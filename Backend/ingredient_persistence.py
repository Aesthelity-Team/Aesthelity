"""Persist #98 matching results to Firestore (product lists + master records).

Collection layout (Phase 1 / Phase 3):
  ingredients/{masterId}           shared master records (CosIng + unresolved)
  productIngredients/{productId}   ordered product ingredient lists

Manual products follow #108 isolation: ownerUID must equal the authenticated
Firebase UID; callers supply the client-assigned ManualProduct UUID as productId.
Catalog products use their stable catalog IDs and may omit ownerUID.

Unresolved IDs are ``unresolved-<sha256(name_key)[:16]>`` so identical normalized
originalText values share one unresolved master record. Tentative/unknown rows
never merge into an identified master record.
"""

from __future__ import annotations

import hashlib
from collections.abc import Mapping, Sequence
from datetime import datetime, timezone
from typing import Any


PRODUCT_INGREDIENTS_COLLECTION = "productIngredients"
INGREDIENTS_COLLECTION = "ingredients"
SOURCE_TYPES = ("manual", "catalog")
MAX_BATCH_OPS = 500


class IngredientPersistenceError(RuntimeError):
    """Sanitized persistence failure; never includes credentials or raw SDK text."""

    def __init__(self, code: str = "firestore_unavailable"):
        self.code = code
        super().__init__(code)


class ArrayUnion:
    """Firestore ArrayUnion stand-in that FakeFirestore can apply locally."""

    def __init__(self, values: Sequence[str]):
        self.values = [value for value in values if isinstance(value, str) and value]


def unresolved_master_id(original_text: str) -> str:
    """Stable unresolved master ID: ``unresolved-<sha256(name_key)[:16]>``.

    Identical ``name_key`` values (case/punctuation folded) share one ID.
    """
    key = " ".join(
        "".join(char.lower() if char.isalnum() else " " for char in original_text).split()
    )
    material = key or original_text.strip() or "empty"
    digest = hashlib.sha256(material.encode("utf-8")).hexdigest()[:16]
    return f"unresolved-{digest}"


def master_id_for_row(row: Mapping[str, Any]) -> str:
    """Pick the Firestore master document ID for one resolve row.

    Confirmed → ``ingredientID``. CosIng-only uncertain → ``suggestedID``.
    Otherwise → ``unresolved_master_id(originalText)``.
    """

    mapping = row.get("mapping")
    if mapping == "confirmed" and isinstance(row.get("ingredientID"), str) and row["ingredientID"]:
        return row["ingredientID"]
    if mapping == "uncertain" and isinstance(row.get("suggestedID"), str) and row["suggestedID"]:
        # CosIng-only / reference-tier identity (still not merged into approved-only logic).
        return row["suggestedID"]
    # Tentative AI guesses without a catalog ID, unknowns, and empty input.
    return unresolved_master_id(str(row.get("originalText") or ""))


def _master_payload(row: Mapping[str, Any], master_id: str, *, updated_by: str) -> dict[str, Any]:
    original = str(row.get("originalText") or "")
    now = datetime.now(timezone.utc)
    if master_id.startswith("unresolved-"):
        return {
            "id": master_id,
            "resolutionStatus": "unresolved",
            "status": row.get("status") if row.get("status") in {"tentative", "unknown"} else "unknown",
            "tier": "unresolved",
            "canonicalName": None,
            "bestGuess": row.get("bestGuess"),
            "explanation": row.get("explanation") or row.get("reason"),
            "observedTexts": ArrayUnion([original] if original.strip() else []),
            "encounteredInProducts": True,
            "updatedAt": now,
            "updatedBy": updated_by,
        }
    payload: dict[str, Any] = {
        "id": master_id,
        "resolutionStatus": "identified",
        "encounteredInProducts": True,
        "observedTexts": ArrayUnion([original] if original.strip() else []),
        "updatedAt": now,
        "updatedBy": updated_by,
    }
    # Prefer catalog names already on the row; never invent new CosIng fields here.
    if row.get("canonicalName"):
        payload["canonicalName"] = row["canonicalName"]
    if row.get("tier"):
        payload["tier"] = row["tier"]
    if row.get("mapping") == "confirmed":
        payload["analysisEligible"] = True
    elif row.get("mapping") == "uncertain":
        payload["analysisEligible"] = False
        if row.get("bestGuess"):
            payload.setdefault("canonicalName", row["bestGuess"])
    return payload


def _product_entry(row: Mapping[str, Any], master_id: str) -> dict[str, Any]:
    return {
        "index": row["index"],
        "originalText": row["originalText"],
        "status": row.get("status"),
        "mapping": row.get("mapping"),
        "normalizedName": row.get("normalizedName"),
        "bestGuess": row.get("bestGuess"),
        "explanation": row.get("explanation") or row.get("reason"),
        "ingredientID": row.get("ingredientID"),
        "suggestedID": row.get("suggestedID"),
        "masterIngredientID": master_id,
        "masterRef": f"{INGREDIENTS_COLLECTION}/{master_id}",
        "analysisEligible": bool(row.get("analysisEligible")),
    }


def build_persistence_plan(
    *,
    product_id: str,
    rows: Sequence[Mapping[str, Any]],
    coverage: str,
    source_type: str,
    owner_uid: str | None,
    submitted_ingredients: Sequence[str],
    prompt_version: str | None = None,
    model: str | None = None,
    provider_status: str | None = None,
    run_status: str = "ok",
    failure_code: str | None = None,
    updated_by: str = "ingredient-matching",
) -> dict[str, Any]:
    """Build ``productIngredients`` + master payloads without writing.

    Manual ``source_type`` requires a non-empty ``owner_uid``. Returns
    ``{"product": ..., "masters": {masterId: payload}}``.
    """

    if source_type not in SOURCE_TYPES:
        raise IngredientPersistenceError("invalid_source_type")
    if not isinstance(product_id, str) or not product_id.strip() or "/" in product_id:
        raise IngredientPersistenceError("invalid_product_id")
    if source_type == "manual" and (not isinstance(owner_uid, str) or not owner_uid.strip()):
        raise IngredientPersistenceError("owner_required")

    masters: dict[str, dict[str, Any]] = {}
    entries: list[dict[str, Any]] = []
    for row in rows:
        master_id = master_id_for_row(row)
        entries.append(_product_entry(row, master_id))
        # First write wins field shape; ArrayUnion accumulates across rows.
        if master_id not in masters:
            masters[master_id] = _master_payload(row, master_id, updated_by=updated_by)
        else:
            existing = masters[master_id]
            texts = existing.get("observedTexts")
            original = str(row.get("originalText") or "")
            if isinstance(texts, ArrayUnion) and original.strip():
                texts.values.append(original)
            # Never promote an unresolved master into an identified one from a best guess.
            if existing.get("resolutionStatus") == "unresolved" and not master_id.startswith("unresolved-"):
                raise IngredientPersistenceError("unresolved_merge_forbidden")

    product_doc = {
        "productID": product_id,
        "sourceType": source_type,
        "ownerUID": owner_uid if source_type == "manual" else owner_uid,
        "coverage": coverage,
        "status": run_status,
        "failureCode": failure_code,
        "submittedIngredients": list(submitted_ingredients),
        "ingredients": entries,
        "promptVersion": prompt_version,
        "model": model,
        "providerStatus": provider_status,
        "updatedAt": datetime.now(timezone.utc),
        "updatedBy": updated_by,
    }
    if source_type == "catalog":
        product_doc["ownerUID"] = None
    return {"product": product_doc, "masters": masters}


def _apply_array_union(existing: Any, union: ArrayUnion) -> list[str]:
    current = list(existing) if isinstance(existing, list) else []
    for value in union.values:
        if value not in current:
            current.append(value)
    return current


def _merge_document(existing: Mapping[str, Any] | None, updates: Mapping[str, Any]) -> dict[str, Any]:
    merged = dict(existing or {})
    for key, value in updates.items():
        if isinstance(value, ArrayUnion):
            merged[key] = _apply_array_union(merged.get(key), value)
        else:
            merged[key] = value
    return merged


class FakeFirestore:
    """In-memory Firestore stand-in for unit tests (no network, no credentials)."""

    def __init__(self):
        self.docs: dict[tuple[str, str], dict[str, Any]] = {}
        self.commits = 0
        self.fail_next_commit = False

    def collection(self, name: str) -> "FakeCollection":
        return FakeCollection(self, name)

    def batch(self) -> "FakeBatch":
        return FakeBatch(self)


class FakeCollection:
    def __init__(self, db: FakeFirestore, name: str):
        self.db = db
        self.name = name

    def document(self, doc_id: str) -> "FakeDocumentRef":
        return FakeDocumentRef(self.db, self.name, doc_id)


class FakeDocumentRef:
    def __init__(self, db: FakeFirestore, collection: str, doc_id: str):
        self.db = db
        self.collection = collection
        self.id = doc_id

    def get(self) -> "FakeSnapshot":
        data = self.db.docs.get((self.collection, self.id))
        return FakeSnapshot(self.id, data)

    def set(self, data: Mapping[str, Any], merge: bool = False) -> None:
        key = (self.collection, self.id)
        if merge:
            self.db.docs[key] = _merge_document(self.db.docs.get(key), data)
        else:
            self.db.docs[key] = _merge_document(None, data)


class FakeSnapshot:
    def __init__(self, doc_id: str, data: dict[str, Any] | None):
        self.id = doc_id
        self._data = data

    @property
    def exists(self) -> bool:
        return self._data is not None

    def to_dict(self) -> dict[str, Any] | None:
        return None if self._data is None else dict(self._data)


class FakeBatch:
    def __init__(self, db: FakeFirestore):
        self.db = db
        self.ops: list[tuple[FakeDocumentRef, dict[str, Any], bool]] = []

    def set(self, ref: FakeDocumentRef, data: Mapping[str, Any], merge: bool = False) -> None:
        self.ops.append((ref, dict(data), merge))

    def commit(self) -> None:
        if self.db.fail_next_commit:
            self.db.fail_next_commit = False
            raise IngredientPersistenceError("firestore_unavailable")
        if len(self.ops) > MAX_BATCH_OPS:
            raise IngredientPersistenceError("firestore_batch_too_large")
        for ref, data, merge in self.ops:
            ref.set(data, merge=merge)
        self.db.commits += 1
        self.ops.clear()


def _firestore_array_union(values: Sequence[str]) -> Any:
    """Prefer the Admin SDK ArrayUnion when available; otherwise the local stand-in."""

    cleaned = [value for value in values if isinstance(value, str) and value]
    try:
        from firebase_admin import firestore as admin_firestore

        return admin_firestore.ArrayUnion(cleaned)
    except Exception:
        return ArrayUnion(cleaned)


def _prepare_writes(payload: Mapping[str, Any]) -> dict[str, Any]:
    prepared: dict[str, Any] = {}
    for key, value in payload.items():
        if isinstance(value, ArrayUnion):
            prepared[key] = _firestore_array_union(value.values)
        else:
            prepared[key] = value
    return prepared


def persist_matching_result(
    db: Any,
    *,
    product_id: str,
    rows: Sequence[Mapping[str, Any]],
    coverage: str,
    source_type: str = "manual",
    owner_uid: str | None = None,
    submitted_ingredients: Sequence[str] | None = None,
    prompt_version: str | None = None,
    model: str | None = None,
    provider_status: str | None = None,
    run_status: str = "ok",
    failure_code: str | None = None,
    updated_by: str = "ingredient-matching",
) -> dict[str, Any]:
    """Write ``productIngredients`` + master merges in one Firestore batch.

    Masters use ``set(..., merge=True)`` so CosIng import fields are not wiped.
    Raises ``IngredientPersistenceError`` on failure; callers must return an
    explicit failure (HTTP 503) and must not claim success. Unit tests should
    pass ``FakeFirestore`` — do not write to the real project without asking.
    """

    submitted = (
        list(submitted_ingredients)
        if submitted_ingredients is not None
        else [str(row.get("originalText") or "") for row in rows]
    )
    plan = build_persistence_plan(
        product_id=product_id,
        rows=rows,
        coverage=coverage,
        source_type=source_type,
        owner_uid=owner_uid,
        submitted_ingredients=submitted,
        prompt_version=prompt_version,
        model=model,
        provider_status=provider_status,
        run_status=run_status,
        failure_code=failure_code,
        updated_by=updated_by,
    )
    if len(plan["masters"]) + 1 > MAX_BATCH_OPS:
        raise IngredientPersistenceError("firestore_batch_too_large")

    try:
        batch = db.batch()
        product_ref = db.collection(PRODUCT_INGREDIENTS_COLLECTION).document(product_id)
        batch.set(product_ref, _prepare_writes(plan["product"]), merge=False)
        for master_id, payload in plan["masters"].items():
            master_ref = db.collection(INGREDIENTS_COLLECTION).document(master_id)
            batch.set(master_ref, _prepare_writes(payload), merge=True)
        batch.commit()
    except IngredientPersistenceError:
        raise
    except Exception as error:
        raise IngredientPersistenceError("firestore_unavailable") from error

    return {
        "productPath": f"{PRODUCT_INGREDIENTS_COLLECTION}/{product_id}",
        "masterIDs": sorted(plan["masters"]),
        "writeCount": len(plan["masters"]) + 1,
    }


def assert_owner_can_read(product_doc: Mapping[str, Any], actor_uid: str | None) -> None:
    """Enforce #108 isolation: manual docs are readable only by their ownerUID."""

    if product_doc.get("sourceType") != "manual":
        return
    owner = product_doc.get("ownerUID")
    if not actor_uid or actor_uid != owner:
        raise IngredientPersistenceError("forbidden")
