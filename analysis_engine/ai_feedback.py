"""AI-written explanations grounded in the deterministic analysis result.

The model can rewrite explanations for readability. It cannot create findings,
choose outcomes/severity, or change affected product/ingredient identifiers.
When the provider is unavailable, callers receive the engine's original text.
"""

from __future__ import annotations

import json
import os
from typing import Any, Protocol
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


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


class OpenAIFeedbackProvider:
    """Small server-side OpenAI Chat Completions client using strict JSON output."""

    def __init__(self, *, api_key: str, model: str, timeout: float = 30.0):
        self.api_key = api_key
        self.model = model
        self.timeout = timeout

    @classmethod
    def from_environment(cls) -> "OpenAIFeedbackProvider":
        return cls(
            api_key=os.environ.get("OPENAI_API_KEY", ""),
            model=os.environ.get("AESTHELITY_ANALYSIS_MODEL", ""),
        )

    def generate(self, context: dict[str, Any]) -> Any:
        if not self.api_key or not self.model:
            raise FeedbackProviderError("ai_unconfigured")

        body = {
            "model": self.model,
            "store": False,
            "messages": [
                {"role": "system", "content": PROMPT},
                {"role": "user", "content": json.dumps(context, ensure_ascii=False)},
            ],
            "response_format": {
                "type": "json_schema",
                "json_schema": {
                    "name": "routine_analysis_feedback",
                    "strict": True,
                    "schema": _SCHEMA,
                },
            },
        }
        request = Request(
            "https://api.openai.com/v1/chat/completions",
            data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                raw = response.read(MAX_PROVIDER_RESPONSE_BYTES + 1)
            if len(raw) > MAX_PROVIDER_RESPONSE_BYTES:
                raise FeedbackProviderError("ai_invalid_response")
            envelope = json.loads(raw)
            choice = envelope["choices"][0]
            message = choice["message"]
            if choice.get("finish_reason") != "stop" or message.get("refusal"):
                raise FeedbackProviderError("ai_refused_or_incomplete")
            return json.loads(message["content"])
        except HTTPError as error:
            raise FeedbackProviderError(
                "ai_rate_limited" if error.code == 429 else "ai_unavailable"
            ) from None
        except (URLError, TimeoutError, OSError):
            raise FeedbackProviderError("ai_unavailable") from None
        except (ValueError, KeyError, IndexError, TypeError, AttributeError):
            raise FeedbackProviderError("ai_invalid_response") from None


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
