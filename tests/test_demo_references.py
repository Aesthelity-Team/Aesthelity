"""Offline checks for the additive demo evidence and allergy gate."""

import io
import json
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import Mock

from analysis_engine.ai_analysis import _reference_matches_routine, analyze_normalized_routine
from Backend.analysis_api import _public_analysis_body
from Backend.seed_analysis_references import CONTRACT, REFERENCES
from Backend.seed_demo_references import REFERENCES_V1_1, preview_references
from test_ai_analysis import FakeProvider, candidate, context, normalization, row

CATALOG_PATH = (
    Path(__file__).resolve().parents[1]
    / "Aesthelity/Aesthelity/Resources/SampleData/ingredient-aliases.json"
)
CATALOG = {row["id"]: row for row in json.loads(CATALOG_PATH.read_text())["ingredients"]}


def routine(ingredient_ids, allergy_ids=(), allergy_status="known"):
    return {
        "products": [{"ingredients": [
            {"ingredientID": ingredient_id, "classes": CATALOG[ingredient_id]["classes"]}
            for ingredient_id in ingredient_ids
        ]}],
        "recordedAllergies": {"status": allergy_status, "ingredientIDs": list(allergy_ids)},
    }


class DemoReferenceTests(unittest.TestCase):
    def test_records_match_schema_and_use_catalog_values(self):
        catalog_classes = {value for row in CATALOG.values() for value in row["classes"]}
        seen = {row["referenceID"] for row in REFERENCES}
        self.assertTrue(REFERENCES_V1_1)
        for record in REFERENCES_V1_1:
            reference_id = record["referenceID"]
            with self.subTest(reference_id=reference_id):
                self.assertNotIn(reference_id, seen)
                seen.add(reference_id)
                self.assertEqual(record.keys(), REFERENCES[0].keys())
                self.assertEqual(record["source"].keys(), REFERENCES[0]["source"].keys())
                self.assertTrue(all(record["source"].values()))
                self.assertTrue(record["source"]["url"].startswith("https://"))
                self.assertEqual(record["source"]["accessedOn"], "2026-11-18")
                self.assertEqual(record["referenceVersion"], 1)
                self.assertEqual(record["reviewStatus"], "approved")
                self.assertIn(record["allowedOutcome"], CONTRACT["approvedReferenceOutcomes"])
                self.assertIn(record["severity"], CONTRACT["severityValues"])
                self.assertTrue(record["claim"])
                self.assertTrue(record["conditions"])
                self.assertTrue(any("not a diagnosis" in line for line in record["limitations"]))
                self.assertTrue(record["canonicalIngredientIDs"])
                criteria = record["matchCriteria"]
                for ids in (
                    record["canonicalIngredientIDs"],
                    criteria.get("allIngredientIDs", []),
                    criteria.get("anyIngredientIDs", []),
                    [item["ingredientID"] for item in criteria.get("formulations", [])],
                ):
                    self.assertLessEqual(set(ids), CATALOG.keys())
                for classes in (record["canonicalIngredientClasses"], criteria.get("allIngredientClasses", [])):
                    self.assertLessEqual(set(classes), catalog_classes)

    def test_every_new_reference_has_positive_and_near_miss_routines(self):
        cases = {
            "allergy.recorded-linalool": (
                routine(["linalool"], ["linalool"]),
                [
                    routine(["linalool"]),
                    routine(["linalool"], allergy_status="unknown"),
                    routine(["water"], ["linalool"]),
                    routine(["linalool", "limonene"], ["limonene"]),
                ],
            ),
        }
        self.assertEqual(set(cases), {record["referenceID"] for record in REFERENCES_V1_1})
        for record in REFERENCES_V1_1:
            positive, near_misses = cases[record["referenceID"]]
            with self.subTest(reference=record["referenceID"]):
                self.assertTrue(_reference_matches_routine(record, positive))
                for near_miss in near_misses:
                    self.assertFalse(_reference_matches_routine(record, near_miss))


    def test_linalool_finding_carries_evidence_in_public_response(self):
        record = REFERENCES_V1_1[0]
        provider = FakeProvider(candidate(record["referenceID"], "allergen", ["product"], ["linalool"]))
        result = analyze_normalized_routine(
            normalization(row(0, "Linalool", "Linalool")),
            context(recordedAllergies={"status": "known", "ingredientIDs": ["linalool"]}),
            [{"id": "linalool", "canonicalName": "Linalool", "classes": CATALOG["linalool"]["classes"]}],
            [*REFERENCES, *REFERENCES_V1_1],
            provider,
        )
        response = _public_analysis_body(result, catalog_version=3, catalog_source="test")
        self.assertEqual(response["outcome"], "findings")
        self.assertEqual(response["findings"][0]["outcome"], "allergen")
        self.assertEqual(response["findings"][0]["evidence"][0]["source"], record["source"])


class DemoReferenceSeedTests(unittest.TestCase):
    def setUp(self):
        self.db = Mock(spec=["collection"])
        collection = self.db.collection.return_value
        self.document = collection.document.return_value
        self.record = REFERENCES_V1_1[0]
        self.document.path = f"analysisReferences/{self.record['referenceID']}"
        self.document.get.return_value.exists = False

    def run_preview(self):
        output = io.StringIO()
        with redirect_stdout(output):
            preview_references(self.db)
        return output.getvalue()

    def test_dry_run_reads_and_lists_without_writing(self):
        output = self.run_preview()
        self.db.collection.assert_called_once_with("analysisReferences")
        self.document.get.assert_called_once_with()
        self.document.create.assert_not_called()
        self.document.set.assert_not_called()
        self.document.delete.assert_not_called()
        self.assertIn(f"Would create: {self.document.path}", output)

    def test_preview_skips_existing_record(self):
        self.document.get.return_value.exists = True
        self.assertIn(f"Skip existing: {self.document.path}", self.run_preview())
        self.document.create.assert_not_called()
        self.document.set.assert_not_called()
        self.document.delete.assert_not_called()
