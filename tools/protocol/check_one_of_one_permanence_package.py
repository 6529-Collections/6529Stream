#!/usr/bin/env python3
"""Validate collector-verifiable 1/1 permanence package descriptors."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit


PERMANENCE_SCHEMA = "6529stream.one-of-one-permanence-package.v1"
LOCAL_PLACEHOLDER_STATUS = "not_available_local"
SELF_REFERENTIAL_STATUS = "not_available_self_referential"

DEFAULT_DESCRIPTOR_DIR = Path("release-artifacts/permanence")
DESCRIPTOR_GLOB = "*.permanence.json"

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "package_id",
        "record_type",
        "review_status",
        "environment",
        "protocol_version",
        "deployment_version",
        "source",
        "scope",
        "renderer",
        "dependencies",
        "source_archive",
        "replay",
        "output_evidence",
        "storage_guarantees",
        "release_bindings",
        "integration_guidance",
        "review",
        "retained_artifacts",
        "redaction_policy",
        "template_notice",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
SCOPE_FIELDS = frozenset(
    {
        "scope_type",
        "chain_id",
        "core_contract",
        "contract_metadata_adapter",
        "collection_id",
        "token_id",
        "token_standard",
        "metadata_schema_version",
        "contract_uri_hash",
        "collection_freeze_manifest_hash",
    }
)
RENDERER_FIELDS = frozenset(
    {
        "renderer_name",
        "renderer_version",
        "renderer_contract",
        "renderer_source",
        "rendering_mode",
        "runtime_assumptions",
    }
)
RUNTIME_FIELDS = frozenset({"browser", "node", "python", "foundry", "notes"})
DEPENDENCIES_FIELDS = frozenset(
    {
        "dependency_artifact_manifest",
        "dependency_registry",
        "dependency_count",
        "dependency_records",
    }
)
DEPENDENCY_RECORD_FIELDS = frozenset(
    {
        "dependency_key",
        "version",
        "content_sha256",
        "provenance_sha256",
        "source_status",
    }
)
SOURCE_ARCHIVE_FIELDS = frozenset(
    {"archive_status", "repository_archive_uri", "archive_sha256", "included_files"}
)
REPLAY_FIELDS = frozenset(
    {
        "deterministic_replay_status",
        "replay_requires_network",
        "replay_commands",
        "expected_replay_outputs",
    }
)
REPLAY_COMMAND_FIELDS = frozenset({"command", "purpose", "working_directory"})
OUTPUT_EVIDENCE_FIELDS = frozenset(
    {
        "metadata_json_sha256",
        "animation_html_sha256",
        "image_sha256",
        "rendered_output_sha256",
        "browser_proof_sha256",
        "browser_proof_status",
        "output_hash_status",
    }
)
STORAGE_GUARANTEE_FIELDS = frozenset(
    {
        "fully_on_chain_components",
        "decentralized_storage_components",
        "external_service_dependencies",
        "gateway_assumptions",
        "permanence_summary",
        "known_failure_modes",
    }
)
RELEASE_BINDINGS_FIELDS = frozenset(
    {
        "release_manifest",
        "release_checksums",
        "dependency_artifact_manifest",
        "one_of_one_provenance_manifest",
    }
)
BINDING_REF_FIELDS = frozenset({"path", "sha256", "status"})
INTEGRATION_GUIDANCE_FIELDS = frozenset(
    {
        "collector_verification",
        "frontend_replay",
        "indexer_binding",
        "marketplace_boundary",
    }
)
REVIEW_FIELDS = frozenset(
    {"owner", "reviewer", "approval_status", "approval_reference", "reviewed_at"}
)
RETAINED_ARTIFACT_FIELDS = frozenset({"category", "path", "sha256"})
REDACTION_POLICY_FIELDS = frozenset({"no_secrets", "redacted_fields"})

RECORD_TYPES = frozenset({"template", "evidence"})
REVIEW_STATUSES = frozenset({"template", "pending_review", "reviewed"})
ENVIRONMENTS = frozenset({"local", "fork", "testnet", "mainnet", "production"})
NON_LOCAL_ENVIRONMENTS = frozenset({"fork", "testnet", "mainnet", "production"})
PRODUCTION_ENVIRONMENTS = frozenset({"mainnet", "production"})
RENDERING_MODES = frozenset(
    {"on_chain_metadata", "animation_html", "off_chain_media", "hybrid"}
)
SOURCE_STATUSES = frozenset({"template", "pending_review", "reviewed"})
ARCHIVE_STATUSES = frozenset({"template", "pending_review", "reviewed"})
REPLAY_STATUSES = frozenset(
    {"template", "pending_review", "reviewed_replayable", "blocked_missing_final_output"}
)
BROWSER_PROOF_STATUSES = frozenset(
    {"template", "pending_review", "reviewed", "not_available_local"}
)
OUTPUT_HASH_STATUSES = frozenset(
    {"template", "pending_review", "reviewed", "not_available_local"}
)
BINDING_STATUSES = frozenset(
    {"template", "pending_review", "reviewed", "self_referential"}
)
APPROVAL_STATUSES = frozenset({"template", "pending", "approved", "rejected"})
LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {
        "permanence_schema",
        "permanence_retained_artifact_template",
        "permanence_runbook",
        "dependency_artifact_manifest",
        "provenance_manifest",
    }
)

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
BYTES32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
SAFE_CONTENT_SCHEMES = frozenset({"ar", "https", "ipfs"})
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|client[_\-\s]?secret|session[_\-\s]?cookie|"
    r"bearer[_\-\s]?token|raw[_\-\s]?signature|unreleased[_\-\s]?drop[_\-\s]?payload"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|rpc[_ -]?url|api[_ -]?key|"
    r"password|client[_ -]?secret|session[_ -]?cookie|bearer[_ -]?token|"
    r"raw[_ -]?signature|unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)


class PermanencePackageError(RuntimeError):
    """Raised when a permanence package descriptor is invalid."""


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise PermanencePackageError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PermanencePackageError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    """Return a sha256-prefixed digest."""
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    """Hash a file using the release artifact digest format."""
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def normalized_text_bytes(path: Path) -> bytes:
    """Return text bytes with repository-stable LF line endings."""
    return path.read_bytes().replace(b"\r\n", b"\n")


def normalized_text_sha256(path: Path) -> str:
    """Hash text using repository-stable LF line endings."""
    return sha256_bytes(normalized_text_bytes(path))


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def file_record(path: Path, repo_root: Path, *, schema_required: bool = False) -> dict[str, Any]:
    """Return a deterministic file record."""
    if not path.is_file():
        raise PermanencePackageError(f"missing required file: {path}")
    record_bytes = normalized_text_bytes(path)
    record: dict[str, Any] = {
        "path": normalize_path(path, repo_root),
        "sha256": sha256_bytes(record_bytes),
        "size_bytes": len(record_bytes),
    }
    if path.suffix == ".json" or schema_required:
        data = load_json(path)
        schema = data.get("schema_version") if isinstance(data, dict) else None
        if not isinstance(schema, str) or schema == "":
            raise PermanencePackageError(f"{path} is missing a schema version")
        record["schema_version"] = schema
    return record


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise PermanencePackageError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise PermanencePackageError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise PermanencePackageError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise PermanencePackageError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value.strip() == "":
        raise PermanencePackageError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise PermanencePackageError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise PermanencePackageError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer."""
    number = require_int(value, path)
    if number < 1:
        raise PermanencePackageError(f"{path} must be greater than zero")
    return number


def require_non_negative_int(value: Any, path: str) -> int:
    """Require a non-negative integer."""
    number = require_int(value, path)
    if number < 0:
        raise PermanencePackageError(f"{path} must be zero or greater")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from an enum set."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise PermanencePackageError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise PermanencePackageError(f"{path} must be a sha256: hash")
    return digest


def require_sha256_or_placeholder(value: Any, path: str) -> str:
    """Require a digest or a documented unavailable status."""
    digest = require_string(value, path)
    if digest in {LOCAL_PLACEHOLDER_STATUS, SELF_REFERENTIAL_STATUS}:
        return digest
    return require_sha256(digest, path)


def require_git_commit(value: Any, path: str) -> str:
    """Require a 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise PermanencePackageError(
            f"{path} must be a 40-character git commit hash"
        )
    return commit


def require_address(value: Any, path: str) -> str:
    """Require an Ethereum address."""
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise PermanencePackageError(f"{path} must be an address")
    return address.lower()


def require_bytes32(value: Any, path: str) -> str:
    """Require a bytes32 hex value."""
    value_text = require_string(value, path)
    if not BYTES32_RE.fullmatch(value_text):
        raise PermanencePackageError(f"{path} must be a bytes32 value")
    return value_text.lower()


def require_non_placeholder(value: Any, path: str) -> str:
    """Require a non-placeholder string."""
    text = require_string(value, path)
    if text in {LOCAL_PLACEHOLDER_STATUS, SELF_REFERENTIAL_STATUS}:
        raise PermanencePackageError(f"{path} must not be a placeholder")
    if text.strip().upper() == "TBD":
        raise PermanencePackageError(f"{path} must not be TBD")
    return text


def require_rfc3339_datetime(value: Any, path: str) -> str:
    """Require an RFC3339 timestamp with an explicit timezone."""
    text = require_non_placeholder(value, path)
    normalized = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise PermanencePackageError(f"{path} must be an RFC3339 date-time") from exc
    if parsed.tzinfo is None:
        raise PermanencePackageError(f"{path} must include an explicit timezone")
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file without allowing escapes."""
    if "\\" in relative_path:
        raise PermanencePackageError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise PermanencePackageError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise PermanencePackageError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise PermanencePackageError(
            f"{path} references missing file: {relative_path}"
        )
    return resolved


def validate_file_ref(value: Any, repo_root: Path, path: str) -> Path:
    """Validate a repository-relative file/hash reference."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, RETAINED_ARTIFACT_FIELDS)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise PermanencePackageError(
            f"{path}.sha256 mismatch for {relative_path}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed descriptors."""
    if path == "$.redaction_policy" or path.startswith("$.redaction_policy."):
        return
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            if SECRET_KEY_RE.search(key_text):
                raise PermanencePackageError(
                    f"secret-like key found at {path}.{key_text}"
                )
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise PermanencePackageError(f"secret-like value found at {path}")


def validate_uri(value: Any, path: str, *, allow_placeholder: bool = True) -> str:
    """Validate a safe content URI or local placeholder."""
    uri = require_string(value, path)
    if allow_placeholder and uri == LOCAL_PLACEHOLDER_STATUS:
        return uri
    if uri != uri.strip():
        raise PermanencePackageError(f"{path} has leading or trailing whitespace")
    for character in uri:
        codepoint = ord(character)
        if codepoint <= 0x20 or codepoint == 0x7F:
            raise PermanencePackageError(
                f"{path} contains whitespace or control characters"
            )
    parsed = urlsplit(uri)
    if parsed.scheme not in SAFE_CONTENT_SCHEMES:
        allowed = ", ".join(sorted(SAFE_CONTENT_SCHEMES))
        raise PermanencePackageError(
            f"{path} scheme {parsed.scheme or '<none>'} is not allowed; expected {allowed}"
        )
    if parsed.scheme == "https" and not parsed.netloc:
        raise PermanencePackageError(f"{path} HTTPS URI is missing a host")
    if parsed.scheme in {"ar", "ipfs"} and not (parsed.netloc or parsed.path):
        raise PermanencePackageError(f"{path} content URI is missing an identifier")
    return uri


def validate_source(value: Any) -> None:
    """Validate source control metadata."""
    source = require_dict(value, "source")
    require_exact_keys(source, "source", SOURCE_FIELDS)
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit")
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_scope(value: Any, review_status: str, environment: str) -> dict[str, Any]:
    """Validate chain/token binding metadata."""
    scope = require_dict(value, "scope")
    require_exact_keys(scope, "scope", SCOPE_FIELDS)
    require_enum(scope.get("scope_type"), "scope.scope_type", frozenset({"one_of_one_token"}))
    require_positive_int(scope.get("chain_id"), "scope.chain_id")
    core_contract = require_address(scope.get("core_contract"), "scope.core_contract")
    adapter = require_address(
        scope.get("contract_metadata_adapter"), "scope.contract_metadata_adapter"
    )
    require_non_negative_int(scope.get("collection_id"), "scope.collection_id")
    token_id = require_non_negative_int(scope.get("token_id"), "scope.token_id")
    require_enum(scope.get("token_standard"), "scope.token_standard", frozenset({"ERC721"}))
    require_string(scope.get("metadata_schema_version"), "scope.metadata_schema_version")
    contract_uri_hash = require_bytes32(
        scope.get("contract_uri_hash"), "scope.contract_uri_hash"
    )
    freeze_hash = require_bytes32(
        scope.get("collection_freeze_manifest_hash"),
        "scope.collection_freeze_manifest_hash",
    )

    if environment in PRODUCTION_ENVIRONMENTS or review_status == "reviewed":
        if core_contract == "0x" + "0" * 40:
            raise PermanencePackageError("reviewed permanence cannot use zero core contract")
        if adapter == "0x" + "0" * 40:
            raise PermanencePackageError(
                "reviewed permanence cannot use zero contract metadata adapter"
            )
        if token_id == 0:
            raise PermanencePackageError("reviewed permanence token_id must be nonzero")
        if contract_uri_hash == "0x" + "0" * 64:
            raise PermanencePackageError(
                "reviewed permanence cannot use zero contract_uri_hash"
            )
        if freeze_hash == "0x" + "0" * 64:
            raise PermanencePackageError(
                "reviewed permanence cannot use zero collection_freeze_manifest_hash"
            )
    return scope


def validate_runtime_assumptions(value: Any) -> None:
    """Validate replay runtime assumptions."""
    runtime = require_dict(value, "renderer.runtime_assumptions")
    require_exact_keys(runtime, "renderer.runtime_assumptions", RUNTIME_FIELDS)
    for field in sorted(RUNTIME_FIELDS):
        require_string(runtime.get(field), f"renderer.runtime_assumptions.{field}")


def validate_renderer(value: Any, repo_root: Path, review_status: str) -> dict[str, Any]:
    """Validate renderer binding metadata."""
    renderer = require_dict(value, "renderer")
    require_exact_keys(renderer, "renderer", RENDERER_FIELDS)
    for field in ("renderer_name", "renderer_version"):
        text = require_string(renderer.get(field), f"renderer.{field}")
        if review_status == "reviewed":
            require_non_placeholder(text, f"renderer.{field}")
    address = require_address(renderer.get("renderer_contract"), "renderer.renderer_contract")
    validate_file_ref(renderer.get("renderer_source"), repo_root, "renderer.renderer_source")
    require_enum(renderer.get("rendering_mode"), "renderer.rendering_mode", RENDERING_MODES)
    validate_runtime_assumptions(renderer.get("runtime_assumptions"))
    if review_status == "reviewed" and address == "0x" + "0" * 40:
        raise PermanencePackageError("reviewed permanence cannot use zero renderer_contract")
    return renderer


def validate_dependency_records(value: Any, review_status: str) -> list[dict[str, Any]]:
    """Validate dependency hash records."""
    records = require_list(value, "dependencies.dependency_records")
    if not records:
        raise PermanencePackageError("dependencies.dependency_records must not be empty")
    seen: set[tuple[str, int]] = set()
    validated: list[dict[str, Any]] = []
    for index, item in enumerate(records):
        record = require_dict(item, f"dependencies.dependency_records[{index}]")
        require_exact_keys(
            record,
            f"dependencies.dependency_records[{index}]",
            DEPENDENCY_RECORD_FIELDS,
        )
        key = require_string(
            record.get("dependency_key"),
            f"dependencies.dependency_records[{index}].dependency_key",
        )
        version = require_positive_int(
            record.get("version"),
            f"dependencies.dependency_records[{index}].version",
        )
        identity = (key, version)
        if identity in seen:
            raise PermanencePackageError(
                f"duplicate dependency record: {key}@{version}"
            )
        seen.add(identity)
        for field in ("content_sha256", "provenance_sha256"):
            digest = require_sha256_or_placeholder(
                record.get(field), f"dependencies.dependency_records[{index}].{field}"
            )
            if review_status == "reviewed" and digest == LOCAL_PLACEHOLDER_STATUS:
                raise PermanencePackageError(
                    f"reviewed permanence requires dependency {field}"
                )
        status = require_enum(
            record.get("source_status"),
            f"dependencies.dependency_records[{index}].source_status",
            SOURCE_STATUSES,
        )
        if review_status == "reviewed" and status != "reviewed":
            raise PermanencePackageError("reviewed permanence requires reviewed dependencies")
        validated.append(record)
    return validated


def validate_dependencies(value: Any, repo_root: Path, review_status: str) -> None:
    """Validate dependency manifest bindings."""
    dependencies = require_dict(value, "dependencies")
    require_exact_keys(dependencies, "dependencies", DEPENDENCIES_FIELDS)
    validate_file_ref(
        dependencies.get("dependency_artifact_manifest"),
        repo_root,
        "dependencies.dependency_artifact_manifest",
    )
    address = require_address(
        dependencies.get("dependency_registry"), "dependencies.dependency_registry"
    )
    count = require_non_negative_int(
        dependencies.get("dependency_count"), "dependencies.dependency_count"
    )
    records = validate_dependency_records(
        dependencies.get("dependency_records"), review_status
    )
    if count != len(records):
        raise PermanencePackageError(
            "dependencies.dependency_count must equal dependency_records length"
        )
    if review_status == "reviewed" and address == "0x" + "0" * 40:
        raise PermanencePackageError("reviewed permanence cannot use zero dependency_registry")


def validate_source_archive(value: Any, repo_root: Path, review_status: str) -> None:
    """Validate source archive and included file hashes."""
    archive = require_dict(value, "source_archive")
    require_exact_keys(archive, "source_archive", SOURCE_ARCHIVE_FIELDS)
    status = require_enum(
        archive.get("archive_status"), "source_archive.archive_status", ARCHIVE_STATUSES
    )
    validate_uri(archive.get("repository_archive_uri"), "source_archive.repository_archive_uri")
    archive_hash = require_sha256_or_placeholder(
        archive.get("archive_sha256"), "source_archive.archive_sha256"
    )
    files = require_list(archive.get("included_files"), "source_archive.included_files")
    if not files:
        raise PermanencePackageError("source_archive.included_files must not be empty")
    seen_paths: set[str] = set()
    for index, item in enumerate(files):
        ref = require_dict(item, f"source_archive.included_files[{index}]")
        relative_path = require_string(
            ref.get("path"), f"source_archive.included_files[{index}].path"
        )
        if relative_path in seen_paths:
            raise PermanencePackageError(
                f"duplicate source_archive.included_files path: {relative_path}"
            )
        seen_paths.add(relative_path)
        validate_file_ref(ref, repo_root, f"source_archive.included_files[{index}]")
    if review_status == "reviewed":
        if status != "reviewed":
            raise PermanencePackageError("reviewed permanence requires reviewed source archive")
        if archive_hash == LOCAL_PLACEHOLDER_STATUS:
            raise PermanencePackageError("reviewed permanence requires archive_sha256")


def validate_replay(value: Any, review_status: str) -> str:
    """Validate deterministic replay instructions."""
    replay = require_dict(value, "replay")
    require_exact_keys(replay, "replay", REPLAY_FIELDS)
    replay_status = require_enum(
        replay.get("deterministic_replay_status"),
        "replay.deterministic_replay_status",
        REPLAY_STATUSES,
    )
    require_bool(replay.get("replay_requires_network"), "replay.replay_requires_network")
    commands = require_list(replay.get("replay_commands"), "replay.replay_commands")
    if not commands:
        raise PermanencePackageError("replay.replay_commands must not be empty")
    for index, item in enumerate(commands):
        command = require_dict(item, f"replay.replay_commands[{index}]")
        require_exact_keys(
            command, f"replay.replay_commands[{index}]", REPLAY_COMMAND_FIELDS
        )
        for field in sorted(REPLAY_COMMAND_FIELDS):
            require_string(command.get(field), f"replay.replay_commands[{index}].{field}")
    outputs = require_list(
        replay.get("expected_replay_outputs"), "replay.expected_replay_outputs"
    )
    if not outputs:
        raise PermanencePackageError("replay.expected_replay_outputs must not be empty")
    for index, output in enumerate(outputs):
        require_string(output, f"replay.expected_replay_outputs[{index}]")
    if review_status == "reviewed" and replay_status != "reviewed_replayable":
        raise PermanencePackageError("reviewed permanence requires reviewed_replayable status")
    return replay_status


def validate_output_evidence(value: Any, review_status: str) -> dict[str, Any]:
    """Validate rendered output hashes and browser proof."""
    evidence = require_dict(value, "output_evidence")
    require_exact_keys(evidence, "output_evidence", OUTPUT_EVIDENCE_FIELDS)
    for field in (
        "metadata_json_sha256",
        "animation_html_sha256",
        "image_sha256",
        "rendered_output_sha256",
        "browser_proof_sha256",
    ):
        digest = require_sha256_or_placeholder(evidence.get(field), f"output_evidence.{field}")
        if review_status == "reviewed" and digest == LOCAL_PLACEHOLDER_STATUS:
            raise PermanencePackageError(f"reviewed permanence requires {field}")
    browser_status = require_enum(
        evidence.get("browser_proof_status"),
        "output_evidence.browser_proof_status",
        BROWSER_PROOF_STATUSES,
    )
    output_status = require_enum(
        evidence.get("output_hash_status"),
        "output_evidence.output_hash_status",
        OUTPUT_HASH_STATUSES,
    )
    if review_status == "reviewed":
        if browser_status != "reviewed":
            raise PermanencePackageError("reviewed permanence requires reviewed browser proof")
        if output_status != "reviewed":
            raise PermanencePackageError("reviewed permanence requires reviewed output hashes")
    return evidence


def validate_string_list(value: Any, path: str, *, minimum: int = 1) -> list[str]:
    """Validate a list of non-empty strings."""
    items = require_list(value, path)
    if len(items) < minimum:
        raise PermanencePackageError(f"{path} must contain at least {minimum} item(s)")
    strings = []
    for index, item in enumerate(items):
        strings.append(require_string(item, f"{path}[{index}]"))
    return strings


def validate_storage_guarantees(value: Any) -> None:
    """Validate explicit on-chain and storage-boundary statements."""
    guarantees = require_dict(value, "storage_guarantees")
    require_exact_keys(guarantees, "storage_guarantees", STORAGE_GUARANTEE_FIELDS)
    validate_string_list(
        guarantees.get("fully_on_chain_components"),
        "storage_guarantees.fully_on_chain_components",
    )
    validate_string_list(
        guarantees.get("decentralized_storage_components"),
        "storage_guarantees.decentralized_storage_components",
    )
    validate_string_list(
        guarantees.get("external_service_dependencies"),
        "storage_guarantees.external_service_dependencies",
    )
    validate_string_list(
        guarantees.get("gateway_assumptions"),
        "storage_guarantees.gateway_assumptions",
    )
    validate_string_list(
        guarantees.get("known_failure_modes"),
        "storage_guarantees.known_failure_modes",
    )
    summary = require_string(
        guarantees.get("permanence_summary"), "storage_guarantees.permanence_summary"
    )
    normalized = " ".join(summary.lower().split())
    if "fully on-chain" not in normalized:
        raise PermanencePackageError(
            "storage_guarantees.permanence_summary must mention fully on-chain"
        )
    if "decentralized storage" not in normalized:
        raise PermanencePackageError(
            "storage_guarantees.permanence_summary must mention decentralized storage"
        )


def validate_binding_ref(value: Any, repo_root: Path, path: str, review_status: str) -> None:
    """Validate a release artifact binding reference."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, BINDING_REF_FIELDS)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    digest = require_sha256_or_placeholder(ref.get("sha256"), f"{path}.sha256")
    status = require_enum(ref.get("status"), f"{path}.status", BINDING_STATUSES)
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    if digest.startswith("sha256:"):
        actual_hash = file_sha256(resolved)
        if actual_hash != digest:
            raise PermanencePackageError(
                f"{path}.sha256 mismatch for {relative_path}: "
                f"expected {digest}, got {actual_hash}"
            )
    if status == "self_referential" and digest != SELF_REFERENTIAL_STATUS:
        raise PermanencePackageError(
            f"{path}.sha256 must be {SELF_REFERENTIAL_STATUS} for self_referential bindings"
        )
    if status != "self_referential" and digest == SELF_REFERENTIAL_STATUS:
        raise PermanencePackageError(
            f"{path}.sha256 cannot be self-referential unless status is self_referential"
        )
    if review_status == "reviewed" and status not in {"reviewed", "self_referential"}:
        raise PermanencePackageError(f"reviewed permanence requires reviewed {path}")
    if review_status == "reviewed" and digest == LOCAL_PLACEHOLDER_STATUS:
        raise PermanencePackageError(f"reviewed permanence requires {path}.sha256")


def validate_release_bindings(value: Any, repo_root: Path, review_status: str) -> None:
    """Validate release manifest/checksum/provenance bindings."""
    bindings = require_dict(value, "release_bindings")
    require_exact_keys(bindings, "release_bindings", RELEASE_BINDINGS_FIELDS)
    for field in sorted(RELEASE_BINDINGS_FIELDS):
        validate_binding_ref(
            bindings.get(field), repo_root, f"release_bindings.{field}", review_status
        )


def validate_integration_guidance(value: Any) -> None:
    """Validate consumer-facing guidance fields."""
    guidance = require_dict(value, "integration_guidance")
    require_exact_keys(guidance, "integration_guidance", INTEGRATION_GUIDANCE_FIELDS)
    for field in sorted(INTEGRATION_GUIDANCE_FIELDS):
        require_string(guidance.get(field), f"integration_guidance.{field}")


def validate_review(value: Any, review_status: str) -> str:
    """Validate review state."""
    review = require_dict(value, "review")
    require_exact_keys(review, "review", REVIEW_FIELDS)
    owner = require_string(review.get("owner"), "review.owner")
    reviewer = require_string(review.get("reviewer"), "review.reviewer")
    approval_status = require_enum(
        review.get("approval_status"), "review.approval_status", APPROVAL_STATUSES
    )
    approval_reference = require_string(
        review.get("approval_reference"), "review.approval_reference"
    )
    reviewed_at = require_string(review.get("reviewed_at"), "review.reviewed_at")
    if review_status == "reviewed":
        require_non_placeholder(owner, "review.owner")
        require_non_placeholder(reviewer, "review.reviewer")
        require_non_placeholder(approval_reference, "review.approval_reference")
        require_rfc3339_datetime(reviewed_at, "review.reviewed_at")
        if approval_status != "approved":
            raise PermanencePackageError(
                "review.approval_status must be approved before reviewed"
            )
    return approval_status


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    """Validate retained artifact file/hash references."""
    retained = require_list(value, "retained_artifacts")
    if not retained:
        raise PermanencePackageError("retained_artifacts must not be empty")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        require_exact_keys(
            artifact, f"retained_artifacts[{index}]", RETAINED_ARTIFACT_FIELDS
        )
        category = require_string(
            artifact.get("category"), f"retained_artifacts[{index}].category"
        )
        if category in categories:
            raise PermanencePackageError(
                f"retained_artifacts category is duplicated: {category}"
            )
        categories.add(category)
        validate_file_ref(artifact, repo_root, f"retained_artifacts[{index}]")
    return categories


def validate_redaction_policy(value: Any) -> None:
    """Validate no-secret redaction policy."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    if not require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets"):
        raise PermanencePackageError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise PermanencePackageError("redaction_policy.redacted_fields must not be empty")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def validate_template_notice(record_type: str, value: str) -> None:
    """Require templates to say they are not completion evidence."""
    if record_type != "template":
        return
    lowered = value.lower()
    if "template" not in lowered or "not completion evidence" not in lowered:
        raise PermanencePackageError(
            "template_notice must say template and not completion evidence"
        )


def validate_package_document(data: Any, repo_root: Path, label: str = "package") -> None:
    """Validate an in-memory permanence package descriptor."""
    package = require_dict(data, label)
    scan_for_secret_like_data(package)
    require_exact_keys(package, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(package.get("schema_version"), "schema_version")
    if schema_version != PERMANENCE_SCHEMA:
        raise PermanencePackageError(f"schema_version must be {PERMANENCE_SCHEMA}")

    record_type = require_enum(package.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_enum(
        package.get("review_status"), "review_status", REVIEW_STATUSES
    )
    if record_type == "template" and review_status != "template":
        raise PermanencePackageError("template records must use template review_status")
    if record_type == "evidence" and review_status == "template":
        raise PermanencePackageError("evidence records cannot use template review_status")

    environment = require_enum(package.get("environment"), "environment", ENVIRONMENTS)
    require_string(package.get("package_id"), "package_id")
    require_string(package.get("protocol_version"), "protocol_version")
    require_string(package.get("deployment_version"), "deployment_version")
    validate_source(package.get("source"))
    validate_scope(package.get("scope"), review_status, environment)
    validate_renderer(package.get("renderer"), repo_root, review_status)
    validate_dependencies(package.get("dependencies"), repo_root, review_status)
    validate_source_archive(package.get("source_archive"), repo_root, review_status)
    validate_replay(package.get("replay"), review_status)
    validate_output_evidence(package.get("output_evidence"), review_status)
    validate_storage_guarantees(package.get("storage_guarantees"))
    validate_release_bindings(package.get("release_bindings"), repo_root, review_status)
    validate_integration_guidance(package.get("integration_guidance"))
    approval_status = validate_review(package.get("review"), review_status)
    categories = validate_retained_artifacts(package.get("retained_artifacts"), repo_root)
    validate_redaction_policy(package.get("redaction_policy"))
    template_notice = require_string(package.get("template_notice"), "template_notice")
    validate_template_notice(record_type, template_notice)
    require_string(package.get("operator_notes"), "operator_notes")

    missing_local = LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
    if record_type == "template" and missing_local:
        raise PermanencePackageError(
            "local permanence template is missing retained categories: "
            + ", ".join(sorted(missing_local))
        )
    if environment in NON_LOCAL_ENVIRONMENTS and review_status == "template":
        raise PermanencePackageError(
            "non-local permanence evidence cannot use template review_status"
        )
    if environment in PRODUCTION_ENVIRONMENTS:
        if review_status != "reviewed" or approval_status != "approved":
            raise PermanencePackageError(
                "production permanence evidence must be reviewed and approved"
            )


def validate_package(path: Path, repo_root: Path) -> None:
    """Validate a permanence package JSON file."""
    validate_package_document(load_json(path), repo_root, str(path))


def descriptor_files(descriptor_dir: Path) -> list[Path]:
    """Return all committed permanence package descriptor files."""
    if not descriptor_dir.is_dir():
        raise PermanencePackageError(f"missing descriptor directory: {descriptor_dir}")
    files = sorted(path for path in descriptor_dir.rglob(DESCRIPTOR_GLOB) if path.is_file())
    if not files:
        raise PermanencePackageError(
            f"descriptor directory has no {DESCRIPTOR_GLOB} descriptors: {descriptor_dir}"
        )
    return files


def expand_targets(repo_root: Path, targets: list[Path]) -> list[Path]:
    """Expand files/directories into permanence descriptor files."""
    if not targets:
        return descriptor_files(repo_root / DEFAULT_DESCRIPTOR_DIR)

    expanded: list[Path] = []
    for target in targets:
        path = target if target.is_absolute() else repo_root / target
        if path.is_dir():
            expanded.extend(descriptor_files(path))
        else:
            expanded.append(path)
    return sorted(expanded)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "packages",
        nargs="*",
        type=Path,
        help="Permanence package JSON files or directories to validate.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the permanence package checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        files = expand_targets(repo_root, args.packages)
        for path in files:
            validate_package(path, repo_root)
    except PermanencePackageError as exc:
        print(f"1/1 permanence package check failed: {exc}", file=sys.stderr)
        return 1
    print("1/1 permanence packages are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
