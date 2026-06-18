#!/usr/bin/env python3
"""Validate retained public-beta verified-address evidence artifacts."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BASE_CHECKER_PATH = SCRIPT_DIR / "check_production_verified_addresses.py"
BASE_CHECKER_SPEC = importlib.util.spec_from_file_location(
    "check_production_verified_addresses", BASE_CHECKER_PATH
)
assert BASE_CHECKER_SPEC is not None
assert BASE_CHECKER_SPEC.loader is not None
checker = importlib.util.module_from_spec(BASE_CHECKER_SPEC)
BASE_CHECKER_SPEC.loader.exec_module(checker)

checker.REQUIREMENT_ID = "public_beta_verified_addresses"
checker.EVIDENCE_KIND = "public beta verified-addresses"
checker.EXPECTED_ENVIRONMENT = "testnet"
checker.EXPECTED_CHAIN_ID = "11155111"
checker.EXPECTED_CHAIN_ID_INT = 11155111
checker.CLI_DESCRIPTION = "Validate retained public-beta verified-address evidence artifacts"
checker.CLI_FAILURE_PREFIX = "public beta verified-addresses check failed"
checker.CLI_SUCCESS_MESSAGE = "public beta verified-addresses evidence is valid"
checker.DEFAULT_EVIDENCE_RELATIVE = Path(
    "release-artifacts/evidence/public-beta-verified-addresses/"
    "public-beta-verified-addresses-retained-artifact-template.md"
)
checker.DEFAULT_EVIDENCE = [checker.DEFAULT_REPO_ROOT / checker.DEFAULT_EVIDENCE_RELATIVE]
checker.REQUIRED_HEADINGS = [
    "# Public Beta Verified Addresses Retained Artifact",
    "## Evidence Status",
    "## Source And Public Beta Reference",
    "## Required Retained Artifacts",
    "## Verified Address Results",
    "## Review",
    "## Redaction",
    "## Validation Commands",
    "## Operator Notes",
]
checker.REQUIRED_FIELDS = {
    "Requirement ID",
    "Review status",
    "Readiness claim",
    "Environment",
    "Chain ID",
    "Repository",
    "Git commit",
    "CI run or operator transcript",
    "Public beta block or reference",
    "Network and deployment version",
    "Generated public-beta address book",
    "Generated public-beta deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
    "Release manifest/checksum digests",
    "Address book covers public-beta deployment",
    "Explorer source verification confirmed",
    "Runtime bytecode matches release proof",
    "Constructor arguments verified",
    "Linked libraries verified",
    "Common explorer/indexer links retained",
    "Operator",
    "Reviewer",
    "Review decision",
    "No secrets retained",
    "Private RPC URLs removed",
    "Private keys removed",
    "API keys removed",
    "Unreleased drop payloads removed",
}
checker.FINAL_VALUE_FIELDS = [
    "Git commit",
    "CI run or operator transcript",
    "Public beta block or reference",
    "Network and deployment version",
    "Generated public-beta address book",
    "Generated public-beta deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
    "Release manifest/checksum digests",
    "Operator",
    "Reviewer",
]
checker.REVIEWED_YES_FIELDS = [
    "Address book covers public-beta deployment",
    "Explorer source verification confirmed",
    "Runtime bytecode matches release proof",
    "Constructor arguments verified",
    "Linked libraries verified",
    "Common explorer/indexer links retained",
]
checker.RETAINED_FILE_FIELDS = [
    "Generated public-beta address book",
    "Generated public-beta deployment manifest",
    "Source verification inputs",
    "Explorer verification evidence",
    "Bytecode release proof",
    "Release manifest/checksum digests",
]
checker.ADDRESS_BOOK_FIELD = "Generated public-beta address book"
checker.DEPLOYMENT_MANIFEST_FIELD = "Generated public-beta deployment manifest"
checker.EXPLORER_EVIDENCE_FIELD = "Explorer verification evidence"
checker.BYTECODE_PROOF_FIELD = "Bytecode release proof"
checker.REQUIRED_COMMANDS = [
    "python scripts/test_public_beta_verified_addresses.py",
    "python scripts/check_public_beta_verified_addresses.py",
    "python scripts/generate_non_local_release_evidence.py",
    "python scripts/check_non_local_release_evidence.py",
    "python scripts/check_public_beta_evidence.py",
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
]

DEFAULT_REPO_ROOT = checker.DEFAULT_REPO_ROOT
DEFAULT_EVIDENCE_RELATIVE = checker.DEFAULT_EVIDENCE_RELATIVE
DEFAULT_EVIDENCE = checker.DEFAULT_EVIDENCE
PublicBetaVerifiedAddressesError = checker.ProductionVerifiedAddressesError
file_sha256 = checker.file_sha256
main = checker.main
validate_artifact = checker.validate_artifact


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
