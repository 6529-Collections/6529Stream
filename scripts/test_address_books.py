#!/usr/bin/env python3
"""Focused tests for deployment address-book generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_address_books.py")
SPEC = importlib.util.spec_from_file_location("generate_address_books", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def release_artifacts(root: Path) -> Path:
    release_dir = root / "release-artifacts" / "latest"
    write_json(
        release_dir / "abi-checksums.json",
        {
            "schema_version": "6529stream.abi-checksums.v1",
            "contracts": {
                "Alpha": {
                    "source": "smart-contracts/Alpha.sol",
                    "artifact_path": "out/Alpha.sol/Alpha.json",
                    "abi_sha256": "sha256:" + ("a" * 64),
                    "deployed_bytecode_sha256": "sha256:" + ("1" * 64),
                },
                "Beta": {
                    "source": "smart-contracts/Beta.sol",
                    "artifact_path": "out/Beta.sol/Beta.json",
                    "abi_sha256": "sha256:" + ("b" * 64),
                    "deployed_bytecode_sha256": "sha256:" + ("2" * 64),
                },
            },
        },
    )
    return release_dir


def deployment_manifest(root: Path) -> Path:
    manifest_path = root / "deployments" / "examples" / "example.json"
    write_json(
        manifest_path,
        {
            "manifest_schema_version": "6529stream.deployment-manifest.v1",
            "protocol_version": "0.1.0",
            "deployment_version": "example-001",
            "lifecycle_state": "Rehearsed",
            "network": {"name": "anvil", "chain_id": 31337},
            "git": {
                "repository": "https://github.com/6529-Collections/6529Stream",
                "commit": "0" * 40,
                "source_dirty": False,
            },
            "contracts": {
                "Alpha": {
                    "address": "0x0000000000000000000000000000000000000001",
                    "abi_hash": "sha256:" + ("a" * 64),
                    "bytecode_hash": "sha256:" + ("1" * 64),
                    "verification_status": "not_applicable",
                },
                "Beta": {
                    "address": "0x0000000000000000000000000000000000000002",
                    "abi_hash": "sha256:" + ("b" * 64),
                    "bytecode_hash": "sha256:" + ("2" * 64),
                    "verification_status": "verified",
                },
            },
            "release_artifacts": {
                "manifest_sha256": "sha256:" + ("c" * 64),
                "event_topic_catalog": "release-artifacts/latest/event-topic-catalog.json",
            },
        },
    )
    return manifest_path


class AddressBookTests(unittest.TestCase):
    def test_generator_writes_address_book_and_detects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            output_dir = root / "deployments" / "address-books"

            written = generator.generate_address_books(
                [manifest_path], release_dir, output_dir, root
            )
            self.assertEqual(written, [output_dir / "example.json"])

            address_book = generator.load_json(output_dir / "example.json")
            self.assertEqual(address_book["schema_version"], generator.ADDRESS_BOOK_SCHEMA)
            self.assertEqual(address_book["network"]["chain_id"], 31337)
            self.assertEqual(
                address_book["source"]["deployment_manifest"],
                "deployments/examples/example.json",
            )
            self.assertEqual(
                address_book["source"]["abi_checksums"],
                "release-artifacts/latest/abi-checksums.json",
            )
            self.assertEqual(
                address_book["contracts"]["Alpha"]["source"],
                "smart-contracts/Alpha.sol",
            )
            self.assertEqual(
                address_book["contracts"]["Beta"]["runtime_bytecode_hash"],
                "sha256:" + ("2" * 64),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_address_books([manifest_path], release_dir, output_dir, root),
                    0,
                )

            address_book["protocol_version"] = "0.2.0"
            write_json(output_dir / "example.json", address_book)
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_address_books([manifest_path], release_dir, output_dir, root),
                    1,
                )

    def test_generator_rejects_duplicate_addresses(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            manifest = generator.load_json(manifest_path)
            manifest["contracts"]["Beta"]["address"] = manifest["contracts"]["Alpha"]["address"]
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.AddressBookError, "duplicates"):
                generator.build_address_book(manifest_path, release_dir, root)

    def test_generator_rejects_invalid_address(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            manifest = generator.load_json(manifest_path)
            manifest["contracts"]["Alpha"]["address"] = "0xnot-an-address"
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.AddressBookError, "20-byte hex address"):
                generator.build_address_book(manifest_path, release_dir, root)

    def test_generator_rejects_missing_contract_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            manifest = generator.load_json(manifest_path)
            del manifest["contracts"]["Alpha"]["abi_hash"]
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.AddressBookError, "abi_hash"):
                generator.build_address_book(manifest_path, release_dir, root)

    def test_generator_rejects_invalid_source_dirty_type(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            manifest = generator.load_json(manifest_path)
            manifest["git"]["source_dirty"] = "false"
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.AddressBookError, "source_dirty"):
                generator.build_address_book(manifest_path, release_dir, root)

    def test_generator_rejects_missing_release_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            manifest_path = deployment_manifest(root)
            manifest = generator.load_json(manifest_path)
            del manifest["contracts"]["Beta"]
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(generator.AddressBookError, "omits release contracts"):
                generator.build_address_book(manifest_path, release_dir, root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
