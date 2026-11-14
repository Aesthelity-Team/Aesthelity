"""Offline tests for loading the approved analysis contract and references."""

import unittest

from Backend.analysis_reference_store import (
    AnalysisReferenceStoreError,
    load_approved_analysis_records,
)


class FakeSnapshot:
    def __init__(self, value, exists=True):
        self.value = value
        self.exists = exists

    def to_dict(self):
        return self.value


class FakeDocument:
    def __init__(self, value):
        self.value = value

    def get(self):
        return FakeSnapshot(self.value, exists=self.value is not None)


class FakeQuery:
    def __init__(self, records):
        self.records = records
        self.field = None
        self.expected_value = None

    def where(self, field, operator, value):
        if operator != "==":
            raise AssertionError("Test fake only supports equality filters.")
        self.field = field
        self.expected_value = value
        return self

    def stream(self):
        return [
            FakeSnapshot(record)
            for record in self.records
            if record.get(self.field) == self.expected_value
        ]


class FakeCollection:
    def __init__(self, documents=None, records=None):
        self.documents = documents or {}
        self.records = records or []

    def document(self, document_id):
        return FakeDocument(self.documents.get(document_id))

    def where(self, field, operator, value):
        return FakeQuery(self.records).where(field, operator, value)


class FakeDatabase:
    def __init__(self, contract=None, references=None, error=None):
        self.contract = contract
        self.references = references or []
        self.error = error

    def collection(self, name):
        if self.error:
            raise self.error
        if name == "analysisContracts":
            return FakeCollection(documents={"v1": self.contract})
        if name == "analysisReferences":
            return FakeCollection(records=self.references)
        raise AssertionError(f"Unexpected collection: {name}")


class AnalysisReferenceStoreTests(unittest.TestCase):
    def approved_contract(self):
        return {
            "contractVersion": 1,
            "reviewStatus": "approved",
            "ruleSetVersion": "AN-02-v1",
        }

    def test_loads_approved_contract_and_only_approved_references(self):
        approved = {"referenceID": "approved-example", "reviewStatus": "approved"}
        draft = {"referenceID": "draft-example", "reviewStatus": "draft"}
        db = FakeDatabase(self.approved_contract(), [approved, draft])

        contract, references = load_approved_analysis_records(db, 1)

        self.assertEqual(contract["ruleSetVersion"], "AN-02-v1")
        self.assertEqual(references, [approved])

    def test_missing_contract_is_rejected(self):
        db = FakeDatabase(contract=None)

        with self.assertRaises(AnalysisReferenceStoreError):
            load_approved_analysis_records(db, 1)

    def test_unapproved_contract_is_rejected(self):
        contract = self.approved_contract()
        contract["reviewStatus"] = "draft"
        db = FakeDatabase(contract=contract)

        with self.assertRaises(AnalysisReferenceStoreError):
            load_approved_analysis_records(db, 1)

    def test_invalid_version_is_rejected(self):
        db = FakeDatabase(contract=self.approved_contract())

        with self.assertRaises(ValueError):
            load_approved_analysis_records(db, True)

    def test_firestore_error_is_sanitized(self):
        db = FakeDatabase(error=RuntimeError("private database detail"))

        with self.assertRaises(AnalysisReferenceStoreError) as raised:
            load_approved_analysis_records(db, 1)

        self.assertNotIn("private database detail", str(raised.exception))
    def test_new_approved_reference_is_available_on_next_read(self):
        first = {"referenceID": "first", "reviewStatus": "approved"}
        db = FakeDatabase(self.approved_contract(), [first])

        _, first_read = load_approved_analysis_records(db, 1)
        self.assertEqual(first_read, [first])

        updated = {"referenceID": "new", "reviewStatus": "approved"}
        db.references.append(updated)

        _, second_read = load_approved_analysis_records(db, 1)
        self.assertEqual(second_read, [first, updated])


if __name__ == "__main__":
    unittest.main()
