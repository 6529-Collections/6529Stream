"""Original Executor input capture rooted exclusively in a verified native finality capture."""
from . import public_finality_capture as original
from . import public_history_rpc as history_rpc
from . import native_finality_wire as native_wire
from . import governance_transaction_wire as wire
from . import public_governance_transaction_rpc as rpc
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_rpc import quantity
from .independent_wire import require
from .bagit import MAX_BYTES

PROFILE = "STREAM_MUSEUM_PUBLIC_GOVERNANCE_TRANSACTION_SOURCE_V1"
SOURCE_REVISION = original._source().SOURCE_REVISION
QUALIFICATION = ("Original scheduled and executed transaction observations are bound to the unchanged native capture, "
    "Executor/runtime/source anchors and original receipts/header slots. Supported canonical direct Executor inputs "
    "reconstruct ordered calls and action-ID preimages; absent or unsupported inputs remain partial. Raw input and RPC JSON "
    "are retained, not signed transaction envelopes. Historical role/policy checks, execution reenactment, source authenticity "
    "and consensus remain unverified. The published native fragment and V6 claims remain unchanged.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_source_profile",
    "sourceReviewCommit": SOURCE_REVISION, "originalCaptureProfileHash": original.PROFILE_HASH,
    "rpcProfileHash": rpc.PROFILE_HASH,
    "anchors": "Derive source state, Executor address/runtime, original scheduled/executed transaction hashes and original source pins only from externally pinned, fully replayed native finality capture.",
    "observations": "Retain exact canonical original transaction JSON and original successful receipt/header bytes; require requested hash, block hash/number/index, receipt logs and header transaction slot. Compare from/to when present in original receipt; compare transaction chainId when present. An absent chainId is explicitly bound through source anchor and original block, not invented.",
    "reconstruction": "Pinned Executor/Bootstrap V2 ABI: both schedule and execute batch/action entry points. Ordered 7-field GovernanceCall records, original scheduling event nonce, exact V2 calls/transition/action domains; single execution requires original per-call schedule transitions. Complete historical calldata carrier remains preserved in original native capture.",
    "availability": "Canonical direct inputs only, at most 64 calls, 32768 bytes per call, 131072 bytes per transaction and 24576 bytes per carrier are reader bounds, not protocol maxima. Unknown wrappers/selectors and noncanonical native-accepted encodings remain retained partial. Missing RPC result means not_returned, not proven pruned.",
    "limits": "Three read-only RPC requests. No latest role/Core substitution, signer recovery, policy/window reexecution, current archive checks or live onchain action.",
    "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def original_observations(files, manifest_hash):
    """Replay original bytes before deriving any transaction lookup target."""
    captured = original.verify(files, manifest_hash)
    files = dict(captured.files)
    native = loads(files["native-finality/fragment.json"], maximum=MAX_BYTES, canonical=True)
    transcript = loads(files["source/transcript.json"], maximum=history_rpc.MAX_TRANSCRIPT, canonical=True)
    executor = native["graph"]["executor"]
    events, receipts, headers = {}, {}, {}
    for role, event_name in (("schedule", "governanceScheduled"), ("execution", "governanceExecuted")):
        matches = [row["log"] for row in native["events"] if row["log"]["address"] == executor["address"]
            and row["log"]["topics"][0] == native_wire.EVENTS[event_name]]
        require(len(matches) == 1, "governance original event selection differs")
        log = matches[0]; events[role] = log
        observed = [row["result"] for row in transcript["calls"]
            if row["method"] == "eth_getTransactionReceipt" and row["params"] == [log["transactionHash"]]]
        require(observed and all(row == observed[0] for row in observed), "governance original receipt missing/differs")
        receipts[role] = observed[0]
        observed = [row["result"] for row in transcript["calls"]
            if row["method"] == "eth_getBlockByHash" and row["params"] == [log["blockHash"], False]]
        require(observed and all(row == observed[0] for row in observed), "governance original header missing/differs")
        headers[log["blockHash"]] = observed[0]
    anchor = {"profile": PROFILE, "sourceProfileHash": PROFILE_HASH, "nativeManifestHash": manifest_hash,
        "nativeFragmentHash": keccak256(files["native-finality/fragment.json"]),
        "nativeSourceProfileHash": native["sourceRef"]["sourceProfileHash"],
        "nativeSourceAnchorHash": native["sourceRef"]["anchorHash"],
        "sourceState": native["sourceState"], "executor": executor,
        "scheduleTransactionHash": events["schedule"]["transactionHash"],
        "executionTransactionHash": events["execution"]["transactionHash"]}
    return captured, native, anchor, events, receipts, sorted(headers.values(), key=lambda row: quantity(row["number"]))


def transaction_observation(value, receipt, event, state):
    raw_receipt = "0x" + dumps(receipt).hex()
    if value is None:
        return {"status": "not_returned", "transactionBytes": None, "receiptBytes": raw_receipt, "normalized": None}
    try:
        require(type(value) is dict and all(key in value for key in
            ("hash", "blockHash", "blockNumber", "transactionIndex", "from", "to", "value", "input")),
            "governance original transaction shape")
        require(value["hash"] == event["transactionHash"], "governance original transaction hash differs")
        for key in ("blockHash", "blockNumber", "transactionIndex"):
            require(value[key] == event[key] == receipt[key], "governance original transaction placement differs")
        hex_bytes(value["from"], 20)
        if value["to"] is not None: hex_bytes(value["to"], 20)
        require(any(hex_bytes(value["from"], 20)), "governance original transaction sender is zero")
        for key in ("from", "to"):
            if key in receipt: require(value[key] == receipt[key], "governance original receipt actor differs")
        amount = quantity(value["value"])
        require(amount < 2**256 and len(hex_bytes(value["input"])) <= 131072, "governance transaction value/input bound")
        if "chainId" in value:
            require(quantity(value["chainId"]) == uint(state["chainId"]), "governance original transaction chain differs")
        return {"status": "available", "transactionBytes": "0x" + dumps(value).hex(), "receiptBytes": raw_receipt,
            "normalized": {"to": value["to"], "from": value["from"], "value": str(amount), "input": value["input"]}}
    except MuseumError: raise
    except (KeyError, TypeError, ValueError, OverflowError) as exc:
        raise MuseumError("malformed governance original transaction") from exc


class PublicGovernanceTransactionSource:
    def __init__(self, native_files, native_manifest_hash, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("trusted_rpc", "synthetic_fixture"), "governance explicit provenance required")
        self.captured, self.native, anchor, self.events, self.receipts, self.headers = original_observations(native_files, native_manifest_hash)
        require(self.captured.report["provenance"] == provenance, "governance original/source provenance differs")
        self.anchor_bytes, self.provenance = dumps(anchor), provenance
        self.reader, self._snapshot = rpc.PublicGovernanceRecordingReader(transport), None

    def snapshot(self):
        if self._snapshot is not None: return self._snapshot
        require(quantity(self.reader.request("eth_chainId", [])) == uint(self.native["sourceState"]["chainId"]),
            "governance RPC chain differs from original source")
        transactions = {}
        for role in ("schedule", "execution"):
            value = self.reader.request("eth_getTransactionByHash", [self.events[role]["transactionHash"]])
            transactions[role] = transaction_observation(value, self.receipts[role], self.events[role], self.native["sourceState"])
        if hasattr(self.reader.transport, "finish"): self.reader.transport.finish()
        snapshot = {"profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
            "sourceReviewCommit": SOURCE_REVISION, "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(self.transcript()), "provenance": self.provenance,
            "sourceState": self.native["sourceState"], "nativeFinality": self.native,
            "headers": ["0x" + dumps(row).hex() for row in self.headers], "transactions": transactions,
            "reconstruction": wire.verify(self.native["bundle"], self.native["sourceState"], self.native["graph"],
                {role: row["normalized"] for role, row in transactions.items()}, self.native["events"]),
            "qualification": QUALIFICATION}
        raw = dumps(snapshot)
        from ..metadata import acquisition_governance_transactions_v1 as definition
        definition.semanticProjection(snapshot, {"sourceProfileHash": PROFILE_HASH, "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(raw), "provenance": self.provenance})
        self._snapshot = raw
        return raw

    def transcript(self): return self.reader.transcript()
