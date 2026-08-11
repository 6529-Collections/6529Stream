#!/usr/bin/env python3
"""Focused tests for the preparatory canonical deployment candidate v2."""

from __future__ import annotations

import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from unittest import mock
from pathlib import Path
from typing import Any

import check_canonical_deployment_candidate as checker
import execute_canonical_deployment_plan as executor
import materialize_canonical_deployment_plan as materializer


REPO_ROOT = Path(__file__).resolve().parent.parent
NEGATIVE_FIXTURES = Path(
    "test/fixtures/canonical-deployment-candidate-v2/negative-fixtures.json"
)
SYNTHETIC_CANDIDATE = Path("deployments/config/synthetic-candidate-v2.json")
SYNTHETIC_EVIDENCE = Path(
    "deployments/canonical-deployment-evidence/synthetic-candidate-v2.json"
)
SYNTHETIC_SENDER = "0x0000000000000000000000000000000000000677"
SYNTHETIC_STARTING_NONCE = 11


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(value, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
        newline="\n",
    )


def deterministic_sha(value: int) -> str:
    return "sha256:" + f"{value:02x}" * 32


def deterministic_hash(value: int) -> str:
    return "0x" + f"{value:02x}" * 32


def deterministic_address(value: int) -> str:
    return "0x" + f"{value:040x}"


def slug(value: str) -> str:
    return value.lower().replace("_", "-")


def pointer_parent(value: Any, pointer: str) -> tuple[Any, str | int]:
    if not pointer.startswith("/"):
        raise AssertionError(f"JSON pointer must be absolute: {pointer}")
    parts = [
        part.replace("~1", "/").replace("~0", "~")
        for part in pointer[1:].split("/")
    ]
    cursor = value
    for part in parts[:-1]:
        cursor = cursor[int(part)] if isinstance(cursor, list) else cursor[part]
    leaf: str | int = int(parts[-1]) if isinstance(cursor, list) else parts[-1]
    return cursor, leaf


def pointer_get(value: Any, pointer: str) -> Any:
    if pointer == "":
        return value
    parent, leaf = pointer_parent(value, pointer)
    return parent[leaf]


def apply_operations(value: Any, operations: list[dict[str, Any]]) -> None:
    for operation in operations:
        parent, leaf = pointer_parent(value, operation["path"])
        if operation["op"] == "remove":
            if isinstance(parent, list):
                parent.pop(leaf)
            else:
                del parent[leaf]
        elif operation["op"] == "set":
            parent[leaf] = copy.deepcopy(operation["value"])
        elif operation["op"] == "copy":
            parent[leaf] = copy.deepcopy(pointer_get(value, operation["from"]))
        else:
            raise AssertionError(f"unsupported fixture operation: {operation['op']}")


class SyntheticCandidate:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for relative in (
            checker.DEFAULT_SCHEMA,
            checker.DEFAULT_PROFILE,
            checker.DEFAULT_SOURCE_LAYOUT,
            checker.DEFAULT_RISK_REGISTER,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, target)
        self.profile = materializer.load_json(self.root / checker.DEFAULT_PROFILE)
        self.candidate = self._candidate()
        self.evidence: dict[str, Any] = {}
        self.bind_create_sequence()
        self.bind_evidence()

    def close(self) -> None:
        self.temporary.cleanup()

    def _instance(self, entry: dict[str, Any]) -> dict[str, Any]:
        profile_id = entry["id"]
        names = entry["implementation"]["names"]
        if names:
            name = names[0]
        elif entry["implementation"]["mode"] == "manifest_equivalent":
            name = "StreamGovernanceExecutor"
        else:
            name = "StreamPaymentIntentAdapter"
        instance_id = slug(entry["key"])
        runtime_hash = deterministic_hash((profile_id + 0x40) % 256)
        initcode_hash = deterministic_hash((profile_id + 0x80) % 256)
        return {
            "order": profile_id,
            "instance_id": instance_id,
            "profile_entry_id": profile_id,
            "profile_entry_key": entry["key"],
            "deployment_scope": entry["deployment_scope"],
            "implementation_match": entry["implementation"]["mode"],
            "target": {
                "kind": "production_contract",
                "name": name,
                "source": f"smart-contracts/{name}.sol",
                "artifact_relative_path": f"{name}.sol/{name}.json",
                "artifact_sha256": deterministic_sha(profile_id),
            },
            "address": deterministic_address(profile_id),
            "depends_on": [],
            "constructor": {
                "types": [],
                "arguments": [],
                "encoded_args_keccak256": deterministic_hash(0x10),
            },
            "linked_libraries": [],
            "authority_dependency_bindings": [],
            "verified_interfaces": copy.deepcopy(entry["required_interfaces"]),
            "verified_markers": copy.deepcopy(entry["required_markers"]),
            "runtime": {
                "immutable_values": {},
                "expected_keccak256": runtime_hash,
            },
            "expected_linked_creation_keccak256": deterministic_hash(
                (profile_id + 0x20) % 256
            ),
            "expected_initcode_keccak256": initcode_hash,
            "on_chain": {
                "status": "observed",
                "deployment_transaction": deterministic_hash(
                    (profile_id + 0xA0) % 256
                ),
                "block_number": 1000 + profile_id,
                "block_hash": deterministic_hash((profile_id + 0xC0) % 256),
                "initcode_keccak256": initcode_hash,
                "runtime_code_keccak256": runtime_hash,
                "source_verification_status": "verified",
            },
            "review_status": "reviewed",
        }

    def _candidate(self) -> dict[str, Any]:
        _, profile_sha256 = materializer.load_json_with_sha256(
            self.root / checker.DEFAULT_PROFILE
        )
        _, source_layout_sha256 = materializer.load_json_with_sha256(
            self.root / checker.DEFAULT_SOURCE_LAYOUT
        )
        return {
            "schema_version": checker.CANDIDATE_SCHEMA_VERSION,
            "candidate_id": "synthetic-mainnet-candidate-v2",
            "candidate_kind": "genesis_release_candidate",
            "status": "complete",
            "production_candidate": True,
            "readiness_evidence": False,
            "network": {
                "environment": "production",
                "name": "mainnet",
                "chain_id": 1,
            },
            "source_commit": "1" * 40,
            "source_layout": {
                "status": "complete",
                "migration_issue": (
                    "https://github.com/6529-Collections/6529Stream/issues/716"
                ),
                "manifest_path": checker.DEFAULT_SOURCE_LAYOUT.as_posix(),
                "manifest_sha256": source_layout_sha256,
            },
            "genesis_profile": {
                "status": "complete",
                "path": checker.DEFAULT_PROFILE.as_posix(),
                "schema_version": checker.PROFILE_SCHEMA_VERSION,
                "sha256": profile_sha256,
                "entry_count": checker.PROFILE_ENTRY_COUNT,
            },
            "governed_parameter_inventory": {
                "status": "complete",
                "path": "release-artifacts/governed-parameter-inventory.json",
                "schema_version": "6529stream.governed-parameter-inventory.v1",
                "identity_sha256": deterministic_sha(0x32),
            },
            "record_family_authorization": {
                "status": "complete",
                "path": "release-artifacts/record-family-authorization-inventory.json",
                "schema_version": "6529stream.record-family-authorization-inventory.v1",
                "identity_sha256": deterministic_sha(0x33),
            },
            "release_build": {
                "status": "complete",
                "receipt_path": "out-release/release-build-manifest.json",
                "receipt_sha256": deterministic_sha(0x34),
                "target_catalog_sha256": deterministic_sha(0x35),
                "config_path": "release-artifacts/contracts.json",
                "config_sha256": deterministic_sha(0x36),
                "foundry_config_path": "foundry.toml",
                "foundry_config_sha256": deterministic_sha(0x37),
            },
            "retained_evidence": {
                "status": "not_available",
                "schema_version": None,
                "path": None,
                "sha256": None,
            },
            "linked_libraries": [],
            "instances": [self._instance(entry) for entry in self.profile["entries"]],
            "factory_spawned_exclusions": copy.deepcopy(
                self.profile["factory_spawned_exclusions"]
            ),
            "out_of_inventory": copy.deepcopy(self.profile["out_of_inventory"]),
        }

    def bind_create_sequence(self) -> None:
        deployables = [
            *self.candidate["linked_libraries"],
            *self.candidate["instances"],
        ]
        for index, deployable in enumerate(deployables):
            deployable["address"] = executor.create_address(
                SYNTHETIC_SENDER,
                SYNTHETIC_STARTING_NONCE + index,
            )

    def bind_evidence(self) -> None:
        identity_sha256, identity_keccak256 = checker.candidate_identity(
            self.candidate
        )
        self.evidence = {
            "schema_version": "6529stream.canonical-deployment-evidence.v1",
            "candidate_identity": {
                "candidate_id": self.candidate["candidate_id"],
                "candidate_identity_sha256": identity_sha256,
                "candidate_identity_keccak256": identity_keccak256,
                "source_commit": self.candidate["source_commit"],
                "release_build": checker._release_build_identity(self.candidate),
            },
            "network": copy.deepcopy(self.candidate["network"]),
            "release_posture": {
                "readiness_evidence": False,
                "note": "Synthetic test evidence only.",
            },
        }
        evidence_path = self.root / SYNTHETIC_EVIDENCE
        write_json(evidence_path, self.evidence)
        evidence_sha256 = materializer.file_sha256(evidence_path)
        self.candidate["retained_evidence"] = {
            "status": "bound",
            "schema_version": self.evidence["schema_version"],
            "path": SYNTHETIC_EVIDENCE.as_posix(),
            "sha256": evidence_sha256,
        }
        write_json(self.root / SYNTHETIC_CANDIDATE, self.candidate)

    def bind_mutated_evidence(self) -> None:
        evidence_path = self.root / SYNTHETIC_EVIDENCE
        write_json(evidence_path, self.evidence)
        self.candidate["retained_evidence"]["sha256"] = materializer.file_sha256(
            evidence_path
        )
        write_json(self.root / SYNTHETIC_CANDIDATE, self.candidate)

    def audit(self) -> checker.CandidateAudit:
        return checker.audit_candidate(
            self.root,
            candidate_path=SYNTHETIC_CANDIDATE,
        )

    def _snapshot(
        self,
        path: Path,
    ) -> materializer.release_build.ReleaseFileSnapshot:
        resolved = path.resolve()
        raw = resolved.read_bytes()
        return materializer.release_build.ReleaseFileSnapshot(
            path=resolved,
            raw=raw,
            sha256=materializer.sha256_bytes(raw),
        )

    def prepare_materialization(self) -> materializer.ReceiptValidator:
        """Create a 37-instance isolated-build universe without Forge."""
        plan_schema = self.root / materializer.PLAN_SCHEMA_PATH
        plan_schema.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(REPO_ROOT / materializer.PLAN_SCHEMA_PATH, plan_schema)
        config_path = self.root / materializer.CANONICAL_CONFIG
        config_path.parent.mkdir(parents=True, exist_ok=True)
        config_path.write_text("{}\n", encoding="utf-8", newline="\n")
        foundry_path = self.root / materializer.CANONICAL_FOUNDRY_CONFIG
        foundry_path.write_text(
            "[profile.default]\n",
            encoding="utf-8",
            newline="\n",
        )

        creation = bytes.fromhex("6000")
        runtime = bytes.fromhex("6001")
        empty_constructor_hash = materializer.keccak256_hex(b"")
        creation_hash = materializer.keccak256_hex(creation)
        runtime_hash = materializer.keccak256_hex(runtime)
        targets: dict[tuple[str, str, str], dict[str, str]] = {}
        artifact_paths: dict[str, Path] = {}
        artifact = {
            "abi": [],
            "bytecode": {
                "object": "0x" + creation.hex(),
                "linkReferences": {},
            },
            "deployedBytecode": {
                "object": "0x" + runtime.hex(),
                "linkReferences": {},
                "immutableReferences": {},
            },
        }
        for instance in self.candidate["instances"]:
            target = instance["target"]
            relative = target["artifact_relative_path"]
            artifact_path = self.root / "out-release" / relative
            if relative not in artifact_paths:
                write_json(artifact_path, artifact)
                artifact_paths[relative] = artifact_path
            target["artifact_sha256"] = materializer.file_sha256(artifact_path)
            targets[
                (target["kind"], target["name"], target["source"])
            ] = copy.deepcopy(target)
            instance["constructor"] = {
                "types": [],
                "arguments": [],
                "encoded_args_keccak256": empty_constructor_hash,
            }
            instance["linked_libraries"] = []
            instance["runtime"] = {
                "immutable_values": {},
                "expected_keccak256": runtime_hash,
            }
            instance["expected_linked_creation_keccak256"] = creation_hash
            instance["expected_initcode_keccak256"] = creation_hash
            instance["on_chain"]["initcode_keccak256"] = creation_hash
            instance["on_chain"]["runtime_code_keccak256"] = runtime_hash

        receipt_path = self.root / materializer.CANONICAL_RECEIPT
        receipt = {
            "schema_version": "6529stream.release-build.v1",
            "source": {
                "config": materializer.CANONICAL_CONFIG.as_posix(),
                "config_sha256": materializer.file_sha256(config_path),
                "foundry_config": materializer.CANONICAL_FOUNDRY_CONFIG.as_posix(),
                "foundry_config_sha256": materializer.file_sha256(foundry_path),
            },
            "policy": {
                "compilation_unit": "one target and its import closure",
                "solc_version": "0.8.19",
                "solc_long_version": "0.8.19+commit.7dd6d404",
                "evm_version": "paris",
                "optimizer_enabled": True,
                "optimizer_runs": 200,
                "via_ir": True,
                "bytecode_hash": "none",
                "cbor_metadata": False,
                "controlled_forge_environment": {"FOUNDRY_PROFILE": "default"},
                "forge_profile": "default",
                "foundry_version": "test",
                "forge_version": "test",
                "forge_version_sha256": deterministic_sha(0),
                "sanitized_environment_prefixes": ["DAPP_", "FOUNDRY_"],
                "restricted_source_roots": ["script", "test"],
                "portable_compiler_paths": {
                    "basePath": ".",
                    "includePaths": ["."],
                    "allowPaths": [".", "lib"],
                },
            },
            "targets": sorted(
                targets.values(),
                key=lambda item: (
                    item["kind"],
                    item["name"],
                    item["source"],
                ),
            ),
        }
        write_json(receipt_path, receipt)
        self.candidate["release_build"] = {
            "status": "complete",
            "receipt_path": materializer.CANONICAL_RECEIPT.as_posix(),
            "receipt_sha256": materializer.file_sha256(receipt_path),
            "target_catalog_sha256": materializer.target_catalog_sha256(receipt),
            "config_path": materializer.CANONICAL_CONFIG.as_posix(),
            "config_sha256": materializer.file_sha256(config_path),
            "foundry_config_path": materializer.CANONICAL_FOUNDRY_CONFIG.as_posix(),
            "foundry_config_sha256": materializer.file_sha256(foundry_path),
        }
        self.bind_evidence()

        def validator(
            _repo_root: Path,
            validated_config_path: Path,
            validated_foundry_path: Path,
            _output_dir: Path,
        ) -> materializer.release_build.ValidatedReleaseOutput:
            return materializer.release_build.ValidatedReleaseOutput(
                receipt=copy.deepcopy(receipt),
                receipt_snapshot=self._snapshot(receipt_path),
                config_snapshot=self._snapshot(validated_config_path),
                foundry_config_snapshot=self._snapshot(validated_foundry_path),
                artifact_snapshots=tuple(
                    self._snapshot(path)
                    for path in sorted(artifact_paths.values())
                ),
            )

        return validator


class PlanningCandidate:
    def __init__(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        for relative in (
            checker.DEFAULT_CANDIDATE,
            checker.DEFAULT_SCHEMA,
            checker.DEFAULT_PROFILE,
            checker.DEFAULT_SOURCE_LAYOUT,
            checker.DEFAULT_RISK_REGISTER,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, target)
        self.candidate = materializer.load_json(
            self.root / checker.DEFAULT_CANDIDATE
        )

    def close(self) -> None:
        self.temporary.cleanup()

    def audit(self) -> checker.CandidateAudit:
        write_json(self.root / checker.DEFAULT_CANDIDATE, self.candidate)
        return checker.audit_candidate(self.root)


class CandidateV2Tests(unittest.TestCase):
    def test_committed_planning_candidate_is_honest_and_incomplete(self) -> None:
        audit = checker.audit_candidate(REPO_ROOT)
        self.assertEqual(audit.profile_entry_count, 37)
        self.assertEqual(audit.instance_count, 0)
        self.assertEqual(audit.linked_library_count, 0)
        self.assertEqual(len(audit.blockers), 44)
        self.assertIn("candidate status is planning", audit.blockers)
        self.assertNotIn("source layout remains pending issue #716", audit.blockers)
        self.assertNotIn("genesis profile identity is not frozen", audit.blockers)
        self.assertIn("canonical retained evidence is not bound", audit.blockers)
        candidate = materializer.load_json(REPO_ROOT / checker.DEFAULT_CANDIDATE)
        self.assertEqual(candidate["status"], "planning")
        self.assertFalse(candidate["production_candidate"])
        self.assertFalse(candidate["readiness_evidence"])
        self.assertIsNone(candidate["source_commit"])
        self.assertEqual(
            candidate["source_layout"],
            {
                "status": "complete",
                "migration_issue": (
                    "https://github.com/6529-Collections/6529Stream/issues/716"
                ),
                "manifest_path": checker.DEFAULT_SOURCE_LAYOUT.as_posix(),
                "manifest_sha256": (
                    "sha256:a4a8be3df18da217e4efc3d4d09b151807bdc152125f524f1493dd39690d9f65"
                ),
            },
        )
        self.assertEqual(candidate["genesis_profile"]["status"], "complete")
        self.assertEqual(
            candidate["genesis_profile"]["sha256"],
            "sha256:e02b966c735ed62d717830612a66f759b07c037e1dee49ec2a46946f6b4d1135",
        )
        self.assertEqual(candidate["governed_parameter_inventory"]["status"], "pending_dependency")
        self.assertEqual(candidate["record_family_authorization"]["status"], "pending_dependency")
        self.assertEqual(candidate["release_build"]["status"], "not_available")
        self.assertEqual(candidate["retained_evidence"]["status"], "not_available")
        self.assertEqual(candidate["linked_libraries"], [])
        self.assertEqual(candidate["instances"], [])

    def test_planning_source_layout_pin_fails_closed_on_path_hash_or_status_drift(
        self,
    ) -> None:
        for field, value, expected in (
            ("manifest_path", "smart-contracts/other-layout.json", "path is noncanonical"),
            ("manifest_sha256", deterministic_sha(0xA4), "SHA-256 mismatch"),
        ):
            with self.subTest(field=field):
                fixture = PlanningCandidate()
                try:
                    fixture.candidate["source_layout"][field] = value
                    with self.assertRaisesRegex(checker.CandidateError, expected):
                        fixture.audit()
                finally:
                    fixture.close()

        fixture = PlanningCandidate()
        try:
            fixture.candidate["source_layout"]["status"] = "pending_issue_716"
            self.assertIn(
                "source layout remains pending issue #716",
                fixture.audit().blockers,
            )
        finally:
            fixture.close()

    def test_planning_profile_pin_fails_closed_on_path_hash_or_status_drift(
        self,
    ) -> None:
        for field, value, expected in (
            (
                "path",
                "release-artifacts/other-profile.json",
                "genesis_profile.*path",
            ),
            ("sha256", deterministic_sha(0xE0), "SHA-256 mismatch"),
        ):
            with self.subTest(field=field):
                fixture = PlanningCandidate()
                try:
                    fixture.candidate["genesis_profile"][field] = value
                    with self.assertRaisesRegex(checker.CandidateError, expected):
                        fixture.audit()
                finally:
                    fixture.close()

        fixture = PlanningCandidate()
        try:
            fixture.candidate["genesis_profile"]["status"] = "planning"
            self.assertIn(
                "genesis profile identity is not frozen",
                fixture.audit().blockers,
            )
        finally:
            fixture.close()

    def test_committed_planning_identity_golden(self) -> None:
        audit = checker.audit_candidate(REPO_ROOT)
        self.assertEqual(
            audit.candidate_identity_sha256,
            "sha256:5154fbedd7e4f0a0168729ec030415f13d9e68f44e02b68328923ca7c8f881f4",
        )
        self.assertEqual(
            audit.candidate_identity_keccak256,
            "0x432f9c5a600332213a9090089d61a1bde66db96d7b50ace89c29f5215bea58c4",
        )

    def test_identity_excludes_only_retained_evidence(self) -> None:
        candidate = materializer.load_json(REPO_ROOT / checker.DEFAULT_CANDIDATE)
        before = checker.candidate_identity(candidate)
        candidate["retained_evidence"] = {
            "status": "bound",
            "schema_version": "example.v1",
            "path": "deployments/example.json",
            "sha256": deterministic_sha(0xFE),
        }
        self.assertEqual(checker.candidate_identity(candidate), before)
        candidate["source_layout"]["status"] = "pending_issue_716"
        self.assertNotEqual(checker.candidate_identity(candidate), before)

    def test_identity_is_stable_across_member_order(self) -> None:
        candidate = materializer.load_json(REPO_ROOT / checker.DEFAULT_CANDIDATE)
        reordered = dict(reversed(list(candidate.items())))
        self.assertEqual(
            checker.candidate_identity(candidate),
            checker.candidate_identity(reordered),
        )

    def test_synthetic_complete_candidate_has_no_blockers(self) -> None:
        fixture = SyntheticCandidate()
        try:
            audit = fixture.audit()
            self.assertEqual(audit.instance_count, 37)
            self.assertEqual(audit.blockers, ())
        finally:
            fixture.close()

    def test_planning_candidate_fails_before_release_receipt_validation(self) -> None:
        receipt_validator = mock.Mock()
        with self.assertRaisesRegex(
            materializer.DeploymentPlanError,
            "canonical deployment candidate v2 is incomplete",
        ):
            materializer.materialize_deployment_plan(
                REPO_ROOT,
                REPO_ROOT / checker.DEFAULT_CANDIDATE,
                receipt_validator=receipt_validator,
            )
        receipt_validator.assert_not_called()

    def test_executor_rejects_planning_candidate_before_rpc_or_forge(self) -> None:
        with (
            mock.patch.object(executor, "rpc_client") as rpc_client,
            mock.patch.object(executor, "start_local_anvil") as start_anvil,
            mock.patch.object(executor.subprocess, "run") as command_runner,
            mock.patch("sys.stderr"),
        ):
            result = executor.main(
                [
                    "--repo-root",
                    str(REPO_ROOT),
                    "--candidate",
                    checker.DEFAULT_CANDIDATE.as_posix(),
                    "--plan",
                    "tmp/nonexistent-v2-plan.json",
                    "--mode",
                    "anvil",
                    "--local-anvil",
                ]
            )
        self.assertEqual(result, 1)
        rpc_client.assert_not_called()
        start_anvil.assert_not_called()
        command_runner.assert_not_called()

    def test_blocked_complete_candidate_fails_before_materialization(self) -> None:
        fixture = SyntheticCandidate()
        try:
            fixture.candidate["instances"][0]["review_status"] = "unreviewed"
            fixture.bind_evidence()
            receipt_validator = mock.Mock()
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "is not reviewed",
            ):
                materializer.materialize_deployment_plan(
                    fixture.root,
                    fixture.root / SYNTHETIC_CANDIDATE,
                    receipt_validator=receipt_validator,
                )
            receipt_validator.assert_not_called()
        finally:
            fixture.close()

    def test_identity_drift_after_audit_fails_closed(self) -> None:
        fixture = SyntheticCandidate()
        try:
            def audit_then_mutate(*args: Any, **kwargs: Any) -> checker.CandidateAudit:
                audit = checker.audit_candidate(*args, **kwargs)
                fixture.candidate["candidate_id"] = "mutated-after-audit"
                write_json(fixture.root / SYNTHETIC_CANDIDATE, fixture.candidate)
                return audit

            with (
                mock.patch.object(
                    checker,
                    "require_complete_candidate",
                    side_effect=audit_then_mutate,
                ),
                self.assertRaisesRegex(
                    materializer.DeploymentPlanError,
                    "changed after completeness audit",
                ),
            ):
                materializer.validate_complete_v2_candidate(
                    fixture.root,
                    fixture.root / SYNTHETIC_CANDIDATE,
                )
        finally:
            fixture.close()

    def test_complete_candidate_identity_flows_through_plan_receipt_binding(
        self,
    ) -> None:
        fixture = SyntheticCandidate()
        try:
            receipt_validator = fixture.prepare_materialization()
            plan = materializer.materialize_deployment_plan(
                fixture.root,
                fixture.root / SYNTHETIC_CANDIDATE,
                receipt_validator=receipt_validator,
            )
            audit = fixture.audit()
            self.assertEqual(len(plan["deployments"]), 37)
            self.assertEqual(
                [item["expected_address"] for item in plan["deployments"]],
                [
                    executor.create_address(
                        SYNTHETIC_SENDER,
                        SYNTHETIC_STARTING_NONCE + index,
                    )
                    for index in range(37)
                ],
            )
            self.assertEqual(
                executor.require_v2_expected_create_addresses(
                    plan,
                    sender=SYNTHETIC_SENDER,
                    starting_nonce=SYNTHETIC_STARTING_NONCE,
                ),
                [item["expected_address"] for item in plan["deployments"]],
            )
            self.assertEqual(
                plan["candidate"]["candidate_identity_sha256"],
                audit.candidate_identity_sha256,
            )
            self.assertEqual(
                plan["candidate"]["candidate_identity_keccak256"],
                audit.candidate_identity_keccak256,
            )
            self.assertEqual(
                plan["release_posture"]["status"],
                "candidate_complete_tooling_only",
            )
            invalid_plan = copy.deepcopy(plan)
            invalid_plan["candidate"]["candidate_identity_sha256"] = None
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "canonical deployment plan does not satisfy",
            ):
                materializer.validate_draft_2020_12_schema(
                    fixture.root.resolve(),
                    materializer.PLAN_SCHEMA_PATH,
                    invalid_plan,
                    "canonical deployment plan",
                )
            missing_address_plan = copy.deepcopy(plan)
            del missing_address_plan["deployments"][0]["expected_address"]
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "expected_address.*required",
            ):
                materializer.validate_draft_2020_12_schema(
                    fixture.root.resolve(),
                    materializer.PLAN_SCHEMA_PATH,
                    missing_address_plan,
                    "canonical deployment plan",
                )
            binding = executor.execution_plan_binding(
                plan,
                plan_path="tmp/canonical-deployment-plan.json",
                plan_sha256=deterministic_sha(0xE1),
            )
            self.assertEqual(
                binding["candidate_identity_sha256"],
                audit.candidate_identity_sha256,
            )
            self.assertEqual(
                binding["candidate_identity_keccak256"],
                audit.candidate_identity_keccak256,
            )
            self.assertNotIn("candidate_sha256", binding)
        finally:
            fixture.close()

    def test_cross_namespace_address_collision_is_blocking(self) -> None:
        fixture = SyntheticCandidate()
        try:
            address = fixture.candidate["instances"][0]["address"]
            library = {
                "order": 1,
                "library_id": "fixture-library",
                "target": {
                    "kind": "production_contract",
                    "name": "FixtureLibrary",
                    "source": "smart-contracts/FixtureLibrary.sol",
                    "artifact_relative_path": "FixtureLibrary.sol/FixtureLibrary.json",
                    "artifact_sha256": deterministic_sha(0xEE),
                },
                "address": address,
                "depends_on": [],
                "constructor": {
                    "types": [],
                    "arguments": [],
                    "encoded_args_keccak256": deterministic_hash(0x10),
                },
                "linked_libraries": [],
                "runtime": {
                    "immutable_values": {},
                    "expected_keccak256": deterministic_hash(0x11),
                },
                "expected_linked_creation_keccak256": deterministic_hash(0x12),
                "expected_initcode_keccak256": deterministic_hash(0x13),
                "on_chain": {
                    "status": "observed",
                    "deployment_transaction": deterministic_hash(0x14),
                    "block_number": 1000,
                    "block_hash": deterministic_hash(0x15),
                    "initcode_keccak256": deterministic_hash(0x13),
                    "runtime_code_keccak256": deterministic_hash(0x11),
                    "source_verification_status": "verified",
                },
                "review_status": "reviewed",
            }
            fixture.candidate["linked_libraries"] = [library]
            fixture.candidate["instances"][0]["linked_libraries"] = [
                {
                    "library_id": library["library_id"],
                    "source": library["target"]["source"],
                    "name": library["target"]["name"],
                    "address": address,
                }
            ]
            fixture.bind_evidence()
            self.assertIn(
                "linked-library and candidate-instance addresses collide: "
                + address,
                fixture.audit().blockers,
            )
        finally:
            fixture.close()

    def test_complete_candidate_linked_creation_binding_is_consumed(self) -> None:
        fixture = SyntheticCandidate()
        try:
            receipt_validator = fixture.prepare_materialization()
            fixture.candidate["instances"][0][
                "expected_linked_creation_keccak256"
            ] = deterministic_hash(0xF1)
            fixture.bind_evidence()
            self.assertEqual(fixture.audit().blockers, ())
            with self.assertRaisesRegex(
                materializer.DeploymentPlanError,
                "linked creation bytecode hash does not match",
            ):
                materializer.materialize_deployment_plan(
                    fixture.root,
                    fixture.root / SYNTHETIC_CANDIDATE,
                    receipt_validator=receipt_validator,
                )
        finally:
            fixture.close()

    def test_negative_fixtures_fail_closed(self) -> None:
        fixture_document = materializer.load_json(REPO_ROOT / NEGATIVE_FIXTURES)
        self.assertEqual(
            fixture_document["schema_version"],
            "6529stream.canonical-deployment-candidate-v2-negative-fixtures.v1",
        )
        names: set[str] = set()
        for case in fixture_document["cases"]:
            with self.subTest(case=case["name"]):
                self.assertNotIn(case["name"], names)
                names.add(case["name"])
                fixture = SyntheticCandidate()
                try:
                    operations = copy.deepcopy(case["operations"])
                    raw_candidate_sha256 = materializer.file_sha256(
                        fixture.root / SYNTHETIC_CANDIDATE
                    )
                    for operation in operations:
                        if operation.get("value") == "$RAW_CANDIDATE_SHA256":
                            operation["value"] = raw_candidate_sha256
                    if case["target"] == "candidate":
                        apply_operations(fixture.candidate, operations)
                        fixture.bind_evidence()
                    elif case["target"] == "evidence":
                        apply_operations(fixture.evidence, operations)
                        fixture.bind_mutated_evidence()
                    else:
                        self.fail(f"unsupported fixture target: {case['target']}")

                    if "expected_error" in case:
                        with self.assertRaisesRegex(
                            checker.CandidateError,
                            case["expected_error"],
                        ):
                            fixture.audit()
                    else:
                        audit = fixture.audit()
                        self.assertIn(case["expected"], "\n".join(audit.blockers))
                finally:
                    fixture.close()
        self.assertEqual(len(names), 21)

    def test_schema_rejects_unknown_candidate_fields(self) -> None:
        fixture = SyntheticCandidate()
        try:
            fixture.candidate["parallel_genesis_identity"] = "forbidden"
            write_json(fixture.root / SYNTHETIC_CANDIDATE, fixture.candidate)
            with self.assertRaisesRegex(checker.CandidateError, "was unexpected"):
                fixture.audit()
        finally:
            fixture.close()

    def test_loader_rejects_duplicate_members_and_floats(self) -> None:
        fixture = SyntheticCandidate()
        try:
            candidate_path = fixture.root / SYNTHETIC_CANDIDATE
            candidate_path.write_text(
                '{"schema_version":"a","schema_version":"b"}\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(checker.CandidateError, "duplicate JSON"):
                fixture.audit()
            candidate_path.write_text(
                '{"schema_version":1.5}\n',
                encoding="utf-8",
            )
            with self.assertRaisesRegex(checker.CandidateError, "floating-point"):
                fixture.audit()
        finally:
            fixture.close()

    def test_risk_gov_003_remains_high_open_and_unaccepted(self) -> None:
        fixture = SyntheticCandidate()
        try:
            risk_path = fixture.root / checker.DEFAULT_RISK_REGISTER
            register = materializer.load_json(risk_path)
            risk = next(
                row
                for row in register["risks"]
                if row["id"] == checker.GOVERNANCE_RISK_ID
            )
            self.assertEqual(risk["severity"], "high")
            self.assertEqual(risk["status"], "open_blocker")
            self.assertIsNone(risk["risk_acceptance"])
            risk["status"] = "mitigated_local"
            write_json(risk_path, register)
            with self.assertRaisesRegex(
                checker.CandidateError,
                "RISK-GOV-003.status must remain 'open_blocker'",
            ):
                fixture.audit()
        finally:
            fixture.close()

    def test_v1_non_production_family_is_unchanged(self) -> None:
        v1_schema = materializer.load_json(
            REPO_ROOT / "deployments/schema/canonical-deployment-candidate.schema.json"
        )
        v2_schema = materializer.load_json(REPO_ROOT / checker.DEFAULT_SCHEMA)
        self.assertEqual(
            v1_schema["properties"]["schema_version"]["const"],
            "6529stream.canonical-deployment-candidate.v1",
        )
        self.assertEqual(
            v2_schema["properties"]["schema_version"]["const"],
            checker.CANDIDATE_SCHEMA_VERSION,
        )
        self.assertEqual(
            v1_schema["properties"]["candidate_kind"]["const"],
            "non_production_fixture",
        )


if __name__ == "__main__":
    unittest.main()
