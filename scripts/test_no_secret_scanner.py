#!/usr/bin/env python3
"""Focused tests for the shared JSON no-secret scanner."""

from __future__ import annotations

import unittest

import check_drop_authorization_signing_evidence as drop_checker
import check_non_local_release_evidence as non_local_checker
import check_public_beta_evidence as public_beta_checker
import check_signer_custody_readiness as custody_checker
from no_secret_scanner import NoSecretScanError, scan_json_no_secrets


class NoSecretScannerTests(unittest.TestCase):
    """Shared scanner behavior and checker-specific exception wrapping."""

    def test_accepts_benign_policy_words(self) -> None:
        """Policy metadata and non-assignment prose remain valid."""
        scan_json_no_secrets(
            {
                "redaction_policy": {
                    "no_secrets": True,
                    "redacted_fields": [
                        "private_key",
                        "api_key",
                        "raw_signature",
                    ],
                },
                "secret_free_note": "No secrets are retained.",
                "no_secrets_stored": True,
            }
        )

    def test_rejects_secret_shaped_keys(self) -> None:
        """The shared vocabulary covers every migrated checker."""
        for key in (
            "private_key",
            "client-secret",
            "raw_signature",
            "bearer_token",
            "hsm_credential",
            "signer_secret",
        ):
            with self.subTest(key=key):
                with self.assertRaisesRegex(
                    NoSecretScanError,
                    rf"secret-like key found at \$\.{key}",
                ):
                    scan_json_no_secrets({key: "do-not-commit"})

    def test_rejects_assignment_looking_values(self) -> None:
        """Assignment-looking secret values fail independently of their key."""
        for value in (
            "private_key=do-not-commit",
            "client secret: do-not-commit",
            "raw-signature = do-not-commit",
            "hsm credential: do-not-commit",
            "secret=do-not-commit",
        ):
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    NoSecretScanError,
                    r"secret-like value found at \$\.notes",
                ):
                    scan_json_no_secrets({"notes": value})

    def test_reports_nested_paths(self) -> None:
        """Nested list and object locations remain actionable."""
        with self.assertRaisesRegex(
            NoSecretScanError,
            r"secret-like key found at \$\.items\[0\]\.metadata\.api_key",
        ):
            scan_json_no_secrets(
                {"items": [{"metadata": {"api_key": "do-not-commit"}}]}
            )

    def test_migrated_checkers_wrap_shared_errors(self) -> None:
        """Each checker preserves its public exception type and message."""
        cases = (
            (
                public_beta_checker.scan_for_secret_like_data,
                public_beta_checker.PublicBetaEvidenceError,
            ),
            (
                non_local_checker.scan_for_secret_like_data,
                non_local_checker.NonLocalReleaseEvidenceError,
            ),
            (
                drop_checker.scan_for_secret_like_data,
                drop_checker.DropAuthorizationSigningEvidenceError,
            ),
            (
                custody_checker.scan_for_secret_like_data,
                custody_checker.SignerCustodyReadinessError,
            ),
        )
        for scan, error_type in cases:
            with self.subTest(error_type=error_type.__name__):
                with self.assertRaisesRegex(
                    error_type,
                    r"secret-like value found at \$\.nested\[0\]\.notes",
                ):
                    scan({"nested": [{"notes": "api_key=do-not-commit"}]})


if __name__ == "__main__":
    unittest.main()
