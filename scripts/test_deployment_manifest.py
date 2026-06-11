#!/usr/bin/env python3
"""Focused tests for deployment manifest generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_deployment_manifest.py")
SPEC = importlib.util.spec_from_file_location("generate_deployment_manifest", SCRIPT_PATH)
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
            "abi_hashes": {
                "Alpha": "sha256:" + ("a" * 64),
                "Beta": "sha256:" + ("b" * 64),
            },
            "bytecode_hashes": {
                "Alpha": {"runtime": {"sha256": "sha256:" + ("1" * 64)}},
                "Beta": {"runtime": {"sha256": "sha256:" + ("2" * 64)}},
            },
        },
    )
    return release_dir


def manifest_config(root: Path) -> Path:
    config_path = root / "deployments" / "config" / "example.json"
    write_json(
        config_path,
        {
            "schema_version": "6529stream.deployment-manifest-input.v1",
            "output": "deployments/examples/example.json",
            "manifest": {
                "protocol_version": "0.1.0",
                "deployment_version": "example-001",
                "lifecycle_state": "Rehearsed",
                "network": {"name": "anvil", "chain_id": 31337},
                "git": {
                    "repository": "https://github.com/6529-Collections/6529Stream",
                    "commit": "0" * 40,
                    "source_dirty": False,
                },
                "toolchain": {
                    "foundry_version": "v1.7.1",
                    "solidity_version": "0.8.19",
                    "profile": "default",
                    "optimizer": True,
                    "optimizer_runs": 200,
                    "via_ir": True,
                },
                "contracts": [
                    {
                        "name": "Alpha",
                        "address": "0x0000000000000000000000000000000000000001",
                        "constructor_args": ["0x0000000000000000000000000000000000000002"],
                        "verification_status": "not_applicable",
                    },
                    {
                        "name": "Beta",
                        "address": "0x0000000000000000000000000000000000000002",
                        "constructor_args": [6529],
                        "verification_status": "verified",
                    },
                ],
                "admin_ceremony": {
                    "deployer": "0x0000000000000000000000000000000000000003",
                    "admin_safe": "0x0000000000000000000000000000000000000004",
                    "emergency_recipient": "0x0000000000000000000000000000000000000005",
                    "pause_guardians": ["0x0000000000000000000000000000000000000006"],
                    "unpause_admins": ["0x0000000000000000000000000000000000000004"],
                    "signer_managers": ["0x0000000000000000000000000000000000000004"],
                    "drop_signers": ["0x0000000000000000000000000000000000000007"],
                    "temporary_admins_revoked": True,
                    "ownership_transfers": [],
                },
                "external_dependencies": {
                    "vrf_coordinator": "0x0000000000000000000000000000000000000008",
                    "arrng_controller": "0x0000000000000000000000000000000000000009",
                    "delegation_registry": "0x0000000000000000000000000000000000000010",
                },
                "verification": {
                    "contract_verification": "not_applicable",
                    "constructor_args_retained": True,
                    "commands": ["forge script example"],
                },
                "release_artifacts": {
                    "event_topic_catalog": "release-artifacts/latest/event-topic-catalog.json"
                },
                "rehearsal": {
                    "command": "forge script example",
                    "anvil_passed": True,
                    "fork_passed": False,
                    "notes": "test manifest",
                },
            },
        },
    )
    return config_path


class DeploymentManifestTests(unittest.TestCase):
    def test_generator_fills_hashes_checksum_and_detects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            config_path = manifest_config(root)
            output_path = root / "deployments" / "examples" / "example.json"

            generated = generator.generate_manifest(config_path, release_dir, output_path)
            self.assertEqual(generated, output_path)

            manifest = generator.load_json(output_path)
            self.assertEqual(manifest["manifest_schema_version"], generator.MANIFEST_SCHEMA)
            self.assertEqual(manifest["contracts"]["Alpha"]["abi_hash"], "sha256:" + ("a" * 64))
            self.assertEqual(
                manifest["contracts"]["Alpha"]["bytecode_hash"], "sha256:" + ("1" * 64)
            )
            self.assertEqual(manifest["contracts"]["Beta"]["verification_status"], "verified")
            self.assertEqual(
                manifest["release_artifacts"]["abi_hashes"]["Beta"], "sha256:" + ("b" * 64)
            )
            self.assertEqual(
                manifest["release_artifacts"]["manifest_sha256"],
                generator.manifest_checksum(manifest),
            )
            self.assertNotEqual(
                manifest["release_artifacts"]["manifest_sha256"],
                generator.ZERO_MANIFEST_CHECKSUM,
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.check_manifest(config_path, release_dir, output_path), 0)

            manifest["network"]["chain_id"] = 1
            write_json(output_path, manifest)
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(generator.check_manifest(config_path, release_dir, output_path), 1)

    def test_generator_rejects_unknown_or_missing_contract_hashes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            release_dir = release_artifacts(root)
            config_path = manifest_config(root)
            config = generator.load_json(config_path)
            config["manifest"]["contracts"][0]["name"] = "Gamma"
            write_json(config_path, config)

            with self.assertRaisesRegex(generator.ManifestError, "omits release contracts"):
                generator.build_manifest(config_path, release_dir)


if __name__ == "__main__":
    unittest.main(verbosity=2)
