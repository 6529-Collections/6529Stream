#!/usr/bin/env python3
"""Focused tests for release evidence issue-body validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_issue_bodies.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_issue_bodies",
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


def expected_body(entry_id: str = "public-beta-audit", issue_number: int = 215) -> str:
    """Return a minimal expected issue body with the sync marker."""
    return (
        f"<!-- {checker.body_sync_generator.BODY_SYNC_SCHEMA} "
        f"entry_id={entry_id} issue_number={issue_number} -->\n\n"
        "Parent tracker: https://github.com/6529-Collections/6529Stream/issues/214\n"
        "Source backlog entry: `release-artifacts/latest/release-evidence-issue-backlog.json` "
        f"/ `{entry_id}`\n"
        "Issue-link artifact: `release-artifacts/latest/release-evidence-issue-links.json`\n"
        "Completion policy: reviewed retained evidence must be referenced before close.\n\n"
        "## Evidence Requirement\n\n"
        "- Phase: `Public Beta`\n"
        "- Requirement ID: `external_audit_report`\n\n"
        "## Source Links\n\n"
        "- Blocker report: `release-artifacts/latest/public-beta-blockers.md`\n\n"
        "## Required Evidence\n\n"
        "- Reviewed retained evidence referenced by the evidence manifest.\n\n"
        "## Validation\n\n"
        "- `python scripts/check_public_beta_evidence.py`\n\n"
        "## Non-Goals\n\n"
        "- Do not change readiness claims from template-only evidence.\n\n"
        "## Acceptance Criteria\n\n"
        "- Reviewed retained evidence exists and is no-secret or properly redacted.\n"
    )


def body_sync_document(
    body: str | None = None,
    title: str = "Retain public beta evidence: external_audit_report",
) -> dict[str, object]:
    """Build a minimal valid body-sync document."""
    issue_body = checker.canonical_issue_body(body or expected_body())
    return {
        "schema_version": checker.body_sync_generator.BODY_SYNC_SCHEMA,
        "policy": {
            "no_secrets": True,
            "tracker_only": True,
            "auto_update_issues": False,
            "completion_requires_reviewed_retained_evidence": True,
        },
        "issues": [
            {
                "entry_id": "public-beta-audit",
                "issue_number": 215,
                "title": title,
                "body_sha256": checker.body_sync_generator.sha256_text(issue_body),
                "expected_body": issue_body,
            }
        ],
    }


def snapshot_issue(
    body: str,
    title: str = "Retain public beta evidence: external_audit_report",
    issue_number: int = 215,
) -> dict[str, object]:
    """Build one GitHub issue-list snapshot row."""
    return {
        "number": issue_number,
        "title": title,
        "body": body,
        "state": "open",
    }


class ReleaseEvidenceIssueBodiesTests(unittest.TestCase):
    """Checker behavior for release evidence issue bodies."""

    def test_committed_issue_bodies_are_current(self) -> None:
        """The committed body-sync artifact has valid deterministic bodies."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_static_bodies_and_live_snapshot(self) -> None:
        """Static expected bodies and a matching GitHub snapshot pass."""
        rows = checker.expected_issue_rows(body_sync_document())

        checker.validate_snapshot_bodies(rows, [snapshot_issue(expected_body())])

    def test_accepts_snapshot_wrapper_and_normalizes_newlines(self) -> None:
        """GitHub snapshots may be wrapped and use platform newline conventions."""
        rows = checker.expected_issue_rows(body_sync_document())
        crlf_body = expected_body().replace("\n", "\r\n").rstrip()

        checker.validate_snapshot_bodies(
            rows,
            {"issues": [snapshot_issue(crlf_body)]},
        )

    def test_accepts_fetcher_live_snapshot_shape(self) -> None:
        """The authenticated live snapshot helper shape is checker-compatible."""
        rows = checker.expected_issue_rows(body_sync_document())
        issue = snapshot_issue(expected_body())
        issue.update(
            {
                "state": "OPEN",
                "url": "https://github.com/6529-Collections/6529Stream/issues/215",
                "closed": False,
                "closedAt": None,
            }
        )

        checker.validate_snapshot_bodies(
            rows,
            {
                "schema_version": "6529stream.release-evidence-live-issue-snapshot.v1",
                "issues": [issue],
            },
        )

    def test_rejects_missing_issue_in_snapshot(self) -> None:
        """Every generated tracker issue must appear in the audit snapshot."""
        rows = checker.expected_issue_rows(body_sync_document())

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueBodiesError,
            "issue #215 is missing",
        ):
            checker.validate_snapshot_bodies(rows, [])

    def test_rejects_snapshot_title_mismatch(self) -> None:
        """Snapshot titles must still match generated tracker titles."""
        rows = checker.expected_issue_rows(body_sync_document())

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueBodiesError,
            "title mismatch",
        ):
            checker.validate_snapshot_bodies(
                rows,
                [snapshot_issue(expected_body(), title="Wrong title")],
            )

    def test_rejects_snapshot_body_drift_with_remediation(self) -> None:
        """Body drift reports the issue number and deterministic repair command."""
        rows = checker.expected_issue_rows(body_sync_document())

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueBodiesError,
            "gh issue edit 215 --repo 6529-Collections/6529Stream --body-file",
        ):
            checker.validate_snapshot_bodies(rows, [snapshot_issue("Drifted body\n")])

    def test_rejects_malformed_snapshot_body(self) -> None:
        """Malformed snapshots fail without assuming missing bodies are empty."""
        rows = checker.expected_issue_rows(body_sync_document())
        malformed = {"number": 215, "title": rows[0]["title"], "state": "open"}

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueBodiesError,
            "issue #215.body",
        ):
            checker.validate_snapshot_bodies(rows, [malformed])

    def test_writes_body_files_for_operator_remediation(self) -> None:
        """The checker can write deterministic body files for GitHub CLI repair."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / checker.DEFAULT_BODY_SYNC, body_sync_document())
            output_dir = root / "tmp" / "release-evidence-issue-bodies"

            stdout = StringIO()
            with redirect_stdout(stdout):
                checker.validate_files(
                    root,
                    root / checker.DEFAULT_BODY_SYNC,
                    body_files_dir=output_dir,
                )

            self.assertIn("wrote release evidence issue body files", stdout.getvalue())
            self.assertEqual(
                (output_dir / "issue-215.md").read_text(encoding="utf-8"),
                expected_body(),
            )

    def test_main_accepts_snapshot_file(self) -> None:
        """CLI mode accepts an explicit live JSON snapshot path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / checker.DEFAULT_BODY_SYNC, body_sync_document())
            snapshot_path = root / "issue-bodies.json"
            write_json(snapshot_path, [snapshot_issue(expected_body())])

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_main_accepts_utf8_bom_snapshot_file(self) -> None:
        """Windows-exported JSON snapshots with a UTF-8 BOM are accepted."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / checker.DEFAULT_BODY_SYNC, body_sync_document())
            snapshot_path = root / "issue-bodies.json"
            snapshot_text = json.dumps([snapshot_issue(expected_body())], indent=2) + "\n"
            snapshot_path.write_text("\ufeff" + snapshot_text, encoding="utf-8")

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_main_reports_snapshot_drift(self) -> None:
        """CLI mode reports live/snapshot audit failures without a traceback."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / checker.DEFAULT_BODY_SYNC, body_sync_document())
            snapshot_path = root / "issue-bodies.json"
            write_json(snapshot_path, [snapshot_issue("Drifted body\n")])

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--live-json",
                        str(snapshot_path),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("body drift", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
