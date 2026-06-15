#!/usr/bin/env python3
"""Validate the metadata rendering integration documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_METADATA_RENDERING = Path("docs/integrations/metadata-rendering.md")

REQUIRED_HEADINGS = [
    (1, "Metadata Rendering"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Metadata State Model"),
    (2, "TokenURI Behavior"),
    (2, "1/1 Provenance Manifests"),
    (2, "JSON And Fixture Expectations"),
    (2, "ERC-4906 Cache Invalidation"),
    (2, "Randomness And Retry States"),
    (2, "Freeze, Burn, And Dependency States"),
    (2, "Animation Sandbox"),
    (2, "Cache Strategy"),
    (2, "Marketplace And Evidence Boundaries"),
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
    "marketplace",
    "metadata rendering",
    "cache",
    "animation sandbox",
    "INT-006",
    "metadata_schema_version",
    "metadata_state",
    "tokenURI",
    "StreamContractMetadata",
    "IERC7572",
    "IStreamContractMetadata",
    "ERC-7572-style",
    "contractURI()",
    "contractURIHash()",
    "ContractURIUpdated",
    "one-of-one provenance",
    "1/1 provenance manifest",
    "artist statement",
    "authenticity status",
    "certificate",
    "curation history",
    "additional `tokenURI` JSON",
    "new `StreamCore` storage",
    "satellite/read-adapter",
    "METADATA_MUTATION",
    "`not_minted`",
    "`pending`",
    "`stale`",
    "`failed`",
    "`retry_failed`",
    "`final`",
    "`frozen`",
    "`burned`",
    "`dependency_pinned`",
    "`dependency_deprecated`",
    "`cache_stale`",
    "MetadataUpdate",
    "BatchMetadataUpdate",
    "CollectionFrozen",
    "DependencyVersionPinned",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "TokenBurned",
    "ERC-721 transfer-to-zero",
    "supportsInterface(0x49064906)",
    "no mint-only ERC-4906",
    "no burn ERC-4906",
    "data:application/json;base64",
    "animation_url",
    "strict UTF-8",
    "attributes",
    "allow-scripts",
    "unexpected outbound HTTP(S) requests",
    "parent document",
    "Electron",
    "mobile",
    "private keys",
    "release manifest",
    "release checksums",
    "one-of-one-provenance-manifest.json",
    "risk register",
    "public-beta evidence",
    "metadata browser evidence",
    "OpenSea",
    "Reservoir",
    "Blur",
    "Manifold",
]

REQUIRED_COMMANDS = [
    "python scripts/test_metadata_rendering.py",
    "python scripts/check_metadata_rendering.py",
    "python scripts/test_one_of_one_provenance_manifest.py",
    "python scripts/check_one_of_one_provenance_manifest.py",
    "python scripts/generate_one_of_one_provenance_manifest.py --check",
    "python scripts/test_metadata_fixtures.py",
    "python scripts/check_metadata_fixtures.py",
    "python scripts/test_metadata_browser_sandbox.py",
    "python scripts/check_metadata_browser_sandbox.py",
    "python scripts/test_rehearsal_metadata_browser_sandbox.py",
    "python scripts/check_rehearsal_metadata_browser_sandbox.py",
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
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/metadata.md",
    "docs/provenance-manifests.md",
    "docs/release-policy.md",
    "docs/release-readiness.md",
    "docs/dependency-operations.md",
    "docs/randomizer-operations.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/one-of-one-provenance-manifest.json",
    "release-artifacts/schema/one-of-one-provenance-manifest.schema.json",
    "release-artifacts/provenance/one-of-one-provenance-template.provenance.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/evidence/public-beta-templates/fork-testnet-metadata-browser-evidence-template.json",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/StreamContractMetadata.sol",
    "smart-contracts/StreamMetadataRenderer.sol",
    "smart-contracts/StreamRandomizerLifecycle.sol",
    "smart-contracts/DependencyRegistry.sol",
    "smart-contracts/IERC4906.sol",
    "smart-contracts/IERC7572.sol",
    "smart-contracts/IStreamContractMetadata.sol",
    "test/fixtures/metadata/onchain-pending-schema-v1-token-uri.txt",
    "test/fixtures/metadata/onchain-stale-schema-v1-token-uri.txt",
    "test/fixtures/metadata/onchain-failed-schema-v1-token-uri.txt",
    "test/fixtures/metadata/onchain-final-schema-v1-token-uri.txt",
    "test/fixtures/metadata/offchain-pending-token-uri.txt",
    "test/fixtures/metadata/offchain-stale-token-uri.txt",
    "test/fixtures/metadata/offchain-failed-token-uri.txt",
    "test/fixtures/metadata/offchain-final-token-uri.txt",
    "test/StreamMetadataGolden.t.sol",
    "test/StreamMetadataEvents.t.sol",
    "test/StreamContractMetadata.t.sol",
    "test/StreamMetadataFreeze.t.sol",
    "test/StreamCoreBurn.t.sol",
    "test/StreamRandomizerLifecycle.t.sol",
    "test/StreamRandomizerRetry.t.sol",
    "test/StreamDependencyRegistry.t.sol",
    "scripts/check_metadata_fixtures.py",
    "scripts/test_metadata_fixtures.py",
    "scripts/check_metadata_browser_sandbox.py",
    "scripts/test_metadata_browser_sandbox.py",
    "scripts/check_rehearsal_metadata_browser_sandbox.py",
    "scripts/test_rehearsal_metadata_browser_sandbox.py",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class MetadataRenderingError(ValueError):
    """Raised when the metadata rendering guide is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise MetadataRenderingError(f"linked path escapes repository: {path}") from exc


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
    suffixes = (
        ".md",
        ".json",
        ".sol",
        ".py",
        ".sh",
        ".ps1",
        ".yml",
        ".yaml",
        ".toml",
        ".txt",
    )
    return "/" in normalized or "\\" in normalized or normalized.endswith(suffixes)


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
            raise MetadataRenderingError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)

    if missing:
        raise MetadataRenderingError(
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


def validate_metadata_rendering(repo_root: Path, document_path: Path) -> None:
    """Validate the metadata rendering integration guide."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise MetadataRenderingError(f"missing metadata rendering doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise MetadataRenderingError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise MetadataRenderingError(
            "metadata rendering doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise MetadataRenderingError(
            "metadata rendering doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise MetadataRenderingError(
            "metadata rendering doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse metadata rendering checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--metadata-rendering",
        type=Path,
        default=DEFAULT_METADATA_RENDERING,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the metadata rendering checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.metadata_rendering
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_metadata_rendering(repo_root, document_path.resolve())
    except MetadataRenderingError as exc:
        print(f"metadata rendering check failed: {exc}", file=sys.stderr)
        return 1

    print("metadata rendering doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
