#!/usr/bin/env python3
"""Focused tests for isolated canonical release builds."""

from __future__ import annotations

import base64
import errno
import hashlib
import copy
import importlib.util
import inspect
import itertools
import json
import os
import re
import ctypes
import struct
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
import zlib
from ctypes import wintypes
from contextlib import (
    ExitStack,
    contextmanager,
    nullcontext,
    redirect_stderr,
    redirect_stdout,
)
from io import StringIO
from pathlib import Path
from typing import Any, Iterator
from unittest.mock import Mock, call, patch

import check_contract_size_budget as size_checker
import check_core_bytecode_spend_policy as core_checker


SCRIPT_PATH = Path(__file__).with_name("build_release_artifacts.py")
REPO_ROOT = SCRIPT_PATH.parent.parent
CHANGELOG_PATH = REPO_ROOT / "CHANGELOG.md"
MAKEFILE_PATH = REPO_ROOT / "Makefile"
CHECK_PS1_PATH = REPO_ROOT / "scripts" / "check.ps1"
CHECK_SH_PATH = REPO_ROOT / "scripts" / "check.sh"
CI_PATH = REPO_ROOT / ".github" / "workflows" / "ci.yml"
README_PATH = REPO_ROOT / "README.md"
TEST_README_PATH = REPO_ROOT / "test" / "README.md"
TOOLING_PATH = REPO_ROOT / "docs" / "tooling.md"
DEPLOYMENT_DOC_PATH = REPO_ROOT / "docs" / "deployment.md"
WARNING_DISPOSITIONS_PATH = REPO_ROOT / "docs" / "warning-dispositions.md"
DEPLOYMENT_README_PATH = REPO_ROOT / "deployments" / "README.md"
RELEASE_ARTIFACTS_README_PATH = REPO_ROOT / "release-artifacts" / "README.md"
SIZE_LOG_PATH = REPO_ROOT / "scripts" / "run_forge_size_log.py"
SIZE_LOG_SPEC = importlib.util.spec_from_file_location(
    "run_forge_size_log",
    SIZE_LOG_PATH,
)
assert SIZE_LOG_SPEC is not None and SIZE_LOG_SPEC.loader is not None
size_log = importlib.util.module_from_spec(SIZE_LOG_SPEC)
SIZE_LOG_SPEC.loader.exec_module(size_log)
SPEC = importlib.util.spec_from_file_location("build_release_artifacts", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)

GENERATOR_PATH = Path(__file__).with_name("generate_release_artifacts.py")
GENERATOR_SPEC = importlib.util.spec_from_file_location(
    "generate_release_artifacts_for_build_test",
    GENERATOR_PATH,
)
assert GENERATOR_SPEC is not None and GENERATOR_SPEC.loader is not None
release_generator = importlib.util.module_from_spec(GENERATOR_SPEC)
GENERATOR_SPEC.loader.exec_module(release_generator)

R4_HERMETIC_CHILD_ENV = "R4_HERMETIC_CHILD"
R4_HERMETIC_CHILD_CWD_ENV = "R4_HERMETIC_CHILD_CWD"
R4_HERMETIC_SELECTED_TEST = (
    "R11AuthoritativeEvidenceTests."
    "test_01_hermetic_python_b_entrypoint_has_no_path_or_user_site_dependency"
)

FAKE_FORGE_VERSION = (
    "forge Version: 1.7.1\n"
    "Commit SHA: fixture\n"
    "Build Timestamp: fixture\n"
    "Build Profile: fixture"
)
OTHER_PLATFORM_FAKE_FORGE_VERSION = FAKE_FORGE_VERSION.replace(
    "Build Timestamp: fixture",
    "Build Timestamp: other-platform-fixture",
)
PORTABLE_FAKE_FORGE_VERSION = FAKE_FORGE_VERSION.replace(
    "Build Timestamp: fixture",
    builder.PORTABLE_FORGE_BUILD_TIMESTAMP,
)


R4_CONSTRUCTOR_AUTHORITY = (
    (
        "StreamArtistArchiveEvidenceStoreV2Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
        ),
        256,
    ),
    (
        "StreamArtistArchiveEvidenceCoordinatorV1Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
        ),
        352,
    ),
    (
        "StreamArtistArchiveEvidenceDirectoryV1Skeleton",
        ("address", "address", "bytes32", "bytes32", "bytes32", "bytes32"),
        192,
    ),
    (
        "StreamArtistArchiveCompatibilityStateV3Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
        ),
        352,
    ),
    (
        "StreamArtistArchiveReadProjectionV1Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
        ),
        288,
    ),
    (
        "StreamArtistArchiveEvidenceAdmissionV3Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
        ),
        704,
    ),
    (
        "StreamArtistArchiveEvidenceMaterializerV1Skeleton",
        (
            "address",
            "bytes32",
            "address",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "address",
            "bytes32",
            "bytes32",
            "bytes32",
            "bytes32",
        ),
        416,
    ),
    (
        "StreamArtistArchiveV2Skeleton",
        ("address", "address", "address", "bytes32"),
        128,
    ),
    (
        "StreamArtistBindingTransitionArchiveVerifierV1Skeleton",
        ("address", "bytes32", "address", "bytes32", "bytes32", "bytes32"),
        192,
    ),
    (
        "StreamArtistBindingProposalArchiveVerifierV1Skeleton",
        ("address", "bytes32", "address", "bytes32", "bytes32", "bytes32"),
        192,
    ),
    (
        "StreamArtistCollaboratorArchiveVerifierV1Skeleton",
        ("address", "bytes32", "address", "bytes32", "bytes32", "bytes32"),
        192,
    ),
    (
        "StreamArtistDirectoryV1Skeleton",
        ("address", "address", "bytes32"),
        96,
    ),
    (
        "StreamArtistBindingLifecycleV1Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
    (
        "StreamArtistCollaboratorIdentityLifecycleV1Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
    (
        "StreamArtistFoundationValidatorAV2Skeleton",
        ("address", "address", "address", "bytes32"),
        128,
    ),
    (
        "StreamArtistFoundationControllerV2Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
    (
        "StreamArtistFutureControllerBCompatibilityV1Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
    (
        "StreamArtistFutureControllerCCompatibilityV1Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
    (
        "StreamArtistFoundationReadFacadeV1Skeleton",
        ("address", "address", "address", "address", "address", "bytes32"),
        192,
    ),
)

R4_SIZE_GATES = (
    ("StreamArtistArchiveEvidenceStoreV2Skeleton", 19_968, ()),
    ("StreamArtistArchiveEvidenceCoordinatorV1Skeleton", 20_480, ()),
    (
        "StreamArtistArchiveEvidenceDirectoryV1Skeleton",
        18_432,
        ("AGG_G3_RUNTIME", "AGG_G3_DEPOSIT"),
    ),
    ("StreamArtistArchiveCompatibilityStateV3Skeleton", 21_040, ()),
    ("StreamArtistArchiveReadProjectionV1Skeleton", 16_384, ()),
    ("StreamArtistArchiveEvidenceAdmissionV3Skeleton", 20_528, ()),
    (
        "StreamArtistArchiveEvidenceMaterializerV1Skeleton",
        18_432,
        ("AGG_G7_RUNTIME", "AGG_G7_DEPOSIT"),
    ),
    (
        "StreamArtistArchiveV2Skeleton",
        22_064,
        (
            "AGG_G8_READ_RUNTIME",
            "AGG_G8_READ_DEPOSIT",
            "AGG_G8_EIGHT_RUNTIME",
            "AGG_G8_EIGHT_DEPOSIT",
        ),
    ),
    ("StreamArtistBindingTransitionArchiveVerifierV1Skeleton", 22_064, ()),
    ("StreamArtistBindingProposalArchiveVerifierV1Skeleton", 22_064, ()),
    (
        "StreamArtistCollaboratorArchiveVerifierV1Skeleton",
        22_064,
        (
            "AGG_G11_VERIFIER_RUNTIME",
            "AGG_G11_FULL_INITCODE",
            "AGG_G11_DEPOSIT",
        ),
    ),
    ("StreamArtistDirectoryV1Skeleton", 22_064, ()),
    ("StreamArtistBindingLifecycleV1Skeleton", 22_064, ()),
    ("StreamArtistCollaboratorIdentityLifecycleV1Skeleton", 22_064, ()),
    ("StreamArtistFoundationValidatorAV2Skeleton", 22_064, ()),
    ("StreamArtistFoundationControllerV2Skeleton", 22_064, ()),
    ("StreamArtistFutureControllerBCompatibilityV1Skeleton", 22_064, ()),
    ("StreamArtistFutureControllerCCompatibilityV1Skeleton", 22_064, ()),
    ("StreamArtistFoundationReadFacadeV1Skeleton", 22_064, ()),
)

R4_BYTECODE_STEP_IDS = (
    "CREATION_CONTAINER",
    "CREATION_OBJECT_STRING",
    "NORMALIZE_CREATION_PREFIX",
    "CREATION_NONEMPTY",
    "CREATION_EVEN_LENGTH",
    "CREATION_PLACEHOLDER_ABSENT",
    "CREATION_FULL_HEX",
    "CREATION_LINK_REFERENCES_EMPTY",
    "RUNTIME_CONTAINER",
    "RUNTIME_OBJECT_STRING",
    "NORMALIZE_RUNTIME_PREFIX",
    "RUNTIME_NONEMPTY",
    "RUNTIME_EVEN_LENGTH",
    "RUNTIME_PLACEHOLDER_ABSENT",
    "RUNTIME_FULL_HEX",
    "RUNTIME_LINK_REFERENCES_EMPTY",
    "CONSTRUCTOR_ABI_SHAPE",
    "DERIVE_CONSTRUCTOR_METRICS",
    "CONSTRUCTOR_METRICS_EXACT",
    "DECODE_CREATION_BYTES",
    "COMPUTE_FULL_INITCODE",
    "FULL_INITCODE_LIMIT",
    "DECODE_RUNTIME_BYTES",
    "RUNTIME_PACKET_LIMIT",
    "RUNTIME_TARGET_CAP",
    "COMPUTE_CODE_DEPOSIT_GAS",
)

R11_LITERAL_TARGET_STATE_KEYS = (
    "semantic_id", "target", "source", "size_ordinal", "emitting_group",
    "file_read", "artifact_byte_count", "artifact_sha256",
    "artifact_json_decoded", "metadata_evaluated", "metadata_admitted",
    "bytecode_evaluated", "bytecode_completed", "bytecode_steps",
)
R11_LITERAL_EVENT_SCHEMA = "6529stream.release-builder-event.v1"
R11_LITERAL_TERMINAL_SCHEMA = "6529stream.release-builder-terminal.v1"
R11_LITERAL_SOURCE_UNION = {
    "count": 31,
    "aggregate_sha256": (
        "sha256:1eb0a58b8a1dca624493839d41fa5267078e7fba67b4ae6df9205dd003659857"
    ),
}
R11_LITERAL_RECOVERY_TERMINAL_RAW = (
    b'{"calls":[],"checkpoints":[],"event_count":2,"event_head_sha256":"sha256:2222222222222222222222222222222222222222222222222222222222222222","first_red":{"code":"interrupted_execution","operands":{}},"invocation_id":"sha256:1111111111111111111111111111111111111111111111111111111111111111","no_retry":true,"results":{"anomalies":[],"output_validated":false,"path_token_status":[],"predicates_evaluated":0,"recovery":true,"sentinel_sha256":"sha256:3333333333333333333333333333333333333333333333333333333333333333","subprocess_calls":0},"schema":"6529stream.release-builder-terminal.v1","status":"NO_GO"}\n'
)
R11_LITERAL_RECOVERY_TOP_KEYS = (
    "schema", "invocation_id", "status", "first_red", "event_count",
    "event_head_sha256", "calls", "checkpoints", "results", "no_retry",
)
R11_LITERAL_RECOVERY_RESULT_KEYS = (
    "recovery", "path_token_status", "anomalies", "sentinel_sha256",
    "predicates_evaluated", "subprocess_calls", "output_validated",
)
R11_LITERAL_RECOVERY_FIRST_RED_KEYS = ("code", "operands")
R11_LITERAL_RECOVERY_ANOMALY_KEYS = (
    "path_token", "status", "exception_type", "message_sha256",
)
R11_LITERAL_BUILDER_FIRST_RED_KEYS = (
    "phase", "code", "call_ordinal", "group_index", "group_string",
    "semantic_id", "target", "step_ordinal", "step_id", "operands",
)
R11_LITERAL_RECORD_PROOF_FIELDS = (
    "code", "operation", "records", "records_sha256", "winner", "root",
    "inventory", "requested_depth", "requested_token", "parent_token",
    "parent_identity", "requested_component", "observed_winner_token",
)
R11_LITERAL_RECORD_PROOF_CODES = frozenset((
    "TRAVERSAL_ROOT_ENTRY_NAME",
    "TRAVERSAL_ROOT_ENTRY_COLLISION",
    "TRAVERSAL_ENTRY_NAME",
    "TRAVERSAL_ENTRY_COLLISION",
    "TRAVERSAL_COMPONENT_MISSING",
    "TRAVERSAL_COMPONENT_CASE_MISMATCH",
    "TRAVERSAL_COMPONENT_SHORT_ALIAS",
))
R11_LITERAL_FOUNDRY_CONFIG_RAW = b"""[profile.default]
src = "smart-contracts"
test = "test"
script = "script"
out = "out"
cache_path = "cache"
libs = ["lib"]
solc_version = "0.8.19"
auto_detect_solc = false
evm_version = "paris"
optimizer = true
optimizer_runs = 200
bytecode_hash = "none"
cbor_metadata = false
additional_compiler_profiles = [
    { name = "governance-via-ir", via_ir = true, optimizer = true, optimizer_runs = 200, evm_version = "paris", bytecode_hash = "None" },
]
compilation_restrictions = [
    { paths = "smart-contracts/{StreamGovernanceExecutor,StreamGovernanceBootstrap,StreamGovernanceEvidence,StreamGovernanceManifest,StreamGovernancePolicy,StreamModuleRegistry,StreamRoleRegistry}.sol", via_ir = true },
    { paths = "test/{StreamGovernanceV2HolderRehearsal.t.sol,helpers/StreamGovernanceV2HolderRehearsalMocks.sol}", via_ir = true },
    { paths = "smart-contracts/{StreamPrimaryRevenueResolverValidationAdapter,StreamRoyaltyRevenueResolverValidationAdapter}.sol", via_ir = true },
    { paths = "smart-contracts/{StreamRoyaltyRevenueResolver,StreamRoyaltyAssignmentController,StreamRoyaltySnapshotController}.sol", via_ir = true },
    { paths = "smart-contracts/{StreamArtistRegistry,StreamArtistRegistryValidatorA,StreamArtistRegistryValidatorB,StreamArtistRegistryValidatorC,StreamArtistMutationControllerA,StreamArtistMutationControllerB,StreamArtistMutationControllerC,StreamArtistArchiveV2}.sol", via_ir = true },
    { paths = "test/StreamRevenueResolverValidationAdapter.t.sol", via_ir = true },
]
fs_permissions = [
    { access = "read", path = "./test/fixtures" },
    { access = "read", path = "./deployments" },
]

[fmt]
line_length = 100
tab_width = 4
bracket_spacing = true
"""
R11_LITERAL_TARGET_CONFIG_ROWS = (
    ("StreamArtistArchiveEvidenceStoreV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceStoreV2Skeleton.sol"),
    ("StreamArtistArchiveEvidenceCoordinatorV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol"),
    ("StreamArtistArchiveEvidenceDirectoryV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol"),
    ("StreamArtistArchiveCompatibilityStateV3Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveCompatibilityStateV3Skeleton.sol"),
    ("StreamArtistArchiveReadProjectionV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveReadProjectionV1Skeleton.sol"),
    ("StreamArtistArchiveEvidenceAdmissionV3Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol"),
    ("StreamArtistArchiveEvidenceMaterializerV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol"),
    ("StreamArtistArchiveV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveV2Skeleton.sol"),
    ("StreamArtistBindingProposalArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol"),
    ("StreamArtistBindingTransitionArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol"),
    ("StreamArtistCollaboratorArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol"),
    ("StreamArtistBindingLifecycleV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingLifecycleV1Skeleton.sol"),
    ("StreamArtistCollaboratorIdentityLifecycleV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol"),
    ("StreamArtistDirectoryV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistDirectoryV1Skeleton.sol"),
    ("StreamArtistFoundationControllerV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistFoundationControllerV2Skeleton.sol"),
    ("StreamArtistFoundationReadFacadeV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFoundationReadFacadeV1Skeleton.sol"),
    ("StreamArtistFoundationValidatorAV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol"),
    ("StreamArtistFutureControllerBCompatibilityV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol"),
    ("StreamArtistFutureControllerCCompatibilityV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol"),
)
R11_LITERAL_TARGET_STATE_ROWS = (
    ("Store", "StreamArtistArchiveEvidenceStoreV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceStoreV2Skeleton.sol", 1, "005", False, None, None, False, False, False, False, False, ()),
    ("Coordinator", "StreamArtistArchiveEvidenceCoordinatorV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol", 2, "002", False, None, None, False, False, False, False, False, ()),
    ("EvidenceDirectory", "StreamArtistArchiveEvidenceDirectoryV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol", 3, "003", False, None, None, False, False, False, False, False, ()),
    ("CompatibilityState", "StreamArtistArchiveCompatibilityStateV3Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveCompatibilityStateV3Skeleton.sol", 4, "000", False, None, None, False, False, False, False, False, ()),
    ("ReadProjection", "StreamArtistArchiveReadProjectionV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveReadProjectionV1Skeleton.sol", 5, "006", False, None, None, False, False, False, False, False, ()),
    ("Admission", "StreamArtistArchiveEvidenceAdmissionV3Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol", 6, "001", False, None, None, False, False, False, False, False, ()),
    ("Materializer", "StreamArtistArchiveEvidenceMaterializerV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol", 7, "004", False, None, None, False, False, False, False, False, ()),
    ("ArchiveV2", "StreamArtistArchiveV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistArchiveV2Skeleton.sol", 8, "007", False, None, None, False, False, False, False, False, ()),
    ("Transition", "StreamArtistBindingTransitionArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol", 9, "010", False, None, None, False, False, False, False, False, ()),
    ("Proposal", "StreamArtistBindingProposalArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol", 10, "009", False, None, None, False, False, False, False, False, ()),
    ("Collaborator", "StreamArtistCollaboratorArchiveVerifierV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol", 11, "011", False, None, None, False, False, False, False, False, ()),
    ("ArtistDirectory", "StreamArtistDirectoryV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistDirectoryV1Skeleton.sol", 12, "013", False, None, None, False, False, False, False, False, ()),
    ("BindingLifecycle", "StreamArtistBindingLifecycleV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistBindingLifecycleV1Skeleton.sol", 13, "008", False, None, None, False, False, False, False, False, ()),
    ("CollaboratorLifecycle", "StreamArtistCollaboratorIdentityLifecycleV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol", 14, "012", False, None, None, False, False, False, False, False, ()),
    ("ValidatorA", "StreamArtistFoundationValidatorAV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol", 15, "016", False, None, None, False, False, False, False, False, ()),
    ("ControllerA", "StreamArtistFoundationControllerV2Skeleton", "smart-contracts/architecture/issue670/StreamArtistFoundationControllerV2Skeleton.sol", 16, "014", False, None, None, False, False, False, False, False, ()),
    ("ControllerB", "StreamArtistFutureControllerBCompatibilityV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol", 17, "016", False, None, None, False, False, False, False, False, ()),
    ("ControllerC", "StreamArtistFutureControllerCCompatibilityV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol", 18, "016", False, None, None, False, False, False, False, False, ()),
    ("ReadFacade", "StreamArtistFoundationReadFacadeV1Skeleton", "smart-contracts/architecture/issue670/StreamArtistFoundationReadFacadeV1Skeleton.sol", 19, "015", False, None, None, False, False, False, False, False, ()),
)

R11_LITERAL_STORE_AUTHORITY = (
    ("semantic_id", "Store"),
    ("target", "StreamArtistArchiveEvidenceStoreV2Skeleton"),
    ("source", "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceStoreV2Skeleton.sol"),
    ("signature", "constructor(address,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)"),
    ("input_types", ("address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")),
    ("words", 8),
    ("bytes", 256),
    ("runtime_cap", 19_968),
)

R11_LITERAL_BYTECODE_FALSE_ROWS = (
    (1, ("BC_CREATION_MISSING", "BC_CREATION_NOT_OBJECT")),
    (2, ("BC_CREATION_OBJECT_MISSING", "BC_CREATION_OBJECT_NOT_STRING")),
    (4, ("BC_CREATION_EMPTY",)),
    (5, ("BC_CREATION_ODD_LENGTH",)),
    (6, ("BC_CREATION_UNRESOLVED_PLACEHOLDER",)),
    (7, ("BC_CREATION_NON_HEX",)),
    (8, ("BC_CREATION_LINKS_MISSING", "BC_CREATION_LINKS_NOT_OBJECT", "BC_CREATION_LINKS_NONEMPTY")),
    (9, ("BC_RUNTIME_MISSING", "BC_RUNTIME_NOT_OBJECT")),
    (10, ("BC_RUNTIME_OBJECT_MISSING", "BC_RUNTIME_OBJECT_NOT_STRING")),
    (12, ("BC_RUNTIME_EMPTY",)),
    (13, ("BC_RUNTIME_ODD_LENGTH",)),
    (14, ("BC_RUNTIME_UNRESOLVED_PLACEHOLDER",)),
    (15, ("BC_RUNTIME_NON_HEX",)),
    (16, ("BC_RUNTIME_LINKS_MISSING", "BC_RUNTIME_LINKS_NOT_OBJECT", "BC_RUNTIME_LINKS_NONEMPTY")),
    (17, ("ABI_NOT_ARRAY", "ABI_CONSTRUCTOR_COUNT", "ABI_CONSTRUCTOR_TYPES_ORDER")),
    (19, ("ABI_CONSTRUCTOR_SIGNATURE", "ABI_CONSTRUCTOR_WORDS", "ABI_CONSTRUCTOR_WIDTH")),
    (22, ("SIZE_INITCODE_LIMIT",)),
    (24, ("SIZE_RUNTIME_PACKET_LIMIT",)),
    (25, ("SIZE_RUNTIME_TARGET_CAP",)),
)
R11_LITERAL_OPERATION_ORDINALS = (3, 11, 18, 20, 21, 23, 26)
R11_LITERAL_BYTECODE_CASE_ROWS = (
    (1, 1, "BC_CREATION_MISSING"),
    (1, 2, "BC_CREATION_NOT_OBJECT"),
    (2, 1, "BC_CREATION_OBJECT_MISSING"),
    (2, 2, "BC_CREATION_OBJECT_NOT_STRING"),
    (3, 1, "OP_NORMALIZE_CREATION_PREFIX_EXCEPTION"),
    (4, 1, "BC_CREATION_EMPTY"),
    (5, 1, "BC_CREATION_ODD_LENGTH"),
    (6, 1, "BC_CREATION_UNRESOLVED_PLACEHOLDER"),
    (7, 1, "BC_CREATION_NON_HEX"),
    (8, 1, "BC_CREATION_LINKS_MISSING"),
    (8, 2, "BC_CREATION_LINKS_NOT_OBJECT"),
    (8, 3, "BC_CREATION_LINKS_NONEMPTY"),
    (9, 1, "BC_RUNTIME_MISSING"),
    (9, 2, "BC_RUNTIME_NOT_OBJECT"),
    (10, 1, "BC_RUNTIME_OBJECT_MISSING"),
    (10, 2, "BC_RUNTIME_OBJECT_NOT_STRING"),
    (11, 1, "OP_NORMALIZE_RUNTIME_PREFIX_EXCEPTION"),
    (12, 1, "BC_RUNTIME_EMPTY"),
    (13, 1, "BC_RUNTIME_ODD_LENGTH"),
    (14, 1, "BC_RUNTIME_UNRESOLVED_PLACEHOLDER"),
    (15, 1, "BC_RUNTIME_NON_HEX"),
    (16, 1, "BC_RUNTIME_LINKS_MISSING"),
    (16, 2, "BC_RUNTIME_LINKS_NOT_OBJECT"),
    (16, 3, "BC_RUNTIME_LINKS_NONEMPTY"),
    (17, 1, "ABI_NOT_ARRAY"),
    (17, 2, "ABI_CONSTRUCTOR_COUNT"),
    (17, 3, "ABI_CONSTRUCTOR_TYPES_ORDER"),
    (18, 1, "OP_DERIVE_CONSTRUCTOR_METRICS_EXCEPTION"),
    (19, 1, "ABI_CONSTRUCTOR_SIGNATURE"),
    (19, 2, "ABI_CONSTRUCTOR_WORDS"),
    (19, 3, "ABI_CONSTRUCTOR_WIDTH"),
    (20, 1, "OP_DECODE_CREATION_BYTES_EXCEPTION"),
    (21, 1, "OP_COMPUTE_FULL_INITCODE_EXCEPTION"),
    (22, 1, "SIZE_INITCODE_LIMIT"),
    (23, 1, "OP_DECODE_RUNTIME_BYTES_EXCEPTION"),
    (24, 1, "SIZE_RUNTIME_PACKET_LIMIT"),
    (25, 1, "SIZE_RUNTIME_TARGET_CAP"),
    (26, 1, "OP_COMPUTE_CODE_DEPOSIT_GAS_EXCEPTION"),
)
R11_LITERAL_AGGREGATE_ROWS = (
    (3, "AGG_G3_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory"), "runtime_bytes", 58_880),
    (3, "AGG_G3_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory"), "code_deposit_gas", 11_776_000),
    (7, "AGG_G7_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "Admission", "Materializer"), "runtime_bytes", 118_880),
    (7, "AGG_G7_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "Admission", "Materializer"), "code_deposit_gas", 23_776_000),
    (8, "AGG_G8_READ_RUNTIME", ("Store", "CompatibilityState", "ReadProjection", "ArchiveV2"), "runtime_bytes", 79_456),
    (8, "AGG_G8_READ_DEPOSIT", ("Store", "CompatibilityState", "ReadProjection", "ArchiveV2"), "code_deposit_gas", 15_891_200),
    (8, "AGG_G8_EIGHT_RUNTIME", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "ReadProjection", "Admission", "Materializer", "ArchiveV2"), "runtime_bytes", 157_328),
    (8, "AGG_G8_EIGHT_DEPOSIT", ("Store", "Coordinator", "EvidenceDirectory", "CompatibilityState", "ReadProjection", "Admission", "Materializer", "ArchiveV2"), "code_deposit_gas", 31_465_600),
    (11, "AGG_G11_VERIFIER_RUNTIME", ("Transition", "Proposal", "Collaborator"), "runtime_bytes", 65_000),
    (11, "AGG_G11_FULL_INITCODE", ("Transition", "Proposal", "Collaborator"), "full_initcode_bytes", 66_500),
    (11, "AGG_G11_DEPOSIT", ("Transition", "Proposal", "Collaborator"), "code_deposit_gas", 13_000_000),
)

_R11_TEXT_ZERO_SHA = "sha256:f1534392279bddbf9d43dde8701cb5be14b82f76ec6607bf8d6ad557f60f304e"
_R11_BYTE_ZERO_SHA = "sha256:6e340b9cffb37a989ca544e6bb780a2c78901d3fb33738768511a30617afa01d"
_R11_STORE_TARGET = "StreamArtistArchiveEvidenceStoreV2Skeleton"
_R11_STORE_TYPES = ("address", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32")
_R11_STORE_SIGNATURE = "constructor(address,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32)"
R11_LITERAL_STORE_TRACE_ROWS = (
    (1, "CREATION_CONTAINER", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "object")), True, None),
    (2, "CREATION_OBJECT_STRING", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "string")), True, None),
    (3, "NORMALIZE_CREATION_PREFIX", "operation", "pass", (("target", _R11_STORE_TARGET), ("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA)), (("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA), ("output_length", 2), ("output_sha256", _R11_TEXT_ZERO_SHA), ("prefix_removed", False)), None),
    (4, "CREATION_NONEMPTY", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (5, "CREATION_EVEN_LENGTH", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (6, "CREATION_PLACEHOLDER_ABSENT", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (7, "CREATION_FULL_HEX", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (8, "CREATION_LINK_REFERENCES_EMPTY", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "object"), ("entry_count", 0)), True, None),
    (9, "RUNTIME_CONTAINER", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "object")), True, None),
    (10, "RUNTIME_OBJECT_STRING", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "string")), True, None),
    (11, "NORMALIZE_RUNTIME_PREFIX", "operation", "pass", (("target", _R11_STORE_TARGET), ("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA)), (("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA), ("output_length", 2), ("output_sha256", _R11_TEXT_ZERO_SHA), ("prefix_removed", False)), None),
    (12, "RUNTIME_NONEMPTY", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (13, "RUNTIME_EVEN_LENGTH", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (14, "RUNTIME_PLACEHOLDER_ABSENT", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (15, "RUNTIME_FULL_HEX", "predicate", "pass", (("target", _R11_STORE_TARGET), ("length", 2), ("sha256", _R11_TEXT_ZERO_SHA)), True, None),
    (16, "RUNTIME_LINK_REFERENCES_EMPTY", "predicate", "pass", (("target", _R11_STORE_TARGET), ("present", True), ("actual_type", "object"), ("entry_count", 0)), True, None),
    (17, "CONSTRUCTOR_ABI_SHAPE", "predicate", "pass", (("target", _R11_STORE_TARGET), ("abi_present", True), ("abi_type", "array"), ("constructor_count", 1), ("inputs_present", True), ("inputs_type", "array"), ("actual_types", _R11_STORE_TYPES), ("expected_types", _R11_STORE_TYPES)), True, None),
    (18, "DERIVE_CONSTRUCTOR_METRICS", "operation", "pass", (("target", _R11_STORE_TARGET), ("input_types", _R11_STORE_TYPES)), (("signature", _R11_STORE_SIGNATURE), ("words", 8), ("bytes", 256)), None),
    (19, "CONSTRUCTOR_METRICS_EXACT", "predicate", "pass", (("target", _R11_STORE_TARGET), ("actual_signature", _R11_STORE_SIGNATURE), ("expected_signature", _R11_STORE_SIGNATURE), ("actual_words", 8), ("expected_words", 8), ("actual_bytes", 256), ("expected_bytes", 256)), True, None),
    (20, "DECODE_CREATION_BYTES", "operation", "pass", (("target", _R11_STORE_TARGET), ("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA)), (("byte_count", 1), ("sha256", _R11_BYTE_ZERO_SHA)), None),
    (21, "COMPUTE_FULL_INITCODE", "operation", "pass", (("target", _R11_STORE_TARGET), ("creation_bytes", 1), ("constructor_bytes", 256)), (("creation_bytes", 1), ("constructor_bytes", 256), ("full_initcode_bytes", 257)), None),
    (22, "FULL_INITCODE_LIMIT", "predicate", "pass", (("target", _R11_STORE_TARGET), ("actual", 257), ("operator", "<"), ("threshold", 49_152)), True, None),
    (23, "DECODE_RUNTIME_BYTES", "operation", "pass", (("target", _R11_STORE_TARGET), ("input_length", 2), ("input_sha256", _R11_TEXT_ZERO_SHA)), (("byte_count", 1), ("sha256", _R11_BYTE_ZERO_SHA)), None),
    (24, "RUNTIME_PACKET_LIMIT", "predicate", "pass", (("target", _R11_STORE_TARGET), ("actual", 1), ("operator", "<"), ("threshold", 24_576)), True, None),
    (25, "RUNTIME_TARGET_CAP", "predicate", "pass", (("target", _R11_STORE_TARGET), ("actual", 1), ("operator", "<="), ("threshold", 19_968)), True, None),
    (26, "COMPUTE_CODE_DEPOSIT_GAS", "operation", "pass", (("target", _R11_STORE_TARGET), ("runtime_bytes", 1), ("gas_per_byte", 200)), (("runtime_bytes", 1), ("gas_per_byte", 200), ("code_deposit_gas", 200)), None),
)
R11_LITERAL_SOURCE_PATHS = (
    "smart-contracts/architecture/issue670/IStreamArtistFoundationOwnershipV1.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveCompatibilityStateV3Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceStoreV2Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveReadProjectionV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistArchiveV2Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistBindingLifecycleV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistDirectoryV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistFoundationControllerV2Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistFoundationReadFacadeV1Skeleton.sol",
    "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol",
    "smart-contracts/architecture/issue670/StreamArtistLifecycleSkeletonBase.sol",
    "smart-contracts/IERC165.sol",
    "smart-contracts/IStreamArtistArchiveV2.sol",
    "smart-contracts/IStreamArtistConsent.sol",
    "smart-contracts/IStreamArtistRead.sol",
    "smart-contracts/IStreamArtistRecoveryEvidence.sol",
    "smart-contracts/IStreamArtistRegistry.sol",
    "smart-contracts/IStreamArtistRegistryValidationCommon.sol",
    "smart-contracts/IStreamArtistRegistryWritesA.sol",
    "smart-contracts/IStreamArtistRegistryWritesB.sol",
    "smart-contracts/IStreamArtistRegistryWritesC.sol",
    "smart-contracts/IStreamGasParameterHost.sol",
    "smart-contracts/IStreamGovernanceExecutor.sol",
)
R11_LITERAL_SOURCE_RECEIPTS = {
    "smart-contracts/architecture/issue670/IStreamArtistFoundationOwnershipV1.sol": (48_191, "sha256:8bd67534c85693cd6087ed37d9b8830ce45ad4750f700914f1a6272fd78f598b"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveCompatibilityStateV3Skeleton.sol": (48_310, "sha256:c7b9471ec1db9c5a6056bf80e56ec9d0bee5f03127d83020ba71b83072859541"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol": (50_455, "sha256:4bc25f3a05ea54ab4e9c27bdc37270f00e07a6f19bbba7fd60f3056b7be24f99"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol": (57_331, "sha256:c95d051ef1bf8a7f99a1a786417a199f8f87f61c262d3efe57ee3a3c039aa6b4"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol": (45_717, "sha256:a294e777d3b9ea2f3cdf4e58e6ef65018c40a8fa7b66d912a0c58eac8c654067"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol": (51_956, "sha256:4b536da02a6055a040031c9da96cd3e315439fcde7ad390c0e788f64cea52974"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveEvidenceStoreV2Skeleton.sol": (55_845, "sha256:c9f15c9cfb057469a37ce46e9f843984fd1eda17c3a3cc9e49e975de8609c8fd"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveReadProjectionV1Skeleton.sol": (27_108, "sha256:e4b614d3b3fb78e70c2875ce9416786f6a94a36894a4a12cc15a0991d369d5a2"),
    "smart-contracts/architecture/issue670/StreamArtistArchiveV2Skeleton.sol": (78_843, "sha256:5df5d141af864e4b558aa1cca4bcc2a1163129ac439f2f57f749bd3eb9ab091d"),
    "smart-contracts/architecture/issue670/StreamArtistBindingLifecycleV1Skeleton.sol": (12_718, "sha256:324ee72f0f06b9541239a61a25006048180814db4c6e19ecdb0c06000d7c112c"),
    "smart-contracts/architecture/issue670/StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol": (41_583, "sha256:c56a8233fac5ffa8a0f5b05c5f6bcb56ef0b95db23e1dabc52989c1ab1a2dc61"),
    "smart-contracts/architecture/issue670/StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol": (44_907, "sha256:8e3cd391e0db869d760bfca20ac5015a86deeab439bf845f86346c27cea89c9f"),
    "smart-contracts/architecture/issue670/StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol": (42_932, "sha256:721db11490119746262e5cafd5f72da9da0e68d626e991fa194e054dea74b54a"),
    "smart-contracts/architecture/issue670/StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol": (7_443, "sha256:ebc2577f499741f60b2aec732c0b978c486fe13e26cd79936bec1fd190a3f38c"),
    "smart-contracts/architecture/issue670/StreamArtistDirectoryV1Skeleton.sol": (16_431, "sha256:5e2e7edc1d9d313a4acf33a43ca84c28f01ee558283569fae0c3359113054753"),
    "smart-contracts/architecture/issue670/StreamArtistFoundationControllerV2Skeleton.sol": (22_469, "sha256:f050911f0e39d1ac7a0f3b86320ccdd12500e8680579aabee484fc7f0db5d43b"),
    "smart-contracts/architecture/issue670/StreamArtistFoundationReadFacadeV1Skeleton.sol": (45_669, "sha256:fddd720029c552aa6875cf4ef0b062b8e8b4df8850f988d2b77c033b5b17ecba"),
    "smart-contracts/architecture/issue670/StreamArtistFutureControllerCompatibilitySkeletons.sol": (24_480, "sha256:ad34af089c673319d232a81a773b31715254b5b9e940efcbd5da3ef4314996bb"),
    "smart-contracts/architecture/issue670/StreamArtistLifecycleSkeletonBase.sol": (25_369, "sha256:764f80b2c3eae1b6807f8a6cd8cf71d9fb691f13ac12299d8ebd61fb5826aaa1"),
    "smart-contracts/IERC165.sol": (852, "sha256:92762629f91532d937e795ceee7391d5e4e9db0ca8eba233da3dd1e95ce9d792"),
    "smart-contracts/IStreamArtistArchiveV2.sol": (8_549, "sha256:9cd8b9d58baa34ef013d2e4fb890fb28afa7cecd961fa755933d189887097d46"),
    "smart-contracts/IStreamArtistConsent.sol": (1_794, "sha256:4ded4a81060392138d979288a79343c25a953b40359da99d673228d0b961bcdc"),
    "smart-contracts/IStreamArtistRead.sol": (2_441, "sha256:8ceef82a001d625cd478ad0c61a94c9bc9480c1003f71a7fa088415bb9689978"),
    "smart-contracts/IStreamArtistRecoveryEvidence.sol": (2_108, "sha256:3d9fed52db05f33e8e21ca9ac486e5921558167d8c0773fd1d4b1a6f7f14765f"),
    "smart-contracts/IStreamArtistRegistry.sol": (6_930, "sha256:bed2bb4c8d4911e563bf12809b396a9e9158581b5c589e2ed98e7cdbb98a6d52"),
    "smart-contracts/IStreamArtistRegistryValidationCommon.sol": (1_754, "sha256:0a17e180c084e539c69b53c5570ac22afd7e4a57ddc9cf96bb2055a0cb294782"),
    "smart-contracts/IStreamArtistRegistryWritesA.sol": (3_962, "sha256:e751b34abba37a36fde60e7af4f80669101504d54e3b34a400d3b43c5eb3f577"),
    "smart-contracts/IStreamArtistRegistryWritesB.sol": (3_532, "sha256:4c85a57d0666dee3d205a145570525e8b5a648ca1de803e7b4051d46a92b75cb"),
    "smart-contracts/IStreamArtistRegistryWritesC.sol": (2_518, "sha256:289631c61678a8773337a81dbf4072f23f4e641ae1a0e4105a6fa12074ef66b1"),
    "smart-contracts/IStreamGasParameterHost.sol": (3_296, "sha256:a50e29b292e8d93068617548806aab531bb7595cbce9ce3127f9b05f2572951f"),
    "smart-contracts/IStreamGovernanceExecutor.sol": (37_763, "sha256:9a560534c84a6a27f881c005dd36e329cc89ecb9c76604ab06757d7196a2aead"),
}
R11_LITERAL_SOURCE_BUNDLE_DECODED_BYTES = 823_256
R11_LITERAL_SOURCE_BUNDLE_DECODED_SHA256 = (
    "sha256:132121aeb93456d093b3bd6d87342abeb9a0cb5b104339480e8ed184cd8a7159"
)
R11_LITERAL_SOURCE_BUNDLE_COMPRESSED_BYTES = 122_048
R11_LITERAL_SOURCE_BUNDLE_COMPRESSED_SHA256 = (
    "sha256:219970657b2fedbbf4eedcb80f389babe2e223ba1afa1e0555bcd1292e548fcd"
)
R11_LITERAL_SOURCE_BUNDLE_ENCODED_BYTES = 152_560
R11_LITERAL_SOURCE_BUNDLE_ENCODED_SHA256 = (
    "sha256:bd5b1ee1a385b30111d18341b76ab78887e1ddb57992d8e7dcda1f76b00e28dc"
)
R11_LITERAL_SOURCE_BUNDLE_CHUNK_BYTES = 100
R11_LITERAL_SOURCE_BUNDLE_CHUNK_COUNT = 1_526
R11_LITERAL_SOURCE_BUNDLE_BASE85 = (
    b'c-ri}YjYeok|_F}zoO)byFnhe=z2e_k!NX&9x+CgbxDq9<~Y0zR253<5y|FuH)UyOeSiB+)Dw>c3f0}DHM{oNGd8<`L?V$d0Ex_R',
    b'zHu(zy!hMGSM!42uISU#lHRW8)toNBb<R#N_wJVD-3@V8i|ctgUw?M~!#zw7z3kcE-u&inv0OV}9UguI|95(Fe(c53AvFBznf&cy',
    b'y`<#kPm7Oqc}s2!dh&@D_v^*d)cR<-p0C#D^d0=~^7C5)<CFD#aeKVDxmnzf_dHq_@8=)sTfc3(_suuoIRAdTSi?k}lTV~rI|D*b',
    b'-}=tHo;ghMenm?s|LiPo>C^T6hB`ki?r)pHoqT><&TrqX4jXVK{pei2r_LQIKG1djb>*zz&sPJqyX$-Q6LpHk&D}L!Q-`**cjmWi',
    b'x~vG`LvBmw8nA^%C4Em;?+^EekL|PuEL1|Cwxh9Wtekc&oPX{)@K1GrThzF}Q@Wjz<p;Wa>+c@`Qfv0{+PS-5QfEom_siRrv!8!n',
    b'(^cRfJR1XbQM{)&#02UdX5_^H>DN7Va?P3zQ*77Ua%KeMl`W>Hfj41}0=SPIfEV<R-ok{6&)+wEB*OYQr@xHiHUOJ1X#xNKtOr5L',
    b'a!FUKaS+EX+ii{wh~*s!%<cMuu3rKqyO~X5g&%*prOTdh26iYGx7GX|EQ|sK{;P(v0`ywqbRs=-x*v+g^)<;COE%^~4VnGZ&!wM+',
    b'fNxLAx87kr1kmBQ#iPN%b8hGjG>}PH>5$}jM8!g+=;o+QT7mP$FRPmJH9jr%XU!irT6?cqDEM>_>bDc^zs}dUKzG3EpZz?$wJ5u}',
    b'JnKKT+%tUYm{)Dm$nk0UOo2=8*Y6ig82qUDLG8PwpyF2aNCD9`=rsH}Ef&l2rGNm_1L-ix@ipOxXuhu2WPLCF8izxtle<OnUimzX',
    b'`f<Jj!Zr<H6*<DbSuXAtD{{Si!uI4V3gC|QbfWlC?A!tqw;WRQ#_I*x5oMxx?IdtAbYD?2$l8fE1ZmfD5UU<2&!->^pVmOKf?Qw2',
    b'Z-i+R_R~zB>ra08^Uw-Brt5MwG&<&#$XoBHpLux07rq0zBl-LqX!izut>W{Kz<x_0r_{M`)qP({hz)JKwRo{8?r-2fhlW6Tpuo_w',
    b'oUiV#$>-PPhUy!2;Qn%cs&523V70gvny6ylxBjL1sct%EEq?OipIfyB-&Xh6YtUZ!avv21y<0!#YD<(~&EJ9A1+H6E--8mproSaM',
    b'&S`c3xV&#qjW3dYV5IlulKk?RB>N%>(W*^el@0FrV{*_JqRCXd`Z${Gw_gB*2!9Dg`Cp;kf5nb4)}QZa>8!x>Ucp9USsygaSF3ya',
    b'G)`QnJ_A{UGY5O2r+@m<S$&|_biKIcPA}NLZGKIkE^e<sgTFkqcfhk^TUC0<PB>Q7DQR&{8jlSeKxhDnFh8ukZ<goi`_t8-ZZpB{',
    b'Nz{#-v>!NXJmCMThq|~WcdPe{wcy15EBp7$+ViDLS{|*Hj{s+V)T3V06=}867Qxa37k3h;J*c5E+se&%zaA!XcWplQvJI{1{BDgm',
    b'>p)%58v_4Pm_QZ__%y$*&lm1!GsCHCJ+`X!(;YBBEjw!B%O<zdFW*wXd1_RZY%ib5R*o~1$~SQ#zyR7Z#!>MB<%)3<Z^J*M3&1D_',
    b'dVd9!D95**Hv4Pcp^Cc8Ua*$lGyHd7B|y_&f1uIy(|>QzvQ!4HDJ1h#zF1s?u>&(S|1VmiCkb>ohQgM1b-h@tv%7;{DsJr8U0^P6',
    b'@`-3*+CyJ&!$aR5PJ7tvO+D<Lo2}Ts%<D5PkB^`FjTlV)ys@bDce|>X90QU@z0Y}5>=)w^sa8#xaKrrFF9yN(X!+H=qQ&RpnzrZ3',
    b'-uCCo(~ga=1q7r%<0r<`2J4u$A(q0!qoeiTO*(xhw8G3T)}nE<#4mcELWLmN4zvO4mZ>dk*NRz{{)>)|KP;B*r1zyG)v>L?Ky!`W',
    b'Y3BMpYpwP%0@tklqOsW@>8UWnbS5yY3h$NIs-FMGTLHF2x|w(0jyQL9w2i3HS%=<lnm+&5ziRh&{7Hp@VYLdVH&o}8ls}Myu%qIh',
    b'o2vQ;leQ5}J3i@B9i#7}zuwb8*55Ssx)gV)T3>{1=a-;LEnTmoZ+`U5@bP=o$75{2(1X=GGaPuEM#m59&`Ade7x#B}*OUng0XD4W',
    b'pJ)kt`|e^|3WH#03SCUXH!U(SFsxmv-|YA6Iox;m$5tMGci%^AOuoz(`fq=aeYE*)`q9RtgRs-d<FZa0kEjN4Odekau`xEle%Fi7',
    b'j3wV(lX`EsUGPAweR@8u51lr=vqqZg^wl29+A=a*Zct=!o9<J}jl)OEt)oUtIS!_d81Xico7Nb%U<4DvSwl`~&oCQ+{djCLo<>`Q',
    b'+tOTGHyPJa_hExEW%_LBDrloiY<!4Z9-8wYHV$i<FtD&WuFrg6WbMh*3^_UilGhOBuV8}T(cAVwYo@pn%{77fyuTep9}?8*CQ<^{',
    b'C`u|SwvPBup5Nax028cL)4B$aHNUS<6=0V|Q3OUu8@6c_Lsma#yTCh}Ho8UR94vefsd9#}hi$wM{RWnuJc3<2167HCW@iIU#0TD{',
    b'_7qv8%l9zG`^9yM<H?^gv@v+P?XrG<$^$uO+tHm7U&HDAfJfG&&3fsC)uW#_Jbq|4+&DEs(Ng@&>OEP~S0ty`GEdarH>octsl_67',
    b'H&5EdXpi|npWfWuuiL1fla?&FC>li&F%BJP?f}|~)FzEVyeJlTy8yYQ|9KBO|6+iw;Sc^w@AjTHM@54Gub3ug&Skxy#(6~=`VI>i',
    b'Q_aTjAz-G!3EA{12SH2iDF;C!xcZ}Wl<K3G^d<*q9HAu=L^YKkb`Tb|1xbHFqnbvDszqcwY7#Yq<FQv)zj?%NAHIy8q!F_%x0OcN',
    b'zwa^cmuMKAyoocNLe5O5kfx8vTB+Y?OE^A@2i=O|mwS)DFD;CCJk}-^!vfv0%3kYmt=`7p{h5B=)Cs>c#CdLM<o>lC5Di7X6id|}',
    b'dQX2B)pk5-BmBO&Cs72!?>Bx8)sl>9h)qb%X*mC}G#rtK-USKumwWsj(+~BnQh%w_$C5q;5x=GE%H*D|`n@uHY|8>y<#5&JRqf%(',
    b'l5||ct`6ws=R3NRZw@;==yG1oi+a&bPoqeOHWr}Pe$qdU+U{YMd`hgn5#&5a9jwCS(qZ?JhUWTFhU+hFyygPCD;=<0qR1?%>0RHT',
    b'_&}V$$1X{GqAPbxcJXB*?}&R9jA?W);;<thBpP`kED3*-q&DV{pbR*7iwMT&AI)KjfO&HscmqV<T_EPvm}uKrYc4Qz)0pSwXy_*%',
    b'Li$({we6y{ygXseursk|`ilz77=v+6XuZbeMv?Q<&4T=$JDU_gG47X68qFftoTO=Dzoqjw6;nolRt%3t@ovAiXO!~ST7d7C^Bc1K',
    b'e5A;6Gsih{tUI(p^$t4*<c|&we8gKtG<26);xqDYUWj;kas35sr7A`#sHtC6MyRh8YF&&3ESm$qEd%;nO4`Kpui)ElY1tUm!R@M8',
    b'D&w|HNI)*?cW~q#JtM0RvQlW#YDRdor0~}}B^JL&NY~7ytvg9lT4QRWm17I0_$w%AYEUsuoe*UgswkC34&wijmY4Gz3QTZwr;4#G',
    b'h=W8M5j-ky=4+6dntT1<xp%kRJIW2eh`;=g;rk2VL#lhG0-Ft-qgrpXJp|nmYyC#N)1fx-&YMNOy;A*&JM#H@K^n{UJ*@;c9cyz`',
    b'DPU4)@Q$vI?&_mhldt*%xtU*o=67h*mkBypEKctaE`AZEVwbC?>@-X=+Y*G|Kfm;e^EPN&*BP$f!zP|C`zM|&*e);$U)%z<n5RLX',
    b')-v0^c&HILGzdcTRN`d~6vmlA<<<WLDd-zBeQ?|!)x9)rHF?f#-xce8%63sMHQKoc%$Ydd(?qsN_^#Ec-yh3_PuoKCwtcm#w<+y2',
    b'O~xP(a1uj#t^d|jVMq=1kh(MWh6~WgZBh&U*@fJ4h>_N4>3MDDv?Hr+^kb`SO{4QmuOA<4WeR#%TVptEDt;?^T|c7jVC$ueS*F_a',
    b'Szgi`(3k60DT=%Mu~Q^OcmLR>4P;8ZX04~|#nYbadw0dTT{N-!PeD=5D-b`YqO{CG^*XeCM-Odes5^=cFzM+U;mW7}WH@8%n!La+',
    b'QXl^5sl1Pc<+`||1-_SU+z@v7`%L!{-Q2g|UeVik>-Wm`ovx^|sRv`R_~o45uc#%`=M;?fz4n<(_v%}5!<x}*&&gt>GvMFloKdru',
    b'kvELu^p|N4l*Y7AF_s<AoY(gV=7yUYKfBG(t{su7TdILue+qxDRSo+KIrs#P@qw;4J(bq1{$$sAWaV{8jyfS}%fQO{Si2-OaT>;7',
    b'?PmV?bM=k`Zn$>pH2JT3y~wxvZB-*n-2&^~oFGapV7lKDx9{rKeQ>x<J4ktdkHV1};gICBbsUu3>gDL_Tux=%aVj@1!mi|NLtSN|',
    b'h{v?2jsER!6Pl$veoyActR17x3Z9U)&yP7=Q?BG>cqY+TN4LXJ@5st+2W9ZUT7Y*pkNY!#*nj#9EP&u)JF7MsM4dRKzGv@LCV!`I',
    b'JSgB^6_`>nbt7p6p#9pMp*`Din%7dy{h^Fria9+b0O9bx+mW7j0SC%eZP-sm-)30r3#w65{fOrMSD!b>n77Epq<td|X}A^|;&3f&',
    b'$ip?ScUML-ag9xzK(5*M1|d?Lo#SGqHvB;pG*J_y0Sb*0)>6Lytf6`RO+)San-v?fhAgyaw9zX{D&s2DtxWXq$2w~_swnx}Rx-tR',
    b'yc^ZfwEwQ5YyaIy31rW!hty@zu>xq~Te*>jYvpDJp53*dt06kyL_>GJiIGycTWy4Avj9kYbPbSpnq@#*8dl=r-43l{mm6yJyWG%D',
    b'&C9*Ubdk>e8!-@iFUzL2*<5H^YpsT+J+l1Mx3I^GP13lrJM;<OENSbgn5c^St(#fL9UccRX>~n+_a3$#|9KA<3H3>r&9^V;BFkdy',
    b'HaM%Tqq*(jP*1Agc-#7DB;umz*)VJiQ`73t^t1jB2&hyekC!Yc0GI2<yJI}W^RA~b?5P<Pg<KPLK{MK}kMS(YW}Xe#>aNWOY;4z3',
    b'4kz!(aXC94T=svjrp9Ltqi?w`%(M*=Cnoj06k1{|$$!@?X|dg-oh)GS@_dA~5Q_D<m!sdCtk7fLlNu3u{3}z-*mr#A)~jY^r624X',
    b'k3G^bag%T-KXPSnxca~SNUs-nRKEst3&ZJ>B@rny#clJpne$t9srMy$wRxj#csnD%J<g4TZT#%m40h8O$7ZPKP0ZIASmcSM8SduU',
    b'>n!1J{0iC(|3nOc*)jGfczDf@=kP*_%-G<O_vjEic}iZZ+0VG}o^<+%dvI%fw<Z^sm>HaLu0RD|B2z}fAHa8t(wxX@B#g6pCpgnQ',
    b'POx}>*%IxtH_VTs^R&ZltM#;ix72%DxLa#JE#$3r-#FxLHHUVD9qB(?_zyOZUFty7AiLLs%4omqLF?o+532$T{YV>YKLgB76`uj*',
    b'<~q*+baQoQ19XcF!dl?lDmi=54}twoRGS(84z(I0p1&(Jo4guISPGXg+*J1)@4Q7WEF9pb+DQiwyLsst&oX<f?NGZOV51c6+p0J7',
    b'Gk^`ml^_oT<p>9yRysbiW^qkO)h=x}u^Dlk5$q73F68K4=Wcx$Jkb$1FrKWf|2(s~T%Aq5T-7F|vLTRFswAxE1`BN(ev@V1M4KPW',
    b'!E4*=^J6*MZEKBwY+mr)>hxnQT<&+R{*YST%EWF;It9=aN^T;CbwuWlbuFMq=C@LZe;H?2rvkZ50n-)V1s}v|OcRGOY^&`2ZI#`{',
    b'5N2uuW~JsX#1K(os}$_qW&KU$$x`vkLCx0cB>Y|TK8!zo(FHm0Sg{RpFp6#)4@TpXk=8#=b-|>dE!_9JYhHQc(L;y|9(^p@W8FfY',
    b'*~JjetYU~}mN7(D=MiYAl&Pku!9d9wTloMqZDL!NNnL&II@=-1ErO#sF6*PDY*A=P)<fXKn&Hz-O+==72FDj$9a>-@G`!7Ip#NRl',
    b'Sy*tcCPMe?HY|%U<IE6IKE}8^^)1xbZf}DfpBWfOYrT?S!}Ri6xUGW{Om|R>V5R+0@Bmw|ZM~FZ^*~`;v-{<FP>9-ivABT^!v_AX',
    b'pvVQlSVb=-j(9fmO4h9MwC}4C4a&FBDl#d>T@QwTnmeXZv`V?H>P3nVo9ULO;FvMLwdQ&7w7Ne=ogqV>R?S$2`d}53x2=xd%4Ad3',
    b'D((N(!s+T?iT_4!Ew?W&{m2!lc3oLoA=z(IDO$<)yU74Tt>_JEQCq?7>Gi*)3|uc~D!;G@TrD|TTUH)DZf!yiJr#3NRW#|0W+PDA',
    b'R{g)5N!K9wB6QPs-lL|1Rlp!DrGHcZ0xNQ{iI^>gw4$OUZwXp?sq{e5Yg60J0EKU*_(W+Q9ko5^+3B2CZL-DA-+B<>9oxN{-+tJ)',
    b'$oDweY$yXW{x08eIZpSdR&o_UaGI@ASd$giX5QT6T(TlNRP>HjZZ(_mAbK`A56dJMTB26#MYp$lHai><fc3@eBqXeA)QH)X4fhY)',
    b'ep}X)Lt$=y>8b^(UWD%8<a*ofv+z1;CtK&H{_=)s9c$%jQ{31ZoG<R#u~2iqZ%6ovtot~6OBR>?kyo8F%U7MVNv}G`^puV=Rys=4',
    b'*;+qY4{q%`_GjliKgGm{+2Z&T2e|pUB@Pe2Tn(lRXsKRy9QWs30PtTp2vw84ToZ#T9k5Nm#z&IuK1PrlCmQ?uEK0NSEK0M9Iel&K',
    b'FA%y|#iptKCP${3hPGZ;K3nL+240>iIh3}KVLMZjE^Qseb~cvMbc^^h{Ek{WP2c)97D+rjNuy}5XK}{nE=!SH+SNl$XNUK~{e$&3',
    b'_4JS@)m8(bSIOH6;^PJaiz;B>m_Ti2l|XGaJyGy<YSXFVz-ZUWT6YA2(e*|Xi9F;oa|6Eh_eV39%q$X$%&c;K%q+7<j4eG%G2@D3',
    b'J**dc!f^TML+qWuqJ5Z$WxIU|Hw{N?4JoBdc?{K9_u+~Z*A{Cw!q27}#^xzmsWGw7Wc{TZ(y$Cl<s7yJUK!8QS~f<jx6Ai)GspUh',
    b't6zt@koYbx*dDXayq?5A0Ql~br7KWv`AkIDeaj<D4CJOBcDZpRPPujHja(smQ-!P)f8I*{DkY`2Qoq^))%%;pnjCErj4j-~Y=s3^',
    b'UEcmQTQ6b^+{NO4S<p5`DH**G=#o&$09Lr$D5KN#=cX`|lU~iFWLJ7ZGy@;EW~$pK+U`SliOEU3QED)HL5piL;IqvFo!zhdE7>J8',
    b'1WWGK2&(qf9$P#Y!2wQqGV<%*H{UoHZ(jWE>8p7`Z&&nbgFo|#zIDz{FZb@2<lPNn^$O=DOw0KX_b@&5vS&b&o4T;!SBKwd%tC#(',
    b'xOzXod+QxS|F57AU-{sIl|bxru037cUVpBO94wthRhLLyzn?GHl-@em^c^WaciU$1!q6$}V8qp71G=OiolEFTKapbXZ~>b2jv8Q-',
    b'+mcm)>S{M%)2FPqPrH35KqFRik5Qn2EmP^_b=k}sooc>Zt(}XD%OB5A4)+R1Z8nBwr0>NCdQI0XxM-zy`mlbp39Xwzj@C`2%O%WO',
    b'-{UX0<Rh71GZO40X((G>8-sF2u7N-|v<>+R+wyIT<=`K61qv-89@p#Cdoj(j&A5D^?C(xX>tXUwo@-^%Px1r(tnYTpZuO-*enaEC',
    b'`z9cuPNv%i;sB%2Yc^XXiDJq5M@YH1#+?JduK7VJ#ngR2z9#BdcAS5|nqJGjR;VmWkS<w(l=2bA>bz<8Dxe9OR}<{s4%I2q{E?km',
    b'e8En&{<*6X_O0!f>1AKXUR$TWE1an-nc3&{ynGL1zh7LJ=ER@cN+NO%`wOh%kpv7cWiRY*@uK%OW$jl(l6!F_`SbzOGD@2cBp)s)',
    b'dn8r#dr-NrNKUVX-0^j>1O+>csz(B6$mr_J6?HLNXle4sq#!w@Ss?T2#2NwH=Y5}2Vh2wQZI$c&fyz;Bm}~r@3I^}KDpq^HYM<nt',
    b'o8m`OSA4z&O5CoUv!nArpPW0-dnoRwGE2fRt^Bksi0ekKn}(i8!m#j3P?brTWTBV)WtPWP<ojt($||Hup8G*XV&a9*%p<-yd2{mm',
    b'#mVdAzhAxh@$BgIwK%w+m1XAoQRPP@@T(&8T)&85yfO(YKM#vEc4I&Q{vE~e|HClI!ZPy$H!CS6BZD9Rcm@t8HZTcdkGeT2Vwg(q',
    b'<zYpr8<e3-iYkEtDmTxQ$fdrY#aWdBW|RbFQ3O?xMkE>=_~`i0S7%3mIz1K!%}53$c7rU<f+BSbFG}JlpkW%pU=@wxga#z`;vmec',
    b'G)!oi#d#3~B`MPc@bO0m{p;!F>ywKMY`O)&30*d=5-6Pou9y0>@ZBoNyfE^UA}Qk}$RjTU3X?d>3mVXj#w4JyM0q(f^2O!R<;hh;',
    b'?X#2DD8&;G2w6sM;AIuf+&my*UgTL2=Yj9Kp`X(riHRFlup~*GrIi~;iJu1WiwijU78FND1%C2i(IOvKxy*~i&(kFGD(b`JOE>pi',
    b'62OkD@=7m_%CH1xEK9!%p$l+%5YW+ygR6dpNEL<k^`f$hQkwfYNLG@-N+(enl!@zmUYG}25yoDgmSGl9z$z(o_((D@i6Y{SGWL(>',
    b'FHT<{!SLAV9!aZ`RHSs{I4FHDsL}!^L|}p-u_bU|LgLtkuVLbbLE)Al>p*crb4r2iV={euesT;${~aGY3i6-;)+zEZjpHayOAx8J',
    b'2#Uf74kNT)kGLqKw2TtsQa3CUFU&%c&?0oLD1Lr&^y2F1`%^&R_2~~M7nfHrk1k#cc(|GC(jbK4Ngigomr)WHRRr6u6hx|4B6*zW',
    b'5$J$2Ov;oN@K5NG(x-r1HipO1`SHusx9HmEFrpU}eptb*lPXU9G7hpb2e>&1Q$bTwz&I&z0^<o_#VkycDs+n?il{fnb4M@EPA@J_',
    b'e|(LN9Wb&}8p4uSagby_$=oP){fzjaPGF&f$Ojb{f)1z{M;4%C(iBu|nxqk>srA^nh6@7UtEw#WV(Nq9j>{~F(#)+~8j>_G!wOVR',
    b'LGm=q-ONuZ=sds&bUi6DU{trT)8}tq9lgecJqEQxGEgdR&L&>OB^W5L04<j!)FX*UqsRkg69h3yix{*J=z<Vba-3!)aL3sG43ymY',
    b'>Cvmx|9gT;o$G~R=)&wls8X*elB^2BPJsx7X&AXx8dH)N5g4!{12dL0&I8T}s|<KQC+?KtFHevEe1huPv?7Tg1H>vLIY@L#OHi~a',
    b'aDSd>H1Q%(Nd(k=kyk(?9~7WllzB+XtcbiQ&Zl7U=IBo+j1xrDTDSqNK>Gy107;m#MInSnNm&G70mG{Fi_8z>7_?39Q9lG6z#;|I',
    b'D}3OaF&+Tb1G?|(_$5qSo&N_AWAXu9>HV+b$j>e=K~tPv9i3mEf{qZnzV*I3u;BK~%aa!k!>Qa}`k@yFVMY=c#H#|k5k=rYl|cbQ',
    b'R(fE>)2sxO25bnbF!QOG<|)`&usop;|2r~#P2InqpI)-{J~;y<1S2b;5`qdNdFg{Nd5rF${sS*3V9$$)78z54v;^*V!@R6=@O3gk',
    b'$OFZc7i9`^(xB39Lv(_7eDvzoi=)e<tFzPBr)PgTbDlf?l^gj}dmsI+>+M}7ao8SY^jGiqIqXu0^D{JZTB4mz7jfUC9c}TEE|<{F',
    b'@D_Vya0>`q;_^b=s7=P?1zs?9Yz5x>c4Qy2&WyA#mCUWr@Ey$1<*GC#$b2@|yWWWoJ-gGgcGw$ocgH{3d;VSjs-_2ag>LZLqoEE!',
    b'hXD#e+4ku>cNa=SXYs)4jZhgK0iYfWDu}e7=2U{xaf4wFr=`?~BV6;GmqQ$RAUuI+{X^ic^j<>%Erj-UuMWU)5IKqJef{w<x;Kw#',
    b'5eR=-&L{LLhX=fRO7lO(A;0R}iRgi_c*5r?kmVD)pMJ&w^Q|_Z(F^UYO})G5gY9~s+N={hKNK{Al4D`jYLwatvctl~a^GCY=xSzH',
    b'$>?gPg~J&b12n`88DRFN!T?b*Cs&3PJDA!=+G`Xwf@yDb5Gaa4x-x~|bw=o_jlCNVZs(Qs{#sl*=lSyvoqhK}XvqHg@BfzC9~Lb-',
    b'&XebwRW<?P*V%q(z88uB#uz4m18dkLG4w%EP&o+$X67Y^OuM!kWOTeW-gDqJamwO1VQMN1qEk|ta2%T_SF8Iwc16D0msANm`f{@Z',
    b'_Vm^Co*``GQ$G%-_bg$@Pjma8g2H0wl&MEyN0@Kg-_NTu36jjVKd0Q-20l&wGzg>3dS^i#R7H|*);sqK*oWoihP_={rhZYNy-f>N',
    b'wf|Ull<7UOyNI;0GdE>Uzq6?pp-+OO92rvVqz-k!ZcgZOJuQ9#<nVyIWkNQYj-=18%*{KU;ONYNwmTnrf~s(<uE_Y970`m}SJXjt',
    b'xJ5T)eANUfVBUfg#;IH6I|o<Qze9Uf>p}-a6%Rek+fUZpXqz}d8Y2WCbmmE06xWc9oxk{fHNT}S6zRDjI#*mYsSIYH<95XbdZL0p',
    b'>?7rvG$P-->q=%AJxqd;KHN_lZ{=z_q~k689|Ur}WQsF4srRwHOE^(^AtS1BSeo>6=u67s@!1$l$sqRiqnTb12@j>l#zX)a`B<LJ',
    b'VgJLpTdVKe`+!QfT6Ufrx*qF#!hi@N4*B24Q67UZiuf1+1^tQaDvXN_mP_yB+MHBe0L1i+rJAJE{Q;^HDO-0KHi*slHo#&dT!w4`',
    b'*0{7mwm2$*4vX=mn>!+g5Pq={O$;eo+q2|4pxPQSRrdP?1ja3!VJj%Oa~KrV-?IS7S)*}XGV0)24A?tfQ-@PLww-#}(~Z)jTBA+P',
    b'&~M?wwQ@OJl8UmB&kq3=Si^l~;gvA1nbIV`UKAe=>j=hqsebN^()#^;bujX|XF#=GqhQtF8&$X;AfTJL@qPDGQTcx6g{7$tt*W$$',
    b'lhD-0^+;HH6~U%~$h=*vW9^i6JB3lW$5^c@`#quBM-4mDE`(=Xi0+uj(564iQQMe3du-n|I{jXS*|*e_Nsf=&j7a@y6v7e4O{NXO',
    b')HZx5n-*c;gm8c0XlT<PEgIVNhln~P@#rrD#Qt#2)TTQ^({jLD-|$J#4PvC&W~A*8y)ebuZ8(s;KZZtngptN*ZVFS++^$*w&d$)L',
    b'KT=Q|3ELJtAIE4@Jsq@NEU6*%&#hbPX(BW;kVTFVoMbK6pYQ0tWm>j_!}(C<XqSwH#2Mm^r0}ds(xpZdV(x|#^EXMGk5W_2GBZNZ',
    b'Z8=gOLO9a43-r?xQ3quR%f`QHR!t0L$Ls(aaIQs94qUTn*u<#ei_Ki;Ai{WRBxX<TpdL2kL&o90bgOnScJ}dmEe!QsU_wz0)3L$L',
    b'>fParN!-%B`$o^-`o5;q0@D_rN3Ge`jqI`87q7#}GYkuEqxh?N>WuJ**Yx(?`n~f9os8+`&UgM!CwExqVcXh)Ibej->}J(nEpXWT',
    b'i}vv_-ge5fX)OTu&!I{74*M6(S{MdlRDF9~DD}1j7dOm!3vwm@qaH3FY|f#>EAN^y=kI1Rub|v%e4Xe#cdl4zJ^0pd+S={UzWIDf',
    b'NeSxQ!C%gEfhf;5(|;|%_D!F3kb^Ih;qF3V6ftO|xo_ebWIU*ZP4$rd&l!0)FPMa3aqxV@w{+Rv>G@iS%f&BjY*+Z<J16P?9^Pt>',
    b'-(le5+aT0D>pT}qKXm$rA)w{>KX!{E!g$##Xam(G>`*W)2V-;Xqn%jy&$nho_-U#SQuoH?)J(wsvFlbOl%Q-*L>Zk;$f!X^obINi',
    b'>;@?ac-|$e)&VG<k=2KO2<6L^^YKZVvD0^LHs>WR>ntOyeTK)ZLshyAMZ;Hr64l1fyU^&Kpu-iUTWzPswQI+YOM#FV?+NU!SmQ1e',
    b'Ms2o=4~Ozoaff#jxKr-BFE_w9-#9<iDOgl{-(_WSUN1QJ@{WOFnUcU`DBjl(403wC_~mfG*@m`&-+FmZ<=7Ab3xz7;jEfJAwthbB',
    b's-6igR?Y2VtErzmp7^=e&b?lix^jwHR@HJ##TuEO{<AK!b<*YmXc}vt*30)H_!EtvYUJCKm_t6R-p}GV=(~L8PN*+8e%ezMXcxtP',
    b'*u9Y$vAKVA1iZRld#XOe!S@Y+R!FPOPQfN)`YzfBygVu!WabEbDQ`)8_UgiZdd8DCtCrYU7HqZL<`wtLC4e{8lGVF|vt9Uq?T)p3',
    b'Nr0y*D|$lkTG%rANQZIz%djrpFNaMs5?C6|sS47i%~Jw>gj+wXrK(Dwi<f<9CqA}u>>Zx2s~Q71`Vdc~3m4mHet(B|llCGb8C3fI',
    b't2T^O|LRd~F6rEXuMZ9CmtP}E2M_&q>bUQW7+bEpK5I)4pfNpMAHe`|^W?0MFhSK8^_{d{vNPsJV;JZ?MQ7ZZMCq<IXW|l!CX^Xg',
    b'Lu0x4B{3(R=|OQ>XLJsfbWGcOCzwogCcqy)7raHnowOFff%cShQk7XvYRIXfO*#()aVqeTr_sW-yFwIkS-LSa2wK&^orYeQPg#Rw',
    b'UG#_@%V=J=4j3E5{3ch|?XZ;)+M?X9G(jXO->TWYuwsk%bnq#MN4WCxaD)=QvKqpnoYHS5|6Zr^>waxg_{|VFY9hO?51+da>xriC',
    b'>pIs-`|P4Lja7+vD-Ne6khy`Z5rXMujjb_k9!6{M!(K_-Xq9d2Bx?z&7EH!57kSgb)flIVeKk+L2N1^gj7^88W2`s1-17q~KKX(9',
    b'PbvyOAK2*ak)qPp(-5mn>$sMCG>u_w5_@Bf>dnv`YN2X)Rd`p=@zq4WHMk@@Esc%q5X9aLS`K-KFRGEBhGBnh4-&^`v-7&!>ddSQ',
    b'a7$BH6BG2N_8JyYJ|UV&A@Rhto|5z3^BQt@3X2|zHrampEWa48J*GUZod*0*b>}f(fbV$N*JTiXW%*I1pZMgcGb6k@QL5A%%aS^7',
    b'=^v_0y2?pkPQ7%ESIFlpM%+R%M~4k>8r(!a{;cy5`$8l9-<=yd$wlOH91lN<xs5S^QhH;ttB}+f?Tx23#-P+%SdRgc(71ylWisad',
    b'=ux+}dyIVA#dLKk%()=132$v!&JkSSbMWf>xjxdJ-A^eWyAbz1=^{&M*u}YPK2}wckwkNxE8XdQLC35AR4$Zi4@{tj_6B!0-b`gz',
    b'{k=4HUOtW$awR&mX{f<WbK$!gZi*kPMNV$1!LGmVklT+*pY|^Fi{wS-R&<o%BRhw}i{dTPF79JpG^VDHnQ7_#C%U+yuoE`kA@d;~',
    b'@j(yceDTZ0{8P^hpy%rv<?W@dY1Nd`zsObN_jpdpZy~!AVJ-Vg$>>XtM$Kuc0IrL^cmk?d)ARee?Bwq2Llge3aZ&1LCI<%+Shk=%',
    b')F;nn^tRwWHK@5`M=iEu*sCr|@yQ5|O6=5_+Oh~U;le*Kb!Lcok+IvBiUK9O7-bV~Nci3};iq4v6=t3W8ox0VHQ;8>pXLjke1Mc4',
    b';EDd+xF&{BIC1!~D7Ud?<DsGXngpE3;?<s9-POFjF5dG72t&U%n8NTgR24i-^yS_Tc?y-(zF0+bA=UL}J09&37*C9!4ICiD6y(?W',
    b'w|~PL@MM1+0yeKj+<kuJgAvN<tfa=iPPdg7W)3|^)S5Z$;!`8<lg>U3%a36v2g7b6wr|Mi>jkL+PLN=1vz%Ueng3e}uIUhX64TYr',
    b'f1fJ2S*w{+F}#_v;2?FMxFil7zagm_x(<BoDQ4DNBqV`nSqC{}L}P4gf7L2qJj{tEQ_H&D1fGvgU@)pGF}3!lUn6mCB<hakMzf-X',
    b'!ZSP`TAsNZBy2c0Zhw3wA*TtIVxI6#Gmd;nG8`<H^aA!&oI+Zy=uLk8+4*Px(fRf{JBeX`uHes(b_dex_03s~FOR76wc{Oh=Q0(!',
    b'Udh#vI$>DegEZbS{dWr!sXz5l4-gdhziK)@U6G1@1?=0QSuE~84@(R*-fuzAoWMVTUEZvpoIH!R;ZN?*^$y^Z>l#sqmFi0ESs~ap',
    b'W;EquI|K{^z;Jb+@82*IcE2C6SYaO77O5WK^XELz7+BAwyJdD%D@1W@sc=*K@r-<$-`wAr<M?>yd@RQN!*j=Lo`1AId?%s&JEwjz',
    b'oQeguTf1)7)>L%VZdm9#U>C@i&=9lI`p;<83LcyM^Rw|i_(nm~{L`YLuM`V2;^B1(`I=d&y`N0!jd-6=Y-Yekq?jl3v+*>+&SK-F',
    b')*h*tPq6qiDby=N`OU{XFQkCHGvQ^Y{xzqWq%+HY>e|}Ah<v8}go;2<gMBm){ZAZSem>yozGrwrB?08q;!gl*%~}IQtygUDfQ1ue',
    b'Uw$<h$Uh`1tzmz!(Ms~mil1#2#U!zkM?tPl&gQJdukdimWDoe}yEO-W$xQUoPdiq7^ZaJH_(yZ^JRFX<bM1P!e~NqacBMS4b6EAd',
    b'8-1qJ|H=oiVCf+Ff3{bf-Kcoh)L$J69tc0@ntyrLZT~yu{yWjxT`Ve~H@v$foP}xbj2ky`JG+c^Wb2?3@&Oh^;=ly6IP5!5sXhjX',
    b'Q-+={riT^fuFG);9-`s<gPH*<pIM>_Bya{|2*ZPit3s?d5EZL>uYQ{r_cRj!v?1@*+H0|NhO*|*oVoJ{K0NA~^YzzrY$1#`k^R#I',
    b'LH*oCHPx!RC1UrR@hvgfg$@J@ffD+&A8b4G!BPSc{=*osC){l6-nb(HTatRYyO*I(zNF;CGwFayJ#y;r!s_0;lO~-BA8vgAiN#65',
    b'_!}J*Z{!k64|@$>ABUFq2vp0Klif7!gZWKdGzFOL8ZYIbRl_+i^7{D8xPAZUj&>)bH<o752%A`5UWtAtrVgzESzePWaBD`DVVOkp',
    b'FXyKQa01Jk!E!OzrepI*-a3xyiZQKawdosI7aJ|YsNUFQ4Sto<5cIFA^s!k;*cNk-)L(xA($Zl=(UH4R0<YOqA&XAk+1lm&hTV7G',
    b'+|8^b(Xf~{Ief`x^C|J+)lI!qJ5pw&IqZ_RiZi^~RBG8%Z2X?SS^F+Fdrvoo*|6I9(7bay1Oub7h2)MUG2~w=@|$E$q}e|o&1smX',
    b'2qYy?(rc=#GAKx_xtmtd?QFU#%H5Wx{ebQDRUz+B57b)`6N|Q?{08yuZe%nz(C7^))}qcdrTprlzxoHtZLI(kKa?Knr1MD7TWoyB',
    b'*oJ>JTH??cHnFXk7$js<;lQjDyJMKZ^#T~hbn?I~B=1+7_q(RM5Ysh?_O{`<qb04Ocm28-?OT6Qdp0kC`5w(LYD+ZQ$7=u9LEv8w',
    b'^L_c>)n4d(V(8u}edmv=4spJ<g<d~M7NMz1i`|U^NSC)x{WXo@hK65<wmk<z^SE8*77mUi<pVU~!J{KePP47V#7e)B{G-OFH)$1~',
    b'>ZoTazOzIps`OJ#7vdM#pN1pW!hHB`I=XIAIhJxi>}&H%%|^0}AUnyiJR;*^Of8m2T;d1K#ouf+YsnS?P9taG$zu~&OBTf&w}-19',
    b'{l}VV*{_DxxVWTfw;}So>LJRiR);g$H#=G@*GTr6E#^ZdL#yN#Jt1_8f51u<(?*ql$0^<Vmjmf<7P!(Wb)$+=SPy@asvd4)TE;3v',
    b'jNa?wJg)PT;~&poTphnWI_(qH+kwYVIuDFQ5ExbE8_UU?vd(NVX%pCKlf}2U);FJ{o1xS(?0j{5m`)S*TNrhRG5wZsCpUy9tB76_',
    b'Vpo07&~C%t%8@m(sl(tlcfA^Cp7)VPz1gno*kwcqgnQ>KT;TP;>bi+<q3bl47<ZVu_s^uck=sCl=E<_Dv+$T&bNASwVVFGr-kOId',
    b'wJ;G<dYlbVnkV$eTiF8~+N#Yf*z?bjU7$`mC^-UXjvZ7ecosoAiEyzSP}5|zSE9xXWGO`ieu+FsE@-#C@;$t}U%khV)8#wpeM7c-',
    b'yF3+k0EGM%nw%AOkc_!3CdGLDYH$t}pLhD@{cbPrcN?m(X$XM!`rqQ}fAj18on7r)UF+*YALNcoE@-SV#;p#AHufEd`1RMAMiw$*',
    b';2oQQgpqKBUya(j`&&w}v8SQ&D57lTwDtwby6ijO@@cS<FfN^^BVmlLnQpcZjQ&5jG?1E|rLn;1$lII=l}=my<QF{RGkfOpKIc%n',
    b'yuXvHMw=>bVdE?0JtX6uG<94+`C->vL&zlC<*>&Pu*+d{nORZjK)MFwURSGyaJYR`N73mCBZR`d<^V`@CI_YV%1FBF6_+3RKs|DJ',
    b')QY*&iw}>D_YgIR$Hp8fMXaletuG8csR%R|@AO-jxZb`<_Y<V}Y+s5I>wvWHQz5e$Q_DVlO7zJk$IS4KAB6JAm`!GL4bi8-n27Os',
    b'<#kDT54lp}V{gRueaBf^+tq|DBKU`5LGm$_#~_R%J_cahI`EpBSi@jg{P@AMhw>M=1C-V@S$PatH;vEWU1e#A&BO|qZl;~#l<a_o',
    b'zkxwLFj)v&_oGAU0A<AP>vr0$hca2eaN{dgDxOGXDmLZievFo9+fy@+xGS+v1WHE%d-sz^5}FbkxETrkAPb{1NNFBdK@ulXk-8Pl',
    b'GC!sy%yT~t0x!#`R~1QKq;XOPNh)$*hrlpJ-Kn|3i<!0w&^uC(u?0{^9~Eb{i%yie3?G}h|LRaX5ygHdfVwrEhu`}$b$EJz%se<O',
    b'!KQ+s-$Urx40T+mahlPIehg+q5g6q+wAX{N96H*U#C6_da$U2)ZLZdy<o%U7{X~kjWm*!Mk&K+iY8t<2xJ^^FwnOGX$^p3Gj^a8r',
    b'8zg9(mqg9Nv?j}UbZu4JNS`@DSk=V`mOp`=HO&h)mwhjF**~*(tS09}H_JBZLz7OS`?1LaA-S#MOxPIBFN~mdE{p?RN<hGfMVyHJ',
    b'pF9_qaI15XHV{V~;Q)=OZuQ8JLqqB`ncM>r>ckq1w&g%qcP7pIVEnwMEk+<EMmexy?m8{9Tr(R@Yt$$17%0IfB7M-LC|y`EmlTEN',
    b'<O;T80*jjN<MH-g-fuO<it|(`oViJwl^S@<7haRaq=U}qFHwUe+6317qRwceKs0%*4LNWcCfQB}igx$p{Md`5LnYJpU@3VdQ7buB',
    b'e|F!0flbNwDl&Lv1=)%Oxh?k>A7&2yPe~2cgW}226m26R>el~OQ>+4=7)s4Nlzs<R4^6e2Jn(gifa;9OZ0zs!d5$`%tJ^*2ic|i&',
    b'_suuX#hVv@d-`f#(AyP#+QhI`bGrQ2IXk`FyIYcXH^f;juID8ScKZ+aFg^6LXM20|8^(*ySBKvSZs8B?Np5`!TUV=Fy`SGPk8W}O',
    b'74-QAhWq#11#ks*>iy?66StQ>arz+R`g*n1MQ?qFw&uDmq4u<{P(GYJH4sbs(K%f^i(fzlZx<}yf4wN!TXHaej0c?er2f!eI?tTz',
    b'#k-kve139tc`~boF|Uh!R_%W|fC77y@(wU$UqO{L;<i^TZr4i&)n?oEHn{k}Ube8JHO(8(Q@d_^4PR0g=7>GYAA+&kAS_s~>n;-q',
    b'(n}d)NT{fF|Aa^s8<>d0;E3+%p7<!E(Vr};XiaX{b@}y+i_;%j>GktJpPX~YJMO1|1Vv71=mk|32TA6W%#Bjl&xlXMtZ>U9@<~yJ',
    b'Q5IB56wo5f;xu*RFip~k()8KL*yqPDPv4$kBj+i}y`b>JDvXPyiW9$#gRIPHT;zV17c?b>N6NHJTo^a;3qK2!qzc`lh$8CIk&)|q',
    b'%h<TINL?=~t0<+ppBKbU*u0Xc3}7VR^TIsHiZJ%_v<$O==4q0YIea9UmqZcqM#eq<@yGKQr>~D-cx-f!q*X~OQo3;*ls=F>EvhOc',
    b'VObI{EZrbWNF2NHHB8(vfCV7Xq;d&`Rf?lzWb_xO=O@Q7^xyHZqaY88m@Rpj#&MLUWt9N+gQD>B$Ro4}s>qLvGD^!RAue^pGV#JJ',
    b'Bnd3MJGRzc<!F(?0^h5uEb?ON$1trj3!*f0E0=~O&C9Uz-KrpYn&ochr?jFGa9mj?q{x6kZZS%3R&Dm`&8wp>%u^UW&fJ`2MGpUB',
    b'tX;%qOgyh}s~}0JM-q=lk>|T^5X2-cVw$;0<b?$2pJpU*N6CHi=H&H@lh?<8#|BTcs`TBw$lb6A3)jnGYBX}aBF_CJ56Y1G#7&Em',
    b'<~i|bMRK>u@-j>EB*@}~jLFv9lk?Lbz=L5Gci$Xco_>G&>huypWY|}K6-Rz{aS7`A?CR+J^7P{JsuR$Yx2J3#Cs%{E(7=D|eRVK`',
    b'*$+o&r?39rEQ-nzC2$`LHK8tv3*U{1TeyMeMZg+q4&qql6jq74lvIhEB^k-mFb1lWZk|`v8{-Hzfy>L27uw<d&<lewBZ&(-uJS>*',
    b'MUe}Nt^iF}dU=(mSxJENV**l=`P57EG)@AybVDEhcVzhQPhW%h|LN+-Hz(&nv>#Enq;UWO=cYaz0nqW1+${lvf}OzTk)OM9Rpm+L',
    b'#=s{@4A_7Y06m<5>PjLDp?LM`==&efYb9hv#LJ5$Pa^{V699jL8g>&>c`=Yar+Ja)Ne+l)NkOB~%fpb66qXO97Ssk9fZR$61HZkv',
    b'I{N+;7UT8l4=2ENFOM!>3V67g>(U?ujRZu`axbGKEUGA{RT>0k7M7Wp$9W!s6H$gqnF31}MF{4>2Xj$oW2))R`HydYyf}I_@HC<x',
    b'V;|Tcp#+w?0^5)$FhgJiFml8NVXZP?*uakyF9uX7A(<cg2}pQMV$h?dKZ3*M`O)i((@R0JFtg|r;>A@OQyNr3UXdV*y&wiNlot_L',
    b'-^?Wmhzd!45Q)qKvSfagMR{07@c+DI3Tv3~NZc3*TmgN-B&4NRfdi1{Ad%FqC}5XX1qdTx3ib*X1lk0If-a5VvkyEnwjxJ=I=TAm',
    b'`ROH$etB{RvMQ7g7f=ad#YtZJU>3XpOb8fIU{>N~Q4!H1V;n<E(Bp2HmsJj$BLk`Oz@5m8G6juq%N)1?%kmV6o5U_ys5}B+C<EI}',
    b'a<&8%2twU720F!o2Nt|y4h8UL>M`~OiH&Gr&ldRjVEdCQ2wV`0xC+A1XNnSxng=8)z+nM9<`pCXUm}glBm>tBl$jq!p&NNQjV9>|',
    b'9D_WnK<=x+%PMvc6y-j6DIhIrNI+uJghb#U72rF9%MyeMw1@z+5O9lPKS`?wgFf-Cmi}i)7k_r@?5zGs7mjFsr>q$1B+Rt$7P}+e',
    b'T4Pqr%HOa4bacTgP+!5suVCkG*Z2J7@-OGFUmRT?U7el2K0W)(8Nl$a(lnjk|LAXRf8V=`M-dpTIf{dS<tP3|Ab2#uK99g)zQrYT',
    b'9xg7y6dfNQy?WJBGHA)TCuCG^`?oRk*R(rheydTkNW(6M;MoXd%3t!n^~T^!&8LpST}9iDgv86(jwT(&kB_AUVU2a{?>yctX}c$V',
    b'LD@4ffHpd6e`|BWJ*IkTF~9EF{ad=MPgKSRlH1$PPVOg9O^@MvNp4s3`stS?j%p8EEY+U&c=Cb5wwPjlY;nc<+A~Zi+;zvIJ_|cu',
    b'+^*@T^-GJfo1++7cH?%3>!Uob9LKlns#b5yd+}JgFFf8UqAN8qyrQJ8)Ep*~qCuc&RFMG|r%DX)5QSra*{ci#L`AJ2ZH<})X|Git',
    b'2(GdmBj9u@!lEgPW`E<M2qywjFZ))FjR;^8hd?z6wPkbTa+yUJ>7bKVjCB+Nz1oxC%;;j2K|a;0DZ@7`)|V4oEGR)1T%;(A)Iu0U',
    b'C)K8*c)1=A-^6;MC}4`f1aMFV_DBqUP!v?nffiFU>W=YZZhBoZ-dE8r>Ut|pgsEyZ4>lU2PSo*`M#6{&b%RGyBN{{<6>TPrYt%6|',
    b'wAC&uKI=(5Frv}a@kTV-_=s8!hm;*tHQa`ri7}9_ExMu;xYFF;lpNcYQe*d;*WtAA74p4fCkNBkLwiZdI*QuWx8+9AscN+^r%4@D',
    b'znc3XV`92lh0&`|2T`e}_Q;5;Djxb96>y!T$)unMI9f#vF!W0L85cVuvazG8S3_%V(psgg?=4K&pt%MJs@OQFfSP)6I2+Wu34(yP',
    b'QHgTN&=ARXGy-q##o=!>4`wLB97Z&`sx@#8&Z!WMiswS`HL4t7Xtg{iJ&JZ`BBQE&F*ZeSKETvoee4OyMV+zFL#pXIPGsNiWhbtd',
    b')uP|W!<KkR+O)5Um?hdEisc8od>iZ^u#hym1i5$a?w8bA0AfpMti1VT(Q9pljvVdKCA}XV^`dxBZ-~{XO$k<R(BRqF<T!oJ4<H7)',
    b'wGI`(AngF!^F#Y#J5kaPKM>Pmc=5zX3H_6pY{S<br#uujrK}tZ$Yl<*gs9mQ&hVeRIg6hqH^BH2hag)E^H)0<gT@ovsTzLlJ3gMt',
    b'Qiv@veLUU*AJwee@nyrcxAcTbqfEtCBbS!5J<BLw-3tP}(%woyc)6=Jnj-O%9JNwEo@Gth3>afl)Lc4!qCK+&7@OjZQnTpiJGw7K',
    b'1`dhYY7j>}hk(WL4i33!UlpKmQ#k=e9ft~?#sqVu@djkL?14-rgmnKp2~jIzjO&ci=2HlAEF`>{MhoRyc_N-x^q8W{*gvMg8^bWF',
    b'&QcpUsXq5TDJA!qa?`n8!}Pf=UG0V4-RIZyqVW_=p5K-UKECgsx!EW9P`1RJPrSMARDuar+UM7c;=^IVGFQ$KRumo_k9_V==G1nw',
    b'3yt%D7w-oLHo~P3#~zU^jXP%HlJ&O(;lBGRFG8OLNr@mUh9_(1=_6f@UZ1t+r#bMkYNUs##vp5_<{cO)SEL@Lewdru_<2<(L6RYD',
    b'uGq5(JTsfsoF`;r8qx@B)2ta%GGV7uwHg{;%&H05^lQ|s1&b#7MU+FiCoQ4zz|F9lZkqaO5JsjI&w@CpiX=taXwT@>rm6-u4e4e@',
    b'8qvyxRu}|+>c@epO&OON&Cxdedx1%cz(x|Lnd5P1_{;Tyr?|d09`Bd#=uY!*?cCZg+?$>1#7^~H?e^le`R>A1ae-ytmw)A^;ep|M',
    b'c$K<X15@OrZR;jT5+kzwXhm(KyrIAcm0mhb(p-~{Gw>q~?e-v=x;<beI28NNUMAK>IRYieI?ql+`A7Dsuzo1tR&i6~Vd_+t^$W`3',
    b'8|GxZ^$$CAZa>oN#T~nS?7`Faw>Hj1JWy3PEBY-8o8e1JN_O7eZBE|Tf6u1Z%v7RY_);Yu%7+bjwQ7l&HEZ<_d>;_$r6wW-O$^p|',
    b'vW+L%)8)4{RV77VM(Wg#{f2Y=kv*5&)$K}=e8;jfPbu@<U6s6oHa#xwEs4D3KaiXG^=F>dkBSe&F1D&a!%y0TUp0?N?b&Zbhy5PN',
    b'jQf7zbazOfFIsiH--#42LOoX@6CBDP)TC(MT(9;`Jz!)UpV2|3dH+=`Bghqo6+g(ke(Cc*j{!1j{b>5RSwKb39M##<W_Lh9Es4o}',
    b'!?c>z1Tb%Mc&mDwYxNQQ_vV%PIW6e?Zf$I>tu>=ZR9`Dd+o$%iiscwG1p#pe+$l>!az<7kq`IEs(vHokEwZ(w@Yg#!J|D~Wc*#?)',
    b'LAzVy?WGzUStq1yZIP1pO>^MH+N)a9a(`XRlV)>$2xgAVZ>7%Ik;sS&F?$R`2<~uCj%JOjOLrmtir%BJrP}^R&f9k9bfZU0%KC5b',
    b'bl+(my1NnO(YI0bQ~yP$o%#kATBmPosdI+GZ8c8c!=!KeMkCs$Z})ITcrE+km14Axdtf1kjR&b3KGB_(3?IH%3&cMa9@4RnE!#|C',
    b'nQ81YB7{=}aFpwC=@hjY0&;{$AFZVJ#(Wu|g`N!#G`6)=k~{4q>8HjcjTVb*Br=ABQHR%Vdi${_ZKY7SO|~kbpDB`HaNWP?&9gBi',
    b'Xk-UeXBRT=d73Jo8*GWYIe!$M#SJIEeQKX)=2T>MMbJL#BUYawkt%f@@uXwj!-ggBX8kG+7ameI5-hKpg-5v~thRI|jYV2C^+iKd',
    b't<jIBc-=|sWjLA^X`?iJ=r!8~X1iWD?JDTsv5u{S@vyv|DAMM^sJ}HnyQ4X-*SZ{f?1U(1IqBGKU!RW<T_6!9C85F$CERRpvjcYJ',
    b'#@3XExSLE@*7^_nlnvN{r`-KJeZ~fx?*ESid(<a<W$gpIgU})E+>mch0**LP$K-Z#3s$waH0O1fKBMEzLGlIf*CzL_JtO2YLl3=1',
    b'Y`4Z>9~@{6X^W;HN*o^I`u5E`sy=zH5E^Jd?EL!<QWom2)4@h()6<s3Tmq>+7oB)E%*bPRD$Hp3Tex}~_+$cK3>zk<iiW?wuhZWm',
    b'r?t&6cke&1*lM%=P?K%O6B+1EdkV;LlzSio`fomOjQ~k=LO2R5L}2xSdfk7#SQPi{K5i6RswSYlX$a7Hq|P6uOg!IqpCZl`ilLdB',
    b'NatJmqFg<CgE`L&&2U57A-gg8_E`QTQ)#N=!y)|tvl^Sa6b<_i_MEf%0P@u5jPHJCXgp~!AAYH6TLV~qK<oNIvq6SfOYX1sJ9>Um',
    b'-<U~4fHu^P+8>TSF`kZg&Bb#EvD5Gke_>in3j9w`PBrr%-%KWMcWl^FS387`j@k~wab^7;O88}e+z;ZR?S7fer&1VbZDT#r^aokk',
    b'0EXt;A+}{5<$S7MD&^Px@g+hb@oG@}Y`I2p@ZYY04=?-Q&&a3w&HarTfu53g<TJ}reYjZ8-?2cr<JObqp!1)YfwUT6+#r4D_*ZV2',
    b'j`PB1-ABz%lLp_%05r+yMKI-j1wVX#O>XD`hXYsmas+@_Z~ZUlrw0~Od2&_DC%<_*CiMjuduG$z)ZcMeaCimr%@#;->iK{E?cX?=',
    b'(Zi`-Q?u6Cbnz#krhzmdw}}$5@@Xs))WRB2)bP;D@p5xmK!?_2$73IM?@8CE)rK@TigFrkRC^tP@I&glR*H_dcdPqr3{>R#R%Auo',
    b'eiNDHIE|_CFOPM6JsOX4*Z;QBA@xx0q+ZMVz6Sbq(T!qoOS^1;Wl{O|d@*ypc*bx+uL6f^7mNXRGQP-5FuXfHd^`XC{%Q9#NNs7b',
    b'GaM8;czP6&gRNmb>eM?Nf7B;WBC11^{x>{Hjzs3~nwzQS?)c#FhJ3=$xx~>7z3f!4Sbe3tvZUpCEioe}`!RpAFP{$Jw~`{Eh4JLW',
    b'A!Q|+n_6BxpAXXq=BVdiJ34jH$a)HGb<6VPd3T*J0hJDWCj~B|XYfsVByM(3`VvVhPA*;;#vTRnSbFSEO^{9U3tLD|CVR=NYkaJJ',
    b'N`ICH>cO{Nx%Ei<MN=cU4sTfFCmMV<nXx)+IShZ`)OLbthqab?zZ!H$Cnw-wA)#xBOZpBFr%PHMtvObcSNvdaGd{cHqBBS1I`{W<',
    b'awgsi=y24h7Z_+d`fgu5T=*?-&5>8J(+*czI>p5encoh2R5*$g$o0pON(0|&t09PLHx8XHg5;<^%x#U~Utq;HG15|XuGReA?RK_7',
    b'5s@C`9<nLfAJ^n;7;egXeT~<>9A*T=iE!KvrEc?g%MHIw4uUiV1)`yZ>WNje$E<b21zOp3E0-^6m}!R)QyoO>(>@!jObB<}cqWl<',
    b'CId50d;cR~(p>ZOny;x!*;#V1vh>qzP-~VsPVnM^9neKpt?FW?HFW3yIDvGP(>D07Muxja<o|ryf%!vQR?c4f3{@GM8gt)1@9ELk',
    b'!K=q^hMcuS>uWJ`Ds`viZS}X2y5Ng&j+e01&EV~zY&dCC!@8>Ka~g5GDt)br1&|}BH)>>|?&h*%u8!?D3n}lj85oi>NI~HiExGW0',
    b'i`M;%bVFM?GR@Fb4T~}~#-exn=Ju}w=%>3n+;PiAIJRAbNhuwU?N{K~dI63n(EoT6`H!usUu(yX{p;Gu%_<yBf5X>zHH)Vv$)HX~',
    b'73b{<SD3a>F@od^sjo=Uw(h5@{Rj2Wn#31edyThG_`ln%hkhSVc7Sdkfx=?e5)6S})oy}Fn+TCZq&_|O@jI2CJo2j*Bzwcb#vuCS',
    b'4x5AMb3foqriWm)*v2d;+J`)2FR<#4eQpz9PGM4iR`^CuRl=5!&u?L385Bpu9IfZMi@7SSiH>xDQ^41+p0ef}AZjDIUBd2;*v;d7',
    b'caYG7gM)|0veWG2*eYGV5cb!+sWE2j;pc;Q-zYKpgp^||E+x*cl8u>68<t|p;c_}zDpIL?pXA0)iAueVij*hNVf_bE55unG@pwUv',
    b'Q9xXRq6sMwbRdo==0nhd<O)ACP}+n`qkw?N=Rz>n6XA0Ycq6ee@uia8Xxkh`Bdn;7x4A(d&&)La1x#*i&|3E~)ut<OI_?~*<k=<q',
    b't-<yrU()-n@j7n;I2FW%2v|LHJS=iYszb58^YBP0tKP*#PvT+mJdsXOtOzVwkl&EZC%7#Wr!m3cJqFG%l%!EI-3^(tA0JmFH;{y`',
    b'KE>V6Z6%T+Z~H8FBlZ#-)5>CE9j87l%tx9i=CEE7eQE7+JM$P=Z*B!213R59l%90_whR9tHt|sr-`X-h2DT4wAAf^M?8r(!2Ijl9',
    b'm5+q+xWzOjN!_{4M02cel_hn=VB!N>nM}Ovg!kZu{wr=Og@B#O#_}QY-P}k%Bvv}(sJwyvZ5H`K%;KXUytO%eNGu=R3_c?AJ2HO{',
    b'iScgD-UDMgZtlzpvL_on<r;jrk?x9&ljS=W1BB(Z(!`0fxX31EM~-HZ^A`zO7yde5zwbirx_nfJN`kG!A>{#&iyW4DUlf47`i`Or',
    b'r+S8k5vf1EBdb^Qn>mZ!I(>2S`jVBKy0|>LJUu=>di9E>7qN-55`#M%#8}MLYRGKT4K(Y?&0?_nY$fb&#66ffH+6Vc_cQzeODWao',
    b'ZNtUB?ebEv7^v0!zo?Xg7@Qn(Tkf~m%pCfk`%TXo3opZh%dhF$xm(mEXV4o|+)p7=A9xtKSloTyZ+q3)cJ;u7=H!<FV%zw@Dzf}Z',
    b'M@^8=;aOM{A6G}5R^)m`)nKhUW(>@~Mg~kbW};Y3tUYMD!fTyjIm~UM*z9ePf3-(NSs6oFlfKiTDJRZmviN9Xr%ZSoIo#8S30MfF',
    b'4P&zhJrg!Ey39(qz@g2<XC+mPB{d}hXEYiz^t3brY~)wXT+*lRs@k07$HaGXFej2*N1LRgleMkO)2eSr>zF9qbPjgh_`YIm(}^Tj',
    b'`oiV#U%>n!EU)0Fv2T5l^-UjLEp^@A+HK_P$!U!?e>Y?mC*N|grXZ*;d{$Fq1bfqMY%n}Hz@Kw$@B+jtMT@zM<ztMEA7Uu)E{gl*',
    b'5_UR2kYc^U6Ur-HmXsybn9@W4xWnA9etNWgvs^5y@9%HRYx{Ae_sr&Qat@Wz_akc7n1>UU<_ReB*ulEi%J5{htFUd)J*;DQ2H_q!',
    b'e`M*s0_R)yuL>Q->akmo34?}$3Hc_T@^TD*%ye<vSWcaXT^{C#eK8B<`By184c|I`a25FJ=px|@;{{iti+2u&M$uK|yCdrtUj=ch',
    b'ETETMxlycp;;Knp^uK5ov#TIXVG+ITDh<O87csgDQg>txldCZEN0tycDh<^o46dTY*X0B^Wk2f4I^%L`+~2N8y#|&RU0NcP@-;N)',
    b'56_jCbqa}^mc!nkn_vIQ9eE+5$!sck>CMwKt>cem*5M!f88XE-*F)>&yjXK@+|v40A(vB?d4^g2qwLIH-So*rxgpVXtiP&RU9Ty*',
    b'{R^yNJFeG`+rOdnnv@eLI2{mQ29i#P5vqu|dMJ$ES1e=G$!$l$45J`NpsmTMKALRDNBE|blANrl%0+g%4b)MI2@iug_SCd)^9Lsk',
    b'(}O7!)h$j9?(6LtrG*oR+wn>ZCW~#^Wdx9)rgjK*E7LmtKX&heReA0y<{AO@7RCZp<QqYC2{<eurJ)g0d$=+VC}g>xG}0-O2t;uz',
    b'F9P?ovCGf5<YrzBa^8+Dz}I3S)3;7-S+)YQOLU}xv<OM7v^72*JOv?fAT2)PT5pX`3r@jC7)Al0XjXn!U$Axs6}T(yx)X&c=+$i$',
    b'qM%tf$H(*2-N4Cs!_&U<-$>E>;f??a7Q+OnW4E%+HMzabX!E0PZ!zwd^UaM#?eU6pVoH9ZNQ`JzaR5CY0!1E7#|y(~kr}A^V2JcX',
    b'jB8R(A%D4wGz!BnSdng_CO`-8%0=~e<1@p8?FNpZ0AZ85DWF=v>;h2jjP3+b2vhSm>Y2LJ_7Qw6(6}m&JYTDI5J)V)?nJ@r@FL44',
    b'`Fyb^ONLK7x;lcC_j2enBK2I$CKu8M7`A6U2(bp}24b<!-?4f+buP;0uYEP|=F=LzZ<rkK<P@gS>)iaAwXbQ*Q20M=91&C2;XCmZ',
    b'W5U4DY*5qlXU-hxT@Url`TFa*Jfpthn%<yT&SeZuBEg{8>b@~Jtw-ujIh^5ar@`>88a~;r<y+YZ!D>7HZ{c79url&~p9vr3c5fqO',
    b'?nqhIfhisIuWLyE=KOzM6s!`T-_Zz{xjOxO0~Bx4bbq?5)6qsQS3I*f!#|uf%Hy>m9JP$XIH-iyr=HDvv-|!|LZmZK_h1KSn~F5z',
    b'u`H!ficQRyH$!R))z?BZU9HUV?DZ<QFJwm;R;V4vnht6V?J$Z#d2~Z>s6Ei6cpGLDoUq_F$pnWumoAfFA0jiBNswdDhap`$PPpeA',
    b'%cu=;7|tv#$AU;&Dh(Kk3f=z3Y2z|;Ldc-HU)0xZl!D^4!Dcga*xL-rjNe6O9g{m-<$y%q$&r#m1m2|hxqqElxL<MOE|7F*6$&+l',
    b'35P4#&7)H%Mx<&2>p<4?`<x{U?0G=L=gshT8vejak#DcW+iPsa-+46M-O^4HCbDAXM>J~4xT1{B+LdHLB-U>s57_*=_suuX#hVv@',
    b'd-`f#(AyP#+GO`)SM=XHXQ!8YcT4i_hB&Lm^}L*~KRf^79;Sz0_H1u&e#0J_IA0xpBgCBiz|>hCUsmUmUcH~+v4Ho*^;gj68yN22',
    b'Zx<l9)L{w__?(53R`XA^eA>uvm%^)m5#{vR+#N1|(_sUvq#vD=Po!7_J#Oc>)M?%!ICqpTYyG!+=G-poOiSb)e5J)TX@CJ^FW$|Z',
    b'<MWfF%M%A2#dj3Yofpn>alfXAdn_~k5&%1P4+7qL7aw3YYrt~8+MDo_piigP=3}$$R)<)=_4XRRpvxu9V5|>|6{5>N)Viquob~Bi',
    b'o4>o4XRR39K^|0>WI{N>Zc~y@g3Bi(?bG4+FSlM!Me}IArnT8v-0sVnf@ezF+ODoiliSq!v17wFKJ%@ogqt_H&f35#`BA}={L-uX',
    b'^Ir8DQr8WKKNq*;ZuNe_hFrD(sb<^lzA&n2p}twt>U#d}{ko}5d&m8$?Q;flx}3A@WA*gkuuNt2m!>!SFZ~qi<k;_;p^E+w!<28p',
    b'h`+2O!QKW=6B4Fv&4>x>S=J?`{JNN!N|auAv~M8P7BGpsRwZ!kfz?axs6dyO^WsBy7}u)w0bHZB3zid?+^(JDAAdZ5ar(M_m&~4Z',
    b'bIAtXPaa9Dl2oL0<2WdNFR0R@szMT$CGo=24YGv9u?t_r#0`VOEeSNKTtah7<EX8PpdJ0i>G{bq4E=X}>?p{CA|^qRhiM!~X<AlE',
    b'7#BfN_<7_JS_D<($3+>XWt0$?x?!1kVHT2v7NI*bHlN{C7?&2Q>qTW1r8M{Rg1AW%1vH7upiErf^TIsHiZJ%_v<$O==4q0YIea9U',
    b'mqZcqM#ddVlOtmXY_gPwK<FwClFTQW8>OzF5ub(`kT-~YQdD7-1r@`p2(vg%-8f8>G@>*e8T$;3$@%HgtJD8`f-bk~g<<GcSp=(@',
    b'dPR|BRT#J#&^}DV$gR?tlDvq5EG)7x$nu;NWf=!yl>yOnGDh;_AJ5(#U7mh_`ii|fLB=n$Bn;EaPfH-X8@X;8dL9YG!Uwi0lQ79b',
    b'FZatVk742cG$&;h(j?FQpdv9a<QVCNOvu8>c}j9GDEzPj21}|q@nK$BnbWw){VXqNN(zsZDX;)z2EXvLFiEP=Es7|j9<^dNFy=3=',
    b'j=nzy1YV#1aB^{Z_44TArMLo_>(U?uUMG2&<z7ZfSX5C?t27A8EG#oGkMlfYln;|Kr3L&G0%ks7T4rM_@aE`GCs%(xKLs|px;#01',
    b'^9mT^3YG<Ysk4*UmjWswz$ba>`(^0`AmN}00xu_C78MaKGKL>5qsVi^ysUCU-7HKq59pQ`Wg3_9vk}$v=KQ3q_tF-C;YY7RF9Vil',
    b'OOORIrG5~4K!O}Ntw_VX$cn^`U09|hcWDv(ZURC}+<;U;;0JLvLWsV?%+V`s^f)YBATmudP%^OQ6#;(t+&J>!fBg_NUlMysMFSU<',
    b'6e+!`2tXjA7tkXMeKN)luaDkby!`R9Eqct4oMwR=<iOq_VxU|+m`dh(p6^F_?uJzv#F<-$e(p!06%(Md8>SH`A6TBiCvI#zGUGgK',
    b'<{l`|l)%I?68a$Mp!Pry##NBSNd%g)qFLsH8VEt^U_HDnqcHm<FVZ+EgCw=q_}$uHoLpjfq!I8|K+~*%mGJV)E0Q>ff;dQFDGEYB',
    b'LW3xaLF`EZlIj6EGyp}FQ{sWu7}LVQd_TN8{nN`!5X%4eFH98GrSRR#2crT^p8H{$x;d~~5rDeQ%ao)^S>}0}lO)a~H}b+HD5HY-',
    b'Wt#g5=*nc21qT#{0_B1&s4@_?Bu~l;td39o3b?MUikL=`OKFvZ;SG|q038t(t`90Y_drJz%FGcM=rLt{bb0jZ$3JNXuK*w{X$ER1',
    b'Nkcy-nGaeq4m_`ji#VmJ2aFej1@yx>1`S<hehP94<o6>IM3J=-)XY8by$bA*7gIk5-BV^klxA+_(vYMuJ6M>iAbFbQE(}a78i8Rf',
    b'%Y+me_$h8N#SX$cygfbnE5k&<fq<xix8tQSL=xq$3mPd;fa%L1115As5P}GV(T}_wT!7Gv!8Hj&x6FM4wmO)E1Jlb20)-pU3cN3-',
    b'eG^cwZcYfH5v+NTffQ7wUt~4?X`Xx34}F&~?Loc52f`JTtTDb0Fbo)CaPvSdf$$ezl*AyFpmOpY)L#@QG$64DE<j$TVFEr1Xn!zN',
    b'U?~$9MAFJEYFHo)1D_U23C>Mgd0<^=K|nhZ<_qK{1!GM!>SrZry)1Eq3d|w}y1=p&uyWLb11~R6Uhu`|1y{rmy)XzflDOb|RX+G!',
    b'Aa>w@72tuDppeouD+zd<F&M%$^Qo8SpaKII<idyl<%SQ{(ShS$oV-3}w)fSm(^?QNPF~fT(Rt3?kpL(iG5^`pj9nQ_Dfl)e7;omM',
    b'Mx|fn;5~;i&0@cxiRZhZJUnoIK)pq&2mc2Ra?tQD_}B@l!1mbdF(7FDns}(`Cax$fX6aG_3d;4F@dWp}C{pSHn*%;z-=dKHcK|C|',
    b'l?71T2X7eEJ@}k?W}#2t9JSOK!K7q{1B5AuJxt|#ag};BB4FG>*Lk4JfcmiHB!b;Wn1gBclK?gxsh<aFSd<mDRjp<$yp+N&A_1G~',
    b'm2p*oN>2jVdVqwd9?2r`L-Wjy!TSIs8?(($3A%>lE+G{oRW(JyT%I2PSz~A`lK3(B?_h2KHZ5rh?p0b__zV~%f_)II82G_JkqlH!',
    b';1*>bk}@kIFN$+(EUZ?hf~CkKKd(TcfM*FlHi4CQJ#a~?0)8vg2n;N668QZYYz3fc;DNOZVebX*_}GRM#O31j;<6Pz=JsMpgfuN<',
    b'a3@L-Y+%FE2aQJ~A4DRqJW2xacBoq=Y3aE^oMs?QuxoIspQmXKNKR9{dNjZQc@%Vh5yKV-e4r3)y9-FUumenBCs2WgO~4iK{R|9s',
    b'<^v0npe%q<f)u!!OxFJh4w>hA^)@?a&Q6iQ9FxeaC~Sa0(}C6?0Vyajum=tsI2~mMOj?D|1$JgZKqukw*VD__Cl?nO9-so4X@xn1',
    b'Hw3$1;0Q1d;01u|7e;=<>_jc3uy+j!xPb)?z&ykxpe5|z%1L-I{yf33NIW2P8M)y0g2Hn10EDE-VSkbbKKKVd7@#BuqX14?l7RP6',
    b'!H$7>4Dbu^GVytJ9-0qh`t%H^r!Q)g&{bl1W(}g==k@)&QViz)gMY3d;HD`|C5+4f`VB_c4fHy=hEXumt@Z?zF}qqoHl6F;b=R@0',
    b'0A$ng)ydHheaEiukGbREzjk)F>z{kzHkbK`{TFnz0s^)isb3UhE6ua4$}SbC1u$<@fCv<%po)Qw!zln-UDk7qM?%;ela}qd$5I-e',
    b'`P0z_bo8!L*S!L_^VvwZdi4hPqw5`6^&Xb6=@(qZR{gr|Lf6ZkfNSR%G<|(bOa*3XC+S-D71yWfoKC~JS<@Ef(6VpOk1d&O`uuQo',
    b'`sy#WAP-MukN#Fak%f`HtBgHi-s2+=?(XyJdEv}&ZtmCY7RFh8q|4>Jq(f#%N%4<&=x&&%cGOiFdNvK?6S;oRL_AJ(<pD?V!0Km>',
    b'42^ZsP_JF;p>Lm%?ah+5PZEZlhhv@Vi>#qzcSkwa?T)-_DuORB>CN3Wd~B|C*n^T$e3gun^(}K-MZBvosK&<hY;`qL?rap6<Jxrn',
    b'dpaTgOL>V+Z7@0`<JF`^;0Se+bl=q_L0W#q1qEqoS}$y>$P!((K|+S|j>8JEOaUz&SPF;#{%`JEUtbhWJ9~wt7af*P1w4Ec0IMsi',
    b'EzE=fZGIO3ipyri5@irEtA!RBWZ}nq>KI|Xr;#!0x;*A<4wMcU_l%>06$iayaV>pW(2-u8fNPxZDG+$?d#qn8>WJ$-t!L*oPV3b<',
    b'-6Pr3MWUK>q@xt!I*E-sbfy(&z0ws$MN4~)m2BOrJnJ^7Oexyh49nBh6a>`!9Yf@h4j;T9o`_zK6d0$|qai#c6a6EjhUs)U1+}i6',
    b'r`a&*C)df<gi4)OlftXlPAXRW2nbFWtcOBpsL;M~o!Nm;joIlRd<J+<dOK(7VNjf0LE&*JXk9PiF-bOBhF8m<I#2O8QbOmHlxO62',
    b'UeT5H6ifj?BPssv0#Cs|<>TtRg?6|_ze2wEg=R74P}(b!>2P9b(VQDim0oT4n&?iunHg!ujUeuQhHgf~=8PG>0gh(p(~XSmiB$UQ',
    b'WWv!i{Q$(Y4FUkhT@ptQWaHyJ$M-|>lTFRm5BUA63sb(p8|@!Vd4!^2eMQ)G7>SA8$KE;;Lm+wMo9-VtupD%GORk&u5B({eocjAf',
    b'O^d9C+-jbrjFQltbsQNQO`R?fhh6h{aS=ow3Ed>3X-)z+%Hx1kMOCE{Ej^mWVA|OIXC7oUN`tVBi?GOI7M>CnVy52wdQp5hEZ&p(',
    b'?Yx|!B0Dn*vIvg%^k!TlX=D>CZ%;8m-6nK4D8HGi2WQeAZKla)-CmOHbDRH}Ru#^$Lny7noGBZie)gV}MjJmw5RV3CW+f*AM6VQQ',
    b'qbdxeH*WuCMpY%k!PF8*c)tirKZ!zqG5jzpQ&LiiPW|_i=IjbTJLq47?EA6H{S~C)!3@icu<u=YQOvbu={1JGlB>wq^$fGCOz0X!',
    b'0~-rhS{NO<d!(6iP1C@P!+kDs{ekA$n_ks*yIKoX*Cu~d)s1I0sK%$-O2?YmZ7L=7n`rLYWqUbND`GvOc%J-mt*nGf&lJVlo&>Mo',
    b'&sPW1pZ$rjUanQ0q76ovq#S-%r;0k=zyykBPe(2b6DXU#JqzdQ%hL2><opbcXP?QkgGGAJu=wkl8Wk-9)5TlPj8TvZLWVfSnIU>m',
    b'grkq|n^{ENNjT}^;%263HCYwl@nkb&l$QwxABUwe-e!Z38F?Iz7gjj{A_5#g%3?o@_}^SgQ<4U<GocHE!HvIv<)*x&;D=YKEBtWf',
    b'C%(pWXaXU)#$kMwg(>%g#}f1FdaIs|*_*+=m*mP11n<Rn1@zs>fPNB(isQ4H&vfM`eCN7>JTM<zggaPbDA0_L@ELW!<k*~<8gYZd',
    b';Jh_HREAp&zYdu>=)E~_8*gsco{Rn#-F#7wo!Dv5tqWbJ_DpTe%3BOp+u5lD3C8&W4)2uMjUQOq1(w>YKHIeNbY|9N18pvuv?uf0',
    b'YbC67;DpkNh4PJy!>zM=sV(*ojE}MFm+jp^K{pVQzA!4wzZn3ZanG)mN!+L(<yjz2kkP<Jx&yZ>pR?K<bz%yHU|bU|$<#LdXx7^i',
    b'_3`At$bMwv?#^ygF&p1*Xm%9HEUmU1qMvNsdPqt{?Aj#*zM!=yub!u>LN-$*W`^<k3<0GwpLi@Q_ECpE%!eAvGweId_rMVQm)~zG',
    b'6qa)apg08wZF)_Uw(m9J+u-1ktF|mc#8wnb9-!SdkK(~A&bOWc6^w6YXeNOfM+k#+E-n}z0KbWI|NGYP_pKqeHT-?k_gifGjE7Lu',
    b'4z!F%R`@a1zt#rSeuD`fBKUWbDhE$Vc364J{&l{-1=p|6vDBoV!lKTBs&zuP;oIh=0^6AH{`NrK)nbt#O&+LjTTpzEgT`-G?_hTW',
    b'Zq-uQ*|JUL@X5UU-SEo0O^h~-GQ&nhvoI?Abk<R<OIPcqZWjEf@0><OVcTe=lww_HPxtLRC&7cqyLA_%*=>eIOY@EgY!ADeZob;0',
    b';>Tz~`RQ5k4mDykLt*b<v3!@U)W9Bu7Y?Kv<{+}uPa=lAcr`!G-_2wu=#tFU4vv~(uHSstKMV}m{%|N{oMT&SHnr~WeIEEX-#Ff(',
    b'GsG2j>EaGmnC+K3)p`5h{4Q2**RTb?t3_`Q6bJ`M!G|vA-M-RToRoj)G~r9jhDnE<c88-$@Xlc<y5i`(Y<_^*jCR?#y94oNXxVL4',
    b'A=}r-=7^1Qg0j_9S8T?`Pa})VX9i@9(Eq*P(g<0yH*%X93Qk(U;Lz#!Oe!<tSrfZMr1idWo`?NLZ-z?@MuDE9%?faH0QcjdE)ql;',
    b'Z}({Jn{mYm1(3R48ucU6C_Hrd{alxM@eo_K`kc90G4`J$6yi6c8Y1DmgiqGQQfdZ8hNk*!M;V;M>N%+`x<TZGk8B9}H$!(k8)QpP',
    b'<O>IiU$3ZBN^RCl{elf?F>CGJ{AHlPvC@JcH<tN?CA}@clCA~eGAH;H{4{=fS|quj42YhI9S3%oAWAbx4xQ#O-ejrlQl+*ts2I45',
    b'5u4WC2nda*8#bZ)fmDD)5F>RU@R2Y*ZFaFZjHI!3K9_1wH}GqC2{2D<W}Xzk`q){##G1oa2RoH-ze=a_Q^2ausKl*@cZ>QUZS|A)',
    b'^Gw#dhfLfq?r6cj!XKYm((RYZ@w5@FZv^Xa3N|o;4MxD~HMk13AfRKx6wo&S{*0_X$f3c!w5NxTur6#p!Kxn`d7?QS5VVxQ2AwYD',
    b'e?zU{3}qk8g!S528fPDeB&jtug)nAd^j|f|ON+gyp>fvPqFOc`u!Sp-Z6?r%&gJ|0%7On|zwbT|d-^-3EryjK4OQEi{~Mj}rJ$vf',
    b'W@aD+MtntgVoqgeNRL^uEro&cl18$$kh}U;rxamqu-UV|8m<@S6(tqyVH?(0_OShhuPBy5<YTnz>twZ&?MKy`ZT+W_&-vO+8pF~M',
    b'*0%U?M&8Yf;Z@F%e~<+TuqMJIS;mnd1G-mytOGmZsEd25Cm(GK?xf?%bIzyMLBvltkTKAPI;d@p><gII?Rs874`7d%hR6qgb1|WJ',
    b'H|eeh_J#va>E8~yUXt5Yu>?B2X^aa4s<k`r&ss_~2B&7I?`g#p6px*?Xd~bnre{mZOM$-UJGwe*`5T+ezqneEkC?mn`KR55U{|w&',
    b'yCJlQ3|}m+k+5(M20JO#g%s>b>tN{C#~6(CX)Z)h&X2t~5^g(n1;_ebfKmZVeC#u6v(Y=%QaBe{EvYWwuCM-NAAK}-qG~=(#pYx6',
    b'Ruk_!bM_BRaR*{tw|I9`U&6Kj!ps|YG|A@N9K>){i|iIl-k1&Bq@j+LZud0onl`*^7}SACh;HaZP01%+y}<sQbQ+&ZPumQEhpT?)',
    b'Hdu8ryE?mP=o>XQz0S|jeCUEkv?&`_hkXc*Dd=#d>#=$-G%0S810^Q-QHL1m-n?PNa%xBoIZ};)>_S&gIh`lK*DBW@R<}M92%ZV?',
    b'j$9m2O<O+DY_x~4Drkt>C<tja5a6RAh801ovB-@_SEW#kH%UabGJ6=j`aa753^#^7Br)2|BDK`OVf+K_@oohc_&l-W_d~FmP0xDc',
    b'sf!ghbTQ}!Jj_@HA#vc!vfIFQLM5D`!N6(00gQ&n)ZjP+4EFdB?cc>?8Tv9m6z$su-5L5$V~!Q}PSHBI0|siaJoxSSa6vSFJ<c_j',
    b'7^45(%oJoO^w=?m9CkR;abTEWq$Rgtx{ct*k&GilPg`?26jS0fG!3vFBwNM8Z})7tfNw7`0{_X(3w+Cg9gqOf@$RGcif_CNzA!|V',
    b'jw3LQJCHD0i9vLEo~_~8vPq#l5wKwvwU^?~$PLE48o531+^8|Twopb@i`oS-Ogf&@2MF5^hFCB>ve*`2bA~+`_aQjhcA%*alIA6f',
    b'9iKkIT&(&+6<EI1`C#W`TeK&tdX<36pLvjh1|%Yl5>%vx4X#=u_TVQHAD_)e57J~W9l3<=jxE3M8|rSMHP2qu%3sR!A<p%e9!;qG',
    b'-I>;Lm%Hj&Yo@W#G6WqT&Ggz^24P^D*_ec>6B^-&nK=?#iMYnYfcu0`@)nLe#2&a|!;>fNjbbxZapV~?t~tpQe^2@X5SiZ=>;7<R',
    b'rK<|A>#$j@#|kT1|4%s@`lsaQt^=zRy#nd_34d!V%8AI}vu>Lqu(pXAaqjCo{5(*!S}ccR=ksUI-1$R;YI{2P%=!B3xy%NPf$By-',
    b'&3_hs6S?Jv*}x2{OJoCO3jY8S&z-Lw?-~53I+cH52+GrG{`((4V{IR1Lh7V`MR>l|+CPOoQ?)=<zS62uOXa9jfMZ(Cmc=^6O<ZPL',
    b'SERpoX}h-V>h^zrSqrS_t04|{YEbdSdnTz;H}`DfVXl^%XPc&LCEFXz;qF$6$9MYZ;e**mx1oC2nhR0%HBi7VnF9QZsfly3x?K{N',
    b'Xq#IlwyfJ<DD`g)HoZ$40=PF0ou64&o*(#GGTHTg^FQq)Ot2!aU37#TUgBxPOZZKN6m!x}jQyz%!w_Omx(-{!pmZQ6#hwU3+cG5O',
    b'qYlb&J0%6Dc975pdcxLdGq0^C@Smy0E|_(s1KZSewA=nRAvhhQ@$q$N&&P`4u+dtWK2qegdGpYhz8PLO2u47B3Nm7LQ1fB5G0c>_',
    b'XdYn<D(nrAp0;VB`=L3lx?0hj{Q9%A|5XF!>55eJD_P~;)cx56_q$PMb)D#gnZp<V>A~KD)?;x$SeFC*`Ir02ZU3n@{09NNdVjs|',
    b'`ym^-f6ct7c|G>46f|RJt+|&h-88Lvkvqw+{Y;h9*;yESl>!ZLJ1RY(t)EiQ+L~dbY}-9W=@?hs6p0*2evy8u5nj`BqW>g?c(*S{',
    b'2Fugpv@35)n9|OIbHt-|JSeA~h<W;r@5N}Vk`sy1*#ak9d^CK<zsz>(C-?2YFkfwW?PTSz=~!YL&#hyl-_m=N-=i5+Ixjx8r`3xO',
    b'_GUuV4=?L@*deo1`##Rp@u+3CTDADS=)qsZa!LZY-#xqQp4)LtD-l>9^~Iw*Gb44N3pt;{1p?07v%+9Rw(#ZI8$+9?#gCLMz&6~h',
    b'=;E$<Cx5U$f|K93RXlz4%As%0yZeFoMH^>s1UM!5yfDA7-zEaR2R%6qT^@2$B>F&x>EY<|z!M|VxfMV*Kin(nLyc36!7^tr8OdR&',
    b'&3R%RvLLsMTj+It*@xHnj{=)e{k8DHj6bK~R8sIy0h>3?W@;3@b7;2*<L4y41mk97ekG<%=zjfvv24xu>jkJy?dygH{4Xqy?#*)X',
    b'4_Yfl8vy)xi+n|wA8C0xzhOJbo4bj_jrSJ`JX~qKSzOPH&u6eW6Nj_}QjgobHG%&T^y}s2$&0HuuZ~_f`gNr1*rT1csrlVb+i05h',
    b'th+pf?wt4pXE&O2@-v(*^ya~Ko=Bm2^DlZPia&xp@HcoP4^eW(l&np<7B4iJ5v0Ain0nJTZ6$KVUZA-u^ma?^&9~DepO~37{|xuN',
    b'M4ivb(mn4L&5#ZqaU}V@F$~K=R7`=4Q>RE~s=k;R^+BI_D;Q6_C1;qhV$rd)>S2<+Gb^xTx8DW7R-+(V2<l<B_<i)51qW&uzEVFk',
    b'mFX~$8ulEAy#q(4=QPoisf{Vh@MbXUZCtc|xf;XBnMrAhc$28`y&1OFIGTiIgml~cay|KK8!(`x+K257R+l-lJvY+HyOI><k&Ti*',
    b'o9Xt6p0_OmX0Sh2Hpj{;H1@}6b2`P383cPHP)K>N?29+)lKz-j#pb$YyFx|A1hz)z(R(oiBkimJkVN+XaSS@a^=ZH$*;D?1_TKzC',
    b'jvGlB{hfbB*%5Do{M@4IKFpEd(vocRt*%GP@=Q3i3{(|L>J`c6$0lv-+x7d~U!qPNiKDukvOH_Yj4gEmi9{liNF?&mXbX~(HAk`1',
    b'Kvb11i(-XsIqm)uqV=)&R~eiveCK#k;$@3wXnI4Etu1!3d=iaGygm<4omp>8(nB@!cGFJ}%cnVUp(<x*^M$~+h}_-y$!f+Fjc!Cj',
    b'Uf?8-+kb88M8xyXzkmzTV~5Q(<Nh?I#}lqlN)a(!<>Y$nu1{POhZ_{vTI(lMS<|-(a8P%ZPPw-29v9eHHp2lr^34iTcM)*P{)Gc<',
    b'|2WUj2ZL}g?mkmO`*yE8*tq5$D~{d^vrZP&KSw<m+~4?l%|-U=W65*mgF#lx^rpjwyaU&(i#s;qHIjr5QJ}Psw*w8PRNH-W{hbL&',
    b'X#_MJ!gk=Ri&AMbv(9$<vH59O7gci<s`>Dv&~N{><w=O~{J+47C?`Ul_a;A2E|}linU0)$Lpm#SC_s!l|09gTE*@L}4*bpI4}>Yn',
    b'<nry260Y(EYtP!QL7mq{3ZOb7;j@e_-}3oIkRwBPbZ`O(fE*4XPkm-HEtuiOck2PWwNO*dZ|RrHxjObGQx@J*9pwm3^trscqo%-~',
    b'R=is0ge@lQjQ5neiF*G9%r)|%1b-MqUSVrQ(}u1#9Et4VAs)S0Qxv^c4RU6!Eh4hqa97vti}UMNC%c73Sj*@yyly9QSzv`<o^>+s',
    b'6QcdQdkBE|pmO|un{aYRK>#zX)e^W}Xv#!RKiG<${)g@K+G!0~l_8z|lj9i0O{{01#Td6NaL;g_2n>XsPui4%Z2(|5Mr)oNbU7e_',
    b'0F=d_9Sj!KhQJ0@^Pyf)!t6|Hto7ikG22!Bg5G-NUDMDT@9Rfi=Y;P67E5OV9P12qR+VFaqF38(;epl^97sT0G#NyO;6AkIAa`93',
    b'W&jTsB9+9h!?f8*lkzn5)pV2{*GF{Q!Zd&T+XVH|Bc2&_b~rpi^BlEkR<7`0x%|!t+8dZH)wEQ&XjeBcwF2pzNX-2yv{0^GCX2ZC',
    b'iKVB=VE=W#O|><RlD0CFdeQ1jk^OltT59O*oa@%?h0|QC)S_Z6nd?HA=-J_3rQ_s(1uLVRhkbkLfp7IKgA>)VjQ0?rI6dUJ#V0y>',
    b'6KDep=lO}WiqJN07cE71;Re!Uf@T3?k4d|<8TtW<>!2a+?zP(t_4)okk%?f(UUq-T>-4?8H|xyh3!5d{{_y$P`TAL(vRxj&@r&?*',
    b'4#oCZk@3T-ji48+g?dj~>}icf{@aE4Lm>YU%0EPJcjuEhql)T`H*K^m$F8M^T-jsWDlLl{6;do(yK|w@UB8q#r0U=1ab$R0M_xlT',
    b'?<NlQSN6~c_wlV!6l!L{Y8H<A<(zTVXlobaSB<`O@n?S3zz?7K4?3Gyg-|OJZ+W#)x7(ljQlTbgnqL$`hA;^rI0o*h{9xPuC{p=+',
    b'@+fHifZSyeHoE%WN9>)rY!o3MalLSwu=a2gb1)fFyXlF@=Uv+~1RL`iw5CX9Bs-hou~Zoxj|9=){}JT5CikX)&q@F2R%68O<SEsa',
    b'nsWA+e0DPa!*G#Z;Mpz2j?>S0Hz5_X&{Oz=cNSJfMwtJEcXv|V94fw_%ZcCS${s!2-@oKh$F|BHwF@V8f+93Y9kuU)OVrthgf+^9',
    b'`=>2Byp_CYFLw%~-SwWd{63jUWe2%=e>64>uBEV{kDb1T&RXiqv+B!qO=C^P{z!EzKh|uK?P(YFskjT(Ps`i)XFbyU1NJ~0Tvr{F',
    b'gSUDrH#Ole)|5l2Ha@&u-jbVl%$k5+2K%351iyjc@5uVu67=tB2`=GSy}Y~RejvZGA9UANd>#0E>S}f2t?#M|@Wq}p+x(hy-z<B0',
    b'?9s1X%4r@0Mf}z%rzYR(ULl8{588&l{C3&i%D#To&xc)M*UTaEz~xPUK<#gT^Y+K9Ur$wb`5W(iJz+K3&nGBjhwqM0p8eP!)vtd%',
    b'eevY@^)VdQ|2TR6<MVBdywfgJZW-M6xq`jdF7>|BO21?r{o1Epwjk3LtX~j+99W|2Km&R0r>B!X72nx=a!t8;j9e&sWSp0GB}=7>',
    b'eE!|I^)Qj~hi^a^Y4{0u;d-Kxx)=Z2h<|Owtu`V)kfKINyMU~D^Bn*3DX9qx>vVlb^V}mZR(J#W;k+Ts3xGDN1pScg0q*G=cKknP',
    b'wyI~(PTGV|XHTEC*IEpeI3P>rl<tO=1i(5KL!O5-9VG!2<BG0<FFPH0bUW(!l8rZHzSMEVQ2TWs6~s~rSiP54k1(ILjhB=QPa{|#',
    b'_2V5*a__%D?tLvNeZTJ;lTddRUJsQjwxDbC*rNvK;qJgmC&^gIm@o?22i*QSR1j~uHPA4|ufSV63Xl4)*#h*(P#D+Lb*B1J$b-O_',
    b'$;kF%xV1@Fm5C<HJaRMSR&Fq@>F=`FABQ)Y{R7i}oy>aIOHo~LQ~<h;Cbz*p4{q0RG3M0kPI0m6@NGPyhECJ@Wa{3J#86nY>2w(g',
    b'5lqw^C@>b@)#{dI2Wk$K%(f_Ldv81~WslYDX*vhK4Jh9CG?84O<LDR{!~b&ML^2@N)Eb&vsnH+f*lD5jGcu|uY)`32z@RDikf#&j',
    b'_q~S?y|Y(O{_)`1vZ7aO`k<@h)hy}F*WUA!*L&AD<lQCl)~kzUy}bSC{fB>;9|pzI-rn+($z1Qt!-s-V<vXVEw@cPOfUn;#ubE9`',
    b'b@Am9*M;x#Y}wH2V|78#KEM{gU0r=k*0k>d_&xOg4cH6N^G@J5AV}@4uIPi?<t6p_L}x?Q2yZGN%wk!3Uh;+<;)fl`n*QPef@^Pm',
    b'vASJ*{(~?CuooW>z1Q!lH+p7FMW&bQRyaRkjo9AsDCp;F;C%05_3m(w1xwtJ>ee$D@kWEln_!qKfNht8@AW+^uztmS7p|J+ySok%',
    b'o;KYT=)`5Dp)A|*@I1fxw@W|usm9(*HQ(C%paw~OH<Mwn+fVf7rezTm3E4S7Z^k3MYX3U<xp#jb9zps8#RcwkvT1F3gA4TxsC>bb',
    b'0mXVOI`_jo6pt@}ruD~f*_IxmagQT2K#jGWWMBJ*Qt1q!?(u#ggB*k{28ztpty)R@(cTo~6p$n;qbem)RmORmCV5^rS)5i;RfS~|',
    b'5L!h|5~fw1<aLq}pZal~1#uCRj8?IKWF8x-87+>UH#KQU?Wbu}he6cjRnx>Iu4@v+wI3B3NmC!b#+e^Sm0uHR()fgyl%`2$8C|Fy',
    b'%#TZ}+z*nvNpf0-WkvifOCp*jbyR157zA+{6;+%DWnRZcM9VzO>JmPZBFK`21eS5-(zL?Z5hFFFF-*2eqpS!?;U~Et79^x`0aJ{U',
    b'kW@{a6j8&ls^TKeb3cvqEKexSEn_2fP=(?BAdX|dDH5P)9#mCUG;!n?u<~&pCw`Nsl$2Ex6>(L>QBjtps_Qh0n*x@+B=!YY>u3t&',
    b'*F_e`c@yR}kljywKaYce#BmkE($-m=6>(68by23kc41zUx`}C4mSNP86qv$B`qRfhoV-C7z064&L{%6!z}{JtW+BY0s7snwWmuFI',
    b'%}EuIItLbD%n(*#5ocKw`&E@BG@wq*hCgbGD^U18jbhkoq>PI)C@6`mCMju?M^RnGbrF<lStg9~aaQNFf`4MbECfvJ!nf`BSEo<K',
    b'v{=IEc^E}O6VaN41<j~m6hRW@MF_h;q)kD~lCeSva-j;N6gVVH!ng?2oTOox__i(g9c=bz*tjqkTG2B0Nf{=zO8h7-il&UxvTkUY',
    b'F`i8P0Cs#3#Zg?Absmz?FG?TSBW{{Gg2piWBF(b00A})i*m`N)lwlKs?1@O86n;(f3fMpOqpHp#z}HVIlGY@FhJK!f*4e8imk}Jw',
    b'Bq_6qhDDI3grs>HM|D+|L6~P{P{O_s0ze`I3ed8Of~*OWs&1l`79e{n8qW~`1~ig9t!a_?NeIi`kf2IySfc=Vu!5-)n%1=+hcqhv',
    b'G>g(Yi0T}80_YL>5nwk@5E$?XU_a0xhiyg@9|Qqxi3k=Wt9>|^Kq{6M2qM_HAhQZUAy2ZH#&G)hG$uhxY}-<G=n%I<QYWz6^P;MJ',
    b'pne1Vo<>QOMmYfq2+Na&QBtHJdPoJ*A^<@|BiJD&B>~`PI|<HS9KSmI;pOW-c0m}q078}^<Ur8E5femd11lfECM$vIn;Q0qU&kTr',
    b'7C4zRSS&xz6F7oW_!JU9bsd?>AC&HJfaipQ>?d&u;vNn^V7Ro2vNTKJd~9d|+a6>SOc|IWC<+=hRaRDcn$=NeJBM^R`ecz@g95;g',
    b'*Q5@c5>$>D_&g0Ongt>3K0g4N?Uz}S2k<{=Py$LmC?*+cfLKRXNjTKEQXJ~VGa2M85Eyn{UHV}IL;<a!s&X1c6zGt`f+R8fb42{2',
    b'sjE0iLO8^ML*S?^i^h(JA@Q7aJOZzk1ZExAjUS{<9?*m&0T4U}IaowNLYt7lCP?EFcp=Op(9-e{_Dl>?!nPa6<UeLCf}Dc#lK~S1',
    b'b=p*vHdzE36QQsOq)6cSEDJw{gA%wRWg22#hY2ZtLK;S@W{!vwk_wAEq#;?Dg4)p(3^uK49RvHdED2{<kbwFID+b3mP^1Wb68TkK',
    b'#-uK)BuLWI84IVCX<#YJBrKa4q=X-XYCvG+{Q&k*Q^9X_p5$<_#2}tBIALmN8U=L>A~j1ui?AIXuwBkh&R+Kx{MOqPK_aGkoq`0a',
    b'<GcVitiy=LGzno#q)k9c1lyDPO_tYilBRh9n+cR1pN3_gmw;q7OK9uSAW<4n9~6`nG&6Q+HH7+rln;t)1`15$m#}AH+^|TCrU-$B',
    b'2s`AW21Gka$SgEi=ofaB2Y%4rO#p+stTLEmmIR<nRG|-NM*!?VDhdo7fQ*L=MO^@sHZgPog))lhEF6A1dHv$)*%_+Xz#$#`Y|eEP',
    b'g3=Bg5mLaRfzu*R!mI)gZ8s^X+%bWZqoNTlDBQSc4QgjS3lGMhPcbaA00>=!RuvQ=u;A!~O;VKws8><w!#Q43kn04_6<D$?E#M9X',
    b'*C&wc@C)!V33;V5Hr*ll0`%S^rq1R$z=@M1BY^QZ8oGf{4Rg3>n7d(W-3S3rX*iH_GXzy78~T?49A&kz0I{PwHG=Rd=&4m@n*^o`',
    b'4KUb+1eAN~P6%ZQDmWx)7?<uKemXq?J{tOiPy>B8D=bUcUT~Db3%{t~V%oTLZf{3J$2f|@JWL~(j?bPRe>Zl7qZ;lhX*7rGD$N=Y',
    b'PH@Q10V1GJ;Xr`R6wd+BOVn}e^s$Z|h%xJf41<4vf_{;I?)$?na7-w1S6(bDZ+Urncgw6<9<z$xENeOy<dy`Dy~ALoo7+)W#RZpi',
    b'6Cjo`<0n>|<K{KJyuJ`ZOl^I!%%(kw9zOJ*GVeEUIT*y*BLs}~b!*LLuRNVqJ9v;Sy!=5BF1#Rm5M-_0I>;Y{;UPNud9%D~t*f=-',
    b'-QA(<;-o(UQzI!*Ac)KI2tsy;Mgicixg!k3`BwmA@;&9|qB^(stI=}x&0YIUDp$zrO!)+meEJ)$?$|5EJLRWywdmH!vFB=7oWjjW',
    b'n_qB_MOvCz6lsoe<$3Q`HR}yyAECp6F`9lPiJ1JU4d))ejlscu5vGY!n0u0rR`$e`M%w9WwZJg}cQaDfVOZBe<fm}`B~efkP^YSd',
    b'Rt2-6QMki{N?z7Y33_M&x^WQJX<5~9zNZ)}=(^Zv@CD}tGO--f1FAR#<-2alt7|ltK*d1!jt^W1P1QKU|NS|+`9N>rSJmM_qN8XR',
    b'#W3iPpZyLKJaODi^v=2*4HJ559<>9p3X<9L$n<Q(5}R?3X#+wY$Jgh`_kq_vjQ`d4x}y!c>ox{ga?`K@yhrB!F+st27kZ;Cjr(g5',
    b'?GszeO~L*FOOM3F%|-W`KA!Ln!B+BX(>xS<j&VVO@oSJG7z9p3w&9njl+@43)v}@Mej&G-yXgsF9vxoY(Ej1@iSQc95S;j_)5KaQ',
    b'C_S26R7==>bq$$2y2slf-46f&e#u-2cSkw#4|+XZ;I}?QE>@wl_P(~jkJyDOIu??^9p@Py4DM|E+_8ZJ)(M+A8UIZ}Wr5cNKy!(x',
    b'`Ugxz{Sl9DRNHl;27}N^09*f)$z4$jEffsy3)BogE=I~$WB79<t%APDjLEFLm{oB^Z;o9!S7CF=9V6nTGc+zt=08)yt;s;QFq+Lw',
    b'FnGh3*ly5Eg7e&OZ@vc$?zcqwEjmw!-%vOq+Q(OZ<J#f)_y`~j$$SEiBNQW}2cd$ac~X8J^T@}5i0}g|I<M>8R-zYX!HPd|orS-#',
    b'oR?ZGl92D$rL*I@il0**ph!R`PR~K77w`)Nj97Mg98jORd}`We#Nc6fX)rWsocmcQHy(a)3sH8+9KfCEqw1kK)7_)~`(uAN?lJ3v',
    b'f@{^^KB;~fz*f0^qxl6!f3NAIdNv@9FvX|8FptF9hAx9Y7O%Yx!5)+Op?6~AE)>(Z<Ca*H$KRAJrz@Y}otO08@(R7u4~aG;Z*XLF',
    b'gsgS`9B**k9Ss{obxpIxH*qjjtAgfZs|})cD5Um-3T0`FF~~;w=g`ZfZn|2wlzjX5r#kR$rka7n*L;377HTjB7>#3S2VbDOXcP3*',
    b'h&6_nx|Yh%?JA02OzSna;&9wxT~Q;%H1=k<rtOFCGKNh(2Cw1$e$mCn{v+9Ov_s1FY44Hdx~BH!q=fg#;ohkC#Iju=Yjcj2Pjz?P',
    b'gu50q_pa&}%g;uOr#LtCL2ogKXXY*e#^4LV%~rVRsxOAxJTTp232%L3+j*OAM!p$`0(t8FbDO&_e|ObijV(a>Yx1OtF1*{DJF4iT',
    b'E$P^E%muxrxK7e3E(>o=0*31a<I#2l?8BbX&cq{5`1vzD>Tr3-)GJjwwo!T9bXcpF!LU;Vo%q;e_+jobAV&ZU;gh}H)87|{JvcZR',
    b'S3+sI?pyE&Lm&L}$mNZ4$Ezi>wvapumoI_L+Z=1_pI|*?VTC;*PZT<o{DY_EDyKfgZhn!|=An|Wamov?^CfN^0`OEHP}L-F<NN9G',
    b'Nq>DCn@nr`?X;@1Z*TgfT%X(B4UuePCMW5JCokO2?{~@ow%gr+{CB_s@AoGTuq-F5yP;BGTr(8Vw3W@U54P7nbsqS0@@E@_$}Y4+',
    b'MD%ckLCGcu6shJa(6}O|1AM%u`%ZC$Z=!?4rOt{zzEF&B){Cw>j3)J<hEp)318ObOkmb--cgD!URHChPXA461qYVSlpK#hwxDq)>',
    b'!<Myb1kk8qyO6=0tnpvs1!+=!$F$-1u1<gE;#a31B3chF5;hp$pcqC56;M9;X6kXMKiuZ3oGJ6Atj%G*cFqc&Sff<c>F~_EYPNW4',
    b'FwFC<cB9-G6N7%P`rWaTW>(VfkcHg2f`^SUPsbCh;#${s;e`k-_ysgToc6qRoE>O=hM33CUGY=Imq@XNWv42$w^$Rc3Zf`hHqsFt',
    b'SZj`=^(RylKQk@Q-TtXwBe?_J@DZPoa&6(RD)YF~?b>2M(18t2PBtU6hhb8rVUZkYHp5UF)a<_CYh4Z$hlSSL;$KwF4nDP-{U<m9',
    b'b&5BxrfO6AZ;XpU2{+kc5$(iL4>tsq%-6#0nbB3p7$j81s)QqzD^brFr8*|!`=Zv>)BDNDZAF#CSsQmqApg1Q;?J?-1d2P2x~BKw',
    b'P=gFIPa#LEr&`t+?!u@A8m$Mc)auX<!oS`)Fqy{BV7{+_K1s-*P;tkk;9{%Az|tvcjlcSc*M%mK)#Q;o#i}|m<tEnSztsNEM(y8z',
    b'i<n%;_3q*Z5R&WoY<F=tUt|a850heTQGO?`+}6!wMg+tkZp;4HIn`uc+@z{*gPo<XOe$x~IHsb^w2qIWVApYIBhL&ccaPs03&r18',
    b'DiLrceMC(5ttEiu_V-Xfj?a2$^KvxlD);H{_&KRTC}%E|YKI0-NQ5NX<6H~mz8-$>>qK{Rh*W&kwoz3CU<dy)=Dkm5B}boaW*TA8',
    b'OMs)|ZvZs;-D(wo`=&jdcQug0Gx2YKg=+p4s`*!_=3k+jy9m{s;mTwUyWcjjew(mStk%Fbfuk6_!9qI}anPyk#}^m9^cNI$B$|^C',
    b'(eseRGP6uTjztxw8V+;nc+0x4nz9C&X{#x1GRIE)npeGkoL6X_*O`bHr&zoRBIC@)`W;AM0Lp^K<O{(<AAw=M2qBlBKzBPbT!3sh',
    b'3jHN<o~hE=JZZhp1l!$X@XcqROlfo5#S3|3Eyq>;H1^Wa=~iXDNlDw-VmS4(PwO%fE&j0klS>*MW8eWs01YQ8?R0!(yHG9cO=h@J',
    b'1)uZ9P@lrc<}K)e%eYSXXZ<#Jx+HGaOD9LM`*HMVx))ntlNX-(RoeyJv}9gjQfr3FLb@kh{GvW;jnZrU1dUJ9u+am&5);WTU0fX`',
    b'bM-i-?BzaIxzn2cZMC{UY{VQ4Hc?H!?En66xgoEv>`8&8Qd3R9x}_H?!YzGta>a_ECU2UhUnf+%;-rGa)YYe#bh>*m=&MyjcIA$6',
    b'Z>rdi&SBfZVL2@BQ>vNOGWW~1)^hHYyhSNXjC0+lX%|^S{UEKPBp|V$B{VNd<R@hsk)~>zJfU?!i!?}mR_39M3Yz3mT&GoB6{%km',
    b'l2np2hRC(^GB_aQpQUDVITG>IiMz>{=#+=j_?|ZZYPoa&3G_NQ&n9KwAV!OogCoS`16@URm?bg4G+~_7IjO16FS@2Bt431DHbv2n',
    b'sIev^CPdjvh?^99i=oD-8CcB5nE6?;0E5U09Yl^P2L@X1x;3N?tgDu$>|H%^8RV9P%8)(0!$i#s)fdR-lV?=eL!p{4dzhQfxN)#S',
    b'|8bw-8MTdlIqk%;H>yZE_SGp=&WLLiE64s$xyOgb+nZS}rq&_N^pv!m@sVl_vnMJ4WGD}5sV9_MoP*DRn))L~q;IWHYsQcs56yeQ',
    b'o6k@$lp6Td1e`Pu4ML9%;_O}#)1C14)c!UIe-x8yGOXJtWKv`P0OnP+I*D~`i7r0{t(AMG0ms8?!<1BfX2MCF@UKT*+DCOkdNpvm',
    b'{d|e>%KpKZLXs*$Ul||Q=D{4g%dlr<!W0x9y?d0Zwe$*@dUHCM({Z?79he#ocP@)c(D&I)73w>0q6zg~H&ld1tT)qx`tD9@P~Uc&',
    b'=UA;URLiwY;?7m)xljC*dM$E!7EI{w7@-YRg`H!tjgD|nWZBIjbl*sAbo$);dj1ir)qQT$PoY!wr|Z2=hEsQ1yA&7FB3!j}b3$za',
    b'J5_3QW*k1>(tO(uZbFs}#-Gq8v$1=@r#3%ucsMcG*uFn_BT+8Nz81SNIBbk$fBHt!=^On)G{gPJqOGh7R-K)<kG2}SZtq(huIx0M',
    b'gNk^G*bt@1_i^je2`C{)#s3HyWpKRt)M83R#c9{^U2yv-;+?b`d9@|B_hTB}5-E-E>tC|#&mg<RsNa7D;idOOJJ<-qXb{?{_vFX+',
    b'sRSdEEk~=27`x$m9OnPGoow70!n@V!c7~SpR21#}sb~(SI>{v>wYAW^FEmw~$F79zCnNg(y=-ic5^hp5c-ZacFy|g5<}9bSNQj}T',
    b'c8?SKZG%S+wZ^s)*-w15tA!FoAC~ESo?p|?L#JtY^ZBBbJ)>LG7m_dxS7%MdM{Kp^_2p=0@^-085&>K}Ptue;bD)5B#x|ufX_~cc',
    b'P>BU%m9D{8rCVYL*-zeT5w!BPd(n_D3_&ryR5KJ6i8gYv=htWRnj({Z^d3W{=7ux5E+v{_(6*Yk6yaZ(gJ|02v}F+wwqMb0l86g7',
    b'rB4)-wON#u^QPqknQbfVka+S7OWaMn%GTtRJJ`5#goJTj4OzDSh-j|O!l?}LOh3nO2StI6M%SPx{5&%Z!x&sKH-N$x6*0nlJI$q8',
    b'-FQP`H*b05Exo^c@san{S4){&7$bJ`{CWA-9CWpF<`Nl9!TUdf@=Nb4FF1lf_W1uNhLkdg{xARe7HfSk(@>}KyCuHNlF>{jUlgtM',
    b'^H3|lFvfPH>aeAXb$}1Em5zghG#<4m>ei!IM<SEB*AU4j{<l%7bzH6ERW+5fGn=+KA(;fe;cW#-mQ0KcQ)huk^(i#x5~ZJx2IB>W',
    b'fUDLpRBY;Vd=nse-DY@H4bfeQNbap~$vf&!+7TvFWgYvZudyz)9{iV-FB{m_to=KGN@!Wz%CvJ(#kRXD^DRQ%AiLjYK(P~@1JLq>',
    b'_st_O^#1lY4>t{oRMy{j(9Srbn_ikWfNUbbfsrJUD@knEgBj>=chlGmz8i(^#UeMp@}LiFQc%1m)OEGG@O~i|ca+!4+Wv#W4GTqB',
    b't@$z7mC5BH*85P2$X|H-{J4De>2|R7T~z_D3vrMRAzHIy)BR%|aMJCvs$j7HdPmk@d*hqi_s3_y?=!6At6LBHV2IRh6PAl@hH(xr',
    b'=+(R1_P`Ru%bgX`=i~wu<4cNIgtfF84d4q;LPX5biCy&u1^kBm+OI}U+tA|y(qdH7WhZ&o<(myn58F<Y{A!<C%YQJbc50xgY1q9r',
    b'ziU{1dRZ`rbgQiH$dt${vxPyY{qocD_WfCp-~RN7h%;|jjePe^s^vW6ir{QE#K-I8(xB69xK=|qTr9CN_3aiAU#>==B3Xy`V(4<<',
    b'eFK{y^*1jbf>ARH%>?X8G1PJA@tNrN``*Kc-r1`s|9J3hS<$OCebBk#HcNW*wfFqw_1^Ujd3Q;?_3C0-!==Of5C1Sf42q+@z2zm_',
    b'eBPIb4~56O?^uPC*4z2zuUGVD{eF4PoM%=SUqYXUFx<agt$=%}*BW9j7`=apyxSXcwQk|T1lSP`SARIHz3cZM*Gu4ZkM=Zqz#`Fw',
    b'N<@bp)SCX{o!ok>UtuM$R<JCW1SV2}EUsXcDv;V2t9Nj&R()b3reiWtFc5q=^j=<FeDvsV(Ar~e+BdK{FUd!b?J{q9d$?DzAK6!D',
    b'&!e*sFuhyg%jJ5{mZeYfS?YL%-rN9o*7p5%Wx7<bzxGS)2x4L|X{(IE>z=S_oxrwC@O-(3#j4)#E1L;;?4o|Mx+Kf1>H4!O*YxHW',
    b'w%O%`LVKJPHw@3Y?e1(!U8)0?&cJOp%Exh5+H^^l*_~Wn-`(za_raUhufx@_9aP`z75R9vBK7Ol>KPMOD$>_|gOAso6?UM`fb_GL',
    b'O6vDZ^4s$A?$U8xSPIB?=Zz=g2l~;3`aAj<cFQf_gGX1ML;nJ?Crq!G^00N`$h^A6{2;j#*8j~9;yCu3B8f9U52`9FnmF={G)>|>',
    b'PW&cMDJiQYD&ne$qoOQHRo7`0H$@SXlK4k6hJW(()zcSna6kTMpCm}YBrCGCuIezYGrvmwFd}&pG(i=lv?#+W3*(ApX&(4#ktKeX',
    b')ih=Z)>#l%Rp2KUOkSNneRJ~kr#7W?n{QJXoJ47nS51)nMVKX}@5ez=W?>%HQIV6vk12_h!mq<5C}HS0NYg5cV!tj!5*JnEOolFd',
    b'wUFpqKqPNS7N$VkrXZzHXie+5ta2E>EDM?iNdkY)>a;4GkQAX$BEPE3nAAm;1W8)jsBrxKQymE^KcWq30AiYEabB?WID{ryT}1^c',
    b';-(I(B8=0N(6S6@7{lO21bu=kgf*%xBlBT<!nm}`{UE6um{=K>6@jHqBAO+21dI>{L0m>f6{kU&*KrZiG6(vX@R1ZjmLw#wjH@O}',
    b'5JnG3-qbMZ8YUgpVGuRI22D)jx+Xzf`%#gRH1**tY>+sr{F*?M23Dq|G)*$g=yDPrY3w8_qbem)RmM4Nxje6%EC$Z1s<2D~LaV4r',
    b'!nCTByiPLWQ$GfFkAXWfTE(`#C&z0DV@GUIN@JLClSWwq%;YDz9~LB}z|ejjB_XLAVEU+G>rur;n&*BR=UJXmnmdn;Gg}meK?70;',
    b'7$;1DxOEXFz;TUFW0IG3+=PBpkuonz*pNAGXae}ubw;WJmdUTIi{AQdzIt~20^4LM<L#m<;XiERRa&Pc2r9pcvWx~K3uuxAq3=gg',
    b'O7aTikDnz$On?jW0=9>3(c59wIoDwv#8F(3%m*SjArLo7e4um%q^^Uq$@8Knu*4|=b|^v`<Yk^_kzf092>*84V0g%yDDn&6r%?>t',
    b'2ICZEP=Ii$nxv#n9z}H#*F{jKWtlKhA7^z=EBGf4NF7pO#lp&Vr>{?7*f${Up7hf0^!UZu<I|H@@M|dTfC>aGtS$)HCN7$cMnH)S',
    b'Bri;w7BvX?Gy}Pmz?KN=hC=Hgi(^VbCS^sHyP*PG5M;nPoB$`VDo=$xjbGwzzC3UPJ>El~ynOuQbNDkiJ#`SJwRM=s$IqSt6_3xK',
    b'KK|jQ%F5gjX%ZG^uVMM0pZB8;DZ=2~d(zcJ5P-djtfT(`%mnB5F2?3TIgH$Hp<RqS0dg3%i;8@8`ttt)q0KmV7Z~6`U1-40>gUI2',
    b'|GpbSh|s$6_jv8rAjD6fzW(v_Maw(SPhOln|M59&qPFnD(Iy~{|1p4Q>oZtjbb@VUUaogr3c}KR(EE`7UG)V^e@=r%VYFo!9C6@i',
    b'@a*Y}?_Yyl_S%XRGjPCQM4@km@Q;oIULF7Q*~{Z69rcndvGf}yR$F)FF(Uvoxv??ZtZqFE4HxmD|MK$k?v`2BM<Yh-c>6}9tZADM',
    b'&zVP#qi{}wt|K9?>8_)V#wypb6i)(M$J+FUXX`vZthdDEUSVwW8(%(cBPb~ztdOVZS}W|SsVlX(F6isijQ(?a8IvB^dYiILTDe2X',
    b'JK1l?cKhDkRcP8oX^WjB78-mLaxG<8+$J)>L$;a$=D1l55S0yuv^DM_q`h|AAh>cIgFr%9*xU-`T5L+n!Xu4LoORyk!!$Tm$ZVqe',
    b'R`8P-zhaNo7^}GVnwY`8&w#n$GNa>dSCmm;7-PH51_h^bHR@4e<ZHY0h@Q_~+~%gG7p8!*yafQx^iIw%@+Po%vTq6`a>@TKhI=q6',
    b'>oBbAfSJddnnXcKf+DFBS{3XbP3t5H{J5-}l29M?$|4Bsw5;kpty4?jsUnhL$ij#FZ9<!a4f@7W6y{+XZPK?+>w=c{z9_LwvU^rt',
    b'5IH_T%B14vAM?quMSR_*oC-*k8NL+4NeatR<pHH(T)Hl$+&?UvI*YQxwLeFTHn(~n=24t%*1L$(sHw8t5;u);p*e!uI_sI;MYN5b',
    b'Z9FAt1e>P{!uf^wLgI&Uia0lJ0aY0kyieRSS-B<h!-FneGy9=98YbyJ(Opbd$qI;$q=`EXXRaTvfVxhH<39IXP&ndql0$8>e)fs(',
    b'VzNs9fjMgz{ZVVDCCA3es_+R~l{SkDX7{A;FT5xiY>!CfvU>C@am(hoMntT0enT_jq}QBcEDy?mGY>f46}y4?e7}3{5^4jfgoz-e',
    b'd=(i|4@ilF?;ANKQ-KM|s<WuvGje;I=fuR2cV_JND)#LzxLb|c=NVOu6%xK!qj!YXU9^IFoj!N#`FO(%xd4d^A<*2#XTf;9#l2pD',
    b'$vLSrSo&)=s$M#$Scpv72u7xn#P+#Ur^g#y=*!K+BW9f}$dEk2?Usu{3M<yE?t^H}5Je*z*fR(w+rT@sN^Na>L5phfB1oUZ1?^fY',
    b'y=EQ%(%d~&s2u6qa%Yx~f@)uGQ+v4BF!n*l#KeROW0cn(V(BxrM@CdFgj0W`T@YZH?S@<kwN7w(CZWdZJ!AabxRH>L+~lO)#%oX`',
    b'V|$`FL)-8mku8DtL8Xr8Aec~SA`C=Msf5544DZn(V5S}>6DG7bS~xi_QLLxlBg~|VhaEVi<J@<s4XUj;iFmEfMr6pe>3~QVF@WF^',
    b'IE^Y~vYZA(BQ20Yw2#;B!%i8kbi?auZG8xzL32$aQ7+C@L{HBXQufIiw>CAjbl%-<69ryY(&sDj+^9<JOR;vMrVu9k$Lwvb+8D%Q',
    b'mwT##LR+#``8*YlG-K7*l2jULYD>;GzZ;8)YmRiMMvt}gQ$37lO>eCEIGXwmZANpx+Qz}kYn-#~uIyfI$&vxmp#+<1f6}kfxP=^=',
    b'=oe9`b~<MXjVhI4HOJ=_L!0ptWrK}jc}3fDtKlzQDp0Mms5Vt)w|-H3P2bu;zve<2U)_3##>E*PX$@`0$5=y~@zHg&t#2%3tIBP>',
    b'$S|swV^V)qbB!OJAfWn!v4^o;Utks^<L%8IH2~IfoBXb!<&$Wu4Qkz)NI-?Dk?OGP+Pd>>)w2eEQBm6~@m5F^AsES|I3Q6|rkxTd',
    b'MH&`HvFcNrlRTo@-6Z?^>St(gY4Rb~!&N+e&43-6yO*@auZV^nx2MU)fnOo6nI)6{YL26YdxMlEgT?u_DKa`Ma{sr5uGP4^Pg{+e',
    b'{nq=v*=`|b#9npSPgjn9ItS*or9;Z7BRuy<MXpv?EbyDPQ<H!=ziC)%K^!{LUR>*ak>VI>53nbYkqpD+Uf$hy;oC|Ir)lzwPd(Qu',
    b'iN>DG2FE74-w(A|u(T@Y%d0hua&{pbzC*Zhe+hdQC%nFoy|K{Ud)bJmbiKN`>&V42M2>)N#t&<KtoQ3>^`T3#CU3yGd+)gVFzq{1',
    b'efS*r+@W>xW^b;AKxc%mpX2Vcl0mcYOvfcZ&1v%q-8U273lj{cr`-a**+KXw9DBmw?9_S_9uCm1exVnuYdS%o{V&|h$tJ>Mc=_$8',
    b'a(FwkMf<p<GRusNEY{=}8)|DRR*1f$%txQ#NZjCD65Bpo!kV|Bcfb7Xzh&fZ6R}h`%j?^3S=aqxQ4WwE0qeom9gddeCAs-{N-GdH',
    b'z*O+JcNFOnjy=}U6jsflPc-&f_Li3M4^LLrT^Ac7JDBiOUbS}#ZpvNq407FGx9Uyu<RUxx3|5fymVv)9wEH!??i;X_v`02b{ON)n',
    b'Ei7TxB>xnMT~a3)j2-xEppGs{?gZp;;J;TLt@xyz-GeaKwxio7xpb!-ART%_<_>fI+&+-!c6oJ2O(}yFmk)uJmT$StRy+>R)Ldxj',
    b'8!-pzK!&02$lVY_S}HyH=d9@;uzbTlY_l?Z=M~HD((=0iu1oI1(^-WLYT<hdLa^3M;;XOJy^Z7byGJk9R6|Sr-M>W^Hs$KqQ+l_i',
    b'(&mtfZjR3pT&bCic+O4}y4HJsc59>?Zei>vubO*n!}id*fbNWuM7Gh-{m7VayFD7J4*<bIqZY|;GR#Q2t9nG^-^V<pui7<Ve-N7u',
    b'+$(kN2_a!%vo0t}68Etroz~as)#?IyF6Ce_R^R4vYERk_DCjQnqtH*23UE*xjrT!^dmvs8a3ajVj<SuEI25Qg9G##Ojc$JOw{JA|',
    b'!p(GSJ}=$ghOcw2g-=%n6jqTeucXe}n^-Fqky+dGj1C#-+K7lAHs|%SUen9+;-k0!Ww$sF)}*0d$}|&tdtW~q*_H`UX{lCCv!=HP',
    b'2rA0KCV~YeVN1eViOOB?{zo$fDmwTVg`bwUSD-jd^5WO-2kEfrJ?dFfSlXuC+)glbSy$_)*kzo{%DSf|z|Zm5ZzYqC`r2Zct=6|<',
    b';k4Y?+|2g)_5$9wZT-Fk0@#dYXT#jLu$XPJtt3hhEW)$HIJpB;P=T<9y$jrQ@e#h7T<lf4@K-L|Mo}(YD!2m$kXXWJhEOr(^&I_K',
    b'kepK%34rU?#yPoKa#R<q_SZ+4=5iz-KVzFw+COsUP$6E7sU%uba)DC@HW4Q<sTQV3TciKC0OuRybFMp_|I34o!D8MW)9EA0XBDC^',
    b'@UcvW>SJ+n_eB5;bzw~rUTmFyprmGDjALo5_V3*LP4~m1)iX_kU&2I`MaH2QW<^&osuTe{Qb!QL;uKs2)(D3aSm;tYN~{syffOtt',
    b'z&!XQtc8<svh_Mzez~e|{caa&+0$ISwklT@RE^Q8F9R0huM@6|J);~(Ur4mpTftD?TWm#N^UjFdnaYR1?^}{QE_igi+7JgA)IfwP',
    b's)uM|MwQaIC0=aTVu0<h36*dcsAx?5vyqAH$SAoa5p=Y#2Qq8jq4;!<2BYPMS#370u*bg!Oh$SEwD;eSx)JvS@9%&2mgo(F!4i9Y',
    b'(Z7@^2BuxBMQA!kjfYVbj@1VQY!43X9W=9XR+#vdQi@V5N#Y~4>u@Hiy{EILJ!6pm)4o@FPoJ=U)05?+?Ofm8e8sl%e4ph*?%<!S',
    b'b!9a=TRLdq0wds``NdXSbjKSjC))21yqUP_rkeoILW4}ec7?EQ5X$vu<YA8>s}O(?2tQyk0DTRPR^zOwb|Q}cZk*-YYJVSXr2Bg_',
    b'{3ip87O>cJ<O4GgIIO>E?XAmX(}89zkAY)GPLnX#yjcXUr42EqaK`OpvA2Z<d?V|b$#S--IelT%v=?^6OYaq?DfqbU*|P1KCUXB~',
    b'=aZU|euG2Fa2QyR5|`6rri-`z_-J(*;E|gan4t|SzdM!MAjI1Sj*^?dDxCF|k~%Hj(0<hCoqO0$LR`DkwELA=Mqk~m{*zXnBgEb9',
    b'`_)Z<ZoF8*ayxb$3fsJ1UQ!_F<+WqKYISiz%GFI9wzaxgRv(`OcW-qp$_0X^(VkZCSDS4vQ{Hy1PUAw%zNrKG#)A?gm^)R*7yeI9',
    b'mCu>s?DS*zLJdc89+2XfU0)FA(HqBB?<Xm?v%j@D=^+E~?sv&JZiKMES%gyb`Ka=8w;5-H+;!G5aSsQv?a;9w)V2%Wzvi(O>9&!4',
    b'NOfFq(j7ZaI53EGI}EYqfkwP>a5&L6{km(hrWS$G3$qCey&#*~I9Rkg6XZ}5vo-iVYOB^sj_+DKF!!?IABcedyM+`YkThmoE36oS',
    b'rM1CYq2&@ZzQyNm_2iNLL`Ki?Km|~nD@`3IF_MsX%W9$j4#K&us`}S`23fcb6yB{?ZK}97D~|tvn(AR)Om5fC)VYV{<F)Pnx1Eb5',
    b'sWzBFx9%}8Xw`iS$D@e7bxlNk-j#!8Pj$dKujSvd=VV5+3BcsMp#YVMc7Ca)2UiE|hme1V?ZUvnJm6nr`ym(Vi1sVRK!L#vlbb)N',
    b'ckfu5kH_LC9SKG*?j7L|`TkD??^<cFjp_38^yK@K7st;gN8OP;`b}m*4|}!{u(i|FO?&yq3(x&H-+1z`PEVd6pZ;@vx;D(+ij3N&',
    b'#cjq^E$Y>_lRbO-_~nZybEa!XX!{9Ub--`D{5&Yaji;<Q1K4J4!$|GcBIq{f_H37CUN6`1!^aook{)miounJj`N_!{oCN<oe{uZW',
    b'w7`zYAd8%&n@@N6L&s1*o}L`+io3_92B0&itwm~k4ll=q%G1r8^G%F4XYI!?pFKPN_T_1tUhVPAA6e1V&c)3*=mN%c!+&p<^b>s}',
    b'hkyR|H$Gxg3*%tCw`n!Ld-LkG90)8`6vjtR)0%rb*>qtX?&S_kqk*DLdThHneWE2pjy1<c(@l8(C2`Y*b25TBES(mPdGRz7@Dnbc',
    b'dO$m_oqooyC;Ob$>m3F(UJs)`;#6Xg3t$#r|NAfS>uPo3O|ipjY+)OHsZ0KXXBoia_6AM8=ch-lQLPWzWPOfIt-n#~<GOIetA6&Y',
    b')iZMQj%tJOh4}9Ac#=o7FHWCeK}#ZO-*JQQX&9_)B5@MC<wc=Hq65`qRB|I4m)Pn&!-c^+Gm^?Ta$@BnSXgEb(Sx21-TBS8zk}*<',
    b'RgqiSrTe!p)8I>Ser@xx&lD~5&sSa`8#x(}+)sU<M0Hd|brXH5Ht_u~7ucfdtStljoGuxkCwaOFw+bYe051l(7#ljqZuZO3Ms2nW',
    b'&NBbQT8)!vtJC?Q%U!n7oWsutP9dDvPRRz8Bm;f71-1#K9cqhGVEp^I$5|w%3j4qyPzTf`HePtr-e@g$Q=x7?OMxw5yNzVWWM(&1',
    b'o4T1hhy~a!Zx4dB^<3A#k{v0Qq6<oxhCVy+_k!Mf<z3Ts{L?Xr|643AG5zh9p<b=7KTa##bpz&F0OAtR78wSSVb1umgWPpFm;pRk',
    b'=vII?KeCY~W*GWvI{q#v8W_-JM;TLvMyQV-@jRhnEjhGhQ|~_8fz69onaBEx=nVH7!@SifuQ$4%q4CP9$-Gl*+qhG=E)I764Q=`x',
    b'+w&D0Wp#IR0~+6Vq`F<>fhS6r8_LWeb9zjK=p7Oq`>mJnuISCHo7JlM_U@{_a3ANCuJ0~fhmq~Hc1K>!ZojoltmMur?wDRS@*=N$',
    b'<px|>i5HdqMJ1qZ_J~Pk`OxpmIk+>FrD)Or?FHd^9;sE)zV^cCJPLE&{jbL`8PAO%JNJ_moklb@O3steM;nE0%AxMhDfj1W>KvWN',
    b'{DXP_b9x@7xn}8gPZocze!u#~c_i5YyTuQR^E{5-7e6{rve2^l*?C-q8?JqF9_7BW^uW4#Y;oV$MH>ru1}<$*><w|=__2uSSOWdT',
    b'oHBC*zs0OGbHly)-fECH*YJFOd$X)=e`3`ny156L_rIXWVw!zhB`|M)<<#W!%OOyAB<MajEY}~2uLX7I>POfK!<hY$Z4#uuKF{GL',
    b'`E3@EPzI9EhY_iW`17FzyFev~Wguz10hDAHsHAgHVH@F`S*M;}jXafOJjHQ~`d~1hxqjDNyLwEJZ9ZIFO0uSon_iLa9!pk;hyn%^',
    b'HZH#rrG5FJ9T!AH634rnziA!Y@xI!Ar}c2scssW0!4&DX`>h8Q=J`$#ijr-2-2f<eq|kWL@2(Lq+w4}%(?XHXJ>)n@jetf?zyVa8',
    b'8$k`0Wd}&PZ-msp;MoBsL8z51B8fnXw7X}M{Q?`8AyI$4BA3f*5>`DD!a!PdWI{8KD1h7T?R&vX8c~axv~IgYYyhlaCXT2@Ok{)I',
    b';nl-c&=ST|0H}!-x#@krXGR>PpYF`qiBuI%i*3Zba9(VVPY~|rv<QkFofcsj?+B1^4w?WB{8;zTjCRo+g=QJwJKHz_N<t%`yPKs0',
    b'5O%<7#Edj2kTdO`xd(|Xj-*FOAkF<B6vB8~tR_0&KStwNb}7sW^S>1LdlJH1h!~LHyHeW2-P|HzMRx;75S~%EBjtY!K&`I76F^MU',
    b'4>szV`|~a`yp!H``aS|_8>N3hklfsmk7u{!h9TCYp$;XY!u7Gp2d?GcQFq8~gv3PSyDOZm)9?nevd+v`lVLynZGT*2X0>Lk43lB_',
    b'KV&<8x6|m(3XW1txoB5`;qt%OfN~f?Ez*564!}~GwPT{`%*KYd^b$pPDWhuIP7I2x+_b^zHQ`{6EsQ&u4X5h5<DA_dt815iv%cpo',
    b'Gx&=kduDCiE>q|Zwn2jX!S<TeHS+)%hySV_>TllvHw03`Uyn?g&pVRin;Lr!=tso6bl@Ir{|eCU{58Lex`98zewPRCI(AY32GpiB',
    b'>=}l+R}6blvS#~O$(c<M7MbC9^P|=%7;qOjvC`i_g)V!(`uk<~D7sMc`tzCXrMFITm#h0~B`f@}rkA?tuALeEIW!D{Zoq9rN%sr6',
    b'xTBb?>)_giUEgZ=($3NCszrbDxMJRV?Ef8!dT+hH&ccBkz1!V!KlIM+)PA(Rte8tV(X-4*!2{PFZK&R;uV$&;vf54VmV`}p_M73;',
    b'$2o=Soce|cO40ESC^~#tFaHnSKXCE58++@z8XQb7*Y6I+2lt*zY}d*kzj!3l-jFqW#8gO-E%bKHkBt`y8JAhc(wfUqDVnNd1(aB8',
    b'R==sOrh;Tg#V9d#Y8_DD4+%}w-a{$*4d~KOWg1IIg*GcsUj=^j#l2;o(ziDET76}U9^Mqa(A%)gKI*;invmQ5r{(SY!BugiA{!$r',
    b'YMBjU?}Svc;oN{(h{yV_s>a9>Rl!z&e@E8OmX}L*T^)mC&R!qCK6%Unw9mgkKAT@IsKbE?0hY93Syf6&686t9@}ghg-YvZ+yX=<U',
    b'|9sHOAYYRep_6Z|Ecp6S&l!`z(a4)G27F;NOoF6!4#U{{<m&qFmK`mEiZ8HEH*kAFxB?FCVn7+d*`%DN(8^&(paJ+uAV7t|#)?06',
    b'd?Qv-nEJcy7&-gVBr69va*ct>%Xrvj2QG0DI9W9(@))!_oQC!4k}R({eWn-h(=S7&2`7)SZGz4QR0f~E0hNR4Clwc+I7BohaYL&r',
    b'o9+@Yv&6%6ewmN0p~#;ktVg`~T7M4l5x6p`5zLyrG=h-s3-=u=#R#XWS^|#S%F`S2>t8~alNjU*c&Wp6;nDxSKZS*(m0%sUQ$#lM',
    b'I%*Um&B?D5L?K8`ceOVk5S@LNLH$M_n$z7!9<|MwyRc>x{mQPxnhm7Ci%Gku7lm^+kZ#i;7qGvyi~D7K<fK=S)o?aqE|9uz$LFqk',
    b'kiynONZ^*7J#<Goo0GfVqv3D+-HsZ@8wZk<nQrqcM*lf_->|`lsrGOf=mR}jhT<Q)xaS;8(59@ipZJ!eB4WMcs9pZL;e4_iPMhdx',
    b'mp2>+@V;(147TAxrlT*jDkB;h{iQAWjel)e>=6*J7C$>;KaDHOUug;l^7Us#NZ*af-2_ba{VLzhvc{o~$Uw|eB;fsx;;n*p5pn*8',
    b'FX=Id_2%7URjKls++u&<d-%{hd-dcW51uV6dbOqxPFk1NW=U_p_MV@--n+gb?=FeAUR^Bf<?ToBKm5b|Fer}p_Li6I`r>_g_)w6+',
    b'->vShx&X~KHRk&L@|u~6Ru^AFpNBBqzg?|BK2h&%bwRxqYvZk&A$i4U<zu#4R?hj|qAk(_H=>&Uwty*;dd)N$ud4wI?OC#z4scC>',
    b'@m{~bp|s_M+T+Xz4^~&ObuK9Rg|3ghtCiruF)Zi9YIW5t-`#aZDL|%n*RnnM`SylXx1Qmw>B?(_XCL6SxP{Kk^`7l`YP+2DF2rxb',
    b'g<FSblr%#b4{PI7AlI8<uVa&zRQPrKv?V5AMY`L1-nx2EFNu=UwtHr2*97P+1Y!@W!|)Nyk~-WBhBlTc>M`MgJ#u<1Bx6ZcG?YN3',
    b'H#e~UdII)l;$c!%``0N2L-+T=4Bc-q8_db1AwR$<)*?rUKVFev$P)PZV#=IS(`#nezN$X{;Evky?JaHfht<`-{I0W5QuEq@K89V^',
    b'O6U>V2l`Rp?S%2e^Z?KPHZ0Wo_T~<DV4tj{RS^G6;ko`2ttO)2(r{=$DmfE4wriDM;3%LCY@xH)FHc$S>(hUKddk^+{NHGm`$1AS',
    b'NlweKtcagwNkp@xj_S-0gCH)WqKea?%<H&_XqjhOUBX9F1X+@h{xYr|_sPlW)5kFOKe4d`l0;=xr6j7#I8W0g&+8_O(<-W}uuK9%',
    b'tEfrBw5pT5PBP+CKd!SNE@G0=D)ud7KYsc0^vTJKHrXCJdfwEeA+?{TQ5^<RlUGd>len%)5Z8WGWF$>}_!?(^994czph@EsT2h)O',
    b'nPv1TrWF}GVpFCxhC!P&%8HN_ev<oPK|&fAFjSO;q-x@%h#IyYRa~Tb?x%5{<q4&^W$dYd;8S$!eh|m8-xLYVEDx$GE1Ed+3s`|T',
    b'j}yPiQ%cGziHf)?;;1M~Qq^@D#Z3XEFNvM-&tJjS;M<dD?3#d#Ul&;%=S`T`z;J%z`*|D$B#x^PNL*)eR>VOW)<v1Z@`rgz>L#XH',
    b'S%y(VQdk@t=}#a3aPkIa_cAAC5LIE^0Gnk^nuRd0qAqD#m0?j<G$&O+>KvG#ZG*51i#W@g*srQ2p#eQ|*=DCtkDr_$e|rK5yg2#p',
    b'=~<T`O<aM(_h}RZ$CENH%AlYmu9~EzO&&#c5!Xdfre&Eh%EwuqgHlyhF<=$~rgdRkfi@XeTf^n_{Pol4ubu%zoOflrSi&{|l^EcY',
    b'vJS(#4kF-o*c4GvlAuVcgjNN^kJd>N_;Fb`C82&1=S2W?E2}zB>-5M;^t?KK`t8XJ*pA=#nXW~0<N@q@*zvKSB@`As@{=-+NCP_(',
    b'7`_f@k%Ct3H(3tyh$eXy*J%aZnffImN#(RGPoBPd`T{PmkN?@DaQ-HUL{c<)7{p1#D3K>sT7_xTlnv~FpsK61@x#!MA{xRbfr%G&',
    b'5k&!s(mD(MxbbTncK{8(dv@~u53Ks`|NA53i#E->fI{duA;>wPcp1iZ?w48VR}t*}vd&4K)pc3cCCSn<@sl9VqB^NaSm$M!!N$$f',
    b'#u<gNu#G5~ngUinE3>)*;UAK)seSl!mC_{fDQ!xSh*4Hoz_3Z>hafM?00ai1>{I~BX_E}cuaBR-{9ZFS&^M{_w17R3<#CvjB7`lP',
    b'MnM2ek>)fHY9HiA9fxt6g1BgkFt1=ON*X34N)jh7(9AoIqmWiv4I(yg0^o64k$_}`Nu;u-ATnq{!=es}Uu1sNz~-b;L1Id(C@rY-',
    b'VW1g43WEmZagfq5g*^zImE?ur_%tRt5Egi%sYsa@r4Mta4Nc&HsOyZt4v1>MnsXj-#W)2VfRPJ00fQWd$dc0c<De+BFlRa6ayXx0',
    b's&F3pb(jPtC;@Sh!j_F<zb-=pXI3-|2PU5s1S&tG4V=hK3S}T<*xn{I0d@mQ7jaXERnaazEz5w0ap;pGf<8eN0^zDzrxLynFbo_>',
    b'aP;Rz1d34=Bv}gQK%6IKnE}<)j79_`Q52U=9%pb?gA@dT4JStC!};XE2CrW~eR4k4co5IUFb?7<E=cBsBG81O0Km2bZJ+{mpblWn',
    b'yr>B%K`BV(ya;KKmwB2+KJ1GS{%sS*FJC=9?Mez8WHB6(HJkxV(M#&EDM1yBQ;@%5MYACEVcQ3AhJs*9@&Nt^4azX3J}7J%X@Ved',
    b'mq0*@)`s}<1%^ii=Tchxlz?dQ!-hsM1RR1n4S-7kpVE($nEg3|E!or+&?*F_3Un4wUCP2i623a_sbRsSE>e;LFP5MdHhz#cc|a4A',
    b'1WZZ=AcdkJfyE*TsIGBI(k9Fz&|dSfjPkgu8|o?)%~%9E1vNa&{U)f>rUGG{MWDOG2FU|bB%sceg%4+u9~4E(H0K(&Dk*(J8b+#S',
    b'&i)iCP77G%4ave3)Ic~W05+{@9ha~uBreMW7$kv<1gsdSQ$Uddc4*{Rbs3YosFEN_OWUeEJv}=)dku&5ps!#^#5AwdkVZ9Z0$BJu',
    b'ge^*w5STD+0!pF`6gj3V)PWzRc>(MT>Yh)-GSABj&~+w-6MKM)5|l|;HXsy0O9Fk70Q>ntPG|$8HFciA`3&p~I&1-IEi{b+I4onh',
    b'L4j(S&5~PsqJaDkD2U7|1x>jO${0>%A4ufGMIr-*vH<~=!66=o1st(O2rNXRx&lT4U56xOw)jMFC;~rd?`$PgQ>qLoo+Uv;L5~I*',
    b'1yX}Vq@uvUL7p&mp)P<)n;5!)f)AS2EF6A1dHv$)*%^ihhyZpn!JI*lflCxD2AuA2h(-nIcVWg3`gW7T6(}ZY0{jxe`3^TxTEjJ<',
    b'o`nZvji(qESpbBt6F&+H5LkX0!6vE7B1+3BgyS^?4I)cHoP&CmWpMa5K3pr|z-7uLpcV4sJl5$m<8#c($&<F8Sm75H=*;|nkBv8#',
    b'p<@hMNFJt<OUGwVkG~r`f|xF7Y3s;e$Gh^9Lx0#hbq2R!bN|VdpiJ4%b0AxsSTKKa{Oat7m#-&Er6nkkNsl*|r9?OIaB6;kd<FpE',
    b'Fgyok!P0v~w(Au2ef9(+&|P`4ti0vr<=ri_h<U4D=*`WtrepO)S+lTr7%Y58^F|uXU{97et%2|3%z>5uA|CD&!0Sc6(Wn;_pn4ei',
    b')eY^9<WEMsqO~)<zF2)^(e6X}$e^(GVYdD@{pQVUdU<^TA3N_h2Blx;hY!7{px)kIeDrRAr5D_r!Nc~Ypfxzd;ME1`4EgKBw%;YW',
    b'zGiRR!{Cp;>F}8R)6Q8kN^*O5L%URz{gbXk#~UGkzI#78o27eCKB?ynG{>}_8=%;8j(b-*k)pO^zoF1kr!1VWI_s`w{3!f6e9NzC',
    b'{{Zl8dG*2CmFw3(HcT%h?ZZR|fU`pX{FWPvnb7P0qkb&pry+cfAHM_Bn#5mS+^t_;(S8H8(vVrhd0&V@CXFKNTzwQ##M!y}Y%}h7',
    b'q<<}oAyXSnVj%5*!9^1W84)K)Gm`{4-;)bED38z+{lpaF?Cp5^CIlv^WJS{~j)YYKPu~Q<D!q+>QHooVc|w2P3fOz1D`M|vTp>1Z',
    b'i@_Do=03UoPCI~Iz^gcfJ4}6G>BaHAMmd@Tf!B@>@LZZWx=sI&r4v7vtyAa9$&G@iuSM&m91_0Kb8_>6-n<D9g<w|kfdE56^nu$6',
    b'DreohG>1xyOQ@#+PcqZH`KW7+FY|#8AG}{rr9h;T{B~!j(<ei?r)40~GWZN=iHWpMb3IgjHKhVSX1Vz3CnxV4xzh3As5$MAgM))V',
    b'0?pyH5z%!!<?b0b-95(64Z2hAk7M%DLFYNSS~hg;JQdTssAD9g&T9ltY~EpVSaOeB{&VE}z!DzDCQ5sSa2~f=9h!5asT$JM-MIff',
    b'n|x4bspCCQ&s-cbh^oYJz%;0-mq}Cd9+?#>+|`?){z%=izJI`Ko6sA$v2~$ZqZvUC={QhpdGJ0l?n4j9xWmwW0%CRK&}lf%7qBJS',
    b'$rNGrCgA*(ohT6Z9_#}Os5S1$i2|ws*ugU3vcY{>rhU*mtag}17@gWs06mJf%=gpbXuMKkVp=C3Mo2mVY7;Cw6{7Qlz*)|rN@=!l',
    b'O5gLvQ1NthZ)OA<ejMDSTdj`&&>AdSiuBjf+xN>gs&fcE9`h^3_taCK1HnzrUZo4^Brpo{ed|^1L6#Hi9~|lJ9N#gDvn6Yl28_2A',
    b'K3h0Pu(;?JTIE@*GNX|!gGcK`$d}i&Gob3`hY)|UNeY4)ljC~Lnx1ork{k*p#q_G7Qu;yobQ8*6zf?cULm^F&(cs9xhE*z;7eK)?',
    b'X8Tsgs`w_F!LT;`X#M$u1|$fO4DMkIue?}Q9}cVcWO=o$7ozZx%0{AcWg+Mp3$9Wa@_@HM@EYFe7Shw(qPN~oy5PW+`!Zs~(X>!c',
    b'sfA<=S?Efcby~zeXP#O(N(<ZBwJ__oA}~>iErt!fK)ij&sRX*IRCz#Y7?%eNTpwE4WCx0`Mj*+|B5uls;xIg-AISwvS<H}A5aFBX',
    b';E;>U7r`KVb%A*fYsqNEgO?_60s|`8PF|pH#9E?EYubci5yWGv2=*Ion!HN0nE%ZWNL&XE(ZLC;s1CD4=o7|Cos*jC`qZ>!&L)K$',
    b'Kk2-&7DgW_5r)}|X<_g!65;5*e-;kzFcMBWAD)HDmqmo3^EO!+eLzewcrT3wmIQS_Oj(@dn0zvixxWSHL6UNRXBm2NDA{=u@;&3?',
    b'yb!uZNvP=>p8LX}VSJwZ!Vl+RrtKV@7eeniJul*1n1jy{L3_v9c^C;;hQ2VcpBM(tQhwm*+-F#d6wvh!V2Z6vgn($G{1%<3!*3ee',
    b'VSRk%H?AFykB<P#F+lP3qW}qY7g-2?AlhSIxd7t_xz4V$Fxpq7gA}pjbhAt2{fx`1qlv)3zM;*<^4)t`=)Vb+!skQFQ~JN}==v74',
    b'ydjC5chmjkeo5ECKCV7Y+9Rnx$hY{-?zH-Ra!2mz_Shp&>UY7v?Q9SG|2`-0mR0+DhzADX@xvVmA<A*QB~Jrz*Jl%$z5t;w|MrcS',
    b'38Re>k@oxV&<Bl>v_G{@L-w(ZjFj`bjymGm6}eu&UztXBxM@$pk8SF`<vU$ELh(}ChY|ieWtLkbQPf2B{m0|+hR=gTMx)bqXqT#+',
    b'uy>CAZi7XpfJ*O?!|lnatnA?Wgk9N9MwEpVU~b@vg`V3M{C2=Wa$&;e^<4<uAeH?^R%jH%fhvYuN>v|VWsH(gyF^3SLz`NipCUFb',
    b'blRFJ>M1#AJp@AG#1V}Eq65>I{gz|m1)nfMdzP`|Mm{6DXnvlU+6zuQ(yI;(f4(vIhl?ex`%ebvBY_S`9Qm-i+{Ca}*S!ZJ*RJ;<',
    b'nt8JJvscd5&*n^RRdT_b$U)rmK0OFYoq8c8{zQk1EBp0C@7bCqg%{b-K<K{DAuRQ%p6J5IH1uiv<NC?))vBKi4R4p#2Z}7H0Ib(x',
    b'OmH}zX2fuYPBZkGqtonq@wK{v5jj2gyn?I3DP6BF?pT*M!O!vADKpXV^IA5#wx51!JFmx)*{$R3npW$@NU4gzh6ilgme0xh1EwQ&',
    b'B1TqPke`Q<7CdSQ#MNMK`*xBy@^9#az=-$)7bnK|hh9?7)SC>ZnLk`>(wxrdDWnmJl7&xQ(*;f=eu1UAqV4;2gSLp!SfH{^;mrjv',
    b'Cl-i=z~N{#A(`Q3-1aw7{P=@f!(oEbH)n0-X=Ce*uPwKX&WoUKBnRECYV8}U5kktjrf6hmyq>zSwH{6Cr(>$M#XV?+4kB6sa*9#f',
    b'j8do6DUf)3Jv3Pu-|afPk_M8{5(A~N-(VCPziWXAs;Y|1_;nlY+bH3Nc9#;F^*Xp!{qAxb{b9<ttZ)C_Ywg-t!H93X-o)*Y+HG^~',
    b'$B=|?Iu?fR+C+4Z(G-)83Cs>PqGq80+(+GbaLMB)VlX&^^gtzneN$r~m3?d3h$xI{zuESe%jsg-Q~C^_2ls5`8+Mmq@Zj!R!ZPbp',
    b'fRbO4W#@n(U+?oexZxE6<G`a?XA$CJa?F&SJ&eO7mOgSmr!eOd{V?)oIC4D1CUTFziZma8K5{zI#w^3bZydC#VIOIyil1Zk(deh;',
    b'?G;=aCfL7rKcH6&Pp1askuZnDRIYxZ7oZBi35P*w{|mP*SvBQ06REIS_Ju9Q?Ykb$BlAqfA`?GQQq!BsTk3uL_l2n=+jJmiYW6TT',
    b'p??j3!%&~9O5nR0t3%sjcJ`iJ!zEfOYABoyI7IHU+Rvs%ZXuUP9Iev><!4-O_0|R$$!cmCdb4F^wgEQNw&wxIrgCn^ac3~vV%HJf',
    b'&7IAiJMKm9nK5U~7&h)z!6Jqj)XgSF=&!YiO-)?PVqELhudHFaAneb|fRll1Xg2+1g^ruL20-XnI|-CGJwZ<s7tRU|xBK#8ROo_h',
    b'$=OZhG5>J4-E^_%3!Q^E{#0k!Y}V2H^Wt$^aQKTynx_&g7}QM8YMaTsc8<2C-PG2h7p8$Z;o`2z4De3x*XSvx%;pSO$oL2POxl8Z',
    b'Z1$B)OLwh#O*F@O?lTZ|aqJ>D%V_Ipr^VjJCw>_&7_RTyM%OyYMr-vfHyK}d?@6n_aEZobtpQnko@(yi8s$gBGOaEk!RmCG{+2yB',
    b'B`s`LU(~qBS%9bC#;hDFO-y4<8=bc?tL94)k^WF#$mj0DaG)&aio$Iy%|`#P2)92o8K!vv6;Fhr#cl<Z&P0F=>@IzV&W}Ya_LdJ(',
    b'64ZbF2O%Ag?#)?1X$>6qsLS!Rfvmt@h_pLe-T0sUVMw{TOvVD?-lFE;1$B>WtKLyC{gCTmy|Hj@x7XJ>U^=zb%8_=s8u4auuF-?T',
    b'p13(tDKR_-3}tCy1$0Umce}9f9qT-#4bf8s-z{!L(HtK=O?GmfFb=xV56N95Shblp=9JvszGv}O0En(V__OyW@;c!Gf4f=Ty?YM;',
    b'S<RK6E)RKYrbnyyE6SO!0510m)7FRK?V6zL(RL7)r|t3@mI)N&w)D)J)t*`2uDP-$@VU<zhn+#MI~*S&5>J#MatGPrMzYTG&N<xr',
    b'b-j0c^6N)lNaNZM{=qiIQM>MLcIffIUGw-iZ3U&ikjGjdWQFb{6%e^@BgyLa;_hUoQXpu3xB9f(XbE!(2yU*DTUq75l>lynWV06>',
    b'7Q|vYBqamCcvRx)!coyC!@+5%G_xO`N)OTG=Z4H&Gav$COS7E<QM}_ZaOmaF2^Qh3^(u18ozoRRDMFdgVzNVbKNbvTFo{cVWlq-!',
    b'hj2aVI$@2FcfTiS?HIZn#0EE+8UALvgWs%)>z@+r<_-t5LTCEWm^)@UyzRt+PLj|rj&$3eYG!D|N&2(@R)5U?9K3ae5}KeyZ+C9D',
    b'ak|GD3@mzw2VTpPB*T5FTl%}Ygn(Y}QmTcPv}rT4+_f2@@Mj72DY1?Bf3~W~#c*5NS5|Jp!(MEx!kL_Xui2r#zMbBe-E7JFkm%3U',
    b'vh$}j|88s|Qe~hWuB<flf^!%4F!SlP=ekvAsWrCqQ*`g$fi-Mfdl#}3^%quiz|N<Wo(j?qa`WLs@4MyA`qn#ZNp|SHeot?xw_LNL',
    b'u#-pWHRDQ;H1KziiHNSW<YX2A!RSqeDv!LS_jfNo^1k|NDNnyG>ptz8pO<g@<6Can%jY(cJjmF6?J>K2i%4Vmm7B15N$0NXt^66N',
    b'zu$@Z$)QCz<bhhHx+RV4u|pX{IToH}|AdR3y!o(p`kJvlU`wG`iIdQvfyuoXONGP*41_z`>y~+`a13)?7!^kGF2idB)AG->xyTU*',
    b'QptreDgMof;(=SP!QKM_$%&|xb@+Mo5BYccai1IM?SP|zqFCJF+qSa&eV{27k@$InjpL=T$NizE)Tx+B!l{3IP>yrNke!!evPXI$',
    b'xB|=hD!5S?o%mpW34JBu*}hO|<L4d%NMOF0#`yDrW%hl7kx#KuL$!{XD>anM7<AP8LshO0vLT{_5N7o~_LcJAr<?Ls6pr<-HQWSu',
    b';nu^H)tmvc-?gvYLbZ{f5j5Va9M*Pj@8{j00u37phiofc_wB1NR2IR+qW;h}jeLA7Rp@pmY=7q(39F?r)0tY>-Zwhs0=E!$1;mHK',
    b';p2soD;ln@m;n9fwy$oHhQqO6sY9-;xbzbzOq3I^FXAv}ARfxVa~a(nQUI@37s#S=Fql@3R5b%l9&I#aLfn(gxoG3D)S23#OJw)-',
    b'^l^|TLY6w58v3-0V=0`Ln;dc<yXK};swZ3Q20B{-0@^JvrJRcr0W{^MoRx1<$->nmai94n<;oV?6o+_O6|q>#tn`(5T0nbZuNfA`',
    b'ZBu~lDg)w-w0dYJwl>AyF4F2@>Ey6<aePL%!Tu216QLPmDyOXYs9cyI!l|6=pCbLXHM#a@osPSGYGZrxMw5Ko-0412clYcu4YI%n',
    b')Ug}3(D%=1Leydl7dVE+Kn=3*_1*P_bapxB(jIY`lS+H+H0ID2H$QA>%osALfgBNkf<LJZS~kT$4Vwf1I_@X&Gg*V4U0!_j_P^|?',
    b'_+U*M`lW19lkoDse&k&;<%}t!`vcus0j<!Np0Y=T^?iukho6bQ8<o2WQ`Gkhe7@uFCO-^u(%*C%Szle~;P8_ChHcVm#*Q6?>2iJ2',
    b'xb4E4h*SH9Pd_o|egCuB2E%&D(LVgk)_8_69kh#S<krzecpPZsTn0G$fR;hv9PA>0fHYmj|4R|3YHs{_qEw%i|5FK46$2~(s9iMN',
    b'6BOYNI7S`r&&w}pfrEK0W2~|8skjD3!pb;kuY2Vkbi_X|``{%j-1x_#YQ}wYj{yZO?-=^r3+EWd`}6XRv{1eEZ6x2Qe764Q&pMzM',
    b'u0okY=A71M=dJImYBGWjeY!+D`qEVGL*cSw`ItnCy(8<d@hs^R8937aw7h+P*3Wc*s`n`_<rh7UZ9Y&jPbg25&DU<CwJkppx51`#',
    b'Ey{|T^Bc^+ur2mxC$muVR~d5m8Z&0~*{ybO{rtRhOKV)GkX+KcdO~+_A()*=z~pPAu&q9s<_=lbF_F<9&7AuBExQd3pKsZp5?HF7',
    b'IOO+Lo%QqyGi4WhE>KeP*5mVNYEa_5VvKn-UAEdLR$46ejy|E+Vou_&-Es6rsf;#|{H7dFo91`gVqY4nZVIb1r6p`@=8V=L`TI9s',
    b'S3?K22BAyHLk_cWen%Lxt;B=%+%Qvl?-|QSCr!n|jFCxwPbD5H;y&`W{>T6XNjEfrpBrJ+_uEm5p&pvny-XJrYj#RAk<-Be4;yPv',
    b'Kc2c<Mqdr=V|-(@6rR<-Od1BP$kpl!`dqvgGH;CJ5EF8kFyB7H3w17c-g$V?BAbI#=<_g*yW97xoBjxRu>uKg<d$FA8}6%{)qm3V',
    b'1as*=jkPM*^yU{96nn|Ez{~4dL)m-tB)zyG<?5y_hq$^}Rv(|kQp_685d_Oj)oxk%mmmn?YVhRz)wAOlQ%-}iAt&@gEyP~54F}jE',
    b'C-H_RqKvcTQPYYqY!vt0V)NuxPjPv;Spsji*wPF-Q}TUgMJRTWw$7w<i{LboG&Z<f3P@a`pB0&lCt8{z?)hRJYGOmVXoqu7Lqp|`',
    b'P4fHUk?Ia7!e$Y|m|m;9<6yZ|<!g&-7i``2#vAdUC3h@l<Bq-I<QfcyqLmP)KdR}EyjV5|I=<1ff8=qbS8(zx`bPh|<~5wd>+fEB',
    b'n^EAm83_>Iu`NuR8eg;t8GYWYVOeg;k`-FNf~#BmJ3o^LK;R=|^bzYl`0#ddNbHxNmv33YJo4+$OYbW$<{Vr12UbIq+a8E717fLS',
    b'fIB@ApzJ(aRu<08d7#VAAqaErn}T52cJUH4PM@=Y9NY&NXoSs_{n+rJFi+ZilKjo`LkFKo*~CdE#|R$Xg&8Rq*0H`x2{>=_Fy;Ri',
    b'#7$X;8QI`%N|z{FiePcK^o$`dayTav(=$Y|aPK{69kBCW?VW=7+J0mI*1OMm732n=?z69k$TJ>}*&k7gw-`G99O!T`@8&UG@%}((',
    b'&2~kf1<Y%-6DxTSdf~8o(nE%2$rg@FA{UIr$<Jb0^h@JXbkc5u#_~ztm&Mqvbi=*9jp*uf&M^5q=VYCo0>B~Nl>QZg%LHwrJwr~Q',
    b'`npX(A-Id?Tr!P*@B=p=BDdA$SFRgxP%GJZM;k<jYbVOjl9i|E<GYWPxbiR9CzcvvO|Nb-&00AQ#s`45;}pImip%y1fNL>a?+ikn',
    b'cO~U|KATRG@e^F8R==LoyR~YSauv@qa#HAf=LZYI=jx8?g5tI0QAqR1N}5Mj(%@uK3T^Ia{yb-T|NW@r*Zsiz``^8#)O2!of${q2',
    b'haPYnO!w;IZvFC#{w!1F?awj}2!BpMVWJp+qKOdzh1(l>;pQyqIP5nX(aDzM3yBwT^mecqB7RsbVzatyXD!Dfj`Min1qgK&bXzz>',
    b'jG`FK(Yj-IpT$itud9xGh0cRKkY|1$yezTEn4Wr=r8sL{jWc0K2$`SOAGXr<hZwGfu<4u?eM8>N4bH)h4mRcenro)!;p~pSsdyBh',
    b't6ltd+^2ysKTVsCQt{gW@6#W(7P6`|WhNJaZT|-x-9l){Fn49Uejy7bu5Bm%O@O%+IF`HNCsrh89JuJZ@)I)$;q{dG;{3W*vu~^S',
    b'tcnVs8c3ef0$J6A`;gRPrXxd^BdMX0N3i}oJDSynY{kwM5ViV1Ywy26mMG#!>hZfrFV+-aR$0feY!0WDm-c`j+^(0{e4z3t0&jC4',
    b'$i}xBe%tEc9fG45!qE1Em)|$T!^)V}VN6WOZ=d0W(d;12eV^rLK+;<DL$$t!oSjXSxnFs~!C)R}2(TAYoV};78Z&u83G;uP9W8l5',
    b'Z@u!aX(;#p;{O&)oJfDWWvExH>yP^r+1hRk&tG`KfdsTghCyVQ??a0Ya@XZx2Jm3v8D!W%4>r<dwix<qI?8_LBf9Lq;{EM!6VykK',
    b'c%CqOMVgXpZs1jjWcplumP+DGA4JX7jOi-VOfAOa!S<<tceWd|jdo81V2uXiDruccKh8@t_{E^U+Vo1T9<}{x+YLYS#C1`zR6~WD',
    b'JyB=4;E|e)7c#1Ek2X)-D3~1vm07FR{Q+b)sVRb)h9S-wP)vJqe1tKWEryG^R;~Zyk>!d%TM@DXIoJ)M%{P0YTC20z*NRUyg`Hl2',
    b'Ac>Z{*B{U3r>piHoy|PE-|f)`&yd`Q0ZH-KaXj3EsOutLf#KjDCu{-m*DI*|D=50KJU^WZ2`qW~u_aORTlT$hLOUO$9S|#uQYt<S',
    b'Nrki+(j%Ph&>q3)-^Rv7z{)Mf$(l7ulK<M%sa)50>-YPdMS4=YWh0YnR^Wq1H+?a%qz=Y&#f{mEw^6FM565xVgSVC81`*|P&cQuh',
    b'59QVa>v90mjHVbYz99k!%Ycf3;o2ckkd&ov^Xr=<AeDr_CV;Fly?J%BS~XpB4v><g)C7oc{A3JPmgZ;@^p89)`7*z|EC<b_fup3H',
    b'?oOgv)<sn@ZPXavN;-u&(2<i9ihTrSe!r_Tb&&9Gb2Vr<Zxt<Q<M~=fQD%(z+ql5_S+zA=(xUex3;o_&wO&4VFP1IX*(-*vCob}a',
    b'S&1v!TW)R;Ep$k9tKUCzer@@@=~K0iNANAVc}H)D6pmuXR=pjtOAUMAm<nQYReaQs$0vVi^F56DGrvDR`(0FaCPy76hK59}hf31f',
    b'1<SBIVUM~{4mom%bP%8qNe+!nzlMc|4|p1pA^Y$FYZz##{41=2j>2P#3Nr)!F%-s=Y3Q6$`K%f;8CkSwxRZn$Hjh(&UGX&=_T;FU',
    b'{=Ub`cD{P@j|b0|6}?*12VIihW=U_p_MV@--n)jI?j`Zy0=}%5w;#R#@DKCDpg7vwTV67@^S(TMC}>>Yu{Zm6f47d;>-WoRmceFq',
    b'@g?+m2*dr`)e6>wdXFzwYg#`57P+Xs<>lqwEpvzUdiz#aeS`@#+M3E(iO;TTXc!J!Ay9<rl^xWY{^C6as(zgED-Wde-jkd90VBq`',
    b'gK_cETLIkl>h7kZM-28@C!_&BDOo89==P4n1eVnV@Md*)OAq&$P3wlCf@qqjfYKDQ_a->|07%@zRF<9cc;e7!vFDyxi1jt~5V)#q',
    b'yw~yK`u64y=5Wg9^b{ua5iS`@oXA><4;ifoE%6vaK+3CIb`3aE+y&ZQ@$btk<SpZJd9}Q}yX+#jkk8~d)8}sV@5x#aJoM%Umd!xh',
    b'AFqhwcU_Muh&dyW71FdpwMmAC7Y0|5XYHK!bxSY?UW^_tU5AD8a3thf9m*zh_M%qU0uzH|yt?(e)XtpE)&DIeewa2%9S121t2B(0',
    b'Agl7Qh@&D-A{v!>8Tw(Fgasu*TBm_eliE*fQs<2y2jP)<#3xT*J$(UE`0+pcOd!JGc@tMjN@+%$FsDhGk}MDXgj9Z56-hz-BFO4G',
    b'CGd%saYnPK48x>pNL>V^$Q#Sxr!Rke{S+IQWE2L@6Y6JCK+_<}Xr5L{ocJ($5=MF9S9wq*S=!W5Lb8(3CNJtRj*B#i;@mQBmyDWK',
    b'OMUqQ4xsbb|9tgS7(Y%M8U~>ccvMZ|XL(L@8We?J7C_oKj_bItX_&`xme&o90-#6Tq*)DADeEw>j4#${HQ<r?4V)Zo1lmNfx=rr;',
    b'FzL7gYSSW&OIUwDDub$OQW}J`A!SuZDQTK2Z1Sphq65Now95S;shcFHWms0k&obb(EUBY9^TQyB%c!X0G$`{rE+SgySyq?ukpMp=',
    b'37I#4Wc<3w;y4GMt6^+E@%=mw0usknNTR0B;;e{+GOUXdc19THC8?X3W@Q;h4M|B5TgDgDxeFtgIVppv3gaeDs|=PjtkbBdOPW??',
    b'Sd<mbNfp4}0y;2?gca<>ENf!Fs*;2Tz1$t&vUMYaz5|-Un9<wP>+I!^r;n#jzEdY&w}NhwOP}wKPoDkQvcx}5p8xn9x+P44?D64|',
    b'*LURw9K@5BFjh?<$T26a#H_x9>^zz`zIrgvMB*`0a?S}8U0ONI__pN#Zlk^l-G-U!8d%z^srGwLXxW7+EPM>$cp&mCc&_Hvq1Xza',
    b'tJ!_jx_=0;O1n}BL@LwQfSs}i2)vP=2pomhNE?;D=e<qS@SHD_*PcpVY%gSn$5+ByYr0zt`^ZQqVR*yZnI<x=p8MpdKKfk!Lly`v',
    b'17HJ8ETH;<Pv3-TtDJ#mT~c|&p84gA$&w=NLZ;G0QJ9Bmq<PxXcO-CMkK-V-4T)`7rb;xRh@@G(VfU&D!y<@l*9mi*oArisJYc0i',
    b'HtOx?d6-9WV(ZNb0*|ZxGMCUz|Bt1khER^Z@tHby7ALB9!k^`=*FNT|!THf4nt&%st8;Vnu~dgn$SK{`Bj3X$luJi$aD#}`PGDRZ',
    b'4-rNV-H^GfvP=Q<CiFPbgnj4Wsv>M^uL>@fQ&yE`xRH{WF8Mbf=*^p8A1Q>UE8c~dJ?rh&o$@~$kFzd6&m26u8V?#Y0v!h9*sWFQ',
    b'Ik{RkbbZSP9#l1RVLe`r;0;SZhvDRU$bMh5_u=kO`)Xyz$;(q?o>d*4_-p-GrYbsE^usNb4%)r6ux~RhG(jRPjB-MSF&2j!Pd~1p',
    b')Oe(Ezm3PM3ad}}DV@9rwvw#|9(*F0$#7n@FbCo@jTIz&6PlG5gHj|=8iRr^g#n<-16FO$$~_MFPsza@N7IVr-JX*s3o{e5l$n9o',
    b'Z-PVjT>Mz7f5`!KO6&d@tqX93C+MCymI<5oDQeHUXPqlUw9SW-hHpY^O^7oQr5^ciFHLnt(1iZj#nW+eh<MwedI4T5#n?p>7v>p$',
    b'+M_}-KhMdKZpxCb7D=3Bb>!1HO@rXTP3{{@Ln;uYQjwPOkoR(UX^Uiz2o!!%<q2&}6qrslu2f=L7qmoAIcb|)XEqhWv=_g;XN3VX',
    b'M+<t(IREiBYM>jY9ryu>>!2Y>KTPHxRu)k)qoaP>jsQgI;RvRjM5<$tA+x1p^ReierM-zGMLkugoN^}n1!sw02nKewn`BB~AeW%U',
    b'rm7)JKHF&tok!7QCM?_3JcB35hWa3L)nXq`=>_??ztt{duU92WqB3q4UX;TB!#23gKRD8;y7F8E)c)wXkb)L5Efecpmc1I%%|@u}',
    b'K655RQTO|pPE@6NPQ$#LPIw*!Fr(14I%CCX$H_>_0biHA^+*{1Ggc|@HiP)zk(YNof9j{S3jMO5e;8YM^Q8W6b#vV78vR5*55`Qw',
    b's`Tq1vNGlkeFqb{`FPSj@U+mL_F`nd+-Mi?exybg6B4AAbwYhzmtRKBzuR&f%MFDU?`OTzIL&Dpbki$Rs~~x@s_xjS@wti;5+`}>',
    b'(_YHw=fFl<Q6dV*A5Tx_&j(nT-AeCqLP1W`)Grc2Hby4t@MO7WuJ<p<CEapDBM;uo%yPKW(69>ot(CwZVtihFdiypiagY$=-f)!^',
    b'_a(-ICd)~kl7*M%Mp?nn=UADHbk?}cYCOzT;lW&D?{^);JZXxYFxla=WB{peIKEnV_3<sRS$W5o!P<C5_mq2&Fn^Ua;(^cp1HW3J',
    b'^sUDKc2sRa$Qf~WOWYzNc}aq-<Ec2%OK2(n<^E*z9BTl3^~~z3iu|J6=J9#z=URy@hGyLJ88detX&ojtEnJjTCA#bLnu?#tc^wa0',
    b'T9S1~WD<nNskFQ~hRtj@8PPd^ms6{fI!(&7n_6(5GI^TVR;iCF`@B}Etdb(hvwoFwHW65*+($QmAJa3$tbJZHp+S_8D(tsTP@ET$',
    b'UMm}>GC*TtPupwJJDg3@_(7EpDrTy`tO-%Bo!+ujMP)8Ov0G*n`K_8|&`t!jC-r0p+Q<$k)5IZ3d=gC;mlU7P_&}h^pKpF)5K=d{',
    b'zx?d82s^&lK5ttxIa9Y3XXIf2pKN#h(?vH#fDAF2e0DNKhzv2AVa!8>9oP3qplOr{8D%ndSSQk2LfU_s28oeDCOgDVsFh%AK3WEL',
    b'GDM2aV!WMOhba18U>YLB*lN5lJFR(tp*D?@Bcn{0So0{6GiMdZDAR?~JWAY=s=aX<w;{IGr%T>$wmP=gryG@ZjPAC@{$(5m+wRlV',
    b'!a7QO?`Z#J90l9%llqUvxr~g}-wTZ3v5h`y<wo!h92H=jeA1MS;9C{i2prqqldg&bhwTzDY20hEM)=s?o)kzU^0^f_wxuVX&Io)^',
    b'_Kfhc%{*yYIQ*c4Z^J#r_VA<$X<<8^q1fJ?6cZeFYLL~6CME}P?;|nj?hc4ZcFNvYf`ixQ0~?(Zm<N*baqvdilU$XQhJMgARY5Xs',
    b'x|>N0RO=~sA&lDSQu!TOj)_zPLs^P0y1soT6-tr9O6A1XAC_0O+PIAsezCgxKlEnxY^q&i%!An1qib`b4&lc@H1;!J{kY9)#$oCb',
    b'Ag&8QodQIqQS^1mkYG`k44@_Y=+JV6W`%vsIn{})G=C0##OpMHo*fkA@R_hQ0ILs22oH1-@6Wh|L;QD^3*dXg{EDW%xlvBlAs@dX',
    b'scO|<)y2f8Ad`j<>*fEU`%<#h)dvQ0N?fqtV>}UPgd~D#AxjvD)cF6|d-LZwZX{v!cm5S^N4yF4x<%K0Se9mKiXQVDT^}jSyX){W',
    b'>Oe^yCfVF>(zbS<_iukVt8gSxsP3jLza7tEsS8LX5{X12Gm%LEuls75td}MAijI<$BjUNJ;m!9G_*lWxMGI1x6rkuzi|}0Mc_lFf',
    b'nXOuZ&(_Vp{u1Hna*`5;w46Q3@IXng0o4eKDFWs8B*KSC(u|Pnvr8&<Xu7R$tK}6I@^p;3ZxM@eg258P%qw|W-`6A(lnxJVK#>pe',
    b'L=>>r23hptmI+uupiZH?PH(p5IC0z=8wU)>PZEP|9{Loa2f2ER2$rBHbI%_T^Js?($LtSamOeKo5n3l#sJhXh7{x!-%nrYU1c=7w',
    b'{594M>4PB}0?W7~n8R6D9-azAqHdN#M?niC1Q+PJ#f*(;m6!%Cuj1$s90{&2z`H(~-F>)4y%FyS^8rnw$v!`oCop@2NoLEus<9KM',
    b'?H3$~t%u3paK=R`^P-kLa`>xdtAH=zNSoIfGvZZb^rgsNc^5(0W!3$dH~uH{e&Wpgr(mOGoQ=v1W}__m#MmfHJ{2}9Gfy_cwB3e{',
    b'Xtz&^jnZ*83ZvqW<Cku^-rT+Fx(&M1m?p6B49kxQb}_^inXEhllMkf$kqkuaB;`k)bN)!#OsDW1+F8=%EaajsUhDfzf@mYzYxf3|',
    b'+nBrTkE2zeCW|g6DJLhb{}&{=;TJOQE*=9ZE;EUfLk*hCKz$^f!j4jjJ2o?GRZ3-WVDa1?t=#W5p59G?>4Kt3U!@;kG<l#YBH6b7',
    b'P|=wYP<FJQ|G^@EUn7}mU=6#3aZ`3>O4T#WXzLtPxyv6fvG}_~O`m!Clz55fRIv$uE4#4lPyke#f@&)n<$z?^3C&@8DNJcUkS~e7',
    b'IJMNOPxZ%yfMxokm66G`H+lSnC+_^}NpH}j#ti}2V%->d7dukN>H!|}@+Vlj|3P7thUd`cSxSL?t6RKK?J=>w!*%p=zrLMnWmePO',
    b'&Yp~9=z<N?@;k4|rfI``Y(7^L_GFQhmzdVX!YJl7@gp}aTi%TAWM?LZVkvR%U_=PZXu3~f^bPy(o(5tv`hKj!bRN>M;*q<YrI+>C',
    b'=boIq3TM>Tr<cwY29TY<9(@M7bykF0d#6bc3VI~h`jgD<^BkD3N9P|ioApH5*pKsgpMJ3ae~TNw1F9Q*p#Hp=q5smHKNJJ_o?`55',
    b'4eNmZ+vwPz=4@6*$GPSD;wc#8hm(u;npcBe-$+dCPy_+zM(-D=(E}pDj+W%n6u#lgQqT*_e!S#k9&$riY8Z>qMt0|szleyg1Mqev',
    b'w-oUsbFeazq4$Pa;8Tof+qs*oBIXF$jLhPEs^P_4H*0x0)iStUM{2Z^dSXD{U9(`c>wYOM)#_6TE`mTIf;-5>G5)wl7V9Jg|Bp?A',
    b'ScRU>!cPQi5g|F5*XddSn{xuQ7F+Y`gr23kC-D~b?HU!uwq4^W*t%;<5e~iD7Nc@w{s89$tQ(r412fG+U|h-7X9}vN0LYiNf{b#S',
    b')$9=;Z1y#k#@ygxSpU54Hh?0d-Ea8BtTqa6^3-e~&gtu>B8J3M!20}X7Kc7F<SjU)FKDm7%>IWrKE!{usQj|!&#}6+bSyk4$o7Ss',
    b't4nAr39c3irj^NBRw`KP%!>vKqZ%)o8rWb8YOO_4-koYAdDKdWxp^m>kgfF5(Xe|ZB==(05#Py1|L0Ze<6Wf)y&v`_1#c75jgCzf',
    b'6}XM4wnW=G%3$$8I;~PwwOQR*FG@~(6FJQ&DHsrC**V-n9)IK-PeT{E$Ma=}nh(tt67`V2sWwROarEVpHqcPM6DlAjg8F9k=w3hK',
    b'j~Q9^=DzE!S>feb-jFm5eJQEsW^<1oWqB~$aD=2XQfGIw)vq_C9KcPte0RU5GyRf<-p<~m>I(A?-T@R)(<5>G%^8-E_jja<l*oci',
    b'w=yENq%Z>!qGN8jTD^0Zka`>W6peZt*^55WRS||jM?0bec{EcDke*-%)v7m0vJP_lzmew)HzdqkBDBmQYN;v(kJkvTFK(*a&HL4z',
    b'Qn|`ndf~Bu<pr~8?`j#6yEz*1IbR@4(Qb()UGO$$MG{ArQz@mW*%lKT@AyW32d_3X>KXSK4qhHQAph%QSB>7yMq2n7FNyk-weJhO',
    b'Th>cz(Upe1Hh(oBxSUf^GQY99Vc*|W_jm7CYhqjO^&oQcptZf8*VzqCHXs~uqT5hmj3*PBt?#dp9Sjqy$5*7h-G^_8tUa_h=7aIp',
    b'Vke<KCDm+mwYsx+{}$0~BC>VRHNV??_EH>AVfCw+4L(V(997PgZL7>mplI6O$G|{^+$KR$t1O=P+KIiKn{pEzE#~GiPX_20bYm$5',
    b'$=HBFFr?d(IO0(&KrXBe<SazyJ1gGZ^3aM(Dmf{WtyLv4E*5%{Bs!4vZeXs2Xx~;%)uNGkcC?W>GW*?*8JHB5S<Ys{tu%t8di=T3',
    b'L~t@`qnW5ePNgzhdzLH$nrVO>ErCP)JFw-DG*lD-*oAtUGT<iPT4}rh%B#!Y?UP+QQrGX!BY#|tx6zSb{qXYi{PN=T4OHQffNkm~',
    b'PunU>64V4q928kw)L1vqgE~*TI0@poDTxg?Pnxc6>$nZduIiF53K~xw&QFh@U4DCfa{TP{@|&}l&(2={4Z<c5lQItSHqL@LjLSUA',
    b'vN8zU0uw2(%eDzil;=&EL`4;6sI7vu%#t82P=wppaq5W;N95x9t2ff{L)!4qFWz8;UtAuazd5^ja|um?^u2r=eeS#bZ%@z9zCAlR',
    b'eslKf<>kq%mv2u04P1{Zz*o91h#I^wc@u?2QZ-ppmRTEwQHqMP%L~+?I10KhZ&6y8q!3|T)^*i}o%edYet!JYxe`elrA^YrT~b9=',
    b'TQxxuv{_i@O^bg@<D{vgx(LHKO|zuMY}|Eem=<xCXGx7QAFI4bN%{Kx)&Ds?p%igoQlO+LQoP)0+;(XkmU!7w)zmc^8fBOrGmJ+b',
    b'BZT)--L*v-c4>~9B<N6HH<c$vqzv#5WSX!J0#u|$6?H`sU}UnUDZ3`cn>P(n5q5EhDvVwkH*HYFK^x~q5@%JERB4tLpJ*Y>XJ_Yl',
    b'Azqz>MKD8>;U;df3X?Y}GCYf-?Q$%#;--n}G^`M2lQhbjHZ9sT$Ey=0E!oLQMVDc;2<NMFOzvYmJUn{QwN+QOL6*gB6vkcAbeJoX',
    b'wynaX4X~7`vMj(~lN<}LCTJ_%qzfukBb252*z!MnadvS*SP&RHCR0Wz!Gm^LoR?8mVqp_RWfh^M#6!htR5f@%;7v%@qe;pPb48XE',
    b'd66PCw%RX_-(ab5{QT@cPQj@MVUl1jE>k?SB5azx?67n$@d_kGk_KIop{j1uxJ(*Sh8K%~ro|^n(v_I>brpQ#)lYR9@bQZdQw;vt',
    b';=jiyf5#L5+u4cAcu5jR_yBG(D-~TBl=x(>!YZ!_<?9yV^AMFN!h=;onFn!~)isLCD#4N`&PwFH-G!*LXa_~wrkKt}*)%~N)?L`-',
    b'S&U_ITvV9pDy$JiF+PIvYU5KXE<?QbD8~F*<K@62BlIExU4`Rs&M+Nbo_%|Y58UsLFTPWELW!kroM6dQ)k#@nHK4+(2p*;@;<zo7',
    b'77vX{kdhsc<SjlS@jnUHog%DDwdGj3S)CIv-r#+4a&r9q`NRUb6cA4!000U6fruCJC$C=r`{l{;Yf%E%*^?<5SeWz<2LlOFe)nK_',
    b'q6{GLf4?Wo@bVQ_eg5|S3k-{NmGE|SdWH3hAFxE9^`>u+4#&@)ou6J%B6;;816&@ze0KT$*~>RrBggad@5lNGB$Ekcg;{j~mcD$f',
    b'Xzj$}xy^Wu;>IxiO)r_Nm}Ywu=iBf|T+<b^>)Ws=<>iVrP`*BPLnOx7!QR%xSr4~++3MyrD-XS)8><4qVrN#zHyUV*Biiybp{w;V',
    b'EXbq=mW44I%4YcQJlb1Kx%T?Ud_9;My~3nA#meJ7@pHU0ev*m-+m>-)WUw|eSX$X$P<WD|{}4cU4jA=&40&CI*-!y@K;9MjtOKCg',
    b'Zbak+2?t_jghkzA`O6+_=F+z`7e?ME9XVPxBPq%v%;0jeQvkW^tx`brO^eyry6r3V7f~*=_rlL@RqKM^>N;=3wu#ybp|)s4taai$',
    b'f0^f4?P@x#Wi$oWG*E~Yj-bXWSkdGm!a6xt0kEP{74}Jd&uS=bKMhfBbC?Ewj4%>=3ETcL2P|fxQfXE`SV)~x4Ns}8DNtS&WM9=g',
    b')UevMjass{QA^Y|N@eZ`DW%G}Av&CEIm>{ep~Ane8qgkdA2tl1FOvg4uYo#%kIcleEhKYgkYE`9+)S>vMIpLTa|BTFODR<6u1x1$',
    b'xDF_FCNrt|y&bQX2Ivs(0$t#7e>85j*5_s(Bmg0Rx>&Xns?o$cS)$~PT;MU<hM`6%Xsgo2{ePe@2_qs7QsFm}&iBF517sV7Uk&<b',
    b'l|0_1YJP?S8lhRr&wT<|+S*;D<exzyI%aw1hB$#98%nMxv&$N<*A1wjh+KX^DNfC8hT#maplsfH$dg7T@$j=H^&a$cYk(kY8%%kD',
    b'#@SjY=^2HnB4L{aD4PaAaX=DlGyVsqbumeyk+AU4W5$v203s@H^+PM1&$o9U*Mv7fFBMhAK^3Os<Ef}BgPusAL;<QjVnEeD@99?H',
    b'hbcN>l!tX2L|sGN30TF;P|~(Rg{nLWg0x0Oj`Ajmnl{Ft>MW@0B1xOPO47W;Y}kzIfIH4*Oc8_$xWoEY<E^I9H^@5TBFKX-46-nc',
    b'$}UNYD61mW6m^}(WtXOT7&K**MZ`B)Re6my@-FFuIIZezl)eu;)xGQCkzJCj<&?MB4J};R`3QQi2^<Kv@plmh{ul`zptnTyNVtVy',
    b'Kiq(RUlBVz8Vn{bD)g<SGjVhQd<PaVAq0$*Rhs=^RbXdo|4FGSZ=gQuT<m+(Lovt;;(nNK52DP{vdi*t(z&QW@U;*~oh)I&Z$*ot',
    b'K>Cq-3iU0-HPJ_)B~hHDRh-4B&C)zb!XnM;Jj>dmYnr%4X&lv65ye#*;fol`f;5fWDr?gMCHVilQGvGCnTZRkD!-zgG=S+lPGQvT',
    b'kFM=^oO`Eu32|vzVrd6&dlgX)w3}Ywh;A0Ku(0PP0r*3W!9MEr79x0lXyVL5qDxELfw2$NCDyjvrbiGqr0ZuI)rZs#ih$)G<trel',
    b'aOoZBH8Ld4MS2Zeqlh$;Io%(;oX|qMhj{~uWFXL8%?FZX2QV*yAdi6ezp0xq0XULQiW>@duz~4;YYWZPrJ1(2HDv*&tHBha2g91m',
    b'AyoKX7MWnQtVPkAX2Nonau4xm@|@3YsG=h@Ka(eF6XhmofLLf#H;4z*qGuOce?!4q!t;`Z>|dcf1RG|U^@i0u*eu^kP-PfAa|N9g',
    b'aZr9s1P(lx1M8ByY%lh1aElRk@?jH;L^sY?%V$%3SQ-xFgUd6V_cQ5m2OCIgy@4gvL3f(U{Y>;B2%sBP1_M300ql^(x7bK8MA7xq',
    b'BT|1)+hcC?u$Tk)2eP&9;I777QPIzCnSMNKiB_HUvQQDX&yNxO&3)57dCdAbBe4ZqqC4H14MrU32JNXyY!oxM={SMMthF~7z&6(2',
    b'$U>(0UP<%8dhCUcEe~5?4Cs!zF4fzRHZ05|eoqmp-N}3g<Wyu`j}AFA+~Qv;+P0>LbY_6T1xUa4gn~PQ-mC#B)=YhjR;>~bHwaez',
    b'7*r`CRD6Hxj_p3PjqTY5d(o-9kD&<!$h0@`a~F0z8pXBE{+?truc6yGkF;tjJ2;Z~2?cLu>XH6~)=A+eliseYDoclZ{!ez?jU7GY',
    b'&qgG;o*;pY`#H2+q)M6m19UYV?tIcUk4&B=>IFZuvF39}&d2Zg4cT`~`0&gW-kHur4nn#b8lNU!&$S89@*S>G<_lU+4y0<rYkCYG',
    b'*n>Kp4B0>EB%m~@0ahCFksv-C;mZxvI029-R6Q1ia)}nTp{ESl0|?Lp<&qh|T5T;ddTjr<$_<m4j&`r*!}kFs$B?7geINRx4s5Fh',
    b'BUJxtH86qfF~sq>ZvD;|&7TSx#=_Jp_p;h73A^5x;li}8Kz-i`H+sTI0d7nH_s7b$^pxEd-sXOrFcQlKhA>XP{M++oOpB59OK$7F',
    b'_S4$666we!OiMKEw1({xX2x#W7ddV}k>fue&LrWb^Q_s8W(TGFGYaHL&yS<h-_k}&iVm&->j-4eaW8_sn{6FD4jaB5b5P^M<Js<s',
    b'<`GWwZ?VEei<wU02ao)`C5tSs>$lpDI|MG3Y<i1>ag*Igy#4vz(QUM6y-eb(P+w1`6o<PdsQ~TN;H$o%(D{}+Du%eFeyS4%!{~Ww',
    b'l1LlhSif(50qij{e1^_*(a!hUHAnt&xQFza#un!KS=+*@lYCZ5(^<?ShqDnnK>eLRP+B0E4A6{0GVM$TY2qqHB2T^0vd*IpCLi@l',
    b'_a=ewJiYu$>}{!}^s#JETRmS;pRkT7dd9<6pEnEEOl?4_8cnW!25WwjcV>6x=fRIoHB}d>$47r~Jelb0+|ksV&row!^{!c4%#)rd',
    b'%<v2m#$f=zW#p@R*O2&pY8!W?R+M=JX;aoib*zz{d={iIKoxgER@allI*0DQF`c4^B{po>ZBo=<Wo<MiN<BfSLrGiKNu5<`Rp)sY',
    b'6kXk=4Jy(kYs0Kg>$0uGBr3uzsM@#=@gGQ#dK&~~JsQ-x->FT06d?SV+oK_6!Bw7h$RSV<w!D3QO(?Dtj>3X)act%7L({~pic!zn',
    b'4v}g0bY}aCQ4`b9av4G?%oZR2VWoBDyq;AKF={(Urzt1&AxIn>C1nCB&$0L8ArTiQwuM-nnGF>yId$u#qF;=wqk1OINu+RC2Ng7S',
    b'iZOyTEL|5gGltl3WAJ&(Z;Y4Fc|=0YsIR2iC&`rJe*R&sU7t-{KsX`!_xrAD%72>vmX>2+pO4;SywUmy|Eg*Ov>DGTLH_&{U(_s;',
    b'jilD4Np<5;uT#L+j0S1pQ7JbPn=pN;0to~bu6&@?l^XgD&sdxQK!*?pM5px>pL*mk<j-F}nI&S17-FtZKn`}BIE!f4SwzlRkizH^',
    b'=9#W|E2PJrJ~O5QucwkfdO#Tv8q6fXEGu&(uk~9gZ}$(&yBmC-3<~+L><6L^|6;Z~)K5icwT%;_+=MF?yp$gNhxPJ~yf?#J7$1XL',
    b'ySJJ@=8&Vjkd|>VY*6S_U^PTG_f13lX+;!RL5I0v{_4*;EkW)PEvwPj#?V%qk23E|HuM8%+nWC@7cfqvDF$h4{%PY--On-%l~F9E',
    b'Ir_<rM+^2MlT-tw>ZJg|g1SW=o{*K{S?qfXz$SuFi57ZUs6PsmSRqRAhvJfdLb!y%M_nRl3m!K=E9M@xD(`^mp|!KK&hBvU7(|uL',
    b'dQ6N>)GC1gaD@N&qI$P%NNX*7By_!^U6i~yXf4c9k!V29I2xbvtN4YMCt+vXXYz?`8{(J#?b<nN(DJtT3F?Xv*w6;`cD=l=)*mh~',
    b'+W79-;2wCDZIG>vZP1zF-5b86xow2Ib#=38)_9h$SG4Su`GA;Clj*7_SUtZx?ntw*jo-gP_&`8bLKzSqSs>8MIsNhuZH{kg1VIbC',
    b'Y3WkE#_dijy0=I;P_OqcOekY_^l2yDgPv}-lTF&Oq&5-_J744FUgG-;DeALXU7?|3&zCeiJ-u>ak{<~%(%*PU4{B+l@?&*#_2I}8',
    b'xo~yGyjYB-PKeonI>Y+9cm7F&uvopSK2X%jE$z@!Hpx1sR4Gl*=1I#*xe|Qo==bRD9er@T?NDEG!xjVf4K4BRg}At>PRAY?(usR?',
    b'8HR4k_fd`l^Rdf#C6eFK6Sn^s?=Gw}>c0smYEF+y%O#L>&oxR$X8P@FElj6;77xZ?@?aLMdDdD7gNejnXDl--4XZrmn{RZ7GX-cm',
    b'{;ol{+b3A)liTwzy(O4&ukR)|cx#JESx|7!r_4t7{j*hbPb`xkb>}OCI`J<q348d6uJ6y!M$yMCL5zlbl3aMi9p%=u<>nTT`?9)5',
    b'({S(EY3sc$4ej0#scj1COHHg|iQPP~xMNpq^=v1c+sc>#?pk7O$DWp<9UJItQs3t^F*iFg(hQ5W-SMHKX`8W>(wkMqcABu;<2%ex',
    b'^}Q54WGvs<wAGMXW9lYV)Weolzg~<$;jQ|AGlEhO2ddX(i;Z9-g%4LHp-nEmyC*k>>V~9DF?Y3^i<J}U$DjI*El-$?qhy0MuN7dS',
    b'Iz2%wxuM``ov-eg|Hcz5X$|EqA+67DSgn`6dU0`AF%;1+tDlD|eLV*DWVy-)+Xs=*?LA&Si+W;a(v{W3y`XVb-I2TD53BXh8_5qg',
    b'ii|=DNzK?3DzrN0=FW>I#RHJy<f>X;Z@h-5LTn!hRD)#rLxyKP?g-skYIyvw`;9873-j3VTpL(2@5nPPmYnZ;WYMUoVO*=onSN@v',
    b'o7j#ha&HDnc(GZ&yO}5w)ziyDOQzlIfZ`qc6(1rO75n?&*453OCn@*AcrD&^c<2v)OQ<l<URH?mJB_#dWdbW1ht)nvK`K&XrT^PC',
    b'LjR5UozL9l?o95|DK-rgjVUOz;&$KM-?Ufgp)YINaL!voa+w8%)c`<<_Iiz$*VQ}pQSO<*kXzr>43qswnE^bia}sHujZT4XBte&H',
    b'lTcmEJ55Q&!a1q%GRu<DY4OV4A9-cuQQbxi>l8NJnR3Eoaz4roz(L)sP+pdCHZlj{c6h$L`FXNgY=>#c<2q+yUj;H$`&#lA9X^2V',
    b'!W;#_R<1YZuv{pxj_*e8s8$QbuJZux5gz8pjhV`x6&PQNAI@5*q61Whkh;>~vft_^iK;lKuLX^dq;z4JHmdgzYKYslq~a&|F{|@7',
    b'k6JVer7p{)4U=@FA$9woot~eBSvo(GKEh;#<D2>#THqrTSLhT#RaY-9YS=5x*CX}h!C1u<7KXR*2+{L|6)ijh<uq7BF24no*l$6L',
    b'2`!WgL*v*eVW?2t@aPM6g(dhA#f$gAY~fS8M+(RAsOD@0fWvG$x6QyKN5#iXj<;|p6I)EpiN=%dd9OzQ)Id*6V!X>za+hfNVXTRl',
    b'9`B)Kle?Dn$b$gidQ4gwEOyTev%?4g!A_II;S88Bq~EwKo{wd-S$O9*feZQeD2DRzae$I63qu#$6<&fQ3G?}4V#*YiHC;Iar=)n<',
    b'V-CSyd@V+EiK+R<!2G2S5|%;P6e;Rt(kF2o6;T$?Edz;I**-phVflTK^7MOuhH=y`(A{_T>GZAL8I+~1>Xq1NtcRV*P#Nr=cVn4=',
    b'O&3LFn6xh5MO{}kS)R!Kg0R9{uB+zL(H`S?wZC$Js-MJL)G-kK^U;M_9eaG|tL26lj(W%@tg+(73%D@yq!&l=#KLX9dBy&i6Io4b',
    b'W2Rhyg^NAU=mIE5<ID#(a*nI=SkH^=NN=RZN<txuYI~&u3ryolHB|J2P&&4Dgwr2wQ(o?xV0>TjKIoYTb|n9(uSC^u#w%d+Y$S^a',
    b's}!TpdOyAS8c&1a`Fgw+-s{{HJw+*7qdzN#@tyL{_+udMS{pti<F&HK%$(1cKVkKfCbhY<M2&w6^1+;q=kh3r+8?|sqZ2f5ts}ED',
    b'&)ZLW0Z**z!Q^><geB$r_;ADjT;s$3f^#_k97xziG55g5lIC^a63xKcLGy>=B7c&K^&KUx9icypt{yx+LSJ2hGs$M&Sty~bDN_9M',
    b'Eq>CPpn9tr)sRLjc<d#|tx+k#Lcx92oFKm|dFMQ`328XWsZzGc73ZSH@9?GAp199)BlWZmFLbN#NCMegFa_WQ<Fd6rhGo@nfh?qd',
    b'3?FQ7trm9V*Uyh%8p&%+yOv_Rb{ng`ZP{iznyL9~EcQyzc6M9fv$J!2;e2)8+X0OhgH79R0}P5HDq_&YJ{V}@Ebf}TaGLMKrpVgb',
    b'X>Y6p)D}_GxY{&P(uE`ko(rF>j*2F=8iyai$U9iKN7FuzHg}nKU!7wXKgO%N)1o#-h)|T&t~OEKwRxPEHX=$0y9i@ZbbLGp>{<B8',
    b'Je@wH!E<15<M1T(ZQ86YQEm4&$SY}SqNg`Dn;k!UadvSb`J8N1hR|T)1`f^fSd9NRR>BcH(H(y9^xjY?K#paz<%{Dtr{`zK&(Hqj',
    b'bSthNo%#z2i?^ZA?4jJy@^4dU0C{RX9XC@LU`xl2L-5-jJyS~mj5&R#sUbc+94^R_p3`x4AMDmV?>=n@=asLIdaI*gnh$%#OATYX',
    b'liLk$zb`i&41L@!M|XfFK4%ZEZ@}vZE-uMC2#UnfV!1Zwpe-f(_SYZf8nv6JZR$<RT5(RxiZ%353lm7cE0qCuD$F1Otw(BE>{9Ab',
    b'!QC!Ut<5ZXw{6Y$Tzu|!>%vg`Doba0b>VfJT8hbYS+-c3t(V6`jNj_jn0#~OOyhp5P?9qUs>0(Rw&YiEVH;}gvE|a!r2_e+2?Y9+',
    b'EDNIDWC4XYslLr#%C)NFURcUph)k{%3S9tz7utEy=YRDodhq}ve;<WpKOyM~k^E0DYt1<+VKKmWm(R_lz&1c=^FcFvu~pS5KB$(o',
    b'lcM7?3HgIkX6R#O0)v32YD6G@dpR&C9-3PooI4$!9tS9Rh+4gErr<T$RX;1XK97A)Amd!NpDc>DKTHl*_<f2$@n7`JAmVpzTl1I-',
    b'pyY;G57+_$%+~J{Ajj+BNLI(~y7vaj?Yj52$|+HKeQ)1jJl<i8a4ao-B8{Mn#_MRv#^BM=xjkXW<K48f6w!EC$M)mzQUha`QO)uf',
    b'wuKmpDVtI(uatCvemh#MDh^NP4)cb`8u3^5s2a|=nKPyaxCieN>oFmA#tV5#h`K5L@H4PSsmy&OI<PKdG1&ILisCs=y=g+*3XaI)',
    b'-u1din7ylZk1%`J?ml4(SMVNT_O9c7(o?vaC!MxVkmeEWCsQ3jK|w2D49K3Bp6~XTgmK^yWZikFKtI+#PJ|7(<`nQR%<mINfG)He',
    b'ear?E$FM{o%q*GH58${C5%6+xYJITl;0jOKIXsX9Imhk-gPZp*Fgv?=fV371wzP*Fy5pm`N(5WFfYy-lk-%>7P)re~eyZbd&ag)O',
    b'^6XoZtKqxji|?RnRC6c)4R>4DvG2)5E?uDSG8AC**9XSKE1gBCVNO&G8*XN`+Bo2D^e@h53yyv#kh(GYQs6WD)^OIs9^X;+^4rdR',
    b';y0>)5pHl`aNGEe?A&qIIm7EFS=A<Jnl=#jcRKtAHVWZn@0T*W^ZG&VWy)u8*tcQq6aq>WB{2<}AE`%}n59|nr0t~La6bRAynBDa',
    b'k(pZGXvhdW7{3mDLi*vZaNxNXA`o7dMdI+bxQ7r_?avVLNy}3qm6=f%z^pX`k28mrGa%{^FR6hH+|t_~XyNrS<DmP1o!(nl562*w',
    b'Waxi!UtcEz8)h{sq<s2-gVoC1{m1#n-47gV{KU5OnLr3TU-^wEpE5qDz+|W{jGRYLy~9+d><<%=uC;jK?z(SG9CpI;PmHMbLj=&D',
    b'yht!|ADTY+1VR8~+uvM`M&0@{oF(Ow7q!MNb=%@FfoKp4cB+kq;qIgu8s0#c;Yj!cO{>U=Z_r*U%ZUEqE1|mx!9tp&+TTY}`pmg_',
    b's(fZgFNH5kGf+t$YA^eg1cZjyivv!n2PoEUzEcd9^k8uGv7g-tImvHrds-o=5>Mewuvo2~xxC(Z^oWd_Sj;Z&Yn4>0R;?I~*S6ne',
    b'&uKL}^ZUDM^L$APdp{YC%$AC#Z#L+<zWOjb{G3tj(WdIq=Q_`Dq-I|c9gb}6#@O2AAAy4RLnX`@eKlQTosR+_-ujwkP#ucynhgTr',
    b'rvrN&h)PH@r*&UmaD$IRsYv<nV1ZwjR!9LttSRMg;fm&4N4O;MSd5CsRKJgk>>IrM=(j^Mg~_}z5U*L?ejs~Yl5%WG@d{D$07wb$',
    b'?e#Tc>42D@*^c0^y-`a2>^T8tXu=MR;ed(gd^F%>?^fyE6lCrF8oA%^_M5ee{Zq3%FPs!hLS5>UCDtw~+E3*StDiR4PdkQ9k^RRX',
    b'!VgL#`!NnV`*u0W0eI8Y%sn3FATFclIoRu;NBTdH^nV`dz>zLn7e4-}u8;nwJJ^j0{PS%0I@>|Pu<$#L<~Eo2|C&P|48Pgt)c454',
    b'{*lgn2PW1N-_hrP$$2jv%+PsmoZsX$_~-fjCp({M^|+6JF!#g$=}zPUbKofc=g|vYs~vLmf7`wKZvDXwRu(7gUA2CP?nJ&vx!e(}',
    b'<=nqo8#{ez(I@RdJ(N$SzNXdeSIlv9;<CY*5m${FW5luY@zL;NOh-n=Dyi_5T(ruOs!oXfzx+i=oI{4{*I43{U+G^7Z^-EkpFHVl',
    b'^w_!pr~gGKX`%Xnss2d&fv8TA5lHlJgIolmGxwaTcqTJC+un`%sm<0{e)k0k_Yl#6yv?Bk!JkX`OSe(Vv0?sPgahfulNqVx@}ri|',
    b'j`AVQP;5`55TBkRro=cFY1EH9x8vQz0&&;xA3ig%tfDrZo%D6Ao*!c6uAjcQa;_>ySLkj=^lqmn&JX75rakN@hW_i2v=U01hBKg>',
    b'25flJ+GzT#qLpb4ez#G>h0oX-%#%>OB1uHaljv`W_GKoet@T85LnV|UmeQ<&!n@gvwaDG=tvDDc?;`{VYA5jR>+P8!`cHO5`X-cK',
    b'U`{QgsTOr(O(<h1*L5FbH$>=b1SR^iJaeTjL|aJV?lDz*8`PNeicRnfDgTm$Z5E(x+A}zXugEKP{0~a&V$#Dm2@8*h=Ho~>fmo+9',
    b'upF63kQZr@q8&h#Sz2~k9!{Ey0>SsyeNR8dh{W0c`LaXJhvo{=Ow7;+qh5{mkvEoAd04kW)HP{{$&(ftO4>H4P?aY^kk+WkQQibm',
    b')5iEyods20Bx#dZNt$<<xth^8`a90Ws6{hYdWI5EWgul_IS5_6NHEcGwwglUAnS@YDf6HUgDecAvP+U8%Bl!8MO~+H*`;Y722I&y',
    b'5z3>cs`9#t+AisWIIZezl)eu;)$PbHF};G&x2yXbR*L(rXrVj`k?YL%E&Ovw;9VZYNm|8OjM^;CgCs1{tj@EnExM+OTa?C8T@_JW',
    b'l@V4hQ5K|W+*Vne7AV30-;GjxuQS^^?}YcBYK>e0EZc;F&-i#d@Ys$ROcRGK{Depy+E8j9PL_D#18Y#*GC@E50BU%Nc{Ef#R&nTm',
    b'--#C<Y-|S?_>O5NKJiwz{CMHxBC?$v0(9d(b)p3yfFr$v$%n_0i&+>*CISWBKKdGyh^qD%=uRoAFu3SwxrO0XpJ=VB?!Ya>7!x3o',
    b'e5=5e==2u&Pg;{{50e@0>Puw)oAL@)`khrpm*f@15OUi{mn8<U6Z?H;6!^&&_ZtpCOA2Sb%1z@hX#@1^WxHg5TQyaSEH~_qel+iq',
    b'?05T>RG6bKR`=@$Z~Eq{Vk|rHw#mj(u7K*$&I=019;-fB?dgK7t|#42hVH&s6Vb!6rASguMs7*?Rn|sRH0cDP4qr~nI;pb?tHybr',
    b'1w~hPX@iOsYj0szr*+xZVG<P~zNoZu9pXO_MY;`wvL4m#_B*x7nzJ}yw@2f6_uOJT4-Ox1QwvnuaUmG6E%z;xrd3~*NPIrE?M!_!',
    b'+*{aN6bU@T&@P9rst@#$JHhV|G~O38BCQZsDz7SHPaI;`ep_DOU!PNBCT#oF%(_IxTyNeTZI<uo+p>Pj@LX>1?}%+Q4y7Y($dQW?',
    b'C+2BlMLm=e+#z>wpKHe>SFr0;b<|Q&^OAaJoER${F`o5d48myA2j8j}59FM8mcAJG#fw8#Nz^<xB{Qspcntnl5oOO^HNrRA=}L=o',
    b'@^pL<-^A^T`idpzz;B7R^bOx1)XTuzQ(uGlz`PlA52p&B_(G!DV%CFH;lbXNiBU~T??cINcgR6ujt>Z9^S?gT<Po?DhFB>KsP71t',
    b'+>n!>U0zpL-D-V}+QUIKvhKEwA7CJp(Ph7}OdR}3n3xWnd=s;xME$KxqACrlm=KBUcW3yf^&2~5msj`eA&dp|Z~4*7^k7}q_chu4',
    b'J#c6zixc3ax>?;UG3U{fYZzysjLHyOQXQr?+i?RCJe_JP&MN0f$1coLWc?RF1i3UxO~b#%D<ubw5>eECxT&s}jmSi!u6*2NMS-G%',
    b'<^oZ^R7qO20aERdMyn=on<frQ;7is<X^TpC|DZ^UHVI?%OWmYpTI8|2KMLctYNAp-oRujXeZm4|Sx~0Xz91w&;&S5aS(Z>ekem@z',
    b'4Q!c5nQClt<h>Cjpw8VORv4>v_lO5{J~4)mBMpe?c8eL8JvS#kPSElyjt(VQS~o-H(nFWSkb)yH=suQ@e|{=YY4!-y3DhA-P6DYN',
    b'CK@K_7aWMK$7dA#|3K^2Yut_~wQSn7t2`SU0GPq7nG3MUlj%+FcffCH82OC{vhDQoia?7Tp2}HFQa!dD4Jyt>l_V%?qVWw;X7&w{',
    b'C4bO{zyp738=}lSHv}f=wi|+WwQh(9WtgBz+bpfKafS)m(elwbrdzHzchfnBc6$x6jReq#Z4^KN@7NYw?l;0zlUKM8aYxPSrhV0Q',
    b'8$=#eP(G5z^_U%SB(dxL0N5@qrNQ+X#?d}!XkC682PXuO6J+2%te}FLzza%8om2`P4a(UCj?(W7+z<bsJkVBBNZuS%0oW1x2x3hm',
    b'j(UHXGL+EwS&ko~?4Mkr>PG7~;vCRB!x7l>?ZB$}n=(7kld1}{hA10=IF=q}6qGA<(L8||&U?M8z6Tj<qM$bQsHjN0vZ%nI6ZrCK',
    b'a-L<TPiJ8kP{r$DE4DIeE2aURhhD<dpuTMv0Vmn^o$=v3_j!?H>z)Op-6s+D_Zhm{Ab`GUmShF0Lx{d36yZqiRnf5GDVWv=&oU!;',
    b'hWjB<8COMJh51$tNGS$viizA)?8H11dzb2_!Fy;*_oyg#=^jVHPTf<AeCXZ27~SOa>EhX}umzg^97hiDj6*wtwBt3-=HlH#S7Anm',
    b'9#LXN0)Ah)B$!P$>Gc5BhmP&=G(ZdOC!<)}Cg6ieJ|SMYnz6&-Ff86!5$VbIX&06q3R?Z82^$tSxfF(Vy8ek>Vc;BM+6#Mvt(bmm',
    b'xap{-&@Y>E#hwH1yA`CWYkK7)J{Z36k<*Nm#87m7R*xZ~u7I{;3o*61-T2yT>+1a6M9|rnq4E^C`9C5)N{@N+797$SwAWu||07-$',
    b'#i46~WnI~^&giBcTV&{o6`3IJsxGW;e`3ipu*wo&h;Yxx_zz#pogdG>_+n`@3H-SHiJmUD5sVE*3W~ecWz{2WI<BpOFFobB)7_SN',
    b'pdnf~yO~%%zF-#yRX3DzAba}!^#6WO%4NKKb$NXLx9?w^zI=0`lSxGd6F31+eH-XkFHbLjcy<146l|PLhI{<%+4<?k#U#+w7dcQ*',
    b'olpOfQ*Q=5VVr~|nfc}M%V(G0pS^rz8kG!8v%-ZbI1d0-u31jUlws+&USSYCB(CHBdN?S<m7!<z?npcL)medVS_N@o6ITyIY34*7',
    b'l6#ETt<oo9$P{HL?FhAKJlfInk4dMS7>^!uVjRnHMnimFSMShCMYG|Ov;lqQ9#M=p>Osy#fnE{KQ{B?Q*{zNVE>>5+QlZb_9=*q>',
    b'6IvhPUp2``nmw6?uw&Ke&&)j4`ojgfu5PI5qrv3&s5|i2eomxeH2X^VJM|{YKO{EJ<p@VKPX+sPEd4o?{+#zGmohX+fCOwC8hQb5',
    b'p3*1>rKvuHXvB0x4Mu9N0uNU*d232Feyf*xVRKo#9nb0p!mQJeH2W8<BC15YWH?GU9@b5I);$D!c;9pkN=c)PYRw*RwI5!Mo^Yjm',
    b'aD7@0W)MP$<}&vXMD_p$9>I)np7+(&@%r68sb;?UPN}0jAw)_%-`?EUhkA%oGT&cBRkEN%sZD`N5XeKWmcF~%R~1PR6kEoZp1yO}',
    b'xd(`C*GV{V9T*%s1hH9H)fM;0YcTU6&igngTilR=9*-E(Vy~*r>c)zXV|OrAdB_g|Vg&q9$ivR~{ou<lXBV%Z{oAAG%Ld(S&?6Rp',
    b'+%3`itJ#aQHwU-t>fLoU+pO@RjSuSCe+EazQCL1cI9OhjnD^P|M_+=kbuNC!B)D7Md{b@E5$^u^<DtjVm-xS0^f7y|_QQIKDRDft',
    b'!#7hqobV2K{$I}i^=5^SYcwO7jFwmE(dq_M7k@|Wr3Jk&Vm8~%!bi!Md7nCftXGZJoA=9G61H`V?{6e?!R-BVL+b@~nE5wH2Ush(',
    b'TjM{@+;8jzy=KeJY?Pp!9q@AB2+rgXU$0lUs|}J)PM*MI!@}k<zDh+z#UO=GXYvMx#YdjC=GzR>ip7M>EkuB-+JcAPtHWi9AmQH-',
    b'CNB*Px28x?a}hB84O4W3C;nn3KQCdQHq{k6VV^G=qBQENALoLz>+Acwish_2<r6lCA<uDMW6p0rm}B)R8s5CeQ+&U=YTY>;csV7Y',
    b'QFY4^VM7@WrPyDxv_PT<wy)J*c$Op<oPGNK{OmxAEe81JxM|Ss-5<|4o8`M3d5U{snCkxS{R;2<59|qmF$t^)G{_i}qS7AUEr0`_',
    b'5UawS1|5HdzUQdB-~2BmZ~v9OCsFs2i+|l~)8fPbYI!qd(bi-INa(74#pGwl53?ck^>AmKfm$6KYwW*<Yka1ezi!@FYxKOT(UlJM',
    b'kKH-PcUXkg_hc$Gt>DS~>gL_P7lchyw7EgQ(xIjhmqEbtU+XEBx>94J-E<w8RZwTY(*D&g#~<rD*UP(!{5=qgXx;i{x|cEB{y{aZ',
    b'3pglTVs6(|f9anIV|GEy+dEiBxTT|ADw69EAPuS3_k2a;+}Xn>LCynC>wB!ualy{sOOvI48v=JhNo+p0V)oc%8d-fZJ1+Sn!C@0U',
    b'_EA0_`zjxgt;)w^omlVsE%6xEkHmZC`<pvw3n6fUmWs;vctquUJVE7q461w#pF#0+qTQ>1IxKuQz9#0)lj?qBB25@Zdu4_1d)L+a',
    b'gP?<QW8^$1A5bs)+Xu*aMAkoc%6d1;92>kzk*px>M1OH(C98#nJl-Q`FQ1*g{M+S=<MY3to=XoCch8UX*l*;MS1;e3zk2@s^!)PT',
    b'`Kvb)3WE*e^NTm<r^hcYkI&znUA(!3x}LtF-7nvUpU*u<{`UCf_}S^?QTc1GzVDPF<-X##XRlrypS@H_pP(!&yE;#ru+7`LYQne-',
    b'x~^^7x~t<V$bukgNNykeIZLxF%cHtVn!JpQvdij@%fajF_Lg{ag%p1B6q1R99pkdOU$5~lRbHS1K;)mWfU$s;;0hVb?%fmMa^d#l',
    b'Pck%l6Ko~`6Tb+FiGQ+f*ZJJEz$)Voja38$2VmGNLPe*+IW<FkzY!bMyW^V=x2S!#e20jo<d@aY4gh_8fezzX*7RQz&Cp6d?#8pN',
    b'p*VLrr%^^H0#L36z^yxfTm6F8H$<a6{S7tuB#7*t@zdpEG)>A-aMaeg&jK*x6$ESzow;I$JRQfEQ1;2S3|3IR#ml<-KuoCQr7=07',
    b'FAvld{G%o#)vxI!5%~wA21V4Ex{@B|So@&Ohe9^zqBi(klZYhkG(IgZX}yGhC(o0KOdOn~%s*k+R^2K54(BuU+a007mF_p>DQeC1',
    b'wCZUFTXfyY_Uxnb#J%RAAv{jQllh2j<tN0-NYr4W>*0X_&Jqod7mknLxIUh6KUqJA9(_1tla_JlNI?=#M+8vdvY)Hc|4?HzV0!9@',
    b'Z)_h<)DJYyz-67DAIZtvC-wbihrTCDUp+yR&LFkMf;xi?qN86;H6UPrOKM5>+{j)1xO_;Hf@h#68Up46Peo3RMG^$-2{jz(GF%2E',
    b'poBvUNC8}UsA!%GI*i^UK5;F#CBRxA*@>sA49HT+em8gD>5WULDXy4_Q<qd=unQz?tmyv;IxYJNs0hm#a*XElpJ0LwS<!|}JeXD>',
    b'Axr{{u01F9k74wa@Gw%(l)lW6J%cD?)jK4W0vQITF~A3E9E+yn|0v`BlhXDpUFB2T{y2>DlN7i~@cuFQX*Pt@h~QI^Tbf?1<+>xR',
    b'Pw46+5!2`xxjIT#3A1PHL{l?bnB5cF-OLrEw@c-Ara_4{${<`s0R^=)w>iyCjPk8XQMh|THWw2}=?kQ{$N+2*$kcLL$asg)o7oIa',
    b'P%~eH8`>$Miba1<nz~J$8_|sDRwlHV0UKj<jv{H-p2b#QXrZrR!s7sye<|(QtCFpx+ZHlOkPyst4?4}{2Il!^el?uvYA$`i7p^vd',
    b'w%2%Dz^!d-YIv;WhLokobQ{A`yf-!yC%sjvlZ-v~<vx-VUAd4y_QrgnI;ch`(sRGLF`T7U1~*hg2uo#y-=u$}h)Jw&wLXiDGz7%x',
    b'Ip|>HmSb#=?$}1-%~aMK&^S^(p4vy)@u@Wu25)Nv$Y?&s?=GLj7Uu+bX?7d{N8>&b;3g*I%*Q~`@b~EW=nB-wKnnIWnQP0QzYmQC',
    b'Zsy+A%|Vu^!@-~^EPAhQu09;v((`g(of3ZnT)uvcu#PDrLM^6DEww&(9ItMUWLfYw{BZ|Bng{X~p7(l5F8Cl&7Aa}|&K=;}f3TXi',
    b'0DE8`LOd9q4nw6{*ZAVuB37Ba(bo=KGL0B63y9@#fF=@6oJeGqaU|ktn~5y+wb|3m;)yehEi?OddH23uSHJqr?P2DUOq@&NWH)s;',
    b'e@t%6C(a|c%wuELN;2wf+D-o2Yj1uUNL_h;L0<WZJasTWHYq|~RMmQlKdm9N^0HEzib2=*lxwh(Uajs9=L}vyhZPr>Q~Vd2Pux22',
    b'_3i2gA78{ZxYM|!KJVve-=3cQ`^j^XzVyZGS1(Ur%5HBvX3Uwh7n-<yI>Ufx!*cnKngD|ioa8+qzhmub9ppN@?5V$0)=WGXIvjX<',
    b'ZmqJ&jNT7~rll&anFORqIBbe2CMhWvjy4HGL56pqqfLXdDl2kln<Oo|JV33hO<z2~(I!iqqRaApZmF)`lYT$1H7u@bY8heoIp}Q!',
    b'wV7Pe3n+`4d$c6F?Phtm`~{J4z(?V1aFB~fIy1cN6ulz`tVO@f&hBRKtIh0YH3UH}X7n0zg~UyAF}qs5TS(%1y{hq#t2G_Gu9}~*',
    b'z-P6Go$o8yYY6fHiDAaEQC?dd7`p0M=L7!wV!g%)0Z)|rSEl00D(-eAvH=6VURNK;^PD%U)pJtxvyZj7<-dOrk6-DNzIub!zli6@',
    b'Mml@@C<6a)tLr5`NHru02yxYYQEh(Kf*nQt!U?+{eM^j^O4!+00L1y~*Uj7LNWl4Fd3S@E34{2R{mG+_jp(bmW-e~3+s*scogBa+',
    b'elr8yu6l<&VP{+1<Ql!AM6QhMun5B&@*tCN8<QHs=+dKP4%2@UiRaBGoHQ_+?7`9B(FZe`LuHA>Q5<h_8y5GYMf%au?pIB7f4f9_',
    b'6kuxx3hD8)r?;!-J^X2i?(vBsq+uUeVS<7PvnUOM994N7bOoyGJj;t9X%Q-_Aa0YcL_rltSsrF}R->vaqa@0^HX_2k#s7ZnIrQ<#',
    b'-|_H&J3CQEFYBUCx;zWYI;hjC>B=lisyb_{0u^<Kf+9=8E{nsqt-7dgDtxdNVU;vp5mhOQeMf(G`ug<cv(uL+{|-g-#dVN3QCS9M',
    b'5=2RoL|u|bs7tycse=j++>~Jxhegn0`UFjs)M4GmUDh^jP_#umg2ly~SLdh9ZGHUB8K%NZtgK<(?YrZP?-V?OG6+zN55=OYld=v=',
    b'L}r@Ss4L>QEt9qk@gmeImfmfWw*@9f(<EWlMks6Al4pkKv)$@=oWJ@34}S6Y8BN*hw{j=Pw6+1!cTfNA4Me;us5;aIQG@abQ!y-(',
    b's>zbF%-SG~QdE>(juAz16m(tQqO>mKuFd1JuB$feg0U#n*Uyh%0*uo(bwY$K=FY5%g0u>nAP&PcYs;dpg1oCyn^h=46;?3HysXM1',
    b'$;!NLgBr6{I5z6(+cUx~r<bQM-=02y_4*W=d5Ae93-dTlE3D$>6=vZ!PV+K~yCMuw7$qqxON2K}(N$3wlwn#nO;*)d!OFWlAHjiZ',
    b'_-~J&pFLx%@aFvZ<;BVQ*=zi3q@mKZaoM3XNHE`GlA{<?H?Q+3XaiKXNg8B1rcm0%P1s@y-o{~`U@fj~;=F7MKU5q6u@UA)yh);}',
    b's@pn^(=JNmFv9FvVbXVbmo!aV;muN4T~}hQBS<inqBu*ls0^{F@k8M38MqF4fElgI;-Jo(vJFv{;%!1goZ}p?Kv)JTiNnQ&Ny+w2',
    b'@fOERfRZ9iVidQXXJ|0yf^)VG01kMps7`|-s*|Ej!UWSkXxq4Hx;W43G^&HF>*^e9vU!bvse&XXBCNr}Hq6t}T_7>R`RU0i;Q#=M',
    b'Aj--%F4~Al(6Ydsm`8Y!DopaUD~bZsysm>N$dV)u(=Z~j%W+esc~;bzVa5n?etPl!^Ebd|L_t#HiDFhqMbZT%+PuRwj`7aJX9lYC',
    b'w9HY|Vhug6lcvluRq&qeO1vTP#;MbhanG>qc?nLqL`_<UC@3q0r_$98s>%Qll-779unY`HgnZVNMU)j`7&c`S<HN4*!ZfME3?(B2',
    b'zxw9l^!zO)`vo+7n-+0eVrDNYEaxIj-v$*erg4*#K=3F_Qp{u#K0ok^bY&Ic!!>O)EUU8?w-5a24Gdghkrvl+(q<`Y%CbdmRCZCD',
    b'7YRN^>#%FWs6<Iv;<1CMEV?*K@UDonqDmvoo!Q91C*Pl+6N;0HHlXCof}$=1d^TYzLn;O1&DNE8XXTjL3KRwvmj7WMHTX&vCit9g',
    b'6HJx}|Gf<`3F>5Y;#lhcyM6ektAnz`+})&jy<;NyGCW_r^H7DC8*2@C`xRYRq-})xtxChPDq?&DU`d3J*n%tO!^0dl{_<Mfp(=3=',
    b'gAoN9sw$`*GLq9CybZ_TYt7YB#?hkpm4^EYZtn19@H>y*W_YnHh<tc&#Yu4qy&u!a1jKD?Qw5+{h~XFyp8u5Sa94T6Va96lEt;#x',
    b'nDIykBiu))fC<$`fpOR)6j1@tJTxXnETc>*-qw?4_Cz8d@V&1v`2-;4&|V`5$w{RV(b`rT!A4dSFPMB1k{0?7kW9Mb-T<+kk)am5',
    b'$}W-l+8uG5;U|RX525)J$2ed8N^C1*gRsa{F^ahOOdYJZ#vRT_VoIdJhO=Ya(FFh5N3}1b<v^N-$*H;@d}goX0iJU^VX+HUoX6-i',
    b'tezQL)kPpXO3)#@6*f>6_iYf`!e?MNuK>3Ct5x&!QS-i9-Yi@5vr>h1<a1xBa$(1aNinkllR$?dFouv4<`?r>$(ViH@kT{C<{Y0+',
    b'tdrEZd9;BYlKa#$+q*1TW^0qh;q}N8ydGno8+BJur^p9*75c<;QoPQwInlv>-lwPI)?(m61hI8f_s-bE#v_mHckYK3902n%$Os=d',
    b'KMy5qtLEp$3@D*06}82Go9~ji^XV+7saSin;a~c*6|dLq>#qqgp2*y%(yQh@p?(tq+po?eO)n@GNnVs8u^>=^<!Xs{!u#r0N{<Ir',
    b'6JGuL9i@e<5oZ~16b=D51dBB#q<eLPz9j*|a~e=8=1AQt)EzPmV+Gx(tXwrTJK$ot(6EY!WW>1<Nh-#AwO+ns`4xE1>>*LCjGv^u',
    b'4p3(!DF_8?4f#hdhMbiHn1xK6IY9HbQvQ<7{neeD_zG+*xp<lgt$t3QebykDNXPPejc~_z$e#n00q)k-&8Ar|Z)phe@HbkP65=~y',
    b'$sd{yshltI3cb;Phk%gnJODWAYu*|_efF^KXEo&ch|zj6Gf-KWn2Z;57Hqx}$#^(RUMfEv`m7F16@=KTY@-C(OtTA3=TUftGtg1*',
    b'!!(aZ(PU5-n6KGmhnX6Ik!cx9Fr<>xgfdX4hsPc45)xd25PN05B^b8bw}Y~h<k~YO&<<2ChCKa@4L*C~ps|!i$z}LZbE--zh;YFV',
    b'HO7Y{TjV6t<<HXSBT4E(_QNupk2~l}#<1q&9bg~{BGD{xV^I50_s8J8Tg*bvzVa?m`AzIYb*=TK;KJKX5$^8h$StmR9QbOGOY;Ri',
    b'HCw_1h$LPoHi&^VDuDiU>4#kOE89N|gLqIqqcAx|iDpUsP_0g7+rH%>+oSL@PLgc|`l$TYM_Y)&ATdp%jCw|~XtXNFnDGJw=kyme',
    b'g@-_<k#Z~xeCG`JqhVG1%z2KB#zzQ>-SKw0=U`b))%~PzP>ymgUN@cI^}y><Q2a=8dVcci2_Q_(LFp-3lx+~qNF~FoAiA!3hz~iA',
    b'X!?IcA0S`)zd%NRqeqY7XMkB<?$N6yst>|7h!Krt`V?$b@gKxS&v6HcfFQp$6KC-jh&aJa$7;y_V>*4zHrvd4jqH%g*Xb}h1F`qO',
    b'=uR>~`ojRcA)i6+5C{e@mJx_Qb9==gY2;Ef^as%C2JhfeU!5jbNH8Gb0xTI(dqTr|$C>GpRKehHlP9Rui&;QVL{?+DpYC2q2!|15',
    b'F4^lCkvYb|<JOTT4G~+Qi-q1V&0;nou#O{esQ`Ee!iPt>PoKO}pl}2i@IvV2;x%tNLm05^AsxS3J0cE^yEI=?>s?MB`?E3ktpD_^',
    b'm6``5<MvvOnbD9aHrv);8o@){+87(j=y1-G;q#v!YsCWj*LHP{SA~$-8a63Q%wJeuWYRvGdsiGY+00RMOl*!uinSN}Lfn$X(c#nf',
    b'=`6eqq6FHVKHdKxQpFrBr7Hng4}tJws5+WHouy&4<uG1oTIG#Y->nEdL8wL^3Bt%EbOX;Y`^%MP(>5%lTM9MP9?j>^cD;u<CP#yI',
    b'bLX8{b}M|{TXo;u-?UdUC4%kH{Qibzkf%U(BaTgqS>~p`S`}h_F^D2-p&hdtS>G9}Fh-F_okouC;cnfd-MVKBz54PL)Z-nep6u8^',
    b'Ul@fTr*toN>K+BVb(a^O*V&%ZJ=$gEqIk4-pCz2DP_*Xr6Rx=qfD%m-^o~`zA1Mty)Dn(F;rh=!{jKhE(^^EgcZBX!ks)$nTSZ38',
    b'3&qTDxA!$xxnPF}Z!+c=>8qJB%@=OOYfZ2>dE^Zu^m)i}LYqh@4D-_o(3?Y*S=325Y(nEMAHo&puRb?dQ1hoZON}sI*WiIrOzrOf',
    b'>eE}JBY|Ki?e;3Wydc9FHd4^>&&z~B@yVest4IkI{8krjRRncM3f|RaoL6<6l0Ua?n4r22=$RYXa!qV;XM!HY!U_j#;G=NRs~>AF',
    b'=}>u`ZKp*^XMn(AOT9&Ok9X_7mEs{f=eu;??$j5(%bj|M;ciq@G^WWj57W`!q`YCDK5I$JbZ3w8zrV)X&g0n^Uo7?G+A-R4oKhnP',
    b'_;A4kcN4n+`feuHTG~r-6zsZ}1P0q}CDA+Ujg&sE^GU6@Vs_DagxAN!q2YP6Bo2@h5kHhqP4Q%^F>AY8q^2Y|;8W!`KRgVp3%b9&',
    b'2O<KD|DwfTu+cnnBM4uD$YCfGgeI^cS(IIBp3z_Tpa~57tf#V%!$_S7I&Fr21~6wwk!gfm##I2?M;9O}J49A94H4~|3yfL6OMzs5',
    b'_L>~6B?nK9esTdJo|t>JGyBPFWSZ;&9+`gfqs8Dd1}GsFV)Iv_2X$}Q{WHhXt6nc7su&U=>O(v%f0P|$@f(bV<w?Pa{j2c>*lOfu',
    b'g6xxbMC;Krfo^icb;P%R^b<P<;J$k6<R`eDFccVqCH~2D_RMXOl%V(lMG$qzDr*9wCCesYhdZ39dT)4RPXJ(U=0N#A?9;$wDkSG7',
    b'T9Z<oCL|31?zrcFdYtoS{z&%wKCn<>*wW)rZ_sZdP3VxhhIF08HC97`HG<CJFQ29?N>NgG>w6^Yy!K<$Qx+Xe<XN9%)y1`=F$6Y_',
    b'ePZX>@L&Q{JsD-HCl+UqouU{AKPh)GeUF<W@L)%_{A}`r<q^{b^h{%7h#YrC|DZ?8J(T9|_XK4Nbso0T0B&Q@H)@5$u2B#ez;(G}',
    b';w<?hXE#UncXRay=y5OOvAZpzI!X`c5bipM{0Mx@xSrft?kDrP<Ek+L;#g6?f*t%E+|bHBObQwtA})T=zfAxGL@WMaYhwp%CafEm',
    b'%&e!D#?DG04L8zlF#~=SxX!orL8~gb&2Ydh0?>OGNd~xiX?Wfwv7gLO!#2}z<Juvlbs0_`t(Sf@0Wb7)yOyxGsJqgVSWw=T=R(3r',
    b'ds6^Ag!_B$B?e_=D>1;14aFMlxSez$d)Z7JsLV%0c-?nAhFEUdr&#pdbG)0Geo<Cpr$@qt*?iiVES)3Ob|w#&jt-^dg)~=8N(?y$',
    b'N!o`PSLtt1JNYi5{ID0Vn&r9Xr}=;Y$N)6F8{O0E0yu02Qf#cu<WQ0baow=g;3`wKU|P1<TVB=_(oeYd!1s$!lqZy2%=J`q+qaCv',
    b'^d`L>gml&U-1=OrPa`{l0zi7Rhai9!a}uW09#I0?wwn&!@;B5{Sz+)LZ9*#2;C(+}<l-~{K6$$|h0|VF4VIvXO7=io9I+G{Zb>ta',
    b'&#mz&jQK*Ng7(&3TapAOXn$v04a(<+&3ky@Pr~~ue8=k}dD#d&TlQ7;Zeu)Sm%uS-(koJ#xFC-cSu%;orQC&HZ<dwxlI9}F2rfX%',
    b'NE=?Ix+0@Y$nyU6T_QsVWZf8<NSFjUW0icF{qqIUCZuiTY1yAVh&~bRV@}>|$sRt)%Qg-@p?#!d!Dx}v779Jb!Dh6RoI1j2lC!5Q',
    b'5KE84FXn@uCQG}~w;cjNIlMzrzAF)zHk+2Vr~!yfX7BoamJGc^4HNQF3A}V-@qIBsigZYY8U*PLC>{V&sp3I{g!7(sESil{h)~I1',
    b'jC7`)dk~G$*t&B|=-802-Xg*Q(LLy!?bHL$SRo*d?TCEc=?DaKJke|4NBA_{F<sxr^Fb(UGn4PGQq&JwDw0fn%vfyX+1W2YYR23H',
    b'by5zV^h+P4#SiM&8vX<Wx{K(~G#+o4jH=OId3;Sys>u)15^K0^wZR&6ef42>_&FoUqfOPJ&vh5I+I{xblb#4<vICZ@uG^ryIq*(N',
    b'<PH#?rPpfwDE?<GVwk=fQSp#GRVuvwysgrfyIQ}atU~x+%=pLTtDhd*vvvvYKNejNdmxtRd0I71SnQ}e0$e-=c(u02mZcZ@U`kon',
    b'$NMb9$OjNboHkNMSYF*u?8W7VoSQGJYxG$ABy6PLpP%WUFnXKS4f!xI8>8Gpozy}?LCzf`4ZDyBS`47)s>M`Gh1{>GT>5UY<$5gk',
    b'Kyoh3MD;-Z-+pSnLc8IW8RkE%(F~N7zgV8C_lEnw{AG41=&nET(|><DD=xz_>R$mLO3O6YJKI}4osqcIzKOKF79day4CFFMin+)9',
    b'22DjwXzuUd{cMa_pN-D<v(d@WH#FAA)`tVnYqQ_daia(;tLtUo`*r_``yK){cEZc_QN1TZve5WP2jS*+w~J|A+W+$@Ge_W`Cv^_2',
    b'6^>>}+}0+pl||)8ycsO}_&`gkrKZ9Hi_&-{-J>4b11PGFOQzr_lJSfFg<Qe;udxW=oAtrG3oRPP8R|Dg_6gX9=#ciH^)H$AOAZdA',
    b'w<`4h_!7fEmBxI6pN2n&Kg})g{ig=r=)0}&2(IT4t!cB>I-)S$t0Av|w&ElZ&NH_F<3;7HQO-QxU=F3(uqLkq!=(hB>|;s05lre~',
    b'T_LaWp78Ph(2y%2`QiS}ImS(R<aTY5pB_0L@v(Z3wvwHPiy8Zm^}?{QUl<lMm-;?>b0=3kb+`SQ)qJ`JLt;W`xm5bdD(PQm@$4(|',
    b'n8<wEvDhjCJX}D~2vr06UsvodX`lcbSHrB?PvvkxN+C7+nIx%xkBEiw8zPq9EUythTd!{q9Z#FgbfWuyRBr4&N1ju*^|pS7zSz;Y',
    b'uq4t>?BRdzM>9pOmsJK+?FNfnOP51RWPW~GA84|-nQ~L`m8LT8kISD1iJ=b52E`4Is-{`pOLkOZhMx6b*Q+bM6}#$cgQQ<K@2fR>',
    b'Ue)O8tOYd?O<DmAeyGb6o5;}gTK#hj$|wH>ypTvd*y4c<C=5f3o~yS_0fkp@les4<tHZ{RArs7Y;F4NRm)Z~QUYl3hZY)17obP7`',
    b'DQkNS{HG6lvbgMf-y?HKs?RMA*J(C*Lj$`fRQ5t!fLeXbG(K}YYoy{_wu~XC{F#qDq5}F9R=BF$-Uq7ct9Q@?@X7m7L-W78kPgGi',
    b'SclO#)Oh{?uT4OG3wXG%-a^EC2VUm>_)f24$nMp50wO5}p*>iiX5Jh|nmrK}eY7z~#FxWaWOG3IW-#bG4DQ1+o0!8uXby^KentI!',
    b'Gd(U@LXafj)YDR$05IEZjS#w_*`<h)YuOyH*VTv98wCYmK%PyVysrZw_BLIQ>81Mg^v={K(N3G%=#;cU_;l!5Yt#4$=4Ur8`VB*l',
    b'vd7Zjzn;Z3MMwXOt_1dU870R60(fY<+MXa1QMeiZO|`tzi89c_YQ`c!X!O6jA$AZ@+9KJGZD!z;-d3wbU6@LSW`8kNB3rDDv@vw4',
    b'$Cu!#Ku5>}`le9%<&juz%pH45Q94MF`x}#s1cAi3Uy^YR(Ls6&-=p~3;gBFM&8X<c*b}6`#6o31s59Q<n0-OU|AG(yFL;c{28-zg',
    b'p2qFaO^uEQUeWr7cj%g@+LK6#5e@PGmKf34+>#1Y>3~He%Q}hi=5zV*6iI9#U{mRDt^@ts3}G<`Ki!{%Do>qgd;2{Cix5_YSL_Hb',
    b'8b=SJ>QsvUKIX>LB&<b{=>lx#okmWUPe5We&b)mlUK(cbDabA15!ga-4Hd^AQ59~d_}t=K0V3O7fd7Jm`pfKp1cFL8mTi}If$`w@',
    b'Gub&^T~VbY8)@H?QRvG5f!3?nc!cH6JA?il0a2O<59*V8N`^T3497aa`fdSfrog!lo!$Sir%|J@*%^T0Sx<n1*~rwb?itlLSlGT|',
    b'*EdqLTnX&Mgb{Q;68n8Q*B%u9ZX7QR==2QE7Qv(zwgX}VX8TS&Zx#*S)^u)E7?!-g!hQeh_31gw{O{q&S2V=QPokzg=FD~X`eX>j',
    b'9?YpzYnW~GXcd5<*ob|e+42_(bDO-;YhFH_H%RvC>U=9or4LNVt3pTf1;ohHOD=k{qgR!|kIy|`Zz307`8h@aJ9x=xYb43{hOJtJ',
    b'7vtVFNA?%31mMFlFjJ~w&fPjQ)9kOa;J1MIukpV+dwyiIu<XN5lqh2RpK2Ig7FZqnY8J(paa7n|3t0+A{26ClUdBm5q7%x?B1t?=',
    b'uC%K5pCVXMQy0Zk04#9stE<WHIj*q2yjlJ?Rs1&h^`RJ@{B}539;1oow<}sek@UExx?%8JqB#%*lxB7N;gGk-uoiSEwJF1!0F#2p',
    b'L=UyOYRKaqZQ-u&;?#4OItreCcKaVyGsf=7OJ-Jezl}4(qS&2Dx!!&~JEX9v^?}%QoL99#)2r=VG3fuJdjIwP6~lpKMvnqQOrfvC',
    b'o2<_cJo#S5hB1D=X5wk`-D+og+UtC2moLxlw+qoN`$Am(IWs*K#F}E^HW^&FCcXIF?v?6UUWiIC5|98|SHIc~ElciUU@=>`<<qCL',
    b'Fbn)InteQp@T+pmB>^^fkm37cZxoR3?0cBMZiJjh1=^3!-7$6I&)nnOv*ZCLKgDya%$__zw@zOP*ikn81Wsp8a$UOXyLBob_rV}K',
    b'BddVtu9*p@o-iriz-vm|v1UIp#+%x7T(iM?;5O6g6MXp3ha2d(m=MNs!i>bun>Zu9!=}z?(*99qgmJXY==Xy!znopXe)eyVo-Z48',
    b'vq6totT8F${nhNn*_(sgb@lGLnr&A2vbwzcF#FHos5lDC#|H<?Yf^Z8_W9A5mc02?vD>^~-o6cwaR1M7pD*!n|9Z2+mjpDU=?<@`',
    b'9@x;@qK}psft$_p4$p_sZ!?R&jK562%zK?b>b1n#FTB|J5rf&HUuI`_v-j0zcC(uGDgMaWd{@<12&<Z_HN9M4t==u9dg$v_jelIN',
    b'DGoKM2fw+e1;~#MNTksktFkko^f|qNE@?t#z4-aX&v;gMm_wG#6MQzU`vKzzv|eMRfHfXm&>|rN;X}TnKrdcE^UZ4Yyjs6QJ-2e(',
    b'!kZ7bNOBkPK$+*<KCdZt_E7}>-&WVls}DMo1Vq&|==Kh^#4I7wwr}p%_n5wxM5X`Oy)eW6Dlm9dS1=QKLM3OFl%2}8g;T?lAo3r^',
    b'RklaT9LC6)Xf~0OBHB`h{T+QU9b0DVL$f=Os_?NIFrj1^)V?VR26s%L%SqcaJr~G$Yva4;&E1TZ^gTVld~tmK_tSGJBUSKQ9aUAB',
    b'bw!3y+{JZQ#c3ACSzY9HlQv0N234MBZB;~NUYB85XJwR@X`OT_{!f@c_8j{7<nKHOlRSEdp?7f{BxRj-agt!#w`E<GVO6(H5QRAk',
    b'!=}pHC@j)8FM})zf;LLhBuK*=rH$|C&rV;Tz9dC)|6SC=m9fZERFp|jMO7E3O%yhH+!h@sKvf`=Mr{(ed65KBmBn=xVnmv}Eb#A`',
    b'0%h5?;RqHNZ(g0BUY?&GKf65s<_uHe<=MBV7jG`VJHGf%!6PVx0L4jK6jhBW5|*e+nl7zTSHy8!CT)qyU)L#?;BAt(1#0j=Nm#WJ',
    b'%9^(18BluXtd7U|s~_;-7k?+oQhqD_Xb0ATR*<d&e6Q?+s6ly@W8xJ_)nu4&vNi}KLf9_Hh@v<Ox-M@~T9<Lx=5blqRU3A}7#gpi',
    b'AHM_`r)}zl2wN0XSrY|m6*NH{hJ<~Jx(f2HMr~H1099QclzCZ|MUr6-ZiBk+P&hWKwS=;aLs)fD7Upr9R;Y{est)QlPV+K~yCMuw',
    b'i1`$iC5n=$=&Gm-$}laPCadZqit{cX+dBLu=G)`vXV2Iwyg5I9d2w=n_8R{hX{a=9Ty`i864WJ_<S53}&Fef0+5nYpk_K6hDU>#G',
    b'6Si1_w{e&!2|{fX=Veojp>lF^`ufc=A;|gZ$*c2c5IK?>Pc1@0Sk!nuqNYlcu<0^Pl_ti-sFEyC>O8=UU!-{ZRzVtPUDXA7(v?J@',
    b'jNl+#l;@}4et&WN+<{0IqNqtRGnPf0rE!F}YSdviZQ`uRqArc9w5%db3=|`RW);+3o3>RLBUGkB8jm8P`$`oYP!>mZ8Wd5TV9^pL',
    b'crAjqjhm*6^Q=yzI>@@N&O5v;HU6av63jGF)#ODG=IQ9JkeC9~;goO$fJ6{wWg8c5RMli(V9v~=g2?+MPrIThk|?h0Ai`2LiNiFE',
    b'!Zyb!R%xCUHD;i01PLXxo-+9$sqsWH>!Tv+0(`dAU6SB=24z+wROe}#qp0n&Jg$?b%rRB)9>!b{rg$UO>BzWBE=gtJ5;bWZqM)o0',
    b'o=R6Ys44?IP+H@az%nt&!@A8dUqo3E;*+Ip;vmRtEcFw72%<3-1X6gZLMbicw2U!rD=haSOy33-Ev9jkH*JlD1wOcnFzTWPuSkb^',
    b'FwgR|&9LmwTHHSHqc<>cfkj+g#|dV4)Rbk5+NkUzdT8O(BJ7$lDp3-ac<dl5i!P3m5LI|PRB42{GaDHgN*1f`xS*)Z0H0M@>frMU',
    b's}XoLgC@-}vlS=|DtsP<dDLWi9wrsuVhJWog#X?Km;|F+A4t`z4BvEhP<EKRn-s5iOax(u=Zkk9s_=57pupR&=sK)JM3~>IG%Twk',
    b'#zz7cl=#RUlYSRxe|w2_h;P1s`RqA-5TLfLTdX&svTjRMM`T6o65#_JpEga~lt~d3O`b$uR>fEX;qN)-%PPW3M37Ycq99aWfxz-w',
    b'-0LcFHH0w*8mcO>9Wvrc9xt#SjoyZ1@U`aZDC1~J?kw(V{?4O!i}m!?2NEp(`l`BNJr3B@z#Dd*Sgj9@i$hO}OEYPpL8eR7ho(&x',
    b'fMOwrV?22NKnHWmmj`<Er4fEQ%vdeCLt+%o8IR|J*C}8^wNYRk_6SAHntK36ETc?vNA)(BCldL9?|tI_Cjcp>I7F2oBqU2CqP49w',
    b'f{m;uUNHG2BrWunauOMIojrkw4f`JJ5lhdDYW*{@_Z-e8YZT;qoSQCq?bf;-0vFADbX~a+VD@U_faK$bk0+0EzWS9|e8z?$;ReGv',
    b';yN~cxZYAI52pqT@_i}|H=H5ck0&_MKCXQ^El1N-Tu#-!;X?r<wgWozcEn>B$~X_zsdzmzwyujvcBG&~cT0TG4Vm5tZWZ1hrSW{{',
    b'#z|v000D_<-4!Us$#?gDxtWiAK5F<HF6<aFsRpOj4YR`#7(+-5^9%K#Otitzk7$q!aRZz|^A-Em@#(}mO^v5V8`vSaPcpN;%i3nP',
    b'HrX6rku1S0;!aqs?+og^`CwazKHw_+w4=T(yOaZ9o)8(~<L2if*Gtv>yb!Yz0+Y~rXmN}GwpAV`o-Akfbe0qK@US;-{$+44hV$9i',
    b'U$a<fnnla!F^=Zrq23(<8+@AsNAkI&zs%<(7gtNX7idK-M=Pvnd`D^FY9uO<`Jw>$N@$uPpvYnm(g8+Ia_LCF4Zzq_f=s3Egfy)=',
    b'KrN$Gl9Ox-Y@=9+cg{wwB#4={a?;v~0fxAKLU=vOALuPS1$TO&G0%T(1|S1K$VMCh44GODpgy}#_v0Q|ib>my;)|Jq%EH9NR*(62',
    b'gPE20K7=aj10c_xwPx=Kyh^s13WLqm>y>2Fk)?4cMlTNf*;daiCOoxJs5hw&lJ$+kd`mFubA)M7jF$@Il?>={#n}MJ5edFInHC4?',
    b'k@ZmIpEEi+(zS8@p76ezM-Je5a-a`sveZLgW$wYVM^o?78ObcHGK<(m+djk@c^TySC}&`bL8y=%SLU0Po-_+6Z|Pz<4TiLU3qfpa',
    b'eJ@#SqEcPW-Aa`y?YXUJDW%X3FXJTHMjDR_UwyQN7z~oJBn+u%6pJFMa*P>FFmO(PH&UM{LQEsY`3rpK4ELj9Rh9It77c%Me@mjn',
    b'HfQ1<B}z+37c0BrYqh!pF1b=yqO<ONu{+QVuOR%>^OG=3m45DLD?-Qo^JLfF;)>CG0(fB$ir=iSw0gvM>vItiWgh%WPszY*gJ1?S',
    b'8Ag85buE<<4ave9$GKEv_AOWs!RP^0r<Hz`dJIKzpNwS&v)7Y0O#C*g_zz;E=eR#&NJ>7WBN0dG7Kk{(Ovh@di)i{_%r@K1dX4Om',
    b'<*M2KFgXKJ*1te^lJ(CY2H>3d4DwD`s$ul?G$cd8AZg^9J@g0A2L|upQP-I!S4gZN;Q}lfQF}rIfybFidG|8q)ow7P?Hi`M*Ab)=',
    b'c`}#mb&SXyW8iUny1*$z#1`nT65QL<EVdN<BmV$*0)S_%wNjET%5g`@+#470KDT8VmLW=5c36(zj2!`qwju@AtC&3YXJg*d-Rp5n',
    b'*1dh_2iZ0o$Os<d-p1HSMu&42kp9(DsG?n6<5eMKwnkOT5))He=rw!Fo@5q}aAZ`_OELMheL4#-gD8P^r%(4j&y))Qkk-M5s-x-C',
    b'SsF%L4&#NURo+O|Gm5|ygleOaAdE~xx6cf-x8@lzH`#V+q2B8AXS?1*9BVcB$Qyxso=*ClZfCC0B#z60+~F^OnOT!|$fZoc>R%e5',
    b'!%;{&4_X^Ooh6rPl59(7`g&|YZf;4v4H%|q%05+`7_OTOiZw&nK4*Qc6hDp|iQk>agoSzFT;4vJcg+XzeP^sA8W|Jyi8;E5yLFFt',
    b'>z*z2H=R>Zk9VAUvSa^zVZ3*o(!JQJdlc-}U0!(p{B%n9XqT0X;?drHRcEfF@^qwHR`n>+L`v^6miv)JhC`OZNW4t_%+r%RF}0lG',
    b';@x-Zo2^T(92n)B^(wv#sL7b$h&K~g3%C)(vSM!{$s17UGqJWXj|6QZ9WCxUzP3`t#<@D~5+ht;{_0~I0Iyc`>aG#S%g!(mirs7a',
    b'zxwpn=tv;gNxS`>NL~={l&ybWCIk}9a#fCIdZAYT!{E2PMo|^k6-lo`UT-x;n~^_<aakvER?ssyFv~>|K(P!cNl}pIC}VkAx~NFY',
    b'hWt6G>LRP-)&(e$0cA}aMNwCi&RJGfIm%o5=OB*asI6Rpav2cDzo^S7C!LGD$cio{J%6jZplO1-r22piXxIBT^wt{IrC0;sDh9l{',
    b'q(0|yw%tWRI^F~hTdHKDd%Rost#m5UIp3x8b_$K?UGCI740ofNq6|)+d6<s&HnQ=C8B4_*1z;v#$7suON{#3ygK+@dP0V=UyO~&P',
    b'X)nc5u<KqD7;LwdMDMIOaQn2*C$-*+*+u6OULO;OhS%1TlY&PXbmXrOpFnUsljW2I8GJt6D2#`pGdtQ}-V71p$A8h{``Bn6xiy5d',
    b'i6KB7^up+q&;B|y3$@L@0&2av)K~+)?t&FF;ELo~D?7<VH@DYs=w|?Pb`;rcxNAiPpnY@!q5@=tjv+*}Z!Rz*C`T=-+e0!xdrj`-',
    b's<KUuesTdJuDpA-GyBPFWSUF_9+`gfqs0(&08oN`oOngBbE|dr$33UE1^4A<$1;!mel1Jen@F|QqX8U#aM&6eaE#@7VlnIX_YTQF',
    b'9!r1DVSnIWYEPS<`NTHZA^2fZxZem8qgQh0?976l-~jXeE`h%=l>E5cJF63mvwA=^Qm}&MrCCCBFBSQKrwJ1y(YVL=2R$Hdze<jg',
    b'U{`*Ou#d8yOmBlqaY7D9M@3JfUqWC2f8dVEs$>n<eoyZ&Evjnlp|Gk2oqITkaMw9xJLWv?dWK@r>GY~Qmbg=n)!dpqnu4E$yHC+w',
    b'rAWLXjNu3U+XOH`2;dL4Hg>RPlDP3>ll9b6$5{!a;YPYGX26dE*ZHoFUHuNlE=SO-5A_|DgL{TYJ`%&p95ie!{m!E41X`Ct5zu<+',
    b'ngZ~`OuyobtEajTE$RE@eRwWpinJRAutT`N=k8%pMm7%v?ASuA!Hye92eOy#!-2|tG(@R=$3t=DmVF{a&t1m5nMn@GIC|3K2|7bI',
    b'pEf2-n%L_p6HDcc4W(pXG*?VYzc>a-+J_id>2FXw`I4mkuovHn<<a7&8Hc}cJr3Pdkp8Dy=v>U0DZXAWT3J&_BjNf2-!DGFl2FPn',
    b'*Mq@rU-S*roAiPX(oW}d>$|5uS?dG}07=6hf&gZ%`ALKT^lLXAy5(=ErLw}{DcS^UJvVsY4;Z;P4S-Lc08Qbv*A*#_eyHT+vxVbI',
    b'5!OKZ4SsHo``YIVjSAX}Z*55un4tZgY&EEx8#eF7a1~g-yQ%OUt`CT1Bk-KmSJk_X@t9iz$Dkb!kH=-=f;>)S$s`_^G6H(N+*Oh`',
    b'nu{PKxBw|5ZFrUHii}zSHDZVT>$^mT4#>JOG7*n4Ib)S9l>I9J(I%vA<Z0Po4v0Px?PE^fY{}ja$jdekJ)wQ1W5H;V(iRFm$H8W_',
    b'lbk@oXp*xRArMQC!!PE8o+eAX(I*lDKsh|;P`)d1bvBcewx|J!OlI#&Dj4*=Lk$!1Q3<beV)1=3K#Fuog&OMS4JaM}QK{lVgM{;*',
    b'bS#>UQixDn1>c$#+YCAPAR42wb;nF>txbdjqWd2<&9A0`zL4f;L<6hhsy3pc%}_xW76a*m{4fRb%&KR{j;ALt020{#2xdUyt%mER',
    b'{O7s$B>*2{9BSop&(S;l|LYHO-1GJI>gMQTAoAPr$DfA0D)<L-;>tD!HJpnFXbW!GazOAj+5(b-I7XXI;K$%6)lk~kGB{b?Q)@15',
    b'chqz43p`K4OCc$zNXkYU-O;KV=^NSmuA4B*!;${6*}uP?5H-(syOFs<m=?&NhhcQ(TmC|9C2ZdUXf5QI{OV^#wN)g*E_sEN%`K14',
    b'J}84y3DZ{(I#kw|IPm_8|MwM9PyXN8;jntcmxz5))@Jyc$V0WJ!nmtQ*+!g%q;4;t$wJ{O6}Ci*1>>ECx<vC)zmJhi>SOtD<m^xO',
    b')1%?<j-c~Hf1C7pyVPfm_O$717P>j{6=q@$f%YsPsCGB%2=-XAB7#uGK#?*-xaD7~F}?Vou_$hu=0wFqa`UV3_Vb`nTkdN8?w-6x',
    b'C)-`j_{Zd{pB~$D#0dsI7F`c}AeI*mKSoJ^4zkMwAczI{?~EK0L!j_K%#E%bQ;$iB9+L5g|A@EKW_9!Z`I-9Q>5w781@mHPrXA1H',
    b'ybh(QaCKq92b*ipsf?RnkL%$ukd)HqGDwO8i+7(L4MUjWxJt(x+W=~(j^>CM2d|}zn#6>xxUICzRu_|Pc{E^qO1THZ|D8R$Q{&53',
    b'{+q^YlbOuUT_eo&z^n2{F2|?<aP0F*o7-zs|8sYC55xlo?B6vFLdH||rHW;ps{}PBFt<BlO<VK+pUjzgGygpKs8rR`J9Fr^9x|>#',
    b'^r*2_nHdpU59C<u=}LFoY|I3xE5&*wrQO<QCO4&SV569?Y&D#lVN1M1<ni6iWg`SttVoIG)AePxzG~V&TXik31fMkW1vJ=@$?~wf',
    b';HUXw2;2LsRMxeRCFcgnugq^T{|4Cf2Z()J455$pQ^sT$;gAf${uluexjjHz@C94Mg|seCEhF|KyR)F!o@s9-_+lnexsTyr%pk)E',
    b'-AEc?jE#_KaLFn#>KU*A#?D1=n9`1vDvZK%VhIu+Dj&wQ!5qpiWDVm5lYFQnJ>es585&HwTH}#PkhKuKV<|Hx#t`=kG4Qa1ZX(IH',
    b'x({o;nY(r0&&!S6@Q$RitU&X&57N1ieur*&f>`yP%&^x?!U9sxd{$%2DNxHP>|8H%66j@4{F9M(_e9DPDBHQ^?13BG^IBEHDP1sj',
    b'H(156jB;pbta4v0uZFCwYFATvR}0gdZ;@;V2SD@DHYw2NZheo&duBgb6MjQCqA8?={T!6NkFKfZd<Llnm}er)B7OY-U-AFGk~8}-',
    b'2*Z<d`W8$aEc*QL38VK^_QvoRy_w3<(%<xk)qY;2abS1&R$kxJ+X^{V?L;CDhg9#*CHpZiwJr6A=qIlvu&=Bc+oU``J4ni%!`lYS',
    b'GtHv*;10C$`?0#;9>UQ^<lK-n4y?W?%z7K?SPre1RY5yG{pluwX;y%TaTNAJLaSe0mH}o@xg{I6S>9sJ<LstIzisPp)74GT3&(y0',
    b'luY)a#cX}Gyg>_5NGE^-&juzXvC&8f-u^2&wfHA?L~%L*&o}5yE|By62E<i^gOa$iz-|nIxjF$>&Yd{59IjifJz7-`U#-@d=;!OI',
    b'xntk09@@t)^&H{~rl$8Ma&bA=^8jn($(h`OGCQ!E+*v}l<GX&C!_PRGu+se*p#b@}JUK8}X6SRM;OUn#)iD8R_F@BQw}ifxVCKH_',
    b'Hj(Qpa5#Z5qt2lP^(VWaE;_Rt?%nbl;mhsyEnZNq;kMIzGCDnlqqm*slTUx1I>SE5drU}F%OPo#k^)C#<J>&lLlH=@Z8?u@Y#Q=L',
    b'?hPT6CXtVYD^7xz_Q9F`*#%~MHh5W22;z)^oP<&_1SRs5TN{18$0sdn{?2`<+}oxZ`BYz&SfZhO<DGu4$bqK1dC+RcG6Q@qK&`fW',
    b'`t)r)uf1Y{w~QehCg<aM1@u0J6|Nc)?E_T}gLcpZ2zU0Oh8EiFLOKj5V;x50P-7d^-S@U5?8O#J<C8>6czDoF>lf@ozV#yvkyAw+',
    b'O?UI+LGd=mUDcnJbX|nNOwq<VeeziP``5E5Bk8;PUvyOE`LW<B!-XZ$Y5=2QDQ3+<P?fozKG|Wym)tr1rdnQ|-Y7`0F`(qgzfXw>',
    b'u`N;%Ovl@wf>8oRD-2}YYWOWl23jTmNtWNW@&Y`=sY;SP3M(ZUIQTxmH`5&uqAta4CIykk>JkX}Av0EGpl=H960t6!y+zDg#F0Nx',
    b'%m%Wm$rC^O_fOUSA|;<cfLsMoOzd9l)*YY9b5B*<0wCNK0AJRqD7H*wAvS$~y?V~C*tQX4JspGIlN*4jo7DI;B+gDVI@j4Fg3n&!',
    b'Z>57Dqfa)_7qdeHy)Wo^f0_M{m|tupnBYQ0*^=9(2l)@QUcJVO-ty+%uxTh_8d~I)X6sDasL4f5@-RbWyU>KVEQ&_lvl8{7+{9eC',
    b'_tieg^77xFiqVDiqJD4Xmq()Q*Rwd<?`mJc{Mr+Q5Bwz=SX<|-F|OQZBi-WVrtT*J9%48xOr3Rs@!<GBnoU(l**4(azaZ=O1xL>0',
    b'c6|wV=XRa`9DyrOZU-RRF3(~lQ>5Kh>$?Rc9v0^H-<^!qNViL2vy8jso&lxYWuU3cQB`z2A5ruUOY(k#%=s`_sP8B+VFaCz#C~7S',
    b'H6z;ZhMvZNvU&x32)9&gUjw0%vwau0G9KV;9W%mTU4l*>5eW9`_31gQF6I#fMyPhMb-suxcDP&%pqLJ!m~UG(dHYJq+ZfaV2-_Mh',
    b't#8PN3cs}Q?*oQG$sxQt-*R@8n2@Q(Bq$PM<mpw}J=xK#5c$XF9<PKk3$JvABY+*eG&L5&+oro1e-`L?0;v@me>etaH>GVQt|cT|',
    b'O?E0aLhxG<j})Z9O~QRth*<slrWXOC`rE_Okmz`OpyE*EBTO&TDDa6s7aiiuBq&A*oL$CQu?Gs<O6>i~h@4+0Wi)}t>1A95BP5P4',
    b'iz3-ynUmgBMM(YUc>AKM+ahKM3+(&qYVz~rD}3MBEdQG-&YS!CP>fD~JDe+-PDJzD6)kd4dR$Z8I`}QoTqpucv%39o$lGIB3p$kA',
    b'l;KT)Ns;cNhuT~<U-FK&*Hc4kP)X(Nw}Uet4b&d&ti)_SBQ}O5b5Xe8#<QSq&6=Q@2fm&iQdszch_A~3GIG@ow0nu2D~9{i=)LLs',
    b'{)*wi>LU?iiu(?{$@(fBlkcT$7~|(_CJ-mzO?RfJy%w`}dG*|WyAa*7FNEoYGt*N+tSNSVlfi{^){D>WR{fskg{U-GUI1EGzuFB|',
    b'OYW&-X9RBf^yw_j0{@FTC;Z@9<~DT#Z0;b#_r=~QAlW?jFn`@LKaC3PIT@L|W9lS&Wsh^uk_VW4mTWnDlHJTYedUdYvf(FiItvrf',
    b'rMtdcr}A+h4x=-&3V80CnPBP(lj04$rnDVv_7h{gsZGZ<8^Na&r-S)%>U<_~n=&Dcqh&_FAAI@c?Beyae|z+N*`S*Zdc^Xk<GHQB',
    b'n!PxCb8x$^-d$I-%?e+Qmv<j#{}~(=M`8K+;9z-uyTWLEe)OfK&=XaIHt(0WZ^I+p|8v~uOFZ1a-mLEMU^Dub<cexd4GsN$w8RM9',
    b'Y?gO;K7@XoS^8zxYsXQqPtAUznljdv7`zt!GCR8?!RE7@)$rnyoMLxXeTA@6wp!C`{MG6mR?B|F+8(~|kif#4JW^fL@$0Jj87rmh',
    b'u4>THfe3h=$y1Y`6DdkNTE7i1e#Voz!;G<H*#OVHdmb<jK<hO|1z6Rdq55oig!A|s0=@n}_TK%wjT>1I{@s5?C*L{qk#}gN-`$MH',
    b'nU!TZ(HY0~ksN1cbF#YqK-*kXq%KL>*5qdY_5~V1Hy#D_gOu&ej!z~Nv+*bt3WcgdJzi29#jExDS+;r8r1avozF*zlAmKTR1&;F9',
    b'E=A}u&%)t<nq4oJcPfx%h>S)25VHrb9JJkSZZTG0Zq_&JEmnl&x)8q&tsTb4Y4xSU6$$H60PKcM-;_<zo9Lw#B*C8H!;qi<H%-}V',
    b'fYN8u64vWYgq-xIjLm;Tcly(ro_SvH4rGc~!Xl&u?^-;Dkl%gJiX{xS?IuwsjE^+d&Q?3;_1VSw)AO^7s~=A;{&sdDBm{OpCT?7W',
    b'Uge{>iu|<ns(DbQd6l@xtxy`Hv??m(d2y9waZ;wZO^~6;^CSG(FN^%R=hP>se`6_d#o6<y%CfWyym>W8UKQnjFi&DXO2aI2-89Lf',
    b'ybOwD?uUsRgb8jDm4zF+z8A%Ql2(0Ze{%Nn?D><k=coVR0a_vy^Ld(~BEjRO9!iVMi$dhZIYvVe`H7bl$aSMQD{^l>5Ai>-?`1xQ',
    b'JI=GrOHtSX#pSCP7bJ7S$&;&-$LAOe&(EKpUB0^d;pFlM2@ZGex+n;vG|lpGj%PzzSYV`}Dh+~i9+q=2kMlgjoVyJ1W?;p<z?+wq',
    b'c=w8O&Wt<F^REiW#fzWu<d=WLmn5l?+Y5K6^u6iy#q(EZe}4rbFLSZxRk?nF5<e+?4{u!&V=Tp`i>U;q^D4oBqQG~nDk)KvV*)Fa',
    b'V4mk0rZ%_e0ORGelji{8V9E;#yG3pm7rq;1Zs7(VriyZ&=9!yRIV$4}xhTV=JWuA?JPqS{l9z6tV|wnI_3ZUIp_a3&v*)kRp1pW^',
    b'2Cdx7DnIs;Ac`_n`AL?$m{=oBtoQ_ZF7o^^Li0KDLqDxDzjEhZG%t!c%Tqr{swC-v;pF1gIi`}=C(q8G&|P?Saq|4~^y2&_{?%7N',
    b'Dav48p~wwU6=IZ=0?l5MC%#*{XkLbq8z&e;Q4thgi5YYmcu5!{R2D%pFVcRXoIe54khplCvp8_`q?nf;!iP4_D;LE<f)U`&-6-|S',
    b'1j7~OiCaW|7-9^dF!jO!1!dP6K7H}**~#M<7bo}>X)mBMAbFAGX_VoA1zsK{RqQ5N<;9o;a+DWop5#@P&+&1NLN5<Pe1b6<m0^{H',
    b'ags)ztgPLLi?h=+vI_tZt{>0KAT9kYC$xyEA@NhpEW9v@sx(bQKge^}cjGV&Jj_QiW-y1#q9jgpylGw7kdldu^CCCQiz>k6hSIQd',
    b'G3U-JjOYMUf1D$fC(%5?47-YxAP)<SgrdUdrkZ1-#KfCN9rH@*^JV6ViYWJxJI@eaN|hHVo4a_TD0fpI^C36!@-i;wsUN4F=N0oJ',
    b'a9z9;n8{{d+{rwFyr428h|(aM2N<^*<~2UXZ-LSh<G4tQGRFrrj4-A7m0#c;spgrV#7R`fm|w;vZtwQPH!yLE*-DTHVHroLn9s59',
    b'?9VH|Ow!QB9NMc2&!3~vo8!4%e~#}sKg35Ph|?_c=b;yOkv&i!Lz+K!(|qpY`vISHd?y6>#8q>Ayb^LVA<xY)5B3tjh?B&_w<#(^',
    b'j20jNy>u}O^00H^T6GF(`l8BRd}(8rAL0ED2=j^Ydczc7T6nvWn_~8pR#h66KBl)U^5z*99p>adz}H+C#{q+?rNfTOGB2apL-V|x',
    b'queJunqwgX|94&$Wiby^H!YITui`B5s|bI`jH=B1$S>V6W8yg%GdTc@Ypz3OTn&RE1scj?sCi_>^4ecw*%iI^y2e+U%d>QYB|NgQ',
    b'2jm}m^e(Y%yuKrj%P*JNiuQOwlTWOu2*2J;G-16##g(2XT|?8A{<5Pi6&S^U49k4*`hgDmlCPM#+u|(Uu2>IC)>qtJ{z}DwKB@@=',
    b'-D7uPL=RU5Fk+Zx&?8A>-*_aT5BT2HDtiQ=Qt&R65klTl6(kzl3Nx6{s>21NPXN+@Um+j1hF9DhKsNj$R+vpIKW3YE#K1C{3PvC3',
    b'Eo`d0`Y1}`;JGi0x9B>v%}s5m<S~rD`X3LO;9~uO7*@JwAn)w$6kO*SG*e@N6K9g${n(ilW@_(?QB!e(Gf!#WI>QY#0E{!4`unU~',
    b'1p>U)#)GgAKCCz90Fa(&N79BGGd$2`Ivf<VB8$3v+$KR92Tga?ChhVt+fjf*ACgO|o*$51X1lkG?X=_bQNea@W`>AzD>%uaS0_r*',
    b'K5?D^r0XJ25B=@f)1%svf*8=xp{4R;Y58<&T%kh5oej(*+3zL2z0F>wx7LXp-i$cJoACgyKW^~-sGmLVfGueJdAu*%smO3P*#Pt*',
    b'K?L}uc-N*{%8GY0zADZf35tbeO!#lpef-J3bCNpkO=B7SQ~Mt0O`X5|g}N#m$^_{GpYlXfKaTLR!O$7lQOxdKq(^&PE*JP1)YX73',
    b't+4#?LyZetBVIkZF9^Ux0|_043cxo*0>j8jmdkZf$BfP#u&l=;TcHtP@B^jmmWt_#b>aauYV}{O_>{&rVx=?nv{L6#Prf~9Q~3m~',
    b'KR!Xc>YWet=JxlU>cz{-gy`PAz#!y=wga>ot+YY=982|mRO8PbrskQWfilw}G3Kz;4vQ40L$D$T?({rz8|wexs}7|uKbVZUz49tI',
    b'FOT|F*VI36E`MiKc*KAZ2?=|Hin|(P3#KE7k;4dvjiN;u*oB4W9%EzxWLpDcMTYqw^3Uw)9Lg2UYt|D&UTE!v;;Njj>%&_z5wo19',
    b'WN<x2GH^PGOwi`XmE{Kc7_={IGsk08DiXU)R{Xe)4Ylcr{plHY(~?iien|FmJ?f-E%?wHdK5OrdS+jvNj%;IjV^Q#``M;d7y_Uz6',
    b'fLh*CDBt2;1z|XbZ+Eh3b+#Fw4C2Pb{ih)mgDfgjjQ*J4Qcj~($w7z^(FmUC9NsB~{ixklDZiLOKiJ;h5Ra_wIoHB?tu8?=Gh4#e',
    b'>m{Ha3tfrWyN^crK(W7qL!VuodT}K6v&U3$3H6UtNo0hA(mV*TB55^zxKmr$pxp${o1byVBVAOGh7pXuy@u1hi?mk&KF)@@<uv(C',
    b'G--gQgkgVyjPzQM2HdXzGq~8J5lZAY1KT8;2bKN?z?(AG*kGmqBx+B1F53v!?dcCluU+mBRa+}wf27gdj9K*tnMWpHhmXk!s6Gdm',
    b'X!lr5uikeI;Pv7w==lN~g9V(q{J)t2qUAwiWyJai@R1BY&Yf>-J(BT0>Xi*|OoCLm&9~Ps_n<QfWy3`(Ip`d|K1WOAhsiV=7)IwC',
    b'eOR0Yh9s%vPrn4tU>4L`4jGYomgF<*3k#?Yj!eGPROpmmG`kgRi<h9LNwY0AYI5S-Uv)jF?w?0Zuo@mZEy&n7-wrsqGDpcs1cy-;',
    b'khfLMu*1H#<qM3ijv~jznC5cLfs!Wa8Q?966tryHJ=%Wfcvr3u=B4Y?y-6=+8vw}WU;@?B^gAc={E^f20@KKEghcbH+j9un#3PK*',
    b'u?W??)2`kakgp%IaoM0=tLvwyz6U#2>MRk*{acm?`l3G0OrVJ@%7NJ7Pk(Z{%7z+u^DAYbN#{r^4H_GgM0rsdj>U5w#?=BhHRQ|&',
    b'tW`iBQG1$8bEXp@tt(V32LR%C>os8@9ykeipM;xw+;-C$%ZOSEN_AnD?%sag{r$SfGc^=(2<X9{OAq(#pUkwt!y(<%y}JAEe%-~5',
    b'XQ@wzbock!IX~#^-4woIGAbE>*DVzW3Kf>pJVlHBNdCe$Iib%(M8E3!LOn2}oc45l=o~R)CB=zeBRj+c=2)hM-;-FAu4gCKjH?!K',
    b'BUba4hANWKOz3l48?J65TrKn&ln=d~$iyNq!g8;6zo-$a(0}b$91~EjYSmpqOfNe_izuqsG=J^WTfrk4!Hn8{vQD)d(mPY@AD0M$',
    b'ys})BYmy;N+>d@)1-a{|Br8Z#_^#(y^?#!z_M&-|VXhTL^}pa+%dt3EI*;d7T;_F(5zq7Hc~B3Q2gvt>d0JoK@=*KgxKP+JEWgkO',
    b'eG`VW=7Pu?hweDxT)0v=3?s!L-re7?do=1U=Dp*+dZ+t=?s;Qw@}_sU9H3>N^#YoD)=R+5vzFNw-H7VAlv}MBBx$NO_oZmsS|I4a',
    b'-<zO01mozL_l_IOZlBi4pw^?rR^EAT@7%?cw1-SXjs*7RUXj0kK~I#U6E?8*Fl#8Dre4|6;qo|e&p7sr;ul9}v*dbcg1L$Uud4QX',
    b'vsO`djrFMcI}P>b5UeFYX<iR1&FlYa9`r=3_)CTr9xv^ce%q)oOb6g-64w4|dRzL|WF+tMKok7#nz-s2*s8;$UVMPIIHpmTk9tet',
    b'kMeH8ZA=xOgJ1Pmi>b*WP!FQxl%~bHDFoE}nUf7jq;2+}!dLF^BNx1v=YmG(2dXVLEp%%LNNUJa^RTniU2LoATHicdbRtY;UwhLN',
    b'US7}6dXYv~`c9rMZ?{Gpr2syuDvUN#dDZ4C9(#Av;HJJFShIe>)tOQBVcV6rZW#6vSLh=zfZV2f5uYEy29}rYm{?}JhaYl|l)*KE',
    b's~_JbCe}~GHM-m#zRVir4nNR;iM<B?thzBBRu0f|hKhdfhp5#^MH{HTBJ>z#Dbq+qFlZRyt!U5eLZT38)+ZaeUKRy<$aHeC_hy_4',
    b'+;s}s71?>SMK~D5o~i9#Y6oIaO^x|*>*3*|v66Tvcxkmy+&`<|1`GqZhy847V;)vd+SPs8Hc}U6N^}%0J6QL{BXTy=AdmKBM-TyX',
    b'<%4P!P?&)n(PN>hHmXD*Ly@l9<E9Gx&0>|qD4jxMC-X7YRAa8P$%oUBgiSo07o5=uN0bjXf&2G7QgoD#6GaEMoGaR3&r_uia*#8{',
    b'1{KMul`DQ=zMEppCLLY((G$Drsp{^h_O)?Nn)<FOQ$4VxO4n3U4n2Lxgd}=hBMHY4!z%m@YA1@2(hmo$I;#cAeVH!ZK&F&7TJJ!{',
    b'lrOcUHD56m&wE8s(x#A@!h{HRUix^~K}n!&0cv9-$lB!%ir9ig*6Gw3J=3Jz9Do5J4b^=hK(8u32oZqLZO22k_=w7yS7<a<H#x$f',
    b';B((XWTP}-d=gDEgwkGS1?Hd=Da)J5e^YSD1+qV|d#n3#b~;nAphOreTN1(uZ4@<{*0-KvOV`~-Pd61Vxd$bkf#nunW^cAy@USo(',
    b'9ZiVi6OjwjIN>FOXk5rK*DF#~N&~2Gf(YOY#Efv@Wvoj)N*`G~zkRnzlL6(r?zEn~l-E$N{a&{bm(^WTo>r9C7q7RZ4(H;wb&np_',
    b'eS~X4YZ28gBz$%c8`qu0fPJk=LPH23lI|WqowjnC$n83P>iGck*8gAnE;(X>4)yw`x*#yIxhu&%-}LqrNXSRYAIl2GPiZ@nua1<;',
    b'zEQmg3fh5cuF?YsA)`IvTGSgw5Te3^Smty-cP|p7c67UH^^_(S4zTXuOp+h1a|}s-n)|5Cu5!(dR`)HVULBAu$SzYLbE$lH?0I`q',
    b'XFseV8vYZ^!oym%>ZSPKQ{{^bdhSn@GOEnLeJ47~USF?QN0%*<Uwgm&+UD`VKad+&v?%};=w}TzjGPd>jYf<l0gl0@3;4zTRkofs',
    b'8R<{ivuWM#sG-~+@j3}DdCp()|Gsrxtvgz09esUs-%a89iPzCT(EB&q2@&&5+KosR+_XUcyPZZAzQr%ZRzlA$0M<;52bVufqOHUM',
    b'_Q_)-9d2=U`azns<}gi_l!>&z<n`&V_<!FL@#MdqNxOUP7oUES_NM(Bic^)kz_>3<8N*IIQs0%WWF}FSJhp&}8Ks?>yhYQ_#~>|t',
    b'(ZL>d1{A*SNVcT-395Dq7Rv%%F>1Wa@whZyg%U3F7h0`xU}RrtbgS)INlosql~ik>r1jLG;%PiL1Ao7KDf@}yKV6=|bv_Ll4&eb_',
    b'9`7(gYRYzJn>RJ75RSlC{7d-lugB(mW}L=Pc-KiYh{0>-7e8#SN~&J~yqXXHgO-<|^<tF~fUh}{MurppVoM~>=h-znRzC4Z^q(%y',
    b')lc|LZr3aFK^l5O!JG+4Nf>`7jyP+_Py_%0EfWC~>{QMeB<lZ9m53jL0S<*41*QJ}os(X9^SV}Q%W|6>JyO7J>!ZYDdndvQr|L}R',
    b'7T-C<ak6P5V8$>A)B+E3<%Vh7sKu$$WEiKQr9}nGGQN9_+HYm1LuI8K3&ZbF@R^cu4of2jQm?-aB4LPBH4&W(K&=yMx8lMYgWg&a',
    b'WiyDS=eF+Q6(_Fyr6&sF{m_Xv_V3CyE5a$iN%C!-$_UjKFf~7B>NeZM$13Uh4*xhQf?(0CGvnjfmnL@0HlWd6aWsxEXdev<OmQB+',
    b'L3zgH{9u~9r^&)@apRPIaTOO_ZrJ_B|FzZATGz6kf%p`3F&vqAXNa7nZZL&%QWz7!fuZ5@Opn-1y~mW@OGsDHcb7Z;ak??DOdu^V',
    b'--gj;uGf5~^?g!TJRn2i;VpiuZe>04JyI-!m23xPI)+5z$;_FV<>HxHE}l6y>y`BEXwn9W+AvJgHF;B$KfKhg1(iCCzHIF4=j2}p',
    b'v$&Rb)<#rjE!jWaVwy31ES1x2%y!iBgBb{PUo?2+pH4LR4H_&SzW|fx4;q6Uci5YUKHLf)H>xR+jsE&;@;`gFUX5+&xknEj39T^%',
    b'OHx$I4;0%BAHE~&kB|#uk0tEw@zTC@)R}nh-KO3x>dSO<AGUX@o%6&)V2Q6<Dj;hSE@{swcXQma<qy|xhAA}n^LEhq4Xi)dlpLxW',
    b'-jLXnVsV4zgmYRAew+zjj`J`W=IM{M2OczXiOG7oSh3p5m|MA!FG@?K#9gvZncMIq@^wP0chgT8Ej0cLuGdRfa*3>d-Vjx_+?QCl',
    b'!EO|Qsk{JMr<aK0me(AmJz8g$=NqLlFS<>?8y{_sZNfT46-{W2NCJ9zl`@~04al9xu*BYsCkFORzG7&?((P9S1LXh3#ewhVZJ&t*',
    b'XTP+2mIXko=LbO18Jbp{n48XHoLS|;;Utt4I}-!wkM;q*F&)-g<!*6}u-bZkgEv%ZICgoDI+rI=^w@Pi`tsMQ672W{loo#(h*gVT',
    b'DuWVB`d#y^?$37|Vr(PV5qB*^JjmnZ=%mYoY0zj<<FD1+U0}vgjh5BedaGO17)62aHSVs=K0Tn9yPN~=5F)pdz2Oh<WNvVfY&^Zx',
    b'dqwm;6SJ@JJ$22LEBgEy1~q#0bq6o&u6%|$#Jp?M?jSL>Pih=jc9QHfs_YqQ!3W?0*#{enx1$Yc&l?Q2=XZ}9Ob>5G?0)7pJ)QT-',
    b'$HEiLpjFw=l1IKZGqj!(={z3(VudHg#~62&f0i=e5Cl^}8_V?JvGDi5IDSep;WWRfpo;6G&JvD#;|jQHhf$#9t7b#gB6B%>vF(Dd',
    b'*gM;+Y_U9BNkGs!pah%0+h0>n+v2*zA?=SdKZKrITSSeTek789SF$g&1aLA+4tNfwT&bWpY~OrHfJ3I>f<(O!<SpRid(;jSgQ=I{',
    b'E<WwznOg+3Md0@z6qA7{MX|h?{rg99f1bFh{{V?RKsvB{x?gvE;Y@o<k%j@heFtFM>Zj?*sBM1e8_nSv(;iJT25RuJ+LPHf>i0SA',
    b'Q=3;bitDvH4+%U6aU~P(Gz>mDK!0{78hC%M=lhfMfB5<WEu5M$5$Q;di-rH6XtREaWthe4O?zl+z!b2^OG#->?WOQVh4WAwTRBsh',
    b'xX6k+o&*H!L8%)Vb8nKNlkH`{eaC0#+^f!oBK`7^xBZI~_=nx?B}}gkLfFLLkcpLjUUpICn1ghKw;K@x<ikS*r+8e_E-)Mn{)aW<',
    b'h5$s50qg!}vTuK8!0FVkZsGpauHv5ou<S|gz=$Tjkk6#Ev|YB@%^>zL(=}TtWac+>QpS30nwOD?&`@GVI&}SxCJQ<}{ejzO*KetA',
    b'F>z<IOE5+Z$MX?C?~AEoANpOB)99cyo$~>lqU6e=fJ2jW=-MB83HGr$p0#@IVr2M>XU|R^zqmMg_2S~{#mln`T7jiU4O4=;2ctuz',
    b'huE1C<tcjj2<dcexykV*CdU|zff2?U<&0qyYUSbkdw&;QcvRwLG$~Lbm5nF<bOurL@WQt}$+1_h*H2G9y>cYXdZq2^7}!EfL*M#)',
    b'+bn0@j!l-RAEiR;{Sh!#m-b}4O=haUI_^g|AVG5<-MKk^x?a}%eiulju(3-7)17<Cl^ewx9=zZxbW>CKu%U9#A8qNuRh0PJ(xa;&',
    b'b$eP~2nPNb4%dqG$h|8t>$%OAg9F2sSbW|t{#na`+uMA?XD7c+rc#(XZ+^3`i`|kQ*R`nVehd|3Hy@=~-`q`Ddpy>xo@%Njk0o%E',
    b'!2}Ow-a~FKTjN+qlgoaa)(t90Z}l7k??JN>kD4$#ROSUWCflRtH9uLZLP^^0Uz|xj7S?yL=Jy{RnwzVL*=DL})qzem;QDq+VW=x1',
    b'5U-&|e1{KNlX`rxnnkD4e!ixBYOt!cH$Kgk7ZqKs=kePI>4tN`Edh*}zT?OmVy4y!oIj)WqI0v6x*>VaDnZw9GSDXbV79v~*qaKy',
    b'4sgrwzH_|T?XPz>KF9nGkeP_dU{ebkeo7C90YQa7!1`4~^Dr#X_;|8*%hHLT!2#DEhxf4fI2^fplA6Z2e95O=I`9K1oj&NQ++97b',
    b'L+QA2Tu=#F9(Zb787Jxii((CWEomHSHVdP)sVv8~n!q2moF?^G|MjppsSyjpFb-G|KY0UJgiqMe6%9H+(uy#Qh86w(;G1up%a>37',
    b'{_xqNK&vf!NFzM(+BV-hKc2sOaI?wYTxZU9jn&r0?#}sN?ooQ=VP);X;`(Nd!T9><8&Q02s=i;oLs%kRuO4SxbcDNqecbjq`Ud|4',
    b'x_sBBi0#SH4v&X+IAtC1`oD4h$7;R9%Xd!K*EfqLdbnO;;Q)U}G(Tx=1;(g-7&$yY@YcaPcl}%JNEutdVd=wZTHy!WXVVcOIbAQ8',
    b'S-#$oJbyf(ra{|lk0Z`mY@JTbGU~w;vD!J%z%(l}668C|g`92i7F}nrY4u@UPpUaND)qV+P2MT37Q*a-k`X~}LZZ90X(&QPWvtEh',
    b'M<UC?ahss?2SOACMFB<C3vQYwaRZCpuK)7s;pK~$47x1I2LA>d&w%t?Y$yOt0^_h5*!a!cR$MzT^+9;$3?0Ws?bJO3^U*(B7j3p{',
    b'j?M=R*SCd@rm`hgxPR+G7rH>+rrEZ&L0deMu#LpA<Jd?+TE2bup*-0cK54nZm9KgdaGf?)uSLH4CoCxMSfyPtJxJ$yIW|(hr0=#U',
    b'qt^}QI#{zN3_*O#`0?c8Z)X=mHct1W8&_!=&J(xt+}QK{c@>7KA7?%)(maoXc@;&8=N9uK_EF*&S(fC5Ushq|22qwXi&nqsNd@~0',
    b'{KMJB)#bAnuLL++8^PC?uP)9`e!ODQ+{XTAuj(<bUVC3phrsak<n-jp*|_=fhbQ6ygC`dUczpi+$@%l|d1#inCq9~EJbQ6a;eVBR',
    b'mbmkD9!5nLqA;tXF!$0J?~WJ5UgqN+3$oI~o0Xz@SO!U+vg3Q5-Q1AZQ+`Yyeb;f6TWRI0x#f<fq4+ZKP$a|#=s?qa|Fq>#%|K6X',
    b'WNbT=v_y-KCt9xczLV4budtX@J`t0aADi&NgsFA}of9%7)*DIK;CiEla(}<ZQrIfPfS!Fs#Vtvh^hW#XYSvkE%xN+bTy<F_dB%KG',
    b'L!eX|-{;rOEwkR7Tmg5)dLs_omhie+uI~sVd%4VNhIgf;0qc}dWOp|!irVC7GB#>JwWTu~jlL$ja~riSuok(&*U+&)e{%Nx)%mM`',
    b'T%BE<l6-Afug@;dpZ??O`;$w;0o1amnh7%N7Wsb6Ht*2pwKthM=;Mx{X9*i2r}}Flz~Nz2Xb(6psYqmjgUU_-7#=(+K0nps4IToT',
    b'm%OcQh)6?XH^eaVmL_?FlbPk?W8245W^`;8)U4$kq})>mF+D}zkp!gjk-y{W=(rLVF7%%$Bnm7~{_xoJLCH*A>xedeYI;;#?XgyZ',
    b'&dXtaAMerkRO+k7E$h_MO(ZSjX?9fh3_0Ak!q4+ph1hij*<YZne3}(miB-MkR;ubBfW^V<5=&OTM3_!!Jbxe9DPS!S6Sab6M#7U#',
    b'Qq!!jNHb=yTcDct4BYRrc-g2k_Xk>+TZC=p%Cn~U{0-f8uFUWp+rVrPn|=YG+!{zk2&TXGUuP>Qs;lc<2$VS0YCf>5ii%udG$eqk',
    b'plK3F*R%}9R7YzIE=$5wLgo!?GD%xAi=jntEL%?m*`+OBW!L$)_~+~mY8FbOHyV}U7e*DoYES-Jbba07sEZJqhFz4PGz3yMNS`%g',
    b'5E^t-g9a5q4*=v4MKsM!B+)c5QiB1R8X+iCNi+bn0){MzB1Dl5O8qu7yeMntyzw85!W|$mH!t3;*foi!B9#hO^;VPOs?3Yk@~&yG',
    b'3D-q|ZgvJFfw)m{V!QbbzOK-E;(_al4eQz7-Vi(b_M8iElg9YjNONXorB=_i3rpx)XBqey;y)<L>u@LSV-X=#`C0xz35QV{QUR2x',
    b'W^p9RnkHAdR(M;kcUaM>yEJPc%IOB5p~0G$V%##$etolEVZtEBioGW9XR>N^*JtNX&rbhw`s@sU|MBIE=cE!*YrZnWNj1~Mp~<G8',
    b'wzHnM+t_#N5SY28u-+50BmxK88a2s(IB7xR<sis!oYu__%2X`BCooO5li(5>1Yoa7{UC_^>CDn5M97Wf$kwJnaTceEwM`hMRpO%3',
    b')+Wk=%8m2f)+UaMw2G5NN%p7Te}{PzHQ429U$^bs#SK<alo!k1uc*DBESto;%=puYiS+SOD4y-$YiLb<DGhIyf@USWPd>02HtA-F',
    b'AF0U{m6F0OuJ8eS&D?A-_{xAkt@uMLDkt*O7JmVRx}C3T8zGhBxNpSm67}fAbirn_65XH`sR(t~Jo0x8M7R57N%YIR$Ak(dw&oWI',
    b'5!A1CP^*R{PKtM{^@k-Y-=OQ7dDXz$m)3M<YhobrjX-5%U*F<;5g5QAK(xLN%wjIS!ZwpqG|=@MADUSj#HN$^NxHBZF?AcZIxsIU',
    b'tGBccZ0=T{ILwn7Zrj?O$7Yn&)(IIQ>WeYi2{RII5cFtHel-J{w*YFd!5ifbScSYb(h#<RHvON})peO4s+$%(Efe$W8s&TdDofpt',
    b'35}bZz#eP63iLS6kwT&~q{r~aM53(Zc+_(_-y5h6J%Mr}EA=aJv%cLP>s!vZ5_lrV<Lpiv=xaFyXw}RMzofT|Q(w}JXg&rBQwH(=',
    b'p4z(})SsMRoSkAx_8-t|dY&hxR~CMmAylTNS7h$IEapj)#zj$KQKv|=I78k%&fMIMqO?dn<Y)6BDATCS(&N5!zxeq%dj+S))~naP',
    b'1PDS=<OOkBhPmgKVG^M-nwKcgVm~g6!uNA8FM=cqB82~)1R09GvdZUCm}XU!B)tLY`=pJvv$V?QneQej@RA&Pr5jf9Jn{V4byGLW',
    b'Fswxp&f}o+)7&kqq>QuBpSxw0MNw~f2EOmZ3lSdoA4nF)x(bf7xW2yKW%&}-Z;T3PP!rCNJDTdxlWhJM?0Qk3DdgvC=_{Q|wt%<q',
    b'<*>0Ecxac|oA6-HPR{~ujgRb&=FxQGeE;!X!&l5t{FdG-7c{)^%T5L>^pU?!iM;0Eul!@*(}&5)699&(Ez3*|&Jj`Tw9-8~L~@Qs',
    b'Q+|;SX}QjaEe2x{5J+(+0*U-9KOp>T4d+|wmeZlcjRDYYZ{H2T`@FZS7eKEG@9|+>k+Fr>87Az_1d?o}TbsSn#BbR1K~}tj@`M0f',
    b'=!nZLkk5P%9f|yD&mWaRE?3#j_U(En!c$}9k#m*f^SuJk&g6RghD7QDu|W(?0u8cX04jv^1c`XtpMl<W^;2~=HNhM_w3IW|mPMt{',
    b'q4fLJD*5UPeZ;uE)J?&hu-uP9=#{aH40VOO`&aDGU?$Uy;hVRV9&<t%H6U`3Tiu=yB3UpVE9&BF?<fO5a5i$ZWzN67Ds)T0X=oz{',
    b'<)fc?dFlF95qVLH#l#qeW$9)pOG4L;a+D@0DO|rO1N<qE-7HVTs7SIfN-De=g?Tf6q6r1SidGyO;Ky+o;(SlXP`lkEH<=mWCa|aP',
    b'RyFQp&74zkK|+ej-P^_1LcluR45pt3D1M?l5F$a=aFT<Zk%PI%@YP?EjDd2Fjv8$i$0sYbb>ULC=12}gFlLnl`Be-1QAJ|xiA}N2',
    b'6x{wU-d)}(o(tmtcN4dI(ij&H!LeFXrC^lm!KwgY_P%=>pu;^c9`SCR3C}x&ZXb1!(N~Z>P%yQN37wabG~5H@iRg$O(lBu}!2fjE',
    b'MW(L~zRmWHF&KB7nbCO=v<^Y<;cmfCuu|Xx)xo{D8}+`{(&OIkwWiT`v6)#M?m`yl7<nt(@xS+pIqKoz+wTHb)+*oP>c{=Ba`X26',
    b'Zsq#DF7?B3{?S*y3EsW$eHm$?6=}c|npB0Tw~vC=NDjCMNXh)P&(h)V_}uV@8E~vNXx3i@R*VD|r-nxVHV#5><{6kL-K&c>nR>Rg',
    b'FdN7xARC6w!=rJDv5quiB`|55_ffa10)y&SM;N9!1Yz23Zjs#ug=SuQhw0y7iGy{5o;<}$T-`ed98|f1Qn^uDu9!NOIA1N%4#D<1',
    b'YSf!K%x*V><`qZNjgKVlM)6L_ihI52=a=wB;IzvvcPTAFrH@XJe7lL)6mejBXEGY61;>_AF)vUEhtdA5J!`4vXUi4V?H&WZF&g#R',
    b'uOMr9BctqX!HvO*@7+{RH%u^i(;p0`ZXm7*HfTeNg3$)R1C#`(zaiRx+g;cD2k0qmm~IWFb(?CBK<gUbrB*_{&B}VGDub_Dgenx4',
    b'^E}Ms3@g`361!=YS5bk|D2z)l&ZB%@=3eNhUhHONkbC$)h$>#X?mQo-i+@IJ-Lvk^$!WkUKCgm(pso0VG;6*Ek@+F$5ZZ*<)8%t1',
    b'6{f9}S*=xhNay%)BdAEW$>DrvK@oirAEs)wMbdQ`4n@j@fG^j#n*u$hH!zcSy7&p{clPlHQypUcpP*uyH8vSD#qX&!^i>Ze@d%bs',
    b'W(|u{$U^c3mHae@O6EB%k!#{uAA!8}iao??RJpX&#Ze*9*d!~1am3?eh!;@Ya4V`!v~*5JU()W-X!}%LD%`SPRH<5VZsk#*O%TB&',
    b'(GTnw4zCdR$p^+QJ3vu5vgROM%am-0BeQpKO?ZHt*)M9BUkyWd#iHsk&>G)xBkFc*_$WHx8k&GExLp7Naj3xZpg2_6M^49GcW6He',
    b'wP1%pb{lUrROn|Kq9G*lwx&Y>1~@6+8Fg4qBdPfpu?W!`!+^e4{{%{gZQtg8whwaJSGbXaT-s>{hIM+@oq>~5{4ux3Kg9O<pLlyr',
    b'QMZ{CXrbK%!}2VcZjBjGtH{R9#0Y}fs7ww(v;o+l2fO1@1FI$=14>`8_r(P!Ea-Xv9Po<heH$J4E`dW|EF7Ps@acNP)nzqDh>2#+',
    b'p0@BsE+v;R$yO9$w3d%{imZ?T^4+1R$)slv-)=SV#n8-{Ey6Hkk8BXE<kx$2F7+JFs#u36G0u!9<-4z=Y{Rlh`D&n*`jH&5sh#@x',
    b'w#f9S&)W}4h6_{0IKc!IBJqnpuZ|rMhevRHmC4n;p|$=ePD)ENa{yLw`0W=Dh3)8l&cqnpFmr%>7skW^)?z3BP8aayrwiztLS4!h',
    b'aQ5+LxhNJpA(No9eT$Y$ngMI`zRoec{;+kthdw@U%)+%L<&@s8Z+A}Syg?YGMS)x0Vxlr+3usr+diT8c#l+?|$erIT;pgpu%n;l@',
    b'><<sr=M&TH`Asl8?^S2`w+6$v&{$*lp$@#RmmWiJNhjQ7nE}F2y{yavFLSdP6E_K)48u6_bL1t+bG_V4!@`Y1*Uz#b$=o1MtDvZ=',
    b'GLFl@t*W5x%w^0o$Fx2*aFAsj`ExnY^2eWE(IT3{3Qn%%5nub=5toexuPc^PeV#bBkDF^A)EyI;ata)GMT}Z~xH^MLd!#4mfS^s7',
    b'+c8<&u;<8`oU6EFc&YUs5waZ!V+nrPy~m+yN;WqUw7gzGwtTiGM(WPE&=F~zbvJ#Dj7(iSeE;l}0Ys--Q$g#Qmb;@@^~?tiI!<_4',
    b'Zu7F$Vrr_V^JgfjZ$6=qhAE({hy}I39YaIn0_&0Y3l205p;^IHB!UsV)|f)bKGq#$NLmRrqD>2p%E@NWDC0g(Ahu{MR!vaPOspS2',
    b'I5}}^0~`#3w#V@6qz+rh`Q8Umm4s%3f-%T-1{$b`6OA$clWo+<L3C7ijby}-$P7v5!8nQLXddh}Na!YMltyT;LFREZ$2y2N2r<eS',
    b'd$~Cov+H-bi~!XKx*yxAB;Isoeop>4KPNv3v6dGHsEnh;4ZSpq^8`z}X;l<KiK4*IGpv+mb05nAD0ZVLD6_bXQWWBUSL6JgJ}0`E',
    b'qm$p^=;RNg$3_w$$!&_z$BIKah#18I_M$|IXB;p>c`t9e&l;zFa8&H?D%UTrt1sa98IrfxwtxPB#xDVd2aoM%xA*}A{8fqN00EW<',
    b'!hA0$Q0o$=rkCa(_AxCrPcw_7&j_><v>H%BQS>5R?Ui*Yb5mXUI@N~nFsVSASI^D{<xK~nz4vibK?s0a2!pB$mOQ9pP9dr+yG#vj',
    b'gpnmxY@b9*6i2ENWt=Z9WIsH#@2sYybhfZK*xE1J&LF)WY@=VGoK>uZhzLL%SUgMoV(DzM`dA)CpeMo~Z+8lV;v)XIx>t%ReAv`n',
    b'Tpp2;%eNLvknXLn3JLUqL7-Cc+Ia2#BD54qMeLB>;4`-*^*PqdMRE6nWdK(?H?8>ht*JPJV|Ff3YA;w5tZKtaIabw1N<CL|4FsWz',
    b'YDc;|0bAS_^__zUAm%R}8)6ekN>Gu~wok9Tc|B?k;Y7g6v~7g>Bs41RB49}Da^;3;+o-{i+GL18(7ZTF?%s%KYZF@xr;V#K3RdV7',
    b'q&S_l%;jxFHx)uUK+zh&)7}(p+ENX1MYao=lN_)Ub{%d36J|P8KH1KsxO~{lr_;GdtNmgu`BGEC5@qkv#9H1&UA>K?sa$2dc!O`i',
    b'mz(vvdW;Ek350zrd=@_RfZM1xbbCU=t0)Yu(U#U@0_SaF2gaX?=YlU=U+1i*%0m((yc-ZL>fj9D`wgmY_r2D-h~a*3hAsl>!DYwO',
    b'P++5>pdSqh-0vR9sbhn!<TTrds}P@(a+7@+#8-?2ayW)^Z?q8FXdwh?;XXIsgnw}B_t@t>N{DrFl79(d)g)Z<x6=;c(=1s+!f5ko',
    b'd`NLs9@HYxnuk5CfE#rPxRFu7<@9csRSmMKB92zsayw8S?XVk~wH%vyw~=4Fj-YtpM<HOWXn7yJ0hWF4M}!!EC&acpA?__>)};11',
    b'Da^W$X2{2r$^Q!qNMa+7<TEQE%4Xb`{!!L3_vqy^+g0n$_0Q|gyRBjGhnNwsZdcj+Y_TMMf|JxRcePl`6Q3@##kH}dry?m>D2#w-',
    b'BsZ<lrwHoY0_w>Q1CZa=#Prz#^;}a31=`6t#dMFhyF>4(=NT1RLjIKCFEje%=qjy;K$JhVq|w@3a~PlU^id{E-3xGm6^qp9jCYXK',
    b'Oa81#46SgUVO*}S7sd8V05!6LdYRSPUq3sPu@%bt(5`l00-%YVLbJQ|?d}O8H&OQ4k9um~`W^a^5elHceovxFJ}bDU%cco}XHhik',
    b'yKK3;d%8jBpXhS}?7RH{X4KmNJfw^{{@PvQTvauOU0uHS`JxYX-()2?%j}E1f3%{Agf=Qlj#c~(PPHIMa@8?hf$3sp0<;kBB}Uq|',
    b'Wpht9Z)(+-XcHKDl0!fXm0AW#4kdv~AN2|!lY)GU-K_wQTmUlLZqaqVymKaB(*-=-W)=Ec)jF1FhsE)KBInyjn2z!ZCsp#>WJ>Zg',
    b'Yt3)g^_Gzy*UNQQlJH8!Q=gAgtZ(intUVrUR!=221r|X@Zaqnw?s8u_vnDjkSK=u8?oG!lU^FNXP{Gt)e#8rPvD{bxb-UQm+^mB8',
    b'mF(!&j;+zBslQ5uO?0DpO6nMEJsxMx0%D~2n!iHcS>N^xQxgf4WmW-0WhB)9)$HT-?U493d$f#{_C<GF!;ESzMc|NT(h?v$W$S4p',
    b'_0wIu;NTd^n@bu2^y1pj(QmDinC76kSEYgNxatCHt0$FCEG^O8OHm;H=i380%^s?_fm{q{t5!GIsud0Rk8Mo%Nv~X?N}p4aB<-m=',
    b'l|iI5n|(@04kF^3#bMFT`EyOr!1dUMdo!b!$sHXaKr8Y6^>B5T#u3}7q7ED_h~=()qM~Pn^QQaJOZ?m`iqb8!ILl(!3xX(h1GfrM',
    b'nx;V*%!49Ja^%PHJn-`}&GRfLp*2AqSGgYzcJ(xH3yDvUVkX9Nz&x+(v-78Cr~f#8b|yrqlX}1g?qMA7^u@DhCy!rToV<E*adrL#',
    b'4|D$NAI8x~t))3@dk3SKR@ct3Z`{LlOcjcL8!3=3P#Z(YAQB-|`B^@lc5fy$W?QNP9Mj@%Z24p+<{rTbYanW(VIb|v7g9H?qR5am',
    b'wq0>P>z?5e10d{?V7d!&!*L|YdQFtc=fZ|AU=BisazP&+SERU2Pb`faTwC^ZkCU?RZs;XqzQ6;dd+ZMaa!4X-QM&|cr9ZOm%y4q(',
    b'gMFJc-9aYz#7w7}miO8p6Gi!XxNEnHY7D144C6J0_qA<5A2J6q=l<pb!*MceVhkl+i|$zXu*DmPsI_7JsCHur4!ou5Lqrt@uM}2p',
    b'1ch^;$*)8G3;^}>cY|@c4uvNHM+LDXHc82L+2#$}X}0F&@=5(X!gCVU-JjJCBrPf=+a8!7(rF)6+Lcp_;r6yD>U<qidpZg!M)Zh*',
    b'Rwtuf6a=IRhfA%y$i^aj!Uy2qF7>9gu<ySC9AU5<e(lxssDa|xvKjSx0JkA*Qrt~#IL6BK2Rz19&A%z)zPajzt><&Ks>IKW-P=nx',
    b'<)oEo+P4b3MZX54wa4Q%P3Yqq*8fPAMjJ`0nR!i!=pZ^Fh14xl362wS4dx^M*NLzVeAZ?<g~IBd-+kwJvD;m?>kxEQuR}-_MO9L_',
    b'24p(5krj*9-xHs7zWYTdeTZWbjYrqn$4`b;rr_7ewBZs+9Rj0OeCh0BkCge<1EUg5pxbqT<>)dBiNR(joox2zd89qqHh14lT8TWU',
    b'5Q8WnS0skR@d|}dyy>B6p+P*xE2ZD&jSMCM`SD=XsnWd$4)^8(9?;Q5)Z<F<(-b0uhF{?UN~BwB=^h_o;Zu`F)tbntgP!#KDp<`Z',
    b'#-{hmYcx_~zNEnGJn&}ge(of`-+;Ts^W;9xwx~Ppub_N(HD&HveNqW$WuI0B5%TZO-jis60`*T(4CN+1U0>fUmgwPnwWM+}+B{qk',
    b'c()6Zah_%<UeQ2)R{zN%(>vArc0)x^^7D==INQ$5#9~cSAv5s<O$j0mXAgiBFEuh}a0jj?0iUHBNOgS$(qa4B1KQfl@EPWYik*Q?',
    b'>1KeR<ejBW#1>$2Fp+Q{(34m1aEabKlp#91+nXhFKD=FTk#q9++^Km5aYkNjYi|0G2A1IccXn%M_ZIK_Vuj~v2CLsfA8zX<@<#$f',
    b'8;k4g4Vnpws^2c&ynUFFsu6S&lInVw74ME7u&AzEOd2(kD89C|z|D2-&j@7NFW1-EVx`~5^#j&<soTUTjdqn$JvL`f1ztMgyvAS?',
    b';la?DWwl{B#{8!i{|luhp*-uH;`_K|VzAk1uXL-OAh2vFfQJ>7h!|*KoS`Z6prqP2Kg((*1>xqVq{pqH*5Td&l5{1fIp<7)-K`Ta',
    b'7dmgmv2gk}TfITX#+XSgZZ>OtRC%p0``{O7d%N8Af?)f6y=(m4JDRdu&7IAkq6`a#=qJI)kmno663J>OHl?*=>G*VqkYG{c)Pz@!',
    b'K4JkEc;r)?Xa&X925@n4g>Glv3}M!l$avN(Vezc%gv^G~^#ehUv|?K+#{O?qTjmiFYtP*;R<8vr2kcuGx}$Qyv$O9{PFV?EV0J&7',
    b'm!<EQiSI{QSQN2aMOhqXS(uc5iua{<VhBA9Mc{{-?|b3A%Ca&m+}xeJS;y>We}8#)`s(b-)#ZzyE>6!b_0k3I$28BXc{tDVpm2)-',
    b'!&1%NstDpVL1`6XxLg!skfJo17x6st5-)Pe$2blPx6H#15T2etKY3=GKbcp^b$ve$6VI)ZG!3IN^1LJtveFH*1XUgi^R)8jSzK0W',
    b'k;WdXf+~peA`VgDcFf-vQ<X~>%iG|^QCem5%y$zMcu9`D(hV!JTt9Z*)Qz&V#M=|j<Dl}>+%2o5jI+?6yCtbM(E$UW*#bd`@j0*Z',
    b'BrLo#Df6uG0=x}XS(JH|2bqhZ2n&+L7k`eUI40FCFu^4AAe~onUUe3*5ZrNWh(Plq%RIbF{4Wef;?C1~7!_HFiJ*!?O#5+>=3Wqc',
    b'm>B03-Xkx~^Ayd)GDz~Y1B{c4(;v=XpV=TtFog$hQU<XbU>qdGr^@xpG${N8pTokNqa-Qj_%vogjLOW7=5gpoDe`gqJcxRe11YKt',
    b'*YJ=%nczCuq<8JQ)N||m&c@r1nM>N_z7tBF#>~q1wC{wxy*^iuA}DK?FRFJn6um>wk{(S*SY7CzaAcX3roYuAye|-kD4Ws@Hmu4C',
    b'+-;9?Cm<PK^-w9aKD8dLsWMtKsb+R}bDJ)xHSSd1v>rAsj44A+TWTV>kaVN^NkD0_Z8V1-WnTan7yY5zRK?{$)nX1&B*rvGn{ReZ',
    b'6_`N=q6vVwdnhEM_u^>ms34<vln^*IS{L+=9GBC5O1*%&bEGwbl~;fz4Jqeh8@hi{m#G@8XRt?n@?_L)tdcfEcQR`8G}bFe$tSH%',
    b'JSHi%85Cn4X>Hz)Y|`c_hUb*F-&o^96byRaA0frGaVP_!*)vHSN3#)(F*CGrGy_=xKCh-Cqz6bfUE7nc7XyrU-Fs-;lukU`u-20>',
    b'dTo0Dz3jD5SKZdT&II4kTNN*~F($>gZnWaF_ne%UsOXX8o6qST!^4w7hpdH<r<=Yk6C4y?`nESQ7GGv;P8h3IC+%bMt6|cksJk|H',
    b'qx%?$h~VMOM2j+NdKZ%Kp&se!l&DUiy*3aK^t#=eyP&FF&D6IVmQtXJ?1U1FDJl$<N}$I(2>H{hEhqK*E?3#j_U(Gty0>I>-H)&e',
    b'hqrkJO7D~F?VF?R;?30Z>eza1kg-@Gd!zVpab{vJxCjowADArNMTQ8D0jWn|vIWX7!7-R{1a&uQdPgr2+BC^k8($&il~xU>CR-_V',
    b'Y&D&kc_K+wryQ`ExAmqU3o+ZCp75F^nMRJ)@BW@K-nPY=qN<0jRHUS_%eBhz9cv#GfDQ(q-#@C@Ss9BZMK_s&wg|!4^V&ZWEI{(o',
    b'{LZEELkylP_QR~bEuJW!CIF9{b__2c8ewpizLgIBXD|wd`kbfw*9puuK`|SeUEY6Tt`q6QMB}OAvWz}B&3WX%Nkxg+Z%5QG2Qz8t',
    b'l@08{Ja&j8FRFrITjpq{q(rbZ6%}VNivqj|$mn5j2^l_4d(H7!%-5h@MPjrlIF8wd0(kXU`soH0i@T3Lj$#CEN9nr`(9uY-s~8>~',
    b'`ix|-)bvPfV;EUqFmT>GSIv&1^9X**fLlw}Amd90+*b!%<{F(4t1eYU9y6H~zyZ39O;<f#vc$90&*TO6ZIZW0NuyMa!7+GMw*yTf',
    b'qv;6wdz{?8x4b=4&hESf?@@L(*i3p!3VpBCFJG=UV4=TAb5E%FgUQ?mG~R=h_617ihQ)V^jo^|=g~}z`A=qd^EgLh3882oUrxk}X',
    b'J$Lt(ldkrXPOc7g-(T%@_g(>a5$rBdw^poFaw<gijh#drZ*EaP>%HO(YDuVLXM+PcgG&4l2BhpUNwEWfIW?H@0hvpwHKObfTy~_k',
    b'hfZ|kq$d>#Fk5E1f4CGV1{p*_+blPNQrjo9cs5X7>0l|OHPgvyYO^CtDbq+y81=B}v>S6C3Yt>6Q5ilEy?_~G#5S(VV83pjL)xQ-',
    b'TQ@N)B+#yId0sZA={IP_0_6H`=r5lCE7Q`oyv(u$NeM?Yw>HTLvJXW1qX`JkNGR82!0~RSV?Exoj|2oGOP3fXGTI<~0he2lhL$XS',
    b'0t%tfPK=nDgl@<lbjnlS(&l;yrbfN>?*@u(i%5`=Ed<hxi9oo&+e8nbgJaL8ddO~_aDx-&7erQFRHPzqCew?W9WDl`f+eNi(gE~?',
    b'2~mfPutD^}<`E_Ut_!_UC*^PfZcl!52y$xfp5{N8S&pT4k^WC=SO5M;=4<+f9Ezuj72-tdl^3T+tIWU#^lm#>d~sT@x?1>w94f@a',
    b'0(>a4+b!^+PN+^Q7!gh3RxPXxy(cpB5;O;M*R2cro-srUZf|C0KAIq{2V9P{$Mf}epAvVe-4O-*oH0?%+R&&<x*Uaegc*H&I4^o|',
    b'k01{R*I2kmjPk<s98B(F;|yj>Txcb_|4%H7%>CVj+WKb}HZvW9&6D1!Y!hnLVSk;NZO)*6Jc+W>{PmA~AIO*-a2L!}Bm!507rWq<',
    b'(6I5Mprp_g)mxML!TfLAx7h|Urx<=lXW9)hRi2nN=GuE32Z>1y>=b4OYYS!r9>B4B_cc`pVs%XbJ_L*AHr|m=_u(4przBR}!d21Q',
    b'et-O~l~p5oJANb^`v*c`_u+1qrD+}=7}>TZ$1aQY&A${{)U^%84O@#)mCbMiHH-|mRR2y5W^MgY?H(F>seG;*M8`(wEyD3(!UJ%X',
    b'xc&T%o7X|@mgs%i%L2D%rWF6*B6c<Je|z5k!b7Ev%Efm}8586JY_6i2<NIN^me$<QG%L~W4$^X(kEhGbtc2ZeVO6RvIIH)pU1ABR',
    b'M;lbCLJ4bt=iE`hRj2_uiYt;u$*y*d-Sc}=w_0?o$mOUM(I(?aMu@WbVJg(UfiboC>YtZSo1g_%J{)2i?{WUbtL8C_OFPt=YZozV',
    b'#JtY?WYN466Rg%C>HN!z18#61kBBFCtL%DF(8>432CyKB4RzpyCFN^<J?J>YdAcs}+bzh4XWG5R6cK%f^~;=G8hH+z-T-DRFkt$C',
    b'rbi->gWRc98Bse(iIVw<2v7?Nz^?jqv!1jk>!Pj$D4#W%Y-^F^3pjP7NC;dg-Zo%~(_Z}f$zpr6%<i6N*Qh^lVl~Annp!>kP$#cO',
    b'!DwbJtVlXp00FaYx_q16F#0FbfS7qyUMk)_VQl>rg2D(LVWc%enoyVsI6S7N)&nEur)(pIG*X!9vSTNgHty58ee#Z1=1<Ga?P?Qr',
    b'G!3f)lqUhXI#Qw6<p@j`y(gZXE&HYGY8X4uz-LO<4<K>=304$&D6N)p6(r~0re#j|q^LOB{6VbtV;w^w<XH*VY(-Y_)z4g~yGw!l',
    b'X*4w7Y}PmHZMOUyy4!cFMCZ&A`!&Q5ZOG;w%zL%(UUL+Ks5R`WzO9r<sCaTpVsL8bs6oa@i<rUO<wod)Rv$o{;33xcH7swa{V{9u',
    b'F^f1FrZIkj_yLzSL~kUlq|WF1_;yt;(F78_M#}TO5M!3+HTUU$7*Q596E&Y6R%+7pCCh>>YdT*ZMn=#Ju)tv$+F~w;%9q(4DTYBG',
    b'<)>Yjz*tOxynifNXmI0o4_mG9XilGT2fu+2!o(nf`w&<m#>WX=*>q+yk2IP6)^#|UARW*_Uftaw?MJ4+jeK$*CgV1MNdSp}0Qy~b',
    b'C))#xe%rVAg(U$AJsQr{t&~aI@NjlktXFHy7PiXknd;WmNZ*R5g(R!hu)t1%{5eXmhR_4n#r9%-mo0a9Pd5nt6LGwta&mt_No9(-',
    b'FMKDQFW1XOamU65;1iClDMyXu2GM&Tf5a1+x6m+Yj|B-&iJx*gq}mL+pB1s8yGiL#OR5$dLR3qXZP7(Wiq;gF=pNE<q9HTBxy?4^',
    b'B3qF{O<k*D?D3ah8`B{7Yixo+de2M3z({P>npT17JGbIt$zS(|t@&oNXx@7+cNq)vdcS^$%8Ba9d9bbJ3r07$7~j1%Rei_oKN-Cg',
    b'@TI!G-JMVkuRn(SPb2D`;AGus95E~A&x`8rGNXTeiq-eq{C{IDY@*&iW>#Qe{ifq2KREZ<>}9sA)|=~}*PC}+AqaiwIcASD11GH6',
    b')^^v6zS2Q7EX}ga7T4QelgPYs=wdb-*+;JPybL%ety}&5Er-%8ufue5bF*2$$5P{9>NJH=DD|EChg0lH<np?jVl1_LUvFuv;|3dW',
    b'1ehSaBcz}4(4E`uL}CZ&2xegDCrP`#AT064{w8a~v4){W+Mi}YCV!V+0I?FlBodw4EX13*3o6J9NA}Vc@zhV#*zV8=ERS&B{{1HF',
    b'ad8d3iA&5{@C0}ACUornVBFSJSm)?_4{Uiaq;~Q$bvM<*t3aVu8xnz7RiP`%2VEDRWff7UN8-o-{%^Id`>{ZA7N<${K*>j~HH@;L',
    b'a^pM)KgLm!R&kPaj^Y)m9|VyPe+&_F<G34^FiNY$HCCb4<B8>xwQ}0Wuk<KqW70>cPS)@6?AjZt2?lHUGyiy5TVS3FLC}PP-fRp>',
    b'70bbCY5ov-Ud)Lp44a_5^?mj&uq62Te<C@}@EwGn06+UScI8_7cXl01cAeogpxC}Y`}Q9+UDg+z4`}#KfeRaz_;xn3J73BJ`B_{m',
    b'TmGB5Gzf#>XuDkRND^p1B>kZ+19EhO0gxJyA1rl4>hDc%KeZ$OU>iUP!Ik=pzYEPbLMm$ytU3aw%<KjYkdV5{lbWP7>wz>Kb+rg)',
    b'-F;jg3n-20OetES6sa(v%~G0T2IMj_XTO?t-|Xh(N2Zimvw>I4n8Zn4IkjfM17vruB};~_*^p`%_PmobAfF^x@h0B1JK%%x5t$yp',
    b'dZgzqI^f9x<aznL*xXXg1(75+pph-aMZTiGD_A?7fU<?b&C}$PKvmZxO;zTu@!`b%7=-CO^<p%gPPH+o5R9K5#EShH2qNSGG!n`#',
    b'CvEl%FSH?hI<%~w)Is=|=Sk_6g<oa}m1*e}nL96wd6J}YQB-jj7ikt}$eYKRo4Zkz7Kw-aY#sz<8kJdUT<}kIjg3#aUS9XZvR-dg',
    b'DJ^D?X$x}M&#$Ho+E1?_i%xrpFAb}f&a>&-7;~(<)y?sz+bd%i#fLiG_Xp`c9P&}Xf^B*wEdoD?ECC$a$S3^7%S+d<ipYyn%m!i<',
    b'mZe*lly==HM`?nR!u5+Xz@PHi&GIyiiX;o8q{2I1jN%ht0?I_LG6ZFwam74j^MEAXu`)qkHL}L0%_pSp-f*{4a5wyYlp1r@M8z&(',
    b'SoJ}3E3|V;IVnL0MSe4gaEhfO`>xe=cfl60!(3oi#Y4KydZ{R5uC{^Jx3RZJi2tA{PY-p^eIl^$;nLe5@_y`mjA^tnk!IaPG#96F',
    b'q@fq88&_!=&J(xt+}QK{c@>7KA7?%)(maoXc@;&8=N9uK_EF*&S(fBjOs~Sq4WcZMM_s7@D%;Uq$_Ltxk(c!W&gB5CeTr-R3n38r',
    b'<{z@7pHv+9OaW;&$)TTJ>%PPY?Iq<f5=5qjhqW>TXmA`OBUr<1_PJj3BJ{H$DGwzT+#8_xAP0<s)fV%{{?6`Y-)`edv)l^`Kdi#I',
    b'NUAvT%Q%>qIaW(^f1Vd8%?d9o(=u_RfZVnIJWP@*bc-U2kcUQHwfD7RcJ<j-?2o(64h}K*e;jmO-2;0*NZ=e@ipXdEPpzTJ56n&U',
    b'eBGOQtA$SEeFMIc_DCUNd%aZyy1RnZIBYGFe_rg~UNR6Tt)~#ld#V@Hf^vTJgL_!e7+;+Y^)(*`ao!YI#Pstd+hxYfjwEHJr36Nx',
    b'kdHod0x^q<x!3`5DjZ+s0K@^!GPxHLXqvlEhJ_xvzQ>^fv;DpC;KiR75ng;Bn5YZu^+H7lN8-`7blQ=eW(;10{Dkn)XUzK`tK=f@',
    b'CtalyN(-)1%_O+jD)}Ivbd@~b>A*xTMdTlj2BdN|{ZUj)DJq6~CEz0A0A6ouIV=`+kkl2nd4ssK#l?EPYkys$)tlYhpVymG$1ZWF',
    b'R}jd%T`yLP>)UI*%t<?f^Jk0*=RYt;WSI?vaYS1=e`$JR*_jPCxuW2bAt(ljI43w&5r{=*P9Kjow~+1aatBDWziYsk6k*RONRP~L',
    b'2*^>zP-%$oXcPfwdPmpUN9Umvc+&x3a^P<8Q9xw_n=;d%>rwyY{2vZ;;3<%C{K7CvqvI{$t^X{4!N_knZC})DbSt3QOs*^$gh-1f',
    b'ZZE)>ZMWz;U*0*Buj!x<w^@b0R+m7}=(mrYYm$n9aG&~r>^x(+`TBNAlQz_U7t|5Ml0-h+i<jx=lA?YPkHhe)9BvR(Qx2za<QOnL',
    b'_u7Dtdiuk2c3{=D4!}ac#8im%ms#BfqlLn7M4=;dPYg);iuF|KrYCu|r$i;In%oF9vf}=G7kz0rg??}p#IlCU3Hr^l_e~%E8|DwK',
    b'hiHw$uSB2Gc8-H{2xCl(ZrPOcwI4t!*G?46ox@=wePlz(lk<zS(^oGp{&98r?8U2@@b|~(&!3z>|Gx2)wR*V9S>_v`J@xl}UCWfh',
    b'C^H3@U8&K!D=L49Tf{elZV>;Qx;=LP1G5it>w=|j*1rBdhuSPCvgC{0sM8nEo}D~?adCpr58Ey2Cw0pPyb<;D&~{os19da^eOo@%',
    b'W-4(fU*tZXT%7)J{`!n<A^)4Ydt?0D+ZP}0_dOpZlq!Ow_eaJ?Q)*?o7V1MZo3_5r7OVDmMO@NHVKt6b%y2U`vw8F9C$0Z={jxKY',
    b')DACpw)OMJ%o5PmU|@O>f&!vba;c>Eh}aZ{OEnsWOP&hqlqeNFundk`(NJuOsnD>^|1fkb=$&=NT<9y_F9w4h<9<6Q<GZHjo`F7c',
    b'DMYU;I8Mq5pop)!X!#V?c`1LgW-c&pkzKz8vImSH%jN-?NApi-!fz~yU;K?H832f~^@U?G{bE0!b3pu!ryA%?fcyJ{Z@zIZUq1Q!',
    b'!)J>Et+wbPy(6my+I;K$c>e0a%_e(uoniXNGCaOIo&V(?rAOZU_`!q4HF@=RzCJqo2LIDMhOd`jAFJOC856sj@;A?)Hw(P5$3r`u',
    b'svYFUPn#0kFFvf$X8U$=Lqd0zE@F??W$GPTqTPD+INKuD10(Vq=YOo$SjR+8Z4z+W37pqN1*&TtI<I|ax4u~~*Kh8eY*jj2Oxvr6',
    b'oAn3h<ng()Wg{Qa@k;dG`5QtvTW9wcIXRxrxyg!mX!rkboz-H69^PbFWm~N95ajfdED(6+<GM9Nw3A^@Q4(%JPU^NExBl~*q`krW',
    b'TtiVu7&>IMty8Tx4u%4c*_J|K3~-BQz~Jw&y7-`2uXY=<P8g}}l3)8AU(RCtKy%Cix^O{_zb|*SuQ#xX=k3?$V*O#u+lo!UCs}}2',
    b'M0h5J!EPxd7B~C>We;ex!FZy5TEMBY`=sIUjU}XI`Yh3mv$<U&b`Zg_C{>;;iP`+_F<HRG)|}W~umr;AE9$>CbFDuBeOs*X^}Sdv',
    b'?<Qgw+J}%A3?79`6J%;D8Y=ZbWwn7Qp3h9efkE(5Dk7U(y_aCd*MQ)8@PP5d2Vw_)Kac{3y9}@W^~tmIC$%c_<H^O}&Mt%mte7kN',
    b'L5R6<9H26e5;yeHD9)2OF4L+gf)Yi6pJ(_I$mTx2LQss=^PtS)GD=a1|6LvTo%_Yl&(E-aboPpg(h?N$+;xkf3g`1Miwdkt<`wb_',
    b'te)g)<(612!TO1t`Eyi8c@S1}Hw`j;4JA=jhH36cy`eaL@#D)E&(EH}f+1<|%CF<dpI^SZI6L|A>g3|p`Q@vtr!Rhbjz>9v@%+j(',
    b';A{VDz8y`1+}nJ)D0toDWt%~)-PuNfQI;{FC#Rod``n85(lH;X+H~~M<-5U)I$h%nY()x8QkjRq`M{befFBKs?P1BC6T;P6;IVA5',
    b'nm9JMwfl*hih#1wY*nDMkEpoCO`JE{PgmU;3|f=fmCi+2!1EQT!YDYrVtULVUOxd~mR=q>cjrK|hhOp%$i(6ne#P8uj)Z4})Uq@;',
    b'%aWW<bv6RFWbGs5rv_j_cA$cNIuQ|HF10LNDtt4+UJ1K04j8EMlQa)hza80QV4DGl#`VHEKwu|L^5_2Iee0$63iutoSnla>S*+24',
    b'-$)hB85C?ZgQ!6qpf44)eTF!;9_jvk`kvm0f2+8s!$9XAs@<Ub=9wFBlzvllEvkD?l@v{mr`_@~=0%!Ag>pYT`h2$LO%9nyFk@{m',
    b'V!*AH@Nb4JLmOdui6zU!>I|5GqjP0oA^H_Q&OT-r+yG;PWJj|b$Yz~)*sR|z2PZVquXpu}tuq5uzrg{p^+x72D<;vxVrGHs=g?Eu',
    b'oDI&UCg$9hMgx_qpA4Fq^O%V>cc>Qw^ZM{a?P*klYUEiuGq8-ezYQgO%ee!x<cPwsm{>}0+S4$r*P@~lDbg$#jlJr1>qN=b>_#3H',
    b'^<p3aZnyc~qz*7ogRFQr1yY2`co8#exuzSzY~>(-S}lSWb=Io_W)xqKoU0tu^$L{eC)e9Iq?i$qyH2q%I8F8sfSKEj4vrjX4fH+-',
    b'Er|+#k4Vb%4JpQDK|X^JH&E)p(A!=b!k7Sablyu5^mZO&(!={efQadlSb*(L_nRqlD8fuxYg(EURXHN=!IU{#;cM86kZoqr01}pk',
    b'H}*mLfdEAh^`IMw9)oa!xtY3ma*b}8S(jA1;phx6hU3e|MG22kg%7qS7~u_=tvJ!V5O_z;<R>E_m&DmIrUxTCHM6{qRq%tm?`oPm',
    b'=+n^Gm%K^$w3JV{Q->hH!I`Z_8O81;xmBl8>>jYNkG1T;1UWVZ$dGI-qc;0q60dY__7{Y`y-cdDAb(WxeB456V)A=ucH*xTVOSnX',
    b'{Rj^?&RXZ2)v58`T;|8lLtCo)<|o!=n?7w$Ek>=5%m6*J{Tex*@zK2B@v%RtkFu@-4r^vRiT-J~xkcS>ZCUXSliW~)2B=_}J&0!y',
    b'dSkj9k4C$Zl8Q-MzZgkatgmmDXop~<2epjM9A^BG9P-3bM4Jt<W*6_;kLY^Q&+$VN-erwT#S)Ae5xOqpSY@(_2}VZU=+)D4)o%GR',
    b'`9#aF;})AJdRf<}N0Kn|T1c|dE~zem_mSATh%-+~;>T2m`->m`3Vao>tk>QzV3X{Il{lmITVF6A0z-2eXQcnW-E9cj9O47NTYp~c',
    b'R+zO2%Vsb4cC+y>Ui@q8XN-4bwY;nM67!T}`GPa}J$XPaD!ywcMS*U1<2DW6EET2qw|>9p`hCm#FHm(mmS}sf|I-sj&=WC%1u-NC',
    b'OS#ED927O59u;9vRD>2(FwO?a%b$!^)DQX(6v}LQa1=&8Q5bcynNNYidqYFq6AkeoH2h(hZPIi3$>%A2=zc8XB$}gn02d8(lQc>r',
    b')LC6{9!K*kPCVeFv9_WifU3n^>v(LeX+uK3xj<QaIAe*G_|E_3krNVF$bVxPl4H$9j|bVbPkd~EzbenU^<O;aTj*#1*jQdie?p|=',
    b'OQ?kBYP!O6o@#H2+RIQa;}a!as<l+-dT73YrHgFI9d)f%8p5pff>o3bk#5qWbxH%8-8lrChb4Mlb*gWXI1^my#ZY!k)mgr!@epue',
    b'#4QO}YM%f_H-jcTLXRv^yNw7iu)8ytJsqdZfo{_3YjMZ$rZDS{S*+2$9aHv-4DOh}eGBNAOn)@^<GGm^CZ}?nA9z29?hXq*Cl6DP',
    b'4hyfe)qop$yE*&%m_rdN3~5j5IMoL#?-}bsuDJf_y*SE%J|a5wjuNtL?g+j7)n)j4d94HBfkO-1)@xj&>-;cRdBs}Zn?q|Zu4OOJ',
    b')^eOftIAMYu|%7}#Cx?az%*7SsyIby6Zhi4@E`yvEjc)kMB0E_2!pFs^o9Bb7YA|&R`}5u?f)xNU)OibKmY;tYSiah=;X@!@xI)f',
    b'M|dIst_CUJ;QM{CBNFY_@q>q9;8fXS`LI~7w{>Xd^$pfrsgW4#rnMG#?BEU<B4@R3CC&xfn!<q<=J@zj9Q3tk4GdPozgbu>RV?+m',
    b'-97>~5W34JIbYq}?ph6$%h1&VEz9Y@<s2}Uu4y@R9}IHD75F}OWqwyvJ{iv>eA2A)TW2Wik3YSlfvl%5p1-<y@$A{z#nodVmi2*r',
    b'B7ZY@<^OoQYfM@car?vrxF4$|^3!}?`XtzFo<?O51zzrZ^Q_2<Ad5ocf-w)HG!MKYMsAV1E(+r?@p2D;Ol=VaI;;ai2-?sAZFEcq',
    b'>rL4t^{9Eo(<T!MWZ2W6`Pu|XJdbIM76E0-GoF-w#19Pbjubu?G_}J6?f5HlAEV>_z#3X%ZHv@XzYp=j+x~=jxCcLZB-OmyNzw9h',
    b'Bg1mvY_b)5o_m6M%$v`@F|l!D-ml-GFACJe0O}SolzxAkZOTQq+8V)Rx5zJ_8uZkJ<@JudBhaHtVf(Boo||I9Zf-W~_YBaBwUwca',
    b'J~e@<%I<r78Q=5No?&WK8)ol&;l4S%im-1wd+XbK;MoHU+FQ<C5M%Y>C%0V;c*0&wZ(q|s@p%bMe7;26#hVpA+Lts}FY#~re8)P7',
    b't+($P5fE4jdSX842kEDQJTXH4U$^*VP|!)x-TTjeKLsWxUyv7`WlvDYpQO2+h28i3p^1AhR*T)Dx#ga$H`f>+=A*0#X!o*Jp=aHy',
    b'UXYGQl$qO8KgoNZ-o)-d!LvSnbGH~zq=)#9*ZrXn_#zU3CwwIZxsuCKw7%4K7vavf8mz+bVU*mv!RmCp!Rqwi2CIJ?tiEuA)#;aH',
    b'u$os{n8uOo$7xj}<VQu2&gbbo$?!MN59Wy*=UzO|yedq}$SY9f=ks_z4^Wj<pTl6a#{A@Dhws(=mi+z6VvEmYe>v}y+{ktV(dqh@',
    b'@b^n1!VtpxvS5#luy5B(tTp#V{rEe*!-~@a@MR$`u_^p5&==_Dwp>`H)_VcZF3^7g0CtG{pC7`=wG!sb&7yh4#An-PLjNQxT;z3d',
    b'A<TqUyNiruo-RJS!WsE?YaPCQcNNwmeqL|hZBN&mTEG9q`ycc$FQ44*-mW)`e|~<1hGxy|dcn+aKj8mind-bwy-ljWeNuczMvl2z',
    b'R17FoKFe0<70DCc_ZfwDth-pExPCp*^GIa6uGaY$ZQdiUJDlF`hz;=2w`G)kxf<~4A5;TAKz{xaY41m-?f*X8zRWh+HNpt{VZGf!',
    b'x$!UGW*e-m*FpY5ey@kGeJ8{GimZ;_0CgUEtcX3_Ev`|M7@sRySb?`YTzBU7g}kjB+(^B62{YZTnrhd!G-Z0l6B?JxX-WLDEwDoI',
    b'1DJDcy)0jo@`df!-{q9$HIb6T(`4+%YTncH@2@UTU%Whn5{CPw>xYFG6-ku&RaBJ7k3ByODz{3bD2wJ<o(68|rbQNbZbI^(7JiVs',
    b'aa@E!iHhT%^JA?OoZn01BF*E}OR6fslNFgChkjTlMTQl<5T#W-ufjB~g3?2-i%^8}qzICLWZ5mlxNH9JU%WoMcz*Ky^z7>F?`Nk!',
    b'wb>D`i1Qqju$(E(P){K(xjDnN<}$4ZB6Rpzn<E#5j$xmE=PK74FelaIX*X6Ys7EiVQv;@_K`Fr@=V-*+KeB{?Tuq_i92tquqvj{T',
    b'E0cIQ>pes#;HfFL3*;A~v#$=X1I4La*?Iu0&|`zFl;Fr0<@Z1wjdt6?gHjT~<5`cHZ3Id#cm&_#V{S|>#}P0avY<hE<JuYa%ue16',
    b'WJ^`kl9IlLHU`w3tH!iLLh5KZHH~%upyl!+#2_qPxah{m;c#NWi<VLw9AFA#%QuDr*ja%|qqJo$<<;G^jDpQwC&#AtO_mB}ZnZ=c',
    b'T7vE%@-PG(_6o@xg3&-=u1X#f5+q8AOiSjX3SshBD&Wy?r^`(B64&H3__HXh!7WzkL(@W7{v)2d^mens)J=DBGBwAXUJ^ih#Q^}q',
    b'pjI+Zsq3cGoduE?%W_;i0w5(GIwpZH#86nRzSxZkiJ(taw%qo}NTgq84N=zNNQ?yaG_C>x8uNZNG$=;%QhLB&MG_Pn;BA5i6X~&M',
    b')RX;ihEifCmZ90qpC-+56wa2k2ow9Xr$8EzN4i>UwmZGDrbaqIrZZ-<k-4(WUiS}Nw#F-W>_(&oEDw{l24(-U3!w6;v6cm~&9SFM',
    b'HYj`9mms8>I^K(XHW)i!w#a50ZX|1q{w;Tu&oP7h1K#$%>NJeaKiK!S#}rxLHAl@aV{UvpMEetP=hG(Qubo%FASvK29(h1wbERyZ',
    b'#yaYi|4W=NMct|&G@LE<U*^wmObVgTFIJuFsE#@+$YYJ^+>xAQm+TmrEh9&TxD`iMai0+PR}ADjS{}p6Bj^de&i!FDk_cn7`>Nep',
    b'ay#jth24`I;2+R+zPxiLUsEhT+-4Q}S{0b2;hk?EIoHc|RuVB|Lf=8%kG?yV?~vw*g3Uv?c>^NcD^`28hZt<1s_mt74tB}ZF47?f',
    b'yA)!V-vNs#N8ERgr!Xw`b8UvJ58CwTI{UbfyqbdYYRgU^DVvEk7EjeTC@+0PkN!jf*UF)cqNuaWHgC|5*V%SJ!=k}9!_NE-eMTO`',
    b'66oZEPd_iqtuCrL?=yHE{SSXI@a)flv;U#ziLM)(53fSG9~i-ohp*W&ya69%QiF+yRwsn%rQxtfB4O7EnQ5xN9E$YNNNkriHIOV-',
    b'6F!-N5Sqz__vJ(28b(7?aj*juUB^an1inS;sS$~Xopd6M3LC+vZRS&`ni2@6kl2NaRCPV?xN^P1TO{1v^x4d<r<hv#4X+EiC#u*x',
    b'-MwO}W%6FkxcuG-qoYwgS=n++>L99`;!wE7lbTLj!2)-GR`aWFKCQ9d0j!#ig4sLBt~p>9&dLW6xT^^K9#^V_`j$&FX2R#S;h*Ql',
    b'-kVUz)|>+=`@pQx_e1DR<9;QoHCoC62d_arPOa)pulKJ+ZCX&E>6)hp-g$#&CRI!ux68Wo-QlXfeUkl8Q~UnQ@fZLxj9Q{m?D`Vv',
    b'<Rxknl-?gN5GMJw6oBvS{WyRG`ImO?e+PZ>TBn}f`ewaczqxa=RoVL9F~gaIF|f?&EZf>UFJI$JYT2ZFtJBqPkLVO7dhfh?OVUhk',
    b'7VqomJnE#k#j7Bh$Less#S%Rv`F|VtzU^_H!WYY=8F2(8X-$`l9N|gP@{X;)%k!@-&LevJ$pL$+r=lL7*Xch9#O5_K|Fp`O?=@=G',
    b'fuc?(%XS6qHX^&LaV$oItg<R!1qP?Fb}iRCV1UL)xZzh9>m^ba(Ex!zwg3GA7|xLXTI@pmyhp2@qw~;~XDSs(I6!!r=p(1Ey6wrV',
    b'N2AAm8l6J<Jez6ssxEq?$9)=|nj3*OYig@@crm93!o>liv1Um!_FA_|x@JNQW{lk60d&~NuZMxW!;|yb`O~x0f1Ex$lX7jHKYw!m',
    b'{Cmi=G>p>H^H5rNd5KWvXDG|P$jjU)k5HBdag?}m8dR9^x`CG`MVg{AN|UrIy=v}<-JY#HX7b6|%d_WC&YqwC!v>F+__<dUrCVlk',
    b'mc_0Y1X1b+ZWW?5O@lC)2St|T$dBWB;OAwU=UE=3*bU;i%KfNy#3bsB4iB;M_=$J*{n_)g%k#^t?@uoAo#jRDmFv2_JD*%$J$?4#',
    b'#Rcv<XFWep>ga=|KK=}8n~U|PJMZ*npA^k{*!d`tQ<u!H3bFa|16!=PBA>Nmkjv(2R%9h=iXp*=sa@pN8{sbIPNytNvK?4#^c?@6',
    b'fvlx=wavS27>9;-JUd#CsQG?A%(DXo+qXGq^<Z#AKu24+uX$;=htLyJ9Gcjg?F<vR)oo#c_QNEpNl!QMu{p9C0`*=Tvp}B~Z(1(_',
    b'rF*5vw&bYpm-c#4PVLR!iLZs>jIKgj{@=QGcsftL7!C5ih6dWp=SLsV$lNmdm%S>a=6O<jW#N|@LM0YU3KG3i%#$RIi=v9NxJa>3',
    b'fV_E}xw#ufX_0uy&*mg;XH;hCxC*J`7rR$MQ{w}gMAc*~^CI-KAQ|S7uMe}I7nm}fA>K_AFnaiFS!f}}a%fQaVHL(jQpJg1#=*SI',
    b'5s9su=LJf$!pks~ByJRta=HFIOp+>eiz14UhsM#um}Pc5Tq)l08bl{Di|sc%*F6De1O=HYfe#`_m4nWNvPjdtN8&Y<_8*BCSsHXm',
    b'pn>)}Cfb1A6_>3dNmspPP6SQYz0O?d2Vs;2aezvq_Jv*=#d#9PWs23mphOW?xU$p_vbm21Nvv~4QGnGntPY|O|GOG@<~}>l4tIb*',
    b'$@-3fT2pq&`!IknhqBGJvIZ`*@fJ5Z=XKi>KW!ZnV*w3qf{rp8gA0GC<9Ag5u#`C2&`Ks7bS3{Pl_=R9sL+R|>5@26Rm(CoKbM1W',
    b'+6RS~S@8~)QdY3<zkhl4^-LdHe6rBBX*@n)Z8G%WdbK0@XVo>Ozn7X3=7orDS~>(uZFFU&@<(kM@@D{MLj!IFQz~+Im82%d6KY_W',
    b'pHTso+hV4+ny1ZXX~7lk#Qf>8`O~Qy!g3GKx0nK_N>q$&aXR8wVdjcsdHU*p<Pe8mu6L6u=>E_*Vp6c?)|6-o+GN$%b&J9;!LN;r',
    b'N&_1)EBqpoghT@3mj9}F<A=g{f&*VYpg;}c_6z&{tLED;40lcCEppuJ;Y=w8yVDDv)M*oD;|F-W?*ONAN<-_qIrm1wr9oafCykZy',
    b'*jYG#ae`y#&wpO11gam?`dVmq`j>?;IlV#nboi6h7Pv=13llJk)o|0LgR~GxPN8IE<6wQpvMC@vMKxxZ<wJIbA)Oe~KK2bk>Pm6h',
    b'5r{-Mn0SgX0__X8=@MVa(tE~W=~_j90ac_K>bLE=&YztH%)Ehz#&JPOJ)Rd29i$|EwiYe}qy^yUyT9t6A(=oQ_px<c&o=I3+qkFJ',
    b'aedpkr<S5|P^~mc!LSu$>r+MT9wNiA<bw%we@SZc+XDk_d}}5YVW+<}Z@aK>-<mfO@O}8!MumVI#J4u;0z4wVwNZ_5^1n4l_i?fE',
    b'TgQ_>R0}NX5)Ykk<&FGZ)PU>(=2SeKIZW!CiBQO+2-`|@+Txv}5DoBru`-4}TReNvlZ{ySs?WBJ)}k(&cjU(NsH*=ub4358_HSif',
    b'&Ju7q9O-LF)D<94ivGZTP_;$y$<hO{zEbq1hJHtyfW$zTPofF&y`noQSWoB=hKyYDnN_-ueyHTs<bI5@pmO6pA7o{3yYFRNXTuD!',
    b'JGLjIE#A{*9)^1F@v3Rmz@EPN>G>0?gW;c_Ts=KGJ$Z6=_1gP-I?j&%8SyjtA+-M~<iz8<z~R_ioGtIAuy0?9)wE;s!PUQCHHC?V',
    b'Y#|c>kSjV;(~8wY2AeixQevMN()?iRgQUCG=k{^CCs+)FW;)b4C-ir@zTFh)Ddp~}yO!|*C@ar+7NENSlh#?=O2m5##iPVu<Lx`4',
    b'mpVTn3eiZCh4h4RATdq5-1~@Xt#|DR;57+|)Zbc&R^$^gqp&T<kST>5z9SXEK@c9bjs4S~zzlBILBLFIMCy_QeW|<n@!mi`J_OK@',
    b'A)wcF&3YjpC0dfmfst^Y9s<r&Gn~P(J*Bkb!Qak2V}ARs$G%=>&%pY)k180r3}opZl_RFpyZUooZtaEgiUh(Q{>lMvLCgJSv5IJ~',
    b'wId8C;DhWi`-=YN3a(iseQTB;^2`eVYFX!ybXEtv`?M0p;`8OIS~r0>H|?XQUfTeO@+MCab%0nK;#@7)>n13N)I=i>k#(XQHRJ+P',
    b'Y6Sp@NUJ=wa%S#KT&(ZVf2POkL7(Vv#WUbl)$wNV8*vY$fe7n`sOjJZ*X&e$r2c93Zngff61(b1FnOO_Nuk_MjH_r1MDVA+aw{#S',
    b'e(+o2E=@}*>oorUi%TAtKqq?*tkwuXqt|wKX3*HN0(idVz!_?mWQ#5O9@y!Iz}4aqhGGhaU^CZZZjv5}TluP<<^5u_yA@4H{GK}o',
    b'vQP@w!rsI1yJPQxBwec4Xkm}Rnk#86d?ppH|9IVnG4S^nScv(b=;j737c1wqi9dZG9)(99W)Zu^a{JAKkihnamhkze$(OTUP9MO<',
    b'HAr04H~;Y;51jv?L9Wd*oOR{w-Xez%;gImEGTV^Ex+H$HTC7N@?TR!Zec$eOH`{N&`35a+wnqs6xIwqqN9)a-Z_dtNUXq_5;!%FV',
    b'fBE$Yw<lfBiH<|=CgM0yWGfbsi+GwE0zeZH+dQY>JK)3HMe(-oK?-a*c@4mS-J;C`gOuMnYcf5??{5_J)3>O=^!NLePyBSfad77a',
    b'pFgAO)E42BNW1(_ntt=3nUt5kWGA)87x}|*cENU(*xd<7CW4m$I-h4-<Fg%<V==$uqy4AwPW_)p&LxJ3bSX$trY$C0B1-VK{V@Lj',
    b'y<LBJ*dp&C#_z)gr>&Cg2VQqgEWh%BcWY;fGR*m|iK|$auWxq_9)&<c)Q6HppkSD=c8Rs~Bi4&|enplpR6tuUo$K4}&bh^1mvwCY',
    b'Ta5a^bzIja7YFbE&0ZyT^z2mRP#vV$OnZXFGBMwPwRxBmW&O~6eND2^=>=n6W75P8@V2kktA{MEnvmdo#C-#KsTfvOh6=6^H*6B8',
    b';b3^@c0zbMxg2V8$;rLp$U`^1ud_Sn1F0c&<eaRU8MD>)1J?htC7JfepDtfH&tJT%ho(X&5C3+^(J9}PThPgxxOPnVcz{Knc#qv(',
    b'q?jZ%SJV;kzVBeV$d(_nI}$PfziZ3Rk$Ax1U@_cDK6<P~4Qp}sp3riEen6N3Z*cqHG!^}Ws<ks4DJd+gej>F^>0wYlH=^2Rah+}M',
    b'F4?*->T+*zi5q;X)`Vg9YW%(-9NY?@+@0L4iTr9S3Ze3}4qaFMsDz<-K8RyI4K#(QE+r+m`u%|g%P+G#k~>R6Gb^`7b1yz67t+fO',
    b'!bp09lxgv<-z>8`Ym@iF`N5R&ac63{UA$SL&CAVtT|LIMzO;;Vfws3x<3O0G-w?~>Da&SL!@}x4T4Ji!m*2eC$@E0hSJA`X{%)e%',
    b'xAlJ<gJsz28pvDY811gy(EqZPj#c7*x@+4W+lJ{~b`~Cmv(0X){J4)nr&I6HhT%+6v<msdhv6>W^`e^XnCNuFOVT-r{nk!(td$bv',
    b'tcdcBQ(_CMSIJeuwuS8~v~Ht1bdz?r{yJjV1$(2S13xCM1`f(JLj%D44NM=@TtyL1<ODi9@+<QWjG$oG2X6yp-lZ)_lC)bxPF@*7',
    b'x<RHfZ*U*-lO5Oq&%JB3TKdKfwIp<c#f$=p)*KkIPn)2D#zi433Q|wGiwfFJFrBY+8XaF3oj+qlJB*HLCe~xUVD+XJZ_XvO?oS<-',
    b'?P|7?o1nyRqIHVwo$-J?Sr@lNC6JGZKHa#(B9HUa#rc>Sq{w&!*^oNb_);e!3i~5n4#h9qp=XxkGldu@uTNi>0|yDM*{U~a#pKk%',
    b'@N#304T6*2)6azL4<-6|AcjUyFwBeUR}(mMI7y`SEX&bS4NR%iMdDG>4VFOR&eHN3E!fykeMy!=4Qif^?Y{O6gxYAQSIK$?Bbtgu',
    b'(6upy^`~{V4q`G}tMBWrhLYtkvBp~5!EKryc=Z;;@^-!Ku}#ckWoVe)FxE|{1sh8<3y1Hjv)KtFrc;1W39&Ji>jb2^_QJK?aBpt2',
    b'O}WTcB!KB&<c8Ls&8OOe%ih5|!YKNBLA9Rk?y^=L4P+#&rllnF;)$G$>H1>56RNNsTyVl`0%@OrU!f01kqR%ppzA)vi-x2aVbv#f',
    b'$?|NuHL<i^wv+B;3ub_#@)vcvab19zwJDN>Uc<!-LeR9Nc_|4J>p}tBxR2=O7URJzK#jS?@D4Ec_q}o*;V(2dJxOhJvJ+u$;IIKL',
    b'R+bk$cn$-4jZJ1V7SJiAb(DlM-V%_?Bske2JREvcPTwShry$H=a2D5nv3E)uZx07lJqQ_-^4$g~JST?qv;(xPy{*46!00`^BW<Y>',
    b'tX9S*TJCU3s8Gy++uNKNDF24fgq}@`eLM#~F)P?5ZBg%bTTpE;KHIHWX6=$q0*2fal`5QLv|W6zYFivWRc20Gq9uCM>_)38w7&~G',
    b'x}P*h#Z#gZ!WR*n62Yo6OcbKv!eyZaf|0RW?;fK{bL(h$>CFOzVbJMsw`hA&CzEYnc_3`E1ncX~6GTvdpVxXb6)1J_kMcPYFYQgX',
    b'stwg9qzSo0%lh?TYo=Q20)#gfCRMV1Ws8vKcB2O-{|{K8xXkF^zbAkmz-mCKk1e`oT=fqYmQ`XFkKwqJ&&FsV=;m-`gR;MwK%R>N',
    b'F*&O_z!Vu+v|5w*7<`l;6ZbO>(3-#00Tu6o!#o;bo!DS##hO^}yCjeL#$D~6ZV>t>VpbtopKR_IyyTk6jW!l-1VfPJ#YQK_nrLq~',
    b'h(2Wi<BhWd(f<79L$);SJGS;<bzj5RM8?+uPB3b_njm@M;Yuri(Y#k#;A0O}hh08@pgU#n1qT^je1yJ0+x7B2Zjw0_(Mcb2e$hT#',
    b'vT2An0C`j1;ya1tL~mYocW<*DcLH!0yQ6jv@)mvK{1a_(&)XZ^=^9~;*!fS(i|Bunhh7XDhG)50y(1Z%6*!Jy4Dm;>XSmm-$J6WR',
    b'!)<)|o!K98fvX2g2PJzYq6W$?uRr@3f{AgQ<*-q0Yxcis7sTEZi5HmmBU@Xy<C59QLL|tSh+Klir-6ApFgut-Vi;;)n(gg1_3pV|',
    b'5Vc^N)h^#8K{#>EBnkc*&v&lZ<?Rw}jot;PZ0O&#D}!6!4)Hdz*iv&Dn+<i{KR0i)Es}nyyN@GUB8U`x;+ZICk)JI0CX3hj5rfJA',
    b'zc;WAQ=efV*Vl_;%jfT@x(U`4LK2F;!bDb5n{cKLSpN)-g@?d*GkK>G3S&!Dpq<RD4t6Gh*VW4pLrItIsGW2~AW;8K!-qZ(DG9LO',
    b'C*(TPF4lM1a(72Xz>~Iqg&hc9F!n^+`cY^zVdRwZseVYQvg^h2PW)wsJ~S%(V5FRia&d2@>>(T13VAb+ur5I|2g#?d_j`fWb<AHb',
    b'GIFC7hqfJVGU^2>Q8htNYZ7VMiU5KH^*%SC$<0u@8mZRsa6zbr_}IPYMFL1j-cG(78S|s{Ziq`LmRr`lbwO&pk(x7D2}f#0n`(W#',
    b'aq?R%;MH0fa|hcxe}8d7gg^JASEPOrME+6hvCE3))SjJ0Y|F8ZTfBAF)E&5S8|2khYWF}EaZf$2X2g-O_71Hh8jN=}2?W)h03kah',
    b')kY6!wB1r`t^VF<F^2w&JzaijPm;Z!`~D^5h%ey!64-Xl<|L-{qzNo*OihH<<cL<%s{P!Xk{CiPIA=oE1JAvAwA0?S;MpF=`Y+b7',
    b'u#5<w+<7rm!dhvh-(<88Useuuf>ibr3;S5NT{3PhUo?^rIk|7}1(97#cMiC_sv)4|c@03!^wN}Lqqo^&RhM<$I_|^Z2=`vCSIPkG',
    b'^}<IY)b@5klwy2AFHHl64?XXwzVSHfS?M-90KR#Jo2&6`ZyrF7X)C@&r>^tHRDNPe!8h&=-fkY|u|;%RE1}cW2BhMQ@rJ9K7_hb*',
    b'rrG<tV7TA0=QlnL6=(s=^j&Y$9*nmE^RYxNfc+$-9?&no1DYbpnrIb2CT0->)O&<6ftayLB7fZI|F(B+O>HDu`n`We#k?$zkm$Di',
    b'vb{s}MqrTL#9|--dv>Oy!z!c_)LN(%suDEYGyi?hE$^A7k^mcT&@XOORe3piGV@%&0}K7B&+tXfoqpXDvvgy^d)4hsF$!C_>h0`}',
    b'YC}2zDGXXFCtSd=77!!+>UziUD*SnujVltw@W^d+XPS9oCylSmx@K=&KAxhmM~zZ+XstibKcVnwC4NZQO_t9w0zv2^K^W*#&+l3|',
    b'oC%?9bi&$pO*i$53hQ9W+D1;6K>C^wYYwLmZ(dXDuI)-!Z>be}m(R*cQG0@hUoDPv4Z_ycg2&vg?aostGB>Cur~IiAF~Xse5hWru',
    b'2j9=~o4lM#;MSW`f=AY)u1~j6j_gMNm^&w|p~qv3&0FoeU!#@zfZ^(D7JoLeCmw(0(t`?<V8zZv{ZN%(fTVsq;Vd>H#tlp+@rta|',
    b'4NX_P{V~_V2RyJ!Osz2qY_YQ=YS!n|&Oa5_72Vr*rtL)W&w$MWHAq$_L7>;NQ;kbd&XedF(MnL1KRC8Q(Chk~=(lv(67K8i^dcX9',
    b'@;owo`bt5b;q;jX7NnSgzz*FE8FK_H<br~AJ<tC07iY%~TbIh+8Y`5PkXavu=plcH8gT3^dK5PX`Yp10$=4#PL~<o7ZK-FQ4cLF7',
    b'j=7c#Rb+=hpL1ir`rMeuOO<-giuuY?R-R0Ny1KT`p99sO1JySSRDU+fKbz#AbMn6GoV>?Q+x;qYS#p)#UoD$mUc!fqeVyCQ+Nmr$',
    b'pt)nlYy0?mR#_kO&6gQ9>yIh|8zgK=N7#z_+9(8VjT{bq+Q8)%H4h}+bhQjdM)I&G0oC}XCV}Uqs{ijvRUW|>i?$PY!?STD&E6FD',
    b'@#veav{~k>$@_XX96l$)Jtx9FC&E1^!aXO#Jtx9_^*CZ*V@lj}Vo%H?c7|q)F@p70Gm6f_@J!f1Sp%J$U_pdNu|o#MTc!c`>y=J1',
    b'AA8ls3;p0H?0tA?p*Si+DZ|H3q+0c&h~ROK^LZ12ZB!31WGN2#83izmv?C#yH1hrO5(u{w4>I9b(Ac+=6vyzG@*A;?Ak+M=^_9?V',
    b'+x8Bnzr<%{UOJwRwba%2-jS8_uqG_3We=wWJ`$oMaIN&am^gO=DOtXz+jPf|iI9i;5?GabekSr^*m|)TVPS!{c?}{$@VR-astdTU',
    b'I2cXu^7_+GYaEjQ)L&NbCBckUTVo|=?4D&=if%Hoe@0lannsw{wtGhV^WdqDVKxi6^_{*uk%=?c0@`ZSrdaO>l)-Uc&V%lL2F-O=',
    b'phy_biJla9!AjS7HaZ*@UQVfJ`u2?t^UUDo#^^G~<91Zeb4105n<m^nb?deX&$%v)r!RT;)N*|D0g1+`O;!iH%RmKFFN!V?l(4fY',
    b'{`Y<{=7Wk+xU=2Y2X=gj1DjoEFZ-`v+R@Z$Y;92J$_xCtz$mK=%5cS~5-gw6A5E*e1#kP*-rV&rg(I(V$6B7sY7QOoM<yINifXK}',
    b'a2ej%C^GH=@|*RhZM3#ONS*-B$NDYxyzcoZ*6Lk99>KgQ4uAco?eb5)q?&twdXRpJ!x-TeKRu)cXCf5G$qVGuzm4qv)B|Mg7O8Wc',
    b'ku8eJ^1ht0YN(G)+}pCb8ZYwOwaA+s$pg_<ww%3bOrg;G(f2Fg1&=|JfaM-`m``M{ic{yr_D8f2?SVR;lvB4?GW&n&Erz4o^&B5x',
    b'dQ5fEoJ9O<pJkQ!5ubv}aQH+xmkO>guC-TLl@$Msba7BWp3LQokNk|-Cp9<=CgMqr%LQwAQbXfd56k)Sq;5A^)`)-MX<fo9$yqcV',
    b'JL~!>57Ytj*leIwh*7_yF+Pe%o6uLKdB6I;|HJp6TlIduvFgo)j%TQSZlS=6I(ULdlF5o-W9rwSCOsxq$So^{>~$Q%ley?H1pSE)',
    b'4rFj1*;|!Vu{JB2{0#j{Btzp-_e4d$Y&+omiIA5=q4d4nbXfWa>iMQ<s<pb^jPx9h{3RwRp_98#-r#2=t(}&Jk#wK!euB<|Dc@Ue',
    b's+S-UzztuFO%z7)nKrMA^C`|$$jH-DIBRw%OT5y3FIpY=B=HfSOK6~Yg@G6I^P~iu5qfW@ks&_*zLG=ii}YR2%BIw}*S>_0eQDDi',
    b'FUC4!dazR+;rZ4h$HrZMRl3{{KlFe6_s^}%?QN{f!MJ9Y!5K4_VT*lj?lNURTOzS2dgr=$1mn-6&w`NBqs#F*q!!YDOy^%4`AC#D',
    b'!?#lYKF^WJXYrRCfRgdQ+z6P3P9izvPtZ0aR!tl4_h}hnStmV-XKH=UBY_omJNENwNu+SGm7-w&O3;jV94dEORn2G8G%+KLJ1xeC',
    b'`K+KQy)|iM$M+c%o%*p=F}yAopQZ)T^FEZUKn7Xd6dEpc*`OZ#1f{wdr07)zVwR19G|gdNSN)rp*;@)b1p)4DUS}uyBEJUFbzy^3',
    b'n;$`}gU?F>OlvT9T4B$kWOkk3F&Jk#!*V1w1(R3H%d0FmIEEnB<#*Vb4tDK-cqK4e+t~>s*Y-6kRtA#F;u3?id)c(QE%09K*|4LM',
    b'Va~8kAVdnZ;uIq#34xI!bMod&11lDP!0JT=N0_{x=C4SsKLh-)lVZ`It9Mi!ZY~NCNFu!$Wjye&;S4^fA}bhde}Uvg2no0dnhYN?',
    b'E-J0o7^Ztu)cSk+Z}_Pgjq*>ge*9_cFF*bG>OaoTPY1j2KE8c>^6@X(KmSQ>yby#i2|2ZA#wh+)+^NVK_*oeEiTDe3S${xa@bKwm',
    b'T2%`_loX}&<)W~{O#c-EsqN_;1dzF_2LC^U8DyiYe0Etd(%-fP`e)DJ{TyLlH-`Ds>u0Ca`9PCM{uZRbWTJaD9TTl00F%XS;t5eP',
    b'iQ#vk^DrECV?bTp#)$35TiHx4MY>as*Y%*(vskFt%0h|B_gYxUMSxr^V8#wJ%s$PkTa#;Ojqk-y;+x$mBEsES#8~I+gBfMQ@IG4W',
    b'%cII*q3ML6kt#&i+FSUYj^|EKb7bY%NIP3A-i9F#NK8hUo)zyNjQ>$As#R|Zv3KY5X&I-qn?)zN?yXZozIa#G*LgF#lH5WCw$3TR',
    b'D&~FEEc2;K%8oawb7ORaK7P9gUr24r9UX7d&ZK#`R_(l-hig@NUNI0G_Tuf@41JoHbrD}yoz=)WPkaId2V#0?*z#+H)g1gWDhdbL',
    b'^&b5tPuf!v#}MOO(&6%1wwxJ|!>sf{QZJpYI;o=M+Z2M~#+?8km60RTMfI~VxSShTAl^~_&o7HU!ji&_xa0@S9oE0uVA9bEuSm7z',
    b'PUA~p^-6g0BpRU*gE!q`tgg2B0*vdGkoy{bul=rdWmC2sfT+U&`g4UWIwhPz{GiSj$gQ<MI+M?(5Ad!v3S1K_iOfB7>Jx%50+;r$',
    b'K~(9#`oj{WXegf4c??p58I7E@B(H-WjpkLX)rNLhc#povdNa8%Q5ek^UwONN4<dVA&;0?jT0wBZB6H)&{HEok7~PFvLCGglXY+D4',
    b'lTr!$r`dPkefNXWCE&lU;kX*r-{#}RxA?4|kFU#F-?Y1ZJs$R~9{E1X=v;oW{Y^1jUR$igPdVFN1n#5bqXA1hXM4X6_TL{4_W94f',
    b'-J`w1q5gC5--EsP=jN}IgH!d#hr#*rVBaqsf$K{(e9Bo}j)4FXYFyxzk!}6<_V`18ckle*_^5xd|2vFZsR{ZEOx%<aD|w^IK@F3P',
    b'E@vO}Pm-EgJK2aj=@pvW2bGxe(tsy3qr#|1FTM$2q4e9_b-#uy4oy*9!l>l94}8)2R7v2;ujh-RPuw7e5meEf78J9lTfiL`G~q4C',
    b'8KsX$RzYfchMZ`r+i&2sqtz<la33O#xH2c@q_g7ats=iw^J}0AYqlQp=!f49)!Gb6g@<zlHhDFn#;Cv-^AFwtB<zC(xRVWOiHEv1',
    b't+gU2(X*@uo@btVy?eg*>+jhDwnp}SjICt5Fk>b53FFBaKKohdX6cg;#gZmXGUU57Po;U~n;7Pb^Q*#IndnS)lM+q2L*B3Y;&Fau',
    b'OZwD*8SVRpH%$Y`zw?cyscC<L`}VbkqZE{;IisqxePWWDPe5*pF$6+><|-|>3xu3sP<=Aztc4kmm$)scd#QSh76I8O2m7ktEf$f2',
    b'bw%j~t|uM=abS|gPGwMkJ}MjObL~qr(Ic!j-6!N??cY|5sdJFg0&s?Q#<2I}C3S?0g)4NM-#JTN-+@qf-B%qVB2t5vjJb8>4Q4Rd',
    b'g3XJciaTZ{T79ZpFx;}%uP1BP)2s4g$n}l4O}}&?BCH14+J-NOEZj=yivF^HQRM7w14Vg(UD5Q=nmBxA4n8Fr7uRzTzO;>Z#?_eU',
    b'Mw)<>BnKuZo^Z$CQOBks6d^@=(}SAHELDXik^E&4GH@bwVNQ1U?d|MH{-l*bQc_94QNCC(Ar0;aeGnE{sxz$VlZ}f>IWzPxokD}j',
    b'Eyq*FRlHk&+qE9m{GyxJ?mjzNRG1j%?w_AC#Q^qi*78Jl{9y^Vx!VK%u1ZbU(Y<o04e8-+KjJX{EJs9>iyUTHI>+QoI~L*yi$Z{a',
    b'aj?((z$(_UjpyM{$WWj!lqgxC93!^19&*S<Iff(DvW=5Lo~lBka+h5cbP#ZE{`NQ1@?wD{y~Xw&1D+^qXC=vCj%tfGS0B84H`qVe',
    b'Js*5LKY07=`QYf_=xz2(_T5hFSNns*-M<g^KOP<*pQ%q?wtsRyIDL0;w0rpR&FNt9j{$t}s{MnL<AWpk=;P_&<ZyRy@NRH)4j+Br',
    b'{?VKFNBd{+$=>mY!Rg=O{U6%jKYPEoH#j>xKK-~q*gM=k-9=#xKKn6xni@bIbq@9$P~ze2C@(M3o3O;=OLmt+G(3kl&iRE?6s!Jp',
    b'xu2i7TSK<p6ul*5+h9g88<Bz8C1K)2gY&p;WcH@lyPF@KhnrlU7~GP`kd!$~8IR-R(qlTK`$diHwYpu@@Tjre5<NE<<inEvV1Xqq',
    b'7j=p3Fvjv@v<r2)yn4yz(k#bIUW<W!meXz5Qac4CG2WXtg1ekL@Ji~5Ils_1?9SSK=1$(k&T|~#^c)>=uvsK03M5k<nD5E5TDsBj',
    b'CeBoJMLTyeib38vGED4^gBf~3ss-aInQ0ke%6;vy$R~RS6sI$5!Q53_^00OW1kVNg3$LWwr<*u;%EJ9ht`SLO#aI#aeFgVjP;%7y',
    b's>!F71!~oDbHhNa4rwrfTAN?GYOP{UBPb|Q&<Gsds3Q}a;ybKNax(;hdkb7!-Lk#2W+@1D8|}QVCQeIA-|$u9US?^f+zkEjw}Yeo',
    b'<G-E#9&-WfX${n@{<N&q=<hfYMa}hl;FCS2mW7Yb%gd{#KnP7fYuesWXHNJIZ>CfW{51Zx`wae_a4T<=*s$eEU_t9gB<P+NqXPcX',
    b't-H2cHX+|$6*F0WBnH_S(d{leW5Ly?kyOGKVl)*8fX$qh<ub#1y9Tz(3^6%`9OdKw0(Puct_fup1o#>?ODWHYMY0|LI@;UR;v-kX',
    b'+qS_M4r}25Q|kzg4<An&#Ve;=2HEmo_-cPIaRm1~ak=M<%F3J3PKueHQvbTZh&OKvqVouK0(t<omNjbXle~r@G;+98;czN#ev1ZU',
    b'BzFa8{0zlPTl}>NWcMmoZKJXijRLiyWp-o%)TRgog~7SneP`9OA%iG#q}V9xqOpf0E@bP@zQ-7pil__}rker&Z203f`R`V(+)$Yq',
    b'>LJJpAdurun&&0C{re3nk_FG3?SDhN$36L$t~1A9N?tN}D)`>^Px^yZL$fC>XZS7I6j_zkD)L+qK0~&;%5MrTSzkbV^X0{~tf5Vq',
    b'+6V#EB38v8U&Q7Ihs25cc+0mr|5tIh`lQhEmLB!Rw7M`9C%qVU!O*s3M``VNXKlI?nA@t6n6Ng48~a|&On7s_iHQSYZ9doAKQ@H(',
    b'syc%cv)R1+f2*@;k+UQ!9cANkGQse#$)dV;H&c8h>ay907_g_vOkxK~$O-72CU`TMEhRVO+S7(T8`WglpTZnq`9t%_0jY0qWi_G0',
    b'hkRM~c!5**)Pu3P^0!tT@~aux8s57KZ&`h^vpt>XB207<-gx6;1OojSmE4N1Jl@3D)D|(I*m>a{&#7k5PohlRA+TW|dBU4#S0Msf',
    b'vY+3gMZ}w&q@iIn@N68e3Kj|1zB=btK)3BB2u1ebW224*oCKG+tXl9pQ_l}>vJhaGwf|64IsVv<a`6!!O|(lVsel|gWWKd8W!U@p',
    b'CultRC7JC-b1p-!pK<+bec&r;f2g?8YDg`85An!f3^7S4!Z_9k9AC8o*Vv;kW@vCho#fj^aZR;uVLuz5K!fTc$~U)*3O2LmuYO&S',
    b'%kidYm28}`ufsb*MJlcuz~dkHvTi|6>k5N-z)boC)O5L&z(V`bi^<0RVq>;feU;A(;$5;#qPbepxQ|6_t$jMj80^T(t05(qeS<?W',
    b'wt6j752mU};qi;bA1PjNXR{U~c(Z&=M&MxOKA(u1FysfRru{i0<0={iwDD<@i-16p;H#;EJ=~8h4@wAk&NBYnJY4!b<dPy^fatie',
    b'6gO5nRWMc$gW;#kv1kWsV!N+*(~6^t$_wKBa=$>HB7pvZC%=}&pp;NJ`r-Cjn!B=IE^aUYJ<CIZf#aUwSnV@!X5`1ZV|`FJ*;iDM',
    b'$nN-*m7eV6(CjbDNfSo=8483tbURJlt<?F7R9p+x0WA?!fdy<C5|+%VW~9A<P^IEw<55$703$WBPkRwDC>SA8gzAo#o7j{t$d{af',
    b'e!i$~ksWc##>AKu>}BeWH&=Nh(qb^7Ny)dqS-$MUD@AEO?JKMo6JP3c)rSr^)ivVOla)HLc8imPRqa0*^UR3eSQ)pxUS4yyi9Hsw',
    b'I=n8RYdL!8y-?-vh2?WJgHe}t)8Pt|To)b_sF4{ZrqEbxjL*-;`5gs1mJz!PCLg1cFPV#C7_}#J3~&66ex(_`L6hlLdfZmzz)C9H',
    b'FAtSO!2Sq(1uAq;V0dmFm7^rdNR-9v{0~|bD?AUEJt7bA<-k*Wm<eH@$n!JHM0Bvv#*<kk<vt`jD`}C0kNk`SFKE5>ERk-7m?i(H',
    b'<tA6LTGnl&08LVdA+9qNod-+0Djx{ea<1rdpo?~<ZzSDV*HKhxBZdVm5g(Lp$xApsYNcDi3QL$tp0c&__y)ubW8s;$8?!Ud@bVy-',
    b'!?F?UkP4FU%^|`+lE&s4L+WVI{yLmvjl%G5_d%$Pjg7}Jysj^|IT+BG#ei`^1Be6!+Fg^Olj55KQ;>U6<1fk(*Uh-k(Kme+edCyk',
    b'Y*`EUc(sHZ4X$nHa-~;cZH_ARXNHy|-~8S|xAFpnm?V0HW^lo2xtvKx^H@a{EyUa6Sdbh)47x|;qcyc;WwPa%&%B%(Dv@it$#D4b',
    b'?S>rv20n?LJgzNyrS(m(%lwY*$d@V;m1hAm*K#ItPb%dhAe<CS;(3*gx{iF|O$8_}FD|AGt}stek8?rBY)w7Hv9w8|5x!ABadbbL',
    b'WvRlIc>q`8sr#&xM5^7SXrV>X9AxzQbXg0d$(5pfvhjU*#-D7NO-FxsIflp&D~>&59j~TiHVK2kPtlKA6$-+a)9M0Fi__!7!ACEi',
    b'=Of0no7@J^Vw#R6SkEDdV`nbIvqL$t`V(q4a%Kiy^C7zS(W(0-*-2ATRZp?I#L21BMJE`6HBR4SH`cqWhTz_>>Q0s0-x2gy3IKG+',
    b'KFsZ^&mhpgxxl2Wm-5O4j5OSeM1PhsUHwk^07)lBp*v{Ik1X5Lu{Pv2L?ZVo5Fx{aDY#$fjtk0V5Yij8BlDj2E62a)4^x>auHX~~',
    b'b`GYM-etI1DWnLfOnz{f@M1&>Kf;;r9!T%LJu#kH?4U!R+hxBTL|weMy)B68Glfp4hhr3-x0s?pH-IA!AHw(U$mrZXUN*-QN*S!f',
    b'F`2Ws?BW$d&nh2gIj69a`bPS@XfZI{3m~OnN;uXrcs_0NSy3%(j2W2Y@#)Q$4uR_eo2akKd7Wk}oU9nj^1051Y?&WiZL4M%#75NY',
    b'j>X_cSOq@Msoq!US24#t7V;TkY8Eg$B4fbyifSmA5v&?G?rEWwLD0Q%-ANu*Gqij?#$0hF!&nelQ_QbX0Uk0V9B-(|dP`?kt$j|)',
    b't`(nDSisB7E^gbB`F1pFF7n%8<n#QpKo3-H)b^;AUz}7b=G>m~w3uBsS1pr<F7~JgdpEXC*2>$}l~zea(w$O3!hNSLzBTmAQT`K~',
    b'i$d;RR82KPW3UK}LIP@|F8{Y^pE`w*>orzWnc}aG@JH`;amXWU>TuA@%LSE+wsYXF2<4Ol#!(t$(2y}Jg`}|tQsC;G_nuW++|kIa',
    b'R*tQNmU}gHWaYoC-_WWH)QRe#cnVgVjn-@;vnd8;l>3sPwzQ}ai_IfEax2b7DK5&kX1h@Hi*mb|p~A|P`0aNPayZe$xt?blNkxtA',
    b'#LQu<gT87^QWE|}hxmlIh)(A*DLeQkZHaH|BA*tHsVosJ3vwf!0&YxV;$^{$=>7p(!e}JxG#~pyERSzF<lKDG6?((}4u!lx7|es{',
    b'O3U@FeDGU-5nSg3`%M*w-C^4}jv=S(1gTu=*z;mt-~`XUrt!&mQc%o!Xq`iW)2ejc9%4o!AdSx2o)r9#fnYTSkyh7mH<tcpRWT@G',
    b'o<c{7T%tk3??c>}dp3A#A^HG859(@~2lTYRvs|WV`r%}Qt&YCZFq|>$K=W&iPwW@dW4s?rMyM1>_AxQu*I3b0wnq_;1b-8sm*tky',
    b'*QtD<NAG;#UiYpdw9;Sc(_v5Nj{6kZa}(2}r<CI_-ik*LCnjs>Z)~<oZd*sy@qEn@q)=x#AOkD)8X5RgahGU@2~XXxXu$RTI?XXA',
    b'`tj|IMa_2-@U+hk?j*;k+F~9V*NE#_LGW<tE$-H~fqlxn9Vn|{YP1^XAMOq$`ZS+!g&{{)@#jQ4cE(8jS`YYhH<rO-h3SSlE#2Fr',
    b'q?JzRf&W!m;0bz0fRt-DV5QXDcmD*liE~rL!h9e8v3phi%(lKF&ha(!652`0Il7&u?8W@Zr(W2P{MvN@=T3HUr(r~={s1dMO3-QX',
    b'Kh#JELRh)Xy(|G5Wzw3vj^b>V&+DtI2}zN@(rTk1>78MoiZQ`@=7Rb$OrZ}4qP^Q2A{E9#8h`eldy%w04x}I2>r&b6+dABXK`FSA',
    b'UW*+hcw{3+gimeMh@M}8-GoZ`PizByFJ9=qmrhfP6ueiE69F8ghMfq%vY{tB@B&|N&#bT>EBGKX_g)5-;P|xG;b93LVC-zh@*Sv&',
    b'u9PoKN=6J?ixJJ_Q|8zK8wFJAI#!j6+GH)0G9wV6PA^gVK4h}WLfFffHAnruWKb0Pu$R4}zY36QYc%&&*K?jfXZ?Op04$E3mmg~n',
    b'R5qFx`D{7g&W12lx@4&rN<u=^jxl4g!0^~nNe1bm+ooV+5jvPoo4}dd?gIRd20PS59@=QVF^}^*{rx?mk6YF?%~w9tMD7Aqt>)+g',
    b'nl(N@IxFXW0>9Lxi;5R1xT|azcX;rsm5MxZmMIDNsW?>(vp3}er8VUqC)5e$Hdm=pf}XkEdRfiO#TVMx)_@mXryV3}Vty>nK1j%n',
    b'&)Ts&QwnDL%!3(QnVOd4i?I@{AEfz3<Y;vbn1O+99lYz{wy_~Xf=kDH>nwQ(d5|GN>Q)psq!%$Jz|`VH!AI%-eePOGL<1p0D*lGl',
    b'8#xlF|1^R05xK#knUHk)wu(2C{y_B~0}%<|P6LUg-#u6S(1fc^vF?f;ma|CS;AP4K5x#0exkN7Oh^HXZor^dSv=Rq?iIJ6{UzAle',
    b'IeG6rj|h6l1aT+IGPj3kQE*qJ-&e-Q?mREvp$$*)=3a|$fcD8bcp~RutL(nfe)lqtsP^o}8y)l$mwEgbKt+jjmpq7{j25PK_c^A7',
    b'Dc4-jHuh%y>ngN<nA0w5w)d#5f<o4m<$QuFtF0?isXW1lq@sP*i&FH}jNMJ2y63Q)b|E05f#S4GmRIDEbBvD<I&&2l?gotClL9It',
    b'-J7BcTz{Ymv<RzYs_vIIe440}iKx&ZyvK?!MISQgeJW+y4xCO#f7&vzi>mZRn2RU>Ss5#CHC{_h3^jnz3Dowsu`vgiYcV5PCl)S7',
    b'mW26LUb~2}4tS5jTh)Q~+bicTHAEjz=c7U2mwcmy`8`$wBgiG%kx=8IhOHlR!L7UwGeq5p@}A@`Vav$Kj7I_sAo}+7E*lEK{V-iV',
    b'ArX3?s-+NMj;D)0*mIsib8G`Qfv^{M7K<bYc!VEqt*U$xsUXOwkw%qk#euNPC&b$^7<3yp1iF9x=CERt<PLDp{?;blYj~?0=7G65',
    b'SI^r6zw6ckAD-#P%R03z=_(_LZW6YWT$Xhk>bN%RHoM;XtlRo}i?d$q${H!<xP0=iTY4u1+pup-V{%Z1m=aZPr%z`<d6Z+k(P_Tf',
    b'Xn0!u+hlx=!+PGhQY^C3FfBnmB`0k%fr-Q2k2wJm_8xNZu5E`bTU%=nE(Kj_%y)?qhSwokAri4|%7hRJq~rF}Cwa5d5P({HC|<0+',
    b'OnSzu%~cYIhmT-`R<N7MviJMqk-SZS77@rwbB@lJi^7#fe)=IcFlEB8Em$uqx@E`EYdl9)mVk2j@@P);+1dH=>EIQkDMsKNcN7Z#',
    b'_lQ8pKr!zX$fGGf>sECoI7BW^tpEax@n31kpNczQ=d;SCnwa_%Dt@*VmLaNt`|kG_y=;4X`^5{8T<gk%zA-)#ni8D$g08Os<rq%_',
    b'$Kql|l462I8N6&UML$AZkplOWmRB}dl}-9n$f6iS&8UoxKTptCujdsKWji}_%d?cKW)O9SsnB`}p(76s(9E!|LOnoLFG3v3vQQ3B',
    b'GEpiW+G%aFoK9O|Ow2{j{f2%emH%KkP%l=O+RC0oY1Mu-(^tG}PtWp}QBY|W2alsN92$H8Ef>p~Za6+~lUou+FkMkIu5ETIkgC?a',
    b'R!s!SBCjboE^n&qaugP?2<GOO4#N`|al#vEc=z>z-qA13jy`?)oxi1R1b}Q919BY#%>*mQhm>{s)j5s?1vk5eGs{}bn=%L0KgD6L',
    b'AAhUPuO+|A<i<=W$vV9s8qU_DP2seLU-+Dq#<ev%lPsE#7aT%9hR$Gjg8s&-pK1tNhwvIbk+nk0T57#pDg2@3kxwh!HYSsd_<Top',
    b'Ob?wjD4F*ee1R|VaMu{@l<b#Z5FUlD8#vPV#}`AmalFdq6g(3eRxI45fQb+>_?6E`a^xo2C<y7?kc*<nvrm4ZR_u(jYKy6YVO$?f',
    b';HBFugoT)V>55@1wwV~3QU%2<4x}Ht+(2EJ%_e|>_)w(4!PsXHl>y<GCuK1m*Q-`NVLt0wb<CWl>$GTW)NuEQsx-+7gq{u6Q<A$5',
    b'&p8tU8Q&h!I}`p=8>6D!+`%Bxb{R##Faow|PojEO+96xSi(D0w^y^oGL<VvnkZUqQJi!~m2DlV8CE#upfRP&%f(Tydn8iNWJv}@a',
    b'oSjn=d)5YUqVM5z?<FZZNy)_8w~G=1Luzm|-<YJ(k!$!Jx(CL#32*C(h-|=9KPbwXgywChu@jw-k8>5|7)Gv;%2?xZX(*)<GU4*w',
    b'&d$B_Ks#D$T`-MG9Vtwk5`=ePj5#IE5_pItRkPHA@C`G!MULm&u}U8d)mjZz6rclNUQ<z&V!EBZuid7GO%h(?tZ0TALHjtB8f=h^',
    b'n8c02kJF-|C@w5VXNAz|kVb>&!$ii(dLSaiLR)&z^r+mJb^p9b@mKb`80Azg!fB5?!df5%GlAHL3xS7FWk7lu5a?288o+$0qV^bm',
    b'`EBy~E|9KqC#2{`Y0cLdafRX>)l<vI!l74i#nggMVvaJ<zQ*2cFijIVRGlaYpMJO9W^-_0i$b`RjZH4nWC|6iRo7vuI>}ui+Lo|p',
    b'<P5`oAD%<bCR9VQjxlxc!Yn%z2iX1r=%as01xxJ;9J%wN(=TOYyU#UX7Crx!&Lc03#|fOGb1U5pKTkFjSyBCb)zT99N>2b>H24XJ',
    b'LnGLU`lYYz=MnJhIjdAr@EQxZ1~JDpR!-|OJ1{79o1Jm4aNe9n)d5sEIcTD1r>#gJvH5L|@OU%349^}x#U$y5q1qbIW?5q-EY08G',
    b'0L{iBj*NGqzNhaP@fpq%6_Re#3l_SZ8d#CVl8~?9pSmOUsE@4<s4;7A8;8Os?7R*r9et*{wH`*TjE<@^z2l&NtXFCgiA%{iKxueQ',
    b'g_1rK7_WUe%QYmO6n9cM*6eeJ#hf!Z0mtF{^v0zq2HarmR;kxIm;$0w^J7(8C&`A$Zw}@RNO#DZ6pR9**Qg>PEI^J5D(T{7dr@c>',
    b'WVZA4Oq=_5IB~*9SVWj4vj*C{sS$#v)##G}Z*FB_37SZ7Zwdy8uyZyw#e-tXu7547YhY*d$Ub6iUWcw2$!KNVfI<RWEjO(MmlA0x',
    b'%lR5baBfl?<PZw-M)bN1lS=l3f`UBWdilbt;z6)#%nG^gnjJ*$$c&N#YS^-2S&58~#UFCGu^@%Y3rg~}2-D7<4KidHb;~z`w#s>t',
    b'UDq+pBDGvYBEzr`tlXk1g;_%=k{a^UeSmtGdrEEDtL-h(0h~S~L?9|=buqoOgi=yTkXLj&iVtKRF#rvi!5vUd5UJyWCxB|%h#fXN',
    b'dfOLPUG4f)IiF)No#3u|u>QmanpZk5(QdOEX>U_E+A7S;*wrF>BdrMve7aokU&FPGxrVlq(1|^Z0bdMP3bZKqwX&}3m6JDPv!YBv',
    b'*UpmQSh2e(ri_$%63o$T*VU@26oC5wiIj3sdcGV*2_!%=LmBms2u~GKu8{iTTZkFo@J*Ma?r#CIcX>JMPp0Ve*9A!!+C^2X_v((q',
    b'F&1Lhx^Tpl77F8Dl#@FvT(pc<f-%-EzA43YbU#&w!$DN9akV3~<*slTtndY__6MYV0-e<r-$R0osH(_@Fm4gZKF0^72!KZN!}Hz#',
    b'$?o3|k9YU``v+%S+WYscxx;f%dCd}5VeOKWB#iFiha!l_r=5>$I?XK|JOWjhn$xPWb|0iN+`FNXre!xb1~&^KL_ud;(E{4NMDgqg',
    b';CK_X9cQ{^dR_MvyH#m+D^u;<@N0vE6>Neacrls27(o+iO-D?oA-0jg^U}1lfi*am&DM^1O}4k&Y~4?4h%aTFU|opzAPkmX{WM`Q',
    b'zYTlY+C2V9HDQHZp`Y4OKJ`ej>U;_Va7AHxgRIFvr1?lRZw>2W3;6eBB9phbS^Qdf-jM#?3x6+bP7Um>v@gcls68RGOH$@KiJ6uW',
    b'@iJOoEZ*#@JkIX9oEznHu9ednC!U*jygHNE{&r<j@<yr0k+Y<guJIhvbyAI;q!{<z4z0#hqSsA}j*UUTe^}&`mXVYl+bvhLw?<O6',
    b'!v?g^PZCMEp}6hg+eI^R(qBaqn(R5|K1iHNaEf0oF!&^>t93&E>zn@rXzen>',
)
_R11_LITERAL_COMMON_SOURCES = (
    "smart-contracts/architecture/issue670/IStreamArtistFoundationOwnershipV1.sol",
    "smart-contracts/IERC165.sol",
    "smart-contracts/IStreamArtistArchiveV2.sol",
    "smart-contracts/IStreamArtistRegistryValidationCommon.sol",
    "smart-contracts/IStreamGovernanceExecutor.sol",
)
_R11_LITERAL_LIFECYCLE_SOURCES = _R11_LITERAL_COMMON_SOURCES + (
    "smart-contracts/architecture/issue670/StreamArtistLifecycleSkeletonBase.sol",
    "smart-contracts/IStreamGasParameterHost.sol",
)
_R11_LITERAL_WRITE_SOURCES = (
    "smart-contracts/IStreamArtistRegistryWritesA.sol",
    "smart-contracts/IStreamArtistRegistryWritesB.sol",
    "smart-contracts/IStreamArtistRegistryWritesC.sol",
)
R11_LITERAL_GROUP_ROWS = (
    ("000", "StreamArtistArchiveCompatibilityStateV3Skeleton.sol", "common", (), "C9BDE11D3DBD78A20D0CC63628ADBDB885F21CBDFBFA73022979AFA8161ECFBD"),
    ("001", "StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol", "common", (), "FA33DD799CBA9CA213571D63D22AD2079A75254671F8535164B84EA35D95F036"),
    ("002", "StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol", "common", (), "E509564C803BB073421C0ABC1AE75A16D6121E8B40983858E1801F2BE26ABF40"),
    ("003", "StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol", "lifecycle", (), "E23BC0FBDF44281A9BB5E2A1941B31316A44B233147D4D93C9E83DA22642C99D"),
    ("004", "StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol", "common", (), "255995D205A2D619F3FBA02E98B85C1E4EEE0C71DA84A2344407B712C51B2732"),
    ("005", "StreamArtistArchiveEvidenceStoreV2Skeleton.sol", "common", (), "7149D57E5E3C3F905063EE7ED152401DF8799E1CD77FCC888FEFB92681537D76"),
    ("006", "StreamArtistArchiveReadProjectionV1Skeleton.sol", "common", (), "8BE52656CC872C5718FAAE66642BCCDB1EC0C8DFC8059727826A50B8D06CA247"),
    ("007", "StreamArtistArchiveV2Skeleton.sol", "lifecycle", (), "A15BD83F911CE89308B16EFF506A9BA53E2DC463A6FD131A0D3FBDAC7BC49EC5"),
    ("008", "StreamArtistBindingLifecycleV1Skeleton.sol", "lifecycle", _R11_LITERAL_WRITE_SOURCES, "4348C8AC10AA9F1E7A94F8538C36EE532B58F90E41D2EBBC8EB76F9D82AEE17B"),
    ("009", "StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol", "common", (), "CC3AE2FA3DA87E956A1FBA87231F0400AB1A5DE2E8A46F8CC529D9A1A7E07F3F"),
    ("010", "StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol", "common", (), "C23DEE9FDD1A9CD14AFD515C54D10C6A99EA4355A4A8082D138AA974291CB94F"),
    ("011", "StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol", "common", (), "DBB22F56049D9097D1AAD9C9BAD1ADF3442A8EC8489D30FD74800991C25A933D"),
    ("012", "StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol", "lifecycle", _R11_LITERAL_WRITE_SOURCES, "DBC0ADC083758109CED4DBBABC95C2C757412B33A0F21C966E885E68A287D3EE"),
    ("013", "StreamArtistDirectoryV1Skeleton.sol", "lifecycle", (), "574C3F466321A8F6661DF0930DC57F9D715618E17877C14B1AFF2D7CA30502A2"),
    ("014", "StreamArtistFoundationControllerV2Skeleton.sol", "common", ("smart-contracts/IStreamArtistRegistryWritesA.sol",), "537E6C21E7EC01BB8BD54DD820A2E0446A54520C39E97AF449F63BE4EE2F5D45"),
    ("015", "StreamArtistFoundationReadFacadeV1Skeleton.sol", "lifecycle", ("smart-contracts/IStreamArtistConsent.sol", "smart-contracts/IStreamArtistRead.sol", "smart-contracts/IStreamArtistRecoveryEvidence.sol", "smart-contracts/IStreamArtistRegistry.sol"), "0F0025EF311EC0A085B1A8DA449B97C201E6D8AED8D1A2A4D31836E50B2D77BF"),
    ("016", "StreamArtistFutureControllerCompatibilitySkeletons.sol", "lifecycle", ("smart-contracts/IStreamArtistRegistryWritesB.sol", "smart-contracts/IStreamArtistRegistryWritesC.sol"), "A4C7F9C082A29DF3D451C34A4DD6CD83377B8B3D4BD495BDB429A08787E0E8B3"),
)

R4_SOLC_PLACEHOLDER_RE = re.compile(r"__\$[0-9a-fA-F]{34}\$__")

R4_GROUP_STRINGS = (
    "000::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveCompatibilityStateV3Skeleton.sol",
    "001::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveEvidenceAdmissionV3Skeleton.sol",
    "002::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveEvidenceCoordinatorV1Skeleton.sol",
    "003::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveEvidenceDirectoryV1Skeleton.sol",
    "004::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveEvidenceMaterializerV1Skeleton.sol",
    "005::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveEvidenceStoreV2Skeleton.sol",
    "006::smart-contracts/architecture/issue670/"
    "StreamArtistArchiveReadProjectionV1Skeleton.sol",
    "007::smart-contracts/architecture/issue670/StreamArtistArchiveV2Skeleton.sol",
    "008::smart-contracts/architecture/issue670/"
    "StreamArtistBindingLifecycleV1Skeleton.sol",
    "009::smart-contracts/architecture/issue670/"
    "StreamArtistBindingProposalArchiveVerifierV1Skeleton.sol",
    "010::smart-contracts/architecture/issue670/"
    "StreamArtistBindingTransitionArchiveVerifierV1Skeleton.sol",
    "011::smart-contracts/architecture/issue670/"
    "StreamArtistCollaboratorArchiveVerifierV1Skeleton.sol",
    "012::smart-contracts/architecture/issue670/"
    "StreamArtistCollaboratorIdentityLifecycleV1Skeleton.sol",
    "013::smart-contracts/architecture/issue670/"
    "StreamArtistDirectoryV1Skeleton.sol",
    "014::smart-contracts/architecture/issue670/"
    "StreamArtistFoundationControllerV2Skeleton.sol",
    "015::smart-contracts/architecture/issue670/"
    "StreamArtistFoundationReadFacadeV1Skeleton.sol",
    "016::smart-contracts/architecture/issue670/"
    "StreamArtistFutureControllerCompatibilitySkeletons.sol",
)
R11_LITERAL_CALL_SCHEDULE = (
    (0, "forge_version", None),
    *(
        (ordinal, "forge_build", group_string)
        for ordinal, group_string in enumerate(R4_GROUP_STRINGS, start=1)
    ),
)


@contextmanager
def working_directory(path: Path) -> Iterator[None]:
    previous = Path.cwd()
    os.chdir(path)
    try:
        yield
    finally:
        os.chdir(previous)


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def write_text(path: Path, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def append_json_object_member(raw: bytes, member: bytes) -> bytes:
    """Append one raw member without normalizing intentionally ambiguous JSON."""
    closing = raw.rfind(b"}")
    if closing < 0:
        raise AssertionError("fixture JSON must end with an object")
    prefix = raw[:closing].rstrip()
    suffix = raw[closing:]
    return prefix + b"," + member + suffix


def seed_tree(root: Path) -> dict[str, Path]:
    config = root / "release-artifacts" / "contracts.json"
    foundry_config = root / "foundry.toml"
    output = root / builder.DEFAULT_OUTPUT_DIR
    write_text(
        foundry_config,
        "\n".join(
            [
                "[profile.default]",
                'src = "smart-contracts"',
                'test = "test"',
                'script = "script"',
                'out = "out"',
                'cache_path = "cache"',
                'solc_version = "0.8.19"',
                "auto_detect_solc = false",
                'evm_version = "paris"',
                "optimizer = true",
                "optimizer_runs = 200",
                'bytecode_hash = "none"',
                "cbor_metadata = false",
                "",
            ]
        ),
    )
    write_text(
        root / "smart-contracts" / "Example.sol",
        (
            "// SPDX-License-Identifier: MIT\n"
            "pragma solidity 0.8.19;\n"
            'import "./Shared.sol";\n'
            "contract Example {}\n"
            "contract ExampleTwo {}\n"
        ),
    )
    write_text(
        root / "smart-contracts" / "Shared.sol",
        "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\nlibrary Shared {}\n",
    )
    write_text(
        root / "smart-contracts" / "IExample.sol",
        "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\ninterface IExample {}\n",
    )
    write_json(
        config,
        {
            "schema_version": "6529stream.release-artifact-contracts.v1",
            "production_contracts": [
                {"name": "Example", "source": "smart-contracts/Example.sol"},
                {"name": "ExampleTwo", "source": "smart-contracts/Example.sol"},
            ],
            "interfaces": [
                {"name": "IExample", "source": "smart-contracts/IExample.sol"}
            ],
            "runtime_size_budget": {
                "schema_version": size_checker.BUDGET_SCHEMA,
                "eip_170_runtime_limit_bytes": 24_576,
                "contracts": {
                    "Example": {
                        "source": "smart-contracts/Example.sol",
                        "minimum_runtime_margin_bytes": 0,
                        "warning_runtime_margin_bytes": 0,
                        "tracking": "https://example.test/release-size-budget",
                    }
                },
            },
        },
    )
    return {
        "config": config,
        "foundry_config": foundry_config,
        "output": output,
        "shared": root / "smart-contracts" / "Shared.sol",
    }


def artifact(
    source: str,
    name: str,
    metadata_sources: dict[str, str],
    *,
    compilation_target: dict[str, str] | None = None,
) -> dict[str, Any]:
    return {
        "abi": [],
        "bytecode": {"object": "0x6000"},
        "deployedBytecode": {"object": "0x6001"},
        "methodIdentifiers": {},
        "metadata": {
            "compiler": {"version": builder.SOLC_LONG_VERSION},
            "language": "Solidity",
            "settings": {
                "compilationTarget": compilation_target or {source: name},
                "evmVersion": builder.EVM_VERSION,
                "metadata": {"bytecodeHash": "none", "appendCBOR": False},
                "optimizer": {"enabled": True, "runs": builder.OPTIMIZER_RUNS},
                "viaIR": True,
            },
            "sources": {
                path: {"keccak256": source_hash}
                for path, source_hash in metadata_sources.items()
            },
            "version": 1,
        },
    }


def r11_literal_target_config_bytes() -> bytes:
    value = {
        "schema_version": "6529stream.release-artifact-contracts.v1",
        "production_contracts": [
            {"name": name, "source": source}
            for name, source in R11_LITERAL_TARGET_CONFIG_ROWS
        ],
        "interfaces": [],
    }
    return (
        json.dumps(value, ensure_ascii=True, indent=2) + "\n"
    ).encode("utf-8")


def r4_authority(target: str) -> dict[str, Any]:
    for authority in builder.CONSTRUCTOR_AUTHORITY:
        if authority["target"] == target:
            return dict(authority)
    raise AssertionError(f"unknown R4 target fixture: {target}")


def r11_literal_authority(position: int) -> dict[str, Any]:
    state = R11_LITERAL_TARGET_STATE_ROWS[position]
    constructor_target, input_types, constructor_bytes = (
        R4_CONSTRUCTOR_AUTHORITY[position]
    )
    size_target, runtime_cap, _aggregate_ids = R4_SIZE_GATES[position]
    if constructor_target != state[1] or size_target != state[1]:
        raise AssertionError("independent literal target fixtures do not join")
    signature = "constructor(" + ",".join(input_types) + ")"
    return {
        "semantic_id": state[0],
        "target": state[1],
        "source": state[2],
        "signature": signature,
        "input_types": input_types,
        "words": len(input_types),
        "bytes": constructor_bytes,
        "runtime_cap": runtime_cap,
    }


def r11_literal_initial_results() -> dict[str, Any]:
    evaluations = []
    for row in R11_LITERAL_TARGET_STATE_ROWS:
        record = dict(zip(R11_LITERAL_TARGET_STATE_KEYS, row, strict=True))
        record["bytecode_steps"] = list(record["bytecode_steps"])
        evaluations.append(record)
    return {
        "groups": [],
        "source_union": None,
        "target_evaluations": evaluations,
        "artifacts": [],
        "aggregates": [],
        "output_files": [],
        "output_installed": False,
        "output_quarantine_without_matching_go": False,
        "temporary_root": None,
    }


def r11_literal_group_results() -> list[dict[str, Any]]:
    groups = []
    prefix = "smart-contracts/architecture/issue670/"
    for group, filename, family, extras, aggregate in R11_LITERAL_GROUP_ROWS:
        primary = prefix + filename
        sources = (
            _R11_LITERAL_COMMON_SOURCES
            if family == "common"
            else _R11_LITERAL_LIFECYCLE_SOURCES
        ) + tuple(extras) + (primary,)
        receipts = []
        for source in sorted(sources, key=str.casefold):
            byte_count, digest = R11_LITERAL_SOURCE_RECEIPTS[source]
            receipts.append({
                "path": source,
                "sha256": digest,
                "byte_count": byte_count,
            })
        groups.append({
            "group": group,
            "group_string": group + "::" + primary,
            "source": primary,
            "source_count": len(receipts),
            "aggregate_sha256": aggregate,
            "sources": receipts,
        })
    return groups


def r11_literal_calls() -> list[dict[str, Any]]:
    return [
        {
            "ordinal": ordinal,
            "phase": phase,
            "group_string": None if ordinal == 0 else R4_GROUP_STRINGS[ordinal - 1],
            "start_event_sha256": r11_hash(f"call-{ordinal}-start"),
            "exit_event_sha256": r11_hash(f"call-{ordinal}-exit"),
            "argv_sha256": r11_hash(f"call-{ordinal}-argv"),
            "environment_sha256": r11_hash("forge-environment"),
            "launched": True,
            "exit_code": 0,
            "stdout_byte_count": 0,
            "stdout_sha256": r11_hash("empty-stdout"),
            "stderr_byte_count": 0,
            "stderr_sha256": r11_hash("empty-stderr"),
            "exception_type": None,
            "exception_sha256": None,
        }
        for ordinal, phase, _group in R11_LITERAL_CALL_SCHEDULE
    ]


def r11_literal_checkpoints() -> list[dict[str, Any]]:
    checkpoints = [r11_checkpoint("pre-started")]
    for ordinal in range(18):
        checkpoints.extend((
            r11_checkpoint(f"invocation-{ordinal:03d}-before"),
            r11_checkpoint(f"invocation-{ordinal:03d}-after"),
        ))
    return checkpoints


def r11_literal_staged_nogo_terminal(
    results: dict[str, Any],
    *,
    label: str,
) -> dict[str, Any]:
    return {
        "schema": R11_LITERAL_TERMINAL_SCHEMA,
        "invocation_id": r11_hash(label + "-invocation"),
        "status": "NO_GO",
        "first_red": {
            "phase": "staged_validation",
            "code": "STAGED_VALIDATION_FAILED",
            "call_ordinal": None,
            "group_index": None,
            "group_string": None,
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {
                "cause_type": "TraversalError",
                "message_sha256": r11_hash(label + "-staged"),
            },
        },
        "event_count": 37,
        "event_head_sha256": r11_hash("event-36"),
        "calls": r11_literal_calls(),
        "checkpoints": r11_literal_checkpoints(),
        "results": results,
        "no_retry": True,
    }


def r11_literal_go_terminal(*, label: str) -> dict[str, Any]:
    results = r11_literal_complete_results(installed=True)
    results["output_files"] = [
        {
            "path": f"literal-output/{index:02d}.json",
            "byte_count": index + 1,
            "sha256": r11_hash(f"{label}-output-{index:02d}"),
        }
        for index in range(37)
    ]
    return {
        "schema": R11_LITERAL_TERMINAL_SCHEMA,
        "invocation_id": r11_hash(label + "-invocation"),
        "status": "GO",
        "first_red": None,
        "event_count": 37,
        "event_head_sha256": r11_hash("event-36"),
        "calls": r11_literal_calls(),
        "checkpoints": r11_literal_checkpoints(),
        "results": results,
        "no_retry": True,
    }


def r11_literal_pass_trace(
    authority: dict[str, Any],
    *,
    creation_bytes: int = 1,
    runtime_bytes: int = 1,
) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    creation_text = "00" * creation_bytes
    runtime_text = "00" * runtime_bytes
    creation_text_sha = r11_hash(creation_text)
    runtime_text_sha = r11_hash(runtime_text)
    creation_byte_sha = "sha256:" + hashlib.sha256(
        b"\x00" * creation_bytes
    ).hexdigest()
    runtime_byte_sha = "sha256:" + hashlib.sha256(
        b"\x00" * runtime_bytes
    ).hexdigest()
    for ordinal, step_id, kind, status, operands_items, result_value, error in R11_LITERAL_STORE_TRACE_ROWS:
        operands = dict(operands_items)
        if "target" in operands:
            operands["target"] = authority["target"]
        for key in ("actual_types", "expected_types", "input_types"):
            if key in operands:
                operands[key] = list(authority["input_types"])
        result = dict(result_value) if isinstance(result_value, tuple) else result_value
        if ordinal == 3:
            operands.update({
                "input_length": len(creation_text),
                "input_sha256": creation_text_sha,
            })
            result = {
                "input_length": len(creation_text),
                "input_sha256": creation_text_sha,
                "output_length": len(creation_text),
                "output_sha256": creation_text_sha,
                "prefix_removed": False,
            }
        elif 4 <= ordinal <= 7:
            operands.update({
                "length": len(creation_text),
                "sha256": creation_text_sha,
            })
        elif ordinal == 11:
            operands.update({
                "input_length": len(runtime_text),
                "input_sha256": runtime_text_sha,
            })
            result = {
                "input_length": len(runtime_text),
                "input_sha256": runtime_text_sha,
                "output_length": len(runtime_text),
                "output_sha256": runtime_text_sha,
                "prefix_removed": False,
            }
        elif 12 <= ordinal <= 15:
            operands.update({
                "length": len(runtime_text),
                "sha256": runtime_text_sha,
            })
        elif ordinal == 18:
            result = {
                "signature": authority["signature"],
                "words": authority["words"],
                "bytes": authority["bytes"],
            }
        elif ordinal == 19:
            operands.update({
                "actual_signature": authority["signature"],
                "expected_signature": authority["signature"],
                "actual_words": authority["words"],
                "expected_words": authority["words"],
                "actual_bytes": authority["bytes"],
                "expected_bytes": authority["bytes"],
            })
        elif ordinal == 20:
            operands.update({
                "input_length": len(creation_text),
                "input_sha256": creation_text_sha,
            })
            result = {
                "byte_count": creation_bytes,
                "sha256": creation_byte_sha,
            }
        elif ordinal == 21:
            operands["creation_bytes"] = creation_bytes
            operands["constructor_bytes"] = authority["bytes"]
            result = {
                "creation_bytes": creation_bytes,
                "constructor_bytes": authority["bytes"],
                "full_initcode_bytes": authority["bytes"] + creation_bytes,
            }
        elif ordinal == 22:
            operands["actual"] = authority["bytes"] + creation_bytes
        elif ordinal == 23:
            operands.update({
                "input_length": len(runtime_text),
                "input_sha256": runtime_text_sha,
            })
            result = {
                "byte_count": runtime_bytes,
                "sha256": runtime_byte_sha,
            }
        elif ordinal == 24:
            operands["actual"] = runtime_bytes
        elif ordinal == 25:
            operands["actual"] = runtime_bytes
            operands["threshold"] = authority["runtime_cap"]
        elif ordinal == 26:
            operands["runtime_bytes"] = runtime_bytes
            result = {
                "runtime_bytes": runtime_bytes,
                "gas_per_byte": 200,
                "code_deposit_gas": runtime_bytes * 200,
            }
        rows.append({
            "ordinal": ordinal,
            "id": step_id,
            "kind": kind,
            "status": status,
            "operands": operands,
            "result": result,
            "error_code": error,
        })
    return rows


def r11_literal_artifact(
    authority: dict[str, Any], trace: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "semantic_id": authority["semantic_id"],
        "target": authority["target"],
        "creation_bytes": trace[19]["result"]["byte_count"],
        "creation_sha256": trace[19]["result"]["sha256"],
        "constructor_signature": trace[17]["result"]["signature"],
        "constructor_words": trace[17]["result"]["words"],
        "constructor_bytes": trace[17]["result"]["bytes"],
        "full_initcode_bytes": trace[20]["result"]["full_initcode_bytes"],
        "runtime_bytes": trace[22]["result"]["byte_count"],
        "runtime_sha256": trace[22]["result"]["sha256"],
        "runtime_cap": authority["runtime_cap"],
        "code_deposit_gas": trace[25]["result"]["code_deposit_gas"],
    }


def r11_literal_bytecode_failure_results(
    target_position: int,
    failed_trace: list[dict[str, Any]],
) -> dict[str, Any]:
    results = r11_literal_initial_results()
    results["groups"] = r11_literal_group_results()
    results["source_union"] = copy.deepcopy(R11_LITERAL_SOURCE_UNION)
    results["temporary_root"] = "C:\\build-temp"
    artifacts = []
    for position, evaluation in enumerate(results["target_evaluations"], start=1):
        evaluation.update({
            "metadata_evaluated": True,
            "file_read": True,
            "artifact_byte_count": 1,
            "artifact_sha256": r11_hash(f"artifact-{position}"),
            "artifact_json_decoded": True,
            "metadata_admitted": True,
        })
        if position < target_position:
            authority = r11_literal_authority(position - 1)
            trace = r11_literal_pass_trace(authority)
            evaluation.update({
                "bytecode_evaluated": True,
                "bytecode_completed": True,
                "bytecode_steps": trace,
            })
            artifacts.append(r11_literal_artifact(authority, trace))
        elif position == target_position:
            evaluation.update({
                "bytecode_evaluated": True,
                "bytecode_completed": False,
                "bytecode_steps": copy.deepcopy(failed_trace),
            })
    results["artifacts"] = artifacts
    measurements = {artifact["semantic_id"]: artifact for artifact in artifacts}
    aggregates = []
    for trigger, gate, members, metric, threshold in R11_LITERAL_AGGREGATE_ROWS:
        if len(artifacts) < trigger:
            continue
        values = [measurements[member][metric] for member in members]
        aggregates.append({
            "gate": gate,
            "members": list(members),
            "field": metric,
            "operands": values,
            "actual": sum(values),
            "operator": "<=",
            "threshold": threshold,
            "passed": True,
        })
    results["aggregates"] = aggregates
    return results


def r11_literal_complete_results(*, installed: bool) -> dict[str, Any]:
    results = r11_literal_initial_results()
    results["groups"] = r11_literal_group_results()
    results["source_union"] = copy.deepcopy(R11_LITERAL_SOURCE_UNION)
    artifacts = []
    for position, evaluation in enumerate(results["target_evaluations"], start=1):
        authority = r11_literal_authority(position - 1)
        trace = r11_literal_pass_trace(authority)
        evaluation.update({
            "metadata_evaluated": True,
            "file_read": True,
            "artifact_byte_count": 1,
            "artifact_sha256": r11_hash(f"artifact-{position}"),
            "artifact_json_decoded": True,
            "metadata_admitted": True,
            "bytecode_evaluated": True,
            "bytecode_completed": True,
            "bytecode_steps": trace,
        })
        artifacts.append(r11_literal_artifact(authority, trace))
    results["artifacts"] = artifacts
    measurements = {artifact["semantic_id"]: artifact for artifact in artifacts}
    results["aggregates"] = [
        {
            "gate": gate,
            "members": list(members),
            "field": metric,
            "operands": [measurements[member][metric] for member in members],
            "actual": sum(measurements[member][metric] for member in members),
            "operator": "<=",
            "threshold": threshold,
            "passed": True,
        }
        for _trigger, gate, members, metric, threshold in R11_LITERAL_AGGREGATE_ROWS
    ]
    results["output_installed"] = installed
    results["output_quarantine_without_matching_go"] = installed
    results["temporary_root"] = None if installed else "C:\\build-temp"
    return results


def r11_literal_installed_output(
    output: Path,
) -> tuple[dict[str, Any], dict[str, bytes], dict[str, Any]]:
    manifest = {
        "schema": "r11-literal-manifest-v1",
        "targets": [],
    }
    output_bytes = {
        builder.MANIFEST_FILENAME: builder.canonical_evidence_bytes(manifest),
        **{
            f"artifact-{index:02d}.json": (
                f'{{"artifact":{index}}}\n'.encode("ascii")
            )
            for index in range(36)
        },
    }
    output.mkdir()
    for name, raw in output_bytes.items():
        (output / name).write_bytes(raw)
    results = r11_literal_complete_results(installed=True)
    results["output_files"] = [
        {
            "path": name,
            "byte_count": len(output_bytes[name]),
            "sha256": "sha256:" + hashlib.sha256(output_bytes[name]).hexdigest(),
        }
        for name in sorted(output_bytes)
    ]
    if len(results["output_files"]) != 37:
        raise AssertionError("literal installed output geometry is not exact")
    return manifest, output_bytes, results


def r11_literal_aggregate_failure_results(
    aggregate_position: int,
) -> dict[str, Any]:
    trigger = R11_LITERAL_AGGREGATE_ROWS[aggregate_position - 1][0]
    results = r11_literal_initial_results()
    results["groups"] = r11_literal_group_results()
    results["source_union"] = copy.deepcopy(R11_LITERAL_SOURCE_UNION)
    results["temporary_root"] = "C:\\build-temp"
    artifacts = []
    for position, evaluation in enumerate(results["target_evaluations"], start=1):
        evaluation.update({
            "metadata_evaluated": True,
            "file_read": True,
            "artifact_byte_count": 1,
            "artifact_sha256": r11_hash(f"aggregate-artifact-{position}"),
            "artifact_json_decoded": True,
            "metadata_admitted": True,
        })
        if position <= trigger:
            authority = r11_literal_authority(position - 1)
            trace = r11_literal_pass_trace(authority)
            evaluation.update({
                "bytecode_evaluated": True,
                "bytecode_completed": True,
                "bytecode_steps": trace,
            })
            artifacts.append(r11_literal_artifact(authority, trace))
    results["artifacts"] = artifacts
    measurements = {artifact["semantic_id"]: artifact for artifact in artifacts}
    prior_rows = R11_LITERAL_AGGREGATE_ROWS[:aggregate_position - 1]
    results["aggregates"] = [
        {
            "gate": gate,
            "members": list(members),
            "field": metric,
            "operands": [measurements[member][metric] for member in members],
            "actual": sum(measurements[member][metric] for member in members),
            "operator": "<=",
            "threshold": threshold,
            "passed": True,
        }
        for _trigger, gate, members, metric, threshold in prior_rows
    ]
    return results


def r11_literal_reachable_aggregate_failure_results(
    aggregate_position: int,
) -> dict[str, Any]:
    if aggregate_position not in (9, 10):
        raise AssertionError("only G11 runtime and initcode reds are reachable")
    results = r11_literal_initial_results()
    results["groups"] = r11_literal_group_results()
    results["source_union"] = copy.deepcopy(R11_LITERAL_SOURCE_UNION)
    results["temporary_root"] = "C:\\build-temp"
    runtime_by_semantic = {
        "Transition": 22_064,
        "Proposal": 22_064,
        "Collaborator": 20_873,
    } if aggregate_position == 9 else {}
    creation_by_semantic = {
        "Transition": 22_000,
        "Proposal": 22_000,
        "Collaborator": 21_925,
    } if aggregate_position == 10 else {}
    artifacts = []
    for position, evaluation in enumerate(
        results["target_evaluations"], start=1,
    ):
        evaluation.update({
            "metadata_evaluated": True,
            "file_read": True,
            "artifact_byte_count": 1,
            "artifact_sha256": r11_hash(
                f"reachable-aggregate-artifact-{position}"
            ),
            "artifact_json_decoded": True,
            "metadata_admitted": True,
        })
        if position <= 11:
            authority = r11_literal_authority(position - 1)
            trace = r11_literal_pass_trace(
                authority,
                creation_bytes=creation_by_semantic.get(
                    authority["semantic_id"], 1,
                ),
                runtime_bytes=runtime_by_semantic.get(
                    authority["semantic_id"], 1,
                ),
            )
            evaluation.update({
                "bytecode_evaluated": True,
                "bytecode_completed": True,
                "bytecode_steps": trace,
            })
            artifacts.append(r11_literal_artifact(authority, trace))
    results["artifacts"] = artifacts
    measurements = {
        artifact["semantic_id"]: artifact for artifact in artifacts
    }
    results["aggregates"] = [
        {
            "gate": gate,
            "members": list(members),
            "field": metric,
            "operands": [measurements[member][metric] for member in members],
            "actual": sum(measurements[member][metric] for member in members),
            "operator": "<=",
            "threshold": threshold,
            "passed": True,
        }
        for _trigger, gate, members, metric, threshold
        in R11_LITERAL_AGGREGATE_ROWS[:aggregate_position - 1]
    ]
    return results


def r4_bytecode_artifact(
    authority: dict[str, Any],
    *,
    creation_bytes: int = 1,
    runtime_bytes: int = 1,
) -> dict[str, Any]:
    constructor_types = (
        authority["signature"]
        .removeprefix("constructor(")
        .removesuffix(")")
        .split(",")
    )
    if constructor_types == [""]:
        constructor_types = []
    return {
        "abi": [
            {
                "type": "constructor",
                "inputs": [
                    {"name": f"arg{index}", "type": item}
                    for index, item in enumerate(constructor_types)
                ],
            }
        ],
        "bytecode": {
            "object": "00" * creation_bytes,
            "linkReferences": {},
        },
        "deployedBytecode": {
            "object": "00" * runtime_bytes,
            "linkReferences": {},
        },
    }


def assert_r4_failure(
    case: unittest.TestCase,
    expected_code: str,
    function: Any,
    *args: Any,
    **kwargs: Any,
) -> builder.EvidenceFailure:
    with case.assertRaises(builder.EvidenceFailure) as raised:
        function(*args, **kwargs)
    case.assertEqual(raised.exception.code, expected_code)
    case.assertIsInstance(raised.exception.operands, dict)
    return raised.exception


def r4_path_token(path: Path, label: str, *, directory: bool = False) -> dict[str, Any]:
    receipt = builder.r4_windows_file_receipt(path, label, directory=directory)
    return {**receipt, "kind": "directory" if directory else "file"}


def r4_journal_fixture(
    root: Path,
) -> tuple[builder.R4ExecutionJournal, Path, Path, Path]:
    evidence = root / "evidence"
    evidence.mkdir()
    forge = root / "forge.exe"
    solc = root / "solc.exe"
    forge.write_bytes(b"fake-forge")
    solc.write_bytes(b"fake-solc")
    receipts = {
        "builder": r4_path_token(SCRIPT_PATH.resolve(), "builder"),
        "forge": r4_path_token(forge, "Forge executable"),
        "solc": r4_path_token(solc, "Solc executable"),
        "evidence": r4_path_token(evidence, "evidence", directory=True),
    }
    journal = builder.R4ExecutionJournal(
        evidence,
        "sha256:" + "a" * 64,
        receipts,
        forge,
        solc,
    )
    return journal, evidence, forge, solc


class FakeForge:
    def __init__(
        self,
        *,
        wrong_target: bool = False,
        compiler_input_extra_source: str | None = None,
        compiler_path_overrides: dict[str, object] | None = None,
    ) -> None:
        self.commands: list[list[str]] = []
        self.cwd_values: list[Path] = []
        self.wrong_target = wrong_target
        self.compiler_input_extra_source = compiler_input_extra_source
        self.compiler_path_overrides = compiler_path_overrides

    def __call__(self, command: list[str], cwd: Path) -> None:
        self.commands.append(command)
        self.cwd_values.append(cwd)
        source = command[2]
        out_dir = Path(command[command.index("--out") + 1])
        names = (
            ["Example", "ExampleTwo"]
            if Path(source).name == "Example.sol"
            else ["IExample"]
        )
        source_paths = [source]
        if Path(source).name == "Example.sol":
            source_paths.append("smart-contracts/Shared.sol")
            if self.compiler_input_extra_source is not None:
                source_paths.append(self.compiler_input_extra_source)
        source_contents = {
            path: (cwd / path).read_bytes().decode("utf-8")
            for path in source_paths
        }
        source_hashes = {
            path: builder.keccak256_hex(content.encode("utf-8"))
            for path, content in source_contents.items()
        }
        for name in names:
            target = {"smart-contracts/Wrong.sol": name} if self.wrong_target else None
            write_json(
                out_dir / Path(source).name / f"{name}.json",
                artifact(
                    source,
                    name,
                    source_hashes,
                    compilation_target=target,
                ),
            )
        build_info_dir = Path(command[command.index("--build-info-path") + 1])
        write_json(
            build_info_dir / "build-info.json",
            {
                "id": "fixture",
                "input": {
                    "language": "Solidity",
                    "sources": {
                        path: {"content": content}
                        for path, content in source_contents.items()
                    },
                    "settings": {
                        "evmVersion": builder.EVM_VERSION,
                        "metadata": {"bytecodeHash": "none", "appendCBOR": False},
                        "optimizer": {
                            "enabled": True,
                            "runs": builder.OPTIMIZER_RUNS,
                        },
                        "outputSelection": {"*": {"*": ["abi"]}},
                        "viaIR": True,
                    },
                    **(
                        self.compiler_path_overrides
                        if self.compiler_path_overrides is not None
                        else {
                            "allowPaths": [
                                cwd.resolve().as_posix(),
                                (cwd.resolve() / "lib").as_posix(),
                            ],
                            "basePath": cwd.resolve().as_posix(),
                            "includePaths": [cwd.resolve().as_posix()],
                        }
                    ),
                },
            },
        )
        write_json(
            out_dir / "Imported.sol" / "Imported.json",
            artifact(
                "smart-contracts/Shared.sol",
                "Imported",
                {
                    "smart-contracts/Shared.sol": source_hashes.get(
                        "smart-contracts/Shared.sol",
                        builder.keccak256_hex(
                            (cwd / "smart-contracts/Shared.sol").read_bytes()
                        ),
                    )
                },
            ),
        )


class ReleaseBuildArtifactTests(unittest.TestCase):
    def test_aggregate_size_log_accepts_only_exact_test_helper_overflow(self) -> None:
        expected = "\n".join(
            [
                "Compiler run successful with warnings:",
                (
                    "| LegacyStreamCore | 24,587 | 25,748 | -11 | "
                    "23,404 |"
                ),
                size_log.RUNTIME_SIZE_ERROR,
            ]
        )
        self.assertTrue(size_log.accepted_test_only_runtime_overflow(expected))

        mutations = {
            "production overflow": expected.replace(
                size_log.RUNTIME_SIZE_ERROR,
                (
                    "| StreamCore | 24,577 | 25,000 | -1 | 24,152 |\n"
                    + size_log.RUNTIME_SIZE_ERROR
                ),
            ),
            "helper size drift": expected.replace("24,587", "24,588").replace(
                "-11",
                "-12",
            ),
            "compile failure": expected.replace(
                "Compiler run successful with warnings:",
                "Compiler run failed:",
            ),
            "unexpected error": expected + "\nError: another failure",
        }
        for label, candidate in mutations.items():
            with self.subTest(label=label):
                self.assertFalse(
                    size_log.accepted_test_only_runtime_overflow(candidate)
                )

    def test_strict_json_decoder_preserves_ijson_policy(self) -> None:
        cases = (
            (b'{"value":1.5}', "floating-point JSON is forbidden"),
            (
                b'{"value":9007199254740992}',
                "outside the I-JSON interoperable range",
            ),
            (
                b'{"value":"\\ud800"}',
                "non-Unicode-scalar surrogate",
            ),
            (b'{"value":"\xff"}', "not strict UTF-8 JSON"),
        )
        for raw, expected in cases:
            with (
                self.subTest(raw=raw),
                self.assertRaisesRegex(builder.ReleaseBuildError, expected),
            ):
                builder.load_json_bytes(raw, Path("fixture.json"))

    def test_builds_each_target_in_an_isolated_import_closure(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()

            with redirect_stdout(StringIO()):
                manifest = builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    "fake-forge",
                    fake,
                    FAKE_FORGE_VERSION,
                )

            self.assertEqual(len(fake.commands), 2)
            self.assertEqual(fake.cwd_values, [root.resolve(), root.resolve()])
            self.assertEqual({command[2] for command in fake.commands}, {
                "smart-contracts/Example.sol",
                "smart-contracts/IExample.sol",
            })
            self.assertTrue(all(command[3] == "--root" for command in fake.commands))
            out_dirs = [Path(command[command.index("--out") + 1]) for command in fake.commands]
            cache_dirs = [
                Path(command[command.index("--cache-path") + 1])
                for command in fake.commands
            ]
            self.assertEqual(len(set(out_dirs)), 2)
            self.assertEqual(len(set(cache_dirs)), 2)
            for command in fake.commands:
                self.assertIn("--via-ir", command)
                self.assertIn("--no-metadata", command)
                self.assertIn("--build-info", command)
                self.assertIn("--use-literal-content", command)
                self.assertNotIn("--profile", command)
                self.assertEqual(command[command.index("--use") + 1], "0.8.19")
                self.assertEqual(command[command.index("--optimizer-runs") + 1], "200")

            actual_files = {
                path.relative_to(paths["output"]).as_posix()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }
            self.assertEqual(
                actual_files,
                {
                    "Example.sol/Example.json",
                    "Example.sol/ExampleTwo.json",
                    "IExample.sol/IExample.json",
                    "compiler-inputs/000-Example.json",
                    "compiler-inputs/001-IExample.json",
                    builder.MANIFEST_FILENAME,
                },
            )
            self.assertEqual(manifest["output_dir"], "out-release")
            self.assertEqual(
                manifest["policy"]["forge_version"],
                PORTABLE_FAKE_FORGE_VERSION,
            )
            self.assertEqual(
                manifest["policy"]["foundry_version"],
                builder.FOUNDRY_VERSION,
            )
            self.assertEqual(manifest["policy"]["forge_profile"], "default")
            self.assertEqual(
                manifest["policy"]["controlled_forge_environment"],
                {"FOUNDRY_PROFILE": "default"},
            )
            self.assertEqual(
                manifest["policy"]["restricted_source_roots"],
                ["script", "test"],
            )
            self.assertEqual(
                manifest["policy"]["sanitized_environment_prefixes"],
                ["DAPP_", "FOUNDRY_"],
            )
            records = {record["name"]: record for record in manifest["targets"]}
            self.assertEqual(
                records["Example"]["artifact_path"],
                "out-release/Example.sol/Example.json",
            )
            self.assertEqual(
                records["Example"]["forge_environment"],
                {"FOUNDRY_PROFILE": "default"},
            )
            self.assertEqual(
                [item["path"] for item in records["Example"]["metadata_sources"]],
                ["smart-contracts/Example.sol", "smart-contracts/Shared.sol"],
            )
            self.assertEqual(
                [item["path"] for item in records["IExample"]["metadata_sources"]],
                ["smart-contracts/IExample.sol"],
            )
            self.assertEqual(
                records["Example"]["canonical_source_universe_sha256"],
                records["ExampleTwo"]["canonical_source_universe_sha256"],
            )
            self.assertEqual(records["Example"]["forge_argv"][2], "smart-contracts/Example.sol")
            self.assertNotEqual(
                records["Example"]["canonical_build_input_sha256"],
                records["ExampleTwo"]["canonical_build_input_sha256"],
            )
            self.assertEqual(
                records["Example"]["compiler_input_ordered_sha256"],
                records["ExampleTwo"]["compiler_input_ordered_sha256"],
            )
            self.assertEqual(
                records["Example"]["compiler_input_path"],
                "out-release/compiler-inputs/000-Example.json",
            )
            retained_input = json.loads(
                (
                    paths["output"]
                    / "compiler-inputs"
                    / "000-Example.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(
                {
                    field: retained_input[field]
                    for field in builder.PORTABLE_COMPILER_PATHS
                },
                builder.PORTABLE_COMPILER_PATHS,
            )
            self.assertEqual(
                manifest["policy"]["portable_compiler_paths"],
                builder.PORTABLE_COMPILER_PATHS,
            )

    def test_release_receipt_is_identical_across_roots_and_platform_builds(
        self,
    ) -> None:
        with (
            tempfile.TemporaryDirectory() as first_dir,
            tempfile.TemporaryDirectory() as second_dir,
        ):
            roots = (Path(first_dir), Path(second_dir))
            forge_versions = (
                FAKE_FORGE_VERSION,
                OTHER_PLATFORM_FAKE_FORGE_VERSION,
            )
            outputs: list[tuple[dict[str, Any], list[bytes], bytes]] = []
            for root, forge_version in zip(roots, forge_versions, strict=True):
                paths = seed_tree(root)
                with redirect_stdout(StringIO()):
                    manifest = builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        "fake-forge",
                        FakeForge(),
                        forge_version,
                    )
                retained = [
                    path.read_bytes()
                    for path in sorted(
                        (paths["output"] / "compiler-inputs").glob("*.json")
                    )
                ]
                receipt = (
                    paths["output"] / builder.MANIFEST_FILENAME
                ).read_bytes()
                outputs.append((manifest, retained, receipt))

            self.assertEqual(outputs[0], outputs[1])
            self.assertEqual(
                outputs[0][0]["policy"]["forge_version"],
                PORTABLE_FAKE_FORGE_VERSION,
            )
            self.assertNotEqual(
                builder.validate_forge_version(
                    FAKE_FORGE_VERSION.replace(
                        "Commit SHA: fixture",
                        "Commit SHA: different",
                    )
                ),
                PORTABLE_FAKE_FORGE_VERSION,
            )
            self.assertEqual(
                builder.file_sha256(
                    roots[0] / builder.DEFAULT_OUTPUT_DIR / builder.MANIFEST_FILENAME
                ),
                builder.file_sha256(
                    roots[1] / builder.DEFAULT_OUTPUT_DIR / builder.MANIFEST_FILENAME
                ),
            )

    def test_rejects_noncanonical_raw_compiler_path_controls(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw_root = root.resolve().as_posix()
            raw_lib = (root.resolve() / "lib").as_posix()
            cases = {
                "outside base": {
                    "allowPaths": [raw_root, raw_lib],
                    "basePath": (root.parent / "outside").resolve().as_posix(),
                    "includePaths": [raw_root],
                },
                "extra allow path": {
                    "allowPaths": [raw_root, raw_lib, raw_root],
                    "basePath": raw_root,
                    "includePaths": [raw_root],
                },
                "reordered allow paths": {
                    "allowPaths": [raw_lib, raw_root],
                    "basePath": raw_root,
                    "includePaths": [raw_root],
                },
                "extra include path": {
                    "allowPaths": [raw_root, raw_lib],
                    "basePath": raw_root,
                    "includePaths": [raw_root, raw_lib],
                },
                "relative raw paths": builder.PORTABLE_COMPILER_PATHS,
            }
            for label, controls in cases.items():
                with self.subTest(case=label):
                    paths = seed_tree(root)
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "before portable retention",
                    ):
                        with redirect_stdout(StringIO()):
                            builder.build_release_output(
                                root,
                                paths["config"],
                                paths["foundry_config"],
                                paths["output"],
                                "fake-forge",
                                FakeForge(compiler_path_overrides=controls),
                                FAKE_FORGE_VERSION,
                            )

    def test_rejects_test_and_script_sources_from_build_info_compiler_input(self) -> None:
        for restricted_source in (
            "test/ReleaseLeak.t.sol",
            "script/ReleaseLeak.s.sol",
        ):
            with self.subTest(source=restricted_source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    write_text(
                        root / restricted_source,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract ReleaseLeak {}\n"
                        ),
                    )
                    fake = FakeForge(
                        compiler_input_extra_source=restricted_source,
                    )

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        with redirect_stdout(StringIO()):
                            builder.build_release_output(
                                root,
                                paths["config"],
                                paths["foundry_config"],
                                paths["output"],
                                runner=fake,
                                forge_version_output=FAKE_FORGE_VERSION,
                            )

                    self.assertEqual(len(fake.commands), 1)
                    self.assertFalse(paths["output"].exists())

    def test_rejects_restricted_configured_target_before_compiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            restricted_source = "test/ConfiguredReleaseTarget.t.sol"
            write_text(
                root / restricted_source,
                (
                    "// SPDX-License-Identifier: MIT\n"
                    "pragma solidity 0.8.19;\n"
                    "contract ConfiguredReleaseTarget {}\n"
                ),
            )
            config = json.loads(paths["config"].read_text(encoding="utf-8"))
            config["production_contracts"][0] = {
                "name": "ConfiguredReleaseTarget",
                "source": restricted_source,
            }
            write_json(paths["config"], config)
            fake = FakeForge()

            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "restricted canonical release source root",
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            self.assertEqual(fake.commands, [])

    def test_rejects_restricted_source_aliases_after_resolution(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir).resolve()
            cases = [
                (
                    "dot segment",
                    Path("smart-contracts") / ".." / "test" / "DotAlias.t.sol",
                    root / "test" / "DotAlias.t.sol",
                ),
                (
                    "absolute path",
                    root / "script" / "AbsoluteAlias.s.sol",
                    root / "script" / "AbsoluteAlias.s.sol",
                ),
                (
                    "mixed-case root",
                    Path("TeSt") / "MixedCaseAlias.t.sol",
                    root / "test" / "MixedCaseAlias.t.sol",
                ),
            ]
            if os.name == "nt":
                cases.extend(
                    [
                        (
                            "Windows separator",
                            Path(r"test\WindowsAlias.t.sol"),
                            root / "test" / "WindowsAlias.t.sol",
                        ),
                        (
                            "Windows trailing-dot root",
                            Path("test.") / "TrailingDotAlias.t.sol",
                            root / "test" / "TrailingDotAlias.t.sol",
                        ),
                    ]
                )

            for label, alias, source_path in cases:
                with self.subTest(alias=label):
                    write_text(
                        source_path,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract RestrictedAlias {}\n"
                        ),
                    )
                    resolved = builder.resolve_repo_path(
                        root,
                        alias,
                        f"{label} source",
                    )
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        builder.reject_restricted_release_source(
                            root,
                            resolved,
                            f"{label} source",
                        )

    @unittest.skipUnless(os.name == "nt", "Windows 8.3 aliases are Windows-only")
    def test_rejects_restricted_windows_short_path_alias(self) -> None:
        import ctypes

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir).resolve()
            source_path = root / "test" / "ShortPathAlias.t.sol"
            write_text(
                source_path,
                (
                    "// SPDX-License-Identifier: MIT\n"
                    "pragma solidity 0.8.19;\n"
                    "contract RestrictedShortPathAlias {}\n"
                ),
            )
            buffer = ctypes.create_unicode_buffer(32_768)
            length = ctypes.windll.kernel32.GetShortPathNameW(  # type: ignore[attr-defined]
                str(source_path),
                buffer,
                len(buffer),
            )
            if length == 0 or length >= len(buffer):
                self.skipTest("Windows did not return an 8.3 alias")
            short_path = Path(buffer.value)
            if str(short_path).casefold() == str(source_path).casefold():
                self.skipTest("8.3 aliases are unavailable for the temporary directory")

            resolved = builder.resolve_repo_path(
                root,
                short_path,
                "Windows 8.3 source",
            )
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "restricted canonical release source root",
            ):
                builder.reject_restricted_release_source(
                    root,
                    resolved,
                    "Windows 8.3 source",
                )

    def test_rejects_test_and_script_sources_from_artifact_metadata(self) -> None:
        for restricted_source in (
            "test/MetadataLeak.t.sol",
            "script/MetadataLeak.s.sol",
        ):
            with self.subTest(source=restricted_source):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    seed_tree(root)
                    source_path = root / restricted_source
                    write_text(
                        source_path,
                        (
                            "// SPDX-License-Identifier: MIT\n"
                            "pragma solidity 0.8.19;\n"
                            "contract MetadataLeak {}\n"
                        ),
                    )
                    metadata = {
                        "sources": {
                            restricted_source: {
                                "keccak256": builder.keccak256_hex(
                                    source_path.read_bytes()
                                )
                            }
                        }
                    }

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "restricted canonical release source root",
                    ):
                        builder.metadata_source_records(
                            root.resolve(),
                            metadata,
                            "metadata fixture",
                        )

    def test_aggregate_size_build_is_labeled_diagnostic(self) -> None:
        expected_phrases = {
            README_PATH: "aggregate size/warning step is diagnostic only",
            TEST_README_PATH: "warning and whole-tree size diagnostic only",
            TOOLING_PATH: "warning-collection and whole-tree size diagnostic",
            DEPLOYMENT_DOC_PATH: "warning and whole-tree size diagnostic;",
            WARNING_DISPOSITIONS_PATH: (
                "log is therefore warning evidence, not production bytecode"
            ),
            DEPLOYMENT_README_PATH: "command is diagnostic only",
            RELEASE_ARTIFACTS_README_PATH: "warnings and whole-tree size diagnostics",
            SIZE_LOG_PATH: "aggregate size/warning diagnostic",
            CI_PATH: "name: Aggregate size and warning diagnostic",
            MAKEFILE_PATH: (
                "Aggregate diagnostic only; canonical release bytecode is built"
            ),
            CHANGELOG_PATH: "aggregate size/warning diagnostic output is retained",
        }
        for path, phrase in expected_phrases.items():
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                self.assertIn(
                    phrase,
                    path.read_text(encoding="utf-8"),
                )

        canonical_commands = [
            "python scripts/test_release_build_artifacts.py",
            builder.CANONICAL_BUILD_COMMAND,
            f"{builder.CANONICAL_BUILD_COMMAND} --check",
            "python scripts/generate_release_artifacts.py",
        ]
        for path in (
            DEPLOYMENT_DOC_PATH,
            DEPLOYMENT_README_PATH,
            RELEASE_ARTIFACTS_README_PATH,
        ):
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                text = path.read_text(encoding="utf-8")
                positions = [text.index(command) for command in canonical_commands]
                self.assertEqual(positions, sorted(positions))

        banned_phrases = {
            CHANGELOG_PATH: "production-size forge output",
            README_PATH: "release bytecode and EIP-170/EIP-3860 evidence",
            RELEASE_ARTIFACTS_README_PATH: (
                "not an input to release, verification, or deployment evidence"
            ),
            WARNING_DISPOSITIONS_PATH: (
                "helpers can appear only in aggregate diagnostic warnings"
            ),
        }
        for path, phrase in banned_phrases.items():
            with self.subTest(path=path.relative_to(REPO_ROOT).as_posix()):
                self.assertNotIn(phrase, path.read_text(encoding="utf-8"))

    def test_successful_replacement_is_exact_and_deterministic(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            write_text(paths["output"] / "stale.txt", "stale output\n")
            write_json(
                paths["output"] / "Old.sol" / "Old.json",
                {"artifact": "must be removed"},
            )
            write_text(root / "out" / "ordinary-forge.txt", "ordinary output\n")

            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            first = {
                path.relative_to(paths["output"]).as_posix(): path.read_bytes()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }
            self.assertNotIn("stale.txt", first)
            self.assertNotIn("Old.sol/Old.json", first)
            self.assertNotIn("Imported.sol/Imported.json", first)
            self.assertEqual(
                (root / "out" / "ordinary-forge.txt").read_text(encoding="utf-8"),
                "ordinary output\n",
            )

            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            second = {
                path.relative_to(paths["output"]).as_posix(): path.read_bytes()
                for path in paths["output"].rglob("*")
                if path.is_file()
            }

            self.assertEqual(second, first)

    def test_check_mode_accepts_current_output_and_rejects_import_drift(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            with (
                patch.object(
                    builder,
                    "read_forge_version",
                    return_value=FAKE_FORGE_VERSION,
                ),
                redirect_stdout(StringIO()),
                redirect_stderr(StringIO()),
            ):
                self.assertEqual(
                    builder.main(
                        [
                            "--repo-root",
                            str(root),
                            "--config",
                            str(paths["config"].relative_to(root)),
                            "--foundry-config",
                            str(paths["foundry_config"].relative_to(root)),
                            "--output-dir",
                            "out-release",
                            "--check",
                        ]
                    ),
                    0,
                )

            with self.assertRaisesRegex(builder.ReleaseBuildError, "different Forge version"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    expected_forge_version=FAKE_FORGE_VERSION.replace(
                        "Commit SHA: fixture",
                        "Commit SHA: different",
                    ),
                )

            write_text(
                paths["shared"],
                "// SPDX-License-Identifier: MIT\npragma solidity 0.8.19;\nlibrary Changed {}\n",
            )
            with self.assertRaisesRegex(builder.ReleaseBuildError, "metadata keccak256"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_size_checker_rejects_aggregate_output_and_missing_receipt(self) -> None:
        cases = (
            ("aggregate output", "out", "canonical repository out-release"),
            ("missing receipt", "out-release", "missing required file"),
        )
        for label, foundry_out, expected_error in cases:
            with self.subTest(case=label):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    stderr = StringIO()
                    with redirect_stdout(StringIO()), redirect_stderr(stderr):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                foundry_out,
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(
                        "canonical release output validation failed",
                        stderr.getvalue(),
                    )
                    self.assertIn(expected_error, stderr.getvalue())

    def test_size_and_core_checkers_accept_valid_canonical_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            custom_foundry_config = root / "config" / "release-foundry.toml"
            write_text(
                custom_foundry_config,
                paths["foundry_config"].read_text(encoding="utf-8"),
            )
            paths["foundry_config"] = custom_foundry_config
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            common_args = [
                "--repo-root",
                str(root),
                "--config",
                str(paths["config"].relative_to(root)),
                "--foundry-config",
                str(paths["foundry_config"].relative_to(root)),
                "--foundry-out",
                builder.DEFAULT_OUTPUT_DIR.as_posix(),
            ]
            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                self.assertEqual(size_checker.main(common_args), 0)

            with (
                patch.object(core_checker, "check_policy", return_value=0) as policy,
                redirect_stdout(StringIO()),
                redirect_stderr(StringIO()),
            ):
                self.assertEqual(core_checker.main(common_args), 0)
            validated_manifest = policy.call_args.args[3]
            self.assertIsInstance(validated_manifest, dict)
            policy.assert_called_once_with(
                root.resolve(),
                Path(paths["config"].relative_to(root)),
                builder.DEFAULT_OUTPUT_DIR,
                validated_manifest,
            )

            noncanonical_args = [
                *common_args[:-1],
                "out",
            ]
            stderr = StringIO()
            with (
                patch.object(core_checker, "check_policy", return_value=0) as policy,
                redirect_stdout(StringIO()),
                redirect_stderr(stderr),
            ):
                self.assertEqual(core_checker.main(noncanonical_args), 1)
            policy.assert_not_called()
            self.assertIn("canonical repository out-release", stderr.getvalue())

    def test_size_checker_rejects_consumed_file_mutation_after_receipt_validation(
        self,
    ) -> None:
        for mutated_file in ("artifact", "config"):
            with self.subTest(mutated_file=mutated_file):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )

                    mutation_path = (
                        paths["output"] / "Example.sol" / "Example.json"
                        if mutated_file == "artifact"
                        else paths["config"]
                    )
                    original_validate = size_checker.validate_canonical_release_output

                    def validate_then_mutate(*args: Any, **kwargs: Any) -> dict[str, Any]:
                        manifest = original_validate(*args, **kwargs)
                        mutation_path.write_bytes(mutation_path.read_bytes() + b"\n")
                        return manifest

                    stderr = StringIO()
                    with (
                        patch.object(
                            size_checker,
                            "validate_canonical_release_output",
                            side_effect=validate_then_mutate,
                        ),
                        redirect_stdout(StringIO()),
                        redirect_stderr(stderr),
                    ):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                builder.DEFAULT_OUTPUT_DIR.as_posix(),
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(
                        "no longer matches the validated canonical release receipt",
                        stderr.getvalue(),
                    )

    def test_size_checker_rejects_import_loss_after_receipt_validation(
        self,
    ) -> None:
        for mutation in ("deleted", "directory"):
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )

                    original_validate = size_checker.validate_canonical_release_output

                    def validate_then_remove_import(
                        *args: Any,
                        **kwargs: Any,
                    ) -> dict[str, Any]:
                        manifest = original_validate(*args, **kwargs)
                        paths["shared"].unlink()
                        if mutation == "directory":
                            paths["shared"].mkdir()
                        return manifest

                    stderr = StringIO()
                    with (
                        patch.object(
                            size_checker,
                            "validate_canonical_release_output",
                            side_effect=validate_then_remove_import,
                        ),
                        redirect_stdout(StringIO()),
                        redirect_stderr(stderr),
                    ):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                builder.DEFAULT_OUTPUT_DIR.as_posix(),
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(
                        "source file is missing or not a regular file",
                        stderr.getvalue(),
                    )
                    self.assertIn(
                        "Shared.sol",
                        stderr.getvalue(),
                    )

    def test_size_checker_rejects_restricted_source_in_retained_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            restricted_source = "test/ReceiptLeak.t.sol"
            restricted_content = (
                "// SPDX-License-Identifier: MIT\n"
                "pragma solidity 0.8.19;\n"
                "contract ReceiptLeak {}\n"
            )
            write_text(root / restricted_source, restricted_content)
            compiler_input_path = (
                paths["output"] / "compiler-inputs" / "000-Example.json"
            )
            compiler_input = json.loads(
                compiler_input_path.read_text(encoding="utf-8")
            )
            compiler_input["sources"][restricted_source] = {
                "content": restricted_content
            }
            compiler_input_path.write_bytes(
                builder.ordered_json_bytes(compiler_input)
            )

            manifest_path = paths["output"] / builder.MANIFEST_FILENAME
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            compiler_input_hash = builder.file_sha256(compiler_input_path)
            for record in manifest["targets"]:
                if (
                    record["compiler_input_relative_path"]
                    == "compiler-inputs/000-Example.json"
                ):
                    record["compiler_input_sha256"] = compiler_input_hash
            write_json(manifest_path, manifest)

            stderr = StringIO()
            with redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = size_checker.main(
                    [
                        "--repo-root",
                        str(root),
                        "--config",
                        str(paths["config"].relative_to(root)),
                        "--foundry-config",
                        str(paths["foundry_config"].relative_to(root)),
                        "--foundry-out",
                        builder.DEFAULT_OUTPUT_DIR.as_posix(),
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "restricted canonical release source root",
                stderr.getvalue(),
            )

    def test_size_checker_rejects_stale_receipt_version_and_root_policy(self) -> None:
        cases = (
            ("generator version", "generator identity is invalid"),
            ("restricted-root policy", "compiler policy is stale"),
            ("portable-path policy", "compiler policy is stale"),
        )
        for mutation, expected_error in cases:
            with self.subTest(mutation=mutation):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )

                    manifest_path = paths["output"] / builder.MANIFEST_FILENAME
                    manifest = json.loads(
                        manifest_path.read_text(encoding="utf-8")
                    )
                    if mutation == "generator version":
                        manifest["generated_by"] = (
                            "scripts/build_release_artifacts.py:1"
                        )
                    elif mutation == "restricted-root policy":
                        del manifest["policy"]["restricted_source_roots"]
                    else:
                        del manifest["policy"]["portable_compiler_paths"]
                    write_json(manifest_path, manifest)

                    stderr = StringIO()
                    with redirect_stdout(StringIO()), redirect_stderr(stderr):
                        result = size_checker.main(
                            [
                                "--repo-root",
                                str(root),
                                "--config",
                                str(paths["config"].relative_to(root)),
                                "--foundry-config",
                                str(paths["foundry_config"].relative_to(root)),
                                "--foundry-out",
                                builder.DEFAULT_OUTPUT_DIR.as_posix(),
                            ]
                        )

                    self.assertEqual(result, 1)
                    self.assertIn(expected_error, stderr.getvalue())

    def test_rejects_post_build_compiler_input_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            compiler_input_path = (
                paths["output"] / "compiler-inputs" / "000-Example.json"
            )
            compiler_input_path.write_bytes(
                compiler_input_path.read_bytes().replace(
                    b"contract Example",
                    b"contract Changed",
                )
            )

            with self.assertRaisesRegex(builder.ReleaseBuildError, "compiler input hash is stale"):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_validator_strictly_decodes_every_security_json_input(self) -> None:
        cases = tuple(
            (boundary, variant)
            for boundary in (
                "config",
                "receipt",
                "selected artifact",
                "unselected artifact",
                "retained compiler input",
                "string metadata",
            )
            for variant in ("duplicate", "NaN")
        )
        duplicate_members = {
            "config": (
                b'"schema_version":'
                b'"6529stream.release-artifact-contracts.v1"'
            ),
            "receipt": b'"schema_version":"6529stream.release-build.v1"',
            "selected artifact": b'"abi":[]',
            "unselected artifact": b'"abi":[]',
            "retained compiler input": b'"language":"Solidity"',
            "string metadata": b'"language":"Solidity"',
        }

        for boundary, variant in cases:
            with (
                self.subTest(boundary=boundary, variant=variant),
                tempfile.TemporaryDirectory() as temp_dir,
            ):
                root = Path(temp_dir)
                paths = seed_tree(root)
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=FakeForge(),
                        forge_version_output=FAKE_FORGE_VERSION,
                    )

                manifest_path = paths["output"] / builder.MANIFEST_FILENAME
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                member = (
                    duplicate_members[boundary]
                    if variant == "duplicate"
                    else b'"ambiguous":NaN'
                )

                if boundary == "config":
                    config_raw = append_json_object_member(
                        paths["config"].read_bytes(),
                        member,
                    )
                    paths["config"].write_bytes(config_raw)
                    manifest["source"]["config_sha256"] = builder.sha256_bytes(
                        config_raw
                    )
                    write_json(manifest_path, manifest)
                elif boundary == "receipt":
                    manifest_path.write_bytes(
                        append_json_object_member(
                            manifest_path.read_bytes(),
                            member,
                        )
                    )
                elif boundary in {
                    "selected artifact",
                    "unselected artifact",
                }:
                    target_name = (
                        "Example"
                        if boundary == "selected artifact"
                        else "IExample"
                    )
                    record = next(
                        item
                        for item in manifest["targets"]
                        if item["name"] == target_name
                    )
                    artifact_path = (
                        paths["output"] / record["artifact_relative_path"]
                    )
                    artifact_raw = append_json_object_member(
                        artifact_path.read_bytes(),
                        member,
                    )
                    artifact_path.write_bytes(artifact_raw)
                    record["artifact_sha256"] = builder.sha256_bytes(
                        artifact_raw
                    )
                    write_json(manifest_path, manifest)
                elif boundary == "retained compiler input":
                    record = next(
                        item
                        for item in manifest["targets"]
                        if item["name"] == "Example"
                    )
                    relative_input = record["compiler_input_relative_path"]
                    compiler_input_path = paths["output"] / relative_input
                    compiler_input_raw = append_json_object_member(
                        compiler_input_path.read_bytes(),
                        member,
                    )
                    compiler_input_path.write_bytes(compiler_input_raw)
                    compiler_input_sha256 = builder.sha256_bytes(
                        compiler_input_raw
                    )
                    for item in manifest["targets"]:
                        if (
                            item["compiler_input_relative_path"]
                            == relative_input
                        ):
                            item["compiler_input_sha256"] = (
                                compiler_input_sha256
                            )
                    write_json(manifest_path, manifest)
                else:
                    record = next(
                        item
                        for item in manifest["targets"]
                        if item["name"] == "Example"
                    )
                    artifact_path = (
                        paths["output"] / record["artifact_relative_path"]
                    )
                    artifact_value = json.loads(
                        artifact_path.read_text(encoding="utf-8")
                    )
                    metadata_raw = json.dumps(
                        artifact_value["metadata"],
                        ensure_ascii=False,
                        separators=(",", ":"),
                    ).encode("utf-8")
                    artifact_value["metadata"] = (
                        append_json_object_member(metadata_raw, member)
                        .decode("utf-8")
                    )
                    write_json(artifact_path, artifact_value)
                    record["artifact_sha256"] = builder.file_sha256(
                        artifact_path
                    )
                    write_json(manifest_path, manifest)

                expected = (
                    "duplicate JSON member"
                    if variant == "duplicate"
                    else "non-I-JSON token is forbidden: NaN"
                )
                with self.assertRaisesRegex(
                    builder.ReleaseBuildError,
                    expected,
                ):
                    builder.validate_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                    )

    def test_validator_reads_each_receipt_bound_input_once(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            manifest = json.loads(
                (paths["output"] / builder.MANIFEST_FILENAME).read_text(
                    encoding="utf-8"
                )
            )
            manifest_path = (
                paths["output"] / builder.MANIFEST_FILENAME
            ).resolve()
            tracked_paths = {
                paths["config"].resolve(),
                paths["foundry_config"].resolve(),
                manifest_path,
            }
            for record in manifest["targets"]:
                tracked_paths.add(
                    (paths["output"] / record["artifact_relative_path"]).resolve()
                )
                tracked_paths.add(
                    (
                        paths["output"]
                        / record["compiler_input_relative_path"]
                    ).resolve()
                )
            expected_raw = {
                path: path.read_bytes()
                for path in tracked_paths
            }
            read_counts = {path: 0 for path in tracked_paths}
            original_read_bytes = Path.read_bytes

            def counted_read_bytes(path: Path) -> bytes:
                resolved = path.resolve()
                if resolved in read_counts:
                    read_counts[resolved] += 1
                return original_read_bytes(path)

            with patch.object(Path, "read_bytes", new=counted_read_bytes):
                validated = builder.validate_release_output_with_snapshots(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

            self.assertEqual(
                read_counts,
                {path: 1 for path in tracked_paths},
            )
            carried = (
                validated.receipt_snapshot,
                validated.config_snapshot,
                validated.foundry_config_snapshot,
                *validated.artifact_snapshots,
            )
            carried_by_path = {
                snapshot.path: snapshot
                for snapshot in carried
            }
            expected_carried_paths = {
                manifest_path,
                paths["config"].resolve(),
                paths["foundry_config"].resolve(),
                *(
                    (
                        paths["output"]
                        / record["artifact_relative_path"]
                    ).resolve()
                    for record in manifest["targets"]
                ),
            }
            self.assertEqual(len(carried), len(expected_carried_paths))
            self.assertEqual(set(carried_by_path), expected_carried_paths)
            for path, snapshot in carried_by_path.items():
                self.assertEqual(snapshot.raw, expected_raw[path])
                self.assertEqual(
                    snapshot.sha256,
                    builder.sha256_bytes(expected_raw[path]),
                )

    def test_validator_rejects_cross_kind_source_binding_conflict_before_reads(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            manifest_path = paths["output"] / builder.MANIFEST_FILENAME
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            interface_record = next(
                record
                for record in manifest["targets"]
                if record["kind"] == "interface"
            )
            alternate_source = (
                b"// SPDX-License-Identifier: MIT\n"
                b"pragma solidity 0.8.19;\n"
                b"library AlternatingShared {}\n"
            )
            conflicting_binding = {
                "path": "smart-contracts/Shared.sol",
                "sha256": builder.sha256_bytes(alternate_source),
                "keccak256": builder.keccak256_hex(alternate_source),
            }
            interface_record["metadata_sources"] = [conflicting_binding]
            interface_record["compiler_input_sources"] = [conflicting_binding]
            write_json(manifest_path, manifest)

            shared_path = paths["shared"].resolve()
            shared_reads = 0
            original_read_bytes = Path.read_bytes

            def alternating_read_bytes(path: Path) -> bytes:
                nonlocal shared_reads
                if path.resolve() == shared_path:
                    shared_reads += 1
                    return (
                        alternate_source
                        if shared_reads % 2 == 0
                        else original_read_bytes(path)
                    )
                return original_read_bytes(path)

            with (
                patch.object(Path, "read_bytes", new=alternating_read_bytes),
                self.assertRaisesRegex(
                    builder.ReleaseBuildError,
                    "conflicting source bindings for smart-contracts/Shared.sol",
                ),
            ):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

            self.assertEqual(shared_reads, 0)

    def test_validator_rejects_noncanonical_source_path_aliases(self) -> None:
        aliases = ["smart-contracts/../smart-contracts/Shared.sol"]
        if os.name == "nt":
            aliases.append("SMART-CONTRACTS/SHARED.SOL")

        for alias in aliases:
            with self.subTest(alias=alias), tempfile.TemporaryDirectory() as temp_dir:
                root = Path(temp_dir)
                paths = seed_tree(root)
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=FakeForge(),
                        forge_version_output=FAKE_FORGE_VERSION,
                    )

                manifest_path = paths["output"] / builder.MANIFEST_FILENAME
                manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
                shared_binding = next(
                    source_record
                    for record in manifest["targets"]
                    if record["kind"] == "production_contract"
                    for source_record in record["metadata_sources"]
                    if source_record["path"] == "smart-contracts/Shared.sol"
                )
                aliased_binding = {**shared_binding, "path": alias}
                interface_record = next(
                    record
                    for record in manifest["targets"]
                    if record["kind"] == "interface"
                )
                interface_record["metadata_sources"] = [aliased_binding]
                interface_record["compiler_input_sources"] = [aliased_binding]
                write_json(manifest_path, manifest)

                with self.assertRaisesRegex(
                    builder.ReleaseBuildError,
                    "must use canonical repository spelling",
                ):
                    builder.validate_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                    )

    def test_builder_carries_single_input_snapshots_into_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            config_path = paths["config"].resolve()
            foundry_config_path = paths["foundry_config"].resolve()
            source_artifact_reads = {
                "Example.json": 0,
                "ExampleTwo.json": 0,
                "IExample.json": 0,
            }
            input_reads = {
                config_path: 0,
                foundry_config_path: 0,
            }
            original_read_bytes = Path.read_bytes

            def counted_read_bytes(path: Path) -> bytes:
                resolved = path.resolve()
                if resolved in input_reads:
                    input_reads[resolved] += 1
                if (
                    path.name in source_artifact_reads
                    and path.parent.name.endswith(".sol")
                    and "targets" in path.parts
                ):
                    source_artifact_reads[path.name] += 1
                return original_read_bytes(path)

            with (
                patch.object(Path, "read_bytes", new=counted_read_bytes),
                redirect_stdout(StringIO()),
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            # One initial producer snapshot plus staged and installed validation.
            self.assertEqual(input_reads[config_path], 3)
            self.assertEqual(input_reads[foundry_config_path], 3)
            self.assertEqual(
                source_artifact_reads,
                {name: 1 for name in source_artifact_reads},
            )

    def test_validator_rejects_absolute_path_reintroduced_into_receipt(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )

            relative_input = "compiler-inputs/000-Example.json"
            compiler_input_path = paths["output"] / relative_input
            compiler_input = json.loads(
                compiler_input_path.read_text(encoding="utf-8")
            )
            compiler_input["basePath"] = root.resolve().as_posix()
            compiler_input_path.write_bytes(
                builder.ordered_json_bytes(compiler_input)
            )

            manifest_path = paths["output"] / builder.MANIFEST_FILENAME
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            updated_hash = builder.file_sha256(compiler_input_path)
            for record in manifest["targets"]:
                if record["compiler_input_relative_path"] == relative_input:
                    record["compiler_input_sha256"] = updated_hash
            write_json(manifest_path, manifest)

            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "retained compiler input basePath must be exactly",
            ):
                builder.validate_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                )

    def test_rejects_foundry_profile_drift_before_compiling(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            content = paths["foundry_config"].read_text(encoding="utf-8")
            write_text(paths["foundry_config"], content.replace("optimizer_runs = 200", "optimizer_runs = 1"))
            fake = FakeForge()

            with self.assertRaisesRegex(builder.ReleaseBuildError, "optimizer_runs"):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(fake.commands, [])

    def test_rejects_unpinned_forge_and_sanitizes_forge_environment(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()

            with self.assertRaisesRegex(builder.ReleaseBuildError, "expected pinned 1.7.1"):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION.replace("1.7.1", "1.7.2"),
                )
            self.assertEqual(fake.commands, [])

            completed = builder.subprocess.CompletedProcess(
                ["forge", "build", "smart-contracts/Example.sol"],
                0,
                stdout="",
                stderr="",
            )
            with (
                patch.dict(
                    os.environ,
                    {
                        "DAPP_OUT": "attacker-out",
                        "FOUNDRY_PROFILE": "attacker-profile",
                        "RELEASE_BUILD_KEEP": "retained",
                    },
                ),
                patch.object(
                    builder.subprocess,
                    "run",
                    return_value=completed,
                ) as run,
            ):
                builder.run_forge(
                    ["forge", "build", "smart-contracts/Example.sol"],
                    root,
                )
            child_environment = run.call_args.kwargs["env"]
            self.assertEqual(child_environment["RELEASE_BUILD_KEEP"], "retained")
            self.assertEqual(child_environment["FOUNDRY_PROFILE"], "default")
            self.assertFalse(
                any(
                    name.upper().startswith("DAPP_")
                    or (
                        name.upper().startswith("FOUNDRY_")
                        and name.upper() != "FOUNDRY_PROFILE"
                    )
                    for name in child_environment
                )
            )

            version_result = builder.subprocess.CompletedProcess(
                ["forge", "--version"],
                0,
                stdout=FAKE_FORGE_VERSION,
                stderr="",
            )
            with (
                patch.dict(
                    os.environ,
                    {
                        "DAPP_TEST": "remove",
                        "FOUNDRY_TEST": "remove",
                        "RELEASE_BUILD_KEEP": "retained",
                    },
                ),
                patch.object(
                    builder.subprocess,
                    "run",
                    return_value=version_result,
                ) as version_run,
            ):
                self.assertEqual(
                    builder.read_forge_version("forge", root),
                    PORTABLE_FAKE_FORGE_VERSION,
                )
            version_environment = version_run.call_args.kwargs["env"]
            self.assertEqual(version_environment["RELEASE_BUILD_KEEP"], "retained")
            self.assertEqual(version_environment["FOUNDRY_PROFILE"], "default")
            self.assertFalse(
                any(
                    name.upper().startswith("DAPP_")
                    or (
                        name.upper().startswith("FOUNDRY_")
                        and name.upper() != "FOUNDRY_PROFILE"
                    )
                    for name in version_environment
                )
            )

    def test_rejects_broad_output_and_linked_inputs_before_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            fake = FakeForge()
            source = root / "smart-contracts" / "Example.sol"
            original_source = source.read_bytes()

            write_text(root / "out" / "ordinary-forge.txt", "ordinary output\n")
            for unsafe_output in (root / "out", root / "smart-contracts"):
                with self.subTest(unsafe_output=unsafe_output.name):
                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "canonical repository out-release",
                    ):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            unsafe_output,
                            runner=fake,
                            forge_version_output=FAKE_FORGE_VERSION,
                        )
            self.assertEqual(source.read_bytes(), original_source)
            self.assertEqual(
                (root / "out" / "ordinary-forge.txt").read_text(encoding="utf-8"),
                "ordinary output\n",
            )
            self.assertEqual(fake.commands, [])

            linked_config = root / "release-artifacts" / "contracts-link.json"
            try:
                linked_config.symlink_to(paths["config"])
            except OSError as exc:
                self.skipTest(f"file symlinks unavailable: {exc}")
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "symlink, junction, or reparse",
            ):
                builder.build_release_output(
                    root,
                    linked_config,
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(fake.commands, [])

            paths["output"].symlink_to(
                root / "smart-contracts",
                target_is_directory=True,
            )
            with self.assertRaisesRegex(
                builder.ReleaseBuildError,
                "symlink, junction, or reparse",
            ):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=fake,
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            self.assertEqual(source.read_bytes(), original_source)
            self.assertEqual(fake.commands, [])

    def test_validator_rejects_linked_receipt_artifact_and_compiler_input(self) -> None:
        cases = (
            Path(builder.MANIFEST_FILENAME),
            Path("Example.sol") / "Example.json",
            Path("compiler-inputs") / "000-Example.json",
        )
        for index, relative in enumerate(cases):
            with self.subTest(relative=relative.as_posix()):
                with tempfile.TemporaryDirectory() as temp_dir:
                    root = Path(temp_dir)
                    paths = seed_tree(root)
                    with redirect_stdout(StringIO()):
                        builder.build_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                            runner=FakeForge(),
                            forge_version_output=FAKE_FORGE_VERSION,
                        )
                    linked_path = paths["output"] / relative
                    moved_path = root / f"linked-target-{index}.json"
                    linked_path.replace(moved_path)
                    try:
                        linked_path.symlink_to(moved_path)
                    except OSError as exc:
                        self.skipTest(f"file symlinks unavailable: {exc}")

                    with self.assertRaisesRegex(
                        builder.ReleaseBuildError,
                        "symlink, junction, or reparse",
                    ):
                        builder.validate_release_output(
                            root,
                            paths["config"],
                            paths["foundry_config"],
                            paths["output"],
                        )

    def test_replacement_rolls_back_on_base_exception(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            output = root / builder.DEFAULT_OUTPUT_DIR
            staged_root = root / ".release-build-test"
            staged = staged_root / "aggregate"
            write_text(output / "sentinel.txt", "previous canonical output\n")
            write_text(staged / "new.txt", "new canonical output\n")

            real_replace = builder.os.replace
            replace_calls = 0

            def interrupt_second_replace(source: Path, destination: Path) -> None:
                nonlocal replace_calls
                replace_calls += 1
                if replace_calls == 2:
                    raise KeyboardInterrupt("simulated interruption")
                real_replace(source, destination)

            with (
                patch.object(
                    builder.os,
                    "replace",
                    side_effect=interrupt_second_replace,
                ),
                self.assertRaises(KeyboardInterrupt),
            ):
                builder.replace_output_directory(staged, output, staged_root)

            self.assertEqual(replace_calls, 3)
            self.assertEqual(
                (output / "sentinel.txt").read_text(encoding="utf-8"),
                "previous canonical output\n",
            )
            self.assertTrue((staged / "new.txt").is_file())

    def test_makefile_orders_release_output_writer_before_consumers(self) -> None:
        makefile = MAKEFILE_PATH.read_text(encoding="utf-8")
        expected_dependencies = [
            "release-build-check: release-build",
            "contract-size-budget-check: size release-build-check",
            "core-bytecode-spend-policy-check: size release-build-check",
            "release-artifacts: release-build-check",
            "release-artifacts-check: release-build-check",
            "source-verification-inputs: release-artifacts",
            "source-verification-inputs-check: release-artifacts-check",
            "abi-compatibility: release-build-check",
            "abi-compatibility-check: release-build-check",
        ]
        for dependency in expected_dependencies:
            with self.subTest(dependency=dependency):
                self.assertIn(dependency, makefile)
        self.assertNotIn(".NOTPARALLEL", makefile)

    def test_check_wrappers_order_release_builder_before_all_consumers(self) -> None:
        wrapper_commands = {
            "PowerShell": (
                CHECK_PS1_PATH,
                [
                    '& $pythonPath @pythonArgs "scripts\\test_release_build_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\build_release_artifacts.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_contract_size_budget.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_contract_size_budget.py"',
                    '& $pythonPath @pythonArgs "scripts\\test_core_bytecode_spend_policy.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_core_bytecode_spend_policy.py"',
                    '& $pythonPath @pythonArgs "scripts\\test_release_artifacts.py"',
                    '& $pythonPath @pythonArgs "scripts\\generate_release_artifacts.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_source_verification_inputs.py"',
                    '& $pythonPath @pythonArgs "scripts\\generate_source_verification_inputs.py" "--check"',
                    '& $pythonPath @pythonArgs "scripts\\test_abi_compatibility.py"',
                    '& $pythonPath @pythonArgs "scripts\\check_abi_compatibility.py" "--check"',
                ],
            ),
            "POSIX shell": (
                CHECK_SH_PATH,
                [
                    '"$python_bin" scripts/test_release_build_artifacts.py',
                    '"$python_bin" scripts/build_release_artifacts.py',
                    '"$python_bin" scripts/build_release_artifacts.py --check',
                    '"$python_bin" scripts/test_contract_size_budget.py',
                    '"$python_bin" scripts/check_contract_size_budget.py',
                    '"$python_bin" scripts/test_core_bytecode_spend_policy.py',
                    '"$python_bin" scripts/check_core_bytecode_spend_policy.py',
                    '"$python_bin" scripts/test_release_artifacts.py',
                    '"$python_bin" scripts/generate_release_artifacts.py --check',
                    '"$python_bin" scripts/test_source_verification_inputs.py',
                    '"$python_bin" scripts/generate_source_verification_inputs.py --check',
                    '"$python_bin" scripts/test_abi_compatibility.py',
                    '"$python_bin" scripts/check_abi_compatibility.py --check',
                ],
            ),
        }

        for wrapper_name, (path, expected_commands) in wrapper_commands.items():
            with self.subTest(wrapper=wrapper_name):
                lines = [
                    line.strip()
                    for line in path.read_text(encoding="utf-8").splitlines()
                ]
                positions: list[int] = []
                for command in expected_commands:
                    self.assertEqual(lines.count(command), 1, command)
                    positions.append(lines.index(command))
                self.assertEqual(positions, sorted(positions))

    def test_release_generator_rejects_post_build_artifact_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            artifact_path = paths["output"] / "Example.sol" / "Example.json"
            value = json.loads(artifact_path.read_text(encoding="utf-8"))
            value["deployedBytecode"]["object"] = "0x6002"
            write_json(artifact_path, value)

            stderr = StringIO()
            with working_directory(root), redirect_stdout(StringIO()), redirect_stderr(stderr):
                result = release_generator.main(
                    [
                        "--config",
                        "release-artifacts/contracts.json",
                        "--foundry-config",
                        "foundry.toml",
                        "--foundry-out",
                        "out-release",
                        "--output-dir",
                        "release-artifacts/latest",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn("artifact hash is stale", stderr.getvalue())
            self.assertFalse((root / "release-artifacts" / "latest").exists())

    def test_release_generator_rejects_mutation_after_validation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            with redirect_stdout(StringIO()):
                builder.build_release_output(
                    root,
                    paths["config"],
                    paths["foundry_config"],
                    paths["output"],
                    runner=FakeForge(),
                    forge_version_output=FAKE_FORGE_VERSION,
                )
            artifact_path = paths["output"] / "Example.sol" / "Example.json"
            original_validate = release_generator.release_build.validate_release_output

            def validate_then_mutate(*args: Any, **kwargs: Any) -> dict[str, Any]:
                receipt = original_validate(*args, **kwargs)
                value = json.loads(artifact_path.read_text(encoding="utf-8"))
                value["deployedBytecode"]["object"] = "0x6002"
                write_json(artifact_path, value)
                return receipt

            stderr = StringIO()
            with (
                patch.object(
                    release_generator.release_build,
                    "validate_release_output",
                    side_effect=validate_then_mutate,
                ),
                working_directory(root),
                redirect_stdout(StringIO()),
                redirect_stderr(stderr),
            ):
                result = release_generator.main(
                    [
                        "--config",
                        "release-artifacts/contracts.json",
                        "--foundry-config",
                        "foundry.toml",
                        "--foundry-out",
                        "out-release",
                        "--output-dir",
                        "release-artifacts/latest",
                    ]
                )

            self.assertEqual(result, 1)
            self.assertIn(
                "validated release receipt artifact hash is stale",
                stderr.getvalue(),
            )
            self.assertFalse((root / "release-artifacts" / "latest").exists())

    def test_rejects_artifact_with_wrong_compilation_target(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)

            with self.assertRaisesRegex(builder.ReleaseBuildError, "compilation target"):
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=FakeForge(wrong_target=True),
                        forge_version_output=FAKE_FORGE_VERSION,
                    )

    def test_failed_build_preserves_previous_output(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            paths = seed_tree(root)
            sentinel = paths["output"] / "sentinel.txt"
            write_text(sentinel, "previous canonical output\n")

            def fail(_command: list[str], _cwd: Path) -> None:
                raise builder.ReleaseBuildError("simulated compiler failure")

            with self.assertRaisesRegex(builder.ReleaseBuildError, "simulated compiler failure"):
                with redirect_stdout(StringIO()):
                    builder.build_release_output(
                        root,
                        paths["config"],
                        paths["foundry_config"],
                        paths["output"],
                        runner=fail,
                        forge_version_output=FAKE_FORGE_VERSION,
                    )
            self.assertEqual(sentinel.read_text(encoding="utf-8"), "previous canonical output\n")


class LUID(ctypes.Structure):
    _fields_ = [
        ("LowPart", wintypes.DWORD),
        ("HighPart", wintypes.LONG),
    ]


class LUID_AND_ATTRIBUTES(ctypes.Structure):
    _fields_ = [
        ("Luid", LUID),
        ("Attributes", wintypes.DWORD),
    ]


class TOKEN_PRIVILEGES_ONE(ctypes.Structure):
    _fields_ = [
        ("PrivilegeCount", wintypes.DWORD),
        ("Privileges", LUID_AND_ATTRIBUTES * 1),
    ]


TOKEN_INFORMATION_CLASS = ctypes.c_int
TokenPrivileges = 3
CURRENT_PROCESS_PSEUDOHANDLE = ctypes.c_void_p(-1).value
TOKEN_QUERY = 0x0008
TOKEN_ADJUST_PRIVILEGES = 0x0020
SE_PRIVILEGE_ENABLED = 0x00000002
ERROR_SUCCESS = 0
ERROR_INSUFFICIENT_BUFFER = 122
ERROR_NOT_ALL_ASSIGNED = 1300
PRIVILEGE_NAME = "SeCreateSymbolicLinkPrivilege"
TOKEN_PRIVILEGES_HEADER_BYTES = 4
LUID_AND_ATTRIBUTES_BYTES = 12
MAX_TOKEN_PRIVILEGES_BYTES = 65_536
MAX_TOKEN_PRIVILEGE_COUNT = 5_461
FSCTL_SET_REPARSE_POINT = 0x000900A4
IO_REPARSE_TAG_MOUNT_POINT = 0xA0000003

_R11_ADVAPI32: Any | None = None
R11_ADVAPI_LOAD_NEEDLE = (
    "ctypes.WinDLL(" + '"advapi32.dll", use_last_error=True)'
)


def r11_test_native() -> tuple[Any, Any]:
    global _R11_ADVAPI32
    if os.name != "nt":
        raise unittest.SkipTest("R11 native privilege fixture is Windows-only")
    if (
        ctypes.sizeof(wintypes.DWORD) != 4
        or ctypes.alignment(wintypes.DWORD) != 4
        or ctypes.sizeof(LUID) != 8
        or ctypes.alignment(LUID) != 4
        or LUID.LowPart.offset != 0
        or LUID.HighPart.offset != 4
        or ctypes.sizeof(LUID_AND_ATTRIBUTES) != 12
        or ctypes.alignment(LUID_AND_ATTRIBUTES) != 4
        or LUID_AND_ATTRIBUTES.Luid.offset != 0
        or LUID_AND_ATTRIBUTES.Attributes.offset != 8
        or ctypes.sizeof(TOKEN_PRIVILEGES_ONE) != 16
        or ctypes.alignment(TOKEN_PRIVILEGES_ONE) != 4
        or TOKEN_PRIVILEGES_ONE.PrivilegeCount.offset != 0
        or TOKEN_PRIVILEGES_ONE.Privileges.offset != 4
    ):
        raise AssertionError("R11 token ABI layout mismatch")
    if _R11_ADVAPI32 is None:
        advapi32 = ctypes.WinDLL("advapi32.dll", use_last_error=True)
        advapi32.OpenProcessToken.argtypes = [
            wintypes.HANDLE, wintypes.DWORD, ctypes.POINTER(wintypes.HANDLE),
        ]
        advapi32.OpenProcessToken.restype = wintypes.BOOL
        advapi32.LookupPrivilegeValueW.argtypes = [
            wintypes.LPCWSTR, wintypes.LPCWSTR, ctypes.POINTER(LUID),
        ]
        advapi32.LookupPrivilegeValueW.restype = wintypes.BOOL
        advapi32.AdjustTokenPrivileges.argtypes = [
            wintypes.HANDLE,
            wintypes.BOOL,
            ctypes.POINTER(TOKEN_PRIVILEGES_ONE),
            wintypes.DWORD,
            ctypes.POINTER(TOKEN_PRIVILEGES_ONE),
            ctypes.POINTER(wintypes.DWORD),
        ]
        advapi32.AdjustTokenPrivileges.restype = wintypes.BOOL
        advapi32.GetTokenInformation.argtypes = [
            wintypes.HANDLE,
            TOKEN_INFORMATION_CLASS,
            wintypes.LPVOID,
            wintypes.DWORD,
            ctypes.POINTER(wintypes.DWORD),
        ]
        advapi32.GetTokenInformation.restype = wintypes.BOOL
        _R11_ADVAPI32 = advapi32
    kernel32 = builder._kernel32()
    kernel32.DeviceIoControl.argtypes = [
        wintypes.HANDLE,
        wintypes.DWORD,
        wintypes.LPVOID,
        wintypes.DWORD,
        wintypes.LPVOID,
        wintypes.DWORD,
        ctypes.POINTER(wintypes.DWORD),
        wintypes.LPVOID,
    ]
    kernel32.DeviceIoControl.restype = wintypes.BOOL
    return _R11_ADVAPI32, kernel32


def read_token_privileges(
    token: int,
    advapi32: Any,
    *,
    storage_factory: Any | None = None,
) -> bytes:
    required = wintypes.DWORD(0)
    ctypes.set_last_error(0)
    first = advapi32.GetTokenInformation(
        token, TokenPrivileges, None, 0, ctypes.byref(required),
    )
    first_error = int(ctypes.get_last_error())
    if first or first_error != ERROR_INSUFFICIENT_BUFFER:
        raise AssertionError("TokenPrivileges size call must be false+122")
    requested = int(required.value)
    if (
        requested < TOKEN_PRIVILEGES_HEADER_BYTES
        or requested > MAX_TOKEN_PRIVILEGES_BYTES
        or requested % ctypes.sizeof(wintypes.DWORD) != 0
    ):
        raise AssertionError("TokenPrivileges size is outside the aligned local policy")
    word_count = (requested + 3) // 4
    storage = (
        (wintypes.DWORD * word_count)()
        if storage_factory is None else storage_factory(word_count)
    )
    base = ctypes.addressof(storage)
    if (
        word_count < 1
        or word_count * 4 < requested
        or base % 4 != 0
        or base % ctypes.alignment(TOKEN_PRIVILEGES_ONE) != 0
    ):
        raise AssertionError("TokenPrivileges output storage is not DWORD-aligned")
    returned = wintypes.DWORD(0)
    ctypes.set_last_error(0)
    second = advapi32.GetTokenInformation(
        token,
        TokenPrivileges,
        ctypes.cast(storage, wintypes.LPVOID),
        required.value,
        ctypes.byref(returned),
    )
    if not second:
        second_error = int(ctypes.get_last_error())
        raise OSError(second_error, "TokenPrivileges data call failed without retry")
    if returned.value != required.value:
        raise AssertionError("TokenPrivileges returned length changed")
    return bytes(ctypes.string_at(base, returned.value))


def parse_token_privileges(snapshot: bytes) -> list[tuple[int, int, int]]:
    if type(snapshot) is not bytes:
        raise AssertionError("TokenPrivileges snapshot is not immutable exact bytes")
    if len(snapshot) < TOKEN_PRIVILEGES_HEADER_BYTES or len(snapshot) % 4:
        raise AssertionError("TokenPrivileges snapshot has invalid outer length")
    count = struct.unpack_from("<I", snapshot, 0)[0]
    if count > MAX_TOKEN_PRIVILEGE_COUNT:
        raise AssertionError("TokenPrivileges count exceeds the local cap")
    expected = TOKEN_PRIVILEGES_HEADER_BYTES + LUID_AND_ATTRIBUTES_BYTES * count
    if expected != len(snapshot):
        raise AssertionError("TokenPrivileges snapshot has partial or trailing bytes")
    entries = []
    for index in range(count):
        offset = TOKEN_PRIVILEGES_HEADER_BYTES + LUID_AND_ATTRIBUTES_BYTES * index
        low = struct.unpack_from("<I", snapshot, offset)[0]
        high = struct.unpack_from("<i", snapshot, offset + 4)[0]
        attributes = struct.unpack_from("<I", snapshot, offset + 8)[0]
        entries.append((low, high, attributes))
    return entries


def unique_privilege_attributes(
    snapshot: bytes,
    wanted_luid: tuple[int, int],
) -> int:
    matches = [
        attributes
        for low, high, attributes in parse_token_privileges(snapshot)
        if (low, high) == wanted_luid
    ]
    if len(matches) != 1:
        raise AssertionError("wanted privilege must have exactly one complete entry")
    return matches[0]


def complete_privilege_snapshot(
    snapshot: bytes,
) -> dict[tuple[int, int], int]:
    entries = parse_token_privileges(snapshot)
    complete = {
        (low, high): attributes for low, high, attributes in entries
    }
    if len(complete) != len(entries):
        raise AssertionError("complete privilege snapshot has a duplicate LUID")
    return complete


def copy_token_privilege(
    wanted_luid: tuple[int, int],
    attributes: int,
) -> TOKEN_PRIVILEGES_ONE:
    value = TOKEN_PRIVILEGES_ONE()
    value.PrivilegeCount = 1
    value.Privileges[0].Luid.LowPart = wanted_luid[0]
    value.Privileges[0].Luid.HighPart = wanted_luid[1]
    value.Privileges[0].Attributes = attributes
    return value


def r11_restore_token_privilege(
    advapi32: Any,
    acquired_token: Any,
    selected_restore_instruction: TOKEN_PRIVILEGES_ONE,
    token_argument: Any,
    disable_all: Any,
    new_state: Any,
    buffer_length: Any,
    previous_state: Any,
    return_length: Any,
) -> None:
    if token_argument is not acquired_token:
        raise AssertionError("restore TokenHandle is not the acquired token")
    if disable_all is not False:
        raise AssertionError("restore DisableAllPrivileges is not literal False")
    if new_state is not selected_restore_instruction:
        raise AssertionError("restore NewState is not the selected exact instruction")
    if buffer_length != 0 or type(buffer_length) is not int:
        raise AssertionError("restore BufferLength is not DWORD zero")
    if previous_state is not None or return_length is not None:
        raise AssertionError("restore output pointers are not NULL")
    ctypes.set_last_error(0)
    restored = advapi32.AdjustTokenPrivileges(
        acquired_token,
        False,
        ctypes.byref(selected_restore_instruction),
        0,
        None,
        None,
    )
    restore_error = int(ctypes.get_last_error())
    if not restored or restore_error != ERROR_SUCCESS:
        raise OSError(restore_error, "restore adjustment failed")


def _r11_validate_privilege_lifecycle_state(
    token_acquired: bool,
    baseline_captured: bool,
    restoration_armed: bool,
    fixture_owned: bool,
) -> None:
    state = (
        token_acquired, baseline_captured, restoration_armed, fixture_owned,
    )
    reachable = (
        (False, False, False, False),
        (True, False, False, False),
        (True, True, False, False),
        (True, True, False, True),
        (True, True, True, False),
        (True, True, True, True),
    )
    if (
        any(type(gate) is not bool for gate in state)
        or state not in reachable
    ):
        raise AssertionError("privilege gate state is statically unreachable")


def r11_run_privileged_fixture(
    fixture_action: Any,
    *,
    native: tuple[Any, Any] | None = None,
    fault_hook: Any | None = None,
) -> dict[str, bool]:
    advapi32, kernel32 = native if native is not None else r11_test_native()
    token = wintypes.HANDLE()
    wanted = LUID()
    token_acquired = False
    baseline_captured = False
    restoration_armed = False
    fixture_owned = False
    original_attributes = 0
    baseline_privileges: dict[tuple[int, int], int] = {}
    wanted_luid = (0, 0)
    restore_instruction = TOKEN_PRIVILEGES_ONE()
    fixture_cleanup: Any | None = None
    failures: list[BaseException | None] = [None, None, None, None, None]
    def inject(stage: str) -> None:
        if fault_hook is not None:
            fault_hook(stage)

    _r11_validate_privilege_lifecycle_state(
        token_acquired, baseline_captured, restoration_armed, fixture_owned,
    )
    try:
        inject("before_token_acquired")
        ctypes.set_last_error(0)
        opened = advapi32.OpenProcessToken(
            CURRENT_PROCESS_PSEUDOHANDLE,
            TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES,
            ctypes.byref(token),
        )
        if not opened:
            open_error = int(ctypes.get_last_error())
            raise OSError(open_error, "OpenProcessToken failed")
        token_acquired = True
        _r11_validate_privilege_lifecycle_state(
            token_acquired, baseline_captured, restoration_armed, fixture_owned,
        )
        inject("after_token_acquired")
        ctypes.set_last_error(0)
        looked_up = advapi32.LookupPrivilegeValueW(
            None, PRIVILEGE_NAME, ctypes.byref(wanted),
        )
        if not looked_up:
            lookup_error = int(ctypes.get_last_error())
            raise OSError(lookup_error, "LookupPrivilegeValueW failed")
        wanted_luid = (int(wanted.LowPart), int(wanted.HighPart))
        inject("before_baseline_captured")
        baseline_snapshot = read_token_privileges(token, advapi32)
        baseline_privileges = complete_privilege_snapshot(baseline_snapshot)
        if wanted_luid not in baseline_privileges:
            raise AssertionError("baseline has no unique wanted privilege provenance")
        original_attributes = baseline_privileges[wanted_luid]
        restore_instruction = copy_token_privilege(
            wanted_luid, original_attributes,
        )
        baseline_captured = True
        _r11_validate_privilege_lifecycle_state(
            token_acquired, baseline_captured, restoration_armed, fixture_owned,
        )
        inject("after_baseline_captured")
        if not (original_attributes & SE_PRIVILEGE_ENABLED):
            request = copy_token_privilege(wanted_luid, SE_PRIVILEGE_ENABLED)
            previous = TOKEN_PRIVILEGES_ONE()
            previous_length = wintypes.DWORD(0)
            ctypes.set_last_error(0)
            inject("before_restoration_armed")
            enabled = advapi32.AdjustTokenPrivileges(
                token,
                False,
                ctypes.byref(request),
                ctypes.sizeof(TOKEN_PRIVILEGES_ONE),
                ctypes.byref(previous),
                ctypes.byref(previous_length),
            )
            enable_error = int(ctypes.get_last_error())
            if enabled:
                restoration_armed = True
                _r11_validate_privilege_lifecycle_state(
                    token_acquired, baseline_captured,
                    restoration_armed, fixture_owned,
                )
                inject("after_restoration_armed")
            if not enabled:
                raise OSError(enable_error, "enable adjustment failed")
            if enable_error != ERROR_SUCCESS:
                raise OSError(enable_error, "enable adjustment returned a privilege error")
            valid_previous = (
                previous_length.value == ctypes.sizeof(TOKEN_PRIVILEGES_ONE)
                and previous.PrivilegeCount == 1
                and int(previous.Privileges[0].Luid.LowPart) == wanted_luid[0]
                and int(previous.Privileges[0].Luid.HighPart) == wanted_luid[1]
                and int(previous.Privileges[0].Attributes) == original_attributes
            )
            if not valid_previous:
                raise AssertionError("AdjustTokenPrivileges PreviousState is malformed")
            restore_instruction = copy_token_privilege(
                wanted_luid, int(previous.Privileges[0].Attributes),
            )
            adjusted = complete_privilege_snapshot(
                read_token_privileges(token, advapi32),
            )
            expected_adjusted = dict(baseline_privileges)
            expected_adjusted[wanted_luid] = (
                original_attributes | SE_PRIVILEGE_ENABLED
            )
            if adjusted != expected_adjusted:
                raise AssertionError("post-adjust complete snapshot mismatch")

        def mark_fixture_owned(cleanup: Any) -> None:
            nonlocal fixture_owned, fixture_cleanup
            fixture_owned = True
            _r11_validate_privilege_lifecycle_state(
                token_acquired, baseline_captured,
                restoration_armed, fixture_owned,
            )
            fixture_cleanup = cleanup
            inject("after_fixture_owned")

        inject("before_fixture_owned")
        fixture_action(mark_fixture_owned, kernel32)
    except BaseException as exc:
        failures[0] = exc
    finally:
        if fixture_owned:
            try:
                if fixture_cleanup is None:
                    raise AssertionError("owned fixture has no cleanup")
                fixture_cleanup()
            except BaseException as exc:
                failures[1] = exc
        if restoration_armed:
            try:
                r11_restore_token_privilege(
                    advapi32,
                    token,
                    restore_instruction,
                    token,
                    False,
                    restore_instruction,
                    0,
                    None,
                    None,
                )
            except BaseException as exc:
                failures[2] = exc
        if baseline_captured:
            try:
                final_privileges = complete_privilege_snapshot(
                    read_token_privileges(token, advapi32),
                )
                if final_privileges != baseline_privileges:
                    raise AssertionError("final privilege snapshot differs from baseline")
            except BaseException as exc:
                failures[3] = exc
        if token_acquired:
            try:
                ctypes.set_last_error(0)
                if not kernel32.CloseHandle(token):
                    close_error = int(ctypes.get_last_error())
                    raise OSError(close_error, "token close failed")
            except BaseException as exc:
                failures[4] = exc
    for failure in failures:
        if failure is not None:
            raise failure
    return {
        "token_acquired": token_acquired,
        "baseline_captured": baseline_captured,
        "restoration_armed": restoration_armed,
        "fixture_owned": fixture_owned,
    }


def r11_mount_point_buffer(target: Path) -> bytes:
    print_name = str(target)
    builder._r11_absolute_parts(print_name)
    substitute_name = "\\??\\" + print_name
    substitute = substitute_name.encode("utf-16-le", errors="strict")
    printable = print_name.encode("utf-16-le", errors="strict")
    path_buffer = substitute + b"\x00\x00" + printable + b"\x00\x00"
    substitute_offset = 0
    print_offset = len(substitute) + 2
    complete_length = 8 + 8 + len(path_buffer)
    if complete_length > 16_384:
        raise AssertionError("mount-point buffer exceeds the 16,384-byte cap")
    body = struct.pack(
        "<HHHH", substitute_offset, len(substitute), print_offset, len(printable),
    ) + path_buffer
    raw = struct.pack("<IHH", IO_REPARSE_TAG_MOUNT_POINT, len(body), 0) + body
    if len(raw) != complete_length:
        raise AssertionError("mount-point buffer length does not reconstruct")
    return raw


def r11_device_io_control(
    kernel32: Any,
    handle: int,
    control_code: int,
    input_buffer: bytes,
) -> None:
    if control_code != FSCTL_SET_REPARSE_POINT or type(input_buffer) is not bytes:
        raise AssertionError("junction DeviceIoControl contract is not exact")
    storage = ctypes.create_string_buffer(input_buffer)
    returned = wintypes.DWORD(0)
    ctypes.set_last_error(0)
    ok = kernel32.DeviceIoControl(
        handle,
        control_code,
        ctypes.cast(storage, wintypes.LPVOID),
        len(input_buffer),
        None,
        0,
        ctypes.byref(returned),
        None,
    )
    if not ok:
        error = int(ctypes.get_last_error())
        raise OSError(error, "DeviceIoControl failed")
    if returned.value != 0:
        raise AssertionError("junction DeviceIoControl returned unexpected output bytes")


def r11_remove_junction_fixture_paths(
    junction: Path,
    target: Path,
    root: Path,
) -> None:
    failures: list[BaseException] = []
    try:
        os.rmdir(junction)
    except FileNotFoundError:
        pass
    except BaseException as exc:
        failures.append(exc)
    try:
        shutil.rmtree(target)
    except FileNotFoundError:
        pass
    except BaseException as exc:
        failures.append(exc)
    try:
        os.rmdir(root)
    except FileNotFoundError:
        pass
    except BaseException as exc:
        failures.append(exc)
    if failures:
        raise failures[0]


def r11_real_junction_fixture(
    mark_owned: Any,
    kernel32: Any,
    *,
    fault_hook: Any | None = None,
) -> None:
    root = Path(tempfile.mkdtemp(
        prefix="r11-junction-", dir=REPO_ROOT.parent,
    ))
    target = root / "target"
    junction = root / "junction"
    junction_handle = 0

    def inject(stage: str) -> None:
        if fault_hook is not None:
            fault_hook(stage)

    def cleanup() -> None:
        failures: list[BaseException] = []
        nonlocal junction_handle
        if junction_handle:
            ctypes.set_last_error(0)
            if not kernel32.CloseHandle(junction_handle):
                failures.append(
                    OSError(int(ctypes.get_last_error()), "junction handle close failed")
                )
            junction_handle = 0

        def cleanup_operation(
            before: str,
            operation: Any,
            after: str,
        ) -> None:
            try:
                inject(before)
            except BaseException as exc:
                failures.append(exc)
            try:
                operation()
            except FileNotFoundError:
                pass
            except BaseException as exc:
                failures.append(exc)
            try:
                inject(after)
            except BaseException as exc:
                failures.append(exc)

        cleanup_operation(
            "before_junction_rmdir", lambda: os.rmdir(junction),
            "after_junction_rmdir",
        )
        cleanup_operation(
            "before_target_removal", lambda: shutil.rmtree(target),
            "after_target_removal",
        )
        cleanup_operation(
            "before_root_removal", lambda: os.rmdir(root),
            "after_root_removal",
        )
        if failures:
            raise failures[0]

    try:
        inject("before_ownership_gate")
    except BaseException:
        os.rmdir(root)
        raise
    mark_owned(cleanup)
    inject("after_ownership_gate")
    inject("before_directory_creation")
    target.mkdir()
    junction.mkdir()
    inject("after_directory_creation")
    inject("before_handle_open")
    ctypes.set_last_error(0)
    opened = kernel32.CreateFileW(
        str(junction),
        0x40000000,
        0,
        None,
        builder._OPEN_EXISTING,
        builder._FILE_FLAG_BACKUP_SEMANTICS | builder._R11_FILE_FLAG_OPEN_REPARSE_POINT,
        None,
    )
    if opened == builder._INVALID_HANDLE_VALUE:
        error = int(ctypes.get_last_error())
        raise OSError(error, "junction no-follow handle open failed")
    junction_handle = int(opened)
    inject("after_handle_open")
    inject("before_set")
    r11_device_io_control(
        kernel32,
        junction_handle,
        FSCTL_SET_REPARSE_POINT,
        r11_mount_point_buffer(target),
    )
    inject("after_set")
    inject("before_handle_close")
    ctypes.set_last_error(0)
    if not kernel32.CloseHandle(junction_handle):
        error = int(ctypes.get_last_error())
        junction_handle = 0
        raise OSError(error, "junction handle close failed")
    junction_handle = 0
    inject("after_handle_close")
    with unittest.TestCase().assertRaises(builder.R11TraversalDiagnostic):
        builder.r11_native_directory_receipt(junction, "junction")


def r11_real_replacement_race_fixture(mark_owned: Any, kernel32: Any) -> None:
    root = Path(tempfile.mkdtemp(
        prefix="r11-race-", dir=REPO_ROOT.parent,
    ))
    parent = root / "parent"
    target = root / "outside-target"
    intermediate = parent / "ordinary-directory"
    selected = intermediate / "leaf.bin"
    selected_token = "race/ordinary-directory/leaf.bin"
    junction_handle = 0
    replaced = False

    def cleanup() -> None:
        nonlocal junction_handle
        failures: list[BaseException] = []
        if junction_handle:
            ctypes.set_last_error(0)
            if not kernel32.CloseHandle(junction_handle):
                failures.append(OSError(int(ctypes.get_last_error()), "race handle close failed"))
            junction_handle = 0
        for operation in (
            lambda: (
                os.rmdir(intermediate)
                if replaced else shutil.rmtree(intermediate)
            ),
            lambda: shutil.rmtree(parent),
            lambda: shutil.rmtree(target),
            lambda: os.rmdir(root),
        ):
            try:
                operation()
            except FileNotFoundError:
                pass
            except BaseException as exc:
                failures.append(exc)
        if failures:
            raise failures[0]

    mark_owned(cleanup)
    parent.mkdir()
    target.mkdir()
    (target / "leaf.bin").write_bytes(b"must-not-read")
    intermediate.mkdir()
    selected.write_bytes(b"ordinary-before-enumeration")
    original_find = builder._r11_find_snapshot

    def replace_after_snapshot(*args: Any, **kwargs: Any) -> list[dict[str, Any]]:
        nonlocal replaced, junction_handle
        records = original_find(*args, **kwargs)
        if not replaced and any(
            record.get("long_name") == intermediate.name for record in records
        ):
            shutil.rmtree(intermediate)
            intermediate.mkdir()
            ctypes.set_last_error(0)
            opened = kernel32.CreateFileW(
                str(intermediate),
                0x40000000,
                0,
                None,
                builder._OPEN_EXISTING,
                builder._FILE_FLAG_BACKUP_SEMANTICS
                | builder._R11_FILE_FLAG_OPEN_REPARSE_POINT,
                None,
            )
            if opened == builder._INVALID_HANDLE_VALUE:
                raise OSError(int(ctypes.get_last_error()), "race junction open failed")
            junction_handle = int(opened)
            r11_device_io_control(
                kernel32,
                junction_handle,
                FSCTL_SET_REPARSE_POINT,
                r11_mount_point_buffer(target),
            )
            ctypes.set_last_error(0)
            if not kernel32.CloseHandle(junction_handle):
                error = int(ctypes.get_last_error())
                junction_handle = 0
                raise OSError(error, "race junction handle close failed")
            junction_handle = 0
            replaced = True
        return records

    read_spy = Mock(wraps=os.read)
    with (
        patch.object(builder, "_r11_find_snapshot", side_effect=replace_after_snapshot),
        patch.object(builder.os, "read", read_spy),
        unittest.TestCase().assertRaises(builder.R11TraversalDiagnostic) as raised,
    ):
        builder.r11_native_read(selected, selected_token)
    if raised.exception.code != "TRAVERSAL_CHILD_REPARSE":
        raise AssertionError(
            "replacement race did not produce exact child-reparse evidence"
        )
    if (
        raised.exception.operands["operation"] != "validate_open_child"
        or raised.exception.operands["path_token"] != selected_token
        or raised.exception.operands["actual_attributes"] is None
        or raised.exception.operands["actual_attributes"]
        & (
            builder._R11_FILE_ATTRIBUTE_DIRECTORY
            | builder._R11_FILE_ATTRIBUTE_REPARSE_POINT
        )
        != (
            builder._R11_FILE_ATTRIBUTE_DIRECTORY
            | builder._R11_FILE_ATTRIBUTE_REPARSE_POINT
        )
        or raised.exception.operands["identity_before"] is None
    ):
        raise AssertionError(
            "replacement race child-reparse evidence is not exact"
        )
    if not replaced or read_spy.call_count != 0:
        raise AssertionError("replacement race followed or read the outside canary")


class R4AuthoritativeEvidenceHistory:
    def test_01_hermetic_python_b_entrypoint_has_no_path_or_user_site_dependency(
        self,
    ) -> None:
        child_cwd = os.environ.get(R4_HERMETIC_CHILD_CWD_ENV)
        if (
            os.environ.get(R4_HERMETIC_CHILD_ENV) == "1"
            and child_cwd is not None
            and child_cwd == os.getcwd()
        ):
            self.assertTrue(sys.dont_write_bytecode)
            self.assertEqual(sys.flags.no_user_site, 1)
            self.assertNotIn("PATH", os.environ)
            self.assertNotIn("PYTHONPATH", os.environ)
            self.assertEqual(os.environ.get("PYTHONNOUSERSITE"), "1")
            self.assertEqual(os.getcwd(), child_cwd)
            self.assertNotEqual(Path.cwd().resolve(), REPO_ROOT.resolve())
            self.assertTrue(Path(__file__).is_absolute())
            self.assertEqual(Path(__file__), Path(__file__).resolve())
            module_provenance = (
                (builder, SCRIPT_PATH.resolve()),
                (release_generator, GENERATOR_PATH.resolve()),
                (size_log, SIZE_LOG_PATH.resolve()),
                (
                    size_checker,
                    (REPO_ROOT / "scripts" / "check_contract_size_budget.py").resolve(),
                ),
                (
                    core_checker,
                    (
                        REPO_ROOT
                        / "scripts"
                        / "check_core_bytecode_spend_policy.py"
                    ).resolve(),
                ),
            )
            for module, expected_path in module_provenance:
                self.assertIsNotNone(module.__spec__)
                assert module.__spec__ is not None
                self.assertIsNotNone(module.__spec__.origin)
                assert module.__spec__.origin is not None
                self.assertEqual(Path(module.__file__), expected_path)
                self.assertEqual(Path(module.__spec__.origin), expected_path)
            return
        environment = {
            key: os.environ[key]
            for key in ("SYSTEMROOT", "WINDIR", "TEMP", "TMP")
            if key in os.environ
        }
        environment.update(
            {
                "PYTHONIOENCODING": "utf-8",
                "PYTHONNOUSERSITE": "1",
                R4_HERMETIC_CHILD_ENV: "1",
            }
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            environment[R4_HERMETIC_CHILD_CWD_ENV] = temp_dir
            command = [sys.executable, "-B", str(Path(__file__).resolve())]
            result = subprocess.run(
                command,
                cwd=temp_dir,
                env=environment,
                check=False,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
        self.assertNotIn("-I", command)
        self.assertNotIn("PATH", environment)
        combined = result.stdout + result.stderr
        self.assertEqual(result.returncode, 0, combined)
        self.assertIn(
            (
                "test_01_hermetic_python_b_entrypoint_has_no_path_or_user_site_"
                "dependency (__main__.R11AuthoritativeEvidenceTests."
                "test_01_hermetic_python_b_entrypoint_has_no_path_or_user_site_"
                "dependency) ... ok"
            ),
            combined,
        )
        self.assertRegex(combined, r"(?m)^Ran 1 test in ")
        self.assertRegex(combined, r"(?m)^OK$")
        self.assertNotIn("Ran 121 tests", combined)

    def test_02_legacy_call_shapes_and_semantics_remain_available_at_v5(self) -> None:
        command = builder.forge_command(
            "forge",
            Path("repo"),
            Path("foundry.toml"),
            "smart-contracts/Example.sol",
            Path("out"),
            Path("cache"),
            Path("build-info"),
        )
        parsed = builder.parse_args([])
        self.assertEqual(builder.GENERATOR_VERSION, "5")
        self.assertEqual(command[command.index("--use") + 1], builder.SOLC_VERSION)
        self.assertNotIn("--offline", command)
        self.assertIsNone(parsed.solc_bin)
        self.assertIsNone(parsed.evidence_dir)
        self.assertFalse(parsed.recover_interrupted)

    def test_03_build_and_recovery_cli_shapes_are_mutually_exclusive(self) -> None:
        valid_build = builder.parse_args(
            ["--solc-bin", "C:/solc.exe", "--evidence-dir", "C:/evidence"]
        )
        self.assertEqual(valid_build.solc_bin, Path("C:/solc.exe"))
        self.assertEqual(valid_build.evidence_dir, Path("C:/evidence"))
        valid_recovery = builder.parse_args(
            ["--recover-interrupted", "--evidence-dir", "C:/evidence"]
        )
        self.assertTrue(valid_recovery.recover_interrupted)
        invalid = (
            ["--solc-bin", "C:/solc.exe"],
            ["--evidence-dir", "C:/evidence"],
            [
                "--solc-bin",
                "C:/solc.exe",
                "--evidence-dir",
                "C:/evidence",
                "--check",
            ],
            ["--recover-interrupted"],
            [
                "--recover-interrupted",
                "--evidence-dir",
                "C:/evidence",
                "--solc-bin",
                "C:/solc.exe",
            ],
            ["--recover-interrupted", "--evidence-dir", "C:/evidence", "--check"],
        )
        for argv in invalid:
            with self.subTest(argv=argv), redirect_stderr(StringIO()):
                with self.assertRaises(SystemExit):
                    builder.parse_args(argv)

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_04_authoritative_paths_fail_closed_before_process_creation(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            ordinary = root / "tool.exe"
            ordinary.write_bytes(b"fixture")
            directory = root / "directory"
            directory.mkdir()
            receipt = builder.r4_windows_file_receipt(ordinary, "tool")
            self.assertEqual(receipt["byte_count"], 7)
            self.assertEqual(
                receipt["sha256"], "sha256:" + hashlib.sha256(b"fixture").hexdigest()
            )
            invalid = (
                (Path("relative.exe"), "PATH_NOT_ABSOLUTE", False),
                (root / "missing.exe", "PATH_MISSING", False),
                (directory, "PATH_NOT_FILE", False),
                (ordinary, "PATH_NOT_DIRECTORY", True),
                (Path(str(ordinary) + ":stream"), "PATH_ALTERNATE_DATA_STREAM", False),
            )
            for path, code, is_directory in invalid:
                with self.subTest(path=path, code=code):
                    assert_r4_failure(
                        self,
                        code,
                        builder.r4_validate_absolute_ordinary_path,
                        path,
                        "fixture",
                        directory=is_directory,
                    )
            link = root / "tool-link.exe"
            try:
                os.symlink(ordinary, link)
            except OSError:
                pass
            else:
                assert_r4_failure(
                    self,
                    "PATH_REPARSE_POINT",
                    builder.r4_windows_file_receipt,
                    link,
                    "linked tool",
                )

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_05_checkpoint_receipts_bind_path_identity_bytes_and_hash(self) -> None:
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        self.assertIn("windows_file_receipt", source)
        self.assertIn("FILE_IDENTITY_MISMATCH", source)
        self.assertIn("checkpoint", source)
        self.assertNotIn("transient_mutation_resistance", source)
        self.assertNotIn("deny_write", source)
        with tempfile.TemporaryDirectory() as temp_dir:
            journal, _evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            for ordinal in range(18):
                journal.invoke(
                    ordinal,
                    [str(forge), "--version" if ordinal == 0 else "build"],
                    Path(temp_dir),
                    phase="forge_version" if ordinal == 0 else "forge_build",
                    group_string=None if ordinal == 0 else R4_GROUP_STRINGS[ordinal - 1],
                    runner=lambda _command, _cwd: builder.CommandResult(True, 0, b"", b""),
                )
            expected_labels = [
                f"invocation-{ordinal:03d}-{position}"
                for ordinal in range(18)
                for position in ("before", "after")
            ]
            self.assertEqual(
                [checkpoint["label"] for checkpoint in journal.checkpoints],
                expected_labels,
            )
            for checkpoint in journal.checkpoints:
                for token in ("forge", "solc"):
                    self.assertEqual(
                        set(checkpoint[token]),
                        {"path", "identity", "byte_count", "sha256"},
                    )

        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            solc.write_bytes(b"changed-before")
            fake_calls: list[list[str]] = []
            assert_r4_failure(
                self,
                "COMPILER_IDENTITY_CHECKPOINT_MISMATCH",
                journal.invoke,
                0,
                [str(forge), "--version"],
                Path(temp_dir),
                phase="forge_version",
                group_string=None,
                runner=lambda command, _cwd: fake_calls.append(command),
            )
            self.assertEqual(fake_calls, [])
            self.assertFalse((evidence / "invocation-000-start.json").exists())

        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            fake_calls = []

            def mutate_after_call(
                command: list[str],
                _cwd: Path,
            ) -> builder.CommandResult:
                fake_calls.append(command)
                forge.write_bytes(b"changed-after")
                return builder.CommandResult(True, 0, b"", b"")

            assert_r4_failure(
                self,
                "COMPILER_IDENTITY_CHECKPOINT_MISMATCH",
                journal.invoke,
                0,
                [str(forge), "--version"],
                Path(temp_dir),
                phase="forge_version",
                group_string=None,
                runner=mutate_after_call,
            )
            self.assertEqual(len(fake_calls), 1)
            self.assertTrue((evidence / "invocation-000-exit.json").is_file())
            self.assertFalse((evidence / "invocation-001-start.json").exists())

    def test_06_evidence_forge_argv_selects_exact_absolute_solc_and_offline(
        self,
    ) -> None:
        solc = Path("C:/authenticated/solc-0.8.19.exe")
        command = builder.forge_command(
            "C:/authenticated/forge.exe",
            Path("C:/repo"),
            Path("C:/repo/foundry.toml"),
            "smart-contracts/Example.sol",
            Path("C:/repo/out"),
            Path("C:/repo/cache"),
            Path("C:/repo/build-info"),
            solc_bin=solc,
        )
        use_index = command.index("--use")
        self.assertEqual(
            command[use_index : use_index + 4],
            ["--use", str(solc), "--no-auto-detect", "--offline"],
        )
        self.assertEqual(command.count("--offline"), 1)
        self.assertNotIn(builder.SOLC_VERSION, command)
        normalized = builder.normalized_forge_argv(
            "smart-contracts/Example.sol",
            "foundry.toml",
            solc_bin=solc,
        )
        normalized_use = normalized.index("--use")
        self.assertEqual(
            normalized[normalized_use : normalized_use + 4],
            ["--use", str(solc), "--no-auto-detect", "--offline"],
        )
        self.assertEqual(normalized.count("--offline"), 1)

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_07_file_identity_mutex_has_one_owner_and_abandoned_policy(self) -> None:
        helper_source = "\n".join(
            (
                "import importlib.util, os, pathlib, sys, time",
                "spec = importlib.util.spec_from_file_location('r4_builder', sys.argv[1])",
                "module = importlib.util.module_from_spec(spec)",
                "sys.modules[spec.name] = module",
                "spec.loader.exec_module(module)",
                "path = pathlib.Path(sys.argv[2])",
                "action = sys.argv[3]",
                "try:",
                "    lock = module.R4WindowsDirectoryLock.acquire(",
                "        path, recovery=(action == 'recovery')",
                "    )",
                "except module.EvidenceFailure as exc:",
                "    print(exc.code, flush=True)",
                "    raise SystemExit(0)",
                "print('owned', flush=True)",
                "if action == 'abandon':",
                "    os._exit(0)",
                "release = pathlib.Path(sys.argv[4])",
                "ready = pathlib.Path(sys.argv[5])",
                "ready.write_text('owned', encoding='utf-8')",
                "deadline = time.monotonic() + 10",
                "while not release.exists():",
                "    if time.monotonic() >= deadline:",
                "        print('release-timeout', file=sys.stderr, flush=True)",
                "        raise SystemExit(2)",
                "    time.sleep(0.02)",
                "lock.close()",
            )
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            evidence = root / "evidence"
            evidence.mkdir()
            helper = root / "mutex_helper.py"
            write_text(helper, helper_source + "\n")
            release = root / "release"
            ready = root / "ready"
            alternate = evidence / ".." / evidence.name
            base = [sys.executable, "-B", str(helper), str(SCRIPT_PATH.resolve())]
            owner = subprocess.Popen(
                [*base, str(evidence), "owner", str(release), str(ready)],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
            )
            owner_stdout = ""
            owner_stderr = ""
            try:
                deadline = time.monotonic() + 10
                while (
                    not ready.is_file()
                    and owner.poll() is None
                    and time.monotonic() < deadline
                ):
                    time.sleep(0.02)
                self.assertTrue(
                    ready.is_file(),
                    f"mutex owner did not signal readiness; returncode={owner.poll()}",
                )
                loser = subprocess.run(
                    [*base, str(alternate), "contender", str(release), str(ready)],
                    check=False,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    timeout=10,
                )
                self.assertEqual(loser.returncode, 0, loser.stderr)
                self.assertEqual(loser.stdout.strip(), "EVIDENCE_LOCKED")
                self.assertEqual(list(evidence.iterdir()), [])
            finally:
                release.touch()
                try:
                    owner_stdout, owner_stderr = owner.communicate(timeout=10)
                except subprocess.TimeoutExpired:
                    owner.kill()
                    owner_stdout, owner_stderr = owner.communicate(timeout=10)
                    self.fail("mutex owner did not reap after bounded release")
            self.assertEqual(owner.returncode, 0, owner_stderr)
            self.assertEqual(owner_stdout.strip(), "owned")
            self.assertEqual(owner_stderr, "")

            real_kernel32 = builder._r4_kernel32()

            class AbandonedKernel:
                def __getattr__(self, name: str) -> Any:
                    return getattr(real_kernel32, name)

                def WaitForSingleObject(
                    self,
                    _handle: int,
                    _milliseconds: int,
                ) -> int:
                    return builder._WAIT_ABANDONED

            with patch.object(builder, "_r4_kernel32", return_value=AbandonedKernel()):
                assert_r4_failure(
                    self,
                    "LOCK_ABANDONED",
                    builder.R4WindowsDirectoryLock.acquire,
                    evidence,
                )
                recovery_lock = builder.R4WindowsDirectoryLock.acquire(
                    evidence,
                    recovery=True,
                )
                recovery_lock.close()

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_08_started_is_durable_before_fake_forge_and_cannot_be_replaced(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            sentinel = journal.publish_started()
            sentinel_bytes = (evidence / "execution-started.json").read_bytes()
            observed: list[str] = []

            def runner(_command: list[str], _cwd: Path) -> builder.CommandResult:
                self.assertTrue((evidence / "execution-started.json").is_file())
                self.assertTrue((evidence / "invocation-000-start.json").is_file())
                observed.append("called")
                return builder.CommandResult(True, 0, b"forge Version: 1.7.1", b"")

            journal.invoke(
                0,
                [str(forge), "--version"],
                Path(temp_dir),
                phase="forge_version",
                group_string=None,
                runner=runner,
            )
            self.assertEqual(observed, ["called"])
            self.assertEqual(sentinel["sequence"], 0)
            self.assertEqual((evidence / "execution-started.json").read_bytes(), sentinel_bytes)
            captured_stdout = b"captured forge stdout\n"
            captured_stderr = b"captured forge stderr\n"
            captured_result = builder.CommandResult(
                True, 0, captured_stdout, captured_stderr,
            )
            with patch.object(
                builder,
                "_r4_captured_subprocess",
                return_value=captured_result,
            ) as captured:
                explicit_result = journal.invoke(
                    1,
                    [str(forge), "--version"],
                    Path(temp_dir),
                    phase="forge_version",
                    group_string=None,
                    runner=builder.run_forge,
                )
            captured.assert_called_once()
            self.assertEqual(explicit_result.stdout, captured_stdout)
            self.assertEqual(explicit_result.stderr, captured_stderr)
            explicit_exit = json.loads(
                (evidence / "invocation-001-exit.json").read_bytes()
            )
            self.assertEqual(
                explicit_exit["operands"]["stdout_sha256"],
                "sha256:" + hashlib.sha256(captured_stdout).hexdigest(),
            )
            self.assertEqual(
                explicit_exit["operands"]["stderr_sha256"],
                "sha256:" + hashlib.sha256(captured_stderr).hexdigest(),
            )
            self.assertEqual(
                explicit_exit["schema"], builder.R4_EVIDENCE_EVENT_SCHEMA,
            )
            self.assertNotEqual(
                builder.R4_EVIDENCE_EVENT_SCHEMA, builder.EVIDENCE_EVENT_SCHEMA,
            )
            self.assertNotEqual(
                builder.R4_EVIDENCE_TERMINAL_SCHEMA,
                builder.EVIDENCE_TERMINAL_SCHEMA,
            )
            second = builder.R4ExecutionJournal(
                evidence,
                journal.invocation_id,
                journal.static_receipts,
                journal.forge_bin,
                journal.solc_bin,
            )
            assert_r4_failure(
                self,
                "PUBLISH_EVIDENCE_NO_REPLACE_COLLISION",
                second.publish_started,
            )

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_09_event_chain_hashes_complete_canonical_predecessor_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            for ordinal in range(2):
                journal.invoke(
                    ordinal,
                    [str(forge), "--version" if ordinal == 0 else "build"],
                    Path(temp_dir),
                    phase="forge_version" if ordinal == 0 else "forge_build",
                    group_string=None if ordinal == 0 else R4_GROUP_STRINGS[0],
                    runner=lambda _command, _cwd: builder.CommandResult(True, 0, b"", b""),
                )
            terminal = journal.publish_terminal("GO", None, results={"fixture": True})
            previous = None
            for sequence in range(5):
                path = evidence / builder._event_filename(sequence)
                raw = path.read_bytes()
                event = json.loads(raw)
                self.assertEqual(event["sequence"], sequence)
                self.assertEqual(event["previous_event_sha256"], previous)
                self.assertTrue(raw.endswith(b"\n"))
                self.assertEqual(raw, builder.r4_canonical_evidence_bytes(event))
                previous = builder.sha256_bytes(raw)
            self.assertEqual(terminal["event_count"], 5)
            self.assertEqual(terminal["event_head_sha256"], previous)
            self.assertEqual(
                terminal["schema"], builder.R4_EVIDENCE_TERMINAL_SCHEMA,
            )
            self.assertTrue(
                {"sequence", "previous_event_sha256", "own_sha256", "forward_event_sha256"}
                .isdisjoint(terminal)
            )
            with self.assertRaises((TypeError, ValueError, builder.EvidenceFailure)):
                builder._r11_validate_event(event)
            with self.assertRaises((TypeError, ValueError, builder.EvidenceFailure)):
                builder.r11_validate_builder_terminal(terminal)
            first_path = evidence / builder._event_filename(0)
            first = json.loads(first_path.read_bytes())
            first["schema"] = builder.EVIDENCE_EVENT_SCHEMA
            first_path.write_bytes(builder.r4_canonical_evidence_bytes(first))
            events, anomalies = builder._read_event_prefix(evidence)
            self.assertEqual(events, [])
            self.assertEqual(anomalies[0]["status"], "invalid")

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_10_success_has_exact_18_direct_calls_and_38_file_topology(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            calls: list[list[str]] = []

            def runner(command: list[str], _cwd: Path) -> builder.CommandResult:
                calls.append(command)
                return builder.CommandResult(True, 0, b"", b"")

            journal.invoke(
                0,
                [str(forge), "--version"],
                Path(temp_dir),
                phase="forge_version",
                group_string=None,
                runner=runner,
            )
            for index, group_string in enumerate(R4_GROUP_STRINGS, start=1):
                journal.invoke(
                    index,
                    [str(forge), "build", group_string.split("::", 1)[1]],
                    Path(temp_dir),
                    phase="forge_build",
                    group_string=group_string,
                    runner=runner,
                )
            terminal = journal.publish_terminal("GO", None, results={"fixture": True})
            self.assertEqual(len(calls), 18)
            self.assertEqual([call[1] for call in calls], ["--version"] + ["build"] * 17)
            self.assertEqual(terminal["event_count"], 37)
            self.assertEqual(len(list(evidence.glob("*.json"))), 38)
            self.assertEqual(
                [call["group_string"] for call in terminal["calls"]],
                [None, *R4_GROUP_STRINGS],
            )
            self.assertTrue(terminal["no_retry"])

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_11_each_fake_forge_failure_is_first_red_without_later_call(self) -> None:
        for failing_ordinal in range(18):
            with self.subTest(failing_ordinal=failing_ordinal):
                with tempfile.TemporaryDirectory() as temp_dir:
                    journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
                    journal.publish_started()
                    calls: list[int] = []
                    failure: builder.EvidenceFailure | None = None
                    for ordinal in range(18):
                        group_string = None if ordinal == 0 else R4_GROUP_STRINGS[ordinal - 1]

                        def runner(
                            _command: list[str],
                            _cwd: Path,
                            *,
                            ordinal: int = ordinal,
                        ) -> builder.CommandResult:
                            calls.append(ordinal)
                            return builder.CommandResult(
                                True,
                                17 if ordinal == failing_ordinal else 0,
                                b"",
                                b"fixture failure" if ordinal == failing_ordinal else b"",
                            )

                        try:
                            journal.invoke(
                                ordinal,
                                [str(forge), "--version" if ordinal == 0 else "build"],
                                Path(temp_dir),
                                phase="forge_version" if ordinal == 0 else "forge_build",
                                group_string=group_string,
                                runner=runner,
                            )
                        except builder.EvidenceFailure as exc:
                            failure = exc
                            break
                    self.assertIsNotNone(failure)
                    self.assertEqual(failure.code, "FORGE_NONZERO_EXIT")
                    terminal = journal.publish_terminal(
                        "NO_GO",
                        {"code": failure.code, "operands": failure.operands},
                        results={},
                    )
                    self.assertEqual(calls, list(range(failing_ordinal + 1)))
                    self.assertEqual(len(terminal["calls"]), failing_ordinal + 1)
                    self.assertFalse(
                        (evidence / f"invocation-{failing_ordinal + 1:03d}-start.json").exists()
                    )

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_12_evidence_publish_faults_never_overwrite_or_advance(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            evidence = Path(temp_dir)
            destination = evidence / "terminal.json"
            with patch.object(builder.os, "fsync", side_effect=OSError("fixture")):
                assert_r4_failure(
                    self,
                    "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION",
                    builder.r4_publish_json_no_replace,
                    evidence,
                    destination.name,
                    {"status": "NO_GO"},
                )
            self.assertFalse(destination.exists())
            self.assertEqual(list(evidence.iterdir()), [])
            destination.write_bytes(b"immutable\n")
            assert_r4_failure(
                self,
                "PUBLISH_EVIDENCE_NO_REPLACE_COLLISION",
                builder.r4_publish_json_no_replace,
                evidence,
                destination.name,
                {"status": "GO"},
            )
            self.assertEqual(destination.read_bytes(), b"immutable\n")

        with tempfile.TemporaryDirectory() as temp_dir:
            evidence = Path(temp_dir)
            with patch.object(builder.os, "fsync", side_effect=OSError("fixture")):
                assert_r4_failure(
                    self,
                    "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION",
                    builder.publish_json_no_replace,
                    evidence,
                    "event.json",
                    {"sequence": 0},
                )
            self.assertEqual(list(evidence.iterdir()), [])

        for publisher in (
            builder.r4_publish_json_no_replace,
            builder.publish_json_no_replace,
        ):
            with self.subTest(publisher=publisher.__name__):
                with tempfile.TemporaryDirectory() as temp_dir:
                    evidence = Path(temp_dir)
                    with patch.object(
                        builder.os, "write", side_effect=OSError("write fixture"),
                    ):
                        assert_r4_failure(
                            self,
                            "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION",
                            publisher,
                            evidence,
                            "event.json",
                            {"sequence": 0},
                        )
                    self.assertEqual(list(evidence.iterdir()), [])

        with tempfile.TemporaryDirectory() as temp_dir:
            evidence = Path(temp_dir)
            with (
                patch.object(builder.os, "fsync", side_effect=OSError("flush fixture")),
                patch.object(builder.os, "unlink", side_effect=OSError("cleanup fixture")),
            ):
                failure = assert_r4_failure(
                    self,
                    "OP_EVIDENCE_TEMP_FLUSH_EXCEPTION",
                    builder.publish_json_no_replace,
                    evidence,
                    "event.json",
                    {"sequence": 0},
                )
            self.assertEqual(str(failure.__cause__), "flush fixture")
            self.assertFalse((evidence / "event.json").exists())

        real_publish = builder.r4_publish_json_no_replace
        for failing_name, expected_calls in (
            ("invocation-000-start.json", 0),
            ("invocation-000-exit.json", 1),
        ):
            with self.subTest(boundary=failing_name):
                with tempfile.TemporaryDirectory() as temp_dir:
                    journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
                    journal.publish_started()
                    calls: list[list[str]] = []

                    def publish(
                        directory: Path,
                        name: str,
                        value: Any,
                    ) -> tuple[bytes, str]:
                        if name == failing_name:
                            raise builder.EvidenceFailure(
                                "INJECTED_EVENT_PUBLISH_FAILURE",
                                name,
                            )
                        return real_publish(directory, name, value)

                    with patch.object(builder, "r4_publish_json_no_replace", side_effect=publish):
                        assert_r4_failure(
                            self,
                            "INJECTED_EVENT_PUBLISH_FAILURE",
                            journal.invoke,
                            0,
                            [str(forge), "--version"],
                            Path(temp_dir),
                            phase="forge_version",
                            group_string=None,
                            runner=lambda command, _cwd: calls.append(command),
                        )
                    self.assertEqual(len(calls), expected_calls)
                    self.assertFalse((evidence / "invocation-001-start.json").exists())

        with tempfile.TemporaryDirectory() as temp_dir:
            evidence = Path(temp_dir)
            with (
                patch.object(builder.os, "getpid", return_value=1),
                patch.object(builder.time, "monotonic_ns", return_value=2),
            ):
                for attempt in range(32):
                    (evidence / f".event.json.1.2.{attempt}.tmp").write_bytes(b"x")
                assert_r4_failure(
                    self,
                    "EVIDENCE_TEMP_COLLISION",
                    builder.r4_publish_json_no_replace,
                    evidence,
                    "event.json",
                    {"sequence": 0},
                )
            self.assertFalse((evidence / "event.json").exists())

    @unittest.skipUnless(os.name == "nt", "atomic R4 primitives are Windows-only")
    def test_13_windows_file_and_directory_publication_is_atomic_no_replace(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            raw, digest = builder.r4_publish_json_no_replace(
                root,
                "event.json",
                {"sequence": 0},
            )
            self.assertEqual((root / "event.json").read_bytes(), raw)
            self.assertEqual(digest, builder.sha256_bytes(raw))
            assert_r4_failure(
                self,
                "PUBLISH_EVIDENCE_NO_REPLACE_COLLISION",
                builder.r4_publish_json_no_replace,
                root,
                "event.json",
                {"sequence": 1},
            )
            self.assertEqual((root / "event.json").read_bytes(), raw)

            staged = root / "staged"
            staged.mkdir()
            (staged / "artifact.json").write_bytes(b"first")
            output = root / "out-release"
            builder.r4_install_output_no_replace(staged, output)
            self.assertEqual((output / "artifact.json").read_bytes(), b"first")
            second = root / "second"
            second.mkdir()
            (second / "artifact.json").write_bytes(b"second")
            assert_r4_failure(
                self,
                "INSTALL_OUTPUT_NO_REPLACE_COLLISION",
                builder.r4_install_output_no_replace,
                second,
                output,
            )
            self.assertEqual((output / "artifact.json").read_bytes(), b"first")
            self.assertEqual((second / "artifact.json").read_bytes(), b"second")

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_14_caught_base_exceptions_share_no_go_and_pre_event_red_is_empty(
        self,
    ) -> None:
        terminal_shapes = []
        for exception in (
            RuntimeError("ordinary"),
            SystemExit(9),
            KeyboardInterrupt(),
        ):
            with self.subTest(exception=type(exception).__name__):
                with tempfile.TemporaryDirectory() as temp_dir:
                    journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
                    assert_r4_failure(
                        self,
                        "STATE_NOT_STARTED",
                        journal.invoke,
                        0,
                        [str(forge), "--version"],
                        Path(temp_dir),
                        phase="forge_version",
                        group_string=None,
                    )
                    assert_r4_failure(
                        self,
                        "STATE_NOT_STARTED",
                        journal.publish_terminal,
                        "NO_GO",
                        {"code": "pre_event_red", "operands": {}},
                        results={},
                    )
                    self.assertEqual(list(evidence.iterdir()), [])
                    journal.publish_started()

                    def fail(_command: list[str], _cwd: Path) -> None:
                        raise exception

                    failure = assert_r4_failure(
                        self,
                        "CALL_EXCEPTION",
                        journal.invoke,
                        0,
                        [str(forge), "--version"],
                        Path(temp_dir),
                        phase="forge_version",
                        group_string=None,
                        runner=fail,
                    )
                    terminal = journal.publish_terminal(
                        "NO_GO",
                        {"code": failure.code, "operands": failure.operands},
                        results={},
                    )
                    terminal_shapes.append(tuple(sorted(terminal)))
                    self.assertEqual(terminal["status"], "NO_GO")
                    self.assertEqual(terminal["first_red"]["code"], "CALL_EXCEPTION")
                    self.assertEqual(len(terminal["calls"]), 1)
        self.assertEqual(len(set(terminal_shapes)), 1)

        with tempfile.TemporaryDirectory() as temp_dir:
            journal, evidence, forge, _solc = r4_journal_fixture(Path(temp_dir))
            journal.publish_started()
            journal._publish_event(
                "invocation-000-start.json",
                "invocation_start",
                "forge_version",
                {"ordinal": 0, "argv": [str(forge), "--version"]},
            )
            self.assertEqual(len(list(evidence.glob("*.json"))), 2)
            self.assertFalse((evidence / "terminal.json").exists())

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_15_recovery_only_hashes_sentinel_tokens_and_emits_no_go(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-recovery-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            evidence = root / "evidence"
            evidence.mkdir()
            matching = root / "matching.bin"
            matching.write_bytes(b"matching")
            mutated = root / "mutated.bin"
            mutated.write_bytes(b"before")
            missing = root / "missing.bin"
            missing.write_bytes(b"present")
            unreadable = root / "unreadable-directory"
            unreadable.mkdir()
            sentinel, path_tokens = r11_canonical_recovery_started(
                evidence,
                matching=matching,
                mutated=mutated,
                missing=missing,
                unreadable=unreadable,
            )
            expected_static = (
                "builder", "test", "config", "foundry_config", "forge", "solc",
                "repo_root", "evidence_dir", "output_dir", "source_aggregate",
            )
            expected_sources = tuple(
                f"source:{path}" for path in R11_LITERAL_SOURCE_PATHS
            )
            self.assertEqual(
                tuple(sorted(
                    {
                        path
                        for group in builder.R4_GROUPS
                        for path in group["sources"]
                    },
                    key=str.casefold,
                )),
                R11_LITERAL_SOURCE_PATHS,
            )
            self.assertEqual(tuple(path_tokens), expected_static + expected_sources)
            self.assertEqual(
                sentinel["invocation_id"],
                r11_independent_invocation_id(sentinel["operands"]),
            )
            builder.publish_json_no_replace(
                evidence,
                "execution-started.json",
                sentinel,
            )
            residue = evidence / ".unpublished.tmp"
            residue.write_bytes(b"residue")
            mutated.write_bytes(b"after")
            missing.unlink()
            preserved = {
                path: path.read_bytes()
                for path in (
                    evidence / "execution-started.json", residue,
                    matching, mutated,
                )
            }
            real_native_read = builder.r11_native_read
            with (
                patch.object(builder.subprocess, "run") as subprocess_run,
                patch.object(builder, "validate_ordered_bytecode") as bytecode_predicate,
                patch.object(builder, "validate_target_artifact_data") as metadata_predicate,
                patch.object(builder, "validate_authoritative_output") as output_predicate,
                patch.object(builder, "windows_file_receipt") as receipt_spy,
                patch.object(
                    builder,
                    "r11_native_read",
                    wraps=real_native_read,
                ) as direct_read_spy,
                patch.object(builder.shutil, "rmtree") as cleanup_spy,
            ):
                terminal = builder.recover_interrupted(evidence)
            subprocess_run.assert_not_called()
            bytecode_predicate.assert_not_called()
            metadata_predicate.assert_not_called()
            output_predicate.assert_not_called()
            receipt_spy.assert_not_called()
            direct_read_spy.assert_called_once_with(
                evidence / "terminal.json", "terminal.json",
            )
            cleanup_spy.assert_not_called()
            self.assertEqual(
                (evidence / "terminal.json").read_bytes(),
                builder.canonical_evidence_bytes(terminal),
            )
            self.assertEqual(terminal["results"]["path_token_status"], [])
            self.assertEqual(terminal["status"], "NO_GO")
            self.assertEqual(terminal["first_red"]["code"], "interrupted_execution")
            self.assertEqual(terminal["event_count"], 1)
            self.assertEqual(terminal["results"]["predicates_evaluated"], 0)
            self.assertEqual(terminal["results"]["subprocess_calls"], 0)
            self.assertFalse(terminal["results"]["output_validated"])
            for path, raw in preserved.items():
                self.assertEqual(path.read_bytes(), raw)
            self.assertEqual(
                sorted(path.name for path in evidence.iterdir()),
                [".unpublished.tmp", "execution-started.json", "terminal.json"],
            )
            builder._close_active_evidence_locks()

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_16_recovery_rejects_invalid_states_without_writing(self) -> None:
        class FakeLock:
            identity = r11_test_identity()

            def __init__(self) -> None:
                self.closed = False

            def close(self) -> None:
                self.closed = True

        class FakeRetainedTree:
            def __init__(
                self,
                names: tuple[str, ...],
                file_bytes: dict[str, bytes],
            ) -> None:
                self.entries = [{"name": name} for name in names]
                self.files = tuple(file_bytes)
                self.file_bytes = dict(file_bytes)
                self.selected: list[str] = []

            def __enter__(self) -> "FakeRetainedTree":
                return self

            def __exit__(self, *_exc: Any) -> None:
                return None

            def select_read_order(
                self, names: list[str], *, require_sorted: bool,
            ) -> None:
                self.selected = list(names)
                if require_sorted:
                    raise AssertionError("recovery selection must preserve event order")

            def read_file(self, name: str) -> bytes:
                return self.file_bytes[name]

        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            noncanonical_raw = (
                b'{ "schema": "6529stream.release-builder-event.v1" }\n'
            )
            self.assertNotEqual(
                noncanonical_raw,
                builder.canonical_evidence_bytes(json.loads(noncanonical_raw)),
            )
            cases = (
                ("empty", (), {}, "EMPTY"),
                ("missing-sentinel", ("residue.tmp",), {"residue.tmp": b"residue"}, "SENTINEL_MISSING"),
                ("terminal", ("terminal.json",), {"terminal.json": b"{}\n"}, "TERMINAL"),
                (
                    "noncanonical",
                    ("execution-started.json",),
                    {"execution-started.json": noncanonical_raw},
                    "NONCANONICAL_EVIDENCE",
                ),
            )
            for case_id, names, file_bytes, code in cases:
                evidence = root / case_id
                evidence.mkdir()
                self.assertEqual(set(names), set(file_bytes))
                for name, raw in file_bytes.items():
                    (evidence / name).write_bytes(raw)
                before = {
                    path.name: path.read_bytes() for path in evidence.iterdir()
                }
                self.assertEqual(before, file_bytes)
                fake_lock = FakeLock()
                retained = FakeRetainedTree(names, file_bytes)
                with self.subTest(state=evidence.name):
                    with (
                        patch.object(
                            builder,
                            "validate_absolute_ordinary_path",
                            side_effect=lambda value, _label, **_kwargs: Path(value),
                        ),
                        patch.object(
                            builder.WindowsDirectoryLock,
                            "acquire",
                            return_value=fake_lock,
                        ),
                        patch.object(
                            builder, "R11RetainedTree", return_value=retained,
                        ),
                        patch.object(builder, "_kernel32") as native_api,
                        patch.object(builder, "r11_native_read") as native_read,
                        patch.object(builder, "r11_native_inventory") as native_inventory,
                        patch.object(builder, "_captured_subprocess") as process_call,
                        patch.object(builder.subprocess, "run") as process_api,
                        patch.object(builder, "_r11_publish_preconstructed") as publication,
                        patch.object(builder, "publish_json_no_replace") as legacy_publication,
                        patch.object(builder, "validate_ordered_bytecode") as bytecode,
                    ):
                        assert_r4_failure(
                            self, code, builder.recover_interrupted, evidence,
                        )
                    self.assertTrue(fake_lock.closed)
                    after = {
                        path.name: path.read_bytes() for path in evidence.iterdir()
                    }
                    self.assertEqual(after, before)
                    self.assertEqual(after, file_bytes)
                    native_api.assert_not_called()
                    native_read.assert_not_called()
                    native_inventory.assert_not_called()
                    process_call.assert_not_called()
                    process_api.assert_not_called()
                    publication.assert_not_called()
                    legacy_publication.assert_not_called()
                    bytecode.assert_not_called()

            concurrent = root / "concurrent"
            concurrent.mkdir()
            with (
                patch.object(
                    builder,
                    "validate_absolute_ordinary_path",
                    side_effect=lambda value, _label, **_kwargs: Path(value),
                ),
                patch.object(
                    builder.WindowsDirectoryLock,
                    "acquire",
                    side_effect=builder.EvidenceFailure("EVIDENCE_LOCKED", "fixture"),
                ),
                patch.object(builder, "R11RetainedTree") as retained_tree,
                patch.object(builder, "_kernel32") as native_api,
                patch.object(builder, "_captured_subprocess") as process_call,
                patch.object(builder.subprocess, "run") as process_api,
                patch.object(builder, "_r11_publish_preconstructed") as publication,
                patch.object(builder, "publish_json_no_replace") as legacy_publication,
                patch.object(builder, "validate_ordered_bytecode") as bytecode,
            ):
                assert_r4_failure(
                    self,
                    "EVIDENCE_LOCKED",
                    builder.recover_interrupted,
                    concurrent,
                )
            retained_tree.assert_not_called()
            native_api.assert_not_called()
            process_call.assert_not_called()
            process_api.assert_not_called()
            publication.assert_not_called()
            legacy_publication.assert_not_called()
            bytecode.assert_not_called()
            self.assertEqual(list(concurrent.iterdir()), [])

    def test_17_success_commit_order_is_staged_install_cleanup_readback_go(self) -> None:
        source = inspect.getsource(builder._build_release_output_evidence_r11)
        commit_tokens = (
            '_r11_snapshot_tree(staged, "staged")',
            "_r11_install_output_no_replace(staged, output_dir, results)",
            "_r11_cleanup_build_temp(temp_root, results)",
            'installed = R11RetainedTree(output_dir, "installed")',
            "_r11_read_retained_output(",
            'journal.publish_terminal("GO", None, results=results)',
        )
        for token in commit_tokens:
            self.assertEqual(source.count(token), 1, token)
        self.assertEqual(
            tuple(sorted(source.index(token) for token in commit_tokens)),
            tuple(source.index(token) for token in commit_tokens),
        )

    @unittest.skipUnless(os.name == "nt", "R11 evidence mode is Windows-only")
    def test_18_quarantined_output_is_never_rolled_back_repaired_or_reused(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-inherited-output-mutation-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            output = root / "out-release"
            manifest, output_bytes, results = r11_literal_installed_output(output)
            context_root = root / "active-r11-go"
            context_root.mkdir()
            context = r11_independent_terminal_context(
                context_root,
                status="GO",
                first_red=None,
                results=results,
            )
            terminal = r11_install_literal_terminal_fixture(context)
            self.assertEqual(
                builder.validate_authoritative_output(
                    output, context["evidence_directory"],
                ),
                manifest,
            )
            self.assertEqual(terminal, context["terminal"])
            first_name = sorted(output_bytes)[0]
            first = output / first_name
            first.write_bytes(b"mutated\n")
            assert_r4_failure(
                self,
                "OUTPUT_BYTES_MISMATCH",
                builder.validate_authoritative_output,
                output,
                context["evidence_directory"],
            )
            self.assertEqual(first.read_bytes(), b"mutated\n")

        with tempfile.TemporaryDirectory(
            prefix="r11-inherited-terminal-fault-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            output = root / "out-release"
            _manifest, output_bytes, results = r11_literal_installed_output(output)
            sentinel_name = sorted(output_bytes)[-1]
            sentinel = output / sentinel_name
            sentinel_raw = sentinel.read_bytes()
            context_root = root / "active-r11-terminal-fault"
            context_root.mkdir()
            context = r11_independent_terminal_context(
                context_root,
                status="GO",
                first_red=None,
                results=results,
            )
            replay = r11_materialize_candidate_journal(context)
            journal, authority, run_lock, leases = (
                r11_authorize_candidate_journal(context, replay)
            )
            with patch.object(
                journal,
                "_candidate_terminal_gate",
                side_effect=builder.EvidenceFailure(
                    "TERMINAL_NAMESPACE_VETO",
                    "fixture candidate gate failure",
                ),
            ):
                assert_r4_failure(
                    self,
                    "TERMINAL_NAMESPACE_VETO",
                    journal.publish_terminal,
                    "GO",
                    None,
                    results=results,
                )
            self.assertTrue(authority.closed)
            self.assertFalse(run_lock.owned)
            self.assertFalse(leases.owned)
            self.assertNotIn(run_lock, builder._ACTIVE_EVIDENCE_LOCKS)
            self.assertEqual(builder._ACTIVE_EVIDENCE_LOCKS, [])
            self.assertTrue(
                all(record["handle"] == 0 for record in leases.records),
            )
            journal, authority, run_lock, leases = (
                r11_authorize_candidate_journal(context, replay)
            )
            with patch.object(
                builder,
                "_r11_publish_preconstructed",
                side_effect=builder.EvidenceFailure(
                    "OP_TERMINAL_GO_PUBLISH_EXCEPTION",
                    "fixture durable publisher failure",
                ),
            ):
                assert_r4_failure(
                    self,
                    "OP_TERMINAL_GO_PUBLISH_EXCEPTION",
                    journal.publish_terminal,
                    "GO",
                    None,
                    results=results,
                )
            self.assertTrue(authority.closed)
            self.assertFalse(run_lock.owned)
            self.assertFalse(leases.owned)
            self.assertNotIn(run_lock, builder._ACTIVE_EVIDENCE_LOCKS)
            self.assertEqual(builder._ACTIVE_EVIDENCE_LOCKS, [])
            self.assertTrue(
                all(record["handle"] == 0 for record in leases.records),
            )
            reacquired = builder.WindowsDirectoryLock.acquire(
                context["evidence_directory"],
            )
            reacquired.close()
            self.assertFalse(
                (context["evidence_directory"] / "terminal.json").exists(),
            )
            self.assertEqual(sentinel.read_bytes(), sentinel_raw)
            self.assertEqual(len(list(output.rglob("*"))), 37)
            self.assertTrue(results["output_installed"])
            self.assertTrue(results["output_quarantine_without_matching_go"])

    @unittest.skipUnless(os.name == "nt", "R11 evidence mode is Windows-only")
    def test_33_success_binds_exact_output_evidence_and_measurement_topology(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-inherited-success-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            output = root / "out-release"
            manifest, _output_bytes, results = r11_literal_installed_output(output)
            success_root = root / "active-r11-success"
            success_root.mkdir()
            context = r11_independent_terminal_context(
                success_root,
                status="GO",
                first_red=None,
                results=results,
            )
            terminal = r11_install_literal_terminal_fixture(context)
            validated_manifest = builder.validate_authoritative_output(
                output, context["evidence_directory"],
            )
            self.assertEqual(validated_manifest, manifest)
            self.assertEqual(
                (
                    terminal["event_count"], len(terminal["calls"]),
                    len(terminal["checkpoints"]),
                    len(terminal["results"]["output_files"]),
                    len(terminal["results"]["artifacts"]),
                    len(terminal["results"]["aggregates"]),
                    len(list(context["evidence_directory"].iterdir())),
                ),
                (37, 18, 37, 37, 19, 11, 38),
            )
            measurements = {
                artifact["semantic_id"]: artifact
                for artifact in terminal["results"]["artifacts"]
            }
            self.assertEqual(
                tuple(
                    (
                        row["gate"], tuple(row["members"]), row["field"],
                        tuple(row["operands"]), row["actual"], row["operator"],
                        row["threshold"], row["passed"],
                    )
                    for row in terminal["results"]["aggregates"]
                ),
                tuple(
                    (
                        gate, members, metric,
                        tuple(measurements[member][metric] for member in members),
                        sum(measurements[member][metric] for member in members),
                        "<=", threshold, True,
                    )
                    for _trigger, gate, members, metric, threshold
                    in R11_LITERAL_AGGREGATE_ROWS
                ),
            )
            terminal_raw = (
                context["evidence_directory"] / "terminal.json"
            ).read_bytes()
            self.assertTrue(terminal_raw.endswith(b"\n"))
            self.assertEqual(
                terminal_raw, builder.canonical_evidence_bytes(terminal),
            )
            self.assertEqual(terminal_raw, context["raw"])
            self.assertEqual(terminal, context["terminal"])

            negative_root = root / "negative"
            negative_root.mkdir()
            negative_results = r11_literal_complete_results(installed=False)
            negative_first_red = {
                "phase": "staged_validation",
                "code": "STAGED_VALIDATION_FAILED",
                "call_ordinal": None,
                "group_index": None,
                "group_string": None,
                "semantic_id": None,
                "target": None,
                "step_ordinal": None,
                "step_id": None,
                "operands": {
                    "cause_type": "TraversalError",
                    "message_sha256": r11_hash("inherited-success-negative"),
                },
            }
            negative_context = r11_independent_terminal_context(
                negative_root,
                first_red=negative_first_red,
                results=negative_results,
            )
            no_go = r11_install_literal_terminal_fixture(negative_context)
            self.assertEqual(no_go["status"], "NO_GO")
            self.assertEqual(no_go["first_red"], negative_first_red)
            self.assertEqual(no_go["results"], negative_results)
            self.assertEqual(no_go, negative_context["terminal"])
            self.assertEqual(
                (negative_context["evidence_directory"] / "terminal.json")
                .read_bytes(),
                negative_context["raw"],
            )
            self.assertEqual(
                (len(no_go["calls"]), len(no_go["checkpoints"])),
                (18, 37),
            )
            self.assertTrue(no_go["no_retry"])

    @unittest.skipUnless(os.name == "nt", "R4 evidence mode is Windows-only")
    def test_19_preexisting_output_is_preserved_and_never_reused(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-inherited-preexisting-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            repo = root / "repo"
            repo.mkdir()
            config = repo / "contracts.json"
            foundry_config = repo / "foundry.toml"
            config.write_bytes(b"{}\n")
            foundry_config.write_bytes(b"[profile.default]\n")
            output = repo / "out-release"
            output.mkdir()
            sentinel = output / "sentinel.bin"
            sentinel.write_bytes(b"quarantined")
            evidence = root / "evidence"
            evidence.mkdir()
            with (
                patch.dict(os.environ, {"TEMP": "", "TMP": ""}),
                patch.object(builder.subprocess, "run") as subprocess_run,
            ):
                assert_r4_failure(
                    self,
                    "OUTPUT_ALREADY_EXISTS",
                    builder.build_release_output,
                    repo,
                    config,
                    foundry_config,
                    output,
                    str(root / "forge.exe"),
                    solc_bin=root / "solc.exe",
                    evidence_dir=evidence,
                )
            subprocess_run.assert_not_called()
            self.assertEqual(sentinel.read_bytes(), b"quarantined")
            self.assertEqual(list(evidence.iterdir()), [])

    def test_20_exact_group_strings_are_all_and_only_the_frozen_values(self) -> None:
        actual = tuple(group["group_string"] for group in builder.GROUP_CLOSURES)
        self.assertEqual(actual, R4_GROUP_STRINGS)
        for index, group in enumerate(builder.GROUP_CLOSURES):
            self.assertEqual(
                builder.validate_evidence_group_string(index, R4_GROUP_STRINGS[index]),
                group,
            )
            sources = {path: {"content": ""} for path in group["sources"]}
            with patch.object(
                builder,
                "_source_closure_aggregate",
                return_value=group["aggregate_sha256"],
            ):
                result = builder.validate_evidence_group_closure(
                    index,
                    group["source"],
                    {"sources": sources},
                )
            self.assertEqual(result["group_string"], R4_GROUP_STRINGS[index])
            for variant in (
                f"999::{group['source']}",
                f"{index:03d}::{group['source'].replace('/', chr(92))}",
                R4_GROUP_STRINGS[index].upper(),
                f"{index:03d}::{Path(group['source']).name}",
                f"{index:03d}:{group['source']}",
            ):
                with self.subTest(index=index, variant=variant):
                    assert_r4_failure(
                        self,
                        "GROUP_STRING_MISMATCH",
                        builder.validate_evidence_group_string,
                        index,
                        variant,
                    )

    def test_21_each_group_closure_rejects_missing_added_and_foreign_sources(
        self,
    ) -> None:
        group_map = [
            {
                "group": group["group"],
                "source": group["source"].removeprefix("smart-contracts/"),
                "sources": [
                    source.removeprefix("smart-contracts/")
                    for source in group["sources"]
                ],
            }
            for group in builder.GROUP_CLOSURES
        ]
        group_map_raw = builder._authority_json_bytes(group_map)
        self.assertEqual(len(group_map_raw), 7_303)
        self.assertEqual(
            hashlib.sha256(group_map_raw).hexdigest().upper(),
            builder.R4_GROUP_MAP_SHA256,
        )
        for index, group in enumerate(builder.GROUP_CLOSURES):
            expected = tuple(group["sources"])
            valid = {path: {"content": ""} for path in expected}
            with patch.object(
                builder,
                "_source_closure_aggregate",
                return_value=group["aggregate_sha256"],
            ):
                builder.validate_evidence_group_closure(
                    index,
                    group["source"],
                    {"sources": valid},
                )
            mutations = (
                {path: {"content": ""} for path in expected[1:]},
                {
                    **valid,
                    builder.R4_ARCHITECTURE_PREFIX + "Unrelated.sol": {
                        "content": ""
                    },
                },
                {**valid, "smart-contracts/Unrelated.sol": {"content": ""}},
            )
            for sources in mutations:
                with self.subTest(index=index, sources=tuple(sources)):
                    assert_r4_failure(
                        self,
                        "GROUP_CLOSURE_MISMATCH",
                        builder.validate_evidence_group_closure,
                        index,
                        group["source"],
                        {"sources": sources},
                    )

    def test_22_group_union_is_exact_31_and_cannot_cure_local_failure(self) -> None:
        union = set().union(
            *(set(group["sources"]) for group in builder.GROUP_CLOSURES)
        )
        self.assertEqual(len(builder.GROUP_CLOSURES), 17)
        self.assertEqual(len(union), 31)
        self.assertEqual(
            builder.R4_SOURCE_AGGREGATE_SHA256,
            "1EB0A58B8A1DCA624493839D41FA5267078E7FBA67B4AE6DF9205DD003659857",
        )
        group = builder.GROUP_CLOSURES[0]
        locally_incomplete = set(group["sources"]) - {group["source"]}
        assert_r4_failure(
            self,
            "GROUP_CLOSURE_MISMATCH",
            builder.validate_evidence_group_closure,
            0,
            group["source"],
            {"sources": {path: {} for path in locally_incomplete | union}},
        )

    def test_23_portable_input_and_metadata_regressions_remain_wired(self) -> None:
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        for function_name in (
            "canonicalize_build_info_compiler_paths",
            "validate_compiler_input",
            "validate_target_artifact_data",
            "validate_release_output",
        ):
            self.assertIn(f"def {function_name}", source)
        self.assertEqual(
            builder.PORTABLE_COMPILER_PATHS,
            {
                "allowPaths": [".", "lib"],
                "basePath": ".",
                "includePaths": ["."],
            },
        )

    def test_24_metadata_admission_does_not_evaluate_bytecode(self) -> None:
        admission_source = inspect.getsource(builder._r11_metadata_and_bindings)
        self.assertNotIn("validate_ordered_bytecode", admission_source)
        self.assertNotIn("deployedBytecode", admission_source)
        self.assertNotIn('["bytecode"]', admission_source)
        build_source = inspect.getsource(builder._build_release_output_evidence_r11)
        self.assertLess(
            build_source.index("_r11_metadata_and_bindings"),
            build_source.index("validate_ordered_bytecode"),
        )

    def test_25_bytecode_phase_uses_exact_size_order_after_full_admission(self) -> None:
        expected = tuple(row[0] for row in R4_SIZE_GATES)
        actual = tuple(item["target"] for item in builder.CONSTRUCTOR_AUTHORITY)
        self.assertEqual(actual, expected)
        self.assertEqual(len(actual), 19)
        build_source = inspect.getsource(builder._build_release_output_evidence_r11)
        self.assertLess(
            build_source.rindex("_r11_metadata_and_bindings"),
            build_source.index("validate_ordered_bytecode"),
        )

    def test_26_each_bytecode_predicate_and_operation_is_typed_and_stops(self) -> None:
        self.assertEqual(tuple(builder.BYTECODE_STEPS), R4_BYTECODE_STEP_IDS)
        authority = r4_authority("StreamArtistArchiveEvidenceStoreV2Skeleton")
        structural_cases: list[tuple[str, dict[str, Any]]] = []
        candidate = r4_bytecode_artifact(authority)
        del candidate["bytecode"]
        structural_cases.append(("BC_CREATION_MISSING", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["bytecode"] = []
        structural_cases.append(("BC_CREATION_NOT_OBJECT", candidate))
        candidate = r4_bytecode_artifact(authority)
        del candidate["bytecode"]["object"]
        structural_cases.append(("BC_CREATION_OBJECT_MISSING", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["bytecode"]["object"] = 1
        structural_cases.append(("BC_CREATION_OBJECT_NOT_STRING", candidate))
        candidate = r4_bytecode_artifact(authority)
        del candidate["deployedBytecode"]
        structural_cases.append(("BC_RUNTIME_MISSING", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["deployedBytecode"] = []
        structural_cases.append(("BC_RUNTIME_NOT_OBJECT", candidate))
        candidate = r4_bytecode_artifact(authority)
        del candidate["deployedBytecode"]["object"]
        structural_cases.append(("BC_RUNTIME_OBJECT_MISSING", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["deployedBytecode"]["object"] = 1
        structural_cases.append(("BC_RUNTIME_OBJECT_NOT_STRING", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["abi"] = {}
        structural_cases.append(("ABI_NOT_ARRAY", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["abi"] = []
        structural_cases.append(("ABI_CONSTRUCTOR_COUNT", candidate))
        candidate = r4_bytecode_artifact(authority)
        candidate["abi"][0]["inputs"][0]["type"] = "uint256"
        structural_cases.append(("ABI_CONSTRUCTOR_TYPES_ORDER", candidate))
        for code, candidate in structural_cases:
            observed: list[tuple[str, dict[str, Any]]] = []
            with self.subTest(structural=code):
                assert_r4_failure(
                    self,
                    code,
                    builder.validate_ordered_bytecode,
                    candidate,
                    authority,
                    step_observer=lambda step, record: observed.append((step, record)),
                )
                self.assertLess(len(observed), len(R4_BYTECODE_STEP_IDS))
                terminal_step, terminal_record = observed[-1]
                self.assertEqual(terminal_record["status"], "false")
                self.assertIs(terminal_record["result"], False)
                self.assertEqual(terminal_record["error_code"], code)
                later = set(
                    R4_BYTECODE_STEP_IDS[
                        R4_BYTECODE_STEP_IDS.index(terminal_step) + 1 :
                    ]
                )
                self.assertTrue(later.isdisjoint(step for step, _record in observed))

        for field, code, replacement in (
            ("signature", "ABI_CONSTRUCTOR_SIGNATURE", "constructor(bytes32)"),
            ("words", "ABI_CONSTRUCTOR_WORDS", authority["words"] + 1),
            ("bytes", "ABI_CONSTRUCTOR_WIDTH", authority["bytes"] + 32),
        ):
            mutated_authority = dict(authority)
            mutated = False

            def mutate_after_shape(
                step: str,
                operands: dict[str, Any],
                *,
                field: str = field,
                replacement: Any = replacement,
            ) -> None:
                nonlocal mutated
                if (
                    step == "CONSTRUCTOR_ABI_SHAPE"
                    and operands["status"] == "pass"
                    and operands["result"] is True
                ):
                    mutated_authority[field] = replacement
                    mutated = True

            with self.subTest(metric=field):
                assert_r4_failure(
                    self,
                    code,
                    builder.validate_ordered_bytecode,
                    r4_bytecode_artifact(authority),
                    mutated_authority,
                    step_observer=mutate_after_shape,
                )
                self.assertTrue(mutated)

        operation_ids = {
            "NORMALIZE_CREATION_PREFIX",
            "NORMALIZE_RUNTIME_PREFIX",
            "DERIVE_CONSTRUCTOR_METRICS",
            "DECODE_CREATION_BYTES",
            "COMPUTE_FULL_INITCODE",
            "DECODE_RUNTIME_BYTES",
            "COMPUTE_CODE_DEPOSIT_GAS",
        }
        for operation_id in operation_ids:
            observed: list[tuple[str, dict[str, Any]]] = []

            def observer(step: str, record: dict[str, Any]) -> None:
                observed.append((step, record))

            def operation_hook(step: str, _operands: dict[str, Any]) -> None:
                if step == operation_id:
                    raise RuntimeError("injected operation failure")

            with self.subTest(operation=operation_id):
                failure = assert_r4_failure(
                    self,
                    f"OP_{operation_id}_EXCEPTION",
                    builder.validate_ordered_bytecode,
                    r4_bytecode_artifact(authority),
                    authority,
                    step_observer=observer,
                    operation_hook=operation_hook,
                )
                terminal_step, terminal_record = observed[-1]
                self.assertEqual(terminal_step, operation_id)
                self.assertEqual(terminal_record["status"], "exception")
                self.assertIsNone(terminal_record["result"])
                self.assertEqual(
                    terminal_record["error_code"],
                    f"OP_{operation_id}_EXCEPTION",
                )
                self.assertTrue(failure.operands)
                later = set(
                    R4_BYTECODE_STEP_IDS[
                        R4_BYTECODE_STEP_IDS.index(operation_id) + 1 :
                    ]
                )
                self.assertTrue(later.isdisjoint(step for step, _record in observed))

    def test_27_malformed_and_placeholder_bytecode_has_exact_first_red(self) -> None:
        authority = r4_authority("StreamArtistArchiveEvidenceStoreV2Skeleton")
        cases = (
            (("bytecode", "object"), "", "BC_CREATION_EMPTY"),
            (("bytecode", "object"), "0", "BC_CREATION_ODD_LENGTH"),
            (("bytecode", "object"), "0x0x00", "BC_CREATION_NON_HEX"),
            (("bytecode", "object"), "gg", "BC_CREATION_NON_HEX"),
            (("deployedBytecode", "object"), "", "BC_RUNTIME_EMPTY"),
            (("deployedBytecode", "object"), "0", "BC_RUNTIME_ODD_LENGTH"),
            (("deployedBytecode", "object"), "0x0X00", "BC_RUNTIME_NON_HEX"),
            (("deployedBytecode", "object"), "gg", "BC_RUNTIME_NON_HEX"),
        )
        for path, value, code in cases:
            candidate = r4_bytecode_artifact(authority)
            candidate[path[0]][path[1]] = value
            with self.subTest(path=path, value=value):
                assert_r4_failure(
                    self,
                    code,
                    builder.validate_ordered_bytecode,
                    candidate,
                    authority,
                )
        placeholder = "__$" + "a" * 34 + "$__"
        self.assertIsNotNone(R4_SOLC_PLACEHOLDER_RE.fullmatch(placeholder))
        self.assertIsNone(R4_SOLC_PLACEHOLDER_RE.fullmatch("__$" + "a" * 33 + "$__"))
        bytecode_source = inspect.getsource(builder.validate_ordered_bytecode)
        self.assertIn(r"__\$[0-9a-fA-F]{34}\$__", bytecode_source)
        self.assertNotIn(r"__\$[^$]*\$__", bytecode_source)
        for container, code in (
            ("bytecode", "BC_CREATION_UNRESOLVED_PLACEHOLDER"),
            ("deployedBytecode", "BC_RUNTIME_UNRESOLVED_PLACEHOLDER"),
        ):
            candidate = r4_bytecode_artifact(authority)
            candidate[container]["object"] = placeholder
            observed: list[str] = []
            assert_r4_failure(
                self,
                code,
                builder.validate_ordered_bytecode,
                candidate,
                authority,
                step_observer=lambda step, _operands: observed.append(step),
            )
            self.assertNotIn(
                "CREATION_FULL_HEX" if container == "bytecode" else "RUNTIME_FULL_HEX",
                observed,
            )

    def test_28_link_reference_shapes_are_independently_fail_closed(self) -> None:
        authority = r4_authority("StreamArtistArchiveEvidenceStoreV2Skeleton")
        for container, prefix in (
            ("bytecode", "BC_CREATION_LINKS"),
            ("deployedBytecode", "BC_RUNTIME_LINKS"),
        ):
            for mutation, code in (
                ("missing", f"{prefix}_MISSING"),
                ([], f"{prefix}_NOT_OBJECT"),
                ({"A.sol": {}}, f"{prefix}_NONEMPTY"),
            ):
                candidate = r4_bytecode_artifact(authority)
                if mutation == "missing":
                    del candidate[container]["linkReferences"]
                else:
                    candidate[container]["linkReferences"] = mutation
                with self.subTest(container=container, code=code):
                    assert_r4_failure(
                        self,
                        code,
                        builder.validate_ordered_bytecode,
                        candidate,
                        authority,
                    )
        wrong_path = r4_bytecode_artifact(authority)
        wrong_path["linkReferences"] = {}
        del wrong_path["bytecode"]["linkReferences"]
        assert_r4_failure(
            self,
            "BC_CREATION_LINKS_MISSING",
            builder.validate_ordered_bytecode,
            wrong_path,
            authority,
        )

    def test_29_constructor_authority_is_exact_for_all_19_targets(self) -> None:
        builder.validate_r4_authority_constants()
        constructor_map = [
            {
                "target": authority["target"],
                "signature": authority["signature"],
                "words": authority["words"],
                "bytes": authority["bytes"],
            }
            for authority in builder.CONSTRUCTOR_AUTHORITY
        ]
        constructor_map_raw = builder._authority_json_bytes(constructor_map)
        self.assertEqual(len(constructor_map_raw), 3_217)
        self.assertEqual(
            hashlib.sha256(constructor_map_raw).hexdigest().upper(),
            builder.R4_CONSTRUCTOR_MAP_SHA256,
        )
        actual = []
        verifier_total = 0
        verifier_targets = {
            "StreamArtistBindingTransitionArchiveVerifierV1Skeleton",
            "StreamArtistBindingProposalArchiveVerifierV1Skeleton",
            "StreamArtistCollaboratorArchiveVerifierV1Skeleton",
        }
        for authority in builder.CONSTRUCTOR_AUTHORITY:
            result = builder.validate_ordered_bytecode(
                r4_bytecode_artifact(authority),
                authority,
            )
            signature_types = tuple(
                authority["signature"]
                .removeprefix("constructor(")
                .removesuffix(")")
                .split(",")
            )
            actual.append((authority["target"], signature_types, authority["bytes"]))
            self.assertEqual(result["constructor_words"], len(signature_types))
            self.assertEqual(result["constructor_bytes"], authority["bytes"])
            if authority["target"] in verifier_targets:
                verifier_total += authority["bytes"]
        self.assertEqual(tuple(actual), R4_CONSTRUCTOR_AUTHORITY)
        self.assertEqual(verifier_total, 576)

    def test_30_full_initcode_includes_constructor_and_uses_strict_limit(self) -> None:
        for authority in builder.CONSTRUCTOR_AUTHORITY:
            passing_creation = builder.R4_INITCODE_LIMIT - authority["bytes"] - 1
            passing = builder.validate_ordered_bytecode(
                r4_bytecode_artifact(authority, creation_bytes=passing_creation),
                authority,
            )
            self.assertEqual(passing["full_initcode_bytes"], 49_151)
            assert_r4_failure(
                self,
                "SIZE_INITCODE_LIMIT",
                builder.validate_ordered_bytecode,
                r4_bytecode_artifact(
                    authority,
                    creation_bytes=passing_creation + 1,
                ),
                authority,
            )

    def test_31_runtime_packet_and_each_target_cap_cover_boundaries(self) -> None:
        authority = r4_authority("StreamArtistArchiveEvidenceStoreV2Skeleton")
        packet_authority = {**authority, "runtime_cap": 30_000}
        below = builder.validate_ordered_bytecode(
            r4_bytecode_artifact(packet_authority, runtime_bytes=24_575),
            packet_authority,
        )
        self.assertEqual(below["runtime_bytes"], 24_575)
        for runtime in (24_576, 24_577):
            assert_r4_failure(
                self,
                "SIZE_RUNTIME_PACKET_LIMIT",
                builder.validate_ordered_bytecode,
                r4_bytecode_artifact(packet_authority, runtime_bytes=runtime),
                packet_authority,
            )
        for target, cap, _aggregates in R4_SIZE_GATES:
            target_authority = r4_authority(target)
            for runtime in (cap - 1, cap):
                result = builder.validate_ordered_bytecode(
                    r4_bytecode_artifact(target_authority, runtime_bytes=runtime),
                    target_authority,
                )
                self.assertEqual(result["runtime_bytes"], runtime)
            assert_r4_failure(
                self,
                "SIZE_RUNTIME_TARGET_CAP",
                builder.validate_ordered_bytecode,
                r4_bytecode_artifact(target_authority, runtime_bytes=cap + 1),
                target_authority,
            )

    def test_32_aggregate_subgates_are_ordered_interleaved_and_fail_fast(self) -> None:
        measurements = {
            authority["semantic_id"]: {
                "runtime_bytes": authority["runtime_cap"],
                "full_initcode_bytes": authority["bytes"] + 1,
                "code_deposit_gas": authority["runtime_cap"] * 200,
            }
            for authority in (
                r11_literal_authority(index) for index in range(19)
            )
        }
        for semantic_id, runtime, full_initcode in (
            ("Transition", 21_666, 22_166),
            ("Proposal", 21_667, 22_167),
            ("Collaborator", 21_667, 22_167),
        ):
            measurements[semantic_id] = {
                "runtime_bytes": runtime,
                "full_initcode_bytes": full_initcode,
                "code_deposit_gas": runtime * 200,
            }
        self.assertEqual(
            tuple(
                (trigger, gate_id, tuple(members), metric, threshold)
                for trigger in (3, 7, 8, 11)
                for gate_id, members, metric, threshold
                in builder.R4_AGGREGATE_GATES[trigger]
            ),
            R11_LITERAL_AGGREGATE_ROWS,
        )
        expected_ids = tuple(row[1] for row in R11_LITERAL_AGGREGATE_ROWS)
        with (
            patch.object(builder, "_r11_publish_preconstructed") as evidence_publish,
            patch.object(builder, "publish_json_no_replace") as legacy_publish,
        ):
            results = builder.evaluate_aggregate_gates(measurements)
        evidence_publish.assert_not_called()
        legacy_publish.assert_not_called()
        self.assertEqual(tuple(item["gate"] for item in results), expected_ids)
        self.assertTrue(all(item["actual"] == item["threshold"] for item in results))
        for result, literal in zip(
            results,
            R11_LITERAL_AGGREGATE_ROWS,
            strict=True,
        ):
            _trigger, gate_id, members, metric, threshold = literal
            self.assertEqual(
                (
                    result["gate"], tuple(result["members"]), result["field"],
                    result["operator"], result["threshold"],
                ),
                (gate_id, members, metric, "<=", threshold),
            )
        self.assertEqual(
            sum(
                r4_authority(target)["bytes"]
                for target in (
                    "StreamArtistBindingTransitionArchiveVerifierV1Skeleton",
                    "StreamArtistBindingProposalArchiveVerifierV1Skeleton",
                    "StreamArtistCollaboratorArchiveVerifierV1Skeleton",
                )
            ),
            576,
        )
        for failing_index, expected_id in enumerate(expected_ids):
            observed: list[str] = []
            calls = 0

            def comparator(actual: int, threshold: int) -> bool:
                nonlocal calls
                result = calls != failing_index and actual <= threshold
                calls += 1
                return result

            with self.subTest(subgate=expected_id):
                with (
                    patch.object(builder, "_r11_publish_preconstructed") as evidence_publish,
                    patch.object(builder, "publish_json_no_replace") as legacy_publish,
                ):
                    injected_failure = assert_r4_failure(
                        self,
                        expected_id,
                        builder.evaluate_aggregate_gates,
                        measurements,
                        comparator=comparator,
                        observer=lambda gate_id, _operands: observed.append(gate_id),
                    )
                _trigger, gate_id, members, metric, threshold = (
                    R11_LITERAL_AGGREGATE_ROWS[failing_index]
                )
                injected_values = [
                    measurements[member][metric] for member in members
                ]
                self.assertEqual(
                    injected_failure.operands,
                    {
                        "gate": gate_id,
                        "members": list(members),
                        "field": metric,
                        "operands": injected_values,
                        "actual": sum(injected_values),
                        "operator": "<=",
                        "threshold": threshold,
                    },
                )
                self.assertEqual(observed, list(expected_ids[:failing_index + 1]))
                self.assertEqual(calls, failing_index + 1)
                evidence_publish.assert_not_called()
                legacy_publish.assert_not_called()

        literal_calls = r11_literal_calls()
        literal_events = [f"event-{index:02d}" for index in range(37)]
        literal_checkpoints = r11_literal_checkpoints()
        self.assertEqual(
            (
                len(literal_calls), len(literal_events),
                len(literal_checkpoints),
            ),
            (18, 37, 37),
        )

        def wrong_aggregate_major(value: Any) -> Any:
            if type(value) is bool:
                return 0
            if type(value) is int:
                return "0"
            if isinstance(value, str):
                return {}
            if isinstance(value, list):
                return {}
            raise AssertionError("unlisted aggregate operand major type")

        staged_first_red = {
            "phase": "staged_validation",
            "code": "STAGED_VALIDATION_FAILED",
            "call_ordinal": None,
            "group_index": None,
            "group_string": None,
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {
                "cause_type": "TraversalError",
                "message_sha256": r11_hash("aggregate-staged"),
            },
        }
        successful_envelope = {
            "schema": R11_LITERAL_TERMINAL_SCHEMA,
            "invocation_id": r11_hash("aggregate-success-invocation"),
            "status": "NO_GO",
            "first_red": staged_first_red,
            "event_count": len(literal_events),
            "event_head_sha256": r11_hash(literal_events[-1]),
            "calls": literal_calls,
            "checkpoints": literal_checkpoints,
            "results": r11_literal_complete_results(installed=False),
            "no_retry": True,
        }
        builder.r11_validate_builder_terminal(successful_envelope)

        aggregate_case_ids: list[str] = []
        aggregate_rejection_ids: list[str] = []
        aggregate_publication_ids: list[str] = []
        aggregate_omission_ids: list[str] = []
        with tempfile.TemporaryDirectory(
            prefix="r11-inherited-aggregate-", dir=REPO_ROOT.parent,
        ) as aggregate_temp:
            for position, literal in enumerate(
                R11_LITERAL_AGGREGATE_ROWS, start=1,
            ):
                trigger, code, members, metric, threshold = literal
                trigger_state = R11_LITERAL_TARGET_STATE_ROWS[trigger - 1]
                context = {
                    "phase": "aggregate",
                    "code": code,
                    "call_ordinal": None,
                    "group_index": int(trigger_state[4]),
                    "group_string": trigger_state[4] + "::" + trigger_state[2],
                    "semantic_id": trigger_state[0],
                    "target": trigger_state[1],
                    "step_ordinal": None,
                    "step_id": None,
                }
                named_results = (
                    r11_literal_reachable_aggregate_failure_results(position)
                    if position in (9, 10)
                    else r11_literal_aggregate_failure_results(position)
                )
                named_measurements = {
                    artifact["semantic_id"]: artifact
                    for artifact in named_results["artifacts"]
                }
                named_values = [
                    named_measurements[member][metric] for member in members
                ]
                named_first_red = {
                    **context,
                    "operands": {
                        "aggregate_id": code,
                        "member_semantic_ids": list(members),
                        "metric": metric,
                        "values": named_values,
                        "actual": sum(named_values),
                        "operator": "<=",
                        "threshold": threshold,
                    },
                }
                named_case_id = f"AGG_{position:02d}_{code}"
                aggregate_case_ids.append(named_case_id)
                named_envelope = {
                    "schema": R11_LITERAL_TERMINAL_SCHEMA,
                    "invocation_id": r11_hash("aggregate-invocation"),
                    "status": "NO_GO",
                    "first_red": named_first_red,
                    "event_count": len(literal_events),
                    "event_head_sha256": r11_hash(literal_events[-1]),
                    "calls": literal_calls,
                    "checkpoints": literal_checkpoints,
                    "results": named_results,
                    "no_retry": True,
                }
                if position in (9, 10):
                    named_directory = Path(aggregate_temp) / named_case_id
                    named_directory.mkdir()
                    named_context = r11_independent_terminal_context(
                        named_directory,
                        first_red=named_first_red,
                        results=named_results,
                    )
                    named_frozen_terminal = copy.deepcopy(
                        named_context["terminal"],
                    )
                    named_frozen_raw = bytes(named_context["raw"])
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(named_frozen_terminal),
                        named_frozen_raw,
                    )
                    actual_aggregate_failure = assert_r4_failure(
                        self,
                        code,
                        builder.evaluate_aggregate_gates,
                        named_measurements,
                    )
                    self.assertEqual(
                        actual_aggregate_failure.operands,
                        {
                            "gate": code,
                            "members": list(members),
                            "field": metric,
                            "operands": named_values,
                            "actual": sum(named_values),
                            "operator": "<=",
                            "threshold": threshold,
                        },
                    )
                    self.assertEqual(
                        named_context["terminal"], named_frozen_terminal,
                    )
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(named_context["terminal"]),
                        named_frozen_raw,
                    )
                    named_envelope, named_raw = (
                        r11_publish_literal_terminal_with_disk_parity(
                            self,
                            named_context,
                            named_frozen_terminal,
                            named_frozen_raw,
                        )
                    )
                    self.assertEqual(named_envelope, named_frozen_terminal)
                    self.assertEqual(named_raw, named_frozen_raw)
                    self.assertEqual(
                        named_raw,
                        (
                            json.dumps(
                                named_envelope,
                                sort_keys=True,
                                separators=(",", ":"),
                                ensure_ascii=False,
                                allow_nan=False,
                            )
                            + "\n"
                        ).encode("utf-8", "strict"),
                    )
                    aggregate_publication_ids.append(named_case_id)
                else:
                    with (
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as named_rejection_publication,
                        patch.object(
                            builder, "publish_json_no_replace",
                        ) as named_rejection_legacy,
                        self.assertRaises(
                            builder.EvidenceFailure,
                        ) as named_rejection,
                    ):
                        builder.r11_validate_builder_terminal(named_envelope)
                    self.assertEqual(
                        (
                            named_rejection.exception.code,
                            named_rejection.exception.operands,
                        ),
                        ("AGGREGATE_RESULT_SCHEMA", {}),
                    )
                    named_rejection_publication.assert_not_called()
                    named_rejection_legacy.assert_not_called()
                    aggregate_rejection_ids.append(named_case_id)
                for operand_name in tuple(named_first_red["operands"]):
                    for mutation_name in ("missing", "null", "wrong", "extra"):
                        named_mutation = copy.deepcopy(named_envelope)
                        named_operands = named_mutation["first_red"]["operands"]
                        if mutation_name == "missing":
                            named_operands.pop(operand_name)
                        elif mutation_name == "null":
                            named_operands[operand_name] = None
                        elif mutation_name == "wrong":
                            named_operands[operand_name] = wrong_aggregate_major(
                                named_first_red["operands"][operand_name],
                            )
                        else:
                            named_operands["_extra"] = None
                        with (
                            self.subTest(
                                aggregate=code,
                                operand=operand_name,
                                mutation=mutation_name,
                            ),
                            patch.object(
                                builder, "_r11_publish_preconstructed",
                            ) as named_mutation_publication,
                            patch.object(
                                builder, "publish_json_no_replace",
                            ) as named_mutation_legacy,
                            self.assertRaises(
                                (builder.EvidenceFailure, TypeError, ValueError),
                            ),
                        ):
                            builder.r11_validate_builder_terminal(named_mutation)
                        named_mutation_publication.assert_not_called()
                        named_mutation_legacy.assert_not_called()

                for missing_index, missing_member in enumerate(members):
                    aggregate_omission_ids.append(
                        f"AGG_{position:02d}_OMIT_{missing_index + 1:02d}_"
                        f"{missing_member}"
                    )
                    omitted_measurements = copy.deepcopy(measurements)
                    omitted_measurements.pop(missing_member)
                    omitted_observed: list[str] = []
                    with (
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as omitted_publication,
                        patch.object(
                            builder, "publish_json_no_replace",
                        ) as omitted_legacy,
                    ):
                        omitted_failure = assert_r4_failure(
                            self,
                            "AGGREGATE_MEMBER_MISSING",
                            builder.evaluate_aggregate_gates,
                            omitted_measurements,
                            observer=lambda gate_id, _operands: (
                                omitted_observed.append(gate_id)
                            ),
                        )
                    self.assertEqual(
                        omitted_failure.operands,
                        {"missing": [missing_member]},
                    )
                    earliest_missing_trigger = next(
                        candidate_trigger
                        for candidate_trigger, _candidate_gate,
                        candidate_members, _candidate_metric,
                        _candidate_threshold in R11_LITERAL_AGGREGATE_ROWS
                        if missing_member in candidate_members
                    )
                    expected_prior_gates = [
                        candidate_gate
                        for candidate_trigger, candidate_gate,
                        _candidate_members, _candidate_metric,
                        _candidate_threshold in R11_LITERAL_AGGREGATE_ROWS
                        if candidate_trigger < earliest_missing_trigger
                    ]
                    self.assertEqual(
                        omitted_observed, expected_prior_gates,
                    )
                    omitted_publication.assert_not_called()
                    omitted_legacy.assert_not_called()
                    missing_first_red = {
                        **context,
                        "code": "AGGREGATE_MEMBER_MISSING",
                        "operands": {
                            "aggregate_id": code,
                            "member_semantic_id": missing_member,
                            "metric": metric,
                        },
                    }
                    missing_results = r11_literal_aggregate_failure_results(
                        position,
                    )
                    missing_case_id = (
                        f"AGG_{position:02d}_MISSING_{missing_index + 1:02d}_"
                        f"{missing_member}"
                    )
                    aggregate_case_ids.append(missing_case_id)
                    aggregate_rejection_ids.append(missing_case_id)
                    missing_envelope = {
                        **named_envelope,
                        "first_red": missing_first_red,
                        "results": missing_results,
                    }
                    with (
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as missing_rejection_publication,
                        patch.object(
                            builder, "publish_json_no_replace",
                        ) as missing_rejection_legacy,
                        self.assertRaises(
                            builder.EvidenceFailure,
                        ) as missing_rejection,
                    ):
                        builder.r11_validate_builder_terminal(missing_envelope)
                    self.assertEqual(
                        (
                            missing_rejection.exception.code,
                            missing_rejection.exception.operands,
                        ),
                        ("AGGREGATE_RESULT_SCHEMA", {}),
                    )
                    missing_rejection_publication.assert_not_called()
                    missing_rejection_legacy.assert_not_called()
                    for operand_name in tuple(missing_first_red["operands"]):
                        for mutation_name in ("missing", "null", "wrong", "extra"):
                            missing_mutation = copy.deepcopy(missing_envelope)
                            missing_operands = missing_mutation["first_red"]["operands"]
                            if mutation_name == "missing":
                                missing_operands.pop(operand_name)
                            elif mutation_name == "null":
                                missing_operands[operand_name] = None
                            elif mutation_name == "wrong":
                                missing_operands[operand_name] = wrong_aggregate_major(
                                    missing_first_red["operands"][operand_name],
                                )
                            else:
                                missing_operands["_extra"] = None
                            with (
                                self.subTest(
                                    aggregate=code,
                                    missing_member=missing_member,
                                    operand=operand_name,
                                    mutation=mutation_name,
                                ),
                                patch.object(
                                    builder, "_r11_publish_preconstructed",
                                ) as missing_mutation_publication,
                                patch.object(
                                    builder, "publish_json_no_replace",
                                ) as missing_mutation_legacy,
                                self.assertRaises(
                                    (builder.EvidenceFailure, TypeError, ValueError),
                                ),
                            ):
                                builder.r11_validate_builder_terminal(missing_mutation)
                            missing_mutation_publication.assert_not_called()
                            missing_mutation_legacy.assert_not_called()

            for row_index, baseline_row in enumerate(
                successful_envelope["results"]["aggregates"],
            ):
                for field in tuple(baseline_row):
                    for mutation_name in ("missing", "null", "wrong", "extra"):
                        mutation = copy.deepcopy(successful_envelope)
                        row = mutation["results"]["aggregates"][row_index]
                        if mutation_name == "missing":
                            row.pop(field)
                        elif mutation_name == "null":
                            row[field] = None
                        elif mutation_name == "wrong":
                            row[field] = wrong_aggregate_major(baseline_row[field])
                        else:
                            row["_extra"] = None
                        with (
                            self.subTest(
                                aggregate=baseline_row["gate"],
                                field=field,
                                mutation=mutation_name,
                            ),
                            patch.object(
                                builder, "_r11_publish_preconstructed",
                            ) as row_mutation_publication,
                            patch.object(
                                builder, "publish_json_no_replace",
                            ) as row_mutation_legacy,
                            self.assertRaises(
                                (builder.EvidenceFailure, TypeError, ValueError),
                            ),
                        ):
                            builder.r11_validate_builder_terminal(mutation)
                        row_mutation_publication.assert_not_called()
                        row_mutation_legacy.assert_not_called()
            for mutation_name in ("missing-row", "duplicate-row", "reversed"):
                mutation = copy.deepcopy(successful_envelope)
                rows = mutation["results"]["aggregates"]
                if mutation_name == "missing-row":
                    rows.pop(0)
                elif mutation_name == "duplicate-row":
                    rows.insert(1, copy.deepcopy(rows[0]))
                else:
                    rows.reverse()
                with (
                    self.subTest(aggregate_array=mutation_name),
                    patch.object(
                        builder, "_r11_publish_preconstructed",
                    ) as array_mutation_publication,
                    patch.object(
                        builder, "publish_json_no_replace",
                    ) as array_mutation_legacy,
                    self.assertRaises(builder.EvidenceFailure),
                ):
                    builder.r11_validate_builder_terminal(mutation)
                array_mutation_publication.assert_not_called()
                array_mutation_legacy.assert_not_called()
        self.assertEqual(len(aggregate_case_ids), 62)
        self.assertEqual(len(set(aggregate_case_ids)), 62)
        self.assertEqual(len(aggregate_publication_ids), 2)
        self.assertEqual(len(set(aggregate_publication_ids)), 2)
        self.assertEqual(len(aggregate_rejection_ids), 60)
        self.assertEqual(len(set(aggregate_rejection_ids)), 60)
        self.assertEqual(len(aggregate_omission_ids), 51)
        self.assertEqual(len(set(aggregate_omission_ids)), 51)

    def test_34_successor_source_introduces_no_prohibited_execution_surface(
        self,
    ) -> None:
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        new_helpers = "\n".join(
            inspect.getsource(value)
            for value in (
                builder.R4ExecutionJournal,
                builder.recover_interrupted,
                builder.r4_install_output_no_replace,
                builder.r4_publish_json_no_replace,
                builder._prepare_evidence_run,
                builder._build_release_output_evidence,
                builder.validate_ordered_bytecode,
                builder.evaluate_aggregate_gates,
                builder.forge_command,
                builder.normalized_forge_argv,
                builder.run_forge,
                builder.read_forge_version,
            )
        )
        for prohibited in (
            "CreateJobObject",
            "ETW",
            "firewall",
            "socket.",
            "requests.",
            "urllib.",
            "shell=True",
            "timeout=",
            "os.replace(",
        ):
            self.assertNotIn(prohibited, new_helpers)
        subprocess_members = set(re.findall(r"subprocess\.([A-Za-z_]+)", source))
        self.assertLessEqual(subprocess_members, {"CompletedProcess", "run"})
        self.assertNotIn("probe_state", source.casefold())
        self.assertNotIn("append_journal", source.casefold())
        r4_closure_source = "\n".join(
            inspect.getsource(value)
            for value in (
                builder._r4_kernel32,
                builder._r4_winerror,
                builder._r4_open_windows_handle,
                builder._r4_identity_from_handle,
                builder._r4_close_windows_handle,
                builder._r4_has_alternate_data_stream,
                builder._r4_path_is_link_or_reparse,
                builder._r4_reject_reparse_components_absolute,
                builder.r4_validate_absolute_ordinary_path,
                builder.r4_windows_path_identity,
                builder._r4_read_required_bytes,
                builder._r4_sha256_bytes,
                builder.r4_windows_file_receipt,
                builder.R4WindowsDirectoryLock,
                builder._r4_validate_evidence_json_value,
                builder._r4_reject_non_unicode_scalars,
                builder.r4_canonical_evidence_bytes,
                builder._r4_windows_move_no_replace,
                builder.r4_publish_json_no_replace,
                builder.r4_install_output_no_replace,
                builder._r4_captured_subprocess,
                builder._r4_sanitized_forge_environment,
                builder.R4ExecutionJournal,
            )
        )
        for late_resolved_name in (
            "validate_absolute_ordinary_path",
            "windows_path_identity",
            "windows_file_receipt",
            "WindowsDirectoryLock",
            "canonical_evidence_bytes",
            "publish_json_no_replace",
            "install_output_no_replace",
            "_captured_subprocess",
            "_kernel32",
            "_winerror",
            "_open_windows_handle",
            "_identity_from_handle",
            "_close_windows_handle",
            "path_is_link_or_reparse",
            "read_required_bytes",
            "sha256_bytes",
            "reject_non_unicode_scalars",
            "_windows_move_no_replace",
            "sanitized_forge_environment",
            "run_forge",
        ):
            self.assertIsNone(
                re.search(
                    rf"(?<![A-Za-z0-9_]){re.escape(late_resolved_name)}\(",
                    r4_closure_source,
                ),
                late_resolved_name,
            )
        self.assertIs(builder.R4ExecutionJournal.default_runner, builder.run_forge)
        self.assertIsNot(
            builder._R4_ACTIVE_EVIDENCE_LOCKS,
            builder._ACTIVE_EVIDENCE_LOCKS,
        )


def r11_token_snapshot(entries: list[tuple[int, int, int]]) -> bytes:
    return struct.pack("<I", len(entries)) + b"".join(
        struct.pack("<IiI", low, high, attributes)
        for low, high, attributes in entries
    )


class R11QueryFake:
    def __init__(self, snapshots: list[bytes], *, requested: int | None = None) -> None:
        self.snapshots = snapshots
        self.snapshot_index = 0
        self.requested = requested
        self.calls: list[tuple[Any, ...]] = []

    def GetTokenInformation(self, *args: Any) -> bool:
        self.calls.append(args)
        token, info_class, buffer, length, returned_pointer = args
        del token
        if info_class != TokenPrivileges:
            raise AssertionError("wrong token information class")
        snapshot = self.snapshots[self.snapshot_index]
        if buffer is None:
            requested = len(snapshot) if self.requested is None else self.requested
            ctypes.cast(
                returned_pointer, ctypes.POINTER(wintypes.DWORD),
            ).contents.value = requested
            ctypes.set_last_error(ERROR_INSUFFICIENT_BUFFER)
            return False
        if length != len(snapshot):
            raise AssertionError("data call did not use authenticated required length")
        ctypes.memmove(buffer, snapshot, len(snapshot))
        ctypes.cast(
            returned_pointer, ctypes.POINTER(wintypes.DWORD),
        ).contents.value = len(snapshot)
        ctypes.set_last_error(0x7FFF)
        self.snapshot_index += 1
        return True


class R11PrivilegeFake(R11QueryFake):
    def __init__(
        self,
        snapshots: list[bytes],
        *,
        previous_attributes: int = 0,
        malformed_previous: str | None = None,
    ) -> None:
        super().__init__(snapshots)
        self.previous_attributes = previous_attributes
        self.malformed_previous = malformed_previous
        self.adjust_calls: list[tuple[Any, ...]] = []
        self.open_calls = 0
        self.lookup_calls = 0

    def OpenProcessToken(self, process: int, access: int, output: Any) -> bool:
        self.open_calls += 1
        if process != CURRENT_PROCESS_PSEUDOHANDLE or access != (
            TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES
        ):
            raise AssertionError("primary-token open contract mismatch")
        ctypes.cast(output, ctypes.POINTER(wintypes.HANDLE)).contents.value = 0x1234
        return True

    def LookupPrivilegeValueW(self, system: Any, name: str, output: Any) -> bool:
        self.lookup_calls += 1
        if system is not None or name != PRIVILEGE_NAME:
            raise AssertionError("privilege lookup contract mismatch")
        luid = ctypes.cast(output, ctypes.POINTER(LUID)).contents
        luid.LowPart = 0x11223344
        luid.HighPart = -7
        return True

    def AdjustTokenPrivileges(self, *args: Any) -> bool:
        self.adjust_calls.append(args)
        token, disable_all, new_state, buffer_length, previous, returned = args
        if int(getattr(token, "value", token)) != 0x1234 or bool(disable_all):
            raise AssertionError("adjustment token/disable-all contract mismatch")
        if buffer_length:
            value = ctypes.cast(
                previous, ctypes.POINTER(TOKEN_PRIVILEGES_ONE),
            ).contents
            value.PrivilegeCount = 1
            value.Privileges[0].Luid.LowPart = 0x11223344
            value.Privileges[0].Luid.HighPart = -7
            value.Privileges[0].Attributes = self.previous_attributes
            length = ctypes.cast(
                returned, ctypes.POINTER(wintypes.DWORD),
            ).contents
            length.value = ctypes.sizeof(TOKEN_PRIVILEGES_ONE)
            if self.malformed_previous == "length":
                length.value -= 1
            elif self.malformed_previous == "count":
                value.PrivilegeCount = 2
            elif self.malformed_previous == "luid":
                value.Privileges[0].Luid.LowPart ^= 1
            elif self.malformed_previous == "attributes":
                value.Privileges[0].Attributes ^= 4
        ctypes.set_last_error(ERROR_SUCCESS)
        return True


class R11KernelFake:
    def __init__(self) -> None:
        self.close_calls: list[Any] = []
        self.device_calls: list[tuple[Any, ...]] = []

    def CloseHandle(self, handle: Any) -> bool:
        self.close_calls.append(handle)
        return True

    def DeviceIoControl(self, *args: Any) -> bool:
        self.device_calls.append(args)
        return True


class R11ForgeFake:
    VERSION = (
        "forge Version: 1.7.1\n"
        "Commit SHA: 0000000000000000000000000000000000000000\n"
        "Build Timestamp: fixture\n"
        "Build Profile: release"
    )

    def __init__(self) -> None:
        self.calls: list[list[str]] = []

    @property
    def portable_version(self) -> str:
        return self.VERSION.replace(
            "Build Timestamp: fixture", builder.PORTABLE_FORGE_BUILD_TIMESTAMP,
        )

    def __call__(self, command: list[str], cwd: Path) -> builder.CommandResult:
        self.calls.append(list(command))
        if command[1:] == ["--version"]:
            return builder.CommandResult(True, 0, self.VERSION.encode("utf-8"), b"")
        source = command[2]
        group = next(item for item in builder.R4_GROUPS if item["source"] == source)
        source_contents = {
            path: (cwd / path).read_bytes().decode("utf-8")
            for path in group["sources"]
        }
        source_hashes = {
            path: builder.keccak256_hex(content.encode("utf-8"))
            for path, content in source_contents.items()
        }
        out_dir = Path(command[command.index("--out") + 1])
        authorities = [
            authority for authority in builder.R4_TARGET_AUTHORITIES
            if authority["source"] == source
        ]
        for authority in authorities:
            value = artifact(source, authority["target"], source_hashes)
            value.update(r4_bytecode_artifact(authority))
            write_json(
                out_dir / Path(source).name / f"{authority['target']}.json",
                value,
            )
        build_info_dir = Path(command[command.index("--build-info-path") + 1])
        root = cwd.resolve().as_posix()
        write_json(
            build_info_dir / "build-info.json",
            {
                "id": "r11-fixture",
                "input": {
                    "language": "Solidity",
                    "sources": {
                        path: {"content": content}
                        for path, content in source_contents.items()
                    },
                    "settings": {
                        "evmVersion": builder.EVM_VERSION,
                        "metadata": {"bytecodeHash": "none", "appendCBOR": False},
                        "optimizer": {"enabled": True, "runs": builder.OPTIMIZER_RUNS},
                        "outputSelection": {"*": {"*": ["abi"]}},
                        "viaIR": True,
                    },
                    "allowPaths": [root, (cwd.resolve() / "lib").as_posix()],
                    "basePath": root,
                    "includePaths": [root],
                },
            },
        )
        return builder.CommandResult(True, 0, b"", b"")


def r11_copied_record(long_name: str, alternate_name: str, attributes: int) -> dict[str, Any]:
    def raw_name(value: str, units: int) -> bytes:
        encoded = value.encode("utf-16-le", errors="strict") + b"\x00\x00"
        return encoded + bytes(units * 2 - len(encoded))

    raw_long = raw_name(long_name, 260)
    raw_alt = raw_name(alternate_name, 14)
    key = raw_long + raw_alt + attributes.to_bytes(4, "little", signed=False)
    return {
        "raw_long": raw_long,
        "raw_alt": raw_alt,
        "attributes": attributes,
        "record_key": key,
        "long_name": long_name,
        "alternate_name": alternate_name,
        "raw_ordinal": 0,
    }


def r11_literal_record_names(record: dict[str, Any]) -> tuple[str, str]:
    def decode(raw: bytes, units: int, *, alternate: bool) -> str:
        if type(raw) is not bytes or len(raw) != units * 2:
            raise ValueError("literal WCHAR array width differs")
        terminator = next(
            (index for index in range(units) if raw[index * 2:index * 2 + 2] == b"\x00\x00"),
            None,
        )
        if terminator is None:
            raise ValueError("literal WCHAR array is unterminated")
        value = raw[:terminator * 2].decode("utf-16-le", errors="strict")
        if not alternate and not value:
            raise ValueError("literal long name is empty")
        if value in (".", "..") or any(char in value for char in "\x00/\\:*?"):
            raise ValueError("literal record name is not a component")
        if value.endswith((".", " ")):
            raise ValueError("literal record component ending differs")
        return value

    return (
        decode(record["raw_long"], 260, alternate=False),
        decode(record["raw_alt"], 14, alternate=True),
    )


def r11_literal_copied_record_multiset_sha256(
    records: list[dict[str, Any]],
) -> str:
    entries = [
        {
            "raw_long": record["raw_long"].hex(),
            "raw_alt": record["raw_alt"].hex(),
            "attributes": record["attributes"],
            "record_key": record["record_key"].hex(),
            "raw_ordinal": record["raw_ordinal"],
            "names_present": "long_name" in record or "alternate_name" in record,
            "long_name": record.get("long_name"),
            "alternate_name": record.get("alternate_name"),
        }
        for record in records
    ]
    entries.sort(key=lambda item: (
        item["record_key"], item["raw_long"], item["raw_alt"],
        item["attributes"], item["raw_ordinal"], item["names_present"],
        "" if item["long_name"] is None else item["long_name"],
        "" if item["alternate_name"] is None else item["alternate_name"],
    ))
    raw = (
        json.dumps(
            entries,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        )
        + "\n"
    ).encode("utf-8", "strict")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def r11_test_identity(file_index: str = "0000000000000001") -> dict[str, str]:
    return {"volume_serial": "1234ABCD", "file_index": file_index}


def r11_literal_diagnostic_operands(code: str) -> dict[str, Any]:
    operation_by_code = {
        "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": "lexical_validate",
        "PATH_DEVICE_NAMESPACE": "namespace_validate",
        "PATH_UNSUPPORTED_DRIVE_TYPE": "drive_type",
        "TRAVERSAL_ROOT_OPEN": "open_root",
        "TRAVERSAL_ROOT_REPARSE": "validate_root",
        "TRAVERSAL_ROOT_NOT_DIRECTORY": "validate_root",
        "TRAVERSAL_ROOT_ENUM_OPEN": "enum_root_open",
        "TRAVERSAL_ROOT_ENUM_NEXT": "enum_root_next",
        "TRAVERSAL_ROOT_ENUM_CLOSE": "enum_root_close",
        "TRAVERSAL_ROOT_ENTRY_NAME": "validate_root_entry",
        "TRAVERSAL_ROOT_ENTRY_COLLISION": "validate_root_entry",
        "TRAVERSAL_ROOT_IDENTITY_CHANGED": "revalidate_root",
        "TRAVERSAL_ROOT_HANDLE_CLOSE": "close_root",
        "TRAVERSAL_ENUM_OPEN": "enum_child_open",
        "TRAVERSAL_ENUM_NEXT": "enum_child_next",
        "TRAVERSAL_ENUM_CLOSE": "enum_child_close",
        "TRAVERSAL_ENTRY_NAME": "validate_inventory_entry",
        "TRAVERSAL_ENTRY_COLLISION": "validate_inventory_entry",
        "TRAVERSAL_COMPONENT_MISSING": "resolve_component",
        "TRAVERSAL_COMPONENT_CASE_MISMATCH": "resolve_component",
        "TRAVERSAL_COMPONENT_SHORT_ALIAS": "resolve_component",
        "TRAVERSAL_ENTRY_REPARSE": "validate_selected_entry",
        "TRAVERSAL_CHILD_OPEN": "open_child",
        "TRAVERSAL_CHILD_REPARSE": "validate_open_child",
        "TRAVERSAL_CHILD_TYPE_CHANGED": "validate_open_child",
        "TRAVERSAL_IDENTITY_CHANGED": "revalidate_child",
        "TRAVERSAL_READ": "read_child",
        "TRAVERSAL_HANDLE_CLOSE": "close_child",
    }
    if code not in operation_by_code:
        raise AssertionError("unlisted literal diagnostic")
    root = code.startswith("TRAVERSAL_ROOT_")
    record = code in R11_LITERAL_RECORD_PROOF_CODES
    component = code.startswith("TRAVERSAL_COMPONENT_")
    component_index = (
        0 if record and not component else
        3 if code.startswith("TRAVERSAL_") and not root else
        None
    )
    path_token = (
        None if root or not code.startswith("TRAVERSAL_") else
        "retained/requested-missing"
        if code == "TRAVERSAL_COMPONENT_MISSING" else
        "retained/requested-component" if component else
        "retained" if record else
        "retained/leaf"
    )
    winerror = (
        5
        if code in {
            "TRAVERSAL_ROOT_OPEN", "TRAVERSAL_ROOT_ENUM_OPEN",
            "TRAVERSAL_ROOT_ENUM_NEXT", "TRAVERSAL_ROOT_ENUM_CLOSE",
            "TRAVERSAL_ROOT_HANDLE_CLOSE", "TRAVERSAL_ENUM_OPEN",
            "TRAVERSAL_ENUM_NEXT", "TRAVERSAL_ENUM_CLOSE",
            "TRAVERSAL_CHILD_OPEN", "TRAVERSAL_READ",
            "TRAVERSAL_HANDLE_CLOSE",
        }
        else None
    )
    expected_attributes = (
        3 if code == "PATH_UNSUPPORTED_DRIVE_TYPE" else
        0x10 if code in {
            "TRAVERSAL_ROOT_NOT_DIRECTORY",
            "TRAVERSAL_ROOT_IDENTITY_CHANGED",
        } else
        0 if code in {
            "TRAVERSAL_CHILD_OPEN", "TRAVERSAL_CHILD_TYPE_CHANGED",
            "TRAVERSAL_IDENTITY_CHANGED",
        } else None
    )
    actual_attributes = (
        0x21 if record and code != "TRAVERSAL_COMPONENT_MISSING" else
        0 if code == "PATH_UNSUPPORTED_DRIVE_TYPE" else
        0x400 if code in {
            "TRAVERSAL_ROOT_REPARSE", "TRAVERSAL_ENTRY_REPARSE",
            "TRAVERSAL_CHILD_REPARSE",
        } else
        0x10 if code == "TRAVERSAL_CHILD_TYPE_CHANGED" else
        0 if code in {
            "TRAVERSAL_ROOT_NOT_DIRECTORY",
            "TRAVERSAL_ROOT_IDENTITY_CHANGED",
            "TRAVERSAL_IDENTITY_CHANGED",
        } else None
    )
    identity_codes = {
        "TRAVERSAL_ROOT_REPARSE", "TRAVERSAL_ROOT_NOT_DIRECTORY",
        "TRAVERSAL_ROOT_ENUM_OPEN", "TRAVERSAL_ROOT_ENUM_NEXT",
        "TRAVERSAL_ROOT_ENUM_CLOSE", "TRAVERSAL_ROOT_ENTRY_NAME",
        "TRAVERSAL_ROOT_ENTRY_COLLISION",
        "TRAVERSAL_ROOT_IDENTITY_CHANGED", "TRAVERSAL_ROOT_HANDLE_CLOSE",
        "TRAVERSAL_ENUM_OPEN", "TRAVERSAL_ENUM_NEXT",
        "TRAVERSAL_ENUM_CLOSE", "TRAVERSAL_ENTRY_NAME",
        "TRAVERSAL_ENTRY_COLLISION", "TRAVERSAL_COMPONENT_MISSING",
        "TRAVERSAL_COMPONENT_CASE_MISMATCH",
        "TRAVERSAL_COMPONENT_SHORT_ALIAS", "TRAVERSAL_ENTRY_REPARSE",
        "TRAVERSAL_CHILD_OPEN", "TRAVERSAL_CHILD_REPARSE",
        "TRAVERSAL_CHILD_TYPE_CHANGED", "TRAVERSAL_IDENTITY_CHANGED",
        "TRAVERSAL_READ", "TRAVERSAL_HANDLE_CLOSE",
    }
    return {
        "operation": operation_by_code[code],
        "component_index": component_index,
        "path_token": path_token,
        "winerror": winerror,
        "expected_attributes": expected_attributes,
        "actual_attributes": actual_attributes,
        "identity_before": (
            {"volume_serial": "1234ABCD", "file_index": "0000000000000001"}
            if code in identity_codes else None
        ),
        "identity_after": (
            {"volume_serial": "1234ABCD", "file_index": "0000000000000002"}
            if code in {
                "TRAVERSAL_ROOT_IDENTITY_CHANGED",
                "TRAVERSAL_IDENTITY_CHANGED",
            } else None
        ),
    }


def r11_complete_diagnostic(code: str) -> builder.R11TraversalDiagnostic:
    if code in R11_LITERAL_RECORD_PROOF_CODES:
        identity = r11_test_identity()

        def ordered(records: list[dict[str, Any]]) -> list[dict[str, Any]]:
            for record in records:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in records
                )
            return records

        def freeze(
            record: dict[str, Any],
        ) -> tuple[bytes, bytes, int, bytes, int, bool, str | None, str | None]:
            names_present = (
                "long_name" in record or "alternate_name" in record
            )
            return (
                record["raw_long"],
                record["raw_alt"],
                record["attributes"],
                record["record_key"],
                record["raw_ordinal"],
                names_present,
                record.get("long_name"),
                record.get("alternate_name"),
            )

        def literal_diagnostic(
            *,
            operation: str,
            records: list[dict[str, Any]],
            winner: dict[str, Any] | None,
            root: bool,
            inventory: bool,
            requested_depth: int | None,
            requested_token: str | None,
            requested_component: str | None = None,
            observed_winner_token: str | None = None,
        ) -> builder.R11TraversalDiagnostic:
            proof = builder.R11CopiedRecordProof(
                code=code,
                operation=operation,
                records=tuple(freeze(record) for record in records),
                records_sha256=r11_literal_copied_record_multiset_sha256(
                    records,
                ),
                winner=None if winner is None else freeze(winner),
                root=root,
                inventory=inventory,
                requested_depth=requested_depth,
                requested_token=requested_token,
                parent_token="retained",
                parent_identity=("1234ABCD", "0000000000000001"),
                requested_component=requested_component,
                observed_winner_token=observed_winner_token,
            )
            component_index = (
                0
                if root
                else requested_depth
                if not inventory
                else 0 if winner is None else winner["raw_ordinal"]
            )
            path_token = (
                None if root else "retained" if inventory else requested_token
            )
            return builder.R11TraversalDiagnostic(
                code,
                operation,
                component_index=component_index,
                path_token=path_token,
                actual_attributes=(
                    None if winner is None else winner["attributes"]
                ),
                identity_before=identity,
                record_proof=proof,
            )

        if code in ("TRAVERSAL_ROOT_ENTRY_NAME", "TRAVERSAL_ENTRY_NAME"):
            malformed = r11_copied_record("Alpha", "", 0x21)
            malformed["raw_long"] = b"A\x00" * 260
            malformed["record_key"] = (
                malformed["raw_long"]
                + malformed["raw_alt"]
                + malformed["attributes"].to_bytes(4, "little")
            )
            malformed.pop("long_name")
            malformed.pop("alternate_name")
            records = ordered([malformed, r11_copied_record("Zulu", "", 0x41)])
            root = code.startswith("TRAVERSAL_ROOT_")
            return literal_diagnostic(
                operation=(
                    "validate_root_entry" if root
                    else "validate_inventory_entry"
                ),
                records=records,
                winner=malformed,
                root=root,
                inventory=True,
                requested_depth=None,
                requested_token=None if root else "retained",
            )
        if code in (
            "TRAVERSAL_ROOT_ENTRY_COLLISION",
            "TRAVERSAL_ENTRY_COLLISION",
        ):
            records = ordered([
                r11_copied_record("Alpha", "", 0x21),
                r11_copied_record("alpha", "", 0x41),
            ])
            winner = min(records, key=lambda record: record["record_key"])
            root = code.startswith("TRAVERSAL_ROOT_")
            return literal_diagnostic(
                operation=(
                    "validate_root_entry" if root
                    else "validate_inventory_entry"
                ),
                records=records,
                winner=winner,
                root=root,
                inventory=True,
                requested_depth=None,
                requested_token=None if root else "retained",
            )
        records = ordered([
            r11_copied_record("Alpha", "ALPHA~1", 0x21),
            r11_copied_record("Zulu", "", 0x41),
        ])
        if code == "TRAVERSAL_COMPONENT_MISSING":
            return literal_diagnostic(
                operation="resolve_component",
                records=records,
                winner=None,
                root=False,
                inventory=False,
                requested_component="Missing",
                requested_depth=3,
                requested_token="retained/requested-missing",
            )
        requested = "alpha" if code == "TRAVERSAL_COMPONENT_CASE_MISMATCH" else "alpha~1"
        winner = records[0]
        return literal_diagnostic(
            operation="resolve_component",
            records=records,
            winner=winner,
            root=False,
            inventory=False,
            requested_depth=3,
            requested_token="retained/requested-component",
            requested_component=requested,
            observed_winner_token="retained/Alpha",
        )
    literal_rows = {
        "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": ("lexical_validate", ()),
        "PATH_DEVICE_NAMESPACE": ("namespace_validate", ()),
        "PATH_UNSUPPORTED_DRIVE_TYPE": (
            "drive_type", ("expected_attributes", "actual_attributes"),
        ),
        "TRAVERSAL_ROOT_OPEN": ("open_root", ("winerror",)),
        "TRAVERSAL_ROOT_REPARSE": (
            "validate_root", ("actual_attributes", "identity_before"),
        ),
        "TRAVERSAL_ROOT_NOT_DIRECTORY": (
            "validate_root",
            ("expected_attributes", "actual_attributes", "identity_before"),
        ),
        "TRAVERSAL_ROOT_ENUM_OPEN": (
            "enum_root_open", ("winerror", "identity_before"),
        ),
        "TRAVERSAL_ROOT_ENUM_NEXT": (
            "enum_root_next", ("winerror", "identity_before"),
        ),
        "TRAVERSAL_ROOT_ENUM_CLOSE": (
            "enum_root_close", ("winerror", "identity_before"),
        ),
        "TRAVERSAL_ROOT_IDENTITY_CHANGED": (
            "revalidate_root",
            (
                "expected_attributes", "actual_attributes",
                "identity_before", "identity_after",
            ),
        ),
        "TRAVERSAL_ROOT_HANDLE_CLOSE": (
            "close_root", ("winerror", "identity_before"),
        ),
        "TRAVERSAL_ENUM_OPEN": (
            "enum_child_open",
            ("component_index", "path_token", "winerror", "identity_before"),
        ),
        "TRAVERSAL_ENUM_NEXT": (
            "enum_child_next",
            ("component_index", "path_token", "winerror", "identity_before"),
        ),
        "TRAVERSAL_ENUM_CLOSE": (
            "enum_child_close",
            ("component_index", "path_token", "winerror", "identity_before"),
        ),
        "TRAVERSAL_ENTRY_REPARSE": (
            "validate_selected_entry",
            (
                "component_index", "path_token", "actual_attributes",
                "identity_before",
            ),
        ),
        "TRAVERSAL_CHILD_OPEN": (
            "open_child",
            (
                "component_index", "path_token", "winerror",
                "expected_attributes", "identity_before",
            ),
        ),
        "TRAVERSAL_CHILD_REPARSE": (
            "validate_open_child",
            (
                "component_index", "path_token", "actual_attributes",
                "identity_before",
            ),
        ),
        "TRAVERSAL_CHILD_TYPE_CHANGED": (
            "validate_open_child",
            (
                "component_index", "path_token", "expected_attributes",
                "actual_attributes", "identity_before",
            ),
        ),
        "TRAVERSAL_IDENTITY_CHANGED": (
            "revalidate_child",
            (
                "component_index", "path_token", "expected_attributes",
                "actual_attributes", "identity_before", "identity_after",
            ),
        ),
        "TRAVERSAL_READ": (
            "read_child",
            ("component_index", "path_token", "winerror", "identity_before"),
        ),
        "TRAVERSAL_HANDLE_CLOSE": (
            "close_child",
            ("component_index", "path_token", "winerror", "identity_before"),
        ),
    }
    operation, fields = literal_rows[code]
    kwargs: dict[str, Any] = {}
    for field in fields:
        if field == "component_index":
            kwargs[field] = 3
        elif field == "path_token":
            kwargs[field] = "retained/leaf"
        elif field == "winerror":
            kwargs[field] = 5
        elif field == "expected_attributes":
            kwargs[field] = (
                3
                if code == "PATH_UNSUPPORTED_DRIVE_TYPE"
                else 0x10
                if code in (
                    "TRAVERSAL_ROOT_NOT_DIRECTORY",
                    "TRAVERSAL_ROOT_IDENTITY_CHANGED",
                )
                else 0
            )
        elif field == "actual_attributes":
            kwargs[field] = (
                0x400
                if code in (
                    "TRAVERSAL_ROOT_REPARSE", "TRAVERSAL_ENTRY_REPARSE",
                    "TRAVERSAL_CHILD_REPARSE",
                )
                else 0x10
                if code == "TRAVERSAL_CHILD_TYPE_CHANGED"
                else 0
            )
        elif field == "identity_before":
            kwargs[field] = r11_test_identity()
        elif field == "identity_after":
            kwargs[field] = r11_test_identity("0000000000000002")
    if code.startswith("TRAVERSAL_ROOT_"):
        kwargs.pop("path_token", None)
        if code not in (
            "TRAVERSAL_ROOT_ENTRY_NAME", "TRAVERSAL_ROOT_ENTRY_COLLISION",
        ):
            kwargs.pop("component_index", None)
        else:
            kwargs["component_index"] = 0
    return builder.R11TraversalDiagnostic(code, operation, **kwargs)


def r11_boundary_states() -> dict[str, dict[str, Any]]:
    authority = r11_literal_authority(0)
    group_index = 5
    source = (
        "smart-contracts/architecture/issue670/"
        "StreamArtistArchiveCompatibilityStateV3Skeleton.sol"
    )
    return {
        "EVIDENCE_CONTROL": {"started": True, "candidate_terminal": False},
        "PORTABLE_BUILD_INFO_LOOKUP": {
            "group_index": 0, "count_complete": False, "actual_count": None,
        },
        "PORTABLE_BUILD_INFO_READ": {
            "group_index": 0, "selected_file_token": "build-info/000/input.json",
        },
        "PORTABLE_SOURCE_LOOKUP": {"group_index": 0, "source_path": source},
        "PORTABLE_SOURCE_READ": {"group_index": 0, "source_path": source},
        "ARTIFACT_LOOKUP": {
            "group_index": group_index,
            "semantic_id": authority["semantic_id"],
            "target": authority["target"],
            "metadata_evaluated": True,
            "item1_passed": False,
        },
        "ARTIFACT_READ": {
            "group_index": group_index,
            "semantic_id": authority["semantic_id"],
            "target": authority["target"],
            "item1_passed": True,
            "selected_artifact_token": f"artifact/{authority['semantic_id']}.json",
            "read_state": None,
        },
        "STAGED_OUTPUT_VALIDATE": {"prefix": "DONE"},
        "OUTPUT_INSTALL": {"prefix": "STAGED"},
        "TEMP_CLEANUP": {"prefix": "INSTALLED"},
        "INSTALLED_INVENTORY": {"prefix": "CLEAN", "selected_file_token": None},
        "INSTALLED_READ": {"prefix": "CLEAN", "selected_file_token": "installed/a.json"},
        "RECOVERY_INVENTORY": {"recovery": True},
    }


def r11_hash(marker: str) -> str:
    return "sha256:" + hashlib.sha256(marker.encode("utf-8")).hexdigest()


class R11IndependentByHandleInformation(ctypes.Structure):
    _fields_ = (
        ("dwFileAttributes", wintypes.DWORD),
        ("ftCreationTime", wintypes.FILETIME),
        ("ftLastAccessTime", wintypes.FILETIME),
        ("ftLastWriteTime", wintypes.FILETIME),
        ("dwVolumeSerialNumber", wintypes.DWORD),
        ("nFileSizeHigh", wintypes.DWORD),
        ("nFileSizeLow", wintypes.DWORD),
        ("nNumberOfLinks", wintypes.DWORD),
        ("nFileIndexHigh", wintypes.DWORD),
        ("nFileIndexLow", wintypes.DWORD),
    )


_R11_INDEPENDENT_KERNEL32: Any | None = None


def _r11_independent_kernel32() -> Any:
    global _R11_INDEPENDENT_KERNEL32
    if os.name != "nt":
        raise unittest.SkipTest("independent R11 receipt helper is Windows-only")
    if _R11_INDEPENDENT_KERNEL32 is None:
        kernel32 = ctypes.WinDLL("kernel32.dll", use_last_error=True)
        kernel32.CreateFileW.argtypes = [
            wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p,
            wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE,
        ]
        kernel32.CreateFileW.restype = wintypes.HANDLE
        kernel32.GetFileInformationByHandle.argtypes = [
            wintypes.HANDLE,
            ctypes.POINTER(R11IndependentByHandleInformation),
        ]
        kernel32.GetFileInformationByHandle.restype = wintypes.BOOL
        kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
        kernel32.CloseHandle.restype = wintypes.BOOL
        _R11_INDEPENDENT_KERNEL32 = kernel32
    return _R11_INDEPENDENT_KERNEL32


def r11_independent_path_token(
    path: Path,
    path_token: str,
    *,
    directory: bool = False,
) -> dict[str, Any]:
    """Construct a receipt without either candidate receipt implementation."""
    kernel32 = _r11_independent_kernel32()
    desired_access = 0x00000080 if directory else 0x80000000 | 0x00000080
    share_mode = 0x00000001 | 0x00000002
    flags = 0x00200000 | (0x02000000 if directory else 0)
    handle = kernel32.CreateFileW(
        str(path), desired_access, share_mode, None, 3, flags, None,
    )
    invalid_handle = ctypes.c_void_p(-1).value
    if handle == invalid_handle:
        raise AssertionError("independent receipt open failed")
    information = R11IndependentByHandleInformation()
    try:
        if not kernel32.GetFileInformationByHandle(
            handle, ctypes.byref(information),
        ):
            raise AssertionError("independent receipt identity query failed")
    finally:
        if not kernel32.CloseHandle(handle):
            raise AssertionError("independent receipt close failed")
    identity = {
        "volume_serial": f"{int(information.dwVolumeSerialNumber):08X}",
        "file_index": f"{((int(information.nFileIndexHigh) << 32) | int(information.nFileIndexLow)):016X}",
    }
    raw = None if directory else path.read_bytes()
    return {
        "path": str(path),
        "identity": identity,
        "byte_count": None if raw is None else len(raw),
        "sha256": None if raw is None else "sha256:" + hashlib.sha256(raw).hexdigest(),
        "path_token": path_token,
        "kind": "directory" if directory else "file",
    }


def r11_independent_invocation_id(operands: dict[str, Any]) -> str:
    path_tokens = operands["path_tokens"]
    invocation_authority = {
        "builder": path_tokens["builder"],
        "test": path_tokens["test"],
        "source_aggregate_sha256": "1EB0A58B8A1DCA624493839D41FA5267078E7FBA67B4AE6DF9205DD003659857",
        "foundry_config_sha256": "C356A459BC9919AE14225E59979601C8EAB26133B19C146E5928D28A7DAFBD61",
        "target_config_sha256": "84B3A32B16B8C171130D0D5F5192F06B2D199D17EF25862FF04B433FD8C3B9F9",
        "group_map_sha256": "5630717FF8C470F250780937C7333062D7CA84DCE87A0CB1510901E5FA18B913",
        "constructor_map_sha256": "0A48FF8AEB3F4358D0AE8889693CCF136B33E1E1982E9497E6F1BB2429BDD06F",
        "forge": path_tokens["forge"],
        "solc": path_tokens["solc"],
        "repo_root": path_tokens["repo_root"],
        "output_dir": path_tokens["output_dir"],
        "evidence_dir": path_tokens["evidence_dir"],
        "held_evidence_directory_identity": operands[
            "held_evidence_directory_identity"
        ],
        "pre_started_checkpoint": operands["pre_started_checkpoint"],
    }
    raw = (
        json.dumps(
            invocation_authority,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
        )
        + "\n"
    ).encode("utf-8", "strict")
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def r11_freeze(value: Any) -> Any:
    if isinstance(value, dict):
        return tuple((key, r11_freeze(member)) for key, member in value.items())
    if isinstance(value, list):
        return tuple(r11_freeze(member) for member in value)
    return value


def r11_checkpoint(label: str) -> dict[str, Any]:
    def receipt(token: str) -> dict[str, Any]:
        return {
            "path": f"C:\\tools\\{token}.exe",
            "identity": r11_test_identity("0000000000000010" if token == "forge" else "0000000000000011"),
            "byte_count": 4,
            "sha256": r11_hash(token),
            "path_token": token,
        }

    return {"label": label, "forge": receipt("forge"), "solc": receipt("solc")}


def r11_canonical_recovery_started(
    evidence: Path,
    *,
    matching: Path,
    mutated: Path,
    missing: Path,
    unreadable: Path,
) -> tuple[dict[str, Any], dict[str, Any]]:
    static: dict[str, Any] = {
        "builder": r11_independent_path_token(matching, "builder"),
        "test": r11_independent_path_token(matching, "builder-test"),
        "config": r11_independent_path_token(matching, "target-config"),
        "foundry_config": r11_independent_path_token(matching, "foundry-config"),
        "forge": r11_independent_path_token(mutated, "Forge executable"),
        "solc": r11_independent_path_token(missing, "Solc executable"),
        "repo_root": r11_independent_path_token(
            unreadable, "repo-root", directory=True,
        ),
        "evidence_dir": r11_independent_path_token(
            evidence, "evidence", directory=True,
        ),
        "output_dir": {
            "path": str(evidence.parent / "absent-output"),
            "identity": None,
            "byte_count": None,
            "sha256": None,
            "path_token": "output-dir",
            "kind": "directory",
            "initial_status": "absent",
        },
    }
    static["source_aggregate"] = {
        **r11_independent_path_token(
            unreadable, "source-root", directory=True,
        ),
        "byte_count": 1,
        "sha256": "sha256:1eb0a58b8a1dca624493839d41fa5267078e7fba67b4ae6df9205dd003659857",
        "source_count": 31,
    }
    for source_path in R11_LITERAL_SOURCE_PATHS:
        receipt = r11_independent_path_token(matching, source_path)
        static[f"source:{source_path}"] = receipt
    common = ("path", "identity", "byte_count", "sha256", "path_token")
    pre_started_checkpoint = {
        "label": "pre-started",
        "forge": {key: static["forge"][key] for key in common},
        "solc": {key: static["solc"][key] for key in common},
    }
    operands = {
        "path_tokens": static,
        "held_evidence_directory_identity": static["evidence_dir"]["identity"],
        "pre_started_checkpoint": pre_started_checkpoint,
    }
    started = {
        "schema": R11_LITERAL_EVENT_SCHEMA,
        "invocation_id": r11_independent_invocation_id(operands),
        "sequence": 0,
        "previous_event_sha256": None,
        "event_type": "execution_started",
        "phase": "execution",
        "operands": operands,
    }
    return started, static


def r11_stdlib_canonical_bytes(value: Any) -> bytes:
    return (
        json.dumps(
            value,
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8", "strict")


def r11_independent_checkpoint(
    label: str,
    static: dict[str, Any],
) -> dict[str, Any]:
    common = ("path", "identity", "byte_count", "sha256", "path_token")
    return {
        "label": label,
        "forge": {key: static["forge"][key] for key in common},
        "solc": {key: static["solc"][key] for key in common},
    }


def r11_independent_terminal_context(
    parity_root: Path,
    *,
    first_red: dict[str, Any] | None,
    results: dict[str, Any],
    status: str = "NO_GO",
) -> dict[str, Any]:
    evidence_directory = parity_root / "evidence"
    evidence_directory.mkdir()
    publication_directory = parity_root / "publication"
    publication_directory.mkdir()
    matching = parity_root / "matching.bin"
    matching.write_bytes(b"matching")
    forge = parity_root / "forge.exe"
    forge.write_bytes(b"forge")
    solc = parity_root / "solc.exe"
    solc.write_bytes(b"solc")
    directory = parity_root / "directory"
    directory.mkdir()
    started, static = r11_canonical_recovery_started(
        evidence_directory,
        matching=matching,
        mutated=forge,
        missing=solc,
        unreadable=directory,
    )
    environment = {
        "FOUNDRY_PROFILE": "default",
        "R11_LITERAL_ENVIRONMENT": "fixture",
    }
    environment_raw = r11_stdlib_canonical_bytes(environment)
    event_rows: list[tuple[str, bytes]] = []
    started_raw = r11_stdlib_canonical_bytes(started)
    previous_event_sha256 = (
        "sha256:" + hashlib.sha256(started_raw).hexdigest()
    )
    event_rows.append(("execution-started.json", started_raw))
    calls: list[dict[str, Any]] = []
    checkpoints = [r11_independent_checkpoint("pre-started", static)]
    for ordinal, phase, group_string in R11_LITERAL_CALL_SCHEDULE:
        command = [str(forge), f"fixture-{ordinal:03d}"]
        checkpoint_before = r11_independent_checkpoint(
            f"invocation-{ordinal:03d}-before", static,
        )
        checkpoint_after = r11_independent_checkpoint(
            f"invocation-{ordinal:03d}-after", static,
        )
        sequence = ordinal * 2 + 1
        start_event = {
            "schema": R11_LITERAL_EVENT_SCHEMA,
            "invocation_id": started["invocation_id"],
            "sequence": sequence,
            "previous_event_sha256": previous_event_sha256,
            "event_type": "invocation_start",
            "phase": phase,
            "operands": {
                "ordinal": ordinal,
                "group_string": group_string,
                "executable": command[0],
                "argv": command,
                "argv_sha256": (
                    "sha256:" + hashlib.sha256(
                        r11_stdlib_canonical_bytes(command)
                    ).hexdigest()
                ),
                "environment_sha256": (
                    "sha256:" + hashlib.sha256(environment_raw).hexdigest()
                ),
                "environment_entry_count": len(environment),
                "cwd": str(parity_root),
                "start_monotonic_ms": 1_000,
                "checkpoint": checkpoint_before,
            },
        }
        start_raw = r11_stdlib_canonical_bytes(start_event)
        start_sha256 = "sha256:" + hashlib.sha256(start_raw).hexdigest()
        exit_event = {
            "schema": R11_LITERAL_EVENT_SCHEMA,
            "invocation_id": started["invocation_id"],
            "sequence": sequence + 1,
            "previous_event_sha256": start_sha256,
            "event_type": "invocation_exit",
            "phase": phase,
            "operands": {
                "ordinal": ordinal,
                "group_string": group_string,
                "launched": True,
                "exit_code": 0,
                "start_monotonic_ms": 1_000,
                "end_monotonic_ms": 1_000,
                "stdout_byte_count": 0,
                "stdout_sha256": (
                    "sha256:" + hashlib.sha256(b"").hexdigest()
                ),
                "stderr_byte_count": 0,
                "stderr_sha256": (
                    "sha256:" + hashlib.sha256(b"").hexdigest()
                ),
                "exception_type": None,
                "exception_sha256": None,
                "checkpoint": checkpoint_after,
            },
        }
        exit_raw = r11_stdlib_canonical_bytes(exit_event)
        exit_sha256 = "sha256:" + hashlib.sha256(exit_raw).hexdigest()
        event_rows.extend((
            (f"invocation-{ordinal:03d}-start.json", start_raw),
            (f"invocation-{ordinal:03d}-exit.json", exit_raw),
        ))
        calls.append({
            "ordinal": ordinal,
            "phase": phase,
            "group_string": group_string,
            "start_event_sha256": start_sha256,
            "exit_event_sha256": exit_sha256,
            "argv_sha256": start_event["operands"]["argv_sha256"],
            "environment_sha256": start_event["operands"][
                "environment_sha256"
            ],
            "launched": True,
            "exit_code": 0,
            "stdout_byte_count": 0,
            "stdout_sha256": exit_event["operands"]["stdout_sha256"],
            "stderr_byte_count": 0,
            "stderr_sha256": exit_event["operands"]["stderr_sha256"],
            "exception_type": None,
            "exception_sha256": None,
        })
        checkpoints.extend((checkpoint_before, checkpoint_after))
        previous_event_sha256 = exit_sha256
    if (
        len(event_rows) != 37
        or len(calls) != 18
        or len(checkpoints) != 37
        or [name for name, _raw in event_rows] != [
            "execution-started.json",
            *[
                f"invocation-{ordinal:03d}-{suffix}.json"
                for ordinal in range(18)
                for suffix in ("start", "exit")
            ],
        ]
    ):
        raise AssertionError("independent terminal context is incomplete")
    terminal = {
        "schema": R11_LITERAL_TERMINAL_SCHEMA,
        "invocation_id": started["invocation_id"],
        "status": status,
        "first_red": copy.deepcopy(first_red),
        "event_count": 37,
        "event_head_sha256": previous_event_sha256,
        "calls": calls,
        "checkpoints": checkpoints,
        "results": copy.deepcopy(results),
        "no_retry": True,
    }
    raw = r11_stdlib_canonical_bytes(terminal)
    return {
        "parity_root": parity_root,
        "evidence_directory": evidence_directory,
        "publication_directory": publication_directory,
        "forge": forge,
        "solc": solc,
        "started": started,
        "static": static,
        "event_rows": event_rows,
        "terminal": terminal,
        "raw": raw,
    }


class _R11NonPublishingJournalHarness(builder.ExecutionJournal):
    """Private replay harness that cannot publish an authoritative terminal."""

    def __init__(
        self,
        evidence_dir: Path,
        invocation_id: str,
        static_receipts: dict[str, Any],
        forge_bin: Path,
        solc_bin: Path,
        *,
        held_evidence_directory_identity: dict[str, str],
        pre_started_checkpoint: dict[str, Any],
    ) -> None:
        self.execution_authority = None
        self.evidence_dir = evidence_dir
        self.invocation_id = invocation_id
        self.static_receipts = static_receipts
        self.forge_bin = forge_bin
        self.solc_bin = solc_bin
        self.held_evidence_directory_identity = dict(
            held_evidence_directory_identity,
        )
        self.pre_started_checkpoint = pre_started_checkpoint
        self.sequence = -1
        self.event_head_sha256: str | None = None
        self.calls: list[dict[str, Any]] = []
        self.checkpoints: list[dict[str, Any]] = []
        self.terminal: dict[str, Any] | None = None
        self.state = "PRE_EVENT"
        self.guard: dict[str, Any] | None = None

    def publish_started(self) -> dict[str, Any]:
        with patch.object(
            builder,
            "_r11_require_journal_execution_authority",
            return_value=None,
        ):
            return super().publish_started()

    def invoke(
        self,
        ordinal: int,
        command: list[str],
        cwd: Path,
        *,
        phase: str,
        group_string: str | None,
    ) -> builder.CommandResult:
        with patch.object(
            builder,
            "_r11_require_journal_execution_authority",
            return_value=None,
        ):
            return super().invoke(
                ordinal,
                command,
                cwd,
                phase=phase,
                group_string=group_string,
            )

    def publish_terminal(self, *_args: Any, **_kwargs: Any) -> dict[str, Any]:
        raise AssertionError(
            "the private replay harness cannot publish an authoritative terminal",
        )


def r11_materialize_candidate_journal(
    context: dict[str, Any],
) -> _R11NonPublishingJournalHarness:
    started = context["started"]
    static = context["static"]
    forge = context["forge"]
    solc = context["solc"]
    journal = _R11NonPublishingJournalHarness(
        context["evidence_directory"],
        started["invocation_id"],
        static,
        forge,
        solc,
        held_evidence_directory_identity=started["operands"][
            "held_evidence_directory_identity"
        ],
        pre_started_checkpoint=started["operands"][
            "pre_started_checkpoint"
        ],
    )
    with (
        patch.dict(
            builder.os.environ,
            {"R11_LITERAL_ENVIRONMENT": "fixture"},
            clear=True,
        ),
        patch.object(
            builder.time, "monotonic_ns", return_value=1_000_000_000,
        ),
        patch.object(
            builder,
            "_captured_subprocess",
            return_value=builder.CommandResult(True, 0, b"", b""),
        ),
    ):
        journal.publish_started()
        for ordinal, phase, group_string in R11_LITERAL_CALL_SCHEDULE:
            journal.invoke(
                ordinal,
                [str(forge), f"fixture-{ordinal:03d}"],
                context["parity_root"],
                phase=phase,
                group_string=group_string,
            )
    for filename, expected_raw in context["event_rows"]:
        if (
            context["evidence_directory"] / filename
        ).read_bytes() != expected_raw:
            raise AssertionError("candidate event differs from independent bytes")
    terminal = context["terminal"]
    if (
        journal.invocation_id != terminal["invocation_id"]
        or journal.sequence + 1 != terminal["event_count"]
        or journal.event_head_sha256 != terminal["event_head_sha256"]
        or journal.calls != terminal["calls"]
        or journal.checkpoints != terminal["checkpoints"]
    ):
        raise AssertionError("candidate journal differs from independent context")
    return journal


def r11_install_literal_terminal_fixture(
    context: dict[str, Any],
) -> dict[str, Any]:
    journal = r11_materialize_candidate_journal(context)
    terminal = context["terminal"]
    journal._candidate_terminal_gate(terminal)
    terminal_path = context["evidence_directory"] / "terminal.json"
    with terminal_path.open("xb") as output:
        output.write(context["raw"])
    return terminal


def r11_authorize_candidate_journal(
    context: dict[str, Any],
    replay: _R11NonPublishingJournalHarness,
) -> tuple[
    builder.ExecutionJournal,
    builder.R11ExecutionAuthority,
    builder.WindowsDirectoryLock,
    builder.R11ExecutableLeaseSet,
]:
    leases = builder.R11ExecutableLeaseSet.acquire(
        context["forge"], context["solc"], context["static"],
    )
    try:
        run_lock = builder.WindowsDirectoryLock.acquire(
            context["evidence_directory"],
        )
    except BaseException as primary:
        try:
            leases.close()
        except BaseException as cleanup:
            raise cleanup from primary
        raise
    run_lock.executable_leases = leases
    authority = builder.R11ExecutionAuthority(run_lock)
    started = context["started"]
    journal = builder.ExecutionJournal(
        context["evidence_directory"],
        started["invocation_id"],
        context["static"],
        context["forge"],
        context["solc"],
        held_evidence_directory_identity=started["operands"][
            "held_evidence_directory_identity"
        ],
        pre_started_checkpoint=started["operands"][
            "pre_started_checkpoint"
        ],
        execution_authority=authority,
    )
    journal.sequence = replay.sequence
    journal.event_head_sha256 = replay.event_head_sha256
    journal.calls = copy.deepcopy(replay.calls)
    journal.checkpoints = copy.deepcopy(replay.checkpoints)
    journal.state = replay.state
    journal.guard = None
    return journal, authority, run_lock, leases


def r11_publish_literal_terminal_with_disk_parity(
    testcase: unittest.TestCase,
    context: dict[str, Any],
    frozen_terminal: dict[str, Any],
    frozen_raw: bytes,
) -> tuple[dict[str, Any], bytes]:
    terminal = context["terminal"]
    raw = context["raw"]
    testcase.assertEqual(terminal, frozen_terminal)
    testcase.assertEqual(raw, frozen_raw)
    testcase.assertEqual(r11_stdlib_canonical_bytes(frozen_terminal), frozen_raw)
    journal = r11_materialize_candidate_journal(context)
    testcase.assertEqual(terminal, frozen_terminal)
    testcase.assertEqual(r11_stdlib_canonical_bytes(terminal), frozen_raw)
    builder.r11_validate_builder_terminal(terminal)
    testcase.assertEqual(terminal, frozen_terminal)
    testcase.assertEqual(r11_stdlib_canonical_bytes(terminal), frozen_raw)
    journal._candidate_terminal_gate(terminal)
    testcase.assertEqual(terminal, frozen_terminal)
    testcase.assertEqual(r11_stdlib_canonical_bytes(terminal), frozen_raw)
    with (
        patch.object(
            builder,
            "_r11_publish_preconstructed",
            wraps=builder._r11_publish_preconstructed,
        ) as publisher,
        patch.object(
            builder,
            "publish_json_no_replace",
            wraps=builder.publish_json_no_replace,
        ) as ordinary_publisher,
    ):
        builder._r11_publish_preconstructed(
            context["publication_directory"],
            "terminal.json",
            terminal,
            frozen_raw,
            "sha256:" + hashlib.sha256(frozen_raw).hexdigest(),
        )
        testcase.assertEqual(
            (
                context["publication_directory"] / "terminal.json"
            ).read_bytes(),
            frozen_raw,
        )
    testcase.assertEqual(publisher.call_count, 1)
    testcase.assertEqual(ordinary_publisher.call_count, 1)
    return terminal, frozen_raw


def r11_builder_nogo_terminal() -> dict[str, Any]:
    return {
        "schema": builder.EVIDENCE_TERMINAL_SCHEMA,
        "invocation_id": r11_hash("invocation"),
        "status": "NO_GO",
        "first_red": {
            "phase": "forge_version",
            "code": "FORGE_VERSION_FORMAT",
            "call_ordinal": 0,
            "group_index": None,
            "group_string": None,
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {"byte_count": 1, "sha256": r11_hash("x")},
        },
        "event_count": 3,
        "event_head_sha256": r11_hash("event-head"),
        "calls": [
            {
                "ordinal": 0,
                "phase": "forge_version",
                "group_string": None,
                "start_event_sha256": r11_hash("start"),
                "exit_event_sha256": r11_hash("exit"),
                "argv_sha256": r11_hash("argv"),
                "environment_sha256": r11_hash("environment"),
                "launched": True,
                "exit_code": 0,
                "stdout_byte_count": 1,
                "stdout_sha256": r11_hash("stdout"),
                "stderr_byte_count": 0,
                "stderr_sha256": r11_hash("stderr"),
                "exception_type": None,
                "exception_sha256": None,
            }
        ],
        "checkpoints": [
            r11_checkpoint("pre-started"),
            r11_checkpoint("invocation-000-before"),
            r11_checkpoint("invocation-000-after"),
        ],
        "results": r11_literal_initial_results(),
        "no_retry": True,
    }


def r11_recovery_terminal() -> dict[str, Any]:
    return {
        "schema": R11_LITERAL_TERMINAL_SCHEMA,
        "invocation_id": "sha256:" + "1" * 64,
        "status": "NO_GO",
        "first_red": {"code": "interrupted_execution", "operands": {}},
        "event_count": 2,
        "event_head_sha256": "sha256:" + "2" * 64,
        "calls": [],
        "checkpoints": [],
        "results": {
            "recovery": True,
            "path_token_status": [],
            "anomalies": [],
            "sentinel_sha256": "sha256:" + "3" * 64,
            "predicates_evaluated": 0,
            "subprocess_calls": 0,
            "output_validated": False,
        },
        "no_retry": True,
    }


def r11_validate_literal_recovery_terminal(
    candidate: Any,
    expected: dict[str, Any],
) -> None:
    builder.r11_validate_recovery_terminal(
        candidate,
        expected_invocation_id=expected["invocation_id"],
        expected_sentinel_sha256=expected["results"]["sentinel_sha256"],
        expected_event_count=expected["event_count"],
        expected_event_head_sha256=expected["event_head_sha256"],
    )


class R11FindFake:
    def __init__(
        self,
        records: list[tuple[str, str, int]],
        *,
        first_error: int = builder._R11_ERROR_FILE_NOT_FOUND,
        next_error: int = builder._R11_ERROR_NO_MORE_FILES,
        close_error: int | None = None,
    ) -> None:
        self.records = records
        self.first_error = first_error
        self.next_error = next_error
        self.close_error = close_error
        self.index = 0
        self.close_calls = 0

    @staticmethod
    def _write(pointer: Any, record: tuple[str, str, int]) -> None:
        name, alternate, attributes = record
        data = ctypes.cast(pointer, ctypes.POINTER(builder._R11FindData)).contents
        data.dwFileAttributes = attributes
        data.cFileName = name
        data.cAlternateFileName = alternate

    def FindFirstFileW(self, _pattern: str, pointer: Any) -> int:
        if not self.records:
            ctypes.set_last_error(self.first_error)
            return builder._INVALID_HANDLE_VALUE
        self.index = 1
        self._write(pointer, self.records[0])
        ctypes.set_last_error(0x7FFF)
        return 0x1234

    def FindNextFileW(self, _handle: int, pointer: Any) -> bool:
        if self.index < len(self.records):
            self._write(pointer, self.records[self.index])
            self.index += 1
            ctypes.set_last_error(0x7FFF)
            return True
        ctypes.set_last_error(self.next_error)
        return False

    def FindClose(self, _handle: int) -> bool:
        self.close_calls += 1
        if self.close_error is not None:
            ctypes.set_last_error(self.close_error)
            return False
        ctypes.set_last_error(0x7FFF)
        return True


R11_EXPECTED_BOUNDARIES = (
    "EVIDENCE_CONTROL", "PORTABLE_BUILD_INFO_LOOKUP",
    "PORTABLE_BUILD_INFO_READ", "PORTABLE_SOURCE_LOOKUP",
    "PORTABLE_SOURCE_READ", "ARTIFACT_LOOKUP", "ARTIFACT_READ",
    "STAGED_OUTPUT_VALIDATE", "OUTPUT_INSTALL", "TEMP_CLEANUP",
    "INSTALLED_INVENTORY", "INSTALLED_READ", "RECOVERY_INVENTORY",
)
R11_LITERAL_NATIVE_OUTCOME_ROWS = {
    "PATH_NOT_LOCAL_DRIVE_ABSOLUTE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "PATH_DEVICE_NAMESPACE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "PATH_UNSUPPORTED_DRIVE_TYPE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_REPARSE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_NOT_DIRECTORY": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_ENUM_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_ENUM_NEXT": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_ENUM_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_ENTRY_NAME": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_ENTRY_COLLISION": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_IDENTITY_CHANGED": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "ARI", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ROOT_HANDLE_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_NEXT": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENUM_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENTRY_NAME": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_ENTRY_COLLISION": ("V", "BLD", "BIR", "SRD", "SRD", "AA", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_COMPONENT_MISSING": ("V", "BLD", "BIR", "SPA", "SRD", "AM", "AFR", "X", "X", "X", "X", "OIR", "X"),
    "TRAVERSAL_COMPONENT_CASE_MISMATCH": ("V", "BLD", "BIR", "SPC", "SRD", "AA", "AFR", "X", "X", "X", "X", "OIR", "X"),
    "TRAVERSAL_COMPONENT_SHORT_ALIAS": ("V", "BLD", "BIR", "SPC", "SRD", "AA", "AFR", "X", "X", "X", "X", "OIR", "X"),
    "TRAVERSAL_ENTRY_REPARSE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_OPEN": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_REPARSE": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_CHILD_TYPE_CHANGED": ("V", "BLD", "BIR", "SRD", "SRD", "AO", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_IDENTITY_CHANGED": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "ARI", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_READ": ("V", "X", "BIR", "X", "SRD", "X", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
    "TRAVERSAL_HANDLE_CLOSE": ("V", "BLD", "BIR", "SRD", "SRD", "ALF", "AFR", "STG", "X", "X", "OII", "OIR", "R"),
}


class R11AuthoritativeEvidenceTests(
    R4AuthoritativeEvidenceHistory,
    unittest.TestCase,
):
    def test_r11_01_exact_authority_and_legacy_partition(self) -> None:
        self.assertEqual(builder.GENERATOR_VERSION, "5")
        self.assertEqual(len(builder.R4_GROUPS), 17)
        self.assertEqual(len(builder.R4_TARGET_AUTHORITIES), 19)
        self.assertIs(builder._build_release_output_evidence, builder._build_release_output_evidence_r11)
        self.assertIs(builder._prepare_evidence_run, builder._prepare_evidence_run_r11)
        self.assertIsNot(
            builder.r4_validate_ordered_bytecode,
            builder.validate_ordered_bytecode,
        )
        self.assertIsNot(
            builder.r4_validate_authoritative_output,
            builder.validate_authoritative_output,
        )
        self.assertIn(
            "return _build_release_output_evidence_r11(",
            inspect.getsource(builder.build_release_output),
        )

    def test_r11_02_cli_pairing_and_recovery_exclusion(self) -> None:
        paired = builder.parse_args(
            ["--solc-bin", "C:/solc.exe", "--evidence-dir", "C:/evidence"]
        )
        self.assertEqual(paired.solc_bin, Path("C:/solc.exe"))
        recovery = builder.parse_args(
            ["--recover-interrupted", "--evidence-dir", "C:/evidence"]
        )
        self.assertTrue(recovery.recover_interrupted)
        for argv in (
            ["--solc-bin", "C:/solc.exe"],
            ["--evidence-dir", "C:/evidence"],
            ["--recover-interrupted", "--evidence-dir", "C:/evidence", "--solc-bin", "C:/solc.exe"],
        ):
            with self.subTest(argv=argv), redirect_stderr(StringIO()):
                with self.assertRaises(SystemExit):
                    builder.parse_args(argv)
        injected = Mock()
        with patch.object(builder, "_build_release_output_evidence") as evidence_build:
            assert_r4_failure(
                self,
                "EVIDENCE_RUNNER_INJECTION_FORBIDDEN",
                builder.build_release_output,
                Path("C:/repo"),
                Path("contracts.json"),
                Path("foundry.toml"),
                Path("out-release"),
                "C:/forge.exe",
                injected,
                solc_bin=Path("C:/solc.exe"),
                evidence_dir=Path("C:/evidence"),
            )
        evidence_build.assert_not_called()
        injected.assert_not_called()
        evidence_source = inspect.getsource(
            builder._build_release_output_evidence_r11,
        )
        invoke_source = inspect.getsource(builder.ExecutionJournal.invoke)
        self.assertNotIn("runner", evidence_source)
        self.assertNotIn("runner", inspect.signature(builder.ExecutionJournal.invoke).parameters)
        self.assertNotIn("runner", invoke_source)

    def test_r11_03_native_matrix_is_direct_literal_28_by_13(self) -> None:
        self.assertEqual(builder.R11_BOUNDARY_IDS, R11_EXPECTED_BOUNDARIES)
        expected_induced = {
            code: dict(zip(R11_EXPECTED_BOUNDARIES, cells, strict=True))
            for code, cells in R11_LITERAL_NATIVE_OUTCOME_ROWS.items()
        }
        self.assertEqual(builder.R11_INDUCED_MATRIX, expected_induced)
        self.assertEqual(len(builder.R11_TRANSLATION_MATRIX), 20)
        self.assertEqual(len(builder.R11_INDUCED_MATRIX), 28)
        base = [value for row in builder.R11_TRANSLATION_MATRIX.values() for value in row.values()]
        induced = [value for row in builder.R11_INDUCED_MATRIX.values() for value in row.values()]
        self.assertEqual((len(base), base.count("X")), (260, 52))
        self.assertEqual((len(induced), induced.count("X")), (364, 68))
        expected_codes = {
            "BLD": "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION",
            "BIR": "PORTABLE_INPUT_BUILD_INFO_READ",
            "SRD": "PORTABLE_INPUT_SOURCE_READ",
            "SPA": "PORTABLE_INPUT_SOURCE_PATH",
            "SPC": "PORTABLE_INPUT_SOURCE_PATH",
            "AM": "METADATA_TARGET_AND_PATH",
            "AA": "METADATA_TARGET_AND_PATH",
            "AO": "METADATA_TARGET_AND_PATH",
            "ALF": "METADATA_TARGET_AND_PATH",
            "AFR": "ARTIFACT_FILE_READ",
            "ARI": "ARTIFACT_FILE_READ",
            "STG": "STAGED_VALIDATION_FAILED",
            "OII": "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION",
            "OIR": "OP_INSTALLED_OUTPUT_READ_EXCEPTION",
        }
        states = r11_boundary_states()
        bic_result = {
            "actual_sha256": (
                "sha256:98897ba821f290cd5434d2fb5d638800d28d790cff3e9f58f"
                "a98e6645985bfe5"
            ),
        }
        bic_records = [
            r11_copied_record("AliasA.txt", "REQ~1.TXT", 0x20),
            r11_copied_record("Unrelated.txt", "OTHER~1.TXT", 0x10),
        ]
        for bic_record in bic_records:
            bic_record["raw_ordinal"] = sum(
                other["record_key"] < bic_record["record_key"]
                for other in bic_records
            )
        builder.r11_validate_strict_bic(
            bic_records,
            "REQ~1.TXT",
            "fixture/parent",
            bic_result,
        )

        def assert_strict_bic_substitution_rejects(
            code: str,
            boundary: str,
        ) -> None:
            with (
                self.subTest(
                    code=code,
                    boundary=boundary,
                    substitution="strict-bic",
                ),
                patch.object(
                    builder, "_r11_first_red",
                    wraps=builder._r11_first_red,
                ) as bic_constructor,
                patch.object(
                    builder, "_r11_publish_preconstructed",
                ) as bic_publication,
                patch.object(
                    builder, "publish_json_no_replace",
                ) as bic_legacy_publication,
                self.assertRaises((AttributeError, TypeError, ValueError)),
            ):
                builder.r11_translate_diagnostic(
                    copy.deepcopy(bic_result),  # type: ignore[arg-type]
                    boundary,
                    copy.deepcopy(states[boundary]),
                )
            bic_constructor.assert_not_called()
            bic_publication.assert_not_called()
            bic_legacy_publication.assert_not_called()

        observed = 0
        for code, literal_cells in R11_LITERAL_NATIVE_OUTCOME_ROWS.items():
            for boundary_index, boundary in enumerate(R11_EXPECTED_BOUNDARIES):
                observed += 1
                cell = literal_cells[boundary_index]
                literal_operands = r11_literal_diagnostic_operands(code)
                diagnostic_raw = r11_stdlib_canonical_bytes({
                    "code": code,
                    "operands": literal_operands,
                })
                digest = (
                    "sha256:" + hashlib.sha256(diagnostic_raw).hexdigest()
                )
                diagnostic = r11_complete_diagnostic(code)
                self.assertEqual(diagnostic.operands, literal_operands)
                dx = {"exception_type": code, "message_sha256": digest}
                if cell in ("X", "V"):
                    with (
                        self.subTest(code=code, boundary=boundary, cell=cell),
                        patch.object(builder, "_r11_first_red", wraps=builder._r11_first_red) as constructor,
                    ):
                        with self.assertRaises(builder.R11TraversalDiagnostic):
                            builder.r11_translate_diagnostic(
                                diagnostic, boundary, copy.deepcopy(states[boundary]),
                            )
                        constructor.assert_not_called()
                    assert_strict_bic_substitution_rejects(code, boundary)
                    continue
                with patch.object(
                    builder, "_r11_first_red", wraps=builder._r11_first_red,
                ) as constructor:
                    translated = builder.r11_translate_diagnostic(
                        diagnostic, boundary, copy.deepcopy(states[boundary]),
                    )
                with self.subTest(code=code, boundary=boundary, cell=cell):
                    if cell == "R":
                        constructor.assert_not_called()
                        self.assertEqual(
                            translated,
                            {
                                "status": "invalid",
                                "exception_type": code,
                                "message_sha256": digest,
                            },
                        )
                    else:
                        constructor.assert_called_once()
                        self.assertEqual(translated.first_red["code"], expected_codes[cell])
                        self.assertEqual(
                            tuple(sorted(translated.first_red)),
                            builder.R11_FIRST_RED_KEYS,
                        )
                        if cell == "BLD":
                            expected_operands = dx
                        elif cell == "BIR":
                            expected_operands = {
                                "path_token": states[boundary]["selected_file_token"],
                                **dx,
                            }
                        elif cell == "SRD":
                            expected_operands = {
                                "source_path": states[boundary]["source_path"],
                                **dx,
                            }
                        elif cell == "SPA":
                            expected_operands = {
                                "source_path": states[boundary]["source_path"],
                                "reason": "absent",
                            }
                        elif cell == "SPC":
                            expected_operands = {
                                "source_path": states[boundary]["source_path"],
                                "reason": "case_mismatch",
                            }
                        elif cell == "AM":
                            expected_operands = {
                                "item": 1, "reason": "artifact_path_missing",
                            }
                        elif cell == "AA":
                            expected_operands = {
                                "item": 1, "reason": "artifact_path_ambiguous",
                            }
                        elif cell == "AO":
                            expected_operands = {
                                "item": 1, "reason": "artifact_path_not_ordinary",
                            }
                        elif cell == "ALF":
                            expected_operands = {
                                "item": 1, "reason": "artifact_path_lookup_failure",
                            }
                        elif cell == "AFR":
                            expected_operands = dx
                        elif cell == "ARI":
                            expected_operands = dx
                        elif cell == "STG":
                            expected_operands = {
                                "cause_type": code, "message_sha256": digest,
                            }
                        elif cell == "OII":
                            expected_operands = dx
                        elif cell == "OIR":
                            expected_operands = {
                                "path_token": states[boundary]["selected_file_token"],
                                **dx,
                            }
                        else:
                            raise AssertionError(
                                f"unlisted translated matrix cell: {cell}"
                            )
                        self.assertEqual(translated.first_red["operands"], expected_operands)
                assert_strict_bic_substitution_rejects(code, boundary)
        self.assertEqual(observed, 364)

    def test_r11_04_native_find_layout_and_exact_four_production_apis(self) -> None:
        self.assertEqual(ctypes.sizeof(builder._R11FileTime), 8)
        self.assertEqual(ctypes.sizeof(builder._R11FindData), 592)
        self.assertEqual(
            tuple(getattr(builder._R11FindData, name).offset for name, _ in builder._R11FindData._fields_),
            (0, 4, 12, 20, 28, 32, 36, 40, 44, 564),
        )
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        for name in ("GetDriveTypeW", "FindFirstFileW", "FindNextFileW", "FindClose"):
            self.assertIn(name, source)

    def test_r11_05_utf16_component_and_wildcard_contract(self) -> None:
        self.assertEqual(builder._r11_u16("a"), 1)
        self.assertEqual(builder._r11_u16("\U0001f600"), 2)
        self.assertEqual(builder._r11_pattern("\\\\?\\C:\\", root=True), "\\\\?\\C:\\*")
        self.assertEqual(builder._r11_pattern("\\\\?\\C:\\dir", root=False), "\\\\?\\C:\\dir\\*")
        ascii_parent = "\\\\?\\C:\\" + "a" * (32_764 - len("\\\\?\\C:\\"))
        self.assertEqual(builder._r11_u16(ascii_parent), 32_764)
        builder._r11_pattern(ascii_parent, root=False)
        with self.assertRaises(builder.R11TraversalDiagnostic):
            builder._r11_pattern(ascii_parent + "a", root=False)
        astral_parent = (
            "\\\\?\\C:\\" + "a" * (32_762 - len("\\\\?\\C:\\"))
            + "\U0001f600"
        )
        self.assertEqual(builder._r11_u16(astral_parent), 32_764)
        builder._r11_pattern(astral_parent, root=False)
        with self.assertRaises(UnicodeEncodeError):
            builder._r11_u16("\ud800")

        class TrappedString(str):
            def encode(self, *_args: Any, **_kwargs: Any) -> bytes:
                raise AssertionError("string subtype reached encoding")

            def __contains__(self, _value: object) -> bool:
                raise AssertionError("string subtype reached component iteration")

            def split(self, *_args: Any, **_kwargs: Any) -> list[str]:
                raise AssertionError("string subtype reached FILETOKEN iteration")

        for validator in (
            builder._r11_validate_component,
            builder._r11_validate_filetoken,
        ):
            with self.subTest(validator=validator.__name__), self.assertRaises(TypeError):
                validator(TrappedString("ordinary"))
        for component in (
            "", ".", "..", "bad\x00name", "bad/name", "bad\\name",
            "bad:", "bad*", "bad?", "trail.", "trail ",
        ):
            with self.subTest(component=component), self.assertRaises((ValueError, UnicodeError)):
                builder._r11_validate_component(component)
        self.assertEqual(
            builder._r11_join_filetoken("installed/nested", "leaf.json"),
            "installed/nested/leaf.json",
        )
        for token in (
            "", "/absolute", "C:/native", "\\\\?\\C:\\native", "a\\b",
            "a/../b", "a/./b", "a//b", "a/trailing.",
        ):
            with self.subTest(token=token), self.assertRaises((ValueError, UnicodeError)):
                builder._r11_validate_filetoken(token)
        native_calls: list[str] = []

        def forbidden_native() -> Any:
            native_calls.append("native")
            raise AssertionError("native traversal ran before FILETOKEN validation")

        with patch.object(builder, "_kernel32", side_effect=forbidden_native):
            with self.assertRaises(ValueError):
                builder.r11_native_inventory(Path("C:/unused"), "")
        self.assertEqual(native_calls, [])

        class DriveTypeFake:
            def __init__(self, drive_type: int) -> None:
                self.drive_type = drive_type
                self.calls: list[str] = []

            def GetDriveTypeW(self, root: str) -> int:
                self.calls.append(root)
                return self.drive_type

        fixed = DriveTypeFake(builder._R11_DRIVE_FIXED)
        with patch.object(builder, "_kernel32", return_value=fixed):
            root, parts, cumulative = builder._r11_absolute_parts("C:\\ordinary")
        self.assertEqual((root, parts, cumulative), (
            "\\\\?\\C:\\", ["ordinary"], "\\\\?\\C:\\ordinary",
        ))
        self.assertEqual(fixed.calls, ["C:\\"])
        for invalid_path in (
            "relative", "C:drive-relative", "\\\\server\\share",
            "\\\\?\\C:\\extended", "\\\\.\\C:\\device",
        ):
            forbidden = DriveTypeFake(builder._R11_DRIVE_FIXED)
            with (
                self.subTest(invalid_path=invalid_path),
                patch.object(builder, "_kernel32", return_value=forbidden),
                self.assertRaises(builder.R11TraversalDiagnostic),
            ):
                builder._r11_absolute_parts(invalid_path)
            self.assertEqual(forbidden.calls, [])
        surrogate = DriveTypeFake(builder._R11_DRIVE_FIXED)
        with (
            patch.object(builder, "_kernel32", return_value=surrogate),
            self.assertRaises(builder.R11TraversalDiagnostic) as surrogate_red,
        ):
            builder._r11_absolute_parts("C:\\" + "\ud800")
        self.assertEqual(
            surrogate_red.exception.code,
            "PATH_NOT_LOCAL_DRIVE_ABSOLUTE",
        )
        self.assertEqual(
            surrogate_red.exception.operands,
            {
                "operation": "lexical_validate",
                "component_index": None,
                "path_token": None,
                "winerror": None,
                "expected_attributes": None,
                "actual_attributes": None,
                "identity_before": None,
                "identity_after": None,
            },
        )
        self.assertIsNone(surrogate_red.exception.record_proof)
        self.assertIsInstance(
            surrogate_red.exception.__cause__, UnicodeEncodeError,
        )
        self.assertEqual(surrogate.calls, [])
        remote = DriveTypeFake(4)
        with (
            patch.object(builder, "_kernel32", return_value=remote),
            self.assertRaises(builder.R11TraversalDiagnostic) as remote_red,
        ):
            builder._r11_absolute_parts("Z:\\remote")
        self.assertEqual(remote_red.exception.code, "PATH_UNSUPPORTED_DRIVE_TYPE")
        self.assertEqual(remote.calls, ["Z:\\"])

    def test_r11_06_record_key_collision_and_alias_winner_are_byte_ordered(self) -> None:
        source = inspect.getsource(builder._r11_find_snapshot) + inspect.getsource(builder._r11_lookup_record)
        self.assertIn('item["record_key"]', source)
        self.assertIn("min(aliases", source)
        self.assertLess(source.index("if malformed"), source.index("collision_members"))
        records = [
            r11_copied_record("Zulu", "NAME~1", 2),
            r11_copied_record("Alpha", "name~1", 1),
        ]
        for record in records:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"] for other in records
            )
        winner = builder.r11_strict_bic_alias_winner(records, "NaMe~1", "parent")
        self.assertEqual(
            winner,
            {
                "actual_sha256": r11_hash("parent/Alpha")
            },
        )
        self.assertIs(
            builder._r11_lookup_record(
                records,
                "Alpha",
                requested_token="parent/Alpha",
                depth=4,
                parent_identity=r11_test_identity(),
                parent_token="parent",
            ),
            records[1],
        )
        with self.assertRaises(builder.R11TraversalDiagnostic) as wrong_case:
            builder._r11_lookup_record(
                records,
                "alpha",
                requested_token="parent/requested-alpha",
                depth=4,
                parent_identity=r11_test_identity(),
                parent_token="parent",
            )
        self.assertEqual(wrong_case.exception.code, "TRAVERSAL_COMPONENT_CASE_MISMATCH")
        self.assertEqual(
            wrong_case.exception.operands["path_token"],
            "parent/requested-alpha",
        )
        self.assertEqual(
            wrong_case.exception.record_proof.parent_token, "parent",
        )
        with self.assertRaises(builder.R11TraversalDiagnostic) as alias:
            builder._r11_lookup_record(
                records,
                "NaMe~1",
                requested_token="parent/requested-alias",
                depth=4,
                parent_identity=r11_test_identity(),
                parent_token="parent",
            )
        self.assertEqual(alias.exception.code, "TRAVERSAL_COMPONENT_SHORT_ALIAS")
        self.assertEqual(
            alias.exception.operands["path_token"],
            "parent/requested-alias",
        )
        self.assertEqual(alias.exception.operands["actual_attributes"], 1)
        collision_records = [
            r11_copied_record("Collision", "", 0x11),
            r11_copied_record("collision", "", 0x21),
        ]
        for record in collision_records:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"]
                for other in collision_records
            )
        root_record_diagnostic = builder._r11_record_backed_diagnostic(
            "TRAVERSAL_ROOT_ENTRY_COLLISION",
            "validate_root_entry",
            records=collision_records,
            winner=min(collision_records, key=lambda item: item["record_key"]),
            root=True,
            inventory=True,
            requested_depth=None,
            requested_token=None,
            parent_token="retained",
            parent_identity=r11_test_identity(),
        )
        self.assertEqual(
            (
                root_record_diagnostic.operands["component_index"],
                root_record_diagnostic.operands["path_token"],
            ),
            (0, None),
        )
        invalid_lookup_authorities = (
            (None, 4, "parent"),
            ("C:/native", 4, "parent"),
            ("parent/requested", None, "parent"),
            ("parent/requested", True, "parent"),
            ("parent/requested", 4, "C:/native"),
        )
        for requested_child, requested_depth, retained_parent in (
            invalid_lookup_authorities
        ):
            with self.subTest(
                requested_child=requested_child,
                requested_depth=requested_depth,
                retained_parent=retained_parent,
            ), self.assertRaises((TypeError, ValueError)):
                builder._r11_lookup_record(
                    records,
                    "Alpha",
                    requested_token=requested_child,
                    depth=requested_depth,
                    parent_identity=r11_test_identity(),
                    parent_token=retained_parent,
                )
        for requested_depth, requested_child in (
            (None, "retained/requested"),
            (0, None),
            (0, "retained/requested"),
        ):
            with self.subTest(
                root_depth=requested_depth,
                root_requested_child=requested_child,
            ), self.assertRaises(ValueError):
                builder._r11_record_backed_diagnostic(
                    "TRAVERSAL_ROOT_ENTRY_COLLISION",
                    "validate_root_entry",
                    records=collision_records,
                    winner=min(
                        collision_records,
                        key=lambda item: item["record_key"],
                    ),
                    root=True,
                    inventory=True,
                    requested_depth=requested_depth,
                    requested_token=requested_child,
                    parent_token="retained",
                    parent_identity=r11_test_identity(),
                )
        with self.assertRaises(ValueError):
            builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_COLLISION",
                "validate_inventory_entry",
                records=collision_records,
                winner=min(
                    collision_records, key=lambda item: item["record_key"],
                ),
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained/requested-child",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
        direct_bic_mutations = (
            {},
            {"actual_sha256": winner["actual_sha256"], "extra": None},
            {"actual_sha256": r11_hash("wrong")},
        )
        for candidate in direct_bic_mutations:
            with self.subTest(candidate=candidate), self.assertRaises(ValueError):
                builder.r11_validate_strict_bic(
                    records, "NaMe~1", "parent", candidate,
                )
        for dot in (".", ".."):
            dot_record = r11_copied_record(dot, "", 16)
            self.assertTrue(builder._r11_is_exact_dot_record(dot_record))
            lookalike = copy.deepcopy(dot_record)
            lookalike["raw_long"] = (
                lookalike["raw_long"][:-2] + b"\x01\x00"
            )
            self.assertFalse(builder._r11_is_exact_dot_record(lookalike))
            with self.assertRaises(ValueError):
                r11_literal_record_names(lookalike)
        for field, mutation in (
            ("raw_long", bytes(520)),
            ("raw_alt", bytes(28)),
            ("attributes", -1),
            ("record_key", b"wrong"),
            ("long_name", "Wrong"),
            ("alternate_name", "WRONG~1"),
            ("raw_ordinal", 99),
        ):
            changed = copy.deepcopy(records)
            changed[0][field] = mutation
            with self.subTest(field=field), self.assertRaises((ValueError, UnicodeError)):
                builder.r11_strict_bic_alias_winner(changed, "NaMe~1", "parent")

    def test_r11_07_diagnostic_schema_is_closed_and_path_free(self) -> None:
        for code in builder.R11_CANONICAL_DIAGNOSTICS:
            diagnostic = r11_complete_diagnostic(code)
            builder.r11_validate_diagnostic(diagnostic)
            self.assertEqual(
                tuple(diagnostic.operands),
                (
                    "operation", "component_index", "path_token", "winerror",
                    "expected_attributes", "actual_attributes", "identity_before",
                    "identity_after",
                ),
            )
            self.assertNotIn("C:\\", json.dumps(diagnostic.operands))
            for member in tuple(diagnostic.operands):
                changed = r11_complete_diagnostic(code)
                changed.operands.pop(member)
                with self.subTest(code=code, missing=member), self.assertRaises((TypeError, ValueError)):
                    builder.r11_validate_diagnostic(changed)
            extra = r11_complete_diagnostic(code)
            extra.operands["extra"] = 1
            with self.subTest(code=code, extra=True), self.assertRaises((TypeError, ValueError)):
                builder.r11_validate_diagnostic(extra)
            reordered = r11_complete_diagnostic(code)
            reordered.operands = dict(reversed(tuple(reordered.operands.items())))
            with self.subTest(code=code, reordered=True), self.assertRaises((TypeError, ValueError)):
                builder.r11_validate_diagnostic(reordered)
            invalid_members = {
                "operation": 1,
                "component_index": True,
                "path_token": "native\\path",
                "winerror": 0,
                "expected_attributes": -1,
                "actual_attributes": 0x1_0000_0000,
                "identity_before": {"volume_serial": "bad", "file_index": "bad"},
                "identity_after": {"volume_serial": "bad", "file_index": "bad"},
            }
            for member, invalid in invalid_members.items():
                changed = r11_complete_diagnostic(code)
                changed.operands[member] = invalid
                with self.subTest(code=code, invalid=member), self.assertRaises((TypeError, ValueError)):
                    builder.r11_validate_diagnostic(changed)
        operand_first = r11_complete_diagnostic(
            "TRAVERSAL_COMPONENT_CASE_MISMATCH",
        )
        operand_first.operands["operation"] = 1
        operand_first.record_proof = object()
        with self.assertRaisesRegex(ValueError, "diagnostic operation"):
            builder.r11_validate_diagnostic(operand_first)

    def test_r11_08_translation_constructor_availability_is_total(self) -> None:
        self.assertEqual(set(builder.R11_DIAGNOSTIC_CLASS), set(builder.R11_CANONICAL_DIAGNOSTICS))
        self.assertTrue(
            all(set(row) == set(builder.R11_BOUNDARY_IDS) for row in builder.R11_INDUCED_MATRIX.values())
        )
        self.assertIn("OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION", builder.R11_SERIALIZABLE_CODES)
        states = r11_boundary_states()
        for boundary, state in states.items():
            builder._r11_validate_boundary_state(boundary, copy.deepcopy(state))
            extra = copy.deepcopy(state)
            extra["extra"] = None
            with self.subTest(boundary=boundary, extra=True), self.assertRaises((TypeError, ValueError)):
                builder._r11_validate_boundary_state(boundary, extra)
            reordered = dict(reversed(tuple(copy.deepcopy(state).items())))
            if tuple(reordered) == tuple(state):
                self.assertEqual(len(state), 1)
                builder._r11_validate_boundary_state(boundary, reordered)
            else:
                with self.subTest(boundary=boundary, reordered=True), self.assertRaises((TypeError, ValueError)):
                    builder._r11_validate_boundary_state(boundary, reordered)
            for member in tuple(state):
                missing = copy.deepcopy(state)
                missing.pop(member)
                with self.subTest(boundary=boundary, missing=member), self.assertRaises((TypeError, ValueError)):
                    builder._r11_validate_boundary_state(boundary, missing)
                wrong = copy.deepcopy(state)
                wrong[member] = object()
                with self.subTest(boundary=boundary, wrong=member), self.assertRaises((TypeError, ValueError)):
                    builder._r11_validate_boundary_state(boundary, wrong)
        identity = r11_complete_diagnostic("TRAVERSAL_IDENTITY_CHANGED")
        state = copy.deepcopy(states["ARTIFACT_READ"])
        state["read_state"] = {
            "before_identity": copy.deepcopy(identity.operands["identity_before"]),
            "after_identity": copy.deepcopy(identity.operands["identity_after"]),
            "before_size": 7,
            "after_size": 7,
            "read_byte_count": 7,
        }
        afi = builder.r11_translate_diagnostic(identity, "ARTIFACT_READ", state)
        self.assertEqual(afi.first_red["code"], "ARTIFACT_FILE_IDENTITY_MISMATCH")
        size_change = r11_complete_diagnostic("TRAVERSAL_IDENTITY_CHANGED")
        size_change.operands["identity_after"] = copy.deepcopy(
            size_change.operands["identity_before"]
        )
        size_state = copy.deepcopy(state)
        size_state["read_state"]["after_identity"] = copy.deepcopy(
            size_state["read_state"]["before_identity"]
        )
        size_state["read_state"]["after_size"] = 8
        size_afi = builder.r11_translate_diagnostic(
            size_change, "ARTIFACT_READ", size_state,
        )
        self.assertEqual(
            size_afi.first_red["code"], "ARTIFACT_FILE_IDENTITY_MISMATCH",
        )
        unchanged_state = copy.deepcopy(size_state)
        unchanged_state["read_state"]["after_size"] = 7
        unchanged = builder.r11_translate_diagnostic(
            size_change, "ARTIFACT_READ", unchanged_state,
        )
        self.assertEqual(unchanged.first_red["code"], "ARTIFACT_FILE_READ")
        read_mutations: list[dict[str, Any]] = []
        for member in tuple(state["read_state"]):
            changed = copy.deepcopy(state)
            changed["read_state"][member] = None
            read_mutations.append(changed)
        missing = copy.deepcopy(state)
        missing["read_state"].pop("after_size")
        read_mutations.append(missing)
        extra = copy.deepcopy(state)
        extra["read_state"]["extra"] = 0
        read_mutations.append(extra)
        overflow = copy.deepcopy(state)
        overflow["read_state"]["read_byte_count"] = 9_007_199_254_740_992
        read_mutations.append(overflow)
        for changed in read_mutations:
            with self.assertRaises((TypeError, ValueError)):
                builder.r11_translate_diagnostic(
                    r11_complete_diagnostic("TRAVERSAL_IDENTITY_CHANGED"),
                    "ARTIFACT_READ",
                    changed,
                )
        inconsistent = copy.deepcopy(state)
        inconsistent["read_state"]["after_identity"] = r11_test_identity("0000000000000099")
        afr = builder.r11_translate_diagnostic(
            r11_complete_diagnostic("TRAVERSAL_IDENTITY_CHANGED"),
            "ARTIFACT_READ",
            inconsistent,
        )
        self.assertEqual(afr.first_red["code"], "ARTIFACT_FILE_READ")
        for actual_count, expected_code in (
            (0, "PORTABLE_INPUT_BUILD_INFO_COUNT"),
            (1, "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION"),
            (2, "PORTABLE_INPUT_BUILD_INFO_COUNT"),
        ):
            lookup_state = {
                "group_index": 0,
                "count_complete": True,
                "actual_count": actual_count,
            }
            translated = builder.r11_translate_diagnostic(
                r11_complete_diagnostic("TRAVERSAL_ENUM_OPEN"),
                "PORTABLE_BUILD_INFO_LOOKUP",
                lookup_state,
            )
            self.assertEqual(translated.first_red["code"], expected_code)

    def test_r11_09_journal_has_exact_guarded_states_and_four_key_latch(self) -> None:
        source = inspect.getsource(builder.ExecutionJournal.invoke)
        self.assertLess(source.index("START_PUBLISHING"), source.index("_r11_publish_preconstructed"))
        self.assertLess(source.index("CALL_OPEN"), source.index("_captured_subprocess"))
        self.assertIn('"start_event_sha256"', source)
        self.assertIn('self.guard = None', source)

    def test_r11_10_evidence_call_is_binary_and_completed_only(self) -> None:
        source = inspect.getsource(builder._captured_subprocess)
        self.assertEqual(source.count("subprocess.run("), 1)
        self.assertIn("subprocess.CompletedProcess", source)
        self.assertIn("capture_output=True", source)
        self.assertNotIn("text=", source)
        self.assertEqual(builder.CommandResult(True, 0, b"a", b"b").stdout, b"a")

    def test_r11_11_environment_evidence_is_hash_and_count_only(self) -> None:
        source = inspect.getsource(builder.ExecutionJournal.invoke)
        self.assertIn('"environment_sha256"', source)
        self.assertIn('"environment_entry_count"', source)
        event_literal = source[source.index("start_event ="):source.index("start_raw =")]
        self.assertNotIn('"environment":', event_literal)

    def test_r11_12_forge_version_priority_is_total(self) -> None:
        valid = R11ForgeFake.VERSION.encode("utf-8")
        cases = (
            (b"\xff", "FORGE_VERSION_UTF8"),
            (b"", "FORGE_VERSION_EMPTY"),
            (b" \r\n", "FORGE_VERSION_FORMAT"),
            (valid.replace(b"\n", b"\r\n"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"\n", b"\r", 1), "FORGE_VERSION_FORMAT"),
            (valid + b" ", "FORGE_VERSION_FORMAT"),
            (valid + b"\t", "FORGE_VERSION_FORMAT"),
            (b" " + valid, "FORGE_VERSION_FORMAT"),
            (b"\t" + valid, "FORGE_VERSION_FORMAT"),
            (valid + b"\n", "FORGE_VERSION_FORMAT"),
            (valid.replace(b"\n", b"\n\n", 1), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Commit SHA:", b"Commit SHA:\x01"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Commit SHA:", b"Commit:"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Build Profile:", b"Profile:"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Commit SHA: " + b"0" * 40 + b"\n", b""), "FORGE_VERSION_FORMAT"),
            (
                b"Commit SHA: " + b"0" * 40 + b"\n"
                + valid.split(b"\n", 1)[0] + b"\n"
                + b"\n".join(valid.split(b"\n")[2:]),
                "FORGE_VERSION_FORMAT",
            ),
            (valid + b"\nExtra: line", "FORGE_VERSION_FORMAT"),
            (valid.replace(b"forge Version: 1.7.1", b"forge Version: broken"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"0" * 40, b"0" * 39), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"0" * 40, b"A" * 40), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"0" * 40, b"g" * 40), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Build Timestamp: fixture", b"Build Timestamp: "), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Build Profile: release", b"Build Profile: bad profile"), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Build Timestamp: fixture\n", b""), "FORGE_VERSION_TIMESTAMP_COUNT"),
            (
                valid.replace(
                    b"Build Timestamp: fixture\n",
                    b"Build Timestamp: first\nBuild Timestamp: second\n",
                ),
                "FORGE_VERSION_TIMESTAMP_COUNT",
            ),
            (valid, "FORGE_VERSION_MISMATCH"),
        )
        for raw, code in cases:
            with self.subTest(code=code):
                failure = assert_r4_failure(self, code, builder.r11_validate_forge_version_bytes, raw)
                self.assertTrue(failure.operands)
        portable = R11ForgeFake().portable_version.encode("utf-8")
        digest = builder.sha256_bytes(portable)
        with patch.object(builder, "R11_FORGE_VERSION_IDENTITY_SHA256", digest):
            self.assertEqual(builder.r11_validate_forge_version_bytes(valid), R11ForgeFake().portable_version)
        pair_cases = (
            (b"\xff\r", "FORGE_VERSION_UTF8"),
            (b"\xff" + valid, "FORGE_VERSION_UTF8"),
            (valid.replace(b"\n", b"\r\n").replace(b"Build Timestamp: fixture\r\n", b""), "FORGE_VERSION_FORMAT"),
            (valid.replace(b"Build Timestamp: fixture\n", b"") + b" ", "FORGE_VERSION_FORMAT"),
            (
                valid.replace(
                    b"Build Timestamp: fixture\n",
                    b"Build Timestamp: first\nBuild Timestamp: second\n",
                ).replace(b"0" * 40, b"1" * 40),
                "FORGE_VERSION_TIMESTAMP_COUNT",
            ),
        )
        for raw, code in pair_cases:
            with self.subTest(pair=code):
                assert_r4_failure(self, code, builder.r11_validate_forge_version_bytes, raw)

    def test_r11_13_target_state_is_exact_14_fields_and_19_records(self) -> None:
        records = builder.r11_default_target_evaluations()
        self.assertEqual(
            tuple(
                tuple(r11_freeze(record[key]) for key in R11_LITERAL_TARGET_STATE_KEYS)
                for record in records
            ),
            R11_LITERAL_TARGET_STATE_ROWS,
        )
        self.assertEqual(
            tuple(r11_freeze(authority) for authority in builder.R4_TARGET_AUTHORITIES),
            tuple(r11_freeze(r11_literal_authority(index)) for index in range(19)),
        )
        initial = r11_literal_initial_results()
        builder._r11_validate_result_state(initial)
        literal_terminal = r11_literal_staged_nogo_terminal(
            r11_literal_complete_results(installed=False),
            label="target-state",
        )
        builder.r11_validate_builder_terminal(literal_terminal)
        first_metadata_target_index = 3
        self.assertEqual(
            R11_LITERAL_TARGET_STATE_ROWS[first_metadata_target_index][:5],
            (
                "CompatibilityState",
                "StreamArtistArchiveCompatibilityStateV3Skeleton",
                "smart-contracts/architecture/issue670/StreamArtistArchiveCompatibilityStateV3Skeleton.sol",
                4,
                "000",
            ),
        )
        accepted_metadata_prefix_ids: list[int] = []
        terminal_metadata_reversal_ids: list[int] = []

        def reverse_durable_mappings(value: Any) -> Any:
            if isinstance(value, dict):
                return dict(reversed(tuple(
                    (
                        key,
                        reverse_durable_mappings(member),
                    )
                    for key, member in value.items()
                )))
            if isinstance(value, list):
                return [reverse_durable_mappings(member) for member in value]
            return copy.deepcopy(value)

        fully_reordered_terminal = reverse_durable_mappings(literal_terminal)
        builder.r11_validate_builder_terminal(fully_reordered_terminal)
        self.assertEqual(
            builder.canonical_evidence_bytes(fully_reordered_terminal),
            builder.canonical_evidence_bytes(literal_terminal),
        )

        def assert_full_target_member_rejects(
            target_index: int,
            member: str,
            mutation_kind: str,
            replacement: Any = None,
        ) -> None:
            terminal_mutation = copy.deepcopy(literal_terminal)
            record = terminal_mutation["results"]["target_evaluations"][
                target_index
            ]
            if mutation_kind == "missing":
                record.pop(member)
            elif mutation_kind == "extra":
                record["_extra"] = None
            elif mutation_kind == "wrong-major":
                terminal_baseline = copy.deepcopy(record[member])
                terminal_replacement = wrong_major(terminal_baseline)
                self.assertIsNot(
                    type(terminal_replacement),
                    type(terminal_baseline),
                    (target_index, member, mutation_kind),
                )
                self.assertNotEqual(
                    terminal_replacement,
                    terminal_baseline,
                    (target_index, member, mutation_kind),
                )
                record[member] = terminal_replacement
            elif mutation_kind == "same-type":
                terminal_baseline = copy.deepcopy(record[member])
                if member == "artifact_byte_count":
                    self.assertIs(type(terminal_baseline), int)
                    terminal_replacement = -1
                else:
                    terminal_replacement = wrong_same_type(terminal_baseline)
                self.assertIs(
                    type(terminal_replacement),
                    type(terminal_baseline),
                    (target_index, member, mutation_kind),
                )
                self.assertNotEqual(
                    terminal_replacement,
                    terminal_baseline,
                    (target_index, member, mutation_kind),
                )
                record[member] = terminal_replacement
            else:
                record[member] = copy.deepcopy(replacement)
            with (
                patch.object(
                    builder, "_r11_publish_preconstructed",
                ) as rejected_publication,
                self.assertRaises(
                    (builder.EvidenceFailure, TypeError, ValueError),
                ),
            ):
                builder.r11_validate_builder_terminal(terminal_mutation)
            rejected_publication.assert_not_called()
            if (
                mutation_kind == "same-type"
                and member == "metadata_evaluated"
            ):
                terminal_metadata_reversal_ids.append(target_index)

        def wrong_major(value: Any) -> Any:
            if type(value) is bool:
                return 0
            if type(value) is int:
                return "0"
            if isinstance(value, str):
                return {}
            if isinstance(value, list):
                return {}
            if value is None:
                return -1
            raise AssertionError("unlisted target-state type")

        def wrong_same_type(value: Any) -> Any:
            if type(value) is bool:
                return not value
            if type(value) is int:
                return value + 1
            if isinstance(value, str):
                return value + "-wrong"
            if isinstance(value, list):
                return [None]
            if value is None:
                return 0
            raise AssertionError("unlisted target-state type")

        for target_index in range(19):
            for member in R11_LITERAL_TARGET_STATE_KEYS:
                missing = copy.deepcopy(initial)
                missing["target_evaluations"][target_index].pop(member)
                with self.subTest(target=target_index, missing=member), self.assertRaises(builder.EvidenceFailure):
                    builder._r11_validate_result_state(missing)
                assert_full_target_member_rejects(
                    target_index, member, "missing",
                )
                wrong = copy.deepcopy(initial)
                wrong["target_evaluations"][target_index][member] = object()
                with self.subTest(target=target_index, wrong=member), self.assertRaises((builder.EvidenceFailure, TypeError)):
                    builder._r11_validate_result_state(wrong)
                assert_full_target_member_rejects(
                    target_index, member, "wrong", object(),
                )
                for mutation_kind, replacement in (
                    ("wrong-major", wrong_major(initial["target_evaluations"][target_index][member])),
                    ("same-type", wrong_same_type(initial["target_evaluations"][target_index][member])),
                    (
                        "cross-row",
                        initial["target_evaluations"][(target_index + 1) % 19][member],
                    ),
                ):
                    if replacement == initial["target_evaluations"][target_index][member]:
                        continue
                    changed = copy.deepcopy(initial)
                    changed["target_evaluations"][target_index][member] = replacement
                    if (
                        target_index == first_metadata_target_index
                        and member == "metadata_evaluated"
                        and mutation_kind == "same-type"
                        and replacement is True
                    ):
                        expected_next = copy.deepcopy(initial)
                        expected_next["target_evaluations"][
                            first_metadata_target_index
                        ][
                            "metadata_evaluated"
                        ] = True
                        builder._r11_validate_result_state(changed)
                        self.assertEqual(changed, expected_next)
                        accepted_metadata_prefix_ids.append(target_index)
                        continue
                    with self.subTest(
                        target=target_index,
                        member=member,
                        mutation=mutation_kind,
                    ), self.assertRaises((builder.EvidenceFailure, TypeError)):
                        builder._r11_validate_result_state(changed)
                    assert_full_target_member_rejects(
                        target_index, member, mutation_kind, replacement,
                    )
                if initial["target_evaluations"][target_index][member] is not None:
                    null_member = copy.deepcopy(initial)
                    null_member["target_evaluations"][target_index][member] = None
                    with self.subTest(
                        target=target_index, member=member, mutation="null",
                    ), self.assertRaises((builder.EvidenceFailure, TypeError)):
                        builder._r11_validate_result_state(null_member)
                    assert_full_target_member_rejects(
                        target_index, member, "null", None,
                    )
            extra = copy.deepcopy(initial)
            extra["target_evaluations"][target_index]["extra"] = None
            with self.subTest(target=target_index, extra=True), self.assertRaises(builder.EvidenceFailure):
                builder._r11_validate_result_state(extra)
            assert_full_target_member_rejects(
                target_index, "semantic_id", "extra",
            )
            non_string = copy.deepcopy(initial)
            non_string["target_evaluations"][target_index][1] = None
            with self.subTest(
                target=target_index, non_string_key=True,
            ), self.assertRaises(builder.EvidenceFailure):
                builder._r11_validate_result_state(non_string)
            reordered = copy.deepcopy(initial)
            reordered["target_evaluations"][target_index] = dict(
                reversed(tuple(reordered["target_evaluations"][target_index].items()))
            )
            with self.subTest(target=target_index, reordered=True):
                builder._r11_validate_result_state(reordered)
            self.assertEqual(
                builder.canonical_evidence_bytes(reordered),
                builder.canonical_evidence_bytes(initial),
            )
            reordered_terminal = copy.deepcopy(literal_terminal)
            reordered_terminal["results"]["target_evaluations"][
                target_index
            ] = dict(reversed(tuple(
                reordered_terminal["results"]["target_evaluations"][
                    target_index
                ].items()
            )))
            builder.r11_validate_builder_terminal(reordered_terminal)
            self.assertEqual(
                builder.canonical_evidence_bytes(reordered_terminal),
                builder.canonical_evidence_bytes(literal_terminal),
            )

        self.assertEqual(
            accepted_metadata_prefix_ids,
            [first_metadata_target_index],
        )
        complete_state_reversal = copy.deepcopy(literal_terminal)
        complete_state_reversal["results"]["target_evaluations"][
            first_metadata_target_index
        ]["metadata_evaluated"] = False
        with (
            patch.object(
                builder, "_r11_publish_preconstructed",
            ) as rejected_complete_reversal,
            self.assertRaises(builder.EvidenceFailure),
        ):
            builder.r11_validate_builder_terminal(complete_state_reversal)
        rejected_complete_reversal.assert_not_called()
        terminal_metadata_reversal_ids.append(first_metadata_target_index)
        self.assertEqual(
            sorted(terminal_metadata_reversal_ids),
            list(range(19)),
        )
        self.assertEqual(len(set(terminal_metadata_reversal_ids)), 19)

        literal_authorities = tuple(
            r11_literal_authority(index) for index in range(19)
        )

        def require_literal_authority(
            position: int,
            candidate: dict[str, Any],
        ) -> None:
            if r11_freeze(candidate) != r11_freeze(
                literal_authorities[position],
            ):
                raise AssertionError("target constructor/cap join is not literal")

        authority_fields = (
            "semantic_id", "target", "source", "signature", "input_types",
            "words", "bytes", "runtime_cap",
        )
        for position, literal_authority in enumerate(literal_authorities):
            require_literal_authority(
                position, dict(builder.R4_TARGET_AUTHORITIES[position]),
            )
            for field in authority_fields:
                value = literal_authority[field]
                if isinstance(value, tuple):
                    wrong_type = {}
                    same_type = value + ("uint256",)
                else:
                    wrong_type = wrong_major(value)
                    same_type = wrong_same_type(value)
                cross_value = literal_authorities[(position + 1) % 19][field]
                for mutation_kind, replacement in (
                    ("null", None),
                    ("wrong-major", wrong_type),
                    ("same-type", same_type),
                    ("cross-row", cross_value),
                ):
                    if replacement == value:
                        continue
                    changed_authority = dict(literal_authority)
                    changed_authority[field] = replacement
                    with self.subTest(
                        authority_row=position + 1,
                        field=field,
                        mutation=mutation_kind,
                    ), self.assertRaises(AssertionError):
                        require_literal_authority(position, changed_authority)
                    authority_terminal = copy.deepcopy(literal_terminal)
                    evaluation = authority_terminal["results"][
                        "target_evaluations"
                    ][position]
                    artifact_row = authority_terminal["results"]["artifacts"][
                        position
                    ]
                    authority_trace = evaluation["bytecode_steps"]
                    if field in ("semantic_id", "target", "source"):
                        evaluation[field] = copy.deepcopy(replacement)
                    elif field == "signature":
                        artifact_row["constructor_signature"] = copy.deepcopy(
                            replacement
                        )
                    elif field == "input_types":
                        authority_trace[16]["operands"]["expected_types"] = (
                            copy.deepcopy(replacement)
                        )
                    elif field == "words":
                        artifact_row["constructor_words"] = copy.deepcopy(
                            replacement
                        )
                    elif field == "bytes":
                        artifact_row["constructor_bytes"] = copy.deepcopy(
                            replacement
                        )
                    else:
                        artifact_row["runtime_cap"] = copy.deepcopy(replacement)
                    with (
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as authority_publication,
                        self.assertRaises(
                            (builder.EvidenceFailure, TypeError, ValueError),
                        ),
                    ):
                        builder.r11_validate_builder_terminal(
                            authority_terminal,
                        )
                    authority_publication.assert_not_called()
                    if field not in ("semantic_id", "source"):
                        with self.assertRaises(
                            (builder.EvidenceFailure, TypeError, ValueError),
                        ):
                            builder._r11_validate_trace(
                                r11_literal_pass_trace(literal_authority),
                                changed_authority,
                                completed=True,
                            )

        def target_array_variant(
            baseline: list[dict[str, Any]], mutation_id: str,
        ) -> list[Any]:
            changed: list[Any] = copy.deepcopy(baseline)
            if mutation_id == "empty":
                return []
            if mutation_id.startswith("truncate:"):
                changed.pop(int(mutation_id.split(":", 1)[1]))
            elif mutation_id == "append":
                changed.append({})
            elif mutation_id == "prepend":
                changed.insert(0, {})
            elif mutation_id == "reverse":
                changed.reverse()
            elif mutation_id.startswith("duplicate:"):
                duplicate_at = int(mutation_id.split(":", 1)[1])
                changed.insert(duplicate_at, copy.deepcopy(changed[duplicate_at]))
            elif mutation_id == "adjacent-swap":
                changed[0], changed[1] = changed[1], changed[0]
            elif mutation_id == "group-016-permutation":
                changed[14], changed[16], changed[17] = (
                    changed[16], changed[17], changed[14],
                )
            elif mutation_id == "duplicate-ordinal":
                changed[1]["size_ordinal"] = 1
            elif mutation_id == "wrong-element-type":
                changed[9] = 1
            elif mutation_id == "null-element":
                changed[9] = None
            elif mutation_id == "cross-target-element":
                changed[9] = copy.deepcopy(changed[10])
            else:
                raise AssertionError(f"unknown target array mutation {mutation_id}")
            return changed

        target_array_mutation_ids = (
            "empty", "truncate:0", "truncate:9", "truncate:18",
            "append", "prepend", "reverse", "adjacent-swap",
            "duplicate:0", "duplicate:9", "duplicate:18",
            "wrong-element-type", "null-element", "cross-target-element",
            "group-016-permutation", "duplicate-ordinal",
        )
        for mutation_id in target_array_mutation_ids:
            targets = target_array_variant(
                initial["target_evaluations"], mutation_id,
            )
            changed = copy.deepcopy(initial)
            changed["target_evaluations"] = targets
            with self.subTest(target_array=mutation_id), self.assertRaises(
                (builder.EvidenceFailure, TypeError),
            ):
                builder._r11_validate_result_state(changed)
            terminal_mutation = copy.deepcopy(literal_terminal)
            terminal_mutation["results"]["target_evaluations"] = (
                target_array_variant(
                    literal_terminal["results"]["target_evaluations"],
                    mutation_id,
                )
            )
            with (
                patch.object(
                    builder, "_r11_publish_preconstructed",
                ) as rejected_publication,
                self.assertRaises(
                    (builder.EvidenceFailure, TypeError, ValueError),
                ),
            ):
                builder.r11_validate_builder_terminal(terminal_mutation)
            rejected_publication.assert_not_called()

    def test_r11_14_bytecode_trace_is_exact_26_rows_and_target_free_results(self) -> None:
        authority = dict(R11_LITERAL_STORE_AUTHORITY)
        result = builder.validate_ordered_bytecode(r4_bytecode_artifact(authority), authority)
        trace = result["bytecode_steps"]
        builder._r11_validate_trace(trace, authority, completed=True)
        for link_index in (7, 15):
            link_operands = trace[link_index]["operands"]
            self.assertEqual(
                tuple(link_operands),
                ("target", "present", "actual_type", "entry_count"),
            )
            self.assertNotIn("length", link_operands)
            self.assertNotIn("sha256", link_operands)
        literal_terminal = r11_literal_staged_nogo_terminal(
            r11_literal_complete_results(installed=False),
            label="trace-schema",
        )
        builder.r11_validate_builder_terminal(literal_terminal)

        def validate_rejected_trace(
            mutation: list[dict[str, Any]],
            selected_authority: dict[str, Any],
            *,
            completed: bool,
        ) -> None:
            direct_failure: BaseException | None = None
            try:
                builder._r11_validate_trace(
                    mutation, selected_authority, completed=completed,
                )
            except (builder.EvidenceFailure, TypeError, ValueError) as error:
                direct_failure = error
            if direct_failure is None:
                raise AssertionError("trace mutation reached the direct validator")
            terminal_mutation = copy.deepcopy(literal_terminal)
            evaluation = terminal_mutation["results"]["target_evaluations"][0]
            evaluation["bytecode_steps"] = copy.deepcopy(mutation)
            evaluation["bytecode_completed"] = completed
            with patch.object(
                builder, "_r11_publish_preconstructed",
            ) as rejected_publication:
                try:
                    builder.r11_validate_builder_terminal(terminal_mutation)
                except (builder.EvidenceFailure, TypeError, ValueError):
                    pass
                else:
                    raise AssertionError("trace mutation reached terminal acceptance")
            rejected_publication.assert_not_called()
            raise direct_failure

        def validate_reordered_trace(
            mutation: list[dict[str, Any]],
        ) -> None:
            builder._r11_validate_trace(
                mutation, authority, completed=True,
            )
            terminal_mutation = copy.deepcopy(literal_terminal)
            terminal_mutation["results"]["target_evaluations"][0][
                "bytecode_steps"
            ] = copy.deepcopy(mutation)
            builder.r11_validate_builder_terminal(terminal_mutation)
            self.assertEqual(
                builder.canonical_evidence_bytes(mutation),
                builder.canonical_evidence_bytes(trace),
            )
            self.assertEqual(
                builder.canonical_evidence_bytes(terminal_mutation),
                builder.canonical_evidence_bytes(literal_terminal),
            )
        self.assertEqual(
            tuple(
                (
                    step["ordinal"], step["id"], step["kind"], step["status"],
                    r11_freeze(step["operands"]), r11_freeze(step["result"]),
                    step["error_code"],
                )
                for step in trace
            ),
            R11_LITERAL_STORE_TRACE_ROWS,
        )
        self.assertNotIn("target", trace[20]["result"])
        self.assertNotIn("target", trace[25]["result"])
        for index, step in enumerate(trace):
            literal_row = R11_LITERAL_STORE_TRACE_ROWS[index]
            for key in (
                "ordinal", "id", "kind", "status", "operands", "result",
                "error_code",
            ):
                mutation = copy.deepcopy(trace)
                mutation[index].pop(key)
                with self.subTest(step=index + 1, missing=key), self.assertRaises(builder.EvidenceFailure):
                    validate_rejected_trace(mutation, authority, completed=True)
            extra = copy.deepcopy(trace)
            extra[index]["extra"] = None
            with self.subTest(step=index + 1, extra=True), self.assertRaises(builder.EvidenceFailure):
                validate_rejected_trace(extra, authority, completed=True)
            for operand, _literal_value in literal_row[4]:
                mutation = copy.deepcopy(trace)
                mutation[index]["operands"].pop(operand)
                with self.subTest(step=index + 1, operand=operand), self.assertRaises(builder.EvidenceFailure):
                    validate_rejected_trace(mutation, authority, completed=True)
                wrong = copy.deepcopy(trace)
                wrong[index]["operands"][operand] = object()
                with self.subTest(step=index + 1, wrong_operand=operand), self.assertRaises((builder.EvidenceFailure, TypeError)):
                    validate_rejected_trace(wrong, authority, completed=True)
                null = copy.deepcopy(trace)
                null[index]["operands"][operand] = None
                with self.subTest(step=index + 1, null_operand=operand), self.assertRaises((builder.EvidenceFailure, TypeError)):
                    validate_rejected_trace(null, authority, completed=True)
            extra_operand = copy.deepcopy(trace)
            extra_operand[index]["operands"]["extra"] = None
            with self.subTest(step=index + 1, extra_operand=True), self.assertRaises(builder.EvidenceFailure):
                validate_rejected_trace(extra_operand, authority, completed=True)
            status = copy.deepcopy(trace)
            status[index]["status"] = "unknown"
            with self.subTest(step=index + 1, status=True), self.assertRaises(builder.EvidenceFailure):
                validate_rejected_trace(status, authority, completed=True)
            if isinstance(literal_row[5], tuple):
                for result_key, _literal_value in literal_row[5]:
                    mutation = copy.deepcopy(trace)
                    mutation[index]["result"].pop(result_key)
                    with self.subTest(step=index + 1, result=result_key), self.assertRaises(builder.EvidenceFailure):
                        validate_rejected_trace(mutation, authority, completed=True)
                    wrong = copy.deepcopy(trace)
                    wrong[index]["result"][result_key] = object()
                    with self.subTest(step=index + 1, wrong_result=result_key), self.assertRaises((builder.EvidenceFailure, TypeError)):
                        validate_rejected_trace(wrong, authority, completed=True)
                    null = copy.deepcopy(trace)
                    null[index]["result"][result_key] = None
                    with self.subTest(step=index + 1, null_result=result_key), self.assertRaises((builder.EvidenceFailure, TypeError)):
                        validate_rejected_trace(null, authority, completed=True)
                extra_result = copy.deepcopy(trace)
                extra_result[index]["result"]["extra"] = None
                with self.subTest(step=index + 1, extra_result=True), self.assertRaises(builder.EvidenceFailure):
                    validate_rejected_trace(extra_result, authority, completed=True)
        self.assertEqual(
            tuple(
                (ordinal, tuple(codes))
                for ordinal, codes in builder.R11_BYTECODE_FALSE_CODES.items()
            ),
            R11_LITERAL_BYTECODE_FALSE_ROWS,
        )
        for ordinal, codes in R11_LITERAL_BYTECODE_FALSE_ROWS:
            for priority, code in enumerate(codes):
                self.assertEqual(code in builder.R11_SERIALIZABLE_CODES, True)
                self.assertEqual(codes.index(code), priority)

        def trace_wrong_major(value: Any) -> Any:
            if type(value) is bool:
                return 0
            if type(value) is int:
                return "0"
            if isinstance(value, str):
                return {}
            if isinstance(value, dict):
                return []
            if isinstance(value, list):
                return {}
            if value is None:
                return 0
            raise AssertionError("unlisted trace major type")

        def trace_same_type_wrong(value: Any) -> Any:
            if type(value) is bool:
                return not value
            if type(value) is int:
                return value + 1
            if isinstance(value, str):
                return value + "-wrong"
            if isinstance(value, dict):
                return {**value, "_extra": None}
            if isinstance(value, list):
                return value + [None]
            if value is None:
                return 0
            raise AssertionError("unlisted trace type")

        trace_mutations: list[tuple[str, list[dict[str, Any]], bool]] = []
        trace_reorders: list[tuple[str, list[dict[str, Any]]]] = []
        row_keys = (
            "ordinal", "id", "kind", "status", "operands", "result",
            "error_code",
        )
        for index, row in enumerate(trace):
            reordered_row = copy.deepcopy(trace)
            reordered_row[index] = dict(
                reversed(tuple(reordered_row[index].items())),
            )
            trace_reorders.append((f"row:{index + 1}:reorder", reordered_row))
            reordered_operands = copy.deepcopy(trace)
            reordered_operands[index]["operands"] = dict(
                reversed(tuple(reordered_operands[index]["operands"].items())),
            )
            trace_reorders.append((
                f"row:{index + 1}:operands-reorder", reordered_operands,
            ))
            if isinstance(row["result"], dict):
                reordered_result = copy.deepcopy(trace)
                reordered_result[index]["result"] = dict(
                    reversed(tuple(reordered_result[index]["result"].items())),
                )
                trace_reorders.append((
                    f"row:{index + 1}:result-reorder", reordered_result,
                ))
            non_string_row = copy.deepcopy(trace)
            non_string_row[index][1] = None
            trace_mutations.append((
                f"row:{index + 1}:non-string-key", non_string_row, True,
            ))
            non_string_operands = copy.deepcopy(trace)
            non_string_operands[index]["operands"][1] = None
            trace_mutations.append((
                f"row:{index + 1}:operands-non-string-key",
                non_string_operands,
                True,
            ))
            if isinstance(row["result"], dict):
                non_string_result = copy.deepcopy(trace)
                non_string_result[index]["result"][1] = None
                trace_mutations.append((
                    f"row:{index + 1}:result-non-string-key",
                    non_string_result,
                    True,
                ))
            for key in row_keys:
                wrong_major_row = copy.deepcopy(trace)
                wrong_major_row[index][key] = trace_wrong_major(row[key])
                trace_mutations.append((f"row:{index + 1}:{key}:wrong-major", wrong_major_row, True))
                same_type_row = copy.deepcopy(trace)
                same_type_row[index][key] = trace_same_type_wrong(row[key])
                trace_mutations.append((f"row:{index + 1}:{key}:same-type", same_type_row, True))
                if row[key] is not None:
                    null_row = copy.deepcopy(trace)
                    null_row[index][key] = None
                    trace_mutations.append((f"row:{index + 1}:{key}:null", null_row, True))
            for container_name in ("operands", "result"):
                container = row[container_name]
                if not isinstance(container, dict):
                    continue
                for key, value in container.items():
                    wrong_major_member = copy.deepcopy(trace)
                    wrong_major_member[index][container_name][key] = trace_wrong_major(value)
                    trace_mutations.append((
                        f"row:{index + 1}:{container_name}:{key}:wrong-major",
                        wrong_major_member,
                        True,
                    ))
                    same_type_member = copy.deepcopy(trace)
                    same_type_member[index][container_name][key] = trace_same_type_wrong(value)
                    trace_mutations.append((
                        f"row:{index + 1}:{container_name}:{key}:same-type",
                        same_type_member,
                        True,
                    ))
                    if value is not None:
                        null_member = copy.deepcopy(trace)
                        null_member[index][container_name][key] = None
                        trace_mutations.append((
                            f"row:{index + 1}:{container_name}:{key}:null",
                            null_member,
                            True,
                        ))
                    if isinstance(value, list):
                        middle = len(value) // 2
                        last = len(value) - 1
                        array_variants: list[tuple[str, list[Any]]] = [
                            ("empty", []),
                        ]
                        for label, array_position in (
                            ("first", 0),
                            ("middle", middle),
                            ("last", last),
                        ):
                            truncated = copy.deepcopy(value)
                            truncated.pop(array_position)
                            array_variants.append((
                                f"truncate-{label}", truncated,
                            ))
                            duplicated = copy.deepcopy(value)
                            duplicated.insert(
                                array_position,
                                copy.deepcopy(duplicated[array_position]),
                            )
                            array_variants.append((
                                f"duplicate-{label}", duplicated,
                            ))
                        array_variants.extend((
                            ("append", value + ["address"]),
                            ("prepend", ["address"] + value),
                            ("reverse", list(reversed(value))),
                            (
                                "adjacent-swap",
                                [value[1], value[0], *value[2:]],
                            ),
                            (
                                "same-members-wrong-order",
                                [*value[1:], value[0]],
                            ),
                            (
                                "wrong-element-type",
                                [*value[:middle], {}, *value[middle + 1:]],
                            ),
                            (
                                "null-element",
                                [*value[:middle], None, *value[middle + 1:]],
                            ),
                            (
                                "cross-target-element",
                                [*value[:middle], "uint256", *value[middle + 1:]],
                            ),
                            ("extra-element", [*value, "bytes32"]),
                        ))
                        for array_id, array_value in array_variants:
                            array_member = copy.deepcopy(trace)
                            array_member[index][container_name][key] = array_value
                            trace_mutations.append((
                                f"row:{index + 1}:{container_name}:{key}:array-{array_id}",
                                array_member,
                                True,
                            ))
            for delta in (-1, 1):
                ordinal_mutation = copy.deepcopy(trace)
                ordinal_mutation[index]["ordinal"] = row["ordinal"] + delta
                trace_mutations.append((f"row:{index + 1}:ordinal:{delta}", ordinal_mutation, True))
            adjacent_id = copy.deepcopy(trace)
            adjacent_id[index]["id"] = R4_BYTECODE_STEP_IDS[
                index - 1 if index else 1
            ]
            trace_mutations.append((f"row:{index + 1}:adjacent-id", adjacent_id, True))
            illegal_tuple = copy.deepcopy(trace)
            illegal_tuple[index]["kind"] = (
                "operation" if row["kind"] == "predicate" else "predicate"
            )
            illegal_tuple[index]["status"] = "exception"
            illegal_tuple[index]["result"] = None
            illegal_tuple[index]["error_code"] = "OP_ILLEGAL_EXCEPTION"
            trace_mutations.append((f"row:{index + 1}:illegal-tuple", illegal_tuple, True))
            if index < 25:
                failed_then_later = copy.deepcopy(trace[:index + 2])
                failed_then_later[index]["status"] = (
                    "false" if row["kind"] == "predicate" else "exception"
                )
                failed_then_later[index]["result"] = (
                    False if row["kind"] == "predicate" else None
                )
                failed_then_later[index]["error_code"] = (
                    next(
                        (
                            codes[0] for ordinal, codes
                            in R11_LITERAL_BYTECODE_FALSE_ROWS
                            if ordinal == index + 1
                        ),
                        f"OP_{row['id']}_EXCEPTION",
                    )
                )
                trace_mutations.append((
                    f"row:{index + 1}:later-after-red",
                    failed_then_later,
                    False,
                ))
        with (
            patch.object(builder, "_r11_publish_preconstructed") as trace_publish,
            patch.object(builder, "publish_json_no_replace") as trace_legacy,
        ):
            for mutation_id, mutation in trace_reorders:
                with self.subTest(trace_reorder=mutation_id):
                    validate_reordered_trace(mutation)
            for mutation_id, mutation, completed in trace_mutations:
                with self.subTest(trace_mutation=mutation_id), self.assertRaises(
                    (builder.EvidenceFailure, TypeError, ValueError),
                ):
                    validate_rejected_trace(
                        mutation, authority, completed=completed,
                    )
        trace_publish.assert_not_called()
        trace_legacy.assert_not_called()

    def test_r11_15_metadata_schedule_is_items_one_through_eleven(self) -> None:
        source = inspect.getsource(builder._r11_metadata_and_bindings)
        for item in range(2, 12):
            self.assertIn(f"authority, {item},", source)
        build_source = inspect.getsource(builder._build_release_output_evidence_r11)
        self.assertLess(build_source.index('evaluation["metadata_evaluated"] = True'), build_source.index("r11_native_read("))
        self.assertLess(build_source.index('evaluation["metadata_admitted"] = True'), build_source.index('evaluation["bytecode_evaluated"] = True'))

    def test_r11_16_group_and_union_authorities_remain_exact(self) -> None:
        builder.validate_r4_authority_constants()
        self.assertEqual([group["group"] for group in builder.R4_GROUPS], [f"{index:03d}" for index in range(17)])
        self.assertEqual(builder.R4_SOURCE_AGGREGATE_SHA256, "1EB0A58B8A1DCA624493839D41FA5267078E7FBA67B4AE6DF9205DD003659857")

    def test_r11_17_aggregate_schedule_is_interleaved_and_exact_eleven(self) -> None:
        self.assertEqual(tuple(builder.R4_AGGREGATE_GATES), (3, 7, 8, 11))
        self.assertEqual(sum(len(rows) for rows in builder.R4_AGGREGATE_GATES.values()), 11)
        members = builder.R4_AGGREGATE_GATES[11][0][1]
        self.assertEqual(members, ("Transition", "Proposal", "Collaborator"))

    def test_r11_18_terminal_gate_reconstructs_disk_before_go_last(self) -> None:
        self.assertEqual(
            builder._r11_key_authority("z", "a", "middle"),
            ("a", "middle", "z"),
        )
        with self.assertRaises(ValueError):
            builder._r11_key_authority("duplicate", "duplicate")
        with self.assertRaises(TypeError):
            builder._r11_key_authority("string", 1)
        source = inspect.getsource(builder.ExecutionJournal.publish_terminal)
        self.assertLess(source.index("_candidate_terminal_gate"), source.index('self.state = "TERMINAL"'))
        self.assertLess(source.index('self.state = "TERMINAL"'), source.index('_r11_publish_preconstructed'))
        self.assertLess(
            source.index('_r11_publish_preconstructed'),
            source.index('authority.close(primary)'),
        )
        build_source = inspect.getsource(
            builder._build_release_output_evidence_r11,
        )
        self.assertLess(
            build_source.index('_lock.executable_leases.revalidate'),
            build_source.index('_r11_install_output_no_replace'),
        )
        gate = inspect.getsource(builder.ExecutionJournal._candidate_terminal_gate)
        self.assertIn("R11RetainedTree", gate)
        self.assertIn("_disk_prefix", gate)
        terminal = r11_builder_nogo_terminal()
        builder.r11_validate_builder_terminal(terminal)

        def reverse_durable_mappings(value: Any) -> Any:
            if isinstance(value, dict):
                return dict(reversed(tuple(
                    (
                        key,
                        reverse_durable_mappings(member),
                    )
                    for key, member in value.items()
                )))
            if isinstance(value, list):
                return [reverse_durable_mappings(member) for member in value]
            return copy.deepcopy(value)

        reordered_terminal = reverse_durable_mappings(terminal)
        builder.r11_validate_builder_terminal(reordered_terminal)
        self.assertEqual(
            builder.canonical_evidence_bytes(reordered_terminal),
            builder.canonical_evidence_bytes(terminal),
        )
        top_mutations: list[dict[str, Any]] = []
        for key in tuple(terminal):
            missing = copy.deepcopy(terminal)
            missing.pop(key)
            top_mutations.append(missing)
        extra = copy.deepcopy(terminal)
        extra["extra"] = None
        top_mutations.append(extra)
        non_string = copy.deepcopy(terminal)
        non_string[1] = None
        top_mutations.append(non_string)
        for mapping_path in (
            ("results",),
            ("first_red",),
            ("first_red", "operands"),
            ("calls", 0),
            ("checkpoints", 0),
            ("checkpoints", 0, "forge"),
            ("checkpoints", 0, "forge", "identity"),
        ):
            non_string_nested = copy.deepcopy(terminal)
            selected: Any = non_string_nested
            for member in mapping_path:
                selected = selected[member]
            selected[1] = None
            top_mutations.append(non_string_nested)
        reordered_checkpoint_array = copy.deepcopy(terminal)
        reordered_checkpoint_array["checkpoints"].reverse()
        top_mutations.append(reordered_checkpoint_array)
        for mutation in top_mutations:
            with self.assertRaises(builder.EvidenceFailure):
                builder.r11_validate_builder_terminal(mutation)
        for key in builder.R11_FIRST_RED_KEYS:
            mutation = copy.deepcopy(terminal)
            mutation["first_red"].pop(key)
            with self.subTest(first_red_key=key), self.assertRaises(builder.EvidenceFailure):
                builder.r11_validate_builder_terminal(mutation)
        for key in builder.R11_RESULT_KEYS:
            mutation = copy.deepcopy(terminal)
            mutation["results"].pop(key)
            with self.subTest(result_key=key), self.assertRaises(builder.EvidenceFailure):
                builder.r11_validate_builder_terminal(mutation)

    def test_r11_19_recovery_schema_is_negative_only(self) -> None:
        source = inspect.getsource(builder.recover_interrupted)
        for literal in (
            '"recovery": True', '"predicates_evaluated": 0',
            '"subprocess_calls": 0', '"output_validated": False',
            '"calls": []', '"checkpoints": []',
        ):
            self.assertIn(literal, source)
        self.assertNotIn("subprocess.run", source)
        for prohibited in (
            "forge_bin", "solc_bin", "artifact", "output_dir",
            "validate_ordered_bytecode", "windows_file_receipt",
        ):
            self.assertNotIn(prohibited, source)
        terminal = r11_recovery_terminal()
        r11_validate_literal_recovery_terminal(terminal, terminal)
        for key in tuple(terminal):
            mutation = copy.deepcopy(terminal)
            mutation.pop(key)
            with self.subTest(top_key=key), self.assertRaises(builder.EvidenceFailure):
                r11_validate_literal_recovery_terminal(mutation, terminal)
        for key in tuple(terminal["results"]):
            mutation = copy.deepcopy(terminal)
            mutation["results"].pop(key)
            with self.subTest(result_key=key), self.assertRaises(builder.EvidenceFailure):
                r11_validate_literal_recovery_terminal(mutation, terminal)
        fixed_mutations = (
            ("predicates_evaluated", 1),
            ("subprocess_calls", 1),
            ("output_validated", True),
            ("path_token_status", ["forge"]),
        )
        for key, value in fixed_mutations:
            mutation = copy.deepcopy(terminal)
            mutation["results"][key] = value
            with self.subTest(fixed=key), self.assertRaises(builder.EvidenceFailure):
                r11_validate_literal_recovery_terminal(mutation, terminal)
        terminal["results"]["anomalies"] = [
            {
                "path_token": "invocation-000-start.json",
                "status": "invalid",
                "exception_type": "EVENT_PREFIX_INVALID",
                "message_sha256": "sha256:" + hashlib.sha256(
                    (
                        json.dumps(
                            {
                                "code": "EVENT_PREFIX_INVALID",
                                "path_token": "invocation-000-start.json",
                            },
                            sort_keys=True,
                            separators=(",", ":"),
                        )
                        + "\n"
                    ).encode("utf-8")
                ).hexdigest(),
            },
            {
                "path_token": "residue.tmp",
                "status": "unlinked",
                "exception_type": None,
                "message_sha256": None,
            },
        ]
        r11_validate_literal_recovery_terminal(terminal, terminal)
        for mutation_kind in ("order", "duplicate", "status", "exception", "message"):
            mutation = copy.deepcopy(terminal)
            anomalies = mutation["results"]["anomalies"]
            if mutation_kind == "order":
                anomalies.reverse()
            elif mutation_kind == "duplicate":
                anomalies[1]["path_token"] = anomalies[0]["path_token"]
            elif mutation_kind == "status":
                anomalies[0]["status"] = "unknown"
            elif mutation_kind == "exception":
                anomalies[0]["exception_type"] = "OSError"
            else:
                anomalies[1]["message_sha256"] = r11_hash("not-null")
            with self.subTest(anomaly=mutation_kind), self.assertRaises(builder.EvidenceFailure):
                r11_validate_literal_recovery_terminal(mutation, terminal)

    def test_r11_20_primary_token_abi_and_exact_five_test_apis(self) -> None:
        self.assertEqual((ctypes.sizeof(LUID), ctypes.alignment(LUID)), (8, 4))
        self.assertEqual((ctypes.sizeof(LUID_AND_ATTRIBUTES), ctypes.alignment(LUID_AND_ATTRIBUTES)), (12, 4))
        self.assertEqual((ctypes.sizeof(TOKEN_PRIVILEGES_ONE), ctypes.alignment(TOKEN_PRIVILEGES_ONE)), (16, 4))
        source = Path(__file__).read_text(encoding="utf-8")
        for name in (
            "DeviceIoControl", "OpenProcessToken", "LookupPrivilegeValueW",
            "AdjustTokenPrivileges", "GetTokenInformation",
        ):
            self.assertIn(name, source)
        self.assertEqual(source.count(R11_ADVAPI_LOAD_NEEDLE), 1)

    def test_r11_21_aligned_two_call_query_table_and_no_retry(self) -> None:
        for size in (4, 16, 65_536):
            count = (size - 4) // 12 if (size - 4) % 12 == 0 else 0
            snapshot = r11_token_snapshot([(index, 0, 0) for index in range(count)])
            fake = R11QueryFake([snapshot], requested=size)
            if len(snapshot) == size:
                self.assertEqual(read_token_privileges(1, fake), snapshot)
                self.assertEqual(len(fake.calls), 2)
        for size in (0, 1, 2, 3, 5, 65_537):
            fake = R11QueryFake([r11_token_snapshot([])], requested=size)
            with self.subTest(size=size), self.assertRaises(AssertionError):
                read_token_privileges(1, fake)
            self.assertEqual(len(fake.calls), 1)
        snapshot = r11_token_snapshot([(1, -1, 2)])

        class QueryFault(R11QueryFake):
            def __init__(self, stage: str) -> None:
                super().__init__([snapshot])
                self.stage = stage

            def GetTokenInformation(self, *args: Any) -> bool:
                buffer = args[2]
                if self.stage == "first_true" and buffer is None:
                    self.calls.append(args)
                    ctypes.set_last_error(ERROR_INSUFFICIENT_BUFFER)
                    return True
                if self.stage == "first_error" and buffer is None:
                    self.calls.append(args)
                    ctypes.set_last_error(5)
                    return False
                if self.stage == "second_false" and buffer is not None:
                    self.calls.append(args)
                    ctypes.set_last_error(6)
                    return False
                if self.stage == "second_false_122" and buffer is not None:
                    self.calls.append(args)
                    ctypes.set_last_error(ERROR_INSUFFICIENT_BUFFER)
                    return False
                result = super().GetTokenInformation(*args)
                if self.stage == "length_change" and buffer is not None:
                    ctypes.cast(args[4], ctypes.POINTER(wintypes.DWORD)).contents.value -= 4
                return result

        for stage, error in (
            ("first_true", AssertionError),
            ("first_error", AssertionError),
            ("second_false", OSError),
            ("second_false_122", OSError),
            ("length_change", AssertionError),
        ):
            fake = QueryFault(stage)
            with self.subTest(stage=stage), self.assertRaises(error):
                read_token_privileges(1, fake)
            self.assertEqual(len(fake.calls), 1 if stage.startswith("first") else 2)

        captured_storage: list[Any] = []

        def zero_storage(words: int) -> Any:
            storage = (wintypes.DWORD * words)()
            self.assertTrue(all(word == 0 for word in storage))
            captured_storage.append(storage)
            return storage

        stale = R11QueryFake([snapshot])
        immutable = read_token_privileges(
            1,
            stale,
            storage_factory=zero_storage,
        )
        self.assertIs(type(immutable), bytes)
        self.assertEqual(immutable, snapshot)
        self.assertEqual(len(stale.calls), 2)
        self.assertEqual(stale.calls[1][3], len(snapshot))
        storage_address = ctypes.addressof(captured_storage[0])
        self.assertEqual(storage_address % 4, 0)
        self.assertEqual(storage_address % ctypes.alignment(TOKEN_PRIVILEGES_ONE), 0)
        captured_storage[0][0] = 0xFFFFFFFF
        self.assertEqual(immutable, snapshot)

        retained_buffers: list[Any] = []

        def misaligned_storage(words: int) -> Any:
            backing = ctypes.create_string_buffer(words * 4 + 1)
            retained_buffers.append(backing)
            return (ctypes.c_ubyte * (words * 4)).from_buffer(backing, 1)

        misaligned = R11QueryFake([snapshot])
        with self.assertRaises(AssertionError):
            read_token_privileges(
                1,
                misaligned,
                storage_factory=misaligned_storage,
            )
        self.assertEqual(len(misaligned.calls), 1)

    def test_r11_22_parser_bounds_signed_high_and_exact_length(self) -> None:
        entries = [(0, -(1 << 31), 0xFFFFFFFF), (0xFFFFFFFF, (1 << 31) - 1, 2)]
        self.assertEqual(parse_token_privileges(r11_token_snapshot(entries)), entries)
        for count in (0, 1, 2, MAX_TOKEN_PRIVILEGE_COUNT):
            counted = [
                (index, -(1 << 31) if index == 0 else (1 << 31) - 1, index & 0xFFFFFFFF)
                for index in range(count)
            ]
            with self.subTest(count=count):
                self.assertEqual(
                    parse_token_privileges(r11_token_snapshot(counted)),
                    counted,
                )
        with self.assertRaises(AssertionError):
            parse_token_privileges(r11_token_snapshot(
                [(index, 0, 0) for index in range(MAX_TOKEN_PRIVILEGE_COUNT + 1)]
            ))
        exact_one = r11_token_snapshot([(1, -1, 2)])
        for malformed in (
            b"", b"\x00\x00\x00", exact_one[:-4], exact_one + b"\x00",
            r11_token_snapshot(entries) + b"\x00\x00\x00\x00",
            struct.pack("<I", MAX_TOKEN_PRIVILEGE_COUNT + 1),
        ):
            with self.subTest(length=len(malformed)), self.assertRaises(AssertionError):
                parse_token_privileges(malformed)
        exact = r11_token_snapshot(entries)
        for mutable in (bytearray(exact), memoryview(exact)):
            with self.subTest(type=type(mutable).__name__), self.assertRaises(AssertionError):
                parse_token_privileges(mutable)  # type: ignore[arg-type]

    def test_r11_23_unique_full_luid_and_attributes_baseline(self) -> None:
        wanted = (0x11223344, -7)
        self.assertEqual(unique_privilege_attributes(r11_token_snapshot([(1, 2, 4), (*wanted, 0xFFFFFFFF)]), wanted), 0xFFFFFFFF)
        unique_entries = [(1, -(1 << 31), 0), (*wanted, 0xFFFFFFFF), (0xFFFFFFFF, (1 << 31) - 1, 2)]
        for permutation in itertools.permutations(unique_entries):
            with self.subTest(permutation=permutation):
                self.assertEqual(
                    unique_privilege_attributes(
                        r11_token_snapshot(list(permutation)), wanted,
                    ),
                    0xFFFFFFFF,
                )
        for entries in ([(1, 2, 4)], [(*wanted, 0), (*wanted, 2)]):
            with self.assertRaises(AssertionError):
                unique_privilege_attributes(r11_token_snapshot(entries), wanted)

    def test_r11_24_restore_call_has_exact_six_positions_and_literal_false(self) -> None:
        fake = R11PrivilegeFake([])
        token = wintypes.HANDLE(0x1234)
        instruction = copy_token_privilege((0x11223344, -7), 0)
        r11_restore_token_privilege(
            fake, token, instruction,
            token, False, instruction, 0, None, None,
        )
        self.assertEqual(len(fake.adjust_calls), 1)
        exact_call = fake.adjust_calls[0]
        self.assertEqual(len(exact_call), 6)
        self.assertIs(exact_call[0], token)
        self.assertIs(exact_call[1], False)
        self.assertEqual(exact_call[3], 0)
        self.assertIsNone(exact_call[4])
        self.assertIsNone(exact_call[5])

    def test_r11_25_false_to_true_mutation_rejects_before_native_calls(self) -> None:
        token = wintypes.HANDLE(0x1234)
        instruction = copy_token_privilege((0x11223344, -7), 0)
        other_instruction = copy_token_privilege((0x11223344, -7), 0)
        output_length = wintypes.DWORD(0)
        mutations = (
            (None, False, instruction, 0, None, None),
            (wintypes.HANDLE(0x9999), False, instruction, 0, None, None),
            (token, True, instruction, 0, None, None),
            (token, False, None, 0, None, None),
            (token, False, other_instruction, 0, None, None),
            (token, False, instruction, 1, None, None),
            (token, False, instruction, 0, ctypes.byref(instruction), None),
            (token, False, instruction, 0, None, ctypes.byref(output_length)),
        )
        for position, arguments in enumerate(mutations, start=1):
            fake = R11PrivilegeFake([])
            with self.subTest(restore_mutation=position), self.assertRaises(
                AssertionError,
            ):
                r11_restore_token_privilege(
                    fake, token, instruction, *arguments,
                )
            self.assertEqual(fake.adjust_calls, [])

    def test_r11_26_baseline_fallback_restores_after_each_rejected_previous(self) -> None:
        wanted = (0x11223344, -7)
        for reason in ("length", "count", "luid", "attributes"):
            fake = R11PrivilegeFake(
                [
                    r11_token_snapshot([(*wanted, 0)]),
                    r11_token_snapshot([(*wanted, 0)]),
                ],
                malformed_previous=reason,
            )
            kernel = R11KernelFake()
            with self.subTest(reason=reason), self.assertRaises(BaseException):
                r11_run_privileged_fixture(lambda _owned, _kernel: None, native=(fake, kernel))
            self.assertEqual(len(fake.adjust_calls), 2)
            restore = ctypes.cast(fake.adjust_calls[-1][2], ctypes.POINTER(TOKEN_PRIVILEGES_ONE)).contents
            self.assertEqual(int(restore.Privileges[0].Attributes), 0)

    def test_r11_27_valid_previous_copy_and_already_enabled_call_counts(self) -> None:
        wanted = (0x11223344, -7)
        fake = R11PrivilegeFake(
            [
                r11_token_snapshot([(*wanted, 0)]),
                r11_token_snapshot([(*wanted, 2)]),
                r11_token_snapshot([(*wanted, 0)]),
            ]
        )
        kernel = R11KernelFake()
        result = r11_run_privileged_fixture(
            lambda owned, _kernel: owned(lambda: None), native=(fake, kernel),
        )
        self.assertTrue(all(result.values()))
        self.assertEqual(len(fake.adjust_calls), 2)
        restore_call = fake.adjust_calls[-1]
        self.assertEqual(len(restore_call), 6)
        self.assertEqual(int(getattr(restore_call[0], "value", restore_call[0])), 0x1234)
        self.assertFalse(bool(restore_call[1]))
        self.assertEqual(restore_call[3], 0)
        self.assertIsNone(restore_call[4])
        self.assertIsNone(restore_call[5])
        enabled = R11PrivilegeFake(
            [r11_token_snapshot([(*wanted, 2)]), r11_token_snapshot([(*wanted, 2)])]
        )
        r11_run_privileged_fixture(
            lambda owned, _kernel: owned(lambda: None),
            native=(enabled, R11KernelFake()),
        )
        self.assertEqual(enabled.adjust_calls, [])

    def test_r11_28_four_monotone_gates_and_finally_order(self) -> None:
        gate_names = (
            "token_acquired", "baseline_captured", "restoration_armed", "fixture_owned",
        )
        reachable = (
            (False, False, False, False),
            (True, False, False, False),
            (True, True, False, False),
            (True, True, False, True),
            (True, True, True, False),
            (True, True, True, True),
        )
        class CombinationStop(BaseException):
            pass

        wanted = (0x11223344, -7)
        scenarios = (
            (reachable[0], False, "before_token_acquired"),
            (reachable[1], False, "after_token_acquired"),
            (reachable[2], False, "after_baseline_captured"),
            (reachable[3], True, None),
            (reachable[4], False, "before_fixture_owned"),
            (reachable[5], False, None),
        )
        executed_states: list[tuple[bool, bool, bool, bool]] = []
        for expected_state, originally_enabled, stop_stage in scenarios:
            marker = CombinationStop("".join("1" if bit else "0" for bit in expected_state))
            observed_gates: list[str] = []
            events: list[str] = []
            original = SE_PRIVILEGE_ENABLED if originally_enabled else 0
            snapshots = [r11_token_snapshot([(*wanted, original)])]
            if originally_enabled:
                snapshots.append(r11_token_snapshot([(*wanted, original)]))
            else:
                snapshots.extend(
                    (
                        r11_token_snapshot([(*wanted, SE_PRIVILEGE_ENABLED)]),
                        r11_token_snapshot([(*wanted, original)]),
                    )
                )

            class GatePrivilege(R11PrivilegeFake):
                def AdjustTokenPrivileges(self, *args: Any) -> bool:
                    events.append("restore" if args[3] == 0 else "enable")
                    return super().AdjustTokenPrivileges(*args)

                def GetTokenInformation(self, *args: Any) -> bool:
                    if args[2] is None:
                        events.append(f"query-size-{self.snapshot_index}")
                    else:
                        events.append(f"query-data-{self.snapshot_index}")
                    return super().GetTokenInformation(*args)

            class GateKernel(R11KernelFake):
                def CloseHandle(self, handle: Any) -> bool:
                    events.append("close")
                    return super().CloseHandle(handle)

            fake = GatePrivilege(snapshots)
            kernel = GateKernel()

            def combination_hook(stage: str) -> None:
                if stage.startswith("after_"):
                    observed_gates.append(stage.removeprefix("after_"))
                if stage == stop_stage:
                    raise marker

            def combination_fixture(mark_owned: Any, _kernel: Any) -> None:
                mark_owned(lambda: events.append("cleanup"))

            with self.subTest(expected_state=expected_state):
                if stop_stage is None:
                    result = r11_run_privileged_fixture(
                        combination_fixture,
                        native=(fake, kernel),
                        fault_hook=combination_hook,
                    )
                    self.assertEqual(
                        tuple(result[name] for name in gate_names),
                        expected_state,
                    )
                else:
                    with self.assertRaises(CombinationStop) as stopped:
                        r11_run_privileged_fixture(
                            combination_fixture,
                            native=(fake, kernel),
                            fault_hook=combination_hook,
                        )
                    self.assertIs(stopped.exception, marker)
                actual = tuple(gate in observed_gates for gate in gate_names)
                self.assertEqual(actual, expected_state)
                executed_states.append(actual)
                expected_tail: list[str] = []
                if expected_state[3]:
                    expected_tail.append("cleanup")
                if expected_state[2]:
                    expected_tail.append("restore")
                if expected_state[1]:
                    final_snapshot = 1 if originally_enabled else (
                        1 if expected_state == reachable[2] else 2
                    )
                    expected_tail.extend(
                        (
                            f"query-size-{final_snapshot}",
                            f"query-data-{final_snapshot}",
                        )
                    )
                if expected_state[0]:
                    expected_tail.append("close")
                self.assertEqual(events[-len(expected_tail):] if expected_tail else [], expected_tail)

        self.assertEqual(tuple(executed_states), reachable)
        invalid_states = tuple(
            state
            for state in itertools.product((False, True), repeat=4)
            if state not in reachable
        )
        self.assertEqual(len(invalid_states), 10)
        self.assertTrue(set(executed_states).isdisjoint(invalid_states))
        static_actions: list[str] = []
        for state in invalid_states:
            with self.subTest(unreachable_state=state), self.assertRaises(
                AssertionError,
            ):
                _r11_validate_privilege_lifecycle_state(*state)
                static_actions.append("action")
        self.assertEqual(static_actions, [])
        for state in reachable:
            _r11_validate_privilege_lifecycle_state(*state)

        class GateBaseFailure(BaseException):
            pass

        stages = tuple(
            f"{position}_{gate}"
            for gate in gate_names
            for position in ("before", "after")
        )
        expected_fault_state = {
            "before_token_acquired": reachable[0],
            "after_token_acquired": reachable[1],
            "before_baseline_captured": reachable[1],
            "after_baseline_captured": reachable[2],
            "before_restoration_armed": reachable[2],
            "after_restoration_armed": reachable[4],
            "before_fixture_owned": reachable[4],
            "after_fixture_owned": reachable[5],
        }
        for failure_type in (RuntimeError, GateBaseFailure):
            for stage in stages:
                marker = failure_type(stage)
                expected_state = expected_fault_state[stage]
                fault_events: list[str] = []
                post_adjust_snapshot_observed = (
                    expected_state[2] and stage != "after_restoration_armed"
                )
                snapshots = [r11_token_snapshot([(*wanted, 0)])]
                if post_adjust_snapshot_observed:
                    snapshots.extend(
                        (
                            r11_token_snapshot([(*wanted, 2)]),
                            r11_token_snapshot([(*wanted, 0)]),
                        )
                    )
                elif expected_state[1]:
                    snapshots.append(r11_token_snapshot([(*wanted, 0)]))

                class FaultGatePrivilege(R11PrivilegeFake):
                    def AdjustTokenPrivileges(self, *args: Any) -> bool:
                        if args[3] == 0:
                            fault_events.append("restore")
                        return super().AdjustTokenPrivileges(*args)

                    def GetTokenInformation(self, *args: Any) -> bool:
                        final_index = 2 if post_adjust_snapshot_observed else 1
                        if (
                            expected_state[1]
                            and self.snapshot_index == final_index
                            and args[2] is None
                        ):
                            fault_events.append("final_query")
                        return super().GetTokenInformation(*args)

                class FaultGateKernel(R11KernelFake):
                    def CloseHandle(self, handle: Any) -> bool:
                        fault_events.append("close")
                        return super().CloseHandle(handle)

                fake = FaultGatePrivilege(snapshots)
                kernel = FaultGateKernel()

                def hook(observed: str) -> None:
                    if observed == stage:
                        raise marker

                def fixture(mark_owned: Any, _kernel: Any) -> None:
                    mark_owned(lambda: fault_events.append("cleanup"))

                with self.subTest(stage=stage, failure=failure_type.__name__):
                    with self.assertRaises(BaseException) as raised:
                        r11_run_privileged_fixture(
                            fixture,
                            native=(fake, kernel),
                            fault_hook=hook,
                        )
                    self.assertIs(raised.exception, marker)
                    expected_actions: list[str] = []
                    if expected_state[3]:
                        expected_actions.append("cleanup")
                    if expected_state[2]:
                        expected_actions.append("restore")
                    if expected_state[1]:
                        expected_actions.append("final_query")
                    if expected_state[0]:
                        expected_actions.append("close")
                    self.assertEqual(fault_events, expected_actions)
                    self.assertEqual(
                        len(kernel.close_calls), int(expected_state[0]),
                    )

    def test_r11_29_error_precedence_retains_all_five_tiers(self) -> None:
        class Marker(BaseException):
            pass

        for first in range(5):
            failures: list[BaseException | None] = [None] * 5
            failures[first] = Marker(str(first))
            failures[(first + 1) % 5] = RuntimeError("later")
            selected = next(failure for failure in failures if failure is not None)
            self.assertIs(selected, failures[min(index for index, failure in enumerate(failures) if failure is not None)])

        class StageFailure(BaseException):
            def __init__(self, stage: int) -> None:
                super().__init__(str(stage))
                self.stage = stage

        class FaultPrivilege(R11PrivilegeFake):
            def __init__(self, failed: set[int]) -> None:
                wanted = (0x11223344, -7)
                super().__init__(
                    [
                        r11_token_snapshot([(*wanted, 0)]),
                        r11_token_snapshot([(*wanted, 2)]),
                        r11_token_snapshot([(*wanted, 0)]),
                    ]
                )
                self.failed = failed

            def AdjustTokenPrivileges(self, *args: Any) -> bool:
                if args[3] == 0 and 2 in self.failed:
                    self.adjust_calls.append(args)
                    ctypes.set_last_error(5)
                    return False
                return super().AdjustTokenPrivileges(*args)

            def GetTokenInformation(self, *args: Any) -> bool:
                if self.snapshot_index == 2 and args[2] is None and 3 in self.failed:
                    self.calls.append(args)
                    raise StageFailure(3)
                return super().GetTokenInformation(*args)

        class FaultKernel(R11KernelFake):
            def __init__(self, failed: set[int]) -> None:
                super().__init__()
                self.failed = failed

            def CloseHandle(self, handle: Any) -> bool:
                self.close_calls.append(handle)
                if 4 in self.failed:
                    ctypes.set_last_error(6)
                    return False
                return True

        requested_failure_orders = tuple((tier,) for tier in range(5)) + tuple(
            itertools.combinations(range(5), 2)
        )
        self.assertEqual(len(requested_failure_orders), 15)
        for requested_order in requested_failure_orders:
            failed = set(requested_order)
            action_events: list[str] = []

            class OrderedFaultPrivilege(FaultPrivilege):
                def AdjustTokenPrivileges(self, *args: Any) -> bool:
                    if args[3] == 0:
                        action_events.append("restore")
                    return super().AdjustTokenPrivileges(*args)

                def GetTokenInformation(self, *args: Any) -> bool:
                    if self.snapshot_index == 2 and args[2] is None:
                        action_events.append("final_query")
                    return super().GetTokenInformation(*args)

            class OrderedFaultKernel(FaultKernel):
                def CloseHandle(self, handle: Any) -> bool:
                    action_events.append("close")
                    return super().CloseHandle(handle)

            fake = OrderedFaultPrivilege(failed)
            kernel = OrderedFaultKernel(failed)

            def fixture(mark_owned: Any, _kernel: Any) -> None:
                def cleanup() -> None:
                    action_events.append("cleanup")
                    if 1 in failed:
                        raise StageFailure(1)

                mark_owned(cleanup)
                if 0 in failed:
                    raise StageFailure(0)

            with self.subTest(order=requested_order), self.assertRaises(BaseException) as raised:
                r11_run_privileged_fixture(fixture, native=(fake, kernel))
            failure = raised.exception
            observed_stage = failure.stage if isinstance(failure, StageFailure) else (
                2 if 2 in failed else 4
            )
            self.assertEqual(observed_stage, min(failed))
            self.assertEqual(len(kernel.close_calls), 1)
            self.assertEqual(
                action_events,
                ["cleanup", "restore", "final_query", "close"],
            )

    def test_r11_30_mount_point_buffer_is_byte_exact_and_device_call_closed(self) -> None:
        target = Path("C:/target")
        raw = r11_mount_point_buffer(target)
        tag, data_length, reserved = struct.unpack_from("<IHH", raw, 0)
        self.assertEqual(tag, IO_REPARSE_TAG_MOUNT_POINT)
        self.assertEqual(data_length, len(raw) - 8)
        self.assertEqual(reserved, 0)
        substitute_offset, substitute_length, print_offset, print_length = struct.unpack_from(
            "<HHHH", raw, 8,
        )
        self.assertEqual(substitute_offset, 0)
        self.assertEqual(print_offset, substitute_length + 2)
        self.assertEqual(len(raw), 16 + substitute_length + 2 + print_length + 2)
        boundary = Path("C:\\" + "a" * 4086)
        self.assertEqual(len(r11_mount_point_buffer(boundary)), 16_384)
        with self.assertRaises(AssertionError):
            r11_mount_point_buffer(Path("C:\\" + "a" * 4087))
        astral = Path("C:\\" + "\U0001f600")
        self.assertIn("\U0001f600".encode("utf-16-le"), r11_mount_point_buffer(astral))
        with (
            patch.object(builder, "_kernel32") as surrogate_native,
            self.assertRaises(builder.R11TraversalDiagnostic) as surrogate_red,
        ):
            r11_mount_point_buffer(Path("C:\\" + "\ud800"))
        self.assertEqual(
            surrogate_red.exception.code,
            "PATH_NOT_LOCAL_DRIVE_ABSOLUTE",
        )
        self.assertEqual(
            surrogate_red.exception.operands,
            {
                "operation": "lexical_validate",
                "component_index": None,
                "path_token": None,
                "winerror": None,
                "expected_attributes": None,
                "actual_attributes": None,
                "identity_before": None,
                "identity_after": None,
            },
        )
        self.assertIsNone(surrogate_red.exception.record_proof)
        self.assertIsInstance(
            surrogate_red.exception.__cause__, UnicodeEncodeError,
        )
        surrogate_native.assert_not_called()
        for rejected in (
            Path("relative"), Path("C:relative"), Path("\\\\server\\share"),
            Path("\\\\?\\C:\\target"), Path("\\\\.\\C:\\target"),
        ):
            with self.subTest(target=str(rejected)), self.assertRaises(builder.R11TraversalDiagnostic):
                r11_mount_point_buffer(rejected)
        order: list[str] = []
        with (
            patch.object(os, "rmdir", side_effect=lambda path: order.append(f"rmdir:{Path(path).name}")),
            patch.object(shutil, "rmtree", side_effect=lambda path: order.append(f"rmtree:{Path(path).name}")),
        ):
            r11_remove_junction_fixture_paths(
                Path("C:/fixture/junction"), Path("C:/fixture/target"), Path("C:/fixture"),
            )
        self.assertEqual(order, ["rmdir:junction", "rmtree:target", "rmdir:fixture"])
        for failed_stage in range(3):
            order = []

            def fail_rmdir(path: Any) -> None:
                order.append(f"rmdir:{Path(path).name}")
                if failed_stage in (0, 2) and len(order) == (1 if failed_stage == 0 else 3):
                    raise MarkerError("rmdir")

            def fail_rmtree(path: Any) -> None:
                order.append(f"rmtree:{Path(path).name}")
                if failed_stage == 1:
                    raise MarkerError("rmtree")

            class MarkerError(BaseException):
                pass

            with (
                patch.object(os, "rmdir", side_effect=fail_rmdir),
                patch.object(shutil, "rmtree", side_effect=fail_rmtree),
                self.assertRaises(MarkerError),
            ):
                r11_remove_junction_fixture_paths(
                    Path("C:/fixture/junction"), Path("C:/fixture/target"), Path("C:/fixture"),
                )
            self.assertEqual(order, ["rmdir:junction", "rmtree:target", "rmdir:fixture"])
        source = inspect.getsource(r11_device_io_control)
        self.assertIn("kernel32.DeviceIoControl(", source)
        self.assertIn("ctypes.set_last_error(0)", source)
        kernel = R11KernelFake()
        for control_code, input_buffer in (
            (0, raw),
            (FSCTL_SET_REPARSE_POINT, bytearray(raw)),
        ):
            with self.assertRaises(AssertionError):
                r11_device_io_control(
                    kernel, 1, control_code, input_buffer,  # type: ignore[arg-type]
                )
        self.assertEqual(kernel.device_calls, [])
        result = r11_run_privileged_fixture(r11_real_junction_fixture)
        self.assertTrue(result["token_acquired"])
        self.assertTrue(result["baseline_captured"])
        self.assertTrue(result["fixture_owned"])
        race = r11_run_privileged_fixture(r11_real_replacement_race_fixture)
        self.assertTrue(race["token_acquired"])
        self.assertTrue(race["baseline_captured"])
        self.assertTrue(race["fixture_owned"])
        main_stages = (
            "before_ownership_gate", "after_ownership_gate",
            "before_directory_creation", "after_directory_creation",
            "before_handle_open", "after_handle_open",
            "before_set", "after_set",
            "before_handle_close", "after_handle_close",
        )
        cleanup_stages = (
            "before_junction_rmdir", "after_junction_rmdir",
            "before_target_removal", "after_target_removal",
            "before_root_removal", "after_root_removal",
        )

        class JunctionBaseFailure(BaseException):
            pass

        for stage in main_stages + cleanup_stages:
            marker = JunctionBaseFailure(stage)
            observed: list[str] = []

            def hook(actual: str) -> None:
                observed.append(actual)
                if actual == stage:
                    raise marker

            def fixture(mark_owned: Any, kernel32: Any) -> None:
                r11_real_junction_fixture(
                    mark_owned,
                    kernel32,
                    fault_hook=hook,
                )

            with self.subTest(junction_fault=stage), self.assertRaises(
                JunctionBaseFailure,
            ) as raised_fault:
                r11_run_privileged_fixture(fixture)
            self.assertIs(raised_fault.exception, marker)
            if stage == "before_ownership_gate":
                expected_stages = ("before_ownership_gate",)
            elif stage in main_stages:
                expected_stages = (
                    main_stages[:main_stages.index(stage) + 1] + cleanup_stages
                )
            else:
                expected_stages = main_stages + cleanup_stages
            self.assertEqual(tuple(observed), expected_stages)

    def test_r11_31_real_empty_enumeration_contract_is_valid_handle_error18_one_close(self) -> None:
        source = inspect.getsource(builder._r11_find_snapshot)
        self.assertIn("FindFirstFileW", source)
        self.assertIn("FindNextFileW", source)
        self.assertIn("_R11_ERROR_NO_MORE_FILES", source)
        self.assertIn("FindClose", source)
        self.assertLess(source.index("if handle == _INVALID_HANDLE_VALUE"), source.index("finally:"))
        identity = r11_test_identity()
        authority_cases = (
            (
                "root-token",
                {
                    "root": True,
                    "mode": "inventory",
                    "requested_token": "retained/requested-child",
                    "requested_depth": None,
                },
            ),
            (
                "root-depth",
                {
                    "root": True,
                    "mode": "inventory",
                    "requested_token": None,
                    "requested_depth": 0,
                },
            ),
            (
                "inventory-child-token",
                {
                    "root": False,
                    "mode": "inventory",
                    "requested_token": "retained/requested-child",
                    "requested_depth": 0,
                },
            ),
            (
                "lookup-null-token",
                {
                    "root": False,
                    "mode": "lookup",
                    "requested_token": None,
                    "requested_depth": 0,
                },
            ),
            (
                "lookup-null-depth",
                {
                    "root": False,
                    "mode": "lookup",
                    "requested_token": "retained/requested-child",
                    "requested_depth": None,
                },
            ),
        )
        for case_id, authority in authority_cases:
            with (
                self.subTest(snapshot_authority=case_id),
                patch.object(builder, "_kernel32") as native,
                self.assertRaises(ValueError),
            ):
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\authority",
                    parent_token="retained",
                    parent_identity=identity,
                    **authority,
                )
            native.assert_not_called()
        for invalid_parent in (None, "C:/native"):
            with (
                self.subTest(snapshot_parent_token=invalid_parent),
                patch.object(builder, "_kernel32") as native,
                self.assertRaises((TypeError, ValueError)),
            ):
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\authority",
                    root=False,
                    parent_token=invalid_parent,
                    parent_identity=identity,
                    mode="lookup",
                    requested_token="retained/requested-child",
                    requested_depth=0,
                )
            native.assert_not_called()
        root_empty = R11FindFake([])
        with patch.object(builder, "_kernel32", return_value=root_empty):
            self.assertEqual(
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\",
                    root=True,
                    parent_token="retained",
                    parent_identity=identity,
                    mode="inventory",
                    requested_token=None,
                    requested_depth=None,
                ),
                [],
            )
        distinct_lookup = R11FindFake([])
        with patch.object(builder, "_kernel32", return_value=distinct_lookup):
            self.assertEqual(
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\retained",
                    root=False,
                    parent_token="retained",
                    parent_identity=identity,
                    mode="lookup",
                    requested_token="retained/requested-child",
                    requested_depth=0,
                ),
                [],
            )
        distinct_lookup_failure = R11FindFake([], first_error=5)
        with (
            patch.object(
                builder, "_kernel32", return_value=distinct_lookup_failure,
            ),
            self.assertRaises(builder.R11TraversalDiagnostic) as lookup_open,
        ):
            builder._r11_find_snapshot(
                "\\\\?\\C:\\retained",
                root=False,
                parent_token="retained",
                parent_identity=identity,
                mode="lookup",
                requested_token="retained/requested-child",
                requested_depth=7,
            )
        self.assertEqual(
            (
                lookup_open.exception.code,
                lookup_open.exception.operands["component_index"],
                lookup_open.exception.operands["path_token"],
            ),
            (
                "TRAVERSAL_ENUM_OPEN",
                7,
                "retained/requested-child",
            ),
        )
        builder.r11_validate_diagnostic(lookup_open.exception)
        empty = R11FindFake([])
        with patch.object(builder, "_kernel32", return_value=empty):
            self.assertEqual(
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\empty", root=False,
                    parent_token="retained", parent_identity=identity,
                    mode="inventory", requested_token="retained", requested_depth=0,
                ),
                [],
            )
        self.assertEqual(empty.close_calls, 0)
        for first_error in (3, 5):
            failed_open = R11FindFake([], first_error=first_error)
            with patch.object(builder, "_kernel32", return_value=failed_open):
                with self.subTest(first_error=first_error), self.assertRaises(builder.R11TraversalDiagnostic) as opened:
                    builder._r11_find_snapshot(
                        "\\\\?\\C:\\missing",
                        root=False,
                        parent_token="retained",
                        parent_identity=identity,
                        mode="inventory",
                        requested_token="retained",
                        requested_depth=0,
                    )
            self.assertEqual(opened.exception.code, "TRAVERSAL_ENUM_OPEN")
            self.assertEqual(opened.exception.operands["component_index"], 0)
            self.assertEqual(opened.exception.operands["winerror"], first_error)
            builder.r11_validate_diagnostic(opened.exception)
            self.assertEqual(failed_open.close_calls, 0)
        for next_error in (2, 3, 5):
            failed_next = R11FindFake(
                [("Alpha", "", 0)], next_error=next_error,
            )
            with patch.object(builder, "_kernel32", return_value=failed_next):
                with self.subTest(next_error=next_error), self.assertRaises(builder.R11TraversalDiagnostic) as advanced:
                    builder._r11_find_snapshot(
                        "\\\\?\\C:\\next",
                        root=False,
                        parent_token="retained",
                        parent_identity=identity,
                        mode="inventory",
                        requested_token="retained",
                        requested_depth=0,
                    )
            self.assertEqual(advanced.exception.code, "TRAVERSAL_ENUM_NEXT")
            self.assertEqual(advanced.exception.operands["component_index"], 0)
            self.assertEqual(advanced.exception.operands["winerror"], next_error)
            builder.r11_validate_diagnostic(advanced.exception)
            self.assertEqual(failed_next.close_calls, 1)
        for permutation in (
            [(".", "", 16), ("..", "", 16), ("Zulu", "ZULU~1", 0), ("Alpha", "ALPHA~1", 0)],
            [("Alpha", "ALPHA~1", 0), ("Zulu", "ZULU~1", 0), ("..", "", 16), (".", "", 16)],
        ):
            fake = R11FindFake(permutation)
            with patch.object(builder, "_kernel32", return_value=fake):
                records = builder._r11_find_snapshot(
                    "\\\\?\\C:\\stable", root=False,
                    parent_token="retained", parent_identity=identity,
                    mode="inventory", requested_token="retained", requested_depth=0,
                )
            self.assertEqual([record["long_name"] for record in records], ["Alpha", "Zulu"])
            self.assertEqual(fake.close_calls, 1)
        primary = R11FindFake([("Alpha", "", 0)], next_error=5, close_error=6)
        with patch.object(builder, "_kernel32", return_value=primary):
            with self.assertRaises(builder.R11TraversalDiagnostic) as raised:
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\fault", root=False,
                    parent_token="retained", parent_identity=identity,
                    mode="inventory", requested_token="retained", requested_depth=0,
                )
        self.assertEqual(raised.exception.code, "TRAVERSAL_ENUM_NEXT")
        self.assertEqual(raised.exception.operands["component_index"], 0)
        self.assertEqual(raised.exception.operands["winerror"], 5)
        builder.r11_validate_diagnostic(raised.exception)
        self.assertEqual(primary.close_calls, 1)
        close_only = R11FindFake([("Alpha", "", 0)], close_error=6)
        with patch.object(builder, "_kernel32", return_value=close_only):
            with self.assertRaises(builder.R11TraversalDiagnostic) as raised:
                builder._r11_find_snapshot(
                    "\\\\?\\C:\\fault", root=False,
                    parent_token="retained", parent_identity=identity,
                    mode="inventory", requested_token="retained", requested_depth=0,
                )
        self.assertEqual(raised.exception.code, "TRAVERSAL_ENUM_CLOSE")
        self.assertEqual(raised.exception.operands["component_index"], 0)
        self.assertEqual(raised.exception.operands["winerror"], 6)
        builder.r11_validate_diagnostic(raised.exception)
        collision_evidence = []
        for permutation in (
            [("Alpha", "", 1), ("alpha", "", 2)],
            [("alpha", "", 2), ("Alpha", "", 1)],
        ):
            fake = R11FindFake(permutation)
            with patch.object(builder, "_kernel32", return_value=fake):
                with self.assertRaises(builder.R11TraversalDiagnostic) as raised:
                    builder._r11_find_snapshot(
                        "\\\\?\\C:\\collision", root=False,
                        parent_token="retained", parent_identity=identity,
                        mode="inventory", requested_token="retained", requested_depth=0,
                    )
            self.assertEqual(raised.exception.code, "TRAVERSAL_ENTRY_COLLISION")
            self.assertEqual(raised.exception.operands["component_index"], 0)
            self.assertIsNotNone(raised.exception.record_proof)
            self.assertIsNone(raised.exception.record_proof.requested_depth)
            builder.r11_validate_diagnostic(raised.exception)
            collision_evidence.append(
                builder.canonical_evidence_bytes(
                    {"code": raised.exception.code, "operands": raised.exception.operands}
                )
            )
        self.assertEqual(collision_evidence[0], collision_evidence[1])
        if os.name != "nt":
            self.skipTest("real empty/nonexistent enumeration is Windows-only")
        real_kernel = builder._kernel32()

        class CountingFindKernel:
            def __init__(self) -> None:
                self.first_handles: list[int] = []
                self.next_terminal_errors: list[int] = []
                self.close_calls = 0

            def __getattr__(self, name: str) -> Any:
                return getattr(real_kernel, name)

            def FindFirstFileW(self, pattern: str, data: Any) -> int:
                handle = int(real_kernel.FindFirstFileW(pattern, data))
                self.first_handles.append(handle)
                return handle

            def FindNextFileW(self, handle: int, data: Any) -> bool:
                result = bool(real_kernel.FindNextFileW(handle, data))
                if not result:
                    self.next_terminal_errors.append(int(ctypes.get_last_error()))
                return result

            def FindClose(self, handle: int) -> bool:
                self.close_calls += 1
                return bool(real_kernel.FindClose(handle))

        with tempfile.TemporaryDirectory(
            prefix="r11-enumeration-", dir=REPO_ROOT.parent,
        ) as temporary:
            empty_path = Path(temporary) / "empty"
            empty_path.mkdir()
            empty_kernel = CountingFindKernel()
            with patch.object(builder, "_kernel32", return_value=empty_kernel):
                self.assertEqual(
                    builder._r11_find_snapshot(
                        "\\\\?\\" + str(empty_path.resolve()),
                        root=False,
                        parent_token="retained",
                        parent_identity=identity,
                        mode="inventory",
                        requested_token="retained",
                        requested_depth=0,
                    ),
                    [],
                )
            self.assertEqual(len(empty_kernel.first_handles), 1)
            self.assertNotEqual(
                empty_kernel.first_handles[0], builder._INVALID_HANDLE_VALUE,
            )
            self.assertEqual(empty_kernel.next_terminal_errors[-1], 18)
            self.assertEqual(empty_kernel.close_calls, 1)
            missing_kernel = CountingFindKernel()
            with patch.object(builder, "_kernel32", return_value=missing_kernel):
                with self.assertRaises(builder.R11TraversalDiagnostic) as missing:
                    builder._r11_find_snapshot(
                        "\\\\?\\" + str((Path(temporary) / "missing").resolve()),
                        root=False,
                        parent_token="retained",
                        parent_identity=identity,
                        mode="inventory",
                        requested_token="retained",
                        requested_depth=0,
                    )
            self.assertEqual(missing.exception.operands["component_index"], 0)
            self.assertEqual(missing.exception.operands["winerror"], 3)
            builder.r11_validate_diagnostic(missing.exception)
            self.assertEqual(missing_kernel.close_calls, 0)

    def test_r11_32_process_and_native_api_partitions_are_closed(self) -> None:
        builder_source = SCRIPT_PATH.read_text(encoding="utf-8")
        self.assertEqual(builder_source.count("subprocess.run("), 4)
        self.assertEqual(
            builder_source.count('ctypes.WinDLL("kernel32.dll", use_last_error=True)'),
            2,
        )
        self.assertNotIn("ctypes.windll", builder_source)
        evidence_source = inspect.getsource(builder._captured_subprocess)
        self.assertEqual(evidence_source.count("subprocess.run("), 1)
        self.assertEqual(
            inspect.getsource(builder._r4_captured_subprocess).count("subprocess.run("),
            1,
        )
        test_source = Path(__file__).read_text(encoding="utf-8")
        self.assertEqual(test_source.count(R11_ADVAPI_LOAD_NEEDLE), 1)
        self.assertNotIn("advapi32.dll", builder_source.casefold())
        independent_source = inspect.getsource(_r11_independent_kernel32)
        self.assertIn(
            "ctypes.POINTER(R11IndependentByHandleInformation)",
            independent_source,
        )
        self.assertNotIn("builder._ByHandleFileInformation", independent_source)
        self.assertIsNot(
            R11IndependentByHandleInformation,
            builder._ByHandleFileInformation,
        )
        if os.name == "nt":
            independent_kernel = _r11_independent_kernel32()
            pointer_type = independent_kernel.GetFileInformationByHandle.argtypes[1]
            self.assertIs(pointer_type._type_, R11IndependentByHandleInformation)

    def test_r11_33_complete_success_geometry_and_go_quarantine_fields(self) -> None:
        results = r11_literal_initial_results()
        self.assertEqual(tuple(sorted(results)), builder.R11_RESULT_KEYS)
        self.assertEqual((len(results["groups"]), len(results["target_evaluations"])), (0, 19))
        source = inspect.getsource(builder._build_release_output_evidence_r11)
        install_source = inspect.getsource(builder._r11_install_output_no_replace)
        self.assertIn('results["output_installed"] = True', install_source)
        self.assertIn('results["output_quarantine_without_matching_go"] = True', install_source)
        self.assertLess(source.index('_r11_install_output_no_replace'), source.index('_r11_cleanup_build_temp'))
        self.assertLess(source.index('_r11_cleanup_build_temp'), source.index('journal.publish_terminal("GO"'))

        expected_bytes = {
            "a/first.json": b"a",
            "m.json": b"m",
            "z/last.json": b"z",
        }
        expected_receipts = [
            {
                "path": name,
                "byte_count": len(raw),
                "sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
            }
            for name, raw in sorted(expected_bytes.items())
        ]

        class RetainedFake:
            def __init__(
                self,
                topology: list[tuple[str, str]],
                contents: dict[str, bytes],
                fail_at: str | None = None,
            ) -> None:
                self._topology = topology
                self.contents = contents
                self.root_token = "installed"
                self.files = {name: object() for name, kind in topology if kind == "file"}
                self.fail_at = fail_at
                self.reads: list[str] = []

            def topology(self) -> list[tuple[str, str]]:
                return list(self._topology)

            def read_file(
                self,
                name: str,
                *,
                on_read_failure: Any = None,
            ) -> bytes:
                self.reads.append(name)
                if name == self.fail_at:
                    diagnostic = builder.R11TraversalDiagnostic(
                        "TRAVERSAL_READ", "read_child",
                        component_index=0, path_token=f"installed/{name}",
                        winerror=5, identity_before=r11_test_identity(),
                    )
                    if on_read_failure is not None:
                        raise on_read_failure(diagnostic, None)
                    raise diagnostic
                return self.contents[name]

        exact_topology = builder._r11_expected_topology(sorted(expected_bytes))
        topology_mutations = []
        for position in range(len(exact_topology)):
            missing = list(exact_topology)
            missing.pop(position)
            topology_mutations.append(missing)
            renamed = list(exact_topology)
            renamed[position] = ("x" + renamed[position][0], "file")
            topology_mutations.append(sorted(renamed))
            case_changed = list(exact_topology)
            case_changed[position] = (case_changed[position][0].upper(), "file")
            topology_mutations.append(sorted(case_changed))
            wrong_kind = list(exact_topology)
            wrong_kind[position] = (
                wrong_kind[position][0],
                "file" if wrong_kind[position][1] == "directory" else "directory",
            )
            topology_mutations.append(sorted(wrong_kind))
        topology_mutations.append(sorted(exact_topology + [("extra.json", "file")]))
        for topology in topology_mutations:
            retained = RetainedFake(topology, expected_bytes, fail_at="a.json")
            with self.assertRaises(builder.EvidenceFailure) as raised:
                builder._r11_read_retained_output(retained, expected_receipts)
            self.assertEqual(raised.exception.code, "OUTPUT_TOPOLOGY_MISMATCH")
            self.assertEqual(retained.reads, [])
        for name in expected_bytes:
            retained = RetainedFake(exact_topology, expected_bytes, fail_at=name)
            with self.assertRaises(builder.R11TraversalDiagnostic) as raised:
                builder._r11_read_retained_output(retained, expected_receipts)
            expected_prefix = sorted(expected_bytes)[:sorted(expected_bytes).index(name) + 1]
            self.assertEqual(retained.reads, expected_prefix)
            self.assertEqual(
                raised.exception.operands["path_token"], f"installed/{name}",
            )
            retained = RetainedFake(exact_topology, expected_bytes, fail_at=name)
            with self.assertRaises(builder.R11BuilderFailure) as translated:
                builder._r11_read_retained_output(
                    retained,
                    expected_receipts,
                    read_boundary="INSTALLED_READ",
                )
            expected_index = sorted(expected_bytes).index(name)
            self.assertEqual(
                translated.exception.first_red["operands"]["path_token"],
                f"installed/{name}",
            )
            self.assertEqual(
                retained.reads,
                sorted(expected_bytes)[:expected_index + 1],
            )
        for name in expected_bytes:
            changed = dict(expected_bytes)
            changed[name] += b"!"
            retained = RetainedFake(exact_topology, changed)
            with self.assertRaises(builder.EvidenceFailure) as raised:
                builder._r11_read_retained_output(retained, expected_receipts)
            self.assertEqual(raised.exception.code, "OUTPUT_BYTES_MISMATCH")
            self.assertEqual(
                raised.exception.operands["path_token"], f"installed/{name}",
            )
        retained = RetainedFake(exact_topology, expected_bytes)
        receipts, contents = builder._r11_read_retained_output(retained, expected_receipts)
        self.assertEqual((receipts, contents), (expected_receipts, expected_bytes))
        if os.name != "nt":
            self.skipTest("R11 fake end-to-end evidence geometry is Windows-only")
        scratch = Path(tempfile.mkdtemp(prefix="r11-success-", dir=REPO_ROOT.parent))
        evidence = scratch / "evidence"
        try:
            compiler_root = scratch / "compiler-root"
            compiler_root.mkdir()
            evidence.mkdir()
            forge = scratch / "forge.exe"
            solc = scratch / "solc.exe"
            forge.write_bytes(b"r11-fake-forge")
            solc.write_bytes(b"r11-fake-solc")
            self.assertEqual(
                set(R11_LITERAL_SOURCE_PATHS),
                set(R11_LITERAL_SOURCE_RECEIPTS),
            )
            self.assertEqual(
                tuple(sorted(R11_LITERAL_SOURCE_PATHS, key=str.casefold)),
                R11_LITERAL_SOURCE_PATHS,
            )
            self.assertEqual(
                sum(
                    R11_LITERAL_SOURCE_RECEIPTS[path][0]
                    for path in R11_LITERAL_SOURCE_PATHS
                ),
                R11_LITERAL_SOURCE_BUNDLE_DECODED_BYTES,
            )
            self.assertEqual(
                len(R11_LITERAL_SOURCE_BUNDLE_BASE85),
                R11_LITERAL_SOURCE_BUNDLE_CHUNK_COUNT,
            )
            self.assertTrue(all(
                len(chunk) == R11_LITERAL_SOURCE_BUNDLE_CHUNK_BYTES
                for chunk in R11_LITERAL_SOURCE_BUNDLE_BASE85[:-1]
            ))
            self.assertEqual(
                len(R11_LITERAL_SOURCE_BUNDLE_BASE85[-1]),
                R11_LITERAL_SOURCE_BUNDLE_ENCODED_BYTES
                - R11_LITERAL_SOURCE_BUNDLE_CHUNK_BYTES
                * (R11_LITERAL_SOURCE_BUNDLE_CHUNK_COUNT - 1),
            )
            encoded = b"".join(R11_LITERAL_SOURCE_BUNDLE_BASE85)
            self.assertEqual(
                (len(encoded), "sha256:" + hashlib.sha256(encoded).hexdigest()),
                (
                    R11_LITERAL_SOURCE_BUNDLE_ENCODED_BYTES,
                    R11_LITERAL_SOURCE_BUNDLE_ENCODED_SHA256,
                ),
            )

            def strict_decompress(candidate: bytes) -> bytes:
                decompressor = zlib.decompressobj()
                decoded = decompressor.decompress(candidate)
                decoded += decompressor.flush()
                if (
                    not decompressor.eof
                    or decompressor.unused_data
                    or decompressor.unconsumed_tail
                ):
                    raise ValueError(
                        "source bundle compression boundary is not exact"
                    )
                return decoded

            invalid_base85 = bytearray(encoded)
            invalid_base85[0] = 0x20
            with self.assertRaises(ValueError):
                base64.b85decode(invalid_base85)
            compressed = base64.b85decode(encoded)
            self.assertEqual(
                (
                    len(compressed),
                    "sha256:" + hashlib.sha256(compressed).hexdigest(),
                ),
                (
                    R11_LITERAL_SOURCE_BUNDLE_COMPRESSED_BYTES,
                    R11_LITERAL_SOURCE_BUNDLE_COMPRESSED_SHA256,
                ),
            )
            compressed_delta = bytearray(compressed)
            compressed_delta[-1] ^= 0x01
            for malformed_compressed in (
                compressed[:-1],
                compressed + b"\x00",
                bytes(compressed_delta),
            ):
                with self.assertRaises((ValueError, zlib.error)):
                    strict_decompress(malformed_compressed)
            decoded = strict_decompress(compressed)
            self.assertEqual(
                (len(decoded), "sha256:" + hashlib.sha256(decoded).hexdigest()),
                (
                    R11_LITERAL_SOURCE_BUNDLE_DECODED_BYTES,
                    R11_LITERAL_SOURCE_BUNDLE_DECODED_SHA256,
                ),
            )

            def strict_source_slices(candidate: bytes) -> dict[str, bytes]:
                slices: dict[str, bytes] = {}
                offset = 0
                for source_path in R11_LITERAL_SOURCE_PATHS:
                    expected_size, expected_digest = (
                        R11_LITERAL_SOURCE_RECEIPTS[source_path]
                    )
                    end = offset + expected_size
                    if end > len(candidate):
                        raise ValueError("source bundle is truncated")
                    raw = candidate[offset:end]
                    actual_digest = (
                        "sha256:" + hashlib.sha256(raw).hexdigest()
                    )
                    if len(raw) != expected_size or actual_digest != expected_digest:
                        raise ValueError(
                            f"source bundle slice differs: {source_path}"
                        )
                    slices[source_path] = raw
                    offset = end
                if offset != len(candidate):
                    raise ValueError("source bundle has trailing bytes")
                return slices

            decoded_delta = bytearray(decoded)
            decoded_delta[0] ^= 0x01
            for malformed_decoded in (
                decoded[:-1], decoded + b"\x00", bytes(decoded_delta),
            ):
                with self.assertRaises(ValueError):
                    strict_source_slices(malformed_decoded)
            source_slices = strict_source_slices(decoded)
            source_authority = bytearray()
            for source_path in R11_LITERAL_SOURCE_PATHS:
                raw = source_slices[source_path]
                actual_size = len(raw)
                actual_digest = "sha256:" + hashlib.sha256(raw).hexdigest()
                expected_size, expected_digest = (
                    R11_LITERAL_SOURCE_RECEIPTS[source_path]
                )
                self.assertEqual(
                    (actual_size, actual_digest),
                    (expected_size, expected_digest),
                    source_path,
                )
                destination = compiler_root / Path(source_path)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(raw)
                source_authority.extend(
                    source_path.removeprefix("smart-contracts/").encode("utf-8")
                )
                source_authority.extend(b"\n")
                source_authority.extend(
                    actual_digest.removeprefix("sha256:").upper().encode("ascii")
                )
                source_authority.extend(b"\n")
                source_authority.extend(str(actual_size).encode("ascii"))
                source_authority.extend(b"\n")
            self.assertEqual(
                hashlib.sha256(source_authority).hexdigest().upper(),
                "1EB0A58B8A1DCA624493839D41FA5267078E7FBA67B4AE6DF9205DD003659857",
            )
            foundry_raw = R11_LITERAL_FOUNDRY_CONFIG_RAW
            target_raw = r11_literal_target_config_bytes()
            self.assertEqual(
                (
                    len(foundry_raw),
                    foundry_raw.count(b"\n"),
                    foundry_raw.count(b"\r"),
                ),
                (1_686, 34, 0),
            )
            self.assertTrue(foundry_raw.endswith(b"\n"))
            self.assertEqual(
                hashlib.sha256(foundry_raw).hexdigest().upper(),
                "C356A459BC9919AE14225E59979601C8EAB26133B19C146E5928D28A7DAFBD61",
            )
            self.assertEqual(
                (
                    len(target_raw),
                    target_raw.count(b"\n"),
                    target_raw.count(b"\r"),
                ),
                (3_581, 82, 0),
            )
            self.assertTrue(target_raw.endswith(b"\n"))
            self.assertEqual(
                hashlib.sha256(target_raw).hexdigest().upper(),
                "84B3A32B16B8C171130D0D5F5192F06B2D199D17EF25862FF04B433FD8C3B9F9",
            )
            foundry_config = compiler_root / "foundry.toml"
            target_config = (
                compiler_root / "release-artifacts" / "contracts.json"
            )
            target_config.parent.mkdir(parents=True)
            foundry_config.write_bytes(foundry_raw)
            target_config.write_bytes(target_raw)
            self.assertEqual(foundry_config.read_bytes(), foundry_raw)
            self.assertEqual(target_config.read_bytes(), target_raw)
            output = compiler_root / "out-release"
            fake = R11ForgeFake()
            fake_version_raw = fake.portable_version.encode("utf-8")
            fake_digest = (
                "sha256:" + hashlib.sha256(fake_version_raw).hexdigest()
            )
            with (
                patch.object(
                    builder, "R11_FORGE_VERSION_IDENTITY_SHA256", fake_digest,
                ),
                patch.object(
                    builder,
                    "_captured_subprocess",
                    side_effect=lambda command, cwd, _environment: fake(
                        command, cwd,
                    ),
                ),
            ):
                manifest = builder.build_release_output(
                    compiler_root,
                    target_config,
                    foundry_config,
                    output,
                    str(forge),
                    solc_bin=solc,
                    evidence_dir=evidence,
                )
            self.assertEqual(len(fake.calls), 18)
            self.assertEqual(len(manifest["targets"]), 19)
            terminal = json.loads((evidence / "terminal.json").read_bytes())
            self.assertEqual(terminal["status"], "GO")
            self.assertEqual((terminal["event_count"], len(terminal["checkpoints"])), (37, 37))
            self.assertEqual(len(terminal["results"]["output_files"]), 37)
            self.assertEqual(len(list(evidence.iterdir())), 38)
            builder.r11_validate_builder_terminal(terminal)
            reordered_output_terminal = copy.deepcopy(terminal)
            first_output = reordered_output_terminal["results"][
                "output_files"
            ][0]
            reordered_output_terminal["results"]["output_files"][0] = dict(
                reversed(tuple(first_output.items())),
            )
            builder.r11_validate_builder_terminal(reordered_output_terminal)
            self.assertEqual(
                builder.canonical_evidence_bytes(reordered_output_terminal),
                builder.canonical_evidence_bytes(terminal),
            )
            for key in builder.R11_RESULT_KEYS:
                mutation = copy.deepcopy(terminal)
                mutation["results"].pop(key)
                with self.subTest(go_result_key=key), self.assertRaises(builder.EvidenceFailure):
                    builder.r11_validate_builder_terminal(mutation)
        finally:
            try:
                for lock in tuple(builder._ACTIVE_EVIDENCE_LOCKS):
                    if lock.path == evidence:
                        lock.close()
            finally:
                shutil.rmtree(scratch)

    def test_r11_34_bounded_successor_has_no_generic_expansion(self) -> None:
        builder_source = SCRIPT_PATH.read_text(encoding="utf-8")
        new_helpers = "\n".join(
            inspect.getsource(value)
            for value in (
                builder._build_release_output_evidence_r11,
                builder.ExecutionJournal,
                builder.r11_native_read,
                builder.r11_native_inventory,
                builder.validate_ordered_bytecode,
                builder.recover_interrupted,
            )
        )
        for prohibited in (
            "CreateJobObject", "socket.", "requests.", "urllib.",
            "shell=True", "timeout=", "delegatecall", "upgradeTo",
        ):
            self.assertNotIn(prohibited, new_helpers)
        self.assertNotIn("advapi32", builder_source.casefold())

    def test_r11_35_discovery_manifest_preserves_every_r4_case_once(self) -> None:
        # These counts prove the complete suite partition; 37, 34, 50, and 121
        # must move together when a test method is added or removed.
        legacy = {
            name for name, value in ReleaseBuildArtifactTests.__dict__.items()
            if name.startswith("test_") and callable(value)
        }
        inherited = {
            name for name, value in R4AuthoritativeEvidenceHistory.__dict__.items()
            if name.startswith("test_") and callable(value)
        }
        amendments = {
            name for name, value in R11AuthoritativeEvidenceTests.__dict__.items()
            if name.startswith("test_") and callable(value)
        }
        self.assertEqual(len(legacy), 37)
        self.assertEqual(len(inherited), 34)
        self.assertEqual(
            inherited,
            {
                name for name in inherited
                if re.fullmatch(r"test_[0-9]{2}_.+", name)
            },
        )
        self.assertEqual(len(amendments), 50)
        self.assertTrue(all(name.startswith("test_r11_") for name in amendments))
        self.assertEqual(legacy & inherited, set())
        self.assertEqual(legacy & amendments, set())
        self.assertEqual(inherited & amendments, set())
        self.assertEqual(len(legacy | inherited | amendments), 121)
        amendment_ids = {
            int(match.group(1))
            for name in amendments
            if (match := re.fullmatch(r"test_r11_([0-9]{2})_.+", name)) is not None
        }
        self.assertEqual(amendment_ids, set(range(1, 51)))
        amendment_source_names = re.findall(
            r"^    def (test_r11_[A-Za-z0-9_]+)\(",
            inspect.getsource(R11AuthoritativeEvidenceTests),
            flags=re.MULTILINE,
        )
        self.assertEqual(len(amendment_source_names), 50)
        self.assertEqual(len(amendment_source_names), len(set(amendment_source_names)))
        self.assertEqual(set(amendment_source_names), amendments)
        discovered = {
            name for name in dir(R11AuthoritativeEvidenceTests)
            if name.startswith("test_")
        }
        self.assertEqual(discovered, inherited | amendments)
        normal_discovery = unittest.defaultTestLoader.loadTestsFromModule(
            sys.modules[__name__],
        )
        self.assertEqual(normal_discovery.countTestCases(), 121)
        self.assertFalse(
            os.environ.get(R4_HERMETIC_CHILD_ENV) == "1"
            and os.environ.get(R4_HERMETIC_CHILD_CWD_ENV) == os.getcwd()
        )

    def test_r11_36_boundary_owner_is_frozen_and_has_no_exception_side_channel(self) -> None:
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        for prohibited in (
            "semantic_stage", "boundary_path_token", "read_prefix",
            "diagnostic.read_state", "getattr(diagnostic", "getattr(retained",
        ):
            self.assertNotIn(prohibited, source)
        owner = builder.R11BoundaryOwner(
            "INSTALLED_READ",
            (("prefix", "CLEAN"), ("selected_file_token", "installed/a.json")),
            "installed/a.json",
            0,
        )
        with self.assertRaises((AttributeError, TypeError)):
            owner.boundary = "INSTALLED_INVENTORY"  # type: ignore[misc]
        diagnostic = r11_complete_diagnostic("TRAVERSAL_READ")
        diagnostic.operands["path_token"] = "installed/a.json"
        translated = owner.translate(diagnostic, None)
        self.assertEqual(
            translated.first_red["operands"]["path_token"],
            "installed/a.json",
        )
        mismatched = r11_complete_diagnostic("TRAVERSAL_READ")
        mismatched.operands["path_token"] = "installed/sibling.json"
        with self.assertRaises(ValueError):
            owner.translate(mismatched, None)
        builder.R11BoundaryOwner(
            "INSTALLED_READ",
            (("prefix", "READ_PARTIAL"), ("selected_file_token", "installed/b.json")),
            "installed/b.json",
            1,
        )
        for mutation in (
            ("INSTALLED_READ", (("prefix", "CLEAN"),), "installed/a.json", 0),
            ("INSTALLED_READ", (("prefix", "CLEAN"), ("selected_file_token", "a.json")), "installed/a.json", 0),
            ("INSTALLED_READ", (("prefix", "CLEAN"), ("selected_file_token", "installed/a.json")), "native\\a.json", 0),
            ("INSTALLED_READ", (("prefix", "CLEAN"), ("selected_file_token", "installed/a.json")), "installed/a.json", -1),
            ("INSTALLED_READ", (("prefix", "READ_PARTIAL"), ("selected_file_token", "installed/a.json")), "installed/a.json", 0),
            ("INSTALLED_READ", (("prefix", "CLEAN"), ("selected_file_token", "installed/a.json")), "installed/a.json", 1),
            ("PORTABLE_BUILD_INFO_READ", (("group_index", 0), ("selected_file_token", "build-info/000/a.json")), "build-info/000/a.json", 1),
        ):
            with self.subTest(mutation=mutation), self.assertRaises((TypeError, ValueError)):
                builder.R11BoundaryOwner(*mutation)

        lookup_failure = RuntimeError("lookup owner must not receive post-read close")
        read_failure = MemoryError("read owner receives post-read close")
        lookup_owner = Mock(return_value=lookup_failure)
        read_owner = Mock(return_value=read_failure)
        close_diagnostic = builder.R11TraversalDiagnostic(
            "TRAVERSAL_HANDLE_CLOSE",
            "close_child",
            component_index=0,
            path_token="artifact/Target.json",
            winerror=6,
            identity_before=r11_test_identity("0000000000000002"),
        )
        copied_record = r11_copied_record("Target.json", "", 0)
        copied_record["raw_ordinal"] = 0
        with (
            patch.object(
                builder,
                "_r11_absolute_parts",
                return_value=("\\\\?\\C:\\", ["Target.json"], "unused"),
            ),
            patch.object(
                builder,
                "_r11_open_child",
                side_effect=(
                    (11, r11_test_identity("0000000000000001"), 0x10, 0),
                    (12, r11_test_identity("0000000000000002"), 0, 1),
                ),
            ),
            patch.object(builder, "_r11_find_snapshot", return_value=[copied_record]),
            patch.object(builder, "_r11_lookup_record", return_value=copied_record),
            patch.object(builder, "_r11_assert_directory_stable"),
            patch.object(builder, "_r11_read_fd", return_value=b"x"),
            patch.object(
                builder,
                "_r11_close_traversal_handle",
                side_effect=(close_diagnostic, None),
            ) as close_handle,
            self.assertRaises(MemoryError) as raised_close,
        ):
            builder.r11_native_read(
                Path("C:/Target.json"),
                "artifact/Target.json",
                on_lookup_failure=lookup_owner,
                on_read_failure=read_owner,
            )
        self.assertIs(raised_close.exception, read_failure)
        read_owner.assert_called_once_with(close_diagnostic, None)
        lookup_owner.assert_not_called()
        self.assertEqual(close_handle.call_count, 2)

    def test_r11_37_full_directory_dword_drift_is_never_kind_only(self) -> None:
        identity = r11_test_identity()
        expected = 0x00000010 | 0x00000001 | 0x00000002 | 0x00000004 | 0x00000020
        for root in (False, True):
            for bit in (0x1, 0x2, 0x4, 0x10, 0x20, 0x400, 0x800):
                actual = expected ^ bit
                with (
                    self.subTest(root=root, bit=bit),
                    patch.object(builder, "_r11_query_handle", return_value=(identity, actual, 0)),
                    self.assertRaises(builder.R11TraversalDiagnostic) as raised,
                ):
                    builder._r11_assert_directory_stable(
                        1,
                        identity,
                        expected,
                        root=root,
                        component_index=None if root else 3,
                        path_token=None if root else "retained/child",
                    )
                self.assertEqual(raised.exception.operands["expected_attributes"], expected)
                self.assertEqual(raised.exception.operands["actual_attributes"], actual)
        with patch.object(
            builder, "_r11_query_handle", return_value=(identity, expected, 0),
        ):
            builder._r11_assert_directory_stable(
                1,
                identity,
                expected,
                root=False,
                component_index=3,
                path_token="retained/child",
            )

        root_attributes = 0x00000837
        middle_attributes = 0x00000035
        nested_attributes = 0x00000813
        root_identity = r11_test_identity("0000000000000101")
        child_rows = {
            "First.bin": (2, r11_test_identity("0000000000000102"), 0x20, 1),
            "Middle": (3, r11_test_identity("0000000000000103"), middle_attributes, 0),
            "Nested": (4, r11_test_identity("0000000000000104"), nested_attributes, 0),
            "Repeated.bin": (5, r11_test_identity("0000000000000105"), 0x20, 1),
            "ZLast.bin": (6, r11_test_identity("0000000000000106"), 0x20, 1),
        }

        def copied_rows(rows: list[tuple[str, int]]) -> list[dict[str, Any]]:
            records = [r11_copied_record(name, "", attributes) for name, attributes in rows]
            for record in records:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"] for other in records
                )
            return records

        root_records = copied_rows([
            ("First.bin", 0x20),
            ("Middle", middle_attributes),
            ("ZLast.bin", 0x20),
        ])
        middle_records = copied_rows([
            ("Nested", nested_attributes),
        ])
        nested_records = copied_rows([("Repeated.bin", 0x20)])
        checkpoint_ids = (
            "D0.E", "D0.C0", "D1.E", "D2.E",
            "D2.C0", "D1.C0", "D0.C1", "D0.C2",
        )
        expected_call_handles = (1, 1, 3, 4, 4, 3, 1, 1)
        expected_open_counts = (0, 1, 2, 3, 4, 4, 4, 5)

        def retained_callsite_run(
            failed_call: int | None,
            *,
            cleanup_failures: set[int] = frozenset(),
        ) -> tuple[
            BaseException | None,
            list[tuple[int, int, bool, str | None]],
            list[str],
            list[int],
            int,
        ]:
            tree = object.__new__(builder.R11RetainedTree)
            root_item = {
                "handle": 1,
                "identity": root_identity,
                "attributes": root_attributes,
                "component_index": None,
                "path_token": None,
                "root": True,
                "directory": True,
                "ancestors": (),
            }
            tree.path = Path("C:/fixture")
            tree.root_token = "retained"
            tree.owned = [root_item]
            tree.entries = []
            tree.files = {}
            tree.read_count = 0
            tree.read_order = []
            stable_calls: list[tuple[int, int, bool, str | None]] = []
            opened: list[str] = []
            closed: list[int] = []
            read_spy = Mock(wraps=os.read)

            def find_snapshot(parent_path: str, **_kwargs: Any) -> list[dict[str, Any]]:
                if parent_path.endswith("\\Middle\\Nested"):
                    return copy.deepcopy(nested_records)
                if parent_path.endswith("\\Middle"):
                    return copy.deepcopy(middle_records)
                return copy.deepcopy(root_records)

            def open_child(child_path: str, **_kwargs: Any) -> tuple[int, dict[str, str], int, int]:
                name = child_path.rsplit("\\", 1)[-1]
                opened.append(name)
                return child_rows[name]

            by_handle = {values[0]: values[1:] for values in child_rows.values()}

            def assert_stable(
                handle: int,
                _before_identity: dict[str, str],
                before_attributes: int,
                *,
                root: bool,
                component_index: int | None,
                path_token: str | None,
            ) -> None:
                call_index = len(stable_calls)
                stable_calls.append((handle, before_attributes, root, path_token))
                if failed_call == call_index:
                    raise builder.R11TraversalDiagnostic(
                        "TRAVERSAL_ROOT_IDENTITY_CHANGED" if root else "TRAVERSAL_IDENTITY_CHANGED",
                        "revalidate_root" if root else "revalidate_child",
                        component_index=component_index,
                        path_token=path_token,
                        expected_attributes=before_attributes,
                        actual_attributes=before_attributes ^ 0x1,
                        identity_before=root_identity if root else by_handle[handle][0],
                        identity_after=root_identity if root else by_handle[handle][0],
                    )

            def query_handle(handle: int) -> tuple[dict[str, str], int, int]:
                child_identity, attributes, size = by_handle[handle]
                return child_identity, attributes, size

            def close_handle(handle: int, **_kwargs: Any) -> None:
                closed.append(handle)
                if handle in cleanup_failures:
                    raise builder.R11TraversalDiagnostic(
                        "TRAVERSAL_ROOT_HANDLE_CLOSE" if handle == 1 else "TRAVERSAL_HANDLE_CLOSE",
                        "close_root" if handle == 1 else "close_child",
                        component_index=None if handle == 1 else 0,
                        path_token=None if handle == 1 else "retained/child",
                        winerror=6,
                        identity_before=root_identity if handle == 1 else by_handle[handle][0],
                    )

            primary: BaseException | None = None
            with (
                patch.object(builder, "_r11_find_snapshot", side_effect=find_snapshot),
                patch.object(builder, "_r11_open_child", side_effect=open_child),
                patch.object(builder, "_r11_assert_directory_stable", side_effect=assert_stable),
                patch.object(builder, "_r11_query_handle", side_effect=query_handle),
                patch.object(builder, "_r11_close_traversal_handle", side_effect=close_handle),
                patch.object(builder.os, "read", read_spy),
            ):
                try:
                    tree._collect(
                        "\\\\?\\C:\\fixture",
                        root_item,
                        "retained",
                        root=True,
                        relative_prefix="",
                        ancestors=(root_item,),
                    )
                except BaseException as exc:
                    primary = exc
                try:
                    tree.close(primary=primary)
                except BaseException as exc:
                    if primary is None:
                        primary = exc
            self.assertEqual(read_spy.call_count, 0)
            return primary, stable_calls, opened, closed, len(tree.files)

        success, stable_calls, opened, closed, file_count = retained_callsite_run(None)
        self.assertIsNone(success)
        self.assertEqual(tuple(call[0] for call in stable_calls), expected_call_handles)
        self.assertEqual(
            tuple(call[1] for call in stable_calls),
            (
                root_attributes, root_attributes,
                middle_attributes, nested_attributes, nested_attributes,
                middle_attributes, root_attributes, root_attributes,
            ),
        )
        self.assertEqual(
            opened,
            ["First.bin", "Middle", "Nested", "Repeated.bin", "ZLast.bin"],
        )
        self.assertEqual(closed, [6, 5, 4, 3, 2, 1])
        self.assertEqual(file_count, 3)
        reverse_close_order = (6, 5, 4, 3, 2, 1)
        for failing_handles in (
            *((handle,) for handle in reverse_close_order),
            *itertools.combinations(reverse_close_order, 2),
        ):
            close_failure, _, all_opened, all_closed, _ = retained_callsite_run(
                None,
                cleanup_failures=set(failing_handles),
            )
            expected_winner = next(
                handle for handle in reverse_close_order
                if handle in failing_handles
            )
            with self.subTest(close_failures=failing_handles):
                self.assertIsInstance(
                    close_failure,
                    builder.R11TraversalDiagnostic,
                )
                self.assertEqual(
                    close_failure.operands["identity_before"],
                    root_identity
                    if expected_winner == 1
                    else {
                        values[0]: values[1]
                        for values in child_rows.values()
                    }[expected_winner],
                )
                self.assertEqual(len(all_opened), 5)
                self.assertEqual(all_closed, list(reverse_close_order))
        for failed_call, expected_open_count in enumerate(expected_open_counts):
            failure, calls, failed_opened, failed_closed, _ = retained_callsite_run(
                failed_call,
                cleanup_failures={1, 2, 3, 4, 5, 6},
            )
            with self.subTest(dword_check=checkpoint_ids[failed_call]):
                self.assertIsInstance(failure, builder.R11TraversalDiagnostic)
                self.assertEqual(len(calls), failed_call + 1)
                self.assertEqual(len(failed_opened), expected_open_count)
                expected_owned = [1] + [child_rows[name][0] for name in failed_opened]
                self.assertEqual(failed_closed, list(reversed(expected_owned)))
        cleanup_failure, _, cleanup_opened, cleanup_closed, _ = retained_callsite_run(
            None,
            cleanup_failures={4, 5},
        )
        self.assertIsInstance(cleanup_failure, builder.R11TraversalDiagnostic)
        self.assertEqual(
            cleanup_failure.operands["identity_before"],
            child_rows["Repeated.bin"][1],
        )
        self.assertEqual(
            cleanup_opened,
            ["First.bin", "Middle", "Nested", "Repeated.bin", "ZLast.bin"],
        )
        self.assertEqual(cleanup_closed, [6, 5, 4, 3, 2, 1])

        query_handles = (1, 2, 1, 3, 4, 5, 4, 3, 1, 6, 1)
        checkpoint_queries = (0, 2, 3, 4, 6, 7, 8, 10)
        checkpoint_open_counts = (0, 1, 2, 3, 4, 4, 4, 5)
        baseline_by_handle = {
            1: (root_identity, root_attributes, 0),
            **{
                values[0]: (values[1], values[2], values[3])
                for values in child_rows.values()
            },
        }

        def actual_query_fault_run(
            fault_query: int,
            mutation: tuple[str, int | None],
        ) -> tuple[BaseException | None, list[int], list[str], list[int], int]:
            tree = object.__new__(builder.R11RetainedTree)
            root_item = {
                "handle": 1,
                "identity": root_identity,
                "attributes": root_attributes,
                "component_index": None,
                "path_token": None,
                "root": True,
                "directory": True,
                "ancestors": (),
            }
            tree.path = Path("C:/fixture")
            tree.root_token = "retained"
            tree.owned = [root_item]
            tree.entries = []
            tree.files = {}
            tree.read_count = 0
            tree.read_order = []
            queried: list[int] = []
            opened: list[str] = []
            closed: list[int] = []
            read_spy = Mock(wraps=os.read)

            def find_snapshot(parent_path: str, **_kwargs: Any) -> list[dict[str, Any]]:
                if parent_path.endswith("\\Middle\\Nested"):
                    return copy.deepcopy(nested_records)
                if parent_path.endswith("\\Middle"):
                    return copy.deepcopy(middle_records)
                return copy.deepcopy(root_records)

            def open_child(child_path: str, **_kwargs: Any) -> tuple[int, dict[str, str], int, int]:
                name = child_path.rsplit("\\", 1)[-1]
                opened.append(name)
                return child_rows[name]

            def query_handle(handle: int) -> tuple[dict[str, str], int, int]:
                query_index = len(queried)
                queried.append(handle)
                identity_value, attributes_value, size_value = baseline_by_handle[handle]
                if query_index == fault_query:
                    mutation_name, mutation_bit = mutation
                    if mutation_name == "identity":
                        identity_value = r11_test_identity("0000000000000999")
                    else:
                        assert mutation_bit is not None
                        attributes_value ^= mutation_bit
                return identity_value, attributes_value, size_value

            def close_handle(handle: int, **_kwargs: Any) -> None:
                closed.append(handle)
                raise builder.R11TraversalDiagnostic(
                    "TRAVERSAL_ROOT_HANDLE_CLOSE" if handle == 1 else "TRAVERSAL_HANDLE_CLOSE",
                    "close_root" if handle == 1 else "close_child",
                    component_index=None if handle == 1 else 0,
                    path_token=None if handle == 1 else "retained/child",
                    winerror=6,
                    identity_before=baseline_by_handle[handle][0],
                )

            primary: BaseException | None = None
            with (
                patch.object(builder, "_r11_find_snapshot", side_effect=find_snapshot),
                patch.object(builder, "_r11_open_child", side_effect=open_child),
                patch.object(builder, "_r11_query_handle", side_effect=query_handle),
                patch.object(builder, "_r11_close_traversal_handle", side_effect=close_handle),
                patch.object(builder.os, "read", read_spy),
            ):
                try:
                    tree._collect(
                        "\\\\?\\C:\\fixture",
                        root_item,
                        "retained",
                        root=True,
                        relative_prefix="",
                        ancestors=(root_item,),
                    )
                except BaseException as exc:
                    primary = exc
                tree.close(primary=primary)
            self.assertEqual(read_spy.call_count, 0)
            return primary, queried, opened, closed, len(tree.files)

        dword_mutations = (
            ("identity", None),
            ("readonly", 0x00000001),
            ("hidden", 0x00000002),
            ("system", 0x00000004),
            ("directory", 0x00000010),
            ("archive", 0x00000020),
            ("reparse", 0x00000400),
            ("compressed", 0x00000800),
        )
        for checkpoint_index, fault_query in enumerate(checkpoint_queries):
            expected_handle = query_handles[fault_query]
            for mutation in dword_mutations:
                failure, queried, opened, closed, _ = actual_query_fault_run(
                    fault_query, mutation,
                )
                repeated_failure, repeated_queries, repeated_opened, repeated_closed, _ = (
                    actual_query_fault_run(fault_query, mutation)
                )
                mutation_name, mutation_bit = mutation
                with self.subTest(
                    checkpoint=checkpoint_ids[checkpoint_index],
                    query=fault_query,
                    handle=expected_handle,
                    mutation=mutation_name,
                ):
                    self.assertIsInstance(failure, builder.R11TraversalDiagnostic)
                    self.assertIsInstance(
                        repeated_failure,
                        builder.R11TraversalDiagnostic,
                    )
                    self.assertEqual(
                        builder.canonical_evidence_bytes({
                            "code": failure.code,
                            "operands": failure.operands,
                        }),
                        builder.canonical_evidence_bytes({
                            "code": repeated_failure.code,
                            "operands": repeated_failure.operands,
                        }),
                    )
                    self.assertEqual(
                        (repeated_queries, repeated_opened, repeated_closed),
                        (queried, opened, closed),
                    )
                    self.assertEqual(queried, list(query_handles[:fault_query + 1]))
                    self.assertEqual(
                        len(opened), checkpoint_open_counts[checkpoint_index],
                    )
                    expected_owned = [1] + [child_rows[name][0] for name in opened]
                    self.assertEqual(closed, list(reversed(expected_owned)))
                    self.assertEqual(
                        failure.code,
                        "TRAVERSAL_ROOT_IDENTITY_CHANGED"
                        if expected_handle == 1
                        else "TRAVERSAL_IDENTITY_CHANGED",
                    )
                    self.assertEqual(
                        failure.operands["path_token"],
                        {
                            1: None,
                            3: "retained/Middle",
                            4: "retained/Middle/Nested",
                        }[expected_handle],
                    )
                    self.assertEqual(
                        failure.operands["expected_attributes"],
                        baseline_by_handle[expected_handle][1],
                    )
                    if mutation_name == "identity":
                        self.assertNotEqual(
                            failure.operands["identity_before"],
                            failure.operands["identity_after"],
                        )
                    else:
                        assert mutation_bit is not None
                        self.assertEqual(
                            failure.operands["actual_attributes"],
                            baseline_by_handle[expected_handle][1] ^ mutation_bit,
                        )

    def test_r11_38_record_permutations_and_bic_are_canonical(self) -> None:
        rank_cases = (
            (b"b", b"a", b"c"),
            (b"b", b"a", b"b", b"a"),
            (b"same", b"same", b"same"),
            (),
        )
        for keys in rank_cases:
            expected_ranks = {
                key: sum(candidate < key for candidate in keys) for key in keys
            }
            with self.subTest(strict_smaller_keys=keys):
                self.assertEqual(
                    builder._r11_strict_smaller_ranks(keys), expected_ranks,
                )
        for function in (
            builder._r11_reconstruct_record_position,
            builder._r11_find_snapshot,
            builder._r11_validate_copied_records,
        ):
            source = inspect.getsource(function)
            self.assertIn("_r11_strict_smaller_ranks", source)
            self.assertNotIn("sum(candidate <", source)
        for code in sorted(R11_LITERAL_RECORD_PROOF_CODES):
            authority_diagnostic = r11_complete_diagnostic(code)
            authority_proof = authority_diagnostic.record_proof
            assert authority_proof is not None
            if authority_proof.root or authority_proof.inventory:
                self.assertIsNone(authority_proof.requested_depth)
            else:
                self.assertIs(type(authority_proof.requested_depth), int)
                self.assertEqual(
                    authority_proof.requested_depth,
                    authority_diagnostic.operands["component_index"],
                )

        records = [
            r11_copied_record("Zulu", "SHARED~1", 0x21),
            r11_copied_record("Alpha", "shared~1", 0x11),
            r11_copied_record("Middle", "SHARED~1", 0x41),
        ]
        expected_hash = r11_hash("parent/Alpha")
        for ordinal, permutation in enumerate(itertools.permutations(records)):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"] for other in copied
                )
            with self.subTest(permutation=ordinal):
                self.assertEqual(
                    builder.r11_strict_bic_alias_winner(
                        copied, "shared~1", "parent",
                    ),
                    {"actual_sha256": expected_hash},
                )
        wrong_case = copy.deepcopy(records)
        wrong_case.append(r11_copied_record("Shared~1", "", 0x10))
        for record in wrong_case:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"] for other in wrong_case
            )
        with self.assertRaises(builder.EvidenceFailure) as raised:
            builder.r11_strict_bic_alias_winner(wrong_case, "shared~1", "parent")
        self.assertEqual(raised.exception.code, "BIC_LONG_MATCH_PRESENT")
        collision = [
            r11_copied_record("Name", "ALIAS~1", 0x10),
            r11_copied_record("name", "ALIAS~1", 0x20),
        ]
        for record in collision:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"] for other in collision
            )
        with self.assertRaises(builder.EvidenceFailure) as collision_red:
            builder.r11_strict_bic_alias_winner(collision, "alias~1", "parent")
        self.assertEqual(collision_red.exception.code, "BIC_COLLISION_PRESENT")
        for no_alias in (
            [r11_copied_record("NoAlias", "", 0x10)],
            [r11_copied_record("OtherAlias", "OTHER~1", 0x10)],
        ):
            no_alias[0]["raw_ordinal"] = 0
            with self.subTest(no_alias=no_alias[0]["alternate_name"]), self.assertRaises(
                builder.EvidenceFailure,
            ) as absent_alias:
                builder.r11_strict_bic_alias_winner(
                    no_alias,
                    "alias~1",
                    "parent",
                )
            self.assertEqual(absent_alias.exception.code, "BIC_ALIAS_ABSENT")
        collision_three = [
            r11_copied_record("Case", "", 0x11),
            r11_copied_record("case", "", 0x21),
            r11_copied_record("CASE", "", 0x41),
        ]
        collision_bytes: list[bytes] = []
        for permutation in itertools.permutations(collision_three):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"] for other in copied
                )
            winner_record = min(copied, key=lambda item: item["record_key"])
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_COLLISION",
                "validate_inventory_entry",
                records=copied,
                winner=winner_record,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            collision_bytes.append(
                builder.canonical_evidence_bytes(
                    {"code": diagnostic.code, "operands": diagnostic.operands}
                )
            )
        self.assertEqual(len(set(collision_bytes)), 1)
        exact_collision = copy.deepcopy(collision_three)
        for record in exact_collision:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"]
                for other in exact_collision
            )
        exact_winner = min(exact_collision, key=lambda item: item["record_key"])
        decoded_mutation = copy.deepcopy(exact_collision)
        decoded_mutation[-1]["long_name"] = "caller-supplied"
        with self.assertRaises(ValueError):
            builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_COLLISION",
                "validate_inventory_entry",
                records=decoded_mutation,
                winner=next(
                    record for record in decoded_mutation
                    if record["record_key"] == exact_winner["record_key"]
                ),
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
        duplicate_nonwinner = copy.deepcopy(exact_collision)
        duplicate_nonwinner.append(copy.deepcopy(max(
            exact_collision, key=lambda item: item["record_key"],
        )))
        for record in duplicate_nonwinner:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"]
                for other in duplicate_nonwinner
            )
        with (
            patch.object(builder, "_r11_publish_preconstructed") as duplicate_publish,
            patch.object(builder, "publish_json_no_replace") as duplicate_legacy,
        ):
            duplicate_diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_COLLISION",
                "validate_inventory_entry",
                records=duplicate_nonwinner,
                winner=next(
                    record for record in duplicate_nonwinner
                    if record["record_key"] == exact_winner["record_key"]
                ),
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            builder.r11_validate_diagnostic(duplicate_diagnostic)
        duplicate_publish.assert_not_called()
        duplicate_legacy.assert_not_called()
        proof_diagnostic = r11_complete_diagnostic("TRAVERSAL_ENTRY_COLLISION")
        proof = proof_diagnostic.record_proof
        self.assertIsInstance(proof, builder.R11CopiedRecordProof)
        assert proof is not None
        proof_values = {
            name: getattr(proof, name) for name in R11_LITERAL_RECORD_PROOF_FIELDS
        }

        def with_record_proof(
            source: builder.R11TraversalDiagnostic,
            attached: builder.R11CopiedRecordProof,
        ) -> builder.R11TraversalDiagnostic:
            return builder.R11TraversalDiagnostic(
                source.code,
                source.operands["operation"],
                **{
                    key: value for key, value in source.operands.items()
                    if key != "operation" and value is not None
                },
                record_proof=attached,
            )

        selected_child = "installed/selected.json"
        retained_parent = "installed"
        authority_records = [r11_copied_record("Alpha", "", 0x21)]
        authority_records[0]["raw_ordinal"] = 0
        with self.assertRaises(
            builder.R11TraversalDiagnostic,
        ) as authority_failure:
            builder._r11_lookup_record(
                authority_records,
                "alpha",
                requested_token=selected_child,
                depth=2,
                parent_identity=r11_test_identity(),
                parent_token=retained_parent,
            )
        authority_diagnostic = authority_failure.exception
        authority_proof = authority_diagnostic.record_proof
        assert authority_proof is not None
        self.assertEqual(
            (
                authority_diagnostic.operands["path_token"],
                authority_proof.requested_token,
                authority_proof.parent_token,
                authority_proof.observed_winner_token,
            ),
            (
                selected_child,
                selected_child,
                retained_parent,
                "installed/Alpha",
            ),
        )
        installed_owner = builder.R11BoundaryOwner(
            "INSTALLED_READ",
            (("prefix", "CLEAN"), ("selected_file_token", selected_child)),
            selected_child,
            0,
            lifecycle_token=retained_parent,
        )
        self.assertIsInstance(
            installed_owner.translate(authority_diagnostic, None),
            builder.R11BuilderFailure,
        )
        sibling_child = "installed/sibling.json"
        authority_values = {
            name: getattr(authority_proof, name)
            for name in R11_LITERAL_RECORD_PROOF_FIELDS
        }
        authority_values["requested_token"] = sibling_child
        sibling_proof = builder.R11CopiedRecordProof(**authority_values)
        with self.assertRaises(ValueError):
            builder.r11_validate_diagnostic(
                with_record_proof(authority_diagnostic, sibling_proof)
            )

        def with_diagnostic_path_token(
            token: str,
            attached: builder.R11CopiedRecordProof,
        ) -> builder.R11TraversalDiagnostic:
            operands = {
                key: value
                for key, value in authority_diagnostic.operands.items()
                if key != "operation" and value is not None
            }
            operands["path_token"] = token
            return builder.R11TraversalDiagnostic(
                authority_diagnostic.code,
                authority_diagnostic.operands["operation"],
                **operands,
                record_proof=attached,
            )

        with self.assertRaises(ValueError):
            builder.r11_validate_diagnostic(
                with_diagnostic_path_token(sibling_child, authority_proof)
            )
        sibling_diagnostic = with_diagnostic_path_token(
            sibling_child, sibling_proof,
        )
        builder.r11_validate_diagnostic(sibling_diagnostic)
        with self.assertRaises(ValueError):
            installed_owner.translate(sibling_diagnostic, None)

        root_sibling_acceptance_ids: list[str] = []
        root_descendant_rejection_ids: list[str] = []
        missing_component_acceptance_ids: list[str] = []
        missing_parent_acceptance_ids: list[str] = []

        def assert_every_record_proof_field_rejects(
            case_id: str,
            source: builder.R11TraversalDiagnostic,
        ) -> None:
            proof_value = source.record_proof
            assert proof_value is not None
            base = {
                name: getattr(proof_value, name)
                for name in R11_LITERAL_RECORD_PROOF_FIELDS
            }
            first_record = list(proof_value.records[0])
            record_mutations: list[tuple[str, int, Any]] = [
                ("raw-long-519", 0, first_record[0][:-1]),
                ("raw-long-521", 0, first_record[0] + b"\x00"),
                (
                    "raw-long-content", 0,
                    bytes([first_record[0][0] ^ 1]) + first_record[0][1:],
                ),
                ("raw-alt-27", 1, first_record[1][:-1]),
                ("raw-alt-29", 1, first_record[1] + b"\x00"),
                (
                    "raw-alt-content", 1,
                    bytes([first_record[1][0] ^ 1]) + first_record[1][1:],
                ),
                ("attributes-kind", 2, first_record[2] ^ 0x10),
                ("attributes-nonkind", 2, first_record[2] ^ 0x02),
                (
                    "key-byte", 3,
                    bytes([first_record[3][0] ^ 1]) + first_record[3][1:],
                ),
                ("ordinal-minus-one", 4, -1),
                ("ordinal-next-u53", 4, first_record[4] + 1),
                ("names-present", 5, not first_record[5]),
                ("decoded-long", 6, "CallerLong"),
                ("decoded-alternate", 7, "CALLER~1"),
            ]
            if len(proof_value.records) > 1:
                record_mutations.extend(
                    (
                        ("key-from-loser", 3, proof_value.records[-1][3]),
                        ("ordinal-from-loser", 4, proof_value.records[-1][4]),
                    )
                )
            mutations: list[tuple[str, str, Any]] = []
            for label, index, replacement in record_mutations:
                changed = list(first_record)
                changed[index] = replacement
                mutations.append(
                    (
                        label,
                        "records",
                        (tuple(changed),) + proof_value.records[1:],
                    )
                )
            mutations.extend(
                (
                    ("code", "code", "TRAVERSAL_READ"),
                    ("operation", "operation", "wrong_operation"),
                    (
                        "records-sha256", "records_sha256",
                        "sha256:" + "f" * 64,
                    ),
                    ("root", "root", not proof_value.root),
                    ("inventory", "inventory", not proof_value.inventory),
                    (
                        "requested-depth", "requested_depth",
                        0 if proof_value.requested_depth is None else None,
                    ),
                    (
                        "requested-token-null", "requested_token", None,
                    ),
                    (
                        "requested-token-sibling", "requested_token",
                        "retained/sibling",
                    ),
                    (
                        "requested-token-native", "requested_token",
                        "C:/fixture/native",
                    ),
                    ("parent-token-null", "parent_token", None),
                    (
                        "parent-token-other", "parent_token",
                        "other-parent",
                    ),
                    (
                        "parent-token-native", "parent_token",
                        "C:/fixture/native",
                    ),
                    (
                        "parent-identity", "parent_identity",
                        ("FFFFFFFF", "0000000000000099"),
                    ),
                    (
                        "requested-component", "requested_component",
                        "CallerComponent",
                    ),
                    (
                        "observed-winner-null", "observed_winner_token", None,
                    ),
                    (
                        "observed-winner-sibling", "observed_winner_token",
                        "retained/sibling",
                    ),
                    (
                        "observed-winner-native", "observed_winner_token",
                        "C:/fixture/native",
                    ),
                    (
                        "duplicate-nonwinner", "records",
                        proof_value.records + (proof_value.records[-1],),
                    ),
                )
            )
            if proof_value.root:
                mutations.append((
                    "parent-token-descendant",
                    "parent_token",
                    proof_value.parent_token + "/descendant",
                ))
            if not proof_value.root and not proof_value.inventory:
                assert type(proof_value.requested_depth) is int
                mutations.extend((
                    ("requested-depth-bool", "requested_depth", True),
                    (
                        "requested-depth-component-mismatch",
                        "requested_depth",
                        proof_value.requested_depth + 1,
                    ),
                ))
            if proof_value.winner is not None and len(proof_value.records) > 1:
                mutations.append(("winner-null", "winner", None))
                losing_record = next(
                    (
                        record for record in proof_value.records
                        if record != proof_value.winner
                    ),
                    None,
                )
                if losing_record is not None:
                    mutations.append(("losing-selection", "winner", losing_record))
            for missing_field in R11_LITERAL_RECORD_PROOF_FIELDS:
                missing_values = dict(base)
                missing_values.pop(missing_field)
                with (
                    self.subTest(
                        proof_case=case_id,
                        proof_mutation=f"missing-{missing_field}",
                    ),
                    self.assertRaises(TypeError),
                ):
                    builder.R11CopiedRecordProof(**missing_values)
            for label, field, replacement in mutations:
                if (
                    replacement == base[field]
                    and type(replacement) is type(base[field])
                ):
                    continue
                changed_values = dict(base)
                changed_values[field] = replacement
                changed_proof = builder.R11CopiedRecordProof(**changed_values)
                changed_diagnostic = with_record_proof(source, changed_proof)
                accepts_context_bound_parent = (
                    (
                        label == "parent-token-other"
                        and (
                            proof_value.root
                            or proof_value.code
                            == "TRAVERSAL_COMPONENT_MISSING"
                        )
                    )
                    or (
                        label == "parent-token-descendant"
                        and proof_value.root
                    )
                )
                accepts_missing_component = (
                    label == "requested-component"
                    and case_id.startswith("D3-2Z-")
                )
                if accepts_context_bound_parent or accepts_missing_component:
                    with (
                        self.subTest(
                            proof_case=case_id,
                            proof_mutation=label,
                        ),
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as proof_publish,
                        patch.object(
                            builder, "publish_json_no_replace",
                        ) as proof_legacy,
                    ):
                        builder.r11_validate_diagnostic(changed_diagnostic)
                        if accepts_context_bound_parent:
                            frozen_owner = builder.R11BoundaryOwner(
                                "STAGED_OUTPUT_VALIDATE",
                                (("prefix", "DONE"),),
                                None,
                                None,
                                lifecycle_token=proof_value.parent_token,
                            )
                            with self.assertRaises(ValueError):
                                frozen_owner.translate(changed_diagnostic, None)
                            if proof_value.root:
                                if label == "parent-token-descendant":
                                    root_descendant_rejection_ids.append(
                                        case_id,
                                    )
                                else:
                                    root_sibling_acceptance_ids.append(case_id)
                            else:
                                missing_parent_acceptance_ids.append(case_id)
                        else:
                            missing_component_acceptance_ids.append(case_id)
                    proof_publish.assert_not_called()
                    proof_legacy.assert_not_called()
                    continue
                with (
                    self.subTest(proof_case=case_id, proof_mutation=label),
                    patch.object(builder, "_r11_publish_preconstructed") as proof_publish,
                    patch.object(builder, "publish_json_no_replace") as proof_legacy,
                    self.assertRaises((TypeError, ValueError, UnicodeError)),
                ):
                    builder.r11_validate_diagnostic(changed_diagnostic)
                proof_publish.assert_not_called()
                proof_legacy.assert_not_called()

        def literal_family_diagnostic(
            code: str,
            records: list[dict[str, Any]],
            winner: dict[str, Any],
            *,
            root: bool,
        ) -> builder.R11TraversalDiagnostic:
            def freeze_record(
                record: dict[str, Any],
            ) -> tuple[
                bytes, bytes, int, bytes, int, bool,
                str | None, str | None,
            ]:
                names_present = (
                    "long_name" in record or "alternate_name" in record
                )
                return (
                    record["raw_long"], record["raw_alt"],
                    record["attributes"], record["record_key"],
                    record["raw_ordinal"], names_present,
                    record.get("long_name"), record.get("alternate_name"),
                )

            operation = (
                "validate_root_entry" if root
                else "validate_inventory_entry"
            )
            proof = builder.R11CopiedRecordProof(
                code=code,
                operation=operation,
                records=tuple(freeze_record(record) for record in records),
                records_sha256=r11_literal_copied_record_multiset_sha256(
                    records,
                ),
                winner=freeze_record(winner),
                root=root,
                inventory=True,
                requested_depth=None,
                requested_token=None if root else "retained",
                parent_token="retained",
                parent_identity=("1234ABCD", "0000000000000001"),
                requested_component=None,
                observed_winner_token=None,
            )
            return builder.R11TraversalDiagnostic(
                code,
                operation,
                component_index=0 if root else winner["raw_ordinal"],
                path_token=None if root else "retained",
                actual_attributes=winner["attributes"],
                identity_before=r11_test_identity(),
                record_proof=proof,
            )

        first_record = list(proof.records[0])
        record_field_1_delta = bytearray(first_record[1])
        self.assertEqual(len(record_field_1_delta), 28)
        record_field_1_delta[-1] ^= 0x01
        self.assertNotEqual(bytes(record_field_1_delta), first_record[1])
        self.assertEqual(
            sum(
                (before ^ after).bit_count()
                for before, after in zip(
                    first_record[1], record_field_1_delta, strict=True,
                )
            ),
            1,
        )
        proof_mutations: list[tuple[str, Any]] = []
        for index, replacement in (
            (0, bytes(520)),
            (1, bytes(record_field_1_delta)),
            (2, 0xFFFFFFFF),
            (3, b"wrong-key"),
            (4, 99),
            (6, "caller-name"),
            (7, "CALLER~1"),
        ):
            changed_record = list(first_record)
            changed_record[index] = replacement
            proof_mutations.append(
                (
                    f"record_field_{index}",
                    (tuple(changed_record),) + proof.records[1:],
                )
            )
        second_record = list(proof.records[1])
        second_record[2] ^= 0x10
        proof_mutations.append(
            (
                "record_1",
                (proof.records[0], tuple(second_record)) + proof.records[2:],
            )
        )
        proof_mutations.extend(
            (
                ("records_sha256", "sha256:" + "f" * 64),
                ("winner", proof.records[-1]),
                ("root", True),
                ("inventory", False),
                ("requested_depth", 8),
                ("requested_token", "retained/sibling"),
                ("parent_token", "other-parent"),
                ("parent_identity", ("FFFFFFFF", "0000000000000099")),
                ("requested_component", "unexpected"),
                ("observed_winner_token", "retained/sibling"),
            )
        )
        for field, replacement in proof_mutations:
            values = dict(proof_values)
            values[field.split("_", 1)[0] if field.startswith("record_") else field] = replacement
            if field.startswith("record_"):
                values["records"] = replacement
                values.pop("record", None)
            changed_proof = builder.R11CopiedRecordProof(**values)
            changed_diagnostic = with_record_proof(
                proof_diagnostic, changed_proof,
            )
            with self.subTest(record_proof=field), self.assertRaises((TypeError, ValueError, UnicodeError)):
                builder.r11_validate_diagnostic(changed_diagnostic)
        unproved = builder.R11TraversalDiagnostic(
            proof_diagnostic.code,
            proof_diagnostic.operands["operation"],
            **{
                key: value for key, value in proof_diagnostic.operands.items()
                if key != "operation" and value is not None
            },
        )
        with self.assertRaises(ValueError):
            builder.r11_validate_diagnostic(unproved)
        root_proof_diagnostic = r11_complete_diagnostic(
            "TRAVERSAL_ROOT_ENTRY_COLLISION",
        )
        root_owner = builder.R11BoundaryOwner(
            "STAGED_OUTPUT_VALIDATE",
            (("prefix", "DONE"),),
            None,
            None,
            lifecycle_token="retained",
        )
        self.assertIsInstance(
            root_owner.translate(root_proof_diagnostic, None),
            builder.R11BuilderFailure,
        )
        root_proof = root_proof_diagnostic.record_proof
        assert root_proof is not None
        root_values = {
            name: getattr(root_proof, name)
            for name in R11_LITERAL_RECORD_PROOF_FIELDS
        }
        root_values["parent_token"] = "other-root"
        mutated_root = with_record_proof(
            root_proof_diagnostic,
            builder.R11CopiedRecordProof(**root_values),
        )
        with self.assertRaises(ValueError):
            root_owner.translate(mutated_root, None)

        def rebind_proof_authority(
            source: builder.R11TraversalDiagnostic,
            *,
            parent_token: str,
            requested_token: str | None = None,
            observed_winner_token: str | None = None,
        ) -> builder.R11TraversalDiagnostic:
            source_proof = source.record_proof
            assert source_proof is not None
            values = {
                name: getattr(source_proof, name)
                for name in R11_LITERAL_RECORD_PROOF_FIELDS
            }
            values["parent_token"] = parent_token
            if requested_token is not None:
                values["requested_token"] = requested_token
            if observed_winner_token is not None:
                values["observed_winner_token"] = observed_winner_token
            rebound_proof = builder.R11CopiedRecordProof(**values)
            if requested_token is None:
                return with_record_proof(source, rebound_proof)
            return with_diagnostic_path_token(
                requested_token, rebound_proof,
            )

        root_descendant = rebind_proof_authority(
            root_proof_diagnostic,
            parent_token="retained/descendant",
        )
        root_outside = rebind_proof_authority(
            root_proof_diagnostic,
            parent_token="outside-root",
        )
        nonroot_descendant = rebind_proof_authority(
            authority_diagnostic,
            parent_token="installed/descendant",
            requested_token="installed/descendant/requested-child",
            observed_winner_token="installed/descendant/Alpha",
        )
        nonroot_outside = rebind_proof_authority(
            authority_diagnostic,
            parent_token="outside-parent",
            observed_winner_token="outside-parent/Alpha",
        )
        nonroot_owner = builder.R11BoundaryOwner(
            "STAGED_OUTPUT_VALIDATE",
            (("prefix", "DONE"),),
            None,
            None,
            lifecycle_token="installed",
        )
        relation_cases = (
            ("root-exact", root_proof_diagnostic, root_owner, True, True),
            ("root-descendant", root_descendant, root_owner, False, True),
            ("root-outside", root_outside, root_owner, False, True),
            (
                "nonroot-exact", authority_diagnostic, nonroot_owner,
                True, False,
            ),
            (
                "nonroot-descendant", nonroot_descendant, nonroot_owner,
                True, False,
            ),
            (
                "nonroot-outside", nonroot_outside, nonroot_owner,
                False, False,
            ),
        )
        observed_owner_relations: list[tuple[str, str]] = []
        with (
            patch.object(
                builder, "_r11_publish_preconstructed",
            ) as relation_publish,
            patch.object(
                builder, "publish_json_no_replace",
            ) as relation_legacy,
        ):
            for relation_id, diagnostic, owner, accepts, root_relation in (
                relation_cases
            ):
                with self.subTest(owner_relation=relation_id):
                    builder.r11_validate_diagnostic(diagnostic)
                    if not accepts:
                        with self.assertRaises(ValueError):
                            owner.translate(diagnostic, None)
                    elif root_relation:
                        translated = owner.translate(diagnostic, None)
                        self.assertIs(
                            type(translated), builder.R11BuilderFailure,
                        )
                    else:
                        with self.assertRaises(
                            builder.R11TraversalDiagnostic,
                        ) as untranslated:
                            owner.translate(diagnostic, None)
                        self.assertIs(untranslated.exception, diagnostic)
                    observed_owner_relations.append((
                        relation_id,
                        "accept" if accepts else "reject",
                    ))
            owner_without_lifecycle = builder.R11BoundaryOwner(
                "STAGED_OUTPUT_VALIDATE",
                (("prefix", "DONE"),),
                None,
                None,
            )
            builder.r11_validate_diagnostic(root_proof_diagnostic)
            with self.assertRaises(ValueError):
                owner_without_lifecycle.translate(
                    root_proof_diagnostic, None,
                )
        relation_publish.assert_not_called()
        relation_legacy.assert_not_called()
        self.assertEqual(
            tuple(observed_owner_relations),
            (
                ("root-exact", "accept"),
                ("root-descendant", "reject"),
                ("root-outside", "reject"),
                ("nonroot-exact", "accept"),
                ("nonroot-descendant", "accept"),
                ("nonroot-outside", "reject"),
            ),
        )
        invalid_three = [
            r11_copied_record("Alpha", "", 0x11),
            r11_copied_record("Beta", "", 0x21),
            r11_copied_record("Gamma", "", 0x41),
        ]
        for index in (0, 2):
            invalid_three[index]["raw_long"] = bytes([0x41 + index, 0]) * 260
            invalid_three[index]["record_key"] = (
                invalid_three[index]["raw_long"]
                + invalid_three[index]["raw_alt"]
                + invalid_three[index]["attributes"].to_bytes(4, "little")
            )
            invalid_three[index].pop("long_name")
            invalid_three[index].pop("alternate_name")
        invalid_pair_bytes: list[bytes] = []
        for permutation in itertools.permutations(invalid_three[:2]):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            malformed = next(
                record for record in copied if "long_name" not in record
            )
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_NAME",
                "validate_inventory_entry",
                records=copied,
                winner=malformed,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            invalid_pair_bytes.append(builder.canonical_evidence_bytes({
                "code": diagnostic.code,
                "operands": diagnostic.operands,
            }))
        self.assertEqual(len(invalid_pair_bytes), 2)
        self.assertEqual(len(set(invalid_pair_bytes)), 1)
        invalid_bytes: list[bytes] = []
        for permutation in itertools.permutations(invalid_three):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"] for other in copied
                )
            malformed = []
            for record in copied:
                try:
                    r11_literal_record_names(record)
                except (ValueError, UnicodeError):
                    malformed.append(record)
            winner_record = min(malformed, key=lambda item: item["record_key"])
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_NAME",
                "validate_inventory_entry",
                records=copied,
                winner=winner_record,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            invalid_bytes.append(
                builder.canonical_evidence_bytes(
                    {"code": diagnostic.code, "operands": diagnostic.operands}
                )
            )
        self.assertEqual(len(set(invalid_bytes)), 1)

        priority_three = [
            copy.deepcopy(invalid_three[0]),
            r11_copied_record("Case", "SHARED~1", 0x21),
            r11_copied_record("case", "shared~1", 0x41),
        ]
        priority_invalid_bytes: list[bytes] = []
        for permutation in itertools.permutations(priority_three):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            malformed = next(
                record for record in copied if "long_name" not in record
            )
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_NAME",
                "validate_inventory_entry",
                records=copied,
                winner=malformed,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            priority_invalid_bytes.append(builder.canonical_evidence_bytes({
                "code": diagnostic.code,
                "operands": diagnostic.operands,
            }))
        self.assertEqual(len(priority_invalid_bytes), 6)
        self.assertEqual(len(set(priority_invalid_bytes)), 1)
        priority_collision = copy.deepcopy(priority_three[1:])
        for record in priority_collision:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"]
                for other in priority_collision
            )
        collision_winner = min(
            priority_collision,
            key=lambda item: item["record_key"],
        )
        collision_after_invalid = builder._r11_record_backed_diagnostic(
            "TRAVERSAL_ENTRY_COLLISION",
            "validate_inventory_entry",
            records=priority_collision,
            winner=collision_winner,
            root=False,
            inventory=True,
            requested_depth=None,
            requested_token="retained",
            parent_token="retained",
            parent_identity=r11_test_identity(),
        )
        builder.r11_validate_diagnostic(collision_after_invalid)
        sole_alias = [copy.deepcopy(collision_winner)]
        sole_alias[0]["raw_ordinal"] = 0
        self.assertEqual(
            builder.r11_strict_bic_alias_winner(
                sole_alias,
                "shared~1",
                "retained",
            ),
            {
                "actual_sha256": r11_hash(
                    "retained/" + sole_alias[0]["long_name"]
                ),
            },
        )

        alternate_invalid = r11_copied_record("Alternate", "ALT~1", 0x21)
        alternate_invalid["raw_alt"] = b"A\x00" * 14
        alternate_invalid["record_key"] = (
            alternate_invalid["raw_long"]
            + alternate_invalid["raw_alt"]
            + alternate_invalid["attributes"].to_bytes(4, "little")
        )
        alternate_invalid.pop("long_name")
        alternate_invalid.pop("alternate_name")
        alternate_pair = [
            alternate_invalid,
            r11_copied_record("Valid", "VALID~1", 0x41),
        ]
        alternate_evidence: list[bytes] = []
        for permutation in itertools.permutations(alternate_pair):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"] for other in copied
                )
            malformed = next(
                record for record in copied if "long_name" not in record
            )
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_NAME",
                "validate_inventory_entry",
                records=copied,
                winner=malformed,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            alternate_evidence.append(builder.canonical_evidence_bytes({
                "code": diagnostic.code,
                "operands": diagnostic.operands,
            }))
        self.assertEqual(len(alternate_evidence), 2)
        self.assertEqual(len(set(alternate_evidence)), 1)

        invalid_alternate_three = [
            r11_copied_record("AltAlpha", "ALPHA~1", 0x11),
            r11_copied_record("AltBeta", "BETA~1", 0x21),
            r11_copied_record("AltValid", "VALID~1", 0x41),
        ]
        for index, unit in ((0, b"A\x00"), (1, b"B\x00")):
            invalid_alternate_three[index]["raw_alt"] = unit * 14
            invalid_alternate_three[index]["record_key"] = (
                invalid_alternate_three[index]["raw_long"]
                + invalid_alternate_three[index]["raw_alt"]
                + invalid_alternate_three[index]["attributes"].to_bytes(
                    4, "little",
                )
            )
            invalid_alternate_three[index].pop("long_name")
            invalid_alternate_three[index].pop("alternate_name")
        alternate_three_evidence: list[bytes] = []
        alternate_three_snapshots: list[
            tuple[tuple[bytes, int, int], ...]
        ] = []
        for permutation_id, permutation in enumerate(
            itertools.permutations(invalid_alternate_three),
        ):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            malformed_records = []
            for record in copied:
                try:
                    r11_literal_record_names(record)
                except (ValueError, UnicodeError):
                    malformed_records.append(record)
            winner = min(
                malformed_records, key=lambda item: item["record_key"],
            )
            diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ENTRY_NAME",
                "validate_inventory_entry",
                records=copied,
                winner=winner,
                root=False,
                inventory=True,
                requested_depth=None,
                requested_token="retained",
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            root_diagnostic = builder._r11_record_backed_diagnostic(
                "TRAVERSAL_ROOT_ENTRY_NAME",
                "validate_root_entry",
                records=copied,
                winner=winner,
                root=True,
                inventory=True,
                requested_depth=None,
                requested_token=None,
                parent_token="retained",
                parent_identity=r11_test_identity(),
            )
            assert_every_record_proof_field_rejects(
                f"D3-3IA-P{permutation_id}-production-nonroot", diagnostic,
            )
            assert_every_record_proof_field_rejects(
                f"D3-3IA-P{permutation_id}-production-root", root_diagnostic,
            )
            with self.subTest(d3_3ia=permutation_id):
                self.assertEqual(
                    diagnostic.operands["actual_attributes"],
                    min(
                        invalid_alternate_three[:2],
                        key=lambda item: item["record_key"],
                    )["attributes"],
                )
                self.assertEqual(diagnostic.operands["path_token"], "retained")
                self.assertEqual(root_diagnostic.operands["path_token"], None)
                self.assertEqual(root_diagnostic.operands["component_index"], 0)
                self.assertEqual(winner["record_key"], min(
                    record["record_key"] for record in copied
                ))
                self.assertEqual(winner["raw_ordinal"], 0)
            alternate_three_snapshots.append(
                tuple(
                    (
                        record["record_key"],
                        record["raw_ordinal"],
                        record["attributes"],
                    )
                    for record in sorted(
                        copied, key=lambda item: item["record_key"],
                    )
                )
            )
            alternate_three_evidence.append(
                builder.canonical_evidence_bytes(
                    {"code": diagnostic.code, "operands": diagnostic.operands}
                )
            )
        self.assertEqual(len(alternate_three_evidence), 6)
        self.assertEqual(len(set(alternate_three_evidence)), 1)
        self.assertEqual(len(set(alternate_three_snapshots)), 1)

        identical_pair = [
            r11_copied_record("Identical", "IDENTI~1", 0x21),
            r11_copied_record("Identical", "IDENTI~1", 0x21),
        ]
        for record in identical_pair:
            record["raw_ordinal"] = 0
        identical_evidence = []
        for permutation in itertools.permutations(identical_pair):
            copied = copy.deepcopy(list(permutation))
            with (
                patch.object(builder, "_r11_publish_preconstructed") as identical_publish,
                patch.object(builder, "publish_json_no_replace") as identical_legacy,
            ):
                diagnostic = builder._r11_record_backed_diagnostic(
                    "TRAVERSAL_ENTRY_COLLISION",
                    "validate_inventory_entry",
                    records=copied,
                    winner=copied[0],
                    root=False,
                    inventory=True,
                    requested_depth=None,
                    requested_token="retained",
                    parent_token="retained",
                    parent_identity=r11_test_identity(),
                )
                builder.r11_validate_diagnostic(diagnostic)
            identical_publish.assert_not_called()
            identical_legacy.assert_not_called()
            identical_evidence.append(builder.canonical_evidence_bytes({
                "code": diagnostic.code,
                "operands": diagnostic.operands,
                "records_sha256": r11_literal_copied_record_multiset_sha256(copied),
            }))
        self.assertEqual(len(identical_evidence), 2)
        self.assertEqual(len(set(identical_evidence)), 1)

        proof_family_ids: list[str] = []
        inventory_proof_families = (
            ("D3-2IL", invalid_three[:2], "invalid"),
            ("D3-2IA", alternate_pair, "invalid"),
            ("D3-2DK", identical_pair, "collision"),
            ("D3-2C", collision, "collision"),
            ("D3-3IL", invalid_three, "invalid"),
            ("D3-3C", collision_three, "collision"),
            ("D3-3IA", invalid_alternate_three, "invalid"),
            ("D3-3P-invalid", priority_three, "invalid"),
            ("D3-3P-collision", priority_collision, "collision"),
        )
        for family_id, family_records, family_kind in inventory_proof_families:
            for permutation_id, permutation in enumerate(
                itertools.permutations(family_records),
            ):
                copied = copy.deepcopy(list(permutation))
                for record in copied:
                    record["raw_ordinal"] = sum(
                        other["record_key"] < record["record_key"]
                        for other in copied
                    )
                if family_kind == "invalid":
                    invalid_records = [
                        record for record in copied
                        if "long_name" not in record
                    ]
                    winner = min(
                        invalid_records,
                        key=lambda item: item["record_key"],
                    )
                else:
                    winner = min(
                        copied,
                        key=lambda item: item["record_key"],
                    )
                for root in (False, True):
                    code = (
                        "TRAVERSAL_ROOT_ENTRY_NAME"
                        if root and family_kind == "invalid"
                        else "TRAVERSAL_ENTRY_NAME"
                        if family_kind == "invalid"
                        else "TRAVERSAL_ROOT_ENTRY_COLLISION"
                        if root
                        else "TRAVERSAL_ENTRY_COLLISION"
                    )
                    diagnostic = literal_family_diagnostic(
                        code, copied, winner, root=root,
                    )
                    builder.r11_validate_diagnostic(diagnostic)
                    proof_case_id = (
                        f"{family_id}-P{permutation_id}-"
                        f"{'root' if root else 'nonroot'}"
                    )
                    assert_every_record_proof_field_rejects(
                        proof_case_id, diagnostic,
                    )
                    proof_family_ids.append(proof_case_id)

        d3_alias_unrelated = [
            r11_copied_record("AliasA.txt", "REQ~1.TXT", 0x20),
            r11_copied_record("Unrelated.txt", "OTHER~1.TXT", 0x10),
        ]
        d3_alias_pair = [
            r11_copied_record("AliasA.txt", "REQ~1.TXT", 0x20),
            r11_copied_record("AliasB.txt", "REQ~1.TXT", 0x10),
        ]
        d3_exact_pair = [
            r11_copied_record("req.txt", "", 0x20),
            r11_copied_record("Peer.txt", "REQ.TXT", 0x10),
        ]
        d3_wrong_case_pair = [
            r11_copied_record("Req.txt", "", 0x20),
            r11_copied_record("Peer.txt", "REQ.TXT", 0x10),
        ]
        d3_empty_alternates = [
            r11_copied_record("One.txt", "", 0x20),
            r11_copied_record("Two.txt", "", 0x10),
        ]
        d3_alias_three = [
            r11_copied_record("AliasA.txt", "REQ~1.TXT", 0x20),
            r11_copied_record("AliasB.txt", "REQ~1.TXT", 0x10),
            r11_copied_record("AliasC.txt", "REQ~1.TXT", 0x40),
        ]
        d3_priority_alias = [
            copy.deepcopy(collision_winner),
            r11_copied_record("Unrelated", "OTHER~1", 0x10),
        ]
        component_proof_families = (
            (
                "D3-2A1", d3_alias_unrelated, "REQ~1.TXT",
                "TRAVERSAL_COMPONENT_SHORT_ALIAS",
            ),
            (
                "D3-2A2", d3_alias_pair, "REQ~1.TXT",
                "TRAVERSAL_COMPONENT_SHORT_ALIAS",
            ),
            (
                "D3-2W", d3_wrong_case_pair, "req.txt",
                "TRAVERSAL_COMPONENT_CASE_MISMATCH",
            ),
            (
                "D3-2Z", d3_empty_alternates, "missing.txt",
                "TRAVERSAL_COMPONENT_MISSING",
            ),
            (
                "D3-3A", d3_alias_three, "REQ~1.TXT",
                "TRAVERSAL_COMPONENT_SHORT_ALIAS",
            ),
            (
                "D3-3P-alias", d3_priority_alias, "shared~1",
                "TRAVERSAL_COMPONENT_SHORT_ALIAS",
            ),
        )
        for family_id, family_records, requested, expected_code in (
            component_proof_families
        ):
            for permutation_id, permutation in enumerate(
                itertools.permutations(family_records),
            ):
                parent_token = "fixture/parent"
                requested_child_token = "fixture/parent/requested-child"
                copied = copy.deepcopy(list(permutation))
                for record in copied:
                    record["raw_ordinal"] = sum(
                        other["record_key"] < record["record_key"]
                        for other in copied
                    )
                with self.assertRaises(
                    builder.R11TraversalDiagnostic,
                ) as component_failure:
                    builder._r11_lookup_record(
                        copied,
                        requested,
                        requested_token=requested_child_token,
                        depth=4,
                        parent_identity=r11_test_identity(),
                        parent_token=parent_token,
                    )
                diagnostic = component_failure.exception
                self.assertEqual(diagnostic.code, expected_code)
                self.assertEqual(
                    diagnostic.operands["path_token"], requested_child_token,
                )
                self.assertEqual(
                    diagnostic.record_proof.requested_token,
                    requested_child_token,
                )
                self.assertEqual(
                    diagnostic.record_proof.parent_token, parent_token,
                )
                builder.r11_validate_diagnostic(diagnostic)
                proof_case_id = f"{family_id}-P{permutation_id}-nonroot"
                assert_every_record_proof_field_rejects(
                    proof_case_id, diagnostic,
                )
                if expected_code == "TRAVERSAL_COMPONENT_SHORT_ALIAS":
                    bic_candidate = builder.r11_strict_bic_alias_winner(
                        copied, requested, parent_token,
                    )
                    builder.r11_validate_strict_bic(
                        copied, requested, parent_token, bic_candidate,
                    )
                    if family_id in ("D3-2A1", "D3-2A2", "D3-3A"):
                        self.assertEqual(
                            bic_candidate,
                            {
                                "actual_sha256": (
                                    "sha256:98897ba821f290cd5434d2fb5d638800d28d79"
                                    "0cff3e9f58fa98e6645985bfe5"
                                ),
                            },
                        )
                    for bic_mutation in (
                        {},
                        {"actual_sha256": None},
                        {"actual_sha256": r11_hash("wrong-bic")},
                        {**bic_candidate, "extra": None},
                    ):
                        with self.assertRaises(ValueError):
                            builder.r11_validate_strict_bic(
                                copied,
                                requested,
                                parent_token,
                                bic_mutation,
                            )
                elif expected_code == "TRAVERSAL_COMPONENT_CASE_MISMATCH":
                    with self.assertRaises(
                        builder.EvidenceFailure,
                    ) as long_match_present:
                        builder.r11_strict_bic_alias_winner(
                            copied, requested, parent_token,
                        )
                    self.assertEqual(
                        long_match_present.exception.code,
                        "BIC_LONG_MATCH_PRESENT",
                    )
                else:
                    with self.assertRaises(
                        builder.EvidenceFailure,
                    ) as alias_absent:
                        builder.r11_strict_bic_alias_winner(
                            copied, requested, parent_token,
                        )
                    self.assertEqual(
                        alias_absent.exception.code, "BIC_ALIAS_ABSENT",
                    )
                proof_family_ids.append(proof_case_id)

        exact_lookup_ids: list[str] = []
        for permutation_id, permutation in enumerate(
            itertools.permutations(d3_exact_pair),
        ):
            parent_token = "fixture/parent"
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            exact = builder._r11_lookup_record(
                copied,
                "req.txt",
                requested_token="fixture/parent/requested-exact",
                depth=4,
                parent_identity=r11_test_identity(),
                parent_token=parent_token,
            )
            self.assertEqual(exact["long_name"], "req.txt")
            for record_index, record in enumerate(copied):
                exact_record_mutations = {
                    "raw-long": record["raw_long"][:-1],
                    "raw-alt": record["raw_alt"][:-1],
                    "attributes": record["attributes"] ^ 0x10,
                    "record-key": b"wrong",
                    "raw-ordinal": record["raw_ordinal"] + 1,
                    "long-name": "Caller.txt",
                    "alternate-name": "CALLER~1.TXT",
                }
                for field_label, replacement in exact_record_mutations.items():
                    changed = copy.deepcopy(copied)
                    field = {
                        "raw-long": "raw_long",
                        "raw-alt": "raw_alt",
                        "attributes": "attributes",
                        "record-key": "record_key",
                        "raw-ordinal": "raw_ordinal",
                        "long-name": "long_name",
                        "alternate-name": "alternate_name",
                    }[field_label]
                    changed[record_index][field] = replacement
                    with self.assertRaises(
                        (TypeError, ValueError, UnicodeError),
                    ):
                        builder._r11_lookup_record(
                            changed,
                            "req.txt",
                            requested_token="fixture/parent/requested-exact",
                            depth=4,
                            parent_identity=r11_test_identity(),
                            parent_token=parent_token,
                        )
            exact_lookup_ids.append(
                f"D3-2E-P{permutation_id}-nonroot"
            )

        self.assertEqual(len(proof_family_ids), 84)
        self.assertEqual(len(set(proof_family_ids)), 84)
        self.assertEqual(len(exact_lookup_ids), 2)
        self.assertEqual(len(set(exact_lookup_ids)), 2)
        self.assertEqual(len(root_sibling_acceptance_ids), 40)
        self.assertEqual(len(set(root_sibling_acceptance_ids)), 40)
        self.assertEqual(len(root_descendant_rejection_ids), 40)
        self.assertEqual(len(set(root_descendant_rejection_ids)), 40)
        self.assertEqual(len(missing_component_acceptance_ids), 2)
        self.assertEqual(len(set(missing_component_acceptance_ids)), 2)
        self.assertEqual(len(missing_parent_acceptance_ids), 2)
        self.assertEqual(len(set(missing_parent_acceptance_ids)), 2)
        self.assertEqual(
            {
                case_id.split("-P", 1)[0]
                for case_id in (*proof_family_ids, *exact_lookup_ids)
            },
            {
                "D3-2IL", "D3-2IA", "D3-2DK", "D3-2C", "D3-2A1",
                "D3-2A2", "D3-2E", "D3-2W", "D3-2Z", "D3-3IL",
                "D3-3C", "D3-3IA", "D3-3A", "D3-3P-invalid",
                "D3-3P-collision", "D3-3P-alias",
            },
        )
        self.assertEqual(
            {
                "D3-3P" if case_id.startswith("D3-3P-") else
                case_id.split("-P", 1)[0]
                for case_id in (*proof_family_ids, *exact_lookup_ids)
            },
            {
                "D3-2IL", "D3-2IA", "D3-2DK", "D3-2C", "D3-2A1",
                "D3-2A2", "D3-2E", "D3-2W", "D3-2Z", "D3-3IL",
                "D3-3C", "D3-3IA", "D3-3A", "D3-3P",
            },
        )

        priority_pair = [
            r11_copied_record("Exact", "", 0x21),
            r11_copied_record("AliasOwner", "exact", 0x41),
        ]
        for permutation in itertools.permutations(priority_pair):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            exact_record = next(
                record for record in copied if record["long_name"] == "Exact"
            )
            self.assertIs(
                builder._r11_lookup_record(
                    copied,
                    "Exact",
                    requested_token="retained/Exact",
                    depth=2,
                    parent_identity=r11_test_identity(),
                    parent_token="retained",
                ),
                exact_record,
            )
            with self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as wrong_case_before_alias:
                builder._r11_lookup_record(
                    copied,
                    "exact",
                    requested_token="retained/requested-exact-case",
                    depth=2,
                    parent_identity=r11_test_identity(),
                    parent_token="retained",
                )
            self.assertEqual(
                wrong_case_before_alias.exception.code,
                "TRAVERSAL_COMPONENT_CASE_MISMATCH",
            )

        empty_alternate_pair = [
            r11_copied_record("Alpha", "", 0x21),
            r11_copied_record("Zulu", "", 0x41),
        ]
        missing_evidence: list[bytes] = []
        for permutation in itertools.permutations(empty_alternate_pair):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            with self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as missing_component:
                builder._r11_lookup_record(
                    copied,
                    "Missing",
                    requested_token="retained/Missing",
                    depth=2,
                    parent_identity=r11_test_identity(),
                    parent_token="retained",
                )
            self.assertEqual(
                missing_component.exception.code,
                "TRAVERSAL_COMPONENT_MISSING",
            )
            self.assertEqual(
                missing_component.exception.operands["path_token"],
                "retained/Missing",
            )
            self.assertEqual(
                (
                    missing_component.exception.record_proof.requested_token,
                    missing_component.exception.record_proof.parent_token,
                ),
                ("retained/Missing", "retained"),
            )
            missing_evidence.append(builder.canonical_evidence_bytes({
                "code": missing_component.exception.code,
                "operands": missing_component.exception.operands,
            }))
        self.assertEqual(len(missing_evidence), 2)
        self.assertEqual(len(set(missing_evidence)), 1)

        lookup_records = [
            r11_copied_record("Exact", "", 0x21),
            r11_copied_record("AliasOwner", "OWNER~1", 0x41),
        ]
        for record in lookup_records:
            record["raw_ordinal"] = sum(
                other["record_key"] < record["record_key"]
                for other in lookup_records
            )
        self.assertIs(
            builder._r11_lookup_record(
                lookup_records,
                "Exact",
                requested_token="retained/requested-exact",
                depth=2,
                parent_identity=r11_test_identity(),
                parent_token="retained",
            ),
            lookup_records[0],
        )
        for requested, expected_code in (
            ("exact", "TRAVERSAL_COMPONENT_CASE_MISMATCH"),
            ("owner~1", "TRAVERSAL_COMPONENT_SHORT_ALIAS"),
            ("Missing", "TRAVERSAL_COMPONENT_MISSING"),
        ):
            with self.subTest(lookup=requested), self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as lookup_failure:
                builder._r11_lookup_record(
                    lookup_records,
                    requested,
                    requested_token="retained/requested-child",
                    depth=2,
                    parent_identity=r11_test_identity(),
                    parent_token="retained",
                )
            self.assertEqual(lookup_failure.exception.code, expected_code)
            self.assertEqual(
                lookup_failure.exception.operands["path_token"],
                "retained/requested-child",
            )
            builder.r11_validate_diagnostic(lookup_failure.exception)

        for alias_count in (1, 2, 3):
            alias_records = [
                r11_copied_record(
                    f"Alias{index}",
                    "SHARED~1",
                    0x20 + index,
                )
                for index in range(alias_count)
            ]
            for permutation in itertools.permutations(alias_records):
                copied = copy.deepcopy(list(permutation))
                for record in copied:
                    record["raw_ordinal"] = sum(
                        other["record_key"] < record["record_key"]
                        for other in copied
                    )
                winner = min(copied, key=lambda item: item["record_key"])
                candidate = builder.r11_strict_bic_alias_winner(
                    copied, "shared~1", "retained",
                )
                with self.subTest(
                    alias_count=alias_count,
                    order=tuple(record["long_name"] for record in copied),
                ):
                    self.assertEqual(
                        candidate,
                        {
                            "actual_sha256": r11_hash(
                                "retained/" + winner["long_name"]
                            ),
                        },
                    )
                    builder.r11_validate_strict_bic(
                        copied, "shared~1", "retained", candidate,
                    )

        alias_plus_unrelated = [
            r11_copied_record("AliasOwner", "ONLY~1", 0x21),
            r11_copied_record("Unrelated", "OTHER~1", 0x41),
        ]
        alias_plus_unrelated_results: list[bytes] = []
        for permutation_id, permutation in enumerate(
            itertools.permutations(alias_plus_unrelated),
        ):
            copied = copy.deepcopy(list(permutation))
            for record in copied:
                record["raw_ordinal"] = sum(
                    other["record_key"] < record["record_key"]
                    for other in copied
                )
            expected_winner = next(
                record for record in copied
                if record["alternate_name"].casefold() == "only~1"
            )
            expected_result = {
                "actual_sha256": r11_hash(
                    "retained/" + expected_winner["long_name"],
                )
            }
            observed = builder.r11_strict_bic_alias_winner(
                copied, "only~1", "retained",
            )
            sorted_records = sorted(copied, key=lambda item: item["record_key"])
            with self.subTest(d3_2a1=permutation_id):
                self.assertEqual(observed, expected_result)
                for record in sorted_records:
                    independently_reconstructed_key = (
                        record["raw_long"]
                        + record["raw_alt"]
                        + record["attributes"].to_bytes(
                            4, "little", signed=False,
                        )
                    )
                    self.assertEqual(
                        record["record_key"], independently_reconstructed_key,
                    )
                    self.assertEqual(
                        record["raw_ordinal"],
                        sum(
                            other["record_key"] < record["record_key"]
                            for other in copied
                        ),
                    )
                self.assertEqual(expected_winner["attributes"], 0x21)
                self.assertEqual(
                    expected_winner["raw_ordinal"],
                    sum(
                        record["record_key"]
                        < expected_winner["record_key"]
                        for record in copied
                    ),
                )
                builder.r11_validate_strict_bic(
                    copied, "only~1", "retained", expected_result,
                )
                expected_raw = (
                    json.dumps(
                        expected_result,
                        sort_keys=True,
                        separators=(",", ":"),
                        ensure_ascii=False,
                    )
                    + "\n"
                ).encode("utf-8")
                self.assertEqual(
                    builder.canonical_evidence_bytes(observed), expected_raw,
                )
            alias_plus_unrelated_results.append(
                builder.canonical_evidence_bytes(observed),
            )
        self.assertEqual(len(alias_plus_unrelated_results), 2)
        self.assertEqual(len(set(alias_plus_unrelated_results)), 1)

        bic_records = [r11_copied_record("Alias", "ALIAS~1", 0x21)]
        bic_records[0]["raw_ordinal"] = 0
        bic_candidate = builder.r11_strict_bic_alias_winner(
            bic_records, "alias~1", "retained",
        )
        for candidate in (
            {},
            None,
            [],
            {"actual_sha256": None},
            {"actual_sha256": 1},
            {"actual_sha256": r11_hash("wrong")},
            {"actual_sha256": bic_candidate["actual_sha256"].upper()},
            {**bic_candidate, "extra": None},
        ):
            with self.subTest(bic_candidate=candidate), self.assertRaises(ValueError):
                builder.r11_validate_strict_bic(
                    bic_records, "alias~1", "retained", candidate,
                )
        direct_record_mutations = (
            ("raw_long", bytes(519)),
            ("raw_alt", bytes(27)),
            ("attributes", 0x1_0000_0000),
            ("record_key", b"wrong"),
            ("raw_ordinal", 1),
            ("long_name", "Caller"),
            ("alternate_name", "CALLER~1"),
        )
        for field, replacement in direct_record_mutations:
            changed_records = copy.deepcopy(bic_records)
            changed_records[0][field] = replacement
            with self.subTest(direct_bic=field), self.assertRaises(
                (TypeError, ValueError, UnicodeError),
            ):
                builder.r11_strict_bic_alias_winner(
                    changed_records, "alias~1", "retained",
                )
        for requested, parent in (
            ("bad/name", "retained"),
            ("alias~1", "C:\\native"),
        ):
            with self.subTest(requested=requested, parent=parent), self.assertRaises(
                (TypeError, ValueError),
            ):
                builder.r11_strict_bic_alias_winner(
                    bic_records, requested, parent,
                )

        staged_boundary_index = R11_EXPECTED_BOUNDARIES.index(
            "STAGED_OUTPUT_VALIDATE",
        )
        expected_staged_cells = {
            "TRAVERSAL_ROOT_ENTRY_NAME": "STG",
            "TRAVERSAL_ROOT_ENTRY_COLLISION": "STG",
            "TRAVERSAL_ENTRY_NAME": "STG",
            "TRAVERSAL_ENTRY_COLLISION": "STG",
            "TRAVERSAL_COMPONENT_MISSING": "X",
            "TRAVERSAL_COMPONENT_CASE_MISMATCH": "X",
            "TRAVERSAL_COMPONENT_SHORT_ALIAS": "X",
        }
        observed_staged_cells: dict[str, str] = {}
        for code in sorted(R11_LITERAL_RECORD_PROOF_CODES):
            diagnostic = r11_complete_diagnostic(code)
            owner = builder.R11BoundaryOwner(
                "STAGED_OUTPUT_VALIDATE",
                (("prefix", "DONE"),),
                None,
                None,
                lifecycle_token="retained",
            )
            with patch.object(
                builder,
                "r11_validate_diagnostic",
                wraps=builder.r11_validate_diagnostic,
            ) as proof_validator:
                cell = R11_LITERAL_NATIVE_OUTCOME_ROWS[code][
                    staged_boundary_index
                ]
                observed_staged_cells[code] = cell
                if cell == "X":
                    with self.assertRaises(
                        builder.R11TraversalDiagnostic,
                    ) as untranslated:
                        owner.translate(diagnostic, None)
                    self.assertIs(untranslated.exception, diagnostic)
                else:
                    translated = owner.translate(diagnostic, None)
                    self.assertIs(type(translated), builder.R11BuilderFailure)
                    self.assertEqual(
                        translated.first_red["code"],
                        "STAGED_VALIDATION_FAILED",
                    )
            self.assertEqual(
                proof_validator.call_args_list,
                [call(diagnostic), call(diagnostic)],
            )
        self.assertEqual(observed_staged_cells, expected_staged_cells)
        self.assertEqual(
            (
                sum(cell == "STG" for cell in observed_staged_cells.values()),
                sum(cell == "X" for cell in observed_staged_cells.values()),
            ),
            (4, 3),
        )

        for proof_code in (
            "TRAVERSAL_ROOT_ENTRY_NAME",
            "TRAVERSAL_ROOT_ENTRY_COLLISION",
            "TRAVERSAL_ENTRY_NAME",
            "TRAVERSAL_ENTRY_COLLISION",
        ):
            source_diagnostic = r11_complete_diagnostic(proof_code)
            source_proof = source_diagnostic.record_proof
            assert source_proof is not None
            base_values = {
                name: getattr(source_proof, name)
                for name in R11_LITERAL_RECORD_PROOF_FIELDS
            }
            first = list(source_proof.records[0])
            first[0] = first[0][:-1]
            mutations = {
                "code": "TRAVERSAL_READ",
                "operation": "wrong_operation",
                "records": (tuple(first),) + source_proof.records[1:],
                "records_sha256": "sha256:" + "f" * 64,
                "winner": None,
                "root": not source_proof.root,
                "inventory": not source_proof.inventory,
                "requested_depth": (
                    0 if source_proof.requested_depth is None else None
                ),
                "requested_token": (
                    "retained" if source_proof.requested_token is None
                    else "retained/sibling"
                ),
                "parent_token": "retained/sibling",
                "parent_identity": ("FFFFFFFF", "0000000000000099"),
                "requested_component": "unexpected",
                "observed_winner_token": "retained/unexpected",
                "duplicate_nonwinner": source_proof.records
                + (source_proof.records[-1],),
            }
            for field, replacement in mutations.items():
                changed_values = dict(base_values)
                if field == "duplicate_nonwinner":
                    changed_values["records"] = replacement
                else:
                    changed_values[field] = replacement
                changed_proof = builder.R11CopiedRecordProof(**changed_values)
                changed_diagnostic = with_record_proof(
                    source_diagnostic, changed_proof,
                )
                with (
                    self.subTest(proof=proof_code, field=field),
                    patch.object(builder, "_r11_publish_preconstructed") as proof_publish,
                    patch.object(builder, "publish_json_no_replace") as proof_legacy,
                ):
                    if field == "parent_token" and source_proof.root:
                        builder.r11_validate_diagnostic(changed_diagnostic)
                        frozen_owner = builder.R11BoundaryOwner(
                            "STAGED_OUTPUT_VALIDATE",
                            (("prefix", "DONE"),),
                            None,
                            None,
                            lifecycle_token=source_proof.parent_token,
                        )
                        with self.assertRaises(ValueError):
                            frozen_owner.translate(changed_diagnostic, None)
                    else:
                        with self.assertRaises(
                            (TypeError, ValueError, UnicodeError),
                        ):
                            builder.r11_validate_diagnostic(
                                changed_diagnostic,
                            )
                proof_publish.assert_not_called()
                proof_legacy.assert_not_called()
            operand_values = {
                key: value
                for key, value in source_diagnostic.operands.items()
                if key != "operation" and value is not None
            }
            if source_proof.root:
                operand_values["path_token"] = "retained"
                operand_values["component_index"] = 1
            else:
                operand_values.pop("path_token", None)
                operand_values["component_index"] = 0
            closure_mutation = builder.R11TraversalDiagnostic(
                source_diagnostic.code,
                source_diagnostic.operands["operation"],
                **operand_values,
                record_proof=source_proof,
            )
            with self.subTest(proof=proof_code, field="root_nonroot_closure"), self.assertRaises(
                ValueError,
            ):
                builder.r11_validate_diagnostic(closure_mutation)

    def test_r11_39_recovery_has_one_negative_implementation_and_no_receipt_helper(self) -> None:
        source = SCRIPT_PATH.read_text(encoding="utf-8")
        self.assertEqual(source.count("def recover_interrupted("), 1)
        self.assertNotIn("def _recover_path_token(", source)
        recovery_source = inspect.getsource(builder.recover_interrupted)
        for prohibited in (
            "windows_file_receipt", "validate_ordered_bytecode",
            "validate_target_artifact_data", "validate_authoritative_output",
            "shutil.rmtree", "path.exists", "path.is_file",
        ):
            self.assertNotIn(prohibited, recovery_source)

    def test_r11_40_post_complete_installed_close_is_escape_only(self) -> None:
        owner = builder.R11BoundaryOwner(
            "INSTALLED_INVENTORY",
            (("prefix", "CLEAN"), ("selected_file_token", None)),
            None,
            None,
            lifecycle_token="installed",
        )
        diagnostic = builder.R11TraversalDiagnostic(
            "TRAVERSAL_HANDLE_CLOSE",
            "close_child",
            component_index=1,
            path_token="installed/nested/a.json",
            winerror=5,
            identity_before=r11_test_identity(),
        )
        with patch.object(builder, "_r11_first_red", wraps=builder._r11_first_red) as constructor:
            escaped = builder._r11_installed_close_failure(
                diagnostic,
                read_set_complete=True,
                inventory_owner=owner,
            )
            self.assertIs(escaped, diagnostic)
            constructor.assert_not_called()
        translated = builder._r11_installed_close_failure(
            diagnostic,
            read_set_complete=False,
            inventory_owner=owner,
        )
        self.assertEqual(
            translated.first_red["code"],
            "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION",
        )
        with self.assertRaises(TypeError):
            builder._r11_installed_close_failure(
                diagnostic,
                read_set_complete=1,  # type: ignore[arg-type]
                inventory_owner=owner,
            )

    def test_r11_41_boundary_state_extremes_and_identity_read_state_are_exhaustive(self) -> None:
        for code, literal_cells in R11_LITERAL_NATIVE_OUTCOME_ROWS.items():
            if literal_cells[1] == "X":
                continue
            diagnostic = r11_complete_diagnostic(code)
            for complete, count, expected_code in (
                (False, None, "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION"),
                (True, 0, "PORTABLE_INPUT_BUILD_INFO_COUNT"),
                (True, 1, "OP_PORTABLE_BUILD_INFO_LOOKUP_EXCEPTION"),
                (True, 2, "PORTABLE_INPUT_BUILD_INFO_COUNT"),
            ):
                translated = builder.r11_translate_diagnostic(
                    diagnostic,
                    "PORTABLE_BUILD_INFO_LOOKUP",
                    {
                        "group_index": 0,
                        "count_complete": complete,
                        "actual_count": count,
                    },
                )
                with self.subTest(code=code, complete=complete, count=count):
                    self.assertEqual(translated.first_red["code"], expected_code)

        for code in (
            "TRAVERSAL_ROOT_IDENTITY_CHANGED",
            "TRAVERSAL_IDENTITY_CHANGED",
        ):
            diagnostic = r11_complete_diagnostic(code)
            base = copy.deepcopy(r11_boundary_states()["ARTIFACT_READ"])
            read_state = {
                "before_identity": copy.deepcopy(diagnostic.operands["identity_before"]),
                "after_identity": copy.deepcopy(diagnostic.operands["identity_after"]),
                "before_size": 0,
                "after_size": 1,
                "read_byte_count": 0,
            }
            base["read_state"] = read_state
            self.assertEqual(
                builder.r11_translate_diagnostic(
                    diagnostic, "ARTIFACT_READ", copy.deepcopy(base),
                ).first_red["code"],
                "ARTIFACT_FILE_IDENTITY_MISMATCH",
            )
            mutations: list[tuple[str, dict[str, Any]]] = []
            for member in tuple(read_state):
                missing = copy.deepcopy(base)
                missing["read_state"].pop(member)
                mutations.append((f"missing-{member}", missing))
                null = copy.deepcopy(base)
                null["read_state"][member] = None
                mutations.append((f"null-{member}", null))
                wrong = copy.deepcopy(base)
                wrong["read_state"][member] = object()
                mutations.append((f"wrong-{member}", wrong))
            extra = copy.deepcopy(base)
            extra["read_state"]["extra"] = None
            mutations.append(("extra", extra))
            reordered = copy.deepcopy(base)
            reordered["read_state"] = dict(
                reversed(tuple(reordered["read_state"].items()))
            )
            mutations.append(("reordered", reordered))
            for label, mutation in mutations:
                with self.subTest(code=code, mutation=label), self.assertRaises((TypeError, ValueError)):
                    builder.r11_translate_diagnostic(
                        diagnostic, "ARTIFACT_READ", mutation,
                    )

        for invalid in (
            None,
            "a.json",
            "nested/a.json",
            "C:/a.json",
            "installed\\a.json",
            "/installed/a.json",
        ):
            state = {
                "prefix": "CLEAN",
                "selected_file_token": invalid,
            }
            with self.subTest(ir_token=invalid), self.assertRaises((TypeError, ValueError)):
                builder._r11_validate_boundary_state("INSTALLED_READ", state)
        for endpoint in (0, 9_007_199_254_740_991):
            builder._r11_validate_boundary_state(
                "PORTABLE_BUILD_INFO_LOOKUP",
                {
                    "group_index": 0,
                    "count_complete": True,
                    "actual_count": endpoint,
                },
            )
        for overflow in (-1, True, 9_007_199_254_740_992):
            with self.subTest(overflow=overflow), self.assertRaises(ValueError):
                builder._r11_validate_boundary_state(
                    "PORTABLE_BUILD_INFO_LOOKUP",
                    {
                        "group_index": 0,
                        "count_complete": True,
                        "actual_count": overflow,
                    },
                )

    def test_r11_42_privilege_adjustment_and_final_proof_fault_table(self) -> None:
        wanted = (0x11223344, -7)
        original = r11_token_snapshot([(*wanted, 0)])
        enabled = r11_token_snapshot([(*wanted, SE_PRIVILEGE_ENABLED)])
        unrelated = (0x55667788, 9, 0x80000004)
        full_original = r11_token_snapshot([unrelated, (*wanted, 0)])
        full_enabled = r11_token_snapshot(
            [unrelated, (*wanted, SE_PRIVILEGE_ENABLED)]
        )

        class AdjustmentFault(R11PrivilegeFake):
            def __init__(self, snapshots: list[bytes], mode: str) -> None:
                super().__init__(snapshots)
                self.mode = mode

            def AdjustTokenPrivileges(self, *args: Any) -> bool:
                result = super().AdjustTokenPrivileges(*args)
                buffer_length = args[3]
                if buffer_length:
                    if self.mode == "enable_zero":
                        ctypes.set_last_error(5)
                        return False
                    if self.mode == "enable_1300":
                        ctypes.set_last_error(ERROR_NOT_ALL_ASSIGNED)
                    elif self.mode == "enable_other":
                        ctypes.set_last_error(5)
                elif self.mode == "restore_zero":
                    ctypes.set_last_error(6)
                    return False
                return result

        class CloseFault(R11KernelFake):
            def CloseHandle(self, handle: Any) -> bool:
                self.close_calls.append(handle)
                ctypes.set_last_error(6)
                return False

        fault_rows = {
            "enable_zero": [original, original],
            "enable_1300": [original, original],
            "enable_other": [original, original],
            "post_missing": [original, r11_token_snapshot([(1, 2, 0)]), original],
            "post_duplicate": [
                original,
                r11_token_snapshot([(*wanted, 2), (*wanted, 2)]),
                original,
            ],
            "post_disabled": [original, original, original],
            "post_extra_bit": [
                original,
                r11_token_snapshot([(*wanted, SE_PRIVILEGE_ENABLED | 4)]),
                original,
            ],
            "post_unrelated_extra": [
                full_original,
                r11_token_snapshot(
                    [unrelated, (0xAABBCCDD, -11, 2), (*wanted, 2)]
                ),
                full_original,
            ],
            "post_unrelated_missing": [
                full_original, enabled, full_original,
            ],
            "post_unrelated_bit": [
                full_original,
                r11_token_snapshot(
                    [(unrelated[0], unrelated[1], unrelated[2] ^ 0x20), (*wanted, 2)]
                ),
                full_original,
            ],
            "restore_zero": [original, enabled, original],
            "final_missing": [original, enabled, r11_token_snapshot([(1, 2, 0)])],
            "final_duplicate": [
                original,
                enabled,
                r11_token_snapshot([(*wanted, 0), (*wanted, 0)]),
            ],
            "final_mismatch": [
                original,
                enabled,
                r11_token_snapshot([(*wanted, 4)]),
            ],
            "final_unrelated_extra": [
                full_original,
                full_enabled,
                r11_token_snapshot(
                    [unrelated, (0xAABBCCDD, -11, 2), (*wanted, 0)]
                ),
            ],
            "final_unrelated_missing": [
                full_original, full_enabled, original,
            ],
            "final_unrelated_bit": [
                full_original,
                full_enabled,
                r11_token_snapshot(
                    [(unrelated[0], unrelated[1], unrelated[2] ^ 0x20), (*wanted, 0)]
                ),
            ],
            "close_zero": [original, enabled, original],
        }
        for mode, snapshots in fault_rows.items():
            fake = AdjustmentFault(snapshots, mode)
            kernel: R11KernelFake = CloseFault() if mode == "close_zero" else R11KernelFake()

            def fixture(mark_owned: Any, _kernel: Any) -> None:
                mark_owned(lambda: None)

            with self.subTest(mode=mode), self.assertRaises(BaseException):
                r11_run_privileged_fixture(
                    fixture,
                    native=(fake, kernel),
                )
            self.assertEqual(len(kernel.close_calls), 1)
            expected_adjusts = 1 if mode == "enable_zero" else 2
            self.assertEqual(len(fake.adjust_calls), expected_adjusts)
            if fake.adjust_calls:
                enable_call = fake.adjust_calls[0]
                requested = ctypes.cast(
                    enable_call[2], ctypes.POINTER(TOKEN_PRIVILEGES_ONE),
                ).contents
                self.assertEqual(requested.PrivilegeCount, 1)
                self.assertEqual(
                    (
                        int(requested.Privileges[0].Luid.LowPart),
                        int(requested.Privileges[0].Luid.HighPart),
                        int(requested.Privileges[0].Attributes),
                    ),
                    (*wanted, SE_PRIVILEGE_ENABLED),
                )
            if len(fake.adjust_calls) == 2:
                restore = ctypes.cast(
                    fake.adjust_calls[1][2],
                    ctypes.POINTER(TOKEN_PRIVILEGES_ONE),
                ).contents
                self.assertEqual(
                    (
                        int(restore.Privileges[0].Luid.LowPart),
                        int(restore.Privileges[0].Luid.HighPart),
                        int(restore.Privileges[0].Attributes),
                    ),
                    (*wanted, 0),
                )

    def test_r11_43_durable_start_latch_survives_all_twelve_base_exceptions(self) -> None:
        class CustomBaseFailure(BaseException):
            pass

        failure_types = (
            KeyboardInterrupt,
            MemoryError,
            SystemExit,
            CustomBaseFailure,
        )
        stages = ("before_write", "after_readback", "publisher_after_write")
        for stage in stages:
            for failure_type in failure_types:
                marker = failure_type(f"{stage}-{failure_type.__name__}")

                class InterruptJournal(_R11NonPublishingJournalHarness):
                    interrupt_after_readback = False

                    def __setattr__(self, name: str, value: Any) -> None:
                        if (
                            self.interrupt_after_readback
                            and name == "state"
                            and value == "CALL_OPEN(0)"
                        ):
                            raise marker
                        super().__setattr__(name, value)

                journal = InterruptJournal(
                    Path("C:/evidence"),
                    r11_hash("invocation"),
                    {},
                    Path("C:/forge.exe"),
                    Path("C:/solc.exe"),
                    held_evidence_directory_identity=r11_test_identity(),
                    pre_started_checkpoint=r11_checkpoint("pre-started"),
                )
                journal.sequence = 0
                journal.event_head_sha256 = r11_hash("started")
                journal.checkpoints = [r11_checkpoint("pre-started")]
                journal.state = "STARTED_IDLE"
                journal.interrupt_after_readback = stage == "after_readback"
                durable: list[str] = []

                def publisher(*_args: Any, **_kwargs: Any) -> None:
                    if stage == "before_write":
                        raise marker
                    durable.append("start")
                    if stage == "publisher_after_write":
                        raise marker

                captured = Mock()
                terminal = Mock()
                with (
                    self.subTest(stage=stage, failure=failure_type.__name__),
                    patch.object(journal, "_checkpoint", return_value=r11_checkpoint("invocation-000-before")),
                    patch.object(builder, "_r11_publish_preconstructed", side_effect=publisher),
                    patch.object(builder, "_captured_subprocess", captured),
                    patch.object(journal, "publish_terminal", terminal),
                    self.assertRaises(BaseException) as raised,
                ):
                    journal.invoke(
                        0,
                        ["C:/forge.exe", "--version"],
                        Path("C:/repo"),
                        phase="forge_version",
                        group_string=None,
                    )
                self.assertIs(raised.exception, marker)
                self.assertEqual(
                    tuple(journal.guard or {}),
                    ("ordinal", "phase", "group_string", "start_event_sha256"),
                )
                self.assertEqual(journal.state, "START_PUBLISHING(0)")
                captured.assert_not_called()
                terminal.assert_not_called()
                self.assertEqual(
                    durable,
                    [] if stage == "before_write" else ["start"],
                )

    def test_r11_44_complete_recovery_namespace_is_strictly_negative(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-recovery-namespace-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            matching = root / "matching.bin"
            matching.write_bytes(b"matching")
            mutated = root / "mutated.bin"
            missing = root / "missing.bin"
            unreadable = root / "unreadable"
            unreadable.mkdir()

            def seed(case: str) -> tuple[Path, dict[str, Any]]:
                evidence = root / case
                evidence.mkdir()
                mutated.write_bytes(b"before")
                missing.write_bytes(b"present")
                started, _ = r11_canonical_recovery_started(
                    evidence,
                    matching=matching,
                    mutated=mutated,
                    missing=missing,
                    unreadable=unreadable,
                )
                builder._r11_validate_event(started)
                builder.publish_json_no_replace(
                    evidence, "execution-started.json", started,
                )
                mutated.write_bytes(b"after")
                missing.unlink()
                return evidence, started

            def invocation_start(started: dict[str, Any]) -> dict[str, Any]:
                def literal_bytes(value: Any) -> bytes:
                    return (
                        json.dumps(
                            value,
                            sort_keys=True,
                            separators=(",", ":"),
                            ensure_ascii=False,
                            allow_nan=False,
                        )
                        + "\n"
                    ).encode("utf-8", "strict")

                checkpoint = copy.deepcopy(
                    started["operands"]["pre_started_checkpoint"],
                )
                checkpoint["label"] = "invocation-000-before"
                executable = str(mutated)
                argv = [executable, "--version"]
                environment = {"FOUNDRY_PROFILE": "default"}
                return {
                    "schema": R11_LITERAL_EVENT_SCHEMA,
                    "invocation_id": started["invocation_id"],
                    "sequence": 1,
                    "previous_event_sha256": (
                        "sha256:" + hashlib.sha256(literal_bytes(started)).hexdigest()
                    ),
                    "event_type": "invocation_start",
                    "phase": "forge_version",
                    "operands": {
                        "ordinal": 0,
                        "group_string": None,
                        "executable": executable,
                        "argv": argv,
                        "argv_sha256": (
                            "sha256:" + hashlib.sha256(literal_bytes(argv)).hexdigest()
                        ),
                        "environment_sha256": (
                            "sha256:"
                            + hashlib.sha256(literal_bytes(environment)).hexdigest()
                        ),
                        "environment_entry_count": 1,
                        "cwd": str(root),
                        "start_monotonic_ms": 1,
                        "checkpoint": checkpoint,
                    },
                }

            def invocation_exit(
                started: dict[str, Any],
                start: dict[str, Any],
            ) -> dict[str, Any]:
                checkpoint = copy.deepcopy(
                    started["operands"]["pre_started_checkpoint"],
                )
                checkpoint["label"] = "invocation-000-after"
                empty_sha256 = "sha256:" + hashlib.sha256(b"").hexdigest()
                return {
                    "schema": R11_LITERAL_EVENT_SCHEMA,
                    "invocation_id": started["invocation_id"],
                    "sequence": 2,
                    "previous_event_sha256": literal_object_digest(start),
                    "event_type": "invocation_exit",
                    "phase": "forge_version",
                    "operands": {
                        "ordinal": 0,
                        "group_string": None,
                        "launched": True,
                        "exit_code": 0,
                        "start_monotonic_ms": 1,
                        "end_monotonic_ms": 1,
                        "stdout_byte_count": 0,
                        "stdout_sha256": empty_sha256,
                        "stderr_byte_count": 0,
                        "stderr_sha256": empty_sha256,
                        "exception_type": None,
                        "exception_sha256": None,
                        "checkpoint": checkpoint,
                    },
                }

            def literal_object_digest(value: Any) -> str:
                raw = (
                    json.dumps(
                        value,
                        sort_keys=True,
                        separators=(",", ":"),
                        ensure_ascii=False,
                        allow_nan=False,
                    )
                    + "\n"
                ).encode("utf-8", "strict")
                return "sha256:" + hashlib.sha256(raw).hexdigest()

            def reverse_durable_mappings(value: Any) -> Any:
                if isinstance(value, dict):
                    return dict(reversed(tuple(
                        (
                            key,
                            reverse_durable_mappings(member),
                        )
                        for key, member in value.items()
                    )))
                if isinstance(value, list):
                    return [
                        reverse_durable_mappings(member) for member in value
                    ]
                return copy.deepcopy(value)

            def literal_recovery_expected(
                started: dict[str, Any],
                prefix: list[dict[str, Any]],
                anomalies: list[dict[str, Any]],
            ) -> dict[str, Any]:
                event_values = [started, *prefix]
                event_receipts = [literal_object_digest(event) for event in event_values]
                return {
                    "schema": R11_LITERAL_TERMINAL_SCHEMA,
                    "invocation_id": started["invocation_id"],
                    "status": "NO_GO",
                    "first_red": {
                        "code": "interrupted_execution",
                        "operands": {},
                    },
                    "event_count": len(event_values),
                    "event_head_sha256": event_receipts[-1],
                    "calls": [],
                    "checkpoints": [],
                    "results": {
                        "recovery": True,
                        "path_token_status": [],
                        "anomalies": sorted(
                            copy.deepcopy(anomalies),
                            key=lambda item: item["path_token"],
                        ),
                        "sentinel_sha256": event_receipts[0],
                        "predicates_evaluated": 0,
                        "subprocess_calls": 0,
                        "output_validated": False,
                    },
                    "no_retry": True,
                }

            def assert_exact_terminal_file(
                evidence: Path, terminal: dict[str, Any],
            ) -> None:
                expected_raw = (
                    json.dumps(
                        terminal,
                        sort_keys=True,
                        separators=(",", ":"),
                        ensure_ascii=False,
                        allow_nan=False,
                    )
                    + "\n"
                ).encode("utf-8", "strict")
                self.assertEqual(
                    builder.canonical_evidence_bytes(terminal), expected_raw,
                )
                self.assertEqual(
                    (evidence / "terminal.json").read_bytes(), expected_raw,
                )

            @contextmanager
            def forbid_recovery_external_surfaces() -> Iterator[None]:
                function_names = (
                    "windows_file_receipt",
                    "_r11_read_path",
                    "_r11_output_must_be_absent",
                    "_r11_load_build_info_input",
                    "_r11_metadata_and_bindings",
                    "_r11_snapshot_tree",
                    "_r11_read_retained_output",
                    "_r11_install_output_no_replace",
                    "_r11_cleanup_build_temp",
                    "_build_release_output_evidence_r11",
                    "validate_authoritative_output",
                    "read_required_bytes",
                    "load_json_snapshot",
                    "load_json_with_sha256",
                    "load_json",
                    "load_foundry_profile",
                    "validate_foundry_profile",
                    "validate_compiler_input",
                    "load_build_info_input",
                    "load_retained_compiler_input_with_sha256",
                    "load_retained_compiler_input",
                    "validate_target_artifact_data",
                    "validate_target_artifact",
                    "find_target_artifact",
                    "validate_ordered_bytecode",
                    "run_forge",
                    "read_forge_version",
                    "validate_release_output_with_snapshots",
                    "validate_release_output",
                    "install_output_no_replace",
                    "build_release_output",
                    "r11_validate_builder_terminal",
                )
                with ExitStack() as stack:
                    forbidden = {
                        name: stack.enter_context(patch.object(builder, name))
                        for name in function_names
                    }
                    forbidden["ExecutionJournal.publish_terminal"] = (
                        stack.enter_context(
                            patch.object(builder.ExecutionJournal, "publish_terminal")
                        )
                    )
                    forbidden["Path.open"] = stack.enter_context(
                        patch.object(Path, "open")
                    )
                    forbidden["Path.read_bytes"] = stack.enter_context(
                        patch.object(Path, "read_bytes")
                    )
                    forbidden["subprocess.run"] = stack.enter_context(
                        patch.object(subprocess, "run")
                    )
                    try:
                        yield
                    finally:
                        for surface in forbidden.values():
                            surface.assert_not_called()

            def recover_restricted(
                evidence: Path,
                *,
                expected_publications: int | None = None,
            ) -> dict[str, Any]:
                with forbid_recovery_external_surfaces():
                    if expected_publications is None:
                        return builder.recover_interrupted(evidence)
                    with patch.object(
                        builder,
                        "_r11_publish_preconstructed",
                        wraps=builder._r11_publish_preconstructed,
                    ) as exclusive_publisher:
                        recovered = builder.recover_interrupted(evidence)
                    self.assertEqual(
                        exclusive_publisher.call_count,
                        expected_publications,
                    )
                    return recovered

            empty = root / "empty"
            empty.mkdir()
            with (
                patch.object(builder, "_r11_publish_preconstructed") as empty_publish,
                self.assertRaises(builder.EvidenceFailure) as empty_recovery,
            ):
                recover_restricted(empty)
            self.assertEqual(empty_recovery.exception.code, "EMPTY")
            empty_publish.assert_not_called()
            self.assertFalse((empty / "terminal.json").exists())
            builder._close_active_evidence_locks()

            sentinel_missing = root / "sentinel-missing"
            sentinel_missing.mkdir()
            (sentinel_missing / "residue.tmp").write_bytes(b"residue")
            with (
                patch.object(builder, "_r11_publish_preconstructed") as missing_publish,
                self.assertRaises(builder.EvidenceFailure) as missing_recovery,
            ):
                recover_restricted(sentinel_missing)
            self.assertEqual(missing_recovery.exception.code, "SENTINEL_MISSING")
            missing_publish.assert_not_called()
            self.assertFalse((sentinel_missing / "terminal.json").exists())
            builder._close_active_evidence_locks()

            terminal_present, _ = seed("terminal-present")
            existing_terminal = b'{"preserve":true}\n'
            (terminal_present / "terminal.json").write_bytes(existing_terminal)
            with (
                patch.object(builder, "_r11_publish_preconstructed") as terminal_publish,
                self.assertRaises(builder.EvidenceFailure) as terminal_recovery,
            ):
                recover_restricted(terminal_present)
            self.assertEqual(terminal_recovery.exception.code, "TERMINAL")
            terminal_publish.assert_not_called()
            self.assertEqual(
                (terminal_present / "terminal.json").read_bytes(),
                existing_terminal,
            )
            builder._close_active_evidence_locks()

            noncanonical = root / "noncanonical-started"
            noncanonical.mkdir()
            (noncanonical / "execution-started.json").write_bytes(b"{ }\n")
            with (
                patch.object(builder, "_r11_publish_preconstructed") as malformed_publish,
                self.assertRaises(builder.EvidenceFailure) as bad_started,
            ):
                recover_restricted(noncanonical)
            self.assertEqual(bad_started.exception.code, "NONCANONICAL_EVIDENCE")
            malformed_publish.assert_not_called()
            self.assertFalse((noncanonical / "terminal.json").exists())
            builder._close_active_evidence_locks()

            odd, odd_started = seed("odd-prefix")
            odd_start = invocation_start(odd_started)
            odd_exit = invocation_exit(odd_started, odd_start)
            for event_id, event in (
                ("STARTED", odd_started),
                ("start", odd_start),
                ("exit", odd_exit),
            ):
                reordered_event = reverse_durable_mappings(event)
                with self.subTest(durable_event_reorder=event_id):
                    builder._r11_validate_event(reordered_event)
                    self.assertEqual(
                        builder.canonical_evidence_bytes(reordered_event),
                        builder.canonical_evidence_bytes(event),
                    )
            builder.publish_json_no_replace(
                odd, "invocation-000-start.json", odd_start,
            )
            odd_expected = literal_recovery_expected(
                odd_started, [odd_start], [],
            )
            odd_terminal = recover_restricted(
                odd, expected_publications=1,
            )
            self.assertEqual(odd_terminal, odd_expected)
            assert_exact_terminal_file(odd, odd_expected)
            self.assertEqual(odd_terminal["event_count"], 2)
            self.assertEqual(odd_terminal["results"]["anomalies"], [])
            self.assertEqual(odd_terminal["results"]["path_token_status"], [])
            for wrong_first_red in (
                {"code": "interrupted_execution", "operands": {"extra": None}},
                {"code": "FORGE_VERSION_FORMAT", "operands": {}},
                None,
            ):
                mutated_terminal = copy.deepcopy(odd_terminal)
                mutated_terminal["first_red"] = wrong_first_red
                with self.subTest(first_red=wrong_first_red), self.assertRaises(
                    builder.EvidenceFailure,
                ):
                    r11_validate_literal_recovery_terminal(
                        mutated_terminal, odd_terminal,
                    )

            literal_terminal = r11_recovery_terminal()
            self.assertEqual(
                tuple(literal_terminal), R11_LITERAL_RECOVERY_TOP_KEYS,
            )
            self.assertEqual(
                tuple(literal_terminal["results"]),
                R11_LITERAL_RECOVERY_RESULT_KEYS,
            )
            self.assertEqual(
                tuple(literal_terminal["first_red"]),
                R11_LITERAL_RECOVERY_FIRST_RED_KEYS,
            )
            r11_validate_literal_recovery_terminal(
                literal_terminal, literal_terminal,
            )
            literal_terminal_raw = (
                json.dumps(
                    literal_terminal,
                    ensure_ascii=False,
                    allow_nan=False,
                    sort_keys=True,
                    separators=(",", ":"),
                ).encode("utf-8", "strict")
                + b"\n"
            )
            self.assertEqual(
                literal_terminal_raw, R11_LITERAL_RECOVERY_TERMINAL_RAW,
            )
            self.assertEqual(len(literal_terminal_raw), 601)
            self.assertEqual(
                hashlib.sha256(literal_terminal_raw).hexdigest(),
                "9d154dbe120cb216ac4c30595e0828ba948b032bdbf88f2a3cdc1441e8fb01d1",
            )

            def wrong_major(value: Any) -> Any:
                if type(value) is bool:
                    return 0
                if type(value) is int:
                    return "0"
                if isinstance(value, str):
                    return {}
                if isinstance(value, dict):
                    return []
                if isinstance(value, list):
                    return {}
                if value is None:
                    return 0
                raise AssertionError("unlisted recovery major type")

            rejected_terminals: list[tuple[str, dict[str, Any]]] = []
            accepted_reordered_terminals: list[
                tuple[str, dict[str, Any], dict[str, Any]]
            ] = []
            for key in R11_LITERAL_RECOVERY_TOP_KEYS:
                missing_top = copy.deepcopy(literal_terminal)
                missing_top.pop(key)
                rejected_terminals.append((f"top:{key}:missing", missing_top))
                null_top = copy.deepcopy(literal_terminal)
                null_top[key] = None
                rejected_terminals.append((f"top:{key}:null", null_top))
                wrong_top = copy.deepcopy(literal_terminal)
                wrong_top[key] = wrong_major(literal_terminal[key])
                rejected_terminals.append((f"top:{key}:wrong", wrong_top))
                extra_top = copy.deepcopy(literal_terminal)
                extra_top["_extra"] = None
                rejected_terminals.append((f"top:{key}:extra", extra_top))
            non_string_top = copy.deepcopy(literal_terminal)
            non_string_top[1] = None
            rejected_terminals.append(("top:non-string-key", non_string_top))
            for key in R11_LITERAL_RECOVERY_RESULT_KEYS:
                missing_result = copy.deepcopy(literal_terminal)
                missing_result["results"].pop(key)
                rejected_terminals.append((f"result:{key}:missing", missing_result))
                null_result = copy.deepcopy(literal_terminal)
                null_result["results"][key] = None
                rejected_terminals.append((f"result:{key}:null", null_result))
                wrong_result = copy.deepcopy(literal_terminal)
                wrong_result["results"][key] = wrong_major(
                    literal_terminal["results"][key],
                )
                rejected_terminals.append((f"result:{key}:wrong", wrong_result))
                extra_result = copy.deepcopy(literal_terminal)
                extra_result["results"]["_extra"] = None
                rejected_terminals.append((f"result:{key}:extra", extra_result))
            non_string_result = copy.deepcopy(literal_terminal)
            non_string_result["results"][1] = None
            rejected_terminals.append((
                "result:non-string-key", non_string_result,
            ))
            for key in R11_LITERAL_RECOVERY_FIRST_RED_KEYS:
                missing_first = copy.deepcopy(literal_terminal)
                missing_first["first_red"].pop(key)
                rejected_terminals.append((f"first:{key}:missing", missing_first))
                null_first = copy.deepcopy(literal_terminal)
                null_first["first_red"][key] = None
                rejected_terminals.append((f"first:{key}:null", null_first))
                wrong_first = copy.deepcopy(literal_terminal)
                wrong_first["first_red"][key] = wrong_major(
                    literal_terminal["first_red"][key],
                )
                rejected_terminals.append((f"first:{key}:wrong", wrong_first))
                extra_first = copy.deepcopy(literal_terminal)
                extra_first["first_red"]["_extra"] = None
                rejected_terminals.append((f"first:{key}:extra", extra_first))
            non_string_first = copy.deepcopy(literal_terminal)
            non_string_first["first_red"][1] = None
            rejected_terminals.append((
                "first:non-string-key", non_string_first,
            ))
            for relationship, replacement in (
                ("invocation_id", r11_hash("other-invocation")),
                ("event_count", 3),
                ("event_head_sha256", r11_hash("other-head")),
            ):
                changed_relationship = copy.deepcopy(literal_terminal)
                changed_relationship[relationship] = replacement
                rejected_terminals.append(
                    (f"relationship:{relationship}", changed_relationship),
                )
            changed_sentinel = copy.deepcopy(literal_terminal)
            changed_sentinel["results"]["sentinel_sha256"] = r11_hash(
                "other-sentinel",
            )
            rejected_terminals.append(
                ("relationship:sentinel_sha256", changed_sentinel),
            )

            def adjacent_swap(
                mapping: dict[str, Any],
                left_index: int,
            ) -> dict[str, Any]:
                rows = list(mapping.items())
                rows[left_index], rows[left_index + 1] = (
                    rows[left_index + 1], rows[left_index]
                )
                return dict(rows)

            for index in range(len(R11_LITERAL_RECOVERY_TOP_KEYS) - 1):
                reordered_top = adjacent_swap(literal_terminal, index)
                accepted_reordered_terminals.append((
                    f"top:adjacent-swap:{index}",
                    reordered_top,
                    literal_terminal,
                ))
            for index in range(len(R11_LITERAL_RECOVERY_RESULT_KEYS) - 1):
                reordered_result = copy.deepcopy(literal_terminal)
                reordered_result["results"] = adjacent_swap(
                    reordered_result["results"], index,
                )
                accepted_reordered_terminals.append((
                    f"result:adjacent-swap:{index}",
                    reordered_result,
                    literal_terminal,
                ))
            for index in range(len(R11_LITERAL_RECOVERY_FIRST_RED_KEYS) - 1):
                reordered_first = copy.deepcopy(literal_terminal)
                reordered_first["first_red"] = adjacent_swap(
                    reordered_first["first_red"], index,
                )
                accepted_reordered_terminals.append((
                    f"first:adjacent-swap:{index}",
                    reordered_first,
                    literal_terminal,
                ))

            invalid_path = "invocation-000-start.json"
            invalid_hash = "sha256:" + hashlib.sha256(
                (
                    json.dumps(
                        {
                            "code": "EVENT_PREFIX_INVALID",
                            "path_token": invalid_path,
                        },
                        sort_keys=True,
                        separators=(",", ":"),
                    )
                    + "\n"
                ).encode("utf-8")
            ).hexdigest()
            invalid_anomaly = {
                "path_token": invalid_path,
                "status": "invalid",
                "exception_type": "EVENT_PREFIX_INVALID",
                "message_sha256": invalid_hash,
            }
            anomaly_terminal = copy.deepcopy(literal_terminal)
            anomaly_terminal["results"]["anomalies"] = [invalid_anomaly]
            r11_validate_literal_recovery_terminal(
                anomaly_terminal, literal_terminal,
            )
            for key in R11_LITERAL_RECOVERY_ANOMALY_KEYS:
                for mutation_name in ("missing", "extra", "null", "wrong"):
                    changed_anomaly = copy.deepcopy(anomaly_terminal)
                    item = changed_anomaly["results"]["anomalies"][0]
                    if mutation_name == "missing":
                        item.pop(key)
                    elif mutation_name == "extra":
                        item["_extra"] = None
                    elif mutation_name == "null":
                        item[key] = None
                    else:
                        item[key] = wrong_major(invalid_anomaly[key])
                    rejected_terminals.append(
                        (f"anomaly:{key}:{mutation_name}", changed_anomaly),
                    )
            non_string_anomaly = copy.deepcopy(anomaly_terminal)
            non_string_anomaly["results"]["anomalies"][0][1] = None
            rejected_terminals.append((
                "anomaly:non-string-key", non_string_anomaly,
            ))
            for index in range(len(R11_LITERAL_RECOVERY_ANOMALY_KEYS) - 1):
                reordered_anomaly_keys = copy.deepcopy(anomaly_terminal)
                reordered_anomaly_keys["results"]["anomalies"][0] = (
                    adjacent_swap(
                        reordered_anomaly_keys["results"]["anomalies"][0],
                        index,
                    )
                )
                accepted_reordered_terminals.append((
                    f"anomaly:adjacent-swap:{index}",
                    reordered_anomaly_keys,
                    anomaly_terminal,
                ))
            for invalid_token in (
                "", ".", "..", "/absolute", "C:/native",
                "native\\path", "a/../b", "a//b", "a/trailing.",
                "a/trailing ", "a\x00b",
            ):
                invalid_path_terminal = copy.deepcopy(anomaly_terminal)
                invalid_path_terminal["results"]["anomalies"][0][
                    "path_token"
                ] = invalid_token
                rejected_terminals.append(
                    (f"anomaly:invalid-path:{invalid_token!r}", invalid_path_terminal),
                )
            unlinked_anomaly = {
                "path_token": "residue.tmp",
                "status": "unlinked",
                "exception_type": None,
                "message_sha256": None,
            }
            two_anomalies = copy.deepcopy(literal_terminal)
            two_anomalies["results"]["anomalies"] = [
                invalid_anomaly, unlinked_anomaly,
            ]
            r11_validate_literal_recovery_terminal(
                two_anomalies, literal_terminal,
            )
            reordered_anomalies = copy.deepcopy(two_anomalies)
            reordered_anomalies["results"]["anomalies"].reverse()
            rejected_terminals.append(("anomaly:reordered", reordered_anomalies))
            duplicate_anomalies = copy.deepcopy(two_anomalies)
            duplicate_anomalies["results"]["anomalies"][1][
                "path_token"
            ] = invalid_path
            rejected_terminals.append(("anomaly:duplicate", duplicate_anomalies))
            for label, field, value in (
                ("status", "status", "unknown"),
                ("exception-null", "exception_type", None),
                ("hash-null", "message_sha256", None),
                ("hash-wrong", "message_sha256", r11_hash("wrong-event")),
            ):
                changed_anomaly = copy.deepcopy(anomaly_terminal)
                changed_anomaly["results"]["anomalies"][0][field] = value
                rejected_terminals.append((f"anomaly:{label}", changed_anomaly))
            unlinked_with_exception = copy.deepcopy(literal_terminal)
            unlinked_with_exception["results"]["anomalies"] = [
                {**unlinked_anomaly, "exception_type": "EVENT_PREFIX_INVALID"},
            ]
            rejected_terminals.append(
                ("anomaly:unlinked-exception", unlinked_with_exception),
            )
            unlinked_with_hash = copy.deepcopy(literal_terminal)
            unlinked_with_hash["results"]["anomalies"] = [
                {**unlinked_anomaly, "message_sha256": r11_hash("not-null")},
            ]
            rejected_terminals.append(
                ("anomaly:unlinked-hash", unlinked_with_hash),
            )
            with (
                forbid_recovery_external_surfaces(),
                patch.object(
                    builder, "_r11_publish_preconstructed",
                ) as mutation_publication,
            ):
                for mutation_id, mutation, baseline in (
                    accepted_reordered_terminals
                ):
                    with self.subTest(recovery_reorder=mutation_id):
                        r11_validate_literal_recovery_terminal(
                            mutation, literal_terminal,
                        )
                        self.assertEqual(
                            builder.canonical_evidence_bytes(mutation),
                            builder.canonical_evidence_bytes(baseline),
                        )
                for mutation_id, mutation in rejected_terminals:
                    with self.subTest(recovery_mutation=mutation_id), self.assertRaises(
                        (builder.EvidenceFailure, TypeError, ValueError),
                    ):
                        r11_validate_literal_recovery_terminal(
                            mutation, literal_terminal,
                        )
            mutation_publication.assert_not_called()
            builder._close_active_evidence_locks()

            identity_mismatch, mismatch_started = seed("identity-mismatch")
            builder._r11_validate_event(mismatch_started)
            held_identity = mismatch_started["operands"][
                "held_evidence_directory_identity"
            ]
            current_identity = {
                "volume_serial": held_identity["volume_serial"],
                "file_index": "0000000000000999",
            }
            drifted_lock = Mock(identity=current_identity)
            builder.publish_json_no_replace(
                identity_mismatch, "identity-drift-canary.json", {"drift": True},
            )
            with (
                patch.object(
                    builder.WindowsDirectoryLock,
                    "acquire",
                    return_value=drifted_lock,
                ),
                patch.object(builder, "_r11_publish_preconstructed") as mismatch_publish,
                self.assertRaises(builder.EvidenceFailure) as mismatch_recovery,
            ):
                recover_restricted(identity_mismatch)
            self.assertEqual(
                mismatch_recovery.exception.code,
                "RECOVERY_EVIDENCE_IDENTITY",
            )
            mismatch_publish.assert_not_called()
            drifted_lock.close.assert_called_once_with()
            self.assertFalse((identity_mismatch / "terminal.json").exists())
            builder._close_active_evidence_locks()

            invalid, invalid_started = seed("invalid-prefix")
            invalid_token = "invocation-000-start.json"
            (invalid / invalid_token).write_bytes(b"{}\n")
            invalid_expected = literal_recovery_expected(
                invalid_started,
                [],
                [{
                    "path_token": invalid_token,
                    "status": "invalid",
                    "exception_type": "EVENT_PREFIX_INVALID",
                    "message_sha256": literal_object_digest(
                        {
                            "code": "EVENT_PREFIX_INVALID",
                            "path_token": invalid_token,
                        }
                    ),
                }],
            )
            invalid_terminal = recover_restricted(
                invalid, expected_publications=1,
            )
            self.assertEqual(invalid_terminal, invalid_expected)
            assert_exact_terminal_file(invalid, invalid_expected)
            self.assertEqual(
                invalid_terminal["results"]["anomalies"][0]["status"],
                "invalid",
            )
            builder._close_active_evidence_locks()

            duplicate, duplicate_started = seed("duplicate-prefix")
            duplicate_start = invocation_start(duplicate_started)
            builder.publish_json_no_replace(
                duplicate, "invocation-000-start.json", duplicate_start,
            )
            builder.publish_json_no_replace(
                duplicate, "invocation-000-exit.json", duplicate_start,
            )
            duplicate_expected = literal_recovery_expected(
                duplicate_started,
                [duplicate_start],
                [{
                    "path_token": "invocation-000-exit.json",
                    "status": "invalid",
                    "exception_type": "EVENT_PREFIX_INVALID",
                    "message_sha256": literal_object_digest(
                        {
                            "code": "EVENT_PREFIX_INVALID",
                            "path_token": "invocation-000-exit.json",
                        }
                    ),
                }],
            )
            duplicate_terminal = recover_restricted(
                duplicate, expected_publications=1,
            )
            self.assertEqual(duplicate_terminal, duplicate_expected)
            assert_exact_terminal_file(duplicate, duplicate_expected)
            self.assertEqual(
                duplicate_terminal["results"]["anomalies"][0]["path_token"],
                "invocation-000-exit.json",
            )
            self.assertEqual(
                duplicate_terminal["results"]["anomalies"][0]["status"],
                "invalid",
            )
            builder._close_active_evidence_locks()

            unlinked, unlinked_started = seed("unlinked")
            (unlinked / "residue.tmp").write_bytes(b"residue")
            unlinked_expected = literal_recovery_expected(
                unlinked_started,
                [],
                [{
                    "path_token": "residue.tmp",
                    "status": "unlinked",
                    "exception_type": None,
                    "message_sha256": None,
                }],
            )
            unlinked_terminal = recover_restricted(
                unlinked, expected_publications=1,
            )
            self.assertEqual(unlinked_terminal, unlinked_expected)
            assert_exact_terminal_file(unlinked, unlinked_expected)
            self.assertEqual(
                unlinked_terminal["results"]["anomalies"],
                [{
                    "path_token": "residue.tmp",
                    "status": "unlinked",
                    "exception_type": None,
                    "message_sha256": None,
                }],
            )
            builder._close_active_evidence_locks()

            above_head, above_started = seed("above-head")
            above_token = "invocation-017-exit.json"
            (above_head / above_token).write_bytes(b"{}\n")
            above_expected = literal_recovery_expected(
                above_started,
                [],
                [{
                    "path_token": above_token,
                    "status": "unlinked",
                    "exception_type": None,
                    "message_sha256": None,
                }],
            )
            above_terminal = recover_restricted(
                above_head, expected_publications=1,
            )
            self.assertEqual(above_terminal, above_expected)
            assert_exact_terminal_file(above_head, above_expected)
            self.assertEqual(
                above_terminal["results"]["anomalies"][0]["path_token"],
                above_token,
            )
            self.assertEqual(
                above_terminal["results"]["anomalies"][0]["status"],
                "unlinked",
            )
            builder._close_active_evidence_locks()

            unreadable_child, unreadable_started = seed("unreadable-child")
            builder.publish_json_no_replace(
                unreadable_child,
                "invocation-000-start.json",
                invocation_start(unreadable_started),
            )
            original_read = builder.R11RetainedTree.read_file

            def fail_evidence_child(
                retained: Any,
                relative: str,
                *,
                on_read_failure: Any = None,
            ) -> bytes:
                if relative == "invocation-000-start.json":
                    raise builder.R11TraversalDiagnostic(
                        "TRAVERSAL_READ",
                        "read_child",
                        component_index=0,
                        path_token="evidence/invocation-000-start.json",
                        winerror=5,
                        identity_before=r11_test_identity(),
                    )
                return original_read(
                    retained,
                    relative,
                    on_read_failure=on_read_failure,
                )

            unreadable_expected = literal_recovery_expected(
                unreadable_started,
                [],
                [{
                    "path_token": "invocation-000-start.json",
                    "status": "invalid",
                    "exception_type": "TRAVERSAL_READ",
                    "message_sha256": literal_object_digest(
                        {
                            "code": "TRAVERSAL_READ",
                            "operands": {
                                "operation": "read_child",
                                "component_index": 0,
                                "path_token": (
                                    "evidence/invocation-000-start.json"
                                ),
                                "winerror": 5,
                                "expected_attributes": None,
                                "actual_attributes": None,
                                "identity_before": r11_test_identity(),
                                "identity_after": None,
                            },
                        }
                    ),
                }],
            )
            with patch.object(
                builder.R11RetainedTree,
                "read_file",
                side_effect=fail_evidence_child,
                autospec=True,
            ):
                unreadable_terminal = recover_restricted(
                    unreadable_child, expected_publications=1,
                )
            self.assertEqual(unreadable_terminal, unreadable_expected)
            assert_exact_terminal_file(unreadable_child, unreadable_expected)
            self.assertEqual(
                unreadable_terminal["results"]["anomalies"][0]["status"],
                "invalid",
            )
            builder._close_active_evidence_locks()

            collision, _ = seed("publication-collision")
            collision_before = {
                child.name: child.read_bytes()
                for child in collision.iterdir() if child.is_file()
            }
            with (
                patch.object(
                    builder,
                    "_r11_publish_preconstructed",
                    side_effect=builder.EvidenceFailure(
                        "EVIDENCE_PUBLICATION_COLLISION", "fixture",
                    ),
                ),
                self.assertRaises(builder.EvidenceFailure) as publication,
            ):
                recover_restricted(collision)
            self.assertEqual(publication.exception.code, "EVIDENCE_PUBLICATION_COLLISION")
            self.assertFalse((collision / "terminal.json").exists())
            self.assertEqual(
                {
                    child.name: child.read_bytes()
                    for child in collision.iterdir() if child.is_file()
                },
                collision_before,
            )
            builder._close_active_evidence_locks()

    def test_r11_45_all_38_bytecode_reds_execute_at_targets_one_and_nineteen(self) -> None:
        placeholder = "__$" + "a" * 34 + "$__"
        literal_false_codes = {
            ordinal: codes for ordinal, codes in R11_LITERAL_BYTECODE_FALSE_ROWS
        }
        false_codes = {
            code
            for codes in literal_false_codes.values()
            for code in codes
        }
        operation_codes = {
            f"OP_{R4_BYTECODE_STEP_IDS[ordinal - 1]}_EXCEPTION"
            for ordinal in R11_LITERAL_OPERATION_ORDINALS
        }
        self.assertEqual(
            tuple((ordinal, tuple(codes)) for ordinal, codes in builder.R11_BYTECODE_FALSE_CODES.items()),
            R11_LITERAL_BYTECODE_FALSE_ROWS,
        )
        self.assertEqual(
            tuple(sorted(builder._R11_OPERATION_STEPS)),
            R11_LITERAL_OPERATION_ORDINALS,
        )
        self.assertEqual(len(false_codes), 31)
        self.assertEqual(len(operation_codes), 7)
        self.assertEqual(len(false_codes | operation_codes), 38)

        def false_fixture(
            authority: dict[str, Any],
            code: str,
        ) -> tuple[dict[str, Any], dict[str, Any], Any]:
            candidate = r4_bytecode_artifact(authority)
            effective_authority = dict(authority)
            hook = None
            if code == "BC_CREATION_MISSING":
                candidate.pop("bytecode")
            elif code == "BC_CREATION_NOT_OBJECT":
                candidate["bytecode"] = []
            elif code == "BC_CREATION_OBJECT_MISSING":
                candidate["bytecode"].pop("object")
            elif code == "BC_CREATION_OBJECT_NOT_STRING":
                candidate["bytecode"]["object"] = 1
            elif code == "BC_CREATION_EMPTY":
                candidate["bytecode"]["object"] = ""
            elif code == "BC_CREATION_ODD_LENGTH":
                candidate["bytecode"]["object"] = "0"
            elif code == "BC_CREATION_UNRESOLVED_PLACEHOLDER":
                candidate["bytecode"]["object"] = placeholder
            elif code == "BC_CREATION_NON_HEX":
                candidate["bytecode"]["object"] = "gg"
            elif code == "BC_CREATION_LINKS_MISSING":
                candidate["bytecode"].pop("linkReferences")
            elif code == "BC_CREATION_LINKS_NOT_OBJECT":
                candidate["bytecode"]["linkReferences"] = []
            elif code == "BC_CREATION_LINKS_NONEMPTY":
                candidate["bytecode"]["linkReferences"] = {"A.sol": {}}
            elif code == "BC_RUNTIME_MISSING":
                candidate.pop("deployedBytecode")
            elif code == "BC_RUNTIME_NOT_OBJECT":
                candidate["deployedBytecode"] = []
            elif code == "BC_RUNTIME_OBJECT_MISSING":
                candidate["deployedBytecode"].pop("object")
            elif code == "BC_RUNTIME_OBJECT_NOT_STRING":
                candidate["deployedBytecode"]["object"] = 1
            elif code == "BC_RUNTIME_EMPTY":
                candidate["deployedBytecode"]["object"] = ""
            elif code == "BC_RUNTIME_ODD_LENGTH":
                candidate["deployedBytecode"]["object"] = "0"
            elif code == "BC_RUNTIME_UNRESOLVED_PLACEHOLDER":
                candidate["deployedBytecode"]["object"] = placeholder
            elif code == "BC_RUNTIME_NON_HEX":
                candidate["deployedBytecode"]["object"] = "gg"
            elif code == "BC_RUNTIME_LINKS_MISSING":
                candidate["deployedBytecode"].pop("linkReferences")
            elif code == "BC_RUNTIME_LINKS_NOT_OBJECT":
                candidate["deployedBytecode"]["linkReferences"] = []
            elif code == "BC_RUNTIME_LINKS_NONEMPTY":
                candidate["deployedBytecode"]["linkReferences"] = {"A.sol": {}}
            elif code == "ABI_NOT_ARRAY":
                candidate["abi"] = {}
            elif code == "ABI_CONSTRUCTOR_COUNT":
                candidate["abi"] = []
            elif code == "ABI_CONSTRUCTOR_TYPES_ORDER":
                candidate["abi"][0]["inputs"][0]["type"] = "uint256"
            elif code == "ABI_CONSTRUCTOR_SIGNATURE":
                effective_authority["signature"] = "constructor(bytes32)"
            elif code == "ABI_CONSTRUCTOR_WORDS":
                effective_authority["words"] += 1
            elif code == "ABI_CONSTRUCTOR_WIDTH":
                effective_authority["bytes"] += 32
            elif code == "SIZE_INITCODE_LIMIT":
                candidate = r4_bytecode_artifact(
                    authority,
                    creation_bytes=builder.R4_INITCODE_LIMIT - authority["bytes"],
                )
            elif code == "SIZE_RUNTIME_PACKET_LIMIT":
                candidate = r4_bytecode_artifact(
                    authority,
                    runtime_bytes=builder.R4_RUNTIME_PACKET_LIMIT,
                )
            elif code == "SIZE_RUNTIME_TARGET_CAP":
                candidate = r4_bytecode_artifact(
                    authority,
                    runtime_bytes=authority["runtime_cap"] + 1,
                )
            elif code in operation_codes:
                operation_id = code.removeprefix("OP_").removesuffix("_EXCEPTION")

                def fail_operation(
                    step: str,
                    _operands: dict[str, Any],
                    *,
                    selected: str = operation_id,
                ) -> None:
                    if step == selected:
                        raise RuntimeError(selected)

                hook = fail_operation
            else:
                raise AssertionError(f"unmaterialized bytecode red: {code}")
            return candidate, effective_authority, hook

        selected_authorities = (
            r11_literal_authority(0),
            r11_literal_authority(18),
        )

        def literal_trace(authority: dict[str, Any]) -> list[dict[str, Any]]:
            rows: list[dict[str, Any]] = []
            for ordinal, step_id, kind, status, operands_items, result_value, error in R11_LITERAL_STORE_TRACE_ROWS:
                operands = dict(operands_items)
                if "target" in operands:
                    operands["target"] = authority["target"]
                for key in ("actual_types", "expected_types", "input_types"):
                    if key in operands:
                        operands[key] = list(authority["input_types"])
                result = (
                    dict(result_value)
                    if isinstance(result_value, tuple)
                    else result_value
                )
                if ordinal == 18:
                    result = {
                        "signature": authority["signature"],
                        "words": authority["words"],
                        "bytes": authority["bytes"],
                    }
                elif ordinal == 19:
                    operands.update(
                        {
                            "actual_signature": authority["signature"],
                            "expected_signature": authority["signature"],
                            "actual_words": authority["words"],
                            "expected_words": authority["words"],
                            "actual_bytes": authority["bytes"],
                            "expected_bytes": authority["bytes"],
                        }
                    )
                elif ordinal == 21:
                    operands["constructor_bytes"] = authority["bytes"]
                    result = {
                        "creation_bytes": 1,
                        "constructor_bytes": authority["bytes"],
                        "full_initcode_bytes": authority["bytes"] + 1,
                    }
                elif ordinal == 22:
                    operands["actual"] = authority["bytes"] + 1
                elif ordinal == 25:
                    operands["threshold"] = authority["runtime_cap"]
                rows.append(
                    {
                        "ordinal": ordinal,
                        "id": step_id,
                        "kind": kind,
                        "status": status,
                        "operands": operands,
                        "result": result,
                        "error_code": error,
                    }
                )
            return rows

        def text_hash(value: str) -> str:
            return "sha256:" + hashlib.sha256(value.encode("utf-8")).hexdigest()

        def false_operands(
            authority: dict[str, Any],
            code: str,
            pass_trace: list[dict[str, Any]],
        ) -> dict[str, Any]:
            step = next(
                ordinal for ordinal, _priority, row_code
                in R11_LITERAL_BYTECODE_CASE_ROWS if row_code == code
            )
            operands = copy.deepcopy(pass_trace[step - 1]["operands"])
            mutations: dict[str, dict[str, Any]] = {
                "BC_CREATION_MISSING": {"present": False, "actual_type": None},
                "BC_CREATION_NOT_OBJECT": {"present": True, "actual_type": "array"},
                "BC_CREATION_OBJECT_MISSING": {"present": False, "actual_type": None},
                "BC_CREATION_OBJECT_NOT_STRING": {"present": True, "actual_type": "integer"},
                "BC_CREATION_EMPTY": {"length": 0, "sha256": text_hash("")},
                "BC_CREATION_ODD_LENGTH": {"length": 1, "sha256": text_hash("0")},
                "BC_CREATION_UNRESOLVED_PLACEHOLDER": {"length": len(placeholder), "sha256": text_hash(placeholder)},
                "BC_CREATION_NON_HEX": {"length": 2, "sha256": text_hash("gg")},
                "BC_CREATION_LINKS_MISSING": {"present": False, "actual_type": None, "entry_count": None},
                "BC_CREATION_LINKS_NOT_OBJECT": {"present": True, "actual_type": "array", "entry_count": None},
                "BC_CREATION_LINKS_NONEMPTY": {"present": True, "actual_type": "object", "entry_count": 1},
                "BC_RUNTIME_MISSING": {"present": False, "actual_type": None},
                "BC_RUNTIME_NOT_OBJECT": {"present": True, "actual_type": "array"},
                "BC_RUNTIME_OBJECT_MISSING": {"present": False, "actual_type": None},
                "BC_RUNTIME_OBJECT_NOT_STRING": {"present": True, "actual_type": "integer"},
                "BC_RUNTIME_EMPTY": {"length": 0, "sha256": text_hash("")},
                "BC_RUNTIME_ODD_LENGTH": {"length": 1, "sha256": text_hash("0")},
                "BC_RUNTIME_UNRESOLVED_PLACEHOLDER": {"length": len(placeholder), "sha256": text_hash(placeholder)},
                "BC_RUNTIME_NON_HEX": {"length": 2, "sha256": text_hash("gg")},
                "BC_RUNTIME_LINKS_MISSING": {"present": False, "actual_type": None, "entry_count": None},
                "BC_RUNTIME_LINKS_NOT_OBJECT": {"present": True, "actual_type": "array", "entry_count": None},
                "BC_RUNTIME_LINKS_NONEMPTY": {"present": True, "actual_type": "object", "entry_count": 1},
                "ABI_NOT_ARRAY": {
                    "abi_present": True, "abi_type": "object",
                    "constructor_count": None, "inputs_present": None,
                    "inputs_type": None, "actual_types": None,
                },
                "ABI_CONSTRUCTOR_COUNT": {
                    "abi_present": True, "abi_type": "array",
                    "constructor_count": 0, "inputs_present": None,
                    "inputs_type": None, "actual_types": None,
                },
                "ABI_CONSTRUCTOR_TYPES_ORDER": {
                    "actual_types": [
                        "uint256", *authority["input_types"][1:],
                    ],
                },
                "ABI_CONSTRUCTOR_SIGNATURE": {
                    "expected_signature": "constructor(bytes32)",
                },
                "ABI_CONSTRUCTOR_WORDS": {
                    "expected_words": authority["words"] + 1,
                },
                "ABI_CONSTRUCTOR_WIDTH": {
                    "expected_bytes": authority["bytes"] + 32,
                },
                "SIZE_INITCODE_LIMIT": {
                    "actual": 49_152, "operator": "<", "threshold": 49_152,
                },
                "SIZE_RUNTIME_PACKET_LIMIT": {
                    "actual": 24_576, "operator": "<", "threshold": 24_576,
                },
                "SIZE_RUNTIME_TARGET_CAP": {
                    "actual": authority["runtime_cap"] + 1,
                    "operator": "<=", "threshold": authority["runtime_cap"],
                },
            }
            operands.update(mutations.get(code, {}))
            return operands

        def exact_failed_trace(
            authority: dict[str, Any],
            candidate: dict[str, Any],
            code: str,
            expected_step: int,
            expected_operands: dict[str, Any],
            pass_trace: list[dict[str, Any]],
        ) -> list[dict[str, Any]]:
            trace = copy.deepcopy(pass_trace[:expected_step])

            def replace_text_prefix(
                raw_text: str,
                operation_ordinal: int,
                shape_ordinals: tuple[int, ...],
            ) -> str:
                normalized = (
                    raw_text[2:]
                    if raw_text.startswith(("0x", "0X"))
                    else raw_text
                )
                raw_sha = text_hash(raw_text)
                normalized_sha = text_hash(normalized)
                if operation_ordinal <= expected_step:
                    trace[operation_ordinal - 1]["operands"] = {
                        "target": authority["target"],
                        "input_length": len(raw_text),
                        "input_sha256": raw_sha,
                    }
                    if operation_ordinal != expected_step:
                        trace[operation_ordinal - 1]["result"] = {
                            "input_length": len(raw_text),
                            "input_sha256": raw_sha,
                            "output_length": len(normalized),
                            "output_sha256": normalized_sha,
                            "prefix_removed": normalized != raw_text,
                        }
                for ordinal in shape_ordinals:
                    if ordinal <= expected_step:
                        trace[ordinal - 1]["operands"] = {
                            "target": authority["target"],
                            "length": len(normalized),
                            "sha256": normalized_sha,
                        }
                return normalized

            creation_text_codes = {
                "BC_CREATION_EMPTY", "BC_CREATION_ODD_LENGTH",
                "BC_CREATION_UNRESOLVED_PLACEHOLDER", "BC_CREATION_NON_HEX",
                "SIZE_INITCODE_LIMIT",
            }
            runtime_text_codes = {
                "BC_RUNTIME_EMPTY", "BC_RUNTIME_ODD_LENGTH",
                "BC_RUNTIME_UNRESOLVED_PLACEHOLDER", "BC_RUNTIME_NON_HEX",
                "SIZE_RUNTIME_PACKET_LIMIT", "SIZE_RUNTIME_TARGET_CAP",
            }
            if code in creation_text_codes:
                creation_text = candidate["bytecode"]["object"]
                creation_normalized = replace_text_prefix(
                    creation_text, 3, (4, 5, 6, 7),
                )
                if expected_step >= 20:
                    creation_bytes = len(bytes.fromhex(creation_normalized))
                    trace[19]["operands"] = {
                        "target": authority["target"],
                        "input_length": len(creation_normalized),
                        "input_sha256": text_hash(creation_normalized),
                    }
                    trace[19]["result"] = {
                        "byte_count": creation_bytes,
                        "sha256": "sha256:" + hashlib.sha256(
                            bytes.fromhex(creation_normalized),
                        ).hexdigest(),
                    }
                    if expected_step >= 21:
                        trace[20]["operands"] = {
                            "target": authority["target"],
                            "creation_bytes": creation_bytes,
                            "constructor_bytes": authority["bytes"],
                        }
                        trace[20]["result"] = {
                            "creation_bytes": creation_bytes,
                            "constructor_bytes": authority["bytes"],
                            "full_initcode_bytes": (
                                creation_bytes + authority["bytes"]
                            ),
                        }
            if code in runtime_text_codes:
                runtime_text = candidate["deployedBytecode"]["object"]
                runtime_normalized = replace_text_prefix(
                    runtime_text, 11, (12, 13, 14, 15),
                )
                if expected_step >= 23:
                    runtime_raw = bytes.fromhex(runtime_normalized)
                    runtime_bytes = len(runtime_raw)
                    trace[22]["operands"] = {
                        "target": authority["target"],
                        "input_length": len(runtime_normalized),
                        "input_sha256": text_hash(runtime_normalized),
                    }
                    trace[22]["result"] = {
                        "byte_count": runtime_bytes,
                        "sha256": "sha256:" + hashlib.sha256(
                            runtime_raw,
                        ).hexdigest(),
                    }
                    for ordinal, operator, threshold in (
                        (24, "<", 24_576),
                        (25, "<=", authority["runtime_cap"]),
                    ):
                        if ordinal <= expected_step:
                            trace[ordinal - 1]["operands"] = {
                                "target": authority["target"],
                                "actual": runtime_bytes,
                                "operator": operator,
                                "threshold": threshold,
                            }
            trace[-1]["operands"] = expected_operands
            trace[-1]["status"] = (
                "exception" if code in operation_codes else "false"
            )
            trace[-1]["result"] = None if code in operation_codes else False
            trace[-1]["error_code"] = code
            return trace

        literal_calls = [
            {
                "ordinal": ordinal,
                "phase": phase,
                "group_string": (
                    None if ordinal == 0 else R4_GROUP_STRINGS[ordinal - 1]
                ),
                "start_event_sha256": r11_hash(f"call-{ordinal}-start"),
                "exit_event_sha256": r11_hash(f"call-{ordinal}-exit"),
                "argv_sha256": r11_hash(f"call-{ordinal}-argv"),
                "environment_sha256": r11_hash("forge-environment"),
                "launched": True,
                "exit_code": 0,
                "stdout_byte_count": 0,
                "stdout_sha256": r11_hash("empty-stdout"),
                "stderr_byte_count": 0,
                "stderr_sha256": r11_hash("empty-stderr"),
                "exception_type": None,
                "exception_sha256": None,
            }
            for ordinal, phase, _group in R11_LITERAL_CALL_SCHEDULE
        ]
        literal_events = [f"event-{index:02d}" for index in range(37)]
        literal_checkpoints = [r11_checkpoint("pre-started")]
        for ordinal in range(18):
            literal_checkpoints.extend(
                (
                    r11_checkpoint(f"invocation-{ordinal:03d}-before"),
                    r11_checkpoint(f"invocation-{ordinal:03d}-after"),
                )
            )
        authority_drift_codes = {
            "ABI_CONSTRUCTOR_SIGNATURE",
            "ABI_CONSTRUCTOR_WORDS",
            "ABI_CONSTRUCTOR_WIDTH",
        }
        executed_case_ids: list[str] = []
        safe_case_ids: list[str] = []
        authority_rejected_case_ids: list[str] = []
        authority_rejected_pairs: list[tuple[int, str]] = []
        trace_state_mutation_ids: list[str] = []
        trace_state_steps: set[int] = set()
        with tempfile.TemporaryDirectory(
            prefix="r11-bytecode-reds-", dir=REPO_ROOT.parent,
        ) as safe_temp:
            for target_position, authority in (
                (1, selected_authorities[0]),
                (19, selected_authorities[1]),
            ):
                pass_trace = literal_trace(authority)
                for suffix, (expected_step, _priority, code) in enumerate(
                    R11_LITERAL_BYTECODE_CASE_ROWS, start=1,
                ):
                    candidate, effective_authority, hook = false_fixture(
                        authority, code,
                    )
                    case_id = f"BC_T{target_position:02d}_{suffix:02d}"
                    self.assertIsInstance(case_id, str)
                    expected_operands = false_operands(
                        authority, code, pass_trace,
                    )
                    failed_trace = exact_failed_trace(
                        authority,
                        candidate,
                        code,
                        expected_step,
                        expected_operands,
                        pass_trace,
                    )
                    safe_results = r11_literal_bytecode_failure_results(
                        target_position, failed_trace,
                    )
                    target_state = R11_LITERAL_TARGET_STATE_ROWS[
                        target_position - 1
                    ]
                    first_red = {
                        "phase": "bytecode",
                        "code": code,
                        "call_ordinal": int(target_state[4]) + 1,
                        "group_index": int(target_state[4]),
                        "group_string": target_state[4] + "::" + target_state[2],
                        "semantic_id": target_state[0],
                        "target": target_state[1],
                        "step_ordinal": expected_step,
                        "step_id": R4_BYTECODE_STEP_IDS[expected_step - 1],
                        "operands": expected_operands,
                    }
                    observed: list[str] = []
                    with (
                        patch.object(builder, "_r11_publish_preconstructed") as evidence_publish,
                        patch.object(builder, "publish_json_no_replace") as legacy_publish,
                    ):
                        failure = assert_r4_failure(
                            self,
                            code,
                            builder.validate_ordered_bytecode,
                            candidate,
                            effective_authority,
                            step_observer=lambda step, _operands: observed.append(step),
                            operation_hook=hook,
                        )
                    evidence_publish.assert_not_called()
                    legacy_publish.assert_not_called()
                    self.assertTrue(failure.operands)
                    self.assertEqual(len(observed), expected_step)
                    self.assertEqual(observed, list(R4_BYTECODE_STEP_IDS[:expected_step]))
                    self.assertEqual(failure.operands, expected_operands)
                    executed_case_ids.append(case_id)
                    builder._r11_validate_first_red(
                        first_red, safe_results, literal_calls,
                    )
                    if code in authority_drift_codes:
                        authority_terminal = r11_literal_staged_nogo_terminal(
                            copy.deepcopy(safe_results),
                            label=f"{case_id}-authority-rejection",
                        )
                        authority_terminal["first_red"] = copy.deepcopy(
                            first_red,
                        )
                        with (
                            patch.object(
                                builder, "_r11_publish_preconstructed",
                            ) as rejected_authority_publication,
                            self.assertRaises(
                                builder.EvidenceFailure,
                            ) as rejected_authority,
                        ):
                            builder.r11_validate_builder_terminal(
                                authority_terminal,
                            )
                        self.assertEqual(
                            rejected_authority.exception.code,
                            "TARGET_TRACE_DEPENDENCY",
                        )
                        rejected_authority_publication.assert_not_called()
                        authority_rejected_case_ids.append(case_id)
                        authority_rejected_pairs.append((target_position, code))
                        continue

                    case_directory = Path(safe_temp) / case_id
                    case_directory.mkdir()
                    bytecode_context = r11_independent_terminal_context(
                        case_directory,
                        first_red=first_red,
                        results=safe_results,
                    )
                    bytecode_frozen_terminal = copy.deepcopy(
                        bytecode_context["terminal"],
                    )
                    bytecode_frozen_raw = bytes(bytecode_context["raw"])
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(bytecode_frozen_terminal),
                        bytecode_frozen_raw,
                    )
                    self.assertEqual(
                        bytecode_context["terminal"], bytecode_frozen_terminal,
                    )
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(
                            bytecode_context["terminal"],
                        ),
                        bytecode_frozen_raw,
                    )
                    terminal, terminal_raw = (
                        r11_publish_literal_terminal_with_disk_parity(
                            self,
                            bytecode_context,
                            bytecode_frozen_terminal,
                            bytecode_frozen_raw,
                        )
                    )
                    self.assertEqual(terminal, bytecode_frozen_terminal)
                    self.assertEqual(terminal_raw, bytecode_frozen_raw)
                    self.assertEqual(
                        terminal_raw,
                        (
                            json.dumps(
                                terminal,
                                sort_keys=True,
                                separators=(",", ":"),
                                ensure_ascii=False,
                                allow_nan=False,
                            )
                            + "\n"
                        ).encode("utf-8", "strict"),
                    )
                    safe_case_ids.append(case_id)

                    if target_position == 1 and expected_step not in trace_state_steps:
                        trace_state_steps.add(expected_step)
                        active_state = safe_results["target_evaluations"][0]
                        cross_state = dict(zip(
                            R11_LITERAL_TARGET_STATE_KEYS,
                            R11_LITERAL_TARGET_STATE_ROWS[1],
                            strict=True,
                        ))
                        state_mutations = {
                            "semantic_id": cross_state["semantic_id"],
                            "target": cross_state["target"],
                            "source": cross_state["source"],
                            "size_ordinal": cross_state["size_ordinal"],
                            "emitting_group": cross_state["emitting_group"],
                            "file_read": False,
                            "artifact_byte_count": None,
                            "artifact_sha256": r11_hash("wrong-artifact").upper(),
                            "artifact_json_decoded": False,
                            "metadata_evaluated": False,
                            "metadata_admitted": False,
                            "bytecode_evaluated": False,
                            "bytecode_completed": True,
                            "bytecode_steps": active_state["bytecode_steps"]
                            + [copy.deepcopy(active_state["bytecode_steps"][-1])],
                        }
                        self.assertEqual(
                            tuple(state_mutations), R11_LITERAL_TARGET_STATE_KEYS,
                        )
                        for state_field, replacement in state_mutations.items():
                            changed_terminal = copy.deepcopy(terminal)
                            changed_terminal["results"]["target_evaluations"][0][
                                state_field
                            ] = replacement
                            mutation_id = (
                                f"{R4_BYTECODE_STEP_IDS[expected_step - 1]}::"
                                f"{state_field}"
                            )
                            with (
                                self.subTest(trace_state_cell=mutation_id),
                                patch.object(
                                    builder, "_r11_publish_preconstructed",
                                ) as rejected_state_publication,
                                self.assertRaises(
                                    (builder.EvidenceFailure, TypeError, ValueError),
                                ),
                            ):
                                builder.r11_validate_builder_terminal(
                                    changed_terminal,
                                )
                            rejected_state_publication.assert_not_called()
                            trace_state_mutation_ids.append(mutation_id)

                    def context_wrong_major(value: Any) -> Any:
                        if type(value) is int:
                            return "0"
                        if isinstance(value, str):
                            return {}
                        if isinstance(value, dict):
                            return []
                        if value is None:
                            return 0
                        raise AssertionError("unlisted first-red type")

                    self.assertEqual(
                        tuple(first_red), R11_LITERAL_BUILDER_FIRST_RED_KEYS,
                    )
                    for member in R11_LITERAL_BUILDER_FIRST_RED_KEYS:
                        for mutation_kind in (
                            "missing", "extra", "null", "wrong-major",
                        ):
                            changed_first_red = copy.deepcopy(first_red)
                            if mutation_kind == "missing":
                                changed_first_red.pop(member)
                            elif mutation_kind == "extra":
                                changed_first_red["_extra"] = None
                            elif mutation_kind == "null":
                                changed_first_red[member] = None
                            else:
                                changed_first_red[member] = context_wrong_major(
                                    first_red[member],
                                )
                            with self.subTest(
                                case_id=case_id,
                                context_member=member,
                                mutation=mutation_kind,
                            ), patch.object(
                                builder, "_r11_publish_preconstructed",
                            ) as rejected_publication, self.assertRaises(
                                (builder.EvidenceFailure, TypeError, ValueError),
                            ):
                                changed_terminal = copy.deepcopy(terminal)
                                changed_terminal["first_red"] = changed_first_red
                                builder.r11_validate_builder_terminal(
                                    changed_terminal,
                                )
                            rejected_publication.assert_not_called()
        expected_authority_rejected_pairs = {
            (target_position, code)
            for target_position in (1, 19)
            for code in authority_drift_codes
        }
        self.assertEqual(len(executed_case_ids), 76)
        self.assertEqual(len(set(executed_case_ids)), 76)
        self.assertEqual(len(safe_case_ids), 70)
        self.assertEqual(len(set(safe_case_ids)), 70)
        self.assertEqual(len(authority_rejected_case_ids), 6)
        self.assertEqual(len(set(authority_rejected_case_ids)), 6)
        self.assertEqual(
            set(authority_rejected_pairs),
            expected_authority_rejected_pairs,
        )
        self.assertEqual(
            set(executed_case_ids),
            set(safe_case_ids) | set(authority_rejected_case_ids),
        )
        self.assertTrue(
            set(safe_case_ids).isdisjoint(authority_rejected_case_ids),
        )
        self.assertEqual(len(trace_state_mutation_ids), 350)
        self.assertEqual(len(set(trace_state_mutation_ids)), 350)

    def test_r11_46_forge_priority_pairs_execute_in_exact_order(self) -> None:
        with tempfile.TemporaryDirectory(
            prefix="r11-forge-priority-", dir=REPO_ROOT.parent,
        ) as temp_dir:
            root = Path(temp_dir)
            evidence = root / "nonzero-evidence"
            evidence.mkdir()
            matching = root / "matching.bin"
            matching.write_bytes(b"matching")
            forge = root / "forge.exe"
            forge.write_bytes(b"forge")
            solc = root / "solc.exe"
            solc.write_bytes(b"solc")
            directory = root / "directory"
            directory.mkdir()
            started, static = r11_canonical_recovery_started(
                evidence,
                matching=matching,
                mutated=forge,
                missing=solc,
                unreadable=directory,
            )
            journal = _R11NonPublishingJournalHarness(
                evidence,
                started["invocation_id"],
                static,
                forge,
                solc,
                held_evidence_directory_identity=started["operands"][
                    "held_evidence_directory_identity"
                ],
                pre_started_checkpoint=started["operands"]["pre_started_checkpoint"],
            )
            journal.publish_started()
            with (
                patch.object(
                    builder,
                    "_captured_subprocess",
                    return_value=builder.CommandResult(
                        True, 7, b"\xff\r", b"stderr",
                    ),
                ) as captured,
                self.assertRaises(builder.R11BuilderFailure) as nonzero,
            ):
                journal.invoke(
                    0,
                    [str(forge), "--version"],
                    root,
                    phase="forge_version",
                    group_string=None,
                )
            captured.assert_called_once_with(
                [str(forge), "--version"],
                root,
                builder.sanitized_forge_environment(),
            )
            self.assertEqual(nonzero.exception.first_red["code"], "FORGE_NONZERO_EXIT")

            valid = R11ForgeFake.VERSION.encode("utf-8")
            priority_pairs = (
                (b"\xff\r", "FORGE_VERSION_UTF8"),
                (b"", "FORGE_VERSION_EMPTY"),
                (
                    valid.replace(b"\n", b"\r\n").replace(
                        b"Build Timestamp: fixture\r\n", b"",
                    ),
                    "FORGE_VERSION_FORMAT",
                ),
                (
                    valid.replace(b"Build Timestamp: fixture\n", b"").replace(
                        b"0" * 40, b"1" * 40,
                    ),
                    "FORGE_VERSION_TIMESTAMP_COUNT",
                ),
                (valid.replace(b"0" * 40, b"1" * 40), "FORGE_VERSION_MISMATCH"),
            )
            for raw, expected_code in priority_pairs:
                with self.subTest(priority=expected_code):
                    failure = assert_r4_failure(
                        self,
                        expected_code,
                        builder.r11_validate_forge_version_bytes,
                        raw,
                    )
                    self.assertTrue(failure.operands)

    def test_r11_47_boundary_tokens_execute_at_every_installed_position(self) -> None:
        omitted_token = object()
        names = (
            "a/repeat.json",
            "m/repeat.json",
            "z/repeat.json",
        )
        raw_by_name = {
            name: bytes([index + 1]) for index, name in enumerate(names)
        }
        expected = [
            {
                "path": name,
                "byte_count": 1,
                "sha256": builder.sha256_bytes(raw_by_name[name]),
            }
            for name in names
        ]

        class RetainedReadFault:
            def __init__(
                self,
                fault_index: int,
                diagnostic_token: str | None | object,
                diagnostic_code: str,
            ) -> None:
                self.root_token = "installed"
                self.fault_index = fault_index
                self.diagnostic_token = diagnostic_token
                self.diagnostic_code = diagnostic_code
                self.reads: list[str] = []
                self.last_diagnostic: builder.R11TraversalDiagnostic | None = None

            def topology(self) -> list[tuple[str, str]]:
                return [
                    ("a", "directory"),
                    ("a/repeat.json", "file"),
                    ("m", "directory"),
                    ("m/repeat.json", "file"),
                    ("z", "directory"),
                    ("z/repeat.json", "file"),
                ]

            def read_file(
                self,
                name: str,
                *,
                on_read_failure: Any = None,
            ) -> bytes:
                position = len(self.reads)
                self.reads.append(name)
                if position == self.fault_index:
                    operands = {
                        "component_index": position,
                        "winerror": 6,
                        "identity_before": r11_test_identity(),
                    }
                    if self.diagnostic_token is not omitted_token:
                        operands["path_token"] = self.diagnostic_token
                    diagnostic = builder.R11TraversalDiagnostic(
                        self.diagnostic_code,
                        "read_child"
                        if self.diagnostic_code == "TRAVERSAL_READ"
                        else "close_child",
                        **operands,
                    )
                    self.last_diagnostic = diagnostic
                    raise on_read_failure(diagnostic, None)
                return raw_by_name[name]

        rejected_token = {
            0: (
                "repeat.json",
                "installed/a/sibling.json",
                "installed/a",
                None,
                omitted_token,
                "C:/fixture/repeat.json",
                "\\\\?\\C:\\fixture\\repeat.json",
                "installed/m/repeat.json",
                "installed/z/repeat.json",
            ),
            1: (
                "repeat.json",
                "installed/m/sibling.json",
                "installed/m",
                None,
                omitted_token,
                "C:/fixture/repeat.json",
                "\\\\?\\C:\\fixture\\repeat.json",
                "installed/a/repeat.json",
                "installed/z/repeat.json",
            ),
            2: (
                "repeat.json",
                "installed/z/sibling.json",
                "installed/z",
                None,
                omitted_token,
                "C:/fixture/repeat.json",
                "\\\\?\\C:\\fixture\\repeat.json",
                "installed/a/repeat.json",
                "installed/m/repeat.json",
            ),
        }
        literal_calls = [
            {
                "ordinal": ordinal,
                "phase": phase,
                "group_string": (
                    None if ordinal == 0 else R4_GROUP_STRINGS[ordinal - 1]
                ),
                "start_event_sha256": r11_hash(f"d1-call-{ordinal}-start"),
                "exit_event_sha256": r11_hash(f"d1-call-{ordinal}-exit"),
                "argv_sha256": r11_hash(f"d1-call-{ordinal}-argv"),
                "environment_sha256": r11_hash("d1-forge-environment"),
                "launched": True,
                "exit_code": 0,
                "stdout_byte_count": 0,
                "stdout_sha256": r11_hash("d1-empty-stdout"),
                "stderr_byte_count": 0,
                "stderr_sha256": r11_hash("d1-empty-stderr"),
                "exception_type": None,
                "exception_sha256": None,
            }
            for ordinal, phase, _group in R11_LITERAL_CALL_SCHEDULE
        ]
        literal_checkpoints = [r11_checkpoint("pre-started")]
        for ordinal in range(18):
            literal_checkpoints.extend(
                (
                    r11_checkpoint(f"invocation-{ordinal:03d}-before"),
                    r11_checkpoint(f"invocation-{ordinal:03d}-after"),
                )
            )
        valid_publication_ids: list[str] = []
        rejected_selected_ids: list[str] = []

        def assert_one_valid_publication(
            case_id: str,
            prebuilt_context: dict[str, Any],
            frozen_terminal: dict[str, Any],
            frozen_raw: bytes,
        ) -> None:
            with nullcontext(prebuilt_context) as context:
                evidence_directory = context["evidence_directory"]
                publication_directory = context["publication_directory"]
                terminal = context["terminal"]
                self.assertEqual(terminal, frozen_terminal)
                self.assertEqual(context["raw"], frozen_raw)
                self.assertEqual(
                    r11_stdlib_canonical_bytes(frozen_terminal), frozen_raw,
                )
                journal = r11_materialize_candidate_journal(context)
                self.assertEqual(terminal, frozen_terminal)
                self.assertEqual(
                    r11_stdlib_canonical_bytes(terminal), frozen_raw,
                )
                if not valid_publication_ids:
                    event_bytes = [
                        (evidence_directory / builder._event_filename(sequence)).read_bytes()
                        for sequence in range(37)
                    ]

                    def event_array_variants() -> tuple[tuple[str, list[bytes]], ...]:
                        middle = len(event_bytes) // 2
                        last = len(event_bytes) - 1
                        variants: list[tuple[str, list[bytes]]] = [("empty", [])]
                        for label, index in (
                            ("first", 0), ("middle", middle), ("last", last),
                        ):
                            truncated = list(event_bytes)
                            truncated.pop(index)
                            variants.append((f"truncate-{label}", truncated))
                            duplicated = list(event_bytes)
                            duplicated.insert(index, duplicated[index])
                            variants.append((f"duplicate-{label}", duplicated))
                        variants.extend((
                            ("append", list(event_bytes) + [event_bytes[-1]]),
                            ("prepend", [event_bytes[0]] + list(event_bytes)),
                            ("reverse", list(reversed(event_bytes))),
                            (
                                "adjacent-swap",
                                [event_bytes[1], event_bytes[0], *event_bytes[2:]],
                            ),
                            (
                                "same-members-wrong-order",
                                [*event_bytes[1:], event_bytes[0]],
                            ),
                            (
                                "wrong-element-type",
                                [*event_bytes[:middle], b"1\n", *event_bytes[middle + 1:]],
                            ),
                            (
                                "null-element",
                                [*event_bytes[:middle], b"null\n", *event_bytes[middle + 1:]],
                            ),
                            (
                                "cross-target-element",
                                [*event_bytes[:middle], event_bytes[0], *event_bytes[middle + 1:]],
                            ),
                            ("extra-element", [*event_bytes, b"{}\n"]),
                        ))
                        return tuple(variants)

                    def materialize_event_array(values: list[bytes]) -> None:
                        for child in evidence_directory.iterdir():
                            if child.is_file():
                                child.unlink()
                        for sequence, raw_event in enumerate(values):
                            (
                                evidence_directory
                                / builder._event_filename(sequence)
                            ).write_bytes(raw_event)

                    with patch.object(
                        builder, "_r11_publish_preconstructed",
                    ) as event_publication:
                        for event_array_id, event_array in event_array_variants():
                            materialize_event_array(event_array)
                            with self.subTest(event_array=event_array_id):
                                if event_array_id in (
                                    "wrong-element-type", "null-element",
                                ):
                                    with self.assertRaises(
                                        builder.EvidenceFailure,
                                    ) as invalid_event_object:
                                        journal._candidate_terminal_gate(terminal)
                                    self.assertEqual(
                                        invalid_event_object.exception.code,
                                        "EVENT_SCHEMA",
                                    )
                                else:
                                    with self.assertRaises(
                                        (
                                            builder.EvidenceFailure,
                                            TypeError,
                                            ValueError,
                                        ),
                                    ):
                                        journal._candidate_terminal_gate(terminal)
                            materialize_event_array(event_bytes)
                    event_publication.assert_not_called()
                builder.r11_validate_builder_terminal(terminal)
                self.assertEqual(terminal, frozen_terminal)
                self.assertEqual(
                    r11_stdlib_canonical_bytes(terminal), frozen_raw,
                )
                journal._candidate_terminal_gate(terminal)
                self.assertEqual(terminal, frozen_terminal)
                self.assertEqual(
                    r11_stdlib_canonical_bytes(terminal), frozen_raw,
                )
                with (
                    patch.object(
                        builder,
                        "_r11_publish_preconstructed",
                        wraps=builder._r11_publish_preconstructed,
                    ) as publisher,
                    patch.object(
                        builder,
                        "publish_json_no_replace",
                        wraps=builder.publish_json_no_replace,
                    ) as ordinary_publisher,
                ):
                    builder._r11_publish_preconstructed(
                        publication_directory,
                        "terminal.json",
                        terminal,
                        frozen_raw,
                        "sha256:" + hashlib.sha256(frozen_raw).hexdigest(),
                    )
                    self.assertEqual(
                        (publication_directory / "terminal.json").read_bytes(),
                        frozen_raw,
                    )
                self.assertEqual(publisher.call_count, 1)
                self.assertEqual(ordinary_publisher.call_count, 1)
            valid_publication_ids.append(case_id)

        for position, name in enumerate(names):
            selected = "installed/" + name
            for diagnostic_code in (
                "TRAVERSAL_READ",
                "TRAVERSAL_HANDLE_CLOSE",
            ):
                literal_diagnostic_operands = {
                    "operation": (
                        "read_child"
                        if diagnostic_code == "TRAVERSAL_READ"
                        else "close_child"
                    ),
                    "component_index": position,
                    "path_token": selected,
                    "winerror": 6,
                    "expected_attributes": None,
                    "actual_attributes": None,
                    "identity_before": {
                        "volume_serial": "1234ABCD",
                        "file_index": "0000000000000001",
                    },
                    "identity_after": None,
                }
                literal_diagnostic_raw = r11_stdlib_canonical_bytes({
                    "code": diagnostic_code,
                    "operands": literal_diagnostic_operands,
                })
                expected_operands = {
                    "path_token": selected,
                    "exception_type": diagnostic_code,
                    "message_sha256": "sha256:"
                    + hashlib.sha256(literal_diagnostic_raw).hexdigest(),
                }
                expected_first_red = {
                    "phase": "installed_readback",
                    "code": "OP_INSTALLED_OUTPUT_READ_EXCEPTION",
                    "call_ordinal": None,
                    "group_index": None,
                    "group_string": None,
                    "semantic_id": None,
                    "target": None,
                    "step_ordinal": None,
                    "step_id": None,
                    "operands": expected_operands,
                }
                installed_state = r11_literal_complete_results(installed=True)
                with tempfile.TemporaryDirectory(
                    prefix="r11-boundary-parity-", dir=REPO_ROOT.parent,
                ) as parity_temp:
                    d1_context = r11_independent_terminal_context(
                        Path(parity_temp),
                        first_red=expected_first_red,
                        results=installed_state,
                    )
                    d1_frozen_terminal = copy.deepcopy(d1_context["terminal"])
                    d1_frozen_raw = bytes(d1_context["raw"])
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(d1_frozen_terminal),
                        d1_frozen_raw,
                    )
                    retained = RetainedReadFault(
                        position,
                        selected,
                        diagnostic_code,
                    )
                    captured_owners: list[builder.R11BoundaryOwner] = []
                    owner_type = builder.R11BoundaryOwner

                    def capture_owner(*args: Any, **kwargs: Any) -> Any:
                        owner = owner_type(*args, **kwargs)
                        captured_owners.append(owner)
                        return owner

                    with self.subTest(
                        position=position,
                        token=selected,
                        diagnostic_code=diagnostic_code,
                    ):
                        with (
                            patch.object(
                                builder, "_r11_first_red",
                                wraps=builder._r11_first_red,
                            ) as constructor,
                            patch.object(
                                builder, "_r11_publish_preconstructed",
                            ) as evidence_publish,
                            patch.object(
                                builder, "publish_json_no_replace",
                            ) as legacy_publish,
                            patch.object(
                                builder,
                                "R11BoundaryOwner",
                                side_effect=capture_owner,
                            ),
                            self.assertRaises(
                                builder.R11BuilderFailure,
                            ) as exact_red,
                        ):
                            builder._r11_read_retained_output(
                                retained,
                                expected,
                                read_boundary="INSTALLED_READ",
                            )
                    self.assertEqual(retained.reads, list(names[:position + 1]))
                    self.assertEqual(constructor.call_count, 1)
                    evidence_publish.assert_not_called()
                    legacy_publish.assert_not_called()
                    expected_owner_snapshots = [
                        (
                            "INSTALLED_READ",
                            (
                                (
                                    "prefix",
                                    "CLEAN"
                                    if read_index == 0
                                    else "READ_PARTIAL",
                                ),
                                (
                                    "selected_file_token",
                                    "installed/" + names[read_index],
                                ),
                            ),
                            "installed/" + names[read_index],
                            read_index,
                            "installed/" + names[read_index],
                        )
                        for read_index in range(position + 1)
                    ]
                    self.assertEqual(len(captured_owners), position + 1)
                    self.assertEqual(
                        [
                            (
                                captured.boundary,
                                captured.state_items,
                                captured.selected_file_token,
                                captured.read_ordinal,
                                captured.lifecycle_token,
                            )
                            for captured in captured_owners
                        ],
                        expected_owner_snapshots,
                    )
                    owner = captured_owners[-1]
                    self.assertEqual(
                        (
                            owner.boundary,
                            owner.state_items,
                            owner.selected_file_token,
                            owner.read_ordinal,
                            owner.lifecycle_token,
                        ),
                        (
                            "INSTALLED_READ",
                            (
                                (
                                    "prefix",
                                    "CLEAN"
                                    if position == 0
                                    else "READ_PARTIAL",
                                ),
                                ("selected_file_token", selected),
                            ),
                            selected,
                            position,
                            selected,
                        ),
                    )
                    self.assertIsNotNone(retained.last_diagnostic)
                    assert retained.last_diagnostic is not None
                    self.assertEqual(
                        retained.last_diagnostic.code, diagnostic_code,
                    )
                    self.assertEqual(
                        retained.last_diagnostic.operands,
                        literal_diagnostic_operands,
                    )
                    self.assertEqual(
                        exact_red.exception.first_red, expected_first_red,
                    )
                    self.assertEqual(
                        d1_context["terminal"], d1_frozen_terminal,
                    )
                    self.assertEqual(
                        r11_stdlib_canonical_bytes(d1_context["terminal"]),
                        d1_frozen_raw,
                    )
                    builder._r11_validate_first_red(
                        expected_first_red,
                        installed_state,
                        literal_calls,
                    )
                    assert_one_valid_publication(
                        f"C{position + 1}-{diagnostic_code}",
                        d1_context,
                        d1_frozen_terminal,
                        d1_frozen_raw,
                    )
                for token_index, token in enumerate(rejected_token[position]):
                    retained = RetainedReadFault(
                        position,
                        token,
                        diagnostic_code,
                    )
                    with self.subTest(
                        position=position,
                        rejected=token,
                        diagnostic_code=diagnostic_code,
                    ):
                        with (
                            patch.object(builder, "_r11_first_red") as rejected_constructor,
                            patch.object(builder, "_r11_publish_preconstructed") as rejected_publish,
                            patch.object(builder, "publish_json_no_replace") as rejected_legacy,
                            self.assertRaises((TypeError, ValueError)),
                        ):
                            builder._r11_read_retained_output(
                                retained, expected,
                                read_boundary="INSTALLED_READ",
                            )
                    rejected_constructor.assert_not_called()
                    rejected_publish.assert_not_called()
                    rejected_legacy.assert_not_called()
                    rejected_selected_ids.append(
                        f"{position}:{diagnostic_code}:{token_index}",
                    )
                    self.assertEqual(
                        retained.reads,
                        list(names[:position + 1]),
                    )

        self.assertEqual(len(rejected_selected_ids), 54)
        self.assertEqual(len(set(rejected_selected_ids)), 54)
        self.assertEqual(len(valid_publication_ids), 6)

        literal_inventory_operands = {
            "operation": "close_child",
            "component_index": 0,
            "path_token": "installed/a/repeat.json",
            "winerror": 6,
            "expected_attributes": None,
            "actual_attributes": None,
            "identity_before": {
                "volume_serial": "1234ABCD",
                "file_index": "0000000000000001",
            },
            "identity_after": None,
        }
        literal_inventory_diagnostic_raw = r11_stdlib_canonical_bytes({
            "code": "TRAVERSAL_HANDLE_CLOSE",
            "operands": literal_inventory_operands,
        })
        expected_inventory_first_red = {
            "phase": "installed_readback",
            "code": "OP_INSTALLED_OUTPUT_INVENTORY_EXCEPTION",
            "call_ordinal": None,
            "group_index": None,
            "group_string": None,
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {
                "exception_type": "TRAVERSAL_HANDLE_CLOSE",
                "message_sha256": "sha256:"
                + hashlib.sha256(literal_inventory_diagnostic_raw).hexdigest(),
            },
        }
        inventory_state = r11_literal_complete_results(installed=True)

        def close_diagnostic(
            token: str | None | object,
        ) -> builder.R11TraversalDiagnostic:
            operands = {
                "component_index": 0,
                "winerror": 6,
                "identity_before": r11_test_identity(),
            }
            if token is not omitted_token:
                operands["path_token"] = token
            return builder.R11TraversalDiagnostic(
                "TRAVERSAL_HANDLE_CLOSE",
                "close_child",
                **operands,
            )

        with tempfile.TemporaryDirectory(
            prefix="r11-inventory-parity-", dir=REPO_ROOT.parent,
        ) as inventory_parity_temp:
            inventory_context = r11_independent_terminal_context(
                Path(inventory_parity_temp),
                first_red=expected_inventory_first_red,
                results=inventory_state,
            )
            inventory_frozen_terminal = copy.deepcopy(
                inventory_context["terminal"],
            )
            inventory_frozen_raw = bytes(inventory_context["raw"])
            self.assertEqual(
                r11_stdlib_canonical_bytes(inventory_frozen_terminal),
                inventory_frozen_raw,
            )
            inventory = builder.R11BoundaryOwner(
                "INSTALLED_INVENTORY",
                (("prefix", "CLEAN"), ("selected_file_token", None)),
                None,
                None,
                lifecycle_token="installed",
            )
            before_selection = close_diagnostic("installed/a/repeat.json")
            translated = builder._r11_installed_close_failure(
                before_selection,
                read_set_complete=False,
                inventory_owner=inventory,
            )
            self.assertEqual(
                before_selection.code, "TRAVERSAL_HANDLE_CLOSE",
            )
            self.assertEqual(
                before_selection.operands, literal_inventory_operands,
            )
            self.assertEqual(
                translated.first_red, expected_inventory_first_red,
            )
            self.assertEqual(
                (
                    inventory.boundary, inventory.state_items,
                    inventory.selected_file_token, inventory.read_ordinal,
                    inventory.lifecycle_token,
                ),
                (
                    "INSTALLED_INVENTORY",
                    (("prefix", "CLEAN"), ("selected_file_token", None)),
                    None,
                    None,
                    "installed",
                ),
            )
            self.assertEqual(
                inventory_context["terminal"], inventory_frozen_terminal,
            )
            self.assertEqual(
                r11_stdlib_canonical_bytes(inventory_context["terminal"]),
                inventory_frozen_raw,
            )
            builder._r11_validate_first_red(
                expected_inventory_first_red,
                inventory_state,
                literal_calls,
            )
            assert_one_valid_publication(
                "C0-inventory-close",
                inventory_context,
                inventory_frozen_terminal,
                inventory_frozen_raw,
            )
        for token in (
            "repeat.json", "sibling/repeat.json", "C:\\fixture\\repeat.json",
        ):
            changed = close_diagnostic(token)
            with self.subTest(close_before_selection=token), self.assertRaises(
                (TypeError, ValueError),
            ):
                builder._r11_installed_close_failure(
                    changed,
                    read_set_complete=False,
                    inventory_owner=inventory,
                )
        with (
            patch.object(
                builder.R11BoundaryOwner,
                "translate",
                autospec=True,
            ) as post_complete_constructor,
            patch.object(builder, "_r11_publish_preconstructed") as evidence_publish,
            patch.object(builder, "publish_json_no_replace") as legacy_publish,
        ):
            for token in (
                "installed/z/repeat.json",
                "repeat.json",
                "installed/z/sibling.json",
                "installed/z",
                None,
                omitted_token,
                "C:/fixture/repeat.json",
                "\\\\?\\C:\\fixture\\repeat.json",
                "installed/a/repeat.json",
                "installed/m/repeat.json",
            ):
                post_complete = close_diagnostic(token)
                self.assertIs(
                    builder._r11_installed_close_failure(
                        post_complete,
                        read_set_complete=True,
                        inventory_owner=inventory,
                    ),
                    post_complete,
                )
        post_complete_constructor.assert_not_called()
        evidence_publish.assert_not_called()
        legacy_publish.assert_not_called()

        production_post_complete: list[tuple[str, BaseException]] = []

        directory_tree = object.__new__(builder.R11RetainedTree)
        directory_identity = r11_test_identity()
        directory_ancestor = {
            "handle": 101,
            "identity": directory_identity,
            "attributes": 0x10,
            "component_index": None,
            "path_token": None,
            "root": True,
            "directory": True,
            "ancestors": (),
        }
        directory_child = {
            "handle": 102,
            "identity": r11_test_identity("0000000000000002"),
            "attributes": 0x20,
            "size": 1,
            "component_index": 2,
            "path_token": "installed/z/repeat.json",
            "root": False,
            "directory": False,
            "ancestors": (directory_ancestor,),
        }
        directory_tree.root_token = "installed"
        directory_tree.read_order = ["z/repeat.json"]
        directory_tree.read_count = 0
        directory_tree.files = {"z/repeat.json": directory_child}
        with (
            patch.object(builder, "_r11_read_fd", return_value=b"x"),
            patch.object(
                builder,
                "_r11_query_handle",
                return_value=(
                    r11_test_identity("0000000000000003"), 0x11, 0,
                ),
            ),
            self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as directory_revalidation,
        ):
            directory_tree.read_file("z/repeat.json")
        production_post_complete.append(
            ("directory_revalidation", directory_revalidation.exception),
        )

        leaf_close_error = OSError(6, "fixture leaf close", None, 6)
        with (
            patch.object(builder.msvcrt, "open_osfhandle", return_value=201),
            patch.object(builder.os, "read", side_effect=(b"x", b"")),
            patch.object(builder.msvcrt, "get_osfhandle", return_value=202),
            patch.object(
                builder,
                "_r11_query_handle",
                return_value=(r11_test_identity(), 0x20, 1),
            ),
            patch.object(builder.os, "close", side_effect=leaf_close_error),
            self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as leaf_close,
        ):
            builder._r11_read_fd(
                200,
                depth=2,
                token="installed/z/repeat.json",
                before_identity=r11_test_identity(),
                before_attributes=0x20,
                before_size=1,
            )
        production_post_complete.append(("leaf_close", leaf_close.exception))

        class CloseFailureKernel:
            def CloseHandle(self, _handle: int) -> bool:
                ctypes.set_last_error(6)
                return False

        close_tree = object.__new__(builder.R11RetainedTree)
        close_tree.owned = [{
            "handle": 301,
            "identity": r11_test_identity(),
            "attributes": 0x10,
            "component_index": 2,
            "path_token": "installed/z",
            "root": False,
            "directory": True,
            "ancestors": (),
        }]
        with (
            patch.object(builder, "_kernel32", return_value=CloseFailureKernel()),
            self.assertRaises(
                builder.R11TraversalDiagnostic,
            ) as directory_close,
        ):
            close_tree.close()
        production_post_complete.append(
            ("directory_close", directory_close.exception),
        )

        cleanup_results = r11_literal_complete_results(installed=True)
        cleanup_results["temporary_root"] = "C:\\build-temp"
        cleanup_failure = MemoryError("post-complete cleanup")
        with (
            patch.object(builder.shutil, "rmtree", side_effect=cleanup_failure),
            self.assertRaises(MemoryError) as cleanup,
        ):
            builder._r11_cleanup_build_temp(
                Path("C:/build-temp"), cleanup_results,
            )
        self.assertIs(cleanup.exception, cleanup_failure)
        self.assertEqual(cleanup_results["temporary_root"], "C:\\build-temp")
        production_post_complete.append(("cleanup", cleanup.exception))

        for stage, escaped_failure in production_post_complete:
            with (
                self.subTest(post_complete_stage=stage),
                patch.object(builder, "_r11_first_red") as forbidden_constructor,
                patch.object(builder, "_r11_publish_preconstructed") as forbidden_publish,
                patch.object(builder, "publish_json_no_replace") as forbidden_ordinary,
            ):
                self.assertIs(
                    builder._r11_installed_close_failure(
                        escaped_failure,  # type: ignore[arg-type]
                        read_set_complete=True,
                        inventory_owner=inventory,
                    ),
                    escaped_failure,
                )
            forbidden_constructor.assert_not_called()
            forbidden_publish.assert_not_called()
            forbidden_ordinary.assert_not_called()
        self.assertEqual(
            [stage for stage, _failure in production_post_complete],
            [
                "directory_revalidation", "leaf_close", "directory_close",
                "cleanup",
            ],
        )
        with self.assertRaises(ValueError):
            builder.R11BoundaryOwner(
                "INSTALLED_INVENTORY",
                (("prefix", "CLEAN"), ("selected_file_token", None)),
                None,
                None,
            )
        self.assertEqual(len(valid_publication_ids), 7)
        self.assertEqual(len(set(valid_publication_ids)), 7)
        with self.assertRaises(ValueError):
            builder.R11BoundaryOwner(
                "RECOVERY_INVENTORY",
                (("recovery", True),),
                None,
                None,
            )

    def test_r11_48_literal_trace_schema_executes_every_scalar_dependency(self) -> None:
        authority = r11_literal_authority(0)
        trace = builder.validate_ordered_bytecode(
            r4_bytecode_artifact(authority), authority,
        )["bytecode_steps"]
        literal_terminal = r11_literal_staged_nogo_terminal(
            r11_literal_complete_results(installed=False),
            label="trace-scalars",
        )
        builder.r11_validate_builder_terminal(literal_terminal)

        def validate_rejected_trace(
            mutation: list[dict[str, Any]],
            selected_authority: dict[str, Any],
            *,
            completed: bool,
        ) -> None:
            direct_failure: BaseException | None = None
            try:
                builder._r11_validate_trace(
                    mutation, selected_authority, completed=completed,
                )
            except (builder.EvidenceFailure, TypeError, ValueError) as error:
                direct_failure = error
            if direct_failure is None:
                raise AssertionError("trace mutation reached the direct validator")
            terminal_mutation = copy.deepcopy(literal_terminal)
            evaluation = terminal_mutation["results"]["target_evaluations"][0]
            evaluation["bytecode_steps"] = copy.deepcopy(mutation)
            with patch.object(
                builder, "_r11_publish_preconstructed",
            ) as rejected_publication:
                try:
                    builder.r11_validate_builder_terminal(terminal_mutation)
                except (builder.EvidenceFailure, TypeError, ValueError):
                    pass
                else:
                    raise AssertionError("trace mutation reached terminal acceptance")
            rejected_publication.assert_not_called()
            raise direct_failure
        self.assertEqual(
            tuple(
                (
                    row["ordinal"], row["id"], row["kind"], row["status"],
                    r11_freeze(row["operands"]), r11_freeze(row["result"]),
                    row["error_code"],
                )
                for row in trace
            ),
            R11_LITERAL_STORE_TRACE_ROWS,
        )

        self.assertTrue(builder._r11_u53(0))
        self.assertTrue(builder._r11_u53(9_007_199_254_740_991))
        self.assertTrue(builder._r11_dword(0))
        self.assertTrue(builder._r11_dword(0xFFFFFFFF))
        for value in (
            -1,
            True,
            False,
            9_007_199_254_740_992,
            0.5,
            1e3,
            1e53,
        ):
            with self.subTest(numeric_form=value):
                self.assertFalse(builder._r11_u53(value))
        for value in (-1, True, False, 0x1_0000_0000, 0.5, 1e3):
            with self.subTest(dword_form=value):
                self.assertFalse(builder._r11_dword(value))

        invalid_numeric_forms = (
            -1, True, False, 9_007_199_254_740_992, 0.5, 1e3,
        )
        numeric_operand_names = {
            "input_length", "length", "entry_count", "constructor_count",
            "actual_words", "expected_words", "actual_bytes", "expected_bytes",
            "creation_bytes", "constructor_bytes", "actual", "threshold",
            "runtime_bytes", "gas_per_byte",
        }
        numeric_result_names = {
            "input_length", "output_length", "words", "bytes", "byte_count",
            "creation_bytes", "constructor_bytes", "full_initcode_bytes",
            "runtime_bytes", "gas_per_byte", "code_deposit_gas",
        }
        for index, row in enumerate(trace):
            for member in numeric_operand_names & set(row["operands"]):
                if row["operands"][member] is None:
                    continue
                for invalid in invalid_numeric_forms:
                    mutation = copy.deepcopy(trace)
                    mutation[index]["operands"][member] = invalid
                    with self.subTest(row=index + 1, operand=member, value=invalid), self.assertRaises(
                        (builder.EvidenceFailure, TypeError),
                    ):
                        validate_rejected_trace(
                            mutation, authority, completed=True,
                        )
            if isinstance(row["result"], dict):
                for member in numeric_result_names & set(row["result"]):
                    for invalid in invalid_numeric_forms:
                        mutation = copy.deepcopy(trace)
                        mutation[index]["result"][member] = invalid
                        with self.subTest(row=index + 1, result=member, value=invalid), self.assertRaises(
                            (builder.EvidenceFailure, TypeError),
                        ):
                            validate_rejected_trace(
                                mutation, authority, completed=True,
                            )

        hash_locations: list[tuple[int, str, str]] = []
        for index, row in enumerate(trace):
            hash_locations.extend(
                (index, "operands", key)
                for key in row["operands"] if key.endswith("sha256")
            )
            if isinstance(row["result"], dict):
                hash_locations.extend(
                    (index, "result", key)
                    for key in row["result"] if key.endswith("sha256")
                )
        for index, container, key in hash_locations:
            for invalid in (
                "",
                "sha256:" + "0" * 63,
                "sha256:" + "0" * 65,
                "sha256:" + "A" * 64,
                "sha256:" + "g" * 64,
                "SHA256:" + "0" * 64,
                "sha256:" + "0" * 63 + " ",
                "0" * 64,
                None,
                {},
                1,
            ):
                mutation = copy.deepcopy(trace)
                mutation[index][container][key] = invalid
                with self.subTest(hash_row=index + 1, hash_key=key, value=invalid), self.assertRaises(
                    (builder.EvidenceFailure, TypeError),
                ):
                    validate_rejected_trace(mutation, authority, completed=True)

        for index, key in (
            (0, "actual_type"), (1, "actual_type"), (7, "actual_type"),
            (8, "actual_type"), (9, "actual_type"), (15, "actual_type"),
            (16, "abi_type"), (16, "inputs_type"),
        ):
            mutation = copy.deepcopy(trace)
            mutation[index]["operands"][key] = "unknown"
            with self.subTest(enum_row=index + 1, enum=key), self.assertRaises(
                builder.EvidenceFailure,
            ):
                validate_rejected_trace(mutation, authority, completed=True)
        for index, field, value in (
            (0, "kind", "operation"),
            (2, "kind", "predicate"),
            (0, "status", "unknown"),
            (21, "operator", "<="),
            (24, "operator", "<"),
        ):
            mutation = copy.deepcopy(trace)
            if field == "operator":
                mutation[index]["operands"][field] = value
            else:
                mutation[index][field] = value
            with self.subTest(enum_field=field, row=index + 1), self.assertRaises(
                builder.EvidenceFailure,
            ):
                validate_rejected_trace(mutation, authority, completed=True)

        dependency_mutations = (
            (0, "operands", "present", False),
            (0, "operands", "actual_type", None),
            (7, "operands", "entry_count", None),
            (7, "operands", "actual_type", "string"),
            (16, "operands", "constructor_count", 2),
            (16, "operands", "inputs_present", None),
            (16, "operands", "actual_types", []),
            (16, "operands", "actual_types", list(_R11_STORE_TYPES) + ["address"]),
            (16, "operands", "actual_types", [*_R11_STORE_TYPES[:-1], 1]),
            (17, "operands", "input_types", [*_R11_STORE_TYPES[:-1], "uint256"]),
            (18, "operands", "actual_signature", "constructor(bytes32)"),
            (20, "result", "full_initcode_bytes", 258),
            (21, "operands", "actual", 258),
            (22, "result", "byte_count", 2),
            (23, "operands", "actual", 2),
            (24, "operands", "actual", 2),
            (25, "result", "code_deposit_gas", 201),
        )
        for index, container, key, value in dependency_mutations:
            mutation = copy.deepcopy(trace)
            mutation[index][container][key] = value
            with self.subTest(dependency=index + 1, member=key), self.assertRaises(
                (builder.EvidenceFailure, TypeError),
            ):
                validate_rejected_trace(mutation, authority, completed=True)
        for index in range(26):
            mutation = copy.deepcopy(trace)
            mutation[index]["operands"]["target"] = "WrongTarget"
            with self.subTest(target_join=index + 1), self.assertRaises(
                builder.EvidenceFailure,
            ):
                validate_rejected_trace(mutation, authority, completed=True)

        def array_variants(
            values: list[Any],
            *,
            baseline_no_op_ids: list[str] | None = None,
        ) -> tuple[tuple[str, list[Any]], ...]:
            middle = len(values) // 2
            last = len(values) - 1
            baseline = r11_freeze(values)
            variants: list[tuple[str, list[Any]]] = []
            candidate_fingerprints: set[Any] = set()

            def distinct_member(value: Any, label: str) -> Any:
                if isinstance(value, dict):
                    return [label]
                if isinstance(value, list):
                    return {"mutation": label}
                if isinstance(value, str):
                    return {"mutation": label}
                if type(value) in (int, bool) or value is None:
                    return label
                return {"mutation": label}

            def add_variant(
                label: str,
                candidate: list[Any],
                preferred_index: int = 0,
                legacy_candidate: list[Any] | None = None,
            ) -> None:
                normalized = copy.deepcopy(candidate)
                fingerprint = r11_freeze(normalized)
                if (
                    baseline_no_op_ids is not None
                    and r11_freeze(
                        candidate if legacy_candidate is None else legacy_candidate
                    ) == baseline
                ):
                    baseline_no_op_ids.append(label)
                if fingerprint == baseline or fingerprint in candidate_fingerprints:
                    if not normalized:
                        normalized.append(distinct_member(None, label))
                    else:
                        selected = min(preferred_index, len(normalized) - 1)
                        normalized[selected] = distinct_member(
                            normalized[selected], label,
                        )
                    fingerprint = r11_freeze(normalized)
                self.assertNotEqual(fingerprint, baseline, label)
                self.assertNotIn(fingerprint, candidate_fingerprints, label)
                candidate_fingerprints.add(fingerprint)
                variants.append((label, normalized))

            add_variant("empty", [])
            for label, index in (("first", 0), ("middle", middle), ("last", last)):
                truncated = copy.deepcopy(values)
                truncated.pop(index)
                add_variant(f"truncate-{label}", truncated, index)
                duplicated = copy.deepcopy(values)
                duplicated.insert(index, copy.deepcopy(duplicated[index]))
                add_variant(f"duplicate-{label}", duplicated, index)
            appended = copy.deepcopy(values)
            appended.append(copy.deepcopy(values[-1]))
            add_variant("append", appended, len(appended) - 1)
            prepended = copy.deepcopy(values)
            prepended.insert(0, copy.deepcopy(values[0]))
            add_variant("prepend", prepended)
            reversed_values = copy.deepcopy(values)
            reversed_values.reverse()
            add_variant("reverse", reversed_values, last)
            adjacent = copy.deepcopy(values)
            adjacent[0], adjacent[1] = adjacent[1], adjacent[0]
            add_variant("adjacent-swap", adjacent)
            rotated = copy.deepcopy(values[1:] + values[:1])
            add_variant("same-members-wrong-order", rotated, middle)
            wrong_element = copy.deepcopy(values)
            legacy_wrong_element = copy.deepcopy(values)
            legacy_wrong_element[middle] = 1
            wrong_element[middle] = distinct_member(
                wrong_element[middle], "wrong-element-type",
            )
            add_variant(
                "wrong-element-type", wrong_element, middle,
                legacy_candidate=legacy_wrong_element,
            )
            null_element = copy.deepcopy(values)
            null_element[middle] = None
            add_variant("null-element", null_element, middle)
            cross_element = copy.deepcopy(values)
            cross_element[middle] = copy.deepcopy(values[0])
            add_variant("cross-target-element", cross_element, middle)
            extra_element = copy.deepcopy(values)
            extra_element.append({"_extra": None})
            add_variant("extra-element", extra_element, len(extra_element) - 1)
            self.assertEqual(len(variants), 16)
            self.assertEqual(len(candidate_fingerprints), 16)
            return tuple(variants)

        for trace_array_id, trace_array in array_variants(trace):
            with (
                self.subTest(trace_array=trace_array_id),
                self.assertRaises(
                    (builder.EvidenceFailure, TypeError, ValueError),
                ),
            ):
                validate_rejected_trace(
                    trace_array, authority, completed=True,
                )

        for envelope_field in ("calls", "checkpoints"):
            baseline_array = literal_terminal[envelope_field]
            for array_id, array_mutation in array_variants(baseline_array):
                terminal_mutation = copy.deepcopy(literal_terminal)
                terminal_mutation[envelope_field] = array_mutation
                with (
                    self.subTest(
                        terminal_array=envelope_field,
                        mutation=array_id,
                    ),
                    patch.object(
                        builder, "_r11_publish_preconstructed",
                    ) as rejected_publication,
                ):
                    if envelope_field == "calls" and array_id == "duplicate-last":
                        with self.assertRaises(
                            builder.EvidenceFailure,
                        ) as outside_call_schedule:
                            builder.r11_validate_builder_terminal(
                                terminal_mutation,
                            )
                        self.assertEqual(
                            outside_call_schedule.exception.code,
                            "CALL_SCHEMA",
                        )
                    else:
                        with self.assertRaises(
                            (builder.EvidenceFailure, TypeError, ValueError),
                        ):
                            builder.r11_validate_builder_terminal(
                                terminal_mutation,
                            )
                rejected_publication.assert_not_called()

        output_terminal = r11_literal_go_terminal(label="output-array")
        builder.r11_validate_builder_terminal(output_terminal)
        for array_id, array_mutation in array_variants(
            output_terminal["results"]["output_files"],
        ):
            terminal_mutation = copy.deepcopy(output_terminal)
            terminal_mutation["results"]["output_files"] = array_mutation
            with (
                self.subTest(output_array=array_id),
                patch.object(
                    builder, "_r11_publish_preconstructed",
                ) as rejected_publication,
                self.assertRaises(
                    (builder.EvidenceFailure, TypeError, ValueError),
                ),
            ):
                builder.r11_validate_builder_terminal(terminal_mutation)
            rejected_publication.assert_not_called()

        aggregate_operand_candidate_counts = {
            "runtime_bytes": 0,
            "code_deposit_gas": 0,
            "full_initcode_bytes": 0,
        }
        aggregate_operand_candidates: dict[
            str, list[tuple[str, str, Any]]
        ] = {
            family: [] for family in aggregate_operand_candidate_counts
        }
        aggregate_operand_legacy_no_op_counts = {
            family: 0 for family in aggregate_operand_candidate_counts
        }
        no_op_sensitive_ids = {
            "reverse", "adjacent-swap", "same-members-wrong-order",
            "cross-target-element", "wrong-element-type",
        }
        for row_index, aggregate_row in enumerate(
            literal_terminal["results"]["aggregates"],
        ):
            for array_field in ("members", "operands"):
                baseline_array = aggregate_row[array_field]
                baseline_no_op_ids: list[str] = []
                variants = array_variants(
                    baseline_array,
                    baseline_no_op_ids=(
                        baseline_no_op_ids
                        if array_field == "operands" else None
                    ),
                )
                self.assertEqual(len(variants), 16)
                self.assertEqual(
                    len({r11_freeze(candidate) for _label, candidate in variants}),
                    16,
                )
                for array_id, array_mutation in variants:
                    self.assertNotEqual(array_mutation, baseline_array, array_id)
                    if array_id in no_op_sensitive_ids:
                        self.assertNotEqual(
                            r11_freeze(array_mutation),
                            r11_freeze(baseline_array),
                            array_id,
                        )
                    if array_field == "operands":
                        family = aggregate_row["field"]
                        aggregate_operand_candidate_counts[family] += 1
                        aggregate_operand_candidates[family].append((
                            aggregate_row["gate"], array_id,
                            r11_freeze(array_mutation),
                        ))
                    terminal_mutation = copy.deepcopy(literal_terminal)
                    terminal_mutation["results"]["aggregates"][row_index][
                        array_field
                    ] = array_mutation
                    with (
                        self.subTest(
                            aggregate=aggregate_row["gate"],
                            aggregate_array=array_field,
                            mutation=array_id,
                        ),
                        patch.object(
                            builder, "_r11_publish_preconstructed",
                        ) as rejected_publication,
                        self.assertRaises(
                            (builder.EvidenceFailure, TypeError, ValueError),
                        ),
                    ):
                        builder.r11_validate_builder_terminal(
                            terminal_mutation,
                        )
                    rejected_publication.assert_not_called()
                if array_field == "operands":
                    aggregate_operand_legacy_no_op_counts[
                        aggregate_row["field"]
                    ] += len(baseline_no_op_ids)
        self.assertEqual(
            aggregate_operand_candidate_counts,
            {
                "runtime_bytes": 80,
                "code_deposit_gas": 80,
                "full_initcode_bytes": 16,
            },
        )
        self.assertEqual(
            aggregate_operand_legacy_no_op_counts,
            {
                "runtime_bytes": 25,
                "code_deposit_gas": 20,
                "full_initcode_bytes": 4,
            },
        )
        for family, candidates in aggregate_operand_candidates.items():
            expected_count = aggregate_operand_candidate_counts[family]
            self.assertEqual(len(candidates), expected_count)
            self.assertEqual(len(set(candidates)), expected_count)

    def test_r11_49_first_red_int53_regex_path_and_safe_contexts_execute(self) -> None:
        initial = r11_literal_initial_results()
        nonzero = {
            "phase": "forge_version",
            "code": "FORGE_NONZERO_EXIT",
            "call_ordinal": 0,
            "group_index": None,
            "group_string": None,
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {
                "returncode": 1,
                "stdout_byte_count": 0,
                "stdout_sha256": r11_hash("stdout"),
                "stderr_byte_count": 0,
                "stderr_sha256": r11_hash("stderr"),
            },
        }
        for returncode in (
            -9_007_199_254_740_991,
            -1,
            1,
            9_007_199_254_740_991,
        ):
            value = copy.deepcopy(nonzero)
            value["operands"]["returncode"] = returncode
            builder._r11_validate_first_red(value, initial, [object()])
        for returncode in (
            -9_007_199_254_740_992,
            0,
            True,
            9_007_199_254_740_992,
            0.5,
            1e3,
        ):
            value = copy.deepcopy(nonzero)
            value["operands"]["returncode"] = returncode
            with self.subTest(returncode=returncode), self.assertRaises(
                builder.EvidenceFailure,
            ):
                builder._r11_validate_first_red(value, initial, [object()])

        portable_results = r11_literal_initial_results()
        portable_results["temporary_root"] = "build-temp"
        portable = {
            "phase": "portable_input",
            "code": "PORTABLE_INPUT_BUILD_INFO_READ",
            "call_ordinal": 1,
            "group_index": 0,
            "group_string": R4_GROUP_STRINGS[0],
            "semantic_id": None,
            "target": None,
            "step_ordinal": None,
            "step_id": None,
            "operands": {
                "path_token": "build-info/000/input.json",
                "exception_type": "Traversal.Error_1",
                "message_sha256": r11_hash("portable"),
            },
        }
        builder._r11_validate_first_red(
            portable, portable_results, [object(), object()],
        )
        for token in (
            "", ".", "..", "input.json", "/absolute", "C:/native",
            "\\\\server\\share", "native\\path", "build-info/../input.json",
            "build-info/000/", "build-info/000/a\x00b",
            "build-info/001/input.json",
            "build-info/000/" + "a" * 32_768,
        ):
            mutation = copy.deepcopy(portable)
            mutation["operands"]["path_token"] = token
            with self.subTest(path_token=token), self.assertRaises(
                (builder.EvidenceFailure, ValueError),
            ):
                builder._r11_validate_first_red(
                    mutation, portable_results, [object(), object()],
                )
        for exception_type in (
            "", ".bad", "1bad", "bad-name", "bad name", "bäd",
            "a" * 257, None, 1,
        ):
            mutation = copy.deepcopy(portable)
            mutation["operands"]["exception_type"] = exception_type
            with self.subTest(exception_type=exception_type), self.assertRaises(
                (builder.EvidenceFailure, TypeError),
            ):
                builder._r11_validate_first_red(
                    mutation, portable_results, [object(), object()],
                )
        for digest in (
            "", "sha256:" + "0" * 63, "sha256:" + "0" * 65,
            "sha256:" + "A" * 64, "sha256:" + "g" * 64,
            "SHA256:" + "0" * 64, "sha256:" + "0" * 63 + " ",
            "0" * 64, None, {}, 1,
        ):
            mutation = copy.deepcopy(portable)
            mutation["operands"]["message_sha256"] = digest
            with self.subTest(message_sha256=digest), self.assertRaises(
                (builder.EvidenceFailure, TypeError),
            ):
                builder._r11_validate_first_red(
                    mutation, portable_results, [object(), object()],
                )

        safe_contexts = (
            builder._r11_first_red(
                "FORGE_VERSION_FORMAT",
                "forge_version",
                {"byte_count": 1, "sha256": r11_hash("version")},
                call_ordinal=0,
            ).first_red,
            builder._r11_first_red(
                "PORTABLE_INPUT_BUILD_INFO_COUNT",
                "portable_input",
                {"expected_count": 1, "actual_count": 0},
                call_ordinal=1,
                group_index=0,
            ).first_red,
            builder._r11_first_red(
                "METADATA_TARGET_AND_PATH",
                "metadata_admission",
                {"item": 1, "reason": "artifact_path_missing"},
                call_ordinal=6,
                authority=r11_literal_authority(0),
            ).first_red,
            builder._r11_first_red(
                "BC_CREATION_MISSING",
                "bytecode",
                {
                    "target": _R11_STORE_TARGET,
                    "present": False,
                    "actual_type": None,
                },
                call_ordinal=6,
                authority=r11_literal_authority(0),
                step_ordinal=1,
            ).first_red,
            builder._r11_first_red(
                "STAGED_VALIDATION_FAILED",
                "staged_validation",
                {"cause_type": "TraversalError", "message_sha256": r11_hash("staged")},
            ).first_red,
        )
        expected_contexts = (
            (0, None, None, None, None, None),
            (1, 0, R4_GROUP_STRINGS[0], None, None, None),
            (6, 5, R4_GROUP_STRINGS[5], "Store", _R11_STORE_TARGET, None),
            (6, 5, R4_GROUP_STRINGS[5], "Store", _R11_STORE_TARGET, 1),
            (None, None, None, None, None, None),
        )
        for first_red, expected in zip(safe_contexts, expected_contexts, strict=True):
            self.assertEqual(
                (
                    first_red["call_ordinal"], first_red["group_index"],
                    first_red["group_string"], first_red["semantic_id"],
                    first_red["target"], first_red["step_ordinal"],
                ),
                expected,
            )
            self.assertEqual(
                first_red["step_id"],
                None if first_red["step_ordinal"] is None else "CREATION_CONTAINER",
            )

    def test_r11_50_pinned_sharing_selected_unrelated_and_full_tree_races(self) -> None:
        def assert_lease_denial(failure: OSError) -> None:
            if failure.winerror is not None:
                self.assertIn(failure.winerror, (5, 32))
                return
            self.assertIn(failure.errno, (errno.EACCES, errno.EPERM))

        if os.name == "nt":
            with tempfile.TemporaryDirectory(
                prefix="r11-pinned-", dir=REPO_ROOT.parent,
            ) as temporary:
                root = Path(temporary) / "pinned"
                root.mkdir()
                (root / "leaf.bin").write_bytes(b"x")
                renamed = root.with_name("renamed")
                with builder.R11RetainedTree(root, "retained") as retained:
                    retained_identity = copy.deepcopy(
                        retained.owned[0]["identity"],
                    )
                    retained_attributes = retained.owned[0]["attributes"]
                    for operation, move in (
                        ("rename", lambda: root.rename(renamed)),
                        ("replace", lambda: os.replace(root, renamed)),
                    ):
                        with self.subTest(pinned_move=operation), self.assertRaises(
                            OSError,
                        ) as move_failure:
                            move()
                        assert_lease_denial(move_failure.exception)
                        self.assertTrue((root / "leaf.bin").is_file())
                        self.assertFalse(renamed.exists())
                        self.assertEqual(
                            retained.owned[0]["identity"], retained_identity,
                        )
                        self.assertEqual(
                            retained.owned[0]["attributes"],
                            retained_attributes,
                        )
                self.assertTrue(all(item["handle"] == 0 for item in retained.owned))
                root.rename(renamed)
                self.assertTrue((renamed / "leaf.bin").is_file())
                renamed.rename(root)
                os.replace(root, renamed)
                self.assertTrue((renamed / "leaf.bin").is_file())
                os.replace(renamed, root)
                self.assertTrue((root / "leaf.bin").is_file())

            with tempfile.TemporaryDirectory(
                prefix="r11-executable-leases-", dir=REPO_ROOT.parent,
            ) as temporary:
                root = Path(temporary)
                forge = root / "forge-copy.exe"
                solc = root / "solc-copy.exe"
                forge.write_bytes(b"safe forge fixture")
                solc.write_bytes(b"safe solc fixture")
                forge_replacement = root / "forge-replacement.exe"
                solc_replacement = root / "solc-replacement.exe"
                forge_replacement.write_bytes(b"safe forge replacement")
                solc_replacement.write_bytes(b"safe solc replacement")
                receipts = {
                    "forge": builder.windows_file_receipt(forge, "Forge executable"),
                    "solc": builder.windows_file_receipt(solc, "Solc executable"),
                }
                leases = builder.R11ExecutableLeaseSet.acquire(
                    forge, solc, receipts,
                )
                try:
                    for token, tool, replacement in (
                        ("forge", forge, forge_replacement),
                        ("solc", solc, solc_replacement),
                    ):
                        with self.subTest(leased_tool=token, mutation="write"), self.assertRaises(OSError) as write_failure:
                            with tool.open("r+b"):
                                pass
                        assert_lease_denial(write_failure.exception)
                        renamed_tool = tool.with_suffix(".renamed")
                        with self.subTest(leased_tool=token, mutation="rename"), self.assertRaises(OSError) as rename_failure:
                            tool.rename(renamed_tool)
                        assert_lease_denial(rename_failure.exception)
                        with self.subTest(leased_tool=token, mutation="replace"), self.assertRaises(OSError) as replace_failure:
                            os.replace(replacement, tool)
                        assert_lease_denial(replace_failure.exception)
                    unrelated = root / "unrelated" / "scratch.bin"
                    unrelated.parent.mkdir()
                    unrelated.write_bytes(b"unrelated write remains permitted")
                    self.assertEqual(
                        unrelated.read_bytes(), b"unrelated write remains permitted",
                    )
                    leases.revalidate()
                finally:
                    leases.close()
                self.assertTrue(
                    all(record["handle"] == 0 for record in leases.records),
                )
                for token, tool, replacement in (
                    ("forge", forge, forge_replacement),
                    ("solc", solc, solc_replacement),
                ):
                    renamed_tool = tool.with_suffix(".renamed")
                    tool.rename(renamed_tool)
                    renamed_tool.rename(tool)
                    os.replace(replacement, tool)
                    self.assertIn(b"replacement", tool.read_bytes(), token)

            real_forge_text = shutil.which("forge")
            real_solc_text = shutil.which("solc")
            self.assertIsNotNone(
                real_forge_text,
                "canonical Windows authority requires the pinned Forge executable",
            )
            self.assertIsNotNone(
                real_solc_text,
                "canonical Windows authority requires the pinned Solc executable",
            )
            assert real_forge_text is not None
            assert real_solc_text is not None
            real_forge = Path(real_forge_text).resolve(strict=True)
            real_solc = Path(real_solc_text).resolve(strict=True)
            with tempfile.TemporaryDirectory(
                prefix="r11-real-tool-journal-", dir=REPO_ROOT.parent,
            ) as temporary:
                evidence = Path(temporary) / "evidence"
                evidence.mkdir()
                static = {
                    "forge": builder.windows_file_receipt(
                        real_forge, "Forge executable", path_token="forge",
                    ),
                    "solc": builder.windows_file_receipt(
                        real_solc, "Solc executable", path_token="solc",
                    ),
                    "evidence_dir": builder.windows_file_receipt(
                        evidence,
                        "evidence",
                        directory=True,
                        path_token="evidence-dir",
                    ),
                }
                leases = builder.R11ExecutableLeaseSet.acquire(
                    real_forge, real_solc, static,
                )
                run_lock = builder.WindowsDirectoryLock.acquire(evidence)
                run_lock.executable_leases = leases
                authority = builder.R11ExecutionAuthority(run_lock)
                checkpoint = builder._r11_checkpoint(
                    "pre-started", real_forge, real_solc, static,
                )
                journal = builder.ExecutionJournal(
                    evidence,
                    r11_hash("real-tool-journal"),
                    static,
                    real_forge,
                    real_solc,
                    held_evidence_directory_identity=run_lock.identity,
                    pre_started_checkpoint=checkpoint,
                    execution_authority=authority,
                )
                journal.publish_started()
                result = journal.invoke(
                    0,
                    [str(real_forge), "--version"],
                    REPO_ROOT,
                    phase="forge_version",
                    group_string=None,
                )
                self.assertTrue(result.launched)
                self.assertEqual(result.returncode, 0)
                self.assertTrue(run_lock.owned)
                self.assertTrue(leases.owned)
                self.assertIn(run_lock, builder._ACTIVE_EVIDENCE_LOCKS)
                self.assertTrue(all(record["handle"] for record in leases.records))
                for token, tool in (
                    ("forge", real_forge), ("solc", real_solc),
                ):
                    with self.subTest(real_tool=token), self.assertRaises(
                        OSError,
                    ) as mutation_failure:
                        with tool.open("r+b"):
                            pass
                    assert_lease_denial(mutation_failure.exception)
                authority.close()
                self.assertFalse(run_lock.owned)
                self.assertFalse(leases.owned)
                self.assertNotIn(run_lock, builder._ACTIVE_EVIDENCE_LOCKS)
                self.assertTrue(
                    all(record["handle"] == 0 for record in leases.records),
                )
                for token, tool in (
                    ("forge", real_forge), ("solc", real_solc),
                ):
                    with self.subTest(real_tool_after_close=token):
                        with tool.open("r+b") as mutable_handle:
                            self.assertTrue(mutable_handle.writable())

        execution_parameter = inspect.signature(
            builder.ExecutionJournal.__init__,
        ).parameters["execution_authority"]
        self.assertIs(execution_parameter.default, inspect.Parameter.empty)
        self.assertNotIn(
            "run_lock", inspect.signature(builder.ExecutionJournal.__init__).parameters,
        )
        self.assertIn(
            "_r11_require_journal_execution_authority",
            inspect.getsource(builder.ExecutionJournal.invoke),
        )
        terminal_source = inspect.getsource(
            builder.ExecutionJournal.publish_terminal,
        )
        self.assertIn("finally:", terminal_source)
        self.assertIn("authority.close(primary)", terminal_source)
        self.assertIn(
            "cannot publish an authoritative terminal",
            inspect.getsource(
                _R11NonPublishingJournalHarness.publish_terminal,
            ),
        )

        class OpenCapture:
            def __init__(self) -> None:
                self.create_calls: list[tuple[Any, ...]] = []
                self.close_calls: list[int] = []

            def CreateFileW(self, *args: Any) -> int:
                self.create_calls.append(args)
                return 101

            def CloseHandle(self, handle: int) -> bool:
                self.close_calls.append(handle)
                return True

        identity = r11_test_identity()
        capture = OpenCapture()
        with (
            patch.object(builder, "_kernel32", return_value=capture),
            patch.object(
                builder,
                "_r11_query_handle",
                return_value=(identity, builder._R11_FILE_ATTRIBUTE_DIRECTORY, 0),
            ),
        ):
            handle, _, _, _ = builder._r11_open_child(
                "\\\\?\\C:\\pinned",
                directory=True,
                depth=None,
                token=None,
                parent_identity=None,
                root=True,
            )
            builder._r11_close_traversal_handle(
                handle,
                code="TRAVERSAL_ROOT_HANDLE_CLOSE",
                operation="close_root",
                component_index=None,
                path_token=None,
                identity_before=identity,
            )
        self.assertEqual(len(capture.create_calls), 1)
        create_call = capture.create_calls[0]
        self.assertEqual(
            create_call[2],
            builder._FILE_SHARE_READ | builder._FILE_SHARE_WRITE,
        )
        self.assertFalse(create_call[2] & builder._FILE_SHARE_DELETE)
        self.assertTrue(create_call[5] & builder._R11_FILE_FLAG_OPEN_REPARSE_POINT)
        self.assertEqual(capture.close_calls, [101])

        lease_capture = OpenCapture()
        with (
            patch.object(builder, "_kernel32", return_value=lease_capture),
            patch.object(
                builder,
                "_r11_query_handle",
                return_value=(
                    identity,
                    builder._R11_FILE_ATTRIBUTE_DIRECTORY,
                    0,
                ),
            ),
        ):
            lease_record = builder._r11_open_executable_lease_handle(
                "\\\\?\\C:\\lease",
                directory=True,
                lease_token="forge-lease/ancestor-000",
            )
            builder._kernel32().CloseHandle(lease_record["handle"])
        self.assertEqual(len(lease_capture.create_calls), 1)
        lease_create = lease_capture.create_calls[0]
        self.assertEqual(lease_create[2], builder._FILE_SHARE_READ)
        self.assertTrue(
            lease_create[5] & builder._R11_FILE_FLAG_OPEN_REPARSE_POINT,
        )
        self.assertEqual(lease_capture.close_calls, [101])

        reverse_capture = OpenCapture()
        reverse_records = [
            {
                "handle": handle,
                "identity": r11_test_identity(f"{handle:016X}"),
                "attributes": builder._R11_FILE_ATTRIBUTE_DIRECTORY,
                "size": None,
                "byte_count": None,
                "sha256": None,
                "lease_token": token,
                "directory": True,
            }
            for handle, token in (
                (201, "forge-lease/ancestor-000"),
                (202, "forge-lease/ancestor-001"),
                (301, "solc-lease/ancestor-000"),
                (302, "solc-lease/ancestor-001"),
            )
        ]
        reverse_by_handle = {
            record["handle"]: (
                record["identity"], record["attributes"], 0,
            )
            for record in reverse_records
        }
        reverse_leases = builder.R11ExecutableLeaseSet(reverse_records)
        with (
            patch.object(builder, "_kernel32", return_value=reverse_capture),
            patch.object(
                builder,
                "_r11_query_handle",
                side_effect=lambda handle: reverse_by_handle[handle],
            ),
        ):
            reverse_leases.close()
        self.assertEqual(reverse_capture.close_calls, [302, 301, 202, 201])
        self.assertTrue(
            all(record["handle"] == 0 for record in reverse_records),
        )

        class CloseFailureCapture(OpenCapture):
            def CloseHandle(self, handle: int) -> bool:
                self.close_calls.append(handle)
                if handle == 402:
                    ctypes.set_last_error(32)
                    return False
                return True

        close_failure_records = [
            {
                "handle": handle,
                "identity": r11_test_identity(f"{handle:016X}"),
                "attributes": builder._R11_FILE_ATTRIBUTE_DIRECTORY,
                "size": None,
                "byte_count": None,
                "sha256": None,
                "lease_token": token,
                "directory": True,
            }
            for handle, token in (
                (401, "forge-lease/ancestor-000"),
                (402, "solc-lease/ancestor-000"),
            )
        ]
        close_failure_by_handle = {
            record["handle"]: (
                record["identity"], record["attributes"], 0,
            )
            for record in close_failure_records
        }
        close_failure_capture = CloseFailureCapture()
        close_failure_leases = builder.R11ExecutableLeaseSet(
            close_failure_records,
        )
        with (
            patch.object(
                builder, "_kernel32", return_value=close_failure_capture,
            ),
            patch.object(
                builder,
                "_r11_query_handle",
                side_effect=lambda handle: close_failure_by_handle[handle],
            ),
            self.assertRaises(builder.EvidenceFailure) as close_failure,
        ):
            close_failure_leases.close()
        self.assertEqual(close_failure.exception.code, "EXECUTABLE_LEASE_CLOSE")
        self.assertEqual(close_failure.exception.operands["winerror"], 32)
        self.assertEqual(close_failure_capture.close_calls, [402, 401])
        self.assertTrue(
            all(record["handle"] == 0 for record in close_failure_records),
        )

        selected_reparse = r11_copied_record(
            "Selected.bin", "", builder._R11_FILE_ATTRIBUTE_REPARSE_POINT,
        )
        selected_reparse["raw_ordinal"] = 0
        selected_read = Mock()
        selected_close = Mock()
        with (
            patch.object(
                builder, "_r11_absolute_parts",
                return_value=("\\\\?\\C:\\", ["Selected.bin"], "C"),
            ),
            patch.object(
                builder, "_r11_open_child",
                return_value=(1, identity, builder._R11_FILE_ATTRIBUTE_DIRECTORY, 0),
            ) as selected_root_open,
            patch.object(builder, "_r11_find_snapshot", return_value=[selected_reparse]),
            patch.object(builder, "_r11_assert_directory_stable"),
            patch.object(builder, "_r11_read_fd", selected_read),
            patch.object(builder, "_r11_close_traversal_handle", selected_close),
            self.assertRaises(builder.R11TraversalDiagnostic) as selected_failure,
        ):
            builder.r11_native_read(
                Path("C:/Selected.bin"), "selected/Selected.bin",
            )
        self.assertEqual(selected_failure.exception.code, "TRAVERSAL_ENTRY_REPARSE")
        self.assertEqual(selected_root_open.call_count, 1)
        selected_read.assert_not_called()
        selected_close.assert_called_once()

        ordinary = r11_copied_record("Selected.bin", "", 0x20)
        ordinary["raw_ordinal"] = 0
        unrelated_reparse = r11_copied_record(
            "Unrelated.bin", "", builder._R11_FILE_ATTRIBUTE_REPARSE_POINT,
        )
        unrelated_reparse["raw_ordinal"] = sum(
            ordinary["record_key"] < unrelated_reparse["record_key"]
            for _member in (0,)
        )
        ordinary["raw_ordinal"] = sum(
            unrelated_reparse["record_key"] < ordinary["record_key"]
            for _member in (0,)
        )
        lookup_records = sorted(
            (ordinary, unrelated_reparse),
            key=lambda record: (record["long_name"].casefold(), record["long_name"]),
        )
        with (
            patch.object(
                builder, "_r11_absolute_parts",
                return_value=("\\\\?\\C:\\", ["Selected.bin"], "C"),
            ),
            patch.object(
                builder,
                "_r11_open_child",
                side_effect=(
                    (1, identity, builder._R11_FILE_ATTRIBUTE_DIRECTORY, 0),
                    (2, r11_test_identity("0000000000000002"), 0x20, 1),
                ),
            ),
            patch.object(builder, "_r11_find_snapshot", return_value=lookup_records),
            patch.object(builder, "_r11_assert_directory_stable"),
            patch.object(builder, "_r11_read_fd", return_value=b"x") as unrelated_read,
            patch.object(builder, "_r11_close_traversal_handle"),
        ):
            raw, token, _ = builder.r11_native_read(
                Path("C:/Selected.bin"), "selected/Selected.bin",
            )
        self.assertEqual((raw, token), (b"x", "selected/Selected.bin"))
        unrelated_read.assert_called_once()

        tree = object.__new__(builder.R11RetainedTree)
        root_item = {
            "handle": 1,
            "identity": identity,
            "attributes": builder._R11_FILE_ATTRIBUTE_DIRECTORY,
            "component_index": None,
            "path_token": None,
            "root": True,
            "directory": True,
            "ancestors": (),
        }
        tree.path = Path("C:/fixture")
        tree.root_token = "retained"
        tree.owned = [root_item]
        tree.entries = []
        tree.files = {}
        tree.read_count = 0
        tree.read_order = []
        with (
            patch.object(builder, "_r11_find_snapshot", return_value=lookup_records),
            patch.object(builder, "_r11_assert_directory_stable"),
            patch.object(builder, "_r11_open_child") as full_tree_open,
            patch.object(builder, "_r11_read_fd") as full_tree_read,
            self.assertRaises(builder.R11TraversalDiagnostic) as full_tree_failure,
        ):
            tree._collect(
                "\\\\?\\C:\\fixture",
                root_item,
                "retained",
                root=True,
                relative_prefix="",
                ancestors=(root_item,),
            )
        self.assertEqual(full_tree_failure.exception.code, "TRAVERSAL_ENTRY_REPARSE")
        full_tree_open.assert_not_called()
        full_tree_read.assert_not_called()

        race_capture = OpenCapture()
        with (
            patch.object(builder, "_kernel32", return_value=race_capture),
            patch.object(
                builder,
                "_r11_query_handle",
                return_value=(
                    identity,
                    builder._R11_FILE_ATTRIBUTE_REPARSE_POINT,
                    0,
                ),
            ),
            self.assertRaises(builder.R11TraversalDiagnostic) as race_failure,
        ):
            builder._r11_open_child(
                "\\\\?\\C:\\race\\Selected.bin",
                directory=False,
                depth=1,
                token="race/Selected.bin",
                parent_identity=identity,
            )
        self.assertEqual(race_failure.exception.code, "TRAVERSAL_CHILD_REPARSE")
        self.assertEqual(race_capture.close_calls, [101])


if __name__ == "__main__":
    if (
        os.environ.get(R4_HERMETIC_CHILD_ENV) == "1"
        and os.environ.get(R4_HERMETIC_CHILD_CWD_ENV) == os.getcwd()
    ):
        unittest.main(
            verbosity=2,
            defaultTest=R4_HERMETIC_SELECTED_TEST,
        )
    else:
        unittest.main(verbosity=2)
