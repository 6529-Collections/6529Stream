#!/usr/bin/env python3
"""Generate the non-production StreamSystemManifest payload ABI-lock vector.

The genesis deployment profile is a planning inventory, not an instance-aware
deployment manifest.  This generator therefore derives deterministic fixture
addresses and hashes from every profile entry.  The resulting vector locks the
JCS, chunking, commitment, and root-descriptor mechanics without claiming that
the synthetic state is deployable production evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Any, Iterable, Sequence


VECTOR_SCHEMA = "6529stream.system-manifest-payload-vector.v1"
PROFILE_SCHEMA = "6529stream.genesis-deployment-profile.v1"
EVIDENCE_CLASS = "target_abi_lock_fixture"
DEFAULT_PROFILE = Path("release-artifacts/genesis-deployment-profile.json")
DEFAULT_OUTPUT = Path("release-artifacts/system-manifest-payload-vector.json")
BLOCKER_ISSUE = "https://github.com/6529-Collections/6529Stream/issues/656"

EXPECTED_PROFILE_ENTRIES = 60
CHAIN_ID = 1
SCHEMA_VERSION = 1
CHUNK_PAYLOAD_BYTES = 24_575
MAX_MANIFEST_CHUNKS = 32
MAX_MANIFEST_PAYLOAD_BYTES = 786_400
MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES = 3_328
ROOT_DESCRIPTOR_DYNAMIC_OFFSET = 224
ROOT_DESCRIPTOR_MAGIC = "0x6c9d2530"

PAYLOAD_SCHEMA_LITERAL = "STREAM_SYSTEM_MANIFEST_PAYLOAD_V1"
PAYLOAD_SCHEMA_ID = (
    "0x8844b744a67cdcdb84ea3c6e3d686883da175820b9ff07a19cffa14bf62e6e81"
)
CANONICALIZATION_LITERAL = "RFC8785_JCS"
CANONICALIZATION_ID = (
    "0x886c7c89c308c459ca8a626e0ef36a5ea9f4c7a7b56aaf86c71a2ddf3b4f9044"
)
PAYLOAD_LEAF_DOMAIN = (
    "0x852f4811a2eb32694863d94ba41b545a65ef4c76086a32c35881f0c4e250a7b5"
)
PAYLOAD_LIST_DOMAIN = (
    "0xa93750a5551ac5668c8f24cca85acaf1d5f8334fac9406f845fce1ce35548839"
)
PAYLOAD_ROOT_DOMAIN = (
    "0xd6ab89b077c61a288c7168cf8f1c9a7a19464b10475735dae37cb46a0c94c40b"
)
DEPLOYMENT_IDENTITY_DOMAIN = (
    "0xabba888804ef35beb44d732a5f39abc2609bd065f98a99779289a9e9c2a4059a"
)
GGP_PROBE_BINDING_DOMAIN = (
    "0x4efb354b2a3c37f3c74fe57912e40eb08d83026611be9740d785f348cc2332c4"
)
STATE_EXPORT_PUBLISHER_INTERFACE = "IStreamStateExportPublisher"
STATE_EXPORT_PUBLISHER_ABI_SCHEMA = "6529stream.state-export-publisher-abi.v1"
STATE_EXPORT_PUBLISHER_INTERFACE_ID = "0x77faad4f"
STATE_EXPORT_LATEST_SELECTOR = STATE_EXPORT_PUBLISHER_INTERFACE_ID
STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID = "0xebf35615"
STATE_EXPORT_PUBLISHER_ABI_SHA256 = (
    "sha256:535217fe4e980b1c72bc1a24f0352a7704928a3cd25f4197bdff0604d7645ea7"
)
STATE_EXPORT_LATEST_RETURNS = (
    "uint256",
    "bytes32",
    "bytes32",
    "bytes32",
    "string",
)
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
    "StateExportPublished(uint16,uint256,bytes32,bytes32,bytes32,string)": (
        False,
        True,
        True,
        True,
        False,
        False,
    ),
    "StateExportChallenged(uint16,bytes32,bytes32,address,string)": (
        False,
        True,
        True,
        True,
        False,
    ),
    "StateExportSuperseded(uint16,bytes32,bytes32,bytes32,string)": (
        False,
        True,
        True,
        True,
        False,
    ),
}
STATE_EXPORT_PUBLISHER_MARKERS = (
    "STATE_EXPORT_PUBLISHER_EVENTS_V1",
    f"LATEST_STATE_EXPORT_SELECTOR_{STATE_EXPORT_LATEST_SELECTOR}",
    f"STATE_EXPORT_PUBLISHED_TOPIC_{STATE_EXPORT_EVENT_TOPICS['StateExportPublished(uint16,uint256,bytes32,bytes32,bytes32,string)']}",
    f"STATE_EXPORT_CHALLENGED_TOPIC_{STATE_EXPORT_EVENT_TOPICS['StateExportChallenged(uint16,bytes32,bytes32,address,string)']}",
    f"STATE_EXPORT_SUPERSEDED_TOPIC_{STATE_EXPORT_EVENT_TOPICS['StateExportSuperseded(uint16,bytes32,bytes32,bytes32,string)']}",
    f"STATE_EXPORT_PUBLISHER_ABI_SHA256_{STATE_EXPORT_PUBLISHER_ABI_SHA256.removeprefix('sha256:')}",
)

VECTOR_DERIVATION_DOMAIN = "6529STREAM_SYSTEM_MANIFEST_TARGET_VECTOR_V1"
MODULE_VERSION_LITERAL = "6529STREAM_MODULE_VERSION_V1"
TARGET_DEPLOYMENT_IDENTITY_SCOPE = (
    "one synthetic release-wide target-only digest reused by every "
    "deploymentManifestHash occurrence; not production deployment-identity evidence"
)
TARGET_IDENTITY_VIEW_RULE = (
    "derive_hash('deployment-identity-view-hash', raw genesis-profile SHA-256)"
)
TARGET_IDENTITY_OUTER_RULE = (
    "keccak256(abi.encode(STREAM_DEPLOYMENT_IDENTITY_V1, synthetic identity-view hash))"
)
UINT53_MAX = (1 << 53) - 1
KEY_RE = re.compile(r"^[A-Z][A-Z0-9_]*$")

PAYLOAD_TOP_LEVEL_KEYS = frozenset(
    {
        "schema",
        "schemaVersion",
        "chainId",
        "core",
        "systemManifest",
        "publicationRevision",
        "aggregate",
        "catalogs",
        "moduleRegistryManifest",
        "contracts",
        "pointers",
        "registryEntries",
        "gasParameterProbes",
        "criticalFallbacks",
        "securityContact",
    }
)

AGGREGATE_KEYS = (
    "revenueResolver",
    "metadataRouter",
    "collectionMetadata",
    "entropyCoordinator",
    "mintManager",
    "mintLedger",
    "artistRegistry",
    "streamAdminsOrGovernance",
    "artworkFinalityRegistry",
    "moduleRegistry",
    "stateExportPublisher",
)
CATALOG_KEYS = (
    "eventCatalogHash",
    "compatibilityMatrixHash",
    "numericIdCatalogHash",
    "schemaCatalogHash",
    "canonicalizationCatalogHash",
    "specBundleHash",
    "reconstructionClientHash",
)

POINTER_TARGETS = {
    "ROYALTY_RESOLVER": "REVENUE_RESOLVER",
    "METADATA_ROUTER": "METADATA_ROUTER",
    "COLLECTION_METADATA": "COLLECTION_METADATA",
    "ENTROPY_COORDINATOR": "ENTROPY_COORDINATOR",
    "MINT_MANAGER": "MINT_MANAGER",
    "MINT_LEDGER": "MINT_LEDGER",
    "ARTIST_REGISTRY": "ARTIST_REGISTRY",
    "ARTWORK_FINALITY_REGISTRY": "ARTWORK_FINALITY_REGISTRY",
    "MODULE_REGISTRY": "MODULE_REGISTRY",
    # Genesis binds the publisher to governance only because the profile
    # independently requires its exact publisher interface and event marker.
    "STATE_EXPORT_PUBLISHER": "GOVERNANCE_LAYER",
    "SYSTEM_MANIFEST": "STREAM_SYSTEM_MANIFEST",
}

AGGREGATE_TARGETS = {
    "revenueResolver": "REVENUE_RESOLVER",
    "metadataRouter": "METADATA_ROUTER",
    "collectionMetadata": "COLLECTION_METADATA",
    "entropyCoordinator": "ENTROPY_COORDINATOR",
    "mintManager": "MINT_MANAGER",
    "mintLedger": "MINT_LEDGER",
    "artistRegistry": "ARTIST_REGISTRY",
    "streamAdminsOrGovernance": "GOVERNANCE_LAYER",
    "artworkFinalityRegistry": "ARTWORK_FINALITY_REGISTRY",
    "moduleRegistry": "MODULE_REGISTRY",
    "stateExportPublisher": "GOVERNANCE_LAYER",
}

GGP_HOSTS: dict[str, tuple[str, ...]] = {
    "ROYALTY_RESOLVER_GAS_LIMIT": ("STREAM_CORE",),
    "ROYALTY_RETURN_GAS_BUFFER": ("STREAM_CORE",),
    "ERC_1271_GAS_LIMIT": ("SPLIT_FACTORY",),
    "ASSET_POLICY_GAS_LIMIT": ("SPLIT_FACTORY",),
    "WALLET_DEPOSIT_GAS_LIMIT": ("SPLIT_FACTORY",),
    "FLUSH_GAS_FLOOR": ("REVENUE_ESCROW",),
    "MINT_GATE_GAS_LIMIT": ("MINT_MANAGER",),
    "TICKET_ERC1271_GAS_LIMIT": ("MINT_TICKET_GATE",),
    "ARTIST_AUTHORITY_GAS_LIMIT": ("MINT_MANAGER",),
    "SALE_ERC1271_GAS_LIMIT": (
        "FIXED_PRICE_SALE_ADAPTER",
        "ENGLISH_AUCTION_HOUSE",
        "DUTCH_AUCTION_ADAPTER",
        "PRIVATE_SALE_ADAPTER",
    ),
    "DELEGATE_REGISTRY_GAS_LIMIT": ("DELEGATE_REGISTRY_GATE",),
    "SALE_ARTIST_AUTHORITY_GAS_LIMIT": (
        "FIXED_PRICE_SALE_ADAPTER",
        "ENGLISH_AUCTION_HOUSE",
        "DUTCH_AUCTION_ADAPTER",
        "PRIVATE_SALE_ADAPTER",
    ),
    "REVEAL_ATTEMPT_GAS_LIMIT": (
        "FIXED_PRICE_SALE_ADAPTER",
        "ENGLISH_AUCTION_HOUSE",
        "DUTCH_AUCTION_ADAPTER",
        "PRIVATE_SALE_ADAPTER",
    ),
    "SALE_NFT_DELIVERY_GAS_LIMIT": (
        "FIXED_PRICE_SALE_ADAPTER",
        "ENGLISH_AUCTION_HOUSE",
        "DUTCH_AUCTION_ADAPTER",
        "PRIVATE_SALE_ADAPTER",
    ),
    "METADATA_ROUTER_GAS_LIMIT": ("STREAM_CORE",),
    "ENTROPY_VIEW_GAS_LIMIT": ("METADATA_ROUTER",),
    "ENTROPY_REGISTRATION_GAS_LIMIT": ("STREAM_CORE",),
    "ENTROPY_RESULT_PROBE_GAS_LIMIT": ("ENTROPY_COORDINATOR",),
    "VRF_CALLBACK_GAS_LIMIT": (
        "ENTROPY_PROVIDER_VRF",
        "ENTROPY_PROVIDER_FALLBACK",
    ),
    "ARTIST_ERC1271_VERIFY_GAS": ("ARTIST_REGISTRY",),
    "METADATA_ERC1271_VERIFY_GAS": (
        "OWNER_RECORDS",
        "COLLECTION_ATTESTATIONS",
        "ARTIST_REGISTRY",
    ),
    "FINALITY_COMPONENT_READ_GAS": ("ARTWORK_FINALITY_REGISTRY",),
}

GTP_HOSTS: dict[str, tuple[str, ...]] = {
    "ENTROPY_REQUEST_TIMEOUT_BLOCKS": ("ENTROPY_COORDINATOR",),
    "ENTROPY_REVEAL_SLO_BLOCKS": ("ENTROPY_COORDINATOR",),
    "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS": ("ENTROPY_COORDINATOR",),
}


class ManifestVectorError(RuntimeError):
    """Raised when generation inputs or a derived vector are nonconformant."""


def keccak256(value: bytes) -> bytes:
    """Return Ethereum Keccak-256 without silently using NIST SHA3-256."""
    try:
        from eth_hash.auto import keccak

        return keccak(value)
    except ImportError:
        try:
            from Crypto.Hash import keccak as crypto_keccak
        except ImportError as exc:  # pragma: no cover - tool requirements provide one
            raise ManifestVectorError(
                "Keccak-256 requires eth-hash or pycryptodome"
            ) from exc
        digest = crypto_keccak.new(digest_bits=256)
        digest.update(value)
        return digest.digest()


def hex_keccak(value: bytes) -> str:
    return "0x" + keccak256(value).hex()


def sha256_prefixed(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def state_export_publisher_surface() -> dict[str, Any]:
    """Return the transparent, digest-locked active publisher ABI surface."""
    surface = {
        "schema": STATE_EXPORT_PUBLISHER_ABI_SCHEMA,
        "required_interface": STATE_EXPORT_PUBLISHER_INTERFACE,
        "interface_id": STATE_EXPORT_PUBLISHER_INTERFACE_ID,
        "functions": [
            {
                "signature": "latestStateExport()",
                "selector": STATE_EXPORT_LATEST_SELECTOR,
                "state_mutability": "view",
                "returns": list(STATE_EXPORT_LATEST_RETURNS),
            }
        ],
        "events": [
            {
                "signature": signature,
                "topic0": topic0,
                "anonymous": False,
                "indexed": list(STATE_EXPORT_EVENT_INDEXED_MASKS[signature]),
            }
            for signature, topic0 in STATE_EXPORT_EVENT_TOPICS.items()
        ],
    }
    canonical = json.dumps(
        surface,
        ensure_ascii=True,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("ascii")
    digest = sha256_prefixed(canonical)
    if digest != STATE_EXPORT_PUBLISHER_ABI_SHA256:
        raise ManifestVectorError(
            "reviewed state-export publisher ABI constants disagree with their fixed digest"
        )
    return {**surface, "surface_sha256": digest}


def require_exact_keys(value: dict[str, Any], expected: Iterable[str], path: str) -> None:
    expected_set = set(expected)
    actual = set(value)
    if actual != expected_set:
        missing = sorted(expected_set - actual)
        extra = sorted(actual - expected_set)
        raise ManifestVectorError(f"{path} keys drifted; missing={missing}, extra={extra}")


def reject_duplicate_pairs(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise ManifestVectorError(f"duplicate JSON object member: {key}")
        result[key] = value
    return result


def load_json_strict(path: Path) -> tuple[Any, bytes]:
    try:
        raw = path.read_bytes()
    except FileNotFoundError as exc:
        raise ManifestVectorError(f"missing required file: {path}") from exc
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise ManifestVectorError(f"{path} is not valid UTF-8: {exc}") from exc
    try:
        value = json.loads(
            text,
            object_pairs_hook=reject_duplicate_pairs,
            parse_constant=lambda token: (_ for _ in ()).throw(
                ManifestVectorError(f"non-I-JSON number token: {token}")
            ),
        )
    except json.JSONDecodeError as exc:
        raise ManifestVectorError(f"invalid JSON in {path}: {exc}") from exc
    return value, raw


def _validate_ijson_string(value: str, path: str) -> None:
    for char in value:
        point = ord(char)
        if 0xD800 <= point <= 0xDFFF:
            raise ManifestVectorError(f"{path} contains a lone UTF-16 surrogate")
    if unicodedata.normalize("NFC", value) != value:
        raise ManifestVectorError(f"{path} is not NFC-normalized")
    try:
        value.encode("utf-8", "strict")
    except UnicodeEncodeError as exc:
        raise ManifestVectorError(f"{path} is not valid Unicode: {exc}") from exc


def _jcs_quote(value: str, path: str) -> str:
    _validate_ijson_string(value, path)
    escaped: list[str] = ['"']
    short = {
        0x08: "\\b",
        0x09: "\\t",
        0x0A: "\\n",
        0x0C: "\\f",
        0x0D: "\\r",
    }
    for char in value:
        point = ord(char)
        if char == '"':
            escaped.append('\\"')
        elif char == "\\":
            escaped.append("\\\\")
        elif point in short:
            escaped.append(short[point])
        elif point <= 0x1F:
            escaped.append(f"\\u{point:04x}")
        else:
            escaped.append(char)
    escaped.append('"')
    return "".join(escaped)


def _utf16_sort_key(value: str) -> bytes:
    _validate_ijson_string(value, "object member name")
    return value.encode("utf-16-be")


def jcs_text(value: Any, path: str = "$") -> str:
    """Canonicalize the payload's pinned RFC8785/I-JSON value subset.

    The normative payload schema forbids null and floating-point values.  Its
    JSON numbers are nonnegative safe integers; larger protocol integers are
    decimal strings.  Keeping that restriction here avoids implementation-
    dependent IEEE-754 serialization while remaining exact for the schema.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        if value < 0 or value > UINT53_MAX:
            raise ManifestVectorError(f"{path} is outside the I-JSON safe-integer range")
        return str(value)
    if isinstance(value, str):
        return _jcs_quote(value, path)
    if isinstance(value, list):
        return "[" + ",".join(jcs_text(item, f"{path}[{index}]") for index, item in enumerate(value)) + "]"
    if isinstance(value, dict):
        for key in value:
            if not isinstance(key, str):
                raise ManifestVectorError(f"{path} contains a non-string object name")
            _validate_ijson_string(key, f"{path} member name")
        names = sorted(value, key=_utf16_sort_key)
        return "{" + ",".join(
            _jcs_quote(name, f"{path} member name")
            + ":"
            + jcs_text(value[name], f"{path}.{name}")
            for name in names
        ) + "}"
    if value is None:
        raise ManifestVectorError(f"{path} contains forbidden null")
    if isinstance(value, float):
        raise ManifestVectorError(f"{path} contains forbidden floating-point JSON")
    raise ManifestVectorError(f"{path} has unsupported JSON type {type(value).__name__}")


def jcs_bytes(value: Any) -> bytes:
    return jcs_text(value).encode("utf-8")


def _hex_bytes(value: str, length: int, path: str) -> bytes:
    if not isinstance(value, str) or not value.startswith("0x"):
        raise ManifestVectorError(f"{path} must be 0x-prefixed hex")
    try:
        decoded = bytes.fromhex(value[2:])
    except ValueError as exc:
        raise ManifestVectorError(f"{path} is malformed hex") from exc
    if len(decoded) != length or value != "0x" + decoded.hex():
        raise ManifestVectorError(f"{path} must be lowercase fixed-width {length}-byte hex")
    return decoded


def _uint_word(value: int, bits: int, path: str) -> bytes:
    if isinstance(value, bool) or not isinstance(value, int):
        raise ManifestVectorError(f"{path} must be an integer")
    if value < 0 or value >= 1 << bits:
        raise ManifestVectorError(f"{path} does not fit uint{bits}")
    return value.to_bytes(32, "big")


def _address_word(value: str, path: str) -> bytes:
    return b"\x00" * 12 + _hex_bytes(value, 20, path)


def _bytes4_word(value: str, path: str) -> bytes:
    return _hex_bytes(value, 4, path) + b"\x00" * 28


def _bytes32_word(value: str, path: str) -> bytes:
    return _hex_bytes(value, 32, path)


def abi_encode_static(fields: Sequence[tuple[str, Any]]) -> bytes:
    words: list[bytes] = []
    for index, (kind, value) in enumerate(fields):
        path = f"abi field {index} ({kind})"
        if kind == "bytes32":
            words.append(_bytes32_word(value, path))
        elif kind == "address":
            words.append(_address_word(value, path))
        elif kind == "bytes4":
            words.append(_bytes4_word(value, path))
        elif kind.startswith("uint"):
            words.append(_uint_word(value, int(kind[4:]), path))
        elif kind == "bool":
            if not isinstance(value, bool):
                raise ManifestVectorError(f"{path} must be boolean")
            words.append(_uint_word(int(value), 8, path))
        else:
            raise ManifestVectorError(f"unsupported ABI kind: {kind}")
    return b"".join(words)


def abi_encode_bytes32_array_prefix(
    prefix_fields: Sequence[tuple[str, Any]], values: Sequence[str]
) -> bytes:
    offset = 32 * (len(prefix_fields) + 1)
    head = abi_encode_static((*prefix_fields, ("uint256", offset)))
    tail = _uint_word(len(values), 256, "dynamic bytes32 array length")
    tail += b"".join(_bytes32_word(value, "dynamic bytes32 value") for value in values)
    return head + tail


def encode_root_descriptor(chunks: Sequence[dict[str, Any]], total_bytes: int) -> bytes:
    count = len(chunks)
    if count < 1 or count > MAX_MANIFEST_CHUNKS:
        raise ManifestVectorError("root descriptor chunk count is outside 1..32")
    head = abi_encode_static(
        (
            ("bytes4", ROOT_DESCRIPTOR_MAGIC),
            ("uint16", SCHEMA_VERSION),
            ("bytes32", PAYLOAD_SCHEMA_ID),
            ("bytes32", CANONICALIZATION_ID),
            ("uint32", total_bytes),
            ("uint16", count),
            ("uint256", ROOT_DESCRIPTOR_DYNAMIC_OFFSET),
        )
    )
    tail = _uint_word(count, 256, "root descriptor array length")
    for index, chunk in enumerate(chunks):
        tail += abi_encode_static(
            (
                ("address", chunk["pointer"]),
                ("uint32", chunk["payload_length"]),
                ("bytes32", chunk["payload_hash"]),
            )
        )
    encoded = head + tail
    expected_length = 256 + 96 * count
    if len(encoded) != expected_length or len(encoded) > MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES:
        raise ManifestVectorError("root descriptor length violates its exact bound")
    return encoded


def _decode_uint_word(word: bytes, bits: int, path: str) -> int:
    if len(word) != 32:
        raise ManifestVectorError(f"{path} is not one ABI word")
    value = int.from_bytes(word, "big")
    if value >= 1 << bits:
        raise ManifestVectorError(f"{path} has nonzero uint{bits} high padding")
    return value


def decode_root_descriptor(encoded: bytes) -> dict[str, Any]:
    """Strictly decode and canonical-reencode the bounded root descriptor."""
    if len(encoded) < 256 or len(encoded) > MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES:
        raise ManifestVectorError("root descriptor code length is outside bounds")
    if len(encoded) % 32:
        raise ManifestVectorError("root descriptor length is not word aligned")
    words = [encoded[index : index + 32] for index in range(0, len(encoded), 32)]
    if words[0][4:] != b"\x00" * 28:
        raise ManifestVectorError("root descriptor bytes4 padding is noncanonical")
    magic = "0x" + words[0][:4].hex()
    schema_version = _decode_uint_word(words[1], 16, "schema version")
    schema_id = "0x" + words[2].hex()
    canonicalization_id = "0x" + words[3].hex()
    total_bytes = _decode_uint_word(words[4], 32, "total bytes")
    declared_count = _decode_uint_word(words[5], 16, "declared chunk count")
    offset = _decode_uint_word(words[6], 256, "chunk array offset")
    if offset != ROOT_DESCRIPTOR_DYNAMIC_OFFSET:
        raise ManifestVectorError("root descriptor dynamic offset is not exactly 224")
    if magic != ROOT_DESCRIPTOR_MAGIC:
        raise ManifestVectorError("root descriptor magic drifted")
    if schema_version != SCHEMA_VERSION:
        raise ManifestVectorError("root descriptor schema version drifted")
    if schema_id != PAYLOAD_SCHEMA_ID or canonicalization_id != CANONICALIZATION_ID:
        raise ManifestVectorError("root descriptor schema/canonicalization ID drifted")
    if len(words) < 8:
        raise ManifestVectorError("root descriptor omits its array length")
    count = _decode_uint_word(words[7], 256, "chunk array length")
    if count != declared_count or count < 1 or count > MAX_MANIFEST_CHUNKS:
        raise ManifestVectorError("root descriptor count fields disagree or exceed bounds")
    expected_length = 256 + 96 * count
    if len(encoded) != expected_length:
        raise ManifestVectorError("root descriptor has truncation or trailing bytes")
    chunks: list[dict[str, Any]] = []
    cursor = 8
    for index in range(count):
        address_word = words[cursor]
        if address_word[:12] != b"\x00" * 12:
            raise ManifestVectorError(f"chunk {index} address padding is noncanonical")
        pointer = "0x" + address_word[12:].hex()
        payload_length = _decode_uint_word(words[cursor + 1], 32, f"chunk {index} length")
        payload_hash = "0x" + words[cursor + 2].hex()
        chunks.append(
            {
                "pointer": pointer,
                "payload_length": payload_length,
                "payload_hash": payload_hash,
            }
        )
        cursor += 3
    decoded = {
        "magic": magic,
        "schema_version": schema_version,
        "schema_id": schema_id,
        "canonicalization_id": canonicalization_id,
        "total_bytes": total_bytes,
        "chunk_count": count,
        "chunks": chunks,
    }
    if encode_root_descriptor(chunks, total_bytes) != encoded:
        raise ManifestVectorError("root descriptor is ABI-decodable but malleable")
    return decoded


def _derivation_preimage(label: str, *parts: object) -> bytes:
    fields = [VECTOR_DERIVATION_DOMAIN, label, *(str(part) for part in parts)]
    return "|".join(fields).encode("utf-8")


def derive_hash(label: str, *parts: object) -> str:
    return hex_keccak(_derivation_preimage(label, *parts))


def derive_address(label: str, *parts: object) -> str:
    return "0x" + keccak256(_derivation_preimage(label, *parts))[-20:].hex()


def derive_selector(label: str, *parts: object) -> str:
    return "0x" + keccak256(_derivation_preimage(label, *parts))[:4].hex()


def derive_target_identity_view_hash(profile_sha256: str) -> str:
    """Derive the synthetic target-only identity-view hash from profile bytes."""

    return derive_hash("deployment-identity-view-hash", profile_sha256)


def derive_target_deployment_identity_hash(profile_sha256: str) -> str:
    """Apply the production outer domain to the synthetic target identity view."""

    return hex_keccak(
        abi_encode_static(
            (
                ("bytes32", DEPLOYMENT_IDENTITY_DOMAIN),
                ("bytes32", derive_target_identity_view_hash(profile_sha256)),
            )
        )
    )


def _require_profile(profile: Any) -> list[dict[str, Any]]:
    if not isinstance(profile, dict):
        raise ManifestVectorError("genesis profile must be an object")
    if profile.get("schema_version") != PROFILE_SCHEMA:
        raise ManifestVectorError("genesis profile schema version drifted")
    if profile.get("chain_id") != CHAIN_ID:
        raise ManifestVectorError("genesis profile must target chain ID 1")
    entries = profile.get("entries")
    if not isinstance(entries, list) or len(entries) != EXPECTED_PROFILE_ENTRIES:
        raise ManifestVectorError(
            f"genesis profile must contain exactly {EXPECTED_PROFILE_ENTRIES} entries"
        )
    expected_ids = list(range(1, EXPECTED_PROFILE_ENTRIES + 1))
    actual_ids: list[int] = []
    keys: list[str] = []
    for index, raw_entry in enumerate(entries):
        if not isinstance(raw_entry, dict):
            raise ManifestVectorError(f"profile.entries[{index}] must be an object")
        entry_id = raw_entry.get("id")
        key = raw_entry.get("key")
        if isinstance(entry_id, bool) or not isinstance(entry_id, int):
            raise ManifestVectorError(f"profile.entries[{index}].id must be an integer")
        if not isinstance(key, str) or not KEY_RE.fullmatch(key):
            raise ManifestVectorError(f"profile.entries[{index}].key is not canonical")
        actual_ids.append(entry_id)
        keys.append(key)
    if actual_ids != expected_ids:
        raise ManifestVectorError(
            "profile entry IDs must be the exact contiguous "
            f"1..{EXPECTED_PROFILE_ENTRIES} walk"
        )
    if len(set(keys)) != len(keys):
        raise ManifestVectorError("profile entry keys must be unique")
    required = set(POINTER_TARGETS.values()) | set(AGGREGATE_TARGETS.values())
    missing = sorted(required - set(keys))
    if missing:
        raise ManifestVectorError(f"profile is missing target-vector entries: {missing}")
    governance = entries[keys.index("GOVERNANCE_LAYER")]
    governance_interfaces = governance.get("required_interfaces")
    governance_markers = governance.get("required_markers")
    if (
        not isinstance(governance_interfaces, list)
        or STATE_EXPORT_PUBLISHER_INTERFACE not in governance_interfaces
        or not isinstance(governance_markers, list)
        or not set(STATE_EXPORT_PUBLISHER_MARKERS).issubset(governance_markers)
    ):
        raise ManifestVectorError(
            "GOVERNANCE_LAYER must prove the state-export publisher interface "
            "and event marker before serving STATE_EXPORT_PUBLISHER"
        )
    return entries


def _module_type(entry: dict[str, Any]) -> str:
    if entry["key"] == "STREAM_SYSTEM_MANIFEST":
        return hex_keccak(b"STREAM_SYSTEM_MANIFEST")
    if entry.get("kind") == "ggp_probe":
        return hex_keccak(b"STREAM_GGP_PROBE")
    if entry.get("kind") == "gtp_probe":
        return hex_keccak(b"STREAM_GTP_PROBE")
    return hex_keccak(entry["key"].encode("ascii"))


def _interface_id(entry: dict[str, Any]) -> str:
    if entry["key"] == "STREAM_SYSTEM_MANIFEST":
        return "0x37660ede"
    if entry["key"] == "STREAM_CORE_FINALITY_ADAPTER":
        return STREAM_CORE_FINALITY_ADAPTER_INTERFACE_ID
    if entry["key"] == "GOVERNANCE_LAYER":
        # Events do not contribute to ERC-165; the one-function publisher
        # interface ID is therefore latestStateExport()'s selector.
        return STATE_EXPORT_PUBLISHER_INTERFACE_ID
    if entry.get("kind") == "ggp_probe":
        return "0x0f8c6b0f"
    if entry.get("kind") == "gtp_probe":
        # IStreamTimeParameterProbe: lastProbeRun(bytes32,uint256) XOR
        # pinnedWallClockFloorSeconds(bytes32).
        return "0xb6c57592"
    interfaces = entry.get("required_interfaces")
    if not isinstance(interfaces, list) or not all(isinstance(item, str) for item in interfaces):
        raise ManifestVectorError(f"{entry['key']} required_interfaces must be strings")
    preimage = ",".join(interfaces)
    return derive_selector("interface-id", entry["id"], entry["key"], preimage)


def _entry_facts(
    entries: Sequence[dict[str, Any]], deployment_identity_hash: str
) -> dict[str, dict[str, Any]]:
    facts: dict[str, dict[str, Any]] = {}
    module_version = hex_keccak(MODULE_VERSION_LITERAL.encode("ascii"))
    for entry in entries:
        entry_hash = hex_keccak(jcs_bytes(entry))
        identity = (entry["id"], entry["key"], entry_hash)
        facts[entry["key"]] = {
            "id": entry["id"],
            "key": entry["key"],
            "kind": entry.get("kind"),
            "entry_hash": entry_hash,
            "address": derive_address("contract-address", entry["id"], entry["key"]),
            "runtime_code_hash": derive_hash("runtime-code-hash", *identity),
            "create2_salt": derive_hash("create2-salt", *identity),
            "init_code_hash": derive_hash("init-code-hash", *identity),
            "deployment_manifest_hash": deployment_identity_hash,
            "module_manifest_hash": derive_hash("module-manifest-hash", *identity),
            "module_type": _module_type(entry),
            "module_version": module_version,
            "interface_id": _interface_id(entry),
            "parameters": tuple(entry.get("parameters", [])),
        }
    return facts


def _contract_records(
    entries: Sequence[dict[str, Any]], facts: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    return [
        {
            "inventoryId": entry["id"],
            "key": entry["key"],
            "address": facts[entry["key"]]["address"],
            "runtimeCodeHash": facts[entry["key"]]["runtime_code_hash"],
            "create2Salt": facts[entry["key"]]["create2_salt"],
            "initCodeHash": facts[entry["key"]]["init_code_hash"],
            "deploymentManifestHash": facts[entry["key"]][
                "deployment_manifest_hash"
            ],
        }
        for entry in entries
    ]


def _registry_entries(
    entries: Sequence[dict[str, Any]], facts: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    registry = facts["MODULE_REGISTRY"]["address"]
    result: list[dict[str, Any]] = []
    for index, entry in enumerate(entries):
        item = facts[entry["key"]]
        result.append(
            {
                "registry": registry,
                "enumerationIndex": index,
                "module": item["address"],
                "status": 1,
                "moduleType": item["module_type"],
                "moduleVersion": item["module_version"],
                "interfaceId": item["interface_id"],
                "moduleGasLimit": "0",
                "runtimeCodeHash": item["runtime_code_hash"],
                "deploymentManifestHash": item["deployment_manifest_hash"],
                "moduleManifestHash": item["module_manifest_hash"],
                "moduleManifestURI": (
                    "ipfs://target-abi-lock-fixture/module/"
                    + item["module_manifest_hash"][2:]
                ),
                "revision": "1",
            }
        )
    return result


def _pointers(facts: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    registry = facts["MODULE_REGISTRY"]["address"]
    result: list[dict[str, Any]] = []
    for pointer_name, target_key in POINTER_TARGETS.items():
        target = facts[target_key]
        result.append(
            {
                "pointerType": hex_keccak(pointer_name.encode("ascii")),
                "target": target["address"],
                "codeHash": target["runtime_code_hash"],
                "frozen": pointer_name == "SYSTEM_MANIFEST",
                "moduleType": target["module_type"],
                "interfaceId": target["interface_id"],
                "registry": registry,
                "registryStatus": 1,
                "moduleManifestHash": target["module_manifest_hash"],
                "deploymentManifestHash": target["deployment_manifest_hash"],
                "revision": "1",
            }
        )
    return sorted(result, key=lambda item: item["pointerType"])


def _parameter_id(kind: str, name: str) -> str:
    prefix = "6529STREAM_GGP_" if kind == "ggp_probe" else "6529STREAM_GTP_"
    return hex_keccak((prefix + name).encode("ascii"))


def _probe_binding_hash(
    registry: str,
    probe: str,
    module_type: str,
    interface_id: str,
    module_version: str,
    runtime_code_hash: str,
    module_manifest_hash: str,
    deployment_manifest_hash: str,
) -> str:
    encoded = abi_encode_static(
        (
            ("bytes32", GGP_PROBE_BINDING_DOMAIN),
            ("address", registry),
            ("address", probe),
            ("bytes32", module_type),
            ("bytes4", interface_id),
            ("bytes32", module_version),
            ("bytes32", runtime_code_hash),
            ("bytes32", module_manifest_hash),
            ("bytes32", deployment_manifest_hash),
        )
    )
    return hex_keccak(encoded)


def _gas_parameter_probes(
    entries: Sequence[dict[str, Any]], facts: dict[str, dict[str, Any]]
) -> list[dict[str, Any]]:
    registry = facts["MODULE_REGISTRY"]["address"]
    rows: list[dict[str, Any]] = []
    seen_parameters: set[str] = set()
    for entry in entries:
        kind = entry.get("kind")
        if kind not in {"ggp_probe", "gtp_probe"}:
            continue
        probe = facts[entry["key"]]
        host_map = GGP_HOSTS if kind == "ggp_probe" else GTP_HOSTS
        parameters = entry.get("parameters")
        if not isinstance(parameters, list) or not parameters:
            raise ManifestVectorError(f"{entry['key']} must bind at least one parameter")
        for parameter in parameters:
            if parameter not in host_map:
                raise ManifestVectorError(f"no fixture host mapping for {parameter}")
            seen_parameters.add(parameter)
            parameter_id = _parameter_id(kind, parameter)
            for host_key in host_map[parameter]:
                binding_hash = _probe_binding_hash(
                    registry,
                    probe["address"],
                    probe["module_type"],
                    probe["interface_id"],
                    probe["module_version"],
                    probe["runtime_code_hash"],
                    probe["module_manifest_hash"],
                    probe["deployment_manifest_hash"],
                )
                rows.append(
                    {
                        "host": facts[host_key]["address"],
                        "parameterId": parameter_id,
                        "probe": probe["address"],
                        "probeRegistry": registry,
                        "probeModuleType": probe["module_type"],
                        "probeInterfaceId": probe["interface_id"],
                        "probeModuleVersion": probe["module_version"],
                        "probeRuntimeCodeHash": probe["runtime_code_hash"],
                        "probeModuleManifestHash": probe["module_manifest_hash"],
                        "probeDeploymentManifestHash": probe[
                            "deployment_manifest_hash"
                        ],
                        "probeBindingHash": binding_hash,
                        "probeMaxAgeBlocks": "7200",
                    }
                )
    expected = set(GGP_HOSTS) | set(GTP_HOSTS)
    if seen_parameters != expected:
        raise ManifestVectorError(
            "profile probe parameters drifted; "
            f"missing={sorted(expected - seen_parameters)}, "
            f"extra={sorted(seen_parameters - expected)}"
        )
    return sorted(rows, key=lambda row: (row["host"], row["parameterId"]))


def _critical_fallbacks(facts: dict[str, dict[str, Any]]) -> list[dict[str, Any]]:
    registry = facts["MODULE_REGISTRY"]["address"]
    pairs = (
        ("ENTROPY_COORDINATOR", "ENTROPY_COORDINATOR_FALLBACK"),
        ("MINT_MANAGER", "MINT_MANAGER_FALLBACK"),
    )
    rows: list[dict[str, Any]] = []
    for pointer_name, key in pairs:
        target = facts[key]
        rows.append(
            {
                "pointerType": hex_keccak(pointer_name.encode("ascii")),
                "target": target["address"],
                "runtimeCodeHash": target["runtime_code_hash"],
                "moduleType": target["module_type"],
                "interfaceId": target["interface_id"],
                "registry": registry,
                "moduleManifestHash": target["module_manifest_hash"],
                "deploymentManifestHash": target["deployment_manifest_hash"],
            }
        )
    return sorted(rows, key=lambda row: (row["pointerType"], row["target"]))


def build_payload(
    profile: dict[str, Any], profile_sha256: str
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    entries = _require_profile(profile)
    deployment_identity_hash = derive_target_deployment_identity_hash(profile_sha256)
    facts = _entry_facts(entries, deployment_identity_hash)
    catalogs = {
        key: derive_hash("catalog-hash", key, profile_sha256) for key in CATALOG_KEYS
    }
    aggregate = {key: facts[target]["address"] for key, target in AGGREGATE_TARGETS.items()}
    gas_rows = _gas_parameter_probes(entries, facts)
    payload = {
        "schema": PAYLOAD_SCHEMA_LITERAL,
        "schemaVersion": SCHEMA_VERSION,
        "chainId": str(CHAIN_ID),
        "core": facts["STREAM_CORE"]["address"],
        "systemManifest": facts["STREAM_SYSTEM_MANIFEST"]["address"],
        "publicationRevision": "1",
        "aggregate": aggregate,
        "catalogs": catalogs,
        "moduleRegistryManifest": {
            "hash": derive_hash("module-registry-manifest-hash", profile_sha256),
            "uri": "ipfs://target-abi-lock-fixture/module-registry",
            "revision": "1",
        },
        "contracts": _contract_records(entries, facts),
        "pointers": _pointers(facts),
        "registryEntries": _registry_entries(entries, facts),
        "gasParameterProbes": gas_rows,
        "criticalFallbacks": _critical_fallbacks(facts),
        "securityContact": {
            "policyHash": derive_hash("security-policy-hash", profile_sha256),
            "uri": "ipfs://target-abi-lock-fixture/security-policy",
        },
    }
    return payload, facts


def split_payload(canonical: bytes) -> list[bytes]:
    total = len(canonical)
    if total < 1 or total > MAX_MANIFEST_PAYLOAD_BYTES:
        raise ManifestVectorError("canonical payload length is outside 1..786400")
    segments = [
        canonical[offset : offset + CHUNK_PAYLOAD_BYTES]
        for offset in range(0, total, CHUNK_PAYLOAD_BYTES)
    ]
    if len(segments) < 1 or len(segments) > MAX_MANIFEST_CHUNKS:
        raise ManifestVectorError("canonical payload requires more than 32 chunks")
    for index, segment in enumerate(segments):
        if index < len(segments) - 1 and len(segment) != CHUNK_PAYLOAD_BYTES:
            raise ManifestVectorError("a non-final manifest chunk is not exactly 24575 bytes")
        if index == len(segments) - 1 and not 1 <= len(segment) <= CHUNK_PAYLOAD_BYTES:
            raise ManifestVectorError("the final manifest chunk length is invalid")
    return segments


def _chunk_records(segments: Sequence[bytes]) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, segment in enumerate(segments):
        payload_hash = hex_keccak(segment)
        pointer = derive_address("sstore2-chunk-pointer", index, payload_hash)
        leaf_hash = hex_keccak(
            abi_encode_static(
                (
                    ("bytes32", PAYLOAD_LEAF_DOMAIN),
                    ("uint256", index),
                    ("uint32", len(segment)),
                    ("bytes32", payload_hash),
                )
            )
        )
        rows.append(
            {
                "index": index,
                "pointer": pointer,
                "payload_length": len(segment),
                "segment_hex": "0x" + segment.hex(),
                "payload_hash": payload_hash,
                "leaf_hash": leaf_hash,
                "runtime_code_hash": hex_keccak(b"\x00" + segment),
            }
        )
    return rows


def _chunk_list_hash(total_bytes: int, leaf_hashes: Sequence[str]) -> str:
    encoded = abi_encode_bytes32_array_prefix(
        (("bytes32", PAYLOAD_LIST_DOMAIN), ("uint32", total_bytes)), leaf_hashes
    )
    return hex_keccak(encoded)


def _payload_root_hash(total_bytes: int, chunk_count: int, list_hash: str) -> str:
    return hex_keccak(
        abi_encode_static(
            (
                ("bytes32", PAYLOAD_ROOT_DOMAIN),
                ("uint16", SCHEMA_VERSION),
                ("bytes32", PAYLOAD_SCHEMA_ID),
                ("bytes32", CANONICALIZATION_ID),
                ("uint32", total_bytes),
                ("uint16", chunk_count),
                ("bytes32", list_hash),
            )
        )
    )


def build_vector(profile: dict[str, Any], profile_raw: bytes) -> dict[str, Any]:
    profile_sha256 = sha256_prefixed(profile_raw)
    identity_view_hash = derive_target_identity_view_hash(profile_sha256)
    deployment_identity_hash = derive_target_deployment_identity_hash(profile_sha256)
    payload, facts = build_payload(profile, profile_sha256)
    canonical = jcs_bytes(payload)
    segments = split_payload(canonical)
    chunks = _chunk_records(segments)
    leaf_hashes = [chunk["leaf_hash"] for chunk in chunks]
    list_hash = _chunk_list_hash(len(canonical), leaf_hashes)
    root_hash = _payload_root_hash(len(canonical), len(chunks), list_hash)
    descriptor_chunks = [
        {
            "pointer": chunk["pointer"],
            "payload_length": chunk["payload_length"],
            "payload_hash": chunk["payload_hash"],
        }
        for chunk in chunks
    ]
    descriptor = encode_root_descriptor(descriptor_chunks, len(canonical))
    decoded = decode_root_descriptor(descriptor)
    if decoded["chunks"] != descriptor_chunks:
        raise ManifestVectorError("root descriptor semantic round trip failed")
    contracts = payload["contracts"]
    return {
        "schema_version": VECTOR_SCHEMA,
        "evidence_class": EVIDENCE_CLASS,
        "production_candidate": False,
        "readiness_evidence": False,
        "blocker": {
            "issue": BLOCKER_ISSUE,
            "reason": (
                f"The {len(contracts)}-entry genesis profile is a planning inventory without "
                "deployed addresses, code hashes, or live state enumerations; an "
                "instance-aware candidate must replace this fixture before "
                "deployment-semantic reconciliation."
            ),
        },
        "source": {
            "genesis_deployment_profile": DEFAULT_PROFILE.as_posix(),
            "genesis_deployment_profile_sha256": profile_sha256,
            "profile_schema_version": PROFILE_SCHEMA,
            "profile_entry_count": len(contracts),
            "normative_anchor": "docs/stream-long-term-architecture.md#LTA-MANIFEST",
        },
        "fixture_derivation": {
            "domain": VECTOR_DERIVATION_DOMAIN,
            "preimage_format": "UTF8(join('|', [domain, label, *parts]))",
            "hash_rule": "keccak256(UTF8(preimage))",
            "address_rule": "low_20_bytes(keccak256(UTF8(preimage)))",
            "selector_rule": "high_4_bytes(keccak256(UTF8(preimage)))",
            "contract_address_parts": ["decimal inventoryId", "profile key"],
            "per_contract_hash_parts": [
                "decimal inventoryId",
                "profile key",
                "keccak256(JCS(profile entry))",
            ],
            "deployment_identity": {
                "scope": TARGET_DEPLOYMENT_IDENTITY_SCOPE,
                "identity_view_rule": TARGET_IDENTITY_VIEW_RULE,
                "outer_rule": TARGET_IDENTITY_OUTER_RULE,
                "domain": DEPLOYMENT_IDENTITY_DOMAIN,
                "identity_view_hash": identity_view_hash,
                "hash": deployment_identity_hash,
            },
            "chunk_pointer_parts": ["zero-based chunk index", "segment keccak256"],
            "catalog_hash_parts": [
                "catalog field name",
                "raw genesis-profile SHA-256",
            ],
            "probe_interface_ids": {
                "IStreamGasParameterProbe": "0x0f8c6b0f",
                "IStreamTimeParameterProbe": "0xb6c57592",
            },
            "sstore2_carrier_policy": (
                "root and chunk carriers are excluded from payload.contracts "
                "to avoid a self-address fixed point"
            ),
            "state_export_publisher_binding": "GOVERNANCE_LAYER",
            "state_export_publisher_surface": state_export_publisher_surface(),
        },
        "constants": {
            "schema_version": SCHEMA_VERSION,
            "payload_schema_literal": PAYLOAD_SCHEMA_LITERAL,
            "payload_schema_id": PAYLOAD_SCHEMA_ID,
            "canonicalization_literal": CANONICALIZATION_LITERAL,
            "canonicalization_id": CANONICALIZATION_ID,
            "chunk_payload_bytes": CHUNK_PAYLOAD_BYTES,
            "max_manifest_chunks": MAX_MANIFEST_CHUNKS,
            "max_manifest_payload_bytes": MAX_MANIFEST_PAYLOAD_BYTES,
            "max_root_descriptor_bytes": MAX_MANIFEST_ROOT_DESCRIPTOR_BYTES,
            "root_descriptor_magic": ROOT_DESCRIPTOR_MAGIC,
            "root_descriptor_dynamic_offset": ROOT_DESCRIPTOR_DYNAMIC_OFFSET,
            "payload_leaf_domain": PAYLOAD_LEAF_DOMAIN,
            "payload_list_domain": PAYLOAD_LIST_DOMAIN,
            "payload_root_domain": PAYLOAD_ROOT_DOMAIN,
            "deployment_identity_domain": DEPLOYMENT_IDENTITY_DOMAIN,
        },
        "payload": payload,
        "canonical_payload": {
            "canonicalization": CANONICALIZATION_LITERAL,
            "utf8_hex": "0x" + canonical.hex(),
            "byte_length": len(canonical),
            "keccak256": hex_keccak(canonical),
            "sha256": sha256_prefixed(canonical),
        },
        "chunks": chunks,
        "commitments": {
            "ordered_leaf_hashes": leaf_hashes,
            "chunk_list_hash": list_hash,
            "payload_root_hash": root_hash,
            "manifest_hash": root_hash,
        },
        "root_descriptor": {
            "magic": ROOT_DESCRIPTOR_MAGIC,
            "schema_version": SCHEMA_VERSION,
            "schema_id": PAYLOAD_SCHEMA_ID,
            "canonicalization_id": CANONICALIZATION_ID,
            "total_bytes": len(canonical),
            "chunk_count": len(chunks),
            "dynamic_offset": ROOT_DESCRIPTOR_DYNAMIC_OFFSET,
            "chunks": descriptor_chunks,
            "encoded_length": len(descriptor),
            "encoded_hex": "0x" + descriptor.hex(),
            "keccak256": hex_keccak(descriptor),
            "runtime_code_hash": hex_keccak(b"\x00" + descriptor),
        },
        "semantic_round_trip": {
            "profile_entry_ids": [record["inventoryId"] for record in contracts],
            "profile_keys": [record["key"] for record in contracts],
            "contract_address_by_key": {
                record["key"]: record["address"] for record in contracts
            },
            "aggregate": payload["aggregate"],
            "catalogs": payload["catalogs"],
            "deployment_manifest_hash": deployment_identity_hash,
            "contract_count": len(contracts),
            "pointer_count": len(payload["pointers"]),
            "registry_entry_count": len(payload["registryEntries"]),
            "gas_parameter_probe_binding_count": len(payload["gasParameterProbes"]),
            "critical_fallback_count": len(payload["criticalFallbacks"]),
            "all_profile_entry_addresses": [
                facts[record["key"]]["address"] for record in contracts
            ],
        },
    }


def render_vector(vector: dict[str, Any]) -> str:
    return json.dumps(vector, indent=2, ensure_ascii=False) + "\n"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--profile", type=Path, default=DEFAULT_PROFILE)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        profile, profile_raw = load_json_strict(args.profile)
        vector = build_vector(profile, profile_raw)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(render_vector(vector), encoding="utf-8", newline="\n")
    except (ManifestVectorError, OSError) as exc:
        print(f"system manifest payload vector generation failed: {exc}", file=sys.stderr)
        return 1
    print(
        "generated target-only system manifest payload vector: "
        f"{args.output} ({vector['canonical_payload']['byte_length']} bytes, "
        f"{len(vector['chunks'])} chunks)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
