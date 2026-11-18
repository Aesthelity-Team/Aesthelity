"""Tests for serving the currently approved Firestore alias catalog."""

import copy
import unittest
from types import SimpleNamespace

from Backend.analysis_api import APIHandler
from Backend.ingredient_alias_store import load_approved_alias_catalog


def catalog(version=1, aliases=None):
    return {
        "version": version,
        "ingredients": [
            {
                "id": "hyaluronic-acid",
                "name": "Hyaluronic Acid",
                "aliases": aliases if aliases is not None else ["Sodium Hyaluronate"],
                "classes": ["humectant"],
            }
        ],
        "ambiguousTerms": [],
    }


class Snapshot:
    def __init__(self, value):
        self.value = value
        self.exists = value is not None

    def to_dict(self):
        return self.value


class Document:
    def __init__(self, value):
        self.value = value

    def get(self):
        return Snapshot(self.value)


class Collection:
    def __init__(self, value):
        self.value = value

    def document(self, _document_id):
        return Document(self.value)


class Database:
    def __init__(self, value=None, error=None):
        self.value = value
        self.error = error

    def collection(self, _name):
        if self.error:
            raise self.error
        return Collection(self.value)


class AliasCatalogStoreTests(unittest.TestCase):
    def test_loads_approved_firestore_catalog(self):
        database = Database({**catalog(2), "reviewStatus": "approved"})

        loaded, source = load_approved_alias_catalog(database, catalog())

        self.assertEqual(source, "firestore")
        self.assertEqual(loaded["version"], 2)
        self.assertEqual(loaded["ingredients"][0]["aliases"], ["Sodium Hyaluronate"])

    def test_updated_catalog_is_visible_on_the_next_read(self):
        database = Database({**catalog(1), "reviewStatus": "approved"})
        first, _ = load_approved_alias_catalog(database, catalog())
        database.value = {
            **catalog(2, aliases=["Sodium Hyaluronate", "Hyaluronan"]),
            "reviewStatus": "approved",
        }

        second, _ = load_approved_alias_catalog(database, catalog())

        self.assertEqual(first["version"], 1)
        self.assertEqual(second["version"], 2)
        self.assertIn("Hyaluronan", second["ingredients"][0]["aliases"])

    def test_missing_or_unavailable_firestore_uses_bundled_catalog(self):
        fallback = catalog(3, aliases=["Hyaluronan"])
        for database in (Database(), Database(error=RuntimeError("private db detail"))):
            loaded, source = load_approved_alias_catalog(database, fallback)
            self.assertEqual(source, "bundled-fallback")
            self.assertEqual(loaded, fallback)

    def test_unapproved_or_malformed_document_falls_back(self):
        fallback = catalog(3)
        values = [
            {**catalog(), "reviewStatus": "draft"},
            {"version": 1, "ingredients": [{"id": "Bad ID"}], "reviewStatus": "approved"},
        ]
        for value in values:
            loaded, source = load_approved_alias_catalog(Database(value), fallback)
            self.assertEqual(source, "bundled-fallback")
            self.assertEqual(loaded, fallback)

    def test_endpoint_serves_the_fresh_catalog_to_clients(self):
        active = {**catalog(4, aliases=["Sodium Hyaluronate", "Hyaluronan"]), "reviewStatus": "approved"}
        handler = object.__new__(APIHandler)
        handler.path = "/api/v1/ingredient-aliases"
        handler.server = SimpleNamespace(
            db=Database(active),
            catalog=catalog(),
            database_id="test",
        )
        captured = {}
        handler._send = lambda status, body: captured.update(status=status, body=body)

        handler.do_GET()

        self.assertEqual(captured["status"], 200)
        self.assertEqual(captured["body"]["version"], 4)
        self.assertEqual(captured["body"]["catalogSource"], "firestore")
        self.assertIn("Hyaluronan", captured["body"]["ingredients"][0]["aliases"])


if __name__ == "__main__":
    unittest.main()
