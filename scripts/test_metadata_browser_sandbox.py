#!/usr/bin/env python3
"""Focused tests for metadata browser sandbox checks."""

from __future__ import annotations

import importlib.util
import sys
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_metadata_browser_sandbox.py")
SPEC = importlib.util.spec_from_file_location("check_metadata_browser_sandbox", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
sandbox_checker = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = sandbox_checker
SPEC.loader.exec_module(sandbox_checker)


def passing_result(
    *,
    expected_script_requests: tuple[str, ...] = ("https://cdn.example/script.js",),
    unexpected_requests: tuple[str, ...] = (),
    page_errors: tuple[str, ...] = (),
    console_errors: tuple[str, ...] = (),
    dependency_loaded: bool = True,
    dependency_url: str | None = "https://cdn.example/script.js",
    script_count: int = 2,
    hash_value: str | None = sandbox_checker.EXPECTED_FINAL_HASH,
    token_id: int | float | None = sandbox_checker.EXPECTED_FINAL_TOKEN_ID,
    token_data_raw: str | None = sandbox_checker.EXPECTED_FINAL_TOKEN_DATA_RAW,
    token_data_is_array: bool = True,
    token_data_values: tuple[object, ...] = sandbox_checker.EXPECTED_FINAL_TOKEN_DATA,
    draw_is_function: bool = True,
    parent_access_blocked: bool = True,
    parent_access_error_name: str | None = "SecurityError",
) -> object:
    """Construct a valid sandbox result with optional field overrides."""

    return sandbox_checker.SandboxResult(
        expected_script_requests=expected_script_requests,
        unexpected_requests=unexpected_requests,
        page_errors=page_errors,
        console_errors=console_errors,
        dependency_loaded=dependency_loaded,
        dependency_url=dependency_url,
        script_count=script_count,
        hash_value=hash_value,
        token_id=token_id,
        token_data_raw=token_data_raw,
        token_data_is_array=token_data_is_array,
        token_data_values=token_data_values,
        draw_is_function=draw_is_function,
        parent_access_blocked=parent_access_blocked,
        parent_access_error_name=parent_access_error_name,
    )


class MetadataBrowserSandboxTests(unittest.TestCase):
    """Unit tests for the metadata browser sandbox checker."""

    def test_current_repository_fixture_loads_expected_dependency(self) -> None:
        """The committed fixture exposes the expected data URI and dependency URL."""

        repo_root = Path(__file__).resolve().parents[1]
        fixture = sandbox_checker.load_final_animation_fixture(
            repo_root / "test" / "fixtures" / "metadata"
        )

        self.assertTrue(fixture.animation_url.startswith("data:text/html;base64,"))
        self.assertIn("let tokenId=1", fixture.animation_html)
        self.assertEqual(fixture.external_script_url, "https://cdn.example/script.js")

    def test_harness_uses_script_only_sandbox(self) -> None:
        """The parent harness enables scripts without same-origin parent access."""

        document = sandbox_checker.build_harness_document(
            "data:text/html;base64,PGh0bWw+PC9odG1sPg=="
        )

        self.assertIn('sandbox="allow-scripts"', document)
        self.assertNotIn("allow-same-origin", document)
        self.assertIn('id="metadata-frame"', document)

    def test_accepts_expected_browser_snapshot(self) -> None:
        """A valid browser snapshot satisfies the sandbox result policy."""

        sandbox_checker.validate_sandbox_result(
            passing_result(),
            expected_external_script_url="https://cdn.example/script.js",
        )

    def test_rejects_duplicate_expected_dependency_requests(self) -> None:
        """The expected external dependency must be requested exactly once."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "exactly one"):
            sandbox_checker.validate_sandbox_result(
                passing_result(
                    expected_script_requests=(
                        "https://cdn.example/script.js",
                        "https://cdn.example/script.js",
                    )
                ),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_unexpected_outbound_request(self) -> None:
        """Unexpected HTTP(S) requests fail the sandbox policy."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "unexpected outbound"):
            sandbox_checker.validate_sandbox_result(
                passing_result(unexpected_requests=("https://tracker.example/pixel",)),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_page_error(self) -> None:
        """Browser page errors fail the sandbox policy."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "page errors"):
            sandbox_checker.validate_sandbox_result(
                passing_result(page_errors=("ReferenceError: x is not defined",)),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_console_error(self) -> None:
        """Browser console errors fail the sandbox policy."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "console errors"):
            sandbox_checker.validate_sandbox_result(
                passing_result(console_errors=("error: bad draw",)),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_unloaded_dependency_stub(self) -> None:
        """The deterministic dependency stub must execute inside the frame."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "dependency stub"):
            sandbox_checker.validate_sandbox_result(
                passing_result(dependency_loaded=False),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_script_count(self) -> None:
        """The browser frame must contain the expected two-script wrapper."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "two scripts"):
            sandbox_checker.validate_sandbox_result(
                passing_result(script_count=3),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_hash_bootstrap_value(self) -> None:
        """The committed final hash bootstrap value is locked by the sandbox check."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "hash"):
            sandbox_checker.validate_sandbox_result(
                passing_result(hash_value="0x02"),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_bootstrap_value(self) -> None:
        """The committed tokenId bootstrap value is locked by the sandbox check."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "tokenId"):
            sandbox_checker.validate_sandbox_result(
                passing_result(token_id=10_000_000_000),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_token_data_raw_bootstrap_value(self) -> None:
        """The raw token data bootstrap string is locked by the sandbox check."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "tokenDataRaw"):
            sandbox_checker.validate_sandbox_result(
                passing_result(token_data_raw="4,5,6"),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_token_data_values(self) -> None:
        """The parsed tokenData array is locked by the sandbox check."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "tokenData"):
            sandbox_checker.validate_sandbox_result(
                passing_result(token_data_values=(1, 2)),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_missing_draw_function(self) -> None:
        """The generative draw bootstrap function must be present."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "draw"):
            sandbox_checker.validate_sandbox_result(
                passing_result(draw_is_function=False),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_missing_parent_sandbox_isolation(self) -> None:
        """The sandboxed frame must not be able to read the parent document."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "parent document"):
            sandbox_checker.validate_sandbox_result(
                passing_result(parent_access_blocked=False, parent_access_error_name=None),
                expected_external_script_url="https://cdn.example/script.js",
            )

    def test_rejects_wrong_parent_access_error(self) -> None:
        """Parent-document access must fail with the expected browser security error."""

        with self.assertRaisesRegex(sandbox_checker.BrowserSandboxError, "unexpected error"):
            sandbox_checker.validate_sandbox_result(
                passing_result(parent_access_error_name="TypeError"),
                expected_external_script_url="https://cdn.example/script.js",
            )


if __name__ == "__main__":
    unittest.main()
