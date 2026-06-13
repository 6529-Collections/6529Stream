#!/usr/bin/env python3
"""Focused tests for release evidence issue body sync generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_evidence_issue_body_sync.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_release_evidence_issue_body_sync",
    SCRIPT_PATH,
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def valid_issue_body() -> str:
    """Return the minimal issue-ready body accepted by the generator."""
    return """## Evidence Requirement

- Phase: `Public Beta`
- Requirement ID: `external_audit_report`
- Current status: `missing`

## Source Links

- Blocker report: `release-artifacts/latest/public-beta-blockers.md`

## Required Evidence

- Reviewed retained evidence must be referenced by the evidence manifest.

## Validation

- `python scripts/check_public_beta_evidence.py`

## Non-Goals

- Do not commit private keys, RPC URLs, API keys, or unreleased drop payloads.

## Acceptance Criteria

- Reviewed retained evidence exists and is no-secret or properly redacted.
"""


def backlog_entry(entry_id: str, requirement_id: str) -> dict[str, object]:
    """Build one minimal backlog entry with an issue body."""
    return {
        "entry_id": entry_id,
        "phase": "public_beta",
        "phase_label": "Public Beta",
        "requirement_id": requirement_id,
        "status": "missing",
        "evidence_posture": "external/future",
        "title": f"Retain public beta evidence: {requirement_id}",
        "suggested_labels": ["release", "evidence", "roadmap", "public-beta"],
        "issue_body": valid_issue_body(),
    }


def backlog(*entries: dict[str, object]) -> dict[str, object]:
    """Build a minimal backlog document."""
    return {
        "schema_version": generator.issue_link_checker.BACKLOG_SCHEMA,
        "status_summary": [
            {
                "phase": "public_beta",
                "label": "Public Beta",
                "entry_count": len(entries),
                "counts": {"missing": len(entries)},
            }
        ],
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
        "schema_version": generator.issue_link_checker.ISSUE_LINKS_SCHEMA,
        "source_backlog": {
            "path": "release-artifacts/latest/release-evidence-issue-backlog.json",
            "schema_version": generator.issue_link_checker.BACKLOG_SCHEMA,
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


def build_body_sync_from_memory(
    backlog_document: dict[str, object],
    issue_links_document: dict[str, object],
) -> dict[str, object]:
    """Build a body-sync document from in-memory fixtures."""
    with tempfile.TemporaryDirectory() as temp_dir:
        root = Path(temp_dir)
        write_json(root / generator.DEFAULT_BACKLOG, backlog_document)
        write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links_document)
        return generator.build_body_sync(
            root,
            generator.DEFAULT_BACKLOG,
            generator.DEFAULT_ISSUE_LINKS,
            generator.DEFAULT_JSON_OUTPUT,
            generator.DEFAULT_MARKDOWN_OUTPUT,
        )


class ReleaseEvidenceIssueBodySyncTests(unittest.TestCase):
    """Generator behavior for release evidence issue body sync."""

    def test_committed_issue_body_sync_is_current(self) -> None:
        """The committed body-sync artifacts match the committed inputs."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])

        self.assertEqual(result, 0)

    def test_builds_body_payloads_from_backlog_and_links(self) -> None:
        """The generator joins backlog bodies to live tracker issue links."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / generator.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))

            document = generator.build_body_sync(
                root,
                generator.DEFAULT_BACKLOG,
                generator.DEFAULT_ISSUE_LINKS,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )

            self.assertEqual(document["schema_version"], generator.BODY_SYNC_SCHEMA)
            self.assertEqual(len(document["issues"]), 1)
            issue = document["issues"][0]
            self.assertEqual(issue["entry_id"], "public-beta-audit")
            self.assertEqual(issue["issue_number"], 215)
            self.assertIn("Parent tracker:", issue["expected_body"])
            self.assertIn("entry_id=public-beta-audit", issue["expected_body"])
            self.assertIn("\n\n## Evidence Requirement", issue["expected_body"])
            self.assertEqual(issue["body_sha256"], generator.sha256_text(issue["expected_body"]))
            self.assertIn("# Release Evidence Issue Body Sync", generator.markdown_for_body_sync(document))

    def test_rejects_missing_issue_body_heading(self) -> None:
        """Issue bodies must keep all issue-ready sections."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        entry["issue_body"] = valid_issue_body().replace("## Validation\n\n", "")

        with self.assertRaisesRegex(
            generator.ReleaseEvidenceIssueBodySyncError,
            "missing ## Validation",
        ):
            build_body_sync_from_memory(
                backlog(entry),
                issue_links(link_for(entry, 215)),
            )

    def test_rejects_stale_issue_link_entry_id(self) -> None:
        """Links cannot reference entries absent from the backlog."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        stale = {**link_for(entry, 215), "entry_id": "stale-entry"}

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / generator.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links(stale))

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceIssueBodySyncError,
                "stale issue link",
            ):
                generator.build_body_sync(
                    root,
                    generator.DEFAULT_BACKLOG,
                    generator.DEFAULT_ISSUE_LINKS,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_duplicate_issue_numbers(self) -> None:
        """One issue number cannot have multiple generated bodies."""
        first = backlog_entry("public-beta-audit", "external_audit_report")
        second = backlog_entry("public-beta-fork", "fork_deployment_rehearsal")

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / generator.DEFAULT_BACKLOG, backlog(first, second))
            write_json(
                root / generator.DEFAULT_ISSUE_LINKS,
                issue_links(link_for(first, 215), link_for(second, 215)),
            )

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceIssueBodySyncError,
                "duplicate issue number",
            ):
                generator.build_body_sync(
                    root,
                    generator.DEFAULT_BACKLOG,
                    generator.DEFAULT_ISSUE_LINKS,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_check_mode_reports_drift(self) -> None:
        """Check mode detects generated output drift."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / generator.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))
            generator.write_outputs(
                root,
                generator.DEFAULT_BACKLOG,
                generator.DEFAULT_ISSUE_LINKS,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            write_text(root / generator.DEFAULT_MARKDOWN_OUTPUT, "# Drift\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(["--repo-root", str(root), "--check"])

            self.assertEqual(result, 1)
            self.assertIn("changed", stderr.getvalue())

    def test_secret_like_body_payload_is_rejected(self) -> None:
        """Generated bodies remain subject to the public evidence secret scanner."""
        entry = backlog_entry("public-beta-audit", "external_audit_report")
        entry["issue_body"] = valid_issue_body() + "\noperator secret: value\n"

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(root / generator.DEFAULT_BACKLOG, backlog(entry))
            write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceIssueBodySyncError,
                "secret-like data",
            ):
                generator.build_body_sync(
                    root,
                    generator.DEFAULT_BACKLOG,
                    generator.DEFAULT_ISSUE_LINKS,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_main_reports_invalid_encoding(self) -> None:
        """Unreadable UTF-8 inputs are reported without a traceback."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            entry = backlog_entry("public-beta-audit", "external_audit_report")
            write_json(root / generator.DEFAULT_ISSUE_LINKS, issue_links(link_for(entry, 215)))
            (root / generator.DEFAULT_BACKLOG).parent.mkdir(parents=True, exist_ok=True)
            (root / generator.DEFAULT_BACKLOG).write_bytes(b"\xff")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.main(["--repo-root", str(root)])

            self.assertEqual(result, 1)
            self.assertIn("unable to read", stderr.getvalue())

if __name__ == "__main__":
    unittest.main(verbosity=2)
