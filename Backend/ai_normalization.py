"""AI-primary ingredient matching for #98 with catalog grounding.

AI proposes identities for every nonempty label string. The approved + CosIng
catalogs are validators / grounding sources only. A row becomes identified only
when the model itself returns status "identified" and that name grounds to
exactly one catalog record. AI-stated uncertainty always stays tentative, even
when the best guess happens to exist in the catalog.

Transport is OpenRouter's OpenAI-compatible API. Mia's analysis_engine code is
not modified; this module owns the #98 matching prompt and response validation.
"""

from __future__ import annotations

import json
import os
import re
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from Backend.ingredient_catalog import name_key, resolve_ingredient_texts
from Backend.prompts.ingredient_matching_v2 import (
    FIELDS,
    PROMPT,
    PROMPT_VERSION,
    SCHEMA,
)


DEFAULT_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_MODEL = "nvidia/nemotron-3.5-super-vl:free"
DEFAULT_FALLBACK_MODEL = "google/gemma-4-31b-it:free"
DEFAULT_TIMEOUT = 30.0
MAX_RESPONSE_BYTES = 1_000_000
OPENAI_HOST_MARKERS = ("api.openai.com",)
MATCH_STATUSES = ("identified", "tentative", "unknown")
COVERAGE_VALUES = ("complete", "partial", "unknown")

# Re-exported so callers can use one module for the #98 AI step.
__all__ = [
    "COVERAGE_VALUES",
    "DEFAULT_BASE_URL",
    "DEFAULT_FALLBACK_MODEL",
    "DEFAULT_MODEL",
    "MATCH_STATUSES",
    "PROMPT_VERSION",
    "ProviderError",
    "OpenRouterNormalizationProvider",
    "apply_ai_normalization",
    "catalog_issue_status_rows",
    "coverage_for_rows",
    "empty_ai_failure_rows",
    "ground_ai_suggestions",
    "load_backend_env",
    "match_ingredients",
    "validate_matching_output",
]


_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


class ProviderError(RuntimeError):
    """Only sanitized failure codes belong here."""


def load_backend_env(path: str | Path | None = None) -> bool:
    """Load Backend/.env into os.environ for keys that are not already set.

    Values are never logged or returned.
    """

    env_path = Path(path) if path is not None else Path(__file__).resolve().parent / ".env"
    if not env_path.is_file():
        return False
    for raw in env_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {"'", '"'}:
            value = value[1:-1]
        if key and key not in os.environ:
            os.environ[key] = value
    return True


def _extract_json(text: str) -> Any:
    if not isinstance(text, str) or not text.strip():
        raise ProviderError("provider_invalid_response")
    stripped = _FENCE.sub("", text.strip()).strip()
    try:
        return json.loads(stripped)
    except ValueError:
        start, end = stripped.find("{"), stripped.rfind("}")
        if start >= 0 and end > start:
            try:
                return json.loads(stripped[start : end + 1])
            except ValueError:
                pass
        raise ProviderError("provider_invalid_response") from None


def validate_matching_output(output: Any, count: int) -> list[dict[str, Any]]:
    """Validate a v2 matching JSON object.

    Requires ``{"ingredients": [...]}`` with exactly ``count`` rows, sequential
    indices ``0..count-1``, statuses in identified|tentative|unknown, and the
    field invariants in ``Backend/prompts/ingredient_matching_v2.py``. Raises
    ``ProviderError("provider_invalid_response")`` on any violation.
    """

    if not isinstance(output, dict) or set(output) != {"ingredients"}:
        raise ProviderError("provider_invalid_response")
    rows = output["ingredients"]
    if not isinstance(rows, list) or len(rows) != count:
        raise ProviderError("provider_invalid_response")
    cleaned: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict) or set(row) != set(FIELDS):
            raise ProviderError("provider_invalid_response")
        if type(row["index"]) is not int or row["index"] != index:
            raise ProviderError("provider_invalid_response")
        if row["status"] not in MATCH_STATUSES:
            raise ProviderError("provider_invalid_response")
        for key in ("normalizedName", "bestGuess", "explanation"):
            value = row[key]
            if value is not None and (not isinstance(value, str) or not value.strip() or len(value) > 500):
                raise ProviderError("provider_invalid_response")
        if row["explanation"] is None:
            raise ProviderError("provider_invalid_response")
        status = row["status"]
        if status == "identified":
            valid = row["normalizedName"] is not None and row["bestGuess"] is None
        elif status == "tentative":
            valid = row["normalizedName"] is None
        else:
            valid = row["normalizedName"] is None and row["bestGuess"] is None
        if not valid:
            raise ProviderError("provider_invalid_response")
        cleaned.append({
            "index": index,
            "status": status,
            "normalizedName": row["normalizedName"].strip() if isinstance(row["normalizedName"], str) else None,
            "bestGuess": row["bestGuess"].strip() if isinstance(row["bestGuess"], str) else None,
            "explanation": row["explanation"].strip(),
        })
    return cleaned


def coverage_for_rows(rows: Sequence[Mapping[str, Any]]) -> str:
    """Matching coverage for the supplied list (Scenario 4), aligned with #99.

    Only approved-catalog hits (mapping == "confirmed") count as identified.
    CosIng-only / tentative / unknown rows do not. complete means #99 would see
    every row as matched.

    complete: every supplied row is confirmed
    partial:  at least one confirmed and at least one non-confirmed
    unknown:  empty list, or no confirmed rows
    """

    if not rows:
        return "unknown"
    confirmed = 0
    for row in rows:
        if row.get("mapping") == "confirmed":
            confirmed += 1
    if confirmed == len(rows):
        return "complete"
    if confirmed == 0:
        return "unknown"
    return "partial"


def catalog_issue_status_rows(rows: Sequence[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Attach #98 issue statuses when AI matching is explicitly opted out.

    Catalog resolver rows reuse a ``status`` field for resolved/ambiguous/
    unknown kinds; overwrite it with the issue statuses used for coverage.
    """

    enriched: list[dict[str, Any]] = []
    for row in rows:
        out = dict(row)
        mapping = out.get("mapping")
        if mapping == "confirmed":
            out["status"] = "identified"
            out["normalizedName"] = out.get("canonicalName")
            out["bestGuess"] = None
            out["explanation"] = out.get("reason") or "approved-catalog match"
        elif mapping == "uncertain":
            out["status"] = "tentative"
            out["normalizedName"] = None
            out["bestGuess"] = out.get("canonicalName") or out.get("suggestedID")
            out["explanation"] = out.get("reason") or "reference-catalog-only"
        elif mapping == "ambiguous":
            candidates = ", ".join(out.get("candidateIDs") or []) or "none"
            out["status"] = "tentative"
            out["normalizedName"] = None
            out["bestGuess"] = None
            out["explanation"] = f"ambiguous: {candidates}"
            out["reason"] = out.get("reason") or f"ambiguous: {candidates}"
        else:
            out["status"] = "unknown"
            out["normalizedName"] = None
            out["bestGuess"] = None
            out["explanation"] = out.get("reason") or "not_in_catalog"
        enriched.append(out)
    return enriched


def _base_row(index: int, text: str) -> dict[str, Any]:
    return {
        "index": index,
        "originalText": text,
        "status": "unknown",
        "mapping": "unmatched",
        "normalizedName": None,
        "bestGuess": None,
        "explanation": None,
        "matchedOn": None,
        "source": None,
        "ingredientID": None,
        "suggestedID": None,
        "candidateIDs": [],
        "canonicalName": None,
        "tier": None,
        "analysisEligible": False,
        "reason": "not_in_catalog",
    }


def empty_ai_failure_rows(texts: Sequence[str], *, failure_code: str = "ai-unavailable") -> list[dict[str, Any]]:
    """Build unknown rows that preserve every submitted string (Scenario 10).

    Used when the provider fails validation or transport. Callers must set
    top-level ``status: failed`` and must not present the run as complete.
    """

    rows: list[dict[str, Any]] = []
    for index, text in enumerate(texts):
        row = _base_row(index, text)
        if not name_key(text):
            row["reason"] = "empty_input"
            row["explanation"] = "empty_input"
        else:
            row["reason"] = failure_code
            row["explanation"] = failure_code
        rows.append(row)
    return rows


def _apply_catalog_hit(
    row: dict[str, Any],
    resolved: Mapping[str, Any],
    *,
    original_text: str,
    index: int,
    explanation: str,
    matched_on: str,
) -> dict[str, Any]:
    out = dict(resolved)
    out["index"] = index
    out["originalText"] = original_text
    out["matchedOn"] = matched_on
    out["source"] = "ai"
    out["explanation"] = explanation
    out["bestGuess"] = None
    if resolved.get("mapping") == "confirmed":
        out["status"] = "identified"
        out["normalizedName"] = resolved.get("canonicalName")
        out["reason"] = f"ai-identified + approved match ({explanation})"
    else:
        # Reference-tier CosIng hit: tentative for coverage/#99 (PD-03), not confirmed.
        out["status"] = "tentative"
        out["normalizedName"] = None
        out["bestGuess"] = resolved.get("canonicalName") or resolved.get("suggestedID")
        out["reason"] = (
            f"ai-identified + reference-catalog-only ({resolved.get('suggestedID')}); {explanation}"
        )
    return out


def _tentative_row(
    index: int,
    original_text: str,
    *,
    best_guess: str | None,
    explanation: str,
    reason: str,
) -> dict[str, Any]:
    row = _base_row(index, original_text)
    row.update(
        status="tentative",
        mapping="uncertain",
        bestGuess=best_guess,
        explanation=explanation,
        reason=reason,
        matchedOn="ai-tentative",
        source="ai",
        suggestedID=None,
        ingredientID=None,
        analysisEligible=False,
    )
    return row


def _unknown_row(index: int, original_text: str, *, explanation: str, reason: str) -> dict[str, Any]:
    row = _base_row(index, original_text)
    row.update(
        status="unknown",
        mapping="unmatched",
        explanation=explanation,
        reason=reason,
        matchedOn=None,
        source="ai",
    )
    return row


def ground_ai_suggestions(
    texts: Sequence[str],
    suggestions: Sequence[Mapping[str, Any]],
    approved_catalog: Mapping[str, Any],
    reference: Any,
    *,
    db: Any = None,
) -> list[dict[str, Any]]:
    """Re-resolve AI names against the catalog and apply the confirmed-bug fix.

    ``identified`` becomes ``confirmed`` only when grounding hits the approved
    catalog. CosIng-only hits stay ``tentative``/``uncertain``. AI ``tentative``
    never becomes ``confirmed``, even when ``bestGuess`` validates.
    """

    if len(texts) != len(suggestions):
        raise ProviderError("provider_invalid_response")
    grounded: list[dict[str, Any]] = []
    for text, ai_row in zip(texts, suggestions):
        index = ai_row["index"]
        explanation = ai_row["explanation"]
        if not name_key(text):
            grounded.append(_unknown_row(index, text, explanation="empty_input", reason="empty_input"))
            continue

        ai_status = ai_row["status"]
        if ai_status == "unknown":
            grounded.append(_unknown_row(index, text, explanation=explanation, reason=explanation))
            continue

        if ai_status == "tentative":
            # Bug fix: AI-stated uncertainty never becomes identified/confirmed,
            # even when bestGuess happens to validate in the catalog.
            grounded.append(
                _tentative_row(
                    index,
                    text,
                    best_guess=ai_row.get("bestGuess"),
                    explanation=explanation,
                    reason=f"ai-tentative: {explanation}",
                )
            )
            continue

        # ai_status == "identified"
        name = ai_row.get("normalizedName")
        if not name:
            grounded.append(
                _unknown_row(
                    index,
                    text,
                    explanation=explanation or "ai-identified-without-name",
                    reason="ai-identified-without-name",
                )
            )
            continue
        try:
            resolved = resolve_ingredient_texts([name], approved_catalog, reference, db=db)[0]
        except Exception:
            grounded.append(
                _tentative_row(
                    index,
                    text,
                    best_guess=name,
                    explanation=f"{explanation}; catalog grounding failed",
                    reason="ai-identified-grounding-failed",
                )
            )
            continue
        mapping = resolved.get("mapping")
        if mapping == "confirmed" or mapping == "uncertain":
            grounded.append(
                _apply_catalog_hit(
                    {},
                    resolved,
                    original_text=text,
                    index=index,
                    explanation=explanation,
                    matched_on="ai-identified",
                )
            )
            continue
        if mapping == "ambiguous":
            candidates = ", ".join(resolved.get("candidateIDs") or []) or "none"
            grounded.append(
                _tentative_row(
                    index,
                    text,
                    best_guess=name,
                    explanation=f"{explanation}; ambiguous catalog match: {candidates}",
                    reason=f"ai-identified-ambiguous: {candidates}",
                )
            )
            continue
        grounded.append(
            _tentative_row(
                index,
                text,
                best_guess=name,
                explanation=f"{explanation}; name not in catalog",
                reason="ai-suggestion-not-in-catalog",
            )
        )
    return grounded


def _schema_rejected(error: HTTPError) -> bool:
    try:
        snippet = error.read(4000).decode("utf-8", "replace").lower()
    except Exception:
        return error.code in {400, 404, 422}
    return error.code in {400, 404, 422} and (
        "response_format" in snippet or "json_schema" in snippet or "json_object" in snippet or "schema" in snippet
    )


class OpenRouterNormalizationProvider:
    """OpenAI-compatible client, defaulting to OpenRouter, with a model fallback."""

    def __init__(
        self,
        *,
        api_key: str,
        model: str,
        fallback_model: str | None = DEFAULT_FALLBACK_MODEL,
        base_url: str = DEFAULT_BASE_URL,
        timeout: float = DEFAULT_TIMEOUT,
        transport: Any = None,
    ):
        self.api_key = api_key
        self.model = model
        self.fallback_model = fallback_model
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.last_model = model
        self._transport = transport or self._http_post

    @classmethod
    def from_environment(cls) -> "OpenRouterNormalizationProvider":
        load_backend_env()
        api_key = os.environ.get("OPENROUTER_API_KEY") or os.environ.get("OPENAI_API_KEY", "")
        model = os.environ.get("AESTHELITY_NORMALIZATION_MODEL") or DEFAULT_MODEL
        fallback = os.environ.get("AESTHELITY_NORMALIZATION_FALLBACK_MODEL") or DEFAULT_FALLBACK_MODEL
        base_url = (
            os.environ.get("OPENROUTER_BASE_URL")
            or os.environ.get("OPENAI_BASE_URL")
            or DEFAULT_BASE_URL
        )
        return cls(api_key=api_key, model=model, fallback_model=fallback, base_url=base_url)

    def _is_openai_host(self) -> bool:
        host = self.base_url.lower()
        return any(marker in host for marker in OPENAI_HOST_MARKERS)

    def _formats(self) -> list[str]:
        if self._is_openai_host():
            return ["json_schema"]
        return ["json_schema", "json_object", "plain"]

    def _headers(self) -> dict[str, str]:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        if "openrouter.ai" in self.base_url.lower():
            headers["HTTP-Referer"] = "https://github.com/Aesthelity-Team/Aesthelity"
            headers["X-Title"] = "Aesthelity"
        return headers

    def _http_post(self, url: str, payload: dict[str, Any], headers: dict[str, str], timeout: float) -> tuple[int, bytes]:
        request = Request(
            url,
            data=json.dumps(payload).encode("utf-8"),
            method="POST",
            headers=headers,
        )
        try:
            with urlopen(request, timeout=timeout) as response:
                return response.status, response.read(MAX_RESPONSE_BYTES + 1)
        except HTTPError as error:
            if error.code == 429:
                raise ProviderError("provider_rate_limited") from None
            if _schema_rejected(error):
                raise ProviderError("provider_schema_unsupported") from None
            raise ProviderError("provider_unavailable") from None

    def complete_messages(
        self,
        messages: Sequence[Mapping[str, str]],
        *,
        schema: Mapping[str, Any],
        schema_name: str,
        model: str | None = None,
    ) -> Any:
        """Run a structured chat request using this provider's shared transport."""
        if not self.api_key:
            raise ProviderError("provider_unconfigured")
        if not messages:
            raise ProviderError("provider_invalid_request")

        models = [model or self.model]
        if self.fallback_model and self.fallback_model not in models:
            models.append(self.fallback_model)

        last_error: ProviderError | None = None
        for selected_model in models:
            for response_format in self._formats():
                request_messages = [dict(message) for message in messages]

                if response_format != "json_schema":
                    system_index = next(
                        (i for i, message in enumerate(request_messages)
                         if message.get("role") == "system"),
                        None,
                    )
                    schema_instruction = (
                        "\nReturn only a JSON object matching this schema: "
                        + json.dumps(schema, ensure_ascii=False)
                    )
                    if system_index is None:
                        request_messages.insert(
                            0, {"role": "system", "content": schema_instruction}
                        )
                    else:
                        request_messages[system_index]["content"] += schema_instruction

                body: dict[str, Any] = {
                    "model": selected_model,
                    "messages": request_messages,
                    "temperature": 0,
                }
                if self._is_openai_host():
                    body["store"] = False

                elif "openrouter.ai" in self.base_url.lower():
                    body["provider"] = {
                        "data_collection": "deny",
                        "zdr": True,
                    }

                if response_format == "json_schema":
                    body["response_format"] = {
                        "type": "json_schema",
                        "json_schema": {
                            "name": schema_name,
                            "strict": True,
                            "schema": dict(schema),
                        },
                    }
                elif response_format == "json_object":
                    body["response_format"] = {"type": "json_object"}

                try:
                    url = f"{self.base_url}/chat/completions"
                    status, raw = self._transport(
                        url, body, self._headers(), self.timeout
                    )
                    if not 200 <= status < 300 or len(raw) > MAX_RESPONSE_BYTES:
                        raise ProviderError("provider_invalid_response")

                    envelope = json.loads(raw)
                    choice = envelope["choices"][0]
                    message = choice["message"]
                    if (
                        choice.get("finish_reason") not in {"stop", "end_turn", None}
                        or message.get("refusal")
                    ):
                        raise ProviderError("provider_incomplete_or_refused")

                    content = message.get("content")
                    if isinstance(content, list):
                        content = "".join(
                            part.get("text", "") if isinstance(part, dict) else str(part)
                            for part in content
                        )

                    result = _extract_json(content)
                    self.last_model = selected_model
                    return result
                except ProviderError as error:
                    last_error = error
                    if str(error) in {
                        "provider_rate_limited",
                        "provider_unavailable",
                    }:
                        break
                except (URLError, TimeoutError, OSError):
                    last_error = ProviderError("provider_unavailable")
                    break
                except (ValueError, KeyError, IndexError, TypeError, AttributeError):
                    last_error = ProviderError("provider_invalid_response")

        raise last_error or ProviderError("provider_unavailable")

    def _complete(self, texts: Sequence[str], model: str, fmt: str) -> Any:
        system = PROMPT
        if fmt != "json_schema":
            system = PROMPT + "\nReturn only a JSON object matching this schema: " + json.dumps(SCHEMA, ensure_ascii=False)
        body: dict[str, Any] = {
            "model": model,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": json.dumps(
                    [{"index": i, "text": t} for i, t in enumerate(texts)], ensure_ascii=False
                )},
            ],
            "temperature": 0,
        }
        if self._is_openai_host():
            body["store"] = False
        if fmt == "json_schema":
            body["response_format"] = {
                "type": "json_schema",
                "json_schema": {"name": "ingredient_matching_v2", "strict": True, "schema": SCHEMA},
            }
        elif fmt == "json_object":
            body["response_format"] = {"type": "json_object"}
        url = f"{self.base_url}/chat/completions"
        status, raw = self._transport(url, body, self._headers(), self.timeout)
        if len(raw) > MAX_RESPONSE_BYTES:
            raise ProviderError("provider_invalid_response")
        try:
            envelope = json.loads(raw)
            choice = envelope["choices"][0]
            message = choice["message"]
            if choice.get("finish_reason") not in {"stop", "end_turn", None} or message.get("refusal"):
                if choice.get("finish_reason") not in {"stop", "end_turn"}:
                    raise ProviderError("provider_incomplete_or_refused")
            content = message.get("content")
            if isinstance(content, list):
                content = "".join(
                    part.get("text", "") if isinstance(part, dict) else str(part) for part in content
                )
            return _extract_json(content)
        except ProviderError:
            raise
        except (ValueError, KeyError, IndexError, TypeError, AttributeError):
            raise ProviderError("provider_invalid_response") from None

    def resolve(self, texts: list[str]) -> Any:
        if not self.api_key or not self.model:
            raise ProviderError("provider_unconfigured")
        models = [self.model]
        if self.fallback_model and self.fallback_model != self.model:
            models.append(self.fallback_model)
        last_error: ProviderError | None = None
        for model in models:
            for fmt in self._formats():
                try:
                    output = validate_matching_output(self._complete(texts, model, fmt), len(texts))
                    self.last_model = model
                    return {"ingredients": output}
                except ProviderError as error:
                    last_error = error
                    code = str(error)
                    if code == "provider_unconfigured":
                        raise
                    if code in {"provider_rate_limited", "provider_unavailable"}:
                        break
                    continue
                except (URLError, TimeoutError, OSError):
                    last_error = ProviderError("provider_unavailable")
                    break
        raise last_error or ProviderError("provider_unavailable")


def match_ingredients(
    texts: Sequence[str],
    approved_catalog: Mapping[str, Any],
    reference: Any,
    *,
    provider: Any,
    db: Any = None,
) -> tuple[list[dict[str, Any]], str, str | None, str]:
    """Run AI-primary matching for every submitted string, then ground names.

    Returns ``(rows, provider_status, model, run_status)``. ``run_status`` is
    ``ok`` or ``failed``. On failure, rows are unknown with reason
    ``ai-unavailable``, coverage is unknown, and the original texts are kept.
    """

    model = getattr(provider, "last_model", None) or getattr(provider, "model", None)
    if not texts:
        return [], "ok", model, "ok"

    try:
        raw = provider.resolve(list(texts))
        suggestions = validate_matching_output(
            raw if not isinstance(raw, list) else {"ingredients": raw},
            len(texts),
        )
        rows = ground_ai_suggestions(texts, suggestions, approved_catalog, reference, db=db)
        return rows, "ok", getattr(provider, "last_model", None) or model, "ok"
    except ProviderError as error:
        code = str(error)
        return empty_ai_failure_rows(texts, failure_code="ai-unavailable"), code, model, "failed"
    except Exception:
        return empty_ai_failure_rows(texts, failure_code="ai-unavailable"), "provider_unavailable", model, "failed"


def apply_ai_normalization(
    rows: list[dict[str, Any]],
    approved_catalog: Mapping[str, Any],
    reference: Any,
    *,
    provider: Any,
    db: Any = None,
) -> tuple[list[dict[str, Any]], str, str | None, int]:
    """Compatibility wrapper around ``match_ingredients`` using row originalText.

    Returns ``(rows, provider_status, model, attempted_count)``. Prefer
    ``match_ingredients`` for new call sites.
    """

    texts = [str(row.get("originalText") or "") for row in rows]
    matched, provider_status, model, _run_status = match_ingredients(
        texts, approved_catalog, reference, provider=provider, db=db
    )
    return matched, provider_status, model, len(texts)
