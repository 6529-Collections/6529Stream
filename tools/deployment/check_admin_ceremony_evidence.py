#!/usr/bin/env python3
"""Validate retained admin ceremony evidence bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.admin-ceremony-evidence.v1"
DEFAULT_EVIDENCE_DIR = Path("deployments/admin-ceremony")

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "evidence_id",
        "record_type",
        "review_status",
        "environment",
        "chain_id",
        "source",
        "deployment",
        "participants",
        "ownership",
        "roles",
        "signer_setup",
        "pause_and_emergency",
        "verification",
        "review",
        "retained_artifacts",
        "redaction_policy",
        "template_notice",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
FILE_REF_FIELDS = frozenset({"path", "sha256"})
DEPLOYMENT_FIELDS = frozenset(
    {
        "protocol_version",
        "deployment_version",
        "deployment_manifest",
        "address_book",
        "release_manifest",
        "checksum_bundle",
    }
)
PARTICIPANT_FIELDS = frozenset(
    {
        "deployer",
        "admin_safe",
        "pause_guardian",
        "emergency_recipient",
        "drop_signer",
        "signer_manager",
    }
)
OWNERSHIP_FIELDS = frozenset(
    {
        "status",
        "owner_before",
        "owner_after",
        "transfer_tx",
        "temporary_deployer_admin_revoked",
        "rationale",
    }
)
ROLE_BUCKETS = frozenset(
    {
        "global_admins",
        "function_admins",
        "signer_managers",
        "pause_guardians",
        "unpause_admins",
    }
)
ROLE_GRANT_FIELDS = frozenset({"role", "target", "account", "status", "tx", "rationale"})
SIGNER_SETUP_FIELDS = frozenset(
    {
        "status",
        "drop_signer",
        "signer_epoch",
        "signer_manager",
        "rotation_or_cancellation_test",
        "tx",
        "rationale",
    }
)
PAUSE_FIELDS = frozenset(
    {
        "status",
        "mint_pause_admin",
        "bid_pause_admin",
        "settlement_pause_admin",
        "withdrawal_pause_policy",
        "emergency_recipient",
        "tx",
        "rationale",
    }
)
VERIFICATION_FIELDS = frozenset(
    {
        "contract_verification",
        "source_verification_inputs",
        "explorer_verification",
        "post_state_views",
        "rationale",
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
CHAIN_IDS_BY_ENVIRONMENT = {
    "local": {31337},
    "fork": {1},
    "testnet": {11155111},
    "mainnet": {1},
    "production": {1},
}
CEREMONY_STATUSES = frozenset(
    {"template", "not_started", "pending", "complete", "intentionally_blocked", "blocked"}
)
REVIEW_APPROVAL_STATUSES = frozenset({"template", "pending", "approved", "rejected"})
FINAL_STATUSES = frozenset({"complete", "pending", "intentionally_blocked", "blocked"})
PLACEHOLDER_VALUES = frozenset({"TBD", "template", "not_available_local", "not_available_template"})
REQUIRED_TEMPLATE_RETAINED_CATEGORIES = frozenset(
    {"admin_ceremony_schema", "admin_ceremony_retained_artifact_template"}
)
REQUIRED_REVIEWED_RETAINED_CATEGORIES = frozenset(
    {
        "admin_ceremony_schema",
        "admin_ceremony_retained_artifact_template",
        "ownership_transfer_or_blocker",
        "role_grants_and_revocations",
        "signer_setup",
        "pause_and_emergency_setup",
        "post_state_views",
        "verification_status",
        "approval_record",
    }
)
REQUIRED_REDACTION_TERMS = frozenset(
    {
        "private_key",
        "mnemonic",
        "seed_phrase",
        "safe_signing_secret",
        "signer_service_credentials",
        "signer_secret",
        "password",
        "client_secret",
        "api_key",
        "rpc_url",
        "private_rpc_url",
        "bearer_token",
        "session_cookie",
        "raw_signature",
        "unreleased_drop_payload",
    }
)

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
TEMPLATE_ADDRESSES = frozenset(
    f"0x{index:040x}" for index in range(1, 6)
)
PLACEHOLDER_SHA = "sha256:" + "0" * 64
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|safe[_\-\s]?signing[_\-\s]?secret|"
    r"rpc[_\-\s]?url|api[_\-\s]?key|password|client[_\-\s]?secret|"
    r"signer[_\-\s]?secret|raw[_\-\s]?signature|bearer[_\-\s]?token|"
    r"unreleased[_\-\s]?drop[_\-\s]?payload"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
SAFE_SECRET_POLICY_KEYS = frozenset({"redaction_policy", "no_secrets", "redacted_fields"})
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|safe[_ -]?signing[_ -]?secret|"
    r"rpc[_ -]?url|api[_ -]?key|password|client[_ -]?secret|signer[_ -]?secret|"
    r"bearer[_ -]?token|raw[_ -]?signature|unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s\"`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s\"`]*"
    r")",
    re.IGNORECASE,
)


class AdminCeremonyEvidenceError(RuntimeError):
    """Raised when admin ceremony evidence is invalid."""


def load_json(path: Path) -> Any:
    """Load a JSON file with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise AdminCeremonyEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise AdminCeremonyEvidenceError(f"invalid JSON in {path}: {exc}") from exc


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
        raise AdminCeremonyEvidenceError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise AdminCeremonyEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise AdminCeremonyEvidenceError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise AdminCeremonyEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value.strip() == "":
        raise AdminCeremonyEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise AdminCeremonyEvidenceError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise AdminCeremonyEvidenceError(f"{path} must be an integer")
    return value


def require_member(value: Any, path: str, allowed: frozenset[str]) -> str:
    """Require a string member of a fixed set."""
    text = require_string(value, path)
    if text not in allowed:
        raise AdminCeremonyEvidenceError(
            f"{path} must be one of {', '.join(sorted(allowed))}"
        )
    return text


def require_address(value: Any, path: str, *, allow_zero: bool, reviewed: bool = False) -> str:
    """Require an address, optionally allowing the zero address."""
    text = require_string(value, path)
    if not ADDRESS_RE.fullmatch(text):
        raise AdminCeremonyEvidenceError(f"{path} must be an Ethereum address")
    if not allow_zero and int(text, 16) == 0:
        raise AdminCeremonyEvidenceError(f"{path} cannot be the zero address")
    if reviewed and text.lower() in TEMPLATE_ADDRESSES:
        raise AdminCeremonyEvidenceError(f"{path} cannot use a template placeholder address")
    return text


def require_sha256(value: Any, path: str, *, allow_placeholder: bool) -> str:
    """Require a sha256-prefixed digest."""
    text = require_string(value, path)
    if not SHA256_RE.fullmatch(text):
        raise AdminCeremonyEvidenceError(f"{path} must be a sha256 digest")
    if not allow_placeholder and text == PLACEHOLDER_SHA:
        raise AdminCeremonyEvidenceError(f"{path} cannot use the placeholder digest")
    return text


def require_git_commit(value: Any, path: str, *, reviewed: bool) -> str:
    """Require a 40-character commit hash."""
    text = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(text):
        raise AdminCeremonyEvidenceError(f"{path} must be a 40-character git commit")
    if reviewed and int(text, 16) == 0:
        raise AdminCeremonyEvidenceError(f"{path} cannot use the all-zero git commit")
    return text


def normalize_repo_path(value: str) -> Path:
    """Parse a repo-relative path and reject absolute paths or traversal."""
    path = Path(value)
    if path.is_absolute() or ".." in path.parts:
        raise AdminCeremonyEvidenceError(f"retained artifact path must be repo-relative: {value}")
    return path


def resolve_repo_relative_path(repo_root: Path, value: str) -> Path:
    """Resolve a repo-relative path while rejecting path escapes."""
    candidate = normalize_repo_path(value)
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise AdminCeremonyEvidenceError(
            f"retained artifact path escapes repository: {value}"
        ) from exc
    return resolved


def validate_file_ref(
    value: Any,
    path: str,
    repo_root: Path,
    *,
    require_existing: bool,
    allow_placeholder: bool,
) -> dict[str, str]:
    """Validate a file reference and optionally check its digest."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, FILE_REF_FIELDS)
    file_path = require_string(ref.get("path"), f"{path}.path")
    digest = require_sha256(
        ref.get("sha256"), f"{path}.sha256", allow_placeholder=allow_placeholder
    )
    if file_path == "TBD":
        if require_existing:
            raise AdminCeremonyEvidenceError(f"{path}.path cannot be TBD")
        return {"path": file_path, "sha256": digest}

    resolved = resolve_repo_relative_path(repo_root, file_path)
    if require_existing:
        if not resolved.is_file():
            raise AdminCeremonyEvidenceError(f"{path}.path points to missing file: {file_path}")
        actual = file_sha256(resolved)
        if actual != digest:
            raise AdminCeremonyEvidenceError(
                f"{path}.sha256 is stale for {file_path}: expected {digest}, actual {actual}"
            )
        validate_no_secret_values(load_text(resolved), f"{path}.path")
    return {"path": file_path, "sha256": digest}


def load_text(path: Path) -> str:
    """Read UTF-8 text with checker-specific errors."""
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        raise AdminCeremonyEvidenceError(f"{path} must be valid UTF-8") from exc


def is_redaction_policy_path(path: str) -> bool:
    """Return whether a JSON path is the redaction policy subtree."""
    return path == "redaction_policy" or path.startswith("redaction_policy.")


def validate_no_secret_key(key: str, path: str) -> None:
    """Reject secret-shaped keys except the redaction policy itself."""
    if key in SAFE_SECRET_POLICY_KEYS or is_redaction_policy_path(path):
        return
    if SECRET_KEY_RE.search(key):
        raise AdminCeremonyEvidenceError(f"{path} contains secret-like key: {key}")


def validate_no_secret_values(value: Any, path: str = "$") -> None:
    """Reject secret-shaped key/value material."""
    if isinstance(value, dict):
        for key, child in value.items():
            validate_no_secret_key(str(key), path)
            validate_no_secret_values(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            validate_no_secret_values(child, f"{path}[{index}]")
    elif isinstance(value, str) and not is_redaction_policy_path(path):
        match = SECRET_VALUE_RE.search(value) or CLI_SECRET_RE.search(value)
        if match:
            raise AdminCeremonyEvidenceError(
                f"{path} contains secret-like value: {match.group(0)}"
            )


def contains_placeholder(value: Any) -> bool:
    """Return whether a value contains a template placeholder."""
    if isinstance(value, dict):
        return any(contains_placeholder(child) for child in value.values())
    if isinstance(value, list):
        return any(contains_placeholder(child) for child in value)
    if isinstance(value, str):
        stripped = value.strip()
        return stripped in PLACEHOLDER_VALUES or stripped == PLACEHOLDER_SHA
    return False


def require_reviewed_no_placeholders(data: dict[str, Any]) -> None:
    """Reviewed evidence cannot keep template placeholders."""
    if contains_placeholder(data):
        raise AdminCeremonyEvidenceError("reviewed admin ceremony evidence contains placeholders")


def validate_source(value: Any, *, reviewed: bool) -> None:
    """Validate source metadata."""
    source = require_dict(value, "source")
    require_exact_keys(source, "source", SOURCE_FIELDS)
    require_string(source.get("repository"), "source.repository")
    require_git_commit(source.get("git_commit"), "source.git_commit", reviewed=reviewed)
    require_bool(source.get("source_dirty"), "source.source_dirty")
    require_string(source.get("ci_run"), "source.ci_run")


def validate_deployment(value: Any, repo_root: Path, *, reviewed: bool) -> dict[str, Any]:
    """Validate deployment references."""
    deployment = require_dict(value, "deployment")
    require_exact_keys(deployment, "deployment", DEPLOYMENT_FIELDS)
    require_string(deployment.get("protocol_version"), "deployment.protocol_version")
    require_string(deployment.get("deployment_version"), "deployment.deployment_version")
    require_existing = reviewed
    allow_placeholder = not reviewed
    for field in (
        "deployment_manifest",
        "address_book",
        "release_manifest",
        "checksum_bundle",
    ):
        validate_file_ref(
            deployment.get(field),
            f"deployment.{field}",
            repo_root,
            require_existing=require_existing,
            allow_placeholder=allow_placeholder,
        )
    return deployment


def validate_participants(value: Any, *, reviewed: bool) -> None:
    """Validate privileged participant addresses."""
    participants = require_dict(value, "participants")
    require_exact_keys(participants, "participants", PARTICIPANT_FIELDS)
    for field in PARTICIPANT_FIELDS:
        require_address(
            participants.get(field),
            f"participants.{field}",
            allow_zero=not reviewed,
            reviewed=reviewed,
        )


def validate_status(value: Any, path: str, *, reviewed: bool) -> str:
    """Validate a ceremony status."""
    status = require_member(value, path, CEREMONY_STATUSES)
    if reviewed and status == "template":
        raise AdminCeremonyEvidenceError(f"{path} cannot be template for reviewed evidence")
    return status


def require_rationale_for_non_complete(status: str, rationale: str, path: str) -> None:
    """Require a useful rationale when reviewed evidence is not complete."""
    if status != "complete" and rationale in PLACEHOLDER_VALUES:
        raise AdminCeremonyEvidenceError(f"{path} needs rationale for status {status}")


def validate_ownership(value: Any, *, reviewed: bool) -> None:
    """Validate ownership transfer evidence."""
    ownership = require_dict(value, "ownership")
    require_exact_keys(ownership, "ownership", OWNERSHIP_FIELDS)
    status = validate_status(ownership.get("status"), "ownership.status", reviewed=reviewed)
    require_address(
        ownership.get("owner_before"),
        "ownership.owner_before",
        allow_zero=not reviewed,
        reviewed=reviewed,
    )
    require_address(
        ownership.get("owner_after"),
        "ownership.owner_after",
        allow_zero=not reviewed,
        reviewed=reviewed,
    )
    require_string(ownership.get("transfer_tx"), "ownership.transfer_tx")
    validate_status(
        ownership.get("temporary_deployer_admin_revoked"),
        "ownership.temporary_deployer_admin_revoked",
        reviewed=reviewed,
    )
    rationale = require_string(ownership.get("rationale"), "ownership.rationale")
    if reviewed:
        require_rationale_for_non_complete(status, rationale, "ownership.rationale")


def validate_role_grant(value: Any, path: str, *, reviewed: bool) -> None:
    """Validate a role grant or intentionally blocked role row."""
    grant = require_dict(value, path)
    require_exact_keys(grant, path, ROLE_GRANT_FIELDS)
    require_string(grant.get("role"), f"{path}.role")
    require_string(grant.get("target"), f"{path}.target")
    require_address(
        grant.get("account"),
        f"{path}.account",
        allow_zero=not reviewed,
        reviewed=reviewed,
    )
    status = validate_status(grant.get("status"), f"{path}.status", reviewed=reviewed)
    require_string(grant.get("tx"), f"{path}.tx")
    rationale = require_string(grant.get("rationale"), f"{path}.rationale")
    if reviewed:
        require_rationale_for_non_complete(status, rationale, f"{path}.rationale")


def validate_roles(value: Any, *, reviewed: bool) -> None:
    """Validate role-grant evidence for every privileged bucket."""
    roles = require_dict(value, "roles")
    require_exact_keys(roles, "roles", ROLE_BUCKETS)
    for bucket in sorted(ROLE_BUCKETS):
        entries = require_list(roles.get(bucket), f"roles.{bucket}")
        if not entries:
            raise AdminCeremonyEvidenceError(f"roles.{bucket} must include at least one row")
        for index, entry in enumerate(entries):
            validate_role_grant(entry, f"roles.{bucket}[{index}]", reviewed=reviewed)


def validate_signer_setup(value: Any, *, reviewed: bool) -> None:
    """Validate drop signer and signer-manager setup evidence."""
    setup = require_dict(value, "signer_setup")
    require_exact_keys(setup, "signer_setup", SIGNER_SETUP_FIELDS)
    status = validate_status(setup.get("status"), "signer_setup.status", reviewed=reviewed)
    require_address(
        setup.get("drop_signer"),
        "signer_setup.drop_signer",
        allow_zero=not reviewed,
        reviewed=reviewed,
    )
    epoch = require_int(setup.get("signer_epoch"), "signer_setup.signer_epoch")
    if epoch < 0:
        raise AdminCeremonyEvidenceError("signer_setup.signer_epoch cannot be negative")
    require_address(
        setup.get("signer_manager"),
        "signer_setup.signer_manager",
        allow_zero=not reviewed,
        reviewed=reviewed,
    )
    validate_status(
        setup.get("rotation_or_cancellation_test"),
        "signer_setup.rotation_or_cancellation_test",
        reviewed=reviewed,
    )
    require_string(setup.get("tx"), "signer_setup.tx")
    rationale = require_string(setup.get("rationale"), "signer_setup.rationale")
    if reviewed:
        require_rationale_for_non_complete(status, rationale, "signer_setup.rationale")


def validate_pause_and_emergency(value: Any, *, reviewed: bool) -> None:
    """Validate pause and emergency authority evidence."""
    pause = require_dict(value, "pause_and_emergency")
    require_exact_keys(pause, "pause_and_emergency", PAUSE_FIELDS)
    status = validate_status(pause.get("status"), "pause_and_emergency.status", reviewed=reviewed)
    for field in (
        "mint_pause_admin",
        "bid_pause_admin",
        "settlement_pause_admin",
        "emergency_recipient",
    ):
        require_address(
            pause.get(field),
            f"pause_and_emergency.{field}",
            allow_zero=not reviewed,
            reviewed=reviewed,
        )
    require_string(
        pause.get("withdrawal_pause_policy"),
        "pause_and_emergency.withdrawal_pause_policy",
    )
    require_string(pause.get("tx"), "pause_and_emergency.tx")
    rationale = require_string(pause.get("rationale"), "pause_and_emergency.rationale")
    if reviewed:
        require_rationale_for_non_complete(status, rationale, "pause_and_emergency.rationale")


def validate_verification(value: Any, *, reviewed: bool) -> None:
    """Validate post-state and verification evidence."""
    verification = require_dict(value, "verification")
    require_exact_keys(verification, "verification", VERIFICATION_FIELDS)
    statuses = []
    for field in (
        "contract_verification",
        "source_verification_inputs",
        "explorer_verification",
        "post_state_views",
    ):
        statuses.append(validate_status(verification.get(field), f"verification.{field}", reviewed=reviewed))
    rationale = require_string(verification.get("rationale"), "verification.rationale")
    if reviewed:
        for status in statuses:
            require_rationale_for_non_complete(status, rationale, "verification.rationale")


def validate_review(value: Any, *, reviewed: bool) -> None:
    """Validate review metadata."""
    review = require_dict(value, "review")
    require_exact_keys(review, "review", REVIEW_FIELDS)
    require_string(review.get("owner"), "review.owner")
    require_string(review.get("reviewer"), "review.reviewer")
    approval_status = require_member(
        review.get("approval_status"), "review.approval_status", REVIEW_APPROVAL_STATUSES
    )
    require_string(review.get("approval_reference"), "review.approval_reference")
    require_string(review.get("reviewed_at"), "review.reviewed_at")
    if reviewed and approval_status != "approved":
        raise AdminCeremonyEvidenceError("review.approval_status must be approved")


def validate_retained_artifacts(value: Any, repo_root: Path, *, reviewed: bool) -> None:
    """Validate retained artifact rows and hashes."""
    artifacts = require_list(value, "retained_artifacts")
    if not artifacts:
        raise AdminCeremonyEvidenceError("retained_artifacts must not be empty")
    categories = set()
    for index, item in enumerate(artifacts):
        path = f"retained_artifacts[{index}]"
        artifact = require_dict(item, path)
        require_exact_keys(artifact, path, RETAINED_ARTIFACT_FIELDS)
        category = require_string(artifact.get("category"), f"{path}.category")
        if category in categories:
            raise AdminCeremonyEvidenceError(f"duplicate retained artifact category: {category}")
        categories.add(category)
        validate_file_ref(
            {"path": artifact.get("path"), "sha256": artifact.get("sha256")},
            path,
            repo_root,
            require_existing=reviewed or category in REQUIRED_TEMPLATE_RETAINED_CATEGORIES,
            allow_placeholder=not reviewed and category not in REQUIRED_TEMPLATE_RETAINED_CATEGORIES,
        )
    required = (
        REQUIRED_REVIEWED_RETAINED_CATEGORIES
        if reviewed
        else REQUIRED_TEMPLATE_RETAINED_CATEGORIES
    )
    missing = required - categories
    if missing:
        raise AdminCeremonyEvidenceError(
            "retained_artifacts missing required category: "
            + ", ".join(sorted(missing))
        )


def validate_redaction_policy(value: Any) -> None:
    """Validate no-secret redaction policy metadata."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    if require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets") is not True:
        raise AdminCeremonyEvidenceError("redaction_policy.no_secrets must be true")
    redacted_fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    values = {require_string(item, "redaction_policy.redacted_fields[]") for item in redacted_fields}
    missing = sorted(REQUIRED_REDACTION_TERMS - values)
    if missing:
        raise AdminCeremonyEvidenceError(
            f"redaction_policy.redacted_fields missing: {', '.join(missing)}"
        )


def validate_environment_chain(environment: str, chain_id: int) -> None:
    """Validate the environment/chain ID pairing."""
    allowed = CHAIN_IDS_BY_ENVIRONMENT[environment]
    if chain_id not in allowed:
        raise AdminCeremonyEvidenceError(
            f"chain_id {chain_id} is not allowed for environment {environment}"
        )


def validate_evidence_document(data: Any, repo_root: Path, source_name: str = "<document>") -> None:
    """Validate an admin ceremony evidence document."""
    document = require_dict(data, source_name)
    require_exact_keys(document, source_name, TOP_LEVEL_FIELDS)
    validate_no_secret_values(document)

    if document.get("schema_version") != EVIDENCE_SCHEMA:
        raise AdminCeremonyEvidenceError(
            f"schema_version must be {EVIDENCE_SCHEMA}"
        )
    require_string(document.get("evidence_id"), "evidence_id")
    record_type = require_member(document.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_member(
        document.get("review_status"), "review_status", REVIEW_STATUSES
    )
    environment = require_member(document.get("environment"), "environment", ENVIRONMENTS)
    chain_id = require_int(document.get("chain_id"), "chain_id")
    validate_environment_chain(environment, chain_id)

    if record_type == "template" and review_status != "template":
        raise AdminCeremonyEvidenceError("template records must use review_status template")
    if record_type == "evidence" and review_status == "template":
        raise AdminCeremonyEvidenceError("evidence records cannot use review_status template")
    reviewed = review_status == "reviewed"

    validate_source(document.get("source"), reviewed=reviewed)
    validate_deployment(document.get("deployment"), repo_root, reviewed=reviewed)
    validate_participants(document.get("participants"), reviewed=reviewed)
    validate_ownership(document.get("ownership"), reviewed=reviewed)
    validate_roles(document.get("roles"), reviewed=reviewed)
    validate_signer_setup(document.get("signer_setup"), reviewed=reviewed)
    validate_pause_and_emergency(document.get("pause_and_emergency"), reviewed=reviewed)
    validate_verification(document.get("verification"), reviewed=reviewed)
    validate_review(document.get("review"), reviewed=reviewed)
    validate_retained_artifacts(document.get("retained_artifacts"), repo_root, reviewed=reviewed)
    validate_redaction_policy(document.get("redaction_policy"))
    require_string(document.get("template_notice"), "template_notice")
    require_string(document.get("operator_notes"), "operator_notes")

    if reviewed:
        require_reviewed_no_placeholders(document)


def validate_evidence(path: Path, repo_root: Path | None = None) -> None:
    """Validate a JSON evidence file."""
    resolved_root = Path.cwd() if repo_root is None else repo_root
    validate_evidence_document(load_json(path), resolved_root, str(path))


def default_evidence_paths(repo_root: Path) -> list[Path]:
    """Return the default admin ceremony JSON evidence set."""
    evidence_dir = repo_root / DEFAULT_EVIDENCE_DIR
    if not evidence_dir.is_dir():
        raise AdminCeremonyEvidenceError(f"missing required directory: {DEFAULT_EVIDENCE_DIR}")
    paths = sorted(evidence_dir.glob("*.json"))
    if not paths:
        raise AdminCeremonyEvidenceError(f"no admin ceremony evidence JSON files in {DEFAULT_EVIDENCE_DIR}")
    return paths


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("paths", nargs="*", type=Path, help="Evidence JSON files to validate")
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """CLI entrypoint."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root
    paths = args.paths or default_evidence_paths(repo_root)
    try:
        for path in paths:
            validate_evidence(path, repo_root)
    except AdminCeremonyEvidenceError as exc:
        print(f"admin ceremony evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("admin ceremony evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
