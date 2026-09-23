"""Public-chain Core ownership capture with explicitly trusted filtered-log completeness."""
from . import ownership_source as original
from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode
from .independent_wire import ZERO_ADDRESS, require
from .public_history_rpc import PublicRecordingReader, PublicReplayTransport, PublicRpcTransport
from .public_chain_history import PROFILE_HASH as HISTORY_PROFILE_HASH, scan_public_history

PROFILE = "STREAM_MUSEUM_PUBLIC_CORE_OWNERSHIP_HISTORY_V1"
CLAIMS = {"nativeTransferContinuityChecked": True, "mintToSourceStateReconciled": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "genesisWalk": False, "allBlockReceipts": False, "cryptographicReceiptProof": False,
    "cryptographicStateProof": False, "consensusVerified": False, "legalTitleProven": False,
    "fullProtocolEventHistoryArchive": False, "fullAcquisitionItem10": False,
    "actualChainAcceptance": False}
QUALIFICATION = ("Consumer-fixed Core/token Transfer queries cover block numbers zero through the supplied "
    "anchor. Every returned log is checked against its full receipt and canonical header; mint, transfer and "
    "burn continuity reconcile with pinned Core state. Provider log completeness and canonical mapping "
    "remain trusted, including omitted transfer cycles that return to the same owner. This is not a genesis "
    "block walk, all-block receipt scan, ancestry/consensus proof, legal-title determination or full item 10.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_source_profile",
    "originalSemanticsProfileHash": original.PROFILE_HASH, "historyProfileHash": HISTORY_PROFILE_HASH,
    "filter": "Exactly original Core Transfer(address,address,uint256), topic3 equal to the exact tokenId.",
    "bounds": "Shared public-history bounds; no caller-supplied lower bound, event filters or transaction hints.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


class PublicOwnershipSource(original.OwnershipSource):
    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc") and (provenance != "trusted_rpc"
            or type(transport) in (PublicRpcTransport, PublicReplayTransport)), "public ownership provenance")
        a = loads(anchor_bytes, maximum=65536, canonical=True)
        require(type(a) is dict and a.get("profile") == PROFILE, "public ownership anchor profile")
        # Reuse the unchanged original closed anchor validation, not its transport
        # admission or history strategy. Restore the exact public-profile bytes.
        super().__init__(dumps(a | {"profile": original.PROFILE}), transport, provenance="synthetic_fixture")
        self.anchor_bytes, self.a, self.provenance = anchor_bytes, a, provenance
        self.reader = PublicRecordingReader(transport, a["blockHash"])

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed public ownership capture cannot resume")
        self._started = True
        a, token = self.a, uint(self.a["tokenId"])
        filters = [{"address": a["core"], "topics": [original.TRANSFER, None, None,
            "0x" + token.to_bytes(32, "big").hex()]}]
        history = scan_public_history(self.reader, a, filters=filters)
        code = hex_bytes(self.reader.code(a["core"]))
        require(0 < len(code) <= 24576 and keccak256(code) == a["coreRuntimeHash"], "public ownership Core runtime differs")
        supported, = self._read("supportsInterface(bytes4)", ("bytes4",), ("0x80ac58cd",), ("bool",))
        require(supported, "public ownership Core ERC721 interface required")
        identity = self._read("tokenCollectionIdentity(uint256)", ("uint256",), (token,),
            ("bool", "uint256", "uint256", "bool"))
        lifecycle, = self._read("tokenLifecycle(uint256)", ("uint256",), (token,), ("uint8",))
        require(identity[0] and identity[1] == uint(a["collectionId"]) and identity[2] > 0
            and lifecycle in (2, 3) and identity[3] == (lifecycle == 3), "public ownership identity/lifecycle differs")
        owner, events, transitions, burned = ZERO_ADDRESS, [], [], False
        for log in history["logs"]:
            require(log["address"] == a["core"] and len(log["topics"]) == 4
                and log["topics"][0] == original.TRANSFER and log["data"] == "0x", "public ownership Transfer shape")
            from_owner, = decode(("address",), hex_bytes(log["topics"][1], 32))
            to_owner, = decode(("address",), hex_bytes(log["topics"][2], 32))
            event_token, = decode(("uint256",), hex_bytes(log["topics"][3], 32))
            require(event_token == token and not burned, "public ownership token or terminal burn differs")
            if not events:
                require(from_owner == ZERO_ADDRESS and to_owner != ZERO_ADDRESS, "public ownership history requires original mint")
                kind = "mint"
            else:
                require(from_owner == owner and from_owner != ZERO_ADDRESS, "public ownership disconnected transfer or repeated mint")
                kind = "burn" if to_owner == ZERO_ADDRESS else "transfer"
            owner, burned = to_owner, to_owner == ZERO_ADDRESS
            events.append(log)
            transitions.append({"kind": kind, "from": from_owner, "to": to_owner,
                "blockNumber": str(int(log["blockNumber"], 16)),
                "blockTimestamp": history["blockTimestamps"][str(int(log["blockNumber"], 16))],
                "transactionHash": log["transactionHash"], "transactionIndex": str(int(log["transactionIndex"], 16)),
                "logIndex": str(int(log["logIndex"], 16))})
        require(bool(events) and burned == (lifecycle == 3), "public ownership missing mint/burn history")
        if lifecycle == 2:
            current, = self._read("ownerOf(uint256)", ("uint256",), (token,), ("address",))
            require(current == owner and current != ZERO_ADDRESS, "public ownership final Core owner differs")
        # The public reader rejects changes to repeated requests. Rebind both
        # canonical mappings after the native state reads as well as the scan.
        self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        self.reader.request("eth_getBlockByNumber", [hex(uint(a["blockNumber"])), False])
        if type(self.reader.transport) is PublicReplayTransport:
            self.reader.transport.finish()
        jsonl = b"".join(dumps(log) + b"\n" for log in events)
        self._snapshot = dumps({"profile": PROFILE, "profileHash": PROFILE_HASH, "version": "1",
            "mode": "caller_admitted_public_rpc_history" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "anchorHash": keccak256(self.anchor_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "source": a, "historyCoverage": history["coverage"],
            "identity": {"tokenId": a["tokenId"], "collectionId": a["collectionId"],
                "collectionSerial": str(identity[2]), "lifecycle": str(lifecycle), "owner": owner},
            "events": events, "transitions": transitions, "tokenTransferJsonl": jsonl.decode("utf-8"),
            "tokenTransferJsonlHash": keccak256(jsonl), "claims": CLAIMS, "qualification": QUALIFICATION})
        return self._snapshot
