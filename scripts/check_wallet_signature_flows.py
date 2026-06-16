#!/usr/bin/env python3
"""Validate the wallet and signature integration documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_WALLET_SIGNATURE_FLOWS = Path("docs/integrations/wallets-and-signatures.md")

REQUIRED_HEADINGS = [
    (1, "Wallets And Signatures"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Domain And Typed Data"),
    (2, "Replay And Revocation Controls"),
    (2, "EOA Wallet Flow"),
    (2, "ERC-1271 Contract Signer Flow"),
    (2, "Safe Signing Flow"),
    (2, "WalletConnect And Mobile Handoff"),
    (2, "Backend Signing Service Boundary"),
    (2, "Frontend Preflight Reads"),
    (2, "Failure States"),
    (2, "Security And UX Requirements"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "local baseline",
    "does not replace fork/testnet/live evidence",
    "public beta",
    "production",
    "React",
    "mobile",
    "Electron",
    "operator UI",
    "indexer",
    "backend signing service",
    "WalletConnect",
    "Safe",
    "fork-aware Safe/ERC-1271 smoke",
    "StreamSafeERC1271ForkSmoke",
    "MockSafeERC1271Signer",
    "`vm.chainId`",
    "no live RPC",
    "EIP-712",
    "ERC-1271",
    "EIP-2098",
    "DropAuthorization",
    "mintDrop",
    "domainSeparator",
    "EIP712Domain",
    "`name`",
    "`version`",
    "`chainId`",
    "`verifyingContract`",
    "6529StreamDrops",
    "DROP_AUTHORIZATION_TYPEHASH",
    "DROP_ID_TYPEHASH",
    "DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)",
    "deriveDropId",
    "hashDropAuthorization",
    "tokenDataHash",
    "keccak256(bytes(tokenData))",
    "tdhSigner",
    "signerEpoch",
    "`nonce`",
    "`salt`",
    "`deadline`",
    "consumedDropIds",
    "cancelledDropIds",
    "storage-backed",
    "EIP-712 is encoding/signing only",
    "no separate on-chain monotonic nonce map",
    "signer-service obligation",
    "wrong signer",
    "wrong domain",
    "wrong chain",
    "expired deadline",
    "replayed drop",
    "cancelled drop",
    "stale signer epoch",
    "malleable signature",
    "invalid `v`",
    "zero recovered signer",
    "malformed signature length",
    "zero-address signer",
    "zero-address recipient",
    "non-zero auction recipient",
    "token data substitution",
    "65-byte",
    "64-byte",
    "isValidSignature(bytes32 digest, bytes signature)",
    "0x1626ba7e",
    "return exactly 32 bytes",
    "invalid magic",
    "empty return",
    "short return",
    "extra return",
    "wrong digest",
    "wrong signature bytes",
    "signer custody readiness",
    "no private keys",
    "no-secret",
    "eth_call",
]

REQUIRED_COMMANDS = [
    "python scripts/test_wallet_signature_flows.py",
    "python scripts/check_wallet_signature_flows.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_drop_authorization_fixtures.py",
    "python scripts/check_drop_authorization_fixtures.py",
    "python scripts/test_drop_authorization_signing_evidence.py",
    "python scripts/check_drop_authorization_signing_evidence.py",
    "python scripts/test_signer_custody_readiness.py",
    "python scripts/check_signer_custody_readiness.py",
    "python scripts/check_changelog.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/generate_release_checksums.py --check",
    "forge test --match-path test/StreamDropsEIP712.t.sol",
    "forge test --match-path test/StreamDropsERC1271.t.sol",
    "forge test --match-path test/StreamSafeERC1271ForkSmoke.t.sol",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/drop-authorization-signing.md",
    "docs/adr/0001-drop-authorization.md",
    "docs/signer-custody-readiness.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/StreamAdmins.sol",
    "test/StreamDropsEIP712.t.sol",
    "test/StreamDropsERC1271.t.sol",
    "test/StreamSafeERC1271ForkSmoke.t.sol",
    "test/helpers/DropAuthTestHelper.sol",
    "test/fixtures/drop-authorization/fixed-price-eoa.json",
    "test/fixtures/drop-authorization/auction-eoa.json",
    "test/fixtures/drop-authorization/erc1271-contract-signer.json",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
    "test/fixtures/drop-authorization/payload-generator/auction-output.json",
    "scripts/generate_drop_authorization_payload.py",
    "scripts/check_drop_authorization_fixtures.py",
    "scripts/check_drop_authorization_signing_evidence.py",
    "scripts/check_signer_custody_readiness.py",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class WalletSignatureFlowsError(ValueError):
    """Raised when the wallet/signature flow doc is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise WalletSignatureFlowsError(f"linked path escapes repository: {path}") from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    """Return a local Markdown link path without anchors or query strings."""
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    if not path_part:
        return None
    return path_part


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        target = normalized_link_target(match.group(1))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path

        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        links.add(relative)

    if missing:
        raise WalletSignatureFlowsError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]


def validate_wallet_signature_flows(repo_root: Path, document_path: Path) -> None:
    """Validate the wallet/signature integration documentation."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise WalletSignatureFlowsError(f"missing wallet signature flows doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise WalletSignatureFlowsError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise WalletSignatureFlowsError(
            "wallet signature flows doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise WalletSignatureFlowsError(
            "wallet signature flows doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise WalletSignatureFlowsError(
            "wallet signature flows doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse wallet/signature checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--wallet-signature-flows",
        type=Path,
        default=DEFAULT_WALLET_SIGNATURE_FLOWS,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the wallet/signature checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.wallet_signature_flows
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_wallet_signature_flows(repo_root, document_path.resolve())
    except WalletSignatureFlowsError as exc:
        print(f"wallet signature flows check failed: {exc}", file=sys.stderr)
        return 1

    print("wallet signature flows doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
