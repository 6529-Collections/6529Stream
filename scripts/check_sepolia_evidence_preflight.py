#!/usr/bin/env python3
"""Check no-secret prerequisites for future Sepolia release evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
from collections.abc import Mapping
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "6529stream.sepolia-evidence-preflight.v1"
DEFAULT_REPO_ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = Path("deployments/config/sepolia-6529stream-v0.1.0-001.template.json")
EXPECTED_CHAIN_ID = 11155111
EXPECTED_NETWORK = "sepolia"
REQUIRED_PATHS = {
    "sepolia_config_template": CONFIG_PATH,
    "deployment_runbook": Path("docs/deployment.md"),
    "non_local_evidence_runbook": Path("docs/non-local-release-evidence.md"),
    "testnet_deployment_retained_template": Path(
        "release-artifacts/evidence/testnet-deployment-rehearsal/"
        "testnet-deployment-rehearsal-retained-artifact-template.md"
    ),
    "public_beta_verified_addresses_template": Path(
        "release-artifacts/evidence/public-beta-verified-addresses/"
        "public-beta-verified-addresses-retained-artifact-template.md"
    ),
    "testnet_deployment_public_beta_template": Path(
        "release-artifacts/evidence/public-beta-templates/"
        "testnet-deployment-rehearsal-template.json"
    ),
    "verified_addresses_public_beta_template": Path(
        "release-artifacts/evidence/public-beta-templates/"
        "verified-deployed-addresses-template.json"
    ),
    "explorer_verification_public_beta_template": Path(
        "release-artifacts/evidence/public-beta-templates/"
        "explorer-verification-status-template.json"
    ),
    "testnet_deployment_checker": Path(
        "scripts/check_testnet_deployment_rehearsal_evidence.py"
    ),
    "public_beta_verified_addresses_checker": Path(
        "scripts/check_public_beta_verified_addresses.py"
    ),
    "non_local_evidence_checker": Path("scripts/check_non_local_release_evidence.py"),
    "public_beta_evidence_checker": Path("scripts/check_public_beta_evidence.py"),
    "sepolia_preflight_checker": Path("scripts/check_sepolia_evidence_preflight.py"),
    "sepolia_preflight_tests": Path("scripts/test_sepolia_evidence_preflight.py"),
}
REQUIRED_COMMANDS = [
    "python scripts/test_sepolia_evidence_preflight.py",
    "python scripts/check_sepolia_evidence_preflight.py",
    "python scripts/test_testnet_deployment_rehearsal_evidence.py",
    "python scripts/check_testnet_deployment_rehearsal_evidence.py",
    "python scripts/test_public_beta_verified_addresses.py",
    "python scripts/check_public_beta_verified_addresses.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]
REQUIRED_ENV_NAMES = [
    "SEPOLIA_RPC_URL",
    "SEPOLIA_CONTRACT_METADATA_URI",
    "SEPOLIA_DEPLOYER_ADDRESS",
    "SEPOLIA_ADMIN_SAFE",
    "SEPOLIA_PAUSE_GUARDIAN",
    "SEPOLIA_EMERGENCY_RECIPIENT",
    "SEPOLIA_DROP_SIGNER",
    "SEPOLIA_PAYOUT",
    "SEPOLIA_DELEGATION_REGISTRY",
    "SEPOLIA_VRF_COORDINATOR",
    "SEPOLIA_ARRNG_CONTROLLER",
    "SEPOLIA_VRF_SUBSCRIPTION_ID",
    "ETHERSCAN_API_KEY",
]


class SepoliaEvidencePreflightError(RuntimeError):
    """Raised when Sepolia evidence prerequisites are invalid."""


def read_text(path: Path) -> str:
    """Read UTF-8 text with checker-specific errors."""
    try:
        return path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise SepoliaEvidencePreflightError(f"missing required file: {path}") from exc
    except UnicodeDecodeError as exc:
        raise SepoliaEvidencePreflightError(f"{path} must be valid UTF-8") from exc


def read_json(path: Path) -> dict[str, Any]:
    """Read a JSON object with checker-specific errors."""
    try:
        value = json.loads(read_text(path))
    except json.JSONDecodeError as exc:
        raise SepoliaEvidencePreflightError(f"{path} must be valid JSON") from exc
    if not isinstance(value, dict):
        raise SepoliaEvidencePreflightError(f"{path} must contain a JSON object")
    return value


def file_sha256(path: Path) -> str:
    """Return a sha256: digest for one file."""
    hasher = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
    except FileNotFoundError as exc:
        raise SepoliaEvidencePreflightError(f"missing required file: {path}") from exc
    return "sha256:" + hasher.hexdigest()


def require_mapping(value: Any, label: str) -> dict[str, Any]:
    """Require one value to be a JSON object."""
    if not isinstance(value, dict):
        raise SepoliaEvidencePreflightError(f"{label} must be an object")
    return value


def require_list(value: Any, label: str) -> list[Any]:
    """Require one value to be a JSON array."""
    if not isinstance(value, list):
        raise SepoliaEvidencePreflightError(f"{label} must be an array")
    return value


def validate_config(config: dict[str, Any], config_path: Path) -> list[dict[str, str]]:
    """Validate the committed Sepolia config template and return env metadata."""
    manifest = require_mapping(config.get("manifest"), "manifest")
    network = require_mapping(manifest.get("network"), "manifest.network")
    if network.get("name") != EXPECTED_NETWORK:
        raise SepoliaEvidencePreflightError(
            f"{config_path} network.name must be {EXPECTED_NETWORK!r}"
        )
    if network.get("chain_id") != EXPECTED_CHAIN_ID:
        raise SepoliaEvidencePreflightError(
            f"{config_path} network.chain_id must be {EXPECTED_CHAIN_ID}"
        )
    if network.get("rpc_environment_variable") != "SEPOLIA_RPC_URL":
        raise SepoliaEvidencePreflightError(
            f"{config_path} must use SEPOLIA_RPC_URL as the RPC env var"
        )
    if config.get("operator_runbook") != (
        "docs/deployment.md#sepolia-deployment-rehearsal-runbook"
    ):
        raise SepoliaEvidencePreflightError(
            f"{config_path} must link the Sepolia deployment runbook"
        )

    operator_inputs = require_mapping(
        config.get("operator_inputs"), "operator_inputs"
    )
    env_rows = require_list(
        operator_inputs.get("required_environment_variables"),
        "operator_inputs.required_environment_variables",
    )
    by_name: dict[str, dict[str, str]] = {}
    for row in env_rows:
        if not isinstance(row, dict):
            raise SepoliaEvidencePreflightError(
                f"{config_path} environment variable rows must be objects"
            )
        name = row.get("name")
        retained_value = row.get("retained_value")
        purpose = row.get("purpose")
        if not all(isinstance(item, str) and item for item in (name, retained_value, purpose)):
            raise SepoliaEvidencePreflightError(
                f"{config_path} environment variable rows need name, retained_value, and purpose"
            )
        by_name[name] = {
            "name": name,
            "retained_value": retained_value,
            "purpose": purpose,
        }

    missing = [name for name in REQUIRED_ENV_NAMES if name not in by_name]
    if missing:
        raise SepoliaEvidencePreflightError(
            f"{config_path} is missing required environment variable(s): "
            + ", ".join(missing)
        )
    return [by_name[name] for name in REQUIRED_ENV_NAMES]


def validate_required_paths(repo_root: Path) -> list[dict[str, str]]:
    """Validate required repo files and return report rows."""
    rows: list[dict[str, str]] = []
    for name, relative_path in REQUIRED_PATHS.items():
        path = repo_root / relative_path
        if not path.is_file():
            raise SepoliaEvidencePreflightError(
                f"missing {name}: {relative_path.as_posix()}"
            )
        rows.append(
            {
                "name": name,
                "path": relative_path.as_posix(),
                "sha256": file_sha256(path),
            }
        )
    return rows


def validate_runbooks(repo_root: Path) -> None:
    """Validate that operator docs carry the expected command breadcrumbs."""
    deployment_doc = read_text(repo_root / "docs/deployment.md")
    non_local_doc = read_text(repo_root / "docs/non-local-release-evidence.md")
    for phrase in [
        "## Sepolia Deployment Rehearsal Runbook",
        "SEPOLIA_RPC_URL",
        "deployments/config/sepolia-6529stream-v0.1.0-001.template.json",
        "--sig \"runSepolia()\"",
        "private keys",
        "API keys",
        "unreleased drop payloads",
    ]:
        if phrase not in deployment_doc:
            raise SepoliaEvidencePreflightError(
                f"docs/deployment.md is missing required Sepolia phrase: {phrase}"
            )
    for command in REQUIRED_COMMANDS:
        if command not in deployment_doc and command not in non_local_doc:
            raise SepoliaEvidencePreflightError(
                f"Sepolia runbooks are missing validation command: {command}"
            )


def env_report(
    required_env: list[dict[str, str]], env: Mapping[str, str]
) -> list[dict[str, Any]]:
    """Return redacted environment-variable presence rows."""
    return [
        {
            "name": row["name"],
            "retained_value": row["retained_value"],
            "present": row["name"] in env and bool(env[row["name"]]),
            "value": "<redacted>" if row["retained_value"] == "redacted" else "<not emitted>",
            "purpose": row["purpose"],
        }
        for row in required_env
    ]


def build_report(
    *,
    repo_root: Path,
    require_env: bool,
    env: Mapping[str, str],
) -> dict[str, Any]:
    """Build a deterministic no-secret preflight report."""
    repo_root = repo_root.resolve()
    checked_files = validate_required_paths(repo_root)
    config_path = repo_root / CONFIG_PATH
    required_env = validate_config(read_json(config_path), config_path)
    validate_runbooks(repo_root)
    environment = env_report(required_env, env)
    missing_env = [row["name"] for row in environment if not row["present"]]
    blockers = []
    if require_env and missing_env:
        blockers.append(
            "missing required operator environment variable(s): "
            + ", ".join(missing_env)
        )

    readiness = "ready" if not missing_env else "operator_env_missing"
    if blockers:
        readiness = "blocked"

    return {
        "schema_version": SCHEMA_VERSION,
        "requirement_ids": [
            "testnet_deployment_rehearsal",
            "verified_deployed_addresses",
            "explorer_verification_status",
        ],
        "linked_issues": ["#217", "#221", "#222"],
        "network": {"name": EXPECTED_NETWORK, "chain_id": EXPECTED_CHAIN_ID},
        "readiness": readiness,
        "checked_files": checked_files,
        "environment": environment,
        "missing_environment_variables": missing_env,
        "blockers": blockers,
        "redaction": {
            "environment_values_emitted": False,
            "private_rpc_urls_emitted": False,
            "private_keys_emitted": False,
            "api_keys_emitted": False,
            "unreleased_drop_payloads_emitted": False,
        },
        "next_steps": [
            "Run with --require-env in the operator shell before a real Sepolia broadcast.",
            "Retain only redacted transcripts, public addresses, public transaction hashes, and sha256 digests.",
            "Keep #217, #221, and #222 open until reviewed retained evidence is linked from public-beta evidence.",
        ],
    }


def validate_preflight(
    repo_root: Path | None = None,
    *,
    require_env: bool = False,
    env: Mapping[str, str] | None = None,
) -> dict[str, Any]:
    """Validate Sepolia evidence prerequisites and return the report."""
    report = build_report(
        repo_root=(repo_root or DEFAULT_REPO_ROOT),
        require_env=require_env,
        env=os.environ if env is None else env,
    )
    if report["blockers"]:
        raise SepoliaEvidencePreflightError("; ".join(report["blockers"]))
    return report


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI arguments."""
    parser = argparse.ArgumentParser(
        description="Check no-secret prerequisites for future Sepolia release evidence"
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=DEFAULT_REPO_ROOT,
        help="Repository root to inspect.",
    )
    parser.add_argument(
        "--require-env",
        action="store_true",
        help="Fail if required operator environment variable names are absent.",
    )
    parser.add_argument(
        "--output-json",
        type=Path,
        help="Optional path for a redacted JSON preflight report.",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the preflight checker."""
    args = parse_args(sys.argv[1:] if argv is None else argv)
    try:
        report = validate_preflight(args.repo_root, require_env=args.require_env)
        if args.output_json is not None:
            args.output_json.parent.mkdir(parents=True, exist_ok=True)
            args.output_json.write_text(
                json.dumps(report, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
                newline="\n",
            )
    except SepoliaEvidencePreflightError as exc:
        print(f"Sepolia evidence preflight failed: {exc}", file=sys.stderr)
        return 1
    print(
        "Sepolia evidence preflight passed "
        f"({report['readiness']}; values redacted)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
