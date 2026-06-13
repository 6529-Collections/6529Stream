#!/usr/bin/env python3
"""Focused tests for production-release blocker report generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_production_release_blocker_report.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_production_release_blocker_report", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)
checker = generator.evidence_checker
non_local_checker = generator.non_local_checker


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
    """Build one evidence requirement row."""
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
        "environment": "release_signing",
        "chain_id": "not_applicable",
        "block_or_reference": "release ceremony reference",
        "command_or_source_system": "release ceremony transcript",
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


def seed_production_templates(root: Path) -> None:
    """Write one valid production-release template for each production requirement."""
    retained_path = (
        non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR
        / "retained-artifact-template.txt"
    )
    write_text(
        root / retained_path,
        "Template retained artifact for production-release report tests.\n",
    )
    retained_hash = non_local_checker.file_sha256(root / retained_path)
    for requirement_id in checker.PRODUCTION_REQUIREMENTS:
        template_name = requirement_id.replace("_", "-") + "-template.json"
        write_json(
            root / non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR / template_name,
            {
                "schema_version": non_local_checker.EVIDENCE_SCHEMA,
                "evidence_id": f"production-release-template-{requirement_id}",
                "record_type": "template",
                "review_status": "template",
                "environment": "release_signing",
                "chain_id": "not_applicable",
                "block_or_reference": "template-only release reference",
                "command_or_source_system": "template-only verification command",
                "retained_path": retained_path.as_posix(),
                "sha256": retained_hash,
                "redaction_statement": "Template only; no secrets are present.",
                "owner": "TBD",
                "reviewer": "TBD",
                "public_beta_requirement_id": requirement_id,
                "source": {
                    "repository": "https://github.com/6529-Collections/6529Stream",
                    "git_commit": "0" * 40,
                    "source_dirty": False,
                    "ci_run": "template",
                },
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
                "template_notice": (
                    "Template only. This file is not completion evidence and does "
                    "not mark production ready."
                ),
                "operator_notes": f"Template for {requirement_id}.",
            },
        )


class ProductionReleaseBlockerReportTests(unittest.TestCase):
    """Generator behavior for the production-release blocker report."""

    def test_accepts_committed_report(self) -> None:
        """The committed report matches the committed evidence manifest."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])

        self.assertEqual(result, 0)

    def test_report_lists_only_production_release_rows(self) -> None:
        """Every incomplete production row appears without public-beta rows."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            seed_production_templates(root)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("## Incomplete Production Release Rows", report)
            for requirement_id in checker.PRODUCTION_REQUIREMENTS:
                self.assertIn(f"| `{requirement_id}` |", report)
            self.assertNotIn("| `external_audit_report` |", report)
            self.assertIn("intentionally blocked for production release", report)

    def test_report_links_every_production_template(self) -> None:
        """Every production requirement row names its matching template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            seed_production_templates(root)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            for requirement_id in checker.PRODUCTION_REQUIREMENTS:
                template_name = requirement_id.replace("_", "-") + "-template.json"
                template_path = (
                    "release-artifacts/evidence/production-release-templates/"
                    f"{template_name}"
                )
                self.assertIn(f"`{template_path}`", report)

    def test_production_rows_are_grouped_by_status_then_requirement_id(self) -> None:
        """Mixed-status production rows are grouped before Markdown rendering."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_production_templates(root)
            evidence = valid_evidence(root)
            production_ids = list(checker.PRODUCTION_REQUIREMENTS)
            status_by_id = {
                production_ids[0]: "pending",
                production_ids[1]: "pending",
                production_ids[2]: "blocked",
                production_ids[-1]: "missing",
            }
            for row in evidence["requirements"]:
                if row["phase"] != checker.PRODUCTION_PHASE:
                    continue
                row_id = row["id"]
                if row_id in status_by_id:
                    row["status"] = status_by_id[row_id]
                    row["notes"] = f"{row_id} remains {status_by_id[row_id]}."
            write_valid_evidence(root, evidence)

            by_phase = generator.canonical_requirements(evidence)
            templates = generator.production_template_map(root)
            rows = generator.production_requirement_rows(
                by_phase,
                templates,
                root,
                {"missing", "pending", "blocked"},
            )

            observed = [
                (row[1].strip("`"), row[0].strip("`"))
                for row in rows
                if row[0].strip("`") in status_by_id
            ]
            status_rank = {
                status: index for index, status in enumerate(generator.STATUS_ORDER)
            }
            expected = sorted(
                ((status, requirement_id) for requirement_id, status in status_by_id.items()),
                key=lambda item: (status_rank[item[0]], item[1]),
            )
            self.assertEqual(observed, expected)

    def test_report_is_deterministic(self) -> None:
        """Rendering the same evidence twice produces identical text."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            seed_production_templates(root)

            first = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )
            second = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertEqual(first, second)

    def test_report_lists_reviewed_production_rows(self) -> None:
        """Complete reviewed production rows appear outside incomplete blockers."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_production_templates(root)
            evidence = valid_evidence(root)
            requirement_id = checker.PRODUCTION_REQUIREMENTS[0]
            evidence_ref = file_ref(
                root,
                "release-artifacts/evidence/production-reviewed.json",
                json.dumps(runbook_evidence(requirement_id)) + "\n",
            )
            production_index = len(checker.PUBLIC_BETA_REQUIREMENTS)
            evidence["requirements"][production_index] = requirement(
                requirement_id,
                checker.PRODUCTION_PHASE,
                "complete",
                evidence=[evidence_ref],
            )
            write_valid_evidence(root, evidence)

            report = generator.build_output_text(
                root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
            )

            self.assertIn("## Reviewed Production Evidence Rows", report)
            self.assertIn("reviewed-external", report)

    def test_missing_template_references_are_rejected(self) -> None:
        """The report requires a checked production template set."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)

            with self.assertRaisesRegex(
                generator.ProductionReleaseBlockerReportError,
                "invalid production-release template set",
            ):
                generator.build_output_text(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

    def test_secret_like_value_is_rejected_by_manifest_validation(self) -> None:
        """Secret-shaped source data is rejected before report rendering."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_production_templates(root)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            write_valid_evidence(root, evidence)

            with self.assertRaisesRegex(
                generator.ProductionReleaseBlockerReportError,
                "secret-like value",
            ):
                generator.build_output_text(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

    def test_check_mode_detects_drift(self) -> None:
        """Check mode fails when the committed report is stale."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            seed_production_templates(root)
            output_path = root / generator.DEFAULT_OUTPUT
            write_text(output_path, "stale\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/production-release-blockers.md",
                stderr.getvalue(),
            )

    def test_check_mode_rejects_missing_output(self) -> None:
        """Check mode names the missing report path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_valid_evidence(root)
            seed_production_templates(root)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_output(
                    root, checker.DEFAULT_EVIDENCE, generator.DEFAULT_OUTPUT
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "missing release-artifacts/latest/production-release-blockers.md",
                stderr.getvalue(),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
