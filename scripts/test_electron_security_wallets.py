#!/usr/bin/env python3
"""Focused tests for the Electron security guide checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_electron_security_wallets.py")
SPEC = importlib.util.spec_from_file_location("check_electron_security_wallets", SCRIPT_PATH)
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


def minimal_electron_security_wallets() -> str:
    """Build the smallest Electron security guide accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Electron Security And Wallet Integration Guide

This INT-009 pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.
The 6529.io Electron BrowserWindow main process, renderer process, and preload
script use contextIsolation, nodeIntegration restrictions, sandbox, contextBridge,
IPC allowlist, Content-Security-Policy, and WebView isolation.

## Maturity And Scope

This is not a maintained Electron reference app commitment.

## Source Of Truth

{links}

Release manifest, ABI checksum, address book, deployment manifest, event topic
catalog, interface IDs, release checksums, bytecode-to-release proof, risk register,
and public-beta evidence are named.

## Non-Goals

No app or package dependency is added.

## Electron Process Model

Electron boundaries are named.

## Renderer Isolation And CSP

Private keys, seed phrases, mnemonics, signer-service credentials,
WalletConnect pairing secrets, session topics, raw signatures, and unreleased
signed DropAuthorization payloads are named.

## Preload And IPC Contract

No-secret logs are named.

## Wallet Provider Boundaries

Wallet provider, WalletConnect, EIP-1193, EIP-712, ERC-1271, Safe,
DropAuthorization, `tokenDataHash`, tdhSigner, signerEpoch, isDropConsumed,
isDropCancelled, consumedDropIds, cancelledDropIds, signer-service allocated
nonce and salt, deadline, chain ID, signed updates, code signing, autoUpdater,
rollback, animation_url, MetadataUpdate, BatchMetadataUpdate, CollectionFrozen,
TokenBurned, DependencyVersionPinned, and Electron, WalletConnect, and EIP-712
alone do not provide replay protection are named.

## Signing And Transaction Flows

Transactions and typed data are named.

## Metadata Animation Sandbox

Metadata sandbox is named.

## Local Storage Cache And Secrets

Secret storage is named. Private keys, seed phrases or mnemonics,
signer-service credentials, code-signing certificates, auto-update publish
credentials, WalletConnect pairing URIs, session topics, raw signatures, and
unreleased signed `DropAuthorization` payloads are named.

## Updates Downloads And Release Integrity

Updates are named.

## Telemetry Support And No-Secret Logs

Telemetry is named. Private keys, seed phrases or mnemonics, signer-service
credentials, code-signing certificates, autoUpdater publish credentials,
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

Refresh when Electron integration docs change.
"""


class ElectronSecurityWalletsTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed Electron security guide satisfies the checker."""
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
                root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS,
                minimal_electron_security_wallets(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default Electron guide path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom/electron.md")
            write_text(root / custom_path, minimal_electron_security_wallets())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--electron-security-wallets",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                "## Preload And IPC Contract\n", ""
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "missing required headings"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing maturity language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                "not production-ready", "ready"
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "missing required content"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_missing_section_scoped_phrase(self) -> None:
        """Secret-field coverage must appear in the intended guide sections."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                (
                    "Telemetry is named. Private keys, seed phrases or mnemonics, "
                    "signer-service\ncredentials, code-signing certificates, "
                    "autoUpdater publish credentials,\nWalletConnect pairing URIs, "
                    "session topics, raw signatures, and unreleased\nsigned "
                    "`DropAuthorization` payloads are named."
                ),
                "Telemetry is named.",
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "incomplete sections"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                "Electron, WalletConnect, and EIP-712 alone do not provide replay protection",
                "Electron, WalletConnect, and EIP-712 alone do not provide replay\nprotection",
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_electron_security_wallets()
            text = original.replace(
                "- [docs/integrations/metadata-rendering.md](../../docs/integrations/metadata-rendering.md)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "missing required links"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "docs/integrations/metadata-rendering.md").unlink()
            write_text(
                root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS,
                minimal_electron_security_wallets(),
            )

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "linked targets are missing"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_path_label_that_resolves_elsewhere(self) -> None:
        """Path-like link labels must resolve to the same repo path they name."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/metadata-rendering.md)\n"
                ),
                (
                    "- [docs/integrations/metadata-rendering.md]"
                    "(../../docs/integrations/contract-flows.md)\n"
                ),
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "resolves to"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                "python scripts/check_electron_security_wallets.py\n", ""
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "missing required commands"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )

    def test_rejects_required_command_as_substring_only(self) -> None:
        """Required commands must appear as exact command lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_electron_security_wallets().replace(
                "make check\n",
                "echo make check\n",
            )
            write_text(root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS, text)

            with self.assertRaisesRegex(
                checker.ElectronSecurityWalletsError, "missing required commands"
            ):
                checker.validate_electron_security_wallets(
                    root, root / checker.DEFAULT_ELECTRON_SECURITY_WALLETS
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
