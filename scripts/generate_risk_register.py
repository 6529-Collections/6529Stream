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


GENERATOR_VERSION = "1"
DEFAULT_OUTPUT = checker.DEFAULT_REGISTER

SOURCE_DOCUMENT_PATHS = [
    "release-artifacts/schema/risk-register.schema.json",
    "ops/ROADMAP.md",
    "ops/EXECUTION_BACKLOG.md",
    "docs/audit-package.md",
    "docs/release-readiness.md",
    "docs/known-blockers.md",
    "ops/SLITHER_BASELINE.md",
    "release-artifacts/latest/public-beta-evidence.json",
    "release-artifacts/latest/public-beta-blockers.md",
    "release-artifacts/latest/production-release-blockers.md",
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
        "tracking": [
            "https://github.com/6529-Collections/6529Stream/issues/217",
            "https://github.com/6529-Collections/6529Stream/issues/218",
        ],
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
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/362"],
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
            "docs/release-readiness.md",
            "release-artifacts/latest/public-beta-blockers.md",
        ],
        "checks": [
            "python scripts/test_metadata_fixtures.py",
            "python scripts/check_metadata_fixtures.py",
            "python scripts/test_metadata_browser_sandbox.py",
            "python scripts/check_metadata_browser_sandbox.py",
        ],
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/135"],
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
        ],
        "checks": [
            "python scripts/test_risk_register.py",
            "python scripts/check_risk_register.py",
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
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/221"],
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
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/384"],
    },
    {
        "id": "RISK-SIZE-001",
        "title": "StreamCore bytecode headroom remains tight",
        "area": "core_size",
        "severity": "medium",
        "status": "accepted_local_baseline",
        "owner": "protocol",
        "target_gate": "Gate G",
        "source": "clean-main reviewer rebaseline and status docs",
        "mitigation": (
            "Keep non-critical product surfaces in satellite contracts, adapters, "
            "libraries, release artifacts, or docs unless a measured size-budget exception is accepted."
        ),
        "residual_risk": (
            "Large future Core feature work could consume the remaining EIP-170 "
            "headroom and block deployment."
        ),
        "evidence_paths": [
            "docs/known-blockers.md",
            "ops/ROADMAP.md",
            "docs/status.md",
        ],
        "checks": [
            "forge build --sizes --via-ir --skip test --skip script --force",
            "python scripts/generate_release_manifest.py --check",
        ],
        "tracking": ["https://github.com/6529-Collections/6529Stream/issues/115"],
    },
    {
        "id": "RISK-SLITHER-001",
        "title": "Static-analysis baseline contains accepted local findings",
        "area": "static_analysis",
        "severity": "medium",
        "status": "accepted_local_baseline",
        "owner": "security",
        "target_gate": "Gate F",
        "source": "Slither baseline and vendored-library provenance docs",
        "mitigation": (
            "Keep high/medium production findings fixed or explicitly accepted, "
            "retain test-only and vendored-library dispositions, and require future deltas to update the baseline."
        ),
        "residual_risk": (
            "Accepted local findings are audit inputs and should be independently reviewed before launch."
        ),
        "evidence_paths": [
            "ops/SLITHER_BASELINE.md",
            "docs/slither.md",
            "docs/vendored-libraries.md",
        ],
        "checks": [
            "slither . --config-file slither.config.json --foundry-compile-all",
            "python scripts/check_audit_package.py",
        ],
        "tracking": ["ops/SLITHER_BASELINE.md"],
    },
    {
        "id": "RISK-WARN-001",
        "title": "Compiler, NatSpec, lint, and warning noise still need release disposition",
        "area": "warning_hygiene",
        "severity": "medium",
        "status": "planned_mitigation",
        "owner": "oss",
        "target_gate": "Gate G",
        "source": "clean-main reviewer rebaseline",
        "mitigation": (
            "Capture warning categories, fix low-risk first-party warning noise, "
            "document accepted warning dispositions, and decide whether new warning categories fail CI."
        ),
        "residual_risk": (
            "Warning noise can hide meaningful future regressions and weakens open-source reviewer confidence."
        ),
        "evidence_paths": [
            "ops/ROADMAP.md",
            "ops/EXECUTION_BACKLOG.md",
            "docs/tooling.md",
        ],
        "checks": [
            "forge build",
            "python scripts/check_audit_package.py",
            "python scripts/check_release_readiness.py",
        ],
        "tracking": ["ops/EXECUTION_BACKLOG.md"],
    },
]


def file_ref(repo_root: Path, relative_path: str) -> dict[str, str]:
    """Build a hashed file reference."""
    resolved = checker.resolve_repo_file(repo_root, relative_path, relative_path)
    return {"path": relative_path, "sha256": checker.file_sha256(resolved)}


def build_register(repo_root: Path) -> dict[str, Any]:
    """Build the deterministic risk register object."""
    risks = []
    for definition in sorted(RISK_DEFINITIONS, key=lambda item: str(item["id"])):
        risk = {key: value for key, value in definition.items() if key != "evidence_paths"}
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
