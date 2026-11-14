"""Offline tests for evidence-grounded AI findings and fail-closed coverage."""

from __future__ import annotations

import copy
import unittest

from analysis_engine.ai_analysis import (
    AIAnalysisProviderError,
    analyze_normalized_routine,
)


CANONICAL = [
    {"id": "retinol", "canonicalName": "Retinol", "classes": ["retinoid"]},
    {"id": "glycolic-acid", "canonicalName": "Glycolic Acid", "classes": ["aha", "exfoliant"]},
    {"id": "benzoyl-peroxide", "canonicalName": "Benzoyl Peroxide", "classes": ["acne-treatment"]},
    {"id": "tretinoin", "canonicalName": "Tretinoin", "classes": ["retinoid"]},
    {"id": "limonene", "canonicalName": "Limonene", "classes": ["fragrance-allergen"]},
]

REFERENCES = [
    {
        "referenceID": "aad-exfoliation-retinoid-sensitivity",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {"title": "How to safely exfoliate at home", "publisher": "AAD", "url": "https://example.org/aad", "accessedOn": "2026-11-13"},
        "claim": "Retinol or benzoyl peroxide may increase sensitivity; exfoliating may worsen irritation.",
        "canonicalIngredientIDs": ["retinol", "benzoyl-peroxide", "tretinoin"],
        "canonicalIngredientClasses": ["exfoliant"],
        "matchCriteria": {"anyIngredientIDs": ["retinol", "benzoyl-peroxide", "tretinoin"], "allIngredientClasses": ["exfoliant"]},
        "conditions": ["an active and an exfoliant are both present"],
        "allowedOutcome": "caution",
        "severity": "moderate",
        "categoryID": "ingredient-combination",
        "limitations": ["This is a possibility, not a universal contraindication."],
    },
    {
        "referenceID": "study-tretinoin-bpo-mixture",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {"title": "Formulation stability study", "publisher": "Journal", "url": "https://example.org/study", "accessedOn": "2026-11-13"},
        "claim": "The studied tretinoin gel and benzoyl peroxide lotion mixture reduced tretinoin concentration.",
        "canonicalIngredientIDs": ["tretinoin", "benzoyl-peroxide"],
        "canonicalIngredientClasses": [],
        "matchCriteria": {"allIngredientIDs": ["tretinoin", "benzoyl-peroxide"], "coapplication": "mixed", "formulations": [{"ingredientID": "tretinoin", "vehicle": "conventional-gel", "concentrationPercent": 0.025}, {"ingredientID": "benzoyl-peroxide", "vehicle": "lotion", "concentrationPercent": 10}]},
        "incompleteWhenContextMissing": True,
        "conditions": ["the studied formulation and mixing conditions are verified"],
        "allowedOutcome": "conflict",
        "severity": "high",
        "categoryID": "ingredient-interaction",
        "limitations": ["Does not apply to every formulation."],
    },
    {
        "referenceID": "eu-limonene-labeling",
        "referenceVersion": 1,
        "reviewStatus": "approved",
        "source": {"title": "Cosmetic allergens labeling", "publisher": "European Union", "url": "https://example.org/eu", "accessedOn": "2026-11-13"},
        "claim": "Limonene is individually named on labels above regulatory thresholds so sensitized people can identify it.",
        "canonicalIngredientIDs": ["limonene"],
        "canonicalIngredientClasses": [],
        "matchCriteria": {"allIngredientIDs": ["limonene"], "recordedAllergyRequired": True},
        "conditions": ["the user has recorded limonene as an allergy"],
        "allowedOutcome": "allergen",
        "severity": "high",
        "categoryID": "recorded-allergy",
        "limitations": ["A label match is not a medical diagnosis."],
    },
]


class FakeProvider:
    model = "test-model"

    def __init__(self, output=None, error=None):
        self.output = output or {"assessment": "no_findings", "findings": []}
        self.error = error
        self.contexts = []

    def generate(self, context):
        self.contexts.append(copy.deepcopy(context))
        if self.error:
            raise AIAnalysisProviderError(self.error)
        return copy.deepcopy(self.output)


def normalization(*rows, list_status="complete", product_id="product", other_products=None):
    products = [{"productID": product_id, "listStatus": list_status, "ingredients": list(rows)}]
    products.extend(other_products or [])
    return {
        "contractVersion": 1,
        "normalizationID": "normalization-test",
        "promptVersion": "ingredient-normalization-v1",
        "providerStatus": "ok",
        "products": products,
    }


def row(index, text, name, status="matched", proposed=None):
    return {"index": index, "originalText": text, "status": status, "canonicalName": name,
            "proposedName": proposed, "reason": "test normalization"}


def context(**changes):
    value = {"period": "pm", "recordedAllergies": {"status": "known", "ingredientIDs": []}}
    value.update(changes)
    return value


def candidate(reference_id, outcome, products, ingredients, explanation="Supported explanation."):
    return {"assessment": "findings", "findings": [{
        "referenceIDs": [reference_id], "outcome": outcome, "productIDs": products,
        "ingredientIDs": ingredients, "explanation": explanation, "reason": "Reference conditions match.",
    }]}


class AIAnalysisTests(unittest.TestCase):
    def test_caution_links_only_confirmed_product_and_ingredient_ids_and_adds_source(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Retinol", "Retinol"), row(1, "Glycolic Acid", "Glycolic Acid"), product_id="retinol-product"),
            context(), CANONICAL, REFERENCES,
            FakeProvider(candidate("aad-exfoliation-retinoid-sensitivity", "caution", ["retinol-product"], ["retinol", "glycolic-acid"])),
        )
        finding = result["findings"][0]
        self.assertEqual(finding["outcome"], "caution")
        self.assertEqual(finding["severity"], "moderate")
        self.assertEqual(finding["productIDs"], ["retinol-product"])
        self.assertEqual(finding["ingredientIDs"], ["retinol", "glycolic-acid"])
        self.assertEqual(finding["evidence"][0]["referenceID"], "aad-exfoliation-retinoid-sensitivity")
        self.assertEqual(result["normalization"]["products"][0]["ingredients"][0]["originalText"], "Retinol")

    def test_allergen_requires_recorded_allergy_and_is_reference_backed(self):
        provider = FakeProvider(candidate("eu-limonene-labeling", "allergen", ["mist"], ["limonene"]))
        result = analyze_normalized_routine(
            normalization(row(0, "Limonene", "Limonene"), product_id="mist"),
            context(recordedAllergies={"status": "known", "ingredientIDs": ["limonene"]}),
            CANONICAL, REFERENCES, provider,
        )
        self.assertEqual(result["findings"][0]["outcome"], "allergen")
        self.assertEqual(result["findings"][0]["severity"], "high")
        self.assertEqual(provider.contexts[0]["recordedAllergies"]["ingredientIDs"], ["limonene"])

    def test_conflict_requires_the_model_to_cite_approved_exact_scope(self):
        provider = FakeProvider(candidate("study-tretinoin-bpo-mixture", "conflict", ["tret", "bpo"], ["tretinoin", "benzoyl-peroxide"]))
        result = analyze_normalized_routine(
            normalization(
                row(0, "Tretinoin", "Tretinoin"), product_id="tret",
                other_products=[{"productID": "bpo", "listStatus": "complete", "ingredients": [row(0, "Benzoyl Peroxide", "Benzoyl Peroxide")]}],
            ),
            context(coapplication="mixed", formulationContext=[{"productID": "tret", "ingredientID": "tretinoin", "vehicle": "conventional-gel", "concentrationPercent": 0.025}, {"productID": "bpo", "ingredientID": "benzoyl-peroxide", "vehicle": "lotion", "concentrationPercent": 10}]),
            CANONICAL, REFERENCES, provider,
        )
        self.assertEqual(result["findings"][0]["outcome"], "conflict")
        self.assertEqual(result["findings"][0]["severity"], "high")

    def test_unresolved_input_stays_unknown_and_is_preserved(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Mystery Extract", None, status="unknown")),
            context(), CANONICAL, REFERENCES, FakeProvider(),
        )
        self.assertEqual(result["completeness"], "incomplete")
        self.assertTrue(any(item["outcome"] == "unknown" for item in result["findings"]))
        returned = result["normalization"]["products"][0]["ingredients"][0]
        self.assertEqual(returned["originalText"], "Mystery Extract")
        self.assertEqual(returned["status"], "unknown")
        self.assertNotIn("ingredientID", returned)

    def test_provider_failure_returns_unknown_not_no_findings(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Retinol", "Retinol")), context(), CANONICAL, REFERENCES,
            FakeProvider(error="unavailable"),
        )
        self.assertEqual(result["analysisProviderStatus"], "unavailable")
        self.assertEqual(result["outcome"], "findings")
        self.assertEqual(result["completeness"], "incomplete")
        self.assertTrue(any(item["outcome"] == "unknown" for item in result["findings"]))
        self.assertNotIn("displayLabel", result)

    def test_unapproved_or_missing_reference_fails_to_unknown(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Unlisted", "Unlisted")), context(), CANONICAL,
            [], FakeProvider(),
        )
        self.assertEqual(result["analysisProviderStatus"], "no_relevant_references")
        self.assertEqual(result["completeness"], "incomplete")
        self.assertFalse(any(item["outcome"] != "unknown" for item in result["findings"]))

    def test_model_cannot_invent_product_or_ingredient_links(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Retinol", "Retinol")), context(), CANONICAL, REFERENCES,
            FakeProvider(candidate("aad-exfoliation-retinoid-sensitivity", "caution", ["other-product"], ["retinol"])),
        )
        self.assertEqual(result["analysisProviderStatus"], "invalid_response")
        self.assertTrue(any(item["outcome"] == "unknown" for item in result["findings"]))

    def test_untrusted_normalized_id_is_not_accepted(self):
        bad = normalization(row(0, "Retinol", "Invented Ingredient"))
        result = analyze_normalized_routine(bad, context(), CANONICAL, REFERENCES, FakeProvider())
        self.assertEqual(result["completeness"], "incomplete")
        self.assertTrue(any(item.get("reason") == "canonical-name-not-found" for item in result["findings"]))

    def test_studied_pair_without_required_formulation_context_is_unknown(self):
        result = analyze_normalized_routine(
            normalization(
                row(0, "Tretinoin", "Tretinoin"), product_id="tret",
                other_products=[{"productID": "bpo", "listStatus": "complete", "ingredients": [row(0, "Benzoyl Peroxide", "Benzoyl Peroxide")]}],
            ),
            context(coapplication="unknown"), CANONICAL, REFERENCES, FakeProvider(),
        )
        self.assertEqual(result["completeness"], "incomplete")
        self.assertTrue(any(item.get("ruleID") == "coverage.reference-context-incomplete" for item in result["findings"]))
        self.assertFalse(any(item["outcome"] == "conflict" for item in result["findings"]))

    def test_model_cannot_return_a_safety_guarantee(self):
        result = analyze_normalized_routine(
            normalization(row(0, "Retinol", "Retinol"), row(1, "Glycolic Acid", "Glycolic Acid")),
            context(), CANONICAL, REFERENCES,
            FakeProvider(candidate(
                "aad-exfoliation-retinoid-sensitivity", "caution", ["product"],
                ["retinol", "glycolic-acid"], explanation="This routine is safe to use.",
            )),
        )
        self.assertEqual(result["analysisProviderStatus"], "unsupported_claim")
        self.assertTrue(any(item["outcome"] == "unknown" for item in result["findings"]))
    def test_ingredient_order_does_not_change_ai_analysis_context(self):
        original_order_provider = FakeProvider()
        reversed_order_provider = FakeProvider()

        analyze_normalized_routine(
            normalization(
                row(0, "Retinol", "Retinol"),
                row(1, "Glycolic Acid", "Glycolic Acid"),
            ),
            context(),
            CANONICAL,
            REFERENCES,
            original_order_provider,
        )

        analyze_normalized_routine(
            normalization(
                row(0, "Glycolic Acid", "Glycolic Acid"),
                row(1, "Retinol", "Retinol"),
            ),
            context(),
            CANONICAL,
            REFERENCES,
            reversed_order_provider,
        )

        self.assertEqual(
            original_order_provider.contexts[0],
            reversed_order_provider.contexts[0],
        )


if __name__ == "__main__":
    unittest.main()
