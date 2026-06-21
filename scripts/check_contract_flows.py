#!/usr/bin/env python3
"""Validate the integration contract-flow documentation."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_CONTRACT_FLOWS = Path("docs/integrations/contract-flows.md")

REQUIRED_HEADINGS = [
    (1, "Contract Flows"),
    (2, "Maturity And Scope"),
    (2, "Fixed-Price Mint Overview"),
    (2, "Source Of Truth"),
    (2, "Artifact Inputs"),
    (2, "Preflight Reads"),
    (2, "Authorization Payload"),
    (2, "Signing Paths"),
    (2, "Submit Transaction"),
    (2, "Events And Indexing"),
    (2, "Credits And Withdrawals"),
    (2, "Failure States"),
    (2, "Frontend State Machine"),
    (2, "Backend Signing Service Boundary"),
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
    "fixed-price mint",
    "DropAuthorization",
    "mintDrop",
    "saleMode = 1",
    "EIP-712",
    "ERC-1271",
    "domainSeparator",
    "deriveDropId",
    "tokenDataHash",
    "signerEpoch",
    "consumedDropIds",
    "cancelledDropIds",
    "DropAuthorizationConsumed",
    "FixedPriceCreditCreated",
    "FixedPriceCreditWithdrawn",
    "withdrawFixedPriceCreditTo",
    "fixedPricePosterCredits",
    "fixedPriceProtocolCredits",
    "fixedPriceCuratorReserveCredits",
    "totalFixedPriceOwed",
    "totalReserved",
    "surplus",
    "posterBps",
    "protocolBps",
    "curatorBps",
    "curatorBps = 0",
    "msg.value * posterBps / 10000",
    "msg.value * curatorBps / 10000",
    "msg.value - posterCredit - curatorReserveCredit",
    "proceedsSplitFor",
    "releaseFixedPriceCuratorReserveCredit",
    "testFixedPriceMintCreditsProceedsWithoutPushPayouts",
    "testFixedPriceOddWeiRemainderAccruesToProtocolCredit",
    "testOneWeiFixedPriceRemainderCreditsOnlyProtocol",
    "testFixedPriceContractSplitCanDisableCuratorReserve",
    "testFixedPriceCollectionAndTokenSplitsOverrideContractDefault",
    "DROP_EXECUTION",
    "wrong chain",
    "wrong domain",
    "expired",
    "cancelled",
    "consumed",
    "replay",
    "wrong signer",
    "zero recipient",
    "insufficient payment",
    "eth_call simulation",
    "StreamMinter",
    "StreamCore",
    "failed withdrawals preserve credit",
    "backend signing service",
    "no private keys",
]

REQUIRED_COMMANDS = [
    "python scripts/test_contract_flows.py",
    "python scripts/check_contract_flows.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/check_release_readiness.py",
    "python scripts/check_changelog.py",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/README.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/metadata.md",
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
    "smart-contracts/StreamDrops.sol",
    "test/StreamFixedPricePayments.t.sol",
    "test/StreamDropsEIP712.t.sol",
    "test/StreamDropsERC1271.t.sol",
    "test/fixtures/drop-authorization/fixed-price-eoa.json",
    "test/fixtures/drop-authorization/erc1271-contract-signer.json",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
    "scripts/generate_drop_authorization_payload.py",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class ContractFlowsError(ValueError):
    """Raised when the contract-flow docs are missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ContractFlowsError(f"linked path escapes repository: {path}") from exc


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
        raise ContractFlowsError(
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


def validate_contract_flows(repo_root: Path, document_path: Path) -> None:
    """Validate the contract-flow documentation."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise ContractFlowsError(f"missing contract flows doc: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise ContractFlowsError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise ContractFlowsError(
            "contract flows doc is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise ContractFlowsError(
            "contract flows doc is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise ContractFlowsError(
            "contract flows doc is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse contract-flow checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--contract-flows", type=Path, default=DEFAULT_CONTRACT_FLOWS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the contract-flow checker CLI."""
    args = parse_args([] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.contract_flows
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_contract_flows(repo_root, document_path.resolve())
    except ContractFlowsError as exc:
        print(f"contract flows check failed: {exc}", file=sys.stderr)
        return 1

    print("contract flows doc is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
