#!/usr/bin/env python3
"""Focused tests for release evidence issue-closure validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_issue_closure.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_issue_closure",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def expected_row(
    *,
    status: str = "missing",
    closure_allowed: bool = False,
    issue_number: int = 215,
) -> dict[str, object]:
    """Return one expected closure-policy row."""
    return {
        "entry_id": "public-beta-external-audit-report",
        "phase": "public_beta",
        "requirement_id": "external_audit_report",
        "issue_number": issue_number,
        "title": "Retain public beta evidence: external_audit_report",
        "status": status,
        "closure_allowed": closure_allowed,
    }


def snapshot_issue(
    *,
    state: str = "open",
    title: str = "Retain public beta evidence: external_audit_report",
    issue_number: int = 215,
) -> dict[str, object]:
    """Return one GitHub issue-list snapshot row."""
    return {
        "number": issue_number,
        "title": title,
        "state": state,
    }


class ReleaseEvidenceIssueClosureTests(unittest.TestCase):
    """Checker behavior for release evidence tracker closure state."""

    def test_committed_issue_closure_policy_is_current(self) -> None:
        """The committed artifacts agree on tracker closure readiness."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_open_blocking_snapshot(self) -> None:
        """Open tracker issues are valid while evidence is still missing."""
        checker.validate_snapshot_closure(
            [expected_row()],
            [snapshot_issue(state="OPEN")],
        )

    def test_accepts_snapshot_wrapper(self) -> None:
        """Snapshots may be wrapped as an object with an issues array."""
        checker.validate_snapshot_closure(
            [expected_row()],
            {"issues": [snapshot_issue(state="opened")]},
        )

    def test_accepts_closed_complete_tracker(self) -> None:
        """Completed evidence rows may have closed tracker issues."""
        checker.validate_snapshot_closure(
            [expected_row(status="complete", closure_allowed=True)],
            [snapshot_issue(state="closed")],
        )

    def test_accepts_closed_accepted_risk_tracker(self) -> None:
        """Risk-accepted evidence rows may have closed tracker issues."""
        checker.validate_snapshot_closure(
            [expected_row(status="accepted_risk", closure_allowed=True)],
            [snapshot_issue(state="CLOSED")],
        )

    def test_rejects_closed_missing_tracker_with_remediation(self) -> None:
        """Missing evidence rows must remain open in the live tracker."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueClosureError,
            "gh issue reopen 215 --repo 6529-Collections/6529Stream",
        ):
            checker.validate_snapshot_closure(
                [expected_row()],
                [snapshot_issue(state="closed")],
            )

    def test_rejects_missing_issue_in_snapshot(self) -> None:
        """Every linked tracker issue must appear in the live audit snapshot."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueClosureError,
            "issue #215 is missing",
        ):
            checker.validate_snapshot_closure([expected_row()], [])

    def test_rejects_snapshot_title_mismatch(self) -> None:
        """Live issue titles must still match committed tracker metadata."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueClosureError,
            "title mismatch",
        ):
            checker.validate_snapshot_closure(
                [expected_row()],
                [snapshot_issue(title="Wrong title")],
            )

    def test_rejects_unknown_snapshot_state(self) -> None:
        """Malformed issue states fail instead of being treated as open."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueClosureError,
            "issue #215.state must be one of",
        ):
            checker.validate_snapshot_closure(
                [expected_row()],
                [snapshot_issue(state="merged")],
            )

    def test_rejects_duplicate_snapshot_issue(self) -> None:
        """Duplicate issue numbers make a snapshot ambiguous."""
        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueClosureError,
            "duplicate issue in snapshot",
        ):
            checker.validate_snapshot_closure(
                [expected_row()],
                [snapshot_issue(), snapshot_issue()],
            )

    def test_main_accepts_snapshot_file(self) -> None:
        """CLI mode accepts an explicit live JSON snapshot path."""
        repo_root = Path(__file__).resolve().parents[1]
        rows = checker.load_expected_issue_rows(
            repo_root,
            repo_root / checker.DEFAULT_ISSUE_LINKS,
            repo_root / checker.DEFAULT_BACKLOG,
            repo_root / checker.DEFAULT_BODY_SYNC,
            repo_root / checker.DEFAULT_PACKET_INDEX,
            repo_root / checker.DEFAULT_EVIDENCE,
        )
        snapshot = [
            {
                "number": row["issue_number"],
                "title": row["title"],
                "state": "open",
            }
            for row in rows
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            snapshot_path = Path(temp_dir) / "issue-closure.json"
            write_json(snapshot_path, snapshot)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(repo_root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

        self.assertEqual(result, 0)

    def test_main_accepts_utf8_bom_snapshot_file(self) -> None:
        """Windows-exported JSON snapshots with a UTF-8 BOM are accepted."""
        repo_root = Path(__file__).resolve().parents[1]
        rows = checker.load_expected_issue_rows(
            repo_root,
            repo_root / checker.DEFAULT_ISSUE_LINKS,
            repo_root / checker.DEFAULT_BACKLOG,
            repo_root / checker.DEFAULT_BODY_SYNC,
            repo_root / checker.DEFAULT_PACKET_INDEX,
            repo_root / checker.DEFAULT_EVIDENCE,
        )
        snapshot = [
            {
                "number": row["issue_number"],
                "title": row["title"],
                "state": "open",
            }
            for row in rows
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            snapshot_path = Path(temp_dir) / "issue-closure.json"
            snapshot_text = json.dumps(snapshot, indent=2) + "\n"
            snapshot_path.write_text("\ufeff" + snapshot_text, encoding="utf-8")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(repo_root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

        self.assertEqual(result, 0)

    def test_main_reports_closed_blocking_snapshot(self) -> None:
        """CLI mode reports premature live/snapshot closure without a traceback."""
        repo_root = Path(__file__).resolve().parents[1]
        rows = checker.load_expected_issue_rows(
            repo_root,
            repo_root / checker.DEFAULT_ISSUE_LINKS,
            repo_root / checker.DEFAULT_BACKLOG,
            repo_root / checker.DEFAULT_BODY_SYNC,
            repo_root / checker.DEFAULT_PACKET_INDEX,
            repo_root / checker.DEFAULT_EVIDENCE,
        )
        snapshot = [
            {
                "number": row["issue_number"],
                "title": row["title"],
                "state": "closed" if index == 0 else "open",
            }
            for index, row in enumerate(rows)
        ]

        with tempfile.TemporaryDirectory() as temp_dir:
            snapshot_path = Path(temp_dir) / "issue-closure.json"
            write_json(snapshot_path, snapshot)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(repo_root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

        self.assertEqual(result, 1)
        self.assertIn("closed while committed evidence status", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
