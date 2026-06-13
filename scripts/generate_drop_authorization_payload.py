#!/usr/bin/env python3
"""Generate no-secret unsigned EIP-712 drop authorization payloads."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

import check_drop_authorization_fixtures as fixture_checker


INPUT_SCHEMA_VERSION = "6529stream.drop-authorization-payload-input.v1"
OUTPUT_SCHEMA_VERSION = "6529stream.drop-authorization-payload.v1"
GENERATOR_VERSION = "1"
ZERO_ADDRESS = "0x0000000000000000000000000000000000000000"
SALE_MODES = {
    "fixed_price": 1,
    "auction": 2,
}


class DropAuthorizationPayloadError(ValueError):
    """Raised when a payload input cannot produce canonical typed data."""


def json_text(value: Any) -> str:
    """Return deterministic JSON text."""
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def read_json(path: Path) -> dict[str, Any]:
    """Read a JSON object from disk."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise DropAuthorizationPayloadError(f"{path} is not valid JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise DropAuthorizationPayloadError(f"{path} must contain a JSON object")
    return data


def convert_checker_error(path: str, callback: Any) -> Any:
    """Run a fixture-checker validator and normalize its exception type."""
    try:
        return callback()
    except fixture_checker.DropAuthorizationFixtureError as exc:
        raise DropAuthorizationPayloadError(str(exc)) from exc


def require_dict(value: Any, path: str) -> dict[str, Any]:
    """Require a JSON object."""
    return convert_checker_error(path, lambda: fixture_checker.require_dict(value, path))


def require_string(value: Any, path: str) -> str:
    """Require a string."""
    return convert_checker_error(path, lambda: fixture_checker.require_string(value, path))


def require_bool(value: Any, path: str) -> bool:
    """Require a boolean."""
    return convert_checker_error(path, lambda: fixture_checker.require_bool(value, path))


def require_address(value: Any, path: str) -> str:
    """Require an Ethereum address string."""
    return convert_checker_error(path, lambda: fixture_checker.require_address(value, path))


def require_uint(value: Any, path: str, max_value: int | None = None) -> int:
    """Require an unsigned integer."""
    if max_value is None:
        return convert_checker_error(path, lambda: fixture_checker.require_uint(value, path))
    return convert_checker_error(path, lambda: fixture_checker.require_uint(value, path, max_value))


def decimal_string(value: Any, path: str, max_value: int | None = None) -> str:
    """Normalize an unsigned integer as a decimal JSON string."""
    return str(require_uint(value, path, max_value))


def validate_no_secret_policy(document: dict[str, Any], document_id: str) -> dict[str, Any]:
    """Validate that the input declares and follows no-secret rules."""
    policy = require_dict(document.get("no_secret_policy"), f"{document_id}.no_secret_policy")
    if require_bool(
        policy.get("key_material_included"),
        f"{document_id}.no_secret_policy.key_material_included",
    ):
        raise DropAuthorizationPayloadError(f"{document_id} includes key material")
    if require_bool(
        policy.get("mnemonic_included"),
        f"{document_id}.no_secret_policy.mnemonic_included",
    ):
        raise DropAuthorizationPayloadError(f"{document_id} includes a mnemonic")
    if require_bool(
        policy.get("production_payload"),
        f"{document_id}.no_secret_policy.production_payload",
    ):
        raise DropAuthorizationPayloadError(f"{document_id} claims production payload status")

    def walk(value: Any, path: str) -> None:
        if isinstance(value, dict):
            for key, nested in value.items():
                nested_path = f"{path}.{key}"
                if (
                    fixture_checker.SECRET_KEY_RE.search(str(key))
                    and "no_secret_policy" not in path
                ):
                    raise DropAuthorizationPayloadError(
                        f"{document_id} uses secret-like key name at {nested_path}"
                    )
                walk(nested, nested_path)
        elif isinstance(value, list):
            for index, nested in enumerate(value):
                walk(nested, f"{path}[{index}]")
        elif isinstance(value, str) and fixture_checker.SECRET_KEY_RE.search(value):
            if path.endswith(".description") or "no_secret_policy" in path:
                return
            raise DropAuthorizationPayloadError(
                f"{document_id} contains secret-like text at {path}"
            )

    walk(document, document_id)
    return {
        "key_material_included": False,
        "mnemonic_included": False,
        "production_payload": False,
    }


def derive_drop_id(signer: str, message: dict[str, Any]) -> str:
    """Derive the StreamDrops drop ID from signer, epoch, nonce, and salt."""
    return fixture_checker.keccak_hex(
        fixture_checker.abi_encode_static(
            [
                ("bytes32", fixture_checker.keccak_hex(fixture_checker.DROP_ID_TYPE.encode("utf-8"))),
                ("address", signer),
                ("uint256", message["signerEpoch"]),
                ("uint256", message["nonce"]),
                ("uint256", message["salt"]),
            ]
        )
    )


def typed_data_from_input(document: dict[str, Any], document_id: str) -> tuple[str, str, dict[str, Any]]:
    """Build canonical typed data from one no-secret payload input."""
    domain_input = require_dict(document.get("domain"), f"{document_id}.domain")
    sale_input = require_dict(document.get("sale"), f"{document_id}.sale")
    signer = require_address(document.get("signer"), f"{document_id}.signer")
    token_data = require_string(sale_input.get("tokenData"), f"{document_id}.sale.tokenData")

    sale_mode_name = require_string(sale_input.get("mode"), f"{document_id}.sale.mode")
    if sale_mode_name not in SALE_MODES:
        modes = ", ".join(sorted(SALE_MODES))
        raise DropAuthorizationPayloadError(
            f"{document_id}.sale.mode must be one of: {modes}"
        )
    sale_mode = SALE_MODES[sale_mode_name]

    domain = {
        "name": fixture_checker.EIP712_NAME,
        "version": fixture_checker.EIP712_VERSION,
        "chainId": require_uint(domain_input.get("chainId"), f"{document_id}.domain.chainId"),
        "verifyingContract": require_address(
            domain_input.get("verifyingContract"),
            f"{document_id}.domain.verifyingContract",
        ),
    }
    message: dict[str, Any] = {
        "dropId": "0x" + "0" * 64,
        "poster": require_address(sale_input.get("poster"), f"{document_id}.sale.poster"),
        "recipient": require_address(sale_input.get("recipient"), f"{document_id}.sale.recipient"),
        "payer": require_address(sale_input.get("payer"), f"{document_id}.sale.payer"),
        "collectionId": decimal_string(sale_input.get("collectionId"), f"{document_id}.sale.collectionId"),
        "saleMode": sale_mode,
        "tokenDataHash": fixture_checker.keccak_hex(token_data.encode("utf-8")),
        "price": decimal_string(sale_input.get("price"), f"{document_id}.sale.price"),
        "quantity": decimal_string(sale_input.get("quantity"), f"{document_id}.sale.quantity"),
        "auctionReservePrice": decimal_string(
            sale_input.get("auctionReservePrice"),
            f"{document_id}.sale.auctionReservePrice",
        ),
        "auctionEndTime": decimal_string(
            sale_input.get("auctionEndTime"),
            f"{document_id}.sale.auctionEndTime",
        ),
        "salt": decimal_string(sale_input.get("salt"), f"{document_id}.sale.salt"),
        "nonce": decimal_string(sale_input.get("nonce"), f"{document_id}.sale.nonce"),
        "deadline": decimal_string(sale_input.get("deadline"), f"{document_id}.sale.deadline"),
        "signerEpoch": decimal_string(
            sale_input.get("signerEpoch"),
            f"{document_id}.sale.signerEpoch",
        ),
    }
    message["dropId"] = derive_drop_id(signer, message)

    typed_data = {
        "types": {
            "EIP712Domain": fixture_checker.EIP712_DOMAIN_FIELDS,
            "DropAuthorization": fixture_checker.DROP_AUTHORIZATION_FIELDS,
        },
        "primaryType": "DropAuthorization",
        "domain": domain,
        "message": message,
    }
    validate_typed_data(typed_data, token_data, document_id)
    return signer, token_data, typed_data


def validate_typed_data(typed_data: dict[str, Any], token_data: str, document_id: str) -> None:
    """Validate generated typed data against the canonical fixture rules."""
    try:
        fixture_checker.validate_types(typed_data, document_id)
        fixture_checker.validate_domain(typed_data, document_id)
        fixture_checker.validate_message(typed_data, token_data, document_id)
    except fixture_checker.DropAuthorizationFixtureError as exc:
        raise DropAuthorizationPayloadError(str(exc)) from exc


def build_payload(document: dict[str, Any], document_id: str = "payload") -> dict[str, Any]:
    """Build a deterministic unsigned payload artifact."""
    if document.get("schema_version") != INPUT_SCHEMA_VERSION:
        raise DropAuthorizationPayloadError(f"{document_id}.schema_version mismatch")
    description = require_string(document.get("description"), f"{document_id}.description")
    no_secret_policy = validate_no_secret_policy(document, document_id)
    signer, token_data, typed_data = typed_data_from_input(document, document_id)
    derived = fixture_checker.compute_derived(typed_data, token_data, signer)

    if typed_data["message"]["dropId"] != derived["drop_id"]:
        raise DropAuthorizationPayloadError(f"{document_id}.dropId derivation mismatch")
    if typed_data["message"]["tokenDataHash"] != derived["token_data_hash"]:
        raise DropAuthorizationPayloadError(f"{document_id}.tokenDataHash mismatch")

    return {
        "schema_version": OUTPUT_SCHEMA_VERSION,
        "generated_by": f"scripts/generate_drop_authorization_payload.py:{GENERATOR_VERSION}",
        "description": description,
        "source": {
            "input_schema": INPUT_SCHEMA_VERSION,
            "generator": "scripts/generate_drop_authorization_payload.py",
            "canonical_checker": "scripts/check_drop_authorization_fixtures.py",
            "adr": "docs/adr/0001-drop-authorization.md",
        },
        "no_secret_policy": no_secret_policy,
        "signing_status": "unsigned",
        "typed_data": typed_data,
        "token_data": token_data,
        "derived": {
            "signer": signer,
            **derived,
        },
        "operator_notes": [
            "Submit typed_data and token_data to an external signer or signing service.",
            "Retain the returned signature, signer identity, signer epoch, reviewer approval, and command evidence separately.",
            "This artifact is local no-secret tooling evidence and is not a production readiness claim.",
        ],
    }


def write_or_check_output(payload: dict[str, Any], output_path: Path, check: bool) -> None:
    """Write a payload output, or check that the committed output is current."""
    expected = json_text(payload)
    if check:
        if not output_path.is_file():
            raise DropAuthorizationPayloadError(f"missing generated output: {output_path}")
        actual = output_path.read_text(encoding="utf-8")
        if actual != expected:
            raise DropAuthorizationPayloadError(
                f"{output_path} is stale; rerun scripts/generate_drop_authorization_payload.py"
            )
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(expected, encoding="utf-8", newline="\n")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="payload input JSON template")
    parser.add_argument("--output", type=Path, help="generated payload output path")
    parser.add_argument(
        "--check",
        action="store_true",
        help="check that --output already matches the deterministic generated payload",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    args = parse_args(argv)
    if args.check and args.output is None:
        raise DropAuthorizationPayloadError("--check requires --output")

    document = read_json(args.input)
    payload = build_payload(document, args.input.as_posix())
    if args.output is not None:
        write_or_check_output(payload, args.output, args.check)
    else:
        sys.stdout.write(json_text(payload))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except DropAuthorizationPayloadError as exc:
        print(f"drop authorization payload generation failed: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
