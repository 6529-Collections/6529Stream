#!/usr/bin/env python3
"""Focused tests for the operator dashboard query model checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_operator_dashboard_query_model.py")
SPEC = importlib.util.spec_from_file_location(
    "check_operator_dashboard_query_model", SCRIPT_PATH
)
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


def minimal_dashboard_model() -> str:
    """Build the smallest dashboard query model accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Operator Dashboard Query Model

This GOV-010 model implements GOV-009 as a pre-audit local baseline. It is not
production-ready and not a security claim. It does not replace
fork/testnet/live evidence, public beta, production, or a maintained monitoring
service. no secrets, private keys, mnemonics, RPC URLs, API keys,
signer-service credentials, raw signatures, Safe signing secrets, and
unreleased drop payloads are forbidden.

## Maturity And Scope

Maturity is named.

## Source Of Truth

{links}

release manifest, checksum bundle, bytecode proof, risk register,
public-beta evidence, event topic catalog, ABI checksum, and interface IDs are
named.

## Dashboard Data Contract

chainId, deploymentVersion, releaseManifestHash, addressBookHash,
contractAddress, blockNumber, blockHash, transactionHash, logIndex,
eventSignature, normalizedLogIdentity, freshnessStatus, operatorActionBoundary,
confirmation depth, reorg rollback, and read-after-event are named.

## Common Query Inputs

Common inputs are named.

## Panel Catalog

Environment And Release Snapshot, Admin And Governance, Signer And Drop
Authorization, Fixed-Price Drop Execution, Auction Health, Randomizer
Lifecycle, Payment And Credit Solvency, Metadata And Dependency State, Release
Evidence And Blockers, and Incident Drill And Handoff are named.

## Environment And Release Snapshot Panel

Environment query input is named.

## Admin And Governance Panel

GlobalAdminUpdated, FunctionAdminUpdated, PauseGuardianUpdated,
UnpauseAdminUpdated, SignerManagerUpdated, SignerLifecycleTargetUpdated,
PauseUpdated, EmergencyRecipientUpdated, retrieveGlobalAdmin,
retrieveFunctionAdmin, isPaused(domain), Critical, and prepare Safe or multisig
ceremony are named.

## Signer And Drop Authorization Panel

DropSignerChanged, SignerEpochChanged, DropAuthorizationCancelled,
DropAuthorizationConsumed, EIP-712, ERC-1271, tdhSigner(), signerEpoch(),
EIP-712 domain, ERC-1271 support status, and consumed-state storage are named.

## Fixed-Price Drop Execution Panel

FixedPriceCreditCreated is named.

## Auction Health Panel

AuctionRegistered, Participate, OutbidCreditCreated,
AuctionProceedsCreditCreated, None, Created, Active, EndedNoBid, EndedWithBid,
SettledNoBid, SettledWithBid, Cancelled, and unknown token custody are named.

## Randomizer Lifecycle Panel

RandomnessRequested, RandomnessFulfilled, RandomnessRequestMarkedStale,
RandomnessPostProcessingFailed, request ID, collection ID, token ID,
randomizer epoch, and duplicate callback are named.

## Payment And Credit Solvency Panel

poster credits, bidder credits, curator credits, protocol surplus, total owed,
emergencyWithdrawable, contract balance covers owed balances, failed withdrawal
does not erase credit, and emergency withdrawal cannot withdraw owed funds are
named.

## Metadata And Dependency State Panel

CollectionFrozen, PermanentURI, ERC-4906, DependencyVersionCreated,
DependencyVersionDeprecated, DependencyVersionPinned, and ContractURIUpdated are
named.

## Release Evidence And Blocker Panel

public-beta evidence, risk-register, release evidence issue, signed tag, and
explorer verification are named.

## Incident Drill And Handoff Panel

incident handoff is named.

## Freshness And Reorg Model

Freshness is named.

## No-Secret Telemetry

No-secret telemetry is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Maintenance is named.
"""


class DashboardQueryModelTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed dashboard query model satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete dashboard query model passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, minimal_dashboard_model())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default dashboard query model path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/dashboard-copy.md")
            write_text(root / custom_path, minimal_dashboard_model())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--dashboard-model",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace("## Panel Catalog\n", "")
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required headings"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace("production-ready", "ready")
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required content"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_missing_section_scoped_phrase(self) -> None:
        """Required panel coverage must remain in the intended sections."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace("Payment And Credit Solvency, ", "")
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "incomplete sections"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace(
                "- [docs/monitoring.md](../docs/monitoring.md)\n", ""
            )
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required links"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_escaped_link_target(self) -> None:
        """Links that escape the repository root are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model() + "\n[escape](../../outside.md)\n"
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "linked path escapes repository"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs" / "monitoring.md").unlink()
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, minimal_dashboard_model())

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "links to missing files"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace(
                "python scripts/check_operator_dashboard_query_model.py\n", ""
            )
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required commands"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_required_command_outside_validation_code_fence(self) -> None:
        """Required commands must appear in fenced validation command blocks."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace(
                "```sh\npython scripts/test_operator_dashboard_query_model.py\n",
                "```sh\n",
            )
            text += "\npython scripts/test_operator_dashboard_query_model.py\n"
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required commands"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_dashboard_model().replace(
                "python scripts/check_operator_dashboard_query_model.py",
                "python scripts/check_operator_dashboard_query_model.py --help",
            )
            write_text(root / checker.DEFAULT_DASHBOARD_MODEL, text)

            with self.assertRaisesRegex(
                checker.DashboardQueryModelError, "missing required commands"
            ):
                checker.validate_dashboard_query_model(
                    root, root / checker.DEFAULT_DASHBOARD_MODEL
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
