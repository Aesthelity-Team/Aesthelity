"""#98 resolve output -> #99 AI analysis engine input (Backend/analysis_engine_input.py)."""

import copy
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from Backend.analysis_api import APIHandler
from Backend.analysis_engine_input import (
    AnalysisInputAdapterError,
    analysis_normalization,
    analysis_product,
    analysis_routine_normalization,
    analysis_row,
    canonical_records,
    derive_list_status,
)
from Backend.ingredient_catalog import ReferenceIndex, build_catalog, parse_cosing_csv, resolve_ingredient_texts


ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
APPROVED = json.loads(BUNDLED.read_text(encoding="utf-8"))
ANALYSIS_BRANCH_FILE = "origin/99-ai-analysis-engine:analysis_engine/ai_analysis.py"
_ENGINE_TMP = None

CSV = """COSING Ref No,INCI name,INN name,Ph. Eur. Name,CAS No,EINECS/ELINCS No,Chem/IUPAC Name / Description,Restriction,Function,Update Date
31959,"AQUA","water","",7732-18-5,231-791-2,"Water","","SOLVENT",01/01/2010
40001,"RETINOL","","",68-26-8,200-683-7,"","","SKIN CONDITIONING",01/01/2010
40002,"GLYCOLIC ACID","","",79-14-1,201-180-5,"","","EXFOLIATING",01/01/2010
40003,"4-ISOBUTYLRESORCINOL","","",18979-62-9,,"","","ANTIOXIDANT",01/01/2010
"""


def reference_index():
    return ReferenceIndex(build_catalog(parse_cosing_csv(CSV), APPROVED, version="test"))


def resolve(texts):
    return resolve_ingredient_texts(texts, APPROVED, reference_index())


class RowMappingTests(unittest.TestCase):
    def setUp(self):
        self.rows = resolve(["Aqua", "4-Isobutylresorcinol", "Mystery Complex 9", "Vitamin E", "   "])
        self.product = analysis_product("p1", self.rows, APPROVED, list_status="complete")

    def test_every_mapping_has_a_status(self):
        self.assertEqual([row["mapping"] for row in self.rows],
                         ["confirmed", "uncertain", "unmatched", "ambiguous", "unmatched"])
        self.assertEqual([row["status"] for row in self.product["ingredients"]],
                         ["matched", "uncertain", "unknown", "unknown", "unknown"])

    def test_confirmed_uses_exact_approved_name(self):
        aqua = self.product["ingredients"][0]
        self.assertEqual(aqua["canonicalName"], "Water")
        self.assertIsNone(aqua["proposedName"])

    def test_uncertain_keeps_proposal_and_stays_out_of_matched(self):
        row = self.product["ingredients"][1]
        self.assertIsNone(row["canonicalName"])
        self.assertEqual(row["proposedName"], "4-ISOBUTYLRESORCINOL")
        self.assertIn("4-isobutylresorcinol", row["reason"])

    def test_tentative_best_guess_maps_to_proposed_name(self):
        """#99 uncertain rows need proposedName from #98 bestGuess (AI tentative)."""

        row = analysis_row(
            {
                "originalText": "maybe niacinamide?",
                "mapping": "uncertain",
                "status": "tentative",
                "bestGuess": "Niacinamide",
                "explanation": "uncertain OCR",
                "reason": "ai-tentative: uncertain OCR",
                "suggestedID": None,
                "canonicalName": None,
            },
            0,
            {item["id"]: item["name"] for item in APPROVED["ingredients"]},
        )
        self.assertEqual(row["status"], "uncertain")
        self.assertEqual(row["proposedName"], "Niacinamide")
        self.assertIsNone(row["canonicalName"])
        self.assertIn("ai-tentative", row["reason"])

    def test_unknown_reasons(self):
        _, _, mystery, vitamin_e, empty = self.product["ingredients"]
        self.assertEqual(mystery["reason"], "not_in_catalog")
        self.assertEqual(vitamin_e["reason"], "ambiguous: tocopherol, tocopheryl-acetate")
        self.assertEqual(empty["reason"], "empty_input")
        for row in (mystery, vitamin_e, empty):
            self.assertIsNone(row["canonicalName"])
            self.assertIsNone(row["proposedName"])

    def test_original_text_index_and_contract_keys(self):
        texts = ["Aqua", "4-Isobutylresorcinol", "Mystery Complex 9", "Vitamin E", "   "]
        self.assertEqual([row["originalText"] for row in self.product["ingredients"]], texts)
        self.assertEqual([row["index"] for row in self.product["ingredients"]], list(range(5)))
        for row in self.product["ingredients"]:
            self.assertEqual(set(row), {"index", "originalText", "status", "canonicalName", "proposedName", "reason"})
            self.assertIsInstance(row["reason"], str)

    def test_confirmed_outside_approved_catalog_is_never_matched(self):
        row = analysis_row({"originalText": "X", "mapping": "confirmed", "ingredientID": "not-approved"}, 0, {})
        self.assertEqual(row["status"], "unknown")

    def test_unknown_mapping_rejected(self):
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_row({"originalText": "X", "mapping": "maybe"}, 0, {})


class ListStatusTests(unittest.TestCase):
    def test_derivation(self):
        self.assertEqual(derive_list_status([]), "unavailable")
        self.assertEqual(derive_list_status([{}]), "partial")
        self.assertEqual(derive_list_status([{}], "complete"), "complete")
        with self.assertRaises(AnalysisInputAdapterError):
            derive_list_status([{}], "unavailable")
        with self.assertRaises(AnalysisInputAdapterError):
            derive_list_status([], "full")

    def test_envelope(self):
        products = [analysis_product("a", resolve(["Aqua"]), APPROVED, list_status="complete"),
                    analysis_product("b", [], APPROVED)]
        envelope = analysis_normalization(products, catalog_version=3, normalization_id="n1")
        self.assertEqual(envelope["contractVersion"], 1)
        self.assertEqual(envelope["normalizationID"], "n1")
        self.assertEqual(envelope["providerStatus"], "ok")
        self.assertEqual(envelope["products"][1]["listStatus"], "unavailable")
        self.assertTrue(envelope["uncertaintyPreserved"])
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_normalization([products[0], products[0]])


class CanonicalRecordTests(unittest.TestCase):
    def test_default_is_the_approved_catalog_with_unique_names(self):
        records = canonical_records(APPROVED)
        self.assertEqual(len(records), len(APPROVED["ingredients"]))
        self.assertEqual(records[0], {"id": "water", "canonicalName": "Water", "classes": ["solvent"]})
        keys = [" ".join(r["canonicalName"].casefold().split()) for r in records]
        self.assertEqual(len(keys), len(set(keys)))

    def test_reference_records_skip_name_clashes(self):
        index = reference_index()
        index.records["clash"] = {"id": "clash", "canonicalName": "WATER", "classes": []}
        records = canonical_records(APPROVED, index, include_reference=True)
        ids = {r["id"] for r in records}
        self.assertIn("4-isobutylresorcinol", ids)
        self.assertNotIn("clash", ids)


class EndpointTests(unittest.TestCase):
    def post(self, body):
        handler = object.__new__(APIHandler)
        handler.path = "/api/v1/ingredients/resolve"
        handler.command = "POST"
        encoded = json.dumps(body).encode()
        handler.headers = {"Content-Type": "application/json", "Content-Length": str(len(encoded))}
        handler.rfile = io.BytesIO(encoded)
        handler.server = SimpleNamespace(
            db=SimpleNamespace(collection=lambda name: (_ for _ in ()).throw(RuntimeError("offline"))),
            catalog=APPROVED, database_id="test", demo_mode=True, reference_index=reference_index(),
        )
        captured = {}
        handler._send = lambda status, payload: captured.update(status=status, body=payload)
        handler.do_POST()
        return captured

    def test_default_response_unchanged(self):
        # Catalog-only opt-out: AI is primary by default for #98.
        captured = self.post({"contractVersion": 1, "ingredients": ["Aqua"], "ai": False})
        self.assertEqual(captured["status"], 200)
        self.assertNotIn("analysisInput", captured["body"])
        self.assertEqual(captured["body"]["coverage"], "complete")
        self.assertEqual(captured["body"]["ingredients"][0]["status"], "identified")

    def test_analysis_input_format(self):
        captured = self.post({"contractVersion": 1, "ingredients": ["Aqua", "Vitamin E"], "ai": False,
                              "format": "analysis-input", "productID": "serum", "listStatus": "complete"})
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual([row["mapping"] for row in body["ingredients"]], ["confirmed", "ambiguous"])
        product = body["analysisInput"]["products"][0]
        self.assertEqual(product["productID"], "serum")
        self.assertEqual([row["status"] for row in product["ingredients"]], ["matched", "unknown"])

    def test_bad_format_or_list_status(self):
        self.assertEqual(self.post({"contractVersion": 1, "ingredients": ["Aqua"], "ai": False,
                                    "format": "other"})["status"], 400)
        self.assertEqual(self.post({"contractVersion": 1, "ingredients": ["Aqua"], "ai": False,
                                    "format": "analysis-input", "listStatus": "full"})["status"], 400)


def _load_analysis_engine():
    """Load ai_analysis.py from the #99 branch into a temp dir; nothing is vendored."""

    global _ENGINE_TMP
    try:
        source = subprocess.run(["git", "show", ANALYSIS_BRANCH_FILE], cwd=ROOT, capture_output=True,
                                text=True, check=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    # Keep TemporaryDirectory alive for the process; it removes the dir on exit.
    _ENGINE_TMP = tempfile.TemporaryDirectory(prefix="ai-analysis-")
    path = Path(_ENGINE_TMP.name) / "ai_analysis_branch99.py"
    path.write_text(source, encoding="utf-8")
    spec = importlib.util.spec_from_file_location("ai_analysis_branch99", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


ENGINE = _load_analysis_engine()

CAUTION_REFERENCE = {
    "referenceID": "retinoid-exfoliant", "referenceVersion": 1, "reviewStatus": "approved",
    "source": {"title": "t", "publisher": "p", "url": "https://example.org/r", "accessedOn": "2026-11-15"},
    "claim": "A retinoid with an exfoliant may increase irritation.",
    "canonicalIngredientIDs": ["retinol"], "canonicalIngredientClasses": ["exfoliant"],
    "matchCriteria": {"anyIngredientIDs": ["retinol"], "allIngredientClasses": ["exfoliant"]},
    "allowedOutcome": "caution", "severity": "moderate", "limitations": ["Possibility only."],
}


class FakeProvider:
    model = "fake"

    def __init__(self, output):
        self.output = output
        self.contexts = []

    def generate(self, context):
        self.contexts.append(copy.deepcopy(context))
        return copy.deepcopy(self.output)


@unittest.skipIf(ENGINE is None, f"{ANALYSIS_BRANCH_FILE} not available (git fetch origin 99-ai-analysis-engine)")
class AnalysisEngineIntegrationTests(unittest.TestCase):
    def normalization(self):
        retinol = analysis_product("retinol-serum", resolve(["Aqua", "Retinol", "4-Isobutylresorcinol"]),
                                   APPROVED, list_status="complete")
        toner = analysis_product("glycolic-toner", resolve(["Water", "Glycolic Acid", "Vitamin E", "Mystery"]),
                                 APPROVED, list_status="complete")
        empty = analysis_product("unknown-cream", [], APPROVED)
        return analysis_normalization([retinol, toner, empty], catalog_version=APPROVED["version"],
                                      normalization_id="integration")

    def test_validate_inputs_accepts_adapter_output(self):
        products, _, has_unresolved, unresolved = ENGINE._validate_inputs(
            self.normalization(), {"period": "pm", "recordedAllergies": {"status": "known", "ingredientIDs": []}},
            canonical_records(APPROVED), [CAUTION_REFERENCE],
        )
        resolved = {p["productID"]: [r["ingredientID"] for r in p["ingredients"]] for p in products}
        self.assertEqual(resolved, {"retinol-serum": ["water", "retinol"],
                                    "glycolic-toner": ["water", "glycolic-acid"], "unknown-cream": []})
        self.assertTrue(has_unresolved)
        reasons = sorted(item["reasonCode"] for item in unresolved)
        self.assertEqual(reasons, ["normalization-uncertain", "normalization-unknown",
                                   "normalization-unknown", "unavailable-list"])
        self.assertNotIn("canonical-name-not-found", reasons)
        self.assertNotIn("canonical-name-ambiguous", reasons)
        texts = [row["originalText"] for p in products for row in p["normalizedRows"]]
        self.assertEqual(texts, ["Aqua", "Retinol", "4-Isobutylresorcinol", "Water", "Glycolic Acid", "Vitamin E", "Mystery"])

    def test_full_analysis_runs_on_adapter_output(self):
        provider = FakeProvider({"assessment": "findings", "findings": [{
            "referenceIDs": ["retinoid-exfoliant"], "outcome": "caution",
            "productIDs": ["retinol-serum", "glycolic-toner"], "ingredientIDs": ["retinol", "glycolic-acid"],
            "explanation": "Retinol with an exfoliant may increase irritation.", "reason": "Reference matches.",
        }]})
        result = ENGINE.analyze_normalized_routine(
            self.normalization(), {"period": "pm", "recordedAllergies": {"status": "known", "ingredientIDs": []}},
            canonical_records(APPROVED), [CAUTION_REFERENCE], provider,
        )
        self.assertEqual(result["analysisProviderStatus"], "ok")
        self.assertEqual(result["completeness"], "incomplete")
        self.assertEqual(result["coverage"]["unknownIngredientCount"], 3)
        cautions = [f for f in result["findings"] if f["outcome"] == "caution"]
        self.assertEqual(len(cautions), 1)
        self.assertEqual(cautions[0]["ingredientIDs"], ["retinol", "glycolic-acid"])
        sent = {p["productID"]: [r["ingredientID"] for r in p["ingredients"]] for p in provider.contexts[0]["products"]}
        self.assertNotIn("4-isobutylresorcinol", sent["retinol-serum"])


def product_envelope(product_id, texts, list_status=None, **kwargs):
    """One product as the resolve endpoint's analysisInput would carry it."""

    product = analysis_product(product_id, resolve(texts), APPROVED, list_status=list_status)
    return analysis_normalization([product], catalog_version=APPROVED["version"],
                                  normalization_id=f"n-{product_id}", **kwargs)


class RoutineNormalizationTests(unittest.TestCase):
    def test_merges_products_and_keeps_provenance(self):
        cleanser = product_envelope("cleanser", ["Aqua", "Glycolic Acid"], "complete")
        serum = product_envelope("serum", ["Water", "Retinol"], "complete")
        routine = analysis_routine_normalization([{"analysisInput": cleanser}, serum], normalization_id="r1")
        self.assertEqual(routine["contractVersion"], 1)
        self.assertEqual(routine["normalizationID"], "r1")
        self.assertEqual([p["productID"] for p in routine["products"]], ["cleanser", "serum"])
        self.assertEqual([r["originalText"] for r in routine["products"][1]["ingredients"]], ["Water", "Retinol"])
        self.assertEqual([r["index"] for r in routine["products"][1]["ingredients"]], [0, 1])
        self.assertEqual(routine["sourceNormalizationIDs"], {"cleanser": ["n-cleanser"], "serum": ["n-serum"]})
        self.assertEqual(routine["canonicalDataVersion"], APPROVED["version"])
        self.assertEqual(routine["providerStatus"], "ok")

    def test_duplicate_product_dedupes_or_rejects(self):
        serum = product_envelope("serum", ["Retinol"], "complete")
        routine = analysis_routine_normalization([serum, copy.deepcopy(serum)])
        self.assertEqual([p["productID"] for p in routine["products"]], ["serum"])
        other = product_envelope("serum", ["Aqua"], "complete")
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_routine_normalization([serum, other])

    def test_routine_list_status(self):
        done = product_envelope("a", ["Aqua"], "complete")
        partial = product_envelope("b", ["Retinol"])
        none = product_envelope("c", [])
        self.assertEqual(analysis_routine_normalization([done])["routineListStatus"], "complete")
        mixed = analysis_routine_normalization([done, partial])
        self.assertEqual(mixed["routineListStatus"], "partial")
        self.assertEqual([p["listStatus"] for p in mixed["products"]], ["complete", "partial"])
        self.assertEqual(analysis_routine_normalization([done, none])["routineListStatus"], "partial")
        self.assertEqual(analysis_routine_normalization([none])["routineListStatus"], "unavailable")

    def test_unknowns_and_uncertain_rows_preserved(self):
        env = product_envelope("toner", ["Aqua", "4-Isobutylresorcinol", "Mystery Complex 9", "Vitamin E"], "complete")
        routine = analysis_routine_normalization([env])
        self.assertEqual([r["status"] for r in routine["products"][0]["ingredients"]],
                         ["matched", "uncertain", "unknown", "unknown"])
        self.assertEqual(routine["products"][0]["ingredients"], env["products"][0]["ingredients"])
        self.assertTrue(routine["uncertaintyPreserved"])

    def test_provider_status_and_versions(self):
        ok = product_envelope("a", ["Aqua"], "complete")
        down = product_envelope("b", ["Aqua"], "complete", provider_status="unavailable")
        routine = analysis_routine_normalization([ok, down])
        self.assertEqual(routine["providerStatus"], "unavailable")
        ok2 = dict(product_envelope("c", ["Aqua"], "complete"), canonicalDataVersion=999)
        self.assertIsNone(analysis_routine_normalization([ok, ok2])["canonicalDataVersion"])

    def test_empty_and_invalid_input(self):
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_routine_normalization([])
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_routine_normalization([{"contractVersion": 2, "products": []}])
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_routine_normalization(["not-an-object"])
        bad = product_envelope("a", ["Aqua", "Retinol"], "complete")
        bad["products"][0]["ingredients"][1]["index"] = 5
        with self.assertRaises(AnalysisInputAdapterError):
            analysis_routine_normalization([bad])


@unittest.skipIf(ENGINE is None, f"{ANALYSIS_BRANCH_FILE} not available (git fetch origin 99-ai-analysis-engine)")
class RoutineEngineContractTests(unittest.TestCase):
    """Routine helper output fed straight into Mia's real #99 engine."""

    CONTEXT = {"period": "pm", "recordedAllergies": {"status": "known", "ingredientIDs": []}}

    def routine(self):
        return analysis_routine_normalization([
            product_envelope("retinol-serum", ["Aqua", "Retinol", "4-Isobutylresorcinol"], "complete"),
            {"analysisInput": product_envelope("glycolic-toner", ["Water", "Glycolic Acid", "Mystery"], "complete")},
            product_envelope("unknown-cream", []),
        ], normalization_id="routine-contract")

    def test_validate_inputs_accepts_routine(self):
        products, _, has_unresolved, unresolved = ENGINE._validate_inputs(
            self.routine(), self.CONTEXT, canonical_records(APPROVED), [CAUTION_REFERENCE])
        resolved = {p["productID"]: [r["ingredientID"] for r in p["ingredients"]] for p in products}
        self.assertEqual(resolved, {"retinol-serum": ["water", "retinol"],
                                    "glycolic-toner": ["water", "glycolic-acid"], "unknown-cream": []})
        self.assertTrue(has_unresolved)
        self.assertEqual(sorted(u["reasonCode"] for u in unresolved),
                         ["normalization-uncertain", "normalization-unknown", "unavailable-list"])

    def test_analyze_normalized_routine_returns_result(self):
        provider = FakeProvider({"assessment": "findings", "findings": [{
            "referenceIDs": ["retinoid-exfoliant"], "outcome": "caution",
            "productIDs": ["retinol-serum", "glycolic-toner"], "ingredientIDs": ["retinol", "glycolic-acid"],
            "explanation": "Retinol with an exfoliant may increase irritation.", "reason": "Reference matches.",
        }]})
        result = ENGINE.analyze_normalized_routine(
            self.routine(), self.CONTEXT, canonical_records(APPROVED), [CAUTION_REFERENCE], provider)
        self.assertEqual(result["contractVersion"], 1)
        self.assertEqual(result["normalizationID"], "routine-contract")
        self.assertEqual(result["analysisProviderStatus"], "ok")
        self.assertEqual(result["productIDs"], ["retinol-serum", "glycolic-toner", "unknown-cream"])
        self.assertEqual(result["completeness"], "incomplete")
        self.assertEqual(len([f for f in result["findings"] if f["outcome"] == "caution"]), 1)

    def test_all_complete_routine_can_be_complete(self):
        routine = analysis_routine_normalization([
            product_envelope("serum", ["Retinol"], "complete"),
            product_envelope("toner", ["Glycolic Acid"], "complete"),
        ])
        self.assertEqual(routine["routineListStatus"], "complete")
        provider = FakeProvider({"assessment": "no_findings", "findings": []})
        result = ENGINE.analyze_normalized_routine(
            routine, self.CONTEXT, canonical_records(APPROVED), [CAUTION_REFERENCE], provider)
        self.assertEqual(result["completeness"], "complete")
        self.assertEqual(result["outcome"], "noFindings")


if __name__ == "__main__":
    unittest.main()
