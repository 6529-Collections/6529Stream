#!/usr/bin/env python3
"""Mutation tests for check_governance_action_policy.py."""

from __future__ import annotations

import copy
import json
import unittest

from tools.protocol import check_governance_action_policy as checker


class GovernanceActionPolicyCheckerTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.policy = json.loads(checker.POLICY_PATH.read_text(encoding="utf-8"))

    def test_repository_policy_passes(self) -> None:
        checker.check(copy.deepcopy(self.policy))

    def test_current_schedule_and_execution_policy_paths_pass(self) -> None:
        checker.validate_policy_call_path(
            checker.EXECUTOR_PATH.read_text(encoding="utf-8"),
            checker.SCHEDULING_PATH.read_text(encoding="utf-8"),
        )

    def test_schedule_delegation_requires_real_import_and_bound_inputs(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        scheduling = checker.SCHEDULING_PATH.read_text(encoding="utf-8")
        for before, after in (
            ('import "./StreamGovernanceScheduling.sol";',
             '// import "./StreamGovernanceScheduling.sol";'),
            ('import "./StreamGovernanceScheduling.sol";', 'import "./OtherScheduling.sol";'),
            ("StreamGovernanceScheduling.prepare(", "OtherScheduling.prepare("),
            ("executing: _executing", "executing: false"),
            ("StreamGovernanceScheduling.Prepared memory prepared =",
             "_nonce += 1; StreamGovernanceScheduling.Prepared memory prepared ="),
            ("StreamGovernanceScheduling.Prepared memory prepared =",
             "{ _nonce += 1; } StreamGovernanceScheduling.Prepared memory prepared ="),
            ("StreamGovernanceScheduling.Prepared memory prepared =",
             "if (ctx.actionClass == 1) { _nonce += 1; } StreamGovernanceScheduling.Prepared memory prepared ="),
        ):
            with self.subTest(before=before, after=after):
                self.assertIn(before, executor)
                with self.assertRaisesRegex(ValueError, "policy validation path"):
                    checker.validate_policy_call_path(executor.replace(before, after), scheduling)

    @staticmethod
    def _policy_call(source: str) -> str:
        start = source.index("StreamGovernanceActionPolicy.validateCalls(")
        return source[start:source.index(");", start) + 2]

    def test_scheduling_policy_validation_cannot_be_missing_conditional_or_bypassed(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        scheduling = checker.SCHEDULING_PATH.read_text(encoding="utf-8")
        call = self._policy_call(scheduling)
        for replacement in (
            "", "/* " + call + " */", "if (false) " + call,
            "if (false) { " + call + " }", "return prepared; " + call,
            call.replace("ctx.actionClass", "uint8(0)"),
            call.replace("manifest.actionPolicyCatalogHash", "bytes32(0)"),
        ):
            with self.subTest(replacement=replacement):
                with self.assertRaisesRegex(ValueError, "policy validation path"):
                    checker.validate_policy_call_path(executor, scheduling.replace(call, replacement))

    def test_other_function_cannot_supply_scheduling_validation(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        scheduling = checker.SCHEDULING_PATH.read_text(encoding="utf-8")
        call = self._policy_call(scheduling)
        moved = scheduling.replace(call, "") + "\nfunction unrelated() public { " + call + " }\n"
        with self.assertRaisesRegex(ValueError, "scheduling policy validation"):
            checker.validate_policy_call_path(executor, moved)

    def test_execution_policy_validation_retains_exact_arguments_and_order(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        scheduling = checker.SCHEDULING_PATH.read_text(encoding="utf-8")
        call = self._policy_call(executor)
        for replacement in (
            "", "/* " + call + " */", "if (false) { " + call + " }",
            call.replace("scheduledCallDatas", "callDatas"),
            call.replace("_manifest.actionPolicyEntryCount", "uint256(0)"),
            "return; " + call,
        ):
            with self.subTest(replacement=replacement):
                with self.assertRaisesRegex(ValueError, "policy validation path"):
                    checker.validate_policy_call_path(executor.replace(call, replacement), scheduling)
        effect = "action.status = GovernanceActionStatus.EXECUTED;"
        late = executor.replace(call, "").replace(effect, effect + "\n" + call)
        with self.assertRaisesRegex(ValueError, "execution policy validation before effects"):
            checker.validate_policy_call_path(late, scheduling)

    def test_catalog_snapshot_delegation_cannot_omit_saved_hash_or_validation(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        bootstrap = checker.BOOTSTRAP_PATH.read_text(encoding="utf-8")
        for before, after in (
            ("_actionPolicyCatalogHashes[actionId] = _actionPolicy.catalogHash;", ""),
            ("StreamGovernanceBootstrap.validateExecution(", "differentValidation("),
            ("scheduledCatalogHash: _actionPolicyCatalogHashes[actionId]", "scheduledCatalogHash: _actionPolicy.catalogHash"),
        ):
            with self.subTest(source=before):
                self.assertIn(before, executor)
                with self.assertRaisesRegex(ValueError, "snapshot delegation"):
                    checker.validate_catalog_snapshot_source(executor.replace(before, after), bootstrap)

    def test_catalog_snapshot_helper_must_compare_and_reject_stale_catalog(self) -> None:
        executor = checker.EXECUTOR_PATH.read_text(encoding="utf-8")
        bootstrap = checker.BOOTSTRAP_PATH.read_text(encoding="utf-8")
        for before, after in (
            ("currentCatalogHash = actionPolicy.catalogHash;", "currentCatalogHash = bytes32(0);"),
            ("if (scheduledCatalogHash != currentCatalogHash)", "if (false)"),
            ("revert IStreamGovernanceExecutor.GovernanceActionPolicySnapshotMismatch(", "ignoreMismatch("),
        ):
            with self.subTest(source=before):
                self.assertIn(before, bootstrap)
                with self.assertRaisesRegex(ValueError, "snapshot check"):
                    checker.validate_catalog_snapshot_source(executor, bootstrap.replace(before, after))

    def test_unknown_tuple_policy_cannot_be_permissive(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["unknown_tuple_policy"] = "allow"
        with self.assertRaisesRegex(ValueError, "unknown tuple policy"):
            checker.check(policy)

    def test_runtime_catalog_cap_is_exact(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["max_entries"] = 1025
        with self.assertRaisesRegex(checker.jsonschema.ValidationError, "1024"):
            checker.check(policy)

    def test_runtime_lookup_key_is_exact(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["lookup_key"] = [
            "action_class",
            "selector",
            "target",
        ]
        with self.assertRaisesRegex(ValueError, "runtime enforcement lookup key"):
            checker.check(policy)

    def test_runtime_domain_hash_is_recomputed(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["domains"]["entry"]["keccak256"] = (
            "0x" + "11" * 32
        )
        with self.assertRaisesRegex(ValueError, "entry domain hash"):
            checker.check(policy)

    def test_runtime_domain_preimage_is_exact(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["domains"]["catalog"]["preimage"] += "-drift"
        with self.assertRaisesRegex(ValueError, "catalog domain preimage"):
            checker.check(policy)

    def test_zero_value_semantics_are_exact(self) -> None:
        for field, value, expected_error in (
            ("value_limit", "1", "zero value limit"),
            ("semantics_hash", "0x" + "11" * 32, "zero value semantics hash"),
        ):
            with self.subTest(field=field):
                policy = copy.deepcopy(self.policy)
                policy["value_semantics"]["zero_only"][field] = value
                with self.assertRaisesRegex(ValueError, expected_error):
                    checker.check(policy)

    def test_complete_candidate_cannot_exceed_runtime_cap(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["runtime_enforcement"]["max_entries"] = 0
        with self.assertRaisesRegex(ValueError, "candidate entry cap"):
            checker._validate_candidate_binding(self._complete_candidate(), policy)

    def test_source_catalog_omission_is_rejected(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["source_catalog"]["entries"].pop()
        with self.assertRaisesRegex(ValueError, "source catalog tuple set"):
            checker.check(policy)

    def test_source_catalog_selector_drift_is_rejected(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["source_catalog"]["entries"][0]["selector"] = "0x12345678"
        with self.assertRaisesRegex(ValueError, "source selector"):
            checker.check(policy)

    def test_generic_dispatch_route_is_rejected(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["source_catalog"]["entries"][0]["signature"] = "multicall(bytes[])"
        with self.assertRaisesRegex(ValueError, "forbidden route"):
            checker.check(policy)

    def test_nonzero_policy_requires_canonical_semantics(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["candidate_binding"] = {
            "status": "complete",
            "chain_id": 1,
            "executor": "0x" + "11" * 20,
            "candidate_profile_hash": "0x" + "22" * 32,
            "catalog_hash": "0x" + "33" * 32,
            "entry_count": 1,
            "entries": [
                {
                    "action_class": 1,
                    "target": "0x" + "44" * 20,
                    "selector": "0x12345678",
                    "target_code_hash": "0x" + "55" * 32,
                    "target_profile_hash": "0x" + "66" * 32,
                    "call_type": 1,
                    "value_policy": 1,
                    "value_limit": "1",
                    "value_semantics_hash": "0x" + "77" * 32,
                }
            ],
        }
        with self.assertRaisesRegex(ValueError, "nonzero value semantics"):
            checker.check(policy)

    def test_complete_candidate_catalog_commitment_is_recomputed(self) -> None:
        policy = copy.deepcopy(self.policy)
        binding = self._complete_candidate()
        binding["catalog_hash"] = checker.candidate_catalog_hash(binding)
        policy["candidate_binding"] = binding
        checker.check(policy)

        policy["candidate_binding"]["catalog_hash"] = "0x" + "33" * 32
        with self.assertRaisesRegex(ValueError, "bound candidate catalog hash"):
            checker.check(policy)

    def test_complete_candidate_rejects_zero_direct_target_hash(self) -> None:
        policy = copy.deepcopy(self.policy)
        binding = self._complete_candidate()
        binding["entries"][0]["target_code_hash"] = "0x" + "00" * 32
        binding["catalog_hash"] = checker.candidate_catalog_hash(binding)
        policy["candidate_binding"] = binding
        with self.assertRaisesRegex(ValueError, "bound direct target code hash"):
            checker.check(policy)

    def test_unbound_candidate_cannot_carry_entries(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["candidate_binding"]["entries"] = [{}]
        with self.assertRaisesRegex(ValueError, "unbound candidate entries"):
            checker.check(policy)

    def test_risk_cannot_close_without_candidate_evidence(self) -> None:
        policy = copy.deepcopy(self.policy)
        policy["release_gate"]["status"] = "closed"
        with self.assertRaisesRegex(ValueError, "risk must remain open"):
            checker.check(policy)

    @staticmethod
    def _complete_candidate() -> dict:
        return {
            "status": "complete",
            "chain_id": 1,
            "executor": "0x" + "11" * 20,
            "candidate_profile_hash": "0x" + "22" * 32,
            "catalog_hash": "0x" + "00" * 32,
            "entry_count": 1,
            "entries": [
                {
                    "action_class": 0,
                    "target": "0x" + "11" * 20,
                    "target_profile": "GOVERNANCE_EXECUTOR",
                    "signature": "registerProposer(address,bool)",
                    "selector": "0x0794ec84",
                    "target_code_hash": "0x" + "55" * 32,
                    "target_profile_hash": "0x" + "66" * 32,
                    "call_type": 1,
                    "value_policy": 0,
                    "value_limit": "0",
                    "value_semantics_hash": "0x" + "00" * 32,
                }
            ],
        }


if __name__ == "__main__":
    unittest.main()
