#!/usr/bin/env python3
"""Focused tests for release evidence issue-label validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_issue_labels.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_issue_labels", SCRIPT_PATH
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


def backlog_entry(entry_id: str, requirement_id: str) -> dict[str, object]:
    """Build one minimal backlog entry."""
    return {
        "entry_id": entry_id,
        "phase": "public_beta",
        "phase_label": "Public Beta",
        "requirement_id": requirement_id,
        "status": "missing",
        "title": f"Retain public beta evidence: {requirement_id}",
        "suggested_labels": ["release", "evidence", "roadmap", "public-beta"],
    }


def backlog(*entries: dict[str, object]) -> dict[str, object]:
    """Build a minimal backlog document."""
    return {
        "schema_version": checker.issue_link_checker.BACKLOG_SCHEMA,
        "entries": list(entries),
    }


def link_for(entry: dict[str, object], issue_number: int) -> dict[str, object]:
    """Build one issue-link row from a backlog entry."""
    return {
        "entry_id": entry["entry_id"],
        "phase": entry["phase"],
        "phase_label": entry["phase_label"],
        "requirement_id": entry["requirement_id"],
        "status": entry["status"],
        "title": entry["title"],
        "issue_number": issue_number,
        "issue_url": f"https://github.com/6529-Collections/6529Stream/issues/{issue_number}",
        "suggested_labels": entry["suggested_labels"],
        "applied_labels": ["release", "roadmap"],
    }


def issue_links(*links: dict[str, object]) -> dict[str, object]:
    """Build a minimal issue-links document."""
    return {
        "schema_version": checker.issue_link_checker.ISSUE_LINKS_SCHEMA,
        "source_backlog": {
            "path": "release-artifacts/latest/release-evidence-issue-backlog.json",
            "schema_version": checker.issue_link_checker.BACKLOG_SCHEMA,
        },
        "parent_issue": {
            "issue_number": 214,
            "issue_url": "https://github.com/6529-Collections/6529Stream/issues/214",
            "title": "Link release evidence backlog entries to GitHub tracker issues",
        },
        "policy": {
            "no_secrets": True,
            "tracker_only": True,
            "auto_create_issues": False,
            "completion_requires_reviewed_retained_evidence": True,
        },
        "links": list(links),
    }


def snapshot_issue(
    issue_number: int,
    title: str,
    labels: list[str],
) -> dict[str, object]:
    """Build one GitHub issue-list snapshot row."""
    return {
        "number": issue_number,
        "title": title,
        "labels": [{"name": label} for label in labels],
    }


class ReleaseEvidenceIssueLabelsTests(unittest.TestCase):
    """Checker behavior for release evidence issue labels."""

    def test_committed_issue_labels_are_current(self) -> None:
        """The committed issue links have valid deterministic label posture."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_static_labels_and_live_snapshot(self) -> None:
        """Static links and matching GitHub snapshot labels pass."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        rows = checker.expected_issue_rows(
            issue_links(link_for(entry, 215)),
            backlog(entry),
            Path.cwd(),
            Path.cwd()
            / "release-artifacts"
            / "latest"
            / "release-evidence-issue-backlog.json",
        )

        checker.validate_snapshot_labels(
            rows,
            [
                snapshot_issue(
                    215,
                    "Retain public beta evidence: external_audit_report",
                    ["release", "roadmap", "triaged"],
                )
            ],
        )

    def test_rejects_duplicate_applied_labels(self) -> None:
        """Applied labels must be unique per issue-link row."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        link = {**link_for(entry, 215), "applied_labels": ["release", "release"]}

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLabelsError,
            "duplicate labels",
        ):
            checker.expected_issue_rows(
                issue_links(link),
                backlog(entry),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_rejects_applied_label_outside_suggested_labels(self) -> None:
        """Applied labels must come from the generated suggested label set."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        link = {**link_for(entry, 215), "applied_labels": ["release", "unknown"]}

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLabelsError,
            "not in suggested_labels",
        ):
            checker.expected_issue_rows(
                issue_links(link),
                backlog(entry),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_rejects_missing_issue_in_snapshot(self) -> None:
        """Every linked issue must appear in the live/snapshot audit input."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        rows = checker.expected_issue_rows(
            issue_links(link_for(entry, 215)),
            backlog(entry),
            Path.cwd(),
            Path.cwd()
            / "release-artifacts"
            / "latest"
            / "release-evidence-issue-backlog.json",
        )

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLabelsError,
            "issue #215 is missing",
        ):
            checker.validate_snapshot_labels(rows, [])

    def test_rejects_missing_snapshot_label_with_remediation(self) -> None:
        """Snapshot audit reports missing labels with a deterministic repair command."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        rows = checker.expected_issue_rows(
            issue_links(link_for(entry, 215)),
            backlog(entry),
            Path.cwd(),
            Path.cwd()
            / "release-artifacts"
            / "latest"
            / "release-evidence-issue-backlog.json",
        )

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLabelsError,
            "gh issue edit 215 --repo 6529-Collections/6529Stream --add-label roadmap",
        ):
            checker.validate_snapshot_labels(
                rows,
                [
                    snapshot_issue(
                        215,
                        "Retain public beta evidence: external_audit_report",
                        ["release"],
                    )
                ],
            )

    def test_rejects_snapshot_title_mismatch(self) -> None:
        """Snapshot titles must still match linked tracker titles."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        rows = checker.expected_issue_rows(
            issue_links(link_for(entry, 215)),
            backlog(entry),
            Path.cwd(),
            Path.cwd()
            / "release-artifacts"
            / "latest"
            / "release-evidence-issue-backlog.json",
        )

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLabelsError,
            "title mismatch",
        ):
            checker.validate_snapshot_labels(
                rows,
                [snapshot_issue(215, "Wrong title", ["release", "roadmap"])],
            )

    def test_main_accepts_snapshot_file(self) -> None:
        """CLI mode accepts an explicit live JSON snapshot path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / checker.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / checker.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))
            snapshot_path = root / "issue-labels.json"
            write_json(
                snapshot_path,
                [
                    snapshot_issue(
                        215,
                        "Retain public beta evidence: external_audit_report",
                        ["release", "roadmap"],
                    )
                ],
            )

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
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / checker.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / checker.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))
            snapshot_path = root / "issue-labels.json"
            write_json(
                snapshot_path,
                [
                    snapshot_issue(
                        215,
                        "Retain public beta evidence: external_audit_report",
                        ["release"],
                    )
                ],
            )

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
            self.assertIn("missing applied labels", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
