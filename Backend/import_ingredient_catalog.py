"""Import the full EU CosIng cosmetic ingredient inventory (#98 follow-up).

Dry-run by default: builds the canonical catalog from the committed snapshot
(or a CosIng CSV export passed with --source) and prints counts. Nothing is
written to Firestore unless --apply is given.

    python3 Backend/import_ingredient_catalog.py                # dry run
    python3 Backend/import_ingredient_catalog.py --fetch        # refresh snapshot from CosIng
    python3 Backend/import_ingredient_catalog.py --source export.csv
    INGREDIENT_ALIAS_EDITOR=you python3 Backend/import_ingredient_catalog.py --apply

Firestore layout (see docs/FIRESTORE_SCHEMA.md):
    ingredients/{ingredientID}            one canonical ingredient per document
    ingredientAmbiguousTerms/{termKey}    names that map to 2+ candidate IDs
    ingredientCatalogs/reference          version, source, counts (written last)
The hand-approved ingredientAliasCatalogs/active document is never modified.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
import urllib.request
import uuid
from collections.abc import Mapping
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from Backend.ingredient_catalog import (  # noqa: E402
    AMBIGUOUS_COLLECTION,
    DATA_PATH,
    INGREDIENTS_COLLECTION,
    META_COLLECTION,
    META_DOCUMENT,
    SOURCE_NAME,
    SOURCE_URL,
    build_catalog,
    load_source,
    name_key,
    row_from_search_metadata,
    write_snapshot,
)


APPROVED_CATALOG_PATH = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
COSING_CONFIG_URL = "https://ec.europa.eu/growth/tools-databases/cosing/assets/env-json-config.json"
BATCH_SIZE = 400  # Firestore allows 500 writes per batch; leave headroom.
# IDs referenced directly by AN-02 rules in analysis_engine/evaluate.py.
RULE_IDS = ("benzoyl-peroxide", "tretinoin", "retinol", "limonene", "linalool", "fragrance")
LICENSE = "CC BY 4.0"


# --------------------------------------------------------------------------
# Fetch (refresh the committed snapshot)
# --------------------------------------------------------------------------


def _http_json(request: urllib.request.Request, attempts: int = 6) -> Any:
    for attempt in range(attempts):
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except Exception as error:  # network hiccups: back off and retry
            if attempt == attempts - 1:
                raise SystemExit(f"CosIng request failed: {type(error).__name__}: {error}") from error
            time.sleep(5 * (attempt + 1))
    return None


def fetch_snapshot(target: Path) -> None:
    """Download every inventory ingredient from CosIng's public search service.

    CosIng no longer publishes a static bulk file. Its public web app reads the
    European Commission Search API with the endpoint and public key published in
    its own config file; this uses the same service, 200 records per request,
    paging by substance ID.
    """

    agent = {"User-Agent": "Aesthelity-student-project (ingredient catalog import)"}
    config = _http_json(urllib.request.Request(COSING_CONFIG_URL, headers=agent))
    endpoint = f"{config['euSearchApiUrl']}?apiKey={config['euSearchApiKey']}&text=*&pageSize=200&pageNumber=1"
    rows: dict[str, Any] = {}
    reported_total = None
    last = None
    while True:
        must: list[dict[str, Any]] = [{"term": {"itemType": "ingredient"}}]
        if last is not None:
            must.append({"range": {"substanceId": {"gt": last}}})
        boundary = uuid.uuid4().hex
        parts = [("query", json.dumps({"bool": {"must": must}})), ("sort", json.dumps({"field": "substanceId", "order": "ASC"}))]
        body = b"".join(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{n}"\r\nContent-Type: application/json\r\n\r\n{v}\r\n'.encode()
            for n, v in parts
        ) + f"--{boundary}--\r\n".encode()
        request = urllib.request.Request(
            endpoint, data=body, method="POST",
            headers={**agent, "Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        page = _http_json(request)
        if reported_total is None:
            reported_total = page.get("totalResults")
        results = page.get("results") or []
        if not results:
            break
        for result in results:
            row = row_from_search_metadata(result.get("metadata") or {})
            if row is not None:
                rows[row.ref_no] = row
        last = (results[-1].get("metadata") or {}).get("substanceId", [None])[0]
        print(f"  fetched {len(rows)} / {reported_total}", flush=True)
        time.sleep(0.3)
    meta = {
        "source": SOURCE_NAME,
        "sourceUrl": SOURCE_URL,
        "retrievalMethod": "CosIng public search service (itemType=ingredient), all records",
        "retrievedOn": dt.date.today().isoformat(),
        "reportedTotal": reported_total,
        "license": LICENSE,
    }
    write_snapshot(target, meta, rows.values())
    print(f"Wrote {len(rows)} CosIng ingredient rows to {target} (service reported {reported_total}).")


# --------------------------------------------------------------------------
# Firestore payloads and writes
# --------------------------------------------------------------------------


def firestore_documents(catalog: Mapping[str, Any], meta: Mapping[str, Any], editor: str) -> list[tuple[str, str, dict[str, Any]]]:
    """(collection, documentID, payload) for every write, meta document last."""

    writes: list[tuple[str, str, dict[str, Any]]] = []
    version = catalog["version"]
    for record in catalog["ingredients"]:
        payload = {key: value for key, value in record.items() if key != "name"}
        payload.update(catalogVersion=version, updatedBy=editor)
        writes.append((INGREDIENTS_COLLECTION, record["id"], payload))
    for term in catalog["ambiguousTerms"]:
        for name in term["terms"]:
            key = name_key(name)
            writes.append((AMBIGUOUS_COLLECTION, key.replace(" ", "-"), {
                "term": name, "termKey": key, "candidateIDs": term["candidateIDs"],
                "note": term.get("note", ""), "source": term.get("source", "approved-catalog"),
                "catalogVersion": version, "updatedBy": editor,
            }))
    writes.append((META_COLLECTION, META_DOCUMENT, {
        "version": version,
        "source": meta.get("source", SOURCE_NAME),
        "sourceUrl": meta.get("sourceUrl", SOURCE_URL),
        "retrievedOn": meta.get("retrievedOn"),
        "license": meta.get("license", LICENSE),
        "ingredientCount": len(catalog["ingredients"]),
        "ambiguousTermCount": sum(len(term["terms"]) for term in catalog["ambiguousTerms"]),
        "stats": catalog["stats"],
        "updatedBy": editor,
    }))
    return writes


def write_documents(db: Any, writes: list[tuple[str, str, dict[str, Any]]], *, timestamp: Any = None, batch_size: int = BATCH_SIZE) -> int:
    """Batched set() writes; returns the number of committed batches."""

    if not 0 < batch_size <= 500:
        raise ValueError("batch_size must be between 1 and 500.")
    committed = 0
    for start in range(0, len(writes), batch_size):
        batch = db.batch()
        for collection, document_id, payload in writes[start:start + batch_size]:
            body = dict(payload)
            if timestamp is not None:
                body["updatedAt"] = timestamp
            batch.set(db.collection(collection).document(document_id), body)
        batch.commit()
        committed += 1
        print(f"  committed batch {committed} ({min(start + batch_size, len(writes))}/{len(writes)})", flush=True)
    return committed


def select_writes(writes, start_after: str | None, limit: int | None):
    """Optional resumable slice (useful under a daily write quota)."""

    if start_after:
        keys = [f"{c}/{d}" for c, d, _ in writes]
        if start_after not in keys:
            raise SystemExit(f"--start-after {start_after!r} is not a planned document path.")
        writes = writes[keys.index(start_after) + 1:]
    if limit is not None:
        writes = writes[:limit]
    return writes


def run(args: argparse.Namespace, *, db_factory=None) -> dict[str, Any]:
    if args.fetch:
        fetch_snapshot(Path(args.source) if args.source else DATA_PATH)
        if not args.apply:
            args.source = args.source or str(DATA_PATH)
    source = Path(args.source) if args.source else DATA_PATH
    meta, rows = load_source(source)
    approved = json.loads(Path(args.approved_catalog).read_text(encoding="utf-8"))
    version = f"cosing-{meta['retrievedOn']}" if meta.get("retrievedOn") else "cosing"
    catalog = build_catalog(rows, approved, version=version, include_inactive=args.include_inactive)
    editor = os.environ.get("INGREDIENT_ALIAS_EDITOR", "").strip()
    writes = select_writes(firestore_documents(catalog, meta, editor or "dry-run"), args.start_after, args.limit)

    stats = catalog["stats"]
    ids = {record["id"] for record in catalog["ingredients"]}
    print(f"Source: {meta.get('source', SOURCE_NAME)} ({source.name}); retrieved {meta.get('retrievedOn', 'unknown')}")
    print(f"Catalog version: {version}")
    for key in ("sourceRows", "duplicateInciRowsMerged", "ingredients", "approvedTier", "approvedWithCosingData",
                "referenceTier", "mappedToApprovedByName", "mappedToApprovedBySynonym", "lookupNames", "aliases",
                "synonymAliases", "ambiguousTerms", "generatedAmbiguousTerms", "slugCollisionsSuffixed",
                "longSlugsShortened", "inciNameConflictsDropped", "synonymsShadowedByOtherNames",
                "synonymsDroppedTooManyCandidates", "approvedSynonymConflicts", "skippedInactive"):
        print(f"  {key}: {stats.get(key, 0)}")
    for merge in catalog["synonymMergesForReview"]:
        print(f"  review synonym merge: {merge['inciName']} -> {merge['approvedID']}")
    present = [rule_id for rule_id in RULE_IDS if rule_id in ids]
    print(f"  AN-02 rule IDs present with unchanged IDs: {', '.join(present)}")
    print(f"Planned Firestore writes: {len(writes)} in {-(-len(writes) // BATCH_SIZE)} batches "
          f"({INGREDIENTS_COLLECTION}, {AMBIGUOUS_COLLECTION}, {META_COLLECTION}/{META_DOCUMENT})")

    if not args.apply:
        print("Dry run only. No Firestore document was written.")
        return {"catalog": catalog, "writes": writes, "batches": 0}
    if not editor:
        raise SystemExit("Set INGREDIENT_ALIAS_EDITOR to your authorized team identity before --apply.")

    project_id = os.environ.get("FIREBASE_PROJECT_ID", "aesthelity-2026")
    database_id = os.environ.get("FIRESTORE_DATABASE_ID", "ogdb")
    if db_factory is None:
        try:
            import firebase_admin
            from firebase_admin import credentials, firestore
        except ImportError as error:
            raise SystemExit("Install Backend/requirements.txt before writing to Firestore.") from error
        app = firebase_admin.initialize_app(credentials.ApplicationDefault(), {"projectId": project_id})
        try:
            db = firestore.client(app=app, database_id=database_id)
            print(f"Target: project={project_id}, database={database_id}")
            batches = write_documents(db, writes, timestamp=firestore.SERVER_TIMESTAMP)
        finally:
            firebase_admin.delete_app(app)
    else:
        batches = write_documents(db_factory(), writes)
    print(f"Wrote {len(writes)} documents in {batches} batches.")
    return {"catalog": catalog, "writes": writes, "batches": batches}


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--source", help="Snapshot (.json/.json.gz) or CosIng CSV export. Default: committed snapshot.")
    p.add_argument("--approved-catalog", default=str(APPROVED_CATALOG_PATH), help="Hand-approved alias catalog JSON.")
    p.add_argument("--fetch", action="store_true", help="Refresh the snapshot from CosIng before building.")
    p.add_argument("--include-inactive", action="store_true", help="Also import entries CosIng marks inactive.")
    p.add_argument("--apply", action="store_true", help="Write to Firestore (requires INGREDIENT_ALIAS_EDITOR).")
    p.add_argument("--start-after", help="Resume after this document path, e.g. ingredients/glycerin.")
    p.add_argument("--limit", type=int, help="Write at most this many documents (quota-friendly chunks).")
    return p


def main(argv: list[str] | None = None) -> None:
    run(parser().parse_args(argv))


if __name__ == "__main__":
    main()
