#!/usr/bin/env python3
"""Focused tests for the operator admin UI guide checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_operator_admin_ui.py")
SPEC = importlib.util.spec_from_file_location("check_operator_admin_ui", SCRIPT_PATH)
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
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_operator_admin_ui() -> str:
    """Build the smallest operator admin UI guide accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Operator Admin UI Specification

This INT-010 pre-audit local baseline is not production-ready and not a
security claim. It does not replace fork/testnet/live evidence for public beta
or production. The 6529.io operator UI names Safe, multisig, owner threshold,
deployer, monitoring, incident response, two-person review, dry-run, and
post-state read boundaries. It is not a maintained operator dashboard
commitment.

## Maturity And Scope

Maturity is named.

## Source Of Truth

{links}

address book, deployment manifest, release manifest, ABI checksum, event topic
catalog, interface IDs, risk register, and public-beta evidence are named.

## Non-Goals

private keys, mnemonics, RPC URLs, API keys, signer-service credentials, and
unreleased drop payloads are forbidden.

## Operator Personas

Personas are named.

## Environment And Artifacts

Environment artifacts are named.

## Permissions And Role Model

StreamAdmins, global admin, function admin, pause guardian, unpause admin,
signer manager, and signer lifecycle target are named. registerAdmin,
registerFunctionAdmin, registerBatchFunctionAdmin, registerSignerManager,
registerSignerLifecycleTarget, registerSignerFunctionAdmin,
registerBatchSignerFunctionAdmin, registerPauseGuardian, registerUnpauseAdmin,
setPaused, and updateEmergencyRecipient are named.

## Workflow Matrix

Root admin grant, Function admin grant, Signer manager grant, Signer lifecycle
target grant, Signer function grant, Pause role grant, Pause domain update,
Emergency recipient update, Drop signer rotation, Signer epoch increment, Drop
cancellation, Metadata freeze, Randomizer update, Dependency create or
deprecate, and Emergency withdrawal are named.

DropSignerChanged, SignerEpochChanged, DropAuthorizationCancelled,
PauseUpdated, GlobalAdminUpdated, FunctionAdminUpdated, PauseGuardianUpdated,
UnpauseAdminUpdated, SignerManagerUpdated, SignerLifecycleTargetUpdated,
EmergencyRecipientUpdated, updateTDHsigner, incrementSignerEpoch, cancelDrop,
DROP_EXECUTION, MINT, AUCTION_BID, AUCTION_SETTLEMENT, METADATA_MUTATION,
RANDOMNESS_REQUEST, emergencyWithdrawable, emergencyWithdraw,
EmergencyWithdrawal, freezeCollection, CollectionFrozen, addRandomizer,
CollectionRandomizerUpdated, DependencyVersionCreated,
DependencyVersionDeprecated, DependencyVersionPinned, randomizer epoch,
provider funding, and metadata freeze are named.

## Safe And Multisig Ceremony

Safe transaction, owner threshold, calldata decoded, target contract address,
batch preview, simulation or dry-run, and post-state reads are named.

## Signer Lifecycle

Signer lifecycle is named.

## Pause And Incident Controls

Pause controls are named.

## Metadata And Dependency Operations

Metadata and dependency operations are named.

## Randomizer Operations

Randomizer operations are named.

## Emergency Withdrawals And Surplus

Emergency withdrawal surplus is named.

## Monitoring Events And Indexer Reads

Monitoring events are named.

## UI Confirmation Model

Artifact check, Pre-state read, Risk classification, Simulation or dry-run,
Human-readable diff, Two-person review, Safe transaction, Post-state read, and
Evidence attachment are named.

## Testing Strategy

Testing strategy is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Maintenance is named.
"""


class OperatorAdminUiTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed operator admin UI guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete guide passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_OPERATOR_ADMIN_UI,
                minimal_operator_admin_ui(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default operator admin UI guide path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom/operator-admin.md")
            write_text(root / custom_path, minimal_operator_admin_ui())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--operator-admin-ui",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "## UI Confirmation Model\n", ""
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "missing required headings"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "missing required content"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_missing_section_scoped_phrase(self) -> None:
        """Workflow rows must stay in the intended guide section."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "Root admin grant, Function admin grant, Signer manager grant,",
                "Function admin grant, Signer manager grant,",
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "incomplete sections"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_operator_admin_ui()
            text = original.replace(
                "- [docs/deployment.md](../../docs/deployment.md)\n", ""
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "missing required links"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            missing_target = root / "docs" / "deployment.md"
            missing_target.unlink()
            write_text(
                root / checker.DEFAULT_OPERATOR_ADMIN_UI,
                minimal_operator_admin_ui(),
            )

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "links to missing files"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "- [docs/deployment.md](../../docs/deployment.md)\n",
                "- [docs/deployment.md](../../docs/incident-response.md)\n",
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "points to"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "python scripts/check_operator_admin_ui.py\n", ""
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "missing required commands"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_operator_admin_ui().replace(
                "python scripts/check_operator_admin_ui.py",
                "python scripts/check_operator_admin_ui.py --help",
            )
            write_text(root / checker.DEFAULT_OPERATOR_ADMIN_UI, text)

            with self.assertRaisesRegex(
                checker.OperatorAdminUiError, "missing required commands"
            ):
                checker.validate_operator_admin_ui(
                    root, root / checker.DEFAULT_OPERATOR_ADMIN_UI
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
