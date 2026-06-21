#!/usr/bin/env python3
"""Validate the integration auction-flow documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_AUCTION_FLOWS = Path("docs/integrations/auction-flows.md")

REQUIRED_HEADINGS = [
    (1, "Auction Flows"),
    (2, "Maturity And Scope"),
    (2, "Auction Mint Overview"),
    (2, "Source Of Truth"),
    (2, "Artifact Inputs"),
    (2, "Preflight Reads"),
    (2, "Authorization Payload"),
    (2, "Submit Auction Drop"),
    (2, "Auction State Machine"),
    (2, "Bidding"),
    (2, "Settlement"),
    (2, "No-Bid Claims"),
    (2, "Cancellation"),
    (2, "Credits And Withdrawals"),
    (2, "Events And Indexing"),
    (2, "Pause And Emergency Boundaries"),
    (2, "Failure States"),
    (2, "Frontend State Machine"),
    (2, "Indexer Reconstruction"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "local baseline",
    "does not replace fork/testnet/live evidence",
    "public beta",
    "production",
    "auction drops",
    "DropAuthorization",
    "mintDrop",
    "mintAndAuction",
    "registerAuction",
    "participateToAuction",
    "claimAuction",
    "claimNoBidAuctionToken",
    "cancelAuction",
    "saleMode = 2",
    "recipient = address(0)",
    "payer = address(0)",
    "price = 0",
    "msg.value == 0",
    "EIP-712",
    "ERC-1271",
    "domainSeparator",
    "deriveDropId",
    "consumedDropIds",
    "cancelledDropIds",
    "signer epoch",
    "None",
    "Created",
    "Active",
    "EndedNoBid",
    "EndedWithBid",
    "SettledNoBid",
    "SettledWithBid",
    "Cancelled",
    "AuctionRegistered",
    "AuctionCustodyConfirmed",
    "AuctionStatusChanged",
    "AuctionExtended",
    "MinterAuctionMinted",
    "MinterAuctionEndTimeUpdated",
    "AuctionCancelled",
    "NoBidSettlementPending",
    "NoBidTokenClaimed",
    "Participate",
    "OutbidCreditCreated",
    "BidderCreditWithdrawn",
    "AuctionProceedsCreditCreated",
    "ProceedsCreditWithdrawn",
    "ClaimAuction",
    "EmergencyWithdrawal",
    "AUCTION_BID",
    "AuctionBid",
    "AUCTION_SETTLEMENT",
    "AuctionSettlement",
    "auctionHighestBid",
    "auctionHighestBidder",
    "auctionBidderCredits",
    "auctionPosterCredits",
    "auctionProtocolCredits",
    "auctionCuratorCredits",
    "totalAuctionBidEscrow",
    "totalBidderOwed",
    "totalProceedsOwed",
    "totalOwed",
    "totalReserved",
    "surplus",
    "emergencyWithdrawable",
    "posterBps",
    "protocolBps",
    "curatorBps",
    "curatorBps = 0",
    "highestBid * posterBps / 10000",
    "highestBid * curatorBps / 10000",
    "highestBid - posterCredit - curatorCredit",
    "proceedsSplitFor",
    "releaseAuctionCuratorCredit",
    "previous bidder refund becomes withdrawable credit",
    "failed bidder withdrawal must not erase",
    "failed proceeds withdrawal must not erase",
    "emergency withdrawal cannot withdraw owed",
    "minimumNextBid",
    "StreamAuctions.retrieveAuctionEndTime",
    "StreamMinter.getAuctionEndTime",
    "block.timestamp > endTime",
    "event/read gaps",
    "CON-003",
    "INT-005",
    "React",
    "mobile",
    "Electron",
    "indexer",
    "backend signing service",
]

REQUIRED_COMMANDS = [
    "python scripts/test_auction_flows.py",
    "python scripts/check_auction_flows.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_changelog.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/generate_release_checksums.py --check",
    "forge test --match-path test/StreamAuctionCustody.t.sol",
    "forge test --match-path test/StreamAuctionPayments.t.sol",
    "forge test --match-path test/StreamMinterEvents.t.sol",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/auction-custody.md",
    "docs/adr/0002-auction-custody.md",
    "docs/adr/0003-payment-accounting.md",
    "docs/drop-authorization-signing.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/IStreamAuctions.sol",
    "smart-contracts/StreamPauseDomains.sol",
    "test/StreamAuctionCustody.t.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamAuctionInvariant.t.sol",
    "test/StreamPaymentsInvariant.t.sol",
    "test/StreamProtocolStateMachine.t.sol",
    "test/StreamPauseControls.t.sol",
    "test/fixtures/drop-authorization/auction-eoa.json",
    "test/fixtures/drop-authorization/payload-generator/auction-output.json",
    "scripts/generate_drop_authorization_payload.py",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class AuctionFlowsError(ValueError):
    """Raised when the auction-flow docs are missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise AuctionFlowsError(f"linked path escapes repository: {path}") from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    """Return a local Markdown link path without anchors or query strings."""
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    if not path_part:
        return None
    return path_part


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        target = normalized_link_target(match.group(1))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path

        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        links.add(relative)

    if missing:
        raise AuctionFlowsError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]


def validate_auction_flows(repo_root: Path, document_path: Path) -> None:
    """Validate the auction-flow documentation."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise AuctionFlowsError(f"missing auction flows doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise AuctionFlowsError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise AuctionFlowsError(
            "auction flows doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise AuctionFlowsError(
            "auction flows doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise AuctionFlowsError(
            "auction flows doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse auction-flow checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--auction-flows", type=Path, default=DEFAULT_AUCTION_FLOWS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the auction-flow checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.auction_flows
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_auction_flows(repo_root, document_path.resolve())
    except AuctionFlowsError as exc:
        print(f"auction flows check failed: {exc}", file=sys.stderr)
        return 1

    print("auction flows doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
