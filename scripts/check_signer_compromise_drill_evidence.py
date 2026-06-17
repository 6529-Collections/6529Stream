#!/usr/bin/env python3
"""Validate retained signer-compromise drill evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "signer_compromise_drill_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/incident-drills/"
        "signer-compromise-drill-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Signer Compromise Drill Retained Artifact",
    "## Evidence Status",
    "## Drill Context",
    "## Containment Sequence",
    "## Recovery Sequence",
    "## Monitoring And Handoff",
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
    "Drill bundle reference",
    "Incident class",
    "Affected signer",
    "Replacement signer",
    "Signer manager",
    "Starting signer epoch",
    "Ending signer epoch",
    "Affected drop IDs",
    "Affected EIP-712 domain",
    "Drop execution pause evidence",
    "Signer rotation evidence",
    "Signer revocation evidence",
    "Signer epoch invalidation evidence",
    "Per-drop cancellation evidence",
    "Withdrawal availability evidence",
    "Stale payload rejection evidence",
    "Cancelled payload rejection evidence",
    "Wrong-domain rejection evidence",
    "Recovered fixed-price payload evidence",
    "Recovered auction payload evidence",
    "Post-recovery signer state evidence",
    "Operator dashboard confirmation",
    "Monitoring alert reference",
    "Incident response decision log",
    "Public communication status",
    "Follow-up issue links",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Signer custody readiness evidence",
    "Drop authorization signing evidence",
    "Admin ceremony evidence",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Raw signatures removed",
    "Unreleased drop payloads removed",
    "Private collector data removed",
}

FINAL_VALUE_FIELDS = sorted(
    REQUIRED_FIELDS
    - {
        "Requirement ID",
        "Review status",
        "Readiness claim",
        "Environment",
        "Incident class",
        "Review decision",
        "No secrets retained",
        "Private RPC URLs removed",
        "Private keys removed",
        "Signer-service secrets removed",
        "Raw signatures removed",
        "Unreleased drop payloads removed",
        "Private collector data removed",
    }
)

REDACTION_FIELDS = (
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "Signer-service secrets removed",
    "Raw signatures removed",
    "Unreleased drop payloads removed",
    "Private collector data removed",
)

REVIEW_STATUSES = {"template", "pending_review", "reviewed"}
READINESS_CLAIMS = {"blocked", "complete"}
ENVIRONMENTS = {"template", "fork", "testnet", "live"}
REVIEW_DECISIONS = {"template", "pending_review", "reviewed", "changes_requested"}

REQUIRED_COMMANDS = [
    "python scripts/test_signer_compromise_drill_evidence.py",
    "python scripts/check_signer_compromise_drill_evidence.py",
    "python scripts/test_incident_drill_evidence.py",
    "python scripts/check_incident_drill_evidence.py",
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

SOURCE_REQUIREMENTS = {
    Path("smart-contracts/StreamDrops.sol"): [
        "function updateTDHsigner",
        "function incrementSignerEpoch",
        "function cancelDrop",
        "event DropSignerChanged",
        "event SignerEpochChanged",
        "event DropAuthorizationCancelled",
        "isDropCancelled",
        "isDropConsumed",
    ],
    Path("smart-contracts/StreamPauseDomains.sol"): [
        "DROP_EXECUTION",
        "6529stream.pause.DropExecution",
    ],
    Path("test/StreamPauseControls.t.sol"): [
        "testDropExecutionPauseBlocksSignedDropsUntilUnpaused",
        "stale cancelled drop executed",
    ],
    Path("test/StreamSignerCompromiseFuzz.t.sol"): [
        "StreamSignerCompromiseFuzzTest",
        "compromised-fixed-before-rotation",
        "current-signer-before-epoch-invalidation",
        "cancelled-current-signer-before-execution",
        "recovered-fixed-after-compromise",
        "recovered-auction-after-compromise",
    ],
}

FIELD_RE = re.compile(r"^- (?P<label>[^:]+): (?P<value>.*)$")
ANGLE_PLACEHOLDER_RE = re.compile(r"<[^>\n]+>")
UINT_RE = re.compile(r"^(0|[1-9][0-9]*)$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
BYTES32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
GIT_COMMIT_RE = re.compile(r"^[0-9a-fA-F]{40}$")
SECRET_VALUE_RE = re.compile(
    r"\b("
    r"private[_ -]?key|mnemonic|seed[_ -]?phrase|secret|rpc[_ -]?url|"
    r"api[_ -]?key|password|bearer[_ -]?token|provider[_ -]?dashboard[_ -]?secret|"
    r"signer[_ -]?service[_ -]?secret|raw[_ -]?signature|"
    r"unreleased[_ -]?drop[_ -]?payload|private[_ -]?collector[_ -]?data"
    r")\s*[:=]",
    re.IGNORECASE,
)
CREDENTIAL_URL_RE = re.compile(r"https?://[^\s`/@:]+:[^\s`/@]+@[^\s`]+", re.IGNORECASE)
DOMAIN_CHAIN_RE = re.compile(r"(?:^|\s)chain=(?P<chain_id>0|[1-9][0-9]*)(?:\s|$)")
DOMAIN_VERIFYING_CONTRACT_RE = re.compile(
    r"(?:^|\s)verifyingContract=(?P<address>0x[0-9a-fA-F]{40})(?:\s|$)"
)


class SignerCompromiseDrillEvidenceError(RuntimeError):
    """Raised when signer-compromise drill evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise SignerCompromiseDrillEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise SignerCompromiseDrillEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CREDENTIAL_URL_RE.search(text)
    if match:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} contains credentialed URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise SignerCompromiseDrillEvidenceError(
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
            raise SignerCompromiseDrillEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(path: Path, fields: dict[str, str], label: str, expected: str) -> None:
    actual = fields[label]
    if actual != expected:
        raise SignerCompromiseDrillEvidenceError(
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
    } or bool(ANGLE_PLACEHOLDER_RE.fullmatch(value))


def validate_drop_ids(path: Path, value: str) -> None:
    drop_ids = [part.strip() for part in value.split(",")]
    if not drop_ids or any(not drop_id for drop_id in drop_ids):
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Affected drop IDs must be comma-separated bytes32 values"
        )
    for drop_id in drop_ids:
        if not BYTES32_RE.fullmatch(drop_id):
            raise SignerCompromiseDrillEvidenceError(
                f"{path} Affected drop IDs must be comma-separated bytes32 values"
            )


def validate_eip712_domain(path: Path, fields: dict[str, str]) -> None:
    domain = fields["Affected EIP-712 domain"]
    chain_match = DOMAIN_CHAIN_RE.search(domain)
    if not chain_match:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Affected EIP-712 domain must include chain=<uint>"
        )
    if chain_match.group("chain_id") != fields["Chain ID"]:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Affected EIP-712 domain chain must match Chain ID"
        )
    if not DOMAIN_VERIFYING_CONTRACT_RE.search(domain):
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Affected EIP-712 domain must include verifyingContract=<address>"
        )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Review status must be one of {expected}, got {review_status!r}"
        )
    if fields["Readiness claim"] not in READINESS_CLAIMS:
        expected = ", ".join(sorted(READINESS_CLAIMS))
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Readiness claim must be one of {expected}"
        )
    if fields["Environment"] not in ENVIRONMENTS:
        expected = ", ".join(sorted(ENVIRONMENTS))
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Environment must be one of {expected}"
        )
    if fields["Review decision"] not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Review decision must be one of {expected}"
        )

    if review_status == "template":
        if "> Template only. This file is not completion evidence." not in text:
            raise SignerCompromiseDrillEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        require_field_value(path, fields, "Readiness claim", "blocked")
        return

    if "> Template only. This file is not completion evidence." in text:
        raise SignerCompromiseDrillEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise SignerCompromiseDrillEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
    if fields["Review decision"] == "template":
        raise SignerCompromiseDrillEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )
    if review_status == "pending_review":
        require_field_value(path, fields, "Readiness claim", "blocked")
        return

    require_field_value(path, fields, "Review decision", "reviewed")
    require_field_value(path, fields, "Readiness claim", "complete")
    if fields["Environment"] == "template":
        raise SignerCompromiseDrillEvidenceError(
            f"{path} reviewed evidence must use fork, testnet, or live environment"
        )
    if not UINT_RE.fullmatch(fields["Chain ID"]):
        raise SignerCompromiseDrillEvidenceError(f"{path} Chain ID must be a uint")
    if not GIT_COMMIT_RE.fullmatch(fields["Release commit"]):
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Release commit must be a 40-character hex commit"
        )
    for label in ("Affected signer", "Replacement signer", "Signer manager"):
        if not ADDRESS_RE.fullmatch(fields[label]):
            raise SignerCompromiseDrillEvidenceError(
                f"{path} field {label!r} must be an address"
            )
    if fields["Affected signer"].lower() == fields["Replacement signer"].lower():
        raise SignerCompromiseDrillEvidenceError(
            f"{path} replacement signer must differ from affected signer"
        )
    for label in ("Starting signer epoch", "Ending signer epoch"):
        if not UINT_RE.fullmatch(fields[label]):
            raise SignerCompromiseDrillEvidenceError(f"{path} {label} must be a uint")
    if int(fields["Ending signer epoch"]) <= int(fields["Starting signer epoch"]):
        raise SignerCompromiseDrillEvidenceError(
            f"{path} Ending signer epoch must increase"
        )
    validate_drop_ids(path, fields["Affected drop IDs"])
    validate_eip712_domain(path, fields)
    for label in REDACTION_FIELDS:
        require_field_value(path, fields, label, "yes")


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise SignerCompromiseDrillEvidenceError(
                f"{path} is missing required validation command: {command}"
            )


def validate_source_requirements(repo_root: Path) -> None:
    for relative_path, snippets in SOURCE_REQUIREMENTS.items():
        path = repo_root / relative_path
        text = read_text(path)
        for snippet in snippets:
            if snippet not in text:
                raise SignerCompromiseDrillEvidenceError(
                    f"{relative_path} is missing signer-compromise source snippet: {snippet}"
                )


def validate_evidence(path: Path, *, repo_root: Path | None = None) -> None:
    repo_root = Path.cwd() if repo_root is None else repo_root
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Incident class", "signer_compromise")
    validate_review_state(path, text, fields)
    validate_commands(path, text)
    validate_source_requirements(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained signer-compromise drill evidence artifacts."
    )
    parser.add_argument(
        "evidence",
        nargs="*",
        type=Path,
        help="Evidence Markdown files to validate. Defaults to committed templates.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path.cwd(),
        help="Repository root used for source-aware checks.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    paths = args.evidence or DEFAULT_EVIDENCE
    try:
        for path in paths:
            validate_evidence(path, repo_root=args.repo_root)
    except SignerCompromiseDrillEvidenceError as exc:
        print(f"signer compromise drill evidence check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
