#!/usr/bin/env python3
"""Hostile self-tests for the committed Solidity layout-equivalence receipt."""

from __future__ import annotations

import copy
import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from typing import Any
from unittest import mock

import check_solidity_layout_equivalence as checker
import check_solidity_source_layout as layout


REPO_ROOT = Path(__file__).resolve().parents[1]


class SolidityLayoutEquivalenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.manifest = layout.load_manifest(REPO_ROOT)
        cls.report = checker.load_strict_json(REPO_ROOT / checker.DEFAULT_REPORT)

    def assert_rejected(self, report: Any) -> None:
        with self.assertRaises(checker.EquivalenceError):
            checker.validate_committed_report(
                report, self.manifest["equivalence_receipt_canonical_sha256"]
            )

    @staticmethod
    def generation_args(root: Path, output: Path | str) -> list[str]:
        return [
            "--repo-root",
            str(root),
            "--generate",
            "--before-out",
            str(root / "before-full"),
            "--after-out",
            str(root / "after-full"),
            "--before-release-out",
            str(root / "before-release"),
            "--after-release-out",
            str(root / "after-release"),
            "--output",
            str(output),
        ]

    @staticmethod
    def write_artifact(root: Path, text: str = "{}") -> None:
        path = root / "Example.sol/Example.json"
        path.parent.mkdir(parents=True)
        path.write_text(text, encoding="utf-8")

    def run_generation_expecting_duplicate(self, root: Path, member: str) -> None:
        self.run_generation_expecting_error(root, f"duplicate JSON member: {member}")

    def run_generation_expecting_error(self, root: Path, message: str) -> None:
        output = root / "generated-receipt.json"
        with mock.patch.object(layout, "load_manifest", return_value=self.manifest), mock.patch.object(
            checker,
            "source_receipt",
            return_value=copy.deepcopy(self.report["source_semantics"]),
        ):
            with self.assertRaisesRegex(checker.EquivalenceError, message):
                checker.main(self.generation_args(root, output))
        self.assertFalse(output.exists())

    def prepare_release_inventory(
        self, root: Path, targets: list[Any], *, create_inputs: bool = True
    ) -> None:
        self.write_artifact(root / "before-full")
        self.write_artifact(root / "after-full")
        for directory in (root / "before-release", root / "after-release"):
            directory.mkdir(parents=True)
            (directory / "release-build-manifest.json").write_text(
                json.dumps(
                    {
                        "schema_version": "6529stream.release-build.v1",
                        "generated_by": "scripts/build_release_artifacts.py:5",
                        "targets": targets,
                    }
                ),
                encoding="utf-8",
            )
            if create_inputs:
                for row in targets:
                    if not isinstance(row, dict):
                        continue
                    relative = row.get("compiler_input_relative_path")
                    if not isinstance(relative, str) or not relative.startswith("compiler-inputs/"):
                        continue
                    path = directory.joinpath(*relative.split("/"))
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(
                        json.dumps({"language": "Solidity", "sources": {}}),
                        encoding="utf-8",
                    )

    def test_committed_receipt_passes(self) -> None:
        checker.validate_committed_report(
            self.report, self.manifest["equivalence_receipt_canonical_sha256"]
        )

    def test_manifest_binds_exact_canonical_receipt_digest(self) -> None:
        self.assertEqual(
            self.manifest["equivalence_receipt_canonical_sha256"],
            checker.EXPECTED_RECEIPT_CANONICAL_SHA256,
        )
        self.assertEqual(checker.sha256(self.report), checker.EXPECTED_RECEIPT_CANONICAL_SHA256)

    def test_cli_modes_are_explicit_and_complete_generation_parses(self) -> None:
        generate = checker.parse_args(
            [
                "--generate",
                "--before-out",
                "before-full",
                "--after-out",
                "after-full",
                "--before-release-out",
                "before-release",
                "--after-release-out",
                "after-release",
                "--output",
                "receipt.json",
            ]
        )
        self.assertTrue(generate.generate)
        self.assertEqual(generate.output, Path("receipt.json"))
        self.assertTrue(checker.parse_args(["--check-receipt"]).check_receipt)
        self.assertTrue(checker.parse_args(["--check-source"]).check_source)

    def test_bare_invocation_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    checker.main(["--repo-root", str(root)])
            self.assertFalse((root / checker.DEFAULT_REPORT).exists())

    def test_generation_half_pair_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output = root / checker.DEFAULT_REPORT
            with self.assertRaisesRegex(checker.EquivalenceError, "requires all four"):
                checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--generate",
                        "--before-out",
                        "before-full",
                    ]
                )
            self.assertFalse(output.exists())

    def test_generation_one_complete_family_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output = root / "receipt.json"
            with self.assertRaisesRegex(checker.EquivalenceError, "requires all four"):
                checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--generate",
                        "--before-out",
                        "before-full",
                        "--after-out",
                        "after-full",
                        "--output",
                        str(output),
                    ]
                )
            self.assertFalse(output.exists())

    def test_generation_external_absolute_output_fails_before_work_or_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            base = Path(temp_dir)
            root = base / "repo"
            root.mkdir()
            output = base / "external-receipt.json"
            with mock.patch.object(layout, "load_manifest") as load_manifest, mock.patch.object(
                checker, "source_receipt"
            ) as source_receipt:
                with self.assertRaisesRegex(
                    checker.EquivalenceError, "must resolve inside repo_root"
                ):
                    checker.main(self.generation_args(root, output))
            load_manifest.assert_not_called()
            source_receipt.assert_not_called()
            self.assertFalse(output.exists())

    def test_generation_escaping_output_fails_before_work_or_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            base = Path(temp_dir)
            root = base / "repo"
            root.mkdir()
            output = base / "escaped-receipt.json"
            with mock.patch.object(layout, "load_manifest") as load_manifest, mock.patch.object(
                checker, "source_receipt"
            ) as source_receipt:
                with self.assertRaisesRegex(
                    checker.EquivalenceError, "must resolve inside repo_root"
                ):
                    checker.main(
                        self.generation_args(root, Path("..") / output.name)
                    )
            load_manifest.assert_not_called()
            source_receipt.assert_not_called()
            self.assertFalse(output.exists())

    def test_generation_repo_relative_output_preflight_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir).resolve()
            self.assertEqual(
                checker.resolve_generation_output(root, Path("evidence/receipt.json")),
                root / "evidence/receipt.json",
            )

    def test_generation_duplicate_artifact_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_artifact(
                root / "before-full", '{"abi": [], "abi": [{"type": "function"}]}'
            )
            self.write_artifact(root / "after-full")
            self.run_generation_expecting_duplicate(root, "abi")

    def test_generation_empty_full_artifact_inventory_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            (root / "before-full").mkdir()
            (root / "after-full").mkdir()
            self.run_generation_expecting_error(
                root, "pre-migration artifact inventory must not be empty"
            )

    def test_generation_empty_post_artifact_inventory_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_artifact(root / "before-full")
            (root / "after-full").mkdir()
            self.run_generation_expecting_error(
                root, "post-migration artifact inventory must not be empty"
            )

    def test_generation_duplicate_build_manifest_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_artifact(root / "before-full")
            self.write_artifact(root / "after-full")
            before_manifest = root / "before-release/release-build-manifest.json"
            before_manifest.parent.mkdir(parents=True)
            before_manifest.write_text('{"targets": [], "targets": []}', encoding="utf-8")
            self.run_generation_expecting_duplicate(root, "targets")

    def test_generation_duplicate_compiler_input_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.write_artifact(root / "before-full")
            self.write_artifact(root / "after-full")
            manifest = {
                "targets": [
                    {
                        "name": "Example",
                        "compiler_input_relative_path": "compiler-inputs/Example.json",
                    }
                ]
            }
            for directory in (root / "before-release", root / "after-release"):
                directory.mkdir(parents=True)
                (directory / "release-build-manifest.json").write_text(
                    json.dumps(manifest), encoding="utf-8"
                )
            compiler_input = root / "before-release/compiler-inputs/Example.json"
            compiler_input.parent.mkdir(parents=True)
            compiler_input.write_text(
                '{"language": "Solidity", "language": "Vyper"}', encoding="utf-8"
            )
            self.run_generation_expecting_duplicate(root, "language")

    def test_release_inputs_accept_current_manifest_shape_and_extra_metadata(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "kind": "interface",
                    "name": "IDependencyRegistry",
                    "source": "smart-contracts/interfaces/stream/IDependencyRegistry.sol",
                    "compiler_input_relative_path": "compiler-inputs/023-IDependencyRegistry.json",
                    "compiler_input_sha256": "sha256:" + "0" * 64,
                    "forge_environment": {"FOUNDRY_PROFILE": "default"},
                }
            ]
            self.prepare_release_inventory(root, targets)
            expected = {"language": "Solidity", "sources": {}}
            self.assertEqual(
                checker.release_inputs(root / "before-release"),
                {"IDependencyRegistry": expected},
            )

    def test_generation_empty_release_targets_fail_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            self.prepare_release_inventory(root, [])
            self.run_generation_expecting_error(
                root, "release build manifest targets must not be empty"
            )

    def test_generation_duplicate_target_name_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "Example",
                    "compiler_input_relative_path": "compiler-inputs/One.json",
                },
                {
                    "name": "Example",
                    "compiler_input_relative_path": "compiler-inputs/Two.json",
                },
            ]
            self.prepare_release_inventory(root, targets)
            for directory in (root / "before-release", root / "after-release"):
                (directory / "compiler-inputs/One.json").write_text(
                    '{"language": "Solidity", "language": "Vyper"}',
                    encoding="utf-8",
                )
            self.run_generation_expecting_error(
                root, "duplicate release compiler-input target name"
            )

    def test_generation_duplicate_compiler_input_path_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "One",
                    "compiler_input_relative_path": "compiler-inputs/Shared.json",
                },
                {
                    "name": "Two",
                    "compiler_input_relative_path": "compiler-inputs/Shared.json",
                },
            ]
            self.prepare_release_inventory(root, targets)
            self.run_generation_expecting_error(
                root, "duplicate release compiler-input relative path"
            )

    def test_generation_case_aliased_compiler_input_paths_fail_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "One",
                    "compiler_input_relative_path": "compiler-inputs/Shared.json",
                },
                {
                    "name": "Two",
                    "compiler_input_relative_path": "compiler-inputs/shared.json",
                },
            ]
            self.prepare_release_inventory(root, targets)
            self.run_generation_expecting_error(
                root, "case-aliased release compiler-input relative path"
            )

    def test_generation_same_resolved_compiler_input_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "One",
                    "compiler_input_relative_path": "compiler-inputs/One.json",
                },
                {
                    "name": "Two",
                    "compiler_input_relative_path": "compiler-inputs/Two.json",
                },
            ]
            self.prepare_release_inventory(root, targets)
            for directory in (root / "before-release", root / "after-release"):
                alias = directory / "compiler-inputs/Two.json"
                alias.unlink()
                try:
                    alias.symlink_to(directory / "compiler-inputs/One.json")
                except OSError as exc:
                    self.skipTest(f"file symlinks are unavailable: {exc}")
            self.run_generation_expecting_error(
                root, "release compiler-input paths resolve to the same file"
            )

    def test_generation_absolute_compiler_input_path_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "Example",
                    "compiler_input_relative_path": "/external/input.json",
                }
            ]
            self.prepare_release_inventory(root, targets, create_inputs=False)
            self.run_generation_expecting_error(
                root, "compiler_input_relative_path must be relative"
            )

    def test_generation_escaping_compiler_input_path_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {"name": "Example", "compiler_input_relative_path": "../input.json"}
            ]
            self.prepare_release_inventory(root, targets, create_inputs=False)
            self.run_generation_expecting_error(
                root, "without empty, dot, or dotdot segments"
            )

    def test_generation_symlinked_compiler_input_escape_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            base = Path(temp_dir)
            root = base / "repo"
            root.mkdir()
            self.write_artifact(root / "before-full")
            self.write_artifact(root / "after-full")
            external = base / "external"
            external.mkdir()
            (external / "input.json").write_text(
                json.dumps({"language": "Solidity", "sources": {}}),
                encoding="utf-8",
            )
            before_release = root / "before-release"
            before_release.mkdir()
            try:
                (before_release / "compiler-inputs").symlink_to(
                    external, target_is_directory=True
                )
            except OSError as exc:
                self.skipTest(f"directory symlinks are unavailable: {exc}")
            (before_release / "release-build-manifest.json").write_text(
                json.dumps(
                    {
                        "targets": [
                            {
                                "name": "Example",
                                "compiler_input_relative_path": "compiler-inputs/input.json",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )
            self.run_generation_expecting_error(root, "resolves outside the release root")

    def test_generation_backslash_compiler_input_path_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "Example",
                    "compiler_input_relative_path": "compiler-inputs\\input.json",
                }
            ]
            self.prepare_release_inventory(root, targets, create_inputs=False)
            self.run_generation_expecting_error(root, "must use forward slashes")

    def test_generation_dot_segment_compiler_input_path_fails_before_write(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            targets = [
                {
                    "name": "Example",
                    "compiler_input_relative_path": "compiler-inputs/./input.json",
                }
            ]
            self.prepare_release_inventory(root, targets, create_inputs=False)
            self.run_generation_expecting_error(
                root, "without empty, dot, or dotdot segments"
            )

    def test_nested_duplicate_receipt_member_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path = root / layout.MANIFEST_PATH
            report_path = root / checker.DEFAULT_REPORT
            manifest_path.parent.mkdir(parents=True)
            report_path.parent.mkdir(parents=True)
            manifest_path.write_text(
                (REPO_ROOT / layout.MANIFEST_PATH).read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            report_text = (REPO_ROOT / checker.DEFAULT_REPORT).read_text(encoding="utf-8")
            report_text = report_text.replace(
                '    "artifact_count":',
                '    "artifact_count": 1,\n    "artifact_count":',
                1,
            )
            report_path.write_text(report_text, encoding="utf-8")
            with self.assertRaisesRegex(
                checker.EquivalenceError, "duplicate JSON member: artifact_count"
            ):
                checker.main(["--repo-root", str(root), "--check-receipt"])

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

    def test_same_shape_artifact_count_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["full_foundry_artifacts"]["artifact_count"] += 1
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

    def test_same_shape_artifact_semantic_digest_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["isolated_release_artifacts"]["semantic_surface_sha256"]["abi"] = (
            "0" * 64
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

    def test_same_shape_compiler_counts_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        receipt = report["release_compiler_inputs"]
        receipt["target_count"] += 1
        receipt["exact_semantic_match_count"] += 1
        self.assert_rejected(report)

    def test_same_shape_compiler_digest_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        report["release_compiler_inputs"]["semantic_inputs_sha256"] = "0" * 64
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

    def test_same_shape_raw_mismatch_path_tamper_fails(self) -> None:
        report = copy.deepcopy(self.report)
        rows = report["full_foundry_artifacts"]["raw_compiler_output_mismatches"][
            "initcode"
        ]
        rows[0] = "DependencyRegistry.sol/Changed.json"
        rows.sort()
        self.assert_rejected(report)

    def test_permanent_receipt_survives_current_source_lifecycle(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            manifest_path = root / layout.MANIFEST_PATH
            report_path = root / checker.DEFAULT_REPORT
            source_path = root / "smart-contracts/core/StreamCore.sol"
            manifest_path.parent.mkdir(parents=True)
            report_path.parent.mkdir(parents=True)
            source_path.parent.mkdir(parents=True, exist_ok=True)
            manifest_path.write_text(
                (REPO_ROOT / layout.MANIFEST_PATH).read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            report_path.write_text(
                (REPO_ROOT / checker.DEFAULT_REPORT).read_text(encoding="utf-8"),
                encoding="utf-8",
            )
            baseline_source = "pragma solidity 0.8.19; contract StreamCore {}\n"
            edited_source = (
                "pragma solidity 0.8.19; contract StreamCore { uint256 public revision; }\n"
            )
            source_path.write_text(baseline_source, encoding="utf-8")

            def recompute_source(*_args: Any, **_kwargs: Any) -> dict[str, Any]:
                receipt = copy.deepcopy(self.report["source_semantics"])
                if source_path.read_text(encoding="utf-8") != baseline_source:
                    receipt["exact_semantic_match_count"] -= 1
                    receipt["mismatches"] = [self.manifest["moves"][0]["old_path"]]
                    receipt["result"] = "fail"
                return receipt

            with mock.patch.object(checker, "source_receipt") as recompute:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(
                        checker.main(["--repo-root", str(root), "--check-receipt"]), 0
                    )
                recompute.assert_not_called()

            source_path.write_text(edited_source, encoding="utf-8")
            with mock.patch.object(checker, "source_receipt") as recompute:
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(
                        checker.main(["--repo-root", str(root), "--check-receipt"]), 0
                    )
                recompute.assert_not_called()

            with mock.patch.object(
                checker, "source_receipt", side_effect=recompute_source
            ):
                with self.assertRaisesRegex(
                    checker.EquivalenceError, "diverges from current sources"
                ):
                    checker.main(["--repo-root", str(root), "--check-source"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
