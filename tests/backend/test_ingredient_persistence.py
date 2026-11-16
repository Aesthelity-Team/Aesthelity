"""Firestore persistence for #98 matching results (fake Firestore only)."""

import io
import json
import unittest
from pathlib import Path
from types import SimpleNamespace

from Backend.analysis_api import APIHandler
from Backend.ai_normalization import coverage_for_rows, ground_ai_suggestions
from Backend.ingredient_catalog import ReferenceIndex, build_catalog, parse_cosing_csv
from Backend.ingredient_persistence import (
    FakeFirestore,
    IngredientPersistenceError,
    assert_owner_can_read,
    master_id_for_row,
    persist_matching_result,
    unresolved_master_id,
)


ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
APPROVED = json.loads(BUNDLED.read_text(encoding="utf-8"))

CSV = """COSING Ref No,INCI name,INN name,Ph. Eur. Name,CAS No,EINECS/ELINCS No,Chem/IUPAC Name / Description,Restriction,Function,Update Date
31959,"AQUA","water","",7732-18-5,231-791-2,"Water","","SOLVENT",01/01/2010
40003,"4-ISOBUTYLRESORCINOL","","",18979-62-9,,"","","ANTIOXIDANT",01/01/2010
"""


def reference_index():
    return ReferenceIndex(build_catalog(parse_cosing_csv(CSV), APPROVED, version="test"))


def ai_row(index, status, normalized=None, best_guess=None, explanation="ok"):
    return {
        "index": index,
        "status": status,
        "normalizedName": normalized,
        "bestGuess": best_guess,
        "explanation": explanation,
    }


class MasterIDTests(unittest.TestCase):
    def test_same_name_key_shares_unresolved_id(self):
        first = unresolved_master_id("Mystery Complex 9")
        second = unresolved_master_id("  mystery   complex 9 ")
        self.assertEqual(first, second)
        self.assertTrue(first.startswith("unresolved-"))
        self.assertEqual(len(first), len("unresolved-") + 16)

    def test_confirmed_and_cosing_use_catalog_ids(self):
        self.assertEqual(master_id_for_row({"mapping": "confirmed", "ingredientID": "water"}), "water")
        self.assertEqual(
            master_id_for_row({"mapping": "uncertain", "suggestedID": "4-isobutylresorcinol", "originalText": "x"}),
            "4-isobutylresorcinol",
        )
        self.assertEqual(
            master_id_for_row({"mapping": "unmatched", "originalText": "blurred txt"}),
            unresolved_master_id("blurred txt"),
        )


class PersistenceTests(unittest.TestCase):
    def setUp(self):
        self.db = FakeFirestore()
        self.reference = reference_index()
        self.rows = ground_ai_suggestions(
            ["niacinimide", "Aqua", "isobutyl mystery", "blurred txt", "maybe niacinamide?"],
            [
                ai_row(0, "identified", "Niacinamide"),
                ai_row(1, "identified", "Water"),
                ai_row(2, "identified", "4-ISOBUTYLRESORCINOL"),
                ai_row(3, "unknown", explanation="gibberish"),
                ai_row(4, "tentative", best_guess="Niacinamide", explanation="uncertain OCR"),
            ],
            APPROVED,
            self.reference,
        )

    def test_stores_product_list_in_order_with_master_refs(self):
        coverage = coverage_for_rows(self.rows)
        result = persist_matching_result(
            self.db,
            product_id="manual-uuid-1",
            rows=self.rows,
            coverage=coverage,
            source_type="manual",
            owner_uid="user-a",
            submitted_ingredients=[row["originalText"] for row in self.rows],
        )
        product = self.db.docs[("productIngredients", "manual-uuid-1")]
        self.assertEqual(product["ownerUID"], "user-a")
        self.assertEqual(product["sourceType"], "manual")
        self.assertEqual(
            [entry["originalText"] for entry in product["ingredients"]],
            [row["originalText"] for row in self.rows],
        )
        self.assertEqual(product["ingredients"][0]["masterIngredientID"], "niacinamide")
        self.assertEqual(product["ingredients"][0]["masterRef"], "ingredients/niacinamide")
        self.assertEqual(product["ingredients"][2]["masterIngredientID"], "4-isobutylresorcinol")
        self.assertTrue(product["ingredients"][3]["masterIngredientID"].startswith("unresolved-"))
        self.assertTrue(product["ingredients"][4]["masterIngredientID"].startswith("unresolved-"))
        self.assertEqual(result["writeCount"], 1 + len(result["masterIDs"]))

    def test_aliases_share_one_master_record(self):
        persist_matching_result(
            self.db,
            product_id="p1",
            rows=self.rows,
            coverage=coverage_for_rows(self.rows),
            source_type="manual",
            owner_uid="user-a",
        )
        # Second product uses another alias for the same approved ingredient.
        other = ground_ai_suggestions(
            ["Niacinamide"],
            [ai_row(0, "identified", "Niacinamide")],
            APPROVED,
            self.reference,
        )
        persist_matching_result(
            self.db,
            product_id="p2",
            rows=other,
            coverage="complete",
            source_type="manual",
            owner_uid="user-a",
        )
        master = self.db.docs[("ingredients", "niacinamide")]
        self.assertEqual(master["resolutionStatus"], "identified")
        self.assertEqual(master["id"], "niacinamide")
        self.assertTrue(master["encounteredInProducts"])
        self.assertEqual(sorted(master["observedTexts"]), ["Niacinamide", "niacinimide"])

    def test_unresolved_never_merges_into_confirmed(self):
        persist_matching_result(
            self.db,
            product_id="p1",
            rows=self.rows,
            coverage=coverage_for_rows(self.rows),
            source_type="manual",
            owner_uid="user-a",
        )
        confirmed = self.db.docs[("ingredients", "niacinamide")]
        unresolved_id = master_id_for_row(self.rows[4])  # tentative best guess Niacinamide
        self.assertNotEqual(unresolved_id, "niacinamide")
        unresolved = self.db.docs[("ingredients", unresolved_id)]
        self.assertEqual(unresolved["resolutionStatus"], "unresolved")
        self.assertEqual(unresolved["bestGuess"], "Niacinamide")
        self.assertEqual(confirmed["resolutionStatus"], "identified")
        self.assertNotEqual(unresolved_id, confirmed["id"])

    def test_cosing_only_in_mixed_list_is_partial_coverage(self):
        mixed = [row for row in self.rows if row["originalText"] in {"Aqua", "isobutyl mystery"}]
        self.assertEqual(coverage_for_rows(mixed), "partial")
        persist_matching_result(
            self.db,
            product_id="p-mix",
            rows=mixed,
            coverage=coverage_for_rows(mixed),
            source_type="manual",
            owner_uid="user-a",
        )
        product = self.db.docs[("productIngredients", "p-mix")]
        self.assertEqual(product["coverage"], "partial")

    def test_owner_isolation_for_manual_products(self):
        persist_matching_result(
            self.db,
            product_id="mine",
            rows=self.rows[:1],
            coverage="complete",
            source_type="manual",
            owner_uid="user-a",
        )
        product = self.db.docs[("productIngredients", "mine")]
        assert_owner_can_read(product, "user-a")
        with self.assertRaises(IngredientPersistenceError):
            assert_owner_can_read(product, "user-b")
        with self.assertRaises(IngredientPersistenceError):
            assert_owner_can_read(product, None)

    def test_firestore_failure_does_not_report_success(self):
        self.db.fail_next_commit = True
        with self.assertRaises(IngredientPersistenceError):
            persist_matching_result(
                self.db,
                product_id="p-fail",
                rows=self.rows[:1],
                coverage="complete",
                source_type="manual",
                owner_uid="user-a",
            )
        self.assertNotIn(("productIngredients", "p-fail"), self.db.docs)
        self.assertEqual(self.db.commits, 0)


class EndpointPersistTests(unittest.TestCase):
    def post(self, body, *, db=None, provider=None, uid="user-a"):
        handler = object.__new__(APIHandler)
        handler.path = "/api/v1/ingredients/resolve"
        handler.command = "POST"
        handler.authenticated_uid = uid
        encoded = json.dumps(body).encode()
        handler.headers = {"Content-Type": "application/json", "Content-Length": str(len(encoded))}
        handler.rfile = io.BytesIO(encoded)
        handler.server = SimpleNamespace(
            db=db or FakeFirestore(),
            catalog=APPROVED,
            database_id="test",
            demo_mode=True,
            reference_index=reference_index(),
            ai_provider=provider,
        )
        captured = {}
        handler._send = lambda status, payload: captured.update(status=status, body=payload)
        handler.do_POST()
        return captured, handler.server.db

    def test_persist_writes_and_firestore_failure_returns_503(self):
        class Provider:
            model = "fake"
            last_model = "fake"

            def resolve(self, texts):
                return {"ingredients": [
                    ai_row(0, "identified", "Water"),
                    ai_row(1, "identified", "4-ISOBUTYLRESORCINOL"),
                ]}

        captured, db = self.post(
            {
                "contractVersion": 1,
                "ingredients": ["Aqua", "isobutyl mystery"],
                "productID": "manual-1",
                "persist": True,
                "sourceType": "manual",
            },
            provider=Provider(),
        )
        self.assertEqual(captured["status"], 200)
        self.assertEqual(captured["body"]["coverage"], "partial")
        self.assertIn("persisted", captured["body"])
        self.assertEqual(db.docs[("productIngredients", "manual-1")]["ownerUID"], "user-a")

        failing = FakeFirestore()
        failing.fail_next_commit = True
        captured, _ = self.post(
            {
                "contractVersion": 1,
                "ingredients": ["Aqua"],
                "productID": "manual-2",
                "persist": True,
            },
            db=failing,
            provider=Provider(),
        )
        self.assertEqual(captured["status"], 503)
        self.assertEqual(captured["body"]["status"], "failed")
        self.assertEqual(captured["body"]["failureCode"], "firestore_unavailable")
        self.assertEqual([row["originalText"] for row in captured["body"]["ingredients"]], ["Aqua"])


if __name__ == "__main__":
    unittest.main()
