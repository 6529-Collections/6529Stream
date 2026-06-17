#!/usr/bin/env python3
"""Focused tests for the protocol monitoring specification checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_monitoring_spec.py")
SPEC = importlib.util.spec_from_file_location("check_monitoring_spec", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required guide link."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_monitoring_spec() -> str:
    """Build the smallest monitoring specification accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Protocol Monitoring Specification

This GOV-009 pre-audit local baseline is not production-ready and not a
security claim. It does not replace fork/testnet/live evidence, public beta or
production review. It is not a maintained monitoring service. no secrets,
private keys, mnemonics, RPC URLs, API keys, signer-service credentials, and
unreleased drop payloads are forbidden.

## Maturity And Scope

Maturity is named.

## Source Of Truth

{links}

release manifest, checksum bundle, address book, bytecode proof, risk register,
public-beta evidence, event topic catalog, and normalized log identity are
named.

## Data Sources

chain ID, deployment version, contract address, block number, block hash,
transaction hash, log index, event signature, confirmation depth, and reorg
rollback are named.

## Event Coverage

Admin and roles, Signer and drop authorization, Pause and emergency, Auction,
Payments and credits, Randomizer, Metadata and dependency, and Release evidence
are named. GlobalAdminUpdated, FunctionAdminUpdated, PauseGuardianUpdated,
UnpauseAdminUpdated, SignerManagerUpdated, SignerLifecycleTargetUpdated,
EmergencyRecipientUpdated, DropSignerChanged, SignerEpochChanged,
DropAuthorizationCancelled, PauseUpdated, EmergencyWithdrawal,
CollectionFrozen, PermanentURI, ERC-4906, DependencyVersionCreated,
DependencyVersionDeprecated, and DependencyVersionPinned are named.

## Admin And Role Monitoring

role change, approved Safe or multisig ceremony, selector coverage drift,
two-person review, post-state read, DROP_EXECUTION, MINT, AUCTION_BID,
AUCTION_SETTLEMENT, METADATA_MUTATION, and RANDOMNESS_REQUEST are named.

## Signer And Drop Authorization Monitoring

signer rotation, signer custody readiness evidence, signer epoch increments,
drop cancellations, accepted drop authorization, EIP-712, ERC-1271, Safe, EOA,
Replay protection, and consumed-state storage are named.

## Auction Monitoring

None, Created, Active, EndedNoBid, EndedWithBid, SettledNoBid,
SettledWithBid, Cancelled, stuck auctions, token custody is known at all times,
previous bidder refund becomes withdrawable credit, and settlement is
idempotent are named.

## Randomizer Monitoring

request ID, randomizer epoch, unexpected provider, duplicate callback, pending
request age, provider funding, stale requests, and fulfillment validates
request ID, token, collection, randomizer address, and randomizer epoch are
named.

## Payment And Credit Monitoring

poster credits, bidder credits, curator credits, protocol surplus, total owed,
emergency withdrawable, contract balance covers owed balances, failed
withdrawal does not erase credit, and emergency withdrawal cannot withdraw owed
funds are named.

## Metadata And Dependency Monitoring

Metadata dependency monitoring is named.

## Release Evidence Monitoring

Release evidence monitoring is named.

## Alert Severity Model

critical alert is named.

## Dashboard And Query Model

deployment selector, admin activity, signer activity, auction health,
randomizer health, payments and credits, metadata and dependency state, and
release evidence are named.

## Incident Handoff

incident-response handoff is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Maintenance is named.
"""


class MonitoringSpecTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed monitoring specification satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete spec passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_MONITORING_SPEC, minimal_monitoring_spec())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default monitoring spec path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/monitoring-copy.md")
            write_text(root / custom_path, minimal_monitoring_spec())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--monitoring-spec",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "## Dashboard And Query Model\n", ""
            )
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required headings"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace("not production-ready", "ready")
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required content"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_missing_section_scoped_phrase(self) -> None:
        """Monitor categories must stay in their intended sections."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace("auction health,", "")
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "incomplete sections"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "- [docs/incident-response.md](../docs/incident-response.md)\n", ""
            )
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required links"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_escaped_link_target(self) -> None:
        """Links that escape the repository root are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec() + "\n[escape](../../outside.md)\n"
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "linked path escapes repository"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs" / "incident-response.md").unlink()
            write_text(root / checker.DEFAULT_MONITORING_SPEC, minimal_monitoring_spec())

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "links to missing files"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "python scripts/check_monitoring_spec.py\n", ""
            )
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required commands"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_required_command_outside_validation_code_fence(self) -> None:
        """Required commands must appear in fenced validation command blocks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "```sh\npython scripts/test_monitoring_spec.py\n",
                "```sh\n",
            )
            text += "\npython scripts/test_monitoring_spec.py\n"
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required commands"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_monitoring_spec().replace(
                "python scripts/check_monitoring_spec.py",
                "python scripts/check_monitoring_spec.py --help",
            )
            write_text(root / checker.DEFAULT_MONITORING_SPEC, text)

            with self.assertRaisesRegex(
                checker.MonitoringSpecError, "missing required commands"
            ):
                checker.validate_monitoring_spec(
                    root, root / checker.DEFAULT_MONITORING_SPEC
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
