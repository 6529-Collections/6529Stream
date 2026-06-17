#!/usr/bin/env python3
"""Validate the repository README front door."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_README = Path("README.md")

REQUIRED_HEADINGS = [
    (1, "6529Stream"),
    (2, "Current Maturity"),
    (2, "First 30 Minutes"),
    (2, "Find Your Path"),
    (2, "Drop Flow"),
    (2, "Quickstart"),
    (2, "Tooling"),
    (2, "Repository Layout"),
    (2, "Important Docs"),
    (2, "Security"),
]

REQUIRED_PHRASES = [
    "pre-audit local baseline",
    "not production-ready",
    "not a security claim",
    "does not prove protocol correctness",
    "does not replace public beta or production release evidence",
    "reviewed fork/testnet or live deployment rehearsal",
    "signed release artifacts",
    "verified addresses",
    "explorer verification",
    "signer custody readiness",
    "production signing",
    "live metadata/indexer/marketplace evidence",
    "external audit",
    "post-audit remediation",
    "signed tag ceremony",
    "accepted release-mode evidence",
    "Foundry",
    "Solidity compiler",
    "Slither",
    "Auditor or security reviewer",
    "Integrator, frontend, mobile, Electron, or indexer engineer",
    "Operator or deployer",
    "Contributor",
    "Protocol maintainer",
    "EIP-712",
    "ERC-1271",
    "deploy-and-wire ceremony",
    "without production secrets",
    "root README itself is part of the gate",
    "release-impacting PRs",
    "Do not use these contracts for production drops",
]

REQUIRED_COMMANDS = [
    "make check",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1",
    "bash scripts/bootstrap-ec2.sh",
    "powershell -ExecutionPolicy Bypass -File scripts\\bootstrap-windows.ps1",
    "python scripts/test_readme.py",
    "python scripts/check_readme.py",
    "python scripts/test_first_30_minutes.py",
    "python scripts/check_first_30_minutes.py",
    "python scripts/test_issue_templates.py",
    "python scripts/check_issue_templates.py",
]

COMMAND_VARIANTS = {
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1",
    ],
    "powershell -ExecutionPolicy Bypass -File scripts\\bootstrap-windows.ps1": [
        "powershell -ExecutionPolicy Bypass -File scripts/bootstrap-windows.ps1",
    ],
}

REQUIRED_LINK_TARGETS = [
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "ops/ROADMAP.md",
    "ops/EXECUTION_BACKLOG.md",
    "ops/SLITHER_BASELINE.md",
    "ops/AUTONOMOUS_RUN.md",
    "docs/status.md",
    "docs/first-30-minutes.md",
    "docs/known-blockers.md",
    "docs/tooling.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/audit-package.md",
    "docs/adr/README.md",
    "docs/slither.md",
    "docs/deployment.md",
    "docs/randomizer-operations.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
    "docs/release-readiness.md",
    "docs/public-beta-evidence.md",
    "docs/incident-response.md",
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/mobile-walletconnect.md",
    "docs/integrations/electron-security-wallets.md",
    "docs/integrations/operator-admin-ui.md",
    "deployments/README.md",
    "release-artifacts/README.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/public-beta-blockers.md",
    "release-artifacts/latest/production-release-blockers.md",
    ".github/ISSUE_TEMPLATE/integration_report.yml",
    ".github/ISSUE_TEMPLATE/audit_finding.yml",
    ".github/ISSUE_TEMPLATE/release_evidence.yml",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCED_CODE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


class ReadmeError(ValueError):
    """Raised when the root README is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ReadmeError(f"linked path escapes repository: {path}") from exc


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
        raise ReadmeError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def fenced_command_lines(text: str) -> set[str]:
    """Return non-empty lines presented inside fenced Markdown code blocks."""
    command_lines = set()
    for match in FENCED_CODE_RE.finditer(text):
        for line in match.group(1).splitlines():
            stripped = line.strip()
            if stripped:
                command_lines.add(stripped)
    return command_lines


def missing_commands(text: str, commands: list[str]) -> list[str]:
    """Return required commands absent from fenced code blocks."""
    command_lines = fenced_command_lines(text)
    missing = []
    for command in commands:
        variants = [command, *COMMAND_VARIANTS.get(command, [])]
        if not any(variant in command_lines for variant in variants):
            missing.append(command)
    return missing


def validate_readme(repo_root: Path, document_path: Path) -> None:
    """Validate the root README against required maturity and navigation content."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise ReadmeError(f"missing README: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise ReadmeError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise ReadmeError(
            "README is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_required_commands = missing_commands(text, REQUIRED_COMMANDS)
    if missing_required_commands:
        raise ReadmeError(
            "README is missing required commands: "
            + ", ".join(missing_required_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise ReadmeError(
            "README is missing required links: " + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse README checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--readme", type=Path, default=DEFAULT_README)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the README checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    readme_path = args.readme
    if not readme_path.is_absolute():
        readme_path = repo_root / readme_path

    try:
        validate_readme(repo_root, readme_path.resolve())
    except ReadmeError as exc:
        print(f"README check failed: {exc}", file=sys.stderr)
        return 1

    print("README is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
