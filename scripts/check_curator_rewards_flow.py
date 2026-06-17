#!/usr/bin/env python3
"""Validate the curator rewards integration-flow documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_DOC = Path("docs/integrations/curator-rewards.md")

REQUIRED_HEADINGS = [
    (1, "Curator Rewards"),
    (2, "Maturity And Scope"),
    (2, "Curator Reward Overview"),
    (2, "Source Of Truth"),
    (2, "Artifact Inputs"),
    (2, "Root And Leaf Model"),
    (2, "Claim Preflight Reads"),
    (2, "Claim Transaction"),
    (2, "Delegated Claims"),
    (2, "Credits And Withdrawals"),
    (2, "Events And Indexing"),
    (2, "Failure States"),
    (2, "Frontend State Machine"),
    (2, "Operator And Admin Boundaries"),
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
    "StreamCuratorsPool",
    "claimRewards",
    "withdrawCuratorCreditTo",
    "setMerkleRoot",
    "setMultipleMerkleRoots",
    "collectionMerkleRoot",
    "collectionMerkleRootEpoch",
    "CURATOR_REWARD_LEAF_DOMAIN",
    "abi.encode",
    "block.chainid",
    "address(this)",
    "rootEpoch",
    "Do not use `abi.encodePacked`",
    "duplicate leaves",
    "wrong claimant",
    "wrong collection",
    "wrong amount",
    "stale root epoch",
    "double claims",
    "rewardsClaimPerAddress",
    "rewardsPerAddress",
    "curatorCredits",
    "totalCuratorOwed",
    "totalOwed",
    "surplus",
    "emergencyWithdrawable",
    "delegator",
    "delegate",
    "0x8888888888888888888888888888888888888888",
    "curator reward use case: `1`",
    "pull-payment",
    "failed withdrawal",
    "credit is preserved",
    "CuratorCreditCreated",
    "CuratorCreditWithdrawn",
    "MerkleRootUpdated",
    "Reward",
    "EmergencyWithdrawal",
    "emergency withdrawal is surplus-only",
    "totalReserved()` returns zero",
    "reward-service proof",
]

REQUIRED_COMMANDS = [
    "python scripts/test_curator_rewards_flow.py",
    "python scripts/check_curator_rewards_flow.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_changelog.py",
    "forge test --match-path test/StreamCuratorsPool.t.sol",
    "forge test --match-path test/StreamPaymentsInvariant.t.sol",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/generate_release_checksums.py --check",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/operator-admin-ui.md",
    "docs/release-readiness.md",
    "docs/public-beta-evidence.md",
    "docs/non-local-release-evidence.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/StreamAdmins.sol",
    "smart-contracts/IDelegationManagementContract.sol",
    "smart-contracts/StreamPauseDomains.sol",
    "test/StreamCuratorsPool.t.sol",
    "test/StreamPaymentsInvariant.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class CuratorRewardsFlowError(ValueError):
    """Raised when the curator rewards guide is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise CuratorRewardsFlowError(f"linked path escapes repository: {path}") from exc


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


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
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
        raise CuratorRewardsFlowError(
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


def validate_curator_rewards_flow(repo_root: Path, document_path: Path) -> None:
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise CuratorRewardsFlowError(f"missing curator rewards doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise CuratorRewardsFlowError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise CuratorRewardsFlowError(
            "curator rewards doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise CuratorRewardsFlowError(
            "curator rewards doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise CuratorRewardsFlowError(
            "curator rewards doc is missing required links: "
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
        validate_curator_rewards_flow(repo_root, document_path.resolve())
    except CuratorRewardsFlowError as exc:
        print(f"curator rewards flow check failed: {exc}", file=sys.stderr)
        return 1

    print("curator rewards flow doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
