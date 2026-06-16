#!/usr/bin/env python3
"""Focused tests for release evidence packet index generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_release_evidence_packet_index.py")
SPEC = importlib.util.spec_from_file_location(
    "generate_release_evidence_packet_index", SCRIPT_PATH
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
    """Create a retained file and return its evidence reference."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def requirement(
    requirement_id: str,
    phase: str,
    status: str = "missing",
    *,
    evidence: list[dict[str, str]] | None = None,
    notes: str | None = None,
) -> dict[str, object]:
    """Build one evidence requirement row."""
    return {
        "id": requirement_id,
        "phase": phase,
        "status": status,
        "owner": "TBD",
        "evidence": [] if evidence is None else evidence,
        "risk_acceptance": None,
        "notes": notes or f"{requirement_id} remains {status}.",
    }


def valid_evidence(root: Path) -> dict[str, object]:
    """Build a valid blocked evidence manifest for packet tests."""
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
    """Write a valid evidence manifest and return its default path."""
    path = root / checker.DEFAULT_EVIDENCE
    write_json(path, valid_evidence(root) if evidence is None else evidence)
    return path


def seed_templates(
    root: Path,
    template_dir: Path,
    requirement_ids: tuple[str, ...],
    *,
    environment: str,
    retained_text: str,
) -> None:
    """Write one valid no-secret template for every requirement."""
    retained_path = template_dir / "retained-artifact-template.txt"
    write_text(root / retained_path, retained_text)
    retained_hash = non_local_checker.file_sha256(root / retained_path)
    for requirement_id in requirement_ids:
        template_name = requirement_id.replace("_", "-") + "-template.json"
        write_json(
            root / template_dir / template_name,
            {
                "schema_version": non_local_checker.EVIDENCE_SCHEMA,
                "evidence_id": f"template-{requirement_id}",
                "record_type": "template",
                "review_status": "template",
                "environment": environment,
                "chain_id": "not_applicable",
                "block_or_reference": f"template-only reference for {requirement_id}",
                "command_or_source_system": (
                    f"template-only validation command for {requirement_id}"
                ),
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
                    "Template only. This file is not completion evidence and "
                    "does not mark public beta or production ready."
                ),
                "operator_notes": f"Replace this template with reviewed {requirement_id}.",
            },
        )


def seed_all_templates(root: Path) -> None:
    """Write public-beta and production-release template sets."""
    seed_templates(
        root,
        non_local_checker.PUBLIC_BETA_TEMPLATE_DIR,
        checker.PUBLIC_BETA_REQUIREMENTS,
        environment="audit",
        retained_text="Public beta template retained artifact.\n",
    )
    write_text(
        root / generator.EXTERNAL_AUDIT_RETAINED_ARTIFACT_TEMPLATE,
        "External audit report retained artifact template.\n",
    )
    write_text(
        root / generator.FORK_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE,
        "Fork deployment rehearsal retained artifact template.\n",
    )
    write_text(
        root / generator.TESTNET_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE,
        "Testnet deployment rehearsal retained artifact template.\n",
    )
    write_text(
        root / generator.PUBLIC_BETA_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE,
        "Fork/testnet marketplace and indexer retained artifact template.\n",
    )
    write_text(
        root / generator.LIVE_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE,
        "Live marketplace and indexer retained artifact template.\n",
    )
    write_text(
        root / generator.LIVE_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE,
        "Live metadata browser retained artifact template.\n",
    )
    write_text(
        root / generator.PRODUCTION_VERIFIED_ADDRESSES_RETAINED_ARTIFACT_TEMPLATE,
        "Production verified-addresses retained artifact template.\n",
    )
    seed_templates(
        root,
        non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR,
        checker.PRODUCTION_REQUIREMENTS,
        environment="release_signing",
        retained_text="Production template retained artifact.\n",
    )


def write_blocker_reports(root: Path) -> None:
    """Write compact blocker reports with the requirement markers the packet checks."""
    public_rows = "\n".join(f"| `{requirement_id}` | missing |" for requirement_id in checker.PUBLIC_BETA_REQUIREMENTS)
    write_text(
        root / generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
        "# Public Beta Evidence Blocker Report\n\n"
        "## Incomplete Public Beta Rows\n\n"
        + public_rows
        + "\n",
    )
    production_rows = []
    for requirement_id in checker.PRODUCTION_REQUIREMENTS:
        template_path = (
            non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR
            / (requirement_id.replace("_", "-") + "-template.json")
        )
        production_rows.append(
            f"| `{requirement_id}` | missing | `{template_path.as_posix()}` |"
        )
    write_text(
        root / generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
        "# Production Release Evidence Blocker Report\n\n"
        "## Incomplete Production Release Rows\n\n"
        + "\n".join(production_rows)
        + "\n",
    )


def seed_repo(root: Path, evidence: dict[str, object] | None = None) -> None:
    """Seed the minimum committed inputs needed by the packet generator."""
    write_valid_evidence(root, evidence)
    seed_all_templates(root)
    write_blocker_reports(root)
    write_text(
        root / generator.DEFAULT_NON_LOCAL_RUNBOOK,
        "# Non-Local Release Evidence\n\nKeep private material out of the repo.\n",
    )


class ReleaseEvidencePacketIndexTests(unittest.TestCase):
    """Generator behavior for the release evidence packet index."""

    def test_accepts_committed_packet_index(self) -> None:
        """The committed packet index matches the committed no-secret inputs."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = generator.main(["--repo-root", str(repo_root), "--check"])

        self.assertEqual(result, 0)

    def test_packet_covers_every_release_requirement(self) -> None:
        """Every public-beta and production row appears once in the packet."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            row_ids = {(row["phase"], row["requirement_id"]) for row in packet["rows"]}

            expected_rows = len(checker.PUBLIC_BETA_REQUIREMENTS) + len(
                checker.PRODUCTION_REQUIREMENTS
            )
            self.assertEqual(len(packet["rows"]), expected_rows)
            for requirement_id in checker.PUBLIC_BETA_REQUIREMENTS:
                self.assertIn((checker.PUBLIC_BETA_PHASE, requirement_id), row_ids)
            for requirement_id in checker.PRODUCTION_REQUIREMENTS:
                self.assertIn((checker.PRODUCTION_PHASE, requirement_id), row_ids)

    def test_packet_rows_include_templates_commands_and_policy(self) -> None:
        """Rows include operator handoff links and reject template-only completion."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"] == "fork_testnet_metadata_browser_evidence"
            )

            self.assertEqual(row["template_only_can_complete"], False)
            self.assertIn("review_status=template", row["owner_reviewer_posture"])
            self.assertIn("retained-artifact-template.txt", row["retained_artifact_expectation"]["path"])
            self.assertIn("python scripts/generate_release_evidence_packet_index.py --check", row["validation_commands"])
            self.assertIn("blocker_report", row)
            self.assertEqual(packet["policy"]["template_only_can_complete"], False)

    def test_external_audit_row_uses_canonical_retained_artifact(self) -> None:
        """External audit tracker rows point at the audit-specific template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            audit_row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"] == generator.EXTERNAL_AUDIT_REQUIREMENT_ID
            )

            self.assertEqual(
                audit_row["retained_artifact_expectation"]["path"],
                generator.EXTERNAL_AUDIT_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                audit_row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root / generator.EXTERNAL_AUDIT_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertIn(
                "python scripts/test_external_audit_report_evidence.py",
                audit_row["validation_commands"],
            )
            self.assertIn(
                "python scripts/check_external_audit_report_evidence.py",
                audit_row["validation_commands"],
            )

    def test_fork_rehearsal_row_uses_canonical_retained_artifact(self) -> None:
        """Fork deployment tracker rows point at the fork-specific template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            fork_row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"] == generator.FORK_DEPLOYMENT_REQUIREMENT_ID
            )

            self.assertEqual(
                fork_row["retained_artifact_expectation"]["path"],
                generator.FORK_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                fork_row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root / generator.FORK_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertIn(
                "python scripts/test_fork_deployment_rehearsal_evidence.py",
                fork_row["validation_commands"],
            )
            self.assertIn(
                "python scripts/check_fork_deployment_rehearsal_evidence.py",
                fork_row["validation_commands"],
            )

    def test_testnet_rehearsal_row_uses_canonical_retained_artifact(self) -> None:
        """Testnet deployment tracker rows point at the testnet-specific template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            testnet_row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"] == generator.TESTNET_DEPLOYMENT_REQUIREMENT_ID
            )

            self.assertEqual(
                testnet_row["retained_artifact_expectation"]["path"],
                generator.TESTNET_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                testnet_row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root / generator.TESTNET_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertIn(
                "python scripts/test_testnet_deployment_rehearsal_evidence.py",
                testnet_row["validation_commands"],
            )
            self.assertIn(
                "python scripts/check_testnet_deployment_rehearsal_evidence.py",
                testnet_row["validation_commands"],
            )

    def test_marketplace_indexer_rows_use_canonical_retained_artifacts(self) -> None:
        """Marketplace/indexer tracker rows point at dedicated retained templates."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            public_row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"]
                == generator.PUBLIC_BETA_MARKETPLACE_INDEXER_REQUIREMENT_ID
            )
            live_row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"]
                == generator.LIVE_MARKETPLACE_INDEXER_REQUIREMENT_ID
            )

            self.assertEqual(
                public_row["retained_artifact_expectation"]["path"],
                generator.PUBLIC_BETA_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                public_row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root
                    / generator.PUBLIC_BETA_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertEqual(
                live_row["retained_artifact_expectation"]["path"],
                generator.LIVE_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                live_row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root / generator.LIVE_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertIn(
                "python scripts/test_marketplace_indexer_evidence.py",
                public_row["validation_commands"],
            )
            self.assertIn(
                "python scripts/check_marketplace_indexer_evidence.py",
                live_row["validation_commands"],
            )

    def test_live_metadata_browser_row_uses_canonical_retained_artifact(self) -> None:
        """Live metadata-browser tracker rows point at the dedicated template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            row = next(
                row
                for row in packet["rows"]
                if row["requirement_id"] == generator.LIVE_METADATA_BROWSER_REQUIREMENT_ID
            )

            self.assertEqual(
                row["retained_artifact_expectation"]["path"],
                generator.LIVE_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
            )
            self.assertEqual(
                row["retained_artifact_expectation"]["sha256"],
                checker.file_sha256(
                    root / generator.LIVE_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE
                ),
            )
            self.assertIn(
                "python scripts/test_live_metadata_browser_evidence.py",
                row["validation_commands"],
            )
            self.assertIn(
                "python scripts/check_live_metadata_browser_evidence.py",
                row["validation_commands"],
            )

    def test_production_verified_address_rows_use_canonical_retained_artifact(self) -> None:
        """Production address and explorer rows point at the dedicated template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            packet = generator.build_packet(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            rows = {
                row["requirement_id"]: row
                for row in packet["rows"]
                if row["requirement_id"]
                in {
                    generator.PRODUCTION_ADDRESS_BOOKS_REQUIREMENT_ID,
                    generator.LIVE_EXPLORER_VERIFICATION_REQUIREMENT_ID,
                }
            }

            self.assertEqual(
                set(rows),
                {
                    generator.PRODUCTION_ADDRESS_BOOKS_REQUIREMENT_ID,
                    generator.LIVE_EXPLORER_VERIFICATION_REQUIREMENT_ID,
                },
            )
            for row in rows.values():
                self.assertEqual(
                    row["retained_artifact_expectation"]["path"],
                    generator.PRODUCTION_VERIFIED_ADDRESSES_RETAINED_ARTIFACT_TEMPLATE.as_posix(),
                )
                self.assertEqual(
                    row["retained_artifact_expectation"]["sha256"],
                    checker.file_sha256(
                        root
                        / generator.PRODUCTION_VERIFIED_ADDRESSES_RETAINED_ARTIFACT_TEMPLATE
                    ),
                )
                self.assertIn(
                    "python scripts/test_production_verified_addresses.py",
                    row["validation_commands"],
                )
                self.assertIn(
                    "python scripts/check_production_verified_addresses.py",
                    row["validation_commands"],
                )

    def test_outputs_are_deterministic(self) -> None:
        """Rendering the same inputs twice produces identical JSON and Markdown."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)

            first = generator.build_outputs(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            second = generator.build_outputs(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )

            self.assertEqual(first, second)

    def test_rejects_missing_template(self) -> None:
        """Generation fails when a requirement lacks a checked template."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)
            missing_requirement_id = checker.PUBLIC_BETA_REQUIREMENTS[0]
            missing_template = (
                root
                / non_local_checker.PUBLIC_BETA_TEMPLATE_DIR
                / (missing_requirement_id.replace("_", "-") + "-template.json")
            )
            missing_template.unlink()

            with self.assertRaisesRegex(
                generator.ReleaseEvidencePacketIndexError,
                "missing public-beta template",
            ):
                generator.build_packet(
                    root,
                    checker.DEFAULT_EVIDENCE,
                    generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                    generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                    generator.DEFAULT_NON_LOCAL_RUNBOOK,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_template_only_completion_evidence(self) -> None:
        """A complete row cannot be backed only by a template reference."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)
            evidence = valid_evidence(root)
            requirement_id = checker.PUBLIC_BETA_REQUIREMENTS[0]
            template_path = (
                non_local_checker.PUBLIC_BETA_TEMPLATE_DIR
                / (requirement_id.replace("_", "-") + "-template.json")
            )
            evidence["requirements"][0] = requirement(
                requirement_id,
                checker.PUBLIC_BETA_PHASE,
                "complete",
                evidence=[
                    {
                        "path": template_path.as_posix(),
                        "sha256": checker.file_sha256(root / template_path),
                    }
                ],
            )
            write_valid_evidence(root, evidence)

            with self.assertRaisesRegex(
                generator.ReleaseEvidencePacketIndexError,
                "reviewed non-local release evidence|template-only evidence cannot complete",
            ):
                generator.build_packet(
                    root,
                    checker.DEFAULT_EVIDENCE,
                    generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                    generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                    generator.DEFAULT_NON_LOCAL_RUNBOOK,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_blocker_report_missing_requirement(self) -> None:
        """The packet checker ties rows back to the generated blocker reports."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)
            write_text(
                root / generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                "# Public Beta Evidence Blocker Report\n\nmissing row\n",
            )

            with self.assertRaisesRegex(
                generator.ReleaseEvidencePacketIndexError,
                "blocker report for public_beta is missing requirement",
            ):
                generator.build_packet(
                    root,
                    checker.DEFAULT_EVIDENCE,
                    generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                    generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                    generator.DEFAULT_NON_LOCAL_RUNBOOK,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_rejects_secret_like_template_metadata(self) -> None:
        """Secret-shaped template metadata cannot flow into the packet."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)
            template_path = (
                root
                / non_local_checker.PUBLIC_BETA_TEMPLATE_DIR
                / "external-audit-report-template.json"
            )
            template = json.loads(template_path.read_text(encoding="utf-8"))
            template["operator_notes"] = "api_key: do not commit this"
            write_json(template_path, template)

            with self.assertRaisesRegex(
                generator.ReleaseEvidencePacketIndexError,
                "secret-like value",
            ):
                generator.build_packet(
                    root,
                    checker.DEFAULT_EVIDENCE,
                    generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                    generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                    generator.DEFAULT_NON_LOCAL_RUNBOOK,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

    def test_check_mode_rejects_drift(self) -> None:
        """Check mode fails when a committed packet output is stale."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_repo(root)
            generator.write_outputs(
                root,
                checker.DEFAULT_EVIDENCE,
                generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                generator.DEFAULT_NON_LOCAL_RUNBOOK,
                generator.DEFAULT_JSON_OUTPUT,
                generator.DEFAULT_MARKDOWN_OUTPUT,
            )
            write_text(root / generator.DEFAULT_MARKDOWN_OUTPUT, "stale\n")

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = generator.check_outputs(
                    root,
                    checker.DEFAULT_EVIDENCE,
                    generator.DEFAULT_PUBLIC_BETA_BLOCKERS,
                    generator.DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
                    generator.DEFAULT_NON_LOCAL_RUNBOOK,
                    generator.DEFAULT_JSON_OUTPUT,
                    generator.DEFAULT_MARKDOWN_OUTPUT,
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "changed release-artifacts/latest/release-evidence-packet-index.md",
                stderr.getvalue(),
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
