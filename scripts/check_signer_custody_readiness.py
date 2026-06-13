#!/usr/bin/env python3
"""Validate retained signer custody readiness evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from datetime import datetime
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.signer-custody-readiness.v1"
LOCAL_PLACEHOLDER_STATUS = "not_available_local"

DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/signer-custody-readiness/"
        "signer-custody-readiness-template.json"
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
        "signer_identity",
        "custody",
        "lifecycle",
        "operations",
        "review",
        "retained_artifacts",
        "redaction_policy",
        "template_notice",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
FILE_REF_FIELDS = frozenset({"path", "sha256"})
SIGNER_IDENTITY_FIELDS = frozenset(
    {
        "signer_type",
        "expected_signer",
        "signer_epoch",
        "signer_epoch_source",
        "signer_manager",
        "signer_manager_type",
        "erc1271_support_status",
        "erc1271_support_detail",
        "signer_service_class",
    }
)
ERC1271_SUPPORT_DETAIL_FIELDS = frozenset({"rationale", "evidence_reference"})
CUSTODY_FIELDS = frozenset(
    {
        "custody_owner",
        "custody_status",
        "custody_system",
        "approval_workflow_reference",
        "key_material_location",
        "separation_of_duties",
    }
)
LIFECYCLE_FIELDS = frozenset(
    {
        "rotation_status",
        "revocation_status",
        "compromise_response_status",
        "signer_epoch_rotation_tested",
        "per_drop_cancellation_tested",
        "last_rotation_drill",
        "last_revocation_drill",
    }
)
OPERATIONS_FIELDS = frozenset(
    {
        "monitoring_status",
        "runbook",
        "alerting_reference",
        "incident_response_runbook",
        "signer_service_integration_status",
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

SIGNER_TYPES = frozenset({"EOA", "ERC1271", "external_service", "hsm", "local_placeholder"})
SIGNER_MANAGER_TYPES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "safe", "multisig", "role_manager", "eoa_breakglass"}
)
ERC1271_STATUSES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "supported", "unsupported", "not_applicable", "pending", "blocked"}
)
SIGNER_SERVICE_CLASSES = frozenset(
    {
        LOCAL_PLACEHOLDER_STATUS,
        "offline_ceremony",
        "managed_signer",
        "hsm",
        "kms",
        "safe_module",
        "contract_wallet",
        "other",
    }
)
CUSTODY_STATUSES = frozenset({LOCAL_PLACEHOLDER_STATUS, "documented", "pending", "blocked"})
KEY_MATERIAL_LOCATIONS = frozenset(
    {
        LOCAL_PLACEHOLDER_STATUS,
        "external_custody_only",
        "hsm",
        "kms",
        "safe_contract",
        "offline_ceremony",
        "redacted",
    }
)
READINESS_STATUSES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "not_started", "planned", "pending", "complete", "blocked"}
)
MONITORING_STATUSES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "not_started", "planned", "pending", "validated", "blocked"}
)
INTEGRATION_STATUSES = frozenset(
    {LOCAL_PLACEHOLDER_STATUS, "not_started", "pending", "validated", "blocked"}
)
APPROVAL_STATUSES = frozenset({"template", "pending", "approved", "rejected"})

LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {"signer_custody_schema", "readiness_transcript"}
)
NON_LOCAL_REQUIRED_RETAINED_CATEGORIES = frozenset(
    {
        "custody_approval",
        "signer_service_attestation",
        "rotation_revocation_drill",
        "monitoring_runbook",
    }
)

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|hsm[_\-\s]?credential|signer[_\-\s]?secret|"
    r"unreleased[_\-\s]?drop[_\-\s]?payload|raw[_\-\s]?signature|bearer[_\-\s]?token"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])client[_\-\s]?secret([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
SAFE_SECRET_POLICY_KEYS = frozenset({"redaction_policy", "no_secrets", "redacted_fields"})
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|rpc[_ -]?url|api[_ -]?key|"
    r"password|client[_ -]?secret|hsm[_ -]?credential|signer[_ -]?secret|"
    r"bearer[_ -]?token|raw[_ -]?signature|unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)


class SignerCustodyReadinessError(RuntimeError):
    """Raised when signer custody readiness evidence is invalid."""


def load_json(path: Path) -> Any:
    """Load a JSON file with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise SignerCustodyReadinessError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise SignerCustodyReadinessError(f"invalid JSON in {path}: {exc}") from exc


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
        raise SignerCustodyReadinessError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise SignerCustodyReadinessError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise SignerCustodyReadinessError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise SignerCustodyReadinessError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value.strip() == "":
        raise SignerCustodyReadinessError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise SignerCustodyReadinessError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise SignerCustodyReadinessError(f"{path} must be an integer")
    return value


def require_positive_int(value: Any, path: str) -> int:
    """Require a positive integer."""
    number = require_int(value, path)
    if number < 1:
        raise SignerCustodyReadinessError(f"{path} must be greater than zero")
    return number


def require_non_negative_int(value: Any, path: str) -> int:
    """Require a non-negative integer."""
    number = require_int(value, path)
    if number < 0:
        raise SignerCustodyReadinessError(f"{path} must be zero or greater")
    return number


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from an enum set."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise SignerCustodyReadinessError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise SignerCustodyReadinessError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    """Require a 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise SignerCustodyReadinessError(
            f"{path} must be a 40-character git commit hash"
        )
    return commit


def require_address(value: Any, path: str) -> str:
    """Require an Ethereum address."""
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise SignerCustodyReadinessError(f"{path} must be an address")
    return address.lower()


def require_non_placeholder(value: Any, path: str) -> str:
    """Require a non-placeholder string for non-local or reviewed evidence."""
    text = require_string(value, path)
    if text == LOCAL_PLACEHOLDER_STATUS or text.strip().upper() == "TBD":
        raise SignerCustodyReadinessError(f"{path} must not be a placeholder")
    return text


def require_rfc3339_datetime(value: Any, path: str) -> str:
    """Require an RFC3339/ISO-8601 timestamp with an explicit timezone."""
    text = require_non_placeholder(value, path)
    normalized = text[:-1] + "+00:00" if text.endswith("Z") else text
    try:
        parsed = datetime.fromisoformat(normalized)
    except ValueError as exc:
        raise SignerCustodyReadinessError(
            f"{path} must be an RFC3339 date-time"
        ) from exc
    if parsed.tzinfo is None:
        raise SignerCustodyReadinessError(
            f"{path} must include an explicit timezone"
        )
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file path without allowing escapes."""
    if "\\" in relative_path:
        raise SignerCustodyReadinessError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise SignerCustodyReadinessError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise SignerCustodyReadinessError(
            f"{path} must stay inside the repository"
        ) from exc
    if not resolved.is_file():
        raise SignerCustodyReadinessError(
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
        raise SignerCustodyReadinessError(
            f"{path}.sha256 mismatch for {relative_path}: "
            f"expected {expected_hash}, got {actual_hash}"
        )
    return resolved


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed evidence."""
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            key_lower = key_text.lower()
            if key_lower not in SAFE_SECRET_POLICY_KEYS and SECRET_KEY_RE.search(key_text):
                raise SignerCustodyReadinessError(
                    f"secret-like key found at {path}.{key_text}"
                )
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise SignerCustodyReadinessError(f"secret-like value found at {path}")


def validate_source(value: Any) -> None:
    """Validate source control evidence metadata."""
    source = require_dict(value, "source")
    require_exact_keys(source, "source", SOURCE_FIELDS)
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit")
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_signer_identity(value: Any, environment: str) -> dict[str, Any]:
    """Validate signer identity and service readiness metadata."""
    identity = require_dict(value, "signer_identity")
    require_exact_keys(identity, "signer_identity", SIGNER_IDENTITY_FIELDS)
    signer_type = require_enum(
        identity.get("signer_type"), "signer_identity.signer_type", SIGNER_TYPES
    )
    require_address(identity.get("expected_signer"), "signer_identity.expected_signer")
    require_non_negative_int(
        identity.get("signer_epoch"), "signer_identity.signer_epoch"
    )
    require_string(identity.get("signer_epoch_source"), "signer_identity.signer_epoch_source")
    require_address(identity.get("signer_manager"), "signer_identity.signer_manager")
    manager_type = require_enum(
        identity.get("signer_manager_type"),
        "signer_identity.signer_manager_type",
        SIGNER_MANAGER_TYPES,
    )
    erc1271_status = require_enum(
        identity.get("erc1271_support_status"),
        "signer_identity.erc1271_support_status",
        ERC1271_STATUSES,
    )
    erc1271_detail = require_dict(
        identity.get("erc1271_support_detail"),
        "signer_identity.erc1271_support_detail",
    )
    require_exact_keys(
        erc1271_detail,
        "signer_identity.erc1271_support_detail",
        ERC1271_SUPPORT_DETAIL_FIELDS,
    )
    require_string(
        erc1271_detail.get("rationale"),
        "signer_identity.erc1271_support_detail.rationale",
    )
    require_string(
        erc1271_detail.get("evidence_reference"),
        "signer_identity.erc1271_support_detail.evidence_reference",
    )
    service_class = require_enum(
        identity.get("signer_service_class"),
        "signer_identity.signer_service_class",
        SIGNER_SERVICE_CLASSES,
    )

    if environment in NON_LOCAL_ENVIRONMENTS:
        if signer_type == "local_placeholder":
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use local_placeholder signer_type"
            )
        if manager_type == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local signer_manager_type"
            )
        if service_class == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local signer_service_class"
            )
        require_non_placeholder(
            identity.get("signer_epoch_source"), "signer_identity.signer_epoch_source"
        )
        if erc1271_status == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local erc1271 status"
            )
        require_non_placeholder(
            erc1271_detail.get("rationale"),
            "signer_identity.erc1271_support_detail.rationale",
        )
        require_non_placeholder(
            erc1271_detail.get("evidence_reference"),
            "signer_identity.erc1271_support_detail.evidence_reference",
        )
    if environment in PRODUCTION_ENVIRONMENTS and signer_type == "ERC1271":
        if erc1271_status != "supported":
            raise SignerCustodyReadinessError(
                "production ERC-1271 signer custody evidence must be supported"
            )
    return identity


def validate_custody(value: Any, environment: str) -> dict[str, Any]:
    """Validate custody owner, approval, and no-secret custody metadata."""
    custody = require_dict(value, "custody")
    require_exact_keys(custody, "custody", CUSTODY_FIELDS)
    require_string(custody.get("custody_owner"), "custody.custody_owner")
    status = require_enum(custody.get("custody_status"), "custody.custody_status", CUSTODY_STATUSES)
    require_string(custody.get("custody_system"), "custody.custody_system")
    require_string(
        custody.get("approval_workflow_reference"),
        "custody.approval_workflow_reference",
    )
    require_enum(
        custody.get("key_material_location"),
        "custody.key_material_location",
        KEY_MATERIAL_LOCATIONS,
    )
    separation = require_enum(
        custody.get("separation_of_duties"),
        "custody.separation_of_duties",
        READINESS_STATUSES,
    )

    if environment in NON_LOCAL_ENVIRONMENTS:
        require_non_placeholder(custody.get("custody_owner"), "custody.custody_owner")
        require_non_placeholder(custody.get("custody_system"), "custody.custody_system")
        require_non_placeholder(
            custody.get("approval_workflow_reference"),
            "custody.approval_workflow_reference",
        )
        if status == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local custody_status"
            )
        if custody.get("key_material_location") == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local key material location"
            )
        if separation == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local separation of duties"
            )
    if environment in PRODUCTION_ENVIRONMENTS and status != "documented":
        raise SignerCustodyReadinessError(
            "production signer custody evidence must have documented custody_status"
        )
    return custody


def validate_lifecycle(value: Any, environment: str) -> dict[str, Any]:
    """Validate rotation, revocation, compromise, and drill readiness."""
    lifecycle = require_dict(value, "lifecycle")
    require_exact_keys(lifecycle, "lifecycle", LIFECYCLE_FIELDS)
    rotation = require_enum(
        lifecycle.get("rotation_status"), "lifecycle.rotation_status", READINESS_STATUSES
    )
    revocation = require_enum(
        lifecycle.get("revocation_status"), "lifecycle.revocation_status", READINESS_STATUSES
    )
    compromise = require_enum(
        lifecycle.get("compromise_response_status"),
        "lifecycle.compromise_response_status",
        READINESS_STATUSES,
    )
    epoch_drill = require_bool(
        lifecycle.get("signer_epoch_rotation_tested"),
        "lifecycle.signer_epoch_rotation_tested",
    )
    cancellation_drill = require_bool(
        lifecycle.get("per_drop_cancellation_tested"),
        "lifecycle.per_drop_cancellation_tested",
    )
    require_string(lifecycle.get("last_rotation_drill"), "lifecycle.last_rotation_drill")
    require_string(lifecycle.get("last_revocation_drill"), "lifecycle.last_revocation_drill")

    if environment in NON_LOCAL_ENVIRONMENTS:
        for field, status in (
            ("rotation_status", rotation),
            ("revocation_status", revocation),
            ("compromise_response_status", compromise),
        ):
            if status == LOCAL_PLACEHOLDER_STATUS:
                raise SignerCustodyReadinessError(
                    f"non-local signer custody evidence cannot use not_available_local {field}"
                )
        require_non_placeholder(
            lifecycle.get("last_rotation_drill"), "lifecycle.last_rotation_drill"
        )
        require_non_placeholder(
            lifecycle.get("last_revocation_drill"), "lifecycle.last_revocation_drill"
        )
    if environment in PRODUCTION_ENVIRONMENTS:
        if rotation != "complete" or revocation != "complete" or compromise != "complete":
            raise SignerCustodyReadinessError(
                "production signer custody evidence must complete rotation, revocation, and compromise readiness"
            )
        if not epoch_drill or not cancellation_drill:
            raise SignerCustodyReadinessError(
                "production signer custody evidence must test signer epoch rotation and per-drop cancellation"
            )
    return lifecycle


def validate_operations(value: Any, repo_root: Path, environment: str) -> dict[str, Any]:
    """Validate runbook, monitoring, and signer-service integration metadata."""
    operations = require_dict(value, "operations")
    require_exact_keys(operations, "operations", OPERATIONS_FIELDS)
    monitoring_status = require_enum(
        operations.get("monitoring_status"),
        "operations.monitoring_status",
        MONITORING_STATUSES,
    )
    validate_file_ref(operations.get("runbook"), repo_root, "operations.runbook")
    require_string(operations.get("alerting_reference"), "operations.alerting_reference")
    validate_file_ref(
        operations.get("incident_response_runbook"),
        repo_root,
        "operations.incident_response_runbook",
    )
    integration_status = require_enum(
        operations.get("signer_service_integration_status"),
        "operations.signer_service_integration_status",
        INTEGRATION_STATUSES,
    )

    if environment in NON_LOCAL_ENVIRONMENTS:
        if monitoring_status == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local monitoring_status"
            )
        if integration_status == LOCAL_PLACEHOLDER_STATUS:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence cannot use not_available_local signer service integration status"
            )
        require_non_placeholder(
            operations.get("alerting_reference"), "operations.alerting_reference"
        )
    if environment in PRODUCTION_ENVIRONMENTS:
        if monitoring_status != "validated" or integration_status != "validated":
            raise SignerCustodyReadinessError(
                "production signer custody evidence must validate monitoring and signer-service integration"
            )
    return operations


def validate_review(value: Any, review_status: str) -> str:
    """Validate reviewer approval metadata."""
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
            raise SignerCustodyReadinessError(
                "review.approval_status must be approved before reviewed"
            )
    return approval_status


def validate_retained_artifacts(value: Any, repo_root: Path) -> set[str]:
    """Validate retained artifact file/hash references."""
    retained = require_list(value, "retained_artifacts")
    if not retained:
        raise SignerCustodyReadinessError("retained_artifacts must not be empty")
    categories: set[str] = set()
    for index, item in enumerate(retained):
        artifact = require_dict(item, f"retained_artifacts[{index}]")
        require_exact_keys(artifact, f"retained_artifacts[{index}]", RETAINED_ARTIFACT_FIELDS)
        category = require_string(
            artifact.get("category"), f"retained_artifacts[{index}].category"
        )
        if category in categories:
            raise SignerCustodyReadinessError(
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


def validate_redaction_policy(value: Any) -> None:
    """Validate the no-secret redaction policy."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    if not require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets"):
        raise SignerCustodyReadinessError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise SignerCustodyReadinessError(
            "redaction_policy.redacted_fields must not be empty"
        )
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def validate_template_notice(record_type: str, value: str) -> None:
    """Require templates to say they are not completion evidence."""
    if record_type != "template":
        return
    lowered = value.lower()
    if "template" not in lowered or "not completion evidence" not in lowered:
        raise SignerCustodyReadinessError(
            "template_notice must say template and not completion evidence"
        )


def validate_evidence_document(data: Any, repo_root: Path, label: str = "evidence") -> None:
    """Validate an in-memory signer custody readiness evidence document."""
    evidence = require_dict(data, label)
    scan_for_secret_like_data(evidence)
    require_exact_keys(evidence, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(evidence.get("schema_version"), "schema_version")
    if schema_version != EVIDENCE_SCHEMA:
        raise SignerCustodyReadinessError(f"schema_version must be {EVIDENCE_SCHEMA}")

    record_type = require_enum(evidence.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_enum(
        evidence.get("review_status"), "review_status", REVIEW_STATUSES
    )
    if record_type == "template" and review_status != "template":
        raise SignerCustodyReadinessError("template records must use template review_status")
    if record_type == "evidence" and review_status == "template":
        raise SignerCustodyReadinessError("evidence records cannot use template review_status")

    environment = require_enum(evidence.get("environment"), "environment", ENVIRONMENTS)
    require_positive_int(evidence.get("chain_id"), "chain_id")
    validate_source(evidence.get("source"))
    validate_signer_identity(evidence.get("signer_identity"), environment)
    validate_custody(evidence.get("custody"), environment)
    validate_lifecycle(evidence.get("lifecycle"), environment)
    validate_operations(evidence.get("operations"), repo_root, environment)
    approval_status = validate_review(evidence.get("review"), review_status)
    categories = validate_retained_artifacts(evidence.get("retained_artifacts"), repo_root)
    validate_redaction_policy(evidence.get("redaction_policy"))
    template_notice = require_string(evidence.get("template_notice"), "template_notice")
    validate_template_notice(record_type, template_notice)
    require_string(evidence.get("operator_notes"), "operator_notes")

    missing_local = LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
    if record_type == "template" and missing_local:
        raise SignerCustodyReadinessError(
            "local signer custody readiness template is missing retained categories: "
            + ", ".join(sorted(missing_local))
        )
    if environment in NON_LOCAL_ENVIRONMENTS:
        missing_non_local = NON_LOCAL_REQUIRED_RETAINED_CATEGORIES - categories
        if missing_non_local:
            raise SignerCustodyReadinessError(
                "non-local signer custody evidence is missing retained categories: "
                + ", ".join(sorted(missing_non_local))
            )
    if environment in PRODUCTION_ENVIRONMENTS:
        if review_status != "reviewed" or approval_status != "approved":
            raise SignerCustodyReadinessError(
                "production signer custody evidence must be reviewed and approved"
            )


def validate_evidence(path: Path, repo_root: Path) -> None:
    """Validate a signer custody readiness metadata file."""
    validate_evidence_document(load_json(path), repo_root, str(path))


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate signer custody readiness evidence metadata"
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
    """Run the signer custody readiness checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        if not args.evidence:
            raise SignerCustodyReadinessError("no evidence files configured")
        for evidence_path in args.evidence:
            path = evidence_path
            if not path.is_absolute():
                path = repo_root / path
            validate_evidence(path, repo_root)
    except SignerCustodyReadinessError as exc:
        print(f"signer custody readiness check failed: {exc}", file=sys.stderr)
        return 1
    print("signer custody readiness evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
