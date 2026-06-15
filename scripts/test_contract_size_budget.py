#!/usr/bin/env python3
"""Focused tests for the production contract runtime size budget checker."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any


SCRIPT_PATH = Path(__file__).with_name("check_contract_size_budget.py")
SPEC = importlib.util.spec_from_file_location("check_contract_size_budget", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def runtime_hex(size_bytes: int) -> str:
    return "0x" + ("60" * size_bytes)


def write_tree(
    root: Path,
    *,
    runtime_size: int,
    minimum_margin: int = 384,
    warning_margin: int = 512,
    limit: int = 24_576,
) -> None:
    write_json(
        root / "release-artifacts/contracts.json",
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [
                {"name": "Example", "source": "smart-contracts/Example.sol"}
            ],
            "runtime_size_budget": {
                "schema_version": checker.BUDGET_SCHEMA,
                "eip_170_runtime_limit_bytes": limit,
                "contracts": {
                    "Example": {
                        "source": "smart-contracts/Example.sol",
                        "minimum_runtime_margin_bytes": minimum_margin,
                        "warning_runtime_margin_bytes": warning_margin,
                        "tracking": "https://example.test/issue",
                    }
                },
            },
        },
    )
    write_json(
        root / "out/Example.sol/Example.json",
        {"deployedBytecode": {"object": runtime_hex(runtime_size)}},
    )


def add_production_contract(root: Path, name: str, source: str, runtime_size: int) -> None:
    config_path = root / "release-artifacts/contracts.json"
    config = checker.load_json(config_path)
    config["production_contracts"].append({"name": name, "source": source})
    write_json(config_path, config)
    write_json(
        root / "out" / Path(source).name / f"{name}.json",
        {"deployedBytecode": {"object": runtime_hex(runtime_size)}},
    )


class ContractSizeBudgetTests(unittest.TestCase):
    def test_passes_above_warning_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000)

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(report[0]["runtime_margin_bytes"], 576)
        self.assertEqual(report[0]["status"], "pass")
        self.assertEqual(checker.check_report(report), 0)

    def test_warns_below_warning_threshold_without_failing(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_139)

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(report[0]["runtime_margin_bytes"], 437)
        self.assertEqual(report[0]["status"], "warn")
        self.assertEqual(checker.check_report(report), 0)

    def test_fails_below_minimum_floor(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_200)

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(report[0]["runtime_margin_bytes"], 376)
        self.assertEqual(report[0]["status"], "fail")
        self.assertEqual(checker.check_report(report), 1)

    def test_counts_solidity_link_placeholders_as_library_addresses(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000, limit=100, minimum_margin=1, warning_margin=1)
            write_json(
                root / "out/Example.sol/Example.json",
                {
                    "deployedBytecode": {
                        "object": "0x60__$a64266b5966c542c29758651cb19f2deb4$__61"
                    }
                },
            )

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(report[0]["runtime_size_bytes"], 22)
        self.assertEqual(report[0]["runtime_margin_bytes"], 78)
        self.assertEqual(report[0]["status"], "pass")

    def test_counts_multiple_solidity_link_placeholders(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000, limit=100, minimum_margin=1, warning_margin=1)
            write_json(
                root / "out/Example.sol/Example.json",
                {
                    "deployedBytecode": {
                        "object": (
                            "0x60__$a64266b5966c542c29758651cb19f2deb4$__"
                            "61__$bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb$__62"
                        )
                    }
                },
            )

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        self.assertEqual(report[0]["runtime_size_bytes"], 43)
        self.assertEqual(report[0]["runtime_margin_bytes"], 57)
        self.assertEqual(report[0]["status"], "pass")

    def test_unbudgeted_production_contract_fails_when_above_eip170_limit(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000)
            add_production_contract(
                root,
                "Other",
                "smart-contracts/Other.sol",
                runtime_size=24_577,
            )

            report = checker.build_report(
                root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT
            )

        by_name = {row["contract"]: row for row in report}
        self.assertEqual(by_name["Other"]["runtime_margin_bytes"], -1)
        self.assertEqual(by_name["Other"]["status"], "fail")
        self.assertEqual(checker.check_report(report), 1)

    def test_rejects_malformed_unlinked_runtime_bytecode(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000)
            write_json(
                root / "out/Example.sol/Example.json",
                {"deployedBytecode": {"object": "0x60__$unlinked$__"}},
            )

            with self.assertRaisesRegex(checker.SizeBudgetError, "must be hex"):
                checker.build_report(root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT)

    def test_rejects_budget_for_non_production_contract(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            write_tree(root, runtime_size=24_000)
            config_path = root / "release-artifacts/contracts.json"
            config = checker.load_json(config_path)
            config["runtime_size_budget"]["contracts"]["Other"] = {
                "minimum_runtime_margin_bytes": 1
            }
            write_json(config_path, config)

            with self.assertRaisesRegex(checker.SizeBudgetError, "not production-listed"):
                checker.build_report(root, checker.DEFAULT_CONFIG, checker.DEFAULT_FOUNDRY_OUT)


if __name__ == "__main__":
    unittest.main(verbosity=2)
