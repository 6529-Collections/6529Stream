#!/usr/bin/env python3
"""Generate a deterministic top-level release manifest."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any


RELEASE_MANIFEST_SCHEMA = "6529stream.release-manifest.v1"
GENERATOR_VERSION = "1"

DEFAULT_OUTPUT = Path("release-artifacts/latest/release-manifest.json")
DEFAULT_RELEASE_ARTIFACTS_DIR = Path("release-artifacts/latest")
DEFAULT_BASELINE = Path("release-artifacts/baselines/v0.1.0/abi-surface.json")
DEFAULT_CONTRACT_CONFIG = Path("release-artifacts/contracts.json")
DEFAULT_DEPLOYMENT_CONFIG_DIR = Path("deployments/config")
DEFAULT_DEPLOYMENT_MANIFEST_DIR = Path("deployments/examples")
DEFAULT_ADDRESS_BOOK_DIR = Path("deployments/address-books")
DEFAULT_DEPLOYMENT_SCHEMA_DIR = Path("deployments/schema")
DEFAULT_CHANGELOG = Path("CHANGELOG.md")
DEFAULT_GOVERNANCE_DOCS = [
    Path("docs/release-policy.md"),
    Path("docs/deployment.md"),
    Path("docs/tooling.md"),
    Path("docs/status.md"),
]
CHECKSUM_OUTPUTS = [
    {
        "path": "release-artifacts/latest/SHA256SUMS",
        "format": "sha256sum",
    },
    {
        "path": "release-artifacts/latest/release-checksums.json",
        "format": "json",
    },
]
CHECKSUM_DIGEST_STATUS = "not_available_self_referential"


class ReleaseManifestError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseManifestError(f"invalid JSON in {path}: {exc}") from exc


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


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseManifestError(f"{path} must be an object")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseManifestError(f"{path} must be a non-empty string")
    return value


def require_existing_file(path: Path) -> None:
    if not path.is_file():
        raise ReleaseManifestError(f"missing required file: {path}")


def json_schema_version(value: Any) -> str | None:
    if not isinstance(value, dict):
        return None
    schema = value.get("schema_version") or value.get("manifest_schema_version") or value.get("$schema")
    if isinstance(schema, str) and schema:
        return schema
    return None


def file_record(path: Path, repo_root: Path, *, schema_required: bool = False) -> dict[str, Any]:
    require_existing_file(path)
    record: dict[str, Any] = {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if path.suffix == ".json":
        data = load_json(path)
        schema = json_schema_version(data)
        if schema_required and schema is None:
            raise ReleaseManifestError(f"{path} is missing a schema version")
        if schema is not None:
            record["schema_version"] = schema
    return record


def json_files(directory: Path) -> list[Path]:
    if not directory.is_dir():
        raise ReleaseManifestError(f"missing required directory: {directory}")
    files = sorted(path for path in directory.glob("*.json") if path.is_file())
    if not files:
        raise ReleaseManifestError(f"required directory has no JSON files: {directory}")
    return files


def deployment_manifest_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    release_artifacts = require_dict(data.get("release_artifacts"), f"{path}.release_artifacts")
    network = require_dict(data.get("network"), f"{path}.network")
    contracts = require_dict(data.get("contracts"), f"{path}.contracts")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "lifecycle_state": require_string(data.get("lifecycle_state"), "lifecycle_state"),
            "network": {
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "manifest_sha256": require_string(
                release_artifacts.get("manifest_sha256"),
                "release_artifacts.manifest_sha256",
            ),
            "contracts": sorted(str(name) for name in contracts),
        }
    )
    return record


def address_book_record(path: Path, repo_root: Path) -> dict[str, Any]:
    data = require_dict(load_json(path), str(path))
    source = require_dict(data.get("source"), f"{path}.source")
    network = require_dict(data.get("network"), f"{path}.network")
    contracts = require_dict(data.get("contracts"), f"{path}.contracts")
    record = file_record(path, repo_root, schema_required=True)
    record.update(
        {
            "protocol_version": require_string(data.get("protocol_version"), "protocol_version"),
            "deployment_version": require_string(
                data.get("deployment_version"), "deployment_version"
            ),
            "lifecycle_state": require_string(data.get("lifecycle_state"), "lifecycle_state"),
            "network": {
                "name": require_string(network.get("name"), "network.name"),
                "chain_id": network.get("chain_id"),
            },
            "deployment_manifest": require_string(
                source.get("deployment_manifest"), "source.deployment_manifest"
            ),
            "deployment_manifest_sha256": require_string(
                source.get("deployment_manifest_sha256"),
                "source.deployment_manifest_sha256",
            ),
            "contracts": sorted(str(name) for name in contracts),
        }
    )
    return record


def artifact_manifest_record(release_artifacts_dir: Path, repo_root: Path) -> dict[str, Any]:
    path = release_artifacts_dir / "release-artifact-manifest.json"
    data = require_dict(load_json(path), str(path))
    artifacts = require_dict(data.get("artifacts"), "release-artifact-manifest.artifacts")
    record = file_record(path, repo_root, schema_required=True)
    record["artifacts"] = {
        str(name): require_dict(value, f"artifacts.{name}")
        for name, value in sorted(artifacts.items())
    }
    return record


def checksum_bundle() -> dict[str, Any]:
    return {
        "status": "generated_after_release_manifest",
        "generated_by": "scripts/generate_release_checksums.py:1",
        "digest_policy": {
            "status": CHECKSUM_DIGEST_STATUS,
            "reason": (
                "The checksum bundle covers release-manifest.json. Embedding the "
                "checksum bundle digest here would create a self-referential hash cycle."
            ),
        },
        "outputs": [
            {
                **entry,
                "sha256": CHECKSUM_DIGEST_STATUS,
            }
            for entry in CHECKSUM_OUTPUTS
        ],
        "coverage_expectation": {
            "release_manifest_path": "release-artifacts/latest/release-manifest.json",
            "covered_by_checksum_bundle": True,
        },
    }


def build_manifest(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
) -> dict[str, Any]:
    deployment_manifests = [
        deployment_manifest_record(path, repo_root) for path in json_files(deployment_manifest_dir)
    ]
    address_books = [address_book_record(path, repo_root) for path in json_files(address_book_dir)]
    protocol_versions = sorted(
        set(
            [record["protocol_version"] for record in deployment_manifests]
            + [record["protocol_version"] for record in address_books]
        )
    )
    deployment_versions = sorted(
        set(
            [record["deployment_version"] for record in deployment_manifests]
            + [record["deployment_version"] for record in address_books]
        )
    )

    return {
        "schema_version": RELEASE_MANIFEST_SCHEMA,
        "generated_by": f"scripts/generate_release_manifest.py:{GENERATOR_VERSION}",
        "release": {
            "project": "6529Stream",
            "status": "pre_audit_local_baseline",
            "protocol_versions": protocol_versions,
            "deployment_versions": deployment_versions,
        },
        "source": {
            "output": normalize_path(output_path, repo_root),
            "release_artifacts_dir": normalize_path(release_artifacts_dir, repo_root),
            "deployment_config_dir": normalize_path(deployment_config_dir, repo_root),
            "deployment_manifest_dir": normalize_path(deployment_manifest_dir, repo_root),
            "address_book_dir": normalize_path(address_book_dir, repo_root),
            "deployment_schema_dir": normalize_path(deployment_schema_dir, repo_root),
        },
        "release_artifacts": {
            "contract_config": file_record(contract_config_path, repo_root, schema_required=True),
            "abi_checksums": file_record(
                release_artifacts_dir / "abi-checksums.json",
                repo_root,
                schema_required=True,
            ),
            "event_topic_catalog": file_record(
                release_artifacts_dir / "event-topic-catalog.json",
                repo_root,
                schema_required=True,
            ),
            "interface_ids": file_record(
                release_artifacts_dir / "interface-ids.json",
                repo_root,
                schema_required=True,
            ),
            "artifact_manifest": artifact_manifest_record(release_artifacts_dir, repo_root),
            "abi_compatibility_baseline": file_record(
                baseline_path,
                repo_root,
                schema_required=True,
            ),
        },
        "deployment_artifacts": {
            "configs": [
                file_record(path, repo_root, schema_required=True)
                for path in json_files(deployment_config_dir)
            ],
            "manifests": deployment_manifests,
            "address_books": address_books,
            "schemas": [
                file_record(path, repo_root, schema_required=True)
                for path in json_files(deployment_schema_dir)
            ],
        },
        "release_notes_and_policy": {
            "changelog": file_record(changelog_path, repo_root),
            "governance_docs": [file_record(path, repo_root) for path in governance_docs],
        },
        "checksum_bundle": checksum_bundle(),
        "unavailable_release_ceremony": {
            "signed_git_tag": "not_available",
            "detached_checksum_signature": "not_available",
            "production_broadcast_manifest": "not_available",
            "live_contract_verification": "not_available",
        },
    }


def build_output_text(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
) -> str:
    manifest = build_manifest(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        contract_config_path,
        deployment_config_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        changelog_path,
        governance_docs,
    )
    return json.dumps(manifest, indent=2, ensure_ascii=False) + "\n"


def write_output(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
) -> Path:
    output_text = build_output_text(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        contract_config_path,
        deployment_config_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        changelog_path,
        governance_docs,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(
    repo_root: Path,
    output_path: Path,
    release_artifacts_dir: Path,
    baseline_path: Path,
    contract_config_path: Path,
    deployment_config_dir: Path,
    deployment_manifest_dir: Path,
    address_book_dir: Path,
    deployment_schema_dir: Path,
    changelog_path: Path,
    governance_docs: list[Path],
) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_manifest.py` and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(
        repo_root,
        output_path,
        release_artifacts_dir,
        baseline_path,
        contract_config_path,
        deployment_config_dir,
        deployment_manifest_dir,
        address_book_dir,
        deployment_schema_dir,
        changelog_path,
        governance_docs,
    )

    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(
                f"changed {normalize_path(output_path, repo_root)}",
                file=sys.stderr,
            )
            print(
                "run `python scripts/generate_release_manifest.py` and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("release manifest is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--release-artifacts-dir", type=Path, default=DEFAULT_RELEASE_ARTIFACTS_DIR)
    parser.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    parser.add_argument("--contract-config", type=Path, default=DEFAULT_CONTRACT_CONFIG)
    parser.add_argument("--deployment-config-dir", type=Path, default=DEFAULT_DEPLOYMENT_CONFIG_DIR)
    parser.add_argument(
        "--deployment-manifest-dir",
        type=Path,
        default=DEFAULT_DEPLOYMENT_MANIFEST_DIR,
    )
    parser.add_argument("--address-book-dir", type=Path, default=DEFAULT_ADDRESS_BOOK_DIR)
    parser.add_argument("--deployment-schema-dir", type=Path, default=DEFAULT_DEPLOYMENT_SCHEMA_DIR)
    parser.add_argument("--changelog", type=Path, default=DEFAULT_CHANGELOG)
    parser.add_argument("--governance-doc", type=Path, action="append", dest="governance_docs")
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    governance_docs = args.governance_docs or DEFAULT_GOVERNANCE_DOCS

    try:
        if args.check:
            return check_output(
                repo_root,
                args.output,
                args.release_artifacts_dir,
                args.baseline,
                args.contract_config,
                args.deployment_config_dir,
                args.deployment_manifest_dir,
                args.address_book_dir,
                args.deployment_schema_dir,
                args.changelog,
                governance_docs,
            )
        written = write_output(
            repo_root,
            args.output,
            args.release_artifacts_dir,
            args.baseline,
            args.contract_config,
            args.deployment_config_dir,
            args.deployment_manifest_dir,
            args.address_book_dir,
            args.deployment_schema_dir,
            args.changelog,
            governance_docs,
        )
    except ReleaseManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(normalize_path(written, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
