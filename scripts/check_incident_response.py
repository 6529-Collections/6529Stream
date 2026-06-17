#!/usr/bin/env python3
"""Validate the protocol incident-response runbook."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_INCIDENT_RESPONSE = Path("docs/incident-response.md")

REQUIRED_HEADINGS = [
    (1, "Protocol Incident Response"),
    (2, "Maturity And Scope"),
    (2, "Roles And Severity"),
    (2, "Universal Triage"),
    (2, "Evidence Retention And Communications"),
    (2, "Runbook: Stuck Auctions Or Settlement"),
    (2, "Runbook: Failed Or Stale Randomness"),
    (2, "Runbook: Bad Merkle Roots Or Curator Claims"),
    (2, "Runbook: Bad Metadata Or Dependency Configuration"),
    (2, "Runbook: Signer Compromise Or Drop Authorization"),
    (2, "Runbook: Release Artifact Or Evidence Mistake"),
    (2, "Reopening And Post-Incident Review"),
    (2, "Local Verification Commands"),
    (2, "Maintenance"),
]

REQUIRED_MATURITY_PHRASES = [
    "pre-audit",
    "not production-ready",
    "not a security claim",
    "no-secret",
    "private reporting",
]

REQUIRED_INCIDENT_PHRASES = [
    "stuck auctions",
    "failed randomness",
    "stale randomness",
    "bad Merkle roots",
    "bad metadata",
    "dependency configuration",
    "signer compromise",
    "release artifact",
    "emergency pause",
    "withdrawal availability",
    "signer revocation",
    "retry/recovery",
    "evidence retention",
    "post-incident review",
]

REQUIRED_COMMANDS = [
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/test_incident_drill_evidence.py",
    "python scripts/check_incident_drill_evidence.py",
    "python scripts/test_signer_compromise_drill_evidence.py",
    "python scripts/check_signer_compromise_drill_evidence.py",
    "python scripts/test_drop_authorization_payload_generator.py",
    (
        "python scripts/generate_drop_authorization_payload.py --input "
        "test/fixtures/drop-authorization/payload-generator/fixed-price-input.json "
        "--output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json "
        "--check"
    ),
    (
        "python scripts/generate_drop_authorization_payload.py --input "
        "test/fixtures/drop-authorization/payload-generator/auction-input.json "
        "--output test/fixtures/drop-authorization/payload-generator/auction-output.json "
        "--check"
    ),
    "python scripts/test_drop_authorization_fixtures.py",
    "python scripts/check_drop_authorization_fixtures.py",
    "python scripts/test_drop_authorization_signing_evidence.py",
    "python scripts/check_drop_authorization_signing_evidence.py",
    "python scripts/test_signer_custody_readiness.py",
    "python scripts/check_signer_custody_readiness.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
    "make check",
    "powershell -ExecutionPolicy Bypass -File scripts\\check.ps1",
]

REQUIRED_LINK_TARGETS = [
    "SECURITY.md",
    "ops/ROADMAP.md",
    "docs/release-readiness.md",
    "docs/non-local-release-evidence.md",
    "docs/public-beta-evidence.md",
    "docs/tooling.md",
    "docs/randomizer-operations.md",
    "docs/dependency-operations.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/auction-custody.md",
    "docs/metadata.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/adr/0005-randomness.md",
    "docs/adr/0006-metadata-freeze.md",
    "docs/adr/0007-upgrade-redeployment.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json",
    "release-artifacts/schema/signer-custody-readiness.schema.json",
    "release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json",
    "release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt",
    "release-artifacts/evidence/incident-drills/incident-drill-retained-artifact-template.md",
    "release-artifacts/evidence/incident-drills/signer-compromise-drill-retained-artifact-template.md",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class IncidentResponseError(ValueError):
    """Raised when the incident-response runbook is incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise IncidentResponseError(f"linked path escapes repository: {path}") from exc


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
        raise IncidentResponseError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = text.lower()
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def validate_incident_response(repo_root: Path, document_path: Path) -> None:
    """Validate the incident-response runbook against required content."""
    if not document_path.is_file():
        relative = normalize_repo_path(document_path, repo_root)
        raise IncidentResponseError(f"missing document: {relative}")

    text = document_path.read_text(encoding="utf-8")

    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        relative = normalize_repo_path(document_path, repo_root)
        raise IncidentResponseError(
            f"{relative} is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing_maturity = missing_phrases(text, REQUIRED_MATURITY_PHRASES)
    if missing_maturity:
        raise IncidentResponseError(
            "incident-response runbook is missing required maturity language: "
            + ", ".join(missing_maturity)
        )

    missing_incidents = missing_phrases(text, REQUIRED_INCIDENT_PHRASES)
    if missing_incidents:
        raise IncidentResponseError(
            "incident-response runbook is missing required incident content: "
            + ", ".join(missing_incidents)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise IncidentResponseError(
            "incident-response runbook is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, document_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise IncidentResponseError(
            "incident-response runbook is missing required links: "
            + ", ".join(missing_targets)
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse incident-response checker command-line options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--incident-response", type=Path, default=DEFAULT_INCIDENT_RESPONSE)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the incident-response checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    incident_response_path = args.incident_response
    if not incident_response_path.is_absolute():
        incident_response_path = repo_root / incident_response_path

    try:
        validate_incident_response(repo_root, incident_response_path.resolve())
    except IncidentResponseError as exc:
        print(f"incident-response check failed: {exc}", file=sys.stderr)
        return 1

    print("incident-response runbook is current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
