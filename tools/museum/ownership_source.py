"""Complete bounded Core ERC-721 ownership stream under an explicit RPC anchor."""
import argparse
import os
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import calldata, decode
from .chain_history import MAX_BLOCKS, scan_history
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport
from .independent_wire import ZERO_ADDRESS, require

PROFILE = "STREAM_MUSEUM_CORE_OWNERSHIP_HISTORY_V1"
TRANSFER = schema_id("Transfer(address,address,uint256)")
CLAIMS = {"fullTokenTransferHistory": True, "mintToSourceBlockChecked": True,
          "anchoredCoreStateReconciled": True, "cryptographicReceiptProof": False,
          "cryptographicStateProof": False, "consensusVerified": False,
          "legalTitleProven": False, "physicalCustodyProven": False,
          "fullProtocolEventHistoryArchive": False, "actualChainAcceptance": False}
QUALIFICATION = ("Complete Core token Transfer stream from genesis through the exact source block, "
                 "using externally admitted RPC headers and every receipt. This is not a consensus "
                 "or receipt-trie proof, a legal title determination, or a complete protocol archive.")
PROFILE_BYTES = dumps({"id": PROFILE, "version": "1", "status": "prospective_unregistered_export_profile",
    "bounds": {"blocksIncludingGenesis": str(MAX_BLOCKS), "transcriptBytes": "67108864"},
    "rules": {"completeness": "Parent-linked headers to genesis; every transaction receipt; contiguous block log indexes; no transaction or lane hints.",
              "identity": "Externally pinned Core runtime and token collection identity at the exact block hash.",
              "ownership": "Exactly one mint followed by contiguous transfers and optional terminal burn; reconcile lifecycle and ownerOf for a live token.",
              "retention": "Exact anchor and transcript replay; original ordered log fields preserved as canonical JSONL.",
              "scope": "One token of one pinned Core. No registered full-protocol archive address set or adopted event-history snapshot assertion."},
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class OwnershipSource:
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and
                (provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport)),
                "ownership source provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(isinstance(a, dict) and set(a) == {"profile", "chainId", "blockHash", "blockNumber",
            "timestamp", "stateRoot", "environment", "deploymentEvidenceHash", "core", "coreRuntimeHash",
            "tokenId", "collectionId"} and a["profile"] == PROFILE,
            "ownership anchor shape/profile")
        require(a["environment"] in ("local_evm_fixture", "public_chain"), "ownership environment")
        for key in ("chainId", "blockNumber", "timestamp", "tokenId", "collectionId"):
            uint(a[key], 64 if key == "timestamp" else 256)
        require(uint(a["chainId"]) > 0 and uint(a["tokenId"]) > 0 and uint(a["collectionId"]) > 0,
                "ownership token/collection/chain identity")
        for key in ("blockHash", "stateRoot", "deploymentEvidenceHash", "coreRuntimeHash"):
            require(any(hex_bytes(a[key], 32)), "ownership anchor commitment")
        require(any(hex_bytes(a["core"], 20)), "ownership Core address")
        self.anchor_bytes, self.a, self.provenance = anchor_bytes, a, provenance
        self.reader = RecordingReader(transport, a["blockHash"])
        self._started, self._snapshot = False, None

    def _read(self, signature, inputs=(), values=(), outputs=()):
        return decode(outputs, hex_bytes(self.reader.call(self.a["core"], calldata(signature, inputs, values))))

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed ownership capture cannot resume")
        self._started = True
        a, token = self.a, uint(self.a["tokenId"])
        history = scan_history(self.reader, a)
        code = hex_bytes(self.reader.code(a["core"]))
        require(0 < len(code) <= 24576 and keccak256(code) == a["coreRuntimeHash"], "ownership Core runtime differs")
        supported, = self._read("supportsInterface(bytes4)", ("bytes4",), ("0x80ac58cd",), ("bool",))
        require(supported, "ownership Core ERC721 interface required")
        identity = self._read("tokenCollectionIdentity(uint256)", ("uint256",), (token,),
                              ("bool", "uint256", "uint256", "bool"))
        lifecycle, = self._read("tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0
                and lifecycle in (2, 3) and identity[3] == (lifecycle == 3),
                "ownership permanent identity/lifecycle differs or mint incomplete")
        owner, events, transitions, burned = ZERO_ADDRESS, [], [], False
        for log in history["logs"]:
            if log["address"] != a["core"] or not log["topics"] or log["topics"][0] != TRANSFER:
                continue
            require(len(log["topics"]) == 4 and log["data"] == "0x", "ownership malformed Core Transfer")
            from_owner, = decode(("address",), hex_bytes(log["topics"][1], 32))
            to_owner, = decode(("address",), hex_bytes(log["topics"][2], 32))
            event_token, = decode(("uint256",), hex_bytes(log["topics"][3], 32))
            if event_token != token:
                continue
            require(not burned, "ownership transfer after terminal burn")
            if not events:
                require(from_owner == ZERO_ADDRESS and to_owner != ZERO_ADDRESS,
                        "ownership history must begin with one mint")
                kind = "mint"
            else:
                require(from_owner == owner and from_owner != ZERO_ADDRESS,
                        "ownership disconnected transfer or repeated mint")
                kind = "burn" if to_owner == ZERO_ADDRESS else "transfer"
            owner, burned = to_owner, to_owner == ZERO_ADDRESS
            events.append(log)
            transitions.append({"kind": kind, "from": from_owner, "to": to_owner,
                "blockNumber": str(int(log["blockNumber"], 16)),
                "blockTimestamp": history["blockTimestamps"][str(int(log["blockNumber"], 16))],
                "transactionHash": log["transactionHash"], "transactionIndex": str(int(log["transactionIndex"], 16)),
                "logIndex": str(int(log["logIndex"], 16))})
        require(bool(events) and burned == (lifecycle == 3), "ownership missing mint/burn history")
        if lifecycle == 2:
            current, = self._read("ownerOf(uint256)", ("uint256",), (token,), ("address",))
            require(current == owner and current != ZERO_ADDRESS, "ownership final Core owner differs")
        # Recheck the original source after all state reads as well as after the walk.
        block = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        require(isinstance(block, dict) and block.get("hash") == a["blockHash"]
                and block.get("stateRoot") == a["stateRoot"]
                and block.get("number") == hex(uint(a["blockNumber"]))
                and block.get("timestamp") == hex(uint(a["timestamp"])), "ownership final source anchor differs")
        if type(self.reader.transport) is ReplayTransport:
            self.reader.transport.finish()
        jsonl = b"".join(dumps(log) + b"\n" for log in events)
        self._snapshot = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_rpc_history" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "source": a, "historyCoverage": {key: history[key] for key in
                ("startBlock", "endBlock", "blockCount", "transactionCount")},
            "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"],
                         "collectionSerial": str(identity[2]), "lifecycle": str(lifecycle), "owner": owner},
            "events": events, "transitions": transitions, "tokenTransferJsonl": jsonl.decode("utf-8"),
            "tokenTransferJsonlHash": keccak256(jsonl), "claims": CLAIMS, "qualification": QUALIFICATION})
        return self._snapshot

    def transcript(self):
        require(self._snapshot is not None, "ownership snapshot required before transcript")
        return self.reader.transcript()


def _bounded_read(path, maximum):
    with path.open("rb") as stream:
        raw = stream.read(maximum + 1)
    require(len(raw) <= maximum, "ownership input file bound")
    return raw


def write_capture(source, output):
    from .bagit import MAX_BYTES, write_tree
    snapshot = source.snapshot()
    transcript = source.transcript()
    pins = {"profileHash": PROFILE_HASH, "anchorHash": keccak256(source.anchor_bytes),
            "snapshotHash": keccak256(snapshot), "transcriptHash": keccak256(transcript),
            "provenance": source.provenance, "actualChainAcceptance": False}
    files = {"anchor.json": source.anchor_bytes, "transcript.json": transcript,
             "snapshot.json": snapshot, "pins.json": dumps(pins), "profile.json": PROFILE_BYTES}
    require(sum(map(len, files.values())) <= MAX_BYTES, "ownership output byte bound")
    write_tree(files, output)
    return pins


def definitions(directory, *, check=False):
    target = Path(directory) / "ownership-history-profile.json"
    if check:
        require(_bounded_read(target, 65536) == PROFILE_BYTES, "ownership profile differs")
    else:
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(PROFILE_BYTES)
    return PROFILE_HASH


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    definition = sub.add_parser("definitions")
    definition.add_argument("--output", type=Path, required=True)
    definition.add_argument("--check", action="store_true")
    for name in ("capture", "replay"):
        command = sub.add_parser(name)
        command.add_argument("--anchor", type=Path, required=True)
        command.add_argument("--anchor-hash", required=True)
        command.add_argument("--output", type=Path, required=True)
        if name == "capture":
            command.add_argument("--rpc-env", required=True)
        else:
            command.add_argument("--transcript", type=Path, required=True)
            command.add_argument("--transcript-hash", required=True)
            command.add_argument("--provenance", choices=("synthetic_fixture", "trusted_rpc"), default="synthetic_fixture")
    args = parser.parse_args()
    if args.command == "definitions":
        print(definitions(args.output, check=args.check))
        return
    anchor = _bounded_read(args.anchor, 65536)
    require(keccak256(anchor) == args.anchor_hash, "ownership external anchor commitment differs")
    if args.command == "capture":
        endpoint = os.environ.get(args.rpc_env)
        require(bool(endpoint), "ownership RPC environment variable missing")
        transport = RpcTransport(endpoint)
    else:
        transport = ReplayTransport(_bounded_read(args.transcript, MAX_TRANSCRIPT), args.transcript_hash)
    source = OwnershipSource(anchor, transport, provenance="trusted_rpc" if args.command == "capture" else args.provenance)
    print(dumps(write_capture(source, args.output)).decode())


if __name__ == "__main__":
    try:
        main()
    except MuseumError as exc:
        raise SystemExit(str(exc)) from None
