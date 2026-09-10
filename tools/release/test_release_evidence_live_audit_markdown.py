#!/usr/bin/env python3
"""Focused tests for release evidence live audit Markdown validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_live_audit_markdown.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_live_audit_markdown", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

JSON_TEST_PATH = Path(__file__).with_name("test_release_evidence_live_audit_report.py")
JSON_TEST_SPEC = importlib.util.spec_from_file_location(
    "test_release_evidence_live_audit_report", JSON_TEST_PATH
)
assert JSON_TEST_SPEC is not None and JSON_TEST_SPEC.loader is not None
json_tests = importlib.util.module_from_spec(JSON_TEST_SPEC)
JSON_TEST_SPEC.loader.exec_module(json_tests)


def write_text(path: Path, value: str) -> None:
    """Write test text with LF line endings."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_raw_text(path: Path, value: str) -> None:
    """Write test text without newline translation."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(value)


class ReleaseEvidenceLiveAuditMarkdownTests(unittest.TestCase):
    """Offline Markdown report checker behavior."""

    def write_valid_bundle(
        self,
        root: Path,
    ) -> tuple[Path, Path, Path, dict[str, object]]:
        """Write a valid schema/report/Markdown bundle under a temp repo root."""
        schema_path = root / "release-artifacts/schema/report.schema.json"
        report_path = root / "release-artifacts/evidence/report.json"
        markdown_path = root / "release-artifacts/evidence/report.md"
        report = json_tests.valid_report(root)
        json_tests.write_json(schema_path, json_tests.valid_schema())
        json_tests.write_json(report_path, report)
        write_text(markdown_path, checker.auditor.markdown_report(report))
        return schema_path, report_path, markdown_path, report

    def run_checker(
        self,
        root: Path,
        schema_path: Path,
        report_path: Path,
        markdown_path: Path,
    ) -> tuple[int, str, str]:
        """Run the checker CLI and return result, stdout, and stderr."""
        stdout = StringIO()
        stderr = StringIO()
        with redirect_stdout(stdout), redirect_stderr(stderr):
            result = checker.main(
                [
                    "--repo-root",
                    str(root),
                    "--schema",
                    str(schema_path.relative_to(root)),
                    "--report-json",
                    str(report_path.relative_to(root)),
                    "--report-md",
                    str(markdown_path.relative_to(root)),
                ]
            )
        return result, stdout.getvalue(), stderr.getvalue()

    def test_default_committed_template_pair_is_valid(self) -> None:
        """The committed JSON/Markdown no-secret template pair passes."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_cli_accepts_valid_markdown_pair(self) -> None:
        """The checker validates retained Markdown without network access."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )

            result, stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 0, stderr)
            self.assertIn("release evidence live audit Markdown is valid", stdout)

    def test_rejects_missing_markdown(self) -> None:
        """Missing retained Markdown is reported cleanly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )
            markdown_path.unlink()

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("missing required file", stderr)

    def test_rejects_malformed_json_before_markdown_compare(self) -> None:
        """Malformed JSON still fails through the JSON report checker."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )
            write_text(report_path, "{")

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("invalid JSON", stderr)

    def test_rejects_markdown_digest_drift(self) -> None:
        """A retained table value cannot drift from the JSON source."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, report = (
                self.write_valid_bundle(root)
            )
            text = markdown_path.read_text(encoding="utf-8")
            digest = str(report["profiles"][0]["snapshot_sha256"])
            write_text(markdown_path, text.replace(digest, "0" * 64, 1))

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("does not match", stderr)

    def test_rejects_command_provenance_drift(self) -> None:
        """Command provenance in Markdown must remain JSON-derived."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )
            text = markdown_path.read_text(encoding="utf-8")
            write_text(markdown_path, text.replace("--profile labels", "--profile bodies", 1))

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("does not match", stderr)

    def test_rejects_crlf_line_ending_drift(self) -> None:
        """CRLF retained Markdown differs from the canonical LF render."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )
            text = markdown_path.read_text(encoding="utf-8").replace("\n", "\r\n")
            write_raw_text(markdown_path, text)

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("does not match", stderr)

    def test_rejects_secret_like_markdown_value(self) -> None:
        """Secret-shaped Markdown content is rejected before drift reporting."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, markdown_path, _report = (
                self.write_valid_bundle(root)
            )
            text = markdown_path.read_text(encoding="utf-8")
            write_text(markdown_path, text + "\napi_key=do-not-commit\n")

            result, _stdout, stderr = self.run_checker(
                root, schema_path, report_path, markdown_path
            )

            self.assertEqual(result, 1)
            self.assertIn("secret-like value", stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
