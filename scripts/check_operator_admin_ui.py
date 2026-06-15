#!/usr/bin/env python3
"""Validate the operator admin UI integration guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_OPERATOR_ADMIN_UI = Path("docs/integrations/operator-admin-ui.md")

REQUIRED_HEADINGS = [
    (1, "Operator Admin UI Specification"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Non-Goals"),
    (2, "Operator Personas"),
    (2, "Environment And Artifacts"),
    (2, "Permissions And Role Model"),
    (2, "Workflow Matrix"),
    (2, "Safe And Multisig Ceremony"),
    (2, "Signer Lifecycle"),
    (2, "Pause And Incident Controls"),
    (2, "Metadata And Dependency Operations"),
    (2, "Randomizer Operations"),
    (2, "Emergency Withdrawals And Surplus"),
    (2, "Monitoring Events And Indexer Reads"),
    (2, "UI Confirmation Model"),
    (2, "Testing Strategy"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "INT-010",
    "pre-audit",
    "local baseline",
    "not production-ready",
    "not a security claim",
    "does not replace fork/testnet/live evidence",
    "public beta",
    "production",
    "operator UI",
    "6529.io",
    "Safe",
    "multisig",
    "owner threshold",
    "deployer",
    "global admin",
    "function admin",
    "pause guardian",
    "unpause admin",
    "signer manager",
    "signer lifecycle target",
    "StreamAdmins",
    "registerAdmin",
    "registerFunctionAdmin",
    "registerBatchFunctionAdmin",
    "registerSignerManager",
    "registerSignerLifecycleTarget",
    "registerSignerFunctionAdmin",
    "registerBatchSignerFunctionAdmin",
    "registerPauseGuardian",
    "registerUnpauseAdmin",
    "setPaused",
    "updateEmergencyRecipient",
    "updateTDHsigner",
    "incrementSignerEpoch",
    "cancelDrop",
    "DropSignerChanged",
    "SignerEpochChanged",
    "DropAuthorizationCancelled",
    "PauseUpdated",
    "GlobalAdminUpdated",
    "FunctionAdminUpdated",
    "PauseGuardianUpdated",
    "UnpauseAdminUpdated",
    "SignerManagerUpdated",
    "SignerLifecycleTargetUpdated",
    "EmergencyRecipientUpdated",
    "DROP_EXECUTION",
    "MINT",
    "AUCTION_BID",
    "AUCTION_SETTLEMENT",
    "METADATA_MUTATION",
    "RANDOMNESS_REQUEST",
    "emergencyWithdrawable",
    "emergencyWithdraw",
    "EmergencyWithdrawal",
    "freezeCollection",
    "CollectionFrozen",
    "addRandomizer",
    "CollectionRandomizerUpdated",
    "DependencyVersionCreated",
    "DependencyVersionDeprecated",
    "DependencyVersionPinned",
    "randomizer epoch",
    "provider funding",
    "metadata freeze",
    "deployment manifest",
    "address book",
    "release manifest",
    "ABI checksum",
    "event topic catalog",
    "interface IDs",
    "risk register",
    "public-beta evidence",
    "private keys",
    "mnemonics",
    "RPC URLs",
    "API keys",
    "signer-service credentials",
    "unreleased drop payloads",
    "two-person review",
    "dry-run",
    "post-state read",
    "monitoring",
    "incident response",
    "not a maintained operator dashboard commitment",
]

REQUIRED_SECTION_PHRASES = {
    "Workflow Matrix": [
        "Root admin grant",
        "Function admin grant",
        "Signer manager grant",
        "Signer lifecycle target grant",
        "Signer function grant",
        "Pause role grant",
        "Pause domain update",
        "Emergency recipient update",
        "Drop signer rotation",
        "Signer epoch increment",
        "Drop cancellation",
        "Metadata freeze",
        "Randomizer update",
        "Dependency create or deprecate",
        "Emergency withdrawal",
    ],
    "Safe And Multisig Ceremony": [
        "Safe transaction",
        "owner threshold",
        "calldata decoded",
        "target contract address",
        "batch preview",
        "simulation or dry-run",
        "post-state reads",
    ],
    "UI Confirmation Model": [
        "Artifact check",
        "Pre-state read",
        "Risk classification",
        "Simulation or dry-run",
        "Human-readable diff",
        "Two-person review",
        "Safe transaction",
        "Post-state read",
        "Evidence attachment",
    ],
}

REQUIRED_COMMANDS = [
    "python scripts/test_operator_admin_ui.py",
    "python scripts/check_operator_admin_ui.py",
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
    "docs/integrations/mobile-walletconnect.md",
    "docs/integrations/electron-security-wallets.md",
    "docs/deployment.md",
    "docs/incident-response.md",
    "docs/signer-custody-readiness.md",
    "docs/randomizer-operations.md",
    "docs/drop-authorization-signing.md",
    "docs/metadata.md",
    "docs/dependency-operations.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/adr/0004-admin-governance.md",
    "docs/adr/0005-randomness.md",
    "docs/adr/0006-metadata-freeze.md",
    "docs/adr/0007-upgrade-redeployment.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/abi-checksums.json",
    "release-artifacts/latest/event-topic-catalog.json",
    "release-artifacts/latest/interface-ids.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "deployments/schema/deployment-manifest.schema.json",
    "deployments/schema/address-book.schema.json",
    "deployments/config/sepolia-6529stream-v0.1.0-001.template.json",
    "deployments/address-books/anvil-6529stream-v0.1.0-001.json",
    "deployments/address-books/fork-mainnet-6529stream-v0.1.0-001-broadcast.json",
    "smart-contracts/StreamAdmins.sol",
    "smart-contracts/StreamPauseDomains.sol",
    "smart-contracts/StreamDrops.sol",
    "smart-contracts/StreamCore.sol",
    "smart-contracts/AuctionContract.sol",
    "smart-contracts/StreamMinter.sol",
    "smart-contracts/StreamCuratorsPool.sol",
    "smart-contracts/DependencyRegistry.sol",
    "smart-contracts/RandomizerRNG.sol",
    "smart-contracts/RandomizerVRF.sol",
    "smart-contracts/StreamRandomizerLifecycle.sol",
    "test/StreamAdmins.t.sol",
    "test/StreamAdminSelectors.t.sol",
    "test/StreamCoreAdminCharacterization.t.sol",
    "test/StreamSignerAdmin.t.sol",
    "test/StreamPauseControls.t.sol",
    "test/StreamEmergencyWithdraw.t.sol",
    "test/StreamMetadataFreeze.t.sol",
    "test/StreamDependencyRegistry.t.sol",
    "test/StreamRandomizerLifecycle.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class OperatorAdminUiError(ValueError):
    """Raised when the operator admin UI guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise OperatorAdminUiError(f"linked path escapes repository: {path}") from exc


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

        normalized = normalize_repo_path(target_path, repo_root)
        if not target_path.exists():
            missing.append(normalized)
            continue
        if label_looks_like_repo_path(label) and label.replace("\\", "/") != normalized:
            raise OperatorAdminUiError(
                f"link label `{label}` points to `{normalized}` instead"
            )
        links.add(normalized)

    if missing:
        raise OperatorAdminUiError(
            "operator admin UI guide links to missing files: " + ", ".join(missing)
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


def validate_operator_admin_ui(repo_root: Path, document_path: Path) -> None:
    """Validate the operator admin UI guide."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise OperatorAdminUiError(f"missing operator admin UI guide: {relative}")

    text = document_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_required_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_required_headings:
        raise OperatorAdminUiError(
            "operator admin UI guide is missing required headings: "
            + ", ".join(missing_required_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise OperatorAdminUiError(
            "operator admin UI guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_section_content = []
    for heading, phrases in REQUIRED_SECTION_PHRASES.items():
        section = markdown_section(text, heading)
        for phrase in missing_phrases(section, phrases):
            missing_section_content.append(f"{heading}: {phrase}")
    if missing_section_content:
        raise OperatorAdminUiError(
            "operator admin UI guide has incomplete sections: "
            + ", ".join(missing_section_content)
        )

    command_lines = {line.strip() for line in text.splitlines()}
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in command_lines
    ]
    if missing_commands:
        raise OperatorAdminUiError(
            "operator admin UI guide is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_links = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_links:
        raise OperatorAdminUiError(
            "operator admin UI guide is missing required links: "
            + ", ".join(missing_links)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse operator admin UI checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument(
        "--operator-admin-ui", type=Path, default=DEFAULT_OPERATOR_ADMIN_UI
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the operator admin UI checker CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    document_path = args.operator_admin_ui
    if not document_path.is_absolute():
        document_path = repo_root / document_path

    try:
        validate_operator_admin_ui(repo_root, document_path.resolve())
    except OperatorAdminUiError as exc:
        print(f"operator admin UI guide check failed: {exc}", file=sys.stderr)
        return 1

    print("operator admin UI guide is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
