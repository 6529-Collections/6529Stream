"""Prepare a read-only ownership capture anchor from immutable Sepolia RC1 evidence."""
import argparse
import json
from pathlib import Path

from .canonical import dumps, keccak256, uint
from .independent_wire import require
from .public_ownership_source import PROFILE, PROFILE_HASH

RELEASE_COMMIT = "569bf87f1fa808787d324f6e1582924b5ccf1d40"
DEPLOYED_SOURCE_COMMIT = "d636056b835c9c3ed0b1c4fe7951609429a5789c"
EVIDENCE = "deployments/current/sepolia-2026-09-10"
PINS = {"deployment/addresses.json": "0x8155b250602c54dfd1950af31726f718dd10a64d91555996f0bbdc804b38880e",
    "demonstration/anchor-block.json": "0xbf2da98f132bd6c16ca9ebbea7c70b13f32a8eddfd79b9ca08b4ddaa27f544ac",
    "demonstration/pinned-readbacks.json": "0x767b414974bcb5770135a41f6dbecf7318e80565bfa403738796ac36e41f823e"}


def prepare(files, *, disclosure):
    require(disclosure == "public", "RC1 recipe requires public disclosure")
    require(type(files) is dict and set(files) == set(PINS), "RC1 recipe exact evidence inventory")
    for path, digest in PINS.items():
        require(type(files[path]) is bytes and keccak256(files[path]) == digest, "RC1 recipe immutable evidence pin differs")
    # Historical readbacks contain exact JSON integers beyond JCS's safe range.
    # Parse only after the immutable byte pins pass; never recanonicalize them.
    addresses, header, readbacks = [json.loads(files[p].decode("utf-8")) for p in PINS]
    core = addresses["modules"]["core"]
    runtime, = [row["runtimeKeccak256"] for row in addresses["verifiedContracts"] if row["address"] == core]
    require(addresses["sourceCommit"] == DEPLOYED_SOURCE_COMMIT and addresses["chainId"] == 11155111
        and readbacks["blockHash"] == header["hash"] and int(header["number"], 16) == uint(readbacks["blockNumber"]),
        "RC1 recipe original source/block binding differs")
    # Exact retained evidence pins already fix these original native observations.
    raw = dumps({"profile": PROFILE, "chainId": "11155111", "blockHash": header["hash"],
        "blockNumber": str(readbacks["blockNumber"]), "timestamp": str(int(header["timestamp"], 16)),
        "stateRoot": header["stateRoot"], "environment": "public_chain",
        "deploymentEvidenceHash": PINS["deployment/addresses.json"], "core": core,
        "coreRuntimeHash": runtime, "tokenId": "1", "collectionId": "1"})
    recipe = {"kind": "read_only_rc1_ownership_capture_recipe", "releaseCommit": RELEASE_COMMIT,
        "deployedSourceCommit": DEPLOYED_SOURCE_COMMIT, "evidenceRoot": EVIDENCE, "evidencePins": PINS,
        "anchorHash": keccak256(raw), "sourceProfileHash": PROFILE_HASH,
        "networkReadsPerformed": False, "currentStackEntropySupported": False,
        "missingCurrentEntropyGetters": ["registeredAtBlock(uint256)", "collectionProviderEpoch(uint256)",
            "requestPolicySnapshot(bytes32)", "freshRecoveryReceipt(bytes32)"],
        "qualification": "Offline preparation only. Run the public ownership capture and exact offline verifier against an admitted RPC; provider completeness remains trusted. RC1 is not the current entropy producer and missing getters must not be synthesized."}
    return {"anchor.json": raw, "recipe.json": dumps(recipe)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--disclosure", required=True); parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(args.disclosure == "public", "RC1 recipe requires public disclosure before reads")
    from .repository_exchange import _destination, _publish
    evidence = Path(__file__).resolve().parents[2] / EVIDENCE
    _destination(args.output, [evidence])
    files = {}
    for name in PINS:
        with (evidence / name).open("rb") as stream: files[name] = stream.read(1024 * 1024 + 1)
    result = prepare(files, disclosure=args.disclosure)
    _publish(result, args.output, [evidence])
    print(dumps({"anchorHash": keccak256(result["anchor.json"]), "sourceProfileHash": PROFILE_HASH,
        "networkReadsPerformed": False}).decode("utf-8"))


if __name__ == "__main__": main()
