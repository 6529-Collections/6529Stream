#!/usr/bin/env python3
"""Validate retained non-local release evidence metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import check_public_beta_evidence as public_beta_checker
from release_evidence_paths import resolve_repo_relative_path


EVIDENCE_SCHEMA = "6529stream.non-local-release-evidence.v1"
DEFAULT_EVIDENCE = [
    Path("release-artifacts/evidence/non-local-release-evidence-template.json")
]
PUBLIC_BETA_TEMPLATE_DIR = Path("release-artifacts/evidence/public-beta-templates")
PUBLIC_BETA_TEMPLATE_REQUIREMENTS = frozenset(public_beta_checker.PUBLIC_BETA_REQUIREMENTS)
PRODUCTION_RELEASE_TEMPLATE_DIR = Path(
    "release-artifacts/evidence/production-release-templates"
)
PRODUCTION_RELEASE_TEMPLATE_REQUIREMENTS = frozenset(
    public_beta_checker.PRODUCTION_REQUIREMENTS
)

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "evidence_id",
        "record_type",
        "review_status",
        "environment",
        "chain_id",
        "block_or_reference",
        "command_or_source_system",
        "retained_path",
        "sha256",
        "redaction_statement",
        "owner",
        "reviewer",
        "public_beta_requirement_id",
        "source",
        "redaction_policy",
        "template_notice",
        "operator_notes",
    }
)
SOURCE_FIELDS = frozenset({"repository", "git_commit", "source_dirty", "ci_run"})
REDACTION_POLICY_FIELDS = frozenset({"no_secrets", "redacted_fields"})
RECORD_TYPES = frozenset({"template", "evidence"})
REVIEW_STATUSES = frozenset({"template", "pending_review", "reviewed"})
ENVIRONMENTS = frozenset({"fork", "testnet", "live", "audit", "release_signing"})
CHAINLESS_ENVIRONMENTS = frozenset({"audit", "release_signing"})
REVIEWED_STATUSES = frozenset({"reviewed"})

GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SHA256_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
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


class NonLocalReleaseEvidenceError(RuntimeError):
    """Raised when non-local release evidence metadata is invalid."""


def load_json(path: Path) -> Any:
    """Load a JSON file with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise NonLocalReleaseEvidenceError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise NonLocalReleaseEvidenceError(f"invalid JSON in {path}: {exc}") from exc


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
        raise NonLocalReleaseEvidenceError(f"{path} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise NonLocalReleaseEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise NonLocalReleaseEvidenceError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise NonLocalReleaseEvidenceError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise NonLocalReleaseEvidenceError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    if not isinstance(value, bool):
        raise NonLocalReleaseEvidenceError(f"{path} must be a boolean")
    return value


def require_int(value: Any, path: str) -> int:
    """Require an integer that is not a boolean."""
    if not isinstance(value, int) or isinstance(value, bool):
        raise NonLocalReleaseEvidenceError(f"{path} must be an integer")
    return value


def require_enum(value: Any, path: str, choices: frozenset[str]) -> str:
    """Require a string from an enum set."""
    text = require_string(value, path)
    if text not in choices:
        expected = ", ".join(sorted(choices))
        raise NonLocalReleaseEvidenceError(f"{path} must be one of: {expected}")
    return text


def require_sha256(value: Any, path: str) -> str:
    """Require a sha256-prefixed digest."""
    digest = require_string(value, path)
    if not SHA256_RE.fullmatch(digest):
        raise NonLocalReleaseEvidenceError(f"{path} must be a sha256: hash")
    return digest


def require_git_commit(value: Any, path: str) -> str:
    """Require a 40-character git commit hash."""
    commit = require_string(value, path)
    if not GIT_COMMIT_RE.fullmatch(commit):
        raise NonLocalReleaseEvidenceError(
            f"{path} must be a 40-character git commit hash"
        )
    return commit


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file path without allowing escapes."""
    return resolve_repo_relative_path(
        repo_root,
        relative_path,
        error_type=NonLocalReleaseEvidenceError,
        forward_slash_message=f"{path} must use forward slashes",
        absolute_message=f"{path} must stay inside the repository",
        traversal_message=f"{path} must stay inside the repository",
        symlink_message=f"{path} must not use symlinked retained files",
        escape_message=f"{path} must stay inside the repository",
        require_file=True,
        missing_message=f"{path} references missing file: {relative_path}",
    )


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
        raise NonLocalReleaseEvidenceError("redaction_policy.no_secrets must be true")
    fields = require_list(policy.get("redacted_fields"), "redaction_policy.redacted_fields")
    if not fields:
        raise NonLocalReleaseEvidenceError("redaction_policy.redacted_fields must not be empty")
    for index, field in enumerate(fields):
        require_string(field, f"redaction_policy.redacted_fields[{index}]")


def valid_requirement_ids() -> frozenset[str]:
    """Return requirement IDs accepted by the public-beta evidence manifest."""
    return frozenset(
        set(public_beta_checker.PUBLIC_BETA_REQUIREMENTS)
        | set(public_beta_checker.PRODUCTION_REQUIREMENTS)
    )


def template_paths(repo_root: Path, template_dir_path: Path, label: str) -> list[Path]:
    """Return committed template metadata files for one release phase."""
    template_dir = repo_root / template_dir_path
    if not template_dir.is_dir():
        raise NonLocalReleaseEvidenceError(
            f"missing {label} template directory: {template_dir_path}"
        )
    return sorted(path for path in template_dir.rglob("*.json") if path.is_file())


def public_beta_template_paths(repo_root: Path) -> list[Path]:
    """Return committed public-beta template metadata files."""
    return template_paths(repo_root, PUBLIC_BETA_TEMPLATE_DIR, "public-beta")


def production_release_template_paths(repo_root: Path) -> list[Path]:
    """Return committed production-release template metadata files."""
    return template_paths(
        repo_root, PRODUCTION_RELEASE_TEMPLATE_DIR, "production-release"
    )


def default_evidence_paths(repo_root: Path) -> list[Path]:
    """Return the default non-local evidence files checked by the CLI."""
    return (
        [repo_root / path for path in DEFAULT_EVIDENCE]
        + public_beta_template_paths(repo_root)
        + production_release_template_paths(repo_root)
    )


def validate_template_set(
    repo_root: Path,
    paths: list[Path],
    expected_requirements: frozenset[str],
    label: str,
) -> None:
    """Require one template metadata file for each release phase requirement."""
    by_requirement: dict[str, Path] = {}
    for path in paths:
        evidence = require_dict(load_json(path), str(path))
        try:
            validate_evidence_document(evidence, repo_root, str(path))
        except NonLocalReleaseEvidenceError as exc:
            raise NonLocalReleaseEvidenceError(
                f"invalid {label} template {path}: {exc}"
            ) from exc

        record_type = require_string(evidence.get("record_type"), f"{path}.record_type")
        if record_type != "template":
            raise NonLocalReleaseEvidenceError(
                f"{path} must be a template record"
            )
        review_status = require_string(
            evidence.get("review_status"), f"{path}.review_status"
        )
        if review_status != "template":
            raise NonLocalReleaseEvidenceError(
                f"{path} must use template review_status"
            )
        requirement_id = require_string(
            evidence.get("public_beta_requirement_id"),
            f"{path}.public_beta_requirement_id",
        )
        if requirement_id not in expected_requirements:
            raise NonLocalReleaseEvidenceError(
                f"{path} maps to non-{label} requirement: {requirement_id}"
            )
        if requirement_id in by_requirement:
            raise NonLocalReleaseEvidenceError(
                f"duplicate {label} template for "
                f"{requirement_id}: {by_requirement[requirement_id]} and {path}"
            )
        by_requirement[requirement_id] = path

    missing = sorted(expected_requirements - set(by_requirement))
    if missing:
        raise NonLocalReleaseEvidenceError(
            f"missing {label} template(s): " + ", ".join(missing)
        )


def validate_public_beta_template_set(repo_root: Path) -> None:
    """Require one template metadata file for each public-beta requirement."""
    validate_template_set(
        repo_root,
        public_beta_template_paths(repo_root),
        PUBLIC_BETA_TEMPLATE_REQUIREMENTS,
        "public-beta",
    )


def validate_production_release_template_set(repo_root: Path) -> None:
    """Require one template metadata file for each production-release requirement."""
    validate_template_set(
        repo_root,
        production_release_template_paths(repo_root),
        PRODUCTION_RELEASE_TEMPLATE_REQUIREMENTS,
        "production-release",
    )


def validate_chain_id(environment: str, value: Any) -> None:
    """Validate chain ID according to environment."""
    if environment in CHAINLESS_ENVIRONMENTS:
        if value == "not_applicable":
            return
        if not isinstance(value, int) or isinstance(value, bool):
            raise NonLocalReleaseEvidenceError(
                "chain_id must be a number or not_applicable"
            )
        if value < 1:
            raise NonLocalReleaseEvidenceError("chain_id must be greater than zero")
        return
    chain_id = require_int(value, "chain_id")
    if chain_id < 1:
        raise NonLocalReleaseEvidenceError("chain_id must be greater than zero")


def validate_template_notice(record_type: str, value: str) -> None:
    """Require templates to say they are not completion evidence."""
    if record_type != "template":
        return
    lowered = value.lower()
    if "template" not in lowered or "not completion evidence" not in lowered:
        raise NonLocalReleaseEvidenceError(
            "template_notice must say template and not completion evidence"
        )


def validate_reviewer(review_status: str, reviewer: str) -> None:
    """Require a real reviewer once evidence is reviewed."""
    if review_status in REVIEWED_STATUSES and reviewer.strip().upper() == "TBD":
        raise NonLocalReleaseEvidenceError("reviewer must be set before reviewed")


def validate_retained_artifact_hash(
    evidence: dict[str, Any], repo_root: Path
) -> None:
    """Validate the retained_path and sha256 pair."""
    retained_path = require_string(evidence.get("retained_path"), "retained_path")
    expected_hash = require_sha256(evidence.get("sha256"), "sha256")
    resolved = resolve_repo_file(repo_root, retained_path, "retained_path")
    actual_hash = file_sha256(resolved)
    if actual_hash != expected_hash:
        raise NonLocalReleaseEvidenceError(
            f"sha256 mismatch for {retained_path}: expected {expected_hash}, got {actual_hash}"
        )


def scan_for_secret_like_data(value: Any, path: str = "$") -> None:
    """Reject secret-shaped keys and values in committed evidence."""
    if isinstance(value, dict):
        for key, item in value.items():
            key_text = str(key)
            key_lower = key_text.lower()
            if key_lower not in SAFE_SECRET_POLICY_KEYS and SECRET_KEY_RE.search(key_text):
                raise NonLocalReleaseEvidenceError(f"secret-like key found at {path}.{key_text}")
            scan_for_secret_like_data(item, f"{path}.{key_text}")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            scan_for_secret_like_data(item, f"{path}[{index}]")
    elif isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise NonLocalReleaseEvidenceError(f"secret-like value found at {path}")


def validate_evidence_document(data: Any, repo_root: Path, label: str) -> None:
    """Validate an in-memory non-local release evidence metadata document."""
    evidence = require_dict(data, label)
    require_exact_keys(evidence, label, TOP_LEVEL_FIELDS)
    schema_version = require_string(evidence.get("schema_version"), "schema_version")
    if schema_version != EVIDENCE_SCHEMA:
        raise NonLocalReleaseEvidenceError(f"schema_version must be {EVIDENCE_SCHEMA}")

    record_type = require_enum(evidence.get("record_type"), "record_type", RECORD_TYPES)
    review_status = require_enum(
        evidence.get("review_status"), "review_status", REVIEW_STATUSES
    )
    if record_type == "template" and review_status != "template":
        raise NonLocalReleaseEvidenceError("template records must use template review_status")
    if record_type == "evidence" and review_status == "template":
        raise NonLocalReleaseEvidenceError("evidence records cannot use template review_status")

    environment = require_enum(evidence.get("environment"), "environment", ENVIRONMENTS)
    validate_chain_id(environment, evidence.get("chain_id"))
    require_string(evidence.get("evidence_id"), "evidence_id")
    require_string(evidence.get("block_or_reference"), "block_or_reference")
    require_string(evidence.get("command_or_source_system"), "command_or_source_system")
    require_string(evidence.get("redaction_statement"), "redaction_statement")
    require_string(evidence.get("owner"), "owner")
    reviewer = require_string(evidence.get("reviewer"), "reviewer")
    validate_reviewer(review_status, reviewer)

    requirement_id = require_string(
        evidence.get("public_beta_requirement_id"), "public_beta_requirement_id"
    )
    if requirement_id not in valid_requirement_ids():
        raise NonLocalReleaseEvidenceError(
            f"public_beta_requirement_id is not recognized: {requirement_id}"
        )

    validate_source(evidence.get("source"))
    validate_redaction_policy(evidence.get("redaction_policy"))
    template_notice = require_string(evidence.get("template_notice"), "template_notice")
    validate_template_notice(record_type, template_notice)
    require_string(evidence.get("operator_notes"), "operator_notes")
    validate_retained_artifact_hash(evidence, repo_root)
    scan_for_secret_like_data(evidence)


def validate_evidence(path: Path, repo_root: Path) -> None:
    """Validate a non-local release evidence metadata file."""
    validate_evidence_document(load_json(path), repo_root, str(path))


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(
        description="Validate non-local release evidence metadata"
    )
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        help=(
            "Evidence metadata JSON files to validate. Defaults to the generic "
            "non-local template plus every public-beta and production-release "
            "template."
        ),
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the non-local release evidence checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        explicit_paths = bool(args.evidence)
        evidence_paths = args.evidence if explicit_paths else default_evidence_paths(repo_root)
        if not evidence_paths:
            raise NonLocalReleaseEvidenceError("no evidence files configured")
        for evidence_path in evidence_paths:
            path = evidence_path
            if not path.is_absolute():
                path = repo_root / path
            validate_evidence(path, repo_root)
        if not explicit_paths:
            validate_public_beta_template_set(repo_root)
            validate_production_release_template_set(repo_root)
    except NonLocalReleaseEvidenceError as exc:
        print(f"non-local release evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("non-local release evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
