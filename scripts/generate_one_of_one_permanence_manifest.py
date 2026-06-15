#!/usr/bin/env python3
"""Generate the deterministic 1/1 permanence package release manifest."""

from __future__ import annotations

import argparse
import filecmp
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

import check_one_of_one_permanence_package as permanence_checker


PERMANENCE_RELEASE_MANIFEST_SCHEMA = (
    "6529stream.one-of-one-permanence-release-manifest.v1"
)
GENERATOR_VERSION = "1"

DEFAULT_DESCRIPTOR_DIR = Path("release-artifacts/permanence")
DEFAULT_OUTPUT = Path("release-artifacts/latest/one-of-one-permanence-manifest.json")


class PermanenceReleaseManifestError(RuntimeError):
    """Raised when the generated permanence manifest cannot be built."""


def load_json(path: Path) -> Any:
    """Load JSON with generator-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise PermanenceReleaseManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PermanenceReleaseManifestError(f"invalid JSON in {path}: {exc}") from exc


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path."""
    return permanence_checker.normalize_path(path, repo_root)


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    try:
        return permanence_checker.require_dict(value, path)
    except permanence_checker.PermanencePackageError as exc:
        raise PermanenceReleaseManifestError(str(exc)) from exc


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    try:
        return permanence_checker.require_string(value, path)
    except permanence_checker.PermanencePackageError as exc:
        raise PermanenceReleaseManifestError(str(exc)) from exc


def descriptor_record(repo_root: Path, descriptor_path: Path) -> dict[str, Any]:
    """Validate and summarize one permanence package descriptor."""
    try:
        permanence_checker.validate_package(descriptor_path, repo_root)
    except permanence_checker.PermanencePackageError as exc:
        raise PermanenceReleaseManifestError(
            f"invalid permanence descriptor {descriptor_path}: {exc}"
        ) from exc

    data = require_dict(load_json(descriptor_path), str(descriptor_path))
    scope = require_dict(data.get("scope"), f"{descriptor_path}.scope")
    renderer = require_dict(data.get("renderer"), f"{descriptor_path}.renderer")
    dependencies = require_dict(
        data.get("dependencies"), f"{descriptor_path}.dependencies"
    )
    replay = require_dict(data.get("replay"), f"{descriptor_path}.replay")
    output_evidence = require_dict(
        data.get("output_evidence"), f"{descriptor_path}.output_evidence"
    )
    storage = require_dict(
        data.get("storage_guarantees"), f"{descriptor_path}.storage_guarantees"
    )
    review = require_dict(data.get("review"), f"{descriptor_path}.review")
    retained = data.get("retained_artifacts")
    if not isinstance(retained, list):
        raise PermanenceReleaseManifestError(
            f"{descriptor_path}.retained_artifacts must be an array"
        )

    return {
        "descriptor": permanence_checker.file_record(
            descriptor_path, repo_root, schema_required=True
        ),
        "package_id": require_string(data.get("package_id"), "package_id"),
        "record_type": require_string(data.get("record_type"), "record_type"),
        "review_status": require_string(data.get("review_status"), "review_status"),
        "environment": require_string(data.get("environment"), "environment"),
        "protocol_version": require_string(
            data.get("protocol_version"), "protocol_version"
        ),
        "deployment_version": require_string(
            data.get("deployment_version"), "deployment_version"
        ),
        "scope": {
            "chain_id": scope.get("chain_id"),
            "core_contract": require_string(
                scope.get("core_contract"), "scope.core_contract"
            ),
            "contract_metadata_adapter": require_string(
                scope.get("contract_metadata_adapter"),
                "scope.contract_metadata_adapter",
            ),
            "collection_id": scope.get("collection_id"),
            "token_id": scope.get("token_id"),
            "metadata_schema_version": require_string(
                scope.get("metadata_schema_version"),
                "scope.metadata_schema_version",
            ),
            "contract_uri_hash": require_string(
                scope.get("contract_uri_hash"), "scope.contract_uri_hash"
            ),
            "collection_freeze_manifest_hash": require_string(
                scope.get("collection_freeze_manifest_hash"),
                "scope.collection_freeze_manifest_hash",
            ),
        },
        "renderer": {
            "renderer_name": require_string(
                renderer.get("renderer_name"), "renderer.renderer_name"
            ),
            "renderer_version": require_string(
                renderer.get("renderer_version"), "renderer.renderer_version"
            ),
            "rendering_mode": require_string(
                renderer.get("rendering_mode"), "renderer.rendering_mode"
            ),
        },
        "dependencies": {
            "dependency_registry": require_string(
                dependencies.get("dependency_registry"),
                "dependencies.dependency_registry",
            ),
            "dependency_count": dependencies.get("dependency_count"),
        },
        "replay": {
            "deterministic_replay_status": require_string(
                replay.get("deterministic_replay_status"),
                "replay.deterministic_replay_status",
            ),
            "replay_requires_network": replay.get("replay_requires_network"),
            "replay_command_count": len(replay.get("replay_commands", [])),
        },
        "output_evidence": {
            "metadata_json_sha256": require_string(
                output_evidence.get("metadata_json_sha256"),
                "output_evidence.metadata_json_sha256",
            ),
            "rendered_output_sha256": require_string(
                output_evidence.get("rendered_output_sha256"),
                "output_evidence.rendered_output_sha256",
            ),
            "browser_proof_status": require_string(
                output_evidence.get("browser_proof_status"),
                "output_evidence.browser_proof_status",
            ),
            "output_hash_status": require_string(
                output_evidence.get("output_hash_status"),
                "output_evidence.output_hash_status",
            ),
        },
        "storage_guarantees": {
            "fully_on_chain_components": storage.get("fully_on_chain_components"),
            "decentralized_storage_components": storage.get(
                "decentralized_storage_components"
            ),
            "external_service_dependencies": storage.get(
                "external_service_dependencies"
            ),
        },
        "retained_artifact_count": len(retained),
        "review": {
            "approval_status": require_string(
                review.get("approval_status"), "review.approval_status"
            ),
            "reviewer": require_string(review.get("reviewer"), "review.reviewer"),
        },
    }


def record_identity(record: dict[str, Any]) -> tuple[str, str, int, str, int, int, str]:
    """Return the uniqueness key for a permanence package record."""
    scope = require_dict(record.get("scope"), "record.scope")
    return (
        require_string(record.get("protocol_version"), "record.protocol_version"),
        require_string(record.get("deployment_version"), "record.deployment_version"),
        int(scope.get("chain_id")),
        require_string(scope.get("core_contract"), "record.scope.core_contract").lower(),
        int(scope.get("collection_id")),
        int(scope.get("token_id")),
        require_string(record.get("package_id"), "record.package_id"),
    )


def build_manifest(repo_root: Path, descriptor_dir: Path, output_path: Path) -> dict[str, Any]:
    """Build the generated permanence release manifest."""
    descriptor_root = descriptor_dir if descriptor_dir.is_absolute() else repo_root / descriptor_dir
    records = [
        descriptor_record(repo_root, path)
        for path in permanence_checker.descriptor_files(descriptor_root)
    ]
    records.sort(key=record_identity)

    seen: dict[tuple[str, str, int, str, int, int, str], str] = {}
    for record in records:
        identity = record_identity(record)
        descriptor_path = require_dict(record.get("descriptor"), "record.descriptor")[
            "path"
        ]
        if identity in seen:
            raise PermanenceReleaseManifestError(
                "duplicate permanence package identity: "
                f"{identity} in {seen[identity]} and {descriptor_path}"
            )
        seen[identity] = str(descriptor_path)

    return {
        "schema_version": PERMANENCE_RELEASE_MANIFEST_SCHEMA,
        "generated_by": f"scripts/generate_one_of_one_permanence_manifest.py:{GENERATOR_VERSION}",
        "source": {
            "output": normalize_path(output_path, repo_root),
            "descriptor_dir": normalize_path(descriptor_root, repo_root),
            "descriptor_count": len(records),
        },
        "packages": records,
    }


def build_output_text(repo_root: Path, descriptor_dir: Path, output_path: Path) -> str:
    """Build deterministic JSON output text."""
    return json.dumps(
        build_manifest(repo_root, descriptor_dir, output_path),
        indent=2,
        ensure_ascii=False,
    ) + "\n"


def write_output(repo_root: Path, descriptor_dir: Path, output_path: Path) -> Path:
    """Write the generated permanence manifest."""
    output_text = build_output_text(repo_root, descriptor_dir, output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(output_text, encoding="utf-8", newline="\n")
    return output_path


def check_output(repo_root: Path, descriptor_dir: Path, output_path: Path) -> int:
    """Check that the committed generated manifest is current."""
    if not output_path.exists():
        print(f"missing {normalize_path(output_path, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_one_of_one_permanence_manifest.py` and commit the regenerated file",
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
                "run `python scripts/generate_one_of_one_permanence_manifest.py` and commit the regenerated file",
                file=sys.stderr,
            )
            return 1

    print("1/1 permanence release manifest is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--descriptor-dir", type=Path, default=DEFAULT_DESCRIPTOR_DIR)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    """Run the generator."""
    args = parse_args(argv)
    repo_root = Path.cwd()

    try:
        if args.check:
            return check_output(repo_root, args.descriptor_dir, args.output)
        written = write_output(repo_root, args.descriptor_dir, args.output)
    except PermanenceReleaseManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    print(f"wrote {normalize_path(written, repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
