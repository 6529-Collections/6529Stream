#!/usr/bin/env python3
"""Generate and check the committed ABI compatibility baseline."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path
from typing import Any

import generate_release_artifacts as release_artifacts


ABI_SURFACE_SCHEMA = "6529stream.abi-surface-baseline.v2"
GENERATOR_VERSION = "2"

DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_OUT = Path("out")
DEFAULT_BASELINE = Path("release-artifacts/baselines/v0.1.0/abi-surface.json")

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
    config = release_artifacts.load_json(config_path)
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
    baseline = release_artifacts.load_json(path)
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
            {
                "type": removed_subject_type,
                "surface": surface,
                "contract": subject,
                "subject": subject,
                "message": f"{subject_kind} {subject} is missing from current surface",
            }
        )

    for subject in sorted(current_names - baseline_names):
        additive.append(
            {
                "type": added_subject_type,
                "surface": surface,
                "contract": subject,
                "subject": subject,
                "message": f"{subject_kind} {subject} was added to current surface",
            }
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
                    {
                        "type": "removed_entry",
                        "surface": surface,
                        "contract": subject,
                        "subject": subject,
                        "category": category,
                        "key": key,
                        "message": f"{subject} removed {category} entry {key}",
                    }
                )

            for key in sorted(current_keys - baseline_keys):
                additive.append(
                    {
                        "type": "added_entry",
                        "surface": surface,
                        "contract": subject,
                        "subject": subject,
                        "category": category,
                        "key": key,
                        "message": f"{subject} added {category} entry {key}",
                    }
                )

            for key in sorted(baseline_keys & current_keys):
                if baseline_map[key] != current_map[key]:
                    incompatible.append(
                        {
                            "type": "changed_entry",
                            "surface": surface,
                            "contract": subject,
                            "subject": subject,
                            "category": category,
                            "key": key,
                            "message": f"{subject} changed {category} entry {key}",
                            "baseline": baseline_map[key],
                            "current": current_map[key],
                        }
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
) -> int:
    baseline = load_baseline(baseline_path)
    current = build_abi_surface(repo_root, config_path, foundry_out)
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
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_compatibility(
                repo_root,
                args.config,
                args.foundry_out,
                args.baseline,
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
