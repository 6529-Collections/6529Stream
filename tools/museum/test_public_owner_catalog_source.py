"""Synthetic public owner catalogue vectors; no RPC or actual-chain acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport
from .independent_wire import ZERO
from . import owner_catalog_source as original
from .public_owner_catalog_source import PublicOwnerCatalogSource, PROFILE, PROFILE_BYTES, PROFILE_HASH
from .public_history_rpc import PublicRpcTransport, PublicReplayTransport
from .test_owner_catalog_source import Fixture, Transport, A, H


class PublicOwnerCatalogFixture(Fixture):
    """Original owner-native wire responses plus sparse synthetic public history."""

    def __init__(self, *, source_block=120005, empty=False):
        super().__init__(empty=empty)
        self.a = self.anchor
        self.a.update(profile=PROFILE, environment="public_chain")
        if source_block != 2:
            assert source_block > 2
            old_hash = self.a["blockHash"]
            header = {"hash": H("public-block" + str(source_block)), "number": hex(source_block),
                "parentHash": H("public-parent" + str(source_block)), "timestamp": hex(100 + source_block),
                "stateRoot": H("public-state" + str(source_block)), "transactions": []}
            if source_block == 3: header["parentHash"] = self.blocks[2]["hash"]
            self.blocks[source_block] = header
            self.a.update(blockHash=header["hash"], blockNumber=str(source_block),
                timestamp=str(100 + source_block), stateRoot=header["stateRoot"])
            moved = {}
            for key, value in self.responses.items():
                method, params = loads(key)
                if method in ("eth_call", "eth_getCode") and params[1]["blockHash"] == old_hash:
                    params[1]["blockHash"] = self.a["blockHash"]
                moved[dumps([method, params])] = value
            self.responses = moved
            self.put("eth_getBlockByHash", [header["hash"], False], header)
        self.requested = []

    @staticmethod
    def matches(log, query):
        if log["address"] != query["address"] or len(log["topics"]) < len(query["topics"]): return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        return all(term is None or log["topics"][index] in (term if type(term) is list else [term])
            for index, term in enumerate(query["topics"]))

    def request(self, method, params):
        self.requested.append((method, deepcopy(params)))
        if method == "eth_getLogs":
            query, = params
            result = [deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"]
                if self.matches(log, query)]
            return sorted(result, key=lambda row: tuple(int(row[k], 16) for k in ("blockNumber", "transactionIndex", "logIndex")))
        if method == "eth_getBlockByNumber":
            assert params[1] is False
            return deepcopy(self.blocks[int(params[0], 16)])
        return Transport(self.responses).request(method, params)

    def source(self, **kwargs): return PublicOwnerCatalogSource(dumps(self.a), self, **kwargs)

    def result(self): return loads(self.source().snapshot(), maximum=64 * 1024 * 1024)


class PublicOwnerCatalogTests(unittest.TestCase):
    def test_high_anchor_exact_two_filters_complete_lanes_and_offline_replay(self):
        f = PublicOwnerCatalogFixture(source_block=9000003); source = f.source()
        with patch("socket.socket", side_effect=AssertionError("offline synthetic evidence")):
            raw = source.snapshot()
        result = loads(raw, maximum=64 * 1024 * 1024)
        self.assertEqual((result["profile"], result["profileHash"]), (PROFILE, PROFILE_HASH))
        self.assertEqual((len(result["catalogue"]), len(result["lanes"]), len(result["records"])), (11, 11, 4))
        self.assertEqual(result["sourceState"]["blockNumber"], "9000003")
        self.assertEqual({r["publication"]["blockNumber"] for r in result["records"]}, {"2"})
        self.assertEqual({r["receipt"][11] for r in result["records"]}, {schema_id(x) for x in ("DIRECT", "EIP712", "ERC1271")})
        coverage = result["historyCoverage"]
        expected = [{"address": A(1), "topics": [original.ADMISSION_EVENT]},
            {"address": A(1), "topics": [original.RECORD_EVENT, "0x" + encode(("uint256",), (71,)).hex()]}]
        self.assertEqual(coverage["filters"], expected)
        self.assertEqual((coverage["startBlock"], coverage["endBlock"], coverage["queries"]), ("0", "9000003", "362"))
        self.assertEqual((coverage["touchedBlocks"], coverage["receipts"], coverage["logs"]), ("3", "2", "5"))
        self.assertTrue(coverage["providerLogCompletenessTrusted"])
        self.assertTrue(coverage["canonicalMappingTrusted"])
        for flag in ("genesisWalk", "allBlockReceipts", "ancestryProven"):
            self.assertFalse(coverage[flag])
        for flag in ("actualChainAcceptance", "legalTitleProven", "currentOwnerProven", "independentlyVerifiedLogCompleteness"):
            self.assertFalse(result["claims"][flag])
        self.assertEqual({p[0] for m, p in f.requested if m == "eth_getBlockByNumber"}, {hex(1), hex(2), hex(9000003)})
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline replay")):
            replay = PublicOwnerCatalogSource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_low_anchor_original_native_results_and_profile_bytes_unchanged(self):
        old_bytes = original.PROFILE_BYTES
        old = loads(Fixture().source().snapshot(), maximum=1048576)
        new = PublicOwnerCatalogFixture(source_block=2).result()
        for field in ("sourceState", "host", "subjectId", "catalogue", "lanes", "records"):
            self.assertEqual(old[field], new[field], field)
        self.assertEqual(original.PROFILE_BYTES, old_bytes)
        self.assertEqual(loads(PROFILE_BYTES)["originalSemanticsProfileHash"], keccak256(old_bytes))
        self.assertNotEqual(PROFILE_BYTES, old_bytes)
        f = PublicOwnerCatalogFixture()
        with self.assertRaisesRegex(MuseumError, "history block bound"):
            original.OwnerCatalogSource(dumps(dict(f.a, profile=original.PROFILE)), f).snapshot()

    def test_empty_token_keeps_fixed_plus_admitted_empty_lanes(self):
        result = PublicOwnerCatalogFixture(empty=True).result()
        self.assertEqual(result["records"], [])
        self.assertEqual(len(result["lanes"]), 11)
        self.assertTrue(all(lane["state"] == "authenticated_empty" and lane["count"] == "0"
            and lane["head"] == ZERO and lane["latestByAuthor"] == [] for lane in result["lanes"]))

    def test_silently_omitted_empty_admission_remains_explicit_provider_trust(self):
        f = PublicOwnerCatalogFixture(empty=True)
        f.receipts[H("tx1")]["logs"].clear()
        result = f.result()
        self.assertEqual(len(result["catalogue"]), 10)
        self.assertTrue(result["claims"]["providerLogCompletenessTrusted"])
        self.assertFalse(result["claims"]["independentlyVerifiedLogCompleteness"])
        self.assertIn("omitted empty admitted type", result["qualification"])

    def test_profile_ranges_types_hints_and_old_transport_cannot_enter(self):
        for extra in ({"profile": original.PROFILE}, {"fromBlock": "1"}, {"types": []}, {"filters": []}, {"transactions": []}):
            f = PublicOwnerCatalogFixture()
            with self.subTest(extra=extra), self.assertRaisesRegex(MuseumError, "anchor shape"):
                PublicOwnerCatalogSource(dumps(f.a | extra), f)
            self.assertEqual(f.requested, [])
        f = PublicOwnerCatalogFixture()
        with self.assertRaisesRegex(MuseumError, "provenance"): f.source(provenance="trusted_rpc")
        old = dumps({"version": 1, "calls": []})
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicOwnerCatalogSource(dumps(f.a), ReplayTransport(old, keccak256(old)), provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "anchor shape"):
            original.OwnerCatalogSource(dumps(f.a), f)

    def test_exact_production_transport_and_replay_preserve_declared_provenance(self):
        f = PublicOwnerCatalogFixture()
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=f.request), \
                patch("socket.socket", side_effect=AssertionError("no network")):
            source = PublicOwnerCatalogSource(dumps(f.a), transport, provenance="trusted_rpc")
            raw = source.snapshot()
        result = loads(raw, maximum=1048576)
        self.assertEqual(result["mode"], "caller_admitted_rpc_owner_catalogue")
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        transcript = source.transcript()
        self.assertEqual(PublicOwnerCatalogSource(source.anchor_bytes,
            PublicReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc").snapshot(), raw)

    def test_missing_admission_and_publication_reject_native_state(self):
        for kind in ("admission", "publication"):
            f = PublicOwnerCatalogFixture()
            f.receipts[H("tx1" if kind == "admission" else "tx2")]["logs"].pop()
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError,
                    "type not yet admitted" if kind == "admission" else "missing/duplicate record event"):
                f.source().snapshot()

    def test_query_cannot_omit_another_matching_log_in_retained_full_receipt(self):
        f = PublicOwnerCatalogFixture(); request = f.request
        def omit(method, params):
            result = request(method, params)
            if method == "eth_getLogs" and params[0]["topics"][0] == original.RECORD_EVENT and result:
                result.pop()
            return result
        f.request = omit
        with self.assertRaisesRegex(MuseumError, "query/receipt matching logs differ"): f.source().snapshot()

    def test_admissions_are_unique_valid_and_before_custom_publication(self):
        for kind in ("duplicate", "fixed", "version", "later"):
            f = PublicOwnerCatalogFixture()
            if kind == "duplicate": f.log(1, A(1), f.admission["topics"], encode(("uint16",), (1,)))
            elif kind == "fixed": f.admission["topics"][1] = schema_id("ACCESSION")
            elif kind == "version": f.admission["data"] = "0x" + encode(("uint16",), (2,)).hex()
            else:
                f.receipts[H("tx1")]["logs"].clear()
                f.log(2, A(1), f.admission["topics"], encode(("uint16",), (1,)))
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError, "admission|type not yet admitted"):
                f.source().snapshot()

    def test_native_lane_heads_nonces_latest_index_and_signature_code_are_preserved(self):
        for kind in ("known", "empty-head", "tail", "latest", "index", "nonce", "signature-code"):
            f = PublicOwnerCatalogFixture(); family = schema_id("ACCESSION")
            if kind == "known": f.call("isOwnerRecordType(bytes32)", ("bool",), (False,), ("bytes32",), (schema_id("LOAN"),))
            elif kind == "empty-head": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (H("nonempty"), 0), ("uint256", "bytes32"), (71, schema_id("LOAN")))
            elif kind == "tail": f.call("recordChainHash(uint256,bytes32)", ("bytes32", "uint64"),
                (f.rows[1][2][4], 2), ("uint256", "bytes32"), (71, family))
            elif kind == "latest": f.call("latestOwnerRecordHashFor(uint256,bytes32,address)", ("bytes32",),
                (f.rows[0][0],), ("uint256", "bytes32", "address"), (71, family, A(8)))
            elif kind == "index": f.call("recordHashAt(uint256,bytes32,uint256)", ("bytes32",),
                (f.rows[1][0],), ("uint256", "bytes32", "uint256"), (71, family, 0))
            elif kind == "nonce": f.call("isOwnerRecordNonceUsed(address,uint256)", ("bool",), (False,),
                ("address", "uint256"), (A(8), 17))
            else: f.put("eth_getCode", [A(30), {"blockHash": f.a["blockHash"], "requireCanonical": True}], "0x00")
            source = f.source()
            with self.subTest(kind=kind), self.assertRaises(MuseumError): source.snapshot()
            with self.assertRaisesRegex(MuseumError, "cannot resume"): source.snapshot()

    def test_event_token_filter_excludes_foreign_token_without_loading_its_payload(self):
        f = PublicOwnerCatalogFixture()
        topics = list(f.receipts[H("tx2")]["logs"][0]["topics"])
        topics[1] = "0x" + encode(("uint256",), (72,)).hex()
        # Deliberately uninterpretable foreign payload: retained receipt has the
        # entire log, but this token's semantic reader must not decode it.
        f.log(2, A(1), topics, b"foreign-owner-payload")
        source = f.source(); result = loads(source.snapshot(), maximum=1048576)
        self.assertEqual(len(result["records"]), 4)
        self.assertIn(b"666f726569676e2d6f776e65722d7061796c6f6164", source.transcript())

    def test_external_pin_rehashed_native_tamper_and_replay_suffix_reject(self):
        f = PublicOwnerCatalogFixture(); source = f.source(); source.snapshot(); transcript = source.transcript()
        with self.assertRaisesRegex(MuseumError, "commitment"): PublicReplayTransport(transcript, H("wrong"))
        changed = loads(transcript, maximum=64 * 1024 * 1024)
        target = calldata("ownerRecord(bytes32)", ("bytes32",), (f.rows[0][0],))
        for row in changed["calls"]:
            if row["method"] == "eth_call" and row["params"][0]["data"] == target:
                record = list(f.rows[0][1]); record[5] = b"tampered"
                row["result"] = "0x" + encode((original.OWNER_RECORD, original.RECEIPT), (tuple(record), f.rows[0][2])).hex()
        raw = dumps(changed)
        with self.assertRaisesRegex(MuseumError, "embedded digest differs"):
            PublicOwnerCatalogSource(source.anchor_bytes, PublicReplayTransport(raw, keccak256(raw))).snapshot()
        changed = loads(transcript, maximum=64 * 1024 * 1024)
        changed["calls"].append(deepcopy(changed["calls"][-1])); raw = dumps(changed)
        with self.assertRaisesRegex(MuseumError, "unconsumed calls"):
            PublicOwnerCatalogSource(source.anchor_bytes, PublicReplayTransport(raw, keccak256(raw))).snapshot()

    def test_final_hash_and_number_mapping_rechecked_after_native_lane_reads(self):
        for target_method in ("eth_getBlockByHash", "eth_getBlockByNumber"):
            f = PublicOwnerCatalogFixture(); request = f.request; state_read = False
            def conflict(method, params):
                nonlocal state_read
                result = request(method, params)
                if method == "eth_call" and params[0]["data"].startswith(calldata(
                        "recordChainHash(uint256,bytes32)", ("uint256", "bytes32"), (71, schema_id("LOAN")))[:10]):
                    state_read = True
                if state_read and method == target_method:
                    result["transactions"] = [H("contradictory-final-transaction")]
                return result
            f.request = conflict
            with self.subTest(method=target_method), self.assertRaisesRegex(MuseumError, "repeated RPC result"):
                f.source().snapshot()


if __name__ == "__main__": unittest.main()
