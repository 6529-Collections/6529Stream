#!/usr/bin/env python3
"""Validate the TypeScript EIP-712 drop authorization snippet guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_DOC = Path("docs/integrations/examples/typescript-eip712-drop-authorization.md")

REQUIRED_HEADINGS = [
    (1, "TypeScript EIP-712 Drop Authorization Snippets"),
    (2, "Maturity And Scope"),
    (2, "Source Of Truth"),
    (2, "Domain Construction"),
    (2, "Typed Data Shape"),
    (2, "Token Data Hash"),
    (2, "Drop Id Derivation"),
    (2, "Fixed-Price Payload"),
    (2, "Auction Payload"),
    (2, "Pre-Signature Validation"),
    (2, "Signer Boundary"),
    (2, "Submission Preflight"),
    (2, "No-Secret Logging"),
    (2, "Testing And Fixtures"),
    (2, "Validation Commands"),
    (2, "Maintenance"),
]

REQUIRED_PHRASES = [
    "INT-014",
    "TypeScript snippets",
    "EIP-712",
    "DropAuthorization",
    "domain construction",
    "typed-data",
    "drop ID derivation",
    "token data hashing",
    "sale-mode validation",
    "EOA",
    "ERC-1271",
    "Safe",
    "WalletConnect",
    "signerEpoch",
    "deadline",
    "consumedDropIds",
    "cancelledDropIds",
    "not production-ready",
    "not a security claim",
    "not a generated SDK",
    "not a signing service implementation",
    "fail closed",
    "wrong chain",
    "wrong verifying contract",
    "raw signatures",
    "unreleased token data",
    "no-secret",
]

REQUIRED_CODE_TOKENS = [
    "type DropAuthorizationDomain",
    "DROP_AUTHORIZATION_TYPES",
    "type DropAuthorizationMessage",
    "tokenDataHash",
    "deriveDropId",
    "makeFixedPriceAuthorization",
    "makeAuctionAuthorization",
    "assertDropAuthorizationPreflight",
    "buildTypedDataToSign",
    "assertSubmissionMatchesAuthorization",
]

REQUIRED_COMMANDS = [
    "python scripts/test_typescript_eip712_drop_authorization.py",
    "python scripts/check_typescript_eip712_drop_authorization.py",
    "python scripts/test_integrations_readme.py",
    "python scripts/check_integrations_readme.py",
    "python scripts/test_wallet_signature_flows.py",
    "python scripts/check_wallet_signature_flows.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_bytecode_release_proof.py",
    "python scripts/generate_bytecode_release_proof.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "make typescript-eip712-drop-authorization-check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "docs/integrations/wallets-and-signatures.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/integrations/examples/typescript-artifacts-and-chain-config.md",
    "docs/release-readiness.md",
    "docs/public-beta-evidence.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "docs/adr/0001-drop-authorization.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "test/fixtures/drop-authorization/fixed-price-eoa.json",
    "test/fixtures/drop-authorization/auction-eoa.json",
    "test/fixtures/drop-authorization/erc1271-contract-signer.json",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
    "test/fixtures/drop-authorization/payload-generator/auction-output.json",
    "scripts/generate_drop_authorization_payload.py",
    "scripts/check_drop_authorization_fixtures.py",
    "smart-contracts/StreamDrops.sol",
    "test/StreamDropsEIP712.t.sol",
    "test/StreamDropsERC1271.t.sol",
    "test/StreamSafeERC1271ForkSmoke.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class TypeScriptEip712DropAuthorizationError(ValueError):
    """Raised when the TypeScript EIP-712 guide is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise TypeScriptEip712DropAuthorizationError(
            f"linked path escapes repository: {path}"
        ) from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    return {
        (len(match.group(1)), match.group(2).strip().rstrip("#").strip())
        for match in HEADING_RE.finditer(text)
    }


def normalized_link_target(raw_target: str) -> str | None:
    target = raw_target.strip()
    if not target or target.startswith("#") or "://" in target or target.startswith("mailto:"):
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
            raise TypeScriptEip712DropAuthorizationError(
                f"link label {label!r} resolves to {relative!r}"
            )
        links.add(relative)
    if missing:
        raise TypeScriptEip712DropAuthorizationError(
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


def validate_typescript_eip712_drop_authorization(
    repo_root: Path, document_path: Path
) -> None:
    if not document_path.is_file():
        raise TypeScriptEip712DropAuthorizationError(
            f"missing TypeScript EIP-712 guide: {normalize_repo_path(document_path, repo_root)}"
        )
    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise TypeScriptEip712DropAuthorizationError(
            "TypeScript EIP-712 guide is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise TypeScriptEip712DropAuthorizationError(
            "TypeScript EIP-712 guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_code = [token for token in REQUIRED_CODE_TOKENS if token not in text]
    if missing_code:
        raise TypeScriptEip712DropAuthorizationError(
            "TypeScript EIP-712 guide is missing required snippets: "
            + ", ".join(missing_code)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise TypeScriptEip712DropAuthorizationError(
            "TypeScript EIP-712 guide is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise TypeScriptEip712DropAuthorizationError(
            "TypeScript EIP-712 guide is missing required links: "
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
        validate_typescript_eip712_drop_authorization(repo_root, document_path.resolve())
    except TypeScriptEip712DropAuthorizationError as exc:
        print(f"TypeScript EIP-712 drop authorization check failed: {exc}", file=sys.stderr)
        return 1
    print("TypeScript EIP-712 drop authorization guide is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
