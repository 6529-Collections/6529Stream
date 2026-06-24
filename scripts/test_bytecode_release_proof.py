#!/usr/bin/env python3
"""Focused tests for bytecode-to-release proof generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("generate_bytecode_release_proof.py")
SPEC = importlib.util.spec_from_file_location("generate_bytecode_release_proof", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
proof = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(proof)


ABI_HASH = "sha256:" + "1" * 64
RUNTIME_HASH = "sha256:" + "2" * 64
CREATION_HASH = "sha256:" + "3" * 64
SOURCE_HASH = "sha256:" + "4" * 64
ARTIFACT_HASH = "sha256:" + "5" * 64
RELEASE_ARTIFACT_MANIFEST_HASH = "sha256:" + "7" * 64
ADDRESS = "0x0000000000000000000000000000000000000001"
CREATION_SIZE = 2
RUNTIME_SIZE = 2
EIP170_LIMIT = 24_576


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def read_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def write_minimal_tree(root: Path) -> dict[str, Path]:
    abi_path = root / "release-artifacts/latest/abi-checksums.json"
    source_path = root / "release-artifacts/latest/source-verification-inputs.json"
    release_manifest_path = root / "release-artifacts/latest/release-manifest.json"
    manifest_path = root / "deployments/examples/example.json"
    address_book_path = root / "deployments/address-books/example.json"

    abi_checksums = {
        "schema_version": "6529stream.abi-checksums.v1",
        "contracts": {
            "Example": {
                "source": "smart-contracts/Example.sol",
                "artifact_path": "out/Example.sol/Example.json",
                "abi_sha256": ABI_HASH,
                "deployed_bytecode_sha256": RUNTIME_HASH,
                "bytecode_size_bytes": CREATION_SIZE,
                "deployed_bytecode_size_bytes": RUNTIME_SIZE,
                "eip170_runtime_limit_bytes": EIP170_LIMIT,
                "deployed_runtime_margin_bytes": EIP170_LIMIT - RUNTIME_SIZE,
            }
        },
        "bytecode_hashes": {
            "Example": {
                "creation": {"sha256": CREATION_HASH, "size_bytes": CREATION_SIZE},
                "runtime": {"sha256": RUNTIME_HASH, "size_bytes": RUNTIME_SIZE},
            }
        },
    }
    source_verification = {
        "schema_version": "6529stream.source-verification-inputs.v1",
        "contracts": {
            "Example": {
                "source": "smart-contracts/Example.sol",
                "source_sha256": SOURCE_HASH,
                "source_solc_keccak256": "0x" + "6" * 64,
                "artifact_path": "out/Example.sol/Example.json",
                "artifact_sha256": ARTIFACT_HASH,
                "compiler_version": "0.8.19+commit.7dd6d404",
                "settings": {
                    "evm_version": "paris",
                    "optimizer": {"enabled": True, "runs": 200},
                    "via_ir": True,
                    "metadata_bytecode_hash": "ipfs",
                },
                "abi_sha256": ABI_HASH,
                "bytecode_hashes": {
                    "creation": {"release_artifact_sha256": CREATION_HASH},
                    "runtime": {"release_artifact_sha256": RUNTIME_HASH},
                },
                "constructor_args": {"status": "retained_per_deployment_manifest"},
            }
        },
    }
    deployment_manifest = {
        "manifest_schema_version": "6529stream.deployment-manifest.v1",
        "protocol_version": "0.1.0",
        "deployment_version": "example",
        "lifecycle_state": "Rehearsed",
        "network": {"name": "anvil", "chain_id": 31337},
        "contracts": {
            "Example": {
                "address": ADDRESS,
                "abi_hash": ABI_HASH,
                "bytecode_hash": RUNTIME_HASH,
                "verification_status": "not_applicable",
            }
        },
        "release_artifacts": {
            "manifest_sha256": RELEASE_ARTIFACT_MANIFEST_HASH,
        },
    }
    write_json(abi_path, abi_checksums)
    write_json(source_path, source_verification)
    write_json(manifest_path, deployment_manifest)
    deployment_manifest_hash = proof.file_sha256(manifest_path)

    release_manifest = {
        "schema_version": "6529stream.release-manifest.v1",
        "release": {
            "project": "6529Stream",
            "status": "pre_audit_local_baseline",
            "protocol_versions": ["0.1.0"],
            "deployment_versions": ["example"],
        },
        "release_artifacts": {
            "abi_checksums": {
                "path": "release-artifacts/latest/abi-checksums.json",
                "sha256": proof.file_sha256(abi_path),
            },
            "source_verification_inputs": {
                "path": "release-artifacts/latest/source-verification-inputs.json",
                "sha256": proof.file_sha256(source_path),
            },
        },
    }
    write_json(release_manifest_path, release_manifest)

    address_book = {
        "schema_version": "6529stream.address-book.v1",
        "source": {
            "deployment_manifest": "deployments/examples/example.json",
            "deployment_manifest_sha256": deployment_manifest_hash,
        },
        "protocol_version": "0.1.0",
        "deployment_version": "example",
        "lifecycle_state": "Rehearsed",
        "network": {"name": "anvil", "chain_id": 31337},
        "contracts": {
            "Example": {
                "address": ADDRESS,
                "source": "smart-contracts/Example.sol",
                "artifact_path": "out/Example.sol/Example.json",
                "abi_hash": ABI_HASH,
                "runtime_bytecode_hash": RUNTIME_HASH,
                "verification_status": "not_applicable",
            }
        },
    }
    write_json(address_book_path, address_book)
    return {
        "output": root / "release-artifacts/latest/bytecode-release-proof.json",
        "release_manifest": release_manifest_path,
        "abi": abi_path,
        "source": source_path,
        "address_book_dir": root / "deployments/address-books",
        "manifest": manifest_path,
        "address_book": address_book_path,
    }


class BytecodeReleaseProofTests(unittest.TestCase):
    def test_committed_bytecode_release_proof_is_current(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        proof.check_proof(
            repo_root,
            proof.DEFAULT_OUTPUT,
            proof.DEFAULT_RELEASE_MANIFEST,
            proof.DEFAULT_ABI_CHECKSUMS,
            proof.DEFAULT_SOURCE_VERIFICATION_INPUTS,
            proof.DEFAULT_ADDRESS_BOOK_DIR,
        )

    def test_minimal_tree_generates_and_checks(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            proof.write_proof(
                root,
                paths["output"],
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/abi-checksums.json"),
                Path("release-artifacts/latest/source-verification-inputs.json"),
                Path("deployments/address-books"),
            )

            generated = read_json(paths["output"])
            proof.check_proof(
                root,
                paths["output"],
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/abi-checksums.json"),
                Path("release-artifacts/latest/source-verification-inputs.json"),
                Path("deployments/address-books"),
            )

        self.assertEqual(generated["schema_version"], proof.BYTECODE_RELEASE_PROOF_SCHEMA)
        self.assertEqual(generated["proof_status"]["production"], "missing_reviewed_live_proof")
        self.assertEqual(generated["contract_proofs"][0]["hashes"]["runtime_bytecode"], RUNTIME_HASH)
        self.assertEqual(
            generated["contract_proofs"][0]["sizes"]["runtime_margin_bytes"],
            EIP170_LIMIT - RUNTIME_SIZE,
        )

    def test_check_mode_rejects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            proof.write_proof(
                root,
                paths["output"],
                Path("release-artifacts/latest/release-manifest.json"),
                Path("release-artifacts/latest/abi-checksums.json"),
                Path("release-artifacts/latest/source-verification-inputs.json"),
                Path("deployments/address-books"),
            )
            with paths["output"].open("a", encoding="utf-8") as handle:
                handle.write("\n")

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "changed release-artifacts/latest/bytecode-release-proof.json",
            ):
                proof.check_proof(
                    root,
                    paths["output"],
                    Path("release-artifacts/latest/release-manifest.json"),
                    Path("release-artifacts/latest/abi-checksums.json"),
                    Path("release-artifacts/latest/source-verification-inputs.json"),
                    Path("deployments/address-books"),
                )

    def test_rejects_deployment_manifest_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            manifest = read_json(paths["manifest"])
            manifest["network"]["chain_id"] = 1
            write_json(paths["manifest"], manifest)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "deployment manifest hash mismatch",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))

    def test_rejects_runtime_hash_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            address_book = read_json(paths["address_book"])
            address_book["contracts"]["Example"]["runtime_bytecode_hash"] = "sha256:" + "9" * 64
            write_json(paths["address_book"], address_book)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "runtime bytecode hash mismatch",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))

    def test_rejects_runtime_size_margin_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            abi = read_json(paths["abi"])
            abi["contracts"]["Example"]["deployed_runtime_margin_bytes"] = 1
            write_json(paths["abi"], abi)
            release_manifest = read_json(paths["release_manifest"])
            release_manifest["release_artifacts"]["abi_checksums"][
                "sha256"
            ] = proof.file_sha256(paths["abi"])
            write_json(paths["release_manifest"], release_manifest)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "runtime size margin mismatch",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))

    def test_rejects_source_verification_runtime_mismatch(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            source = read_json(paths["source"])
            source["contracts"]["Example"]["bytecode_hashes"]["runtime"][
                "release_artifact_sha256"
            ] = "sha256:" + "8" * 64
            write_json(paths["source"], source)
            release_manifest = read_json(paths["release_manifest"])
            release_manifest["release_artifacts"]["source_verification_inputs"][
                "sha256"
            ] = proof.file_sha256(paths["source"])
            write_json(paths["release_manifest"], release_manifest)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "runtime bytecode hash mismatch",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))

    def test_rejects_non_boolean_compiler_flags(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            source = read_json(paths["source"])
            source["contracts"]["Example"]["settings"]["optimizer"]["enabled"] = "true"
            write_json(paths["source"], source)
            release_manifest = read_json(paths["release_manifest"])
            release_manifest["release_artifacts"]["source_verification_inputs"][
                "sha256"
            ] = proof.file_sha256(paths["source"])
            write_json(paths["release_manifest"], release_manifest)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "settings.optimizer.enabled must be a boolean",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))

    def test_rejects_address_book_manifest_path_escape(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = write_minimal_tree(root)
            address_book = read_json(paths["address_book"])
            address_book["source"]["deployment_manifest"] = "../outside.json"
            write_json(paths["address_book"], address_book)

            with self.assertRaisesRegex(
                proof.BytecodeReleaseProofError,
                "must stay inside the repository",
            ):
                proof.build_proof(root, address_book_dir=Path("deployments/address-books"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
