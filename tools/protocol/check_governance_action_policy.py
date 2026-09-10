#!/usr/bin/env python3
"""Fail-closed checks for the Governance V2 action/native-value policy."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import jsonschema
from eth_hash.auto import keccak

ROOT = Path(__file__).resolve().parents[2]
POLICY_PATH = ROOT / "release-artifacts" / "governance-action-policy.json"
SCHEMA_PATH = (
    ROOT
    / "release-artifacts"
    / "schema"
    / "governance-action-policy.v1.schema.json"
)
EXECUTOR_PATH = (
    ROOT / "smart-contracts" / "domains" / "governance" / "StreamGovernanceExecutor.sol"
)
POLICY_LIBRARY_PATH = (
    ROOT
    / "smart-contracts"
    / "domains"
    / "governance"
    / "StreamGovernanceActionPolicy.sol"
)
MANIFEST_PATH = (
    ROOT / "smart-contracts" / "domains" / "governance" / "StreamGovernanceManifest.sol"
)
BOOTSTRAP_PATH = (
    ROOT / "smart-contracts" / "domains" / "governance" / "StreamGovernanceBootstrap.sol"
)
SCHEDULING_PATH = EXECUTOR_PATH.with_name("StreamGovernanceScheduling.sol")

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
EXPECTED_DOMAINS = {
    "entry": (
        "6529STREAM_GOVERNANCE_ACTION_POLICY_ENTRY_V1",
        ENTRY_DOMAIN,
    ),
    "chain": (
        "6529STREAM_GOVERNANCE_ACTION_POLICY_CHAIN_V1",
        CHAIN_DOMAIN,
    ),
    "catalog": (
        "6529STREAM_GOVERNANCE_ACTION_POLICY_CATALOG_V1",
        CATALOG_DOMAIN,
    ),
}


def fail(message: str) -> None:
    raise ValueError(message)


def require(condition: bool, message: str) -> None:
    if not condition:
        fail(message)


def validate_catalog_snapshot_source(executor_source: str, bootstrap_source: str) -> None:
    executor = re.sub(r"\s+", "", executor_source)
    bootstrap = re.sub(r"\s+", "", bootstrap_source)
    require(
        "_actionPolicyCatalogHashes[actionId]=_actionPolicy.catalogHash;" in executor
        and "StreamGovernanceBootstrap.validateExecution(" in executor
        and "scheduledCatalogHash:_actionPolicyCatalogHashes[actionId]" in executor,
        "scheduled catalog snapshot delegation",
    )
    require(
        "currentCatalogHash=actionPolicy.catalogHash;" in bootstrap
        and "bytes32scheduledCatalogHash=ctx.scheduledCatalogHash;" in bootstrap
        and "if(scheduledCatalogHash!=currentCatalogHash)" in bootstrap
        and "revertIStreamGovernanceExecutor.GovernanceActionPolicySnapshotMismatch(" in bootstrap,
        "scheduled catalog snapshot check",
    )


# Pure lexical helpers copied from tools/protocol/check_external_call_gas_inventory.py
# at e7a6550c8f22315d954c7141e00d7ec1fda66342. Keep these algorithms local so the
# deliberately closed release verifier does not import the inventory CLI runtime.
def mask_comments_and_strings(source: str) -> str:
    """Replace comments and string contents with spaces while preserving offsets."""

    masked = list(source)
    index = 0
    state = "code"
    quote = ""
    while index < len(source):
        current = source[index]
        following = source[index + 1] if index + 1 < len(source) else ""

        if state == "code":
            if current == "/" and following == "/":
                masked[index] = masked[index + 1] = " "
                state = "line-comment"
                index += 2
                continue
            if current == "/" and following == "*":
                masked[index] = masked[index + 1] = " "
                state = "block-comment"
                index += 2
                continue
            if current in {'"', "'"}:
                quote = current
                masked[index] = " "
                state = "string"
                index += 1
                continue
            index += 1
            continue

        if state == "line-comment":
            if current == "\n":
                state = "code"
            else:
                masked[index] = " "
            index += 1
            continue

        if state == "block-comment":
            if current == "*" and following == "/":
                masked[index] = masked[index + 1] = " "
                state = "code"
                index += 2
            else:
                if current not in "\r\n":
                    masked[index] = " "
                index += 1
            continue

        if current == "\\":
            masked[index] = " "
            if index + 1 < len(source):
                if source[index + 1] not in "\r\n":
                    masked[index + 1] = " "
                index += 2
            else:
                index += 1
            continue
        masked[index] = " " if current not in "\r\n" else current
        if current == quote:
            state = "code"
        index += 1

    return "".join(masked)

def matching_closing_brace(source: str, opening: int) -> int | None:
    depth = 0
    for index in range(opening, len(source)):
        if source[index] == "{":
            depth += 1
        elif source[index] == "}":
            depth -= 1
            if depth == 0:
                return index
    return None


def _function_body(source: str, name: str) -> str:
    """Read one real function body, excluding comment/string lookalikes."""
    masked = mask_comments_and_strings(source)
    matches = list(re.finditer(r"\bfunction\s+" + re.escape(name) + r"\s*\(", masked))
    require(len(matches) == 1, f"policy validation path: unique {name} function")
    opening = masked.find("{", matches[0].end())
    semicolon = masked.find(";", matches[0].end())
    require(opening >= 0 and (semicolon < 0 or opening < semicolon),
            f"policy validation path: {name} body")
    closing = matching_closing_brace(masked, opening)
    require(closing is not None, f"policy validation path: {name} closing brace")
    return masked[opening + 1:closing]


def _top_level_statements(body: str) -> list[str]:
    """Select unconditional statement spellings, including any unbraced if prefix."""
    statements = []
    depth = parens = start = 0
    for index, char in enumerate(body):
        if char == "(":
            parens += 1
        elif char == ")":
            parens -= 1
        elif char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0 and parens == 0:
                start = index + 1
        elif char == ";" and depth == 0 and parens == 0:
            statements.append(re.sub(r"\s+", "", body[start:index + 1]))
            start = index + 1
    return statements


def validate_policy_call_path(executor_source: str, scheduling_source: str) -> None:
    """Bind scheduling's library route and execution's separate policy validation."""
    masked = mask_comments_and_strings(executor_source)
    imports = list(re.finditer(r'import\s+"\./StreamGovernanceScheduling\.sol"\s*;', executor_source))
    require(any(masked[m.start():m.start() + 6] == "import" for m in imports),
            "policy validation path: scheduling source import")
    schedule_body = _function_body(executor_source, "_schedule")
    prepare_body = _function_body(scheduling_source, "prepare")
    execute_body = _function_body(executor_source, "_execute")
    prepare = _top_level_statements(prepare_body)
    execute = _top_level_statements(execute_body)
    expected_delegation = """StreamGovernanceScheduling.Prepared memory prepared =
        StreamGovernanceScheduling.prepare(_admin, _policy, _actionPolicy, _manifest,
            StreamGovernanceScheduling.Runtime({owner: owner(),
                bootstrapAuthority: genesisBootstrapAuthority, nonce: _nonce,
                pendingCount: _pendingScheduledActionCount, executing: _executing,
                genesisPlanHash: genesisPlanHash, genesisInitialized: genesisInitialized}),
            ctx, calls);"""
    require(re.sub(r"\s+", "", schedule_body).startswith(re.sub(r"\s+", "", expected_delegation)),
            "policy validation path: schedule delegation and bound arguments")
    expected_prepare = """StreamGovernanceActionPolicy.validateCalls(actionPolicy,
        manifest.actionPolicyCandidateProfileHash, manifest.actionPolicyCatalogHash,
        manifest.actionPolicyEntryCount, ctx.actionClass, calls, callDatas);"""
    require(prepare.count(re.sub(r"\s+", "", expected_prepare)) == 1,
            "policy validation path: scheduling policy validation")
    expected_execute = """StreamGovernanceActionPolicy.validateCalls(_actionPolicy,
        _manifest.actionPolicyCandidateProfileHash, _manifest.actionPolicyCatalogHash,
        _manifest.actionPolicyEntryCount, action.actionClass, calls, scheduledCallDatas);"""
    execution_call = re.sub(r"\s+", "", expected_execute)
    executed = "action.status=GovernanceActionStatus.EXECUTED;"
    require(execute.count(execution_call) == 1 and executed in execute
            and execute.index(execution_call) < execute.index(executed),
            "policy validation path: execution policy validation before effects")
    require(not any(re.search(r"\b(return|assembly)\b", body)
                    for body in (schedule_body, prepare_body, execute_body)),
            "policy validation path: early return or assembly bypass")


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
    require(
        enforcement.get("lookup_key") == ["action_class", "target", "selector"],
        "runtime enforcement lookup key",
    )
    for flag in (
        "schedule_validation",
        "execution_validation",
        "runtime_code_hash_validation",
        "catalog_commitment_mirror_validation",
        "selected_entry_hash_validation",
        "scheduled_catalog_snapshot_validation",
    ):
        require(enforcement.get(flag) is True, f"runtime enforcement {flag}")
    require(enforcement.get("unknown_tuple_policy") == "revert", "unknown tuple policy")
    require(enforcement.get("default_value_policy") == "zero_only", "default value policy")
    require(enforcement.get("batch_policy") == "atomic_exact_msg_value_sum", "batch policy")
    require(enforcement.get("surplus_policy") == "revert", "surplus policy")
    domains = enforcement.get("domains", {})
    require(set(domains) == set(EXPECTED_DOMAINS), "runtime enforcement domain set")
    for name, (preimage, expected_hash) in EXPECTED_DOMAINS.items():
        domain = domains.get(name, {})
        require(domain.get("preimage") == preimage, f"{name} domain preimage")
        require(
            domain.get("keccak256") == "0x" + expected_hash.hex(),
            f"{name} domain hash",
        )

    value_semantics = policy.get("value_semantics", {})
    zero_only = value_semantics.get("zero_only", {})
    require(zero_only.get("id") == 0, "zero value id")
    require(zero_only.get("value_limit") == "0", "zero value limit")
    require(zero_only.get("semantics_hash") == ZERO_WORD, "zero value semantics hash")
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
    validate_policy_call_path(executor_source, SCHEDULING_PATH.read_text(encoding="utf-8"))
    _function_body(policy_source, "validateCalls")
    validate_catalog_snapshot_source(
        executor_source, BOOTSTRAP_PATH.read_text(encoding="utf-8")
    )
    for source_domain in (
        "ACTION_POLICY_ENTRY_V1",
        "ACTION_POLICY_CHAIN_V1",
        "ACTION_POLICY_CATALOG_V1",
    ):
        require(source_domain in policy_source, f"{source_domain} source domain")
    require("entryHashes" in policy_source, "selected entry commitment check")
    require(
        "actionPolicyCatalogHash" in executor_source,
        "manifest catalog commitment mirror check",
    )
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
