#!/usr/bin/env python3
"""Focused tests for public-beta blocker report generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_public_beta_blocker_report.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_public_beta_blocker_report", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)
checker = generator.evidence_checker


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


def file_ref(root: Path, relative_path: str, content: str = "evidence\n") -> dict[str, str]:
    """Create a retained file and return its public evidence reference."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def requirement(
    requirement_id: str,
    phase: str,
    status: str = "missing",
    *,
    evidence: list[dict[str, str]] | None = None,
    risk_acceptance: dict[str, str] | None = None,
    notes: str | None = None,
) -> dict[str, object]:
    """Build one public-beta evidence requirement row."""
    return {
        "id": requirement_id,
        "phase": phase,
        "status": status,
        "owner": "TBD",
        "evidence": [] if evidence is None else evidence,
        "risk_acceptance": risk_acceptance,
        "notes": notes or f"{requirement_id} remains {status}.",
    }


def runbook_evidence(requirement_id: str) -> dict[str, object]:
    """Build reviewed non-local evidence metadata for complete rows."""
    return {
        "environment": "audit",
        "chain_id": "not_applicable",
        "block_or_reference": "audit report draft reference",
        "command_or_source_system": "auditor portal",
        "retained_path": f"release-artifacts/evidence/{requirement_id}.json",
        "sha256": "sha256:" + "1" * 64,
        "redaction_statement": "Secrets were never present.",
        "owner": "release-operator",
        "reviewer": "release-reviewer",
        "public_beta_requirement_id": requirement_id,
    }


def valid_evidence(root: Path) -> dict[str, object]:
    """Build a valid blocked evidence document for report tests."""
    schema_ref = {
        **file_ref(root, "release-artifacts/schema/public-beta-evidence.schema.json"),
        "category": "public_beta_evidence_schema",
    }
    requirements: list[dict[str, object]] = []
    for requirement_id in checker.PUBLIC_BETA_REQUIREMENTS:
        requirements.append(requirement(requirement_id, checker.PUBLIC_BETA_PHASE))
    for requirement_id in checker.PRODUCTION_REQUIREMENTS:
        requirements.append(requirement(requirement_id, checker.PRODUCTION_PHASE))

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "release_version": "v0.1.0-local",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "status": {
            "public_beta": "blocked",
            "production_release": "blocked",
        },
        "requirements": requirements,
        "retained_artifacts": [schema_ref],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "api_key",
                "rpc_url",
                "unreleased_drop_payload",
            ],
        },
        "operator_notes": "Public beta and production release remain blocked.",
    }


def write_valid_evidence(root: Path, evidence: dict[str, object] | None = None) -> Path:
    """Write a valid evidence file and return its default path."""
    path = root / checker.DEFAULT_EVIDENCE
    write_json(path, valid_evidence(root) if evidence is None else evidence)
    return path


class PublicBetaBlockerReportTests(unittest.TestCase):
    """Generator behavior for the public-beta blocker report."""

    def test_accepts_committed_report(self) -> None:
        """The committed report matches the committed evidence manifest."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])

        self.assertEqual(result, 0)

    def test_report_lists_every_incomplete_public_beta_row(self) -> None:
        """Every incomplete public-beta row appears in the generated report."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("## Incomplete Public Beta Rows", report)
            for requirement_id in checker.PUBLIC_BETA_REQUIREMENTS:
                self.assertIn(f"| `{requirement_id}` |", report)
            self.assertIn("| `production_signatures` |", report)
            self.assertIn("The committed baseline remains intentionally blocked", report)

    def test_report_is_deterministic(self) -> None:
        """Rendering the same evidence twice produces identical text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)

            first = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )
            second = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertEqual(first, second)

    def test_report_marks_local_template_only_evidence(self) -> None:
        """Template-only retained evidence is visible without claiming readiness."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence_ref = file_ref(
                root,
                "release-artifacts/evidence/external-audit-template.json",
                "{}\n",
            )
            evidence["requirements"][0] = requirement(
                checker.PUBLIC_BETA_REQUIREMENTS[0],
                checker.PUBLIC_BETA_PHASE,
                "pending",
                evidence=[evidence_ref],
            )
            write_valid_evidence(root, evidence)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("local-template-only", report)

    def test_report_lists_reviewed_external_rows(self) -> None:
        """Complete reviewed evidence rows appear outside incomplete blockers."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            requirement_id = checker.PUBLIC_BETA_REQUIREMENTS[0]
            evidence_ref = file_ref(
                root,
                "release-artifacts/evidence/external-audit-reviewed.json",
                json.dumps(runbook_evidence(requirement_id)) + "\n",
            )
            evidence["requirements"][0] = requirement(
                requirement_id,
                checker.PUBLIC_BETA_PHASE,
                "complete",
                evidence=[evidence_ref],
            )
            write_valid_evidence(root, evidence)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("## Reviewed External Evidence Rows", report)
            self.assertIn("reviewed-external", report)

    def test_unknown_status_is_rejected_by_manifest_validation(self) -> None:
        """The report cannot render evidence with unknown statuses."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["status"] = "surprising"
            write_valid_evidence(root, evidence)

            with self.assertRaisesRegex(
                generator.PublicBetaBlockerReportError, "must be one of"
            ):
                generator.build_output_text(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

    def test_path_escape_is_rejected_by_manifest_validation(self) -> None:
        """Unsafe retained paths cannot reach the report."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["status"] = "pending"
            evidence["requirements"][0]["evidence"] = [
                {"path": "../outside.txt", "sha256": "sha256:" + "0" * 64}
            ]
            write_valid_evidence(root, evidence)

            with self.assertRaisesRegex(
                generator.PublicBetaBlockerReportError,
                "stay inside the repository",
            ):
                generator.build_output_text(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

    def test_secret_like_value_is_rejected_by_manifest_validation(self) -> None:
        """Secret-shaped source data is rejected before report rendering."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            write_valid_evidence(root, evidence)

            with self.assertRaisesRegex(
                generator.PublicBetaBlockerReportError,
                "secret-like value",
            ):
                generator.build_output_text(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

    def test_markdown_table_cells_are_escaped(self) -> None:
        """Requirement notes cannot break report tables."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["requirements"][0]["notes"] = "Pipe | value is escaped."
            write_valid_evidence(root, evidence)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("Pipe \\| value is escaped.", report)

    def test_check_mode_detects_drift(self) -> None:
        """Check mode fails when the committed report is stale."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            output_path = root / generator.DEFAULT_OUTPUT
            write_text(output_path, "stale\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/public-beta-blockers.md",
                stderr.getvalue(),
            )

    def test_check_mode_rejects_missing_output(self) -> None:
        """Check mode names the missing report path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "missing release-artifacts/latest/public-beta-blockers.md",
                stderr.getvalue(),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
