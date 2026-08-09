#!/usr/bin/env python3
"""Hostile tests for global artist semantic-domain ownership."""

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
CHECKER_PATH = REPO_ROOT / "scripts/check_artist_semantic_owner_matrix.py"


def _load_checker() -> ModuleType:
    spec = importlib.util.spec_from_file_location("artist_owner_checker", CHECKER_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load artist semantic-owner checker")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


CHECKER = _load_checker()
PROVIDER_INTERFACE_PATHS = (
    Path("smart-contracts/interfaces/stream/IStreamRoleRegistry.sol"),
    Path("smart-contracts/interfaces/stream/IStreamCore.sol"),
    Path("smart-contracts/interfaces/stream/IStreamGovernedParameterAuthority.sol"),
    Path("smart-contracts/interfaces/stream/IStreamArtworkFinalityRegistry.sol"),
)


class ArtistSemanticOwnerMatrixTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tempdir = tempfile.TemporaryDirectory()
        self.root = Path(self.tempdir.name)
        for relative in (
            CHECKER.MATRIX_PATH,
            CHECKER.SCHEMA_PATH,
            CHECKER.SOURCE_PATH,
            *PROVIDER_INTERFACE_PATHS,
        ):
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

    def _matrix(self) -> dict[str, Any]:
        return self._read(CHECKER.MATRIX_PATH)

    def _write_matrix(self, matrix: dict[str, Any]) -> None:
        self._write(CHECKER.MATRIX_PATH, matrix)

    def _restore_matrix(self) -> None:
        shutil.copy2(REPO_ROOT / CHECKER.MATRIX_PATH, self.root / CHECKER.MATRIX_PATH)

    def _assert_rejected(self, expected: str | None = None) -> None:
        if expected is None:
            with self.assertRaises(CHECKER.MatrixError):
                CHECKER.check(self.root)
        else:
            with self.assertRaisesRegex(CHECKER.MatrixError, expected):
                CHECKER.check(self.root)

    def test_baseline_is_exact(self) -> None:
        CHECKER.check(self.root)

    def test_safety_posture_is_independently_literal(self) -> None:
        matrix = json.loads(
            (REPO_ROOT / CHECKER.MATRIX_PATH).read_text(encoding="utf-8")
        )
        self.assertEqual(set(matrix), {
            "schema",
            "status",
            "maturity",
            "source_freeze",
            "proposed_supersession",
            "directory",
            "operation_coordinator",
            "archive",
            "semantic_domains",
            "current_state_surfaces",
            "record_surfaces",
            "event_surfaces",
            "replay_surfaces",
            "cross_domain_protocol",
            "constructor_dag",
            "sole_authorities",
            "immutable_external_providers",
            "authority_surfaces",
            "external_dependencies",
            "source_requirements",
            "operations",
            "implementation_stops",
        })
        self.assertEqual(matrix["status"], "PROPOSED_ARCHITECTURE_ONLY")
        self.assertEqual(matrix["maturity"], "pre_audit_implementation_blocked")
        self.assertEqual(set(matrix["directory"]), {
            "name",
            "role",
            "owns_semantic_authority",
            "semantic_storage",
            "owns_semantic_truth",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "generic_routing",
            "arbitrary_selector_or_calldata",
            "delegatecall",
            "upgrade_path",
            "mutable_rebinding",
            "routes_only_to",
            "immutable_pins",
            "original_caller_protocol",
        })
        self.assertEqual(set(matrix["operation_coordinator"]), {
            "name",
            "role",
            "owns_semantic_authority",
            "semantic_storage",
            "record_storage",
            "replay_storage",
            "normative_event_emitter",
            "generic_selector_route",
            "generic_calldata_route",
            "delegatecall",
            "upgrade_path",
            "mutable_recipe",
            "enumerated_recipe_count",
            "transient_state",
            "snapshot_protocol",
            "owner_call_protocol",
            "atomicity",
        })
        self.assertEqual(set(matrix["archive"]), {
            "name",
            "deployment_position",
            "role",
            "owns_semantic_authority",
            "semantic_storage",
            "owns_authorization",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "usable_for_authentication",
            "usable_for_replay_decisions",
            "usable_for_current_state_decisions",
            "usable_for_latest_state_decisions",
            "generic_routing",
            "delegatecall",
            "upgrade_path",
            "event_semantics",
            "atomicity",
        })
        self.assertEqual(
            {
                key: matrix["directory"][key]
                for key in (
                    "owns_semantic_authority",
                    "semantic_storage",
                    "owns_semantic_truth",
                    "owns_records",
                    "owns_replay_state",
                    "owns_current_or_latest_state",
                    "generic_routing",
                    "arbitrary_selector_or_calldata",
                    "delegatecall",
                    "upgrade_path",
                    "mutable_rebinding",
                )
            },
            {key: False for key in (
                "owns_semantic_authority",
                "semantic_storage",
                "owns_semantic_truth",
                "owns_records",
                "owns_replay_state",
                "owns_current_or_latest_state",
                "generic_routing",
                "arbitrary_selector_or_calldata",
                "delegatecall",
                "upgrade_path",
                "mutable_rebinding",
            )},
        )
        for key in (
            "owns_semantic_authority",
            "semantic_storage",
            "record_storage",
            "replay_storage",
            "normative_event_emitter",
            "generic_selector_route",
            "generic_calldata_route",
            "delegatecall",
            "upgrade_path",
            "mutable_recipe",
        ):
            self.assertIs(matrix["operation_coordinator"][key], False)
        for key in (
            "owns_semantic_authority",
            "semantic_storage",
            "owns_authorization",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "usable_for_authentication",
            "usable_for_replay_decisions",
            "usable_for_current_state_decisions",
            "usable_for_latest_state_decisions",
            "generic_routing",
            "delegatecall",
            "upgrade_path",
        ):
            self.assertIs(matrix["archive"][key], False)

    def test_duplicate_json_member_is_rejected(self) -> None:
        path = self.root / CHECKER.MATRIX_PATH
        raw = path.read_text(encoding="utf-8")
        path.write_text(raw.replace("{", '{"schema":"shadow",', 1), encoding="utf-8")
        self._assert_rejected("duplicate JSON member")

    def test_unsafe_integer_is_rejected(self) -> None:
        path = self.root / CHECKER.MATRIX_PATH
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

    def test_coupled_schema_and_matrix_tamper_is_rejected(self) -> None:
        schema = self._read(CHECKER.SCHEMA_PATH)
        schema["$defs"]["coordinator"]["properties"]["generic_selector_route"] = {
            "type": "boolean"
        }
        self._write(CHECKER.SCHEMA_PATH, schema)
        matrix = self._matrix()
        matrix["operation_coordinator"]["generic_selector_route"] = True
        self._write_matrix(matrix)
        self._assert_rejected("schema sha256 drifted")

    def test_extra_critical_top_level_field_is_rejected(self) -> None:
        matrix = self._matrix()
        matrix["production_ready"] = True
        self._write_matrix(matrix)
        self._assert_rejected("critical top-level fields drifted")

    def test_matrix_identity_status_and_maturity_are_independent(self) -> None:
        for field, value, expected in (
            ("schema", "artist.v3", "schema id drifted"),
            ("status", "ACCEPTED", "remain Proposed"),
            ("maturity", "production_ready", "remain pre-audit"),
        ):
            with self.subTest(field=field):
                matrix = self._matrix()
                matrix[field] = value
                self._write_matrix(matrix)
                self._assert_rejected(expected)
                self._restore_matrix()

    def test_source_freeze_bytes_are_pinned(self) -> None:
        source = self._read(CHECKER.SOURCE_PATH)
        source["operations"][0][6] += " drift"
        self._write(CHECKER.SOURCE_PATH, source)
        self._assert_rejected("source freeze sha256 drifted")

    def test_all_18_source_row_fields_are_bound(self) -> None:
        original = self._matrix()["operations"][0]["source_row"]
        for field, value in original.items():
            with self.subTest(field=field):
                matrix = self._matrix()
                row = matrix["operations"][0]["source_row"]
                if isinstance(value, int):
                    row[field] = value + 1
                elif isinstance(value, list):
                    row[field] = [*value, "UNREVIEWED_STOP"]
                else:
                    row[field] = value + "_drift"
                self._write_matrix(matrix)
                self._assert_rejected("18-column source binding")
                self._restore_matrix()

    def test_current_state_fact_cannot_be_unresolved(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["current_state_fact_bindings"].pop()
        self._write_matrix(matrix)
        self._assert_rejected("current-state facts are unresolved")

    def test_current_state_fact_requires_exact_snapshots(self) -> None:
        matrix = self._matrix()
        matrix["operations"][14]["current_state_fact_bindings"][1][
            "surface_ids"
        ] = ["external:governance"]
        self._write_matrix(matrix)
        self._assert_rejected("unowned or unsnapshotted")

    def test_replay_fact_cannot_be_unresolved(self) -> None:
        matrix = self._matrix()
        matrix["operations"][1]["replay_fact_bindings"].pop()
        self._write_matrix(matrix)
        self._assert_rejected("replay facts are unresolved")

    def test_record_owner_cannot_split_at_operation(self) -> None:
        matrix = self._matrix()
        matrix["operations"][1]["record_bindings"][0][
            "owner_domain"
        ] = "binding_lifecycle"
        self._write_matrix(matrix)
        self._assert_rejected("record owner split")

    def test_record_surface_cannot_have_two_owner_rows(self) -> None:
        matrix = self._matrix()
        matrix["record_surfaces"][1] = dict(matrix["record_surfaces"][0])
        self._write_matrix(matrix)
        self._assert_rejected("more than one owner row")

    def test_event_owner_cannot_split_at_operation(self) -> None:
        matrix = self._matrix()
        matrix["operations"][1]["event_bindings"][0][
            "emitter_domain"
        ] = "binding_lifecycle"
        self._write_matrix(matrix)
        self._assert_rejected("event owner split")

    def test_replay_surface_cannot_be_unowned(self) -> None:
        matrix = self._matrix()
        matrix["replay_surfaces"].pop()
        self._write_matrix(matrix)
        self._assert_rejected("ownership map drifted|replay surface")

    def test_one_owner_cannot_write_another_domain_state(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["coordinator_recipe"]["actions"][0][
            "write_surfaces"
        ].append("state:binding_lifecycle")
        self._write_matrix(matrix)
        self._assert_rejected("writes binding_lifecycle's surface")

    def test_unknown_typed_write_surface_is_matrix_error(self) -> None:
        for surface_type in ("record", "event", "replay"):
            with self.subTest(surface_type=surface_type):
                matrix = self._matrix()
                surface = f"{surface_type}:UNREVIEWED_SURFACE"
                matrix["operations"][0]["coordinator_recipe"]["actions"][0][
                    "write_surfaces"
                ].append(surface)
                self._write_matrix(matrix)
                self._assert_rejected(
                    f"writes unowned {surface_type} surface {surface}"
                )
                self._restore_matrix()

    def test_owner_must_validate_exact_coordinator(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["coordinator_recipe"]["actions"][0][
            "validates_coordinator"
        ] = "StreamArtistRegistry"
        self._write_matrix(matrix)
        self._assert_rejected("validates_coordinator")

    def test_owner_must_validate_original_caller(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["coordinator_recipe"]["actions"][0][
            "validates_original_caller"
        ] = False
        self._write_matrix(matrix)
        self._assert_rejected("validates_original_caller")

    def test_owner_must_validate_its_revision_pin(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["coordinator_recipe"]["actions"][0][
            "validates_revision_snapshot"
        ] = "domain:binding_lifecycle"
        self._write_matrix(matrix)
        self._assert_rejected("coordinator/caller/revision")

    def test_coordinator_cannot_gain_generic_route(self) -> None:
        matrix = self._matrix()
        matrix["operation_coordinator"]["generic_calldata_route"] = True
        self._write_matrix(matrix)
        self._assert_rejected("generic_calldata_route")

    def test_registry_cannot_gain_semantic_storage(self) -> None:
        matrix = self._matrix()
        matrix["directory"]["owns_semantic_authority"] = True
        matrix["directory"]["semantic_storage"] = True
        self._write_matrix(matrix)
        self._assert_rejected("directory.*(owns_semantic_authority|semantic_storage)")

    def test_coordinator_cannot_gain_semantic_authority(self) -> None:
        matrix = self._matrix()
        matrix["operation_coordinator"]["owns_semantic_authority"] = True
        self._write_matrix(matrix)
        self._assert_rejected("owns_semantic_authority")

    def test_coordinator_cannot_gain_delegatecall(self) -> None:
        matrix = self._matrix()
        matrix["operation_coordinator"]["delegatecall"] = True
        self._write_matrix(matrix)
        self._assert_rejected("delegatecall")

    def test_owner_modules_cannot_read_each_other(self) -> None:
        matrix = self._matrix()
        matrix["semantic_domains"][0]["module_reads_other_domains"] = True
        self._write_matrix(matrix)
        self._assert_rejected("module_reads_other_domains")

    def test_op1_identity_registration_recipe_is_required(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["coordinator_recipe"]["actions"].pop(0)
        self._write_matrix(matrix)
        self._assert_rejected("operation 1")

    def test_op6_identity_registration_recipe_is_required(self) -> None:
        matrix = self._matrix()
        matrix["operations"][5]["coordinator_recipe"]["actions"].pop(0)
        self._write_matrix(matrix)
        self._assert_rejected("operation 6")

    def test_op2_shared_acceptance_owner_is_required(self) -> None:
        matrix = self._matrix()
        matrix["operations"][1]["record_bindings"][0][
            "owner_domain"
        ] = "binding_lifecycle"
        self._write_matrix(matrix)
        self._assert_rejected("record owner split|shared ACCEPTANCE")

    def test_op7_shared_acceptance_owner_is_required(self) -> None:
        matrix = self._matrix()
        matrix["operations"][6]["coordinator_recipe"]["actions"] = [
            action
            for action in matrix["operations"][6]["coordinator_recipe"]["actions"]
            if action["owner_domain"] != "acceptance_lifecycle"
        ]
        self._write_matrix(matrix)
        self._assert_rejected("operation 7")

    def test_op13_attribution_transition_requires_finality_owner(self) -> None:
        matrix = self._matrix()
        matrix["operations"][12]["coordinator_recipe"]["actions"].reverse()
        self._write_matrix(matrix)
        self._assert_rejected("operation 13")

    def test_op15_payout_snapshot_precedes_consent_finality(self) -> None:
        matrix = self._matrix()
        snapshots = matrix["operations"][14]["coordinator_recipe"]["snapshot_ids"]
        payout = snapshots.index("domain:payout_lifecycle")
        consent = snapshots.index("domain:consent_finality")
        snapshots[payout], snapshots[consent] = snapshots[consent], snapshots[payout]
        self._write_matrix(matrix)
        self._assert_rejected("payout before consent")

    def test_source_requirement_cannot_be_claimed_present(self) -> None:
        matrix = self._matrix()
        matrix["operations"][0]["source_requirements"]["source_present"] = True
        matrix["operations"][0]["source_requirements"][
            "implementation_authorized"
        ] = True
        self._write_matrix(matrix)
        self._assert_rejected(
            "source_requirements.*(source_present|implementation_authorized)"
        )

    def test_base_and_effective_implementation_stops_are_bound(self) -> None:
        matrix = self._matrix()
        matrix["operations"][21]["source_row"]["implementation_stop"] = []
        matrix["operations"][21]["source_requirements"][
            "effective_implementation_stops"
        ] = []
        self._write_matrix(matrix)
        self._assert_rejected("18-column source binding|effective implementation stops")

    def test_validator_call_row_cannot_drift(self) -> None:
        matrix = self._matrix()
        row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
        row["path"] = (
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol"
        )
        row["expression"] = "gasCap"
        self._write_matrix(matrix)
        self._assert_rejected("reserved_call_row.*expression")

    def test_validator_call_row_requires_exact_staticcall_syntax(self) -> None:
        matrix = self._matrix()
        row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
        row["call_syntax"] = "signer.staticcall(context.erc1271GasCap)"
        self._write_matrix(matrix)
        self._assert_rejected("staticcall reservation|schema violation")

    def test_platform_role_snapshot_cannot_be_omitted(self) -> None:
        matrix = self._matrix()
        matrix["operations"][10]["coordinator_recipe"]["snapshot_ids"].remove(
            "authority:role_registry:ROLE_ATTRIBUTION_ARBITER"
        )
        self._write_matrix(matrix)
        self._assert_rejected("platform-role snapshots")

    def test_platform_role_snapshot_must_bind_original_caller(self) -> None:
        matrix = self._matrix()
        matrix["authority_surfaces"][1]["original_caller_required"] = False
        self._write_matrix(matrix)
        self._assert_rejected("schema violation|authority surface")

    def test_external_provider_identity_cannot_drift(self) -> None:
        matrix = self._matrix()
        matrix["immutable_external_providers"][1]["interface_pin"][
            "interface_id"
        ] = "0x00000000"
        self._write_matrix(matrix)
        self._assert_rejected("provider identities")

    def test_missing_provider_interface_is_matrix_error(self) -> None:
        (self.root / PROVIDER_INTERFACE_PATHS[0]).unlink()
        self._assert_rejected(
            "provider:role_registry interface source is unreadable: "
            "smart-contracts/interfaces/stream/IStreamRoleRegistry.sol"
        )

    def test_external_surface_cannot_rebind_provider(self) -> None:
        matrix = self._matrix()
        matrix["current_state_surfaces"][7]["provider_id"] = (
            "provider:governance_v2"
        )
        self._write_matrix(matrix)
        self._assert_rejected("provider is not exact")

    def test_missing_import_interface_cannot_pretend_implementable(self) -> None:
        matrix = self._matrix()
        provider = matrix["immutable_external_providers"][4]
        provider["implementable"] = True
        provider["interface_pin"]["status"] = "exact"
        self._write_matrix(matrix)
        self._assert_rejected("schema violation|incomplete posture")

    def test_validator_boundary_cannot_claim_semantic_authority(self) -> None:
        matrix = self._matrix()
        matrix["sole_authorities"]["artist_erc1271"][
            "boundary_authoritative"
        ] = True
        matrix["external_dependencies"]["issue_669"][
            "validation_boundary_authoritative"
        ] = True
        self._write_matrix(matrix)
        self._assert_rejected(
            "validation_boundary_authoritative|boundary_authoritative"
        )

    def test_archive_cannot_gain_replay_authority(self) -> None:
        matrix = self._matrix()
        matrix["archive"]["owns_replay_state"] = True
        matrix["archive"]["usable_for_replay_decisions"] = True
        self._write_matrix(matrix)
        self._assert_rejected(
            "archive.*(owns_replay_state|usable_for_replay_decisions)"
        )

    def test_archive_cannot_gain_generic_route_or_upgrade(self) -> None:
        matrix = self._matrix()
        matrix["archive"]["generic_routing"] = True
        matrix["archive"]["delegatecall"] = True
        matrix["archive"]["upgrade_path"] = True
        self._write_matrix(matrix)
        self._assert_rejected("archive.*(generic_routing|delegatecall|upgrade_path)")

    def test_implementation_stop_cannot_become_readiness_claim(self) -> None:
        matrix = self._matrix()
        matrix["implementation_stops"][-1] = "production ready"
        self._write_matrix(matrix)
        self._assert_rejected("selected architecture invariants drifted")


if __name__ == "__main__":
    unittest.main()
