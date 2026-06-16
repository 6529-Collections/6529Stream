#!/usr/bin/env python3
"""Generate a deterministic dependency provenance attestation bundle."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import re
import sys
import tempfile
from pathlib import Path
from typing import Any


ATTESTATION_SCHEMA = "6529stream.dependency-provenance-attestation.v1"
DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA = "6529stream.dependency-artifact-manifest.v1"
GENERATOR_VERSION = "1"

DEFAULT_MANIFEST = Path("release-artifacts/latest/dependency-artifact-manifest.json")
DEFAULT_OUTPUT = Path("release-artifacts/latest/dependency-provenance-attestation.json")

SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
HEX32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|rpc[_ -]?url|api[_ -]?key|"
    r"password|client[_ -]?secret|bearer[_ -]?token|raw[_ -]?signature|"
    r"unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)
SECRET_URL_RE = re.compile(
    r"https?://[^\s\"`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)"
    r"[^\s\"`]*",
    re.IGNORECASE,
)


class DependencyProvenanceAttestationError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise DependencyProvenanceAttestationError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise DependencyProvenanceAttestationError(f"invalid JSON in {path}: {exc}") from exc


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


def canonical_json_sha256(value: Any) -> str:
    data = json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256_bytes(data.encode("utf-8"))


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DependencyProvenanceAttestationError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise DependencyProvenanceAttestationError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise DependencyProvenanceAttestationError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise DependencyProvenanceAttestationError(f"{path} must be a positive integer")
    return value


def require_sha256(value: Any, path: str) -> str:
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise DependencyProvenanceAttestationError(f"{path} must be a sha256 digest")
    return digest


def require_dependency_key(value: Any, path: str) -> str:
    key = require_string(value, path).lower()
    if not HEX32_RE.fullmatch(key):
        raise DependencyProvenanceAttestationError(f"{path} must be a 32-byte hex string")
    return key


def resolve_repo_file(repo_root: Path, relative_path: str, field_path: str) -> Path:
    if relative_path.startswith("/") or "\\" in relative_path:
        raise DependencyProvenanceAttestationError(f"{field_path} must be a repo-relative POSIX path")
    path = Path(relative_path)
    if ".." in path.parts:
        raise DependencyProvenanceAttestationError(f"{field_path} must not contain parent-directory segments")
    resolved = (repo_root / path).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise DependencyProvenanceAttestationError(
            f"{field_path} must stay inside the repository"
        ) from exc
    if not resolved.is_file():
        raise DependencyProvenanceAttestationError(f"{field_path} references missing file: {relative_path}")
    return resolved


def validate_file_record(repo_root: Path, record: dict[str, Any], path: str) -> dict[str, Any]:
    relative_path = require_string(record.get("path"), f"{path}.path")
    expected_sha256 = require_sha256(record.get("sha256"), f"{path}.sha256")
    size_bytes = require_positive_int(record.get("size_bytes"), f"{path}.size_bytes")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_sha256 = file_sha256(resolved)
    if actual_sha256 != expected_sha256:
        raise DependencyProvenanceAttestationError(
            f"{path}.sha256 mismatch for {relative_path}: expected {expected_sha256}, got {actual_sha256}"
        )
    actual_size = resolved.stat().st_size
    if actual_size != size_bytes:
        raise DependencyProvenanceAttestationError(
            f"{path}.size_bytes mismatch for {relative_path}: expected {size_bytes}, got {actual_size}"
        )
    return {
        "path": relative_path,
        "sha256": expected_sha256,
        "size_bytes": size_bytes,
    }


def scan_no_secret_values(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            scan_no_secret_values(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            scan_no_secret_values(child, f"{path}[{index}]")
    elif isinstance(value, str):
        match = SECRET_VALUE_RE.search(value) or SECRET_URL_RE.search(value)
        if match:
            raise DependencyProvenanceAttestationError(
                f"{path} contains secret-like value: {match.group(0)}"
            )


def artifact_identity(record: dict[str, Any]) -> tuple[str, str, str, str, int]:
    dependency = require_dict(record.get("dependency"), "artifact.dependency")
    return (
        require_string(record.get("protocol_version"), "artifact.protocol_version"),
        require_string(record.get("deployment_version"), "artifact.deployment_version"),
        require_string(dependency.get("registry_contract"), "artifact.dependency.registry_contract"),
        require_dependency_key(dependency.get("key"), "artifact.dependency.key"),
        require_positive_int(dependency.get("version"), "artifact.dependency.version"),
    )


def build_artifact_attestation(
    repo_root: Path,
    artifact: dict[str, Any],
    index: int,
) -> dict[str, Any]:
    descriptor = require_dict(artifact.get("descriptor"), f"artifacts[{index}].descriptor")
    dependency = require_dict(artifact.get("dependency"), f"artifacts[{index}].dependency")
    source = require_dict(artifact.get("source"), f"artifacts[{index}].source")
    files = require_list(artifact.get("files"), f"artifacts[{index}].files")
    if not files:
        raise DependencyProvenanceAttestationError(f"artifacts[{index}].files must not be empty")

    descriptor_record = validate_file_record(repo_root, descriptor, f"artifacts[{index}].descriptor")
    schema = require_string(
        descriptor.get("schema_version"),
        f"artifacts[{index}].descriptor.schema_version",
    )

    file_records = []
    seen_paths: set[str] = set()
    for file_index, file_entry in enumerate(files):
        entry = require_dict(file_entry, f"artifacts[{index}].files[{file_index}]")
        file_record = validate_file_record(
            repo_root,
            entry,
            f"artifacts[{index}].files[{file_index}]",
        )
        if file_record["path"] in seen_paths:
            raise DependencyProvenanceAttestationError(
                f"artifacts[{index}].files contains duplicate path: {file_record['path']}"
            )
        seen_paths.add(file_record["path"])
        file_record.update(
            {
                "role": require_string(entry.get("role"), f"artifacts[{index}].files[{file_index}].role"),
                "media_type": require_string(
                    entry.get("media_type"),
                    f"artifacts[{index}].files[{file_index}].media_type",
                ),
            }
        )
        file_records.append(file_record)

    dependency_name = require_string(dependency.get("name"), f"artifacts[{index}].dependency.name")
    dependency_key = require_dependency_key(dependency.get("key"), f"artifacts[{index}].dependency.key")
    dependency_version = require_positive_int(
        dependency.get("version"),
        f"artifacts[{index}].dependency.version",
    )
    provenance = require_string(
        dependency.get("provenance"),
        f"artifacts[{index}].dependency.provenance",
    )
    key_preimage = require_string(
        dependency.get("key_preimage"),
        f"artifacts[{index}].dependency.key_preimage",
    )
    registered_by = require_string(source.get("registered_by"), f"artifacts[{index}].source.registered_by")
    source_notes = source.get("notes", "")
    if not isinstance(source_notes, str):
        raise DependencyProvenanceAttestationError(f"artifacts[{index}].source.notes must be a string")

    return {
        "identity": {
            "protocol_version": require_string(
                artifact.get("protocol_version"),
                f"artifacts[{index}].protocol_version",
            ),
            "deployment_version": require_string(
                artifact.get("deployment_version"),
                f"artifacts[{index}].deployment_version",
            ),
            "registry_contract": require_string(
                dependency.get("registry_contract"),
                f"artifacts[{index}].dependency.registry_contract",
            ),
            "dependency_name": dependency_name,
            "dependency_key": dependency_key,
            "dependency_key_preimage": key_preimage,
            "dependency_version": dependency_version,
        },
        "descriptor": {
            **descriptor_record,
            "schema_version": schema,
        },
        "source": {
            "registered_by": registered_by,
            "notes": source_notes,
            "provenance": provenance,
        },
        "files": sorted(file_records, key=lambda item: item["path"]),
        "artifact_digest": canonical_json_sha256(
            {
                "identity": artifact_identity(artifact),
                "descriptor": descriptor_record,
                "files": sorted(file_records, key=lambda item: item["path"]),
                "provenance": provenance,
                "registered_by": registered_by,
            }
        ),
    }


def build_attestation(repo_root: Path, manifest_path: Path, output_path: Path) -> dict[str, Any]:
    manifest = require_dict(load_json(manifest_path), str(manifest_path))
    if manifest.get("schema_version") != DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA:
        raise DependencyProvenanceAttestationError(
            f"{manifest_path}.schema_version must be {DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA}"
        )
    scan_no_secret_values(manifest)

    source = require_dict(manifest.get("source"), "manifest.source")
    artifacts = require_list(manifest.get("artifacts"), "manifest.artifacts")
    if not artifacts:
        raise DependencyProvenanceAttestationError("manifest.artifacts must not be empty")

    manifest_record = validate_file_record(
        repo_root,
        {
            "path": normalize_path(manifest_path, repo_root),
            "sha256": file_sha256(manifest_path),
            "size_bytes": manifest_path.stat().st_size,
        },
        "source.dependency_artifact_manifest",
    )

    artifact_attestations = [
        build_artifact_attestation(repo_root, require_dict(artifact, f"artifacts[{index}]"), index)
        for index, artifact in enumerate(artifacts)
    ]
    artifact_attestations.sort(
        key=lambda item: (
            item["identity"]["protocol_version"],
            item["identity"]["deployment_version"],
            item["identity"]["registry_contract"],
            item["identity"]["dependency_key"],
            item["identity"]["dependency_version"],
        )
    )

    seen_identities: set[tuple[str, str, str, str, int]] = set()
    for item in artifact_attestations:
        identity = item["identity"]
        key = (
            identity["protocol_version"],
            identity["deployment_version"],
            identity["registry_contract"],
            identity["dependency_key"],
            identity["dependency_version"],
        )
        if key in seen_identities:
            raise DependencyProvenanceAttestationError(f"duplicate dependency identity: {key}")
        seen_identities.add(key)

    descriptor_count = require_positive_int(source.get("descriptor_count"), "manifest.source.descriptor_count")
    if descriptor_count != len(artifact_attestations):
        raise DependencyProvenanceAttestationError(
            "manifest.source.descriptor_count must match artifacts length"
        )

    return {
        "schema_version": ATTESTATION_SCHEMA,
        "generated_by": f"scripts/generate_dependency_provenance_attestation.py:{GENERATOR_VERSION}",
        "release_status": {
            "project": "6529Stream",
            "status": "pre_audit_local_baseline",
            "claims": [
                "packaged dependency descriptors and source files exist in this checkout",
                "dependency artifact manifest hashes match files on disk",
                "dependency provenance strings are retained with the release bundle",
            ],
            "limitations": [
                "does not prove live chain registration",
                "does not prove public-beta or production readiness",
                "does not replace external audit or maintainer release signatures",
            ],
        },
        "source": {
            "output": normalize_path(output_path, repo_root),
            "dependency_artifact_manifest": manifest_record,
            "descriptor_dir": require_string(source.get("descriptor_dir"), "manifest.source.descriptor_dir"),
            "descriptor_count": descriptor_count,
        },
        "validation": {
            "commands": [
                "python scripts/test_dependency_artifact_manifest.py",
                "python scripts/generate_dependency_artifact_manifest.py --check",
                "python scripts/test_dependency_provenance_attestation.py",
                "python scripts/generate_dependency_provenance_attestation.py --check",
                "python scripts/generate_release_manifest.py --check",
                "python scripts/generate_release_checksums.py --check",
                "python scripts/verify_release_artifacts.py",
            ],
            "no_secret_policy": "attestation input and output reject secret-shaped values",
        },
        "artifacts": artifact_attestations,
    }


def build_output_text(repo_root: Path, manifest_path: Path, output_path: Path) -> str:
    return json.dumps(
        build_attestation(repo_root, manifest_path, output_path),
        indent=2,
        ensure_ascii=False,
    ) + "\n"


def write_output(repo_root: Path, manifest_path: Path, output_path: Path) -> Path:
    output_text = build_output_text(repo_root, manifest_path, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(repo_root: Path, manifest_path: Path, output_path: Path) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_dependency_provenance_attestation.py` and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(repo_root, manifest_path, output_path)
    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(f"changed {normalize_path(output_path, repo_root)}", file=sys.stderr)
            print(
                "run `python scripts/generate_dependency_provenance_attestation.py` and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("dependency provenance attestation is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_output(repo_root, args.manifest, args.output)
        written = write_output(repo_root, args.manifest, args.output)
    except DependencyProvenanceAttestationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"wrote {normalize_path(written, repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
