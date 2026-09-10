#!/usr/bin/env python3
"""Independent fixed-golden audit of the system-manifest payload vector.

This reference oracle intentionally does not import the vector generator, the
primary checker, or either module's codecs/formula helpers.  It reimplements the
small fixture-specific JCS and ABI encodings below and compares their results to
reviewed fixed goldens.  A shared defect in the generator and primary checker
therefore cannot bless a newly self-consistent but incompatible vector.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path
from typing import Any, Sequence


DEFAULT_VECTOR = Path("release-artifacts/system-manifest-payload-vector.json")
DEFAULT_PROFILE = Path("release-artifacts/genesis-deployment-profile.json")

VECTOR_SCHEMA = "6529stream.system-manifest-payload-vector.v1"
FIXTURE_DOMAIN = "6529STREAM_SYSTEM_MANIFEST_TARGET_VECTOR_V1"
PROFILE_SHA256 = "sha256:e02b966c735ed62d717830612a66f759b07c037e1dee49ec2a46946f6b4d1135"
PROFILE_SCHEMA = "6529stream.genesis-deployment-profile.v2"
PROFILE_NORMATIVE_ANCHOR = "docs/stream-long-term-architecture.md#LTA-MANIFEST"
PAYLOAD_BYTE_LENGTH = 55_109
PAYLOAD_KECCAK = "0x23e29269a33db5b039360ff416749b337910d39eaa82c04de7601ad984623d38"
PAYLOAD_SHA256 = "sha256:a7ed330450881081d9c330d4cce88c6075960ca5fec65ff1206f20c338a87e3e"

IDENTITY_DOMAIN = "0xabba888804ef35beb44d732a5f39abc2609bd065f98a99779289a9e9c2a4059a"
IDENTITY_VIEW_HASH = "0x4771bfdb1073d98ed9a969ec4beb32e5ba18eac629a6b1043f00c7828742456a"
DEPLOYMENT_IDENTITY_HASH = (
    "0xe372461cbfe0b9c8d89a54aa35ab81ea8a173e89bce196f47f1d7c350ac45b00"
)

CHUNK_BYTES = 24_575
LEAF_DOMAIN = "0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5"
LIST_DOMAIN = "0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839"
ROOT_DOMAIN = "0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b"
SCHEMA_ID = "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81"
CANONICALIZATION_ID = (
    "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044"
)
CHUNK_LIST_HASH = "0xf680bb0e85aa2bb5848b43dbb2ee1c2f55b68223ca97fa3e1b4ef35ca88f1855"
PAYLOAD_ROOT_HASH = "0x7409ea442420e4cbbc31d888f48e74ea6a2e1728c8ba433767a572db9e2670e0"

DESCRIPTOR_MAGIC = "0x6c9d2530"
DESCRIPTOR_DYNAMIC_OFFSET = 224
DESCRIPTOR_LENGTH = 544
DESCRIPTOR_KECCAK = "0x697ab9f1b6075cdf5f957e688adb9635de0dcd7be2c4ea8e97fb5500ad3db49e"
DESCRIPTOR_RUNTIME_HASH = (
    "0x7d117776fa2b116641cacdc3904c00c4b55b25d755d373eec4020f98ad6902ec"
)

# index, pointer, payload length, payload hash, leaf hash, SSTORE2 runtime hash
CHUNK_GOLDENS = (
    (
        0,
        "0x3323cfaf8192dd4891a01ddd0ad05add50946817",
        24_575,
        "0x2b45351f26b3c15d1fa9bdf1ddfc063c43822621a1534fb9750bd14dae26f722",
        "0xc8f0457736e149911c8354caf19d7e097b3e4df571cf465de4814f5ca6dea5d3",
        "0x6e3a62c8f33f16450961e5340314183b3b0d8ab53ab7a6212887f9921480aba9",
    ),
    (
        1,
        "0x3168c46ba1b3b0e72f9f7eb5951d2794f5adc881",
        24_575,
        "0x2fa2ab4aa6e175f14348983ee9d7c6b3540066334154dcd8be3c81f42415537a",
        "0x6883496d9211c42718f3b447dc7979d83cec894419648588f8c6c06139aecfb9",
        "0x511722dbede40fb8319cc9760988f5cd6f85928e124dab49608f1850bc48a414",
    ),
    (
        2,
        "0x06f7d9cf78b0d834bc89786b2c3bfa9ecd4ad24c",
        5_959,
        "0xf4fcc63861a1701907843ad2a0d9c172686d868f8bee662b311e648f62914a3e",
        "0x943be1d600842f4d311d31ed7f9c5e764815361c903b18bf085625b98ca8e2ca",
        "0x435d80d94cb2d137e2094123e149c9cefd89d09f6130f8e205cdf37cd5cfeacf",
    ),
)

STATE_EXPORT_LATEST_SIGNATURE = "latestStateExport()"
STATE_EXPORT_LATEST_SELECTOR = "0x77faad4f"
STATE_EXPORT_INTERFACE_ID = STATE_EXPORT_LATEST_SELECTOR
STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID = "0xebf35615"
STATE_EXPORT_ABI_SCHEMA = "6529stream.state-export-publisher-abi.v1"
STATE_EXPORT_ABI_SHA256 = (
    "sha256:535217fe4e980b1c72bc1a24f0352a7704928a3cd25f4197bdff0604d7645ea7"
)
FINALITY_ADAPTER_SELECTORS = {
    "core()": "0xf2f4eb26",
    "collectionMetadata()": "0x89ed2edf",
    "coreCollectionFinalityFacts(uint256)": "0x4eb4b6dc",
    "scopedCoreFinalityFacts((uint8,uint256,uint256,bytes32))": "0xde5e2530",
}
STATE_EXPORT_LATEST_RETURNS = [
    "uint256",
    "bytes32",
    "bytes32",
    "bytes32",
    "string",
]
STATE_EXPORT_EVENT_TOPICS = {
    "StateExportPublished(uint16,uint256,bytes32,bytes32,bytes32,string)": (
        "0x4b64ff5d268568999197a07e66632a3d1cf86adfb499394383bfa5e02577f045"
    ),
    "StateExportChallenged(uint16,bytes32,bytes32,address,string)": (
        "0x7dcf7c00a2fcd9a11d7b2a1a1c7f49b2ddffe3bb28e97a0efd2e53d2e183a68c"
    ),
    "StateExportSuperseded(uint16,bytes32,bytes32,bytes32,string)": (
        "0xd38e3f1ed11d4a002ed59a6ac2242bb16b6681891fbdbbbf55077edf92bfdc4a"
    ),
}
STATE_EXPORT_EVENT_INDEXED_MASKS = {
    "StateExportPublished(uint16,uint256,bytes32,bytes32,bytes32,string)": [
        False,
        True,
        True,
        True,
        False,
        False,
    ],
    "StateExportChallenged(uint16,bytes32,bytes32,address,string)": [
        False,
        True,
        True,
        True,
        False,
    ],
    "StateExportSuperseded(uint16,bytes32,bytes32,bytes32,string)": [
        False,
        True,
        True,
        True,
        False,
    ],
}
AUTHORITY_MARKER_SIGNATURE = "isStreamGovernedParameterAuthority()"
AUTHORITY_MARKER_SELECTOR = "0x8d96760d"
AUTHORITY_CONTEXT_SIGNATURE = "currentAction()"
AUTHORITY_CONTEXT_SELECTOR = "0x546ea281"
AUTHORITY_INTERFACE_ID = "0xd9f8d48c"
AUTHORITY_ABI_SCHEMA = "6529stream.governed-parameter-authority-abi.v1"
AUTHORITY_ABI_SHA256 = (
    "sha256:720e3b782672b5720bf4c679f09a20a3de74c4df856e34ad23bfc99a710b827a"
)
AUTHORITY_CONTEXT_RETURNS = [
    "bool",
    "bytes32",
    "uint8",
    "bytes32",
    "bytes32",
    "bytes32",
]


class ReferenceVectorError(RuntimeError):
    """Raised when the independent oracle finds fixture drift."""


def _reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ReferenceVectorError(f"duplicate JSON member: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path) -> tuple[dict[str, Any], bytes]:
    raw = path.read_bytes()
    try:
        value = json.loads(
            raw.decode("utf-8", "strict"),
            object_pairs_hook=_reject_duplicate_pairs,
            parse_float=lambda token: (_ for _ in ()).throw(
                ReferenceVectorError(f"floating-point JSON is forbidden: {token}")
            ),
            parse_constant=lambda token: (_ for _ in ()).throw(
                ReferenceVectorError(f"non-I-JSON token is forbidden: {token}")
            ),
        )
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ReferenceVectorError(f"{path} is not strict UTF-8 JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ReferenceVectorError(f"{path} root must be an object")
    return value, raw


def _keccak(value: bytes) -> bytes:
    # Deliberately use one independent backend, not the generator's fallback chain.
    try:
        from Crypto.Hash import keccak
    except ImportError as exc:  # pragma: no cover - locked tool requirements provide it
        raise ReferenceVectorError("independent oracle requires pycryptodome Keccak-256") from exc
    digest = keccak.new(digest_bits=256)
    digest.update(value)
    return digest.digest()


def _keccak_hex(value: bytes) -> str:
    return "0x" + _keccak(value).hex()


def _fixed_hex(value: Any, byte_length: int, path: str) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x"):
        raise ReferenceVectorError(f"{path} must be 0x-prefixed hex")
    try:
        decoded = bytes.fromhex(value[2:])
    except ValueError as exc:
        raise ReferenceVectorError(f"{path} is malformed hex") from exc
    if len(decoded) != byte_length or value != "0x" + decoded.hex():
        raise ReferenceVectorError(
            f"{path} must be lowercase fixed-width {byte_length}-byte hex"
        )
    return decoded


def _word(value: int, bits: int, path: str) -> bytes:
    if isinstance(value, bool) or not isinstance(value, int) or value < 0 or value >= 1 << bits:
        raise ReferenceVectorError(f"{path} does not fit uint{bits}")
    return value.to_bytes(32, "big")


def _assert_reference_json(value: Any, path: str = "payload") -> None:
    """Limit this fixture to the JCS subset independently encoded below."""

    if isinstance(value, dict):
        for key, member in value.items():
            if not isinstance(key, str) or not key.isascii():
                raise ReferenceVectorError(f"{path} has a non-ASCII member name")
            _assert_reference_json(member, f"{path}.{key}")
        return
    if isinstance(value, list):
        for index, member in enumerate(value):
            _assert_reference_json(member, f"{path}[{index}]")
        return
    if isinstance(value, str):
        if not value.isascii():
            raise ReferenceVectorError(f"{path} is outside the audited ASCII JCS fixture")
        return
    if isinstance(value, bool):
        return
    if isinstance(value, int):
        if value < 0 or value > (1 << 53) - 1:
            raise ReferenceVectorError(f"{path} is outside the I-JSON safe integer range")
        return
    raise ReferenceVectorError(f"{path} has unsupported JCS type {type(value).__name__}")


def _reference_jcs(value: dict[str, Any]) -> bytes:
    _assert_reference_json(value)
    # With audited ASCII names/values and safe integers, this is the exact RFC 8785 form.
    return json.dumps(
        value,
        ensure_ascii=False,
        allow_nan=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _expect(actual: Any, expected: Any, path: str) -> None:
    if type(actual) is not type(expected):
        raise ReferenceVectorError(
            f"{path} drifted: expected {type(expected).__name__}, "
            f"got {type(actual).__name__}"
        )
    if isinstance(expected, dict):
        if set(actual) != set(expected):
            raise ReferenceVectorError(
                f"{path} keys drifted: expected {sorted(expected)!r}, "
                f"got {sorted(actual)!r}"
            )
        for key in expected:
            _expect(actual[key], expected[key], f"{path}.{key}")
        return
    if isinstance(expected, list):
        if len(actual) != len(expected):
            raise ReferenceVectorError(
                f"{path} length drifted: expected {len(expected)}, got {len(actual)}"
            )
        for index, (actual_item, expected_item) in enumerate(
            zip(actual, expected, strict=True)
        ):
            _expect(actual_item, expected_item, f"{path}[{index}]")
        return
    if actual != expected:
        raise ReferenceVectorError(f"{path} drifted: expected {expected!r}, got {actual!r}")


def _metadata_audit(vector: dict[str, Any]) -> None:
    _expect(
        vector["source"]["genesis_deployment_profile"],
        "release-artifacts/genesis-deployment-profile.json",
        "profile source path",
    )
    _expect(vector["source"]["profile_entry_count"], 37, "profile source entry count")
    _expect(
        vector["source"]["profile_schema_version"],
        PROFILE_SCHEMA,
        "profile source schema",
    )
    _expect(
        vector["source"]["normative_anchor"],
        PROFILE_NORMATIVE_ANCHOR,
        "profile source normative anchor",
    )
    expected_constants = {
        "schema_version": 1,
        "payload_schema_literal": "STREAM_SYSTEM_MANIFEST_PAYLOAD_V1",
        "payload_schema_id": SCHEMA_ID,
        "canonicalization_literal": "RFC8785_JCS",
        "canonicalization_id": CANONICALIZATION_ID,
        "chunk_payload_bytes": CHUNK_BYTES,
        "max_manifest_chunks": 32,
        "max_manifest_payload_bytes": 786_400,
        "max_root_descriptor_bytes": 3_328,
        "root_descriptor_magic": DESCRIPTOR_MAGIC,
        "root_descriptor_dynamic_offset": DESCRIPTOR_DYNAMIC_OFFSET,
        "payload_leaf_domain": LEAF_DOMAIN,
        "payload_list_domain": LIST_DOMAIN,
        "payload_root_domain": ROOT_DOMAIN,
        "deployment_identity_domain": IDENTITY_DOMAIN,
    }
    _expect(vector["constants"], expected_constants, "fixed vector constants")

    computed_selector = "0x" + _keccak(STATE_EXPORT_LATEST_SIGNATURE.encode("ascii"))[:4].hex()
    _expect(computed_selector, STATE_EXPORT_LATEST_SELECTOR, "state-export selector golden")
    _expect(computed_selector, STATE_EXPORT_INTERFACE_ID, "one-function interface ID")
    finality_interface_id = 0
    for signature, selector in FINALITY_ADAPTER_SELECTORS.items():
        computed = "0x" + _keccak(signature.encode("ascii"))[:4].hex()
        _expect(computed, selector, f"{signature} selector golden")
        finality_interface_id ^= int(computed, 16)
    _expect(
        f"0x{finality_interface_id:08x}",
        STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID,
        "finality adapter interface ID golden",
    )
    for signature, topic in STATE_EXPORT_EVENT_TOPICS.items():
        _expect(_keccak_hex(signature.encode("ascii")), topic, f"{signature} topic golden")
    surface_without_digest = {
        "schema": STATE_EXPORT_ABI_SCHEMA,
        "required_interface": "IStreamStateExportPublisher",
        "interface_id": STATE_EXPORT_INTERFACE_ID,
        "functions": [
            {
                "signature": STATE_EXPORT_LATEST_SIGNATURE,
                "selector": computed_selector,
                "state_mutability": "view",
                "returns": STATE_EXPORT_LATEST_RETURNS,
            }
        ],
        "events": [
            {
                "signature": signature,
                "topic0": topic,
                "anonymous": False,
                "indexed": STATE_EXPORT_EVENT_INDEXED_MASKS[signature],
            }
            for signature, topic in STATE_EXPORT_EVENT_TOPICS.items()
        ],
    }
    computed_abi_digest = (
        "sha256:" + hashlib.sha256(_reference_jcs(surface_without_digest)).hexdigest()
    )
    _expect(computed_abi_digest, STATE_EXPORT_ABI_SHA256, "state-export ABI digest")
    surface = vector["fixture_derivation"]["state_export_publisher_surface"]
    _expect(
        surface,
        {**surface_without_digest, "surface_sha256": computed_abi_digest},
        "complete state-export ABI surface",
    )

    derivation = vector["fixture_derivation"]
    _expect(
        derivation["state_export_publisher_binding"],
        "GOVERNANCE_LAYER",
        "state-export publisher binding",
    )
    _expect(
        derivation["governed_parameter_authority_binding"],
        "GOVERNANCE_LAYER",
        "governed-parameter authority binding",
    )
    authority_marker_selector = (
        "0x" + _keccak(AUTHORITY_MARKER_SIGNATURE.encode("ascii"))[:4].hex()
    )
    authority_context_selector = (
        "0x" + _keccak(AUTHORITY_CONTEXT_SIGNATURE.encode("ascii"))[:4].hex()
    )
    _expect(
        authority_marker_selector,
        AUTHORITY_MARKER_SELECTOR,
        "governed-parameter authority marker selector golden",
    )
    _expect(
        authority_context_selector,
        AUTHORITY_CONTEXT_SELECTOR,
        "governed-parameter authority context selector golden",
    )
    authority_interface_id = (
        int(authority_marker_selector, 16) ^ int(authority_context_selector, 16)
    )
    _expect(
        f"0x{authority_interface_id:08x}",
        AUTHORITY_INTERFACE_ID,
        "governed-parameter authority interface ID golden",
    )
    authority_surface_without_digest = {
        "schema": AUTHORITY_ABI_SCHEMA,
        "required_interface": "IStreamGovernedParameterAuthority",
        "interface_id": AUTHORITY_INTERFACE_ID,
        "functions": [
            {
                "signature": AUTHORITY_MARKER_SIGNATURE,
                "selector": authority_marker_selector,
                "state_mutability": "view",
                "returns": ["bool"],
            },
            {
                "signature": AUTHORITY_CONTEXT_SIGNATURE,
                "selector": authority_context_selector,
                "state_mutability": "view",
                "returns": AUTHORITY_CONTEXT_RETURNS,
            },
        ],
        "events": [],
    }
    computed_authority_digest = (
        "sha256:"
        + hashlib.sha256(_reference_jcs(authority_surface_without_digest)).hexdigest()
    )
    _expect(
        computed_authority_digest,
        AUTHORITY_ABI_SHA256,
        "governed-parameter authority ABI digest",
    )
    _expect(
        derivation["governed_parameter_authority_surface"],
        {
            **authority_surface_without_digest,
            "surface_sha256": computed_authority_digest,
        },
        "complete governed-parameter authority ABI surface",
    )


def _publisher_binding_audit(vector: dict[str, Any]) -> None:
    payload = vector["payload"]
    governance_address = vector["semantic_round_trip"]["contract_address_by_key"][
        "GOVERNANCE_LAYER"
    ]
    publisher_pointer_type = _keccak_hex(b"STATE_EXPORT_PUBLISHER")
    publisher_pointers = [
        row
        for row in payload["pointers"]
        if row["pointerType"] == publisher_pointer_type
    ]
    if len(publisher_pointers) != 1:
        raise ReferenceVectorError(
            "STATE_EXPORT_PUBLISHER pointer must appear exactly once"
        )
    publisher_pointer = publisher_pointers[0]
    _expect(publisher_pointer["target"], governance_address, "publisher pointer target")
    _expect(
        publisher_pointer["interfaceId"],
        STATE_EXPORT_INTERFACE_ID,
        "publisher pointer interface ID",
    )

    governance_records = [
        row
        for row in payload["registryEntries"]
        if row["module"] == governance_address
    ]
    if len(governance_records) != 1:
        raise ReferenceVectorError(
            "GOVERNANCE_LAYER registry record must appear exactly once"
        )
    _expect(
        governance_records[0]["interfaceId"],
        STATE_EXPORT_INTERFACE_ID,
        "governance registry publisher interface ID",
    )


def _finality_adapter_binding_audit(vector: dict[str, Any]) -> None:
    adapter_address = vector["semantic_round_trip"]["contract_address_by_key"][
        "STREAM_CORE_FINALITY_ADAPTER"
    ]
    adapter_records = [
        row
        for row in vector["payload"]["registryEntries"]
        if row["module"] == adapter_address
    ]
    if len(adapter_records) != 1:
        raise ReferenceVectorError(
            "STREAM_CORE_FINALITY_ADAPTER registry record must appear exactly once"
        )
    _expect(
        adapter_records[0]["interfaceId"],
        STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID,
        "finality adapter registry interface ID",
    )


def _identity_audit(vector: dict[str, Any], profile_raw: bytes) -> None:
    profile_hash = "sha256:" + hashlib.sha256(profile_raw).hexdigest()
    _expect(profile_hash, PROFILE_SHA256, "fixed profile SHA-256 golden")
    _expect(
        vector["source"]["genesis_deployment_profile_sha256"],
        PROFILE_SHA256,
        "vector source profile SHA-256",
    )

    preimage = (
        f"{FIXTURE_DOMAIN}|deployment-identity-view-hash|{profile_hash}".encode("utf-8")
    )
    identity_view = _keccak_hex(preimage)
    _expect(identity_view, IDENTITY_VIEW_HASH, "deployment identity-view hash")
    outer = _fixed_hex(IDENTITY_DOMAIN, 32, "identity domain") + _fixed_hex(
        identity_view, 32, "identity-view hash"
    )
    identity_hash = _keccak_hex(outer)
    _expect(identity_hash, DEPLOYMENT_IDENTITY_HASH, "deployment identity hash")

    recorded = vector["fixture_derivation"]["deployment_identity"]
    _expect(recorded["domain"], IDENTITY_DOMAIN, "recorded deployment identity domain")
    _expect(recorded["identity_view_hash"], identity_view, "recorded identity-view hash")
    _expect(recorded["hash"], identity_hash, "recorded deployment identity hash")

    payload = vector["payload"]
    occurrences: list[Any] = []
    for row in payload["contracts"]:
        occurrences.append(row["deploymentManifestHash"])
    for row in payload["pointers"]:
        occurrences.append(row["deploymentManifestHash"])
    for row in payload["registryEntries"]:
        occurrences.append(row["deploymentManifestHash"])
    for row in payload["criticalFallbacks"]:
        occurrences.append(row["deploymentManifestHash"])
    if not occurrences or any(value != identity_hash for value in occurrences):
        raise ReferenceVectorError("deployment identity is not byte-identical at every occurrence")
    _expect(
        vector["semantic_round_trip"]["deployment_manifest_hash"],
        identity_hash,
        "semantic deployment identity hash",
    )


def _chunk_audit(vector: dict[str, Any], canonical: bytes) -> tuple[list[bytes], list[str]]:
    segments = [canonical[offset : offset + CHUNK_BYTES] for offset in range(0, len(canonical), CHUNK_BYTES)]
    _expect(len(segments), len(CHUNK_GOLDENS), "chunk count")
    chunks = vector["chunks"]
    _expect(len(chunks), len(CHUNK_GOLDENS), "recorded chunk count")

    leaf_hashes: list[str] = []
    for golden, segment, row in zip(CHUNK_GOLDENS, segments, chunks, strict=True):
        index, pointer, length, payload_hash, leaf_hash, runtime_hash = golden
        _expect(row["index"], index, f"chunk {index} index")
        _expect(len(segment), length, f"chunk {index} payload length golden")
        _expect(row["payload_length"], length, f"chunk {index} recorded payload length")
        _expect(row["segment_hex"], "0x" + segment.hex(), f"chunk {index} segment bytes")

        computed_payload_hash = _keccak_hex(segment)
        _expect(computed_payload_hash, payload_hash, f"chunk {index} payload hash golden")
        _expect(row["payload_hash"], payload_hash, f"chunk {index} recorded payload hash")

        pointer_preimage = (
            f"{FIXTURE_DOMAIN}|sstore2-chunk-pointer|{index}|{payload_hash}".encode("utf-8")
        )
        computed_pointer = "0x" + _keccak(pointer_preimage)[-20:].hex()
        _expect(computed_pointer, pointer, f"chunk {index} pointer golden")
        _expect(row["pointer"], pointer, f"chunk {index} recorded pointer")

        leaf_preimage = b"".join(
            (
                _fixed_hex(LEAF_DOMAIN, 32, "leaf domain"),
                _word(index, 256, "chunk index"),
                _word(length, 32, "chunk length"),
                _fixed_hex(payload_hash, 32, "payload hash"),
            )
        )
        computed_leaf = _keccak_hex(leaf_preimage)
        _expect(computed_leaf, leaf_hash, f"chunk {index} leaf hash golden")
        _expect(row["leaf_hash"], leaf_hash, f"chunk {index} recorded leaf hash")

        computed_runtime = _keccak_hex(b"\x00" + segment)
        _expect(computed_runtime, runtime_hash, f"chunk {index} runtime hash golden")
        _expect(row["runtime_code_hash"], runtime_hash, f"chunk {index} runtime hash")
        leaf_hashes.append(computed_leaf)
    return segments, leaf_hashes


def _commitment_audit(vector: dict[str, Any], leaf_hashes: list[str]) -> None:
    list_preimage = b"".join(
        (
            _fixed_hex(LIST_DOMAIN, 32, "list domain"),
            _word(PAYLOAD_BYTE_LENGTH, 32, "payload byte length"),
            _word(96, 256, "leaf array dynamic offset"),
            _word(len(leaf_hashes), 256, "leaf array length"),
            *(_fixed_hex(value, 32, "leaf hash") for value in leaf_hashes),
        )
    )
    list_hash = _keccak_hex(list_preimage)
    _expect(list_hash, CHUNK_LIST_HASH, "chunk-list hash golden")

    root_preimage = b"".join(
        (
            _fixed_hex(ROOT_DOMAIN, 32, "root domain"),
            _word(1, 16, "schema version"),
            _fixed_hex(SCHEMA_ID, 32, "schema ID"),
            _fixed_hex(CANONICALIZATION_ID, 32, "canonicalization ID"),
            _word(PAYLOAD_BYTE_LENGTH, 32, "payload byte length"),
            _word(len(leaf_hashes), 16, "chunk count"),
            _fixed_hex(list_hash, 32, "chunk-list hash"),
        )
    )
    root_hash = _keccak_hex(root_preimage)
    _expect(root_hash, PAYLOAD_ROOT_HASH, "payload-root hash golden")

    commitments = vector["commitments"]
    _expect(commitments["ordered_leaf_hashes"], leaf_hashes, "ordered leaf hashes")
    _expect(commitments["chunk_list_hash"], list_hash, "recorded chunk-list hash")
    _expect(commitments["payload_root_hash"], root_hash, "recorded payload-root hash")
    _expect(commitments["manifest_hash"], root_hash, "recorded manifest hash")


def _descriptor_audit(vector: dict[str, Any]) -> None:
    descriptor = vector["root_descriptor"]
    chunks = vector["chunks"]
    encoded = b"".join(
        (
            _fixed_hex(DESCRIPTOR_MAGIC, 4, "descriptor magic") + b"\x00" * 28,
            _word(1, 16, "descriptor schema version"),
            _fixed_hex(SCHEMA_ID, 32, "descriptor schema ID"),
            _fixed_hex(CANONICALIZATION_ID, 32, "descriptor canonicalization ID"),
            _word(PAYLOAD_BYTE_LENGTH, 32, "descriptor total bytes"),
            _word(len(chunks), 16, "descriptor chunk count"),
            _word(DESCRIPTOR_DYNAMIC_OFFSET, 256, "descriptor dynamic offset"),
            _word(len(chunks), 256, "descriptor array length"),
            *(
                b"".join(
                    (
                        b"\x00" * 12 + _fixed_hex(row["pointer"], 20, "chunk pointer"),
                        _word(row["payload_length"], 32, "chunk payload length"),
                        _fixed_hex(row["payload_hash"], 32, "chunk payload hash"),
                    )
                )
                for row in chunks
            ),
        )
    )
    _expect(len(encoded), DESCRIPTOR_LENGTH, "root descriptor length golden")
    _expect(_keccak_hex(encoded), DESCRIPTOR_KECCAK, "root descriptor Keccak golden")
    _expect(
        _keccak_hex(b"\x00" + encoded),
        DESCRIPTOR_RUNTIME_HASH,
        "root descriptor runtime hash golden",
    )

    _expect(descriptor["magic"], DESCRIPTOR_MAGIC, "descriptor magic")
    _expect(descriptor["schema_version"], 1, "descriptor schema version")
    _expect(descriptor["schema_id"], SCHEMA_ID, "descriptor schema ID")
    _expect(
        descriptor["canonicalization_id"],
        CANONICALIZATION_ID,
        "descriptor canonicalization ID",
    )
    _expect(descriptor["total_bytes"], PAYLOAD_BYTE_LENGTH, "descriptor total bytes")
    _expect(descriptor["chunk_count"], len(chunks), "descriptor chunk count")
    _expect(descriptor["dynamic_offset"], DESCRIPTOR_DYNAMIC_OFFSET, "descriptor offset")
    _expect(descriptor["encoded_length"], len(encoded), "descriptor encoded length")
    _expect(descriptor["encoded_hex"], "0x" + encoded.hex(), "descriptor encoded bytes")
    _expect(descriptor["keccak256"], DESCRIPTOR_KECCAK, "descriptor recorded Keccak")
    _expect(
        descriptor["runtime_code_hash"],
        DESCRIPTOR_RUNTIME_HASH,
        "descriptor recorded runtime hash",
    )
    expected_rows = [
        {
            "pointer": row["pointer"],
            "payload_length": row["payload_length"],
            "payload_hash": row["payload_hash"],
        }
        for row in chunks
    ]
    _expect(descriptor["chunks"], expected_rows, "descriptor chunk rows")


def audit_vector(vector: dict[str, Any], profile_raw: bytes) -> None:
    _expect(vector.get("schema_version"), VECTOR_SCHEMA, "vector schema")
    _expect(vector.get("evidence_class"), "target_abi_lock_fixture", "evidence class")
    _expect(vector.get("production_candidate"), False, "production-candidate flag")
    _expect(vector.get("readiness_evidence"), False, "readiness-evidence flag")

    # A known Ethereum Keccak vector prevents accidental NIST SHA3 substitution.
    _expect(
        _keccak_hex(b""),
        "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        "Keccak-256 backend self-test",
    )
    _metadata_audit(vector)
    _publisher_binding_audit(vector)
    _finality_adapter_binding_audit(vector)
    payload = vector["payload"]
    if not isinstance(payload, dict):
        raise ReferenceVectorError("payload must be an object")
    canonical = _reference_jcs(payload)
    _expect(len(canonical), PAYLOAD_BYTE_LENGTH, "canonical payload byte-length golden")
    _expect(_keccak_hex(canonical), PAYLOAD_KECCAK, "canonical payload Keccak golden")
    _expect(
        "sha256:" + hashlib.sha256(canonical).hexdigest(),
        PAYLOAD_SHA256,
        "canonical payload SHA-256 golden",
    )

    recorded = vector["canonical_payload"]
    _expect(recorded["canonicalization"], "RFC8785_JCS", "canonicalization label")
    _expect(recorded["byte_length"], len(canonical), "recorded canonical byte length")
    _expect(recorded["keccak256"], PAYLOAD_KECCAK, "recorded canonical Keccak")
    _expect(recorded["sha256"], PAYLOAD_SHA256, "recorded canonical SHA-256")
    _expect(recorded["utf8_hex"], "0x" + canonical.hex(), "recorded canonical bytes")

    _identity_audit(vector, profile_raw)
    segments, leaf_hashes = _chunk_audit(vector, canonical)
    _expect(b"".join(segments), canonical, "chunk concatenation")
    _commitment_audit(vector, leaf_hashes)
    _descriptor_audit(vector)

    payload_counts = (
        ("contracts", 37),
        ("pointers", 11),
        ("registryEntries", 37),
        ("gasParameterProbes", 0),
        ("criticalFallbacks", 2),
    )
    for name, expected in payload_counts:
        _expect(len(payload[name]), expected, f"payload {name} count golden")


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vector", type=Path, default=DEFAULT_VECTOR)
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        vector, _ = load_json_strict(args.vector)
        _, profile_raw = load_json_strict(args.profile)
        audit_vector(vector, profile_raw)
    except (KeyError, OSError, ReferenceVectorError, TypeError) as exc:
        print(f"independent system manifest vector reference check failed: {exc}", file=sys.stderr)
        return 1
    print(
        "independent system manifest vector reference goldens are valid: "
        f"{PAYLOAD_BYTE_LENGTH} JCS bytes, {len(CHUNK_GOLDENS)} chunks, "
        f"descriptor {DESCRIPTOR_LENGTH} bytes"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
