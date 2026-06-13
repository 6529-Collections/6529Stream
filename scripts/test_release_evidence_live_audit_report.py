#!/usr/bin/env python3
"""Focused tests for release evidence live audit report validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_live_audit_report.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_live_audit_report", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON test data."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def write_text(path: Path, value: str) -> None:
    """Write test text with LF line endings."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_schema() -> dict[str, object]:
    """Build a minimal schema accepted by the checker."""
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "properties": {
            "schema_version": {"const": checker.REPORT_SCHEMA_VERSION},
            "repo": {"const": checker.REPO_FULL_NAME},
            "profiles": {
                "minItems": len(checker.DEFAULT_PROFILES),
                "maxItems": len(checker.DEFAULT_PROFILES),
            },
            "validation": {
                "properties": {
                    "profile_count": {"const": len(checker.DEFAULT_PROFILES)}
                }
            },
        },
    }


def snapshot_path(profile: str) -> str:
    """Return the repository-relative snapshot path for a profile."""
    return f"tmp/live-audit/{profile}.json"


def write_snapshot(root: Path, profile: str) -> str:
    """Write a tiny retained snapshot and return its digest."""
    path = root / snapshot_path(profile)
    write_json(
        path,
        [{"number": 200 + len(profile), "title": f"{profile} snapshot"}],
    )
    return checker.file_sha256_hex(path)


def valid_profile(root: Path, profile: str) -> dict[str, object]:
    """Build one valid profile result."""
    path = snapshot_path(profile)
    return {
        "profile": profile,
        "snapshot_path": path,
        "snapshot_sha256": write_snapshot(root, profile),
        "export_command": (
            "python scripts/export_release_evidence_issue_snapshot.py "
            f"--profile {profile} --repo {checker.REPO_FULL_NAME} --limit 100 "
            f"--output {path} --gh gh"
        ),
        "checker_command": (
            f"python scripts/{checker.auditor.PROFILE_CONFIG[profile]['checker']} "
            f"--live-json {path}"
        ),
        "export_status": "passed",
        "checker_status": "passed",
    }


def valid_report(root: Path) -> dict[str, object]:
    """Build a valid no-secret retained report."""
    profiles = [valid_profile(root, profile) for profile in checker.DEFAULT_PROFILES]
    return {
        "schema_version": checker.REPORT_SCHEMA_VERSION,
        "repo": checker.REPO_FULL_NAME,
        "generated_at": "2026-06-13T22:00:00Z",
        "readiness_claim": "blocked",
        "no_secret_notice": checker.auditor.NO_SECRET_NOTICE,
        "readiness_warning": checker.auditor.READINESS_WARNING,
        "profiles": profiles,
        "validation": {
            "status": "passed",
            "profile_count": len(profiles),
        },
    }


class ReleaseEvidenceLiveAuditReportTests(unittest.TestCase):
    """Offline report checker behavior."""

    def write_valid_bundle(self, root: Path) -> tuple[Path, Path, dict[str, object]]:
        """Write a valid schema/report pair under a temp repo root."""
        schema_path = root / "release-artifacts/schema/report.schema.json"
        report_path = root / "release-artifacts/evidence/report.json"
        report = valid_report(root)
        write_json(schema_path, valid_schema())
        write_json(report_path, report)
        return schema_path, report_path, report

    def assert_checker_fails(
        self,
        report: dict[str, object],
        root: Path,
        message: str,
    ) -> None:
        """Assert direct document validation fails with context."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceLiveAuditReportError,
            message,
        ):
            checker.validate_report_document(report, root)

    def test_default_committed_template_is_valid(self) -> None:
        """The committed no-secret template report passes the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main([])

        self.assertEqual(result, 0)

    def test_cli_accepts_valid_report(self) -> None:
        """The checker validates a retained report without network access."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, _report = self.write_valid_bundle(root)
            stdout = StringIO()

            with redirect_stdout(stdout), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--schema",
                        str(schema_path.relative_to(root)),
                        "--report-json",
                        str(report_path.relative_to(root)),
                    ]
                )

            self.assertEqual(result, 0)
            self.assertIn("release evidence live audit report is valid", stdout.getvalue())

    def test_rejects_malformed_json(self) -> None:
        """Malformed report JSON is reported cleanly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path = root / "schema.json"
            report_path = root / "report.json"
            write_json(schema_path, valid_schema())
            write_text(report_path, "{")
            stderr = StringIO()

            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--schema",
                        str(schema_path.relative_to(root)),
                        "--report-json",
                        str(report_path.relative_to(root)),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("invalid JSON", stderr.getvalue())

    def test_rejects_schema_const_drift(self) -> None:
        """The committed schema must name the supported report schema version."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, _report = self.write_valid_bundle(root)
            write_json(
                schema_path,
                {
                    "$schema": "https://json-schema.org/draft/2020-12/schema",
                    "properties": {
                        "schema_version": {"const": "wrong"},
                        "repo": {"const": checker.REPO_FULL_NAME},
                        "profiles": {
                            "minItems": len(checker.DEFAULT_PROFILES),
                            "maxItems": len(checker.DEFAULT_PROFILES),
                        },
                        "validation": {
                            "properties": {
                                "profile_count": {
                                    "const": len(checker.DEFAULT_PROFILES)
                                }
                            }
                        },
                    },
                },
            )
            stderr = StringIO()

            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--schema",
                        str(schema_path.relative_to(root)),
                        "--report-json",
                        str(report_path.relative_to(root)),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("schema.properties.schema_version.const", stderr.getvalue())

    def test_rejects_schema_repo_drift(self) -> None:
        """The committed schema must stay pinned to the expected repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            schema_path, report_path, _report = self.write_valid_bundle(root)
            schema = valid_schema()
            schema["properties"]["repo"] = {"const": "other/repo"}
            write_json(schema_path, schema)
            stderr = StringIO()

            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--schema",
                        str(schema_path.relative_to(root)),
                        "--report-json",
                        str(report_path.relative_to(root)),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("schema.properties.repo.const", stderr.getvalue())

    def test_rejects_wrong_report_schema_version(self) -> None:
        """Report schema version must match the generator."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["schema_version"] = "wrong"

            self.assert_checker_fails(report, root, "report.schema_version")

    def test_rejects_wrong_repo(self) -> None:
        """Reports are pinned to the expected GitHub repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["repo"] = "other/repo"

            self.assert_checker_fails(report, root, "report.repo")

    def test_rejects_unblocked_readiness_claim(self) -> None:
        """Retained reports cannot claim readiness."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["readiness_claim"] = "ready"

            self.assert_checker_fails(report, root, "readiness_claim")

    def test_rejects_missing_profile_coverage(self) -> None:
        """All three live audit profiles must be present."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"] = report["profiles"][:2]
            report["validation"]["profile_count"] = 2

            self.assert_checker_fails(report, root, "must cover labels")

    def test_rejects_duplicate_profiles(self) -> None:
        """Duplicate profile rows are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][1] = dict(report["profiles"][0])

            self.assert_checker_fails(report, root, "duplicate profile")

    def test_rejects_unsafe_snapshot_path(self) -> None:
        """Snapshot paths cannot escape the repo."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["snapshot_path"] = "../outside.json"

            self.assert_checker_fails(report, root, "inside the repository")

    def test_rejects_malformed_snapshot_digest(self) -> None:
        """Snapshot digests must be lowercase sha256 hex."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["snapshot_sha256"] = "sha256:" + "0" * 64

            self.assert_checker_fails(report, root, "64-character sha256")

    def test_rejects_snapshot_digest_mismatch(self) -> None:
        """Snapshot digests must match retained snapshot files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["snapshot_sha256"] = "0" * 64

            self.assert_checker_fails(report, root, "snapshot_sha256 mismatch")

    def test_rejects_failed_checker_status(self) -> None:
        """Checker status must be passed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["checker_status"] = "failed"

            self.assert_checker_fails(report, root, "checker_status must be passed")

    def test_rejects_command_provenance_drift(self) -> None:
        """Checker commands must point at the matching live-json snapshot."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["checker_command"] = "python something_else.py"

            self.assert_checker_fails(report, root, "checker_command")

    def test_rejects_validation_count_mismatch(self) -> None:
        """Validation metadata must agree with profile rows."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["validation"]["profile_count"] = 2

            self.assert_checker_fails(report, root, "profile_count")

    def test_rejects_secret_like_key(self) -> None:
        """Secret-shaped keys fail even when nested."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["api_key"] = "do-not-commit"

            self.assert_checker_fails(report, root, "secret-like key")

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values fail."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report = valid_report(root)
            report["profiles"][0]["export_command"] += " --extra api_key=abc"

            self.assert_checker_fails(report, root, "secret-like value")


if __name__ == "__main__":
    unittest.main(verbosity=2)
