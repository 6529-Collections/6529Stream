#!/usr/bin/env python3
"""Validate retained live ceremony evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "live_ceremony_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/live-ceremony/"
        "live-ceremony-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Live Ceremony Retained Artifact",
    "## Evidence Status",
    "## Live Deployment Context",
    "## Participants And Governance",
    "## Ceremony Transactions",
    "## Dry Runs And Monitoring",
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
    "Deployment version",
    "Live block or reference",
    "Deployer",
    "Admin Safe or multisig",
    "Pause guardian",
    "Emergency recipient",
    "Drop signer",
    "Signer manager",
    "Ownership transfer transaction",
    "Role grant and revoke transactions",
    "Signer setup transactions",
    "Metadata and freeze ceremony",
    "Auction ceremony",
    "Emergency controls ceremony",
    "Dry-run mint evidence",
    "Dry-run auction evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Safe or multisig export",
    "Explorer transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Unreleased drop payloads removed",
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Release commit",
    "Deployment version",
    "Live block or reference",
    "Deployer",
    "Admin Safe or multisig",
    "Pause guardian",
    "Emergency recipient",
    "Drop signer",
    "Signer manager",
    "Ownership transfer transaction",
    "Role grant and revoke transactions",
    "Signer setup transactions",
    "Metadata and freeze ceremony",
    "Auction ceremony",
    "Emergency controls ceremony",
    "Dry-run mint evidence",
    "Dry-run auction evidence",
    "Monitoring handoff",
    "Live deployment manifest",
    "Live address book",
    "Safe or multisig export",
    "Explorer transaction bundle",
    "Post-state views",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]

REQUIRED_COMMANDS = [
    "python scripts/test_live_ceremony_evidence.py",
    "python scripts/check_live_ceremony_evidence.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|signer[_ -]?service[_ -]?secret|"
    r"unreleased[_ -]?drop[_ -]?payload"
    r")\s*[:=]",
    re.IGNORECASE,
)
CREDENTIAL_URL_RE = re.compile(r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+", re.IGNORECASE)


class LiveCeremonyEvidenceError(RuntimeError):
    """Raised when live ceremony evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise LiveCeremonyEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise LiveCeremonyEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise LiveCeremonyEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CREDENTIAL_URL_RE.search(text)
    if match:
        raise LiveCeremonyEvidenceError(
            f"{path} contains credentialed URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise LiveCeremonyEvidenceError(
                f"{path} is missing required heading: {heading}"
            ) from exc
        cursor = index + 1


def field_map(path: Path, text: str) -> dict[str, str]:
    fields: dict[str, str] = {}
    for line in text.splitlines():
        match = FIELD_RE.match(line.strip())
        if not match:
            continue
        label = match.group("label").strip()
        value = normalize_value(match.group("value"))
        if label in fields:
            raise LiveCeremonyEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise LiveCeremonyEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    actual = fields[label]
    if actual != expected:
        raise LiveCeremonyEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def require_address(path: Path, fields: dict[str, str], label: str) -> None:
    if not ADDRESS_RE.fullmatch(fields[label]):
        raise LiveCeremonyEvidenceError(f"{path} field {label!r} must be an address")


def is_placeholder(value: str) -> bool:
    lowered = value.lower()
    return lowered in {"tbd", "template", "template-only"} or bool(
        ANGLE_PLACEHOLDER_RE.fullmatch(value)
    )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise LiveCeremonyEvidenceError(
            f"{path} field 'Review status' must be one of: {expected}"
        )

    review_decision = fields["Review decision"]
    if review_decision not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise LiveCeremonyEvidenceError(
            f"{path} field 'Review decision' must be one of: {expected}"
        )

    if review_status == "template":
        if "Template only. This file is not completion evidence." not in text:
            raise LiveCeremonyEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        return

    if "Template only. This file is not completion evidence." in text:
        raise LiveCeremonyEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    if review_decision == "template":
        raise LiveCeremonyEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )

    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise LiveCeremonyEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )

    for label in (
        "Deployer",
        "Admin Safe or multisig",
        "Pause guardian",
        "Emergency recipient",
        "Drop signer",
        "Signer manager",
    ):
        require_address(path, fields, label)

    require_field_value(path, fields, "No secrets retained", "yes")
    require_field_value(path, fields, "Private RPC URLs removed", "yes")
    require_field_value(path, fields, "Private keys removed", "yes")
    require_field_value(path, fields, "Signer-service secrets removed", "yes")
    require_field_value(path, fields, "Unreleased drop payloads removed", "yes")

    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise LiveCeremonyEvidenceError(
                f"{path} is missing validation command: {command}"
            )


def validate_artifact(path: Path) -> None:
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
    parser = argparse.ArgumentParser(
        description="Validate retained live ceremony evidence artifacts"
    )
    parser.add_argument(
        "--evidence",
        type=Path,
        action="append",
        help="Evidence Markdown path to validate; may be repeated.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_artifact(path)
    except LiveCeremonyEvidenceError as exc:
        print(f"live ceremony evidence check failed: {exc}", file=sys.stderr)
        return 1
    print("live ceremony evidence is valid")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
