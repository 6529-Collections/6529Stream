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

    def test_filters_line_ending_only_forge_fmt_diff(self) -> None:
        output = """Diff in smart-contracts\\IERC721Enumerable.sol:
1        |-pragma solidity ^0.8.0;
2        |-
3        |-interface IERC721Enumerable {}
    1    |+pragma solidity ^0.8.0;
    2    |+
    3    |+interface IERC721Enumerable {}
"""

        self.assertEqual(
            checker.filter_line_ending_only_fmt_diffs(
                output, ["smart-contracts/IERC721Enumerable.sol"]
            ),
            [],
        )

    def test_retains_real_forge_fmt_diff(self) -> None:
        output = """Diff in smart-contracts\\StreamSplitWallet.sol:
1        |-contract StreamSplitWallet{
    1    |+contract StreamSplitWallet {
"""

        self.assertEqual(
            checker.filter_line_ending_only_fmt_diffs(
                output, ["smart-contracts/StreamSplitWallet.sol"]
            ),
            ["smart-contracts/StreamSplitWallet.sol"],
        )

    def test_required_formatting_failure_without_parseable_diff_is_reported(self) -> None:
        output = """Error: failed to parse Solidity source
not a diff header
"""

        with self.assertRaisesRegex(
            checker.SolidityFormattingError, "without parseable formatting diffs"
        ):
            checker.required_formatting_diff_files(output)

    def test_required_files_exclude_vendored_exemptions(self) -> None:
        files = [
            "smart-contracts/Address.sol",
            "smart-contracts/Math.sol",
            "smart-contracts/StreamCore.sol",
        ]

        self.assertEqual(
            checker.formatting_required_files(files),
            ["smart-contracts/StreamCore.sol"],
        )

    def test_vendored_exemptions_accept_exact_current_diff_set(self) -> None:
        files = sorted(checker.VENDORED_FORMATTING_EXEMPTIONS | {"smart-contracts/StreamCore.sol"})
        checker.validate_vendored_exemptions(
            files, sorted(checker.VENDORED_FORMATTING_EXEMPTIONS)
        )

    def test_vendored_exemptions_reject_new_unformatted_file(self) -> None:
        files = sorted(checker.VENDORED_FORMATTING_EXEMPTIONS | {"smart-contracts/StreamCore.sol"})

        with self.assertRaisesRegex(checker.SolidityFormattingError, "unexpected"):
            checker.validate_vendored_exemptions(
                files,
                sorted(
                    checker.VENDORED_FORMATTING_EXEMPTIONS | {"smart-contracts/StreamCore.sol"}
                ),
            )

    def test_vendored_exemptions_reject_formatted_file_without_policy_update(self) -> None:
        files = sorted(checker.VENDORED_FORMATTING_EXEMPTIONS | {"smart-contracts/StreamCore.sol"})
        diff_files = sorted(
            checker.VENDORED_FORMATTING_EXEMPTIONS - {"smart-contracts/Address.sol"}
        )

        with self.assertRaisesRegex(checker.SolidityFormattingError, "exemption set changed"):
            checker.validate_vendored_exemptions(files, diff_files)

    def test_vendored_exemptions_reject_missing_exempt_file(self) -> None:
        files = sorted(checker.VENDORED_FORMATTING_EXEMPTIONS - {"smart-contracts/Address.sol"})

        with self.assertRaisesRegex(checker.SolidityFormattingError, "missing file"):
            checker.validate_vendored_exemptions(
                files, sorted(checker.VENDORED_FORMATTING_EXEMPTIONS)
            )


if __name__ == "__main__":
    unittest.main(verbosity=2)
