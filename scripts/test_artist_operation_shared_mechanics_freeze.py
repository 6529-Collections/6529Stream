#!/usr/bin/env python3
"""Hostile tests for the proposed artist shared-mechanics decision register."""

from __future__ import annotations

import importlib.util
import json
import shutil
import tempfile
import unittest
from pathlib import Path
from types import ModuleType
from typing import Any

REPO_ROOT = Path(__file__).resolve().parents[1]
CHECKER_PATH = REPO_ROOT / "scripts/check_artist_operation_shared_mechanics_freeze.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("artist_mechanics_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load artist shared-mechanics checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()


class ArtistOperationSharedMechanicsFreezeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        copied = {
            CHECKER.PACKET_PATH,
            CHECKER.SCHEMA_PATH,
            CHECKER.MATRIX_PATH,
            *(
                Path(relative)
                for _, relative, _ in CHECKER.EXPECTED_AUTHORITY_BINDINGS
            ),
        }
        for relative in copied:
            destination = self.root / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(REPO_ROOT / relative, destination)

    def tearDown(self) -> None:
        self.tempdir.cleanup()

    def _read(self, relative: Path) -> dict[str, Any]:
        return json.loads((self.root / relative).read_text(encoding="utf-8"))

    def _write(self, relative: Path, value: dict[str, Any]) -> None:
        (self.root / relative).write_text(
            json.dumps(value, indent=2) + "\n",
            encoding="utf-8",
        )

    def _packet(self) -> dict[str, Any]:
        return self._read(CHECKER.PACKET_PATH)

    def _write_packet(self, packet: dict[str, Any]) -> None:
        self._write(CHECKER.PACKET_PATH, packet)

    def _assert_rejected(self, expected: str | None = None) -> None:
        if expected is None:
            with self.assertRaises(CHECKER.FreezeError):
                CHECKER.check(self.root)
        else:
            with self.assertRaisesRegex(CHECKER.FreezeError, expected):
                CHECKER.check(self.root)

    def test_baseline_is_exact(self) -> None:
        counts = CHECKER.check(self.root)
        self.assertEqual(counts, {
            "authority_bindings": 10,
            "phases": 4,
            "decision_rows": 19,
            "accepted_decisions": 0,
            "operations": 57,
        })

    def test_safety_posture_is_independently_literal(self) -> None:
        packet = self._packet()
        self.assertEqual(packet["status"], "PROPOSED_DECISION_REGISTER_ONLY")
        self.assertEqual(packet["maturity"], "pre_audit_source_blocked")
        self.assertFalse(packet["selected_shape"]["comprehensive_freeze_complete"])
        self.assertFalse(packet["selected_shape"]["typed_abi_only_authorizes_source"])
        self.assertFalse(packet["gate_state"]["interface_and_storage_freeze_complete"])
        self.assertFalse(packet["gate_state"]["coordinator_interface_accepted"])
        self.assertFalse(packet["gate_state"]["coordinator_source_present"])
        self.assertFalse(packet["gate_state"]["implementation_authorized"])
        self.assertTrue(all(not row["accepted"] for row in packet["decision_rows"]))
        self.assertTrue(all(row["source_blocking"] for row in packet["decision_rows"]))

    def test_duplicate_json_member_is_rejected(self) -> None:
        path = self.root / CHECKER.PACKET_PATH
        raw = path.read_text(encoding="utf-8")
        path.write_text(raw.replace("{", '{"schema":"shadow",', 1), encoding="utf-8")
        self._assert_rejected("duplicate JSON member")

    def test_unsafe_integer_is_rejected(self) -> None:
        path = self.root / CHECKER.PACKET_PATH
        raw = path.read_text(encoding="utf-8")
        path.write_text(
            raw.replace('"operation_count": 57', '"operation_count": 9007199254740992', 1),
            encoding="utf-8",
        )
        self._assert_rejected("unsafe JSON integer")

    def test_schema_digest_is_independently_pinned(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["title"] = "tampered"
        self._write(CHECKER.SCHEMA_PATH, schema)
        self._assert_rejected("schema sha256 drifted")

    def test_extra_top_level_readiness_claim_is_rejected(self) -> None:
        packet = self._packet()
        packet["production_ready"] = True
        self._write_packet(packet)
        self._assert_rejected("critical top-level fields drifted")

    def test_status_or_maturity_promotion_is_rejected(self) -> None:
        for field, value, expected in (
            ("status", "ACCEPTED", "Proposed decision register"),
            ("maturity", "production_ready", "pre-audit and source-blocked"),
        ):
            with self.subTest(field=field):
                packet = self._packet()
                packet[field] = value
                self._write_packet(packet)
                self._assert_rejected(expected)
                shutil.copy2(REPO_ROOT / CHECKER.PACKET_PATH, self.root / CHECKER.PACKET_PATH)

    def test_authority_bytes_are_pinned(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        path = self.root / relative
        path.write_text(path.read_text(encoding="utf-8") + "\nclaim drift\n", encoding="utf-8")
        self._assert_rejected("authority coordinator_source_gate sha256 drifted")

    def test_coupled_authority_and_packet_tamper_is_rejected(self) -> None:
        relative = Path(
            "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md"
        )
        path = self.root / relative
        path.write_text(path.read_text(encoding="utf-8") + "\nclaim drift\n", encoding="utf-8")
        packet = self._packet()
        packet["authority_bindings"][0]["sha256"] = "0" * 64
        self._write_packet(packet)
        self._assert_rejected("authority binding identity, order, or digest drifted")

    def test_selected_shape_cannot_become_typed_abi_only(self) -> None:
        packet = self._packet()
        packet["selected_shape"]["option"] = "B"
        packet["selected_shape"]["scope"] = "typed_abi_only"
        self._write_packet(packet)
        self._assert_rejected("schema violation|selected dependency shape")

    def test_typed_abi_alone_cannot_authorize_source(self) -> None:
        packet = self._packet()
        packet["selected_shape"]["typed_abi_only_authorizes_source"] = True
        packet["gate_state"]["implementation_authorized"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|selected dependency shape|gate state")

    def test_phase_order_cannot_skip_shared_mechanics(self) -> None:
        packet = self._packet()
        packet["phase_order"][0], packet["phase_order"][1] = (
            packet["phase_order"][1],
            packet["phase_order"][0],
        )
        self._write_packet(packet)
        self._assert_rejected("phase order")

    def test_unresolved_decision_cannot_be_selected_or_accepted(self) -> None:
        packet = self._packet()
        row = packet["decision_rows"][0]
        row["decision_status"] = "accepted"
        row["selected_option"] = "invented ABI"
        row["accepted"] = True
        row["source_blocking"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|decision.*overclaims|decision rows")

    def test_decision_surface_omission_is_rejected_by_schema_cardinality(self) -> None:
        packet = self._packet()
        packet["decision_rows"].pop()
        self._write_packet(packet)
        self._assert_rejected(
            r"schema violation at \$\['decision_rows'\]: .* is too short"
        )

    def test_twentieth_unknown_decision_surface_is_rejected_by_schema_cardinality(
        self,
    ) -> None:
        packet = self._packet()
        extra = dict(packet["decision_rows"][0])
        extra["surface_id"] = "unknown_future_surface"
        packet["decision_rows"].append(extra)
        self._write_packet(packet)
        self._assert_rejected(
            r"schema violation at \$\['decision_rows'\]: .* is too long"
        )

    def test_decision_surface_reorder_is_rejected_by_checker_digest(self) -> None:
        packet = self._packet()
        packet["decision_rows"][0], packet["decision_rows"][1] = (
            packet["decision_rows"][1],
            packet["decision_rows"][0],
        )
        self._write_packet(packet)
        self._assert_rejected("source-blocking decision rows drifted")

    def test_registry_and_archive_roles_cannot_expand(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["registry_role"] = "semantic_authority"
        packet["fixed_invariants"]["archive_role"] = "current_state_owner"
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_coordinator_cannot_gain_authority_or_persistent_state(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["coordinator_owns_semantic_authority"] = True
        packet["fixed_invariants"]["coordinator_owns_persistent_state"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_generic_routing_delegatecall_and_rebinding_are_rejected(self) -> None:
        packet = self._packet()
        invariants = packet["fixed_invariants"]
        invariants["generic_selector_or_calldata_route"] = True
        invariants["delegatecall"] = True
        invariants["mutable_rebinding"] = True
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_original_caller_and_snapshot_order_cannot_weaken(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["original_caller_required"] = False
        packet["fixed_invariants"]["snapshots_before_first_mutation"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_payable_or_value_forwarding_drift_is_rejected(self) -> None:
        packet = self._packet()
        projection = packet["operation_projection"]
        projection["registry_state_mutability"] = "payable"
        projection["coordinator_state_mutability"] = "payable"
        projection["typed_collaborator_call_value_wei"] = 1
        self._write_packet(packet)
        self._assert_rejected("schema violation|57-operation projection")

    def test_unknown_signatures_cannot_be_invented_in_this_slice(self) -> None:
        packet = self._packet()
        packet["operation_projection"]["registry_signature_status"] = "accepted"
        packet["operation_projection"]["coordinator_signature_status"] = "accepted"
        self._write_packet(packet)
        self._assert_rejected("schema violation|57-operation projection")

    def test_operation_22_stop_cannot_be_removed(self) -> None:
        packet = self._packet()
        packet["fixed_invariants"]["operation_22_stop"] = ""
        packet["operation_projection"]["operation_22_effective_stop"] = ""
        packet["gate_state"]["operation_22_stop_preserved"] = False
        self._write_packet(packet)
        self._assert_rejected("schema violation|fixed architecture invariants")

    def test_missing_authority_is_reported_as_freeze_error(self) -> None:
        relative = Path("smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol")
        (self.root / relative).unlink()
        self._assert_rejected("authority archive_v2_interface is unreadable")

    def test_coordinator_source_or_interface_presence_fails_closed(self) -> None:
        for relative in (
            Path("smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol"),
            CHECKER.COORDINATOR_INTERFACE_PATH,
        ):
            with self.subTest(relative=relative):
                path = self.root / relative
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("pragma solidity 0.8.19;\n", encoding="utf-8")
                self._assert_rejected("source-blocked artist component|Coordinator interface")
                path.unlink()

    def test_unmodeled_artist_source_fails_closed(self) -> None:
        path = self.root / CHECKER.ARTIST_SOURCE_ROOT / "StreamArtistRegistryV3.sol"
        path.write_text("pragma solidity 0.8.19;\n", encoding="utf-8")
        self._assert_rejected("canonical artist source set drifted")

    def test_issue_669_exact_staticcall_row_remains_bound(self) -> None:
        matrix = self._read(CHECKER.MATRIX_PATH)
        row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
        self.assertEqual(row, CHECKER.EXPECTED_669_ROW)
        row["call_syntax"] = "signer.staticcall(context.erc1271GasCap)"
        self._write(CHECKER.MATRIX_PATH, matrix)
        self._assert_rejected("authority semantic_owner_matrix sha256 drifted")


if __name__ == "__main__":
    unittest.main()
