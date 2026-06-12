#!/usr/bin/env python3
"""Focused tests for the drop authorization signing fixture checker."""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("check_drop_authorization_fixtures.py")
SPEC = importlib.util.spec_from_file_location("check_drop_authorization_fixtures", SCRIPT_PATH)
assert SPEC is not None and SPEC.loader is not None
checker = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(checker)


ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
SIGNER = "0xe05fcC23807536bEe418f142D19fa0d21BB0cfF7"
VERIFYING_CONTRACT = "0x100000000000000000000000000000000000dEaD"


def write_text(path: Path, value: str) -> None:
    """Write UTF-8 text while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(value, encoding="utf-8", newline="\n")


def write_json(path: Path, value: object) -> None:
    """Write canonical JSON while creating parent directories."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2)
        handle.write("\n")


def seed_required_targets(root: Path) -> None:
    """Create placeholder files for every required guide link target."""
    for relative in checker.REQUIRED_LINK_TARGETS:
        write_text(root / relative, f"seed for {relative}\n")


def target_links(prefix: str = "../") -> str:
    """Render Markdown list items for all required link targets."""
    return "\n".join(
        f"- [{target}]({prefix}{target})" for target in checker.REQUIRED_LINK_TARGETS
    )


def minimal_guide(link_prefix: str = "../") -> str:
    """Build the smallest signing guide accepted by the checker."""
    commands = "\n".join(checker.REQUIRED_COMMANDS)
    links = target_links(link_prefix)
    return f"""# Drop Authorization Signing

This pre-audit no-secret guide is not production-ready and does not claim launch
readiness.

## Maturity And Scope

Fixtures explain EIP-712 signing for local evidence only.

## Canonical EIP-712 Schema

The EIP-712 domain contains name, version, chainId, and verifyingContract.
The contract exposes DROP_AUTHORIZATION_TYPEHASH and DROP_ID_TYPEHASH.

## Fixture Index

Fixture links are listed below.

## Operator Signing Flow

Operators sign after deriving nonce, salt, deadline, signerEpoch, dropId, and
tokenDataHash.

## Replay And Revocation Model

Replay is blocked with consumedDropIds, cancelledDropIds, signerEpoch rotation,
and drop cancellation.

## Auction Signing Notes

Auction custody covers poster, bid start, bid end, and reserve assumptions.

## ERC-1271 Contract Signers

ERC-1271 signers must return 0x1626ba7e from isValidSignature.

## Failure Checklist

Reject wrong domain, wrong signer, zero address, replay, stale epoch, bad drop
ID, token data substitution, and expired payloads.

## Local Verification Commands

```sh
{commands}
```

## Maintenance

{links}
"""


def base_typed_data(message: dict[str, object]) -> dict[str, object]:
    """Build canonical EIP-712 typed data around a message."""
    return {
        "types": {
            "EIP712Domain": checker.EIP712_DOMAIN_FIELDS,
            "DropAuthorization": checker.DROP_AUTHORIZATION_FIELDS,
        },
        "primaryType": "DropAuthorization",
        "domain": {
            "name": checker.EIP712_NAME,
            "version": checker.EIP712_VERSION,
            "chainId": 31337,
            "verifyingContract": VERIFYING_CONTRACT,
        },
        "message": message,
    }


def drop_id_for(message: dict[str, object], signer: str) -> str:
    """Derive the fixture drop ID using the checker encoder."""
    return checker.keccak_hex(
        checker.abi_encode_static(
            [
                ("bytes32", checker.keccak_hex(checker.DROP_ID_TYPE.encode("utf-8"))),
                ("address", signer),
                ("uint256", message["signerEpoch"]),
                ("uint256", message["nonce"]),
                ("uint256", message["salt"]),
            ]
        )
    )


def valid_fixture(fixture_id: str, sale_mode: int) -> dict[str, object]:
    """Return a complete deterministic fixture for a sale mode."""
    token_data = "auction-data" if sale_mode == 2 else "data"
    message: dict[str, object] = {
        "dropId": "0x" + "0" * 64,
        "poster": "0x0000000000000000000000000000000000001001",
        "recipient": ZERO_ADDRESS if sale_mode == 2 else "0x0000000000000000000000000000000000005005",
        "payer": ZERO_ADDRESS,
        "collectionId": "7" if sale_mode == 2 else "1",
        "saleMode": sale_mode,
        "tokenDataHash": checker.keccak_hex(token_data.encode("utf-8")),
        "price": "0",
        "quantity": "1",
        "auctionReservePrice": "5000000000000000000" if sale_mode == 2 else "0",
        "auctionEndTime": "1893542400" if sale_mode == 2 else "0",
        "salt": "4" if sale_mode == 2 else "2",
        "nonce": "3" if sale_mode == 2 else "1",
        "deadline": "1893456000",
        "signerEpoch": "1",
    }
    message["dropId"] = drop_id_for(message, SIGNER)
    typed_data = base_typed_data(message)
    expected = {
        "signer": SIGNER,
        **checker.compute_derived(typed_data, token_data, SIGNER),
        "signature_kind": "eoa_65_byte",
        "signature": "0x" + "11" * 65,
        "call": {
            "function": "mintDrop(DropAuthorization,string,bytes)",
            "msg_value_wei": "0",
        },
    }
    if fixture_id == "erc1271-contract-signer":
        expected["signature_kind"] = "erc1271_mock_bytes"
        expected["signature"] = "0x127165291271"
        expected["erc1271_magic_value"] = "0x1626ba7e"

    return {
        "schema_version": checker.SCHEMA_VERSION,
        "fixture_id": fixture_id,
        "description": f"{fixture_id} fixture",
        "source": {
            "contract": "smart-contracts/StreamDrops.sol",
            "adr": "docs/adr/0001-drop-authorization.md",
            "tests": ["test/StreamDropsEIP712.t.sol"],
        },
        "no_secret_policy": {
            "key_material_included": False,
            "mnemonic_included": False,
            "production_payload": False,
        },
        "typed_data": typed_data,
        "token_data": token_data,
        "expected": expected,
        "failure_cases": [
            {"id": "wrong_signer", "expected_revert": "Wrong signer", "notes": "bad signer"},
            {"id": "wrong_domain", "expected_revert": "Wrong signer", "notes": "bad domain"},
            {"id": "expired", "expected_revert": "Expired", "notes": "old deadline"},
            {"id": "replayed_or_consumed", "expected_revert": "Drop Executed", "notes": "replay"},
            {"id": "cancelled_drop", "expected_revert": "Drop cancelled", "notes": "cancelled"},
            {"id": "stale_signer_epoch", "expected_revert": "Bad epoch", "notes": "stale"},
            {"id": "bad_drop_id", "expected_revert": "Bad dropId", "notes": "bad id"},
            {"id": "token_data_substitution", "expected_revert": "Token data", "notes": "data"},
            {"id": "zero_address", "expected_revert": "Zero recipient", "notes": "zero"},
        ],
    }


def seed_valid_fixture_tree(root: Path) -> None:
    """Create a complete temporary guide and fixture directory."""
    seed_required_targets(root)
    write_text(root / checker.DEFAULT_GUIDE, minimal_guide())
    fixtures = {
        "fixed-price-eoa": valid_fixture("fixed-price-eoa", 1),
        "auction-eoa": valid_fixture("auction-eoa", 2),
        "erc1271-contract-signer": valid_fixture("erc1271-contract-signer", 1),
    }
    for fixture_id, fixture in fixtures.items():
        write_json(root / checker.DEFAULT_FIXTURE_DIR / f"{fixture_id}.json", fixture)


class DropAuthorizationFixtureTests(unittest.TestCase):
    def test_keccak_vectors_match_ethereum_keccak(self) -> None:
        """The local Keccak implementation matches known Ethereum vectors."""
        self.assertEqual(
            checker.keccak_hex(b""),
            "0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470",
        )
        self.assertEqual(
            checker.keccak_hex(b"data"),
            "0x8f54f1c2d0eb5771cd5bf67a6689fcd6eed9444d91a39e5ef32a9b4ae5ca14ff",
        )

    def test_accepts_committed_docs_and_fixtures(self) -> None:
        """The committed signing guide and fixtures satisfy the checker."""
        repo_root = Path(__file__).resolve().parents[1]

        with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            result = checker.main(["--repo-root", str(repo_root)])

        self.assertEqual(result, 0)

    def test_accepts_minimal_valid_temp_tree(self) -> None:
        """A minimal complete fixture set passes validation."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)

            with redirect_stdout(StringIO()), redirect_stderr(StringIO()):
                result = checker.main(["--repo-root", str(root)])

            self.assertEqual(result, 0)

    def test_rejects_missing_domain_field(self) -> None:
        """EIP-712 domain fields are mandatory."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)
            path = root / checker.DEFAULT_FIXTURE_DIR / "fixed-price-eoa.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            del data["typed_data"]["domain"]["verifyingContract"]
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.DropAuthorizationFixtureError, "domain must contain exactly"
            ):
                checker.validate_fixture(path)

    def test_rejects_derived_digest_mismatch(self) -> None:
        """Stale expected hashes are rejected."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)
            path = root / checker.DEFAULT_FIXTURE_DIR / "fixed-price-eoa.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["expected"]["digest"] = "0x" + "0" * 64
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.DropAuthorizationFixtureError, "expected.digest mismatch"
            ):
                checker.validate_fixture(path)

    def test_rejects_zero_poster(self) -> None:
        """Drop authorizations require a non-zero poster address."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)
            path = root / checker.DEFAULT_FIXTURE_DIR / "fixed-price-eoa.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["typed_data"]["message"]["poster"] = ZERO_ADDRESS
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.DropAuthorizationFixtureError, "poster must be non-zero"
            ):
                checker.validate_fixture(path)

    def test_rejects_key_material_policy(self) -> None:
        """Fixtures must explicitly omit signing key material."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)
            path = root / checker.DEFAULT_FIXTURE_DIR / "fixed-price-eoa.json"
            data = json.loads(path.read_text(encoding="utf-8"))
            data["no_secret_policy"]["key_material_included"] = True
            write_json(path, data)

            with self.assertRaisesRegex(
                checker.DropAuthorizationFixtureError, "includes key material"
            ):
                checker.validate_fixture(path)

    def test_rejects_missing_required_guide_link(self) -> None:
        """The guide must link all required source and fixture targets."""
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            seed_valid_fixture_tree(root)
            guide = root / checker.DEFAULT_GUIDE
            text = guide.read_text(encoding="utf-8").replace(
                "- [smart-contracts/StreamDrops.sol](../smart-contracts/StreamDrops.sol)\n",
                "",
            )
            write_text(guide, text)

            with self.assertRaisesRegex(
                checker.DropAuthorizationFixtureError, "missing required links"
            ):
                checker.validate_guide(root, guide)


if __name__ == "__main__":
    unittest.main(verbosity=2)
