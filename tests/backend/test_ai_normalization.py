"""AI-primary matching for #98 (Backend/ai_normalization.py)."""

import copy
import io
import json
import os
import unittest
from http.client import HTTPResponse
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from Backend.analysis_api import APIHandler
from Backend.analysis_engine_input import analysis_normalization, analysis_product, canonical_records
from Backend.ai_normalization import (
    DEFAULT_FALLBACK_MODEL,
    DEFAULT_MODEL,
    OpenRouterNormalizationProvider,
    ProviderError,
    apply_ai_normalization,
    coverage_for_rows,
    ground_ai_suggestions,
    match_ingredients,
    validate_matching_output,
)
from Backend.ingredient_catalog import ReferenceIndex, build_catalog, parse_cosing_csv, resolve_ingredient_texts
from Backend.ingredient_persistence import FakeFirestore

from test_analysis_engine_input import CAUTION_REFERENCE, ENGINE


ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
APPROVED = json.loads(BUNDLED.read_text(encoding="utf-8"))

CSV = """COSING Ref No,INCI name,INN name,Ph. Eur. Name,CAS No,EINECS/ELINCS No,Chem/IUPAC Name / Description,Restriction,Function,Update Date
31959,"AQUA","water","",7732-18-5,231-791-2,"Water","","SOLVENT",01/01/2010
40001,"RETINOL","","",68-26-8,200-683-7,"","","SKIN CONDITIONING",01/01/2010
40002,"GLYCOLIC ACID","","",79-14-1,201-180-5,"","","EXFOLIATING",01/01/2010
40003,"4-ISOBUTYLRESORCINOL","","",18979-62-9,,"","","ANTIOXIDANT",01/01/2010
40004,"ASCORBIC ACID","","",50-81-7,,"","","ANTIOXIDANT",01/01/2010
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


class FakeProvider:
    model = "fake-model"

    def __init__(self, output=None, error=None):
        self.output = output
        self.error = error
        self.calls = []
        self.last_model = self.model

    def resolve(self, texts):
        self.calls.append(list(texts))
        if self.error:
            raise self.error
        return copy.deepcopy(self.output)


class CoverageTests(unittest.TestCase):
    def test_complete_partial_unknown_and_empty(self):
        self.assertEqual(coverage_for_rows([]), "unknown")
        self.assertEqual(
            coverage_for_rows([{"mapping": "confirmed"}, {"mapping": "confirmed"}]),
            "complete",
        )
        self.assertEqual(
            coverage_for_rows([{"mapping": "confirmed"}, {"mapping": "uncertain"}]),
            "partial",
        )
        self.assertEqual(
            coverage_for_rows([{"mapping": "confirmed"}, {"mapping": "unmatched"}]),
            "partial",
        )
        self.assertEqual(
            coverage_for_rows([{"mapping": "uncertain"}, {"mapping": "unmatched"}]),
            "unknown",
        )
        self.assertEqual(coverage_for_rows([{"mapping": "unmatched"}]), "unknown")
        # CosIng-only alone is not complete and not partial: #99 would see zero matched rows.
        self.assertEqual(coverage_for_rows([{"mapping": "uncertain", "status": "tentative"}]), "unknown")


class ValidationTests(unittest.TestCase):
    def test_accepts_valid_rows(self):
        rows = validate_matching_output(
            {"ingredients": [
                ai_row(0, "identified", "Niacinamide"),
                ai_row(1, "tentative", best_guess="Ascorbic Acid", explanation="shorthand"),
                ai_row(2, "unknown", explanation="gibberish"),
            ]},
            3,
        )
        self.assertEqual([row["status"] for row in rows], ["identified", "tentative", "unknown"])

    def test_rejects_missing_extra_duplicate_indices_and_bad_json_shapes(self):
        with self.assertRaises(ProviderError):
            validate_matching_output({"ingredients": [ai_row(0, "identified", "Water")]}, 2)
        with self.assertRaises(ProviderError):
            validate_matching_output(
                {"ingredients": [ai_row(0, "identified", "Water"), ai_row(0, "identified", "Water")]},
                2,
            )
        with self.assertRaises(ProviderError):
            validate_matching_output(
                {"ingredients": [ai_row(1, "identified", "Water"), ai_row(0, "identified", "Glycerin")]},
                2,
            )
        with self.assertRaises(ProviderError):
            validate_matching_output({"ingredients": [ai_row(0, "identified", "Water")], "extra": 1}, 1)
        with self.assertRaises(ProviderError):
            validate_matching_output(
                {"ingredients": [ai_row(0, "identified", "Water", best_guess="also")]},
                1,
            )
        with self.assertRaises(ProviderError):
            validate_matching_output(
                {"ingredients": [{"index": 0, "status": "matched", "normalizedName": "Water",
                                  "bestGuess": None, "explanation": "x"}]},
                1,
            )


class GroundingAndBugFixTests(unittest.TestCase):
    def setUp(self):
        self.reference = reference_index()

    def test_identified_and_approved_becomes_confirmed(self):
        rows = ground_ai_suggestions(
            ["niacinimide"],
            [ai_row(0, "identified", "Niacinamide", explanation="spelling")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "identified")
        self.assertEqual(rows[0]["mapping"], "confirmed")
        self.assertEqual(rows[0]["ingredientID"], "niacinamide")
        self.assertEqual(rows[0]["originalText"], "niacinimide")
        self.assertEqual(rows[0]["normalizedName"], "Niacinamide")

    def test_ai_tentative_stays_tentative_even_when_guess_validates(self):
        """Regression: AI uncertainty must not become confirmed (Scenario 2 / 8)."""

        rows = ground_ai_suggestions(
            ["maybe niacinamide?"],
            [ai_row(0, "tentative", best_guess="Niacinamide", explanation="uncertain OCR")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "tentative")
        self.assertEqual(rows[0]["mapping"], "uncertain")
        self.assertEqual(rows[0]["bestGuess"], "Niacinamide")
        self.assertIsNone(rows[0]["ingredientID"])
        self.assertFalse(rows[0]["analysisEligible"])
        self.assertIn("ai-tentative", rows[0]["reason"])

    def test_identified_ambiguous_downgrades_to_tentative(self):
        rows = ground_ai_suggestions(
            ["Vit C"],
            [ai_row(0, "identified", "Vitamin C", explanation="common shorthand")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "tentative")
        self.assertEqual(rows[0]["mapping"], "uncertain")
        self.assertEqual(rows[0]["bestGuess"], "Vitamin C")
        self.assertIsNone(rows[0]["ingredientID"])
        self.assertIn("ambiguous", rows[0]["reason"])

    def test_identified_not_in_catalog_stays_tentative(self):
        rows = ground_ai_suggestions(
            ["Mystery Complex 9"],
            [ai_row(0, "identified", "totally-invented-ingredient")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "tentative")
        self.assertEqual(rows[0]["bestGuess"], "totally-invented-ingredient")
        self.assertIsNone(rows[0]["ingredientID"])
        self.assertEqual(rows[0]["reason"], "ai-suggestion-not-in-catalog")

    def test_identified_reference_tier_is_tentative_for_coverage(self):
        rows = ground_ai_suggestions(
            ["isobutyl mystery"],
            [ai_row(0, "identified", "4-ISOBUTYLRESORCINOL")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "tentative")
        self.assertEqual(rows[0]["mapping"], "uncertain")
        self.assertEqual(rows[0]["suggestedID"], "4-isobutylresorcinol")
        self.assertEqual(rows[0]["bestGuess"], "4-ISOBUTYLRESORCINOL")
        self.assertIsNone(rows[0]["ingredientID"])
        self.assertFalse(rows[0]["analysisEligible"])
        self.assertEqual(coverage_for_rows(rows), "unknown")

    def test_cosing_only_with_confirmed_gives_partial_coverage(self):
        """A list with one CosIng-only ingredient (plus an approved hit) is partial."""

        rows = ground_ai_suggestions(
            ["Aqua", "isobutyl mystery"],
            [
                ai_row(0, "identified", "Water"),
                ai_row(1, "identified", "4-ISOBUTYLRESORCINOL"),
            ],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["mapping"], "confirmed")
        self.assertEqual(rows[1]["mapping"], "uncertain")
        self.assertEqual(coverage_for_rows(rows), "partial")

    def test_unknown_stays_unknown(self):
        rows = ground_ai_suggestions(
            ["blurred txt"],
            [ai_row(0, "unknown", explanation="gibberish")],
            APPROVED,
            self.reference,
        )
        self.assertEqual(rows[0]["status"], "unknown")
        self.assertEqual(rows[0]["mapping"], "unmatched")
        self.assertEqual(rows[0]["explanation"], "gibberish")


class MatchIngredientsTests(unittest.TestCase):
    def setUp(self):
        self.reference = reference_index()

    def test_sends_every_nonempty_label_to_ai(self):
        provider = FakeProvider({"ingredients": [
            ai_row(0, "identified", "Water"),
            ai_row(1, "identified", "Niacinamide"),
            ai_row(2, "unknown", explanation="gibberish"),
            ai_row(3, "unknown", explanation="empty"),
        ]})
        rows, status, model, run = match_ingredients(
            ["Aqua", "niacinimide", "blurred txt", "   "],
            APPROVED,
            self.reference,
            provider=provider,
        )
        self.assertEqual(status, "ok")
        self.assertEqual(run, "ok")
        self.assertEqual(model, "fake-model")
        self.assertEqual(provider.calls, [["Aqua", "niacinimide", "blurred txt", "   "]])
        self.assertEqual([row["status"] for row in rows], ["identified", "identified", "unknown", "unknown"])
        self.assertEqual(coverage_for_rows(rows), "partial")

    def test_failure_preserves_list_as_unknown_not_success(self):
        provider = FakeProvider(error=ProviderError("provider_unavailable"))
        texts = ["Vit C", "Aqua", "Mystery"]
        rows, status, model, run = match_ingredients(texts, APPROVED, self.reference, provider=provider)
        self.assertEqual(run, "failed")
        self.assertEqual(status, "provider_unavailable")
        self.assertEqual(model, "fake-model")
        self.assertEqual([row["originalText"] for row in rows], texts)
        self.assertEqual([row["status"] for row in rows], ["unknown", "unknown", "unknown"])
        self.assertEqual([row["reason"] for row in rows], ["ai-unavailable"] * 3)
        self.assertEqual(coverage_for_rows(rows), "unknown")

    def test_adapter_and_engine_accept_ai_identified_approved_row(self):
        provider = FakeProvider({"ingredients": [ai_row(0, "identified", "Ascorbic Acid")]})
        rows, status, model, run = match_ingredients(["Vit C"], APPROVED, self.reference, provider=provider)
        # Vit C as identified Ascorbic Acid grounds cleanly to approved.
        self.assertEqual(run, "ok")
        self.assertEqual(rows[0]["mapping"], "confirmed")
        product = analysis_product("serum", rows, APPROVED, list_status="complete")
        self.assertEqual(product["ingredients"][0]["status"], "matched")
        self.assertEqual(product["ingredients"][0]["canonicalName"], "Ascorbic Acid")
        envelope = analysis_normalization(
            [product], catalog_version=APPROVED["version"], provider_status=status,
            model=model, prompt_version="ingredient-matching-v2",
        )
        self.assertEqual(envelope["providerStatus"], "ok")
        products, _, has_unresolved, unresolved = ENGINE._validate_inputs(
            envelope, {"period": "am", "recordedAllergies": {"status": "known", "ingredientIDs": []}},
            canonical_records(APPROVED), [CAUTION_REFERENCE],
        )
        self.assertEqual(products[0]["ingredients"][0]["ingredientID"], "ascorbic-acid")
        self.assertFalse(has_unresolved)
        self.assertEqual(unresolved, [])

    def test_apply_ai_normalization_wrapper_preserves_order(self):
        catalog_rows = resolve_ingredient_texts(["niacinimide", "Aqua"], APPROVED, self.reference)
        provider = FakeProvider({"ingredients": [
            ai_row(0, "identified", "Niacinamide"),
            ai_row(1, "identified", "Water"),
        ]})
        updated, status, model, attempted = apply_ai_normalization(
            catalog_rows, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "ok")
        self.assertEqual(attempted, 2)
        self.assertEqual(model, "fake-model")
        self.assertEqual([row["originalText"] for row in updated], ["niacinimide", "Aqua"])
        self.assertEqual([row["status"] for row in updated], ["identified", "identified"])


class ProviderTransportTests(unittest.TestCase):
    def test_fallback_model_used_after_primary_failure(self):
        calls = []

        def transport(url, payload, headers, timeout):
            calls.append(payload["model"])
            self.assertTrue(headers["Authorization"].startswith("Bearer "))
            self.assertNotIn("OPENROUTER", json.dumps(payload))
            if payload["model"] == DEFAULT_MODEL:
                raise ProviderError("provider_unavailable")
            body = {
                "choices": [{
                    "finish_reason": "stop",
                    "message": {"content": json.dumps({"ingredients": [
                        ai_row(0, "identified", "Ascorbic Acid"),
                    ]})},
                }]
            }
            return 200, json.dumps(body).encode()

        provider = OpenRouterNormalizationProvider(
            api_key="test-key", model=DEFAULT_MODEL, fallback_model=DEFAULT_FALLBACK_MODEL,
            transport=transport,
        )
        output = provider.resolve(["Vit C"])
        self.assertEqual(output["ingredients"][0]["normalizedName"], "Ascorbic Acid")
        self.assertEqual(provider.last_model, DEFAULT_FALLBACK_MODEL)
        self.assertIn(DEFAULT_MODEL, calls)
        self.assertIn(DEFAULT_FALLBACK_MODEL, calls)

    def test_openrouter_chat_disables_collection_and_requires_zero_retention(self):
        def transport(url, payload, headers, timeout):
            self.assertEqual(
                payload["provider"], {"data_collection": "deny", "zdr": True}
            )
            return 200, b'{"choices":[{"finish_reason":"stop","message":{"content":"{}"}}]}'

        provider = OpenRouterNormalizationProvider(
            api_key="test-key", model=DEFAULT_MODEL,
            base_url="https://openrouter.ai/api/v1", transport=transport,
        )
        self.assertEqual(
            provider.complete_messages(
                [{"role": "user", "content": "Fictional test"}],
                schema={"type": "object"}, schema_name="test",
            ),
            {},
        )

    def test_unconfigured_provider(self):
        provider = OpenRouterNormalizationProvider(api_key="", model=DEFAULT_MODEL)
        with self.assertRaises(ProviderError) as caught:
            provider.resolve(["Vit C"])
        self.assertEqual(str(caught.exception), "provider_unconfigured")

    def test_from_environment_uses_openrouter_defaults(self):
        env = {
            "OPENROUTER_API_KEY": "sk-test-not-real",
            "OPENAI_API_KEY": "",
        }
        with patch.dict(os.environ, env, clear=True), patch("Backend.ai_normalization.load_backend_env"):
            provider = OpenRouterNormalizationProvider.from_environment()
        self.assertEqual(provider.model, DEFAULT_MODEL)
        self.assertEqual(provider.fallback_model, DEFAULT_FALLBACK_MODEL)
        self.assertEqual(provider.base_url, "https://openrouter.ai/api/v1")
        self.assertTrue(provider.api_key.startswith("sk-test-"))

    def test_chunked_read_stops_at_wall_clock_deadline(self):
        clock = {"now": 1_000.0}

        def monotonic():
            return clock["now"]

        class Drip(HTTPResponse):
            def __init__(self):
                self.fp = None
                self.reads = 0
                self.requested = []
                self.status = 200

            def read1(self, amt=-1):
                self.reads += 1
                self.requested.append(amt)
                clock["now"] += 0.05
                size = 1 if amt is None or amt < 0 else amt
                return b"x" * size

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, tb):
                return False

        drip = Drip()
        provider = OpenRouterNormalizationProvider(
            api_key="test-key",
            model="slow-model",
            fallback_model=None,
            timeout=30.0,
            deadline_seconds=0.12,
        )
        with patch("Backend.ai_normalization.time.monotonic", monotonic), patch(
            "Backend.ai_normalization.urlopen", return_value=drip
        ) as urlopen_mock:
            with self.assertRaises(ProviderError) as caught:
                provider.complete_messages(
                    [{"role": "user", "content": "Fictional test"}],
                    schema={"type": "object"},
                    schema_name="test",
                )
        self.assertAlmostEqual(urlopen_mock.call_args.kwargs["timeout"], 0.12, places=3)
        self.assertEqual(str(caught.exception), "provider_unavailable")
        self.assertGreaterEqual(drip.reads, 2)
        self.assertLess(drip.reads, 20)
        self.assertTrue(drip.requested)
        self.assertTrue(all(size is not None and size <= 65_536 for size in drip.requested))
        self.assertLess(clock["now"], 1_000.12 + 0.2)

    def test_fallback_attempt_uses_remaining_wall_clock_budget(self):
        clock = {"now": 500.0}

        def monotonic():
            return clock["now"]

        calls = []

        def transport(url, payload, headers, timeout):
            calls.append((payload["model"], timeout))
            if payload["model"] == "primary-model":
                clock["now"] += 0.07
                raise ProviderError("provider_unavailable")
            body = {
                "choices": [{
                    "finish_reason": "stop",
                    "message": {"content": "{}"},
                }]
            }
            return 200, json.dumps(body).encode()

        provider = OpenRouterNormalizationProvider(
            api_key="test-key",
            model="primary-model",
            fallback_model="fallback-model",
            timeout=30.0,
            deadline_seconds=0.10,
            transport=transport,
        )
        with patch("Backend.ai_normalization.time.monotonic", monotonic):
            result = provider.complete_messages(
                [{"role": "user", "content": "Fictional test"}],
                schema={"type": "object"},
                schema_name="test",
            )
        self.assertEqual(result, {})
        self.assertEqual([model for model, _timeout in calls], ["primary-model", "fallback-model"])
        primary_timeout, fallback_timeout = calls[0][1], calls[1][1]
        self.assertAlmostEqual(primary_timeout, 0.10, places=3)
        self.assertAlmostEqual(fallback_timeout, 0.03, places=3)
        self.assertLess(fallback_timeout, primary_timeout)
        self.assertLess(sum(timeout for _model, timeout in calls), 30.0)
        self.assertLess(clock["now"] - 500.0, 0.10)

    def test_response_byte_cap_still_rejects_oversized_body(self):
        class Endless(HTTPResponse):
            def __init__(self):
                self.fp = None
                self.reads = 0
                self.total = 0
                self.status = 200

            def read1(self, amt=-1):
                self.reads += 1
                if self.total >= 4_000_000:
                    return b""
                size = 1 if amt is None or amt < 0 else amt
                self.total += size
                return b"x" * size

            def __enter__(self):
                return self

            def __exit__(self, exc_type, exc, tb):
                return False

        body = Endless()
        provider = OpenRouterNormalizationProvider(
            api_key="test-key",
            model="big-model",
            fallback_model=None,
            timeout=30.0,
            deadline_seconds=30.0,
        )
        with patch("Backend.ai_normalization.urlopen", return_value=body):
            with self.assertRaises(ProviderError) as caught:
                provider.complete_messages(
                    [{"role": "user", "content": "Fictional test"}],
                    schema={"type": "object"},
                    schema_name="test",
                )
        self.assertEqual(str(caught.exception), "provider_invalid_response")
        self.assertGreater(body.total, 1_000_000)
        self.assertLess(body.total, 4_000_000)


class EndpointTests(unittest.TestCase):
    def post(self, body, provider=None, claims=None, db=None):
        handler = object.__new__(APIHandler)
        handler.path = "/api/v1/ingredients/resolve"
        handler.command = "POST"
        handler.authenticated_claims = claims
        encoded = json.dumps(body).encode()
        handler.headers = {"Content-Type": "application/json", "Content-Length": str(len(encoded))}
        handler.rfile = io.BytesIO(encoded)
        handler.server = SimpleNamespace(
            db=db or SimpleNamespace(collection=lambda name: (_ for _ in ()).throw(RuntimeError("offline"))),
            catalog=APPROVED, database_id="test", demo_mode=True, reference_index=reference_index(),
            ai_provider=provider,
        )
        captured = {}
        handler._send = lambda status, payload: captured.update(status=status, body=payload)
        handler.do_POST()
        return captured

    def test_ai_false_is_catalog_only(self):
        captured = self.post({"contractVersion": 1, "ingredients": ["Vit C"], "ai": False})
        self.assertEqual(captured["status"], 200)
        self.assertNotIn("providerStatus", captured["body"])
        self.assertEqual(captured["body"]["status"], "ok")
        self.assertEqual(captured["body"]["coverage"], "unknown")
        self.assertEqual(captured["body"]["ingredients"][0]["mapping"], "ambiguous")
        self.assertEqual(captured["body"]["ingredients"][0]["status"], "tentative")

    def test_default_ai_primary_resolves_and_keeps_analysis_input(self):
        provider = FakeProvider({"ingredients": [
            ai_row(0, "identified", "Ascorbic Acid"),
            ai_row(1, "identified", "Water"),
        ]})
        captured = self.post(
            {"contractVersion": 1, "ingredients": ["Vit C", "Aqua"],
             "format": "analysis-input", "productID": "serum", "listStatus": "complete"},
            provider=provider,
        )
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual(body["status"], "ok")
        self.assertEqual(body["coverage"], "complete")
        self.assertEqual(body["providerStatus"], "ok")
        self.assertEqual(body["promptVersion"], "ingredient-matching-v2")
        self.assertEqual([row["status"] for row in body["ingredients"]], ["identified", "identified"])
        self.assertEqual([row["mapping"] for row in body["ingredients"]], ["confirmed", "confirmed"])
        row = body["analysisInput"]["products"][0]["ingredients"][0]
        self.assertEqual(row["status"], "matched")
        self.assertEqual(row["canonicalName"], "Ascorbic Acid")

    def test_catalog_persistence_requires_authorized_writer_before_ai(self):
        provider = FakeProvider({"ingredients": [
            ai_row(0, "identified", "Water"),
        ]})
        captured = self.post(
            {
                "contractVersion": 1,
                "ingredients": ["Aqua"],
                "productID": "shared-product",
                "persist": True,
                "sourceType": "catalog",
            },
            provider=provider,
            claims={"uid": "ordinary-user"},
        )
        self.assertEqual(captured["status"], 403)
        self.assertEqual(captured["body"]["error"]["code"], "FORBIDDEN")
        self.assertEqual(len(provider.calls), 0)

    def test_catalog_writer_claim_can_persist_catalog_record(self):
        provider = FakeProvider({"ingredients": [
            ai_row(0, "identified", "Water"),
        ]})
        captured = self.post(
            {
                "contractVersion": 1,
                "ingredients": ["Aqua"],
                "productID": "shared-product",
                "persist": True,
                "sourceType": "catalog",
            },
            provider=provider,
            claims={"uid": "catalog-admin", "catalogWriter": True},
            db=FakeFirestore(),
        )
        self.assertEqual(captured["status"], 200)
        self.assertTrue(captured["body"]["persisted"])
        self.assertEqual(len(provider.calls), 1)

    def test_ai_failure_returns_full_unknown_list_not_bare_error(self):
        provider = FakeProvider(error=ProviderError("provider_rate_limited"))
        texts = ["Vit C", "Aqua"]
        captured = self.post({"contractVersion": 1, "ingredients": texts}, provider=provider)
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual(body["status"], "failed")
        self.assertEqual(body["failureCode"], "provider_rate_limited")
        self.assertEqual(body["coverage"], "unknown")
        self.assertEqual(body["providerStatus"], "provider_rate_limited")
        self.assertEqual([row["originalText"] for row in body["ingredients"]], texts)
        self.assertEqual([row["status"] for row in body["ingredients"]], ["unknown", "unknown"])
        self.assertEqual([row["reason"] for row in body["ingredients"]], ["ai-unavailable", "ai-unavailable"])

    def test_bad_ai_flag(self):
        self.assertEqual(self.post({"contractVersion": 1, "ingredients": ["Aqua"], "ai": "yes"})["status"], 400)


LIVE = os.environ.get("AESTHELITY_LIVE_AI_TEST") == "1"


@unittest.skipUnless(LIVE, "set AESTHELITY_LIVE_AI_TEST=1 to run the live OpenRouter smoke test")
class LiveAINormalizationTests(unittest.TestCase):
    def test_messy_labels_then_engine_accepts_adapter_output(self):
        from Backend.ai_normalization import load_backend_env
        from Backend.ingredient_catalog import load_reference_index

        load_backend_env()
        provider = OpenRouterNormalizationProvider.from_environment()
        if not provider.api_key:
            self.fail("OPENROUTER_API_KEY is not set")
        texts = ["Vit C", "niacinimide", "sodium hyaluronate", "parfum", "retinyl palmitat", "blurred txt"]
        reference = load_reference_index(APPROVED)
        updated, status, model, run = match_ingredients(texts, APPROVED, reference, provider=provider)
        print("")
        print(f"live providerStatus={status} run={run} model={model}")
        for row in updated:
            print(
                "live label:",
                json.dumps({
                    "originalText": row["originalText"],
                    "status": row["status"],
                    "mapping": row["mapping"],
                    "normalizedName": row.get("normalizedName"),
                    "bestGuess": row.get("bestGuess"),
                    "ingredientID": row.get("ingredientID"),
                    "suggestedID": row.get("suggestedID"),
                    "reason": row.get("reason"),
                }, ensure_ascii=False),
            )
        self.assertIn(run, {"ok", "failed"})
        self.assertIn(status, {"ok", "provider_unavailable", "provider_rate_limited",
                               "provider_invalid_response", "provider_incomplete_or_refused",
                               "provider_unconfigured", "provider_schema_unsupported"})
        if run == "ok":
            by_text = {row["originalText"]: row for row in updated}
            self.assertEqual(by_text["sodium hyaluronate"]["status"], "identified")
            self.assertEqual(by_text["parfum"]["status"], "identified")
            self.assertNotEqual(by_text["blurred txt"]["status"], "identified")
        product = analysis_product("messy-label", updated, APPROVED, list_status="complete")
        envelope = analysis_normalization(
            [product], catalog_version=APPROVED["version"], provider_status=status,
            model=model, prompt_version="ingredient-matching-v2",
        )
        engine = ENGINE
        products, _, has_unresolved, unresolved = engine._validate_inputs(
            envelope, {"period": "am", "recordedAllergies": {"status": "known", "ingredientIDs": []}},
            canonical_records(APPROVED), [CAUTION_REFERENCE],
        )
        reasons = [item["reasonCode"] for item in unresolved]
        self.assertNotIn("canonical-name-not-found", reasons)
        self.assertNotIn("canonical-name-ambiguous", reasons)
        self.assertEqual(products[0]["normalizedRows"][2]["originalText"], "sodium hyaluronate")
        print(f"live engine: has_unresolved={has_unresolved} reasonCodes={reasons}")


if __name__ == "__main__":
    unittest.main()
