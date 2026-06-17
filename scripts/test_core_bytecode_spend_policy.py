#!/usr/bin/env python3
"""Focused tests for the StreamCore bytecode-spend policy checker."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("check_core_bytecode_spend_policy.py")
SPEC = importlib.util.spec_from_file_location("check_core_bytecode_spend_policy", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)

SIZE_SCRIPT_PATH = Path(__file__).with_name("check_contract_size_budget.py")
SIZE_SPEC = importlib.util.spec_from_file_location("check_contract_size_budget", SIZE_SCRIPT_PATH)
assert SIZE_SPEC is not None and SIZE_SPEC.loader is not None
size_checker = importlib.util.module_from_spec(SIZE_SPEC)
SIZE_SPEC.loader.exec_module(size_checker)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def runtime_hex(size_bytes: int) -> str:
    return "0x" + ("60" * size_bytes)


def write_source(root: Path, source: str) -> None:
    source_path = root / source
    source_path.parent.mkdir(parents=True, exist_ok=True)
    source_path.write_text(
        "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\ncontract StreamCore {}\n",
        encoding="utf-8",
        newline="\n",
    )


def artifact_metadata(root: Path, source: str) -> dict[str, Any]:
    normalized_source = Path(source).as_posix()
    return {
        "compiler": {"version": size_checker.EXPECTED_SOLC_VERSION},
        "language": "Solidity",
        "settings": {
            "compilationTarget": {normalized_source: "StreamCore"},
            "evmVersion": size_checker.EXPECTED_EVM_VERSION,
            "optimizer": {"enabled": True, "runs": size_checker.EXPECTED_OPTIMIZER_RUNS},
        },
        "sources": {
            normalized_source: {
                "keccak256": size_checker.keccak256_hex((root / normalized_source).read_bytes())
            }
        },
        "version": 1,
    }


def write_tree(
    root: Path,
    *,
    runtime_size: int = 22_184,
    approved_size: int = 22_184,
    exceptions: list[dict[str, Any]] | None = None,
    include_policy: bool = True,
) -> None:
    source = "smart-contracts/StreamCore.sol"
    write_source(root, source)
    config: dict[str, Any] = {
        "schema_version": "6529stream.release-artifact-contracts.v1",
        "production_contracts": [{"name": "StreamCore", "source": source}],
        "runtime_size_budget": {
            "schema_version": size_checker.BUDGET_SCHEMA,
            "eip_170_runtime_limit_bytes": 24_576,
            "contracts": {
                "StreamCore": {
                    "source": source,
                    "minimum_runtime_margin_bytes": 384,
                    "warning_runtime_margin_bytes": 512,
                    "tracking": "https://example.test/size-budget",
                }
            },
        },
    }
    if include_policy:
        config["core_bytecode_spend_policy"] = {
            "schema_version": checker.POLICY_SCHEMA,
            "contract": "StreamCore",
            "approved_runtime_size_bytes": approved_size,
            "tracking": "https://example.test/core-bytecode-policy",
            "exceptions": exceptions or [],
            "rejected_experiments": [],
        }
    write_json(root / "release-artifacts/contracts.json", config)
    write_json(
        root / "out/StreamCore.sol/StreamCore.json",
        {
            "deployedBytecode": {"object": runtime_hex(runtime_size)},
            "metadata": artifact_metadata(root, source),
        },
    )


class CoreBytecodeSpendPolicyTests(unittest.TestCase):
    def test_current_baseline_passes_without_exception(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root)

            result = checker.check_policy(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(result, 0)

    def test_smaller_runtime_passes_without_exception(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=22_000)

            result = checker.check_policy(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(result, 0)

    def test_unreviewed_runtime_increase_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=22_185)

            result = checker.check_policy(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(result, 1)

    def test_accepted_bounded_exception_allows_runtime_increase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                runtime_size=22_220,
                exceptions=[
                    {
                        "id": "CORE-SPEND-001",
                        "status": "accepted",
                        "issue": "https://example.test/issues/1",
                        "max_runtime_size_bytes": 22_220,
                        "measured_delta_bytes": 36,
                        "rationale": "Critical consensus safety fix.",
                        "mitigation": "No satellite-compatible alternative exists.",
                    }
                ],
            )

            result = checker.check_policy(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(result, 0)

    def test_exception_does_not_allow_growth_past_approved_maximum(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                runtime_size=22_221,
                exceptions=[
                    {
                        "id": "CORE-SPEND-001",
                        "status": "accepted",
                        "issue": "https://example.test/issues/1",
                        "max_runtime_size_bytes": 22_220,
                        "measured_delta_bytes": 36,
                        "rationale": "Critical consensus safety fix.",
                        "mitigation": "No satellite-compatible alternative exists.",
                    }
                ],
            )

            result = checker.check_policy(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(result, 1)

    def test_accepted_exception_requires_required_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(
                root,
                runtime_size=22_220,
                exceptions=[
                    {
                        "id": "CORE-SPEND-001",
                        "status": "accepted",
                        "issue": "https://example.test/issues/1",
                        "max_runtime_size_bytes": 22_220,
                        "measured_delta_bytes": 36,
                        "rationale": "Critical consensus safety fix.",
                    }
                ],
            )

            with self.assertRaisesRegex(checker.CoreBytecodePolicyError, "mitigation"):
                checker.check_policy(root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT)

    def test_missing_policy_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, include_policy=False)

            with self.assertRaisesRegex(
                checker.CoreBytecodePolicyError,
                "core_bytecode_spend_policy",
            ):
                checker.check_policy(root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT)


if __name__ == "__main__":
    unittest.main(verbosity=2)
