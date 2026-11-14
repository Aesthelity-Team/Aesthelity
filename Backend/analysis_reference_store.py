"""Read the active analysis contract and approved evidence from Firestore."""

from __future__ import annotations

from typing import Any


class AnalysisReferenceStoreError(RuntimeError):
    """The approved analysis data could not be loaded safely."""


def load_approved_analysis_records(
    db: Any,
    contract_version: int,
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Load one approved contract and all currently approved references.

    Reads on each call so an authorized Firestore update is available to the
    next analysis request. This module does not write to Firestore.
    """
    if type(contract_version) is not int or contract_version < 1:
        raise ValueError("contract_version must be a positive integer.")

    try:
        contract_snapshot = (
            db.collection("analysisContracts")
            .document(f"v{contract_version}")
            .get()
        )
        if not contract_snapshot.exists:
            raise AnalysisReferenceStoreError("approved_analysis_contract_unavailable")

        contract = contract_snapshot.to_dict() or {}
        if (
            contract.get("reviewStatus") != "approved"
            or contract.get("contractVersion") != contract_version
        ):
            raise AnalysisReferenceStoreError("approved_analysis_contract_unavailable")

        reference_snapshots = (
            db.collection("analysisReferences")
            .where("reviewStatus", "==", "approved")
            .stream()
        )
        references = [snapshot.to_dict() or {} for snapshot in reference_snapshots]

    except AnalysisReferenceStoreError:
        raise
    except Exception:
        # Keep database details and credentials out of API responses.
        raise AnalysisReferenceStoreError("approved_analysis_data_unavailable") from None

    return contract, references
