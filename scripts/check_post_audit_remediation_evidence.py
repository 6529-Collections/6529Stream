#!/usr/bin/env python3
"""Validate retained post-audit remediation evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "post_audit_remediation"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/post-audit-remediation/"
        "post-audit-remediation-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Post-Audit Remediation Retained Artifact",
    "## Evidence Status",
    "## Audit And Release Scope",
    "## Finding Remediation Matrix",
    "## Retest And Risk Acceptance",
    "## Required Retained Artifacts",
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
    "Release commit",
    "Audit report reference",
    "Audit finding tracker",
    "Release version",
    "Finding IDs covered",
    "Critical/high remediation status",
    "Medium remediation status",
    "Low/informational disposition",
    "Fix PRs or commits",
    "Regression tests added",
    "Retest evidence",
    "Accepted-risk records",
    "Release notes mapping",
    "Open finding exceptions",
    "Finding-by-finding remediation tracker",
    "Retest transcript or reviewer report",
    "Accepted-risk signoff packet",
    "Updated release notes",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private auditor portal credentials removed",
    "Private RPC URLs removed",
    "Private keys removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Release commit",
    "Audit report reference",
    "Audit finding tracker",
    "Release version",
    "Finding IDs covered",
    "Critical/high remediation status",
    "Medium remediation status",
    "Low/informational disposition",
    "Fix PRs or commits",
    "Regression tests added",
    "Retest evidence",
    "Accepted-risk records",
    "Release notes mapping",
    "Open finding exceptions",
    "Finding-by-finding remediation tracker",
    "Retest transcript or reviewer report",
    "Accepted-risk signoff packet",
    "Updated release notes",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]

REQUIRED_COMMANDS = [
    "python scripts/test_post_audit_remediation_evidence.py",
    "python scripts/check_post_audit_remediation_evidence.py",
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
    r"api[_ -]?key|password|bearer[_ -]?token|auditor[_ -]?portal[_ -]?token|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)


class PostAuditRemediationEvidenceError(RuntimeError):
    """Raised when post-audit remediation evidence is invalid."""


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
        raise PostAuditRemediationEvidenceError(
            f"missing required file: {path}"
        ) from exc
    except UnicodeDecodeError as exc:
        raise PostAuditRemediationEvidenceError(
            f"{path} must be valid UTF-8"
        ) from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    """Reject secret-shaped key/value material."""
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise PostAuditRemediationEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    """Require canonical headings in order."""
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise PostAuditRemediationEvidenceError(
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
            raise PostAuditRemediationEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise PostAuditRemediationEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    """Require one field to match an expected value."""
    actual = fields[label]
    if actual != expected:
        raise PostAuditRemediationEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    """Return whether a value is still placeholder/template text."""
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or "<" in value


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    """Validate template, pending-review, and reviewed state semantics."""
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise PostAuditRemediationEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise PostAuditRemediationEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise PostAuditRemediationEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise PostAuditRemediationEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise PostAuditRemediationEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(
        path, fields, "Private auditor portal credentials removed", "yes"
    )
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")


def validate_commands(path: Path, text: str) -> None:
    """Require the artifact to carry the validation sequence."""
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise PostAuditRemediationEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
    """Validate one retained post-audit remediation artifact."""
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)

    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Readiness claim", "blocked")
    require_field_value(path, fields, "Environment", "audit")
    require_field_value(path, fields, "Chain ID", "not_applicable")
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Validate retained post-audit remediation evidence artifacts"
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
    except PostAuditRemediationEvidenceError as exc:
        print(f"post-audit remediation evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("post-audit remediation evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
