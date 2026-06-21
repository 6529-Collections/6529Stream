#!/usr/bin/env python3
"""Focused tests for the contract-flow documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_contract_flows.py")
SPEC = importlib.util.spec_from_file_location("check_contract_flows", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required contract-flow link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_contract_flows_doc() -> str:
    """Build the smallest contract-flow doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Contract Flows

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.

## Maturity And Scope

The fixed-price mint flow is documented for a backend signing service and no private keys.

## Fixed-Price Mint Overview

Fixed-price mint, DropAuthorization, mintDrop, saleMode = 1, EIP-712, ERC-1271,
domainSeparator, deriveDropId, tokenDataHash, signerEpoch, consumedDropIds,
cancelledDropIds, DropAuthorizationConsumed, FixedPriceCreditCreated,
FixedPriceCreditWithdrawn, withdrawFixedPriceCreditTo, fixedPricePosterCredits,
fixedPriceProtocolCredits, fixedPriceCuratorReserveCredits, totalFixedPriceOwed,
totalReserved, surplus, DROP_EXECUTION, wrong chain, wrong domain, expired,
cancelled, consumed, replay, wrong signer, zero recipient, insufficient payment,
eth_call simulation, StreamMinter, StreamCore, and failed withdrawals preserve credit.
Payment ratios use posterBps, protocolBps, curatorBps, curatorBps = 0,
msg.value * posterBps / 10000, msg.value * curatorBps / 10000,
and msg.value - posterCredit - curatorReserveCredit.
Split reads and operator release use proceedsSplitFor and
releaseFixedPriceCuratorReserveCredit.
Ratio tests are testFixedPriceMintCreditsProceedsWithoutPushPayouts,
testFixedPriceOddWeiRemainderAccruesToProtocolCredit, and
testOneWeiFixedPriceRemainderCreditsOnlyProtocol,
testFixedPriceContractSplitCanDisableCuratorReserve, and
testFixedPriceCollectionAndTokenSplitsOverrideContractDefault.

## Source Of Truth

{links}

## Artifact Inputs

Artifacts are named.

## Preflight Reads

Reads are named.

## Authorization Payload

Payload fields are named.

## Signing Paths

Signing paths are named.

## Submit Transaction

Submission is named.

## Events And Indexing

Events are named.

## Credits And Withdrawals

Credits are named.

## Failure States

Failures are named.

## Frontend State Machine

UI states are named.

## Backend Signing Service Boundary

Backend signing service duties are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when flow behavior changes.
"""


class ContractFlowsTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed contract-flow doc satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete contract-flow doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, minimal_contract_flows_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default contract-flow doc path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-contract-flows/flow.md")
            write_text(root / custom_path, minimal_contract_flows_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    ["--repo-root", str(root), "--contract-flows", str(custom_path)]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_contract_flows_doc().replace("## Preflight Reads\n", "")
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, text)

            with self.assertRaisesRegex(checker.ContractFlowsError, "missing required headings"):
                checker.validate_contract_flows(root, root / checker.DEFAULT_CONTRACT_FLOWS)

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing flow and maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_contract_flows_doc().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, text)

            with self.assertRaisesRegex(checker.ContractFlowsError, "missing required content"):
                checker.validate_contract_flows(root, root / checker.DEFAULT_CONTRACT_FLOWS)

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_contract_flows_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_contract_flows_doc()
            text = original.replace(
                "- [smart-contracts/StreamDrops.sol](../../smart-contracts/StreamDrops.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, text)

            with self.assertRaisesRegex(checker.ContractFlowsError, "missing required links"):
                checker.validate_contract_flows(root, root / checker.DEFAULT_CONTRACT_FLOWS)

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamDrops.sol").unlink()
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, minimal_contract_flows_doc())

            with self.assertRaisesRegex(checker.ContractFlowsError, "linked targets are missing"):
                checker.validate_contract_flows(root, root / checker.DEFAULT_CONTRACT_FLOWS)

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_contract_flows_doc().replace(
                "python scripts/check_contract_flows.py\n", ""
            )
            write_text(root / checker.DEFAULT_CONTRACT_FLOWS, text)

            with self.assertRaisesRegex(checker.ContractFlowsError, "missing required commands"):
                checker.validate_contract_flows(root, root / checker.DEFAULT_CONTRACT_FLOWS)


if __name__ == "__main__":
    unittest.main(verbosity=2)
