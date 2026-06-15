#!/usr/bin/env python3
"""Validate the royalty policy document."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ROYALTY_POLICY = Path("docs/royalty-policy.md")

REQUIRED_HEADINGS = [
    (1, "Royalty Policy"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Current ERC-2981 Behavior"),
    (2, "Royalty Philosophy"),
    (2, "Governance And Change Policy"),
    (2, "Enforcement Boundary"),
    (2, "Marketplace Display Guidance"),
    (2, "Integration Guidance"),
    (2, "Evidence And Readiness Boundaries"),
    (2, "Testing Strategy"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "ONE-003",
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "local baseline",
    "does not replace fork/testnet/live evidence",
    "ERC-2981",
    "IERC2981",
    "royaltyInfo()",
    "supportsInterface(0x2a55205a)",
    "fixed default royalty",
    "690 basis points",
    "0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377",
    "10,000",
    "no runtime royalty setters",
    "no per-token override",
    "no per-collection override",
    "royalty disclosure, not payment enforcement",
    "No production-readiness claim depends on marketplaces honoring royalties",
    "permissionless-transfer composability",
    "satellite royalty policy contract",
    "StreamCore size-budget exception",
    "changed royalty behavior is a breaking change",
    "sale router",
    "transfer validator",
    "operator filter",
    "ERC721C-style",
    "marketplace allowlist or blocklist",
    "royalty escrow",
    "royalty pull-payment accounting",
    "OpenSea",
    "Reservoir",
    "Blur",
    "Manifold",
    "marketplace support",
    "wallet/indexer risks",
    "retained fork/testnet/live evidence",
    "ONE-005",
    "retained marketplace/indexer evidence",
    "event topic catalog",
    "not release readiness proof",
]

REQUIRED_SECTION_PHRASES = {
    "Current ERC-2981 Behavior": [
        "royaltyInfo()",
        "supportsInterface(0x2a55205a)",
        "690 basis points",
        "no runtime royalty setters",
        "no per-token override",
        "no per-collection override",
    ],
    "Governance And Change Policy": [
        "Changing the default royalty receiver",
        "Changing `690 basis points`",
        "Adding per-token override support",
        "Adding per-collection override support",
        "Adding a satellite royalty policy contract",
        "Adding royalty enforcement",
    ],
    "Enforcement Boundary": [
        "ERC-2981 exposes royalty information",
        "does not enforce secondary-sale payment",
        "transfer validator",
        "ERC721C-style transfer restriction",
        "royalty pull-payment accounting",
    ],
    "Marketplace Display Guidance": [
        "OpenSea",
        "Reservoir",
        "Blur",
        "Manifold",
        "Display the returned receiver",
        "Avoid wording that implies payment was enforced",
    ],
    "Evidence And Readiness Boundaries": [
        "Public beta requires reviewed retained fork/testnet/live evidence",
        "Production requires the same evidence",
        "ONE-005",
    ],
}

REQUIRED_COMMANDS = [
    "python scripts/test_royalty_policy.py",
    "python scripts/check_royalty_policy.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_marketplace_indexer_evidence.py",
    "python scripts/check_marketplace_indexer_evidence.py",
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
    "docs/metadata.md",
    "docs/provenance-manifests.md",
    "docs/release-readiness.md",
    "docs/public-beta-evidence.md",
    "docs/non-local-release-evidence.md",
    "docs/release-policy.md",
    "docs/adr/0007-upgrade-redeployment.md",
    "docs/integrations/README.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/marketplace-indexer-evidence.md",
    "docs/integrations/wallets-and-signatures.md",
    "release-artifacts/contracts.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/risk-register.json",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/IERC2981.sol",
    "smart-contracts/ERC2981.sol",
    "test/StreamRoyalty.t.sol",
]

SOURCE_CONSTANT_ASSERTIONS = {
    "smart-contracts/StreamCore.sol": [
        "_DEFAULT_ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377",
        "_DEFAULT_ROYALTY_BPS = 690",
        "_ROYALTY_DENOMINATOR = 10_000",
        "type(IERC2981).interfaceId",
        "salePrice * _DEFAULT_ROYALTY_BPS / _ROYALTY_DENOMINATOR",
    ],
    "test/StreamRoyalty.t.sol": [
        "ERC2981_INTERFACE_ID = 0x2a55205a",
        "ROYALTY_RECEIVER = 0xC8ed02aFEBD9aCB14c33B5330c803feacAF01377",
        "ROYALTY_BPS = 690",
        "ROYALTY_DENOMINATOR = 10_000",
        "testDefaultRoyaltyIsFixedAt690BasisPoints",
    ],
}

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class RoyaltyPolicyError(ValueError):
    """Raised when the royalty policy document is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise RoyaltyPolicyError(f"linked path escapes repository: {path}") from exc


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
        normalized = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(normalized)
            continue
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != normalized:
            raise RoyaltyPolicyError(f"link label `{label}` points to `{normalized}`")
        links.add(normalized)

    if missing:
        raise RoyaltyPolicyError(
            "royalty policy links to missing files: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases not found after whitespace normalization."""
    normalized_text = re.sub(r"\s+", " ", text)
    return [
        phrase
        for phrase in phrases
        if re.sub(r"\s+", " ", phrase) not in normalized_text
    ]


def markdown_section(text: str, heading: str) -> str:
    """Return the body for a level-two Markdown section."""
    pattern = re.compile(
        rf"^## {re.escape(heading)}\s*$([\s\S]*?)(?=^## |\Z)",
        re.MULTILINE,
    )
    match = pattern.search(text)
    return "" if match is None else match.group(1)


def validate_source_constants(repo_root: Path) -> None:
    """Ensure documented royalty constants still match the source/tests."""
    missing = []
    for relative, snippets in SOURCE_CONSTANT_ASSERTIONS.items():
        source_path = repo_root / relative
        if not source_path.is_file():
            missing.append(f"{relative}: missing file")
            continue
        source = re.sub(r"\s+", " ", source_path.read_text(encoding="utf-8"))
        for snippet in snippets:
            normalized_snippet = re.sub(r"\s+", " ", snippet)
            if normalized_snippet not in source:
                missing.append(f"{relative}: {snippet}")

    if missing:
        raise RoyaltyPolicyError(
            "royalty source constants drifted from the policy: "
            + ", ".join(missing)
        )


def validate_royalty_policy(repo_root: Path, document_path: Path) -> None:
    """Validate the royalty policy document."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise RoyaltyPolicyError(f"missing royalty policy: {relative}")

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise RoyaltyPolicyError(
            "royalty policy is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise RoyaltyPolicyError(
            "royalty policy is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_section_content = []
    for heading, phrases in REQUIRED_SECTION_PHRASES.items():
        section = markdown_section(text, heading)
        for phrase in missing_phrases(section, phrases):
            missing_section_content.append(f"{heading}: {phrase}")
    if missing_section_content:
        raise RoyaltyPolicyError(
            "royalty policy has incomplete sections: "
            + ", ".join(missing_section_content)
        )

    command_lines = {line.strip() for line in text.splitlines()}
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise RoyaltyPolicyError(
            "royalty policy is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_links = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_links:
        raise RoyaltyPolicyError(
            "royalty policy is missing required links: "
            + ", ".join(missing_links)
        )

    validate_source_constants(repo_root)


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse royalty policy checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--royalty-policy", type=Path, default=DEFAULT_ROYALTY_POLICY)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the royalty policy checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    policy_path = args.royalty_policy
    if not policy_path.is_absolute():
        policy_path = repo_root / policy_path

    try:
        validate_royalty_policy(repo_root, policy_path.resolve())
    except RoyaltyPolicyError as exc:
        print(f"royalty policy check failed: {exc}", file=sys.stderr)
        return 1

    print("royalty policy is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
