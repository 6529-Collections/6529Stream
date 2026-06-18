#!/usr/bin/env python3
"""Focused tests for ABI compatibility baseline checks."""

from __future__ import annotations

import importlib.util
import json
import os
import tempfile
import unittest
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Any, Iterator


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
                    "category": "functions",
                    "key": "balanceOf(address)",
                    "message": "Example removed functions entry balanceOf(address)",
                },
                report["incompatible_changes"],
            )

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

    def test_check_mode_detects_drift_without_rewriting_baseline(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_contract(root)
            config_path = self.write_config(root)
            baseline_path = self.write_baseline(root, config_path)
            original_baseline = baseline_path.read_text(encoding="utf-8")

            self.write_contract(
                root,
                abi=[
                    constructor_entry(),
                    event_entry(),
                    error_entry(),
                ],
            )

            with working_directory(root), redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--config",
                        str(config_path),
                        "--foundry-out",
                        str(root / "out"),
                        "--baseline",
                        str(baseline_path),
                        "--check",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertEqual(original_baseline, baseline_path.read_text(encoding="utf-8"))

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
            self.assertEqual(interface_additions[0]["contract"], "IExample")
            self.assertEqual(interface_additions[0]["key"], "totalSupply()")


if __name__ == "__main__":
    unittest.main(verbosity=2)
