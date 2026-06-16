#!/usr/bin/env python3
"""Focused tests for protocol surface report generation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import contextmanager, redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
from typing import Iterator


SCRIPT_PATH = Path(__file__).with_name("generate_protocol_surface_report.py")
SPEC = importlib.util.spec_from_file_location("generate_protocol_surface_report", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def seed_fixture(root: Path, *, include_all_selectors: bool = True) -> dict[str, Path]:
    config_path = root / "release-artifacts" / "contracts.json"
    out_dir = root / "out"
    output_path = root / "release-artifacts" / "latest" / "protocol-surface-report.json"
    abi = [
        {
            "type": "function",
            "name": "readValue",
            "stateMutability": "view",
            "inputs": [],
            "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
        },
        {
            "type": "function",
            "name": "setValue",
            "stateMutability": "nonpayable",
            "inputs": [{"name": "value", "type": "uint256", "internalType": "uint256"}],
            "outputs": [],
        },
        {
            "type": "function",
            "name": "pay",
            "stateMutability": "payable",
            "inputs": [],
            "outputs": [],
        },
        {
            "type": "event",
            "name": "ValueSet",
            "anonymous": False,
            "inputs": [
                {
                    "name": "value",
                    "type": "uint256",
                    "indexed": True,
                    "internalType": "uint256",
                },
                {
                    "name": "actor",
                    "type": "address",
                    "indexed": False,
                    "internalType": "address",
                },
            ],
        },
        {
            "type": "error",
            "name": "BadValue",
            "inputs": [{"name": "value", "type": "uint256", "internalType": "uint256"}],
        },
    ]
    method_identifiers = {
        "readValue()": "11111111",
        "pay()": "22222222",
    }
    if include_all_selectors:
        method_identifiers["setValue(uint256)"] = "33333333"
    artifact = {
        "abi": abi,
        "bytecode": {"object": "0x6000"},
        "deployedBytecode": {"object": "0x6001"},
        "methodIdentifiers": method_identifiers,
    }
    write_json(out_dir / "Example.sol" / "Example.json", artifact)
    write_json(
        config_path,
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [
                {"name": "Example", "source": "smart-contracts/Example.sol"}
            ],
        },
    )
    return {"config": config_path, "out": out_dir, "output": output_path}


@contextmanager
def patched_cast() -> Iterator[None]:
    original = generator.release_artifacts.run_cast

    def fake_run_cast(cast_bin: str, args: list[str]) -> str:
        self = cast_bin
        _ = self
        if args == ["sig-event", "ValueSet(uint256,address)"]:
            return "0x" + "ab" * 32
        if args == ["sig", "BadValue(uint256)"]:
            return "0xdeadbeef"
        raise AssertionError(f"unexpected cast args: {args}")

    generator.release_artifacts.run_cast = fake_run_cast
    try:
        yield
    finally:
        generator.release_artifacts.run_cast = original


class ProtocolSurfaceReportTests(unittest.TestCase):
    def test_committed_report_is_canonical_compact_json(self) -> None:
        root = Path(__file__).resolve().parents[1]
        output_path = root / "release-artifacts" / "latest" / "protocol-surface-report.json"
        report_text = output_path.read_text(encoding="utf-8")
        report = json.loads(report_text)

        self.assertEqual(report_text.count("\n"), 1)
        self.assertEqual(
            report_text,
            json.dumps(report, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n",
        )

    def test_committed_report_summary_matches_contract_entries(self) -> None:
        root = Path(__file__).resolve().parents[1]
        output_path = root / "release-artifacts" / "latest" / "protocol-surface-report.json"
        report = json.loads(output_path.read_text(encoding="utf-8"))
        totals = {
            "contract_count": len(report["contracts"]),
            "function_count": 0,
            "read_function_count": 0,
            "write_function_count": 0,
            "payable_function_count": 0,
            "event_count": 0,
            "custom_error_count": 0,
        }

        for contract in report["contracts"].values():
            functions = contract["functions"]
            events = contract["events"]
            custom_errors = contract["custom_errors"]
            expected_summary = {
                "function_count": len(functions),
                "read_function_count": sum(
                    1 for function in functions if function["posture"] == "read"
                ),
                "write_function_count": sum(
                    1 for function in functions if function["posture"] == "write"
                ),
                "payable_function_count": sum(
                    1 for function in functions if function["payable"]
                ),
                "event_count": len(events),
                "custom_error_count": len(custom_errors),
            }
            self.assertEqual(contract["summary"], expected_summary)
            for key, value in expected_summary.items():
                totals[key] += value

        self.assertEqual(report["summary"], totals)

    def test_report_contains_functions_events_and_custom_errors(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir, patched_cast():
            root = Path(temp_dir)
            paths = seed_fixture(root)

            output = generator.generate_report(
                root,
                paths["config"],
                paths["out"],
                paths["output"],
                "cast",
            )
            report = json.loads(output.read_text(encoding="utf-8"))

            self.assertEqual(report["schema_version"], generator.PROTOCOL_SURFACE_SCHEMA)
            self.assertEqual(report["summary"]["contract_count"], 1)
            self.assertEqual(report["summary"]["function_count"], 3)
            self.assertEqual(report["summary"]["read_function_count"], 1)
            self.assertEqual(report["summary"]["write_function_count"], 2)
            self.assertEqual(report["summary"]["payable_function_count"], 1)
            self.assertEqual(report["summary"]["event_count"], 1)
            self.assertEqual(report["summary"]["custom_error_count"], 1)

            contract = report["contracts"]["Example"]
            functions = {item["signature"]: item for item in contract["functions"]}
            self.assertEqual(functions["readValue()"]["selector"], "0x11111111")
            self.assertEqual(functions["readValue()"]["posture"], "read")
            self.assertEqual(functions["setValue(uint256)"]["posture"], "write")
            self.assertEqual(functions["pay()"]["payable"], True)
            self.assertEqual(
                functions["setValue(uint256)"]["inputs"][0]["internal_type"],
                "uint256",
            )

            event = contract["events"][0]
            self.assertEqual(event["signature"], "ValueSet(uint256,address)")
            self.assertEqual(event["topic0"], "0x" + "ab" * 32)
            self.assertEqual(event["inputs"][0]["indexed"], True)

            custom_error = contract["custom_errors"][0]
            self.assertEqual(custom_error["signature"], "BadValue(uint256)")
            self.assertEqual(custom_error["selector"], "0xdeadbeef")

    def test_check_report_detects_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir, patched_cast():
            root = Path(temp_dir)
            paths = seed_fixture(root)

            generator.generate_report(root, paths["config"], paths["out"], paths["output"], "cast")
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_report(root, paths["config"], paths["out"], paths["output"], "cast"),
                    0,
                )

            with paths["output"].open("a", encoding="utf-8") as handle:
                handle.write("\n")
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(
                    generator.check_report(root, paths["config"], paths["out"], paths["output"], "cast"),
                    1,
                )

    def test_missing_function_selector_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir, patched_cast():
            root = Path(temp_dir)
            paths = seed_fixture(root, include_all_selectors=False)

            with self.assertRaisesRegex(
                generator.ProtocolSurfaceError,
                "missing method identifier for setValue",
            ):
                generator.build_report(root, paths["config"], paths["out"], "cast")


if __name__ == "__main__":
    unittest.main(verbosity=2)
