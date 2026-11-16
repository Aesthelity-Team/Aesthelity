"""Seed the approved alias catalog into Firestore (dry-run unless --apply)."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from Backend.ingredient_alias_store import (
    COLLECTION,
    DOCUMENT_ID,
    _validate_catalog,
)


ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Write the approved catalog to Firestore.")
    parser.add_argument("--replace", action="store_true", help="Replace an existing active catalog; requires --apply.")
    args = parser.parse_args()
    if args.replace and not args.apply:
        raise SystemExit("--replace requires --apply.")

    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Could not load bundled alias catalog: {error}") from error
    _validate_catalog(catalog)

    project_id = os.environ.get("FIREBASE_PROJECT_ID", "aesthelity-2026")
    database_id = os.environ.get("FIRESTORE_DATABASE_ID", "ogdb")
    editor = os.environ.get("INGREDIENT_ALIAS_EDITOR", "").strip()
    if args.apply and not editor:
        raise SystemExit("Set INGREDIENT_ALIAS_EDITOR to your authorized team identity before --apply.")

    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
    except ImportError as error:
        raise SystemExit("Install Backend/requirements.txt before seeding Firestore.") from error

    app = firebase_admin.initialize_app(credentials.ApplicationDefault(), {"projectId": project_id})
    try:
        db = firestore.client(app=app, database_id=database_id)
        reference = db.collection(COLLECTION).document(DOCUMENT_ID)
        existing = reference.get()
        if existing.exists and not args.replace:
            raise SystemExit(
                f"{COLLECTION}/{DOCUMENT_ID} already exists; inspect it and use --replace to update it."
            )

        payload = {
            **catalog,
            "reviewStatus": "approved",
            "updatedBy": editor or "dry-run",
        }
        print(f"Target: project={project_id}, database={database_id}")
        print(f"Document: {COLLECTION}/{DOCUMENT_ID}")
        print(f"Catalog version: {catalog['version']}; ingredients: {len(catalog['ingredients'])}")
        if not args.apply:
            print("Dry run only. No Firestore document was written.")
            return
        payload["updatedAt"] = firestore.SERVER_TIMESTAMP
        reference.set(payload)
        print("Approved ingredient alias catalog written.")
    finally:
        firebase_admin.delete_app(app)


if __name__ == "__main__":
    main()
