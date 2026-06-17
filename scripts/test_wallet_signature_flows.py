#!/usr/bin/env python3
"""Focused tests for the wallet/signature flow documentation checker."""

from __future__ import annotations

import importlib.util
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_wallet_signature_flows.py")
SPEC = importlib.util.spec_from_file_location("check_wallet_signature_flows", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required wallet/signature link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links() -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}](../../{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_wallet_signature_doc() -> str:
    """Build the smallest wallet/signature doc accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links()
    return f"""# Wallets And Signatures

This pre-audit local baseline is not production-ready and not a security claim.
It does not replace fork/testnet/live evidence for public beta or production.

## Maturity And Scope

React, mobile, Electron, operator UI, indexer, backend signing service,
WalletConnect, and Safe teams are named. INT-014 TypeScript EIP-712 payload
construction snippets, domain construction, DropAuthorization message shape,
drop ID derivation, token data hashing, sale-mode validation, submission
preflight, and no-secret logging are named. Fork-aware Safe/ERC-1271 smoke,
StreamSafeERC1271ForkSmoke, MockSafeERC1271Signer, `vm.chainId`, no live RPC,
no private keys, and no-secret policy are named.

## Source Of Truth

{links}

## Domain And Typed Data

EIP-712, ERC-1271, DropAuthorization, mintDrop, domainSeparator,
EIP712Domain, `name`, `version`, `chainId`, `verifyingContract`, 6529StreamDrops,
DROP_AUTHORIZATION_TYPEHASH, DROP_ID_TYPEHASH,
DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt),
deriveDropId, hashDropAuthorization, tokenDataHash,
keccak256(bytes(tokenData)), tdhSigner, signerEpoch, `nonce`, `salt`, and `deadline`
are named.

## Replay And Revocation Controls

EIP-712 is encoding/signing only. Storage-backed consumedDropIds and
cancelledDropIds are named. There is no separate on-chain monotonic nonce map;
nonce uniqueness is a signer-service obligation. Wrong domain, wrong chain,
stale signer epoch, replayed drop, cancelled drop, and expired deadline.

## EOA Wallet Flow

65-byte and 64-byte EIP-2098 EOA signatures are named. Wrong signer,
malleable signature, invalid `v`, zero recovered signer, and malformed
signature length are named.

## ERC-1271 Contract Signer Flow

isValidSignature(bytes32 digest, bytes signature), 0x1626ba7e,
return exactly 32 bytes, invalid magic, empty return, short return,
extra return, wrong digest, and wrong signature bytes are named.

## Safe Signing Flow

Safe signer custody readiness is named.

## WalletConnect And Mobile Handoff

WalletConnect and mobile reconnect behavior are named.

## Backend Signing Service Boundary

Backend signing service boundaries are named.

## Frontend Preflight Reads

Frontend preflight reads and eth_call are named.

## Failure States

Zero-address signer, zero-address recipient, non-zero auction recipient, and
token data substitution are named.

## Security And UX Requirements

Security and UX requirements are named.

## Validation Commands

```sh
{commands}
```

## Maintenance

Refresh when signature behavior changes.
"""


class WalletSignatureFlowsTests(unittest.TestCase):
    def test_accepts_committed_doc(self) -> None:
        """The committed wallet/signature guide satisfies the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_doc(self) -> None:
        """A minimal complete wallet/signature doc passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            write_text(
                root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS,
                minimal_wallet_signature_doc(),
            )

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_accepts_custom_doc_path(self) -> None:
        """The CLI accepts a non-default wallet/signature doc path."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            custom_path = Path("docs/custom-wallets/signatures.md")
            write_text(root / custom_path, minimal_wallet_signature_doc())

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--wallet-signature-flows",
                        str(custom_path),
                    ]
                )

            self.assertEqual(result, 0)

    def test_rejects_missing_heading(self) -> None:
        """Missing required headings are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_wallet_signature_doc().replace("## Safe Signing Flow\n", "")
            write_text(root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS, text)

            with self.assertRaisesRegex(
                checker.WalletSignatureFlowsError, "missing required headings"
            ):
                checker.validate_wallet_signature_flows(
                    root, root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS
                )

    def test_rejects_missing_required_phrase(self) -> None:
        """Missing signature safety language is rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_wallet_signature_doc().replace(
                "EIP-712 is encoding/signing only", "EIP-712 is enough"
            )
            write_text(root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS, text)

            with self.assertRaisesRegex(
                checker.WalletSignatureFlowsError, "missing required content"
            ):
                checker.validate_wallet_signature_flows(
                    root, root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS
                )

    def test_required_phrases_tolerate_markdown_wrapping(self) -> None:
        """Required phrases may span Markdown-wrapped lines."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_wallet_signature_doc().replace(
                "does not replace fork/testnet/live evidence",
                "does not replace fork/testnet/live\nevidence",
            )
            write_text(root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS, text)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_required_link(self) -> None:
        """Required source links cannot be silently dropped."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            original = minimal_wallet_signature_doc()
            text = original.replace(
                "- [smart-contracts/StreamDrops.sol](../../smart-contracts/StreamDrops.sol)\n",
                "",
            )
            self.assertNotEqual(text, original, "replacement had no effect")
            write_text(root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS, text)

            with self.assertRaisesRegex(
                checker.WalletSignatureFlowsError, "missing required links"
            ):
                checker.validate_wallet_signature_flows(
                    root, root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS
                )

    def test_rejects_missing_linked_file(self) -> None:
        """Local links must resolve to existing repository files."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            (root / "smart-contracts/StreamDrops.sol").unlink()
            write_text(
                root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS,
                minimal_wallet_signature_doc(),
            )

            with self.assertRaisesRegex(
                checker.WalletSignatureFlowsError, "linked targets are missing"
            ):
                checker.validate_wallet_signature_flows(
                    root, root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS
                )

    def test_rejects_missing_required_command(self) -> None:
        """Validation commands must stay visible in the doc."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_required_targets(root)
            text = minimal_wallet_signature_doc().replace(
                "python scripts/check_wallet_signature_flows.py\n", ""
            )
            write_text(root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS, text)

            with self.assertRaisesRegex(
                checker.WalletSignatureFlowsError, "missing required commands"
            ):
                checker.validate_wallet_signature_flows(
                    root, root / checker.DEFAULT_WALLET_SIGNATURE_FLOWS
                )


if __name__ == "__main__":
    unittest.main(verbosity=2)
