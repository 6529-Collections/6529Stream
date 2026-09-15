"""Bounded complete valuation lanes and original cross-family receipt order.

External block/transcript pins and RPC consistency are the trust boundary. This does
not verify Ethereum receipt/state trie proofs or authenticate a financial opinion.
"""
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import encode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .owner_record_source import OwnerRecordSource, OWNER_RECORD
from .valuations import need

PROFILE = "STREAM_MUSEUM_OWNER_VALUATION_HISTORY_V1"
EVENT = schema_id("OwnerRecordRecorded(uint256,bytes32,address,(bytes32,bytes32,bytes32,(uint16,bytes,bytes32),string,bytes,uint64),bytes32,bytes32,bool,uint16)")


def event_bytes(row):
    r, t = row["record"], row["receipt"]
    record = (r[0], r[1], r[2], (uint(r[3][0], 16), hex_bytes(r[3][1]), r[3][2]),
        r[4], hex_bytes(row["payloadHex"]), uint(r[6], 64))
    return encode((OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"),
        (record, row["recordHash"], t[4], t[5], 1))


class ValuationHistory:
    _read = IndependentSourceAdapter._read

    def __init__(self, source, hints_bytes, transport, *, hints_hash, provenance="synthetic_fixture"):
        need(type(source) is OwnerRecordSource and provenance in ("synthetic_fixture", "trusted_rpc"), "history source/provenance")
        need(provenance != "trusted_rpc" or (source.provenance == "trusted_rpc" and type(transport) in (ReplayTransport, RpcTransport)), "history transport provenance")
        need(keccak256(hints_bytes) == hints_hash, "history hint pin")
        h = loads(hints_bytes, maximum=524288, canonical=True)
        need(isinstance(h, dict) and set(h) == {"profile", "ownerSourceHash", "loans", "transactions"}
            and h["profile"] == PROFILE and h["ownerSourceHash"] == keccak256(source.snapshot()), "history hints/source differs")
        need(isinstance(h["loans"], list) and 0 < len(h["loans"]) <= 64
            and len(set(h["loans"])) == len(h["loans"]), "history loan bound")
        need(isinstance(h["transactions"], list) and 0 < len(h["transactions"]) <= 128
            and len(set(h["transactions"])) == len(h["transactions"]), "history receipt bound")
        for x in h["loans"] + h["transactions"]: need(hex_bytes(x, 32) != bytes(32), "history empty identity")
        self.source, self.hints, self.hints_bytes, self.provenance = source, h, hints_bytes, provenance
        self.reader = RecordingReader(transport, source.a["blockHash"])
        self._result, self._started = None, False

    def capture(self):
        try:
            return self._capture()
        except (KeyError, TypeError, IndexError, OverflowError) as exc:
            raise MuseumError("valuation malformed history receipt/header evidence") from exc

    def _capture(self):
        if self._result is not None: return self._result
        need(not self._started, "failed history cannot resume"); self._started = True
        a = self.source.a; chosen = set(self.hints["loans"]); tokens = set()
        for h in chosen:
            need(h in self.source.records and self.source.records[h]["record"][0] == schema_id("LOAN"), "history original loan missing")
            tokens.add(self.source.records[h]["receipt"][0])
        lanes = {}
        for token in sorted(tokens, key=uint):
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (uint(token), schema_id("VALUATION")), ("bytes32", "uint64"))
            need(count <= 128, "complete valuation lane bound unsupported")
            hashes = []
            for i in range(count):
                _, (h,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (uint(token), schema_id("VALUATION"), i), ("bytes32",))
                need(h in self.source.records and h not in hashes, "complete valuation lane selection missing")
                row = self.source.records[h]
                need(row["receipt"][0] == token and uint(row["receipt"][3]) == i
                    and row["record"][0] == schema_id("VALUATION"), "complete valuation lane index differs")
                hashes.append(h); chosen.add(h)
            expected = "0x" + "00" * 32 if not hashes else self.source.records[hashes[-1]]["receipt"][4]
            need(head == expected, "complete valuation lane head differs")
            lanes[token] = {"records": hashes, "head": head, "count": str(count)}
        need(len(chosen) <= 128, "history whole evidence bound unsupported")
        receipts = []
        for tx in self.hints["transactions"]:
            r = self.reader.request("eth_getTransactionReceipt", [tx])
            need(isinstance(r, dict) and r.get("transactionHash") == tx and r.get("status") == "0x1", "history successful receipt required")
            for k in ("blockHash", "transactionHash"): need(hex_bytes(r[k], 32) != bytes(32), "history receipt identity")
            for k in ("blockNumber", "transactionIndex"): quantity(r[k])
            need(isinstance(r.get("logs"), list) and len(r["logs"]) <= 4096, "history receipt log bound")
            receipts.append(r)
        lowest = min(quantity(r["blockNumber"]) for r in receipts)
        anchor_number = uint(a["blockNumber"])
        need(lowest <= anchor_number and anchor_number - lowest <= 256, "history ancestor span unsupported")
        blocks = {}; expected_hash = a["blockHash"]
        for number in range(anchor_number, lowest - 1, -1):
            b = self.reader.request("eth_getBlockByHash", [expected_hash, False])
            need(isinstance(b, dict) and b.get("hash") == expected_hash and quantity(b["number"]) == number, "history anchor ancestry differs")
            need(hex_bytes(b["parentHash"], 32) != bytes(32), "history parent missing")
            stamp = quantity(b["timestamp"])
            if number == anchor_number:
                need(b.get("stateRoot") == a["stateRoot"] and stamp == uint(a["timestamp"]), "history original anchor differs")
            else: need(stamp <= quantity(blocks[number + 1]["timestamp"]), "history ancestor timestamp order")
            need(isinstance(b.get("transactions"), list) and len(b["transactions"]) <= 8192
                and all(isinstance(t, str) and len(hex_bytes(t, 32)) == 32 for t in b["transactions"])
                and len(set(b["transactions"])) == len(b["transactions"]), "history block transactions shape")
            blocks[number] = b; expected_hash = b["parentHash"]
        by_event = {}
        for h in chosen:
            row = self.source.records[h]; t = row["receipt"]
            key = ("0x" + encode(("uint256",), (uint(t[0]),)).hex(), row["record"][0],
                "0x" + encode(("address",), (t[1],)).hex(), "0x" + event_bytes(row).hex())
            need(key not in by_event, "history duplicate event identity"); by_event[key] = h
        positions = {}; used_txs = set(); all_positions = set()
        for r in receipts:
            number, index = quantity(r["blockNumber"]), quantity(r["transactionIndex"])
            need(number in blocks and blocks[number]["hash"] == r["blockHash"], "history receipt canonical block differs")
            transactions = blocks[number]["transactions"]
            need(index < len(transactions) and transactions[index] == r["transactionHash"], "history receipt transaction index differs")
            last_log = -1
            for log in r["logs"]:
                need(isinstance(log, dict) and log.get("removed") is False, "history removed/malformed log")
                n = quantity(log["logIndex"])
                need(n > last_log and log.get("blockHash") == r["blockHash"]
                    and log.get("transactionHash") == r["transactionHash"]
                    and log.get("blockNumber") == r["blockNumber"]
                    and log.get("transactionIndex") == r["transactionIndex"], "history log receipt coordinates differ")
                last_log = n
                if log.get("address") != a["host"]: continue
                topics = log.get("topics")
                if not isinstance(topics, list) or len(topics) != 4 or topics[0] != EVENT: continue
                h = by_event.get((*topics[1:], log.get("data")))
                if h is None: continue
                need(h not in positions and (number, n) not in all_positions, "history duplicate selected event")
                need(uint(self.source.records[h]["receipt"][2]) == quantity(blocks[number]["timestamp"]), "history original recordedAt differs")
                all_positions.add((number, n)); used_txs.add(r["transactionHash"])
                positions[h] = {"blockNumber": str(number), "blockHash": r["blockHash"], "transactionHash": r["transactionHash"],
                    "transactionIndex": str(index), "logIndex": str(n)}
        need(set(positions) == chosen and used_txs == set(self.hints["transactions"]), "history selected exact events missing or unrelated receipts")
        position = lambda h: tuple(uint(positions[h][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
        for lane in lanes.values():
            ordered = [position(h) for h in lane["records"]]
            need(all(ordered[i] < ordered[i+1] for i in range(len(ordered)-1)), "history lane/event order differs")
        ordered = sorted(position(h) for h in chosen)
        need(all(ordered[i][0] != ordered[i+1][0] or ordered[i][2] < ordered[i+1][2]
            for i in range(len(ordered)-1)), "history block log order differs")
        # Recheck the externally pinned anchor at the end; receipt/state proof remains unclaimed.
        latest = self.reader.request("eth_getBlockByHash", [a["blockHash"], False])
        need(latest == blocks[anchor_number], "history anchor changed during capture")
        if type(self.reader.transport) is ReplayTransport: self.reader.transport.finish()
        self._result = {"profile": PROFILE, "mode": "recorded_receipts" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "ownerSourceHash": self.hints["ownerSourceHash"],
            "hintsHash": keccak256(self.hints_bytes), "transcriptHash": keccak256(self.reader.transcript()),
            "lanes": lanes, "positions": positions, "claims": {"completeSelectedValuationLanesChecked": True,
                "originalEventReceiptOrderChecked": True, "cryptographicStateProof": False,
                "cryptographicReceiptProof": False, "legalOperativenessProven": False}}
        return self._result
