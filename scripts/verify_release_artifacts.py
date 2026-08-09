#!/usr/bin/env python3
"""Verify committed release artifacts without regenerating them.

This is the consumer-facing offline verifier for a checked-out release bundle.
It validates the signable checksum file, checksum manifest, top-level release
manifest, and bytecode release proof agree with the files on disk.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import os
import re
import stat
import sys
import tempfile
from pathlib import Path
from typing import Any, Iterable, NamedTuple, Sequence


SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA256_PREFIX_RE = re.compile(r"^sha256:[0-9a-f]{64}$")
CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
CANONICAL_COVERAGE_POLICY = "canonical"
RELEASE_MANIFEST_SCHEMA = "6529stream.release-manifest.v1"
BYTECODE_PROOF_SCHEMA = "6529stream.bytecode-release-proof.v1"
RELEASE_CANDIDATE_LOCKFILE_SCHEMA = "6529stream.release-candidate-lockfile.v1"
GOVERNED_PARAMETER_INVENTORY_SCHEMA = (
    "6529stream.governed-parameter-inventory.v1"
)
RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA = (
    "6529stream.record-family-authorization-inventory.v1"
)
RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA = (
    "6529stream.record-family-authorization-source-catalog.v1"
)
RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_ID = (
    "https://6529.io/schemas/"
    "record-family-authorization-source-catalog.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_ID = (
    "https://6529.io/schemas/"
    "record-family-authorization-inventory.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA = (
    "6529stream.record-family-authorization-evidence.v1"
)
RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_ID = (
    "https://raw.githubusercontent.com/6529-Collections/6529Stream/main/"
    "deployments/schema/record-family-authorization-evidence.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA = (
    "6529stream.record-family-authorization-grant-map.v1"
)
RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_ID = (
    "https://raw.githubusercontent.com/6529-Collections/6529Stream/main/"
    "deployments/schema/record-family-authorization-grant-map.v1.schema.json"
)
JSON_SCHEMA_DRAFT = "https://json-schema.org/draft/2020-12/schema"

DEFAULT_RELEASE_DIR = Path("release-artifacts/latest")
GOVERNED_PARAMETER_INVENTORY_PATH = (
    "release-artifacts/governed-parameter-inventory.json"
)
GOVERNED_PARAMETER_INVENTORY_SCHEMA_PATH = (
    "release-artifacts/schema/governed-parameter-inventory.v1.schema.json"
)
GENESIS_DEPLOYMENT_PROFILE_PATH = (
    "release-artifacts/genesis-deployment-profile.json"
)
RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH = (
    "release-artifacts/record-family-authorization-inventory.json"
)
RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH = (
    "release-artifacts/record-family-authorization-source-catalog.json"
)
RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_PATH = (
    "release-artifacts/schema/"
    "record-family-authorization-source-catalog.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH = (
    "release-artifacts/schema/"
    "record-family-authorization-inventory.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH = (
    "deployments/schema/"
    "record-family-authorization-evidence.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH = (
    "deployments/record-family-authorization/"
    "record-family-authorization-evidence-template.json"
)
RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH = (
    "deployments/schema/"
    "record-family-authorization-grant-map.v1.schema.json"
)
RECORD_FAMILY_AUTHORIZATION_SEMANTIC_SOURCE_PATHS = (
    "smart-contracts/interfaces/stream/IStreamRecordFamilyAuthorityProvider.sol",
    "smart-contracts/interfaces/stream/IStreamRecordFamilyRegistry.sol",
    "smart-contracts/domains/records/StreamRecordFamilyRegistry.sol",
    "smart-contracts/domains/metadata/StreamCollectionMetadata.sol",
    "smart-contracts/interfaces/stream/IStreamCollectionMetadata.sol",
    "smart-contracts/domains/preservation/StreamPreservationRecords.sol",
    "smart-contracts/interfaces/stream/IStreamPreservationRecords.sol",
    "script/RehearseDeployment.s.sol",
    "test/StreamRecordFamilyAuthorization.t.sol",
    "test/StreamCollectionMetadata.t.sol",
    "test/StreamPreservationRecords.t.sol",
    "test/StreamDeploymentManifest.t.sol",
)
ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA = (
    "6529stream.artist-semantic-owner-matrix.v2"
)
ARTIST_SEMANTIC_OWNER_MATRIX_STATUS = "PROPOSED_ARCHITECTURE_ONLY"
ARTIST_SEMANTIC_OWNER_MATRIX_MATURITY = "pre_audit_implementation_blocked"
ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA_ID = (
    "https://6529.io/schemas/artist-semantic-owner-matrix-v2.schema.json"
)
ARTIST_SEMANTIC_OWNER_MATRIX_PATH = (
    "docs/architecture/artist-semantic-owner-matrix-v2.json"
)
ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA_PATH = (
    "docs/architecture/artist-semantic-owner-matrix-v2.schema.json"
)
RELEASE_TOOL_CALL_POLICY_PATH = (
    "release-artifacts/release-tool-call-policy.json"
)
RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH = (
    "release-artifacts/schema/release-tool-call-policy.v1.schema.json"
)
RELEASE_TOOL_CALL_POLICY_SCHEMA = "6529stream.release-tool-call-policy.v1"
RELEASE_TOOL_CALL_POLICY_SCHEMA_ID = (
    "https://6529.io/schemas/release-tool-call-policy.v1.schema.json"
)
RELEASE_TOOL_CALL_POLICY_PATH_PATTERN = (
    r"^scripts/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.py$"
)
CHECKSUM_FILE_NAME = "SHA256SUMS"
CHECKSUM_MANIFEST_NAME = "release-checksums.json"
RELEASE_MANIFEST_NAME = "release-manifest.json"
BYTECODE_PROOF_NAME = "bytecode-release-proof.json"
RELEASE_CANDIDATE_LOCKFILE_NAME = "release-candidate-lockfile.json"
SELF_REFERENTIAL_SHA256_MARKERS = {"not_available_self_referential"}
ALLOWED_UNCHECKSUMMED_RELEASE_FILES = {
    CHECKSUM_FILE_NAME,
    CHECKSUM_MANIFEST_NAME,
}
REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE = (
    Path("scripts/check_admin_ceremony_evidence.py"),
    Path("scripts/check_artist_semantic_owner_matrix.py"),
    Path("scripts/check_changelog.py"),
    Path("scripts/check_drop_authorization_signing_evidence.py"),
    Path("scripts/check_governance_action_policy.py"),
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
    Path("scripts/no_secret_scanner.py"),
    Path("scripts/release_evidence_paths.py"),
    Path("scripts/verify_release_artifacts.py"),
)
REVIEWED_RELEASE_TOOL_ROOTS = (
    Path("scripts/generate_risk_register.py"),
    Path("scripts/generate_release_notes.py"),
    Path("scripts/generate_release_manifest.py"),
    Path("scripts/generate_bytecode_release_proof.py"),
    Path("scripts/generate_release_candidate_lockfile.py"),
    Path("scripts/generate_release_checksums.py"),
    Path("scripts/verify_release_artifacts.py"),
)
REVIEWED_RELEASE_TOOL_ROOTS_SHA256 = (
    "806543a0cef88603d2833f9cc6446fd52a9dc5742f9c8bf8b792724f8a6127b6"
)
REVIEWED_RELEASE_TOOL_FOCUSED_TESTS = (
    Path("scripts/test_changelog_check.py"),
    Path("scripts/test_release_notes.py"),
    Path("scripts/test_admin_ceremony_evidence.py"),
    Path("scripts/test_drop_authorization_signing_evidence.py"),
    Path("scripts/test_non_local_release_evidence.py"),
    Path("scripts/test_artist_semantic_owner_matrix.py"),
    Path("scripts/test_record_family_authorization.py"),
    Path("scripts/test_release_signatures.py"),
    Path("scripts/test_signer_custody_readiness.py"),
    Path("scripts/test_bytecode_release_proof.py"),
)
SNAPSHOT_CHECKER_MODULE_PATHS = {
    "check_artist_semantic_owner_matrix": Path(
        "scripts/check_artist_semantic_owner_matrix.py"
    ),
    "check_governed_parameter_inventory": Path(
        "scripts/check_governed_parameter_inventory.py"
    ),
    "check_record_family_authorization": Path(
        "scripts/check_record_family_authorization.py"
    ),
}
SNAPSHOT_CHECKER_DEPENDENCY_PATHS = {
    "check_artist_semantic_owner_matrix": {},
    "check_governed_parameter_inventory": {
        "check_governed_parameter_identifiers": Path(
            "scripts/check_governed_parameter_identifiers.py"
        ),
    },
    "check_record_family_authorization": {},
}
RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES = frozenset(
    {
        "Crypto.Hash",
        "__future__",
        "argparse",
        "ast",
        "collections",
        "contextlib",
        "copy",
        "datetime",
        "eth_hash.auto",
        "filecmp",
        "hashlib",
        "importlib",
        "importlib.util",
        "io",
        "json",
        "jsonschema",
        "jsonschema.exceptions",
        "math",
        "os",
        "pathlib",
        "re",
        "shlex",
        "shutil",
        "stat",
        "subprocess",
        "sys",
        "tempfile",
        "types",
        "typing",
        "unicodedata",
        "unittest",
    }
)
REVIEWED_RELEASE_TOOL_EXTERNAL_MODULES_SHA256 = (
    "e8e4ef81278dcbfb1e00abaa1634f539810b93002d15c814e5ad4801089362ae"
)
RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST = frozenset(
    tuple(line.split("|"))
    for line in """
scripts/check_admin_ceremony_evidence.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_artist_semantic_owner_matrix.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_artist_semantic_owner_matrix.py|sys.stderr|local:print|keyword:file
scripts/check_admin_ceremony_evidence.py|re.IGNORECASE|re.compile|arg:1
scripts/check_admin_ceremony_evidence.py|sys.argv|local:parse_args|arg:0
scripts/check_admin_ceremony_evidence.py|sys.stderr|local:print|keyword:file
scripts/check_changelog.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_changelog.py|re.IGNORECASE|re.compile|arg:1
scripts/check_changelog.py|subprocess.PIPE|subprocess.run|keyword:stderr
scripts/check_changelog.py|subprocess.PIPE|subprocess.run|keyword:stdout
scripts/check_changelog.py|sys.stderr|local:print|keyword:file
scripts/check_drop_authorization_signing_evidence.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_drop_authorization_signing_evidence.py|sys.argv|local:parse_args|arg:0
scripts/check_drop_authorization_signing_evidence.py|sys.stderr|local:print|keyword:file
scripts/check_governance_action_policy.py|sys.stderr|local:print|keyword:file
scripts/check_governed_parameter_identifiers.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_governed_parameter_identifiers.py|re.IGNORECASE|re.match|keyword:flags
scripts/check_governed_parameter_identifiers.py|re.IGNORECASE|re.compile|keyword:flags
scripts/check_governed_parameter_inventory.py|check_governed_parameter_identifiers.GGP_NAMES|local:tuple|arg:0
scripts/check_governed_parameter_inventory.py|check_governed_parameter_identifiers.GTP_NAMES|local:tuple|arg:0
scripts/check_governed_parameter_inventory.py|jsonschema.Draft202012Validator|<none>|Compare.left
scripts/check_governed_parameter_inventory.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_governed_parameter_inventory.py|re.MULTILINE|re.search|arg:2
scripts/check_governed_parameter_inventory.py|stat|local:getattr|arg:0
scripts/check_non_local_release_evidence.py|check_public_beta_evidence.PRODUCTION_REQUIREMENTS|local:frozenset|arg:0
scripts/check_non_local_release_evidence.py|check_public_beta_evidence.PRODUCTION_REQUIREMENTS|local:set|arg:0
scripts/check_non_local_release_evidence.py|check_public_beta_evidence.PUBLIC_BETA_REQUIREMENTS|local:frozenset|arg:0
scripts/check_non_local_release_evidence.py|check_public_beta_evidence.PUBLIC_BETA_REQUIREMENTS|local:set|arg:0
scripts/check_non_local_release_evidence.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_non_local_release_evidence.py|re.MULTILINE|re.compile|arg:1
scripts/check_non_local_release_evidence.py|sys.argv|local:parse_args|arg:0
scripts/check_non_local_release_evidence.py|sys.stderr|local:print|keyword:file
scripts/check_public_beta_evidence.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_public_beta_evidence.py|sys.argv|local:parse_args|arg:0
scripts/check_public_beta_evidence.py|sys.stderr|local:print|keyword:file
scripts/check_record_family_authorization.py|jsonschema.Draft202012Validator|<none>|Compare.left
scripts/check_record_family_authorization.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_record_family_authorization.py|stat|local:getattr|arg:0
scripts/check_record_family_authorization.py|subprocess.PIPE|subprocess.run|keyword:stderr
scripts/check_record_family_authorization.py|subprocess.PIPE|subprocess.run|keyword:stdout
scripts/check_record_family_authorization.py|sys.stderr|local:print|keyword:file
scripts/check_release_evidence_issue_links.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_release_evidence_issue_links.py|sys.stderr|local:print|keyword:file
scripts/check_release_signatures.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_release_signatures.py|re.IGNORECASE|re.compile|arg:1
scripts/check_release_signatures.py|sys.stderr|local:print|keyword:file
scripts/check_risk_register.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_risk_register.py|re.IGNORECASE|re.compile|arg:1
scripts/check_risk_register.py|sys.argv|local:main|arg:0
scripts/check_risk_register.py|sys.stderr|local:print|keyword:file
scripts/check_signer_custody_readiness.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_signer_custody_readiness.py|sys.argv|local:parse_args|arg:0
scripts/check_signer_custody_readiness.py|sys.stderr|local:print|keyword:file
scripts/check_slither_baseline.py|pathlib.Path|local:mode.add_argument|keyword:type
scripts/check_slither_baseline.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/check_slither_baseline.py|sys.argv|local:parse_args|arg:0
scripts/check_slither_baseline.py|sys.executable|<none>|List.elts
scripts/check_slither_baseline.py|sys.stderr|local:print|keyword:file
scripts/generate_bytecode_release_proof.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_bytecode_release_proof.py|sys.argv|local:parse_args|arg:0
scripts/generate_bytecode_release_proof.py|sys.stderr|local:print|keyword:file
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_EVIDENCE_SCHEMA|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_EVIDENCE_TEMPLATE|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_GRANT_MAP_SCHEMA|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_INVENTORY|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_INVENTORY_SCHEMA|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG_SCHEMA|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.EVIDENCE_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.EVIDENCE_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.GRANT_MAP_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.GRANT_MAP_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.INVENTORY_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.INVENTORY_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.JSON_SCHEMA_DRAFT|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.SOURCE_CATALOG_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_record_family_authorization.SOURCE_CATALOG_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|check_release_signatures.EVIDENCE_SCHEMA|local:require_schema|arg:1
scripts/generate_release_candidate_lockfile.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_PATH|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH|<none>|Assign.value
scripts/generate_release_candidate_lockfile.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_release_candidate_lockfile.py|sys.argv|local:parse_args|arg:0
scripts/generate_release_candidate_lockfile.py|sys.path|<none>|Compare.comparators
scripts/generate_release_candidate_lockfile.py|sys.stderr|local:print|keyword:file
scripts/generate_release_checksums.py|ast.AST|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Assign|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.AsyncFunctionDef|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Attribute|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Call|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.ClassDef|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Constant|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Del|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.ExceptHandler|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.FunctionDef|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Global|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Import|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.ImportFrom|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.List|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Load|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.MatchAs|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.MatchMapping|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.MatchStar|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Name|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Nonlocal|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Starred|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Store|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.Tuple|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.arg|local:isinstance|arg:1
scripts/generate_release_checksums.py|ast.stmt|local:isinstance|arg:1
scripts/generate_release_checksums.py|check_governed_parameter_inventory.DEFAULT_INVENTORY|<none>|Assign.value
scripts/generate_release_checksums.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_release_checksums.py|stat|local:getattr|arg:0
scripts/generate_release_checksums.py|sys.argv|local:main|arg:0
scripts/generate_release_checksums.py|sys.stderr|local:print|keyword:file
scripts/generate_release_manifest.py|check_non_local_release_evidence.EVIDENCE_SCHEMA|<none>|Compare.comparators
scripts/generate_release_manifest.py|check_public_beta_evidence.BLOCKING_STATUSES|local:sum|arg:0
scripts/generate_release_manifest.py|check_public_beta_evidence.PRODUCTION_PHASE|<none>|Dict.keys
scripts/generate_release_manifest.py|check_public_beta_evidence.PUBLIC_BETA_PHASE|<none>|Dict.keys
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_EVIDENCE_SCHEMA|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_EVIDENCE_TEMPLATE|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_GRANT_MAP_SCHEMA|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_INVENTORY|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_INVENTORY_SCHEMA|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG_SCHEMA|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.EVIDENCE_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.EVIDENCE_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.GRANT_MAP_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.GRANT_MAP_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.INVENTORY_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.INVENTORY_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.JSON_SCHEMA_DRAFT|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.SOURCE_CATALOG_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_manifest.py|check_record_family_authorization.SOURCE_CATALOG_SCHEMA_VERSION|<none>|Assign.value
scripts/generate_release_manifest.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_PATH|<none>|Assign.value
scripts/generate_release_manifest.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA|<none>|Assign.value
scripts/generate_release_manifest.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA_ID|<none>|Assign.value
scripts/generate_release_manifest.py|generate_release_checksums.RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH|<none>|Assign.value
scripts/generate_release_manifest.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_release_manifest.py|sys.argv|local:main|arg:0
scripts/generate_release_manifest.py|sys.stderr|local:print|keyword:file
scripts/generate_release_notes.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_release_notes.py|re.IGNORECASE|re.compile|arg:1
scripts/generate_release_notes.py|sys.argv|local:parse_args|arg:0
scripts/generate_release_notes.py|sys.stderr|local:print|keyword:file
scripts/generate_risk_register.py|check_risk_register.DEFAULT_REGISTER|<none>|Assign.value
scripts/generate_risk_register.py|check_risk_register.RISK_REGISTER_SCHEMA|<none>|Dict.values
scripts/generate_risk_register.py|check_slither_baseline.DEFAULT_BASELINE|check_slither_baseline.validate_baseline|arg:1
scripts/generate_risk_register.py|check_slither_baseline.DEFAULT_MARKDOWN|check_slither_baseline.validate_baseline|arg:2
scripts/generate_risk_register.py|check_slither_baseline.IMPACTS|<none>|comprehension.iter
scripts/generate_risk_register.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/generate_risk_register.py|sys.argv|local:main|arg:0
scripts/generate_risk_register.py|sys.stderr|local:print|keyword:file
scripts/no_secret_scanner.py|re.IGNORECASE|re.compile|arg:1
scripts/test_record_family_authorization.py|check_record_family_authorization.ADMIN_REJECTION_FAMILY_GROUPS|<none>|Compare.comparators
scripts/test_record_family_authorization.py|check_record_family_authorization.ADMIN_REJECTION_FAMILY_GROUP_BLOCKERS|local:expected.extend|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.AUTHORIZATION_CLASS_HOME|expression:Subscript:eb818dd54cbe2594957bcb6fa36c5f79070833f16f47ca2c5c2b5f090179ea58.__setitem__|arg:1
scripts/test_record_family_authorization.py|check_record_family_authorization.COMMON_FAMILY_GROUP_BLOCKERS|local:list|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.COMPLETION_BLOCKER|local:self.assertEqual|arg:1
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_EVIDENCE_SCHEMA|<none>|BinOp.right
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_EVIDENCE_SCHEMA|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_EVIDENCE_TEMPLATE|<none>|BinOp.right
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_EVIDENCE_TEMPLATE|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_EVIDENCE_TEMPLATE|local:_read|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_GRANT_MAP_SCHEMA|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_INVENTORY|<none>|BinOp.right
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_INVENTORY|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_INVENTORY|local:_read|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_INVENTORY_SCHEMA|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG|local:_read|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.DEFAULT_SOURCE_CATALOG_SCHEMA|<none>|Set.elts
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_AUTHORIZATION_CLASSES|local:enumerate|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_FAMILY_GROUPS|<none>|comprehension.iter
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_FAMILY_GROUPS|local:enumerate|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_FAMILY_GROUPS|local:self.subTest|keyword:family
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_GRANT_MAP_PATHS|<none>|Subscript.value
scripts/test_record_family_authorization.py|check_record_family_authorization.EXPECTED_NORMATIVE_SOURCES|<none>|Subscript.value
scripts/test_record_family_authorization.py|check_record_family_authorization.FAMILY_GROUP_HOME|expression:Subscript:fdde61149fa73b405d912aa28abaf073c7ee2ccc25e8233c4f02b5b85115352d.__setitem__|arg:1
scripts/test_record_family_authorization.py|check_record_family_authorization.GRANT_MAP_SCHEMA_VERSION|<none>|Dict.values
scripts/test_record_family_authorization.py|check_record_family_authorization.GRANT_MAP_SCHEMA_VERSION|local:evidence.update|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.IMPLEMENTATION_COMPLETION_SUPPORTED|<none>|Assign.targets
scripts/test_record_family_authorization.py|check_record_family_authorization.IMPLEMENTATION_COMPLETION_SUPPORTED|<none>|Assign.value
scripts/test_record_family_authorization.py|check_record_family_authorization.INVENTORY_SCHEMA_VERSION|local:evidence.update|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.NORMATIVE_FRAGMENT_BINDINGS|<none>|For.iter
scripts/test_record_family_authorization.py|check_record_family_authorization.RecordFamilyAuthorizationError|local:self.assertRaisesRegex|arg:0
scripts/test_record_family_authorization.py|check_record_family_authorization.SNAPSHOT_FAMILY_GROUP_EXTRA_BLOCKERS|local:expected.extend|arg:0
scripts/test_record_family_authorization.py|os.environ|<none>|Subscript.value
scripts/test_record_family_authorization.py|os.name|<none>|Compare.left
scripts/test_record_family_authorization.py|subprocess.DEVNULL|subprocess.run|keyword:stderr
scripts/test_record_family_authorization.py|subprocess.DEVNULL|subprocess.run|keyword:stdout
scripts/test_record_family_authorization.py|subprocess.PIPE|subprocess.run|keyword:stderr
scripts/test_record_family_authorization.py|subprocess.PIPE|subprocess.run|keyword:stdout
scripts/verify_release_artifacts.py|ast.AST|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Assign|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.AsyncFunctionDef|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Attribute|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Call|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.ClassDef|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Constant|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Del|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.ExceptHandler|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.FunctionDef|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Global|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Import|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.ImportFrom|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Load|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.MatchAs|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.MatchMapping|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.MatchStar|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Name|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Nonlocal|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Starred|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.Store|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.arg|local:isinstance|arg:1
scripts/verify_release_artifacts.py|ast.stmt|local:isinstance|arg:1
scripts/verify_release_artifacts.py|pathlib.Path|local:parser.add_argument|keyword:type
scripts/verify_release_artifacts.py|stat.FILE_ATTRIBUTE_REPARSE_POINT|local:bool|arg:0
scripts/verify_release_artifacts.py|sys.argv|local:parse_args|arg:0
scripts/verify_release_artifacts.py|sys.modules|<none>|Compare.comparators
scripts/verify_release_artifacts.py|sys.modules|<none>|Subscript.value
scripts/verify_release_artifacts.py|sys.modules|local:set|arg:0
scripts/verify_release_artifacts.py|sys.path|<none>|Subscript.value
scripts/verify_release_artifacts.py|sys.path|local:list|arg:0
scripts/verify_release_artifacts.py|sys.stderr|local:print|keyword:file
""".strip().splitlines()
    if line
)
RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST = frozenset(
    tuple(line.split("|"))
    for line in """
scripts/check_governed_parameter_inventory.py|Draft202012Validator|jsonschema.Draft202012Validator|Constant(value=None)
scripts/check_governed_parameter_inventory.py|SchemaError|jsonschema.exceptions.SchemaError|Name(id='Exception', ctx=Load())
scripts/check_record_family_authorization.py|Draft202012Validator|jsonschema.Draft202012Validator|Constant(value=None)
scripts/check_record_family_authorization.py|FormatChecker|jsonschema.FormatChecker|Constant(value=None)
scripts/check_record_family_authorization.py|SchemaError|jsonschema.exceptions.SchemaError|Name(id='Exception', ctx=Load())
""".strip().splitlines()
    if line
)
REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES = {
    Path("scripts/check_changelog.py"): (
        "3a1e93aa1b524b54ff492b432dc143afd5ecb1c6b8c4ec42c377d62d70733065",
        8_999,
    ),
    Path("scripts/check_record_family_authorization.py"): (
        "179ef782124caadff4a36dbea3bb163e44e5d105f45685d4828c82010e79a60f",
        128_549,
    ),
    Path("scripts/check_slither_baseline.py"): (
        "7c3e7823fc7a58262881d7df59bdafd995895b87e9dea08a625d7538608f0b13",
        47_072,
    ),
}
GIT_ATTRIBUTES_PATH = ".gitattributes"
GIT_BINARY_SNIFF_BYTES = 8_000
CANONICAL_COVERED_PATH_COUNT = 282
CANONICAL_COVERED_PATHS_SHA256 = (
    "9cf2a2d08c6ce7b69ed33f4076be231566e304b132b0865e4902d893f8693e0a"
)
RISK_SIZE_CHECKER_PATH = Path("scripts/check_contract_size_budget.py")


class ReleaseArtifactVerificationError(RuntimeError):
    pass


class VerificationSummary(NamedTuple):
    checksum_entries: int
    checksum_manifest_records: int
    release_manifest_records: int
    bytecode_proof_records: int
    release_candidate_lockfile_records: int


class CanonicalCoveredFile(NamedTuple):
    data: bytes
    sha256: str
    size_bytes: int
    line_ending: str


class ChecksumBundleSnapshot(NamedTuple):
    checksum_file_path: str
    checksum_file_data: bytes
    checksum_file_sha256: str
    checksum_file_identity: tuple[int, int]
    checksum_entries: tuple[tuple[str, str], ...]
    checksum_manifest_path: str
    checksum_manifest_data: bytes
    checksum_manifest_identity: tuple[int, int]
    checksum_manifest: dict[str, Any]


def _is_reparse_point(path: Path) -> bool:
    try:
        attributes = path.lstat().st_file_attributes
    except (AttributeError, FileNotFoundError, OSError):
        return False
    return bool(attributes & stat.FILE_ATTRIBUTE_REPARSE_POINT)


def require_canonical_repo_root(repo_root: Path) -> Path:
    lexical = Path(os.path.abspath(repo_root))
    current = Path(lexical.anchor)
    for part in lexical.parts[1:]:
        current = current / part
        if current.is_symlink() or _is_reparse_point(current):
            raise ReleaseArtifactVerificationError(
                "repository root must not include symlinks or reparse points: "
                f"{current}"
            )
    if not lexical.is_dir():
        raise ReleaseArtifactVerificationError(
            f"repository root must be a directory: {lexical}"
        )
    return lexical.resolve()


def normalize_path(path: Path, repo_root: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        return path.as_posix()


def require_no_symlink_components(
    repo_root: Path,
    relative_path: Path,
    field: str,
) -> None:
    # Callers first reject absolute, escaping, or out-of-checkout paths. This
    # helper then walks the remaining lexical components before resolution can
    # redirect any release input through a symlink.
    current = repo_root.resolve()
    for part in relative_path.parts:
        if part in {"", "."}:
            continue
        if part == "..":
            raise ReleaseArtifactVerificationError(f"{field} must stay inside the repository")
        current = current / part
        if current.is_symlink() or _is_reparse_point(current):
            try:
                display_path = current.relative_to(repo_root.resolve()).as_posix()
            except ValueError:
                display_path = current.as_posix()
            raise ReleaseArtifactVerificationError(
                f"{field} must not include symlinks or reparse points: "
                f"{display_path}"
            )


def require_regular_file(path: Path, source: str) -> None:
    if path.is_symlink() or _is_reparse_point(path):
        raise ReleaseArtifactVerificationError(
            f"{source} must not be a symlink or reparse point: {path}"
        )
    if not path.is_file():
        raise ReleaseArtifactVerificationError(f"{source} references missing file: {path}")


def _read_unique_regular_file_once(
    path: Path,
    source: str,
) -> tuple[bytes, tuple[int, int]]:
    """Read one stable, non-redirecting, single-link file snapshot."""

    require_regular_file(path, source)
    try:
        lexical_stat = os.stat(path, follow_symlinks=False)
        if not stat.S_ISREG(lexical_stat.st_mode):
            raise ReleaseArtifactVerificationError(
                f"{source} must be a regular file: {path}"
            )
        if lexical_stat.st_nlink != 1:
            raise ReleaseArtifactVerificationError(
                f"{source} must have exactly one hard link: {path}"
            )
        with path.open("rb") as handle:
            opened_stat = os.fstat(handle.fileno())
            if not stat.S_ISREG(opened_stat.st_mode):
                raise ReleaseArtifactVerificationError(
                    f"{source} must be a regular file: {path}"
                )
            if opened_stat.st_nlink != 1:
                raise ReleaseArtifactVerificationError(
                    f"{source} must have exactly one hard link: {path}"
                )
            if (
                opened_stat.st_dev,
                opened_stat.st_ino,
            ) != (
                lexical_stat.st_dev,
                lexical_stat.st_ino,
            ):
                raise ReleaseArtifactVerificationError(
                    f"{source} changed before snapshot acquisition: {path}"
                )
            data = handle.read()
            final_opened_stat = os.fstat(handle.fileno())
        final_path_stat = os.stat(path, follow_symlinks=False)
    except FileNotFoundError as exc:
        raise ReleaseArtifactVerificationError(
            f"{source} changed during snapshot acquisition: {path}"
        ) from exc
    except OSError as exc:
        raise ReleaseArtifactVerificationError(
            f"cannot snapshot {source}: {path}: {exc}"
        ) from exc

    baseline = (
        opened_stat.st_dev,
        opened_stat.st_ino,
        opened_stat.st_size,
        opened_stat.st_mtime_ns,
        opened_stat.st_nlink,
    )
    if (
        (
            final_opened_stat.st_dev,
            final_opened_stat.st_ino,
            final_opened_stat.st_size,
            final_opened_stat.st_mtime_ns,
            final_opened_stat.st_nlink,
        )
        != baseline
        or (
            final_path_stat.st_dev,
            final_path_stat.st_ino,
            final_path_stat.st_size,
            final_path_stat.st_mtime_ns,
            final_path_stat.st_nlink,
        )
        != baseline
        or len(data) != opened_stat.st_size
    ):
        raise ReleaseArtifactVerificationError(
            f"{source} changed during snapshot acquisition: {path}"
        )
    return data, (opened_stat.st_dev, opened_stat.st_ino)


def resolve_release_dir(repo_root: Path, release_dir: Path) -> Path:
    repo_root = repo_root.resolve()
    candidate = release_dir if release_dir.is_absolute() else repo_root / release_dir
    resolved = candidate.resolve()
    try:
        resolved_relative = resolved.relative_to(repo_root)
    except ValueError as exc:
        raise ReleaseArtifactVerificationError(
            "release directory must stay inside the repository"
        ) from exc

    try:
        lexical_relative = candidate.relative_to(repo_root)
    except ValueError:
        lexical_relative = resolved_relative
    require_no_symlink_components(repo_root, lexical_relative, "release directory")
    return resolved


def resolve_release_file(repo_root: Path, relative_path: str, field: str) -> Path:
    if "\\" in relative_path:
        raise ReleaseArtifactVerificationError(f"{field} must use forward slashes")
    candidate = Path(relative_path)
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ReleaseArtifactVerificationError(f"{field} must stay inside the repository")
    require_no_symlink_components(repo_root, candidate, field)
    resolved = (repo_root / candidate).resolve()
    try:
        resolved.relative_to(repo_root.resolve())
    except ValueError as exc:
        raise ReleaseArtifactVerificationError(
            f"{field} must stay inside the repository"
        ) from exc
    return resolved


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    try:
        if path.is_symlink():
            raise ReleaseArtifactVerificationError(f"refusing symlinked file: {path}")
        return sha256_bytes(path.read_bytes())
    except FileNotFoundError as exc:
        raise ReleaseArtifactVerificationError(f"missing required file: {path}") from exc


def load_json(path: Path) -> Any:
    try:
        if path.is_symlink():
            raise ReleaseArtifactVerificationError(f"refusing symlinked JSON file: {path}")
        return json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise ReleaseArtifactVerificationError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise ReleaseArtifactVerificationError(f"invalid JSON in {path}: {exc}") from exc


def load_snapshot_json(
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
    relative_path: str,
    field: str,
) -> Any:
    snapshot = covered_file_snapshots.get(relative_path)
    if snapshot is None:
        raise ReleaseArtifactVerificationError(
            f"{field} is not present in the canonical covered-file snapshot: "
            f"{relative_path}"
        )
    try:
        text = snapshot.data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"{field} must be valid UTF-8: {relative_path}"
        ) from exc
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"invalid JSON in bound snapshot {relative_path}: {exc}"
        ) from exc


def require_dict(value: Any, field: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise ReleaseArtifactVerificationError(f"{field} must be an object")
    return value


def require_string(value: Any, field: str) -> str:
    if not isinstance(value, str) or value == "":
        raise ReleaseArtifactVerificationError(f"{field} must be a non-empty string")
    return value


def require_schema(data: Any, expected: str, field: str) -> dict[str, Any]:
    document = require_dict(data, field)
    schema = document.get("schema_version") or document.get("manifest_schema_version")
    if schema != expected:
        raise ReleaseArtifactVerificationError(f"{field} must use schema {expected}")
    return document


def parse_checksum_file(checksum_text: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = []
    seen_paths: set[str] = set()
    for line_number, line in enumerate(checksum_text.splitlines(), start=1):
        if not line:
            continue
        if "  " not in line:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: missing separator"
            )
        digest, relative_path = line.split("  ", 1)
        if not SHA256_RE.fullmatch(digest):
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: invalid sha256"
            )
        if relative_path.startswith("/") or "\\" in relative_path:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: invalid path"
            )
        if ".." in Path(relative_path).parts:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: path traversal"
            )
        if relative_path in seen_paths:
            raise ReleaseArtifactVerificationError(
                f"malformed checksum line {line_number}: duplicate path {relative_path}"
            )
        seen_paths.add(relative_path)
        entries.append((digest, relative_path))
    if not entries:
        raise ReleaseArtifactVerificationError("checksum file contains no entries")
    return entries


def snapshot_checksum_bundle(
    repo_root: Path,
    checksum_path: Path,
    checksum_manifest_path: Path,
) -> ChecksumBundleSnapshot:
    """Capture and parse both checksum indexes exactly once."""

    checksum_data, checksum_identity = _read_unique_regular_file_once(
        checksum_path,
        CHECKSUM_FILE_NAME,
    )
    if b"\r" in checksum_data:
        raise ReleaseArtifactVerificationError(
            f"{CHECKSUM_FILE_NAME} must use LF line endings"
        )
    try:
        checksum_text = checksum_data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"{CHECKSUM_FILE_NAME} must be valid UTF-8"
        ) from exc
    checksum_entries = tuple(parse_checksum_file(checksum_text))

    checksum_manifest_data, checksum_manifest_identity = (
        _read_unique_regular_file_once(
            checksum_manifest_path,
            CHECKSUM_MANIFEST_NAME,
        )
    )
    try:
        manifest_text = checksum_manifest_data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"{CHECKSUM_MANIFEST_NAME} must be valid UTF-8"
        ) from exc
    try:
        manifest = json.loads(manifest_text)
    except json.JSONDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"invalid JSON in {CHECKSUM_MANIFEST_NAME}: {exc}"
        ) from exc
    manifest = require_schema(
        manifest,
        CHECKSUM_SCHEMA,
        CHECKSUM_MANIFEST_NAME,
    )
    return ChecksumBundleSnapshot(
        checksum_file_path=normalize_path(checksum_path, repo_root),
        checksum_file_data=checksum_data,
        checksum_file_sha256=sha256_bytes(checksum_data),
        checksum_file_identity=checksum_identity,
        checksum_entries=checksum_entries,
        checksum_manifest_path=normalize_path(
            checksum_manifest_path,
            repo_root,
        ),
        checksum_manifest_data=checksum_manifest_data,
        checksum_manifest_identity=checksum_manifest_identity,
        checksum_manifest=manifest,
    )


def verify_file_record(
    repo_root: Path,
    *,
    path: str,
    sha256: str,
    size_bytes: int | None,
    source: str,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    del repo_root
    if not SHA256_PREFIX_RE.fullmatch(sha256):
        raise ReleaseArtifactVerificationError(f"{source} has invalid sha256 for {path}")
    snapshot = covered_file_snapshots.get(path)
    if snapshot is None:
        raise ReleaseArtifactVerificationError(
            f"{source} is absent from the immutable covered-file snapshot: {path}"
        )
    actual = snapshot.sha256
    actual_size = snapshot.size_bytes
    if actual != sha256:
        raise ReleaseArtifactVerificationError(
            f"{source} hash mismatch for {path}: expected {sha256}, got {actual}"
        )
    if size_bytes is not None and actual_size != size_bytes:
        raise ReleaseArtifactVerificationError(
            f"{source} size mismatch for {path}: expected {size_bytes}, "
            f"got {actual_size}"
        )


def verify_checksum_file(
    repo_root: Path,
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> dict[str, str]:
    del repo_root
    digests: dict[str, str] = {}
    for digest, relative_path in checksum_bundle.checksum_entries:
        snapshot = covered_file_snapshots.get(relative_path)
        if snapshot is None:
            raise ReleaseArtifactVerificationError(
                f"{CHECKSUM_FILE_NAME} entry is absent from the immutable "
                f"covered-file snapshot: {relative_path}"
            )
        actual = snapshot.sha256.removeprefix("sha256:")
        if actual != digest:
            raise ReleaseArtifactVerificationError(
                f"{CHECKSUM_FILE_NAME} hash mismatch for {relative_path}: "
                f"expected {digest}, got {actual}"
            )
        digests[relative_path] = digest
    return digests


def _require_normalized_repo_path(value: str, field: str) -> Path:
    if (
        not value
        or value.startswith("/")
        or value.endswith("/")
        or "\\" in value
        or "//" in value
        or ":" in value.split("/", 1)[0]
    ):
        raise ReleaseArtifactVerificationError(
            f"{field} must be a normalized repository-relative path: {value}"
        )
    parts = value.split("/")
    if any(part in {"", ".", ".."} for part in parts):
        raise ReleaseArtifactVerificationError(
            f"{field} must be a normalized repository-relative path: {value}"
        )
    normalized = Path(*parts)
    if normalized.as_posix() != value:
        raise ReleaseArtifactVerificationError(
            f"{field} must be a normalized repository-relative path: {value}"
        )
    return normalized


def _require_exact_component_spelling(
    repo_root: Path,
    relative_path: Path,
    field: str,
) -> None:
    current = repo_root.resolve()
    for part in relative_path.parts:
        if not current.is_dir():
            raise ReleaseArtifactVerificationError(
                f"{field} references missing path component: {part}"
            )
        case_matches = [
            child
            for child in current.iterdir()
            if child.name.casefold() == part.casefold()
        ]
        exact_matches = [
            child
            for child in case_matches
            if child.name == part
        ]
        if len(case_matches) != 1 or len(exact_matches) != 1:
            observed = sorted(child.name for child in case_matches)
            raise ReleaseArtifactVerificationError(
                f"{field} must use exact on-disk component spelling for "
                f"{part}: observed={observed}"
            )
        current = exact_matches[0]


def _independent_complete_reference_bindings(
    inventory: dict[str, Any],
) -> tuple[tuple[Path, str, str], ...]:
    references: list[tuple[Path, str, str]] = []
    genesis_profile = inventory.get("genesis_profile")
    if isinstance(genesis_profile, dict):
        references.append(
            (
                _require_normalized_repo_path(
                    require_string(
                        genesis_profile.get("path"),
                        "governed-parameter inventory genesis_profile.path",
                    ),
                    "governed-parameter inventory genesis_profile.path",
                ),
                require_string(
                    genesis_profile.get("sha256"),
                    "governed-parameter inventory genesis_profile.sha256",
                ),
                "genesis_profile",
            )
        )
    candidate = require_dict(
        inventory.get("candidate_binding"),
        "governed-parameter inventory candidate_binding",
    )
    if candidate.get("status") == "complete":
        references.append(
            (
                _require_normalized_repo_path(
                    require_string(
                        candidate.get("candidate_artifact_path"),
                        "candidate_binding.candidate_artifact_path",
                    ),
                    "candidate_binding.candidate_artifact_path",
                ),
                require_string(
                    candidate.get("candidate_artifact_sha256"),
                    "candidate_binding.candidate_artifact_sha256",
                ),
                "candidate_binding",
            )
        )
        host_bindings = candidate.get("host_bindings", [])
        if not isinstance(host_bindings, list):
            raise ReleaseArtifactVerificationError(
                "candidate_binding.host_bindings must be an array"
            )
        for index, raw_binding in enumerate(host_bindings):
            binding = require_dict(
                raw_binding,
                f"candidate_binding.host_bindings[{index}]",
            )
            source_verification = require_dict(
                binding.get("source_verification_binding"),
                (
                    f"candidate_binding.host_bindings[{index}]"
                    ".source_verification_binding"
                ),
            )
            field = (
                f"candidate_binding.host_bindings[{index}]"
                ".source_verification_binding.path"
            )
            references.append(
                (
                    _require_normalized_repo_path(
                        require_string(source_verification.get("path"), field),
                        field,
                    ),
                    require_string(
                        source_verification.get("sha256"),
                        (
                            f"candidate_binding.host_bindings[{index}]"
                            ".source_verification_binding.sha256"
                        ),
                    ),
                    (
                        f"candidate_binding.host_bindings[{index}]"
                        ".source_verification_binding"
                    ),
                )
            )
    parameters = inventory.get("parameters")
    if not isinstance(parameters, list):
        raise ReleaseArtifactVerificationError(
            "governed-parameter inventory parameters must be an array"
        )
    for index, raw_parameter in enumerate(parameters):
        parameter = require_dict(raw_parameter, f"parameters[{index}]")
        measurement = require_dict(
            parameter.get("measurement_evidence"),
            f"parameters[{index}].measurement_evidence",
        )
        if measurement.get("status") == "complete":
            field = f"parameters[{index}].measurement_evidence.path"
            references.append(
                (
                    _require_normalized_repo_path(
                        require_string(measurement.get("path"), field),
                        field,
                    ),
                    require_string(
                        measurement.get("sha256"),
                        f"parameters[{index}].measurement_evidence.sha256",
                    ),
                    f"parameters[{index}].measurement_evidence",
                )
            )
        fixed = require_dict(
            parameter.get("fixed_stipend_compatibility"),
            f"parameters[{index}].fixed_stipend_compatibility",
        )
        if fixed.get("status") == "complete":
            field = (
                f"parameters[{index}].fixed_stipend_compatibility.evidence_path"
            )
            references.append(
                (
                    _require_normalized_repo_path(
                        require_string(fixed.get("evidence_path"), field),
                        field,
                    ),
                    require_string(
                        fixed.get("evidence_sha256"),
                        (
                            f"parameters[{index}].fixed_stipend_compatibility"
                            ".evidence_sha256"
                        ),
                    ),
                    f"parameters[{index}].fixed_stipend_compatibility",
                )
            )
    return tuple(references)


def _independent_complete_reference_paths(
    inventory: dict[str, Any],
) -> tuple[Path, ...]:
    return tuple(
        path
        for path, _sha256, _source in (
            _independent_complete_reference_bindings(inventory)
        )
    )


def _canonical_covered_files(
    repo_root: Path,
    raw_covered_paths: Any,
    additional_references: Iterable[Path] = (),
) -> tuple[str, ...]:
    if not isinstance(raw_covered_paths, list) or not all(
        isinstance(path, str) and path
        for path in raw_covered_paths
    ):
        raise ReleaseArtifactVerificationError(
            "canonical line-ending bindings require string source.covered_paths"
        )
    normalized_roots = [
        _require_normalized_repo_path(
            path,
            f"release-checksums.source.covered_paths[{index}]",
        )
        for index, path in enumerate(raw_covered_paths)
    ]
    normalized_root_strings = [path.as_posix() for path in normalized_roots]
    if len(normalized_root_strings) != len(set(normalized_root_strings)):
        raise ReleaseArtifactVerificationError(
            "canonical release checksum coverage roots must be unique"
        )
    policy_digest = hashlib.sha256(
        (
            "\n".join(sorted(normalized_root_strings))
            + "\n"
        ).encode("utf-8")
    ).hexdigest()
    if (
        len(normalized_root_strings) != CANONICAL_COVERED_PATH_COUNT
        or policy_digest != CANONICAL_COVERED_PATHS_SHA256
    ):
        raise ReleaseArtifactVerificationError(
            "canonical release checksum coverage roots differ from the "
            "independent verifier policy: "
            f"count={len(normalized_root_strings)}; sha256={policy_digest}"
        )

    excluded = {
        "release-artifacts/latest/SHA256SUMS",
        "release-artifacts/latest/release-checksums.json",
    }
    files: set[str] = set()
    for configured_path in normalized_roots:
        _require_exact_component_spelling(
            repo_root,
            configured_path,
            f"canonical coverage root {configured_path.as_posix()}",
        )
        resolved = resolve_release_file(
            repo_root,
            configured_path.as_posix(),
            f"canonical coverage root {configured_path.as_posix()}",
        )
        if not resolved.exists():
            raise ReleaseArtifactVerificationError(
                f"canonical coverage root does not exist: {configured_path.as_posix()}"
            )
        if resolved.is_file():
            candidates = ((resolved, configured_path.as_posix()),)
        elif resolved.is_dir():
            discovered: list[tuple[Path, str]] = []
            pending: list[tuple[Path, Path]] = [(resolved, Path())]
            while pending:
                directory, suffix = pending.pop()
                try:
                    entries = sorted(
                        os.scandir(directory),
                        key=lambda entry: entry.name,
                    )
                except OSError as exc:
                    raise ReleaseArtifactVerificationError(
                        "cannot enumerate canonical coverage directory "
                        f"{configured_path.as_posix()}: {exc}"
                    ) from exc
                for entry in entries:
                    entry_path = Path(entry.path)
                    relative_suffix = suffix / entry.name
                    relative = (
                        configured_path / relative_suffix
                    ).as_posix()
                    if entry.is_symlink() or _is_reparse_point(entry_path):
                        raise ReleaseArtifactVerificationError(
                            "canonical covered path must not include symlinks "
                            f"or reparse points: {relative}"
                        )
                    if entry.is_dir(follow_symlinks=False):
                        pending.append((entry_path, relative_suffix))
                    elif entry.is_file(follow_symlinks=False):
                        discovered.append((entry_path, relative))
                    else:
                        raise ReleaseArtifactVerificationError(
                            "canonical covered path must be a regular file or "
                            f"directory: {relative}"
                        )
            candidates = tuple(discovered)
        else:
            raise ReleaseArtifactVerificationError(
                "canonical coverage root must be a regular file or directory: "
                f"{configured_path.as_posix()}"
            )
        for candidate, relative in candidates:
            normalized = _require_normalized_repo_path(
                relative,
                f"canonical covered file {relative}",
            )
            require_no_symlink_components(
                repo_root,
                normalized,
                f"canonical covered file {relative}",
            )
            require_regular_file(candidate, f"canonical covered file {relative}")
            if relative not in excluded:
                files.add(relative)

    for reference in additional_references:
        relative = reference.as_posix()
        _require_exact_component_spelling(
            repo_root,
            reference,
            f"complete governed-parameter reference {relative}",
        )
        resolved = resolve_release_file(
            repo_root,
            relative,
            f"complete governed-parameter reference {relative}",
        )
        require_regular_file(
            resolved,
            f"complete governed-parameter reference {relative}",
        )
        files.add(relative)

    for relative in tuple(files):
        parent = Path(relative).parent
        while parent != Path("."):
            nested_attributes = repo_root / parent / GIT_ATTRIBUTES_PATH
            if nested_attributes.exists() or nested_attributes.is_symlink():
                raise ReleaseArtifactVerificationError(
                    "canonical coverage forbids nested .gitattributes: "
                    f"{(parent / GIT_ATTRIBUTES_PATH).as_posix()}"
                )
            parent = parent.parent
    nested_attribute_files = sorted(
        path
        for path in files
        if Path(path).name == GIT_ATTRIBUTES_PATH
        and path != GIT_ATTRIBUTES_PATH
    )
    if nested_attribute_files:
        raise ReleaseArtifactVerificationError(
            "canonical coverage forbids nested .gitattributes: "
            + ", ".join(nested_attribute_files)
        )
    return tuple(sorted(files))


def _parse_canonical_gitattributes(
    attributes_data: bytes,
) -> list[tuple[str, str, str | None]]:
    try:
        text = attributes_data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            f"{GIT_ATTRIBUTES_PATH} must be valid UTF-8"
        ) from exc
    if "\x00" in text:
        raise ReleaseArtifactVerificationError(
            f"{GIT_ATTRIBUTES_PATH} must not contain NUL bytes"
        )
    rules: list[tuple[str, str, str | None]] = []
    for line_number, raw_line in enumerate(text.split("\n"), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            raise ReleaseArtifactVerificationError(
                f"unsupported .gitattributes rule at line {line_number}: "
                "missing attributes"
            )
        pattern, *attributes = parts
        if (
            pattern.startswith("!")
            or pattern.startswith("/")
            or pattern.endswith("/")
            or "\\" in pattern
            or '"' in pattern
            or any(character in pattern for character in "?[]")
            or "//" in pattern
            or any(part in {".", ".."} for part in pattern.split("/"))
        ):
            raise ReleaseArtifactVerificationError(
                f"unsupported .gitattributes pattern at line {line_number}: "
                f"{pattern}"
            )
        if "*" in pattern and not (
            pattern == "*"
            or (
                pattern.startswith("*.")
                and pattern.count("*") == 1
                and "/" not in pattern
            )
            or (
                pattern.endswith("/**")
                and pattern.count("*") == 2
                and "*" not in pattern[:-2]
            )
        ):
            raise ReleaseArtifactVerificationError(
                f"unsupported .gitattributes wildcard at line {line_number}: "
                f"{pattern}"
            )
        text_modes = [
            token
            for token in attributes
            if token in {"text", "text=auto", "-text", "binary"}
        ]
        eol_tokens = [
            token.removeprefix("eol=")
            for token in attributes
            if token.startswith("eol=")
        ]
        unknown = [
            token
            for token in attributes
            if token not in {"text", "text=auto", "-text", "binary"}
            and not token.startswith("eol=")
        ]
        if unknown:
            raise ReleaseArtifactVerificationError(
                f"unsupported .gitattributes attribute at line {line_number}: "
                f"{unknown[0]}"
            )
        if len(text_modes) != 1:
            raise ReleaseArtifactVerificationError(
                f"ambiguous .gitattributes text mode at line {line_number}"
            )
        if len(eol_tokens) > 1 or any(
            value not in {"lf", "crlf"}
            for value in eol_tokens
        ):
            raise ReleaseArtifactVerificationError(
                f"ambiguous .gitattributes eol at line {line_number}"
            )
        mode = {
            "text": "text",
            "text=auto": "auto",
            "-text": "binary",
            "binary": "binary",
        }[text_modes[0]]
        eol = eol_tokens[0] if eol_tokens else None
        if mode == "binary" and eol is not None:
            raise ReleaseArtifactVerificationError(
                "binary .gitattributes rule must not set eol at line "
                f"{line_number}"
            )
        rules.append((pattern, mode, eol))
    if not rules:
        raise ReleaseArtifactVerificationError(
            f"{GIT_ATTRIBUTES_PATH} has no usable rules"
        )
    return rules


def _gitattributes_pattern_matches(
    pattern: str,
    relative_path: str,
) -> bool:
    if pattern == "*":
        return True
    if pattern.startswith("*."):
        return Path(relative_path).name.endswith(pattern[1:])
    if pattern.endswith("/**"):
        return relative_path.startswith(pattern[:-2])
    return relative_path == pattern


def _classify_canonical_file(
    relative_path: str,
    data: bytes,
    rules: Sequence[tuple[str, str, str | None]],
) -> str:
    mode: str | None = None
    eol: str | None = None
    for pattern, rule_mode, rule_eol in rules:
        if not _gitattributes_pattern_matches(pattern, relative_path):
            continue
        mode = rule_mode
        if rule_eol is not None:
            eol = rule_eol
    if mode is None:
        raise ReleaseArtifactVerificationError(
            f"covered path has no explicit text/binary rule: {relative_path}"
        )
    if mode == "binary" or (
        mode == "auto"
        and b"\x00" in data[:GIT_BINARY_SNIFF_BYTES]
    ):
        if eol is not None:
            raise ReleaseArtifactVerificationError(
                f"binary covered path must not declare eol: {relative_path}"
            )
        return "binary"
    if eol is None:
        raise ReleaseArtifactVerificationError(
            "covered Git text path must declare explicit eol=lf or eol=crlf: "
            f"{relative_path}"
        )
    if eol == "lf":
        if b"\r" in data:
            raise ReleaseArtifactVerificationError(
                f"covered Git text path violates declared eol=lf: {relative_path}"
            )
        return "lf"
    without_crlf = data.replace(b"\r\n", b"")
    if b"\r" in without_crlf or b"\n" in without_crlf:
        raise ReleaseArtifactVerificationError(
            f"covered Git text path violates declared eol=crlf: {relative_path}"
        )
    return "crlf"


def verify_canonical_line_ending_bindings(
    repo_root: Path,
    checksum_bundle: ChecksumBundleSnapshot,
) -> dict[str, CanonicalCoveredFile]:
    """Snapshot and verify canonical coverage/EOL before accepting hashes."""

    repo_root = require_canonical_repo_root(repo_root)
    checksum_entries = checksum_bundle.checksum_entries
    checksum_entries_by_path = {
        path: digest
        for digest, path in checksum_entries
    }
    for path in checksum_entries_by_path:
        _require_normalized_repo_path(path, f"{CHECKSUM_FILE_NAME}.{path}")

    data = checksum_bundle.checksum_manifest
    source = require_dict(data.get("source"), "release-checksums.source")
    if (
        source.get("coverage_policy")
        != CANONICAL_COVERAGE_POLICY
    ):
        raise ReleaseArtifactVerificationError(
            "canonical line-ending bindings require canonical coverage_policy"
        )
    configured_paths = set(
        _canonical_covered_files(
            repo_root,
            source.get("covered_paths"),
        )
    )

    raw_files = data.get("files")
    if not isinstance(raw_files, list):
        raise ReleaseArtifactVerificationError(
            "canonical line-ending bindings require checksum manifest files"
        )
    manifest_entries_by_path: dict[str, dict[str, Any]] = {}
    for index, raw_entry in enumerate(raw_files):
        entry = require_dict(raw_entry, f"release-checksums.files[{index}]")
        path = require_string(
            entry.get("path"),
            f"release-checksums.files[{index}].path",
        )
        _require_normalized_repo_path(
            path,
            f"release-checksums.files[{index}].path",
        )
        if path in manifest_entries_by_path:
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding requires exactly one "
                f"release-checksums.json entry for {path}: got 2"
            )
        manifest_entries_by_path[path] = entry

    checksum_paths = set(checksum_entries_by_path)
    manifest_paths = set(manifest_entries_by_path)
    if checksum_paths != manifest_paths:
        raise ReleaseArtifactVerificationError(
            "canonical line-ending checksum-index file-set mismatch: "
            f"SHA256SUMS-only={sorted(checksum_paths - manifest_paths)}; "
            "release-checksums.json-only="
            f"{sorted(manifest_paths - checksum_paths)}"
        )
    missing_configured = sorted(configured_paths - checksum_paths)
    if missing_configured:
        raise ReleaseArtifactVerificationError(
            "canonical line-ending checksum indexes omit configured files: "
            f"{missing_configured}"
        )
    if GIT_ATTRIBUTES_PATH not in checksum_paths:
        raise ReleaseArtifactVerificationError(
            "canonical line-ending binding requires exactly one SHA256SUMS "
            f"entry for {GIT_ATTRIBUTES_PATH}: got 0"
        )
    if GIT_ATTRIBUTES_PATH not in manifest_paths:
        raise ReleaseArtifactVerificationError(
            "canonical line-ending binding requires exactly one "
            "release-checksums.json entry for "
            f"{GIT_ATTRIBUTES_PATH}: got 0"
        )

    output_file_identities = {
        checksum_bundle.checksum_file_identity,
        checksum_bundle.checksum_manifest_identity,
    }
    file_identities: dict[tuple[int, int], str] = {}
    file_bytes: dict[str, bytes] = {}
    for relative_path in sorted(checksum_paths):
        normalized_relative_path = _require_normalized_repo_path(
            relative_path,
            f"canonical line-ending binding {relative_path}",
        )
        _require_exact_component_spelling(
            repo_root,
            normalized_relative_path,
            f"canonical line-ending binding {relative_path}",
        )
        resolved = resolve_release_file(
            repo_root,
            relative_path,
            f"canonical line-ending binding {relative_path}",
        )
        require_regular_file(
            resolved,
            f"canonical line-ending binding {relative_path}",
        )
        with resolved.open("rb") as handle:
            opened_stat = os.fstat(handle.fileno())
            identity = (opened_stat.st_dev, opened_stat.st_ino)
            if identity in output_file_identities:
                raise ReleaseArtifactVerificationError(
                    "canonical covered file must not alias a checksum output: "
                    f"{relative_path}"
                )
            prior_path = file_identities.get(identity)
            if prior_path is not None:
                raise ReleaseArtifactVerificationError(
                    "canonical covered files must not alias the same file: "
                    f"{prior_path}, {relative_path}"
                )
            file_identities[identity] = relative_path
            file_bytes[relative_path] = handle.read()
    try:
        governed_parameter_inventory = json.loads(
            file_bytes[GOVERNED_PARAMETER_INVENTORY_PATH].decode("utf-8")
        )
    except (KeyError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReleaseArtifactVerificationError(
            "governed-parameter inventory must be present as valid UTF-8 JSON "
            "in the immutable checksum snapshot"
        ) from exc
    governed_parameter_inventory = require_dict(
        governed_parameter_inventory,
        "governed-parameter inventory",
    )
    expected_paths = set(
        _canonical_covered_files(
            repo_root,
            source.get("covered_paths"),
            _independent_complete_reference_paths(
                governed_parameter_inventory
            ),
        )
    )
    if checksum_paths != expected_paths:
        missing = sorted(expected_paths - checksum_paths)
        unexpected = sorted(checksum_paths - expected_paths)
        raise ReleaseArtifactVerificationError(
            "canonical line-ending checksum-index file-set mismatch: "
            f"missing={missing}; unexpected={unexpected}"
        )

    rules = _parse_canonical_gitattributes(
        file_bytes[GIT_ATTRIBUTES_PATH]
    )

    snapshots: dict[str, CanonicalCoveredFile] = {}
    for relative_path, data_bytes in file_bytes.items():
        entry = manifest_entries_by_path[relative_path]
        manifest_sha256 = require_string(
            entry.get("sha256"),
            f"release-checksums.{relative_path}.sha256",
        )
        checksum_sha256 = checksum_entries_by_path[relative_path]
        if manifest_sha256 != f"sha256:{checksum_sha256}":
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding checksum indexes disagree for "
                f"{relative_path}"
            )
        size_bytes = entry.get("size_bytes")
        if not isinstance(size_bytes, int) or isinstance(size_bytes, bool):
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding size must be an integer for "
                f"{relative_path}"
            )
        actual_sha256 = sha256_bytes(data_bytes)
        actual_size = len(data_bytes)
        if size_bytes != actual_size:
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding size mismatch for "
                f"{relative_path}: expected {size_bytes}, got {actual_size}"
            )
        if checksum_sha256 != actual_sha256.removeprefix("sha256:"):
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding SHA256SUMS hash mismatch for "
                f"{relative_path}"
            )
        if manifest_sha256 != actual_sha256:
            raise ReleaseArtifactVerificationError(
                "canonical line-ending binding release-checksums.json hash "
                f"mismatch for {relative_path}"
            )
        snapshots[relative_path] = CanonicalCoveredFile(
            data=data_bytes,
            sha256=actual_sha256,
            size_bytes=actual_size,
            line_ending=_classify_canonical_file(
                relative_path,
                data_bytes,
                rules,
            ),
        )
    return snapshots


def _materialize_covered_file_snapshots(
    snapshot_root: Path,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    for relative_path, snapshot in covered_file_snapshots.items():
        target = snapshot_root / Path(*relative_path.split("/"))
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(snapshot.data)


def verify_reviewed_subprocess_source_bindings(
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    """Independently pin every release tool permitted to spawn a subprocess."""

    for configured_path, (expected_sha256, expected_size) in sorted(
        REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES.items()
    ):
        relative_path = configured_path.as_posix()
        snapshot = covered_file_snapshots.get(relative_path)
        if snapshot is None:
            raise ReleaseArtifactVerificationError(
                "reviewed subprocess source is absent from the immutable "
                f"canonical snapshot: {relative_path}"
            )
        actual_sha256 = hashlib.sha256(snapshot.data).hexdigest()
        actual_size = len(snapshot.data)
        if (actual_sha256, actual_size) != (expected_sha256, expected_size):
            raise ReleaseArtifactVerificationError(
                "reviewed subprocess source differs from the verifier's "
                f"exact hash/size binding: {relative_path}; expected "
                f"{expected_sha256}/{expected_size}, got "
                f"{actual_sha256}/{actual_size}"
            )


def _policy_json_object(data: bytes, *, label: str) -> dict[str, Any]:
    """Decode one immutable policy document while rejecting duplicate keys."""

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        value: dict[str, Any] = {}
        for key, member in pairs:
            if key in value:
                raise ReleaseArtifactVerificationError(
                    f"{label} contains duplicate key {key!r}"
                )
            value[key] = member
        return value

    try:
        decoded = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=unique_object,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReleaseArtifactVerificationError(
            f"{label} is not canonical UTF-8 JSON: {exc}"
        ) from exc
    if not isinstance(decoded, dict):
        raise ReleaseArtifactVerificationError(
            f"{label} must be a JSON object"
        )
    return decoded


def _policy_parent_map(
    tree: ast.AST,
) -> dict[ast.AST, tuple[ast.AST, str]]:
    parents: dict[ast.AST, tuple[ast.AST, str]] = {}
    for parent in ast.walk(tree):
        for field, child in ast.iter_fields(parent):
            if isinstance(child, ast.AST):
                parents[child] = (parent, field)
            elif isinstance(child, list):
                for item in child:
                    if isinstance(item, ast.AST):
                        parents[item] = (parent, field)
    return parents


def _policy_imports(
    tree: ast.AST,
    relative_path: Path,
    *,
    role: str,
    local_dependencies: set[Path] | None = None,
    observed_external_modules: set[str] | None = None,
) -> tuple[list[dict[str, Any]], dict[str, str]]:
    records: dict[str, int] = {}
    bindings: dict[str, str] = {}
    reviewed_module_paths = {
        path.with_suffix("").name: path
        for path in (
            REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
            + REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
        )
    }
    reviewed_module_names = set(reviewed_module_paths)

    def validate_module(
        module: str,
        *,
        member: str | None,
        level: int,
        node: ast.AST,
    ) -> None:
        if level:
            if (
                module
                and module.split(".", 1)[0] not in reviewed_module_names
            ):
                raise ReleaseArtifactVerificationError(
                    "release-tool call policy forbids unknown relative import "
                    f"{'.' * level}{module} in "
                    f"{relative_path.as_posix()}:"
                    f"{getattr(node, 'lineno', 0)}"
                )
            return
        if (
            role == "runtime"
            and relative_path
            != Path("scripts/verify_release_artifacts.py")
            and module
            in {"runpy", "importlib.util", "importlib.machinery"}
        ):
            raise ReleaseArtifactVerificationError(
                "release-tool runtime call policy forbids alternate loader "
                f"module {module!r} in "
                f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
            )
        if module in RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES:
            if observed_external_modules is not None:
                observed_external_modules.add(module)
            return
        local_module = module
        if local_module.startswith("scripts."):
            local_module = local_module.removeprefix("scripts.")
        if local_module == "scripts" and member in reviewed_module_names:
            if local_dependencies is not None:
                local_dependencies.add(reviewed_module_paths[member])
            return
        if local_module in reviewed_module_names:
            if local_dependencies is not None:
                local_dependencies.add(reviewed_module_paths[local_module])
            return
        raise ReleaseArtifactVerificationError(
            "release-tool call policy forbids unreviewed import module "
            f"{module!r} in {relative_path.as_posix()}:"
            f"{getattr(node, 'lineno', 0)}"
        )

    def add_record(value: dict[str, Any]) -> None:
        record = json.dumps(
            value,
            ensure_ascii=True,
            separators=(",", ":"),
            sort_keys=True,
        )
        records[record] = records.get(record, 0) + 1

    def add_binding(binding: str, target: str, node: ast.AST) -> None:
        existing = bindings.get(binding)
        if existing is not None and existing != target:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy has ambiguous import binding "
                f"{binding!r} in {relative_path.as_posix()}:"
                f"{getattr(node, 'lineno', 0)}"
            )
        bindings[binding] = target

    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                validate_module(
                    alias.name,
                    member=None,
                    level=0,
                    node=node,
                )
                binding = alias.asname or alias.name.split(".", 1)[0]
                target = alias.name if alias.asname else binding
                add_record(
                    {
                        "alias": alias.asname,
                        "binding": binding,
                        "kind": "import",
                        "level": 0,
                        "member": None,
                        "module": alias.name,
                    }
                )
                add_binding(binding, target, node)
        elif isinstance(node, ast.ImportFrom):
            if node.level:
                raise ReleaseArtifactVerificationError(
                    "release-tool call policy forbids relative import in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
            if any(alias.name == "*" for alias in node.names):
                raise ReleaseArtifactVerificationError(
                    "release-tool call policy forbids wildcard import in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
            module = node.module or ""
            prefix = "." * node.level
            for alias in node.names:
                validate_module(
                    module,
                    member=alias.name,
                    level=node.level,
                    node=node,
                )
                binding = alias.asname or alias.name
                target = f"{prefix}{module}"
                if module:
                    target += "."
                target += alias.name
                add_record(
                    {
                        "alias": alias.asname,
                        "binding": binding,
                        "kind": "from",
                        "level": node.level,
                        "member": alias.name,
                        "module": module,
                    }
                )
                add_binding(binding, target, node)

    return (
        [
            {"record": record, "count": records[record]}
            for record in sorted(records)
        ],
        bindings,
    )


def _policy_reject_imported_binding_shadows(
    tree: ast.AST,
    bindings: dict[str, str],
    parents: dict[ast.AST, tuple[ast.AST, str]],
    relative_path: Path,
) -> frozenset[tuple[str, str, str, str]]:
    """Reject imported-name shadowing except five exact checker fallbacks."""

    observed: set[tuple[str, str, str, str]] = set()

    def reject(name: str, node: ast.AST, shape: str) -> None:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy forbids imported binding shadow "
            f"path={relative_path.as_posix()!r}, binding={name!r}, "
            f"target={bindings[name]!r}, shape={shape!r} at line "
            f"{getattr(node, 'lineno', 0)}"
        )

    for node in ast.walk(tree):
        name: str | None = None
        shape: str | None = None
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, (ast.Store, ast.Del))
            and node.id in bindings
        ):
            name = node.id
            shape = f"Name.{type(node.ctx).__name__}"
        elif isinstance(node, ast.arg) and node.arg in bindings:
            name = node.arg
            shape = "arg"
        elif (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and node.name in bindings
        ):
            name = node.name
            shape = type(node).__name__
        elif (
            isinstance(node, ast.ExceptHandler)
            and isinstance(node.name, str)
            and node.name in bindings
        ):
            name = node.name
            shape = "ExceptHandler.name"
        elif (
            isinstance(node, (ast.MatchAs, ast.MatchStar))
            and isinstance(node.name, str)
            and node.name in bindings
        ):
            name = node.name
            shape = f"{type(node).__name__}.name"
        elif (
            isinstance(node, ast.MatchMapping)
            and isinstance(node.rest, str)
            and node.rest in bindings
        ):
            name = node.rest
            shape = "MatchMapping.rest"
        elif isinstance(node, (ast.Global, ast.Nonlocal)):
            for declared_name in node.names:
                if declared_name in bindings:
                    reject(declared_name, node, type(node).__name__)
            continue
        if name is None:
            continue

        parent_info = parents.get(node)
        allowed_key: tuple[str, str, str, str] | None = None
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Store)
            and parent_info is not None
        ):
            parent, field = parent_info
            if (
                isinstance(parent, ast.Assign)
                and field == "targets"
                and len(parent.targets) == 1
                and parent.targets[0] is node
            ):
                handler_info = parents.get(parent)
                handler = (
                    handler_info[0]
                    if (
                        handler_info is not None
                        and isinstance(handler_info[0], ast.ExceptHandler)
                        and handler_info[1] == "body"
                    )
                    else None
                )
                if (
                    handler is not None
                    and isinstance(handler.type, ast.Name)
                    and handler.type.id == "ModuleNotFoundError"
                    and handler.name is None
                ):
                    allowed_key = (
                        relative_path.as_posix(),
                        name,
                        bindings[name],
                        ast.dump(
                            parent.value,
                            annotate_fields=True,
                            include_attributes=False,
                        ),
                    )

        if (
            allowed_key is None
            or allowed_key not in RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST
            or allowed_key in observed
        ):
            reject(name, node, shape or type(node).__name__)
        observed.add(allowed_key)

    return frozenset(observed)


def _policy_reject_imported_binding_escapes(
    tree: ast.AST,
    bindings: dict[str, str],
    parents: dict[ast.AST, tuple[ast.AST, str]],
    relative_path: Path,
) -> frozenset[tuple[str, str, str, str]]:
    """Pin every imported value use outside a direct call/member chain."""

    def imported_target(node: ast.AST) -> str | None:
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in bindings
        ):
            return bindings[node.id]
        if isinstance(node, ast.Attribute):
            dotted = _policy_dotted_parts(node)
            if dotted is not None and dotted[0] in bindings:
                return ".".join((bindings[dotted[0]], *dotted[1:]))
        return None

    def is_outermost_imported_member(node: ast.AST) -> bool:
        parent_info = parents.get(node)
        if parent_info is None:
            return True
        parent, field = parent_info
        return not (
            isinstance(parent, ast.Attribute)
            and field == "value"
            and imported_target(parent) is not None
        )

    def is_annotation_or_exception_context(node: ast.AST) -> bool:
        current = node
        while current in parents:
            parent, field = parents[current]
            if field in {"annotation", "returns", "type_comment"}:
                return True
            if isinstance(parent, ast.ExceptHandler) and field == "type":
                return True
            if isinstance(parent, (ast.FunctionDef, ast.AsyncFunctionDef)):
                if field == "decorator_list":
                    return True
            if isinstance(parent, ast.ClassDef) and field in {
                "bases",
                "keywords",
                "decorator_list",
            }:
                return True
            if isinstance(parent, ast.stmt):
                return False
            current = parent
        return False

    observed: set[tuple[str, str, str, str]] = set()
    for node in ast.walk(tree):
        target = imported_target(node)
        if target is None or not is_outermost_imported_member(node):
            continue
        if is_annotation_or_exception_context(node):
            continue
        parent_info = parents.get(node)
        if parent_info is None:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy forbids root imported binding "
                f"{target} in "
                f"{relative_path.as_posix()}:"
                f"{getattr(node, 'lineno', 0)}"
            )
        parent, field = parent_info
        if isinstance(parent, ast.Call) and field == "func":
            continue
        first_field = f"{type(parent).__name__}.{field}"
        current = node
        key: tuple[str, str, str, str] | None = None
        while current in parents:
            parent, field = parents[current]
            if isinstance(parent, ast.Call):
                call_target = _policy_static_target(
                    parent.func,
                    bindings,
                    relative_path,
                )
                if field == "args":
                    argument_index = next(
                        (
                            index
                            for index, argument in enumerate(parent.args)
                            if argument is current
                        ),
                        -1,
                    )
                    value_field = f"arg:{argument_index}"
                elif field == "keywords":
                    keyword = next(
                        (
                            candidate
                            for candidate in parent.keywords
                            if candidate is current
                        ),
                        None,
                    )
                    value_field = (
                        f"keyword:{keyword.arg}"
                        if keyword is not None and keyword.arg is not None
                        else "keyword:**"
                    )
                elif field == "func":
                    key = None
                    break
                else:
                    value_field = f"call-{field}"
                key = (
                    relative_path.as_posix(),
                    target,
                    call_target,
                    value_field,
                )
                break
            if isinstance(parent, ast.stmt):
                key = (
                    relative_path.as_posix(),
                    target,
                    "<none>",
                    first_field,
                )
                break
            current = parent
        if key is None:
            continue
        if key not in RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy forbids unreviewed imported value "
                f"context path={key[0]!r}, target={key[1]!r}, "
                f"call={key[2]!r}, field={key[3]!r} at line "
                f"{getattr(node, 'lineno', 0)}"
            )
        observed.add(key)
    return frozenset(observed)


def _policy_dotted_parts(node: ast.AST) -> tuple[str, ...] | None:
    parts: list[str] = []
    current = node
    while isinstance(current, ast.Attribute):
        parts.append(current.attr)
        current = current.value
    if not isinstance(current, ast.Name):
        return None
    parts.append(current.id)
    return tuple(reversed(parts))


def _policy_static_target(
    node: ast.AST,
    bindings: dict[str, str],
    relative_path: Path,
) -> str:
    if isinstance(node, ast.Name):
        return bindings.get(node.id, f"local:{node.id}")
    if isinstance(node, ast.Attribute):
        dotted = _policy_dotted_parts(node)
        if dotted is not None:
            root = bindings.get(dotted[0], f"local:{dotted[0]}")
            suffix = ".".join(dotted[1:])
            return f"{root}.{suffix}" if suffix else root
        attributes: list[str] = []
        current: ast.AST = node
        while isinstance(current, ast.Attribute):
            attributes.append(current.attr)
            current = current.value
        if isinstance(current, ast.Call):
            receiver = _policy_static_target(
                current.func,
                bindings,
                relative_path,
            )
            return (
                f"{receiver}()."
                + ".".join(reversed(attributes))
            )
        imported_receiver_names = sorted(
            {
                child.id
                for child in ast.walk(node.value)
                if (
                    isinstance(child, ast.Name)
                    and isinstance(child.ctx, ast.Load)
                    and child.id in bindings
                )
            }
        )
        if imported_receiver_names:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy forbids computed imported receiver "
                f"in {relative_path.as_posix()}:{node.lineno}: "
                f"{imported_receiver_names}"
            )
        receiver_ast = ast.dump(
            node.value,
            annotate_fields=True,
            include_attributes=False,
        ).encode("utf-8")
        return (
            f"expression:{type(node.value).__name__}:"
            f"{hashlib.sha256(receiver_ast).hexdigest()}.{node.attr}"
        )
    raise ReleaseArtifactVerificationError(
        "release-tool call policy forbids computed or escaped callable in "
        f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
    )


def _policy_member_context(
    node: ast.AST,
    parents: dict[ast.AST, tuple[ast.AST, str]],
) -> str:
    parent_info = parents.get(node)
    if parent_info is None:
        return "root"
    parent, field = parent_info
    if isinstance(parent, ast.Call) and field == "func":
        return "call-target"
    if isinstance(parent, ast.Attribute) and field == "value":
        return "attribute-base"
    return f"{type(parent).__name__}.{field}"


def _policy_members(
    tree: ast.AST,
    bindings: dict[str, str],
    parents: dict[ast.AST, tuple[ast.AST, str]],
) -> list[dict[str, Any]]:
    records: dict[str, int] = {}
    for node in ast.walk(tree):
        target: str | None = None
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in bindings
        ):
            target = bindings[node.id]
        elif isinstance(node, ast.Attribute):
            dotted = _policy_dotted_parts(node)
            if dotted is not None and dotted[0] in bindings:
                target = ".".join((bindings[dotted[0]], *dotted[1:]))
        if target is None:
            continue
        record = json.dumps(
            {
                "context": _policy_member_context(node, parents),
                "target": target,
            },
            ensure_ascii=True,
            separators=(",", ":"),
            sort_keys=True,
        )
        records[record] = records.get(record, 0) + 1
    return [
        {"record": record, "count": records[record]}
        for record in sorted(records)
    ]


def _policy_calls(
    tree: ast.AST,
    bindings: dict[str, str],
    relative_path: Path,
) -> list[dict[str, Any]]:
    records: dict[tuple[str, str, str], int] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        target = _policy_static_target(node.func, bindings, relative_path)
        if target in {
            "local:__import__",
            "builtins.__import__",
            "importlib.import_module",
        }:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy forbids dynamic import in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
        if (
            target == "local:getattr"
            and (
                len(node.args) < 2
                or not isinstance(node.args[1], ast.Constant)
                or not isinstance(node.args[1].value, str)
            )
        ):
            raise ReleaseArtifactVerificationError(
                "release-tool call policy forbids computed attribute name in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
        keyword_names = [
            keyword.arg if keyword.arg is not None else "**"
            for keyword in node.keywords
        ]
        shape = (
            "positional="
            f"{sum(not isinstance(arg, ast.Starred) for arg in node.args)};"
            "starred="
            f"{sum(isinstance(arg, ast.Starred) for arg in node.args)};"
            f"keywords={','.join(keyword_names)}"
        )
        normalized_ast = ast.dump(
            node,
            annotate_fields=True,
            include_attributes=False,
        ).encode("utf-8")
        ast_sha256 = hashlib.sha256(normalized_ast).hexdigest()
        key = (target, shape, ast_sha256)
        records[key] = records.get(key, 0) + 1
    return [
        {
            "target": target,
            "shape": shape,
            "ast_sha256": ast_sha256,
            "count": records[(target, shape, ast_sha256)],
        }
        for target, shape, ast_sha256 in sorted(records)
    ]


def _policy_row_from_snapshot(
    relative_path: Path,
    role: str,
    snapshot: CanonicalCoveredFile,
    imported_value_uses: set[tuple[str, str, str, str]] | None = None,
    imported_shadow_uses: set[tuple[str, str, str, str]] | None = None,
    local_dependencies: set[Path] | None = None,
    observed_external_modules: set[str] | None = None,
) -> dict[str, Any]:
    try:
        source_text = snapshot.data.decode("utf-8")
        tree = ast.parse(source_text, filename=relative_path.as_posix())
    except UnicodeDecodeError as exc:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy source must be UTF-8: "
            f"{relative_path.as_posix()}"
        ) from exc
    except SyntaxError as exc:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy cannot parse "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc
    imports, bindings = _policy_imports(
        tree,
        relative_path,
        role=role,
        local_dependencies=local_dependencies,
        observed_external_modules=observed_external_modules,
    )
    if (
        role == "runtime"
        and relative_path != Path("scripts/verify_release_artifacts.py")
    ):
        for node in ast.walk(tree):
            if (
                isinstance(node, ast.Attribute)
                and node.attr in {"exec_module", "load_module"}
            ):
                raise ReleaseArtifactVerificationError(
                    "release-tool runtime call policy forbids alternate "
                    f"loader member {node.attr!r} in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
    parents = _policy_parent_map(tree)
    observed_imported_shadows = _policy_reject_imported_binding_shadows(
        tree,
        bindings,
        parents,
        relative_path,
    )
    if imported_shadow_uses is not None:
        imported_shadow_uses.update(observed_imported_shadows)
    observed_imported_values = _policy_reject_imported_binding_escapes(
        tree,
        bindings,
        parents,
        relative_path,
    )
    if imported_value_uses is not None:
        imported_value_uses.update(observed_imported_values)
    return {
        "path": relative_path.as_posix(),
        "role": role,
        "source_sha256": hashlib.sha256(snapshot.data).hexdigest(),
        "size_bytes": len(snapshot.data),
        "imports": imports,
        "members": _policy_members(tree, bindings, parents),
        "calls": _policy_calls(tree, bindings, relative_path),
    }


def _validate_policy_schema_document(schema: dict[str, Any]) -> None:
    expected = {
        "$schema": JSON_SCHEMA_DRAFT,
        "$id": RELEASE_TOOL_CALL_POLICY_SCHEMA_ID,
        "title": "6529Stream Release Tool Call Policy v1",
        "type": "object",
        "additionalProperties": False,
        "required": [
            "schema_version",
            "generator_version",
            "runtime_roots",
            "external_modules",
            "reviewed_paths",
        ],
        "properties": {
            "schema_version": {
                "const": RELEASE_TOOL_CALL_POLICY_SCHEMA,
            },
            "generator_version": {"const": "1"},
            "runtime_roots": {
                "type": "array",
                "minItems": 7,
                "maxItems": 7,
                "uniqueItems": True,
                "prefixItems": [
                    {
                        "const": path.as_posix(),
                    }
                    for path in REVIEWED_RELEASE_TOOL_ROOTS
                ],
                "items": False,
            },
            "external_modules": {
                "type": "array",
                "minItems": 31,
                "maxItems": 31,
                "uniqueItems": True,
                "prefixItems": [
                    {
                        "const": module,
                    }
                    for module in sorted(
                        RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES
                    )
                ],
                "items": False,
            },
            "reviewed_paths": {
                "type": "array",
                "minItems": 34,
                "maxItems": 34,
                "uniqueItems": True,
                "prefixItems": [
                    {
                        "allOf": [
                            {
                                "$ref": "#/$defs/reviewedPath",
                            },
                        ],
                        "required": [
                            "path",
                            "role",
                        ],
                        "properties": {
                            "path": {
                                "const": path.as_posix(),
                            },
                            "role": {
                                "const": (
                                    "runtime"
                                    if path
                                    in REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
                                    else "focused-test"
                                ),
                            },
                        },
                    }
                    for path in sorted(
                        REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
                        + REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
                    )
                ],
                "items": False,
            },
        },
        "$defs": {
            "reviewedPath": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "path",
                    "role",
                    "source_sha256",
                    "size_bytes",
                    "imports",
                    "members",
                    "calls",
                ],
                "properties": {
                    "path": {
                        "type": "string",
                        "pattern": RELEASE_TOOL_CALL_POLICY_PATH_PATTERN,
                    },
                    "role": {
                        "enum": ["runtime", "focused-test"],
                    },
                    "source_sha256": {
                        "type": "string",
                        "pattern": r"^[0-9a-f]{64}$",
                    },
                    "size_bytes": {
                        "type": "integer",
                        "minimum": 1,
                    },
                    "imports": {
                        "$ref": "#/$defs/recordMultiset",
                    },
                    "members": {
                        "$ref": "#/$defs/recordMultiset",
                    },
                    "calls": {
                        "type": "array",
                        "uniqueItems": True,
                        "items": {"$ref": "#/$defs/callRecord"},
                    },
                },
            },
            "recordMultiset": {
                "type": "array",
                "uniqueItems": True,
                "items": {"$ref": "#/$defs/countRecord"},
            },
            "countRecord": {
                "type": "object",
                "additionalProperties": False,
                "required": ["record", "count"],
                "properties": {
                    "record": {
                        "type": "string",
                        "minLength": 1,
                    },
                    "count": {
                        "type": "integer",
                        "minimum": 1,
                    },
                },
            },
            "callRecord": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "target",
                    "shape",
                    "ast_sha256",
                    "count",
                ],
                "properties": {
                    "target": {
                        "type": "string",
                        "minLength": 1,
                    },
                    "shape": {
                        "type": "string",
                        "minLength": 1,
                    },
                    "ast_sha256": {
                        "type": "string",
                        "pattern": r"^[0-9a-f]{64}$",
                    },
                    "count": {
                        "type": "integer",
                        "minimum": 1,
                    },
                },
            },
        },
    }
    if schema != expected:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy schema differs from the exact "
            "independent closed-world schema"
        )


def _validate_release_tool_call_policy_paths(
    policy: dict[str, Any],
) -> None:
    """Reject non-canonical reviewed script path spellings independently."""

    rows = policy.get("reviewed_paths")
    if not isinstance(rows, list):
        return
    for index, row in enumerate(rows):
        path = row.get("path") if isinstance(row, dict) else None
        if (
            not isinstance(path, str)
            or re.fullmatch(RELEASE_TOOL_CALL_POLICY_PATH_PATTERN, path)
            is None
        ):
            raise ReleaseArtifactVerificationError(
                "release-tool call policy reviewed_paths"
                f"[{index}].path must be a normalized scripts/.../*.py path"
            )


def _require_index_binding(
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
    relative_path: str,
    *,
    label: str,
) -> None:
    snapshot = covered_file_snapshots.get(relative_path)
    if snapshot is None:
        raise ReleaseArtifactVerificationError(
            f"{label} is absent from the immutable covered-file snapshot"
        )
    checksum_matches = [
        digest
        for digest, path in checksum_bundle.checksum_entries
        if path == relative_path
    ]
    if len(checksum_matches) != 1:
        raise ReleaseArtifactVerificationError(
            f"{label} requires exactly one SHA256SUMS entry: "
            f"got {len(checksum_matches)}"
        )
    raw_files = checksum_bundle.checksum_manifest.get("files")
    if not isinstance(raw_files, list):
        raise ReleaseArtifactVerificationError(
            f"{label} requires release-checksums.json files"
        )
    manifest_matches = [
        require_dict(entry, f"{label}.release-checksums entry")
        for entry in raw_files
        if isinstance(entry, dict) and entry.get("path") == relative_path
    ]
    if len(manifest_matches) != 1:
        raise ReleaseArtifactVerificationError(
            f"{label} requires exactly one release-checksums.json entry: "
            f"got {len(manifest_matches)}"
        )
    if checksum_matches[0] != snapshot.sha256.removeprefix("sha256:"):
        raise ReleaseArtifactVerificationError(
            f"{label} SHA256SUMS hash mismatch"
        )
    manifest_record = manifest_matches[0]
    if manifest_record.get("sha256") != snapshot.sha256:
        raise ReleaseArtifactVerificationError(
            f"{label} release-checksums.json hash mismatch"
        )
    if manifest_record.get("size_bytes") != snapshot.size_bytes:
        raise ReleaseArtifactVerificationError(
            f"{label} release-checksums.json size mismatch"
        )


def verify_release_tool_call_policy(
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> tuple[str, ...]:
    """Reconstruct and enforce the closed-world 30-file policy independently."""

    _require_index_binding(
        checksum_bundle,
        covered_file_snapshots,
        RELEASE_TOOL_CALL_POLICY_PATH,
        label="release-tool call policy",
    )
    _require_index_binding(
        checksum_bundle,
        covered_file_snapshots,
        RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
        label="release-tool call policy schema",
    )
    expected_runtime_roots = [
        path.as_posix() for path in REVIEWED_RELEASE_TOOL_ROOTS
    ]
    roots_digest = hashlib.sha256(
        ("\n".join(expected_runtime_roots) + "\n").encode("utf-8")
    ).hexdigest()
    if (
        len(expected_runtime_roots) != 7
        or len(set(expected_runtime_roots)) != 7
        or roots_digest != REVIEWED_RELEASE_TOOL_ROOTS_SHA256
    ):
        raise ReleaseArtifactVerificationError(
            "release-tool roots differ from the independent pinned digest"
        )
    expected_external_modules = sorted(
        RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES
    )
    external_modules_digest = hashlib.sha256(
        ("\n".join(expected_external_modules) + "\n").encode("utf-8")
    ).hexdigest()
    if (
        len(expected_external_modules) != 31
        or external_modules_digest
        != REVIEWED_RELEASE_TOOL_EXTERNAL_MODULES_SHA256
    ):
        raise ReleaseArtifactVerificationError(
            "release-tool external-module literal differs from the "
            "independent pinned digest"
        )
    policy_snapshot = covered_file_snapshots[RELEASE_TOOL_CALL_POLICY_PATH]
    schema_snapshot = covered_file_snapshots[
        RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
    ]
    schema = _policy_json_object(
        schema_snapshot.data,
        label=RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
    )
    _validate_policy_schema_document(schema)
    actual = _policy_json_object(
        policy_snapshot.data,
        label=RELEASE_TOOL_CALL_POLICY_PATH,
    )
    canonical_text = json.dumps(
        actual,
        indent=2,
        ensure_ascii=False,
    )
    canonical = (canonical_text + "\n").encode("utf-8")
    if canonical != policy_snapshot.data:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy must use canonical JSON formatting"
        )
    _validate_release_tool_call_policy_paths(actual)
    if set(actual) != {
        "schema_version",
        "generator_version",
        "runtime_roots",
        "external_modules",
        "reviewed_paths",
    }:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy root keys mismatch"
        )
    if actual.get("schema_version") != RELEASE_TOOL_CALL_POLICY_SCHEMA:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy schema_version mismatch"
        )
    if actual.get("generator_version") != "1":
        raise ReleaseArtifactVerificationError(
            "release-tool call policy generator_version mismatch"
        )
    if actual.get("runtime_roots") != expected_runtime_roots:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy runtime roots differ from the "
            "independent exact seven-root literal"
        )
    if actual.get("external_modules") != expected_external_modules:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy external modules differ from the "
            "independent exact 31-module literal"
        )
    roles = {
        **{
            path.as_posix(): "runtime"
            for path in REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
        },
        **{
            path.as_posix(): "focused-test"
            for path in REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
        },
    }
    if len(roles) != 34:
        raise ReleaseArtifactVerificationError(
            "release-tool call policy requires exactly 24 runtime and 10 "
            "focused-test paths"
        )
    if (
        len(REVIEWED_RELEASE_TOOL_ROOTS) != 7
        or len(set(REVIEWED_RELEASE_TOOL_ROOTS)) != 7
        or any(
            root not in REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
            for root in REVIEWED_RELEASE_TOOL_ROOTS
        )
    ):
        raise ReleaseArtifactVerificationError(
            "release-tool roots differ from the independent exact seven-root "
            "literal"
        )
    expected_rows: list[dict[str, Any]] = []
    observed_imported_values: set[tuple[str, str, str, str]] = set()
    observed_imported_shadows: set[tuple[str, str, str, str]] = set()
    observed_external_modules: set[str] = set()
    dependency_graph: dict[Path, set[Path]] = {}
    for relative_path, role in sorted(roles.items()):
        snapshot = covered_file_snapshots.get(relative_path)
        if snapshot is None:
            raise ReleaseArtifactVerificationError(
                "release-tool call policy source is absent from immutable "
                f"snapshot: {relative_path}"
            )
        path = Path(relative_path)
        local_dependencies: set[Path] = set()
        expected_rows.append(
            _policy_row_from_snapshot(
                path,
                role,
                snapshot,
                imported_value_uses=observed_imported_values,
                imported_shadow_uses=observed_imported_shadows,
                local_dependencies=local_dependencies,
                observed_external_modules=observed_external_modules,
            )
        )
        dependency_graph[path] = local_dependencies
    pending = list(reversed(REVIEWED_RELEASE_TOOL_ROOTS))
    observed_runtime: set[Path] = set()
    while pending:
        path = pending.pop()
        if path in observed_runtime:
            continue
        observed_runtime.add(path)
        pending.extend(
            reversed(
                sorted(
                    dependency_graph.get(path, set()) - observed_runtime
                )
            )
        )
    expected_runtime = set(REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE)
    if observed_runtime != expected_runtime:
        missing = sorted(
            path.as_posix() for path in expected_runtime - observed_runtime
        )
        unexpected = sorted(
            path.as_posix() for path in observed_runtime - expected_runtime
        )
        raise ReleaseArtifactVerificationError(
            "release-tool snapshot runtime closure differs from the "
            f"independent exact role: missing={missing}; "
            f"unexpected={unexpected}"
        )
    if observed_external_modules != set(
        RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES
    ):
        missing = sorted(
            set(RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES)
            - observed_external_modules
        )
        unexpected = sorted(
            observed_external_modules
            - set(RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES)
        )
        raise ReleaseArtifactVerificationError(
            "release-tool external-module inventory differs from the "
            f"independent observed set: missing={missing}; "
            f"unexpected={unexpected}"
        )
    if observed_imported_values != set(
        RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST
    ):
        missing = sorted(
            set(RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST)
            - observed_imported_values
        )
        unexpected = sorted(
            observed_imported_values
            - set(RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST)
        )
        raise ReleaseArtifactVerificationError(
            "release-tool imported-value context inventory differs from the "
            f"exact literal allowlist: missing={missing}; "
            f"unexpected={unexpected}"
        )
    if observed_imported_shadows != set(
        RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST
    ):
        missing = sorted(
            set(RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST)
            - observed_imported_shadows
        )
        unexpected = sorted(
            observed_imported_shadows
            - set(RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST)
        )
        raise ReleaseArtifactVerificationError(
            "release-tool imported-shadow inventory differs from the exact "
            f"literal allowlist: missing={missing}; unexpected={unexpected}"
        )
    if actual.get("reviewed_paths") != expected_rows:
        actual_rows_value = actual.get("reviewed_paths")
        actual_rows = (
            {
                row.get("path"): row
                for row in actual_rows_value
                if isinstance(row, dict) and isinstance(row.get("path"), str)
            }
            if isinstance(actual_rows_value, list)
            else {}
        )
        expected_by_path = {row["path"]: row for row in expected_rows}
        missing = sorted(set(expected_by_path) - set(actual_rows))
        unexpected = sorted(set(actual_rows) - set(expected_by_path))
        changed = sorted(
            path
            for path in set(expected_by_path) & set(actual_rows)
            if expected_by_path[path] != actual_rows[path]
        )
        raise ReleaseArtifactVerificationError(
            "release-tool call policy differs from verifier reconstruction: "
            f"missing={missing}; unexpected={unexpected}; changed={changed}"
        )
    return tuple(sorted(roles))


def verify_release_tool_trust_bindings(
    repo_root: Path,
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> tuple[str, ...]:
    """Independently enforce canonical release-tool trust in both indexes."""

    checksum_entries = checksum_bundle.checksum_entries
    checksum_entries_by_path: dict[str, list[str]] = {}
    for digest, path in checksum_entries:
        checksum_entries_by_path.setdefault(path, []).append(digest)

    data = checksum_bundle.checksum_manifest
    source = require_dict(data.get("source"), "release-checksums.source")
    if (
        source.get("coverage_policy")
        != CANONICAL_COVERAGE_POLICY
    ):
        raise ReleaseArtifactVerificationError(
            "release-tool trust bindings require canonical coverage_policy"
        )
    raw_covered_paths = source.get("covered_paths")
    if not isinstance(raw_covered_paths, list) or not all(
        isinstance(path, str) and path
        for path in raw_covered_paths
    ):
        raise ReleaseArtifactVerificationError(
            "release-tool trust bindings require string source.covered_paths"
        )
    for required_path in (
        REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
        + REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
        + (RISK_SIZE_CHECKER_PATH,)
    ):
        relative_path = required_path.as_posix()
        if relative_path not in covered_file_snapshots:
            raise ReleaseArtifactVerificationError(
                "release-tool reviewed source is absent from the canonical "
                f"snapshot: {relative_path}"
            )
    verify_reviewed_subprocess_source_bindings(covered_file_snapshots)
    verify_release_tool_call_policy(
        checksum_bundle,
        covered_file_snapshots,
    )
    for relative_path in RECORD_FAMILY_AUTHORIZATION_SEMANTIC_SOURCE_PATHS:
        _require_index_binding(
            checksum_bundle,
            covered_file_snapshots,
            relative_path,
            label=(
                "record-family authorization semantic source "
                f"{relative_path}"
            ),
        )

    raw_files = data.get("files")
    if not isinstance(raw_files, list):
        raise ReleaseArtifactVerificationError(
            "release-tool trust bindings require checksum manifest files"
        )
    manifest_entries_by_path: dict[str, list[dict[str, Any]]] = {}
    for index, raw_entry in enumerate(raw_files):
        entry = require_dict(
            raw_entry,
            f"release-checksums.files[{index}]",
        )
        path = require_string(
            entry.get("path"),
            f"release-checksums.files[{index}].path",
        )
        manifest_entries_by_path.setdefault(path, []).append(entry)

    required_paths = tuple(
        sorted(
            set(REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE).union(
                REVIEWED_RELEASE_TOOL_FOCUSED_TESTS
            ).union({RISK_SIZE_CHECKER_PATH})
        )
    )
    for required_path in required_paths:
        relative_path = required_path.as_posix()
        checksum_matches = checksum_entries_by_path.get(relative_path, [])
        if len(checksum_matches) != 1:
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding requires exactly one SHA256SUMS "
                f"entry for {relative_path}: got {len(checksum_matches)}"
            )
        manifest_matches = manifest_entries_by_path.get(relative_path, [])
        if len(manifest_matches) != 1:
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding requires exactly one "
                f"release-checksums.json entry for {relative_path}: "
                f"got {len(manifest_matches)}"
            )

        snapshot = covered_file_snapshots.get(relative_path)
        if snapshot is None:
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding is absent from the immutable "
                f"covered-file snapshot: {relative_path}"
            )
        expected_hash = snapshot.sha256
        expected_size = snapshot.size_bytes
        if checksum_matches[0] != expected_hash.removeprefix("sha256:"):
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding SHA256SUMS hash mismatch for "
                f"{relative_path}"
            )
        manifest_entry = manifest_matches[0]
        if manifest_entry.get("sha256") != expected_hash:
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding release-checksums.json hash "
                f"mismatch for {relative_path}"
            )
        if manifest_entry.get("size_bytes") != expected_size:
            raise ReleaseArtifactVerificationError(
                "release-tool trust binding release-checksums.json size "
                f"mismatch for {relative_path}"
            )
    return tuple(path.as_posix() for path in required_paths)


def verify_record_family_inventory_schema_checksum_bindings(
    repo_root: Path,
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    """Independently require the canonical #690 inventory schema in both indexes."""

    del repo_root
    relative_path = RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH
    snapshot = covered_file_snapshots.get(relative_path)
    if snapshot is None:
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            "is absent from the immutable covered-file snapshot: "
            f"{relative_path}"
        )
    expected_hash = snapshot.sha256
    expected_size = snapshot.size_bytes

    checksum_matches = [
        digest
        for digest, path in checksum_bundle.checksum_entries
        if path == relative_path
    ]
    if len(checksum_matches) != 1:
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            "requires exactly one SHA256SUMS entry for "
            f"{relative_path}: got {len(checksum_matches)}"
        )
    if checksum_matches[0] != expected_hash.removeprefix("sha256:"):
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            f"SHA256SUMS hash mismatch for {relative_path}"
        )

    checksum_manifest = checksum_bundle.checksum_manifest
    raw_files = checksum_manifest.get("files")
    if not isinstance(raw_files, list):
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            "requires checksum manifest files"
        )
    manifest_matches: list[dict[str, Any]] = []
    for index, raw_entry in enumerate(raw_files):
        entry = require_dict(
            raw_entry,
            f"release-checksums.files[{index}]",
        )
        path = require_string(
            entry.get("path"),
            f"release-checksums.files[{index}].path",
        )
        if path == relative_path:
            manifest_matches.append(entry)
    if len(manifest_matches) != 1:
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            "requires exactly one release-checksums.json entry for "
            f"{relative_path}: got {len(manifest_matches)}"
        )
    manifest_entry = manifest_matches[0]
    if manifest_entry.get("sha256") != expected_hash:
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            f"release-checksums.json hash mismatch for {relative_path}"
        )
    if manifest_entry.get("size_bytes") != expected_size:
        raise ReleaseArtifactVerificationError(
            "record-family authorization inventory-schema checksum binding "
            f"release-checksums.json size mismatch for {relative_path}"
        )


def verify_release_directory_checksum_closure(
    repo_root: Path,
    release_dir: Path,
    checksum_entries: dict[str, str],
) -> int:
    if not release_dir.is_dir():
        raise ReleaseArtifactVerificationError(f"missing release artifact directory: {release_dir}")

    allowed_uncovered = {
        normalize_path(release_dir / name, repo_root)
        for name in ALLOWED_UNCHECKSUMMED_RELEASE_FILES
    }
    checked_files = 0
    unchecksummed = []
    for path in sorted(release_dir.rglob("*")):
        if path.is_symlink():
            try:
                relative_path = path.relative_to(repo_root).as_posix()
            except ValueError:
                relative_path = path.as_posix()
            raise ReleaseArtifactVerificationError(
                f"release artifact directory contains symlink: {relative_path}"
            )
        if not path.is_file():
            continue
        relative_path = normalize_path(path, repo_root)
        if relative_path in allowed_uncovered:
            continue
        checked_files += 1
        if relative_path not in checksum_entries:
            unchecksummed.append(relative_path)

    if unchecksummed:
        raise ReleaseArtifactVerificationError(
            "release artifact directory contains unchecksummed file(s): "
            + ", ".join(unchecksummed[:5])
        )
    return checked_files


def verify_checksum_manifest(
    repo_root: Path,
    checksum_entries: dict[str, str],
    checksum_bundle: ChecksumBundleSnapshot,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> int:
    data = checksum_bundle.checksum_manifest
    if data.get("algorithm") != "sha256":
        raise ReleaseArtifactVerificationError("release checksum manifest must use sha256")

    checksum_record = require_dict(
        data.get("text_checksum_file"),
        "release-checksums.text_checksum_file",
    )
    checksum_record_path = require_string(
        checksum_record.get("path"),
        "release-checksums.text_checksum_file.path",
    )
    if checksum_bundle.checksum_file_path != checksum_record_path:
        raise ReleaseArtifactVerificationError("release checksum manifest SHA256SUMS path mismatch")
    if checksum_record.get("sha256") != checksum_bundle.checksum_file_sha256:
        raise ReleaseArtifactVerificationError("release checksum manifest SHA256SUMS hash mismatch")

    manifest_record = require_dict(
        data.get("manifest_file"),
        "release-checksums.manifest_file",
    )
    if (
        manifest_record.get("path")
        != checksum_bundle.checksum_manifest_path
    ):
        raise ReleaseArtifactVerificationError(
            "release checksum manifest self path mismatch"
        )
    if manifest_record.get("self_hash") is not False:
        raise ReleaseArtifactVerificationError(
            "release checksum manifest self_hash must be false"
        )

    files = data.get("files")
    if not isinstance(files, list) or not files:
        raise ReleaseArtifactVerificationError("release checksum manifest files must be non-empty")

    manifest_entries: dict[str, dict[str, Any]] = {}
    for index, raw_entry in enumerate(files):
        entry = require_dict(raw_entry, f"release-checksums.files[{index}]")
        path = require_string(entry.get("path"), f"release-checksums.files[{index}].path")
        sha256 = require_string(entry.get("sha256"), f"release-checksums.files[{index}].sha256")
        size = entry.get("size_bytes")
        if not isinstance(size, int) or isinstance(size, bool):
            raise ReleaseArtifactVerificationError(
                f"release-checksums.files[{index}].size_bytes must be an integer"
            )
        if path in manifest_entries:
            raise ReleaseArtifactVerificationError(
                f"release checksum manifest has duplicate path {path}"
            )
        manifest_entries[path] = entry
        verify_file_record(
            repo_root,
            path=path,
            sha256=sha256,
            size_bytes=size,
            source="release-checksums",
            covered_file_snapshots=covered_file_snapshots,
        )

    if set(manifest_entries) != set(checksum_entries):
        missing = sorted(set(checksum_entries) - set(manifest_entries))
        extra = sorted(set(manifest_entries) - set(checksum_entries))
        detail = []
        if missing:
            detail.append(f"missing manifest records: {', '.join(missing[:5])}")
        if extra:
            detail.append(f"extra manifest records: {', '.join(extra[:5])}")
        raise ReleaseArtifactVerificationError(
            "release checksum manifest does not match SHA256SUMS"
            + (f" ({'; '.join(detail)})" if detail else "")
        )

    for path, digest in checksum_entries.items():
        if manifest_entries[path]["sha256"] != f"sha256:{digest}":
            raise ReleaseArtifactVerificationError(
                f"release checksum manifest hash mismatch for {path}"
            )
    return len(manifest_entries)


def iter_file_records(value: Any, source: str) -> Iterable[tuple[str, str, int | None, str]]:
    if isinstance(value, dict):
        path = value.get("path")
        sha256 = value.get("sha256")
        size_bytes = value.get("size_bytes")
        if isinstance(path, str) and "sha256" in value:
            if not isinstance(sha256, str):
                raise ReleaseArtifactVerificationError(f"{source}.sha256 must be a string")
            if not SHA256_PREFIX_RE.fullmatch(sha256):
                if sha256 not in SELF_REFERENTIAL_SHA256_MARKERS:
                    raise ReleaseArtifactVerificationError(
                        f"{source}.sha256 has invalid sha256 marker for {path}"
                    )
            else:
                if size_bytes is None:
                    yield path, sha256, None, source
                elif isinstance(size_bytes, int) and not isinstance(size_bytes, bool):
                    yield path, sha256, size_bytes, source
                else:
                    raise ReleaseArtifactVerificationError(
                        f"{source}.size_bytes must be an integer when present"
                    )
        for key, child in value.items():
            yield from iter_file_records(child, f"{source}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from iter_file_records(child, f"{source}[{index}]")


def require_checksum_record(
    checksum_entries: dict[str, str],
    *,
    path: str,
    sha256: str,
    source: str,
) -> None:
    """Require a nested file record to be present in SHA256SUMS."""
    if not SHA256_PREFIX_RE.fullmatch(sha256):
        raise ReleaseArtifactVerificationError(
            f"{source}.sha256 has invalid sha256 marker for {path}"
        )
    # Nested file records are release inputs too; adding one requires matching
    # coverage in SHA256SUMS so third-party verifiers have one canonical bundle.
    expected = sha256.removeprefix("sha256:")
    actual = checksum_entries.get(path)
    if actual is None:
        raise ReleaseArtifactVerificationError(
            f"{source} references file not covered by {CHECKSUM_FILE_NAME}: {path}"
        )
    if actual != expected:
        raise ReleaseArtifactVerificationError(
            f"{source} checksum hash mismatch for {path}: "
            f"record has {sha256}, {CHECKSUM_FILE_NAME} has sha256:{actual}"
        )


def verify_nested_file_records(
    repo_root: Path,
    document: Any,
    source: str,
    checksum_entries: dict[str, str],
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> int:
    count = 0
    for path, sha256, size_bytes, field in iter_file_records(document, source):
        verify_file_record(
            repo_root,
            path=path,
            sha256=sha256,
            size_bytes=size_bytes,
            source=field,
            covered_file_snapshots=covered_file_snapshots,
        )
        require_checksum_record(
            checksum_entries,
            path=path,
            sha256=sha256,
            source=field,
        )
        count += 1
    return count


def require_checksum_covered(checksum_entries: dict[str, str], required_paths: Sequence[str]) -> None:
    missing = [path for path in required_paths if path not in checksum_entries]
    if missing:
        raise ReleaseArtifactVerificationError(
            f"required files are not checksum-covered: {', '.join(missing)}"
        )


def verify_governed_parameter_inventory_bindings(
    release_manifest: dict[str, Any],
    release_candidate_lockfile: dict[str, Any],
) -> None:
    """Require both release documents to bind the same canonical inventory."""
    release_artifacts = require_dict(
        release_manifest.get("release_artifacts"),
        "release-manifest.release_artifacts",
    )
    locked_inputs = require_dict(
        release_candidate_lockfile.get("locked_inputs"),
        "release-candidate-lockfile.locked_inputs",
    )
    manifest_record = require_dict(
        release_artifacts.get("governed_parameter_inventory"),
        "release-manifest.release_artifacts.governed_parameter_inventory",
    )
    lockfile_record = require_dict(
        locked_inputs.get("governed_parameter_inventory"),
        "release-candidate-lockfile.locked_inputs.governed_parameter_inventory",
    )

    for source, record in (
        ("release-manifest", manifest_record),
        ("release-candidate-lockfile", lockfile_record),
    ):
        if record.get("path") != GOVERNED_PARAMETER_INVENTORY_PATH:
            raise ReleaseArtifactVerificationError(
                f"{source} governed-parameter inventory path must be "
                f"{GOVERNED_PARAMETER_INVENTORY_PATH}"
            )
        if record.get("schema_version") != GOVERNED_PARAMETER_INVENTORY_SCHEMA:
            raise ReleaseArtifactVerificationError(
                f"{source} governed-parameter inventory must use schema "
                f"{GOVERNED_PARAMETER_INVENTORY_SCHEMA}"
            )
        require_string(
            record.get("sha256"),
            f"{source}.governed_parameter_inventory.sha256",
        )
        size_bytes = record.get("size_bytes")
        if (
            isinstance(size_bytes, bool)
            or not isinstance(size_bytes, int)
            or size_bytes < 0
        ):
            raise ReleaseArtifactVerificationError(
                f"{source}.governed_parameter_inventory.size_bytes must be "
                "a non-negative integer"
            )

    for field in ("path", "sha256", "size_bytes", "schema_version"):
        if manifest_record[field] != lockfile_record[field]:
            raise ReleaseArtifactVerificationError(
                "release manifest and release-candidate lockfile governed-parameter "
                f"inventory {field} values do not match"
            )


def validate_governed_parameter_inventory_semantics(
    repo_root: Path,
    checker: Any,
) -> dict[str, Any]:
    """Run the canonical ordinary semantic validator for offline consumers."""
    try:
        return checker.validate_inventory(
            repo_root,
            Path(GOVERNED_PARAMETER_INVENTORY_PATH),
            require_complete=False,
        )
    except Exception as exc:
        raise ReleaseArtifactVerificationError(
            f"governed-parameter inventory semantic validation failed: {exc}"
        ) from exc


def validate_record_family_authorization_semantics(
    repo_root: Path,
    checker: Any,
) -> None:
    """Run the canonical planning-package validator for offline consumers."""
    try:
        checker.validate_package(repo_root)
    except Exception as exc:
        raise ReleaseArtifactVerificationError(
            f"record-family authorization semantic validation failed: {exc}"
        ) from exc


def validate_artist_semantic_owner_matrix_semantics(
    repo_root: Path,
    checker: Any,
) -> None:
    """Run the Proposed artist-owner validator for offline consumers."""
    try:
        checker.check(repo_root)
    except Exception as exc:
        raise ReleaseArtifactVerificationError(
            f"artist semantic-owner matrix validation failed: {exc}"
        ) from exc


def _load_snapshot_checker(
    snapshot_root: Path,
    module_name: str,
) -> Any:
    """Load one already policy-validated checker from materialized bound bytes."""

    # importlib is deliberately imported only after release-tool policy
    # validation. The loaded filename is a fixed literal caller argument and
    # points into the immutable materialization, never the live checkout.
    import importlib.util

    relative_source = SNAPSHOT_CHECKER_MODULE_PATHS.get(module_name)
    if relative_source is None:
        raise ReleaseArtifactVerificationError(
            f"unreviewed snapshot checker module: {module_name}"
        )
    dependency_paths = SNAPSHOT_CHECKER_DEPENDENCY_PATHS[module_name]
    source_path = snapshot_root / relative_source
    spec = importlib.util.spec_from_file_location(
        f"_release_snapshot_{module_name}",
        source_path,
    )
    if spec is None or spec.loader is None:
        raise ReleaseArtifactVerificationError(
            f"cannot load validated snapshot checker: {module_name}"
        )
    module = importlib.util.module_from_spec(spec)
    scripts_path = str(snapshot_root / "scripts")
    original_path = list(sys.path)
    original_modules = set(sys.modules)
    prior_dependencies = {
        dependency_name: sys.modules[dependency_name]
        for dependency_name in dependency_paths
        if dependency_name in sys.modules
    }
    for dependency_name in dependency_paths:
        sys.modules.pop(dependency_name, None)
    sys.path.insert(0, scripts_path)
    try:
        try:
            spec.loader.exec_module(module)
        except Exception as exc:
            raise ReleaseArtifactVerificationError(
                f"cannot execute validated snapshot checker {module_name}: {exc}"
            ) from exc

        snapshot_root_resolved = snapshot_root.resolve(strict=True)
        for dependency_name, dependency_relative_path in dependency_paths.items():
            dependency_module = sys.modules.get(dependency_name)
            dependency_file = getattr(dependency_module, "__file__", None)
            if not isinstance(dependency_file, str):
                raise ReleaseArtifactVerificationError(
                    "validated snapshot checker did not load exact dependency "
                    f"{dependency_name}"
                )
            try:
                dependency_resolved = Path(dependency_file).resolve(strict=True)
                expected_resolved = (
                    snapshot_root / dependency_relative_path
                ).resolve(strict=True)
            except OSError as exc:
                raise ReleaseArtifactVerificationError(
                    "validated snapshot checker dependency path is unreadable: "
                    f"{dependency_name}"
                ) from exc
            if (
                dependency_resolved != expected_resolved
                or dependency_resolved.parent.parent != snapshot_root_resolved
            ):
                raise ReleaseArtifactVerificationError(
                    "validated snapshot checker dependency escaped the exact "
                    f"materialized source: {dependency_name}"
                )

        for loaded_name in set(sys.modules) - original_modules:
            if loaded_name in dependency_paths:
                continue
            loaded_module = sys.modules.get(loaded_name)
            loaded_file = getattr(loaded_module, "__file__", None)
            if not isinstance(loaded_file, str):
                continue
            try:
                Path(loaded_file).resolve(strict=True).relative_to(
                    snapshot_root_resolved
                )
            except (OSError, ValueError):
                continue
            raise ReleaseArtifactVerificationError(
                "validated snapshot checker loaded an unreviewed materialized "
                f"module: {loaded_name}"
            )
    finally:
        sys.path[:] = original_path
        for dependency_name in dependency_paths:
            sys.modules.pop(dependency_name, None)
        for dependency_name, dependency_module in prior_dependencies.items():
            sys.modules[dependency_name] = dependency_module
        for loaded_name in set(sys.modules) - original_modules:
            loaded_module = sys.modules.get(loaded_name)
            loaded_file = getattr(loaded_module, "__file__", None)
            if not isinstance(loaded_file, str):
                continue
            try:
                Path(loaded_file).resolve().relative_to(
                    snapshot_root.resolve()
                )
            except (OSError, ValueError):
                continue
            sys.modules.pop(loaded_name, None)
    return module


def validate_bound_snapshot_semantics(
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> dict[str, Any]:
    """Run canonical semantic validators against only bound snapshot bytes."""

    with tempfile.TemporaryDirectory() as temp_dir:
        snapshot_root = Path(temp_dir)
        _materialize_covered_file_snapshots(
            snapshot_root,
            covered_file_snapshots,
        )
        governed_parameter_checker = _load_snapshot_checker(
            snapshot_root,
            "check_governed_parameter_inventory",
        )
        record_family_checker = _load_snapshot_checker(
            snapshot_root,
            "check_record_family_authorization",
        )
        artist_semantic_owner_checker = _load_snapshot_checker(
            snapshot_root,
            "check_artist_semantic_owner_matrix",
        )
        governed_parameter_inventory = (
            validate_governed_parameter_inventory_semantics(
                snapshot_root,
                governed_parameter_checker,
            )
        )
        validate_record_family_authorization_semantics(
            snapshot_root,
            record_family_checker,
        )
        validate_artist_semantic_owner_matrix_semantics(
            snapshot_root,
            artist_semantic_owner_checker,
        )
    return governed_parameter_inventory


def _require_exact_file_record(
    record: dict[str, Any],
    *,
    source: str,
    expected_path: str,
    expected_schema: str | None,
    expected_fields: dict[str, str] | None = None,
) -> None:
    expected_fields = expected_fields or {}
    expected_keys = {"path", "sha256", "size_bytes", *expected_fields}
    if expected_schema is not None:
        expected_keys.add("schema_version")
    if set(record) != expected_keys:
        raise ReleaseArtifactVerificationError(
            f"{source} keys must be exactly {', '.join(sorted(expected_keys))}"
        )
    if record.get("path") != expected_path:
        raise ReleaseArtifactVerificationError(
            f"{source} path must be {expected_path}"
        )
    if expected_schema is not None and record.get("schema_version") != expected_schema:
        raise ReleaseArtifactVerificationError(
            f"{source} must use schema {expected_schema}"
        )
    sha256 = require_string(record.get("sha256"), f"{source}.sha256")
    if not SHA256_PREFIX_RE.fullmatch(sha256):
        raise ReleaseArtifactVerificationError(
            f"{source}.sha256 must be a canonical sha256: digest"
        )
    size_bytes = record.get("size_bytes")
    if isinstance(size_bytes, bool) or not isinstance(size_bytes, int) or size_bytes < 0:
        raise ReleaseArtifactVerificationError(
            f"{source}.size_bytes must be a non-negative integer"
        )
    for field, expected_value in expected_fields.items():
        if record.get(field) != expected_value:
            raise ReleaseArtifactVerificationError(
                f"{source}.{field} must be {expected_value}"
            )


def verify_artist_semantic_owner_matrix_bindings(
    release_manifest: dict[str, Any],
) -> None:
    """Require the manifest to bind the exact Proposed #670 packet."""
    release_artifacts = require_dict(
        release_manifest.get("release_artifacts"),
        "release-manifest.release_artifacts",
    )
    package = require_dict(
        release_artifacts.get("artist_semantic_owner_matrix"),
        "release-manifest.release_artifacts.artist_semantic_owner_matrix",
    )
    if set(package) != {"matrix", "schema"}:
        raise ReleaseArtifactVerificationError(
            "release-manifest artist semantic-owner package keys must be "
            "exactly matrix, schema"
        )
    _require_exact_file_record(
        require_dict(
            package.get("matrix"),
            "release-manifest artist semantic-owner matrix",
        ),
        source="release-manifest artist semantic-owner matrix",
        expected_path=ARTIST_SEMANTIC_OWNER_MATRIX_PATH,
        expected_schema=ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA,
        expected_fields={
            "status": ARTIST_SEMANTIC_OWNER_MATRIX_STATUS,
            "maturity": ARTIST_SEMANTIC_OWNER_MATRIX_MATURITY,
        },
    )
    _require_exact_file_record(
        require_dict(
            package.get("schema"),
            "release-manifest artist semantic-owner schema",
        ),
        source="release-manifest artist semantic-owner schema",
        expected_path=ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA_PATH,
        expected_schema=JSON_SCHEMA_DRAFT,
        expected_fields={
            "schema_id": ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA_ID,
            "document_schema_version": ARTIST_SEMANTIC_OWNER_MATRIX_SCHEMA,
        },
    )


def verify_release_tool_call_policy_bindings(
    release_manifest: dict[str, Any],
    release_candidate_lockfile: dict[str, Any],
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    """Require manifest and lockfile to bind the validated policy and schema."""

    release_artifacts = require_dict(
        release_manifest.get("release_artifacts"),
        "release-manifest.release_artifacts",
    )
    locked_inputs = require_dict(
        release_candidate_lockfile.get("locked_inputs"),
        "release-candidate-lockfile.locked_inputs",
    )
    manifest_group = require_dict(
        release_artifacts.get("release_tool_call_policy"),
        "release-manifest.release_artifacts.release_tool_call_policy",
    )
    manifest_policy = require_dict(
        manifest_group.get("policy"),
        "release-manifest.release_tool_call_policy.policy",
    )
    manifest_schema = require_dict(
        manifest_group.get("schema"),
        "release-manifest.release_tool_call_policy.schema",
    )
    lock_policy = require_dict(
        locked_inputs.get("release_tool_call_policy"),
        "release-candidate-lockfile.release_tool_call_policy",
    )
    lock_schema = require_dict(
        locked_inputs.get("release_tool_call_policy_schema"),
        "release-candidate-lockfile.release_tool_call_policy_schema",
    )
    _require_exact_file_record(
        manifest_policy,
        source="release-manifest.release_tool_call_policy.policy",
        expected_path=RELEASE_TOOL_CALL_POLICY_PATH,
        expected_schema=RELEASE_TOOL_CALL_POLICY_SCHEMA,
    )
    _require_exact_file_record(
        lock_policy,
        source="release-candidate-lockfile.release_tool_call_policy",
        expected_path=RELEASE_TOOL_CALL_POLICY_PATH,
        expected_schema=RELEASE_TOOL_CALL_POLICY_SCHEMA,
    )
    schema_fields = {
        "schema_id": RELEASE_TOOL_CALL_POLICY_SCHEMA_ID,
        "document_schema_version": RELEASE_TOOL_CALL_POLICY_SCHEMA,
    }
    _require_exact_file_record(
        manifest_schema,
        source="release-manifest.release_tool_call_policy.schema",
        expected_path=RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
        expected_schema=JSON_SCHEMA_DRAFT,
        expected_fields=schema_fields,
    )
    _require_exact_file_record(
        lock_schema,
        source="release-candidate-lockfile.release_tool_call_policy_schema",
        expected_path=RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
        expected_schema=JSON_SCHEMA_DRAFT,
        expected_fields=schema_fields,
    )
    if manifest_policy != lock_policy:
        raise ReleaseArtifactVerificationError(
            "release manifest and release-candidate lockfile release-tool "
            "call policy records do not match"
        )
    if manifest_schema != lock_schema:
        raise ReleaseArtifactVerificationError(
            "release manifest and release-candidate lockfile release-tool "
            "call policy schema records do not match"
        )
    for label, record in (
        ("release-tool call policy", manifest_policy),
        ("release-tool call policy schema", manifest_schema),
    ):
        snapshot = covered_file_snapshots.get(record["path"])
        if snapshot is None:
            raise ReleaseArtifactVerificationError(
                f"{label} binding is absent from immutable snapshot"
            )
        if (
            record["sha256"] != snapshot.sha256
            or record["size_bytes"] != snapshot.size_bytes
        ):
            raise ReleaseArtifactVerificationError(
                f"{label} manifest/lock binding differs from immutable snapshot"
            )


def verify_record_family_authorization_bindings(
    release_manifest: dict[str, Any],
    release_candidate_lockfile: dict[str, Any],
) -> None:
    """Require the manifest and lockfile to bind the canonical #690 inputs."""
    release_artifacts = require_dict(
        release_manifest.get("release_artifacts"),
        "release-manifest.release_artifacts",
    )
    locked_inputs = require_dict(
        release_candidate_lockfile.get("locked_inputs"),
        "release-candidate-lockfile.locked_inputs",
    )
    manifest_group = require_dict(
        release_artifacts.get("record_family_authorization"),
        "release-manifest.release_artifacts.record_family_authorization",
    )
    expected_manifest_keys = {
        "source_catalog",
        "source_catalog_schema",
        "inventory",
        "inventory_schema",
        "evidence_schema",
        "grant_map_schema",
        "evidence_template",
    }
    if set(manifest_group) != expected_manifest_keys:
        raise ReleaseArtifactVerificationError(
            "release-manifest record-family authorization keys must be exactly "
            "source_catalog, source_catalog_schema, inventory, "
            "inventory_schema, evidence_schema, grant_map_schema, and "
            "evidence_template"
        )

    manifest_source_catalog = require_dict(
        manifest_group.get("source_catalog"),
        "release-manifest.record_family_authorization.source_catalog",
    )
    manifest_source_catalog_schema = require_dict(
        manifest_group.get("source_catalog_schema"),
        "release-manifest.record_family_authorization.source_catalog_schema",
    )
    manifest_inventory = require_dict(
        manifest_group.get("inventory"),
        "release-manifest.record_family_authorization.inventory",
    )
    manifest_inventory_schema = require_dict(
        manifest_group.get("inventory_schema"),
        "release-manifest.record_family_authorization.inventory_schema",
    )
    manifest_schema = require_dict(
        manifest_group.get("evidence_schema"),
        "release-manifest.record_family_authorization.evidence_schema",
    )
    manifest_template = require_dict(
        manifest_group.get("evidence_template"),
        "release-manifest.record_family_authorization.evidence_template",
    )
    manifest_grant_map_schema = require_dict(
        manifest_group.get("grant_map_schema"),
        "release-manifest.record_family_authorization.grant_map_schema",
    )
    lock_inventory = require_dict(
        locked_inputs.get("record_family_authorization_inventory"),
        "release-candidate-lockfile.record_family_authorization_inventory",
    )
    lock_source_catalog = require_dict(
        locked_inputs.get("record_family_authorization_source_catalog"),
        "release-candidate-lockfile.record_family_authorization_source_catalog",
    )
    lock_source_catalog_schema = require_dict(
        locked_inputs.get("record_family_authorization_source_catalog_schema"),
        "release-candidate-lockfile."
        "record_family_authorization_source_catalog_schema",
    )
    lock_inventory_schema = require_dict(
        locked_inputs.get("record_family_authorization_inventory_schema"),
        "release-candidate-lockfile.record_family_authorization_inventory_schema",
    )
    lock_schema = require_dict(
        locked_inputs.get("record_family_authorization_evidence_schema"),
        "release-candidate-lockfile.record_family_authorization_evidence_schema",
    )
    lock_template = require_dict(
        locked_inputs.get("record_family_authorization_evidence_template"),
        "release-candidate-lockfile.record_family_authorization_evidence_template",
    )
    lock_grant_map_schema = require_dict(
        locked_inputs.get("record_family_authorization_grant_map_schema"),
        "release-candidate-lockfile.record_family_authorization_grant_map_schema",
    )

    _require_exact_file_record(
        manifest_source_catalog,
        source="release-manifest record-family authorization source catalog",
        expected_path=RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA,
    )
    _require_exact_file_record(
        lock_source_catalog,
        source=(
            "release-candidate-lockfile record-family authorization "
            "source catalog"
        ),
        expected_path=RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA,
    )
    for source, record in (
        (
            "release-manifest record-family authorization source-catalog schema",
            manifest_source_catalog_schema,
        ),
        (
            "release-candidate-lockfile record-family authorization "
            "source-catalog schema",
            lock_source_catalog_schema,
        ),
    ):
        _require_exact_file_record(
            record,
            source=source,
            expected_path=RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_PATH,
            expected_schema=JSON_SCHEMA_DRAFT,
            expected_fields={
                "schema_id": RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA_ID,
                "document_schema_version": (
                    RECORD_FAMILY_AUTHORIZATION_SOURCE_CATALOG_SCHEMA
                ),
            },
        )

    _require_exact_file_record(
        manifest_inventory,
        source="release-manifest record-family authorization inventory",
        expected_path=RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA,
    )
    _require_exact_file_record(
        lock_inventory,
        source="release-candidate-lockfile record-family authorization inventory",
        expected_path=RECORD_FAMILY_AUTHORIZATION_INVENTORY_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA,
    )
    for source, record in (
        (
            "release-manifest record-family authorization inventory schema",
            manifest_inventory_schema,
        ),
        (
            "release-candidate-lockfile record-family authorization inventory schema",
            lock_inventory_schema,
        ),
    ):
        _require_exact_file_record(
            record,
            source=source,
            expected_path=RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_PATH,
            expected_schema=JSON_SCHEMA_DRAFT,
            expected_fields={
                "schema_id": RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA_ID,
                "document_schema_version": (
                    RECORD_FAMILY_AUTHORIZATION_INVENTORY_SCHEMA
                ),
            },
        )
    for source, record in (
        (
            "release-manifest record-family authorization evidence schema",
            manifest_schema,
        ),
        (
            "release-candidate-lockfile record-family authorization evidence schema",
            lock_schema,
        ),
    ):
        _require_exact_file_record(
            record,
            source=source,
            expected_path=RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_PATH,
            expected_schema=JSON_SCHEMA_DRAFT,
            expected_fields={
                "schema_id": RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA_ID,
                "document_schema_version": (
                    RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA
                ),
            },
        )
    _require_exact_file_record(
        manifest_template,
        source="release-manifest record-family authorization evidence template",
        expected_path=RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA,
    )
    _require_exact_file_record(
        lock_template,
        source="release-candidate-lockfile record-family authorization evidence template",
        expected_path=RECORD_FAMILY_AUTHORIZATION_EVIDENCE_TEMPLATE_PATH,
        expected_schema=RECORD_FAMILY_AUTHORIZATION_EVIDENCE_SCHEMA,
    )
    for source, record in (
        (
            "release-manifest record-family authorization grant-map schema",
            manifest_grant_map_schema,
        ),
        (
            "release-candidate-lockfile record-family authorization grant-map schema",
            lock_grant_map_schema,
        ),
    ):
        _require_exact_file_record(
            record,
            source=source,
            expected_path=RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_PATH,
            expected_schema=JSON_SCHEMA_DRAFT,
            expected_fields={
                "schema_id": RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA_ID,
                "document_schema_version": (
                    RECORD_FAMILY_AUTHORIZATION_GRANT_MAP_SCHEMA
                ),
            },
        )
    for label, manifest_record, lock_record in (
        ("source catalog", manifest_source_catalog, lock_source_catalog),
        (
            "source-catalog schema",
            manifest_source_catalog_schema,
            lock_source_catalog_schema,
        ),
        ("inventory", manifest_inventory, lock_inventory),
        (
            "inventory schema",
            manifest_inventory_schema,
            lock_inventory_schema,
        ),
        ("evidence schema", manifest_schema, lock_schema),
        ("evidence template", manifest_template, lock_template),
        ("grant-map schema", manifest_grant_map_schema, lock_grant_map_schema),
    ):
        if manifest_record != lock_record:
            raise ReleaseArtifactVerificationError(
                "release manifest and release-candidate lockfile record-family "
                f"authorization {label} records do not match"
            )


def verify_governed_parameter_reference_checksum_coverage(
    repo_root: Path,
    inventory: dict[str, Any],
    checksum_entries: dict[str, str],
) -> None:
    """Require every complete candidate/evidence file in the checksum bundle."""
    del repo_root
    references = _independent_complete_reference_bindings(inventory)
    for path, recorded_sha256, source in references:
        relative_path = path.as_posix()
        bundled_sha256 = checksum_entries.get(relative_path)
        if bundled_sha256 is None:
            raise ReleaseArtifactVerificationError(
                f"{source} complete reference is not covered by "
                f"{CHECKSUM_FILE_NAME}: {relative_path}"
            )
        if bundled_sha256 != recorded_sha256:
            raise ReleaseArtifactVerificationError(
                f"{source} complete reference hash does not match "
                f"{CHECKSUM_FILE_NAME}: {relative_path}"
            )


def verify_bytecode_proof_release_manifest_binding(
    repo_root: Path,
    bytecode_proof: dict[str, Any],
    release_manifest_path: Path,
    covered_file_snapshots: dict[str, CanonicalCoveredFile],
) -> None:
    source = require_dict(bytecode_proof.get("source"), "bytecode-release-proof.source")
    release_manifest = require_dict(
        source.get("release_manifest"),
        "bytecode-release-proof.source.release_manifest",
    )
    path = require_string(
        release_manifest.get("path"),
        "bytecode-release-proof.source.release_manifest.path",
    )
    if path != normalize_path(release_manifest_path, repo_root):
        raise ReleaseArtifactVerificationError(
            "bytecode release proof release_manifest path mismatch"
        )
    sha256 = require_string(
        release_manifest.get("sha256"),
        "bytecode-release-proof.source.release_manifest.sha256",
    )
    relative_path = normalize_path(release_manifest_path, repo_root)
    snapshot = covered_file_snapshots.get(relative_path)
    if snapshot is None:
        raise ReleaseArtifactVerificationError(
            "bytecode release proof release_manifest is absent from the "
            f"immutable covered-file snapshot: {relative_path}"
        )
    actual_sha256 = snapshot.sha256
    if sha256 != actual_sha256:
        raise ReleaseArtifactVerificationError(
            "bytecode release proof release_manifest hash mismatch"
        )


def verify_release_artifacts(
    repo_root: Path,
    release_dir: Path = DEFAULT_RELEASE_DIR,
) -> VerificationSummary:
    repo_root = require_canonical_repo_root(repo_root)
    resolved_release_dir = resolve_release_dir(repo_root, release_dir)
    checksum_path = resolved_release_dir / CHECKSUM_FILE_NAME
    checksum_manifest_path = resolved_release_dir / CHECKSUM_MANIFEST_NAME
    release_manifest_path = resolved_release_dir / RELEASE_MANIFEST_NAME
    bytecode_proof_path = resolved_release_dir / BYTECODE_PROOF_NAME
    release_candidate_lockfile_path = resolved_release_dir / RELEASE_CANDIDATE_LOCKFILE_NAME

    checksum_bundle = snapshot_checksum_bundle(
        repo_root,
        checksum_path,
        checksum_manifest_path,
    )
    covered_file_snapshots = verify_canonical_line_ending_bindings(
        repo_root,
        checksum_bundle,
    )
    verify_release_tool_trust_bindings(
        repo_root,
        checksum_bundle,
        covered_file_snapshots,
    )
    governed_parameter_inventory = validate_bound_snapshot_semantics(
        covered_file_snapshots
    )
    verify_record_family_inventory_schema_checksum_bindings(
        repo_root,
        checksum_bundle,
        covered_file_snapshots,
    )
    checksum_entries = verify_checksum_file(
        repo_root,
        checksum_bundle,
        covered_file_snapshots,
    )
    verify_governed_parameter_reference_checksum_coverage(
        repo_root,
        governed_parameter_inventory,
        checksum_entries,
    )
    required_paths = [
        normalize_path(release_manifest_path, repo_root),
        normalize_path(bytecode_proof_path, repo_root),
        normalize_path(release_candidate_lockfile_path, repo_root),
    ]
    require_checksum_covered(checksum_entries, required_paths)
    verify_release_directory_checksum_closure(
        repo_root,
        resolved_release_dir,
        checksum_entries,
    )
    checksum_manifest_records = verify_checksum_manifest(
        repo_root,
        checksum_entries,
        checksum_bundle,
        covered_file_snapshots,
    )

    release_manifest = require_schema(
        load_snapshot_json(
            covered_file_snapshots,
            normalize_path(release_manifest_path, repo_root),
            RELEASE_MANIFEST_NAME,
        ),
        RELEASE_MANIFEST_SCHEMA,
        RELEASE_MANIFEST_NAME,
    )
    bytecode_proof = require_schema(
        load_snapshot_json(
            covered_file_snapshots,
            normalize_path(bytecode_proof_path, repo_root),
            BYTECODE_PROOF_NAME,
        ),
        BYTECODE_PROOF_SCHEMA,
        BYTECODE_PROOF_NAME,
    )
    release_candidate_lockfile = require_schema(
        load_snapshot_json(
            covered_file_snapshots,
            normalize_path(release_candidate_lockfile_path, repo_root),
            RELEASE_CANDIDATE_LOCKFILE_NAME,
        ),
        RELEASE_CANDIDATE_LOCKFILE_SCHEMA,
        RELEASE_CANDIDATE_LOCKFILE_NAME,
    )
    verify_governed_parameter_inventory_bindings(
        release_manifest,
        release_candidate_lockfile,
    )
    verify_release_tool_call_policy_bindings(
        release_manifest,
        release_candidate_lockfile,
        covered_file_snapshots,
    )
    verify_record_family_authorization_bindings(
        release_manifest,
        release_candidate_lockfile,
    )
    verify_artist_semantic_owner_matrix_bindings(release_manifest)

    release_manifest_records = verify_nested_file_records(
        repo_root,
        release_manifest,
        RELEASE_MANIFEST_NAME,
        checksum_entries,
        covered_file_snapshots,
    )
    bytecode_proof_records = verify_nested_file_records(
        repo_root,
        bytecode_proof,
        BYTECODE_PROOF_NAME,
        checksum_entries,
        covered_file_snapshots,
    )
    release_candidate_lockfile_records = verify_nested_file_records(
        repo_root,
        release_candidate_lockfile,
        RELEASE_CANDIDATE_LOCKFILE_NAME,
        checksum_entries,
        covered_file_snapshots,
    )
    verify_bytecode_proof_release_manifest_binding(
        repo_root,
        bytecode_proof,
        release_manifest_path,
        covered_file_snapshots,
    )

    return VerificationSummary(
        checksum_entries=len(checksum_entries),
        checksum_manifest_records=checksum_manifest_records,
        release_manifest_records=release_manifest_records,
        bytecode_proof_records=bytecode_proof_records,
        release_candidate_lockfile_records=release_candidate_lockfile_records,
    )


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--release-dir", type=Path, default=DEFAULT_RELEASE_DIR)
    parser.add_argument("--json", action="store_true", help="emit machine-readable summary")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        summary = verify_release_artifacts(args.repo_root, args.release_dir)
    except ReleaseArtifactVerificationError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if args.json:
        print(json.dumps(summary._asdict(), indent=2, ensure_ascii=False))
    else:
        print(
            "release artifact verification passed: "
            f"{summary.checksum_entries} checksum entries, "
            f"{summary.checksum_manifest_records} checksum manifest records, "
            f"{summary.release_manifest_records} release manifest file records, "
            f"{summary.bytecode_proof_records} bytecode proof file records, "
            f"{summary.release_candidate_lockfile_records} "
            "release candidate lockfile file records"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
