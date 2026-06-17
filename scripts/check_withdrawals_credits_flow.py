#!/usr/bin/env python3
"""Validate the withdrawals and credits integration-flow documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_DOC = Path("docs/integrations/withdrawals-and-credits.md")

REQUIRED_HEADINGS = [
    (1, "Withdrawals And Credits"),
    (2, "Maturity And Scope"),
    (2, "Credit Families"),
    (2, "Source Of Truth"),
    (2, "Credit Discovery Reads"),
    (2, "Withdrawal Transactions"),
    (2, "Failure States"),
    (2, "Event And Indexer Reconstruction"),
    (2, "Owed, Reserved, And Surplus"),
    (2, "Frontend State Machine"),
    (2, "Mobile And Electron Boundaries"),
    (2, "Operator And Emergency Boundaries"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "fixed-price poster",
    "fixed-price protocol",
    "fixed-price curator reserve",
    "auction bidder refund",
    "auction poster proceeds",
    "auction protocol proceeds",
    "auction curator proceeds",
    "curator rewards",
    "pull payments",
    "withdrawFixedPriceCreditTo",
    "withdrawBidderCreditTo",
    "withdrawAuctionProceedsCreditTo",
    "withdrawCuratorCreditTo",
    "fixedPricePosterCredits",
    "fixedPriceProtocolCredits",
    "fixedPriceCuratorReserveCredits",
    "auctionBidderCredits",
    "auctionPosterCredits",
    "auctionProtocolCredits",
    "auctionCuratorCredits",
    "curatorCredits",
    "totalFixedPriceOwed",
    "totalBidderOwed",
    "totalProceedsOwed",
    "totalAuctionBidEscrow",
    "totalCuratorOwed",
    "totalReserved",
    "totalOwed",
    "surplus",
    "emergencyWithdrawable",
    "FixedPriceCreditCreated",
    "FixedPriceCreditWithdrawn",
    "OutbidCreditCreated",
    "BidderCreditWithdrawn",
    "AuctionProceedsCreditCreated",
    "ProceedsCreditWithdrawn",
    "CuratorCreditCreated",
    "CuratorCreditWithdrawn",
    "EmergencyWithdrawal",
    "failed withdrawals preserve credit",
    "recipient can differ from the owner",
    "credit owner",
    "stale indexer",
    "direct RPC read",
    "mobile",
    "Electron",
    "no-secret",
    "emergency withdrawal is surplus-only",
]

REQUIRED_COMMANDS = [
    "python scripts/test_withdrawals_credits_flow.py",
    "python scripts/check_withdrawals_credits_flow.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_changelog.py",
    "forge test --match-path test/StreamFixedPricePayments.t.sol",
    "forge test --match-path test/StreamAuctionPayments.t.sol",
    "forge test --match-path test/StreamCuratorsPool.t.sol",
    "forge test --match-path test/StreamPaymentsInvariant.t.sol",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/generate_release_checksums.py --check",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/curator-rewards.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/mobile-walletconnect.md",
    "docs/integrations/electron-security-wallets.md",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/RandomizerRNG.sol",
    "smart-contracts/StreamPauseDomains.sol",
    "test/StreamFixedPricePayments.t.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamCuratorsPool.t.sol",
    "test/StreamPaymentsInvariant.t.sol",
]

SOURCE_EXPECTATIONS = {
    "smart-contracts/StreamDrops.sol": [
        "fixedPricePosterCredits",
        "fixedPriceProtocolCredits",
        "fixedPriceCuratorReserveCredits",
        "withdrawFixedPriceCreditTo",
        "FixedPriceCreditCreated",
        "FixedPriceCreditWithdrawn",
        "totalFixedPriceOwed",
        "totalFixedPricePosterOwed",
        "totalFixedPriceProtocolOwed",
        "totalFixedPriceCuratorReserveOwed",
        "totalPosterOwed",
        "totalProtocolOwed",
        "totalCuratorReserved",
        "totalReserved",
        "emergencyWithdrawable",
    ],
    "smart-contracts/AuctionContract.sol": [
        "auctionBidderCredits",
        "auctionPosterCredits",
        "auctionProtocolCredits",
        "auctionCuratorCredits",
        "withdrawBidderCreditTo",
        "withdrawAuctionProceedsCreditTo",
        "OutbidCreditCreated",
        "BidderCreditWithdrawn",
        "AuctionProceedsCreditCreated",
        "ProceedsCreditWithdrawn",
        "totalAuctionBidEscrow",
        "totalProceedsOwed",
        "emergencyWithdrawable",
    ],
    "smart-contracts/StreamCuratorsPool.sol": [
        "curatorCredits",
        "Reward",
        "withdrawCuratorCreditTo",
        "CuratorCreditCreated",
        "CuratorCreditWithdrawn",
        "totalCuratorOwed",
        "totalReserved",
        "emergencyWithdrawable",
    ],
    "smart-contracts/StreamMinter.sol": [
        "totalOwed",
        "surplus",
        "emergencyWithdrawable",
        "EmergencyWithdrawal",
    ],
    "smart-contracts/RandomizerRNG.sol": [
        "totalOwed",
        "totalReserved",
        "emergencyWithdrawable",
        "surplus",
    ],
}

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class WithdrawalsCreditsFlowError(ValueError):
    """Raised when the withdrawals and credits guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise WithdrawalsCreditsFlowError(f"linked path escapes repository: {path}") from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None
    path_part = target.split("#", 1)[0].split("?", 1)[0]
    return path_part or None


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
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
        raise WithdrawalsCreditsFlowError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    normalized_text = " ".join(text.lower().split())
    return [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]


def validate_source_expectations(repo_root: Path) -> None:
    missing = []
    for relative, symbols in SOURCE_EXPECTATIONS.items():
        source_path = repo_root / relative
        if not source_path.is_file():
            missing.append(f"{relative}: missing file")
            continue
        source = source_path.read_text(encoding="utf-8")
        for symbol in symbols:
            if symbol not in source:
                missing.append(f"{relative}: {symbol}")

    if missing:
        raise WithdrawalsCreditsFlowError(
            "source surface no longer matches withdrawals guide: "
            + ", ".join(missing)
        )


def validate_withdrawals_credits_flow(repo_root: Path, document_path: Path) -> None:
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise WithdrawalsCreditsFlowError(f"missing withdrawals and credits doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise WithdrawalsCreditsFlowError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise WithdrawalsCreditsFlowError(
            "withdrawals and credits doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = missing_phrases(text, REQUIRED_COMMANDS)
    if missing_commands:
        raise WithdrawalsCreditsFlowError(
            "withdrawals and credits doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise WithdrawalsCreditsFlowError(
            "withdrawals and credits doc is missing required links: "
            + ", ".join(missing_targets)
        )

    validate_source_expectations(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.doc
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_withdrawals_credits_flow(repo_root, document_path.resolve())
    except WithdrawalsCreditsFlowError as exc:
        print(f"withdrawals and credits flow check failed: {exc}", file=sys.stderr)
        return 1

    print("withdrawals and credits flow doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
