#!/usr/bin/env python3
"""Focused tests for signer custody readiness validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_signer_custody_readiness.py")
SPEC = importlib.util.spec_from_file_location("check_signer_custody_readiness", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

REPO_ROOT = Path(__file__).resolve().parents[1]
COMMITTED_TEMPLATE = (
    "release-artifacts/signer-custody-readiness/"
    "signer-custody-readiness-template.json"
)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write deterministic JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def file_ref(root: Path, relative_path: str, content: str | None = None) -> dict[str, str]:
    """Create or hash a retained file reference."""
    path = root / relative_path
    if content is not None:
        write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def valid_evidence(
    root: Path,
    *,
    record_type: str = "evidence",
    environment: str = "testnet",
    signer_type: str = "EOA",
) -> dict[str, object]:
    """Build valid signer custody readiness evidence."""
    schema_ref = file_ref(
        root,
        "release-artifacts/schema/signer-custody-readiness.schema.json",
        '{"schema_version":"test"}\n',
    )
    transcript_ref = file_ref(
        root,
        "release-artifacts/signer-custody-readiness/readiness-transcript.txt",
        "sanitized readiness transcript\n",
    )
    runbook_ref = file_ref(
        root,
        "docs/signer-custody-readiness.md",
        "# Signer Custody Readiness\n",
    )
    incident_ref = file_ref(
        root,
        "docs/incident-response.md",
        "# Incident Response\n",
    )
    approval_ref = file_ref(
        root,
        "release-artifacts/signer-custody-readiness/custody-approval.txt",
        "reviewed custody approval\n",
    )
    attestation_ref = file_ref(
        root,
        "release-artifacts/signer-custody-readiness/signer-service-attestation.txt",
        "reviewed signer service attestation\n",
    )
    drill_ref = file_ref(
        root,
        "release-artifacts/signer-custody-readiness/rotation-drill.txt",
        "reviewed rotation and revocation drill\n",
    )
    monitoring_ref = file_ref(
        root,
        "release-artifacts/signer-custody-readiness/monitoring-runbook.txt",
        "reviewed monitoring runbook\n",
    )
    review_status = "reviewed" if record_type == "evidence" else "template"
    approval_status = "approved" if review_status == "reviewed" else "template"
    local = environment == "local"
    chain_ids = {
        "local": 31337,
        "fork": 1,
        "testnet": 11155111,
        "mainnet": 1,
        "production": 1,
    }
    retained_artifacts = [
        {**schema_ref, "category": "signer_custody_schema"},
        {**transcript_ref, "category": "readiness_transcript"},
    ]
    if not local:
        retained_artifacts.extend(
            [
                {**approval_ref, "category": "custody_approval"},
                {**attestation_ref, "category": "signer_service_attestation"},
                {**drill_ref, "category": "rotation_revocation_drill"},
                {**monitoring_ref, "category": "monitoring_runbook"},
            ]
        )

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "signer-custody-readiness",
        "record_type": record_type,
        "review_status": review_status,
        "environment": environment,
        "chain_id": chain_ids[environment],
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "signer_identity": {
            "signer_type": "local_placeholder" if local else signer_type,
            "expected_signer": "0x0000000000000000000000000000000000006532",
            "signer_epoch": 1,
            "signer_epoch_source": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "StreamDrops.signerEpoch() on retained deployment",
            "signer_manager": "0x0000000000000000000000000000000000000004",
            "signer_manager_type": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "safe",
            "erc1271_support_status": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else ("supported" if signer_type == "ERC1271" else "not_applicable"),
            "erc1271_support_detail": {
                "rationale": checker.LOCAL_PLACEHOLDER_STATUS
                if local
                else (
                    "Contract signer support validated"
                    if signer_type == "ERC1271"
                    else "EOA signer selected; ERC-1271 not applicable"
                ),
                "evidence_reference": checker.LOCAL_PLACEHOLDER_STATUS
                if local
                else "retained signer custody readiness transcript",
            },
            "signer_service_class": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "managed_signer",
        },
        "custody": {
            "custody_owner": "TBD" if local else "release-operations",
            "custody_status": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "documented",
            "custody_system": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "approved external signer service",
            "approval_workflow_reference": "TBD" if local else "OPS-SIGNER-001",
            "key_material_location": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "external_custody_only",
            "separation_of_duties": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "complete",
        },
        "lifecycle": {
            "rotation_status": checker.LOCAL_PLACEHOLDER_STATUS if local else "complete",
            "revocation_status": checker.LOCAL_PLACEHOLDER_STATUS if local else "complete",
            "compromise_response_status": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "complete",
            "signer_epoch_rotation_tested": not local,
            "per_drop_cancellation_tested": not local,
            "last_rotation_drill": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "2026-06-13T00:00:00Z",
            "last_revocation_drill": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "2026-06-13T00:00:00Z",
        },
        "operations": {
            "monitoring_status": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "validated",
            "runbook": runbook_ref,
            "alerting_reference": "TBD" if local else "ops-alert-policy",
            "incident_response_runbook": incident_ref,
            "signer_service_integration_status": checker.LOCAL_PLACEHOLDER_STATUS
            if local
            else "validated",
        },
        "review": {
            "owner": "release-operator" if not local else "TBD",
            "reviewer": "release-reviewer" if review_status == "reviewed" else "TBD",
            "approval_status": approval_status,
            "approval_reference": "review ticket" if not local else "TBD",
            "reviewed_at": "2026-06-13T00:00:00Z"
            if review_status == "reviewed"
            else checker.LOCAL_PLACEHOLDER_STATUS,
        },
        "retained_artifacts": retained_artifacts,
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "api_key",
                "rpc_url",
                "hsm_credentials",
                "raw_signature",
                "unreleased_drop_payload",
            ],
        },
        "template_notice": "Template only. This file is not completion evidence.",
        "operator_notes": "No-secret test fixture.",
    }


class SignerCustodyReadinessTests(unittest.TestCase):
    """Checker behavior for signer custody readiness evidence metadata."""

    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT), COMMITTED_TEMPLATE])

        self.assertEqual(result, 0)

    def test_accepts_reviewed_non_local_eoa_evidence(self) -> None:
        """Reviewed non-local EOA evidence can satisfy the readiness format."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, valid_evidence(root))

            checker.validate_evidence(path, root)

    def test_accepts_reviewed_non_local_erc1271_evidence(self) -> None:
        """Contract signer evidence records explicit ERC-1271 support."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, valid_evidence(root, signer_type="ERC1271"))

            checker.validate_evidence(path, root)

    def test_rejects_missing_required_field(self) -> None:
        """Exact-key validation catches missing required fields."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            del evidence["custody"]["custody_owner"]
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "missing required field"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_reviewed_tbd_reviewer(self) -> None:
        """Reviewed evidence needs a named reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["reviewer"] = "TBD"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "review.reviewer"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_reviewed_tbd_owner(self) -> None:
        """Reviewed evidence needs a named owner."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["owner"] = "TBD"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "review.owner"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_reviewed_placeholder_approval_reference(self) -> None:
        """Reviewed evidence needs a non-placeholder approval reference."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["approval_reference"] = "not_available_local"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "approval_reference"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_reviewed_invalid_reviewed_at(self) -> None:
        """Reviewed timestamps must be machine-readable date-times."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["reviewed_at"] = "yesterday"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "RFC3339"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_whitespace_only_required_string(self) -> None:
        """Whitespace-only strings do not satisfy required text fields."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["custody"]["custody_owner"] = "   "
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "custody_owner"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_non_local_placeholder_status(self) -> None:
        """Non-local readiness cannot use local placeholder signer-service state."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operations"][
                "signer_service_integration_status"
            ] = checker.LOCAL_PLACEHOLDER_STATUS
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "non-local"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_non_local_placeholder_erc1271_detail(self) -> None:
        """Non-local ERC-1271 rationale remains machine-checkable."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["signer_identity"]["erc1271_support_detail"][
                "rationale"
            ] = checker.LOCAL_PLACEHOLDER_STATUS
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "erc1271_support_detail"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_stale_retained_hash(self) -> None:
        """Retained artifact hashes must match file content."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"][0]["sha256"] = "sha256:" + "0" * 64
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "sha256 mismatch"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_path_escape(self) -> None:
        """Retained artifact paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operations"]["runbook"]["path"] = "../outside.md"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "stay inside"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_negative_signer_epoch(self) -> None:
        """Signer epochs are non-negative readiness evidence."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["signer_identity"]["signer_epoch"] = -1
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError,
                "signer_identity.signer_epoch must be zero or greater",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_invalid_status_enum(self) -> None:
        """Status fields must stay in the documented enum set."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["lifecycle"]["rotation_status"] = "maybe"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "must be one of"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_production_without_required_drills(self) -> None:
        """Production readiness needs rotation and cancellation drills."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root, environment="production")
            evidence["lifecycle"]["per_drop_cancellation_tested"] = False
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "production"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/signer-custody-readiness/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.SignerCustodyReadinessError, "secret-like"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_key(self) -> None:
        """Secret-shaped keys cannot be committed."""
        with self.assertRaisesRegex(
            checker.SignerCustodyReadinessError, "secret-like key"
        ):
            checker.scan_for_secret_like_data({"signer_secret": "do-not-commit"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
