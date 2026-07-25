#!/usr/bin/env python3
"""Generate deterministic checksums for release and deployment artifacts."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import re
import stat
import sys
from pathlib import Path
from typing import Any

import check_governed_parameter_inventory as governed_parameter_inventory_checker


CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
GENERATOR_VERSION = "1"
CANONICAL_COVERAGE_POLICY = "canonical"
CUSTOM_SUBSET_COVERAGE_POLICY = "custom-subset"
COVERAGE_POLICIES = (
    CANONICAL_COVERAGE_POLICY,
    CUSTOM_SUBSET_COVERAGE_POLICY,
)
RELEASE_TOOL_ROOTS = (
    Path("scripts/generate_risk_register.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/verify_release_artifacts.py"),
)
RELEASE_TOOL_FOCUSED_TESTS = (
    Path("scripts/test_changelog_check.py"),
    Path("scripts/test_release_notes.py"),
    Path("scripts/test_admin_ceremony_evidence.py"),
    Path("scripts/test_drop_authorization_signing_evidence.py"),
    Path("scripts/test_non_local_release_evidence.py"),
    Path("scripts/test_record_family_authorization.py"),
    Path("scripts/test_release_signatures.py"),
    Path("scripts/test_signer_custody_readiness.py"),
    Path("scripts/test_bytecode_release_proof.py"),
)
REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE = (
    Path("scripts/check_admin_ceremony_evidence.py"),
    Path("scripts/check_changelog.py"),
    Path("scripts/check_drop_authorization_signing_evidence.py"),
    Path("scripts/check_governed_parameter_identifiers.py"),
    Path("scripts/check_governed_parameter_inventory.py"),
    Path("scripts/check_non_local_release_evidence.py"),
    Path("scripts/check_public_beta_evidence.py"),
    Path("scripts/check_record_family_authorization.py"),
    Path("scripts/check_release_evidence_issue_links.py"),
    Path("scripts/check_release_signatures.py"),
    Path("scripts/check_risk_register.py"),
    Path("scripts/check_signer_custody_readiness.py"),
    Path("scripts/check_slither_baseline.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/generate_risk_register.py"),
    Path("scripts/release_evidence_paths.py"),
    Path("scripts/verify_release_artifacts.py"),
)

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
    Path("scripts/check_changelog.py"),
    Path("scripts/test_changelog_check.py"),
    Path("scripts/check_admin_ceremony_evidence.py"),
    Path("scripts/test_admin_ceremony_evidence.py"),
    Path("scripts/check_drop_authorization_signing_evidence.py"),
    Path("scripts/test_drop_authorization_signing_evidence.py"),
    Path("scripts/check_non_local_release_evidence.py"),
    Path("scripts/test_non_local_release_evidence.py"),
    Path("scripts/check_release_signatures.py"),
    Path("scripts/test_release_signatures.py"),
    Path("scripts/check_signer_custody_readiness.py"),
    Path("scripts/test_signer_custody_readiness.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/test_bytecode_release_proof.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/test_release_manifest.py"),
    Path("scripts/test_release_notes.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/test_release_candidate_lockfile.py"),
    Path("scripts/generate_risk_register.py"),
    Path("scripts/check_risk_register.py"),
    Path("scripts/test_risk_register.py"),
    Path("scripts/check_record_family_authorization.py"),
    Path("scripts/test_record_family_authorization.py"),
    Path("scripts/check_release_evidence_issue_links.py"),
    Path("scripts/test_release_evidence_issue_links.py"),
    Path("scripts/check_public_beta_evidence.py"),
    Path("scripts/test_public_beta_evidence.py"),
    Path("release-artifacts/contracts.json"),
    Path("release-artifacts/genesis-deployment-profile.json"),
    Path("release-artifacts/governed-parameter-inventory.json"),
    Path("release-artifacts/record-family-authorization-inventory.json"),
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
    Path("scripts/check_governed_parameter_inventory.py"),
    Path("scripts/test_governed_parameter_inventory.py"),
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
    Path("scripts/test_verify_release_artifacts.py"),
    Path("deployments/broadcasts"),
    Path("deployments/config"),
    Path("deployments/examples"),
    Path("deployments/address-books"),
    Path("deployments/schema"),
    Path(
        "deployments/record-family-authorization/"
        "record-family-authorization-evidence-template.json"
    ),
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
    Path("docs/adr/0018-batch-operation-root-and-token-identity.md"),
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


def complete_governed_parameter_references(
    inventory: dict[str, Any],
) -> list[tuple[Path, str, str]]:
    """Return candidate and evidence files from a validated inventory."""
    references: list[tuple[Path, str, str]] = []
    genesis_profile = inventory.get("genesis_profile")
    if genesis_profile is not None:
        references.append(
            (
                Path(genesis_profile["path"]),
                genesis_profile["sha256"],
                "genesis_profile",
            )
        )
    candidate = inventory["candidate_binding"]
    if candidate["status"] == "complete":
        references.append(
            (
                Path(candidate["candidate_artifact_path"]),
                candidate["candidate_artifact_sha256"],
                "candidate_binding",
            )
        )
        for index, binding in enumerate(candidate.get("host_bindings", [])):
            source_verification = binding["source_verification_binding"]
            references.append(
                (
                    Path(source_verification["path"]),
                    source_verification["sha256"],
                    (
                        f"candidate_binding.host_bindings[{index}]"
                        ".source_verification_binding"
                    ),
                )
            )

    for index, parameter in enumerate(inventory["parameters"]):
        measurement = parameter["measurement_evidence"]
        if measurement["status"] == "complete":
            references.append(
                (
                    Path(measurement["path"]),
                    measurement["sha256"],
                    f"parameters[{index}].measurement_evidence",
                )
            )
        fixed = parameter["fixed_stipend_compatibility"]
        if fixed["status"] == "complete":
            references.append(
                (
                    Path(fixed["evidence_path"]),
                    fixed["evidence_sha256"],
                    f"parameters[{index}].fixed_stipend_compatibility",
                )
            )
    return references


def resolve_governed_parameter_reference(
    repo_root: Path,
    path: Path,
    source: str,
) -> Path:
    """Reject absolute, escaping, or symlinked governed-parameter references."""
    raw = path.as_posix()
    relative = Path(*raw.split("/"))
    if (
        governed_parameter_inventory_checker.REPO_PATH_RE.fullmatch(raw) is None
        or relative.is_absolute()
        or relative.drive
        or relative.root
        or relative.anchor
        or any(part in {".", ".."} for part in relative.parts)
    ):
        raise ChecksumError(
            f"{source} complete reference must stay inside the repository: {path}"
        )
    root = repo_root.resolve()
    current = root
    for part in relative.parts:
        current = current / part
        if current.is_symlink():
            raise ChecksumError(
                f"{source} complete reference must not include symlinks: {path}"
            )
    resolved = (root / relative).resolve()
    try:
        resolved.relative_to(root)
    except ValueError as exc:
        raise ChecksumError(
            f"{source} complete reference must stay inside the repository: {path}"
        ) from exc
    return relative


def validated_complete_governed_parameter_references(
    repo_root: Path,
    inventory: dict[str, Any],
) -> list[tuple[Path, str, str]]:
    references = complete_governed_parameter_references(inventory)
    return [
        (
            resolve_governed_parameter_reference(repo_root, path, source),
            sha256,
            source,
        )
        for path, sha256, source in references
    ]


def configured_path_covers(
    repo_root: Path,
    configured_path: Path,
    required_path: Path,
) -> bool:
    configured = resolve_repo_path(repo_root, configured_path).resolve()
    required = resolve_repo_path(repo_root, required_path).resolve()
    if configured == required:
        return True
    if not configured.is_dir():
        return False
    try:
        required.relative_to(configured)
    except ValueError:
        return False
    return True


def _is_reparse_point(path: Path) -> bool:
    try:
        attributes = path.lstat().st_file_attributes
    except (AttributeError, FileNotFoundError, OSError):
        return False
    return bool(attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)


def _validated_release_tool_source(
    repo_root: Path,
    relative_path: Path,
    *,
    required: bool,
) -> Path | None:
    """Resolve one regular scripts/*.py file without following redirections."""

    root = repo_root.resolve()
    if (
        relative_path.is_absolute()
        or relative_path.drive
        or relative_path.root
        or relative_path.anchor
        or not relative_path.parts
        or relative_path.parts[0] != "scripts"
        or any(part in {"", ".", ".."} for part in relative_path.parts)
    ):
        raise ChecksumError(
            "release-tool checksum closure source must stay below scripts/: "
            f"{relative_path.as_posix()}"
        )

    current = root
    for part in relative_path.parts:
        current = current / part
        if current.is_symlink() or _is_reparse_point(current):
            raise ChecksumError(
                "release-tool checksum closure source must not include "
                f"symlinks or reparse points: {relative_path.as_posix()}"
            )

    if not current.exists():
        if required:
            raise ChecksumError(
                "release-tool checksum closure source is missing: "
                f"{relative_path.as_posix()}"
            )
        return None
    if not current.is_file():
        raise ChecksumError(
            "release-tool checksum closure source must be a regular file: "
            f"{relative_path.as_posix()}"
        )
    try:
        resolved = current.resolve(strict=True)
        resolved.relative_to(root)
    except (FileNotFoundError, OSError, ValueError) as exc:
        raise ChecksumError(
            "release-tool checksum closure source resolves outside the "
            f"repository: {relative_path.as_posix()}"
        ) from exc
    if resolved != current:
        raise ChecksumError(
            "release-tool checksum closure source must not redirect: "
            f"{relative_path.as_posix()}"
        )
    return resolved


def _repo_local_script_imports(
    repo_root: Path,
    relative_path: Path,
) -> tuple[Path, ...]:
    """Resolve supported first-party imports from one scripts/*.py module.

    The deliberately narrow fail-closed grammar supports ordinary absolute and
    static relative Import/ImportFrom nodes plus direct string-literal targets
    passed to an importlib module alias's import_module(), direct __import__(),
    or a builtins module alias's __import__(). Importer callable/module escapes,
    dynamic non-literal or relative targets, exec/eval/compile, runpy,
    importlib.util/importlib.machinery loaders, exec_module(), and load_module()
    are forbidden because their dependencies cannot be reviewed deterministically.
    """

    source_path = _validated_release_tool_source(
        repo_root,
        relative_path,
        required=True,
    )
    assert source_path is not None
    try:
        tree = ast.parse(
            read_text(source_path),
            filename=relative_path.as_posix(),
        )
    except SyntaxError as exc:
        raise ChecksumError(
            f"release-tool checksum closure cannot parse "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc

    importlib_aliases: set[str] = set()
    builtins_aliases: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Import):
            continue
        for alias in node.names:
            if alias.name == "importlib":
                importlib_aliases.add(alias.asname or "importlib")
            elif alias.name == "builtins":
                builtins_aliases.add(alias.asname or "builtins")

    def reject_alternate_loader(node: ast.AST, api: str) -> None:
        raise ChecksumError(
            "release-tool checksum closure forbids alternate loader API "
            f"{api} in {relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
        )

    alternate_parent_by_node = {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }

    def is_direct_call_func(node: ast.AST) -> bool:
        parent = alternate_parent_by_node.get(node)
        return isinstance(parent, ast.Call) and parent.func is node

    def attribute_chain(node: ast.AST) -> tuple[str, ...] | None:
        parts: list[str] = []
        current = node
        while isinstance(current, ast.Attribute):
            parts.append(current.attr)
            current = current.value
        if not isinstance(current, ast.Name):
            return None
        parts.append(current.id)
        return tuple(reversed(parts))

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name == "runpy" or alias.name.startswith("runpy."):
                    reject_alternate_loader(node, alias.name)
                if alias.name in {
                    "importlib.util",
                    "importlib.machinery",
                } or alias.name.startswith(
                    ("importlib.util.", "importlib.machinery.")
                ):
                    reject_alternate_loader(node, alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if module == "runpy" or module.startswith("runpy."):
                reject_alternate_loader(node, module)
            if module in {
                "importlib.util",
                "importlib.machinery",
            } or module.startswith(
                ("importlib.util.", "importlib.machinery.")
            ):
                reject_alternate_loader(node, module)
            if module == "importlib":
                for alias in node.names:
                    if alias.name in {"util", "machinery"}:
                        reject_alternate_loader(
                            node,
                            f"importlib.{alias.name}",
                        )
            if module == "builtins":
                for alias in node.names:
                    if alias.name in {"exec", "eval", "compile"}:
                        reject_alternate_loader(node, f"builtins.{alias.name}")
        elif (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in {"exec", "eval", "compile"}
        ):
            reject_alternate_loader(node, node.id)
        elif isinstance(node, ast.Call):
            if (
                isinstance(node.func, ast.Name)
                and node.func.id in {"exec", "eval", "compile"}
            ):
                reject_alternate_loader(node.func, node.func.id)
            if (
                isinstance(node.func, ast.Attribute)
                and node.func.attr in {"exec_module", "load_module"}
            ):
                reject_alternate_loader(node.func, node.func.attr)
            if (
                (
                    isinstance(node.func, ast.Name)
                    and node.func.id == "__import__"
                )
                or (
                    isinstance(node.func, ast.Attribute)
                    and node.func.attr == "import_module"
                    and isinstance(node.func.value, ast.Name)
                    and node.func.value.id in importlib_aliases
                )
                or (
                    isinstance(node.func, ast.Attribute)
                    and node.func.attr == "__import__"
                    and isinstance(node.func.value, ast.Name)
                    and node.func.value.id in builtins_aliases
                )
            ) and (
                node.args
                and isinstance(node.args[0], ast.Constant)
                and node.args[0].value
                in {"runpy", "importlib.util", "importlib.machinery"}
            ):
                reject_alternate_loader(node, str(node.args[0].value))
        elif isinstance(node, ast.Attribute):
            chain = attribute_chain(node)
            if (
                node.attr in {"exec", "eval", "compile"}
                and isinstance(node.value, ast.Name)
                and node.value.id in builtins_aliases
                and is_direct_call_func(node)
            ):
                reject_alternate_loader(
                    node,
                    f"{node.value.id}.{node.attr}",
                )
            if chain is not None and chain[0] in importlib_aliases:
                importlib_api = ".".join(chain)
                if (
                    len(chain) >= 2
                    and chain[1] in {"util", "machinery"}
                ):
                    reject_alternate_loader(node, importlib_api)

    def repo_script_candidates(
        module_name: str,
        *,
        package_parts: tuple[str, ...] = (),
    ) -> tuple[Path, ...]:
        has_scripts_prefix = module_name == "scripts" or module_name.startswith(
            "scripts."
        )
        module_parts = tuple(
            part for part in module_name.split(".") if part
        )
        if module_parts and module_parts[0] == "scripts":
            module_parts = module_parts[1:]
        parts = package_parts + module_parts
        resolved_candidates: list[Path] = []
        prefix_parts: tuple[str, ...] = ()
        if has_scripts_prefix:
            scripts_init = Path("scripts/__init__.py")
            if _validated_release_tool_source(
                repo_root,
                scripts_init,
                required=False,
            ) is not None:
                resolved_candidates.append(scripts_init)
        for part in parts[:-1]:
            prefix_parts += (part,)
            package_init = Path("scripts", *prefix_parts, "__init__.py")
            if _validated_release_tool_source(
                repo_root,
                package_init,
                required=False,
            ) is not None:
                resolved_candidates.append(package_init)
        if not parts:
            return tuple(resolved_candidates)
        module_candidate = Path("scripts", *parts).with_suffix(".py")
        package_candidate = Path("scripts", *parts, "__init__.py")
        module_exists = (
            _validated_release_tool_source(
                repo_root,
                module_candidate,
                required=False,
            )
            is not None
        )
        package_exists = (
            _validated_release_tool_source(
                repo_root,
                package_candidate,
                required=False,
            )
            is not None
        )
        if package_exists:
            resolved_candidates.append(package_candidate)
        elif module_exists:
            resolved_candidates.append(module_candidate)
        return tuple(resolved_candidates)

    def add_module_candidates(
        candidates: set[Path],
        module_name: str,
        *,
        package_parts: tuple[str, ...] = (),
    ) -> None:
        candidates.update(
            repo_script_candidates(
                module_name,
                package_parts=package_parts,
            )
        )

    current_parts = relative_path.with_suffix("").parts
    if not current_parts or current_parts[0] != "scripts":
        raise ChecksumError(
            "release-tool checksum closure source must be below scripts/: "
            f"{relative_path.as_posix()}"
        )
    current_package = tuple(current_parts[1:-1])
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name == "importlib":
                    importlib_aliases.add(alias.asname or "importlib")
                elif alias.name.startswith("importlib.") and alias.asname is None:
                    # `import importlib.util` binds the top-level importlib name.
                    importlib_aliases.add("importlib")
                elif alias.name == "builtins":
                    builtins_aliases.add(alias.asname or "builtins")
        elif (
            isinstance(node, ast.ImportFrom)
            and node.level == 0
            and node.module == "importlib"
        ):
            for alias in node.names:
                if alias.name == "import_module":
                    raise ChecksumError(
                        "release-tool checksum closure does not support "
                        "importer callable alias import "
                        f"importlib.import_module in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )
        elif (
            isinstance(node, ast.ImportFrom)
            and node.level == 0
            and node.module == "builtins"
        ):
            for alias in node.names:
                if alias.name == "__import__":
                    raise ChecksumError(
                        "release-tool checksum closure does not support "
                        "importer callable alias import builtins.__import__ in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )

    protected_module_aliases = importlib_aliases | builtins_aliases
    for node in ast.walk(tree):
        shadowed_name: str | None = None
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, (ast.Store, ast.Del))
            and node.id in protected_module_aliases
        ):
            shadowed_name = node.id
        elif isinstance(node, ast.arg) and node.arg in protected_module_aliases:
            shadowed_name = node.arg
        elif (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and node.name in protected_module_aliases
        ):
            shadowed_name = node.name
        if shadowed_name is not None:
            raise ChecksumError(
                "release-tool checksum closure does not support importer "
                f"module alias rebinding for {shadowed_name} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )

    def importer_callable_source(node: ast.AST) -> str | None:
        if isinstance(node, ast.Name) and node.id == "__import__":
            return "__import__"
        if (
            isinstance(node, ast.Attribute)
            and node.attr == "import_module"
            and isinstance(node.value, ast.Name)
            and node.value.id in importlib_aliases
        ):
            return f"{node.value.id}.import_module"
        if (
            isinstance(node, ast.Attribute)
            and node.attr == "__import__"
            and isinstance(node.value, ast.Name)
            and node.value.id in builtins_aliases
        ):
            return f"{node.value.id}.__import__"
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "getattr"
            and len(node.args) >= 2
            and isinstance(node.args[0], ast.Name)
            and node.args[0].id in importlib_aliases
        ):
            attribute = node.args[1]
            if (
                not isinstance(attribute, ast.Constant)
                or not isinstance(attribute.value, str)
            ):
                raise ChecksumError(
                    "release-tool checksum closure does not support nonliteral "
                    "dynamic importer construction in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
            if attribute.value == "import_module":
                raise ChecksumError(
                    "release-tool checksum closure does not support dynamic "
                    "importer construction via getattr in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
        return None

    parent_by_node = {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            importer_callable_source(node)
    for node in ast.walk(tree):
        importer_source = importer_callable_source(node)
        if importer_source is not None:
            parent = parent_by_node.get(node)
            if not (
                isinstance(parent, ast.Call)
                and parent.func is node
            ):
                raise ChecksumError(
                    "release-tool checksum closure does not support importer "
                    f"callable escape from {importer_source} in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
    for node in ast.walk(tree):
        if not (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in protected_module_aliases
        ):
            continue
        parent = parent_by_node.get(node)
        grandparent = parent_by_node.get(parent) if parent is not None else None
        direct_importer_call = (
            isinstance(parent, ast.Attribute)
            and parent.value is node
            and importer_callable_source(parent) is not None
            and isinstance(grandparent, ast.Call)
            and grandparent.func is parent
        )
        getattr_construction = (
            isinstance(parent, ast.Call)
            and isinstance(parent.func, ast.Name)
            and parent.func.id == "getattr"
            and parent.args
            and parent.args[0] is node
        )
        if not direct_importer_call and not getattr_construction:
            raise ChecksumError(
                "release-tool checksum closure does not support importer "
                f"module alias escape for {node.id} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )

    candidates: set[Path] = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                add_module_candidates(candidates, alias.name)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                ascents = node.level - 1
                if ascents > len(current_package):
                    raise ChecksumError(
                        "release-tool checksum closure relative import escapes "
                        f"scripts/: {relative_path.as_posix()}:{node.lineno}"
                    )
                package_parts = current_package[
                    : len(current_package) - ascents
                ]
                if node.module:
                    add_module_candidates(
                        candidates,
                        node.module,
                        package_parts=package_parts,
                    )
                    for alias in node.names:
                        add_module_candidates(
                            candidates,
                            f"{node.module}.{alias.name}",
                            package_parts=package_parts,
                        )
                else:
                    for alias in node.names:
                        add_module_candidates(
                            candidates,
                            alias.name,
                            package_parts=package_parts,
                        )
            elif node.module == "scripts":
                add_module_candidates(candidates, "scripts")
                for alias in node.names:
                    add_module_candidates(candidates, alias.name)
            elif node.module:
                add_module_candidates(candidates, node.module)
                for alias in node.names:
                    add_module_candidates(
                        candidates,
                        f"{node.module}.{alias.name}",
                    )
        elif isinstance(node, ast.Call):
            is_dynamic_import = (
                isinstance(node.func, ast.Name)
                and node.func.id == "__import__"
            ) or (
                isinstance(node.func, ast.Attribute)
                and node.func.attr == "import_module"
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id in importlib_aliases
            ) or (
                isinstance(node.func, ast.Attribute)
                and node.func.attr == "__import__"
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id in builtins_aliases
            )
            if not is_dynamic_import:
                continue
            if (
                not node.args
                or not isinstance(node.args[0], ast.Constant)
                or not isinstance(node.args[0].value, str)
            ):
                raise ChecksumError(
                    "release-tool checksum closure requires a string-literal "
                    f"dynamic import in {relative_path.as_posix()}:{node.lineno}"
                )
            module_name = node.args[0].value
            if (
                (
                    isinstance(node.func, ast.Name)
                    and node.func.id == "__import__"
                )
                or (
                    isinstance(node.func, ast.Attribute)
                    and node.func.attr == "__import__"
                    and isinstance(node.func.value, ast.Name)
                    and node.func.value.id in builtins_aliases
                )
            ):
                level_node = (
                    node.args[4]
                    if len(node.args) >= 5
                    else next(
                        (
                            keyword.value
                            for keyword in node.keywords
                            if keyword.arg == "level"
                        ),
                        None,
                    )
                )
                if level_node is not None and (
                    not isinstance(level_node, ast.Constant)
                    or not isinstance(level_node.value, int)
                    or isinstance(level_node.value, bool)
                ):
                    raise ChecksumError(
                        "release-tool checksum closure requires a literal "
                        "__import__ level in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )
                if level_node is not None and level_node.value != 0:
                    raise ChecksumError(
                        "release-tool checksum closure does not support "
                        "relative dynamic imports in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )
            if module_name.startswith("."):
                raise ChecksumError(
                    "release-tool checksum closure does not support relative "
                    f"dynamic imports in {relative_path.as_posix()}:{node.lineno}"
                )
            add_module_candidates(candidates, module_name)
    return tuple(sorted(candidates))


def release_tool_runtime_closure(
    repo_root: Path,
    roots: tuple[Path, ...] = RELEASE_TOOL_ROOTS,
) -> tuple[Path, ...]:
    """Return the deterministic recursive first-party Python import closure."""

    pending = list(sorted(roots, reverse=True))
    visited: set[Path] = set()
    while pending:
        path = pending.pop()
        if path in visited:
            continue
        visited.add(path)
        for dependency in reversed(_repo_local_script_imports(repo_root, path)):
            if dependency not in visited:
                pending.append(dependency)
    return tuple(sorted(visited))


def validate_release_tool_checksum_closure(
    repo_root: Path,
    covered_paths: list[Path],
) -> tuple[Path, ...]:
    """Fail closed unless reviewed release tools/tests are exact file entries."""

    for path in REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE:
        _validated_release_tool_source(
            repo_root,
            path,
            required=True,
        )
    for path in RELEASE_TOOL_FOCUSED_TESTS:
        _validated_release_tool_source(
            repo_root,
            path,
            required=True,
        )
    runtime_closure = release_tool_runtime_closure(repo_root)
    if runtime_closure != REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE:
        missing_reviewed = sorted(
            path.as_posix()
            for path in (
                set(REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE)
                - set(runtime_closure)
            )
        )
        unexpected_runtime = sorted(
            path.as_posix()
            for path in (
                set(runtime_closure)
                - set(REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE)
            )
        )
        raise ChecksumError(
            "release-tool runtime closure differs from the reviewed literal: "
            f"missing={missing_reviewed}; unexpected={unexpected_runtime}"
        )
    exact_covered_paths = set(covered_paths)
    missing_runtime = [
        path.as_posix()
        for path in runtime_closure
        if path not in exact_covered_paths
    ]
    if missing_runtime:
        raise ChecksumError(
            "release-tool checksum trust closure missing runtime dependencies: "
            f"{missing_runtime}"
        )
    missing_tests = [
        path.as_posix()
        for path in RELEASE_TOOL_FOCUSED_TESTS
        if path not in exact_covered_paths
    ]
    if missing_tests:
        raise ChecksumError(
            "release-tool checksum trust closure missing focused tests: "
            f"{missing_tests}"
        )
    return runtime_closure


def validate_canonical_release_checksum_policy(
    repo_root: Path,
    covered_paths: list[Path],
) -> tuple[Path, ...]:
    """Require the exact reviewed canonical policy before generating outputs."""

    def normalized_configured_path(path: Path) -> Path:
        if (
            path.is_absolute()
            or path.drive
            or path.root
            or path.anchor
            or any(part in {"", ".", ".."} for part in path.parts)
        ):
            raise ChecksumError(
                "canonical release checksum coverage path must be a normalized "
                "repository-relative path: "
                f"{path.as_posix()}"
            )
        normalized = Path(*path.parts)
        if normalized.as_posix() != path.as_posix():
            raise ChecksumError(
                "canonical release checksum coverage path must be normalized: "
                f"{path.as_posix()}"
            )
        return normalized

    normalized_paths = [
        normalized_configured_path(path)
        for path in covered_paths
    ]
    expected = set(DEFAULT_COVERED_PATHS)
    actual = set(normalized_paths)
    duplicates = sorted(
        {
            path.as_posix()
            for path in normalized_paths
            if normalized_paths.count(path) > 1
        }
    )
    missing = sorted(path.as_posix() for path in expected - actual)
    unexpected = sorted(path.as_posix() for path in actual - expected)
    if duplicates or missing or unexpected:
        raise ChecksumError(
            "canonical release checksum coverage policy mismatch: "
            f"missing={missing}; unexpected={unexpected}; "
            f"duplicates={duplicates}"
        )
    return validate_release_tool_checksum_closure(repo_root, normalized_paths)


def release_checksum_inputs(
    repo_root: Path,
    covered_paths: list[Path],
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> tuple[list[Path], list[tuple[Path, str, str]]]:
    """Validate an in-scope inventory and add all complete references."""
    if coverage_policy == CANONICAL_COVERAGE_POLICY:
        validate_canonical_release_checksum_policy(repo_root, covered_paths)
    elif coverage_policy != CUSTOM_SUBSET_COVERAGE_POLICY:
        raise ChecksumError(
            f"unsupported release checksum coverage policy: {coverage_policy}"
        )

    inventory_path = governed_parameter_inventory_checker.DEFAULT_INVENTORY
    if not any(
        configured_path_covers(repo_root, path, inventory_path)
        for path in covered_paths
    ):
        return list(covered_paths), []

    try:
        inventory = governed_parameter_inventory_checker.validate_inventory(
            repo_root,
            inventory_path,
            require_complete=False,
        )
    except (
        governed_parameter_inventory_checker.GovernedParameterInventoryError
    ) as exc:
        raise ChecksumError(
            f"invalid governed-parameter inventory {inventory_path}: {exc}"
        ) from exc

    references = validated_complete_governed_parameter_references(
        repo_root,
        inventory,
    )
    effective_paths = list(covered_paths)
    for path, _sha256, _source in references:
        if not any(
            configured_path_covers(repo_root, configured, path)
            for configured in effective_paths
        ):
            effective_paths.append(path)
    return effective_paths, references


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
    coverage_policy: str,
) -> dict[str, Any]:
    output_dir_relative = normalize_path(output_dir, repo_root)
    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME

    return {
        "schema_version": CHECKSUM_SCHEMA,
        "generated_by": f"scripts/generate_release_checksums.py:{GENERATOR_VERSION}",
        "algorithm": "sha256",
        "source": {
            "coverage_policy": coverage_policy,
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
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> tuple[str, str]:
    output_dir = resolve_repo_path(repo_root, output_dir)
    canonical_output_dir = (repo_root / DEFAULT_OUTPUT_DIR).resolve()
    if (
        coverage_policy == CUSTOM_SUBSET_COVERAGE_POLICY
        and output_dir.resolve() == canonical_output_dir
    ):
        raise ChecksumError(
            "custom-subset release checksum coverage must use a noncanonical "
            f"output directory, not {DEFAULT_OUTPUT_DIR.as_posix()}"
        )
    effective_paths, governed_references = release_checksum_inputs(
        repo_root,
        covered_paths,
        coverage_policy=coverage_policy,
    )
    files = collect_files(repo_root, effective_paths, output_dir)
    files_by_path = {
        normalize_path(path, repo_root): path
        for path in files
    }
    for path, recorded_sha256, source in governed_references:
        relative_path = normalize_path(resolve_repo_path(repo_root, path), repo_root)
        covered = files_by_path.get(relative_path)
        if covered is None:
            raise ChecksumError(
                f"{source} complete reference is excluded from checksum coverage: "
                f"{relative_path}"
            )
        actual_sha256 = file_sha256(covered).removeprefix("sha256:")
        if actual_sha256 != recorded_sha256:
            raise ChecksumError(
                f"{source} checksum input hash mismatch for {relative_path}"
            )
    checksum_text = "\n".join(build_checksum_lines(files, repo_root)) + "\n"
    manifest = build_manifest(
        repo_root,
        effective_paths,
        output_dir,
        files,
        checksum_text,
        coverage_policy,
    )
    return checksum_text, json_text(manifest)


def write_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> list[Path]:
    output_dir = resolve_repo_path(repo_root, output_dir)
    checksum_text, manifest_text = build_outputs(
        repo_root,
        covered_paths,
        output_dir,
        coverage_policy=coverage_policy,
    )
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


def check_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> int:
    output_dir = resolve_repo_path(repo_root, output_dir)
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
            repo_root,
            covered_paths,
            output_dir,
            coverage_policy=coverage_policy,
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
    parser.add_argument(
        "--coverage-policy",
        choices=COVERAGE_POLICIES,
        default=CANONICAL_COVERAGE_POLICY,
    )
    parser.add_argument("--output-dir", type=Path, default=DEFAULT_OUTPUT_DIR)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    covered_paths = args.covered_paths or DEFAULT_COVERED_PATHS
    output_dir = args.output_dir
    if args.coverage_policy == CANONICAL_COVERAGE_POLICY and args.covered_paths:
        print(
            "error: --covered-path requires "
            f"--coverage-policy {CUSTOM_SUBSET_COVERAGE_POLICY}",
            file=sys.stderr,
        )
        return 1
    if (
        args.coverage_policy == CUSTOM_SUBSET_COVERAGE_POLICY
        and not args.covered_paths
    ):
        print(
            "error: custom-subset coverage policy requires --covered-path",
            file=sys.stderr,
        )
        return 1

    try:
        if args.check:
            return check_outputs(
                repo_root,
                covered_paths,
                output_dir,
                coverage_policy=args.coverage_policy,
            )
        written = write_outputs(
            repo_root,
            covered_paths,
            output_dir,
            coverage_policy=args.coverage_policy,
        )
    except ChecksumError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
