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
    "bytecode-to-release proof",
    "live bytecode proof",
    "source verification inputs",
    "ceremony evidence",
    "randomizer operations evidence",
    "release-signature evidence",
    "signed release tag gate",
    "post-bundle release-signature evidence",
    "public-beta evidence status",
    "risk register",
    "release evidence packet index",
    "release evidence issue backlog",
    "release evidence issue links",
    "release evidence issue body sync",
    "release evidence issue closure readiness",
    "release evidence live audit report bundle",
    "release evidence live audit report schema",
    "release evidence live audit Markdown parity",
    "release evidence live audit report archive",
    "release-artifacts/evidence/live-audit-reports/",
    "YYYYMMDDTHHMMSSZ",
    "production broadcast retention checker",
    "production broadcast retention retained artifact",
    "production verified-addresses checker",
    "production verified-addresses retained artifact",
    "--generated-at",
    "no secrets",
    "release-mode CI profile",
    "manual workflow_dispatch",
    "expected to fail until retained evidence is complete",
    "release mode requires public-beta readiness before production-release readiness",
    "snapshot_freshness",
    "currentness_claim",
    "profile_generated_at",
    "not readiness proof by themselves",
    "non-local release evidence",
    "incident response",
    "integration entrypoint",
    "fixed-price mint and drop authorization flow spec",
    "auction frontend and indexer flow spec",
    "wallet, EIP-712, ERC-1271, and Safe signing guide",
    "event and indexer reconstruction spec",
    "metadata rendering, cache, animation sandbox, and marketplace integration guide",
    "ONE-005",
    "retained marketplace/indexer evidence",
    "OpenSea",
    "Reservoir",
    "Blur",
    "Manifold",
    "React/Next frontend reference architecture",
    "maintained frontend package",
    "generated SDK",
    "mobile and WalletConnect integration guide",
    "maintained mobile SDK",
    "React Native app",
    "WalletConnect dependency recommendation",
    "Electron security and wallet integration guide",
    "maintained Electron app",
    "native desktop app",
    "desktop SDK",
    "code-signing implementation",
    "signed-update implementation",
    "operator admin UI specification",
    "maintained operator dashboard",
    "Safe app",
    "multisig transaction builder",
    "monitoring service",
    "production signer custody implementation",
    "drop authorization signing fixtures",
    "unsigned payload-generator examples",
    "drop authorization signing evidence",
    "signer custody readiness",
    "1/1 provenance manifest",
    "artist/story/authenticity",
    "collector-verifiable permanence package",
    "one-of-one permanence manifest",
    "browser proof",
    "fully on-chain versus decentralized storage",
    "royalty policy",
    "ERC-2981 disclosure",
    "royalty disclosure, not payment enforcement",
    "No production-readiness claim depends on marketplaces honoring royalties",
    "warning disposition baseline",
    "NatSpec coverage baseline",
    "burn-down queue",
    "fixed NatSpec warning noise",
    "accepted solc, documentation, linter, vendored, test-only, ABI-compatibility",
    "StreamCore size-tradeoff warning decisions",
    "token finality",
    "marketplace readiness",
    "royalty enforcement",
    "ownership proof beyond chain state",
    "Slither baseline",
    "test matrix",
    "ADR index",
]

REQUIRED_COMMANDS = [
    "python scripts/test_release_readiness.py",
    "python scripts/check_release_readiness.py",
    "python scripts/test_release_mode.py",
    "python scripts/check_release_mode.py --phase public-beta",
    "python scripts/check_release_mode.py --phase production-release",
    "python scripts/test_production_broadcast_retention.py",
    "python scripts/check_production_broadcast_retention.py",
    "python scripts/test_production_verified_addresses.py",
    "python scripts/check_production_verified_addresses.py",
    "python scripts/test_signed_release_tag.py",
    "python scripts/check_signed_release_tag.py",
    "python scripts/test_incident_response.py",
    "python scripts/check_incident_response.py",
    "python scripts/test_contract_flows.py",
    "python scripts/check_contract_flows.py",
    "python scripts/test_auction_flows.py",
    "python scripts/check_auction_flows.py",
    "python scripts/test_wallet_signature_flows.py",
    "python scripts/check_wallet_signature_flows.py",
    "python scripts/test_events_and_indexing.py",
    "python scripts/check_events_and_indexing.py",
    "python scripts/test_metadata_rendering.py",
    "python scripts/check_metadata_rendering.py",
    "python scripts/test_marketplace_indexer_evidence.py",
    "python scripts/check_marketplace_indexer_evidence.py",
    "python scripts/test_react_next_reference.py",
    "python scripts/check_react_next_reference.py",
    "python scripts/test_mobile_walletconnect.py",
    "python scripts/check_mobile_walletconnect.py",
    "python scripts/test_electron_security_wallets.py",
    "python scripts/check_electron_security_wallets.py",
    "python scripts/test_operator_admin_ui.py",
    "python scripts/check_operator_admin_ui.py",
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
    "python scripts/test_one_of_one_provenance_manifest.py",
    "python scripts/check_one_of_one_provenance_manifest.py",
    "python scripts/generate_one_of_one_provenance_manifest.py --check",
    "python scripts/test_one_of_one_permanence_package.py",
    "python scripts/check_one_of_one_permanence_package.py",
    "python scripts/generate_one_of_one_permanence_manifest.py --check",
    "python scripts/test_royalty_policy.py",
    "python scripts/check_royalty_policy.py",
    "python scripts/test_warning_dispositions.py",
    "python scripts/check_warning_dispositions.py",
    "python scripts/test_natspec_coverage.py",
    "python scripts/check_natspec_coverage.py",
    "python scripts/test_gas_envelopes.py",
    "python scripts/check_gas_envelopes.py",
    "python scripts/test_public_beta_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/test_risk_register.py",
    "python scripts/check_risk_register.py",
    "python scripts/generate_risk_register.py --check",
    "python scripts/test_production_release_blocker_report.py",
    "python scripts/generate_production_release_blocker_report.py --check",
    "python scripts/test_release_evidence_packet_index.py",
    "python scripts/generate_release_evidence_packet_index.py --check",
    "python scripts/test_release_evidence_issue_backlog.py",
    "python scripts/generate_release_evidence_issue_backlog.py --check",
    "python scripts/test_release_evidence_issue_links.py",
    "python scripts/check_release_evidence_issue_links.py",
    "python scripts/test_release_evidence_issue_snapshot.py",
    "python scripts/test_release_evidence_issue_snapshot_audit.py",
    (
        "python scripts/audit_release_evidence_issue_snapshots.py --report-json "
        "tmp/release-evidence-live-audit-report.json --report-md "
        "tmp/release-evidence-live-audit-report.md"
    ),
    "python scripts/test_release_evidence_live_audit_report.py",
    "python scripts/check_release_evidence_live_audit_report.py",
    "python scripts/test_release_evidence_live_audit_markdown.py",
    "python scripts/check_release_evidence_live_audit_markdown.py",
    "python scripts/test_release_evidence_live_audit_archive.py",
    "python scripts/generate_release_evidence_live_audit_archive.py --check",
    (
        "python scripts/audit_release_evidence_issue_snapshots.py --generated-at "
        "YYYYMMDDTHHMMSSZ --report-json "
        "release-artifacts/evidence/live-audit-reports/"
        "YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md "
        "release-artifacts/evidence/live-audit-reports/"
        "YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md"
    ),
    (
        "python scripts/check_release_evidence_live_audit_report.py --report-json "
        "release-artifacts/evidence/live-audit-reports/"
        "YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json"
    ),
    (
        "python scripts/check_release_evidence_live_audit_markdown.py --report-json "
        "release-artifacts/evidence/live-audit-reports/"
        "YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.json --report-md "
        "release-artifacts/evidence/live-audit-reports/"
        "YYYYMMDDTHHMMSSZ-release-evidence-live-audit-report.md"
    ),
    (
        "python scripts/generate_release_evidence_live_audit_archive.py "
        "--archive-dir release-artifacts/evidence/live-audit-reports"
    ),
    (
        "python scripts/generate_release_evidence_live_audit_archive.py "
        "--archive-dir release-artifacts/evidence/live-audit-reports --check"
    ),
    (
        "python scripts/check_signed_release_tag.py --mode release --tag vX.Y.Z "
        "--evidence path/to/post-bundle-release-signature-evidence.json"
    ),
    "python scripts/test_release_evidence_issue_labels.py",
    "python scripts/check_release_evidence_issue_labels.py",
    "python scripts/test_release_evidence_issue_body_sync.py",
    "python scripts/generate_release_evidence_issue_body_sync.py --check",
    "python scripts/test_release_evidence_issue_bodies.py",
    "python scripts/check_release_evidence_issue_bodies.py",
    "python scripts/test_release_evidence_issue_closure.py",
    "python scripts/check_release_evidence_issue_closure.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/test_bytecode_release_proof.py",
    "python scripts/generate_bytecode_release_proof.py --check",
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
    "docs/incident-response.md",
    "docs/integrations/README.md",
    "docs/integrations/contract-flows.md",
    "docs/integrations/auction-flows.md",
    "docs/integrations/wallets-and-signatures.md",
    "docs/integrations/events-and-indexing.md",
    "docs/integrations/metadata-rendering.md",
    "docs/integrations/marketplace-indexer-evidence.md",
    "docs/integrations/frontend-reference-architecture.md",
    "docs/integrations/mobile-walletconnect.md",
    "docs/integrations/electron-security-wallets.md",
    "docs/integrations/operator-admin-ui.md",
    "docs/integrations/examples/react-viem.md",
    "docs/architecture.md",
    "docs/threat-model.md",
    "docs/deployment.md",
    "docs/release-policy.md",
    "docs/release-signatures.md",
    "docs/public-beta-evidence.md",
    "docs/non-local-release-evidence.md",
    "docs/randomizer-operations.md",
    "docs/dependency-operations.md",
    "docs/drop-authorization-signing.md",
    "docs/signer-custody-readiness.md",
    "docs/provenance-manifests.md",
    "docs/permanence-packages.md",
    "docs/royalty-policy.md",
    "docs/warning-dispositions.md",
    "docs/natspec-coverage.md",
    "docs/slither.md",
    "docs/tooling.md",
    "docs/adr/README.md",
    "release-artifacts/README.md",
    "release-artifacts/latest/release-manifest.json",
    "release-artifacts/latest/bytecode-release-proof.json",
    "release-artifacts/latest/SHA256SUMS",
    "release-artifacts/latest/release-checksums.json",
    "release-artifacts/latest/risk-register.json",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/release-evidence-packet-index.json",
    "release-artifacts/latest/release-evidence-packet-index.md",
    "release-artifacts/latest/release-evidence-issue-backlog.json",
    "release-artifacts/latest/release-evidence-issue-backlog.md",
    "release-artifacts/latest/release-evidence-issue-links.json",
    "release-artifacts/latest/release-evidence-issue-body-sync.json",
    "release-artifacts/latest/release-evidence-issue-body-sync.md",
    "release-artifacts/latest/release-evidence-live-audit-report-archive.json",
    "release-artifacts/latest/release-evidence-live-audit-report-archive.md",
    "release-artifacts/latest/production-release-blockers.md",
    "release-artifacts/latest/source-verification-inputs.json",
    "release-artifacts/schema/public-beta-evidence.schema.json",
    "release-artifacts/schema/risk-register.schema.json",
    "release-artifacts/schema/release-evidence-live-audit-report.schema.json",
    "release-artifacts/evidence/release-evidence-live-audit-report-template.json",
    "release-artifacts/evidence/release-evidence-live-audit-report-template.md",
    "release-artifacts/evidence/live-audit-reports/README.md",
    "release-artifacts/schema/drop-authorization-signing-evidence.schema.json",
    "release-artifacts/drop-authorization-signing/drop-authorization-signing-evidence-template.json",
    "release-artifacts/drop-authorization-signing/drop-authorization-signing-retained-artifact.txt",
    "release-artifacts/schema/signer-custody-readiness.schema.json",
    "release-artifacts/signer-custody-readiness/signer-custody-readiness-template.json",
    "release-artifacts/signer-custody-readiness/signer-custody-readiness-retained-artifact.txt",
    "release-artifacts/schema/one-of-one-provenance-manifest.schema.json",
    "release-artifacts/provenance/one-of-one-provenance-template.provenance.json",
    "release-artifacts/provenance/one-of-one-provenance-retained-artifact-template.md",
    "release-artifacts/latest/one-of-one-provenance-manifest.json",
    "release-artifacts/schema/one-of-one-permanence-package.schema.json",
    "release-artifacts/permanence/one-of-one-permanence-template.permanence.json",
    "release-artifacts/permanence/one-of-one-permanence-retained-artifact-template.md",
    "release-artifacts/latest/one-of-one-permanence-manifest.json",
    "release-artifacts/baselines/v0.1.0/abi-surface.json",
    "release-artifacts/baselines/v0.1.0/gas-snapshot.snap",
    "release-artifacts/baselines/v0.1.0/gas-envelopes.json",
    "release-artifacts/baselines/v0.1.0/natspec-coverage.json",
    "deployments/ceremony-evidence/anvil-6529stream-v0.1.0-001-local.json",
    "deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json",
    "release-artifacts/signatures/anvil-6529stream-v0.1.0-001-local.json",
]

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")


class ReleaseReadinessError(ValueError):
    pass


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise ReleaseReadinessError(f"linked path escapes repository: {path}") from exc


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
        raise ReleaseReadinessError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = " ".join(text.lower().split())
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def validate_release_readiness(repo_root: Path, document_path: Path) -> None:
    """Validate the release-readiness dashboard against required evidence."""
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
    """Parse release-readiness checker command-line options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--release-readiness", type=Path, default=DEFAULT_RELEASE_READINESS)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the release-readiness checker CLI."""
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
