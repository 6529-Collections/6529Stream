#!/usr/bin/env python3
"""Focused tests for the scoped Solidity formatting checker."""

from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_solidity_formatting.py")
SPEC = importlib.util.spec_from_file_location("check_solidity_formatting", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


class SolidityFormattingTests(unittest.TestCase):
    def test_parses_windows_and_posix_diff_headers(self) -> None:
        output = """Diff in smart-contracts\\Address.sol:
line noise
Diff in smart-contracts/Math.sol:
Diff in smart-contracts\\Address.sol:
"""

        self.assertEqual(
            checker.parse_fmt_diff_files(output),
            ["smart-contracts/Address.sol", "smart-contracts/Math.sol"],
        )

    def test_required_files_exclude_deferred_baseline(self) -> None:
        files = [
            "smart-contracts/Address.sol",
            "smart-contracts/IRandomizer.sol",
            "smart-contracts/StreamCore.sol",
        ]

        self.assertEqual(
            checker.formatting_required_files(files),
            ["smart-contracts/StreamCore.sol"],
        )

    def test_deferred_baseline_accepts_exact_current_diff_set(self) -> None:
        files = sorted(checker.DEFERRED_FORMATTING_FILES | {"smart-contracts/StreamCore.sol"})
        checker.validate_deferred_baseline(files, sorted(checker.DEFERRED_FORMATTING_FILES))

    def test_deferred_baseline_rejects_new_unformatted_file(self) -> None:
        files = sorted(checker.DEFERRED_FORMATTING_FILES | {"smart-contracts/StreamCore.sol"})

        with self.assertRaisesRegex(checker.SolidityFormattingError, "unexpected"):
            checker.validate_deferred_baseline(
                files,
                sorted(checker.DEFERRED_FORMATTING_FILES | {"smart-contracts/StreamCore.sol"}),
            )

    def test_deferred_baseline_rejects_fixed_file_without_manifest_update(self) -> None:
        files = sorted(checker.DEFERRED_FORMATTING_FILES | {"smart-contracts/StreamCore.sol"})
        diff_files = sorted(checker.DEFERRED_FORMATTING_FILES - {"smart-contracts/Address.sol"})

        with self.assertRaisesRegex(checker.SolidityFormattingError, "baseline changed"):
            checker.validate_deferred_baseline(files, diff_files)

    def test_deferred_baseline_rejects_missing_baseline_file(self) -> None:
        files = sorted(checker.DEFERRED_FORMATTING_FILES - {"smart-contracts/Address.sol"})

        with self.assertRaisesRegex(checker.SolidityFormattingError, "missing file"):
            checker.validate_deferred_baseline(files, sorted(checker.DEFERRED_FORMATTING_FILES))


if __name__ == "__main__":
    unittest.main(verbosity=2)
