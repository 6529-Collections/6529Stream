#!/usr/bin/env python3
"""Focused tests for deployment manifest generation."""

from __future__ import annotations

import importlib.util
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("generate_deployment_manifest.py")
REPO_ROOT = Path(__file__).resolve().parents[1]
SEPOLIA_TEMPLATE = (
    REPO_ROOT / "deployments" / "config" / "sepolia-6529stream-v0.1.0-001.template.json"
)
SEPOLIA_REQUIRED_ENV_VARS = {
    "SEPOLIA_RPC_URL",
    "SEPOLIA_CONTRACT_METADATA_URI",
    "SEPOLIA_DEPLOYER_ADDRESS",
    "SEPOLIA_ADMIN_SAFE",
    "SEPOLIA_PAUSE_GUARDIAN",
    "SEPOLIA_EMERGENCY_RECIPIENT",
    "SEPOLIA_DROP_SIGNER",
    "SEPOLIA_PAYOUT",
    "SEPOLIA_DELEGATION_REGISTRY",
    "SEPOLIA_VRF_COORDINATOR",
    "SEPOLIA_ARRNG_CONTROLLER",
    "SEPOLIA_VRF_SUBSCRIPTION_ID",
    "ETHERSCAN_API_KEY",
}
SEPOLIA_EXPECTED_CONTRACTS = {
    "StreamAdmins",
    "DependencyRegistry",
    "StreamCore",
    "StreamContractMetadata",
    "StreamCollectionMetadata",
    "StreamPreservationRecords",
    "StreamCuratorsPool",
    "StreamMinter",
    "StreamDrops",
    "StreamAuctions",
    "NextGenRandomizerVRF",
    "NextGenRandomizerRNG",
    "StreamAssetPolicyRegistry",
    "StreamSplitFactory",
    "StreamRevenueResolver",
    "StreamPrimarySaleSettlement",
    "StreamMintLedger",
    "StreamMintModuleRegistry",
    "StreamMintManager",
}
TEMPLATE_FORBIDDEN_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s\"`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s\"`]*|"
    r"\bSEPOLIA_(?:PRIVATE|MNEMONIC|SEED|TOKEN|API_KEY)"
    r")",
    re.IGNORECASE,
)
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

    def test_sepolia_template_is_placeholder_scoped_and_no_secret(self) -> None:
        template_text = SEPOLIA_TEMPLATE.read_text(encoding="utf-8")
        self.assertIsNone(TEMPLATE_FORBIDDEN_SECRET_RE.search(template_text))

        template = json.loads(template_text)
        self.assertEqual(template["schema_version"], generator.INPUT_SCHEMA)
        self.assertIn("Template only", template["template_notice"])
        self.assertEqual(
            template["operator_runbook"],
            "docs/deployment.md#sepolia-deployment-rehearsal-runbook",
        )

        env_vars = {
            value["name"]
            for value in template["operator_inputs"]["required_environment_variables"]
        }
        self.assertEqual(env_vars, SEPOLIA_REQUIRED_ENV_VARS)
        self.assertEqual(
            template["operator_inputs"]["script_entrypoint"],
            'script/RehearseDeployment.s.sol:RehearseDeployment --sig "runSepolia()"',
        )

        manifest = template["manifest"]
        self.assertEqual(manifest["lifecycle_state"], "Template")
        self.assertEqual(manifest["network"]["name"], "sepolia")
        self.assertEqual(manifest["network"]["chain_id"], 11155111)
        self.assertEqual(manifest["network"]["rpc_environment_variable"], "SEPOLIA_RPC_URL")
        self.assertEqual(manifest["network"]["confirmation_depth"], 12)
        self.assertEqual(manifest["git"]["commit"], "0" * 40)

        contract_names = {contract["name"] for contract in manifest["contracts"]}
        self.assertEqual(contract_names, SEPOLIA_EXPECTED_CONTRACTS)
        for contract in manifest["contracts"]:
            self.assertEqual(contract["verification_status"], "not_started")
        self.assertEqual(manifest["verification"]["contract_verification"], "not_started")

        command = manifest["rehearsal"]["command"]
        self.assertIn('runSepolia()', command)
        self.assertIn("--rpc-url <redacted>", command)
        self.assertIn("--sender <deployer>", command)
        self.assertIn("<approved Foundry signer flags redacted>", command)
        self.assertNotIn("$SEPOLIA_RPC_URL", command)
        self.assertFalse(manifest["rehearsal"]["testnet_passed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
