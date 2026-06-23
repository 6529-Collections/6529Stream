#!/usr/bin/env python3
"""Generate deterministic deployment manifests from committed inputs."""

from __future__ import annotations

import argparse
import copy
import filecmp
import hashlib
import json
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


INPUT_SCHEMA = "6529stream.deployment-manifest-input.v1"
MANIFEST_SCHEMA = "6529stream.deployment-manifest.v1"
GENERATOR_VERSION = "1"
ZERO_MANIFEST_CHECKSUM = "sha256:" + ("0" * 64)

DEFAULT_CONFIG = Path("deployments/config/anvil-6529stream-v0.1.0-001.json")
DEFAULT_RELEASE_ARTIFACTS_DIR = Path("release-artifacts/latest")


class ManifestError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ManifestError(f"invalid JSON in {path}: {exc}") from exc


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


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ManifestError(f"{path} must be a non-empty string")
    return value


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ManifestError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise ManifestError(f"{path} must be an array")
    return value


def normalize_checksum_target(manifest: dict[str, Any]) -> dict[str, Any]:
    normalized = copy.deepcopy(manifest)
    release_artifacts = require_dict(
        normalized.get("release_artifacts"), "manifest.release_artifacts"
    )
    release_artifacts["manifest_sha256"] = ZERO_MANIFEST_CHECKSUM
    return normalized


def manifest_checksum(manifest: dict[str, Any]) -> str:
    return sha256_json(normalize_checksum_target(manifest))


def load_release_hashes(release_artifacts_dir: Path) -> tuple[dict[str, str], dict[str, str]]:
    checksums = load_json(release_artifacts_dir / "abi-checksums.json")
    abi_hashes = require_dict(checksums.get("abi_hashes"), "abi-checksums.abi_hashes")
    bytecode_hashes = require_dict(
        checksums.get("bytecode_hashes"), "abi-checksums.bytecode_hashes"
    )
    contract_metadata = checksums.get("contracts")
    singleton_contracts: set[str] | None = None
    if isinstance(contract_metadata, dict):
        singleton_contracts = {
            str(name)
            for name, contract in contract_metadata.items()
            if isinstance(contract, dict)
            and contract.get("deployment_scope", "singleton") == "singleton"
        }

    runtime_hashes: dict[str, str] = {}
    for name, hashes in bytecode_hashes.items():
        if singleton_contracts is not None and str(name) not in singleton_contracts:
            continue
        contract_hashes = require_dict(hashes, f"bytecode_hashes.{name}")
        runtime = require_dict(contract_hashes.get("runtime"), f"bytecode_hashes.{name}.runtime")
        runtime_hashes[name] = require_string(
            runtime.get("sha256"), f"bytecode_hashes.{name}.runtime.sha256"
        )

    filtered_abi_hashes = {
        str(name): str(value)
        for name, value in abi_hashes.items()
        if singleton_contracts is None or str(name) in singleton_contracts
    }

    return dict(sorted(filtered_abi_hashes.items())), dict(
        sorted((str(name), str(value)) for name, value in runtime_hashes.items())
    )


def validate_contract_set(
    configured_contracts: list[dict[str, Any]],
    abi_hashes: dict[str, str],
    runtime_hashes: dict[str, str],
) -> None:
    configured_names = [
        require_string(contract.get("name"), "contract.name")
        for contract in configured_contracts
    ]
    duplicate_names = sorted(
        name for name, count in Counter(configured_names).items() if count > 1
    )
    if duplicate_names:
        raise ManifestError(f"duplicate contract manifest entries: {', '.join(duplicate_names)}")

    configured_set = set(configured_names)
    abi_set = set(abi_hashes)
    runtime_set = set(runtime_hashes)
    if abi_set != runtime_set:
        missing_runtime = sorted(abi_set - runtime_set)
        extra_runtime = sorted(runtime_set - abi_set)
        details = []
        if missing_runtime:
            details.append(f"missing runtime hashes for {', '.join(missing_runtime)}")
        if extra_runtime:
            details.append(f"unexpected runtime hashes for {', '.join(extra_runtime)}")
        raise ManifestError("; ".join(details))

    missing = sorted(abi_set - configured_set)
    unknown = sorted(configured_set - abi_set)
    details = []
    if missing:
        details.append(f"manifest config omits release contracts: {', '.join(missing)}")
    if unknown:
        details.append(f"manifest config references unknown contracts: {', '.join(unknown)}")
    if details:
        raise ManifestError("; ".join(details))


def build_contracts(
    configured_contracts: list[Any],
    abi_hashes: dict[str, str],
    runtime_hashes: dict[str, str],
) -> dict[str, Any]:
    contract_entries = [
        require_dict(contract, "manifest.contracts[]") for contract in configured_contracts
    ]
    validate_contract_set(contract_entries, abi_hashes, runtime_hashes)

    contracts: dict[str, Any] = {}
    for contract in contract_entries:
        name = require_string(contract.get("name"), "contract.name")
        output = {
            "address": require_string(contract.get("address"), f"contracts.{name}.address"),
            "constructor_args": require_list(
                contract.get("constructor_args"), f"contracts.{name}.constructor_args"
            ),
            "abi_hash": abi_hashes[name],
            "bytecode_hash": runtime_hashes[name],
            "verification_status": require_string(
                contract.get("verification_status"), f"contracts.{name}.verification_status"
            ),
        }
        contracts[name] = output
    return contracts


def build_manifest(
    config_path: Path,
    release_artifacts_dir: Path,
) -> tuple[Path, dict[str, Any]]:
    config = load_json(config_path)
    schema_version = require_string(config.get("schema_version"), "schema_version")
    if schema_version != INPUT_SCHEMA:
        raise ManifestError(f"unsupported manifest input schema: {schema_version}")

    output_path = Path(require_string(config.get("output"), "output"))
    manifest_input = require_dict(config.get("manifest"), "manifest")
    configured_contracts = require_list(manifest_input.get("contracts"), "manifest.contracts")
    abi_hashes, runtime_hashes = load_release_hashes(release_artifacts_dir)

    release_artifacts = require_dict(
        manifest_input.get("release_artifacts"), "manifest.release_artifacts"
    )
    event_topic_catalog = require_string(
        release_artifacts.get("event_topic_catalog"),
        "manifest.release_artifacts.event_topic_catalog",
    )

    manifest: dict[str, Any] = {
        "manifest_schema_version": MANIFEST_SCHEMA,
        "protocol_version": require_string(
            manifest_input.get("protocol_version"), "manifest.protocol_version"
        ),
        "deployment_version": require_string(
            manifest_input.get("deployment_version"), "manifest.deployment_version"
        ),
        "lifecycle_state": require_string(
            manifest_input.get("lifecycle_state"), "manifest.lifecycle_state"
        ),
        "network": require_dict(manifest_input.get("network"), "manifest.network"),
        "git": require_dict(manifest_input.get("git"), "manifest.git"),
        "toolchain": require_dict(manifest_input.get("toolchain"), "manifest.toolchain"),
        "contracts": build_contracts(configured_contracts, abi_hashes, runtime_hashes),
        "admin_ceremony": require_dict(
            manifest_input.get("admin_ceremony"), "manifest.admin_ceremony"
        ),
        "external_dependencies": require_dict(
            manifest_input.get("external_dependencies"), "manifest.external_dependencies"
        ),
        "verification": require_dict(manifest_input.get("verification"), "manifest.verification"),
        "release_artifacts": {
            "manifest_sha256": ZERO_MANIFEST_CHECKSUM,
            "abi_hashes": {
                name: abi_hashes[name] for name in manifest_input_contract_names(configured_contracts)
            },
            "event_topic_catalog": event_topic_catalog,
        },
        "rehearsal": require_dict(manifest_input.get("rehearsal"), "manifest.rehearsal"),
    }
    manifest["release_artifacts"]["manifest_sha256"] = manifest_checksum(manifest)
    return output_path, manifest


def manifest_input_contract_names(configured_contracts: list[Any]) -> list[str]:
    names = [
        require_string(
            require_dict(contract, "manifest.contracts[]").get("name"), "contract.name"
        )
        for contract in configured_contracts
    ]
    return names


def generate_manifest(
    config_path: Path, release_artifacts_dir: Path, output_path: Path | None
) -> Path:
    configured_output, manifest = build_manifest(config_path, release_artifacts_dir)
    target = output_path or configured_output
    write_json(target, manifest)
    return target


def check_manifest(config_path: Path, release_artifacts_dir: Path, output_path: Path | None) -> int:
    configured_output, manifest = build_manifest(config_path, release_artifacts_dir)
    target = output_path or configured_output
    with tempfile.TemporaryDirectory() as temp_dir:
        generated = Path(temp_dir) / "deployment-manifest.json"
        write_json(generated, manifest)
        if not target.exists():
            print(f"deployment manifest is missing: {target}", file=sys.stderr)
            return 1
        if not filecmp.cmp(generated, target, shallow=False):
            print("deployment manifest is out of date:", file=sys.stderr)
            print(f"  - changed {target.as_posix()}", file=sys.stderr)
            print(
                "run `python scripts/generate_deployment_manifest.py` and commit the regenerated JSON",
                file=sys.stderr,
            )
            return 1
    print("deployment manifest is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument(
        "--release-artifacts-dir", type=Path, default=DEFAULT_RELEASE_ARTIFACTS_DIR
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        if args.check:
            return check_manifest(args.config, args.release_artifacts_dir, args.output)
        output_path = generate_manifest(args.config, args.release_artifacts_dir, args.output)
    except ManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(output_path.as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
