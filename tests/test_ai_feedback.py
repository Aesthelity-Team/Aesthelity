"""AI explanation layer stays additive to the deterministic evaluator."""

from __future__ import annotations

import copy
import json
import unittest
from io import BytesIO
from unittest.mock import patch

from analysis_engine.ai_feedback import (
    FeedbackProviderError,
    OpenAIFeedbackProvider,
    add_ai_feedback,
)
from analysis_engine.demo import CATALOG, demo_input
from analysis_engine.evaluate import evaluate_routine


class FakeFeedbackProvider:
    model = "test-model"

    def __init__(self, fail: str | None = None):
        self.fail = fail
        self.contexts = []

    def generate(self, context):
        self.contexts.append(context)
        if self.fail:
            raise FeedbackProviderError(self.fail)
        return {
            "summary": "A short explanation based on the supplied findings.",
            "findingExplanations": [
                {"findingIndex": index, "explanation": "A grounded explanation."}
                for index, _ in enumerate(context["findings"])
            ],
        }


class AIFeedbackTests(unittest.TestCase):
    def test_ai_feedback_does_not_change_engine_outcomes_severity_or_links(self):
        for case in ("caution", "conflict", "unknown", "no-findings"):
            with self.subTest(case=case):
                result = evaluate_routine(demo_input(case), CATALOG)
                original_findings = copy.deepcopy(result["findings"])
                enriched = add_ai_feedback(result, CATALOG, FakeFeedbackProvider())
                self.assertEqual(enriched["findings"], original_findings)
                self.assertEqual(enriched["aiFeedback"]["status"], "generated")

    def test_allergen_finding_is_only_reworded(self):
        routine = {
            "period": "pm",
            "recordedAllergies": {"status": "known", "ingredientIDs": ["limonene"]},
            "products": [{
                "productID": "mist",
                "listStatus": "complete",
                "catalogVersion": CATALOG["version"],
                "ingredients": [{
                    "originalText": "Limonene",
                    "mapping": "confirmed",
                    "ingredientID": "limonene",
                }],
            }],
        }
        result = evaluate_routine(routine, CATALOG)
        self.assertTrue(any(item["outcome"] == "allergen" for item in result["findings"]))
        enriched = add_ai_feedback(result, CATALOG, FakeFeedbackProvider())
        self.assertEqual(enriched["findings"], result["findings"])

    def test_failure_returns_original_findings_and_no_safe_claim(self):
        result = evaluate_routine(demo_input("no-findings"), CATALOG)
        enriched = add_ai_feedback(
            result, CATALOG, FakeFeedbackProvider(fail="ai_unconfigured")
        )
        self.assertEqual(enriched["aiFeedback"]["status"], "ai_unconfigured")
        self.assertFalse(enriched["aiFeedback"]["generated"])
        self.assertIn("not a safety guarantee", enriched["aiFeedback"]["summary"])
        self.assertEqual(enriched["findings"], result["findings"])

    def test_malformed_response_falls_back_without_changing_findings(self):
        class BadProvider:
            model = "test-model"

            def generate(self, context):
                return {"summary": "Looks safe", "findingExplanations": [], "outcome": "safe"}

        result = evaluate_routine(demo_input("caution"), CATALOG)
        enriched = add_ai_feedback(result, CATALOG, BadProvider())
        self.assertEqual(enriched["aiFeedback"]["status"], "ai_invalid_response")
        self.assertEqual(enriched["findings"], result["findings"])
        self.assertNotEqual(enriched["aiFeedback"]["summary"], "Looks safe")

    def test_provider_receives_only_structured_findings_not_allergy_profile_or_raw_rows(self):
        provider = FakeFeedbackProvider()
        result = evaluate_routine(demo_input("caution"), CATALOG)
        add_ai_feedback(result, CATALOG, provider)
        context = provider.contexts[0]
        encoded = json.dumps(context)
        self.assertNotIn("recordedAllergies", encoded)
        self.assertNotIn("originalText", encoded)
        self.assertIn("productIDs", encoded)
        self.assertIn("ingredientIDs", encoded)

    @patch("analysis_engine.ai_feedback.urlopen")
    def test_openai_provider_uses_strict_output_and_does_not_store(self, urlopen_mock):
        response_data = {
            "choices": [{
                "finish_reason": "stop",
                "message": {
                    "content": json.dumps({"summary": "Summary", "findingExplanations": []})
                },
            }]
        }
        urlopen_mock.return_value.__enter__.return_value = BytesIO(
            json.dumps(response_data).encode("utf-8")
        )
        provider = OpenAIFeedbackProvider(api_key="test-key", model="test-model")
        parsed = provider.generate({"findings": []})
        self.assertEqual(parsed["summary"], "Summary")
        request_body = json.loads(urlopen_mock.call_args.args[0].data)
        self.assertFalse(request_body["store"])
        self.assertTrue(request_body["response_format"]["json_schema"]["strict"])
        self.assertEqual(urlopen_mock.call_args.kwargs["timeout"], 30.0)


if __name__ == "__main__":
    unittest.main()
