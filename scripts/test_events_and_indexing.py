#!/usr/bin/env python3
"""Focused tests for the events/indexing documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_events_and_indexing.py")
SPEC = importlib.util.spec_from_file_location("check_events_and_indexing", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required events/indexing link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_events_and_indexing_doc() -> str:
    """Build the smallest events/indexing doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Events And Indexing

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.
Marketplace and indexer limits are named.

## Maturity And Scope

INT-005, CON-002, ONE-005, event reconstructability,
retained marketplace/indexer evidence,
fork_testnet_marketplace_indexer_evidence, and
live_marketplace_indexer_evidence are named.

## Source Of Truth

{links}

## Indexer Inputs

Event topic catalog, ABI checksums, release manifest, release checksums,
confirmation depth, reorg rollback, read-after-event, and full rescan are named.

## Log Identity And Ordering

chainId, contractAddress, blockHash, transactionHash, logIndex, and duplicate
logs must be idempotent are named.

## Indexed Entities

ReleaseArtifactSnapshot, ContractDeployment, ContractMetadataState,
| `Collection` |, | `Token` |, DropExecution, | `Auction` |, CreditAccount,
RandomnessRequest, MetadataState, AdminRole, PauseDomain, DependencyVersion,
CuratorRoot, ProvenanceManifest, one-of-one-provenance-manifest.json,
artifact-only, separate from `tokenURI`, separate from `contractURI()`, and
not included in `collectionFreezeManifestHash(collectionId)` are named.

## Event Processing Rules

Transfer, `Approval`, `ApprovalForAll`, MetadataUpdate, BatchMetadataUpdate,
ContractURIUpdated, CollectionCreated, CollectionFrozen, CollectionRandomizerUpdated,
DependencyVersionPinned, TokenBurned, DropAuthorizationConsumed,
DropAuthorizationCancelled, SignerEpochChanged, DropSignerChanged,
AuctionContractChanged, CollectionPhasesUpdated, MinterTokensMinted,
MinterAuctionMinted, MinterAuctionEndTimeUpdated, MinterContractReferenceUpdated,
StreamEventReconstructability, StreamMinter.updateContracts,
Invalid options remain no-ops, unchanged references do not emit,
Indexers can filter by `option`, `newContract`, and `admin`,
FixedPriceCreditCreated, FixedPriceCreditWithdrawn,
AuctionRegistered, AuctionCustodyConfirmed, AuctionStatusChanged,
AuctionExtended, AuctionCancelled, ClaimAuction, NoBidSettlementPending,
NoBidTokenClaimed, Participate, OutbidCreditCreated, BidderCreditWithdrawn,
AuctionProceedsCreditCreated, ProceedsCreditWithdrawn, Reward,
MerkleRootUpdated, CuratorCreditCreated, CuratorCreditWithdrawn,
RandomnessRequested, RandomnessFulfilled, RandomnessRequestMarkedStale,
RandomnessPostProcessingFailed, RandomnessPostProcessingRetried,
RandomnessPostProcessingRetryFailed, BurnedTokenRandomnessRecorded,
RequestFulfilled, GlobalAdminUpdated, FunctionAdminUpdated,
PauseGuardianUpdated, UnpauseAdminUpdated, SignerManagerUpdated,
SignerLifecycleTargetUpdated, PauseUpdated, EmergencyRecipientUpdated,
OwnershipTransferred, DependencyVersionCreated, DependencyVersionDeprecated,
and EmergencyWithdrawal are named.

## Read-After-Event Calls

isDropConsumed(dropId), isDropCancelled(dropId), tdhSigner(), signerEpoch(),
retrieveCollectionPhases(collectionId), getAuctionStatus(tokenId),
getAuctionEndTime(tokenId),
auctionRecords(tokenId), retrieveAuctionStatus(tokenId),
retrieveAuctionEndTime(tokenId), auctionHighestBid(tokenId),
auctionHighestBidder(tokenId), totalOwed(), totalReserved(), surplus(), and
emergencyWithdrawable() are named. contractURI(), contractURIHash(),
streamCore(), and adminsContract() are named.

## Collection And Token Reconstruction

Collection and token reconstruction are named.

## Drop And Signature Reconstruction

EIP-712 is encoding/signing only.

## Auction Reconstruction

Auction reconstruction is named.

## Credit And Payment Reconstruction

Forced ETH is named.

## Randomizer Reconstruction

Randomizer reconstruction is named.

## Metadata And Dependency Reconstruction

Metadata and dependency reconstruction are named.

## Governance And Pause Reconstruction

DROP_EXECUTION, AUCTION_BID, and AUCTION_SETTLEMENT are named.

## Confirmation And Reorg Policy

Confirmation and reorg policy are named.

## Full Rescan And Recovery

Full rescan and recovery are named.

## Event And Read Gaps

Event and read gaps are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when event behavior changes.
"""


class EventsAndIndexingTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed events/indexing guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete events/indexing doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_EVENTS_AND_INDEXING,
                minimal_events_and_indexing_doc(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default events/indexing doc path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-indexer/events.md")
            write_text(root / custom_path, minimal_events_and_indexing_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--events-and-indexing",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_events_and_indexing_doc().replace(
                "## Event And Read Gaps\n", ""
            )
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "missing required headings"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_events_and_indexing_doc().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "missing required content"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_events_and_indexing_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_events_and_indexing_doc()
            text = original.replace(
                "- [smart-contracts/StreamCore.sol](../../smart-contracts/StreamCore.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "missing required links"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamCore.sol").unlink()
            write_text(
                root / checker.DEFAULT_EVENTS_AND_INDEXING,
                minimal_events_and_indexing_doc(),
            )

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "linked targets are missing"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_events_and_indexing_doc().replace(
                "- [smart-contracts/StreamCore.sol](../../smart-contracts/StreamCore.sol)\n",
                (
                    "- [smart-contracts/StreamCore.sol]"
                    "(../../smart-contracts/StreamDrops.sol)\n"
                ),
            )
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "resolves to"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_events_and_indexing_doc().replace(
                "python scripts/check_events_and_indexing.py\n", ""
            )
            write_text(root / checker.DEFAULT_EVENTS_AND_INDEXING, text)

            with self.assertRaisesRegex(
                checker.EventsAndIndexingError, "missing required commands"
            ):
                checker.validate_events_and_indexing(
                    root, root / checker.DEFAULT_EVENTS_AND_INDEXING
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
