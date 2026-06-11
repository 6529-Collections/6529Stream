#!/usr/bin/env python3
"""Generate deterministic source-verification inputs from Foundry artifacts."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover - Python 3.10 fallback.
    tomllib = None  # type: ignore[assignment]


SOURCE_VERIFICATION_SCHEMA = "6529stream.source-verification-inputs.v1"
GENERATOR_VERSION = "1"

DEFAULT_CONTRACT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_FOUNDRY_CONFIG = Path("foundry.toml")
DEFAULT_FOUNDRY_OUT = Path("out")
DEFAULT_ABI_CHECKSUMS = Path("release-artifacts/latest/abi-checksums.json")
DEFAULT_OUTPUT = Path("release-artifacts/latest/source-verification-inputs.json")
PRODUCTION_BUILD_COMMAND = "forge build --sizes --via-ir --skip test --skip script --force"


class SourceVerificationError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise SourceVerificationError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SourceVerificationError(f"invalid JSON in {path}: {exc}") from exc


def json_text(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode(
        "utf-8"
    )


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_json(value: Any) -> str:
    return sha256_bytes(canonical_json_bytes(value))


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def bytecode_hash(value: str) -> dict[str, Any]:
    hex_value = value[2:] if value.startswith("0x") else value
    if hex_value == "":
        return {"sha256": sha256_bytes(b""), "linked": True, "hash_mode": "bytes"}
    try:
        return {
            "sha256": sha256_bytes(bytes.fromhex(hex_value)),
            "linked": True,
            "hash_mode": "bytes",
        }
    except ValueError:
        return {
            "sha256": sha256_bytes(value.encode("utf-8")),
            "linked": False,
            "hash_mode": "unlinked_artifact_object",
        }


def parse_scalar(value: str) -> Any:
    value = value.strip()
    if value in {"true", "false"}:
        return value == "true"
    if value.startswith('"') and value.endswith('"'):
        return value[1:-1]
    try:
        return int(value)
    except ValueError:
        return value


def load_foundry_config(path: Path) -> dict[str, Any]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise SourceVerificationError(f"missing required file: {path}") from exc

    if tomllib is not None:
        return tomllib.loads(raw.decode("utf-8"))

    parsed: dict[str, Any] = {}
    current: dict[str, Any] | None = None
    for raw_line in raw.decode("utf-8").splitlines():
        line = raw_line.split("#", 1)[0].strip()
        if not line:
            continue
        if line.startswith("[") and line.endswith("]"):
            current = parsed
            for part in line[1:-1].split("."):
                current = current.setdefault(part, {})
            continue
        if current is None or "=" not in line:
            continue
        key, value = line.split("=", 1)
        value = value.strip()
        if value.startswith("["):
            continue
        current[key.strip()] = parse_scalar(value)
    return parsed


def foundry_profile(config: dict[str, Any]) -> dict[str, Any]:
    profile = config.get("profile", {}).get("default", {})
    if not isinstance(profile, dict):
        raise SourceVerificationError("foundry.toml profile.default must be a table")
    return profile


def find_artifact(foundry_out: Path, name: str, source: str | None) -> Path:
    if source:
        direct = foundry_out / Path(source).name / f"{name}.json"
        if direct.exists():
            return direct

    matches = sorted(foundry_out.glob(f"**/{name}.json"))
    if not matches:
        raise SourceVerificationError(
            f"could not find Foundry artifact for {name} under {foundry_out}"
        )
    if len(matches) > 1:
        locations = ", ".join(str(match) for match in matches)
        raise SourceVerificationError(f"ambiguous Foundry artifact for {name}: {locations}")
    return matches[0]


def artifact_metadata(artifact: dict[str, Any], name: str) -> dict[str, Any]:
    metadata = artifact.get("metadata")
    if isinstance(metadata, dict):
        return metadata
    if isinstance(metadata, str):
        try:
            value = json.loads(metadata)
        except json.JSONDecodeError as exc:
            raise SourceVerificationError(f"invalid metadata JSON for {name}: {exc}") from exc
        if isinstance(value, dict):
            return value
    raise SourceVerificationError(f"artifact for {name} does not contain metadata")


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise SourceVerificationError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise SourceVerificationError(f"{path} must be an array")
    return value


def constructor_abi(abi: list[dict[str, Any]]) -> dict[str, Any]:
    constructors = [entry for entry in abi if entry.get("type") == "constructor"]
    if not constructors:
        return {
            "present": False,
            "state_mutability": "not_applicable",
            "inputs": [],
        }
    if len(constructors) > 1:
        raise SourceVerificationError("ABI contains more than one constructor")

    constructor = constructors[0]
    inputs = []
    for index, parameter in enumerate(constructor.get("inputs", [])):
        inputs.append(
            {
                "index": index,
                "name": parameter.get("name", ""),
                "type": parameter.get("type", ""),
                "internal_type": parameter.get("internalType", ""),
            }
        )
    return {
        "present": True,
        "state_mutability": constructor.get("stateMutability", ""),
        "inputs": inputs,
    }


def normalize_link_references(value: Any) -> list[dict[str, Any]]:
    if not value:
        return []
    references = require_dict(value, "linkReferences")
    normalized = []
    for source_path, libraries in sorted(references.items()):
        library_map = require_dict(libraries, f"linkReferences.{source_path}")
        for library_name, offsets in sorted(library_map.items()):
            normalized_offsets = []
            for offset in require_list(offsets, f"linkReferences.{source_path}.{library_name}"):
                offset_map = require_dict(offset, "link offset")
                normalized_offsets.append(
                    {
                        "start": offset_map.get("start"),
                        "length": offset_map.get("length"),
                    }
                )
            normalized.append(
                {
                    "source": source_path,
                    "library": library_name,
                    "positions": normalized_offsets,
                }
            )
    return normalized


def library_template(references: list[dict[str, Any]]) -> str:
    if not references:
        return ""
    libraries = [
        f"{reference['source']}:{reference['library']}:<library-address>"
        for reference in references
    ]
    return " --libraries " + ",".join(libraries)


def unique_library_references(
    creation_links: list[dict[str, Any]],
    runtime_links: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    references_by_library: dict[tuple[str, str], dict[str, Any]] = {}
    for reference in creation_links + runtime_links:
        key = (reference["source"], reference["library"])
        references_by_library.setdefault(key, reference)
    return [references_by_library[key] for key in sorted(references_by_library)]


def verification_command_template(
    source: str,
    name: str,
    compiler_version: str,
    optimizer_runs: int | None,
    via_ir: bool,
    constructor: dict[str, Any],
    link_references: list[dict[str, Any]],
) -> str:
    optimizer_option = (
        f" --num-of-optimizations {optimizer_runs}" if optimizer_runs is not None else ""
    )
    via_ir_option = " --via-ir" if via_ir else ""
    constructor_option = (
        " --constructor-args <encoded-constructor-args>" if constructor["present"] else ""
    )
    return (
        "forge verify-contract"
        " --chain-id <chain-id>"
        f" --compiler-version v{compiler_version}"
        f"{optimizer_option}"
        f"{via_ir_option}"
        " --watch"
        " <deployed-address>"
        f" {source}:{name}"
        f"{constructor_option}"
        f"{library_template(link_references)}"
    )


def source_record(
    repo_root: Path,
    source_path: str,
    metadata_source: dict[str, Any],
    used_by: list[str],
) -> dict[str, Any]:
    path = repo_root / source_path
    if not path.is_file():
        raise SourceVerificationError(f"metadata source file is missing: {source_path}")
    return {
        "path": source_path,
        "sha256": file_sha256(path),
        "solc_keccak256": metadata_source.get("keccak256", ""),
        "license": metadata_source.get("license", ""),
        "used_by": sorted(set(used_by)),
    }


def collect_source_usage(contract_records: list[dict[str, Any]]) -> dict[str, list[str]]:
    usage: dict[str, list[str]] = {}
    for record in contract_records:
        for source_path in record["metadata_sources"]:
            usage.setdefault(source_path, []).append(record["name"])
    return usage


def artifact_record(
    entry: dict[str, Any],
    repo_root: Path,
    foundry_out: Path,
    abi_checksums: dict[str, Any],
) -> dict[str, Any]:
    name = entry["name"]
    source = entry.get("source", "")
    artifact_path = find_artifact(foundry_out, name, source)
    artifact = require_dict(load_json(artifact_path), str(artifact_path))
    abi = require_list(artifact.get("abi"), f"{artifact_path}.abi")
    metadata = artifact_metadata(artifact, name)

    metadata_sources = require_dict(metadata.get("sources"), f"{name}.metadata.sources")
    settings = require_dict(metadata.get("settings"), f"{name}.metadata.settings")
    compiler = require_dict(metadata.get("compiler"), f"{name}.metadata.compiler")
    compiler_version = compiler.get("version")
    if not isinstance(compiler_version, str) or compiler_version == "":
        raise SourceVerificationError(f"{name} metadata compiler version is missing")

    compilation_target = require_dict(
        settings.get("compilationTarget"),
        f"{name}.metadata.settings.compilationTarget",
    )
    if source not in compilation_target or compilation_target.get(source) != name:
        raise SourceVerificationError(
            f"{name} metadata compilation target does not match {source}:{name}"
        )
    primary_metadata_source = require_dict(
        metadata_sources.get(source),
        f"{name}.metadata.sources.{source}",
    )
    if not (repo_root / source).is_file():
        raise SourceVerificationError(f"source file is missing for {name}: {source}")

    checksum_contracts = require_dict(abi_checksums.get("contracts"), "abi-checksums.contracts")
    checksum_entry = require_dict(
        checksum_contracts.get(name),
        f"abi-checksums.contracts.{name}",
    )
    normalized_artifact_path = normalize_path(artifact_path, repo_root)
    if checksum_entry.get("source") != source:
        raise SourceVerificationError(f"ABI checksum source mismatch for {name}")
    if checksum_entry.get("artifact_path") != normalized_artifact_path:
        raise SourceVerificationError(f"ABI checksum artifact path mismatch for {name}")

    abi_sha256 = sha256_json(abi)
    if checksum_entry.get("abi_sha256") != abi_sha256:
        raise SourceVerificationError(f"ABI checksum mismatch for {name}")

    creation_hash = bytecode_hash(artifact.get("bytecode", {}).get("object", ""))
    runtime_hash = bytecode_hash(artifact.get("deployedBytecode", {}).get("object", ""))
    if checksum_entry.get("bytecode_sha256") != creation_hash["sha256"]:
        raise SourceVerificationError(f"creation bytecode checksum mismatch for {name}")
    if checksum_entry.get("deployed_bytecode_sha256") != runtime_hash["sha256"]:
        raise SourceVerificationError(f"runtime bytecode checksum mismatch for {name}")

    optimizer = require_dict(settings.get("optimizer"), f"{name}.metadata.settings.optimizer")
    constructor = constructor_abi([entry for entry in abi if isinstance(entry, dict)])
    creation_links = normalize_link_references(artifact.get("bytecode", {}).get("linkReferences"))
    runtime_links = normalize_link_references(
        artifact.get("deployedBytecode", {}).get("linkReferences")
    )
    verification_links = unique_library_references(creation_links, runtime_links)
    optimizer_runs = optimizer.get("runs")
    if not isinstance(optimizer_runs, int):
        optimizer_runs = None

    return {
        "name": name,
        "source": source,
        "metadata_sources": sorted(str(path) for path in metadata_sources),
        "contract": {
            "source": source,
            "source_sha256": file_sha256(repo_root / source),
            "source_solc_keccak256": primary_metadata_source.get("keccak256", ""),
            "artifact_path": normalized_artifact_path,
            "artifact_sha256": file_sha256(artifact_path),
            "compilation_target": f"{source}:{name}",
            "compiler_version": compiler_version,
            "language": metadata.get("language", "Solidity"),
            "settings": {
                "evm_version": settings.get("evmVersion", ""),
                "optimizer": {
                    "enabled": bool(optimizer.get("enabled", False)),
                    "runs": optimizer_runs,
                },
                "via_ir": bool(settings.get("viaIR", False)),
                "metadata_bytecode_hash": require_dict(
                    settings.get("metadata"), f"{name}.metadata.settings.metadata"
                ).get("bytecodeHash", ""),
                "libraries": settings.get("libraries", {}),
            },
            "abi_sha256": abi_sha256,
            "bytecode_hashes": {
                "creation": {
                    **creation_hash,
                    "release_artifact_sha256": checksum_entry.get("bytecode_sha256"),
                },
                "runtime": {
                    **runtime_hash,
                    "release_artifact_sha256": checksum_entry.get(
                        "deployed_bytecode_sha256"
                    ),
                },
            },
            "constructor": constructor,
            "constructor_args": {
                "status": "retained_per_deployment_manifest",
                "deployment_manifest_dir": "deployments/examples",
                "encoded_args": "not_available_until_broadcast",
            },
            "library_linking": {
                "requires_linking": bool(creation_links or runtime_links),
                "creation_link_references": creation_links,
                "runtime_link_references": runtime_links,
            },
            "verification": {
                "live_status": "not_available_until_broadcast",
                "template": verification_command_template(
                    source,
                    name,
                    compiler_version,
                    optimizer_runs,
                    bool(settings.get("viaIR", False)),
                    constructor,
                    verification_links,
                ),
            },
        },
    }


def sorted_unique(values: list[Any]) -> list[Any]:
    return sorted({value for value in values if value not in {None, ""}})


def build_manifest(
    repo_root: Path,
    output_path: Path,
    contract_config_path: Path,
    foundry_config_path: Path,
    foundry_out: Path,
    abi_checksums_path: Path,
) -> dict[str, Any]:
    contract_config = require_dict(load_json(contract_config_path), str(contract_config_path))
    abi_checksums = require_dict(load_json(abi_checksums_path), str(abi_checksums_path))
    foundry = load_foundry_config(foundry_config_path)
    profile = foundry_profile(foundry)

    contracts = require_list(
        contract_config.get("production_contracts"),
        "release-artifacts/contracts.json.production_contracts",
    )
    if not contracts:
        raise SourceVerificationError("production_contracts list is empty")

    artifact_records = [
        artifact_record(entry, repo_root, foundry_out, abi_checksums)
        for entry in sorted(contracts, key=lambda item: item["name"])
    ]
    source_usage = collect_source_usage(artifact_records)

    metadata_sources: dict[str, dict[str, Any]] = {}
    for record in artifact_records:
        artifact = load_json(repo_root / record["contract"]["artifact_path"])
        metadata = artifact_metadata(
            require_dict(artifact, record["contract"]["artifact_path"]),
            record["name"],
        )
        for source_path, metadata_source in require_dict(
            metadata.get("sources"),
            "sources",
        ).items():
            metadata_sources[source_path] = require_dict(metadata_source, f"sources.{source_path}")

    contract_map = {record["name"]: record["contract"] for record in artifact_records}
    compiler_versions = sorted_unique(
        [record["compiler_version"] for record in contract_map.values()]
    )
    evm_versions = sorted_unique(
        [record["settings"]["evm_version"] for record in contract_map.values()]
    )
    via_ir_values = sorted_unique(
        [record["settings"]["via_ir"] for record in contract_map.values()]
    )
    optimizer_values = sorted_unique(
        [record["settings"]["optimizer"]["enabled"] for record in contract_map.values()]
    )
    optimizer_runs = sorted_unique(
        [record["settings"]["optimizer"]["runs"] for record in contract_map.values()]
    )

    return {
        "schema_version": SOURCE_VERIFICATION_SCHEMA,
        "generated_by": f"scripts/generate_source_verification_inputs.py:{GENERATOR_VERSION}",
        "source": {
            "output": normalize_path(output_path, repo_root),
            "contract_config": normalize_path(contract_config_path, repo_root),
            "foundry_config": normalize_path(foundry_config_path, repo_root),
            "foundry_out": normalize_path(foundry_out, repo_root),
            "abi_checksums": normalize_path(abi_checksums_path, repo_root),
            "build_command": PRODUCTION_BUILD_COMMAND,
        },
        "toolchain": {
            "foundry_profile": "default",
            "solidity_version_pin": profile.get("solc_version", ""),
            "compiler_versions": compiler_versions,
            "evm_versions": evm_versions,
            "optimizer_enabled": optimizer_values,
            "optimizer_runs": optimizer_runs,
            "via_ir": via_ir_values,
            "foundry_config": {
                "auto_detect_solc": profile.get("auto_detect_solc"),
                "evm_version": profile.get("evm_version"),
                "optimizer": profile.get("optimizer"),
                "optimizer_runs": profile.get("optimizer_runs"),
                "out": profile.get("out"),
                "solc_version": profile.get("solc_version"),
                "src": profile.get("src"),
            },
        },
        "constructor_arguments": {
            "policy": "deployment_manifests_retain_unencoded_values",
            "deployment_manifest_dir": "deployments/examples",
            "broadcast_required_for_live_encoded_args": True,
        },
        "verification": {
            "retained_inputs_status": "generated",
            "live_explorer_status": "not_available_until_broadcast",
        },
        "source_files": {
            source_path: source_record(
                repo_root,
                source_path,
                metadata_sources[source_path],
                source_usage.get(source_path, []),
            )
            for source_path in sorted(metadata_sources)
        },
        "contracts": contract_map,
    }


def build_output_text(
    repo_root: Path,
    output_path: Path,
    contract_config_path: Path,
    foundry_config_path: Path,
    foundry_out: Path,
    abi_checksums_path: Path,
) -> str:
    manifest = build_manifest(
        repo_root,
        output_path,
        contract_config_path,
        foundry_config_path,
        foundry_out,
        abi_checksums_path,
    )
    return json_text(manifest)


def write_output(
    repo_root: Path,
    output_path: Path,
    contract_config_path: Path,
    foundry_config_path: Path,
    foundry_out: Path,
    abi_checksums_path: Path,
) -> Path:
    output_text = build_output_text(
        repo_root,
        output_path,
        contract_config_path,
        foundry_config_path,
        foundry_out,
        abi_checksums_path,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(
    repo_root: Path,
    output_path: Path,
    contract_config_path: Path,
    foundry_config_path: Path,
    foundry_out: Path,
    abi_checksums_path: Path,
) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_source_verification_inputs.py` and commit "
            "the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(
        repo_root,
        output_path,
        contract_config_path,
        foundry_config_path,
        foundry_out,
        abi_checksums_path,
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(f"changed {normalize_path(output_path, repo_root)}", file=sys.stderr)
            print(
                "run `python scripts/generate_source_verification_inputs.py` and commit "
                "the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("source verification inputs are current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--contract-config", type=Path, default=DEFAULT_CONTRACT_CONFIG)
    parser.add_argument("--foundry-config", type=Path, default=DEFAULT_FOUNDRY_CONFIG)
    parser.add_argument("--foundry-out", type=Path, default=DEFAULT_FOUNDRY_OUT)
    parser.add_argument("--abi-checksums", type=Path, default=DEFAULT_ABI_CHECKSUMS)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_output(
                repo_root,
                args.output,
                args.contract_config,
                args.foundry_config,
                args.foundry_out,
                args.abi_checksums,
            )
        written = write_output(
            repo_root,
            args.output,
            args.contract_config,
            args.foundry_config,
            args.foundry_out,
            args.abi_checksums,
        )
    except SourceVerificationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
