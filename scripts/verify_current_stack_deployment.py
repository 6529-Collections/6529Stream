#!/usr/bin/env python3
"""Compare a public Foundry deployment with its exact compiler build-info.

This checks bytes, not release readiness. Immutable words are observed and
reported; ignoring their compiler-declared ranges does not validate their meaning.
Only read-only JSON-RPC methods are used. RPC URLs and full broadcasts are not
copied into the report.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import urllib.request
from pathlib import Path
from typing import Any

from eth_hash.auto import keccak


class VerificationError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise VerificationError(message)


def unprefixed(value: str) -> str:
    return value[2:] if value.startswith("0x") else value


def hex_bytes(value: str) -> bytes:
    require(isinstance(value, str), "Expected hexadecimal bytes")
    value = unprefixed(value)
    require(bool(re.fullmatch(r"(?:[a-fA-F0-9]{2})*", value)), "Invalid hexadecimal bytes")
    return bytes.fromhex(value)


def address(value: str) -> str:
    require(len(hex_bytes(value)) == 20, "Expected a 20-byte address")
    return "0x" + hex_bytes(value).hex()


def digest(value: bytes) -> str:
    return "0x" + keccak(value).hex()


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8-sig"))


def references(value: dict, size: int, *, links: bool = False) -> dict:
    result = {}
    if links:
        value = {f"{source}:{name}": positions for source, names in value.items()
                 for name, positions in names.items()}
    occupied = set()
    for key, positions in value.items():
        require(bool(positions), "Empty compiler reference")
        result[key] = []
        for position in positions:
            start, length = position["start"], position["length"]
            require(type(start) is int and type(length) is int, "Noninteger compiler reference")
            require(start >= 0 and length > 0 and start + length <= size,
                    "Compiler reference outside bytecode")
            require(not links or length == 20, "Library reference must be 20 bytes")
            span = set(range(start, start + length))
            require(not occupied.intersection(span), "Overlapping compiler references")
            occupied.update(span)
            result[key].append((start, length))
    return result


def linked_bytes(bytecode: dict, libraries: dict[str, str]) -> tuple[bytes, list]:
    raw = unprefixed(bytecode["object"])
    require(len(raw) % 2 == 0, "Odd compiler bytecode length")
    links = references(bytecode.get("linkReferences", {}), len(raw) // 2, links=True)
    observations = []
    for name, positions in links.items():
        require(name in libraries, f"Missing linked library: {name}")
        linked_address = address(libraries[name])
        for start, length in positions:
            raw = raw[:start * 2] + linked_address[2:] + raw[(start + length) * 2:]
        observations.append({"library": name, "address": linked_address,
                             "offsets": [start for start, _ in positions]})
    return hex_bytes(raw), observations


def compare_runtime(contract: dict, actual: bytes, deployed_address: str,
                    libraries: dict[str, str]) -> dict:
    expected, links = linked_bytes(contract["evm"]["deployedBytecode"], libraries)
    require(len(actual) == len(expected) and bool(actual), "Runtime length differs from compiler")
    expected = bytearray(expected)
    immutable_ranges = references(
        contract["evm"]["deployedBytecode"].get("immutableReferences", {}), len(expected))
    self_fixup = None
    self_ranges = []
    if "library_deploy_address" in immutable_ranges:
        require(contract["kind"] == "library", "Library deploy-address reference on a non-library")
        self_ranges = immutable_ranges.pop("library_deploy_address")
        for start, length in self_ranges:
            require(length == 32 and expected[start:start + length] == bytes(32),
                    "Unknown compiler library deploy-address encoding")
            expected[start:start + length] = bytes(12) + hex_bytes(deployed_address)
            require(actual[start:start + length] == expected[start:start + length],
                    "Solidity library self-address differs")
        self_fixup = {"encoding": "compiler library_deploy_address immutable",
                      "references": [{"offset": start, "length": length} for start, length in self_ranges],
                      "address": address(deployed_address), "verified": True}
    elif contract["kind"] == "library" and expected[:21] == b"\x73" + bytes(20):
        self_ranges = [(1, 20)]
        expected[1:21] = hex_bytes(deployed_address)
        self_fixup = {"offset": 1, "length": 20, "address": address(deployed_address),
                      "verified": actual[1:21] == expected[1:21]}
        require(self_fixup["verified"], "Solidity library self-address differs")
    link_ranges = references(contract["evm"]["deployedBytecode"].get("linkReferences", {}),
                             len(expected), links=True)
    reserved = {i for positions in link_ranges.values() for start, length in positions
                for i in range(start, start + length)}
    for start, length in self_ranges:
        reserved.update(range(start, start + length))
    observations = []
    masked = set()
    for ast_id, positions in immutable_ranges.items():
        words = []
        for start, length in positions:
            span = set(range(start, start + length))
            require(not span.intersection(reserved), "Immutable reference overlaps a checked library address")
            masked.update(span)
            words.append({"offset": start, "length": length,
                          "value": "0x" + actual[start:start + length].hex()})
        require(len({item["value"] for item in words}) == 1,
                "Repeated references to one immutable have different values")
        observations.append({"ast_id": ast_id, **contract["immutable_names"].get(ast_id, {}),
                             "observed_words": words, "semantic_value_verified": False})
    differences = [i for i, (left, right) in enumerate(zip(expected, actual))
                   if i not in masked and left != right]
    require(not differences, f"Runtime differs outside immutable references at byte {differences[:1]}")
    return {"runtime_keccak256": digest(actual), "runtime_bytes": len(actual),
            "compiler_runtime_template_keccak256": digest(bytes(expected)),
            "non_immutable_bytes_verified": len(actual) - len(masked),
            "immutable_observations": observations, "linked_libraries": links,
            "library_self_address": self_fixup}


def walk(value: Any):
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk(child)


def load_contracts(build_paths: list[Path], artifacts: Path | None = None) -> tuple[dict, list]:
    contracts, builds = {}, []
    for path in build_paths:
        raw = path.read_bytes()
        build = json.loads(raw)
        require("input" in build and "contracts" in build.get("output", {}),
                "Full compiler build-info with input/output is required")
        build_hash = hashlib.sha256(raw).hexdigest()
        builds.append({"file": path.name, "sha256": build_hash,
                       "compiler": build.get("solcLongVersion", build.get("solcVersion")),
                       "compiler_input_sha256": hashlib.sha256(json.dumps(
                           build["input"], sort_keys=True, separators=(",", ":")).encode()).hexdigest()})
        names, kinds = {}, {}
        for source, output in build["output"].get("sources", {}).items():
            for node in walk(output.get("ast", {})):
                if node.get("nodeType") == "VariableDeclaration" and node.get("mutability") == "immutable":
                    names[str(node["id"])] = {"name": node.get("name"), "source": source,
                                               "type": node.get("typeDescriptions", {}).get("typeString")}
                if node.get("nodeType") == "ContractDefinition":
                    kinds[f"{source}:{node['name']}"] = node["contractKind"]
        for source, entries in build["output"]["contracts"].items():
            for name, output in entries.items():
                if not output.get("evm", {}).get("bytecode", {}).get("object"):
                    continue
                identity = f"{source}:{name}"
                item = {"identity": identity, "evm": output["evm"], "kind": kinds.get(identity, "contract"),
                        "immutable_names": names, "build_info_sha256": build_hash}
                if artifacts:
                    candidates = []
                    for artifact_path in (artifacts / Path(source).name).glob(f"{name}*.json"):
                        artifact = read_json(artifact_path)
                        target = artifact.get("metadata", {}).get("settings", {}).get("compilationTarget", {})
                        if target != {source: name}:
                            continue
                        if all(unprefixed(artifact.get(field, {}).get("object", "")) ==
                               unprefixed(output["evm"][field]["object"])
                               and artifact[field].get("linkReferences", {}) == output["evm"][field].get("linkReferences", {})
                               for field in ("bytecode", "deployedBytecode")):
                            require(artifact["deployedBytecode"].get("immutableReferences", {}) ==
                                    output["evm"]["deployedBytecode"].get("immutableReferences", {}),
                                    "Artifact immutable references differ from build-info")
                            candidates.append(hashlib.sha256(artifact_path.read_bytes()).hexdigest())
                    item["artifact_sha256"] = candidates
                if identity in contracts:
                    require(contracts[identity]["evm"] == item["evm"],
                            f"Ambiguous compiler profiles for {identity}; select one exact build-info")
                contracts[identity] = item
    return contracts, builds


class PublicRpc:
    ALLOWED = {"eth_chainId", "eth_getBlockByNumber", "eth_getTransactionByHash",
               "eth_getTransactionReceipt", "eth_getCode"}

    def __init__(self, url: str):
        self.url, self.cache = url, {}

    def __call__(self, method: str, params: list):
        require(method in self.ALLOWED, "Only read-only RPC methods are permitted")
        key = json.dumps([method, params])
        if key not in self.cache:
            payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
            request = urllib.request.Request(self.url, data=payload, headers={"Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(request, timeout=30) as response:
                    result = json.load(response)
            except Exception as exc:
                raise VerificationError(f"Public RPC {method} failed; endpoint details withheld") from exc
            require("result" in result and "error" not in result, f"Public RPC {method} returned an error")
            self.cache[key] = result["result"]
        return self.cache[key]


def verify(contracts: dict, broadcast: dict, rpc, runtime_only: dict[str, str] | None = None) -> dict:
    chain = int(rpc("eth_chainId", []), 16)
    require(chain == int(broadcast["chain"]), "Broadcast chain differs from RPC")
    block = rpc("eth_getBlockByNumber", ["latest", False])
    block_number = block["number"]
    libraries = {}
    for item in broadcast.get("libraries", []):
        identity, value = item.rsplit(":", 1)
        require(identity not in libraries or libraries[identity] == address(value), "Conflicting library addresses")
        libraries[identity] = address(value)
    records, verified_addresses = [], set()
    for entry in broadcast["transactions"]:
        if entry["transactionType"] not in ("CREATE", "CREATE2"):
            continue
        tx_hash = entry.get("hash")
        require(bool(tx_hash), "Deployment has no mined transaction hash (dry run is insufficient)")
        tx = rpc("eth_getTransactionByHash", [tx_hash])
        receipt = rpc("eth_getTransactionReceipt", [tx_hash])
        require(bool(tx) and bool(receipt), "Deployment transaction or receipt missing")
        require(receipt["transactionHash"].lower() == tx_hash.lower() and int(receipt["status"], 16) == 1,
                "Deployment receipt is unsuccessful or belongs to another transaction")
        require(int(receipt["blockNumber"], 16) <= int(block_number, 16), "Receipt is newer than verification block")
        expected_tx = entry["transaction"]
        require(hex_bytes(tx["input"]) == hex_bytes(expected_tx["input"]), "Public transaction input differs from broadcast")
        require(address(tx["from"]) == address(expected_tx["from"]) and
                int(tx["nonce"], 16) == int(expected_tx["nonce"], 16) and
                int(tx.get("value", "0x0"), 16) == int(expected_tx.get("value", "0x0"), 16),
                "Public deployment sender, nonce or value differs from broadcast")
        deployed_address = address(entry["contractAddress"])
        initcode = hex_bytes(tx["input"])
        creation = {"transaction_hash": tx_hash, "receipt_block": receipt["blockNumber"],
                    "receipt_block_hash": receipt["blockHash"], "type": entry["transactionType"]}
        if entry["transactionType"] == "CREATE":
            require(tx["to"] is None and address(receipt["contractAddress"]) == deployed_address,
                    "CREATE receipt address or transaction destination differs")
        else:
            require(address(tx["to"]) == address(expected_tx["to"]) and len(initcode) > 32,
                    "CREATE2 deployer or calldata missing")
            salt, initcode = initcode[:32], initcode[32:]
            derived = address("0x" + keccak(b"\xff" + hex_bytes(tx["to"]) + salt + keccak(initcode))[-20:].hex())
            require(derived == deployed_address, "CREATE2 address does not match calldata commitment")
            creation.update({"deployer": address(tx["to"]), "salt": "0x" + salt.hex(),
                             "proof": "successful deployer calldata and CREATE2 address commitment; no internal trace"})
        actual = hex_bytes(rpc("eth_getCode", [deployed_address, block_number]))
        matches = []
        for identity, contract in contracts.items():
            if entry.get("contractName") and identity.rsplit(":", 1)[1] != entry["contractName"]:
                continue
            try:
                prefix, _ = linked_bytes(contract["evm"]["bytecode"], libraries)
            except VerificationError:
                continue
            if prefix and initcode.startswith(prefix):
                matches.append((contract, prefix))
        require(len(matches) <= 1, "Creation bytecode matches multiple compiler contracts")
        record = {"address": deployed_address, "creation": creation, "initcode_keccak256": digest(initcode)}
        if matches:
            contract, prefix = matches[0]
            if "artifact_sha256" in contract:
                require(bool(contract["artifact_sha256"]), f"No exact Foundry artifact for {contract['identity']}")
            record.update({"contract": contract["identity"], "build_info_sha256": contract["build_info_sha256"],
                           "artifact_sha256": contract.get("artifact_sha256"),
                           "creation_prefix_bytes": len(prefix), "creation_prefix_verified": True,
                           "constructor_arguments_hex": "0x" + initcode[len(prefix):].hex(),
                           "constructor_arguments_semantically_verified": False,
                           **compare_runtime(contract, actual, deployed_address, libraries)})
        else:
            preamble = bytes.fromhex("600b5981380380925939f3")
            require(not entry.get("contractName") and initcode.startswith(preamble + b"\x00") and
                    actual == initcode[len(preamble):] and len(actual) <= 24576,
                    f"No compiler creation prefix or exact SSTORE2 data creation for {deployed_address}")
            record.update({"contract": "SSTORE2 data", "creation_prefix_verified": True,
                           "runtime_keccak256": digest(actual), "runtime_bytes": len(actual),
                           "exact_data_runtime_verified": True})
        verified_addresses.add(deployed_address)
        records.append(record)
    require(bool(records), "No mined deployments to verify")
    # Foundry's additionalContracts are a supplied execution trace, not a public
    # transaction input. Check the enclosing public call and resulting bytecode,
    # but do not promote the supplied internal initcode to independently proven.
    for entry in broadcast["transactions"]:
        if not entry.get("additionalContracts"):
            continue
        tx_hash = entry.get("hash")
        require(bool(tx_hash), "Internal deployment has no enclosing transaction")
        tx = rpc("eth_getTransactionByHash", [tx_hash])
        receipt = rpc("eth_getTransactionReceipt", [tx_hash])
        require(bool(tx) and bool(receipt) and int(receipt["status"], 16) == 1 and
                receipt["transactionHash"].lower() == tx_hash.lower() and
                int(receipt["blockNumber"], 16) <= int(block_number, 16),
                "Internal deployment enclosing transaction is not successful and mined")
        require(hex_bytes(tx["input"]) == hex_bytes(entry["transaction"]["input"]) and
                address(tx["to"]) == address(entry["transaction"]["to"]),
                "Internal deployment enclosing public call differs from broadcast")
        for internal in entry["additionalContracts"]:
            deployed_address = address(internal["address"])
            require(deployed_address not in verified_addresses, "Duplicate internal deployment address")
            actual = hex_bytes(rpc("eth_getCode", [deployed_address, block_number]))
            initcode = hex_bytes(internal["initCode"])
            record = {"address": deployed_address, "enclosing_transaction_hash": tx_hash,
                      "creation_prefix_verified": False,
                      "creation_limitation": "Internal initcode supplied by Foundry; no independent public execution trace",
                      "supplied_initcode_keccak256": digest(initcode)}
            name = internal.get("contractName")
            if name:
                matches = []
                for identity, contract in contracts.items():
                    if identity.rsplit(":", 1)[1] == name:
                        prefix, _ = linked_bytes(contract["evm"]["bytecode"], libraries)
                        if initcode.startswith(prefix):
                            matches.append((contract, prefix))
                require(len(matches) == 1, "Internal initcode has no unique compiler match")
                contract, prefix = matches[0]
                if "artifact_sha256" in contract:
                    require(bool(contract["artifact_sha256"]), "Internal deployment artifact missing")
                record.update({"contract": contract["identity"],
                               "build_info_sha256": contract["build_info_sha256"],
                               "artifact_sha256": contract.get("artifact_sha256"),
                               "supplied_creation_prefix_matches_compiler": True,
                               "constructor_arguments_hex": "0x" + initcode[len(prefix):].hex(),
                               "constructor_arguments_semantically_verified": False,
                               **compare_runtime(contract, actual, deployed_address, libraries)})
            else:
                preamble = bytes.fromhex("600b5981380380925939f3")
                require(initcode.startswith(preamble + b"\x00") and actual == initcode[len(preamble):]
                        and len(actual) <= 24576, "Internal data runtime differs from supplied SSTORE2 initcode")
                record.update({"contract": "SSTORE2 data", "runtime_keccak256": digest(actual),
                               "runtime_bytes": len(actual), "exact_data_runtime_verified": True})
            records.append(record)
            verified_addresses.add(deployed_address)
    extra = {**{value: name for name, value in libraries.items()}, **(runtime_only or {})}
    for deployed_address, identity in extra.items():
        deployed_address = address(deployed_address)
        if deployed_address in verified_addresses:
            require(any(row.get("contract") == identity and row["address"] == deployed_address for row in records),
                    "Runtime-only or linked-library identity conflicts with verified creation")
            continue
        require(identity in contracts, f"Unknown runtime-only compiler contract {identity}")
        contract = contracts[identity]
        if "artifact_sha256" in contract:
            require(bool(contract["artifact_sha256"]), f"No exact Foundry artifact for {identity}")
        actual = hex_bytes(rpc("eth_getCode", [deployed_address, block_number]))
        records.append({"address": deployed_address, "contract": identity,
                        "build_info_sha256": contract["build_info_sha256"],
                        "artifact_sha256": contract.get("artifact_sha256"),
                        "creation_prefix_verified": False,
                        "creation_limitation": "Runtime-only read; no creation transaction or internal trace supplied",
                        **compare_runtime(contract, actual, deployed_address, libraries)})
    return {"schema": "6529stream.current-deployment-bytecode-check.v1", "chain_id": chain,
            "verification_block": block_number, "verification_block_hash": block["hash"],
            "result": "bytecode comparisons passed", "contracts": records,
            "limitations": ["Compiler outputs are supplied evidence, not independently recompiled by this helper.",
                            "Constructor arguments and observed immutable values are not semantically validated.",
                            "Runtime-only records do not prove their creation path.",
                            "This report does not assert audit completion or release readiness."]}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-info", type=Path, action="append", required=True)
    parser.add_argument("--artifacts", type=Path)
    parser.add_argument("--broadcast", type=Path, required=True)
    parser.add_argument("--rpc-url", required=True)
    parser.add_argument("--runtime-only", action="append", default=[], metavar="ADDRESS=SOURCE:CONTRACT")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        contracts, builds = load_contracts(args.build_info, args.artifacts)
        extras = dict(item.split("=", 1) for item in args.runtime_only)
        report = verify(contracts, read_json(args.broadcast), PublicRpc(args.rpc_url), extras)
        report["builds"] = builds
        report["broadcast_sha256"] = hashlib.sha256(args.broadcast.read_bytes()).hexdigest()
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print(f"Verified {len(report['contracts'])} deployment/runtime records; report: {args.output}")
        return 0
    except (VerificationError, KeyError, TypeError, ValueError, OSError) as exc:
        # Generic IO/format failures do not expose RPC endpoints or raw broadcast data.
        print(str(exc) if isinstance(exc, VerificationError) else "Invalid or unreadable verification input", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
