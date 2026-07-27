#!/usr/bin/env python3
"""Generate the canonical release risk register."""

from __future__ import annotations

import argparse
import filecmp
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

import check_risk_register as checker
import check_release_evidence_issue_links as issue_links_checker
import check_slither_baseline as slither_baseline_checker


GENERATOR_VERSION = "1"
DEFAULT_OUTPUT = checker.DEFAULT_REGISTER
SLITHER_RISK_ID = "RISK-SLITHER-001"
ISSUE_LINKS_PATH = issue_links_checker.DEFAULT_ISSUE_LINKS.as_posix()
ISSUE_BACKLOG_PATH = issue_links_checker.DEFAULT_BACKLOG.as_posix()

RISK_TRACKING_REQUIREMENTS: dict[str, list[tuple[str, str]]] = {
    "RISK-EXT-001": [
        ("public_beta", "fork_deployment_rehearsal"),
        ("public_beta", "testnet_deployment_rehearsal"),
        ("public_beta", "fork_testnet_ceremony_evidence"),
        ("public_beta", "fork_testnet_randomizer_operations_evidence"),
        ("public_beta", "verified_deployed_addresses"),
        ("public_beta", "explorer_verification_status"),
    ],
    "RISK-GOV-001": [
        ("public_beta", "fork_testnet_ceremony_evidence"),
        ("production_release", "live_ceremony_evidence"),
    ],
    "RISK-RAND-001": [
        ("public_beta", "fork_testnet_randomizer_operations_evidence"),
        ("production_release", "live_randomizer_operations_evidence"),
    ],
    "RISK-REL-001": [
        ("production_release", "production_signatures"),
        ("production_release", "signed_git_tag"),
        ("production_release", "production_address_books"),
        ("production_release", "production_broadcast_retention"),
        ("production_release", "live_deployment_manifest"),
        ("production_release", "live_explorer_verification"),
    ],
    "RISK-META-001": [
        ("production_release", "live_marketplace_indexer_evidence"),
        ("production_release", "live_metadata_browser_evidence"),
    ],
}

SOURCE_DOCUMENT_PATHS = [
    "release-artifacts/schema/risk-register.schema.json",
    "ops/ROADMAP.md",
    "ops/EXECUTION_BACKLOG.md",
    "docs/audit-package.md",
    "docs/release-readiness.md",
    "docs/permanence-packages.md",
    "docs/royalty-policy.md",
    "docs/warning-dispositions.md",
    "docs/known-blockers.md",
    "docs/adr/0017-raise-only-parameter-governance.md",
    "ops/SLITHER_BASELINE.json",
    "ops/SLITHER_BASELINE.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/public-beta-blockers.md",
    "release-artifacts/latest/production-release-blockers.md",
    ISSUE_LINKS_PATH,
]

RISK_DEFINITIONS: list[dict[str, Any]] = [
    {
        "id": "RISK-AUD-001",
        "title": "Completed external audit and post-audit remediation are missing",
        "area": "audit",
        "severity": "critical",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate F",
        "source": "clean-main reviewer rebaseline and release evidence blockers",
        "mitigation": (
            "Retain a reviewed external audit report, map findings to issues, "
            "add remediation evidence, and keep post-audit remediation blocked "
            "until accepted by maintainers."
        ),
        "residual_risk": (
            "The local test and Slither baseline is not an independent security "
            "assessment and cannot support public beta or production claims."
        ),
        "evidence_paths": [
            "docs/audit-package.md",
            "release-artifacts/latest/public-beta-blockers.md",
            "release-artifacts/latest/production-release-blockers.md",
            (
                "release-artifacts/evidence/external-audit-report/"
                "external-audit-report-retained-artifact-template.md"
            ),
        ],
        "checks": [
            "python scripts/test_external_audit_report_evidence.py",
            "python scripts/check_external_audit_report_evidence.py",
            "python scripts/test_audit_package.py",
            "python scripts/check_audit_package.py",
            "python scripts/check_public_beta_evidence.py",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/215",
            "https://github.com/6529-Collections/6529Stream/issues/231",
        ],
    },
    {
        "id": "RISK-AUD-002",
        "title": "Risk register and audit-boundary drift",
        "area": "audit_boundary",
        "severity": "medium",
        "status": "mitigated_local",
        "owner": "audit",
        "target_gate": "Gate F",
        "source": "AUD-002",
        "mitigation": (
            "Generate this risk register from the committed roadmap, backlog, "
            "blocker reports, Slither baseline, and audit package, then fail "
            "local and CI checks on missing categories, stale hashes, or unsafe "
            "accepted-risk metadata."
        ),
        "residual_risk": (
            "The register can only summarize committed public evidence; it does "
            "not replace real external audit, production ceremony, or marketplace evidence."
        ),
        "evidence_paths": [
            "release-artifacts/schema/risk-register.schema.json",
            "docs/audit-package.md",
            "ops/EXECUTION_BACKLOG.md",
        ],
        "checks": [
            "python scripts/test_risk_register.py",
            "python scripts/check_risk_register.py",
            "python scripts/generate_risk_register.py --check",
        ],
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/388"],
    },
    {
        "id": "RISK-EXT-001",
        "title": "Public beta external execution evidence remains incomplete",
        "area": "external_evidence",
        "severity": "high",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate E",
        "source": "public-beta evidence status and clean-main reviewer rebaseline",
        "mitigation": (
            "Retain reviewed fork, testnet, metadata browser, ceremony, randomizer, "
            "verified address, and explorer evidence through the no-secret evidence intake."
        ),
        "residual_risk": (
            "Local and fork artifacts do not prove public testnet or live-chain "
            "deployment behavior, explorer verification, or indexer-visible state."
        ),
        "evidence_paths": [
            "docs/release-readiness.md",
            "release-artifacts/latest/public-beta-evidence.json",
            "release-artifacts/latest/public-beta-blockers.md",
        ],
        "checks": [
            "python scripts/test_public_beta_evidence.py",
            "python scripts/check_public_beta_evidence.py",
            "python scripts/test_non_local_release_evidence.py",
            "python scripts/check_non_local_release_evidence.py",
        ],
        "tracking_requirements": RISK_TRACKING_REQUIREMENTS["RISK-EXT-001"],
    },
    {
        "id": "RISK-GOV-001",
        "title": "Production governance ceremony and signer custody proof are missing",
        "area": "governance",
        "severity": "high",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate F",
        "source": "signer custody readiness and admin ceremony evidence model",
        "mitigation": (
            "Retain reviewed Safe ownership, role grants, signer manager, pause "
            "guardian, emergency recipient, signer custody, rotation, and monitoring evidence."
        ),
        "residual_risk": (
            "Production authority could be misunderstood or unverifiable without "
            "reviewed ceremony artifacts and custody evidence."
        ),
        "evidence_paths": [
            "docs/signer-custody-readiness.md",
            "deployments/admin-ceremony/admin-ceremony-evidence-template.json",
            "deployments/admin-ceremony/admin-ceremony-retained-artifact-template.md",
        ],
        "checks": [
            "python scripts/test_signer_custody_readiness.py",
            "python scripts/check_signer_custody_readiness.py",
            "python scripts/test_admin_ceremony_evidence.py",
            "python scripts/check_admin_ceremony_evidence.py",
        ],
        "tracking_requirements": RISK_TRACKING_REQUIREMENTS["RISK-GOV-001"],
    },
    {
        "id": "RISK-GOV-002",
        "title": "Metadata satellite writer grants are whole-module",
        "area": "governance",
        "severity": "high",
        "status": "open_blocker",
        "owner": "protocol",
        "target_gate": "Gate E",
        "source": "CON-015 launch metadata and preservation authorization model",
        "mitigation": (
            "Implement a fail-closed record-family classifier and exact family-to-"
            "authority mapping, reject undeclared families, enforce every-family "
            "snapshot authority, persist the authorization class, and retain "
            "independently reviewed candidate-bound grant, lifecycle, runtime, and "
            "deployment evidence."
        ),
        "residual_risk": (
            "A compromised or over-broad metadata/preservation writer can publish "
            "records for every record family accepted by the target launch module."
        ),
        "evidence_paths": [
            "docs/collection-metadata-contract.md",
            "release-artifacts/record-family-authorization-inventory.json",
            "release-artifacts/schema/record-family-authorization-inventory.v1.schema.json",
            "deployments/schema/record-family-authorization-evidence.v1.schema.json",
            "deployments/schema/record-family-authorization-grant-map.v1.schema.json",
            "deployments/record-family-authorization/record-family-authorization-evidence-template.json",
        ],
        "checks": [
            "python scripts/test_record_family_authorization.py",
            "python scripts/check_record_family_authorization.py",
            "python scripts/check_risk_register.py",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/690"
        ],
    },
    {
        "id": "RISK-GOV-003",
        "title": "Governance Executor proposal-selected native-value authority",
        "area": "governance",
        "severity": "high",
        "status": "open_blocker",
        "owner": "security",
        "target_gate": "Gate F",
        "source": (
            "Historical Slither arbitrary-send-eth fingerprint "
            "sha256:c1b7db0f62e7ff01758e147d41188f1d33ea9a448efb0162d98b14e3ef11cbe8; "
            "live semantic anchor "
            "StreamGovernanceExecutor._executeCall(bytes32,uint256,GovernanceCall,bytes) "
            "assembly call"
        ),
        "mitigation": (
            "Implement and bind a closed-world target, selector, and native-value "
            "action policy; review every balance source and destination; retain hostile "
            "target, reentrancy, value-exhaustion, refund, and atomic-rollback tests; "
            "prove the policy in deployment evidence; and complete independent review "
            "before governance ownership cutover."
        ),
        "residual_risk": (
            "The Executor can forward proposal-selected native value from a governed "
            "batch. Bounded assembly prevents returndata bombs but is invisible to "
            "Slither's arbitrary-send-eth detector and does not constrain destination, "
            "value, balance source, or downstream call semantics."
        ),
        "evidence_paths": [
            "smart-contracts/StreamGovernanceExecutor.sol",
            "docs/adr/0004-admin-governance.md",
            "docs/known-blockers.md",
            "test/StreamGovernanceExecutor.t.sol",
        ],
        "checks": [
            "forge test --match-path test/StreamGovernanceExecutor.t.sol -vvv",
            "python scripts/test_risk_register.py",
            "python scripts/check_risk_register.py",
            "python scripts/test_release_mode.py",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/656",
            "https://github.com/6529-Collections/6529Stream/issues/658",
            "https://github.com/6529-Collections/6529Stream/issues/685",
        ],
    },
    {
        "id": "RISK-GOV-004",
        "title": "Governed parameter production bindings and sizing evidence are incomplete",
        "area": "governance",
        "severity": "high",
        "status": "open_blocker",
        "owner": "protocol",
        "target_gate": "Gate G",
        "source": "ADR 0017 governed-parameter closed world and issue #684",
        "mitigation": (
            "Complete the checked versioned 22-GGP/3-GTP inventory by binding "
            "every row to the required production profile instance, genesis "
            "value, immutable floor, failure class or cadence rule, reviewed "
            "candidate-bound measurement evidence, and reachable fixed-stipend "
            "raise chains; bind the concrete candidate and keep strict production "
            "release mode fail-closed on every unresolved row."
        ),
        "residual_risk": (
            "The committed inventory is a structurally checked planning artifact. "
            "It does not yet prove that the 37-entry production candidate registers "
            "every governed parameter on the correct deployed host with safe values, "
            "floors, cadence evidence, or downstream gas compatibility."
        ),
        "evidence_paths": [
            "docs/adr/0017-raise-only-parameter-governance.md",
            "docs/launch-v1-target-architecture.md",
            "docs/known-blockers.md",
            "release-artifacts/governed-parameter-inventory.json",
            "release-artifacts/schema/governed-parameter-inventory.v1.schema.json",
            "release-artifacts/genesis-deployment-profile.json",
            "scripts/check_governed_parameter_inventory.py",
            "scripts/check_governed_parameter_identifiers.py",
        ],
        "checks": [
            "python scripts/test_governed_parameter_inventory.py",
            "python scripts/check_governed_parameter_inventory.py",
            "python scripts/check_governed_parameter_inventory.py --require-complete",
            "python scripts/test_governed_parameter_identifiers.py",
            "python scripts/check_governed_parameter_identifiers.py",
            "python scripts/test_risk_register.py",
            "python scripts/check_risk_register.py",
            "python scripts/test_release_mode.py",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/656",
            "https://github.com/6529-Collections/6529Stream/issues/671",
            "https://github.com/6529-Collections/6529Stream/issues/684",
        ],
    },
    {
        "id": "RISK-META-001",
        "title": "Marketplace, indexer, and metadata browser evidence is incomplete",
        "area": "metadata_marketplace",
        "severity": "high",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate E",
        "source": "clean-main reviewer rebaseline and release readiness dashboard",
        "mitigation": (
            "Retain fork, testnet, and live evidence for token metadata refresh, "
            "animation execution, marketplace display, royalty display, event replay, and cache invalidation."
        ),
        "residual_risk": (
            "Local browser and fixture checks do not prove collector-facing marketplace behavior."
        ),
        "evidence_paths": [
            "docs/metadata.md",
            "docs/integrations/marketplace-indexer-evidence.md",
            "docs/release-readiness.md",
            "release-artifacts/latest/public-beta-blockers.md",
            "release-artifacts/evidence/marketplace-indexer/fork-testnet-marketplace-indexer-retained-artifact-template.md",
            "release-artifacts/evidence/marketplace-indexer/live-marketplace-indexer-retained-artifact-template.md",
        ],
        "checks": [
            "python scripts/test_metadata_fixtures.py",
            "python scripts/check_metadata_fixtures.py",
            "python scripts/test_metadata_browser_sandbox.py",
            "python scripts/check_metadata_browser_sandbox.py",
            "python scripts/test_marketplace_indexer_evidence.py",
            "python scripts/check_marketplace_indexer_evidence.py",
        ],
        "tracking_requirements": RISK_TRACKING_REQUIREMENTS["RISK-META-001"],
    },
    {
        "id": "RISK-ONE-001",
        "title": "Best-in-class 1/1 product surfaces remain design and evidence work",
        "area": "one_of_one_product",
        "severity": "medium",
        "status": "planned_mitigation",
        "owner": "product",
        "target_gate": "Gate G",
        "source": "clean-main reviewer rebaseline and integration-readiness roadmap",
        "mitigation": (
            "Decide and implement or explicitly defer contract-level metadata, "
            "1/1 provenance manifests, artist/authenticity records, royalty policy, "
            "collector permanence packages, and marketplace/indexer evidence."
        ),
        "residual_risk": (
            "The protocol can be locally safe without yet meeting a world-class "
            "collector-facing 1/1 release bar."
        ),
        "evidence_paths": [
            "ops/ROADMAP.md",
            "ops/EXECUTION_BACKLOG.md",
            "docs/metadata.md",
            "docs/permanence-packages.md",
            "docs/royalty-policy.md",
        ],
        "checks": [
            "python scripts/test_risk_register.py",
            "python scripts/check_risk_register.py",
            "python scripts/test_one_of_one_permanence_package.py",
            "python scripts/check_one_of_one_permanence_package.py",
            "python scripts/test_royalty_policy.py",
            "python scripts/check_royalty_policy.py",
            "python scripts/check_audit_package.py",
        ],
        "tracking": ["ops/EXECUTION_BACKLOG.md"],
    },
    {
        "id": "RISK-RAND-001",
        "title": "Non-local randomizer provider operations evidence is missing",
        "area": "randomizer_operations",
        "severity": "high",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate E",
        "source": "public-beta evidence blockers and randomizer operations runbook",
        "mitigation": (
            "Retain reviewed fork/testnet/live provider configuration, funding, "
            "request health, epoch, stale/failure/retry, and metadata-finalization evidence."
        ),
        "residual_risk": (
            "Local mock provider evidence does not prove live provider funding, "
            "callback, or operational monitoring behavior."
        ),
        "evidence_paths": [
            "docs/randomizer-operations.md",
            "deployments/randomizer-operations/anvil-6529stream-v0.1.0-001-local.json",
            "release-artifacts/latest/public-beta-blockers.md",
        ],
        "checks": [
            "python scripts/test_randomizer_operations.py",
            "python scripts/check_randomizer_operations.py",
            "python scripts/check_public_beta_evidence.py",
        ],
        "tracking_requirements": RISK_TRACKING_REQUIREMENTS["RISK-RAND-001"],
    },
    {
        "id": "RISK-REL-001",
        "title": "Production release signatures, signed tags, and live bytecode proof are missing",
        "area": "release_integrity",
        "severity": "high",
        "status": "open_blocker",
        "owner": "TBD",
        "target_gate": "Gate G",
        "source": "production release blocker report and release-signature policy",
        "mitigation": (
            "Retain production checksum signatures, signed Git tag evidence, "
            "production deployment manifests, source verification inputs, and live bytecode/explorer proof."
        ),
        "residual_risk": (
            "The local bytecode-to-release proof does not prove deployed live bytecode "
            "or production signer approval."
        ),
        "evidence_paths": [
            "docs/release-signatures.md",
            "release-artifacts/latest/source-verification-inputs.json",
            "release-artifacts/latest/production-release-blockers.md",
        ],
        "checks": [
            "python scripts/test_signed_release_tag.py",
            "python scripts/check_signed_release_tag.py",
            "python scripts/test_bytecode_release_proof.py",
            "python scripts/generate_bytecode_release_proof.py --check",
        ],
        "tracking_requirements": RISK_TRACKING_REQUIREMENTS["RISK-REL-001"],
    },
    {
        "id": "RISK-SIZE-001",
        "title": "StreamCore misses the normative production headroom gate",
        "area": "core_size",
        "severity": "high",
        "status": "open_blocker",
        "owner": "protocol",
        "target_gate": "Gate G",
        "source": "launch conformance matrix, target architecture, and artifact-backed size proof",
        "mitigation": (
            "Recover real Core headroom through measured compression, extraction, or "
            "authorized relocation while retaining every mandatory hook; keep non-critical "
            "product surfaces satellite-first."
        ),
        "residual_risk": (
            "The current 24,152-byte runtime leaves 424 bytes of EIP-170 headroom, "
            "1,576 bytes below the non-waivable 2,000-byte production deployment minimum."
        ),
        "evidence_paths": [
            "docs/known-blockers.md",
            "ops/ROADMAP.md",
            "docs/status.md",
        ],
        "checks": [
            "python scripts/build_release_artifacts.py",
            "python scripts/check_contract_size_budget.py",
            "python scripts/check_release_mode.py --phase production-release",
            "python scripts/generate_release_manifest.py --check",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/654",
            "https://github.com/6529-Collections/6529Stream/issues/115",
        ],
    },
    {
        "id": SLITHER_RISK_ID,
        "title": "First-party production Slither findings remain open",
        "area": "static_analysis",
        "severity": "high",
        "status": "open_blocker",
        "owner": "security",
        "target_gate": "Gate F",
        "source": "Normalized first-party production Slither high/medium baseline",
        "mitigation": (
            "Disposition and remediate every open first-party production high/medium "
            "finding, retain issue-linked proof for each resolution, and keep the "
            "exact normalized baseline drift gate green."
        ),
        "residual_risk": (
            "The current normalized baseline contains open first-party production "
            "findings; local normalization and drift detection do not establish that "
            "any finding is safe."
        ),
        "evidence_paths": [
            "ops/SLITHER_BASELINE.json",
            "ops/SLITHER_BASELINE.md",
            "docs/slither.md",
            "scripts/check_slither_baseline.py",
        ],
        "checks": [
            "python scripts/test_slither_baseline.py",
            "python scripts/check_slither_baseline.py --baseline-only",
            "python scripts/check_slither_baseline.py --run-slither",
            "python scripts/test_release_mode.py",
            "python scripts/check_audit_package.py",
        ],
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/658",
            "https://github.com/6529-Collections/6529Stream/issues/654",
        ],
    },
    {
        "id": "RISK-WARN-001",
        "title": "Compiler, NatSpec, lint, and warning noise still need release disposition",
        "area": "warning_hygiene",
        "severity": "medium",
        "status": "mitigated_local",
        "owner": "oss",
        "target_gate": "Gate G",
        "source": "ONE-007 warning disposition baseline",
        "mitigation": (
            "Capture warning categories, fix low-risk first-party NatSpec noise, "
            "document accepted solc, documentation, linter, vendored, test-only, "
            "ABI-compatibility, and size-tradeoff dispositions, and fail local "
            "and CI checks if the disposition document or source anchors drift."
        ),
        "residual_risk": (
            "Accepted local-baseline warnings remain audit inputs and should be "
            "rechecked before public beta or production release."
        ),
        "evidence_paths": [
            "ops/ROADMAP.md",
            "ops/EXECUTION_BACKLOG.md",
            "docs/tooling.md",
            "docs/warning-dispositions.md",
        ],
        "checks": [
            "forge build",
            "python scripts/run_forge_size_log.py --log cache/forge-size.log",
            "forge doc --build",
            "python scripts/test_warning_dispositions.py",
            "python scripts/check_warning_dispositions.py --solc-warnings-log cache/forge-size.log",
        ],
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/428"],
    },
]


def file_ref(repo_root: Path, relative_path: str) -> dict[str, str]:
    """Build a hashed file reference."""
    resolved = checker.resolve_repo_file(repo_root, relative_path, relative_path)
    return {"path": relative_path, "sha256": checker.file_sha256(resolved)}


def canonical_issue_urls(repo_root: Path) -> dict[tuple[str, str], str]:
    """Load validated evidence-issue URLs by canonical phase and requirement ID."""
    issue_links_path = repo_root / ISSUE_LINKS_PATH
    backlog_path = repo_root / ISSUE_BACKLOG_PATH
    issue_links = issue_links_checker.require_dict(
        issue_links_checker.load_json(issue_links_path),
        str(issue_links_path),
    )
    backlog = issue_links_checker.require_dict(
        issue_links_checker.load_json(backlog_path),
        str(backlog_path),
    )
    issue_links_checker.validate_links_document(
        issue_links,
        backlog,
        repo_root,
        backlog_path,
    )

    urls: dict[tuple[str, str], str] = {}
    for index, raw_link in enumerate(
        issue_links_checker.require_list(issue_links.get("links"), "links")
    ):
        link = issue_links_checker.require_dict(raw_link, f"links[{index}]")
        key = (
            issue_links_checker.require_string(
                link.get("phase"),
                f"links[{index}].phase",
            ),
            issue_links_checker.require_string(
                link.get("requirement_id"),
                f"links[{index}].requirement_id",
            ),
        )
        if key in urls:
            raise issue_links_checker.ReleaseEvidenceIssueLinksError(
                "duplicate canonical evidence issue key: " + ".".join(key)
            )
        urls[key] = issue_links_checker.require_string(
            link.get("issue_url"),
            f"links[{index}].issue_url",
        )
    return urls


def resolve_tracking_urls(
    issue_urls: dict[tuple[str, str], str],
    requirement_keys: list[tuple[str, str]],
) -> list[str]:
    """Resolve ordered risk tracking URLs from canonical requirement keys."""
    missing = [key for key in requirement_keys if key not in issue_urls]
    if missing:
        raise issue_links_checker.ReleaseEvidenceIssueLinksError(
            "missing canonical evidence issue key(s): "
            + ", ".join(".".join(key) for key in missing)
        )
    return [issue_urls[key] for key in requirement_keys]


def slither_open_residual_risk(repo_root: Path) -> str:
    """Describe the validated live baseline without duplicating mutable counts."""
    baseline = slither_baseline_checker.validate_baseline(
        repo_root,
        repo_root / slither_baseline_checker.DEFAULT_BASELINE,
        repo_root / slither_baseline_checker.DEFAULT_MARKDOWN,
    )
    open_counts = {impact: 0 for impact in slither_baseline_checker.IMPACTS}
    for finding in baseline["findings"]:
        if finding["status"] == "Open":
            open_counts[finding["impact"]] += 1
    return (
        "The current normalized baseline contains "
        f"{open_counts['High']} High and {open_counts['Medium']} Medium open "
        "first-party production findings; local normalization and drift detection "
        "do not establish that any finding is safe."
    )


def build_register(repo_root: Path) -> dict[str, Any]:
    """Build the deterministic risk register object."""
    issue_urls = canonical_issue_urls(repo_root)
    risks = []
    for definition in sorted(RISK_DEFINITIONS, key=lambda item: str(item["id"])):
        risk = {
            key: value
            for key, value in definition.items()
            if key not in {"evidence_paths", "tracking_requirements"}
        }
        tracking_requirements = definition.get("tracking_requirements")
        if tracking_requirements is not None:
            risk["tracking"] = resolve_tracking_urls(
                issue_urls,
                tracking_requirements,
            )
        if risk["id"] == SLITHER_RISK_ID:
            risk["residual_risk"] = slither_open_residual_risk(repo_root)
        risk["evidence"] = [
            file_ref(repo_root, evidence_path) for evidence_path in definition["evidence_paths"]
        ]
        risk["risk_acceptance"] = None
        risks.append(risk)

    return {
        "schema_version": checker.RISK_REGISTER_SCHEMA,
        "generated_by": f"scripts/generate_risk_register.py:{GENERATOR_VERSION}",
        "maturity": "pre_audit_local_baseline",
        "readiness_boundary": (
            "Open blockers and planned mitigations are not launch approvals. "
            "Public beta and production claims require reviewed retained evidence "
            "or explicit accepted-risk records in the public-beta evidence manifest."
        ),
        "source_documents": [file_ref(repo_root, path) for path in SOURCE_DOCUMENT_PATHS],
        "status_taxonomy": {
            "accepted_local_baseline": (
                "Accepted for local pre-audit baseline only; still reviewable before release."
            ),
            "accepted_risk": (
                "Explicit risk acceptance with owner, date, expiry, and reference."
            ),
            "mitigated_local": (
                "Mitigated by committed local checks or docs; external proof may still be required."
            ),
            "open_blocker": "Blocks public beta, audit-ready, or production claims.",
            "planned_mitigation": "Tracked but not yet implemented or evidenced.",
        },
        "risk_acceptance_policy": (
            "Accepted-risk rows require owner approval, an expiry, a reference, "
            "and matching public-beta evidence status where they affect launch claims."
        ),
        "risks": risks,
        "redaction_policy": {
            "no_secrets": True,
            "redacted_fields": [
                "private_key",
                "mnemonic",
                "seed_phrase",
                "api_key",
                "rpc_url",
                "bearer_token",
                "client_secret",
                "session_cookie",
                "unreleased_drop_payload",
            ],
        },
        "operator_notes": (
            "Generated no-secret risk register. It summarizes launch blockers and "
            "accepted local-baseline risks; it does not complete external evidence."
        ),
    }


def json_text(value: Any) -> str:
    """Serialize JSON with stable formatting."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def write_output(repo_root: Path, output_path: Path) -> Path:
    """Write the generated risk register."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json_text(build_register(repo_root)), encoding="utf-8", newline="\n")
    return output_path


def check_output(repo_root: Path, output_path: Path) -> int:
    """Check the committed register against generated output and schema."""
    with tempfile.TemporaryDirectory() as temp_dir:
        candidate = Path(temp_dir) / output_path.name
        write_output(repo_root, candidate)
        if not output_path.is_file():
            print(f"missing {output_path}", file=sys.stderr)
            return 1
        if not filecmp.cmp(output_path, candidate, shallow=False):
            print(f"changed {output_path}", file=sys.stderr)
            return 1

    try:
        checker.validate_risk_register(repo_root, output_path)
    except checker.RiskRegisterError as exc:
        print(f"risk register check failed: {exc}", file=sys.stderr)
        return 1
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    output_path = args.output
    if not output_path.is_absolute():
        output_path = repo_root / output_path

    if args.check:
        result = check_output(repo_root, output_path.resolve())
        if result == 0:
            print("risk register is current")
        return result

    written = write_output(repo_root, output_path.resolve())
    print(f"wrote {written}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
