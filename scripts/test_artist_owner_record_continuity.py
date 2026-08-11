#!/usr/bin/env python3
"""Hostile tests for the proposed dual owner-record continuity prerequisite."""

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
CHECKER_PATH = REPO_ROOT / "scripts/check_artist_owner_record_continuity.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("owner_record_continuity_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load owner record continuity checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()


class ArtistOwnerRecordContinuityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        copied = {
            CHECKER.PACKET_PATH,
            CHECKER.SCHEMA_PATH,
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
            json.dumps(value, indent=2) + "\n", encoding="utf-8"
        )

    def _packet(self) -> dict[str, Any]:
        return self._read(CHECKER.PACKET_PATH)

    def _write_packet(self, packet: dict[str, Any]) -> None:
        self._write(CHECKER.PACKET_PATH, packet)

    def _assert_rejected(self, expected: str) -> None:
        with self.assertRaisesRegex(CHECKER.ContinuityError, expected):
            CHECKER.check(self.root)

    def _refresh_packet_semantic_digest(self) -> str:
        packet = self._packet()
        payload = dict(packet)
        payload.pop("semantic_digest")
        digest = "sha256:" + CHECKER._canonical_sha(payload)
        packet["semantic_digest"] = digest
        self._write_packet(packet)
        return digest

    def _assert_rejected_after_semantic_rebind(self, expected: str) -> None:
        digest = self._refresh_packet_semantic_digest()
        original = CHECKER.SEMANTIC_DIGEST
        try:
            CHECKER.SEMANTIC_DIGEST = digest
            self._assert_rejected(expected)
        finally:
            CHECKER.SEMANTIC_DIGEST = original

    def _rebind_authority(self, authority_id: str) -> None:
        packet = self._packet()
        binding = next(
            row for row in packet["authority_bindings"] if row["id"] == authority_id
        )
        digest = hashlib.sha256((self.root / binding["path"]).read_bytes()).hexdigest()
        binding["sha256"] = digest
        self._write_packet(packet)
        CHECKER.EXPECTED_AUTHORITY_BINDINGS = tuple(
            (row_id, path, digest if row_id == authority_id else sha)
            for row_id, path, sha in CHECKER.EXPECTED_AUTHORITY_BINDINGS
        )

    def _with_rebound_authority(self, authority_id: str, expected: str) -> None:
        original_bindings = CHECKER.EXPECTED_AUTHORITY_BINDINGS
        original_semantic = CHECKER.SEMANTIC_DIGEST
        try:
            self._rebind_authority(authority_id)
            CHECKER.SEMANTIC_DIGEST = self._refresh_packet_semantic_digest()
            self._assert_rejected(expected)
        finally:
            CHECKER.EXPECTED_AUTHORITY_BINDINGS = original_bindings
            CHECKER.SEMANTIC_DIGEST = original_semantic

    def test_baseline_is_valid(self) -> None:
        CHECKER.check(self.root)

    def test_schema_is_draft_2020_12_and_packet_validates(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        packet = self._packet()
        Draft202012Validator.check_schema(schema)
        Draft202012Validator(schema).validate(packet)

    def test_schema_digest_is_independently_bound(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["title"] += " drift"
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected("schema digest drifted")

    def test_authority_digest_drift_is_rejected(self) -> None:
        path = self.root / CHECKER.FOUNDATION_PATH
        path.write_bytes(path.read_bytes() + b" ")
        self._assert_rejected("authority digest drifted: owner_state_foundation")

    def test_authority_path_escape_is_rejected(self) -> None:
        packet = self._packet()
        packet["authority_bindings"][0]["path"] = "../outside.md"
        self._write_packet(packet)
        self._assert_rejected("authority binding inventory drifted")

    def test_authority_symlink_is_rejected(self) -> None:
        packet = self._packet()
        binding = packet["authority_bindings"][0]
        path = self.root / binding["path"]
        replacement = self.root / "authority-copy.md"
        shutil.copy2(path, replacement)
        path.unlink()
        try:
            path.symlink_to(replacement)
        except OSError as exc:
            self.skipTest(f"symlink creation unavailable: {exc}")
        self._assert_rejected("authority path uses symlink")

    def test_record_domain_omission_survives_coordinated_repin(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        correction["record_domain_rows"].pop()
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority("record_event_correction", "record_domains count drifted")

    def test_created_record_reorder_survives_coordinated_repin(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        correction["operation_join_rows"][0]["record_bindings"].reverse()
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority(
            "record_event_correction", "created_records ordered inventory drifted"
        )

    def test_extra_created_record_survives_coordinated_repin(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        extra = copy.deepcopy(correction["operation_join_rows"][1]["record_bindings"][0])
        correction["operation_join_rows"][1]["record_bindings"].append(extra)
        correction["inventory"]["created_record_bindings"] = 41
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority(
            "record_event_correction", "record/event correction inventory drifted"
        )

    def test_two_record_batch_order_drift_is_rejected(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        op35 = next(row for row in correction["operation_join_rows"] if row["operation_id"] == 35)
        op35["record_bindings"].reverse()
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority(
            "record_event_correction", "matrix and correction owner record batches drifted"
        )

    def test_incomplete_reconstruction_is_rejected(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        correction["record_reconstruction_rows"][0]["reconstruction_complete"] = False
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority("record_event_correction", "record reconstruction row is incomplete")

    def test_implicit_current_state_join_is_rejected(self) -> None:
        correction = self._read(CHECKER.CORRECTION_PATH)
        correction["record_reconstruction_rows"][0]["implicit_storage_join"] = True
        self._write(CHECKER.CORRECTION_PATH, correction)
        self._with_rebound_authority("record_event_correction", "record reconstruction uses implicit storage")

    def test_foundation_record_transition_drift_is_rejected(self) -> None:
        foundation = self._read(CHECKER.FOUNDATION_PATH)
        foundation["transition_protocol"]["record_transition_fields"].reverse()
        self._write(CHECKER.FOUNDATION_PATH, foundation)
        self._with_rebound_authority("owner_state_foundation", "foundation record transition drifted")

    def test_opaque_coordinator_word_is_rejected(self) -> None:
        foundation = self._read(CHECKER.FOUNDATION_PATH)
        foundation["owner_side_recomputation"]["coordinator_supplied_commitment_words_allowed"] = True
        self._write(CHECKER.FOUNDATION_PATH, foundation)
        self._with_rebound_authority("owner_state_foundation", "foundation owner recomputation posture drifted")

    def test_shared_owner_storage_acceptance_is_rejected(self) -> None:
        shared = self._read(CHECKER.SHARED_PATH)
        row = next(row for row in shared["decision_rows"] if row["surface_id"] == "owner_storage")
        row["decision_status"] = "accepted"
        row["source_blocking"] = False
        self._write(CHECKER.SHARED_PATH, shared)
        self._with_rebound_authority("shared_mechanics", "shared accepted decision set drifted")

    def test_operation_source_authorization_is_rejected(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        matrix["operations"][0]["source_requirements"]["source_present"] = True
        self._write(CHECKER.MATRIX_PATH, matrix)
        self._with_rebound_authority("semantic_owner_matrix", "operation source or authorization drifted")

    def test_matrix_record_write_omission_survives_coordinated_repin(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        action = matrix["operations"][0]["coordinator_recipe"]["actions"][0]
        action["write_surfaces"] = [
            surface for surface in action["write_surfaces"] if not surface.startswith("record:")
        ]
        self._write(CHECKER.MATRIX_PATH, matrix)
        self._with_rebound_authority(
            "semantic_owner_matrix", "matrix and correction owner record batches drifted"
        )

    def test_matrix_two_record_order_survives_coordinated_repin(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        operation = next(row for row in matrix["operations"] if row["operation_id"] == 35)
        action = next(
            row
            for row in operation["coordinator_recipe"]["actions"]
            if row["owner_domain"] == "identity_authority"
        )
        record_indexes = [
            index
            for index, surface in enumerate(action["write_surfaces"])
            if surface.startswith("record:")
        ]
        left, right = record_indexes
        action["write_surfaces"][left], action["write_surfaces"][right] = (
            action["write_surfaces"][right],
            action["write_surfaces"][left],
        )
        self._write(CHECKER.MATRIX_PATH, matrix)
        self._with_rebound_authority(
            "semantic_owner_matrix", "matrix and correction owner record batches drifted"
        )

    def test_owner_domain_namespace_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["owner_domain_ids"][0]["storage_namespace"] = (
            "6529stream.artist.binding-lifecycle-alt.v2"
        )
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("owner domain identity rows drifted")

    def test_owner_domain_hash_coordinated_repin_is_rejected(self) -> None:
        packet = self._packet()
        row = packet["owner_domain_ids"][0]
        row["storage_namespace"] = "6529stream.artist.binding-lifecycle-alt.v2"
        row["domain_value"] = CHECKER._keccak_text(row["storage_namespace"])
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("owner domain identity rows drifted")

    def test_owner_record_domain_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["owner_record_commitment_protocol"]["domain"] += "_DRIFT"
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_owner_record_field_omission_is_rejected(self) -> None:
        packet = self._packet()
        packet["owner_record_commitment_protocol"]["ordered_fields"].pop()
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_owner_record_field_reorder_is_rejected(self) -> None:
        packet = self._packet()
        fields = packet["owner_record_commitment_protocol"]["ordered_fields"]
        fields[8], fields[9] = fields[9], fields[8]
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_owner_record_type_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["owner_record_commitment_protocol"]["ordered_fields"][8]["type"] = "uint256"
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_owner_revision_rule_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["owner_record_commitment_protocol"]["requirements"][
            "owner_revision_rule"
        ] = "caller_selected_revision"
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind(
            "owner record commitment protocol drifted"
        )

    def test_record_delta_field_reorder_is_rejected(self) -> None:
        packet = self._packet()
        fields = packet["record_delta_commitment_protocol"]["ordered_fields"]
        fields[13], fields[14] = fields[14], fields[13]
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_zero_record_absent_slot_rule_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["record_delta_commitment_protocol"]["requirements"][
            "absent_slot_rule"
        ] = "arbitrary_fixture_words"
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind(
            "record delta commitment protocol drifted"
        )

    def test_live_chainid_is_rejected(self) -> None:
        packet = self._packet()
        packet["semantic_record_protocol"]["live_block_chainid_allowed"] = True
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_packed_encoding_is_rejected(self) -> None:
        packet = self._packet()
        packet["record_delta_commitment_protocol"]["encoding"] = "abi.encodePacked"
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_receipt_overwrite_is_rejected(self) -> None:
        packet = self._packet()
        packet["logical_receipt_mapping"]["overwrite_allowed"] = True
        self._write_packet(packet)
        self._assert_rejected("schema validation failed")

    def test_archive_authority_is_rejected(self) -> None:
        packet = self._packet()
        packet["archive_boundary"]["archive_can_authorize_owner_state"] = True
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("Archive evidence boundary drifted")

    def test_archive_content_hash_in_commitment_is_rejected(self) -> None:
        packet = self._packet()
        packet["archive_boundary"]["archive_content_hash_pointer_or_block_in_owner_commitment"] = True
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("Archive evidence boundary drifted")

    def test_partial_success_is_rejected(self) -> None:
        packet = self._packet()
        packet["failure_and_rollback"]["partial_success_allowed"] = True
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("failure and rollback posture drifted")

    def test_record_sequence_overflow_rule_mutation_is_rejected(self) -> None:
        packet = self._packet()
        packet["failure_and_rollback"]["record_sequence_overflow"] = "wrap"
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("failure and rollback posture drifted")

    def test_successful_record_no_op_is_rejected(self) -> None:
        packet = self._packet()
        packet["failure_and_rollback"]["successful_record_no_op_allowed"] = True
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("failure and rollback posture drifted")

    def test_uint64_vector_boundary_is_checked(self) -> None:
        self.assertEqual(
            CHECKER._abi_word("uint64", (1 << 64) - 1),
            b"\x00" * 24 + ((1 << 64) - 1).to_bytes(8, "big"),
        )
        with self.assertRaisesRegex(CHECKER.ContinuityError, "uint64 vector value is out of range"):
            CHECKER._abi_word("uint64", 1 << 64)

    def test_source_or_readiness_promotion_is_rejected(self) -> None:
        for key in ("source_present", "implementation_authorized", "readiness_credit"):
            with self.subTest(key=key):
                packet = self._packet()
                packet["gate_state"][key] = True
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_root_cluster_acceptance_is_rejected(self) -> None:
        for key in ("owner_storage_accepted", "owner_snapshots_accepted", "replay_keys_accepted"):
            with self.subTest(key=key):
                packet = self._packet()
                packet["gate_state"][key] = True
                self._write_packet(packet)
                self._assert_rejected("schema validation failed")
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_record_vector_semantic_word_and_hash_coordinated_repin_is_rejected(self) -> None:
        packet = self._packet()
        fixture = packet["canonical_vectors"]["record_fixtures"][0]
        fixture["semantic_record_hash"] = "0x" + "cc" * 32
        identity = packet["canonical_vectors"]["fixture_identity"]
        values = {
            "domain_separator": CHECKER.OWNER_RECORD_DOMAIN_HASH,
            "schema_version": CHECKER.SCHEMA_VERSION,
            "deployment_chain_id": identity["deployment_chain_id"],
            "registry_address": identity["registry_address"],
            "coordinator_address": identity["coordinator_address"],
            "archive_v2_address": identity["archive_v2_address"],
            "owner_address": identity["owner_address"],
            "owner_domain_id": identity["owner_domain_id"],
            "owner_revision": identity["owner_revision"],
            "record_sequence": fixture["record_sequence"],
            "original_caller": identity["original_caller"],
            "record_domain": fixture["record_domain"],
            "semantic_record_hash": fixture["semantic_record_hash"],
        }
        fixture["expected_owner_record_commitment"] = CHECKER._abi_hash(
            CHECKER.OWNER_RECORD_FIELDS, values
        )
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("record vector fixture rows drifted")

    def test_record_vector_chain_tip_repin_is_rejected(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["record_fixtures"][0]["expected_record_chain_tip"] = "0x" + "dd" * 32
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("record vector fixture rows drifted")

    def test_zero_record_delta_hash_repin_is_rejected(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["record_delta_vectors"][0]["expected_record_delta_commitment"] = "0x" + "ee" * 32
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("record delta vector fixture rows drifted")

    def test_one_record_delta_count_drift_is_rejected(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["record_delta_vectors"][1]["record_count"] = 2
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("record delta vector fixture rows drifted")

    def test_two_record_delta_order_drift_is_rejected(self) -> None:
        packet = self._packet()
        packet["canonical_vectors"]["record_fixtures"].reverse()
        self._write_packet(packet)
        self._assert_rejected_after_semantic_rebind("record vector fixture rows drifted")

    def test_original_caller_alias_changes_commitment(self) -> None:
        packet = self._packet()
        identity = packet["canonical_vectors"]["fixture_identity"]
        fixture = packet["canonical_vectors"]["record_fixtures"][0]
        values = {
            "domain_separator": CHECKER.OWNER_RECORD_DOMAIN_HASH,
            "schema_version": CHECKER.SCHEMA_VERSION,
            "deployment_chain_id": identity["deployment_chain_id"],
            "registry_address": identity["registry_address"],
            "coordinator_address": identity["coordinator_address"],
            "archive_v2_address": identity["archive_v2_address"],
            "owner_address": identity["owner_address"],
            "owner_domain_id": identity["owner_domain_id"],
            "owner_revision": identity["owner_revision"],
            "record_sequence": fixture["record_sequence"],
            "original_caller": "0x6666666666666666666666666666666666666666",
            "record_domain": fixture["record_domain"],
            "semantic_record_hash": fixture["semantic_record_hash"],
        }
        self.assertNotEqual(
            CHECKER._abi_hash(CHECKER.OWNER_RECORD_FIELDS, values),
            fixture["expected_owner_record_commitment"],
        )

    def test_chain_and_owner_aliases_change_commitment(self) -> None:
        packet = self._packet()
        identity = packet["canonical_vectors"]["fixture_identity"]
        fixture = packet["canonical_vectors"]["record_fixtures"][0]
        base = {
            "domain_separator": CHECKER.OWNER_RECORD_DOMAIN_HASH,
            "schema_version": CHECKER.SCHEMA_VERSION,
            "deployment_chain_id": identity["deployment_chain_id"],
            "registry_address": identity["registry_address"],
            "coordinator_address": identity["coordinator_address"],
            "archive_v2_address": identity["archive_v2_address"],
            "owner_address": identity["owner_address"],
            "owner_domain_id": identity["owner_domain_id"],
            "owner_revision": identity["owner_revision"],
            "record_sequence": fixture["record_sequence"],
            "original_caller": identity["original_caller"],
            "record_domain": fixture["record_domain"],
            "semantic_record_hash": fixture["semantic_record_hash"],
        }
        for key, value in (
            ("deployment_chain_id", "2"),
            ("registry_address", "0x6666666666666666666666666666666666666666"),
            ("coordinator_address", "0x6666666666666666666666666666666666666666"),
            ("archive_v2_address", "0x6666666666666666666666666666666666666666"),
            ("owner_address", "0x6666666666666666666666666666666666666666"),
            ("owner_domain_id", "0x" + "66" * 32),
        ):
            with self.subTest(key=key):
                mutated = dict(base)
                mutated[key] = value
                self.assertNotEqual(
                    CHECKER._abi_hash(CHECKER.OWNER_RECORD_FIELDS, mutated),
                    fixture["expected_owner_record_commitment"],
                )

    def test_semantic_digest_is_independently_bound(self) -> None:
        packet = self._packet()
        packet["selected_shape"]["rationale"][0] += " drift"
        self._write_packet(packet)
        self._assert_rejected("packet semantic digest drifted")


if __name__ == "__main__":
    unittest.main(verbosity=2)
