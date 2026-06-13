#!/usr/bin/env python3
"""Focused tests for release evidence issue backlog generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_evidence_issue_backlog.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_release_evidence_issue_backlog", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def packet_row(
    phase: str,
    requirement_id: str,
    *,
    status: str = "missing",
    template_only_can_complete: bool = False,
    operator_notes: str | None = None,
) -> dict[str, object]:
    """Build one packet row for issue-backlog tests."""
    phase_label = {
        generator.PUBLIC_BETA_PHASE: "Public Beta",
        generator.PRODUCTION_PHASE: "Production Release",
    }[phase]
    template_path = (
        "release-artifacts/evidence/"
        f"{phase.replace('_', '-')}-templates/{requirement_id}-template.json"
    )
    retained_path = (
        "release-artifacts/evidence/"
        f"{phase.replace('_', '-')}-templates/{requirement_id}-retained.txt"
    )
    blocker_path = (
        "release-artifacts/latest/public-beta-blockers.md"
        if phase == generator.PUBLIC_BETA_PHASE
        else "release-artifacts/latest/production-release-blockers.md"
    )
    return {
        "phase": phase,
        "phase_label": phase_label,
        "requirement_id": requirement_id,
        "status": status,
        "evidence_posture": "Retained evidence is not yet present.",
        "owner": "TBD",
        "template_owner": "TBD",
        "reviewer": "TBD",
        "review_status": "template",
        "owner_reviewer_posture": "Owner and reviewer are placeholders.",
        "blocker_report": {
            "path": blocker_path,
            "section": f"Incomplete {phase_label} Rows",
            "requirement_marker": f"`{requirement_id}`",
        },
        "template": {
            "path": template_path,
            "schema_version": "6529stream.non-local-release-evidence.v1",
            "evidence_id": f"template-{requirement_id}",
            "record_type": "template",
            "review_status": "template",
        },
        "retained_artifact_expectation": {
            "path": retained_path,
            "sha256": "sha256:" + ("0" * 64),
            "block_or_reference": f"retained reference for {requirement_id}",
            "command_or_source_system": f"validate retained {requirement_id}",
            "operator_notes": operator_notes
            or f"Replace template evidence for {requirement_id}.",
        },
        "validation_commands": [
            "python scripts/check_public_beta_evidence.py",
            "python scripts/generate_release_evidence_packet_index.py --check",
        ],
        "template_only_can_complete": template_only_can_complete,
    }


def packet(*rows: dict[str, object], schema_version: str | None = None) -> dict[str, object]:
    """Build a minimal packet index document for issue-backlog tests."""
    return {
        "schema_version": schema_version or generator.PACKET_SCHEMA,
        "generated_by": "scripts/generate_release_evidence_packet_index.py:1",
        "release_version": "v0.1.0-local",
        "release_source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "status": {
            generator.PUBLIC_BETA_PHASE: "blocked",
            generator.PRODUCTION_PHASE: "blocked",
        },
        "policy": {
            "no_secrets": True,
            "template_only_can_complete": False,
        },
        "rows": list(rows),
    }


class ReleaseEvidenceIssueBacklogTests(unittest.TestCase):
    """Generator behavior for the release evidence issue backlog."""

    def test_committed_issue_backlog_is_current(self) -> None:
        """The committed issue backlog matches the committed packet index."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])

        self.assertEqual(result, 0)

    def test_builds_issue_ready_entries_for_incomplete_rows(self) -> None:
        """Incomplete packet rows become issue-ready backlog entries."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            packet_path = root / generator.DEFAULT_PACKET_INDEX
            write_json(
                packet_path,
                packet(
                    packet_row(generator.PUBLIC_BETA_PHASE, "external_audit_report"),
                    packet_row(generator.PRODUCTION_PHASE, "production_signatures"),
                    packet_row(
                        generator.PUBLIC_BETA_PHASE,
                        "complete_requirement",
                        status="complete",
                    ),
                ),
            )

            backlog = generator.build_backlog(
                root,
                generator.DEFAULT_PACKET_INDEX,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )

            self.assertEqual(backlog["schema_version"], generator.BACKLOG_SCHEMA)
            self.assertEqual(len(backlog["entries"]), 2)
            entry_ids = {entry["entry_id"] for entry in backlog["entries"]}
            self.assertEqual(
                entry_ids,
                {
                    "public-beta-external-audit-report",
                    "production-release-production-signatures",
                },
            )
            first_entry = backlog["entries"][0]
            self.assertIn("release", first_entry["suggested_labels"])
            self.assertIn("evidence", first_entry["suggested_labels"])
            self.assertIn("roadmap", first_entry["suggested_labels"])
            self.assertIn("public-beta", first_entry["suggested_labels"])
            self.assertIn("Requirement ID", first_entry["issue_body"])
            self.assertIn("Validation", first_entry["issue_body"])
            self.assertFalse(first_entry["template_only_can_complete"])
            self.assertFalse(backlog["policy"]["template_only_can_complete"])
            self.assertFalse(backlog["policy"]["auto_create_issues"])
            self.assertEqual(backlog["status_summary"][0]["entry_count"], 1)
            self.assertEqual(backlog["status_summary"][1]["entry_count"], 1)

    def test_check_mode_accepts_current_outputs(self) -> None:
        """Check mode accepts freshly generated backlog outputs."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(
                root / generator.DEFAULT_PACKET_INDEX,
                packet(packet_row(generator.PUBLIC_BETA_PHASE, "external_audit_report")),
            )

            generator.write_outputs(
                root,
                generator.DEFAULT_PACKET_INDEX,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = generator.check_outputs(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

            self.assertEqual(result, 0)

    def test_check_mode_rejects_drift(self) -> None:
        """Check mode reports regenerated files that differ from disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(
                root / generator.DEFAULT_PACKET_INDEX,
                packet(packet_row(generator.PUBLIC_BETA_PHASE, "external_audit_report")),
            )
            generator.write_outputs(
                root,
                generator.DEFAULT_PACKET_INDEX,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            write_text(root / generator.DEFAULT_MARKDOWN_OUTPUT, "# stale\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/release-evidence-issue-backlog.md",
                stderr.getvalue(),
            )

    def test_rejects_template_only_completion(self) -> None:
        """The backlog refuses packets that allow template-only completion."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(
                root / generator.DEFAULT_PACKET_INDEX,
                {
                    **packet(packet_row(generator.PUBLIC_BETA_PHASE, "external_audit_report")),
                    "policy": {
                        "no_secrets": True,
                        "template_only_can_complete": True,
                    },
                },
            )

            with self.assertRaises(generator.ReleaseEvidenceIssueBacklogError):
                generator.build_backlog(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_wrong_packet_schema(self) -> None:
        """The backlog only accepts the current packet-index schema."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(
                root / generator.DEFAULT_PACKET_INDEX,
                packet(
                    packet_row(generator.PUBLIC_BETA_PHASE, "external_audit_report"),
                    schema_version="wrong.schema",
                ),
            )

            with self.assertRaises(generator.ReleaseEvidenceIssueBacklogError):
                generator.build_backlog(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_secret_scan_rejects_secret_like_generated_content(self) -> None:
        """Secret-like row content cannot be copied into generated issue bodies."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_json(
                root / generator.DEFAULT_PACKET_INDEX,
                packet(
                    packet_row(
                        generator.PUBLIC_BETA_PHASE,
                        "external_audit_report",
                        operator_notes="password: never commit this",
                    )
                ),
            )

            with self.assertRaises(generator.ReleaseEvidenceIssueBacklogError):
                generator.build_backlog(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_unknown_phase_and_status(self) -> None:
        """Unknown packet phases and statuses fail explicitly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            unknown_phase = packet_row(
                generator.PUBLIC_BETA_PHASE,
                "external_audit_report",
            )
            unknown_phase["phase"] = "surprise"
            write_json(root / generator.DEFAULT_PACKET_INDEX, packet(unknown_phase))

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceIssueBacklogError,
                "unknown packet row phase",
            ):
                generator.build_backlog(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            unknown_status = packet_row(
                generator.PUBLIC_BETA_PHASE,
                "external_audit_report",
                status="surprise",
            )
            write_json(root / generator.DEFAULT_PACKET_INDEX, packet(unknown_status))

            with self.assertRaisesRegex(
                generator.ReleaseEvidenceIssueBacklogError,
                "unknown packet row status",
            ):
                generator.build_backlog(
                    root,
                    generator.DEFAULT_PACKET_INDEX,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
