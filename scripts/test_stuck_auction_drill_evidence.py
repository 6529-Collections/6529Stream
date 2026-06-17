#!/usr/bin/env python3
"""Focused tests for stuck-auction drill evidence validation."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_stuck_auction_drill_evidence.py")
SPEC = importlib.util.spec_from_file_location(
    "check_stuck_auction_drill_evidence", SCRIPT_PATH
)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", newline="\n")


def template_text() -> str:
    return Path(
        "release-artifacts/evidence/incident-drills/"
        "stuck-auction-drill-retained-artifact-template.md"
    ).read_text(encoding="utf-8")


def reviewed_text() -> str:
    text = template_text()
    replacements = {
        "> Template only. This file is not completion evidence.\n\n": "",
        "Review status: `template`": "Review status: `reviewed`",
        "Readiness claim: `blocked`": "Readiness claim: `complete`",
        "Environment: `template`": "Environment: `testnet`",
        "Chain ID: `TBD`": "Chain ID: `11155111`",
        "Release commit: `TBD`": "Release commit: `0123456789abcdef0123456789abcdef01234567`",
        "Deployment version: `TBD`": "Deployment version: `sepolia-001`",
        "Drill bundle reference: `TBD`": "Drill bundle reference: `incident-drills/stuck-auction-sepolia-001.md`",
        "Auction contract: `TBD`": "Auction contract: `0x0000000000000000000000000000000000003001`",
        "Token ID: `TBD`": "Token ID: `1001`",
        "Collection ID: `TBD`": "Collection ID: `42`",
        "Drop ID: `TBD`": "Drop ID: `0x1111111111111111111111111111111111111111111111111111111111111111`",
        "Auction path: `TBD`": "Auction path: `with_bid`",
        "Stuck condition: `TBD`": "Stuck condition: `settlement_paused`",
        "Poster: `TBD`": "Poster: `0x0000000000000000000000000000000000003002`",
        "Highest bidder: `TBD`": "Highest bidder: `0x0000000000000000000000000000000000003003`",
        "Highest bid wei: `TBD`": "Highest bid wei: `1000000000000000000`",
        "Starting auction status: `TBD`": "Starting auction status: `EndedWithBid`",
        "Ending auction status: `TBD`": "Ending auction status: `SettledWithBid`",
        "Bid pause evidence: `TBD`": "Bid pause evidence: `AUCTION_BID pause tx and revert retained`",
        "Settlement pause evidence: `TBD`": "Settlement pause evidence: `AUCTION_SETTLEMENT pause tx and revert retained`",
        "Custody snapshot evidence: `TBD`": "Custody snapshot evidence: `ownerOf token before and after retained`",
        "No-bid claimant evidence: `TBD`": "No-bid claimant evidence: `not applicable for with_bid path`",
        "Credit balance snapshot evidence: `TBD`": "Credit balance snapshot evidence: `bidder/proceeds credits retained`",
        "Emergency surplus boundary evidence: `TBD`": "Emergency surplus boundary evidence: `emergencyWithdrawable cannot withdraw owed retained`",
        "Settlement unpause evidence: `TBD`": "Settlement unpause evidence: `unpause tx retained`",
        "Terminal auction outcome evidence: `TBD`": "Terminal auction outcome evidence: `ClaimAuction and Transfer retained`",
        "Bidder credit withdrawal evidence: `TBD`": "Bidder credit withdrawal evidence: `outbid bidder withdrawal retained`",
        "Proceeds withdrawal evidence: `TBD`": "Proceeds withdrawal evidence: `poster/protocol/curator withdrawal retained`",
        "Settlement idempotency evidence: `TBD`": "Settlement idempotency evidence: `repeat settlement revert retained`",
        "Post-recovery owed balance evidence: `TBD`": "Post-recovery owed balance evidence: `totalOwed post-state retained`",
        "Operator dashboard confirmation: `TBD`": "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
        "Monitoring alert reference: `TBD`": "Monitoring alert reference: `alert SIM-AUCTION-001 retained`",
        "Incident response decision log: `TBD`": "Incident response decision log: `decision-log.md`",
        "Public communication status: `TBD`": "Public communication status: `no public user impact`",
        "Follow-up issue links: `TBD`": "Follow-up issue links: `https://github.com/6529-Collections/6529Stream/issues/512`",
        "Command transcript bundle: `TBD`": "Command transcript bundle: `commands.md`",
        "Event or state snapshot bundle: `TBD`": "Event or state snapshot bundle: `snapshots.md`",
        "Auction flow spec evidence: `TBD`": "Auction flow spec evidence: `docs/integrations/auction-flows.md reviewed`",
        "Admin ceremony evidence: `TBD`": "Admin ceremony evidence: `admin-ceremony.json`",
        "Release manifest/checksum digests: `TBD`": "Release manifest/checksum digests: `sha256 bundle retained`",
        "Operator: `TBD`": "Operator: `ops`",
        "Reviewer: `TBD`": "Reviewer: `reviewer`",
        "Review decision: `template`": "Review decision: `reviewed`",
        "No secrets retained: `TBD`": "No secrets retained: `yes`",
        "Private RPC URLs removed: `TBD`": "Private RPC URLs removed: `yes`",
        "Private keys removed: `TBD`": "Private keys removed: `yes`",
        "Signer-service secrets removed: `TBD`": "Signer-service secrets removed: `yes`",
        "Raw signatures removed: `TBD`": "Raw signatures removed: `yes`",
        "Unreleased drop payloads removed: `TBD`": "Unreleased drop payloads removed: `yes`",
        "Private collector data removed: `TBD`": "Private collector data removed: `yes`",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text


class StuckAuctionDrillEvidenceTests(unittest.TestCase):
    def test_committed_template_passes(self) -> None:
        for path in checker.DEFAULT_EVIDENCE:
            checker.validate_evidence(path)

    def test_reviewed_artifact_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(path, reviewed_text())

            checker.validate_evidence(path)

    def test_wrong_requirement_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    checker.REQUIREMENT_ID, "incident_drill_evidence", 1
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Requirement ID"
            ):
                checker.validate_evidence(path)

    def test_reviewed_placeholder_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Incident response decision log: `decision-log.md`",
                    "Incident response decision log: `TBD`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "must be replaced"
            ):
                checker.validate_evidence(path)

    def test_pending_review_complete_readiness_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            text = reviewed_text().replace(
                "Review status: `reviewed`", "Review status: `pending_review`"
            )
            text = text.replace(
                "Review decision: `reviewed`", "Review decision: `pending_review`"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Readiness claim"
            ):
                checker.validate_evidence(path)

    def test_reviewed_bad_chain_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace("Chain ID: `11155111`", "Chain ID: `sepolia`"),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Chain ID must be a uint"
            ):
                checker.validate_evidence(path)

    def test_drop_id_must_be_bytes32(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Drop ID: `0x1111111111111111111111111111111111111111111111111111111111111111`",
                    "Drop ID: `0x1234`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Drop ID"
            ):
                checker.validate_evidence(path)

    def test_git_sha256_release_commit_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Release commit: `0123456789abcdef0123456789abcdef01234567`",
                    (
                        "Release commit: "
                        "`0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef`"
                    ),
                ),
            )

            checker.validate_evidence(path)

    def test_stuck_condition_must_match_auction_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Stuck condition: `settlement_paused`",
                    "Stuck condition: `no_bid_pending`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Stuck condition"
            ):
                checker.validate_evidence(path)

    def test_auction_path_controls_terminal_status(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Ending auction status: `SettledWithBid`",
                    "Ending auction status: `Cancelled`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Ending auction status"
            ):
                checker.validate_evidence(path)

    def test_with_bid_requires_nonzero_bidder_and_bid(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            text = reviewed_text().replace(
                "Highest bid wei: `1000000000000000000`", "Highest bid wei: `0`"
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "non-zero highest bid"
            ):
                checker.validate_evidence(path)

    def test_no_bid_requires_zero_bidder_and_bid(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            text = reviewed_text()
            text = text.replace("Auction path: `with_bid`", "Auction path: `no_bid`")
            text = text.replace(
                "Starting auction status: `EndedWithBid`",
                "Starting auction status: `EndedNoBid`",
            )
            text = text.replace(
                "Ending auction status: `SettledWithBid`",
                "Ending auction status: `SettledNoBid`",
            )
            write_text(path, text)

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "zero highest bid"
            ):
                checker.validate_evidence(path)

    def test_no_bid_path_with_zero_bidder_and_bid_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            text = reviewed_text()
            text = text.replace("Auction path: `with_bid`", "Auction path: `no_bid`")
            text = text.replace(
                "Starting auction status: `EndedWithBid`",
                "Starting auction status: `EndedNoBid`",
            )
            text = text.replace(
                "Ending auction status: `SettledWithBid`",
                "Ending auction status: `SettledNoBid`",
            )
            text = text.replace(
                "Highest bidder: `0x0000000000000000000000000000000000003003`",
                "Highest bidder: `0x0000000000000000000000000000000000000000`",
            )
            text = text.replace(
                "Highest bid wei: `1000000000000000000`", "Highest bid wei: `0`"
            )
            write_text(path, text)

            checker.validate_evidence(path)

    def test_redaction_no_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Private keys removed: `yes`", "Private keys removed: `no`"
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "Private keys removed"
            ):
                checker.validate_evidence(path)

    def test_secret_like_values_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Command transcript bundle: `commands.md`",
                    "Command transcript bundle: `api_key=do-not-commit`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "secret-like"
            ):
                checker.validate_evidence(path)

    def test_credentialed_urls_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
                    "Operator dashboard confirmation: `https://operator:password@example.invalid/panel`",
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "credentialed URL"
            ):
                checker.validate_evidence(path)

    def test_redacted_urls_pass(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "Operator dashboard confirmation: `dashboard panel screenshot hash retained`",
                    "Operator dashboard confirmation: `https://<redacted>@example.invalid/panel`",
                ),
            )

            checker.validate_evidence(path)

    def test_missing_validation_command_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            path = Path(temp_dir) / "stuck-auction.md"
            write_text(
                path,
                reviewed_text().replace(
                    "python scripts/check_release_readiness.py", ""
                ),
            )

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError,
                "missing required validation command",
            ):
                checker.validate_evidence(path)

    def test_source_requirement_missing_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            path = root / "stuck-auction.md"
            write_text(path, reviewed_text())
            for source_path, snippets in checker.SOURCE_REQUIREMENTS.items():
                body = "\n".join(snippets)
                if source_path.as_posix().endswith("AuctionContract.sol"):
                    body = body.replace("function emergencyWithdrawable", "")
                write_text(root / source_path, body)

            with self.assertRaisesRegex(
                checker.StuckAuctionDrillEvidenceError, "source snippet"
            ):
                checker.validate_evidence(path, repo_root=root)


if __name__ == "__main__":
    unittest.main(verbosity=2)
