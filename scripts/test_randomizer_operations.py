#!/usr/bin/env python3
"""Focused tests for randomizer operations evidence validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_randomizer_operations.py")
SPEC = importlib.util.spec_from_file_location("check_randomizer_operations", SCRIPT_PATH)
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


def seed_manifest(root: Path) -> dict[str, dict[str, str]]:
    deployment_manifest = root / "deployments/examples/anvil.json"
    address_book = root / "deployments/address-books/anvil.json"
    write_json(
        deployment_manifest,
        {
            "manifest_schema_version": "6529stream.deployment-manifest.v1",
            "contracts": {
                "NextGenRandomizerVRF": {
                    "address": "0x0000000000000000000000000000000000000008"
                },
                "NextGenRandomizerRNG": {
                    "address": "0x0000000000000000000000000000000000000009"
                },
            },
            "external_dependencies": {
                "vrf_coordinator": "0x0000000000000000000000000000000000006535",
                "arrng_controller": "0x0000000000000000000000000000000000006536",
            },
        },
    )
    write_json(
        address_book,
        {
            "schema_version": "6529stream.address-book.v1",
            "contracts": {
                "NextGenRandomizerVRF": {
                    "address": "0x0000000000000000000000000000000000000008"
                },
                "NextGenRandomizerRNG": {
                    "address": "0x0000000000000000000000000000000000000009"
                },
            },
        },
    )
    abi_checksums = root / "release-artifacts/latest/abi-checksums.json"
    write_json(abi_checksums, {"schema_version": "6529stream.abi-checksums.v1"})
    checksum_bundle = root / "release-artifacts/latest/SHA256SUMS"
    write_text(checksum_bundle, "placeholder\n")
    return {
        "deployment_manifest": {
            "path": "deployments/examples/anvil.json",
            "sha256": checker.file_sha256(deployment_manifest),
        },
        "address_book": {
            "path": "deployments/address-books/anvil.json",
            "sha256": checker.file_sha256(address_book),
        },
        "abi_checksums": {
            "path": "release-artifacts/latest/abi-checksums.json",
            "sha256": checker.file_sha256(abi_checksums),
        },
    }


def control(status: str, evidence: list[dict[str, str]]) -> dict[str, object]:
    return {
        "status": status,
        "notes": f"{status} control",
        "evidence": evidence,
    }


def valid_evidence(root: Path) -> dict[str, object]:
    artifacts = seed_manifest(root)
    lifecycle_test = file_ref(root, "test/StreamRandomizerLifecycle.t.sol")
    payment_test = file_ref(root, "test/StreamRandomizerPayments.t.sol")
    emergency_test = file_ref(root, "test/StreamEmergencyWithdraw.t.sol")

    return {
        "schema_version": checker.EVIDENCE_SCHEMA,
        "evidence_id": "anvil-randomizer-local",
        "protocol_version": "0.1.0",
        "deployment_version": "anvil-001",
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
            **artifacts,
            "release_checksum_bundle": {
                "path": "release-artifacts/latest/SHA256SUMS",
                "digest_status": checker.CHECKSUM_DIGEST_STATUS,
                "reason": "The checksum bundle covers randomizer evidence outputs.",
            },
        },
        "provider_configuration": {
            "vrf": {
                "adapter": "0x0000000000000000000000000000000000000008",
                "provider": "0x0000000000000000000000000000000000006535",
                "provider_type": "local_mock",
                "provider_epoch": 0,
                "funding_status": "not_applicable_local",
                "balance_wei": "0",
                "operator_notes": "local placeholder",
                "evidence": [lifecycle_test],
            },
            "arrng": {
                "adapter": "0x0000000000000000000000000000000000000009",
                "provider": "0x0000000000000000000000000000000000006536",
                "provider_type": "local_mock",
                "provider_epoch": 0,
                "funding_status": "not_applicable_local",
                "balance_wei": "0",
                "refund_recipient": "0x0000000000000000000000000000000000000009",
                "operator_notes": "local placeholder",
                "evidence": [payment_test],
            },
        },
        "lifecycle_controls": {
            "request_tracking": control("passed", [lifecycle_test]),
            "callback_validation": control("passed", [lifecycle_test]),
            "provider_epoch_migration": control("passed", [lifecycle_test]),
            "pending_request_migration_block": control("passed", [lifecycle_test]),
            "stale_request_policy": control("passed", [lifecycle_test]),
            "failed_request_policy": control("passed", [lifecycle_test]),
            "retry_policy": control("passed", [lifecycle_test]),
            "reserve_accounting": control("passed", [payment_test]),
            "pause_policy": control("passed", [emergency_test]),
            "emergency_withdrawal_boundary": control("passed", [emergency_test]),
        },
        "retained_artifacts": [
            {**artifacts["deployment_manifest"], "category": "deployment_manifest"},
            {**artifacts["address_book"], "category": "address_book"},
            {**artifacts["abi_checksums"], "category": "abi_checksums"},
        ],
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": ["rpc_url", "private_key", "mnemonic"],
        },
        "operator_notes": "local evidence only",
    }


class RandomizerOperationsTests(unittest.TestCase):
    def test_valid_evidence_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            checker.validate_evidence(path, root)

    def test_invalid_provider_address_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["provider_configuration"]["vrf"]["adapter"] = "0x1234"
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "20-byte"):
                checker.validate_evidence(path, root)

    def test_manifest_adapter_mismatch_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["provider_configuration"]["arrng"]["adapter"] = (
                "0x0000000000000000000000000000000000000010"
            )
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "does not match"):
                checker.validate_evidence(path, root)

    def test_passed_control_requires_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["lifecycle_controls"]["callback_validation"]["evidence"] = []
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "must not be empty"):
                checker.validate_evidence(path, root)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["operator_notes"] = "api_key=do-not-commit"
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "secret-like"):
                checker.validate_evidence(path, root)

    def test_non_local_cannot_use_local_funding_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "testnet"
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "non-local"):
                checker.validate_evidence(path, root)

    def test_production_requires_provider_funding_proof(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["network"]["environment"] = "production"
            evidence["provider_configuration"]["vrf"]["funding_status"] = "funded"
            evidence["provider_configuration"]["arrng"]["funding_status"] = "funded"
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "provider_funding"):
                checker.validate_evidence(path, root)

    def test_duplicate_retained_category_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = valid_evidence(root)
            evidence["retained_artifacts"].append(evidence["retained_artifacts"][0])
            path = root / "deployments/randomizer-operations/example.json"
            write_json(path, evidence)

            with self.assertRaisesRegex(checker.RandomizerOperationsError, "duplicated"):
                checker.validate_evidence(path, root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
