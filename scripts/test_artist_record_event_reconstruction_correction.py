#!/usr/bin/env python3
"""Hostile tests for the artist record/event reconstruction correction."""

from __future__ import annotations

import base64
import hashlib
import json
import tempfile
import unittest
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch

from jsonschema import Draft202012Validator

import check_artist_record_event_reconstruction_correction as checker


ROOT = Path(__file__).resolve().parents[1]


class ArtistRecordEventReconstructionCorrectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.packet = checker.load_json(ROOT / checker.PACKET_PATH)
        cls.schema = checker.load_json(ROOT / checker.SCHEMA_PATH)
        cls.archive = checker.load_json(ROOT / checker.HISTORICAL_ARCHIVE_PATH)
        cls.wanted_events = {
            row["event"]
            for row in checker.load_json(ROOT / checker.MATRIX_PATH)["event_surfaces"]
        }

    def copy_packet(self) -> dict:
        return deepcopy(self.packet)

    def rebind(self, packet: dict) -> None:
        packet["semantic_digest"] = "sha256:" + hashlib.sha256(
            json.dumps(
                {key: value for key, value in packet.items() if key != "semantic_digest"},
                separators=(",", ":"),
                sort_keys=True,
            ).encode()
        ).hexdigest()

    def assert_rejected(self, packet: dict, expected: str, *, rebind: bool = True) -> None:
        if rebind:
            self.rebind(packet)
        with self.assertRaisesRegex(checker.CorrectionError, expected):
            checker.check(ROOT, packet)

    def write_archive(self, root: Path, archive: dict) -> tuple[Path, str]:
        path = root / checker.HISTORICAL_ARCHIVE_PATH
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(archive, indent=2) + "\n", encoding="utf-8")
        return path, hashlib.sha256(path.read_bytes()).hexdigest()

    def assert_archive_rejected(
        self,
        archive: dict,
        expected: str,
        *,
        packet_mutator=None,
        expected_snapshots=None,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            _path, archive_sha = self.write_archive(temp_root, archive)
            packet = self.copy_packet()
            packet["historical_git_object_archive"]["raw_sha256"] = archive_sha
            next(
                row
                for row in packet["authority_bindings"]
                if row["id"] == "historical_git_object_archive"
            )["sha256"] = archive_sha
            if packet_mutator is not None:
                packet_mutator(packet, archive)
            self.rebind(packet)
            snapshots = (
                checker.EXPECTED_HISTORICAL_SNAPSHOTS
                if expected_snapshots is None
                else expected_snapshots
            )
            with (
                patch.object(
                    checker, "EXPECTED_HISTORICAL_ARCHIVE_SHA256", archive_sha
                ),
                patch.object(checker, "EXPECTED_HISTORICAL_SNAPSHOTS", snapshots),
            ):
                with self.assertRaisesRegex(checker.CorrectionError, expected):
                    checker._validate_historical_archive(
                        temp_root, packet, self.wanted_events
                    )

    def object_row(self, archive: dict, group: str, oid: str) -> dict:
        return next(row for row in archive[group] if row["oid"] == oid)

    def repin_object(self, row: dict, object_type: str, raw: bytes) -> str:
        oid = hashlib.sha1(
            f"{object_type} {len(raw)}\0".encode("ascii") + raw,
            usedforsecurity=False,
        ).hexdigest()
        row.update(
            {
                "oid": oid,
                "size_bytes": len(raw),
                "data_base64": base64.b64encode(raw).decode("ascii"),
            }
        )
        return oid

    def replace_tree_entry(
        self,
        raw: bytes,
        *,
        mode: str,
        name: str,
        old_oid: str,
        new_oid: str | None = None,
        new_mode: str | None = None,
    ) -> bytes:
        marker = f"{mode} {name}\0".encode("utf-8") + bytes.fromhex(old_oid)
        replacement = (
            f"{new_mode or mode} {name}\0".encode("utf-8")
            + bytes.fromhex(new_oid or old_oid)
        )
        self.assertEqual(1, raw.count(marker))
        return raw.replace(marker, replacement, 1)

    def assert_upstream_rejected(self, foundation: dict, expected: str) -> None:
        shared = checker.load_json(ROOT / checker.SHARED_PATH)
        matrix = checker.load_json(ROOT / checker.MATRIX_PATH)
        with patch.object(checker, "load_json", side_effect=[foundation, shared, matrix]):
            with self.assertRaisesRegex(checker.CorrectionError, expected):
                checker._validate_upstream_posture(ROOT)

    def event(self, packet: dict, name: str) -> dict:
        return next(row for row in packet["event_surface_rows"] if row["event"] == name)

    def vector(self, packet: dict, surface_id: str) -> dict:
        return next(
            row for row in packet["canonical_event_vectors"] if row["surface_id"] == surface_id
        )

    def record_map(self, packet: dict, operation_id: int, record_domain: str) -> dict:
        return next(
            row
            for row in packet["record_reconstruction_rows"]
            if row["operation_id"] == operation_id and row["record_domain"] == record_domain
        )

    def record_vector(self, packet: dict, vector_id: str) -> dict:
        return next(
            row for row in packet["canonical_record_vectors"] if row["vector_id"] == vector_id
        )

    def test_baseline_packet_passes(self) -> None:
        checker.check(ROOT)

    def test_aggregate_local_and_ci_wiring_is_exact(self) -> None:
        shell_wrapper = (ROOT / "scripts" / "check.sh").read_text(encoding="utf-8")
        powershell_wrapper = (ROOT / "scripts" / "check.ps1").read_text(
            encoding="utf-8"
        )
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        ci_workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(
            encoding="utf-8"
        )
        release_mode = (
            ROOT / ".github" / "workflows" / "release-mode.yml"
        ).read_text(encoding="utf-8")

        shell_test = (
            '"$python_bin" scripts/test_artist_record_event_reconstruction_correction.py'
        )
        shell_check = (
            '"$python_bin" scripts/check_artist_record_event_reconstruction_correction.py'
        )
        powershell_test = (
            '& $pythonPath @pythonArgs '
            '"scripts\\test_artist_record_event_reconstruction_correction.py"'
        )
        powershell_check = (
            '& $pythonPath @pythonArgs '
            '"scripts\\check_artist_record_event_reconstruction_correction.py"'
        )
        for wrapper, test_command, check_command in (
            (shell_wrapper, shell_test, shell_check),
            (powershell_wrapper, powershell_test, powershell_check),
        ):
            self.assertEqual(1, wrapper.count(test_command))
            self.assertEqual(1, wrapper.count(check_command))
            self.assertLess(wrapper.index(test_command), wrapper.index(check_command))

        make_target = (
            "artist-record-event-reconstruction-correction-check:\n"
            "\t$(PYTHON) scripts/test_artist_record_event_reconstruction_correction.py\n"
            "\t$(PYTHON) scripts/check_artist_record_event_reconstruction_correction.py\n"
        )
        self.assertEqual(1, makefile.count(make_target))
        self.assertIn(
            ".PHONY: record-family-authorization-check "
            "artist-semantic-owner-matrix-check "
            "artist-record-event-reconstruction-correction-check",
            makefile,
        )
        self.assertIn(
            "check: record-family-authorization-check "
            "artist-semantic-owner-matrix-check "
            "artist-record-event-reconstruction-correction-check",
            makefile,
        )

        ci_gate = (
            "      - name: Artist record/event reconstruction correction gate\n"
            "        shell: bash\n"
            "        run: |\n"
            "          set -o pipefail\n"
            "          mkdir -p ci-logs\n"
            "          python3 scripts/test_artist_record_event_reconstruction_correction.py "
            "2>&1 | tee ci-logs/artist-record-event-reconstruction-correction-tests.log\n"
            "          python3 scripts/check_artist_record_event_reconstruction_correction.py "
            "2>&1 | tee ci-logs/artist-record-event-reconstruction-correction-check.log\n"
        )
        self.assertEqual(1, ci_workflow.count(ci_gate))
        self.assertIn("fetch-depth: 0", release_mode)
        self.assertEqual(1, release_mode.count("bash scripts/check.sh"))

    def test_schema_is_draft_2020_12_valid(self) -> None:
        Draft202012Validator.check_schema(self.schema)
        self.assertEqual([], list(Draft202012Validator(self.schema).iter_errors(self.packet)))

    def test_historical_compatibility_schema_rejects_unknown_property(self) -> None:
        packet = self.copy_packet()
        packet["historical_compatibility"][0]["unexpected"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_correction_rule_schema_rejects_unknown_property(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][0]["unexpected"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_semantic_digest_is_independent(self) -> None:
        packet = self.copy_packet()
        packet["semantic_digest"] = "sha256:" + "00" * 32
        self.assert_rejected(packet, "semantic digest drifted", rebind=False)

    def test_authority_binding_digest_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["authority_bindings"][0]["sha256"] = "0" * 64
        self.assert_rejected(packet, "authority bindings drifted")

    def test_evaluated_base_commit_and_tree_drift_are_rejected(self) -> None:
        for field in ("commit", "tree"):
            with self.subTest(field=field):
                packet = self.copy_packet()
                packet["evaluated_base"][field] = "0" * 40
                self.rebind(packet)
                with patch.object(checker, "_validate_schema", return_value=None):
                    with self.assertRaisesRegex(
                        checker.CorrectionError, "evaluated-base receipt drifted"
                    ):
                        checker.check(ROOT, packet)

    def test_resolved_owner_layout_is_rejected_by_upstream_posture(self) -> None:
        foundation = checker.load_json(ROOT / checker.FOUNDATION_PATH)
        foundation["domain_layout_rows"][0]["decision_status"] = "accepted"
        self.assert_upstream_rejected(
            foundation, "seven owner layout rows no longer remain unresolved"
        )

    def test_resolved_replay_surface_is_rejected_by_upstream_posture(self) -> None:
        foundation = checker.load_json(ROOT / checker.FOUNDATION_PATH)
        foundation["replay_surface_rows"][0]["decision_status"] = "accepted"
        self.assert_upstream_rejected(
            foundation, "64 replay rows no longer remain unresolved"
        )

    def test_resolved_inner_preimage_is_rejected_by_upstream_posture(self) -> None:
        foundation = checker.load_json(ROOT / checker.FOUNDATION_PATH)
        foundation["owner_side_recomputation"]["action_commitment_preimage"] = (
            "opaque coordinator word"
        )
        self.assert_upstream_rejected(
            foundation, "four owner inner preimages no longer remain null"
        )

    def test_record_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_domain_rows"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_record_same_cardinality_replacement_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_domain_rows"][0] = deepcopy(packet["record_domain_rows"][1])
        self.assert_rejected(packet, "37 ordered record-domain rows drifted")

    def test_record_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_domain_rows"][0], packet["record_domain_rows"][1] = (
            packet["record_domain_rows"][1],
            packet["record_domain_rows"][0],
        )
        self.assert_rejected(packet, "37 ordered record-domain rows drifted")

    def test_record_domain_preimage_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_domain_rows"][0]["domain_preimage"] += "_DRIFT"
        self.assert_rejected(packet, "37 ordered record-domain rows drifted")

    def test_record_hash_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_domain_rows"][0]["domain_value"] = "0x" + "11" * 32
        self.assert_rejected(packet, "37 ordered record-domain rows drifted")

    def test_record_preimage_field_order_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        row = next(
            item
            for item in packet["record_domain_rows"]
            if item["record_domain"] == "BINDING_REFUSAL_RECORD_DOMAIN"
        )
        row["legacy_preimage"] = row["legacy_preimage"].replace(
            "bindingHash,artistId", "artistId,bindingHash"
        )
        self.assert_rejected(packet, "37 ordered record-domain rows drifted")

    def test_packed_record_encoding_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_protocol"]["abi_encode_packed_allowed"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_event_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["event_surface_rows"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_event_same_cardinality_replacement_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["event_surface_rows"][0] = deepcopy(packet["event_surface_rows"][1])
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["event_surface_rows"][0], packet["event_surface_rows"][1] = (
            packet["event_surface_rows"][1],
            packet["event_surface_rows"][0],
        )
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_field_type_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistDelegationRevoked")["fields"][-1]["type"] = "uint256"
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_field_name_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistHistoryLaneVerified")["fields"][-1]["name"] = "chainHash"
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_indexing_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistIdentityRecovered")["fields"][1]["indexed"] = False
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_topic_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistDelegationRevoked")["v2_topic0"] = "0x" + "11" * 32
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_signature_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistIdentityRecovered")["v2_signature"] += "DRIFT"
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_corrected_suffix_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistAttributionStateChanged")["fields"].pop()
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_corrected_suffix_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        fields = self.event(packet, "ArtistDelegationRevoked")["fields"]
        fields[-1], fields[-2] = fields[-2], fields[-1]
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_legacy_prefix_change_on_corrected_event_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.event(packet, "ArtistHistoryLaneVerified")["fields"][1]["type"] = "bytes32"
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_generic_event_substitution_is_rejected(self) -> None:
        packet = self.copy_packet()
        row = self.event(packet, "ArtistDelegationRevoked")
        row["event"] = "ArtistOperationCommitted"
        row["surface_id"] = "event:ArtistOperationCommitted"
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_event_vector_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_event_vectors"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_event_vector_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_event_vectors"][0], packet["canonical_event_vectors"][1] = (
            packet["canonical_event_vectors"][1],
            packet["canonical_event_vectors"][0],
        )
        self.assert_rejected(packet, "54 canonical event vectors drifted")

    def test_event_vector_topic_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_event_vectors"][0]["topic0"] = "0x" + "22" * 32
        self.assert_rejected(packet, "54 canonical event vectors drifted")

    def test_event_vector_index_positions_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_event_vectors"][0]["indexed_positions"] = []
        self.assert_rejected(packet, "54 canonical event vectors drifted")

    def test_operation_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_operation_same_cardinality_replacement_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][0] = deepcopy(packet["operation_join_rows"][1])
        self.assert_rejected(packet, "57 ordered operation joins drifted")

    def test_operation_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][0], packet["operation_join_rows"][1] = (
            packet["operation_join_rows"][1],
            packet["operation_join_rows"][0],
        )
        self.assert_rejected(packet, "57 ordered operation joins drifted")

    def test_cross_record_substitution_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][2]["record_bindings"] = deepcopy(
            packet["operation_join_rows"][26]["record_bindings"]
        )
        self.assert_rejected(packet, "57 ordered operation joins drifted")

    def test_cross_event_substitution_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][2]["event_bindings"] = deepcopy(
            packet["operation_join_rows"][26]["event_bindings"]
        )
        self.assert_rejected(packet, "57 ordered operation joins drifted")

    def test_operation_source_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][0]["source_present"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_operation_authorization_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["operation_join_rows"][0]["implementation_authorized"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_correction_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_correction_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][0], packet["correction_rules"][1] = (
            packet["correction_rules"][1],
            packet["correction_rules"][0],
        )
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_correction_cross_event_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][0]["event"] = "ArtistDelegationRevoked"
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_correction_suffix_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][1]["required_suffix"].pop()
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_binding_zero_suffix_rule_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][0]["other_operation_suffix_rule"] = "optional"
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_binding_signer_cannot_alias_actor(self) -> None:
        packet = self.copy_packet()
        row = self.record_map(packet, 3, "BINDING_REFUSAL_RECORD_DOMAIN")
        binding = next(item for item in row["component_bindings"] if item["component"] == "signer")
        binding["source"] = "event:ArtistAttributionStateChanged.actor"
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_binding_record_signer_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        fields = self.event(packet, "ArtistAttributionStateChanged")["fields"]
        fields[:] = [field for field in fields if field["name"] != "recordSigner"]
        self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_record_mapping_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        self.record_map(packet, 27, "DELEGATION_REVOCATION_RECORD_DOMAIN")[
            "component_bindings"
        ].pop()
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_complete_mapping_cardinality_and_domain_coverage(self) -> None:
        rows = self.packet["record_reconstruction_rows"]
        self.assertEqual(40, len(rows))
        self.assertEqual(430, sum(len(row["component_bindings"]) for row in rows))
        self.assertEqual(
            {row["record_domain"] for row in self.packet["record_domain_rows"]},
            {row["record_domain"] for row in rows},
        )

    def test_record_mapping_row_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        rows = packet["record_reconstruction_rows"]
        rows[0], rows[1] = rows[1], rows[0]
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_record_mapping_same_cardinality_replacement_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_reconstruction_rows"][0] = deepcopy(
            packet["record_reconstruction_rows"][1]
        )
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_record_component_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        bindings = packet["record_reconstruction_rows"][0]["component_bindings"]
        bindings[3], bindings[4] = bindings[4], bindings[3]
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_record_component_cannot_use_implicit_storage(self) -> None:
        packet = self.copy_packet()
        row = self.record_map(packet, 56, "ARTIST_HISTORY_IMPORT_LEAF_DOMAIN")
        predecessor = next(
            item for item in row["component_bindings"] if item["component"] == "predecessorRegistry"
        )
        predecessor["source_kind"] = "immutable_constant"
        predecessor["source"] = "constant:registry_address"
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_operation_provider_field_cannot_alias_core_constant(self) -> None:
        packet = self.copy_packet()
        row = self.record_map(packet, 14, "POLICY_CONSENT_RECORD_DOMAIN")
        provider = next(
            item for item in row["component_bindings"] if item["component"] == "mintManager"
        )
        provider["source_kind"] = "immutable_constant"
        provider["source"] = "constant:provider_core"
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_same_type_event_field_substitution_is_rejected(self) -> None:
        packet = self.copy_packet()
        row = self.record_map(packet, 14, "POLICY_CONSENT_RECORD_DOMAIN")
        artist_id = next(
            item for item in row["component_bindings"] if item["component"] == "artistId"
        )
        artist_id["source"] = "event:ArtistPolicyConsentRecorded.policyHash"
        self.assert_rejected(packet, "40 created-record component mappings drifted")

    def test_implicit_event_source_ambiguity_is_rejected(self) -> None:
        aliases = dict(checker.ALIASED_EVENT_SOURCES)
        aliases.pop((44, "DISPUTE_RECORD_DOMAIN", "collectionId"))
        with patch.object(checker, "ALIASED_EVENT_SOURCES", aliases):
            self.assert_rejected(
                self.copy_packet(),
                "ambiguous record component source: operation 44 "
                "DISPUTE_RECORD_DOMAIN.collectionId",
            )

    def test_mapping_completion_claim_cannot_be_lowered(self) -> None:
        packet = self.copy_packet()
        packet["record_reconstruction_rows"][0]["reconstruction_complete"] = False
        self.assert_rejected(packet, "schema validation failed")

    def test_permitted_constant_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["permitted_constants"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_live_chainid_constant_rule_is_rejected(self) -> None:
        packet = self.copy_packet()
        chain = next(
            row
            for row in packet["permitted_constants"]
            if row["constant_id"] == "deployment_chain_id"
        )
        chain["value_rule"] = "live block.chainid"
        self.assert_rejected(packet, "permitted immutable constant inventory drifted")

    def test_every_minimal_suffix_is_required(self) -> None:
        for event_name in checker.EXPECTED_SUFFIXES:
            with self.subTest(event=event_name):
                packet = self.copy_packet()
                self.event(packet, event_name)["fields"].pop()
                self.assert_rejected(packet, "54 ordered event rows drifted")

    def test_unused_suffix_fixture_is_rejected(self) -> None:
        suffixes = deepcopy(checker.EXPECTED_SUFFIXES)
        suffixes["PhantomEvent"] = [
            {"type": "bytes32", "name": "phantom", "indexed": False}
        ]
        with patch.object(checker, "EXPECTED_SUFFIXES", suffixes):
            self.assert_rejected(
                self.copy_packet(), "suffix fixture event is not normative"
            )

    def test_history_invariant_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][2]["invariants"].pop()
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_history_invariant_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        rules = packet["correction_rules"][2]["invariants"]
        rules[0], rules[1] = rules[1], rules[0]
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_supersession_invariant_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["correction_rules"][3]["invariants"].pop()
        self.assert_rejected(packet, "complete correction rule identity/body/order drifted")

    def test_static_record_vector_hash_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][0]["expected_hash"] = "0x" + "33" * 32
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_static_record_vector_word_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        words = packet["canonical_record_vectors"][1]["expected_abi_words"]
        words[3], words[4] = words[4], words[3]
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_import_inner_hash_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][2]["expected_inner_hash"] = "0x" + "44" * 32
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_import_outer_hash_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][2]["expected_hash"] = "0x" + "55" * 32
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_supersession_array_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        values = packet["canonical_record_vectors"][3]["components"][1]["value"]
        values[0], values[1] = values[1], values[0]
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_supersession_array_duplicate_is_rejected(self) -> None:
        packet = self.copy_packet()
        values = packet["canonical_record_vectors"][3]["components"][1]["value"]
        values[1] = values[0]
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_supersession_array_zero_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][3]["components"][1]["value"][0] = "0x" + "00" * 32
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_supersession_array_length_above_64_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][3]["components"][1]["value"] = [
            "0x" + f"{value:064x}" for value in range(1, 66)
        ]
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_supersession_dynamic_offset_drift_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][3]["expected_abi_words"][1] = "0x" + "00" * 32
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_vector_component_name_is_domain_tied(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][0]["components"][4]["name"] = "tokenId"
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_vector_component_type_is_domain_tied(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][2]["components"][5]["type"] = "uint256"
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_vector_correction_identity_is_domain_tied(self) -> None:
        packet = self.copy_packet()
        packet["canonical_record_vectors"][0]["correction_id"] = (
            "delegation_revocation_reconstruction"
        )
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_static_word_hash_and_semantic_digest_coordinated_repin_is_rejected(self) -> None:
        packet = self.copy_packet()
        vector = self.record_vector(packet, "binding_refusal_static_v1")
        vector["components"][4]["value"] = 43
        vector["expected_abi_words"][4] = "0x" + (43).to_bytes(32, "big").hex()
        encoded = b"".join(bytes.fromhex(word[2:]) for word in vector["expected_abi_words"])
        vector["expected_hash"] = checker._hex_keccak(encoded)
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_history_words_hashes_and_semantic_digest_coordinated_repin_is_rejected(self) -> None:
        packet = self.copy_packet()
        vector = self.record_vector(packet, "history_import_leaf_static_v1")
        vector["components"][5]["value"] = 4
        vector["expected_abi_words"][5] = "0x" + (4).to_bytes(32, "big").hex()
        encoded = b"".join(bytes.fromhex(word[2:]) for word in vector["expected_abi_words"])
        inner = checker._keccak(encoded)
        vector["expected_inner_hash"] = "0x" + inner.hex()
        vector["expected_hash"] = checker._hex_keccak(inner)
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_array_words_hash_and_semantic_digest_coordinated_repin_is_rejected(self) -> None:
        packet = self.copy_packet()
        vector = self.record_vector(packet, "identity_recovery_supersession_dynamic_v1")
        hashes = vector["components"][1]["value"]
        hashes.append("0x" + f"{4:064x}")
        domain = bytes.fromhex(vector["components"][0]["value"][2:])
        encoded = (
            domain
            + (64).to_bytes(32, "big")
            + len(hashes).to_bytes(32, "big")
            + b"".join(bytes.fromhex(value[2:]) for value in hashes)
        )
        vector["expected_abi_words"] = [
            "0x" + encoded[index : index + 32].hex()
            for index in range(0, len(encoded), 32)
        ]
        vector["expected_hash"] = checker._hex_keccak(encoded)
        self.assert_rejected(packet, "typed canonical record vector bytes/schema drifted")

    def test_historical_coverage_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["historical_compatibility"][0]["normative_event_coverage"] = 54
        self.assert_rejected(packet, "schema validation failed")

    def test_historical_posture_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["historical_compatibility"][0]["posture"] = "baseline"
        self.assert_rejected(packet, "schema validation failed")

    def test_historical_archive_is_self_contained_and_deduplicated(self) -> None:
        self.assertEqual(2, len(self.archive["commit_objects"]))
        self.assertEqual(4, len(self.archive["tree_objects"]))
        self.assertEqual(38, len(self.archive["blob_objects"]))
        self.assertEqual(
            39,
            sum(len(row["selected_sources"]) for row in self.archive["snapshots"]),
        )
        approval_oids = [
            source["blob_oid"]
            for snapshot in self.archive["snapshots"]
            for source in snapshot["selected_sources"]
            if source["path"] == "smart-contracts/StreamArtistApprovals.sol"
        ]
        self.assertEqual(
            ["7c08b938df7c9ba4eab59ccb9551c275e650913b"] * 2,
            approval_oids,
        )
        self.assertEqual(
            [(12, 21), (27, 2)],
            checker._validate_historical_archive(
                ROOT, self.copy_packet(), self.wanted_events
            ),
        )

    def test_checker_has_no_git_subprocess_or_ref_dependency(self) -> None:
        source = (ROOT / "scripts/check_artist_record_event_reconstruction_correction.py").read_text(
            encoding="utf-8"
        )
        self.assertNotIn("import subprocess", source)
        self.assertNotIn("git ls-tree", source)
        self.assertNotIn("git show", source)
        self.assertNotIn("git rev-parse", source)
        self.assertNotIn("subprocess", checker.__dict__)

    def test_historical_archive_missing_object_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["blob_objects"].pop()
        self.assert_archive_rejected(archive, "blob object inventory drifted")

    def test_historical_archive_extra_object_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        raw = b"extra historical object"
        oid = hashlib.sha1(
            f"blob {len(raw)}\0".encode() + raw,
            usedforsecurity=False,
        ).hexdigest()
        archive["blob_objects"].append(
            {
                "oid": oid,
                "size_bytes": len(raw),
                "data_base64": base64.b64encode(raw).decode(),
            }
        )
        self.assert_archive_rejected(archive, "blob object inventory drifted")

    def test_historical_archive_duplicate_object_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["blob_objects"][-1] = deepcopy(archive["blob_objects"][0])
        self.assert_archive_rejected(archive, "duplicate object id")

    def test_historical_archive_outside_path_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["snapshots"][0]["selected_sources"][0]["path"] = "../Artist.sol"
        self.assert_archive_rejected(archive, "escapes smart-contracts")

    def test_historical_archive_missing_selected_path_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["snapshots"][0]["selected_sources"].pop()
        self.assert_archive_rejected(archive, "exact snapshot/path/blob map drifted")

    def test_historical_archive_extra_selected_path_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["snapshots"][0]["selected_sources"].append(
            {
                "path": "smart-contracts/UnexpectedArtist.sol",
                "blob_oid": archive["blob_objects"][0]["oid"],
            }
        )
        self.assert_archive_rejected(archive, "exact snapshot/path/blob map drifted")

    def test_historical_archive_duplicate_selected_path_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["snapshots"][0]["selected_sources"][-1] = deepcopy(
            archive["snapshots"][0]["selected_sources"][0]
        )
        self.assert_archive_rejected(archive, "duplicate selected source path")

    def test_historical_archive_malformed_base64_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        archive["blob_objects"][0]["data_base64"] = "not***base64"
        self.assert_archive_rejected(archive, "malformed base64")

    def test_historical_archive_object_id_drift_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        row = archive["blob_objects"][0]
        raw = base64.b64decode(row["data_base64"]) + b"\n"
        row["size_bytes"] = len(raw)
        row["data_base64"] = base64.b64encode(raw).decode()
        self.assert_archive_rejected(archive, "blob object id drifted")

    def test_historical_archive_malformed_tree_is_rejected(self) -> None:
        with self.assertRaisesRegex(checker.CorrectionError, "malformed tree"):
            checker._parse_historical_tree(b"100644 Artist.sol\0short", "hostile")

    def test_historical_archive_file_symlink_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_root = Path(temp_dir)
            target = temp_root / "archive-target.json"
            target.write_bytes((ROOT / checker.HISTORICAL_ARCHIVE_PATH).read_bytes())
            archive_path = temp_root / checker.HISTORICAL_ARCHIVE_PATH
            archive_path.parent.mkdir(parents=True, exist_ok=True)
            try:
                archive_path.symlink_to(target)
            except OSError as exc:
                self.skipTest(f"symlinks unavailable on this platform: {exc}")
            with self.assertRaisesRegex(checker.CorrectionError, "path is a symlink"):
                checker._validate_historical_archive(
                    temp_root, self.copy_packet(), self.wanted_events
                )

    def test_historical_archive_selected_tree_symlink_is_rejected(self) -> None:
        archive = deepcopy(self.archive)
        snapshot = archive["snapshots"][0]
        smart_oid = snapshot["smart_contracts_tree_oid"]
        smart_row = self.object_row(archive, "tree_objects", smart_oid)
        smart_raw = base64.b64decode(smart_row["data_base64"])
        source = snapshot["selected_sources"][0]
        name = source["path"].removeprefix("smart-contracts/")
        smart_raw = self.replace_tree_entry(
            smart_raw,
            mode="100644",
            name=name,
            old_oid=source["blob_oid"],
            new_mode="120000",
        )
        new_smart_oid = self.repin_object(smart_row, "tree", smart_raw)
        old_root_oid = snapshot["root_tree_oid"]
        root_row = self.object_row(archive, "tree_objects", old_root_oid)
        root_raw = self.replace_tree_entry(
            base64.b64decode(root_row["data_base64"]),
            mode="40000",
            name="smart-contracts",
            old_oid=smart_oid,
            new_oid=new_smart_oid,
        )
        new_root_oid = self.repin_object(root_row, "tree", root_raw)
        old_commit_oid = snapshot["commit_oid"]
        commit_row = self.object_row(archive, "commit_objects", old_commit_oid)
        commit_raw = base64.b64decode(commit_row["data_base64"])
        commit_raw = commit_raw.replace(
            f"tree {old_root_oid}\n".encode(),
            f"tree {new_root_oid}\n".encode(),
            1,
        )
        new_commit_oid = self.repin_object(commit_row, "commit", commit_raw)
        snapshot.update(
            {
                "commit_oid": new_commit_oid,
                "root_tree_oid": new_root_oid,
                "smart_contracts_tree_oid": new_smart_oid,
            }
        )
        expected = list(deepcopy(checker.EXPECTED_HISTORICAL_SNAPSHOTS))
        current = list(expected[0])
        current[1:4] = [new_commit_oid, new_root_oid, new_smart_oid]
        expected[0] = tuple(current)
        self.assert_archive_rejected(
            archive,
            "selected source is a symlink",
            expected_snapshots=tuple(expected),
        )

    def test_historical_archive_coordinated_blob_tree_commit_repin_is_rejected(
        self,
    ) -> None:
        archive = deepcopy(self.archive)
        snapshot = archive["snapshots"][0]
        source = snapshot["selected_sources"][0]
        old_blob_oid = source["blob_oid"]
        blob_row = self.object_row(archive, "blob_objects", old_blob_oid)
        new_blob_oid = self.repin_object(
            blob_row,
            "blob",
            base64.b64decode(blob_row["data_base64"]) + b"\n",
        )
        source["blob_oid"] = new_blob_oid
        old_smart_oid = snapshot["smart_contracts_tree_oid"]
        smart_row = self.object_row(archive, "tree_objects", old_smart_oid)
        name = source["path"].removeprefix("smart-contracts/")
        smart_raw = self.replace_tree_entry(
            base64.b64decode(smart_row["data_base64"]),
            mode="100644",
            name=name,
            old_oid=old_blob_oid,
            new_oid=new_blob_oid,
        )
        new_smart_oid = self.repin_object(smart_row, "tree", smart_raw)
        old_root_oid = snapshot["root_tree_oid"]
        root_row = self.object_row(archive, "tree_objects", old_root_oid)
        root_raw = self.replace_tree_entry(
            base64.b64decode(root_row["data_base64"]),
            mode="40000",
            name="smart-contracts",
            old_oid=old_smart_oid,
            new_oid=new_smart_oid,
        )
        new_root_oid = self.repin_object(root_row, "tree", root_raw)
        old_commit_oid = snapshot["commit_oid"]
        commit_row = self.object_row(archive, "commit_objects", old_commit_oid)
        commit_raw = base64.b64decode(commit_row["data_base64"]).replace(
            f"tree {old_root_oid}\n".encode(),
            f"tree {new_root_oid}\n".encode(),
            1,
        )
        new_commit_oid = self.repin_object(commit_row, "commit", commit_raw)
        snapshot.update(
            {
                "commit_oid": new_commit_oid,
                "root_tree_oid": new_root_oid,
                "smart_contracts_tree_oid": new_smart_oid,
            }
        )

        def mutate_packet(packet: dict, _archive: dict) -> None:
            packet["historical_compatibility"][0].update(
                {
                    "commit": new_commit_oid,
                    "root_tree": new_root_oid,
                    "smart_contracts_tree": new_smart_oid,
                }
            )

        self.assert_archive_rejected(
            archive,
            "exact snapshot/path/blob map drifted",
            packet_mutator=mutate_packet,
        )

    def test_normative_events_acceptance_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["gate_state"]["normative_owner_events_accepted"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_dual_continuity_claim_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_protocol"]["dual_continuity_packet_created"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_owner_commitment_claim_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["record_protocol"]["owner_v2_record_commitment_created"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_inner_commitment_resolution_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["gate_state"]["four_inner_commitments_resolved"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_interface_freeze_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["gate_state"]["interface_freeze_complete"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_source_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["gate_state"]["source_present"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_readiness_promotion_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["gate_state"]["readiness_credit"] = True
        self.assert_rejected(packet, "schema validation failed")

    def test_unresolved_dependency_omission_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["unresolved_dependencies"].pop()
        self.assert_rejected(packet, "schema validation failed")

    def test_unresolved_dependency_reorder_is_rejected(self) -> None:
        packet = self.copy_packet()
        values = packet["unresolved_dependencies"]
        values[0], values[1] = values[1], values[0]
        self.assert_rejected(packet, "unresolved dependency order/content drifted")

    def test_selected_option_mismatch_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["selected_shape"]["option_id"] = "generic_record_witness_event"
        self.assert_rejected(packet, "schema validation failed")

    def test_multiple_selected_options_are_rejected(self) -> None:
        packet = self.copy_packet()
        packet["selected_shape"]["options"][0]["selected"] = True
        self.assert_rejected(packet, "continuity option inventory/selection drifted")

    def test_unexpected_root_property_is_rejected(self) -> None:
        packet = self.copy_packet()
        packet["unexpected"] = True
        self.assert_rejected(packet, "schema validation failed")


if __name__ == "__main__":
    unittest.main()
