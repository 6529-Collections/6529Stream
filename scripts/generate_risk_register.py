#!/usr/bin/env python3
"""Generate the canonical release risk register."""

from __future__ import annotations

import argparse
import filecmp
import hashlib
import json
import re
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
SIZE_RISK_ID = "RISK-SIZE-001"
BYTECODE_PROOF_PATH = Path("release-artifacts/latest/bytecode-release-proof.json")
RELEASE_MANIFEST_PATH = Path("release-artifacts/latest/release-manifest.json")
ABI_CHECKSUMS_PATH = Path("release-artifacts/latest/abi-checksums.json")
BYTECODE_PROOF_SCHEMA = "6529stream.bytecode-release-proof.v1"
ABI_CHECKSUMS_SCHEMA = "6529stream.abi-checksums.v1"
STREAM_CORE_CONTRACT = "StreamCore"
EIP170_RUNTIME_LIMIT_BYTES = 24_576
PRODUCTION_MINIMUM_MARGIN_BYTES = 2_000
LIVE_SIZE_MIRROR_REQUIREMENTS: dict[Path, tuple[str, ...]] = {
    Path("docs/architecture.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/launch-conformance-matrix.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
        "matrix does not duplicate the mutable runtime or margin",
    ),
    Path("docs/launch-v1-target-architecture.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
        "rather than duplicating",
        "mutable measurements here",
    ),
    Path("docs/tooling.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
        "not by copied tooling\nprose",
    ),
    Path("docs/release-policy.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/status.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/known-blockers.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/release-readiness.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/public-beta-evidence.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("docs/production-readiness-execution.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("ops/ROADMAP.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("ops/EXECUTION_BACKLOG.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
    ),
    Path("ops/AUTONOMOUS_RUN.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
        "are not duplicated in this active run state",
    ),
    Path("ops/workstreams/core-mint-critical-path/active-context.md"): (
        "release-artifacts/latest/bytecode-release-proof.json",
        "not duplicated in this active context",
    ),
}
STALE_SIZE_MIRROR_PATTERNS = (
    r"(?<!then-)current 24,128",
    r"448 bytes of EIP-170",
    r"current 448-byte margin",
    r"1,552 bytes",
)
STABLE_SIZE_POLICY_FRAGMENTS = (
    "approved baseline EIP-170 margin is 2,392 bytes",
)
LIVE_SIZE_MEASUREMENT_PATTERN = re.compile(
    r"(?i)\b(?:now\s+)?measures?\s+\d[\d,]*\s*(?:-byte|bytes)\b"
    r"|\bruntime(?:\s+(?:bytecode|size))?\s*(?:is|as|of|:|=)\s*"
    r"\d[\d,]*\s*(?:-byte|bytes)\b"
    r"|\b(?:current\s+)?(?:StreamCore|Core|permanent\s+target)"
    r"(?:\s+runtime(?:\s+bytecode)?)?\s*(?:is|equals?|:|=)\s*"
    r"\d[\d,]*\s*(?:-byte|bytes)\b"
    r"|\b(?:StreamCore|Core|permanent\s+target)\s*:\s*"
    r"\d[\d,]*\s+runtime(?:\s+bytecode)?\s+bytes\b"
    r"|\b(?:StreamCore|Core|permanent\s+target)(?:\s+runtime)?\s+size\s+"
    r"(?:is|equals?|:)\s*\d[\d,]*\s*(?:-byte|bytes)\b"
    r"|\b(?:EIP-170\s+)?(?:margin|headroom)\s*"
    r"(?:is|equals?|of|:)\s*\d[\d,]*\s*(?:-byte|bytes)\b"
    r"|\b(?:StreamCore|Core|permanent\s+target)\b[^\n]{0,40}\bhas\s+"
    r"(?:a\s+)?\d[\d,]*\s*(?:-byte|bytes)(?:\s+of)?\s+"
    r"(?:runtime(?:\s+bytecode)?|headroom|margin)\b",
)
STATUS_SIZE_PROJECTION_PATH = Path("docs/status.md")
STATUS_SIZE_PROJECTION_START = "<!-- streamcore-size-projection:start -->"
STATUS_SIZE_PROJECTION_END = "<!-- streamcore-size-projection:end -->"
STATUS_SIZE_PROJECTION_PATTERN = re.compile(
    r"(?i)`StreamCore` production runtime as "
    r"(?P<runtime>\d[\d,]*) bytes,\s+"
    r"leaving\s+(?P<margin>\d[\d,]*) bytes of EIP-170 headroom",
)
HISTORICAL_SIZE_BLOCK_START = "<!-- historical-streamcore-size:start -->"
HISTORICAL_SIZE_BLOCK_END = "<!-- historical-streamcore-size:end -->"
AUTONOMOUS_CURRENT_RUN_HEADING = "\n## Current Run Notes"
AUTONOMOUS_PACKAGING_HEADING = "\n## Packaging Notes"
AUTONOMOUS_ACTIVE_END = "\n## PR Queue"
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
        "title": "Record-family authorization candidate binding remains incomplete",
        "area": "governance",
        "severity": "high",
        "status": "open_blocker",
        "owner": "protocol",
        "target_gate": "Gate E",
        "source": (
            "Issue #690 source implementation and candidate-bound record-family "
            "authorization evidence"
        ),
        "mitigation": (
            "Retain the fail-closed source implementation and complete the exact "
            "candidate-bound admission/provider/grant map, shared host-registry "
            "address, finalized current/pending configuration-authority observation, "
            "deployed runtime/codehash bindings, reconciled propose/accept/cancel "
            "lifecycle evidence, phase evidence, and independent review before release."
        ),
        "residual_risk": (
            "Source-level family isolation does not prove the selected candidate's "
            "deployed registry, provider/grant configuration, configuration-authority "
            "state, runtime, or lifecycle; an unbound or drifted candidate could "
            "therefore admit or authorize the wrong record writers."
        ),
        "evidence_paths": [
            "docs/collection-metadata-contract.md",
            "release-artifacts/record-family-authorization-inventory.json",
            "release-artifacts/schema/record-family-authorization-inventory.v1.schema.json",
            "release-artifacts/record-family-authorization-source-catalog.json",
            "release-artifacts/schema/record-family-authorization-source-catalog.v1.schema.json",
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
            "smart-contracts/domains/governance/StreamGovernanceExecutor.sol",
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
        "id": SIZE_RISK_ID,
        "area": "core_size",
        "severity": "high",
        "owner": "protocol",
        "target_gate": "Gate G",
        "source": "launch conformance matrix, target architecture, and artifact-backed size proof",
        "evidence_paths": [
            "docs/known-blockers.md",
            "ops/ROADMAP.md",
            "docs/status.md",
            "release-artifacts/latest/abi-checksums.json",
        ],
        "checks": [
            "python scripts/build_release_artifacts.py",
            "python scripts/check_contract_size_budget.py",
            "python scripts/test_risk_register.py",
            "python scripts/generate_risk_register.py --check",
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


def _load_bytecode_proof(repo_root: Path) -> dict[str, Any]:
    proof_path = repo_root / BYTECODE_PROOF_PATH
    try:
        with proof_path.open("r", encoding="utf-8") as handle:
            proof = json.load(handle)
    except FileNotFoundError as exc:
        raise checker.RiskRegisterError(
            f"missing StreamCore bytecode proof: {BYTECODE_PROOF_PATH.as_posix()}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise checker.RiskRegisterError(
            f"invalid StreamCore bytecode proof JSON: {exc}"
        ) from exc
    if not isinstance(proof, dict):
        raise checker.RiskRegisterError("StreamCore bytecode proof must be an object")
    if proof.get("schema_version") != BYTECODE_PROOF_SCHEMA:
        raise checker.RiskRegisterError(
            f"StreamCore bytecode proof must use schema {BYTECODE_PROOF_SCHEMA}"
        )
    return proof


def _require_proof_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise checker.RiskRegisterError(f"{path} must be an integer")
    return value


def _validate_proof_source_file_binding(
    repo_root: Path,
    proof: dict[str, Any],
    *,
    field: str,
    expected_path: Path,
    label: str,
) -> None:
    source = proof.get("source")
    if not isinstance(source, dict):
        raise checker.RiskRegisterError("bytecode proof source must be an object")
    record = source.get(field)
    if not isinstance(record, dict):
        raise checker.RiskRegisterError(
            f"bytecode proof source.{field} must be an object"
        )
    expected_path_text = expected_path.as_posix()
    if record.get("path") != expected_path_text:
        raise checker.RiskRegisterError(
            f"bytecode proof {label} path must be {expected_path_text}"
        )
    source_path = repo_root / expected_path
    if not source_path.is_file():
        raise checker.RiskRegisterError(
            f"missing bytecode-proof {label}: {expected_path_text}"
        )
    source_bytes = source_path.read_bytes()
    actual_sha256 = "sha256:" + hashlib.sha256(source_bytes).hexdigest()
    actual_size = len(source_bytes)
    if record.get("sha256") != actual_sha256 or record.get("size_bytes") != actual_size:
        raise checker.RiskRegisterError(
            f"stale StreamCore bytecode proof {label} binding: "
            f"expected {actual_sha256}/{actual_size}, "
            f"got {record.get('sha256')}/{record.get('size_bytes')}"
        )


def _validate_measurement(
    *,
    runtime: Any,
    limit: Any,
    margin: Any,
    prefix: str,
) -> tuple[int, int]:
    runtime_int = _require_proof_int(runtime, f"{prefix}.runtime")
    limit_int = _require_proof_int(limit, f"{prefix}.eip170_runtime_limit")
    margin_int = _require_proof_int(margin, f"{prefix}.runtime_margin")
    if runtime_int < 0 or margin_int < 0:
        raise checker.RiskRegisterError(f"{prefix} sizes must be non-negative")
    if limit_int != EIP170_RUNTIME_LIMIT_BYTES:
        raise checker.RiskRegisterError(
            f"{prefix} EIP-170 limit must be {EIP170_RUNTIME_LIMIT_BYTES:,}, "
            f"got {limit_int:,}"
        )
    if margin_int != limit_int - runtime_int:
        raise checker.RiskRegisterError(
            f"{prefix} margin is inconsistent: "
            f"{margin_int:,} != {limit_int:,} - {runtime_int:,}"
        )
    return runtime_int, margin_int


def stream_core_release_measurement(repo_root: Path) -> tuple[int, int]:
    """Return the cycle-free pre-tail StreamCore measurement."""
    path = repo_root / ABI_CHECKSUMS_PATH
    try:
        with path.open("r", encoding="utf-8") as handle:
            artifact = json.load(handle)
    except FileNotFoundError as exc:
        raise checker.RiskRegisterError(
            f"missing StreamCore ABI checksums: {ABI_CHECKSUMS_PATH.as_posix()}"
        ) from exc
    except json.JSONDecodeError as exc:
        raise checker.RiskRegisterError(
            f"invalid StreamCore ABI checksums JSON: {exc}"
        ) from exc
    if not isinstance(artifact, dict):
        raise checker.RiskRegisterError("StreamCore ABI checksums must be an object")
    if artifact.get("schema_version") != ABI_CHECKSUMS_SCHEMA:
        raise checker.RiskRegisterError(
            f"StreamCore ABI checksums must use schema {ABI_CHECKSUMS_SCHEMA}"
        )
    contracts = artifact.get("contracts")
    if not isinstance(contracts, dict):
        raise checker.RiskRegisterError("ABI checksums contracts must be an object")
    row = contracts.get(STREAM_CORE_CONTRACT)
    if not isinstance(row, dict):
        raise checker.RiskRegisterError(
            "ABI checksums have no StreamCore contract row"
        )
    return _validate_measurement(
        runtime=row.get("deployed_bytecode_size_bytes"),
        limit=row.get("eip170_runtime_limit_bytes"),
        margin=row.get("deployed_runtime_margin_bytes"),
        prefix="abi-checksums.contracts.StreamCore",
    )


def stream_core_proof_measurement(repo_root: Path) -> tuple[int, int]:
    """Return the final proof measurement after validating its bound sources."""
    proof = _load_bytecode_proof(repo_root)
    _validate_proof_source_file_binding(
        repo_root,
        proof,
        field="release_manifest",
        expected_path=RELEASE_MANIFEST_PATH,
        label="release-manifest",
    )
    _validate_proof_source_file_binding(
        repo_root,
        proof,
        field="abi_checksums",
        expected_path=ABI_CHECKSUMS_PATH,
        label="ABI-checksums",
    )
    contract_proofs = proof.get("contract_proofs")
    if not isinstance(contract_proofs, list):
        raise checker.RiskRegisterError(
            "bytecode proof contract_proofs must be an array"
        )

    measurements: list[tuple[int, int]] = []
    for index, contract_proof in enumerate(contract_proofs):
        if not isinstance(contract_proof, dict):
            continue
        contract = contract_proof.get("contract")
        if not isinstance(contract, dict) or contract.get("name") != STREAM_CORE_CONTRACT:
            continue
        sizes = contract_proof.get("sizes")
        if not isinstance(sizes, dict):
            raise checker.RiskRegisterError(
                f"StreamCore bytecode proof row {index} sizes must be an object"
            )
        measurements.append(
            _validate_measurement(
                runtime=sizes.get("runtime_bytecode_bytes"),
                limit=sizes.get("eip170_runtime_limit_bytes"),
                margin=sizes.get("runtime_margin_bytes"),
                prefix=f"StreamCore bytecode proof row {index}",
            )
        )

    if not measurements:
        raise checker.RiskRegisterError(
            "bytecode proof has no StreamCore contract proof"
        )
    distinct = sorted(set(measurements))
    if len(distinct) != 1:
        rendered = ", ".join(f"{runtime:,}/{margin:,}" for runtime, margin in distinct)
        raise checker.RiskRegisterError(
            "StreamCore bytecode proof measurements disagree: " + rendered
        )
    return distinct[0]


def stream_core_size_measurement(
    repo_root: Path,
    *,
    require_current_proof: bool = True,
) -> tuple[int, int]:
    """Return the pre-tail measurement and optionally require final-proof parity."""
    release_measurement = stream_core_release_measurement(repo_root)
    if require_current_proof:
        proof_measurement = stream_core_proof_measurement(repo_root)
        if proof_measurement != release_measurement:
            raise checker.RiskRegisterError(
                "StreamCore ABI/proof measurements disagree: "
                f"ABI {release_measurement[0]:,}/{release_measurement[1]:,}, "
                f"proof {proof_measurement[0]:,}/{proof_measurement[1]:,}"
            )
    return release_measurement


def stream_core_size_risk_fields(
    repo_root: Path,
    *,
    require_current_proof: bool = True,
) -> dict[str, str]:
    """Derive Core-size risk state from the cycle-free measurement/final proof."""
    runtime, margin = stream_core_size_measurement(
        repo_root,
        require_current_proof=require_current_proof,
    )
    if margin >= PRODUCTION_MINIMUM_MARGIN_BYTES:
        surplus = margin - PRODUCTION_MINIMUM_MARGIN_BYTES
        relation = (
            "exactly meets"
            if surplus == 0
            else f"is {surplus:,} {'byte' if surplus == 1 else 'bytes'} above"
        )
        return {
            "title": "StreamCore satisfies the normative production headroom gate locally",
            "status": "mitigated_local",
            "mitigation": (
                "Preserve the artifact-backed production margin while retaining every "
                "mandatory Core hook and keeping non-critical product surfaces satellite-first."
            ),
            "residual_risk": (
                f"The current {runtime:,}-byte runtime leaves {margin:,} bytes of "
                f"EIP-170 headroom and {relation} the non-waivable "
                f"{PRODUCTION_MINIMUM_MARGIN_BYTES:,}-byte production deployment minimum. "
                "This local build proof does not replace concrete candidate integration, "
                "independent audit, deployment, or reviewed live-bytecode evidence."
            ),
        }

    shortfall = PRODUCTION_MINIMUM_MARGIN_BYTES - margin
    shortfall_unit = "byte" if shortfall == 1 else "bytes"
    return {
        "title": "StreamCore misses the normative production headroom gate",
        "status": "open_blocker",
        "mitigation": (
            "Recover real Core headroom through measured compression, extraction, or "
            "authorized relocation while retaining every mandatory hook; keep non-critical "
            "product surfaces satellite-first."
        ),
        "residual_risk": (
            f"The current {runtime:,}-byte runtime leaves {margin:,} bytes of "
            f"EIP-170 headroom, {shortfall:,} {shortfall_unit} below the non-waivable "
            f"{PRODUCTION_MINIMUM_MARGIN_BYTES:,}-byte production deployment minimum."
        ),
    }


def _strip_historical_size_blocks(relative_path: Path, text: str) -> str:
    start_count = text.count(HISTORICAL_SIZE_BLOCK_START)
    end_count = text.count(HISTORICAL_SIZE_BLOCK_END)
    pattern = re.compile(
        r"(?s)"
        + re.escape(HISTORICAL_SIZE_BLOCK_START)
        + r".*?"
        + re.escape(HISTORICAL_SIZE_BLOCK_END),
    )
    matches = list(pattern.finditer(text))
    if start_count != end_count or len(matches) != start_count:
        raise checker.RiskRegisterError(
            f"{relative_path.as_posix()} has malformed historical Core-size markers"
        )
    return pattern.sub("", text)


def _live_size_scan_text(relative_path: Path, text: str) -> str:
    scan_text = text
    if relative_path == Path("ops/AUTONOMOUS_RUN.md"):
        for heading in (
            AUTONOMOUS_CURRENT_RUN_HEADING,
            AUTONOMOUS_PACKAGING_HEADING,
            AUTONOMOUS_ACTIVE_END,
        ):
            if scan_text.count(heading) != 1:
                raise checker.RiskRegisterError(
                    "ops/AUTONOMOUS_RUN.md must contain exactly one active-state "
                    f"boundary heading {heading.strip()!r}"
                )
        positions = [
            scan_text.index(AUTONOMOUS_CURRENT_RUN_HEADING),
            scan_text.index(AUTONOMOUS_PACKAGING_HEADING),
            scan_text.index(AUTONOMOUS_ACTIVE_END),
        ]
        if positions != sorted(positions):
            raise checker.RiskRegisterError(
                "ops/AUTONOMOUS_RUN.md active-state boundary headings are misordered"
            )
        scan_text = scan_text.split(AUTONOMOUS_ACTIVE_END, 1)[0]
    return _strip_historical_size_blocks(relative_path, scan_text)


def _validate_status_size_projection(repo_root: Path, text: str) -> str:
    relative_path = STATUS_SIZE_PROJECTION_PATH
    if (
        text.count(STATUS_SIZE_PROJECTION_START) != 1
        or text.count(STATUS_SIZE_PROJECTION_END) != 1
    ):
        raise checker.RiskRegisterError(
            "docs/status.md must contain exactly one marked StreamCore size projection"
        )
    start = text.index(STATUS_SIZE_PROJECTION_START)
    end = text.index(STATUS_SIZE_PROJECTION_END)
    if end <= start:
        raise checker.RiskRegisterError(
            "docs/status.md has misordered StreamCore size projection markers"
        )
    owner = text[start + len(STATUS_SIZE_PROJECTION_START) : end]
    matches = list(STATUS_SIZE_PROJECTION_PATTERN.finditer(owner))
    if len(matches) != 1:
        raise checker.RiskRegisterError(
            "docs/status.md must contain exactly one canonical StreamCore size "
            "pair inside its marked projection"
        )
    live_measurements = list(LIVE_SIZE_MEASUREMENT_PATTERN.finditer(owner))
    if len(live_measurements) != 1:
        raise checker.RiskRegisterError(
            "docs/status.md marked projection must contain exactly one live "
            "StreamCore measurement"
        )
    match = matches[0]
    projected = (
        int(match.group("runtime").replace(",", "")),
        int(match.group("margin").replace(",", "")),
    )
    expected = stream_core_release_measurement(repo_root)
    if projected != expected:
        raise checker.RiskRegisterError(
            "docs/status.md size projection does not match ABI checksums: "
            f"expected {expected[0]:,}/{expected[1]:,}, "
            f"got {projected[0]:,}/{projected[1]:,}"
        )
    outside = text[:start] + text[end + len(STATUS_SIZE_PROJECTION_END) :]
    return _strip_historical_size_blocks(relative_path, outside)


def validate_live_size_mirrors(repo_root: Path) -> None:
    """Keep mutable Core measurements owned by the canonical proof."""
    for relative_path, required_fragments in LIVE_SIZE_MIRROR_REQUIREMENTS.items():
        path = repo_root / relative_path
        try:
            text = path.read_text(encoding="utf-8")
        except FileNotFoundError as exc:
            raise checker.RiskRegisterError(
                f"missing live Core-size mirror: {relative_path.as_posix()}"
            ) from exc
        for fragment in required_fragments:
            if fragment not in text:
                raise checker.RiskRegisterError(
                    f"{relative_path.as_posix()} is missing canonical Core-size "
                    f"proof ownership fragment: {fragment!r}"
                )
        scan_text = (
            _validate_status_size_projection(repo_root, text)
            if relative_path == STATUS_SIZE_PROJECTION_PATH
            else _live_size_scan_text(relative_path, text)
        )
        normalized = re.sub(r"\s*\n\s*", " ", scan_text)
        for pattern in STALE_SIZE_MIRROR_PATTERNS:
            if re.search(f"(?i){pattern}", normalized):
                raise checker.RiskRegisterError(
                    f"{relative_path.as_posix()} repeats stale current Core-size "
                    f"value matching: {pattern!r}"
                )
        for stable_fragment in STABLE_SIZE_POLICY_FRAGMENTS:
            normalized = normalized.replace(stable_fragment, "")
        match = LIVE_SIZE_MEASUREMENT_PATTERN.search(normalized)
        if match:
            raise checker.RiskRegisterError(
                f"{relative_path.as_posix()} owns a mutable live Core-size "
                f"claim outside docs/status.md: {match.group(0)!r}"
            )


def build_register(
    repo_root: Path,
    *,
    require_current_proof: bool = True,
) -> dict[str, Any]:
    """Build the deterministic risk register object."""
    validate_live_size_mirrors(repo_root)
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
        if risk["id"] == SIZE_RISK_ID:
            risk.update(
                stream_core_size_risk_fields(
                    repo_root,
                    require_current_proof=require_current_proof,
                )
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


def write_output(
    repo_root: Path,
    output_path: Path,
    *,
    require_current_proof: bool = False,
) -> Path:
    """Write the generated risk register from the cycle-free pre-tail input."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(
        json_text(
            build_register(
                repo_root,
                require_current_proof=require_current_proof,
            )
        ),
        encoding="utf-8",
        newline="\n",
    )
    return output_path


def check_output(repo_root: Path, output_path: Path) -> int:
    """Check the committed register against generated output and schema."""
    with tempfile.TemporaryDirectory() as temp_dir:
        candidate = Path(temp_dir) / output_path.name
        write_output(repo_root, candidate, require_current_proof=True)
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
