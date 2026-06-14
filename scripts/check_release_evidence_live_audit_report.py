#!/usr/bin/env python3
"""Validate retained release evidence live audit report bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import audit_release_evidence_issue_snapshots as auditor


REPORT_SCHEMA_VERSION = auditor.REPORT_SCHEMA_VERSION
REPO_FULL_NAME = auditor.REPO_FULL_NAME
DEFAULT_PROFILES = auditor.DEFAULT_PROFILES
DEFAULT_SCHEMA = Path(
    "release-artifacts/schema/release-evidence-live-audit-report.schema.json"
)
DEFAULT_REPORT_JSON = Path(
    "release-artifacts/evidence/release-evidence-live-audit-report-template.json"
)

TOP_LEVEL_FIELDS = frozenset(
    {
        "schema_version",
        "repo",
        "generated_at",
        "readiness_claim",
        "no_secret_notice",
        "readiness_warning",
        "snapshot_freshness",
        "profiles",
        "validation",
    }
)
SNAPSHOT_FRESHNESS_FIELDS = frozenset(
    {
        "status",
        "generated_from_live_export",
        "currentness_claim",
        "stale_snapshot_policy",
        "profile_generated_at",
    }
)
PROFILE_FIELDS = frozenset(
    {
        "profile",
        "snapshot_path",
        "snapshot_sha256",
        "export_command",
        "checker_command",
        "export_status",
        "checker_status",
    }
)
VALIDATION_FIELDS = frozenset({"status", "profile_count"})
SAFE_SECRET_KEYS = frozenset(
    {
        "no_secret_notice",
        "readiness_warning",
        "readiness_claim",
        "snapshot_sha256",
        "schema_version",
    }
)

SHA256_HEX_RE = re.compile(r"^[0-9a-f]{64}$")
SECRET_KEY_RE = re.compile(
    r"(^|[_\-\s])("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|unreleased[_\-\s]?drop[_\-\s]?payload"
    r")([_\-\s]|$)"
    r"|(^|[_\-\s])client[_\-\s]?secret([_\-\s]|$)"
    r"|(^|[_\-\s])secret$",
    re.IGNORECASE,
)
SECRET_VALUE_RE = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY-----"
    r"|\bgh[pousr]_[A-Za-z0-9_]{20,}"
    r"|\bxox[baprs]-[A-Za-z0-9-]{10,}"
    r"|\b("
    r"private[_\-\s]?key|mnemonic|seed[_\-\s]?phrase|rpc[_\-\s]?url|"
    r"api[_\-\s]?key|password|client[_\-\s]?secret"
    r")\s*[:=]",
    re.IGNORECASE,
)


class ReleaseEvidenceLiveAuditReportError(RuntimeError):
    """Raised when a retained live audit report is invalid."""


def load_json(path: Path) -> Any:
    """Load JSON with checker-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidenceLiveAuditReportError(
            f"missing required file: {path}"
        ) from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise ReleaseEvidenceLiveAuditReportError(f"unable to read {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidenceLiveAuditReportError(
            f"invalid JSON in {path}: {exc}"
        ) from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    if not isinstance(value, dict):
        raise ReleaseEvidenceLiveAuditReportError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Require a JSON array."""
    if not isinstance(value, list):
        raise ReleaseEvidenceLiveAuditReportError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Require a non-empty string."""
    if not isinstance(value, str) or value == "":
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} must be a non-empty string"
        )
    return value


def require_non_negative_int(value: Any, path: str) -> int:
    """Require a non-negative integer, excluding booleans."""
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} must be a non-negative integer"
        )
    return value


def require_boolean(value: Any, path: str) -> bool:
    """Require a JSON boolean."""
    if not isinstance(value, bool):
        raise ReleaseEvidenceLiveAuditReportError(f"{path} must be a boolean")
    return value


def require_exact_keys(value: dict[str, Any], path: str, expected: frozenset[str]) -> None:
    """Require exactly the expected object keys."""
    keys = set(value)
    missing = sorted(expected - keys)
    extra = sorted(keys - expected)
    if missing:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    if extra:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} has unexpected field(s): {', '.join(extra)}"
        )


def resolve_repo_file(repo_root: Path, relative_path: str, path: str) -> Path:
    """Resolve a repository-relative file path without allowing escapes."""
    if "\\" in relative_path:
        raise ReleaseEvidenceLiveAuditReportError(f"{path} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} must stay inside the repository"
        )
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} must stay inside the repository"
        ) from exc
    if not resolved.is_file():
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} references missing file: {relative_path}"
        )
    return resolved


def file_sha256_hex(path: Path) -> str:
    """Return a bare lowercase SHA-256 hex digest."""
    hasher = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def require_sha256_hex(value: Any, path: str) -> str:
    """Require a bare lowercase SHA-256 digest."""
    digest = require_string(value, path)
    if not SHA256_HEX_RE.fullmatch(digest):
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} must be a lowercase 64-character sha256 hex digest"
        )
    return digest


def scan_for_secret_like_data(value: Any, path: str = "report") -> None:
    """Reject secret-shaped keys and values in a retained report."""
    if isinstance(value, dict):
        for key, child in value.items():
            key_text = str(key)
            child_path = f"{path}.{key_text}"
            if key_text not in SAFE_SECRET_KEYS and SECRET_KEY_RE.search(key_text):
                raise ReleaseEvidenceLiveAuditReportError(
                    f"{child_path} contains a secret-like key"
                )
            scan_for_secret_like_data(child, child_path)
        return
    if isinstance(value, list):
        for index, child in enumerate(value):
            scan_for_secret_like_data(child, f"{path}[{index}]")
        return
    if isinstance(value, str) and SECRET_VALUE_RE.search(value):
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path} contains a secret-like value"
        )


def validate_schema_document(schema: Any) -> None:
    """Validate the committed JSON schema is for this report type."""
    schema_obj = require_dict(schema, "schema")
    require_string(schema_obj.get("$schema"), "schema.$schema")
    properties = require_dict(schema_obj.get("properties"), "schema.properties")

    schema_version = require_dict(
        properties.get("schema_version"), "schema.properties.schema_version"
    )
    if schema_version.get("const") != REPORT_SCHEMA_VERSION:
        raise ReleaseEvidenceLiveAuditReportError(
            f"schema.properties.schema_version.const must be {REPORT_SCHEMA_VERSION}"
        )

    repo = require_dict(properties.get("repo"), "schema.properties.repo")
    if repo.get("const") != REPO_FULL_NAME:
        raise ReleaseEvidenceLiveAuditReportError(
            f"schema.properties.repo.const must be {REPO_FULL_NAME}"
        )

    profiles = require_dict(properties.get("profiles"), "schema.properties.profiles")
    if profiles.get("minItems") != len(DEFAULT_PROFILES):
        raise ReleaseEvidenceLiveAuditReportError(
            "schema.properties.profiles.minItems must cover all live audit profiles"
        )
    if profiles.get("maxItems") != len(DEFAULT_PROFILES):
        raise ReleaseEvidenceLiveAuditReportError(
            "schema.properties.profiles.maxItems must cover exactly all live audit profiles"
        )

    validation = require_dict(
        properties.get("validation"), "schema.properties.validation"
    )
    validation_properties = require_dict(
        validation.get("properties"), "schema.properties.validation.properties"
    )
    profile_count = require_dict(
        validation_properties.get("profile_count"),
        "schema.properties.validation.properties.profile_count",
    )
    if profile_count.get("const") != len(DEFAULT_PROFILES):
        raise ReleaseEvidenceLiveAuditReportError(
            "schema.properties.validation.properties.profile_count.const must match profile coverage"
        )

    freshness = require_dict(
        properties.get("snapshot_freshness"),
        "schema.properties.snapshot_freshness",
    )
    freshness_properties = require_dict(
        freshness.get("properties"),
        "schema.properties.snapshot_freshness.properties",
    )
    generated_from_live_export = require_dict(
        freshness_properties.get("generated_from_live_export"),
        (
            "schema.properties.snapshot_freshness.properties."
            "generated_from_live_export"
        ),
    )
    if generated_from_live_export.get("type") != "boolean":
        raise ReleaseEvidenceLiveAuditReportError(
            "schema.properties.snapshot_freshness.properties.generated_from_live_export.type must be boolean"
        )
    profile_generated_at = require_dict(
        freshness_properties.get("profile_generated_at"),
        "schema.properties.snapshot_freshness.properties.profile_generated_at",
    )
    if profile_generated_at.get("required") != list(DEFAULT_PROFILES):
        raise ReleaseEvidenceLiveAuditReportError(
            "schema.properties.snapshot_freshness.properties.profile_generated_at.required must cover all live audit profiles"
        )


def expected_export_fragments(profile: str, snapshot_path: str) -> list[str]:
    """Return command fragments expected in the exporter command."""
    return [
        "export_release_evidence_issue_snapshot.py",
        f"--profile {profile}",
        f"--repo {REPO_FULL_NAME}",
        f"--output {snapshot_path}",
    ]


def expected_checker_fragments(profile: str, snapshot_path: str) -> list[str]:
    """Return command fragments expected in the checker command."""
    checker = auditor.PROFILE_CONFIG[profile]["checker"]
    return [checker, f"--live-json {snapshot_path}"]


def require_command_fragments(command: str, fragments: list[str], path: str) -> None:
    """Require command provenance to contain all expected fragments."""
    for fragment in fragments:
        if fragment not in command:
            raise ReleaseEvidenceLiveAuditReportError(
                f"{path} must include `{fragment}`"
            )


def validate_profile_result(
    raw_profile: Any,
    index: int,
    repo_root: Path,
) -> str:
    """Validate one profile row and return the profile name."""
    path = f"profiles[{index}]"
    profile = require_dict(raw_profile, path)
    require_exact_keys(profile, path, PROFILE_FIELDS)

    profile_name = require_string(profile.get("profile"), f"{path}.profile")
    if profile_name not in DEFAULT_PROFILES:
        expected = ", ".join(DEFAULT_PROFILES)
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path}.profile must be one of: {expected}"
        )

    snapshot_path = require_string(profile.get("snapshot_path"), f"{path}.snapshot_path")
    snapshot_file = resolve_repo_file(repo_root, snapshot_path, f"{path}.snapshot_path")
    expected_digest = require_sha256_hex(
        profile.get("snapshot_sha256"), f"{path}.snapshot_sha256"
    )
    actual_digest = file_sha256_hex(snapshot_file)
    if actual_digest != expected_digest:
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path}.snapshot_sha256 mismatch for {snapshot_path}"
        )

    export_command = require_string(
        profile.get("export_command"), f"{path}.export_command"
    )
    checker_command = require_string(
        profile.get("checker_command"), f"{path}.checker_command"
    )
    require_command_fragments(
        export_command,
        expected_export_fragments(profile_name, snapshot_path),
        f"{path}.export_command",
    )
    require_command_fragments(
        checker_command,
        expected_checker_fragments(profile_name, snapshot_path),
        f"{path}.checker_command",
    )

    if profile.get("export_status") != "passed":
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path}.export_status must be passed"
        )
    if profile.get("checker_status") != "passed":
        raise ReleaseEvidenceLiveAuditReportError(
            f"{path}.checker_status must be passed"
        )
    return profile_name


def validate_snapshot_freshness(
    raw_freshness: Any,
    generated_at: str,
    profile_names: list[str],
) -> None:
    """Validate explicit retained-snapshot freshness/currentness claims."""
    freshness = require_dict(raw_freshness, "report.snapshot_freshness")
    require_exact_keys(
        freshness,
        "report.snapshot_freshness",
        SNAPSHOT_FRESHNESS_FIELDS,
    )
    status = require_string(
        freshness.get("status"),
        "report.snapshot_freshness.status",
    )
    generated_from_live_export = require_boolean(
        freshness.get("generated_from_live_export"),
        "report.snapshot_freshness.generated_from_live_export",
    )
    currentness_claim = require_string(
        freshness.get("currentness_claim"),
        "report.snapshot_freshness.currentness_claim",
    )
    stale_snapshot_policy = require_string(
        freshness.get("stale_snapshot_policy"),
        "report.snapshot_freshness.stale_snapshot_policy",
    )
    if stale_snapshot_policy != auditor.STALE_SNAPSHOT_POLICY:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.snapshot_freshness.stale_snapshot_policy must match the generator policy"
        )

    profile_generated_at = require_dict(
        freshness.get("profile_generated_at"),
        "report.snapshot_freshness.profile_generated_at",
    )
    require_exact_keys(
        profile_generated_at,
        "report.snapshot_freshness.profile_generated_at",
        frozenset(profile_names),
    )
    for profile_name in profile_names:
        require_string(
            profile_generated_at.get(profile_name),
            f"report.snapshot_freshness.profile_generated_at.{profile_name}",
        )

    if generated_from_live_export:
        if status != auditor.LIVE_EXPORT_FRESHNESS_STATUS:
            raise ReleaseEvidenceLiveAuditReportError(
                "report.snapshot_freshness.status must mark live export generation"
            )
        if currentness_claim != auditor.LIVE_EXPORT_CURRENTNESS_CLAIM:
            raise ReleaseEvidenceLiveAuditReportError(
                "report.snapshot_freshness.currentness_claim must be current at generation only"
            )
        for profile_name in profile_names:
            if profile_generated_at[profile_name] != generated_at:
                raise ReleaseEvidenceLiveAuditReportError(
                    (
                        "report.snapshot_freshness.profile_generated_at."
                        f"{profile_name} must match report.generated_at for live exports"
                    )
                )
        return

    if status != auditor.RETAINED_HISTORICAL_FRESHNESS_STATUS:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.snapshot_freshness.status must mark retained historical snapshots"
        )
    if currentness_claim != auditor.RETAINED_CURRENTNESS_CLAIM:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.snapshot_freshness.currentness_claim must be not_current for retained historical snapshots"
        )


def validate_report_document(report: Any, repo_root: Path) -> None:
    """Validate a retained no-secret live audit report."""
    report_obj = require_dict(report, "report")
    require_exact_keys(report_obj, "report", TOP_LEVEL_FIELDS)
    scan_for_secret_like_data(report_obj)

    if report_obj.get("schema_version") != REPORT_SCHEMA_VERSION:
        raise ReleaseEvidenceLiveAuditReportError(
            f"report.schema_version must be {REPORT_SCHEMA_VERSION}"
        )
    if report_obj.get("repo") != REPO_FULL_NAME:
        raise ReleaseEvidenceLiveAuditReportError(
            f"report.repo must be {REPO_FULL_NAME}"
        )
    generated_at = require_string(report_obj.get("generated_at"), "report.generated_at")
    if report_obj.get("readiness_claim") != "blocked":
        raise ReleaseEvidenceLiveAuditReportError(
            "report.readiness_claim must be blocked"
        )
    if report_obj.get("no_secret_notice") != auditor.NO_SECRET_NOTICE:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.no_secret_notice must match the generator notice"
        )
    if report_obj.get("readiness_warning") != auditor.READINESS_WARNING:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.readiness_warning must match the blocked-readiness warning"
        )

    profile_names: list[str] = []
    for index, raw_profile in enumerate(
        require_list(report_obj.get("profiles"), "report.profiles")
    ):
        profile_name = validate_profile_result(raw_profile, index, repo_root)
        if profile_name in profile_names:
            raise ReleaseEvidenceLiveAuditReportError(
                f"duplicate profile row: {profile_name}"
            )
        profile_names.append(profile_name)

    expected_profiles = list(DEFAULT_PROFILES)
    if profile_names != expected_profiles:
        raise ReleaseEvidenceLiveAuditReportError(
            "report.profiles must cover labels, bodies, and closure in order"
        )

    validate_snapshot_freshness(
        report_obj.get("snapshot_freshness"),
        generated_at,
        profile_names,
    )

    validation = require_dict(report_obj.get("validation"), "report.validation")
    require_exact_keys(validation, "report.validation", VALIDATION_FIELDS)
    if validation.get("status") != "passed":
        raise ReleaseEvidenceLiveAuditReportError(
            "report.validation.status must be passed"
        )
    profile_count = require_non_negative_int(
        validation.get("profile_count"), "report.validation.profile_count"
    )
    if profile_count != len(profile_names):
        raise ReleaseEvidenceLiveAuditReportError(
            "report.validation.profile_count must match report.profiles"
        )


def resolve_cli_path(repo_root: Path, path: Path) -> Path:
    """Resolve a CLI path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def build_parser() -> argparse.ArgumentParser:
    """Build the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--schema", type=Path, default=DEFAULT_SCHEMA)
    parser.add_argument("--report-json", type=Path, default=DEFAULT_REPORT_JSON)
    return parser


def main(argv: list[str] | None = None) -> int:
    """Validate a retained live audit report bundle."""
    parser = build_parser()
    args = parser.parse_args(argv)
    repo_root = args.repo_root.resolve()
    schema_path = resolve_cli_path(repo_root, args.schema)
    report_path = resolve_cli_path(repo_root, args.report_json)

    try:
        validate_schema_document(load_json(schema_path))
        validate_report_document(load_json(report_path), repo_root)
    except ReleaseEvidenceLiveAuditReportError as exc:
        print(f"release evidence live audit report check failed: {exc}", file=sys.stderr)
        return 1

    print(f"release evidence live audit report is valid: {args.report_json.as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
