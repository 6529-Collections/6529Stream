#!/usr/bin/env python3
"""Fail-closed checker for global artist semantic-domain ownership."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator

MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")
SCHEMA_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.schema.json")
SOURCE_PATH = Path(
    "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json"
)
ARCHIVE_SOURCE_PATH = Path("smart-contracts/domains/artist/StreamArtistArchiveV2.sol")
MATRIX_SCHEMA = "6529stream.artist-semantic-owner-matrix.v2"
MATRIX_STATUS = "PROPOSED_ARCHITECTURE_ONLY"
MATRIX_MATURITY = "pre_audit_implementation_blocked"
JSON_SCHEMA_ID = "https://6529.io/schemas/artist-semantic-owner-matrix-v2.schema.json"
SOURCE_SHA256 = "34e768291af8fd0327cbd6d99177d4a829fa8d8076fdc18da58bf74912efa8df"
SCHEMA_SHA256 = "ae3810abfabbe9f737d7f7d4553b3d4ad93cf1fee4664638dcd3186ad171f2f3"
ARCHITECTURE_SHA256 = "6f79bdad52d6ce49cf8f45014325223f084ec5557d5a773eafea0ae63b5b824c"
OWNERSHIP_SHA256 = "c0cf8f4018bd8c6233a39bbbfc8147e043323a5ef487ea1bbb79a94e50b11749"
RECIPES_SHA256 = "f1111e5012dff870f416b3ca197aed1223671a6cf85919dae37322ba9def5a81"
PROVIDERS_SHA256 = "2708f48bafc5aa170471862078dace4a643382ba4b1b49eeb4cc6b75d777d190"
TOP_LEVEL_FIELDS = frozenset(
    {
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
    }
)
DOMAIN_ORDER = (
    "binding_lifecycle",
    "collaborator_lifecycle",
    "identity_authority",
    "acceptance_lifecycle",
    "attribution_lifecycle",
    "payout_lifecycle",
    "consent_finality",
)
DOMAIN_OWNERS = {
    "binding_lifecycle": "StreamArtistBindingLifecycle",
    "collaborator_lifecycle": "StreamArtistCollaboratorLifecycle",
    "identity_authority": "StreamArtistIdentityAuthority",
    "acceptance_lifecycle": "StreamArtistAcceptanceLifecycle",
    "attribution_lifecycle": "StreamArtistAttributionLifecycle",
    "payout_lifecycle": "StreamArtistPayoutLifecycle",
    "consent_finality": "StreamArtistConsentFinalityLifecycle",
}
DEPENDENCY_SNAPSHOTS = {
    "CORE": "external:core",
    "GOVERNANCE": "external:governance",
    "FINALITY": "external:finality",
    "IMPORT": "external:import_continuity",
    "SIGNER": "validation:artist_erc1271",
}
PROVIDER_SNAPSHOTS = {
    "provider:role_registry": (
        "authority:role_registry:ROLE_ARTIST_REGISTRY_ADMIN",
        "authority:role_registry:ROLE_ATTRIBUTION_ARBITER",
        "authority:role_registry:ROLE_ARTIST_DORMANCY_ADMIN",
    ),
    "provider:core": ("external:core",),
    "provider:governance_v2": ("external:governance",),
    "provider:finality_registry": ("external:finality",),
    "provider:import_continuity": ("external:import_continuity",),
}
EXTERNAL_SURFACE_PROVIDERS = {
    "external:core": "provider:core",
    "external:governance": "provider:governance_v2",
    "external:finality": "provider:finality_registry",
    "external:import_continuity": "provider:import_continuity",
}
PLATFORM_ROLE_SNAPSHOTS = {
    1: ("authority:role_registry:ROLE_ARTIST_REGISTRY_ADMIN",),
    5: ("authority:role_registry:ROLE_ARTIST_REGISTRY_ADMIN",),
    8: ("authority:role_registry:ROLE_ARTIST_REGISTRY_ADMIN",),
    11: ("authority:role_registry:ROLE_ATTRIBUTION_ARBITER",),
    23: ("authority:role_registry:ROLE_ATTRIBUTION_ARBITER",),
    41: ("authority:role_registry:ROLE_ARTIST_DORMANCY_ADMIN",),
    53: ("authority:role_registry:ROLE_ATTRIBUTION_ARBITER",),
}
ROLE_IDS = {
    "ROLE_ARTIST_REGISTRY_ADMIN": "0x0867ba965af47ef1093061999c8839c3895b7acb6ac5bfd4c780e8a9e2b9b5f9",
    "ROLE_ATTRIBUTION_ARBITER": "0x3b4801e9987627c0dfb7f0545a32cb92747d97e9c62931a44aaf4dd11a955a36",
    "ROLE_ARTIST_DORMANCY_ADMIN": "0x997fd45a7bcdd3c06c0200b667a5d02a80dcc4828476272710418a58d26ac8f9",
}
SPECIAL_RECIPE_OWNERS = {
    1: [
        "identity_authority",
        "binding_lifecycle",
        "attribution_lifecycle",
    ],
    2: [
        "identity_authority",
        "acceptance_lifecycle",
        "binding_lifecycle",
        "attribution_lifecycle",
    ],
    6: ["identity_authority", "collaborator_lifecycle"],
    7: [
        "identity_authority",
        "acceptance_lifecycle",
        "collaborator_lifecycle",
        "binding_lifecycle",
        "attribution_lifecycle",
    ],
    13: ["consent_finality", "attribution_lifecycle"],
}


class MatrixError(ValueError):
    """Raised when the proposed matrix is not exact."""


def _reject_constant(value: str) -> Any:
    raise MatrixError(f"non-finite JSON number is forbidden: {value}")


def _reject_float(value: str) -> Any:
    raise MatrixError(f"floating-point JSON number is forbidden: {value}")


def _strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise MatrixError(f"duplicate JSON member is forbidden: {key}")
        result[key] = value
    return result


def _walk_numbers(value: Any, path: str = "$") -> None:
    if isinstance(value, bool) or value is None or isinstance(value, str):
        return
    if isinstance(value, int):
        if abs(value) > (2**53 - 1):
            raise MatrixError(f"unsafe JSON integer at {path}")
        return
    if isinstance(value, float):
        if not math.isfinite(value):
            raise MatrixError(f"non-finite JSON number at {path}")
        raise MatrixError(f"floating-point JSON number at {path}")
    if isinstance(value, list):
        for index, item in enumerate(value):
            _walk_numbers(item, f"{path}[{index}]")
        return
    if isinstance(value, dict):
        for key, item in value.items():
            _walk_numbers(item, f"{path}.{key}")
        return
    raise MatrixError(f"unsupported JSON value at {path}")


def load_strict_json(path: Path) -> Any:
    try:
        raw = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise MatrixError(f"cannot read UTF-8 JSON {path}: {exc}") from exc
    try:
        value = json.loads(
            raw,
            object_pairs_hook=_strict_object,
            parse_constant=_reject_constant,
            parse_float=_reject_float,
        )
    except (json.JSONDecodeError, MatrixError) as exc:
        raise MatrixError(f"invalid strict JSON {path}: {exc}") from exc
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


def _split_semicolon(value: str) -> list[str]:
    return [item.strip() for item in value.split(";") if item.strip()]


def _split_pipe(value: str) -> list[str]:
    return [item for item in value.split("|") if item]


def _source_row(columns: list[str], row: list[Any], index: int) -> dict[str, Any]:
    if len(row) != len(columns):
        raise MatrixError(f"source operation {index} does not have all 18 columns")
    return dict(zip(columns, row, strict=True))


def _validate_schema(matrix: Any, schema: Any) -> None:
    validator = Draft202012Validator(schema)
    errors = sorted(validator.iter_errors(matrix), key=lambda item: list(item.path))
    if errors:
        first = errors[0]
        location = "$" + "".join(f"[{part!r}]" for part in first.path)
        raise MatrixError(f"schema violation at {location}: {first.message}")


def _unique_map(rows: list[dict[str, Any]], field: str, label: str) -> dict[str, dict[str, Any]]:
    result: dict[str, dict[str, Any]] = {}
    for row in rows:
        key = row[field]
        if key in result:
            raise MatrixError(f"{label} {key} has more than one owner row")
        result[key] = row
    return result


def _check_meta(matrix: dict[str, Any], schema: dict[str, Any], schema_path: Path) -> None:
    if set(matrix) != TOP_LEVEL_FIELDS:
        missing = sorted(TOP_LEVEL_FIELDS - set(matrix))
        extra = sorted(set(matrix) - TOP_LEVEL_FIELDS)
        raise MatrixError(f"critical top-level fields drifted: missing={missing}, extra={extra}")
    if matrix.get("schema") != MATRIX_SCHEMA:
        raise MatrixError("matrix schema id drifted")
    if matrix.get("status") != MATRIX_STATUS:
        raise MatrixError("matrix must remain Proposed architecture only")
    if matrix.get("maturity") != MATRIX_MATURITY:
        raise MatrixError("matrix must remain pre-audit and implementation-blocked")
    if schema.get("$id") != JSON_SCHEMA_ID:
        raise MatrixError("JSON Schema $id drifted")
    schema_digest = hashlib.sha256(schema_path.read_bytes()).hexdigest()
    if schema_digest != SCHEMA_SHA256:
        raise MatrixError(
            f"schema sha256 drifted: {schema_digest} != {SCHEMA_SHA256}"
        )


def _check_source_freeze(
    root: Path,
    matrix: dict[str, Any],
    source: dict[str, Any],
    source_path: Path,
) -> tuple[list[str], list[dict[str, Any]]]:
    digest = hashlib.sha256(source_path.read_bytes()).hexdigest()
    if digest != SOURCE_SHA256:
        raise MatrixError(f"source freeze sha256 drifted: {digest} != {SOURCE_SHA256}")
    columns = source.get("operation_columns")
    rows = source.get("operations")
    if not isinstance(columns, list) or len(columns) != 18 or len(set(columns)) != 18:
        raise MatrixError("source operation columns must remain 18 unique names")
    if not isinstance(rows, list) or len(rows) != 57:
        raise MatrixError("source operation matrix must retain 57 rows")

    freeze = matrix["source_freeze"]
    expected = {
        "path": SOURCE_PATH.as_posix(),
        "schema": source["schema"],
        "sha256": SOURCE_SHA256,
        "source_commit": source["source_commit"],
        "operation_count": 57,
        "operation_columns": columns,
        "authority": source["authority"],
        "implementation_stop_overlays": source["implementation_stop_overlays"],
        "effective_implementation_stops": source["effective_implementation_stops"],
        "dependency_profiles": source["dependency_profiles"],
    }
    if freeze != expected:
        raise MatrixError("source freeze context drifted or omitted a required field")
    source_rows = [_source_row(columns, row, index) for index, row in enumerate(rows, 1)]
    if [row["id"] for row in source_rows] != list(range(1, 58)):
        raise MatrixError("source operation ids must remain ordered 1..57")
    return columns, source_rows


def _check_source_requirements(root: Path, matrix: dict[str, Any]) -> None:
    requirements = matrix["source_requirements"]
    expected_components = [
        (
            "registry_directory",
            "smart-contracts/domains/artist/StreamArtistRegistry.sol",
            False,
        ),
        (
            "operation_coordinator",
            "smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol",
            False,
        ),
        ("archive", ARCHIVE_SOURCE_PATH.as_posix(), True),
        (
            "binding_lifecycle",
            "smart-contracts/domains/artist/StreamArtistBindingLifecycle.sol",
            False,
        ),
        (
            "collaborator_lifecycle",
            "smart-contracts/domains/artist/StreamArtistCollaboratorLifecycle.sol",
            False,
        ),
        (
            "identity_authority",
            "smart-contracts/domains/artist/StreamArtistIdentityAuthority.sol",
            False,
        ),
        (
            "acceptance_lifecycle",
            "smart-contracts/domains/artist/StreamArtistAcceptanceLifecycle.sol",
            False,
        ),
        (
            "attribution_lifecycle",
            "smart-contracts/domains/artist/StreamArtistAttributionLifecycle.sol",
            False,
        ),
        (
            "payout_lifecycle",
            "smart-contracts/domains/artist/StreamArtistPayoutLifecycle.sol",
            False,
        ),
        (
            "consent_finality",
            "smart-contracts/domains/artist/StreamArtistConsentFinalityLifecycle.sol",
            False,
        ),
        (
            "stateless_validator",
            "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol",
            False,
        ),
    ]
    actual_components = [
        (row["component"], row["path"], row["source_present"])
        for row in requirements["components"]
    ]
    if actual_components != expected_components:
        raise MatrixError("source component presence/order drifted")
    if requirements["all_source_absent"]:
        raise MatrixError("source requirements must acknowledge the isolated Archive source")
    if requirements["interface_and_storage_freeze_complete"]:
        raise MatrixError("complete artist topology interface/storage freeze is overclaimed")
    if requirements["implementation_authorized"]:
        raise MatrixError("complete artist topology implementation is overclaimed")
    for component, relative, source_present in expected_components:
        observed = (root / relative).is_file()
        if observed != source_present:
            state = "present" if observed else "absent"
            expected = "present" if source_present else "absent"
            raise MatrixError(
                f"{component} source is {state}; exact source requirement is {expected}: {relative}"
            )
    artist_root = root / requirements["canonical_root"]
    observed_artist_sources = sorted(
        path.relative_to(root).as_posix() for path in artist_root.rglob("*.sol")
    )
    expected_artist_sources = [ARCHIVE_SOURCE_PATH.as_posix()]
    if observed_artist_sources != expected_artist_sources:
        raise MatrixError(
            "canonical artist source set drifted: "
            f"observed={observed_artist_sources}, expected={expected_artist_sources}"
        )


def _check_global_ownership(matrix: dict[str, Any]) -> tuple[dict[str, Any], ...]:
    domains = matrix["semantic_domains"]
    if [item["domain_id"] for item in domains] != list(DOMAIN_ORDER):
        raise MatrixError("semantic domains are not in the exact coordinator snapshot order")
    if len({item["owner"] for item in domains}) != 7:
        raise MatrixError("each semantic domain must have a distinct sole owner")
    domain_map = _unique_map(domains, "domain_id", "semantic domain")
    for index, domain_id in enumerate(DOMAIN_ORDER, 1):
        row = domain_map[domain_id]
        if row["owner"] != DOMAIN_OWNERS[domain_id]:
            raise MatrixError(f"{domain_id} owner drifted")
        if row["rollback_owner"] != row["owner"]:
            raise MatrixError(f"{domain_id} rollback owner split from state owner")
        if row["module_reads_other_domains"]:
            raise MatrixError(f"{domain_id} may not read another owner module")
        if row["coordinator_snapshot_order"] != index:
            raise MatrixError(f"{domain_id} snapshot order drifted")

    current = _unique_map(
        matrix["current_state_surfaces"], "surface_id", "current-state surface"
    )
    for surface_id, row in current.items():
        if row["owner_kind"] == "artist_semantic_domain":
            domain_id = row["owner_domain"]
            if surface_id != f"domain:{domain_id}" or row["owner"] != DOMAIN_OWNERS[domain_id]:
                raise MatrixError(f"current-state surface {surface_id} owner split")
            if "provider_id" in row:
                raise MatrixError(f"artist current-state surface {surface_id} gained an external provider")
        else:
            if row["owner_domain"] is not None:
                raise MatrixError(f"external current-state surface {surface_id} gained an artist owner")
            if row.get("provider_id") != EXTERNAL_SURFACE_PROVIDERS.get(surface_id):
                raise MatrixError(f"external current-state surface {surface_id} provider is not exact")

    records = _unique_map(matrix["record_surfaces"], "surface_id", "record surface")
    events = _unique_map(matrix["event_surfaces"], "surface_id", "event surface")
    replay = _unique_map(matrix["replay_surfaces"], "surface_id", "replay surface")
    for label, surfaces, owner_field, contract_field in (
        ("record", records, "owner_domain", "owner_contract"),
        ("event", events, "emitter_domain", "emitter_contract"),
        ("replay", replay, "owner_domain", "owner_contract"),
    ):
        for surface, row in surfaces.items():
            domain_id = row[owner_field]
            if row[contract_field] != DOMAIN_OWNERS[domain_id]:
                raise MatrixError(f"{label} surface {surface} splits owner and contract")

    ownership = {
        key: matrix[key]
        for key in (
            "semantic_domains",
            "current_state_surfaces",
            "record_surfaces",
            "event_surfaces",
            "replay_surfaces",
        )
    }
    if _canonical_digest(ownership) != OWNERSHIP_SHA256:
        raise MatrixError("global semantic/record/replay/event ownership map drifted")
    return domain_map, current, records, events, replay


def _check_external_providers(root: Path, matrix: dict[str, Any]) -> set[str]:
    providers = matrix["immutable_external_providers"]
    if [item["provider_id"] for item in providers] != list(PROVIDER_SNAPSHOTS):
        raise MatrixError("immutable external provider inventory/order drifted")
    provider_map = _unique_map(providers, "provider_id", "external provider")
    all_snapshots: set[str] = set()
    for provider_id, expected_snapshots in PROVIDER_SNAPSHOTS.items():
        provider = provider_map[provider_id]
        if tuple(provider["snapshot_ids"]) != expected_snapshots:
            raise MatrixError(f"{provider_id} snapshot inventory drifted")
        if (
            not provider["immutable"]
            or provider["candidate_values_present"]
            or provider["implementable"]
            or not provider["reconciliation_stop"]
        ):
            raise MatrixError(f"{provider_id} lost immutable incomplete posture")
        for pin_name in ("address_pin", "runtime_codehash_pin", "binding_pin"):
            pin = provider[pin_name]
            if pin["value"] is not None or pin["status"] != "required_candidate_value_absent":
                raise MatrixError(f"{provider_id} {pin_name} pretends to have candidate evidence")
        interface_pin = provider["interface_pin"]
        source_path = interface_pin["source_path"]
        if source_path is not None:
            try:
                payload = (root / source_path).read_bytes()
            except OSError as exc:
                raise MatrixError(
                    f"{provider_id} interface source is unreadable: {source_path}"
                ) from exc
            digest = hashlib.sha256(payload).hexdigest()
            if digest != interface_pin["source_sha256"]:
                raise MatrixError(f"{provider_id} interface source sha256 drifted")
        elif provider_id != "provider:import_continuity":
            raise MatrixError(f"{provider_id} lost its exact interface authority")
        for snapshot_id in provider["snapshot_ids"]:
            if snapshot_id in all_snapshots:
                raise MatrixError(f"provider snapshot {snapshot_id} has multiple providers")
            all_snapshots.add(snapshot_id)

    authority_rows = _unique_map(
        matrix["authority_surfaces"], "snapshot_id", "platform-role authority surface"
    )
    expected_authority = set(PROVIDER_SNAPSHOTS["provider:role_registry"])
    if set(authority_rows) != expected_authority:
        raise MatrixError("platform-role authority surface inventory drifted")
    for snapshot_id, row in authority_rows.items():
        role = snapshot_id.rsplit(":", 1)[-1]
        if (
            row["provider_id"] != "provider:role_registry"
            or row["role_literal"] != role
            or row["role_id"] != ROLE_IDS[role]
            or row["membership_call"] != "hasRole(bytes32,address)"
            or row["revision_call"] != "roleMutationState(bytes32)"
            or row["original_caller_subject"] != "authenticated_original_caller"
            or not row["original_caller_required"]
        ):
            raise MatrixError(f"platform-role authority surface {snapshot_id} drifted")

    provider_view = {
        "immutable_external_providers": providers,
        "authority_surfaces": matrix["authority_surfaces"],
    }
    if _canonical_digest(provider_view) != PROVIDERS_SHA256:
        raise MatrixError("immutable provider identities or role surfaces drifted")
    return all_snapshots


def _check_record_binding(
    operation_id: int,
    source_value: str,
    binding: dict[str, Any],
    records: dict[str, Any],
    role: str,
) -> None:
    if binding["role"] != role or binding["source"] != source_value:
        raise MatrixError(f"operation {operation_id} {role} record source drifted")
    if source_value == "NONE":
        expected_mode = "none"
        expected_surface = None
    else:
        expected_mode = "existing" if source_value.startswith("EXISTING:") else "create"
        name = source_value.removeprefix("EXISTING:")
        expected_surface = f"record:{name}"
    if binding["mode"] != expected_mode or binding["surface_id"] != expected_surface:
        raise MatrixError(f"operation {operation_id} {role} record mode drifted")
    if expected_surface is None:
        if binding["owner_domain"] is not None:
            raise MatrixError(f"operation {operation_id} NONE record gained an owner")
    else:
        surface = records.get(expected_surface)
        if surface is None or binding["owner_domain"] != surface["owner_domain"]:
            raise MatrixError(f"operation {operation_id} {role} record owner split")


def _check_operation(
    root: Path,
    operation: dict[str, Any],
    source_row: dict[str, Any],
    matrix: dict[str, Any],
    domain_map: dict[str, Any],
    current: dict[str, Any],
    records: dict[str, Any],
    events: dict[str, Any],
    replay: dict[str, Any],
    provider_snapshots: set[str],
) -> None:
    operation_id = source_row["id"]
    if operation["operation_id"] != operation_id or operation["write"] != source_row["write"]:
        raise MatrixError(f"operation {operation_id} identity drifted")
    if operation["source_row"] != source_row:
        raise MatrixError(f"operation {operation_id} failed exact 18-column source binding")

    recipe = operation["coordinator_recipe"]
    snapshots = recipe["snapshot_ids"]
    if len(snapshots) != len(set(snapshots)):
        raise MatrixError(f"operation {operation_id} has duplicate snapshots")
    if recipe["generic_dispatch"] or not recipe["original_caller_authenticated"]:
        raise MatrixError(f"operation {operation_id} recipe became generic or unauthenticated")

    current_facts = _split_semicolon(source_row["current_state_facts"])
    current_bindings = operation["current_state_fact_bindings"]
    if [item["source_index"] for item in current_bindings] != list(range(len(current_facts))):
        raise MatrixError(f"operation {operation_id} current-state facts are unresolved")
    if [item["source_fact"] for item in current_bindings] != current_facts:
        raise MatrixError(f"operation {operation_id} current-state source facts drifted")
    for item in current_bindings:
        surface_ids = item["surface_ids"]
        if not surface_ids:
            raise MatrixError(f"operation {operation_id} current fact is unresolved")
        for surface_id in surface_ids:
            if surface_id not in current or surface_id not in snapshots:
                raise MatrixError(
                    f"operation {operation_id} current fact uses an unowned or unsnapshotted surface"
                )

    replay_facts = _split_semicolon(source_row["replay_facts"])
    replay_bindings = operation["replay_fact_bindings"]
    if [item["source_index"] for item in replay_bindings] != list(range(len(replay_facts))):
        raise MatrixError(f"operation {operation_id} replay facts are unresolved")
    if [item["source_fact"] for item in replay_bindings] != replay_facts:
        raise MatrixError(f"operation {operation_id} replay source facts drifted")
    referenced_replay: set[str] = set()
    for item in replay_bindings:
        if not item["surface_ids"]:
            raise MatrixError(f"operation {operation_id} replay fact has no owner surface")
        for surface_id in item["surface_ids"]:
            if surface_id not in replay:
                raise MatrixError(f"operation {operation_id} replay surface is unresolved")
            referenced_replay.add(surface_id)

    bindings = operation["record_bindings"]
    _check_record_binding(operation_id, source_row["primary_record"], bindings[0], records, "primary")
    _check_record_binding(operation_id, source_row["secondary_record"], bindings[1], records, "secondary")

    event_names = _split_pipe(source_row["events"])
    event_bindings = operation["event_bindings"]
    if [item["source_index"] for item in event_bindings] != list(range(len(event_names))):
        raise MatrixError(f"operation {operation_id} event fields are unresolved")
    if [item["event"] for item in event_bindings] != event_names:
        raise MatrixError(f"operation {operation_id} source events drifted")
    referenced_events: set[str] = set()
    for item in event_bindings:
        surface_id = item["surface_id"]
        surface = events.get(surface_id)
        if surface is None or item["emitter_domain"] != surface["emitter_domain"]:
            raise MatrixError(f"operation {operation_id} event owner split")
        referenced_events.add(surface_id)

    actions = recipe["actions"]
    if [item["step"] for item in actions] != list(range(1, len(actions) + 1)):
        raise MatrixError(f"operation {operation_id} action order is not exact")
    if len({item["owner_domain"] for item in actions}) != len(actions):
        raise MatrixError(f"operation {operation_id} calls one owner more than once")
    action_surfaces: set[str] = set()
    emitted: set[str] = set()
    for action in actions:
        domain_id = action["owner_domain"]
        if action["owner_contract"] != DOMAIN_OWNERS[domain_id]:
            raise MatrixError(f"operation {operation_id} action owner contract drifted")
        if (
            action["validates_coordinator"] != "StreamArtistOperationCoordinator"
            or not action["validates_original_caller"]
            or action["validates_revision_snapshot"] != f"domain:{domain_id}"
        ):
            raise MatrixError(
                f"operation {operation_id} owner does not validate coordinator/caller/revision"
            )
        for surface in action["write_surfaces"]:
            if surface.startswith("state:"):
                owner = surface.removeprefix("state:")
            elif surface.startswith("record:"):
                if surface not in records:
                    raise MatrixError(
                        f"operation {operation_id} writes unowned record surface {surface}"
                    )
                owner = records[surface]["owner_domain"]
            elif surface.startswith("event:"):
                if surface not in events:
                    raise MatrixError(
                        f"operation {operation_id} writes unowned event surface {surface}"
                    )
                owner = events[surface]["emitter_domain"]
            elif surface.startswith("replay:"):
                replay_id = surface.removeprefix("replay:")
                if replay_id not in replay:
                    raise MatrixError(
                        f"operation {operation_id} writes unowned replay surface {surface}"
                    )
                owner = replay[replay_id]["owner_domain"]
            else:
                raise MatrixError(f"operation {operation_id} has unknown write surface {surface}")
            if owner != domain_id:
                raise MatrixError(
                    f"operation {operation_id} owner {domain_id} writes {owner}'s surface"
                )
            action_surfaces.add(surface)
        for event in action["emits"]:
            surface_id = f"event:{event}"
            if surface_id not in events or events[surface_id]["emitter_domain"] != domain_id:
                raise MatrixError(f"operation {operation_id} emits another owner's event")
            emitted.add(surface_id)

    required_writes = {f"replay:{surface}" for surface in referenced_replay}
    required_writes.update(
        binding["surface_id"]
        for binding in bindings
        if binding["mode"] == "create"
    )
    required_writes.update(referenced_events)
    if not required_writes.issubset(action_surfaces):
        missing = sorted(required_writes - action_surfaces)
        raise MatrixError(f"operation {operation_id} recipe omitted owned writes: {missing}")
    if emitted != referenced_events:
        raise MatrixError(f"operation {operation_id} normative event emitters are incomplete")

    dependency_tokens = (
        ["LOCAL"]
        if source_row["dependencies"] == "LOCAL"
        else _split_pipe(source_row["dependencies"])
    )
    requirements = operation["source_requirements"]
    if requirements["dependency_tokens"] != dependency_tokens:
        raise MatrixError(f"operation {operation_id} dependency source field drifted")
    if requirements["effective_implementation_stops"] != matrix[
        "source_freeze"
    ]["effective_implementation_stops"][str(operation_id)]:
        raise MatrixError(f"operation {operation_id} effective implementation stops drifted")
    if requirements["source_present"] or requirements["implementation_authorized"]:
        raise MatrixError(f"operation {operation_id} overclaims source or authorization")
    for token in dependency_tokens:
        if token in DEPENDENCY_SNAPSHOTS and DEPENDENCY_SNAPSHOTS[token] not in snapshots:
            raise MatrixError(f"operation {operation_id} omitted {token} typed snapshot")
    expected_external = {
        DEPENDENCY_SNAPSHOTS[token]
        for token in dependency_tokens
        if token in ("CORE", "GOVERNANCE", "FINALITY", "IMPORT")
    }
    actual_external = {item for item in snapshots if item.startswith("external:")}
    if actual_external != expected_external:
        raise MatrixError(f"operation {operation_id} external provider snapshots drifted")
    expected_authority = set(PLATFORM_ROLE_SNAPSHOTS.get(operation_id, ()))
    actual_authority = {item for item in snapshots if item.startswith("authority:")}
    if actual_authority != expected_authority:
        raise MatrixError(f"operation {operation_id} platform-role snapshots drifted")
    if not (actual_external | actual_authority).issubset(provider_snapshots):
        raise MatrixError(f"operation {operation_id} uses an unbound provider snapshot")
    required_paths = requirements["required_source_paths"]
    for baseline in (
        "smart-contracts/domains/artist/StreamArtistRegistry.sol",
        "smart-contracts/domains/artist/StreamArtistOperationCoordinator.sol",
        "smart-contracts/domains/artist/StreamArtistArchiveV2.sol",
    ):
        if baseline not in required_paths:
            raise MatrixError(f"operation {operation_id} omitted required source {baseline}")
    if "SIGNER" in dependency_tokens:
        validator = (
            "smart-contracts/domains/artist/StreamArtistRegistryValidatorBase.sol"
        )
        if validator not in required_paths:
            raise MatrixError(f"operation {operation_id} omitted validator requirement")
    for relative in required_paths:
        if relative == ARCHIVE_SOURCE_PATH.as_posix():
            if not (root / relative).is_file():
                raise MatrixError(
                    f"operation {operation_id} required Archive source is missing: {relative}"
                )
        elif (root / relative).exists():
            raise MatrixError(
                f"operation {operation_id} source requirement is no longer absent: {relative}"
            )


def _check_special_recipes(matrix: dict[str, Any]) -> None:
    operations = {item["operation_id"]: item for item in matrix["operations"]}
    for operation_id, expected in SPECIAL_RECIPE_OWNERS.items():
        actual = [
            action["owner_domain"]
            for action in operations[operation_id]["coordinator_recipe"]["actions"]
        ]
        if actual != expected:
            raise MatrixError(
                f"operation {operation_id} composite recipe owners/order drifted"
            )

    for operation_id in (2, 7):
        primary = operations[operation_id]["record_bindings"][0]
        if (
            primary["surface_id"] != "record:ACCEPTANCE_RECORD_DOMAIN"
            or primary["owner_domain"] != "acceptance_lifecycle"
        ):
            raise MatrixError(
                f"operation {operation_id} split shared ACCEPTANCE_RECORD_DOMAIN"
            )

    snapshots = operations[15]["coordinator_recipe"]["snapshot_ids"]
    try:
        payout_index = snapshots.index("domain:payout_lifecycle")
        consent_index = snapshots.index("domain:consent_finality")
    except ValueError as exc:
        raise MatrixError("operation 15 payout/consent snapshot is incomplete") from exc
    if payout_index >= consent_index:
        raise MatrixError("operation 15 must snapshot payout before consent/finality")

    call_row = matrix["external_dependencies"]["issue_669"]["reserved_call_row"]
    if call_row != {
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
    }:
        raise MatrixError("issue #669 exact staticcall reservation drifted")


def _check_participation(matrix: dict[str, Any]) -> None:
    operations = matrix["operations"]
    for domain in matrix["semantic_domains"]:
        domain_id = domain["domain_id"]
        snapshot_id = f"domain:{domain_id}"
        expected = [
            operation["operation_id"]
            for operation in operations
            if snapshot_id in operation["coordinator_recipe"]["snapshot_ids"]
            or any(
                action["owner_domain"] == domain_id
                for action in operation["coordinator_recipe"]["actions"]
            )
        ]
        if domain["participating_operation_ids"] != expected:
            raise MatrixError(f"{domain_id} participating operation inventory drifted")


def _check_frozen_hashes(matrix: dict[str, Any]) -> None:
    architecture = {
        key: matrix[key]
        for key in (
            "proposed_supersession",
            "directory",
            "operation_coordinator",
            "archive",
            "cross_domain_protocol",
            "constructor_dag",
            "sole_authorities",
            "immutable_external_providers",
            "authority_surfaces",
            "external_dependencies",
            "source_requirements",
            "implementation_stops",
        )
    }
    if _canonical_digest(architecture) != ARCHITECTURE_SHA256:
        raise MatrixError("selected architecture invariants drifted")
    recipes = [
        {
            key: operation[key]
            for key in (
                "operation_id",
                "write",
                "current_state_fact_bindings",
                "replay_fact_bindings",
                "record_bindings",
                "event_bindings",
                "coordinator_recipe",
                "source_requirements",
            )
        }
        for operation in matrix["operations"]
    ]
    if _canonical_digest(recipes) != RECIPES_SHA256:
        raise MatrixError("57 exact coordinator recipes or source bindings drifted")


def check(root: Path) -> dict[str, int]:
    matrix_path = root / MATRIX_PATH
    schema_path = root / SCHEMA_PATH
    source_path = root / SOURCE_PATH
    matrix = load_strict_json(matrix_path)
    schema = load_strict_json(schema_path)
    source = load_strict_json(source_path)
    if not isinstance(matrix, dict) or not isinstance(schema, dict) or not isinstance(source, dict):
        raise MatrixError("matrix, schema, and source freeze must be JSON objects")

    _check_meta(matrix, schema, schema_path)
    _validate_schema(matrix, schema)
    _, source_rows = _check_source_freeze(root, matrix, source, source_path)
    _check_source_requirements(root, matrix)
    domain_map, current, records, events, replay = _check_global_ownership(matrix)
    provider_snapshots = _check_external_providers(root, matrix)

    operations = matrix["operations"]
    if [item["operation_id"] for item in operations] != list(range(1, 58)):
        raise MatrixError("operation recipes must remain unique and ordered 1..57")
    for operation, source_row in zip(operations, source_rows, strict=True):
        _check_operation(
            root,
            operation,
            source_row,
            matrix,
            domain_map,
            current,
            records,
            events,
            replay,
            provider_snapshots,
        )

    source_record_names = {
        value.removeprefix("EXISTING:")
        for row in source_rows
        for value in (row["primary_record"], row["secondary_record"])
        if value != "NONE"
    }
    if {row["record_domain"] for row in matrix["record_surfaces"]} != source_record_names:
        raise MatrixError("one or more frozen record domains are unresolved")
    source_events = {
        event for row in source_rows for event in _split_pipe(row["events"])
    }
    if {row["event"] for row in matrix["event_surfaces"]} != source_events:
        raise MatrixError("one or more frozen event domains are unresolved")
    referenced_current = {
        surface
        for operation in operations
        for binding in operation["current_state_fact_bindings"]
        for surface in binding["surface_ids"]
    }
    if {row["surface_id"] for row in matrix["current_state_surfaces"]} != referenced_current:
        raise MatrixError("global current-state surface inventory is unresolved or unused")
    referenced_replay = {
        surface
        for operation in operations
        for binding in operation["replay_fact_bindings"]
        for surface in binding["surface_ids"]
    }
    if set(replay) != referenced_replay:
        raise MatrixError("global replay surface inventory is unresolved or unused")

    _check_special_recipes(matrix)
    _check_participation(matrix)
    _check_frozen_hashes(matrix)
    return {
        "sole_owners": len(matrix["semantic_domains"]),
        "immutable_external_providers": len(matrix["immutable_external_providers"]),
        "current_state_surfaces": len(matrix["current_state_surfaces"]),
        "platform_role_surfaces": len(matrix["authority_surfaces"]),
        "records": len(matrix["record_surfaces"]),
        "events": len(matrix["event_surfaces"]),
        "replay_surfaces": len(matrix["replay_surfaces"]),
        "recipes": len(matrix["operations"]),
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
    except MatrixError as exc:
        print(f"artist semantic owner matrix check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "artist semantic owner matrix check passed: "
        f"{counts['sole_owners']} sole owners, "
        f"{counts['immutable_external_providers']} immutable external providers, "
        f"{counts['current_state_surfaces']} current-state surfaces, "
        f"{counts['platform_role_surfaces']} platform-role surfaces, "
        f"{counts['records']} records, {counts['events']} events, "
        f"{counts['replay_surfaces']} replay surfaces, "
        f"{counts['recipes']} recipes; "
        "architecture remains Proposed"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
