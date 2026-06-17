#!/usr/bin/env python3
"""Validate retained incident drill evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "incident_drill_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/incident-drills/"
        "incident-drill-retained-artifact-template.md"
    )
]

DRILL_IDS = {
    "mint_pause",
    "bid_pause",
    "settlement_pause",
    "withdrawal_policy",
    "failed_randomness",
    "stuck_auction",
    "bad_metadata_dependency",
    "bad_merkle_root",
    "signer_compromise",
}

REQUIRED_HEADINGS = [
    "# Incident Drill Retained Artifact",
    "## Evidence Status",
    "## Drill Context",
    "## Mint Pause Drill",
    "## Bid Pause Drill",
    "## Settlement Pause Drill",
    "## Withdrawal Policy Drill",
    "## Failed Randomness Drill",
    "## Stuck Auction Drill",
    "## Bad Metadata Or Dependency Drill",
    "## Bad Merkle Root Drill",
    "## Signer Compromise Drill",
    "## Required Retained Artifacts",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]

DRILL_FIELD_PREFIXES = [
    "Mint pause",
    "Bid pause",
    "Settlement pause",
    "Withdrawal policy",
    "Failed randomness",
    "Stuck auction",
    "Bad metadata/dependency",
    "Bad Merkle root",
    "Signer compromise",
]

DRILL_FIELD_SUFFIXES = [
    "command evidence",
    "affected controls",
    "observed events",
    "rollback/recovery status",
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
    "Drill bundle reference",
    "Drill coverage",
    "Incident decision log",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Recovery evidence bundle",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Provider dashboard secrets removed",
    "Unreleased drop payloads removed",
    "Private collector data removed",
} | {
    f"{prefix} {suffix}"
    for prefix in DRILL_FIELD_PREFIXES
    for suffix in DRILL_FIELD_SUFFIXES
}

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
READINESS_CLAIMS = {"blocked", "complete"}
ENVIRONMENTS = {"template", "fork", "testnet", "live"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}
FINAL_VALUE_FIELDS = [
    "Chain ID",
    "Release commit",
    "Deployment version",
    "Drill bundle reference",
    "Incident decision log",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Recovery evidence bundle",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
] + [
    f"{prefix} {suffix}"
    for prefix in DRILL_FIELD_PREFIXES
    for suffix in DRILL_FIELD_SUFFIXES
]
RECOVERY_STATUS_FIELDS = [
    f"{prefix} rollback/recovery status" for prefix in DRILL_FIELD_PREFIXES
]
REDACTION_FIELDS = (
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Provider dashboard secrets removed",
    "Unreleased drop payloads removed",
    "Private collector data removed",
)

REQUIRED_COMMANDS = [
    "python scripts/test_incident_drill_evidence.py",
    "python scripts/check_incident_drill_evidence.py",
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/check_release_readiness.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|provider[_ -]?dashboard[_ -]?secret|"
    r"signer[_ -]?service[_ -]?secret|unreleased[_ -]?drop[_ -]?payload|"
    r"private[_ -]?collector[_ -]?data"
    r")\s*[:=]",
    re.IGNORECASE,
)
CREDENTIAL_URL_RE = re.compile(r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+", re.IGNORECASE)


class IncidentDrillEvidenceError(RuntimeError):
    """Raised when incident drill evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise IncidentDrillEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise IncidentDrillEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise IncidentDrillEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CREDENTIAL_URL_RE.search(text)
    if match:
        raise IncidentDrillEvidenceError(
            f"{path} contains credentialed URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise IncidentDrillEvidenceError(
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
            raise IncidentDrillEvidenceError(f"{path} has duplicate field: {label}")
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise IncidentDrillEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(
    path: Path, fields: dict[str, str], label: str, expected: str
) -> None:
    actual = fields[label]
    if actual != expected:
        raise IncidentDrillEvidenceError(
            f"{path} field {label!r} must be {expected!r}, got {actual!r}"
        )


def is_placeholder(value: str) -> bool:
    lowered = value.lower()
    return lowered in {
        "tbd",
        "template",
        "template-only",
        "n/a",
        "na",
        "none",
    } or bool(
        ANGLE_PLACEHOLDER_RE.fullmatch(value)
    )


def validate_drill_coverage(path: Path, fields: dict[str, str]) -> None:
    coverage = {
        part.strip()
        for part in fields["Drill coverage"].split(",")
        if part.strip()
    }
    missing = sorted(DRILL_IDS - coverage)
    extra = sorted(coverage - DRILL_IDS)
    if missing:
        raise IncidentDrillEvidenceError(
            f"{path} Drill coverage is missing required drill(s): {', '.join(missing)}"
        )
    if extra:
        raise IncidentDrillEvidenceError(
            f"{path} Drill coverage includes unknown drill(s): {', '.join(extra)}"
        )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise IncidentDrillEvidenceError(
            f"{path} Review status must be one of {expected}, got {review_status!r}"
        )
    if fields["Readiness claim"] not in READINESS_CLAIMS:
        expected = ", ".join(sorted(READINESS_CLAIMS))
        raise IncidentDrillEvidenceError(
            f"{path} Readiness claim must be one of {expected}"
        )
    if fields["Environment"] not in ENVIRONMENTS:
        expected = ", ".join(sorted(ENVIRONMENTS))
        raise IncidentDrillEvidenceError(
            f"{path} Environment must be one of {expected}"
        )
    if fields["Review decision"] not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise IncidentDrillEvidenceError(
            f"{path} Review decision must be one of {expected}"
        )

    if review_status == "template":
        if "> Template only. This file is not completion evidence." not in text:
            raise IncidentDrillEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        require_field_value(path, fields, "Readiness claim", "blocked")
        return

    if "> Template only. This file is not completion evidence." in text:
        raise IncidentDrillEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise IncidentDrillEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
    if fields["Review decision"] == "template":
        raise IncidentDrillEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )
    if review_status == "pending_review":
        require_field_value(path, fields, "Readiness claim", "blocked")
    if review_status == "reviewed":
        require_field_value(path, fields, "Review decision", "reviewed")
        require_field_value(path, fields, "Readiness claim", "complete")
        if fields["Environment"] == "template":
            raise IncidentDrillEvidenceError(
                f"{path} reviewed evidence must use fork, testnet, or live environment"
            )
        if not UINT_RE.fullmatch(fields["Chain ID"]):
            raise IncidentDrillEvidenceError(f"{path} Chain ID must be a uint")
        for label in RECOVERY_STATUS_FIELDS:
            require_field_value(path, fields, label, "passed")
        for label in REDACTION_FIELDS:
            require_field_value(path, fields, label, "yes")


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise IncidentDrillEvidenceError(
                f"{path} is missing required validation command: {command}"
            )


def validate_evidence(path: Path) -> None:
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    validate_drill_coverage(path, fields)
    validate_review_state(path, text, fields)
    validate_commands(path, text)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained incident drill evidence artifacts."
    )
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        help="Evidence Markdown files to validate. Defaults to committed templates.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_evidence(path)
    except IncidentDrillEvidenceError as exc:
        print(f"incident drill evidence check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
