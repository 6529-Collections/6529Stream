#!/usr/bin/env python3
"""Generate deterministic checksums for release and deployment artifacts."""

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
from typing import Any, NamedTuple

import check_governed_parameter_inventory as governed_parameter_inventory_checker


CHECKSUM_SCHEMA = "6529stream.release-checksums.v1"
GENERATOR_VERSION = "1"
CANONICAL_COVERAGE_POLICY = "canonical"
CUSTOM_SUBSET_COVERAGE_POLICY = "custom-subset"
GIT_ATTRIBUTES_PATH = Path(".gitattributes")
RELEASE_TOOL_CALL_POLICY_PATH = Path(
    "release-artifacts/release-tool-call-policy.json"
)
RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH = Path(
    "release-artifacts/schema/release-tool-call-policy.v1.schema.json"
)
RELEASE_TOOL_CALL_POLICY_SCHEMA = "6529stream.release-tool-call-policy.v1"
RELEASE_TOOL_CALL_POLICY_SCHEMA_ID = (
    "https://6529.io/schemas/release-tool-call-policy.v1.schema.json"
)
RELEASE_TOOL_CALL_POLICY_PATH_PATTERN = (
    r"^scripts/(?:[A-Za-z0-9_-]+/)*[A-Za-z0-9_-]+\.py$"
)
GIT_BINARY_SNIFF_BYTES = 8_000
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
RELEASE_TOOL_SEMANTIC_SOURCE_PATHS = (
    Path("smart-contracts/IStreamRecordFamilyAuthorityProvider.sol"),
    Path("smart-contracts/IStreamRecordFamilyRegistry.sol"),
    Path("smart-contracts/StreamRecordFamilyRegistry.sol"),
    Path("smart-contracts/StreamCollectionMetadata.sol"),
    Path("smart-contracts/IStreamCollectionMetadata.sol"),
    Path("smart-contracts/StreamPreservationRecords.sol"),
    Path("smart-contracts/IStreamPreservationRecords.sol"),
    Path("script/RehearseDeployment.s.sol"),
    Path("test/StreamRecordFamilyAuthorization.t.sol"),
    Path("test/StreamCollectionMetadata.t.sol"),
    Path("test/StreamPreservationRecords.t.sol"),
    Path("test/StreamDeploymentManifest.t.sol"),
)
REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE = (
    Path("scripts/check_admin_ceremony_evidence.py"),
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
RELEASE_TOOL_CALL_POLICY_ROLES = {
    **{
        path: "runtime"
        for path in REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
    },
    **{
        path: "focused-test"
        for path in RELEASE_TOOL_FOCUSED_TESTS
    },
}
RELEASE_TOOL_CALL_POLICY_PATHS = tuple(
    sorted(RELEASE_TOOL_CALL_POLICY_ROLES)
)
RELEASE_TOOL_CALL_POLICY_GENERATOR_VERSION = "1"
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
        "os",
        "pathlib",
        "re",
        "shlex",
        "shutil",
        "stat",
        "subprocess",
        "sys",
        "tempfile",
        "typing",
        "unicodedata",
        "unittest",
    }
)
REVIEWED_RELEASE_TOOL_EXTERNAL_MODULES_SHA256 = (
    "7a475d5ccb8e51ca912bfe8f62c66f6c2987bc121a7eddc709eb2e10a402dfc4"
)
# Imported bindings used as data (rather than as the direct function/member of
# a call or in an annotation/exception type) are a deliberately tiny,
# path-scoped capability surface. Each row is:
#   source path | imported target | enclosing call target or <none> | field.
# Any new callback/argument/alias/container/return use requires an explicit
# reviewed source change here as well as the generated per-file AST policy.
RELEASE_TOOL_CALL_POLICY_IMPORTED_VALUE_ALLOWLIST = frozenset(
    tuple(line.split("|"))
    for line in """
scripts/check_admin_ceremony_evidence.py|pathlib.Path|local:parser.add_argument|keyword:type
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
        "7fcdf573e3841e539c9bce91b882121a50c941225a1ad292e7df4506bccccae4",
        100_553,
    ),
    Path("scripts/check_slither_baseline.py"): (
        "8124a7981c2870b6816db733f4c963c8aa573036cb061a35810937560d4b98bc",
        46_988,
    ),
}
REVIEWED_RELEASE_TOOL_SNAPSHOT_LOADER_SOURCES = {
    Path("scripts/verify_release_artifacts.py"): (
        "5e9720e443907ab76ad42f7f82ce21cedb4f2fbfcefb045f1a1c6d6b3e17ce27",
        169_204,
    ),
}

DEFAULT_COVERED_PATHS = [
    GIT_ATTRIBUTES_PATH,
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
    Path("scripts/no_secret_scanner.py"),
    Path("scripts/test_no_secret_scanner.py"),
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
    Path("scripts/generate_post_entropy_completion_gas.py"),
    Path("scripts/check_post_entropy_completion_gas.py"),
    Path("scripts/test_post_entropy_completion_gas.py"),
    *RELEASE_TOOL_SEMANTIC_SOURCE_PATHS,
    Path("scripts/check_release_evidence_issue_links.py"),
    Path("scripts/test_release_evidence_issue_links.py"),
    Path("scripts/check_public_beta_evidence.py"),
    Path("scripts/test_public_beta_evidence.py"),
    Path("release-artifacts/contracts.json"),
    Path("release-artifacts/genesis-deployment-profile.json"),
    Path("release-artifacts/governed-parameter-inventory.json"),
    Path("release-artifacts/governance-action-policy.json"),
    Path("release-artifacts/record-family-authorization-inventory.json"),
    Path("release-artifacts/record-family-authorization-source-catalog.json"),
    Path("release-artifacts/post-entropy-mint-completion-gas.json"),
    RELEASE_TOOL_CALL_POLICY_PATH,
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
    Path("scripts/check_governance_action_policy.py"),
    Path("scripts/test_governance_action_policy.py"),
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
    Path("test/StreamPostEntropyCompletionGas.t.sol"),
    Path("test/helpers/StreamPostEntropyCompletionGasHarness.sol"),
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
    Path("docs/adr/0022-immutable-artist-registry-validation-adapter.md"),
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


class CoveredFileSnapshot(NamedTuple):
    """One immutable read used for EOL validation, hashing, and sizing."""

    path: Path
    relative_path: str
    data: bytes
    sha256: str
    size_bytes: int
    classification: str | None


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


def _parse_root_gitattributes(
    attributes_data: bytes,
) -> list[tuple[str, str, str | None]]:
    """Parse the deliberately narrow root policy used by release checksums."""

    try:
        text = attributes_data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ChecksumError(
            f"{GIT_ATTRIBUTES_PATH.as_posix()} must be valid UTF-8"
        ) from exc
    if "\x00" in text:
        raise ChecksumError(
            f"{GIT_ATTRIBUTES_PATH.as_posix()} must not contain NUL bytes"
        )

    rules: list[tuple[str, str, str | None]] = []
    for line_number, raw_line in enumerate(text.split("\n"), start=1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        if len(parts) < 2:
            raise ChecksumError(
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
            raise ChecksumError(
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
            raise ChecksumError(
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
            raise ChecksumError(
                f"unsupported .gitattributes attribute at line {line_number}: "
                f"{unknown[0]}"
            )
        if len(text_modes) != 1:
            raise ChecksumError(
                f"ambiguous .gitattributes text mode at line {line_number}"
            )
        if len(eol_tokens) > 1 or any(
            value not in {"lf", "crlf"} for value in eol_tokens
        ):
            raise ChecksumError(
                f"ambiguous .gitattributes eol at line {line_number}"
            )

        mode_token = text_modes[0]
        mode = {
            "text": "text",
            "text=auto": "auto",
            "-text": "binary",
            "binary": "binary",
        }[mode_token]
        eol = eol_tokens[0] if eol_tokens else None
        if mode == "binary" and eol is not None:
            raise ChecksumError(
                f"binary .gitattributes rule must not set eol at line {line_number}"
            )
        rules.append((pattern, mode, eol))

    if not rules:
        raise ChecksumError(f"{GIT_ATTRIBUTES_PATH.as_posix()} has no usable rules")
    return rules


def _gitattributes_pattern_matches(pattern: str, relative_path: str) -> bool:
    if pattern == "*":
        return True
    if pattern.startswith("*."):
        return Path(relative_path).name.endswith(pattern[1:])
    if pattern.endswith("/**"):
        return relative_path.startswith(pattern[:-2])
    return relative_path == pattern


def _validate_declared_line_endings(
    relative_path: str,
    data: bytes,
    mode: str,
    eol: str | None,
) -> str:
    if mode == "binary" or (
        mode == "auto" and b"\x00" in data[:GIT_BINARY_SNIFF_BYTES]
    ):
        if eol is not None:
            raise ChecksumError(
                f"binary covered path must not declare eol: {relative_path}"
            )
        return "binary"
    if eol is None:
        raise ChecksumError(
            "covered Git text path must declare explicit eol=lf or eol=crlf: "
            f"{relative_path}"
        )
    if eol == "lf":
        if b"\r" in data:
            raise ChecksumError(
                f"covered Git text path violates declared eol=lf: {relative_path}"
            )
        return "lf"

    without_crlf = data.replace(b"\r\n", b"")
    if b"\r" in without_crlf or b"\n" in without_crlf:
        raise ChecksumError(
            f"covered Git text path violates declared eol=crlf: {relative_path}"
        )
    return "crlf"


def _is_reparse_point(path: Path) -> bool:
    try:
        metadata = os.lstat(path)
    except OSError as exc:
        raise ChecksumError(f"cannot inspect covered path component: {path}") from exc
    return bool(
        path.is_symlink()
        or (
            getattr(metadata, "st_file_attributes", 0)
            & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
        )
    )


def _validated_repository_root(repo_root: Path) -> Path:
    if not repo_root.is_absolute():
        raise ChecksumError("release checksum repository root must be absolute")
    lexical_root = Path(os.path.abspath(repo_root))
    current = Path(lexical_root.anchor)
    for part in lexical_root.parts[1:]:
        current = current / part
        try:
            metadata = os.lstat(current)
        except OSError as exc:
            raise ChecksumError(
                f"cannot inspect release checksum repository root: {current}"
            ) from exc
        if stat.S_ISLNK(metadata.st_mode) or (
            getattr(metadata, "st_file_attributes", 0)
            & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
        ):
            raise ChecksumError(
                "release checksum repository root must not include "
                f"symlink/reparse components: {current}"
            )
    if not lexical_root.is_dir():
        raise ChecksumError(
            f"release checksum repository root is not a directory: {lexical_root}"
        )
    try:
        return lexical_root.resolve(strict=True)
    except (FileNotFoundError, OSError) as exc:
        raise ChecksumError(
            f"cannot resolve release checksum repository root: {lexical_root}"
        ) from exc


def _read_covered_file_snapshots(
    repo_root: Path,
    files: list[Path],
) -> dict[str, CoveredFileSnapshot]:
    lexical_root = Path(os.path.abspath(repo_root))
    root = _validated_repository_root(repo_root)

    snapshots: dict[str, CoveredFileSnapshot] = {}
    directory_entries: dict[Path, set[str]] = {}
    for file_path in files:
        if not file_path.is_absolute() and any(
            part in {"", ".", ".."} for part in file_path.parts
        ):
            raise ChecksumError(
                f"covered line-ending input must be normalized: {file_path}"
            )
        if file_path.is_absolute():
            lexical_candidate = file_path.absolute()
            try:
                lexical_relative = lexical_candidate.relative_to(lexical_root)
            except ValueError:
                try:
                    lexical_relative = lexical_candidate.relative_to(root)
                except ValueError as exc:
                    raise ChecksumError(
                        f"covered line-ending input escapes repository: {file_path}"
                    ) from exc
        else:
            lexical_relative = file_path
        candidate = root / lexical_relative
        if any(part in {"", ".", ".."} for part in lexical_relative.parts):
            raise ChecksumError(
                f"covered line-ending input must be normalized: {file_path}"
            )
        current = root
        for part in lexical_relative.parts:
            names = directory_entries.get(current)
            if names is None:
                try:
                    names = {entry.name for entry in current.iterdir()}
                except OSError as exc:
                    raise ChecksumError(
                        f"cannot enumerate covered path parent: {current}"
                    ) from exc
                directory_entries[current] = names
            if part not in names:
                raise ChecksumError(
                    "covered line-ending input must use exact on-disk path "
                    f"spelling: {file_path}"
                )
            current = current / part
            if _is_reparse_point(current):
                raise ChecksumError(
                    "covered line-ending input must not include symlink/reparse "
                    f"components: {file_path}"
                )
        if not candidate.is_file():
            raise ChecksumError(
                f"covered line-ending input is not a regular file: {file_path}"
            )
        resolved = candidate.resolve()
        if resolved != candidate:
            raise ChecksumError(
                f"covered line-ending input must not redirect: {file_path}"
            )
        relative_path = lexical_relative.as_posix()
        if relative_path in snapshots:
            raise ChecksumError(
                f"covered line-ending input listed more than once: {relative_path}"
            )
        data = candidate.read_bytes()
        snapshots[relative_path] = CoveredFileSnapshot(
            path=candidate,
            relative_path=relative_path,
            data=data,
            sha256=sha256_bytes(data),
            size_bytes=len(data),
            classification=None,
        )
    return snapshots


def validate_covered_file_line_endings(
    repo_root: Path,
    files: list[Path],
    *,
    attributes_path: Path = GIT_ATTRIBUTES_PATH,
) -> dict[str, CoveredFileSnapshot]:
    """Validate exact root attributes and raw bytes for canonical covered files.

    The return value maps normalized repository paths to immutable snapshots
    carrying the exact bytes-derived SHA-256, size, and ``lf``, ``crlf``, or
    ``binary`` classification. Binary files are classified only by an explicit
    raw/binary rule or Git's 8,000-byte NUL sniff for ``text=auto``; their bytes
    are not decoded or normalized.
    """

    if attributes_path != GIT_ATTRIBUTES_PATH:
        raise ChecksumError(
            "release checksum line-ending policy must use exact "
            f"{GIT_ATTRIBUTES_PATH.as_posix()}"
        )
    root = _validated_repository_root(repo_root)
    snapshots = _read_covered_file_snapshots(repo_root, files)

    attributes_relative = GIT_ATTRIBUTES_PATH.as_posix()
    if attributes_relative not in snapshots:
        raise ChecksumError(
            "canonical release checksum inputs must include exact "
            f"{attributes_relative}"
        )
    rules = _parse_root_gitattributes(snapshots[attributes_relative].data)

    validated: dict[str, CoveredFileSnapshot] = {}
    for relative_path, snapshot in sorted(snapshots.items()):
        parent = Path(relative_path).parent
        while parent != Path("."):
            nested_attributes = root / parent / GIT_ATTRIBUTES_PATH
            if nested_attributes.exists():
                raise ChecksumError(
                    "canonical release checksum line-ending policy forbids "
                    f"nested .gitattributes: {nested_attributes.relative_to(root).as_posix()}"
                )
            parent = parent.parent
        mode: str | None = None
        eol: str | None = None
        for pattern, rule_mode, rule_eol in rules:
            if not _gitattributes_pattern_matches(pattern, relative_path):
                continue
            mode = rule_mode
            if rule_eol is not None:
                eol = rule_eol
        if mode is None:
            raise ChecksumError(
                f"covered path has no explicit text/binary rule: {relative_path}"
            )
        classification = _validate_declared_line_endings(
            relative_path,
            snapshot.data,
            mode,
            eol,
        )
        validated[relative_path] = CoveredFileSnapshot(
            path=snapshot.path,
            relative_path=snapshot.relative_path,
            data=snapshot.data,
            sha256=snapshot.sha256,
            size_bytes=snapshot.size_bytes,
            classification=classification,
        )
    return validated


def json_text(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    if path.is_absolute():
        return path
    return repo_root / path


def output_paths(output_dir: Path) -> set[Path]:
    return {
        output_dir / CHECKSUM_FILE_NAME,
        output_dir / CHECKSUM_MANIFEST_NAME,
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
    root = _validated_repository_root(repo_root)
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


def _validated_release_tool_source(
    repo_root: Path,
    relative_path: Path,
    *,
    required: bool,
) -> Path | None:
    """Resolve one regular scripts/*.py file without following redirections."""

    root = _validated_repository_root(repo_root)
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
        try:
            metadata = os.lstat(current)
        except FileNotFoundError as exc:
            if not required:
                return None
            raise ChecksumError(
                "release-tool checksum closure source is missing: "
                f"{relative_path.as_posix()}"
            ) from exc
        except OSError as exc:
            raise ChecksumError(
                "cannot inspect release-tool checksum closure source: "
                f"{relative_path.as_posix()}"
            ) from exc
        if stat.S_ISLNK(metadata.st_mode) or (
            getattr(metadata, "st_file_attributes", 0)
            & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
        ):
            raise ChecksumError(
                "release-tool checksum closure source must not include "
                f"symlinks or reparse points: {relative_path.as_posix()}"
            )

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
    getattr access on protected importer modules, dynamic imports of those
    modules, dynamic non-literal or relative targets, non-empty __import__
    fromlists, wildcard imports, exec/eval/compile, reflective
    globals/locals/vars access, runpy, importlib.util/importlib.machinery
    loaders, locator/serialization modules, operator-based reflective getters,
    Python-interpreter subprocess targets, exec_module(), and load_module() are
    forbidden because their dependencies cannot be reviewed deterministically.
    """

    source_path = _validated_release_tool_source(
        repo_root,
        relative_path,
        required=True,
    )
    assert source_path is not None
    try:
        source_bytes = source_path.read_bytes()
        source_text = source_bytes.decode("utf-8")
        tree = ast.parse(source_text, filename=relative_path.as_posix())
    except (OSError, UnicodeDecodeError) as exc:
        raise ChecksumError(
            "release-tool checksum closure cannot read UTF-8 source "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc
    except SyntaxError as exc:
        raise ChecksumError(
            f"release-tool checksum closure cannot parse "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc

    importlib_aliases: set[str] = set()
    builtins_aliases: set[str] = set()
    sys_aliases: set[str] = set()
    subprocess_aliases: set[str] = set()
    forbidden_reflective_modules = {
        "ctypes",
        "gc",
        "marshal",
        "multiprocessing",
        "inspect",
        "operator",
        "pickle",
        "pkgutil",
        "pydoc",
        "runpy",
        "shelve",
    }
    forbidden_reflection_attributes = frozenset(
        {
            "__builtins__",
            "__dict__",
            "__globals__",
            "__getattribute__",
            "_getframe",
            "ag_frame",
            "breakpoint",
            "breakpointhook",
            "cr_frame",
            "currentframe",
            "discover",
            "f_builtins",
            "f_globals",
            "f_locals",
            "gi_frame",
            "help",
            "loadTestsFromName",
            "loadTestsFromNames",
            "modules",
            "tb_frame",
        }
    )
    for node in ast.walk(tree):
        if not isinstance(node, ast.Import):
            continue
        for alias in node.names:
            if alias.name == "importlib":
                importlib_aliases.add(alias.asname or "importlib")
            elif alias.name == "builtins":
                builtins_aliases.add(alias.asname or "builtins")
            elif alias.name == "sys":
                sys_aliases.add(alias.asname or "sys")
            elif alias.name == "subprocess":
                subprocess_aliases.add(alias.asname or "subprocess")

    reviewed_subprocess_binding = REVIEWED_RELEASE_TOOL_SUBPROCESS_SOURCES.get(
        relative_path
    )
    reviewed_snapshot_loader_binding = (
        REVIEWED_RELEASE_TOOL_SNAPSHOT_LOADER_SOURCES.get(relative_path)
    )
    if reviewed_snapshot_loader_binding is not None:
        actual_snapshot_loader_binding = (
            hashlib.sha256(source_bytes).hexdigest(),
            len(source_bytes),
        )
        if actual_snapshot_loader_binding != reviewed_snapshot_loader_binding:
            raise ChecksumError(
                "release-tool snapshot-loader source differs from its exact "
                f"reviewed binding: {relative_path.as_posix()}"
            )
    if reviewed_subprocess_binding is not None:
        actual_subprocess_binding = (
            hashlib.sha256(source_bytes).hexdigest(),
            len(source_bytes),
        )
        if actual_subprocess_binding != reviewed_subprocess_binding:
            raise ChecksumError(
                "release-tool subprocess source differs from its exact reviewed "
                f"binding: {relative_path.as_posix()}"
            )
    elif subprocess_aliases:
        raise ChecksumError(
            "release-tool checksum closure forbids subprocess outside exact "
            f"reviewed sources: {relative_path.as_posix()}"
        )

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
                if any(
                    alias.name == module_name
                    or alias.name.startswith(f"{module_name}.")
                    for module_name in forbidden_reflective_modules
                ):
                    reject_alternate_loader(node, alias.name)
                if (
                    alias.name.startswith("importlib.")
                    and not (
                        alias.name == "importlib.util"
                        and reviewed_snapshot_loader_binding is not None
                    )
                ):
                    reject_alternate_loader(node, alias.name)
        elif isinstance(node, ast.ImportFrom):
            module = node.module or ""
            if any(alias.name == "*" for alias in node.names):
                reject_alternate_loader(node, "wildcard import")
            if any(
                module == module_name or module.startswith(f"{module_name}.")
                for module_name in forbidden_reflective_modules
            ):
                reject_alternate_loader(node, module)
            if module == "subprocess":
                reject_alternate_loader(node, "subprocess callable import")
            if module.startswith("importlib."):
                reject_alternate_loader(node, module)
            if module == "importlib":
                allowed_importlib_from = {"import_module"}
                if (
                    relative_path
                    == Path("scripts/check_slither_baseline.py")
                    and reviewed_subprocess_binding is not None
                ):
                    allowed_importlib_from.add("metadata")
                for alias in node.names:
                    if alias.name not in allowed_importlib_from:
                        reject_alternate_loader(
                            node,
                            f"importlib.{alias.name}",
                        )
                    if alias.name in {"__dict__", "__getattribute__"}:
                        reject_alternate_loader(
                            node,
                            f"importlib.{alias.name}",
                        )
            if module == "builtins":
                for alias in node.names:
                    if alias.name in {
                        "exec",
                        "eval",
                        "compile",
                        "__dict__",
                        "__getattribute__",
                        "getattr",
                        "vars",
                        "globals",
                        "locals",
                        "breakpoint",
                        "help",
                    }:
                        reject_alternate_loader(node, f"builtins.{alias.name}")
            if module == "sys":
                for alias in node.names:
                    if alias.name in forbidden_reflection_attributes:
                        reject_alternate_loader(node, f"sys.{alias.name}")
        elif (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in {
                "exec",
                "eval",
                "compile",
                "globals",
                "locals",
                "vars",
                "breakpoint",
                "help",
            }
        ):
            reject_alternate_loader(node, node.id)
        elif isinstance(node, ast.Call):
            if (
                isinstance(node.func, ast.Name)
                and node.func.id == "getattr"
                and len(node.args) >= 2
                and isinstance(node.args[1], ast.Constant)
                and node.args[1].value in {"exec_module", "load_module"}
            ):
                reject_alternate_loader(node, str(node.args[1].value))
            if (
                isinstance(node.func, ast.Name)
                and node.func.id in {"exec", "eval", "compile"}
            ):
                reject_alternate_loader(node.func, node.func.id)
            if (
                isinstance(node.func, ast.Attribute)
                and node.func.attr in {"exec_module", "load_module"}
                and not (
                    node.func.attr == "exec_module"
                    and reviewed_snapshot_loader_binding is not None
                )
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
                    and not (
                        chain[1] == "util"
                        and reviewed_snapshot_loader_binding is not None
                        and (
                            len(chain) == 2
                            or (
                                len(chain) == 3
                                and chain[2]
                                in {
                                    "spec_from_file_location",
                                    "module_from_spec",
                                }
                            )
                        )
                    )
                ):
                    reject_alternate_loader(node, importlib_api)
            if (
                chain is not None
                and chain[0] in sys_aliases
                and len(chain) >= 2
                and chain[1] in {
                    "modules",
                    "__dict__",
                    "__getattribute__",
                }
                and not (
                    chain[1] == "modules"
                    and reviewed_snapshot_loader_binding is not None
                )
            ):
                reject_alternate_loader(node, ".".join(chain[:2]))

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
                elif alias.name == "sys":
                    sys_aliases.add(alias.asname or "sys")
                elif alias.name == "subprocess":
                    subprocess_aliases.add(alias.asname or "subprocess")
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

    protected_module_aliases = importlib_aliases | builtins_aliases | {
        "__builtins__"
    }
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
            and node.args
            and isinstance(node.args[0], ast.Name)
            and node.args[0].id in protected_module_aliases
        ):
            raise ChecksumError(
                "release-tool checksum closure does not support getattr access "
                "on protected importer module alias "
                f"{node.args[0].id} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
        return None

    parent_by_node = {
        child: parent
        for parent in ast.walk(tree)
        for child in ast.iter_child_nodes(parent)
    }
    for node in ast.walk(tree):
        subprocess_alias: str | None = None
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, (ast.Store, ast.Del))
            and node.id in subprocess_aliases
        ):
            subprocess_alias = node.id
        elif isinstance(node, ast.arg) and node.arg in subprocess_aliases:
            subprocess_alias = node.arg
        elif (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and node.name in subprocess_aliases
        ):
            subprocess_alias = node.name
        if subprocess_alias is not None:
            raise ChecksumError(
                "release-tool checksum closure does not support subprocess "
                f"module alias rebinding for {subprocess_alias} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )

    allowed_subprocess_attributes = {"CalledProcessError", "PIPE", "run"}
    for node in ast.walk(tree):
        if not (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in subprocess_aliases
        ):
            continue
        parent = parent_by_node.get(node)
        if not (
            isinstance(parent, ast.Attribute)
            and parent.value is node
            and parent.attr in allowed_subprocess_attributes
        ):
            raise ChecksumError(
                "release-tool checksum closure does not support subprocess "
                f"module alias escape for {node.id} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
        if parent.attr != "run":
            continue
        call = parent_by_node.get(parent)
        if not (isinstance(call, ast.Call) and call.func is parent):
            raise ChecksumError(
                "release-tool checksum closure does not support subprocess "
                f"callable escape from {node.id}.run in "
                f"{relative_path.as_posix()}:{parent.lineno}"
            )
        command = call.args[0] if call.args else None
        if command is None:
            reject_alternate_loader(call, "subprocess.run without command")
        assert command is not None
        command_nodes = tuple(ast.walk(command))
        if any(
            isinstance(candidate, ast.Attribute)
            and candidate.attr == "executable"
            and isinstance(candidate.value, ast.Name)
            and candidate.value.id in sys_aliases
            for candidate in command_nodes
        ):
            reject_alternate_loader(call, "Python subprocess target")
        for candidate in command_nodes:
            if not (
                isinstance(candidate, ast.Constant)
                and isinstance(candidate.value, str)
            ):
                continue
            token = candidate.value.strip().replace("\\", "/").split("/")[-1]
            token_lower = token.casefold()
            if token_lower in {
                "py",
                "py.exe",
                "python",
                "python.exe",
                "python3",
                "python3.exe",
            } or token_lower.endswith(".py"):
                reject_alternate_loader(call, "Python subprocess target")
        for keyword in call.keywords:
            if keyword.arg == "shell" and not (
                isinstance(keyword.value, ast.Constant)
                and keyword.value.value is False
            ):
                reject_alternate_loader(call, "subprocess shell execution")
            if keyword.arg == "executable" and not (
                isinstance(keyword.value, ast.Constant)
                and keyword.value.value is None
            ):
                reject_alternate_loader(call, "subprocess executable override")
    for node in ast.walk(tree):
        if not (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in sys_aliases
        ):
            continue
        parent = parent_by_node.get(node)
        if not (
            isinstance(parent, ast.Attribute)
            and parent.value is node
        ):
            raise ChecksumError(
                "release-tool checksum closure does not support sys module "
                f"alias escape for {node.id} in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
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
        snapshot_loader_call = False
        if (
            reviewed_snapshot_loader_binding is not None
            and isinstance(parent, ast.Attribute)
            and parent.value is node
        ):
            top_attribute = parent
            next_parent = parent_by_node.get(top_attribute)
            while (
                isinstance(next_parent, ast.Attribute)
                and next_parent.value is top_attribute
            ):
                top_attribute = next_parent
                next_parent = parent_by_node.get(top_attribute)
            snapshot_loader_call = (
                attribute_chain(top_attribute)
                in {
                    (
                        node.id,
                        "util",
                        "spec_from_file_location",
                    ),
                    (
                        node.id,
                        "util",
                        "module_from_spec",
                    ),
                }
                and isinstance(next_parent, ast.Call)
                and next_parent.func is top_attribute
            )
        if not direct_importer_call and not snapshot_loader_call:
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
                if any(keyword.arg is None for keyword in node.keywords):
                    raise ChecksumError(
                        "release-tool checksum closure does not support "
                        "expanded dynamic-import keyword arguments in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )
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
                fromlist_node = (
                    node.args[3]
                    if len(node.args) >= 4
                    else next(
                        (
                            keyword.value
                            for keyword in node.keywords
                            if keyword.arg == "fromlist"
                        ),
                        None,
                    )
                )
                if fromlist_node is not None and not (
                    isinstance(fromlist_node, (ast.List, ast.Tuple))
                    and not fromlist_node.elts
                ):
                    raise ChecksumError(
                        "release-tool checksum closure does not support "
                        "non-empty or dynamic __import__ fromlist in "
                        f"{relative_path.as_posix()}:{node.lineno}"
                    )
            if module_name.startswith("."):
                raise ChecksumError(
                    "release-tool checksum closure does not support relative "
                    f"dynamic imports in {relative_path.as_posix()}:{node.lineno}"
                )
            if (
                module_name in {"builtins", "importlib", "subprocess", "sys"}
                or module_name in forbidden_reflective_modules
                or module_name.startswith("builtins.")
                or module_name.startswith("importlib.")
                or any(
                    module_name.startswith(f"{forbidden_module}.")
                    for forbidden_module in forbidden_reflective_modules
                )
            ):
                raise ChecksumError(
                    "release-tool checksum closure does not support dynamic "
                    f"import of protected module {module_name} in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
            add_module_candidates(candidates, module_name)

    # Run broad reflection fallbacks after the shape-specific importer checks
    # above. This preserves stable, targeted diagnostics while still rejecting
    # transitive stdlib pivots such as ``os.__builtins__`` and
    # ``pkgutil.importlib.import_module``. The builtin getattr callable itself
    # may only appear as the direct function of a call; aliases, containers,
    # arguments, returns, and conditional escapes fail closed.
    for node in ast.walk(tree):
        if isinstance(node, ast.Name) and node.id == "getattr":
            if isinstance(node.ctx, ast.Load):
                parent = parent_by_node.get(node)
                if not (
                    isinstance(parent, ast.Call)
                    and parent.func is node
                ):
                    reject_alternate_loader(node, "getattr callable escape")
            elif isinstance(node.ctx, (ast.Store, ast.Del)):
                reject_alternate_loader(node, "getattr rebinding")
        elif isinstance(node, ast.arg) and node.arg == "getattr":
            reject_alternate_loader(node, "getattr rebinding")
        elif (
            isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))
            and node.name == "getattr"
        ):
            reject_alternate_loader(node, "getattr rebinding")

    for node in ast.walk(tree):
        if not (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id == "getattr"
        ):
            continue
        if (
            len(node.args) < 2
            or not isinstance(node.args[1], ast.Constant)
            or not isinstance(node.args[1].value, str)
        ):
            reject_alternate_loader(node, "non-literal getattr")
        getattr_name = node.args[1].value
        if getattr_name in forbidden_reflection_attributes | {
            "__import__",
            "exec_module",
            "import_module",
            "load_module",
        }:
            reject_alternate_loader(node, getattr_name)

    for node in ast.walk(tree):
        if not isinstance(node, ast.Attribute):
            continue
        if (
            node.attr in forbidden_reflection_attributes
            and not (
                node.attr == "modules"
                and reviewed_snapshot_loader_binding is not None
                and isinstance(node.value, ast.Name)
                and node.value.id in sys_aliases
            )
        ):
            reject_alternate_loader(node, node.attr)
        if node.attr in {"__import__", "import_module"}:
            direct_known_importer = (
                is_direct_call_func(node)
                and (
                    (
                        node.attr == "import_module"
                        and isinstance(node.value, ast.Name)
                        and node.value.id in importlib_aliases
                    )
                    or (
                        node.attr == "__import__"
                        and isinstance(node.value, ast.Name)
                        and node.value.id in builtins_aliases
                    )
                )
            )
            if not direct_known_importer:
                reject_alternate_loader(node, node.attr)
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


def _release_tool_call_policy_json_object(
    data: bytes,
    *,
    label: str,
) -> dict[str, Any]:
    """Decode one canonical JSON object while rejecting duplicate keys."""

    def unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        value: dict[str, Any] = {}
        for key, member in pairs:
            if key in value:
                raise ChecksumError(f"{label} contains duplicate key {key!r}")
            value[key] = member
        return value

    try:
        decoded = json.loads(
            data.decode("utf-8"),
            object_pairs_hook=unique_object,
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ChecksumError(f"{label} is not canonical UTF-8 JSON: {exc}") from exc
    if not isinstance(decoded, dict):
        raise ChecksumError(f"{label} must be a JSON object")
    return decoded


def _release_tool_call_policy_parent_map(
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


def _release_tool_call_policy_imports(
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
        for path in RELEASE_TOOL_CALL_POLICY_PATHS
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
            raise ChecksumError(
                "release-tool call policy forbids every relative import: "
                f"{'.' * level}{module} in "
                f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
            )
        if (
            role == "runtime"
            and relative_path
            != Path("scripts/verify_release_artifacts.py")
            and module
            in {"runpy", "importlib.util", "importlib.machinery"}
        ):
            raise ChecksumError(
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
        raise ChecksumError(
            "release-tool call policy forbids unreviewed import module "
            f"{module!r} in "
            f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
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
            raise ChecksumError(
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
            if any(alias.name == "*" for alias in node.names):
                raise ChecksumError(
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


def _release_tool_call_policy_dotted_parts(
    node: ast.AST,
) -> tuple[str, ...] | None:
    parts: list[str] = []
    current = node
    while isinstance(current, ast.Attribute):
        parts.append(current.attr)
        current = current.value
    if not isinstance(current, ast.Name):
        return None
    parts.append(current.id)
    return tuple(reversed(parts))


def _release_tool_call_policy_static_target(
    node: ast.AST,
    bindings: dict[str, str],
    relative_path: Path,
) -> str:
    if isinstance(node, ast.Name):
        return bindings.get(node.id, f"local:{node.id}")
    if isinstance(node, ast.Attribute):
        dotted = _release_tool_call_policy_dotted_parts(node)
        if dotted is not None:
            root = bindings.get(dotted[0], f"local:{dotted[0]}")
            suffix = ".".join(dotted[1:])
            return f"{root}.{suffix}" if suffix else root
        receiver_attributes: list[str] = []
        receiver: ast.AST = node
        while isinstance(receiver, ast.Attribute):
            receiver_attributes.append(receiver.attr)
            receiver = receiver.value
        if isinstance(receiver, ast.Call):
            receiver = _release_tool_call_policy_static_target(
                receiver.func,
                bindings,
                relative_path,
            )
            suffix = ".".join(reversed(receiver_attributes))
            return f"{receiver}().{suffix}"
        imported_receiver_names = sorted(
            {
                candidate.id
                for candidate in ast.walk(node.value)
                if (
                    isinstance(candidate, ast.Name)
                    and isinstance(candidate.ctx, ast.Load)
                    and candidate.id in bindings
                )
            }
        )
        if imported_receiver_names:
            raise ChecksumError(
                "release-tool call policy forbids imported binding in "
                "computed receiver "
                f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}: "
                f"{imported_receiver_names}"
            )
        receiver_ast = ast.dump(
            node.value,
            annotate_fields=True,
            include_attributes=False,
        ).encode("utf-8")
        receiver_sha256 = hashlib.sha256(receiver_ast).hexdigest()
        return (
            f"expression:{type(node.value).__name__}:"
            f"{receiver_sha256}.{node.attr}"
        )
    raise ChecksumError(
        "release-tool call policy forbids computed or escaped callable in "
        f"{relative_path.as_posix()}:{getattr(node, 'lineno', 0)}"
    )


def _release_tool_call_policy_member_context(
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


def _release_tool_call_policy_members(
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
            dotted = _release_tool_call_policy_dotted_parts(node)
            if dotted is not None and dotted[0] in bindings:
                target = ".".join((bindings[dotted[0]], *dotted[1:]))
        if target is None:
            continue
        record = json.dumps(
            {
                "context": _release_tool_call_policy_member_context(
                    node,
                    parents,
                ),
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


def _release_tool_call_policy_reject_imported_binding_shadows(
    tree: ast.AST,
    bindings: dict[str, str],
    parents: dict[ast.AST, tuple[ast.AST, str]],
    relative_path: Path,
) -> frozenset[tuple[str, str, str, str]]:
    """Reject imported-name shadowing except five exact toolchain fallbacks."""

    observed: set[tuple[str, str, str, str]] = set()

    def reject(name: str, node: ast.AST, shape: str) -> None:
        raise ChecksumError(
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
                    replacement = ast.dump(
                        parent.value,
                        annotate_fields=True,
                        include_attributes=False,
                    )
                    allowed_key = (
                        relative_path.as_posix(),
                        name,
                        bindings[name],
                        replacement,
                    )

        if (
            allowed_key is None
            or allowed_key
            not in RELEASE_TOOL_CALL_POLICY_IMPORTED_SHADOW_ALLOWLIST
            or allowed_key in observed
        ):
            reject(name, node, shape or type(node).__name__)
        observed.add(allowed_key)

    return frozenset(observed)


def _release_tool_call_policy_reject_imported_binding_escapes(
    tree: ast.AST,
    bindings: dict[str, str],
    parents: dict[ast.AST, tuple[ast.AST, str]],
    relative_path: Path,
) -> frozenset[tuple[str, str, str, str]]:
    """Reject laundering imported modules/callables into local dataflow.

    Imported bindings may be called directly, used through a static member
    chain, or appear in type/exception annotations. Every other value use,
    including an argument, callback, constant, assignment, return, container,
    comparison, or conditional, must match the literal path/target/call/field
    allowlist above.
    """

    def imported_target(node: ast.AST) -> str | None:
        if (
            isinstance(node, ast.Name)
            and isinstance(node.ctx, ast.Load)
            and node.id in bindings
        ):
            return bindings[node.id]
        if isinstance(node, ast.Attribute):
            dotted = _release_tool_call_policy_dotted_parts(node)
            if dotted is not None and dotted[0] in bindings:
                return ".".join((bindings[dotted[0]], *dotted[1:]))
        return None

    def is_outermost_imported_member(node: ast.AST) -> bool:
        parent_info = parents.get(node)
        if parent_info is None:
            return True
        parent, field = parent_info
        if (
            isinstance(parent, ast.Attribute)
            and field == "value"
            and imported_target(parent) is not None
        ):
            return False
        return True

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
            raise ChecksumError(
                "release-tool call policy forbids root imported binding "
                f"{target} in {relative_path.as_posix()}:"
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
                call_target = _release_tool_call_policy_static_target(
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
            raise ChecksumError(
                "release-tool call policy forbids unreviewed imported value "
                f"context path={key[0]!r}, target={key[1]!r}, "
                f"call={key[2]!r}, field={key[3]!r} at line "
                f"{getattr(node, 'lineno', 0)}"
            )
        observed.add(key)
    return frozenset(observed)


def _release_tool_call_policy_calls(
    tree: ast.AST,
    bindings: dict[str, str],
    relative_path: Path,
) -> list[dict[str, Any]]:
    records: dict[tuple[str, str, str], int] = {}
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        target = _release_tool_call_policy_static_target(
            node.func,
            bindings,
            relative_path,
        )
        if target in {
            "local:__import__",
            "builtins.__import__",
            "importlib.import_module",
        }:
            raise ChecksumError(
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
            raise ChecksumError(
                "release-tool call policy forbids computed attribute name in "
                f"{relative_path.as_posix()}:{node.lineno}"
            )
        keyword_names = [
            keyword.arg if keyword.arg is not None else "**"
            for keyword in node.keywords
        ]
        shape = (
            f"positional={sum(not isinstance(arg, ast.Starred) for arg in node.args)};"
            f"starred={sum(isinstance(arg, ast.Starred) for arg in node.args)};"
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


def _release_tool_call_policy_row(
    repo_root: Path,
    relative_path: Path,
    role: str,
    *,
    source_bytes: bytes | None = None,
    imported_value_uses: set[tuple[str, str, str, str]] | None = None,
    imported_shadow_uses: set[tuple[str, str, str, str]] | None = None,
    local_dependencies: set[Path] | None = None,
    observed_external_modules: set[str] | None = None,
) -> dict[str, Any]:
    try:
        if source_bytes is None:
            source_path = _validated_release_tool_source(
                repo_root,
                relative_path,
                required=True,
            )
            assert source_path is not None
            source_bytes = source_path.read_bytes()
        source_text = source_bytes.decode("utf-8")
        tree = ast.parse(source_text, filename=relative_path.as_posix())
    except (OSError, UnicodeDecodeError) as exc:
        raise ChecksumError(
            "release-tool call policy cannot read UTF-8 source "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc
    except SyntaxError as exc:
        raise ChecksumError(
            "release-tool call policy cannot parse "
            f"{relative_path.as_posix()}: {exc}"
        ) from exc

    imports, bindings = _release_tool_call_policy_imports(
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
                raise ChecksumError(
                    "release-tool runtime call policy forbids alternate "
                    f"loader member {node.attr!r} in "
                    f"{relative_path.as_posix()}:{node.lineno}"
                )
    parents = _release_tool_call_policy_parent_map(tree)
    observed_imported_shadows = (
        _release_tool_call_policy_reject_imported_binding_shadows(
            tree,
            bindings,
            parents,
            relative_path,
        )
    )
    if imported_shadow_uses is not None:
        imported_shadow_uses.update(observed_imported_shadows)
    observed_imported_values = (
        _release_tool_call_policy_reject_imported_binding_escapes(
            tree,
            bindings,
            parents,
            relative_path,
        )
    )
    if imported_value_uses is not None:
        imported_value_uses.update(observed_imported_values)
    return {
        "path": relative_path.as_posix(),
        "role": role,
        "source_sha256": hashlib.sha256(source_bytes).hexdigest(),
        "size_bytes": len(source_bytes),
        "imports": imports,
        "members": _release_tool_call_policy_members(
            tree,
            bindings,
            parents,
        ),
        "calls": _release_tool_call_policy_calls(
            tree,
            bindings,
            relative_path,
        ),
    }


def _release_tool_call_policy_snapshot_bytes(
    snapshots: dict[str, CoveredFileSnapshot],
    relative_path: Path,
    *,
    repo_root: Path,
) -> bytes:
    key = relative_path.as_posix()
    snapshot = snapshots.get(key)
    if snapshot is None:
        raise ChecksumError(
            "release-tool call policy immutable snapshot is missing "
            f"{key}"
        )
    if not isinstance(snapshot, CoveredFileSnapshot):
        raise ChecksumError(
            "release-tool call policy immutable snapshot has invalid value "
            f"for {key}"
        )
    expected_path = Path(os.path.abspath(repo_root)) / relative_path
    actual_path = Path(os.path.abspath(snapshot.path))
    if (
        snapshot.relative_path != key
        or actual_path != expected_path
        or snapshot.sha256 != sha256_bytes(snapshot.data)
        or snapshot.size_bytes != len(snapshot.data)
        or snapshot.classification not in {"lf", "crlf", "binary"}
    ):
        raise ChecksumError(
            "release-tool call policy immutable snapshot metadata "
            f"mismatch for {key}"
        )
    return snapshot.data


def build_release_tool_call_policy(
    repo_root: Path,
    *,
    source_snapshots: dict[str, CoveredFileSnapshot] | None = None,
) -> dict[str, Any]:
    """Build the exact bounded static call policy for the reviewed 32 files."""

    runtime_paths = set(REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE)
    focused_paths = set(RELEASE_TOOL_FOCUSED_TESTS)
    overlap = sorted(path.as_posix() for path in runtime_paths & focused_paths)
    if overlap:
        raise ChecksumError(
            "release-tool call policy role sets overlap: "
            f"{overlap}"
        )
    if len(runtime_paths) != 23 or len(focused_paths) != 9:
        raise ChecksumError(
            "release-tool call policy requires exactly 23 runtime and 9 "
            f"focused-test paths, got {len(runtime_paths)} and "
            f"{len(focused_paths)}"
        )
    if (
        RELEASE_TOOL_ROOTS != REVIEWED_RELEASE_TOOL_ROOTS
        or len(REVIEWED_RELEASE_TOOL_ROOTS) != 7
        or len(set(REVIEWED_RELEASE_TOOL_ROOTS)) != 7
    ):
        raise ChecksumError(
            "release-tool roots differ from the exact reviewed seven-root "
            "literal"
        )
    roots_digest = hashlib.sha256(
        (
            "\n".join(
                path.as_posix()
                for path in REVIEWED_RELEASE_TOOL_ROOTS
            )
            + "\n"
        ).encode("utf-8")
    ).hexdigest()
    if roots_digest != REVIEWED_RELEASE_TOOL_ROOTS_SHA256:
        raise ChecksumError(
            "release-tool roots differ from the pinned canonical digest"
        )
    if any(path not in runtime_paths for path in REVIEWED_RELEASE_TOOL_ROOTS):
        raise ChecksumError(
            "release-tool roots must all belong to the reviewed runtime role"
        )
    observed_imported_values: set[tuple[str, str, str, str]] = set()
    observed_imported_shadows: set[tuple[str, str, str, str]] = set()
    observed_external_modules: set[str] = set()
    dependency_graph: dict[Path, set[Path]] = {}
    reviewed_rows: list[dict[str, Any]] = []
    for path in RELEASE_TOOL_CALL_POLICY_PATHS:
        local_dependencies: set[Path] = set()
        reviewed_rows.append(
            _release_tool_call_policy_row(
                repo_root,
                path,
                RELEASE_TOOL_CALL_POLICY_ROLES[path],
                source_bytes=(
                    _release_tool_call_policy_snapshot_bytes(
                        source_snapshots,
                        path,
                        repo_root=repo_root,
                    )
                    if source_snapshots is not None
                    else None
                ),
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
    if observed_runtime != runtime_paths:
        missing = sorted(
            path.as_posix() for path in runtime_paths - observed_runtime
        )
        unexpected = sorted(
            path.as_posix() for path in observed_runtime - runtime_paths
        )
        raise ChecksumError(
            "release-tool snapshot runtime closure differs from the exact "
            f"reviewed role: missing={missing}; unexpected={unexpected}"
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
        raise ChecksumError(
            "release-tool external-module inventory differs from the exact "
            f"observed set: missing={missing}; unexpected={unexpected}"
        )
    external_modules = sorted(RELEASE_TOOL_CALL_POLICY_EXTERNAL_MODULES)
    external_modules_digest = hashlib.sha256(
        ("\n".join(external_modules) + "\n").encode("utf-8")
    ).hexdigest()
    if (
        len(external_modules) != 29
        or external_modules_digest
        != REVIEWED_RELEASE_TOOL_EXTERNAL_MODULES_SHA256
    ):
        raise ChecksumError(
            "release-tool external-module literal differs from the exact "
            "29-module canonical digest"
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
        raise ChecksumError(
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
        raise ChecksumError(
            "release-tool imported-shadow inventory differs from the exact "
            f"literal allowlist: missing={missing}; unexpected={unexpected}"
        )
    return {
        "schema_version": RELEASE_TOOL_CALL_POLICY_SCHEMA,
        "generator_version": RELEASE_TOOL_CALL_POLICY_GENERATOR_VERSION,
        "runtime_roots": [
            path.as_posix() for path in REVIEWED_RELEASE_TOOL_ROOTS
        ],
        "external_modules": external_modules,
        "reviewed_paths": reviewed_rows,
    }


def _validate_release_tool_call_policy_schema_document(
    schema: dict[str, Any],
) -> None:
    expected: dict[str, Any] = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
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
            "generator_version": {
                "const": RELEASE_TOOL_CALL_POLICY_GENERATOR_VERSION,
            },
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
                "minItems": 29,
                "maxItems": 29,
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
                "minItems": 32,
                "maxItems": 32,
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
                                "const": RELEASE_TOOL_CALL_POLICY_ROLES[
                                    path
                                ],
                            },
                        },
                    }
                    for path in RELEASE_TOOL_CALL_POLICY_PATHS
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
                        "enum": [
                            "runtime",
                            "focused-test",
                        ],
                    },
                    "source_sha256": {
                        "type": "string",
                        "pattern": "^[0-9a-f]{64}$",
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
                        "items": {
                            "$ref": "#/$defs/callRecord",
                        },
                    },
                },
            },
            "recordMultiset": {
                "type": "array",
                "uniqueItems": True,
                "items": {
                    "$ref": "#/$defs/countRecord",
                },
            },
            "countRecord": {
                "type": "object",
                "additionalProperties": False,
                "required": [
                    "record",
                    "count",
                ],
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
                        "pattern": "^[0-9a-f]{64}$",
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
        raise ChecksumError(
            "release-tool call policy schema differs from the exact strict "
            "Draft 2020-12 shape"
        )


def _validate_release_tool_call_policy_paths(
    policy: dict[str, Any],
) -> None:
    """Reject non-canonical reviewed script path spellings."""

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
            raise ChecksumError(
                "release-tool call policy reviewed_paths"
                f"[{index}].path must be a normalized scripts/.../*.py path"
            )


def validate_release_tool_call_policy(
    repo_root: Path,
    *,
    policy_bytes: bytes | None = None,
    schema_bytes: bytes | None = None,
    source_snapshots: dict[str, CoveredFileSnapshot] | None = None,
) -> tuple[Path, ...]:
    """Require the committed policy to equal a fresh bounded AST extraction."""

    if source_snapshots is not None:
        if policy_bytes is None:
            policy_bytes = _release_tool_call_policy_snapshot_bytes(
                source_snapshots,
                RELEASE_TOOL_CALL_POLICY_PATH,
                repo_root=repo_root,
            )
        if schema_bytes is None:
            schema_bytes = _release_tool_call_policy_snapshot_bytes(
                source_snapshots,
                RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
                repo_root=repo_root,
            )
    elif policy_bytes is None or schema_bytes is None:
        snapshots = _read_covered_file_snapshots(
            repo_root,
            [
                RELEASE_TOOL_CALL_POLICY_PATH,
                RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH,
            ],
        )
        if policy_bytes is None:
            policy_bytes = snapshots[
                RELEASE_TOOL_CALL_POLICY_PATH.as_posix()
            ].data
        if schema_bytes is None:
            schema_bytes = snapshots[
                RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH.as_posix()
            ].data
    schema = _release_tool_call_policy_json_object(
        schema_bytes,
        label=RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH.as_posix(),
    )
    _validate_release_tool_call_policy_schema_document(schema)
    actual = _release_tool_call_policy_json_object(
        policy_bytes,
        label=RELEASE_TOOL_CALL_POLICY_PATH.as_posix(),
    )
    if json_text(actual).encode("utf-8") != policy_bytes:
        raise ChecksumError(
            "release-tool call policy must use canonical JSON formatting"
        )
    _validate_release_tool_call_policy_paths(actual)
    expected = build_release_tool_call_policy(
        repo_root,
        source_snapshots=source_snapshots,
    )
    if actual != expected:
        expected_rows = {
            row["path"]: row
            for row in expected["reviewed_paths"]
        }
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
        missing = sorted(set(expected_rows) - set(actual_rows))
        unexpected = sorted(set(actual_rows) - set(expected_rows))
        changed = sorted(
            path
            for path in set(expected_rows) & set(actual_rows)
            if expected_rows[path] != actual_rows[path]
        )
        raise ChecksumError(
            "release-tool call policy differs from the bounded static "
            f"inventory: missing={missing}; unexpected={unexpected}; "
            f"changed={changed}"
        )
    return RELEASE_TOOL_CALL_POLICY_PATHS


def check_release_tool_call_policy(repo_root: Path) -> int:
    try:
        validate_release_tool_call_policy(repo_root)
    except ChecksumError as exc:
        print(f"release-tool call policy is out of date: {exc}", file=sys.stderr)
        return 1
    print("release-tool call policy is current")
    return 0


def write_release_tool_call_policy(repo_root: Path) -> Path:
    schema_path = repo_root / RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH
    try:
        schema_bytes = schema_path.read_bytes()
    except OSError as exc:
        raise ChecksumError(
            "cannot read release-tool call policy schema: "
            f"{RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH.as_posix()}"
        ) from exc
    schema = _release_tool_call_policy_json_object(
        schema_bytes,
        label=RELEASE_TOOL_CALL_POLICY_SCHEMA_PATH.as_posix(),
    )
    _validate_release_tool_call_policy_schema_document(schema)
    policy_path = repo_root / RELEASE_TOOL_CALL_POLICY_PATH
    policy_bytes = json_text(
        build_release_tool_call_policy(repo_root)
    ).encode("utf-8")
    _atomic_write_output(repo_root, policy_path, policy_bytes)
    validate_release_tool_call_policy(
        repo_root,
        policy_bytes=policy_bytes,
        schema_bytes=schema_bytes,
    )
    return policy_path


def validate_release_tool_checksum_closure(
    repo_root: Path,
    covered_paths: list[Path],
    *,
    source_snapshots: dict[str, CoveredFileSnapshot] | None = None,
) -> tuple[Path, ...]:
    """Fail closed unless reviewed release tools/tests are exact file entries."""

    if source_snapshots is None:
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
    else:
        for path in RELEASE_TOOL_CALL_POLICY_PATHS:
            _release_tool_call_policy_snapshot_bytes(
                source_snapshots,
                path,
                repo_root=repo_root,
            )
        runtime_closure = REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
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
    validate_release_tool_call_policy(
        repo_root,
        source_snapshots=source_snapshots,
    )
    return runtime_closure


def validate_canonical_release_checksum_policy(
    repo_root: Path,
    covered_paths: list[Path],
    *,
    source_snapshots: dict[str, CoveredFileSnapshot] | None = None,
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
    if source_snapshots is None:
        return REVIEWED_RELEASE_TOOL_RUNTIME_CLOSURE
    return validate_release_tool_checksum_closure(
        repo_root,
        normalized_paths,
        source_snapshots=source_snapshots,
    )


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


def _validated_coverage_root(
    repo_root: Path,
    configured_path: Path,
    directory_entries: dict[Path, set[str]],
) -> Path:
    lexical_root = Path(os.path.abspath(repo_root))
    root = _validated_repository_root(repo_root)

    if configured_path.is_absolute():
        lexical_candidate = configured_path.absolute()
        try:
            relative = lexical_candidate.relative_to(lexical_root)
        except ValueError:
            try:
                relative = lexical_candidate.relative_to(root)
            except ValueError as exc:
                raise ChecksumError(
                    f"covered path escapes repository: {configured_path}"
                ) from exc
    else:
        relative = configured_path
    if (
        not relative.parts
        or any(part in {"", ".", ".."} for part in relative.parts)
    ):
        raise ChecksumError(
            f"covered path must be normalized: {configured_path}"
        )

    current = root
    for part in relative.parts:
        names = directory_entries.get(current)
        if names is None:
            try:
                names = {entry.name for entry in current.iterdir()}
            except OSError as exc:
                raise ChecksumError(
                    f"cannot enumerate covered path parent: {current}"
                ) from exc
            directory_entries[current] = names
        if part not in names:
            alias = root / relative
            if alias.exists():
                raise ChecksumError(
                    "covered path must use exact on-disk path spelling: "
                    f"{configured_path}"
                )
            raise ChecksumError(f"covered path does not exist: {configured_path}")
        current = current / part
        if _is_reparse_point(current):
            raise ChecksumError(
                "covered path must not include symlink/reparse components: "
                f"{configured_path}"
            )
    if not current.is_file() and not current.is_dir():
        raise ChecksumError(
            f"covered path is neither a regular file nor directory: {configured_path}"
        )
    try:
        resolved = current.resolve(strict=True)
        resolved.relative_to(root)
    except (FileNotFoundError, OSError, ValueError) as exc:
        raise ChecksumError(
            f"covered path resolves outside repository: {configured_path}"
        ) from exc
    if resolved != current:
        raise ChecksumError(f"covered path must not redirect: {configured_path}")
    return current


def _validated_output_directory(repo_root: Path, output_dir: Path) -> Path:
    lexical_root = Path(os.path.abspath(repo_root))
    root = _validated_repository_root(repo_root)

    if output_dir.is_absolute():
        lexical_output = output_dir.absolute()
        try:
            relative = lexical_output.relative_to(lexical_root)
        except ValueError:
            try:
                relative = lexical_output.relative_to(root)
            except ValueError as exc:
                raise ChecksumError(
                    f"release checksum output directory escapes repository: {output_dir}"
                ) from exc
    else:
        relative = output_dir
    if (
        not relative.parts
        or any(part in {"", ".", ".."} for part in relative.parts)
    ):
        raise ChecksumError(
            f"release checksum output directory must be normalized: {output_dir}"
        )

    current = root
    for part in relative.parts:
        if not current.exists():
            break
        try:
            names = {entry.name for entry in current.iterdir()}
        except OSError as exc:
            raise ChecksumError(
                f"cannot enumerate release checksum output parent: {current}"
            ) from exc
        if part not in names:
            alias = root / relative
            if alias.exists():
                raise ChecksumError(
                    "release checksum output directory must use exact on-disk "
                    f"path spelling: {output_dir}"
                )
            break
        current = current / part
        if _is_reparse_point(current):
            raise ChecksumError(
                "release checksum output directory must not include "
                f"symlink/reparse components: {output_dir}"
            )
        if current.exists() and not current.is_dir():
            raise ChecksumError(
                f"release checksum output path is not a directory: {output_dir}"
            )
    return root / relative


def _validate_existing_output_files(output_dir: Path) -> None:
    if not output_dir.exists():
        return
    try:
        names = {entry.name for entry in output_dir.iterdir()}
    except OSError as exc:
        raise ChecksumError(
            f"cannot enumerate release checksum output directory: {output_dir}"
        ) from exc
    for name in (CHECKSUM_FILE_NAME, CHECKSUM_MANIFEST_NAME):
        path = output_dir / name
        casefold_matches = sorted(
            candidate for candidate in names
            if candidate.casefold() == name.casefold()
        )
        if casefold_matches not in ([], [name]):
            raise ChecksumError(
                "release checksum output file has case-ambiguous path spelling: "
                f"expected {name}, found {casefold_matches}"
            )
        if name not in names:
            if path.exists():
                raise ChecksumError(
                    "release checksum output file must use exact on-disk path "
                    f"spelling: {path}"
                )
            continue
        try:
            metadata = os.lstat(path)
        except OSError as exc:
            raise ChecksumError(
                f"cannot inspect release checksum output file: {path}"
            ) from exc
        if (
            path.is_symlink()
            or (
                getattr(metadata, "st_file_attributes", 0)
                & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
            )
        ):
            raise ChecksumError(
                f"release checksum output file must not redirect: {path}"
            )
        if not stat.S_ISREG(metadata.st_mode):
            raise ChecksumError(
                f"release checksum output file must be regular: {path}"
            )
        if metadata.st_nlink != 1:
            raise ChecksumError(
                f"release checksum output file must have one link: {path}"
            )


def _atomic_write_output(repo_root: Path, path: Path, data: bytes) -> None:
    temporary_path: Path | None = None
    try:
        descriptor, temporary_name = tempfile.mkstemp(
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
        )
        temporary_path = Path(temporary_name)
        with os.fdopen(descriptor, "wb") as handle:
            validated_parent = _validated_output_directory(repo_root, path.parent)
            if validated_parent != path.parent:
                raise ChecksumError(
                    "release checksum output parent changed during atomic write: "
                    f"{path.parent}"
                )
            _validate_existing_output_files(validated_parent)
            temporary_metadata = os.lstat(temporary_path)
            descriptor_metadata = os.fstat(handle.fileno())
            if (
                not stat.S_ISREG(temporary_metadata.st_mode)
                or temporary_metadata.st_nlink != 1
                or (
                    temporary_metadata.st_dev,
                    temporary_metadata.st_ino,
                )
                != (
                    descriptor_metadata.st_dev,
                    descriptor_metadata.st_ino,
                )
            ):
                raise ChecksumError(
                    "release checksum temporary output changed identity: "
                    f"{temporary_path}"
                )
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        validated_parent = _validated_output_directory(repo_root, path.parent)
        if validated_parent != path.parent:
            raise ChecksumError(
                "release checksum output parent changed during atomic write: "
                f"{path.parent}"
            )
        _validate_existing_output_files(validated_parent)
        temporary_metadata = os.lstat(temporary_path)
        if (
            not stat.S_ISREG(temporary_metadata.st_mode)
            or temporary_metadata.st_nlink != 1
        ):
            raise ChecksumError(
                "release checksum temporary output changed identity: "
                f"{temporary_path}"
            )
        os.replace(temporary_path, path)
    except ChecksumError:
        raise
    except OSError as exc:
        raise ChecksumError(
            f"cannot atomically write release checksum output: {path}"
        ) from exc
    finally:
        if temporary_path is not None:
            try:
                temporary_path.unlink(missing_ok=True)
            except OSError:
                pass


def _collect_directory_files_without_redirections(
    repo_root: Path,
    directory: Path,
) -> list[Path]:
    files: list[Path] = []
    pending = [directory]
    while pending:
        current = pending.pop()
        try:
            entries = sorted(current.iterdir(), key=lambda entry: entry.name)
        except OSError as exc:
            raise ChecksumError(
                f"cannot enumerate covered directory: {normalize_path(current, repo_root)}"
            ) from exc
        child_directories: list[Path] = []
        for entry in entries:
            if _is_reparse_point(entry):
                raise ChecksumError(
                    "covered directory must not contain symlink/reparse entries: "
                    f"{normalize_path(entry, repo_root)}"
                )
            if entry.is_file():
                files.append(entry)
            elif entry.is_dir():
                child_directories.append(entry)
            else:
                raise ChecksumError(
                    "covered directory contains a non-regular entry: "
                    f"{normalize_path(entry, repo_root)}"
                )
        pending.extend(reversed(child_directories))
    return files


def collect_files(repo_root: Path, covered_paths: list[Path], output_dir: Path) -> list[Path]:
    excluded = output_paths(output_dir)
    files_by_relative_path: dict[str, Path] = {}
    directory_entries: dict[Path, set[str]] = {}

    for configured_path in covered_paths:
        root = _validated_coverage_root(
            repo_root,
            configured_path,
            directory_entries,
        )

        if root.is_file():
            candidates = [root]
        elif root.is_dir():
            candidates = _collect_directory_files_without_redirections(
                repo_root,
                root,
            )
        else:
            raise ChecksumError(f"covered path is neither a file nor directory: {configured_path}")

        for candidate in candidates:
            if candidate in excluded:
                continue
            for excluded_path in excluded:
                if not excluded_path.exists() or not candidate.exists():
                    continue
                try:
                    aliases_output = os.path.samefile(candidate, excluded_path)
                except OSError as exc:
                    raise ChecksumError(
                        "cannot compare covered path to generated checksum output: "
                        f"{normalize_path(candidate, repo_root)}"
                    ) from exc
                if aliases_output:
                    raise ChecksumError(
                        "covered path must not alias generated checksum output: "
                        f"{normalize_path(candidate, repo_root)}"
                    )
            relative_path = normalize_path(candidate, repo_root)
            if relative_path in files_by_relative_path:
                raise ChecksumError(f"covered path listed more than once: {relative_path}")
            files_by_relative_path[relative_path] = candidate

    if not files_by_relative_path:
        raise ChecksumError("covered paths did not contain any files")

    return [files_by_relative_path[key] for key in sorted(files_by_relative_path)]


def build_checksum_lines(snapshots: list[CoveredFileSnapshot]) -> list[str]:
    return [
        f"{snapshot.sha256.removeprefix('sha256:')}  {snapshot.relative_path}"
        for snapshot in snapshots
    ]


def build_manifest(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    snapshots: list[CoveredFileSnapshot],
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
                "path": snapshot.relative_path,
                "sha256": snapshot.sha256,
                "size_bytes": snapshot.size_bytes,
            }
            for snapshot in snapshots
        ],
    }


def build_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> tuple[str, str]:
    output_dir = _validated_output_directory(repo_root, output_dir)
    _validate_existing_output_files(output_dir)
    canonical_output_dir = _validated_output_directory(
        repo_root,
        repo_root / DEFAULT_OUTPUT_DIR,
    )
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
    if coverage_policy == CANONICAL_COVERAGE_POLICY:
        snapshots_by_path = validate_covered_file_line_endings(repo_root, files)
        validate_canonical_release_checksum_policy(
            repo_root,
            covered_paths,
            source_snapshots=snapshots_by_path,
        )
    else:
        snapshots_by_path = _read_covered_file_snapshots(repo_root, files)
    snapshots = [
        snapshots_by_path[key] for key in sorted(snapshots_by_path)
    ]
    for path, recorded_sha256, source in governed_references:
        relative_path = normalize_path(resolve_repo_path(repo_root, path), repo_root)
        covered = snapshots_by_path.get(relative_path)
        if covered is None:
            raise ChecksumError(
                f"{source} complete reference is excluded from checksum coverage: "
                f"{relative_path}"
            )
        actual_sha256 = covered.sha256.removeprefix("sha256:")
        if actual_sha256 != recorded_sha256:
            raise ChecksumError(
                f"{source} checksum input hash mismatch for {relative_path}"
            )
    checksum_text = "\n".join(build_checksum_lines(snapshots)) + "\n"
    manifest = build_manifest(
        repo_root,
        effective_paths,
        output_dir,
        snapshots,
        checksum_text,
        coverage_policy,
    )
    # Revalidate after input discovery and snapshotting. Those operations are
    # intentionally side-effect free in the canonical implementation, but a
    # redirected output created after the initial preflight must never make a
    # direct build appear valid or survive into a later write/check step.
    output_dir = _validated_output_directory(repo_root, output_dir)
    _validate_existing_output_files(output_dir)
    return checksum_text, json_text(manifest)


def write_outputs(
    repo_root: Path,
    covered_paths: list[Path],
    output_dir: Path,
    *,
    coverage_policy: str = CANONICAL_COVERAGE_POLICY,
) -> list[Path]:
    output_dir = _validated_output_directory(repo_root, output_dir)
    _validate_existing_output_files(output_dir)
    checksum_text, manifest_text = build_outputs(
        repo_root,
        covered_paths,
        output_dir,
        coverage_policy=coverage_policy,
    )
    output_dir = _validated_output_directory(repo_root, output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    output_dir = _validated_output_directory(repo_root, output_dir)
    _validate_existing_output_files(output_dir)

    checksum_path = output_dir / CHECKSUM_FILE_NAME
    manifest_path = output_dir / CHECKSUM_MANIFEST_NAME
    _atomic_write_output(repo_root, checksum_path, checksum_text.encode("utf-8"))
    _atomic_write_output(repo_root, manifest_path, manifest_text.encode("utf-8"))
    return [checksum_path, manifest_path]


def parse_checksum_file(checksum_text: str) -> list[tuple[str, str]]:
    entries = []
    seen_paths: set[str] = set()
    for line_number, line in enumerate(checksum_text.splitlines(), start=1):
        if not line:
            continue
        if "  " not in line:
            raise ChecksumError(f"malformed checksum line {line_number}: missing separator")
        digest, relative_path = line.split("  ", 1)
        if not SHA256_RE.fullmatch(digest):
            raise ChecksumError(f"malformed checksum line {line_number}: invalid sha256")
        path_parts = relative_path.split("/")
        if ".." in path_parts:
            raise ChecksumError(f"malformed checksum line {line_number}: path traversal")
        if (
            not relative_path
            or relative_path.startswith("/")
            or "\\" in relative_path
            or any(part in {"", "."} for part in path_parts)
            or Path(relative_path).drive
            or Path(relative_path).root
            or Path(relative_path).anchor
            or Path(*path_parts).as_posix() != relative_path
        ):
            raise ChecksumError(f"malformed checksum line {line_number}: invalid path")
        if relative_path in seen_paths:
            raise ChecksumError(
                f"malformed checksum line {line_number}: duplicate path {relative_path}"
            )
        seen_paths.add(relative_path)
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
    output_dir = _validated_output_directory(repo_root, output_dir)
    _validate_existing_output_files(output_dir)
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

    try:
        output_dir = _validated_output_directory(repo_root, output_dir)
        _validate_existing_output_files(output_dir)
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
    policy_group = parser.add_mutually_exclusive_group()
    policy_group.add_argument(
        "--refresh-release-tool-call-policy",
        action="store_true",
    )
    policy_group.add_argument(
        "--check-release-tool-call-policy",
        action="store_true",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    repo_root = Path.cwd()
    covered_paths = args.covered_paths or DEFAULT_COVERED_PATHS
    output_dir = args.output_dir
    if (
        args.refresh_release_tool_call_policy
        or args.check_release_tool_call_policy
    ) and (
        args.check
        or args.covered_paths
        or args.coverage_policy != CANONICAL_COVERAGE_POLICY
        or output_dir != DEFAULT_OUTPUT_DIR
    ):
        print(
            "error: release-tool call-policy modes cannot be combined with "
            "checksum generation/check options",
            file=sys.stderr,
        )
        return 1
    if args.check_release_tool_call_policy:
        return check_release_tool_call_policy(repo_root)
    if args.refresh_release_tool_call_policy:
        try:
            path = write_release_tool_call_policy(repo_root)
        except ChecksumError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1
        print(normalize_path(path, repo_root))
        return 0
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
