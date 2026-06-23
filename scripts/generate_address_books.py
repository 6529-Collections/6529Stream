#!/usr/bin/env python3
"""Generate deterministic deployment address books from committed manifests."""

from __future__ import annotations

import argparse
import filecmp
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


ADDRESS_BOOK_SCHEMA = "6529stream.address-book.v1"
DEPLOYMENT_MANIFEST_SCHEMA = "6529stream.deployment-manifest.v1"
GENERATOR_VERSION = "1"

DEFAULT_MANIFESTS = [
    Path("deployments/examples/anvil-6529stream-v0.1.0-001.json"),
    Path("deployments/examples/anvil-6529stream-v0.1.0-001-broadcast.json"),
    Path("deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json"),
]
DEFAULT_OUTPUT_DIR = Path("deployments/address-books")
DEFAULT_RELEASE_ARTIFACTS_DIR = Path("release-artifacts/latest")

ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
ZERO_ADDRESS = "0x" + ("0" * 40)
LIFECYCLE_STATES = frozenset(
    {
        "Planned",
        "Rehearsed",
        "Active",
        "Deprecated",
        "EmergencySuperseded",
        "Retired",
        "Cancelled",
    }
)
VERIFICATION_STATUSES = frozenset(
    {
        "not_started",
        "submitted",
        "verified",
        "not_applicable",
    }
)


class AddressBookError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise AddressBookError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise AddressBookError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise AddressBookError(f"{path} must be a non-empty string")
    return value


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise AddressBookError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.match(digest):
        raise AddressBookError(f"{path} must be a sha256: hash")
    return digest


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise AddressBookError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    number = require_int(value, path)
    if number < 1:
        raise AddressBookError(f"{path} must be greater than zero")
    return number


def require_git_commit(value: Any, path: str) -> str:
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.match(commit):
        raise AddressBookError(f"{path} must be a 40-character git commit hash")
    return commit


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise AddressBookError(f"{path} must be a boolean")
    return value


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise AddressBookError(f"{path} must be an object")
    return value


def normalize_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.match(address):
        raise AddressBookError(f"{path} must be a 20-byte hex address")
    if address.lower() == ZERO_ADDRESS:
        raise AddressBookError(f"{path} cannot be the zero address")
    return address.lower()


def load_release_contract_metadata(release_artifacts_dir: Path) -> dict[str, Any]:
    checksums = load_json(release_artifacts_dir / "abi-checksums.json")
    contracts = require_dict(checksums.get("contracts"), "abi-checksums.contracts")
    metadata: dict[str, Any] = {}
    for name, contract in contracts.items():
        contract_data = require_dict(contract, f"abi-checksums.contracts.{name}")
        deployment_scope = contract_data.get("deployment_scope", "singleton")
        if deployment_scope == "factory_spawned":
            continue
        if deployment_scope != "singleton":
            raise AddressBookError(
                f"abi-checksums.contracts.{name}.deployment_scope must be singleton "
                "or factory_spawned"
            )
        metadata[str(name)] = {
            "source": require_string(
                contract_data.get("source"), f"abi-checksums.contracts.{name}.source"
            ),
            "artifact_path": require_string(
                contract_data.get("artifact_path"),
                f"abi-checksums.contracts.{name}.artifact_path",
            ),
            "abi_sha256": require_sha256(
                contract_data.get("abi_sha256"),
                f"abi-checksums.contracts.{name}.abi_sha256",
            ),
            "deployed_bytecode_sha256": require_sha256(
                contract_data.get("deployed_bytecode_sha256"),
                f"abi-checksums.contracts.{name}.deployed_bytecode_sha256",
            ),
        }
    return metadata


def validate_contract_set(
    manifest_contracts: dict[str, Any],
    release_contracts: dict[str, Any],
) -> None:
    manifest_names = set(manifest_contracts)
    release_names = set(release_contracts)
    missing = sorted(release_names - manifest_names)
    unknown = sorted(manifest_names - release_names)
    details = []
    if missing:
        details.append(f"deployment manifest omits release contracts: {', '.join(missing)}")
    if unknown:
        details.append(f"deployment manifest references unknown contracts: {', '.join(unknown)}")
    if details:
        raise AddressBookError("; ".join(details))


def build_contracts(
    manifest_contracts: dict[str, Any],
    release_contracts: dict[str, Any],
) -> dict[str, Any]:
    validate_contract_set(manifest_contracts, release_contracts)

    seen_addresses: dict[str, str] = {}
    contracts: dict[str, Any] = {}
    for name in sorted(manifest_contracts):
        manifest_contract = require_dict(manifest_contracts[name], f"contracts.{name}")
        release_contract = release_contracts[name]
        address = normalize_address(manifest_contract.get("address"), f"contracts.{name}.address")
        duplicate_owner = seen_addresses.get(address.lower())
        if duplicate_owner is not None:
            raise AddressBookError(
                f"contracts.{name}.address duplicates contracts.{duplicate_owner}.address"
            )
        seen_addresses[address.lower()] = name

        abi_hash = require_sha256(manifest_contract.get("abi_hash"), f"contracts.{name}.abi_hash")
        runtime_hash = require_sha256(
            manifest_contract.get("bytecode_hash"), f"contracts.{name}.bytecode_hash"
        )
        expected_abi_hash = release_contract["abi_sha256"]
        expected_runtime_hash = release_contract["deployed_bytecode_sha256"]
        if abi_hash != expected_abi_hash:
            raise AddressBookError(
                f"contracts.{name}.abi_hash does not match release artifact baseline"
            )
        if runtime_hash != expected_runtime_hash:
            raise AddressBookError(
                f"contracts.{name}.bytecode_hash does not match release artifact baseline"
            )

        contracts[name] = {
            "address": address,
            "source": release_contract["source"],
            "artifact_path": release_contract["artifact_path"],
            "abi_hash": abi_hash,
            "runtime_bytecode_hash": runtime_hash,
            "verification_status": require_enum(
                manifest_contract.get("verification_status"),
                f"contracts.{name}.verification_status",
                VERIFICATION_STATUSES,
            ),
        }
    return contracts


def build_address_book(
    manifest_path: Path,
    release_artifacts_dir: Path,
    repo_root: Path,
) -> dict[str, Any]:
    manifest = load_json(manifest_path)
    schema_version = require_string(
        manifest.get("manifest_schema_version"), "manifest.manifest_schema_version"
    )
    if schema_version != DEPLOYMENT_MANIFEST_SCHEMA:
        raise AddressBookError(f"unsupported deployment manifest schema: {schema_version}")

    network = require_dict(manifest.get("network"), "manifest.network")
    git = require_dict(manifest.get("git"), "manifest.git")
    release_artifacts = require_dict(
        manifest.get("release_artifacts"), "manifest.release_artifacts"
    )
    source_manifest_checksum = require_sha256(
        release_artifacts.get("manifest_sha256"),
        "manifest.release_artifacts.manifest_sha256",
    )
    event_topic_catalog = require_string(
        release_artifacts.get("event_topic_catalog"),
        "manifest.release_artifacts.event_topic_catalog",
    )
    manifest_contracts = require_dict(manifest.get("contracts"), "manifest.contracts")
    release_contracts = load_release_contract_metadata(release_artifacts_dir)

    return {
        "schema_version": ADDRESS_BOOK_SCHEMA,
        "generated_by": f"scripts/generate_address_books.py:{GENERATOR_VERSION}",
        "source": {
            "deployment_manifest": normalize_path(manifest_path, repo_root),
            "deployment_manifest_sha256": source_manifest_checksum,
            "release_artifacts": normalize_path(release_artifacts_dir, repo_root),
            "abi_checksums": normalize_path(
                release_artifacts_dir / "abi-checksums.json", repo_root
            ),
            "event_topic_catalog": event_topic_catalog,
        },
        "protocol_version": require_string(
            manifest.get("protocol_version"), "manifest.protocol_version"
        ),
        "deployment_version": require_string(
            manifest.get("deployment_version"), "manifest.deployment_version"
        ),
        "lifecycle_state": require_enum(
            manifest.get("lifecycle_state"),
            "manifest.lifecycle_state",
            LIFECYCLE_STATES,
        ),
        "network": {
            "name": require_string(network.get("name"), "manifest.network.name"),
            "chain_id": require_positive_int(
                network.get("chain_id"), "manifest.network.chain_id"
            ),
        },
        "git": {
            "repository": require_string(git.get("repository"), "manifest.git.repository"),
            "commit": require_git_commit(git.get("commit"), "manifest.git.commit"),
            "source_dirty": require_bool(
                git.get("source_dirty"), "manifest.git.source_dirty"
            ),
        },
        "contracts": build_contracts(manifest_contracts, release_contracts),
    }


def output_path_for_manifest(manifest_path: Path, output_dir: Path) -> Path:
    return output_dir / manifest_path.name


def generate_address_books(
    manifest_paths: list[Path],
    release_artifacts_dir: Path,
    output_dir: Path,
    repo_root: Path,
) -> list[Path]:
    written = []
    for manifest_path in sorted(manifest_paths, key=lambda path: path.as_posix()):
        address_book = build_address_book(manifest_path, release_artifacts_dir, repo_root)
        output_path = output_path_for_manifest(manifest_path, output_dir)
        write_json(output_path, address_book)
        written.append(output_path)
    return written


def compare_generated_outputs(expected_dir: Path, actual_dir: Path) -> list[str]:
    mismatches: list[str] = []
    expected_files = sorted(path.relative_to(expected_dir) for path in expected_dir.glob("*.json"))
    actual_files = sorted(path.relative_to(actual_dir) for path in actual_dir.glob("*.json"))

    missing = sorted(set(expected_files) - set(actual_files))
    extra = sorted(set(actual_files) - set(expected_files))
    mismatches.extend(f"missing {path.as_posix()}" for path in missing)
    mismatches.extend(f"unexpected {path.as_posix()}" for path in extra)

    for relative_path in sorted(set(expected_files) & set(actual_files)):
        if not filecmp.cmp(expected_dir / relative_path, actual_dir / relative_path, shallow=False):
            mismatches.append(f"changed {relative_path.as_posix()}")
    return mismatches


def check_address_books(
    manifest_paths: list[Path],
    release_artifacts_dir: Path,
    output_dir: Path,
    repo_root: Path,
) -> int:
    with tempfile.TemporaryDirectory() as temp_dir:
        generated_dir = Path(temp_dir) / "address-books"
        generate_address_books(manifest_paths, release_artifacts_dir, generated_dir, repo_root)
        if not output_dir.exists():
            print(f"address-book output directory is missing: {output_dir}", file=sys.stderr)
            return 1
        mismatches = compare_generated_outputs(generated_dir, output_dir)
        if mismatches:
            print("address books are out of date:", file=sys.stderr)
            for mismatch in mismatches:
                print(f"  - {mismatch}", file=sys.stderr)
            print(
                "run `python scripts/generate_address_books.py` after deployment manifests are generated",
                file=sys.stderr,
            )
            return 1
    print("address books are current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", action="append", type=Path, dest="manifests")
    parser.add_argument(
        "--release-artifacts-dir", type=Path, default=DEFAULT_RELEASE_ARTIFACTS_DIR
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    manifest_paths = args.manifests or DEFAULT_MANIFESTS
    repo_root = Path.cwd()
    try:
        if args.check:
            return check_address_books(
                manifest_paths,
                args.release_artifacts_dir,
                args.output_dir,
                repo_root,
            )
        written = generate_address_books(
            manifest_paths,
            args.release_artifacts_dir,
            args.output_dir,
            repo_root,
        )
    except AddressBookError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for path in written:
        print(path.as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
