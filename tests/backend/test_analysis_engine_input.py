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
    analysis_row,
    canonical_records,
    derive_list_status,
)
from Backend.ingredient_catalog import ReferenceIndex, build_catalog, parse_cosing_csv, resolve_ingredient_texts


ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
APPROVED = json.loads(BUNDLED.read_text(encoding="utf-8"))
ANALYSIS_BRANCH_FILE = "origin/99-ai-analysis-engine:analysis_engine/ai_analysis.py"

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
        captured = self.post({"contractVersion": 1, "ingredients": ["Aqua"]})
        self.assertEqual(captured["status"], 200)
        self.assertNotIn("analysisInput", captured["body"])

    def test_analysis_input_format(self):
        captured = self.post({"contractVersion": 1, "ingredients": ["Aqua", "Vitamin E"], "format": "analysis-input",
                              "productID": "serum", "listStatus": "complete"})
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual([row["mapping"] for row in body["ingredients"]], ["confirmed", "ambiguous"])
        product = body["analysisInput"]["products"][0]
        self.assertEqual(product["productID"], "serum")
        self.assertEqual([row["status"] for row in product["ingredients"]], ["matched", "unknown"])

    def test_bad_format_or_list_status(self):
        self.assertEqual(self.post({"contractVersion": 1, "ingredients": ["Aqua"], "format": "other"})["status"], 400)
        self.assertEqual(self.post({"contractVersion": 1, "ingredients": ["Aqua"], "format": "analysis-input",
                                    "listStatus": "full"})["status"], 400)


def _load_analysis_engine():
    """Load ai_analysis.py from the #99 branch into a temp dir; nothing is vendored."""

    try:
        source = subprocess.run(["git", "show", ANALYSIS_BRANCH_FILE], cwd=ROOT, capture_output=True,
                                text=True, check=True, timeout=20).stdout
    except (OSError, subprocess.SubprocessError):
        return None
    directory = tempfile.mkdtemp(prefix="ai-analysis-")
    path = Path(directory) / "ai_analysis_branch99.py"
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


if __name__ == "__main__":
    unittest.main()
