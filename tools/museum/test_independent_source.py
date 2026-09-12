"""Pinned actual local-EVM replay and hostile independent-source responses."""

import copy
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, record_chain, schema_id
from .chain_abi import Array, calldata, decode, encode
from .chain_rpc import ReplayTransport, RpcTransport, quantity
from .independent_source import IndependentSourceAdapter
from .independent_wire import (DOCUMENT, RECORD, RECEIPT, SUBJECT, ZERO, domain,
                               generic_hash, verify_record)
from .local_independent_fixture import LocalFixture


FIXTURE = Path(__file__).resolve().parents[2] / "schemas/museum/independent-source/local-fixture"
TRANSCRIPT_HASH = "0xf489f9781d309ed1089be18358b7537044a3ff5e2a82a686bb02133050f2847e"
CAPTURE_HASH = "0x081f67725e6ae980186031abf14509cf93512ead7627cb7515e683a503b3e00c"


def read_fixture(name):
    return (FIXTURE / name).read_bytes()


class FixtureTransport:
    def __init__(self, rows):
        self.rows = rows
        self.used = []

    def request(self, method, params):
        self.used.append((method, params))
        for row in self.rows:
            if row["method"] == method and row["params"] == params:
                return copy.deepcopy(row["result"])
        raise MuseumError("fixture call is absent")


class IndependentSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.anchor_raw = read_fixture("anchor.json")
        cls.anchor = loads(cls.anchor_raw)
        cls.transcript = read_fixture("transcript.json")
        cls.rows = loads(cls.transcript, maximum=1048576)["calls"]
        cls.capture_raw = read_fixture("source-capture.json")
        cls.capture = loads(cls.capture_raw, maximum=1048576)

    def adapter(self, rows=None, anchor=None):
        return IndependentSourceAdapter(dumps(anchor or self.anchor), FixtureTransport(rows or copy.deepcopy(self.rows)))

    def response(self, rows, signature, occurrence=0):
        prefix = calldata(signature)[:10]
        return [r for r in rows if r["method"] == "eth_call" and r["params"][0]["data"].startswith(prefix)][occurrence]

    def testActualLocalSixRecordsReplayExactlyAndRetainBoundaries(self):
        self.assertEqual(keccak256(self.transcript), TRANSCRIPT_HASH)
        self.assertEqual(keccak256(self.capture_raw), CAPTURE_HASH)
        transport = ReplayTransport(self.transcript, TRANSCRIPT_HASH)
        adapter = IndependentSourceAdapter(self.anchor_raw, transport, provenance="trusted_rpc")
        self.assertEqual(adapter.snapshot(), self.capture_raw)
        self.assertEqual(adapter.snapshot(), self.capture_raw)
        self.assertEqual(len(adapter.reader.rows), 85)
        self.assertEqual([r["count"] for r in self.capture["lanes"]], ["1", "5", "0"])
        self.assertEqual(self.capture["environment"], "local_evm_fixture")
        self.assertFalse(self.capture["claims"]["cryptographicStateProof"])
        self.assertFalse(self.capture["claims"]["publicDeploymentAcceptance"])
        self.assertFalse(self.capture["claims"]["semanticPayloadValidation"])
        evidence = loads(read_fixture("deployment-evidence.json"), maximum=1048576)
        self.assertEqual(keccak256(read_fixture("deployment-evidence.json")), self.anchor["deploymentEvidenceHash"])
        self.assertEqual(evidence["boundaries"], ["IndependentCoreBoundary", "IndependentExecutorBoundary", "IndependentSignatureBoundary"])
        self.assertEqual(evidence["hostGovernanceAuthority"], "0x" + "00" * 20)
        self.assertEqual({r["record"][5] for r in self.capture["records"]},
                         {schema_id(s) for s in ("DIRECT", "EIP712", "ERC1271")})

    def testExactSourceBytesWideNonceAndAttestorIsolation(self):
        records = self.capture["records"]
        payload = loads(hex_bytes(records[0]["payloadHex"]))
        self.assertEqual(payload["exactUint256"], "115792089237316195423570985008687907853269984665640564039457584007913129639935")
        self.assertEqual(payload["exactText"], "A\r\n& < > \U0001f9ed")
        self.assertIsNone(payload["language"])
        shared = [r for r in records if r["receipt"][7] == "0"]
        self.assertEqual(len(shared), 2)
        self.assertEqual(len({r["receipt"][1] for r in shared}), 2)
        self.assertIn(payload["exactUint256"], [r["receipt"][7] for r in records])
        self.assertEqual({r["subject"][0] for r in records}, {"0", "1", "2"})
        self.assertEqual([r["subjectMembership"] for r in records if r["subject"][0] == "2"], ["declared_media_reference"])

    def testRetiredSchemaChunksAndHistoricalAuthorityWithoutCurrentCalls(self):
        document = next(d for d in self.capture["documents"] if d["view"][3][1] == "0")
        self.assertEqual(document["view"][1], "2")
        self.assertEqual(len(document["view"][4]), 2)
        self.assertGreater(len(hex_bytes(document["payloadHex"])), 8192)
        targets = {r["params"][0]["to"] for r in self.rows if r["method"] == "eth_call"}
        self.assertEqual(targets, {self.anchor["host"], self.anchor["schemas"], self.anchor["store"]})
        forbidden = {calldata(s)[:10] for s in ("isValidSignature(bytes32,bytes)", "currentAction()", "documentBytes(bytes32)")}
        self.assertFalse(any(r["params"][0]["data"][:10] in forbidden for r in self.rows if r["method"] == "eth_call"))

    def testSyntheticTransportCannotRelabelItselfAsRecordedState(self):
        with self.assertRaisesRegex(MuseumError, "synthetic transport"):
            IndependentSourceAdapter(self.anchor_raw, FixtureTransport(self.rows), provenance="trusted_rpc")
        adapter = self.adapter()
        result = loads(adapter.snapshot(), maximum=1048576)
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertEqual(result["evidence"], "synthetic_fixture")
        self.assertEqual(result["records"], self.capture["records"])

    def testAllCallsUseExactCanonicalBlockAndExternalTranscriptAnchor(self):
        for row in self.rows:
            if row["method"] in ("eth_call", "eth_getCode"):
                self.assertEqual(row["params"][-1], {"blockHash": self.anchor["blockHash"], "requireCanonical": True})
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            ReplayTransport(self.transcript + b" ", TRANSCRIPT_HASH)
        changed = copy.deepcopy(self.rows)
        changed[2]["params"][-1] = "latest"
        raw = dumps({"version": 1, "calls": changed})
        adapter = IndependentSourceAdapter(self.anchor_raw, ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "call/block/order"):
            adapter.snapshot()

    def testReplayRejectsOmittedDuplicateAndExtraResponseRows(self):
        for rows in (self.rows[:-1], [self.rows[0]] + self.rows, self.rows + [self.rows[-1]]):
            raw = dumps({"version": 1, "calls": rows})
            with self.subTest(rows=len(rows)), self.assertRaises(MuseumError):
                IndependentSourceAdapter(self.anchor_raw, ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc").snapshot()

    def testExactReplayRejectsBooleanVersionAndNumericCanonicalFlag(self):
        # Both hostile inputs carry their own correct external byte commitment;
        # the exact wire check, not the hash mismatch, must reject them.
        raw = dumps({"version": True, "calls": self.rows})
        with self.assertRaisesRegex(MuseumError, "wire version"):
            ReplayTransport(raw, keccak256(raw))
        rows = copy.deepcopy(self.rows)
        row = next(r for r in rows if r["method"] == "eth_getCode")
        row["params"][-1]["requireCanonical"] = 1
        raw = dumps({"version": 1, "calls": rows})
        adapter = IndependentSourceAdapter(self.anchor_raw, ReplayTransport(raw, keccak256(raw)), provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "call/block/order"):
            adapter.snapshot()
        exact = IndependentSourceAdapter(self.anchor_raw, ReplayTransport(self.transcript, TRANSCRIPT_HASH), provenance="trusted_rpc")
        self.assertEqual(exact.snapshot(), self.capture_raw)

    def testAnchorRejectsUnknownWidthsDuplicateLanesAndMissingPins(self):
        variants = []
        for field, value in (("chainId", str(1 << 256)), ("timestamp", str(1 << 64)), ("blockNumber", "01"), ("blockHash", ZERO)):
            a = copy.deepcopy(self.anchor); a[field] = value; variants.append(a)
        a = copy.deepcopy(self.anchor); a["lanes"].append(a["lanes"][0]); variants.append(a)
        a = copy.deepcopy(self.anchor); a["codePins"] = a["codePins"][1:]; variants.append(a)
        a = copy.deepcopy(self.anchor); a["codePins"].append(a["codePins"][0]); variants.append(a)
        for a in variants:
            with self.subTest(anchor=a), self.assertRaises(MuseumError):
                self.adapter(anchor=a)

    def testWrongChainBlockAndRuntimeIdentityReject(self):
        for field in ("chain", "block", "code"):
            rows = copy.deepcopy(self.rows)
            if field == "chain": rows[0]["result"] = "0x1"
            if field == "block": rows[1]["result"]["stateRoot"] = ZERO
            if field == "code": rows[2]["result"] = "0x00"
            with self.subTest(field=field), self.assertRaises(MuseumError):
                self.adapter(rows).snapshot()

    def testFailedCaptureCannotReusePartiallyValidatedCaches(self):
        rows = copy.deepcopy(self.rows); rows[0]["result"] = "0x1"
        adapter = self.adapter(rows)
        with self.assertRaises(MuseumError): adapter.snapshot()
        rows[0]["result"] = "0x7a69"
        with self.assertRaisesRegex(MuseumError, "partial reader state"): adapter.snapshot()

    def testDeclaredLaneCountOmissionAndDuplicateRecordReject(self):
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "recordChainHash(uint256,bytes32)", 1)
        head, count = decode(("bytes32", "uint64"), hex_bytes(row["result"]))
        row["result"] = "0x" + encode(("bytes32", "uint64"), (head, count - 1)).hex()
        with self.assertRaisesRegex(MuseumError, "final chain/count"): self.adapter(rows).snapshot()
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "recordHashAt(uint256,bytes32,uint256)", 2)
        row["result"] = self.response(rows, "recordHashAt(uint256,bytes32,uint256)", 1)["result"]
        with self.assertRaisesRegex(MuseumError, "duplicate/missing"): self.adapter(rows).snapshot()

    def testLatestIsPerAttestorAndNeverGlobalSubjectReplacement(self):
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "latestCollectionRecordHashFor(uint256,bytes32,bytes32,address)", 1)
        row["result"] = ZERO
        with self.assertRaisesRegex(MuseumError, "attestor scoped latest"): self.adapter(rows).snapshot()

    def testAllSstoreChunksRequireStopLengthHashAndExactPointer(self):
        payload_pointer = self.capture["records"][0]["pointers"][0]
        for mode in ("prefix", "short", "content"):
            rows = copy.deepcopy(self.rows)
            row = next(r for r in rows if r["method"] == "eth_getCode" and r["params"][0] == payload_pointer)
            code = bytearray(hex_bytes(row["result"]))
            if mode == "prefix": code[0] = 1
            if mode == "short": code.pop()
            if mode == "content": code[-1] ^= 1
            row["result"] = "0x" + code.hex()
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "SSTORE2"):
                self.adapter(rows).snapshot()
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "recordPayload(bytes32)")
        pointer, payload = decode(("address", "bytes"), hex_bytes(row["result"]))
        row["result"] = "0x" + encode(("address", "bytes"), (self.anchor["host"], payload)).hex()
        with self.assertRaisesRegex(MuseumError, "host/store pointer"): self.adapter(rows).snapshot()

    def testArchivedDocumentCannotChangeDefinitionOrOrderedChunkList(self):
        for mode in ("status", "hash", "chunks", "exists", "declaration"):
            rows = copy.deepcopy(self.rows)
            row = self.response(rows, "document(bytes32)")
            d, = decode((DOCUMENT,), hex_bytes(row["result"]))
            d = list(d); spec = list(d[3]); d[3] = spec
            if mode == "status": d[1] = 3
            if mode == "hash": spec[2] = ZERO
            if mode == "chunks": d[4] = tuple(reversed(d[4]))
            if mode == "exists": d[0] = False
            if mode == "declaration": d[2] = ZERO
            row["result"] = "0x" + encode((DOCUMENT,), (d,)).hex()
            with self.subTest(mode=mode), self.assertRaises(MuseumError): self.adapter(rows).snapshot()

    def testRawRecordRejectsNoncanonicalAuthorityAndUnknownSubject(self):
        for signature, kinds, index, replacement in (("collectionRecord(bytes32)", (RECORD, RECEIPT), 2, 4),
                                                     ("recordSubject(bytes32)", (SUBJECT,), 0, 3)):
            rows = copy.deepcopy(self.rows); row = self.response(rows, signature)
            values = list(decode(kinds, hex_bytes(row["result"])))
            target = list(values[-1]); target[index] = replacement; values[-1] = target
            row["result"] = "0x" + encode(kinds, values).hex()
            with self.subTest(signature=signature), self.assertRaises(MuseumError): self.adapter(rows).snapshot()

    def testFourteenGenericWordsHaveIndependentLiteralEncoding(self):
        row = self.response(self.rows, "collectionRecord(bytes32)")
        record, receipt = decode((RECORD, RECEIPT), hex_bytes(row["result"]))
        def word(value): return value.to_bytes(32, "big")
        def address(value): return bytes(12) + bytes.fromhex(value[2:])
        def ref(value):
            return hex_bytes(keccak256(word(value[0]) + hex_bytes(keccak256(value[1])) + hex_bytes(value[2])))
        expected = keccak256(hex_bytes(keccak256(b"6529stream.preservation-record.v2"))
            + word(31337) + address(self.anchor["host"]) + address(self.anchor["core"])
            + address(receipt[1]) + word(receipt[0]) + hex_bytes(record[0]) + hex_bytes(record[1])
            + ref(record[2]) + hex_bytes(keccak256(record[3].encode())) + hex_bytes(record[4])
            + hex_bytes(record[5]) + ref(record[6]) + word(record[7]))
        self.assertEqual(expected, self.capture["records"][0]["recordHash"])
        self.assertEqual(expected, generic_hash(31337, self.anchor["host"], self.anchor["core"], receipt[0], receipt[1], record))

    def testEverySignedWordAndDomainRejectAfterValidOuterHashRebinding(self):
        record, receipt = decode((RECORD, RECEIPT), hex_bytes(self.response(self.rows, "collectionRecord(bytes32)")["result"]))
        subject_raw = hex_bytes(self.response(self.rows, "recordSubject(bytes32)")["result"])
        original = self.capture["records"][0]
        payload, bundle = hex_bytes(original["payloadHex"]), hex_bytes(original["signatureBundleHex"])
        d, words, signature = decode(("bytes32", ("bytes32",) * 14, "bytes"), bundle)
        literal_type = (b"StreamIndependentPreservationRecord(address attestor,uint256 scopeKey,bytes32 subjectId,"
                        b"bytes32 recordType,bytes32 schemaId,uint16 algorithmId,bytes digest,bytes32 canonicalizationId,"
                        b"string uri,bytes payload,uint64 effectiveAt,uint256 nonce,uint64 deadline)")
        self.assertEqual(words[0], keccak256(literal_type))
        self.assertEqual(d, domain(31337, self.anchor["host"]))
        for i in range(15):
            bad_words = list(words); bad_domain = d
            if i == 14: bad_domain = ZERO
            else: bad_words[i] = "0x" + (int(words[i], 16) ^ 1).to_bytes(32, "big").hex()
            bad_bundle = encode(("bytes32", ("bytes32",) * 14, "bytes"), (bad_domain, bad_words, signature))
            changed_record = list(record)
            changed_record[6] = (1, hex_bytes(keccak256(bad_bundle)), schema_id("RAW_BYTES"))
            h = generic_hash(31337, self.anchor["host"], self.anchor["core"], receipt[0], receipt[1], changed_record)
            changed_receipt = list(receipt)
            changed_receipt[5] = record_chain("31337", self.anchor["host"], str(receipt[0]), record[0], ZERO, h, "0")
            with self.subTest(word=i), self.assertRaisesRegex(MuseumError, "full signed tuple/domain"):
                verify_record(31337, self.anchor["host"], self.anchor["core"], int(self.anchor["timestamp"]),
                    (receipt[0], record[0]), 0, ZERO, h, encode((RECORD, RECEIPT), (changed_record, changed_receipt)),
                    subject_raw, payload, bad_bundle)

    def testOfflineCliEmitsExactTrustedLocalCaptureWithoutNetwork(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "capture"
            run = subprocess.run([sys.executable, "-m", "tools.museum.independent_source",
                "--anchor", str(FIXTURE / "anchor.json"), "--transcript", str(FIXTURE / "transcript.json"),
                "--transcript-hash", TRANSCRIPT_HASH, "--output", str(output)],
                cwd=FIXTURE.parents[3], capture_output=True, timeout=30)
            self.assertEqual(run.returncode, 0, run.stderr.decode())
            self.assertEqual((output / "source-capture.json").read_bytes(), self.capture_raw)
            self.assertEqual((output / "transcript.json").read_bytes(), self.transcript)
            self.assertEqual(loads(run.stdout)["captureHash"], CAPTURE_HASH)

    def testOversizedRecordInventoryAndBundleFailBeforeUnboundedReads(self):
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "recordChainHash(uint256,bytes32)")
        row["result"] = "0x" + encode(("bytes32", "uint64"), (ZERO, 4097)).hex()
        with self.assertRaisesRegex(MuseumError, "inventory bound"): self.adapter(rows).snapshot()
        rows = copy.deepcopy(self.rows)
        row = self.response(rows, "recordSignatureBundle(bytes32)")
        pointer, _ = decode(("address", "bytes"), hex_bytes(row["result"]))
        row["result"] = "0x" + encode(("address", "bytes"), (pointer, bytes(8193))).hex()
        with self.assertRaisesRegex(MuseumError, "payload bound"): self.adapter(rows).snapshot()


class ChainAbiTest(unittest.TestCase):
    def testLiteralAbiExampleAndStrictScalarWidths(self):
        self.assertEqual(calldata("baz(uint32,bool)", ("uint32", "bool"), (69, True)),
                         "0xcdcd77c0" + "00" * 31 + "45" + "00" * 31 + "01")
        for kind, value in (("uint8", 256), ("uint64", 1 << 64), ("uint256", 1 << 256), ("uint256", True)):
            with self.subTest(kind=kind), self.assertRaises(MuseumError): encode((kind,), (value,))
        with self.assertRaises(MuseumError): decode(("bool",), (2).to_bytes(32, "big"))
        with self.assertRaises(MuseumError): decode(("address",), b"\1" + bytes(31))

    def testOffsetsPaddingUtf8AndTrailingBytesAreNotSilentlyAccepted(self):
        valid = encode(("bytes", "string"), (b"x", "astral \U0001f9ed"))
        bad = []
        b = bytearray(valid); b[31] = 0; bad.append(bytes(b))
        b = bytearray(valid); b[63] = 64; bad.append(bytes(b))
        b = bytearray(valid); b[127] = 1; bad.append(bytes(b))
        bad.extend((valid + bytes(32), valid[:-1]))
        b = bytearray(encode(("string",), ("x",))); b[64] = 0xff
        with self.assertRaises(MuseumError): decode(("string",), bytes(b))
        for data in bad:
            with self.subTest(data=data.hex()), self.assertRaises(MuseumError): decode(("bytes", "string"), data)
        self.assertEqual(decode(("bytes", "string"), valid), (b"x", "astral \U0001f9ed"))

    def testArrayCountAndResponseBoundsAreCheckedBeforeExpansion(self):
        huge = (32).to_bytes(32, "big") + (1 << 255).to_bytes(32, "big")
        with self.assertRaisesRegex(MuseumError, "array bound"): decode((Array("bytes32"),), huge)
        with self.assertRaisesRegex(MuseumError, "bound/alignment"): decode(("bytes",), bytes(32800))
        for value in ("0x00", "0X1", "0x", "0x01", "0xg", "0x" + "f" * 65):
            with self.subTest(value=value), self.assertRaises(MuseumError): quantity(value)
        self.assertEqual(quantity("0x0"), 0)
        self.assertEqual(quantity("0x" + "f" * 64), (1 << 256) - 1)

    def testReadTransportRefusesWritesBeforeNetwork(self):
        transport = RpcTransport("http://127.0.0.1:1")
        with self.assertRaisesRegex(MuseumError, "read-only"):
            transport.request("eth_sendTransaction", [])
        with self.assertRaisesRegex(MuseumError, "HTTPS"):
            RpcTransport("http://example.invalid")

    def testNestedDocumentOffsetsAndPaddingAreCanonical(self):
        rows = loads(read_fixture("transcript.json"), maximum=1048576)["calls"]
        row = next(r for r in rows if r["method"] == "eth_call"
                   and r["params"][0]["data"].startswith(calldata("document(bytes32)")[:10]))
        raw = hex_bytes(row["result"])
        d, = decode((DOCUMENT,), raw)
        self.assertEqual(d[3][0], "LOCAL_INDEPENDENT_CAPTURE_SCHEMA_V1")
        number = lambda at: int.from_bytes(raw[at:at + 32], "big")
        doc = number(0)
        spec = doc + number(doc + 96)
        name = spec + number(spec)
        length = number(name)
        self.assertNotEqual(length % 32, 0)
        bad_padding = bytearray(raw); bad_padding[name + 32 + length] = 1
        alias = bytearray(raw); alias[spec + 160:spec + 192] = raw[spec:spec + 32]
        for changed in (bytes(bad_padding), bytes(alias), raw + bytes(32)):
            with self.subTest(changed=changed.hex()), self.assertRaises(MuseumError): decode((DOCUMENT,), changed)

    def testEndpointErrorsAreSanitizedAndRedirectDoesNotReachSecondPath(self):
        marker = "INERT_FIXTURE_CREDENTIAL_MARKER"
        with patch("urllib.request.Request", side_effect=ValueError(marker)):
            with self.assertRaises(MuseumError) as failure:
                RpcTransport("http://127.0.0.1/?key=" + marker).request("eth_chainId", [])
            self.assertNotIn(marker, str(failure.exception))
        paths = []
        class Handler(BaseHTTPRequestHandler):
            def do_POST(self):
                paths.append(self.path)
                self.send_response(302)
                self.send_header("Location", "/forbidden-redirect-target")
                self.end_headers()
            def do_GET(self):
                paths.append(self.path)
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'{"jsonrpc":"2.0","id":1,"result":"0x7a69"}')
            def log_message(self, *args):
                pass
        server = HTTPServer(("127.0.0.1", 0), Handler)
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            with self.assertRaises(MuseumError):
                RpcTransport("http://127.0.0.1:" + str(server.server_port) + "/original").request("eth_chainId", [])
            self.assertEqual(paths, ["/original"])
        finally:
            server.shutdown()
            server.server_close()
            worker.join(timeout=5)

    def testLocalReceiptPollingDoesNotResendOrConfusePendingWithRevert(self):
        fixture = LocalFixture.__new__(LocalFixture)
        fixture.account = "0x" + "11" * 20
        fixture.receipts = []
        calls = []
        receipt = {"status": "0x1", "transactionHash": "0x" + "22" * 32}
        responses = iter([receipt["transactionHash"], None, None, receipt])
        def rpc(method, params):
            calls.append((method, params))
            return next(responses)
        fixture.rpc = rpc
        with patch("tools.museum.local_independent_fixture.time.sleep"):
            self.assertEqual(fixture.send("0x00"), receipt)
        self.assertEqual([c[0] for c in calls], ["eth_sendTransaction"] + ["eth_getTransactionReceipt"] * 3)
        self.assertEqual(len(fixture.receipts), 1)
        self.assertTrue(all(c[1] == [receipt["transactionHash"]] for c in calls[1:]))
        responses = iter([receipt["transactionHash"], {"status": "0x0"}])
        with self.assertRaisesRegex(MuseumError, "transaction reverted"): fixture.send("0x00")
        self.assertEqual(fixture.receipts[-1]["receipt"]["status"], "0x0")


if __name__ == "__main__":
    unittest.main()
