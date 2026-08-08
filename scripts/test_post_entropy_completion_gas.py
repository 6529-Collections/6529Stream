#!/usr/bin/env python3
"""Focused hostile tests for issue #672 completion-gas evidence."""

from __future__ import annotations

import copy
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def load_module(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


generator = load_module(
    "generate_post_entropy_completion_gas",
    SCRIPT_DIR / "generate_post_entropy_completion_gas.py",
)
checker = load_module(
    "check_post_entropy_completion_gas",
    SCRIPT_DIR / "check_post_entropy_completion_gas.py",
)


class CompletionGasEvidenceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.evidence = generator.build_evidence()

    def _check_mutation(self, mutation, diagnostic: str) -> None:
        mutated = copy.deepcopy(self.evidence)
        mutation(mutated)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.json"
            path.write_text(json.dumps(mutated, indent=2) + "\n", encoding="utf-8")
            with self.assertRaisesRegex(checker.CompletionGasCheckError, diagnostic):
                checker.validate_evidence(path)

    def _seed_spec_root(self, root: Path) -> None:
        for relative_path in checker.REQUIRED_SPEC_FRAGMENTS:
            target = root / relative_path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                (checker.REPO_ROOT / relative_path).read_text(encoding="utf-8"),
                encoding="utf-8",
            )

    def test_committed_evidence_is_current(self) -> None:
        checker.validate_evidence()
        self.assertEqual(
            checker.DEFAULT_EVIDENCE.read_text(encoding="utf-8"),
            generator.render_evidence(),
        )

    def test_generator_writes_repository_lf_bytes(self) -> None:
        with tempfile.TemporaryDirectory(dir=generator.REPO_ROOT) as tmp:
            output = Path(tmp) / "post-entropy-completion-gas.json"
            self.assertEqual(generator.main(["--output", str(output)]), 0)
            rendered = output.read_bytes()
            self.assertNotIn(b"\r\n", rendered)
            self.assertEqual(rendered, generator.render_evidence().encode("utf-8"))

    def test_generator_check_rejects_crlf_serialization(self) -> None:
        with tempfile.TemporaryDirectory(dir=generator.REPO_ROOT) as tmp:
            output = Path(tmp) / "post-entropy-completion-gas.json"
            output.write_bytes(
                generator.render_evidence().replace("\n", "\r\n").encode("utf-8")
            )
            self.assertEqual(
                generator.main(["--output", str(output), "--check"]),
                1,
            )

    def test_rejects_non_as_built_status(self) -> None:
        self._check_mutation(
            lambda value: value.__setitem__("status", "complete"),
            "must bind the as-built Core",
        )

    def test_rejects_non_via_ir_profile(self) -> None:
        self._check_mutation(
            lambda value: value["compiler_profile"].__setitem__("via_ir", False),
            "compiler profile drift: via_ir",
        )

    def test_rejects_snapshot_measurement_drift(self) -> None:
        self._check_mutation(
            lambda value: value["measurement"].__setitem__(
                "measured_upper_bound_gas",
                value["measurement"]["measured_upper_bound_gas"] + 1,
            ),
            "measured upper-bound gas mismatch",
        )

    def test_rejects_measurement_start_boundary_drift(self) -> None:
        self._check_mutation(
            lambda value: value["measurement"]["scenario"].__setitem__(
                "starts_after", "before_entropy_coordinator_return"
            ),
            "measurement scenario boundary or contents drift",
        )

    def test_rejects_measurement_end_boundary_drift(self) -> None:
        self._check_mutation(
            lambda value: value["measurement"]["scenario"].__setitem__(
                "ends_after", "erc721_owner_write"
            ),
            "measurement scenario boundary or contents drift",
        )

    def test_rejects_measurement_included_work_drift(self) -> None:
        self._check_mutation(
            lambda value: value["measurement"]["scenario"]["includes"].pop(),
            "measurement scenario boundary or contents drift",
        )

    def test_rejects_admission_formula_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "formula",
                "registrationGasLimit + POST_ENTROPY_PARENT_RESERVE",
            ),
            "admission formula drift",
        )

    def test_rejects_admission_proof_scope_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "proof_scope", "exact_as_built_call_boundary"
            ),
            "admission proof scope drift",
        )

    def test_rejects_included_call_boundary_cost_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"]["included_call_boundary_costs"].pop(),
            "included call-boundary costs drift",
        )

    def test_rejects_call_upfront_reserve_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "call_upfront_reserve_gas", 3_299
            ),
            "cold CALL upfront reserve drift",
        )

    def test_rejects_actual_boundary_test_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "actual_boundary_test", "fixture-only"
            ),
            "actual Core boundary test drift",
        )

    def test_rejects_registration_gas_limit_source_drift(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "registration_gas_limit_source", "fixture constant"
            ),
            "registration gas-limit source drift",
        )

    def test_rejects_snapshot_command_semantic_drift(self) -> None:
        self._check_mutation(
            lambda value: value["compiler_profile"].__setitem__(
                "snapshot_command", "forge snapshot --via-ir"
            ),
            "snapshot command drift",
        )

    def test_rejects_reserve_not_derived_from_measurement(self) -> None:
        self._check_mutation(
            lambda value: value["admission_model"].__setitem__(
                "post_entropy_parent_reserve_gas",
                value["admission_model"]["post_entropy_parent_reserve_gas"] + 1_000,
            ),
            "not measurement-derived",
        )

    def test_rejects_fixture_source_hash_drift(self) -> None:
        self._check_mutation(
            lambda value: value["sources"][0].__setitem__(
                "sha256", "sha256:" + "00" * 32
            ),
            "bound source hash mismatch",
        )

    def test_rejects_contract_receiver_overclaim(self) -> None:
        self._check_mutation(
            lambda value: value["receiver_callback_scope"].__setitem__(
                "fixed_reserve_guarantee", "all_recipients"
            ),
            "receiver callback scope drift",
        )

    def test_rejects_stream_core_delta_claim(self) -> None:
        self._check_mutation(
            lambda value: value["core_boundary"].__setitem__(
                "stream_core_delta_bytes",
                value["core_boundary"]["stream_core_delta_bytes"] + 1,
            ),
            "StreamCore delta is not runtime-derived",
        )

    def test_rejects_complete_target_ceiling_drift(self) -> None:
        self._check_mutation(
            lambda value: value["core_boundary"].__setitem__(
                "production_complete_runtime_ceiling_bytes", 22_577
            ),
            "production Core ceiling drift",
        )

    def test_rejects_stream_core_eip170_margin_drift(self) -> None:
        self._check_mutation(
            lambda value: value["core_boundary"].__setitem__(
                "stream_core_eip170_margin_bytes",
                value["core_boundary"]["stream_core_eip170_margin_bytes"] + 1,
            ),
            "StreamCore EIP-170 margin is not runtime-derived",
        )

    def test_rejects_missing_as_built_limitations(self) -> None:
        self._check_mutation(
            lambda value: value.__setitem__("limitations", []),
            "as-built limitations drift",
        )

    def test_rejects_incomplete_as_built_limitations(self) -> None:
        self._check_mutation(
            lambda value: value["limitations"].pop(1),
            "as-built limitations drift",
        )

    def test_rejects_missing_eoa_callback_boundary(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_spec_root(root)
            path = root / "docs/stream-entropy-coordinator.md"
            original = path.read_text(encoding="utf-8")
            target = (
                "Contract-recipient callback gas is outside this fixed EOA guarantee."
            )
            mutated = original.replace(
                target,
                "Contract-recipient callback gas is part of this fixed EOA guarantee.",
                1,
            )
            self.assertNotEqual(original, mutated, "stale callback-boundary mutation anchor")
            path.write_text(mutated, encoding="utf-8")
            with self.assertRaisesRegex(
                checker.CompletionGasCheckError,
                "missing #672 spec fragment.*Contract-recipient callback",
            ):
                checker._validate_spec_fragments(root)

    def test_rejects_missing_as_built_call_boundary_proof(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_spec_root(root)
            path = root / "docs/stream-entropy-coordinator.md"
            original = path.read_text(encoding="utf-8")
            target = (
                "`testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend`"
            )
            mutated = original.replace(
                target,
                "`removedExactBoundaryProof`",
                1,
            )
            self.assertNotEqual(
                original,
                mutated,
                "stale as-built-call-boundary mutation anchor",
            )
            path.write_text(mutated, encoding="utf-8")
            with self.assertRaisesRegex(
                checker.CompletionGasCheckError,
                "missing #672 spec fragment.*testActualCoreCallBoundary",
            ):
                checker._validate_spec_fragments(root)

    def test_rejects_stale_planning_only_claim(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_spec_root(root)
            path = root / "docs/stream-entropy-coordinator.md"
            with path.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\nThis is checksum-bound target-fixture planning evidence, "
                    "not an as-built StreamCore measurement.\n"
                )
            with self.assertRaisesRegex(
                checker.CompletionGasCheckError,
                "forbidden #672 spec claim present",
            ):
                checker._validate_spec_fragments(root)

    def test_rejects_production_readiness_overclaim(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._seed_spec_root(root)
            path = root / "docs/launch-v1-target-architecture.md"
            with path.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\npost-entropy completion evidence makes StreamCore "
                    "production-ready\n"
                )
            with self.assertRaisesRegex(
                checker.CompletionGasCheckError,
                "forbidden #672 spec claim present",
            ):
                checker._validate_spec_fragments(root)


class CompletionGasSourcePolicyTests(unittest.TestCase):
    def test_accepts_complete_actual_boundary_case(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        checker._validate_actual_boundary_test(source)

    def _assert_source_rejected(self, mutated: str) -> None:
        with self.assertRaisesRegex(
            checker.CompletionGasCheckError,
            "incomplete below/at/above Core boundary regression",
        ):
            checker._validate_actual_boundary_test(mutated)

    def _assert_boundary_mutation_rejected(self, old: str, new: str) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        mutated = source.replace(old, new, 1)
        self.assertNotEqual(source, mutated, "stale boundary mutation anchor")
        self._assert_source_rejected(mutated)

    @staticmethod
    def _canonical_boundary_function(source: str) -> str:
        start_marker = (
            "    function testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend()"
        )
        end_marker = (
            "\n    function testPreparedMintAbortByReplacementManagerRestoresDenseAllocation"
        )
        start = source.index(start_marker)
        end = source.index(end_marker, start)
        return source[start:end]

    def test_rejects_decoupled_actual_boundary_cases(self) -> None:
        cases = {
            "below": (
                (
                    "bool belowSuccess = _manager.tryMintWithCoreGas(\n"
                    "            _core, exactThreshold - 1, 1, address(0xBEEF), "
                    "tokenData_, mintCommitment\n"
                    "        );"
                ),
                (
                    "exactThreshold - 1;\n"
                    "        bool belowSuccess = false;\n"
                    "        // _manager.tryMintWithCoreGas(_core, exactThreshold - 1);"
                ),
            ),
            "above": ("exactThreshold + 1", "exactThreshold + 2"),
            "exact": (
                "_core, exactThreshold, 1, address(0xBEEF)",
                "_core, exactThreshold + 0, 1, address(0xBEEF)",
            ),
            "stipend": (
                (
                    "_entropy.entryGas() <= 120_000 && _entropy.entryGas() > 118_000,\n"
                    '            "just-above boundary capped stipend"'
                ),
                'true,\n            "just-above boundary capped stipend"',
            ),
            "isolation": (
                "vm.revertToState(aboveSnapshotId)",
                "vm.revertToState(aboveSnapshotId + 1)",
            ),
        }
        for label, (old, new) in cases.items():
            with self.subTest(case=label):
                self._assert_boundary_mutation_rejected(old, new)

    def test_comments_cannot_spoof_just_above_case(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        call = (
            "_core, exactThreshold + 1, 1, address(0xBEEF), "
            "tokenData_, mintCommitment"
        )
        mutated = source.replace(call, call.replace("+ 1", "+ 2"), 1)
        mutated = mutated.replace(
            "uint256 aboveSnapshotId",
            f"// _manager.tryMintWithCoreGas({call});\n        uint256 aboveSnapshotId",
            1,
        )
        self.assertNotEqual(source, mutated, "stale comment-spoof mutation anchor")
        self._assert_source_rejected(mutated)

    def test_rejects_early_exit_before_boundary_cases(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        marker = (
            "function testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend() "
            "public {"
        )
        mutated = source.replace(marker, f"{marker}\n        return;", 1)
        self.assertNotEqual(source, mutated, "stale early-exit mutation anchor")
        self._assert_source_rejected(mutated)

    def test_rejects_inline_assembly_termination_before_boundary_cases(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        marker = (
            "function testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend() "
            "public {"
        )
        cases = (
            "assembly { return(0, 0) }",
            "assembly { stop() }",
            'assembly ("memory-safe") { stop() }',
        )
        for assembly_block in cases:
            with self.subTest(assembly_block=assembly_block):
                mutated = source.replace(
                    marker,
                    f"{marker}\n        {assembly_block}",
                    1,
                )
                self.assertNotEqual(
                    source, mutated, "stale assembly-termination mutation anchor"
                )
                self._assert_source_rejected(mutated)

    def test_rejects_body_suppressing_modifier(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        marker = (
            "function testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend() "
            "public {"
        )
        replacement = (
            "modifier suppressBoundaryBody() {}\n\n    "
            "function testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend() "
            "public suppressBoundaryBody {"
        )
        mutated = source.replace(marker, replacement, 1)
        self.assertNotEqual(source, mutated, "stale modifier mutation anchor")
        self._assert_source_rejected(mutated)

    def test_rejects_boundary_function_moved_to_foreign_abstract_contract(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        function_source = self._canonical_boundary_function(source)
        renamed_source = function_source.replace(
            "testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend",
            "removedCanonicalBoundaryTest",
            1,
        )
        mutated = source.replace(function_source, renamed_source, 1)
        mutated += (
            "\nabstract contract ForeignNonExecutedBoundaryProof {\n"
            f"{function_source}\n"
            "}\n"
        )
        self.assertNotEqual(source, mutated, "stale foreign-contract mutation anchor")
        self._assert_source_rejected(mutated)

    def test_rejects_missing_renamed_or_abstract_canonical_contract(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        declaration = "contract StreamCorePermanentTargetTest is CharacterizationTestBase"
        cases = (
            declaration.replace(
                "StreamCorePermanentTargetTest", "RenamedPermanentTargetTest", 1
            ),
            f"abstract {declaration}",
        )
        for replacement in cases:
            with self.subTest(replacement=replacement):
                mutated = source.replace(declaration, replacement, 1)
                self.assertNotEqual(
                    source, mutated, "stale canonical-contract mutation anchor"
                )
                self._assert_source_rejected(mutated)

    def test_rejects_duplicate_canonical_contract_or_function(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        function_name = (
            "testActualCoreCallBoundaryCoversBelowAtAndAboveWithFullStipend"
        )
        cases = (
            (
                "\ncontract StreamCorePermanentTargetTest is "
                "CharacterizationTestBase {}\n"
            ),
            (
                "\ncontract ForeignBoundaryDuplicate {\n"
                f"    function {function_name}() public {{}}\n"
                "}\n"
            ),
        )
        for suffix in cases:
            with self.subTest(suffix=suffix):
                self._assert_source_rejected(source + suffix)

    def test_comments_and_strings_cannot_spoof_canonical_contract(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        declaration = "contract StreamCorePermanentTargetTest is CharacterizationTestBase"
        renamed = declaration.replace(
            "StreamCorePermanentTargetTest", "RenamedPermanentTargetTest", 1
        )
        mutated = source.replace(declaration, renamed, 1)
        mutated += (
            "\n/* contract StreamCorePermanentTargetTest is CharacterizationTestBase "
            "{ function spoof() public {} } */\n"
            'contract StringSpoof { string constant VALUE = "contract '
            'StreamCorePermanentTargetTest is CharacterizationTestBase {"; }\n'
        )
        self.assertNotEqual(source, mutated, "stale lexical-spoof mutation anchor")
        self._assert_source_rejected(mutated)

    def test_rejects_unbalanced_canonical_contract_body(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        prefix, separator, suffix = source.rpartition("\n}")
        self.assertEqual(separator, "\n}", "stale canonical-contract closing anchor")
        self.assertTrue(suffix.strip() == "", "canonical contract must remain last")
        self._assert_source_rejected(prefix + "\n")

    def test_rejects_unreachable_boundary_case_wrapper(self) -> None:
        source = checker.CORE_TEST_PATH.read_text(encoding="utf-8")
        mutated = source.replace(
            "        bool belowSuccess = _manager.tryMintWithCoreGas(",
            "        if (false) {\n            bool belowSuccess = "
            "_manager.tryMintWithCoreGas(",
            1,
        )
        next_test = "\n    function testPreparedMintAbortByReplacementManagerRestoresDenseAllocation"
        mutated = mutated.replace(
            next_test,
            "        }\n" + next_test,
            1,
        )
        self.assertNotEqual(source, mutated, "stale unreachable-wrapper mutation anchor")
        self._assert_source_rejected(mutated)


if __name__ == "__main__":
    unittest.main(verbosity=2)
