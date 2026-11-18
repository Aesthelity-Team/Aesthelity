"""Preview the additional v1 demo analysis references."""

from __future__ import annotations

import argparse
import os
from typing import Any

REFERENCES_V1_1 = [
    {
        "referenceID": "allergy.recorded-linalool",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {
            "title": (
                "Contact sensitization to hydroperoxides of limonene and linalool: "
                "Results of consecutive patch testing and clinical relevance"
            ),
            "publisher": "Contact Dermatitis",
            "url": "https://pure.rug.nl/ws/portalfiles/portal/78600809/Dittmar_et_al_2019_Contact_Dermatitis.pdf",
            "accessedOn": "2026-11-18",
        },
        "claim": (
            "The study used linalool on product labels to help investigate exposure "
            "in patients who reacted to linalool hydroperoxides on patch testing."
        ),
        "canonicalIngredientIDs": ["linalool"],
        "canonicalIngredientClasses": [],
        "matchCriteria": {
            "allIngredientIDs": ["linalool"],
            "recordedAllergyRequired": True,
        },
        "conditions": [
            "A product lists linalool and the user has recorded linalool as an allergy."
        ],
        "incompleteWhenContextMissing": False,
        "allowedOutcome": "allergen",
        "severity": "high",
        "categoryID": "recorded-allergy",
        "limitations": [
            "This is informational, not a diagnosis.",
            "A label match cannot establish oxidation, exposure level, or reaction severity.",
        ],
    },
]


def preview_references(db: Any) -> None:
    collection = db.collection("analysisReferences")
    for record in REFERENCES_V1_1:
        document = collection.document(record["referenceID"])
        action = "Skip existing" if document.get().exists else "Would create"
        print(f"{action}: {document.path}")
    print("Dry run only. No Firestore documents were written.")


def main() -> None:
    argparse.ArgumentParser(description=__doc__).parse_args()

    import firebase_admin
    from firebase_admin import credentials, firestore

    project_id = os.environ.get("FIREBASE_PROJECT_ID", "aesthelity-2026")
    database_id = os.environ.get("FIRESTORE_DATABASE_ID", "ogdb")
    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": project_id},
    )
    try:
        print(f"Target: project={project_id}, database={database_id}")
        preview_references(firestore.client(app=app, database_id=database_id))
    finally:
        firebase_admin.delete_app(app)


if __name__ == "__main__":
    main()
