#!/usr/bin/env python3
"""Focused tests for release-mode evidence gates."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

SCRIPT_PATH = SCRIPT_DIR / "check_release_mode.py"
SPEC = importlib.util.spec_from_file_location("check_release_mode", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

evidence_checker = checker.evidence_checker


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


def file_ref(root: Path, relative_path: str, content: str) -> dict[str, str]:
    """Create an evidence file and return a manifest file reference."""
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": evidence_checker.file_sha256(path)}


def runbook_metadata(requirement_id: str, phase: str) -> dict[str, object]:
    """Build reviewed no-secret runbook metadata for a completed row."""
    environment = "live" if phase == evidence_checker.PUBLIC_BETA_PHASE else "release_signing"
    chain_id: object = 1 if environment == "live" else "not_applicable"
    return {
        "environment": environment,
        "chain_id": chain_id,
        "block_or_reference": "release-mode-fixture",
        "command_or_source_system": "release-mode fixture",
        "retained_path": f"release-artifacts/evidence/release-mode/{requirement_id}.json",
        "sha256": "sha256:" + "1" * 64,
        "redaction_statement": "No secrets are present in this fixture.",
        "owner": "release-operator",
        "reviewer": "release-reviewer",
        "public_beta_requirement_id": requirement_id,
    }


def evidence_row(
    root: Path,
    requirement_id: str,
    phase: str,
    status: str,
) -> dict[str, object]:
    """Build one requirement row with evidence when release-ready."""
    evidence: list[dict[str, str]] = []
    risk_acceptance: dict[str, str] | None = None
    if status == "complete":
        evidence = [
            file_ref(
                root,
                f"release-artifacts/evidence/release-mode/{requirement_id}.json",
                json.dumps(runbook_metadata(requirement_id, phase)) + "\n",
            )
        ]
    if status == "accepted_risk":
        risk_acceptance = {
            "accepted_by": "protocol-owner",
            "accepted_at": "2026-06-16",
            "expires_at": "2026-07-16",
            "reference": "docs/release-policy.md#risk-acceptance",
            "notes": "Fixture risk acceptance for release-mode gate coverage.",
        }
    return {
        "id": requirement_id,
        "phase": phase,
        "status": status,
        "owner": "release-operator",
        "evidence": evidence,
        "risk_acceptance": risk_acceptance,
        "notes": f"{requirement_id} is {status} for release-mode fixture coverage.",
    }


def evidence_document(
    root: Path,
    *,
    public_beta_status: str,
    production_status: str,
    public_beta_requirement_status: str = "complete",
    production_requirement_status: str = "complete",
) -> dict[str, object]:
    """Build a public-beta evidence document for release-mode tests."""
    schema_ref = {
        **file_ref(root, "release-artifacts/schema/public-beta-evidence.schema.json", "{}\n"),
        "category": "public_beta_evidence_schema",
    }
    requirements: list[dict[str, object]] = []
    for requirement_id in evidence_checker.PUBLIC_BETA_REQUIREMENTS:
        requirements.append(
            evidence_row(root, requirement_id, evidence_checker.PUBLIC_BETA_PHASE, public_beta_requirement_status)
        )
    for requirement_id in evidence_checker.PRODUCTION_REQUIREMENTS:
        requirements.append(
            evidence_row(root, requirement_id, evidence_checker.PRODUCTION_PHASE, production_requirement_status)
        )

    return {
        "schema_version": evidence_checker.EVIDENCE_SCHEMA,
        "release_version": "v0.1.0-release-mode-fixture",
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "1" * 40,
            "source_dirty": False,
            "ci_run": "release-mode-fixture",
        },
        "status": {
            evidence_checker.PUBLIC_BETA_PHASE: public_beta_status,
            evidence_checker.PRODUCTION_PHASE: production_status,
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
        "operator_notes": "Release-mode fixture contains no secrets.",
    }


class ReleaseModeTests(unittest.TestCase):
    """Release-mode evidence gate behavior."""

    def test_rejects_unknown_phase_alias(self) -> None:
        """Phase normalization rejects aliases outside the release-mode allowlist."""
        with self.assertRaisesRegex(checker.ReleaseModeError, "phase must be one of"):
            checker.normalize_phase("mainnet")

    def test_current_committed_public_beta_release_mode_fails(self) -> None:
        """The committed blocked baseline is structurally valid but not release-ready."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root), "--phase", "public-beta"])

        self.assertEqual(result, 1)

    def test_complete_public_beta_fixture_passes(self) -> None:
        """Public-beta release mode passes when public-beta evidence is ready."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="ready",
                    production_status="blocked",
                    production_requirement_status="missing",
                ),
            )

            checker.validate_release_mode(path, root, "public-beta")

    def test_production_requires_public_beta_and_production_readiness(self) -> None:
        """Production release mode fails if public-beta evidence is still blocked."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="blocked",
                    production_status="ready",
                    public_beta_requirement_status="missing",
                ),
            )

            with self.assertRaisesRegex(checker.ReleaseModeError, "status.public_beta"):
                checker.validate_release_mode(path, root, "production-release")

    def test_complete_production_fixture_passes(self) -> None:
        """Production release mode passes only when both phases are ready."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="ready",
                    production_status="ready",
                ),
            )

            checker.validate_release_mode(path, root, "production-release")

    def test_accepted_risk_rows_can_satisfy_release_mode(self) -> None:
        """Explicit accepted-risk rows are permitted by release mode."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="ready",
                    production_status="blocked",
                    public_beta_requirement_status="accepted_risk",
                    production_requirement_status="missing",
                ),
            )

            checker.validate_release_mode(path, root, "public_beta")

    def test_pending_requirement_blocks_release_mode(self) -> None:
        """Pending requirement rows are listed as release-mode blockers."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="blocked",
                    production_status="blocked",
                    public_beta_requirement_status="pending",
                    production_requirement_status="missing",
                ),
            )

            with self.assertRaisesRegex(checker.ReleaseModeError, "external_audit_report"):
                checker.validate_release_mode(path, root, "public-beta")


if __name__ == "__main__":
    unittest.main()
