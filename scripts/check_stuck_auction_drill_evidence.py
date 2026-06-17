#!/usr/bin/env python3
"""Validate retained stuck-auction drill evidence artifacts."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REQUIREMENT_ID = "stuck_auction_drill_evidence"
DEFAULT_EVIDENCE = [
    Path(
        "release-artifacts/evidence/incident-drills/"
        "stuck-auction-drill-retained-artifact-template.md"
    )
]

REQUIRED_HEADINGS = [
    "# Stuck Auction Drill Retained Artifact",
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
    "Auction contract",
    "Token ID",
    "Collection ID",
    "Drop ID",
    "Auction path",
    "Stuck condition",
    "Poster",
    "Highest bidder",
    "Highest bid wei",
    "Starting auction status",
    "Ending auction status",
    "Bid pause evidence",
    "Settlement pause evidence",
    "Custody snapshot evidence",
    "No-bid claimant evidence",
    "Credit balance snapshot evidence",
    "Emergency surplus boundary evidence",
    "Settlement unpause evidence",
    "Terminal auction outcome evidence",
    "Bidder credit withdrawal evidence",
    "Proceeds withdrawal evidence",
    "Settlement idempotency evidence",
    "Post-recovery owed balance evidence",
    "Operator dashboard confirmation",
    "Monitoring alert reference",
    "Incident response decision log",
    "Public communication status",
    "Follow-up issue links",
    "Command transcript bundle",
    "Event or state snapshot bundle",
    "Auction flow spec evidence",
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
AUCTION_PATHS = {"with_bid", "no_bid", "cancelled_no_bid"}
STUCK_CONDITIONS = {
    "bid_paused",
    "settlement_paused",
    "no_bid_pending",
    "poster_receiver_blocked",
    "withdrawal_receiver_blocked",
    "indexer_stale",
}
AUCTION_STATUSES = {
    "Created",
    "Active",
    "EndedNoBid",
    "EndedWithBid",
    "SettledNoBid",
    "SettledWithBid",
    "Cancelled",
}
TERMINAL_BY_PATH = {
    "with_bid": {"SettledWithBid"},
    "no_bid": {"SettledNoBid"},
    "cancelled_no_bid": {"Cancelled"},
}
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"

REQUIRED_COMMANDS = [
    "python scripts/test_stuck_auction_drill_evidence.py",
    "python scripts/check_stuck_auction_drill_evidence.py",
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
    Path("smart-contracts/AuctionContract.sol"): [
        "event AuctionCancelled",
        "event NoBidSettlementPending",
        "event BidderCreditWithdrawn",
        "event ProceedsCreditWithdrawn",
        "event ClaimAuction",
        "function claimAuction",
        "function claimNoBidAuctionToken",
        "function cancelAuction",
        "function totalOwed",
        "function emergencyWithdrawable",
    ],
    Path("smart-contracts/StreamPauseDomains.sol"): [
        "AUCTION_BID",
        "AUCTION_SETTLEMENT",
        "6529stream.pause.AuctionBid",
        "6529stream.pause.AuctionSettlement",
    ],
    Path("test/StreamPauseControls.t.sol"): [
        "PAUSE_DOMAIN_AUCTION_BID",
        "PAUSE_DOMAIN_AUCTION_SETTLEMENT",
        "Settlement paused",
        "withdrawBidderCreditTo",
        "withdrawAuctionProceedsCreditTo",
        "claimNoBidAuctionToken",
    ],
    Path("test/StreamProtocolStateMachine.t.sol"): [
        "paused bid owed",
        "repeat owed",
        "failed withdrawal owed",
    ],
    Path("docs/integrations/auction-flows.md"): [
        "NoBidSettlementPending",
        "claimNoBidAuctionToken(tokenId, recipient)",
        "failed bidder withdrawal must not erase",
        "failed proceeds withdrawal must not erase",
        "emergency withdrawal cannot withdraw owed",
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


class StuckAuctionDrillEvidenceError(RuntimeError):
    """Raised when stuck-auction drill evidence is invalid."""


def normalize_value(value: str) -> str:
    value = value.strip()
    if value.startswith("`") and value.endswith("`") and len(value) >= 2:
        value = value[1:-1]
    return value.strip()


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise StuckAuctionDrillEvidenceError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise StuckAuctionDrillEvidenceError(f"{path} must be valid UTF-8") from exc


def validate_no_secret_values(path: Path, text: str) -> None:
    match = SECRET_VALUE_RE.search(text)
    if match:
        raise StuckAuctionDrillEvidenceError(
            f"{path} contains secret-like key/value text: {match.group(0)}"
        )
    match = CREDENTIAL_URL_RE.search(text)
    if match:
        raise StuckAuctionDrillEvidenceError(
            f"{path} contains credentialed URL text: {match.group(0)}"
        )


def validate_headings(path: Path, text: str) -> None:
    lines = [line.strip() for line in text.splitlines()]
    cursor = 0
    for heading in REQUIRED_HEADINGS:
        try:
            index = lines.index(heading, cursor)
        except ValueError as exc:
            raise StuckAuctionDrillEvidenceError(
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
            raise StuckAuctionDrillEvidenceError(
                f"{path} has duplicate field: {label}"
            )
        fields[label] = value
    missing = sorted(REQUIRED_FIELDS - set(fields))
    if missing:
        raise StuckAuctionDrillEvidenceError(
            f"{path} is missing required field(s): {', '.join(missing)}"
        )
    return fields


def require_field_value(path: Path, fields: dict[str, str], label: str, expected: str) -> None:
    actual = fields[label]
    if actual != expected:
        raise StuckAuctionDrillEvidenceError(
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


def require_uint(path: Path, fields: dict[str, str], label: str) -> int:
    value = fields[label]
    if not UINT_RE.fullmatch(value):
        raise StuckAuctionDrillEvidenceError(f"{path} {label} must be a uint")
    return int(value)


def require_address(path: Path, fields: dict[str, str], label: str) -> str:
    value = fields[label]
    if not ADDRESS_RE.fullmatch(value):
        raise StuckAuctionDrillEvidenceError(
            f"{path} field {label!r} must be an address"
        )
    return value.lower()


def validate_auction_shape(path: Path, fields: dict[str, str]) -> None:
    auction_path = fields["Auction path"]
    if auction_path not in AUCTION_PATHS:
        expected = ", ".join(sorted(AUCTION_PATHS))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Auction path must be one of {expected}"
        )
    if fields["Stuck condition"] not in STUCK_CONDITIONS:
        expected = ", ".join(sorted(STUCK_CONDITIONS))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Stuck condition must be one of {expected}"
        )
    for label in ("Starting auction status", "Ending auction status"):
        if fields[label] not in AUCTION_STATUSES:
            expected = ", ".join(sorted(AUCTION_STATUSES))
            raise StuckAuctionDrillEvidenceError(
                f"{path} {label} must be one of {expected}"
            )
    if fields["Ending auction status"] not in TERMINAL_BY_PATH[auction_path]:
        expected = ", ".join(sorted(TERMINAL_BY_PATH[auction_path]))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Ending auction status must match Auction path: {expected}"
        )

    highest_bid = require_uint(path, fields, "Highest bid wei")
    highest_bidder = require_address(path, fields, "Highest bidder")
    if auction_path == "with_bid":
        if highest_bid == 0:
            raise StuckAuctionDrillEvidenceError(
                f"{path} with_bid auction evidence requires a non-zero highest bid"
            )
        if highest_bidder == ZERO_ADDRESS:
            raise StuckAuctionDrillEvidenceError(
                f"{path} with_bid auction evidence requires a non-zero highest bidder"
            )
        return

    if highest_bid != 0:
        raise StuckAuctionDrillEvidenceError(
            f"{path} no-bid/cancelled auction evidence requires zero highest bid"
        )
    if highest_bidder != ZERO_ADDRESS:
        raise StuckAuctionDrillEvidenceError(
            f"{path} no-bid/cancelled auction evidence requires zero highest bidder"
        )


def validate_review_state(path: Path, text: str, fields: dict[str, str]) -> None:
    review_status = fields["Review status"]
    if review_status not in REVIEW_STATUSES:
        expected = ", ".join(sorted(REVIEW_STATUSES))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Review status must be one of {expected}, got {review_status!r}"
        )
    if fields["Readiness claim"] not in READINESS_CLAIMS:
        expected = ", ".join(sorted(READINESS_CLAIMS))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Readiness claim must be one of {expected}"
        )
    if fields["Environment"] not in ENVIRONMENTS:
        expected = ", ".join(sorted(ENVIRONMENTS))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Environment must be one of {expected}"
        )
    if fields["Review decision"] not in REVIEW_DECISIONS:
        expected = ", ".join(sorted(REVIEW_DECISIONS))
        raise StuckAuctionDrillEvidenceError(
            f"{path} Review decision must be one of {expected}"
        )

    if review_status == "template":
        if "> Template only. This file is not completion evidence." not in text:
            raise StuckAuctionDrillEvidenceError(
                f"{path} template evidence must include the template-only notice"
            )
        require_field_value(path, fields, "Review decision", "template")
        require_field_value(path, fields, "Readiness claim", "blocked")
        return

    if "> Template only. This file is not completion evidence." in text:
        raise StuckAuctionDrillEvidenceError(
            f"{path} non-template evidence must remove the template-only notice"
        )
    for label in FINAL_VALUE_FIELDS:
        if is_placeholder(fields[label]):
            raise StuckAuctionDrillEvidenceError(
                f"{path} field {label!r} must be replaced before non-template review"
            )
    if fields["Review decision"] == "template":
        raise StuckAuctionDrillEvidenceError(
            f"{path} non-template evidence must advance the review decision"
        )
    if review_status == "pending_review":
        require_field_value(path, fields, "Readiness claim", "blocked")
        return

    require_field_value(path, fields, "Review decision", "reviewed")
    require_field_value(path, fields, "Readiness claim", "complete")
    if fields["Environment"] == "template":
        raise StuckAuctionDrillEvidenceError(
            f"{path} reviewed evidence must use fork, testnet, or live environment"
        )
    if not UINT_RE.fullmatch(fields["Chain ID"]):
        raise StuckAuctionDrillEvidenceError(f"{path} Chain ID must be a uint")
    if not GIT_COMMIT_RE.fullmatch(fields["Release commit"]):
        raise StuckAuctionDrillEvidenceError(
            f"{path} Release commit must be a 40-character hex commit"
        )
    require_address(path, fields, "Auction contract")
    require_address(path, fields, "Poster")
    require_uint(path, fields, "Token ID")
    require_uint(path, fields, "Collection ID")
    if not BYTES32_RE.fullmatch(fields["Drop ID"]):
        raise StuckAuctionDrillEvidenceError(f"{path} Drop ID must be bytes32")
    validate_auction_shape(path, fields)
    for label in REDACTION_FIELDS:
        require_field_value(path, fields, label, "yes")


def validate_commands(path: Path, text: str) -> None:
    for command in REQUIRED_COMMANDS:
        if command not in text:
            raise StuckAuctionDrillEvidenceError(
                f"{path} is missing required validation command: {command}"
            )


def validate_source_requirements(repo_root: Path) -> None:
    for relative_path, snippets in SOURCE_REQUIREMENTS.items():
        path = repo_root / relative_path
        text = read_text(path)
        for snippet in snippets:
            if snippet not in text:
                raise StuckAuctionDrillEvidenceError(
                    f"{relative_path} is missing stuck-auction source snippet: {snippet}"
                )


def validate_evidence(path: Path, *, repo_root: Path | None = None) -> None:
    repo_root = Path.cwd() if repo_root is None else repo_root
    text = read_text(path)
    validate_no_secret_values(path, text)
    validate_headings(path, text)
    fields = field_map(path, text)
    require_field_value(path, fields, "Requirement ID", REQUIREMENT_ID)
    require_field_value(path, fields, "Incident class", "stuck_auction")
    validate_review_state(path, text, fields)
    validate_commands(path, text)
    validate_source_requirements(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate retained stuck-auction drill evidence artifacts."
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
    except StuckAuctionDrillEvidenceError as exc:
        print(f"stuck auction drill evidence check failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
