#!/usr/bin/env python3
"""Generate deployment-manifest inputs from sanitized Foundry broadcasts."""

from __future__ import annotations

import argparse
import copy
import filecmp
import hashlib
import json
import re
import sys
import tempfile
from collections import Counter
from pathlib import Path
from typing import Any


INPUT_SCHEMA = "6529stream.deployment-manifest-input.v1"
BROADCAST_EVIDENCE_SCHEMA = "6529stream.foundry-broadcast-evidence.v1"
GENERATOR_VERSION = "1"

DEFAULT_TEMPLATE = Path("deployments/config/anvil-6529stream-v0.1.0-001.json")
DEFAULT_BROADCAST = Path("deployments/broadcasts/anvil-6529stream-v0.1.0-001-run-latest.json")
DEFAULT_OUTPUT = Path("deployments/config/anvil-6529stream-v0.1.0-001-broadcast.json")
DEFAULT_MANIFEST_OUTPUT = Path("deployments/examples/anvil-6529stream-v0.1.0-001-broadcast.json")

ADDRESS_RE = re.compile(r"^0x[0-9a-fA-F]{40}$")
TX_HASH_RE = re.compile(r"^0x[0-9a-fA-F]{64}$")
SUCCESS_STATUS_STRINGS = frozenset({"0x1", "1"})
FORBIDDEN_SECRET_KEYS = frozenset(
    {
        "mnemonic",
        "mnemonics",
        "privateKey",
        "privateKeys",
        "private_key",
        "private_keys",
        "rpcUrl",
        "rpcUrls",
        "rpc_url",
        "rpc_urls",
    }
)


class BroadcastManifestError(RuntimeError):
    pass


def load_json(path: Path) -> Any:
    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError as exc:
        raise BroadcastManifestError(f"missing required file: {path}") from exc
    except json.JSONDecodeError as exc:
        raise BroadcastManifestError(f"invalid JSON in {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, indent=2, ensure_ascii=False)
        handle.write("\n")


def sha256_file(path: Path) -> str:
    with path.open("rb") as handle:
        return "sha256:" + hashlib.sha256(handle.read()).hexdigest()


def normalize_path(path: Path) -> str:
    return path.as_posix()


def require_dict(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise BroadcastManifestError(f"{path} must be an object")
    return value


def require_list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise BroadcastManifestError(f"{path} must be an array")
    return value


def require_string(value: Any, path: str) -> str:
    if not isinstance(value, str) or value == "":
        raise BroadcastManifestError(f"{path} must be a non-empty string")
    return value


def require_positive_int(value: Any, path: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool):
        raise BroadcastManifestError(f"{path} must be an integer")
    if value < 1:
        raise BroadcastManifestError(f"{path} must be greater than zero")
    return value


def normalize_address(value: Any, path: str) -> str:
    address = require_string(value, path)
    if not ADDRESS_RE.fullmatch(address):
        raise BroadcastManifestError(f"{path} must be a 20-byte hex address")
    if address.lower() == "0x" + ("0" * 40):
        raise BroadcastManifestError(f"{path} cannot be the zero address")
    return address.lower()


def normalize_tx_hash(value: Any, path: str) -> str:
    tx_hash = require_string(value, path)
    if not TX_HASH_RE.fullmatch(tx_hash):
        raise BroadcastManifestError(f"{path} must be a 32-byte transaction hash")
    return tx_hash.lower()


def assert_no_secret_keys(value: Any, path: str = "$") -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            if str(key) in FORBIDDEN_SECRET_KEYS:
                raise BroadcastManifestError(f"broadcast contains forbidden secret-like key: {path}.{key}")
            assert_no_secret_keys(child, f"{path}.{key}")
    elif isinstance(value, list):
        for index, child in enumerate(value):
            assert_no_secret_keys(child, f"{path}[{index}]")


def expected_contract_names(template: dict[str, Any]) -> list[str]:
    schema = require_string(template.get("schema_version"), "schema_version")
    if schema != INPUT_SCHEMA:
        raise BroadcastManifestError(f"unsupported template schema: {schema}")

    manifest = require_dict(template.get("manifest"), "manifest")
    contracts = require_list(manifest.get("contracts"), "manifest.contracts")
    names = [
        require_string(require_dict(contract, "manifest.contracts[]").get("name"), "contract.name")
        for contract in contracts
    ]
    duplicates = sorted(name for name, count in Counter(names).items() if count > 1)
    if duplicates:
        raise BroadcastManifestError(f"template has duplicate contract entries: {', '.join(duplicates)}")
    return names


def template_chain_id(template: dict[str, Any]) -> int:
    manifest = require_dict(template.get("manifest"), "manifest")
    network = require_dict(manifest.get("network"), "manifest.network")
    return require_positive_int(network.get("chain_id"), "manifest.network.chain_id")


def receipt_map(receipts: Any) -> dict[str, dict[str, Any]]:
    mapped: dict[str, dict[str, Any]] = {}
    if isinstance(receipts, dict):
        iterable = receipts.values()
    elif isinstance(receipts, list):
        iterable = receipts
    else:
        raise BroadcastManifestError("broadcast.receipts must be an array or object")

    for index, receipt_value in enumerate(iterable):
        receipt = require_dict(receipt_value, f"broadcast.receipts[{index}]")
        tx_hash = receipt.get("transactionHash") or receipt.get("hash")
        normalized_hash = normalize_tx_hash(tx_hash, f"broadcast.receipts[{index}].transactionHash")
        if normalized_hash in mapped:
            raise BroadcastManifestError(f"duplicate receipt for transaction hash: {normalized_hash}")
        mapped[normalized_hash] = receipt
    return mapped


def is_deployment_transaction(transaction: dict[str, Any]) -> bool:
    tx_type = transaction.get("transactionType")
    has_contract_fields = bool(transaction.get("contractName") or transaction.get("contractAddress"))
    return tx_type in {"CREATE", "CREATE2"} or (tx_type is None and has_contract_fields)


def require_success_receipt(
    receipt: dict[str, Any],
    contract_name: str,
    tx_hash: str,
    address: str,
) -> None:
    receipt_hash = normalize_tx_hash(
        receipt.get("transactionHash") or receipt.get("hash"),
        f"receipt.{contract_name}.transactionHash",
    )
    if receipt_hash != tx_hash:
        raise BroadcastManifestError(f"{contract_name} receipt hash does not match transaction hash")

    status = receipt.get("status")
    if not is_success_status(status):
        raise BroadcastManifestError(f"{contract_name} deployment receipt did not succeed")

    receipt_address = receipt.get("contractAddress")
    if receipt_address is not None:
        normalized_receipt_address = normalize_address(
            receipt_address, f"receipt.{contract_name}.contractAddress"
        )
        if normalized_receipt_address != address:
            raise BroadcastManifestError(f"{contract_name} receipt address does not match transaction")


def is_success_status(value: Any) -> bool:
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return value == 1
    if isinstance(value, str):
        return value.lower() in SUCCESS_STATUS_STRINGS
    return False


def extract_deployments(
    broadcast: dict[str, Any],
    expected_names: list[str],
    expected_chain_id: int,
) -> dict[str, dict[str, str]]:
    assert_no_secret_keys(broadcast)

    chain_id = require_positive_int(broadcast.get("chain"), "broadcast.chain")
    if chain_id != expected_chain_id:
        raise BroadcastManifestError(
            f"broadcast chain {chain_id} does not match manifest chain {expected_chain_id}"
        )

    transactions = require_list(broadcast.get("transactions"), "broadcast.transactions")
    receipts = receipt_map(broadcast.get("receipts"))
    deployments: dict[str, dict[str, str]] = {}

    for index, transaction_value in enumerate(transactions):
        transaction = require_dict(transaction_value, f"broadcast.transactions[{index}]")
        if not is_deployment_transaction(transaction):
            continue

        contract_name = require_string(
            transaction.get("contractName"), f"broadcast.transactions[{index}].contractName"
        )
        address = normalize_address(
            transaction.get("contractAddress"),
            f"broadcast.transactions[{index}].contractAddress",
        )
        tx_hash = normalize_tx_hash(
            transaction.get("hash") or transaction.get("transactionHash"),
            f"broadcast.transactions[{index}].hash",
        )

        if contract_name in deployments:
            raise BroadcastManifestError(f"duplicate deployment transaction for {contract_name}")
        receipt = receipts.get(tx_hash)
        if receipt is None:
            raise BroadcastManifestError(f"missing receipt for {contract_name} deployment")
        require_success_receipt(receipt, contract_name, tx_hash, address)
        deployments[contract_name] = {
            "address": address,
            "transaction_hash": tx_hash,
        }

    expected_set = set(expected_names)
    actual_set = set(deployments)
    missing = sorted(expected_set - actual_set)
    unexpected = sorted(actual_set - expected_set)
    details = []
    if missing:
        details.append(f"missing deployments: {', '.join(missing)}")
    if unexpected:
        details.append(f"unexpected deployments: {', '.join(unexpected)}")
    if details:
        raise BroadcastManifestError("; ".join(details))

    address_counts = Counter(deployment["address"] for deployment in deployments.values())
    duplicate_addresses = sorted(address for address, count in address_counts.items() if count > 1)
    if duplicate_addresses:
        raise BroadcastManifestError(
            "duplicate deployment addresses: " + ", ".join(duplicate_addresses)
        )

    return deployments


def build_manifest_input(
    template_path: Path,
    broadcast_path: Path,
    output_path: Path,
    manifest_output_path: Path,
) -> dict[str, Any]:
    template = require_dict(load_json(template_path), str(template_path))
    broadcast = require_dict(load_json(broadcast_path), str(broadcast_path))
    names = expected_contract_names(template)
    chain_id = template_chain_id(template)
    deployments = extract_deployments(broadcast, names, chain_id)

    generated = copy.deepcopy(template)
    generated["output"] = normalize_path(manifest_output_path)
    generated["generated_by"] = f"scripts/generate_broadcast_manifest_input.py:{GENERATOR_VERSION}"
    generated["broadcast_evidence"] = {
        "schema_version": BROADCAST_EVIDENCE_SCHEMA,
        "broadcast_file": normalize_path(broadcast_path),
        "broadcast_sha256": sha256_file(broadcast_path),
        "template_config": normalize_path(template_path),
        "generated_config": normalize_path(output_path),
        "chain_id": chain_id,
        "deployments": [
            {
                "contract": name,
                "address": deployments[name]["address"],
                "transaction_hash": deployments[name]["transaction_hash"],
            }
            for name in names
        ],
    }

    manifest = require_dict(generated.get("manifest"), "manifest")
    manifest["deployment_version"] = require_string(
        manifest.get("deployment_version"), "manifest.deployment_version"
    ) + "-broadcast"
    manifest["rehearsal"] = require_dict(manifest.get("rehearsal"), "manifest.rehearsal")
    manifest["rehearsal"]["notes"] = (
        "Generated from a sanitized Foundry broadcast fixture. The fixture contains "
        "public deployment evidence only; it is not a live production broadcast."
    )

    contracts = require_list(manifest.get("contracts"), "manifest.contracts")
    for contract_value in contracts:
        contract = require_dict(contract_value, "manifest.contracts[]")
        name = require_string(contract.get("name"), "contract.name")
        contract["address"] = deployments[name]["address"]

    return generated


def generate_manifest_input(
    template_path: Path,
    broadcast_path: Path,
    output_path: Path,
    manifest_output_path: Path,
) -> Path:
    generated = build_manifest_input(
        template_path,
        broadcast_path,
        output_path,
        manifest_output_path,
    )
    write_json(output_path, generated)
    return output_path


def check_manifest_input(
    template_path: Path,
    broadcast_path: Path,
    output_path: Path,
    manifest_output_path: Path,
) -> int:
    generated = build_manifest_input(
        template_path,
        broadcast_path,
        output_path,
        manifest_output_path,
    )
    with tempfile.TemporaryDirectory() as temp_dir:
        expected = Path(temp_dir) / output_path.name
        write_json(expected, generated)
        if not output_path.exists():
            print(f"broadcast-derived manifest input is missing: {output_path}", file=sys.stderr)
            return 1
        if not filecmp.cmp(expected, output_path, shallow=False):
            print("broadcast-derived manifest input is out of date:", file=sys.stderr)
            print(f"  - changed {output_path.as_posix()}", file=sys.stderr)
            print(
                "run `python scripts/generate_broadcast_manifest_input.py` and commit the regenerated JSON",
                file=sys.stderr,
            )
            return 1
    print("broadcast-derived manifest input is current")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, default=DEFAULT_TEMPLATE)
    parser.add_argument("--broadcast", type=Path, default=DEFAULT_BROADCAST)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--manifest-output", type=Path, default=DEFAULT_MANIFEST_OUTPUT)
    parser.add_argument("--check", action="store_true")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    try:
        if args.check:
            return check_manifest_input(
                args.template,
                args.broadcast,
                args.output,
                args.manifest_output,
            )
        output_path = generate_manifest_input(
            args.template,
            args.broadcast,
            args.output,
            args.manifest_output,
        )
    except BroadcastManifestError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    print(output_path.as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
