#!/usr/bin/env python3
"""Validate the exact production GGP/GTP inventory and candidate bindings."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
from pathlib import Path
from typing import Any, Final, Sequence

import check_governed_parameter_identifiers as identifier_checker

try:
    from jsonschema import Draft202012Validator
    from jsonschema.exceptions import SchemaError
except ModuleNotFoundError:  # pragma: no cover - only a broken pinned toolchain.
    Draft202012Validator = None
    SchemaError = Exception


DEFAULT_INVENTORY: Final = Path(
    "release-artifacts/governed-parameter-inventory.json"
)
DEFAULT_SCHEMA: Final = Path(
    "release-artifacts/schema/governed-parameter-inventory.v1.schema.json"
)
GENESIS_PROFILE: Final = Path("release-artifacts/genesis-deployment-profile.json")
SCHEMA_VERSION: Final = "6529stream.governed-parameter-inventory.v1"
GENESIS_PROFILE_SCHEMA: Final = "6529stream.genesis-deployment-profile.v2"
JSON_SCHEMA_DRAFT_2020_12: Final = (
    "https://json-schema.org/draft/2020-12/schema"
)
MEASUREMENT_EVIDENCE_SCHEMA: Final = (
    "6529stream.governed-parameter-measurement-evidence.v1"
)
FIXED_STIPEND_EVIDENCE_SCHEMA: Final = (
    "6529stream.governed-parameter-fixed-stipend-evidence.v1"
)
STRUCTURED_PRODUCTION_CANDIDATE_BLOCKER: Final = (
    "candidate_binding.status 'complete' is unsupported until issue #656 "
    "defines and checks a structured production deployment candidate model"
)
STRUCTURED_EVIDENCE_BLOCKER: Final = (
    "complete governed-parameter evidence is unsupported in this structural "
    "slice until issue #684 defines candidate-instance-bound measurement, "
    "cadence, reproduction, and reachable-raise-chain evidence"
)
PRODUCTION_CANDIDATE_ISSUE: Final = (
    "https://github.com/6529-Collections/6529Stream/issues/656"
)
EVIDENCE_ROOT: Final = "release-artifacts/evidence/governed-parameters"
CANDIDATE_ROOT: Final = "deployments/config"
EXPECTED_GGP_COUNT: Final = 22
EXPECTED_GTP_COUNT: Final = 3
EXPECTED_PARAMETER_COUNT: Final = 25
EXPECTED_HOST_BINDING_COUNT: Final = 50
UINT256_MAX: Final = (1 << 256) - 1
UINT64_MAX: Final = (1 << 64) - 1

EXPECTED_NORMATIVE_SOURCES: Final = (
    {
        "path": "docs/stream-long-term-architecture.md",
        "anchor": "LTA-GGP",
    },
    {
        "path": "docs/stream-long-term-architecture.md",
        "anchor": "LTA-GTP",
    },
    {
        "path": "docs/adr/0017-raise-only-parameter-governance.md",
        "anchor": "Decision",
    },
    {
        "path": "release-artifacts/genesis-deployment-profile.json",
        "anchor": GENESIS_PROFILE_SCHEMA,
    },
)

FACT_STATUSES: Final = frozenset(
    {"complete", "planning", "missing", "not_available"}
)
FAILURE_CLASSES: Final = {
    1: "FORWARDING_CAP",
    2: "FAIL_CLOSED_PRECHECK",
    3: "MIN_GAS_GATE",
}
SHA256_RE: Final = re.compile(r"[0-9a-f]{64}")
KECCAK_RE: Final = re.compile(r"0x[0-9a-f]{64}")
ADDRESS_RE: Final = re.compile(r"0x[0-9a-f]{40}")
COMMIT_RE: Final = re.compile(r"[0-9a-f]{40}")
CANDIDATE_ID_RE: Final = re.compile(r"[a-z0-9][a-z0-9._-]{0,127}")
SOLIDITY_NAME_RE: Final = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")
REPO_PATH_PATTERN: Final = (
    r"^(?!/)"
    r'(?!.*[\u0000-\u001F\u007F<>:"\\|?*])'
    r"(?!.*//)"
    r"(?!.*\/$)"
    r"(?!\.\.?(?:/|$))"
    r"(?!.*\/\.\.?(?:/|$))"
    r"(?![^/]*[. ](?:/|$))"
    r"(?!.*\/[^/]*[. ](?:/|$))"
    r"(?!(?:[Cc][Oo][Nn]|[Pp][Rr][Nn]|[Aa][Uu][Xx]|[Nn][Uu][Ll]|"
    r"[Cc][Oo][Mm][1-9]|[Ll][Pp][Tt][1-9])[ ]*(?:\.|/|$))"
    r"(?!.*\/(?:[Cc][Oo][Nn]|[Pp][Rr][Nn]|[Aa][Uu][Xx]|[Nn][Uu][Ll]|"
    r"[Cc][Oo][Mm][1-9]|[Ll][Pp][Tt][1-9])[ ]*(?:\.|/|$))"
    r".+$"
)
REPO_PATH_RE: Final = re.compile(REPO_PATH_PATTERN)

GAS_SCOPE_PREIMAGE: Final = "6529STREAM_GAS_PARAMETER_SCOPE_V2"
GAS_STATE_PREIMAGE: Final = "6529STREAM_GAS_PARAMETER_STATE_V2"
TIME_SCOPE_PREIMAGE: Final = "6529STREAM_TIME_PARAMETER_SCOPE_V2"
TIME_STATE_PREIMAGE: Final = "6529STREAM_TIME_PARAMETER_STATE_V2"


class GovernedParameterInventoryError(RuntimeError):
    """Raised when the governed-parameter inventory is malformed or incomplete."""


class _DuplicateKeyError(ValueError):
    pass


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateKeyError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise GovernedParameterInventoryError(f"cannot read {label}: {exc}") from exc
    try:
        value = json.loads(
            text,
            object_pairs_hook=_object_no_duplicates,
            parse_float=lambda token: (_ for _ in ()).throw(
                ValueError(f"floating-point JSON number {token}")
            ),
            parse_constant=lambda token: (_ for _ in ()).throw(
                ValueError(f"non-finite JSON number {token}")
            ),
        )
    except (json.JSONDecodeError, ValueError, _DuplicateKeyError) as exc:
        raise GovernedParameterInventoryError(f"invalid {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise GovernedParameterInventoryError(f"{label} root must be an object")
    return value


def _expect(condition: bool, message: str) -> None:
    if not condition:
        raise GovernedParameterInventoryError(message)


def _expect_keys(value: Any, expected: set[str], label: str) -> dict[str, Any]:
    _expect(isinstance(value, dict), f"{label} must be an object")
    actual = set(value)
    _expect(
        actual == expected,
        f"{label} keys must be exactly {sorted(expected)!r}, got {sorted(actual)!r}",
    )
    return value


def _expect_string(value: Any, label: str) -> str:
    _expect(isinstance(value, str) and bool(value), f"{label} must be a nonempty string")
    return value


def _expect_int(
    value: Any,
    label: str,
    *,
    minimum: int = 0,
    maximum: int | None = None,
) -> int:
    _expect(
        isinstance(value, int)
        and not isinstance(value, bool)
        and value >= minimum
        and (maximum is None or value <= maximum),
        (
            f"{label} must be an integer >= {minimum}"
            if maximum is None
            else f"{label} must be an integer in [{minimum}, {maximum}]"
        ),
    )
    return value


def _format_json_schema_path(parts: Sequence[Any]) -> str:
    result = "$"
    for part in parts:
        if isinstance(part, int):
            result += f"[{part}]"
        else:
            result += f"[{json.dumps(part, ensure_ascii=True)}]"
    return result


def _validate_schema(schema: dict[str, Any], value: Any, label: str) -> None:
    if Draft202012Validator is None:
        raise GovernedParameterInventoryError(
            "Draft 2020-12 validation requires the pinned jsonschema "
            "toolchain dependency"
        )
    if schema.get("$schema") != JSON_SCHEMA_DRAFT_2020_12:
        raise GovernedParameterInventoryError(
            f"governed parameter inventory schema must declare "
            f"{JSON_SCHEMA_DRAFT_2020_12}"
        )
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as exc:
        raise GovernedParameterInventoryError(
            f"governed parameter inventory schema is not valid Draft 2020-12: "
            f"{exc.message}"
        ) from exc
    errors = sorted(
        Draft202012Validator(schema).iter_errors(value),
        key=lambda error: (
            _format_json_schema_path(tuple(error.absolute_path)),
            error.message,
        ),
    )
    if errors:
        error = errors[0]
        location = _format_json_schema_path(tuple(error.absolute_path))
        raise GovernedParameterInventoryError(
            f"{label} does not satisfy its Draft 2020-12 schema at "
            f"{location}: {error.message}"
        )


def _path_is_link_or_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attributes = getattr(os.lstat(path), "st_file_attributes", 0)
    except FileNotFoundError:
        return False
    reparse_flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(reparse_flag and attributes & reparse_flag)


def _resolve_reference(
    repo_root: Path,
    value: Any,
    label: str,
    *,
    required_root: str,
) -> Path:
    raw = _expect_string(value, label)
    _expect(
        REPO_PATH_RE.fullmatch(raw) is not None,
        (
            f"{label} must be a normalized portable forward-slash "
            "repository-relative path"
        ),
    )
    _expect(
        raw.startswith(required_root + "/"),
        f"{label} must be below {required_root}/",
    )
    relative = Path(*raw.split("/"))
    _expect(
        not relative.drive
        and not relative.root
        and not relative.anchor
        and all(part not in {".", ".."} for part in relative.parts),
        f"{label} must be repository-relative without dot segments",
    )
    root = repo_root.resolve()
    lexical = root.joinpath(*relative.parts)
    cursor = root
    for part in relative.parts:
        cursor /= part
        _expect(
            not _path_is_link_or_reparse(cursor),
            (
                f"{label} must not use symlink, junction, or reparse "
                f"components: {cursor}"
            ),
        )
    try:
        resolved = lexical.resolve(strict=True)
    except OSError as exc:
        raise GovernedParameterInventoryError(
            f"{label} references a missing or inaccessible file: {raw}"
        ) from exc
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise GovernedParameterInventoryError(
            f"{label} must stay inside the repository: {raw}"
        ) from exc
    _expect(resolved.is_file(), f"{label} must reference a regular file")
    return resolved


def _resolve_canonical_file(repo_root: Path, relative: Path, label: str) -> Path:
    return _resolve_reference(
        repo_root,
        relative.as_posix(),
        label,
        required_root=relative.parent.as_posix(),
    )


def _resolve_inventory_input(repo_root: Path, inventory_path: Path) -> Path:
    root = repo_root.resolve()
    if inventory_path.is_absolute():
        _expect(
            all(part not in {".", ".."} for part in inventory_path.parts),
            "governed parameter inventory must not use dot segments",
        )
        cursor = inventory_path
        descendants: list[Path] = []
        while True:
            try:
                reached_root = os.path.samefile(cursor, root)
            except OSError:
                reached_root = False
            if reached_root:
                break
            descendants.append(cursor)
            parent = cursor.parent
            if parent == cursor:
                raise GovernedParameterInventoryError(
                    "governed parameter inventory must stay inside the "
                    "repository below release-artifacts/"
                )
            cursor = parent
        for component in reversed(descendants):
            _expect(
                not _path_is_link_or_reparse(component),
                (
                    "governed parameter inventory must not use symlink, "
                    f"junction, or reparse components: {component}"
                ),
            )
        try:
            resolved = inventory_path.resolve(strict=True)
            relative = resolved.relative_to(root)
        except (OSError, ValueError) as exc:
            raise GovernedParameterInventoryError(
                "governed parameter inventory must stay inside the repository "
                "below release-artifacts/"
            ) from exc
    else:
        relative = inventory_path
    raw = relative.as_posix()
    _expect(
        raw.endswith(".json"),
        "governed parameter inventory must be a JSON file",
    )
    return _resolve_reference(
        root,
        raw,
        "governed parameter inventory",
        required_root="release-artifacts",
    )


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as exc:
        raise GovernedParameterInventoryError(f"cannot hash {path}: {exc}") from exc
    return digest.hexdigest()


def _status(value: Any, label: str) -> str:
    status = _expect_string(value, label)
    _expect(status in FACT_STATUSES, f"{label} has unknown status {status!r}")
    return status


def _fact(status: str, value: int | None) -> dict[str, Any]:
    return {"status": status, "value": value}


def _row(
    family: str,
    name: str,
    path: str,
    anchor: str,
    hosts: tuple[str, ...],
    consumers: tuple[str, ...],
    failure_class_id: int | None,
    genesis: dict[str, Any],
    floor: dict[str, Any],
    wall_clock_floor: dict[str, Any] | None = None,
    fixed_disposition: str = "no_fixed_stipend_consumers_identified",
    fixed_consumers: tuple[str, ...] = (),
) -> dict[str, Any]:
    return {
        "family": family,
        "name": name,
        "normative_path": path,
        "normative_anchor": anchor,
        "host_keys": hosts,
        "guarded_consumers": consumers,
        "failure_class_id": failure_class_id,
        "genesis": genesis,
        "floor": floor,
        "wall_clock_floor": wall_clock_floor,
        "fixed_disposition": fixed_disposition,
        "fixed_consumers": fixed_consumers,
    }


def _parameter_id(family: str, name: str) -> str:
    preimage = f"6529STREAM_{family}_{name}"
    return "0x" + identifier_checker._keccak256(preimage.encode("ascii")).hex()


# This table is the reviewed structural policy for issue #684. Numeric values
# marked planning are copied from their normative homes; they are not candidate
# facts and cannot satisfy --require-complete.
EXPECTED_ROWS: Final = (
    _row(
        "GGP",
        "ROYALTY_RESOLVER_GAS_LIMIT",
        "docs/revenue-splits-and-royalties.md",
        "RSR-GGP",
        ("STREAM_CORE",),
        ("StreamCore.royaltyInfo(uint256,uint256)",),
        1,
        _fact("planning", 50_000),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("royaltyInfo(uint256,uint256)",),
    ),
    _row(
        "GGP",
        "ROYALTY_RETURN_GAS_BUFFER",
        "docs/revenue-splits-and-royalties.md",
        "RSR-GGP",
        ("STREAM_CORE",),
        (
            "StreamCore.royaltyInfo(uint256,uint256)",
            "StreamCore.tokenURI(uint256)",
            "StreamCore.contractURI()",
        ),
        1,
        _fact("planning", 2_910_000),
        _fact("planning", 1_460_000),
        fixed_disposition="evidence_required",
        fixed_consumers=(
            "royaltyInfo(uint256,uint256)",
            "tokenURI(uint256)",
            "contractURI()",
        ),
    ),
    _row(
        "GGP",
        "ERC_1271_GAS_LIMIT",
        "docs/revenue-splits-and-royalties.md",
        "RSR-1271",
        ("SPLIT_FACTORY",),
        ("revenue-layer ERC-1271 verification",),
        2,
        _fact("planning", 400_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "ASSET_POLICY_GAS_LIMIT",
        "docs/revenue-splits-and-royalties.md",
        "RSR-ASSET-POLICY",
        ("SPLIT_FACTORY",),
        ("asset-policy registry reads",),
        2,
        _fact("planning", 30_000),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("split-wallet deposit asset-policy subcall",),
    ),
    _row(
        "GGP",
        "WALLET_DEPOSIT_GAS_LIMIT",
        "docs/revenue-splits-and-royalties.md",
        "RSR-GGP",
        ("SPLIT_FACTORY",),
        ("split-wallet deposits",),
        2,
        _fact("planning", 50_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "FLUSH_GAS_FLOOR",
        "docs/revenue-splits-and-royalties.md",
        "RSR-GGP",
        ("REVENUE_ESCROW",),
        ("revenue escrow flush",),
        3,
        _fact("missing", None),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "MINT_GATE_GAS_LIMIT",
        "docs/mint-policy-and-accounting.md",
        "MPA-GATES",
        ("MINT_MANAGER", "MINT_MANAGER_FALLBACK"),
        ("mint gate calls",),
        2,
        _fact("planning", 400_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "TICKET_ERC1271_GAS_LIMIT",
        "docs/mint-policy-and-accounting.md",
        "MPA-TICKET",
        ("MINT_TICKET_GATE",),
        ("mint-ticket ERC-1271 verification",),
        2,
        _fact("missing", None),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("mint-manager ticket-gate ERC-1271 subcall",),
    ),
    _row(
        "GGP",
        "ARTIST_AUTHORITY_GAS_LIMIT",
        "docs/mint-policy-and-accounting.md",
        "MPA-CONSENT",
        ("MINT_MANAGER", "MINT_MANAGER_FALLBACK"),
        ("mint artist-authority reads",),
        2,
        _fact("planning", 150_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "SALE_ERC1271_GAS_LIMIT",
        "docs/stream-sales-and-auctions.md",
        "SSA-GAS",
        (
            "FIXED_PRICE_SALE_ADAPTER",
            "ENGLISH_AUCTION_HOUSE",
            "DUTCH_AUCTION_ADAPTER",
            "PRIVATE_SALE_ADAPTER",
        ),
        ("sale ERC-1271 verification",),
        2,
        _fact("planning", 400_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "DELEGATE_REGISTRY_GAS_LIMIT",
        "docs/stream-sales-and-auctions.md",
        "SSA-GAS",
        (
            "DELEGATE_REGISTRY_GATE",
            "FIXED_PRICE_SALE_ADAPTER",
            "ENGLISH_AUCTION_HOUSE",
            "DUTCH_AUCTION_ADAPTER",
            "PRIVATE_SALE_ADAPTER",
        ),
        ("delegate-registry reads",),
        2,
        _fact("planning", 150_000),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=(
            "StreamMintManager MINT_GATE_GAS_LIMIT -> "
            "StreamDelegateRegistryGate -> delegate registry",
        ),
    ),
    _row(
        "GGP",
        "SALE_ARTIST_AUTHORITY_GAS_LIMIT",
        "docs/stream-sales-and-auctions.md",
        "SSA-GAS",
        (
            "FIXED_PRICE_SALE_ADAPTER",
            "ENGLISH_AUCTION_HOUSE",
            "DUTCH_AUCTION_ADAPTER",
            "PRIVATE_SALE_ADAPTER",
        ),
        ("sale artist-authority reads",),
        2,
        _fact("planning", 150_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "REVEAL_ATTEMPT_GAS_LIMIT",
        "docs/stream-sales-and-auctions.md",
        "SSA-REVEAL",
        (
            "FIXED_PRICE_SALE_ADAPTER",
            "ENGLISH_AUCTION_HOUSE",
            "DUTCH_AUCTION_ADAPTER",
            "PRIVATE_SALE_ADAPTER",
        ),
        ("AT_MINT entropy request attempts",),
        2,
        _fact("planning", 400_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "SALE_NFT_DELIVERY_GAS_LIMIT",
        "docs/stream-sales-and-auctions.md",
        "SSA-GAS",
        (
            "FIXED_PRICE_SALE_ADAPTER",
            "ENGLISH_AUCTION_HOUSE",
            "DUTCH_AUCTION_ADAPTER",
            "PRIVATE_SALE_ADAPTER",
        ),
        ("sale NFT delivery attempts",),
        2,
        _fact("planning", 300_000),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "METADATA_ROUTER_GAS_LIMIT",
        "docs/metadata-router-and-renderer.md",
        "MRR-ROUTER-GGP",
        ("STREAM_CORE",),
        ("StreamCore.tokenURI(uint256)", "StreamCore.contractURI()"),
        1,
        _fact("missing", None),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("tokenURI(uint256)", "contractURI()"),
    ),
    _row(
        "GGP",
        "ENTROPY_VIEW_GAS_LIMIT",
        "docs/metadata-router-and-renderer.md",
        "MRR-ENTROPY-READ",
        ("METADATA_ROUTER",),
        ("metadata-router entropy reads",),
        1,
        _fact("missing", None),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("StreamCore metadata-router entropy-view subcall",),
    ),
    _row(
        "GGP",
        "ENTROPY_REGISTRATION_GAS_LIMIT",
        "docs/stream-entropy-coordinator.md",
        "EC-REGGAS",
        ("STREAM_CORE",),
        ("StreamCore mint entropy registration",),
        2,
        _fact("missing", None),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "ENTROPY_RESULT_PROBE_GAS_LIMIT",
        "docs/stream-entropy-coordinator.md",
        "EC-INCIDENT-ROLE",
        ("ENTROPY_COORDINATOR", "ENTROPY_COORDINATOR_FALLBACK"),
        ("StreamEntropyCoordinator.providerResultStatus(bytes32)",),
        1,
        _fact("missing", None),
        _fact("missing", None),
    ),
    _row(
        "GGP",
        "VRF_CALLBACK_GAS_LIMIT",
        "docs/stream-entropy-providers.md",
        "EP-VRF-CONFIG",
        ("ENTROPY_PROVIDER_VRF", "ENTROPY_PROVIDER_FALLBACK"),
        ("provider callback fulfillment",),
        1,
        _fact("missing", None),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("upstream provider callback fulfillment",),
    ),
    _row(
        "GGP",
        "ARTIST_ERC1271_VERIFY_GAS",
        "docs/stream-artist-authority.md",
        "AA-SIGVER",
        ("ARTIST_REGISTRY",),
        ("artist-registry ERC-1271 verification",),
        2,
        _fact("planning", 150_000),
        _fact("planning", 90_000),
    ),
    _row(
        "GGP",
        "METADATA_ERC1271_VERIFY_GAS",
        "docs/collection-metadata-contract.md",
        "CMC-SIGVER-GGP",
        ("COLLECTION_METADATA", "OWNER_RECORDS", "COLLECTION_ATTESTATIONS"),
        ("metadata-satellite ERC-1271 verification",),
        2,
        _fact("planning", 150_000),
        _fact("planning", 90_000),
    ),
    _row(
        "GGP",
        "FINALITY_COMPONENT_READ_GAS",
        "docs/stream-long-term-architecture.md",
        "LTA-FINALITY",
        ("ARTWORK_FINALITY_REGISTRY",),
        ("finality component reads",),
        1,
        _fact("planning", 30_000),
        _fact("missing", None),
        fixed_disposition="evidence_required",
        fixed_consumers=("finality 32-component diagnostic aggregation",),
    ),
    _row(
        "GTP",
        "ENTROPY_REQUEST_TIMEOUT_BLOCKS",
        "docs/stream-entropy-coordinator.md",
        "EC-TIME",
        ("ENTROPY_COORDINATOR", "ENTROPY_COORDINATOR_FALLBACK"),
        ("entropy request-timeout eligibility",),
        None,
        _fact("planning", 7_200),
        _fact("planning", 7_200),
        _fact("planning", 86_400),
    ),
    _row(
        "GTP",
        "ENTROPY_REVEAL_SLO_BLOCKS",
        "docs/stream-entropy-coordinator.md",
        "EC-TIME",
        ("ENTROPY_COORDINATOR", "ENTROPY_COORDINATOR_FALLBACK"),
        ("entropy reveal-SLO eligibility",),
        None,
        _fact("planning", 300),
        _fact("planning", 300),
        _fact("planning", 3_600),
    ),
    _row(
        "GTP",
        "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS",
        "docs/stream-entropy-coordinator.md",
        "EC-TIME",
        ("ENTROPY_COORDINATOR", "ENTROPY_COORDINATOR_FALLBACK"),
        ("entropy recovery-step eligibility",),
        None,
        _fact("planning", 300),
        _fact("planning", 300),
        _fact("planning", 3_600),
    ),
)


def _expected_domains() -> dict[str, dict[str, Any]]:
    values = (
        ("gas_scope", GAS_SCOPE_PREIMAGE),
        ("gas_state", GAS_STATE_PREIMAGE),
        ("time_scope", TIME_SCOPE_PREIMAGE),
        ("time_state", TIME_STATE_PREIMAGE),
    )
    return {
        key: {
            "preimage": preimage,
            "keccak256": "0x"
            + identifier_checker._keccak256(preimage.encode("ascii")).hex(),
        }
        for key, preimage in values
    }


def _validate_governance_policy(value: Any) -> None:
    policy = _expect_keys(
        value,
        {
            "status",
            "action_class",
            "minimum_delay_seconds",
            "maximum_raise_multiplier",
            "genesis_revision",
            "one_write_per_action_per_parameter",
            "mutation_model",
            "domains",
            "forbidden_surfaces",
        },
        "governance_policy",
    )
    _expect(policy["status"] == "complete", "governance_policy.status must be complete")
    _expect(
        policy["action_class"]
        == {"id": 1, "name": "DELAYED_LOOSENING"},
        "governance_policy.action_class drifted",
    )
    _expect(
        policy["minimum_delay_seconds"] == 172_800,
        "governance_policy minimum delay must be 172800 seconds",
    )
    _expect(
        policy["maximum_raise_multiplier"] == {"numerator": 2, "denominator": 1},
        "governance_policy maximum raise multiplier must be 2x",
    )
    _expect(policy["genesis_revision"] == 1, "genesis revision must be 1")
    _expect(
        policy["one_write_per_action_per_parameter"] is True,
        "one write per action per parameter must be required",
    )
    _expect(policy["mutation_model"] == "raise_only", "mutation model must be raise_only")
    _expect(policy["domains"] == _expected_domains(), "Governance V2 domains drifted")
    _expect(
        policy["forbidden_surfaces"]
        == [
            "lower_mutation",
            "standalone_parameter_probe_contract",
            "probe_binding",
            "emergency_mutation",
            "rebind",
            "conditional_mutation",
            "permissionless_mutation",
        ],
        "forbidden governed-parameter surfaces drifted",
    )


def _profile_map(
    repo_root: Path,
    profile_record_value: Any,
) -> dict[str, int]:
    profile_record = _expect_keys(
        profile_record_value,
        {"path", "schema_version", "sha256"},
        "genesis_profile",
    )
    _expect(
        profile_record["path"] == GENESIS_PROFILE.as_posix(),
        f"genesis_profile.path must be {GENESIS_PROFILE.as_posix()}",
    )
    _expect(
        profile_record["schema_version"] == GENESIS_PROFILE_SCHEMA,
        f"genesis_profile.schema_version must be {GENESIS_PROFILE_SCHEMA}",
    )
    recorded = _expect_string(profile_record["sha256"], "genesis_profile.sha256")
    _expect(
        SHA256_RE.fullmatch(recorded) is not None,
        "genesis_profile.sha256 is malformed",
    )
    profile_path = _resolve_canonical_file(
        repo_root,
        GENESIS_PROFILE,
        "genesis_profile.path",
    )
    actual = _sha256(profile_path)
    _expect(
        actual == recorded,
        f"genesis_profile.sha256 mismatch: expected {actual}",
    )
    profile = _load_json(profile_path, "genesis deployment profile")
    _expect(
        profile.get("schema_version") == GENESIS_PROFILE_SCHEMA,
        f"genesis deployment profile must use schema {GENESIS_PROFILE_SCHEMA}",
    )
    entries = profile.get("entries")
    _expect(isinstance(entries, list), "genesis profile entries must be an array")
    result: dict[str, int] = {}
    seen_ids: set[int] = set()
    for index, entry in enumerate(entries):
        _expect(isinstance(entry, dict), f"genesis profile entries[{index}] must be an object")
        key = _expect_string(entry.get("key"), f"genesis profile entries[{index}].key")
        profile_id = _expect_int(
            entry.get("id"), f"genesis profile entries[{index}].id", minimum=1
        )
        _expect(key not in result, f"duplicate genesis profile key {key}")
        _expect(profile_id not in seen_ids, f"duplicate genesis profile id {profile_id}")
        result[key] = profile_id
        seen_ids.add(profile_id)
    return result


def _validate_value_fact(
    value: Any,
    label: str,
    *,
    expected: dict[str, Any],
    completeness: list[str],
    maximum: int,
) -> None:
    fact = _expect_keys(value, {"status", "value"}, label)
    status = _status(fact["status"], f"{label}.status")
    raw_value = fact["value"]
    if status in {"complete", "planning"}:
        _expect_int(raw_value, f"{label}.value", minimum=1, maximum=maximum)
    else:
        _expect(raw_value is None, f"{label}.value must be null for status {status}")
    if status == "complete":
        return
    _expect(fact == expected, f"{label} must match the reviewed planning fact")
    if status != "complete":
        completeness.append(f"{label} is {status}")


def _validate_evidence(
    value: Any,
    label: str,
    repo_root: Path,
    completeness: list[str],
    *,
    parameter_id: str,
    expected: dict[str, Any],
    guarded_consumers: list[str],
) -> tuple[
    str,
    str,
    tuple[tuple[str, int, int, int | None, int | None], ...],
] | None:
    evidence = _expect_keys(value, {"status", "path", "sha256"}, label)
    status = _status(evidence["status"], f"{label}.status")
    if status == "complete":
        path = _resolve_reference(
            repo_root,
            evidence["path"],
            f"{label}.path",
            required_root=EVIDENCE_ROOT,
        )
        recorded = _expect_string(evidence["sha256"], f"{label}.sha256")
        _expect(SHA256_RE.fullmatch(recorded) is not None, f"{label}.sha256 is malformed")
        actual = _sha256(path)
        _expect(actual == recorded, f"{label}.sha256 mismatch: expected {actual}")
        document = _load_json(path, f"{label} document")
        parsed = _validate_evidence_document_common(
            document,
            label,
            schema=MEASUREMENT_EVIDENCE_SCHEMA,
            parameter_id=parameter_id,
            expected=expected,
        )
        audit = _expect_keys(
            document["consumer_audit"],
            {"review_status", "consumers"},
            f"{label}.consumer_audit",
        )
        _expect(
            audit["review_status"] == "reviewed",
            f"{label}.consumer_audit.review_status must be reviewed",
        )
        _expect(
            audit["consumers"] == guarded_consumers,
            f"{label}.consumer_audit.consumers drifted",
        )
        return parsed
    else:
        _expect(evidence["path"] is None, f"{label}.path must be null while {status}")
        _expect(evidence["sha256"] is None, f"{label}.sha256 must be null while {status}")
        completeness.append(f"{label} is {status}")
        return None


def _validate_fixed_stipend(
    value: Any,
    label: str,
    expected: dict[str, Any],
    repo_root: Path,
    completeness: list[str],
    *,
    parameter_id: str,
) -> tuple[
    str,
    str,
    tuple[tuple[str, int, int, int | None, int | None], ...],
] | None:
    fixed = _expect_keys(
        value,
        {"status", "disposition", "consumers", "evidence_path", "evidence_sha256"},
        label,
    )
    status = _status(fixed["status"], f"{label}.status")
    _expect(
        fixed["disposition"] == expected["fixed_disposition"],
        f"{label}.disposition drifted",
    )
    _expect(
        fixed["consumers"] == list(expected["fixed_consumers"]),
        f"{label}.consumers drifted",
    )
    if status == "complete":
        path = _resolve_reference(
            repo_root,
            fixed["evidence_path"],
            f"{label}.evidence_path",
            required_root=EVIDENCE_ROOT,
        )
        recorded = _expect_string(
            fixed["evidence_sha256"], f"{label}.evidence_sha256"
        )
        _expect(
            SHA256_RE.fullmatch(recorded) is not None,
            f"{label}.evidence_sha256 is malformed",
        )
        actual = _sha256(path)
        _expect(actual == recorded, f"{label}.evidence_sha256 mismatch: expected {actual}")
        document = _load_json(path, f"{label} document")
        parsed = _validate_evidence_document_common(
            document,
            label,
            schema=FIXED_STIPEND_EVIDENCE_SCHEMA,
            parameter_id=parameter_id,
            expected=expected,
        )
        _expect(
            document["disposition"] == expected["fixed_disposition"],
            f"{label} evidence disposition drifted",
        )
        _expect(
            document["consumers"] == list(expected["fixed_consumers"]),
            f"{label} evidence consumers drifted",
        )
        return parsed
    else:
        _expect(
            fixed["evidence_path"] is None,
            f"{label}.evidence_path must be null while {status}",
        )
        _expect(
            fixed["evidence_sha256"] is None,
            f"{label}.evidence_sha256 must be null while {status}",
        )
        completeness.append(f"{label} is {status}")
        return None


def _validate_evidence_document_common(
    document: dict[str, Any],
    label: str,
    *,
    schema: str,
    parameter_id: str,
    expected: dict[str, Any],
) -> tuple[
    str,
    str,
    tuple[tuple[str, int, int, int | None, int | None], ...],
]:
    common_keys = {
        "schema_version",
        "candidate_id",
        "candidate_commit",
        "review_status",
        "parameter_id",
        "covered_profile_keys",
        "host_facts",
    }
    expected_keys = (
        common_keys | {"consumer_audit"}
        if schema == MEASUREMENT_EVIDENCE_SCHEMA
        else common_keys | {"disposition", "consumers"}
    )
    _expect_keys(document, expected_keys, f"{label} document")
    _expect(
        document["schema_version"] == schema,
        f"{label} document schema_version must be {schema}",
    )
    candidate_id = _expect_string(document["candidate_id"], f"{label}.candidate_id")
    _expect(
        CANDIDATE_ID_RE.fullmatch(candidate_id) is not None,
        f"{label}.candidate_id is malformed",
    )
    candidate_commit = _expect_string(
        document["candidate_commit"],
        f"{label}.candidate_commit",
    )
    _expect(
        COMMIT_RE.fullmatch(candidate_commit) is not None,
        f"{label}.candidate_commit must be 40 lowercase hexadecimal characters",
    )
    _expect(
        document["review_status"] == "reviewed",
        f"{label}.review_status must be reviewed",
    )
    _expect(
        document["parameter_id"] == parameter_id,
        f"{label}.parameter_id must be {parameter_id}",
    )
    host_keys = list(expected["host_keys"])
    _expect(
        document["covered_profile_keys"] == host_keys,
        f"{label}.covered_profile_keys must exactly cover {host_keys!r}",
    )
    host_facts = document["host_facts"]
    _expect(isinstance(host_facts, list), f"{label}.host_facts must be an array")
    _expect(
        len(host_facts) == len(host_keys),
        f"{label}.host_facts must contain exactly {len(host_keys)} rows",
    )
    normalized_facts: list[tuple[str, int, int, int | None, int | None]] = []
    for index, (raw_fact, profile_key) in enumerate(
        zip(host_facts, host_keys, strict=True)
    ):
        fact_label = f"{label}.host_facts[{index}]"
        fact = _expect_keys(
            raw_fact,
            {
                "profile_key",
                "genesis_value",
                "immutable_floor",
                "failure_class_id",
                "wall_clock_floor_seconds",
            },
            fact_label,
        )
        _expect(
            fact["profile_key"] == profile_key,
            f"{fact_label}.profile_key must be {profile_key}",
        )
        genesis = _expect_int(
            fact["genesis_value"],
            f"{fact_label}.genesis_value",
            minimum=1,
            maximum=UINT256_MAX,
        )
        floor = _expect_int(
            fact["immutable_floor"],
            f"{fact_label}.immutable_floor",
            minimum=1,
            maximum=UINT256_MAX,
        )
        _expect(genesis >= floor, f"{fact_label}.genesis_value must be >= floor")
        if expected["family"] == "GGP":
            failure_class_id = _expect_int(
                fact["failure_class_id"],
                f"{fact_label}.failure_class_id",
                minimum=1,
                maximum=max(FAILURE_CLASSES),
            )
            _expect(
                failure_class_id == expected["failure_class_id"],
                f"{fact_label}.failure_class_id drifted",
            )
            _expect(
                fact["wall_clock_floor_seconds"] is None,
                f"{fact_label}.wall_clock_floor_seconds must be null for a GGP",
            )
            normalized_facts.append(
                (profile_key, genesis, floor, failure_class_id, None)
            )
        else:
            _expect(
                fact["failure_class_id"] is None,
                f"{fact_label}.failure_class_id must be null for a GTP",
            )
            wall_clock_floor_seconds = _expect_int(
                fact["wall_clock_floor_seconds"],
                f"{fact_label}.wall_clock_floor_seconds",
                minimum=1,
                maximum=UINT64_MAX,
            )
            normalized_facts.append(
                (profile_key, genesis, floor, None, wall_clock_floor_seconds)
            )
    return candidate_id, candidate_commit, tuple(normalized_facts)


def _validate_normative_sources(repo_root: Path, sources: Any) -> None:
    expected = list(EXPECTED_NORMATIVE_SOURCES)
    _expect(sources == expected, "normative_sources drifted")

    for index, source in enumerate(expected):
        label = f"normative_sources[{index}]"
        path = source["path"]
        required_root = path.split("/", 1)[0]
        resolved = _resolve_reference(
            repo_root,
            path,
            f"{label}.path",
            required_root=required_root,
        )
        anchor = source["anchor"]
        if resolved.suffix == ".json":
            document = _load_json(resolved, f"{label} document")
            _expect(
                document.get("schema_version") == anchor,
                f"{label}.anchor does not identify the source schema_version",
            )
            continue

        try:
            text = resolved.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            raise GovernedParameterInventoryError(
                f"cannot read {label} document: {exc}"
            ) from exc
        _expect(
            _markdown_anchor_declared(
                text,
                anchor,
                allow_bare_heading=not anchor.startswith("LTA-"),
            ),
            f"{label}.anchor does not identify a Markdown heading",
        )


def _markdown_anchor_declared(
    text: str,
    anchor: str,
    *,
    allow_bare_heading: bool = False,
) -> bool:
    tag = re.escape(anchor)
    patterns = [
        rf"^#{{1,6}}[ \t]+.+\[{tag}\][ \t]*$",
        rf"^[^\r\n]*\[{tag}\](?:[ \t]+\([^\r\n)]*\))?:[ \t]*$",
    ]
    if allow_bare_heading:
        patterns.append(rf"^#{{1,6}}[ \t]+{tag}[ \t]*$")
    return any(re.search(pattern, text, re.MULTILINE) for pattern in patterns)


def _validate_parameters(
    parameters: Any,
    repo_root: Path,
    profiles: dict[str, int],
    completeness: list[str],
) -> list[tuple[str, int, str]]:
    _expect(isinstance(parameters, list), "parameters must be an array")
    _expect(
        len(parameters) == EXPECTED_PARAMETER_COUNT,
        f"parameters must contain exactly {EXPECTED_PARAMETER_COUNT} rows",
    )
    expected_names = tuple(identifier_checker.GGP_NAMES) + tuple(
        identifier_checker.GTP_NAMES
    )
    _expect(
        tuple(row["name"] for row in EXPECTED_ROWS) == expected_names,
        "checker row catalog drifted from canonical identifier catalog",
    )

    expected_bindings: list[tuple[str, int, str]] = []
    evidence_identities: set[tuple[str, str]] = set()
    has_complete_evidence = False
    seen_ids: set[str] = set()
    for index, (raw_row, expected) in enumerate(
        zip(parameters, EXPECTED_ROWS, strict=True), start=1
    ):
        label = f"parameters[{index - 1}]"
        row = _expect_keys(
            raw_row,
            {
                "order",
                "family",
                "name",
                "constant_name",
                "preimage",
                "parameter_id",
                "identifier_schema_version",
                "normative_source",
                "expected_hosts",
                "guarded_consumers",
                "gas",
                "time",
                "measurement_evidence",
                "fixed_stipend_compatibility",
            },
            label,
        )
        _expect(row["order"] == index, f"{label}.order must be {index}")
        family = expected["family"]
        name = expected["name"]
        _expect(row["family"] == family, f"{label}.family must be {family}")
        _expect(row["name"] == name, f"{label}.name must be {name}")
        constant_name = f"{family}_{name}"
        preimage = f"6529STREAM_{constant_name}"
        parameter_id = _parameter_id(family, name)
        _expect(
            row["constant_name"] == constant_name,
            f"{label}.constant_name must be {constant_name}",
        )
        _expect(row["preimage"] == preimage, f"{label}.preimage must be {preimage}")
        _expect(
            row["parameter_id"] == parameter_id,
            f"{label}.parameter_id must recompute to {parameter_id}",
        )
        _expect(parameter_id not in seen_ids, f"duplicate parameter id {parameter_id}")
        seen_ids.add(parameter_id)
        _expect(
            row["identifier_schema_version"] == 1,
            f"{label}.identifier_schema_version must be 1",
        )

        source = _expect_keys(
            row["normative_source"], {"status", "path", "anchor"}, f"{label}.normative_source"
        )
        _expect(
            source
            == {
                "status": "complete",
                "path": expected["normative_path"],
                "anchor": expected["normative_anchor"],
            },
            f"{label}.normative_source drifted",
        )
        source_path = _resolve_reference(
            repo_root,
            source["path"],
            f"{label}.normative_source.path",
            required_root="docs",
        )
        try:
            source_text = source_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            raise GovernedParameterInventoryError(
                f"cannot read {label} normative source: {exc}"
            ) from exc
        _expect(
            _markdown_anchor_declared(source_text, source["anchor"]),
            f"{label} normative anchor [{source['anchor']}] has no declaration",
        )

        hosts = _expect_keys(
            row["expected_hosts"],
            {"status", "count", "profiles"},
            f"{label}.expected_hosts",
        )
        _expect(
            hosts["status"] == "complete",
            f"{label}.expected_hosts.status must be complete",
        )
        host_keys = expected["host_keys"]
        expected_profiles = []
        for host_key in host_keys:
            _expect(host_key in profiles, f"required profile {host_key} is absent")
            expected_profiles.append({"id": profiles[host_key], "key": host_key})
            expected_bindings.append((parameter_id, profiles[host_key], host_key))
        _expect(hosts["count"] == len(host_keys), f"{label}.expected_hosts.count drifted")
        _expect(
            hosts["profiles"] == expected_profiles,
            f"{label}.expected_hosts.profiles drifted",
        )
        guarded = _expect_keys(
            row["guarded_consumers"],
            {"status", "consumers"},
            f"{label}.guarded_consumers",
        )
        guarded_status = _status(
            guarded["status"], f"{label}.guarded_consumers.status"
        )
        _expect(
            guarded_status in {"complete", "planning"},
            f"{label}.guarded_consumers must be planning or complete",
        )
        _expect(
            guarded["consumers"] == list(expected["guarded_consumers"]),
            f"{label}.guarded_consumers.consumers drifted",
        )
        if guarded_status != "complete":
            completeness.append(
                f"{label}.guarded_consumers is {guarded_status}"
            )

        if family == "GGP":
            _expect(row["time"] is None, f"{label}.time must be null for a GGP")
            gas = _expect_keys(
                row["gas"],
                {"genesis_value", "immutable_floor", "failure_class"},
                f"{label}.gas",
            )
            _validate_value_fact(
                gas["genesis_value"],
                f"{label}.gas.genesis_value",
                expected=expected["genesis"],
                completeness=completeness,
                maximum=UINT256_MAX,
            )
            _validate_value_fact(
                gas["immutable_floor"],
                f"{label}.gas.immutable_floor",
                expected=expected["floor"],
                completeness=completeness,
                maximum=UINT256_MAX,
            )
            failure = _expect_keys(
                gas["failure_class"], {"status", "id", "name"}, f"{label}.gas.failure_class"
            )
            class_id = expected["failure_class_id"]
            _expect(
                failure
                == {
                    "status": "complete",
                    "id": class_id,
                    "name": FAILURE_CLASSES[class_id],
                },
                f"{label}.gas.failure_class drifted",
            )
            genesis_value = gas["genesis_value"]["value"]
            floor_value = gas["immutable_floor"]["value"]
            if genesis_value is not None and floor_value is not None:
                _expect(
                    genesis_value >= floor_value,
                    f"{label} genesis value must not be below floor",
                )
        else:
            _expect(row["gas"] is None, f"{label}.gas must be null for a GTP")
            time = _expect_keys(
                row["time"],
                {
                    "genesis_value_blocks",
                    "immutable_floor_blocks",
                    "wall_clock_floor_seconds",
                },
                f"{label}.time",
            )
            _validate_value_fact(
                time["genesis_value_blocks"],
                f"{label}.time.genesis_value_blocks",
                expected=expected["genesis"],
                completeness=completeness,
                maximum=UINT256_MAX,
            )
            _validate_value_fact(
                time["immutable_floor_blocks"],
                f"{label}.time.immutable_floor_blocks",
                expected=expected["floor"],
                completeness=completeness,
                maximum=UINT256_MAX,
            )
            _validate_value_fact(
                time["wall_clock_floor_seconds"],
                f"{label}.time.wall_clock_floor_seconds",
                expected=expected["wall_clock_floor"],
                completeness=completeness,
                maximum=UINT64_MAX,
            )
            _expect(
                time["genesis_value_blocks"]["value"]
                >= time["immutable_floor_blocks"]["value"],
                f"{label} genesis block value must not be below floor",
            )

        measurement_identity = _validate_evidence(
            row["measurement_evidence"],
            f"{label}.measurement_evidence",
            repo_root,
            completeness,
            parameter_id=parameter_id,
            expected=expected,
            guarded_consumers=list(expected["guarded_consumers"]),
        )
        fixed_identity = _validate_fixed_stipend(
            row["fixed_stipend_compatibility"],
            f"{label}.fixed_stipend_compatibility",
            expected,
            repo_root,
            completeness,
            parameter_id=parameter_id,
        )
        if guarded_status == "complete":
            _expect(
                measurement_identity is not None,
                (
                    f"{label}.guarded_consumers cannot be complete without "
                    "reviewed measurement consumer-audit evidence"
                ),
            )
        for identity in (measurement_identity, fixed_identity):
            if identity is not None:
                has_complete_evidence = True
                evidence_identities.add(identity[:2])
        if measurement_identity is not None and fixed_identity is not None:
            _expect(
                measurement_identity == fixed_identity,
                (
                    f"{label} evidence files must bind the same candidate "
                    "and host facts"
                ),
            )

    _expect(
        len(expected_bindings) == EXPECTED_HOST_BINDING_COUNT,
        "checker host-binding count drifted",
    )
    _expect(
        len(evidence_identities) <= 1,
        "complete evidence files must all bind one candidate id and commit",
    )
    _expect(not has_complete_evidence, STRUCTURED_EVIDENCE_BLOCKER)
    return expected_bindings


def _validate_candidate(
    value: Any,
    repo_root: Path,
    expected_bindings: list[tuple[str, int, str]],
    parameters: list[dict[str, Any]],
    completeness: list[str],
) -> None:
    candidate = _expect_keys(
        value,
        {
            "status",
            "blocked_by_issue",
            "candidate_id",
            "candidate_commit",
            "candidate_artifact_path",
            "candidate_artifact_sha256",
            "host_bindings",
        },
        "candidate_binding",
    )
    status = _status(candidate["status"], "candidate_binding.status")
    bindings = candidate["host_bindings"]
    _expect(isinstance(bindings, list), "candidate_binding.host_bindings must be an array")
    if status == "complete":
        _expect(
            candidate["blocked_by_issue"] is None,
            "complete candidate_binding.blocked_by_issue must be null",
        )
        candidate_id = _expect_string(
            candidate["candidate_id"],
            "candidate_binding.candidate_id",
        )
        _expect(
            CANDIDATE_ID_RE.fullmatch(candidate_id) is not None,
            "candidate_binding.candidate_id is malformed",
        )
        candidate_commit = _expect_string(
            candidate["candidate_commit"],
            "candidate_binding.candidate_commit",
        )
        _expect(
            COMMIT_RE.fullmatch(candidate_commit) is not None,
            (
                "candidate_binding.candidate_commit must be 40 lowercase "
                "hexadecimal characters"
            ),
        )
        path = _resolve_reference(
            repo_root,
            candidate["candidate_artifact_path"],
            "candidate_binding.candidate_artifact_path",
            required_root=CANDIDATE_ROOT,
        )
        recorded = _expect_string(
            candidate["candidate_artifact_sha256"],
            "candidate_binding.candidate_artifact_sha256",
        )
        _expect(
            SHA256_RE.fullmatch(recorded) is not None,
            "candidate binding SHA-256 is malformed",
        )
        actual = _sha256(path)
        _expect(actual == recorded, f"candidate binding SHA-256 mismatch: expected {actual}")
        normalized: list[tuple[str, int, str]] = []
        expected_by_parameter_id = {
            row["parameter_id"]: expected
            for row, expected in zip(parameters, EXPECTED_ROWS, strict=True)
        }
        host_identity_by_profile: dict[str, tuple[Any, ...]] = {}
        for index, binding in enumerate(bindings):
            label = f"candidate_binding.host_bindings[{index}]"
            item = _expect_keys(
                binding,
                {
                    "candidate_instance_id",
                    "contract_name",
                    "contract_source",
                    "parameter_id",
                    "profile_id",
                    "profile_key",
                    "host_address",
                    "runtime_code_keccak256",
                    "governance_authority",
                    "source_verification_binding",
                    "genesis_value",
                    "immutable_floor",
                    "failure_class_id",
                    "wall_clock_floor_seconds",
                    "genesis_revision",
                },
                label,
            )
            instance_id = _expect_string(
                item["candidate_instance_id"],
                f"{label}.candidate_instance_id",
            )
            _expect(
                CANDIDATE_ID_RE.fullmatch(instance_id) is not None,
                f"{label}.candidate_instance_id is malformed",
            )
            contract_name = _expect_string(
                item["contract_name"],
                f"{label}.contract_name",
            )
            _expect(
                SOLIDITY_NAME_RE.fullmatch(contract_name) is not None,
                f"{label}.contract_name is malformed",
            )
            contract_source = _expect_string(
                item["contract_source"],
                f"{label}.contract_source",
            )
            _resolve_reference(
                repo_root,
                contract_source,
                f"{label}.contract_source",
                required_root="smart-contracts",
            )
            address = _expect_string(item["host_address"], f"{label}.host_address")
            _expect(
                ADDRESS_RE.fullmatch(address) is not None
                and int(address.removeprefix("0x"), 16) != 0,
                f"{label}.host_address must be a nonzero lowercase address",
            )
            runtime_code_hash = _expect_string(
                item["runtime_code_keccak256"],
                f"{label}.runtime_code_keccak256",
            )
            _expect(
                KECCAK_RE.fullmatch(runtime_code_hash) is not None
                and int(runtime_code_hash.removeprefix("0x"), 16) != 0,
                f"{label}.runtime_code_keccak256 must be a nonzero Keccak-256",
            )
            governance_authority = _expect_string(
                item["governance_authority"],
                f"{label}.governance_authority",
            )
            _expect(
                ADDRESS_RE.fullmatch(governance_authority) is not None
                and int(governance_authority.removeprefix("0x"), 16) != 0,
                f"{label}.governance_authority must be a nonzero lowercase address",
            )
            source_verification = _expect_keys(
                item["source_verification_binding"],
                {"path", "sha256", "target_name", "target_source"},
                f"{label}.source_verification_binding",
            )
            source_verification_path = _resolve_reference(
                repo_root,
                source_verification["path"],
                f"{label}.source_verification_binding.path",
                required_root="release-artifacts/latest",
            )
            source_verification_sha256 = _expect_string(
                source_verification["sha256"],
                f"{label}.source_verification_binding.sha256",
            )
            _expect(
                SHA256_RE.fullmatch(source_verification_sha256) is not None,
                f"{label}.source_verification_binding.sha256 is malformed",
            )
            _expect(
                _sha256(source_verification_path) == source_verification_sha256,
                f"{label}.source_verification_binding.sha256 mismatch",
            )
            _expect(
                source_verification["target_name"] == contract_name,
                f"{label}.source_verification_binding.target_name drifted",
            )
            _expect(
                source_verification["target_source"] == contract_source,
                f"{label}.source_verification_binding.target_source drifted",
            )
            parameter_id = _expect_string(
                item["parameter_id"], f"{label}.parameter_id"
            )
            profile_id = _expect_int(
                item["profile_id"],
                f"{label}.profile_id",
                minimum=1,
            )
            profile_key = _expect_string(
                item["profile_key"],
                f"{label}.profile_key",
            )
            normalized.append(
                (
                    parameter_id,
                    profile_id,
                    profile_key,
                )
            )
            host_identity = (
                instance_id,
                contract_name,
                contract_source,
                address,
                runtime_code_hash,
                governance_authority,
                source_verification["path"],
                source_verification_sha256,
            )
            previous_identity = host_identity_by_profile.setdefault(
                profile_key,
                host_identity,
            )
            _expect(
                previous_identity == host_identity,
                (
                    f"candidate bindings for profile {profile_key} must use one "
                    "consistent instance/address/code/authority/source identity"
                ),
            )
            genesis_value = _expect_int(
                item["genesis_value"],
                f"{label}.genesis_value",
                minimum=1,
                maximum=UINT256_MAX,
            )
            immutable_floor = _expect_int(
                item["immutable_floor"],
                f"{label}.immutable_floor",
                minimum=1,
                maximum=UINT256_MAX,
            )
            _expect(
                genesis_value >= immutable_floor,
                f"{label}.genesis_value must be >= immutable_floor",
            )
            expected = expected_by_parameter_id.get(parameter_id)
            _expect(expected is not None, f"{label}.parameter_id is not inventoried")
            if expected["family"] == "GGP":
                _expect(
                    item["failure_class_id"] == expected["failure_class_id"],
                    f"{label}.failure_class_id does not match the policy class",
                )
                _expect(
                    item["wall_clock_floor_seconds"] is None,
                    f"{label}.wall_clock_floor_seconds must be null for a GGP",
                )
            else:
                _expect(
                    item["failure_class_id"] is None,
                    f"{label}.failure_class_id must be null for a GTP",
                )
                _expect_int(
                    item["wall_clock_floor_seconds"],
                    f"{label}.wall_clock_floor_seconds",
                    minimum=1,
                    maximum=UINT64_MAX,
                )
            _expect(
                _expect_int(
                    item["genesis_revision"],
                    f"{label}.genesis_revision",
                    minimum=1,
                    maximum=1,
                )
                == 1,
                f"{label}.genesis_revision must be 1",
            )
        _expect(
            normalized == expected_bindings,
            "candidate host bindings must exactly cover every ordered parameter/profile pair",
        )
        raise GovernedParameterInventoryError(
            STRUCTURED_PRODUCTION_CANDIDATE_BLOCKER
        )
    else:
        _expect(
            candidate["blocked_by_issue"] == PRODUCTION_CANDIDATE_ISSUE,
            "incomplete candidate_binding.blocked_by_issue must identify issue #656",
        )
        _expect(
            candidate["candidate_id"] is None,
            "candidate id must be null before a candidate is available",
        )
        _expect(
            candidate["candidate_commit"] is None,
            "candidate commit must be null before a candidate is available",
        )
        _expect(
            candidate["candidate_artifact_path"] is None,
            "candidate artifact path must be null before a candidate is available",
        )
        _expect(
            candidate["candidate_artifact_sha256"] is None,
            "candidate artifact SHA-256 must be null before a candidate is available",
        )
        _expect(not bindings, "candidate host bindings must be empty before availability")
        completeness.append(f"candidate_binding is {status}")


def _validate_shared_buffer_planning(
    value: Any,
    parameters: list[dict[str, Any]],
    repo_root: Path,
    completeness: list[str],
) -> None:
    label = "shared_buffer_planning"
    planning = _expect_keys(
        value,
        {
            "status",
            "parameter",
            "host_profile",
            "guarded_consumers",
            "failure_class",
            "genesis_value",
            "immutable_floor",
            "returndata_limits",
            "planning_evidence",
            "independent_raise_chain",
            "fixed_stipend_compatibility",
        },
        label,
    )
    _expect(
        planning["status"] == "planning_target_fixture",
        f"{label}.status must remain planning_target_fixture",
    )
    parameter = _expect_keys(
        planning["parameter"], {"family", "name", "parameter_id"}, f"{label}.parameter"
    )
    expected_parameter = EXPECTED_ROWS[1]
    expected_parameter_id = _parameter_id(
        expected_parameter["family"], expected_parameter["name"]
    )
    _expect(parameter["family"] == "GGP", f"{label}.parameter.family drifted")
    _expect(
        parameter["name"] == expected_parameter["name"],
        f"{label}.parameter.name drifted",
    )
    _expect(
        parameter["parameter_id"] == expected_parameter_id,
        f"{label}.parameter.parameter_id drifted",
    )
    _expect(
        planning["host_profile"]
        == {"id": 1, "key": "STREAM_CORE", "candidate_instance": "not_available"},
        f"{label}.host_profile drifted",
    )
    consumers = list(expected_parameter["guarded_consumers"])
    _expect(
        planning["guarded_consumers"] == consumers,
        f"{label}.guarded_consumers drifted",
    )
    _expect(
        planning["failure_class"] == {"id": 1, "name": "FORWARDING_CAP"},
        f"{label}.failure_class drifted",
    )
    expected_genesis = expected_parameter["genesis"]
    expected_floor = expected_parameter["floor"]
    _expect(
        planning["genesis_value"] == expected_genesis,
        f"{label}.genesis_value drifted",
    )
    _expect(
        planning["immutable_floor"] == expected_floor,
        f"{label}.immutable_floor drifted",
    )
    _expect(
        planning["returndata_limits"]
        == {"royalty_exact_bytes": 64, "metadata_max_abi_bytes": 65_536},
        f"{label}.returndata_limits drifted",
    )

    evidence = _expect_keys(
        planning["planning_evidence"],
        {"status", "path", "sha256", "onchain_authority"},
        f"{label}.planning_evidence",
    )
    _expect(
        evidence["status"] == "planning_target_fixture",
        f"{label}.planning_evidence.status must remain planning",
    )
    _expect(
        evidence["onchain_authority"] is False,
        f"{label}.planning_evidence must have no onchain authority",
    )
    path = _resolve_reference(
        repo_root,
        evidence["path"],
        f"{label}.planning_evidence.path",
        required_root="release-artifacts",
    )
    _expect(
        path.relative_to(repo_root).as_posix()
        == "release-artifacts/evidence/royalty-return-gas-buffer.json",
        f"{label}.planning_evidence.path drifted",
    )
    recorded_sha = _expect_string(
        evidence["sha256"], f"{label}.planning_evidence.sha256"
    )
    _expect(
        SHA256_RE.fullmatch(recorded_sha) is not None,
        f"{label}.planning_evidence.sha256 is malformed",
    )
    _expect(
        recorded_sha == _sha256(path),
        f"{label}.planning_evidence.sha256 mismatch",
    )
    document = _load_json(path, f"{label}.planning_evidence document")
    _expect(
        document.get("schema_version")
        == "6529stream.royalty-return-gas-buffer.v1",
        f"{label}.planning_evidence schema drifted",
    )
    _expect(
        document.get("status") == "planning_target_fixture",
        f"{label}.planning_evidence document must remain planning",
    )
    _expect(
        document.get("shared_parameter", {}).get("guarded_consumers") == consumers,
        f"{label}.planning_evidence consumers drifted",
    )
    _expect(
        document.get("sizing", {}).get("planning_genesis_value")
        == expected_genesis["value"],
        f"{label}.planning_evidence genesis drifted",
    )
    _expect(
        document.get("sizing", {}).get("planning_immutable_floor")
        == expected_floor["value"],
        f"{label}.planning_evidence floor drifted",
    )
    _expect(
        document.get("core_boundary", {}).get("stream_core_delta_bytes") == 0,
        f"{label}.planning_evidence must record zero StreamCore delta",
    )

    raise_chain = _expect_keys(
        planning["independent_raise_chain"],
        {
            "status",
            "action_class_id",
            "minimum_delay_seconds",
            "maximum_raise_multiplier",
            "one_write_per_action_per_parameter",
            "limit_parameters",
            "near_uint256_behavior",
        },
        f"{label}.independent_raise_chain",
    )
    _expect(
        raise_chain
        == {
            "status": "planning_target_fixture",
            "action_class_id": 1,
            "minimum_delay_seconds": 172_800,
            "maximum_raise_multiplier": {"numerator": 2, "denominator": 1},
            "one_write_per_action_per_parameter": True,
            "limit_parameters": [
                "ROYALTY_RESOLVER_GAS_LIMIT",
                "METADATA_ROUTER_GAS_LIMIT",
            ],
            "near_uint256_behavior": "no_overflow_and_fail_closed",
        },
        f"{label}.independent_raise_chain drifted",
    )
    _expect(
        planning["fixed_stipend_compatibility"]
        == {
            "status": "missing",
            "disposition": (
                "production_gate_conflict_until_candidate_upstream_budgets_cover_tuple"
            ),
            "blocked_by_issue": "#684",
        },
        f"{label}.fixed_stipend_compatibility drifted",
    )

    royalty_row = parameters[1]
    _expect(
        royalty_row["gas"]["genesis_value"] == expected_genesis,
        f"{label} genesis does not match parameter row",
    )
    _expect(
        royalty_row["gas"]["immutable_floor"] == expected_floor,
        f"{label} floor does not match parameter row",
    )
    completeness.append(
        "shared_buffer_planning is target-fixture-only and fixed-stipend compatibility is missing"
    )


def validate_inventory(
    repo_root: Path,
    inventory_path: Path = DEFAULT_INVENTORY,
    require_complete: bool = False,
) -> dict[str, Any]:
    """Validate the structural inventory and optionally require production facts."""
    root = repo_root.resolve()

    resolved_inventory = _resolve_inventory_input(root, inventory_path)
    inventory = _load_json(resolved_inventory, "governed parameter inventory")
    schema_path = _resolve_canonical_file(
        root,
        DEFAULT_SCHEMA,
        "governed parameter inventory schema",
    )
    schema = _load_json(schema_path, "governed parameter inventory schema")
    _validate_schema(schema, inventory, "governed parameter inventory")
    _expect_keys(
        inventory,
        {
            "schema_version",
            "status",
            "normative_sources",
            "genesis_profile",
            "governance_policy",
            "inventory_summary",
            "candidate_binding",
            "shared_buffer_planning",
            "parameters",
        },
        "inventory",
    )
    _expect(
        inventory["schema_version"] == SCHEMA_VERSION,
        f"schema_version must be {SCHEMA_VERSION}",
    )
    _validate_normative_sources(root, inventory["normative_sources"])
    _validate_governance_policy(inventory["governance_policy"])
    _expect(
        inventory["inventory_summary"]
        == {
            "ggp_count": EXPECTED_GGP_COUNT,
            "gtp_count": EXPECTED_GTP_COUNT,
            "logical_parameter_count": EXPECTED_PARAMETER_COUNT,
            "expected_host_binding_count": EXPECTED_HOST_BINDING_COUNT,
        },
        "inventory_summary drifted",
    )

    completeness: list[str] = []
    profiles = _profile_map(root, inventory["genesis_profile"])
    expected_bindings = _validate_parameters(
        inventory["parameters"], root, profiles, completeness
    )
    _validate_shared_buffer_planning(
        inventory["shared_buffer_planning"],
        inventory["parameters"],
        root,
        completeness,
    )
    _validate_candidate(
        inventory["candidate_binding"],
        root,
        expected_bindings,
        inventory["parameters"],
        completeness,
    )
    expected_status = "complete" if not completeness else "planning"
    _expect(
        inventory["status"] == expected_status,
        f"inventory.status must be {expected_status!r} for its current facts",
    )
    if require_complete and completeness:
        preview = "; ".join(completeness[:8])
        if len(completeness) > 8:
            preview += f"; and {len(completeness) - 8} more"
        raise GovernedParameterInventoryError(
            f"production completeness required but unresolved facts remain: {preview}"
        )
    return inventory


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="reject planning, missing, or not-available production facts",
    )
    args = parser.parse_args()
    try:
        inventory = validate_inventory(
            args.repo_root,
            args.inventory,
            require_complete=args.require_complete,
        )
    except GovernedParameterInventoryError as exc:
        print(f"governed parameter inventory check failed: {exc}")
        return 1
    summary = inventory["inventory_summary"]
    print(
        "governed parameter inventory check passed "
        f"({summary['ggp_count']} GGP, {summary['gtp_count']} GTP, "
        f"{summary['expected_host_binding_count']} expected host bindings; "
        f"status={inventory['status']})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
