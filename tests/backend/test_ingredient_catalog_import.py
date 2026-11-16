"""Tests for the full CosIng ingredient catalog import and resolver (#98 follow-up)."""

import argparse
import contextlib
import io
import json
import random
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

from Backend.analysis_api import APIHandler
from Backend.import_ingredient_catalog import BATCH_SIZE, firestore_documents, run, write_documents
from Backend.ingredient_catalog import (
    DATA_PATH,
    ReferenceIndex,
    build_catalog,
    load_source,
    parse_cosing_csv,
    resolve_ingredient_texts,
    write_snapshot,
)
from analysis_engine.product_input import prepare_analysis_input


ROOT = Path(__file__).resolve().parents[2]
BUNDLED = ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"

FIXTURE_CSV = """sep=,

File creation date: 20/02/2016

Ingredients/Fragrance Inventory (CosIng 2),Last update: 15/02/2016

COSING Ref No,INCI name,INN name,Ph. Eur. Name,CAS No,EINECS/ELINCS No,Chem/IUPAC Name / Description,Restriction,Function,Update Date
31959," AQUA","water","aqua purificata",7732-18-5 ,231-791-2 ,"Water","","SOLVENT",01/01/2010
34040,"GLYCERIN","glycerol","glycerolum",56-81-5,200-289-5,"Glycerin is the polyhydric alcohol","","HUMECTANT, SOLVENT",02/02/2011
34041,"glycerin ","","",56-81-5,,"","","SKIN CONDITIONING",02/02/2011
32184,"BHA","butylated hydroxyanisole","",25013-16-5,246-563-8,"BHA is a mixture","III/71","ANTIOXIDANT",03/03/2012
38968,"ZINC OXIDE","zinc oxide","",1314-13-2,215-222-5,"Zinc Oxide","IV/144
VI/30","UV FILTER, COLORANT",04/04/2013
98572,"CI 77947","","",1314-13-2,215-222-5,"inorganic colour","IV/144","COLORANT",04/04/2013
50001,"CAFE EXTRACT","","",,,"","","SKIN CONDITIONING",05/05/2014
50000,"CAFÉ EXTRACT","","",,,"","","SKIN CONDITIONING",05/05/2014
60000,"PHENOXYETHANOL","","",122-99-6,204-589-7,"","V/29","PRESERVATIVE",06/06/2015
70000,"BUTYROSPERMUM PARKII BUTTER","","",91080-23-8,293-515-7,"Shea butter","","SKIN CONDITIONING",07/07/2016
70001,"NIACINAMIDE","nicotinamide","",98-92-0,202-713-4,"","","SMOOTHING",07/07/2016
"""

APPROVED = {
    "version": 3,
    "ingredients": [
        {"id": "water", "name": "Water", "aliases": ["Aqua", "Purified Water"], "classes": ["solvent"]},
        {"id": "glycerin", "name": "Glycerin", "aliases": ["Glycerine"], "classes": ["humectant"]},
        {"id": "salicylic-acid", "name": "Salicylic Acid", "aliases": [], "classes": ["bha", "exfoliant"]},
        {"id": "butylated-hydroxyanisole", "name": "Butylated Hydroxyanisole", "aliases": [], "classes": ["antioxidant"]},
        {"id": "zinc-oxide", "name": "Zinc Oxide", "aliases": ["CI 77947"], "classes": ["uv-filter"]},
        {"id": "phenoxyethanol", "name": "Phenoxyethanol", "aliases": [], "classes": ["preservative"]},
    ],
    "ambiguousTerms": [
        {"terms": ["BHA"], "candidateIDs": ["salicylic-acid", "butylated-hydroxyanisole"], "note": "two meanings"}
    ],
}


def fixture_rows():
    return parse_cosing_csv(FIXTURE_CSV)


def by_id(catalog):
    return {record["id"]: record for record in catalog["ingredients"]}


class ParseTests(unittest.TestCase):
    def test_parses_export_after_preamble(self):
        rows = {row.ref_no: row for row in fixture_rows()}
        self.assertEqual(len(rows), 11)
        self.assertEqual(rows["31959"].inci_name, "AQUA")
        self.assertEqual(rows["31959"].cas_numbers, ("7732-18-5",))
        self.assertEqual(rows["34040"].functions, ("HUMECTANT", "SOLVENT"))
        self.assertEqual(rows["34040"].inn_names, ("glycerol",))
        self.assertEqual(rows["38968"].restrictions, ("IV/144", "VI/30"))

    def test_missing_header_is_rejected(self):
        with self.assertRaises(ValueError):
            parse_cosing_csv("just,some,columns\n1,2,3\n")

    def test_snapshot_round_trip_is_byte_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            first, second = Path(tmp, "a.json.gz"), Path(tmp, "b.json.gz")
            rows = fixture_rows()
            write_snapshot(first, {"retrievedOn": "2026-11-15"}, rows)
            write_snapshot(second, {"retrievedOn": "2026-11-15"}, list(reversed(rows)))
            self.assertEqual(first.read_bytes(), second.read_bytes())
            meta, loaded = load_source(first)
            self.assertEqual(meta["rowCount"], 11)
            self.assertEqual({row.ref_no for row in loaded}, {row.ref_no for row in rows})

    def test_csv_file_loads_through_load_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "export.csv")
            path.write_text(FIXTURE_CSV, encoding="utf-8")
            _, rows = load_source(path)
            self.assertEqual(len(rows), 11)


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.catalog = build_catalog(fixture_rows(), APPROVED, version="test")
        self.records = by_id(self.catalog)

    def test_ids_are_deterministic_and_collision_safe(self):
        rows = fixture_rows()
        random.Random(7).shuffle(rows)
        shuffled = build_catalog(rows, APPROVED, version="test")
        self.assertEqual(shuffled["ingredients"], self.catalog["ingredients"])
        # CAFÉ EXTRACT has the lower reference number, so it keeps the plain slug.
        cafe = [r for r in self.catalog["ingredients"] if r["inciNames"] and r["inciNames"][0] in {"CAFE EXTRACT", "CAFÉ EXTRACT"}]
        ids = {r["inciNames"][0]: r["id"] for r in cafe}
        self.assertEqual(ids["CAFÉ EXTRACT"], "cafe-extract")
        self.assertRegex(ids["CAFE EXTRACT"], r"^cafe-extract-[0-9a-f]{8}$")

    def test_duplicate_inci_rows_merge_into_one_ingredient(self):
        glycerin = self.records["glycerin"]
        self.assertEqual([source["refNo"] for source in glycerin["sources"]], ["34040", "34041"])
        self.assertEqual(glycerin["functions"], ["HUMECTANT", "SOLVENT", "SKIN CONDITIONING"])
        self.assertEqual(self.catalog["stats"]["duplicateInciRowsMerged"], 1)

    def test_approved_ids_names_aliases_and_classes_are_preserved(self):
        water = self.records["water"]
        self.assertEqual(water["tier"], "approved")
        self.assertEqual(water["canonicalName"], "Water")
        self.assertEqual(water["aliases"][:2], ["Aqua", "Purified Water"])
        self.assertEqual(water["classes"], ["solvent"])
        self.assertEqual(water["casNumbers"], ["7732-18-5"])
        self.assertNotIn("aqua", self.records)  # no duplicate ID for AQUA
        zinc = self.records["zinc-oxide"]
        self.assertEqual(sorted(s["refNo"] for s in zinc["sources"]), ["38968", "98572"])
        self.assertNotIn("ci-77947", self.records)

    def test_aliases_come_from_source_synonyms(self):
        self.assertIn("glycerol", self.records["glycerin"]["aliases"])
        self.assertIn("nicotinamide", self.records["niacinamide"]["aliases"])
        self.assertEqual(self.records["niacinamide"]["tier"], "reference")
        self.assertEqual(self.records["niacinamide"]["canonicalName"], "NIACINAMIDE")

    def test_approved_ambiguous_term_is_not_overridden(self):
        # CosIng's INCI "BHA" attaches to butylated-hydroxyanisole through its INN,
        # but the bare name stays ambiguous as the team decided.
        bha = self.records["butylated-hydroxyanisole"]
        self.assertIn("III/71", bha["restrictions"])
        self.assertNotIn("bha", bha["aliasKeys"])
        index = ReferenceIndex(self.catalog)
        self.assertEqual(index.lookup("BHA")[0], "ambiguous")

    def test_real_bundled_catalog_ids_survive_import(self):
        approved = json.loads(BUNDLED.read_text(encoding="utf-8"))
        catalog = build_catalog(fixture_rows(), approved, version="test")
        records = by_id(catalog)
        for item in approved["ingredients"]:
            self.assertEqual(records[item["id"]]["tier"], "approved")
            self.assertEqual(records[item["id"]]["classes"], item["classes"])
            self.assertEqual(records[item["id"]]["aliases"][: len(item["aliases"])], item["aliases"])


class ResolveTests(unittest.TestCase):
    def setUp(self):
        self.index = ReferenceIndex(build_catalog(fixture_rows(), APPROVED, version="test"))

    def resolve(self, texts, **kwargs):
        return resolve_ingredient_texts(texts, APPROVED, self.index, **kwargs)

    def test_approved_and_reference_matches(self):
        aqua, niacinamide, cas = self.resolve(["Aqua", "Niacinamide", "56-81-5"])
        self.assertEqual((aqua["mapping"], aqua["ingredientID"], aqua["analysisEligible"]), ("confirmed", "water", True))
        self.assertEqual(niacinamide["mapping"], "uncertain")
        self.assertEqual(niacinamide["suggestedID"], "niacinamide")
        self.assertFalse(niacinamide["analysisEligible"])
        self.assertEqual(niacinamide["sources"][0]["refNo"], "70001")
        self.assertEqual((cas["ingredientID"], cas["matchedOn"]), ("glycerin", "cas-number"))

    def test_unknown_stays_unknown(self):
        unknown, empty = self.resolve(["Mystery Botanical Complex 9", "   "])
        self.assertEqual((unknown["status"], unknown["mapping"], unknown["reason"]), ("unknown", "unmatched", "not_in_catalog"))
        self.assertIsNone(unknown["ingredientID"])
        self.assertIsNone(unknown["suggestedID"])
        self.assertEqual(empty["reason"], "empty_input")
        self.assertEqual(unknown["originalText"], "Mystery Botanical Complex 9")

    def test_shared_cas_number_is_ambiguous_not_guessed(self):
        index = ReferenceIndex({
            "version": "t",
            "ingredients": [
                {"id": "a", "aliasKeys": ["a"], "casNumbers": ["50-00-0"]},
                {"id": "b", "aliasKeys": ["b"], "casNumbers": ["50-00-0"]},
            ],
            "ambiguousTerms": [],
        })
        self.assertEqual(index.lookup("50-00-0"), ("ambiguous", ["a", "b"], "cas-number"))

    def test_parenthetical_common_names(self):
        shea, water = self.resolve(["Butyrospermum Parkii (Shea) Butter", "Water (Aqua)"])
        self.assertEqual(shea["suggestedID"], "butyrospermum-parkii-butter")
        self.assertEqual(shea["matchedOn"], "name-without-parenthetical")
        self.assertEqual(water["ingredientID"], "water")

    def test_rows_fit_pd03_analysis_input_and_stay_out_of_analysis(self):
        rows = self.resolve(["Aqua", "Niacinamide", "Mystery"])
        product = {
            "productID": "p1",
            "listStatus": "complete",
            "catalogVersion": APPROVED["version"],
            "ingredients": [
                {key: row[key] for key in ("originalText", "mapping", "ingredientID", "suggestedID", "candidateIDs")}
                for row in rows
            ],
        }
        prepared = prepare_analysis_input(product, APPROVED)
        self.assertEqual(prepared.confirmed_ids, ("water",))
        self.assertEqual(len(prepared.unresolved_ingredients), 2)
        self.assertTrue(prepared.uncertainty_preserved)

    def test_firestore_lookup_used_only_for_misses(self):
        calls = []

        class Query:
            def __init__(self, key):
                self.key = key

            def limit(self, _n):
                return self

            def stream(self):
                return [SimpleNamespace(id="db-only-ingredient")] if self.key == "db only name" else []

        class Collection:
            def where(self, field, op, key):
                calls.append(key)
                return Query(key)

        db = SimpleNamespace(collection=lambda name: Collection())
        aqua, db_only, unknown = self.resolve(["Aqua", "DB Only Name", "Nothing"], db=db)
        self.assertEqual(calls, ["db only name", "nothing"])
        self.assertEqual((db_only["suggestedID"], db_only["source"]), ("db-only-ingredient", "firestore"))
        self.assertEqual(unknown["mapping"], "unmatched")

    def test_input_limits(self):
        with self.assertRaises(ValueError):
            self.resolve("Aqua")
        with self.assertRaises(ValueError):
            self.resolve(["x"] * 201)


class FakeBatch:
    def __init__(self, db):
        self.db, self.sets = db, []

    def set(self, reference, payload):
        self.sets.append((reference, payload))

    def commit(self):
        self.db.committed.append(self.sets)


class FakeDB:
    def __init__(self):
        self.committed = []

    def batch(self):
        return FakeBatch(self)

    def collection(self, name):
        return SimpleNamespace(document=lambda doc_id: f"{name}/{doc_id}")


class ImportCommandTests(unittest.TestCase):
    def args(self, source, **overrides):
        values = dict(source=str(source), approved_catalog=str(BUNDLED), fetch=False, include_inactive=False,
                      apply=False, start_after=None, limit=None)
        values.update(overrides)
        return argparse.Namespace(**values)

    def with_fixture(self, fn):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp, "export.csv")
            path.write_text(FIXTURE_CSV, encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                return fn(path)

    def test_dry_run_makes_no_writes(self):
        def never():
            raise AssertionError("dry run must not open Firestore")

        result = self.with_fixture(lambda path: run(self.args(path), db_factory=never))
        self.assertEqual(result["batches"], 0)
        self.assertGreater(len(result["writes"]), 0)

    def test_apply_requires_editor(self):
        import os
        previous = os.environ.pop("INGREDIENT_ALIAS_EDITOR", None)
        try:
            with self.assertRaises(SystemExit):
                self.with_fixture(lambda path: run(self.args(path, apply=True), db_factory=FakeDB))
        finally:
            if previous is not None:
                os.environ["INGREDIENT_ALIAS_EDITOR"] = previous

    def test_batched_writes_stay_under_firestore_limit(self):
        catalog = build_catalog(fixture_rows(), APPROVED, version="test")
        writes = firestore_documents(catalog, {"retrievedOn": "2026-11-15"}, "tester")
        db = FakeDB()
        many = writes * 120
        with contextlib.redirect_stdout(io.StringIO()):
            batches = write_documents(db, many)
        self.assertEqual(batches, -(-len(many) // BATCH_SIZE))
        self.assertTrue(all(len(batch) <= 500 for batch in db.committed))
        self.assertEqual(sum(len(batch) for batch in db.committed), len(many))
        self.assertEqual(writes[-1][0:2], ("ingredientCatalogs", "reference"))
        ingredient_docs = [w for w in writes if w[0] == "ingredients"]
        self.assertTrue(all(doc_id == payload["id"] for _, doc_id, payload in ingredient_docs))

    def test_firestore_payloads_never_touch_the_approved_alias_document(self):
        catalog = build_catalog(fixture_rows(), APPROVED, version="test")
        collections = {collection for collection, _, _ in firestore_documents(catalog, {}, "tester")}
        self.assertNotIn("ingredientAliasCatalogs", collections)


class ApiTests(unittest.TestCase):
    def handler(self, method, path, body=None):
        catalog = build_catalog(fixture_rows(), APPROVED, version="test")
        handler = object.__new__(APIHandler)
        handler.path = path
        handler.command = method
        encoded = json.dumps(body).encode() if body is not None else b""
        handler.headers = {"Content-Type": "application/json", "Content-Length": str(len(encoded))}
        handler.rfile = io.BytesIO(encoded)
        handler.server = SimpleNamespace(
            db=SimpleNamespace(collection=lambda name: (_ for _ in ()).throw(RuntimeError("offline"))),
            catalog=APPROVED, database_id="test", demo_mode=True,
            reference_index=ReferenceIndex(catalog),
        )
        captured = {}
        handler._send = lambda status, payload: captured.update(status=status, body=payload)
        return handler, captured

    def test_resolve_endpoint_offline(self):
        handler, captured = self.handler(
            "POST",
            "/api/v1/ingredients/resolve",
            {"contractVersion": 1, "ai": False, "ingredients": ["Aqua", "Niacinamide", "???"]},
        )
        handler.do_POST()
        self.assertEqual(captured["status"], 200)
        body = captured["body"]
        self.assertEqual(body["catalogSource"], "bundled-fallback")
        self.assertEqual([row["mapping"] for row in body["ingredients"]], ["confirmed", "uncertain", "unmatched"])
        self.assertEqual([row["status"] for row in body["ingredients"]], ["identified", "tentative", "unknown"])
        self.assertEqual(body["coverage"], "partial")
        self.assertTrue(body["uncertaintyPreserved"])

    def test_resolve_endpoint_rejects_bad_input(self):
        handler, captured = self.handler(
            "POST",
            "/api/v1/ingredients/resolve",
            {"contractVersion": 1, "ai": False, "ingredients": "Aqua"},
        )
        handler.do_POST()
        self.assertEqual(captured["status"], 400)

    def test_ingredient_detail(self):
        handler, captured = self.handler("GET", "/api/v1/ingredients/niacinamide")
        handler.do_GET()
        self.assertEqual(captured["status"], 200)
        self.assertEqual(captured["body"]["ingredient"]["casNumbers"], ["98-92-0"])
        handler, captured = self.handler("GET", "/api/v1/ingredients/not-a-real-id")
        handler.do_GET()
        self.assertEqual(captured["status"], 404)


@unittest.skipUnless(DATA_PATH.exists(), "committed CosIng snapshot not present")
class CommittedSnapshotTests(unittest.TestCase):
    def test_full_snapshot_builds_with_all_approved_ids(self):
        approved = json.loads(BUNDLED.read_text(encoding="utf-8"))
        meta, rows = load_source(DATA_PATH)
        catalog = build_catalog(rows, approved, version="snapshot")
        records = by_id(catalog)
        self.assertGreater(len(records), 30000)
        self.assertTrue(meta.get("retrievedOn"))
        for item in approved["ingredients"]:
            self.assertEqual(records[item["id"]]["tier"], "approved")
        index = ReferenceIndex(catalog)
        self.assertEqual(index.lookup("Aqua"), ("resolved", ["water"], "name"))
        self.assertEqual(index.lookup("Ethylhexylglycerin")[0], "resolved")
        self.assertEqual(index.lookup("Totally Invented Ingredient 42")[0], "unknown")


if __name__ == "__main__":
    unittest.main()
