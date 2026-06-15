#!/usr/bin/env python3
"""Focused tests for the mobile and WalletConnect guide checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_mobile_walletconnect.py")
SPEC = importlib.util.spec_from_file_location("check_mobile_walletconnect", SCRIPT_PATH)
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


def minimal_mobile_walletconnect() -> str:
    """Build the smallest mobile and WalletConnect guide accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Mobile And WalletConnect Integration Guide

This INT-008 pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.
The 6529.io mobile browser and native mobile shell use WalletConnect, QR pairing,
deep links, universal links, app links, foreground wallet action, and return-to-app flows.

## Maturity And Scope

This is not a mobile SDK commitment and names React Native, Expo, Electron, and INT-009.

## Source Of Truth

{links}

Release manifest, ABI checksum, address book, deployment manifest, event topic
catalog, interface IDs, release checksums, bytecode-to-release proof, risk register,
and public-beta evidence are named.

## Non-Goals

No app or package dependency is added.

## Mobile Architecture Boundaries

WalletConnect is a user channel, not the production signer.

## WalletConnect Session Lifecycle

session_pending, session_expired, transport_error, reconnected, account_changed,
and wrong_chain are named.

## Deep Link And Foreground Handoff

foregrounded and backgrounded flows are named.

## Network Account And Domain Guards

Chain ID, EIP-712, ERC-1271, Safe, `DropAuthorization`, `tokenDataHash`,
tdhSigner, signerEpoch, isDropConsumed, isDropCancelled, consumedDropIds,
cancelledDropIds, signer-service allocated nonce and salt, deadline, and
WalletConnect does not provide replay protection are named.

## Typed Data And Transaction Flows

Transactions and typed data are named.

## Offline Background And Reconnect Policy

Offline, push notifications, confirmation depth, read-after-event, reorg, and
indexer lag are named.

## Metadata Event And Indexer Refresh

MetadataUpdate, BatchMetadataUpdate, CollectionFrozen, TokenBurned,
DependencyVersionPinned, animation_url, and WebView are named.

## Telemetry Support And No-Secret Logs

Private keys, seed phrases, mnemonics, signer-service credentials,
WalletConnect pairing URIs, session topics, raw signatures, and unreleased
signed `DropAuthorization` payloads are named.

## Security Checklist

Security checklist is named.

## Testing Strategy

Testing strategy is named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when mobile integration docs change.
"""


class MobileWalletConnectTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed mobile and WalletConnect guide satisfies the checker."""
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
                root / checker.DEFAULT_MOBILE_WALLETCONNECT,
                minimal_mobile_walletconnect(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default mobile guide path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom/mobile.md")
            write_text(root / custom_path, minimal_mobile_walletconnect())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--mobile-walletconnect",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                "## WalletConnect Session Lifecycle\n", ""
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "missing required headings"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "missing required content"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                "WalletConnect does not provide replay protection",
                "WalletConnect does not provide replay\nprotection",
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_mobile_walletconnect()
            text = original.replace(
                "- [docs/integrations/metadata-rendering.md](../../docs/integrations/metadata-rendering.md)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "missing required links"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/integrations/metadata-rendering.md").unlink()
            write_text(
                root / checker.DEFAULT_MOBILE_WALLETCONNECT,
                minimal_mobile_walletconnect(),
            )

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "linked targets are missing"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/metadata-rendering.md)\n"
                ),
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/contract-flows.md)\n"
                ),
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "resolves to"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                "python scripts/check_mobile_walletconnect.py\n", ""
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "missing required commands"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_mobile_walletconnect().replace(
                "make check\n",
                "echo make check\n",
            )
            write_text(root / checker.DEFAULT_MOBILE_WALLETCONNECT, text)

            with self.assertRaisesRegex(
                checker.MobileWalletConnectError, "missing required commands"
            ):
                checker.validate_mobile_walletconnect(
                    root, root / checker.DEFAULT_MOBILE_WALLETCONNECT
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
