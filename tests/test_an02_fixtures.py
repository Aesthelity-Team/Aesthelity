"""Default-suite checks for AN-02 fixture files and contract shape.

These tests do not call analysis_engine and do not score fixtures as engine
results. A passing run is fixture validation only.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = ROOT / "docs" / "fixtures" / "an02"
CONTRACT = ROOT / "docs" / "AN02.md"
CATALOG_PATH = ROOT / "Aesthelity/Aesthelity/Resources/SampleData/ingredient-aliases.json"
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
ERROR_CODES = (
    "missing-period",
    "missing-recorded-allergies",
    "allergy-unknown-has-ids",
    "allergy-known-missing-ids",
    "empty-products",
    "duplicate-product-id",
    "list-status",
    "invalid-coapplication",
    "row-shape",
    "invalid-id",
    "invalid-formulation",
)


def load_fixtures():
    files = sorted(FIXTURES.glob("*.json"))
    return [(path, json.loads(path.read_text(encoding="utf-8"))) for path in files]


def bundled_catalog():
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def invalid_routines():
    known = {"status": "known", "ingredientIDs": []}
    product = {"productID": "x", "listStatus": "unavailable", "catalogVersion": 2, "ingredients": []}
    return {
        "missing-period": {"recordedAllergies": known, "products": [product]},
        "missing-recorded-allergies": {"period": "am", "products": [product]},
        "allergy-unknown-has-ids": {
            "period": "am",
            "recordedAllergies": {"status": "unknown", "ingredientIDs": ["limonene"]},
            "products": [product],
        },
        "allergy-known-missing-ids": {
            "period": "am",
            "recordedAllergies": {"status": "known"},
            "products": [product],
        },
        "empty-products": {"period": "am", "recordedAllergies": known, "products": []},
        "duplicate-product-id": {
            "period": "am",
            "recordedAllergies": known,
            "products": [dict(product, productID="same"), dict(product, productID="same")],
        },
        "list-status": {
            "period": "am",
            "recordedAllergies": known,
            "products": [dict(product, listStatus="full")],
        },
        "invalid-coapplication": {
            "period": "am",
            "coapplication": "together",
            "recordedAllergies": known,
            "products": [product],
        },
        "row-shape": {
            "period": "am",
            "recordedAllergies": known,
            "products": [{
                "productID": "x",
                "listStatus": "complete",
                "catalogVersion": 2,
                "ingredients": [{
                    "originalText": "Water",
                    "mapping": "confirmed",
                    "status": {"matched": {"ingredientID": "water"}},
                    "ingredientID": "water",
                }],
            }],
        },
        "invalid-id": {
            "period": "am",
            "recordedAllergies": known,
            "products": [{
                "productID": "x",
                "listStatus": "complete",
                "catalogVersion": 2,
                "ingredients": [{"originalText": "Water", "mapping": "confirmed", "ingredientID": "Water"}],
            }],
        },
        "invalid-formulation": {
            "period": "am",
            "recordedAllergies": known,
            "products": [{
                "productID": "x",
                "listStatus": "complete",
                "catalogVersion": 2,
                "ingredients": [{
                    "originalText": "Tretinoin",
                    "mapping": "confirmed",
                    "ingredientID": "tretinoin",
                    "formulation": {"vehicle": "cream", "concentrationPercent": 0.025},
                }],
            }],
        },
    }


class FixtureInventory(unittest.TestCase):
    """File checks only. A passing result here is not an engine test."""

    @classmethod
    def setUpClass(cls):
        cls.fixtures = load_fixtures()
        cls.catalog = bundled_catalog()
        cls.ids = {item["id"] for item in cls.catalog["ingredients"]}
        cls.classes = {
            item["id"]: set(item.get("classes", [])) for item in cls.catalog["ingredients"]
        }

    def test_required_cases_are_present(self):
        roles = {doc["caseRole"] for _, doc in self.fixtures}
        self.assertTrue(
            {"normal", "caution", "allergen", "unknown", "conflict", "negative", "exception"} <= roles
        )

    def test_files_match_the_contract_shape(self):
        self.assertEqual(self.catalog["version"], 2)
        self.assertNotIn("tretinoin", self.ids)
        self.assertEqual(
            self.classes["glycolic-acid"] & {"exfoliant"},
            {"exfoliant"},
        )
        for path, doc in self.fixtures:
            self.assertEqual(doc["contractStatus"], "proposed", path.name)
            self.assertEqual(doc["schemaVersion"], 1, path.name)
            expected = doc["expected"]
            self.assertEqual(expected["productIDs"], [item["productID"] for item in doc["input"]["products"]])
            if expected["outcome"] == "noFindings":
                self.assertEqual(expected["findings"], [])
                self.assertEqual(expected["completeness"], "complete")
            else:
                self.assertTrue(expected["findings"], path.name)
            for item in expected["findings"]:
                self.assertEqual(item["ruleStatus"], "proposed", path.name)
                if item["outcome"] == "unknown":
                    self.assertNotIn("severity", item, path.name)
                else:
                    self.assertIn(item["severity"], {"low", "moderate", "high"}, path.name)
            self._ids_fit_catalog(path, doc)

    def test_conflict_trigger_requires_studied_context(self):
        by_name = {path.name: doc for path, doc in self.fixtures}
        conflict = by_name["conflict-tretinoin-benzoyl-peroxide.json"]
        self.assertEqual(conflict["input"]["coapplication"], "mixed")
        formulas = {}
        for product in conflict["input"]["products"]:
            for row in product["ingredients"]:
                if "formulation" in row:
                    formulas[row["ingredientID"]] = row["formulation"]
        self.assertEqual(formulas["tretinoin"], {"vehicle": "conventional-gel", "concentrationPercent": 0.025})
        self.assertEqual(formulas["benzoyl-peroxide"], {"vehicle": "lotion", "concentrationPercent": 10})
        conflict_files = [
            path.name
            for path, doc in self.fixtures
            if any(item["outcome"] == "conflict" for item in doc["expected"]["findings"])
        ]
        self.assertEqual(conflict_files, ["conflict-tretinoin-benzoyl-peroxide.json"])
        unknown = by_name["unknown-tretinoin-bpo-context.json"]
        self.assertNotIn("coapplication", unknown["input"])
        self.assertEqual(
            [item["ruleID"] for item in unknown["expected"]["findings"]],
            ["coverage.tretinoin-bpo-context-unknown"],
        )
        self.assertEqual(unknown["expected"]["findings"][0]["reasonCode"], "formulation-unknown")
        for name in ("negative-tretinoin-optimized-gel.json", "negative-tretinoin-microsphere.json"):
            stable = by_name[name]
            self.assertEqual(stable["expected"]["outcome"], "noFindings", name)
            self.assertEqual(stable["input"]["coapplication"], "mixed")
            benzoyl = next(
                product for product in stable["input"]["products"]
                if product["productID"] == "example-benzoyl-peroxide"
            )
            self.assertTrue(all("formulation" not in row for row in benzoyl["ingredients"]), name)

    def test_contradictory_lists_are_excluded_from_matches(self):
        by_name = {path.name: doc for path, doc in self.fixtures}
        doc = by_name["exception-contradictory-list.json"]
        retinol = doc["input"]["products"][0]
        self.assertEqual(retinol["listStatus"], "unavailable")
        self.assertTrue(retinol["ingredients"])
        outcomes = {item["outcome"] for item in doc["expected"]["findings"]}
        self.assertTrue(outcomes <= {"unknown"}, outcomes)
        self.assertEqual(doc["expected"]["findings"][0]["ruleID"], "coverage.contradictory-list-status")

    def test_error_codes_match_the_contract(self):
        text = CONTRACT.read_text(encoding="utf-8")
        listed = re.search(r"raises the first one: (.+)\.", text)
        self.assertIsNotNone(listed)
        codes = re.findall(r"`([a-z0-9-]+)`", listed.group(1))
        self.assertEqual(tuple(codes), ERROR_CODES)
        for code in ERROR_CODES:
            self.assertIn(code, invalid_routines())

    def test_assigned_severities(self):
        found = {}
        for _, doc in self.fixtures:
            for item in doc["expected"]["findings"]:
                if "severity" in item:
                    found.setdefault(item["ruleID"], set()).add(item["severity"])
        self.assertEqual(found["irritation.retinol-benzoyl-peroxide-with-exfoliant"], {"moderate"})
        self.assertEqual(found["interaction.benzoyl-peroxide-with-tretinoin"], {"high"})
        self.assertEqual(found["allergy.recorded-ingredient"], {"high"})

    def _ids_fit_catalog(self, path, doc):
        allowed = set(self.ids)
        if doc["catalogMode"] == "bundled-plus-tretinoin":
            allowed.add("tretinoin")
        allowed.add("nonexistent-id")
        for product in doc["input"]["products"]:
            for row in product["ingredients"]:
                for value in self._row_ids(row):
                    self.assertRegex(value, SLUG, path.name)
                confirmed_id = row.get("ingredientID")
                legacy = row.get("status", {}).get("matched", {}).get("ingredientID")
                confirmed_id = confirmed_id or legacy
                if confirmed_id and confirmed_id != "nonexistent-id":
                    if not (doc["catalogMode"] == "bundled" and confirmed_id == "tretinoin"):
                        self.assertIn(confirmed_id, allowed, path.name)
                for value in row.get("candidateIDs", []):
                    self.assertIn(value, self.ids, path.name)

    @staticmethod
    def _row_ids(row):
        values = []
        for key in ("ingredientID", "suggestedID"):
            if key in row:
                values.append(row[key])
        status = row.get("status")
        if isinstance(status, dict):
            for payload in status.values():
                if isinstance(payload, dict):
                    for key in ("ingredientID", "suggestedID"):
                        if key in payload:
                            values.append(payload[key])
                    values.extend(payload.get("candidateIDs", []))
        return values


if __name__ == "__main__":
    unittest.main()
