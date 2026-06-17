#!/usr/bin/env python3
"""Validate the protocol monitoring specification."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_MONITORING_SPEC = Path("docs/monitoring.md")

REQUIRED_HEADINGS = [
    (1, "Protocol Monitoring Specification"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Data Sources"),
    (2, "Event Coverage"),
    (2, "Admin And Role Monitoring"),
    (2, "Signer And Drop Authorization Monitoring"),
    (2, "Auction Monitoring"),
    (2, "Randomizer Monitoring"),
    (2, "Payment And Credit Monitoring"),
    (2, "Metadata And Dependency Monitoring"),
    (2, "Release Evidence Monitoring"),
    (2, "Alert Severity Model"),
    (2, "Dashboard And Query Model"),
    (2, "Incident Handoff"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "GOV-009",
    "pre-audit local baseline",
    "not production-ready",
    "not a security claim",
    "does not replace fork/testnet/live evidence",
    "maintained monitoring service",
    "public beta",
    "production",
    "no secrets",
    "private keys",
    "mnemonics",
    "RPC URLs",
    "API keys",
    "signer-service credentials",
    "unreleased drop payloads",
    "chain ID",
    "deployment version",
    "contract address",
    "block number",
    "block hash",
    "transaction hash",
    "log index",
    "event signature",
    "normalized log identity",
    "confirmation depth",
    "reorg rollback",
    "event topic catalog",
    "release manifest",
    "checksum bundle",
    "address book",
    "bytecode proof",
    "risk register",
    "public-beta evidence",
    "GlobalAdminUpdated",
    "FunctionAdminUpdated",
    "PauseGuardianUpdated",
    "UnpauseAdminUpdated",
    "SignerManagerUpdated",
    "SignerLifecycleTargetUpdated",
    "EmergencyRecipientUpdated",
    "DropSignerChanged",
    "SignerEpochChanged",
    "DropAuthorizationCancelled",
    "PauseUpdated",
    "EmergencyWithdrawal",
    "CollectionFrozen",
    "PermanentURI",
    "ERC-4906",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "DependencyVersionPinned",
    "DROP_EXECUTION",
    "MINT",
    "AUCTION_BID",
    "AUCTION_SETTLEMENT",
    "METADATA_MUTATION",
    "RANDOMNESS_REQUEST",
    "EIP-712",
    "ERC-1271",
    "Safe",
    "EOA",
    "Replay protection",
    "consumed-state storage",
    "token custody is known at all times",
    "previous bidder refund becomes withdrawable credit",
    "settlement is idempotent",
    "poster credits",
    "bidder credits",
    "curator credits",
    "protocol surplus",
    "total owed",
    "emergency withdrawable",
    "failed withdrawal does not erase credit",
    "emergency withdrawal cannot withdraw owed funds",
    "fulfillment validates request ID, token, collection, randomizer address, and randomizer epoch",
    "provider funding",
    "stale requests",
    "critical alert",
    "incident-response handoff",
]

REQUIRED_SECTION_PHRASES = {
    "Event Coverage": [
        "Admin and roles",
        "Signer and drop authorization",
        "Pause and emergency",
        "Auction",
        "Payments and credits",
        "Randomizer",
        "Metadata and dependency",
        "Release evidence",
    ],
    "Admin And Role Monitoring": [
        "role change",
        "approved Safe or multisig ceremony",
        "selector coverage drift",
        "two-person review",
        "post-state read",
    ],
    "Signer And Drop Authorization Monitoring": [
        "signer rotation",
        "signer custody readiness evidence",
        "signer epoch increments",
        "drop cancellations",
        "accepted drop authorization",
    ],
    "Auction Monitoring": [
        "None",
        "Created",
        "Active",
        "EndedNoBid",
        "EndedWithBid",
        "SettledNoBid",
        "SettledWithBid",
        "Cancelled",
        "stuck auctions",
    ],
    "Randomizer Monitoring": [
        "request ID",
        "randomizer epoch",
        "unexpected provider",
        "duplicate callback",
        "pending request age",
    ],
    "Payment And Credit Monitoring": [
        "poster credits",
        "bidder credits",
        "curator credits",
        "protocol surplus",
        "contract balance covers owed balances",
    ],
    "Dashboard And Query Model": [
        "deployment selector",
        "admin activity",
        "signer activity",
        "auction health",
        "randomizer health",
        "payments and credits",
        "metadata and dependency state",
        "release evidence",
    ],
}

REQUIRED_COMMANDS = [
    "python scripts/test_monitoring_spec.py",
    "python scripts/check_monitoring_spec.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_readme.py",
    "python scripts/check_readme.py",
    "python scripts/test_markdown_links.py",
    "python scripts/check_markdown_links.py",
    "python scripts/check_changelog.py",
    "make monitoring-spec-check",
    "make check",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "README.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/incident-response.md",
    "docs/integrations/README.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/operator-admin-ui.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/withdrawals-and-credits.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/randomizer-operations.md",
    "docs/dependency-operations.md",
    "docs/metadata.md",
    "docs/deployment.md",
    "docs/protocol-surface.md",
    "docs/custom-errors.md",
    "docs/release-policy.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/latest/protocol-surface-report.json",
    "release-artifacts/latest/custom-error-catalog.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/release-evidence-packet-index.md",
    "deployments/schema/deployment-manifest.schema.json",
    "deployments/schema/address-book.schema.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/StreamAdmins.sol",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/StreamRandomizerLifecycle.sol",
    "smart-contracts/RandomizerRNG.sol",
    "smart-contracts/RandomizerVRF.sol",
    "smart-contracts/StreamCore.sol",
    "test/StreamEventReconstructability.t.sol",
    "test/StreamPauseControls.t.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamRandomizerLifecycle.t.sol",
    "test/StreamRandomizerPayments.t.sol",
    "test/StreamSignerAdmin.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class MonitoringSpecError(ValueError):
    """Raised when the monitoring specification is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise MonitoringSpecError(f"linked path escapes repository: {path}") from exc


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
        raise MonitoringSpecError(
            "monitoring specification links to missing files: "
            + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases not found after whitespace normalization."""
    normalized_text = re.sub(r"\s+", " ", text)
    return [
        phrase
        for phrase in phrases
        if re.sub(r"\s+", " ", phrase) not in normalized_text
    ]


def markdown_section(text: str, heading: str) -> str:
    """Return the body for a level-two Markdown section."""
    pattern = re.compile(
        rf"^## {re.escape(heading)}\s*$([\s\S]*?)(?=^## |\Z)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    return "" if match is None else match.group(1)


def validate_monitoring_spec(repo_root: Path, document_path: Path) -> None:
    """Validate the monitoring specification."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise MonitoringSpecError(f"missing monitoring specification: {relative}")

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_required_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_required_headings:
        raise MonitoringSpecError(
            "monitoring specification is missing required headings: "
            + ", ".join(missing_required_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise MonitoringSpecError(
            "monitoring specification is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_section_content = []
    for heading, phrases in REQUIRED_SECTION_PHRASES.items():
        section = markdown_section(text, heading)
        for phrase in missing_phrases(section, phrases):
            missing_section_content.append(f"{heading}: {phrase}")
    if missing_section_content:
        raise MonitoringSpecError(
            "monitoring specification has incomplete sections: "
            + ", ".join(missing_section_content)
        )

    command_lines = {line.strip() for line in text.splitlines()}
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise MonitoringSpecError(
            "monitoring specification is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_links = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_links:
        raise MonitoringSpecError(
            "monitoring specification is missing required links: "
            + ", ".join(missing_links)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse monitoring checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--monitoring-spec", type=Path, default=DEFAULT_MONITORING_SPEC)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the monitoring specification checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.monitoring_spec
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_monitoring_spec(repo_root, document_path.resolve())
    except MonitoringSpecError as exc:
        print(f"monitoring specification check failed: {exc}", file=sys.stderr)
        return 1

    print("monitoring specification is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
