#!/usr/bin/env python3
"""Focused unit tests for the non-production deployment-plan materializer."""

from __future__ import annotations

import copy
import json
import re
import tempfile
import unittest
from dataclasses import replace
from pathlib import Path
from typing import Any
from unittest import mock

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
        source_root = Path(__file__).resolve().parents[1]
        for schema_path in (
            materializer.CANDIDATE_SCHEMA_PATH,
            materializer.PLAN_SCHEMA_PATH,
        ):
            write_json(
                root / schema_path,
                materializer.load_json(source_root / schema_path),
            )
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
                "restricted_source_roots": ["script", "test"],
                "portable_compiler_paths": {
                    "basePath": ".",
                    "includePaths": ["."],
                    "allowPaths": [".", "lib"],
                },
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

    def file_snapshot(
        self,
        path: Path,
    ) -> materializer.release_build.ReleaseFileSnapshot:
        resolved = path.resolve()
        raw = resolved.read_bytes()
        return materializer.release_build.ReleaseFileSnapshot(
            path=resolved,
            raw=raw,
            sha256=materializer.sha256_bytes(raw),
        )

    def validator(
        self,
        _repo_root: Path,
        config_path: Path,
        foundry_config_path: Path,
        _output_dir: Path,
    ) -> materializer.release_build.ValidatedReleaseOutput:
        return materializer.release_build.ValidatedReleaseOutput(
            receipt=copy.deepcopy(self.receipt),
            receipt_snapshot=self.file_snapshot(self.receipt_path),
            config_snapshot=self.file_snapshot(config_path),
            foundry_config_snapshot=self.file_snapshot(foundry_config_path),
            artifact_snapshots=(self.file_snapshot(self.artifact_path),),
        )

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

    def set_full_initcode_length(self, length: int) -> None:
        """Configure exact full initcode length without invoking a compiler."""
        encoded_args = materializer.encode_abi(["address"], [ADMIN_ADDRESS])
        creation_length = length - len(encoded_args)
        if creation_length < 1:
            raise AssertionError("fixture initcode must retain creation bytecode")
        creation = bytes.fromhex("60" * creation_length)
        runtime = bytes.fromhex("6100")
        self.artifact["bytecode"] = {
            "object": "0x" + creation.hex(),
            "linkReferences": {},
        }
        self.artifact["deployedBytecode"] = {
            "object": "0x" + runtime.hex(),
            "linkReferences": {},
            "immutableReferences": {},
        }
        instance = self.candidate["instances"][0]
        instance["libraries"] = []
        instance["runtime"] = {
            "immutable_values": {},
            "expected_keccak256": materializer.keccak256_hex(runtime),
        }
        instance["expected_initcode_keccak256"] = materializer.keccak256_hex(
            creation + encoded_args
        )
        self.rebind_artifact_and_receipt()


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
        self.assertEqual(
            first["generated_by"],
            "scripts/materialize_canonical_deployment_plan.py:3",
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

    def test_reads_each_bound_input_once_and_reuses_artifact_snapshot(
        self,
    ) -> None:
        duplicate = copy.deepcopy(self.fixture.candidate["instances"][0])
        duplicate["order"] = 2
        duplicate["instance_id"] = "fixture-copy"
        self.fixture.candidate["instances"].append(duplicate)
        self.fixture.write_candidate()

        tracked_paths = {
            self.fixture.candidate_path.resolve(),
            self.fixture.receipt_path.resolve(),
            (
                self.root / "release-artifacts" / "contracts.json"
            ).resolve(),
            (self.root / "foundry.toml").resolve(),
            self.fixture.artifact_path.resolve(),
        }
        read_counts = {path: 0 for path in tracked_paths}
        original_read_bytes = Path.read_bytes

        def counted_read_bytes(path: Path) -> bytes:
            resolved = path.resolve()
            if resolved in read_counts:
                read_counts[resolved] += 1
            return original_read_bytes(path)

        with mock.patch.object(
            Path,
            "read_bytes",
            new=counted_read_bytes,
        ):
            plan = self.fixture.materialize()

        self.assertEqual(len(plan["deployments"]), 2)
        self.assertEqual(
            read_counts,
            {path: 1 for path in tracked_paths},
        )

    def test_post_validation_disk_mutation_cannot_change_plan(self) -> None:
        expected = self.fixture.materialize()

        def validator_then_mutate(
            repo_root: Path,
            config_path: Path,
            foundry_config_path: Path,
            output_dir: Path,
        ) -> materializer.release_build.ValidatedReleaseOutput:
            validated = self.fixture.validator(
                repo_root,
                config_path,
                foundry_config_path,
                output_dir,
            )
            self.fixture.candidate_path.write_bytes(b"not-json")
            self.fixture.receipt_path.write_bytes(b"not-json")
            config_path.write_bytes(b"not-json")
            foundry_config_path.write_bytes(b"not-toml")
            self.fixture.artifact_path.write_bytes(b"not-json")
            return validated

        actual = materializer.materialize_deployment_plan(
            self.root,
            self.fixture.candidate_path,
            receipt_validator=validator_then_mutate,
        )
        self.assertEqual(actual, expected)

    def test_rejects_forged_release_snapshots(self) -> None:
        validated = self.fixture.validator(
            self.root,
            self.root / "release-artifacts" / "contracts.json",
            self.root / "foundry.toml",
            self.root / "out-release",
        )
        extra_path = (self.root / "out-release" / "extra.json").resolve()
        cases = (
            (
                "receipt path",
                replace(
                    validated,
                    receipt_snapshot=replace(
                        validated.receipt_snapshot,
                        path=extra_path,
                    ),
                ),
                "receipt snapshot path mismatch",
            ),
            (
                "receipt digest",
                replace(
                    validated,
                    receipt_snapshot=replace(
                        validated.receipt_snapshot,
                        sha256=ZERO_SHA256,
                    ),
                ),
                "receipt snapshot digest mismatch",
            ),
            (
                "parsed receipt",
                replace(
                    validated,
                    receipt={"forged": True},
                ),
                "receipt snapshot disagrees",
            ),
            (
                "missing artifact",
                replace(validated, artifact_snapshots=()),
                "snapshot set is incomplete",
            ),
            (
                "mutable artifact collection",
                replace(
                    validated,
                    artifact_snapshots=list(validated.artifact_snapshots),
                ),
                "snapshots are not an immutable tuple",
            ),
            (
                "duplicate artifact",
                replace(
                    validated,
                    artifact_snapshots=(
                        validated.artifact_snapshots[0],
                        validated.artifact_snapshots[0],
                    ),
                ),
                "snapshot set contains a duplicate path",
            ),
            (
                "unexpected artifact",
                replace(
                    validated,
                    artifact_snapshots=(
                        *validated.artifact_snapshots,
                        materializer.release_build.ReleaseFileSnapshot(
                            path=extra_path,
                            raw=b"{}\n",
                            sha256=materializer.sha256_bytes(b"{}\n"),
                        ),
                    ),
                ),
                "snapshot set contains an unexpected path",
            ),
        )
        for label, forged, pattern in cases:
            with self.subTest(label=label):
                with self.assertRaisesRegex(
                    materializer.DeploymentPlanError,
                    pattern,
                ):
                    materializer.materialize_deployment_plan(
                        self.root,
                        self.fixture.candidate_path,
                        receipt_validator=lambda *_args, result=forged: result,
                    )

    def test_strictly_decodes_carried_receipt_and_artifact_snapshots(
        self,
    ) -> None:
        duplicate_receipt = (
            b'{"schema_version":"one","schema_version":"two"}'
        )
        self.fixture.receipt_path.write_bytes(duplicate_receipt)
        self.fixture.candidate["release_build"]["receipt_sha256"] = (
            materializer.sha256_bytes(duplicate_receipt)
        )
        self.fixture.write_candidate()
        self.assert_materialization_fails("duplicate JSON member")

        self.fixture = MaterializerFixture(self.root / "artifact-json")
        duplicate_artifact = b'{"abi":[],"abi":[]}'
        self.fixture.artifact_path.write_bytes(duplicate_artifact)
        artifact_sha256 = materializer.sha256_bytes(duplicate_artifact)
        self.fixture.receipt["targets"][0][
            "artifact_sha256"
        ] = artifact_sha256
        self.fixture.candidate["instances"][0]["target"][
            "artifact_sha256"
        ] = artifact_sha256
        write_json(self.fixture.receipt_path, self.fixture.receipt)
        binding = self.fixture.candidate["release_build"]
        binding["receipt_sha256"] = materializer.file_sha256(
            self.fixture.receipt_path
        )
        binding["target_catalog_sha256"] = (
            materializer.target_catalog_sha256(self.fixture.receipt)
        )
        self.fixture.write_candidate()
        self.assert_materialization_fails("duplicate JSON member")

    def test_strictly_decodes_carried_config_snapshot(self) -> None:
        config_path = self.root / "release-artifacts" / "contracts.json"
        duplicate_config = b'{"targets":[],"targets":[]}'
        config_path.write_bytes(duplicate_config)
        config_sha256 = materializer.sha256_bytes(duplicate_config)
        self.fixture.receipt["source"]["config_sha256"] = config_sha256
        write_json(self.fixture.receipt_path, self.fixture.receipt)
        binding = self.fixture.candidate["release_build"]
        binding["config_sha256"] = config_sha256
        binding["receipt_sha256"] = materializer.file_sha256(
            self.fixture.receipt_path
        )
        self.fixture.write_candidate()

        self.assert_materialization_fails("duplicate JSON member")

    def test_strictly_decodes_unselected_artifact_snapshot(self) -> None:
        unselected_path = (
            self.root / "out-release" / "Unused.sol" / "Unused.json"
        )
        duplicate_artifact = b'{"abi":[],"abi":[]}'
        unselected_path.parent.mkdir(parents=True)
        unselected_path.write_bytes(duplicate_artifact)
        self.fixture.receipt["targets"].append(
            {
                "kind": "interface",
                "name": "Unused",
                "source": "smart-contracts/Unused.sol",
                "artifact_relative_path": "Unused.sol/Unused.json",
                "artifact_sha256": materializer.sha256_bytes(
                    duplicate_artifact
                ),
            }
        )
        write_json(self.fixture.receipt_path, self.fixture.receipt)
        binding = self.fixture.candidate["release_build"]
        binding["receipt_sha256"] = materializer.file_sha256(
            self.fixture.receipt_path
        )
        binding["target_catalog_sha256"] = (
            materializer.target_catalog_sha256(self.fixture.receipt)
        )
        self.fixture.write_candidate()
        validated = self.fixture.validator(
            self.root,
            self.root / "release-artifacts" / "contracts.json",
            self.root / "foundry.toml",
            self.root / "out-release",
        )
        validated = replace(
            validated,
            artifact_snapshots=(
                *validated.artifact_snapshots,
                self.fixture.file_snapshot(unselected_path),
            ),
        )

        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "duplicate JSON member",
        ):
            materializer.materialize_deployment_plan(
                self.root,
                self.fixture.candidate_path,
                receipt_validator=lambda *_args: validated,
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

    def test_abi_normalization_handles_nested_tuple_arrays(self) -> None:
        parameter = {
            "name": "_nested",
            "type": "tuple[][2]",
            "internalType": "struct Nested[2]",
            "components": [
                {"name": "count", "type": "uint8", "internalType": "uint8"},
                {
                    "name": "flags",
                    "type": "tuple[]",
                    "internalType": "struct Flag[]",
                    "components": [
                        {
                            "name": "account",
                            "type": "address",
                            "internalType": "address",
                        },
                        {
                            "name": "enabled",
                            "type": "bool",
                            "internalType": "bool",
                        },
                    ],
                },
            ],
        }
        value = [
            [["255", [[ADMIN_ADDRESS, True]]]],
            [[0, []], [1, [[OTHER_LIBRARY_ADDRESS, False]]]],
        ]
        canonical = materializer.canonical_abi_type(parameter, "input")
        self.assertEqual(canonical, "(uint8,(address,bool)[])[][2]")
        normalized = materializer.normalize_abi_value(
            parameter,
            value,
            "argument",
        )
        expected = materializer.encode_abi([canonical], [normalized])
        constructor = {
            "types": [canonical],
            "arguments": [value],
            "encoded_args_keccak256": materializer.keccak256_hex(expected),
        }
        canonical_types, encoded = materializer.encode_constructor(
            [parameter],
            constructor,
            "nested",
        )
        self.assertEqual(canonical_types, [canonical])
        self.assertEqual(encoded, expected)

    def test_abi_integer_width_bounds_fail_closed(self) -> None:
        cases = (
            ("uint8", 0, 0),
            ("uint8", "255", 255),
            ("int8", "-128", -128),
            ("int8", 127, 127),
        )
        for abi_type, value, expected in cases:
            with self.subTest(abi_type=abi_type, value=value):
                self.assertEqual(
                    materializer.normalize_abi_value(
                        {"type": abi_type},
                        value,
                        "argument",
                    ),
                    expected,
                )
        for abi_type, value in (
            ("uint8", -1),
            ("uint8", 256),
            ("int8", -129),
            ("int8", 128),
            ("uint7", 1),
            ("int264", 1),
        ):
            with self.subTest(abi_type=abi_type, value=value):
                with self.assertRaisesRegex(
                    materializer.DeploymentPlanError,
                    "outside|invalid ABI type",
                ):
                    materializer.normalize_abi_value(
                        {"type": abi_type},
                        value,
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
            "normalized portable forward-slash repository-relative path"
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

    def test_rejects_wrong_immutable_width_and_positions(self) -> None:
        runtime = self.fixture.artifact["deployedBytecode"]
        runtime["object"] = "0x61" + PLACEHOLDER + ("00" * 32) + "00"
        runtime["immutableReferences"] = {
            "123": [{"start": 21, "length": 32}]
        }
        instance = self.fixture.candidate["instances"][0]
        instance["runtime"]["immutable_values"] = {
            "123": "0x" + ("ab" * 31)
        }
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("must contain exactly 32 bytes")

        runtime["immutableReferences"] = {
            "123": [{"start": 54, "length": 1}]
        }
        instance["runtime"]["immutable_values"] = {"123": "0xab"}
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("in-bounds immutable reference")

    def test_rejects_overlapping_immutable_positions(self) -> None:
        runtime = self.fixture.artifact["deployedBytecode"]
        runtime["object"] = "0x61" + PLACEHOLDER + ("00" * 40)
        runtime["immutableReferences"] = {
            "123": [{"start": 21, "length": 20}],
            "124": [{"start": 40, "length": 10}],
        }
        instance = self.fixture.candidate["instances"][0]
        instance["runtime"]["immutable_values"] = {
            "123": "0x" + ("ab" * 20),
            "124": "0x" + ("cd" * 10),
        }
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("contains overlapping ranges")

    def test_rejects_wrong_library_positions_and_runtime_hash(self) -> None:
        self.fixture.artifact["bytecode"]["linkReferences"][
            "smart-contracts/FixtureLibrary.sol"
        ]["FixtureLibrary"][0]["length"] = 19
        self.fixture.rebind_artifact_and_receipt()
        self.assert_materialization_fails("20-byte in-bounds library link")

        self.fixture = MaterializerFixture(self.root / "runtime-hash")
        self.fixture.candidate["instances"][0]["runtime"][
            "expected_keccak256"
        ] = "0x" + ("0" * 64)
        self.fixture.write_candidate()
        self.assert_materialization_fails("expected runtime hash mismatch")

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

    def test_output_is_reparsed_before_atomic_replacement(self) -> None:
        output = materializer.resolve_output_path(
            self.root,
            self.root / "tmp" / "plan.json",
        )
        with mock.patch.object(
            materializer,
            "json_text",
            return_value='{"wrong":true}\n',
        ):
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "did not reparse",
            ):
                materializer.write_output(
                    self.root,
                    output,
                    {"expected": True},
                )
        self.assertFalse(output.exists())

    def test_strict_json_rejects_ambiguous_or_non_ijson_inputs(self) -> None:
        invalid_inputs = (
            (b'{"value":1,"value":2}', "duplicate JSON member"),
            (b'{"value":1.5}', "floating-point JSON is forbidden"),
            (
                b'{"value":9007199254740992}',
                "outside the I-JSON interoperable range",
            ),
            (b'{"value":"\\ud800"}', "non-Unicode-scalar surrogate"),
            (b'{"value":"\xff"}', "strict UTF-8 JSON"),
        )
        for raw, pattern in invalid_inputs:
            with self.subTest(pattern=pattern):
                with self.assertRaisesRegex(
                    materializer.DeploymentPlanError,
                    pattern,
                ):
                    materializer.decode_json_bytes(
                        raw,
                        self.root / "candidate.json",
                    )

    def test_repository_relative_paths_are_cross_platform_canonical(self) -> None:
        accepted = (
            "smart-contracts/Fixture.sol",
            ".hidden/Fixture.sol",
            "unicode/\N{SNOWMAN}.sol",
            "COM0.sol",
            "com10.sol",
            "LPT0",
            "lpt10.json",
            "CONSOLE.sol",
            "nulled/file",
            "directory/name .sol",
        )
        for value in accepted:
            with self.subTest(accepted=value):
                self.assertEqual(
                    materializer.require_safe_relative_path(value, "path"),
                    value,
                )

        rejected = [
            "/absolute",
            "C:/windows-drive",
            "../escape",
            "nested/../escape",
            "./prefixed",
            "nested/./file",
            "nested//file",
            "nested\\file",
            "nested/",
            ".",
            "..",
            "trailing.",
            "trailing ",
            "nested/trailing.",
            "nested/trailing ",
            "nested/alias. /file",
            "nested/alias /file",
        ]
        rejected.extend(f"nested/file{character}name" for character in '<>:"|?*')
        rejected.extend(
            f"nested/control{chr(codepoint)}name"
            for codepoint in (*range(0x20), 0x7F)
        )
        reserved_names = (
            "CON",
            "PRN",
            "AUX",
            "NUL",
            *(f"COM{index}" for index in range(1, 10)),
            *(f"LPT{index}" for index in range(1, 10)),
        )
        for name in reserved_names:
            rejected.extend(
                (
                    name,
                    name.lower() + ".json",
                    f"nested/{name.swapcase()}",
                    f"nested/{name} .json",
                    f"nested/{name}..json",
                )
            )

        for value in rejected:
            with self.subTest(value=value):
                with self.assertRaisesRegex(
                    materializer.DeploymentPlanError,
                    "normalized portable forward-slash "
                    "repository-relative path",
                ):
                    materializer.require_safe_relative_path(value, "path")

        repo_root = Path(__file__).resolve().parents[1]
        for schema_path in (
            materializer.CANDIDATE_SCHEMA_PATH,
            materializer.PLAN_SCHEMA_PATH,
        ):
            path_schema = materializer.load_json(repo_root / schema_path)[
                "$defs"
            ]["repo_path"]
            self.assertEqual(
                path_schema["pattern"],
                materializer.REPO_PATH_PATTERN,
            )
            materializer.Draft202012Validator.check_schema(path_schema)
            validator = materializer.Draft202012Validator(path_schema)
            for value in accepted:
                with self.subTest(schema=schema_path, accepted=value):
                    self.assertTrue(validator.is_valid(value))
            for value in rejected:
                with self.subTest(schema=schema_path, rejected=value):
                    self.assertFalse(validator.is_valid(value))

    def test_materialization_runs_real_draft_2020_12_validation(self) -> None:
        with mock.patch.object(
            materializer,
            "validate_draft_2020_12_schema",
            wraps=materializer.validate_draft_2020_12_schema,
        ) as validate_schema:
            plan = self.fixture.materialize()
        self.assertEqual(
            [call.args[3] for call in validate_schema.call_args_list],
            ["deployment candidate", "canonical deployment plan"],
        )

        invalid_candidate = copy.deepcopy(self.fixture.candidate)
        invalid_candidate["unexpected"] = True
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "deployment candidate does not satisfy its Draft 2020-12 schema",
        ):
            materializer.validate_draft_2020_12_schema(
                self.root,
                materializer.CANDIDATE_SCHEMA_PATH,
                invalid_candidate,
                "deployment candidate",
            )

        invalid_plan = copy.deepcopy(plan)
        invalid_plan["generated_by"] = "unreviewed-generator"
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "canonical deployment plan does not satisfy its "
            "Draft 2020-12 schema",
        ):
            materializer.validate_draft_2020_12_schema(
                self.root,
                materializer.PLAN_SCHEMA_PATH,
                invalid_plan,
                "canonical deployment plan",
            )

    def test_draft_2020_12_validation_fails_closed_without_dependency(
        self,
    ) -> None:
        with mock.patch.object(
            materializer,
            "Draft202012Validator",
            None,
        ):
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "pinned jsonschema toolchain dependency",
            ):
                materializer.validate_draft_2020_12_schema(
                    self.root,
                    materializer.CANDIDATE_SCHEMA_PATH,
                    self.fixture.candidate,
                    "deployment candidate",
                )

    def test_draft_2020_12_validation_rejects_invalid_schema(self) -> None:
        schema_path = self.root / materializer.CANDIDATE_SCHEMA_PATH
        schema = materializer.load_json(schema_path)
        schema["type"] = 42
        write_json(schema_path, schema)
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "schema is not valid Draft 2020-12",
        ):
            materializer.validate_draft_2020_12_schema(
                self.root,
                materializer.CANDIDATE_SCHEMA_PATH,
                self.fixture.candidate,
                "deployment candidate",
            )

    def test_eip3860_full_initcode_boundary(self) -> None:
        self.fixture.set_full_initcode_length(
            materializer.EIP3860_MAX_INITCODE_SIZE
        )
        deployment = self.fixture.materialize()["deployments"][0]
        self.assertEqual(
            deployment["initcode_length_bytes"],
            materializer.EIP3860_MAX_INITCODE_SIZE,
        )

        self.fixture.set_full_initcode_length(
            materializer.EIP3860_MAX_INITCODE_SIZE + 1
        )
        self.assert_materialization_fails("exceeding the EIP-3860 limit")

    def test_repository_gates_run_real_candidate_after_canonical_build(
        self,
    ) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        makefile = (repo_root / "Makefile").read_text(encoding="utf-8")
        self.assertIn(
            "canonical-deployment-plan-check: release-build-check",
            makefile,
        )
        self.assertIn(
            "check: canonical-deployment-plan-check",
            makefile,
        )
        self.assertIn(
            "tmp/canonical-deployment-plan.json",
            (repo_root / ".gitignore").read_text(encoding="utf-8"),
        )
        for token in (
            "scripts/test_materialize_canonical_deployment_plan.py",
            "scripts/materialize_canonical_deployment_plan.py --candidate "
            "deployments/config/canonical-deployment-candidate-non-production.json "
            "--output tmp/canonical-deployment-plan.json",
            "--output tmp/canonical-deployment-plan.json --check",
        ):
            self.assertIn(token, makefile)

        shell = (repo_root / "scripts" / "check.sh").read_text(
            encoding="utf-8"
        )
        release_at = shell.index(
            '"$python_bin" scripts/build_release_artifacts.py --check'
        )
        unit_at = shell.index(
            '"$python_bin" scripts/test_materialize_canonical_deployment_plan.py'
        )
        write_at = shell.index(
            '"$python_bin" scripts/materialize_canonical_deployment_plan.py '
            "--candidate",
            unit_at,
        )
        check_at = shell.index(
            "--output tmp/canonical-deployment-plan.json --check",
            write_at,
        )
        self.assertLess(release_at, unit_at)
        self.assertLess(unit_at, write_at)
        self.assertLess(write_at, check_at)

        powershell = (repo_root / "scripts" / "check.ps1").read_text(
            encoding="utf-8"
        )
        release_at = powershell.index(
            '"scripts\\build_release_artifacts.py" "--check"'
        )
        unit_at = powershell.index(
            '"scripts\\test_materialize_canonical_deployment_plan.py"'
        )
        write_at = powershell.index(
            '"scripts\\materialize_canonical_deployment_plan.py" "--candidate"',
            unit_at,
        )
        check_at = powershell.index(
            '"tmp\\canonical-deployment-plan.json" "--check"',
            write_at,
        )
        self.assertLess(release_at, unit_at)
        self.assertLess(unit_at, write_at)
        self.assertLess(write_at, check_at)

        workflow = (
            repo_root / ".github" / "workflows" / "ci.yml"
        ).read_text(encoding="utf-8")
        release_at = workflow.index("- name: Canonical release build")
        gate_at = workflow.index(
            "- name: Canonical deployment plan (non-production fixture)"
        )
        size_at = workflow.index("- name: Contract size budget", gate_at)
        self.assertLess(release_at, gate_at)
        self.assertLess(gate_at, size_at)
        block = workflow[gate_at:size_at]
        self.assertLess(
            block.index("test_materialize_canonical_deployment_plan.py"),
            block.index(
                "materialize_canonical_deployment_plan.py --candidate"
            ),
        )
        self.assertIn(
            "--output tmp/canonical-deployment-plan.json --check",
            block,
        )

    def test_committed_candidate_and_schemas_are_strict_nonproduction(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        candidate_path = (
            repo_root
            / "deployments"
            / "config"
            / "canonical-deployment-candidate-non-production.json"
        )
        candidate_value = materializer.load_json(candidate_path)
        materializer.validate_draft_2020_12_schema(
            repo_root,
            materializer.CANDIDATE_SCHEMA_PATH,
            candidate_value,
            "committed deployment candidate",
        )
        candidate = materializer.validate_candidate(candidate_value)
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

        candidate_schema = materializer.load_json(
            repo_root
            / "deployments"
            / "schema"
            / "canonical-deployment-candidate.schema.json"
        )
        plan_schema = materializer.load_json(
            repo_root
            / "deployments"
            / "schema"
            / "canonical-deployment-plan.schema.json"
        )
        candidate_defs = candidate_schema["$defs"]
        plan_defs = plan_schema["$defs"]
        candidate_network = candidate_schema["properties"]["network"][
            "properties"
        ]
        self.assertEqual(
            candidate_network["chain_id"]["maximum"],
            materializer.IJSON_SAFE_INTEGER_MAX,
        )
        self.assertEqual(
            plan_schema["properties"]["deployments"]["items"]["$ref"],
            "#/$defs/deployment",
        )
        self.assertEqual(
            plan_defs["deployment"]["properties"]["initcode_length_bytes"][
                "maximum"
            ],
            materializer.EIP3860_MAX_INITCODE_SIZE,
        )
        self.assertEqual(
            plan_defs["library_position"]["properties"]["length"]["const"],
            20,
        )
        for repo_path in (candidate_defs["repo_path"], plan_defs["repo_path"]):
            self.assertEqual(
                repo_path["pattern"],
                materializer.REPO_PATH_PATTERN,
            )
            pattern = re.compile(repo_path["pattern"])
            self.assertIsNotNone(pattern.fullmatch("contracts/Fixture.sol"))
            for rejected in (
                "../x",
                "x//y",
                "x/./y",
                "C:/x",
                "x/file:stream",
                "x\\y",
                "x/CON.json",
                "x/Lpt9",
                "x/name.",
                "x/name ",
                "x/control\u007fname",
            ):
                self.assertIsNone(pattern.fullmatch(rejected))


if __name__ == "__main__":
    unittest.main()
