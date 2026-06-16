#!/usr/bin/env python3
"""Focused tests for the auction-flow documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_auction_flows.py")
SPEC = importlib.util.spec_from_file_location("check_auction_flows", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required auction-flow link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_auction_flows_doc() -> str:
    """Build the smallest auction-flow doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Auction Flows

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.

## Maturity And Scope

The auction drops flow is documented for React, mobile, Electron, indexer, and
backend signing service teams.

## Auction Mint Overview

DropAuthorization, mintDrop, mintAndAuction, registerAuction,
participateToAuction, claimAuction, claimNoBidAuctionToken, cancelAuction,
saleMode = 2, recipient = address(0), payer = address(0), price = 0,
msg.value == 0, EIP-712, ERC-1271, domainSeparator, deriveDropId,
consumedDropIds, cancelledDropIds, and signer epoch are named.

## Source Of Truth

{links}

## Artifact Inputs

Artifacts are named.

## Preflight Reads

auctionHighestBid, auctionHighestBidder, auctionBidderCredits,
auctionPosterCredits, auctionProtocolCredits, auctionCuratorCredits,
totalAuctionBidEscrow, totalBidderOwed, totalProceedsOwed, totalOwed,
totalReserved, surplus, emergencyWithdrawable, StreamAuctions.retrieveAuctionEndTime,
and StreamMinter.getAuctionEndTime are named.

## Authorization Payload

Payload fields are named.

## Submit Auction Drop

Submission is named.

## Auction State Machine

None, Created, Active, EndedNoBid, EndedWithBid, SettledNoBid,
SettledWithBid, and Cancelled are named. block.timestamp > endTime is named.

## Bidding

AUCTION_BID, AuctionBid, Participate, OutbidCreditCreated, AuctionExtended,
minimumNextBid, and previous bidder refund becomes withdrawable credit are named.

## Settlement

AUCTION_SETTLEMENT, AuctionSettlement, AuctionProceedsCreditCreated,
ClaimAuction, highestBid / 2, highestBid / 4, and
highestBid - posterCredit - protocolCredit are named.

## No-Bid Claims

NoBidSettlementPending and NoBidTokenClaimed are named.

## Cancellation

AuctionCancelled is named.

## Credits And Withdrawals

BidderCreditWithdrawn, ProceedsCreditWithdrawn, EmergencyWithdrawal,
failed bidder withdrawal must not erase, failed proceeds withdrawal must not erase,
and emergency withdrawal cannot withdraw owed are named.

## Events And Indexing

AuctionRegistered, AuctionCustodyConfirmed, AuctionStatusChanged, event/read gaps,
AuctionExtended, MinterAuctionMinted, MinterAuctionEndTimeUpdated, CON-003, and
INT-005 are named.

## Pause And Emergency Boundaries

Pause boundaries are named.

## Failure States

Failure states are named.

## Frontend State Machine

Frontend states are named.

## Indexer Reconstruction

Indexer reconstruction is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when flow behavior changes.
"""


class AuctionFlowsTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed auction-flow doc satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete auction-flow doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, minimal_auction_flows_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default auction-flow doc path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-auction-flows/flow.md")
            write_text(root / custom_path, minimal_auction_flows_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--auction-flows", str(custom_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_auction_flows_doc().replace("## Bidding\n", "")
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, text)

            with self.assertRaisesRegex(checker.AuctionFlowsError, "missing required headings"):
                checker.validate_auction_flows(root, root / checker.DEFAULT_AUCTION_FLOWS)

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing auction maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_auction_flows_doc().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, text)

            with self.assertRaisesRegex(checker.AuctionFlowsError, "missing required content"):
                checker.validate_auction_flows(root, root / checker.DEFAULT_AUCTION_FLOWS)

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_auction_flows_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_auction_flows_doc()
            text = original.replace(
                "- [smart-contracts/AuctionContract.sol](../../smart-contracts/AuctionContract.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, text)

            with self.assertRaisesRegex(checker.AuctionFlowsError, "missing required links"):
                checker.validate_auction_flows(root, root / checker.DEFAULT_AUCTION_FLOWS)

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/AuctionContract.sol").unlink()
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, minimal_auction_flows_doc())

            with self.assertRaisesRegex(checker.AuctionFlowsError, "linked targets are missing"):
                checker.validate_auction_flows(root, root / checker.DEFAULT_AUCTION_FLOWS)

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_auction_flows_doc().replace(
                "python scripts/check_auction_flows.py\n", ""
            )
            write_text(root / checker.DEFAULT_AUCTION_FLOWS, text)

            with self.assertRaisesRegex(checker.AuctionFlowsError, "missing required commands"):
                checker.validate_auction_flows(root, root / checker.DEFAULT_AUCTION_FLOWS)


if __name__ == "__main__":
    unittest.main(verbosity=2)
