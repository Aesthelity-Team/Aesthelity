"""Representative AN-03 unit tests for the production evaluator."""

from __future__ import annotations

import unittest
import json
import subprocess
import sys
from pathlib import Path

from analysis_engine import AnalysisInputError, evaluate_routine
from analysis_engine.demo import CATALOG, demo_input


def product(product_id: str, *rows: dict, status: str = "complete", version: int | None = 2) -> dict:
    return {
        "productID": product_id,
        "listStatus": status,
        "catalogVersion": version,
        "ingredients": list(rows),
    }


def confirmed(ingredient_id: str, **extra: object) -> dict:
    return {
        "originalText": ingredient_id.replace("-", " ").title(),
        "mapping": "confirmed",
        "ingredientID": ingredient_id,
        **extra,
    }


def routine(*products: dict, period: str = "pm", allergies: dict | None = None, **extra: object) -> dict:
    return {
        "period": period,
        "recordedAllergies": allergies or {"status": "known", "ingredientIDs": []},
        "products": list(products),
        **extra,
    }


class AnalysisEngineTests(unittest.TestCase):
    def test_caution_finds_retinol_with_exfoliant_and_keeps_product_links(self) -> None:
        result = evaluate_routine(demo_input("caution"), CATALOG)
        self.assertEqual(result["outcome"], "findings")
        self.assertEqual(result["completeness"], "complete")
        finding = result["findings"][0]
        self.assertEqual(finding["outcome"], "caution")
        self.assertEqual(finding["severity"], "moderate")
        self.assertEqual(finding["productIDs"], ["retinol-product", "glycolic-product"])
        self.assertEqual(finding["ingredientIDs"], ["retinol", "glycolic-acid"])

    def test_partial_product_can_match_confirmed_rows_and_reports_incompleteness(self) -> None:
        result = evaluate_routine(
            routine(
                product("retinol", confirmed("retinol"), status="partial"),
                product("exfoliant", confirmed("glycolic-acid")),
            ),
            CATALOG,
        )
        self.assertEqual([f["outcome"] for f in result["findings"]], ["caution", "unknown"])
        self.assertEqual(result["completeness"], "incomplete")

    def test_conflict_only_matches_the_approved_formulations_when_mixed(self) -> None:
        inp = demo_input("conflict")
        result = evaluate_routine(inp, CATALOG)
        conflict = next(f for f in result["findings"] if f["outcome"] == "conflict")
        self.assertEqual(conflict["severity"], "high")
        self.assertEqual(conflict["productIDs"], ["tretinoin-product", "benzoyl-peroxide-product"])

        inp["products"][0]["ingredients"][0]["formulation"]["concentrationPercent"] = 0.05
        result = evaluate_routine(inp, CATALOG)
        self.assertFalse(any(f["outcome"] == "conflict" for f in result["findings"]))
        self.assertTrue(any(f["outcome"] == "unknown" for f in result["findings"]))

    def test_recorded_allergy_requires_exact_confirmed_id(self) -> None:
        result = evaluate_routine(
            routine(
                product("fragranced", confirmed("limonene")),
                allergies={"status": "known", "ingredientIDs": ["limonene"]},
            ),
            CATALOG,
        )
        self.assertEqual(result["findings"][0]["outcome"], "allergen")
        self.assertEqual(result["findings"][0]["ingredientIDs"], ["limonene"])

    def test_suggested_allergen_is_unknown_and_not_a_match(self) -> None:
        result = evaluate_routine(
            routine(
                product("fragranced", {
                    "originalText": "Citrus oil",
                    "mapping": "uncertain",
                    "suggestedID": "limonene",
                }),
                allergies={"status": "known", "ingredientIDs": ["limonene"]},
            ),
            CATALOG,
        )
        self.assertFalse(any(f["outcome"] == "allergen" for f in result["findings"]))
        self.assertTrue(any(f["outcome"] == "unknown" for f in result["findings"]))

    def test_unknown_allergy_state_is_not_an_empty_known_allergy_list(self) -> None:
        result = evaluate_routine(
            routine(product("water", confirmed("water")), allergies={"status": "unknown"}),
            CATALOG,
        )
        self.assertEqual(result["completeness"], "incomplete")
        self.assertIn("coverage.allergy-input-unknown", [f["ruleID"] for f in result["findings"]])

    def test_no_findings_uses_requested_display_label(self) -> None:
        result = evaluate_routine(demo_input("no-findings"), CATALOG)
        self.assertEqual(result["outcome"], "noFindings")
        self.assertEqual(result["displayLabel"], "No recorded conflicts")
        self.assertEqual(result["findings"], [])

    def test_unavailable_or_stale_product_rows_do_not_match_rules(self) -> None:
        for item in (
            product("bad-status", confirmed("retinol"), status="unavailable"),
            product("stale", confirmed("retinol"), version=1),
        ):
            with self.subTest(product=item["productID"]):
                result = evaluate_routine(
                    routine(item, product("exfoliant", confirmed("glycolic-acid"))), CATALOG
                )
                self.assertFalse(any(f["outcome"] == "caution" for f in result["findings"]))
                self.assertTrue(any(f["outcome"] == "unknown" for f in result["findings"]))

    def test_exact_conflict_is_evaluated_within_the_selected_period(self) -> None:
        result = evaluate_routine(
            routine(
                product("tretinoin", confirmed("tretinoin", formulation={
                    "vehicle": "conventional-gel", "concentrationPercent": 0.025
                })),
                product("benzoyl-peroxide", confirmed("benzoyl-peroxide", formulation={
                    "vehicle": "lotion", "concentrationPercent": 10
                })),
                period="am",
                coapplication="mixed",
            ),
            CATALOG,
        )
        self.assertEqual(result["period"], "am")
        self.assertTrue(any(f["outcome"] == "conflict" for f in result["findings"]))

    def test_invalid_routine_raises_stable_error_code(self) -> None:
        with self.assertRaises(AnalysisInputError) as caught:
            evaluate_routine({"products": []}, CATALOG)
        self.assertEqual(caught.exception.code, "missing-period")

    def test_demo_command_runs_as_an_integration_path(self) -> None:
        package_root = Path(__file__).resolve().parents[1]
        completed = subprocess.run(
            [sys.executable, "-m", "analysis_engine.demo", "--case", "no-findings"],
            cwd=package_root,
            check=True,
            capture_output=True,
            text=True,
        )
        result = json.loads(completed.stdout)
        self.assertEqual(result["outcome"], "noFindings")
        self.assertEqual(result["displayLabel"], "No recorded conflicts")


if __name__ == "__main__":
    unittest.main()
