#!/usr/bin/env python3
"""Focused tests for drop authorization signing evidence validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_drop_authorization_signing_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_drop_authorization_signing_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

REPO_ROOT = Path(__file__).resolve().parents[1]
PAYLOAD_FIXTURE = (
    REPO_ROOT
    / "test"
    / "fixtures"
    / "drop-authorization"
    / "payload-generator"
    / "fixed-price-output.json"
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


def seed_payload(root: Path) -> tuple[dict[str, object], dict[str, str]]:
    """Copy the committed fixed-price payload into a temporary repository."""
    relative_path = "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json"
    payload = json.loads(PAYLOAD_FIXTURE.read_text(encoding="utf-8"))
    write_json(root / relative_path, payload)
    return payload, file_ref(root, relative_path)


def payload_summary(payload: dict[str, object], payload_ref: dict[str, str]) -> dict[str, object]:
    """Build the evidence payload summary from a generated payload."""
    typed_data = payload["typed_data"]
    domain = typed_data["domain"]
    message = typed_data["message"]
    derived = payload["derived"]
    return {
        "payload_file": payload_ref,
        "payload_schema_version": checker.PAYLOAD_SCHEMA,
        "payload_kind": "fixed_price",
        "typed_data_primary_type": typed_data["primaryType"],
        "domain": {
            "name": domain["name"],
            "version": domain["version"],
            "chain_id": domain["chainId"],
            "verifying_contract": domain["verifyingContract"],
        },
        "message": {
            "drop_id": message["dropId"],
            "poster": message["poster"],
            "recipient": message["recipient"],
            "payer": message["payer"],
            "collection_id": int(message["collectionId"]),
            "sale_mode": message["saleMode"],
            "signer_epoch": int(message["signerEpoch"]),
            "nonce": int(message["nonce"]),
            "deadline": int(message["deadline"]),
        },
        "derived": {
            "signer": derived["signer"],
            "drop_id": derived["drop_id"],
            "token_data_hash": derived["token_data_hash"],
            "domain_separator": derived["domain_separator"],
            "struct_hash": derived["struct_hash"],
            "digest": derived["digest"],
        },
    }


def signature_result(status: str) -> dict[str, str]:
    """Return a signature metadata object for the requested status."""
    if status == "signed":
        return {
            "status": "signed",
            "signature_format": "erc191_or_erc1271_result",
            "signature_hash": "sha256:" + "a" * 64,
            "verification_status": "verified",
            "verification_command": "cast wallet verify --data-hash <digest> <signature>",
            "returned_at": "2026-06-13T00:00:00Z",
            "evidence_note": "Signature retained outside the repository.",
        }
    return {
        "status": status,
        "signature_format": checker.LOCAL_PLACEHOLDER_STATUS,
        "signature_hash": status,
        "verification_status": status,
        "verification_command": checker.LOCAL_PLACEHOLDER_STATUS,
        "returned_at": checker.LOCAL_PLACEHOLDER_STATUS,
        "evidence_note": f"{status} signature result",
    }


def valid_evidence(
    root: Path,
    *,
    record_type: str = "evidence",
    environment: str = "testnet",
    signature_status: str = "pending",
) -> dict[str, object]:
    """Build valid evidence metadata."""
    payload, payload_ref = seed_payload(root)
    schema_ref = file_ref(
        root,
        "release-artifacts/schema/drop-authorization-signing-evidence.schema.json",
        '{"schema_version":"test"}\n',
    )
    transcript_ref = file_ref(
        root,
        "release-artifacts/drop-authorization-signing/retained-transcript.txt",
        "sanitized transcript\n",
    )
    approval_ref = file_ref(
        root,
        "release-artifacts/drop-authorization-signing/signing-approval.txt",
        "reviewed approval\n",
    )
    verification_ref = file_ref(
        root,
        "release-artifacts/drop-authorization-signing/signature-verification.txt",
        "verified signature\n",
    )
    review_status = "reviewed" if record_type == "evidence" else "template"
    approval_status = "approved" if review_status == "reviewed" else "template"
    signer_type = "EOA" if environment != "local" else "local_placeholder"
    custody_status = "documented" if environment != "local" else checker.LOCAL_PLACEHOLDER_STATUS
    lifecycle_status = "active" if environment != "local" else checker.LOCAL_PLACEHOLDER_STATUS
    signature = signature_result(signature_status)
    retained_artifacts = [
        {**schema_ref, "category": "drop_signing_schema"},
        {**payload_ref, "category": "payload_output"},
        {**transcript_ref, "category": "retained_transcript"},
    ]
    if environment != "local":
        retained_artifacts.append({**approval_ref, "category": "signing_approval"})
        retained_artifacts.append({**transcript_ref, "category": "signing_transcript"})
    if signature_status == "signed":
        retained_artifacts.append({**verification_ref, "category": "signature_verification"})

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "drop-authorization-signing-evidence",
        "record_type": record_type,
        "review_status": review_status,
        "environment": environment,
        "chain_id": payload["typed_data"]["domain"]["chainId"],
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "payload": payload_summary(payload, payload_ref),
        "signing_identity": {
            "signer_type": signer_type,
            "signer": payload["derived"]["signer"],
            "signer_epoch": int(payload["typed_data"]["message"]["signerEpoch"]),
            "custody_status": custody_status,
            "custody_reference": "signer custody evidence reference",
            "signer_lifecycle_status": lifecycle_status,
            "signer_service": "approved signer service",
            "signer_epoch_source": "contract signerEpoch view",
        },
        "signature": signature,
        "review": {
            "owner": "release-operator",
            "reviewer": "release-reviewer" if review_status == "reviewed" else "TBD",
            "approval_status": approval_status,
            "approval_reference": "review ticket",
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
                "raw_signature",
                "unreleased_drop_payload",
            ],
        },
        "template_notice": "Template only. This file is not completion evidence.",
        "operator_notes": "No-secret test fixture.",
    }


class DropAuthorizationSigningEvidenceTests(unittest.TestCase):
    """Checker behavior for drop authorization signing evidence metadata."""

    def test_accepts_committed_template(self) -> None:
        """The committed template satisfies the checker."""
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(REPO_ROOT)])

        self.assertEqual(result, 0)

    def test_accepts_reviewed_non_local_pending_evidence(self) -> None:
        """Reviewed non-local evidence can be pending while public beta remains blocked."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, valid_evidence(root, signature_status="pending"))

            checker.validate_evidence(path, root)

    def test_accepts_signed_evidence_with_verification_artifact(self) -> None:
        """Signed evidence requires verification metadata and retained proof."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, valid_evidence(root, signature_status="signed"))

            checker.validate_evidence(path, root)

    def test_rejects_reviewed_tbd_reviewer(self) -> None:
        """Reviewed evidence needs a named reviewer."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["review"]["reviewer"] = "TBD"
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "reviewer must be set"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_non_local_placeholder_signature(self) -> None:
        """Non-local evidence cannot use local placeholder signature state."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root, signature_status=checker.LOCAL_PLACEHOLDER_STATUS)
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "non-local"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_evidence_record_with_template_review_status(self) -> None:
        """Evidence records cannot carry template review_status."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["record_type"] = "evidence"
            evidence["review_status"] = "template"
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError,
                "evidence records cannot use template review_status",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_stale_retained_hash(self) -> None:
        """Retained artifact hashes must match file content."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"][0]["sha256"] = "sha256:" + "0" * 64
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "sha256 mismatch"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_path_escape(self) -> None:
        """Retained artifact paths must stay inside the repository."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"][0]["path"] = "../outside.txt"
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "stay inside"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_payload_digest_mismatch(self) -> None:
        """Evidence digest fields must match the generated payload."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["payload"]["derived"]["digest"] = "0x" + "0" * 64
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError,
                "payload.derived.digest mismatch",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_negative_payload_numeric_fields(self) -> None:
        """Evidence payload numeric fields follow the schema minimums."""
        for field in ("collection_id", "signer_epoch", "nonce", "deadline"):
            with self.subTest(field=field), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                evidence = valid_evidence(root)
                evidence["payload"]["message"][field] = -1
                path = root / "release-artifacts/drop-authorization-signing/example.json"
                write_json(path, evidence)

                with self.assertRaisesRegex(
                    checker.DropAuthorizationSigningEvidenceError,
                    f"payload.message.{field} must be zero or greater",
                ):
                    checker.validate_evidence(path, root)

    def test_rejects_production_payload_file(self) -> None:
        """Signing evidence must point at no-secret non-production payload files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            payload_path = root / evidence["payload"]["payload_file"]["path"]
            payload = json.loads(payload_path.read_text(encoding="utf-8"))
            payload["no_secret_policy"]["production_payload"] = True
            write_json(payload_path, payload)
            evidence["payload"]["payload_file"]["sha256"] = checker.file_sha256(payload_path)
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError,
                "production payload",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_signer_epoch_mismatch(self) -> None:
        """Signer epoch evidence must match the payload."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["signing_identity"]["signer_epoch"] = 999
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError,
                "signing_identity.signer_epoch",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_negative_signing_identity_signer_epoch(self) -> None:
        """Signer identity epoch follows the schema minimum."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["signing_identity"]["signer_epoch"] = -1
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError,
                "signing_identity.signer_epoch must be zero or greater",
            ):
                checker.validate_evidence(path, root)

    def test_rejects_production_pending_signature(self) -> None:
        """Production evidence must be reviewed, approved, and signed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root, environment="production", signature_status="pending")
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "production"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_value(self) -> None:
        """Secret-shaped values cannot be committed."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/drop-authorization-signing/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.DropAuthorizationSigningEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path, root)

    def test_rejects_secret_like_key(self) -> None:
        """Secret-shaped keys cannot be committed."""
        with self.assertRaisesRegex(
            checker.DropAuthorizationSigningEvidenceError, "secret-like key"
        ):
            checker.scan_for_secret_like_data({"client_secret": "do-not-commit"})


if __name__ == "__main__":
    unittest.main(verbosity=2)
