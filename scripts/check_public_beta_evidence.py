#!/usr/bin/env python3
"""Validate the public-beta and production evidence status manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


EVIDENCE_SCHEMA = "6529stream.public-beta-evidence.v1"
DEFAULT_EVIDENCE = Path("release-artifacts/latest/public-beta-evidence.json")

PUBLIC_BETA_PHASE = "public_beta"
PRODUCTION_PHASE = "production_release"

PUBLIC_BETA_REQUIREMENTS = (
    "external_audit_report",
    "fork_deployment_rehearsal",
    "testnet_deployment_rehearsal",
    "fork_testnet_metadata_browser_evidence",
    "fork_testnet_ceremony_evidence",
    "fork_testnet_randomizer_operations_evidence",
    "verified_deployed_addresses",
    "explorer_verification_status",
)
PRODUCTION_REQUIREMENTS = (
    "production_signatures",
    "signed_git_tag",
    "production_address_books",
    "production_broadcast_retention",
    "live_deployment_manifest",
    "live_ceremony_evidence",
    "live_randomizer_operations_evidence",
    "live_explorer_verification",
    "post_audit_remediation",
)
REQUIRED_BY_PHASE = {
    PUBLIC_BETA_PHASE: frozenset(PUBLIC_BETA_REQUIREMENTS),
    PRODUCTION_PHASE: frozenset(PRODUCTION_REQUIREMENTS),
}

OVERALL_STATUSES = frozenset({"blocked", "ready"})
REQUIREMENT_STATUSES = frozenset(
    {"missing", "pending", "blocked", "accepted_risk", "not_applicable", "complete"}
)
BLOCKING_STATUSES = frozenset({"missing", "pending", "blocked"})

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "release_version",
        "source",
        "status",
        "requirements",
        "retained_artifacts",
        "redaction_policy",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
STATUS_FIELDS = frozenset({PUBLIC_BETA_PHASE, PRODUCTION_PHASE})
REQUIREMENT_FIELDS = frozenset(
    {"id", "phase", "status", "owner", "evidence", "risk_acceptance", "notes"}
)
RISK_ACCEPTANCE_FIELDS = frozenset(
    {"accepted_by", "accepted_at", "expires_at", "reference", "notes"}
)
FILE_REF_FIELDS = frozenset({"path", "sha256"})
RETAINED_ARTIFACT_FIELDS = frozenset({"category", "path", "sha256"})
REDACTION_POLICY_FIELDS = frozenset({"no_secrets", "redacted_fields"})

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
ISO_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|unreleased[_\-\s]?drop[_\-\s]?payload"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])client[_\-\s]?secret([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
SAFE_SECRET_POLICY_KEYS = frozenset({"redaction_policy", "no_secrets", "redacted_fields"})
SECRET_VALUE_RE = re.compile(
    r"\b(private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|api[_ -]?key|password|unreleased[_ -]?drop[_ -]?payload)\s*[:=]",
    re.IGNORECASE,
)


class PublicBetaEvidenceError(RuntimeError):
    """Raised when public-beta evidence is missing, stale, or unsafe."""


def load_json(path: Path) -> Any:
    """Load a JSON file with a checker-specific error message."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise PublicBetaEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise PublicBetaEvidenceError(f"invalid JSON in {path}: {exc}") from exc


def sha256_bytes(value: bytes) -> str:
    """Return a sha256-prefixed digest for raw bytes."""
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    """Hash a file using the release artifact digest format."""
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require an object at a JSON path."""
    if not isinstance(value, dict):
        raise PublicBetaEvidenceError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require an object to have exactly the expected fields."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise PublicBetaEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise PublicBetaEvidenceError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require an array at a JSON path."""
    if not isinstance(value, list):
        raise PublicBetaEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string at a JSON path."""
    if not isinstance(value, str) or value == "":
        raise PublicBetaEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean at a JSON path."""
    if not isinstance(value, bool):
        raise PublicBetaEvidenceError(f"{path} must be a boolean")
    return value


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string value to be one of the allowed choices."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise PublicBetaEvidenceError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest at a JSON path."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise PublicBetaEvidenceError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    """Require a full 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise PublicBetaEvidenceError(f"{path} must be a 40-character git commit hash")
    return commit


def require_iso_date(value: Any, path: str) -> str:
    """Require an ISO-8601 date string in YYYY-MM-DD form."""
    text = require_string(value, path)
    if not ISO_DATE_RE.fullmatch(text):
        raise PublicBetaEvidenceError(f"{path} must be an ISO-8601 date (YYYY-MM-DD)")
    return text


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a forward-slash repo path and reject traversal."""
    if "\\" in relative_path:
        raise PublicBetaEvidenceError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise PublicBetaEvidenceError(f"{path} must stay inside the repository")
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise PublicBetaEvidenceError(f"{path} must stay inside the repository") from exc
    if not resolved.is_file():
        raise PublicBetaEvidenceError(f"{path} references missing file: {relative_path}")
    return resolved


def validate_file_ref(
    value: Any,
    repo_root: Path,
    path: str,
    expected_fields: frozenset[str] = FILE_REF_FIELDS,
) -> Path:
    """Validate a retained file reference and its sha256 digest."""
    ref = require_dict(value, path)
    require_exact_keys(ref, path, expected_fields)
    relative_path = require_string(ref.get("path"), f"{path}.path")
    expected_hash = require_sha256(ref.get("sha256"), f"{path}.sha256")
    resolved = resolve_repo_file(repo_root, relative_path, f"{path}.path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise PublicBetaEvidenceError(
            f"{path}.sha256 mismatch for {relative_path}: expected {expected_hash}, got {actual_hash}"
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


def validate_status(value: Any) -> dict[str, str]:
    """Validate the top-level public beta and production statuses."""
    status = require_dict(value, "status")
    require_exact_keys(status, "status", STATUS_FIELDS)
    return {
        PUBLIC_BETA_PHASE: require_enum(
            status.get(PUBLIC_BETA_PHASE),
            f"status.{PUBLIC_BETA_PHASE}",
            OVERALL_STATUSES,
        ),
        PRODUCTION_PHASE: require_enum(
            status.get(PRODUCTION_PHASE),
            f"status.{PRODUCTION_PHASE}",
            OVERALL_STATUSES,
        ),
    }


def validate_risk_acceptance(value: Any, path: str) -> None:
    """Validate risk-acceptance metadata for an accepted blocker."""
    risk = require_dict(value, path)
    require_exact_keys(risk, path, RISK_ACCEPTANCE_FIELDS)
    require_string(risk.get("accepted_by"), f"{path}.accepted_by")
    require_iso_date(risk.get("accepted_at"), f"{path}.accepted_at")
    require_iso_date(risk.get("expires_at"), f"{path}.expires_at")
    require_string(risk.get("reference"), f"{path}.reference")
    require_string(risk.get("notes"), f"{path}.notes")


def validate_requirement(
    value: Any, repo_root: Path, path: str
) -> tuple[str, str, str]:
    """Validate one requirement row and return its phase, id, and status."""
    item = require_dict(value, path)
    require_exact_keys(item, path, REQUIREMENT_FIELDS)
    requirement_id = require_string(item.get("id"), f"{path}.id")
    phase = require_string(item.get("phase"), f"{path}.phase")
    if phase not in REQUIRED_BY_PHASE:
        raise PublicBetaEvidenceError(f"{path}.phase must be public_beta or production_release")
    if requirement_id not in REQUIRED_BY_PHASE[phase]:
        raise PublicBetaEvidenceError(
            f"{path}.id is not a required {phase} requirement: {requirement_id}"
        )

    status = require_enum(item.get("status"), f"{path}.status", REQUIREMENT_STATUSES)
    require_string(item.get("owner"), f"{path}.owner")
    require_string(item.get("notes"), f"{path}.notes")

    evidence = require_list(item.get("evidence"), f"{path}.evidence")
    for index, ref in enumerate(evidence):
        validate_file_ref(ref, repo_root, f"{path}.evidence[{index}]")

    risk_acceptance = item.get("risk_acceptance")
    if status == "complete" and not evidence:
        raise PublicBetaEvidenceError(f"{path}.evidence must not be empty when status is complete")
    if status == "accepted_risk":
        validate_risk_acceptance(risk_acceptance, f"{path}.risk_acceptance")
    elif risk_acceptance is not None:
        raise PublicBetaEvidenceError(
            f"{path}.risk_acceptance must be null unless status is accepted_risk"
        )

    return phase, requirement_id, status


def validate_requirements(
    value: Any, repo_root: Path
) -> dict[str, dict[str, str]]:
    """Validate all required public-beta and production requirement rows."""
    requirements = require_list(value, "requirements")
    statuses: dict[str, dict[str, str]] = {
        PUBLIC_BETA_PHASE: {},
        PRODUCTION_PHASE: {},
    }

    for index, requirement in enumerate(requirements):
        phase, requirement_id, status = validate_requirement(
            requirement, repo_root, f"requirements[{index}]"
        )
        if requirement_id in statuses[phase]:
            raise PublicBetaEvidenceError(
                f"requirements contains duplicate {phase} requirement: {requirement_id}"
            )
        statuses[phase][requirement_id] = status

    for phase, expected_ids in REQUIRED_BY_PHASE.items():
        actual_ids = set(statuses[phase])
        missing = sorted(expected_ids - actual_ids)
        extra = sorted(actual_ids - expected_ids)
        if missing:
            raise PublicBetaEvidenceError(
                f"requirements missing {phase} requirement(s): {', '.join(missing)}"
            )
        if extra:
            raise PublicBetaEvidenceError(
                f"requirements has unexpected {phase} requirement(s): {', '.join(extra)}"
            )

    return statuses


def validate_retained_artifacts(value: Any, repo_root: Path) -> None:
    """Validate supplemental retained artifacts for the manifest itself."""
    artifacts = require_list(value, "retained_artifacts")
    if not artifacts:
        raise PublicBetaEvidenceError("retained_artifacts must not be empty")
    for index, artifact in enumerate(artifacts):
        validate_file_ref(
            artifact,
            repo_root,
            f"retained_artifacts[{index}]",
            expected_fields=RETAINED_ARTIFACT_FIELDS,
        )
        require_string(
            require_dict(artifact, f"retained_artifacts[{index}]").get("category"),
            f"retained_artifacts[{index}].category",
        )


def validate_redaction_policy(value: Any) -> None:
    """Validate the explicit no-secret redaction policy."""
    policy = require_dict(value, "redaction_policy")
    require_exact_keys(policy, "redaction_policy", REDACTION_POLICY_FIELDS)
    no_secrets = require_bool(policy.get("no_secrets"), "redaction_policy.no_secrets")
    if not no_secrets:
        raise PublicBetaEvidenceError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise PublicBetaEvidenceError("redaction_policy.redacted_fields must not be empty")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def validate_overall_status(
    overall_status: dict[str, str], requirement_statuses: dict[str, dict[str, str]]
) -> None:
    """Reject ready claims while blocking requirement rows remain."""
    for phase, status in overall_status.items():
        blocking = sorted(
            requirement_id
            for requirement_id, requirement_status in requirement_statuses[phase].items()
            if requirement_status in BLOCKING_STATUSES
        )
        if status == "ready" and blocking:
            raise PublicBetaEvidenceError(
                f"status.{phase} cannot be ready while blockers remain: {', '.join(blocking)}"
            )


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed evidence."""
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            key_lower = key_text.lower()
            if key_lower not in SAFE_SECRET_POLICY_KEYS and SECRET_KEY_RE.search(key_text):
                raise PublicBetaEvidenceError(f"secret-like key found at {path}.{key_text}")
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise PublicBetaEvidenceError(f"secret-like value found at {path}")


def validate_evidence_document(data: Any, repo_root: Path, label: str) -> None:
    """Validate an in-memory public-beta evidence document."""
    document = require_dict(data, label)
    require_exact_keys(document, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(document.get("schema_version"), "schema_version")
    if schema_version != EVIDENCE_SCHEMA:
        raise PublicBetaEvidenceError(f"schema_version must be {EVIDENCE_SCHEMA}")
    require_string(document.get("release_version"), "release_version")
    validate_source(document.get("source"))
    overall_status = validate_status(document.get("status"))
    requirement_statuses = validate_requirements(document.get("requirements"), repo_root)
    validate_retained_artifacts(document.get("retained_artifacts"), repo_root)
    validate_redaction_policy(document.get("redaction_policy"))
    require_string(document.get("operator_notes"), "operator_notes")
    validate_overall_status(overall_status, requirement_statuses)
    scan_for_secret_like_data(document)


def validate_evidence(path: Path, repo_root: Path) -> None:
    """Load and validate one public-beta evidence status file."""
    evidence_path = path if path.is_absolute() else repo_root / path
    data = load_json(evidence_path)
    validate_evidence_document(data, repo_root, str(evidence_path))


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--evidence", type=Path, default=DEFAULT_EVIDENCE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        validate_evidence(args.evidence, repo_root)
    except PublicBetaEvidenceError as exc:
        print(f"public beta evidence check failed: {exc}", file=sys.stderr)
        return 1
    print(f"public beta evidence check passed: {args.evidence}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
