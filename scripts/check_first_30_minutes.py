#!/usr/bin/env python3
"""Validate the first-30-minutes contributor guide."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_GUIDE = Path("docs/first-30-minutes.md")

REQUIRED_HEADINGS = [
    (1, "First 30 Minutes"),
    (2, "What This Guide Proves"),
    (2, "Prerequisites"),
    (2, "Clone And Verify Tools"),
    (2, "Run The Local Gate"),
    (2, "Choose A Contribution Path"),
    (2, "Generated Artifact Drift"),
    (2, "Known Warning Noise"),
    (2, "Troubleshooting"),
    (2, "No Secrets And Maturity Boundaries"),
]

REQUIRED_PHRASES = [
    "fresh-contributor path",
    "pre-audit",
    "not production-ready",
    "does not prove protocol correctness",
    "without production secrets",
    "Foundry `v1.7.1`",
    "Solidity compiler `0.8.19`",
    "Python 3.8 or newer",
    "Slither `0.11.5`",
    "Windows PowerShell",
    "PowerShell wrapper",
    "`forge` is not on `PATH`",
    "docs-only changes",
    "Solidity or Foundry test changes",
    "release-artifact or generated-evidence changes",
    "generated artifact drift",
    "release manifest",
    "checksum bundle",
    "known and reviewed warning noise",
    "Do not commit private keys",
    "WalletConnect project secrets",
    "public beta remains blocked",
    "production release remains blocked",
]

REQUIRED_COMMANDS = [
    "bash scripts/bootstrap-ec2.sh",
    "powershell -ExecutionPolicy Bypass -File scripts\\bootstrap-windows.ps1",
    "git clone https://github.com/6529-Collections/6529Stream.git",
    "cd 6529Stream",
    "forge --version",
    "python --version",
    "python3 --version",
    "curl -L https://foundry.paradigm.xyz | bash",
    "foundryup --version v1.7.1",
    "$env:USERPROFILE + \"\\.foundry\\bin\"",
    "forge build",
    "forge test -vvv",
    "make check",
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1",
    "python scripts/test_first_30_minutes.py",
    "python scripts/check_first_30_minutes.py",
    "python scripts/test_readme.py",
    "python scripts/check_readme.py",
    "python scripts/test_release_manifest.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_release_checksums.py",
    "python scripts/generate_release_checksums.py --check",
    "python scripts/check_changelog.py",
    "forge test -vvv --match-path test/StreamCoreBurn.t.sol",
    "forge snapshot --match-path test/StreamGasSnapshot.t.sol --check release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
    "python scripts/run_forge_size_log.py --log cache/forge-size.log",
    "python scripts/check_contract_size_budget.py",
    "python scripts/check_core_bytecode_spend_policy.py",
    "python scripts/generate_risk_register.py",
    "python scripts/generate_public_beta_blocker_report.py",
    "python scripts/generate_production_release_blocker_report.py",
    "python scripts/generate_release_notes.py",
    "python scripts/generate_release_manifest.py",
    "python scripts/generate_bytecode_release_proof.py",
    "python scripts/generate_release_checksums.py",
    "python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log",
]

COMMAND_VARIANTS = {
    "powershell -ExecutionPolicy Bypass -File scripts\\bootstrap-windows.ps1": [
        "powershell -ExecutionPolicy Bypass -File scripts/bootstrap-windows.ps1",
    ],
    "powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\check.ps1": [
        "powershell -NoProfile -ExecutionPolicy Bypass -File scripts/check.ps1",
    ],
}

REQUIRED_LINK_TARGETS = [
    "README.md",
    "CONTRIBUTING.md",
    "CHANGELOG.md",
    "docs/status.md",
    "docs/release-readiness.md",
    "docs/known-blockers.md",
    "docs/tooling.md",
    "docs/warning-dispositions.md",
    "ops/ROADMAP.md",
    "ops/EXECUTION_BACKLOG.md",
    "scripts/check.sh",
    "scripts/check.ps1",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
FENCED_CODE_RE = re.compile(r"^```[^\n]*\n(.*?)^```", re.MULTILINE | re.DOTALL)


class First30MinutesError(ValueError):
    """Raised when the first-30-minutes guide is missing required content."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise First30MinutesError(f"linked path escapes repository: {path}") from exc


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
        raise First30MinutesError(
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


def validate_guide(repo_root: Path, document_path: Path) -> None:
    """Validate the contributor guide against setup and maturity requirements."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise First30MinutesError(f"missing guide: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise First30MinutesError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_required_phrases = missing_phrases(text, REQUIRED_PHRASES)
    if missing_required_phrases:
        raise First30MinutesError(
            "first-30-minutes guide is missing required content: "
            + ", ".join(missing_required_phrases)
        )

    missing_required_commands = missing_commands(text, REQUIRED_COMMANDS)
    if missing_required_commands:
        raise First30MinutesError(
            "first-30-minutes guide is missing required commands: "
            + ", ".join(missing_required_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise First30MinutesError(
            "first-30-minutes guide is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse first-30-minutes checker options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--guide", type=Path, default=DEFAULT_GUIDE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the first-30-minutes checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    guide_path = args.guide
    if not guide_path.is_absolute():
        guide_path = repo_root / guide_path

    try:
        validate_guide(repo_root, guide_path.resolve())
    except First30MinutesError as exc:
        print(f"first-30-minutes check failed: {exc}", file=sys.stderr)
        return 1

    print("first-30-minutes guide is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
