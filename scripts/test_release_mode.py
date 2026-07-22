#!/usr/bin/env python3
"""Focused tests for release-mode evidence gates."""

from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from datetime import date
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


def write_core_size_artifact(
    root: Path,
    *,
    runtime_margin: object = checker.PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES,
) -> Path:
    """Write the minimal checksum-covered Core size artifact for release mode."""
    path = root / checker.DEFAULT_ABI_CHECKSUMS
    runtime_size: object
    if isinstance(runtime_margin, bool) or not isinstance(runtime_margin, int):
        runtime_size = 0
    else:
        runtime_size = checker.EIP170_RUNTIME_LIMIT_BYTES - runtime_margin
    write_json(
        path,
        {
            "schema_version": checker.ABI_CHECKSUMS_SCHEMA,
            "contracts": {
                checker.STREAM_CORE_NAME: {
                    "source": checker.STREAM_CORE_SOURCE,
                    "deployed_bytecode_size_bytes": runtime_size,
                    "eip170_runtime_limit_bytes": checker.EIP170_RUNTIME_LIMIT_BYTES,
                    "deployed_runtime_margin_bytes": runtime_margin,
                }
            },
        },
    )
    return path


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
            "accepted_at": "2026-01-01",
            "expires_at": "2099-12-31",
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
    write_core_size_artifact(root)
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


def replace_requirement_status(
    root: Path,
    document: dict[str, object],
    requirement_id: str,
    status: str,
) -> dict[str, object]:
    """Replace one requirement row in a release-mode fixture."""
    requirements = document["requirements"]
    assert isinstance(requirements, list)
    for index, requirement in enumerate(requirements):
        assert isinstance(requirement, dict)
        if requirement["id"] != requirement_id:
            continue
        replacement = evidence_row(root, requirement_id, requirement["phase"], status)
        requirements[index] = replacement
        return replacement
    raise AssertionError(f"missing release-mode fixture requirement: {requirement_id}")


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

    def test_production_core_headroom_at_deployment_target_passes(self) -> None:
        """The exact normative 2,000-byte production margin is sufficient."""
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
            write_core_size_artifact(
                root,
                runtime_margin=checker.PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES,
            )

            checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_below_deployment_target_blocks(self) -> None:
        """A 1,999-byte Core margin fails the governing deployment rule."""
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
            write_core_size_artifact(root, runtime_margin=1_999)

            with self.assertRaisesRegex(
                checker.ReleaseModeError, "below the production deployment minimum"
            ):
                checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_missing_artifact_fails_closed(self) -> None:
        """Production mode rejects a missing checksum-covered size artifact."""
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
            (root / checker.DEFAULT_ABI_CHECKSUMS).unlink()

            with self.assertRaisesRegex(
                evidence_checker.PublicBetaEvidenceError, "missing required file"
            ):
                checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_missing_field_fails_closed(self) -> None:
        """Production mode rejects an omitted Core size field."""
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
            artifact_path = root / checker.DEFAULT_ABI_CHECKSUMS
            artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
            del artifact["contracts"][checker.STREAM_CORE_NAME][
                "deployed_runtime_margin_bytes"
            ]
            write_json(artifact_path, artifact)

            with self.assertRaisesRegex(
                checker.ReleaseModeError,
                "deployed_runtime_margin_bytes must be an integer",
            ):
                checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_malformed_field_fails_closed(self) -> None:
        """Production mode rejects stringified numeric artifact fields."""
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
            artifact_path = root / checker.DEFAULT_ABI_CHECKSUMS
            artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
            artifact["contracts"][checker.STREAM_CORE_NAME][
                "deployed_bytecode_size_bytes"
            ] = "22576"
            write_json(artifact_path, artifact)

            with self.assertRaisesRegex(
                checker.ReleaseModeError,
                "deployed_bytecode_size_bytes must be an integer",
            ):
                checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_boolean_field_fails_closed(self) -> None:
        """Production mode does not accept JSON booleans as integer margins."""
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
            write_core_size_artifact(root, runtime_margin=True)

            with self.assertRaisesRegex(
                checker.ReleaseModeError,
                "deployed_runtime_margin_bytes must be an integer",
            ):
                checker.validate_release_mode(path, root, "production-release")

    def test_production_core_headroom_invalid_metadata_fails_closed(self) -> None:
        """Production mode rejects invalid Core artifact identity and arithmetic."""
        cases: tuple[tuple[str, tuple[str, ...], object, str], ...] = (
            (
                "wrong_schema",
                ("schema_version",),
                "6529stream.abi-checksums.v0",
                "schema_version must be",
            ),
            (
                "wrong_core_source",
                ("contracts", checker.STREAM_CORE_NAME, "source"),
                "smart-contracts/NotStreamCore.sol",
                "StreamCore.source must be",
            ),
            (
                "wrong_eip170_limit",
                (
                    "contracts",
                    checker.STREAM_CORE_NAME,
                    "eip170_runtime_limit_bytes",
                ),
                checker.EIP170_RUNTIME_LIMIT_BYTES - 1,
                "eip170_runtime_limit_bytes must be 24576",
            ),
            (
                "inconsistent_margin",
                (
                    "contracts",
                    checker.STREAM_CORE_NAME,
                    "deployed_runtime_margin_bytes",
                ),
                checker.PRODUCTION_CORE_MIN_RUNTIME_MARGIN_BYTES + 1,
                "expected 2000 from the EIP-170 limit and runtime size",
            ),
            (
                "negative_runtime_size",
                (
                    "contracts",
                    checker.STREAM_CORE_NAME,
                    "deployed_bytecode_size_bytes",
                ),
                -1,
                "deployed_bytecode_size_bytes must be non-negative",
            ),
        )

        for case_name, field_path, invalid_value, expected_error in cases:
            with self.subTest(case=case_name), tempfile.TemporaryDirectory() as temp_dir:
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
                artifact_path = root / checker.DEFAULT_ABI_CHECKSUMS
                artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
                target: object = artifact
                for field in field_path[:-1]:
                    assert isinstance(target, dict)
                    target = target[field]
                assert isinstance(target, dict)
                target[field_path[-1]] = invalid_value
                write_json(artifact_path, artifact)

                with self.assertRaisesRegex(checker.ReleaseModeError, expected_error):
                    checker.validate_release_mode(path, root, "production-release")

    def test_public_beta_does_not_require_core_headroom_artifact(self) -> None:
        """The production headroom rule does not broaden the public-beta gate."""
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
            (root / checker.DEFAULT_ABI_CHECKSUMS).unlink()

            checker.validate_release_mode(path, root, "public-beta")

    def test_active_accepted_risk_can_satisfy_a_waivable_requirement(self) -> None:
        """An active risk acceptance remains valid for a non-critical row."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            document = evidence_document(
                root,
                public_beta_status="ready",
                production_status="blocked",
                production_requirement_status="missing",
            )
            replace_requirement_status(
                root, document, "fork_deployment_rehearsal", "accepted_risk"
            )
            write_json(
                path,
                document,
            )

            checker.validate_release_mode(path, root, "public_beta")

    def test_expired_accepted_risk_blocks_release_mode(self) -> None:
        """A risk acceptance cannot satisfy release mode after its expiry date."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            document = evidence_document(
                root,
                public_beta_status="ready",
                production_status="blocked",
                production_requirement_status="missing",
            )
            requirement = replace_requirement_status(
                root, document, "fork_deployment_rehearsal", "accepted_risk"
            )
            risk_acceptance = requirement["risk_acceptance"]
            assert isinstance(risk_acceptance, dict)
            risk_acceptance["expires_at"] = "2026-07-20"
            write_json(path, document)

            with self.assertRaisesRegex(checker.ReleaseModeError, "expired on '2026-07-20'"):
                checker.validate_release_mode(
                    path, root, "public_beta", as_of=date(2026, 7, 21)
                )

    def test_future_accepted_risk_blocks_release_mode(self) -> None:
        """A risk acceptance cannot satisfy release mode before acceptance."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            document = evidence_document(
                root,
                public_beta_status="ready",
                production_status="blocked",
                production_requirement_status="missing",
            )
            requirement = replace_requirement_status(
                root, document, "fork_deployment_rehearsal", "accepted_risk"
            )
            risk_acceptance = requirement["risk_acceptance"]
            assert isinstance(risk_acceptance, dict)
            risk_acceptance["accepted_at"] = "2026-07-22"
            write_json(path, document)

            with self.assertRaisesRegex(checker.ReleaseModeError, "not active until"):
                checker.validate_release_mode(
                    path, root, "public_beta", as_of=date(2026, 7, 21)
                )

    def test_inverted_accepted_risk_window_blocks_release_mode(self) -> None:
        """Risk-acceptance expiry cannot precede the acceptance date."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            document = evidence_document(
                root,
                public_beta_status="ready",
                production_status="blocked",
                production_requirement_status="missing",
            )
            requirement = replace_requirement_status(
                root, document, "fork_deployment_rehearsal", "accepted_risk"
            )
            risk_acceptance = requirement["risk_acceptance"]
            assert isinstance(risk_acceptance, dict)
            risk_acceptance["accepted_at"] = "2026-07-22"
            risk_acceptance["expires_at"] = "2026-07-20"
            write_json(path, document)

            with self.assertRaisesRegex(checker.ReleaseModeError, "invalid risk-acceptance window"):
                checker.validate_release_mode(
                    path, root, "public_beta", as_of=date(2026, 7, 21)
                )

    def test_external_audit_cannot_be_accepted_as_risk(self) -> None:
        """Public-beta release mode requires completed external-audit evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            document = evidence_document(
                root,
                public_beta_status="ready",
                production_status="blocked",
                production_requirement_status="missing",
            )
            replace_requirement_status(
                root, document, "external_audit_report", "accepted_risk"
            )
            write_json(path, document)

            with self.assertRaisesRegex(checker.ReleaseModeError, "external_audit_report"):
                checker.validate_release_mode(path, root, "public-beta")

    def test_production_requirements_cannot_be_accepted_as_risk(self) -> None:
        """Every production evidence requirement is non-waivable."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / checker.DEFAULT_EVIDENCE
            write_json(
                path,
                evidence_document(
                    root,
                    public_beta_status="ready",
                    production_status="ready",
                    production_requirement_status="accepted_risk",
                ),
            )

            with self.assertRaisesRegex(checker.ReleaseModeError, "production_signatures"):
                checker.validate_release_mode(path, root, "production-release")

    def test_workflow_requires_protected_default_branch_and_full_gate(self) -> None:
        """The manual workflow rejects unsafe refs and runs the aggregate checker."""
        repo_root = Path(__file__).resolve().parents[1]
        workflow = (repo_root / ".github/workflows/release-mode.yml").read_text(
            encoding="utf-8"
        )
        self.assertIn("github.event.repository.default_branch", workflow)
        self.assertIn("github.ref_protected", workflow)
        self.assertIn("bash scripts/check.sh", workflow)

        makefile = (repo_root / "Makefile").read_text(encoding="utf-8")
        self.assertIn("release-mode-public-beta-check: check", makefile)
        self.assertIn("release-mode-production-release-check: check", makefile)

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
