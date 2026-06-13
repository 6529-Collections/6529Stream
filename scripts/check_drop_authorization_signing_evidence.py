#!/usr/bin/env python3
"""Validate retained drop authorization signing evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.drop-authorization-signing-evidence.v1"
PAYLOAD_SCHEMA = "6529stream.drop-authorization-payload.v1"
LOCAL_PLACEHOLDER_STATUS = "not_available_local"

DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/drop-authorization-signing/"
        "drop-authorization-signing-evidence-template.json"
    )
]

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "evidence_id",
        "record_type",
        "review_status",
        "environment",
        "chain_id",
        "source",
        "payload",
        "signing_identity",
        "signature",
        "review",
        "retained_artifacts",
        "redaction_policy",
        "template_notice",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
FILE_REF_FIELDS = frozenset({"path", "sha256"})
PAYLOAD_FIELDS = frozenset(
    {
        "payload_file",
        "payload_schema_version",
        "payload_kind",
        "typed_data_primary_type",
        "domain",
        "message",
        "derived",
    }
)
DOMAIN_FIELDS = frozenset({"name", "version", "chain_id", "verifying_contract"})
MESSAGE_FIELDS = frozenset(
    {
        "drop_id",
        "poster",
        "recipient",
        "payer",
        "collection_id",
        "sale_mode",
        "signer_epoch",
        "nonce",
        "deadline",
    }
)
DERIVED_FIELDS = frozenset(
    {"signer", "drop_id", "token_data_hash", "domain_separator", "struct_hash", "digest"}
)
SIGNING_IDENTITY_FIELDS = frozenset(
    {
        "signer_type",
        "signer",
        "signer_epoch",
        "custody_status",
        "custody_reference",
        "signer_lifecycle_status",
        "signer_service",
        "signer_epoch_source",
    }
)
SIGNATURE_FIELDS = frozenset(
    {
        "status",
        "signature_format",
        "signature_hash",
        "verification_status",
        "verification_command",
        "returned_at",
        "evidence_note",
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
PAYLOAD_KINDS = frozenset({"fixed_price", "auction"})
SIGNER_TYPES = frozenset({"EOA", "ERC1271", "external_service", "hsm", "local_placeholder"})
SIGNER_LIFECYCLE_STATUSES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "active", "rotated", "revoked", "pending"}
)
CUSTODY_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "documented", "pending", "blocked"})
SIGNATURE_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "pending", "signed", "blocked"})
SIGNATURE_HASH_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "pending", "blocked", "redacted"})
VERIFICATION_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "pending", "verified", "blocked"})
APPROVAL_STATUSES = frozenset({"template", "pending", "approved", "rejected"})

LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {"drop_signing_schema", "payload_output", "retained_transcript"}
)
NON_LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {"payload_output", "signing_approval", "signing_transcript"}
)
SIGNED_REQUIRED_RETAINED_CATEGORIES = frozenset({"signature_verification"})

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
HEX32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|unreleased[_\-\s]?drop[_\-\s]?payload|"
    r"raw[_\-\s]?signature|bearer[_\-\s]?token"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])client[_\-\s]?secret([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
# NOTE: SECRET_KEY_RE intentionally catches any key whose final segment is
# "secret". Add legitimate metadata keys such as "no_secret" here before use.
SAFE_SECRET_POLICY_KEYS = frozenset({"redaction_policy", "no_secrets", "redacted_fields"})
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|rpc[_ -]?url|api[_ -]?key|"
    r"password|client[_ -]?secret|bearer[_ -]?token|raw[_ -]?signature|"
    r"unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)


class DropAuthorizationSigningEvidenceError(RuntimeError):
    """Raised when drop authorization signing evidence is invalid."""


def load_json(path: Path) -> Any:
    """Load a JSON file with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise DropAuthorizationSigningEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise DropAuthorizationSigningEvidenceError(
            f"invalid JSON in {path}: {exc}"
        ) from exc


def sha256_bytes(value: bytes) -> str:
    """Return a sha256-prefixed digest for raw bytes."""
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    """Hash a file using the release artifact digest format."""
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise DropAuthorizationSigningEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise DropAuthorizationSigningEvidenceError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise DropAuthorizationSigningEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer."""
    number = require_int(value, path)
    if number < 1:
        raise DropAuthorizationSigningEvidenceError(f"{path} must be greater than zero")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from an enum set."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise DropAuthorizationSigningEvidenceError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    """Require a 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise DropAuthorizationSigningEvidenceError(
            f"{path} must be a 40-character git commit hash"
        )
    return commit


def require_address(value: Any, path: str) -> str:
    """Require an Ethereum address."""
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be an address")
    return address.lower()


def require_bytes32(value: Any, path: str) -> str:
    """Require a bytes32 hex string."""
    digest = require_string(value, path)
    if not HEX32_RE.fullmatch(digest):
        raise DropAuthorizationSigningEvidenceError(f"{path} must be a bytes32 hex string")
    return digest.lower()


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file path without allowing escapes."""
    if "\\" in relative_path:
        raise DropAuthorizationSigningEvidenceError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise DropAuthorizationSigningEvidenceError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise DropAuthorizationSigningEvidenceError(
            f"{path} must stay inside the repository"
        ) from exc
    if not resolved.is_file():
        raise DropAuthorizationSigningEvidenceError(
            f"{path} references missing file: {relative_path}"
        )
    return resolved


def validate_file_ref(
    value: Any,
    repo_root: Path,
    path: str,
    expected_fields: frozenset[str] = FILE_REF_FIELDS,
) -> Path:
    """Validate a repository-relative file/hash reference."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, expected_fields)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise DropAuthorizationSigningEvidenceError(
            f"{path}.sha256 mismatch for {relative_path}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def validate_source(value: Any) -> None:
    """Validate source control evidence metadata."""
    source = require_dict(value, "source")
    require_exact_keys(source, "source", SOURCE_FIELDS)
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit")
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_redaction_policy(value: Any) -> None:
    """Validate the no-secret redaction policy."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    no_secrets = require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets")
    if not no_secrets:
        raise DropAuthorizationSigningEvidenceError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise DropAuthorizationSigningEvidenceError(
            "redaction_policy.redacted_fields must not be empty"
        )
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed evidence."""
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            key_lower = key_text.lower()
            if key_lower not in SAFE_SECRET_POLICY_KEYS and SECRET_KEY_RE.search(key_text):
                raise DropAuthorizationSigningEvidenceError(
                    f"secret-like key found at {path}.{key_text}"
                )
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise DropAuthorizationSigningEvidenceError(f"secret-like value found at {path}")


def stringified(value: Any) -> str:
    """Return a stable string form for numeric payload comparison."""
    return str(value)


def require_matching_string(actual: Any, expected: Any, path: str) -> None:
    """Compare JSON values after stringifying integer-like payload fields."""
    if stringified(actual).lower() != stringified(expected).lower():
        raise DropAuthorizationSigningEvidenceError(
            f"{path} mismatch: expected {expected}, got {actual}"
        )


def validate_payload_domain(evidence_domain: Any, actual_domain: dict[str, Any]) -> None:
    """Validate EIP-712 domain evidence against the generated payload."""
    domain = require_dict(evidence_domain, "payload.domain")
    require_exact_keys(domain, "payload.domain", DOMAIN_FIELDS)
    require_matching_string(actual_domain.get("name"), domain.get("name"), "payload.domain.name")
    require_matching_string(
        actual_domain.get("version"), domain.get("version"), "payload.domain.version"
    )
    require_matching_string(
        actual_domain.get("chainId"), domain.get("chain_id"), "payload.domain.chain_id"
    )
    expected_contract = require_address(
        domain.get("verifying_contract"), "payload.domain.verifying_contract"
    )
    actual_contract = require_address(
        actual_domain.get("verifyingContract"), "typed_data.domain.verifyingContract"
    )
    if actual_contract != expected_contract:
        raise DropAuthorizationSigningEvidenceError(
            "payload.domain.verifying_contract mismatch"
        )


def validate_payload_message(evidence_message: Any, actual_message: dict[str, Any]) -> None:
    """Validate signed message summary evidence against the generated payload."""
    message = require_dict(evidence_message, "payload.message")
    require_exact_keys(message, "payload.message", MESSAGE_FIELDS)
    comparisons = {
        "drop_id": ("dropId", require_bytes32),
        "poster": ("poster", require_address),
        "recipient": ("recipient", require_address),
        "payer": ("payer", require_address),
    }
    for evidence_key, (payload_key, validator) in comparisons.items():
        expected = validator(message.get(evidence_key), f"payload.message.{evidence_key}")
        actual = validator(actual_message.get(payload_key), f"typed_data.message.{payload_key}")
        if actual != expected:
            raise DropAuthorizationSigningEvidenceError(
                f"payload.message.{evidence_key} mismatch"
            )

    numeric_comparisons = {
        "collection_id": "collectionId",
        "sale_mode": "saleMode",
        "signer_epoch": "signerEpoch",
        "nonce": "nonce",
        "deadline": "deadline",
    }
    for evidence_key, payload_key in numeric_comparisons.items():
        if evidence_key == "sale_mode":
            require_positive_int(message.get(evidence_key), f"payload.message.{evidence_key}")
        else:
            require_int(message.get(evidence_key), f"payload.message.{evidence_key}")
        require_matching_string(
            actual_message.get(payload_key),
            message.get(evidence_key),
            f"payload.message.{evidence_key}",
        )


def validate_payload_derived(evidence_derived: Any, actual_derived: dict[str, Any]) -> None:
    """Validate derived hashes against the generated payload."""
    derived = require_dict(evidence_derived, "payload.derived")
    require_exact_keys(derived, "payload.derived", DERIVED_FIELDS)
    expected_signer = require_address(derived.get("signer"), "payload.derived.signer")
    actual_signer = require_address(actual_derived.get("signer"), "derived.signer")
    if actual_signer != expected_signer:
        raise DropAuthorizationSigningEvidenceError("payload.derived.signer mismatch")
    for key in ("drop_id", "token_data_hash", "domain_separator", "struct_hash", "digest"):
        expected = require_bytes32(derived.get(key), f"payload.derived.{key}")
        actual = require_bytes32(actual_derived.get(key), f"derived.{key}")
        if actual != expected:
            raise DropAuthorizationSigningEvidenceError(f"payload.derived.{key} mismatch")


def validate_payload(value: Any, repo_root: Path) -> dict[str, Any]:
    """Validate the payload evidence and return the generated payload."""
    payload = require_dict(value, "payload")
    require_exact_keys(payload, "payload", PAYLOAD_FIELDS)
    payload_path = validate_file_ref(payload.get("payload_file"), repo_root, "payload.payload_file")
    payload_document = require_dict(load_json(payload_path), str(payload_path))
    if payload_document.get("schema_version") != PAYLOAD_SCHEMA:
        raise DropAuthorizationSigningEvidenceError(
            f"payload payload_file schema_version must be {PAYLOAD_SCHEMA}"
        )
    if require_string(payload_document.get("signing_status"), "payload_file.signing_status") != "unsigned":
        raise DropAuthorizationSigningEvidenceError("payload_file.signing_status must be unsigned")
    no_secret_policy = require_dict(payload_document.get("no_secret_policy"), "payload_file.no_secret_policy")
    if require_bool(
        no_secret_policy.get("key_material_included"),
        "payload_file.no_secret_policy.key_material_included",
    ):
        raise DropAuthorizationSigningEvidenceError("payload_file must not include key material")
    if require_bool(
        no_secret_policy.get("mnemonic_included"),
        "payload_file.no_secret_policy.mnemonic_included",
    ):
        raise DropAuthorizationSigningEvidenceError("payload_file must not include mnemonics")
    if require_bool(
        no_secret_policy.get("production_payload"),
        "payload_file.no_secret_policy.production_payload",
    ):
        raise DropAuthorizationSigningEvidenceError(
            "payload_file must not be marked as a production payload"
        )

    schema_version = require_string(
        payload.get("payload_schema_version"), "payload.payload_schema_version"
    )
    if schema_version != PAYLOAD_SCHEMA:
        raise DropAuthorizationSigningEvidenceError(
            f"payload.payload_schema_version must be {PAYLOAD_SCHEMA}"
        )
    payload_kind = require_enum(payload.get("payload_kind"), "payload.payload_kind", PAYLOAD_KINDS)
    typed_data = require_dict(payload_document.get("typed_data"), "payload_file.typed_data")
    primary_type = require_string(typed_data.get("primaryType"), "payload_file.typed_data.primaryType")
    if payload.get("typed_data_primary_type") != primary_type:
        raise DropAuthorizationSigningEvidenceError("payload.typed_data_primary_type mismatch")
    if primary_type != "DropAuthorization":
        raise DropAuthorizationSigningEvidenceError("typed_data primary type must be DropAuthorization")

    actual_domain = require_dict(typed_data.get("domain"), "payload_file.typed_data.domain")
    actual_message = require_dict(typed_data.get("message"), "payload_file.typed_data.message")
    actual_derived = require_dict(payload_document.get("derived"), "payload_file.derived")
    validate_payload_domain(payload.get("domain"), actual_domain)
    validate_payload_message(payload.get("message"), actual_message)
    validate_payload_derived(payload.get("derived"), actual_derived)

    sale_mode = int(stringified(actual_message.get("saleMode")))
    if payload_kind == "fixed_price" and sale_mode != 1:
        raise DropAuthorizationSigningEvidenceError("fixed_price payloads must use sale mode 1")
    if payload_kind == "auction" and sale_mode != 2:
        raise DropAuthorizationSigningEvidenceError("auction payloads must use sale mode 2")
    return payload_document


def validate_signing_identity(
    value: Any, environment: str, payload_document: dict[str, Any]
) -> dict[str, Any]:
    """Validate signer metadata against the generated payload."""
    identity = require_dict(value, "signing_identity")
    require_exact_keys(identity, "signing_identity", SIGNING_IDENTITY_FIELDS)
    signer_type = require_enum(identity.get("signer_type"), "signing_identity.signer_type", SIGNER_TYPES)
    signer = require_address(identity.get("signer"), "signing_identity.signer")
    signer_epoch = require_int(identity.get("signer_epoch"), "signing_identity.signer_epoch")
    custody_status = require_enum(
        identity.get("custody_status"), "signing_identity.custody_status", CUSTODY_STATUSES
    )
    require_string(identity.get("custody_reference"), "signing_identity.custody_reference")
    lifecycle_status = require_enum(
        identity.get("signer_lifecycle_status"),
        "signing_identity.signer_lifecycle_status",
        SIGNER_LIFECYCLE_STATUSES,
    )
    require_string(identity.get("signer_service"), "signing_identity.signer_service")
    require_string(identity.get("signer_epoch_source"), "signing_identity.signer_epoch_source")

    derived = require_dict(payload_document.get("derived"), "payload_file.derived")
    payload_signer = require_address(derived.get("signer"), "payload_file.derived.signer")
    if signer != payload_signer:
        raise DropAuthorizationSigningEvidenceError("signing_identity.signer must match payload signer")
    message = require_dict(
        require_dict(payload_document.get("typed_data"), "payload_file.typed_data").get("message"),
        "payload_file.typed_data.message",
    )
    require_matching_string(
        message.get("signerEpoch"), signer_epoch, "signing_identity.signer_epoch"
    )

    if environment in NON_LOCAL_ENVIRONMENTS:
        if signer_type == "local_placeholder":
            raise DropAuthorizationSigningEvidenceError(
                "non-local signing evidence cannot use local_placeholder signer_type"
            )
        if custody_status == LOCAL_PLACEHOLDER_STATUS:
            raise DropAuthorizationSigningEvidenceError(
                "non-local signing evidence cannot use not_available_local custody_status"
            )
        if lifecycle_status == LOCAL_PLACEHOLDER_STATUS:
            raise DropAuthorizationSigningEvidenceError(
                "non-local signing evidence cannot use not_available_local lifecycle status"
            )
    return identity


def validate_signature(value: Any, environment: str) -> str:
    """Validate signature status metadata."""
    signature = require_dict(value, "signature")
    require_exact_keys(signature, "signature", SIGNATURE_FIELDS)
    status = require_enum(signature.get("status"), "signature.status", SIGNATURE_STATUSES)
    require_string(signature.get("signature_format"), "signature.signature_format")
    signature_hash = require_string(signature.get("signature_hash"), "signature.signature_hash")
    if status == "signed":
        require_sha256(signature_hash, "signature.signature_hash")
    elif signature_hash not in SIGNATURE_HASH_STATUSES:
        raise DropAuthorizationSigningEvidenceError(
            "signature.signature_hash must be a sha256: hash or a status marker"
        )
    verification_status = require_enum(
        signature.get("verification_status"),
        "signature.verification_status",
        VERIFICATION_STATUSES,
    )
    verification_command = require_string(
        signature.get("verification_command"), "signature.verification_command"
    )
    returned_at = require_string(signature.get("returned_at"), "signature.returned_at")
    require_string(signature.get("evidence_note"), "signature.evidence_note")

    if environment in NON_LOCAL_ENVIRONMENTS and status == LOCAL_PLACEHOLDER_STATUS:
        raise DropAuthorizationSigningEvidenceError(
            "non-local signing evidence cannot use not_available_local signature status"
        )
    if status == "signed":
        if verification_status != "verified":
            raise DropAuthorizationSigningEvidenceError(
                "signed drop authorization evidence must be verified"
            )
        if verification_command == LOCAL_PLACEHOLDER_STATUS:
            raise DropAuthorizationSigningEvidenceError(
                "signed drop authorization evidence must include a verification command"
            )
        if returned_at == LOCAL_PLACEHOLDER_STATUS:
            raise DropAuthorizationSigningEvidenceError(
                "signed drop authorization evidence must include returned_at"
            )
    return status


def validate_review(value: Any, review_status: str) -> str:
    """Validate reviewer approval metadata."""
    review = require_dict(value, "review")
    require_exact_keys(review, "review", REVIEW_FIELDS)
    require_string(review.get("owner"), "review.owner")
    reviewer = require_string(review.get("reviewer"), "review.reviewer")
    approval_status = require_enum(
        review.get("approval_status"), "review.approval_status", APPROVAL_STATUSES
    )
    require_string(review.get("approval_reference"), "review.approval_reference")
    require_string(review.get("reviewed_at"), "review.reviewed_at")
    if review_status == "reviewed":
        if reviewer.strip().upper() == "TBD":
            raise DropAuthorizationSigningEvidenceError("review.reviewer must be set before reviewed")
        if approval_status != "approved":
            raise DropAuthorizationSigningEvidenceError(
                "review.approval_status must be approved before reviewed"
            )
    return approval_status


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    """Validate retained artifact file/hash references."""
    retained = require_list(value, "retained_artifacts")
    if not retained:
        raise DropAuthorizationSigningEvidenceError("retained_artifacts must not be empty")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        require_exact_keys(artifact, f"retained_artifacts[{index}]", RETAINED_ARTIFACT_FIELDS)
        category = require_string(
            artifact.get("category"), f"retained_artifacts[{index}].category"
        )
        if category in categories:
            raise DropAuthorizationSigningEvidenceError(
                f"retained_artifacts category is duplicated: {category}"
            )
        categories.add(category)
        validate_file_ref(
            artifact,
            repo_root,
            f"retained_artifacts[{index}]",
            RETAINED_ARTIFACT_FIELDS,
        )
    return categories


def validate_template_notice(record_type: str, value: str) -> None:
    """Require templates to say they are not completion evidence."""
    if record_type != "template":
        return
    lowered = value.lower()
    if "template" not in lowered or "not completion evidence" not in lowered:
        raise DropAuthorizationSigningEvidenceError(
            "template_notice must say template and not completion evidence"
        )


def validate_evidence_document(data: Any, repo_root: Path, label: str = "evidence") -> None:
    """Validate an in-memory drop authorization signing evidence document."""
    evidence = require_dict(data, label)
    scan_for_secret_like_data(evidence)
    require_exact_keys(evidence, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(evidence.get("schema_version"), "schema_version")
    if schema_version != EVIDENCE_SCHEMA:
        raise DropAuthorizationSigningEvidenceError(f"schema_version must be {EVIDENCE_SCHEMA}")

    record_type = require_enum(evidence.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_enum(
        evidence.get("review_status"), "review_status", REVIEW_STATUSES
    )
    if record_type == "template" and review_status != "template":
        raise DropAuthorizationSigningEvidenceError("template records must use template review_status")
    if record_type == "evidence" and review_status == "template":
        raise DropAuthorizationSigningEvidenceError("evidence records cannot use template review_status")

    environment = require_enum(evidence.get("environment"), "environment", ENVIRONMENTS)
    chain_id = require_positive_int(evidence.get("chain_id"), "chain_id")
    validate_source(evidence.get("source"))
    payload_document = validate_payload(evidence.get("payload"), repo_root)
    payload_domain = require_dict(
        require_dict(payload_document.get("typed_data"), "payload_file.typed_data").get("domain"),
        "payload_file.typed_data.domain",
    )
    require_matching_string(payload_domain.get("chainId"), chain_id, "chain_id")
    validate_signing_identity(evidence.get("signing_identity"), environment, payload_document)
    signature_status = validate_signature(evidence.get("signature"), environment)
    approval_status = validate_review(evidence.get("review"), review_status)
    categories = validate_retained_artifacts(evidence.get("retained_artifacts"), repo_root)
    validate_redaction_policy(evidence.get("redaction_policy"))
    template_notice = require_string(evidence.get("template_notice"), "template_notice")
    validate_template_notice(record_type, template_notice)
    require_string(evidence.get("operator_notes"), "operator_notes")

    missing_local = LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
    if record_type == "template" and missing_local:
        raise DropAuthorizationSigningEvidenceError(
            "local drop authorization signing template is missing retained categories: "
            + ", ".join(sorted(missing_local))
        )
    if environment in NON_LOCAL_ENVIRONMENTS:
        missing_non_local = NON_LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
        if missing_non_local:
            raise DropAuthorizationSigningEvidenceError(
                "non-local drop authorization signing evidence is missing retained categories: "
                + ", ".join(sorted(missing_non_local))
            )
    if signature_status == "signed":
        missing_signed = SIGNED_REQUIRED_RETAINED_CATEGORIES - categories
        if missing_signed:
            raise DropAuthorizationSigningEvidenceError(
                "signed drop authorization evidence is missing retained categories: "
                + ", ".join(sorted(missing_signed))
            )
    if environment in PRODUCTION_ENVIRONMENTS:
        if review_status != "reviewed" or approval_status != "approved":
            raise DropAuthorizationSigningEvidenceError(
                "production drop authorization signing evidence must be reviewed and approved"
            )
        if signature_status != "signed":
            raise DropAuthorizationSigningEvidenceError(
                "production drop authorization signing evidence must be signed"
            )


def validate_evidence(path: Path, repo_root: Path) -> None:
    """Validate a drop authorization signing evidence metadata file."""
    validate_evidence_document(load_json(path), repo_root, str(path))


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate drop authorization signing evidence metadata"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        default=DEFAULT_EVIDENCE,
        help="Evidence metadata JSON files to validate",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the drop authorization signing evidence checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        if not args.evidence:
            raise DropAuthorizationSigningEvidenceError("no evidence files configured")
        for evidence_path in args.evidence:
            path = evidence_path
            if not path.is_absolute():
                path = repo_root / path
            validate_evidence(path, repo_root)
    except DropAuthorizationSigningEvidenceError as exc:
        print(f"drop authorization signing evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("drop authorization signing evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
