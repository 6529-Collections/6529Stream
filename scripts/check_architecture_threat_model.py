#!/usr/bin/env python3
"""Validate the architecture and threat-model audit docs."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


DEFAULT_ARCHITECTURE = Path("docs/architecture.md")
DEFAULT_THREAT_MODEL = Path("docs/threat-model.md")

REQUIRED_HEADINGS = {
    DEFAULT_ARCHITECTURE: [
        (1, "Architecture"),
        (2, "Maturity And Scope"),
        (2, "System Components"),
        (2, "Actor And Role Boundaries"),
        (2, "Protocol Flows"),
        (2, "Value And Custody Boundaries"),
        (2, "Randomness And Metadata Boundaries"),
        (2, "Deployment And Release Boundaries"),
        (2, "Invariants And Evidence"),
        (2, "Known Gaps"),
        (2, "Maintenance"),
    ],
    DEFAULT_THREAT_MODEL: [
        (1, "Threat Model"),
        (2, "Maturity And Scope"),
        (2, "Assets"),
        (2, "Actors And Trust Boundaries"),
        (2, "Assumptions And Non-Goals"),
        (2, "Threat Categories"),
        (2, "Existing Controls"),
        (2, "Residual Risks And Open Blockers"),
        (2, "Evidence Links"),
        (2, "Maintenance"),
    ],
}

REQUIRED_MATURITY_PHRASES = [
    "pre-audit",
    "not production-ready",
    "local baseline",
    "not a security claim",
]

REQUIRED_ARCHITECTURE_PHRASES = [
    "StreamAdmins",
    "StreamCore",
    "StreamDrops",
    "StreamAuctions",
    "DependencyRegistry",
    "StreamCuratorsPool",
    "NextGenRandomizerVRF",
    "NextGenRandomizerRNG",
    "fixed-price",
    "auction",
    "pull credits",
    "randomizer",
    "metadata",
    "deployment",
    "release",
]

REQUIRED_THREAT_PHRASES = [
    "authorization and replay",
    "auction custody",
    "pull-payment credits",
    "randomizer lifecycle",
    "metadata rendering",
    "dependency supply chain",
    "deployment ceremony",
    "release signatures",
    "external integrations",
    "residual risk",
]

REQUIRED_COMMANDS = [
    "python scripts/test_architecture_threat_model.py",
    "python scripts/check_architecture_threat_model.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
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
    "docs/audit-package.md",
    "docs/status.md",
    "docs/known-blockers.md",
    "docs/slither.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
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
    "test/StreamPaymentsInvariant.t.sol",
    "test/StreamSupplyReplayFreezeInvariant.t.sol",
    "test/StreamAuctionInvariant.t.sol",
    "test/StreamRandomizerPayments.t.sol",
    "test/StreamDeploymentManifest.t.sol",
    "scripts/check_audit_package.py",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class ArchitectureThreatModelError(ValueError):
    pass


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ArchitectureThreatModelError(
            f"linked path escapes repository: {path}"
        ) from exc


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


def linked_repo_paths(repo_root: Path, documents: dict[Path, str]) -> set[str]:
    links = set()
    missing = []
    for document_path, text in documents.items():
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
        raise ArchitectureThreatModelError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    normalized_text = text.lower()
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def validate_document_headings(
    repo_root: Path,
    document_path: Path,
    text: str,
    required_headings: list[tuple[int, str]],
) -> None:
    headings = markdown_headings(text)
    missing = [
        f"{'#' * level} {title}"
        for level, title in required_headings
        if (level, title) not in headings
    ]
    if missing:
        relative = normalize_repo_path(document_path, repo_root)
        raise ArchitectureThreatModelError(
            f"{relative} is missing required headings: " + ", ".join(missing)
        )


def validate_architecture_threat_model(
    repo_root: Path, architecture_path: Path, threat_model_path: Path
) -> None:
    for document_path in [architecture_path, threat_model_path]:
        if not document_path.is_file():
            relative = normalize_repo_path(document_path, repo_root)
            raise ArchitectureThreatModelError(f"missing document: {relative}")

    documents = {
        architecture_path: architecture_path.read_text(encoding="utf-8"),
        threat_model_path: threat_model_path.read_text(encoding="utf-8"),
    }

    validate_document_headings(
        repo_root,
        architecture_path,
        documents[architecture_path],
        REQUIRED_HEADINGS[DEFAULT_ARCHITECTURE],
    )
    validate_document_headings(
        repo_root,
        threat_model_path,
        documents[threat_model_path],
        REQUIRED_HEADINGS[DEFAULT_THREAT_MODEL],
    )

    for document_path, text in documents.items():
        missing = missing_phrases(text, REQUIRED_MATURITY_PHRASES)
        if missing:
            relative = normalize_repo_path(document_path, repo_root)
            raise ArchitectureThreatModelError(
                f"{relative} is missing required maturity language: "
                + ", ".join(missing)
            )

    missing_architecture = missing_phrases(
        documents[architecture_path], REQUIRED_ARCHITECTURE_PHRASES
    )
    if missing_architecture:
        raise ArchitectureThreatModelError(
            "architecture is missing required content: "
            + ", ".join(missing_architecture)
        )

    missing_threats = missing_phrases(
        documents[threat_model_path], REQUIRED_THREAT_PHRASES
    )
    if missing_threats:
        raise ArchitectureThreatModelError(
            "threat model is missing required content: " + ", ".join(missing_threats)
        )

    combined_text = "\n".join(documents.values())
    missing_commands = [
        command for command in REQUIRED_COMMANDS if command not in combined_text
    ]
    if missing_commands:
        raise ArchitectureThreatModelError(
            "architecture/threat model docs are missing required commands: "
            + ", ".join(missing_commands)
        )

    architecture_links = linked_repo_paths(
        repo_root, {architecture_path: documents[architecture_path]}
    )
    threat_links = linked_repo_paths(
        repo_root, {threat_model_path: documents[threat_model_path]}
    )
    links = architecture_links | threat_links
    missing_targets = [
        target for target in REQUIRED_LINK_TARGETS if target not in links
    ]
    if missing_targets:
        raise ArchitectureThreatModelError(
            "architecture/threat model docs are missing required links: "
            + ", ".join(missing_targets)
        )

    architecture_relative = normalize_repo_path(architecture_path, repo_root)
    threat_relative = normalize_repo_path(threat_model_path, repo_root)
    if threat_relative not in architecture_links:
        raise ArchitectureThreatModelError(
            f"{architecture_relative} must link to {threat_relative}"
        )
    if architecture_relative not in threat_links:
        raise ArchitectureThreatModelError(
            f"{threat_relative} must link to {architecture_relative}"
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--architecture", type=Path, default=DEFAULT_ARCHITECTURE)
    parser.add_argument("--threat-model", type=Path, default=DEFAULT_THREAT_MODEL)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    architecture_path = args.architecture
    threat_model_path = args.threat_model
    if not architecture_path.is_absolute():
        architecture_path = repo_root / architecture_path
    if not threat_model_path.is_absolute():
        threat_model_path = repo_root / threat_model_path

    try:
        validate_architecture_threat_model(
            repo_root, architecture_path.resolve(), threat_model_path.resolve()
        )
    except ArchitectureThreatModelError as exc:
        print(f"architecture/threat model check failed: {exc}", file=sys.stderr)
        return 1

    print("architecture and threat model docs are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
