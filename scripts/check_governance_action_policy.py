#!/usr/bin/env python3
"""Fail-closed checks for the Governance V2 action/native-value policy."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import jsonschema
from eth_hash.auto import keccak

ROOT = Path(__file__).resolve().parents[1]
POLICY_PATH = ROOT / "release-artifacts" / "governance-action-policy.json"
SCHEMA_PATH = (
    ROOT
    / "release-artifacts"
    / "schema"
    / "governance-action-policy.v1.schema.json"
)
EXECUTOR_PATH = ROOT / "smart-contracts" / "StreamGovernanceExecutor.sol"
POLICY_LIBRARY_PATH = ROOT / "smart-contracts" / "StreamGovernanceActionPolicy.sol"
MANIFEST_PATH = ROOT / "smart-contracts" / "StreamGovernanceManifest.sol"

EXPECTED_ACTION_CLASSES = {
    0: "IMMEDIATE_TIGHTENING",
    1: "DELAYED_LOOSENING",
    2: "TERMINAL_FREEZE",
    3: "POINTER_REPLACEMENT",
    4: "FUNDS_RECOVERY",
    5: "SUCCESSOR_DECLARATION",
}
EXPECTED_SOURCE_SELECTORS = {
    (0, "GOVERNANCE_EXECUTOR", "registerProposer(address,bool)"): "0x0794ec84",
    (1, "GOVERNANCE_EXECUTOR", "registerProposer(address,bool)"): "0x0794ec84",
    (0, "GOVERNANCE_EXECUTOR", "registerCanceller(address,bool)"): "0xcb585072",
    (1, "GOVERNANCE_EXECUTOR", "registerCanceller(address,bool)"): "0xcb585072",
    (0, "GOVERNANCE_EXECUTOR", "setApprovedNativeReceiver(address,bool)"): "0x31ac9e82",
    (1, "GOVERNANCE_EXECUTOR", "setApprovedNativeReceiver(address,bool)"): "0x31ac9e82",
    (0, "GOVERNANCE_EXECUTOR", "setTighteningCall(address,bytes4,bool)"): "0x250885fb",
    (1, "GOVERNANCE_EXECUTOR", "setTighteningCall(address,bytes4,bool)"): "0x250885fb",
    (0, "GOVERNANCE_EXECUTOR", "registerFreezeSelector(address,bytes4,bool)"): "0xb1b73b69",
    (1, "GOVERNANCE_EXECUTOR", "registerFreezeSelector(address,bytes4,bool)"): "0xb1b73b69",
    (3, "GOVERNANCE_EXECUTOR", "rotateGovernanceRoot(address,bytes32)"): "0x46bf8975",
    (
        2,
        "GOVERNANCE_EXECUTOR",
        "registerSystemManifestTailTrigger(address,bytes4,uint8)",
    ): "0xc64f0807",
    (3, "GOVERNANCE_EXECUTOR", "sealSystemManifestBootstrap()"): "0xbd1f39cd",
    (1, "ROLE_REGISTRY", "grantRole(bytes32,address)"): "0x2f2ff15d",
    (1, "ROLE_REGISTRY", "revokeRole(bytes32,address)"): "0xd547741f",
    (1, "ROLE_REGISTRY", "grantScopedRole(bytes32,bytes32,address)"): "0x4c5ceedb",
    (1, "ROLE_REGISTRY", "revokeScopedRole(bytes32,bytes32,address)"): "0x2862c0f1",
    (0, "ROLE_REGISTRY", "registerRoleManager(address,bool)"): "0x148fed8e",
    (1, "ROLE_REGISTRY", "registerRoleManager(address,bool)"): "0x148fed8e",
    (
        1,
        "MODULE_REGISTRY",
        "registerModule(address,bytes32,bytes4,bytes32,bytes32,string,uint256)",
    ): "0x03eb8dea",
    (0, "MODULE_REGISTRY", "setModuleStatus(address,uint8)"): "0x1dfaba7c",
    (1, "MODULE_REGISTRY", "setModuleStatus(address,uint8)"): "0x1dfaba7c",
    (1, "MODULE_REGISTRY", "setModuleRegistryManifest(bytes32,string)"): "0x7ba46615",
    (1, "GOVERNED_GAS_PARAMETER_HOST", "raiseGasParameter(bytes32,uint256)"): "0x5c0df7da",
    (1, "GOVERNED_TIME_PARAMETER_HOST", "raiseTimeParameter(bytes32,uint256)"): "0x046e1fd5",
    (0, "SYSTEM_MANIFEST_SATELLITE", "SYSTEM_MANIFEST_PUBLISH"): "0x09b1b5c6",
    (1, "SYSTEM_MANIFEST_SATELLITE", "SYSTEM_MANIFEST_PUBLISH"): "0x09b1b5c6",
    (2, "SYSTEM_MANIFEST_SATELLITE", "SYSTEM_MANIFEST_PUBLISH"): "0x09b1b5c6",
    (3, "SYSTEM_MANIFEST_SATELLITE", "SYSTEM_MANIFEST_PUBLISH"): "0x09b1b5c6",
}
HEX_32 = re.compile(r"^0x[0-9a-f]{64}$")
HEX_SELECTOR = re.compile(r"^0x[0-9a-f]{8}$")
HEX_ADDRESS = re.compile(r"^0x[0-9a-fA-F]{40}$")
ZERO_WORD = "0x" + "00" * 32
ZERO_ADDRESS = "0x" + "00" * 20
VALUE_SEMANTICS = (
    "0x9734d6cd59791593409e4cc12cae8ad5c2c0fa8cd606deffc0814fbf58109aea"
)
ENTRY_DOMAIN = keccak(b"6529STREAM_GOVERNANCE_ACTION_POLICY_ENTRY_V1")
CHAIN_DOMAIN = keccak(b"6529STREAM_GOVERNANCE_ACTION_POLICY_CHAIN_V1")
CATALOG_DOMAIN = keccak(b"6529STREAM_GOVERNANCE_ACTION_POLICY_CATALOG_V1")


def fail(message: str) -> None:
    raise ValueError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def _uint_word(value: int) -> bytes:
    return value.to_bytes(32, byteorder="big")


def _hex_word(value: str) -> bytes:
    return bytes.fromhex(value[2:])


def _address_word(value: str) -> bytes:
    return b"\x00" * 12 + bytes.fromhex(value[2:])


def _selector_word(value: str) -> bytes:
    return bytes.fromhex(value[2:]) + b"\x00" * 28


def _policy_key(entry: dict) -> bytes:
    return keccak(
        _uint_word(entry["action_class"])
        + _address_word(entry["target"])
        + _selector_word(entry["selector"])
    )


def candidate_catalog_hash(binding: dict) -> str:
    chain_hash = bytes(32)
    for index, entry in enumerate(binding["entries"]):
        encoded_entry = (
            ENTRY_DOMAIN
            + _uint_word(index)
            + _uint_word(entry["action_class"])
            + _address_word(entry["target"])
            + _selector_word(entry["selector"])
            + _hex_word(entry["target_code_hash"])
            + _hex_word(entry["target_profile_hash"])
            + _uint_word(entry["call_type"])
            + _uint_word(entry["value_policy"])
            + _uint_word(int(entry["value_limit"]))
            + _hex_word(entry["value_semantics_hash"])
        )
        entry_hash = keccak(encoded_entry)
        chain_hash = keccak(
            CHAIN_DOMAIN + chain_hash + entry_hash + _uint_word(index)
        )
    catalog_hash = keccak(
        CATALOG_DOMAIN
        + _uint_word(binding["chain_id"])
        + _address_word(binding["executor"])
        + _hex_word(binding["candidate_profile_hash"])
        + _uint_word(len(binding["entries"]))
        + chain_hash
    )
    return "0x" + catalog_hash.hex()


def _validate_candidate_binding(binding: dict, policy: dict) -> None:
    status = binding.get("status")
    require(status in {"not_available", "complete"}, "unsupported candidate binding status")
    if status == "not_available":
        require(
            binding.get("blocked_by_issue", "").endswith("/issues/656"),
            "unbound candidate must cite issue #656",
        )
        require(binding.get("entry_count") == 0, "unbound candidate entry count must be zero")
        require(binding.get("entries") == [], "unbound candidate entries must be empty")
        for key in ("chain_id", "executor", "candidate_profile_hash", "catalog_hash"):
            require(binding.get(key) is None, f"unbound candidate {key} must be null")
        return

    require(
        isinstance(binding.get("chain_id"), int) and binding["chain_id"] > 0,
        "bound candidate chain_id",
    )
    require(HEX_ADDRESS.fullmatch(binding.get("executor", "")) is not None, "bound executor")
    require(binding["executor"].lower() != ZERO_ADDRESS, "bound executor")
    require(
        HEX_32.fullmatch(binding.get("candidate_profile_hash", "")) is not None,
        "bound candidate profile hash",
    )
    require(binding["candidate_profile_hash"] != ZERO_WORD, "bound candidate profile hash")
    require(
        HEX_32.fullmatch(binding.get("catalog_hash", "")) is not None,
        "bound candidate catalog hash",
    )
    entries = binding.get("entries")
    require(isinstance(entries, list) and entries, "bound candidate entries")
    require(
        len(entries) <= policy["runtime_enforcement"]["max_entries"],
        "bound candidate entry cap",
    )
    require(binding.get("entry_count") == len(entries), "bound candidate entry count")
    keys: set[tuple[int, str, str]] = set()
    prior_policy_key: bytes | None = None
    source_entries = {
        (entry["action_class"], entry["target_profile"], entry["signature"]): entry
        for entry in policy["source_catalog"]["entries"]
    }
    for index, entry in enumerate(entries):
        key = (entry.get("action_class"), entry.get("target"), entry.get("selector"))
        require(key not in keys, f"duplicate bound candidate tuple at {index}")
        keys.add(key)
        require(key[0] in EXPECTED_ACTION_CLASSES, f"bound candidate action class at {index}")
        require(HEX_ADDRESS.fullmatch(key[1] or "") is not None, f"bound target at {index}")
        require(key[1].lower() != ZERO_ADDRESS, f"bound target at {index}")
        require(HEX_SELECTOR.fullmatch(key[2] or "") is not None, f"bound selector at {index}")
        require(
            HEX_32.fullmatch(entry.get("target_code_hash", "")) is not None,
            f"bound target code hash at {index}",
        )
        require(
            HEX_32.fullmatch(entry.get("target_profile_hash", "")) is not None,
            f"bound target profile hash at {index}",
        )
        require(
            entry["target_profile_hash"] != ZERO_WORD,
            f"bound target profile hash at {index}",
        )
        require(entry.get("call_type") in {1, 2}, f"bound call type at {index}")
        require(entry.get("value_policy") in {0, 1, 2}, f"bound value policy at {index}")
        policy_key = _policy_key(entry)
        require(
            prior_policy_key is None or prior_policy_key < policy_key,
            f"bound candidate ordering at {index}",
        )
        prior_policy_key = policy_key
        if entry["value_policy"] == 0:
            require(entry.get("value_limit") == "0", f"zero value limit at {index}")
            require(
                entry.get("value_semantics_hash") == "0x" + "00" * 32,
                f"zero value semantics at {index}",
            )
        else:
            require(int(entry.get("value_limit", "0")) > 0, f"nonzero value limit at {index}")
            require(
                entry.get("value_semantics_hash") == VALUE_SEMANTICS,
                f"nonzero value semantics at {index}",
            )
        if entry["call_type"] == 1:
            require(
                entry["target_code_hash"] != ZERO_WORD,
                f"bound direct target code hash at {index}",
            )
            source_key = (
                entry.get("action_class"),
                entry.get("target_profile"),
                entry.get("signature"),
            )
            source_entry = source_entries.get(source_key)
            require(source_entry is not None, f"unregistered bound direct route at {index}")
            require(
                source_entry["selector"] == entry["selector"],
                f"bound selector/source mismatch at {index}",
            )
            require(entry["value_policy"] == 0, f"bound direct value policy at {index}")
        else:
            require(entry["selector"] == "0x00000000", f"bound native selector at {index}")
            require(
                entry.get("source_id")
                in {
                    source["id"]
                    for source in policy["source_catalog"]["native_value_entries"]
                },
                f"unregistered bound native route at {index}",
            )
    require(
        binding["catalog_hash"] == candidate_catalog_hash(binding),
        "bound candidate catalog hash",
    )


def check(policy: dict) -> None:
    schema = json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))
    jsonschema.Draft202012Validator.check_schema(schema)
    jsonschema.Draft202012Validator(schema).validate(policy)
    require(
        policy.get("schema_version") == "6529stream.governance-action-policy.v1",
        "schema version",
    )
    require(policy.get("production_readiness_evidence") is False, "readiness claim")
    require(
        {entry["id"]: entry["name"] for entry in policy.get("action_classes", [])}
        == EXPECTED_ACTION_CLASSES,
        "action class vocabulary",
    )

    enforcement = policy.get("runtime_enforcement", {})
    require(enforcement.get("max_entries") == 1024, "runtime enforcement catalog cap")
    for flag in (
        "schedule_validation",
        "execution_validation",
        "runtime_code_hash_validation",
        "scheduled_catalog_snapshot_validation",
    ):
        require(enforcement.get(flag) is True, f"runtime enforcement {flag}")
    require(enforcement.get("unknown_tuple_policy") == "revert", "unknown tuple policy")
    require(enforcement.get("default_value_policy") == "zero_only", "default value policy")
    require(enforcement.get("batch_policy") == "atomic_exact_msg_value_sum", "batch policy")
    require(enforcement.get("surplus_policy") == "revert", "surplus policy")

    value_semantics = policy.get("value_semantics", {})
    require(value_semantics.get("zero_only", {}).get("id") == 0, "zero value id")
    for name, identifier in (("exact", 1), ("bounded", 2)):
        value = value_semantics.get(name, {})
        require(value.get("id") == identifier, f"{name} value id")
        require(value.get("semantics_hash") == VALUE_SEMANTICS, f"{name} semantics hash")
        for key in ("source", "destination", "accounting", "refund_policy", "failure_policy"):
            require(isinstance(value.get(key), str) and value[key], f"{name} {key}")

    entries = policy.get("source_catalog", {}).get("entries")
    require(isinstance(entries, list), "source catalog entries")
    tuples: set[tuple[int, str, str]] = set()
    selector_keys: set[tuple[int, str, str]] = set()
    forbidden_names = {
        value.lower() for value in policy.get("forbidden_routes", {}).get("function_names", [])
    }
    for index, entry in enumerate(entries):
        source_tuple = (
            entry.get("action_class"),
            entry.get("target_profile"),
            entry.get("signature"),
        )
        require(source_tuple not in tuples, f"duplicate source tuple at {index}")
        tuples.add(source_tuple)
        selector_key = (
            entry.get("action_class"),
            entry.get("target_profile"),
            entry.get("selector"),
        )
        require(selector_key not in selector_keys, f"duplicate selector tuple at {index}")
        selector_keys.add(selector_key)
        require(HEX_SELECTOR.fullmatch(entry.get("selector", "")) is not None, f"selector {index}")
        require(entry.get("call_type") == "direct", f"source call type at {index}")
        require(entry.get("value_policy") == "zero_only", f"source value policy at {index}")
        function_name = entry.get("signature", "").split("(", 1)[0].lower()
        require(function_name not in forbidden_names, f"forbidden route at {index}")
        require(
            entry.get("selector") == EXPECTED_SOURCE_SELECTORS.get(source_tuple),
            f"source selector at {index}",
        )
    require(tuples == set(EXPECTED_SOURCE_SELECTORS), "source catalog tuple set")
    require(
        policy.get("source_catalog", {}).get("native_value_entries") == [],
        "launch source catalog must not authorize native value",
    )

    forbidden_kinds = set(policy.get("forbidden_routes", {}).get("target_kinds", []))
    require(
        {
            "generic_proxy",
            "generic_multicall",
            "generic_fallback_dispatcher",
            "generic_delegatecall_router",
            "unregistered_module",
        }
        <= forbidden_kinds,
        "forbidden route kinds",
    )
    _validate_candidate_binding(policy.get("candidate_binding", {}), policy)
    release_gate = policy.get("release_gate", {})
    require(release_gate.get("risk_id") == "RISK-GOV-003", "risk id")
    require(release_gate.get("status") == "open", "risk must remain open")

    executor_source = EXECUTOR_PATH.read_text(encoding="utf-8")
    policy_source = POLICY_LIBRARY_PATH.read_text(encoding="utf-8")
    manifest_source = MANIFEST_PATH.read_text(encoding="utf-8")
    require(
        executor_source.count("StreamGovernanceActionPolicy.validateCalls(") >= 2
        and "function validateCalls(" in policy_source,
        "executor must validate at schedule and execution",
    )
    require(
        "GovernanceActionPolicySnapshotMismatch" in executor_source,
        "scheduled catalog snapshot check",
    )
    require("ACTION_POLICY_CATALOG_V1" in policy_source, "catalog hash domain")
    require("GovernanceActionPolicyUnknown" in policy_source, "unknown tuple rejection")
    require("GovernanceActionPolicyValueRejected" in policy_source, "value rejection")
    require("StreamGovernanceActionPolicy.bind(" in manifest_source, "manifest bootstrap bind")


def main() -> int:
    try:
        check(json.loads(POLICY_PATH.read_text(encoding="utf-8")))
    except (
        OSError,
        json.JSONDecodeError,
        jsonschema.SchemaError,
        jsonschema.ValidationError,
        KeyError,
        TypeError,
        ValueError,
    ) as exc:
        print(f"governance action policy check failed: {exc}", file=sys.stderr)
        return 1
    print("governance action policy check passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
