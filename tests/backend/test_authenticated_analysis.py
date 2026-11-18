"""HTTP acceptance tests for the authenticated POST /api/v1/analyses endpoint.

These tests exercise the full HTTP request-response cycle using a real
AnalysisHTTPServer bound to a random loopback port.  They inject a fake
token_verifier so no live Firebase Admin credentials are needed.

Run with:
    python3 -m unittest discover -s tests/backend -v
"""

from __future__ import annotations

import http.client
import json
import sys
import threading
import unittest
from unittest.mock import MagicMock, patch
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from Backend.analysis_api import AnalysisHTTPServer  # noqa: E402
from analysis_engine.product_input import load_alias_catalog  # noqa: E402

CATALOG_PATH = (
    ROOT / "Aesthelity" / "Aesthelity" / "Resources" / "SampleData" / "ingredient-aliases.json"
)

# ---------------------------------------------------------------------------
# Shared payloads (match the approved AN-02 fixture shapes exactly)
# ---------------------------------------------------------------------------

# A minimal valid routine that produces no findings (the "normal" fixture).
VALID_NORMAL_PAYLOAD = {
    "contractVersion": 1,
    "period": "am",
    "recordedAllergies": {"status": "known", "ingredientIDs": []},
    "products": [
        {
            "productID": "serum_hydrating",
            "listStatus": "complete",
            "catalogVersion": 3,
            "ingredients": [
                {"originalText": "Water", "mapping": "confirmed", "ingredientID": "water"},
                {"originalText": "Glycerin", "mapping": "confirmed", "ingredientID": "glycerin"},
            ],
        }
    ],
}

# A valid routine that triggers the approved retinol + exfoliant caution.
VALID_CAUTION_PAYLOAD = {
    "contractVersion": 1,
    "period": "pm",
    "recordedAllergies": {"status": "known", "ingredientIDs": []},
    "products": [
        {
            "productID": "example-retinol",
            "listStatus": "complete",
            "catalogVersion": 3,
            "ingredients": [
                {"originalText": "Retinol", "mapping": "confirmed", "ingredientID": "retinol"},
                {"originalText": "Water", "mapping": "confirmed", "ingredientID": "water"},
            ],
        },
        {
            "productID": "example-glycolic",
            "listStatus": "complete",
            "catalogVersion": 3,
            "ingredients": [
                {
                    "originalText": "Glycolic Acid",
                    "mapping": "confirmed",
                    "ingredientID": "glycolic-acid",
                },
            ],
        },
    ],
}


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

class _FakeNormalizationProvider:
    model = "test-normalizer"
    last_model = model

    def resolve(self, texts):
        return {
            "ingredients": [
                {
                    "index": index,
                    "status": "identified",
                    "normalizedName": text,
                    "bestGuess": None,
                    "explanation": "Test match.",
                }
                for index, text in enumerate(texts)
            ]
        }


class _FakeAnalysisProvider:
    model = "test-analysis"

    def generate(self, context):
        references = context.get("approvedReferences", [])
        if not references:
            return {"assessment": "no_findings", "findings": []}

        reference = references[0]
        criteria = reference.get("matchCriteria", {})
        allowed_ids = set(criteria.get("allIngredientIDs", []))
        allowed_ids.update(criteria.get("anyIngredientIDs", []))
        allowed_classes = set(criteria.get("allIngredientClasses", []))

        product_ids = []
        ingredient_ids = []
        for product in context["products"]:
            product_matches = [
                row["ingredientID"]
                for row in product["ingredients"]
                if row["ingredientID"] in allowed_ids
                or allowed_classes.intersection(row.get("classes", []))
            ]
            if product_matches:
                product_ids.append(product["productID"])
                for ingredient_id in product_matches:
                    if ingredient_id not in ingredient_ids:
                        ingredient_ids.append(ingredient_id)

        return {
            "assessment": "findings",
            "findings": [{
                "referenceIDs": [reference["referenceID"]],
                "outcome": reference["allowedOutcome"],
                "productIDs": product_ids,
                "ingredientIDs": ingredient_ids,
                "explanation": "Test explanation based on the supplied reference.",
                "reason": "The test routine matches the reference conditions.",
            }],
        }

def _make_server(demo_mode: bool = False) -> AnalysisHTTPServer:
    """Spin up an AnalysisHTTPServer on a random loopback port.

    Uses an injected token_verifier that accepts only the string "valid-token"
    and treats every other value as expired/revoked so no Firebase Admin SDK is
    needed.
    """
    catalog = load_alias_catalog(CATALOG_PATH)

    # Fake in-memory Firestore db — the analysis endpoint does not use it, but
    # AnalysisHTTPServer requires the attribute to be present.
    class _NullDB:
        def collection(self, _name: str) -> None:  # type: ignore[return]
            raise RuntimeError("Firestore should not be reached by the analysis endpoint.")

    server = AnalysisHTTPServer(
        ("127.0.0.1", 0),  # port=0 → OS picks a free port
        db=_NullDB(),
        app=None,
        catalog=catalog,
        database_id="test",
        demo_mode=demo_mode,
    )

    def fake_verifier(token: str) -> dict:
        if token == "valid-token":
            return {"uid": "test-user-uid"}
        raise ValueError("expired or invalid token")

    server.token_verifier = fake_verifier  # type: ignore[attr-defined]
    server.normalization_provider = _FakeNormalizationProvider()
    server.analysis_provider = _FakeAnalysisProvider()
    return server


def _request(
    server: AnalysisHTTPServer,
    method: str,
    path: str = "/api/v1/analyses",
    body: object = None,
    token: str | None = "valid-token",
    content_type: str = "application/json",
) -> tuple[int, dict]:
    """Make one HTTP request and return (status_code, parsed_body)."""
    conn = http.client.HTTPConnection(*server.server_address, timeout=5)
    headers: dict[str, str] = {}
    if content_type:
        headers["Content-Type"] = content_type
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    encoded: bytes | None = None
    if body is not None:
        encoded = json.dumps(body).encode("utf-8")
        headers["Content-Length"] = str(len(encoded))
    conn.request(method, path, encoded, headers)
    response = conn.getresponse()
    result = json.loads(response.read())
    conn.close()
    return response.status, result


# ---------------------------------------------------------------------------
# Test suite
# ---------------------------------------------------------------------------


class AuthenticatedAnalysisEndpointTests(unittest.TestCase):
    """
    Covers every acceptance criterion for POST /api/v1/analyses with auth.

    The server starts once per class and is shut down in tearDownClass.
    """

    @classmethod
    def setUpClass(cls) -> None:
        cls.server = _make_server(demo_mode=False)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join()

    # ------------------------------------------------------------------
    # Happy-path: authenticated requests return correct analysis results
    # ------------------------------------------------------------------

    def test_valid_token_without_relevant_references_fails_closed(self):
        """A routine with no relevant approved references returns unknown."""
        status, body = _request(self.server, "POST", body=VALID_NORMAL_PAYLOAD)

        self.assertEqual(status, 200)
        self.assertEqual(body["contractVersion"], 1)
        self.assertIn("ruleVersion", body)
        self.assertEqual(body["period"], "am")
        self.assertEqual(body["productIDs"], ["serum_hydrating"])
        self.assertEqual(body["outcome"], "findings")
        self.assertEqual(body["completeness"], "incomplete")
        self.assertEqual(body["findings"][0]["outcome"], "unknown")
        self.assertEqual(
            body["findings"][0]["ruleID"],
            "coverage.ai-analysis-unavailable",
        )
        self.assertEqual(body["coverage"]["status"], "incomplete")
        self.assertIn("limitations", body)

    def test_valid_token_caution_routine_returns_200_with_findings(self):
        """
        STEP 2b — Happy path, caution finding.

        Retinol + glycolic acid triggers the team-approved caution rule.
        The response must include outcome="findings" and the matching finding.
        """
        status, body = _request(self.server, "POST", body=VALID_CAUTION_PAYLOAD)

        self.assertEqual(status, 200)
        self.assertEqual(body["outcome"], "findings")
        self.assertEqual(body["period"], "pm")
        self.assertEqual(len(body["findings"]), 1)
        finding = body["findings"][0]
        self.assertEqual(
            finding["outcome"],
            "caution",
            json.dumps(body, indent=2),
        )
        self.assertEqual(finding["ruleID"], "irritation.retinol-benzoyl-peroxide-with-exfoliant")
        self.assertIn("retinol", finding["ingredientIDs"])
        self.assertIn("glycolic-acid", finding["ingredientIDs"])

    def test_response_always_includes_cache_control_no_store(self):
        """
        Analysis results must never be cached (they contain personal health data).
        """
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        encoded = json.dumps(VALID_NORMAL_PAYLOAD).encode("utf-8")
        conn.request(
            "POST",
            "/api/v1/analyses",
            encoded,
            {
                "Content-Type": "application/json",
                "Content-Length": str(len(encoded)),
                "Authorization": "Bearer valid-token",
            },
        )
        response = conn.getresponse()
        response.read()
        conn.close()
        self.assertEqual(response.getheader("Cache-Control"), "no-store")

    # ------------------------------------------------------------------
    # Authentication enforcement — 401 cases
    # ------------------------------------------------------------------

    def test_missing_authorization_header_returns_401(self):
        """
        STEP 2c — No Authorization header at all.

        The endpoint must reject the request before reading the body.
        """
        status, body = _request(
            self.server, "POST", body=VALID_NORMAL_PAYLOAD, token=None
        )
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "UNAUTHENTICATED")

    def test_wrong_auth_scheme_returns_401(self):
        """
        STEP 2d — 'Basic <credentials>' is not accepted; only Bearer tokens are.
        """
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        encoded = json.dumps(VALID_NORMAL_PAYLOAD).encode("utf-8")
        conn.request(
            "POST",
            "/api/v1/analyses",
            encoded,
            {
                "Content-Type": "application/json",
                "Content-Length": str(len(encoded)),
                "Authorization": "Basic dXNlcjpwYXNz",
            },
        )
        response = conn.getresponse()
        result = json.loads(response.read())
        conn.close()
        self.assertEqual(response.status, 401)
        self.assertEqual(result["error"]["code"], "UNAUTHENTICATED")

    def test_expired_or_invalid_token_returns_401(self):
        """
        STEP 2e — Expired, revoked, or forged tokens must be rejected.

        The fake verifier raises for any token other than "valid-token".
        """
        for bad_token in ("expired-token", "revoked-token", "forged", ""):
            with self.subTest(token=bad_token):
                token_header = bad_token if bad_token else None
                status, body = _request(
                    self.server, "POST", body=VALID_NORMAL_PAYLOAD, token=token_header
                )
                self.assertEqual(status, 401)
                self.assertEqual(body["error"]["code"], "UNAUTHENTICATED")

    def test_bearer_token_with_no_value_returns_401(self):
        """
        'Authorization: Bearer' with nothing after it must not reach the verifier.
        verified_firebase_uid rejects this at the parsing stage.
        """
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        encoded = json.dumps(VALID_NORMAL_PAYLOAD).encode("utf-8")
        conn.request(
            "POST",
            "/api/v1/analyses",
            encoded,
            {
                "Content-Type": "application/json",
                "Content-Length": str(len(encoded)),
                "Authorization": "Bearer",
            },
        )
        response = conn.getresponse()
        result = json.loads(response.read())
        conn.close()
        self.assertEqual(response.status, 401)
        self.assertEqual(result["error"]["code"], "UNAUTHENTICATED")

    # ------------------------------------------------------------------
    # Request validation — 400 cases (checked after auth)
    # ------------------------------------------------------------------

    def test_wrong_content_type_returns_400(self):
        """
        STEP 2f — Content-Type must be application/json.
        Even with a valid token, a text/plain body must be rejected.
        """
        status, body = _request(
            self.server,
            "POST",
            body=VALID_NORMAL_PAYLOAD,
            content_type="text/plain",
        )
        self.assertEqual(status, 400)
        self.assertEqual(body["error"]["code"], "INVALID_REQUEST")

    def test_missing_content_length_returns_400(self):
        """
        A request with Content-Length: 0 (empty body) must be rejected.
        """
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        conn.request(
            "POST",
            "/api/v1/analyses",
            None,
            {
                "Content-Type": "application/json",
                "Content-Length": "0",
                "Authorization": "Bearer valid-token",
            },
        )
        response = conn.getresponse()
        result = json.loads(response.read())
        conn.close()
        self.assertEqual(response.status, 400)
        self.assertEqual(result["error"]["code"], "INVALID_REQUEST")

    def test_malformed_json_returns_400(self):
        """
        STEP 2g — A body that is not valid JSON must return 400.
        """
        conn = http.client.HTTPConnection(*self.server.server_address, timeout=5)
        garbage = b"{ this is not valid json !!!"
        conn.request(
            "POST",
            "/api/v1/analyses",
            garbage,
            {
                "Content-Type": "application/json",
                "Content-Length": str(len(garbage)),
                "Authorization": "Bearer valid-token",
            },
        )
        response = conn.getresponse()
        result = json.loads(response.read())
        conn.close()
        self.assertEqual(response.status, 400)
        self.assertEqual(result["error"]["code"], "INVALID_REQUEST")

    def test_wrong_contract_version_returns_400(self):
        """
        STEP 2h — contractVersion must be exactly 1 (not 0, 2, or missing).
        """
        for bad_version in (0, 2, "1", None):
            payload = dict(VALID_NORMAL_PAYLOAD, contractVersion=bad_version)
            with self.subTest(contractVersion=bad_version):
                status, body = _request(self.server, "POST", body=payload)
                self.assertEqual(status, 400)
                self.assertEqual(body["error"]["code"], "INVALID_REQUEST")

    def test_missing_period_returns_400_with_stable_code(self):
        """
        A routine without 'period' must be rejected with a stable error code
        from the analysis engine, not an unhandled exception.
        """
        payload = {
            "contractVersion": 1,
            "recordedAllergies": {"status": "known", "ingredientIDs": []},
            "products": [
                {
                    "productID": "x",
                    "listStatus": "unavailable",
                    "catalogVersion": 3,
                    "ingredients": [],
                }
            ],
        }
        status, body = _request(self.server, "POST", body=payload)
        self.assertEqual(status, 400)
        # The analysis engine raises AnalysisInputError with code "missing-period"
        self.assertIn("code", body["error"])

    def test_empty_products_list_returns_400(self):
        """An empty products array must be rejected by the engine."""
        payload = {
            "contractVersion": 1,
            "period": "am",
            "recordedAllergies": {"status": "known", "ingredientIDs": []},
            "products": [],
        }
        status, body = _request(self.server, "POST", body=payload)
        self.assertEqual(status, 400)

    def test_duplicate_product_ids_returns_400(self):
        """Duplicate productIDs in a single request must be rejected."""
        single = {
            "productID": "same",
            "listStatus": "unavailable",
            "catalogVersion": 3,
            "ingredients": [],
        }
        payload = {
            "contractVersion": 1,
            "period": "am",
            "recordedAllergies": {"status": "known", "ingredientIDs": []},
            "products": [single, single],
        }
        status, body = _request(self.server, "POST", body=payload)
        self.assertEqual(status, 400)

    # ------------------------------------------------------------------
    # Demo-mode bypass is NOT available for the analysis endpoint itself
    # (demo_mode=True skips token verification, which is intentional for
    #  local simulator runs — this test documents that behaviour explicitly)
    # ------------------------------------------------------------------

    def test_demo_mode_bypasses_token_check_for_analysis(self):
        """
        STEP 2i — Demo mode behaviour (documented intentional bypass).

        When AESTHELITY_DEMO_MODE=1, the server skips token verification so
        the iOS simulator can call the analysis endpoint without real auth.
        This test asserts that behaviour is preserved and that a request with
        NO Authorization header still succeeds in demo mode.

        NOTE: demo mode is restricted to loopback by the CLI startup guard and
        must NEVER be used in a deployed environment.
        """
        demo_server = _make_server(demo_mode=True)
        t = threading.Thread(target=demo_server.serve_forever, daemon=True)
        t.start()
        try:
            status, body = _request(demo_server, "POST", body=VALID_NORMAL_PAYLOAD, token=None)
            self.assertEqual(status, 200)
            self.assertEqual(body["contractVersion"], 1)
        finally:
            demo_server.shutdown()
            demo_server.server_close()
            t.join()

    def test_non_demo_mode_rejects_unauthenticated_even_with_valid_body(self):
        """
        STEP 2j — Demo bypass must NOT be active in non-demo mode.

        This is the complement of the demo-mode test: even with a perfectly
        valid body, a missing token must return 401 when demo_mode=False.
        """
        status, body = _request(
            self.server, "POST", body=VALID_NORMAL_PAYLOAD, token=None
        )
        self.assertEqual(status, 401)
        self.assertEqual(body["error"]["code"], "UNAUTHENTICATED")

    # ------------------------------------------------------------------
    # Error response shape is consistent
    # ------------------------------------------------------------------

    def test_error_responses_always_include_requestid(self):
        """
        Every error response must include a requestID field so callers can
        correlate client-side logs with server logs.
        """
        for bad_token in (None, "invalid"):
            with self.subTest(token=bad_token):
                status, body = _request(
                    self.server, "POST", body=VALID_NORMAL_PAYLOAD, token=bad_token
                )
                self.assertEqual(status, 401)
                self.assertIn("requestID", body["error"])
                self.assertTrue(body["error"]["requestID"])  # non-empty


    def test_server_failure_returns_500_with_internal_error(self):
        """
        Unexpected engine or internal errors must return 500 INTERNAL_ERROR
        without leaking server details or secrets in the response.
        """
        with patch(
            "Backend.analysis_api.analyze_normalized_routine",
            side_effect=RuntimeError("internal crash detail"),
        ):
            status, body = _request(
                self.server, "POST", body=VALID_NORMAL_PAYLOAD
            )
            self.assertEqual(status, 500)
            self.assertEqual(body["error"]["code"], "INTERNAL_ERROR")
            self.assertEqual(
                body["error"]["message"],
                "The analysis could not be completed.",
            )
            self.assertNotIn("internal crash detail", json.dumps(body))
            self.assertIn("requestID", body["error"])
    def test_production_auth_verifies_with_check_revoked_true(self):
        """
        When token_verifier is not injected (production configuration), the
        server must call firebase_admin.auth.verify_id_token with check_revoked=True.
        """
        prod_server = _make_server(demo_mode=False)
        # Delete injected token_verifier so it takes the production SDK branch
        del prod_server.token_verifier
        fake_app = object()
        prod_server.firebase_app = fake_app

        t = threading.Thread(target=prod_server.serve_forever, daemon=True)
        t.start()
        try:
            mock_verify = MagicMock(return_value={"uid": "prod-user-123"})
            with patch("firebase_admin.auth.verify_id_token", mock_verify):
                status, body = _request(
                    prod_server, "POST", body=VALID_NORMAL_PAYLOAD, token="prod-raw-token"
                )
                self.assertEqual(status, 200)
                mock_verify.assert_called_once_with(
                    "prod-raw-token", app=fake_app, check_revoked=True
                )
        finally:
            prod_server.shutdown()
            prod_server.server_close()
            t.join()


if __name__ == "__main__":
    unittest.main()
