"""AI fallback for #98 unresolved rows (Backend/ai_normalization.py)."""

import copy
import io
import json
import os
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

from Backend.analysis_api import APIHandler
from Backend.analysis_engine.normalization import ProviderError
from Backend.analysis_engine_input import analysis_normalization, analysis_product, canonical_records
from Backend.ai_normalization import (
    DEFAULT_FALLBACK_MODEL,
    DEFAULT_MODEL,
    OpenRouterNormalizationProvider,
    apply_ai_normalization,
    looks_noisy,
    needs_ai,
    suggested_name,
)
from Backend.ingredient_catalog import ReferenceIndex, build_catalog, parse_cosing_csv, resolve_ingredient_texts

from test_analysis_engine_input import ANALYSIS_BRANCH_FILE, CAUTION_REFERENCE, ENGINE, _load_analysis_engine


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


def resolve(texts, reference=None):
    return resolve_ingredient_texts(texts, APPROVED, reference if reference is not None else reference_index())


def ai_row(index, status, canonical=None, proposed=None, reason="ok", **extra):
    row = {"index": index, "status": status, "canonicalName": canonical, "proposedName": proposed, "reason": reason}
    row.update(extra)
    return row


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


class HelperTests(unittest.TestCase):
    def test_looks_noisy_and_needs_ai(self):
        self.assertTrue(looks_noisy("blurred txt"))
        self.assertFalse(looks_noisy("Aqua"))
        self.assertFalse(looks_noisy("   "))
        rows = resolve(["Aqua", "4-Isobutylresorcinol", "Mystery Complex 9", "Vitamin E", "   ", "blurred txt"])
        flags = [needs_ai(row) for row in rows]
        self.assertEqual(flags, [False, False, True, True, False, True])

    def test_suggested_name_ignores_ids(self):
        self.assertEqual(suggested_name(ai_row(0, "matched", "Ascorbic Acid", ingredientID="water")), "Ascorbic Acid")
        self.assertIsNone(suggested_name(ai_row(0, "matched", None, ingredientID="water", suggestedID="retinol")))


class ApplyAINormalizationTests(unittest.TestCase):
    def setUp(self):
        self.reference = reference_index()

    def test_reresolve_to_confirmed(self):
        rows = resolve(["niacinimide", "Vit C", "Aqua"], self.reference)
        self.assertEqual([row["mapping"] for row in rows], ["unmatched", "ambiguous", "confirmed"])
        provider = FakeProvider({"ingredients": [
            ai_row(0, "matched", "Niacinamide"),
            ai_row(1, "matched", "Ascorbic Acid"),
        ]})
        updated, status, model, attempted = apply_ai_normalization(
            rows, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "ok")
        self.assertEqual(model, "fake-model")
        self.assertEqual(attempted, 2)
        self.assertEqual(provider.calls, [["niacinimide", "Vit C"]])
        self.assertEqual(updated[0]["mapping"], "confirmed")
        self.assertEqual(updated[0]["ingredientID"], "niacinamide")
        self.assertEqual(updated[0]["canonicalName"], "Niacinamide")
        self.assertEqual(updated[0]["originalText"], "niacinimide")
        self.assertEqual(updated[0]["reason"], "ai-suggested + approved match")
        self.assertEqual(updated[1]["mapping"], "confirmed")
        self.assertEqual(updated[1]["ingredientID"], "ascorbic-acid")
        self.assertEqual(updated[1]["originalText"], "Vit C")
        self.assertEqual(updated[1]["reason"], "ai-suggested + approved match")
        self.assertEqual(updated[2]["ingredientID"], "water")
        self.assertNotEqual(updated[2].get("source"), "ai")

    def test_reresolve_to_uncertain(self):
        rows = resolve(["isobutyl mystery"], self.reference)
        self.assertEqual(rows[0]["mapping"], "unmatched")
        provider = FakeProvider({"ingredients": [ai_row(0, "uncertain", proposed="4-ISOBUTYLRESORCINOL")]})
        updated, status, _, attempted = apply_ai_normalization(
            rows, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "ok")
        self.assertEqual(attempted, 1)
        self.assertEqual(updated[0]["mapping"], "uncertain")
        self.assertEqual(updated[0]["suggestedID"], "4-isobutylresorcinol")
        self.assertIsNone(updated[0]["ingredientID"])
        self.assertFalse(updated[0]["analysisEligible"])
        self.assertIn("ai-suggested + reference-catalog-only", updated[0]["reason"])
        self.assertEqual(updated[0]["originalText"], "isobutyl mystery")

    def test_unknown_stays_unmatched(self):
        rows = resolve(["blurred txt"], self.reference)
        provider = FakeProvider({"ingredients": [ai_row(0, "unknown", reason="gibberish")]})
        updated, status, _, attempted = apply_ai_normalization(
            rows, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "ok")
        self.assertEqual(attempted, 1)
        self.assertEqual(updated[0]["mapping"], "unmatched")
        self.assertIsNone(updated[0]["ingredientID"])
        self.assertEqual(updated[0]["reason"], "not_in_catalog")

    def test_ai_cannot_invent_an_id(self):
        rows = resolve(["Mystery Complex 9"], self.reference)
        provider = FakeProvider({"ingredients": [ai_row(
            0, "matched", "totally-invented-id", ingredientID="water", suggestedID="retinol"
        )]})
        updated, status, _, _ = apply_ai_normalization(rows, APPROVED, self.reference, provider=provider)
        self.assertEqual(status, "ok")
        self.assertEqual(updated[0]["mapping"], "unmatched")
        self.assertIsNone(updated[0]["ingredientID"])
        self.assertIsNone(updated[0]["suggestedID"])
        self.assertEqual(updated[0]["reason"], "ai-suggestion-not-in-catalog")
        self.assertNotEqual(updated[0]["ingredientID"], "water")
        self.assertNotIn("water", (updated[0].get("ingredientID"), updated[0].get("suggestedID")))

    def test_failure_falls_back_to_lookup_only(self):
        original = resolve(["Vit C", "Aqua", "Vitamin E"], self.reference)
        provider = FakeProvider(error=ProviderError("provider_unavailable"))
        updated, status, model, attempted = apply_ai_normalization(
            original, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "provider_unavailable")
        self.assertEqual(model, "fake-model")
        self.assertEqual(attempted, 2)
        self.assertEqual(updated, original)
        self.assertEqual([row["mapping"] for row in updated], ["ambiguous", "confirmed", "ambiguous"])

    def test_only_misses_are_sent(self):
        rows = resolve(["Aqua", "4-Isobutylresorcinol", "Mystery Complex 9", "Vitamin E", "   "], self.reference)
        provider = FakeProvider({"ingredients": [
            ai_row(0, "unknown", reason="no"),
            ai_row(1, "matched", "Tocopherol"),
        ]})
        updated, status, _, attempted = apply_ai_normalization(
            rows, APPROVED, self.reference, provider=provider
        )
        self.assertEqual(status, "ok")
        self.assertEqual(attempted, 2)
        self.assertEqual(provider.calls, [["Mystery Complex 9", "Vitamin E"]])
        self.assertEqual(updated[0]["mapping"], "confirmed")
        self.assertEqual(updated[0]["ingredientID"], "water")
        self.assertEqual(updated[1]["mapping"], "uncertain")
        self.assertEqual(updated[2]["mapping"], "unmatched")
        self.assertEqual(updated[3]["mapping"], "confirmed")
        self.assertEqual(updated[3]["ingredientID"], "tocopherol")
        self.assertEqual(updated[3]["originalText"], "Vitamin E")
        self.assertEqual(updated[3]["reason"], "ai-suggested + approved match")
        self.assertEqual(updated[4]["reason"], "empty_input")

    def test_adapter_reason_and_engine_accept_ai_confirmed_row(self):
        rows = resolve(["Vit C"], self.reference)
        provider = FakeProvider({"ingredients": [ai_row(0, "matched", "Ascorbic Acid")]})
        updated, status, model, _ = apply_ai_normalization(rows, APPROVED, self.reference, provider=provider)
        product = analysis_product("serum", updated, APPROVED, list_status="complete")
        self.assertEqual(product["ingredients"][0]["status"], "matched")
        self.assertEqual(product["ingredients"][0]["canonicalName"], "Ascorbic Acid")
        self.assertEqual(product["ingredients"][0]["reason"], "ai-suggested + approved match")
        envelope = analysis_normalization(
            [product], catalog_version=APPROVED["version"], provider_status=status,
            model=model, prompt_version="ingredient-normalization-v1",
        )
        self.assertEqual(envelope["providerStatus"], "ok")
        self.assertEqual(envelope["model"], "fake-model")
        if ENGINE is None:
            self.skipTest(f"{ANALYSIS_BRANCH_FILE} not available")
        products, _, has_unresolved, unresolved = ENGINE._validate_inputs(
            envelope, {"period": "am", "recordedAllergies": {"status": "known", "ingredientIDs": []}},
            canonical_records(APPROVED), [CAUTION_REFERENCE],
        )
        self.assertEqual(products[0]["ingredients"][0]["ingredientID"], "ascorbic-acid")
        self.assertFalse(has_unresolved)
        self.assertEqual(unresolved, [])


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
                        ai_row(0, "matched", "Ascorbic Acid"),
                    ]})},
                }]
            }
            return 200, json.dumps(body).encode()

        provider = OpenRouterNormalizationProvider(
            api_key="test-key", model=DEFAULT_MODEL, fallback_model=DEFAULT_FALLBACK_MODEL,
            transport=transport,
        )
        output = provider.resolve(["Vit C"])
        self.assertEqual(output["ingredients"][0]["canonicalName"], "Ascorbic Acid")
        self.assertEqual(provider.last_model, DEFAULT_FALLBACK_MODEL)
        self.assertIn(DEFAULT_MODEL, calls)
        self.assertIn(DEFAULT_FALLBACK_MODEL, calls)

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
        with patch.dict(os.environ, env, clear=False):
            os.environ.pop("AESTHELITY_NORMALIZATION_MODEL", None)
            os.environ.pop("AESTHELITY_NORMALIZATION_FALLBACK_MODEL", None)
            os.environ.pop("OPENROUTER_BASE_URL", None)
            os.environ.pop("OPENAI_BASE_URL", None)
            provider = OpenRouterNormalizationProvider.from_environment()
        self.assertEqual(provider.model, DEFAULT_MODEL)
        self.assertEqual(provider.fallback_model, DEFAULT_FALLBACK_MODEL)
        self.assertEqual(provider.base_url, "https://openrouter.ai/api/v1")
        self.assertTrue(provider.api_key.startswith("sk-test-"))


class EndpointTests(unittest.TestCase):
    def post(self, body, provider=None):
        handler = object.__new__(APIHandler)
        handler.path = "/api/v1/ingredients/resolve"
        handler.command = "POST"
        encoded = json.dumps(body).encode()
        handler.headers = {"Content-Type": "application/json", "Content-Length": str(len(encoded))}
        handler.rfile = io.BytesIO(encoded)
        handler.server = SimpleNamespace(
            db=SimpleNamespace(collection=lambda name: (_ for _ in ()).throw(RuntimeError("offline"))),
            catalog=APPROVED, database_id="test", demo_mode=True, reference_index=reference_index(),
            ai_provider=provider,
        )
        captured = {}
        handler._send = lambda status, payload: captured.update(status=status, body=payload)
        handler.do_POST()
        return captured

    def test_default_response_unchanged_without_ai_flag(self):
        captured = self.post({"contractVersion": 1, "ingredients": ["Vit C"]})
        self.assertEqual(captured["status"], 200)
        self.assertNotIn("providerStatus", captured["body"])
        self.assertNotIn("model", captured["body"])
        self.assertEqual(captured["body"]["ingredients"][0]["mapping"], "ambiguous")
        self.assertEqual(
            captured["body"]["ingredients"][0]["candidateIDs"],
            ["ascorbic-acid", "sodium-ascorbyl-phosphate", "magnesium-ascorbyl-phosphate", "ascorbyl-glucoside"],
        )

    def test_ai_flag_resolves_miss_and_keeps_analysis_input(self):
        provider = FakeProvider({"ingredients": [ai_row(0, "matched", "Ascorbic Acid")]})
        captured = self.post(
            {"contractVersion": 1, "ingredients": ["Vit C", "Aqua"], "ai": True,
             "format": "analysis-input", "productID": "serum", "listStatus": "complete"},
            provider=provider,
        )
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual(body["providerStatus"], "ok")
        self.assertEqual([row["mapping"] for row in body["ingredients"]], ["confirmed", "confirmed"])
        self.assertEqual(body["ingredients"][0]["reason"], "ai-suggested + approved match")
        row = body["analysisInput"]["products"][0]["ingredients"][0]
        self.assertEqual(row["status"], "matched")
        self.assertEqual(row["canonicalName"], "Ascorbic Acid")
        self.assertEqual(row["reason"], "ai-suggested + approved match")
        self.assertEqual(body["analysisInput"]["providerStatus"], "ok")

    def test_ai_failure_keeps_lookup_rows(self):
        provider = FakeProvider(error=ProviderError("provider_rate_limited"))
        captured = self.post({"contractVersion": 1, "ingredients": ["Vit C"], "ai": True}, provider=provider)
        self.assertEqual(captured["status"], 200)
        self.assertEqual(captured["body"]["providerStatus"], "provider_rate_limited")
        self.assertEqual(captured["body"]["ingredients"][0]["mapping"], "ambiguous")

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
        catalog_rows = resolve_ingredient_texts(texts, APPROVED, reference)
        updated, status, model, attempted = apply_ai_normalization(
            catalog_rows, APPROVED, reference, provider=provider
        )
        # Per-label report for the operator; never print credentials.
        print("")
        print(f"live providerStatus={status} model={model} attempted={attempted}")
        for row in updated:
            print(
                "live label:",
                json.dumps({
                    "originalText": row["originalText"],
                    "mapping": row["mapping"],
                    "canonicalName": row.get("canonicalName"),
                    "ingredientID": row.get("ingredientID"),
                    "suggestedID": row.get("suggestedID"),
                    "reason": row.get("reason"),
                    "source": row.get("source"),
                }, ensure_ascii=False),
            )
        self.assertIn(status, {"ok", "provider_unavailable", "provider_rate_limited",
                               "provider_invalid_response", "provider_incomplete_or_refused",
                               "provider_unconfigured", "provider_schema_unsupported"})
        by_text = {row["originalText"]: row for row in updated}
        self.assertEqual(by_text["sodium hyaluronate"]["mapping"], "confirmed")
        self.assertEqual(by_text["sodium hyaluronate"]["canonicalName"], "Sodium Hyaluronate")
        self.assertEqual(by_text["parfum"]["mapping"], "confirmed")
        self.assertEqual(by_text["parfum"]["canonicalName"], "Fragrance")
        self.assertNotEqual(by_text["blurred txt"]["mapping"], "confirmed")
        for row in updated:
            if row["mapping"] == "confirmed":
                self.assertIn(row["ingredientID"], {item["id"] for item in APPROVED["ingredients"]})
        product = analysis_product("messy-label", updated, APPROVED, list_status="complete")
        envelope = analysis_normalization(
            [product], catalog_version=APPROVED["version"], provider_status=status,
            model=model, prompt_version="ingredient-normalization-v1",
        )
        engine = ENGINE or _load_analysis_engine()
        if engine is None:
            self.fail(f"{ANALYSIS_BRANCH_FILE} not available")
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
