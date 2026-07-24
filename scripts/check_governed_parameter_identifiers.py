#!/usr/bin/env python3
"""Check the closed-world launch GGP/GTP identifier catalog and derivation."""

from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Final


TARGET_ARCHITECTURE: Final = Path("docs/launch-v1-target-architecture.md")
LONG_TERM_ARCHITECTURE: Final = Path("docs/stream-long-term-architecture.md")
GAS_HOST: Final = Path("smart-contracts/StreamGasParameterHost.sol")
TIME_HOST: Final = Path("smart-contracts/StreamTimeParameterHost.sol")

GGP_NAMES: Final = (
    "ROYALTY_RESOLVER_GAS_LIMIT",
    "ROYALTY_RETURN_GAS_BUFFER",
    "ERC_1271_GAS_LIMIT",
    "ASSET_POLICY_GAS_LIMIT",
    "WALLET_DEPOSIT_GAS_LIMIT",
    "FLUSH_GAS_FLOOR",
    "MINT_GATE_GAS_LIMIT",
    "TICKET_ERC1271_GAS_LIMIT",
    "ARTIST_AUTHORITY_GAS_LIMIT",
    "SALE_ERC1271_GAS_LIMIT",
    "DELEGATE_REGISTRY_GAS_LIMIT",
    "SALE_ARTIST_AUTHORITY_GAS_LIMIT",
    "REVEAL_ATTEMPT_GAS_LIMIT",
    "SALE_NFT_DELIVERY_GAS_LIMIT",
    "METADATA_ROUTER_GAS_LIMIT",
    "ENTROPY_VIEW_GAS_LIMIT",
    "ENTROPY_REGISTRATION_GAS_LIMIT",
    "ENTROPY_RESULT_PROBE_GAS_LIMIT",
    "VRF_CALLBACK_GAS_LIMIT",
    "ARTIST_ERC1271_VERIFY_GAS",
    "METADATA_ERC1271_VERIFY_GAS",
    "FINALITY_COMPONENT_READ_GAS",
)

GTP_NAMES: Final = (
    "ENTROPY_REQUEST_TIMEOUT_BLOCKS",
    "ENTROPY_REVEAL_SLO_BLOCKS",
    "ENTROPY_RECOVERY_STEP_DELAY_BLOCKS",
)

TARGET_TABLE_HEADER: Final = (
    "| Constant name | String preimage | Hash value | Owner | Schema version | Inputs |"
)
TARGET_TABLE_END: Final = "### Pinned-Name Glossary"
GGP_INVENTORY_START: Final = "GGP inventory."
GGP_INVENTORY_END: Final = "A future guarded path that is not in this inventory"
GTP_INVENTORY_START: Final = "The GTP inventory is owned by the subsystem homes"
GTP_INVENTORY_END: Final = "GTP membership is closed-world and decidable"

TARGET_ROW = re.compile(
    r"^\| `((?:GGP|GTP)_[A-Z0-9_]+)` \| `([^`]+)` \| "
    r"(0x[0-9a-f]{64}) \| ([^|]+?) \| `(\d+)` \|",
    flags=re.MULTILINE,
)
GGP_ROW = re.compile(r"^\| `([A-Z][A-Z0-9_]+)` \|", flags=re.MULTILINE)
UPPER_BACKTICK = re.compile(r"`([A-Z][A-Z0-9_]+)`")


class GovernedParameterIdentifierError(RuntimeError):
    """Raised when a governed-parameter identifier surface drifts."""


def _read(root: Path, relative: Path) -> str:
    path = root / relative
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        raise GovernedParameterIdentifierError(f"cannot read {relative}: {exc}") from exc


def _bounded(text: str, start: str, end: str, label: str) -> str:
    start_index = text.find(start)
    if start_index < 0:
        raise GovernedParameterIdentifierError(f"missing {label} start marker: {start!r}")
    end_index = text.find(end, start_index + len(start))
    if end_index < 0:
        raise GovernedParameterIdentifierError(f"missing {label} end marker: {end!r}")
    return text[start_index + len(start) : end_index]


def _keccak256(value: bytes) -> bytes:
    try:
        from eth_hash.auto import keccak

        return keccak(value)
    except ImportError:
        try:
            from Crypto.Hash import keccak as crypto_keccak
        except ImportError as exc:
            raise GovernedParameterIdentifierError(
                "Ethereum Keccak support requires eth-hash or pycryptodome"
            ) from exc
        digest = crypto_keccak.new(digest_bits=256)
        digest.update(value)
        return digest.digest()


def _expected_constants() -> tuple[str, ...]:
    return tuple(f"GGP_{name}" for name in GGP_NAMES) + tuple(
        f"GTP_{name}" for name in GTP_NAMES
    )


def _validate_target_table(text: str) -> None:
    section = _bounded(text, TARGET_TABLE_HEADER, TARGET_TABLE_END, "identifier mirror table")
    rows = TARGET_ROW.findall(section)
    expected_constants = _expected_constants()
    actual_constants = tuple(row[0] for row in rows)
    if actual_constants != expected_constants:
        raise GovernedParameterIdentifierError(
            "target identifier rows do not match the exact 22-GGP/3-GTP launch catalog"
        )

    for constant_name, preimage, pinned_hash, owner, schema_version in rows:
        expected_preimage = f"6529STREAM_{constant_name}"
        if preimage != expected_preimage:
            raise GovernedParameterIdentifierError(
                f"{constant_name} preimage must be {expected_preimage!r}, got {preimage!r}"
            )
        computed_hash = "0x" + _keccak256(preimage.encode("ascii")).hex()
        if pinned_hash != computed_hash:
            raise GovernedParameterIdentifierError(
                f"{constant_name} hash mismatch: expected {computed_hash}, got {pinned_hash}"
            )
        if schema_version != "1":
            raise GovernedParameterIdentifierError(
                f"{constant_name} identifier schema must remain 1"
            )
        if not owner.strip():
            raise GovernedParameterIdentifierError(f"{constant_name} owner must not be empty")


def _validate_lta_inventories(text: str) -> None:
    ggp_section = _bounded(
        text, GGP_INVENTORY_START, GGP_INVENTORY_END, "LTA GGP inventory"
    )
    ggp_names = tuple(GGP_ROW.findall(ggp_section))
    if ggp_names != GGP_NAMES:
        raise GovernedParameterIdentifierError(
            "LTA GGP inventory does not match the exact launch catalog"
        )

    gtp_section = _bounded(
        text, GTP_INVENTORY_START, GTP_INVENTORY_END, "LTA GTP inventory"
    )
    gtp_names = tuple(UPPER_BACKTICK.findall(gtp_section))
    if gtp_names != GTP_NAMES:
        raise GovernedParameterIdentifierError(
            "LTA GTP inventory does not match the exact launch catalog"
        )


def _validate_host_derivation(gas_source: str, time_source: str) -> None:
    gas_pattern = re.compile(
        r'parameterId\s*=\s*keccak256\(\s*abi\.encodePacked\('
        r'\s*"6529STREAM_GGP_"\s*,\s*config\.name\s*\)\s*\)\s*;'
    )
    time_pattern = re.compile(
        r'parameterId\s*=\s*keccak256\(\s*abi\.encodePacked\('
        r'\s*"6529STREAM_GTP_"\s*,\s*config\.name\s*\)\s*\)\s*;'
    )
    if len(gas_pattern.findall(gas_source)) != 1:
        raise GovernedParameterIdentifierError(
            "StreamGasParameterHost must contain exactly one canonical GGP derivation"
        )
    if len(time_pattern.findall(time_source)) != 1:
        raise GovernedParameterIdentifierError(
            "StreamTimeParameterHost must contain exactly one canonical GTP derivation"
        )


def validate_repository(root: Path) -> None:
    _validate_target_table(_read(root, TARGET_ARCHITECTURE))
    _validate_lta_inventories(_read(root, LONG_TERM_ARCHITECTURE))
    _validate_host_derivation(_read(root, GAS_HOST), _read(root, TIME_HOST))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    args = parser.parse_args()
    try:
        validate_repository(args.repo_root.resolve())
    except GovernedParameterIdentifierError as exc:
        print(f"governed parameter identifier check failed: {exc}")
        return 1
    print("governed parameter identifier check passed (22 GGP, 3 GTP)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
