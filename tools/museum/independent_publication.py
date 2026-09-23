"""Exact INDEPENDENT publication positions under the anchored trusted-RPC model.

Receipts and parent-linked headers are evidence from the selected endpoint, not
receipt-trie proofs or consensus verification. Semantic issuer identity and
review eligibility remain separate from an accepted account's publication.
"""

import argparse
import os
from pathlib import Path

from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import RECORD, json_values, require


PROFILE = "STREAM_MUSEUM_INDEPENDENT_PUBLICATION_V1"
EVENT_SIGNATURE = ("IndependentPreservationRecordRecorded(uint256,bytes32,bytes32,"
    "(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),"
    "bytes32,bytes32,address,bytes32,uint16)")
EVENT_TOPIC = keccak256(EVENT_SIGNATURE.encode("ascii"))
EVENT_DATA = (RECORD, "bytes32", "bytes32", "address", "bytes32", "uint16")
MAX_HEADERS = 4096
MAX_LOGS = 8192


def _hash(value):
    require(hex_bytes(value, 32) != bytes(32), "zero publication hash")
    return value


def _hints(raw, records):
    value = loads(raw, maximum=1048576, canonical=True)
    require(isinstance(value, dict) and set(value) == {"profile", "records"}
            and value["profile"] == PROFILE, "publication hints profile")
    rows = value["records"]
    require(isinstance(rows, list) and len(rows) == len(records), "publication hints completeness")
    result = {}
    for row in rows:
        require(isinstance(row, dict) and set(row) == {"recordHash", "transactionHash"}, "publication hint shape")
        h, tx = _hash(row["recordHash"]), _hash(row["transactionHash"])
        require(h in records and h not in result, "duplicate or foreign publication hint")
        result[h] = tx
    return result


class IndependentPublicationAdapter:
    def __init__(self, source, hints_bytes, transport, *, provenance="synthetic_fixture"):
        require(type(source) is IndependentSourceAdapter, "validated independent source required")
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "publication provenance")
        require(provenance != "trusted_rpc" or (source.provenance == "trusted_rpc"
                and type(transport) in (RpcTransport, ReplayTransport)), "synthetic publication cannot authenticate state")
        self.source = source
        self.source_bytes = source.snapshot()
        self.capture = loads(self.source_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
        self.records = {r["recordHash"]: r for r in self.capture["records"]}
        self.hints_bytes = hints_bytes
        self.hints = _hints(hints_bytes, self.records)
        self.reader = RecordingReader(transport, source.a["blockHash"])
        self.provenance = provenance
        self._started = False
        self._snapshot = None

    def _header(self, h):
        _hash(h)
        b = self.reader.request("eth_getBlockByHash", [h, False])
        require(isinstance(b, dict) and b.get("hash") == h, "publication block hash mismatch")
        hex_bytes(b.get("parentHash"), 32)
        number, timestamp = quantity(b.get("number")), quantity(b.get("timestamp"))
        transactions = b.get("transactions")
        require(isinstance(transactions, list) and len(transactions) <= 65536, "block transaction bound")
        require(len(set(_hash(t) for t in transactions)) == len(transactions), "duplicate block transaction")
        return b, number, timestamp

    def _anchor(self):
        a = self.source.a
        b, number, timestamp = self._header(a["blockHash"])
        require(number == uint(a["blockNumber"]) and timestamp == uint(a["timestamp"])
                and b.get("stateRoot") == a["stateRoot"], "publication anchor mismatch")
        return b, number, timestamp

    def _receipt(self, tx):
        receipt = self.reader.request("eth_getTransactionReceipt", [tx])
        require(isinstance(receipt, dict), "publication receipt unavailable")
        require(receipt.get("transactionHash") == tx and receipt.get("status") == "0x1",
                "publication receipt transaction or status mismatch")
        _hash(receipt.get("blockHash"))
        number = quantity(receipt.get("blockNumber"))
        index = quantity(receipt.get("transactionIndex"))
        logs = receipt.get("logs")
        require(isinstance(logs, list) and 0 < len(logs) <= MAX_LOGS, "publication receipt log bound")
        previous = -1
        for log in logs:
            require(isinstance(log, dict) and log.get("removed") is False, "removed or malformed publication log")
            require(log.get("blockHash") == receipt["blockHash"] and log.get("transactionHash") == tx
                    and quantity(log.get("blockNumber")) == number
                    and quantity(log.get("transactionIndex")) == index, "receipt/log coordinate mismatch")
            current = quantity(log.get("logIndex"))
            require(current > previous, "duplicate or unordered receipt log index")
            previous = current
            hex_bytes(log.get("address"), 20)
            topics = log.get("topics")
            require(isinstance(topics, list) and len(topics) <= 4, "receipt log topics shape")
            for topic in topics:
                hex_bytes(topic, 32)
            require(len(hex_bytes(log.get("data"))) <= 262144, "receipt log data bound")
        return receipt

    def _event(self, log, expected):
        topics = log["topics"]
        require(len(topics) == 4, "independent event indexed topic count")
        scope = int.from_bytes(hex_bytes(topics[1], 32), "big")
        record, h, chain, attestor, authority, version = decode(EVENT_DATA, hex_bytes(log["data"]), maximum=16384)
        require(record[0] == topics[2] and record[1] == topics[3], "independent event indexed tuple mismatch")
        require(authority == "0x" + (5).to_bytes(32, "big").hex() and version == 1,
                "independent event authority or version mismatch")
        if expected is not None:
            receipt = expected["receipt"]
            require(scope == uint(receipt[0]) and h == expected["recordHash"] and chain == receipt[5]
                    and attestor == receipt[1] and json_values(record) == expected["record"],
                    "independent event full record mismatch")
        return h, (str(scope), record[0])

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed publication cannot reuse partial reader state")
        self._started = True
        a, reader = self.source.a, self.reader
        require(quantity(reader.request("eth_chainId", [])) == uint(a["chainId"]), "publication chain id mismatch")
        first, anchor_number, anchor_time = self._anchor()
        receipts = {tx: self._receipt(tx) for tx in dict.fromkeys(self.hints.values())}
        targets = {r["blockHash"] for r in receipts.values()}
        require(all(quantity(r["blockNumber"]) <= anchor_number for r in receipts.values()), "publication after anchor")
        headers, b, number, timestamp = {}, first, anchor_number, anchor_time
        while True:
            headers[b["hash"]] = b
            targets.discard(b["hash"])
            if not targets:
                break
            require(len(headers) < MAX_HEADERS and number > 0, "publication ancestry bound or unavailable ancestor")
            child = b
            b, parent_number, parent_time = self._header(child["parentHash"])
            require(parent_number + 1 == number and parent_time <= timestamp,
                    "publication ancestry number or timestamp mismatch")
            number, timestamp = parent_number, parent_time
        seen, positions, coordinates = {}, [], set()
        lanes = {(lane["scopeKey"], lane["recordType"]) for lane in self.capture["lanes"]}
        block_ranges = {}
        for tx, receipt in receipts.items():
            b = headers[receipt["blockHash"]]
            number, tx_index = quantity(receipt["blockNumber"]), quantity(receipt["transactionIndex"])
            require(number == quantity(b["number"]) and tx_index < len(b["transactions"])
                    and b["transactions"][tx_index] == tx, "publication block transaction inclusion mismatch")
            coordinate = (number, tx_index)
            require(coordinate not in coordinates, "conflicting publication transaction position")
            coordinates.add(coordinate)
            indices = [quantity(log["logIndex"]) for log in receipt["logs"]]
            block_ranges.setdefault(number, []).append((tx_index, min(indices), max(indices)))
            matched = 0
            for offset, log in enumerate(receipt["logs"]):
                if log["address"] != a["host"] or not log["topics"] or log["topics"][0] != EVENT_TOPIC:
                    continue
                h, lane = self._event(log, None)
                if h not in self.records:
                    require(lane not in lanes, "unmatched event in complete declared lane")
                    continue  # Other lanes are retained in the receipt, outside this selection.
                require(h not in seen and self.hints[h] == tx, "duplicate or wrongly hinted publication")
                self._event(log, self.records[h])
                require(quantity(b["timestamp"]) == uint(self.records[h]["receipt"][3]),
                        "publication timestamp differs from host receipt")
                position = [str(number), str(tx_index), str(quantity(log["logIndex"]))]
                seen[h] = position
                matched += 1
                positions.append({"recordHash": h, "blockHash": b["hash"], "transactionHash": tx,
                    "publicationPosition": position, "receiptLogOffset": str(offset),
                    "eventHash": keccak256(dumps(log)), "receiptHash": keccak256(dumps(receipt))})
            require(matched > 0, "hinted transaction has no selected publication")
        require(set(seen) == set(self.records), "publication record/event completeness mismatch")
        for ranges in block_ranges.values():
            ordered = sorted(ranges)
            require(all(left[2] < right[1] for left, right in zip(ordered, ordered[1:])),
                    "publication log order contradicts transaction order")
        self._anchor()
        code = hex_bytes(reader.code(a["host"]))
        require(keccak256(code) == self.source.pins[a["host"]], "publication canonical anchor code mismatch")
        if isinstance(reader.transport, ReplayTransport):
            reader.transport.finish()
        result = dumps({"profile": PROFILE,
            "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "evidence": self.provenance, "environment": a["environment"],
            "anchorHash": keccak256(self.source.anchor_bytes), "sourceCaptureHash": keccak256(self.source_bytes),
            "sourceTranscriptHash": keccak256(self.source.reader.transcript()), "hintsHash": keccak256(self.hints_bytes),
            "transcriptHash": keccak256(reader.transcript()),
            "publications": sorted(positions, key=lambda p: tuple(uint(v) for v in p["publicationPosition"])),
            "headers": list(headers.values()), "receipts": list(receipts.values()),
            "claims": {"declaredRecordPublicationsComplete": True, "wholeHostLogInventory": False,
                "cryptographicReceiptProof": False, "consensusFinality": False,
                "publicDeploymentAcceptance": False, "semanticPayloadValidation": False,
                "assertingAgentIdentityAdmission": False, "institutionalAcceptance": False}})
        require(len(result) <= MAX_TRANSCRIPT, "publication output byte bound")
        self._snapshot = result
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--anchor", type=Path, required=True)
    parser.add_argument("--source-transcript", type=Path, required=True)
    parser.add_argument("--source-transcript-hash", required=True)
    parser.add_argument("--hints", type=Path, required=True)
    transport = parser.add_mutually_exclusive_group(required=True)
    transport.add_argument("--publication-transcript", type=Path)
    transport.add_argument("--rpc-env")
    parser.add_argument("--publication-transcript-hash")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = IndependentSourceAdapter(args.anchor.read_bytes(), ReplayTransport(
        args.source_transcript.read_bytes(), args.source_transcript_hash), provenance="trusted_rpc")
    if args.rpc_env:
        require(args.publication_transcript_hash is None and args.rpc_env in os.environ, "publication RPC variable unavailable")
        remote = RpcTransport(os.environ[args.rpc_env])
    else:
        require(args.publication_transcript_hash is not None, "publication replay needs external commitment")
        remote = ReplayTransport(args.publication_transcript.read_bytes(), args.publication_transcript_hash)
    adapter = IndependentPublicationAdapter(source, args.hints.read_bytes(), remote, provenance="trusted_rpc")
    output = adapter.snapshot()
    args.output.mkdir(parents=True, exist_ok=False)
    for name, raw in (("anchor.json", source.anchor_bytes), ("source-transcript.json", source.reader.transcript()),
        ("source-capture.json", source.snapshot()), ("publication-hints.json", adapter.hints_bytes),
        ("publication-transcript.json", adapter.reader.transcript()), ("publications.json", output)):
        (args.output / name).write_bytes(raw)
    print(dumps({"publicationHash": keccak256(output), "output": str(args.output)}).decode())


if __name__ == "__main__":
    main()
