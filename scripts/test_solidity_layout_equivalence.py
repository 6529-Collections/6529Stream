#!/usr/bin/env python3
"""Hostile self-tests for the committed Solidity layout-equivalence receipt."""

from __future__ import annotations

import copy
import json
import unittest
from pathlib import Path
from typing import Any

import check_solidity_layout_equivalence as checker
import check_solidity_source_layout as layout


REPO_ROOT = Path(__file__).resolve().parents[1]


class SolidityLayoutEquivalenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        manifest = layout.load_manifest(REPO_ROOT)
        cls.sources = checker.source_receipt(REPO_ROOT, manifest)
        cls.report = json.loads(
            (REPO_ROOT / checker.DEFAULT_REPORT).read_text(encoding="utf-8")
        )

    def assert_rejected(self, report: Any) -> None:
        with self.assertRaises(checker.EquivalenceError):
            checker.validate_committed_report(report, self.sources)

    def test_committed_receipt_passes(self) -> None:
        checker.validate_committed_report(self.report, self.sources)

    def test_raw_mismatch_arrays_and_counts_are_preserved(self) -> None:
        expected = {
            "full_foundry_artifacts": {
                "initcode": 12,
                "runtime": 11,
                "link_references": 2,
                "immutable_references": 1,
            },
            "isolated_release_artifacts": {
                "initcode": 15,
                "runtime": 15,
                "link_references": 2,
                "immutable_references": 4,
            },
        }
        for section, counts in expected.items():
            receipt = self.report[section]
            self.assertEqual(receipt["raw_compiler_output_mismatch_counts"], counts)
            self.assertEqual(
                {key: len(value) for key, value in receipt["raw_compiler_output_mismatches"].items()},
                counts,
            )

    def test_schema_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["schema_version"] = "6529stream.solidity-layout-equivalence.v2"
        self.assert_rejected(report)

    def test_migration_base_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["migration_base_commit"] = "0" * 40
        self.assert_rejected(report)

    def test_top_level_result_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["result"] = "fail"
        self.assert_rejected(report)

    def test_raw_bytecode_identity_claim_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["raw_bytecode_identity_claimed"] = True
        self.assert_rejected(report)

    def test_source_receipt_value_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["source_semantics"]["semantic_inventory_sha256"] = "0" * 64
        self.assert_rejected(report)

    def test_source_receipt_field_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["source_semantics"].pop("mismatches")
        self.assert_rejected(report)

    def test_top_level_field_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["unsupported_claim"] = "raw bytecode is identical"
        self.assert_rejected(report)

    def test_raw_mismatch_count_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["full_foundry_artifacts"]["raw_compiler_output_mismatch_counts"][
            "runtime"
        ] = 0
        self.assert_rejected(report)

    def test_forged_abi_semantic_mismatch_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["full_foundry_artifacts"]["semantic_mismatches"]["abi"].append(
            "StreamCore.sol/StreamCore.json"
        )
        self.assert_rejected(report)

    def test_bad_semantic_digest_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["isolated_release_artifacts"]["semantic_surface_sha256"]["abi"] = (
            "A" * 64
        )
        self.assert_rejected(report)

    def test_contradictory_raw_bytecode_equal_flag_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["full_foundry_artifacts"]["raw_bytecode_equal"] = True
        self.assert_rejected(report)

    def test_compiler_input_mismatch_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["release_compiler_inputs"]["mismatches"].append("forged-target")
        self.assert_rejected(report)

    def test_compiler_input_match_count_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["release_compiler_inputs"]["exact_semantic_match_count"] -= 1
        self.assert_rejected(report)

    def test_duplicate_raw_mismatch_row_fails(self) -> None:
        report = copy.deepcopy(self.report)
        receipt = report["full_foundry_artifacts"]
        receipt["raw_compiler_output_mismatches"]["initcode"].append(
            receipt["raw_compiler_output_mismatches"]["initcode"][0]
        )
        receipt["raw_compiler_output_mismatch_counts"]["initcode"] += 1
        self.assert_rejected(report)

    def test_non_normalized_raw_mismatch_row_fails(self) -> None:
        report = copy.deepcopy(self.report)
        rows = report["isolated_release_artifacts"]["raw_compiler_output_mismatches"][
            "runtime"
        ]
        rows[0] = f"./{rows[0]}"
        self.assert_rejected(report)


if __name__ == "__main__":
    unittest.main(verbosity=2)
