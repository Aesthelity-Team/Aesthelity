"""AI-written explanations grounded in the deterministic analysis result.

The model can rewrite explanations for readability. It cannot create findings,
choose outcomes/severity, or change affected product/ingredient identifiers.
When the provider is unavailable, callers receive the engine's original text.
"""

from __future__ import annotations

import json
import os
from typing import Any, Protocol

from Backend.ai_normalization import (
    OpenRouterNormalizationProvider,
    ProviderError,
)


PROMPT_VERSION = "analysis-feedback-v1"
MAX_PROVIDER_RESPONSE_BYTES = 128_000
MAX_TEXT_LENGTH = 1_200

PROMPT = """You write concise skincare routine analysis explanations for users.
The supplied analysis result is authoritative. Rewrite its findings in clear,
calm language using only the supplied facts and explanations. Do not add or
remove a finding, ingredient interaction, source, medical claim, diagnosis,
recommendation, or safety guarantee. Do not change severity. Do not call a
routine safe. If the input is incomplete or contains unknown findings, say the
assessment is incomplete and explain only the stated reason. For no findings,
say that no recorded rule matched; do not imply the routine is safe. Keep each
finding explanation faithful to its supplied engine explanation and reason.
Return exactly one explanation for every supplied finding index, in order.
"""

_SCHEMA = {
    "type": "object",
    "additionalProperties": False,
    "properties": {
        "summary": {"type": "string"},
        "findingExplanations": {
            "type": "array",
            "items": {
                "type": "object",
                "additionalProperties": False,
                "properties": {
                    "findingIndex": {"type": "integer"},
                    "explanation": {"type": "string"},
                },
                "required": ["findingIndex", "explanation"],
            },
        },
    },
    "required": ["summary", "findingExplanations"],
}


class FeedbackProviderError(RuntimeError):
    """Sanitized provider failure code; never contains provider response text."""


class FeedbackProvider(Protocol):
    model: str

    def generate(self, context: dict[str, Any]) -> Any: ...


class OpenRouterFeedbackProvider:
    """Feedback provider using the shared OpenRouter client."""

    def __init__(self, client: OpenRouterNormalizationProvider):
        self.client = client
        self.model = client.model

    @classmethod
    def from_environment(cls) -> "OpenRouterFeedbackProvider":
        client = OpenRouterNormalizationProvider.from_environment()
        analysis_model = os.environ.get("AESTHELITY_ANALYSIS_MODEL")
        if analysis_model:
            client.model = analysis_model

        client.fallback_model = (
            os.environ.get("AESTHELITY_ANALYSIS_FALLBACK_MODEL") or None
        )
        return cls(client)

    def generate(self, context: dict[str, Any]) -> Any:
        try:
            return self.client.complete_messages(
                [
                    {"role": "system", "content": PROMPT},
                    {
                        "role": "user",
                        "content": json.dumps(context, ensure_ascii=False),
                    },
                ],
                schema=_SCHEMA,
                schema_name="routine_analysis_feedback",
                model=self.model,
            )
        except ProviderError as error:
            code = str(error)
            mapped_code = {
                "provider_unconfigured": "ai_unconfigured",
                "provider_rate_limited": "ai_rate_limited",
                "provider_incomplete_or_refused": "ai_refused_or_incomplete",
                "provider_invalid_response": "ai_invalid_response",
            }.get(code, "ai_unavailable")
            raise FeedbackProviderError(mapped_code) from None

def _ingredient_names(catalog: dict[str, Any]) -> dict[str, str]:
    rows = catalog.get("ingredients", []) if isinstance(catalog, dict) else []
    if not isinstance(rows, list):
        return {}
    return {
        row["id"]: row["name"]
        for row in rows
        if isinstance(row, dict)
        and isinstance(row.get("id"), str)
        and isinstance(row.get("name"), str)
    }


def _context_for(result: dict[str, Any], catalog: dict[str, Any]) -> dict[str, Any]:
    names = _ingredient_names(catalog)
    findings = []
    for index, finding in enumerate(result.get("findings", [])):
        findings.append(
            {
                "findingIndex": index,
                "ruleID": finding.get("ruleID"),
                "outcome": finding.get("outcome"),
                "categoryID": finding.get("categoryID"),
                "severity": finding.get("severity"),
                "productIDs": finding.get("productIDs", []),
                "ingredientIDs": finding.get("ingredientIDs", []),
                "ingredientNames": [
                    names[ingredient_id]
                    for ingredient_id in finding.get("ingredientIDs", [])
                    if ingredient_id in names
                ],
                "approvedExplanation": finding.get("explanation", ""),
                "engineReason": finding.get("reason", ""),
            }
        )
    return {
        "period": result.get("period"),
        "outcome": result.get("outcome"),
        "completeness": result.get("completeness"),
        "displayLabel": result.get("displayLabel"),
        "findings": findings,
        "limitations": result.get("limitations", []),
    }


def _validate_feedback(value: Any, finding_count: int) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != {"summary", "findingExplanations"}:
        raise FeedbackProviderError("ai_invalid_response")
    summary = value["summary"]
    explanations = value["findingExplanations"]
    if not isinstance(summary, str) or not summary.strip() or len(summary) > MAX_TEXT_LENGTH:
        raise FeedbackProviderError("ai_invalid_response")
    if not isinstance(explanations, list) or len(explanations) != finding_count:
        raise FeedbackProviderError("ai_invalid_response")
    clean = []
    for index, row in enumerate(explanations):
        if (
            not isinstance(row, dict)
            or set(row) != {"findingIndex", "explanation"}
            or type(row["findingIndex"]) is not int
            or row["findingIndex"] != index
            or not isinstance(row["explanation"], str)
            or not row["explanation"].strip()
            or len(row["explanation"]) > MAX_TEXT_LENGTH
        ):
            raise FeedbackProviderError("ai_invalid_response")
        clean.append(row)
    return {"summary": summary.strip(), "findingExplanations": clean}


def add_ai_feedback(
    result: dict[str, Any],
    catalog: dict[str, Any],
    provider: FeedbackProvider,
) -> dict[str, Any]:
    """Add AI wording while preserving every deterministic finding field.

    AI failures return a deterministic summary and original finding explanations.
    The full allergy profile and raw product label text are not sent. A matching
    allergen finding's ingredient ID remains in the structured result context.
    """
    findings = result.get("findings", [])
    try:
        feedback = _validate_feedback(
            provider.generate(_context_for(result, catalog)), len(findings)
        )
        status = "generated"
        generated = True
    except FeedbackProviderError as error:
        status = str(error)
        generated = False
        if result.get("outcome") == "noFindings":
            summary = (
                "No recorded rule matched the available routine data. "
                "This is not a safety guarantee."
            )
        elif result.get("completeness") == "incomplete":
            summary = "The assessment is incomplete. Review the unknown or missing data in the findings."
        else:
            summary = f"The analysis returned {len(findings)} finding(s) under the approved rules."
        feedback = {
            "summary": summary,
            "findingExplanations": [
                {"findingIndex": index, "explanation": finding.get("explanation", "")}
                for index, finding in enumerate(findings)
            ],
        }
    except Exception:
        # Unexpected provider/client failures must not replace the analysis or
        # leak exception text, keys, or raw provider payloads to the API caller.
        status = "ai_unavailable"
        generated = False
        if result.get("outcome") == "noFindings":
            summary = "No recorded rule matched the available routine data. This is not a safety guarantee."
        elif result.get("completeness") == "incomplete":
            summary = "The assessment is incomplete. Review the unknown or missing data in the findings."
        else:
            summary = f"The analysis returned {len(findings)} finding(s) under the approved rules."
        feedback = {
            "summary": summary,
            "findingExplanations": [
                {"findingIndex": index, "explanation": finding.get("explanation", "")}
                for index, finding in enumerate(findings)
            ],
        }

    # Keep this as an additive response field; the model cannot alter findings.
    return {
        **result,
        "aiFeedback": {
            "status": status,
            "generated": generated,
            "promptVersion": PROMPT_VERSION,
            "model": provider.model if generated else None,
            **feedback,
        },
    }
