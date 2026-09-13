"""Actual local publication replay; hostile receipts and explicitly synthetic arrangements."""

import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import decode, encode
from .chain_rpc import ReplayTransport
from .independent_publication import EVENT_DATA, EVENT_TOPIC, IndependentPublicationAdapter
from .independent_source import IndependentSourceAdapter


FIXTURE = Path(__file__).resolve().parents[2] / "schemas/museum/independent-publication/local-fixture"
SOURCE_HASH = "0xe37251d457433b030259d0f078d9c7f301c1845874ec472baae57a6d57ffce52"
PUBLICATION_HASH = "0x6163b3162d9783396cb2dbec389da9e254f15f2b324d5845f0af45e17b7e922c"
OUTPUT_HASH = "0xe386b4c31b42726ca0455031f069f90d875426eea28822f025c40b9346f4b517"
OTHER_HASH = "0x" + "aa" * 32


class SyntheticRows:
    def __init__(self, rows):
        self.rows = rows

    def request(self, method, params):
        matches = [r for r in self.rows if r["method"] == method and dumps(r["params"]) == dumps(params)]
        if not matches:
            raise MuseumError("synthetic request unavailable")
        return copy.deepcopy(matches[0]["result"])


class IndependentPublicationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.anchor_raw = (FIXTURE / "anchor.json").read_bytes()
        cls.transcript = (FIXTURE / "transcript.json").read_bytes()
        cls.publication_transcript = (FIXTURE / "publication-transcript.json").read_bytes()
        cls.hints_raw = (FIXTURE / "publication-hints.json").read_bytes()
        cls.hints = loads(cls.hints_raw)
        cls.rows = loads(cls.publication_transcript, maximum=1048576)["calls"]
        cls.source = IndependentSourceAdapter(cls.anchor_raw, ReplayTransport(cls.transcript, SOURCE_HASH), provenance="trusted_rpc")
        cls.capture = loads(cls.source.snapshot(), maximum=1048576)
        cls.actual_bytes = (FIXTURE / "publications.json").read_bytes()
        cls.actual = loads(cls.actual_bytes, maximum=1048576)

    def adapter(self, rows=None, hints=None):
        return IndependentPublicationAdapter(self.source, dumps(self.hints if hints is None else hints),
            SyntheticRows(copy.deepcopy(self.rows) if rows is None else rows))

    def receipts(self, rows):
        return [r["result"] for r in rows if r["method"] == "eth_getTransactionReceipt"]

    def event(self, receipt):
        return next(log for log in receipt["logs"] if log["topics"][0] == EVENT_TOPIC)

    def reject(self, rows, message, hints=None):
        with self.assertRaisesRegex(MuseumError, message):
            self.adapter(rows, hints).snapshot()

    def testActualSixPublicationsMatchIndependentReceiptPositions(self):
        self.assertEqual(keccak256(self.publication_transcript), PUBLICATION_HASH)
        self.assertEqual(keccak256(self.actual_bytes), OUTPUT_HASH)
        adapter = IndependentPublicationAdapter(self.source, self.hints_raw,
            ReplayTransport(self.publication_transcript, PUBLICATION_HASH), provenance="trusted_rpc")
        self.assertEqual(adapter.snapshot(), self.actual_bytes)
        self.assertEqual(adapter.snapshot(), self.actual_bytes)
        self.assertEqual(len(adapter.reader.rows), 19)
        self.assertEqual((len(self.actual["headers"]), len(self.actual["receipts"])), (10, 6))
        literal_topic = "0x373a50c0efd697ceb058ba8a5f18262af0d8117008a89848623b926938419ba5"
        evidence = loads((FIXTURE / "deployment-evidence.json").read_bytes(), maximum=1048576)
        expected = []
        host = self.source.a["host"]
        for tx in evidence["transactions"]:
            for offset, log in enumerate(tx["receipt"]["logs"]):
                if log["address"] == host and log["topics"][0] == literal_topic:
                    expected.append((log["transactionHash"], [str(int(log[k], 16)) for k in
                        ("blockNumber", "transactionIndex", "logIndex")], str(offset)))
        self.assertEqual([(p["transactionHash"], p["publicationPosition"], p["receiptLogOffset"])
                          for p in self.actual["publications"]], expected)
        self.assertEqual(self.actual["mode"], "recorded_state")
        self.assertEqual(self.actual["environment"], "local_evm_fixture")
        self.assertFalse(self.actual["claims"]["cryptographicReceiptProof"])
        self.assertFalse(self.actual["claims"]["assertingAgentIdentityAdmission"])
        self.assertFalse(self.actual["claims"]["semanticPayloadValidation"])

    def testEqualTimestampsAndDifferentLaneIndicesDoNotChoosePublicationOrder(self):
        by_hash = {r["recordHash"]: r for r in self.capture["records"]}
        ordered = self.actual["publications"]
        self.assertEqual(len({by_hash[p["recordHash"]]["receipt"][3] for p in ordered[:3]}), 1)
        self.assertEqual(len({by_hash[p["recordHash"]]["receipt"][0] for p in ordered[:3]}), 2)
        self.assertEqual([p["publicationPosition"][0] for p in ordered], ["13", "14", "15", "17", "19", "21"])
        self.assertEqual([by_hash[p["recordHash"]]["receipt"][4] for p in ordered[:3]], ["0", "1", "0"])
        self.assertNotEqual(ordered[0]["recordHash"], self.capture["records"][0]["recordHash"])

    def testSyntheticRowsStaySyntheticAndCannotClaimTrustedPublication(self):
        adapter = self.adapter()
        self.assertEqual(loads(adapter.snapshot(), maximum=1048576)["mode"], "synthetic_fixture")
        with self.assertRaisesRegex(MuseumError, "synthetic publication"):
            IndependentPublicationAdapter(self.source, self.hints_raw, SyntheticRows(self.rows), provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "validated independent"):
            IndependentPublicationAdapter(object(), self.hints_raw, SyntheticRows(self.rows))

    def testHintsRequireEveryExactRecordOnceAndRejectForeignRecords(self):
        for kind in ("missing", "duplicate", "foreign", "extra", "width"):
            with self.subTest(kind=kind):
                hints = copy.deepcopy(self.hints)
                if kind == "missing": hints["records"].pop()
                elif kind == "duplicate": hints["records"][0] = hints["records"][1]
                elif kind == "foreign": hints["records"][0]["recordHash"] = OTHER_HASH
                elif kind == "extra": hints["unexpected"] = True
                else: hints["records"][0]["transactionHash"] = "0x01"
                with self.assertRaises(MuseumError): self.adapter(hints=hints)

    def testEveryGenericEventFieldAndAllIndexedFieldsAreBound(self):
        paths = [(0,), (1,), (2, 0), (2, 1), (2, 2), (3,), (4,), (5,),
                 (6, 0), (6, 1), (6, 2), (7,)]
        def mutable(value):
            return [mutable(v) for v in value] if isinstance(value, tuple) else value
        for path in paths:
            with self.subTest(path=path):
                rows = copy.deepcopy(self.rows)
                event = self.event(self.receipts(rows)[0])
                values = mutable(decode(EVENT_DATA, hex_bytes(event["data"])))
                target = values[0]
                for step in path[:-1]: target = target[step]
                old = target[path[-1]]
                target[path[-1]] = old + 1 if type(old) is int else old + b"x" if type(old) is bytes else (
                    OTHER_HASH if old.startswith("0x") else old + "changed")
                event["data"] = "0x" + encode(EVENT_DATA, values).hex()
                if path == (0,): event["topics"][2] = values[0][0]
                if path == (1,): event["topics"][3] = values[0][1]
                self.reject(rows, "full record mismatch")
        for index in (1, 2, 3):
            rows = copy.deepcopy(self.rows)
            self.event(self.receipts(rows)[0])["topics"][index] = OTHER_HASH
            self.reject(rows, "full record mismatch|indexed tuple mismatch")

    def testEventHashChainAttestorAuthorityAndVersionCannotChange(self):
        for index in range(1, 6):
            rows = copy.deepcopy(self.rows)
            event = self.event(self.receipts(rows)[0])
            values = list(decode(EVENT_DATA, hex_bytes(event["data"])))
            values[index] = 2 if index == 5 else "0x" + "aa" * 20 if index == 3 else OTHER_HASH
            event["data"] = "0x" + encode(EVENT_DATA, values).hex()
            self.reject(rows, "full record mismatch|authority or version|unmatched event")

    def testEventEncodingIsCanonicalAndRequiresFourTopics(self):
        for kind in ("short", "long", "alias", "padding", "topics"):
            rows = copy.deepcopy(self.rows)
            event = self.event(self.receipts(rows)[0])
            data = bytearray(hex_bytes(event["data"]))
            if kind == "short": data = data[:-1]
            elif kind == "long": data += bytes(32)
            elif kind == "alias": data[:32] = (224).to_bytes(32, "big")
            elif kind == "padding": data[96] = 1  # high address padding in static attestor word
            else: event["topics"].pop()
            event["data"] = "0x" + data.hex()
            self.reject(rows, "ABI|topic count")

    def testReceiptMustExistSucceedAndMatchTransaction(self):
        for kind in ("missing", "status", "tx", "after"):
            rows = copy.deepcopy(self.rows)
            row = next(r for r in rows if r["method"] == "eth_getTransactionReceipt")
            if kind == "missing": row["result"] = None
            elif kind == "status": row["result"]["status"] = "0x0"
            elif kind == "tx": row["result"]["transactionHash"] = OTHER_HASH
            else:
                row["result"]["blockNumber"] = "0xffff"
                for log in row["result"]["logs"]: log["blockNumber"] = "0xffff"
            self.reject(rows, "receipt unavailable|transaction or status|after anchor")

    def testRemovedLogsExactBooleanAndAllCoordinatesReject(self):
        for field, value in (("removed", True), ("removed", 0), ("blockHash", OTHER_HASH),
            ("transactionHash", OTHER_HASH), ("blockNumber", "0x99"), ("transactionIndex", "0x1")):
            rows = copy.deepcopy(self.rows)
            self.event(self.receipts(rows)[0])[field] = value
            self.reject(rows, "removed or malformed|coordinate mismatch")
        rows = copy.deepcopy(self.rows)
        receipt = self.receipts(rows)[0]
        receipt["logs"][-1]["logIndex"] = receipt["logs"][0]["logIndex"]
        self.reject(rows, "duplicate or unordered")

    def testDuplicateMissingAndWrongHostEventsDoNotSupplyPublication(self):
        for kind in ("duplicate", "missing", "host", "signature"):
            rows = copy.deepcopy(self.rows)
            receipt = self.receipts(rows)[0]
            event = self.event(receipt)
            if kind == "duplicate":
                duplicate = copy.deepcopy(event)
                duplicate["logIndex"] = hex(int(event["logIndex"], 16) + 1)
                receipt["logs"].append(duplicate)
            elif kind == "missing": receipt["logs"].remove(event)
            elif kind == "host": event["address"] = "0x" + "aa" * 20
            else: event["topics"][0] = OTHER_HASH
            self.reject(rows, "duplicate or wrongly hinted|no selected publication")

    def testHeadersMustMatchExactHashAncestryNumbersAndTimestamp(self):
        for kind in ("hash", "parent", "number", "timestamp", "state"):
            rows = copy.deepcopy(self.rows)
            blocks = [r for r in rows if r["method"] == "eth_getBlockByHash"]
            if kind == "hash": blocks[0]["result"]["hash"] = OTHER_HASH
            elif kind == "parent": blocks[0]["result"]["parentHash"] = OTHER_HASH
            elif kind == "state": blocks[0]["result"]["stateRoot"] = OTHER_HASH
            elif kind == "number": blocks[1]["result"]["number"] = "0x1"
            else: blocks[1]["result"]["timestamp"] = hex(int(blocks[0]["result"]["timestamp"], 16) + 1)
            self.reject(rows, "block hash mismatch|synthetic request unavailable|anchor mismatch|ancestry")
        with patch("tools.museum.independent_publication.MAX_HEADERS", 1):
            self.reject(copy.deepcopy(self.rows), "ancestry bound")

    def testExactHostRecordedTimeAndBlockTransactionMembership(self):
        rows = copy.deepcopy(self.rows)
        oldest = min((r["result"] for r in rows if r["method"] == "eth_getBlockByHash"), key=lambda b: int(b["number"], 16))
        oldest["timestamp"] = hex(int(oldest["timestamp"], 16) - 1)
        self.reject(rows, "timestamp differs from host")
        for kind in ("wrong", "duplicate", "index"):
            rows = copy.deepcopy(self.rows)
            receipt = self.receipts(rows)[0]
            block = next(r["result"] for r in rows if r["method"] == "eth_getBlockByHash" and r["result"]["hash"] == receipt["blockHash"])
            if kind == "wrong": block["transactions"][0] = OTHER_HASH
            elif kind == "duplicate": block["transactions"].append(block["transactions"][0])
            else:
                receipt["transactionIndex"] = "0x1"
                for log in receipt["logs"]: log["transactionIndex"] = "0x1"
            self.reject(rows, "transaction inclusion mismatch|duplicate block transaction")

    def testMultipleRecordsInOneTransactionRemainDistinctSyntheticPositions(self):
        rows, hints = copy.deepcopy(self.rows), copy.deepcopy(self.hints)
        first, second = self.receipts(rows)[:2]
        for hint in hints["records"]:
            if hint["transactionHash"] == second["transactionHash"]: hint["transactionHash"] = first["transactionHash"]
        start = int(first["logs"][-1]["logIndex"], 16) + 1
        for index, log in enumerate(second["logs"]):
            for key in ("transactionHash", "transactionIndex", "blockHash", "blockNumber"): log[key] = first[key]
            log["logIndex"] = hex(start + index)
        first["logs"].extend(second["logs"])
        result = loads(self.adapter(rows, hints).snapshot(), maximum=1048576)
        same = [p for p in result["publications"] if p["transactionHash"] == first["transactionHash"]]
        self.assertEqual(len(same), 2)
        self.assertEqual(same[0]["publicationPosition"][:2], same[1]["publicationPosition"][:2])
        self.assertLess(int(same[0]["publicationPosition"][2]), int(same[1]["publicationPosition"][2]))
        self.assertEqual(result["mode"], "synthetic_fixture")

    def testSameBlockTransactionOrderAndGlobalLogOrderAgreeSyntheticControl(self):
        rows = copy.deepcopy(self.rows)
        first, second = self.receipts(rows)[:2]
        block = next(r["result"] for r in rows if r["method"] == "eth_getBlockByHash" and r["result"]["hash"] == first["blockHash"])
        block["transactions"].append(second["transactionHash"])
        second["blockHash"], second["blockNumber"], second["transactionIndex"] = first["blockHash"], first["blockNumber"], "0x1"
        for index, log in enumerate(second["logs"]):
            for key in ("transactionIndex", "blockHash", "blockNumber"): log[key] = second[key]
            log["logIndex"] = hex(int(first["logs"][-1]["logIndex"], 16) + 1 + index)
        self.assertEqual(len(loads(self.adapter(rows).snapshot(), maximum=1048576)["publications"]), 6)
        for index, log in enumerate(second["logs"]): log["logIndex"] = hex(index)
        self.reject(rows, "log order contradicts transaction order")

    def testExternalReplayCommitmentsEndAnchorAndFailedReuseAreEnforced(self):
        altered = self.publication_transcript.replace(b'"version":1', b'"version":true')
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            ReplayTransport(altered, PUBLICATION_HASH)
        with self.assertRaisesRegex(MuseumError, "wire version"):
            ReplayTransport(altered, keccak256(altered))
        rows = copy.deepcopy(self.rows)
        rows[-1]["result"] = "0x00"
        bad = self.adapter(rows)
        with self.assertRaisesRegex(MuseumError, "anchor code mismatch"): bad.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot reuse"): bad.snapshot()
        # Rehashed ordered replay reaches the *second* anchor response, not a synthetic first-match lookup.
        rows = copy.deepcopy(self.rows)
        rows[-2]["result"]["stateRoot"] = OTHER_HASH
        raw = dumps({"version": 1, "calls": rows})
        adapter = IndependentPublicationAdapter(self.source, self.hints_raw,
            ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "anchor mismatch"): adapter.snapshot()

    def testOfflineCliReproducesAllSixBoundArtifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "publication"
            result = subprocess.run([sys.executable, "-m", "tools.museum.independent_publication",
                "--anchor", str(FIXTURE / "anchor.json"), "--source-transcript", str(FIXTURE / "transcript.json"),
                "--source-transcript-hash", SOURCE_HASH, "--hints", str(FIXTURE / "publication-hints.json"),
                "--publication-transcript", str(FIXTURE / "publication-transcript.json"),
                "--publication-transcript-hash", PUBLICATION_HASH, "--output", str(output)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr.decode())
            for target, original in (("anchor.json", "anchor.json"), ("source-transcript.json", "transcript.json"),
                ("source-capture.json", "source-capture.json"), ("publication-hints.json", "publication-hints.json"),
                ("publication-transcript.json", "publication-transcript.json"), ("publications.json", "publications.json")):
                self.assertEqual((output / target).read_bytes(), (FIXTURE / original).read_bytes())


if __name__ == "__main__":
    unittest.main()
