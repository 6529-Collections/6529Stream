#!/usr/bin/env python3
"""Fail-closed checker for the proposed artist shared-mechanics decision register."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

PACKET_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json"
)
SCHEMA_PATH = Path(
    "docs/architecture/artist-operation-shared-mechanics-freeze-v1.schema.json"
)
MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")
ARTIST_SOURCE_ROOT = Path("smart-contracts/domains/artist")
COORDINATOR_INTERFACE_PATH = Path(
    "smart-contracts/interfaces/stream/IStreamArtistOperationCoordinator.sol"
)

PACKET_SCHEMA = "6529stream.artist-operation-shared-mechanics-freeze.v1"
PACKET_STATUS = "PROPOSED_PARTIAL_DECISION_RESOLUTION"
PACKET_MATURITY = "pre_audit_source_blocked"
JSON_SCHEMA_ID = (
    "https://6529.io/schemas/artist-operation-shared-mechanics-freeze-v1.schema.json"
)
EVALUATED_COMMIT = "eef6a4cc5070186cc6517cca90bd9ffe1f74ea06"
EVALUATED_TREE = "1a56c7b27ed304f96f551d1bebd0aa93a4ee164e"
SCHEMA_SHA256 = "094eea2ffd0955f000ca1d97465c0d7f7f1662cfc844481068b4308a79ed5505"
SELECTED_SHAPE_SHA256 = "9417c5fe3f8187ab75463384b1ef0932233369b097de459df5d10f86e80cc11b"
PHASE_ORDER_SHA256 = "9faa90a8cd9027448dfdf344f23c9719ad0488e9f79d3a78f4fd40adab7075aa"
FIXED_INVARIANTS_SHA256 = "5e4ae8a539187ab0c29969f189d956b41c2002ac046e80023644e85c19381543"
OPERATION_PROJECTION_SHA256 = "baab6362ef92d9b1c27ca4bda2117a8818e66fc4ea2b80d3d090144ce24ed969"
DECISION_ROWS_SHA256 = "27031b7092d81767cc5ac9b4573cfcf9f5faee1f53a95d9da9a5542a17a404f2"
GATE_STATE_SHA256 = "41ef4a06b79f0478a71ad4aadd7230179f6daf3f57cb5207fdf006ce276831fa"
EXCLUSIONS_SHA256 = "3d917a006edccebf17dd61967de693dd8f75e44273cbd9117419fc14cb8a01bc"

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema",
        "status",
        "maturity",
        "evaluated_base",
        "authority_bindings",
        "selected_shape",
        "phase_order",
        "fixed_invariants",
        "operation_projection",
        "decision_rows",
        "gate_state",
        "exclusions",
    }
)

EXPECTED_AUTHORITY_BINDINGS = (
    (
        "coordinator_source_gate",
        "docs/architecture/artist-operation-coordinator-source-acceptance-gate.md",
        "df2f039ee0a8991cba38da084d2e41158bb857cfa005d8fcad45b30d592b727a",
    ),
    (
        "adr_0023",
        "docs/adr/0023-modular-artist-authority-domain-ownership.md",
        "b3a7f322518aeb63638572486292be511f67202e09db58471ac867eb3fa8c113",
    ),
    (
        "semantic_owner_matrix",
        "docs/architecture/artist-semantic-owner-matrix-v2.json",
        "bc4b55c68c504ee7d74965d7fa0d1edbe6de816e567e076442781b81232320a2",
    ),
    (
        "semantic_owner_matrix_schema",
        "docs/architecture/artist-semantic-owner-matrix-v2.schema.json",
        "b242c5480ecdf8e4aa57dc02d76fd8cd81631298eeda0b96cbba9b036d72b473",
    ),
    (
        "semantic_owner_matrix_checker",
        "scripts/check_artist_semantic_owner_matrix.py",
        "75be5171655556711282de41a3feb909b0a9fdded45c565f66597d984427152b",
    ),
    (
        "semantic_owner_matrix_tests",
        "scripts/test_artist_semantic_owner_matrix.py",
        "126269436e56b83f9e996b9b1e0961ebac08740a38a8e9789c70c302a8b0654f",
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

EXPECTED_DECISION_PHASES = (
    ("entrypoint_abi", "shared_mechanics"),
    ("registry_ingress", "shared_mechanics"),
    ("original_caller", "shared_mechanics"),
    ("owner_snapshots", "owner_domain_packets"),
    ("owner_mutations", "owner_domain_packets"),
    ("owner_storage", "owner_domain_packets"),
    ("replay_keys", "shared_mechanics"),
    ("normative_owner_events", "owner_domain_packets"),
    ("provider_reads", "shared_mechanics"),
    ("role_authority", "shared_mechanics"),
    ("signer_validation", "shared_mechanics"),
    ("recipe_commitment", "shared_mechanics"),
    ("archive_evidence", "shared_mechanics"),
    ("composite_manifest", "shared_mechanics"),
    ("operation_lock", "shared_mechanics"),
    ("construction", "shared_mechanics"),
    ("errors", "cross_surface_closure"),
    ("native_value", "shared_mechanics"),
    ("gas_and_call_discipline", "shared_mechanics"),
)

EXPECTED_ACCEPTED_DECISIONS = ("native_value",)
EXPECTED_NATIVE_VALUE_OPTION = "nonpayable_zero_value_end_to_end_v1"
EXPECTED_NATIVE_VALUE_OPTION_DISPOSITIONS = (
    ("payable_passthrough_or_custody", "rejected"),
    ("payable_with_in_body_zero_value_check", "rejected"),
    ("nonpayable_with_explicit_fallback_or_receive_revert", "rejected"),
    ("nonpayable_with_redundant_zero_value_commitment_fields", "rejected"),
    ("nonpayable_zero_value_end_to_end_v1", "accepted"),
)
EXPECTED_NATIVE_VALUE_VALUES = {
    "registry_entrypoint_count": 57,
    "coordinator_entrypoint_count": 57,
    "registry_entrypoint_mutability": "external_nonpayable",
    "coordinator_entrypoint_mutability": "external_nonpayable",
    "fallback_present": False,
    "receive_present": False,
    "typed_owner_call_value_wei": 0,
    "typed_provider_call_value_wei": 0,
    "typed_validator_call_value_wei": 0,
    "archive_call_value_wei": 0,
    "forced_balance_forwarded": False,
    "forced_balance_recoverable_by_protocol": False,
}

EXPECTED_PRESENT_ARTIST_SOURCES = (
    "smart-contracts/domains/artist/StreamArtistArchiveV2.sol",
    "smart-contracts/domains/artist/StreamArtistRegistryV2.sol",
)

EXPECTED_ABSENT_ARTIST_SOURCES = (
    "smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol",
    "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol",
    "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol",
    "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol",
)

EXPECTED_669_ROW = {
    "path": "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol",
    "site": "_validateSignerProof",
    "kind": "call-option",
    "operation": "staticcall",
    "expression": "context.erc1271GasCap",
    "call_syntax": "address(<signer>).staticcall{gas: context.erc1271GasCap}",
    "expected_count": 1,
    "path_class": "user-path",
    "lane": "artist-authority",
    "issue": "#669",
    "disposition": "open-remediation-required",
}


class FreezeError(ValueError):
    """Raised when the proposed decision register is not exact."""


def _reject_constant(value: str) -> Any:
    raise FreezeError(f"non-finite JSON number is forbidden: {value}")


def _reject_float(value: str) -> Any:
    raise FreezeError(f"floating-point JSON number is forbidden: {value}")


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise FreezeError(f"duplicate JSON member is forbidden: {key}")
        result[key] = value
    return result


def _walk_numbers(value: Any, path: str = "$") -> None:
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return
    if isinstance(value, int):
        if abs(value) > (2**53 - 1):
            raise FreezeError(f"unsafe JSON integer at {path}")
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise FreezeError(f"non-finite JSON number at {path}")
        raise FreezeError(f"floating-point JSON number at {path}")
    if isinstance(value, list):
        for index, item in enumerate(value):
            _walk_numbers(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _walk_numbers(item, f"{path}.{key}")
        return
    raise FreezeError(f"unsupported JSON value at {path}")


def load_strict_json(path: Path) -> Any:
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise FreezeError(f"cannot read UTF-8 JSON {path}: {exc}") from exc
    try:
        value = json.loads(
            raw,
            object_pairs_hook=_strict_object,
            parse_constant=_reject_constant,
            parse_float=_reject_float,
        )
    except (json.JSONDecodeError, FreezeError) as exc:
        raise FreezeError(f"invalid strict JSON {path}: {exc}") from exc
    _walk_numbers(value)
    return value


def _canonical_digest(value: Any) -> str:
    encoded = json.dumps(
        value,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _require_digest(label: str, value: Any, expected: str) -> None:
    observed = _canonical_digest(value)
    if observed != expected:
        raise FreezeError(f"{label} drifted: {observed} != {expected}")


def _validate_schema(packet: Any, schema: Any) -> None:
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(packet), key=lambda item: list(item.path))
    if errors:
        first = errors[0]
        location = "$" + "".join(f"[{part!r}]" for part in first.path)
        raise FreezeError(f"schema violation at {location}: {first.message}")


def _check_meta(packet: dict[str, Any], schema: dict[str, Any], schema_path: Path) -> None:
    if set(packet) != TOP_LEVEL_FIELDS:
        missing = sorted(TOP_LEVEL_FIELDS - set(packet))
        extra = sorted(set(packet) - TOP_LEVEL_FIELDS)
        raise FreezeError(
            f"critical top-level fields drifted: missing={missing}, extra={extra}"
        )
    if packet.get("schema") != PACKET_SCHEMA:
        raise FreezeError("packet schema id drifted")
    if packet.get("status") != PACKET_STATUS:
        raise FreezeError("packet must remain a Proposed partial decision resolution")
    if packet.get("maturity") != PACKET_MATURITY:
        raise FreezeError("packet must remain pre-audit and source-blocked")
    if packet.get("evaluated_base") != {
        "commit": EVALUATED_COMMIT,
        "tree": EVALUATED_TREE,
    }:
        raise FreezeError("evaluated base or tree drifted")
    if schema.get("$id") != JSON_SCHEMA_ID:
        raise FreezeError("JSON Schema $id drifted")
    try:
        schema_digest = hashlib.sha256(schema_path.read_bytes()).hexdigest()
    except OSError as exc:
        raise FreezeError(f"cannot read schema bytes {schema_path}: {exc}") from exc
    if schema_digest != SCHEMA_SHA256:
        raise FreezeError(
            f"schema sha256 drifted: {schema_digest} != {SCHEMA_SHA256}"
        )


def _check_authorities(root: Path, packet: dict[str, Any]) -> None:
    actual = tuple(
        (row["id"], row["path"], row["sha256"])
        for row in packet["authority_bindings"]
    )
    if actual != EXPECTED_AUTHORITY_BINDINGS:
        raise FreezeError("authority binding identity, order, or digest drifted")
    for authority_id, relative, expected in EXPECTED_AUTHORITY_BINDINGS:
        path = root / relative
        try:
            observed = hashlib.sha256(path.read_bytes()).hexdigest()
        except OSError as exc:
            raise FreezeError(
                f"authority {authority_id} is unreadable: {relative}: {exc}"
            ) from exc
        if observed != expected:
            raise FreezeError(
                f"authority {authority_id} sha256 drifted: {observed} != {expected}"
            )


def _check_register(packet: dict[str, Any]) -> None:
    _require_digest(
        "selected dependency shape",
        packet["selected_shape"],
        SELECTED_SHAPE_SHA256,
    )
    _require_digest("phase order", packet["phase_order"], PHASE_ORDER_SHA256)
    _require_digest(
        "fixed architecture invariants",
        packet["fixed_invariants"],
        FIXED_INVARIANTS_SHA256,
    )
    _require_digest(
        "57-operation projection policy",
        packet["operation_projection"],
        OPERATION_PROJECTION_SHA256,
    )
    _require_digest(
        "decision rows",
        packet["decision_rows"],
        DECISION_ROWS_SHA256,
    )
    _require_digest("gate state", packet["gate_state"], GATE_STATE_SHA256)
    _require_digest("bounded exclusions", packet["exclusions"], EXCLUSIONS_SHA256)

    rows = packet["decision_rows"]
    actual = tuple((row["surface_id"], row["phase"]) for row in rows)
    if actual != EXPECTED_DECISION_PHASES:
        raise FreezeError("decision surface identity, phase, or order drifted")
    accepted = tuple(row["surface_id"] for row in rows if row["accepted"])
    if accepted != EXPECTED_ACCEPTED_DECISIONS:
        raise FreezeError("accepted decision identity or count drifted")
    for row in rows:
        if row["surface_id"] == "native_value":
            if (
                row["decision_status"] != "accepted"
                or row["selected_option"] != EXPECTED_NATIVE_VALUE_OPTION
                or not row["accepted"]
                or row["source_blocking"]
                or row["unresolved_decisions"]
                or row["evidence_required"]
            ):
                raise FreezeError("native-value decision acceptance drifted")
            resolution = row["resolution"]
            dispositions = tuple(
                (option["option_id"], option["disposition"])
                for option in resolution["considered_options"]
            )
            if dispositions != EXPECTED_NATIVE_VALUE_OPTION_DISPOSITIONS:
                raise FreezeError("native-value considered options drifted")
            if resolution["selected_values"] != EXPECTED_NATIVE_VALUE_VALUES:
                raise FreezeError("native-value exact values drifted")
            continue
        if (
            row["decision_status"] != "unresolved"
            or row["selected_option"] is not None
            or row["accepted"]
            or not row["source_blocking"]
            or row.get("resolution") is not None
        ):
            raise FreezeError(
                f"decision {row['surface_id']} overclaims selection or acceptance"
            )


def _check_matrix_projection(matrix: dict[str, Any], packet: dict[str, Any]) -> None:
    requirements = matrix["source_requirements"]
    if (
        requirements["interface_and_storage_freeze_complete"]
        or requirements["implementation_authorized"]
    ):
        raise FreezeError("semantic-owner matrix overclaims freeze or authorization")
    operations = matrix["operations"]
    if [row["operation_id"] for row in operations] != list(range(1, 58)):
        raise FreezeError("matrix operation identities are not exact ordered 1..57")

    recipes: list[str] = []
    entrypoints: list[str] = []
    for operation in operations:
        recipe = operation["coordinator_recipe"]
        if set(recipe) != {
            "recipe_id",
            "facade_entrypoint",
            "generic_dispatch",
            "original_caller_authenticated",
            "snapshot_ids",
            "actions",
            "atomicity",
        }:
            raise FreezeError(
                f"operation {operation['operation_id']} recipe field inventory drifted"
            )
        if recipe["generic_dispatch"] or not recipe["original_caller_authenticated"]:
            raise FreezeError(
                f"operation {operation['operation_id']} became generic or unauthenticated"
            )
        source = operation["source_requirements"]
        if source["source_present"] or source["implementation_authorized"]:
            raise FreezeError(
                f"operation {operation['operation_id']} overclaims source or authorization"
            )
        recipes.append(recipe["recipe_id"])
        entrypoints.append(recipe["facade_entrypoint"])
    if len(set(recipes)) != 57 or len(set(entrypoints)) != 57:
        raise FreezeError("57 recipe identities or facade entrypoints are not unique")

    stop = "FINALITY_DEPENDENCY_ABI_AND_ADR0020_NOT_FROZEN"
    for operation in operations:
        observed = operation["source_requirements"]["effective_implementation_stops"]
        expected = [stop] if operation["operation_id"] == 22 else []
        if observed != expected:
            raise FreezeError(
                f"operation {operation['operation_id']} effective stop drifted"
            )

    projection = packet["operation_projection"]
    if (
        projection["operation_count"] != len(operations)
        or projection["registry_state_mutability"] != "nonpayable"
        or projection["coordinator_state_mutability"] != "nonpayable"
        or projection["typed_collaborator_call_value_wei"] != 0
        or projection["source_present"]
        or projection["implementation_authorized"]
        or projection["operation_22_effective_stop"] != stop
    ):
        raise FreezeError("57-operation value/source projection drifted")

    directory = matrix["directory"]
    coordinator = matrix["operation_coordinator"]
    archive = matrix["archive"]
    if any(
        directory[field]
        for field in (
            "owns_semantic_authority",
            "semantic_storage",
            "owns_records",
            "owns_replay_state",
            "owns_current_or_latest_state",
            "generic_routing",
            "arbitrary_selector_or_calldata",
            "delegatecall",
            "upgrade_path",
            "mutable_rebinding",
        )
    ):
        raise FreezeError("Registry gained semantic authority or generic mutability")
    if any(
        coordinator[field]
        for field in (
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
        )
    ):
        raise FreezeError("Coordinator gained authority, storage, routing, or mutability")
    if any(
        archive[field]
        for field in (
            "owns_semantic_authority",
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
        )
    ):
        raise FreezeError("Archive gained semantic or routing authority")

    call_row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
    if call_row != EXPECTED_669_ROW:
        raise FreezeError("issue 669 exact stateless staticcall reservation drifted")


def _check_source_absence(root: Path) -> None:
    for relative in EXPECTED_ABSENT_ARTIST_SOURCES:
        if (root / relative).exists():
            raise FreezeError(f"source-blocked artist component became present: {relative}")
    if (root / COORDINATOR_INTERFACE_PATH).exists():
        raise FreezeError("Coordinator interface became present or was presented as accepted")
    observed = tuple(
        sorted(
            path.relative_to(root).as_posix()
            for path in (root / ARTIST_SOURCE_ROOT).rglob("*.sol")
        )
    )
    if observed != EXPECTED_PRESENT_ARTIST_SOURCES:
        raise FreezeError(
            f"canonical artist source set drifted: observed={observed}, "
            f"expected={EXPECTED_PRESENT_ARTIST_SOURCES}"
        )


def check(root: Path) -> dict[str, int]:
    packet_path = root / PACKET_PATH
    schema_path = root / SCHEMA_PATH
    matrix_path = root / MATRIX_PATH
    packet = load_strict_json(packet_path)
    schema = load_strict_json(schema_path)
    matrix = load_strict_json(matrix_path)
    if not isinstance(packet, dict) or not isinstance(schema, dict) or not isinstance(matrix, dict):
        raise FreezeError("packet, schema, and semantic-owner matrix must be JSON objects")

    _check_meta(packet, schema, schema_path)
    _validate_schema(packet, schema)
    _check_authorities(root, packet)
    _check_register(packet)
    _check_matrix_projection(matrix, packet)
    _check_source_absence(root)
    return {
        "authority_bindings": len(packet["authority_bindings"]),
        "phases": len(packet["phase_order"]),
        "decision_rows": len(packet["decision_rows"]),
        "accepted_decisions": sum(row["accepted"] for row in packet["decision_rows"]),
        "unresolved_decisions": sum(
            row["decision_status"] == "unresolved" for row in packet["decision_rows"]
        ),
        "operations": len(matrix["operations"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="repository root (defaults to the checker repository)",
    )
    args = parser.parse_args(argv)
    try:
        counts = check(args.root.resolve())
    except FreezeError as exc:
        print(f"artist shared-mechanics freeze check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "artist shared-mechanics freeze check passed: "
        f"{counts['authority_bindings']} authority bindings, "
        f"{counts['phases']} dependency phases, "
        f"{counts['decision_rows']} decision rows, "
        f"{counts['accepted_decisions']} accepted and "
        f"{counts['unresolved_decisions']} unresolved source-blocking decisions, "
        f"{counts['operations']} operations; source remains unauthorized"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
