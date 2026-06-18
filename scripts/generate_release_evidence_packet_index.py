#!/usr/bin/env python3
"""Generate a deterministic release evidence packet index."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import check_non_local_release_evidence as non_local_checker
import check_public_beta_evidence as evidence_checker
import generate_public_beta_blocker_report as shared_report


PACKET_SCHEMA = "6529stream.release-evidence-packet-index.v1"
GENERATOR_VERSION = "1"
SCRIPT_NAME = Path(__file__).name

DEFAULT_JSON_OUTPUT = Path("release-artifacts/latest/release-evidence-packet-index.json")
DEFAULT_MARKDOWN_OUTPUT = Path("release-artifacts/latest/release-evidence-packet-index.md")
DEFAULT_PUBLIC_BETA_BLOCKERS = Path("release-artifacts/latest/public-beta-blockers.md")
DEFAULT_PRODUCTION_RELEASE_BLOCKERS = Path(
    "release-artifacts/latest/production-release-blockers.md"
)
DEFAULT_NON_LOCAL_RUNBOOK = Path("docs/non-local-release-evidence.md")

PUBLIC_BETA_PHASE = evidence_checker.PUBLIC_BETA_PHASE
PRODUCTION_PHASE = evidence_checker.PRODUCTION_PHASE

PHASES = (
    {
        "phase": PUBLIC_BETA_PHASE,
        "label": "Public Beta",
        "requirements": evidence_checker.PUBLIC_BETA_REQUIREMENTS,
        "template_dir": non_local_checker.PUBLIC_BETA_TEMPLATE_DIR,
        "blocker_report_key": "public_beta",
        "blocker_report_path": DEFAULT_PUBLIC_BETA_BLOCKERS,
        "blocker_report_section": "Incomplete Public Beta Rows",
        "blocker_report_check": "python scripts/generate_public_beta_blocker_report.py --check",
    },
    {
        "phase": PRODUCTION_PHASE,
        "label": "Production Release",
        "requirements": evidence_checker.PRODUCTION_REQUIREMENTS,
        "template_dir": non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR,
        "blocker_report_key": "production_release",
        "blocker_report_path": DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
        "blocker_report_section": "Incomplete Production Release Rows",
        "blocker_report_check": (
            "python scripts/generate_production_release_blocker_report.py --check"
        ),
    },
)

COMMON_VALIDATION_COMMANDS = (
    "python scripts/check_public_beta_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/generate_release_evidence_packet_index.py --check",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
)
TEST_COMMANDS = (
    "python scripts/test_release_evidence_packet_index.py",
    "python scripts/test_public_beta_evidence.py",
    "python scripts/test_non_local_release_evidence.py",
)
FORK_DEPLOYMENT_REQUIREMENT_ID = "fork_deployment_rehearsal"
FORK_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/fork-deployment-rehearsal/"
    "fork-deployment-rehearsal-retained-artifact-template.md"
)
TESTNET_DEPLOYMENT_REQUIREMENT_ID = "testnet_deployment_rehearsal"
TESTNET_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/testnet-deployment-rehearsal/"
    "testnet-deployment-rehearsal-retained-artifact-template.md"
)
PUBLIC_BETA_MARKETPLACE_INDEXER_REQUIREMENT_ID = (
    "fork_testnet_marketplace_indexer_evidence"
)
PUBLIC_BETA_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/marketplace-indexer/"
    "fork-testnet-marketplace-indexer-retained-artifact-template.md"
)
PUBLIC_BETA_METADATA_BROWSER_REQUIREMENT_ID = "fork_testnet_metadata_browser_evidence"
PUBLIC_BETA_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/fork-metadata-browser/"
    "fork-metadata-browser-retained-artifact-template.md"
)
PUBLIC_BETA_CEREMONY_REQUIREMENT_ID = "fork_testnet_ceremony_evidence"
PUBLIC_BETA_CEREMONY_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/fork-ceremony/"
    "fork-ceremony-retained-artifact-template.md"
)
PUBLIC_BETA_RANDOMIZER_OPERATIONS_REQUIREMENT_ID = (
    "fork_testnet_randomizer_operations_evidence"
)
PUBLIC_BETA_RANDOMIZER_OPERATIONS_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/fork-randomizer-operations/"
    "fork-randomizer-operations-retained-artifact-template.md"
)
LIVE_MARKETPLACE_INDEXER_REQUIREMENT_ID = "live_marketplace_indexer_evidence"
LIVE_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/marketplace-indexer/"
    "live-marketplace-indexer-retained-artifact-template.md"
)
LIVE_METADATA_BROWSER_REQUIREMENT_ID = "live_metadata_browser_evidence"
LIVE_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/live-metadata-browser/"
    "live-metadata-browser-retained-artifact-template.md"
)
LIVE_CEREMONY_REQUIREMENT_ID = "live_ceremony_evidence"
LIVE_CEREMONY_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/live-ceremony/"
    "live-ceremony-retained-artifact-template.md"
)
LIVE_RANDOMIZER_OPERATIONS_REQUIREMENT_ID = "live_randomizer_operations_evidence"
LIVE_RANDOMIZER_OPERATIONS_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/live-randomizer-operations/"
    "live-randomizer-operations-retained-artifact-template.md"
)
EXTERNAL_AUDIT_REQUIREMENT_ID = "external_audit_report"
EXTERNAL_AUDIT_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/external-audit-report/"
    "external-audit-report-retained-artifact-template.md"
)
POST_AUDIT_REMEDIATION_REQUIREMENT_ID = "post_audit_remediation"
POST_AUDIT_REMEDIATION_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/post-audit-remediation/"
    "post-audit-remediation-retained-artifact-template.md"
)
PRODUCTION_ADDRESS_BOOKS_REQUIREMENT_ID = "production_address_books"
LIVE_EXPLORER_VERIFICATION_REQUIREMENT_ID = "live_explorer_verification"
PRODUCTION_VERIFIED_ADDRESSES_RETAINED_ARTIFACT_TEMPLATE = Path(
    "release-artifacts/evidence/production-verified-addresses/"
    "production-verified-addresses-retained-artifact-template.md"
)
ROW_VALIDATION_COMMAND_OVERRIDES = {
    (PUBLIC_BETA_PHASE, EXTERNAL_AUDIT_REQUIREMENT_ID): (
        "python scripts/test_external_audit_report_evidence.py",
        "python scripts/check_external_audit_report_evidence.py",
    ),
    (PRODUCTION_PHASE, POST_AUDIT_REMEDIATION_REQUIREMENT_ID): (
        "python scripts/test_post_audit_remediation_evidence.py",
        "python scripts/check_post_audit_remediation_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, FORK_DEPLOYMENT_REQUIREMENT_ID): (
        "python scripts/test_fork_deployment_rehearsal_evidence.py",
        "python scripts/check_fork_deployment_rehearsal_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, TESTNET_DEPLOYMENT_REQUIREMENT_ID): (
        "python scripts/test_testnet_deployment_rehearsal_evidence.py",
        "python scripts/check_testnet_deployment_rehearsal_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, PUBLIC_BETA_MARKETPLACE_INDEXER_REQUIREMENT_ID): (
        "python scripts/test_marketplace_indexer_evidence.py",
        "python scripts/check_marketplace_indexer_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, PUBLIC_BETA_METADATA_BROWSER_REQUIREMENT_ID): (
        "python scripts/test_fork_metadata_browser_evidence.py",
        "python scripts/check_fork_metadata_browser_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, PUBLIC_BETA_CEREMONY_REQUIREMENT_ID): (
        "python scripts/test_fork_ceremony_evidence.py",
        "python scripts/check_fork_ceremony_evidence.py",
    ),
    (PUBLIC_BETA_PHASE, PUBLIC_BETA_RANDOMIZER_OPERATIONS_REQUIREMENT_ID): (
        "python scripts/test_fork_randomizer_operations_evidence.py",
        "python scripts/check_fork_randomizer_operations_evidence.py",
    ),
    (PRODUCTION_PHASE, LIVE_MARKETPLACE_INDEXER_REQUIREMENT_ID): (
        "python scripts/test_marketplace_indexer_evidence.py",
        "python scripts/check_marketplace_indexer_evidence.py",
    ),
    (PRODUCTION_PHASE, LIVE_METADATA_BROWSER_REQUIREMENT_ID): (
        "python scripts/test_live_metadata_browser_evidence.py",
        "python scripts/check_live_metadata_browser_evidence.py",
    ),
    (PRODUCTION_PHASE, LIVE_CEREMONY_REQUIREMENT_ID): (
        "python scripts/test_live_ceremony_evidence.py",
        "python scripts/check_live_ceremony_evidence.py",
    ),
    (PRODUCTION_PHASE, LIVE_RANDOMIZER_OPERATIONS_REQUIREMENT_ID): (
        "python scripts/test_live_randomizer_operations_evidence.py",
        "python scripts/check_live_randomizer_operations_evidence.py",
    ),
    (PRODUCTION_PHASE, PRODUCTION_ADDRESS_BOOKS_REQUIREMENT_ID): (
        "python scripts/test_production_verified_addresses.py",
        "python scripts/check_production_verified_addresses.py",
    ),
    (PRODUCTION_PHASE, LIVE_EXPLORER_VERIFICATION_REQUIREMENT_ID): (
        "python scripts/test_production_verified_addresses.py",
        "python scripts/check_production_verified_addresses.py",
    ),
}


class ReleaseEvidencePacketIndexError(RuntimeError):
    """Raised when packet-index generation cannot safely continue."""


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    """Resolve a path relative to the repository root."""
    return path if path.is_absolute() else repo_root / path


def normalize_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path when possible."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def load_json(path: Path) -> Any:
    """Load a JSON file with packet-index-specific errors."""
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise ReleaseEvidencePacketIndexError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseEvidencePacketIndexError(f"invalid JSON in {path}: {exc}") from exc


def file_record(path: Path, repo_root: Path) -> dict[str, Any]:
    """Return a deterministic file record for release packet inputs or outputs."""
    if not path.is_file():
        raise ReleaseEvidencePacketIndexError(
            f"missing required file: {normalize_path(path, repo_root)}"
        )
    return {
        "path": normalize_path(path, repo_root),
        "sha256": evidence_checker.file_sha256(path),
        "size_bytes": path.stat().st_size,
    }


def load_evidence_document(evidence_path: Path, repo_root: Path) -> dict[str, Any]:
    """Load and validate the public-beta evidence status manifest."""
    try:
        data = shared_report.load_evidence_document(evidence_path, repo_root)
    except shared_report.PublicBetaBlockerReportError as exc:
        raise ReleaseEvidencePacketIndexError(
            f"invalid public beta evidence: {exc}"
        ) from exc
    if not isinstance(data, dict):
        raise ReleaseEvidencePacketIndexError("public beta evidence must be an object")
    return data


def canonical_requirements(data: dict[str, Any]) -> dict[str, dict[str, dict[str, Any]]]:
    """Return validated requirement rows by phase and requirement ID."""
    return shared_report.canonical_requirements(data)


def template_map_for_phase(
    repo_root: Path,
    phase: str,
    requirement_ids: tuple[str, ...],
) -> dict[str, tuple[Path, dict[str, Any]]]:
    """Return template paths and metadata by requirement ID for one phase."""
    try:
        if phase == PUBLIC_BETA_PHASE:
            non_local_checker.validate_public_beta_template_set(repo_root)
            paths = non_local_checker.public_beta_template_paths(repo_root)
        elif phase == PRODUCTION_PHASE:
            non_local_checker.validate_production_release_template_set(repo_root)
            paths = non_local_checker.production_release_template_paths(repo_root)
        else:
            raise ReleaseEvidencePacketIndexError(f"unknown evidence phase: {phase}")

        by_requirement: dict[str, tuple[Path, dict[str, Any]]] = {}
        for path in paths:
            evidence = non_local_checker.require_dict(
                non_local_checker.load_json(path),
                str(path),
            )
            requirement_id = non_local_checker.require_string(
                evidence.get("public_beta_requirement_id"),
                f"{path}.public_beta_requirement_id",
            )
            if requirement_id in requirement_ids:
                by_requirement[requirement_id] = (path, evidence)
    except non_local_checker.NonLocalReleaseEvidenceError as exc:
        raise ReleaseEvidencePacketIndexError(
            f"invalid {phase} evidence template set: {exc}"
        ) from exc

    missing = sorted(set(requirement_ids) - set(by_requirement))
    if missing:
        raise ReleaseEvidencePacketIndexError(
            f"missing {phase} template(s): " + ", ".join(missing)
        )
    return by_requirement


def report_text(path: Path, repo_root: Path) -> str:
    """Read a required blocker report."""
    if not path.is_file():
        raise ReleaseEvidencePacketIndexError(
            f"missing blocker report: {normalize_path(path, repo_root)}"
        )
    return path.read_text(encoding="utf-8")


def status_summary(
    data: dict[str, Any],
    by_phase: dict[str, dict[str, dict[str, Any]]],
) -> list[dict[str, Any]]:
    """Build status counts for each release phase."""
    rows: list[dict[str, Any]] = []
    for phase_config in PHASES:
        phase = str(phase_config["phase"])
        counts = {status: 0 for status in shared_report.STATUS_ORDER}
        for requirement_id in phase_config["requirements"]:
            counts[by_phase[phase][requirement_id]["status"]] += 1
        rows.append(
            {
                "phase": phase,
                "label": phase_config["label"],
                "overall_status": data["status"][phase],
                "counts": counts,
                "incomplete": sum(
                    counts[status] for status in shared_report.INCOMPLETE_STATUSES
                ),
            }
        )
    return rows


def row_validation_commands(
    phase_config: dict[str, Any],
    requirement_id: str,
) -> list[str]:
    """Return commands that must stay green for one packet row."""
    phase = str(phase_config["phase"])
    return [
        *TEST_COMMANDS,
        *ROW_VALIDATION_COMMAND_OVERRIDES.get((phase, requirement_id), ()),
        "python scripts/test_public_beta_blocker_report.py",
        "python scripts/test_production_release_blocker_report.py",
        str(phase_config["blocker_report_check"]),
        *COMMON_VALIDATION_COMMANDS,
    ]


def retained_artifact_expectation(
    repo_root: Path,
    phase: str,
    requirement_id: str,
    template: dict[str, Any],
) -> dict[str, Any]:
    """Return the retained artifact handoff record for one packet row."""
    if phase == PUBLIC_BETA_PHASE and requirement_id == FORK_DEPLOYMENT_REQUIREMENT_ID:
        record = file_record(
            resolve_repo_path(repo_root, FORK_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif phase == PUBLIC_BETA_PHASE and requirement_id == EXTERNAL_AUDIT_REQUIREMENT_ID:
        record = file_record(
            resolve_repo_path(repo_root, EXTERNAL_AUDIT_RETAINED_ARTIFACT_TEMPLATE),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PUBLIC_BETA_PHASE
        and requirement_id == TESTNET_DEPLOYMENT_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(repo_root, TESTNET_DEPLOYMENT_RETAINED_ARTIFACT_TEMPLATE),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PUBLIC_BETA_PHASE
        and requirement_id == PUBLIC_BETA_MARKETPLACE_INDEXER_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                PUBLIC_BETA_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PUBLIC_BETA_PHASE
        and requirement_id == PUBLIC_BETA_METADATA_BROWSER_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                PUBLIC_BETA_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PUBLIC_BETA_PHASE
        and requirement_id == PUBLIC_BETA_CEREMONY_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(repo_root, PUBLIC_BETA_CEREMONY_RETAINED_ARTIFACT_TEMPLATE),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PUBLIC_BETA_PHASE
        and requirement_id == PUBLIC_BETA_RANDOMIZER_OPERATIONS_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                PUBLIC_BETA_RANDOMIZER_OPERATIONS_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PRODUCTION_PHASE
        and requirement_id == LIVE_MARKETPLACE_INDEXER_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                LIVE_MARKETPLACE_INDEXER_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PRODUCTION_PHASE
        and requirement_id == LIVE_METADATA_BROWSER_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                LIVE_METADATA_BROWSER_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PRODUCTION_PHASE
        and requirement_id == POST_AUDIT_REMEDIATION_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                POST_AUDIT_REMEDIATION_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif phase == PRODUCTION_PHASE and requirement_id == LIVE_CEREMONY_REQUIREMENT_ID:
        record = file_record(
            resolve_repo_path(repo_root, LIVE_CEREMONY_RETAINED_ARTIFACT_TEMPLATE),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif (
        phase == PRODUCTION_PHASE
        and requirement_id == LIVE_RANDOMIZER_OPERATIONS_REQUIREMENT_ID
    ):
        record = file_record(
            resolve_repo_path(
                repo_root,
                LIVE_RANDOMIZER_OPERATIONS_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    elif phase == PRODUCTION_PHASE and requirement_id in {
        PRODUCTION_ADDRESS_BOOKS_REQUIREMENT_ID,
        LIVE_EXPLORER_VERIFICATION_REQUIREMENT_ID,
    }:
        record = file_record(
            resolve_repo_path(
                repo_root,
                PRODUCTION_VERIFIED_ADDRESSES_RETAINED_ARTIFACT_TEMPLATE,
            ),
            repo_root,
        )
        retained_path = record["path"]
        retained_sha256 = record["sha256"]
    else:
        retained_path = template["retained_path"]
        retained_sha256 = template["sha256"]

    return {
        "path": retained_path,
        "sha256": retained_sha256,
        "block_or_reference": template["block_or_reference"],
        "command_or_source_system": template["command_or_source_system"],
        "operator_notes": template["operator_notes"],
    }


def evidence_paths(requirement: dict[str, Any]) -> list[str]:
    """Return evidence reference paths from a requirement row."""
    return [str(reference["path"]) for reference in requirement["evidence"]]


def completion_policy(requirement: dict[str, Any]) -> str:
    """Return the packet completion policy for a requirement row."""
    if requirement["status"] == "complete":
        return "reviewed retained evidence is recorded in the evidence manifest"
    return (
        "reviewed non-local evidence must replace or supplement the template; "
        "template-only evidence is preparation material and cannot complete this row"
    )


def validate_template_only_completion(requirement: dict[str, Any]) -> None:
    """Reject completion claims that are backed only by template references."""
    if requirement["status"] != "complete":
        return
    if shared_report.evidence_posture(requirement) == "local-template-only":
        raise ReleaseEvidencePacketIndexError(
            "template-only evidence cannot complete requirement "
            f"{requirement['phase']}:{requirement['id']}"
        )


def validate_blocker_reference(
    requirement_id: str,
    phase: str,
    template_path: str,
    report: str,
    status: str,
) -> None:
    """Ensure the generated blocker report still references the packet row."""
    if f"`{requirement_id}`" not in report:
        raise ReleaseEvidencePacketIndexError(
            f"blocker report for {phase} is missing requirement {requirement_id}"
        )
    if phase == PRODUCTION_PHASE and status != "complete" and template_path not in report:
        raise ReleaseEvidencePacketIndexError(
            "production blocker report is missing template link for "
            f"{requirement_id}: {template_path}"
        )


def packet_rows(
    repo_root: Path,
    by_phase: dict[str, dict[str, dict[str, Any]]],
    reports: dict[str, str],
) -> list[dict[str, Any]]:
    """Build the ordered packet rows."""
    rows: list[dict[str, Any]] = []
    for phase_config in PHASES:
        phase = str(phase_config["phase"])
        templates = template_map_for_phase(
            repo_root,
            phase,
            phase_config["requirements"],
        )
        for requirement_id in phase_config["requirements"]:
            requirement = by_phase[phase][requirement_id]
            validate_template_only_completion(requirement)
            template_path, template = templates[requirement_id]
            template_path_text = normalize_path(template_path, repo_root)
            retained = retained_artifact_expectation(
                repo_root,
                phase,
                requirement_id,
                template,
            )
            commands = row_validation_commands(phase_config, requirement_id)
            validate_blocker_reference(
                requirement_id,
                phase,
                template_path_text,
                reports[str(phase_config["blocker_report_key"])],
                requirement["status"],
            )
            rows.append(
                {
                    "phase": phase,
                    "phase_label": phase_config["label"],
                    "requirement_id": requirement_id,
                    "status": requirement["status"],
                    "evidence_posture": shared_report.evidence_posture(requirement),
                    "evidence_count": len(requirement["evidence"]),
                    "evidence_paths": evidence_paths(requirement),
                    "owner": requirement["owner"],
                    "template_owner": template["owner"],
                    "reviewer": template["reviewer"],
                    "review_status": template["review_status"],
                    "owner_reviewer_posture": (
                        f"requirement owner={requirement['owner']}; "
                        f"template owner={template['owner']}; "
                        f"reviewer={template['reviewer']}; "
                        f"review_status={template['review_status']}"
                    ),
                    "blocker_report": {
                        "path": normalize_path(
                            resolve_repo_path(repo_root, phase_config["blocker_report_path"]),
                            repo_root,
                        ),
                        "section": phase_config["blocker_report_section"],
                        "requirement_marker": f"`{requirement_id}`",
                    },
                    "template": {
                        "path": template_path_text,
                        "schema_version": template["schema_version"],
                        "evidence_id": template["evidence_id"],
                        "record_type": template["record_type"],
                        "review_status": template["review_status"],
                    },
                    "retained_artifact_expectation": retained,
                    "validation_commands": commands,
                    "template_only_can_complete": False,
                    "completion_policy": completion_policy(requirement),
                    "notes": requirement["notes"],
                }
            )
    return rows


def build_packet(
    repo_root: Path,
    evidence_path: Path,
    public_beta_blockers_path: Path,
    production_release_blockers_path: Path,
    non_local_runbook_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> dict[str, Any]:
    """Build the machine-readable release evidence packet index."""
    resolved_evidence = resolve_repo_path(repo_root, evidence_path)
    resolved_public_beta_blockers = resolve_repo_path(repo_root, public_beta_blockers_path)
    resolved_production_blockers = resolve_repo_path(
        repo_root, production_release_blockers_path
    )
    resolved_runbook = resolve_repo_path(repo_root, non_local_runbook_path)
    resolved_json_output = resolve_repo_path(repo_root, json_output_path)
    resolved_markdown_output = resolve_repo_path(repo_root, markdown_output_path)

    data = load_evidence_document(evidence_path, repo_root)
    by_phase = canonical_requirements(data)
    reports = {
        "public_beta": report_text(resolved_public_beta_blockers, repo_root),
        "production_release": report_text(resolved_production_blockers, repo_root),
    }
    rows = packet_rows(repo_root, by_phase, reports)
    redaction_policy = data["redaction_policy"]
    packet = {
        "schema_version": PACKET_SCHEMA,
        "generated_by": f"scripts/{SCRIPT_NAME}:{GENERATOR_VERSION}",
        "generator_version": GENERATOR_VERSION,
        "outputs": {
            "json": normalize_path(resolved_json_output, repo_root),
            "markdown": normalize_path(resolved_markdown_output, repo_root),
        },
        "source": {
            "evidence_manifest": file_record(resolved_evidence, repo_root),
            "public_beta_blocker_report": file_record(
                resolved_public_beta_blockers,
                repo_root,
            ),
            "production_release_blocker_report": file_record(
                resolved_production_blockers,
                repo_root,
            ),
            "non_local_release_evidence_runbook": file_record(
                resolved_runbook,
                repo_root,
            ),
            "public_beta_template_dir": non_local_checker.PUBLIC_BETA_TEMPLATE_DIR.as_posix(),
            "production_release_template_dir": (
                non_local_checker.PRODUCTION_RELEASE_TEMPLATE_DIR.as_posix()
            ),
        },
        "release_version": data["release_version"],
        "release_source": data["source"],
        "status": data["status"],
        "status_summary": status_summary(data, by_phase),
        "policy": {
            "no_secrets": redaction_policy["no_secrets"],
            "redacted_field_families": redaction_policy["redacted_fields"],
            "template_only_can_complete": False,
            "completion_rule": (
                "Template records are packet preparation material only. A row can "
                "be complete only when reviewed retained evidence is referenced in "
                "release-artifacts/latest/public-beta-evidence.json."
            ),
        },
        "rows": rows,
        "validation_commands": sorted(
            {
                command
                for row in rows
                for command in row["validation_commands"]
            }
        ),
    }
    try:
        evidence_checker.scan_for_secret_like_data(packet)
    except evidence_checker.PublicBetaEvidenceError as exc:
        raise ReleaseEvidencePacketIndexError(
            f"generated packet contains secret-like data: {exc}"
        ) from exc
    return packet


def json_text(value: Any) -> str:
    """Return deterministic JSON text."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def markdown_for_packet(packet: dict[str, Any]) -> str:
    """Build the human-readable packet index."""
    source = packet["source"]
    policy = packet["policy"]
    lines = [
        "# Release Evidence Packet Index",
        "",
        (
            "This generated index maps every public-beta and production-release "
            "evidence requirement to its blocker report row, evidence template, "
            "retained-artifact expectation, validation commands, and current "
            "readiness posture. It contains no secrets and does not change "
            "readiness claims."
        ),
        "",
        "The committed baseline remains blocked for public beta and production release.",
        "",
        "## Packet Metadata",
        "",
        shared_report.markdown_table(
            ["Field", "Value"],
            [
                ["Generated by", f"`{packet['generated_by']}`"],
                ["Generator version", f"`{packet['generator_version']}`"],
                ["JSON output", f"`{packet['outputs']['json']}`"],
                ["Markdown output", f"`{packet['outputs']['markdown']}`"],
                ["Evidence manifest", f"`{source['evidence_manifest']['path']}`"],
                [
                    "Public beta blocker report",
                    f"`{source['public_beta_blocker_report']['path']}`",
                ],
                [
                    "Production blocker report",
                    f"`{source['production_release_blocker_report']['path']}`",
                ],
                [
                    "Non-local evidence runbook",
                    f"`{source['non_local_release_evidence_runbook']['path']}`",
                ],
                ["Release version", f"`{packet['release_version']}`"],
                ["Public beta status", f"`{packet['status'][PUBLIC_BETA_PHASE]}`"],
                [
                    "Production release status",
                    f"`{packet['status'][PRODUCTION_PHASE]}`",
                ],
                ["No-secret policy", f"`{str(policy['no_secrets']).lower()}`"],
                [
                    "Template-only can complete",
                    f"`{str(policy['template_only_can_complete']).lower()}`",
                ],
            ],
        ),
        "",
        "## Status Summary",
        "",
        shared_report.markdown_table(
            [
                "Phase",
                "Overall Status",
                "Missing",
                "Pending",
                "Blocked",
                "Accepted Risk",
                "Not Applicable",
                "Complete",
                "Incomplete",
            ],
            [
                [
                    summary["label"],
                    f"`{summary['overall_status']}`",
                    summary["counts"]["missing"],
                    summary["counts"]["pending"],
                    summary["counts"]["blocked"],
                    summary["counts"]["accepted_risk"],
                    summary["counts"]["not_applicable"],
                    summary["counts"]["complete"],
                    summary["incomplete"],
                ]
                for summary in packet["status_summary"]
            ],
        ),
        "",
        "## Packet Rows",
        "",
        shared_report.markdown_table(
            [
                "Phase",
                "Requirement",
                "Status",
                "Evidence Posture",
                "Owner/Reviewer Posture",
                "Blocker Report",
                "Template",
                "Retained Artifact Expectation",
                "Template-Only Completion",
                "Validation Commands",
            ],
            [
                [
                    row["phase_label"],
                    f"`{row['requirement_id']}`",
                    f"`{row['status']}`",
                    row["evidence_posture"],
                    row["owner_reviewer_posture"],
                    (
                        f"`{row['blocker_report']['path']}` / "
                        f"{row['blocker_report']['section']}"
                    ),
                    f"`{row['template']['path']}`",
                    (
                        f"`{row['retained_artifact_expectation']['path']}`; "
                        f"{row['retained_artifact_expectation']['operator_notes']}"
                    ),
                    f"`{str(row['template_only_can_complete']).lower()}`",
                    "; ".join(f"`{command}`" for command in row["validation_commands"]),
                ]
                for row in packet["rows"]
            ],
        ),
        "",
        "## Validation Commands",
        "",
        shared_report.markdown_table(
            ["Command"],
            [[f"`{command}`"] for command in packet["validation_commands"]],
        ),
    ]
    return "\n".join(lines) + "\n"


def build_outputs(
    repo_root: Path,
    evidence_path: Path,
    public_beta_blockers_path: Path,
    production_release_blockers_path: Path,
    non_local_runbook_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> tuple[str, str]:
    """Return deterministic JSON and Markdown output text."""
    packet = build_packet(
        repo_root,
        evidence_path,
        public_beta_blockers_path,
        production_release_blockers_path,
        non_local_runbook_path,
        json_output_path,
        markdown_output_path,
    )
    return json_text(packet), markdown_for_packet(packet)


def write_outputs(
    repo_root: Path,
    evidence_path: Path,
    public_beta_blockers_path: Path,
    production_release_blockers_path: Path,
    non_local_runbook_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> list[Path]:
    """Generate and write the committed packet index outputs."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    json_output_text, markdown_output_text = build_outputs(
        repo_root,
        evidence_path,
        public_beta_blockers_path,
        production_release_blockers_path,
        non_local_runbook_path,
        json_output_path,
        markdown_output_path,
    )
    json_output.parent.mkdir(parents=True, exist_ok=True)
    markdown_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json_output_text, encoding="utf-8", newline="\n")
    markdown_output.write_text(markdown_output_text, encoding="utf-8", newline="\n")
    return [json_output, markdown_output]


def check_outputs(
    repo_root: Path,
    evidence_path: Path,
    public_beta_blockers_path: Path,
    production_release_blockers_path: Path,
    non_local_runbook_path: Path,
    json_output_path: Path,
    markdown_output_path: Path,
) -> int:
    """Check that committed packet index outputs match generated output."""
    json_output = resolve_repo_path(repo_root, json_output_path)
    markdown_output = resolve_repo_path(repo_root, markdown_output_path)
    missing = [
        output
        for output in (json_output, markdown_output)
        if not output.exists()
    ]
    if missing:
        for output in missing:
            print(f"missing {normalize_path(output, repo_root)}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_packet_index.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1

    expected_json, expected_markdown = build_outputs(
        repo_root,
        evidence_path,
        public_beta_blockers_path,
        production_release_blockers_path,
        non_local_runbook_path,
        json_output_path,
        markdown_output_path,
    )
    mismatches = []
    if json_output.read_text(encoding="utf-8") != expected_json:
        mismatches.append(normalize_path(json_output, repo_root))
    if markdown_output.read_text(encoding="utf-8") != expected_markdown:
        mismatches.append(normalize_path(markdown_output, repo_root))
    if mismatches:
        for path in mismatches:
            print(f"changed {path}", file=sys.stderr)
        print(
            "run `python scripts/generate_release_evidence_packet_index.py` "
            "and commit the regenerated files",
            file=sys.stderr,
        )
        return 1
    print("release evidence packet index is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse command-line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--evidence", type=Path, default=evidence_checker.DEFAULT_EVIDENCE)
    parser.add_argument(
        "--public-beta-blockers",
        type=Path,
        default=DEFAULT_PUBLIC_BETA_BLOCKERS,
    )
    parser.add_argument(
        "--production-release-blockers",
        type=Path,
        default=DEFAULT_PRODUCTION_RELEASE_BLOCKERS,
    )
    parser.add_argument(
        "--non-local-runbook",
        type=Path,
        default=DEFAULT_NON_LOCAL_RUNBOOK,
    )
    parser.add_argument("--json-output", type=Path, default=DEFAULT_JSON_OUTPUT)
    parser.add_argument("--markdown-output", type=Path, default=DEFAULT_MARKDOWN_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the generator CLI."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    repo_root = args.repo_root.resolve()
    try:
        if args.check:
            return check_outputs(
                repo_root,
                args.evidence,
                args.public_beta_blockers,
                args.production_release_blockers,
                args.non_local_runbook,
                args.json_output,
                args.markdown_output,
            )
        written = write_outputs(
            repo_root,
            args.evidence,
            args.public_beta_blockers,
            args.production_release_blockers,
            args.non_local_runbook,
            args.json_output,
            args.markdown_output,
        )
    except ReleaseEvidencePacketIndexError as exc:
        print(f"release evidence packet index generation failed: {exc}", file=sys.stderr)
        return 1
    for path in written:
        print(normalize_path(path, repo_root))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
