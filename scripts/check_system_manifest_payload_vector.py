#!/usr/bin/env python3
"""Fail-closed checker for the target-only system-manifest payload vector."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable, Sequence

import generate_system_manifest_payload_vector as generator


DECIMAL_RE = re.compile(r"^(0|[1-9][0-9]*)$")

VECTOR_KEYS = frozenset(
    {
        "schema_version",
        "evidence_class",
        "production_candidate",
        "readiness_evidence",
        "blocker",
        "source",
        "fixture_derivation",
        "constants",
        "payload",
        "canonical_payload",
        "chunks",
        "commitments",
        "root_descriptor",
        "semantic_round_trip",
    }
)
CONTRACT_KEYS = frozenset(
    {
        "inventoryId",
        "key",
        "address",
        "runtimeCodeHash",
        "create2Salt",
        "initCodeHash",
        "deploymentManifestHash",
    }
)
POINTER_KEYS = frozenset(
    {
        "pointerType",
        "target",
        "codeHash",
        "frozen",
        "moduleType",
        "interfaceId",
        "registry",
        "registryStatus",
        "moduleManifestHash",
        "deploymentManifestHash",
        "revision",
    }
)
REGISTRY_ENTRY_KEYS = frozenset(
    {
        "registry",
        "enumerationIndex",
        "module",
        "status",
        "moduleType",
        "moduleVersion",
        "interfaceId",
        "moduleGasLimit",
        "runtimeCodeHash",
        "deploymentManifestHash",
        "moduleManifestHash",
        "moduleManifestURI",
        "revision",
    }
)
PROBE_KEYS = frozenset(
    {
        "host",
        "parameterId",
        "probe",
        "probeRegistry",
        "probeModuleType",
        "probeInterfaceId",
        "probeModuleVersion",
        "probeRuntimeCodeHash",
        "probeModuleManifestHash",
        "probeDeploymentManifestHash",
        "probeBindingHash",
        "probeMaxAgeBlocks",
    }
)
FALLBACK_KEYS = frozenset(
    {
        "pointerType",
        "target",
        "runtimeCodeHash",
        "moduleType",
        "interfaceId",
        "registry",
        "moduleManifestHash",
        "deploymentManifestHash",
    }
)
CHUNK_KEYS = frozenset(
    {
        "index",
        "pointer",
        "payload_length",
        "segment_hex",
        "payload_hash",
        "leaf_hash",
        "runtime_code_hash",
    }
)
DESCRIPTOR_CHUNK_KEYS = frozenset({"pointer", "payload_length", "payload_hash"})


def _object(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise generator.ManifestVectorError(f"{path} must be an object")
    return value


def _array(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise generator.ManifestVectorError(f"{path} must be an array")
    return value


def _exact_keys(value: dict[str, Any], expected: Iterable[str], path: str) -> None:
    generator.require_exact_keys(value, expected, path)


def _safe_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise generator.ManifestVectorError(f"{path} must be an integer")
    if value < 0 or value > generator.UINT53_MAX:
        raise generator.ManifestVectorError(f"{path} is outside the I-JSON safe range")
    return value


def _decimal(value: Any, path: str) -> int:
    if not isinstance(value, str) or not DECIMAL_RE.fullmatch(value):
        raise generator.ManifestVectorError(
            f"{path} must be a minimal unsigned decimal string"
        )
    return int(value)


def _hex(value: Any, length: int, path: str) -> str:
    if not isinstance(value, str):
        raise generator.ManifestVectorError(f"{path} must be fixed-width hex")
    generator._hex_bytes(value, length, path)
    return value


def _address(value: Any, path: str) -> str:
    return _hex(value, 20, path)


def _bytes4(value: Any, path: str) -> str:
    return _hex(value, 4, path)


def _bytes32(value: Any, path: str) -> str:
    return _hex(value, 32, path)


def _string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        raise generator.ManifestVectorError(f"{path} must be a nonempty string")
    generator._validate_ijson_string(value, path)
    return value


def _strict_parse_canonical_json(value: bytes) -> Any:
    try:
        text = value.decode("utf-8", "strict")
    except UnicodeDecodeError as exc:
        raise generator.ManifestVectorError(
            f"canonical payload is malformed UTF-8: {exc}"
        ) from exc
    try:
        return json.loads(
            text,
            object_pairs_hook=generator.reject_duplicate_pairs,
            parse_float=lambda token: (_ for _ in ()).throw(
                generator.ManifestVectorError(
                    f"canonical payload contains forbidden floating number {token}"
                )
            ),
            parse_constant=lambda token: (_ for _ in ()).throw(
                generator.ManifestVectorError(
                    f"canonical payload contains non-I-JSON token {token}"
                )
            ),
        )
    except json.JSONDecodeError as exc:
        raise generator.ManifestVectorError(
            f"canonical payload is not valid JSON: {exc}"
        ) from exc


def _validate_global_deployment_identity(
    payload: dict[str, Any], expected_hash: str
) -> None:
    occurrences: list[tuple[str, str]] = []
    array_fields = (
        ("contracts", "deploymentManifestHash"),
        ("pointers", "deploymentManifestHash"),
        ("registryEntries", "deploymentManifestHash"),
        ("gasParameterProbes", "probeDeploymentManifestHash"),
        ("criticalFallbacks", "deploymentManifestHash"),
    )
    for array_name, field_name in array_fields:
        values = _array(payload[array_name], f"payload.{array_name}")
        for index, raw_value in enumerate(values):
            path = f"payload.{array_name}[{index}].{field_name}"
            value = _object(raw_value, f"payload.{array_name}[{index}]")
            if field_name not in value:
                raise generator.ManifestVectorError(f"{path} is missing")
            occurrences.append((path, _bytes32(value[field_name], path)))
    if not occurrences:
        raise generator.ManifestVectorError(
            "payload contains no deploymentManifestHash occurrence"
        )
    for path, value in occurrences:
        if value != expected_hash:
            raise generator.ManifestVectorError(
                f"{path} must equal the one release-wide deployment identity hash"
            )


def validate_payload_schema(
    payload_value: Any,
    profile: dict[str, Any],
    expected_deployment_identity_hash: str,
) -> dict[str, Any]:
    payload = _object(payload_value, "payload")
    _exact_keys(payload, generator.PAYLOAD_TOP_LEVEL_KEYS, "payload")
    if payload["schema"] != generator.PAYLOAD_SCHEMA_LITERAL:
        raise generator.ManifestVectorError("payload.schema literal drifted")
    if _safe_int(payload["schemaVersion"], "payload.schemaVersion") != 1:
        raise generator.ManifestVectorError("payload.schemaVersion must equal 1")
    if payload["chainId"] != "1":
        raise generator.ManifestVectorError("payload.chainId must equal the string '1'")
    _decimal(payload["publicationRevision"], "payload.publicationRevision")
    _address(payload["core"], "payload.core")
    _address(payload["systemManifest"], "payload.systemManifest")

    aggregate = _object(payload["aggregate"], "payload.aggregate")
    _exact_keys(aggregate, generator.AGGREGATE_KEYS, "payload.aggregate")
    for name in generator.AGGREGATE_KEYS:
        _address(aggregate[name], f"payload.aggregate.{name}")

    catalogs = _object(payload["catalogs"], "payload.catalogs")
    _exact_keys(catalogs, generator.CATALOG_KEYS, "payload.catalogs")
    for name in generator.CATALOG_KEYS:
        _bytes32(catalogs[name], f"payload.catalogs.{name}")

    registry_manifest = _object(
        payload["moduleRegistryManifest"], "payload.moduleRegistryManifest"
    )
    _exact_keys(
        registry_manifest,
        ("hash", "uri", "revision"),
        "payload.moduleRegistryManifest",
    )
    _bytes32(registry_manifest["hash"], "payload.moduleRegistryManifest.hash")
    _string(registry_manifest["uri"], "payload.moduleRegistryManifest.uri")
    _decimal(registry_manifest["revision"], "payload.moduleRegistryManifest.revision")

    _validate_global_deployment_identity(
        payload, expected_deployment_identity_hash
    )

    profile_entries = generator._require_profile(profile)
    contracts = _array(payload["contracts"], "payload.contracts")
    if len(contracts) != generator.EXPECTED_PROFILE_ENTRIES:
        raise generator.ManifestVectorError(
            "payload.contracts must consume all "
            f"{generator.EXPECTED_PROFILE_ENTRIES} entries"
        )
    contract_by_key: dict[str, dict[str, Any]] = {}
    contract_by_address: dict[str, dict[str, Any]] = {}
    for index, raw_contract in enumerate(contracts):
        contract = _object(raw_contract, f"payload.contracts[{index}]")
        _exact_keys(contract, CONTRACT_KEYS, f"payload.contracts[{index}]")
        inventory_id = _safe_int(
            contract["inventoryId"], f"payload.contracts[{index}].inventoryId"
        )
        if inventory_id != index + 1:
            raise generator.ManifestVectorError(
                "payload.contracts is not the ascending contiguous inventory walk"
            )
        key = contract["key"]
        if not isinstance(key, str) or not generator.KEY_RE.fullmatch(key):
            raise generator.ManifestVectorError(
                f"payload.contracts[{index}].key is not uppercase ASCII"
            )
        if key != profile_entries[index]["key"]:
            raise generator.ManifestVectorError(
                f"payload.contracts[{index}] does not match profile entry {index + 1}"
            )
        address = _address(contract["address"], f"payload.contracts[{index}].address")
        for field in (
            "runtimeCodeHash",
            "create2Salt",
            "initCodeHash",
            "deploymentManifestHash",
        ):
            _bytes32(contract[field], f"payload.contracts[{index}].{field}")
        if key in contract_by_key or address in contract_by_address:
            raise generator.ManifestVectorError(
                "payload.contracts keys and deployed addresses must be unique"
            )
        contract_by_key[key] = contract
        contract_by_address[address] = contract

    if payload["core"] != contract_by_key["STREAM_CORE"]["address"]:
        raise generator.ManifestVectorError("payload.core disagrees with STREAM_CORE")
    if (
        payload["systemManifest"]
        != contract_by_key["STREAM_SYSTEM_MANIFEST"]["address"]
    ):
        raise generator.ManifestVectorError(
            "payload.systemManifest disagrees with STREAM_SYSTEM_MANIFEST"
        )
    for aggregate_name, profile_key in generator.AGGREGATE_TARGETS.items():
        if aggregate[aggregate_name] != contract_by_key[profile_key]["address"]:
            raise generator.ManifestVectorError(
                f"payload.aggregate.{aggregate_name} disagrees with {profile_key}"
            )

    referenced_addresses: list[str] = [payload["core"], payload["systemManifest"]]
    referenced_addresses.extend(aggregate.values())

    pointers = _array(payload["pointers"], "payload.pointers")
    previous_pointer_type = ""
    seen_pointer_types: set[str] = set()
    for index, raw_pointer in enumerate(pointers):
        pointer = _object(raw_pointer, f"payload.pointers[{index}]")
        _exact_keys(pointer, POINTER_KEYS, f"payload.pointers[{index}]")
        pointer_type = _bytes32(
            pointer["pointerType"], f"payload.pointers[{index}].pointerType"
        )
        if pointer_type <= previous_pointer_type or pointer_type in seen_pointer_types:
            raise generator.ManifestVectorError(
                "payload.pointers must be strictly ordered by unique raw pointerType"
            )
        previous_pointer_type = pointer_type
        seen_pointer_types.add(pointer_type)
        target = _address(pointer["target"], f"payload.pointers[{index}].target")
        registry = _address(pointer["registry"], f"payload.pointers[{index}].registry")
        referenced_addresses.extend((target, registry))
        if target not in contract_by_address or registry not in contract_by_address:
            raise generator.ManifestVectorError("pointer references an unknown contract")
        if not isinstance(pointer["frozen"], bool):
            raise generator.ManifestVectorError(
                f"payload.pointers[{index}].frozen must be boolean"
            )
        _safe_int(pointer["registryStatus"], f"payload.pointers[{index}].registryStatus")
        _bytes4(pointer["interfaceId"], f"payload.pointers[{index}].interfaceId")
        for field in (
            "codeHash",
            "moduleType",
            "moduleManifestHash",
            "deploymentManifestHash",
        ):
            _bytes32(pointer[field], f"payload.pointers[{index}].{field}")
        _decimal(pointer["revision"], f"payload.pointers[{index}].revision")

    registry_entries = _array(payload["registryEntries"], "payload.registryEntries")
    registry_walks: dict[str, list[int]] = defaultdict(list)
    previous_registry_sort: tuple[str, int] | None = None
    seen_registry_modules: set[tuple[str, str]] = set()
    for index, raw_entry in enumerate(registry_entries):
        entry = _object(raw_entry, f"payload.registryEntries[{index}]")
        _exact_keys(entry, REGISTRY_ENTRY_KEYS, f"payload.registryEntries[{index}]")
        registry = _address(entry["registry"], f"payload.registryEntries[{index}].registry")
        module = _address(entry["module"], f"payload.registryEntries[{index}].module")
        referenced_addresses.extend((registry, module))
        if registry not in contract_by_address or module not in contract_by_address:
            raise generator.ManifestVectorError(
                "registry entry references an unknown contract"
            )
        enumeration_index = _safe_int(
            entry["enumerationIndex"],
            f"payload.registryEntries[{index}].enumerationIndex",
        )
        sort_key = (registry, enumeration_index)
        if previous_registry_sort is not None and sort_key <= previous_registry_sort:
            raise generator.ManifestVectorError(
                "payload.registryEntries is not strictly registry/index ordered"
            )
        previous_registry_sort = sort_key
        registry_walks[registry].append(enumeration_index)
        if (registry, module) in seen_registry_modules:
            raise generator.ManifestVectorError("duplicate module in a registry walk")
        seen_registry_modules.add((registry, module))
        _safe_int(entry["status"], f"payload.registryEntries[{index}].status")
        _bytes4(entry["interfaceId"], f"payload.registryEntries[{index}].interfaceId")
        for field in (
            "moduleType",
            "moduleVersion",
            "runtimeCodeHash",
            "deploymentManifestHash",
            "moduleManifestHash",
        ):
            _bytes32(entry[field], f"payload.registryEntries[{index}].{field}")
        _decimal(entry["moduleGasLimit"], f"payload.registryEntries[{index}].moduleGasLimit")
        _decimal(entry["revision"], f"payload.registryEntries[{index}].revision")
        _string(entry["moduleManifestURI"], f"payload.registryEntries[{index}].moduleManifestURI")
    for registry, indices in registry_walks.items():
        if indices != list(range(len(indices))):
            raise generator.ManifestVectorError(
                f"registry {registry} is not a complete 0..moduleCount-1 walk"
            )
    canonical_registry = contract_by_key["MODULE_REGISTRY"]["address"]
    if len(registry_entries) != len(contracts):
        raise generator.ManifestVectorError(
            "target fixture must enumerate one registry record per profile contract"
        )
    if set(registry_walks) != {canonical_registry}:
        raise generator.ManifestVectorError(
            "target fixture registry walk must use the canonical MODULE_REGISTRY"
        )
    registry_by_module = {entry["module"]: entry for entry in registry_entries}
    if set(registry_by_module) != set(contract_by_address):
        raise generator.ManifestVectorError(
            "target fixture registry walk must cover every contract exactly once"
        )
    for module, entry in registry_by_module.items():
        contract = contract_by_address[module]
        if (
            entry["runtimeCodeHash"] != contract["runtimeCodeHash"]
            or entry["deploymentManifestHash"]
            != contract["deploymentManifestHash"]
        ):
            raise generator.ManifestVectorError(
                "registry record runtime/deployment facts disagree with contracts"
            )

    expected_pointer_target = {
        generator.hex_keccak(name.encode("ascii")): contract_by_key[key]["address"]
        for name, key in generator.POINTER_TARGETS.items()
    }
    if len(pointers) != len(expected_pointer_target):
        raise generator.ManifestVectorError("target fixture pointer inventory is incomplete")
    for pointer in pointers:
        pointer_type = pointer["pointerType"]
        if pointer_type not in expected_pointer_target:
            raise generator.ManifestVectorError("target fixture has an unknown pointer type")
        if pointer["target"] != expected_pointer_target[pointer_type]:
            raise generator.ManifestVectorError(
                "target fixture pointer disagrees with its profile binding"
            )
        contract = contract_by_address[pointer["target"]]
        registry_record = registry_by_module[pointer["target"]]
        if (
            pointer["codeHash"] != contract["runtimeCodeHash"]
            or pointer["deploymentManifestHash"]
            != contract["deploymentManifestHash"]
            or pointer["registry"] != canonical_registry
            or pointer["moduleType"] != registry_record["moduleType"]
            or pointer["interfaceId"] != registry_record["interfaceId"]
            or pointer["moduleManifestHash"]
            != registry_record["moduleManifestHash"]
        ):
            raise generator.ManifestVectorError(
                "pointer cached facts disagree with contracts/registry state"
            )

    probes = _array(payload["gasParameterProbes"], "payload.gasParameterProbes")
    previous_probe_sort: tuple[str, str] | None = None
    seen_probe_pairs: set[tuple[str, str]] = set()
    for index, raw_probe in enumerate(probes):
        probe = _object(raw_probe, f"payload.gasParameterProbes[{index}]")
        _exact_keys(probe, PROBE_KEYS, f"payload.gasParameterProbes[{index}]")
        host = _address(probe["host"], f"payload.gasParameterProbes[{index}].host")
        parameter_id = _bytes32(
            probe["parameterId"], f"payload.gasParameterProbes[{index}].parameterId"
        )
        sort_key = (host, parameter_id)
        if previous_probe_sort is not None and sort_key <= previous_probe_sort:
            raise generator.ManifestVectorError(
                "payload.gasParameterProbes is not strictly host/parameterId ordered"
            )
        previous_probe_sort = sort_key
        if sort_key in seen_probe_pairs:
            raise generator.ManifestVectorError("duplicate host/parameter probe binding")
        seen_probe_pairs.add(sort_key)
        probe_address = _address(
            probe["probe"], f"payload.gasParameterProbes[{index}].probe"
        )
        registry = _address(
            probe["probeRegistry"],
            f"payload.gasParameterProbes[{index}].probeRegistry",
        )
        referenced_addresses.extend((host, probe_address, registry))
        if any(
            address not in contract_by_address
            for address in (host, probe_address, registry)
        ):
            raise generator.ManifestVectorError("probe binding references an unknown contract")
        _bytes4(
            probe["probeInterfaceId"],
            f"payload.gasParameterProbes[{index}].probeInterfaceId",
        )
        for field in (
            "probeModuleType",
            "probeModuleVersion",
            "probeRuntimeCodeHash",
            "probeModuleManifestHash",
            "probeDeploymentManifestHash",
            "probeBindingHash",
        ):
            _bytes32(probe[field], f"payload.gasParameterProbes[{index}].{field}")
        _decimal(
            probe["probeMaxAgeBlocks"],
            f"payload.gasParameterProbes[{index}].probeMaxAgeBlocks",
        )
        expected_binding = generator._probe_binding_hash(
            registry,
            probe_address,
            probe["probeModuleType"],
            probe["probeInterfaceId"],
            probe["probeModuleVersion"],
            probe["probeRuntimeCodeHash"],
            probe["probeModuleManifestHash"],
            probe["probeDeploymentManifestHash"],
        )
        if probe["probeBindingHash"] != expected_binding:
            raise generator.ManifestVectorError(
                f"payload.gasParameterProbes[{index}] binding hash does not recompute"
            )
        probe_record = registry_by_module[probe_address]
        if (
            probe["probeRegistry"] != canonical_registry
            or probe["probeModuleType"] != probe_record["moduleType"]
            or probe["probeInterfaceId"] != probe_record["interfaceId"]
            or probe["probeModuleVersion"] != probe_record["moduleVersion"]
            or probe["probeRuntimeCodeHash"] != probe_record["runtimeCodeHash"]
            or probe["probeModuleManifestHash"]
            != probe_record["moduleManifestHash"]
            or probe["probeDeploymentManifestHash"]
            != probe_record["deploymentManifestHash"]
        ):
            raise generator.ManifestVectorError(
                "probe binding facts disagree with the canonical registry record"
            )

    fallbacks = _array(payload["criticalFallbacks"], "payload.criticalFallbacks")
    previous_fallback_sort: tuple[str, str] | None = None
    for index, raw_fallback in enumerate(fallbacks):
        fallback = _object(raw_fallback, f"payload.criticalFallbacks[{index}]")
        _exact_keys(fallback, FALLBACK_KEYS, f"payload.criticalFallbacks[{index}]")
        pointer_type = _bytes32(
            fallback["pointerType"], f"payload.criticalFallbacks[{index}].pointerType"
        )
        target = _address(
            fallback["target"], f"payload.criticalFallbacks[{index}].target"
        )
        registry = _address(
            fallback["registry"], f"payload.criticalFallbacks[{index}].registry"
        )
        referenced_addresses.extend((target, registry))
        sort_key = (pointer_type, target)
        if previous_fallback_sort is not None and sort_key <= previous_fallback_sort:
            raise generator.ManifestVectorError(
                "payload.criticalFallbacks is not strictly pointerType/target ordered"
            )
        previous_fallback_sort = sort_key
        _bytes4(fallback["interfaceId"], f"payload.criticalFallbacks[{index}].interfaceId")
        for field in (
            "runtimeCodeHash",
            "moduleType",
            "moduleManifestHash",
            "deploymentManifestHash",
        ):
            _bytes32(fallback[field], f"payload.criticalFallbacks[{index}].{field}")
        fallback_record = registry_by_module[target]
        fallback_contract = contract_by_address[target]
        if (
            fallback["registry"] != canonical_registry
            or fallback["runtimeCodeHash"] != fallback_contract["runtimeCodeHash"]
            or fallback["deploymentManifestHash"]
            != fallback_contract["deploymentManifestHash"]
            or fallback["moduleType"] != fallback_record["moduleType"]
            or fallback["interfaceId"] != fallback_record["interfaceId"]
            or fallback["moduleManifestHash"]
            != fallback_record["moduleManifestHash"]
        ):
            raise generator.ManifestVectorError(
                "critical fallback facts disagree with contracts/registry state"
            )

    security = _object(payload["securityContact"], "payload.securityContact")
    _exact_keys(security, ("policyHash", "uri"), "payload.securityContact")
    _bytes32(security["policyHash"], "payload.securityContact.policyHash")
    _string(security["uri"], "payload.securityContact.uri")

    missing_references = sorted(set(referenced_addresses) - set(contract_by_address))
    if missing_references:
        raise generator.ManifestVectorError(
            f"payload references addresses absent from contracts: {missing_references}"
        )
    contract_counts = Counter(contract["address"] for contract in contracts)
    if any(contract_counts[address] != 1 for address in set(referenced_addresses)):
        raise generator.ManifestVectorError(
            "every referenced address must appear exactly once in contracts"
        )
    return payload


def _decode_hex_blob(value: Any, path: str) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x"):
        raise generator.ManifestVectorError(f"{path} must be 0x-prefixed hex")
    try:
        decoded = bytes.fromhex(value[2:])
    except ValueError as exc:
        raise generator.ManifestVectorError(f"{path} contains malformed hex") from exc
    if value != "0x" + decoded.hex():
        raise generator.ManifestVectorError(f"{path} must use canonical lowercase hex")
    return decoded


def _first_difference(expected: Any, actual: Any, path: str = "$") -> str | None:
    if type(expected) is not type(actual):
        return f"{path}: expected {type(expected).__name__}, got {type(actual).__name__}"
    if isinstance(expected, dict):
        if list(expected) != list(actual):
            return f"{path}: object member order/set drifted"
        for key in expected:
            difference = _first_difference(expected[key], actual[key], f"{path}.{key}")
            if difference:
                return difference
        return None
    if isinstance(expected, list):
        if len(expected) != len(actual):
            return f"{path}: expected {len(expected)} elements, got {len(actual)}"
        for index, (expected_item, actual_item) in enumerate(zip(expected, actual)):
            difference = _first_difference(
                expected_item, actual_item, f"{path}[{index}]"
            )
            if difference:
                return difference
        return None
    if expected != actual:
        expected_repr = repr(expected)
        actual_repr = repr(actual)
        if len(expected_repr) > 160:
            expected_repr = expected_repr[:157] + "..."
        if len(actual_repr) > 160:
            actual_repr = actual_repr[:157] + "..."
        return f"{path}: expected {expected_repr}, got {actual_repr}"
    return None


def validate_vector_mechanics(
    vector_value: Any, profile: dict[str, Any]
) -> dict[str, Any]:
    vector = _object(vector_value, "vector")
    _exact_keys(vector, VECTOR_KEYS, "vector")
    if vector["schema_version"] != generator.VECTOR_SCHEMA:
        raise generator.ManifestVectorError("vector schema version drifted")
    if vector["evidence_class"] != generator.EVIDENCE_CLASS:
        raise generator.ManifestVectorError(
            "vector must remain unmistakably target_abi_lock_fixture"
        )
    if vector["production_candidate"] is not False:
        raise generator.ManifestVectorError(
            "target ABI-lock fixture cannot be used as a production candidate"
        )
    if vector["readiness_evidence"] is not False:
        raise generator.ManifestVectorError(
            "target ABI-lock fixture cannot be marked as readiness evidence"
        )
    blocker = _object(vector["blocker"], "vector.blocker")
    _exact_keys(blocker, ("issue", "reason"), "vector.blocker")
    if blocker["issue"] != generator.BLOCKER_ISSUE:
        raise generator.ManifestVectorError("vector must retain the #656 blocker")
    _string(blocker["reason"], "vector.blocker.reason")

    source = _object(vector["source"], "vector.source")
    _exact_keys(
        source,
        (
            "genesis_deployment_profile",
            "genesis_deployment_profile_sha256",
            "profile_schema_version",
            "profile_entry_count",
            "normative_anchor",
        ),
        "vector.source",
    )
    if source["genesis_deployment_profile"] != generator.DEFAULT_PROFILE.as_posix():
        raise generator.ManifestVectorError("vector source must name the canonical profile")
    if source["profile_schema_version"] != generator.PROFILE_SCHEMA:
        raise generator.ManifestVectorError("vector source profile schema drifted")
    if source["profile_entry_count"] != generator.EXPECTED_PROFILE_ENTRIES:
        raise generator.ManifestVectorError(
            "vector source must consume all "
            f"{generator.EXPECTED_PROFILE_ENTRIES} entries"
        )
    if (
        source["normative_anchor"]
        != "docs/stream-long-term-architecture.md#LTA-MANIFEST"
    ):
        raise generator.ManifestVectorError("vector normative anchor drifted")
    if not isinstance(
        source["genesis_deployment_profile_sha256"], str
    ) or not re.fullmatch(
        r"sha256:[0-9a-f]{64}", source["genesis_deployment_profile_sha256"]
    ):
        raise generator.ManifestVectorError("vector source profile SHA-256 is malformed")
    expected_identity_view_hash = generator.derive_target_identity_view_hash(
        source["genesis_deployment_profile_sha256"]
    )
    expected_deployment_identity_hash = (
        generator.derive_target_deployment_identity_hash(
            source["genesis_deployment_profile_sha256"]
        )
    )

    derivation = _object(vector["fixture_derivation"], "vector.fixture_derivation")
    if derivation.get("domain") != generator.VECTOR_DERIVATION_DOMAIN:
        raise generator.ManifestVectorError("fixture derivation domain drifted")
    if derivation.get("state_export_publisher_binding") != "GOVERNANCE_LAYER":
        raise generator.ManifestVectorError(
            "fixture state-export publisher binding must remain explicit"
        )
    if derivation.get("sstore2_carrier_policy") != (
        "root and chunk carriers are excluded from payload.contracts "
        "to avoid a self-address fixed point"
    ):
        raise generator.ManifestVectorError("fixture SSTORE2 carrier policy drifted")
    deployment_identity = _object(
        derivation.get("deployment_identity"),
        "vector.fixture_derivation.deployment_identity",
    )
    _exact_keys(
        deployment_identity,
        ("scope", "identity_view_rule", "outer_rule", "domain", "identity_view_hash", "hash"),
        "vector.fixture_derivation.deployment_identity",
    )
    if deployment_identity != {
        "scope": generator.TARGET_DEPLOYMENT_IDENTITY_SCOPE,
        "identity_view_rule": generator.TARGET_IDENTITY_VIEW_RULE,
        "outer_rule": generator.TARGET_IDENTITY_OUTER_RULE,
        "domain": generator.DEPLOYMENT_IDENTITY_DOMAIN,
        "identity_view_hash": expected_identity_view_hash,
        "hash": expected_deployment_identity_hash,
    }:
        raise generator.ManifestVectorError(
            "fixture deployment identity derivation drifted"
        )

    constants = _object(vector["constants"], "vector.constants")
    expected_constants = {
        "schema_version": generator.SCHEMA_VERSION,
        "payload_schema_literal": generator.PAYLOAD_SCHEMA_LITERAL,
        "payload_schema_id": generator.PAYLOAD_SCHEMA_ID,
        "canonicalization_literal": generator.CANONICALIZATION_LITERAL,
        "canonicalization_id": generator.CANONICALIZATION_ID,
        "chunk_payload_bytes": generator.CHUNK_PAYLOAD_BYTES,
        "max_manifest_chunks": generator.MAX_MANIFEST_CHUNKS,
        "max_manifest_payload_bytes": generator.MAX_MANIFEST_PAYLOAD_BYTES,
        "max_root_descriptor_bytes": generator.MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES,
        "root_descriptor_magic": generator.ROOT_DESCRIPTOR_MAGIC,
        "root_descriptor_dynamic_offset": generator.ROOT_DESCRIPTOR_DYNAMIC_OFFSET,
        "payload_leaf_domain": generator.PAYLOAD_LEAF_DOMAIN,
        "payload_list_domain": generator.PAYLOAD_LIST_DOMAIN,
        "payload_root_domain": generator.PAYLOAD_ROOT_DOMAIN,
        "deployment_identity_domain": generator.DEPLOYMENT_IDENTITY_DOMAIN,
    }
    if constants != expected_constants:
        raise generator.ManifestVectorError("vector constants drifted from LTA-MANIFEST")

    payload = validate_payload_schema(
        vector["payload"], profile, expected_deployment_identity_hash
    )
    canonical_metadata = _object(
        vector["canonical_payload"], "vector.canonical_payload"
    )
    _exact_keys(
        canonical_metadata,
        ("canonicalization", "utf8_hex", "byte_length", "keccak256", "sha256"),
        "vector.canonical_payload",
    )
    if canonical_metadata["canonicalization"] != generator.CANONICALIZATION_LITERAL:
        raise generator.ManifestVectorError("canonicalization literal drifted")
    canonical = _decode_hex_blob(
        canonical_metadata["utf8_hex"], "vector.canonical_payload.utf8_hex"
    )
    length = _safe_int(
        canonical_metadata["byte_length"], "vector.canonical_payload.byte_length"
    )
    if length != len(canonical) or not 1 <= length <= generator.MAX_MANIFEST_PAYLOAD_BYTES:
        raise generator.ManifestVectorError("canonical payload byte length is invalid")
    if canonical_metadata["keccak256"] != generator.hex_keccak(canonical):
        raise generator.ManifestVectorError("canonical payload Keccak hash drifted")
    if canonical_metadata["sha256"] != generator.sha256_prefixed(canonical):
        raise generator.ManifestVectorError("canonical payload SHA-256 drifted")
    decoded_payload = _strict_parse_canonical_json(canonical)
    if decoded_payload != payload:
        raise generator.ManifestVectorError(
            "canonical payload bytes do not semantically round-trip to payload"
        )
    recanonicalized = generator.jcs_bytes(decoded_payload)
    if recanonicalized != canonical or canonical != generator.jcs_bytes(payload):
        raise generator.ManifestVectorError(
            "canonical payload bytes are not the unique RFC8785/I-JSON encoding"
        )

    chunks = _array(vector["chunks"], "vector.chunks")
    expected_count = (length + generator.CHUNK_PAYLOAD_BYTES - 1) // generator.CHUNK_PAYLOAD_BYTES
    if len(chunks) != expected_count or not 1 <= len(chunks) <= generator.MAX_MANIFEST_CHUNKS:
        raise generator.ManifestVectorError("chunk count does not match canonical split")
    reconstructed = bytearray()
    leaf_hashes: list[str] = []
    descriptor_chunks: list[dict[str, Any]] = []
    for index, raw_chunk in enumerate(chunks):
        chunk = _object(raw_chunk, f"vector.chunks[{index}]")
        _exact_keys(chunk, CHUNK_KEYS, f"vector.chunks[{index}]")
        if _safe_int(chunk["index"], f"vector.chunks[{index}].index") != index:
            raise generator.ManifestVectorError("chunk indices are not contiguous")
        segment = _decode_hex_blob(
            chunk["segment_hex"], f"vector.chunks[{index}].segment_hex"
        )
        declared_length = _safe_int(
            chunk["payload_length"], f"vector.chunks[{index}].payload_length"
        )
        if declared_length != len(segment):
            raise generator.ManifestVectorError("chunk declared/live lengths disagree")
        if index < len(chunks) - 1 and len(segment) != generator.CHUNK_PAYLOAD_BYTES:
            raise generator.ManifestVectorError(
                "every non-final chunk must be exactly 24575 bytes"
            )
        if index == len(chunks) - 1 and not 1 <= len(segment) <= generator.CHUNK_PAYLOAD_BYTES:
            raise generator.ManifestVectorError("final chunk length is outside bounds")
        pointer = _address(chunk["pointer"], f"vector.chunks[{index}].pointer")
        payload_hash = _bytes32(
            chunk["payload_hash"], f"vector.chunks[{index}].payload_hash"
        )
        if payload_hash != generator.hex_keccak(segment):
            raise generator.ManifestVectorError("chunk payload hash does not recompute")
        leaf_hash = generator.hex_keccak(
            generator.abi_encode_static(
                (
                    ("bytes32", generator.PAYLOAD_LEAF_DOMAIN),
                    ("uint256", index),
                    ("uint32", len(segment)),
                    ("bytes32", payload_hash),
                )
            )
        )
        if chunk["leaf_hash"] != leaf_hash:
            raise generator.ManifestVectorError("chunk leaf hash does not recompute")
        expected_runtime_hash = generator.hex_keccak(b"\x00" + segment)
        if chunk["runtime_code_hash"] != expected_runtime_hash:
            raise generator.ManifestVectorError(
                "chunk SSTORE2 runtime code hash does not recompute"
            )
        reconstructed.extend(segment)
        leaf_hashes.append(leaf_hash)
        descriptor_chunks.append(
            {
                "pointer": pointer,
                "payload_length": len(segment),
                "payload_hash": payload_hash,
            }
        )
    if bytes(reconstructed) != canonical:
        raise generator.ManifestVectorError(
            "ordered chunks do not reconstruct the canonical payload"
        )
    contract_addresses = {
        contract["address"] for contract in payload["contracts"]
    }
    if any(chunk["pointer"] in contract_addresses for chunk in chunks):
        raise generator.ManifestVectorError(
            "SSTORE2 chunk carriers must stay outside payload.contracts"
        )

    commitments = _object(vector["commitments"], "vector.commitments")
    _exact_keys(
        commitments,
        ("ordered_leaf_hashes", "chunk_list_hash", "payload_root_hash", "manifest_hash"),
        "vector.commitments",
    )
    if commitments["ordered_leaf_hashes"] != leaf_hashes:
        raise generator.ManifestVectorError("ordered leaf hash list drifted")
    list_hash = generator._chunk_list_hash(length, leaf_hashes)
    if commitments["chunk_list_hash"] != list_hash:
        raise generator.ManifestVectorError("chunk list hash does not recompute")
    root_hash = generator._payload_root_hash(length, len(chunks), list_hash)
    if commitments["payload_root_hash"] != root_hash:
        raise generator.ManifestVectorError("payload root hash does not recompute")
    if commitments["manifest_hash"] != root_hash:
        raise generator.ManifestVectorError(
            "manifestHash must equal the exact payload root commitment"
        )

    root = _object(vector["root_descriptor"], "vector.root_descriptor")
    _exact_keys(
        root,
        (
            "magic",
            "schema_version",
            "schema_id",
            "canonicalization_id",
            "total_bytes",
            "chunk_count",
            "dynamic_offset",
            "chunks",
            "encoded_length",
            "encoded_hex",
            "keccak256",
            "runtime_code_hash",
        ),
        "vector.root_descriptor",
    )
    root_chunks = _array(root["chunks"], "vector.root_descriptor.chunks")
    for index, item in enumerate(root_chunks):
        _exact_keys(
            _object(item, f"vector.root_descriptor.chunks[{index}]"),
            DESCRIPTOR_CHUNK_KEYS,
            f"vector.root_descriptor.chunks[{index}]",
        )
    if root_chunks != descriptor_chunks:
        raise generator.ManifestVectorError(
            "root descriptor chunk metadata disagrees with canonical chunks"
        )
    if (
        root["magic"] != generator.ROOT_DESCRIPTOR_MAGIC
        or root["schema_version"] != generator.SCHEMA_VERSION
        or root["schema_id"] != generator.PAYLOAD_SCHEMA_ID
        or root["canonicalization_id"] != generator.CANONICALIZATION_ID
        or root["total_bytes"] != length
        or root["chunk_count"] != len(chunks)
        or root["dynamic_offset"] != generator.ROOT_DESCRIPTOR_DYNAMIC_OFFSET
    ):
        raise generator.ManifestVectorError("root descriptor semantic fields drifted")
    encoded = _decode_hex_blob(root["encoded_hex"], "vector.root_descriptor.encoded_hex")
    expected_descriptor_length = 256 + 96 * len(chunks)
    if (
        root["encoded_length"] != len(encoded)
        or len(encoded) != expected_descriptor_length
        or len(encoded) > generator.MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES
    ):
        raise generator.ManifestVectorError("root descriptor exact length is invalid")
    decoded_descriptor = generator.decode_root_descriptor(encoded)
    if decoded_descriptor["chunks"] != descriptor_chunks:
        raise generator.ManifestVectorError("root descriptor ABI round trip drifted")
    if generator.encode_root_descriptor(descriptor_chunks, length) != encoded:
        raise generator.ManifestVectorError(
            "root descriptor is noncanonical or contains trailing bytes"
        )
    if root["keccak256"] != generator.hex_keccak(encoded):
        raise generator.ManifestVectorError("root descriptor hash does not recompute")
    if root["runtime_code_hash"] != generator.hex_keccak(b"\x00" + encoded):
        raise generator.ManifestVectorError(
            "root descriptor SSTORE2 runtime hash does not recompute"
        )

    semantic = _object(vector["semantic_round_trip"], "vector.semantic_round_trip")
    _exact_keys(
        semantic,
        (
            "profile_entry_ids",
            "profile_keys",
            "contract_address_by_key",
            "aggregate",
            "catalogs",
            "deployment_manifest_hash",
            "contract_count",
            "pointer_count",
            "registry_entry_count",
            "gas_parameter_probe_binding_count",
            "critical_fallback_count",
            "all_profile_entry_addresses",
        ),
        "vector.semantic_round_trip",
    )
    expected_ids = [contract["inventoryId"] for contract in payload["contracts"]]
    expected_keys = [contract["key"] for contract in payload["contracts"]]
    expected_addresses = [contract["address"] for contract in payload["contracts"]]
    expected_address_map = {
        contract["key"]: contract["address"] for contract in payload["contracts"]
    }
    if (
        semantic["profile_entry_ids"] != expected_ids
        or semantic["profile_keys"] != expected_keys
        or semantic["contract_address_by_key"] != expected_address_map
        or semantic["all_profile_entry_addresses"] != expected_addresses
        or semantic["aggregate"] != payload["aggregate"]
        or semantic["catalogs"] != payload["catalogs"]
        or semantic["deployment_manifest_hash"]
        != expected_deployment_identity_hash
        or semantic["contract_count"] != len(payload["contracts"])
        or semantic["pointer_count"] != len(payload["pointers"])
        or semantic["registry_entry_count"] != len(payload["registryEntries"])
        or semantic["gas_parameter_probe_binding_count"]
        != len(payload["gasParameterProbes"])
        or semantic["critical_fallback_count"] != len(payload["criticalFallbacks"])
    ):
        raise generator.ManifestVectorError(
            "semantic_round_trip fields disagree with the canonical payload"
        )
    return vector


def validate_committed_vector(
    vector: Any,
    vector_raw: bytes | None,
    profile: dict[str, Any],
    profile_raw: bytes,
) -> dict[str, Any]:
    validated = validate_vector_mechanics(vector, profile)
    if validated["source"][
        "genesis_deployment_profile_sha256"
    ] != generator.sha256_prefixed(profile_raw):
        raise generator.ManifestVectorError(
            "vector source hash does not match the raw canonical genesis profile"
        )
    expected = generator.build_vector(profile, profile_raw)
    difference = _first_difference(expected, validated)
    if difference:
        raise generator.ManifestVectorError(
            "committed vector drifted from deterministic generation: " + difference
        )
    if vector_raw is not None:
        expected_raw = generator.render_vector(validated).encode("utf-8")
        if vector_raw != expected_raw:
            raise generator.ManifestVectorError(
                "vector file formatting is noncanonical; regenerate it instead of hand editing"
            )
    return validated


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, default=generator.DEFAULT_PROFILE)
    parser.add_argument("--vector", type=Path, default=generator.DEFAULT_OUTPUT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        profile, profile_raw = generator.load_json_strict(args.profile)
        vector, vector_raw = generator.load_json_strict(args.vector)
        validated = validate_committed_vector(
            vector, vector_raw, profile, profile_raw
        )
    except (generator.ManifestVectorError, OSError) as exc:
        print(f"system manifest payload vector check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "system manifest target ABI-lock vector verified: "
        f"{validated['source']['profile_entry_count']} profile entries, "
        f"{validated['canonical_payload']['byte_length']} canonical bytes, "
        f"{len(validated['chunks'])} chunks; production use remains blocked by #656"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
