#!/usr/bin/env python3
"""Focused tests for release evidence issue snapshot exports."""

from __future__ import annotations

import importlib.util
import json
import subprocess
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).with_name("export_release_evidence_issue_snapshot.py")
SPEC = importlib.util.spec_from_file_location(
    "export_release_evidence_issue_snapshot", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
exporter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(exporter)


def completed(stdout: object, returncode: int = 0, stderr: str = "") -> subprocess.CompletedProcess:
    """Build a CompletedProcess for subprocess.run mocks."""
    return subprocess.CompletedProcess(
        args=["gh"],
        returncode=returncode,
        stdout=json.dumps(stdout),
        stderr=stderr,
    )


class ReleaseEvidenceIssueSnapshotTests(unittest.TestCase):
    """Exporter behavior for live issue snapshots."""

    def test_profile_args_match_label_audit_fields(self) -> None:
        """The labels profile exports the checker-compatible fields."""
        self.assertEqual(
            exporter.gh_issue_list_args(
                "owner/repo",
                "open",
                100,
                exporter.PROFILE_FIELDS["labels"],
            ),
            [
                "issue",
                "list",
                "--repo",
                "owner/repo",
                "--state",
                "open",
                "--limit",
                "100",
                "--json",
                "number,title,labels",
            ],
        )

    def test_profile_defaults_cover_existing_live_audits(self) -> None:
        """Each profile matches one existing optional live audit shape."""
        self.assertEqual(exporter.PROFILE_FIELDS["bodies"], ("number", "title", "body"))
        self.assertEqual(exporter.PROFILE_STATES["bodies"], "open")
        self.assertEqual(exporter.PROFILE_FIELDS["closure"], ("number", "title", "state"))
        self.assertEqual(exporter.PROFILE_STATES["closure"], "all")
        self.assertEqual(
            exporter.PROFILE_FIELDS["all"],
            ("number", "title", "state", "labels", "body"),
        )

    def test_run_gh_issue_list_returns_rows(self) -> None:
        """The exporter parses gh issue list JSON arrays."""
        rows = [{"number": 215, "title": "Retain public beta evidence", "labels": []}]
        with patch.object(exporter.subprocess, "run", return_value=completed(rows)) as run:
            result = exporter.run_gh_issue_list(
                "gh",
                exporter.REPO_FULL_NAME,
                "open",
                100,
                exporter.PROFILE_FIELDS["labels"],
            )

        self.assertEqual(result, rows)
        run.assert_called_once()
        self.assertIn("issue", run.call_args.args[0])

    def test_resolves_windows_command_shims(self) -> None:
        """Windows gh.cmd shims are run through cmd.exe without shell=True."""
        with patch.object(exporter.shutil, "which", return_value="C:/tools/gh.cmd"):
            self.assertEqual(
                exporter.resolve_gh_command("gh"),
                ["cmd.exe", "/c", "C:/tools/gh.cmd"],
            )

    def test_rejects_gh_failure(self) -> None:
        """GitHub CLI failures are reported without traceback."""
        with patch.object(
            exporter.subprocess,
            "run",
            return_value=completed([], returncode=1, stderr="auth required"),
        ):
            with self.assertRaisesRegex(
                exporter.ReleaseEvidenceIssueSnapshotError,
                "auth required",
            ):
                exporter.run_gh_issue_list(
                    "gh",
                    exporter.REPO_FULL_NAME,
                    "open",
                    100,
                    exporter.PROFILE_FIELDS["labels"],
                )

    def test_rejects_invalid_json(self) -> None:
        """Invalid gh JSON is rejected."""
        result = subprocess.CompletedProcess(
            args=["gh"],
            returncode=0,
            stdout="{",
            stderr="",
        )
        with patch.object(exporter.subprocess, "run", return_value=result):
            with self.assertRaisesRegex(
                exporter.ReleaseEvidenceIssueSnapshotError,
                "invalid JSON",
            ):
                exporter.run_gh_issue_list(
                    "gh",
                    exporter.REPO_FULL_NAME,
                    "open",
                    100,
                    exporter.PROFILE_FIELDS["labels"],
                )

    def test_rejects_non_array_json(self) -> None:
        """The checker snapshots expect GitHub issue-list arrays."""
        with self.assertRaisesRegex(
            exporter.ReleaseEvidenceIssueSnapshotError,
            "JSON array",
        ):
            exporter.require_issue_list({"issues": []})

    def test_write_snapshot_uses_utf8_without_bom(self) -> None:
        """Snapshot files are strict UTF-8 JSON without a BOM."""
        rows = [{"number": 215, "title": "Public beta cafe", "labels": []}]
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "snapshot.json"

            exporter.write_snapshot(output, rows)

            raw = output.read_bytes()
            self.assertFalse(raw.startswith(b"\xef\xbb\xbf"))
            self.assertEqual(json.loads(raw.decode("utf-8")), rows)

    def test_main_writes_profile_output(self) -> None:
        """CLI mode writes the requested profile snapshot file."""
        rows = [{"number": 215, "title": "Retain public beta evidence", "labels": []}]
        with tempfile.TemporaryDirectory() as temp_dir:
            output = Path(temp_dir) / "labels.json"
            with patch.object(exporter.subprocess, "run", return_value=completed(rows)):
                stdout = StringIO()
                with redirect_stdout(stdout), redirect_stderr(StringIO()):
                    result = exporter.main(
                        [
                            "--profile",
                            "labels",
                            "--output",
                            str(output),
                        ]
                    )

            self.assertEqual(result, 0)
            self.assertIn(output.as_posix(), stdout.getvalue())
            self.assertEqual(json.loads(output.read_text(encoding="utf-8")), rows)

    def test_main_reports_errors(self) -> None:
        """CLI mode reports failures without a traceback."""
        with patch.object(
            exporter.subprocess,
            "run",
            return_value=completed([], returncode=1, stderr="not logged in"),
        ):
            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = exporter.main(["--stdout"])

        self.assertEqual(result, 1)
        self.assertIn("not logged in", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
