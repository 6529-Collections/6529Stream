#!/usr/bin/env python3
"""Export allowlisted public observations from a completed current-stack demo.

The deployment runner and bytecode verifier perform live reads. This exporter
checks their supplied results and cross-references; it does not query the chain.
It excludes signer configuration, local paths, fee planning and raw broadcasts.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def encoded(value: object) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()


def sha256(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def public_hex(value: object, size: int) -> str:
    require(isinstance(value, str) and bool(re.fullmatch(r"0x[0-9a-fA-F]{%d}" % (size * 2), value)),
            "Invalid public hexadecimal identifier")
    return value.lower()


def number(value: object) -> int:
    require(isinstance(value, (int, str)) and not isinstance(value, bool), "Invalid public number")
    result = int(value, 16 if value.startswith("0x") else 10) if isinstance(value, str) else value
    require(result >= 0, "Negative public number")
    return result


def observations(state: dict, metadata: dict, verification: dict) -> dict:
    require(state.get("chainId") == 11155111 and verification.get("chain_id") == 11155111,
            "Sepolia observations required")
    require(state.get("demonstrated") is True and state.get("metadataState") == "final"
            and metadata.get("metadata_state") == "final", "Completed final-metadata demo required")
    require(verification.get("schema") == "6529stream.current-deployment-bytecode-check.v1"
            and verification.get("result") == "bytecode comparisons passed", "Successful bytecode check required")
    accounts = {name: public_hex(state["accounts"][name], 20)
                for name in ("deployer", "artist", "platform", "protocol")}
    addresses = {name: public_hex(value, 20) for name, value in state["addresses"].items()}
    verified = {public_hex(row["address"], 20) for row in verification["contracts"]}
    require(set(addresses.values()).issubset(verified), "Deployment address lacks bytecode observation")
    wallet = public_hex(state["wallet"], 20)
    require(wallet in verified, "Split wallet lacks bytecode observation")
    final_owner = public_hex(state["finalOwner"], 20)
    require(final_owner == accounts["artist"], "Demo final ownership differs from the artist")
    provider = state["providerResult"]
    require(len(provider) == 5 and provider[3] is True and provider[4] is True,
            "Real provider receipt and delivery readbacks required")
    require(public_hex(provider[1], 32) == public_hex(state["requestKey"], 32),
            "Provider result belongs to another request")
    receipts = {}
    for label, receipt in state["receipts"].items():
        require(bool(re.fullmatch(r"[A-Za-z0-9-]+", label)), "Invalid public receipt label")
        require(number(receipt["status"]) == 1, "Unsuccessful transaction in completed demo")
        receipts[label] = {
            "transaction_hash": public_hex(receipt["transactionHash"], 32),
            "block_number": number(receipt["blockNumber"]),
            "gas_used": number(receipt["gasUsed"]),
            "effective_gas_price_wei": str(number(receipt["effectiveGasPrice"])),
            "status": 1,
        }
    require({"paidMint", "requestEntropy", "artistWithdrawal", "protocolWithdrawal", "transfer"}
            .issubset(receipts), "Incomplete mint, entropy, withdrawal or transfer receipts")
    require(any(label.startswith("deployment-") for label in receipts), "Deployment receipts absent")
    vrf = state["vrf"]
    commit = state["deploymentSourceCommit"]
    require(bool(re.fullmatch(r"[0-9a-f]{40}", commit)), "Invalid deployment runner source commit")
    return {
        "schema": "6529stream.current-sepolia-observations.v1", "chain_id": 11155111,
        "deployment_runner_commit": commit,
        "accounts": accounts, "addresses": addresses, "split_wallet": wallet,
        "token_id": str(number(state["tokenId"])), "mint_price_wei": str(number(state["mintPriceWei"])),
        "final_owner": final_owner, "metadata_state": "final",
        "vrf": {"coordinator": public_hex(vrf["coordinator"], 20),
                "key_hash": public_hex(vrf["keyHash"], 32),
                "subscription_id": str(number(state["subscriptionId"])),
                "request_id": str(number(state["providerRequestId"])),
                "request_key": public_hex(state["requestKey"], 32),
                "confirmations": number(vrf["confirmations"]),
                "callback_gas": number(vrf["callbackGas"]),
                "native_payment": vrf["nativePayment"] is True,
                "provider_status": number(provider[0]),
                "raw_randomness_hash": public_hex(provider[2], 32), "received": True, "delivered": True},
        "royalty": {"receiver": public_hex(state["royaltyInfo"][0], 20),
                    "amount_wei_at_mint_price": str(number(state["royaltyInfo"][1]))},
        "receipts": receipts,
        "bytecode_verification_block": number(verification["verification_block"]),
        "limitations": ["Successive live readbacks, not one atomic state snapshot.",
                        "This exporter checks supplied observations; it does not query the chain.",
                        "Bytecode comparison limitations are retained in bytecode-verification.json.",
                        "This is a testnet demonstration, not an audit or production release."],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state", required=True, type=Path)
    parser.add_argument("--metadata", required=True, type=Path)
    parser.add_argument("--verification", required=True, type=Path)
    parser.add_argument("--output-dir", required=True, type=Path)
    args = parser.parse_args()
    try:
        state, metadata, verification = [json.loads(path.read_text(encoding="utf-8-sig"))
                                         for path in (args.state, args.metadata, args.verification)]
        report = observations(state, metadata, verification)
        report["input_sha256"] = {name: sha256(path.read_bytes()) for name, path in
                                  (("state", args.state), ("metadata", args.metadata),
                                   ("bytecode_verification", args.verification))}
        files = {"observations.json": encoded(report), "token.metadata.json": encoded(metadata),
                 "bytecode-verification.json": encoded(verification)}
        checksums = "".join(f"{hashlib.sha256(data).hexdigest()}  {name}\n"
                            for name, data in sorted(files.items()))
        files["SHA256SUMS"] = checksums.encode()
        args.output_dir.mkdir(parents=True, exist_ok=True)
        for name, data in files.items():
            (args.output_dir / name).write_bytes(data)
    except (ValueError, KeyError, TypeError, OSError):
        print("Public observation export failed: incomplete or invalid supplied evidence.")
        return 1
    print(f"Exported completed public Sepolia observations to {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
