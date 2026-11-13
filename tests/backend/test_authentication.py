"""Unit tests for the backend Firebase ID-token boundary."""

from __future__ import annotations

import unittest

from Backend.authentication import verified_firebase_uid


class VerifiedFirebaseUIDTests(unittest.TestCase):
    def test_valid_bearer_token_returns_uid_from_verified_claims(self):
        calls = []

        def verify(token):
            calls.append(token)
            return {"uid": "firebase-user-123"}

        uid = verified_firebase_uid("Bearer signed-token", verify)

        self.assertEqual(uid, "firebase-user-123")
        self.assertEqual(calls, ["signed-token"])

    def test_bearer_scheme_is_case_insensitive_and_whitespace_is_supported(self):
        uid = verified_firebase_uid(
            "  bEaReR   signed-token  ", lambda token: {"uid": "user-1"}
        )

        self.assertEqual(uid, "user-1")

    def test_missing_or_malformed_authorization_is_rejected_without_verification(self):
        def should_not_run(_token):
            self.fail("Verifier must not run for a malformed header")

        for header in (None, "", "Basic abc", "Bearer", "Bearer a b"):
            with self.subTest(header=header):
                self.assertIsNone(verified_firebase_uid(header, should_not_run))

    def test_invalid_or_expired_token_is_rejected(self):
        def reject(_token):
            raise ValueError("invalid token details must not escape")

        self.assertIsNone(verified_firebase_uid("Bearer bad-token", reject))

    def test_missing_or_malformed_uid_claim_is_rejected(self):
        for claims in ({}, {"uid": ""}, {"uid": " user-1"}, {"uid": 42}):
            with self.subTest(claims=claims):
                self.assertIsNone(
                    verified_firebase_uid("Bearer token", lambda _token: claims)
                )

    def test_request_cannot_supply_a_uid_instead_of_a_verified_token(self):
        self.assertIsNone(
            verified_firebase_uid(None, lambda _token: {"uid": "attacker-choice"})
        )


if __name__ == "__main__":
    unittest.main()
