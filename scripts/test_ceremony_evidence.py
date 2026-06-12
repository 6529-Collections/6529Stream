#!/usr/bin/env python3
"""Focused tests for ceremony evidence validation."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_ceremony_evidence.py")
SPEC = importlib.util.spec_from_file_location("check_ceremony_evidence", SCRIPT_PATH)
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


def valid_evidence(root: Path) -> dict[str, object]:
    deployment_manifest = file_ref(root, "deployments/examples/example.json", "{}\n")
    address_book = file_ref(root, "deployments/address-books/example.json", "{}\n")
    abi_checksums = file_ref(root, "release-artifacts/latest/abi-checksums.json", "{}\n")
    release_checksums = root / "release-artifacts/latest/SHA256SUMS"
    write_text(release_checksums, "placeholder\n")

    deployment_script = file_ref(root, "script/RehearseDeployment.s.sol")
    metadata_script = file_ref(root, "script/RehearseMetadataBrowser.s.sol")
    auction_script = file_ref(root, "script/RehearseAuctionCeremony.s.sol")
    emergency_script = file_ref(root, "script/RehearseEmergencyRedeployment.s.sol")

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "example-local",
        "protocol_version": "0.1.0",
        "deployment_version": "example-001",
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
        "participants": {
            "deployer": "0x0000000000000000000000000000000000006537",
            "admin_safe": "0x0000000000000000000000000000000000006529",
            "tdh_signer": "0x0000000000000000000000000000000000006532",
            "emergency_recipient": "0x0000000000000000000000000000000000006531",
        },
        "artifacts": {
            "deployment_manifest": deployment_manifest,
            "deployment_manifest_canonical_sha256": "sha256:" + ("1" * 64),
            "address_book": address_book,
            "abi_checksums": abi_checksums,
            "release_checksum_bundle": {
                "path": "release-artifacts/latest/SHA256SUMS",
                "digest_status": checker.CHECKSUM_DIGEST_STATUS,
                "reason": "The checksum bundle covers ceremony evidence outputs.",
            },
        },
        "ceremony_results": {
            "admin_ceremony": {
                "status": "passed",
                "command": "forge script example",
                "evidence": [deployment_script],
                "notes": "admin ownership transferred",
            },
            "signer_setup": {
                "status": "passed",
                "evidence": [deployment_manifest],
                "notes": "drop signer recorded",
            },
            "metadata_browser": {
                "status": "passed",
                "command": "python scripts/check_rehearsal_metadata_browser_sandbox.py",
                "evidence": [metadata_script],
                "notes": "browser sandbox passed",
            },
            "auction_ceremony": {
                "status": "passed",
                "command": "forge script auction",
                "evidence": [auction_script],
                "notes": "auction settled",
            },
            "emergency_redeployment": {
                "status": "passed",
                "command": "forge script emergency",
                "evidence": [emergency_script],
                "notes": "replacement smoke passed",
            },
        },
        "verification_status": {
            "contract_verification": "not_applicable",
            "source_verification_inputs": "verified",
            "explorer_submissions": [],
        },
        "retained_artifacts": [
            {**deployment_manifest, "category": "deployment_manifest"},
            {**address_book, "category": "address_book"},
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["rpc_url", "private_key", "mnemonic"],
        },
        "operator_notes": "local evidence only",
    }


class CeremonyEvidenceTests(unittest.TestCase):
    def test_valid_evidence_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            checker.validate_evidence(path, root)

    def test_missing_required_section_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            del evidence["ceremony_results"]["auction_ceremony"]
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "auction_ceremony"):
                checker.validate_evidence(path, root)

    def test_invalid_hash_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["artifacts"]["deployment_manifest"]["sha256"] = "sha256:" + ("f" * 64)
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "sha256 mismatch"):
                checker.validate_evidence(path, root)

    def test_missing_referenced_file_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["artifacts"]["address_book"]["path"] = "deployments/address-books/missing.json"
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "missing file"):
                checker.validate_evidence(path, root)

    def test_non_local_passed_evidence_requires_retained_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "testnet"
            evidence["verification_status"]["contract_verification"] = "verified"
            evidence["retained_artifacts"] = []
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "retained_artifacts"):
                checker.validate_evidence(path, root)

    def test_testnet_verification_cannot_be_not_applicable(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "testnet"
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "not_applicable"):
                checker.validate_evidence(path, root)

    def test_secret_like_keys_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = copy.deepcopy(valid_evidence(root))
            evidence["operator_private_key"] = "do-not-commit"
            path = root / "deployments/ceremony-evidence/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.CeremonyEvidenceError, "secret-like"):
                checker.validate_evidence(path, root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
