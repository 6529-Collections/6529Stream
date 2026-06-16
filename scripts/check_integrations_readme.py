#!/usr/bin/env python3
"""Validate the integrations documentation entrypoint."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_INTEGRATIONS_README = Path("docs/integrations/README.md")

REQUIRED_HEADINGS = [
    (1, "Integrations"),
    (2, "Maturity And Scope"),
    (2, "Consumer Surfaces"),
    (2, "Source Of Truth"),
    (2, "Canonical Artifacts"),
    (2, "Integration Flows"),
    (2, "Readiness Boundaries"),
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
    "indexer",
    "operator UI",
    "backend signing service",
    "ABIs",
    "address books",
    "deployment manifests",
    "release manifest",
    "source verification inputs",
    "ABI compatibility baseline",
    "event topic catalog",
    "interface IDs",
    "IStreamCompatibility",
    "interface and version views for frontend compatibility",
    "metadata",
    "1/1 provenance manifest",
    "collector-verifiable permanence package",
    "one-of-one permanence manifest",
    "royalty policy",
    "ERC-2981",
    "royalty disclosure, not payment enforcement",
    "No production-readiness claim depends on marketplaces honoring royalties",
    "EIP-712",
    "ERC-1271",
    "risk register",
    "public-beta evidence status",
    "INT-002",
    "INT-003",
    "auction frontend and indexer flow spec",
    "INT-004",
    "wallet, EIP-712, ERC-1271, and Safe signing guide",
    "INT-005",
    "event and indexer reconstruction spec",
    "INT-006",
    "metadata rendering, cache, animation sandbox, and marketplace integration guide",
    "ONE-005",
    "retained marketplace/indexer evidence",
    "OpenSea",
    "Reservoir",
    "Blur",
    "Manifold",
    "INT-007",
    "React/Next frontend reference architecture",
    "maintained frontend package",
    "generated SDK",
    "INT-008",
    "mobile and WalletConnect integration guide",
    "maintained mobile SDK",
    "React Native app",
    "WalletConnect dependency recommendation",
    "INT-009",
    "Electron security and wallet integration guide",
    "maintained Electron app",
    "native desktop app",
    "desktop SDK",
    "code-signing implementation",
    "signed-update implementation",
    "INT-010",
    "operator admin UI specification",
    "maintained operator dashboard",
    "Safe app",
    "multisig transaction builder",
    "monitoring service",
    "production signer custody implementation",
    "fully on-chain versus decentralized storage",
    "browser proof",
]

REQUIRED_COMMANDS = [
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_auction_flows.py",
    "python scripts/check_auction_flows.py",
    "python scripts/test_wallet_signature_flows.py",
    "python scripts/check_wallet_signature_flows.py",
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_metadata_rendering.py",
    "python scripts/check_metadata_rendering.py",
    "python scripts/test_marketplace_indexer_evidence.py",
    "python scripts/check_marketplace_indexer_evidence.py",
    "python scripts/test_one_of_one_provenance_manifest.py",
    "python scripts/check_one_of_one_provenance_manifest.py",
    "python scripts/generate_one_of_one_provenance_manifest.py --check",
    "python scripts/test_one_of_one_permanence_package.py",
    "python scripts/check_one_of_one_permanence_package.py",
    "python scripts/generate_one_of_one_permanence_manifest.py --check",
    "python scripts/test_royalty_policy.py",
    "python scripts/check_royalty_policy.py",
    "python scripts/test_react_next_reference.py",
    "python scripts/check_react_next_reference.py",
    "python scripts/test_mobile_walletconnect.py",
    "python scripts/check_mobile_walletconnect.py",
    "python scripts/test_electron_security_wallets.py",
    "python scripts/check_electron_security_wallets.py",
    "python scripts/test_operator_admin_ui.py",
    "python scripts/check_operator_admin_ui.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_changelog.py",
]

REQUIRED_LINK_TARGETS = [
    "README.md",
    "docs/release-readiness.md",
    "docs/deployment.md",
    "docs/drop-authorization-signing.md",
    "docs/metadata.md",
    "docs/provenance-manifests.md",
    "docs/permanence-packages.md",
    "docs/royalty-policy.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
    "docs/public-beta-evidence.md",
    "docs/non-local-release-evidence.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/known-blockers.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/marketplace-indexer-evidence.md",
    "docs/integrations/interface-versioning.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/mobile-walletconnect.md",
    "docs/integrations/electron-security-wallets.md",
    "docs/integrations/operator-admin-ui.md",
    "docs/integrations/examples/react-viem.md",
    "release-artifacts/README.md",
    "release-artifacts/contracts.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/release-artifact-manifest.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/bytecode-release-proof.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/source-verification-inputs.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/one-of-one-provenance-manifest.json",
    "release-artifacts/schema/one-of-one-provenance-manifest.schema.json",
    "release-artifacts/provenance/one-of-one-provenance-template.provenance.json",
    "release-artifacts/latest/one-of-one-permanence-manifest.json",
    "release-artifacts/schema/one-of-one-permanence-package.schema.json",
    "release-artifacts/permanence/one-of-one-permanence-template.permanence.json",
    "deployments/README.md",
    "deployments/schema/deployment-manifest.schema.json",
    "deployments/schema/address-book.schema.json",
    "deployments/config/sepolia-6529stream-v0.1.0-001.template.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "deployments/examples/anvil-6529stream-v0.1.0-001.json",
    "deployments/examples/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class IntegrationsReadmeError(ValueError):
    """Raised when the integrations entrypoint is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise IntegrationsReadmeError(f"linked path escapes repository: {path}") from exc


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
        raise IntegrationsReadmeError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def validate_integrations_readme(repo_root: Path, document_path: Path) -> None:
    """Validate the integrations README against required source-of-truth links."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise IntegrationsReadmeError(f"missing integrations README: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise IntegrationsReadmeError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise IntegrationsReadmeError(
            "integrations README is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise IntegrationsReadmeError(
            "integrations README is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise IntegrationsReadmeError(
            "integrations README is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse integrations README checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--readme", type=Path, default=DEFAULT_INTEGRATIONS_README)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the integrations README checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    readme_path = args.readme
    if not readme_path.is_absolute():
        readme_path = repo_root / readme_path

    try:
        validate_integrations_readme(repo_root, readme_path.resolve())
    except IntegrationsReadmeError as exc:
        print(f"integrations README check failed: {exc}", file=sys.stderr)
        return 1

    print("integrations README is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
