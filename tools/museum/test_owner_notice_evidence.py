"""Synthetic native notice/companion RPC mechanics, never actual-chain acceptance."""
from copy import deepcopy
from pathlib import Path
import re
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, uint
from .chain_abi import encode
from .chain_rpc import ReplayTransport, RpcTransport
from . import owner_catalog_source as catalog
from . import owner_notice_evidence as notice
from .test_owner_catalog_source import A, H, Fixture as CatalogueFixture, Transport, record_pair


class Fixture(CatalogueFixture):
    """Full real reader path over synthetic headers, receipts and ABI calls."""

    def __init__(self, *, executed=False, status=None, unopened=False, pending=True, processed=2, steward=True):
        super().__init__(empty=True)
        self.rows = []; self.action = H("native-notice-action"); self.manifest = H("recovery-manifest")
        self.target, self.executor = A(6), A(5)
        for height, stamp in ((3, 103), (4, 259303), (5, 259304)):
            self.blocks[height] = {"hash": H("block" + str(height)), "number": hex(height),
                "parentHash": self.blocks[height - 1]["hash"], "timestamp": hex(stamp),
                "stateRoot": H("state" + str(height)), "transactions": []}
        self.anchor.update(blockHash=self.blocks[5]["hash"], blockNumber="5", timestamp="259304", stateRoot=self.blocks[5]["stateRoot"])
        # Rebind the base fixture's complete catalogue calls to this one source block.
        existing = list(self.responses.items()); self.responses.clear()
        for key, value in existing:
            method, params = loads(key)
            if method in ("eth_call", "eth_getCode"):
                params[-1] = self.block_ref
            self.put(method, params, value)
        for address in (self.executor, self.target):
            runtime = b"\x60" + hex_bytes(address)[-1:]
            self.anchor["codePins"].append({"address": address, "runtimeHash": keccak256(runtime)})
            self.put("eth_getCode", [address, self.block_ref], "0x" + runtime.hex())
        self.call("governanceAuthority()", ("address",), (self.executor,))
        self.call("executorCodeHash()", ("bytes32",), (keccak256(b"\x60\x05"),))
        self.call("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            (True, 9, 71, False), ("uint256",), (71,), target=A(2))
        for getter, value in (("core", A(2)), ("governanceAuthority", self.executor), ("ownerEvidence", A(1))):
            self.call(getter + "()", ("address",), (value,), target=self.target)
        self.reference = (4, H("opaque-canonicalization"), b"opaque-claim-commitment", "ipfs://claimed-publication")
        self.steward = self.add_record(2, notice.STEWARD_TYPE, dumps({"contactEndpoints": [{"kind": "https", "uri": "https://museum.example/notice"}],
            "predecessor": None, "profileHash": H("steward-profile"), "steward": {"identity": {
                "hash": {"algorithm": 4, "canonicalizationId": self.reference[1], "digest": "0x" + self.reference[2].hex()},
                "uri": self.reference[3]}, "kind": "institution", "name": "Claimed museum"},
            "subjectId": self.subject, "version": 1})) if steward else None
        self.first = self.add_response(2, "acknowledged")
        self.second = None
        self.last = None
        self.scope = (1, 9, 71, notice.ZERO)
        component = (H("route-type"), A(7), "0x01020304", H("route-code"), H("route-version"), H("route-manifest"), H("route-data"))
        manifest = ("ipfs://manifest", keccak256(b"ipfs://manifest"), self.manifest, H("manifest-schema"), H("manifest-canon"))
        self.request = (self.scope, H("original-finality"), notice.ZERO, H("old-route"), component, manifest, H("reason"), "ipfs://reason")
        self.binding = (self.target, keccak256(b"\x60\x06"), notice._hash(("bytes32", "uint256", "address", notice.SCOPE),
            (schema_id("6529STREAM_FINALITY_RECOVERY_SCOPE_V1"), 31337, self.target, self.scope)),
            notice._hash(("bytes32", "bytes32", "bytes32", "bytes32", "uint64", "bytes32"),
                (schema_id("6529STREAM_FINALITY_RECOVERY_OLD_STATE_V1"), notice._hash(notice.SCOPE, self.scope), self.request[1], notice.ZERO, 0, self.request[3])),
            notice._hash(("bytes32", "uint256", "address", "uint64", notice.REQUEST),
                (schema_id("6529STREAM_FINALITY_RECOVERY_NEW_STATE_V1"), 31337, self.target, 1, self.request)),
            notice._hash((notice.REQUEST,), (self.request,)), self.manifest, H("complete-ordered-governance-call-hash"), 400000, self.request[1])
        self.snapshot = [self.binding, self.scope, A(10), A(8), self.steward[0] if steward else notice.ZERO,
            keccak256(self.steward[1][5]) if steward else notice.ZERO,
            notice.ZERO, 103, 259303, 1, 2 if steward else 1, notice.ZERO, 1, 1, 0, 0, 0]
        if not unopened:
            raw = encode((notice.REFERENCE, notice.REFERENCE), (self.reference, self.reference))
            self.claim(0, raw); publication = keccak256(raw)
            endpoints = [(2, "", 31337, A(8))]
            if steward:
                endpoints.append((0, "https://museum.example/notice", 0, notice.ZERO_ADDRESS))
            for index, endpoint in enumerate(endpoints):
                raw = encode((notice.DELIVERY,), ((endpoint, self.reference),))
                self.claim(index + 1, raw)
                publication = notice._hash(("bytes32", "uint256", "bytes32"), (publication, index, keccak256(raw)))
            self.snapshot[6] = publication
            self.snapshot[11] = notice.opening_hash(31337, A(1), A(2), self.action, self.snapshot, 1)
            self.open_log = self.log(3, A(1), [notice.OPENED, self.action, self.topic("uint256", 71), self.topic("address", A(8))],
                encode(("address", "bytes32", "bytes32", "uint64", "uint64", "bytes32", "uint16"),
                    (A(10), self.snapshot[4], publication, 103, 259303, self.snapshot[11], 1)))
            self.second = self.add_response(4, "objected", queued=True, late=True)
            self.snapshot[13] = 2
            previous = notice.ZERO
            self.processing_logs = []
            for count, row in enumerate([self.first, self.second][:processed], 1):
                response = self.response_values(row, queued=True, processed=True)
                ack, obj = (1, 0) if count == 1 else (0, 1)
                self.snapshot[11] = notice.update_hash(self.snapshot[11], self.action, row[0], previous, response, count, ack, obj)
                self.processing_logs.append(self.log(4, A(1), [notice.PROCESSED, self.action, self.topic("address", A(8)), row[0]],
                    encode(("bytes32", "uint64", "uint32", "uint32", "bytes32", "uint16"),
                        (previous, count + 1, ack, obj, self.snapshot[11], 1))))
                previous = row[0]
                self.snapshot[12:17] = [count + 1, 2, count, ack, obj]
            self.call("governanceActionFacts(bytes32)", (notice.FACTS,),
                ((status if status is not None else 3 if executed else 1, 2, self.binding[7], 103, self.binding[8]),),
                ("bytes32",), (self.action,), target=self.executor)
            self.recovery = notice._empty(notice.RECOVERY)
            if executed:
                self.execute()
            self.call("finalityRecoveryRecord(bytes32)", (notice.RECOVERY,), (self.recovery,), ("bytes32",), (self.action,), target=self.target)
            if pending:
                self.last = self.add_response(5, "acknowledged", owner=A(9), queued=True, late=True)
                self.snapshot[13] += 1
            self.call("recoveryNotice(bytes32)", (notice.NOTICE,), (tuple(self.snapshot),), ("bytes32",), (self.action,))
            queue = [self.first, self.second] + ([self.last] if self.last else [])
            for index, row in enumerate(queue):
                self.call("recoveryResponseAt(bytes32,uint256)", ("bytes32",), (row[0],), ("bytes32", "uint256"), (self.action, index))
                self.response_read(row, queued=True, processed=index < processed)
            self.call("latestCountedRecoveryResponse(bytes32,address)", ("bytes32",),
                (queue[processed - 1][0] if processed else notice.ZERO,), ("bytes32", "address"), (self.action, A(8)))
            if self.last:
                self.call("latestCountedRecoveryResponse(bytes32,address)", ("bytes32",), (notice.ZERO,),
                    ("bytes32", "address"), (self.action, A(9)))
        self.finish_catalogue()

    @property
    def block_ref(self):
        return {"blockHash": self.anchor["blockHash"], "requireCanonical": True}

    @property
    def subject(self):
        return catalog.subject_id("token", "31337", A(2), "0", token_id="71")

    @staticmethod
    def topic(kind, value):
        return "0x" + encode((kind,), (value,)).hex()

    def add_record(self, block, family, payload, owner=A(8)):
        lane = [row for row in self.rows if row[1][0] == family]
        row = list(record_pair(record_type=family, payload=payload, owner=owner, index=len(lane),
            previous=lane[-1][2][4] if lane else notice.ZERO))
        receipt = list(row[2]); receipt[2] = int(self.blocks[block]["timestamp"], 16); row[2] = tuple(receipt)
        row = tuple(row); self.rows.append(row)
        digest, record, receipt, bundle = row; pointer = A(30 + len(self.rows))
        self.call("ownerRecord(bytes32)", (catalog.OWNER_RECORD, catalog.RECEIPT), (record, receipt), ("bytes32",), (digest,))
        self.call("ownerRecordSignatureBundle(bytes32)", ("address", "bytes"), (pointer, bundle), ("bytes32",), (digest,))
        self.put("eth_getCode", [pointer, self.block_ref], "0x00" + bundle.hex())
        self.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",), (digest,),
            ("uint256", "bytes32", "uint256"), (71, family, receipt[3]))
        self.log(block, A(1), [catalog.RECORD_EVENT, self.topic("uint256", 71), family, self.topic("address", owner)],
            encode((catalog.OWNER_RECORD, "bytes32", "bytes32", "bool", "uint16"), (record, digest, receipt[4], False, 1)))
        return row

    def add_response(self, block, response, *, owner=A(8), queued=False, late=False, action=None, manifest=None):
        action, manifest = action or self.action, manifest or self.manifest
        row = self.add_record(block, notice.RESPONSE_TYPE, dumps({"evidenceReferences": [], "grounds": "Original owner statement",
            "profileHash": H("response-profile"), "recoveryId": action, "recoveryManifestHash": manifest,
            "response": response, "subjectId": self.subject, "version": 1}), owner)
        self.log(block, A(1), [notice.RECORDED, action, self.topic("address", owner), row[0]],
            encode(("uint256", "bool", "bool", "uint16"), (71, queued, late, 1)))
        self.response_read(row, queued=queued, processed=False)
        return row

    def response_values(self, row, *, queued=False, processed=False):
        body = loads(row[1][5]); receipt = row[2]
        return (71, receipt[1], body["recoveryId"], body["recoveryManifestHash"], receipt[2], receipt[3],
            0 if body["response"] == "acknowledged" else 1, queued, processed, queued and receipt[2] >= 259303)

    def response_read(self, row, **kwargs):
        self.call("recoveryResponse(bytes32)", (notice.RESPONSE,), (self.response_values(row, **kwargs),), ("bytes32",), (row[0],))

    def claim(self, index, raw):
        pointer = A(100 + index)
        self.call("recoveryNoticeClaim(bytes32,uint256)", ("address", "bytes"), (pointer, raw),
            ("bytes32", "uint256"), (self.action, index))
        self.put("eth_getCode", [pointer, self.block_ref], "0x00" + raw.hex())

    def finish_catalogue(self):
        for family in (*catalog.FIXED, self.custom):
            rows = [row for row in self.rows if row[1][0] == family]
            self.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (rows[-1][2][4] if rows else notice.ZERO, len(rows)), ("uint256", "bytes32"), (71, family))
            for owner, digest in {row[2][1]: row[0] for row in rows}.items():
                self.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",), (digest,),
                    ("uint256", "bytes32", "address"), (71, family, owner))
        for block in self.blocks.values():
            self.put("eth_getBlockByHash", [block["hash"], False], block)

    def execute(self):
        evidence = (1, H("artist-evidence"), A(11), H("artist-id"), 1, 259303,
            self.snapshot[11], self.snapshot[12], 259303, self.snapshot[15], self.snapshot[16])
        route = keccak256(encode(("bytes32", "uint256", "address", "bytes32", "bytes32", "bytes32", "uint64"),
            (schema_id("6529STREAM_SCOPED_FINALITY_RECOVERY_V1"), 31337, self.target, self.action, self.request[1], notice.ZERO, 1))
            + encode((notice.SCOPE, notice.COMPONENT, "bytes32", notice.EXECUTION_EVIDENCE, "bytes32"),
                (self.scope, self.request[4], self.manifest, evidence, self.request[6])))
        self.recovery = (True, self.action, self.scope, self.request[1], notice.ZERO, 1, self.request[3], route,
            True, self.request[4], self.request[5], evidence, self.request[6], self.request[7], 259303)
        self.lineage_log = self.log(4, self.target, [notice.LINEAGE, self.action, notice.ZERO, self.request[1]],
            encode(("uint16", "uint64", "bytes32", "bytes32"), (1, 1, self.request[3], route)))
        self.evidence_log = self.log(4, self.target, [notice.EVIDENCE, self.action], encode(("uint16", notice.EXECUTION_EVIDENCE), (1, evidence)))
        self.execution_log = self.log(4, self.target, [notice.EXECUTED, self.topic("uint8", 1), self.topic("uint256", 9), self.action],
            encode(("uint16", "uint256", "bytes32", "bytes32", "bytes32", "bool", "bytes32", "string"),
                (1, 71, notice.ZERO, self.manifest, route, True, self.request[6], self.request[7])))

    def evidence_source(self, **kwargs):
        return notice.OwnerNoticeEvidenceSource(self.source(), Transport(self.responses), **kwargs)

    def capture(self):
        source = self.evidence_source()
        return source, loads(source.snapshot(), maximum=notice.MAX_SNAPSHOT)


class NoticeEvidenceTests(unittest.TestCase):
    def test_complete_publication_and_pending_originals_are_separate_from_receipt(self):
        source, result = Fixture().capture()
        action = result["actions"][0]
        self.assertEqual(action["governanceAction"]["status"], "SCHEDULED")
        self.assertEqual(action["processed"], "2")
        self.assertEqual(len(action["pending"]), 1)
        self.assertEqual(len(result["originals"]), 4)
        self.assertEqual(action["claims"][1]["attribution"], "publisher_delivery_claim")
        self.assertEqual(action["claims"][1]["wire"][1][0], "4")
        for key in ("recipientReceiptProven", "institutionalAssentProven", "offchainDeliveryProven", "actualChainAcceptance"):
            self.assertFalse(result["claims"][key])
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertIs(source.snapshot(), source.snapshot())

    def test_exact_execution_joins_old_evidence_while_later_response_stays_pending(self):
        _, result = Fixture(executed=True).capture()
        action = result["actions"][0]
        self.assertEqual(action["execution"]["state"], "executed_native_receipt")
        self.assertEqual(action["execution"]["consumedOwnerEvidenceRevision"], "3")
        self.assertEqual(len(action["execution"]["events"]), 3)
        self.assertEqual(len(action["pending"]), 1)
        self.assertEqual(action["completeOrderedActionWitness"], "not_captured")

    def test_cancellation_and_governance_execution_do_not_invent_companion_execution(self):
        for status in (2, 3, 4, 5):
            with self.subTest(status=status):
                _, result = Fixture(status=status).capture()
                action = result["actions"][0]
                self.assertEqual(action["governanceAction"]["status"], notice.STATUSES[status])
                self.assertEqual(action["execution"]["state"], "observed_not_executed")

    def test_unopened_original_response_and_untyped_generic_payload_are_preserved(self):
        f = Fixture(unopened=True)
        extra = f.add_record(5, notice.RESPONSE_TYPE, b"generic arbitrary original")
        f.finish_catalogue()
        _, result = f.capture()
        self.assertEqual(result["actions"][0]["state"], "no_token_notice_in_complete_history")
        self.assertEqual(result["actions"][0]["execution"]["state"], "not_captured")
        self.assertEqual(result["unlinkedOriginalResponseHashes"], [extra[0]])

    def test_zero_processed_and_no_steward_are_complete_supported_cases(self):
        _, result = Fixture(processed=0, steward=False).capture()
        action = result["actions"][0]
        self.assertEqual(action["processed"], "0")
        self.assertEqual(len(action["pending"]), 3)
        self.assertEqual(len(action["claims"]), 2)

    def test_missing_explicit_companion_or_executor_pin_is_not_inferred(self):
        for address in (A(5), A(6)):
            f = Fixture(); f.anchor["codePins"] = [r for r in f.anchor["codePins"] if r["address"] != address]
            with self.subTest(address=address), self.assertRaisesRegex(MuseumError, "explicit dependency pin"):
                f.capture()

    def test_immutable_claim_hash_bytes_endpoint_and_carrier_controls(self):
        for change in ("code", "endpoint", "digest", "extra-padding"):
            f = Fixture(); endpoint = (2, "", 31337, A(8)); reference = f.reference
            if change == "code":
                f.put("eth_getCode", [A(101), f.block_ref], "0x0001")
            else:
                if change == "endpoint": endpoint = (2, "", 31337, A(9))
                if change == "digest": reference = (4, reference[1], b"changed", reference[3])
                raw = encode((notice.DELIVERY,), ((endpoint, reference),))
                if change == "extra-padding": raw += bytes(32)
                f.claim(1, raw)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.capture()

    def test_opening_event_clock_and_hash_mismatch_fail(self):
        for index, replacement in ((7, 104), (8, 259304), (9, 0), (11, H("false-evidence")), (13, 2)):
            f = Fixture(); values = list(f.snapshot); values[index] = replacement
            f.call("recoveryNotice(bytes32)", (notice.NOTICE,), (tuple(values),), ("bytes32",), (f.action,))
            with self.subTest(index=index), self.assertRaises(MuseumError):
                f.capture()

    def test_complete_queue_and_processed_event_correspondence(self):
        for change in ("queue", "latest", "processed", "predecessor", "response-label"):
            f = Fixture()
            if change == "queue":
                f.call("recoveryResponseAt(bytes32,uint256)", ("bytes32",), (f.second[0],), ("bytes32", "uint256"), (f.action, 0))
            elif change == "latest":
                f.call("latestCountedRecoveryResponse(bytes32,address)", ("bytes32",), (f.first[0],), ("bytes32", "address"), (f.action, A(8)))
            elif change == "processed": f.processing_logs[0]["topics"][3] = f.last[0]
            elif change == "predecessor": f.processing_logs[0]["data"] = "0x" + encode(
                ("bytes32", "uint64", "uint32", "uint32", "bytes32", "uint16"), (f.last[0], 2, 1, 0, H("bad"), 1)).hex()
            else: f.response_read(f.first, queued=False, processed=True)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.capture()

    def test_execution_needs_exact_record_and_all_three_native_events(self):
        for change in ("missing", "manifest", "request", "scope", "evidence", "runtime", "authority", "pending-at-execution"):
            f = Fixture(executed=True)
            if change == "missing": f.evidence_log["topics"][0] = H("different-event")
            elif change == "runtime": f.put("eth_getCode", [f.target, f.block_ref], "0x6007")
            elif change == "authority": f.call("ownerEvidence()", ("address",), (A(99),), target=f.target)
            elif change == "pending-at-execution":
                f = Fixture(executed=True, processed=1)
            else:
                values = list(f.recovery)
                if change == "manifest": manifest = list(values[10]); manifest[2] = H("other"); values[10] = tuple(manifest)
                elif change == "request": values[13] = "ipfs://different-original-request"
                elif change == "scope": values[2] = (1, 9, 72, notice.ZERO)
                elif change == "evidence": evidence = list(values[11]); evidence[7] = 2; values[11] = tuple(evidence)
                f.call("finalityRecoveryRecord(bytes32)", (notice.RECOVERY,), (tuple(values),), ("bytes32",), (f.action,), target=f.target)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                f.capture()

    def test_offline_replay_is_exact_and_external_pins_are_required(self):
        f = Fixture(executed=True); source, _ = f.capture()
        owner = source.owner_catalog
        replay_owner = catalog.OwnerCatalogSource(owner.anchor_bytes, ReplayTransport(owner.transcript(), keccak256(owner.transcript())))
        replay = notice.OwnerNoticeEvidenceSource(replay_owner, ReplayTransport(source.transcript(), keccak256(source.transcript())))
        self.assertEqual(source.snapshot(), replay.snapshot())
        with self.assertRaisesRegex(MuseumError, "external commitment"):
            ReplayTransport(source.transcript(), H("wrong-pin"))
        altered = loads(source.transcript(), maximum=notice.MAX_TRANSCRIPT); altered["calls"].append(altered["calls"][-1])
        raw = dumps(altered)
        again = notice.OwnerNoticeEvidenceSource(owner, ReplayTransport(raw, keccak256(raw)))
        with self.assertRaisesRegex(MuseumError, "unconsumed"):
            again.snapshot()

    def test_standalone_join_rejects_contradictory_header_and_omitted_typed_receipt(self):
        for change in ("header", "receipt"):
            f = Fixture(unopened=True)
            owner = f.source(); owner.snapshot()
            if change == "header":
                f.blocks[1]["stateRoot"] = H("contradictory-past-state-root")
            else:
                # The omitted last event is not needed by OwnerCatalogSource's
                # generic lanes, but it must remain in the identical receipt.
                f.receipts[H("tx2")]["logs"].pop()
            source = notice.OwnerNoticeEvidenceSource(owner, Transport(f.responses))
            with self.subTest(change=change), self.assertRaisesRegex(MuseumError, "transcripts contradict"):
                source.snapshot()

    def test_different_manifest_original_is_retained_outside_opened_queue(self):
        f = Fixture()
        row = f.add_response(5, "objected", manifest=H("different-manifest"))
        f.finish_catalogue()
        _, result = f.capture()
        self.assertEqual(len(result["responses"]), 4)
        self.assertNotIn(row[0], result["actions"][0]["queue"])
        saved = next(r for r in result["responses"] if r["recordHash"] == row[0])
        self.assertEqual(saved["wire"][7:], [False, False, False])

    def test_empty_native_catalogue_authenticates_no_notice_events(self):
        f = CatalogueFixture(empty=True)
        source = notice.OwnerNoticeEvidenceSource(f.source(), Transport(f.responses))
        result = loads(source.snapshot(), maximum=notice.MAX_SNAPSHOT)
        self.assertEqual(result["actions"], [])
        self.assertEqual(result["responses"], [])

    def test_concrete_catalogue_provenance_bounds_and_failed_capture_cannot_resume(self):
        with self.assertRaisesRegex(MuseumError, "concrete"):
            notice.OwnerNoticeEvidenceSource({}, Transport({}))
        f = Fixture()
        with self.assertRaisesRegex(MuseumError, "provenance"):
            notice.OwnerNoticeEvidenceSource(f.source(), Transport(f.responses), provenance="trusted_rpc")
        source = f.evidence_source()
        with patch.object(notice, "MAX_DELIVERIES", 1), self.assertRaisesRegex(MuseumError, "endpoint count"):
            source.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"):
            source.snapshot()

    def test_trusted_rpc_mode_is_explicit_synthetic_mechanics_not_acceptance(self):
        f = Fixture()
        with patch.object(RpcTransport, "request", Transport(f.responses).request):
            owner = catalog.OwnerCatalogSource(dumps(f.anchor), RpcTransport("http://127.0.0.1:1"), provenance="trusted_rpc")
            source = notice.OwnerNoticeEvidenceSource(owner, RpcTransport("http://127.0.0.1:1"), provenance="trusted_rpc")
            result = loads(source.snapshot(), maximum=notice.MAX_SNAPSHOT)
        self.assertEqual(result["mode"], "caller_admitted_rpc_owner_notice_evidence")
        self.assertFalse(result["claims"]["actualChainAcceptance"])

    def test_native_tuple_and_hash_domain_source_parity(self):
        root = Path(__file__).resolve().parents[2]
        types = (root / "smart-contracts/interfaces/stream/metadata/StreamOwnerRecoveryNoticeTypes.sol").read_text(encoding="utf-8")
        body = re.search(r"struct Snapshot\s*\{(.*?)\}", types, re.S)[1]
        fields = re.findall(r"\b(\w+)\s*;", body)
        self.assertEqual(fields, ["binding", "scope", "publisher", "openingOwner", "stewardRecordHash", "stewardPayloadHash",
            "publicationHash", "openedAt", "noticeEndsAt", "firstResponseIndex", "deliveryCount", "evidenceHash", "revision",
            "responseTail", "processed", "acknowledgements", "objections"])
        state = (root / "smart-contracts/domains/records/StreamOwnerRecoveryNoticeState.sol").read_text(encoding="utf-8")
        self.assertIn('keccak256("6529STREAM_OWNER_RECOVERY_NOTICE_V1")', state)
        self.assertIn('keccak256("6529STREAM_OWNER_RECOVERY_RESPONSE_V1")', state)
        self.assertIn("block.timestamp + 72 hours", state)


if __name__ == "__main__":
    unittest.main()
