#!/usr/bin/env python3
"""Materialize deterministic initcode from the canonical isolated release build.

This is a reusable tooling foundation for issues #656 and #677.  Version 1
deliberately accepts only explicitly non-production candidates.  It does not
broadcast, derive deployment addresses, prove constructor semantics, or make
release-readiness claims.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Callable, Sequence

import build_release_artifacts as release_build

try:
    from eth_abi import encode as encode_abi
except ModuleNotFoundError:  # pragma: no cover - exercised only on broken toolchains.
    encode_abi = None


CANDIDATE_SCHEMA = "6529stream.canonical-deployment-candidate.v1"
PLAN_SCHEMA = "6529stream.canonical-deployment-plan.v1"
GENERATOR_VERSION = "1"
DEFAULT_CANDIDATE = Path(
    "deployments/config/canonical-deployment-candidate-non-production.json"
)
DEFAULT_OUTPUT = Path("tmp/canonical-deployment-plan.json")
CANONICAL_RECEIPT = Path("out-release/release-build-manifest.json")
CANONICAL_CONFIG = Path("release-artifacts/contracts.json")
CANONICAL_FOUNDRY_CONFIG = Path("foundry.toml")
NON_PRODUCTION_ENVIRONMENTS = frozenset({"anvil", "local", "fork", "testnet"})
EPHEMERAL_OUTPUT_ROOT = "tmp"
IJSON_SAFE_INTEGER_MAX = (1 << 53) - 1

SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
KECCAK_RE = re.compile(r"^0x[0-9a-f]{64}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
HEX_RE = re.compile(r"^0x(?:[0-9a-fA-F]{2})*$")
IDENTIFIER_RE = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SOLIDITY_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
ARRAY_SUFFIX_RE = re.compile(r"^(?P<inner>.+)\[(?P<size>[0-9]*)\]$")
UNSIGNED_DECIMAL_RE = re.compile(r"^(?:0|[1-9][0-9]*)$")
SIGNED_DECIMAL_RE = re.compile(r"^(?:0|-?[1-9][0-9]*)$")
AST_ID_RE = UNSIGNED_DECIMAL_RE


class DeploymentPlanError(RuntimeError):
    """Raised when a candidate cannot be materialized safely."""


ReceiptValidator = Callable[
    [Path, Path, Path, Path],
    dict[str, Any],
]


def reject_duplicate_json_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    """Reject duplicate JSON members instead of accepting last-key-wins input."""
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise DeploymentPlanError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def parse_ijson_integer(token: str) -> int:
    """Accept only integers interoperable across I-JSON consumers."""
    value = int(token)
    if abs(value) > IJSON_SAFE_INTEGER_MAX:
        raise DeploymentPlanError(
            f"JSON integer is outside the I-JSON interoperable range: {token}"
        )
    return value


def reject_json_float(token: str) -> float:
    """Deployment inputs do not permit floating-point JSON values."""
    raise DeploymentPlanError(
        f"floating-point JSON is forbidden in deployment-plan inputs: {token}"
    )


def reject_json_constant(token: str) -> None:
    """Reject NaN and infinities."""
    raise DeploymentPlanError(f"non-I-JSON token is forbidden: {token}")


def decode_json_bytes(raw: bytes, path: Path) -> Any:
    """Decode strict UTF-8, duplicate-free I-JSON bytes."""
    try:
        text = raw.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise DeploymentPlanError(f"{path} is not strict UTF-8 JSON: {exc}") from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=reject_duplicate_json_pairs,
            parse_int=parse_ijson_integer,
            parse_float=reject_json_float,
            parse_constant=reject_json_constant,
        )
    except json.JSONDecodeError as exc:
        raise DeploymentPlanError(f"invalid JSON in {path}: {exc}") from exc


def load_json_with_sha256(path: Path) -> tuple[Any, str]:
    """Load and hash one immutable in-memory snapshot of a JSON file."""
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise DeploymentPlanError(f"cannot read required file {path}: {exc}") from exc
    return decode_json_bytes(raw, path), sha256_bytes(raw)


def load_json(path: Path) -> Any:
    return load_json_with_sha256(path)[0]


def canonical_json_bytes(value: Any) -> bytes:
    """Return a deterministic canonical comparison encoding."""
    try:
        return json.dumps(
            value,
            ensure_ascii=True,
            allow_nan=False,
            separators=(",", ":"),
            sort_keys=True,
        ).encode("ascii")
    except (TypeError, ValueError) as exc:
        raise DeploymentPlanError(
            "value cannot be encoded as canonical I-JSON"
        ) from exc


def json_text(value: Any) -> str:
    """Return deterministic human-readable JSON."""
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        indent=2,
    ) + "\n"


def sha256_bytes(value: bytes) -> str:
    return release_build.sha256_bytes(value)


def file_sha256(path: Path) -> str:
    try:
        return sha256_bytes(path.read_bytes())
    except OSError as exc:
        raise DeploymentPlanError(f"cannot read required file {path}: {exc}") from exc


def keccak256_hex(value: bytes) -> str:
    try:
        return release_build.keccak256_hex(value)
    except release_build.ReleaseBuildError as exc:
        raise DeploymentPlanError(str(exc)) from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DeploymentPlanError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise DeploymentPlanError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise DeploymentPlanError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise DeploymentPlanError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise DeploymentPlanError(f"{path} must be an integer")
    return value


def require_exact_keys(
    value: dict[str, Any],
    required: set[str],
    path: str,
) -> None:
    missing = sorted(required - value.keys())
    extra = sorted(value.keys() - required)
    if missing:
        raise DeploymentPlanError(f"{path} is missing fields: {', '.join(missing)}")
    if extra:
        raise DeploymentPlanError(
            f"{path} has unsupported fields: {', '.join(extra)}"
        )


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise DeploymentPlanError(f"{path} must be a lowercase sha256: digest")
    return digest


def require_keccak(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not KECCAK_RE.fullmatch(digest):
        raise DeploymentPlanError(f"{path} must be a lowercase 0x Keccak-256 digest")
    return digest


def require_address(
    value: Any,
    path: str,
    *,
    allow_zero: bool = False,
) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise DeploymentPlanError(f"{path} must be a 20-byte 0x address")
    if not allow_zero and int(address[2:], 16) == 0:
        raise DeploymentPlanError(f"{path} must not be the zero address")
    return address.lower()


def require_hex(value: Any, path: str, *, allow_empty: bool = True) -> str:
    encoded = require_string(value, path)
    if not HEX_RE.fullmatch(encoded):
        raise DeploymentPlanError(f"{path} must be even-length 0x-prefixed hex")
    if not allow_empty and encoded == "0x":
        raise DeploymentPlanError(f"{path} must not be empty")
    return encoded.lower()


def require_identifier(value: Any, path: str) -> str:
    identifier = require_string(value, path)
    if not IDENTIFIER_RE.fullmatch(identifier):
        raise DeploymentPlanError(
            f"{path} must use lowercase letters, digits, '.', '_', or '-'"
        )
    return identifier


def require_solidity_name(value: Any, path: str) -> str:
    name = require_string(value, path)
    if not SOLIDITY_NAME_RE.fullmatch(name):
        raise DeploymentPlanError(f"{path} is not a Solidity identifier")
    return name


def require_safe_relative_path(value: Any, path: str) -> str:
    text = require_string(value, path)
    candidate = Path(text)
    if (
        candidate.is_absolute()
        or "\\" in text
        or ".." in candidate.parts
        or candidate.as_posix() != text
    ):
        raise DeploymentPlanError(
            f"{path} must be a normalized forward-slash repository-relative path"
        )
    return text


def normalize_repo_path(repo_root: Path, value: Path, label: str) -> Path:
    try:
        return release_build.resolve_repo_path(repo_root, value, label)
    except release_build.ReleaseBuildError as exc:
        raise DeploymentPlanError(str(exc)) from exc


def resolve_output_path(repo_root: Path, value: Path) -> Path:
    """Resolve a non-canonical output without permitting build-path contamination."""
    output = normalize_repo_path(repo_root, value, "deployment plan output")
    relative = output.relative_to(repo_root)
    if len(relative.parts) < 2 or relative.parts[0] != EPHEMERAL_OUTPUT_ROOT:
        raise DeploymentPlanError(
            "deployment plan output must be a file below the repository tmp directory"
        )
    if output.exists() and not output.is_file():
        raise DeploymentPlanError("deployment plan output must be a regular file")
    return output


def write_output(repo_root: Path, path: Path, value: Any) -> None:
    """Replace an output file atomically after validating its parent path."""
    path.parent.mkdir(parents=True, exist_ok=True)
    normalize_repo_path(repo_root, path.parent, "deployment plan output parent")
    handle, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.",
        suffix=".tmp",
        dir=path.parent,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(handle, "w", encoding="utf-8", newline="\n") as output:
            output.write(json_text(value))
        os.replace(temporary, path)
    finally:
        if temporary.exists():
            temporary.unlink()


def validate_release_build_binding(value: Any) -> dict[str, Any]:
    binding = require_dict(value, "candidate.release_build")
    require_exact_keys(
        binding,
        {
            "receipt_path",
            "receipt_sha256",
            "target_catalog_sha256",
            "config_path",
            "config_sha256",
            "foundry_config_path",
            "foundry_config_sha256",
        },
        "candidate.release_build",
    )
    receipt_path = require_safe_relative_path(
        binding.get("receipt_path"),
        "candidate.release_build.receipt_path",
    )
    if receipt_path != CANONICAL_RECEIPT.as_posix():
        raise DeploymentPlanError(
            "candidate.release_build.receipt_path must name the canonical "
            f"{CANONICAL_RECEIPT.as_posix()}"
        )
    config_path = require_safe_relative_path(
        binding.get("config_path"),
        "candidate.release_build.config_path",
    )
    if config_path != CANONICAL_CONFIG.as_posix():
        raise DeploymentPlanError(
            "candidate.release_build.config_path must name the canonical "
            f"{CANONICAL_CONFIG.as_posix()}"
        )
    foundry_config_path = require_safe_relative_path(
        binding.get("foundry_config_path"),
        "candidate.release_build.foundry_config_path",
    )
    if foundry_config_path != CANONICAL_FOUNDRY_CONFIG.as_posix():
        raise DeploymentPlanError(
            "candidate.release_build.foundry_config_path must name foundry.toml"
        )
    return {
        "receipt_path": receipt_path,
        "receipt_sha256": require_sha256(
            binding.get("receipt_sha256"),
            "candidate.release_build.receipt_sha256",
        ),
        "target_catalog_sha256": require_sha256(
            binding.get("target_catalog_sha256"),
            "candidate.release_build.target_catalog_sha256",
        ),
        "config_path": config_path,
        "config_sha256": require_sha256(
            binding.get("config_sha256"),
            "candidate.release_build.config_sha256",
        ),
        "foundry_config_path": foundry_config_path,
        "foundry_config_sha256": require_sha256(
            binding.get("foundry_config_sha256"),
            "candidate.release_build.foundry_config_sha256",
        ),
    }


def validate_target(value: Any, path: str) -> dict[str, str]:
    target = require_dict(value, path)
    require_exact_keys(
        target,
        {
            "kind",
            "name",
            "source",
            "artifact_relative_path",
            "artifact_sha256",
        },
        path,
    )
    kind = require_string(target.get("kind"), f"{path}.kind")
    if kind != "production_contract":
        raise DeploymentPlanError(f"{path}.kind must be production_contract")
    return {
        "kind": kind,
        "name": require_solidity_name(target.get("name"), f"{path}.name"),
        "source": require_safe_relative_path(target.get("source"), f"{path}.source"),
        "artifact_relative_path": require_safe_relative_path(
            target.get("artifact_relative_path"),
            f"{path}.artifact_relative_path",
        ),
        "artifact_sha256": require_sha256(
            target.get("artifact_sha256"),
            f"{path}.artifact_sha256",
        ),
    }


def validate_constructor(value: Any, path: str) -> dict[str, Any]:
    constructor = require_dict(value, path)
    require_exact_keys(
        constructor,
        {"types", "arguments", "encoded_args_keccak256"},
        path,
    )
    raw_types = require_list(constructor.get("types"), f"{path}.types")
    types = [
        require_string(item, f"{path}.types[{index}]")
        for index, item in enumerate(raw_types)
    ]
    arguments = require_list(constructor.get("arguments"), f"{path}.arguments")
    if len(types) != len(arguments):
        raise DeploymentPlanError(
            f"{path}.types and {path}.arguments must have the same length"
        )
    return {
        "types": types,
        "arguments": arguments,
        "encoded_args_keccak256": require_keccak(
            constructor.get("encoded_args_keccak256"),
            f"{path}.encoded_args_keccak256",
        ),
    }


def validate_libraries(value: Any, path: str) -> list[dict[str, str]]:
    libraries = require_list(value, path)
    result: list[dict[str, str]] = []
    seen: set[tuple[str, str]] = set()
    for index, item in enumerate(libraries):
        item_path = f"{path}[{index}]"
        library = require_dict(item, item_path)
        require_exact_keys(library, {"source", "name", "address"}, item_path)
        record = {
            "source": require_safe_relative_path(
                library.get("source"),
                f"{item_path}.source",
            ),
            "name": require_solidity_name(
                library.get("name"),
                f"{item_path}.name",
            ),
            "address": require_address(
                library.get("address"),
                f"{item_path}.address",
            ),
        }
        identity = (record["source"], record["name"])
        if identity in seen:
            raise DeploymentPlanError(
                f"{path} contains duplicate library binding {identity[0]}:{identity[1]}"
            )
        seen.add(identity)
        result.append(record)
    return result


def validate_runtime(value: Any, path: str) -> dict[str, Any]:
    runtime = require_dict(value, path)
    require_exact_keys(
        runtime,
        {"immutable_values", "expected_keccak256"},
        path,
    )
    immutable_values = require_dict(
        runtime.get("immutable_values"),
        f"{path}.immutable_values",
    )
    normalized_values: dict[str, str] = {}
    for immutable_id, encoded in sorted(immutable_values.items()):
        if not isinstance(immutable_id, str) or not AST_ID_RE.fullmatch(
            immutable_id
        ):
            raise DeploymentPlanError(
                f"{path}.immutable_values keys must be canonical decimal AST IDs"
            )
        normalized_values[immutable_id] = require_hex(
            encoded,
            f"{path}.immutable_values.{immutable_id}",
            allow_empty=False,
        )
    return {
        "immutable_values": normalized_values,
        "expected_keccak256": require_keccak(
            runtime.get("expected_keccak256"),
            f"{path}.expected_keccak256",
        ),
    }


def validate_instance(value: Any, index: int) -> dict[str, Any]:
    path = f"candidate.instances[{index}]"
    instance = require_dict(value, path)
    require_exact_keys(
        instance,
        {
            "order",
            "instance_id",
            "profile_entry_id",
            "target",
            "depends_on",
            "constructor",
            "libraries",
            "runtime",
            "expected_initcode_keccak256",
        },
        path,
    )
    order = require_int(instance.get("order"), f"{path}.order")
    if order != index + 1:
        raise DeploymentPlanError(
            f"{path}.order must be contiguous and equal {index + 1}"
        )
    profile_entry_id = instance.get("profile_entry_id")
    if profile_entry_id is not None:
        profile_entry_id = require_int(profile_entry_id, f"{path}.profile_entry_id")
        if profile_entry_id < 1:
            raise DeploymentPlanError(f"{path}.profile_entry_id must be positive")
    depends_on = [
        require_identifier(item, f"{path}.depends_on[{dependency_index}]")
        for dependency_index, item in enumerate(
            require_list(instance.get("depends_on"), f"{path}.depends_on")
        )
    ]
    if len(depends_on) != len(set(depends_on)):
        raise DeploymentPlanError(f"{path}.depends_on must not contain duplicates")
    return {
        "order": order,
        "instance_id": require_identifier(
            instance.get("instance_id"),
            f"{path}.instance_id",
        ),
        "profile_entry_id": profile_entry_id,
        "target": validate_target(instance.get("target"), f"{path}.target"),
        "depends_on": depends_on,
        "constructor": validate_constructor(
            instance.get("constructor"),
            f"{path}.constructor",
        ),
        "libraries": validate_libraries(
            instance.get("libraries"),
            f"{path}.libraries",
        ),
        "runtime": validate_runtime(instance.get("runtime"), f"{path}.runtime"),
        "expected_initcode_keccak256": require_keccak(
            instance.get("expected_initcode_keccak256"),
            f"{path}.expected_initcode_keccak256",
        ),
    }


def validate_candidate(value: Any) -> dict[str, Any]:
    """Validate the deliberately non-production v1 candidate shape."""
    candidate = require_dict(value, "candidate")
    require_exact_keys(
        candidate,
        {
            "schema_version",
            "candidate_id",
            "candidate_kind",
            "production_candidate",
            "readiness_evidence",
            "network",
            "release_build",
            "instances",
        },
        "candidate",
    )
    if candidate.get("schema_version") != CANDIDATE_SCHEMA:
        raise DeploymentPlanError(
            f"candidate.schema_version must be {CANDIDATE_SCHEMA}"
        )
    if candidate.get("candidate_kind") != "non_production_fixture":
        raise DeploymentPlanError(
            "candidate.candidate_kind must be non_production_fixture in v1"
        )
    if require_bool(
        candidate.get("production_candidate"),
        "candidate.production_candidate",
    ):
        raise DeploymentPlanError(
            "v1 materializer refuses production candidates until #656 supplies "
            "the strict instance-aware candidate model"
        )
    if require_bool(
        candidate.get("readiness_evidence"),
        "candidate.readiness_evidence",
    ):
        raise DeploymentPlanError(
            "v1 materializer output is not release-readiness evidence"
        )

    network = require_dict(candidate.get("network"), "candidate.network")
    require_exact_keys(network, {"environment", "chain_id"}, "candidate.network")
    environment = require_string(
        network.get("environment"),
        "candidate.network.environment",
    )
    if environment not in NON_PRODUCTION_ENVIRONMENTS:
        raise DeploymentPlanError(
            "candidate.network.environment must be explicitly non-production"
        )
    chain_id = require_int(network.get("chain_id"), "candidate.network.chain_id")
    if chain_id < 1:
        raise DeploymentPlanError("candidate.network.chain_id must be positive")

    raw_instances = require_list(candidate.get("instances"), "candidate.instances")
    if not raw_instances:
        raise DeploymentPlanError("candidate.instances must not be empty")
    instances = [
        validate_instance(instance, index)
        for index, instance in enumerate(raw_instances)
    ]
    ids = [instance["instance_id"] for instance in instances]
    if len(ids) != len(set(ids)):
        raise DeploymentPlanError("candidate instance IDs must be unique")
    profile_ids = [
        instance["profile_entry_id"]
        for instance in instances
        if instance["profile_entry_id"] is not None
    ]
    if len(profile_ids) != len(set(profile_ids)):
        raise DeploymentPlanError(
            "candidate non-null profile_entry_id values must be unique"
        )

    seen: set[str] = set()
    for instance in instances:
        for dependency in instance["depends_on"]:
            if dependency not in seen:
                raise DeploymentPlanError(
                    f"{instance['instance_id']} dependency {dependency} must name "
                    "an earlier candidate instance"
                )
        seen.add(instance["instance_id"])

    return {
        "schema_version": CANDIDATE_SCHEMA,
        "candidate_id": require_identifier(
            candidate.get("candidate_id"),
            "candidate.candidate_id",
        ),
        "candidate_kind": "non_production_fixture",
        "production_candidate": False,
        "readiness_evidence": False,
        "network": {
            "environment": environment,
            "chain_id": chain_id,
        },
        "release_build": validate_release_build_binding(
            candidate.get("release_build")
        ),
        "instances": instances,
    }


def target_catalog(receipt: dict[str, Any]) -> list[dict[str, str]]:
    """Return the receipt's deterministic target catalog binding."""
    records = require_list(receipt.get("targets"), "release receipt.targets")
    catalog = []
    identities: set[tuple[str, str, str]] = set()
    for index, item in enumerate(records):
        path = f"release receipt.targets[{index}]"
        target = require_dict(item, path)
        record = {
            "kind": require_string(target.get("kind"), f"{path}.kind"),
            "name": require_solidity_name(target.get("name"), f"{path}.name"),
            "source": require_safe_relative_path(
                target.get("source"),
                f"{path}.source",
            ),
            "artifact_relative_path": require_safe_relative_path(
                target.get("artifact_relative_path"),
                f"{path}.artifact_relative_path",
            ),
            "artifact_sha256": require_sha256(
                target.get("artifact_sha256"),
                f"{path}.artifact_sha256",
            ),
        }
        identity = (record["kind"], record["name"], record["source"])
        if identity in identities:
            raise DeploymentPlanError(
                "release receipt contains a duplicate target identity: "
                + ":".join(identity)
            )
        identities.add(identity)
        catalog.append(record)
    if not catalog:
        raise DeploymentPlanError("release receipt target catalog must not be empty")
    return catalog


def target_catalog_sha256(receipt: dict[str, Any]) -> str:
    return sha256_bytes(canonical_json_bytes(target_catalog(receipt)))


def default_receipt_validator(
    repo_root: Path,
    config_path: Path,
    foundry_config_path: Path,
    output_dir: Path,
) -> dict[str, Any]:
    """Validate the complete #674 receipt, compiler inputs, and artifact set."""
    try:
        return release_build.validate_release_output(
            repo_root,
            config_path,
            foundry_config_path,
            output_dir,
        )
    except release_build.ReleaseBuildError as exc:
        raise DeploymentPlanError(
            f"canonical release build validation failed: {exc}"
        ) from exc


def validate_receipt_binding(
    repo_root: Path,
    candidate: dict[str, Any],
    validator: ReceiptValidator,
) -> tuple[dict[str, Any], Path, str, list[dict[str, str]]]:
    """Validate the canonical receipt and the candidate's exact receipt binding."""
    binding = candidate["release_build"]
    config_path = normalize_repo_path(
        repo_root,
        Path(binding["config_path"]),
        "candidate release config",
    )
    foundry_config_path = normalize_repo_path(
        repo_root,
        Path(binding["foundry_config_path"]),
        "candidate Foundry config",
    )
    output_dir = normalize_repo_path(
        repo_root,
        Path("out-release"),
        "canonical release output",
    )
    receipt_path = normalize_repo_path(
        repo_root,
        Path(binding["receipt_path"]),
        "canonical release receipt",
    )
    validated_receipt = require_dict(
        validator(repo_root, config_path, foundry_config_path, output_dir),
        "validated release receipt",
    )

    receipt_value, actual_receipt_sha = load_json_with_sha256(receipt_path)
    receipt = require_dict(receipt_value, "canonical release receipt")
    if receipt != validated_receipt:
        raise DeploymentPlanError(
            "canonical release receipt changed during validation"
        )
    if actual_receipt_sha != binding["receipt_sha256"]:
        raise DeploymentPlanError(
            "candidate release receipt hash is stale: "
            f"expected {binding['receipt_sha256']}, got {actual_receipt_sha}"
        )
    actual_config_sha = file_sha256(config_path)
    if actual_config_sha != binding["config_sha256"]:
        raise DeploymentPlanError(
            "candidate release config hash is stale: "
            f"expected {binding['config_sha256']}, got {actual_config_sha}"
        )
    actual_foundry_config_sha = file_sha256(foundry_config_path)
    if actual_foundry_config_sha != binding["foundry_config_sha256"]:
        raise DeploymentPlanError(
            "candidate Foundry config hash is stale: "
            f"expected {binding['foundry_config_sha256']}, "
            f"got {actual_foundry_config_sha}"
        )
    source = require_dict(receipt.get("source"), "release receipt.source")
    if source.get("config") != binding["config_path"]:
        raise DeploymentPlanError("candidate release config path mismatches receipt")
    if source.get("config_sha256") != binding["config_sha256"]:
        raise DeploymentPlanError("candidate release config hash mismatches receipt")
    if source.get("foundry_config") != binding["foundry_config_path"]:
        raise DeploymentPlanError(
            "candidate Foundry config path mismatches receipt"
        )
    if source.get("foundry_config_sha256") != binding["foundry_config_sha256"]:
        raise DeploymentPlanError(
            "candidate Foundry config hash mismatches receipt"
        )
    catalog = target_catalog(receipt)
    actual_catalog_sha = sha256_bytes(canonical_json_bytes(catalog))
    if actual_catalog_sha != binding["target_catalog_sha256"]:
        raise DeploymentPlanError(
            "candidate target catalog hash is stale: "
            f"expected {binding['target_catalog_sha256']}, got {actual_catalog_sha}"
        )
    return receipt, receipt_path, actual_receipt_sha, catalog


def constructor_inputs(artifact: dict[str, Any], label: str) -> list[dict[str, Any]]:
    abi = require_list(artifact.get("abi"), f"{label}.abi")
    constructors = [
        require_dict(entry, f"{label}.abi[{index}]")
        for index, entry in enumerate(abi)
        if isinstance(entry, dict) and entry.get("type") == "constructor"
    ]
    if len(constructors) > 1:
        raise DeploymentPlanError(f"{label} ABI has more than one constructor")
    if not constructors:
        return []
    return [
        require_dict(value, f"{label}.constructor.inputs[{index}]")
        for index, value in enumerate(
            require_list(
                constructors[0].get("inputs"),
                f"{label}.constructor.inputs",
            )
        )
    ]


def canonical_abi_type(parameter: dict[str, Any], path: str) -> str:
    """Return the canonical eth-abi type for one Solidity ABI input."""
    abi_type = require_string(parameter.get("type"), f"{path}.type")
    if not abi_type.startswith("tuple"):
        return abi_type
    suffix = abi_type[len("tuple") :]
    components = [
        canonical_abi_type(
            require_dict(component, f"{path}.components[{index}]"),
            f"{path}.components[{index}]",
        )
        for index, component in enumerate(
            require_list(parameter.get("components"), f"{path}.components")
        )
    ]
    return "(" + ",".join(components) + ")" + suffix


def normalize_abi_integer(
    value: Any,
    path: str,
    *,
    signed: bool,
) -> int:
    """Accept safe JSON integers or canonical decimal strings."""
    if isinstance(value, bool):
        raise DeploymentPlanError(f"{path} must be an ABI integer")
    if isinstance(value, int):
        return value
    pattern = SIGNED_DECIMAL_RE if signed else UNSIGNED_DECIMAL_RE
    if isinstance(value, str) and pattern.fullmatch(value):
        return int(value)
    flavor = "signed" if signed else "unsigned"
    raise DeploymentPlanError(
        f"{path} must be a JSON integer or canonical {flavor} decimal string"
    )


def normalize_abi_value(parameter: dict[str, Any], value: Any, path: str) -> Any:
    """Convert JSON ABI values into the exact Python values expected by eth-abi."""
    abi_type = require_string(parameter.get("type"), f"{path}.type")
    array_match = ARRAY_SUFFIX_RE.fullmatch(abi_type)
    if array_match:
        values = require_list(value, path)
        declared_size = array_match.group("size")
        if declared_size and len(values) != int(declared_size):
            raise DeploymentPlanError(
                f"{path} must contain exactly {declared_size} array elements"
            )
        nested_parameter = dict(parameter)
        nested_parameter["type"] = array_match.group("inner")
        return [
            normalize_abi_value(
                nested_parameter,
                item,
                f"{path}[{index}]",
            )
            for index, item in enumerate(values)
        ]

    if abi_type == "tuple":
        values = require_list(value, path)
        components = [
            require_dict(component, f"{path}.components[{index}]")
            for index, component in enumerate(
                require_list(parameter.get("components"), f"{path}.components")
            )
        ]
        if len(values) != len(components):
            raise DeploymentPlanError(
                f"{path} tuple value must contain {len(components)} elements"
            )
        return tuple(
            normalize_abi_value(component, values[index], f"{path}[{index}]")
            for index, component in enumerate(components)
        )

    if abi_type == "address":
        return require_address(value, path, allow_zero=True)
    if abi_type == "bool":
        return require_bool(value, path)
    if abi_type == "string":
        if not isinstance(value, str):
            raise DeploymentPlanError(f"{path} must be a string")
        return value
    if abi_type == "bytes":
        return bytes.fromhex(require_hex(value, path)[2:])
    if abi_type.startswith("bytes") and abi_type[5:].isdigit():
        size = int(abi_type[5:])
        if size < 1 or size > 32:
            raise DeploymentPlanError(f"{path} uses invalid ABI type {abi_type}")
        encoded = bytes.fromhex(require_hex(value, path)[2:])
        if len(encoded) != size:
            raise DeploymentPlanError(f"{path} must contain exactly {size} bytes")
        return encoded
    if abi_type.startswith("uint"):
        width_text = abi_type[4:]
        width = int(width_text) if width_text else 256
        if width < 8 or width > 256 or width % 8:
            raise DeploymentPlanError(f"{path} uses invalid ABI type {abi_type}")
        integer = normalize_abi_integer(value, path, signed=False)
        if integer < 0 or integer >= 1 << width:
            raise DeploymentPlanError(f"{path} is outside the {abi_type} range")
        return integer
    if abi_type.startswith("int"):
        width_text = abi_type[3:]
        width = int(width_text) if width_text else 256
        if width < 8 or width > 256 or width % 8:
            raise DeploymentPlanError(f"{path} uses invalid ABI type {abi_type}")
        integer = normalize_abi_integer(value, path, signed=True)
        minimum = -(1 << (width - 1))
        maximum = (1 << (width - 1)) - 1
        if integer < minimum or integer > maximum:
            raise DeploymentPlanError(f"{path} is outside the {abi_type} range")
        return integer
    if abi_type == "function":
        encoded = bytes.fromhex(require_hex(value, path)[2:])
        if len(encoded) != 24:
            raise DeploymentPlanError(f"{path} must contain 24 bytes")
        return encoded
    return value


def encode_constructor(
    inputs: list[dict[str, Any]],
    candidate_constructor: dict[str, Any],
    label: str,
) -> tuple[list[str], bytes]:
    canonical_types = [
        canonical_abi_type(parameter, f"{label}.inputs[{index}]")
        for index, parameter in enumerate(inputs)
    ]
    if candidate_constructor["types"] != canonical_types:
        raise DeploymentPlanError(
            f"{label} candidate constructor types {candidate_constructor['types']!r} "
            f"do not match artifact ABI {canonical_types!r}"
        )
    arguments = candidate_constructor["arguments"]
    if len(arguments) != len(inputs):
        raise DeploymentPlanError(
            f"{label} has {len(arguments)} constructor arguments, "
            f"expected {len(inputs)}"
        )
    normalized = [
        normalize_abi_value(
            parameter,
            arguments[index],
            f"{label}.arguments[{index}]",
        )
        for index, parameter in enumerate(inputs)
    ]
    if encode_abi is None:
        raise DeploymentPlanError(
            "constructor encoding requires eth-abi from requirements-tools.lock"
        )
    try:
        encoded = encode_abi(canonical_types, normalized)
    except Exception as exc:  # eth-abi exposes multiple encoding exception types.
        raise DeploymentPlanError(
            f"{label} constructor arguments cannot be ABI encoded: {exc}"
        ) from exc
    actual_hash = keccak256_hex(encoded)
    expected_hash = candidate_constructor["encoded_args_keccak256"]
    if actual_hash != expected_hash:
        raise DeploymentPlanError(
            f"{label} constructor argument hash mismatch: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return canonical_types, encoded


def bytecode_object(value: Any, path: str) -> str:
    container = require_dict(value, path)
    encoded = require_string(container.get("object"), f"{path}.object")
    if encoded == "0x" or not encoded.startswith("0x") or len(encoded) % 2:
        raise DeploymentPlanError(
            f"{path}.object must be 0x-prefixed even-length artifact bytecode"
        )
    return encoded[2:]


def normalize_references(
    value: Any,
    byte_length: int,
    path: str,
) -> dict[tuple[str, str], list[dict[str, int]]]:
    if value is None:
        return {}
    references = require_dict(value, path)
    normalized: dict[tuple[str, str], list[dict[str, int]]] = {}
    occupied: list[tuple[int, int, str]] = []
    for source, libraries_value in sorted(references.items()):
        source_path = require_safe_relative_path(source, f"{path}.{source}")
        libraries = require_dict(libraries_value, f"{path}.{source}")
        for name, positions_value in sorted(libraries.items()):
            library_name = require_solidity_name(name, f"{path}.{source}.{name}")
            key = (source_path, library_name)
            positions = require_list(
                positions_value,
                f"{path}.{source}.{name}",
            )
            if not positions:
                raise DeploymentPlanError(
                    f"{path}.{source}.{name} must contain link positions"
                )
            normalized_positions = []
            for index, position_value in enumerate(positions):
                position_path = f"{path}.{source}.{name}[{index}]"
                position = require_dict(position_value, position_path)
                require_exact_keys(position, {"start", "length"}, position_path)
                start = require_int(position.get("start"), f"{position_path}.start")
                length = require_int(
                    position.get("length"),
                    f"{position_path}.length",
                )
                if start < 0 or length != 20 or start + length > byte_length:
                    raise DeploymentPlanError(
                        f"{position_path} must be a 20-byte in-bounds library link"
                    )
                normalized_positions.append({"start": start, "length": length})
                occupied.append(
                    (start, start + length, f"{source_path}:{library_name}")
                )
            normalized[key] = normalized_positions
    reject_overlaps(occupied, path)
    return normalized


def normalize_immutable_references(
    value: Any,
    byte_length: int,
    path: str,
) -> dict[str, list[dict[str, int]]]:
    if value is None:
        return {}
    references = require_dict(value, path)
    normalized: dict[str, list[dict[str, int]]] = {}
    occupied: list[tuple[int, int, str]] = []
    for immutable_id, positions_value in sorted(references.items()):
        if not isinstance(immutable_id, str) or not AST_ID_RE.fullmatch(
            immutable_id
        ):
            raise DeploymentPlanError(
                f"{path} keys must be canonical decimal AST IDs"
            )
        positions = require_list(positions_value, f"{path}.{immutable_id}")
        if not positions:
            raise DeploymentPlanError(
                f"{path}.{immutable_id} must contain immutable positions"
            )
        normalized_positions = []
        for index, position_value in enumerate(positions):
            position_path = f"{path}.{immutable_id}[{index}]"
            position = require_dict(position_value, position_path)
            require_exact_keys(position, {"start", "length"}, position_path)
            start = require_int(position.get("start"), f"{position_path}.start")
            length = require_int(position.get("length"), f"{position_path}.length")
            if start < 0 or length < 1 or start + length > byte_length:
                raise DeploymentPlanError(
                    f"{position_path} must be an in-bounds immutable reference"
                )
            normalized_positions.append({"start": start, "length": length})
            occupied.append((start, start + length, immutable_id))
        normalized[immutable_id] = normalized_positions
    reject_overlaps(occupied, path)
    return normalized


def reject_overlaps(
    ranges: list[tuple[int, int, str]],
    path: str,
) -> None:
    ordered = sorted(ranges)
    for previous, current in zip(ordered, ordered[1:]):
        if current[0] < previous[1]:
            raise DeploymentPlanError(
                f"{path} contains overlapping ranges for "
                f"{previous[2]} and {current[2]}"
            )


def flatten_reference_ranges(
    references: dict[Any, list[dict[str, int]]],
) -> list[tuple[int, int, str]]:
    ranges = []
    for identity, positions in references.items():
        label = (
            ":".join(identity)
            if isinstance(identity, tuple)
            else str(identity)
        )
        for position in positions:
            ranges.append(
                (
                    position["start"],
                    position["start"] + position["length"],
                    label,
                )
            )
    return ranges


def require_disjoint_reference_classes(
    links: dict[tuple[str, str], list[dict[str, int]]],
    immutables: dict[str, list[dict[str, int]]],
    path: str,
) -> None:
    reject_overlaps(
        flatten_reference_ranges(links)
        + flatten_reference_ranges(immutables),
        path,
    )


def materialize_bytecode(
    object_hex: str,
    link_references: dict[tuple[str, str], list[dict[str, int]]],
    library_addresses: dict[tuple[str, str], str],
    immutable_references: dict[str, list[dict[str, int]]] | None = None,
    immutable_values: dict[str, str] | None = None,
    *,
    path: str,
) -> bytes:
    """Patch exact link and immutable ranges, then require fully resolved hex."""
    expected_libraries = set(link_references)
    actual_libraries = set(library_addresses)
    if actual_libraries != expected_libraries:
        missing = sorted(expected_libraries - actual_libraries)
        extra = sorted(actual_libraries - expected_libraries)
        details = [f"missing {source}:{name}" for source, name in missing]
        details.extend(f"unexpected {source}:{name}" for source, name in extra)
        raise DeploymentPlanError(
            f"{path} library bindings do not match artifact references: "
            + ", ".join(details)
        )

    immutable_references = immutable_references or {}
    immutable_values = immutable_values or {}
    if set(immutable_references) != set(immutable_values):
        missing = sorted(set(immutable_references) - set(immutable_values))
        extra = sorted(set(immutable_values) - set(immutable_references))
        details = [f"missing immutable {item}" for item in missing]
        details.extend(f"unexpected immutable {item}" for item in extra)
        raise DeploymentPlanError(
            f"{path} immutable bindings do not match artifact references: "
            + ", ".join(details)
        )
    require_disjoint_reference_classes(
        link_references,
        immutable_references,
        path,
    )

    characters = list(object_hex)
    for identity in sorted(link_references):
        address = bytes.fromhex(library_addresses[identity][2:])
        for position in link_references[identity]:
            start = position["start"] * 2
            end = (position["start"] + position["length"]) * 2
            characters[start:end] = list(address.hex())
    for immutable_id in sorted(immutable_references):
        encoded = bytes.fromhex(immutable_values[immutable_id][2:])
        for position in immutable_references[immutable_id]:
            if len(encoded) != position["length"]:
                raise DeploymentPlanError(
                    f"{path} immutable {immutable_id} must contain exactly "
                    f"{position['length']} bytes"
                )
            start = position["start"] * 2
            end = (position["start"] + position["length"]) * 2
            characters[start:end] = list(encoded.hex())

    resolved = "".join(characters)
    if len(resolved) % 2 or not re.fullmatch(r"[0-9a-fA-F]*", resolved):
        raise DeploymentPlanError(
            f"{path} remains unresolved after applying declared links and immutables"
        )
    return bytes.fromhex(resolved)


def receipt_target_map(
    catalog: list[dict[str, str]],
) -> dict[tuple[str, str, str], dict[str, str]]:
    return {
        (item["kind"], item["name"], item["source"]): item
        for item in catalog
    }


def materialize_instance(
    repo_root: Path,
    instance: dict[str, Any],
    receipt_targets: dict[tuple[str, str, str], dict[str, str]],
) -> dict[str, Any]:
    target = instance["target"]
    identity = (target["kind"], target["name"], target["source"])
    receipt_target = receipt_targets.get(identity)
    label = f"candidate instance {instance['instance_id']}"
    if receipt_target is None:
        raise DeploymentPlanError(
            f"{label} target does not exist in the canonical release receipt"
        )
    if target != receipt_target:
        raise DeploymentPlanError(
            f"{label} target binding does not exactly match the release receipt"
        )

    artifact_path = normalize_repo_path(
        repo_root,
        Path("out-release") / target["artifact_relative_path"],
        f"{label} artifact",
    )
    expected_artifact_root = (repo_root / "out-release").resolve()
    try:
        artifact_path.relative_to(expected_artifact_root)
    except ValueError as exc:
        raise DeploymentPlanError(
            f"{label} artifact path contaminates a non-canonical output"
        ) from exc
    artifact_value, actual_artifact_sha = load_json_with_sha256(artifact_path)
    if actual_artifact_sha != target["artifact_sha256"]:
        raise DeploymentPlanError(
            f"{label} artifact hash is stale or mutated: "
            f"expected {target['artifact_sha256']}, got {actual_artifact_sha}"
        )
    artifact = require_dict(artifact_value, str(artifact_path))

    inputs = constructor_inputs(artifact, label)
    canonical_types, encoded_arguments = encode_constructor(
        inputs,
        instance["constructor"],
        f"{label}.constructor",
    )

    bytecode = require_dict(artifact.get("bytecode"), f"{label}.bytecode")
    deployed_bytecode = require_dict(
        artifact.get("deployedBytecode"),
        f"{label}.deployedBytecode",
    )
    creation_object = bytecode_object(bytecode, f"{label}.bytecode")
    runtime_object = bytecode_object(
        deployed_bytecode,
        f"{label}.deployedBytecode",
    )
    creation_length = len(creation_object) // 2
    runtime_length = len(runtime_object) // 2
    creation_links = normalize_references(
        bytecode.get("linkReferences"),
        creation_length,
        f"{label}.bytecode.linkReferences",
    )
    runtime_links = normalize_references(
        deployed_bytecode.get("linkReferences"),
        runtime_length,
        f"{label}.deployedBytecode.linkReferences",
    )
    immutable_references = normalize_immutable_references(
        deployed_bytecode.get("immutableReferences"),
        runtime_length,
        f"{label}.deployedBytecode.immutableReferences",
    )

    library_addresses = {
        (library["source"], library["name"]): library["address"]
        for library in instance["libraries"]
    }
    expected_library_set = set(creation_links) | set(runtime_links)
    if set(library_addresses) != expected_library_set:
        missing = sorted(expected_library_set - set(library_addresses))
        extra = sorted(set(library_addresses) - expected_library_set)
        details = [f"missing {source}:{name}" for source, name in missing]
        details.extend(f"unexpected {source}:{name}" for source, name in extra)
        raise DeploymentPlanError(
            f"{label} library bindings do not match creation/runtime references: "
            + ", ".join(details)
        )

    linked_creation = materialize_bytecode(
        creation_object,
        creation_links,
        {
            identity: library_addresses[identity]
            for identity in creation_links
        },
        path=f"{label}.creation",
    )
    expected_runtime = materialize_bytecode(
        runtime_object,
        runtime_links,
        {
            identity: library_addresses[identity]
            for identity in runtime_links
        },
        immutable_references,
        instance["runtime"]["immutable_values"],
        path=f"{label}.runtime",
    )
    initcode = linked_creation + encoded_arguments
    actual_initcode_hash = keccak256_hex(initcode)
    if actual_initcode_hash != instance["expected_initcode_keccak256"]:
        raise DeploymentPlanError(
            f"{label} full initcode hash mismatch: expected "
            f"{instance['expected_initcode_keccak256']}, got {actual_initcode_hash}"
        )
    actual_runtime_hash = keccak256_hex(expected_runtime)
    if actual_runtime_hash != instance["runtime"]["expected_keccak256"]:
        raise DeploymentPlanError(
            f"{label} expected runtime hash mismatch: expected "
            f"{instance['runtime']['expected_keccak256']}, got {actual_runtime_hash}"
        )

    link_records = []
    for identity in sorted(expected_library_set):
        source, name = identity
        link_records.append(
            {
                "source": source,
                "name": name,
                "address": library_addresses[identity],
                "creation_positions": creation_links.get(identity, []),
                "runtime_positions": runtime_links.get(identity, []),
            }
        )
    immutable_records = [
        {
            "ast_id": immutable_id,
            "value": instance["runtime"]["immutable_values"][immutable_id],
            "runtime_positions": immutable_references[immutable_id],
        }
        for immutable_id in sorted(immutable_references, key=int)
    ]
    return {
        "order": instance["order"],
        "instance_id": instance["instance_id"],
        "profile_entry_id": instance["profile_entry_id"],
        "target": target,
        "depends_on": instance["depends_on"],
        "artifact": {
            "path": f"out-release/{target['artifact_relative_path']}",
            "sha256": actual_artifact_sha,
        },
        "constructor": {
            "abi_inputs": inputs,
            "canonical_types": canonical_types,
            "arguments": instance["constructor"]["arguments"],
            "encoded_args": "0x" + encoded_arguments.hex(),
            "encoded_args_keccak256": keccak256_hex(encoded_arguments),
        },
        "libraries": link_records,
        "immutables": immutable_records,
        "linked_creation_bytecode": "0x" + linked_creation.hex(),
        "linked_creation_bytecode_keccak256": keccak256_hex(linked_creation),
        "initcode": "0x" + initcode.hex(),
        "initcode_length_bytes": len(initcode),
        "initcode_keccak256": actual_initcode_hash,
        "expected_runtime_bytecode": "0x" + expected_runtime.hex(),
        "expected_runtime_length_bytes": len(expected_runtime),
        "expected_runtime_keccak256": actual_runtime_hash,
    }


def materialize_deployment_plan(
    repo_root: Path,
    candidate_path: Path,
    *,
    receipt_validator: ReceiptValidator = default_receipt_validator,
) -> dict[str, Any]:
    """Validate all inputs and return one deterministic non-production plan."""
    repo_root = repo_root.resolve()
    candidate_path = normalize_repo_path(
        repo_root,
        candidate_path,
        "deployment candidate",
    )
    candidate_value, candidate_sha = load_json_with_sha256(candidate_path)
    candidate = validate_candidate(candidate_value)
    receipt, receipt_path, receipt_sha, catalog = validate_receipt_binding(
        repo_root,
        candidate,
        receipt_validator,
    )
    targets = receipt_target_map(catalog)
    deployments = [
        materialize_instance(repo_root, instance, targets)
        for instance in candidate["instances"]
    ]
    return {
        "schema_version": PLAN_SCHEMA,
        "generated_by": (
            f"scripts/materialize_canonical_deployment_plan.py:{GENERATOR_VERSION}"
        ),
        "release_posture": {
            "production_candidate": False,
            "readiness_evidence": False,
            "status": "non_production_tooling_only",
            "note": (
                "This plan does not close issues #656 or #677, authorize a "
                "broadcast, or establish public-beta or production readiness."
            ),
        },
        "candidate": {
            "path": candidate_path.relative_to(repo_root).as_posix(),
            "sha256": candidate_sha,
            "candidate_id": candidate["candidate_id"],
            "candidate_kind": candidate["candidate_kind"],
        },
        "network": candidate["network"],
        "release_build": {
            "receipt_path": receipt_path.relative_to(repo_root).as_posix(),
            "receipt_sha256": receipt_sha,
            "target_catalog_sha256": sha256_bytes(canonical_json_bytes(catalog)),
            "config_path": candidate["release_build"]["config_path"],
            "config_sha256": candidate["release_build"]["config_sha256"],
            "foundry_config_path": candidate["release_build"][
                "foundry_config_path"
            ],
            "foundry_config_sha256": candidate["release_build"][
                "foundry_config_sha256"
            ],
            "compiler_policy": require_dict(
                receipt.get("policy"),
                "release receipt.policy",
            ),
        },
        "deployments": deployments,
    }


def check_output(path: Path, plan: dict[str, Any]) -> None:
    if not path.is_file():
        raise DeploymentPlanError(
            f"{path} is missing; rerun without --check to materialize it"
        )
    try:
        raw = path.read_bytes()
    except OSError as exc:
        raise DeploymentPlanError(f"cannot read deployment plan {path}: {exc}") from exc
    expected = json_text(plan).encode("utf-8")
    if decode_json_bytes(raw, path) != plan or raw != expected:
        raise DeploymentPlanError(
            f"{path} is stale; rerun without --check to materialize it"
        )


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Materialize deterministic non-production initcode from the "
            "validated canonical isolated release build."
        )
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--candidate", type=Path, default=DEFAULT_CANDIDATE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        repo_root = args.repo_root.resolve()
        candidate_path = (
            args.candidate
            if args.candidate.is_absolute()
            else repo_root / args.candidate
        )
        output_path = (
            args.output if args.output.is_absolute() else repo_root / args.output
        )
        output_path = resolve_output_path(repo_root, output_path)
        plan = materialize_deployment_plan(repo_root, candidate_path)
        if args.check:
            check_output(output_path, plan)
            print(f"canonical deployment plan is current: {output_path}")
        else:
            write_output(repo_root, output_path, plan)
            print(
                "materialized non-production canonical deployment plan: "
                f"{output_path}"
            )
        return 0
    except DeploymentPlanError as exc:
        print(f"canonical deployment plan failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
