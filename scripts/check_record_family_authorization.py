#!/usr/bin/env python3
"""Validate record-family authorization source, inventory, and release evidence."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import stat
import subprocess
import sys
import unicodedata
from pathlib import Path
from typing import Any, Final, Iterable, Sequence

try:
    from jsonschema import Draft202012Validator, FormatChecker
    from jsonschema.exceptions import SchemaError
except ModuleNotFoundError:  # pragma: no cover - broken pinned toolchain only.
    Draft202012Validator = None
    FormatChecker = None
    SchemaError = Exception


DEFAULT_INVENTORY: Final = Path(
    "release-artifacts/record-family-authorization-inventory.json"
)
DEFAULT_INVENTORY_SCHEMA: Final = Path(
    "release-artifacts/schema/record-family-authorization-inventory.v1.schema.json"
)
DEFAULT_SOURCE_CATALOG: Final = Path(
    "release-artifacts/record-family-authorization-source-catalog.json"
)
DEFAULT_SOURCE_CATALOG_SCHEMA: Final = Path(
    "release-artifacts/schema/"
    "record-family-authorization-source-catalog.v1.schema.json"
)
DEFAULT_EVIDENCE_TEMPLATE: Final = Path(
    "deployments/record-family-authorization/record-family-authorization-evidence-template.json"
)
DEFAULT_EVIDENCE_SCHEMA: Final = Path(
    "deployments/schema/record-family-authorization-evidence.v1.schema.json"
)
DEFAULT_GRANT_MAP_SCHEMA: Final = Path(
    "deployments/schema/record-family-authorization-grant-map.v1.schema.json"
)
EXPECTED_GRANT_MAP_PATHS: Final = {
    "public_beta": Path(
        "deployments/record-family-authorization/"
        "public-beta-record-family-authorization-grant-map.json"
    ),
    "production_release": Path(
        "deployments/record-family-authorization/"
        "production-release-record-family-authorization-grant-map.json"
    ),
}
EXPECTED_EVIDENCE_PATHS: Final = {
    "public_beta": Path(
        "deployments/record-family-authorization/"
        "public-beta-record-family-authorization-evidence.json"
    ),
    "production_release": Path(
        "deployments/record-family-authorization/"
        "production-release-record-family-authorization-evidence.json"
    ),
}

INVENTORY_SCHEMA_VERSION: Final = (
    "6529stream.record-family-authorization-inventory.v1"
)
SOURCE_CATALOG_SCHEMA_VERSION: Final = (
    "6529stream.record-family-authorization-source-catalog.v1"
)
EVIDENCE_SCHEMA_VERSION: Final = (
    "6529stream.record-family-authorization-evidence.v1"
)
GRANT_MAP_SCHEMA_VERSION: Final = (
    "6529stream.record-family-authorization-grant-map.v1"
)
INVENTORY_SCHEMA_ID: Final = (
    "https://6529.io/schemas/record-family-authorization-inventory.v1.schema.json"
)
SOURCE_CATALOG_SCHEMA_ID: Final = (
    "https://6529.io/schemas/"
    "record-family-authorization-source-catalog.v1.schema.json"
)
EVIDENCE_SCHEMA_ID: Final = (
    "https://raw.githubusercontent.com/6529-Collections/6529Stream/main/"
    "deployments/schema/record-family-authorization-evidence.v1.schema.json"
)
GRANT_MAP_SCHEMA_ID: Final = (
    "https://raw.githubusercontent.com/6529-Collections/6529Stream/main/"
    "deployments/schema/record-family-authorization-grant-map.v1.schema.json"
)
JSON_SCHEMA_DRAFT: Final = "https://json-schema.org/draft/2020-12/schema"
TRACKING_ISSUE: Final = (
    "https://github.com/6529-Collections/6529Stream/issues/690"
)
AS_BUILT_SOURCE_COMMIT: Final = "063605ea4fe906b229fd6ae51294fe96f384e698"
AS_BUILT_SOURCE_SHA256: Final = {
    "smart-contracts/StreamCollectionMetadata.sol": (
        "c8eda0b8fd126962a4cbd1b3923b315aa26f1a3edd81422217e6fec194d188b4"
    ),
    "smart-contracts/IStreamCollectionMetadata.sol": (
        "9ee2f79bff66060846d64dbb2d61f30c5febbd28580565989fef8109f518eef6"
    ),
    "smart-contracts/StreamPreservationRecords.sol": (
        "47125f41f62754f0cd563468f6db91d547a9c7d42a0783711eebf71b3431f6c6"
    ),
    "smart-contracts/IStreamPreservationRecords.sol": (
        "e6a9f6e60167ea7f9b9dfcc4492d5d7eec3e4647426693a4a23b6d7b3030606a"
    ),
}

# Source implementation is now present, but a source catalog cannot substitute
# for candidate-bound deployment configuration or reviewed retained evidence.
IMPLEMENTATION_COMPLETION_SUPPORTED: Final = False
COMPLETION_BLOCKER: Final = (
    "candidate_bound_record_family_evidence_not_available: issue #690 remains "
    "an open public-beta and production blocker until the exact candidate, "
    "admitted record-type set, live providers and grants, deployed runtime "
    "codehashes, lifecycle exercise, and independent review are retained"
)

SOURCE_IMPLEMENTATION_COMMIT: Final = (
    "6931aaa6db64e288ee2d67b6b0566ad986d2c856"
)
EXPECTED_SOURCE_BINDINGS: Final = (
    (
        "smart-contracts/IStreamRecordFamilyAuthorityProvider.sol",
        "eb381ae81e56bfa27495c5c20de82843a642995b50d5c07de102e4e20399cb2f",
    ),
    (
        "smart-contracts/IStreamRecordFamilyRegistry.sol",
        "82f39b0c7157c7ae94d4a8e7b3a6aa3c6a9281c471c98af6f3e87cbb8d1aaa95",
    ),
    (
        "smart-contracts/StreamRecordFamilyRegistry.sol",
        "9ffb6e90c1905f8eebf91039f4c947b08d07730038b115f9204a348e52c85bb2",
    ),
    (
        "smart-contracts/IStreamCollectionMetadata.sol",
        "f22398c6650c3de6599c2e6edc48068d251cab782cc2f1f931ea96fdd9877295",
    ),
    (
        "smart-contracts/StreamCollectionMetadata.sol",
        "f25195871f147b2ca47ba12b5a6bff434112e86107ce6371564d7760218770ac",
    ),
    (
        "smart-contracts/IStreamPreservationRecords.sol",
        "bdfbddab0249e6048ab644b7c0f833ca1ed261e706973742b54636089fbdfc54",
    ),
    (
        "smart-contracts/StreamPreservationRecords.sol",
        "271e622ebffdf852e3bb42faa47d08f2731a0c219dea30fda2e6c8a1530ad9ca",
    ),
    (
        "script/RehearseDeployment.s.sol",
        "8ada36c26e300a1497cc9ee422a4c34504ae08014dd7c4bdf9f9d505d7e43026",
    ),
)

EXPECTED_INVENTORY_KEYS: Final = (
    "schema_version",
    "status",
    "tracking_issue",
    "normative_sources",
    "current_implementation",
    "authorization_classes",
    "family_groups",
    "snapshot_policy",
    "classifier_binding",
    "candidate_binding",
    "retained_evidence",
    "blockers",
)
EXPECTED_EVIDENCE_KEYS: Final = (
    "schema_version",
    "record_type",
    "review_status",
    "evidence_id",
    "target_phase",
    "inventory_binding",
    "candidate_binding",
    "profile_binding",
    "classifier_binding",
    "implementation_bindings",
    "grant_map",
    "snapshot_intersection",
    "authority_lifecycle",
    "phases",
    "review",
    "redaction_policy",
    "template_notice",
)

EXPECTED_NORMATIVE_SOURCES: Final = (
    {
        "path": "docs/collection-metadata-contract.md",
        "anchor": "Record-family-scoped authorization [CMC-AUTHZ]:",
    },
    {
        "path": "docs/adr/0010-world-class-spec-pass.md",
        "anchor": "The CON-015 whole-module writer exception is retired",
    },
    {
        "path": "docs/stream-artist-authority.md",
        "anchor": "## Record Discipline And Write Authority [AA-RECORDS]",
    },
    {
        "path": "docs/launch-conformance-matrix.md",
        "anchor": "| Owner records |",
    },
)

EXPECTED_CONTRACTS: Final = (
    {
        "name": "StreamCollectionMetadata",
        "source_path": "smart-contracts/StreamCollectionMetadata.sol",
        "interface_path": "smart-contracts/IStreamCollectionMetadata.sol",
        "mutation_surface_count": 4,
    },
    {
        "name": "StreamPreservationRecords",
        "source_path": "smart-contracts/StreamPreservationRecords.sol",
        "interface_path": "smart-contracts/IStreamPreservationRecords.sol",
        "mutation_surface_count": 1,
    },
)

EXPECTED_SURFACES: Final = (
    (
        "StreamCollectionMetadata",
        "smart-contracts/StreamCollectionMetadata.sol",
        "smart-contracts/IStreamCollectionMetadata.sol",
        "setCollectionRecord",
        "setCollectionRecord(uint256,(bytes32,bytes32,string,bytes32,bytes32,uint64))",
        "0xcf51f66a",
        "record.recordType",
    ),
    (
        "StreamCollectionMetadata",
        "smart-contracts/StreamCollectionMetadata.sol",
        "smart-contracts/IStreamCollectionMetadata.sol",
        "setCollectionRecordWithRevision",
        "setCollectionRecordWithRevision(uint256,(bytes32,bytes32,string,bytes32,bytes32,uint64),uint64)",
        "0x0dd00ba6",
        "record.recordType",
    ),
    (
        "StreamCollectionMetadata",
        "smart-contracts/StreamCollectionMetadata.sol",
        "smart-contracts/IStreamCollectionMetadata.sol",
        "publishCollectionSnapshot",
        "publishCollectionSnapshot(uint256,bytes32,(bytes32,bytes32,string,bytes32,bytes32,uint64))",
        "0xf2d67fbd",
        "snapshot.recordType",
    ),
    (
        "StreamCollectionMetadata",
        "smart-contracts/StreamCollectionMetadata.sol",
        "smart-contracts/IStreamCollectionMetadata.sol",
        "lockCollectionRecord",
        "lockCollectionRecord(uint256,bytes32)",
        "0xe4c05429",
        "recordType",
    ),
    (
        "StreamPreservationRecords",
        "smart-contracts/StreamPreservationRecords.sol",
        "smart-contracts/IStreamPreservationRecords.sol",
        "recordCollectionRecord",
        "recordCollectionRecord(uint256,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64))",
        "0xc3434532",
        "record.recordType",
    ),
)

EXPECTED_AUTHORIZATION_CLASSES: Final = (
    "ARTIST_SIGNER",
    "OWNER_SIGNER",
    "CURATOR_SIGNER",
    "INSTITUTION_SIGNER",
    "INDEPENDENT_ATTESTOR",
    "PRESERVATION_ADMIN",
    "METADATA_ADMIN",
    "GLOBAL_ADMIN",
)
EXPECTED_SOURCE_AUTHORIZATION_CLASSES: Final = (
    (1, "ARTIST_SIGNER", "live_provider"),
    (2, "OWNER_SIGNER", "live_provider"),
    (3, "CURATOR_SIGNER", "family_grant"),
    (4, "INSTITUTION_SIGNER", "live_provider"),
    (5, "INDEPENDENT_ATTESTOR", "direct_self_attributed"),
    (6, "PRESERVATION_ADMIN", "family_grant"),
    (7, "METADATA_ADMIN", "family_grant"),
    (8, "GLOBAL_ADMIN", "family_grant"),
)
EXPECTED_SOURCE_FAMILY_GROUPS: Final = (
    (
        "ARTIST",
        "6529STREAM_RECORD_FAMILY_ARTIST_V1",
        "0x3d8f31ee46ecb9b89fee34e6abc6987daf40ec43650ca838df8f4d4440985fbf",
        (1,),
        True,
    ),
    (
        "OWNER",
        "6529STREAM_RECORD_FAMILY_OWNER_V1",
        "0xc7de3ac1b2e3c40a8c1b3e435f7c65fa15c202d9679c69ee855ef9f5b0725606",
        (2,),
        True,
    ),
    (
        "INDEPENDENT",
        "6529STREAM_RECORD_FAMILY_INDEPENDENT_V1",
        "0x3d6783a53e9ee408332f476190214259f17b7658b5c78835ef36a3297ca949e4",
        (5,),
        True,
    ),
    (
        "CURATOR",
        "6529STREAM_RECORD_FAMILY_CURATOR_V1",
        "0xeeac19d70c3d1ed563ebf5a18bc84d214bf13390dc2c45ec701a679bb51a465c",
        (3, 8),
        False,
    ),
    (
        "INSTITUTION",
        "6529STREAM_RECORD_FAMILY_INSTITUTION_V1",
        "0x3f08fa07a7a50519532a7a1d38176090f0fe3658aa24e2a93a808fda6b167bdd",
        (4,),
        True,
    ),
    (
        "RIGHTS",
        "6529STREAM_RECORD_FAMILY_RIGHTS_V1",
        "0x0ac4845ea7c71ae24076ac125aece1fbe555ad3772b9d4321a8ddfaf72fb1182",
        (7, 8),
        False,
    ),
    (
        "ARCHIVE",
        "6529STREAM_RECORD_FAMILY_ARCHIVE_V1",
        "0x7fe99c2d5382e3f222f07476408e839f3c760fc3bb919399c36210500621cada",
        (6, 8),
        False,
    ),
    (
        "FIXITY",
        "6529STREAM_RECORD_FAMILY_FIXITY_V1",
        "0x371df78414259ffae7f400fb3684d32b79a85ab55ede6d87a9a65cf6719cb47d",
        (4, 6, 8),
        False,
    ),
    (
        "C2PA",
        "6529STREAM_RECORD_FAMILY_C2PA_V1",
        "0xd3afd2b1425b71c3926c945fbd6843d447300ff86666083430b8b6bdd8358dd2",
        (4, 6, 8),
        False,
    ),
    (
        "IIIF",
        "6529STREAM_RECORD_FAMILY_IIIF_V1",
        "0xd079063dbc54d66071a3941cbbb4b013656d970173035f810d1cf9ad90bc34f2",
        (6, 7, 8),
        False,
    ),
    (
        "MEDIA_RELATIONSHIP",
        "6529STREAM_RECORD_FAMILY_MEDIA_RELATIONSHIP_V1",
        "0x01c3e3e144bf723d69bcf723c514c628e82d7d3d971b21830a1d436df414adb6",
        (6, 7),
        False,
    ),
    (
        "IDENTITY_DISPLAY",
        "6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1",
        "0x574230e8aa599708bb647ce64cbe59441a63558adf38401987fd75dbd3a2a977",
        (7, 8),
        False,
    ),
    (
        "SNAPSHOT",
        "6529STREAM_RECORD_FAMILY_SNAPSHOT_V1",
        "0xadc9589adaf8b5c94bffd82dd7d6b973f1bfa1ad6bbb3e6a269d0d39eb266352",
        (7, 8),
        False,
    ),
    (
        "AGENT",
        "6529STREAM_RECORD_FAMILY_AGENT_V1",
        "0x4dbe05954884f7cc073a27786ddb9783d7fe47369ab6faf2cbcb66eb55f72b99",
        (7, 8),
        False,
    ),
)
EXPECTED_SOURCE_HOST_BINDINGS: Final = (
    (
        "StreamCollectionMetadata",
        "smart-contracts/StreamCollectionMetadata.sol",
        "smart-contracts/IStreamCollectionMetadata.sol",
        "0x2c2422f4",
        "immutable",
        True,
    ),
    (
        "StreamPreservationRecords",
        "smart-contracts/StreamPreservationRecords.sol",
        "smart-contracts/IStreamPreservationRecords.sol",
        "0x45cc434d",
        "immutable",
        True,
    ),
)
EXPECTED_SOURCE_TESTS: Final = (
    "test/StreamRecordFamilyAuthorization.t.sol",
    "test/StreamCollectionMetadata.t.sol",
    "test/StreamPreservationRecords.t.sol",
    "test/StreamDeploymentManifest.t.sol",
)
EXPECTED_SOURCE_BLOCKERS: Final = (
    "exact_candidate_binding_not_available",
    "genesis_profile_binding_not_available",
    "production_record_type_admission_set_not_available",
    "artist_owner_institution_provider_bindings_not_available",
    "candidate_grant_map_not_available",
    "deployed_runtime_codehash_evidence_not_available",
    "non_local_rotation_revocation_evidence_not_available",
    "independent_security_review_not_available",
)
AUTHORIZATION_CLASS_HOME: Final = {
    "path": "docs/collection-metadata-contract.md",
    "anchor": "### V1 Onchain Record Primitive",
}
FAMILY_GROUP_HOME: Final = {
    "path": "docs/collection-metadata-contract.md",
    "anchor": "Record-family-scoped authorization [CMC-AUTHZ]:",
}
EXPECTED_FAMILY_GROUPS: Final = (
    ("ARTIST", ("ARTIST_*",)),
    ("OWNER", ("OWNER_*",)),
    ("INDEPENDENT", ("INDEPENDENT_*",)),
    ("CURATOR", ("CURATOR_*",)),
    ("INSTITUTION", ("INSTITUTION_*",)),
    ("RIGHTS", ("RIGHTS_*",)),
    ("ARCHIVE", ("ARCHIVE_*",)),
    ("FIXITY", ("FIXITY_*",)),
    ("C2PA", ("C2PA_*",)),
    ("IIIF", ("IIIF_*",)),
    ("MEDIA_RELATIONSHIP", ("MEDIA_RELATIONSHIP_*",)),
    ("IDENTITY_DISPLAY", ("IDENTITY_*", "DISPLAY_*")),
    ("SNAPSHOT", ("SNAPSHOT_*",)),
    ("AGENT", ("AGENT_*",)),
)
COMMON_FAMILY_GROUP_BLOCKERS: Final = (
    "record_type_ids_not_pinned",
    "family_to_authorization_class_mapping_not_pinned",
)
# [CMC-AUTHZ] permits the named/global administration paths for most families.
# ARTIST and OWNER reject administrator substitution, while INDEPENDENT must
# remain open-entry without administrator blocking or impersonation.
ADMIN_REJECTION_FAMILY_GROUPS: Final = frozenset(
    {
        "ARTIST",
        "OWNER",
        "INDEPENDENT",
    }
)
ADMIN_REJECTION_FAMILY_GROUP_BLOCKERS: Final = (
    "admin_rejection_not_implemented",
)
SNAPSHOT_FAMILY_GROUP_EXTRA_BLOCKERS: Final = (
    "snapshot_family_intersection_not_observable",
)
NORMATIVE_FRAGMENT_BINDINGS: Final = (
    (
        "docs/collection-metadata-contract.md",
        "authorization-class inventory",
        "`recorder` and `authorizationClass` (the record-family authority under which",
        ") are mandatory in every record event",
        "568ef7041420b43b6e14269066404eb0bc54c22df56a2c7ddea680394d17d6cd",
    ),
    (
        "docs/collection-metadata-contract.md",
        "record-family authority table",
        "The genesis record-family authority table is normative:",
        "Authorization rules:",
        "21b1ae4fbf8b182249eedf4745b47359115b47e16ef865e3a9ee13cc3dc74124",
    ),
    (
        "docs/adr/0010-world-class-spec-pass.md",
        "ADR 0010 decision D2.8",
        "8. The CON-015 whole-module writer exception is retired:",
        "### D3. Single-sourcing and requirement identity",
        "949322a1330152bb5d44e98863d9110d613bd38161284427d56d7685a2b11c16",
    ),
    (
        "docs/stream-artist-authority.md",
        "artist record-discipline requirements 1-3",
        "## Record Discipline And Write Authority [AA-RECORDS]",
        "4. The registry maintains rolling record-chain accumulators",
        "004a1ffdec12212de1e28b6a6e1698c3841206d56fe7a9860281bb8d290b684d",
    ),
)
LCM_OWNER_RECORD_ROW_SHA256: Final = (
    "27ea13beb309392873b20c5344f28764eb22fdcf4e325d4b2ccaa70304858780"
)
EXPECTED_FAIL_OPEN: Final = (
    ("arbitrary_metadata_record_type", "smart-contracts/StreamCollectionMetadata.sol", "_validateRecord"),
    ("arbitrary_preservation_record_type", "smart-contracts/StreamPreservationRecords.sol", "_validateRecord"),
    ("opaque_snapshot_family_set", "smart-contracts/StreamCollectionMetadata.sol", "publishCollectionSnapshot"),
    ("arbitrary_lock_record_type", "smart-contracts/StreamCollectionMetadata.sol", "lockCollectionRecord"),
    ("record_type_capacity_exhaustion", "smart-contracts/StreamCollectionMetadata.sol", "_rememberRecordType"),
    ("optional_unverified_preservation_signature", "smart-contracts/StreamPreservationRecords.sol", "_validateRecord"),
    ("authorization_class_event_absent", "smart-contracts/IStreamCollectionMetadata.sol", "CollectionMetadataRecordSet"),
    ("selector_global_admin_family_authority", "smart-contracts/StreamCollectionMetadata.sol", "FunctionAdminRequired"),
)
EXPECTED_BLOCKERS: Final = (
    "implementation_not_supported_in_this_slice",
    "record_type_ids_not_pinned",
    "authorization_class_ids_not_pinned",
    "family_to_authorization_class_mapping_not_pinned",
    "classifier_host_interface_marker_revision_not_pinned",
    "snapshot_family_intersection_not_observable",
    "grant_map_not_available",
    "candidate_binding_not_available",
    "deployed_runtime_evidence_not_available",
    "rotation_revocation_evidence_not_available",
    "independent_review_not_available",
    "whole_module_authorization_present",
)

SURFACE_KEYS: Final = (
    "contract",
    "source_path",
    "interface_path",
    "function",
    "canonical_signature",
    "selector",
    "record_type_source",
    "authorization_model",
    "function_admin_authorized",
    "global_admin_authorized",
    "family_classifier_enforced",
    "family_authorization_enforced",
    "authorization_class_emitted",
    "normative_status",
    "blockers",
)

SHA256_RE: Final = re.compile(r"[0-9a-f]{64}")
KECCAK_RE: Final = re.compile(r"0x[0-9a-f]{64}")
COMMIT_RE: Final = re.compile(r"[0-9a-f]{40}")
ADDRESS_RE: Final = re.compile(r"0x[0-9a-f]{40}")
INTERFACE_ID_RE: Final = re.compile(r"0x[0-9a-f]{8}")
ZERO_ADDRESS: Final = "0x" + "00" * 20
ZERO_KECCAK: Final = "0x" + "00" * 32
REPO_PATH_RE: Final = re.compile(
    r"^(?!/)"
    r'(?!.*[\u0000-\u001F\u007F<>:"\\|?*])'
    r"(?!.*//)"
    r"(?!.*(?:^|/)\.\.?(?:/|$))"
    r".+$"
)
FORBIDDEN_PATHS: Final = frozenset(
    {
        "release-artifacts/latest/release-manifest.json",
        "release-artifacts/latest/risk-register.json",
        "release-artifacts/latest/release-notes.json",
        "release-artifacts/latest/release-notes.md",
        "release-artifacts/latest/bytecode-release-proof.json",
        "release-artifacts/latest/release-candidate-lockfile.json",
        "release-artifacts/latest/SHA256SUMS",
        "release-artifacts/latest/release-checksums.json",
    }
)
FORBIDDEN_PATH_KEYS: Final = frozenset(path.casefold() for path in FORBIDDEN_PATHS)
RESERVED_ROLE_PATHS: Final = frozenset(
    {
        *(path.as_posix() for path in EXPECTED_EVIDENCE_PATHS.values()),
        *(path.as_posix() for path in EXPECTED_GRANT_MAP_PATHS.values()),
    }
)
RESERVED_ROLE_PATH_KEYS: Final = frozenset(
    path.casefold() for path in RESERVED_ROLE_PATHS
)
FORBIDDEN_CANDIDATE_KEYS: Final = frozenset(
    {
        "candidate_sha256",
        "candidate_artifact_sha256",
        "raw_candidate_sha256",
    }
)


class RecordFamilyAuthorizationError(RuntimeError):
    """Raised when the inventory/evidence package is malformed or misleading."""


class _DuplicateKeyError(ValueError):
    pass


def _object_no_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise _DuplicateKeyError(f"duplicate JSON key {key!r}")
        result[key] = value
    return result


def _fail(message: str) -> None:
    raise RecordFamilyAuthorizationError(message)


def _expect(condition: bool, message: str) -> None:
    if not condition:
        _fail(message)


def _check_ijson(value: Any, label: str = "$") -> None:
    if isinstance(value, str):
        try:
            value.encode("utf-8", errors="strict")
        except UnicodeError as exc:
            _fail(f"{label} contains a non-Unicode scalar string: {exc}")
    elif isinstance(value, bool) or value is None:
        return
    elif isinstance(value, int):
        _expect(
            -(2**53) + 1 <= value <= (2**53) - 1,
            f"{label} integer is outside the interoperable I-JSON range",
        )
    elif isinstance(value, float):
        _fail(f"{label} must not contain floating-point JSON numbers")
    elif isinstance(value, list):
        for index, item in enumerate(value):
            _check_ijson(item, f"{label}[{index}]")
    elif isinstance(value, dict):
        for key, item in value.items():
            _check_ijson(key, f"{label}.<key>")
            _check_ijson(item, f"{label}.{key}")
    else:
        _fail(f"{label} contains unsupported JSON type {type(value).__name__}")


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        raise RecordFamilyAuthorizationError(f"cannot read {label}: {exc}") from exc
    try:
        value = json.loads(
            text,
            object_pairs_hook=_object_no_duplicates,
            parse_float=lambda token: (_ for _ in ()).throw(
                ValueError(f"floating-point JSON number {token}")
            ),
            parse_constant=lambda token: (_ for _ in ()).throw(
                ValueError(f"non-finite JSON number {token}")
            ),
        )
    except (json.JSONDecodeError, ValueError, _DuplicateKeyError) as exc:
        raise RecordFamilyAuthorizationError(f"invalid {label}: {exc}") from exc
    _expect(isinstance(value, dict), f"{label} root must be an object")
    _check_ijson(value)
    return value


def _format_schema_path(parts: Sequence[Any]) -> str:
    result = "$"
    for part in parts:
        result += f"[{part}]" if isinstance(part, int) else f"[{part!r}]"
    return result


def _validate_schema(
    schema: dict[str, Any],
    value: dict[str, Any],
    *,
    expected_id: str,
    label: str,
) -> None:
    _validate_schema_definition(
        schema,
        expected_id=expected_id,
        label=label,
    )
    errors = sorted(
        Draft202012Validator(
            schema,
            format_checker=FormatChecker(),
        ).iter_errors(value),
        key=lambda error: (
            _format_schema_path(tuple(error.absolute_path)),
            error.message,
        ),
    )
    if errors:
        error = errors[0]
        _fail(
            f"{label} does not satisfy its schema at "
            f"{_format_schema_path(tuple(error.absolute_path))}: {error.message}"
        )


def _validate_schema_definition(
    schema: dict[str, Any],
    *,
    expected_id: str,
    label: str,
) -> None:
    if Draft202012Validator is None:
        _fail("Draft 2020-12 validation requires the pinned jsonschema dependency")
    _expect(
        schema.get("$schema") == JSON_SCHEMA_DRAFT,
        f"{label} schema must declare {JSON_SCHEMA_DRAFT}",
    )
    _expect(schema.get("$id") == expected_id, f"{label} schema $id mismatch")
    try:
        Draft202012Validator.check_schema(schema)
    except SchemaError as exc:
        raise RecordFamilyAuthorizationError(
            f"{label} schema is invalid Draft 2020-12: {exc.message}"
        ) from exc


def _expect_keys(value: Any, expected: Sequence[str], label: str) -> dict[str, Any]:
    _expect(isinstance(value, dict), f"{label} must be an object")
    actual = tuple(value)
    _expect(
        actual == tuple(expected),
        f"{label} keys/order must be exactly {tuple(expected)!r}, got {actual!r}",
    )
    return value


def _path_is_link_or_reparse(path: Path) -> bool:
    if path.is_symlink():
        return True
    is_junction = getattr(path, "is_junction", None)
    if callable(is_junction) and is_junction():
        return True
    try:
        attrs = getattr(os.lstat(path), "st_file_attributes", 0)
    except OSError:
        return False
    flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return bool(flag and attrs & flag)


def _lstat_or_missing(path: Path, label: str) -> os.stat_result | None:
    try:
        return os.lstat(path)
    except FileNotFoundError:
        return None
    except OSError as exc:
        raise RecordFamilyAuthorizationError(
            f"cannot inspect {label}: {exc}"
        ) from exc


def _metadata_is_link_or_reparse(metadata: os.stat_result) -> bool:
    attrs = getattr(metadata, "st_file_attributes", 0)
    flag = getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)
    return (
        metadata.st_mode & 0o170000 == 0o120000
        or bool(flag and attrs & flag)
    )


def _normalize_raw_repo_path(raw: Any, label: str) -> tuple[str, ...]:
    _expect(isinstance(raw, str) and bool(raw), f"{label} must be a nonempty path")
    _expect(
        REPO_PATH_RE.fullmatch(raw) is not None,
        f"{label} must be a normalized portable repository-relative path",
    )
    _expect(
        unicodedata.normalize("NFC", raw) == raw,
        f"{label} must use canonical NFC Unicode",
    )
    parts = tuple(raw.split("/"))
    _expect(
        all(part not in {"", ".", ".."} for part in parts),
        f"{label} must not contain empty or dot path segments",
    )
    windows_devices = {
        "con",
        "prn",
        "aux",
        "nul",
        *(f"com{index}" for index in range(1, 10)),
        *(f"lpt{index}" for index in range(1, 10)),
    }
    for part in parts:
        _expect(
            part == part.strip() and part == part.rstrip("."),
            f"{label} must not contain leading/trailing space or dot aliases",
        )
        _expect(
            "~" not in part,
            f"{label} must not contain a DOS 8.3 short-name alias",
        )
        _expect(
            part.split(".", 1)[0].casefold() not in windows_devices,
            f"{label} must not contain a Windows device-name alias",
        )
    return parts


def _portable_path_key(raw: Any, label: str) -> str:
    _normalize_raw_repo_path(raw, label)
    assert isinstance(raw, str)
    return raw.casefold()


def resolve_repo_file(repo_root: Path, raw: Any, label: str) -> Path:
    parts = _normalize_raw_repo_path(raw, label)
    assert isinstance(raw, str)
    root = repo_root.resolve(strict=True)
    cursor = root
    for part in parts:
        if cursor.is_dir():
            case_matches = [
                child for child in cursor.iterdir() if child.name.casefold() == part.casefold()
            ]
            if case_matches:
                _expect(
                    len(case_matches) == 1,
                    f"{label} has ambiguous case-insensitive filesystem aliases",
                )
                _expect(
                    case_matches[0].name == part,
                    f"{label} must use the exact on-disk path casing",
                )
                cursor = case_matches[0]
            else:
                cursor /= part
        else:
            cursor /= part
        _expect(
            not _path_is_link_or_reparse(cursor),
            f"{label} must not traverse a symlink, junction, or reparse point",
        )
    try:
        resolved = cursor.resolve(strict=True)
    except OSError as exc:
        raise RecordFamilyAuthorizationError(f"{label} does not exist: {raw}") from exc
    _expect(
        resolved.is_relative_to(root),
        f"{label} resolves outside the repository root",
    )
    _expect(
        resolved.relative_to(root).parts == parts,
        f"{label} must use the exact canonical on-disk path identity",
    )
    _expect(resolved.is_file(), f"{label} must resolve to a regular file")
    return resolved


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _extract_owned_fragment(
    text: str,
    start: str,
    end: str,
    label: str,
) -> str:
    _expect(text.count(start) == 1, f"{label} start boundary must occur exactly once")
    start_index = text.index(start)
    _expect(
        text.count(end, start_index + len(start)) == 1,
        f"{label} end boundary must occur exactly once after its start",
    )
    end_index = text.index(end, start_index + len(start)) + len(end)
    return text[start_index:end_index]


def _validate_normative_bindings(repo_root: Path) -> None:
    for relative, label, start, end, expected_hash in NORMATIVE_FRAGMENT_BINDINGS:
        path = resolve_repo_file(repo_root, relative, f"{label} source")
        fragment = _extract_owned_fragment(
            path.read_text(encoding="utf-8"),
            start,
            end,
            label,
        )
        _expect(
            hashlib.sha256(fragment.encode("utf-8")).hexdigest() == expected_hash,
            f"{label} content drifted from the exact normative owned section",
        )

    lcm_path = resolve_repo_file(
        repo_root,
        "docs/launch-conformance-matrix.md",
        "owner-record conformance row source",
    )
    owner_rows = [
        line
        for line in lcm_path.read_text(encoding="utf-8").splitlines()
        if line.startswith("| Owner records |")
    ]
    _expect(
        len(owner_rows) == 1,
        "owner-record conformance row must occur exactly once",
    )
    _expect(
        hashlib.sha256(owner_rows[0].encode("utf-8")).hexdigest()
        == LCM_OWNER_RECORD_ROW_SHA256,
        "owner-record conformance row drifted from the exact normative mirror",
    )


def _assert_source_unchanged_from_commit(
    repo_root: Path, commit: str, relative_paths: Iterable[str]
) -> None:
    relative_set = set(relative_paths)
    _expect(
        relative_set == set(AS_BUILT_SOURCE_SHA256),
        "as-built source file set does not match the code-owned provenance inventory",
    )
    has_git_metadata = (repo_root / ".git").exists()
    if not has_git_metadata:
        # The v1 planning inventory is retained as a historical baseline.
        # Exported/test fixtures without Git metadata are validated through
        # the live source catalog instead.
        return
    for relative in sorted(relative_set):
        completed = subprocess.run(
            ["git", "show", f"{commit}:{relative}"],
            cwd=repo_root,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
        _expect(
            completed.returncode == 0,
            f"cannot read {relative} at current_implementation.source_commit",
        )
        _expect(
            hashlib.sha256(completed.stdout).hexdigest()
            == AS_BUILT_SOURCE_SHA256[relative],
            f"{relative} historical digest drifted at "
            f"current_implementation.source_commit {commit}",
        )


def _assert_candidate_source_at_commit(
    repo_root: Path,
    commit: str,
    relative: str,
    expected_sha256: str,
    label: str,
) -> Path:
    path = resolve_repo_file(repo_root, relative, f"{label}.path")
    _expect(_sha256(path) == expected_sha256, f"{label} file digest mismatch")
    if not (repo_root / ".git").exists():
        return path
    completed = subprocess.run(
        ["git", "show", f"{commit}:{relative}"],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    _expect(
        completed.returncode == 0,
        f"{label} is not present at candidate source_commit {commit}",
    )
    _expect(
        hashlib.sha256(completed.stdout).hexdigest() == expected_sha256,
        f"{label} digest does not match candidate source_commit {commit}",
    )
    return path


def _validate_source_catalog_semantics(
    catalog: dict[str, Any],
    repo_root: Path,
) -> None:
    _expect_keys(
        catalog,
        (
            "schema_version",
            "status",
            "tracking_issue",
            "source_commit",
            "source_bindings",
            "classifier",
            "authorization_classes",
            "family_groups",
            "host_bindings",
            "snapshot_policy",
            "source_tests",
            "remaining_blockers",
        ),
        "source catalog",
    )
    _expect(
        catalog["schema_version"] == SOURCE_CATALOG_SCHEMA_VERSION,
        "source catalog schema_version mismatch",
    )
    _expect(
        catalog["status"] == "source_implemented_candidate_unbound",
        "source catalog status mismatch",
    )
    _expect(
        catalog["tracking_issue"] == TRACKING_ISSUE,
        "source catalog tracking_issue mismatch",
    )
    _expect(
        catalog["source_commit"] == SOURCE_IMPLEMENTATION_COMMIT,
        "source implementation commit mismatch",
    )

    bindings = catalog["source_bindings"]
    actual_bindings = tuple(
        (row["path"], row["sha256"]) for row in bindings
    )
    _expect(
        actual_bindings == EXPECTED_SOURCE_BINDINGS,
        "source binding paths/digests/order mismatch",
    )
    for index, (relative, digest) in enumerate(EXPECTED_SOURCE_BINDINGS):
        _assert_candidate_source_at_commit(
            repo_root,
            SOURCE_IMPLEMENTATION_COMMIT,
            relative,
            digest,
            f"source_bindings[{index}]",
        )

    classifier = catalog["classifier"]
    _expect(
        classifier
        == {
            "contract": "StreamCollectionMetadata",
            "source_path": "smart-contracts/StreamCollectionMetadata.sol",
            "implementation_source_path": (
                "smart-contracts/StreamRecordFamilyRegistry.sol"
            ),
            "interface_path": "smart-contracts/IStreamRecordFamilyRegistry.sol",
            "authority_provider_interface_path": (
                "smart-contracts/IStreamRecordFamilyAuthorityProvider.sol"
            ),
            "interface_id": "0xb19a79de",
            "marker_selector": "0x20e9f458",
            "schema_version": 1,
            "record_type_admission": "append_only_exact_bytes32",
            "wildcard_admission": False,
            "configuration_authority": "stream_admins_owner",
            "deployment_model": "embedded_in_collection_metadata_host",
            "candidate_binding_status": "not_available",
        },
        "classifier source binding mismatch",
    )

    classes = tuple(
        (row["id"], row["name"], row["mode"])
        for row in catalog["authorization_classes"]
    )
    _expect(
        classes == EXPECTED_SOURCE_AUTHORIZATION_CLASSES,
        "source authorization class catalog mismatch",
    )

    families = tuple(
        (
            row["name"],
            row["id_preimage"],
            row["id"],
            tuple(row["allowed_authorization_class_ids"]),
            row["admin_authority_rejected"],
        )
        for row in catalog["family_groups"]
    )
    _expect(
        families == EXPECTED_SOURCE_FAMILY_GROUPS,
        "source family catalog mismatch",
    )

    hosts = tuple(
        (
            row["contract"],
            row["source_path"],
            row["interface_path"],
            row["interface_id"],
            row["registry_binding"],
            row["authorization_class_persisted"],
        )
        for row in catalog["host_bindings"]
    )
    _expect(hosts == EXPECTED_SOURCE_HOST_BINDINGS, "source host bindings mismatch")

    _expect(
        catalog["snapshot_policy"]
        == {
            "abi": (
                "publishCollectionSnapshot(uint256,bytes32,bytes32[],"
                "(bytes32,bytes32,string,bytes32,bytes32,uint64))"
            ),
            "selector": "0xfc57068f",
            "covered_record_types": "strictly_ascending_nonempty_exact_ids",
            "every_record_type_authority_revalidated": True,
            "covered_record_types_hash_stored": True,
            "per_record_type_authorization_event": True,
        },
        "snapshot source policy mismatch",
    )
    _expect(
        tuple(catalog["source_tests"]) == EXPECTED_SOURCE_TESTS,
        "source test set/order mismatch",
    )
    for index, relative in enumerate(EXPECTED_SOURCE_TESTS):
        resolve_repo_file(repo_root, relative, f"source_tests[{index}]")
    _expect(
        tuple(catalog["remaining_blockers"]) == EXPECTED_SOURCE_BLOCKERS,
        "source catalog blocker set/order mismatch",
    )

    registry_host_source = resolve_repo_file(
        repo_root,
        classifier["source_path"],
        "classifier host source",
    ).read_text(encoding="utf-8")
    registry_source = resolve_repo_file(
        repo_root,
        classifier["implementation_source_path"],
        "classifier implementation source",
    ).read_text(encoding="utf-8")
    registry_interface = resolve_repo_file(
        repo_root,
        classifier["interface_path"],
        "classifier interface",
    ).read_text(encoding="utf-8")
    provider_interface = resolve_repo_file(
        repo_root,
        classifier["authority_provider_interface_path"],
        "authority provider interface",
    ).read_text(encoding="utf-8")
    for class_id, class_name, _ in EXPECTED_SOURCE_AUTHORIZATION_CLASSES:
        _expect(
            f"AUTHORIZATION_CLASS_{class_name} = {class_id}" in registry_source,
            f"source authorization class {class_name} constant mismatch",
        )
    for name, preimage, _, _, _ in EXPECTED_SOURCE_FAMILY_GROUPS:
        _expect(
            f'keccak256("{preimage}")' in registry_source,
            f"source family {name} preimage missing",
        )
    for anchor in (
        "function admitRecordType",
        "function setRecordFamilyGrant",
        "function setAuthorityProvider",
        "function requireRecordWriter",
        "provider.codehash != expectedCodeHash",
        "provider.staticcall(",
        "revert RecordTypeNotAdmitted(recordType)",
    ):
        _expect(anchor in registry_source, f"classifier source anchor missing: {anchor}")
    _expect(
        "isAuthorizedRecordWriter" in provider_interface,
        "authority-provider predicate missing",
    )
    _expect(
        "StreamRecordFamilyRegistry" in registry_host_source
        and "recordFamilyRegistry = address(this)" in registry_host_source,
        "classifier must remain embedded in the collection metadata host",
    )
    _expect(
        "function recordTypePolicy" in registry_interface,
        "exact record-type policy read missing",
    )

    metadata_source = resolve_repo_file(
        repo_root,
        "smart-contracts/StreamCollectionMetadata.sol",
        "metadata host source",
    ).read_text(encoding="utf-8")
    preservation_source = resolve_repo_file(
        repo_root,
        "smart-contracts/StreamPreservationRecords.sol",
        "preservation host source",
    ).read_text(encoding="utf-8")
    for anchor in (
        "_recordFamilyRegistry.requireRecordWriter",
        "_requireSnapshotFamilyIntersection",
        "InvalidSnapshotRecordType",
        "_snapshotCoveredRecordTypesHashes",
        "authorizationClass: authorizationClass",
    ):
        _expect(anchor in metadata_source, f"metadata host anchor missing: {anchor}")
    for anchor in (
        "_recordFamilyRegistry.requireRecordWriter",
        "authorizationClass: authorizationClass",
    ):
        _expect(
            anchor in preservation_source,
            f"preservation host anchor missing: {anchor}",
        )


def _validate_inventory_semantics(inventory: dict[str, Any], repo_root: Path) -> None:
    _expect_keys(inventory, EXPECTED_INVENTORY_KEYS, "inventory")
    _expect(
        inventory["schema_version"] == INVENTORY_SCHEMA_VERSION,
        "inventory schema_version mismatch",
    )
    _expect(inventory["status"] == "planning", "inventory status must remain planning")
    _expect(inventory["tracking_issue"] == TRACKING_ISSUE, "tracking_issue mismatch")
    _expect(
        tuple(inventory["normative_sources"]) == EXPECTED_NORMATIVE_SOURCES,
        "normative_sources must match the exact ordered four-row inventory",
    )
    for index, source in enumerate(inventory["normative_sources"]):
        path = resolve_repo_file(repo_root, source["path"], f"normative_sources[{index}].path")
        count = path.read_text(encoding="utf-8").count(source["anchor"])
        _expect(
            count == 1,
            f"normative_sources[{index}].anchor must occur exactly once in "
            f"{source['path']}, got {count}",
        )
    _validate_normative_bindings(repo_root)

    current = _expect_keys(
        inventory["current_implementation"],
        (
            "status",
            "source_commit",
            "contracts",
            "mutation_surfaces",
            "known_fail_open_behaviors",
        ),
        "current_implementation",
    )
    _expect(current["status"] == "as_built_fail_open", "current implementation status mismatch")
    _expect(
        current["source_commit"] == AS_BUILT_SOURCE_COMMIT,
        "current implementation source commit mismatch",
    )
    _expect(tuple(current["contracts"]) == EXPECTED_CONTRACTS, "contract rows mismatch")

    surfaces = current["mutation_surfaces"]
    _expect(isinstance(surfaces, list) and len(surfaces) == 5, "exactly five mutation surfaces required")
    source_paths: list[str] = []
    for index, (row, expected) in enumerate(zip(surfaces, EXPECTED_SURFACES, strict=True)):
        _expect_keys(row, SURFACE_KEYS, f"mutation_surfaces[{index}]")
        actual = (
            row["contract"],
            row["source_path"],
            row["interface_path"],
            row["function"],
            row["canonical_signature"],
            row["selector"],
            row["record_type_source"],
        )
        _expect(actual == expected, f"mutation_surfaces[{index}] exact identity mismatch")
        _expect(row["authorization_model"] == "selector_or_global_admin", f"mutation_surfaces[{index}] authorization model mismatch")
        _expect(row["function_admin_authorized"] is True, f"mutation_surfaces[{index}] must expose function-admin authority")
        _expect(row["global_admin_authorized"] is True, f"mutation_surfaces[{index}] must expose global-admin authority")
        _expect(row["family_classifier_enforced"] is False, f"mutation_surfaces[{index}] falsely claims a classifier")
        _expect(row["family_authorization_enforced"] is False, f"mutation_surfaces[{index}] falsely claims family authorization")
        _expect(row["authorization_class_emitted"] is False, f"mutation_surfaces[{index}] falsely claims authorization-class events")
        _expect(row["normative_status"] == "nonconformant", f"mutation_surfaces[{index}] must remain nonconformant")
        _expect(isinstance(row["blockers"], list) and row["blockers"], f"mutation_surfaces[{index}] blockers required")
        source = resolve_repo_file(repo_root, row["source_path"], f"mutation_surfaces[{index}].source_path")
        interface = resolve_repo_file(repo_root, row["interface_path"], f"mutation_surfaces[{index}].interface_path")
        source_text = source.read_text(encoding="utf-8")
        interface_text = interface.read_text(encoding="utf-8")
        _expect(f"function {row['function']}" in interface_text, f"{row['function']} missing from interface")
        _expect(f"function {row['function']}" in source_text, f"{row['function']} missing from implementation")
        source_paths.extend((row["source_path"], row["interface_path"]))

    failures = current["known_fail_open_behaviors"]
    _expect(isinstance(failures, list) and len(failures) == 8, "exactly eight fail-open findings required")
    for index, (row, expected) in enumerate(zip(failures, EXPECTED_FAIL_OPEN, strict=True)):
        _expect_keys(row, ("id", "source_path", "source_anchor", "status", "description"), f"known_fail_open_behaviors[{index}]")
        _expect((row["id"], row["source_path"], row["source_anchor"]) == expected, f"known_fail_open_behaviors[{index}] identity mismatch")
        _expect(row["status"] == "open_blocker", f"known_fail_open_behaviors[{index}] must remain open_blocker")
        _expect(isinstance(row["description"], str) and bool(row["description"]), f"known_fail_open_behaviors[{index}] description required")
        path = resolve_repo_file(repo_root, row["source_path"], f"known_fail_open_behaviors[{index}].source_path")
        source_paths.append(row["source_path"])
    _assert_source_unchanged_from_commit(
        repo_root,
        current["source_commit"],
        (path for path in source_paths if path.startswith("smart-contracts/")),
    )

    classes = inventory["authorization_classes"]
    _expect(isinstance(classes, list) and len(classes) == 8, "exactly eight authorization classes required")
    _expect(tuple(row["name"] for row in classes) == EXPECTED_AUTHORIZATION_CLASSES, "authorization classes/order mismatch")
    for index, row in enumerate(classes):
        _expect_keys(row, ("name", "normative_source", "onchain_id", "status", "blockers"), f"authorization_classes[{index}]")
        _expect(row["normative_source"] == AUTHORIZATION_CLASS_HOME, f"authorization_classes[{index}] normative source mismatch")
        home = resolve_repo_file(repo_root, row["normative_source"]["path"], f"authorization_classes[{index}].normative_source.path")
        count = home.read_text(encoding="utf-8").count(row["normative_source"]["anchor"])
        _expect(count == 1, f"authorization_classes[{index}] normative home anchor must occur exactly once, got {count}")
        _expect(row["onchain_id"] is None, f"authorization_classes[{index}] must not invent an onchain id")
        _expect(row["status"] == "planning", f"authorization_classes[{index}] must remain planning")
        _expect(row["blockers"] == ["authorization_class_id_not_pinned"], f"authorization_classes[{index}] blocker mismatch")

    groups = inventory["family_groups"]
    _expect(isinstance(groups, list) and len(groups) == 14, "exactly fourteen family groups required")
    _expect(tuple((row["name"], tuple(row["normative_patterns"])) for row in groups) == EXPECTED_FAMILY_GROUPS, "family groups/order/patterns mismatch")
    for index, row in enumerate(groups):
        _expect_keys(row, ("name", "normative_patterns", "normative_source", "declared_record_type_ids", "authorization_classes", "classification_status", "implementation_status", "blockers"), f"family_groups[{index}]")
        _expect(row["normative_source"] == FAMILY_GROUP_HOME, f"family_groups[{index}] normative source mismatch")
        home = resolve_repo_file(repo_root, row["normative_source"]["path"], f"family_groups[{index}].normative_source.path")
        count = home.read_text(encoding="utf-8").count(row["normative_source"]["anchor"])
        _expect(count == 1, f"family_groups[{index}] normative home anchor must occur exactly once, got {count}")
        _expect(row["declared_record_type_ids"] == [], f"family_groups[{index}] must not invent wildcard-derived IDs")
        _expect(row["authorization_classes"] == [], f"family_groups[{index}] must not invent the unresolved 14-to-8 mapping")
        _expect(row["classification_status"] == "unresolved", f"family_groups[{index}] classification must remain unresolved")
        _expect(row["implementation_status"] == "not_implemented", f"family_groups[{index}] implementation must remain missing")
        expected_blockers = COMMON_FAMILY_GROUP_BLOCKERS
        if row["name"] in ADMIN_REJECTION_FAMILY_GROUPS:
            expected_blockers += ADMIN_REJECTION_FAMILY_GROUP_BLOCKERS
        if row["name"] == "SNAPSHOT":
            expected_blockers += SNAPSHOT_FAMILY_GROUP_EXTRA_BLOCKERS
        _expect(
            tuple(row["blockers"]) == expected_blockers,
            f"family_groups[{index}] blockers mismatch",
        )

    snapshot = inventory["snapshot_policy"]
    _expect(snapshot["normative_every_family_authority_required"] is True, "snapshot policy must retain every-family authority")
    _expect(snapshot["runtime_record_type_source"] == "snapshot.recordType", "snapshot runtime source mismatch")
    _expect(snapshot["manifest_family_set_observable"] is False, "snapshot manifest family set is not observable")
    _expect(snapshot["family_authorization_enforced"] is False, "snapshot family intersection is not enforced")
    _expect(snapshot["locks_checked"] == ["METADATA_ALL", "SNAPSHOTS", "recordType"], "snapshot lock set mismatch")
    _expect(snapshot["status"] == "planning", "snapshot status must remain planning")

    classifier = inventory["classifier_binding"]
    _expect(classifier["status"] == "missing", "classifier binding must remain missing")
    for key in ("classifier_host", "classifier_contract", "module_type", "interface_id", "marker", "schema", "revision", "runtime_codehash", "grant_map_binding", "record_type_registry", "wildcard_derivation"):
        _expect(classifier[key] is None, f"classifier_binding.{key} must remain unavailable")
    _expect(classifier["unknown_family_disposition"] == "currently_accepted", "unknown-family fail-open disposition mismatch")

    candidate = inventory["candidate_binding"]
    _expect(candidate["status"] == "not_available", "candidate binding must remain unavailable")
    for key in ("candidate_id", "candidate_identity_sha256", "candidate_identity_keccak256", "source_commit", "release_build", "genesis_profile_sha256", "grant_map_sha256"):
        _expect(candidate[key] is None, f"candidate_binding.{key} must remain null")

    evidence = inventory["retained_evidence"]
    _expect(isinstance(evidence, list) and len(evidence) == 2, "two retained-evidence phase rows required")
    expected_evidence = tuple(
        (
            phase,
            EXPECTED_EVIDENCE_PATHS[phase].as_posix(),
        )
        for phase in ("public_beta", "production_release")
    )
    for index, (row, (phase, path)) in enumerate(zip(evidence, expected_evidence, strict=True)):
        _expect(row["phase"] == phase and row["path"] == path, f"retained_evidence[{index}] phase/path mismatch")
        _expect(row["status"] == "missing", f"retained_evidence[{index}] must remain missing")
        _expect(row["schema_version"] == EVIDENCE_SCHEMA_VERSION, f"retained_evidence[{index}] schema mismatch")
        _expect(row["template_path"] == DEFAULT_EVIDENCE_TEMPLATE.as_posix(), f"retained_evidence[{index}] template mismatch")

    _expect(tuple(inventory["blockers"]) == EXPECTED_BLOCKERS, "inventory blockers/order mismatch")


def _reject_forbidden_transit(
    value: Any,
    *,
    evidence_input_path: str,
    json_path: tuple[str, ...] = (),
    allowed_reserved_paths: dict[
        tuple[str, ...], frozenset[str]
    ] | None = None,
) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            _expect(
                key not in FORBIDDEN_CANDIDATE_KEYS,
                f"forbidden raw candidate hash key {key!r}",
            )
            current = (*json_path, key)
            if key in {
                "path",
                "schema_path",
                "evidence_path",
                "candidate_identity_path",
                "source_path",
                "interface_path",
            } and isinstance(item, str):
                path_key = _portable_path_key(
                    item,
                    ".".join(current),
                )
                if current in {
                    ("inventory_binding", "path"),
                    ("profile_binding", "path"),
                }:
                    _reject_forbidden_transit(
                        item,
                        evidence_input_path=evidence_input_path,
                        json_path=current,
                        allowed_reserved_paths=allowed_reserved_paths,
                    )
                    continue
                forbidden_keys = FORBIDDEN_PATH_KEYS | {
                    DEFAULT_INVENTORY.as_posix().casefold(),
                    DEFAULT_EVIDENCE_TEMPLATE.as_posix().casefold(),
                    evidence_input_path.casefold(),
                }
                _expect(
                    path_key not in forbidden_keys,
                    f"cyclic/downstream evidence path is forbidden: {item}",
                )
                _expect(
                    not path_key.startswith(
                        "release-artifacts/latest/"
                    ),
                    f"generated release-tail evidence path is forbidden: "
                    f"{item}",
                )
                allowed_keys = (
                    allowed_reserved_paths.get(current, frozenset())
                    if allowed_reserved_paths is not None
                    else frozenset()
                )
                _expect(
                    path_key not in RESERVED_ROLE_PATH_KEYS
                    or path_key in allowed_keys,
                    f"reserved record-family artifact path is forbidden "
                    f"for {'.'.join(current)}: {item}",
                )
                _expect(
                    current == ("candidate_binding", "candidate_identity_path")
                    or "candidate" not in item.lower(),
                    f"raw candidate artifact path is forbidden: {item}",
                )
                _expect(
                    REPO_PATH_RE.fullmatch(item) is not None,
                    f"evidence support path must be normalized: {item}",
                )
            _reject_forbidden_transit(
                item,
                evidence_input_path=evidence_input_path,
                json_path=current,
                allowed_reserved_paths=allowed_reserved_paths,
            )
    elif isinstance(value, list):
        for item in value:
            _reject_forbidden_transit(
                item,
                evidence_input_path=evidence_input_path,
                json_path=json_path,
                allowed_reserved_paths=allowed_reserved_paths,
            )


def _allowed_reserved_transit_paths(
    evidence: dict[str, Any],
) -> dict[tuple[str, ...], frozenset[str]]:
    target_phase = evidence.get("target_phase")
    allowed: dict[tuple[str, ...], frozenset[str]] = {}
    if target_phase in EXPECTED_GRANT_MAP_PATHS:
        allowed[("grant_map", "path")] = frozenset(
            path.as_posix().casefold()
            for path in EXPECTED_GRANT_MAP_PATHS.values()
        )
    if target_phase == "production_release":
        allowed[("phases", "evidence_path")] = frozenset(
            {
                EXPECTED_EVIDENCE_PATHS["public_beta"]
                .as_posix()
                .casefold()
            }
        )
    return allowed


def _validate_template_semantics(
    evidence: dict[str, Any], inventory: dict[str, Any], inventory_path: Path
) -> None:
    _expect_keys(evidence, EXPECTED_EVIDENCE_KEYS, "evidence template")
    _expect(evidence["schema_version"] == EVIDENCE_SCHEMA_VERSION, "evidence schema_version mismatch")
    _expect(evidence["record_type"] == "template", "committed evidence must remain a template")
    _expect(evidence["review_status"] == "unreviewed", "committed evidence must remain unreviewed")
    _expect(evidence["evidence_id"] == "record-family-authorization-evidence-template", "template evidence_id mismatch")
    _expect(evidence["target_phase"] is None, "template target_phase must remain null")

    binding = evidence["inventory_binding"]
    _expect(binding["status"] == "planning_bound", "template inventory binding must be planning_bound")
    _expect(binding["path"] == DEFAULT_INVENTORY.as_posix(), "template inventory path mismatch")
    _expect(binding["schema_version"] == INVENTORY_SCHEMA_VERSION, "template inventory schema mismatch")
    _expect(binding["sha256"] == _sha256(inventory_path), "template raw inventory SHA-256 mismatch")

    candidate = evidence["candidate_binding"]
    _expect(candidate["status"] == "not_available", "template candidate binding must remain unavailable")
    for key in ("candidate_id", "candidate_identity_sha256", "candidate_identity_keccak256", "candidate_identity_path", "source_commit", "release_build", "genesis_profile_sha256"):
        _expect(candidate[key] is None, f"evidence candidate_binding.{key} must remain null")
        if key != "candidate_identity_path":
            _expect(candidate.get(key) == inventory["candidate_binding"].get(key), f"inventory/evidence candidate_binding.{key} split-brain")

    profile = evidence["profile_binding"]
    _expect(profile == {"status": "missing", "path": "release-artifacts/genesis-deployment-profile.json", "schema_version": "6529stream.genesis-deployment-profile.v2", "sha256": None}, "template profile binding mismatch")

    classifier = evidence["classifier_binding"]
    _expect(classifier["status"] == "missing", "template classifier binding must remain missing")
    for key in ("host_address", "contract_address", "module_type", "interface_id", "marker", "schema", "revision", "runtime_codehash", "grant_map_sha256"):
        _expect(classifier[key] is None, f"evidence classifier_binding.{key} must remain null")

    implementations = evidence["implementation_bindings"]
    _expect(implementations == {"status": "missing", "review_status": "unreviewed", "contracts": []}, "template implementation bindings must remain missing/unreviewed")
    grant = evidence["grant_map"]
    _expect(grant["status"] == "missing" and grant["review_status"] == "unreviewed", "template grant map must remain missing/unreviewed")
    _expect(
        grant["schema_path"] == DEFAULT_GRANT_MAP_SCHEMA.as_posix()
        and grant["schema_version"] == GRANT_MAP_SCHEMA_VERSION,
        "template grant-map schema binding mismatch",
    )
    for key in ("path", "sha256", "family_group_count", "authorization_class_count", "candidate_identity_sha256"):
        _expect(grant[key] is None, f"template grant_map.{key} must remain null")
    snapshot = evidence["snapshot_intersection"]
    _expect(snapshot == {"status": "missing", "review_status": "unreviewed", "covered_family_groups": [], "evidence_path": None, "evidence_sha256": None}, "template snapshot intersection must remain missing/unreviewed")
    lifecycle = evidence["authority_lifecycle"]
    _expect(lifecycle["status"] == "missing" and lifecycle["review_status"] == "unreviewed", "template authority lifecycle must remain missing/unreviewed")
    for key in ("rotation_revision", "revocation_revision", "observed_at_commit", "evidence_path", "evidence_sha256"):
        _expect(lifecycle[key] is None, f"template authority_lifecycle.{key} must remain null")

    phases = evidence["phases"]
    _expect(isinstance(phases, list) and len(phases) == 2, "template must contain exactly two phase rows")
    for index, phase in enumerate(("public_beta", "production_release")):
        row = phases[index]
        _expect(row["phase"] == phase, f"phases[{index}] order/name mismatch")
        _expect(row["status"] == "missing" and row["review_status"] == "unreviewed", f"phases[{index}] must remain missing/unreviewed")
        _expect(row["evidence_path"] is None and row["evidence_sha256"] is None, f"phases[{index}] must not claim retained evidence")

    _expect(evidence["review"] == {"reviewer": None, "reviewed_at": None, "reference": None}, "template review must remain empty")
    _expect(evidence["redaction_policy"]["no_secrets"] is True, "template must prohibit secrets")
    required_redactions = {"private_key", "mnemonic", "seed_phrase", "api_key", "rpc_url"}
    _expect(set(evidence["redaction_policy"]["redacted_fields"]) == required_redactions, "template redaction field set mismatch")
    notice = evidence["template_notice"]
    _expect(isinstance(notice, str) and "not retained evidence" in notice and "cannot satisfy" in notice, "template notice must state its non-evidence release boundary")

    _reject_forbidden_transit(
        evidence,
        evidence_input_path=DEFAULT_EVIDENCE_TEMPLATE.as_posix(),
    )


def _existing_release_tail_files(
    repo_root: Path,
) -> tuple[tuple[str, Path], ...]:
    release_root = repo_root / "release-artifacts"
    latest_root = release_root / "latest"
    for label, directory in (
        ("release-artifacts directory", release_root),
        ("release-artifacts/latest directory", latest_root),
    ):
        metadata = _lstat_or_missing(directory, label)
        if metadata is None:
            return ()
        _expect(
            not _metadata_is_link_or_reparse(metadata),
            f"{label} must not be a symlink, junction, or reparse point",
        )
        _expect(stat.S_ISDIR(metadata.st_mode), f"{label} must be a directory")

    files: list[tuple[str, Path]] = []

    def visit(directory: Path) -> None:
        try:
            with os.scandir(directory) as iterator:
                entries = sorted(
                    iterator,
                    key=lambda entry: entry.name.casefold(),
                )
        except OSError as exc:
            raise RecordFamilyAuthorizationError(
                f"cannot enumerate release output directory "
                f"{directory.relative_to(repo_root).as_posix()}: {exc}"
            ) from exc

        folded_names: set[str] = set()
        for entry in entries:
            folded_name = entry.name.casefold()
            _expect(
                folded_name not in folded_names,
                "release-artifacts/latest must not contain "
                "case-ambiguous filesystem aliases",
            )
            folded_names.add(folded_name)
            candidate = directory / entry.name
            relative = candidate.relative_to(repo_root).as_posix()
            try:
                metadata = entry.stat(follow_symlinks=False)
            except OSError as exc:
                raise RecordFamilyAuthorizationError(
                    f"cannot inspect release output {relative}: {exc}"
                ) from exc
            _expect(
                not _metadata_is_link_or_reparse(metadata),
                f"release output {relative} must not be a symlink, "
                "junction, or reparse point",
            )
            if stat.S_ISDIR(metadata.st_mode):
                visit(candidate)
                continue
            _expect(
                stat.S_ISREG(metadata.st_mode),
                f"release output {relative} must be a regular file",
            )
            files.append((relative, candidate))

    visit(latest_root)
    return tuple(files)


def _register_distinct_file(
    registered: list[tuple[str, Path]],
    label: str,
    path: Path,
    *,
    repo_root: Path,
    allowed_reserved_paths: frozenset[str] = frozenset(),
) -> None:
    allowed_reserved_keys = frozenset(
        value.casefold() for value in allowed_reserved_paths
    )
    forbidden_files = list(_existing_release_tail_files(repo_root))
    for reserved_relative in sorted(RESERVED_ROLE_PATHS):
        reserved_path = repo_root / reserved_relative
        metadata = _lstat_or_missing(
            reserved_path,
            f"reserved record-family artifact {reserved_relative}",
        )
        if metadata is None:
            continue
        forbidden_files.append((reserved_relative, reserved_path))

    for forbidden_relative, forbidden_path in forbidden_files:
        if forbidden_relative.casefold() in allowed_reserved_keys:
            continue
        try:
            aliases_forbidden = os.path.samefile(path, forbidden_path)
        except OSError as exc:
            raise RecordFamilyAuthorizationError(
                f"cannot compare {label} with forbidden release output "
                f"{forbidden_relative}: {exc}"
            ) from exc
        _expect(
            not aliases_forbidden,
            f"{label} must not alias forbidden release output "
            f"{forbidden_relative}",
        )
    for other_label, other_path in registered:
        try:
            aliases = os.path.samefile(path, other_path)
        except OSError as exc:
            raise RecordFamilyAuthorizationError(
                f"cannot compare {label} with {other_label}: {exc}"
            ) from exc
        _expect(
            not aliases,
            f"{label} must be a distinct file from {other_label}",
        )
    registered.append((label, path))


def _load_bound_support(
    repo_root: Path,
    raw_path: Any,
    expected_sha256: Any,
    label: str,
    registered: list[tuple[str, Path]],
    *,
    allowed_reserved_paths: frozenset[str] = frozenset(),
) -> tuple[Path, dict[str, Any]]:
    _expect(
        isinstance(expected_sha256, str)
        and SHA256_RE.fullmatch(expected_sha256) is not None
        and expected_sha256 != "0" * 64,
        f"{label} SHA-256 must be nonzero",
    )
    path = resolve_repo_file(repo_root, raw_path, f"{label}.path")
    relative_path = path.relative_to(repo_root).as_posix()
    _expect(
        relative_path.startswith(
            "deployments/record-family-authorization/"
        ),
        f"{label} must remain in the dedicated record-family "
        f"authorization namespace",
    )
    _register_distinct_file(
        registered,
        label,
        path,
        repo_root=repo_root,
        allowed_reserved_paths=allowed_reserved_paths,
    )
    _expect(_sha256(path) == expected_sha256, f"{label} file digest mismatch")
    return path, load_json(path, label)


def _expect_support_header(
    support: dict[str, Any],
    *,
    artifact_type: str,
    target_phase: str,
    candidate_identity_sha256: str,
    grant_map_sha256: str,
    extra_keys: Sequence[str],
    label: str,
) -> None:
    _expect_keys(
        support,
        (
            "schema_version",
            "artifact_type",
            "target_phase",
            "candidate_identity_sha256",
            "grant_map_sha256",
            *extra_keys,
        ),
        label,
    )
    _expect(
        support["schema_version"]
        == "6529stream.record-family-authorization-support.v1",
        f"{label} schema_version mismatch",
    )
    _expect(support["artifact_type"] == artifact_type, f"{label} artifact_type mismatch")
    _expect(support["target_phase"] == target_phase, f"{label} target_phase mismatch")
    _expect(
        support["candidate_identity_sha256"] == candidate_identity_sha256,
        f"{label} candidate identity mismatch",
    )
    _expect(
        support["grant_map_sha256"] == grant_map_sha256,
        f"{label} grant-map digest mismatch",
    )


def _validate_complete_evidence_semantics(
    evidence: dict[str, Any],
    inventory: dict[str, Any],
    inventory_path: Path,
    evidence_path: Path,
    repo_root: Path,
    evidence_schema: dict[str, Any],
    grant_map_schema: dict[str, Any],
    *,
    enforce_inventory_candidate_dependency: bool = True,
) -> None:
    """Validate a coherent future retained envelope before the hard release stop."""
    _expect_keys(evidence, EXPECTED_EVIDENCE_KEYS, "retained evidence")
    _expect(evidence["schema_version"] == EVIDENCE_SCHEMA_VERSION, "retained evidence schema_version mismatch")
    _expect(evidence["record_type"] == "retained_evidence", "retained evidence record_type mismatch")
    _expect(evidence["review_status"] == "reviewed", "retained evidence must be reviewed")
    target_phase = evidence["target_phase"]
    _expect(
        target_phase in {"public_beta", "production_release"},
        "retained evidence target_phase mismatch",
    )
    expected_evidence_id = {
        "public_beta": "record-family-authorization-public-beta-v1",
        "production_release": "record-family-authorization-production-release-v1",
    }[target_phase]
    _expect(
        evidence["evidence_id"] == expected_evidence_id,
        "retained evidence_id does not match target_phase",
    )

    evidence_relative = evidence_path.relative_to(repo_root).as_posix()
    matching_inventory_rows = [
        row
        for row in inventory["retained_evidence"]
        if row["path"] == evidence_relative
    ]
    _expect(
        len(matching_inventory_rows) == 1,
        "retained evidence input path must match exactly one inventory phase row",
    )
    _expect(
        matching_inventory_rows[0]["phase"] == target_phase,
        "retained evidence input path/target_phase mismatch",
    )

    phases = evidence["phases"]
    _expect(
        [row["phase"] for row in phases] == ["public_beta", "production_release"],
        "retained phases must be exact and ordered",
    )
    expected_phase_states = (
        (("complete", "reviewed"), ("missing", "unreviewed"))
        if target_phase == "public_beta"
        else (("complete", "reviewed"), ("complete", "reviewed"))
    )
    for index, (status, review_status) in enumerate(expected_phase_states):
        row = phases[index]
        _expect(
            (row["status"], row["review_status"]) == (status, review_status),
            f"phases[{index}] status/review matrix mismatch for {target_phase}",
        )
        if status == "missing":
            _expect(
                row["evidence_path"] is None and row["evidence_sha256"] is None,
                f"phases[{index}] missing predecessor must not claim support evidence",
            )

    inventory_binding = evidence["inventory_binding"]
    _expect(inventory_binding["status"] == "complete", "retained inventory binding must be complete")
    _expect(inventory_binding["path"] == DEFAULT_INVENTORY.as_posix(), "retained inventory path mismatch")
    _expect(inventory_binding["schema_version"] == INVENTORY_SCHEMA_VERSION, "retained inventory schema mismatch")
    _expect(inventory_binding["sha256"] == _sha256(inventory_path), "retained raw inventory SHA-256 mismatch")

    registered_files: list[tuple[str, Path]] = []
    _register_distinct_file(
        registered_files,
        "inventory",
        inventory_path,
        repo_root=repo_root,
    )
    _register_distinct_file(
        registered_files,
        "evidence envelope",
        evidence_path,
        repo_root=repo_root,
        allowed_reserved_paths=frozenset(
            {evidence_path.relative_to(repo_root).as_posix()}
        ),
    )

    candidate = evidence["candidate_binding"]
    _expect(candidate["status"] == "complete", "retained candidate binding must be complete")
    _expect(isinstance(candidate["candidate_id"], str) and bool(candidate["candidate_id"].strip()), "candidate_id is required")
    _expect(SHA256_RE.fullmatch(candidate["candidate_identity_sha256"]) is not None and candidate["candidate_identity_sha256"] != "0" * 64, "candidate identity SHA-256 is malformed or zero")
    _expect(KECCAK_RE.fullmatch(candidate["candidate_identity_keccak256"]) is not None and candidate["candidate_identity_keccak256"] != ZERO_KECCAK, "candidate identity Keccak is malformed or zero")
    _expect(COMMIT_RE.fullmatch(candidate["source_commit"]) is not None and candidate["source_commit"] != "0" * 40, "candidate source commit is malformed or zero")
    _expect(isinstance(candidate["release_build"], str) and bool(candidate["release_build"].strip()), "candidate release build is required")
    _expect(SHA256_RE.fullmatch(candidate["genesis_profile_sha256"]) is not None and candidate["genesis_profile_sha256"] != "0" * 64, "candidate profile digest is malformed or zero")
    candidate_identity_path = resolve_repo_file(
        repo_root,
        candidate["candidate_identity_path"],
        "candidate_binding.candidate_identity_path",
    )
    _expect(
        candidate_identity_path.relative_to(repo_root)
        .as_posix()
        .startswith("deployments/record-family-authorization/"),
        "candidate identity projection must remain in the dedicated "
        "record-family authorization namespace until #656 pins its exact "
        "projection path",
    )
    _register_distinct_file(
        registered_files,
        "candidate identity projection",
        candidate_identity_path,
        repo_root=repo_root,
    )
    candidate_projection = load_json(
        candidate_identity_path,
        "candidate identity projection",
    )
    _expect_keys(
        candidate_projection,
        (
            "schema_version",
            "candidate_id",
            "candidate_identity_sha256",
            "candidate_identity_keccak256",
            "source_commit",
            "release_build",
            "genesis_profile_sha256",
        ),
        "candidate identity projection",
    )
    _expect(
        candidate_projection["schema_version"]
        == "6529stream.genesis-deployment-candidate-identity.v1",
        "candidate identity projection schema_version mismatch",
    )
    for key in (
        "candidate_id",
        "candidate_identity_sha256",
        "candidate_identity_keccak256",
        "source_commit",
        "release_build",
        "genesis_profile_sha256",
    ):
        _expect(
            candidate_projection[key] == candidate[key],
            f"candidate identity projection {key} mismatch",
        )

    profile = evidence["profile_binding"]
    _expect(profile["status"] == "complete", "retained profile binding must be complete")
    _expect(profile["sha256"] == candidate["genesis_profile_sha256"], "candidate/profile digest mismatch")
    profile_path = resolve_repo_file(repo_root, profile["path"], "profile_binding.path")
    _register_distinct_file(
        registered_files,
        "genesis profile",
        profile_path,
        repo_root=repo_root,
    )
    _expect(_sha256(profile_path) == profile["sha256"], "profile binding file digest mismatch")

    grant = evidence["grant_map"]
    _expect(grant["status"] == "complete" and grant["review_status"] == "reviewed", "grant map must be complete and reviewed")
    _expect(grant["family_group_count"] == 14, "grant map family-group count must be 14")
    _expect(grant["authorization_class_count"] == 8, "grant map authorization-class count must be 8")
    _expect(grant["candidate_identity_sha256"] == candidate["candidate_identity_sha256"], "candidate/grant-map identity mismatch")
    _expect(
        grant["schema_path"] == DEFAULT_GRANT_MAP_SCHEMA.as_posix()
        and grant["schema_version"] == GRANT_MAP_SCHEMA_VERSION,
        "grant-map schema binding mismatch",
    )
    _expect(
        grant["path"] == EXPECTED_GRANT_MAP_PATHS[target_phase].as_posix(),
        "grant-map path must match the canonical phase-specific candidate-bound artifact path",
    )
    grant_path, grant_document = _load_bound_support(
        repo_root,
        grant["path"],
        grant["sha256"],
        "grant map",
        registered_files,
        allowed_reserved_paths=frozenset(
            {EXPECTED_GRANT_MAP_PATHS[target_phase].as_posix()}
        ),
    )
    _reject_forbidden_transit(
        grant_document,
        evidence_input_path=grant_path.relative_to(repo_root).as_posix(),
    )
    _validate_schema(
        grant_map_schema,
        grant_document,
        expected_id=GRANT_MAP_SCHEMA_ID,
        label="grant map artifact",
    )
    _expect(grant_document["target_phase"] == target_phase, "grant-map target_phase mismatch")
    grant_candidate = grant_document["candidate_binding"]
    for key in (
        "candidate_id",
        "candidate_identity_sha256",
        "candidate_identity_keccak256",
        "source_commit",
        "release_build",
        "genesis_profile_sha256",
    ):
        _expect(grant_candidate[key] == candidate[key], f"grant-map candidate {key} mismatch")
    class_rows = grant_document["authorization_classes"]
    _expect(
        [row["name"] for row in class_rows] == list(EXPECTED_AUTHORIZATION_CLASSES),
        "grant-map authorization classes mismatch",
    )
    class_ids = [row["authorization_class_id"] for row in class_rows]
    _expect(len(class_ids) == len(set(class_ids)), "grant-map authorization class IDs must be unique")
    family_rows = grant_document["family_groups"]
    _expect(
        [
            (row["name"], tuple(row["normative_patterns"]))
            for row in family_rows
        ]
        == list(EXPECTED_FAMILY_GROUPS),
        "grant-map family rows/patterns mismatch",
    )
    all_record_type_ids: list[str] = []
    for index, row in enumerate(family_rows):
        _expect(
            set(row["authorization_class_ids"]).issubset(class_ids),
            f"grant-map family_groups[{index}] references an unknown authorization class",
        )
        all_record_type_ids.extend(row["declared_record_type_ids"])
    _expect(
        len(all_record_type_ids) == len(set(all_record_type_ids)),
        "grant-map declared record-type IDs must be globally unique",
    )

    classifier = evidence["classifier_binding"]
    _expect(classifier["status"] == "complete", "classifier binding must be complete")
    _expect(ADDRESS_RE.fullmatch(classifier["host_address"]) is not None, "classifier host address is malformed")
    _expect(ADDRESS_RE.fullmatch(classifier["contract_address"]) is not None, "classifier contract address is malformed")
    _expect(KECCAK_RE.fullmatch(classifier["module_type"]) is not None, "classifier module type is malformed")
    _expect(INTERFACE_ID_RE.fullmatch(classifier["interface_id"]) is not None, "classifier interface id is malformed")
    _expect(INTERFACE_ID_RE.fullmatch(classifier["marker"]) is not None, "classifier marker is malformed")
    _expect(KECCAK_RE.fullmatch(classifier["schema"]) is not None, "classifier schema is malformed")
    _expect(isinstance(classifier["revision"], int) and not isinstance(classifier["revision"], bool) and classifier["revision"] > 0, "classifier revision is malformed")
    _expect(KECCAK_RE.fullmatch(classifier["runtime_codehash"]) is not None, "classifier runtime codehash is malformed")
    _expect(classifier["host_address"] != ZERO_ADDRESS, "classifier host address must be nonzero")
    _expect(classifier["contract_address"] != ZERO_ADDRESS, "classifier contract address must be nonzero")
    _expect(classifier["module_type"] != ZERO_KECCAK, "classifier module type must be nonzero")
    _expect(classifier["schema"] != ZERO_KECCAK, "classifier schema must be nonzero")
    _expect(classifier["runtime_codehash"] != ZERO_KECCAK, "classifier runtime codehash must be nonzero")
    _expect(classifier["interface_id"] not in {"0x00000000", "0xffffffff"}, "classifier interface id is invalid")
    _expect(classifier["marker"] not in {"0x00000000", "0xffffffff"}, "classifier marker is invalid")
    _expect(classifier["grant_map_sha256"] == grant["sha256"], "classifier/grant-map digest mismatch")
    expected_grant_classifier = {
        key: classifier[key]
        for key in (
            "host_address",
            "contract_address",
            "module_type",
            "interface_id",
            "marker",
            "schema",
            "revision",
            "runtime_codehash",
        )
    }
    _expect(
        grant_document["classifier_binding"] == expected_grant_classifier,
        "grant-map classifier binding mismatch",
    )

    implementations = evidence["implementation_bindings"]
    _expect(implementations["status"] == "complete" and implementations["review_status"] == "reviewed", "implementation bindings must be complete and reviewed")
    contracts = implementations["contracts"]
    _expect(isinstance(contracts, list) and len(contracts) >= 3, "at least three implementation bindings are required")
    names = [row["contract"] for row in contracts]
    _expect(len(names) == len(set(names)), "implementation contract bindings must be unique")
    addresses = [row["address"] for row in contracts]
    _expect(len(addresses) == len(set(addresses)), "implementation addresses must be unique")
    for index, row in enumerate(contracts):
        _expect(row["address"] != ZERO_ADDRESS, f"implementation_bindings.contracts[{index}] address must be nonzero")
        _expect(row["runtime_sha256"] != "0" * 64, f"implementation_bindings.contracts[{index}] runtime SHA-256 must be nonzero")
        _expect(row["runtime_keccak256"] != ZERO_KECCAK, f"implementation_bindings.contracts[{index}] runtime codehash must be nonzero")
        _expect(
            all(interface_id not in {"0x00000000", "0xffffffff"} for interface_id in row["interface_ids"]),
            f"implementation_bindings.contracts[{index}] interface IDs must be valid",
        )
        _expect(isinstance(row["marker"], str) and bool(row["marker"].strip()), f"implementation_bindings.contracts[{index}] marker is required")
        _expect(row["evidence_sha256"] != "0" * 64, f"implementation_bindings.contracts[{index}] evidence SHA-256 must be nonzero")
        _path, support = _load_bound_support(
            repo_root,
            row["evidence_path"],
            row["evidence_sha256"],
            f"implementation support {row['contract']}",
            registered_files,
        )
        _expect_support_header(
            support,
            artifact_type="implementation_binding",
            target_phase=target_phase,
            candidate_identity_sha256=candidate["candidate_identity_sha256"],
            grant_map_sha256=grant["sha256"],
            extra_keys=(
                "contract",
                "source_path",
                "source_sha256",
                "interface_path",
                "interface_sha256",
                "address",
                "runtime_sha256",
                "runtime_keccak256",
                "interface_ids",
                "marker",
                "revision",
            ),
            label=f"implementation support {row['contract']}",
        )
        for key in (
            "contract",
            "source_path",
            "source_sha256",
            "interface_path",
            "interface_sha256",
            "address",
            "runtime_sha256",
            "runtime_keccak256",
            "interface_ids",
            "marker",
            "revision",
        ):
            _expect(
                support[key] == row[key],
                f"implementation support {row['contract']} {key} mismatch",
            )
    for required_name in ("StreamCollectionMetadata", "StreamPreservationRecords"):
        _expect(required_name in names, f"implementation binding missing {required_name}")

    grant_implementations = grant_document["implementation_bindings"]
    _expect(
        len(grant_implementations) == len(contracts),
        "grant-map implementation binding count mismatch",
    )
    expected_source_paths = {
        "StreamCollectionMetadata": (
            "smart-contracts/StreamCollectionMetadata.sol",
            "smart-contracts/IStreamCollectionMetadata.sol",
        ),
        "StreamPreservationRecords": (
            "smart-contracts/StreamPreservationRecords.sol",
            "smart-contracts/IStreamPreservationRecords.sol",
        ),
    }
    for index, (grant_row, evidence_row) in enumerate(
        zip(grant_implementations, contracts, strict=True)
    ):
        for key in (
            "contract",
            "source_path",
            "source_sha256",
            "interface_path",
            "interface_sha256",
            "address",
            "runtime_sha256",
            "runtime_keccak256",
            "interface_ids",
            "marker",
            "revision",
        ):
            _expect(
                grant_row[key] == evidence_row[key],
                f"grant-map implementation_bindings[{index}].{key} mismatch",
            )
        if evidence_row["contract"] in expected_source_paths:
            _expect(
                (
                    grant_row["source_path"],
                    grant_row["interface_path"],
                )
                == expected_source_paths[evidence_row["contract"]],
                f"grant-map implementation_bindings[{index}] source/interface mismatch",
            )
        for field in ("source_path", "interface_path"):
            _expect(
                re.fullmatch(
                    r"smart-contracts/[A-Za-z0-9_.-]+\.sol",
                    grant_row[field],
                )
                is not None,
                f"grant-map implementation_bindings[{index}].{field} "
                "must remain an exact smart-contracts Solidity source path",
            )
        source_path = _assert_candidate_source_at_commit(
            repo_root,
            candidate["source_commit"],
            grant_row["source_path"],
            grant_row["source_sha256"],
            f"grant-map implementation_bindings[{index}].source",
        )
        interface_path = _assert_candidate_source_at_commit(
            repo_root,
            candidate["source_commit"],
            grant_row["interface_path"],
            grant_row["interface_sha256"],
            f"grant-map implementation_bindings[{index}].interface",
        )
        _register_distinct_file(
            registered_files,
            f"implementation source {grant_row['contract']}",
            source_path,
            repo_root=repo_root,
        )
        _register_distinct_file(
            registered_files,
            f"implementation interface {grant_row['contract']}",
            interface_path,
            repo_root=repo_root,
        )

    classifier_implementation_rows = [
        row
        for row in contracts
        if row["address"] == classifier["contract_address"]
        and row["runtime_keccak256"] == classifier["runtime_codehash"]
        and classifier["interface_id"] in row["interface_ids"]
        and row["marker"] == classifier["marker"]
        and row["revision"] == classifier["revision"]
    ]
    _expect(
        len(classifier_implementation_rows) == 1,
        "classifier binding must match exactly one implementation binding",
    )

    snapshot = evidence["snapshot_intersection"]
    _expect(snapshot["status"] == "complete" and snapshot["review_status"] == "reviewed", "snapshot intersection must be complete and reviewed")
    expected_groups = [name for name, _ in EXPECTED_FAMILY_GROUPS]
    _expect(snapshot["covered_family_groups"] == expected_groups, "snapshot intersection must cover all fourteen groups in order")
    _snapshot_path, snapshot_support = _load_bound_support(
        repo_root,
        snapshot["evidence_path"],
        snapshot["evidence_sha256"],
        "snapshot-intersection support",
        registered_files,
    )
    _expect_support_header(
        snapshot_support,
        artifact_type="snapshot_intersection",
        target_phase=target_phase,
        candidate_identity_sha256=candidate["candidate_identity_sha256"],
        grant_map_sha256=grant["sha256"],
        extra_keys=("covered_family_groups",),
        label="snapshot-intersection support",
    )
    _expect(
        snapshot_support["covered_family_groups"] == expected_groups,
        "snapshot-intersection support family coverage mismatch",
    )

    lifecycle = evidence["authority_lifecycle"]
    _expect(lifecycle["status"] == "complete" and lifecycle["review_status"] == "reviewed", "authority lifecycle must be complete and reviewed")
    _expect(lifecycle["observed_at_commit"] == candidate["source_commit"], "candidate/lifecycle source commit mismatch")
    _expect(lifecycle["rotation_revision"] > 0 and lifecycle["revocation_revision"] > 0, "rotation and revocation revisions must be positive")
    _lifecycle_path, lifecycle_support = _load_bound_support(
        repo_root,
        lifecycle["evidence_path"],
        lifecycle["evidence_sha256"],
        "authority-lifecycle support",
        registered_files,
    )
    _expect_support_header(
        lifecycle_support,
        artifact_type="authority_lifecycle",
        target_phase=target_phase,
        candidate_identity_sha256=candidate["candidate_identity_sha256"],
        grant_map_sha256=grant["sha256"],
        extra_keys=(
            "rotation_revision",
            "revocation_revision",
            "observed_at_commit",
        ),
        label="authority-lifecycle support",
    )
    for key in ("rotation_revision", "revocation_revision", "observed_at_commit"):
        _expect(
            lifecycle_support[key] == lifecycle[key],
            f"authority-lifecycle support {key} mismatch",
        )

    public_beta_evidence_path = next(
        row["path"]
        for row in inventory["retained_evidence"]
        if row["phase"] == "public_beta"
    )
    for row in phases:
        if row["status"] == "missing":
            continue
        if target_phase == "production_release" and row["phase"] == "public_beta":
            _expect(
                row["evidence_path"] == public_beta_evidence_path,
                "production predecessor must bind the canonical public-beta retained envelope path",
            )
            predecessor_path, predecessor = _load_bound_support(
                repo_root,
                row["evidence_path"],
                row["evidence_sha256"],
                "canonical public-beta retained predecessor",
                registered_files,
                allowed_reserved_paths=frozenset(
                    {EXPECTED_EVIDENCE_PATHS["public_beta"].as_posix()}
                ),
            )
            _validate_schema(
                evidence_schema,
                predecessor,
                expected_id=EVIDENCE_SCHEMA_ID,
                label="canonical public-beta retained predecessor",
            )
            _reject_forbidden_transit(
                predecessor,
                evidence_input_path=predecessor_path.relative_to(repo_root).as_posix(),
                allowed_reserved_paths=_allowed_reserved_transit_paths(
                    predecessor
                ),
            )
            _expect_keys(
                predecessor,
                EXPECTED_EVIDENCE_KEYS,
                "canonical public-beta retained predecessor",
            )
            _expect(
                predecessor["record_type"] == "retained_evidence"
                and predecessor["review_status"] == "reviewed"
                and predecessor["evidence_id"]
                == "record-family-authorization-public-beta-v1"
                and predecessor["target_phase"] == "public_beta",
                "production predecessor must be the reviewed public-beta retained envelope",
            )
            _validate_complete_evidence_semantics(
                predecessor,
                inventory,
                inventory_path,
                predecessor_path,
                repo_root,
                evidence_schema,
                grant_map_schema,
                enforce_inventory_candidate_dependency=False,
            )
            continue
        _phase_path, phase_support = _load_bound_support(
            repo_root,
            row["evidence_path"],
            row["evidence_sha256"],
            f"phase support {row['phase']}",
            registered_files,
        )
        _expect_support_header(
            phase_support,
            artifact_type="phase_support",
            target_phase=target_phase,
            candidate_identity_sha256=candidate["candidate_identity_sha256"],
            grant_map_sha256=grant["sha256"],
            extra_keys=("phase", "status"),
            label=f"phase support {row['phase']}",
        )
        _expect(
            phase_support["phase"] == row["phase"]
            and phase_support["status"] == "complete",
            f"phase support {row['phase']} content mismatch",
        )

    review = evidence["review"]
    for key in ("reviewer", "reviewed_at", "reference"):
        _expect(isinstance(review[key], str) and bool(review[key].strip()), f"review.{key} is required")
    _expect(
        review["reference"].startswith("https://"),
        "review.reference must be a retained HTTPS review record",
    )
    _expect(
        grant_document["independent_review"]
        == {
            "status": "reviewed",
            "reviewer": review["reviewer"],
            "reviewed_at": review["reviewed_at"],
            "reference": review["reference"],
        },
        "grant-map independent review does not match the retained envelope",
    )

    _expect(evidence["redaction_policy"]["no_secrets"] is True, "retained evidence must prohibit secrets")
    required_redactions = {"private_key", "mnemonic", "seed_phrase", "api_key", "rpc_url"}
    _expect(
        set(evidence["redaction_policy"]["redacted_fields"]) == required_redactions,
        "retained evidence redaction field set mismatch",
    )
    _expect(
        isinstance(evidence["template_notice"], str)
        and "does not by itself satisfy" in evidence["template_notice"],
        "retained evidence notice must preserve the independent release boundary",
    )

    if not enforce_inventory_candidate_dependency:
        return

    inventory_candidate = inventory["candidate_binding"]
    _expect(
        inventory_candidate["status"] == "complete",
        "candidate_identity_dependency_unavailable: inventory candidate binding "
        "remains blocked on the serialized #656 identity model",
    )
    for key in ("candidate_id", "candidate_identity_sha256", "candidate_identity_keccak256", "source_commit", "release_build", "genesis_profile_sha256"):
        _expect(inventory_candidate[key] == candidate[key], f"inventory/evidence candidate_binding.{key} mismatch")
    _expect(inventory_candidate["grant_map_sha256"] == grant["sha256"], "inventory/evidence grant-map digest mismatch")


def validate_package(
    repo_root: Path,
    inventory_path: Path = DEFAULT_INVENTORY,
    inventory_schema_path: Path = DEFAULT_INVENTORY_SCHEMA,
    evidence_template_path: Path = DEFAULT_EVIDENCE_TEMPLATE,
    evidence_schema_path: Path = DEFAULT_EVIDENCE_SCHEMA,
    grant_map_schema_path: Path = DEFAULT_GRANT_MAP_SCHEMA,
    source_catalog_path: Path = DEFAULT_SOURCE_CATALOG,
    source_catalog_schema_path: Path = DEFAULT_SOURCE_CATALOG_SCHEMA,
    *,
    require_complete: bool = False,
) -> tuple[dict[str, Any], dict[str, Any]]:
    root = repo_root.resolve(strict=True)
    inventory_file = resolve_repo_file(root, inventory_path.as_posix(), "inventory")
    inventory_schema_file = resolve_repo_file(root, inventory_schema_path.as_posix(), "inventory schema")
    evidence_file = resolve_repo_file(root, evidence_template_path.as_posix(), "evidence template")
    evidence_schema_file = resolve_repo_file(root, evidence_schema_path.as_posix(), "evidence schema")
    grant_map_schema_file = resolve_repo_file(
        root,
        grant_map_schema_path.as_posix(),
        "grant-map schema",
    )
    source_catalog_file = resolve_repo_file(
        root,
        source_catalog_path.as_posix(),
        "source catalog",
    )
    source_catalog_schema_file = resolve_repo_file(
        root,
        source_catalog_schema_path.as_posix(),
        "source catalog schema",
    )

    inventory = load_json(inventory_file, "record-family authorization inventory")
    inventory_schema = load_json(inventory_schema_file, "record-family inventory schema")
    evidence = load_json(evidence_file, "record-family evidence template")
    evidence_schema = load_json(evidence_schema_file, "record-family evidence schema")
    grant_map_schema = load_json(grant_map_schema_file, "record-family grant-map schema")
    source_catalog = load_json(
        source_catalog_file,
        "record-family authorization source catalog",
    )
    source_catalog_schema = load_json(
        source_catalog_schema_file,
        "record-family authorization source catalog schema",
    )
    evidence_relative = evidence_file.relative_to(root).as_posix()
    _reject_forbidden_transit(
        evidence,
        evidence_input_path=evidence_relative,
        allowed_reserved_paths=_allowed_reserved_transit_paths(evidence),
    )
    _validate_schema(inventory_schema, inventory, expected_id=INVENTORY_SCHEMA_ID, label="inventory")
    _validate_schema(
        source_catalog_schema,
        source_catalog,
        expected_id=SOURCE_CATALOG_SCHEMA_ID,
        label="source catalog",
    )
    _validate_schema(evidence_schema, evidence, expected_id=EVIDENCE_SCHEMA_ID, label="evidence")
    _validate_schema_definition(
        grant_map_schema,
        expected_id=GRANT_MAP_SCHEMA_ID,
        label="grant map",
    )
    _validate_source_catalog_semantics(source_catalog, root)
    _validate_inventory_semantics(inventory, root)
    if evidence["record_type"] == "template":
        _validate_template_semantics(evidence, inventory, inventory_file)
    else:
        _validate_complete_evidence_semantics(
            evidence,
            inventory,
            inventory_file,
            evidence_file,
            root,
            evidence_schema,
            grant_map_schema,
        )

    if require_complete:
        # Source implementation alone cannot satisfy a candidate-bound release
        # evidence gate.
        _fail(COMPLETION_BLOCKER)
    return inventory, evidence


def completion_blockers(
    repo_root: Path,
    inventory_path: Path = DEFAULT_INVENTORY,
    inventory_schema_path: Path = DEFAULT_INVENTORY_SCHEMA,
    evidence_template_path: Path = DEFAULT_EVIDENCE_TEMPLATE,
    evidence_schema_path: Path = DEFAULT_EVIDENCE_SCHEMA,
    grant_map_schema_path: Path = DEFAULT_GRANT_MAP_SCHEMA,
    source_catalog_path: Path = DEFAULT_SOURCE_CATALOG,
    source_catalog_schema_path: Path = DEFAULT_SOURCE_CATALOG_SCHEMA,
) -> list[str]:
    validate_package(
        repo_root,
        inventory_path,
        inventory_schema_path,
        evidence_template_path,
        evidence_schema_path,
        grant_map_schema_path,
        source_catalog_path,
        source_catalog_schema_path,
    )
    return [COMPLETION_BLOCKER]


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--inventory", type=Path, default=DEFAULT_INVENTORY)
    parser.add_argument("--inventory-schema", type=Path, default=DEFAULT_INVENTORY_SCHEMA)
    parser.add_argument("--evidence-template", type=Path, default=DEFAULT_EVIDENCE_TEMPLATE)
    parser.add_argument("--evidence-schema", type=Path, default=DEFAULT_EVIDENCE_SCHEMA)
    parser.add_argument("--grant-map-schema", type=Path, default=DEFAULT_GRANT_MAP_SCHEMA)
    parser.add_argument("--source-catalog", type=Path, default=DEFAULT_SOURCE_CATALOG)
    parser.add_argument(
        "--source-catalog-schema",
        type=Path,
        default=DEFAULT_SOURCE_CATALOG_SCHEMA,
    )
    parser.add_argument("--require-complete", action="store_true")
    args = parser.parse_args(argv)
    try:
        inventory, _ = validate_package(
            args.repo_root,
            args.inventory,
            args.inventory_schema,
            args.evidence_template,
            args.evidence_schema,
            args.grant_map_schema,
            args.source_catalog,
            args.source_catalog_schema,
            require_complete=args.require_complete,
        )
    except RecordFamilyAuthorizationError as exc:
        print(f"record-family authorization check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "record-family authorization check passed: "
        f"{len(inventory['authorization_classes'])} classes, "
        f"{len(inventory['family_groups'])} family groups, "
        f"{len(inventory['current_implementation']['mutation_surfaces'])} "
        "historical fail-open mutation surfaces; source implemented, "
        "candidate unbound"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
