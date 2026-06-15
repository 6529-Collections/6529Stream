#!/usr/bin/env python3
"""Generate deterministic bytecode-to-release proof from committed artifacts."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any, Sequence


BYTECODE_RELEASE_PROOF_SCHEMA = "6529stream.bytecode-release-proof.v1"
GENERATOR_VERSION = "1"

DEFAULT_OUTPUT = Path("release-artifacts/latest/bytecode-release-proof.json")
DEFAULT_RELEASE_MANIFEST = Path("release-artifacts/latest/release-manifest.json")
DEFAULT_ABI_CHECKSUMS = Path("release-artifacts/latest/abi-checksums.json")
DEFAULT_SOURCE_VERIFICATION_INPUTS = Path(
    "release-artifacts/latest/source-verification-inputs.json"
)
DEFAULT_ADDRESS_BOOK_DIR = Path("deployments/address-books")

ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")


class BytecodeReleaseProofError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise BytecodeReleaseProofError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise BytecodeReleaseProofError(f"invalid JSON in {path}: {exc}") from exc


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
        raise BytecodeReleaseProofError(f"{path} must be an object")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise BytecodeReleaseProofError(f"{path} must be a non-empty string")
    return value


def require_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise BytecodeReleaseProofError(f"{path} must be an integer")
    return value


def require_bool(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise BytecodeReleaseProofError(f"{path} must be a boolean")
    return value


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise BytecodeReleaseProofError(f"{path} must be a sha256: hash")
    return digest


def require_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise BytecodeReleaseProofError(f"{path} must be a 20-byte hex address")
    return address.lower()


def require_existing_file(path: Path) -> None:
    if not path.is_file():
        raise BytecodeReleaseProofError(f"missing required file: {path}")


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    if "\\" in relative_path:
        raise BytecodeReleaseProofError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise BytecodeReleaseProofError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise BytecodeReleaseProofError(f"{path} must stay inside the repository") from exc
    require_existing_file(resolved)
    return resolved


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    require_existing_file(path)
    return {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def address_book_paths(address_book_dir: Path) -> list[Path]:
    if not address_book_dir.is_dir():
        raise BytecodeReleaseProofError(f"missing address book directory: {address_book_dir}")
    paths = sorted(path for path in address_book_dir.glob("*.json") if path.is_file())
    if not paths:
        raise BytecodeReleaseProofError(f"address book directory has no JSON files: {address_book_dir}")
    return paths


def require_schema(value: Any, expected: str, path: str) -> None:
    data = require_dict(value, path)
    schema = data.get("schema_version") or data.get("manifest_schema_version")
    if schema != expected:
        raise BytecodeReleaseProofError(f"{path} must use schema {expected}")


def validate_source_file_hash(path: Path, expected_sha256: str, path_label: str) -> None:
    actual = file_sha256(path)
    if actual != expected_sha256:
        raise BytecodeReleaseProofError(
            f"{path_label} hash mismatch: expected {expected_sha256}, got {actual}"
        )


def validate_release_artifacts(
    release_manifest: dict[str, Any],
    abi_path: Path,
    source_verification_path: Path,
    repo_root: Path,
) -> None:
    artifacts = require_dict(
        release_manifest.get("release_artifacts"), "release-manifest.release_artifacts"
    )
    abi_record = require_dict(artifacts.get("abi_checksums"), "release_artifacts.abi_checksums")
    source_record = require_dict(
        artifacts.get("source_verification_inputs"),
        "release_artifacts.source_verification_inputs",
    )
    if abi_record.get("path") != normalize_path(abi_path, repo_root):
        raise BytecodeReleaseProofError("release manifest abi_checksums path mismatch")
    if source_record.get("path") != normalize_path(source_verification_path, repo_root):
        raise BytecodeReleaseProofError("release manifest source_verification_inputs path mismatch")
    validate_source_file_hash(
        abi_path,
        require_sha256(abi_record.get("sha256"), "release_artifacts.abi_checksums.sha256"),
        "release manifest abi_checksums",
    )
    validate_source_file_hash(
        source_verification_path,
        require_sha256(
            source_record.get("sha256"),
            "release_artifacts.source_verification_inputs.sha256",
        ),
        "release manifest source_verification_inputs",
    )


def build_contract_proof(
    *,
    deployment_version: str,
    lifecycle_state: str,
    network: dict[str, Any],
    manifest_path: Path,
    manifest_file_hash: str,
    release_artifact_manifest_hash: str,
    address_book_path: Path,
    address_book_hash: str,
    contract_name: str,
    address_book_contract: dict[str, Any],
    manifest_contract: dict[str, Any],
    abi_contract: dict[str, Any],
    abi_bytecode: dict[str, Any],
    source_contract: dict[str, Any],
    repo_root: Path,
) -> dict[str, Any]:
    address = require_address(
        address_book_contract.get("address"),
        f"address-book.contracts.{contract_name}.address",
    )
    manifest_address = require_address(
        manifest_contract.get("address"),
        f"deployment-manifest.contracts.{contract_name}.address",
    )
    if address != manifest_address:
        raise BytecodeReleaseProofError(f"{contract_name} address mismatch")

    abi_hash = require_sha256(
        address_book_contract.get("abi_hash"),
        f"address-book.contracts.{contract_name}.abi_hash",
    )
    manifest_abi_hash = require_sha256(
        manifest_contract.get("abi_hash"),
        f"deployment-manifest.contracts.{contract_name}.abi_hash",
    )
    release_abi_hash = require_sha256(
        abi_contract.get("abi_sha256"),
        f"abi-checksums.contracts.{contract_name}.abi_sha256",
    )
    source_abi_hash = require_sha256(
        source_contract.get("abi_sha256"),
        f"source-verification.contracts.{contract_name}.abi_sha256",
    )
    if len({abi_hash, manifest_abi_hash, release_abi_hash, source_abi_hash}) != 1:
        raise BytecodeReleaseProofError(f"{contract_name} ABI hash mismatch")

    runtime_hash = require_sha256(
        address_book_contract.get("runtime_bytecode_hash"),
        f"address-book.contracts.{contract_name}.runtime_bytecode_hash",
    )
    manifest_runtime_hash = require_sha256(
        manifest_contract.get("bytecode_hash"),
        f"deployment-manifest.contracts.{contract_name}.bytecode_hash",
    )
    release_runtime_hash = require_sha256(
        abi_contract.get("deployed_bytecode_sha256"),
        f"abi-checksums.contracts.{contract_name}.deployed_bytecode_sha256",
    )
    bytecode_runtime_hash = require_sha256(
        require_dict(
            require_dict(
                source_contract.get("bytecode_hashes"),
                f"source-verification.contracts.{contract_name}.bytecode_hashes",
            ).get("runtime"),
            f"source-verification.contracts.{contract_name}.bytecode_hashes.runtime",
        ).get("release_artifact_sha256"),
        f"source-verification.contracts.{contract_name}.bytecode_hashes.runtime.release_artifact_sha256",
    )
    if len({runtime_hash, manifest_runtime_hash, release_runtime_hash, bytecode_runtime_hash}) != 1:
        raise BytecodeReleaseProofError(f"{contract_name} runtime bytecode hash mismatch")

    creation_hash = require_sha256(
        require_dict(abi_bytecode.get("creation"), f"abi-checksums.bytecode_hashes.{contract_name}.creation").get("sha256"),
        f"abi-checksums.bytecode_hashes.{contract_name}.creation.sha256",
    )
    source_creation_hash = require_sha256(
        require_dict(
            require_dict(
                source_contract.get("bytecode_hashes"),
                f"source-verification.contracts.{contract_name}.bytecode_hashes",
            ).get("creation"),
            f"source-verification.contracts.{contract_name}.bytecode_hashes.creation",
        ).get("release_artifact_sha256"),
        f"source-verification.contracts.{contract_name}.bytecode_hashes.creation.release_artifact_sha256",
    )
    if creation_hash != source_creation_hash:
        raise BytecodeReleaseProofError(f"{contract_name} creation bytecode hash mismatch")
    creation_size = require_int(
        abi_contract.get("bytecode_size_bytes"),
        f"abi-checksums.contracts.{contract_name}.bytecode_size_bytes",
    )
    runtime_size = require_int(
        abi_contract.get("deployed_bytecode_size_bytes"),
        f"abi-checksums.contracts.{contract_name}.deployed_bytecode_size_bytes",
    )
    eip170_limit = require_int(
        abi_contract.get("eip170_runtime_limit_bytes"),
        f"abi-checksums.contracts.{contract_name}.eip170_runtime_limit_bytes",
    )
    runtime_margin = require_int(
        abi_contract.get("deployed_runtime_margin_bytes"),
        f"abi-checksums.contracts.{contract_name}.deployed_runtime_margin_bytes",
    )
    if runtime_margin != eip170_limit - runtime_size:
        raise BytecodeReleaseProofError(f"{contract_name} runtime size margin mismatch")
    abi_runtime_size = require_int(
        require_dict(
            abi_bytecode.get("runtime"), f"abi-checksums.bytecode_hashes.{contract_name}.runtime"
        ).get("size_bytes"),
        f"abi-checksums.bytecode_hashes.{contract_name}.runtime.size_bytes",
    )
    abi_creation_size = require_int(
        require_dict(
            abi_bytecode.get("creation"), f"abi-checksums.bytecode_hashes.{contract_name}.creation"
        ).get("size_bytes"),
        f"abi-checksums.bytecode_hashes.{contract_name}.creation.size_bytes",
    )
    if runtime_size != abi_runtime_size:
        raise BytecodeReleaseProofError(f"{contract_name} runtime bytecode size mismatch")
    if creation_size != abi_creation_size:
        raise BytecodeReleaseProofError(f"{contract_name} creation bytecode size mismatch")

    source_path = require_string(
        address_book_contract.get("source"),
        f"address-book.contracts.{contract_name}.source",
    )
    artifact_path = require_string(
        address_book_contract.get("artifact_path"),
        f"address-book.contracts.{contract_name}.artifact_path",
    )
    if source_path != require_string(
        abi_contract.get("source"), f"abi-checksums.contracts.{contract_name}.source"
    ):
        raise BytecodeReleaseProofError(f"{contract_name} source path mismatch")
    if source_path != require_string(
        source_contract.get("source"),
        f"source-verification.contracts.{contract_name}.source",
    ):
        raise BytecodeReleaseProofError(f"{contract_name} source verification path mismatch")
    if artifact_path != require_string(
        abi_contract.get("artifact_path"),
        f"abi-checksums.contracts.{contract_name}.artifact_path",
    ):
        raise BytecodeReleaseProofError(f"{contract_name} artifact path mismatch")
    if artifact_path != require_string(
        source_contract.get("artifact_path"),
        f"source-verification.contracts.{contract_name}.artifact_path",
    ):
        raise BytecodeReleaseProofError(f"{contract_name} source verification artifact path mismatch")

    settings = require_dict(
        source_contract.get("settings"),
        f"source-verification.contracts.{contract_name}.settings",
    )
    optimizer = require_dict(
        settings.get("optimizer"),
        f"source-verification.contracts.{contract_name}.settings.optimizer",
    )
    return {
        "proof_id": f"{deployment_version}:{contract_name}",
        "deployment_version": deployment_version,
        "lifecycle_state": lifecycle_state,
        "network": {
            "name": require_string(network.get("name"), f"{deployment_version}.network.name"),
            "chain_id": require_int(network.get("chain_id"), f"{deployment_version}.network.chain_id"),
        },
        "contract": {
            "name": contract_name,
            "address": address,
            "source": source_path,
            "artifact_path": artifact_path,
        },
        "hashes": {
            "abi": abi_hash,
            "runtime_bytecode": runtime_hash,
            "creation_bytecode": creation_hash,
        },
        "sizes": {
            "runtime_bytecode_bytes": runtime_size,
            "creation_bytecode_bytes": creation_size,
            "eip170_runtime_limit_bytes": eip170_limit,
            "runtime_margin_bytes": runtime_margin,
        },
        "compiler": {
            "version": require_string(
                source_contract.get("compiler_version"),
                f"source-verification.contracts.{contract_name}.compiler_version",
            ),
            "evm_version": require_string(
                settings.get("evm_version"),
                f"source-verification.contracts.{contract_name}.settings.evm_version",
            ),
            "optimizer_enabled": require_bool(
                optimizer.get("enabled"),
                f"source-verification.contracts.{contract_name}.settings.optimizer.enabled",
            ),
            "optimizer_runs": require_int(
                optimizer.get("runs"),
                f"source-verification.contracts.{contract_name}.settings.optimizer.runs",
            ),
            "via_ir": require_bool(
                settings.get("via_ir"),
                f"source-verification.contracts.{contract_name}.settings.via_ir",
            ),
            "metadata_bytecode_hash": require_string(
                settings.get("metadata_bytecode_hash"),
                f"source-verification.contracts.{contract_name}.settings.metadata_bytecode_hash",
            ),
        },
        "source_verification": {
            "source_sha256": require_sha256(
                source_contract.get("source_sha256"),
                f"source-verification.contracts.{contract_name}.source_sha256",
            ),
            "source_solc_keccak256": require_string(
                source_contract.get("source_solc_keccak256"),
                f"source-verification.contracts.{contract_name}.source_solc_keccak256",
            ),
            "artifact_sha256": require_sha256(
                source_contract.get("artifact_sha256"),
                f"source-verification.contracts.{contract_name}.artifact_sha256",
            ),
            "constructor_args_status": require_string(
                require_dict(
                    source_contract.get("constructor_args"),
                    f"source-verification.contracts.{contract_name}.constructor_args",
                ).get("status"),
                f"source-verification.contracts.{contract_name}.constructor_args.status",
            ),
            "verification_status": require_string(
                address_book_contract.get("verification_status"),
                f"address-book.contracts.{contract_name}.verification_status",
            ),
        },
        "artifacts": {
            "deployment_manifest": {
                "path": normalize_path(manifest_path, repo_root),
                "sha256": manifest_file_hash,
                "release_artifact_manifest_sha256": release_artifact_manifest_hash,
            },
            "address_book": {
                "path": normalize_path(address_book_path, repo_root),
                "sha256": address_book_hash,
            },
        },
        "limitations": [
            "This proof is generated from committed deployment artifacts and does not query live chain bytecode.",
            "Production completion requires reviewed retained live RPC/explorer evidence.",
        ],
    }


def build_proof(
    repo_root: Path,
    output: Path = DEFAULT_OUTPUT,
    release_manifest_path: Path = DEFAULT_RELEASE_MANIFEST,
    abi_checksums_path: Path = DEFAULT_ABI_CHECKSUMS,
    source_verification_path: Path = DEFAULT_SOURCE_VERIFICATION_INPUTS,
    address_book_dir: Path = DEFAULT_ADDRESS_BOOK_DIR,
) -> dict[str, Any]:
    del output
    release_manifest_abs = repo_root / release_manifest_path
    abi_checksums_abs = repo_root / abi_checksums_path
    source_verification_abs = repo_root / source_verification_path
    address_book_abs = repo_root / address_book_dir

    release_manifest = load_json(release_manifest_abs)
    require_schema(release_manifest, "6529stream.release-manifest.v1", "release-manifest")
    abi_checksums = load_json(abi_checksums_abs)
    require_schema(abi_checksums, "6529stream.abi-checksums.v1", "abi-checksums")
    source_verification = load_json(source_verification_abs)
    require_schema(
        source_verification,
        "6529stream.source-verification-inputs.v1",
        "source-verification-inputs",
    )
    validate_release_artifacts(
        release_manifest,
        abi_checksums_abs,
        source_verification_abs,
        repo_root,
    )

    abi_contracts = require_dict(abi_checksums.get("contracts"), "abi-checksums.contracts")
    abi_bytecodes = require_dict(abi_checksums.get("bytecode_hashes"), "abi-checksums.bytecode_hashes")
    source_contracts = require_dict(
        source_verification.get("contracts"),
        "source-verification.contracts",
    )
    release_manifest_record = file_record(release_manifest_abs, repo_root)
    abi_record = file_record(abi_checksums_abs, repo_root)
    source_verification_record = file_record(source_verification_abs, repo_root)

    contract_proofs: list[dict[str, Any]] = []
    address_book_records = []
    deployment_manifest_records = []
    seen_manifest_paths: set[str] = set()

    for address_book_path in address_book_paths(address_book_abs):
        address_book = load_json(address_book_path)
        require_schema(address_book, "6529stream.address-book.v1", str(address_book_path))
        address_book_hash = file_sha256(address_book_path)
        address_book_records.append(file_record(address_book_path, repo_root))

        source = require_dict(address_book.get("source"), f"{address_book_path}.source")
        manifest_relative = require_string(
            source.get("deployment_manifest"),
            f"{address_book_path}.source.deployment_manifest",
        )
        manifest_path = resolve_repo_file(
            repo_root,
            manifest_relative,
            f"{address_book_path}.source.deployment_manifest",
        )
        manifest_file_hash = file_sha256(manifest_path)
        expected_release_artifact_manifest_hash = require_sha256(
            source.get("deployment_manifest_sha256"),
            f"{address_book_path}.source.deployment_manifest_sha256",
        )
        if normalize_path(manifest_path, repo_root) not in seen_manifest_paths:
            deployment_manifest_records.append(file_record(manifest_path, repo_root))
            seen_manifest_paths.add(normalize_path(manifest_path, repo_root))

        manifest = load_json(manifest_path)
        require_schema(manifest, "6529stream.deployment-manifest.v1", str(manifest_path))
        release_artifacts = require_dict(
            manifest.get("release_artifacts"),
            f"{manifest_path}.release_artifacts",
        )
        release_artifact_manifest_hash = require_sha256(
            release_artifacts.get("manifest_sha256"),
            f"{manifest_path}.release_artifacts.manifest_sha256",
        )
        if release_artifact_manifest_hash != expected_release_artifact_manifest_hash:
            raise BytecodeReleaseProofError(
                f"{address_book_path} release artifact manifest hash mismatch"
            )
        deployment_version = require_string(
            address_book.get("deployment_version"),
            f"{address_book_path}.deployment_version",
        )
        if deployment_version != require_string(
            manifest.get("deployment_version"),
            f"{manifest_path}.deployment_version",
        ):
            raise BytecodeReleaseProofError(f"{address_book_path} deployment_version mismatch")
        lifecycle_state = require_string(
            address_book.get("lifecycle_state"),
            f"{address_book_path}.lifecycle_state",
        )
        if lifecycle_state != require_string(
            manifest.get("lifecycle_state"),
            f"{manifest_path}.lifecycle_state",
        ):
            raise BytecodeReleaseProofError(f"{address_book_path} lifecycle_state mismatch")
        address_network = require_dict(address_book.get("network"), f"{address_book_path}.network")
        manifest_network = require_dict(manifest.get("network"), f"{manifest_path}.network")
        if address_network.get("name") != manifest_network.get("name"):
            raise BytecodeReleaseProofError(f"{address_book_path} network.name mismatch")
        if address_network.get("chain_id") != manifest_network.get("chain_id"):
            raise BytecodeReleaseProofError(f"{address_book_path} network.chain_id mismatch")

        address_contracts = require_dict(
            address_book.get("contracts"),
            f"{address_book_path}.contracts",
        )
        manifest_contracts = require_dict(
            manifest.get("contracts"),
            f"{manifest_path}.contracts",
        )
        if set(address_contracts) != set(manifest_contracts):
            raise BytecodeReleaseProofError(f"{address_book_path} contract set mismatch")
        for contract_name in sorted(address_contracts):
            if contract_name not in abi_contracts:
                raise BytecodeReleaseProofError(f"{contract_name} missing from abi checksums")
            if contract_name not in abi_bytecodes:
                raise BytecodeReleaseProofError(f"{contract_name} missing bytecode checksums")
            if contract_name not in source_contracts:
                raise BytecodeReleaseProofError(
                    f"{contract_name} missing from source verification inputs"
                )
            contract_proofs.append(
                build_contract_proof(
                    deployment_version=deployment_version,
                    lifecycle_state=lifecycle_state,
                    network=address_network,
                    manifest_path=manifest_path,
                    manifest_file_hash=manifest_file_hash,
                    release_artifact_manifest_hash=release_artifact_manifest_hash,
                    address_book_path=address_book_path,
                    address_book_hash=address_book_hash,
                    contract_name=contract_name,
                    address_book_contract=require_dict(
                        address_contracts[contract_name],
                        f"{address_book_path}.contracts.{contract_name}",
                    ),
                    manifest_contract=require_dict(
                        manifest_contracts[contract_name],
                        f"{manifest_path}.contracts.{contract_name}",
                    ),
                    abi_contract=require_dict(
                        abi_contracts[contract_name],
                        f"abi-checksums.contracts.{contract_name}",
                    ),
                    abi_bytecode=require_dict(
                        abi_bytecodes[contract_name],
                        f"abi-checksums.bytecode_hashes.{contract_name}",
                    ),
                    source_contract=require_dict(
                        source_contracts[contract_name],
                        f"source-verification.contracts.{contract_name}",
                    ),
                    repo_root=repo_root,
                )
            )

    return {
        "schema_version": BYTECODE_RELEASE_PROOF_SCHEMA,
        "generated_by": f"scripts/generate_bytecode_release_proof.py:{GENERATOR_VERSION}",
        "source": {
            "release_manifest": release_manifest_record,
            "abi_checksums": abi_record,
            "source_verification_inputs": source_verification_record,
            "deployment_manifests": sorted(
                deployment_manifest_records,
                key=lambda record: record["path"],
            ),
            "address_books": sorted(address_book_records, key=lambda record: record["path"]),
        },
        "release": require_dict(release_manifest.get("release"), "release-manifest.release"),
        "proof_status": {
            "local_and_fork": "generated_from_committed_artifacts",
            "production": "missing_reviewed_live_proof",
            "production_completion_requires": [
                "reviewed live deployment manifest or explorer verification evidence",
                "reviewed live deployed runtime bytecode evidence",
                "reviewed production address book evidence",
            ],
        },
        "contract_proofs": sorted(
            contract_proofs,
            key=lambda proof: (proof["deployment_version"], proof["contract"]["name"]),
        ),
    }


def expected_text(
    repo_root: Path,
    output: Path,
    release_manifest_path: Path,
    abi_checksums_path: Path,
    source_verification_path: Path,
    address_book_dir: Path,
) -> str:
    proof = build_proof(
        repo_root,
        output=output,
        release_manifest_path=release_manifest_path,
        abi_checksums_path=abi_checksums_path,
        source_verification_path=source_verification_path,
        address_book_dir=address_book_dir,
    )
    return json.dumps(proof, indent=2, ensure_ascii=False) + "\n"


def write_proof(
    repo_root: Path,
    output: Path,
    release_manifest_path: Path,
    abi_checksums_path: Path,
    source_verification_path: Path,
    address_book_dir: Path,
) -> Path:
    output_path = output if output.is_absolute() else repo_root / output
    text = expected_text(
        repo_root,
        output,
        release_manifest_path,
        abi_checksums_path,
        source_verification_path,
        address_book_dir,
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(text, encoding="utf-8", newline="\n")
    return output_path


def check_proof(
    repo_root: Path,
    output: Path,
    release_manifest_path: Path,
    abi_checksums_path: Path,
    source_verification_path: Path,
    address_book_dir: Path,
) -> None:
    output_path = output if output.is_absolute() else repo_root / output
    if not output_path.is_file():
        raise BytecodeReleaseProofError(f"missing bytecode release proof: {output_path}")
    with tempfile.TemporaryDirectory() as temp_dir:
        expected_path = Path(temp_dir) / output_path.name
        expected_path.write_text(
            expected_text(
                repo_root,
                output,
                release_manifest_path,
                abi_checksums_path,
                source_verification_path,
                address_book_dir,
            ),
            encoding="utf-8",
            newline="\n",
        )
        if not filecmp.cmp(expected_path, output_path, shallow=False):
            raise BytecodeReleaseProofError(
                f"changed {normalize_path(output_path, repo_root)}; "
                "run `python scripts/generate_bytecode_release_proof.py` and commit the regenerated file"
            )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--release-manifest", type=Path, default=DEFAULT_RELEASE_MANIFEST)
    parser.add_argument("--abi-checksums", type=Path, default=DEFAULT_ABI_CHECKSUMS)
    parser.add_argument(
        "--source-verification-inputs",
        type=Path,
        default=DEFAULT_SOURCE_VERIFICATION_INPUTS,
    )
    parser.add_argument("--address-book-dir", type=Path, default=DEFAULT_ADDRESS_BOOK_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    repo_root = args.repo_root.resolve()
    try:
        if args.check:
            check_proof(
                repo_root,
                args.output,
                args.release_manifest,
                args.abi_checksums,
                args.source_verification_inputs,
                args.address_book_dir,
            )
            print("bytecode release proof is current")
        else:
            output_path = write_proof(
                repo_root,
                args.output,
                args.release_manifest,
                args.abi_checksums,
                args.source_verification_inputs,
                args.address_book_dir,
            )
            print(normalize_path(output_path, repo_root))
    except BytecodeReleaseProofError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
