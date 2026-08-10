#!/usr/bin/env python3
"""Hostile tests for the proposed owner-state mechanics foundation."""

from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import Any

from jsonschema import Draft202012Validator

REPO_ROOT = Path(__file__).resolve().parents[1]
CHECKER_PATH = REPO_ROOT / "scripts/check_artist_owner_state_mechanics_foundation.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("owner_state_foundation_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load owner-state mechanics foundation checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()


class ArtistOwnerStateMechanicsFoundationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        copied = {
            CHECKER.PACKET_PATH,
            CHECKER.SCHEMA_PATH,
            CHECKER.MATRIX_PATH,
            CHECKER.SHARED_PACKET_PATH,
            *(Path(path) for _, path, _ in CHECKER.EXPECTED_AUTHORITY_BINDINGS),
        }
        for relative in copied:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, destination)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _read(self, relative: Path) -> dict[str, Any]:
        return json.loads((self.root / relative).read_text(encoding="utf-8"))

    def _write(self, relative: Path, value: Any) -> None:
        (self.root / relative).write_text(
            json.dumps(value, indent=2) + "\n",
            encoding="utf-8",
        )

    def _packet(self) -> dict[str, Any]:
        return self._read(CHECKER.PACKET_PATH)

    def _write_packet(self, packet: dict[str, Any]) -> None:
        self._write(CHECKER.PACKET_PATH, packet)

    def _assert_rejected(self, expected: str) -> None:
        with self.assertRaisesRegex(CHECKER.FoundationError, expected):
            CHECKER.check(self.root)

    def _assert_rejected_after_schema_rebind(self, expected: str) -> None:
        schema_path = self.root / CHECKER.SCHEMA_PATH
        rebound = hashlib.sha256(schema_path.read_bytes()).hexdigest()
        original = CHECKER.SCHEMA_SHA256
        try:
            CHECKER.SCHEMA_SHA256 = rebound
            self._assert_rejected(expected)
        finally:
            CHECKER.SCHEMA_SHA256 = original

    def _rebind_authority(self, authority_id: str) -> None:
        packet = self._packet()
        binding = next(
            row for row in packet["authority_bindings"] if row["id"] == authority_id
        )
        target = self.root / binding["path"]
        digest = hashlib.sha256(target.read_bytes()).hexdigest()
        binding["sha256"] = digest
        self._write_packet(packet)
        CHECKER.EXPECTED_AUTHORITY_BINDINGS = tuple(
            (row_id, path, digest if row_id == authority_id else sha)
            for row_id, path, sha in CHECKER.EXPECTED_AUTHORITY_BINDINGS
        )

    def _mutate_matrix_coordinated(self, inventory: str, mode: str) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        rows = matrix[inventory]
        if mode == "missing":
            rows.pop()
        elif mode == "extra":
            rows.append(copy.deepcopy(rows[-1]))
            if inventory == "semantic_domains":
                rows[-1]["domain_id"] = "unexpected_domain"
            elif inventory == "replay_surfaces":
                rows[-1]["surface_id"] = "unexpected.replay.surface"
            else:
                raise AssertionError(inventory)
        elif mode == "reordered":
            rows[0], rows[1] = rows[1], rows[0]
        else:
            raise AssertionError(mode)
        self._write(CHECKER.MATRIX_PATH, matrix)

        packet = self._packet()
        key = "domain_layout_rows" if inventory == "semantic_domains" else "replay_surface_rows"
        if inventory == "semantic_domains":
            packet[key] = [
                {
                    "domain_id": row["domain_id"],
                    "owner_contract": row["owner"],
                    "storage_namespace": row["storage_namespace"],
                    "coordinator_snapshot_order": row["coordinator_snapshot_order"],
                    "participating_operation_count": len(row["participating_operation_ids"]),
                    "decision_status": "unresolved",
                    "selected_domain_struct": None,
                    "selected_domain_state_commitment": None,
                    "source_blocking": True,
                }
                for row in rows
            ]
        else:
            packet[key] = [
                {
                    "surface_id": row["surface_id"],
                    "owner_domain": row["owner_domain"],
                    "owner_contract": row["owner_contract"],
                    "decision_status": "unresolved",
                    "replay_kind": None,
                    "replay_status_lifecycle": None,
                    "scope_commitment_schema": None,
                    "source_blocking": True,
                }
                for row in rows
            ]
        packet["inventory_bindings"][inventory] = {
            "count": len(rows),
            "canonical_sha256": CHECKER._canonical_digest(rows),
        }
        matrix_digest = hashlib.sha256(
            (self.root / CHECKER.MATRIX_PATH).read_bytes()
        ).hexdigest()
        binding = next(
            row
            for row in packet["authority_bindings"]
            if row["id"] == "semantic_owner_matrix"
        )
        binding["sha256"] = matrix_digest
        self._write_packet(packet)

        original = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        try:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = tuple(
                (row_id, path, matrix_digest if row_id == "semantic_owner_matrix" else sha)
                for row_id, path, sha in original
            )
            expected = (
                f"matrix {inventory} inventory drifted"
                if mode == "reordered"
                else "schema violation"
            )
            self._assert_rejected(expected)
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original

    def test_baseline_is_exact(self) -> None:
        self.assertEqual(
            CHECKER.check(self.root),
            {
                "authority_bindings": 14,
                "semantic_domains": 7,
                "replay_surfaces": 64,
                "operations": 57,
                "record_surfaces": 37,
                "event_surfaces": 54,
                "accepted_domain_layouts": 0,
                "accepted_replay_surfaces": 0,
            },
        )

    def test_schema_is_valid_draft_2020_12(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        Draft202012Validator.check_schema(schema)

    def test_authority_bytes_cannot_drift(self) -> None:
        target = self.root / Path(CHECKER.EXPECTED_AUTHORITY_BINDINGS[0][1])
        target.write_text(target.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        self._assert_rejected("authority adr_0023 sha256 drifted")

    def test_authority_path_cannot_traverse(self) -> None:
        packet = self._packet()
        packet["authority_bindings"][0]["path"] = "../outside.md"
        self._write_packet(packet)
        self._assert_rejected("authority binding inventory or order drifted")

    def test_duplicate_json_member_is_rejected(self) -> None:
        path = self.root / CHECKER.PACKET_PATH
        text = path.read_text(encoding="utf-8")
        path.write_text(text.replace('  "status":', '  "schema": "duplicate",\n  "status":', 1), encoding="utf-8")
        self._assert_rejected("duplicate JSON member")

    def test_domain_inventory_missing_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("semantic_domains", "missing")

    def test_domain_inventory_extra_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("semantic_domains", "extra")

    def test_domain_inventory_reorder_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("semantic_domains", "reordered")

    def test_replay_inventory_missing_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("replay_surfaces", "missing")

    def test_replay_inventory_extra_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("replay_surfaces", "extra")

    def test_replay_inventory_reorder_is_rejected_after_coordinated_repin(self) -> None:
        self._mutate_matrix_coordinated("replay_surfaces", "reordered")

    def test_unresolved_domain_cannot_be_accepted(self) -> None:
        packet = self._packet()
        packet["domain_layout_rows"][0]["decision_status"] = "accepted"
        packet["domain_layout_rows"][0]["selected_domain_struct"] = "bytes32 opaque"
        packet["domain_layout_rows"][0]["source_blocking"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_unresolved_replay_cannot_be_accepted(self) -> None:
        packet = self._packet()
        packet["replay_surface_rows"][0]["decision_status"] = "accepted"
        packet["replay_surface_rows"][0]["replay_kind"] = "ONE_SHOT"
        packet["replay_surface_rows"][0]["scope_commitment_schema"] = "opaque"
        packet["replay_surface_rows"][0]["source_blocking"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_domain_struct_assignment_remains_null(self) -> None:
        packet = self._packet()
        packet["domain_layout_rows"][0]["selected_domain_struct"] = "mapping(bytes32 => bytes32)"
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_scope_commitment_assignment_remains_null(self) -> None:
        packet = self._packet()
        packet["replay_key_protocol"]["scope_commitment_schema"] = "abi.encode(subject)"
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["replay_key_protocol"]["properties"][
            "scope_commitment_schema"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "outer replay-key protocol or unresolved scope drifted"
        )

    def test_replay_enum_is_capability_only(self) -> None:
        packet = self._packet()
        packet["replay_cell"]["per_surface_assignment_frozen"] = True
        self._write_packet(packet)
        self._assert_rejected("replay capability was presented as a surface assignment")

    def test_opaque_coordinator_runtime_commitment_is_rejected(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["runtime_codehash_commitment"] = "0x" + "11" * 32
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["snapshot_protocol"]["properties"][
            "runtime_codehash_commitment"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "opaque Coordinator runtime commitment is forbidden"
        )

    def test_snapshot_commitment_domain_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["commitment_domain"] = "MUTATED_SNAPSHOT_DOMAIN"
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["snapshot_protocol"]["properties"][
            "commitment_domain"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "snapshot commitment domain drifted"
        )

    def test_snapshot_failure_semantics_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["failure_semantics"] = "return_zero_tuple"
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["snapshot_protocol"]["properties"][
            "failure_semantics"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "snapshot failure semantics drifted"
        )

    def test_state_transition_domain_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["state_transition_domain"] = (
            "MUTATED_STATE_TRANSITION_DOMAIN"
        )
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["transition_protocol"]["properties"][
            "state_transition_domain"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "state transition domain drifted"
        )

    def test_record_transition_domain_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["record_transition_domain"] = (
            "MUTATED_RECORD_TRANSITION_DOMAIN"
        )
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["transition_protocol"]["properties"][
            "record_transition_domain"
        ] = {"type": "string"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "record transition domain drifted"
        )

    def test_coordinator_supplied_opaque_commitments_are_rejected(self) -> None:
        packet = self._packet()
        packet["owner_side_recomputation"]["compute_location"] = (
            "coordinator_supplied_opaque_words"
        )
        packet["owner_side_recomputation"][
            "coordinator_supplied_commitment_words_allowed"
        ] = True
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["owner_side_recomputation"]["properties"][
            "coordinator_supplied_commitment_words_allowed"
        ] = {"type": "boolean"}
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind(
            "typed owner-side commitment recomputation invariant drifted"
        )

    def test_inner_commitment_preimages_remain_null(self) -> None:
        packet = self._packet()
        packet["owner_side_recomputation"]["action_commitment_preimage"] = (
            "coordinator_supplied_bytes32"
        )
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_packed_snapshot_encoding_is_rejected(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["commitment_encoding"] = "abi.encodePacked"
        self._write_packet(packet)
        self._assert_rejected("snapshot commitment must use abi.encode")

    def test_packed_transition_encoding_is_rejected(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["state_transition_encoding"] = "abi.encodePacked"
        self._write_packet(packet)
        self._assert_rejected("packed transition encoding is forbidden")

    def test_packed_replay_key_encoding_is_rejected(self) -> None:
        packet = self._packet()
        packet["replay_key_protocol"]["encoding"] = "abi.encodePacked"
        self._write_packet(packet)
        self._assert_rejected("outer replay-key protocol or unresolved scope drifted")

    def test_replay_delete_cannot_be_enabled(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["replay_delete_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected("transition prohibition drifted: replay_delete_forbidden")

    def test_replay_reopen_cannot_be_enabled(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["replay_reopen_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected("transition prohibition drifted: replay_reopen_forbidden")

    def test_root_rewind_cannot_be_enabled(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["root_rewind_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected("transition prohibition drifted: root_rewind_forbidden")

    def test_record_chain_tip_rewind_cannot_be_enabled(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["record_chain_tip_rewind_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected(
            "transition prohibition drifted: record_chain_tip_rewind_forbidden"
        )

    def test_successful_no_op_cannot_be_enabled(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["no_op_success_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected("transition prohibition drifted: no_op_success_forbidden")

    def test_constructor_cycle_claim_is_rejected(self) -> None:
        packet = self._packet()
        row = next(
            item for item in packet["unresolved_dependencies"]
            if item["id"] == "construction_binding_preimage"
        )
        row["value"] = "coordinator_runtime_hash_commits_owner_runtime_hash"
        row["source_blocking"] = False
        packet["gate_state"]["construction_binding_resolved"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_premature_owner_storage_acceptance_is_rejected(self) -> None:
        packet = self._packet()
        packet["gate_state"]["owner_storage_accepted"] = True
        self._write_packet(packet)
        self._assert_rejected("premature acceptance")

    def test_premature_source_authorization_is_rejected(self) -> None:
        packet = self._packet()
        packet["gate_state"]["implementation_authorized"] = True
        packet["gate_state"]["source_present"] = True
        self._write_packet(packet)
        self._assert_rejected("premature acceptance")

    def test_premature_interface_freeze_is_rejected(self) -> None:
        packet = self._packet()
        packet["gate_state"]["interface_freeze_complete"] = True
        self._write_packet(packet)
        self._assert_rejected("premature acceptance")

    def test_external_owner_calls_are_rejected(self) -> None:
        packet = self._packet()
        packet["constant_work_bounds"]["external_calls_from_owner"] = True
        self._write_packet(packet)
        self._assert_rejected("packet constant-work bounds drifted")

    def test_storage_gap_is_rejected(self) -> None:
        packet = self._packet()
        packet["common_storage_layout"]["storage_gap_slots"] = 50
        self._write_packet(packet)
        self._assert_rejected("upgrade, gap, or generic storage was introduced")

    def test_owner_mutation_authority_is_immutable_coordinator_only(self) -> None:
        packet = self._packet()
        packet["common_storage_layout"]["mutation_authority"] = "registry_or_coordinator"
        self._write_packet(packet)
        self._assert_rejected("owner mutation authority drifted")

    def test_live_block_chainid_source_is_rejected(self) -> None:
        packet = self._packet()
        packet["common_storage_layout"]["deployment_chain_id_source"] = (
            "live_block_chainid"
        )
        packet["common_storage_layout"]["live_block_chainid_forbidden"] = False
        self._write_packet(packet)
        self._assert_rejected("deploymentChainId source drifted")

    def test_archive_identity_cannot_be_omitted_from_snapshot_envelope(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["commitment_fields"].remove(
            "archive_v2_address"
        )
        self._write_packet(packet)
        self._assert_rejected("schema violation")

    def test_checked_counter_overflow_reverts(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["overflow_behavior"] = "wrap"
        self._write_packet(packet)
        self._assert_rejected("checked counter overflow behavior drifted")

    def test_unknown_nested_mechanics_field_is_rejected(self) -> None:
        packet = self._packet()
        packet["common_storage_layout"]["delegatecall"] = True
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["common_storage_layout"]["additionalProperties"] = True
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind("common storage fields drifted")

    def test_checked_revision_increment_is_exact(self) -> None:
        packet = self._packet()
        packet["transition_protocol"]["checked_revision_increment"] = 2
        self._write_packet(packet)
        self._assert_rejected("checked revision increment drifted")

    def test_snapshot_has_exactly_four_fields(self) -> None:
        packet = self._packet()
        packet["snapshot_protocol"]["return_fields"].append(
            {"position": 4, "name": "latestRecord", "type": "bytes32"}
        )
        self._write_packet(packet)
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["properties"]["snapshot_protocol"]["properties"][
            "return_fields"
        ]["maxItems"] = 5
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected_after_schema_rebind("four-field snapshot ABI drifted")

    def test_all_canonical_vectors_are_independently_recomputed(self) -> None:
        vector_ids = (
            "replay_key",
            "snapshot_commitment",
            "genesis_state_root",
            "genesis_record_chain_tip",
            "state_transition",
            "record_transition",
        )
        for vector_id in vector_ids:
            with self.subTest(vector_id=vector_id):
                packet = self._packet()
                packet["canonical_vectors"]["vectors"][vector_id][
                    "expected_commitment"
                ] = "0x" + "00" * 32
                self._write_packet(packet)
                self._assert_rejected(f"{vector_id} vector commitment drifted")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_vector_domain_must_match_protocol_domain(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["vectors"]["snapshot_commitment"][
            "domain"
        ] = "MUTATED_SNAPSHOT_DOMAIN"
        self._write_packet(packet)
        self._assert_rejected(
            "snapshot_commitment vector-to-protocol domain drifted"
        )

    def test_fork_rekey_cannot_change_deployment_chain_identity(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["fixture_identity"][
            "deployment_chain_id"
        ] = "31337"
        self._write_packet(packet)
        self._assert_rejected("vector immutable identity fixture drifted")

    def test_matrix_bound_change_is_rejected_after_authority_repin(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        matrix["operations"][0]["coordinator_recipe"]["actions"].append(
            copy.deepcopy(matrix["operations"][0]["coordinator_recipe"]["actions"][-1])
        )
        self._write(CHECKER.MATRIX_PATH, matrix)
        original = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        try:
            self._rebind_authority("semantic_owner_matrix")
            self._assert_rejected("matrix operations inventory drifted")
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original

    def test_matrix_derived_maximum_action_bound_is_exact(self) -> None:
        packet = self._packet()
        packet["constant_work_bounds"]["maximum_owner_actions_per_operation"] = 6
        self._write_packet(packet)
        self._assert_rejected("packet constant-work bounds drifted")

    def test_shared_packet_must_remain_byte_exact(self) -> None:
        shared = self._read(CHECKER.SHARED_PACKET_PATH)
        shared["gate_state"]["accepted_decision_count"] = 4
        self._write(CHECKER.SHARED_PACKET_PATH, shared)
        self._assert_rejected("authority shared_mechanics_packet sha256 drifted")

    def test_operation_source_authorization_remains_false(self) -> None:
        shared = self._read(CHECKER.SHARED_PACKET_PATH)
        shared["operation_projection"]["source_present"] = True
        self._write(CHECKER.SHARED_PACKET_PATH, shared)
        digest = hashlib.sha256(
            (self.root / CHECKER.SHARED_PACKET_PATH).read_bytes()
        ).hexdigest()
        packet = self._packet()
        binding = next(
            row for row in packet["authority_bindings"]
            if row["id"] == "shared_mechanics_packet"
        )
        binding["sha256"] = digest
        self._write_packet(packet)
        original = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        try:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = tuple(
                (row_id, path, digest if row_id == "shared_mechanics_packet" else sha)
                for row_id, path, sha in original
            )
            self._assert_rejected("shared-mechanics operation source/auth drifted")
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original


if __name__ == "__main__":
    unittest.main()
