#!/usr/bin/env python3
"""Validate the mobile and WalletConnect integration guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_MOBILE_WALLETCONNECT = Path("docs/integrations/mobile-walletconnect.md")

REQUIRED_HEADINGS = [
    (1, "Mobile And WalletConnect Integration Guide"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Non-Goals"),
    (2, "Mobile Architecture Boundaries"),
    (2, "WalletConnect Session Lifecycle"),
    (2, "Deep Link And Foreground Handoff"),
    (2, "Network Account And Domain Guards"),
    (2, "Typed Data And Transaction Flows"),
    (2, "Offline Background And Reconnect Policy"),
    (2, "Metadata Event And Indexer Refresh"),
    (2, "Telemetry Support And No-Secret Logs"),
    (2, "Security Checklist"),
    (2, "Testing Strategy"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "INT-008",
    "pre-audit",
    "local baseline",
    "not production-ready",
    "not a security claim",
    "does not replace fork/testnet/live evidence",
    "public beta",
    "production",
    "6529.io",
    "mobile browser",
    "native mobile shell",
    "WalletConnect",
    "QR pairing",
    "deep links",
    "universal links",
    "app links",
    "foreground wallet action",
    "return-to-app",
    "session_pending",
    "session_expired",
    "transport_error",
    "reconnected",
    "account_changed",
    "wrong_chain",
    "chain ID",
    "address book",
    "deployment manifest",
    "release manifest",
    "ABI checksum",
    "event topic catalog",
    "interface IDs",
    "release checksums",
    "bytecode-to-release proof",
    "risk register",
    "public-beta evidence",
    "EIP-712",
    "ERC-1271",
    "Safe",
    "`DropAuthorization`",
    "`tokenDataHash`",
    "tdhSigner",
    "signerEpoch",
    "isDropConsumed",
    "isDropCancelled",
    "consumedDropIds",
    "cancelledDropIds",
    "signer-service allocated",
    "deadline",
    "WalletConnect does not provide replay protection",
    "foregrounded",
    "backgrounded",
    "offline",
    "push notifications",
    "confirmation depth",
    "read-after-event",
    "reorg",
    "indexer lag",
    "MetadataUpdate",
    "BatchMetadataUpdate",
    "CollectionFrozen",
    "TokenBurned",
    "DependencyVersionPinned",
    "animation_url",
    "WebView",
    "private keys",
    "seed phrases",
    "mnemonics",
    "signer-service credentials",
    "WalletConnect pairing URIs",
    "session topics",
    "raw signatures",
    "unreleased signed `DropAuthorization` payloads",
    "not a mobile SDK commitment",
    "React Native",
    "Expo",
    "Electron",
    "INT-009",
]

REQUIRED_COMMANDS = [
    "python scripts/test_mobile_walletconnect.py",
    "python scripts/check_mobile_walletconnect.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_bytecode_release_proof.py",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/examples/react-viem.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "release-artifacts/README.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/bytecode-release-proof.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "deployments/schema/deployment-manifest.schema.json",
    "deployments/schema/address-book.schema.json",
    "deployments/config/sepolia-6529stream-v0.1.0-001.template.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/examples/anvil-6529stream-v0.1.0-001.json",
    "deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class MobileWalletConnectError(ValueError):
    """Raised when the mobile and WalletConnect guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise MobileWalletConnectError(
            f"linked path escapes repository: {path}"
        ) from exc


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


def label_looks_like_repo_path(label: str) -> bool:
    """Return true when a link label should match its resolved repo path."""
    normalized = label.strip().strip("`")
    return "/" in normalized or "\\" in normalized


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        label = match.group(1).strip().strip("`")
        target = normalized_link_target(match.group(2))
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
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != relative:
            raise MobileWalletConnectError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)

    if missing:
        raise MobileWalletConnectError(
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


def validate_mobile_walletconnect(repo_root: Path, document_path: Path) -> None:
    """Validate the mobile and WalletConnect integration guide."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise MobileWalletConnectError(
            f"missing mobile and WalletConnect guide: {relative}"
        )

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise MobileWalletConnectError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise MobileWalletConnectError(
            "mobile and WalletConnect guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    command_lines = {line.strip() for line in text.splitlines()}
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise MobileWalletConnectError(
            "mobile and WalletConnect guide is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise MobileWalletConnectError(
            "mobile and WalletConnect guide is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse mobile and WalletConnect checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--mobile-walletconnect",
        type=Path,
        default=DEFAULT_MOBILE_WALLETCONNECT,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the mobile and WalletConnect checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.mobile_walletconnect
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_mobile_walletconnect(repo_root, document_path.resolve())
    except MobileWalletConnectError as exc:
        print(f"mobile and WalletConnect check failed: {exc}", file=sys.stderr)
        return 1

    print("mobile and WalletConnect guide is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
