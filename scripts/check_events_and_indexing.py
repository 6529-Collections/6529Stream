#!/usr/bin/env python3
"""Validate the event and indexer reconstruction documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_EVENTS_AND_INDEXING = Path("docs/integrations/events-and-indexing.md")

REQUIRED_HEADINGS = [
    (1, "Events And Indexing"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Indexer Inputs"),
    (2, "Log Identity And Ordering"),
    (2, "Indexed Entities"),
    (2, "Event Processing Rules"),
    (2, "Read-After-Event Calls"),
    (2, "Collection And Token Reconstruction"),
    (2, "Drop And Signature Reconstruction"),
    (2, "Auction Reconstruction"),
    (2, "Credit And Payment Reconstruction"),
    (2, "Randomizer Reconstruction"),
    (2, "Metadata And Dependency Reconstruction"),
    (2, "Governance And Pause Reconstruction"),
    (2, "Confirmation And Reorg Policy"),
    (2, "Full Rescan And Recovery"),
    (2, "Event And Read Gaps"),
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
    "marketplace",
    "indexer",
    "event topic catalog",
    "ABI checksums",
    "release manifest",
    "release checksums",
    "confirmation depth",
    "reorg rollback",
    "read-after-event",
    "full rescan",
    "duplicate logs must be idempotent",
    "event reconstructability",
    "chainId",
    "contractAddress",
    "blockHash",
    "transactionHash",
    "logIndex",
    "ReleaseArtifactSnapshot",
    "ContractDeployment",
    "ContractMetadataState",
    "| `Collection` |",
    "| `Token` |",
    "DropExecution",
    "| `Auction` |",
    "CreditAccount",
    "RandomnessRequest",
    "MetadataState",
    "AdminRole",
    "PauseDomain",
    "DependencyVersion",
    "CuratorRoot",
    "ProvenanceManifest",
    "one-of-one-provenance-manifest.json",
    "artifact-only",
    "separate from `tokenURI`",
    "separate from `contractURI()`",
    "not included in `collectionFreezeManifestHash(collectionId)`",
    "Transfer",
    "`Approval`",
    "`ApprovalForAll`",
    "MetadataUpdate",
    "BatchMetadataUpdate",
    "ContractURIUpdated",
    "CollectionCreated",
    "CollectionFrozen",
    "CollectionRandomizerUpdated",
    "DependencyVersionPinned",
    "TokenBurned",
    "DropAuthorizationConsumed",
    "DropAuthorizationCancelled",
    "SignerEpochChanged",
    "DropSignerChanged",
    "AuctionContractChanged",
    "CollectionPhasesUpdated",
    "MinterTokensMinted",
    "MinterAuctionMinted",
    "MinterAuctionEndTimeUpdated",
    "MinterContractReferenceUpdated",
    "StreamEventReconstructability",
    "StreamMinter.updateContracts",
    "Indexers can filter by `option`, `newContract`, and `admin`",
    "Invalid options remain no-ops",
    "unchanged references do not emit",
    "FixedPriceCreditCreated",
    "FixedPriceCreditWithdrawn",
    "AuctionRegistered",
    "AuctionCustodyConfirmed",
    "AuctionStatusChanged",
    "AuctionExtended",
    "AuctionCancelled",
    "ClaimAuction",
    "NoBidSettlementPending",
    "NoBidTokenClaimed",
    "Participate",
    "OutbidCreditCreated",
    "BidderCreditWithdrawn",
    "AuctionProceedsCreditCreated",
    "ProceedsCreditWithdrawn",
    "Reward",
    "MerkleRootUpdated",
    "CuratorCreditCreated",
    "CuratorCreditWithdrawn",
    "RandomnessRequested",
    "RandomnessFulfilled",
    "RandomnessRequestMarkedStale",
    "RandomnessPostProcessingFailed",
    "RandomnessPostProcessingRetried",
    "RandomnessPostProcessingRetryFailed",
    "BurnedTokenRandomnessRecorded",
    "RequestFulfilled",
    "GlobalAdminUpdated",
    "FunctionAdminUpdated",
    "PauseGuardianUpdated",
    "UnpauseAdminUpdated",
    "SignerManagerUpdated",
    "SignerLifecycleTargetUpdated",
    "PauseUpdated",
    "EmergencyRecipientUpdated",
    "OwnershipTransferred",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "EmergencyWithdrawal",
    "contractURI()",
    "contractURIHash()",
    "streamCore()",
    "adminsContract()",
    "DROP_EXECUTION",
    "AUCTION_BID",
    "AUCTION_SETTLEMENT",
    "isDropConsumed(dropId)",
    "isDropCancelled(dropId)",
    "tdhSigner()",
    "signerEpoch()",
    "retrieveCollectionPhases(collectionId)",
    "getAuctionStatus(tokenId)",
    "getAuctionEndTime(tokenId)",
    "auctionRecords(tokenId)",
    "retrieveAuctionStatus(tokenId)",
    "retrieveAuctionEndTime(tokenId)",
    "auctionHighestBid(tokenId)",
    "auctionHighestBidder(tokenId)",
    "totalOwed()",
    "totalReserved()",
    "surplus()",
    "emergencyWithdrawable()",
    "EIP-712 is encoding/signing only",
    "forced ETH",
    "CON-002",
    "INT-005",
    "ONE-005",
    "retained marketplace/indexer evidence",
    "fork_testnet_marketplace_indexer_evidence",
    "live_marketplace_indexer_evidence",
    "INT-015",
    "TypeScript event decoding and indexer ingestion snippets",
    "event topic catalog loading",
    "topic0 dispatch",
    "normalized log identity",
    "idempotent ingestion",
    "read-after-event queue",
]

REQUIRED_COMMANDS = [
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_typescript_event_decoding_indexer.py",
    "python scripts/check_typescript_event_decoding_indexer.py",
    "python scripts/test_one_of_one_provenance_manifest.py",
    "python scripts/check_one_of_one_provenance_manifest.py",
    "python scripts/generate_one_of_one_provenance_manifest.py --check",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_marketplace_indexer_evidence.py",
    "python scripts/check_marketplace_indexer_evidence.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_bytecode_release_proof.py",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "forge test --match-path test/StreamEventReconstructability.t.sol",
    "forge test --match-path test/StreamMinterEvents.t.sol",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/marketplace-indexer-evidence.md",
    "docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md",
    "docs/metadata.md",
    "docs/provenance-manifests.md",
    "docs/release-policy.md",
    "docs/drop-authorization-signing.md",
    "docs/auction-custody.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/one-of-one-provenance-manifest.json",
    "release-artifacts/schema/one-of-one-provenance-manifest.schema.json",
    "release-artifacts/provenance/one-of-one-provenance-template.provenance.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/examples/anvil-6529stream-v0.1.0-001.json",
    "deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/StreamContractMetadata.sol",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/StreamAdmins.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/StreamRandomizerLifecycle.sol",
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/DependencyRegistry.sol",
    "smart-contracts/IERC4906.sol",
    "smart-contracts/IERC7572.sol",
    "test/StreamMetadataEvents.t.sol",
    "test/StreamContractMetadata.t.sol",
    "test/StreamDropsEIP712.t.sol",
    "test/StreamDropsERC1271.t.sol",
    "test/StreamAuctionCustody.t.sol",
    "test/StreamAuctionPayments.t.sol",
    "test/StreamEventReconstructability.t.sol",
    "test/StreamMinterEvents.t.sol",
    "test/StreamCuratorsPool.t.sol",
    "test/StreamAdmins.t.sol",
    "test/StreamPauseControls.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class EventsAndIndexingError(ValueError):
    """Raised when the events/indexing docs are missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise EventsAndIndexingError(f"linked path escapes repository: {path}") from exc


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


def label_looks_like_repo_path(label: str) -> bool:
    """Return true when a link label should match its resolved repo path."""
    normalized = label.strip().strip("`")
    suffixes = (
        ".md",
        ".json",
        ".sol",
        ".py",
        ".sh",
        ".ps1",
        ".yml",
        ".yaml",
        ".toml",
    )
    return "/" in normalized or "\\" in normalized or normalized.endswith(suffixes)


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        label = match.group(1).strip().strip("`")
        target = normalized_link_target(match.group(2))
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
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != relative:
            raise EventsAndIndexingError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)

    if missing:
        raise EventsAndIndexingError(
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


def validate_events_and_indexing(repo_root: Path, document_path: Path) -> None:
    """Validate the events/indexing documentation."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise EventsAndIndexingError(f"missing events and indexing doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise EventsAndIndexingError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise EventsAndIndexingError(
            "events and indexing doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise EventsAndIndexingError(
            "events and indexing doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise EventsAndIndexingError(
            "events and indexing doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse events/indexing checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--events-and-indexing",
        type=Path,
        default=DEFAULT_EVENTS_AND_INDEXING,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the events/indexing checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.events_and_indexing
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_events_and_indexing(repo_root, document_path.resolve())
    except EventsAndIndexingError as exc:
        print(f"events and indexing check failed: {exc}", file=sys.stderr)
        return 1

    print("events and indexing doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
