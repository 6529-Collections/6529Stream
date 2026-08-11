#!/usr/bin/env python3
"""Fail closed on the proposed artist record/event reconstruction correction."""

from __future__ import annotations

import hashlib
import json
import re
import subprocess
from copy import deepcopy
from pathlib import Path
from typing import Any

from Crypto.Hash import keccak
from jsonschema import Draft202012Validator


PACKET_PATH = Path("docs/architecture/artist-record-event-reconstruction-correction-v1.json")
SCHEMA_PATH = Path("docs/architecture/artist-record-event-reconstruction-correction-v1.schema.json")
RATIONALE_PATH = Path("docs/architecture/artist-record-event-reconstruction-correction-v1.md")
NORMATIVE_PATH = Path("docs/stream-artist-authority.md")
MATRIX_PATH = Path("docs/architecture/artist-semantic-owner-matrix-v2.json")
OPERATION_MATRIX_PATH = Path(
    "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json"
)
FOUNDATION_PATH = Path("docs/architecture/artist-owner-state-mechanics-foundation-v1.json")
SHARED_PATH = Path("docs/architecture/artist-operation-shared-mechanics-freeze-v1.json")

EXPECTED_BASE = "1cd16e1c8bde97a5f5cc7cd3c8f39169e09c38ea"
EXPECTED_TREE = "94c67b852c2ee582043cbcef42254e515d33698e"

EXPECTED_BINDING_PATHS = [
    ("adr_0023", "docs/adr/0023-modular-artist-authority-domain-ownership.md"),
    ("normative_artist_authority", "docs/stream-artist-authority.md"),
    ("semantic_owner_matrix", "docs/architecture/artist-semantic-owner-matrix-v2.json"),
    ("semantic_owner_matrix_schema", "docs/architecture/artist-semantic-owner-matrix-v2.schema.json"),
    ("semantic_owner_matrix_checker", "scripts/check_artist_semantic_owner_matrix.py"),
    ("semantic_owner_matrix_tests", "scripts/test_artist_semantic_owner_matrix.py"),
    ("operation_matrix", "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json"),
    ("owner_state_foundation", "docs/architecture/artist-owner-state-mechanics-foundation-v1.json"),
    ("owner_state_foundation_schema", "docs/architecture/artist-owner-state-mechanics-foundation-v1.schema.json"),
    ("owner_state_foundation_checker", "scripts/check_artist_owner_state_mechanics_foundation.py"),
    ("owner_state_foundation_tests", "scripts/test_artist_owner_state_mechanics_foundation.py"),
    ("shared_mechanics_packet", "docs/architecture/artist-operation-shared-mechanics-freeze-v1.json"),
    ("shared_mechanics_schema", "docs/architecture/artist-operation-shared-mechanics-freeze-v1.schema.json"),
    ("shared_mechanics_checker", "scripts/check_artist_operation_shared_mechanics_freeze.py"),
    ("shared_mechanics_tests", "scripts/test_artist_operation_shared_mechanics_freeze.py"),
]

EXPECTED_SUFFIXES: dict[str, list[dict[str, Any]]] = {
    "ArtistAttributionStateChanged": [
        {"type": "bytes32", "name": "recordArtistId", "indexed": False},
        {"type": "bytes32", "name": "recordBindingHash", "indexed": False},
        {"type": "address", "name": "recordSigner", "indexed": False},
        {"type": "uint256", "name": "recordNonce", "indexed": False},
        {"type": "uint64", "name": "recordSignedAt", "indexed": False},
    ],
    "ArtistDelegationRevoked": [
        {"type": "address", "name": "signer", "indexed": False},
        {"type": "uint8", "name": "authorityClass", "indexed": False},
        {"type": "uint256", "name": "nonce", "indexed": False},
        {"type": "uint64", "name": "signedAt", "indexed": False},
    ],
    "ArtistHistoryLaneVerified": [
        {"type": "address", "name": "predecessorRegistry", "indexed": False},
        {"type": "uint64", "name": "sequence", "indexed": False},
        {"type": "bytes32", "name": "recordHash", "indexed": False},
        {"type": "bytes32", "name": "recordChainHash", "indexed": False},
    ],
    "ArtistIdentityRecovered": [
        {"type": "bytes32[]", "name": "supersededRecordHashes", "indexed": False}
    ],
    "CollaboratorAccepted": [
        {"type": "bytes32", "name": "bindingHash", "indexed": False}
    ],
    "ArtistSanctionRecorded": [
        {"type": "bytes32", "name": "artistId", "indexed": False}
    ],
    "ArtistPolicyConsentRecorded": [
        {"type": "address", "name": "mintManager", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistEconomicsConsentRecorded": [
        {"type": "address", "name": "resolver", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistSaleConsentRecorded": [
        {"type": "address", "name": "saleAdapter", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistContentConsentRecorded": [
        {"type": "address", "name": "metadataContract", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistRoyaltyFreezeAuthorized": [
        {"type": "address", "name": "resolver", "indexed": False},
        {"type": "bytes32", "name": "revenueClass", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistContentFreezeAuthorized": [
        {"type": "address", "name": "metadataContract", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
    "ArtistRecoveryApprovalRecorded": [
        {"type": "bytes32", "name": "artistId", "indexed": False}
    ],
    "ArtistAttestationRecorded": [
        {"type": "bytes32", "name": "artistId", "indexed": False}
    ],
    "ArtistContentRatificationRecorded": [
        {"type": "address", "name": "metadataContract", "indexed": False},
        {"type": "bytes32", "name": "artistId", "indexed": False},
    ],
}

EXPECTED_CORRECTIONS = [
    ("binding_refusal_reconstruction", [3], "ArtistAttributionStateChanged", ["BINDING_REFUSAL_RECORD_DOMAIN"]),
    ("delegation_revocation_reconstruction", [27], "ArtistDelegationRevoked", ["DELEGATION_REVOCATION_RECORD_DOMAIN"]),
    ("history_import_leaf_reconstruction", [56], "ArtistHistoryLaneVerified", ["ARTIST_HISTORY_IMPORT_LEAF_DOMAIN"]),
    ("identity_recovery_supersession_reconstruction", [35], "ArtistIdentityRecovered", ["IDENTITY_RECOVERY_SUPERSESSION_DOMAIN"]),
    ("collaborator_acceptance_reconstruction", [7], "CollaboratorAccepted", ["ACCEPTANCE_RECORD_DOMAIN"]),
    ("sanction_reconstruction", [12], "ArtistSanctionRecorded", ["SANCTION_RECORD_DOMAIN"]),
    ("policy_consent_reconstruction", [14], "ArtistPolicyConsentRecorded", ["POLICY_CONSENT_RECORD_DOMAIN"]),
    ("economics_consent_reconstruction", [15], "ArtistEconomicsConsentRecorded", ["ECONOMICS_CONSENT_RECORD_DOMAIN"]),
    ("sale_consent_reconstruction", [16], "ArtistSaleConsentRecorded", ["SALE_CONSENT_RECORD_DOMAIN"]),
    ("content_consent_reconstruction", [17], "ArtistContentConsentRecorded", ["CONTENT_CONSENT_RECORD_DOMAIN"]),
    ("royalty_freeze_reconstruction", [20], "ArtistRoyaltyFreezeAuthorized", ["ROYALTY_FREEZE_RECORD_DOMAIN"]),
    ("content_freeze_reconstruction", [21], "ArtistContentFreezeAuthorized", ["CONTENT_FREEZE_RECORD_DOMAIN"]),
    ("recovery_approval_reconstruction", [22], "ArtistRecoveryApprovalRecorded", ["RECOVERY_APPROVAL_RECORD_DOMAIN"]),
    ("attestation_reconstruction", [24], "ArtistAttestationRecorded", ["ATTESTATION_RECORD_DOMAIN"]),
    ("content_ratification_reconstruction", [52], "ArtistContentRatificationRecorded", ["CONTENT_RATIFICATION_RECORD_DOMAIN"]),
]

EXPECTED_CONSTANTS = [
    {"constant_id": "record_domain", "type": "bytes32", "value_rule": "exact record_domain_rows.domain_value for the mapped record domain", "authority": "record-domain authority binding"},
    {"constant_id": "deployment_chain_id", "type": "uint256", "value_rule": "constructor-captured immutable deploymentChainId; live block.chainid is forbidden", "authority": "merged owner-state mechanics foundation"},
    {"constant_id": "registry_address", "type": "address", "value_rule": "immutable StreamArtistRegistryV2 address", "authority": "ADR 0023 and merged owner-state mechanics foundation"},
    {"constant_id": "provider_core", "type": "address", "value_rule": "exact immutable RegistryV2 provider:core expectedAddress", "authority": "IStreamArtistRegistryV2 typed provider pin"},
    {"constant_id": "provider_finality_registry", "type": "address", "value_rule": "exact immutable RegistryV2 provider:finality_registry expectedAddress", "authority": "IStreamArtistRegistryV2 typed provider pin"},
    {"constant_id": "acceptance_kind_artist", "type": "uint8", "value_rule": "uint8(1)", "authority": "AA-DOMAINS acceptanceKind discriminator"},
    {"constant_id": "acceptance_kind_collaborator", "type": "uint8", "value_rule": "uint8(2)", "authority": "AA-DOMAINS acceptanceKind discriminator"},
    {"constant_id": "dispute_action_open", "type": "uint8", "value_rule": "uint8(1)", "authority": "operation 44 exact source-field discriminator"},
    {"constant_id": "dispute_action_counter_statement", "type": "uint8", "value_rule": "uint8(3)", "authority": "operation 45 exact source-field discriminator"},
]

SPECIAL_COMPONENT_TYPES = {
    "domain": "bytes32", "chainId": "uint256", "registry": "address", "core": "address",
    "collectionId": "uint256", "bindingGeneration": "uint64", "bindingHash": "bytes32",
    "artistId": "bytes32", "signer": "address", "authorityClass": "uint8",
    "reasonHash": "bytes32", "nonce": "uint256", "signedAt": "uint64",
    "delegate": "address", "delegationRecordHash": "bytes32",
}

CONSTANT_COMPONENT_SOURCES = {
    "domain": "constant:record_domain", "chainId": "constant:deployment_chain_id",
    "registry": "constant:registry_address", "core": "constant:provider_core",
    "finalityRegistry": "constant:provider_finality_registry",
}

LITERAL_COMPONENT_SOURCES = {
    (2, "ACCEPTANCE_RECORD_DOMAIN", "acceptanceKind"): "constant:acceptance_kind_artist",
    (7, "ACCEPTANCE_RECORD_DOMAIN", "acceptanceKind"): "constant:acceptance_kind_collaborator",
    (44, "DISPUTE_RECORD_DOMAIN", "disputeAction"): "constant:dispute_action_open",
    (45, "DISPUTE_RECORD_DOMAIN", "disputeAction"): "constant:dispute_action_counter_statement",
}

ALIASED_EVENT_SOURCES = {
    (1, "ARTIST_BINDING_DOMAIN", "identityRecordHash"): "event:ArtistIdentityRegistered.identityRecordHash",
    (1, "ARTIST_ID_DOMAIN", "firstAddress"): "event:ArtistIdentityRegistered.authorityAddress",
    (6, "ARTIST_ID_DOMAIN", "firstAddress"): "event:ArtistIdentityRegistered.authorityAddress",
    (3, "BINDING_REFUSAL_RECORD_DOMAIN", "bindingHash"): "event:ArtistAttributionStateChanged.recordBindingHash",
    (3, "BINDING_REFUSAL_RECORD_DOMAIN", "artistId"): "event:ArtistAttributionStateChanged.recordArtistId",
    (3, "BINDING_REFUSAL_RECORD_DOMAIN", "signer"): "event:ArtistAttributionStateChanged.recordSigner",
    (3, "BINDING_REFUSAL_RECORD_DOMAIN", "nonce"): "event:ArtistAttributionStateChanged.recordNonce",
    (3, "BINDING_REFUSAL_RECORD_DOMAIN", "signedAt"): "event:ArtistAttributionStateChanged.recordSignedAt",
    (7, "ACCEPTANCE_RECORD_DOMAIN", "signer"): "event:CollaboratorAccepted.collaborator",
    (45, "DISPUTE_RECORD_DOMAIN", "opener"): "event:AttributionCounterStatementRecorded.signer",
    (45, "DISPUTE_RECORD_DOMAIN", "openerAuthorityClass"): "event:AttributionCounterStatementRecorded.authorityClass",
    (45, "DISPUTE_RECORD_DOMAIN", "openedAt"): "event:AttributionCounterStatementRecorded.recordedAt",
}

EXPECTED_RECORD_VECTOR_FIXTURES = [
    {
        "vector_id": "binding_refusal_static_v1",
        "correction_id": "binding_refusal_reconstruction",
        "operation_id": 3,
        "record_domain": "BINDING_REFUSAL_RECORD_DOMAIN",
        "hash_mode": "keccak256_abi_encode_static",
        "values": [
            "0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed",
            1,
            "0x0000000000000000000000000000000000001111",
            "0x0000000000000000000000000000000000002222",
            42,
            7,
            "0x0000000000000000000000000000000000000000000000000000000000003333",
            "0x0000000000000000000000000000000000000000000000000000000000004444",
            "0x0000000000000000000000000000000000005555",
            2,
            "0x0000000000000000000000000000000000000000000000000000000000006666",
            9,
            1_700_000_000,
        ],
        "expected_abi_words": [
            "0x61e2c527c98d65328522fa0ac36862f52a59a2035e3e2ca4a0bfd5da13ee95ed",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000001111",
            "0x0000000000000000000000000000000000000000000000000000000000002222",
            "0x000000000000000000000000000000000000000000000000000000000000002a",
            "0x0000000000000000000000000000000000000000000000000000000000000007",
            "0x0000000000000000000000000000000000000000000000000000000000003333",
            "0x0000000000000000000000000000000000000000000000000000000000004444",
            "0x0000000000000000000000000000000000000000000000000000000000005555",
            "0x0000000000000000000000000000000000000000000000000000000000000002",
            "0x0000000000000000000000000000000000000000000000000000000000006666",
            "0x0000000000000000000000000000000000000000000000000000000000000009",
            "0x000000000000000000000000000000000000000000000000000000006553f100",
        ],
        "expected_hash": "0x97699daf0e850b746a8cfd15e5fb6fe04bc249f519db89108666b5c073b44636",
    },
    {
        "vector_id": "delegation_revocation_static_v1",
        "correction_id": "delegation_revocation_reconstruction",
        "operation_id": 27,
        "record_domain": "DELEGATION_REVOCATION_RECORD_DOMAIN",
        "hash_mode": "keccak256_abi_encode_static",
        "values": [
            "0xa85c3026098222def761aae03562d9fff97010f075911f40d4a27886f49bcef3",
            1,
            "0x0000000000000000000000000000000000001111",
            "0x0000000000000000000000000000000000000000000000000000000000004444",
            "0x0000000000000000000000000000000000007777",
            "0x0000000000000000000000000000000000000000000000000000000000008888",
            "0x0000000000000000000000000000000000005555",
            2,
            "0x0000000000000000000000000000000000000000000000000000000000006666",
            9,
            1_700_000_000,
        ],
        "expected_abi_words": [
            "0xa85c3026098222def761aae03562d9fff97010f075911f40d4a27886f49bcef3",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000001111",
            "0x0000000000000000000000000000000000000000000000000000000000004444",
            "0x0000000000000000000000000000000000000000000000000000000000007777",
            "0x0000000000000000000000000000000000000000000000000000000000008888",
            "0x0000000000000000000000000000000000000000000000000000000000005555",
            "0x0000000000000000000000000000000000000000000000000000000000000002",
            "0x0000000000000000000000000000000000000000000000000000000000006666",
            "0x0000000000000000000000000000000000000000000000000000000000000009",
            "0x000000000000000000000000000000000000000000000000000000006553f100",
        ],
        "expected_hash": "0x171c04bd82cae5f8f83f0e6d79dbc3903645f44a398990e742bd0a1ea3b437fc",
    },
    {
        "vector_id": "history_import_leaf_static_v1",
        "correction_id": "history_import_leaf_reconstruction",
        "operation_id": 56,
        "record_domain": "ARTIST_HISTORY_IMPORT_LEAF_DOMAIN",
        "hash_mode": "keccak256_bytes_concat_keccak256_abi_encode_static",
        "values": [
            "0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d",
            1,
            "0x0000000000000000000000000000000000009999",
            1,
            "0x000000000000000000000000000000000000000000000000000000000000aaaa",
            3,
            "0x000000000000000000000000000000000000000000000000000000000000bbbb",
            "0x000000000000000000000000000000000000000000000000000000000000cccc",
        ],
        "expected_abi_words": [
            "0xea04da6644046a7c731e99312c32df311e81aa7e137dfc2a49c2116bb325195d",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000009999",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x000000000000000000000000000000000000000000000000000000000000aaaa",
            "0x0000000000000000000000000000000000000000000000000000000000000003",
            "0x000000000000000000000000000000000000000000000000000000000000bbbb",
            "0x000000000000000000000000000000000000000000000000000000000000cccc",
        ],
        "expected_inner_hash": "0x2fbde60c0139455a338239173cbecc2e10e83669807e138fea4183ff5e365ac5",
        "expected_hash": "0x560528131018278adbb2eacefa0c2786b3b97d7736766d05843c9c75bba4ae03",
    },
    {
        "vector_id": "identity_recovery_supersession_dynamic_v1",
        "correction_id": "identity_recovery_supersession_reconstruction",
        "operation_id": 35,
        "record_domain": "IDENTITY_RECOVERY_SUPERSESSION_DOMAIN",
        "hash_mode": "keccak256_abi_encode_bytes32_array",
        "values": [
            "0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae",
            [
                "0x0000000000000000000000000000000000000000000000000000000000000001",
                "0x0000000000000000000000000000000000000000000000000000000000000002",
                "0x0000000000000000000000000000000000000000000000000000000000000003",
            ],
        ],
        "expected_abi_words": [
            "0x0c8573762967a1af597f2a7afc4b655a87b3e22d2b11fbab6cf13c6f7b1396ae",
            "0x0000000000000000000000000000000000000000000000000000000000000040",
            "0x0000000000000000000000000000000000000000000000000000000000000003",
            "0x0000000000000000000000000000000000000000000000000000000000000001",
            "0x0000000000000000000000000000000000000000000000000000000000000002",
            "0x0000000000000000000000000000000000000000000000000000000000000003",
        ],
        "expected_hash": "0x3de8b19205fc04d0d8c9a9a9115124bd4b5de9d34175d5f8bdc1a4e3e2307a66",
    },
]

EXPECTED_UNRESOLVED = [
    "entrypoint_abi",
    "owner_mutations",
    "owner_storage",
    "owner_snapshots",
    "replay_keys",
    "normative_owner_events_acceptance",
    "provider_reads",
    "role_authority",
    "signer_validation",
    "recipe_commitment",
    "archive_evidence",
    "composite_manifest",
    "construction",
    "errors",
    "operation_lock",
    "gas_and_call_discipline",
    "four_owner_inner_commitment_preimages",
]


class CorrectionError(RuntimeError):
    """Raised when the proposed correction packet drifts."""


def _reject_float(value: str) -> None:
    raise CorrectionError(f"floating-point JSON is forbidden: {value}")


def _object_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key, value in pairs:
        if key in out:
            raise CorrectionError(f"duplicate JSON key: {key}")
        out[key] = value
    return out


def load_json(path: Path) -> Any:
    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=_object_pairs,
            parse_float=_reject_float,
        )
    except OSError as exc:
        raise CorrectionError(f"cannot read {path.as_posix()}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise CorrectionError(f"invalid JSON in {path.as_posix()}: {exc}") from exc


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _keccak(data: bytes) -> bytes:
    digest = keccak.new(digest_bits=256)
    digest.update(data)
    return digest.digest()


def _hex_keccak(data: bytes) -> str:
    return "0x" + _keccak(data).hex()


def _signature(name: str, fields: list[dict[str, Any]]) -> str:
    return f"{name}({','.join(field['type'] for field in fields)})"


def _normative_events(text: str) -> dict[str, list[dict[str, Any]]]:
    try:
        section = text[
            text.index("## Events [AA-EVENTS]") : text.index(
                "## Domain Constants And Typehashes"
            )
        ]
    except ValueError as exc:
        raise CorrectionError("normative event section anchors drifted") from exc
    section = re.sub(r"//[^\n]*", "", section)
    events: dict[str, list[dict[str, Any]]] = {}
    for match in re.finditer(r"event\s+(\w+)\s*\((.*?)\)\s*;", section, re.S):
        name = match.group(1)
        fields: list[dict[str, Any]] = []
        for raw in match.group(2).split(","):
            parts = raw.strip().split()
            if len(parts) < 2:
                raise CorrectionError(f"malformed event field in {name}: {raw!r}")
            fields.append(
                {
                    "type": parts[0],
                    "name": parts[-1],
                    "indexed": "indexed" in parts[1:-1],
                }
            )
        if name in events:
            raise CorrectionError(f"duplicate normative event declaration: {name}")
        events[name] = fields
    return events


def _record_rows(
    normative_text: str, matrix: dict[str, Any], operation_matrix: dict[str, Any]
) -> list[dict[str, Any]]:
    wanted = {row["record_domain"] for row in matrix["record_surfaces"]}
    source: dict[str, dict[str, str]] = {}
    for line in normative_text.splitlines():
        if not line.startswith("| `"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) < 6:
            continue
        domain = cells[0].strip("`")
        if domain not in wanted:
            continue
        inputs = cells[5]
        if "`" in inputs:
            inputs = inputs[inputs.find("`") + 1 : inputs.rfind("`")]
        source[domain] = {
            "domain_preimage": cells[1].strip("`"),
            "domain_value": cells[2].strip("`"),
            "legacy_preimage": inputs,
            "authority_source": "docs/stream-artist-authority.md#aa-domains",
        }
    for domain in (
        "BINDING_REFUSAL_RECORD_DOMAIN",
        "DELEGATION_REVOCATION_RECORD_DOMAIN",
    ):
        item = operation_matrix["domains"][domain]
        source[domain] = {
            "domain_preimage": item["preimage"],
            "domain_value": item["value"],
            "legacy_preimage": item["fields"],
            "authority_source": "release-artifacts/issue-670-adapter-freeze/artist-operation-matrix-v1.json#domains",
        }
    if set(source) != wanted:
        raise CorrectionError(
            f"record-domain authority join drifted: missing={sorted(wanted - set(source))}, "
            f"extra={sorted(set(source) - wanted)}"
        )
    rows: list[dict[str, Any]] = []
    for item in matrix["record_surfaces"]:
        authority = source[item["record_domain"]]
        if authority["domain_value"] != _hex_keccak(
            authority["domain_preimage"].encode("ascii")
        ):
            raise CorrectionError(f"record domain hash drifted: {item['record_domain']}")
        rows.append(
            {
                "surface_id": item["surface_id"],
                "record_domain": item["record_domain"],
                "owner_domain": item["owner_domain"],
                "owner_contract": item["owner_contract"],
                **authority,
                "encoding": "abi.encode",
                "decision_status": "retained_v1_semantic_hash_schema",
            }
        )
    return rows


def _event_rows(
    normative_text: str, matrix: dict[str, Any]
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    declarations = _normative_events(normative_text)
    matrix_names = [row["event"] for row in matrix["event_surfaces"]]
    if set(declarations) - set(matrix_names) != {"ArtistRegistryParameterChanged"}:
        raise CorrectionError("normative administrative-event exclusion drifted")
    if set(matrix_names) - set(declarations):
        raise CorrectionError("semantic event inventory lacks a normative declaration")
    correction_ids = {
        event: correction_id
        for correction_id, _operations, event, _domains in EXPECTED_CORRECTIONS
    }
    rows: list[dict[str, Any]] = []
    vectors: list[dict[str, Any]] = []
    topics: set[str] = set()
    for item in matrix["event_surfaces"]:
        name = item["event"]
        legacy = declarations[name]
        fields = legacy + EXPECTED_SUFFIXES.get(name, [])
        legacy_signature = _signature(name, legacy)
        v2_signature = _signature(name, fields)
        topic = _hex_keccak(v2_signature.encode("ascii"))
        if topic in topics:
            raise CorrectionError(f"event topic collision: {name}")
        topics.add(topic)
        indexed_positions = [index for index, field in enumerate(fields) if field["indexed"]]
        if len(indexed_positions) > 3:
            raise CorrectionError(f"too many indexed fields: {name}")
        if not fields or fields[0] != {
            "type": "uint16",
            "name": "schemaVersion",
            "indexed": False,
        }:
            raise CorrectionError(f"schemaVersion prefix drifted: {name}")
        rows.append(
            {
                "surface_id": item["surface_id"],
                "event": name,
                "emitter_domain": item["emitter_domain"],
                "emitter_contract": item["emitter_contract"],
                "schema_version_field": fields[0],
                "legacy_signature": legacy_signature,
                "v2_signature": v2_signature,
                "v2_topic0": topic,
                "fields": fields,
                "correction_id": correction_ids.get(name),
                "unchanged_from_normative_v1": name not in EXPECTED_SUFFIXES,
            }
        )
        vectors.append(
            {
                "surface_id": item["surface_id"],
                "signature": v2_signature,
                "topic0": topic,
                "indexed_positions": indexed_positions,
            }
        )
    return rows, vectors


def _operation_rows(matrix: dict[str, Any]) -> list[dict[str, Any]]:
    rows = []
    for operation in matrix["operations"]:
        rows.append(
            {
                "operation_id": operation["operation_id"],
                "write": operation["source_row"]["write"],
                "record_bindings": operation["record_bindings"],
                "event_bindings": operation["event_bindings"],
                "source_fields": operation["source_row"]["fields"],
                "source_present": False,
                "implementation_authorized": False,
            }
        )
    return rows


def _record_components(row: dict[str, Any]) -> list[tuple[str, str]]:
    """Parse the authoritative ABI preimage into exact ordered typed names."""
    preimage = row["legacy_preimage"]
    if ";" not in preimage:
        names = preimage.split(",")
        try:
            return [(SPECIAL_COMPONENT_TYPES[name], name) for name in names]
        except KeyError as exc:
            raise CorrectionError(f"unknown untyped record component: {exc.args[0]}") from exc
    components: list[tuple[str, str]] = []
    for index, raw in enumerate(preimage.split(";")):
        part = raw.strip()
        if "(" not in part:
            if index == 0:
                components.append(("bytes32", "domain"))
            else:
                tokens = part.split()
                if len(tokens) < 2:
                    raise CorrectionError(f"malformed typed record component: {part}")
                components.append((tokens[0], tokens[1]))
            continue
        component_type = part[: part.find("(")]
        inner = part[part.find("(") + 1 : part.rfind(")")].strip()
        name = inner.split(":", 1)[0].split()[0]
        components.append((component_type, "chainId" if name == "block.chainid" else name))
    return components


def _reconstruction_rows(
    record_rows: list[dict[str, Any]],
    event_rows: list[dict[str, Any]],
    operation_rows: list[dict[str, Any]],
) -> list[dict[str, Any]]:
    records = {row["record_domain"]: row for row in record_rows}
    events = {row["event"]: row for row in event_rows}
    constant_types = {row["constant_id"]: row["type"] for row in EXPECTED_CONSTANTS}
    rows: list[dict[str, Any]] = []
    for operation in operation_rows:
        operation_events = [events[binding["event"]] for binding in operation["event_bindings"]]
        emitted_names = [row["event"] for row in operation_events]
        for record_binding in operation["record_bindings"]:
            if record_binding["mode"] != "create":
                continue
            record_domain = record_binding["source"]
            component_bindings: list[dict[str, Any]] = []
            for position, (component_type, name) in enumerate(
                _record_components(records[record_domain])
            ):
                source = (
                    LITERAL_COMPONENT_SOURCES.get((operation["operation_id"], record_domain, name))
                    or ALIASED_EVENT_SOURCES.get((operation["operation_id"], record_domain, name))
                    or CONSTANT_COMPONENT_SOURCES.get(name)
                )
                if source is None:
                    hits = [
                        (event, field)
                        for event in operation_events
                        for field in event["fields"]
                        if field["name"] == name and field["type"] == component_type
                    ]
                    owner_hits = [
                        hit
                        for hit in hits
                        if hit[0]["emitter_domain"] == record_binding["owner_domain"]
                    ]
                    selected = owner_hits or hits
                    if not selected:
                        raise CorrectionError(
                            f"unmapped record component: operation {operation['operation_id']} "
                            f"{record_domain}.{name}"
                        )
                    source = f"event:{selected[0][0]['event']}.{selected[0][1]['name']}"
                if source.startswith("constant:"):
                    constant_id = source.split(":", 1)[1]
                    if constant_types.get(constant_id) != component_type:
                        raise CorrectionError(
                            f"constant type mismatch: {record_domain}.{name} -> {source}"
                        )
                    source_kind = "immutable_constant"
                else:
                    event_name, field_name = source.split(":", 1)[1].rsplit(".", 1)
                    if event_name not in emitted_names:
                        raise CorrectionError(
                            f"record component maps to an unemitted event: {source}"
                        )
                    field = next(
                        (item for item in events[event_name]["fields"] if item["name"] == field_name),
                        None,
                    )
                    if field is None or field["type"] != component_type:
                        raise CorrectionError(
                            f"record component/event type mismatch: {record_domain}.{name} -> {source}"
                        )
                    source_kind = "event_field"
                component_bindings.append(
                    {
                        "position": position,
                        "type": component_type,
                        "component": name,
                        "source_kind": source_kind,
                        "source": source,
                    }
                )
            rows.append(
                {
                    "operation_id": operation["operation_id"],
                    "write": operation["write"],
                    "role": record_binding["role"],
                    "record_domain": record_domain,
                    "component_bindings": component_bindings,
                    "implicit_storage_join": False,
                    "reconstruction_complete": True,
                }
            )
    if len(rows) != 40 or {row["record_domain"] for row in rows} != set(records):
        raise CorrectionError("created-record reconstruction coverage drifted")
    return rows


def _validate_schema(packet: dict[str, Any], schema: dict[str, Any]) -> None:
    try:
        Draft202012Validator.check_schema(schema)
    except Exception as exc:  # jsonschema provides detailed exception subclasses
        raise CorrectionError(f"Draft202012 schema is invalid: {exc}") from exc
    errors = sorted(Draft202012Validator(schema).iter_errors(packet), key=lambda e: list(e.path))
    if errors:
        error = errors[0]
        path = "/".join(str(part) for part in error.path) or "<root>"
        raise CorrectionError(f"schema validation failed at {path}: {error.message}")


def _validate_authorities(packet: dict[str, Any], root: Path) -> None:
    expected = []
    for binding_id, relative in EXPECTED_BINDING_PATHS:
        path = root / relative
        if not path.is_file():
            raise CorrectionError(f"missing authority path: {relative}")
        expected.append(
            {"id": binding_id, "path": relative, "sha256": _sha256(path)}
        )
    if packet["authority_bindings"] != expected:
        raise CorrectionError("authority bindings drifted")


def _validate_complete_corrections(packet: dict[str, Any]) -> None:
    expected: list[dict[str, Any]] = []
    for correction_id, operation_ids, event, record_domains in EXPECTED_CORRECTIONS:
        rule: dict[str, Any] = {
            "correction_id": correction_id,
            "operation_ids": operation_ids,
            "event": event,
            "record_domains": record_domains,
            "field_rule": "append_only_unindexed_suffix",
            "required_suffix": EXPECTED_SUFFIXES[event],
            "mapping_authority": "record_reconstruction_rows",
        }
        if event == "ArtistAttributionStateChanged":
            rule.update(
                {
                    "other_operation_suffix_rule": (
                        "all five appended fields MUST be zero when recordHash is not a "
                        "BINDING_REFUSAL_RECORD_DOMAIN hash"
                    ),
                    "collision_rule": "a nonzero correction suffix on any other operation is invalid",
                }
            )
        if event == "ArtistHistoryLaneVerified":
            rule.update(
                {
                    "invariants": [
                        "predecessorRegistry != address(0)",
                        "recordCount > 0",
                        "sequence + 1 == recordCount",
                        "recordChainHash == laneTip",
                        "laneKind is 1 or 2",
                        "recordHash != bytes32(0)",
                        "recordChainHash != bytes32(0)",
                    ],
                    "hash_mode": "double_hashed_leaf_exactly_as_AA_IMPORT",
                }
            )
        if event == "ArtistIdentityRecovered":
            rule.update(
                {
                    "invariants": [
                        "array length is 0..64 inclusive",
                        "every element is nonzero",
                        "elements are strictly ascending as uint256(bytes32)",
                        "duplicates are forbidden",
                        "supersededRecordsHash == keccak256(abi.encode(domain, supersededRecordHashes))",
                    ],
                    "collision_rule": (
                        "array length and ABI offset are committed; packed encoding is forbidden"
                    ),
                }
            )
        expected.append(rule)
    if packet["correction_rules"] != expected:
        raise CorrectionError("complete correction rule identity/body/order drifted")


def _encode_static_word(component_type: str, value: Any) -> bytes:
    if component_type == "bytes32":
        if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-f]{64}", value):
            raise CorrectionError("bytes32 vector value is not canonical")
        return bytes.fromhex(value[2:])
    if component_type == "address":
        if not isinstance(value, str) or not re.fullmatch(r"0x[0-9a-f]{40}", value):
            raise CorrectionError("address vector value is not canonical")
        return int(value, 16).to_bytes(32, "big")
    match = re.fullmatch(r"uint(8|16|32|64|128|256)", component_type)
    if match:
        bits = int(match.group(1))
        if not isinstance(value, int) or isinstance(value, bool) or not 0 <= value < 2**bits:
            raise CorrectionError(f"{component_type} vector value is out of range")
        return value.to_bytes(32, "big")
    if component_type == "bool":
        if not isinstance(value, bool):
            raise CorrectionError("bool vector value is not canonical")
        return int(value).to_bytes(32, "big")
    raise CorrectionError(f"unsupported static vector type: {component_type}")


def _validate_independent_record_vectors(
    packet: dict[str, Any], record_rows: list[dict[str, Any]]
) -> None:
    records = {row["record_domain"]: row for row in record_rows}
    expected_packet: list[dict[str, Any]] = []
    for fixture in EXPECTED_RECORD_VECTOR_FIXTURES:
        schema = _record_components(records[fixture["record_domain"]])
        values = fixture["values"]
        if len(schema) != len(values):
            raise CorrectionError(f"independent vector arity drifted: {fixture['vector_id']}")
        components = [
            {"position": position, "type": component_type, "name": name, "value": value}
            for position, ((component_type, name), value) in enumerate(zip(schema, values, strict=True))
        ]
        if fixture["vector_id"] == "identity_recovery_supersession_dynamic_v1":
            domain_word = _encode_static_word(schema[0][0], values[0])
            hashes = values[1]
            if (
                not isinstance(hashes, list)
                or len(hashes) > 64
                or any(int(value, 16) == 0 for value in hashes)
                or hashes != sorted(hashes, key=lambda value: int(value, 16))
                or len(set(hashes)) != len(hashes)
            ):
                raise CorrectionError("independent supersession vector violates ordering/bounds")
            encoded = (
                domain_word
                + (64).to_bytes(32, "big")
                + len(hashes).to_bytes(32, "big")
                + b"".join(_encode_static_word("bytes32", value) for value in hashes)
            )
        else:
            encoded = b"".join(
                _encode_static_word(component_type, value)
                for (component_type, _name), value in zip(schema, values, strict=True)
            )
        words = ["0x" + encoded[index : index + 32].hex() for index in range(0, len(encoded), 32)]
        if words != fixture["expected_abi_words"]:
            raise CorrectionError(f"independent ABI words drifted: {fixture['vector_id']}")
        expected: dict[str, Any] = {
            "vector_id": fixture["vector_id"],
            "correction_id": fixture["correction_id"],
            "operation_id": fixture["operation_id"],
            "record_domain": fixture["record_domain"],
            "hash_mode": fixture["hash_mode"],
            "components": components,
            "expected_abi_words": fixture["expected_abi_words"],
            "expected_hash": fixture["expected_hash"],
        }
        if "expected_inner_hash" in fixture:
            expected["expected_inner_hash"] = fixture["expected_inner_hash"]
            inner = _keccak(encoded)
            if "0x" + inner.hex() != fixture["expected_inner_hash"]:
                raise CorrectionError("independent history inner hash drifted")
            computed_hash = _hex_keccak(inner)
        else:
            computed_hash = _hex_keccak(encoded)
        if computed_hash != fixture["expected_hash"]:
            raise CorrectionError(f"independent vector hash drifted: {fixture['vector_id']}")
        expected_packet.append(expected)
    if packet["canonical_record_vectors"] != expected_packet:
        raise CorrectionError("typed canonical record vector bytes/schema drifted")


def _historical_event_coverage(root: Path, commit: str, wanted: set[str]) -> tuple[int, int]:
    try:
        output = subprocess.check_output(
            ["git", "ls-tree", "-r", "--name-only", commit],
            cwd=root,
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        raise CorrectionError(f"cannot inspect historical source {commit}: {exc}") from exc
    paths = [
        line
        for line in output.splitlines()
        if line.startswith("smart-contracts/")
        and "Artist" in line
        and line.endswith(".sol")
    ]
    names: set[str] = set()
    for relative in paths:
        source = subprocess.check_output(
            ["git", "show", f"{commit}:{relative}"],
            cwd=root,
            text=True,
            errors="replace",
        )
        names.update(re.findall(r"\bevent\s+(\w+)\s*\(", source))
    return len(paths), len(names & wanted)


def _validate_upstream_posture(root: Path) -> None:
    foundation = load_json(root / FOUNDATION_PATH)
    shared = load_json(root / SHARED_PATH)
    matrix = load_json(root / MATRIX_PATH)
    if len(foundation["domain_layout_rows"]) != 7 or any(
        row["decision_status"] != "unresolved"
        or row["selected_domain_struct"] is not None
        or row["selected_domain_state_commitment"] is not None
        or row["source_blocking"] is not True
        for row in foundation["domain_layout_rows"]
    ):
        raise CorrectionError("seven owner layout rows no longer remain unresolved")
    if len(foundation["replay_surface_rows"]) != 64 or any(
        row["decision_status"] != "unresolved"
        or row["replay_kind"] is not None
        or row["scope_commitment_schema"] is not None
        or row["source_blocking"] is not True
        for row in foundation["replay_surface_rows"]
    ):
        raise CorrectionError("64 replay rows no longer remain unresolved")
    owner_side = foundation["owner_side_recomputation"]
    if owner_side["exact_inner_preimages_resolved"] is not False or any(
        owner_side[key] is not None
        for key in (
            "action_commitment_preimage",
            "domain_state_commitment_preimage",
            "replay_delta_commitment_preimage",
            "record_delta_commitment_preimage",
        )
    ):
        raise CorrectionError("four owner inner preimages no longer remain null")
    if shared["gate_state"]["accepted_decision_count"] != 3 or shared["gate_state"]["unresolved_decision_count"] != 16:
        raise CorrectionError("shared mechanics no longer remains 3/16")
    if any(
        operation["source_requirements"]["source_present"]
        or operation["source_requirements"]["implementation_authorized"]
        for operation in matrix["operations"]
    ):
        raise CorrectionError("a semantic operation gained source or authorization")


def check(root: Path = Path("."), packet_override: dict[str, Any] | None = None) -> None:
    root = root.resolve()
    packet = deepcopy(packet_override) if packet_override is not None else load_json(root / PACKET_PATH)
    schema = load_json(root / SCHEMA_PATH)
    matrix = load_json(root / MATRIX_PATH)
    operation_matrix = load_json(root / OPERATION_MATRIX_PATH)
    normative_text = (root / NORMATIVE_PATH).read_text(encoding="utf-8")

    _validate_schema(packet, schema)
    if packet["evaluated_base"] != {
        "commit": EXPECTED_BASE,
        "tree": EXPECTED_TREE,
        "shared_mechanics_accepted_count": 3,
        "shared_mechanics_unresolved_count": 16,
    }:
        raise CorrectionError("evaluated-base receipt drifted")
    _validate_authorities(packet, root)

    expected_records = _record_rows(normative_text, matrix, operation_matrix)
    if packet["record_domain_rows"] != expected_records:
        raise CorrectionError("37 ordered record-domain rows drifted")
    expected_events, expected_event_vectors = _event_rows(normative_text, matrix)
    if packet["event_surface_rows"] != expected_events:
        raise CorrectionError("54 ordered event rows drifted")
    if packet["canonical_event_vectors"] != expected_event_vectors:
        raise CorrectionError("54 canonical event vectors drifted")
    expected_operations = _operation_rows(matrix)
    if packet["operation_join_rows"] != expected_operations:
        raise CorrectionError("57 ordered operation joins drifted")
    expected_reconstruction = _reconstruction_rows(
        expected_records, expected_events, expected_operations
    )
    if packet["record_reconstruction_rows"] != expected_reconstruction:
        raise CorrectionError("40 created-record component mappings drifted")
    if packet["permitted_constants"] != EXPECTED_CONSTANTS:
        raise CorrectionError("permitted immutable constant inventory drifted")
    if packet["inventory"] != {
        "record_domains": 37,
        "normative_events": 54,
        "operations": 57,
        "corrected_events": 15,
        "preserved_events": 39,
        "historical_genesis_event_coverage": 21,
        "historical_split_event_coverage": 2,
        "created_record_bindings": 40,
        "record_component_bindings": 430,
    }:
        raise CorrectionError("inventory counts drifted")

    expected_options = [
        {
            "option_id": "weaken_event_only_reconstruction",
            "selected": False,
            "reason": "would permit implicit storage/current-state joins and weaken AA-RECON",
        },
        {
            "option_id": "fix_only_review_examples",
            "selected": False,
            "reason": "would leave the remaining 57-operation/37-domain component join unproved",
        },
        {
            "option_id": "complete_field_source_mapping_minimal_suffixes_independent_vectors",
            "selected": True,
            "reason": "smallest complete trust closure across all created records and canonical vectors",
        },
        {
            "option_id": "accept_packet_supplied_vector_words",
            "selected": False,
            "reason": "coordinated word, hash and semantic-digest re-pins would remain possible",
        },
    ]
    if packet["selected_shape"]["options"] != expected_options:
        raise CorrectionError("continuity option inventory/selection drifted")
    if packet["selected_shape"] != {
        "option_id": "complete_field_source_mapping_minimal_suffixes_independent_vectors",
        "selection_posture": "selected_for_architecture_review_only",
        "rationale": (
            "Prove every component of every created record from typed event payload bytes or an "
            "exact permitted immutable constant, append every mechanically required minimal event "
            "suffix, and independently pin typed record vectors."
        ),
        "options": expected_options,
    }:
        raise CorrectionError("selected complete trust-closure shape drifted")
    if packet["event_protocol"] != {
        "schema_version_position": 0,
        "schema_version_type": "uint16",
        "maximum_indexed_fields": 3,
        "topic0": "keccak256(canonical event signature)",
        "field_encoding": "Solidity ABI event encoding",
        "generic_event_allowed": False,
        "anonymous_events_allowed": False,
        "preservation_rule": (
            "the complete field-source proof determines corrections: each legacy prefix remains "
            "exact in type, order, name and indexed status, and only the fifteen mechanically "
            "incomplete events receive their exact unindexed suffix"
        ),
        "historical_implementation_posture": (
            "compatibility evidence only; not baseline, source authorization, deployment evidence, "
            "or readiness credit"
        ),
    }:
        raise CorrectionError("event correction protocol drifted")
    if packet["record_protocol"] != {
        "semantic_hash_mode": "retain exact V1 domain and preimage schema",
        "encoding": "abi.encode except the explicitly double-hashed import leaf",
        "abi_encode_packed_allowed": False,
        "event_only_reconstruction_required": True,
        "immutable_context_fields": [
            "recordDomain",
            "deploymentChainId",
            "RegistryV2",
            "provider:core",
            "provider:finality_registry",
            "typed protocol discriminator constants",
        ],
        "dual_continuity_packet_created": False,
        "owner_v2_record_commitment_created": False,
        "implicit_storage_or_current_state_joins_allowed": False,
        "every_created_record_component_mapped": True,
    }:
        raise CorrectionError("record reconstruction protocol drifted")

    _validate_complete_corrections(packet)
    _validate_independent_record_vectors(packet, expected_records)
    if packet["unresolved_dependencies"] != EXPECTED_UNRESOLVED:
        raise CorrectionError("unresolved dependency order/content drifted")
    expected_digest = "sha256:" + hashlib.sha256(
        json.dumps(
            {key: value for key, value in packet.items() if key != "semantic_digest"},
            separators=(",", ":"),
            sort_keys=True,
        ).encode("utf-8")
    ).hexdigest()
    if packet["semantic_digest"] != expected_digest:
        raise CorrectionError("packet semantic digest drifted")

    wanted_events = {row["event"] for row in matrix["event_surfaces"]}
    first = _historical_event_coverage(root, packet["historical_compatibility"][0]["commit"], wanted_events)
    second = _historical_event_coverage(root, packet["historical_compatibility"][1]["commit"], wanted_events)
    if first != (12, 21) or second != (27, 2):
        raise CorrectionError(f"historical compatibility evidence drifted: {first}, {second}")
    if packet["historical_compatibility"] != [
        {
            "commit": "58599147cadd7bb36d74e5a37485ff5d49ae9129",
            "artist_source_file_count": 12,
            "normative_event_coverage": 21,
            "normative_event_total": 54,
            "posture": "compatibility_evidence_only",
        },
        {
            "commit": "1c991bc9f7d3a35e36f6fa2ec2a1044d1ed65ff7",
            "artist_source_file_count": 27,
            "normative_event_coverage": 2,
            "normative_event_total": 54,
            "generic_event": "ArtistOperationCommitted",
            "posture": "compatibility_evidence_only",
        },
    ]:
        raise CorrectionError("historical compatibility packet claim drifted")

    _validate_upstream_posture(root)
    rationale = (root / RATIONALE_PATH).read_text(encoding="utf-8")
    for required in (
        "Proposed correction packet only; pre-audit and source-blocking.",
        "does not create the later dual-continuity",
        "all 64 replay rows",
        "authorizes no Solidity",
    ):
        if required not in rationale:
            raise CorrectionError(f"rationale boundary wording drifted: {required}")


def main() -> int:
    try:
        check()
    except CorrectionError as exc:
        print(f"artist record/event reconstruction correction check failed: {exc}")
        return 1
    print(
        "artist record/event reconstruction correction check passed: "
        "37 record domains, 54 typed events (39 retained + 15 corrected), "
        "57 operation joins, 40 created-record maps and 430 component bindings; "
        "normative events and source remain unauthorized"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
