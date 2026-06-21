#!/usr/bin/env python3
"""Validate retained production broadcast evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from release_evidence_paths import resolve_repo_relative_path as resolve_shared_repo_relative_path


REQUIREMENT_ID = "production_broadcast_retention"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/production-broadcast-retention/"
        "production-broadcast-retention-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Production Broadcast Retention Retained Artifact",
    "## Evidence Status",
    "## Source And Production Reference",
    "## Required Retained Artifacts",
    "## Broadcast Results",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

REQUIRED_FIELDS = {
    "Requirement ID",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Production block or reference",
    "Deployment transaction references",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Derived broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
    "Release manifest/checksum digests",
    "Broadcast completed",
    "Manifest input generated",
    "Deployment manifest generated",
    "Address book generated",
    "Transaction references retained",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Git commit",
    "CI run or operator transcript",
    "Production block or reference",
    "Deployment transaction references",
    "Command",
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Derived broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
REVIEWED_YES_FIELDS = [
    "Broadcast completed",
    "Manifest input generated",
    "Deployment manifest generated",
    "Address book generated",
    "Transaction references retained",
]
RETAINED_FILE_FIELDS = [
    "Sanitized command transcript",
    "Sanitized Foundry broadcast",
    "Derived broadcast manifest input",
    "Generated live deployment manifest",
    "Generated live address book",
]
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")

REQUIRED_COMMANDS = [
    "python scripts/test_production_broadcast_retention.py",
    "python scripts/check_production_broadcast_retention.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CLI_SECRET_RE = re.compile(
    r"("
    r"--(?:private-key|mnemonic|seed(?:-phrase)?)\b(?:\s+|=)\S+|"
    r"--rpc-url\b(?:\s+|=)(?!<redacted>|redacted\b)\S+|"
    r"\bAuthorization\s*:\s*Bearer\s+\S+|"
    r"\bBearer\s+[A-Za-z0-9._~+/=-]{12,}|"
    r"https?://[^\s`]*(?:alchemy|infura|quicknode|api[_-]?key|apikey|token|secret)[^\s`]*"
    r")",
    re.IGNORECASE,
)


class ProductionBroadcastRetentionError(RuntimeError):
    """Raised when production broadcast retention evidence is invalid."""


def normalize_value(value: str) -> str:
    """Normalize a Markdown field value."""
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    """Read UTF-8 text with checker-specific errors."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise ProductionBroadcastRetentionError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise ProductionBroadcastRetentionError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value, CLI, and provider URL material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise ProductionBroadcastRetentionError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CLI_SECRET_RE.search(text)
    if match:
        raise ProductionBroadcastRetentionError(
            f"{path} contains secret-like CLI or URL text: {match.group(0)}"
        )


def repo_root_for(path: Path) -> Path:
    """Return the root used for repo-relative retained artifact paths."""
    cwd = Path.cwd().resolve()
    resolved = path.resolve()
    try:
        resolved.relative_to(cwd)
    except ValueError:
        return resolved.parent
    return cwd


def resolve_repo_relative_path(root: Path, value: str) -> Path:
    """Resolve a retained artifact path while rejecting escapes."""
    return resolve_shared_repo_relative_path(
        root,
        value,
        error_type=ProductionBroadcastRetentionError,
        forward_slash_message=f"retained artifact path must use forward slashes: {value}",
        absolute_message=f"retained artifact path must be repo-relative: {value}",
        traversal_message=f"retained artifact path must be repo-relative: {value}",
        symlink_message=f"retained artifact path must not use symlinked retained files: {value}",
        escape_message=f"retained artifact path escapes repository: {value}",
    )


def validate_referenced_artifacts(path: Path, fields: dict[str, str]) -> None:
    """Require reviewed retained artifact paths to exist and be no-secret."""
    root = repo_root_for(path)
    for label in RETAINED_FILE_FIELDS:
        target = resolve_repo_relative_path(root, fields[label])
        if not target.is_file():
            raise ProductionBroadcastRetentionError(
                f"{path} field {label!r} points to missing retained file: {fields[label]}"
            )
        validate_no_secret_values(target, read_text(target))


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise ProductionBroadcastRetentionError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    """Extract Markdown bullet fields."""
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise ProductionBroadcastRetentionError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise ProductionBroadcastRetentionError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise ProductionBroadcastRetentionError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.search(value)
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise ProductionBroadcastRetentionError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise ProductionBroadcastRetentionError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise ProductionBroadcastRetentionError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise ProductionBroadcastRetentionError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise ProductionBroadcastRetentionError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "API keys removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
        for label in REVIEWED_YES_FIELDS:
            require_field_value(path, fields, label, "yes")
        validate_referenced_artifacts(path, fields)
    elif review_status == "pending_review":
        validate_referenced_artifacts(path, fields)


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise ProductionBroadcastRetentionError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
    """Validate one retained production broadcast artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "live")
    require_field_value(path, fields, "Chain ID", "1")
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained production broadcast evidence artifacts"
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_artifact(path)
    except ProductionBroadcastRetentionError as exc:
        print(f"production broadcast retention check failed: {exc}", file=sys.stderr)
        return 1
    print("production broadcast retention evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
