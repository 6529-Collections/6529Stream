#!/usr/bin/env python3
"""Validate the TypeScript event decoding and indexer ingestion guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_DOC = Path(
    "docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md"
)

REQUIRED_HEADINGS = [
    (1, "TypeScript Event Decoding And Indexer Ingestion Snippets"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Event Catalog Types"),
    (2, "Artifact Preflight"),
    (2, "Topic Dispatch"),
    (2, "Log Identity"),
    (2, "Decode Log Boundary"),
    (2, "Ingestion Actions"),
    (2, "Confirmation And Reorg Handling"),
    (2, "Read-After-Event Queue"),
    (2, "No-Secret Logging"),
    (2, "Testing And Fixtures"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "INT-015",
    "TypeScript snippets",
    "event decoding",
    "indexer ingestion",
    "event topic catalog",
    "ABI checksum",
    "wrong deployment",
    "wrong chain",
    "unknown emitter",
    "unknown `topic0`",
    "ABI/topic drift",
    "malformed logs",
    "idempotent log identities",
    "confirmation depth",
    "reorg rollback",
    "read-after-event",
    "no-secret",
    "fail closed",
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "not a generated SDK",
    "not an indexer service",
    "not retained marketplace/indexer evidence",
    "public beta",
    "production",
    "private keys",
    "raw signatures",
    "WalletConnect",
    "unreleased token data",
]

REQUIRED_CODE_TOKENS = [
    "type EventTopicCatalogEntry",
    "type EventTopicCatalog",
    "type StreamChainConfig",
    "assertEventArtifactPreflight",
    "makeDispatchTable",
    "dispatchKey",
    "type StreamRawLog",
    "type NormalizedLogIdentity",
    "normalizeLogIdentity",
    "type DecodedEvent",
    "type DecodeLog",
    "decodeStreamLog",
    "type IngestionAction",
    "handleDropAuthorizationConsumed",
    "type ReorgPolicy",
    "classifyLogFinality",
    "shouldRollbackFromBlock",
    "type ReadAfterEventTask",
    "makeReadAfterEventTask",
]

REQUIRED_COMMANDS = [
    "python scripts/test_typescript_event_decoding_indexer.py",
    "python scripts/check_typescript_event_decoding_indexer.py",
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_react_next_reference.py",
    "python scripts/check_react_next_reference.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_bytecode_release_proof.py",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "make typescript-event-decoding-indexer-check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/examples/react-viem.md",
    "docs/integrations/examples/typescript-artifacts-and-chain-config.md",
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/marketplace-indexer-evidence.md",
    "docs/release-readiness.md",
    "docs/public-beta-evidence.md",
    "docs/non-local-release-evidence.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/examples/anvil-6529stream-v0.1.0-001.json",
    "test/StreamEventReconstructability.t.sol",
    "test/StreamMinterEvents.t.sol",
    "test/StreamMetadataEvents.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class TypeScriptEventDecodingIndexerError(ValueError):
    """Raised when the TypeScript event decoding guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise TypeScriptEventDecodingIndexerError(
            f"linked path escapes repository: {path}"
        ) from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None
    path_part = target.split("#", 1)[0].split("?", 1)[0]
    return path_part or None


def label_looks_like_repo_path(label: str) -> bool:
    normalized = label.strip().strip("`")
    if any(character.isspace() for character in normalized):
        return False
    return "/" in normalized or "\\" in normalized or normalized.endswith((
        ".md",
        ".json",
        ".py",
        ".ps1",
        ".sh",
        ".sol",
    ))


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
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
            raise TypeScriptEventDecodingIndexerError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)
    if missing:
        raise TypeScriptEventDecodingIndexerError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    normalized_text = " ".join(text.lower().split())
    return [
        phrase
        for phrase in phrases
        if " ".join(phrase.lower().split()) not in normalized_text
    ]


def validate_typescript_event_decoding_indexer(
    repo_root: Path, document_path: Path
) -> None:
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise TypeScriptEventDecodingIndexerError(
            f"missing TypeScript event decoding guide: {relative}"
        )

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise TypeScriptEventDecodingIndexerError(
            "TypeScript event decoding guide is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise TypeScriptEventDecodingIndexerError(
            "TypeScript event decoding guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_code = [token for token in REQUIRED_CODE_TOKENS if token not in text]
    if missing_code:
        raise TypeScriptEventDecodingIndexerError(
            "TypeScript event decoding guide is missing required snippets: "
            + ", ".join(missing_code)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise TypeScriptEventDecodingIndexerError(
            "TypeScript event decoding guide is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise TypeScriptEventDecodingIndexerError(
            "TypeScript event decoding guide is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--doc", type=Path, default=DEFAULT_DOC)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.doc
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_typescript_event_decoding_indexer(repo_root, document_path.resolve())
    except TypeScriptEventDecodingIndexerError as exc:
        print(f"TypeScript event decoding indexer check failed: {exc}", file=sys.stderr)
        return 1

    print("TypeScript event decoding and indexer ingestion guide is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
