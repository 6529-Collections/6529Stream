#!/usr/bin/env python3
"""Validate the release-readiness dashboard."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_RELEASE_READINESS = Path("docs/release-readiness.md")

REQUIRED_HEADINGS = [
    (1, "Release Readiness"),
    (2, "Maturity And Scope"),
    (2, "Readiness Summary"),
    (2, "Local Evidence Already Passing"),
    (2, "Public Beta Blockers"),
    (2, "Production Release Blockers"),
    (2, "Required Evidence Links"),
    (2, "Release Commands"),
    (2, "Maintenance"),
]

REQUIRED_MATURITY_PHRASES = [
    "pre-audit",
    "not production-ready",
    "local baseline",
    "not a security claim",
    "local evidence does not replace fork/testnet/live evidence",
]

REQUIRED_READINESS_PHRASES = [
    "public beta",
    "fork/testnet/live evidence",
    "production signatures",
    "signed Git tags",
    "explorer verification",
    "verified deployed addresses",
    "external audit",
    "post-audit remediation",
    "release manifest",
    "checksum bundle",
    "source verification inputs",
    "ceremony evidence",
    "randomizer operations evidence",
    "release-signature evidence",
    "Slither baseline",
    "test matrix",
    "ADR index",
]

REQUIRED_COMMANDS = [
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "CHANGELOG.md",
    "ops/ROADMAP.md",
    "ops/AUTONOMOUS_RUN.md",
    "ops/SLITHER_BASELINE.md",
    "docs/release-readiness.md",
    "docs/status.md",
    "docs/known-blockers.md",
    "docs/audit-package.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
    "docs/randomizer-operations.md",
    "docs/dependency-operations.md",
    "docs/slither.md",
    "docs/tooling.md",
    "docs/adr/README.md",
    "release-artifacts/README.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/source-verification-inputs.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
    "deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json",
    "deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json",
    "release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class ReleaseReadinessError(ValueError):
    pass


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ReleaseReadinessError(f"linked path escapes repository: {path}") from exc


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
    if not path_part:
        return None
    return path_part


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
        raise ReleaseReadinessError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    normalized_text = text.lower()
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def validate_release_readiness(repo_root: Path, document_path: Path) -> None:
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise ReleaseReadinessError(f"missing document: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise ReleaseReadinessError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_maturity = missing_phrases(text, REQUIRED_MATURITY_PHRASES)
    if missing_maturity:
        raise ReleaseReadinessError(
            "release-readiness dashboard is missing required maturity language: "
            + ", ".join(missing_maturity)
        )

    missing_readiness = missing_phrases(text, REQUIRED_READINESS_PHRASES)
    if missing_readiness:
        raise ReleaseReadinessError(
            "release-readiness dashboard is missing required content: "
            + ", ".join(missing_readiness)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise ReleaseReadinessError(
            "release-readiness dashboard is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise ReleaseReadinessError(
            "release-readiness dashboard is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--release-readiness", type=Path, default=DEFAULT_RELEASE_READINESS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    release_readiness_path = args.release_readiness
    if not release_readiness_path.is_absolute():
        release_readiness_path = repo_root / release_readiness_path

    try:
        validate_release_readiness(repo_root, release_readiness_path.resolve())
    except ReleaseReadinessError as exc:
        print(f"release-readiness check failed: {exc}", file=sys.stderr)
        return 1

    print("release-readiness dashboard is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
