"""Exact General publication and historical curator-grant positions under the anchored trusted-RPC model.

Receipts and parent-linked headers are evidence from the selected endpoint, not
receipt-trie proofs or consensus verification. Semantic issuer identity and
review eligibility remain separate from an accepted account's publication.
"""

from .canonical import dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import decode
from .chain_rpc import MAX_TRANSCRIPT, RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_publication import IndependentPublicationAdapter
from .general_attestation_source_v2 import GeneralAttestationSourceV2
from .general_attestation_source import CURATORIAL, CURATOR_FAMILY
from .independent_wire import require


PROFILE = "STREAM_MUSEUM_GENERAL_PUBLICATION_V1"
EVENT_TOPIC = keccak256(b"GeneralAttestationRecorded(uint256,bytes32,bytes32,bytes32,address,uint8,uint8,bytes32,bytes32,uint16)")
EVENT_DATA = ("bytes32", "address", "uint8", "uint8", "bytes32", "bytes32", "uint16")
GRANT_TOPIC = keccak256(b"MetadataFamilyWriterChanged(uint256,bytes32,address,uint8,bool,uint64,bytes32)")
GRANT_DATA = ("uint8", "bool", "uint64", "bytes32")
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


class GeneralPublicationAdapterV1:
    def __init__(self, source, hints_bytes, transport, *, provenance="synthetic_fixture"):
        require(type(source) is GeneralAttestationSourceV2, "concrete General V2 source required")
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "publication provenance")
        require(provenance != "trusted_rpc" or (source.provenance == "trusted_rpc"
                and type(transport) in (RpcTransport, ReplayTransport)), "synthetic publication cannot authenticate state")
        self.source = source
        self.hints_bytes = hints_bytes
        self.reader = RecordingReader(transport, source.a["blockHash"])
        self.provenance = provenance
        self._started = False
        self._snapshot = None

    def _prepare(self):
        self.source_bytes = self.source.snapshot()
        self.capture = loads(self.source_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
        self.records = {r["recordHash"]: r for r in self.capture["records"]}
        hint_value = loads(self.hints_bytes, maximum=1048576, canonical=True)
        require(type(hint_value) is dict and set(hint_value) == {"profile", "records", "curatorGrants"},
                "General publication hint shape")
        self.hints = _hints(dumps({k: hint_value[k] for k in ("profile", "records")}), self.records)
        grants = hint_value["curatorGrants"]
        expected = {h for h, row in self.records.items() if row["value"][3] == CURATORIAL}
        require(type(grants) is list and len(grants) == len(expected), "curator grant hints completeness")
        self.grant_hints = {}
        for row in grants:
            require(type(row) is dict and set(row) == {"recordHash", "transactionHash"}, "curator grant hint shape")
            h, tx = _hash(row["recordHash"]), _hash(row["transactionHash"])
            require(h in expected and h not in self.grant_hints, "foreign or duplicate curator grant hint")
            self.grant_hints[h] = tx
    # Reuse the unchanged strict receipt/header primitives. Only event and
    # historical curator-grant joins belong to this General-specific adapter.
    _header = IndependentPublicationAdapter._header
    _anchor = IndependentPublicationAdapter._anchor
    _receipt = IndependentPublicationAdapter._receipt

    def _event(self, log, expected):
        topics = log["topics"]
        require(len(topics) == 4, "General event indexed topic count")
        scope = int.from_bytes(hex_bytes(topics[1], 32), "big")
        h, attester, verification, authority, supersedes, chain, version = decode(
            EVENT_DATA, hex_bytes(log["data"]), maximum=16384)
        require(version == 1, "General event version mismatch")
        if expected is not None:
            value, receipt = expected["value"], expected["receipt"]
            require(scope == uint(value[1]) and topics[2] == value[3] and topics[3] == value[2]
                and h == expected["recordHash"] and attester == value[0]
                and verification == uint(receipt[1]) and authority == uint(receipt[2])
                and supersedes == value[9] and chain == receipt[5], "General event full record mismatch")
        return h, (str(scope), topics[2])

    def _grants(self, receipts, positions):
        proof, by_hash = [], {p["recordHash"]: p for p in positions}
        for h, tx in self.grant_hints.items():
            row = self.records[h]; saved = row["receipt"]
            matches = []
            for offset, log in enumerate(receipts[tx]["logs"]):
                if log["address"] != self.source.a["metadata"] or not log["topics"] or log["topics"][0] != GRANT_TOPIC:
                    continue
                topics = log["topics"]
                require(len(topics) == 4, "curator grant event topic count")
                cls, enabled, revision, action = decode(GRANT_DATA, hex_bytes(log["data"]))
                account = hex_bytes(topics[3], 32)
                require(account[:12] == bytes(12), "curator grant account topic padding")
                if (int.from_bytes(hex_bytes(topics[1], 32), "big") == uint(saved[16])
                    and topics[2] == CURATOR_FAMILY and "0x" + account[12:].hex() == saved[0]
                    and cls == 3 and revision == uint(saved[17])):
                    require(enabled is True and any(hex_bytes(action, 32)), "curator grant was not enabled")
                    position = [str(quantity(log[k])) for k in ("blockNumber", "transactionIndex", "logIndex")]
                    require(tuple(map(uint, position)) < tuple(map(uint, by_hash[h]["publicationPosition"])),
                            "curator grant must precede original publication")
                    matches.append({"recordHash": h, "operator": saved[0], "collectionId": saved[16],
                        "family": CURATOR_FAMILY, "authorizationClass": "3", "revision": saved[17],
                        "actionId": action, "transactionHash": tx, "publicationPosition": position,
                        "receiptLogOffset": str(offset), "eventHash": keccak256(dumps(log)),
                        "receiptHash": keccak256(dumps(receipts[tx]))})
            require(len(matches) == 1, "exact original curator grant event absent or ambiguous")
            proof.extend(matches)
        return proof

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed publication cannot reuse partial reader state")
        self._started = True
        self._prepare()
        a, reader = self.source.a, self.reader
        require(quantity(reader.request("eth_chainId", [])) == uint(a["chainId"]), "publication chain id mismatch")
        first, anchor_number, anchor_time = self._anchor()
        receipts = {tx: self._receipt(tx) for tx in dict.fromkeys([*self.hints.values(), *self.grant_hints.values()])}
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
        lanes = {(a["collectionId"], lane["recordType"]) for lane in self.capture["lanes"]}
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
            require(matched > 0 or tx in self.grant_hints.values(), "hinted transaction has no selected publication")
        require(set(seen) == set(self.records), "publication record/event completeness mismatch")
        for ranges in block_ranges.values():
            ordered = sorted(ranges)
            require(all(left[2] < right[1] for left, right in zip(ordered, ordered[1:])),
                    "publication log order contradicts transaction order")
        grants = self._grants(receipts, positions)
        self._anchor()
        code = hex_bytes(reader.code(a["host"]))
        require(keccak256(code) == self.source.pins[a["host"]], "publication canonical anchor code mismatch")
        metadata_code = hex_bytes(reader.code(a["metadata"]))
        require(keccak256(metadata_code) == self.source.pins[a["metadata"]], "curator grant host code mismatch")
        from .general_semantic_source_v1 import _consistent
        _consistent([self.source.reader.transcript(), reader.transcript()], self.source.pins)
        if isinstance(reader.transport, ReplayTransport):
            reader.transport.finish()
        result = dumps({"profile": PROFILE,
            "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "evidence": self.provenance, "environment": a["environment"],
            "anchorHash": keccak256(self.source.anchor_bytes), "sourceCaptureHash": keccak256(self.source_bytes),
            "sourceTranscriptHash": keccak256(self.source.reader.transcript()), "hintsHash": keccak256(self.hints_bytes),
            "transcriptHash": keccak256(reader.transcript()),
            "publications": sorted(positions, key=lambda p: tuple(uint(v) for v in p["publicationPosition"])),
            "curatorGrants": grants, "headers": list(headers.values()), "receipts": list(receipts.values()),
            "claims": {"declaredRecordPublicationsComplete": True, "wholeHostLogInventory": False,
                "cryptographicReceiptProof": False, "consensusFinality": False,
                "publicDeploymentAcceptance": False, "semanticPayloadValidation": False,
                "originalCuratorGrantEventsChecked": True, "currentGrantRevalidated": False, "assertingAgentIdentityAdmission": False, "institutionalAcceptance": False}})
        require(len(result) <= MAX_TRANSCRIPT, "publication output byte bound")
        self._snapshot = result
        return result
