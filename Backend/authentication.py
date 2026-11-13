"""Firebase ID-token authentication helpers for backend API requests."""

from __future__ import annotations

from collections.abc import Callable, Mapping
from typing import Any


TokenVerifier = Callable[[str], Mapping[str, Any]]


def verified_firebase_uid(
    authorization_header: str | None,
    verify_token: TokenVerifier,
) -> str | None:
    """Return the UID from a verified Firebase Bearer token, or ``None``.

    The verifier must be Firebase Admin SDK's ``verify_id_token``. This helper
    parses the HTTP header and extracts the UID only after verification. It
    deliberately accepts no UID from request data.
    """
    if not isinstance(authorization_header, str):
        return None

    parts = authorization_header.strip().split()
    if len(parts) != 2 or parts[0].casefold() != "bearer":
        return None

    token = parts[1]
    if not token or len(token) > 16_384:
        return None

    try:
        claims = verify_token(token)
    except Exception:
        # Invalid, expired, revoked, or unverifiable credentials all fail
        # closed. Callers should return the same 401 response for each case.
        return None

    if not isinstance(claims, Mapping):
        return None
    uid = claims.get("uid")
    if not isinstance(uid, str) or not uid.strip() or uid != uid.strip():
        return None
    return uid
