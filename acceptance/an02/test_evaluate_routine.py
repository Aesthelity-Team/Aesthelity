"""Opt-in AN-02 engine acceptance suite.

Not part of `python3 -m unittest discover -s tests`. Run only with:

    python3 -m unittest discover -s acceptance/an02 -v

This suite calls analysis_engine.evaluate.evaluate_routine. When that module
is missing it fails with BLOCKER. It does not skip, does not score fixtures
locally, and does not call scripts.demo_catalog.evaluate. A green run here is
the only signal that the production engine matched the fixtures.
"""

import importlib
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIXTURES = ROOT / "docs" / "fixtures" / "an02"
CATALOG_PATH = ROOT / "Aesthelity/Aesthelity/Resources/SampleData/ingredient-aliases.json"
BLOCKER = (
    "BLOCKER: AN-03 is not implemented on this branch. "
    "The production API is analysis_engine.evaluate.evaluate_routine "
    "and AnalysisInputError. These acceptance tests do not evaluate rules "
    "locally and do not call the demo catalog evaluator."
)


def load_fixtures():
    files = sorted(FIXTURES.glob("*.json"))
    return [(path, json.loads(path.read_text(encoding="utf-8"))) for path in files]


def bundled_catalog():
    return json.loads(CATALOG_PATH.read_text(encoding="utf-8"))


def catalog_for(fixture, bundled):
    mode = fixture["catalogMode"]
    if mode == "bundled":
        return bundled
    if mode == "bundled-plus-tretinoin":
        catalog = json.loads(json.dumps(bundled))
        catalog["ingredients"].append(
            {"id": "tretinoin", "name": "Tretinoin", "aliases": [], "classes": ["retinoid"]}
        )
        return catalog
    raise AssertionError(f"Unknown catalogMode {mode}")


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


class EngineAcceptance(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        try:
            module = importlib.import_module("analysis_engine.evaluate")
        except ImportError as error:
            raise AssertionError(BLOCKER) from error
        evaluate = getattr(module, "evaluate_routine", None)
        error_type = getattr(module, "AnalysisInputError", None)
        if evaluate is None or error_type is None:
            raise AssertionError(BLOCKER)
        cls.evaluate = staticmethod(evaluate)
        cls.error_type = error_type
        cls.catalog = bundled_catalog()

    def test_each_fixture_matches_the_engine_result(self):
        for path, doc in load_fixtures():
            with self.subTest(fixture=path.name):
                actual = self.evaluate(doc["input"], catalog_for(doc, self.catalog))
                self.assertEqual(actual, doc["expected"])

    def test_invalid_input_raises(self):
        for code, routine in invalid_routines().items():
            with self.subTest(code=code):
                with self.assertRaises(self.error_type) as caught:
                    self.evaluate(routine, self.catalog)
                self.assertEqual(getattr(caught.exception, "code", None), code)


if __name__ == "__main__":
    unittest.main()
