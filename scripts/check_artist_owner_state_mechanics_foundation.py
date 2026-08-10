#!/usr/bin/env python3
"""Fail-closed checker for the proposed owner-state mechanics foundation."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any

from Crypto.Hash import keccak
from jsonschema import Draft202012Validator

PACKET_PATH = Path(
    "docs/architecture/artist-owner-state-mechanics-foundation-v1.json"
)
SCHEMA_PATH = Path(
    "docs/architecture/artist-owner-state-mechanics-foundation-v1.schema.json"
)
MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")
SHARED_PACKET_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json"
)

PACKET_SCHEMA = "6529stream.artist-owner-state-mechanics-foundation.v1"
PACKET_STATUS = "PROPOSED_FOUNDATION_ONLY"
PACKET_MATURITY = "pre_audit_source_blocked"
JSON_SCHEMA_ID = (
    "https://6529.io/schemas/artist-owner-state-mechanics-foundation-v1.schema.json"
)
EVALUATED_COMMIT = "40a09e7fa5fc3ab0deb350b86a5a5eb318359c3f"
EVALUATED_TREE = "c94ca72aa84e2924dedbd9b744353451cdceb1ee"
SCHEMA_SHA256 = "2c643f5a8fe67380481f64e107878a638866627ff86ba2ea6a20086577519550"

EXPECTED_AUTHORITY_BINDINGS = (
    ("adr_0023", "docs/adr/0023-modular-artist-authority-domain-ownership.md", "b3a7f322518aeb63638572486292be511f67202e09db58471ac867eb3fa8c113"),
    ("coordinator_source_gate", "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md", "df2f039ee0a8991cba38da084d2e41158bb857cfa005d8fcad45b30d592b727a"),
    ("semantic_owner_matrix", "docs/architecture/artist-semantic-owner-matrix-v2.json", "bc4b55c68c504ee7d74965d7fa0d1edbe6de816e567e076442781b81232320a2"),
    ("semantic_owner_matrix_schema", "docs/architecture/artist-semantic-owner-matrix-v2.schema.json", "b242c5480ecdf8e4aa57dc02d76fd8cd81631298eeda0b96cbba9b036d72b473"),
    ("semantic_owner_matrix_checker", "scripts/check_artist_semantic_owner_matrix.py", "75be5171655556711282de41a3feb909b0a9fdded45c565f66597d984427152b"),
    ("semantic_owner_matrix_tests", "scripts/test_artist_semantic_owner_matrix.py", "126269436e56b83f9e996b9b1e0961ebac08740a38a8e9789c70c302a8b0654f"),
    ("shared_mechanics_packet", "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json", "a631aed2a423a5aebb83e709151abe77cc2c5cc78c9354943b64e4b7a6116206"),
    ("shared_mechanics_schema", "docs/architecture/artist-operation-shared-mechanics-freeze-v1.schema.json", "d61b29f63c662494047fc1b30bf72035ab7d586a23fe45c2bb6f2d8a0ae795b0"),
    ("shared_mechanics_checker", "scripts/check_artist_operation_shared_mechanics_freeze.py", "d63f9e4193a9d8e382eaf994b69d4a5d1e3e5e402bb3d42c762f611e9eb77762"),
    ("shared_mechanics_tests", "scripts/test_artist_operation_shared_mechanics_freeze.py", "0dff4eefa8e110f36c17b08b24a38f557ef9893ef12ea2f8d5e00da7406da54f"),
    ("archive_v2_implementation", "smart-contracts/domains/artist/StreamArtistArchiveV2.sol", "1228ef5451258927b8141a842c437d4738f41fb66bbfff57e805919252552778"),
    ("archive_v2_interface", "smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol", "2e488c13527383b63864eb484203e2fed6349def941043ca9435cc728a29a80e"),
    ("registry_v2_implementation", "smart-contracts/domains/artist/StreamArtistRegistryV2.sol", "038560c0a8811b7ed4a816d011813d9c529e16091bd646f153c63390578a2430"),
    ("registry_v2_interface", "smart-contracts/interfaces/stream/IStreamArtistRegistryV2.sol", "6b56d095a7abdde99967c18ebef1c089ef91e9cff1c5477c2c1cc5d601059a54"),
)

EXPECTED_INVENTORIES = {
    "semantic_domains": (7, "5d98a25f0886abed544bbb686a213be978b8f1e055a1b7f55d6e457cc239289a"),
    "operations": (57, "50ce11e14d65ffcdc2b2756ee7a44fe26de1ec9a6930f29c9e102bbd0f450e87"),
    "replay_surfaces": (64, "1b3771b462e8c3a2453102718d4d68ee33d060a9e126ab33f87344f1b31128ba"),
    "record_surfaces": (37, "9ab9af1e2ac22c23f7521236e7628b76491993c7ebefa57d75e4c5b2deb0fa51"),
    "event_surfaces": (54, "93d3b7d3dd2368ff6b3a6466138b599e92e1c288ab62400fb188e336139475fc"),
}

EXPECTED_KIND_ENUM = (
    ("UNSET", 0),
    ("ONE_SHOT", 1),
    ("MONOTONIC_COUNTER", 2),
    ("CHAIN_HEAD", 3),
    ("PERMANENT_LATCH", 4),
    ("IMMUTABLE_BINDING", 5),
)
EXPECTED_STATUS_ENUM = (
    ("UNSET", 0),
    ("ACTIVE", 1),
    ("CONSUMED", 2),
    ("SUPERSEDED", 3),
    ("RETIRED", 4),
)
EXPECTED_PROHIBITED = (
    "external_calls_from_owner",
    "delegatecall",
    "proxy",
    "generic_upgrade",
    "mutable_rebind",
    "storage_gap",
    "generic_mutation",
    "replay_delete",
    "replay_reopen",
    "state_root_rewind",
    "record_chain_tip_rewind",
    "successful_no_op",
)
EXPECTED_UNRESOLVED = (
    "per_domain_structs",
    "per_domain_state_commitments",
    "per_surface_scope_commitments",
    "per_surface_replay_lifecycles",
    "action_commitment_schema",
    "record_commitment_schema",
    "construction_binding_preimage",
    "entrypoint_abi",
    "normative_owner_events",
    "provider_read_protocol",
    "role_and_signer_authority",
    "recipe_and_composite_manifest_commitments",
    "archive_evidence_protocol",
    "operation_lock_and_errors",
    "gas_and_call_discipline",
)
EXPECTED_GATE_STATE = {
    "outer_foundation_selected_for_review": True,
    "owner_storage_accepted": False,
    "owner_snapshots_accepted": False,
    "replay_keys_accepted": False,
    "all_domain_layouts_resolved": False,
    "all_replay_surfaces_resolved": False,
    "construction_binding_resolved": False,
    "shared_mechanics_modified": False,
    "interface_freeze_complete": False,
    "full_freeze_complete": False,
    "implementation_authorized": False,
    "source_present": False,
    "deployment_authorized": False,
    "readiness_credit": False,
}
EXPECTED_BOUNDS = {
    "operation_count": 57,
    "total_owner_actions": 85,
    "minimum_owner_actions_per_operation": 1,
    "maximum_owner_actions_per_operation": 5,
    "minimum_snapshots_per_operation": 1,
    "maximum_snapshots_per_operation": 7,
    "maximum_replay_writes_per_owner_action": 4,
    "maximum_record_writes_per_owner_action": 2,
    "unbounded_enumeration": False,
    "external_calls_from_owner": False,
}
EXPECTED_IDENTITY_FIELDS = [
    "domain_separator",
    "deployment_chain_id",
    "registry_address",
    "coordinator_address",
    "archive_v2_address",
    "owner_address",
    "domain_id",
]
EXPECTED_SNAPSHOT_DOMAIN = "6529STREAM_ARTIST_OWNER_SNAPSHOT_COMMITMENT_V2"
EXPECTED_SNAPSHOT_FAILURE = (
    "revert_on_unavailable_malformed_or_noncanonical_return"
)
EXPECTED_STATE_TRANSITION_DOMAIN = "6529STREAM_ARTIST_OWNER_STATE_TRANSITION_V2"
EXPECTED_RECORD_TRANSITION_DOMAIN = "6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"
EXPECTED_VECTOR_DOMAINS = {
    "replay_key": "6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2",
    "snapshot_commitment": EXPECTED_SNAPSHOT_DOMAIN,
    "genesis_state_root": "6529STREAM_ARTIST_OWNER_STATE_GENESIS_V2",
    "genesis_record_chain_tip": "6529STREAM_ARTIST_OWNER_RECORD_GENESIS_V2",
    "state_transition": EXPECTED_STATE_TRANSITION_DOMAIN,
    "record_transition": EXPECTED_RECORD_TRANSITION_DOMAIN,
}
EXPECTED_TOP_LEVEL = {
    "schema",
    "status",
    "maturity",
    "evaluated_base",
    "authority_bindings",
    "selected_foundation",
    "inventory_bindings",
    "common_storage_layout",
    "replay_cell",
    "snapshot_protocol",
    "genesis_protocol",
    "transition_protocol",
    "replay_key_protocol",
    "owner_side_recomputation",
    "canonical_vectors",
    "constant_work_bounds",
    "domain_layout_rows",
    "replay_surface_rows",
    "unresolved_dependencies",
    "prohibited_mechanics",
    "gate_state",
}


class FoundationError(RuntimeError):
    """Raised when the foundation packet drifts."""


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        if key in value:
            raise FoundationError(f"duplicate JSON member is forbidden: {key}")
        value[key] = item
    return value


def load_strict_json(path: Path) -> Any:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_reject_duplicates,
        )
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise FoundationError(f"cannot read strict JSON {path}: {exc}") from exc


def _canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _safe_path(root: Path, relative: str) -> Path:
    pure = PurePosixPath(relative)
    if (
        pure.is_absolute()
        or not pure.parts
        or any(part in ("", ".", "..") for part in pure.parts)
        or "\\" in relative
    ):
        raise FoundationError(f"unsafe authority path: {relative}")
    target = (root / Path(*pure.parts)).resolve()
    try:
        target.relative_to(root.resolve())
    except ValueError as exc:
        raise FoundationError(f"authority path escapes repository: {relative}") from exc
    return target


def _keccak(data: bytes) -> bytes:
    digest = keccak.new(digest_bits=256)
    digest.update(data)
    return digest.digest()


def _word_uint(value: int) -> bytes:
    if value < 0 or value >= 1 << 256:
        raise FoundationError("canonical vector uint256 is out of range")
    return value.to_bytes(32, "big")


def _word_address(value: str) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x") or len(value) != 42:
        raise FoundationError("canonical vector address is malformed")
    try:
        return bytes.fromhex(value[2:]).rjust(32, b"\0")
    except ValueError as exc:
        raise FoundationError("canonical vector address is malformed") from exc


def _word_bytes32(value: str) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x") or len(value) != 66:
        raise FoundationError("canonical vector bytes32 is malformed")
    try:
        return bytes.fromhex(value[2:])
    except ValueError as exc:
        raise FoundationError("canonical vector bytes32 is malformed") from exc


def _check_meta(packet: dict[str, Any], schema: dict[str, Any], schema_path: Path) -> None:
    if set(packet) != EXPECTED_TOP_LEVEL:
        raise FoundationError("packet top-level fields drifted")
    if packet["schema"] != PACKET_SCHEMA:
        raise FoundationError("packet schema id drifted")
    if packet["status"] != PACKET_STATUS:
        raise FoundationError("packet status drifted")
    if packet["maturity"] != PACKET_MATURITY:
        raise FoundationError("packet maturity drifted")
    base = packet["evaluated_base"]
    if base != {
        "commit": EVALUATED_COMMIT,
        "tree": EVALUATED_TREE,
        "shared_mechanics_accepted_count": 3,
        "shared_mechanics_unresolved_count": 16,
    }:
        raise FoundationError("evaluated base or shared-mechanics counts drifted")
    if schema.get("$schema") != "https://json-schema.org/draft/2020-12/schema":
        raise FoundationError("schema dialect drifted")
    if schema.get("$id") != JSON_SCHEMA_ID:
        raise FoundationError("schema id drifted")
    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:
        raise FoundationError(f"schema is not valid Draft 2020-12: {exc}") from exc
    observed = hashlib.sha256(schema_path.read_bytes()).hexdigest()
    if observed != SCHEMA_SHA256:
        raise FoundationError(f"schema sha256 drifted: {observed}")
    errors = sorted(
        Draft202012Validator(schema).iter_errors(packet),
        key=lambda item: tuple(str(part) for part in item.absolute_path),
    )
    if errors:
        first = errors[0]
        location = "/".join(str(part) for part in first.absolute_path) or "<root>"
        raise FoundationError(f"schema violation at {location}: {first.message}")


def _check_authorities(root: Path, packet: dict[str, Any]) -> None:
    observed = tuple(
        (row.get("id"), row.get("path"), row.get("sha256"))
        for row in packet["authority_bindings"]
    )
    if observed != EXPECTED_AUTHORITY_BINDINGS:
        raise FoundationError("authority binding inventory or order drifted")
    for authority_id, relative, expected_digest in EXPECTED_AUTHORITY_BINDINGS:
        target = _safe_path(root, relative)
        try:
            actual = hashlib.sha256(target.read_bytes()).hexdigest()
        except OSError as exc:
            raise FoundationError(f"cannot read authority {authority_id}: {exc}") from exc
        if actual != expected_digest:
            raise FoundationError(
                f"authority {authority_id} sha256 drifted: {actual}"
            )


def _check_inventory(packet: dict[str, Any], matrix: dict[str, Any]) -> None:
    bindings = packet["inventory_bindings"]
    if tuple(bindings) != tuple(EXPECTED_INVENTORIES):
        raise FoundationError("inventory binding order drifted")
    for key, (count, digest) in EXPECTED_INVENTORIES.items():
        rows = matrix.get(key)
        if not isinstance(rows, list):
            raise FoundationError(f"matrix {key} inventory is not a list")
        actual_digest = _canonical_digest(rows)
        if len(rows) != count or actual_digest != digest:
            raise FoundationError(f"matrix {key} inventory drifted")
        if bindings[key] != {"count": count, "canonical_sha256": digest}:
            raise FoundationError(f"packet {key} inventory binding drifted")


def _check_selected_shape(packet: dict[str, Any]) -> None:
    selected = packet["selected_foundation"]
    if set(selected) != {"option_id", "selection_posture", "rationale", "rejected_options"}:
        raise FoundationError("selected foundation fields drifted")
    if selected.get("option_id") != "lean_typed_mapping_transition_accumulator_v1":
        raise FoundationError("selected foundation option drifted")
    if selected.get("selection_posture") != "outer_mechanics_only_no_decision_acceptance":
        raise FoundationError("selection posture drifted")
    alternatives = tuple(
        (row.get("option_id"), row.get("disposition"))
        for row in selected.get("rejected_options", [])
    )
    if alternatives != (
        ("generic_hash_only_envelopes", "rejected"),
        ("sparse_merkle_tree_for_all_state", "rejected"),
        ("full_append_only_owner_log", "rejected"),
        ("premature_full_hybrid_acceptance", "rejected"),
    ):
        raise FoundationError("alternative dispositions drifted")
    if selected.get("rationale") != [
        "typed isolated storage preserves exactly one authoritative owner per semantic domain",
        "immutable deployment-chain, Registry, Coordinator, ArchiveV2 and domain identity prevents cross-suite or cross-chain rekeying",
        "a fixed header, roots and replay mapping bound constant work without exposing generic mutation",
        "history-sensitive owner-recomputed accumulators make rollback, opaque-input and no-op drift observable while ArchiveV2 remains evidence-only",
    ]:
        raise FoundationError("selected foundation rationale drifted")
    expected_reasons = (
        "does not freeze typed storage ownership or replay capabilities and can conceal incompatible domain state",
        "adds proof, gas and denial-of-service complexity without an accepted proof-consumer requirement",
        "unbounded owner-local history and enumeration duplicate ArchiveV2 evidence responsibilities",
        "would invent unresolved domain structs, replay scopes, lifecycle assignments, commitments and construction preimages",
    )
    if tuple(row.get("reason") for row in selected["rejected_options"]) != expected_reasons:
        raise FoundationError("alternative rationale drifted")
    if any(set(row) != {"option_id", "disposition", "reason"} for row in selected["rejected_options"]):
        raise FoundationError("alternative fields drifted")


def _check_storage(packet: dict[str, Any]) -> None:
    layout = packet["common_storage_layout"]
    if set(layout) != {
        "slots", "typed_domain_state_start_slot", "immutable_binding_fields",
        "owner_address_binding", "deployment_chain_id_source",
        "live_block_chainid_forbidden", "mutation_authority", "storage_gap_slots",
        "proxy_or_upgrade_storage", "generic_mutation_storage",
    }:
        raise FoundationError("common storage fields drifted")
    slots = layout.get("slots")
    if not isinstance(slots, list) or len(slots) != 4:
        raise FoundationError("common storage slot inventory drifted")
    if [(row.get("slot"), row.get("label"), row.get("solidity_type")) for row in slots] != [
        (0, "header", "OwnerHeaderV2"),
        (1, "stateRoot", "bytes32"),
        (2, "recordChainTip", "bytes32"),
        (3, "replay", "mapping(bytes32 => ReplayCellV2)"),
    ]:
        raise FoundationError("common storage slot order or type drifted")
    header = slots[0]
    if header.get("packing") != "single_slot" or header.get("reserved_high_bits") != 128:
        raise FoundationError("OwnerHeaderV2 packing drifted")
    if header.get("fields") != [
        {"name": "revision", "type": "uint64", "bit_offset": 0, "bit_width": 64},
        {"name": "recordSequence", "type": "uint64", "bit_offset": 64, "bit_width": 64},
    ]:
        raise FoundationError("OwnerHeaderV2 fields drifted")
    if layout.get("typed_domain_state_start_slot") != 4:
        raise FoundationError("typed domain state start slot drifted")
    if layout.get("immutable_binding_fields") != [
        "deploymentChainId", "registry", "coordinator", "archiveV2", "domainId"
    ]:
        raise FoundationError("immutable owner binding fields drifted")
    if layout.get("owner_address_binding") != "address_this_in_every_outer_commitment":
        raise FoundationError("owner address commitment binding drifted")
    if layout.get("deployment_chain_id_source") != "constructor_captured_immutable":
        raise FoundationError("deploymentChainId source drifted")
    if layout.get("live_block_chainid_forbidden") is not True:
        raise FoundationError("live block.chainid use is forbidden")
    if layout.get("mutation_authority") != "immutable_coordinator_only":
        raise FoundationError("owner mutation authority drifted")
    if (
        layout.get("storage_gap_slots") != 0
        or layout.get("proxy_or_upgrade_storage") is not False
        or layout.get("generic_mutation_storage") is not False
    ):
        raise FoundationError("upgrade, gap, or generic storage was introduced")

    cell = packet["replay_cell"]
    if set(cell) != {
        "solidity_type", "mapping_key_type", "fields", "replay_kind_enum",
        "replay_status_enum", "capability_only", "per_surface_assignment_frozen",
    }:
        raise FoundationError("ReplayCellV2 fields inventory drifted")
    if cell.get("solidity_type") != "ReplayCellV2" or cell.get("mapping_key_type") != "bytes32":
        raise FoundationError("ReplayCellV2 identity drifted")
    if cell.get("fields") != [
        {"name": "commitment", "type": "bytes32", "slot_offset": 0},
        {"name": "touchedRevision", "type": "uint64", "slot_offset": 1, "bit_offset": 0},
        {"name": "kind", "type": "ReplayKindV2", "slot_offset": 1, "bit_offset": 64},
        {"name": "status", "type": "ReplayStatusV2", "slot_offset": 1, "bit_offset": 72},
    ]:
        raise FoundationError("ReplayCellV2 fields drifted")
    kinds = tuple((row.get("name"), row.get("value")) for row in cell["replay_kind_enum"])
    statuses = tuple((row.get("name"), row.get("value")) for row in cell["replay_status_enum"])
    if kinds != EXPECTED_KIND_ENUM or statuses != EXPECTED_STATUS_ENUM:
        raise FoundationError("ReplayKindV2 or ReplayStatusV2 enum drifted")
    if cell.get("capability_only") is not True or cell.get("per_surface_assignment_frozen") is not False:
        raise FoundationError("replay capability was presented as a surface assignment")


def _check_protocols(packet: dict[str, Any]) -> None:
    snapshot = packet["snapshot_protocol"]
    if set(snapshot) != {
        "function_signature", "state_mutability", "return_fields",
        "commitment_domain", "commitment_encoding", "commitment_fields",
        "runtime_codehash_commitment", "failure_semantics",
    }:
        raise FoundationError("snapshot protocol fields drifted")
    if snapshot.get("function_signature") != "ownerStateSnapshotV2()":
        raise FoundationError("snapshot signature drifted")
    if snapshot.get("state_mutability") != "view":
        raise FoundationError("snapshot mutability drifted")
    if snapshot.get("commitment_domain") != EXPECTED_SNAPSHOT_DOMAIN:
        raise FoundationError("snapshot commitment domain drifted")
    if snapshot.get("failure_semantics") != EXPECTED_SNAPSHOT_FAILURE:
        raise FoundationError("snapshot failure semantics drifted")
    if snapshot.get("return_fields") != [
        {"position": 0, "name": "domainId", "type": "bytes32"},
        {"position": 1, "name": "revision", "type": "uint64"},
        {"position": 2, "name": "stateRoot", "type": "bytes32"},
        {"position": 3, "name": "recordChainTip", "type": "bytes32"},
    ]:
        raise FoundationError("four-field snapshot ABI drifted")
    if snapshot.get("commitment_encoding") != "abi.encode":
        raise FoundationError("snapshot commitment must use abi.encode")
    if snapshot.get("runtime_codehash_commitment") is not None:
        raise FoundationError("opaque Coordinator runtime commitment is forbidden")
    if snapshot.get("commitment_fields") != [
        *EXPECTED_IDENTITY_FIELDS, "revision", "state_root", "record_chain_tip"
    ]:
        raise FoundationError("snapshot commitment envelope drifted")

    genesis = packet["genesis_protocol"]
    if genesis != {
        "revision": 0,
        "record_sequence": 0,
        "state_root_domain": "6529STREAM_ARTIST_OWNER_STATE_GENESIS_V2",
        "record_chain_tip_domain": "6529STREAM_ARTIST_OWNER_RECORD_GENESIS_V2",
        "encoding": "abi.encode",
        "ordered_fields": EXPECTED_IDENTITY_FIELDS,
        "require_nonzero_state_root": True,
        "require_nonzero_record_chain_tip": True,
    }:
        raise FoundationError("nonzero identity-bound genesis protocol drifted")

    transition = packet["transition_protocol"]
    if set(transition) != {
        "checked_revision_increment", "revision_increment_frequency",
        "checked_record_sequence_increment", "overflow_behavior",
        "failure_semantics", "state_transition_domain",
        "state_transition_encoding", "state_transition_fields",
        "record_transition_domain", "record_transition_encoding",
        "record_transition_fields", "history_sensitive",
        "no_op_success_forbidden", "root_rewind_forbidden",
        "record_chain_tip_rewind_forbidden",
        "replay_delete_forbidden", "replay_reopen_forbidden",
    }:
        raise FoundationError("transition protocol fields drifted")
    if transition.get("checked_revision_increment") != 1:
        raise FoundationError("checked revision increment drifted")
    if transition.get("revision_increment_frequency") != "exactly_once_per_successful_owner_action":
        raise FoundationError("revision increment frequency drifted")
    if transition.get("checked_record_sequence_increment") != "exact_record_count_zero_to_two_per_successful_owner_action":
        raise FoundationError("record-sequence increment drifted")
    if transition.get("overflow_behavior") != "revert":
        raise FoundationError("checked counter overflow behavior drifted")
    if transition.get("failure_semantics") != "any_failure_reverts_header_roots_replay_domain_state_records_and_events":
        raise FoundationError("owner action rollback semantics drifted")
    if transition.get("state_transition_domain") != EXPECTED_STATE_TRANSITION_DOMAIN:
        raise FoundationError("state transition domain drifted")
    if transition.get("record_transition_domain") != EXPECTED_RECORD_TRANSITION_DOMAIN:
        raise FoundationError("record transition domain drifted")
    if transition.get("state_transition_encoding") != "abi.encode" or transition.get("record_transition_encoding") != "abi.encode":
        raise FoundationError("packed transition encoding is forbidden")
    required_state_fields = [
        *EXPECTED_IDENTITY_FIELDS, "prior_revision", "next_revision",
        "prior_state_root", "action_commitment", "next_domain_state_commitment",
        "replay_delta_commitment", "record_delta_commitment",
    ]
    required_record_fields = [
        *EXPECTED_IDENTITY_FIELDS, "prior_record_sequence",
        "next_record_sequence", "prior_record_chain_tip", "record_commitment",
    ]
    if transition.get("state_transition_fields") != required_state_fields:
        raise FoundationError("history-sensitive state-transition envelope drifted")
    if transition.get("record_transition_fields") != required_record_fields:
        raise FoundationError("history-sensitive record-transition envelope drifted")
    for key in (
        "history_sensitive",
        "no_op_success_forbidden",
        "root_rewind_forbidden",
        "record_chain_tip_rewind_forbidden",
        "replay_delete_forbidden",
        "replay_reopen_forbidden",
    ):
        if transition.get(key) is not True:
            raise FoundationError(f"transition prohibition drifted: {key}")

    replay = packet["replay_key_protocol"]
    if replay != {
        "domain": "6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2",
        "encoding": "abi.encode",
        "ordered_fields": [*EXPECTED_IDENTITY_FIELDS, "surface_id", "scope_commitment"],
        "scope_commitment_type": "bytes32",
        "scope_commitment_schema": None,
        "per_surface_scope_frozen": False,
        "lifecycle_assignment_frozen": False,
    }:
        raise FoundationError("outer replay-key protocol or unresolved scope drifted")

    if tuple(packet["prohibited_mechanics"]) != EXPECTED_PROHIBITED:
        raise FoundationError("prohibited mechanics inventory drifted")


def _check_owner_recomputation(packet: dict[str, Any]) -> None:
    expected = {
        "compute_location": "inside_typed_owner",
        "mandatory_inputs": [
            "accepted_recipe_identity",
            "accepted_action_identity",
            "original_caller",
            "exact_typed_calldata",
            "prior_owner_storage",
            "actual_replay_transitions",
            "actual_record_transitions",
        ],
        "computed_outputs": [
            "action_commitment",
            "next_domain_state_commitment",
            "replay_delta_commitment",
            "record_delta_commitment",
        ],
        "coordinator_supplied_commitment_words_allowed": False,
        "external_supplied_commitment_words_allowed": False,
        "action_commitment_preimage": None,
        "domain_state_commitment_preimage": None,
        "replay_delta_commitment_preimage": None,
        "record_delta_commitment_preimage": None,
        "exact_inner_preimages_resolved": False,
        "source_blocking": True,
    }
    if packet["owner_side_recomputation"] != expected:
        raise FoundationError(
            "typed owner-side commitment recomputation invariant drifted"
        )


def _identity_words(identity: dict[str, Any]) -> tuple[bytes, ...]:
    try:
        deployment_chain_id = int(identity["deployment_chain_id"], 10)
    except (KeyError, TypeError, ValueError) as exc:
        raise FoundationError("vector deploymentChainId is malformed") from exc
    if set(identity) != {
        "deployment_chain_id", "registry_address", "coordinator_address",
        "archive_v2_address", "owner_address", "domain_id",
    }:
        raise FoundationError("vector immutable identity fields drifted")
    if identity != {
        "deployment_chain_id": "1",
        "registry_address": "0x1111111111111111111111111111111111111111",
        "coordinator_address": "0x2222222222222222222222222222222222222222",
        "archive_v2_address": "0x3333333333333333333333333333333333333333",
        "owner_address": "0x4444444444444444444444444444444444444444",
        "domain_id": "0x5555555555555555555555555555555555555555555555555555555555555555",
    }:
        raise FoundationError("vector immutable identity fixture drifted")
    return (
        _word_uint(deployment_chain_id),
        _word_address(identity["registry_address"]),
        _word_address(identity["coordinator_address"]),
        _word_address(identity["archive_v2_address"]),
        _word_address(identity["owner_address"]),
        _word_bytes32(identity["domain_id"]),
    )


def _check_one_vector(
    vector_id: str,
    vector: dict[str, Any],
    identity_words: tuple[bytes, ...],
    expected_domain: str,
    input_fields: tuple[tuple[str, str], ...],
) -> None:
    if set(vector) != {
        "domain", "domain_separator_keccak256", "inputs", "expected_commitment"
    }:
        raise FoundationError(f"{vector_id} vector fields drifted")
    if vector.get("domain") != expected_domain:
        raise FoundationError(f"{vector_id} vector domain drifted")
    inputs = vector.get("inputs")
    if not isinstance(inputs, dict) or tuple(inputs) != tuple(name for name, _ in input_fields):
        raise FoundationError(f"{vector_id} vector input order drifted")
    words: list[bytes] = list(identity_words)
    for name, kind in input_fields:
        value = inputs[name]
        if kind == "uint":
            try:
                words.append(_word_uint(int(value, 10)))
            except (TypeError, ValueError) as exc:
                raise FoundationError(f"{vector_id} vector uint is malformed") from exc
        elif kind == "bytes32":
            words.append(_word_bytes32(value))
        else:
            raise FoundationError(f"{vector_id} vector type is unsupported")
    separator = _keccak(expected_domain.encode("ascii"))
    expected = _keccak(separator + b"".join(words))
    if vector.get("domain_separator_keccak256") != "0x" + separator.hex():
        raise FoundationError(f"{vector_id} vector domain separator drifted")
    if vector.get("expected_commitment") != "0x" + expected.hex():
        raise FoundationError(f"{vector_id} vector commitment drifted")


def _check_vectors(packet: dict[str, Any]) -> None:
    fixture = packet["canonical_vectors"]
    if set(fixture) != {
        "fixture_scope", "fixture_identity",
        "inner_commitment_fixture_words_resolve_schemas", "vectors",
    }:
        raise FoundationError("canonical vector fixture fields drifted")
    if fixture.get("fixture_scope") != (
        "outer_mechanics_only_inner_commitment_words_are_not_accepted_preimages"
    ):
        raise FoundationError("canonical vectors overstate their fixture scope")
    if fixture.get("inner_commitment_fixture_words_resolve_schemas") is not False:
        raise FoundationError("canonical vectors prematurely resolve inner schemas")
    identity_words = _identity_words(fixture["fixture_identity"])
    vectors = fixture.get("vectors")
    expected_order = (
        "replay_key", "snapshot_commitment", "genesis_state_root",
        "genesis_record_chain_tip", "state_transition", "record_transition",
    )
    if not isinstance(vectors, dict) or tuple(vectors) != expected_order:
        raise FoundationError("canonical vector inventory or order drifted")
    protocol_domains = {
        "replay_key": packet["replay_key_protocol"]["domain"],
        "snapshot_commitment": packet["snapshot_protocol"]["commitment_domain"],
        "genesis_state_root": packet["genesis_protocol"]["state_root_domain"],
        "genesis_record_chain_tip": packet["genesis_protocol"][
            "record_chain_tip_domain"
        ],
        "state_transition": packet["transition_protocol"][
            "state_transition_domain"
        ],
        "record_transition": packet["transition_protocol"][
            "record_transition_domain"
        ],
    }
    if protocol_domains != EXPECTED_VECTOR_DOMAINS:
        raise FoundationError("protocol domain inventory drifted from vector constants")
    for vector_id in EXPECTED_VECTOR_DOMAINS:
        if vectors[vector_id].get("domain") != protocol_domains[vector_id]:
            raise FoundationError(f"{vector_id} vector-to-protocol domain drifted")
    specs = {
        "replay_key": (
            EXPECTED_VECTOR_DOMAINS["replay_key"],
            (("surface_id", "bytes32"), ("scope_commitment", "bytes32")),
        ),
        "snapshot_commitment": (
            EXPECTED_VECTOR_DOMAINS["snapshot_commitment"],
            (("revision", "uint"), ("state_root", "bytes32"),
             ("record_chain_tip", "bytes32")),
        ),
        "genesis_state_root": (
            EXPECTED_VECTOR_DOMAINS["genesis_state_root"], (),
        ),
        "genesis_record_chain_tip": (
            EXPECTED_VECTOR_DOMAINS["genesis_record_chain_tip"], (),
        ),
        "state_transition": (
            EXPECTED_VECTOR_DOMAINS["state_transition"],
            (("prior_revision", "uint"), ("next_revision", "uint"),
             ("prior_state_root", "bytes32"), ("action_commitment", "bytes32"),
             ("next_domain_state_commitment", "bytes32"),
             ("replay_delta_commitment", "bytes32"),
             ("record_delta_commitment", "bytes32")),
        ),
        "record_transition": (
            EXPECTED_VECTOR_DOMAINS["record_transition"],
            (("prior_record_sequence", "uint"),
             ("next_record_sequence", "uint"),
             ("prior_record_chain_tip", "bytes32"),
             ("record_commitment", "bytes32")),
        ),
    }
    for vector_id in expected_order:
        domain, fields = specs[vector_id]
        _check_one_vector(vector_id, vectors[vector_id], identity_words, domain, fields)


def _derive_bounds(matrix: dict[str, Any]) -> dict[str, Any]:
    actions_per_operation: list[int] = []
    snapshots_per_operation: list[int] = []
    replay_writes: list[int] = []
    record_writes: list[int] = []
    for operation in matrix["operations"]:
        recipe = operation.get("coordinator_recipe")
        if not isinstance(recipe, dict):
            raise FoundationError("matrix operation recipe is malformed")
        actions = recipe.get("actions")
        snapshots = recipe.get("snapshot_ids")
        if not isinstance(actions, list) or not isinstance(snapshots, list):
            raise FoundationError("matrix operation action or snapshot inventory is malformed")
        actions_per_operation.append(len(actions))
        snapshots_per_operation.append(len(snapshots))
        for action in actions:
            writes = action.get("write_surfaces")
            if not isinstance(writes, list):
                raise FoundationError("matrix action write surface inventory is malformed")
            replay_writes.append(sum(item.startswith("replay:") for item in writes))
            record_writes.append(sum(item.startswith("record:") for item in writes))
    return {
        "operation_count": len(matrix["operations"]),
        "total_owner_actions": sum(actions_per_operation),
        "minimum_owner_actions_per_operation": min(actions_per_operation),
        "maximum_owner_actions_per_operation": max(actions_per_operation),
        "minimum_snapshots_per_operation": min(snapshots_per_operation),
        "maximum_snapshots_per_operation": max(snapshots_per_operation),
        "maximum_replay_writes_per_owner_action": max(replay_writes),
        "maximum_record_writes_per_owner_action": max(record_writes),
        "unbounded_enumeration": False,
        "external_calls_from_owner": False,
    }


def _check_rows(packet: dict[str, Any], matrix: dict[str, Any]) -> None:
    expected_domains = [
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
        for row in matrix["semantic_domains"]
    ]
    if packet["domain_layout_rows"] != expected_domains:
        raise FoundationError("seven unresolved domain layout rows drifted")

    expected_replay = [
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
        for row in matrix["replay_surfaces"]
    ]
    if packet["replay_surface_rows"] != expected_replay:
        raise FoundationError("64 unresolved replay rows drifted")

    dependencies = packet["unresolved_dependencies"]
    if tuple(row.get("id") for row in dependencies) != EXPECTED_UNRESOLVED:
        raise FoundationError("unresolved dependency inventory or order drifted")
    if any(row.get("value") is not None or row.get("source_blocking") is not True for row in dependencies):
        raise FoundationError("unresolved dependency was assigned or unblocked")


def _check_gate_and_shared(packet: dict[str, Any], shared: dict[str, Any], matrix: dict[str, Any]) -> None:
    if packet["gate_state"] != EXPECTED_GATE_STATE:
        raise FoundationError("premature acceptance, source, deployment, or readiness state")
    if _derive_bounds(matrix) != EXPECTED_BOUNDS:
        raise FoundationError("matrix-derived constant-work bounds drifted")
    if packet["constant_work_bounds"] != EXPECTED_BOUNDS:
        raise FoundationError("packet constant-work bounds drifted")
    if shared.get("gate_state", {}).get("accepted_decision_count") != 3:
        raise FoundationError("shared-mechanics accepted count drifted")
    if shared.get("gate_state", {}).get("unresolved_decision_count") != 16:
        raise FoundationError("shared-mechanics unresolved count drifted")
    accepted = [
        row.get("surface_id")
        for row in shared.get("decision_rows", [])
        if row.get("decision_status") == "accepted"
    ]
    if accepted != ["registry_ingress", "original_caller", "native_value"]:
        raise FoundationError("shared-mechanics accepted decision identity drifted")
    for key in (
        "interface_and_storage_freeze_complete",
        "implementation_authorized",
        "coordinator_source_present",
        "semantic_owner_sources_present",
        "stateless_validator_source_present",
    ):
        if shared.get("gate_state", {}).get(key) is not False:
            raise FoundationError(f"shared-mechanics global gate drifted: {key}")
    projection = shared.get("operation_projection")
    if not isinstance(projection, dict) or projection.get("operation_count") != 57:
        raise FoundationError("shared-mechanics operation projection count drifted")
    if projection.get("implementation_authorized") is not False or projection.get("source_present") is not False:
        raise FoundationError("shared-mechanics operation source/auth drifted")
    for operation in matrix.get("operations", []):
        requirements = operation.get("source_requirements", {})
        if requirements.get("source_present") is not False or requirements.get("implementation_authorized") is not False:
            raise FoundationError("matrix operation source/auth drifted")
    if projection.get("operation_22_effective_stop") != "FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN":
        raise FoundationError("operation 22 implementation stop drifted")


def check(root: Path) -> dict[str, int]:
    root = root.resolve()
    packet_path = root / PACKET_PATH
    schema_path = root / SCHEMA_PATH
    packet = load_strict_json(packet_path)
    schema = load_strict_json(schema_path)
    matrix = load_strict_json(root / MATRIX_PATH)
    shared = load_strict_json(root / SHARED_PACKET_PATH)
    if not all(isinstance(item, dict) for item in (packet, schema, matrix, shared)):
        raise FoundationError("packet, schema, matrix and shared register must be objects")
    _check_meta(packet, schema, schema_path)
    _check_authorities(root, packet)
    _check_inventory(packet, matrix)
    _check_selected_shape(packet)
    _check_storage(packet)
    _check_protocols(packet)
    _check_owner_recomputation(packet)
    _check_vectors(packet)
    _check_rows(packet, matrix)
    _check_gate_and_shared(packet, shared, matrix)
    return {
        "authority_bindings": len(packet["authority_bindings"]),
        "semantic_domains": len(packet["domain_layout_rows"]),
        "replay_surfaces": len(packet["replay_surface_rows"]),
        "operations": len(matrix["operations"]),
        "record_surfaces": len(matrix["record_surfaces"]),
        "event_surfaces": len(matrix["event_surfaces"]),
        "accepted_domain_layouts": 0,
        "accepted_replay_surfaces": 0,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        counts = check(args.root)
    except FoundationError as exc:
        print(f"artist owner-state mechanics foundation check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "artist owner-state mechanics foundation check passed: "
        f"{counts['authority_bindings']} authorities, "
        f"{counts['semantic_domains']} unresolved domains, "
        f"{counts['replay_surfaces']} unresolved replay surfaces, "
        f"{counts['operations']} operations, "
        f"{counts['record_surfaces']} records, {counts['event_surfaces']} events, "
        "0 accepted layouts, 0 accepted replay surfaces"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
