#!/usr/bin/env python3
"""Validate drop authorization signing docs and deterministic fixtures."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = "6529stream.drop-authorization-fixture.v1"
DEFAULT_GUIDE = Path("docs/drop-authorization-signing.md")
DEFAULT_FIXTURE_DIR = Path("test/fixtures/drop-authorization")

EIP712_NAME = "6529StreamDrops"
EIP712_VERSION = "1"
EIP712_DOMAIN_TYPE = (
    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
)
DROP_ID_TYPE = "DropId(address signer,uint256 signerEpoch,uint256 nonce,uint256 salt)"
DROP_AUTHORIZATION_TYPE = (
    "DropAuthorization(bytes32 dropId,address poster,address recipient,address payer,"
    "uint256 collectionId,uint8 saleMode,bytes32 tokenDataHash,uint256 price,"
    "uint256 quantity,uint256 auctionReservePrice,uint256 auctionEndTime,uint256 salt,"
    "uint256 nonce,uint256 deadline,uint256 signerEpoch)"
)

EIP712_DOMAIN_FIELDS = [
    {"name": "name", "type": "string"},
    {"name": "version", "type": "string"},
    {"name": "chainId", "type": "uint256"},
    {"name": "verifyingContract", "type": "address"},
]

DROP_AUTHORIZATION_FIELDS = [
    {"name": "dropId", "type": "bytes32"},
    {"name": "poster", "type": "address"},
    {"name": "recipient", "type": "address"},
    {"name": "payer", "type": "address"},
    {"name": "collectionId", "type": "uint256"},
    {"name": "saleMode", "type": "uint8"},
    {"name": "tokenDataHash", "type": "bytes32"},
    {"name": "price", "type": "uint256"},
    {"name": "quantity", "type": "uint256"},
    {"name": "auctionReservePrice", "type": "uint256"},
    {"name": "auctionEndTime", "type": "uint256"},
    {"name": "salt", "type": "uint256"},
    {"name": "nonce", "type": "uint256"},
    {"name": "deadline", "type": "uint256"},
    {"name": "signerEpoch", "type": "uint256"},
]

REQUIRED_FIXTURE_IDS = {
    "fixed-price-eoa",
    "auction-eoa",
    "erc1271-contract-signer",
}

REQUIRED_GUIDE_HEADINGS = [
    (1, "Drop Authorization Signing"),
    (2, "Maturity And Scope"),
    (2, "Canonical EIP-712 Schema"),
    (2, "Fixture Index"),
    (2, "Operator Signing Flow"),
    (2, "Replay And Revocation Model"),
    (2, "Auction Signing Notes"),
    (2, "ERC-1271 Contract Signers"),
    (2, "Failure Checklist"),
    (2, "Local Verification Commands"),
    (2, "Maintenance"),
]

REQUIRED_GUIDE_PHRASES = [
    "pre-audit",
    "not production-ready",
    "no-secret",
    "EIP-712",
    "name",
    "version",
    "chainId",
    "verifyingContract",
    "DROP_AUTHORIZATION_TYPEHASH",
    "DROP_ID_TYPEHASH",
    "consumedDropIds",
    "cancelledDropIds",
    "signerEpoch",
    "nonce",
    "salt",
    "deadline",
    "wrong domain",
    "wrong signer",
    "zero address",
    "replay",
    "ERC-1271",
    "isValidSignature",
    "0x1626ba7e",
    "auction custody",
]

REQUIRED_COMMANDS = [
    "python scripts/test_drop_authorization_fixtures.py",
    "python scripts/check_drop_authorization_fixtures.py",
    "python scripts/test_drop_authorization_payload_generator.py",
    (
        "python scripts/generate_drop_authorization_payload.py --input "
        "test/fixtures/drop-authorization/payload-generator/fixed-price-input.json "
        "--output test/fixtures/drop-authorization/payload-generator/fixed-price-output.json "
        "--check"
    ),
    (
        "python scripts/generate_drop_authorization_payload.py --input "
        "test/fixtures/drop-authorization/payload-generator/auction-input.json "
        "--output test/fixtures/drop-authorization/payload-generator/auction-output.json "
        "--check"
    ),
    "python scripts/generate_release_manifest.py --check",
    "python scripts/generate_release_checksums.py --check",
    "make check",
]

REQUIRED_LINK_TARGETS = [
    "smart-contracts/StreamDrops.sol",
    "docs/adr/0001-drop-authorization.md",
    "docs/known-blockers.md",
    "docs/release-readiness.md",
    "docs/tooling.md",
    "docs/audit-package.md",
    "docs/incident-response.md",
    "ops/ROADMAP.md",
    "test/StreamDropsEIP712.t.sol",
    "test/StreamDropsERC1271.t.sol",
    "test/helpers/DropAuthTestHelper.sol",
    "test/fixtures/drop-authorization/fixed-price-eoa.json",
    "test/fixtures/drop-authorization/auction-eoa.json",
    "test/fixtures/drop-authorization/erc1271-contract-signer.json",
    "scripts/generate_drop_authorization_payload.py",
    "scripts/test_drop_authorization_payload_generator.py",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-input.json",
    "test/fixtures/drop-authorization/payload-generator/fixed-price-output.json",
    "test/fixtures/drop-authorization/payload-generator/auction-input.json",
    "test/fixtures/drop-authorization/payload-generator/auction-output.json",
]

REQUIRED_FAILURE_CASE_IDS = {
    "wrong_signer",
    "wrong_domain",
    "expired",
    "replayed_or_consumed",
    "cancelled_drop",
    "stale_signer_epoch",
    "bad_drop_id",
    "token_data_substitution",
    "zero_address",
}

HEADING_RE = re.compile(r"^(#{1,6})\s+(.+?)\s*$", re.MULTILINE)
LINK_RE = re.compile(r"\[[^\]]+\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HEX_RE = re.compile(r"^0x[0-9a-fA-F]+$")
ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
BYTES32_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
SECRET_KEY_RE = re.compile(
    r"(private[_ -]?key|mnemonic|seed[_ -]?phrase|secret[_ -]?key)", re.IGNORECASE
)

MASK_64 = (1 << 64) - 1
KECCAK_ROUNDS = [
    0x0000000000000001,
    0x0000000000008082,
    0x800000000000808A,
    0x8000000080008000,
    0x000000000000808B,
    0x0000000080000001,
    0x8000000080008081,
    0x8000000000008009,
    0x000000000000008A,
    0x0000000000000088,
    0x0000000080008009,
    0x000000008000000A,
    0x000000008000808B,
    0x800000000000008B,
    0x8000000000008089,
    0x8000000000008003,
    0x8000000000008002,
    0x8000000000000080,
    0x000000000000800A,
    0x800000008000000A,
    0x8000000080008081,
    0x8000000000008080,
    0x0000000080000001,
    0x8000000080008008,
]
RHO_OFFSETS = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]


class DropAuthorizationFixtureError(ValueError):
    """Raised when drop authorization docs or fixtures are incomplete."""


def normalize_repo_path(path: Path, repo_root: Path) -> str:
    """Return a repository-relative POSIX path or reject path escapes."""
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as exc:
        raise DropAuthorizationFixtureError(
            f"linked path escapes repository: {path}"
        ) from exc


def markdown_headings(text: str) -> set[tuple[int, str]]:
    """Extract Markdown headings as level/title pairs."""
    headings = set()
    for match in HEADING_RE.finditer(text):
        level = len(match.group(1))
        title = match.group(2).strip().rstrip("#").strip()
        headings.add((level, title))
    return headings


def normalized_link_target(raw_target: str) -> str | None:
    """Return a local Markdown link path without anchors or query strings."""
    target = raw_target.strip()
    if not target or target.startswith("#"):
        return None
    if "://" in target or target.startswith("mailto:"):
        return None

    path_part = target.split("#", 1)[0].split("?", 1)[0]
    if not path_part:
        return None
    return path_part


def linked_repo_paths(repo_root: Path, document_path: Path, text: str) -> set[str]:
    """Collect existing repository-relative file links from Markdown text."""
    links = set()
    missing = []
    for match in LINK_RE.finditer(text):
        target = normalized_link_target(match.group(1))
        if target is None:
            continue

        target_path = Path(target)
        if not target_path.is_absolute():
            target_path = document_path.parent / target_path

        resolved = target_path.resolve()
        relative = normalize_repo_path(resolved, repo_root)
        if not resolved.exists():
            missing.append(relative)
            continue
        links.add(relative)

    if missing:
        raise DropAuthorizationFixtureError(
            "linked targets are missing: " + ", ".join(sorted(set(missing)))
        )
    return links


def missing_phrases(text: str, phrases: list[str]) -> list[str]:
    """Return required phrases that are absent from text, case-insensitively."""
    normalized_text = text.lower()
    return [phrase for phrase in phrases if phrase.lower() not in normalized_text]


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Return a JSON object or raise a path-aware error."""
    if not isinstance(value, dict):
        raise DropAuthorizationFixtureError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    """Return a JSON array or raise a path-aware error."""
    if not isinstance(value, list):
        raise DropAuthorizationFixtureError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    """Return a string or raise a path-aware error."""
    if not isinstance(value, str) or value == "":
        raise DropAuthorizationFixtureError(f"{path} must be a non-empty string")
    return value


def require_bool(value: Any, path: str) -> bool:
    """Return a bool or raise a path-aware error."""
    if not isinstance(value, bool):
        raise DropAuthorizationFixtureError(f"{path} must be a boolean")
    return value


def require_uint(value: Any, path: str, max_value: int = (1 << 256) - 1) -> int:
    """Parse a JSON uint encoded as an integer or decimal string."""
    if isinstance(value, bool):
        raise DropAuthorizationFixtureError(f"{path} must be an unsigned integer")
    if isinstance(value, int):
        parsed = value
    elif isinstance(value, str) and value.isdigit():
        parsed = int(value)
    else:
        raise DropAuthorizationFixtureError(
            f"{path} must be an unsigned integer or decimal string"
        )
    if parsed < 0 or parsed > max_value:
        raise DropAuthorizationFixtureError(f"{path} is outside the uint range")
    return parsed


def require_hex(value: Any, path: str, length_bytes: int | None = None) -> str:
    """Return normalized lowercase hex with an optional byte-length check."""
    raw = require_string(value, path)
    if not HEX_RE.fullmatch(raw):
        raise DropAuthorizationFixtureError(f"{path} must be 0x-prefixed hex")
    if length_bytes is not None and len(raw) != 2 + length_bytes * 2:
        raise DropAuthorizationFixtureError(
            f"{path} must be {length_bytes} bytes of hex"
        )
    return raw.lower()


def require_address(value: Any, path: str) -> str:
    """Return a normalized lowercase Ethereum address."""
    raw = require_string(value, path)
    if not ADDRESS_RE.fullmatch(raw):
        raise DropAuthorizationFixtureError(f"{path} must be an Ethereum address")
    return raw.lower()


def require_bytes32(value: Any, path: str) -> str:
    """Return normalized lowercase bytes32 hex."""
    raw = require_string(value, path)
    if not BYTES32_RE.fullmatch(raw):
        raise DropAuthorizationFixtureError(f"{path} must be bytes32 hex")
    return raw.lower()


def rotl64(value: int, shift: int) -> int:
    """Rotate a 64-bit word left."""
    if shift == 0:
        return value & MASK_64
    return ((value << shift) | (value >> (64 - shift))) & MASK_64


def keccak_f1600(state: list[int]) -> None:
    """Apply the Keccak-f[1600] permutation in place."""
    for round_constant in KECCAK_ROUNDS:
        c = [state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20] for x in range(5)]
        d = [c[(x - 1) % 5] ^ rotl64(c[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                state[x + 5 * y] ^= d[x]

        b = [0] * 25
        for x in range(5):
            for y in range(5):
                b[y + 5 * ((2 * x + 3 * y) % 5)] = rotl64(
                    state[x + 5 * y], RHO_OFFSETS[x][y]
                )

        for x in range(5):
            for y in range(5):
                state[x + 5 * y] = (
                    b[x + 5 * y]
                    ^ ((~b[((x + 1) % 5) + 5 * y]) & b[((x + 2) % 5) + 5 * y])
                ) & MASK_64

        state[0] ^= round_constant


def keccak256(data: bytes) -> bytes:
    """Return Ethereum Keccak-256 for bytes."""
    rate = 136
    pad_len = rate - (len(data) % rate)
    if pad_len == 1:
        padded = data + b"\x81"
    else:
        padded = data + b"\x01" + b"\x00" * (pad_len - 2) + b"\x80"

    state = [0] * 25
    for offset in range(0, len(padded), rate):
        block = padded[offset : offset + rate]
        for lane in range(rate // 8):
            start = lane * 8
            state[lane] ^= int.from_bytes(block[start : start + 8], "little")
        keccak_f1600(state)

    output = bytearray()
    while len(output) < 32:
        for lane in range(rate // 8):
            output.extend(state[lane].to_bytes(8, "little"))
            if len(output) >= 32:
                break
        if len(output) < 32:
            keccak_f1600(state)
    return bytes(output[:32])


def keccak_hex(data: bytes) -> str:
    """Return a 0x-prefixed Keccak-256 digest."""
    return "0x" + keccak256(data).hex()


def encode_uint(value: int) -> bytes:
    """ABI-encode a uint value."""
    return value.to_bytes(32, "big")


def encode_address(value: str) -> bytes:
    """ABI-encode an address."""
    return b"\x00" * 12 + bytes.fromhex(value[2:])


def encode_bytes32(value: str) -> bytes:
    """ABI-encode bytes32."""
    return bytes.fromhex(value[2:])


def abi_encode_static(values: list[tuple[str, Any]]) -> bytes:
    """ABI-encode the static field subset used by DropAuthorization."""
    encoded = bytearray()
    for solidity_type, value in values:
        if solidity_type in {"uint256", "uint8"}:
            max_value = (1 << 8) - 1 if solidity_type == "uint8" else (1 << 256) - 1
            encoded.extend(encode_uint(require_uint(value, solidity_type, max_value)))
        elif solidity_type == "address":
            encoded.extend(encode_address(require_address(value, solidity_type)))
        elif solidity_type == "bytes32":
            encoded.extend(encode_bytes32(require_bytes32(value, solidity_type)))
        else:
            raise DropAuthorizationFixtureError(
                f"unsupported ABI fixture field type: {solidity_type}"
            )
    return bytes(encoded)


def compute_derived(typed_data: dict[str, Any], token_data: str, signer: str) -> dict[str, str]:
    """Compute dropId, token-data hash, EIP-712 hashes, and digest."""
    domain = require_dict(typed_data.get("domain"), "typed_data.domain")
    message = require_dict(typed_data.get("message"), "typed_data.message")
    normalized_signer = require_address(signer, "expected.signer")

    token_data_hash = keccak_hex(token_data.encode("utf-8"))
    drop_id = keccak_hex(
        abi_encode_static(
            [
                ("bytes32", keccak_hex(DROP_ID_TYPE.encode("utf-8"))),
                ("address", normalized_signer),
                ("uint256", message.get("signerEpoch")),
                ("uint256", message.get("nonce")),
                ("uint256", message.get("salt")),
            ]
        )
    )
    domain_separator = keccak_hex(
        abi_encode_static(
            [
                ("bytes32", keccak_hex(EIP712_DOMAIN_TYPE.encode("utf-8"))),
                ("bytes32", keccak_hex(require_string(domain.get("name"), "domain.name").encode("utf-8"))),
                ("bytes32", keccak_hex(require_string(domain.get("version"), "domain.version").encode("utf-8"))),
                ("uint256", domain.get("chainId")),
                ("address", domain.get("verifyingContract")),
            ]
        )
    )
    struct_values: list[tuple[str, Any]] = [
        ("bytes32", keccak_hex(DROP_AUTHORIZATION_TYPE.encode("utf-8"))),
    ]
    for field in DROP_AUTHORIZATION_FIELDS:
        struct_values.append((field["type"], message.get(field["name"])))
    struct_hash = keccak_hex(abi_encode_static(struct_values))
    digest = keccak_hex(bytes.fromhex("1901") + bytes.fromhex(domain_separator[2:]) + bytes.fromhex(struct_hash[2:]))
    return {
        "drop_id": drop_id,
        "token_data_hash": token_data_hash,
        "domain_separator": domain_separator,
        "struct_hash": struct_hash,
        "digest": digest,
    }


def validate_types(typed_data: dict[str, Any], fixture_id: str) -> None:
    """Validate the EIP-712 types are exact and ordered."""
    types = require_dict(typed_data.get("types"), f"{fixture_id}.typed_data.types")
    if types.get("EIP712Domain") != EIP712_DOMAIN_FIELDS:
        raise DropAuthorizationFixtureError(
            f"{fixture_id} has an unexpected EIP712Domain field order"
        )
    if types.get("DropAuthorization") != DROP_AUTHORIZATION_FIELDS:
        raise DropAuthorizationFixtureError(
            f"{fixture_id} has an unexpected DropAuthorization field order"
        )
    if typed_data.get("primaryType") != "DropAuthorization":
        raise DropAuthorizationFixtureError(
            f"{fixture_id}.typed_data.primaryType must be DropAuthorization"
        )


def validate_domain(typed_data: dict[str, Any], fixture_id: str) -> None:
    """Validate the EIP-712 domain contains required fields and values."""
    domain = require_dict(typed_data.get("domain"), f"{fixture_id}.typed_data.domain")
    required = {"name", "version", "chainId", "verifyingContract"}
    if set(domain) != required:
        raise DropAuthorizationFixtureError(
            f"{fixture_id}.typed_data.domain must contain exactly "
            "name, version, chainId, verifyingContract"
        )
    if domain["name"] != EIP712_NAME:
        raise DropAuthorizationFixtureError(f"{fixture_id}.domain.name mismatch")
    if domain["version"] != EIP712_VERSION:
        raise DropAuthorizationFixtureError(f"{fixture_id}.domain.version mismatch")
    require_uint(domain["chainId"], f"{fixture_id}.domain.chainId")
    require_address(domain["verifyingContract"], f"{fixture_id}.domain.verifyingContract")


def validate_message(typed_data: dict[str, Any], token_data: str, fixture_id: str) -> None:
    """Validate the authorization message shape and sale-mode constraints."""
    message = require_dict(typed_data.get("message"), f"{fixture_id}.typed_data.message")
    required = {field["name"] for field in DROP_AUTHORIZATION_FIELDS}
    if set(message) != required:
        raise DropAuthorizationFixtureError(
            f"{fixture_id}.typed_data.message has missing or unexpected fields"
        )

    for field in DROP_AUTHORIZATION_FIELDS:
        field_path = f"{fixture_id}.typed_data.message.{field['name']}"
        if field["type"] == "address":
            require_address(message[field["name"]], field_path)
        elif field["type"] == "bytes32":
            require_bytes32(message[field["name"]], field_path)
        elif field["type"] == "uint8":
            require_uint(message[field["name"]], field_path, (1 << 8) - 1)
        else:
            require_uint(message[field["name"]], field_path)

    if require_uint(message["quantity"], f"{fixture_id}.quantity") != 1:
        raise DropAuthorizationFixtureError(f"{fixture_id}.quantity must be 1")
    if message["tokenDataHash"].lower() != keccak_hex(token_data.encode("utf-8")):
        raise DropAuthorizationFixtureError(f"{fixture_id}.tokenDataHash mismatch")

    sale_mode = require_uint(message["saleMode"], f"{fixture_id}.saleMode", (1 << 8) - 1)
    zero_address = "0x0000000000000000000000000000000000000000"
    if message["poster"].lower() == zero_address:
        raise DropAuthorizationFixtureError(f"{fixture_id}.poster must be non-zero")
    if sale_mode == 1:
        if message["recipient"].lower() == zero_address:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.recipient must be non-zero for fixed price"
            )
        if require_uint(message["auctionReservePrice"], f"{fixture_id}.auctionReservePrice") != 0:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.auctionReservePrice must be zero for fixed price"
            )
        if require_uint(message["auctionEndTime"], f"{fixture_id}.auctionEndTime") != 0:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.auctionEndTime must be zero for fixed price"
            )
    elif sale_mode == 2:
        if message["recipient"].lower() != zero_address:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.recipient must be zero for auction"
            )
        if message["payer"].lower() != zero_address:
            raise DropAuthorizationFixtureError(f"{fixture_id}.payer must be zero for auction")
        if require_uint(message["price"], f"{fixture_id}.price") != 0:
            raise DropAuthorizationFixtureError(f"{fixture_id}.price must be zero for auction")
        if require_uint(message["auctionEndTime"], f"{fixture_id}.auctionEndTime") == 0:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.auctionEndTime must be non-zero for auction"
            )
    else:
        raise DropAuthorizationFixtureError(f"{fixture_id}.saleMode must be 1 or 2")


def validate_no_secret_policy(fixture: dict[str, Any], fixture_id: str) -> None:
    """Validate fixture policy says no key material or production payload exists."""
    policy = require_dict(fixture.get("no_secret_policy"), f"{fixture_id}.no_secret_policy")
    if require_bool(policy.get("key_material_included"), f"{fixture_id}.key_material_included"):
        raise DropAuthorizationFixtureError(f"{fixture_id} includes key material")
    if require_bool(policy.get("mnemonic_included"), f"{fixture_id}.mnemonic_included"):
        raise DropAuthorizationFixtureError(f"{fixture_id} includes a mnemonic")
    if require_bool(policy.get("production_payload"), f"{fixture_id}.production_payload"):
        raise DropAuthorizationFixtureError(f"{fixture_id} claims production payload status")

    def walk(value: Any, path: str) -> None:
        if isinstance(value, dict):
            for key, nested in value.items():
                if SECRET_KEY_RE.search(str(key)) and "no_secret_policy" not in path:
                    raise DropAuthorizationFixtureError(
                        f"{fixture_id} uses secret-like key name at {path}.{key}"
                    )
                walk(nested, f"{path}.{key}")
        elif isinstance(value, list):
            for index, nested in enumerate(value):
                walk(nested, f"{path}[{index}]")
        elif isinstance(value, str) and SECRET_KEY_RE.search(value):
            if path.endswith(".description") or "no_secret_policy" in path:
                return
            raise DropAuthorizationFixtureError(
                f"{fixture_id} contains secret-like text at {path}"
            )

    walk(fixture, fixture_id)


def validate_expected(
    fixture: dict[str, Any],
    typed_data: dict[str, Any],
    token_data: str,
    fixture_id: str,
) -> None:
    """Validate expected hashes, digest, signature shape, and call expectations."""
    expected = require_dict(fixture.get("expected"), f"{fixture_id}.expected")
    signer = require_address(expected.get("signer"), f"{fixture_id}.expected.signer")
    derived = compute_derived(typed_data, token_data, signer)
    for key, value in derived.items():
        actual = require_bytes32(expected.get(key), f"{fixture_id}.expected.{key}")
        if actual != value:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.expected.{key} mismatch: expected {value}, got {actual}"
            )

    message = require_dict(typed_data.get("message"), f"{fixture_id}.typed_data.message")
    if message["dropId"].lower() != expected["drop_id"].lower():
        raise DropAuthorizationFixtureError(f"{fixture_id}.message.dropId mismatch")
    if message["tokenDataHash"].lower() != expected["token_data_hash"].lower():
        raise DropAuthorizationFixtureError(f"{fixture_id}.message.tokenDataHash mismatch")

    kind = require_string(expected.get("signature_kind"), f"{fixture_id}.signature_kind")
    signature = require_hex(expected.get("signature"), f"{fixture_id}.expected.signature")
    if kind == "eoa_65_byte":
        if len(signature) != 132:
            raise DropAuthorizationFixtureError(
                f"{fixture_id}.expected.signature must be a 65-byte EOA signature"
            )
    elif kind == "erc1271_mock_bytes":
        if fixture_id != "erc1271-contract-signer":
            raise DropAuthorizationFixtureError(
                "only erc1271-contract-signer may use erc1271_mock_bytes"
            )
        magic = require_string(
            expected.get("erc1271_magic_value"),
            f"{fixture_id}.expected.erc1271_magic_value",
        )
        if magic.lower() != "0x1626ba7e":
            raise DropAuthorizationFixtureError(f"{fixture_id}.ERC1271 magic mismatch")
    else:
        raise DropAuthorizationFixtureError(f"{fixture_id}.signature_kind is unsupported")

    call = require_dict(expected.get("call"), f"{fixture_id}.expected.call")
    if call.get("function") != "mintDrop(DropAuthorization,string,bytes)":
        raise DropAuthorizationFixtureError(f"{fixture_id}.expected.call.function mismatch")
    msg_value = require_uint(call.get("msg_value_wei"), f"{fixture_id}.expected.call.msg_value_wei")
    price = require_uint(message["price"], f"{fixture_id}.message.price")
    sale_mode = require_uint(message["saleMode"], f"{fixture_id}.message.saleMode")
    if sale_mode == 1 and msg_value != price:
        raise DropAuthorizationFixtureError(
            f"{fixture_id}.expected.call.msg_value_wei must equal fixed price"
        )
    if sale_mode == 2 and msg_value != 0:
        raise DropAuthorizationFixtureError(
            f"{fixture_id}.expected.call.msg_value_wei must be zero for auction"
        )


def validate_failure_cases(fixture: dict[str, Any], fixture_id: str) -> set[str]:
    """Validate failure case entries and return their IDs."""
    cases = require_list(fixture.get("failure_cases"), f"{fixture_id}.failure_cases")
    found = set()
    for index, case in enumerate(cases):
        item = require_dict(case, f"{fixture_id}.failure_cases[{index}]")
        case_id = require_string(item.get("id"), f"{fixture_id}.failure_cases[{index}].id")
        require_string(item.get("expected_revert"), f"{fixture_id}.failure_cases[{index}].expected_revert")
        require_string(item.get("notes"), f"{fixture_id}.failure_cases[{index}].notes")
        found.add(case_id)
    return found


def validate_fixture(path: Path) -> tuple[str, set[str]]:
    """Validate one fixture and return its fixture ID and failure case IDs."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise DropAuthorizationFixtureError(f"{path} is not valid JSON: {exc}") from exc

    fixture = require_dict(data, path.as_posix())
    fixture_id = require_string(fixture.get("fixture_id"), f"{path}.fixture_id")
    if fixture.get("schema_version") != SCHEMA_VERSION:
        raise DropAuthorizationFixtureError(f"{fixture_id}.schema_version mismatch")
    if path.stem != fixture_id:
        raise DropAuthorizationFixtureError(f"{path} filename must match fixture_id")

    require_string(fixture.get("description"), f"{fixture_id}.description")
    source = require_dict(fixture.get("source"), f"{fixture_id}.source")
    if source.get("contract") != "smart-contracts/StreamDrops.sol":
        raise DropAuthorizationFixtureError(f"{fixture_id}.source.contract mismatch")
    require_list(source.get("tests"), f"{fixture_id}.source.tests")
    validate_no_secret_policy(fixture, fixture_id)

    typed_data = require_dict(fixture.get("typed_data"), f"{fixture_id}.typed_data")
    validate_types(typed_data, fixture_id)
    validate_domain(typed_data, fixture_id)
    token_data = require_string(fixture.get("token_data"), f"{fixture_id}.token_data")
    validate_message(typed_data, token_data, fixture_id)
    validate_expected(fixture, typed_data, token_data, fixture_id)
    return fixture_id, validate_failure_cases(fixture, fixture_id)


def validate_guide(repo_root: Path, guide_path: Path) -> None:
    """Validate the operator signing guide."""
    if not guide_path.is_file():
        relative = normalize_repo_path(guide_path, repo_root)
        raise DropAuthorizationFixtureError(f"missing guide: {relative}")

    text = guide_path.read_text(encoding="utf-8")
    headings = markdown_headings(text)
    missing_headings = [
        f"{'#' * level} {title}"
        for level, title in REQUIRED_GUIDE_HEADINGS
        if (level, title) not in headings
    ]
    if missing_headings:
        raise DropAuthorizationFixtureError(
            "drop authorization signing guide is missing required headings: "
            + ", ".join(missing_headings)
        )

    missing = missing_phrases(text, REQUIRED_GUIDE_PHRASES)
    if missing:
        raise DropAuthorizationFixtureError(
            "drop authorization signing guide is missing required content: "
            + ", ".join(missing)
        )

    missing_commands = [command for command in REQUIRED_COMMANDS if command not in text]
    if missing_commands:
        raise DropAuthorizationFixtureError(
            "drop authorization signing guide is missing required commands: "
            + ", ".join(missing_commands)
        )

    links = linked_repo_paths(repo_root, guide_path, text)
    missing_targets = [target for target in REQUIRED_LINK_TARGETS if target not in links]
    if missing_targets:
        raise DropAuthorizationFixtureError(
            "drop authorization signing guide is missing required links: "
            + ", ".join(missing_targets)
        )


def validate_all(repo_root: Path, guide_path: Path, fixture_dir: Path) -> None:
    """Validate the guide and all deterministic fixture files."""
    validate_guide(repo_root, guide_path)
    if not fixture_dir.is_dir():
        relative = normalize_repo_path(fixture_dir, repo_root)
        raise DropAuthorizationFixtureError(f"missing fixture directory: {relative}")

    fixture_ids = set()
    failure_cases = set()
    for path in sorted(fixture_dir.glob("*.json")):
        fixture_id, cases = validate_fixture(path)
        fixture_ids.add(fixture_id)
        failure_cases.update(cases)

    missing_fixtures = REQUIRED_FIXTURE_IDS - fixture_ids
    if missing_fixtures:
        raise DropAuthorizationFixtureError(
            "missing required drop authorization fixtures: "
            + ", ".join(sorted(missing_fixtures))
        )

    missing_cases = REQUIRED_FAILURE_CASE_IDS - failure_cases
    if missing_cases:
        raise DropAuthorizationFixtureError(
            "missing required failure case coverage: " + ", ".join(sorted(missing_cases))
        )


def parse_args(argv: list[str]) -> argparse.Namespace:
    """Parse CLI options."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--guide", type=Path, default=DEFAULT_GUIDE)
    parser.add_argument("--fixture-dir", type=Path, default=DEFAULT_FIXTURE_DIR)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """Run the fixture checker CLI."""
    args = parse_args(argv or [])
    repo_root = args.repo_root.resolve()
    guide_path = args.guide
    fixture_dir = args.fixture_dir
    if not guide_path.is_absolute():
        guide_path = repo_root / guide_path
    if not fixture_dir.is_absolute():
        fixture_dir = repo_root / fixture_dir

    try:
        validate_all(repo_root, guide_path.resolve(), fixture_dir.resolve())
    except DropAuthorizationFixtureError as exc:
        print(f"drop authorization fixture check failed: {exc}", file=sys.stderr)
        return 1

    print("drop authorization signing guide and fixtures are current")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
