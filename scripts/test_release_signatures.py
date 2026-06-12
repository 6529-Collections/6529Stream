#!/usr/bin/env python3
"""Focused tests for release signature evidence validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_release_signatures.py")
SPEC = importlib.util.spec_from_file_location("check_release_signatures", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def file_ref(root: Path, relative_path: str, content: str = "evidence\n") -> dict[str, str]:
    path = root / relative_path
    write_text(path, content)
    return {"path": relative_path, "sha256": checker.file_sha256(path)}


def self_ref(relative_path: str) -> dict[str, str]:
    return {
        "path": relative_path,
        "digest_status": checker.SELF_REFERENTIAL_DIGEST_STATUS,
        "reason": "Self-referential release output.",
    }


def signature_result(status: str) -> dict[str, object]:
    return {
        "status": status,
        "format": "not_applicable_local",
        "artifact_path": "not_applicable_local",
        "verification_command": "not_applicable_local",
        "evidence": [],
        "notes": f"{status} signature result",
    }


def valid_evidence(root: Path) -> dict[str, object]:
    write_text(root / "release-artifacts/latest/release-manifest.json", "{}\n")
    write_text(root / "release-artifacts/latest/SHA256SUMS", "placeholder\n")
    schema = file_ref(root, "release-artifacts/schema/release-signature-evidence.schema.json")

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "anvil-release-signature-local",
        "protocol_version": "0.1.0",
        "release_version": "v0.1.0-local",
        "network": {
            "environment": "local",
            "name": "anvil",
            "chain_id": 31337,
            "confirmation_depth": 0,
        },
        "source": {
            "repository": "https://github.com/6529-Collections/6529Stream",
            "git_commit": "0" * 40,
            "source_dirty": False,
            "ci_run": "local",
        },
        "artifacts": {
            "release_manifest": self_ref("release-artifacts/latest/release-manifest.json"),
            "checksum_bundle": self_ref("release-artifacts/latest/SHA256SUMS"),
        },
        "signing_identity": {
            "status": checker.LOCAL_PLACEHOLDER_STATUS,
            "public_key_fingerprint": "not_applicable_local",
            "key_custody": "not_applicable_local",
            "rotation_policy": "Production releases must document signer rotation.",
        },
        "signatures": {
            "detached_checksum_signature": signature_result(checker.LOCAL_PLACEHOLDER_STATUS),
            "signed_git_tag": signature_result(checker.LOCAL_PLACEHOLDER_STATUS),
        },
        "retained_artifacts": [
            {**schema, "category": "release_signature_schema"},
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["private_key", "mnemonic", "api_key", "rpc_url"],
        },
        "operator_notes": "local placeholder only",
    }


class ReleaseSignatureEvidenceTests(unittest.TestCase):
    def test_valid_evidence_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            checker.validate_evidence(path, root)

    def test_unexpected_fields_fail(self) -> None:
        mutations = {
            "top_level": lambda evidence: evidence.update({"unexpected": "value"}),
            "nested": lambda evidence: evidence["signatures"]["signed_git_tag"].update(
                {"unexpected": "value"}
            ),
        }

        for label, mutate in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                evidence = valid_evidence(root)
                mutate(evidence)
                path = root / "release-artifacts/signatures/example.json"
                write_json(path, evidence)

                with self.assertRaisesRegex(
                    checker.ReleaseSignatureEvidenceError, "unexpected field"
                ):
                    checker.validate_evidence(path, root)

    def test_negative_confirmation_depth_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["confirmation_depth"] = -1
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.ReleaseSignatureEvidenceError, "zero or greater"):
                checker.validate_evidence(path, root)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.ReleaseSignatureEvidenceError, "secret-like"):
                checker.validate_evidence(path, root)

    def test_stale_retained_artifact_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            write_text(root / "release-artifacts/schema/release-signature-evidence.schema.json", "changed\n")
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.ReleaseSignatureEvidenceError, "sha256 mismatch"):
                checker.validate_evidence(path, root)

    def test_non_local_placeholder_signature_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "testnet"
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.ReleaseSignatureEvidenceError, "non-local"):
                checker.validate_evidence(path, root)

    def test_signed_signature_requires_verification_command(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "testnet"
            evidence["signing_identity"]["status"] = "active"
            evidence["signing_identity"]["public_key_fingerprint"] = "a" * 40
            evidence["signatures"]["detached_checksum_signature"] = {
                "status": "signed",
                "format": "gpg",
                "artifact_path": "release-artifacts/latest/SHA256SUMS.asc",
                "verification_command": "not_applicable_local",
                "evidence": [file_ref(root, "release-artifacts/latest/SHA256SUMS.asc")],
                "notes": "signed checksum bundle",
            }
            evidence["signatures"]["signed_git_tag"] = {
                "status": "pending",
                "format": "gpg",
                "artifact_path": "v0.1.0",
                "verification_command": "git tag -v v0.1.0",
                "evidence": [],
                "notes": "pending signed tag",
            }
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(
                checker.ReleaseSignatureEvidenceError, "verification_command"
            ):
                checker.validate_evidence(path, root)

    def test_production_requires_signed_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "production"
            evidence["signing_identity"]["status"] = "active"
            evidence["signing_identity"]["public_key_fingerprint"] = "b" * 40
            evidence["signatures"]["detached_checksum_signature"] = {
                "status": "pending",
                "format": "gpg",
                "artifact_path": "release-artifacts/latest/SHA256SUMS.asc",
                "verification_command": "gpg --verify release-artifacts/latest/SHA256SUMS.asc release-artifacts/latest/SHA256SUMS",
                "evidence": [],
                "notes": "pending detached checksum signature",
            }
            evidence["signatures"]["signed_git_tag"] = {
                "status": "pending",
                "format": "gpg",
                "artifact_path": "v0.1.0",
                "verification_command": "git tag -v v0.1.0",
                "evidence": [],
                "notes": "pending signed Git tag",
            }
            path = root / "release-artifacts/signatures/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.ReleaseSignatureEvidenceError, "production"):
                checker.validate_evidence(path, root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
