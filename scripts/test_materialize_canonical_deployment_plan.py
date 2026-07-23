#!/usr/bin/env python3
"""Focused unit tests for the non-production deployment-plan materializer."""

from __future__ import annotations

import copy
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any

import materialize_canonical_deployment_plan as materializer


ZERO_SHA256 = "sha256:" + ("0" * 64)
ADMIN_ADDRESS = "0x0000000000000000000000000000000000000011"
LIBRARY_ADDRESS = "0x0000000000000000000000000000000000000022"
OTHER_LIBRARY_ADDRESS = "0x0000000000000000000000000000000000000033"
PLACEHOLDER = "__" + ("x" * 36) + "__"


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


class MaterializerFixture:
    """Create a tiny receipt/artifact universe without invoking Forge."""

    def __init__(self, root: Path) -> None:
        self.root = root
        self.artifact_path = (
            root / "out-release" / "Fixture.sol" / "Fixture.json"
        )
        self.receipt_path = (
            root / "out-release" / "release-build-manifest.json"
        )
        self.candidate_path = (
            root / "deployments" / "config" / "candidate.json"
        )
        (root / "release-artifacts").mkdir(parents=True)
        config_path = root / "release-artifacts" / "contracts.json"
        config_path.write_text(
            "{}\n",
            encoding="utf-8",
        )
        foundry_config_path = root / "foundry.toml"
        foundry_config_path.write_text(
            "[profile.default]\n",
            encoding="utf-8",
        )
        config_sha256 = materializer.file_sha256(config_path)
        foundry_config_sha256 = materializer.file_sha256(
            foundry_config_path
        )

        self.artifact = {
            "abi": [
                {
                    "type": "constructor",
                    "inputs": [
                        {
                            "name": "_admin",
                            "type": "address",
                            "internalType": "address",
                        }
                    ],
                    "stateMutability": "nonpayable",
                }
            ],
            "bytecode": {
                "object": "0x60" + PLACEHOLDER + "00",
                "linkReferences": {
                    "smart-contracts/FixtureLibrary.sol": {
                        "FixtureLibrary": [
                            {
                                "start": 1,
                                "length": 20,
                            }
                        ]
                    }
                },
            },
            "deployedBytecode": {
                "object": "0x61" + PLACEHOLDER + "00",
                "linkReferences": {
                    "smart-contracts/FixtureLibrary.sol": {
                        "FixtureLibrary": [
                            {
                                "start": 1,
                                "length": 20,
                            }
                        ]
                    }
                },
                "immutableReferences": {},
            },
        }
        write_json(self.artifact_path, self.artifact)
        target = {
            "kind": "production_contract",
            "name": "Fixture",
            "source": "smart-contracts/Fixture.sol",
            "artifact_relative_path": "Fixture.sol/Fixture.json",
            "artifact_sha256": materializer.file_sha256(self.artifact_path),
        }
        self.receipt = {
            "schema_version": "6529stream.release-build.v1",
            "source": {
                "config": "release-artifacts/contracts.json",
                "config_sha256": config_sha256,
                "foundry_config": "foundry.toml",
                "foundry_config_sha256": foundry_config_sha256,
            },
            "policy": {
                "compilation_unit": "one target and its import closure",
                "solc_version": "0.8.19",
                "solc_long_version": "0.8.19+commit.7dd6d404",
                "evm_version": "paris",
                "optimizer_enabled": True,
                "optimizer_runs": 200,
                "via_ir": True,
                "bytecode_hash": "none",
                "cbor_metadata": False,
                "controlled_forge_environment": {
                    "FOUNDRY_PROFILE": "default"
                },
                "forge_profile": "default",
                "foundry_version": "test",
                "forge_version": "test",
                "forge_version_sha256": ZERO_SHA256,
                "sanitized_environment_prefixes": ["DAPP_", "FOUNDRY_"],
            },
            "targets": [target],
        }
        write_json(self.receipt_path, self.receipt)

        encoded_args = materializer.encode_abi(["address"], [ADMIN_ADDRESS])
        linked_creation = (
            bytes.fromhex("60")
            + bytes.fromhex(LIBRARY_ADDRESS[2:])
            + bytes.fromhex("00")
        )
        expected_runtime = (
            bytes.fromhex("61")
            + bytes.fromhex(LIBRARY_ADDRESS[2:])
            + bytes.fromhex("00")
        )
        self.candidate = {
            "schema_version": materializer.CANDIDATE_SCHEMA,
            "candidate_id": "unit-fixture",
            "candidate_kind": "non_production_fixture",
            "production_candidate": False,
            "readiness_evidence": False,
            "network": {
                "environment": "anvil",
                "chain_id": 31337,
            },
            "release_build": {
                "receipt_path": "out-release/release-build-manifest.json",
                "receipt_sha256": materializer.file_sha256(
                    self.receipt_path
                ),
                "target_catalog_sha256": (
                    materializer.target_catalog_sha256(self.receipt)
                ),
                "config_path": "release-artifacts/contracts.json",
                "config_sha256": config_sha256,
                "foundry_config_path": "foundry.toml",
                "foundry_config_sha256": foundry_config_sha256,
            },
            "instances": [
                {
                    "order": 1,
                    "instance_id": "fixture",
                    "profile_entry_id": None,
                    "target": copy.deepcopy(target),
                    "depends_on": [],
                    "constructor": {
                        "types": ["address"],
                        "arguments": [ADMIN_ADDRESS],
                        "encoded_args_keccak256": (
                            materializer.keccak256_hex(encoded_args)
                        ),
                    },
                    "libraries": [
                        {
                            "source": (
                                "smart-contracts/FixtureLibrary.sol"
                            ),
                            "name": "FixtureLibrary",
                            "address": LIBRARY_ADDRESS,
                        }
                    ],
                    "runtime": {
                        "immutable_values": {},
                        "expected_keccak256": (
                            materializer.keccak256_hex(expected_runtime)
                        ),
                    },
                    "expected_initcode_keccak256": (
                        materializer.keccak256_hex(
                            linked_creation + encoded_args
                        )
                    ),
                }
            ],
        }
        write_json(self.candidate_path, self.candidate)

    def validator(
        self,
        _repo_root: Path,
        _config_path: Path,
        _foundry_config_path: Path,
        _output_dir: Path,
    ) -> dict[str, Any]:
        return copy.deepcopy(self.receipt)

    def materialize(self) -> dict[str, Any]:
        return materializer.materialize_deployment_plan(
            self.root,
            self.candidate_path,
            receipt_validator=self.validator,
        )

    def write_candidate(self) -> None:
        write_json(self.candidate_path, self.candidate)

    def rebind_artifact_and_receipt(self) -> None:
        """Bind candidate and receipt to the current in-memory artifact."""
        write_json(self.artifact_path, self.artifact)
        digest = materializer.file_sha256(self.artifact_path)
        self.receipt["targets"][0]["artifact_sha256"] = digest
        self.candidate["instances"][0]["target"]["artifact_sha256"] = digest
        write_json(self.receipt_path, self.receipt)
        binding = self.candidate["release_build"]
        binding["receipt_sha256"] = materializer.file_sha256(
            self.receipt_path
        )
        binding["target_catalog_sha256"] = (
            materializer.target_catalog_sha256(self.receipt)
        )
        self.write_candidate()


class CanonicalDeploymentPlanTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.fixture = MaterializerFixture(self.root)

    def assert_materialization_fails(self, pattern: str) -> None:
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            pattern,
        ):
            self.fixture.materialize()

    def test_materializes_deterministically_with_exact_hashes(self) -> None:
        first = self.fixture.materialize()
        second = self.fixture.materialize()
        self.assertEqual(first, second)
        self.assertEqual(
            first["schema_version"],
            "6529stream.canonical-deployment-plan.v1",
        )
        self.assertFalse(first["release_posture"]["production_candidate"])
        self.assertFalse(first["release_posture"]["readiness_evidence"])
        deployment = first["deployments"][0]
        self.assertEqual(
            deployment["constructor"]["encoded_args_keccak256"],
            self.fixture.candidate["instances"][0]["constructor"][
                "encoded_args_keccak256"
            ],
        )
        self.assertEqual(
            deployment["initcode_keccak256"],
            self.fixture.candidate["instances"][0][
                "expected_initcode_keccak256"
            ],
        )
        self.assertEqual(
            deployment["expected_runtime_keccak256"],
            self.fixture.candidate["instances"][0]["runtime"][
                "expected_keccak256"
            ],
        )
        self.assertEqual(
            deployment["libraries"][0]["creation_positions"],
            [{"start": 1, "length": 20}],
        )
        self.assertEqual(
            deployment["libraries"][0]["runtime_positions"],
            [{"start": 1, "length": 20}],
        )

    def test_refuses_production_and_readiness_claims(self) -> None:
        self.fixture.candidate["production_candidate"] = True
        self.fixture.write_candidate()
        self.assert_materialization_fails("refuses production candidates")

        self.fixture.candidate["production_candidate"] = False
        self.fixture.candidate["readiness_evidence"] = True
        self.fixture.write_candidate()
        self.assert_materialization_fails("not release-readiness evidence")

    def test_rejects_stale_receipt_and_catalog_bindings(self) -> None:
        with self.fixture.receipt_path.open("a", encoding="utf-8") as handle:
            handle.write(" ")
        self.assert_materialization_fails("receipt hash is stale")

        write_json(self.fixture.receipt_path, self.fixture.receipt)
        self.fixture.receipt["targets"][0]["name"] = "OtherFixture"
        write_json(self.fixture.receipt_path, self.fixture.receipt)
        self.fixture.candidate["release_build"]["receipt_sha256"] = (
            materializer.file_sha256(self.fixture.receipt_path)
        )
        self.fixture.write_candidate()
        self.assert_materialization_fails("target catalog hash is stale")

    def test_rejects_stale_release_and_foundry_configs(self) -> None:
        config_path = self.root / "release-artifacts" / "contracts.json"
        config_path.write_text('{"mutated":true}\n', encoding="utf-8")
        self.assert_materialization_fails("release config hash is stale")

        config_path.write_text("{}\n", encoding="utf-8")
        foundry_path = self.root / "foundry.toml"
        foundry_path.write_text(
            "[profile.default]\nmutated = true\n",
            encoding="utf-8",
        )
        self.assert_materialization_fails("Foundry config hash is stale")

    def test_rejects_mutated_artifact(self) -> None:
        with self.fixture.artifact_path.open("a", encoding="utf-8") as handle:
            handle.write(" ")
        self.assert_materialization_fails("artifact hash is stale or mutated")

    def test_rejects_wrong_constructor_types_and_arguments(self) -> None:
        constructor = self.fixture.candidate["instances"][0]["constructor"]
        constructor["types"] = ["uint256"]
        self.fixture.write_candidate()
        self.assert_materialization_fails("do not match artifact ABI")

        constructor["types"] = ["address"]
        constructor["arguments"] = [OTHER_LIBRARY_ADDRESS]
        self.fixture.write_candidate()
        self.assert_materialization_fails("constructor argument hash mismatch")

    def test_abi_normalization_supports_zero_addresses_and_large_integers(
        self,
    ) -> None:
        self.assertEqual(
            materializer.normalize_abi_value(
                {"type": "address"},
                "0x0000000000000000000000000000000000000000",
                "argument",
            ),
            "0x0000000000000000000000000000000000000000",
        )
        large = str((1 << 255) + 17)
        self.assertEqual(
            materializer.normalize_abi_value(
                {"type": "uint256"},
                large,
                "argument",
            ),
            int(large),
        )
        self.assertEqual(
            materializer.normalize_abi_value(
                {"type": "string"},
                "",
                "argument",
            ),
            "",
        )
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "canonical unsigned decimal string",
        ):
            materializer.normalize_abi_value(
                {"type": "uint256"},
                "01",
                "argument",
            )

    def test_rejects_missing_unresolved_and_wrong_library_bindings(self) -> None:
        instance = self.fixture.candidate["instances"][0]
        instance["libraries"] = []
        self.fixture.write_candidate()
        self.assert_materialization_fails(
            "library bindings do not match creation/runtime references"
        )

        instance["libraries"] = [
            {
                "source": "smart-contracts/FixtureLibrary.sol",
                "name": "FixtureLibrary",
                "address": OTHER_LIBRARY_ADDRESS,
            }
        ]
        self.fixture.write_candidate()
        self.assert_materialization_fails("full initcode hash mismatch")

        instance["libraries"] = []
        self.fixture.artifact["bytecode"]["linkReferences"] = {}
        self.fixture.artifact["deployedBytecode"]["linkReferences"] = {}
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("remains unresolved")

    def test_accepts_library_used_by_only_creation_or_runtime(self) -> None:
        runtime = self.fixture.artifact["deployedBytecode"]
        runtime["object"] = "0x6100"
        runtime["linkReferences"] = {}
        self.fixture.candidate["instances"][0]["runtime"][
            "expected_keccak256"
        ] = materializer.keccak256_hex(bytes.fromhex("6100"))
        self.fixture.rebind_artifact_and_receipt()
        creation_only = self.fixture.materialize()["deployments"][0]
        self.assertEqual(
            creation_only["libraries"][0]["runtime_positions"],
            [],
        )

        creation = self.fixture.artifact["bytecode"]
        creation["object"] = "0x6000"
        creation["linkReferences"] = {}
        runtime["object"] = "0x61" + PLACEHOLDER + "00"
        runtime["linkReferences"] = {
            "smart-contracts/FixtureLibrary.sol": {
                "FixtureLibrary": [
                    {
                        "start": 1,
                        "length": 20,
                    }
                ]
            }
        }
        encoded_args = materializer.encode_abi(["address"], [ADMIN_ADDRESS])
        instance = self.fixture.candidate["instances"][0]
        instance["expected_initcode_keccak256"] = (
            materializer.keccak256_hex(
                bytes.fromhex("6000") + encoded_args
            )
        )
        runtime_bytes = (
            bytes.fromhex("61")
            + bytes.fromhex(LIBRARY_ADDRESS[2:])
            + bytes.fromhex("00")
        )
        instance["runtime"]["expected_keccak256"] = (
            materializer.keccak256_hex(runtime_bytes)
        )
        self.fixture.rebind_artifact_and_receipt()
        runtime_only = self.fixture.materialize()["deployments"][0]
        self.assertEqual(
            runtime_only["libraries"][0]["creation_positions"],
            [],
        )

    def test_rejects_overlapping_library_references(self) -> None:
        self.fixture.artifact["bytecode"]["linkReferences"][
            "smart-contracts/OtherLibrary.sol"
        ] = {
            "OtherLibrary": [
                {
                    "start": 1,
                    "length": 20,
                }
            ]
        }
        self.fixture.candidate["instances"][0]["libraries"].append(
            {
                "source": "smart-contracts/OtherLibrary.sol",
                "name": "OtherLibrary",
                "address": OTHER_LIBRARY_ADDRESS,
            }
        )
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("contains overlapping ranges")

    def test_rejects_target_mismatch_and_path_contamination(self) -> None:
        target = self.fixture.candidate["instances"][0]["target"]
        target["artifact_relative_path"] = "Other.sol/Fixture.json"
        self.fixture.write_candidate()
        self.assert_materialization_fails(
            "does not exactly match the release receipt"
        )

        target["artifact_relative_path"] = "../Fixture.json"
        self.fixture.write_candidate()
        self.assert_materialization_fails(
            "normalized forward-slash repository-relative path"
        )

        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "below the repository tmp directory",
        ):
            materializer.resolve_output_path(
                self.root,
                self.root / "out-release" / "plan.json",
            )

    def test_materializes_immutables_and_rejects_missing_values(self) -> None:
        runtime = self.fixture.artifact["deployedBytecode"]
        runtime["object"] = "0x61" + PLACEHOLDER + ("00" * 32) + "00"
        runtime["immutableReferences"] = {
            "123": [
                {
                    "start": 21,
                    "length": 32,
                }
            ]
        }
        immutable_value = "0x" + ("ab" * 32)
        instance = self.fixture.candidate["instances"][0]
        instance["runtime"]["immutable_values"] = {
            "123": immutable_value
        }
        expected_runtime = (
            bytes.fromhex("61")
            + bytes.fromhex(LIBRARY_ADDRESS[2:])
            + bytes.fromhex(immutable_value[2:])
            + bytes.fromhex("00")
        )
        instance["runtime"]["expected_keccak256"] = (
            materializer.keccak256_hex(expected_runtime)
        )
        self.fixture.rebind_artifact_and_receipt()

        deployment = self.fixture.materialize()["deployments"][0]
        self.assertEqual(
            deployment["immutables"],
            [
                {
                    "ast_id": "123",
                    "value": immutable_value,
                    "runtime_positions": [{"start": 21, "length": 32}],
                }
            ],
        )

        instance["runtime"]["immutable_values"] = {}
        self.fixture.write_candidate()
        self.assert_materialization_fails(
            "immutable bindings do not match artifact references"
        )

    def test_rejects_overlapping_runtime_link_and_immutable(self) -> None:
        runtime = self.fixture.artifact["deployedBytecode"]
        runtime["immutableReferences"] = {
            "123": [
                {
                    "start": 1,
                    "length": 20,
                }
            ]
        }
        self.fixture.candidate["instances"][0]["runtime"][
            "immutable_values"
        ] = {"123": "0x" + ("ab" * 20)}
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("contains overlapping ranges")

    def test_rejects_forward_or_unknown_dependencies(self) -> None:
        instance = self.fixture.candidate["instances"][0]
        instance["depends_on"] = ["later-instance"]
        self.fixture.write_candidate()
        self.assert_materialization_fails(
            "must name an earlier candidate instance"
        )

    def test_check_output_detects_stale_output(self) -> None:
        plan = self.fixture.materialize()
        output = self.root / "tmp" / "plan.json"
        output = materializer.resolve_output_path(self.root, output)
        materializer.write_output(self.root, output, plan)
        materializer.check_output(output, plan)
        output.write_text(
            json.dumps(plan, separators=(",", ":")),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "is stale",
        ):
            materializer.check_output(output, plan)
        write_json(output, {"stale": True})
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "is stale",
        ):
            materializer.check_output(output, plan)

    def test_committed_candidate_and_schemas_are_strict_nonproduction(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        candidate_path = (
            repo_root
            / "deployments"
            / "config"
            / "canonical-deployment-candidate-non-production.json"
        )
        candidate = materializer.validate_candidate(
            materializer.load_json(candidate_path)
        )
        self.assertEqual(
            candidate["candidate_kind"],
            "non_production_fixture",
        )
        self.assertFalse(candidate["production_candidate"])
        self.assertFalse(candidate["readiness_evidence"])
        self.assertIsNone(candidate["instances"][0]["profile_entry_id"])
        self.assertEqual(
            candidate["instances"][0]["target"]["name"],
            "DependencyRegistry",
        )
        for name in (
            "canonical-deployment-candidate.schema.json",
            "canonical-deployment-plan.schema.json",
        ):
            value = materializer.load_json(
                repo_root / "deployments" / "schema" / name
            )
            self.assertEqual(
                value["$schema"],
                "https://json-schema.org/draft/2020-12/schema",
            )


if __name__ == "__main__":
    unittest.main()
