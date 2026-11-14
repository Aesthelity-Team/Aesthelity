"""Seed the team-approved v1 analysis contract and evidence into Firestore.

Defaults to dry-run. Pass --apply to create the documents. Existing documents
are never overwritten.
"""

from __future__ import annotations

import argparse
import os

import firebase_admin
from firebase_admin import credentials, firestore


CONTRACT_ID = "v1"

REFERENCES = [
    {
        "referenceID": "irritation.retinol-benzoyl-peroxide-with-exfoliant",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {
            "title": "How to safely exfoliate at home",
            "publisher": "American Academy of Dermatology",
            "url": "https://www.aad.org/public/everyday-care/skin-care-secrets/routine/safely-exfoliate-at-home",
            "accessedOn": "2026-11-14",
        },
        "claim": (
            "Retinoid creams and products containing retinol or benzoyl peroxide "
            "may increase skin sensitivity; exfoliating may worsen dryness or irritation."
        ),
        "canonicalIngredientIDs": ["retinol", "benzoyl-peroxide", "tretinoin"],
        "canonicalIngredientClasses": ["exfoliant"],
        "matchCriteria": {
            "anyIngredientIDs": ["retinol", "benzoyl-peroxide", "tretinoin"],
            "allIngredientClasses": ["exfoliant"],
        },
        "conditions": ["An active ingredient and an exfoliant are both present."],
        "incompleteWhenContextMissing": False,
        "allowedOutcome": "caution",
        "severity": "moderate",
        "categoryID": "ingredient-combination",
        "limitations": [
            "This is a possibility, not a universal contraindication.",
            "Ingredient order is not a match condition.",
        ],
    },
    {
        "referenceID": "interaction.benzoyl-peroxide-with-tretinoin",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {
            "title": "Martin et al. (1998) formulation stability study",
            "publisher": "British Journal of Dermatology",
            "url": "https://pubmed.ncbi.nlm.nih.gov/9990414/",
            "accessedOn": "2026-11-14",
        },
        "claim": (
            "The studied mixture of tretinoin 0.025% conventional gel and "
            "benzoyl peroxide 10% lotion reduced tretinoin concentration."
        ),
        "canonicalIngredientIDs": ["tretinoin", "benzoyl-peroxide"],
        "canonicalIngredientClasses": [],
        "matchCriteria": {
            "allIngredientIDs": ["tretinoin", "benzoyl-peroxide"],
            "coapplication": "mixed",
            "formulations": [
                {
                    "ingredientID": "tretinoin",
                    "vehicle": "conventional-gel",
                    "concentrationPercent": 0.025,
                },
                {
                    "ingredientID": "benzoyl-peroxide",
                    "vehicle": "lotion",
                    "concentrationPercent": 10,
                },
            ],
        },
        "conditions": [
            "The studied formulation and mixing conditions are verified."
        ],
        "incompleteWhenContextMissing": True,
        "allowedOutcome": "conflict",
        "severity": "high",
        "categoryID": "ingredient-interaction",
        "limitations": ["This result does not apply to every formulation."],
    },
    {
        "referenceID": "allergy.recorded-ingredient",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {
            "title": "Commission Regulation (EU) 2023/1545",
            "publisher": "European Union",
            "url": "https://eur-lex.europa.eu/eli/reg/2023/1545/oj/eng",
            "accessedOn": "2026-11-14",
        },
        "claim": (
            "Limonene labeling helps people who have already identified a "
            "sensitivity recognize the ingredient; a label match is not a diagnosis."
        ),
        "canonicalIngredientIDs": ["limonene"],
        "canonicalIngredientClasses": [],
        "matchCriteria": {
            "allIngredientIDs": ["limonene"],
            "recordedAllergyRequired": True,
        },
        "conditions": ["The user has recorded limonene as an allergy."],
        "incompleteWhenContextMissing": False,
        "allowedOutcome": "allergen",
        "severity": "high",
        "categoryID": "recorded-allergy",
        "limitations": ["A label match is not a medical diagnosis."],
    },
]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Create the approved documents. Without this flag, only preview.",
    )
    args = parser.parse_args()

    project_id = os.environ.get("FIREBASE_PROJECT_ID", "aesthelity-2026")
    database_id = os.environ.get("FIRESTORE_DATABASE_ID", "ogdb")
    editor = os.environ.get("ANALYSIS_DATA_EDITOR", "").strip()
    if args.apply and not editor:
        raise SystemExit("Set ANALYSIS_DATA_EDITOR to your authorized team identity.")

    app = firebase_admin.initialize_app(
        credentials.ApplicationDefault(),
        {"projectId": project_id},
    )
    try:
        db = firestore.client(app=app, database_id=database_id)
        contract_ref = db.collection("analysisContracts").document(CONTRACT_ID)
        reference_refs = [
            db.collection("analysisReferences").document(record["referenceID"])
            for record in REFERENCES
        ]
        targets = [contract_ref, *reference_refs]
        existing = [ref.path for ref in targets if ref.get().exists]
        if existing:
            raise SystemExit(
                "Refusing to overwrite existing Firestore documents: "
                + ", ".join(existing)
            )

        print(f"Target: project={project_id}, database={database_id}")
        print(f"Would create contract: analysisContracts/{CONTRACT_ID}")
        print(f"Would create {len(REFERENCES)} approved analysis references:")
        for record in REFERENCES:
            print(f"  analysisReferences/{record['referenceID']}")

        if not args.apply:
            print("Dry run only. No Firestore documents were written.")
            return

        now = firestore.SERVER_TIMESTAMP
        contract = {
            "contractVersion": 1,
            "reviewStatus": "approved",
            "ruleSetVersion": "AN-02-v1",
            "resultOutcomes": ["findings", "noFindings"],
            "findingOutcomes": ["caution", "conflict", "allergen", "unknown"],
            "approvedReferenceOutcomes": ["caution", "conflict", "allergen"],
            "severityValues": ["low", "moderate", "high"],
            "policy": {
                "ingredientOrderUsed": False,
                "layeringRecommendations": False,
                "missingOrUnmatchedDataOutcome": "unknown",
            },
            "updatedAt": now,
            "updatedBy": editor,
        }

        batch = db.batch()
        batch.set(contract_ref, contract)
        for ref, record in zip(reference_refs, REFERENCES):
            batch.set(
                ref,
                {
                    **record,
                    "updatedAt": now,
                    "updatedBy": editor,
                },
            )
        batch.commit()
        print("Approved analysis documents created.")
    finally:
        firebase_admin.delete_app(app)


if __name__ == "__main__":
    main()
