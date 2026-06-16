#!/usr/bin/env python3
"""Focused tests for gas envelope validation."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_gas_envelopes.py")
SPEC = importlib.util.spec_from_file_location("check_gas_envelopes", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")


def write_snapshot(path: Path, rows: dict[str, int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(f"{name} (gas: {gas})\n" for name, gas in rows.items()),
        encoding="utf-8",
    )


def minimal_envelopes(snapshot_path: Path, max_gas: int = 200) -> dict[str, object]:
    return {
        "schema_version": checker.EXPECTED_SCHEMA_VERSION,
        "snapshot_path": str(snapshot_path),
        "envelopes": [
            {
                "test": "GasTest:testGasFlow()",
                "flow": "example_flow",
                "max_gas": max_gas,
                "rationale": "Example release gas envelope.",
            }
        ],
    }


class GasEnvelopeTests(unittest.TestCase):
    def test_committed_envelopes_pass(self) -> None:
        messages = checker.validate_envelopes(checker.DEFAULT_ENVELOPES)
        self.assertGreaterEqual(len(messages), 12)

    def test_rejects_budget_overrun(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            snapshot = root / "gas.snap"
            envelope = root / "gas-envelopes.json"
            write_snapshot(snapshot, {"GasTest:testGasFlow()": 201})
            write_json(envelope, minimal_envelopes(snapshot, max_gas=200))

            with self.assertRaisesRegex(checker.GasEnvelopeError, "exceeds envelope"):
                checker.validate_envelopes(envelope)

    def test_rejects_missing_snapshot_measurement(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            snapshot = root / "gas.snap"
            envelope = root / "gas-envelopes.json"
            write_snapshot(snapshot, {"GasTest:testOtherFlow()": 100})
            write_json(envelope, minimal_envelopes(snapshot))

            with self.assertRaisesRegex(checker.GasEnvelopeError, "missing from snapshot"):
                checker.validate_envelopes(envelope)

    def test_rejects_uncovered_snapshot_measurement(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            snapshot = root / "gas.snap"
            envelope = root / "gas-envelopes.json"
            write_snapshot(
                snapshot,
                {
                    "GasTest:testGasFlow()": 100,
                    "GasTest:testNewFlow()": 100,
                },
            )
            write_json(envelope, minimal_envelopes(snapshot))

            with self.assertRaisesRegex(checker.GasEnvelopeError, "missing envelopes"):
                checker.validate_envelopes(envelope)

    def test_rejects_duplicate_flow_names(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            snapshot = root / "gas.snap"
            envelope = root / "gas-envelopes.json"
            write_snapshot(
                snapshot,
                {
                    "GasTest:testGasFlow()": 100,
                    "GasTest:testOtherFlow()": 100,
                },
            )
            data = minimal_envelopes(snapshot)
            data["envelopes"].append(
                {
                    "test": "GasTest:testOtherFlow()",
                    "flow": "example_flow",
                    "max_gas": 200,
                    "rationale": "Another release gas envelope.",
                }
            )
            write_json(envelope, data)

            with self.assertRaisesRegex(checker.GasEnvelopeError, "duplicate gas envelope flow"):
                checker.validate_envelopes(envelope)


if __name__ == "__main__":
    unittest.main(verbosity=2)
