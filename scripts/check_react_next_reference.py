#!/usr/bin/env python3
"""Validate the React/Next frontend reference architecture guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_REACT_NEXT_REFERENCE = Path(
    "docs/integrations/frontend-reference-architecture.md"
)

REQUIRED_HEADINGS = [
    (1, "React/Next Frontend Reference Architecture"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Non-Goals"),
    (2, "Application Layers"),
    (2, "Artifact Import Flow"),
    (2, "Environment And Network Selection"),
    (2, "Contract Client Layer"),
    (2, "Query And Cache Boundaries"),
    (2, "Transaction Orchestration"),
    (2, "Wallet And Signature Boundaries"),
    (2, "Error, Toast, And Telemetry Policy"),
    (2, "Metadata, Animation, And Marketplace Rendering"),
    (2, "Indexer And Event Reconciliation"),
    (2, "Security And Secret Handling"),
    (2, "Testing Strategy"),
    (2, "Pseudocode Examples"),
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
    "6529.io",
    "React",
    "Next",
    "viem",
    "wagmi",
    "TanStack Query",
    "generated types",
    "environment separation",
    "chain config",
    "transaction state",
    "INT-007",
    "INT-013",
    "TypeScript artifact loading and chain config snippets",
    "release artifact loading",
    "address book loading",
    "release manifest hash validation",
    "deployment manifest cross-checks",
    "ABI checksum awareness",
    "fail-closed wrong-chain guards",
    "chain config construction",
    "no package dependency is introduced",
    "not a generated SDK",
    "not a dependency recommendation",
    "INT-015",
    "TypeScript event decoding and indexer ingestion snippets",
    "event topic catalog loading",
    "topic0 dispatch",
    "normalized log identity",
    "reorg rollback",
    "idempotent ingestion",
    "INT-016",
    "integration conformance fixtures",
    "fail-closed chain config",
    "EIP-712 domain expectations",
    "duplicate log idempotency",
    "no-secret redaction diagnostics",
    "release manifest",
    "ABI surface",
    "address book",
    "deployment manifest",
    "ABI checksum",
    "event topic catalog",
    "interface IDs",
    "release checksums",
    "bytecode-to-release proof",
    "risk register",
    "public-beta evidence",
    "private keys",
    "secrets",
    "NEXT_PUBLIC_",
    "signer service",
    "backend signing service",
    "signed `DropAuthorization` fields",
    "`tokenData`",
    "public client",
    "wallet client",
    "contract client layer",
    "chain ID",
    "query key",
    "cache invalidation",
    "read-after-event",
    "confirmation depth",
    "reorg",
    "optimistic state",
    "transaction receipt",
    "custom errors",
    "toast",
    "telemetry",
    "MetadataUpdate",
    "BatchMetadataUpdate",
    "CollectionFrozen",
    "TokenBurned",
    "Transfer",
    "DependencyVersionPinned",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "animation sandbox",
    "iframe",
    "allow-scripts",
    "Electron",
    "mobile",
    "WalletConnect",
    "ERC-1271",
    "EIP-712",
]

REQUIRED_COMMANDS = [
    "python scripts/test_react_next_reference.py",
    "python scripts/check_react_next_reference.py",
    "python scripts/test_typescript_artifact_chain_config.py",
    "python scripts/check_typescript_artifact_chain_config.py",
    "python scripts/test_typescript_event_decoding_indexer.py",
    "python scripts/check_typescript_event_decoding_indexer.py",
    "python scripts/test_integration_conformance_fixtures.py",
    "python scripts/check_integration_conformance_fixtures.py",
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
    "docs/integrations/examples/react-viem.md",
    "docs/integrations/examples/typescript-artifacts-and-chain-config.md",
    "docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md",
    "docs/integrations/integration-conformance-fixtures.md",
    "docs/integrations/fixtures/integration-conformance-fixtures.json",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/deployment.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/release-readiness.md",
    "docs/release-policy.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/README.md",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
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


class ReactNextReferenceError(ValueError):
    """Raised when the frontend reference architecture guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ReactNextReferenceError(f"linked path escapes repository: {path}") from exc


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
            raise ReactNextReferenceError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)

    if missing:
        raise ReactNextReferenceError(
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


def validate_react_next_reference(repo_root: Path, document_path: Path) -> None:
    """Validate the React/Next frontend reference architecture guide."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise ReactNextReferenceError(f"missing React/Next reference doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise ReactNextReferenceError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise ReactNextReferenceError(
            "React/Next reference doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise ReactNextReferenceError(
            "React/Next reference doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise ReactNextReferenceError(
            "React/Next reference doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse React/Next reference checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--react-next-reference",
        type=Path,
        default=DEFAULT_REACT_NEXT_REFERENCE,
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the React/Next reference checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.react_next_reference
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_react_next_reference(repo_root, document_path.resolve())
    except ReactNextReferenceError as exc:
        print(f"React/Next reference check failed: {exc}", file=sys.stderr)
        return 1

    print("React/Next reference doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
