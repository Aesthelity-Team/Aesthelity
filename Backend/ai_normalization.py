"""AI name suggestions for #98 rows the catalog could not resolve.

Catalog lookup always runs first. Only unmatched or ambiguous rows, plus
noisy OCR text, are sent to a provider. The provider may propose a name;
that name is looked up in the catalog again. The provider never assigns an
ingredient ID.

The provider matches the NormalizationProvider interface in
analysis_engine.normalization (model + resolve(texts) -> JSON object), so
it can slot in once #99 merges. The default transport is OpenRouter's
OpenAI-compatible API.
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

from Backend.analysis_engine.normalization import (
    PROMPT,
    PROMPT_VERSION,
    SCHEMA,
    ProviderError,
    _validate,
)
from Backend.ingredient_catalog import name_key, resolve_ingredient_texts


DEFAULT_BASE_URL = "https://openrouter.ai/api/v1"
DEFAULT_MODEL = "nvidia/nemotron-3.5-super-vl:free"
DEFAULT_FALLBACK_MODEL = "google/gemma-4-31b-it:free"
DEFAULT_TIMEOUT = 30.0
MAX_RESPONSE_BYTES = 1_000_000
OPENAI_HOST_MARKERS = ("api.openai.com",)

# Re-exported so callers can use one module for the #98 AI step.
__all__ = [
    "DEFAULT_BASE_URL",
    "DEFAULT_FALLBACK_MODEL",
    "DEFAULT_MODEL",
    "PROMPT_VERSION",
    "ProviderError",
    "OpenRouterNormalizationProvider",
    "apply_ai_normalization",
    "load_backend_env",
    "looks_noisy",
    "needs_ai",
    "suggested_name",
]


_NOISY_HINTS = re.compile(
    r"blurred|illegible|unreadable|undecipherable|ocr\b|\?{2,}|\.{3,}|\ufffd",
    re.IGNORECASE,
)
_REPEATED = re.compile(r"(.)\1{3,}")
_FENCE = re.compile(r"^```(?:json)?\s*|\s*```$", re.IGNORECASE)


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


def looks_noisy(text: str) -> bool:
    """Heuristic for garbled OCR / unreadable label fragments."""

    stripped = text.strip()
    if not stripped or not name_key(stripped):
        return False
    if _NOISY_HINTS.search(stripped) or _REPEATED.search(stripped):
        return True
    letters = sum(char.isalpha() for char in stripped)
    if letters and len(stripped) >= 4 and letters / len(stripped) < 0.5:
        return True
    return False


def needs_ai(row: Mapping[str, Any]) -> bool:
    """True when the catalog left this row unresolved (or the text looks like noisy OCR)."""

    if row.get("reason") == "empty_input" or not name_key(str(row.get("originalText") or "")):
        return False
    mapping = row.get("mapping")
    if mapping in {"confirmed", "uncertain"}:
        return False
    return mapping in {"unmatched", "ambiguous"} or looks_noisy(str(row.get("originalText") or ""))


def suggested_name(ai_row: Mapping[str, Any]) -> str | None:
    """Take a proposed display name only. IDs and other keys are ignored."""

    for key in ("canonicalName", "proposedName"):
        value = ai_row.get(key)
        if isinstance(value, str) and value.strip() and len(value.strip()) <= 500:
            return value.strip()
    return None


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


def _coerce(output: Any, count: int) -> dict[str, Any]:
    """Keep only the shared contract fields, dropping any smuggled IDs."""

    if not isinstance(output, dict) or not isinstance(output.get("ingredients"), list):
        raise ProviderError("provider_invalid_response")
    rows = output["ingredients"]
    if len(rows) != count:
        raise ProviderError("provider_invalid_response")
    cleaned: list[dict[str, Any]] = []
    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            raise ProviderError("provider_invalid_response")
        cleaned.append({
            "index": index,
            "status": row.get("status"),
            "canonicalName": row.get("canonicalName"),
            "proposedName": row.get("proposedName"),
            "reason": row.get("reason") if row.get("reason") is not None else "unspecified",
        })
    return {"ingredients": cleaned}


def accepted_output(output: Any, count: int) -> list[dict[str, Any]]:
    return _validate(_coerce(output, count), count)


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
                "json_schema": {"name": "ingredient_normalization", "strict": True, "schema": SCHEMA},
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
                    output = accepted_output(self._complete(texts, model, fmt), len(texts))
                    self.last_model = model
                    return {"ingredients": output}
                except ProviderError as error:
                    last_error = error
                    code = str(error)
                    if code == "provider_unconfigured":
                        raise
                    if code in {"provider_rate_limited", "provider_unavailable"}:
                        break
                    # schema/format or invalid JSON: try the next format, then the next model
                    continue
                except (URLError, TimeoutError, OSError):
                    last_error = ProviderError("provider_unavailable")
                    break
        raise last_error or ProviderError("provider_unavailable")


def apply_ai_normalization(
    rows: list[dict[str, Any]],
    approved_catalog: Mapping[str, Any],
    reference: Any,
    *,
    provider: Any,
    db: Any = None,
) -> tuple[list[dict[str, Any]], str, str | None, int]:
    """Apply AI name suggestions to unresolved catalog rows, then re-resolve.

    Returns (rows, provider_status, model, attempted_count). On any provider
    failure the original lookup rows are returned unchanged and provider_status
    is a sanitized failure code.
    """

    model = getattr(provider, "last_model", None) or getattr(provider, "model", None)
    targets = [row for row in rows if needs_ai(row)]
    if not targets:
        return rows, "ok", model, 0
    try:
        raw = provider.resolve([row["originalText"] for row in targets])
        suggestions = accepted_output(raw if not isinstance(raw, list) else {"ingredients": raw}, len(targets))
    except ProviderError as error:
        return rows, str(error), model, len(targets)
    except Exception:
        return rows, "provider_unavailable", model, len(targets)

    model = getattr(provider, "last_model", None) or model
    updated = list(rows)
    for row, ai_row in zip(targets, suggestions):
        name = suggested_name(ai_row)
        if not name:
            continue
        try:
            resolved = resolve_ingredient_texts([name], approved_catalog, reference, db=db)[0]
        except Exception:
            continue
        if resolved.get("mapping") not in {"confirmed", "uncertain"}:
            # Suggestion did not land in the catalog: keep the original mapping.
            kept = dict(updated[row["index"]])
            if kept.get("mapping") == "unmatched":
                kept["reason"] = "ai-suggestion-not-in-catalog"
            updated[row["index"]] = kept
            continue
        new_row = dict(resolved)
        new_row["index"] = row["index"]
        new_row["originalText"] = row["originalText"]
        new_row["matchedOn"] = "ai-suggested"
        new_row["source"] = "ai"
        if resolved["mapping"] == "confirmed":
            new_row["reason"] = "ai-suggested + approved match"
        else:
            new_row["reason"] = (
                f"ai-suggested + reference-catalog-only ({resolved.get('suggestedID')})"
            )
        updated[row["index"]] = new_row
    return updated, "ok", model, len(targets)
