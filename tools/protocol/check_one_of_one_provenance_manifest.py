#!/usr/bin/env python3
"""Validate 1/1 provenance manifest records."""

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


PROVENANCE_SCHEMA = "6529stream.one-of-one-provenance-manifest.v1"
LOCAL_PLACEHOLDER_STATUS = "not_available_local"
SELF_REFERENTIAL_STATUS = "not_available_self_referential"

DEFAULT_DESCRIPTOR_DIR = Path("release-artifacts/provenance")
DESCRIPTOR_GLOB = "*.provenance.json"
SELF_REFERENTIAL_PROVENANCE_MANIFEST_URI = (
    "release-artifacts/latest/one-of-one-provenance-manifest.json"
)

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "provenance_id",
        "record_type",
        "review_status",
        "environment",
        "protocol_version",
        "deployment_version",
        "source",
        "scope",
        "artwork",
        "authenticity",
        "provenance_entries",
        "mutability_policy",
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
ARTWORK_FIELDS = frozenset(
    {
        "title",
        "artist",
        "artist_statement",
        "medium",
        "creation_date",
        "image_uri",
        "animation_uri",
    }
)
AUTHENTICITY_FIELDS = frozenset(
    {
        "authenticity_status",
        "authority",
        "authority_reference",
        "artist_statement_sha256",
        "artwork_content_sha256",
        "certificate_sha256",
    }
)
PROVENANCE_ENTRY_FIELDS = frozenset(
    {"entry_id", "entry_type", "occurred_at", "title", "description", "evidence_refs"}
)
EVIDENCE_REF_FIELDS = frozenset({"label", "uri", "sha256", "notes"})
MUTABILITY_POLICY_FIELDS = frozenset(
    {
        "token_metadata_boundary",
        "contract_metadata_boundary",
        "freeze_boundary",
        "provenance_update_policy",
        "correction_policy",
        "authority_rotation_policy",
    }
)
RELEASE_BINDINGS_FIELDS = frozenset(
    {
        "release_manifest",
        "release_checksums",
        "deployment_manifest",
        "address_book",
        "contract_uri_hash_source",
        "collection_freeze_manifest_hash_source",
    }
)
BINDING_REF_FIELDS = frozenset({"path", "sha256", "status"})
INTEGRATION_GUIDANCE_FIELDS = frozenset(
    {"frontend_display", "indexer_source", "marketplace_boundary", "ownership_boundary"}
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
AUTHENTICITY_STATUSES = frozenset({"template", "pending_review", "reviewed"})
ENTRY_TYPES = frozenset(
    {
        "creation",
        "curation",
        "exhibition",
        "publication",
        "collector_note",
        "correction",
        "append_only_story",
        "transfer_context",
        "release_binding",
    }
)
TOKEN_METADATA_BOUNDARIES = frozenset(
    {"separate_from_token_uri", "token_uri_embedded"}
)
CONTRACT_METADATA_BOUNDARIES = frozenset(
    {"separate_from_contract_uri", "contract_uri_embedded"}
)
FREEZE_BOUNDARIES = frozenset(
    {"not_in_collection_freeze_manifest", "included_in_collection_freeze_manifest"}
)
PROVENANCE_UPDATE_POLICIES = frozenset(
    {"append_only", "frozen", "mutable_until_review"}
)
AUTHORITY_ROTATION_POLICIES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "reviewed_release_ceremony"}
)
BINDING_STATUSES = frozenset(
    {"template", "pending_review", "reviewed", "self_referential"}
)
APPROVAL_STATUSES = frozenset({"template", "pending", "approved", "rejected"})
LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {
        "provenance_schema",
        "provenance_retained_artifact_template",
        "provenance_runbook",
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


class ProvenanceManifestError(RuntimeError):
    """Raised when a provenance manifest is invalid."""


def load_json(path: Path) -> Any:
    """Load a JSON document with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ProvenanceManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ProvenanceManifestError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    """Return a sha256-prefixed digest for raw bytes."""
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
        raise ProvenanceManifestError(f"missing required file: {path}")
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
            raise ProvenanceManifestError(f"{path} is missing a schema version")
        record["schema_version"] = schema
    return record


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ProvenanceManifestError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise ProvenanceManifestError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise ProvenanceManifestError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ProvenanceManifestError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value.strip() == "":
        raise ProvenanceManifestError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise ProvenanceManifestError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise ProvenanceManifestError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer."""
    number = require_int(value, path)
    if number < 1:
        raise ProvenanceManifestError(f"{path} must be greater than zero")
    return number


def require_non_negative_int(value: Any, path: str) -> int:
    """Require a non-negative integer."""
    number = require_int(value, path)
    if number < 0:
        raise ProvenanceManifestError(f"{path} must be zero or greater")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from an enum set."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise ProvenanceManifestError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise ProvenanceManifestError(f"{path} must be a sha256: hash")
    return digest


def require_sha256_or_placeholder(value: Any, path: str) -> str:
    """Require a digest or the local placeholder."""
    digest = require_string(value, path)
    if digest == LOCAL_PLACEHOLDER_STATUS:
        return digest
    return require_sha256(digest, path)


def require_sha256_or_self_ref(value: Any, path: str) -> str:
    """Require a digest or a documented unavailable status."""
    digest = require_string(value, path)
    if digest in {LOCAL_PLACEHOLDER_STATUS, SELF_REFERENTIAL_STATUS}:
        return digest
    return require_sha256(digest, path)


def require_git_commit(value: Any, path: str) -> str:
    """Require a 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise ProvenanceManifestError(
            f"{path} must be a 40-character git commit hash"
        )
    return commit


def require_address(value: Any, path: str) -> str:
    """Require an Ethereum address."""
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise ProvenanceManifestError(f"{path} must be an address")
    return address.lower()


def require_bytes32(value: Any, path: str) -> str:
    """Require a bytes32 hex value."""
    value_text = require_string(value, path)
    if not BYTES32_RE.fullmatch(value_text):
        raise ProvenanceManifestError(f"{path} must be a bytes32 value")
    return value_text.lower()


def require_non_placeholder(value: Any, path: str) -> str:
    """Require a non-placeholder string."""
    text = require_string(value, path)
    if text in {LOCAL_PLACEHOLDER_STATUS, SELF_REFERENTIAL_STATUS}:
        raise ProvenanceManifestError(f"{path} must not be a placeholder")
    if text.strip().upper() == "TBD":
        raise ProvenanceManifestError(f"{path} must not be TBD")
    return text


def require_rfc3339_datetime(value: Any, path: str) -> str:
    """Require an RFC3339 timestamp with an explicit timezone."""
    text = require_non_placeholder(value, path)
    normalized = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise ProvenanceManifestError(f"{path} must be an RFC3339 date-time") from exc
    if parsed.tzinfo is None:
        raise ProvenanceManifestError(f"{path} must include an explicit timezone")
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file without allowing escapes."""
    if "\\" in relative_path:
        raise ProvenanceManifestError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ProvenanceManifestError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ProvenanceManifestError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise ProvenanceManifestError(
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
        raise ProvenanceManifestError(
            f"{path}.sha256 mismatch for {relative_path}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed provenance records."""
    if path == "$.redaction_policy" or path.startswith("$.redaction_policy."):
        return
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            if SECRET_KEY_RE.search(key_text):
                raise ProvenanceManifestError(
                    f"secret-like key found at {path}.{key_text}"
                )
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise ProvenanceManifestError(f"secret-like value found at {path}")


def validate_uri(value: Any, path: str, *, allow_placeholder: bool = True) -> str:
    """Validate a safe provenance URI or local placeholder."""
    uri = require_string(value, path)
    if allow_placeholder and uri == LOCAL_PLACEHOLDER_STATUS:
        return uri
    if uri != uri.strip():
        raise ProvenanceManifestError(f"{path} has leading or trailing whitespace")
    for character in uri:
        codepoint = ord(character)
        if codepoint <= 0x20 or codepoint == 0x7F:
            raise ProvenanceManifestError(
                f"{path} contains whitespace or control characters"
            )
    parsed = urlsplit(uri)
    if parsed.scheme not in SAFE_CONTENT_SCHEMES:
        allowed = ", ".join(sorted(SAFE_CONTENT_SCHEMES))
        raise ProvenanceManifestError(
            f"{path} scheme {parsed.scheme or '<none>'} is not allowed; expected {allowed}"
        )
    if parsed.scheme == "https" and not parsed.netloc:
        raise ProvenanceManifestError(f"{path} HTTPS URI is missing a host")
    if parsed.scheme in {"ar", "ipfs"} and not (parsed.netloc or parsed.path):
        raise ProvenanceManifestError(f"{path} content URI is missing an identifier")
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
            raise ProvenanceManifestError("reviewed provenance cannot use zero core contract")
        if adapter == "0x" + "0" * 40:
            raise ProvenanceManifestError(
                "reviewed provenance cannot use zero contract metadata adapter"
            )
        if token_id == 0:
            raise ProvenanceManifestError("reviewed provenance token_id must be nonzero")
        if contract_uri_hash == "0x" + "0" * 64:
            raise ProvenanceManifestError(
                "reviewed provenance cannot use zero contract_uri_hash"
            )
        if freeze_hash == "0x" + "0" * 64:
            raise ProvenanceManifestError(
                "reviewed provenance cannot use zero collection_freeze_manifest_hash"
            )
    return scope


def validate_artwork(value: Any, review_status: str) -> dict[str, Any]:
    """Validate artwork display metadata."""
    artwork = require_dict(value, "artwork")
    require_exact_keys(artwork, "artwork", ARTWORK_FIELDS)
    for field in ("title", "artist", "artist_statement", "medium", "creation_date"):
        text = require_string(artwork.get(field), f"artwork.{field}")
        if review_status == "reviewed":
            require_non_placeholder(text, f"artwork.{field}")
    validate_uri(artwork.get("image_uri"), "artwork.image_uri")
    validate_uri(artwork.get("animation_uri"), "artwork.animation_uri")
    return artwork


def validate_authenticity(value: Any, review_status: str) -> dict[str, Any]:
    """Validate authenticity and hash evidence metadata."""
    authenticity = require_dict(value, "authenticity")
    require_exact_keys(authenticity, "authenticity", AUTHENTICITY_FIELDS)
    status = require_enum(
        authenticity.get("authenticity_status"),
        "authenticity.authenticity_status",
        AUTHENTICITY_STATUSES,
    )
    authority = require_string(authenticity.get("authority"), "authenticity.authority")
    authority_reference = require_string(
        authenticity.get("authority_reference"), "authenticity.authority_reference"
    )
    for field in (
        "artist_statement_sha256",
        "artwork_content_sha256",
        "certificate_sha256",
    ):
        require_sha256_or_placeholder(authenticity.get(field), f"authenticity.{field}")
    if review_status == "reviewed":
        if status != "reviewed":
            raise ProvenanceManifestError(
                "reviewed provenance requires reviewed authenticity_status"
            )
        require_non_placeholder(authority, "authenticity.authority")
        require_non_placeholder(
            authority_reference, "authenticity.authority_reference"
        )
        for field in (
            "artist_statement_sha256",
            "artwork_content_sha256",
            "certificate_sha256",
        ):
            if authenticity.get(field) == LOCAL_PLACEHOLDER_STATUS:
                raise ProvenanceManifestError(
                    f"reviewed provenance requires {field} hash evidence"
                )
    return authenticity


def validate_provenance_entries(value: Any, review_status: str) -> list[dict[str, Any]]:
    """Validate append-only provenance entries."""
    entries = require_list(value, "provenance_entries")
    if not entries:
        raise ProvenanceManifestError("provenance_entries must not be empty")
    seen_entry_ids: set[str] = set()
    entry_types: set[str] = set()
    validated_entries: list[dict[str, Any]] = []
    for index, item in enumerate(entries):
        entry = require_dict(item, f"provenance_entries[{index}]")
        require_exact_keys(entry, f"provenance_entries[{index}]", PROVENANCE_ENTRY_FIELDS)
        entry_id = require_string(
            entry.get("entry_id"), f"provenance_entries[{index}].entry_id"
        )
        if entry_id in seen_entry_ids:
            raise ProvenanceManifestError(f"duplicate provenance entry_id: {entry_id}")
        seen_entry_ids.add(entry_id)
        entry_type = require_enum(
            entry.get("entry_type"),
            f"provenance_entries[{index}].entry_type",
            ENTRY_TYPES,
        )
        entry_types.add(entry_type)
        for field in ("occurred_at", "title", "description"):
            text = require_string(
                entry.get(field), f"provenance_entries[{index}].{field}"
            )
            if review_status == "reviewed":
                require_non_placeholder(text, f"provenance_entries[{index}].{field}")
        refs = require_list(
            entry.get("evidence_refs"), f"provenance_entries[{index}].evidence_refs"
        )
        if not refs:
            raise ProvenanceManifestError(
                f"provenance_entries[{index}].evidence_refs must not be empty"
            )
        for ref_index, ref_item in enumerate(refs):
            ref = require_dict(
                ref_item, f"provenance_entries[{index}].evidence_refs[{ref_index}]"
            )
            require_exact_keys(
                ref,
                f"provenance_entries[{index}].evidence_refs[{ref_index}]",
                EVIDENCE_REF_FIELDS,
            )
            require_string(
                ref.get("label"),
                f"provenance_entries[{index}].evidence_refs[{ref_index}].label",
            )
            require_string(
                ref.get("uri"),
                f"provenance_entries[{index}].evidence_refs[{ref_index}].uri",
            )
            digest = require_sha256_or_self_ref(
                ref.get("sha256"),
                f"provenance_entries[{index}].evidence_refs[{ref_index}].sha256",
            )
            require_string(
                ref.get("notes"),
                f"provenance_entries[{index}].evidence_refs[{ref_index}].notes",
            )
            if digest == SELF_REFERENTIAL_STATUS:
                if review_status == "reviewed":
                    raise ProvenanceManifestError(
                        "reviewed provenance evidence refs require hash evidence"
                    )
                if entry_type != "release_binding" or ref.get("uri") != SELF_REFERENTIAL_PROVENANCE_MANIFEST_URI:
                    raise ProvenanceManifestError(
                        "self-referential provenance evidence refs are only allowed "
                        "for the generated release-binding manifest"
                    )
            if review_status == "reviewed" and digest == LOCAL_PLACEHOLDER_STATUS:
                raise ProvenanceManifestError(
                    "reviewed provenance evidence refs require hash evidence"
                )
        validated_entries.append(entry)
    if "creation" not in entry_types:
        raise ProvenanceManifestError("provenance_entries must include creation")
    if "release_binding" not in entry_types:
        raise ProvenanceManifestError("provenance_entries must include release_binding")
    return validated_entries


def validate_mutability_policy(value: Any, review_status: str) -> dict[str, Any]:
    """Validate provenance mutability boundaries."""
    policy = require_dict(value, "mutability_policy")
    require_exact_keys(policy, "mutability_policy", MUTABILITY_POLICY_FIELDS)
    require_enum(
        policy.get("token_metadata_boundary"),
        "mutability_policy.token_metadata_boundary",
        TOKEN_METADATA_BOUNDARIES,
    )
    require_enum(
        policy.get("contract_metadata_boundary"),
        "mutability_policy.contract_metadata_boundary",
        CONTRACT_METADATA_BOUNDARIES,
    )
    require_enum(
        policy.get("freeze_boundary"),
        "mutability_policy.freeze_boundary",
        FREEZE_BOUNDARIES,
    )
    update_policy = require_enum(
        policy.get("provenance_update_policy"),
        "mutability_policy.provenance_update_policy",
        PROVENANCE_UPDATE_POLICIES,
    )
    require_enum(
        policy.get("correction_policy"),
        "mutability_policy.correction_policy",
        frozenset({"append_only_with_supersedes"}),
    )
    rotation = require_enum(
        policy.get("authority_rotation_policy"),
        "mutability_policy.authority_rotation_policy",
        AUTHORITY_ROTATION_POLICIES,
    )
    if update_policy != "append_only":
        raise ProvenanceManifestError("provenance_update_policy must be append_only")
    if review_status == "reviewed" and rotation == LOCAL_PLACEHOLDER_STATUS:
        raise ProvenanceManifestError(
            "reviewed provenance requires an authority rotation policy"
        )
    return policy


def validate_binding_ref(value: Any, repo_root: Path, path: str, review_status: str) -> None:
    """Validate a release/deployment binding reference."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, BINDING_REF_FIELDS)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    digest = require_sha256_or_self_ref(ref.get("sha256"), f"{path}.sha256")
    status = require_enum(ref.get("status"), f"{path}.status", BINDING_STATUSES)
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    if digest.startswith("sha256:"):
        actual_hash = file_sha256(resolved)
        if actual_hash != digest:
            raise ProvenanceManifestError(
                f"{path}.sha256 mismatch for {relative_path}: "
                f"expected {digest}, got {actual_hash}"
            )
    if status == "self_referential" and digest != SELF_REFERENTIAL_STATUS:
        raise ProvenanceManifestError(
            f"{path}.sha256 must be {SELF_REFERENTIAL_STATUS} for self_referential bindings"
        )
    if status != "self_referential" and digest == SELF_REFERENTIAL_STATUS:
        raise ProvenanceManifestError(
            f"{path}.sha256 cannot be self-referential unless status is self_referential"
        )
    if review_status == "reviewed" and status not in {"reviewed", "self_referential"}:
        raise ProvenanceManifestError(f"reviewed provenance requires reviewed {path}")
    if review_status == "reviewed" and digest == LOCAL_PLACEHOLDER_STATUS:
        raise ProvenanceManifestError(f"reviewed provenance requires {path}.sha256")


def validate_release_bindings(value: Any, repo_root: Path, review_status: str) -> None:
    """Validate release/deployment binding metadata."""
    bindings = require_dict(value, "release_bindings")
    require_exact_keys(bindings, "release_bindings", RELEASE_BINDINGS_FIELDS)
    for field in (
        "release_manifest",
        "release_checksums",
        "deployment_manifest",
        "address_book",
    ):
        validate_binding_ref(
            bindings.get(field), repo_root, f"release_bindings.{field}", review_status
        )
    require_string(
        bindings.get("contract_uri_hash_source"),
        "release_bindings.contract_uri_hash_source",
    )
    require_string(
        bindings.get("collection_freeze_manifest_hash_source"),
        "release_bindings.collection_freeze_manifest_hash_source",
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
            raise ProvenanceManifestError(
                "review.approval_status must be approved before reviewed"
            )
    return approval_status


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    """Validate retained artifact file/hash references."""
    retained = require_list(value, "retained_artifacts")
    if not retained:
        raise ProvenanceManifestError("retained_artifacts must not be empty")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        require_exact_keys(artifact, f"retained_artifacts[{index}]", RETAINED_ARTIFACT_FIELDS)
        category = require_string(
            artifact.get("category"), f"retained_artifacts[{index}].category"
        )
        if category in categories:
            raise ProvenanceManifestError(
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
        raise ProvenanceManifestError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise ProvenanceManifestError("redaction_policy.redacted_fields must not be empty")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def validate_template_notice(record_type: str, value: str) -> None:
    """Require templates to say they are not completion evidence."""
    if record_type != "template":
        return
    lowered = value.lower()
    if "template" not in lowered or "not completion evidence" not in lowered:
        raise ProvenanceManifestError(
            "template_notice must say template and not completion evidence"
        )


def validate_manifest_document(data: Any, repo_root: Path, label: str = "manifest") -> None:
    """Validate an in-memory 1/1 provenance manifest."""
    manifest = require_dict(data, label)
    scan_for_secret_like_data(manifest)
    require_exact_keys(manifest, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(manifest.get("schema_version"), "schema_version")
    if schema_version != PROVENANCE_SCHEMA:
        raise ProvenanceManifestError(f"schema_version must be {PROVENANCE_SCHEMA}")

    record_type = require_enum(manifest.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_enum(
        manifest.get("review_status"), "review_status", REVIEW_STATUSES
    )
    if record_type == "template" and review_status != "template":
        raise ProvenanceManifestError("template records must use template review_status")
    if record_type == "evidence" and review_status == "template":
        raise ProvenanceManifestError("evidence records cannot use template review_status")

    environment = require_enum(manifest.get("environment"), "environment", ENVIRONMENTS)
    require_string(manifest.get("provenance_id"), "provenance_id")
    require_string(manifest.get("protocol_version"), "protocol_version")
    require_string(manifest.get("deployment_version"), "deployment_version")
    validate_source(manifest.get("source"))
    validate_scope(manifest.get("scope"), review_status, environment)
    validate_artwork(manifest.get("artwork"), review_status)
    validate_authenticity(manifest.get("authenticity"), review_status)
    validate_provenance_entries(manifest.get("provenance_entries"), review_status)
    validate_mutability_policy(manifest.get("mutability_policy"), review_status)
    validate_release_bindings(manifest.get("release_bindings"), repo_root, review_status)
    validate_integration_guidance(manifest.get("integration_guidance"))
    approval_status = validate_review(manifest.get("review"), review_status)
    categories = validate_retained_artifacts(manifest.get("retained_artifacts"), repo_root)
    validate_redaction_policy(manifest.get("redaction_policy"))
    template_notice = require_string(manifest.get("template_notice"), "template_notice")
    validate_template_notice(record_type, template_notice)
    require_string(manifest.get("operator_notes"), "operator_notes")

    missing_local = LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
    if record_type == "template" and missing_local:
        raise ProvenanceManifestError(
            "local provenance template is missing retained categories: "
            + ", ".join(sorted(missing_local))
        )
    if environment in NON_LOCAL_ENVIRONMENTS and review_status == "template":
        raise ProvenanceManifestError(
            "non-local provenance evidence cannot use template review_status"
        )
    if environment in PRODUCTION_ENVIRONMENTS:
        if review_status != "reviewed" or approval_status != "approved":
            raise ProvenanceManifestError(
                "production provenance evidence must be reviewed and approved"
            )


def validate_manifest(path: Path, repo_root: Path) -> None:
    """Validate a provenance manifest JSON file."""
    validate_manifest_document(load_json(path), repo_root, str(path))


def descriptor_files(descriptor_dir: Path) -> list[Path]:
    """Return all committed provenance descriptor files."""
    if not descriptor_dir.is_dir():
        raise ProvenanceManifestError(f"missing descriptor directory: {descriptor_dir}")
    files = sorted(path for path in descriptor_dir.rglob(DESCRIPTOR_GLOB) if path.is_file())
    if not files:
        raise ProvenanceManifestError(
            f"descriptor directory has no {DESCRIPTOR_GLOB} descriptors: {descriptor_dir}"
        )
    return files


def expand_targets(repo_root: Path, targets: list[Path]) -> list[Path]:
    """Expand files/directories into provenance descriptor files."""
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
        "manifests",
        nargs="*",
        type=Path,
        help="Provenance manifest JSON files or directories to validate.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the provenance manifest checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        files = expand_targets(repo_root, args.manifests)
        for path in files:
            validate_manifest(path, repo_root)
    except ProvenanceManifestError as exc:
        print(f"1/1 provenance manifest check failed: {exc}", file=sys.stderr)
        return 1
    print("1/1 provenance manifests are valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
