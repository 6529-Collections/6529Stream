#!/usr/bin/env python3
"""Focused tests for release evidence issue snapshot live audits."""

from __future__ import annotations

import importlib.util
import subprocess
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


class ReleaseEvidenceIssueSnapshotAuditTests(unittest.TestCase):
    """Orchestrator behavior for live issue snapshot audits."""

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

    def test_repo_limit_and_gh_are_passed_to_exporter_only(self) -> None:
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
                    ]
                )

        self.assertEqual(result, 0)
        export_command = run.call_args_list[0].args[0]
        check_command = run.call_args_list[1].args[0]
        self.assertIn("owner/repo", export_command)
        self.assertIn("17", export_command)
        self.assertIn("custom-gh", export_command)
        self.assertNotIn("custom-gh", check_command)


if __name__ == "__main__":
    unittest.main(verbosity=2)
