#!/usr/bin/env python3
"""Validate the external audit package index."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_PACKAGE = Path("docs/audit-package.md")

REQUIRED_HEADINGS = [
    (1, "External Audit Package"),
    (2, "Maturity And Scope"),
    (2, "Reviewer Entry Points"),
    (2, "Protocol Decisions"),
    (2, "Invariants And Test Evidence"),
    (2, "Static Analysis"),
    (2, "Deployment And Release Evidence"),
    (2, "Known Blockers And Accepted Risks"),
    (2, "Security Reporting"),
    (2, "Local Verification Commands"),
    (2, "Package Maintenance"),
]

REQUIRED_PHRASES = [
    "pre-audit",
    "not production-ready",
    "local baseline",
    "not a security claim",
]

REQUIRED_COMMANDS = [
    "python scripts/test_audit_package.py",
    "python scripts/check_audit_package.py",
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_public_beta_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
    "make check",
]

REQUIRED_LINK_TARGETS = [
    "README.md",
    "CONTRIBUTING.md",
    "SECURITY.md",
    "ops/ROADMAP.md",
    "ops/AUTONOMOUS_RUN.md",
    "ops/SLITHER_BASELINE.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/incident-response.md",
    "docs/release-readiness.md",
    "docs/status.md",
    "docs/known-blockers.md",
    "docs/slither.md",
    "docs/tooling.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
    "docs/public-beta-evidence.md",
    "docs/dependency-operations.md",
    "docs/randomizer-operations.md",
    "docs/auction-custody.md",
    "docs/metadata.md",
    "docs/vendored-libraries.md",
    "docs/adr/README.md",
    "docs/adr/0001-drop-authorization.md",
    "docs/adr/0002-auction-custody.md",
    "docs/adr/0003-payment-accounting.md",
    "docs/adr/0004-admin-governance.md",
    "docs/adr/0005-randomness.md",
    "docs/adr/0006-metadata-freeze.md",
    "docs/adr/0007-upgrade-redeployment.md",
    "release-artifacts/README.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/schema/public-beta-evidence.schema.json",
    "release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json",
    "deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json",
    "deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json",
    "test/StreamPaymentsInvariant.t.sol",
    "test/StreamSupplyReplayFreezeInvariant.t.sol",
    "test/StreamAuctionInvariant.t.sol",
    "test/StreamRandomizerPayments.t.sol",
    "test/StreamDeploymentManifest.t.sol",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class AuditPackageError(ValueError):
    pass


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise AuditPackageError(f"linked path escapes repository: {path}") from exc


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


def linked_repo_paths(repo_root: Path, package_path: Path, text: str) -> set[str]:
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        target = normalized_link_target(match.group(1))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = package_path.parent / target_path

        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        links.add(relative)

    if missing:
        raise AuditPackageError(
            "linked targets are missing: " + ", ".join(sorted(missing))
        )
    return links


def validate_audit_package(repo_root: Path, package_path: Path) -> None:
    if not package_path.is_file():
        raise AuditPackageError(f"missing audit package: {package_path}")

    text = package_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise AuditPackageError(
            "audit package is missing required headings: "
            + ", ".join(missing_headings)
        )

    normalized_text = text.lower()
    missing_phrases = [
        phrase for phrase in REQUIRED_PHRASES if phrase.lower() not in normalized_text
    ]
    if missing_phrases:
        raise AuditPackageError(
            "audit package is missing required maturity language: "
            + ", ".join(missing_phrases)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise AuditPackageError(
            "audit package is missing required verification commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, package_path, text)
    missing_targets = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_targets:
        raise AuditPackageError(
            "audit package is missing required links: " + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--package", type=Path, default=DEFAULT_PACKAGE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    package_path = args.package
    if not package_path.is_absolute():
        package_path = repo_root / package_path

    try:
        validate_audit_package(repo_root, package_path.resolve())
    except AuditPackageError as exc:
        print(f"audit package check failed: {exc}", file=sys.stderr)
        return 1

    print("audit package is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
