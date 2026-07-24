#!/usr/bin/env python3
"""Generate deterministic checksums for release and deployment artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
GENERATOR_VERSION = "1"

DEFAULT_COVERED_PATHS = [
    Path("requirements-tools.txt"),
    Path("requirements-tools.lock"),
    Path(".github/workflows/ci.yml"),
    Path(".github/workflows/release-mode.yml"),
    Path("Makefile"),
    Path("scripts/check.sh"),
    Path("scripts/check.ps1"),
    Path("scripts/check_python_toolchain.py"),
    Path("scripts/test_python_toolchain.py"),
    Path("scripts/build_release_artifacts.py"),
    Path("scripts/test_release_build_artifacts.py"),
    Path("scripts/materialize_canonical_deployment_plan.py"),
    Path("scripts/test_materialize_canonical_deployment_plan.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/test_release_checksums.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/test_release_manifest.py"),
    Path("scripts/generate_risk_register.py"),
    Path("scripts/check_risk_register.py"),
    Path("scripts/test_risk_register.py"),
    Path("release-artifacts/contracts.json"),
    Path("release-artifacts/genesis-deployment-profile.json"),
    Path("release-artifacts/stream-core-permanent-interface.json"),
    Path("release-artifacts/system-manifest-payload-vector.json"),
    Path("release-artifacts/README.md"),
    Path("release-artifacts/dependencies"),
    Path("release-artifacts/schema"),
    Path("release-artifacts/evidence"),
    Path("release-artifacts/drop-authorization-signing"),
    Path("release-artifacts/signer-custody-readiness"),
    Path("release-artifacts/permanence"),
    Path("release-artifacts/provenance"),
    Path("release-artifacts/signatures"),
    Path("release-artifacts/latest"),
    Path("release-artifacts/baselines"),
    Path("scripts/generate_dependency_provenance_attestation.py"),
    Path("scripts/check_release_mode.py"),
    Path("scripts/test_release_mode.py"),
    Path("scripts/check_genesis_deployment_profile.py"),
    Path("scripts/test_genesis_deployment_profile.py"),
    Path("ops/EXTERNAL_CALL_GAS_INVENTORY.json"),
    Path("scripts/check_external_call_gas_inventory.py"),
    Path("scripts/test_external_call_gas_inventory.py"),
    Path("scripts/check_abi_compatibility.py"),
    Path("scripts/test_abi_compatibility.py"),
    Path("scripts/check_governed_parameter_identifiers.py"),
    Path("scripts/test_governed_parameter_identifiers.py"),
    Path("scripts/generate_system_manifest_payload_vector.py"),
    Path("scripts/check_system_manifest_payload_vector.py"),
    Path("scripts/test_system_manifest_payload_vector.py"),
    Path("scripts/check_system_manifest_payload_vector_reference.py"),
    Path("scripts/test_system_manifest_payload_vector_reference.py"),
    Path("scripts/check_slither_baseline.py"),
    Path("scripts/test_slither_baseline.py"),
    Path("scripts/release_evidence_paths.py"),
    Path("scripts/check_production_broadcast_retention.py"),
    Path("scripts/check_production_verified_addresses.py"),
    Path("scripts/check_public_beta_verified_addresses.py"),
    Path("scripts/test_public_beta_verified_addresses.py"),
    Path("scripts/check_production_release_signing_evidence.py"),
    Path("scripts/test_production_release_signing_evidence.py"),
    Path("scripts/check_fork_metadata_browser_evidence.py"),
    Path("scripts/test_fork_metadata_browser_evidence.py"),
    Path("scripts/check_live_metadata_browser_evidence.py"),
    Path("scripts/check_incident_drill_evidence.py"),
    Path("scripts/check_signer_compromise_drill_evidence.py"),
    Path("scripts/test_signer_compromise_drill_evidence.py"),
    Path("scripts/check_stuck_auction_drill_evidence.py"),
    Path("scripts/test_stuck_auction_drill_evidence.py"),
    Path("scripts/check_failed_randomness_drill_evidence.py"),
    Path("scripts/test_failed_randomness_drill_evidence.py"),
    Path("scripts/check_bad_metadata_dependency_drill_evidence.py"),
    Path("scripts/test_bad_metadata_dependency_drill_evidence.py"),
    Path("scripts/check_readme.py"),
    Path("scripts/test_readme.py"),
    Path("scripts/check_first_30_minutes.py"),
    Path("scripts/test_first_30_minutes.py"),
    Path("docs/first-30-minutes.md"),
    Path("scripts/check_audit_finding_workflow.py"),
    Path("scripts/test_audit_finding_workflow.py"),
    Path("docs/audit-finding-workflow.md"),
    Path(".github/ISSUE_TEMPLATE/audit_finding.yml"),
    Path(".github/ISSUE_TEMPLATE/bug_report.yml"),
    Path(".github/ISSUE_TEMPLATE/config.yml"),
    Path(".github/ISSUE_TEMPLATE/integration_report.yml"),
    Path(".github/ISSUE_TEMPLATE/release_evidence.yml"),
    Path(".github/ISSUE_TEMPLATE/roadmap_item.yml"),
    Path(".github/PULL_REQUEST_TEMPLATE.md"),
    Path("scripts/check_issue_templates.py"),
    Path("scripts/test_issue_templates.py"),
    Path("scripts/check_pr_template.py"),
    Path("scripts/test_pr_template.py"),
    Path("scripts/check_markdown_links.py"),
    Path("scripts/test_markdown_links.py"),
    Path("scripts/check_monitoring_spec.py"),
    Path("scripts/test_monitoring_spec.py"),
    Path("docs/monitoring.md"),
    Path("scripts/check_operator_dashboard_query_model.py"),
    Path("scripts/test_operator_dashboard_query_model.py"),
    Path("docs/operator-dashboard-query-model.md"),
    Path("scripts/check_curator_rewards_flow.py"),
    Path("scripts/test_curator_rewards_flow.py"),
    Path("scripts/check_withdrawals_credits_flow.py"),
    Path("scripts/test_withdrawals_credits_flow.py"),
    Path("scripts/check_react_next_reference.py"),
    Path("scripts/test_react_next_reference.py"),
    Path("scripts/check_typescript_artifact_chain_config.py"),
    Path("scripts/test_typescript_artifact_chain_config.py"),
    Path("scripts/check_typescript_eip712_drop_authorization.py"),
    Path("scripts/test_typescript_eip712_drop_authorization.py"),
    Path("scripts/check_typescript_event_decoding_indexer.py"),
    Path("scripts/test_typescript_event_decoding_indexer.py"),
    Path("scripts/check_integration_conformance_fixtures.py"),
    Path("scripts/test_integration_conformance_fixtures.py"),
    Path("docs/integrations/fixtures/integration-conformance-fixtures.json"),
    Path("scripts/check_warning_dispositions.py"),
    Path("scripts/test_warning_dispositions.py"),
    Path("scripts/check_mint_manager_domain_constants.py"),
    Path("scripts/test_mint_manager_domain_constants.py"),
    Path("scripts/run_forge_size_log.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/verify_release_artifacts.py"),
    Path("deployments/broadcasts"),
    Path("deployments/config"),
    Path("deployments/examples"),
    Path("deployments/address-books"),
    Path("deployments/schema"),
    Path("deployments/ceremony-evidence"),
    Path("deployments/admin-ceremony"),
    Path("deployments/randomizer-operations"),
    Path("test/fixtures/drop-authorization"),
    Path("test/fixtures/warning-dispositions"),
    Path("CHANGELOG.md"),
    Path("README.md"),
    Path("slither.config.json"),
    Path("foundry.toml"),
    Path("ops/SLITHER_BASELINE.json"),
    Path("ops/SLITHER_BASELINE.md"),
    Path("ops/ROADMAP.md"),
    Path("ops/EXECUTION_BACKLOG.md"),
    Path("docs/architecture.md"),
    Path("docs/adr/README.md"),
    Path("docs/adr/0004-admin-governance.md"),
    Path("docs/adr/0008-revenue-splits-and-royalty-resolver.md"),
    Path("docs/adr/0010-world-class-spec-pass.md"),
    Path("docs/adr/0011-world-class-pass-round-2.md"),
    Path("docs/adr/0012-world-class-pass-round-3.md"),
    Path("docs/adr/0013-world-class-pass-round-4.md"),
    Path("docs/adr/0014-world-class-pass-round-5.md"),
    Path("docs/adr/0016-core-native-only-erc721.md"),
    Path("docs/adr/0017-raise-only-parameter-governance.md"),
    Path("docs/audit-package.md"),
    Path("docs/custom-errors.md"),
    Path("docs/dependency-operations.md"),
    Path("docs/deployment.md"),
    Path("docs/drop-authorization-signing.md"),
    Path("docs/incident-response.md"),
    Path("docs/known-blockers.md"),
    Path("docs/launch-v1-target-architecture.md"),
    Path("docs/launch-conformance-matrix.md"),
    Path("docs/revenue-splits-and-royalties.md"),
    Path("docs/mint-policy-and-accounting.md"),
    Path("docs/stream-sales-and-auctions.md"),
    Path("docs/stream-artist-authority.md"),
    Path("docs/metadata-router-and-renderer.md"),
    Path("docs/collection-metadata-contract.md"),
    Path("docs/stream-entropy-coordinator.md"),
    Path("docs/stream-entropy-providers.md"),
    Path("docs/stream-long-term-architecture.md"),
    Path("docs/integrations/README.md"),
    Path("docs/integrations/auction-flows.md"),
    Path("docs/integrations/contract-flows.md"),
    Path("docs/integrations/curator-rewards.md"),
    Path("docs/integrations/electron-security-wallets.md"),
    Path("docs/integrations/events-and-indexing.md"),
    Path("docs/integrations/frontend-reference-architecture.md"),
    Path("docs/integrations/integration-conformance-fixtures.md"),
    Path("docs/integrations/interface-versioning.md"),
    Path("docs/integrations/marketplace-indexer-evidence.md"),
    Path("docs/integrations/metadata-rendering.md"),
    Path("docs/integrations/mobile-walletconnect.md"),
    Path("docs/integrations/operator-admin-ui.md"),
    Path("docs/integrations/wallets-and-signatures.md"),
    Path("docs/integrations/withdrawals-and-credits.md"),
    Path("docs/integrations/examples/react-viem.md"),
    Path("docs/integrations/examples/typescript-artifacts-and-chain-config.md"),
    Path("docs/integrations/examples/typescript-eip712-drop-authorization.md"),
    Path("docs/integrations/examples/typescript-event-decoding-and-indexer-ingestion.md"),
    Path("docs/natspec-coverage.md"),
    Path("docs/non-local-release-evidence.md"),
    Path("docs/permanence-packages.md"),
    Path("docs/protocol-surface.md"),
    Path("docs/provenance-manifests.md"),
    Path("docs/public-beta-evidence.md"),
    Path("docs/randomizer-operations.md"),
    Path("docs/release-policy.md"),
    Path("docs/production-readiness-execution.md"),
    Path("docs/release-readiness.md"),
    Path("docs/release-signatures.md"),
    Path("docs/royalty-policy.md"),
    Path("docs/signer-custody-readiness.md"),
    Path("docs/slither.md"),
    Path("docs/status.md"),
    Path("docs/threat-model.md"),
    Path("docs/tooling.md"),
    Path("docs/warning-dispositions.md"),
]
DEFAULT_OUTPUT_DIR = Path("release-artifacts/latest")
CHECKSUM_FILE_NAME = "SHA256SUMS"
CHECKSUM_MANIFEST_NAME = "release-checksums.json"
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


class ChecksumError(RuntimeError):
    pass


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    with path.open("rb") as handle:
        return sha256_bytes(handle.read())


def read_text(path: Path) -> str:
    with path.open("r", encoding="utf-8") as handle:
        return handle.read()


def json_text(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    if path.is_absolute():
        return path
    return repo_root / path


def output_paths(output_dir: Path) -> set[Path]:
    return {
        (output_dir / CHECKSUM_FILE_NAME).resolve(),
        (output_dir / CHECKSUM_MANIFEST_NAME).resolve(),
    }


def collect_files(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> list[Path]:
    excluded = output_paths(output_dir)
    files_by_relative_path: dict[str, Path] = {}

    for configured_path in covered_paths:
        root = resolve_repo_path(repo_root, configured_path)
        if not root.exists():
            raise ChecksumError(f"covered path does not exist: {configured_path}")

        if root.is_file():
            candidates = [root]
        elif root.is_dir():
            candidates = sorted(path for path in root.rglob("*") if path.is_file())
        else:
            raise ChecksumError(f"covered path is neither a file nor directory: {configured_path}")

        for candidate in candidates:
            if candidate.resolve() in excluded:
                continue
            relative_path = normalize_path(candidate, repo_root)
            if relative_path in files_by_relative_path:
                raise ChecksumError(f"covered path listed more than once: {relative_path}")
            files_by_relative_path[relative_path] = candidate

    if not files_by_relative_path:
        raise ChecksumError("covered paths did not contain any files")

    return [files_by_relative_path[key] for key in sorted(files_by_relative_path)]


def build_checksum_lines(files: list[Path], repo_root: Path) -> list[str]:
    lines = []
    for path in files:
        digest = file_sha256(path).removeprefix("sha256:")
        lines.append(f"{digest}  {normalize_path(path, repo_root)}")
    return lines


def build_manifest(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    files: list[Path],
    checksum_text: str,
) -> dict[str, Any]:
    output_dir_relative = normalize_path(output_dir, repo_root)
    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME

    return {
        "schema_version": CHECKSUM_SCHEMA,
        "generated_by": f"scripts/generate_release_checksums.py:{GENERATOR_VERSION}",
        "algorithm": "sha256",
        "source": {
            "covered_paths": [
                normalize_path(resolve_repo_path(repo_root, path), repo_root)
                for path in covered_paths
            ],
            "output_dir": output_dir_relative,
        },
        "text_checksum_file": {
            "path": normalize_path(checksum_path, repo_root),
            "format": "sha256sum",
            "sha256": sha256_bytes(checksum_text.encode("utf-8")),
        },
        "manifest_file": {
            "path": normalize_path(manifest_path, repo_root),
            "self_hash": False,
        },
        "files": [
            {
                "path": normalize_path(path, repo_root),
                "sha256": file_sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in files
        ],
    }


def build_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
) -> tuple[str, str]:
    files = collect_files(repo_root, covered_paths, output_dir)
    checksum_text = "\n".join(build_checksum_lines(files, repo_root)) + "\n"
    manifest = build_manifest(repo_root, covered_paths, output_dir, files, checksum_text)
    return checksum_text, json_text(manifest)


def write_outputs(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> list[Path]:
    checksum_text, manifest_text = build_outputs(repo_root, covered_paths, output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME
    checksum_path.write_text(checksum_text, encoding="utf-8", newline="\n")
    manifest_path.write_text(manifest_text, encoding="utf-8", newline="\n")
    return [checksum_path, manifest_path]


def parse_checksum_file(checksum_text: str) -> list[tuple[str, str]]:
    entries = []
    for line_number, line in enumerate(checksum_text.splitlines(), start=1):
        if not line:
            continue
        if "  " not in line:
            raise ChecksumError(f"malformed checksum line {line_number}: missing separator")
        digest, relative_path = line.split("  ", 1)
        if not SHA256_RE.fullmatch(digest):
            raise ChecksumError(f"malformed checksum line {line_number}: invalid sha256")
        if relative_path.startswith("/") or "\\" in relative_path:
            raise ChecksumError(f"malformed checksum line {line_number}: invalid path")
        if ".." in Path(relative_path).parts:
            raise ChecksumError(f"malformed checksum line {line_number}: path traversal")
        entries.append((digest, relative_path))
    return entries


def verify_committed_checksum_file(repo_root: Path, checksum_text: str) -> list[str]:
    mismatches = []
    for digest, relative_path in parse_checksum_file(checksum_text):
        path = repo_root / relative_path
        if not path.exists():
            mismatches.append(
                f"missing covered file listed in {CHECKSUM_FILE_NAME}: {relative_path}"
            )
            continue
        current_digest = file_sha256(path).removeprefix("sha256:")
        if current_digest != digest:
            mismatches.append(f"hash mismatch for {relative_path}")
    return mismatches


def check_outputs(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> int:
    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME
    mismatches = []

    if not checksum_path.exists():
        mismatches.append(f"missing {normalize_path(checksum_path, repo_root)}")
    if not manifest_path.exists():
        mismatches.append(f"missing {normalize_path(manifest_path, repo_root)}")

    if not mismatches:
        try:
            checksum_text = read_text(checksum_path)
            mismatches.extend(verify_committed_checksum_file(repo_root, checksum_text))
        except ChecksumError as exc:
            mismatches.append(str(exc))

    try:
        expected_checksum_text, expected_manifest_text = build_outputs(
            repo_root, covered_paths, output_dir
        )
    except ChecksumError as exc:
        mismatches.append(str(exc))
        expected_checksum_text = None
        expected_manifest_text = None

    if (
        expected_checksum_text is not None
        and checksum_path.exists()
        and read_text(checksum_path) != expected_checksum_text
    ):
        mismatches.append(f"changed {normalize_path(checksum_path, repo_root)}")
    if (
        expected_manifest_text is not None
        and manifest_path.exists()
        and read_text(manifest_path) != expected_manifest_text
    ):
        mismatches.append(f"changed {normalize_path(manifest_path, repo_root)}")

    if mismatches:
        print("release checksum bundle is out of date:", file=sys.stderr)
        for mismatch in mismatches:
            print(f"  - {mismatch}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_checksums.py` and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    print("release checksum bundle is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--covered-path", type=Path, action="append", dest="covered_paths")
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    covered_paths = args.covered_paths or DEFAULT_COVERED_PATHS
    output_dir = args.output_dir

    try:
        if args.check:
            return check_outputs(repo_root, covered_paths, output_dir)
        written = write_outputs(repo_root, covered_paths, output_dir)
    except ChecksumError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
