"""Focused controls for current preservation packet fields 8 and 11."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import acquisition_preservation_current_v1 as p
from . import public_chain_history as history
from . import public_history_rpc as rpc
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO


A = lambda value: "0x" + value.to_bytes(20, "big").hex()
H = lambda label: schema_id("current preservation fixture " + label)


def context(**changes):
    value = {"chainId": "31337", "core": A(2), "collectionId": "1", "tokenId": "41",
        "blockHash": H("source block"), "blockNumber": "5", "timestamp": "1790000000",
        "stateRoot": H("state root"), "environment": "local_evm_fixture",
        "deploymentEvidenceHash": H("deployment evidence")}
    value.update(changes); return value


def packet(c=None, mode="OFFCHAIN_HASH_BOUND", work="script"):
    c = context() if c is None else c
    state = {key: c[key] for key in ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber")}
    state.update(collectionSerial="3", lifecycle="2", burned=False, examinedAt=c["timestamp"])
    return {"sourceState": state, "metadataMode": mode, "workClass": work,
        "preservation": {"coverage": "uncovered_overdue"},
        "scriptDrill": {"status": "never_drilled", "evidence": {}}}


class Transport:
    def __init__(self, c, records, source_header=None):
        self.c, self.records = c, records
        self.host, self.code = A(900), b"\x60\x00"
        self.runtime = keccak256(self.code)
        self.logs = [row["log"] for row in records]
        self.tx = {row["log"]["transactionHash"]: row for row in records}
        self.source = (self.header(int(c["blockNumber"]), c["blockHash"], int(c["timestamp"]), [])
            if source_header is None else deepcopy(source_header))

    def header(self, number, digest, stamp, transactions):
        return {"hash": digest, "number": hex(number), "stateRoot": self.c["stateRoot"],
            "parentHash": ZERO if number == 0 else H("parent " + str(number)),
            "timestamp": hex(stamp), "transactions": transactions}

    def request(self, method, params):
        if method == "eth_chainId": return hex(int(self.c["chainId"]))
        if method in ("eth_getBlockByHash", "eth_getBlockByNumber"):
            if params[0] in (self.c["blockHash"], hex(int(self.c["blockNumber"]))): return self.source
            row = next(r for r in self.records if params[0] in (r["log"]["blockHash"], r["log"]["blockNumber"]))
            return self.header(int(row["log"]["blockNumber"], 16), row["log"]["blockHash"],
                row["recordedAt"], [row["log"]["transactionHash"]])
        if method == "eth_getLogs":
            query = params[0]
            return [row for row in self.logs if history._matches(row, query)]
        if method == "eth_getTransactionReceipt":
            row = self.tx[params[0]]; log = row["log"]
            return {"transactionHash": log["transactionHash"], "status": "0x1",
                "blockHash": log["blockHash"], "blockNumber": log["blockNumber"],
                "transactionIndex": log["transactionIndex"], "logs": [log]}
        if method == "eth_getCode": return "0x" + self.code.hex()
        if method == "eth_call":
            data = params[0]["data"]
            constants = {
                calldata("streamCore()")[:10]: (("address",), (self.c["core"],)),
                calldata("recordFamilyRegistry()")[:10]: (("address",), (A(902),)),
                calldata("isStreamPreservationRecords()")[:10]: (("bool",), (True,)),
                calldata("streamModuleFamily()")[:10]: (("bytes32",), (p.MODULE_FAMILY,)),
                calldata("streamModuleVersion()")[:10]: (("bytes32",), (p.MODULE_VERSION,)),
                calldata("streamModuleSchemaHash()")[:10]: (("bytes32",), (p.MODULE_SCHEMA,)),
            }
            if data[:10] in constants:
                outputs, values = constants[data[:10]]; return "0x" + encode(outputs, values).hex()
            if data.startswith(calldata("collectionRecord(bytes32)")[:10]):
                digest, = decode(("bytes32",), bytes.fromhex(data[10:]))
                return "0x" + encode((p.RECORD,), (self.by_hash(digest)["record"],)).hex()
            if data.startswith(calldata("collectionRecordSummary(bytes32)")[:10]):
                digest, = decode(("bytes32",), bytes.fromhex(data[10:]))
                return "0x" + encode((p.SUMMARY,), (self.by_hash(digest)["summary"],)).hex()
            if data.startswith(calldata("latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)")[:10]):
                collection, kind, subject, recorder = decode(
                    ("uint256", "bytes32", "bytes32", "address"), bytes.fromhex(data[10:]))
                matches = [row for row in self.records if collection == 1 and row["record"][0] == kind
                    and row["record"][1] == subject and row["recorder"] == recorder]
                return "0x" + encode(("bytes32",), (matches[-1]["recordHash"],)).hex()
        raise AssertionError((method, params))

    def by_hash(self, digest): return next(row for row in self.records if row["recordHash"] == digest)


def native_row(c, kind=p.FIXITY_CYCLE, index=0):
    host, recorder = A(900), A(901)
    record = (kind, H("subject " + str(index)), (1, bytes.fromhex(H("content")[2:]), p.JCS),
        "ipfs://retained", H("unregistered schema"), H("signature scheme"),
        (1, bytes.fromhex(H("signature")[2:]), p.JCS), 1789999900 + index)
    digest = p._record_hash(31337, host, c["core"], recorder, 1, record)
    recorded, auth = 1789999950 + index, 4
    summary = (1, record[0], record[1], digest, record[2][0], keccak256(record[2][1]),
        record[2][2], record[3], keccak256(record[3].encode()), record[4], record[5],
        record[6][0], keccak256(record[6][1]), record[6][2], record[7], recorder, recorded, auth)
    block, tx = H("publication block " + str(index)), H("publication tx " + str(index))
    log = {"address": host, "blockHash": block, "blockNumber": hex(3 + index),
        "transactionHash": tx, "transactionIndex": "0x0", "logIndex": "0x0",
        "topics": [p.EVENT, "0x" + (1).to_bytes(32, "big").hex(), kind, record[1]],
        "data": "0x" + encode((p.RECORD, "bytes32", "address", "uint8"),
            (record, digest, recorder, auth)).hex(), "removed": False}
    return {"record": record, "recordHash": digest, "recorder": recorder,
        "recordedAt": recorded, "summary": summary, "log": log}


def record_source(c=None, rows=(), source_header=None):
    c = context() if c is None else c; transport = Transport(c, list(rows), source_header)
    reader = rpc.PublicRecordingReader(transport, c["blockHash"])
    filters = [{"address": transport.host, "topics": [p.EVENT,
        "0x" + int(c["collectionId"]).to_bytes(32, "big").hex(), kind]}
        for kind in (p.FIXITY_CYCLE, p.SCRIPT_DRILL)]
    scanned = history.scan_public_history(reader, c, filters=filters)
    reader.request("eth_getCode", [transport.host,
        {"blockHash": c["blockHash"], "requireCanonical": True}])
    for signature in ("streamCore()", "recordFamilyRegistry()", "isStreamPreservationRecords()",
                      "streamModuleFamily()", "streamModuleVersion()", "streamModuleSchemaHash()"):
        reader.request("eth_call", [{"to": transport.host, "data": calldata(signature),
            "gas": "0x1000000"}, reader.block])
    latest = {}
    for log in scanned["logs"]:
        _, digest, recorder, _ = decode((p.RECORD, "bytes32", "address", "uint8"), bytes.fromhex(log["data"][2:]))
        for signature, output in (("collectionRecord(bytes32)", (p.RECORD,)),
                                  ("collectionRecordSummary(bytes32)", (p.SUMMARY,))):
            reader.request("eth_call", [{"to": transport.host,
                "data": calldata(signature, ("bytes32",), (digest,)), "gas": "0x1000000"}, reader.block])
        row = transport.by_hash(digest); latest[(row["record"][0], row["record"][1], recorder)] = digest
    for (kind, subject, recorder), digest in sorted(latest.items()):
        reader.request("eth_call", [{"to": transport.host, "data": calldata(
            "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)",
            ("uint256", "bytes32", "bytes32", "address"), (1, kind, subject, recorder)),
            "gas": "0x1000000"}, reader.block])
    transcript = loads(reader.transcript(), canonical=True)
    return {"host": transport.host, "runtimeHash": transport.runtime,
        "anchorHash": keccak256(dumps(c)), "transcriptHash": keccak256(dumps(transcript)),
        "transcript": transcript, "provenance": "synthetic_fixture"}


def evidence(c=None, rows=(), retrieval_envelope=None, source_header=None):
    c = context() if c is None else c
    return {"sourceRevision": p.SOURCE_REVISION, "retrievalEnvelope": retrieval_envelope,
        "recordSource": record_source(c, rows, source_header)}


def preservation_inputs(c=None, *, mode="OFFCHAIN_HASH_BOUND", work="script", rows=(),
                        retrieval_envelope=None, source_header=None):
    c = context() if c is None else c
    return packet(c, mode, work), evidence(c, rows, retrieval_envelope, source_header), c,


def input_envelope(c=None, graph=None, **kwargs):
    pkt, ev, c = preservation_inputs(c, **kwargs)
    return pkt, {"context": c, "graph": {} if graph is None else graph, "evidence": ev}


class CurrentPreservationTests(unittest.TestCase):
    def test_authenticated_empty_histories_produce_only_supported_packet_patches(self):
        pkt, ev, c = preservation_inputs()
        result = p.consume(pkt, ev, context=c, graph={})
        preservation = loads(result.files[p.PRESERVATION_PATH], canonical=True)
        drill = loads(result.files[p.DRILL_PATH], canonical=True)
        self.assertEqual(preservation["coverageStatus"], "unresolved")
        self.assertIsNone(preservation["packetPatch"])
        self.assertIsNone(drill["packetPatch"])
        self.assertFalse(drill["history"]["hostSelectionProven"])
        self.assertEqual(result.observations[0]["kind"], "rpc")

    def test_title_v5_state_can_parameterize_complete_empty_scan(self):
        c = context(blockHash=H("title block"), blockNumber="5", timestamp="1790000000")
        pkt, ev, _ = preservation_inputs(c)
        result = p.consume(pkt, ev, context=c, graph={})
        self.assertEqual(result.report["sourceState"], c)

    def test_mode_total_values_do_not_need_archive_claims(self):
        for mode, expected in (("ONCHAIN", "onchain_bound"), ("HYBRID", "onchain_bound"),
                               ("SERVICE_BACKED", "service_backed_mutable")):
            pkt, ev, c = preservation_inputs(mode=mode)
            body = loads(p.consume(pkt, ev, context=c, graph={}).files[p.PRESERVATION_PATH], canonical=True)
            self.assertIsNone(body["packetPatch"])
            self.assertEqual(body["suppliedModeApplicability"]["interpretation"], expected)

    def test_nonempty_generic_history_is_retained_without_semantic_projection(self):
        c = context(); row = native_row(c)
        pkt, ev, _ = preservation_inputs(c, mode="ONCHAIN", rows=(row,))
        result = p.consume(pkt, ev, context=c, graph={})
        body = loads(result.files[p.PRESERVATION_PATH], canonical=True)
        self.assertEqual(body["fixityCycleHistory"]["status"], "retained_unmapped")
        self.assertIsNone(body["packetPatch"])
        self.assertFalse(result.report["claims"]["latestFixityCycleSemanticsProven"])

    def test_complete_query_record_summary_latest_and_runtime_tampering_refuses(self):
        c = context(); pkt, ev, _ = preservation_inputs(c, rows=(native_row(c),))
        cases = []
        for index, row in enumerate(ev["recordSource"]["transcript"]["calls"]):
            if row["method"] in ("eth_getLogs", "eth_call", "eth_getCode"):
                cases.append(index)
        for index in cases:
            changed = deepcopy(ev); row = changed["recordSource"]["transcript"]["calls"][index]
            if row["method"] == "eth_getLogs": row["result"] = [] if row["result"] else [{}]
            elif row["method"] == "eth_getCode": row["result"] = "0x6001"
            else: row["result"] = "0x" + bytes(len(bytes.fromhex(row["result"][2:]))).hex()
            changed["recordSource"]["transcriptHash"] = keccak256(dumps(changed["recordSource"]["transcript"]))
            with self.assertRaises(MuseumError): p.consume(pkt, changed, context=c, graph={})

    def test_non_script_is_not_applicable_but_script_nonempty_remains_unresolved(self):
        c = context(); drill = native_row(c, p.SCRIPT_DRILL)
        pkt, ev, _ = preservation_inputs(c, work="script", rows=(drill,))
        body = loads(p.consume(pkt, ev, context=c, graph={}).files[p.DRILL_PATH], canonical=True)
        self.assertIsNone(body["packetPatch"])
        pkt, ev, _ = preservation_inputs(c, work="non_script", rows=(drill,))
        body = loads(p.consume(pkt, ev, context=c, graph={}).files[p.DRILL_PATH], canonical=True)
        self.assertIsNone(body["packetPatch"])
        self.assertEqual(body["suppliedWorkApplicability"]["interpretation"], "not_applicable")

    def test_current_retrieval_can_support_offchain_coverage(self):
        from .test_view_preservation_retrieval_v1 import complete_envelope
        envelope = complete_envelope(); c = dict(envelope["context"])
        pkt, ev, _ = preservation_inputs(c, retrieval_envelope=envelope)
        with patch("socket.socket", side_effect=AssertionError("network used")):
            result = p.consume(pkt, ev, context=c, graph=envelope["graph"])
        body = loads(result.files[p.PRESERVATION_PATH], canonical=True)
        self.assertEqual(body["coverageStatus"], "covered")
        self.assertEqual(len(body["currentArchive"]["media"]), 1)
        self.assertEqual([row["kind"] for row in result.observations], ["native", "rpc"])
        pins = result.observations[0]["runtimePins"]
        carrier = envelope["sourceProof"]["bundle"]["adoption"]["history"][0]["carrier"]
        checkpoint = envelope["retrieval"]["records"][0]["current"]["sourceEvidence"]["checkpoint"]
        self.assertEqual(pins[carrier["pointer"]], carrier["codeHash"])
        self.assertEqual(pins[checkpoint["verifier"]], checkpoint["runtimeHash"])
        self.assertGreater(len(pins), len(envelope["graph"]) + 1)

    def test_reference_render_or_archive_fixity_never_becomes_drill_or_cycle(self):
        pkt, ev, c = preservation_inputs(mode="ONCHAIN")
        result = p.consume(pkt, ev, context=c, graph={})
        self.assertFalse(result.report["claims"]["latestFixityCycleSemanticsProven"])
        self.assertFalse(result.report["claims"]["preservationDrillSemanticsProven"])


if __name__ == "__main__": unittest.main()
