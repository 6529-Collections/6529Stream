#!/usr/bin/env python3
"""Focused tests for the preparatory canonical deployment candidate v2."""

from __future__ import annotations

import copy
import hashlib
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from typing import Any

import check_canonical_deployment_candidate as checker
import materialize_canonical_deployment_plan as materializer


REPO_ROOT = Path(__file__).resolve().parent.parent
NEGATIVE_FIXTURES = Path(
    "test/fixtures/canonical-deployment-candidate-v2/negative-fixtures.json"
)
SYNTHETIC_CANDIDATE = Path("deployments/config/synthetic-candidate-v2.json")
SYNTHETIC_EVIDENCE = Path(
    "deployments/canonical-deployment-evidence/synthetic-candidate-v2.json"
)


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
            checker.DEFAULT_RISK_REGISTER,
        ):
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, target)
        self.profile = materializer.load_json(self.root / checker.DEFAULT_PROFILE)
        self.candidate = self._candidate()
        self.evidence: dict[str, Any] = {}
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
                "manifest_path": "release-artifacts/solidity-source-layout.json",
                "manifest_sha256": deterministic_sha(0x31),
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


class CandidateV2Tests(unittest.TestCase):
    def test_committed_planning_candidate_is_honest_and_incomplete(self) -> None:
        audit = checker.audit_candidate(REPO_ROOT)
        self.assertEqual(audit.profile_entry_count, 37)
        self.assertEqual(audit.instance_count, 0)
        self.assertIn("candidate status is planning", audit.blockers)
        self.assertIn("source layout remains pending issue #716", audit.blockers)
        self.assertIn("canonical retained evidence is not bound", audit.blockers)
        candidate = materializer.load_json(REPO_ROOT / checker.DEFAULT_CANDIDATE)
        self.assertFalse(candidate["production_candidate"])
        self.assertFalse(candidate["readiness_evidence"])
        self.assertIsNone(candidate["source_commit"])

    def test_committed_planning_identity_golden(self) -> None:
        audit = checker.audit_candidate(REPO_ROOT)
        self.assertEqual(
            audit.candidate_identity_sha256,
            "sha256:e07d83502d70090f80276a270f29f5d47b5087fb2517f1207e2d91fc927a37fe",
        )
        self.assertEqual(
            audit.candidate_identity_keccak256,
            "0xec2d74f7e290c3d36a8b16f6b96007a143968d22e197e7de8747668c26c50ea1",
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
        candidate["source_layout"]["status"] = "complete"
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
