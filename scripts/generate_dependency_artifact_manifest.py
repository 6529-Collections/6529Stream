#!/usr/bin/env python3
"""Generate a deterministic dependency artifact manifest."""

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


DEPENDENCY_ARTIFACT_SCHEMA = "6529stream.dependency-artifact.v1"
DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA = "6529stream.dependency-artifact-manifest.v1"
GENERATOR_VERSION = "1"

DEFAULT_DESCRIPTOR_DIR = Path("release-artifacts/dependencies")
DEFAULT_OUTPUT = Path("release-artifacts/latest/dependency-artifact-manifest.json")
DESCRIPTOR_GLOB = "*.dependency.json"

HEX32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")


class DependencyArtifactError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise DependencyArtifactError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise DependencyArtifactError(f"invalid JSON in {path}: {exc}") from exc


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


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    if not path.is_file():
        raise DependencyArtifactError(f"missing required file: {path}")
    record: dict[str, Any] = {
        "path": normalize_path(path, repo_root),
        "sha256": file_sha256(path),
        "size_bytes": path.stat().st_size,
    }
    if path.suffix == ".json":
        data = load_json(path)
        schema = data.get("schema_version") if isinstance(data, dict) else None
        if not isinstance(schema, str) or schema == "":
            raise DependencyArtifactError(f"{path} is missing a schema version")
        record["schema_version"] = schema
    return record


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise DependencyArtifactError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise DependencyArtifactError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise DependencyArtifactError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise DependencyArtifactError(f"{path} must be a positive integer")
    return value


def require_dependency_key(value: Any, path: str) -> str:
    key = require_string(value, path).lower()
    if not HEX32_RE.fullmatch(key):
        raise DependencyArtifactError(f"{path} must be a 32-byte hex string")
    return key


def resolve_artifact_path(
    repo_root: Path,
    descriptor_dir: Path,
    relative_path: str,
    field_path: str,
) -> Path:
    if relative_path.startswith("/") or "\\" in relative_path:
        raise DependencyArtifactError(f"{field_path} must be a repo-relative POSIX path")
    path = Path(relative_path)
    if ".." in path.parts:
        raise DependencyArtifactError(f"{field_path} must not contain parent-directory segments")
    resolved = (repo_root / path).resolve()
    try:
        resolved.relative_to(descriptor_dir.resolve())
    except ValueError as exc:
        raise DependencyArtifactError(
            f"{field_path} must stay under {normalize_path(descriptor_dir, repo_root)}"
        ) from exc
    return resolved


def descriptor_files(descriptor_dir: Path) -> list[Path]:
    if not descriptor_dir.is_dir():
        raise DependencyArtifactError(f"missing descriptor directory: {descriptor_dir}")
    files = sorted(path for path in descriptor_dir.rglob(DESCRIPTOR_GLOB) if path.is_file())
    if not files:
        raise DependencyArtifactError(
            f"descriptor directory has no {DESCRIPTOR_GLOB} descriptors: {descriptor_dir}"
        )
    return files


def dependency_record(
    repo_root: Path,
    descriptor_dir: Path,
    descriptor_path: Path,
) -> dict[str, Any]:
    data = require_dict(load_json(descriptor_path), str(descriptor_path))
    schema = require_string(data.get("schema_version"), f"{descriptor_path}.schema_version")
    if schema != DEPENDENCY_ARTIFACT_SCHEMA:
        raise DependencyArtifactError(
            f"{descriptor_path}.schema_version must be {DEPENDENCY_ARTIFACT_SCHEMA}"
        )

    protocol_version = require_string(data.get("protocol_version"), "protocol_version")
    deployment_version = require_string(data.get("deployment_version"), "deployment_version")
    dependency = require_dict(data.get("dependency"), "dependency")
    source = require_dict(data.get("source"), "source")
    files = require_list(data.get("files"), "files")
    if not files:
        raise DependencyArtifactError("files must contain at least one artifact file")

    dependency_name = require_string(dependency.get("name"), "dependency.name")
    dependency_key = require_dependency_key(dependency.get("key"), "dependency.key")
    dependency_key_preimage = require_string(dependency.get("key_preimage"), "dependency.key_preimage")
    dependency_version = require_positive_int(dependency.get("version"), "dependency.version")
    registry_contract = require_string(dependency.get("registry_contract"), "dependency.registry_contract")
    provenance = require_string(dependency.get("provenance"), "dependency.provenance")
    source_notes = source.get("notes", "")
    if not isinstance(source_notes, str):
        raise DependencyArtifactError("source.notes must be a string when provided")

    artifact_files = []
    seen_paths: set[str] = set()
    for index, file_entry in enumerate(files):
        entry = require_dict(file_entry, f"files[{index}]")
        path_text = require_string(entry.get("path"), f"files[{index}].path")
        artifact_path = resolve_artifact_path(repo_root, descriptor_dir, path_text, f"files[{index}].path")
        normalized = normalize_path(artifact_path, repo_root)
        if normalized in seen_paths:
            raise DependencyArtifactError(f"duplicate artifact file path: {normalized}")
        seen_paths.add(normalized)
        artifact_record = file_record(artifact_path, repo_root)
        artifact_record.update(
            {
                "role": require_string(entry.get("role"), f"files[{index}].role"),
                "media_type": require_string(entry.get("media_type"), f"files[{index}].media_type"),
            }
        )
        artifact_files.append(artifact_record)

    return {
        "descriptor": file_record(descriptor_path, repo_root),
        "protocol_version": protocol_version,
        "deployment_version": deployment_version,
        "dependency": {
            "name": dependency_name,
            "key": dependency_key,
            "key_preimage": dependency_key_preimage,
            "version": dependency_version,
            "registry_contract": registry_contract,
            "provenance": provenance,
        },
        "source": {
            "registered_by": require_string(source.get("registered_by"), "source.registered_by"),
            "notes": source_notes,
        },
        "files": artifact_files,
    }


def artifact_identity(record: dict[str, Any]) -> tuple[str, str, str, str, int]:
    dependency = require_dict(record.get("dependency"), "record.dependency")
    return (
        require_string(record.get("protocol_version"), "record.protocol_version"),
        require_string(record.get("deployment_version"), "record.deployment_version"),
        require_string(dependency.get("registry_contract"), "record.dependency.registry_contract"),
        require_dependency_key(dependency.get("key"), "record.dependency.key"),
        require_positive_int(dependency.get("version"), "record.dependency.version"),
    )


def build_manifest(repo_root: Path, descriptor_dir: Path, output_path: Path) -> dict[str, Any]:
    records = [
        dependency_record(repo_root, descriptor_dir, path)
        for path in descriptor_files(descriptor_dir)
    ]
    records.sort(key=artifact_identity)

    seen: dict[tuple[str, str, str, str, int], str] = {}
    for record in records:
        identity = artifact_identity(record)
        descriptor_path = require_dict(record.get("descriptor"), "record.descriptor")["path"]
        if identity in seen:
            raise DependencyArtifactError(
                f"duplicate dependency artifact identity: {identity} in {seen[identity]} and {descriptor_path}"
            )
        seen[identity] = str(descriptor_path)

    return {
        "schema_version": DEPENDENCY_ARTIFACT_MANIFEST_SCHEMA,
        "generated_by": f"scripts/generate_dependency_artifact_manifest.py:{GENERATOR_VERSION}",
        "source": {
            "output": normalize_path(output_path, repo_root),
            "descriptor_dir": normalize_path(descriptor_dir, repo_root),
            "descriptor_count": len(records),
        },
        "artifacts": records,
    }


def build_output_text(repo_root: Path, descriptor_dir: Path, output_path: Path) -> str:
    return json.dumps(
        build_manifest(repo_root, descriptor_dir, output_path),
        indent=2,
        ensure_ascii=False,
    ) + "\n"


def write_output(repo_root: Path, descriptor_dir: Path, output_path: Path) -> Path:
    output_text = build_output_text(repo_root, descriptor_dir, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(repo_root: Path, descriptor_dir: Path, output_path: Path) -> int:
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_dependency_artifact_manifest.py` and commit the regenerated file",
            file=sys.stderr,
        )
        return 1

    expected_text = build_output_text(repo_root, descriptor_dir, output_path)
    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        expected.write_text(expected_text, encoding="utf-8", newline="\n")
        if not filecmp.cmp(expected, output_path, shallow=False):
            print(f"changed {normalize_path(output_path, repo_root)}", file=sys.stderr)
            print(
                "run `python scripts/generate_dependency_artifact_manifest.py` and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("dependency artifact manifest is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-dir", type=Path, default=DEFAULT_DESCRIPTOR_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_output(repo_root, args.descriptor_dir, args.output)
        written = write_output(repo_root, args.descriptor_dir, args.output)
    except DependencyArtifactError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"wrote {normalize_path(written, repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
