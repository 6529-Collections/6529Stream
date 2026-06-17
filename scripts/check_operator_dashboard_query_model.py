#!/usr/bin/env python3
"""Validate the operator dashboard query model."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_DASHBOARD_MODEL = Path("docs/operator-dashboard-query-model.md")

REQUIRED_HEADINGS = [
    (1, "Operator Dashboard Query Model"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Dashboard Data Contract"),
    (2, "Common Query Inputs"),
    (2, "Panel Catalog"),
    (2, "Environment And Release Snapshot Panel"),
    (2, "Admin And Governance Panel"),
    (2, "Signer And Drop Authorization Panel"),
    (2, "Fixed-Price Drop Execution Panel"),
    (2, "Auction Health Panel"),
    (2, "Randomizer Lifecycle Panel"),
    (2, "Payment And Credit Solvency Panel"),
    (2, "Metadata And Dependency State Panel"),
    (2, "Release Evidence And Blocker Panel"),
    (2, "Incident Drill And Handoff Panel"),
    (2, "Freshness And Reorg Model"),
    (2, "No-Secret Telemetry"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "GOV-010",
    "GOV-009",
    "pre-audit local baseline",
    "not production-ready",
    "not a security claim",
    "does not replace fork/testnet/live evidence",
    "maintained monitoring service",
    "public beta",
    "production",
    "No secrets",
    "private keys",
    "mnemonics",
    "RPC URLs",
    "API keys",
    "signer-service credentials",
    "raw signatures",
    "Safe signing secrets",
    "unreleased drop payloads",
    "chainId",
    "deploymentVersion",
    "releaseManifestHash",
    "addressBookHash",
    "contractAddress",
    "blockNumber",
    "blockHash",
    "transactionHash",
    "logIndex",
    "eventSignature",
    "normalizedLogIdentity",
    "freshnessStatus",
    "operatorActionBoundary",
    "confirmation depth",
    "reorg rollback",
    "read-after-event",
    "event topic catalog",
    "ABI checksum",
    "interface IDs",
    "release manifest",
    "checksum bundle",
    "bytecode proof",
    "risk register",
    "public-beta evidence",
    "GlobalAdminUpdated",
    "FunctionAdminUpdated",
    "PauseGuardianUpdated",
    "UnpauseAdminUpdated",
    "SignerManagerUpdated",
    "SignerLifecycleTargetUpdated",
    "PauseUpdated",
    "EmergencyRecipientUpdated",
    "DropSignerChanged",
    "SignerEpochChanged",
    "DropAuthorizationCancelled",
    "DropAuthorizationConsumed",
    "EIP-712",
    "ERC-1271",
    "consumed-state storage",
    "FixedPriceCreditCreated",
    "AuctionRegistered",
    "Participate",
    "OutbidCreditCreated",
    "AuctionProceedsCreditCreated",
    "RandomnessRequested",
    "RandomnessFulfilled",
    "RandomnessRequestMarkedStale",
    "RandomnessPostProcessingFailed",
    "CollectionFrozen",
    "PermanentURI",
    "ERC-4906",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "DependencyVersionPinned",
    "ContractURIUpdated",
    "poster credits",
    "bidder credits",
    "curator credits",
    "protocol surplus",
    "total owed",
    "emergencyWithdrawable",
    "failed withdrawal does not erase credit",
    "emergency withdrawal cannot withdraw owed funds",
    "incident handoff",
]

REQUIRED_SECTION_PHRASES = {
    "Panel Catalog": [
        "Environment And Release Snapshot",
        "Admin And Governance",
        "Signer And Drop Authorization",
        "Fixed-Price Drop Execution",
        "Auction Health",
        "Randomizer Lifecycle",
        "Payment And Credit Solvency",
        "Metadata And Dependency State",
        "Release Evidence And Blockers",
        "Incident Drill And Handoff",
    ],
    "Admin And Governance Panel": [
        "retrieveGlobalAdmin",
        "retrieveFunctionAdmin",
        "isPaused(domain)",
        "Critical",
        "prepare Safe or multisig ceremony",
    ],
    "Signer And Drop Authorization Panel": [
        "tdhSigner()",
        "signerEpoch()",
        "EIP-712 domain",
        "ERC-1271 support status",
        "consumed-state storage",
    ],
    "Auction Health Panel": [
        "None",
        "Created",
        "Active",
        "EndedNoBid",
        "EndedWithBid",
        "SettledNoBid",
        "SettledWithBid",
        "Cancelled",
        "unknown token custody",
    ],
    "Randomizer Lifecycle Panel": [
        "request ID",
        "collection ID",
        "token ID",
        "randomizer epoch",
        "duplicate callback",
    ],
    "Payment And Credit Solvency Panel": [
        "poster credits",
        "bidder credits",
        "curator credits",
        "protocol surplus",
        "contract balance covers owed balances",
    ],
    "Release Evidence And Blocker Panel": [
        "public-beta evidence",
        "risk-register",
        "release evidence issue",
        "signed tag",
        "explorer verification",
    ],
}

REQUIRED_COMMANDS = [
    "python scripts/test_operator_dashboard_query_model.py",
    "python scripts/check_operator_dashboard_query_model.py",
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
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "make operator-dashboard-query-model-check",
    "make check",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "README.md",
    "docs/monitoring.md",
    "docs/release-readiness.md",
    "docs/incident-response.md",
    "docs/non-local-release-evidence.md",
    "docs/integrations/README.md",
    "docs/integrations/operator-admin-ui.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/withdrawals-and-credits.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/metadata-rendering.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/randomizer-operations.md",
    "docs/dependency-operations.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/bytecode-release-proof.json",
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
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/StreamRandomizerLifecycle.sol",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/DependencyRegistry.sol",
    "test/StreamEventReconstructability.t.sol",
    "test/StreamPauseControls.t.sol",
    "test/StreamSignerAdmin.t.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamRandomizerLifecycle.t.sol",
    "test/StreamPaymentsInvariant.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCED_CODE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


class DashboardQueryModelError(ValueError):
    """Raised when the operator dashboard query model is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise DashboardQueryModelError(
            f"linked path escapes repository: {path}"
        ) from exc


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
        raise DashboardQueryModelError(
            "operator dashboard query model links to missing files: "
            + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases not found after whitespace normalization."""
    normalized_text = re.sub(r"\s+", " ", text).lower()
    return [
        phrase
        for phrase in phrases
        if re.sub(r"\s+", " ", phrase).lower() not in normalized_text
    ]


def markdown_section(text: str, heading: str) -> str:
    """Return the body for a level-two Markdown section."""
    pattern = re.compile(
        rf"^## {re.escape(heading)}\s*$([\s\S]*?)(?=^## |\Z)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    return "" if match is None else match.group(1)


def fenced_command_lines(text: str) -> set[str]:
    """Return non-empty lines presented inside fenced Markdown code blocks."""
    command_lines = set()
    for match in FENCED_CODE_RE.finditer(text):
        for line in match.group(1).splitlines():
            stripped = line.strip()
            if stripped:
                command_lines.add(stripped)
    return command_lines


def validate_dashboard_query_model(repo_root: Path, document_path: Path) -> None:
    """Validate the operator dashboard query model."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise DashboardQueryModelError(
            f"missing operator dashboard query model: {relative}"
        )

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_required_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_required_headings:
        raise DashboardQueryModelError(
            "operator dashboard query model is missing required headings: "
            + ", ".join(missing_required_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise DashboardQueryModelError(
            "operator dashboard query model is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_section_content = []
    for heading, phrases in REQUIRED_SECTION_PHRASES.items():
        section = markdown_section(text, heading)
        for phrase in missing_phrases(section, phrases):
            missing_section_content.append(f"{heading}: {phrase}")
    if missing_section_content:
        raise DashboardQueryModelError(
            "operator dashboard query model has incomplete sections: "
            + ", ".join(missing_section_content)
        )

    command_lines = fenced_command_lines(markdown_section(text, "Validation Commands"))
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise DashboardQueryModelError(
            "operator dashboard query model is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_links = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_links:
        raise DashboardQueryModelError(
            "operator dashboard query model is missing required links: "
            + ", ".join(missing_links)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse dashboard query model checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--dashboard-model", type=Path, default=DEFAULT_DASHBOARD_MODEL)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the dashboard query model checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.dashboard_model
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_dashboard_query_model(repo_root, document_path.resolve())
    except DashboardQueryModelError as exc:
        print(f"operator dashboard query model check failed: {exc}", file=sys.stderr)
        return 1

    print("operator dashboard query model is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
