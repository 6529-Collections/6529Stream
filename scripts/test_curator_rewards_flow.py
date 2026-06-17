#!/usr/bin/env python3
"""Focused tests for the curator rewards flow checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_curator_rewards_flow.py")
SPEC = importlib.util.spec_from_file_location("check_curator_rewards_flow", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_doc() -> str:
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Curator Rewards

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.

## Maturity And Scope

StreamCuratorsPool curator rewards use a pull-payment model.

## Curator Reward Overview

claimRewards, withdrawCuratorCreditTo, setMerkleRoot, setMultipleMerkleRoots,
collectionMerkleRoot, collectionMerkleRootEpoch, rewardsClaimPerAddress,
rewardsPerAddress, curatorCredits, totalCuratorOwed, totalOwed, surplus,
emergencyWithdrawable, delegator, delegate, CuratorCreditCreated,
CuratorCreditWithdrawn, MerkleRootUpdated, Reward, EmergencyWithdrawal,
failed withdrawal, credit is preserved, emergency withdrawal is surplus-only,
totalReserved()` returns zero, reward-service proof, duplicate leaves,
wrong claimant, wrong collection, wrong amount, stale root epoch, and double
claims are named.

## Source Of Truth

{links}

## Artifact Inputs

Artifacts are named.

## Root And Leaf Model

CURATOR_REWARD_LEAF_DOMAIN, abi.encode, block.chainid, address(this), and
rootEpoch are named. Do not use `abi.encodePacked`.

## Claim Preflight Reads

Reads are named.

## Claim Transaction

Claim transaction is named.

## Delegated Claims

0x8888888888888888888888888888888888888888 and curator reward use case: `1`
are named.

## Credits And Withdrawals

Credits and withdrawals are named.

## Events And Indexing

Events are named.

## Failure States

Failures are named.

## Frontend State Machine

UI states are named.

## Operator And Admin Boundaries

Operator boundaries are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when behavior changes.
"""


class CuratorRewardsFlowTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        repo_root = Path(__file__).resolve().parents[1]
        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])
        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])
            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-curator/rewards.md")
            write_text(root / custom_path, minimal_doc())
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root), "--doc", str(custom_path)])
            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace("## Root And Leaf Model\n", "")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.CuratorRewardsFlowError, "missing required headings"
            ):
                checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_required_phrase(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.CuratorRewardsFlowError, "missing required content"
            ):
                checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_DOC, text)
            checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_required_link(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_doc()
            text = original.replace(
                "- [smart-contracts/StreamCuratorsPool.sol](../../smart-contracts/StreamCuratorsPool.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.CuratorRewardsFlowError, "missing required links"
            ):
                checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_linked_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamCuratorsPool.sol").unlink()
            write_text(root / checker.DEFAULT_DOC, minimal_doc())
            with self.assertRaisesRegex(
                checker.CuratorRewardsFlowError, "linked targets are missing"
            ):
                checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)

    def test_rejects_missing_required_command(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_doc().replace("python scripts/check_curator_rewards_flow.py\n", "")
            write_text(root / checker.DEFAULT_DOC, text)
            with self.assertRaisesRegex(
                checker.CuratorRewardsFlowError, "missing required commands"
            ):
                checker.validate_curator_rewards_flow(root, root / checker.DEFAULT_DOC)


if __name__ == "__main__":
    unittest.main(verbosity=2)
