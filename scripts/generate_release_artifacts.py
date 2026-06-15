#!/usr/bin/env python3
"""Generate deterministic release metadata from Foundry artifacts."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any


ABI_CHECKSUM_SCHEMA = "6529stream.abi-checksums.v1"
EVENT_CATALOG_SCHEMA = "6529stream.event-topic-catalog.v1"
INTERFACE_ID_SCHEMA = "6529stream.interface-ids.v1"
MANIFEST_SCHEMA = "6529stream.release-artifact-manifest.v1"
GENERATOR_VERSION = "1"
DEFAULT_EIP_170_RUNTIME_LIMIT_BYTES = 24_576
DOWNSTREAM_RELEASE_FILES = {
    "bytecode-release-proof.json",
    "dependency-artifact-manifest.json",
    "one-of-one-permanence-manifest.json",
    "one-of-one-provenance-manifest.json",
    "production-release-blockers.md",
    "public-beta-blockers.md",
    "public-beta-evidence.json",
    "release-evidence-issue-backlog.json",
    "release-evidence-issue-backlog.md",
    "release-evidence-issue-body-sync.json",
    "release-evidence-issue-body-sync.md",
    "release-evidence-issue-links.json",
    "release-evidence-live-audit-report-archive.json",
    "release-evidence-live-audit-report-archive.md",
    "release-evidence-packet-index.json",
    "release-evidence-packet-index.md",
    "SHA256SUMS",
    "release-checksums.json",
    "release-manifest.json",
    "risk-register.json",
    "source-verification-inputs.json",
}

DEFAULT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_OUT = Path("out")
DEFAULT_OUTPUT_DIR = Path("release-artifacts/latest")
HEX_RE = re.compile(r"^[0-9a-fA-F]*$")
SOLIDITY_LINK_PLACEHOLDER_RE = re.compile(r"__\$[0-9a-fA-F]{34}\$__")


class ArtifactError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ArtifactError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ArtifactError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_json(value: Any) -> str:
    return sha256_bytes(canonical_json_bytes(value))


def bytecode_hash(value: str) -> dict[str, Any]:
    if value.startswith("0x"):
        hex_value = value[2:]
    else:
        hex_value = value
    linked_equivalent = SOLIDITY_LINK_PLACEHOLDER_RE.sub("0" * 40, hex_value)
    if hex_value == "":
        return {
            "sha256": sha256_bytes(b""),
            "linked": True,
            "hash_mode": "bytes",
            "size_bytes": 0,
        }
    try:
        bytecode = bytes.fromhex(linked_equivalent)
        if not HEX_RE.fullmatch(linked_equivalent):
            raise ValueError("invalid linked-equivalent bytecode")
        linked = linked_equivalent == hex_value
        return {
            "sha256": sha256_bytes(bytecode) if linked else sha256_bytes(value.encode("utf-8")),
            "linked": linked,
            "hash_mode": "bytes" if linked else "unlinked_artifact_object",
            "size_bytes": len(bytecode),
        }
    except ValueError:
        return {
            "sha256": sha256_bytes(value.encode("utf-8")),
            "linked": False,
            "hash_mode": "unlinked_artifact_object",
            "size_bytes": None,
        }


def find_artifact(foundry_out: Path, name: str, source: str | None) -> Path:
    if source:
        direct = foundry_out / Path(source).name / f"{name}.json"
        if direct.exists():
            return direct

    matches = sorted(foundry_out.glob(f"**/{name}.json"))
    if not matches:
        raise ArtifactError(f"could not find Foundry artifact for {name} under {foundry_out}")
    if len(matches) > 1:
        locations = ", ".join(str(match) for match in matches)
        raise ArtifactError(f"ambiguous Foundry artifact for {name}: {locations}")
    return matches[0]


def normalize_artifact_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def canonical_type(parameter: dict[str, Any]) -> str:
    parameter_type = parameter["type"]
    if parameter_type.startswith("tuple"):
        suffix = parameter_type[len("tuple") :]
        components = parameter.get("components", [])
        component_types = ",".join(canonical_type(component) for component in components)
        return f"({component_types}){suffix}"
    return parameter_type


def abi_signature(entry: dict[str, Any]) -> str:
    inputs = ",".join(canonical_type(parameter) for parameter in entry.get("inputs", []))
    return f"{entry['name']}({inputs})"


def resolve_cast_binary(cast_bin: str) -> str:
    configured = Path(cast_bin)
    if configured.exists():
        return str(configured)

    resolved = shutil.which(cast_bin)
    if resolved:
        return resolved

    foundry_bin = Path.home() / ".foundry" / "bin"
    candidates = [foundry_bin / cast_bin]
    if not cast_bin.lower().endswith(".exe"):
        candidates.append(foundry_bin / f"{cast_bin}.exe")
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)

    return cast_bin


def run_cast(cast_bin: str, args: list[str]) -> str:
    cast_command = resolve_cast_binary(cast_bin)
    try:
        result = subprocess.run(
            [cast_command, *args],
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise ArtifactError(
            f"{cast_bin!r} was not found. Install Foundry and ensure cast is on PATH."
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip()
        raise ArtifactError(f"cast {' '.join(args)} failed: {stderr}") from exc
    return result.stdout.strip()


def event_topic(cast_bin: str, signature: str, anonymous: bool) -> str | None:
    if anonymous:
        return None
    topic = run_cast(cast_bin, ["sig-event", signature])
    if not topic.startswith("0x") or len(topic) != 66:
        raise ArtifactError(f"cast returned an invalid event topic for {signature}: {topic}")
    return topic.lower()


def input_metadata(inputs: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized = []
    for index, parameter in enumerate(inputs):
        normalized.append(
            {
                "index": index,
                "name": parameter.get("name", ""),
                "type": canonical_type(parameter),
                "indexed": bool(parameter.get("indexed", False)),
                "internal_type": parameter.get("internalType", ""),
            }
        )
    return normalized


def function_selectors(artifact: dict[str, Any], abi: list[dict[str, Any]]) -> list[dict[str, str]]:
    method_identifiers = artifact.get("methodIdentifiers", {})
    selectors = []
    for entry in abi:
        if entry.get("type") != "function":
            continue
        signature = abi_signature(entry)
        selector = method_identifiers.get(signature)
        if not selector:
            raise ArtifactError(f"missing method identifier for {signature}")
        selectors.append({"signature": signature, "selector": "0x" + selector.lower()})
    return sorted(selectors, key=lambda item: item["signature"])


def xor_selectors(selectors: list[dict[str, str]]) -> str:
    interface_id = 0
    for selector in selectors:
        interface_id ^= int(selector["selector"], 16)
    return f"0x{interface_id:08x}"


def normalize_interface_id(interface_id: str) -> str:
    value = interface_id.lower()
    if not value.startswith("0x"):
        value = "0x" + value
    if len(value) != 10:
        raise ArtifactError(f"invalid interface ID: {interface_id}")
    int(value, 16)
    return value


def artifact_summary(
    entry: dict[str, Any],
    foundry_out: Path,
    repo_root: Path,
) -> dict[str, Any]:
    name = entry["name"]
    source = entry.get("source")
    artifact_path = find_artifact(foundry_out, name, source)
    artifact = load_json(artifact_path)
    abi = artifact.get("abi")
    if not isinstance(abi, list):
        raise ArtifactError(f"artifact for {name} does not contain an ABI array")

    bytecode = artifact.get("bytecode", {}).get("object", "")
    deployed_bytecode = artifact.get("deployedBytecode", {}).get("object", "")

    return {
        "name": name,
        "source": source or "",
        "config": entry,
        "artifact_path": normalize_artifact_path(artifact_path, repo_root),
        "artifact": artifact,
        "abi": abi,
        "abi_sha256": sha256_json(abi),
        "bytecode_hash": bytecode_hash(bytecode),
        "deployed_bytecode_hash": bytecode_hash(deployed_bytecode),
    }


def build_abi_checksums(
    contract_summaries: list[dict[str, Any]],
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    eip_170_runtime_limit_bytes: int = DEFAULT_EIP_170_RUNTIME_LIMIT_BYTES,
) -> dict[str, Any]:
    contracts: dict[str, Any] = {}
    abi_hashes: dict[str, str] = {}
    bytecode_hashes: dict[str, dict[str, str]] = {}

    for summary in contract_summaries:
        abi = summary["abi"]
        functions = [entry for entry in abi if entry.get("type") == "function"]
        events = [entry for entry in abi if entry.get("type") == "event"]
        constructors = [entry for entry in abi if entry.get("type") == "constructor"]
        name = summary["name"]
        abi_hashes[name] = summary["abi_sha256"]
        bytecode_hashes[name] = {
            "creation": summary["bytecode_hash"],
            "runtime": summary["deployed_bytecode_hash"],
        }
        runtime_size = summary["deployed_bytecode_hash"]["size_bytes"]
        runtime_margin = (
            None if runtime_size is None else eip_170_runtime_limit_bytes - runtime_size
        )
        contracts[name] = {
            "source": summary["source"],
            "artifact_path": summary["artifact_path"],
            "abi_sha256": summary["abi_sha256"],
            "bytecode_sha256": summary["bytecode_hash"]["sha256"],
            "bytecode_linked": summary["bytecode_hash"]["linked"],
            "bytecode_hash_mode": summary["bytecode_hash"]["hash_mode"],
            "bytecode_size_bytes": summary["bytecode_hash"]["size_bytes"],
            "deployed_bytecode_sha256": summary["deployed_bytecode_hash"]["sha256"],
            "deployed_bytecode_linked": summary["deployed_bytecode_hash"]["linked"],
            "deployed_bytecode_hash_mode": summary["deployed_bytecode_hash"]["hash_mode"],
            "deployed_bytecode_size_bytes": runtime_size,
            "eip170_runtime_limit_bytes": eip_170_runtime_limit_bytes,
            "deployed_runtime_margin_bytes": runtime_margin,
            "abi_entries": len(abi),
            "function_count": len(functions),
            "event_count": len(events),
            "constructor_count": len(constructors),
        }

    return {
        "schema_version": ABI_CHECKSUM_SCHEMA,
        "generated_by": f"scripts/generate_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_artifact_path(config_path, repo_root),
            "foundry_out": normalize_artifact_path(foundry_out, repo_root),
        },
        "abi_hashes": abi_hashes,
        "bytecode_hashes": bytecode_hashes,
        "contracts": contracts,
    }


def build_event_catalog(
    contract_summaries: list[dict[str, Any]],
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    cast_bin: str,
) -> dict[str, Any]:
    topics: dict[str, Any] = {}
    contracts: dict[str, Any] = {}

    for summary in contract_summaries:
        contract_events = []
        for entry in summary["abi"]:
            if entry.get("type") != "event":
                continue
            signature = abi_signature(entry)
            topic0 = event_topic(cast_bin, signature, bool(entry.get("anonymous", False)))
            event_record = {
                "name": entry["name"],
                "signature": signature,
                "topic0": topic0,
                "anonymous": bool(entry.get("anonymous", False)),
                "inputs": input_metadata(entry.get("inputs", [])),
            }
            contract_events.append(event_record)

            topic_key = topic0 if topic0 is not None else f"anonymous:{signature}"
            topic_record = topics.setdefault(
                topic_key,
                {
                    "topic0": topic0,
                    "signature": signature,
                    "name": entry["name"],
                    "anonymous": bool(entry.get("anonymous", False)),
                    "inputs": event_record["inputs"],
                    "emitted_by": [],
                },
            )
            if summary["name"] not in topic_record["emitted_by"]:
                topic_record["emitted_by"].append(summary["name"])

        contracts[summary["name"]] = {
            "source": summary["source"],
            "artifact_path": summary["artifact_path"],
            "events": sorted(contract_events, key=lambda item: item["signature"]),
        }

    sorted_topics = sorted(
        topics.values(),
        key=lambda item: (item["topic0"] or "", item["signature"]),
    )
    for topic in sorted_topics:
        topic["emitted_by"] = sorted(topic["emitted_by"])

    return {
        "schema_version": EVENT_CATALOG_SCHEMA,
        "generated_by": f"scripts/generate_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_artifact_path(config_path, repo_root),
            "foundry_out": normalize_artifact_path(foundry_out, repo_root),
        },
        "topics": sorted_topics,
        "contracts": contracts,
    }


def build_interface_ids(
    interface_summaries: list[dict[str, Any]],
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
) -> dict[str, Any]:
    interfaces: dict[str, Any] = {}
    interface_ids: dict[str, str] = {}

    for summary in interface_summaries:
        selectors = function_selectors(summary["artifact"], summary["abi"])
        computed_interface_id = xor_selectors(selectors)
        configured_interface_id = summary["config"].get("interface_id")
        if configured_interface_id:
            interface_id = normalize_interface_id(configured_interface_id)
            interface_id_source = "configured"
        else:
            interface_id = computed_interface_id
            interface_id_source = "selector_xor"
        name = summary["name"]
        interface_ids[name] = interface_id
        interfaces[name] = {
            "source": summary["source"],
            "artifact_path": summary["artifact_path"],
            "abi_sha256": summary["abi_sha256"],
            "interface_id": interface_id,
            "interface_id_source": interface_id_source,
            "computed_selector_xor": computed_interface_id,
            "function_selectors": selectors,
        }

    return {
        "schema_version": INTERFACE_ID_SCHEMA,
        "generated_by": f"scripts/generate_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_artifact_path(config_path, repo_root),
            "foundry_out": normalize_artifact_path(foundry_out, repo_root),
        },
        "interface_ids": interface_ids,
        "interfaces": interfaces,
    }


def artifact_file_hash(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def generate_artifacts(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    output_dir: Path,
    cast_bin: str,
) -> list[Path]:
    config = load_json(config_path)
    contracts = config.get("production_contracts", [])
    interfaces = config.get("interfaces", [])
    runtime_size_budget = config.get("runtime_size_budget", {})
    eip_170_runtime_limit_bytes = runtime_size_budget.get(
        "eip_170_runtime_limit_bytes", DEFAULT_EIP_170_RUNTIME_LIMIT_BYTES
    )
    if (
        not isinstance(eip_170_runtime_limit_bytes, int)
        or isinstance(eip_170_runtime_limit_bytes, bool)
        or eip_170_runtime_limit_bytes <= 0
    ):
        raise ArtifactError("runtime_size_budget.eip_170_runtime_limit_bytes must be positive")
    if not contracts:
        raise ArtifactError("config production_contracts list is empty")

    contract_summaries = [
        artifact_summary(entry, foundry_out, repo_root) for entry in sorted(contracts, key=lambda x: x["name"])
    ]
    interface_summaries = [
        artifact_summary(entry, foundry_out, repo_root) for entry in sorted(interfaces, key=lambda x: x["name"])
    ]

    files = {
        "abi-checksums.json": build_abi_checksums(
            contract_summaries,
            repo_root,
            config_path,
            foundry_out,
            eip_170_runtime_limit_bytes,
        ),
        "event-topic-catalog.json": build_event_catalog(
            contract_summaries, repo_root, config_path, foundry_out, cast_bin
        ),
        "interface-ids.json": build_interface_ids(
            interface_summaries, repo_root, config_path, foundry_out
        ),
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for file_name, data in sorted(files.items()):
        path = output_dir / file_name
        write_json(path, data)
        written.append(path)

    manifest = {
        "schema_version": MANIFEST_SCHEMA,
        "generated_by": f"scripts/generate_release_artifacts.py:{GENERATOR_VERSION}",
        "source": {
            "config": normalize_artifact_path(config_path, repo_root),
            "foundry_out": normalize_artifact_path(foundry_out, repo_root),
        },
        "artifacts": {
            path.name: {
                "path": path.name,
                "sha256": artifact_file_hash(path),
            }
            for path in written
        },
    }
    manifest_path = output_dir / "release-artifact-manifest.json"
    write_json(manifest_path, manifest)
    written.append(manifest_path)
    return written


def generated_files(root: Path) -> list[Path]:
    return sorted(
        path.relative_to(root)
        for path in root.rglob("*")
        if path.is_file() and path.name not in DOWNSTREAM_RELEASE_FILES
    )


def compare_directories(expected: Path, actual: Path) -> list[str]:
    mismatches: list[str] = []
    expected_files = generated_files(expected)
    actual_files = generated_files(actual)

    missing = sorted(set(expected_files) - set(actual_files))
    extra = sorted(set(actual_files) - set(expected_files))
    mismatches.extend(f"missing {path.as_posix()}" for path in missing)
    mismatches.extend(f"unexpected {path.as_posix()}" for path in extra)

    for relative_path in sorted(set(expected_files) & set(actual_files)):
        if not filecmp.cmp(expected / relative_path, actual / relative_path, shallow=False):
            mismatches.append(f"changed {relative_path.as_posix()}")
    return mismatches


def check_artifacts(
    repo_root: Path,
    config_path: Path,
    foundry_out: Path,
    output_dir: Path,
    cast_bin: str,
) -> int:
    with tempfile.TemporaryDirectory() as temp_dir:
        generated_dir = Path(temp_dir) / "release-artifacts"
        generate_artifacts(repo_root, config_path, foundry_out, generated_dir, cast_bin)
        mismatches = compare_directories(generated_dir, output_dir)
        if mismatches:
            print("release artifacts are out of date:", file=sys.stderr)
            for mismatch in mismatches:
                print(f"  - {mismatch}", file=sys.stderr)
            print(
                "run `python scripts/generate_release_artifacts.py` after `forge build` "
                "and commit the regenerated JSON",
                file=sys.stderr,
            )
            return 1
    print("release artifacts are current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--cast-bin", default="cast")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    config_path = args.config
    foundry_out = args.foundry_out
    output_dir = args.output_dir

    try:
        if args.check:
            return check_artifacts(repo_root, config_path, foundry_out, output_dir, args.cast_bin)
        written = generate_artifacts(repo_root, config_path, foundry_out, output_dir, args.cast_bin)
    except ArtifactError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for path in written:
        print(normalize_artifact_path(path, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
