#!/usr/bin/env python3
"""Focused tests for release evidence issue-link validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_evidence_issue_links.py")
SPEC = importlib.util.spec_from_file_location(
    "check_release_evidence_issue_links", SCRIPT_PATH
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
        "schema_version": checker.BACKLOG_SCHEMA,
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
        "schema_version": checker.ISSUE_LINKS_SCHEMA,
        "source_backlog": {
            "path": "release-artifacts/latest/release-evidence-issue-backlog.json",
            "schema_version": checker.BACKLOG_SCHEMA,
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


class ReleaseEvidenceIssueLinksTests(unittest.TestCase):
    """Checker behavior for release evidence issue links."""

    def test_committed_issue_links_are_current(self) -> None:
        """The committed issue-link mapping matches the committed backlog."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_complete_mapping(self) -> None:
        """A complete one-to-one mapping passes."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        checker.validate_links_document(
            issue_links(link_for(entry, 215)),
            backlog(entry),
            Path.cwd(),
            Path.cwd()
            / "release-artifacts"
            / "latest"
            / "release-evidence-issue-backlog.json",
        )

    def test_rejects_missing_backlog_entry_link(self) -> None:
        """Every backlog entry must have a tracker issue."""
        first = backlog_entry("public-beta-audit", "external_audit_report")
        second = backlog_entry("public-beta-fork", "fork_deployment_rehearsal")

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLinksError,
            "missing issue links",
        ):
            checker.validate_links_document(
                issue_links(link_for(first, 215)),
                backlog(first, second),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_rejects_stale_issue_link_entry_id(self) -> None:
        """Mappings cannot point at entries absent from the generated backlog."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        stale = {**link_for(entry, 215), "entry_id": "stale-entry"}

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLinksError,
            "stale issue link",
        ):
            checker.validate_links_document(
                issue_links(stale),
                backlog(entry),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_rejects_issue_url_number_mismatch(self) -> None:
        """Issue URLs must match issue_number exactly."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        bad_link = {
            **link_for(entry, 215),
            "issue_url": "https://github.com/6529-Collections/6529Stream/issues/999",
        }

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLinksError,
            "does not match issue_number",
        ):
            checker.validate_links_document(
                issue_links(bad_link),
                backlog(entry),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_rejects_duplicate_issue_numbers(self) -> None:
        """One GitHub issue cannot satisfy multiple backlog entries."""
        first = backlog_entry("public-beta-audit", "external_audit_report")
        second = backlog_entry("public-beta-fork", "fork_deployment_rehearsal")

        with self.assertRaisesRegex(
            checker.ReleaseEvidenceIssueLinksError,
            "duplicate issue number",
        ):
            checker.validate_links_document(
                issue_links(link_for(first, 215), link_for(second, 215)),
                backlog(first, second),
                Path.cwd(),
                Path.cwd()
                / "release-artifacts"
                / "latest"
                / "release-evidence-issue-backlog.json",
            )

    def test_main_reports_invalid_mapping(self) -> None:
        """CLI mode reports validation failures without a traceback."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / checker.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / checker.DEFAULT_ISSUE_LINKS, issue_links())

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 1)
            self.assertIn("release evidence issue links check failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
