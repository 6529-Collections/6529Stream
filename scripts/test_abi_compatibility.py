#!/usr/bin/env python3
"""Focused tests for ABI compatibility baseline checks."""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from copy import deepcopy
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Any, Iterator
from unittest.mock import patch


SCRIPT_PATH = Path(__file__).with_name("check_abi_compatibility.py")
SPEC = importlib.util.spec_from_file_location("check_abi_compatibility", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


@contextmanager
def working_directory(path: Path) -> Iterator[None]:
    old_cwd = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(old_cwd)


@contextmanager
def fixture_active_surface_lock(manifest: dict[str, Any]) -> Iterator[None]:
    """Bind both reviewer locks to a deliberately minimal schema-test fixture."""
    functions = tuple(
        (entry["signature"], entry["state_mutability"], tuple(entry["returns"]))
        for entry in manifest["functions"]
        if entry["status"] == "active_target"
    )
    events = tuple(
        (
            entry["signature"],
            tuple(entry["indexed"]),
            entry["anonymous"],
            entry["schema_version"],
        )
        for entry in manifest["events"]
        if entry["status"] == "active_target"
    )
    digest = checker.target_active_surface_lock_digest(functions, events)
    full_digest = checker.target_full_manifest_lock_digest(manifest)
    with patch.multiple(
        checker,
        TARGET_ACTIVE_FUNCTION_SURFACES=functions,
        TARGET_ACTIVE_EVENT_SURFACES=events,
        TARGET_ACTIVE_SURFACE_LOCK_SHA256=digest,
        TARGET_FULL_MANIFEST_LOCK_SHA256=full_digest,
    ):
        yield


def function_entry(
    name: str,
    inputs: list[dict[str, Any]] | None = None,
    outputs: list[dict[str, Any]] | None = None,
    state_mutability: str = "view",
) -> dict[str, Any]:
    return {
        "type": "function",
        "name": name,
        "inputs": inputs or [],
        "outputs": outputs or [],
        "stateMutability": state_mutability,
    }


def event_entry(indexed: bool = True) -> dict[str, Any]:
    return {
        "type": "event",
        "name": "ExampleEvent",
        "inputs": [
            {"name": "account", "type": "address", "indexed": indexed},
            {"name": "amount", "type": "uint256", "indexed": False},
        ],
        "anonymous": False,
    }


def error_entry() -> dict[str, Any]:
    return {
        "type": "error",
        "name": "ExampleError",
        "inputs": [{"name": "code", "type": "uint256"}],
    }


def constructor_entry() -> dict[str, Any]:
    return {
        "type": "constructor",
        "inputs": [{"name": "owner", "type": "address"}],
        "stateMutability": "nonpayable",
    }


class AbiCompatibilityTests(unittest.TestCase):
    def target_manifest_value(self) -> dict[str, Any]:
        return {
            "schema_version": "6529stream.stream-core-permanent-interface.v1",
            "artifact_role": "normative_external_interface_target",
            "contract": "StreamCore",
            "coverage": {
                "permanence_class": "Permanent",
                "completeness": "complete_permanent_functions_and_events",
                "bytecode_measurement_authority": "complete_linked_via_ir_runtime_measurement_only",
                "implementation_comparison": "deferred_until_complete_core_cutover",
                "implementation_baseline": "release-artifacts/baselines/v0.1.0/abi-surface.json",
                "excluded_abi_categories": [
                    "custom_errors",
                    "constructor",
                ],
                "required_absent_abi_categories": ["fallback", "receive"],
                "excluded_permanence_classes": ["Medium", "Replaceable"],
            },
            "bootstrap_bind_authority_challenge": deepcopy(
                checker.TARGET_BOOTSTRAP_BIND_AUTHORITY_CHALLENGE
            ),
            "bytecode_budget_groups": [
                {
                    "id": "example-group",
                    "description": "Example implementation requirement group",
                }
            ],
            "functions": [
                {
                    "id": "example-function",
                    "status": "active_target",
                    "bytecode_budget_group": "example-group",
                    "permanence_class": "Permanent",
                    "owner_subsystem": "StreamCore",
                    "interface_name": "IExample",
                    "authorization_model": "Public read",
                    "normative_home": "docs/spec.md#SPEC",
                    "signature": "example()",
                    "supersedes": [],
                    "replaced_by": [],
                    "retirement_disposition": None,
                    "replacement_owner": None,
                    "replacement_signature": None,
                    "retirement_rationale": None,
                    "selector": "0x54353f2f",
                    "returns": ["uint256"],
                    "state_mutability": "view",
                },
                {
                    "id": "core-update-satellite-pointer",
                    "status": "active_target",
                    "bytecode_budget_group": "example-group",
                    "permanence_class": "Permanent",
                    "owner_subsystem": "StreamCore",
                    "interface_name": "IStreamCoreSatellitePointers",
                    "authorization_model": "Immutable executor during an executing action",
                    "normative_home": "docs/spec.md#SPEC",
                    "signature": "updateSatellitePointer(bytes32,address)",
                    "supersedes": [],
                    "replaced_by": [],
                    "retirement_disposition": None,
                    "replacement_owner": None,
                    "replacement_signature": None,
                    "retirement_rationale": None,
                    "selector": "0xac1e5708",
                    "returns": [],
                    "state_mutability": "nonpayable",
                }
            ],
            "events": [
                {
                    "id": "example-event",
                    "status": "active_target",
                    "bytecode_budget_group": "example-group",
                    "permanence_class": "Permanent",
                    "owner_subsystem": "StreamCore",
                    "interface_name": "IExample",
                    "authorization_model": "Emitted after the example transition",
                    "normative_home": "docs/spec.md#SPEC",
                    "signature": "ExampleEvent(uint16,uint256)",
                    "supersedes": [],
                    "replaced_by": [],
                    "retirement_disposition": None,
                    "replacement_owner": None,
                    "replacement_signature": None,
                    "retirement_rationale": None,
                    "topic0": "0x19d5d40f2e4164d71b0caaae9056fe583ecdfc1ff872ae9c26f08fad017d1ba8",
                    "anonymous": False,
                    "indexed": [False, True],
                    "schema_version": 1,
                    "standard_interface": None,
                }
            ],
        }

    def write_target_manifest(
        self,
        root: Path,
        value: dict[str, Any] | None = None,
    ) -> Path:
        source_path = root / "docs" / "spec.md"
        source_path.parent.mkdir(parents=True, exist_ok=True)
        source_path.write_text("# Test specification [SPEC]\n", encoding="utf-8", newline="\n")
        manifest_path = root / "release-artifacts" / "stream-core-permanent-interface.json"
        write_json(manifest_path, value or self.target_manifest_value())
        return manifest_path

    def write_contract(
        self,
        root: Path,
        name: str = "Example",
        abi: list[dict[str, Any]] | None = None,
    ) -> None:
        write_json(
            root / "out" / f"{name}.sol" / f"{name}.json",
            {
                "abi": abi
                if abi is not None
                else [
                    constructor_entry(),
                    function_entry(
                        "balanceOf",
                        inputs=[{"name": "owner", "type": "address"}],
                        outputs=[{"name": "", "type": "uint256"}],
                    ),
                    event_entry(),
                    error_entry(),
                ],
                "bytecode": {"object": "0x6000"},
                "deployedBytecode": {"object": "0x6001"},
            },
        )

    def write_config(
        self,
        root: Path,
        names: list[str] | None = None,
        interface_names: list[str] | None = None,
    ) -> Path:
        config_path = root / "release-artifacts" / "contracts.json"
        write_json(
            config_path,
            {
                "schema_version": "6529stream.release-artifact-contracts.v1",
                "production_contracts": [
                    {"name": name, "source": f"smart-contracts/{name}.sol"}
                    for name in (names or ["Example"])
                ],
                "interfaces": [
                    {"name": name, "source": f"smart-contracts/{name}.sol"}
                    for name in (interface_names or [])
                ],
            },
        )
        return config_path

    def write_baseline(self, root: Path, config_path: Path) -> Path:
        baseline_path = root / "release-artifacts" / "baselines" / "v0.1.0" / "abi-surface.json"
        checker.write_baseline(root, config_path, root / "out", baseline_path)
        return baseline_path

    def release_receipt(
        self,
        root: Path,
        config_path: Path,
        names: list[str] | None = None,
        interface_names: list[str] | None = None,
    ) -> dict[str, Any]:
        targets = []
        for kind, target_names in (
            ("production_contract", names or ["Example"]),
            ("interface", interface_names or []),
        ):
            for name in target_names:
                artifact_path = root / "out" / f"{name}.sol" / f"{name}.json"
                targets.append(
                    {
                        "kind": kind,
                        "name": name,
                        "source": f"smart-contracts/{name}.sol",
                        "artifact_relative_path": f"{name}.sol/{name}.json",
                        "artifact_path": (
                            checker.release_artifacts.normalize_artifact_path(
                                artifact_path,
                                root,
                            )
                        ),
                        "artifact_sha256": checker.release_build.sha256_bytes(
                            artifact_path.read_bytes()
                        ),
                    }
                )
        return {
            "source": {
                "config": checker.release_artifacts.normalize_artifact_path(
                    config_path,
                    root,
                ),
                "config_sha256": checker.release_build.sha256_bytes(
                    config_path.read_bytes()
                ),
            },
            "targets": targets,
        }

    def assert_subject_contract_alias(self, change: dict[str, Any], subject: str) -> None:
        self.assertEqual(change["subject"], subject)
        self.assertEqual(change["contract"], subject)

    def test_identical_surface_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    checker.check_compatibility(root, config_path, root / "out", baseline_path),
                    0,
                )

    def test_receipt_bound_surface_rejects_post_validation_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            receipt = self.release_receipt(root, config_path)
            artifact_path = root / "out" / "Example.sol" / "Example.json"
            artifact = json.loads(artifact_path.read_text(encoding="utf-8"))
            artifact["deployedBytecode"]["object"] = "0x6002"
            write_json(artifact_path, artifact)

            with self.assertRaisesRegex(
                checker.release_artifacts.ArtifactError,
                "validated release receipt artifact hash is stale",
            ):
                checker.build_abi_surface(
                    root,
                    config_path,
                    root / "out",
                    receipt,
                )

    def test_additive_entries_are_reported_as_compatible(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                abi=[
                    constructor_entry(),
                    function_entry(
                        "balanceOf",
                        inputs=[{"name": "owner", "type": "address"}],
                        outputs=[{"name": "", "type": "uint256"}],
                    ),
                    function_entry("totalSupply", outputs=[{"name": "", "type": "uint256"}]),
                    event_entry(),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertTrue(report["compatible"])
            self.assertEqual(report["additive_changes"][0]["type"], "added_entry")
            self.assert_subject_contract_alias(report["additive_changes"][0], "Example")
            self.assertEqual(report["additive_changes"][0]["key"], "totalSupply()")

    def test_removed_entry_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                abi=[
                    constructor_entry(),
                    event_entry(),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assertIn(
                {
                    "type": "removed_entry",
                    "surface": "contracts",
                    "contract": "Example",
                    "subject": "Example",
                    "category": "functions",
                    "key": "balanceOf(address)",
                    "message": "Example removed functions entry balanceOf(address)",
                },
                report["incompatible_changes"],
            )

    def test_contract_diagnostics_keep_deprecated_contract_alias(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root, "Example")
            self.write_contract(root, "Other")
            baseline_config = self.write_config(root, ["Example", "Other"])
            baseline_path = self.write_baseline(root, baseline_config)
            current_config = self.write_config(root, ["Example"])

            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, current_config, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assert_subject_contract_alias(report["incompatible_changes"][0], "Other")

    def test_changed_entry_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                abi=[
                    constructor_entry(),
                    function_entry(
                        "balanceOf",
                        inputs=[{"name": "owner", "type": "address"}],
                        outputs=[{"name": "", "type": "uint256"}],
                    ),
                    event_entry(indexed=False),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            changed = [
                change
                for change in report["incompatible_changes"]
                if change["type"] == "changed_entry"
            ]
            self.assertEqual(changed[0]["key"], "ExampleEvent(address,uint256)")
            self.assertEqual(changed[0]["category"], "events")

    def test_removed_contract_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root, "Example")
            self.write_contract(root, "Other")
            baseline_config = self.write_config(root, ["Example", "Other"])
            baseline_path = self.write_baseline(root, baseline_config)
            current_config = self.write_config(root, ["Example"])

            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, current_config, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assertEqual(report["incompatible_changes"][0]["type"], "removed_contract")
            self.assertEqual(report["incompatible_changes"][0]["contract"], "Other")
            self.assertEqual(report["incompatible_changes"][0]["subject"], "Other")

    def test_check_mode_detects_drift_without_rewriting_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)
            target_manifest = self.target_manifest_value()
            target_manifest_path = self.write_target_manifest(root, target_manifest)
            original_baseline = baseline_path.read_text(encoding="utf-8")

            self.write_contract(
                root,
                abi=[
                    constructor_entry(),
                    event_entry(),
                    error_entry(),
                ],
            )

            with (
                fixture_active_surface_lock(target_manifest),
                working_directory(root),
                redirect_stdout(StringIO()),
                redirect_stderr(StringIO()),
            ):
                result = checker.main(
                    [
                        "--config",
                        str(config_path),
                        "--foundry-out",
                        str(root / "out"),
                        "--baseline",
                        str(baseline_path),
                        "--target-manifest",
                        str(target_manifest_path),
                        "--check",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertEqual(original_baseline, baseline_path.read_text(encoding="utf-8"))

    def test_target_only_does_not_require_or_rewrite_implementation_artifacts(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            target_manifest = self.target_manifest_value()
            target_manifest_path = self.write_target_manifest(root, target_manifest)
            original = target_manifest_path.read_bytes()

            with (
                fixture_active_surface_lock(target_manifest),
                working_directory(root),
                redirect_stdout(StringIO()) as stdout,
            ):
                result = checker.main(
                    ["--target-manifest", str(target_manifest_path), "--target-only"]
                )

            self.assertEqual(result, 0)
            self.assertIn("Permanent function/event interface target is valid", stdout.getvalue())
            self.assertEqual(original, target_manifest_path.read_bytes())
            self.assertFalse((root / "out").exists())
            self.assertFalse(
                (root / "release-artifacts" / "baselines" / "v0.1.0" / "abi-surface.json").exists()
            )

    def test_target_strict_json_loader_rejects_ambiguous_or_non_ijson_input(self) -> None:
        cases = (
            ("duplicate member", b'{"contract":"AttackerCore","contract":"StreamCore"}', "duplicate JSON member"),
            ("nonfinite number", b'{"value":NaN}', "non-I-JSON token"),
            ("floating number", b'{"value":1.5}', "floating-point JSON is forbidden"),
            (
                "unsafe integer",
                b'{"value":9007199254740992}',
                "outside the I-JSON interoperable range",
            ),
            ("invalid UTF-8", b'{"value":"\xff"}', "not strict UTF-8 JSON"),
        )
        for label, raw, diagnostic in cases:
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp_dir:
                path = Path(temp_dir) / "target.json"
                path.write_bytes(raw)
                with self.assertRaisesRegex(checker.AbiCompatibilityError, diagnostic):
                    checker.load_strict_json(path)

    def test_config_and_baseline_use_the_strict_json_loader(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            baseline_path = root / "baseline.json"
            baseline_path.write_text(
                '{"schema_version":"wrong","schema_version":"'
                + checker.ABI_SURFACE_SCHEMA
                + '","contracts":{},"interfaces":{}}',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                "duplicate JSON member",
            ):
                checker.load_baseline(baseline_path)

            config_path = root / "contracts.json"
            config_path.write_text(
                '{"production_contracts":[],"production_contracts":[],"interfaces":[]}',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                "duplicate JSON member",
            ):
                checker.build_abi_surface(root, config_path, root / "out")

    def test_target_manifest_rejects_selector_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            value["functions"][0]["selector"] = "0x00000000"
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(checker.AbiCompatibilityError, "derived selector"):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_target_manifest_rejects_bootstrap_bind_authority_challenge_drift(self) -> None:
        mutations = {
            "call mode": ("call_mode", "call"),
            "authorized error selector": (
                "authorized_no_action_error_selector",
                "0x00000000",
            ),
            "check order": (
                "required_check_order",
                [
                    "argument_validation",
                    "immutable_executor_caller",
                    "executing_current_action",
                ],
            ),
            "accepted outcome": ("accepted_outcome", "any_revert"),
        }
        for label, (field, replacement) in mutations.items():
            with self.subTest(label=label), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                value = self.target_manifest_value()
                value["bootstrap_bind_authority_challenge"][field] = replacement
                target_manifest_path = self.write_target_manifest(root, value)

                with self.assertRaisesRegex(
                    checker.AbiCompatibilityError,
                    "write-impossible genesis authority challenge",
                ):
                    checker.validate_target_manifest(root, target_manifest_path)

    def test_target_manifest_requires_challenged_writer_in_active_surface(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            value["functions"] = [
                entry
                for entry in value["functions"]
                if entry["signature"] != "updateSatellitePointer(bytes32,address)"
            ]
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                "references missing active function",
            ):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_target_manifest_rejects_event_topic_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            value["events"][0]["topic0"] = "0x" + ("00" * 32)
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(checker.AbiCompatibilityError, "derived topic"):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_target_manifest_rejects_unknown_bytecode_budget_group(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            value["functions"][0]["bytecode_budget_group"] = "not-in-catalog"
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(checker.AbiCompatibilityError, "unknown group"):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_target_manifest_rejects_phantom_bytecode_budget_group(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            value["bytecode_budget_groups"].append(
                {
                    "id": "phantom-group",
                    "description": "No active entry maps to this group",
                }
            )
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(checker.AbiCompatibilityError, "phantom groups"):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_target_required_absence_rejects_fallback_and_receive(self) -> None:
        manifest = self.target_manifest_value()
        for category, entry_category in (("fallback", "fallbacks"), ("receive", "receives")):
            with self.subTest(category=category):
                surface = {
                    "contracts": {
                        "StreamCore": {
                            "entries": {
                                "fallbacks": [],
                                "receives": [],
                            }
                        }
                    }
                }
                surface["contracts"]["StreamCore"]["entries"][entry_category] = [
                    {"kind": category}
                ]
                with self.assertRaisesRegex(
                    checker.AbiCompatibilityError,
                    f"category '{category}' to be absent",
                ):
                    checker.validate_target_required_absence(manifest, surface)

    def test_check_mode_rejects_additive_fallback_required_absent_by_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            baseline_abi = [function_entry("example")]
            self.write_contract(root, "StreamCore", abi=baseline_abi)
            config_path = self.write_config(root, names=["StreamCore"])
            baseline_path = self.write_baseline(root, config_path)
            self.write_contract(
                root,
                "StreamCore",
                abi=baseline_abi
                + [{"type": "fallback", "stateMutability": "payable"}],
            )

            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                "category 'fallback' to be absent",
            ):
                checker.check_compatibility(
                    root,
                    config_path,
                    root / "out",
                    baseline_path,
                    self.target_manifest_value(),
                )

    def test_target_manifest_rejects_broken_retirement_lineage(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            value = self.target_manifest_value()
            retired = deepcopy(value["functions"][0])
            retired.update(
                {
                    "id": "retired-example-function",
                    "status": "retired_pre_genesis",
                    "bytecode_budget_group": None,
                    "permanence_class": "NotPermanentPreGenesis",
                    "signature": "legacyExample()",
                    "selector": "0x4e440d8f",
                    "supersedes": [],
                    "replaced_by": ["example-function"],
                    "retirement_disposition": "replaced_in_core",
                    "replacement_owner": "StreamCore",
                    "replacement_signature": None,
                    "retirement_rationale": "The legacy read is replaced before genesis.",
                }
            )
            value["functions"].append(retired)
            target_manifest_path = self.write_target_manifest(root, value)

            with self.assertRaisesRegex(checker.AbiCompatibilityError, "lacks inverse"):
                checker.validate_target_manifest(root, target_manifest_path)

    def test_committed_target_declares_complete_permanent_function_event_scope(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        target_path = repo_root / checker.DEFAULT_TARGET_MANIFEST

        manifest = checker.validate_target_manifest(repo_root, target_path)

        active_functions = [
            entry for entry in manifest["functions"] if entry["status"] == "active_target"
        ]
        active_events = [
            entry for entry in manifest["events"] if entry["status"] == "active_target"
        ]
        self.assertEqual(manifest["coverage"]["completeness"], "complete_permanent_functions_and_events")
        self.assertEqual(len(active_functions), 53)
        self.assertEqual(len(active_events), 18)
        self.assertIn("custom_errors", manifest["coverage"]["excluded_abi_categories"])
        self.assertEqual(
            manifest["coverage"]["required_absent_abi_categories"],
            ["fallback", "receive"],
        )
        self.assertEqual(
            manifest["bootstrap_bind_authority_challenge"],
            checker.TARGET_BOOTSTRAP_BIND_AUTHORITY_CHALLENGE,
        )
        catalog_ids = {group["id"] for group in manifest["bytecode_budget_groups"]}
        self.assertEqual(
            catalog_ids,
            {
                "burn-and-retention",
                "collection-management",
                "erc165-interface-discovery",
                "erc2981-royalties",
                "erc721-metadata",
                "erc721-ownership-and-approvals",
                "erc7572-contract-metadata",
                "gas-parameters",
                "metadata-refresh",
                "mint-boundary",
                "satellite-pointers",
                "token-identity-and-supply",
            },
        )
        used_ids = {
            entry["bytecode_budget_group"]
            for entry in active_functions + active_events
        }
        self.assertEqual(used_ids, catalog_ids)
        self.assertTrue(
            all(
                entry["bytecode_budget_group"] is None
                for entry in manifest["functions"] + manifest["events"]
                if entry["status"] == "retired_pre_genesis"
            )
        )

    def test_committed_target_active_surface_matches_reviewed_fixed_digest(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )

        self.assertEqual(
            checker.target_active_surface_lock_digest(
                checker.TARGET_ACTIVE_FUNCTION_SURFACES,
                checker.TARGET_ACTIVE_EVENT_SURFACES,
            ),
            checker.TARGET_ACTIVE_SURFACE_LOCK_SHA256,
        )
        checker.validate_target_active_surface_lock(
            manifest["functions"],
            manifest["events"],
            "committed target",
        )

    def test_active_surface_lock_rejects_status_substitution(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        functions = deepcopy(manifest["functions"])
        target = next(
            entry for entry in functions if entry["signature"] == "burn(uint256)"
        )
        target["status"] = "retired_pre_genesis"

        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "independent active target surface lock",
        ):
            checker.validate_target_active_surface_lock(
                functions,
                manifest["events"],
                "status-substituted target",
            )

    def test_active_surface_lock_rejects_dummy_event_replacement(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        events = deepcopy(manifest["events"])
        target = next(
            entry
            for entry in events
            if entry["signature"] == "Transfer(address,address,uint256)"
        )
        target["signature"] = "DummyTransfer(address,address,uint256)"

        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "independent active target surface lock",
        ):
            checker.validate_target_active_surface_lock(
                manifest["functions"],
                events,
                "dummy-replaced target",
            )

    def test_active_surface_lock_rejects_anonymous_event(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        events = deepcopy(manifest["events"])
        target = next(
            entry
            for entry in events
            if entry["signature"] == "Transfer(address,address,uint256)"
        )
        target["anonymous"] = True

        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "independent active target surface lock",
        ):
            checker.validate_target_active_surface_lock(
                manifest["functions"],
                events,
                "anonymous-event target",
            )

    def test_active_surface_lock_rejects_schema_version_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        events = deepcopy(manifest["events"])
        target = next(
            entry
            for entry in events
            if entry["signature"]
            == "CollectionBurnsBlocked(uint16,uint256,bytes32)"
        )
        target["schema_version"] = 65_535

        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "independent active target surface lock",
        ):
            checker.validate_target_active_surface_lock(
                manifest["functions"],
                events,
                "schema-version-drifted target",
            )

    def test_active_surface_lock_rejects_shape_and_order_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.release_artifacts.load_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        functions = deepcopy(manifest["functions"])
        target = next(
            entry
            for entry in functions
            if entry["signature"] == "balanceOf(address)"
        )
        target["returns"] = ["uint128"]
        functions[0], functions[1] = functions[1], functions[0]

        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "independent active target surface lock",
        ):
            checker.validate_target_active_surface_lock(
                functions,
                manifest["events"],
                "shape/order-drifted target",
            )

    def test_full_manifest_lock_rejects_retired_and_security_metadata_drift(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.load_strict_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        self.assertEqual(
            checker.target_full_manifest_lock_digest(manifest),
            checker.TARGET_FULL_MANIFEST_LOCK_SHA256,
        )

        def delete_retired(candidate: dict[str, Any]) -> None:
            target = next(
                entry
                for entry in candidate["functions"]
                if entry["status"] == "retired_pre_genesis"
                and not entry["replaced_by"]
            )
            candidate["functions"].remove(target)

        def add_retired(candidate: dict[str, Any]) -> None:
            target = deepcopy(
                next(
                    entry
                    for entry in candidate["functions"]
                    if entry["status"] == "retired_pre_genesis"
                    and not entry["replaced_by"]
                )
            )
            target["id"] = target["id"] + "-phantom"
            candidate["functions"].append(target)

        def change_authorization(candidate: dict[str, Any]) -> None:
            next(
                entry
                for entry in candidate["functions"]
                if entry["signature"] == "burn(uint256)"
            )["authorization_model"] = "Permissionless public write"

        def change_budget_group(candidate: dict[str, Any]) -> None:
            next(
                entry
                for entry in candidate["functions"]
                if entry["signature"] == "burn(uint256)"
            )["bytecode_budget_group"] = "collection-management"

        def change_standard_interface(candidate: dict[str, Any]) -> None:
            next(
                entry
                for entry in candidate["events"]
                if entry["signature"] == "Transfer(address,address,uint256)"
            )["standard_interface"] = "IERC1155"

        for label, mutate in (
            ("retired deletion", delete_retired),
            ("retired addition", add_retired),
            ("authorization", change_authorization),
            ("budget group", change_budget_group),
            ("standard interface", change_standard_interface),
        ):
            with self.subTest(label=label):
                candidate = deepcopy(manifest)
                mutate(candidate)
                with self.assertRaisesRegex(
                    checker.AbiCompatibilityError,
                    "complete reviewer-pinned target semantic lock",
                ):
                    checker.validate_target_full_manifest_lock(
                        candidate,
                        f"{label} target",
                    )

    def test_retired_catalog_closes_both_directions_against_current_baseline(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.load_strict_json(
            repo_root / checker.DEFAULT_TARGET_MANIFEST
        )
        baseline = checker.load_baseline(repo_root / checker.DEFAULT_BASELINE)
        checker.validate_target_retirement_baseline_closure(manifest, baseline)

        missing = deepcopy(manifest)
        target = next(
            entry
            for entry in missing["functions"]
            if entry["status"] == "retired_pre_genesis"
            and not entry["replaced_by"]
            and entry["signature"]
            not in {
                active["signature"]
                for active in missing["functions"]
                if active["status"] == "active_target"
            }
        )
        missing["functions"].remove(target)
        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "missing retirement dispositions",
        ):
            checker.validate_target_retirement_baseline_closure(missing, baseline)

        phantom = deepcopy(manifest)
        target = deepcopy(
            next(
                entry
                for entry in phantom["functions"]
                if entry["status"] == "retired_pre_genesis"
            )
        )
        target["signature"] = "phantomLegacySurface(uint256)"
        phantom["functions"].append(target)
        with self.assertRaisesRegex(
            checker.AbiCompatibilityError,
            "absent from the implementation baseline",
        ):
            checker.validate_target_retirement_baseline_closure(phantom, baseline)

    def test_committed_target_defers_external_facade_and_locks_refresh_surface(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.validate_target_manifest(
            repo_root,
            repo_root / checker.DEFAULT_TARGET_MANIFEST,
        )

        function_by_signature = {
            entry["signature"]: entry
            for entry in manifest["functions"]
            if entry["status"] == "active_target"
        }
        event_by_signature = {
            entry["signature"]: entry
            for entry in manifest["events"]
            if entry["status"] == "active_target"
        }

        deferred_functions = {
            "collectionIdentityMode(uint256)",
            "collectionTransferController(uint256)",
            "declareCollectionIdentityMode(uint256,bytes32)",
            "registerCollectionTransferController(uint256,address)",
            "controlledOwnershipChange(uint256,uint256,address,address,bytes)",
        }
        deferred_events = {
            "CollectionIdentityModeDeclared(uint16,uint256,bytes32,bytes32)",
            "CollectionTransferControllerRegistered(uint16,uint256,address,bytes32)",
            "ControlledOwnershipChanged(uint16,address,address,uint256,uint256,uint256)",
        }
        self.assertTrue(deferred_functions.isdisjoint(function_by_signature))
        self.assertTrue(deferred_events.isdisjoint(event_by_signature))
        satellite_manifest_functions = {
            "publishStreamSystemManifest(address,(bytes32,string,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32))",
            "streamSystemManifest()",
            "streamSystemManifestPointer()",
            "streamSystemManifestPointerAt(uint256)",
            "streamSystemManifestPointerCount()",
        }
        self.assertTrue(satellite_manifest_functions.isdisjoint(function_by_signature))
        self.assertNotIn(
            "StreamSystemManifestPublished(uint16,bytes32,address,bytes32)",
            event_by_signature,
        )
        self.assertNotIn(
            "MetadataRouterUpdated(uint16,address,address,bytes32)",
            event_by_signature,
        )

        self.assertNotIn("STREAM_COLLECTION_CONFIG_STATE_V1()", function_by_signature)
        self.assertEqual(
            function_by_signature["lastAllocatedCollectionId()"]["normative_home"],
            "docs/launch-v1-target-architecture.md#PV1-IDENTITY",
        )
        self.assertEqual(
            function_by_signature["emitContractURIUpdated()"]["bytecode_budget_group"],
            "erc7572-contract-metadata",
        )
        self.assertEqual(
            event_by_signature["ContractURIUpdated()"]["bytecode_budget_group"],
            "erc7572-contract-metadata",
        )
        self.assertEqual(
            function_by_signature["emitBatchMetadataUpdate(uint256,uint256,bytes32)"][
                "authorization_model"
            ],
            "Current metadata router or current artwork finality registry only; entropy coordinators are never authorized",
        )
        self.assertEqual(
            function_by_signature["emitMetadataUpdate(uint256,bytes32)"][
                "authorization_model"
            ],
            "Current metadata router, current artwork finality registry, or exact nonzero coordinatorAtMint(tokenId); token lifecycle must be MINTED or BURNED",
        )
        for removed_signature in (
            "conditionalRaiseGasParameter(bytes32,uint256)",
            "conditionalRelowerGasParameter(bytes32,uint256)",
            "emergencyRaiseGasParameter(bytes32,uint256)",
            "lowerGasParameter(bytes32,uint256)",
            "rebindGasParameterProbe(bytes32,address)",
        ):
            self.assertNotIn(removed_signature, function_by_signature)
        self.assertNotIn(
            "GasParameterProbeRebound(uint16,bytes32,address,bytes32,address,address)",
            event_by_signature,
        )
        self.assertIn(
            "strict monotonic raise bounded to at most 2x per action",
            function_by_signature["raiseGasParameter(bytes32,uint256)"]["authorization_model"],
        )
        self.assertEqual(
            event_by_signature[
                "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)"
            ]["schema_version"],
            2,
        )
        self.assertEqual(
            function_by_signature["abortPreparedMintFromManager(uint256,bytes32)"][
                "authorization_model"
            ],
            "Caller equals current MINT_MANAGER and differs from stored preparingManager; exact tokenId and operationId; replacement-manager incident recovery only",
        )
        self.assertEqual(
            function_by_signature[
                "completePreparedMintFromManager(uint256,address,bytes32,bytes32)"
            ]["authorization_model"],
            "Caller equals current MINT_MANAGER and equals stored preparingManager; same non-reentrant manager execution; exact tokenId and operationId",
        )
        self.assertIn(
            "IERC7572 (0xe8a3d485)",
            function_by_signature["supportsInterface(bytes4)"]["authorization_model"],
        )

        refresh_event = event_by_signature[
            "StreamMetadataRefresh(uint16,bytes32,uint256,uint256)"
        ]
        self.assertEqual(
            refresh_event["topic0"],
            "0x167c8dd2305074833e7698077c46d5d3f848b5f53506dc2a72101a217c55bb04",
        )
        self.assertEqual(refresh_event["indexed"], [False, True, True, True])
        self.assertIs(refresh_event["anonymous"], False)
        self.assertEqual(refresh_event["schema_version"], 1)
        self.assertEqual(
            refresh_event["normative_home"],
            "docs/metadata-router-and-renderer.md#MRR-REFRESH-EMITTERS",
        )

    def test_committed_target_reconciles_normative_revision_return_tuples(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.validate_target_manifest(
            repo_root,
            repo_root / checker.DEFAULT_TARGET_MANIFEST,
        )
        normative = checker.normative_revision_return_tuples(repo_root)
        expected = {
            "gasParameterInfo(bytes32)": (
                "uint256",
                "uint256",
                "uint8",
                "uint64",
            ),
            "getSatellitePointer(bytes32)": (
                "address",
                "bytes32",
                "bool",
                "bytes32",
                "bytes4",
                "address",
                "uint8",
                "bytes32",
                "bytes32",
                "uint64",
            ),
        }
        self.assertEqual(
            {signature: normative[signature] for signature in expected},
            expected,
        )
        active_by_signature = {
            entry["signature"]: entry
            for entry in manifest["functions"]
            if entry["status"] == "active_target"
        }
        for signature, return_types in expected.items():
            with self.subTest(signature=signature):
                self.assertEqual(
                    tuple(active_by_signature[signature]["returns"]),
                    return_types,
                )

                mutated_functions = deepcopy(manifest["functions"])
                mutated_entry = next(
                    entry
                    for entry in mutated_functions
                    if entry["status"] == "active_target"
                    and entry["signature"] == signature
                )
                mutated_entry["returns"] = mutated_entry["returns"][:-1]
                with self.assertRaisesRegex(
                    checker.AbiCompatibilityError,
                    "does not match normative",
                ):
                    checker.validate_target_normative_revision_returns(
                        repo_root,
                        mutated_functions,
                        "mutated target",
                    )

    def test_committed_target_disposes_every_baseline_core_function_and_event(self) -> None:
        repo_root = SCRIPT_PATH.parent.parent
        manifest = checker.validate_target_manifest(
            repo_root,
            repo_root / checker.DEFAULT_TARGET_MANIFEST,
        )
        baseline = checker.load_baseline(repo_root / checker.DEFAULT_BASELINE)
        core_entries = baseline["contracts"]["StreamCore"]["entries"]

        manifest_functions: dict[str, list[dict[str, Any]]] = {}
        for entry in manifest["functions"]:
            manifest_functions.setdefault(entry["signature"], []).append(entry)
        for baseline_entry in core_entries["functions"]:
            matching = manifest_functions.get(baseline_entry["signature"], [])
            baseline_returns = [output["type"] for output in baseline_entry["outputs"]]
            self.assertTrue(
                any(
                    entry["returns"] == baseline_returns
                    and entry["state_mutability"] == baseline_entry["state_mutability"]
                    for entry in matching
                ),
                f"missing current Core function disposition for {baseline_entry['signature']}",
            )

        manifest_events = {entry["signature"]: entry for entry in manifest["events"]}
        for baseline_entry in core_entries["events"]:
            matching = manifest_events.get(baseline_entry["signature"])
            self.assertIsNotNone(
                matching,
                f"missing current Core event disposition for {baseline_entry['signature']}",
            )
            assert matching is not None
            self.assertEqual(
                matching["indexed"],
                [event_input["indexed"] for event_input in baseline_entry["inputs"]],
            )

    def test_baseline_includes_published_interfaces(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            config_path = self.write_config(root, interface_names=["IExample"])

            baseline = checker.build_abi_surface(root, config_path, root / "out")

            self.assertIn("Example", baseline["contracts"])
            self.assertIn("IExample", baseline["interfaces"])
            self.assertEqual(
                baseline["interfaces"]["IExample"]["source"],
                "smart-contracts/IExample.sol",
            )
            self.assertEqual(
                baseline["interfaces"]["IExample"]["entry_counts"]["functions"],
                1,
            )

    def test_removed_interface_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            baseline_config = self.write_config(root, interface_names=["IExample"])
            baseline_path = self.write_baseline(root, baseline_config)
            current_config = self.write_config(root, interface_names=[])

            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, current_config, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assertEqual(report["incompatible_changes"][0]["type"], "removed_interface")
            self.assertEqual(report["incompatible_changes"][0]["surface"], "interfaces")
            self.assertEqual(report["incompatible_changes"][0]["contract"], "IExample")
            self.assertEqual(report["incompatible_changes"][0]["subject"], "IExample")

    def test_removed_interface_entry_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            config_path = self.write_config(root, interface_names=["IExample"])
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                "IExample",
                abi=[
                    constructor_entry(),
                    event_entry(),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assertIn(
                {
                    "type": "removed_entry",
                    "surface": "interfaces",
                    "contract": "IExample",
                    "subject": "IExample",
                    "category": "functions",
                    "key": "balanceOf(address)",
                    "message": "IExample removed functions entry balanceOf(address)",
                },
                report["incompatible_changes"],
            )

    def test_changed_interface_entry_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            config_path = self.write_config(root, interface_names=["IExample"])
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                "IExample",
                abi=[
                    constructor_entry(),
                    function_entry(
                        "balanceOf",
                        inputs=[{"name": "owner", "type": "address"}],
                        outputs=[{"name": "", "type": "uint256"}],
                    ),
                    event_entry(indexed=False),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            changed = [
                change
                for change in report["incompatible_changes"]
                if change["type"] == "changed_entry" and change["surface"] == "interfaces"
            ]
            self.assertEqual(changed[0]["contract"], "IExample")
            self.assertEqual(changed[0]["subject"], "IExample")
            self.assertEqual(changed[0]["key"], "ExampleEvent(address,uint256)")
            self.assertEqual(changed[0]["category"], "events")

    def test_additive_interface_entries_are_reported_as_compatible(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            config_path = self.write_config(root, interface_names=["IExample"])
            baseline_path = self.write_baseline(root, config_path)

            self.write_contract(
                root,
                "IExample",
                abi=[
                    constructor_entry(),
                    function_entry(
                        "balanceOf",
                        inputs=[{"name": "owner", "type": "address"}],
                        outputs=[{"name": "", "type": "uint256"}],
                    ),
                    function_entry("totalSupply", outputs=[{"name": "", "type": "uint256"}]),
                    event_entry(),
                    error_entry(),
                ],
            )
            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, config_path, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertTrue(report["compatible"])
            interface_additions = [
                change
                for change in report["additive_changes"]
                if change["surface"] == "interfaces"
            ]
            self.assertEqual(interface_additions[0]["type"], "added_entry")
            self.assert_subject_contract_alias(interface_additions[0], "IExample")
            self.assertEqual(interface_additions[0]["key"], "totalSupply()")

    def test_added_interface_subject_diagnostics_keep_deprecated_contract_alias(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            baseline_config = self.write_config(root, interface_names=[])
            baseline_path = self.write_baseline(root, baseline_config)
            current_config = self.write_config(root, interface_names=["IExample"])

            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, current_config, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertTrue(report["compatible"])
            self.assertEqual(report["additive_changes"][0]["type"], "added_interface")
            self.assert_subject_contract_alias(report["additive_changes"][0], "IExample")

    def test_interface_diagnostics_keep_deprecated_contract_alias(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            self.write_contract(root, "IExample")
            baseline_config = self.write_config(root, interface_names=["IExample"])
            baseline_path = self.write_baseline(root, baseline_config)
            current_config = self.write_config(root, interface_names=[])

            baseline = checker.load_baseline(baseline_path)
            current = checker.build_abi_surface(root, current_config, root / "out")
            report = checker.compare_abi_surfaces(baseline, current)

            self.assertFalse(report["compatible"])
            self.assert_subject_contract_alias(report["incompatible_changes"][0], "IExample")

    def test_malformed_contract_config_entry_reports_abi_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = root / "release-artifacts" / "contracts.json"
            write_json(
                config_path,
                {
                    "schema_version": "6529stream.release-artifact-contracts.v1",
                    "production_contracts": [{"source": "smart-contracts/Example.sol"}],
                    "interfaces": [],
                },
            )

            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                r"config production_contracts\[0\] is missing a string name",
            ):
                checker.build_abi_surface(root, config_path, root / "out")

    def test_malformed_interface_config_entry_reports_abi_error(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = root / "release-artifacts" / "contracts.json"
            write_json(
                config_path,
                {
                    "schema_version": "6529stream.release-artifact-contracts.v1",
                    "production_contracts": [
                        {"name": "Example", "source": "smart-contracts/Example.sol"}
                    ],
                    "interfaces": [{"name": "IExample"}],
                },
            )

            with self.assertRaisesRegex(
                checker.AbiCompatibilityError,
                r"config interfaces\[0\] is missing a string source",
            ):
                checker.build_abi_surface(root, config_path, root / "out")


if __name__ == "__main__":
    unittest.main(verbosity=2)
