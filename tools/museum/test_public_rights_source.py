"""Synthetic paged RPC mechanics; no actual public-chain or rights acceptance."""
import copy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import ReplayTransport
from .independent_wire import json_values
from .current_rights_source import CurrentRightsSource, PROFILE as OLD_PROFILE, PROFILE_BYTES as OLD_PROFILE_BYTES
from .public_rights_source import PublicRightsSource, PROFILE, PROFILE_BYTES, PROFILE_HASH
from .public_history_rpc import PublicRpcTransport, PublicReplayTransport
from .test_current_rights_source import (CurrentRightsFixture, A, H, SELECTION, EMPTY_SELECTION,
    METADATA_RECORDED, SELECTED_EVENT)


class PublicRightsFixture(CurrentRightsFixture):
    """Original concrete native-wire fixture with a synthetic getLogs endpoint."""

    def __init__(self, *, source_block=120005, **kwargs):
        super().__init__(**kwargs)
        self.a["profile"] = PROFILE
        self.a["environment"] = "public_chain"
        if source_block != 5:
            header = self.blocks.pop(H(205))
            header.update(hash=H(900000 + source_block), number=hex(source_block),
                parentHash=H(899999 + source_block), transactions=[])
            self.blocks[header["hash"]] = header
            self.a.update(blockHash=header["hash"], blockNumber=str(source_block))
            del self.receipts[H(405)]

    @staticmethod
    def matches(log, query):
        if log["address"] != query["address"]: return False
        if not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        for i, term in enumerate(query["topics"]):
            if term is None: continue
            if i >= len(log["topics"]) or log["topics"][i] not in (term if type(term) is list else [term]): return False
        return True

    def request(self, method, params):
        if method == "eth_getLogs":
            self.requested.append((method, copy.deepcopy(params)))
            query, = params
            logs = [copy.deepcopy(log) for receipt in self.receipts.values() for log in receipt["logs"]
                if self.matches(log, query)]
            return sorted(logs, key=lambda row: (int(row["blockNumber"], 16), int(row["logIndex"], 16)))
        if method == "eth_getBlockByNumber":
            self.requested.append((method, copy.deepcopy(params)))
            assert params[1] is False
            matches = [value for value in self.blocks.values() if value["number"] == params[0]]
            assert len(matches) == 1, params
            return copy.deepcopy(matches[0])
        return super().request(method, params)

    def source(self): return PublicRightsSource(dumps(self.a), self)


class PublicRightsSourceTests(unittest.TestCase):
    def test_large_height_fixed_filters_complete_native_revisions_and_exact_replay(self):
        f = PublicRightsFixture(token=True)
        f.append("collection", "denied", block=3)
        source = f.source(); raw = source.snapshot(); result = loads(raw, maximum=8 * 1024 * 1024)
        self.assertEqual(result["profile"], PROFILE)
        self.assertEqual(result["profileHash"], PROFILE_HASH)
        self.assertEqual(result["mode"], "synthetic_fixture")
        self.assertEqual(result["source"]["blockNumber"], "120005")
        self.assertEqual(len(result["scopes"]["collection"]["history"]), 2)
        self.assertEqual(len(result["scopes"]["token"]["history"]), 1)
        self.assertEqual({row["publication"]["recordedBlock"] for row in result["records"]}, {"1", "2", "3"})
        self.assertEqual(set(result["effectiveGrants"].values()), {"unspecified"})
        coverage = result["historyCoverage"]
        self.assertEqual((coverage["startBlock"], coverage["endBlock"]), ("0", "120005"))
        self.assertTrue(coverage["providerLogCompletenessTrusted"])
        self.assertTrue(coverage["canonicalMappingTrusted"])
        self.assertFalse(coverage["genesisWalk"])
        self.assertFalse(coverage["allBlockReceipts"])
        self.assertFalse(result["claims"]["independentlyVerifiedLogCompleteness"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        queries = [params[0] for method, params in f.requested if method == "eth_getLogs"]
        self.assertEqual(len(queries), 6)
        expected = {A(1): [METADATA_RECORDED, H(1), f.rows[0]["record"][0], [f.subject("collection"), f.subject("token")]],
            A(8): [SELECTED_EVENT, H(1), [f.subject("collection"), f.subject("token")]]}
        for query in queries: self.assertEqual(query["topics"], expected[query["address"]])
        self.assertLess(len({params[0] for method, params in f.requested if method == "eth_getBlockByHash"}), 10)
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("synthetic offline replay only")):
            replay = PublicRightsSource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_small_anchor_native_results_match_unchanged_original_profile(self):
        original_profile = bytes(OLD_PROFILE_BYTES)
        old = CurrentRightsFixture(token=True); new = PublicRightsFixture(source_block=5, token=True)
        old.append("collection", "denied", block=3); new.append("collection", "denied", block=3)
        old_result, new_result = old.result(), new.result()
        for field in ("binding", "identity", "scopes", "records", "documents", "artistLicensorIdentities",
                "effectiveGrants", "completeness", "dateAssessment"):
            self.assertEqual(new_result[field], old_result[field], field)
        self.assertEqual(OLD_PROFILE_BYTES, original_profile)
        self.assertNotEqual(PROFILE_BYTES, OLD_PROFILE_BYTES)

    def test_old_profile_and_arbitrary_filter_or_range_input_rejected_before_rpc(self):
        for extra in (None, {"fromBlock": "1"}, {"filters": []}, {"history": {"startBlock": "1"}}):
            f = PublicRightsFixture()
            a = dict(f.a)
            if extra is None: a["profile"] = OLD_PROFILE
            else: a.update(extra)
            with self.subTest(extra=extra), self.assertRaisesRegex(MuseumError, "shape/profile"):
                PublicRightsSource(dumps(a), f)
            self.assertEqual(f.requested, [])
        f = PublicRightsFixture()
        with self.assertRaisesRegex(MuseumError, "shape/profile"): CurrentRightsSource(dumps(f.a), f)

    def test_trusted_transport_is_exact_and_does_not_promote_synthetic_acceptance(self):
        f = PublicRightsFixture()
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicRightsSource(dumps(f.a), f, provenance="trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicRightsSource(dumps(f.a), ReplayTransport(dumps({"version": 1, "calls": []}),
                keccak256(dumps({"version": 1, "calls": []}))), provenance="trusted_rpc")
        # An exact production transport class routed only to the synthetic fixture
        # exercises caller-admitted provenance mechanics without making a socket.
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=f.request), \
                patch("socket.socket", side_effect=AssertionError("no network")):
            source = PublicRightsSource(dumps(f.a), transport, provenance="trusted_rpc")
            raw = source.snapshot(); result = loads(raw, maximum=8 * 1024 * 1024)
        self.assertEqual(result["mode"], "caller_admitted_rpc")
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        transcript = source.transcript()
        replay = PublicRightsSource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
        self.assertEqual(replay.snapshot(), raw)

    def test_native_head_requires_missing_publication_and_selection_events(self):
        for omitted in ("publication", "selection", "both"):
            f = PublicRightsFixture()
            logs = f.receipts[H(401)]["logs"]
            if omitted == "both": logs.clear()
            else: logs.pop(0 if omitted == "publication" else 1)
            for i, log in enumerate(logs): log["logIndex"] = hex(i)
            expected = "missing selected event" if omitted == "selection" else "original publication missing"
            with self.subTest(omitted=omitted), self.assertRaisesRegex(MuseumError, expected): f.source().snapshot()

    def test_empty_or_truncated_head_cannot_hide_returned_native_selections(self):
        for truncated in (False, True):
            f = PublicRightsFixture()
            if truncated:
                f.append("collection", "denied", block=2)
                f.selections["collection"].pop()
            else: f.selections["collection"] = []
            f.update_heads()
            with self.subTest(truncated=truncated), self.assertRaisesRegex(MuseumError, "selected event/history"):
                f.source().snapshot()

    def test_absent_selection_keeps_historical_publication_distinction(self):
        f = PublicRightsFixture(collection=False)
        f.append("collection", "granted", block=1, select=False)
        source = f.source(); result = loads(source.snapshot(), maximum=8 * 1024 * 1024)
        self.assertEqual(result["completeness"], "absent")
        self.assertEqual(result["records"], [])
        self.assertEqual(result["scopes"]["collection"]["current"], json_values(EMPTY_SELECTION))
        self.assertIn(METADATA_RECORDED, source.transcript().decode("utf-8"))
        self.assertFalse(result["claims"]["fullMetadataLaneHistory"])

    def test_original_provider_binding_and_positive_consumer_eligibility_required(self):
        f = PublicRightsFixture(collection=False)
        f.add(A(6), "scopeEvidenceProvider()", (), (), ("address",), (A(99),))
        with self.assertRaisesRegex(MuseumError, "provider binding"): f.source().snapshot()
        f = PublicRightsFixture(); head = f.selections["collection"][-1]
        f.add(A(8), "requireCurrent(uint256,bytes32,bytes32,uint64)", ("uint256", "bytes32", "bytes32", "uint64"),
            (1, f.subject("collection"), head[0], head[6]), (SELECTION,), (EMPTY_SELECTION,))
        with self.assertRaisesRegex(MuseumError, "consuming eligibility"): f.source().snapshot()

    def test_original_publication_must_precede_selection_in_same_receipt(self):
        f = PublicRightsFixture(); logs = f.receipts[H(401)]["logs"]; logs.reverse()
        for i, log in enumerate(logs): log["logIndex"] = hex(i)
        with self.assertRaisesRegex(MuseumError, "precedes publication"): f.source().snapshot()

    def test_known_artist_registration_is_preserved_without_current_authority_promotion(self):
        for wrong in (False, True):
            f = PublicRightsFixture(collection=False, burned=True, locked=True)
            artist, registration = f.artist_graph()
            f.append("collection", "granted", block=1, artist_identity_hash=H(999) if wrong else registration,
                edit=lambda value: value["licensor"].update(identity={"kind": "artist", "artistId": artist}))
            if wrong:
                with self.assertRaisesRegex(MuseumError, "licensor registration differs"): f.source().snapshot()
            else:
                result = f.result()
                self.assertTrue(result["identity"]["burned"])
                self.assertEqual(result["artistLicensorIdentities"][0]["authorityState"], [A(73), "4", "3", registration])
                self.assertFalse(result["claims"]["currentGrantReauthorization"])

    def test_external_transcript_pin_and_rehashed_native_result_tamper_reject(self):
        f = PublicRightsFixture(); source = f.source(); source.snapshot(); transcript = source.transcript()
        with self.assertRaisesRegex(MuseumError, "commitment"):
            PublicReplayTransport(transcript, H(123))
        value = loads(transcript, maximum=64 * 1024 * 1024)
        # Change an original publication return coherently in every occurrence;
        # the rehashed transcript still conflicts with the pinned native receipt.
        for row in value["calls"]:
            if row["method"] == "eth_getLogs" and row["result"] and row["result"][0]["address"] == A(1):
                row["result"][0]["data"] = "0x"
        changed = dumps(value)
        with self.assertRaises(MuseumError):
            PublicRightsSource(source.anchor_bytes, PublicReplayTransport(changed, keccak256(changed))).snapshot()

    def test_post_state_canonical_number_mapping_and_exact_rpc_result_conflicts_reject(self):
        for method_name in ("eth_getBlockByHash", "eth_getBlockByNumber"):
            f = PublicRightsFixture(); original = f.request
            def changed(method, params):
                result = original(method, params)
                if method == method_name and any(m == "eth_call" for m, _ in f.requested):
                    result["transactions"] = [H(99999)]
                return result
            f.request = changed
            with self.subTest(method=method_name), self.assertRaisesRegex(MuseumError, "repeated RPC result"):
                f.source().snapshot()


if __name__ == "__main__": unittest.main()
