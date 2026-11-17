"""Turn #98 resolve results into the input of the #99 AI analysis engine.

`resolve_ingredient_texts` (and `POST /api/v1/ingredients/resolve`) return one
row per label string with a #98 `mapping` of confirmed, uncertain, unmatched or
ambiguous. The #99 engine (`analysis_engine.ai_analysis.analyze_normalized_routine`)
expects the shared normalization contract instead:

* a normalization envelope: contractVersion 1, normalizationID, promptVersion,
  providerStatus, products
* per product: productID, listStatus (complete | partial | unavailable) and
  ingredient rows with index, originalText, status (matched | uncertain |
  unknown), canonicalName, proposedName and reason
* canonical_records: [{id, canonicalName, classes}], looked up by exact
  canonical name, which must be unique

Mapping (PD-03 is unchanged, only approved-catalog matches become `matched`):

    confirmed  -> matched    canonicalName = the approved catalog name
    uncertain  -> uncertain  proposedName  = bestGuess, else CosIng/canonical/suggestedID
    unmatched  -> unknown    reason        = not_in_catalog | empty_input
    ambiguous  -> unknown    reason        = ambiguous: <candidate ids>

originalText and row order are always preserved.
"""

from __future__ import annotations

from collections.abc import Iterable, Mapping
from typing import Any
from uuid import uuid4


CONTRACT_VERSION = 1
RESOLVE_VERSION = "ingredient-resolve-v1"
LIST_STATUSES = ("complete", "partial", "unavailable")
MAX_REASON_LENGTH = 500


class AnalysisInputAdapterError(ValueError):
    """The resolve rows or product details cannot form valid #99 input."""


def _name_key(value: str) -> str:
    # Same normalization the #99 engine uses for canonical-name lookups.
    return " ".join(value.casefold().split())


def _approved_names(approved_catalog: Mapping[str, Any]) -> dict[str, str]:
    return {
        item["id"]: item["name"]
        for item in approved_catalog.get("ingredients", [])
        if isinstance(item, Mapping) and isinstance(item.get("id"), str) and isinstance(item.get("name"), str)
    }


def canonical_records(
    approved_catalog: Mapping[str, Any],
    reference: Any = None,
    *,
    include_reference: bool = False,
) -> list[dict[str, Any]]:
    """`canonical_records` for the #99 engine.

    Default: the approved catalog only. Under PD-03 only approved ingredients
    are ever `matched`, so this is all the engine needs, and every name is
    unique (the alias store rejects catalogs with clashing names).

    With include_reference=True the full CosIng index is appended too (for
    allergy IDs outside the approved list, say). Any reference record whose
    name clashes with an earlier record is dropped, so a `matched` name can
    never become "canonical-name-ambiguous" in the engine.
    """

    records: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    seen_names: set[str] = set()
    for item in approved_catalog.get("ingredients", []):
        key = _name_key(item["name"])
        if item["id"] in seen_ids or key in seen_names:
            raise AnalysisInputAdapterError(f"Approved catalog name or ID is not unique: {item['name']!r}.")
        seen_ids.add(item["id"])
        seen_names.add(key)
        records.append({"id": item["id"], "canonicalName": item["name"], "classes": list(item.get("classes", []))})

    if include_reference and reference is not None:
        clashing: set[str] = set()
        extra: dict[str, dict[str, Any]] = {}
        for record in reference.records.values():
            if record["id"] in seen_ids:
                continue
            key = _name_key(record.get("canonicalName") or "")
            if not key:
                continue
            if key in seen_names or key in extra:
                clashing.add(key)
                continue
            extra[key] = {"id": record["id"], "canonicalName": record["canonicalName"], "classes": list(record.get("classes", []))}
        records.extend(record for key, record in extra.items() if key not in clashing)
    return records


def _reason(text: str) -> str:
    return text if len(text) <= MAX_REASON_LENGTH else text[: MAX_REASON_LENGTH - 3] + "..."


def analysis_row(row: Mapping[str, Any], index: int, approved_names: Mapping[str, str]) -> dict[str, Any]:
    """Convert one #98 resolve row into one #99 normalized ingredient row.

    ``uncertain`` rows set ``proposedName`` from ``bestGuess`` when present
    (AI tentative), otherwise CosIng ``canonicalName`` / ``suggestedID``.
    Only approved-catalog ``confirmed`` rows become ``matched``.
    """

    original = row.get("originalText")
    if not isinstance(original, str):
        raise AnalysisInputAdapterError("Each resolve row needs its originalText.")
    mapping = row.get("mapping")
    out: dict[str, Any] = {
        "index": index,
        "originalText": original,
        "status": "unknown",
        "canonicalName": None,
        "proposedName": None,
        "reason": None,
    }
    if mapping == "confirmed":
        name = approved_names.get(row.get("ingredientID"))
        if name is None:
            # Not in the approved catalog after all: never pass it as matched.
            out["reason"] = "not-in-approved-catalog"
        else:
            default = f"approved-catalog match on {row.get('matchedOn') or 'name'}"
            out.update(status="matched", canonicalName=name, reason=row.get("reason") or default)
    elif mapping == "uncertain":
        # Tentative AI rows carry bestGuess; CosIng-only rows carry canonicalName / suggestedID.
        proposed = row.get("bestGuess") or row.get("canonicalName") or row.get("suggestedID")
        if row.get("status") == "tentative" and row.get("bestGuess"):
            default = row.get("explanation") or row.get("reason") or "ai-tentative best guess"
        else:
            default = f"reference-catalog-only ({row.get('suggestedID')}); not approved for analysis"
        out.update(status="uncertain", proposedName=proposed, reason=row.get("reason") or default)
    elif mapping == "ambiguous":
        candidates = ", ".join(row.get("candidateIDs") or []) or "none"
        out["reason"] = _reason(f"ambiguous: {candidates}")
    elif mapping == "unmatched":
        out["reason"] = row.get("reason") or "not_in_catalog"
    else:
        raise AnalysisInputAdapterError(f"Unknown resolve mapping: {mapping!r}.")
    out["reason"] = _reason(out["reason"])
    return out


def derive_list_status(rows: list[Any], list_status: str | None = None) -> str:
    """The product's listStatus.

    An explicit value wins (a catalog product's stored status, or the app
    saying the whole label was captured). With no rows the list is
    unavailable. Otherwise the default is partial: a scan or pasted text does
    not prove the full label was read, and the engine treats partial as an
    honest coverage gap rather than a clean result.
    """

    if list_status is not None:
        if list_status not in LIST_STATUSES:
            raise AnalysisInputAdapterError("listStatus must be complete, partial, or unavailable.")
        if list_status == "unavailable" and rows:
            raise AnalysisInputAdapterError("An unavailable list cannot have ingredient rows.")
        return list_status
    return "unavailable" if not rows else "partial"


def analysis_product(
    product_id: str,
    resolve_rows: list[Mapping[str, Any]],
    approved_catalog: Mapping[str, Any],
    *,
    list_status: str | None = None,
) -> dict[str, Any]:
    """Build one product object for the #99 ``normalization.products`` array.

    Preserves resolve-row order and exact ``originalText``. ``list_status``
    defaults via ``derive_list_status`` when omitted.
    """

    if not isinstance(product_id, str) or not product_id.strip():
        raise AnalysisInputAdapterError("productID must be a non-empty string.")
    if not isinstance(resolve_rows, list):
        raise AnalysisInputAdapterError("resolve rows must be an array.")
    status = derive_list_status(resolve_rows, list_status)
    names = _approved_names(approved_catalog)
    return {
        "productID": product_id,
        "listStatus": status,
        "ingredients": [analysis_row(row, index, names) for index, row in enumerate(resolve_rows)],
    }


def analysis_normalization(
    products: Iterable[Mapping[str, Any]],
    *,
    catalog_version: Any = None,
    reference_catalog_version: Any = None,
    normalization_id: str | None = None,
    provider_status: str = "ok",
    model: str | None = None,
    prompt_version: str | None = None,
) -> dict[str, Any]:
    """Build the #99 ``normalization`` envelope for already-converted products.

    Pass the sanitized ``provider_status`` and ``model`` from #98 matching.
    ``providerStatus`` other than ``ok`` makes the #99 result incomplete.
    """

    product_list = [dict(product) for product in products]
    ids = [product["productID"] for product in product_list]
    if not product_list:
        raise AnalysisInputAdapterError("At least one product is required.")
    if len(set(ids)) != len(ids):
        raise AnalysisInputAdapterError("productID values must be unique.")
    return {
        "contractVersion": CONTRACT_VERSION,
        "normalizationID": normalization_id or str(uuid4()),
        "promptVersion": prompt_version or RESOLVE_VERSION,
        "model": model,
        "providerStatus": provider_status,
        "canonicalDataVersion": catalog_version,
        "referenceCatalogVersion": reference_catalog_version,
        "products": product_list,
        "uncertaintyPreserved": any(
            product["listStatus"] != "complete"
            or not product["ingredients"]
            or any(row["status"] != "matched" for row in product["ingredients"])
            for product in product_list
        ),
    }


def _routine_list_status(statuses: list[str]) -> str:
    # The routine is complete only when every product's full list was captured.
    if all(status == "complete" for status in statuses):
        return "complete"
    if all(status == "unavailable" for status in statuses):
        return "unavailable"
    return "partial"


def _shared(values: list[Any]) -> Any:
    # A version/model field survives the merge only when every source agrees.
    distinct = {repr(value) for value in values}
    return values[0] if values and len(distinct) == 1 else None


def analysis_routine_normalization(
    payloads: Iterable[Mapping[str, Any]],
    *,
    normalization_id: str | None = None,
) -> dict[str, Any]:
    """Combine per-product #99 envelopes into one routine ``normalization``.

    Each payload is an ``analysis_normalization`` envelope, or a resolve
    response body carrying one under ``analysisInput``. Products keep their
    own ``productID``, ``listStatus`` and rows (index, ``originalText``,
    status) untouched, so unknown/uncertain rows stay unknown/uncertain and
    every row stays attributable to its product. The same product sent twice
    with identical content is kept once; different content under one
    ``productID`` is rejected.

    ``providerStatus`` is ``ok`` only if every source was ok, otherwise the
    first non-ok status (the #99 engine then reports incomplete).
    ``routineListStatus`` is ``complete`` only if every product is complete,
    ``unavailable`` if every product is, else ``partial``.
    """

    envelopes: list[Mapping[str, Any]] = []
    for payload in payloads:
        if not isinstance(payload, Mapping):
            raise AnalysisInputAdapterError("Each routine payload must be an object.")
        envelope = payload.get("analysisInput", payload)
        if not isinstance(envelope, Mapping) or envelope.get("contractVersion") != CONTRACT_VERSION:
            raise AnalysisInputAdapterError("Each routine payload needs a contractVersion 1 analysis-input envelope.")
        if not isinstance(envelope.get("products"), list):
            raise AnalysisInputAdapterError("Each analysis-input envelope needs a products array.")
        envelopes.append(envelope)
    if not envelopes:
        raise AnalysisInputAdapterError("At least one product payload is required.")

    products: list[dict[str, Any]] = []
    by_id: dict[str, dict[str, Any]] = {}
    sources: dict[str, list[str]] = {}
    for envelope in envelopes:
        source_id = envelope.get("normalizationID")
        for product in envelope["products"]:
            if not isinstance(product, Mapping):
                raise AnalysisInputAdapterError("Each product must be an object.")
            product_id = product.get("productID")
            if not isinstance(product_id, str) or not product_id.strip():
                raise AnalysisInputAdapterError("productID must be a non-empty string.")
            rows = product.get("ingredients")
            if not isinstance(rows, list) or any(
                not isinstance(row, Mapping) or row.get("index") != index for index, row in enumerate(rows)
            ):
                raise AnalysisInputAdapterError(f"Product {product_id!r} needs ingredient rows with sequential index.")
            status = derive_list_status(rows, product.get("listStatus"))
            merged = {**dict(product), "listStatus": status, "ingredients": [dict(row) for row in rows]}
            if product_id in by_id:
                if by_id[product_id] != merged:
                    raise AnalysisInputAdapterError(f"productID {product_id!r} appears twice with different content.")
                continue
            by_id[product_id] = merged
            products.append(merged)
            if isinstance(source_id, str):
                sources.setdefault(product_id, []).append(source_id)

    provider_statuses = [envelope.get("providerStatus") or "ok" for envelope in envelopes]
    provider_status = next((status for status in provider_statuses if status != "ok"), "ok")
    routine = analysis_normalization(
        products,
        catalog_version=_shared([envelope.get("canonicalDataVersion") for envelope in envelopes]),
        reference_catalog_version=_shared([envelope.get("referenceCatalogVersion") for envelope in envelopes]),
        normalization_id=normalization_id,
        provider_status=provider_status,
        model=_shared([envelope.get("model") for envelope in envelopes]),
        prompt_version=_shared([envelope.get("promptVersion") for envelope in envelopes]),
    )
    routine["routineListStatus"] = _routine_list_status([product["listStatus"] for product in products])
    routine["sourceNormalizationIDs"] = sources
    return routine
