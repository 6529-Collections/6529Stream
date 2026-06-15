#!/usr/bin/env python3
"""Focused tests for admin ceremony evidence validation."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_admin_ceremony_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_admin_ceremony_evidence", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

REPO_ROOT = Path(__file__).resolve().parents[1]
COMMITTED_TEMPLATE = "deployments/admin-ceremony/admin-ceremony-evidence-template.json"


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


def role_row(role: str, target: str, account: str) -> dict[str, str]:
    """Build a reviewed role-grant row."""
    return {
        "role": role,
        "target": target,
        "account": account,
        "status": "complete",
        "tx": "0x" + "a" * 64,
        "rationale": "grant confirmed by post-state view",
    }


def valid_evidence(root: Path) -> dict[str, object]:
    """Build valid reviewed admin ceremony evidence."""
    manifest = file_ref(
        root,
        "deployments/examples/sepolia-6529stream-v0.1.0-001.json",
        '{"manifest_schema_version":"6529stream.deployment-manifest.v1"}\n',
    )
    address_book = file_ref(
        root,
        "deployments/address-books/sepolia-6529stream-v0.1.0-001.json",
        '{"schema_version":"6529stream.address-book.v1"}\n',
    )
    release_manifest = file_ref(
        root,
        "release-artifacts/latest/release-manifest.json",
        '{"schema_version":"6529stream.release-manifest.v1"}\n',
    )
    checksum_bundle = file_ref(
        root,
        "release-artifacts/latest/SHA256SUMS",
        "abc  retained\n",
    )
    schema_ref = file_ref(
        root,
        "deployments/schema/admin-ceremony-evidence.schema.json",
        '{"schema_version":"test"}\n',
    )
    transcript_ref = file_ref(
        root,
        "deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md",
        "sanitized admin ceremony retained artifact\n",
    )
    reviewed_artifacts = [
        {
            **file_ref(
                root,
                f"deployments/admin-ceremony/{category}.txt",
                f"sanitized {category} evidence\n",
            ),
            "category": category,
        }
        for category in (
            "ownership_transfer_or_blocker",
            "role_grants_and_revocations",
            "signer_setup",
            "pause_and_emergency_setup",
            "post_state_views",
            "verification_status",
            "approval_record",
        )
    ]

    admin_safe = "0x0000000000000000000000000000000000001002"
    pause_guardian = "0x0000000000000000000000000000000000001003"
    emergency_recipient = "0x0000000000000000000000000000000000001004"
    drop_signer = "0x0000000000000000000000000000000000001005"

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "admin-ceremony-sepolia-reviewed",
        "record_type": "evidence",
        "review_status": "reviewed",
        "environment": "testnet",
        "chain_id": 11155111,
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "1" * 40,
            "source_dirty": False,
            "ci_run": "https://github.com/6529-Collections/6529Stream/actions/runs/1",
        },
        "deployment": {
            "protocol_version": "0.1.0",
            "deployment_version": "sepolia-6529stream-v0.1.0-001",
            "deployment_manifest": manifest,
            "address_book": address_book,
            "release_manifest": release_manifest,
            "checksum_bundle": checksum_bundle,
        },
        "participants": {
            "deployer": "0x0000000000000000000000000000000000001001",
            "admin_safe": admin_safe,
            "pause_guardian": pause_guardian,
            "emergency_recipient": emergency_recipient,
            "drop_signer": drop_signer,
            "signer_manager": admin_safe,
        },
        "ownership": {
            "status": "complete",
            "owner_before": "0x0000000000000000000000000000000000001001",
            "owner_after": admin_safe,
            "transfer_tx": "0x" + "b" * 64,
            "temporary_deployer_admin_revoked": "complete",
            "rationale": "Safe owns privileged root and deployer grant is revoked",
        },
        "roles": {
            "global_admins": [role_row("global_admin", "StreamAdmins", admin_safe)],
            "function_admins": [
                role_row("unpause_admin", "StreamCore pause surfaces", admin_safe)
            ],
            "signer_managers": [
                role_row("signer_manager", "StreamDrops signer lifecycle", admin_safe)
            ],
            "pause_guardians": [
                role_row("pause_guardian", "StreamAdmins pause surfaces", pause_guardian)
            ],
            "unpause_admins": [
                role_row("unpause_admin", "StreamAdmins pause surfaces", admin_safe)
            ],
        },
        "signer_setup": {
            "status": "complete",
            "drop_signer": drop_signer,
            "signer_epoch": 1,
            "signer_manager": admin_safe,
            "rotation_or_cancellation_test": "complete",
            "tx": "0x" + "c" * 64,
            "rationale": "signer manager and epoch checked after setup",
        },
        "pause_and_emergency": {
            "status": "complete",
            "mint_pause_admin": pause_guardian,
            "bid_pause_admin": pause_guardian,
            "settlement_pause_admin": pause_guardian,
            "withdrawal_pause_policy": "withdrawals remain available unless path is unsafe",
            "emergency_recipient": emergency_recipient,
            "tx": "0x" + "d" * 64,
            "rationale": "pause and emergency views checked after setup",
        },
        "verification": {
            "contract_verification": "complete",
            "source_verification_inputs": "complete",
            "explorer_verification": "complete",
            "post_state_views": "complete",
            "rationale": "explorer and post-state checks retained",
        },
        "review": {
            "owner": "release-operator",
            "reviewer": "release-reviewer",
            "approval_status": "approved",
            "approval_reference": "https://github.com/6529-Collections/6529Stream/pull/1",
            "reviewed_at": "2026-06-14T00:00:00Z",
        },
        "retained_artifacts": [
            {**schema_ref, "category": "admin_ceremony_schema"},
            {**transcript_ref, "category": "admin_ceremony_retained_artifact_template"},
            *reviewed_artifacts,
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "safe_signing_secret",
                "signer_service_credentials",
                "signer_secret",
                "password",
                "client_secret",
                "api_key",
                "rpc_url",
                "private_rpc_url",
                "bearer_token",
                "session_cookie",
                "raw_signature",
                "unreleased_drop_payload",
            ],
        },
        "template_notice": "Reviewed evidence, not a template.",
        "operator_notes": "No-secret reviewed fixture.",
    }


class AdminCeremonyEvidenceTests(unittest.TestCase):
    """Checker behavior for admin ceremony evidence metadata."""

    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT), COMMITTED_TEMPLATE])

        self.assertEqual(result, 0)

    def test_accepts_reviewed_evidence(self) -> None:
        """Reviewed evidence can pass with retained file hashes."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "deployments/admin-ceremony/reviewed.json"
            write_json(path, valid_evidence(root))

            checker.validate_evidence(path, root)

    def test_reviewed_placeholder_fails(self) -> None:
        """Reviewed evidence cannot retain template placeholders."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["ownership"]["transfer_tx"] = "TBD"  # type: ignore[index]
            path = root / "deployments/admin-ceremony/reviewed-placeholder.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "contains placeholders",
            ):
                checker.validate_evidence(path, root)

    def test_reviewed_stale_retained_hash_fails(self) -> None:
        """Reviewed retained artifact hashes must match disk."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"][0]["sha256"] = "sha256:" + "f" * 64  # type: ignore[index]
            path = root / "deployments/admin-ceremony/stale-hash.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "stale",
            ):
                checker.validate_evidence(path, root)

    def test_reviewed_missing_ceremony_artifact_category_fails(self) -> None:
        """Reviewed evidence must retain ceremony proof categories."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"] = [  # type: ignore[index]
                item
                for item in evidence["retained_artifacts"]  # type: ignore[index]
                if item["category"] != "approval_record"
            ]
            path = root / "deployments/admin-ceremony/missing-approval.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "approval_record",
            ):
                checker.validate_evidence(path, root)

    def test_missing_privileged_role_bucket_fails(self) -> None:
        """Every privileged role bucket must be represented."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["roles"]["pause_guardians"] = []  # type: ignore[index]
            path = root / "deployments/admin-ceremony/missing-role.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "roles.pause_guardians",
            ):
                checker.validate_evidence(path, root)

    def test_path_escape_fails(self) -> None:
        """Retained artifact paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"][0]["path"] = "../schema.json"  # type: ignore[index]
            path = root / "deployments/admin-ceremony/path-escape.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "repo-relative",
            ):
                checker.validate_evidence(path, root)

    def test_secret_like_value_fails(self) -> None:
        """Secret-shaped values cannot be retained."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["approval_reference"] = "private_key=abc123"  # type: ignore[index]
            path = root / "deployments/admin-ceremony/secret.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "secret-like value",
            ):
                checker.validate_evidence(path, root)

    def test_wrong_chain_for_environment_fails(self) -> None:
        """Environment and chain ID must agree."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["chain_id"] = 1
            path = root / "deployments/admin-ceremony/wrong-chain.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "not allowed for environment testnet",
            ):
                checker.validate_evidence(path, root)

    def test_reviewed_zero_address_fails(self) -> None:
        """Reviewed privileged participant addresses cannot be zero."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["participants"]["admin_safe"] = checker.ZERO_ADDRESS  # type: ignore[index]
            path = root / "deployments/admin-ceremony/zero-address.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "zero address",
            ):
                checker.validate_evidence(path, root)

    def test_reviewed_template_placeholder_address_fails(self) -> None:
        """Reviewed evidence cannot keep numbered template addresses."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["participants"]["admin_safe"] = "0x" + "0" * 39 + "2"  # type: ignore[index]
            path = root / "deployments/admin-ceremony/template-address.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "template placeholder address",
            ):
                checker.validate_evidence(path, root)

    def test_reviewed_all_zero_commit_fails(self) -> None:
        """Reviewed evidence cannot use the template zero commit."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["source"]["git_commit"] = "0" * 40  # type: ignore[index]
            path = root / "deployments/admin-ceremony/zero-commit.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "all-zero git commit",
            ):
                checker.validate_evidence(path, root)

    def test_pending_status_needs_rationale(self) -> None:
        """Non-complete reviewed rows need a real rationale."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["ownership"]["status"] = "pending"  # type: ignore[index]
            evidence["ownership"]["rationale"] = "TBD"  # type: ignore[index]
            path = root / "deployments/admin-ceremony/pending-no-rationale.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "needs rationale",
            ):
                checker.validate_evidence(path, root)

    def test_redaction_policy_requires_secret_detector_terms(self) -> None:
        """The redaction policy must cover the documented detector terms."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["redaction_policy"]["redacted_fields"].remove("bearer_token")  # type: ignore[index]
            path = root / "deployments/admin-ceremony/missing-redaction-term.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.AdminCeremonyEvidenceError,
                "bearer_token",
            ):
                checker.validate_evidence(path, root)

    def test_default_cli_checks_every_admin_ceremony_json(self) -> None:
        """The no-arg CLI scans every committed admin ceremony JSON file."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            valid_path = root / "deployments/admin-ceremony/reviewed.json"
            invalid_path = root / "deployments/admin-ceremony/invalid.json"
            write_json(valid_path, valid_evidence(root))
            write_json(invalid_path, {"schema_version": checker.EVIDENCE_SCHEMA})
            stdout = StringIO()
            stderr = StringIO()

            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 1)
            self.assertIn("invalid.json", stderr.getvalue())

    def test_cli_reports_errors_without_traceback(self) -> None:
        """The CLI reports validation failures cleanly."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "bad.json"
            write_json(path, {"schema_version": checker.EVIDENCE_SCHEMA})
            stdout = StringIO()
            stderr = StringIO()

            with redirect_stdout(stdout), redirect_stderr(stderr):
                result = checker.main(["--repo-root", str(root), str(path)])

            self.assertEqual(result, 1)
            self.assertIn("admin ceremony evidence check failed", stderr.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
