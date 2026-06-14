#!/usr/bin/env python3
"""Focused tests for live audit report archive generation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name(
    "generate_release_evidence_live_audit_archive.py"
)
SPEC = importlib.util.spec_from_file_location(
    "generate_release_evidence_live_audit_archive",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)

JSON_TEST_PATH = Path(__file__).with_name("test_release_evidence_live_audit_report.py")
JSON_TEST_SPEC = importlib.util.spec_from_file_location(
    "test_release_evidence_live_audit_report",
    JSON_TEST_PATH,
)
assert JSON_TEST_SPEC is not None and JSON_TEST_SPEC.loader is not None
json_tests = importlib.util.module_from_spec(JSON_TEST_SPEC)
JSON_TEST_SPEC.loader.exec_module(json_tests)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text with LF line endings."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON with LF line endings."""
    json_tests.write_json(path, value)


def seed_bundle(
    root: Path,
    *,
    report_json: Path = generator.DEFAULT_TEMPLATE_JSON,
    report_md: Path = generator.DEFAULT_TEMPLATE_MARKDOWN,
) -> dict[str, object]:
    """Write a valid schema/report/Markdown bundle under a temp repo root."""
    report = json_tests.valid_report(root)
    write_json(root / generator.report_checker.DEFAULT_SCHEMA, json_tests.valid_schema())
    write_json(root / report_json, report)
    write_text(root / report_md, generator.markdown_checker.auditor.markdown_report(report))
    return report


def pair(
    archive_id: str,
    report_json: Path = generator.DEFAULT_TEMPLATE_JSON,
    report_md: Path = generator.DEFAULT_TEMPLATE_MARKDOWN,
    *,
    record_type: str = "template",
) -> dict[str, object]:
    """Return one archive pair descriptor."""
    return {
        "archive_id": archive_id,
        "record_type": record_type,
        "report_json": report_json,
        "report_markdown": report_md,
    }


class ReleaseEvidenceLiveAuditArchiveTests(unittest.TestCase):
    """Generator behavior for the live audit report archive index."""

    def test_default_committed_archive_is_current(self) -> None:
        """The committed archive index matches committed no-secret inputs."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--check"])

        self.assertEqual(result, 0)

    def test_archive_indexes_valid_report_pair(self) -> None:
        """A valid JSON/Markdown pair is summarized with validation commands."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)

            archive = generator.build_archive(
                root,
                generator.report_checker.DEFAULT_SCHEMA,
                [pair("template")],
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
                generator.DEFAULT_ARCHIVE_DIR,
            )

            self.assertEqual(archive["schema_version"], generator.ARCHIVE_SCHEMA)
            self.assertEqual(archive["report_count"], 1)
            row = archive["rows"][0]
            self.assertEqual(row["archive_id"], "template")
            self.assertEqual(row["validation_status"], "passed")
            self.assertIn(
                "python scripts/check_release_evidence_live_audit_report.py "
                "--report-json release-artifacts/evidence/"
                "release-evidence-live-audit-report-template.json",
                row["validation_commands"],
            )
            self.assertIn(
                "python scripts/test_release_evidence_live_audit_archive.py",
                archive["validation_commands"],
            )

    def test_outputs_are_deterministic(self) -> None:
        """Rendering the same archive twice produces identical outputs."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)
            args = (
                root,
                generator.report_checker.DEFAULT_SCHEMA,
                [pair("template")],
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
                generator.DEFAULT_ARCHIVE_DIR,
            )

            self.assertEqual(generator.build_outputs(*args), generator.build_outputs(*args))

    def test_discovers_optional_archive_directory_reports(self) -> None:
        """Future retained report bundles can be discovered from the archive dir."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)
            report_json = generator.DEFAULT_ARCHIVE_DIR / "operator-audit.json"
            report_md = generator.DEFAULT_ARCHIVE_DIR / "operator-audit.md"
            seed_bundle(root, report_json=report_json, report_md=report_md)

            pairs = generator.default_report_pairs(root, generator.DEFAULT_ARCHIVE_DIR)
            archive = generator.build_archive(
                root,
                generator.report_checker.DEFAULT_SCHEMA,
                pairs,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
                generator.DEFAULT_ARCHIVE_DIR,
            )

            self.assertEqual(
                [row["archive_id"] for row in archive["rows"]],
                ["operator-audit", "template"],
            )
            self.assertEqual(archive["report_count"], 2)

    def test_rejects_duplicate_archive_ids(self) -> None:
        """Archive IDs must be unique."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceLiveAuditArchiveError,
                "duplicate archive_id",
            ):
                generator.build_archive(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    [pair("template"), pair("template")],
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

    def test_rejects_missing_markdown_pair(self) -> None:
        """An indexed JSON report must have its retained Markdown pair."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_json = generator.DEFAULT_ARCHIVE_DIR / "operator-audit.json"
            report_md = generator.DEFAULT_ARCHIVE_DIR / "operator-audit.md"
            seed_bundle(root, report_json=report_json, report_md=report_md)
            (root / report_md).unlink()

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceLiveAuditArchiveError,
                "references missing file",
            ):
                generator.build_archive(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    [pair("operator-audit", report_json, report_md)],
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

    def test_rejects_markdown_drift(self) -> None:
        """Archive generation validates JSON/Markdown parity for each row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)
            write_text(root / generator.DEFAULT_TEMPLATE_MARKDOWN, "stale\n")

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceLiveAuditArchiveError,
                "does not match",
            ):
                generator.build_archive(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    [pair("template")],
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

    def test_rejects_path_escape(self) -> None:
        """Archive row paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceLiveAuditArchiveError,
                "repository-relative path|inside the repository",
            ):
                generator.build_archive(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    [pair("template", Path("../report.json"))],
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

    def test_rejects_secret_like_archive_metadata(self) -> None:
        """Secret-shaped values cannot flow into the archive index."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceLiveAuditArchiveError,
                "secret-like value",
            ):
                generator.build_archive(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    [
                        pair(
                            "api_key: do-not-commit",
                            record_type="operator_supplied",
                        )
                    ],
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

    def test_check_mode_rejects_output_drift(self) -> None:
        """Check mode fails when generated outputs are stale."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_bundle(root)
            pairs = [pair("template")]
            generator.write_outputs(
                root,
                generator.report_checker.DEFAULT_SCHEMA,
                pairs,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
                generator.DEFAULT_ARCHIVE_DIR,
            )
            write_text(root / generator.DEFAULT_MARKDOWN_OUTPUT, "stale\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    generator.report_checker.DEFAULT_SCHEMA,
                    pairs,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                    generator.DEFAULT_ARCHIVE_DIR,
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/"
                "release-evidence-live-audit-report-archive.md",
                stderr.getvalue(),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
