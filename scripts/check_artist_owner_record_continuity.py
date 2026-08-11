#!/usr/bin/env python3
"""Fail-closed checker for the proposed dual owner-record continuity prerequisite."""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path, PurePosixPath
from typing import Any

from Crypto.Hash import keccak
from jsonschema import Draft202012Validator

PACKET_PATH = Path("docs/architecture/artist-owner-record-continuity-v1.json")
SCHEMA_PATH = Path("docs/architecture/artist-owner-record-continuity-v1.schema.json")
FOUNDATION_PATH = Path(
    "docs/architecture/artist-owner-state-mechanics-foundation-v1.json"
)
CORRECTION_PATH = Path(
    "docs/architecture/artist-record-event-reconstruction-correction-v1.json"
)
SHARED_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json"
)
MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")

PACKET_SCHEMA = "6529stream.artist-owner-record-continuity.v1"
PACKET_STATUS = "PROPOSED_RECORD_CONTINUITY_PREREQUISITE"
PACKET_MATURITY = "pre_audit_source_blocked"
SCHEMA_ID = "https://6529.io/schemas/artist-owner-record-continuity-v1.schema.json"
EVALUATED_COMMIT = "501d63499f97586ff9fd5128ec63e9c8489eea1f"
EVALUATED_TREE = "75cacef8a99201b33ae17a7987ac34201bef305f"
SCHEMA_SHA256 = "2c665c57e677e266eb139ad3fb9aeaa63b83f0e3204ed59d10d964052f7dfac5"
SEMANTIC_DIGEST = "sha256:d146f6454951437e579cf4a9fa109a3c8c185d1cd3ece279dac522a027d5d6dd"

EXPECTED_AUTHORITY_BINDINGS = (
    (
        "adr_0023",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md",
        "b3a7f322518aeb63638572486292be511f67202e09db58471ac867eb3fa8c113",
    ),
    (
        "owner_state_foundation",
        "docs/architecture/artist-owner-state-mechanics-foundation-v1.json",
        "94fde0bdb326920a2528fbf0cb7f3f4923421915be53fadbb2aaf1c8e360ee91",
    ),
    (
        "record_event_correction",
        "docs/architecture/artist-record-event-reconstruction-correction-v1.json",
        "e6df09205c1bfd7a4a74301c794d8d67cbd68fa8c1b2f6f97ecb06046ac853af",
    ),
    (
        "shared_mechanics",
        "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json",
        "a631aed2a423a5aebb83e709151abe77cc2c5cc78c9354943b64e4b7a6116206",
    ),
    (
        "semantic_owner_matrix",
        "docs/architecture/artist-semantic-owner-matrix-v2.json",
        "bc4b55c68c504ee7d74965d7fa0d1edbe6de816e567e076442781b81232320a2",
    ),
    (
        "archive_v2_implementation",
        "smart-contracts/domains/artist/StreamArtistArchiveV2.sol",
        "1228ef5451258927b8141a842c437d4738f41fb66bbfff57e805919252552778",
    ),
    (
        "archive_v2_interface",
        "smart-contracts/interfaces/stream/IStreamArtistArchiveV2.sol",
        "2e488c13527383b63864eb484203e2fed6349def941043ca9435cc728a29a80e",
    ),
    (
        "registry_v2_implementation",
        "smart-contracts/domains/artist/StreamArtistRegistryV2.sol",
        "038560c0a8811b7ed4a816d011813d9c529e16091bd646f153c63390578a2430",
    ),
    (
        "registry_v2_interface",
        "smart-contracts/interfaces/stream/IStreamArtistRegistryV2.sol",
        "6b56d095a7abdde99967c18ebef1c089ef91e9cff1c5477c2c1cc5d601059a54",
    ),
)

EXPECTED_INVENTORIES = {
    "record_domains": (
        37,
        "surface_id,record_domain,owner_domain,owner_contract,domain_value",
        "1a369e03eedbbafad6c6619eea58ec977c2d4b670cc7c8bddc72ffacc42542d6",
    ),
    "created_records": (
        40,
        "operation_id,write,role,record_domain,owner_domain",
        "bdcf66619a8752e6e8a8b170c2947ebddc29f21ff27e413e9fafe341ebd9458b",
    ),
    "owner_record_batches": (
        39,
        "operation_id,write,owner_domain,ordered_role_and_record_domain_pairs",
        "ec324319dcb6a8628ef8db3151585d5c72a1b3ca20e1950cd6b80a06eb4ce139",
    ),
    "owner_domains": (
        7,
        "domain_id,owner_contract,storage_namespace",
        "bf85166627a5e73687bbd0b8ff0e9f9ea0bf7e7288e8312b87bdc846f9f7c7ba",
    ),
}

EXPECTED_OWNER_DOMAINS = (
    (
        "binding_lifecycle",
        "6529stream.artist.binding-lifecycle.v2",
        "0xbaafb92238e6c08a1640858ae21979e8c328eab49e99507986e767f041094eb2",
    ),
    (
        "collaborator_lifecycle",
        "6529stream.artist.collaborator-lifecycle.v2",
        "0x5dad6e369eefadf15aa44cee330e69b9c2380798a8f5582493b7a4e59f2365f0",
    ),
    (
        "identity_authority",
        "6529stream.artist.identity-authority.v2",
        "0x1b0dd53dfa76f8d43a27b96148dae3ebe0609a01dfd55dedacf1fb71c51bfba3",
    ),
    (
        "acceptance_lifecycle",
        "6529stream.artist.acceptance-lifecycle.v2",
        "0x57a9434ee33b95b85a6552b9fc2fef4af9843e9e6c4a9dc1a527037955c79ad6",
    ),
    (
        "attribution_lifecycle",
        "6529stream.artist.attribution-lifecycle.v2",
        "0xf9c6e034436285d64b39abb3b388bdaeb9d80a4561c4cb23ba2bf6f6231ab45a",
    ),
    (
        "payout_lifecycle",
        "6529stream.artist.payout-lifecycle.v2",
        "0xe642144c68650878eddff1994d4629c8504455a418494d0858f4d32dcb655a3a",
    ),
    (
        "consent_finality",
        "6529stream.artist.consent-finality.v2",
        "0xd88ac7b3633026f3ea2643af4b4ddbe6b9b7ff82226a907d41511b96f745c169",
    ),
)

OWNER_RECORD_DOMAIN = "6529STREAM_ARTIST_OWNER_RECORD_COMMITMENT_V2"
OWNER_RECORD_DOMAIN_HASH = (
    "0x2524f38d4b0732cdfa0810161b89161cfa6da3e7cc1b6cab90fd8b71fbfbd861"
)
RECORD_DELTA_DOMAIN = "6529STREAM_ARTIST_OWNER_RECORD_DELTA_V2"
RECORD_DELTA_DOMAIN_HASH = (
    "0x8ffc87ac7a69cf11f845f37d440821760d42d49ad78aa90d3b437aca24cdba4e"
)
RECORD_TRANSITION_DOMAIN = "6529STREAM_ARTIST_OWNER_RECORD_TRANSITION_V2"
RECORD_TRANSITION_DOMAIN_HASH = (
    "0xee9923a60ff96c9c573fe0297f13dd797f0879da0f711079e7e3e5981fb8ab29"
)
SCHEMA_VERSION = 2

OWNER_RECORD_FIELDS = (
    ("domain_separator", "bytes32"),
    ("schema_version", "uint16"),
    ("deployment_chain_id", "uint256"),
    ("registry_address", "address"),
    ("coordinator_address", "address"),
    ("archive_v2_address", "address"),
    ("owner_address", "address"),
    ("owner_domain_id", "bytes32"),
    ("owner_revision", "uint64"),
    ("record_sequence", "uint64"),
    ("original_caller", "address"),
    ("record_domain", "bytes32"),
    ("semantic_record_hash", "bytes32"),
)
RECORD_TRANSITION_FIELDS = (
    ("domain_separator", "bytes32"),
    ("deployment_chain_id", "uint256"),
    ("registry_address", "address"),
    ("coordinator_address", "address"),
    ("archive_v2_address", "address"),
    ("owner_address", "address"),
    ("domain_id", "bytes32"),
    ("prior_record_sequence", "uint64"),
    ("next_record_sequence", "uint64"),
    ("prior_record_chain_tip", "bytes32"),
    ("record_commitment", "bytes32"),
)
RECORD_DELTA_FIELDS = (
    ("domain_separator", "bytes32"),
    ("schema_version", "uint16"),
    ("deployment_chain_id", "uint256"),
    ("registry_address", "address"),
    ("coordinator_address", "address"),
    ("archive_v2_address", "address"),
    ("owner_address", "address"),
    ("owner_domain_id", "bytes32"),
    ("owner_revision", "uint64"),
    ("prior_record_sequence", "uint64"),
    ("next_record_sequence", "uint64"),
    ("prior_record_chain_tip", "bytes32"),
    ("record_count", "uint8"),
    ("record_0_domain", "bytes32"),
    ("record_0_semantic_hash", "bytes32"),
    ("record_0_owner_commitment", "bytes32"),
    ("record_1_domain", "bytes32"),
    ("record_1_semantic_hash", "bytes32"),
    ("record_1_owner_commitment", "bytes32"),
    ("next_record_chain_tip", "bytes32"),
)
EXPECTED_OWNER_RECORD_REQUIREMENTS = {
    "deployment_chain_id_source": "constructor_captured_immutable",
    "address_sources": "immutable_registry_coordinator_archive_and_address_this_owner",
    "owner_domain_source": "exact owner_domain_ids row for this owner",
    "owner_revision_rule": "next_revision_equals_checked_prior_revision_plus_one_for_the_successful_owner_action",
    "record_sequence_rule": "checked_prior_record_sequence_plus_one_based_record_position",
    "original_caller_rule": "nonzero immediate Registry submitter forwarded unchanged through Coordinator",
    "record_domain_rule": "exact nonzero correction record domain owned by this owner",
    "semantic_hash_rule": "exact nonzero owner_recomputed retained semantic hash",
    "commitment_must_be_nonzero": True,
}
EXPECTED_RECORD_DELTA_REQUIREMENTS = {
    "owner_revision_rule": "same_checked_next_revision_used_by_every_record_in_the_successful_owner_action",
    "next_sequence": "prior_record_sequence_plus_record_count_checked_uint64",
    "prior_tip_rule": "exact_nonzero_current_owner_record_chain_tip",
    "present_slot_rule": "domain_semantic_hash_and_owner_commitment_are_all_nonzero_and_independently_recomputed",
    "absent_slot_rule": "domain_semantic_hash_and_owner_commitment_are_all_zero",
    "one_record_rule": "slot_zero_present_slot_one_absent",
    "two_record_rule": "both_slots_present_in_primary_then_secondary_order",
    "next_tip_rule": "result_of_zero_one_or_two_ordered_record_chain_transitions",
    "zero_record_delta": "nonzero_commitment_with_unchanged_sequence_and_tip_and_two_absent_slots",
}
EXPECTED_RECORD_ORDERING = {
    "source": "record_event_correction.operation_join_rows.record_bindings",
    "per_owner_filter": True,
    "order": ["primary", "secondary"],
    "allowed_record_counts": [0, 1, 2],
    "only_two_record_owner_action_operation_id": 35,
    "unbounded_or_dynamic_record_loop_allowed": False,
}
EXPECTED_ARCHIVE_BOUNDARY = {
    "archive_is_evidence_only": True,
    "archive_can_authorize_owner_state": False,
    "owner_reads_archive": False,
    "archive_content_hash_pointer_or_block_in_owner_commitment": False,
    "reserved_evidence_projection": {
        "evidence_id": "owner_record_commitment",
        "evidence_version": "record_sequence",
        "append_requirement_accepted": False,
        "evidence_bytes_schema_accepted": False,
    },
    "same_content_retry": "archive_returns_appended_false_but_does_not_make_owner_semantic_retry_valid",
    "conflicting_retry": "archive_reverts_and_if_called_in_same_transaction_all_owner_and_archive_changes_revert",
}
EXPECTED_FAILURE = {
    "owner_computes_all_record_words_internally": True,
    "coordinator_or_external_commitment_word_allowed": False,
    "semantic_duplicate": "revert_before_sequence_tip_receipt_or_event_change",
    "wrong_owner_domain": "revert",
    "zero_or_unknown_record_domain": "revert",
    "zero_semantic_hash": "revert",
    "zero_original_caller": "revert",
    "stale_revision_sequence_or_tip": "revert",
    "record_sequence_overflow": "revert",
    "record_count_or_order_drift": "revert",
    "downstream_owner_archive_event_or_recipe_failure": "revert_entire_transaction",
    "partial_success_allowed": False,
    "successful_record_no_op_allowed": False,
}

EXPECTED_PROHIBITED = (
    "live_block_chainid",
    "tx_origin",
    "abi_encode_packed",
    "opaque_coordinator_commitment_word",
    "external_commitment_word",
    "implicit_storage_or_current_state_join",
    "generic_hash_only_record_identity",
    "record_receipt_delete_or_overwrite",
    "record_chain_tip_rewind",
    "record_sequence_decrement_or_reuse",
    "unbounded_record_enumeration_or_history_loop",
    "archive_authority_or_latest_pointer",
    "delegatecall",
    "proxy_or_generic_upgrade",
    "mutable_rebind",
)
EXPECTED_UNRESOLVED = (
    "entrypoint_abi",
    "owner_mutations",
    "owner_storage",
    "owner_snapshots",
    "replay_keys",
    "action_commitment_preimage",
    "domain_state_commitment_preimage",
    "replay_delta_commitment_preimage",
    "normative_owner_events_acceptance",
    "provider_reads",
    "role_authority",
    "signer_validation",
    "recipe_commitment",
    "archive_evidence_bytes_and_call_order",
    "composite_manifest",
    "construction",
    "errors",
    "operation_lock",
    "gas_and_call_discipline",
)
EXPECTED_GATE = {
    "record_continuity_prerequisite_selected_for_review": True,
    "semantic_record_hash_retained": True,
    "owner_v2_record_commitment_resolved": True,
    "record_delta_commitment_resolved": True,
    "logical_receipt_mapping_resolved_without_slot": True,
    "dual_continuity_prerequisite_resolved": True,
    "shared_mechanics_modified": False,
    "owner_storage_accepted": False,
    "owner_snapshots_accepted": False,
    "replay_keys_accepted": False,
    "all_domain_layouts_resolved": False,
    "all_replay_surfaces_resolved": False,
    "four_inner_commitments_resolved": False,
    "interface_freeze_complete": False,
    "full_freeze_complete": False,
    "implementation_authorized": False,
    "source_present": False,
    "deployment_authorized": False,
    "readiness_credit": False,
}

EXPECTED_VECTOR_IDENTITY = {
    "deployment_chain_id": "1",
    "registry_address": "0x1111111111111111111111111111111111111111",
    "coordinator_address": "0x2222222222222222222222222222222222222222",
    "archive_v2_address": "0x3333333333333333333333333333333333333333",
    "owner_address": "0x4444444444444444444444444444444444444444",
    "owner_domain": "identity_authority",
    "owner_domain_id": "0x1b0dd53dfa76f8d43a27b96148dae3ebe0609a01dfd55dedacf1fb71c51bfba3",
    "owner_revision": "9",
    "prior_record_sequence": "10",
    "prior_record_chain_tip": "0x9999999999999999999999999999999999999999999999999999999999999999",
    "original_caller": "0x5555555555555555555555555555555555555555",
}
EXPECTED_RECORD_FIXTURES = (
    (
        0,
        "IDENTITY_RECOVERY_RECORD_DOMAIN",
        "0x459749364fd07c3a8f1998b82d893d33ef0942c30d94666b42dac1e37ba5feff",
        "0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "11",
        "0xf9e6ce3db993d46c4630e01ab985212cc609f4ede3310bd1a926bd784bafed70",
        "0x8dfe9694373c844dfba888b1f86a4165a16cd92de70793d7ce18ad8c59d0e060",
    ),
    (
        1,
        "IDENTITY_RECOVERY_SUPERSESSION_DOMAIN",
        "0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae",
        "0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
        "12",
        "0x0940dc8f1a5aa5a5837cd5df2cb2e0d213d24aa03e8ba67f140dd1367deda140",
        "0x001774eb134dae83118373af3b3b84cda4f6953f2b5868c075dc3ca504111d14",
    ),
)
EXPECTED_DELTA_FIXTURES = (
    (
        0,
        "10",
        "0x9999999999999999999999999999999999999999999999999999999999999999",
        "0x2ad36ea5331fee2089dcdfa71dd148ed91d172b82b8608fc518425cae5cda0fe",
    ),
    (
        1,
        "11",
        "0x8dfe9694373c844dfba888b1f86a4165a16cd92de70793d7ce18ad8c59d0e060",
        "0xa5d4832b467aa54b347026183e4afe6bb5a9bbf33a899bd4ecf66c2440d1a2c5",
    ),
    (
        2,
        "12",
        "0x001774eb134dae83118373af3b3b84cda4f6953f2b5868c075dc3ca504111d14",
        "0x27b4a3d9e57bffa88bf9d43d737e8c0ddbb3e2d73a5486608692058e95b17f12",
    ),
)


class ContinuityError(RuntimeError):
    """Raised when the continuity packet or an authority binding drifts."""


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _canonical_sha(value: Any) -> str:
    encoded = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(encoded).hexdigest()


def _keccak_bytes(data: bytes) -> bytes:
    digest = keccak.new(digest_bits=256)
    digest.update(data)
    return digest.digest()


def _keccak_text(value: str) -> str:
    return "0x" + _keccak_bytes(value.encode()).hex()


def _decode_hex(value: str, expected: int) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x"):
        raise ContinuityError("vector hex value is malformed")
    try:
        decoded = bytes.fromhex(value[2:])
    except ValueError as exc:
        raise ContinuityError("vector hex value is malformed") from exc
    if len(decoded) != expected:
        raise ContinuityError("vector hex value has wrong width")
    return decoded


def _abi_word(type_name: str, value: Any) -> bytes:
    if type_name == "bytes32":
        return _decode_hex(value, 32)
    if type_name == "address":
        return b"\x00" * 12 + _decode_hex(value, 20)
    if type_name.startswith("uint"):
        bits = int(type_name[4:])
        number = int(value)
        if bits <= 0 or bits > 256 or bits % 8 or number < 0 or number >= 1 << bits:
            raise ContinuityError(f"{type_name} vector value is out of range")
        return number.to_bytes(32, "big")
    raise ContinuityError(f"unsupported vector ABI type {type_name}")


def _abi_hash(fields: tuple[tuple[str, str], ...], values: dict[str, Any]) -> str:
    encoded = b"".join(_abi_word(type_name, values[name]) for name, type_name in fields)
    return "0x" + _keccak_bytes(encoded).hex()


def _safe_path(root: Path, raw: str) -> Path:
    posix = PurePosixPath(raw)
    if not raw or posix.is_absolute() or "\\" in raw or ".." in posix.parts:
        raise ContinuityError(f"unsafe authority path: {raw}")
    candidate = root.joinpath(*posix.parts)
    cursor = root
    for part in posix.parts:
        cursor = cursor / part
        if cursor.is_symlink():
            raise ContinuityError(f"authority path uses symlink: {raw}")
    try:
        resolved_root = root.resolve(strict=True)
        resolved = candidate.resolve(strict=True)
    except (OSError, RuntimeError) as exc:
        raise ContinuityError(f"authority path is unavailable: {raw}") from exc
    if resolved_root not in resolved.parents:
        raise ContinuityError(f"authority path escapes repository: {raw}")
    if not resolved.is_file():
        raise ContinuityError(f"authority path is not a file: {raw}")
    return resolved


def _read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ContinuityError(f"cannot read JSON {path.as_posix()}") from exc
    if not isinstance(value, dict):
        raise ContinuityError(f"JSON object required: {path.as_posix()}")
    return value


def _field_rows(fields: tuple[tuple[str, str], ...]) -> list[dict[str, str]]:
    return [{"name": name, "type": type_name} for name, type_name in fields]


def _derive_inventories(
    correction: dict[str, Any], foundation: dict[str, Any]
) -> tuple[dict[str, list[Any]], list[list[Any]]]:
    records = [
        [
            row["surface_id"],
            row["record_domain"],
            row["owner_domain"],
            row["owner_contract"],
            row["domain_value"],
        ]
        for row in correction["record_domain_rows"]
    ]
    created: list[list[Any]] = []
    batches: list[list[Any]] = []
    for operation in correction["operation_join_rows"]:
        by_owner: dict[str, list[list[str]]] = {}
        for record in operation["record_bindings"]:
            if record["mode"] != "create":
                continue
            created.append(
                [
                    operation["operation_id"],
                    operation["write"],
                    record["role"],
                    record["source"],
                    record["owner_domain"],
                ]
            )
            by_owner.setdefault(record["owner_domain"], []).append(
                [record["role"], record["source"]]
            )
        for owner_domain, owner_records in by_owner.items():
            batches.append(
                [
                    operation["operation_id"],
                    operation["write"],
                    owner_domain,
                    owner_records,
                ]
            )
    domains = [
        [row["domain_id"], row["owner_contract"], row["storage_namespace"]]
        for row in foundation["domain_layout_rows"]
    ]
    return {
        "record_domains": records,
        "created_records": created,
        "owner_record_batches": batches,
        "owner_domains": domains,
    }, batches


def _check_authorities(root: Path, packet: dict[str, Any]) -> None:
    expected_rows = [
        {"id": row_id, "path": path, "sha256": digest}
        for row_id, path, digest in EXPECTED_AUTHORITY_BINDINGS
    ]
    if packet["authority_bindings"] != expected_rows:
        raise ContinuityError("authority binding inventory drifted")
    for row in expected_rows:
        path = _safe_path(root, row["path"])
        if _sha256_bytes(path.read_bytes()) != row["sha256"]:
            raise ContinuityError(f"authority digest drifted: {row['id']}")


def _check_inputs(
    correction: dict[str, Any],
    foundation: dict[str, Any],
    shared: dict[str, Any],
    matrix: dict[str, Any],
) -> None:
    inventory = correction["inventory"]
    expected_inventory = {
        "record_domains": 37,
        "normative_events": 54,
        "operations": 57,
        "corrected_events": 15,
        "preserved_events": 39,
        "historical_genesis_event_coverage": 21,
        "historical_split_event_coverage": 2,
        "created_record_bindings": 40,
        "record_component_bindings": 430,
    }
    if inventory != expected_inventory:
        raise ContinuityError("record/event correction inventory drifted")
    protocol = correction["record_protocol"]
    if (
        protocol["dual_continuity_packet_created"] is not False
        or protocol["owner_v2_record_commitment_created"] is not False
        or protocol["implicit_storage_or_current_state_joins_allowed"] is not False
        or protocol["every_created_record_component_mapped"] is not True
    ):
        raise ContinuityError("record/event correction prerequisite posture drifted")
    if any(not row["reconstruction_complete"] for row in correction["record_reconstruction_rows"]):
        raise ContinuityError("record reconstruction row is incomplete")
    if any(row["implicit_storage_join"] for row in correction["record_reconstruction_rows"]):
        raise ContinuityError("record reconstruction uses implicit storage")
    transition = foundation["transition_protocol"]
    if (
        transition["record_transition_domain"] != RECORD_TRANSITION_DOMAIN
        or transition["record_transition_encoding"] != "abi.encode"
        or transition["record_transition_fields"]
        != [name for name, _ in RECORD_TRANSITION_FIELDS]
        or transition["checked_record_sequence_increment"]
        != "exact_record_count_zero_to_two_per_successful_owner_action"
        or transition["overflow_behavior"] != "revert"
    ):
        raise ContinuityError("foundation record transition drifted")
    recomputation = foundation["owner_side_recomputation"]
    if (
        recomputation["compute_location"] != "inside_typed_owner"
        or recomputation["coordinator_supplied_commitment_words_allowed"] is not False
        or recomputation["external_supplied_commitment_words_allowed"] is not False
        or recomputation["record_delta_commitment_preimage"] is not None
        or recomputation["exact_inner_preimages_resolved"] is not False
    ):
        raise ContinuityError("foundation owner recomputation posture drifted")
    if foundation["gate_state"]["owner_storage_accepted"] is not False:
        raise ContinuityError("foundation owner storage was prematurely accepted")
    decisions = shared["decision_rows"]
    accepted = [row["surface_id"] for row in decisions if row["decision_status"] == "accepted"]
    if accepted != ["registry_ingress", "original_caller", "native_value"]:
        raise ContinuityError("shared accepted decision set drifted")
    roots = {row["surface_id"]: row for row in decisions}
    for decision_id in ("owner_storage", "owner_snapshots", "replay_keys"):
        row = roots[decision_id]
        if row["decision_status"] != "unresolved" or row["source_blocking"] is not True:
            raise ContinuityError(f"shared root decision drifted: {decision_id}")
    if any(
        row["source_requirements"]["source_present"]
        or row["source_requirements"]["implementation_authorized"]
        for row in matrix["operations"]
    ):
        raise ContinuityError("operation source or authorization drifted")
    matrix_batches: dict[tuple[int, str], list[str]] = {}
    owner_action_count = 0
    for operation in matrix["operations"]:
        for action in operation["coordinator_recipe"]["actions"]:
            owner_action_count += 1
            records = [
                surface.removeprefix("record:")
                for surface in action["write_surfaces"]
                if surface.startswith("record:")
            ]
            if len(records) > 2:
                raise ContinuityError("matrix owner action record bound drifted")
            if records:
                key = (operation["operation_id"], action["owner_domain"])
                if key in matrix_batches:
                    raise ContinuityError("matrix has duplicate operation owner action")
                matrix_batches[key] = records
    correction_batches: dict[tuple[int, str], list[str]] = {}
    for operation in correction["operation_join_rows"]:
        for record in operation["record_bindings"]:
            if record["mode"] != "create":
                continue
            correction_batches.setdefault(
                (operation["operation_id"], record["owner_domain"]), []
            ).append(record["source"])
    if owner_action_count != 85:
        raise ContinuityError("matrix owner action count drifted")
    if matrix_batches != correction_batches or len(matrix_batches) != 39:
        raise ContinuityError("matrix and correction owner record batches drifted")


def _check_inventories(
    packet: dict[str, Any], correction: dict[str, Any], foundation: dict[str, Any]
) -> None:
    derived, batches = _derive_inventories(correction, foundation)
    for inventory_id, values in derived.items():
        expected_count, expected_projection, expected_digest = EXPECTED_INVENTORIES[inventory_id]
        binding = packet["inventory_bindings"][inventory_id]
        if binding["count"] != expected_count or len(values) != expected_count:
            raise ContinuityError(f"{inventory_id} count drifted")
        if binding["ordered_projection"] != expected_projection:
            raise ContinuityError(f"{inventory_id} projection drifted")
        digest = _canonical_sha(values)
        if binding["sha256"] != expected_digest or digest != expected_digest:
            raise ContinuityError(f"{inventory_id} ordered inventory drifted")
    sizes = [len(row[3]) for row in batches]
    if max(sizes) != 2 or sizes.count(2) != 1:
        raise ContinuityError("owner record batch bound drifted")
    two = next(row for row in batches if len(row[3]) == 2)
    if two != [
        35,
        "recoverArtistIdentity",
        "identity_authority",
        [
            ["primary", "IDENTITY_RECOVERY_RECORD_DOMAIN"],
            ["secondary", "IDENTITY_RECOVERY_SUPERSESSION_DOMAIN"],
        ],
    ]:
        raise ContinuityError("two-record owner batch drifted")
    packet_two = packet["inventory_bindings"]["owner_record_batches"]["only_two_record_batch"]
    expected_two = {
        "operation_id": 35,
        "write": "recoverArtistIdentity",
        "owner_domain": "identity_authority",
        "ordered_records": [
            {"role": "primary", "record_domain": "IDENTITY_RECOVERY_RECORD_DOMAIN"},
            {
                "role": "secondary",
                "record_domain": "IDENTITY_RECOVERY_SUPERSESSION_DOMAIN",
            },
        ],
    }
    if packet_two != expected_two:
        raise ContinuityError("packet two-record owner batch drifted")


def _check_protocol(packet: dict[str, Any], correction: dict[str, Any]) -> None:
    expected_domains = [
        {
            "domain_id": domain_id,
            "storage_namespace": namespace,
            "domain_value_rule": "keccak256(bytes(storage_namespace))",
            "domain_value": value,
        }
        for domain_id, namespace, value in EXPECTED_OWNER_DOMAINS
    ]
    if packet["owner_domain_ids"] != expected_domains:
        raise ContinuityError("owner domain identity rows drifted")
    for row in packet["owner_domain_ids"]:
        if _keccak_text(row["storage_namespace"]) != row["domain_value"]:
            raise ContinuityError(f"owner domain identity hash drifted: {row['domain_id']}")
    records = {row["record_domain"]: row for row in correction["record_domain_rows"]}
    for row in correction["record_domain_rows"]:
        if row["domain_value"] == "0x" + "00" * 32:
            raise ContinuityError("zero retained record domain")
    commitment = packet["owner_record_commitment_protocol"]
    if (
        commitment["domain"] != OWNER_RECORD_DOMAIN
        or commitment["domain_separator_keccak256"] != OWNER_RECORD_DOMAIN_HASH
        or _keccak_text(OWNER_RECORD_DOMAIN) != OWNER_RECORD_DOMAIN_HASH
        or commitment["schema_version"] != SCHEMA_VERSION
        or commitment["encoding"] != "abi.encode"
        or commitment["ordered_fields"] != _field_rows(OWNER_RECORD_FIELDS)
        or commitment["requirements"] != EXPECTED_OWNER_RECORD_REQUIREMENTS
    ):
        raise ContinuityError("owner record commitment protocol drifted")
    transition = packet["record_chain_transition"]
    if (
        transition["domain"] != RECORD_TRANSITION_DOMAIN
        or transition["domain_separator_keccak256"] != RECORD_TRANSITION_DOMAIN_HASH
        or _keccak_text(RECORD_TRANSITION_DOMAIN) != RECORD_TRANSITION_DOMAIN_HASH
        or transition["ordered_fields"] != _field_rows(RECORD_TRANSITION_FIELDS)
        or transition["encoding"] != "abi.encode"
    ):
        raise ContinuityError("record chain transition protocol drifted")
    delta = packet["record_delta_commitment_protocol"]
    if (
        delta["domain"] != RECORD_DELTA_DOMAIN
        or delta["domain_separator_keccak256"] != RECORD_DELTA_DOMAIN_HASH
        or _keccak_text(RECORD_DELTA_DOMAIN) != RECORD_DELTA_DOMAIN_HASH
        or delta["schema_version"] != SCHEMA_VERSION
        or delta["encoding"] != "abi.encode"
        or delta["ordered_fields"] != _field_rows(RECORD_DELTA_FIELDS)
        or delta["requirements"] != EXPECTED_RECORD_DELTA_REQUIREMENTS
    ):
        raise ContinuityError("record delta commitment protocol drifted")
    for fixture in packet["canonical_vectors"]["record_fixtures"]:
        source = records.get(fixture["record_domain_name"])
        if source is None or source["domain_value"] != fixture["record_domain"]:
            raise ContinuityError("vector record domain is not correction-bound")
        if source["owner_domain"] != "identity_authority":
            raise ContinuityError("vector record owner domain drifted")


def _check_policy(packet: dict[str, Any]) -> None:
    if tuple(packet["prohibited_mechanics"]) != EXPECTED_PROHIBITED:
        raise ContinuityError("prohibited mechanics drifted")
    if tuple(packet["unresolved_dependencies"]) != EXPECTED_UNRESOLVED:
        raise ContinuityError("unresolved dependency inventory drifted")
    if packet["gate_state"] != EXPECTED_GATE:
        raise ContinuityError("gate state drifted")
    semantic = packet["semantic_record_protocol"]
    if semantic != {
        "identity": "exact retained record-domain semantic hash",
        "authority": "record_event_correction.record_domain_rows and record_reconstruction_rows",
        "record_domain_count": 37,
        "encoding": "exact correction-row encoding",
        "semantic_hash_must_be_nonzero": True,
        "owner_must_recompute_from_typed_inputs_and_immutable_constants": True,
        "implicit_storage_or_current_state_join_allowed": False,
        "live_block_chainid_allowed": False,
        "abi_encode_packed_allowed": False,
    }:
        raise ContinuityError("semantic record protocol drifted")
    mapping = packet["logical_receipt_mapping"]
    expected_mapping = {
        "coordinate": ["record_domain", "semantic_record_hash"],
        "value": "owner_record_commitment",
        "physical_storage_slot_selected": False,
        "insert_only": True,
        "delete_allowed": False,
        "overwrite_allowed": False,
        "enumeration_allowed": False,
        "latest_or_current_pointer_allowed": False,
        "same_semantic_record_retry": "revert_duplicate_owner_record_no_sequence_or_tip_change",
        "different_domain_same_semantic_hash": "distinct_typed_coordinate",
        "supersession": "new_semantic_record_and_new_owner_commitment_prior_receipts_remain_immutable",
    }
    if mapping != expected_mapping:
        raise ContinuityError("logical receipt mapping drifted")
    if packet["record_ordering"] != EXPECTED_RECORD_ORDERING:
        raise ContinuityError("record ordering policy drifted")
    if packet["archive_boundary"] != EXPECTED_ARCHIVE_BOUNDARY:
        raise ContinuityError("Archive evidence boundary drifted")
    if packet["failure_and_rollback"] != EXPECTED_FAILURE:
        raise ContinuityError("failure and rollback posture drifted")


def _check_vectors(packet: dict[str, Any]) -> None:
    vectors = packet["canonical_vectors"]
    if vectors["fixture_identity"] != EXPECTED_VECTOR_IDENTITY:
        raise ContinuityError("vector fixture identity drifted")
    expected_record_rows = [
        {
            "position": position,
            "record_domain_name": name,
            "record_domain": domain,
            "semantic_record_hash": semantic_hash,
            "record_sequence": sequence,
            "expected_owner_record_commitment": commitment,
            "expected_record_chain_tip": tip,
        }
        for position, name, domain, semantic_hash, sequence, commitment, tip in EXPECTED_RECORD_FIXTURES
    ]
    if vectors["record_fixtures"] != expected_record_rows:
        raise ContinuityError("record vector fixture rows drifted")
    identity = vectors["fixture_identity"]
    common = {
        "deployment_chain_id": identity["deployment_chain_id"],
        "registry_address": identity["registry_address"],
        "coordinator_address": identity["coordinator_address"],
        "archive_v2_address": identity["archive_v2_address"],
        "owner_address": identity["owner_address"],
        "owner_domain_id": identity["owner_domain_id"],
    }
    prior_tip = identity["prior_record_chain_tip"]
    prior_sequence = int(identity["prior_record_sequence"])
    computed_records: list[dict[str, str]] = []
    for index, fixture in enumerate(vectors["record_fixtures"]):
        commitment_values = {
            "domain_separator": OWNER_RECORD_DOMAIN_HASH,
            "schema_version": SCHEMA_VERSION,
            **common,
            "owner_revision": identity["owner_revision"],
            "record_sequence": fixture["record_sequence"],
            "original_caller": identity["original_caller"],
            "record_domain": fixture["record_domain"],
            "semantic_record_hash": fixture["semantic_record_hash"],
        }
        commitment = _abi_hash(OWNER_RECORD_FIELDS, commitment_values)
        if commitment != fixture["expected_owner_record_commitment"]:
            raise ContinuityError(f"owner record vector {index} commitment drifted")
        next_sequence = prior_sequence + 1
        transition_values = {
            "domain_separator": RECORD_TRANSITION_DOMAIN_HASH,
            **common,
            "prior_record_sequence": prior_sequence,
            "next_record_sequence": next_sequence,
            "prior_record_chain_tip": prior_tip,
            "domain_id": common["owner_domain_id"],
            "record_commitment": commitment,
        }
        next_tip = _abi_hash(RECORD_TRANSITION_FIELDS, transition_values)
        if next_tip != fixture["expected_record_chain_tip"]:
            raise ContinuityError(f"owner record vector {index} chain tip drifted")
        computed_records.append(
            {
                "domain": fixture["record_domain"],
                "semantic_hash": fixture["semantic_record_hash"],
                "commitment": commitment,
                "tip": next_tip,
            }
        )
        prior_sequence = next_sequence
        prior_tip = next_tip
    expected_delta_rows = [
        {
            "record_count": count,
            "expected_next_record_sequence": sequence,
            "expected_next_record_chain_tip": tip,
            "expected_record_delta_commitment": commitment,
        }
        for count, sequence, tip, commitment in EXPECTED_DELTA_FIXTURES
    ]
    if vectors["record_delta_vectors"] != expected_delta_rows:
        raise ContinuityError("record delta vector fixture rows drifted")
    zero = "0x" + "00" * 32
    initial_tip = identity["prior_record_chain_tip"]
    initial_sequence = int(identity["prior_record_sequence"])
    for fixture in vectors["record_delta_vectors"]:
        count = fixture["record_count"]
        slots = computed_records[:count] + [
            {"domain": zero, "semantic_hash": zero, "commitment": zero, "tip": zero}
            for _ in range(2 - count)
        ]
        next_tip = initial_tip if count == 0 else computed_records[count - 1]["tip"]
        values = {
            "domain_separator": RECORD_DELTA_DOMAIN_HASH,
            "schema_version": SCHEMA_VERSION,
            **common,
            "owner_revision": identity["owner_revision"],
            "prior_record_sequence": initial_sequence,
            "next_record_sequence": initial_sequence + count,
            "prior_record_chain_tip": initial_tip,
            "record_count": count,
            "record_0_domain": slots[0]["domain"],
            "record_0_semantic_hash": slots[0]["semantic_hash"],
            "record_0_owner_commitment": slots[0]["commitment"],
            "record_1_domain": slots[1]["domain"],
            "record_1_semantic_hash": slots[1]["semantic_hash"],
            "record_1_owner_commitment": slots[1]["commitment"],
            "next_record_chain_tip": next_tip,
        }
        commitment = _abi_hash(RECORD_DELTA_FIELDS, values)
        if str(initial_sequence + count) != fixture["expected_next_record_sequence"]:
            raise ContinuityError(f"record delta vector {count} sequence drifted")
        if next_tip != fixture["expected_next_record_chain_tip"]:
            raise ContinuityError(f"record delta vector {count} tip drifted")
        if commitment != fixture["expected_record_delta_commitment"]:
            raise ContinuityError(f"record delta vector {count} commitment drifted")


def _check_semantic_digest(packet: dict[str, Any]) -> None:
    payload = dict(packet)
    observed_field = payload.pop("semantic_digest")
    observed = "sha256:" + _canonical_sha(payload)
    if observed_field != observed or observed != SEMANTIC_DIGEST:
        raise ContinuityError("packet semantic digest drifted")


def check(root: Path) -> None:
    root = root.resolve(strict=True)
    packet = _read_json(root / PACKET_PATH)
    schema = _read_json(root / SCHEMA_PATH)
    if _sha256_bytes((root / SCHEMA_PATH).read_bytes()) != SCHEMA_SHA256:
        raise ContinuityError("packet schema digest drifted")
    if schema.get("$id") != SCHEMA_ID:
        raise ContinuityError("packet schema id drifted")
    errors = sorted(Draft202012Validator(schema).iter_errors(packet), key=lambda e: list(e.path))
    if errors:
        raise ContinuityError(f"packet schema validation failed: {errors[0].message}")
    if (
        packet["schema"] != PACKET_SCHEMA
        or packet["status"] != PACKET_STATUS
        or packet["maturity"] != PACKET_MATURITY
        or packet["evaluated_base"]
        != {"commit": EVALUATED_COMMIT, "tree": EVALUATED_TREE}
    ):
        raise ContinuityError("packet identity or evaluated base drifted")
    _check_authorities(root, packet)
    foundation = _read_json(root / FOUNDATION_PATH)
    correction = _read_json(root / CORRECTION_PATH)
    shared = _read_json(root / SHARED_PATH)
    matrix = _read_json(root / MATRIX_PATH)
    _check_inputs(correction, foundation, shared, matrix)
    _check_inventories(packet, correction, foundation)
    _check_protocol(packet, correction)
    _check_policy(packet)
    _check_vectors(packet)
    _check_semantic_digest(packet)
    print(
        "artist owner record continuity is source-blocked and exact: "
        "37 semantic record domains, 40 created records, 39 owner batches, "
        "7 owner identities, fixed 0/1/2 record delta; shared 3/19 and source unauthorized"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    try:
        check(args.root)
    except ContinuityError as exc:
        print(f"artist owner record continuity check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
