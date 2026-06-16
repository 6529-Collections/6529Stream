#!/usr/bin/env python3
"""Generate a deterministic report of the release contract protocol surface."""

from __future__ import annotations

import argparse
import filecmp
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

import generate_release_artifacts as release_artifacts


PROTOCOL_SURFACE_SCHEMA = "6529stream.protocol-surface-report.v1"
GENERATOR_VERSION = "1"
DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_OUT = Path("out")
DEFAULT_OUTPUT = Path("release-artifacts/latest/protocol-surface-report.json")


class ProtocolSurfaceError(RuntimeError):
    pass


def parameter_metadata(
    parameters: list[dict[str, Any]],
    *,
    include_indexed: bool = False,
) -> list[dict[str, Any]]:
    normalized = []
    for index, parameter in enumerate(parameters):
        item = {
            "index": index,
            "name": parameter.get("name", ""),
            "type": release_artifacts.canonical_type(parameter),
            "internal_type": parameter.get("internalType", ""),
        }
        if include_indexed:
            item["indexed"] = bool(parameter.get("indexed", False))
        normalized.append(item)
    return normalized


def normalized_selector(selector: str, signature: str) -> str:
    value = selector.lower()
    if value.startswith("0x"):
        value = value[2:]
    if len(value) != 8:
        raise ProtocolSurfaceError(f"invalid selector for {signature}: {selector}")
    try:
        int(value, 16)
    except ValueError as exc:
        raise ProtocolSurfaceError(f"invalid selector for {signature}: {selector}") from exc
    return f"0x{value}"


def error_selector(cast_bin: str, signature: str) -> str:
    selector = release_artifacts.run_cast(cast_bin, ["sig", signature])
    return normalized_selector(selector, signature)


def function_surface(artifact: dict[str, Any], abi: list[dict[str, Any]]) -> list[dict[str, Any]]:
    method_identifiers = artifact.get("methodIdentifiers", {})
    if not isinstance(method_identifiers, dict):
        raise ProtocolSurfaceError("artifact methodIdentifiers must be an object")

    functions = []
    for entry in abi:
        if entry.get("type") != "function":
            continue
        signature = release_artifacts.abi_signature(entry)
        selector = method_identifiers.get(signature)
        if selector is None:
            raise ProtocolSurfaceError(f"missing method identifier for {signature}")
        state_mutability = entry.get("stateMutability", "nonpayable")
        payable = state_mutability == "payable"
        posture = "read" if state_mutability in {"pure", "view"} else "write"
        functions.append(
            {
                "name": entry["name"],
                "signature": signature,
                "selector": normalized_selector(str(selector), signature),
                "state_mutability": state_mutability,
                "posture": posture,
                "payable": payable,
                "inputs": parameter_metadata(entry.get("inputs", [])),
                "outputs": parameter_metadata(entry.get("outputs", [])),
            }
        )
    return sorted(functions, key=lambda item: item["signature"])


def event_surface(abi: list[dict[str, Any]], cast_bin: str) -> list[dict[str, Any]]:
    events = []
    for entry in abi:
        if entry.get("type") != "event":
            continue
        signature = release_artifacts.abi_signature(entry)
        anonymous = bool(entry.get("anonymous", False))
        events.append(
            {
                "name": entry["name"],
                "signature": signature,
                "topic0": release_artifacts.event_topic(cast_bin, signature, anonymous),
                "anonymous": anonymous,
                "inputs": parameter_metadata(
                    entry.get("inputs", []),
                    include_indexed=True,
                ),
            }
        )
    return sorted(events, key=lambda item: item["signature"])


def error_surface(abi: list[dict[str, Any]], cast_bin: str) -> list[dict[str, Any]]:
    errors = []
    for entry in abi:
        if entry.get("type") != "error":
            continue
        signature = release_artifacts.abi_signature(entry)
        errors.append(
            {
                "name": entry["name"],
                "signature": signature,
                "selector": error_selector(cast_bin, signature),
                "inputs": parameter_metadata(entry.get("inputs", [])),
            }
        )
    return sorted(errors, key=lambda item: item["signature"])


def contract_surface(
    summary: dict[str, Any],
    cast_bin: str,
) -> dict[str, Any]:
    functions = function_surface(summary["artifact"], summary["abi"])
    events = event_surface(summary["abi"], cast_bin)
    errors = error_surface(summary["abi"], cast_bin)
    read_functions = [item for item in functions if item["posture"] == "read"]
    write_functions = [item for item in functions if item["posture"] == "write"]
    payable_functions = [item for item in functions if item["payable"]]
    return {
        "source": summary["source"],
        "artifact_path": summary["artifact_path"],
        "abi_sha256": summary["abi_sha256"],
        "bytecode_sha256": summary["bytecode_hash"]["sha256"],
        "deployed_bytecode_sha256": summary["deployed_bytecode_hash"]["sha256"],
        "deployed_bytecode_size_bytes": summary["deployed_bytecode_hash"]["size_bytes"],
        "summary": {
            "function_count": len(functions),
            "read_function_count": len(read_functions),
            "write_function_count": len(write_functions),
            "payable_function_count": len(payable_functions),
            "event_count": len(events),
            "custom_error_count": len(errors),
        },
        "functions": functions,
        "events": events,
        "custom_errors": errors,
    }


def build_report(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    cast_bin: str,
) -> dict[str, Any]:
    config = release_artifacts.load_json(config_path)
    contracts = config.get("production_contracts", [])
    if not contracts:
        raise ProtocolSurfaceError("config production_contracts list is empty")

    summaries = [
        release_artifacts.artifact_summary(entry, foundry_out, repo_root)
        for entry in sorted(contracts, key=lambda item: item["name"])
    ]

    contract_reports: dict[str, Any] = {}
    total_functions = 0
    total_read_functions = 0
    total_write_functions = 0
    total_payable_functions = 0
    total_events = 0
    total_custom_errors = 0

    for summary in summaries:
        surface = contract_surface(summary, cast_bin)
        stats = surface["summary"]
        total_functions += stats["function_count"]
        total_read_functions += stats["read_function_count"]
        total_write_functions += stats["write_function_count"]
        total_payable_functions += stats["payable_function_count"]
        total_events += stats["event_count"]
        total_custom_errors += stats["custom_error_count"]
        contract_reports[summary["name"]] = surface

    return {
        "schema_version": PROTOCOL_SURFACE_SCHEMA,
        "generated_by": f"scripts/generate_protocol_surface_report.py:{GENERATOR_VERSION}",
        "source": {
            "config": release_artifacts.normalize_artifact_path(config_path, repo_root),
            "foundry_out": release_artifacts.normalize_artifact_path(foundry_out, repo_root),
            "contract_set": "production_contracts",
        },
        "summary": {
            "contract_count": len(contract_reports),
            "function_count": total_functions,
            "read_function_count": total_read_functions,
            "write_function_count": total_write_functions,
            "payable_function_count": total_payable_functions,
            "event_count": total_events,
            "custom_error_count": total_custom_errors,
        },
        "contracts": contract_reports,
    }


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        handle.write("\n")


def generate_report(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    output_path: Path,
    cast_bin: str,
) -> Path:
    report = build_report(repo_root, config_path, foundry_out, cast_bin)
    write_json(output_path, report)
    return output_path


def check_report(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    output_path: Path,
    cast_bin: str,
) -> int:
    if not output_path.exists():
        print(
            f"{output_path} is missing; run `python scripts/generate_protocol_surface_report.py` "
            "after `forge build` to refresh it.",
            file=sys.stderr,
        )
        return 1

    with tempfile.TemporaryDirectory() as temp_dir:
        generated = Path(temp_dir) / output_path.name
        generate_report(repo_root, config_path, foundry_out, generated, cast_bin)
        if not filecmp.cmp(generated, output_path, shallow=False):
            print(
                f"{output_path} is out of date; run "
                "`python scripts/generate_protocol_surface_report.py` after `forge build`.",
                file=sys.stderr,
            )
            return 1

    print(f"{output_path} is up to date")
    return 0


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate or check the deterministic protocol surface report."
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--cast-bin", default="cast")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    config_path = args.config if args.config.is_absolute() else repo_root / args.config
    foundry_out = (
        args.foundry_out
        if args.foundry_out.is_absolute()
        else repo_root / args.foundry_out
    )
    output_path = args.output if args.output.is_absolute() else repo_root / args.output

    try:
        if args.check:
            return check_report(repo_root, config_path, foundry_out, output_path, args.cast_bin)
        written = generate_report(repo_root, config_path, foundry_out, output_path, args.cast_bin)
    except (ProtocolSurfaceError, release_artifacts.ArtifactError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(release_artifacts.normalize_artifact_path(written, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
