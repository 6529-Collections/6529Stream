#!/usr/bin/env python3
"""Focused tests for release evidence issue snapshot live audits."""

from __future__ import annotations

import importlib.util
import hashlib
import json
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).with_name("audit_release_evidence_issue_snapshots.py")
SPEC = importlib.util.spec_from_file_location(
    "audit_release_evidence_issue_snapshots", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
auditor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(auditor)


def completed(returncode: int = 0) -> subprocess.CompletedProcess:
    """Build a CompletedProcess for subprocess.run mocks."""
    return subprocess.CompletedProcess(args=["python"], returncode=returncode)


def script_name(command: list[str]) -> str:
    """Return the script basename from an orchestrated command."""
    return Path(command[1]).name


def snapshot_text(profile: str) -> str:
    """Return deterministic snapshot content for report tests."""
    return json.dumps([{"profile": profile}], sort_keys=True) + "\n"


def snapshot_digest(profile: str) -> str:
    """Return the digest expected for the deterministic snapshot content."""
    return hashlib.sha256(snapshot_text(profile).encode("utf-8")).hexdigest()


def write_snapshot_for_export_command(command: list[str]) -> None:
    """Write the snapshot requested by a mocked exporter command."""
    profile = command[command.index("--profile") + 1]
    output = Path(command[command.index("--output") + 1])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(snapshot_text(profile), encoding="utf-8", newline="\n")


def run_success_and_write_snapshots(
    command: list[str], check: bool = False
) -> subprocess.CompletedProcess:
    """Mock subprocess.run while materializing exporter snapshots."""
    del check
    if script_name(command) == "export_release_evidence_issue_snapshot.py":
        write_snapshot_for_export_command(command)
    return completed()


class ReleaseEvidenceIssueSnapshotAuditTests(unittest.TestCase):
    """Orchestrator behavior for live issue snapshot audits."""

    def test_invalid_limit_keeps_argparse_error_text(self) -> None:
        """Invalid limits keep the shared positive-int argparse error."""
        stderr = StringIO()
        with self.assertRaises(SystemExit) as raised:
            with redirect_stderr(stderr), redirect_stdout(StringIO()):
                auditor.main(["--limit", "0"])

        self.assertEqual(raised.exception.code, 2)
        self.assertIn("must be a positive integer", stderr.getvalue())

    def test_default_profiles_run_export_then_check_in_order(self) -> None:
        """Default mode audits labels, bodies, and closure in order."""
        with patch.object(auditor.subprocess, "run", return_value=completed()) as run:
            stdout = StringIO()
            with redirect_stdout(stdout), redirect_stderr(StringIO()):
                result = auditor.main(["--python", "python", "--gh", "gh"])

        self.assertEqual(result, 0)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(
            [script_name(command) for command in commands],
            [
                "export_release_evidence_issue_snapshot.py",
                "check_release_evidence_issue_labels.py",
                "export_release_evidence_issue_snapshot.py",
                "check_release_evidence_issue_bodies.py",
                "export_release_evidence_issue_snapshot.py",
                "check_release_evidence_issue_closure.py",
            ],
        )
        self.assertIn("labels live audit passed", stdout.getvalue())
        self.assertIn("bodies live audit passed", stdout.getvalue())
        self.assertIn("closure live audit passed", stdout.getvalue())

    def test_single_profile_uses_expected_snapshot_path(self) -> None:
        """A selected profile exports to and checks its deterministic path."""
        with patch.object(auditor.subprocess, "run", return_value=completed()) as run:
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = auditor.main(
                    [
                        "--profile",
                        "bodies",
                        "--python",
                        "python",
                        "--tmp-dir",
                        "tmp/live",
                    ]
                )

        self.assertEqual(result, 0)
        commands = [call.args[0] for call in run.call_args_list]
        self.assertEqual(len(commands), 2)
        self.assertIn("--output", commands[0])
        self.assertIn("tmp/live/release-evidence-issue-bodies.json", commands[0])
        self.assertIn("--exact-linked-issues", commands[0])
        self.assertIn("--issue-links", commands[0])
        self.assertIn("--live-json", commands[1])
        self.assertIn("tmp/live/release-evidence-issue-bodies.json", commands[1])

    def test_all_profile_deduplicates_explicit_profiles(self) -> None:
        """The all profile expands once even when profiles are repeated."""
        self.assertEqual(
            auditor.expand_profiles(["labels", "all", "labels", "closure"]),
            ["labels", "bodies", "closure"],
        )

    def test_export_failure_stops_before_checker(self) -> None:
        """Exporter failures stop the audit before running a checker."""
        with patch.object(auditor.subprocess, "run", return_value=completed(1)) as run:
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = auditor.main(["--profile", "labels", "--python", "python"])

        self.assertEqual(result, 1)
        self.assertEqual(run.call_count, 1)
        self.assertIn("labels snapshot export failed", stderr.getvalue())

    def test_checker_failure_stops_remaining_profiles(self) -> None:
        """Checker failures are reported and later profiles do not run."""
        calls = [completed(0), completed(1), completed(0)]
        with patch.object(auditor.subprocess, "run", side_effect=calls) as run:
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = auditor.main(["--python", "python"])

        self.assertEqual(result, 1)
        self.assertEqual(run.call_count, 2)
        self.assertIn("labels snapshot check failed", stderr.getvalue())

    def test_repo_gh_and_issue_links_are_passed_to_exporter_only(self) -> None:
        """The orchestrator passes live GitHub options through to the exporter."""
        with patch.object(auditor.subprocess, "run", return_value=completed()) as run:
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = auditor.main(
                    [
                        "--profile",
                        "closure",
                        "--python",
                        "python",
                        "--repo",
                        "owner/repo",
                        "--limit",
                        "17",
                        "--gh",
                        "custom-gh",
                        "--issue-links",
                        "custom/links.json",
                    ]
                )

        self.assertEqual(result, 0)
        export_command = run.call_args_list[0].args[0]
        check_command = run.call_args_list[1].args[0]
        self.assertIn("owner/repo", export_command)
        self.assertIn("custom-gh", export_command)
        self.assertIn("custom/links.json", export_command)
        self.assertNotIn("17", export_command)
        self.assertNotIn("custom-gh", check_command)
        self.assertNotIn("custom/links.json", check_command)

    def test_report_json_and_markdown_are_deterministic(self) -> None:
        """Report mode writes deterministic no-secret JSON and Markdown."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_json = root / "reports" / "live-audit.json"
            report_md = root / "reports" / "live-audit.md"

            with patch.object(
                auditor.subprocess,
                "run",
                side_effect=run_success_and_write_snapshots,
            ):
                with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                    result = auditor.main(
                        [
                            "--python",
                            "python",
                            "--gh",
                            "gh",
                            "--tmp-dir",
                            str(root / "snapshots"),
                            "--report-json",
                            str(report_json),
                            "--report-md",
                            str(report_md),
                            "--generated-at",
                            "2026-06-13T20:00:00Z",
                        ]
                    )

            self.assertEqual(result, 0)
            report_text = report_json.read_text(encoding="utf-8")
            report = json.loads(report_text)
            self.assertEqual(
                report_text,
                json.dumps(report, indent=2, ensure_ascii=False) + "\n",
            )
            self.assertEqual(
                [profile["profile"] for profile in report["profiles"]],
                ["labels", "bodies", "closure"],
            )
            self.assertEqual(report["schema_version"], auditor.REPORT_SCHEMA_VERSION)
            self.assertEqual(report["repo"], auditor.REPO_FULL_NAME)
            self.assertEqual(report["generated_at"], "2026-06-13T20:00:00Z")
            self.assertEqual(report["readiness_claim"], "blocked")
            self.assertEqual(
                report["snapshot_freshness"]["status"],
                auditor.LIVE_EXPORT_FRESHNESS_STATUS,
            )
            self.assertEqual(
                report["snapshot_freshness"]["generated_from_live_export"],
                True,
            )
            self.assertEqual(
                report["snapshot_freshness"]["currentness_claim"],
                auditor.LIVE_EXPORT_CURRENTNESS_CLAIM,
            )
            self.assertEqual(
                report["snapshot_freshness"]["stale_snapshot_policy"],
                auditor.STALE_SNAPSHOT_POLICY,
            )
            self.assertEqual(
                report["snapshot_freshness"]["profile_generated_at"],
                {
                    "labels": "2026-06-13T20:00:00Z",
                    "bodies": "2026-06-13T20:00:00Z",
                    "closure": "2026-06-13T20:00:00Z",
                },
            )
            self.assertEqual(report["validation"]["status"], "passed")
            self.assertEqual(report["validation"]["profile_count"], 3)
            self.assertEqual(
                report["profiles"][0]["snapshot_sha256"],
                snapshot_digest("labels"),
            )
            markdown = report_md.read_text(encoding="utf-8")
            self.assertIn("# Release Evidence Live Audit Report", markdown)
            self.assertIn(auditor.LIVE_EXPORT_CURRENTNESS_CLAIM, markdown)
            self.assertIn(auditor.STALE_SNAPSHOT_POLICY, markdown)
            self.assertIn(auditor.NO_SECRET_NOTICE, markdown)
            self.assertIn(auditor.READINESS_WARNING, markdown)
            self.assertIn(snapshot_digest("closure"), markdown)

    def test_report_profile_selection_preserves_deduplicated_order(self) -> None:
        """Report mode records the selected profile order after all expansion."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            report_json = root / "report.json"

            with patch.object(
                auditor.subprocess,
                "run",
                side_effect=run_success_and_write_snapshots,
            ):
                with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                    result = auditor.main(
                        [
                            "--profile",
                            "labels",
                            "--profile",
                            "all",
                            "--python",
                            "python",
                            "--tmp-dir",
                            str(root / "snapshots"),
                            "--report-json",
                            str(report_json),
                        ]
                    )

            self.assertEqual(result, 0)
            report = json.loads(report_json.read_text(encoding="utf-8"))
            self.assertEqual(
                [profile["profile"] for profile in report["profiles"]],
                ["labels", "bodies", "closure"],
            )
            self.assertEqual(report["generated_at"], "TBD")
            self.assertEqual(
                report["snapshot_freshness"]["profile_generated_at"],
                {"labels": "TBD", "bodies": "TBD", "closure": "TBD"},
            )

    def test_missing_report_snapshot_fails_with_context(self) -> None:
        """Report mode fails if the mocked exporter does not leave a snapshot."""
        with tempfile.TemporaryDirectory() as temp_dir:
            report_json = Path(temp_dir) / "report.json"
            stderr = StringIO()

            with patch.object(auditor.subprocess, "run", return_value=completed()):
                with redirect_stdout(StringIO()), redirect_stderr(stderr):
                    result = auditor.main(
                        [
                            "--profile",
                            "labels",
                            "--python",
                            "python",
                            "--tmp-dir",
                            str(Path(temp_dir) / "snapshots"),
                            "--report-json",
                            str(report_json),
                        ]
                    )

            self.assertEqual(result, 1)
            self.assertFalse(report_json.exists())
            self.assertIn("snapshot output is missing", stderr.getvalue())

    def test_checker_failure_does_not_write_report(self) -> None:
        """Failed checks stop before retained report files are written."""
        with tempfile.TemporaryDirectory() as temp_dir:
            report_json = Path(temp_dir) / "report.json"
            calls = [completed(0), completed(1)]

            with patch.object(auditor.subprocess, "run", side_effect=calls):
                with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                    result = auditor.main(
                        [
                            "--profile",
                            "labels",
                            "--python",
                            "python",
                            "--tmp-dir",
                            str(Path(temp_dir) / "snapshots"),
                            "--report-json",
                            str(report_json),
                        ]
                    )

            self.assertEqual(result, 1)
            self.assertFalse(report_json.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
