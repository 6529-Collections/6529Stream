#!/usr/bin/env python3
"""Generate and check the committed ABI compatibility baseline."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import generate_release_artifacts as release_artifacts


ABI_SURFACE_SCHEMA = "6529stream.abi-surface-baseline.v2"
GENERATOR_VERSION = "2"

DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_OUT = Path("out-release")
DEFAULT_BASELINE = Path("release-artifacts/baselines/v0.1.0/abi-surface.json")
DEFAULT_TARGET_MANIFEST = Path("release-artifacts/stream-core-permanent-interface.json")
TARGET_NORMATIVE_RETURN_SOURCE = Path("docs/stream-long-term-architecture.md")
TARGET_REQUIRED_REVISION_RETURN_SIGNATURES = {
    "gasParameterInfo(bytes32)",
    "getSatellitePointer(bytes32)",
}

# Independent, reviewer-owned lock for the complete ordered active target.  The
# normative manifest remains the rich source of ownership/authorization data;
# these deliberately duplicated ABI shapes stop a status substitution or an
# internally valid dummy entry from silently changing the Permanent surface.
TARGET_ACTIVE_SURFACE_LOCK_SCHEMA = (
    "6529stream.stream-core-active-surface-lock.v1"
)
TARGET_ACTIVE_SURFACE_LOCK_SHA256 = (
    "sha256:2513151416a7fc01753226120b415de67ba4f1e5ebf79e6e7ae8a1a3e8aefdc4"
)
TARGET_FULL_MANIFEST_LOCK_SCHEMA = (
    "6529stream.stream-core-permanent-interface-semantic-lock.v1"
)
TARGET_FULL_MANIFEST_LOCK_SHA256 = (
    "sha256:18992066d0c6b22c27d37112b13e6b7d3d7efe5d8e46b4ded9fa25d6d0652f55"
)
TARGET_ACTIVE_FUNCTION_SURFACES = (
    ("abortPreparedMintFromManager(uint256,bytes32)", "nonpayable", ()),
    ("approve(address,uint256)", "nonpayable", ()),
    ("balanceOf(address)", "view", ("uint256",)),
    ("blockCollectionBurns(uint256)", "nonpayable", ()),
    ("burn(uint256)", "nonpayable", ()),
    ("collectionBurnsBlocked(uint256)", "view", ("bool",)),
    ("collectionBurnsBlockedAtBlock(uint256)", "view", ("uint64",)),
    ("collectionExists(uint256)", "view", ("bool",)),
    ("collectionFreezeStatus(uint256)", "view", ("bool",)),
    ("collectionHasMaxSupply(uint256)", "view", ("bool",)),
    ("collectionMaxSupply(uint256)", "view", ("uint256",)),
    ("collectionMintedEver(uint256)", "view", ("uint256",)),
    ("collectionNextSerial(uint256)", "view", ("uint256",)),
    ("collectionStatus(uint256)", "view", ("uint8",)),
    ("collectionSupplyMode(uint256)", "view", ("uint8",)),
    (
        "completePreparedMintFromManager(uint256,address,bytes32,bytes32)",
        "nonpayable",
        (),
    ),
    ("conditionalRaiseGasParameter(bytes32,uint256)", "nonpayable", ()),
    ("conditionalRelowerGasParameter(bytes32,uint256)", "nonpayable", ()),
    ("contractURI()", "view", ("string",)),
    ("coordinatorAtMint(uint256)", "view", ("address",)),
    ("createCollection(uint8,bool,uint256,uint8)", "nonpayable", ("uint256",)),
    ("emergencyRaiseGasParameter(bytes32,uint256)", "nonpayable", ()),
    ("emitBatchMetadataUpdate(uint256,uint256,bytes32)", "nonpayable", ()),
    ("emitContractURIUpdated()", "nonpayable", ()),
    ("emitMetadataUpdate(uint256,bytes32)", "nonpayable", ()),
    ("freezeCollection(uint256)", "nonpayable", ()),
    ("freezeSatellitePointer(bytes32)", "nonpayable", ()),
    (
        "gasParameterInfo(bytes32)",
        "view",
        ("uint256", "uint256", "address", "uint8", "uint64", "uint64"),
    ),
    ("getApproved(uint256)", "view", ("address",)),
    (
        "getSatellitePointer(bytes32)",
        "view",
        (
            "address",
            "bytes32",
            "bool",
            "bytes32",
            "bytes4",
            "address",
            "uint8",
            "bytes32",
            "bytes32",
            "uint64",
        ),
    ),
    ("isApprovedForAll(address,address)", "view", ("bool",)),
    ("lastAllocatedCollectionId()", "view", ("uint256",)),
    ("lastAllocatedTokenId()", "view", ("uint256",)),
    ("lowerGasParameter(bytes32,uint256)", "nonpayable", ()),
    (
        "mintFromManager(uint256,address,bytes,bytes32,bytes32)",
        "nonpayable",
        ("uint256", "uint256"),
    ),
    ("name()", "view", ("string",)),
    ("ownerOf(uint256)", "view", ("address",)),
    ("pendingPreparedMintTokenId()", "view", ("uint256",)),
    ("preparedMint(uint256)", "view", ("(bool,bytes32,uint256)",)),
    (
        "prepareMintFromManager(uint256,bytes,bytes32,bytes32)",
        "nonpayable",
        ("uint256", "uint256"),
    ),
    ("raiseGasParameter(bytes32,uint256)", "nonpayable", ()),
    ("rebindGasParameterProbe(bytes32,address)", "nonpayable", ()),
    ("royaltyInfo(uint256,uint256)", "view", ("address", "uint256")),
    ("safeTransferFrom(address,address,uint256,bytes)", "nonpayable", ()),
    ("safeTransferFrom(address,address,uint256)", "nonpayable", ()),
    ("setApprovalForAll(address,bool)", "nonpayable", ()),
    ("setCollectionMaxSupply(uint256,uint256)", "nonpayable", ()),
    ("setCollectionStatus(uint256,uint8)", "nonpayable", ()),
    ("supportsInterface(bytes4)", "view", ("bool",)),
    ("symbol()", "view", ("string",)),
    (
        "tokenCollectionIdentity(uint256)",
        "view",
        ("bool", "uint256", "uint256", "bool"),
    ),
    ("tokenData(uint256)", "view", ("bytes",)),
    ("tokenLifecycle(uint256)", "view", ("uint8",)),
    ("tokenURI(uint256)", "view", ("string",)),
    ("totalSupply()", "view", ("uint256",)),
    ("totalSupplyOfCollection(uint256)", "view", ("uint256",)),
    ("transferFrom(address,address,uint256)", "nonpayable", ()),
    ("updateSatellitePointer(bytes32,address)", "nonpayable", ()),
)
TARGET_ACTIVE_EVENT_SURFACES = (
    ("Approval(address,address,uint256)", (True, True, True), False, None),
    ("ApprovalForAll(address,address,bool)", (True, True, False), False, None),
    ("BatchMetadataUpdate(uint256,uint256)", (False, False), False, None),
    (
        "CollectionBurnsBlocked(uint16,uint256,bytes32)",
        (False, True, True),
        False,
        1,
    ),
    ("CollectionFrozen(uint16,uint256,bytes32)", (False, True, True), False, 1),
    ("ContractURIUpdated()", (), False, None),
    (
        "CoreSatellitePointerFrozen(uint16,bytes32,bytes32,address,bytes32)",
        (False, True, True, False, False),
        False,
        1,
    ),
    (
        "CoreSatellitePointerUpdated(uint16,bytes32,bytes32,address,address)",
        (False, True, True, True, False),
        False,
        1,
    ),
    (
        "GasParameterProbeRebound(uint16,bytes32,address,bytes32,address,address)",
        (False, True, True, True, False, False),
        False,
        1,
    ),
    (
        "GasParameterUpdated(uint16,bytes32,address,bytes32,uint256,uint256,uint256)",
        (False, True, True, True, False, False, False),
        False,
        1,
    ),
    ("MetadataUpdate(uint256)", (False,), False, None),
    (
        "StreamCollectionCreated(uint16,uint256,bytes32,uint8,bool,uint256,uint8)",
        (False, True, True, False, False, False, False),
        False,
        1,
    ),
    (
        "StreamCollectionMaxSupplyUpdated(uint16,uint256,bytes32,uint256,uint256)",
        (False, True, True, False, False),
        False,
        1,
    ),
    (
        "StreamCollectionStatusUpdated(uint16,uint256,bytes32,uint8,uint8)",
        (False, True, True, False, False),
        False,
        1,
    ),
    (
        "StreamMetadataRefresh(uint16,bytes32,uint256,uint256)",
        (False, True, True, True),
        False,
        1,
    ),
    (
        "StreamTokenBurned(uint256,uint256,uint256,uint16)",
        (True, True, False, False),
        False,
        1,
    ),
    (
        "TokenCollectionRegistered(uint16,uint256,uint256,uint256)",
        (False, True, True, False),
        False,
        1,
    ),
    (
        "TokenCollectionRegistrationReverted(uint16,uint256,uint256)",
        (False, True, True),
        False,
        1,
    ),
    ("Transfer(address,address,uint256)", (True, True, True), False, None),
)

TARGET_ABI_SCHEMA = "6529stream.stream-core-permanent-interface.v1"
TARGET_TOP_LEVEL_KEYS = {
    "schema_version",
    "artifact_role",
    "contract",
    "coverage",
    "bootstrap_bind_authority_challenge",
    "bytecode_budget_groups",
    "functions",
    "events",
}
TARGET_COVERAGE_KEYS = {
    "permanence_class",
    "completeness",
    "bytecode_measurement_authority",
    "implementation_comparison",
    "implementation_baseline",
    "excluded_abi_categories",
    "required_absent_abi_categories",
    "excluded_permanence_classes",
}
TARGET_COMMON_ENTRY_KEYS = {
    "id",
    "status",
    "bytecode_budget_group",
    "permanence_class",
    "owner_subsystem",
    "interface_name",
    "authorization_model",
    "normative_home",
    "signature",
    "supersedes",
    "replaced_by",
    "retirement_disposition",
    "replacement_owner",
    "replacement_signature",
    "retirement_rationale",
}
TARGET_BUDGET_GROUP_KEYS = {"id", "description"}
TARGET_BOOTSTRAP_BIND_CHALLENGE_KEYS = {
    "scope",
    "call_mode",
    "function_signature",
    "selector",
    "arguments",
    "required_check_order",
    "authorized_no_action_error_signature",
    "authorized_no_action_error_selector",
    "wrong_executor_error_signature",
    "wrong_executor_error_selector",
    "accepted_outcome",
    "rejected_outcomes",
}
TARGET_BOOTSTRAP_BIND_AUTHORITY_CHALLENGE = {
    "scope": "genesis_bootstrap_bind_only",
    "call_mode": "staticcall",
    "function_signature": "updateSatellitePointer(bytes32,address)",
    "selector": "0xac1e5708",
    "arguments": ["0x" + ("00" * 32), "0x" + ("00" * 20)],
    "required_check_order": [
        "immutable_executor_caller",
        "executing_current_action",
        "argument_validation",
    ],
    "authorized_no_action_error_signature": "NoExecutingGovernanceAction()",
    "authorized_no_action_error_selector": "0xb8456c92",
    "wrong_executor_error_signature": "UnauthorizedGovernanceExecutor(address)",
    "wrong_executor_error_selector": "0xdd2aa8bd",
    "accepted_outcome": "authorized_no_action_error_only",
    "rejected_outcomes": [
        "success",
        "empty_revert_data",
        "wrong_executor_error",
        "any_other_revert",
    ],
}
TARGET_FUNCTION_KEYS = TARGET_COMMON_ENTRY_KEYS | {
    "selector",
    "returns",
    "state_mutability",
}
TARGET_EVENT_KEYS = TARGET_COMMON_ENTRY_KEYS | {
    "topic0",
    "anonymous",
    "indexed",
    "schema_version",
    "standard_interface",
}
TARGET_STATUSES = {"active_target", "retired_pre_genesis"}
TARGET_REQUIRED_ABSENT_CATEGORIES = {
    "fallback": "fallbacks",
    "receive": "receives",
}
TARGET_PERMANENCE_BY_STATUS = {
    "active_target": "Permanent",
    "retired_pre_genesis": "NotPermanentPreGenesis",
}
TARGET_STATE_MUTABILITIES = {"pure", "view", "payable", "nonpayable"}
SIGNATURE_RE = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)\((.*)\)$")
INTEGER_TYPE_RE = re.compile(r"^(u?int)([0-9]{0,3})$")
BYTES_TYPE_RE = re.compile(r"^bytes([0-9]{1,2})$")
ARRAY_SUFFIX_RE = re.compile(r"\[[0-9]*\]$")
PLACEHOLDER_RE = re.compile(r"\b(?:TBD|TODO|PLACEHOLDER|UNKNOWN)\b", re.IGNORECASE)
SOLIDITY_FUNCTION_RETURN_RE = re.compile(
    r"\bfunction\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*"
    r"\((?P<inputs>[^()]*)\)"
    r"(?:(?!\bfunction\b).)*?\breturns\s*"
    r"\((?P<returns>[^()]*)\)\s*;",
    re.DOTALL,
)
SOLIDITY_ABI_TYPE_ALIASES = {
    "ModuleRegistryStatus": "uint8",
}

ENTRY_CATEGORIES = (
    "constructors",
    "functions",
    "events",
    "errors",
    "fallbacks",
    "receives",
)


class AbiCompatibilityError(RuntimeError):
    pass


IJSON_SAFE_INTEGER_MAX = (1 << 53) - 1


def reject_duplicate_json_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Reject duplicate object members instead of accepting last-key-wins JSON."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise AbiCompatibilityError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def parse_ijson_integer(token: str) -> int:
    value = int(token)
    if abs(value) > IJSON_SAFE_INTEGER_MAX:
        raise AbiCompatibilityError(
            f"JSON integer is outside the I-JSON interoperable range: {token}"
        )
    return value


def reject_json_float(token: str) -> float:
    raise AbiCompatibilityError(
        f"floating-point JSON is forbidden in normative ABI checker inputs: {token}"
    )


def reject_json_constant(token: str) -> None:
    raise AbiCompatibilityError(f"non-I-JSON token is forbidden: {token}")


def load_strict_json(path: Path) -> Any:
    """Load strict UTF-8, duplicate-free JSON for normative checker inputs."""
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise AbiCompatibilityError(f"missing required file: {path}") from exc
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise AbiCompatibilityError(f"{path} is not strict UTF-8 JSON: {exc}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=reject_duplicate_json_pairs,
            parse_int=parse_ijson_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        raise AbiCompatibilityError(f"invalid JSON in {path}: {exc}") from exc


def require_exact_keys(
    value: dict[str, Any], expected: set[str], location: str
) -> None:
    actual = set(value)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing or extra:
        details: list[str] = []
        if missing:
            details.append(f"missing {', '.join(missing)}")
        if extra:
            details.append(f"unexpected {', '.join(extra)}")
        raise AbiCompatibilityError(f"{location} has invalid keys: {'; '.join(details)}")


def split_abi_types(value: str, location: str) -> list[str]:
    if value == "":
        return []

    parts: list[str] = []
    start = 0
    depth = 0
    for index, character in enumerate(value):
        if character == "(":
            depth += 1
        elif character == ")":
            depth -= 1
            if depth < 0:
                raise AbiCompatibilityError(f"{location} has unbalanced tuple parentheses")
        elif character == "," and depth == 0:
            parts.append(value[start:index])
            start = index + 1
    if depth != 0:
        raise AbiCompatibilityError(f"{location} has unbalanced tuple parentheses")
    parts.append(value[start:])
    if any(not part for part in parts):
        raise AbiCompatibilityError(f"{location} contains an empty ABI type")
    return parts


def validate_abi_type(value: Any, location: str) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise AbiCompatibilityError(f"{location} must be a canonical ABI type string")

    base = value
    while True:
        suffix = ARRAY_SUFFIX_RE.search(base)
        if suffix is None:
            break
        base = base[: suffix.start()]

    if base.startswith("(") and base.endswith(")"):
        tuple_members = split_abi_types(base[1:-1], location)
        if not tuple_members:
            raise AbiCompatibilityError(f"{location} contains an empty tuple")
        for index, member in enumerate(tuple_members):
            validate_abi_type(member, f"{location} tuple member {index}")
        return value

    if base in {"address", "bool", "string", "bytes", "function"}:
        return value

    integer_match = INTEGER_TYPE_RE.fullmatch(base)
    if integer_match is not None:
        width_text = integer_match.group(2)
        if not width_text:
            raise AbiCompatibilityError(
                f"{location} must spell integer widths explicitly (for example uint256)"
            )
        width = int(width_text)
        if width < 8 or width > 256 or width % 8 != 0:
            raise AbiCompatibilityError(f"{location} has invalid integer width {width}")
        return value

    bytes_match = BYTES_TYPE_RE.fullmatch(base)
    if bytes_match is not None and 1 <= int(bytes_match.group(1)) <= 32:
        return value

    raise AbiCompatibilityError(f"{location} has unsupported ABI type {value!r}")


def signature_types(signature: Any, location: str) -> list[str]:
    if not isinstance(signature, str) or not signature:
        raise AbiCompatibilityError(f"{location} must be a non-empty string")
    if signature != signature.strip() or any(character.isspace() for character in signature):
        raise AbiCompatibilityError(f"{location} must be canonical and contain no whitespace")
    match = SIGNATURE_RE.fullmatch(signature)
    if match is None:
        raise AbiCompatibilityError(f"{location} is not a canonical ABI signature")
    types = split_abi_types(match.group(2), location)
    for index, abi_type in enumerate(types):
        validate_abi_type(abi_type, f"{location} input {index}")
    return types


def require_nonempty_string(value: Any, location: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise AbiCompatibilityError(f"{location} must be a non-empty string")
    if value != value.strip():
        raise AbiCompatibilityError(f"{location} must not have surrounding whitespace")
    if PLACEHOLDER_RE.search(value):
        raise AbiCompatibilityError(f"{location} contains placeholder language")
    return value


def validate_normative_home(repo_root: Path, value: Any, location: str) -> None:
    home = require_nonempty_string(value, location)
    if home.count("#") != 1:
        raise AbiCompatibilityError(f"{location} must use path#ANCHOR form")
    path_text, anchor = home.split("#", 1)
    relative_path = Path(path_text)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        raise AbiCompatibilityError(f"{location} must stay within the repository")
    if not anchor or not re.fullmatch(r"[A-Z0-9-]+", anchor):
        raise AbiCompatibilityError(f"{location} has invalid anchor {anchor!r}")
    source_path = repo_root / relative_path
    try:
        source_text = source_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise AbiCompatibilityError(f"{location} references missing file {path_text}") from exc
    if f"[{anchor}]" not in source_text:
        raise AbiCompatibilityError(
            f"{location} references missing anchor [{anchor}] in {path_text}"
        )


def solidity_declaration_abi_type(value: str, location: str) -> str:
    declaration = " ".join(value.strip().split())
    if not declaration:
        raise AbiCompatibilityError(f"{location} is an empty Solidity declaration")
    tokens = declaration.split(" ")
    abi_type = SOLIDITY_ABI_TYPE_ALIASES.get(tokens[0], tokens[0])
    if abi_type == "address" and len(tokens) > 1 and tokens[1] == "payable":
        return "address"
    return abi_type


def normative_revision_return_tuples(repo_root: Path) -> dict[str, tuple[str, ...]]:
    """Extract direct revision-bearing return tuples from the normative LTA ABI blocks."""
    source_path = repo_root / TARGET_NORMATIVE_RETURN_SOURCE
    try:
        source_text = source_path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise AbiCompatibilityError(
            f"missing normative return-tuple source {TARGET_NORMATIVE_RETURN_SOURCE}"
        ) from exc

    tuples_by_signature: dict[str, set[tuple[str, ...]]] = {}
    for match_index, match in enumerate(SOLIDITY_FUNCTION_RETURN_RE.finditer(source_text)):
        return_declarations = split_abi_types(
            match.group("returns").strip(),
            f"{TARGET_NORMATIVE_RETURN_SOURCE} function return block {match_index}",
        )
        if not any(re.search(r"\brevision\b", value) for value in return_declarations):
            continue
        input_declarations = split_abi_types(
            match.group("inputs").strip(),
            f"{TARGET_NORMATIVE_RETURN_SOURCE} function input block {match_index}",
        )
        input_types = tuple(
            solidity_declaration_abi_type(
                value,
                f"{TARGET_NORMATIVE_RETURN_SOURCE} function input {match_index}:{index}",
            )
            for index, value in enumerate(input_declarations)
        )
        return_types = tuple(
            solidity_declaration_abi_type(
                value,
                f"{TARGET_NORMATIVE_RETURN_SOURCE} function return {match_index}:{index}",
            )
            for index, value in enumerate(return_declarations)
        )
        signature = f"{match.group('name')}({','.join(input_types)})"
        tuples_by_signature.setdefault(signature, set()).add(return_types)

    conflicting = {
        signature: tuples
        for signature, tuples in tuples_by_signature.items()
        if len(tuples) != 1
    }
    if conflicting:
        raise AbiCompatibilityError(
            "normative revision-bearing function declarations disagree: "
            + ", ".join(sorted(conflicting))
        )
    return {
        signature: next(iter(tuples))
        for signature, tuples in tuples_by_signature.items()
    }


def validate_target_normative_revision_returns(
    repo_root: Path,
    functions: list[dict[str, Any]],
    location: str,
) -> None:
    """Reconcile active target returns with revision-bearing normative Solidity ABI blocks."""
    source_path = repo_root / TARGET_NORMATIVE_RETURN_SOURCE
    if not source_path.exists():
        # Minimal unit-test repositories exercise schema validation without the
        # committed normative corpus. The committed target always has this file.
        return
    normative = normative_revision_return_tuples(repo_root)
    missing_normative = sorted(
        TARGET_REQUIRED_REVISION_RETURN_SIGNATURES - normative.keys()
    )
    if missing_normative:
        raise AbiCompatibilityError(
            f"{TARGET_NORMATIVE_RETURN_SOURCE} is missing required revision-bearing "
            "return declarations: " + ", ".join(missing_normative)
        )
    active_by_signature = {
        entry["signature"]: entry
        for entry in functions
        if entry["status"] == "active_target"
    }
    missing_target = sorted(
        TARGET_REQUIRED_REVISION_RETURN_SIGNATURES - active_by_signature.keys()
    )
    if missing_target:
        raise AbiCompatibilityError(
            f"{location} is missing required revision-bearing target functions: "
            + ", ".join(missing_target)
        )
    for signature, expected_returns in sorted(normative.items()):
        entry = active_by_signature.get(signature)
        if entry is None:
            continue
        actual_returns = tuple(entry["returns"])
        if actual_returns != expected_returns:
            raise AbiCompatibilityError(
                f"{location} {signature} return tuple {actual_returns!r} does not match "
                f"normative {TARGET_NORMATIVE_RETURN_SOURCE} tuple {expected_returns!r}"
            )


def target_active_surface_lock_payload(
    function_surfaces: tuple[tuple[str, str, tuple[str, ...]], ...],
    event_surfaces: tuple[
        tuple[str, tuple[bool, ...], bool, int | None], ...
    ],
) -> dict[str, Any]:
    """Build the canonical, intentionally narrow active-surface lock view."""
    return {
        "schema": TARGET_ACTIVE_SURFACE_LOCK_SCHEMA,
        "functions": [
            {
                "signature": signature,
                "state_mutability": state_mutability,
                "returns": list(returns),
            }
            for signature, state_mutability, returns in function_surfaces
        ],
        "events": [
            {
                "signature": signature,
                "indexed": list(indexed),
                "anonymous": anonymous,
                "schema_version": schema_version,
            }
            for signature, indexed, anonymous, schema_version in event_surfaces
        ],
    }


def target_active_surface_lock_digest(
    function_surfaces: tuple[tuple[str, str, tuple[str, ...]], ...],
    event_surfaces: tuple[
        tuple[str, tuple[bool, ...], bool, int | None], ...
    ],
) -> str:
    payload = target_active_surface_lock_payload(function_surfaces, event_surfaces)
    canonical = json.dumps(
        payload,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return "sha256:" + hashlib.sha256(canonical).hexdigest()


def target_full_manifest_lock_payload(manifest: dict[str, Any]) -> dict[str, Any]:
    """Build the reviewer-pinned view of every normative target semantic."""
    return {
        "schema": TARGET_FULL_MANIFEST_LOCK_SCHEMA,
        "manifest": manifest,
    }


def target_full_manifest_lock_digest(manifest: dict[str, Any]) -> str:
    """Hash the complete manifest while preserving all ordered arrays."""
    try:
        canonical = json.dumps(
            target_full_manifest_lock_payload(manifest),
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("ascii")
    except (TypeError, ValueError) as exc:
        raise AbiCompatibilityError(
            "StreamCore target manifest contains a non-canonical semantic value"
        ) from exc
    return "sha256:" + hashlib.sha256(canonical).hexdigest()


def validate_target_full_manifest_lock(
    manifest: dict[str, Any],
    location: str,
) -> None:
    """Require every target field and ordered active/retired row to stay reviewed."""
    actual_digest = target_full_manifest_lock_digest(manifest)
    if actual_digest != TARGET_FULL_MANIFEST_LOCK_SHA256:
        raise AbiCompatibilityError(
            f"{location} does not match the complete reviewer-pinned target semantic lock: "
            f"expected {TARGET_FULL_MANIFEST_LOCK_SHA256}, got {actual_digest}"
        )


def validate_target_active_surface_lock(
    functions: list[dict[str, Any]],
    events: list[dict[str, Any]],
    location: str,
) -> None:
    """Require the complete ordered active ABI to match the reviewed fixed lock."""
    expected_digest = target_active_surface_lock_digest(
        TARGET_ACTIVE_FUNCTION_SURFACES,
        TARGET_ACTIVE_EVENT_SURFACES,
    )
    if expected_digest != TARGET_ACTIVE_SURFACE_LOCK_SHA256:
        raise AbiCompatibilityError(
            "checker-owned active target surface constants disagree with their reviewed "
            f"fixed digest: expected {TARGET_ACTIVE_SURFACE_LOCK_SHA256}, "
            f"recomputed {expected_digest}"
        )

    actual_functions = tuple(
        (
            entry["signature"],
            entry["state_mutability"],
            tuple(entry["returns"]),
        )
        for entry in functions
        if entry["status"] == "active_target"
    )
    actual_events = tuple(
        (
            entry["signature"],
            tuple(entry["indexed"]),
            entry["anonymous"],
            entry["schema_version"],
        )
        for entry in events
        if entry["status"] == "active_target"
    )
    actual_digest = target_active_surface_lock_digest(actual_functions, actual_events)
    if (
        actual_functions != TARGET_ACTIVE_FUNCTION_SURFACES
        or actual_events != TARGET_ACTIVE_EVENT_SURFACES
        or actual_digest != TARGET_ACTIVE_SURFACE_LOCK_SHA256
    ):
        raise AbiCompatibilityError(
            f"{location} active functions/events do not match the independent active "
            "target surface lock: "
            f"expected {TARGET_ACTIVE_SURFACE_LOCK_SHA256}, got {actual_digest}"
        )


def validate_string_list(value: Any, location: str) -> list[str]:
    if not isinstance(value, list):
        raise AbiCompatibilityError(f"{location} must be a list")
    result: list[str] = []
    for index, item in enumerate(value):
        result.append(require_nonempty_string(item, f"{location}[{index}]"))
    if len(result) != len(set(result)):
        raise AbiCompatibilityError(f"{location} contains duplicate IDs")
    return result


def validate_target_entry_common(
    repo_root: Path,
    entry: dict[str, Any],
    location: str,
    budget_group_ids: set[str],
) -> tuple[str, str, list[str], str | None]:
    entry_id = require_nonempty_string(entry["id"], f"{location}.id")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", entry_id):
        raise AbiCompatibilityError(f"{location}.id must be lowercase kebab-case")
    status = entry["status"]
    if status not in TARGET_STATUSES:
        raise AbiCompatibilityError(f"{location}.status has invalid value {status!r}")
    expected_permanence = TARGET_PERMANENCE_BY_STATUS[status]
    if entry["permanence_class"] != expected_permanence:
        raise AbiCompatibilityError(
            f"{location}.permanence_class must be {expected_permanence!r} for {status}"
        )
    budget_group = entry["bytecode_budget_group"]
    if status == "active_target":
        budget_group = require_nonempty_string(
            budget_group,
            f"{location}.bytecode_budget_group",
        )
        if budget_group not in budget_group_ids:
            raise AbiCompatibilityError(
                f"{location}.bytecode_budget_group references unknown group {budget_group!r}"
            )
    elif budget_group is not None:
        raise AbiCompatibilityError(
            f"{location}.bytecode_budget_group must be null for retired entries"
        )
    for key in ("owner_subsystem", "interface_name", "authorization_model"):
        require_nonempty_string(entry[key], f"{location}.{key}")
    validate_normative_home(repo_root, entry["normative_home"], f"{location}.normative_home")
    input_types = signature_types(entry["signature"], f"{location}.signature")
    supersedes = validate_string_list(entry["supersedes"], f"{location}.supersedes")
    replaced_by = validate_string_list(entry["replaced_by"], f"{location}.replaced_by")
    if entry_id in supersedes or entry_id in replaced_by:
        raise AbiCompatibilityError(f"{location} cannot reference itself in lineage")
    disposition = entry["retirement_disposition"]
    replacement_owner = entry["replacement_owner"]
    replacement_signature = entry["replacement_signature"]
    retirement_rationale = entry["retirement_rationale"]
    if status == "active_target":
        if replaced_by:
            raise AbiCompatibilityError(f"{location} active target cannot have replaced_by entries")
        if any(
            value is not None
            for value in (
                disposition,
                replacement_owner,
                replacement_signature,
                retirement_rationale,
            )
        ):
            raise AbiCompatibilityError(
                f"{location} active target must have null retirement metadata"
            )
    else:
        if supersedes:
            raise AbiCompatibilityError(f"{location} retired entry cannot supersede entries")
        if disposition not in {
            "replaced_in_core",
            "relocated_outside_core",
            "removed_without_replacement",
        }:
            raise AbiCompatibilityError(
                f"{location}.retirement_disposition has invalid value {disposition!r}"
            )
        require_nonempty_string(retirement_rationale, f"{location}.retirement_rationale")
        if disposition == "replaced_in_core":
            if not replaced_by:
                raise AbiCompatibilityError(
                    f"{location} replaced_in_core entry must identify a manifest replacement"
                )
            if replacement_owner != "StreamCore" or replacement_signature is not None:
                raise AbiCompatibilityError(
                    f"{location} replaced_in_core metadata must name StreamCore and use lineage IDs"
                )
        elif disposition == "relocated_outside_core":
            if replaced_by:
                raise AbiCompatibilityError(
                    f"{location} relocated_outside_core entry cannot name a Core replacement"
                )
            require_nonempty_string(replacement_owner, f"{location}.replacement_owner")
            if replacement_owner == "StreamCore":
                raise AbiCompatibilityError(
                    f"{location}.replacement_owner must identify an external subsystem"
                )
            if replacement_signature is not None:
                signature_types(replacement_signature, f"{location}.replacement_signature")
        elif replaced_by or replacement_owner is not None or replacement_signature is not None:
            raise AbiCompatibilityError(
                f"{location} removed_without_replacement must not name a replacement"
            )
    return entry_id, status, input_types, budget_group


def validate_target_manifest(
    repo_root: Path,
    manifest_path: Path,
    cast_bin: str = "cast",
) -> dict[str, Any]:
    manifest = load_strict_json(manifest_path)
    if not isinstance(manifest, dict):
        raise AbiCompatibilityError(f"{manifest_path} must contain a JSON object")
    require_exact_keys(manifest, TARGET_TOP_LEVEL_KEYS, str(manifest_path))
    if manifest["schema_version"] != TARGET_ABI_SCHEMA:
        raise AbiCompatibilityError(
            f"{manifest_path} has schema {manifest['schema_version']!r}, "
            f"expected {TARGET_ABI_SCHEMA!r}"
        )
    if manifest["artifact_role"] != "normative_external_interface_target":
        raise AbiCompatibilityError(
            f"{manifest_path} artifact_role must be 'normative_external_interface_target'"
        )
    if manifest["contract"] != "StreamCore":
        raise AbiCompatibilityError(f"{manifest_path} contract must be 'StreamCore'")
    coverage = manifest["coverage"]
    if not isinstance(coverage, dict):
        raise AbiCompatibilityError(f"{manifest_path} coverage must be an object")
    require_exact_keys(coverage, TARGET_COVERAGE_KEYS, f"{manifest_path}.coverage")
    expected_coverage = {
        "permanence_class": "Permanent",
        "completeness": "complete_permanent_functions_and_events",
        "bytecode_measurement_authority": "complete_linked_via_ir_runtime_measurement_only",
        "implementation_comparison": "deferred_until_complete_core_cutover",
        "implementation_baseline": "release-artifacts/baselines/v0.1.0/abi-surface.json",
        "excluded_abi_categories": ["custom_errors", "constructor"],
        "required_absent_abi_categories": ["fallback", "receive"],
        "excluded_permanence_classes": ["Medium", "Replaceable"],
    }
    if coverage != expected_coverage:
        raise AbiCompatibilityError(
            f"{manifest_path} coverage must preserve the complete Permanent function/event declaration"
        )

    bind_challenge = manifest["bootstrap_bind_authority_challenge"]
    if not isinstance(bind_challenge, dict):
        raise AbiCompatibilityError(
            f"{manifest_path}.bootstrap_bind_authority_challenge must be an object"
        )
    require_exact_keys(
        bind_challenge,
        TARGET_BOOTSTRAP_BIND_CHALLENGE_KEYS,
        f"{manifest_path}.bootstrap_bind_authority_challenge",
    )
    if bind_challenge != TARGET_BOOTSTRAP_BIND_AUTHORITY_CHALLENGE:
        raise AbiCompatibilityError(
            f"{manifest_path}.bootstrap_bind_authority_challenge must preserve the exact "
            "write-impossible genesis authority challenge"
        )
    for signature_key, selector_key in (
        ("function_signature", "selector"),
        ("authorized_no_action_error_signature", "authorized_no_action_error_selector"),
        ("wrong_executor_error_signature", "wrong_executor_error_selector"),
    ):
        derived_selector = release_artifacts.run_cast(
            cast_bin,
            ["sig", bind_challenge[signature_key]],
        ).lower()
        if derived_selector != bind_challenge[selector_key]:
            raise AbiCompatibilityError(
                f"{manifest_path}.bootstrap_bind_authority_challenge.{selector_key} is "
                f"{bind_challenge[selector_key]}, derived selector is {derived_selector}"
            )

    budget_groups = manifest["bytecode_budget_groups"]
    if not isinstance(budget_groups, list) or not budget_groups:
        raise AbiCompatibilityError(
            f"{manifest_path}.bytecode_budget_groups must be a non-empty list"
        )
    budget_group_ids: set[str] = set()
    for index, group in enumerate(budget_groups):
        location = f"{manifest_path}.bytecode_budget_groups[{index}]"
        if not isinstance(group, dict):
            raise AbiCompatibilityError(f"{location} must be an object")
        require_exact_keys(group, TARGET_BUDGET_GROUP_KEYS, location)
        group_id = require_nonempty_string(group["id"], f"{location}.id")
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*", group_id):
            raise AbiCompatibilityError(f"{location}.id must be lowercase kebab-case")
        if group_id in budget_group_ids:
            raise AbiCompatibilityError(f"{location}.id duplicates {group_id}")
        require_nonempty_string(group["description"], f"{location}.description")
        budget_group_ids.add(group_id)

    functions = manifest["functions"]
    events = manifest["events"]
    if not isinstance(functions, list) or not functions:
        raise AbiCompatibilityError(f"{manifest_path}.functions must be a non-empty list")
    if not isinstance(events, list) or not events:
        raise AbiCompatibilityError(f"{manifest_path}.events must be a non-empty list")
    all_entries: dict[str, tuple[str, str, dict[str, Any]]] = {}
    active_selectors: dict[str, str] = {}
    active_topics: dict[str, str] = {}
    active_budget_groups: set[str] = set()
    seen_function_signatures: set[tuple[str, str]] = set()
    seen_event_signatures: set[tuple[str, str]] = set()

    for index, entry in enumerate(functions):
        location = f"{manifest_path}.functions[{index}]"
        if not isinstance(entry, dict):
            raise AbiCompatibilityError(f"{location} must be an object")
        require_exact_keys(entry, TARGET_FUNCTION_KEYS, location)
        entry_id, status, _, budget_group = validate_target_entry_common(
            repo_root,
            entry,
            location,
            budget_group_ids,
        )
        if budget_group is not None:
            active_budget_groups.add(budget_group)
        if entry_id in all_entries:
            raise AbiCompatibilityError(f"{location}.id duplicates {entry_id}")
        signature = entry["signature"]
        signature_key = (status, signature)
        if signature_key in seen_function_signatures:
            raise AbiCompatibilityError(f"{location}.signature duplicates {signature} for {status}")
        seen_function_signatures.add(signature_key)
        selector = entry["selector"]
        if not isinstance(selector, str) or not re.fullmatch(r"0x[0-9a-f]{8}", selector):
            raise AbiCompatibilityError(f"{location}.selector must be a lowercase bytes4 hex value")
        derived_selector = release_artifacts.run_cast(cast_bin, ["sig", signature]).lower()
        if derived_selector != selector:
            raise AbiCompatibilityError(
                f"{location}.selector is {selector}, derived selector is {derived_selector}"
            )
        returns = entry["returns"]
        if not isinstance(returns, list):
            raise AbiCompatibilityError(f"{location}.returns must be a list")
        for output_index, output_type in enumerate(returns):
            validate_abi_type(output_type, f"{location}.returns[{output_index}]")
        if entry["state_mutability"] not in TARGET_STATE_MUTABILITIES:
            raise AbiCompatibilityError(
                f"{location}.state_mutability has invalid value {entry['state_mutability']!r}"
            )
        if status == "active_target":
            previous = active_selectors.get(selector)
            if previous is not None:
                raise AbiCompatibilityError(
                    f"active selector collision: {entry_id} and {previous} both use {selector}"
                )
            active_selectors[selector] = entry_id
        all_entries[entry_id] = ("function", status, entry)

    for index, entry in enumerate(events):
        location = f"{manifest_path}.events[{index}]"
        if not isinstance(entry, dict):
            raise AbiCompatibilityError(f"{location} must be an object")
        require_exact_keys(entry, TARGET_EVENT_KEYS, location)
        entry_id, status, input_types, budget_group = validate_target_entry_common(
            repo_root,
            entry,
            location,
            budget_group_ids,
        )
        if budget_group is not None:
            active_budget_groups.add(budget_group)
        if entry_id in all_entries:
            raise AbiCompatibilityError(f"{location}.id duplicates {entry_id}")
        signature = entry["signature"]
        signature_key = (status, signature)
        if signature_key in seen_event_signatures:
            raise AbiCompatibilityError(f"{location}.signature duplicates {signature} for {status}")
        seen_event_signatures.add(signature_key)
        topic0 = entry["topic0"]
        if not isinstance(topic0, str) or not re.fullmatch(r"0x[0-9a-f]{64}", topic0):
            raise AbiCompatibilityError(f"{location}.topic0 must be a lowercase bytes32 hex value")
        derived_topic = release_artifacts.event_topic(cast_bin, signature, False)
        if derived_topic != topic0:
            raise AbiCompatibilityError(
                f"{location}.topic0 is {topic0}, derived topic is {derived_topic}"
            )
        indexed = entry["indexed"]
        if (
            not isinstance(indexed, list)
            or len(indexed) != len(input_types)
            or any(type(value) is not bool for value in indexed)
        ):
            raise AbiCompatibilityError(
                f"{location}.indexed must contain one boolean per event input"
            )
        anonymous = entry["anonymous"]
        if type(anonymous) is not bool or anonymous:
            raise AbiCompatibilityError(
                f"{location}.anonymous must be the boolean false for every Core target event"
            )
        if sum(indexed) > 3:
            raise AbiCompatibilityError(f"{location} has more than three indexed event inputs")
        standard_interface = entry["standard_interface"]
        schema_version = entry["schema_version"]
        if standard_interface is None:
            if status == "active_target":
                if type(schema_version) is not int or schema_version < 1:
                    raise AbiCompatibilityError(
                        f"{location}.schema_version must be a positive integer"
                    )
                if "uint16" not in input_types:
                    raise AbiCompatibilityError(
                        f"{location} versioned protocol event must include a uint16 schema input"
                    )
            elif schema_version is not None and (
                type(schema_version) is not int or schema_version < 1
            ):
                raise AbiCompatibilityError(
                    f"{location}.schema_version must be null or a positive integer"
                )
        else:
            require_nonempty_string(standard_interface, f"{location}.standard_interface")
            if schema_version is not None:
                raise AbiCompatibilityError(
                    f"{location}.schema_version must be null for a standard event"
                )
        if status == "active_target":
            previous = active_topics.get(topic0)
            if previous is not None:
                raise AbiCompatibilityError(
                    f"active topic collision: {entry_id} and {previous} both use {topic0}"
                )
            active_topics[topic0] = entry_id
        all_entries[entry_id] = ("event", status, entry)

    for entry_id, (kind, _status, entry) in all_entries.items():
        for relation, expected_status, inverse in (
            ("supersedes", "retired_pre_genesis", "replaced_by"),
            ("replaced_by", "active_target", "supersedes"),
        ):
            for related_id in entry[relation]:
                related = all_entries.get(related_id)
                if related is None:
                    raise AbiCompatibilityError(
                        f"{entry_id}.{relation} references unknown entry {related_id}"
                    )
                related_kind, related_status, related_entry = related
                if related_kind != kind or related_status != expected_status:
                    raise AbiCompatibilityError(
                        f"{entry_id}.{relation} references incompatible entry {related_id}"
                    )
                if entry_id not in related_entry[inverse]:
                    raise AbiCompatibilityError(
                        f"{entry_id}.{relation} -> {related_id} lacks inverse {inverse} link"
                    )

    phantom_budget_groups = sorted(budget_group_ids - active_budget_groups)
    if phantom_budget_groups:
        raise AbiCompatibilityError(
            f"{manifest_path}.bytecode_budget_groups contains phantom groups: "
            + ", ".join(phantom_budget_groups)
        )

    challenged_signature = bind_challenge["function_signature"]
    challenged_entry = next(
        (
            entry
            for entry in functions
            if entry["status"] == "active_target"
            and entry["signature"] == challenged_signature
        ),
        None,
    )
    if challenged_entry is None:
        raise AbiCompatibilityError(
            f"{manifest_path}.bootstrap_bind_authority_challenge references missing active "
            f"function {challenged_signature}"
        )
    if challenged_entry["selector"] != bind_challenge["selector"]:
        raise AbiCompatibilityError(
            f"{manifest_path}.bootstrap_bind_authority_challenge selector disagrees with "
            f"the active {challenged_signature} entry"
        )

    validate_target_normative_revision_returns(
        repo_root,
        functions,
        str(manifest_path),
    )
    validate_target_active_surface_lock(functions, events, str(manifest_path))
    validate_target_full_manifest_lock(manifest, str(manifest_path))

    return manifest


def validate_target_required_absence(
    manifest: dict[str, Any],
    implementation_surface: dict[str, Any],
) -> None:
    contracts = implementation_surface.get("contracts")
    if not isinstance(contracts, dict) or "StreamCore" not in contracts:
        raise AbiCompatibilityError(
            "implementation ABI surface must include StreamCore for target absence checks"
        )
    core = contracts["StreamCore"]
    entries = core.get("entries") if isinstance(core, dict) else None
    if not isinstance(entries, dict):
        raise AbiCompatibilityError(
            "implementation ABI surface StreamCore entry categories are missing"
        )
    required_absent = manifest["coverage"]["required_absent_abi_categories"]
    for category in required_absent:
        entry_category = TARGET_REQUIRED_ABSENT_CATEGORIES[category]
        category_entries = entries.get(entry_category)
        if not isinstance(category_entries, list):
            raise AbiCompatibilityError(
                f"implementation ABI surface StreamCore.{entry_category} must be a list"
            )
        if category_entries:
            raise AbiCompatibilityError(
                f"StreamCore target requires ABI category {category!r} to be absent"
            )


def target_function_shape(entry: dict[str, Any]) -> tuple[Any, ...]:
    return (
        entry.get("signature"),
        entry.get("state_mutability"),
        tuple(entry.get("returns", [])),
    )


def baseline_function_shape(entry: dict[str, Any]) -> tuple[Any, ...]:
    outputs = entry.get("outputs", [])
    if not isinstance(outputs, list):
        raise AbiCompatibilityError("StreamCore baseline function outputs must be a list")
    return (
        entry.get("signature"),
        entry.get("state_mutability"),
        tuple(output.get("type") if isinstance(output, dict) else None for output in outputs),
    )


def target_event_shape(entry: dict[str, Any]) -> tuple[Any, ...]:
    return (
        entry.get("signature"),
        tuple(entry.get("indexed", [])),
        entry.get("anonymous"),
    )


def baseline_event_shape(entry: dict[str, Any]) -> tuple[Any, ...]:
    inputs = entry.get("inputs", [])
    if not isinstance(inputs, list):
        raise AbiCompatibilityError("StreamCore baseline event inputs must be a list")
    return (
        entry.get("signature"),
        tuple(
            input_value.get("indexed") if isinstance(input_value, dict) else None
            for input_value in inputs
        ),
        entry.get("anonymous"),
    )


def validate_target_retirement_baseline_closure(
    manifest: dict[str, Any],
    baseline: dict[str, Any],
) -> None:
    """Prove every current Core row survives exactly or has one reviewed retirement."""
    contracts = baseline.get("contracts")
    core = contracts.get("StreamCore") if isinstance(contracts, dict) else None
    entries = core.get("entries") if isinstance(core, dict) else None
    if not isinstance(entries, dict):
        raise AbiCompatibilityError(
            "implementation ABI baseline must include StreamCore entry categories"
        )

    categories = (
        (
            "function",
            manifest["functions"],
            entries.get("functions"),
            target_function_shape,
            baseline_function_shape,
        ),
        (
            "event",
            manifest["events"],
            entries.get("events"),
            target_event_shape,
            baseline_event_shape,
        ),
    )
    for label, target_rows, baseline_rows, target_shape, baseline_shape in categories:
        if not isinstance(baseline_rows, list):
            raise AbiCompatibilityError(
                f"implementation ABI baseline StreamCore {label}s must be a list"
            )
        baseline_shapes = [baseline_shape(entry) for entry in baseline_rows]
        active_shapes = [
            target_shape(entry)
            for entry in target_rows
            if entry["status"] == "active_target"
        ]
        retired_shapes = [
            target_shape(entry)
            for entry in target_rows
            if entry["status"] == "retired_pre_genesis"
        ]
        if len(baseline_shapes) != len(set(baseline_shapes)):
            raise AbiCompatibilityError(
                f"implementation ABI baseline has duplicate StreamCore {label} shapes"
            )
        if len(retired_shapes) != len(set(retired_shapes)):
            raise AbiCompatibilityError(
                f"target has duplicate retired StreamCore {label} shapes"
            )

        baseline_set = set(baseline_shapes)
        accounted = set(active_shapes) | set(retired_shapes)
        missing = sorted(baseline_set - accounted, key=repr)
        phantom = sorted(set(retired_shapes) - baseline_set, key=repr)
        double_counted = sorted(
            set(active_shapes) & set(retired_shapes),
            key=repr,
        )
        if missing:
            raise AbiCompatibilityError(
                f"target is missing retirement dispositions for current StreamCore {label} "
                f"shapes: {missing!r}"
            )
        if phantom:
            raise AbiCompatibilityError(
                f"target contains retired StreamCore {label} shapes absent from the "
                f"implementation baseline: {phantom!r}"
            )
        if double_counted:
            raise AbiCompatibilityError(
                f"target double-counts StreamCore {label} shapes as active and retired: "
                f"{double_counted!r}"
            )


def parameter_record(parameter: dict[str, Any], include_indexed: bool = False) -> dict[str, Any]:
    record = {
        "name": parameter.get("name", ""),
        "type": release_artifacts.canonical_type(parameter),
        "internal_type": parameter.get("internalType", ""),
    }
    if include_indexed:
        record["indexed"] = bool(parameter.get("indexed", False))
    if "components" in parameter:
        record["components"] = [
            parameter_record(component, include_indexed=False)
            for component in parameter.get("components", [])
        ]
    return record


def parameter_records(
    parameters: list[dict[str, Any]], include_indexed: bool = False
) -> list[dict[str, Any]]:
    return [
        parameter_record(parameter, include_indexed=include_indexed)
        for parameter in parameters
    ]


def input_signature(entry: dict[str, Any]) -> str:
    return ",".join(
        release_artifacts.canonical_type(parameter)
        for parameter in entry.get("inputs", [])
    )


def constructor_signature(entry: dict[str, Any]) -> str:
    return f"constructor({input_signature(entry)})"


def normalize_abi_entry(entry: dict[str, Any]) -> tuple[str, dict[str, Any]]:
    entry_type = entry.get("type")

    if entry_type == "function":
        signature = release_artifacts.abi_signature(entry)
        return (
            "functions",
            {
                "key": signature,
                "kind": "function",
                "name": entry["name"],
                "signature": signature,
                "inputs": parameter_records(entry.get("inputs", [])),
                "outputs": parameter_records(entry.get("outputs", [])),
                "state_mutability": entry.get("stateMutability", ""),
            },
        )

    if entry_type == "event":
        signature = release_artifacts.abi_signature(entry)
        return (
            "events",
            {
                "key": signature,
                "kind": "event",
                "name": entry["name"],
                "signature": signature,
                "anonymous": bool(entry.get("anonymous", False)),
                "inputs": parameter_records(entry.get("inputs", []), include_indexed=True),
            },
        )

    if entry_type == "error":
        signature = release_artifacts.abi_signature(entry)
        return (
            "errors",
            {
                "key": signature,
                "kind": "error",
                "name": entry["name"],
                "signature": signature,
                "inputs": parameter_records(entry.get("inputs", [])),
            },
        )

    if entry_type == "constructor":
        signature = constructor_signature(entry)
        return (
            "constructors",
            {
                "key": signature,
                "kind": "constructor",
                "signature": signature,
                "inputs": parameter_records(entry.get("inputs", [])),
                "state_mutability": entry.get("stateMutability", ""),
            },
        )

    if entry_type == "fallback":
        return (
            "fallbacks",
            {
                "key": "fallback",
                "kind": "fallback",
                "state_mutability": entry.get("stateMutability", ""),
            },
        )

    if entry_type == "receive":
        return (
            "receives",
            {
                "key": "receive",
                "kind": "receive",
                "state_mutability": entry.get("stateMutability", ""),
            },
        )

    raise AbiCompatibilityError(f"unsupported ABI entry type: {entry_type!r}")


def build_contract_surface(summary: dict[str, Any]) -> dict[str, Any]:
    entries: dict[str, list[dict[str, Any]]] = {category: [] for category in ENTRY_CATEGORIES}
    seen: dict[str, set[str]] = {category: set() for category in ENTRY_CATEGORIES}

    for abi_entry in summary["abi"]:
        category, normalized = normalize_abi_entry(abi_entry)
        key = normalized["key"]
        if key in seen[category]:
            raise AbiCompatibilityError(
                f"{summary['name']} has duplicate ABI {category} entry {key}"
            )
        seen[category].add(key)
        entries[category].append(normalized)

    for category in ENTRY_CATEGORIES:
        entries[category] = sorted(entries[category], key=lambda item: item["key"])

    return {
        "source": summary["source"],
        "artifact_path": summary["artifact_path"],
        "abi_sha256": summary["abi_sha256"],
        "abi_entries": len(summary["abi"]),
        "entry_counts": {
            category: len(entries[category])
            for category in ENTRY_CATEGORIES
        },
        "entries": entries,
    }


def configured_artifact_entries(
    config: dict[str, Any],
    key: str,
    *,
    required: bool = False,
) -> list[dict[str, Any]]:
    entries = config.get(key, [])
    if required and not entries:
        raise AbiCompatibilityError(f"config {key} list is empty")
    if not isinstance(entries, list):
        raise AbiCompatibilityError(f"config {key} must be a list")

    seen: set[str] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise AbiCompatibilityError(f"config {key}[{index}] must be an object")
        name = entry.get("name")
        if not isinstance(name, str) or not name:
            raise AbiCompatibilityError(f"config {key}[{index}] is missing a string name")
        source = entry.get("source")
        if not isinstance(source, str) or not source:
            raise AbiCompatibilityError(f"config {key}[{index}] is missing a string source")
        if name in seen:
            raise AbiCompatibilityError(f"config {key} contains duplicate name {name}")
        seen.add(name)

    return entries


def build_abi_surface(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
) -> dict[str, Any]:
    config = load_strict_json(config_path)
    configured_contracts = configured_artifact_entries(
        config,
        "production_contracts",
        required=True,
    )
    configured_interfaces = configured_artifact_entries(config, "interfaces")

    contracts: dict[str, Any] = {}
    for config_entry in sorted(configured_contracts, key=lambda item: item["name"]):
        summary = release_artifacts.artifact_summary(config_entry, foundry_out, repo_root)
        name = summary["name"]
        contracts[name] = build_contract_surface(summary)

    interfaces: dict[str, Any] = {}
    for config_entry in sorted(configured_interfaces, key=lambda item: item["name"]):
        summary = release_artifacts.artifact_summary(config_entry, foundry_out, repo_root)
        name = summary["name"]
        interfaces[name] = build_contract_surface(summary)

    return {
        "schema_version": ABI_SURFACE_SCHEMA,
        "generated_by": f"scripts/check_abi_compatibility.py:{GENERATOR_VERSION}",
        "source": {
            "config": release_artifacts.normalize_artifact_path(config_path, repo_root),
            "foundry_out": release_artifacts.normalize_artifact_path(foundry_out, repo_root),
        },
        "compatibility_policy": {
            "removed_entries": "fail",
            "changed_entries": "fail",
            "added_entries": "report-compatible",
            "contract_removed_from_production_surface": "fail",
            "contract_added_to_production_surface": "report-compatible",
            "interface_removed_from_published_surface": "fail",
            "interface_added_to_published_surface": "report-compatible",
        },
        "contracts": contracts,
        "interfaces": interfaces,
    }


def load_baseline(path: Path) -> dict[str, Any]:
    baseline = load_strict_json(path)
    if baseline.get("schema_version") != ABI_SURFACE_SCHEMA:
        raise AbiCompatibilityError(
            f"{path} has schema {baseline.get('schema_version')!r}, "
            f"expected {ABI_SURFACE_SCHEMA!r}"
        )
    contracts = baseline.get("contracts")
    if not isinstance(contracts, dict):
        raise AbiCompatibilityError(f"{path} does not contain a contracts object")
    interfaces = baseline.get("interfaces")
    if not isinstance(interfaces, dict):
        raise AbiCompatibilityError(f"{path} does not contain an interfaces object")
    return baseline


def entries_by_key(entries: list[dict[str, Any]], contract: str, category: str) -> dict[str, Any]:
    mapped: dict[str, Any] = {}
    for entry in entries:
        key = entry.get("key")
        if not isinstance(key, str):
            raise AbiCompatibilityError(f"{contract} {category} entry is missing a string key")
        if key in mapped:
            raise AbiCompatibilityError(f"{contract} has duplicate {category} baseline key {key}")
        mapped[key] = entry
    return mapped


def abi_change(
    *,
    change_type: str,
    surface: str,
    subject: str,
    message: str,
    category: str | None = None,
    key: str | None = None,
    baseline: dict[str, Any] | None = None,
    current: dict[str, Any] | None = None,
) -> dict[str, Any]:
    change: dict[str, Any] = {
        "type": change_type,
        "surface": surface,
        "subject": subject,
        # subject is canonical; contract remains as a compatibility alias for
        # consumers written before interface diagnostics were added.
        "contract": subject,
        "message": message,
    }
    if category is not None:
        change["category"] = category
    if key is not None:
        change["key"] = key
    if baseline is not None:
        change["baseline"] = baseline
    if current is not None:
        change["current"] = current
    return change


def compare_surface_entries(
    *,
    baseline_entries_by_name: dict[str, Any],
    current_entries_by_name: dict[str, Any],
    surface: str,
    subject_kind: str,
    removed_subject_type: str,
    added_subject_type: str,
    incompatible: list[dict[str, Any]],
    additive: list[dict[str, Any]],
) -> None:
    baseline_names = set(baseline_entries_by_name)
    current_names = set(current_entries_by_name)

    for subject in sorted(baseline_names - current_names):
        incompatible.append(
            abi_change(
                change_type=removed_subject_type,
                surface=surface,
                subject=subject,
                message=f"{subject_kind} {subject} is missing from current surface",
            )
        )

    for subject in sorted(current_names - baseline_names):
        additive.append(
            abi_change(
                change_type=added_subject_type,
                surface=surface,
                subject=subject,
                message=f"{subject_kind} {subject} was added to current surface",
            )
        )

    for subject in sorted(baseline_names & current_names):
        baseline_entries = baseline_entries_by_name[subject].get("entries", {})
        current_entries = current_entries_by_name[subject].get("entries", {})
        for category in ENTRY_CATEGORIES:
            baseline_map = entries_by_key(
                baseline_entries.get(category, []),
                subject,
                category,
            )
            current_map = entries_by_key(
                current_entries.get(category, []),
                subject,
                category,
            )
            baseline_keys = set(baseline_map)
            current_keys = set(current_map)

            for key in sorted(baseline_keys - current_keys):
                incompatible.append(
                    abi_change(
                        change_type="removed_entry",
                        surface=surface,
                        subject=subject,
                        category=category,
                        key=key,
                        message=f"{subject} removed {category} entry {key}",
                    )
                )

            for key in sorted(current_keys - baseline_keys):
                additive.append(
                    abi_change(
                        change_type="added_entry",
                        surface=surface,
                        subject=subject,
                        category=category,
                        key=key,
                        message=f"{subject} added {category} entry {key}",
                    )
                )

            for key in sorted(baseline_keys & current_keys):
                if baseline_map[key] != current_map[key]:
                    incompatible.append(
                        abi_change(
                            change_type="changed_entry",
                            surface=surface,
                            subject=subject,
                            category=category,
                            key=key,
                            message=f"{subject} changed {category} entry {key}",
                            baseline=baseline_map[key],
                            current=current_map[key],
                        )
                    )


def compare_abi_surfaces(baseline: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
    incompatible: list[dict[str, Any]] = []
    additive: list[dict[str, Any]] = []

    compare_surface_entries(
        baseline_entries_by_name=baseline["contracts"],
        current_entries_by_name=current["contracts"],
        surface="contracts",
        subject_kind="production contract",
        removed_subject_type="removed_contract",
        added_subject_type="added_contract",
        incompatible=incompatible,
        additive=additive,
    )
    compare_surface_entries(
        baseline_entries_by_name=baseline["interfaces"],
        current_entries_by_name=current["interfaces"],
        surface="interfaces",
        subject_kind="published interface",
        removed_subject_type="removed_interface",
        added_subject_type="added_interface",
        incompatible=incompatible,
        additive=additive,
    )

    return {
        "compatible": len(incompatible) == 0,
        "incompatible_changes": incompatible,
        "additive_changes": additive,
    }


def print_report(report: dict[str, Any]) -> None:
    incompatible = report["incompatible_changes"]
    additive = report["additive_changes"]
    if incompatible:
        print("ABI compatibility check failed:", file=sys.stderr)
        for change in incompatible:
            print(f"  - {change['message']}", file=sys.stderr)
    if additive:
        print("ABI additive changes detected:")
        for change in additive:
            print(f"  - {change['message']}")
    if not incompatible and not additive:
        print("ABI compatibility baseline is current")
    elif not incompatible:
        print("ABI compatibility baseline is compatible; additive entries were reported")


def check_compatibility(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    baseline_path: Path,
    target_manifest: dict[str, Any] | None = None,
) -> int:
    baseline = load_baseline(baseline_path)
    current = build_abi_surface(repo_root, config_path, foundry_out)
    if target_manifest is not None:
        validate_target_required_absence(target_manifest, current)
        validate_target_retirement_baseline_closure(target_manifest, baseline)
    report = compare_abi_surfaces(baseline, current)
    print_report(report)
    return 0 if report["compatible"] else 1


def write_baseline(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    baseline_path: Path,
) -> Path:
    surface = build_abi_surface(repo_root, config_path, foundry_out)
    release_artifacts.write_json(baseline_path, surface)
    return baseline_path


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--target-manifest", type=Path, default=DEFAULT_TARGET_MANIFEST)
    parser.add_argument("--cast-bin", default="cast")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true")
    mode.add_argument("--target-only", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        target_manifest = validate_target_manifest(
            repo_root,
            args.target_manifest,
            args.cast_bin,
        )
        if args.target_only:
            print("StreamCore Permanent function/event interface target is valid")
            return 0
        if args.check:
            return check_compatibility(
                repo_root,
                args.config,
                args.foundry_out,
                args.baseline,
                target_manifest,
            )
        baseline_path = write_baseline(
            repo_root,
            args.config,
            args.foundry_out,
            args.baseline,
        )
    except (AbiCompatibilityError, release_artifacts.ArtifactError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(release_artifacts.normalize_artifact_path(baseline_path, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
