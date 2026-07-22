#!/usr/bin/env python3
"""Validate the canonical genesis deployment profile and candidate inventory."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PROFILE_SCHEMA = "6529stream.genesis-deployment-profile.v1"
CONTRACTS_SCHEMA = "6529stream.release-artifact-contracts.v1"
CONCRETE_CANDIDATE_MODEL_BLOCKER = (
    "release-artifacts/contracts.json uses "
    f"{CONTRACTS_SCHEMA}, an implementation class catalog that cannot prove concrete "
    "genesis deployment instances, addresses, code hashes, profile bindings, distinct "
    "fallbacks, or parameter-bound probes; issue #656 requires an instance-aware "
    "deployment candidate artifact"
)
DEFAULT_PROFILE = Path("release-artifacts/genesis-deployment-profile.json")
DEFAULT_CONTRACTS = Path("release-artifacts/contracts.json")
NORMATIVE_SOURCE = "docs/launch-conformance-matrix.md"
NORMATIVE_ANCHOR = "LCM-GENESIS"
MAINNET_CHAIN_ID = 1
GGP_INVENTORY_SOURCE = Path("docs/stream-long-term-architecture.md")
GTP_MIRROR_SOURCE = Path("docs/launch-v1-target-architecture.md")

FIXED_CONTRACT_KEYS = (
    "STREAM_CORE",
    "GOVERNANCE_LAYER",
    "MODULE_REGISTRY",
    "REVENUE_RESOLVER",
    "SPLIT_FACTORY",
    "SPLIT_WALLET_IMPLEMENTATION",
    "REVENUE_ESCROW",
    "ASSET_POLICY_REGISTRY",
    "PRIMARY_SALE_SETTLEMENT",
    "CLAIM_ROUTER",
    "MINT_MANAGER",
    "MINT_LEDGER",
    "MINT_TICKET_GATE",
    "FIXED_PRICE_SALE_ADAPTER",
    "ENGLISH_AUCTION_HOUSE",
    "DUTCH_AUCTION_ADAPTER",
    "PRIVATE_SALE_ADAPTER",
    "BURN_MINT_GATE",
    "DELEGATE_REGISTRY_GATE",
    "ERC20_PRIMARY_SETTLEMENT_ADAPTER",
    "ARTIST_REGISTRY",
    "METADATA_ROUTER",
    "RENDERER_V1",
    "COLLECTION_METADATA",
    "SCHEMA_REGISTRY",
    "OWNER_RECORDS",
    "PRESERVATION_RECORDS",
    "COLLECTION_ATTESTATIONS",
    "COLLECTION_VIEWS",
    "ENTROPY_COORDINATOR",
    "ENTROPY_PROVIDER_VRF",
    "ENTROPY_PROVIDER_FALLBACK",
    "ARTWORK_FINALITY_REGISTRY",
    "ENTROPY_COORDINATOR_FALLBACK",
    "MINT_MANAGER_FALLBACK",
)

GGP_PARAMETERS = (
    "ROYALTY_RESOLVER_GAS_LIMIT",
    "ROYALTY_RETURN_GAS_BUFFER",
    "ERC_1271_GAS_LIMIT",
    "ASSET_POLICY_GAS_LIMIT",
    "WALLET_DEPOSIT_GAS_LIMIT",
    "FLUSH_GAS_FLOOR",
    "MINT_GATE_GAS_LIMIT",
    "TICKET_ERC1271_GAS_LIMIT",
    "ARTIST_AUTHORITY_GAS_LIMIT",
    "SALE_ERC1271_GAS_LIMIT",
    "DELEGATE_REGISTRY_GAS_LIMIT",
    "SALE_ARTIST_AUTHORITY_GAS_LIMIT",
    "REVEAL_ATTEMPT_GAS_LIMIT",
    "SALE_NFT_DELIVERY_GAS_LIMIT",
    "METADATA_ROUTER_GAS_LIMIT",
    "ENTROPY_VIEW_GAS_LIMIT",
    "ENTROPY_REGISTRATION_GAS_LIMIT",
    "ENTROPY_RESULT_PROBE_GAS_LIMIT",
    "VRF_CALLBACK_GAS_LIMIT",
    "ARTIST_ERC1271_VERIFY_GAS",
    "METADATA_ERC1271_VERIFY_GAS",
    "FINALITY_COMPONENT_READ_GAS",
)

GTP_PARAMETERS = (
    "ENTROPY_REQUEST_TIMEOUT_BLOCKS",
    "ENTROPY_REVEAL_SLO_BLOCKS",
    "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS",
)


class GenesisProfileError(RuntimeError):
    """Raised when the profile or candidate inventory is malformed."""


@dataclass(frozen=True)
class ProfileAudit:
    """Validated profile summary and production-completeness blockers."""

    entry_count: int
    candidate_count: int
    blockers: tuple[str, ...]


def load_json(path: Path) -> Any:
    """Load one UTF-8 JSON file with stable diagnostics."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise GenesisProfileError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise GenesisProfileError(f"invalid JSON in {path}: {exc}") from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise GenesisProfileError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise GenesisProfileError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        raise GenesisProfileError(f"{path} must be a non-empty string")
    return value


def require_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise GenesisProfileError(f"{path} must be an integer")
    return value


def require_string_list(value: Any, path: str) -> list[str]:
    values = require_list(value, path)
    result = [require_string(item, f"{path}[{index}]") for index, item in enumerate(values)]
    if len(result) != len(set(result)):
        raise GenesisProfileError(f"{path} must not contain duplicates")
    return result


def require_exact_keys(value: dict[str, Any], required: set[str], path: str) -> None:
    missing = sorted(required - value.keys())
    extra = sorted(value.keys() - required)
    if missing:
        raise GenesisProfileError(f"{path} is missing fields: {', '.join(missing)}")
    if extra:
        raise GenesisProfileError(f"{path} has unsupported fields: {', '.join(extra)}")


def resolve_path(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise GenesisProfileError(f"missing required file: {path}") from exc


def validate_document_mirrors(entries: list[dict[str, Any]], repo_root: Path) -> None:
    """Require the checked profile to match its three normative inventory mirrors."""
    matrix = read_text(repo_root / NORMATIVE_SOURCE)
    block_match = re.search(
        r"Mandatory genesis contracts:\s*```text\s*(.*?)\s*```",
        matrix,
        flags=re.DOTALL,
    )
    if block_match is None:
        raise GenesisProfileError(
            f"{NORMATIVE_SOURCE} is missing the Mandatory genesis contracts block"
        )
    block = block_match.group(1)
    row_matches = list(re.finditer(r"^\s*(\d+)(?:-(\d+))?\s+", block, re.MULTILINE))
    numbered_ids: list[int] = []
    row_text_by_id: dict[int, str] = {}
    for index, match in enumerate(row_matches):
        start = int(match.group(1))
        end = int(match.group(2) or start)
        if end < start:
            raise GenesisProfileError(f"{NORMATIVE_SOURCE} has a reversed genesis range")
        numbered_ids.extend(range(start, end + 1))
        row_end = row_matches[index + 1].start() if index + 1 < len(row_matches) else len(block)
        normalized_row = " ".join(block[match.start() : row_end].split())
        for entry_id in range(start, end + 1):
            row_text_by_id[entry_id] = normalized_row
    profile_ids = [entry["id"] for entry in entries]
    if numbered_ids != profile_ids:
        raise GenesisProfileError(
            f"{NORMATIVE_SOURCE} numbered genesis inventory does not match the profile"
        )
    for entry in entries[: len(FIXED_CONTRACT_KEYS)] + entries[-1:]:
        normalized_requirement = " ".join(entry["requirement"].split())
        if normalized_requirement not in row_text_by_id[entry["id"]]:
            raise GenesisProfileError(
                f"profile entry {entry['id']} requirement is not mirrored by "
                f"{NORMATIVE_SOURCE}"
            )

    architecture = read_text(repo_root / GGP_INVENTORY_SOURCE)
    ggp_match = re.search(
        r"GGP inventory\.(.*?)(?:\nA future guarded path)",
        architecture,
        flags=re.DOTALL,
    )
    if ggp_match is None:
        raise GenesisProfileError(f"{GGP_INVENTORY_SOURCE} is missing the GGP inventory")
    ggp_rows = tuple(
        re.findall(r"^\| `([^`]+)` \|", ggp_match.group(1), flags=re.MULTILINE)
    )
    if ggp_rows != GGP_PARAMETERS:
        raise GenesisProfileError(
            f"{GGP_INVENTORY_SOURCE} GGP rows do not match the profile probe inventory"
        )

    target_architecture = read_text(repo_root / GTP_MIRROR_SOURCE)
    gtp_rows = tuple(
        re.findall(r"^\| `GTP_([^`]+)` \|", target_architecture, flags=re.MULTILINE)
    )
    if gtp_rows != GTP_PARAMETERS:
        raise GenesisProfileError(
            f"{GTP_MIRROR_SOURCE} GTP rows do not match the shared cadence-probe inventory"
        )


def validate_implementation(value: Any, path: str, kind: str) -> dict[str, Any]:
    implementation = require_dict(value, path)
    require_exact_keys(implementation, {"mode", "names"}, path)
    mode = require_string(implementation.get("mode"), f"{path}.mode")
    names = require_string_list(implementation.get("names"), f"{path}.names")
    allowed_modes = {
        "contract": {
            "exact",
            "one_of",
            "manifest_equivalent",
            "distinct_instance",
            "role_bound",
        },
        "ggp_probe": {"parameter_bound"},
        "gtp_probe": {"shared_parameter_bound"},
    }[kind]
    if mode not in allowed_modes:
        raise GenesisProfileError(
            f"{path}.mode must be one of: {', '.join(sorted(allowed_modes))}"
        )
    if mode in {"exact", "one_of", "distinct_instance"} and not names:
        raise GenesisProfileError(f"{path}.names must not be empty for mode {mode!r}")
    if mode in {"manifest_equivalent", "role_bound", "parameter_bound"} and names:
        raise GenesisProfileError(f"{path}.names must be empty for mode {mode!r}")
    if mode == "shared_parameter_bound" and not names:
        raise GenesisProfileError(f"{path}.names must not be empty for mode {mode!r}")
    return implementation


def validate_entry(value: Any, index: int) -> dict[str, Any]:
    path = f"profile.entries[{index}]"
    entry = require_dict(value, path)
    required = {
        "id",
        "key",
        "kind",
        "requirement",
        "deployment_scope",
        "multiplicity",
        "implementation",
        "required_interfaces",
        "required_markers",
        "approved_aliases",
        "normative_anchors",
        "parameters",
        "distinct_from",
    }
    require_exact_keys(entry, required, path)
    entry_id = require_int(entry.get("id"), f"{path}.id")
    require_string(entry.get("key"), f"{path}.key")
    kind = require_string(entry.get("kind"), f"{path}.kind")
    if kind not in {"contract", "ggp_probe", "gtp_probe"}:
        raise GenesisProfileError(f"{path}.kind is unsupported: {kind!r}")
    require_string(entry.get("requirement"), f"{path}.requirement")
    scope = require_string(entry.get("deployment_scope"), f"{path}.deployment_scope")
    allowed_scopes = {
        "singleton",
        "implementation",
        "fallback_instance",
        "per_parameter_probe",
        "shared_probe",
    }
    if scope not in allowed_scopes:
        raise GenesisProfileError(f"{path}.deployment_scope is unsupported: {scope!r}")

    multiplicity = require_dict(entry.get("multiplicity"), f"{path}.multiplicity")
    require_exact_keys(multiplicity, {"minimum", "maximum"}, f"{path}.multiplicity")
    minimum = require_int(multiplicity.get("minimum"), f"{path}.multiplicity.minimum")
    maximum = require_int(multiplicity.get("maximum"), f"{path}.multiplicity.maximum")
    if minimum != 1 or maximum != 1:
        raise GenesisProfileError(f"{path}.multiplicity must require exactly one deployment")

    validate_implementation(entry.get("implementation"), f"{path}.implementation", kind)
    require_string_list(entry.get("required_interfaces"), f"{path}.required_interfaces")
    require_string_list(entry.get("required_markers"), f"{path}.required_markers")
    require_string_list(entry.get("approved_aliases"), f"{path}.approved_aliases")
    anchors = require_string_list(entry.get("normative_anchors"), f"{path}.normative_anchors")
    if not anchors:
        raise GenesisProfileError(f"{path}.normative_anchors must not be empty")
    parameters = require_string_list(entry.get("parameters"), f"{path}.parameters")
    distinct_from = require_list(entry.get("distinct_from"), f"{path}.distinct_from")
    distinct_ids = [require_int(item, f"{path}.distinct_from[{i}]") for i, item in enumerate(distinct_from)]
    if len(distinct_ids) != len(set(distinct_ids)) or entry_id in distinct_ids:
        raise GenesisProfileError(f"{path}.distinct_from must contain unique other entry ids")

    if kind == "contract" and parameters:
        raise GenesisProfileError(f"{path}.parameters must be empty for contract entries")
    if kind == "contract" and scope not in {
        "singleton",
        "implementation",
        "fallback_instance",
    }:
        raise GenesisProfileError(
            f"{path}.deployment_scope is invalid for a contract entry: {scope!r}"
        )
    if kind == "ggp_probe" and len(parameters) != 1:
        raise GenesisProfileError(f"{path}.parameters must contain exactly one GGP parameter")
    if kind == "ggp_probe" and scope != "per_parameter_probe":
        raise GenesisProfileError(
            f"{path}.deployment_scope must be 'per_parameter_probe' for GGP probes"
        )
    if kind == "gtp_probe" and tuple(parameters) != GTP_PARAMETERS:
        raise GenesisProfileError(
            f"{path}.parameters must contain the canonical shared GTP inventory"
        )
    if kind == "gtp_probe" and scope != "shared_probe":
        raise GenesisProfileError(
            f"{path}.deployment_scope must be 'shared_probe' for GTP probes"
        )
    return entry


def validate_profile_document(data: Any) -> list[dict[str, Any]]:
    """Validate the closed-world requirement artifact and return its entries."""
    profile = require_dict(data, "profile")
    require_exact_keys(
        profile,
        {
            "schema_version",
            "normative_source",
            "chain_id",
            "entries",
            "factory_spawned_exclusions",
            "out_of_inventory",
        },
        "profile",
    )
    if profile.get("schema_version") != PROFILE_SCHEMA:
        raise GenesisProfileError(f"profile.schema_version must be {PROFILE_SCHEMA!r}")
    source = require_dict(profile.get("normative_source"), "profile.normative_source")
    require_exact_keys(source, {"path", "anchor"}, "profile.normative_source")
    if source.get("path") != NORMATIVE_SOURCE or source.get("anchor") != NORMATIVE_ANCHOR:
        raise GenesisProfileError(
            f"profile.normative_source must identify {NORMATIVE_SOURCE} [{NORMATIVE_ANCHOR}]"
        )
    if require_int(profile.get("chain_id"), "profile.chain_id") != MAINNET_CHAIN_ID:
        raise GenesisProfileError(f"profile.chain_id must be {MAINNET_CHAIN_ID}")

    raw_entries = require_list(profile.get("entries"), "profile.entries")
    entries = [validate_entry(value, index) for index, value in enumerate(raw_entries)]
    entry_ids = [entry["id"] for entry in entries]
    if entry_ids != list(range(1, len(entries) + 1)):
        raise GenesisProfileError("profile.entries ids must be contiguous, ordered, and start at 1")
    keys = [entry["key"] for entry in entries]
    if len(keys) != len(set(keys)):
        raise GenesisProfileError("profile.entries keys must be unique")

    implementation_names = {
        name
        for entry in entries
        for name in entry["implementation"]["names"]
    }
    aliases_by_name: dict[str, list[int]] = {}
    for entry in entries:
        for alias in entry["approved_aliases"]:
            aliases_by_name.setdefault(alias, []).append(entry["id"])
    duplicate_aliases = {
        alias: entry_ids
        for alias, entry_ids in aliases_by_name.items()
        if len(entry_ids) > 1
    }
    if duplicate_aliases:
        details = "; ".join(
            f"{alias!r} on entries {', '.join(str(entry_id) for entry_id in entry_ids)}"
            for alias, entry_ids in sorted(duplicate_aliases.items())
        )
        raise GenesisProfileError(
            f"profile.entries approved aliases must be globally unique: {details}"
        )
    overlapping_aliases = sorted(set(aliases_by_name) & implementation_names)
    if overlapping_aliases:
        raise GenesisProfileError(
            "profile.entries approved aliases must not overlap implementation names: "
            + ", ".join(repr(alias) for alias in overlapping_aliases)
        )
    if tuple(keys[: len(FIXED_CONTRACT_KEYS)]) != FIXED_CONTRACT_KEYS:
        raise GenesisProfileError("profile.entries 1-35 do not match the canonical contract inventory")
    if any(entry["kind"] != "contract" for entry in entries[: len(FIXED_CONTRACT_KEYS)]):
        raise GenesisProfileError("profile.entries 1-35 must be contract requirements")

    probe_entries = entries[len(FIXED_CONTRACT_KEYS) : -1]
    if any(entry["kind"] != "ggp_probe" for entry in probe_entries):
        raise GenesisProfileError("profile.entries 36-57 must be per-parameter GGP probes")
    if tuple(entry["parameters"][0] for entry in probe_entries) != GGP_PARAMETERS:
        raise GenesisProfileError("profile.entries 36-57 do not match the canonical GGP inventory")
    if not entries or entries[-1]["kind"] != "gtp_probe":
        raise GenesisProfileError("the final profile entry must be the shared GTP cadence probe")

    governance = entries[1]
    if governance["implementation"]["mode"] != "manifest_equivalent":
        raise GenesisProfileError("profile entry 2 must preserve the governance disjunction")
    provider_fallback = entries[31]
    if provider_fallback["implementation"]["mode"] != "one_of":
        raise GenesisProfileError("profile entry 32 must preserve the fallback-provider disjunction")
    for fallback_id, primary_id in ((34, 30), (35, 11)):
        fallback = entries[fallback_id - 1]
        if (
            fallback["deployment_scope"] != "fallback_instance"
            or fallback["implementation"]["mode"] != "distinct_instance"
            or fallback["distinct_from"] != [primary_id]
        ):
            raise GenesisProfileError(
                f"profile entry {fallback_id} must be a distinct fallback instance of entry {primary_id}"
            )

    exclusions = require_list(
        profile.get("factory_spawned_exclusions"), "profile.factory_spawned_exclusions"
    )
    if exclusions != [
        {
            "name": "StreamSplitWallet instances",
            "factory_entry_id": 5,
            "implementation_entry_id": 6,
        }
    ]:
        raise GenesisProfileError(
            "profile.factory_spawned_exclusions must exclude only on-demand split-wallet instances"
        )
    out_of_inventory = require_list(profile.get("out_of_inventory"), "profile.out_of_inventory")
    if len(out_of_inventory) != 1:
        raise GenesisProfileError("profile.out_of_inventory must contain only the deployer factory")
    deployer = require_dict(out_of_inventory[0], "profile.out_of_inventory[0]")
    require_exact_keys(deployer, {"name", "reason"}, "profile.out_of_inventory[0]")
    if deployer.get("name") != "deployer_factory":
        raise GenesisProfileError("profile.out_of_inventory[0].name must be 'deployer_factory'")
    require_string(deployer.get("reason"), "profile.out_of_inventory[0].reason")

    return entries


def validate_contract_config(data: Any) -> list[dict[str, Any]]:
    """Validate the candidate class inventory fields consumed by this checker."""
    document = require_dict(data, "contracts")
    if document.get("schema_version") != CONTRACTS_SCHEMA:
        raise GenesisProfileError(f"contracts.schema_version must be {CONTRACTS_SCHEMA!r}")
    candidates = require_list(document.get("production_contracts"), "contracts.production_contracts")
    result: list[dict[str, Any]] = []
    names: list[str] = []
    for index, value in enumerate(candidates):
        path = f"contracts.production_contracts[{index}]"
        candidate = require_dict(value, path)
        name = require_string(candidate.get("name"), f"{path}.name")
        require_string(candidate.get("source"), f"{path}.source")
        scope = candidate.get("deployment_scope", "singleton")
        require_string(scope, f"{path}.deployment_scope")
        verified_interfaces = require_string_list(
            candidate.get("verified_interfaces", []), f"{path}.verified_interfaces"
        )
        verified_markers = require_string_list(
            candidate.get("verified_markers", []), f"{path}.verified_markers"
        )
        names.append(name)
        result.append(
            {
                **candidate,
                "deployment_scope": scope,
                "verified_interfaces": verified_interfaces,
                "verified_markers": verified_markers,
            }
        )
    if len(names) != len(set(names)):
        raise GenesisProfileError("contracts.production_contracts names must be unique")
    return result


def completeness_blockers(
    entries: list[dict[str, Any]],
    candidates: list[dict[str, Any]],
) -> list[str]:
    """Return fail-closed blockers without weakening structural validation."""
    blockers: list[str] = []
    matched_by_entry: dict[int, list[dict[str, Any]]] = {}
    for candidate in candidates:
        name = candidate["name"]
        matches = [
            entry
            for entry in entries
            if name in entry["implementation"]["names"]
            or name in entry["approved_aliases"]
        ]
        if not matches:
            blockers.append(
                f"candidate contract {name!r} is extra or has no reviewed profile alias"
            )
            continue
        if len(matches) > 1:
            entry_ids = ", ".join(str(entry["id"]) for entry in matches)
            blockers.append(
                f"candidate contract {name!r} ambiguously matches profile entries {entry_ids}"
            )
            continue
        entry = matches[0]
        target_id = entry["id"]
        matched_by_entry.setdefault(target_id, []).append(candidate)
        if candidate["deployment_scope"] != entry["deployment_scope"]:
            blockers.append(
                f"candidate contract {name!r} has deployment_scope "
                f"{candidate['deployment_scope']!r}, expected {entry['deployment_scope']!r} "
                f"for profile entry {target_id}"
            )
        missing_interfaces = sorted(
            set(entry["required_interfaces"]) - set(candidate["verified_interfaces"])
        )
        if missing_interfaces:
            blockers.append(
                f"candidate contract {name!r} lacks verified interfaces for profile entry "
                f"{target_id}: {', '.join(missing_interfaces)}"
            )
        missing_markers = sorted(
            set(entry["required_markers"]) - set(candidate["verified_markers"])
        )
        if missing_markers:
            blockers.append(
                f"candidate contract {name!r} lacks verified markers for profile entry "
                f"{target_id}: {', '.join(missing_markers)}"
            )

    for entry in entries:
        matches = matched_by_entry.get(entry["id"], [])
        minimum = entry["multiplicity"]["minimum"]
        maximum = entry["multiplicity"]["maximum"]
        if len(matches) < minimum:
            blockers.append(
                f"profile entry {entry['id']} ({entry['key']}) is missing a reviewed candidate"
            )
        elif len(matches) > maximum:
            names = ", ".join(candidate["name"] for candidate in matches)
            blockers.append(
                f"profile entry {entry['id']} ({entry['key']}) is satisfied more than once: {names}"
            )

    for entry in entries:
        for other_id in entry["distinct_from"]:
            here = {
                candidate["name"] for candidate in matched_by_entry.get(entry["id"], [])
            }
            other = {
                candidate["name"] for candidate in matched_by_entry.get(other_id, [])
            }
            overlap = sorted(here & other)
            if overlap:
                blockers.append(
                    f"profile entry {entry['id']} must be a distinct deployment from entry "
                    f"{other_id}, but both resolve to: {', '.join(overlap)}"
                )
    return blockers


def audit_profile(profile_path: Path, contracts_path: Path, repo_root: Path) -> ProfileAudit:
    """Validate both artifacts and return the current production blockers."""
    profile_data = load_json(resolve_path(repo_root, profile_path))
    contracts_data = load_json(resolve_path(repo_root, contracts_path))
    entries = validate_profile_document(profile_data)
    validate_document_mirrors(entries, repo_root)
    candidates = validate_contract_config(contracts_data)
    blockers = completeness_blockers(entries, candidates)
    return ProfileAudit(len(entries), len(candidates), tuple(blockers))


def production_completeness_blockers(
    profile_path: Path, contracts_path: Path, repo_root: Path
) -> list[str]:
    """Return blockers for strict production release mode."""
    audit = audit_profile(profile_path, contracts_path, repo_root)
    return [CONCRETE_CANDIDATE_MODEL_BLOCKER, *audit.blockers]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--contracts", type=Path, default=DEFAULT_CONTRACTS)
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help=(
            "Fail unless an instance-aware concrete deployment candidate exists and "
            "satisfies every profile entry; the v1 implementation catalog can never pass."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        audit = audit_profile(args.profile, args.contracts, args.repo_root.resolve())
        if args.require_complete:
            production_blockers = [CONCRETE_CANDIDATE_MODEL_BLOCKER, *audit.blockers]
            details = "\n".join(f"- {blocker}" for blocker in production_blockers)
            raise GenesisProfileError(f"production genesis candidate is incomplete:\n{details}")
    except GenesisProfileError as exc:
        print(f"genesis deployment profile check failed: {exc}", file=sys.stderr)
        return 1

    if audit.blockers:
        print(
            "genesis deployment profile is structurally valid: "
            f"{audit.entry_count} derived entries; implementation catalog has "
            f"{len(audit.blockers)} catalog blocker(s); production also requires an "
            "instance-aware concrete deployment candidate"
        )
    else:
        print(
            "genesis deployment profile is structurally valid and catalog declarations "
            f"cover {audit.entry_count} derived entries across {audit.candidate_count} "
            "candidates; production remains blocked until an instance-aware concrete "
            "deployment candidate is available"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
