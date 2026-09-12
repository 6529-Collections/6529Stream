"""One-block INDEPENDENT lane capture; no writes or fixture projection promotion."""

import argparse
import os
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .chain_abi import calldata, decode
from .chain_rpc import RecordingReader, ReplayTransport, RpcTransport, quantity
from .independent_wire import (DOCUMENT, RAW_BYTES, RECORD_TYPES, ZERO, ZERO_ADDRESS,
                               json_values, require, verify_document, verify_record)


PROFILE = "STREAM_MUSEUM_INDEPENDENT_SOURCE_V1"
MAX_RECORDS = 4096
MAX_DOCUMENTS = 512
MAX_DOCUMENT_BYTES = 16777216


def _anchor(raw):
    a = loads(raw, maximum=524288, canonical=True)
    required = {"profile", "chainId", "blockHash", "blockNumber", "timestamp", "stateRoot",
                "environment", "deploymentEvidenceHash", "host", "core", "schemas", "store",
                "codePins", "lanes"}
    require(isinstance(a, dict) and set(a) == required and a["profile"] == PROFILE, "anchor shape/profile")
    require(a["environment"] in ("local_evm_fixture", "public_chain"), "anchor environment")
    for field in ("chainId", "blockNumber", "timestamp"):
        uint(a[field])
    require(uint(a["timestamp"]) < 1 << 64, "anchor timestamp width")
    for field in ("blockHash", "stateRoot", "deploymentEvidenceHash"):
        require(hex_bytes(a[field], 32) != bytes(32), "anchor zero commitment")
    for field in ("host", "core", "schemas", "store"):
        require(hex_bytes(a[field], 20) != bytes(20), "anchor zero address")
    require(isinstance(a["codePins"], list) and 4 <= len(a["codePins"]) <= 64, "code pin bound")
    pins = {}
    for p in a["codePins"]:
        require(isinstance(p, dict) and set(p) == {"address", "runtimeHash"}, "code pin shape")
        hex_bytes(p["address"], 20)
        hex_bytes(p["runtimeHash"], 32)
        require(p["address"] not in pins, "duplicate code pin")
        pins[p["address"]] = p["runtimeHash"]
    require(all(a[f] in pins for f in ("host", "core", "schemas", "store")), "missing dependency code pin")
    require(isinstance(a["lanes"], list) and 0 < len(a["lanes"]) <= 1024, "declared lane bound")
    lanes = []
    for lane in a["lanes"]:
        require(isinstance(lane, dict) and set(lane) == {"scopeKey", "recordType"}, "lane shape")
        value = (uint(lane["scopeKey"]), lane["recordType"])
        require(value[1] in RECORD_TYPES and value not in lanes, "duplicate/unsupported lane")
        lanes.append(value)
    return a, pins, lanes


class IndependentSourceAdapter:
    """An externally anchored deployment and declared lanes, never whole-host inventory.

    A synthetic transport can exercise all byte checks but cannot produce
    recorded_state. Offline recorded replay requires its externally supplied
    transcript commitment; neither route implements MPT/consensus verification.
    """

    def __init__(self, anchor_bytes, transport, *, provenance="synthetic_fixture"):
        require(provenance in ("synthetic_fixture", "trusted_rpc"), "source provenance")
        require(provenance != "trusted_rpc" or type(transport) in (RpcTransport, ReplayTransport),
                "synthetic transport cannot authenticate source")
        self.anchor_bytes = anchor_bytes
        self.a, self.pins, self.lanes = _anchor(anchor_bytes)
        self.reader = RecordingReader(transport, self.a["blockHash"])
        self.provenance = provenance
        self.documents = {}
        self.document_stack = set()
        self.document_bytes = 0
        self.chunks = {}
        self._started = False
        self._snapshot = None

    def _read(self, target, signature, inputs=(), values=(), outputs=(), maximum=32768):
        raw = hex_bytes(self.reader.call(target, calldata(signature, inputs, values)))
        require(len(raw) <= maximum, "ABI response profile bound")
        return raw, decode(outputs, raw, maximum=maximum)

    def _block(self):
        b = self.reader.request("eth_getBlockByHash", [self.a["blockHash"], False])
        require(isinstance(b, dict), "anchored block unavailable")
        for field in ("hash", "stateRoot"):
            require(b.get(field) == self.a["blockHash" if field == "hash" else field], "block anchor mismatch")
        for field in ("number", "timestamp"):
            require(quantity(b.get(field)) == uint(self.a["blockNumber" if field == "number" else field]),
                    "block numeric anchor mismatch")

    def _chunk(self, digest, expected_pointer=None):
        if digest not in self.chunks:
            _, (pointer, length) = self._read(self.a["store"], "chunk(bytes32)", ("bytes32",),
                                             (digest,), ("address", "uint32"))
            require(pointer != ZERO_ADDRESS and 0 < length <= 8192, "chunk pointer/length")
            code = hex_bytes(self.reader.code(pointer))
            require(len(code) == length + 1 and code[:1] == b"\0" and keccak256(code[1:]) == digest,
                    "SSTORE2 code prefix/length/hash mismatch")
            self.chunks[digest] = (pointer, code[1:])
        pointer, payload = self.chunks[digest]
        require(expected_pointer is None or expected_pointer == pointer, "host/store pointer mismatch")
        return payload

    def _document(self, document_id, expected_kind=None, expected_hash=None):
        require(document_id not in self.document_stack, "interpretation document cycle")
        if document_id not in self.documents:
            require(len(set(self.documents) | self.document_stack) < MAX_DOCUMENTS, "document closure count bound")
            self.document_stack.add(document_id)
            raw, (d,) = self._read(self.a["schemas"], "document(bytes32)", ("bytes32",),
                                   (document_id,), (DOCUMENT,), maximum=8192)
            require(d[0] and 0 < len(d[4]) <= 64, "unregistered or empty document")
            parts = [self._chunk(h) for h in d[4]]
            require(all(len(p) == 8192 for p in parts[:-1]) and 0 < len(parts[-1]) <= 8192,
                    "document canonical segment lengths")
            payload = b"".join(parts)
            verify_document(document_id, raw, payload)
            self.document_bytes += len(payload)
            require(self.document_bytes <= MAX_DOCUMENT_BYTES, "document closure byte bound")
            self.documents[document_id] = (raw, payload, d)
            canonical, predecessor = d[3][3:5]
            if canonical != document_id:
                self._document(canonical, 1)
            else:
                require(document_id == RAW_BYTES, "nonbootstrap canonicalization cycle")
            if predecessor != ZERO:
                self._document(predecessor, d[3][1])
            self.document_stack.remove(document_id)
        raw, payload, _ = self.documents[document_id]
        verify_document(document_id, raw, payload, expected_kind, expected_hash)

    def snapshot(self):
        if self._snapshot is not None:
            return self._snapshot
        require(not self._started, "failed capture cannot reuse partial reader state")
        self._started = True
        a, r = self.a, self.reader
        require(quantity(r.request("eth_chainId", [])) == uint(a["chainId"]), "chain id mismatch")
        self._block()
        for address, expected in self.pins.items():
            code = hex_bytes(r.code(address))
            require(0 < len(code) <= 24576 and keccak256(code) == expected, "runtime identity mismatch")
        for field, getter in (("core", "core()"), ("schemas", "schemaRegistry()"), ("store", "chunkStore()")):
            _, (actual,) = self._read(a["host"], getter, outputs=("address",))
            require(actual == a[field], "host dependency address mismatch")
        _, (store,) = self._read(a["schemas"], "chunkStore()", outputs=("address",))
        require(store == a["store"], "schema chunk store mismatch")
        for field, getter in (("core", "coreCodeHash()"), ("schemas", "schemaRegistryCodeHash()"),
                              ("store", "chunkStoreCodeHash()")):
            _, (saved,) = self._read(a["host"], getter, outputs=("bytes32",))
            require(saved == self.pins[a[field]], "host constructor code pin mismatch")
        _, (supported,) = self._read(a["host"], "supportsInterface(bytes4)", ("bytes4",),
                                      ("0x771b2917",), ("bool",))
        require(supported, "unsupported dedicated independent host")
        records, lane_results, all_hashes = [], [], set()
        for scope, record_type in self.lanes:
            _, (head, count) = self._read(a["host"], "recordChainHash(uint256,bytes32)",
                ("uint256", "bytes32"), (scope, record_type), ("bytes32", "uint64"))
            require(len(records) + count <= MAX_RECORDS, "record inventory bound")
            previous, latest = ZERO, {}
            for index in range(count):
                _, (h,) = self._read(a["host"], "recordHashAt(uint256,bytes32,uint256)",
                    ("uint256", "bytes32", "uint256"), (scope, record_type, index), ("bytes32",))
                require(h != ZERO and h not in all_hashes, "duplicate/missing lane record")
                all_hashes.add(h)
                # Raw bytes are independently decoded again by the wire verifier.
                record_raw = hex_bytes(r.call(a["host"], calldata("collectionRecord(bytes32)", ("bytes32",), (h,))))
                subject_raw = hex_bytes(r.call(a["host"], calldata("recordSubject(bytes32)", ("bytes32",), (h,))))
                payloads = []
                pointers = []
                for getter in ("recordPayload(bytes32)", "recordSignatureBundle(bytes32)"):
                    _, (pointer, payload) = self._read(a["host"], getter, ("bytes32",), (h,), ("address", "bytes"))
                    require(0 < len(payload) <= 8192, "record/bundle payload bound")
                    require(self._chunk(keccak256(payload), pointer) == payload, "record pointer bytes mismatch")
                    payloads.append(payload)
                    pointers.append(pointer)
                record, receipt, subject = verify_record(uint(a["chainId"]), a["host"], a["core"],
                    uint(a["timestamp"]), (scope, record_type), index, previous, h,
                    record_raw, subject_raw, *payloads)
                self._document(record[4], 0, receipt[9])
                self._document(record[2][2], 1, receipt[10])
                _, (used,) = self._read(a["host"], "isIndependentAttestorNonceUsed(address,uint256)",
                    ("address", "uint256"), (receipt[1], receipt[7]), ("bool",))
                require(used, "accepted record nonce not consumed")
                records.append({"recordHash": h, "record": json_values(record), "receipt": json_values(receipt),
                    "subject": json_values(subject), "payloadHex": "0x" + payloads[0].hex(),
                    "signatureBundleHex": "0x" + payloads[1].hex(), "pointers": pointers,
                    "authority": {"class": "5", "attestor": receipt[1], "basis": "historical_host_receipt",
                                  "currentSignatureRevalidation": False},
                    "subjectMembership": "declared_media_reference" if subject[0] == 2 else "host_admitted_at_write"})
                previous = receipt[5]
                latest[(record[1], receipt[1])] = h
            require(previous == head, "lane final chain/count mismatch")
            for (subject_id, attestor), expected in latest.items():
                _, (actual,) = self._read(a["host"], "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
                    ("uint256", "bytes32", "bytes32", "address"), (scope, record_type, subject_id, attestor), ("bytes32",))
                require(actual == expected, "attestor scoped latest mismatch")
            lane_results.append({"scopeKey": str(scope), "recordType": record_type, "count": str(count), "chainHash": head})
        self._block()
        if isinstance(r.transport, ReplayTransport):
            r.transport.finish()
        self._snapshot = dumps({"profile": PROFILE, "mode": "recorded_state" if self.provenance == "trusted_rpc" else "synthetic_fixture",
            "evidence": self.provenance, "environment": a["environment"], "anchorHash": keccak256(self.anchor_bytes),
            "transcriptHash": keccak256(r.transcript()), "lanes": lane_results, "records": records,
            "documents": [{"documentId": key, "view": json_values(d), "payloadHex": "0x" + payload.hex()}
                          for key, (_, payload, d) in self.documents.items()],
            "claims": {"declaredLanesComplete": True, "wholeHostInventory": False, "wholeCollectionInventory": False,
                       "cryptographicStateProof": False, "consensusFinality": False, "publicDeploymentAcceptance": False,
                       "semanticPayloadValidation": False, "institutionalAcceptance": False}})
        return self._snapshot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--anchor", type=Path, required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--rpc-env", help="Environment variable holding an explicitly trusted RPC endpoint")
    source.add_argument("--transcript", type=Path)
    parser.add_argument("--transcript-hash", help="Externally trusted keccak256 for offline replay")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.rpc_env:
        require(args.transcript_hash is None and args.rpc_env in os.environ, "RPC endpoint variable unavailable")
        transport = RpcTransport(os.environ[args.rpc_env])
    else:
        require(args.transcript_hash is not None, "offline replay needs external transcript commitment")
        transport = ReplayTransport(args.transcript.read_bytes(), args.transcript_hash)
    adapter = IndependentSourceAdapter(args.anchor.read_bytes(), transport, provenance="trusted_rpc")
    output = adapter.snapshot()
    args.output.mkdir(parents=True, exist_ok=False)
    (args.output / "anchor.json").write_bytes(adapter.anchor_bytes)
    (args.output / "transcript.json").write_bytes(adapter.reader.transcript())
    (args.output / "source-capture.json").write_bytes(output)
    print(dumps({"captureHash": keccak256(output), "output": str(args.output)}).decode())


if __name__ == "__main__":
    main()
