"""Synthetic public-query mechanics over unchanged exact native mint fixtures."""
import copy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import calldata, encode
from .chain_rpc import ReplayTransport
from .mint_entropy_source import MintEntropySource, PROFILE as OLD_PROFILE, PROFILE_BYTES as OLD_PROFILE_BYTES
from .public_mint_entropy_source import PublicMintEntropySource, PROFILE, PROFILE_HASH, PROFILE_BYTES
from .public_history_rpc import PublicRpcTransport, PublicReplayTransport
from .test_mint_entropy_source import (MintEntropyFixture, H, A, ZERO, TRANSFER, REGISTERED, REVERTED,
    ENTROPY_REGISTERED, REQUESTED, FINALIZED, TERMINAL, SUPERSEDED, TOKEN_ENTROPY, POLICY, CONFIG)


class PublicMintEntropyFixture(MintEntropyFixture):
    def __init__(self, *, source_block=120005, **kwargs):
        super().__init__(**kwargs)
        self.a["profile"], self.a["environment"] = PROFILE, "public_chain"
        if source_block != 6:
            require_height = source_block > 6
            if not require_height: raise ValueError("synthetic public source must retain original event blocks")
            header = {"hash": H(900000+source_block), "number": hex(source_block), "timestamp": hex(2000+source_block),
                "stateRoot": H(1900000+source_block), "parentHash": H(899999+source_block), "transactions": []}
            self.blocks[header["hash"]] = header
            self.a.update(blockHash=header["hash"], blockNumber=str(source_block), timestamp=str(2000+source_block), stateRoot=header["stateRoot"])

    @staticmethod
    def matches(log, query):
        if log["address"] != query["address"] or not int(query["fromBlock"], 16) <= int(log["blockNumber"], 16) <= int(query["toBlock"], 16): return False
        if len(log["topics"]) < len(query["topics"]): return False
        for index, topic in enumerate(query["topics"]):
            if topic is not None and log["topics"][index] not in (topic if type(topic) is list else [topic]): return False
        return True

    def request(self, method, params):
        if method == "eth_getLogs":
            self.requested.append((method, copy.deepcopy(params)))
            rows = [copy.deepcopy(row) for receipt in self.receipts.values() for row in receipt["logs"] if self.matches(row, params[0])]
            return sorted(rows, key=lambda row: (int(row["blockNumber"], 16), int(row["transactionIndex"], 16), int(row["logIndex"], 16)))
        if method == "eth_getBlockByNumber":
            self.requested.append((method, copy.deepcopy(params)))
            matches = [header for header in self.blocks.values() if header["number"] == params[0]]
            assert len(matches) == 1 and params[1] is False
            return copy.deepcopy(matches[0])
        return super().request(method, params)

    def source(self): return PublicMintEntropySource(dumps(self.a), self)


class PublicMintEntropySourceTests(unittest.TestCase):
    def test_original_native_semantic_parity_and_helpers_unchanged(self):
        for options in ({}, {"status": 3}, {"status": 4}, {"status": 6}, {"status": 7},
            {"recovery": True}, {"recovery": True, "late": True}, {"burned": True}, {"prepared": True}, {"abandoned": True}):
            with self.subTest(options=options):
                old = MintEntropyFixture(**options).result()
                new = PublicMintEntropyFixture(source_block=6, **options).result()
                for field in ("identity", "mint", "entropy", "entropyLeafBytes", "entropyLogs", "entropyControlLogs",
                    "observedStatus", "observedStatusLabel", "terminalEligible", "native", "remaining"):
                    self.assertEqual(new[field], old[field], field)
        for helper in ("_read", "_interfaces", "_mint", "_entropy"):
            self.assertIs(getattr(PublicMintEntropySource, helper), getattr(MintEntropySource, helper))
        self.assertNotEqual(PROFILE_BYTES, OLD_PROFILE_BYTES)

    def test_high_height_fixed_primary_and_derived_control_queries_with_replay(self):
        f = PublicMintEntropyFixture(source_block=9000000, recovery=True, late=True)
        source = f.source(); raw = source.snapshot(); result = loads(raw, maximum=4*1024*1024)
        self.assertEqual(result["profileHash"], PROFILE_HASH)
        self.assertEqual(result["mode"], "synthetic_fixture")
        coverage = result["historyCoverage"]
        self.assertEqual(coverage["derivedRequestKeys"], f.keys)
        self.assertEqual(coverage["primary"]["queries"], "724")
        self.assertEqual(coverage["controls"]["queries"], "543")
        self.assertEqual(coverage["startBlock"], "0")
        self.assertFalse(coverage["genesisWalk"]); self.assertFalse(coverage["allBlockReceipts"])
        self.assertTrue(coverage["providerLogCompletenessTrusted"])
        self.assertTrue(coverage["canonicalMappingTrusted"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertEqual(coverage["primary"]["filters"], [
            {"address": A(10), "topics": [[REGISTERED, REVERTED], H(71)]},
            {"address": A(10), "topics": [TRANSFER, None, None, H(71)]},
            {"address": A(20), "topics": [ENTROPY_REGISTERED, None, H(71)]},
            {"address": A(20), "topics": [[REQUESTED, FINALIZED], None, H(71)]}])
        self.assertEqual(coverage["controls"]["filters"], [{"address": A(20), "topics": topics}
            for topics in ([TERMINAL, f.keys], [SUPERSEDED, f.keys], [SUPERSEDED, None, f.keys])])
        self.assertEqual(result["entropy"]["leaf"]["requestAttempt"], "1")
        self.assertEqual(result["requestHistoryObservation"], {"observedRequestCount": "2", "observedMaximumAttempt": "2", "lifetimeAttemptHighWaterProven": False})
        self.assertEqual(len(result["entropyControlLogs"]), 2)
        self.assertEqual(len(hex_bytes(result["entropyLeafBytes"])), 288)
        self.assertEqual(keccak256(hex_bytes(result["entropyLeafBytes"])), result["entropy"]["leafHash"])
        self.assertEqual(source.snapshot(), raw)
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("no network")):
            replay = PublicMintEntropySource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_registered_has_no_control_stage_and_unsupported_statuses_have_no_fallback(self):
        f = PublicMintEntropyFixture(status=3); report = f.result()
        self.assertEqual(report["historyCoverage"]["controlScanStatus"], "not_queried_no_request_keys")
        self.assertIsNone(report["historyCoverage"]["controls"])
        self.assertEqual(report["historyCoverage"]["derivedRequestKeys"], [])
        self.assertEqual(report["requestHistoryObservation"]["observedMaximumAttempt"], "0")
        self.assertFalse(report["terminalEligible"])
        self.assertEqual(len([1 for method, _ in f.requested if method == "eth_getLogs"]), 12)
        for status in (0, 1, 2, 8):
            f = PublicMintEntropyFixture(status=3); f.entropy = (status,) + f.entropy[1:]; f.update_views()
            with self.subTest(status=status), self.assertRaisesRegex(MuseumError, "production writer"): f.source().snapshot()

    def test_omitted_request_terminal_and_supersession_reject_without_claiming_log_completeness(self):
        for omitted in (REQUESTED, TERMINAL, SUPERSEDED):
            f = PublicMintEntropyFixture(recovery=True, late=True)
            for receipt in f.receipts.values():
                receipt["logs"] = [row for row in receipt["logs"] if row["topics"][0] != omitted]
                for i, row in enumerate(receipt["logs"]): row["logIndex"] = hex(i)
            with self.subTest(omitted=omitted), self.assertRaises(MuseumError): f.source().snapshot()

    def test_control_hit_visible_in_primary_receipt_cannot_be_omitted_by_control_queries(self):
        f = PublicMintEntropyFixture(recovery=True, late=True); original = f.request
        def omit_control(method, params):
            result = original(method, params)
            if method == "eth_getLogs" and params[0]["topics"][0] == SUPERSEDED: return []
            return result
        f.request = omit_control
        with self.assertRaisesRegex(MuseumError, "cross-stage query/receipt matching logs differ"): f.source().snapshot()

    def test_union_detects_header_contradictions_between_stages(self):
        for kind in ("parent", "time"):
            f = PublicMintEntropyFixture(recovery=True)
            if kind == "parent": f.blocks[H(103)]["parentHash"] = H(999)
            else: f.blocks[H(103)]["timestamp"] = hex(1001)
            expected = "cross-stage adjacent parent" if kind == "parent" else "cross-stage header time"
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError, expected): f.source().snapshot()

    def test_union_detects_different_receipts_reusing_or_reordering_global_log_positions(self):
        for duplicate in (True, False):
            f = PublicMintEntropyFixture(status=7)
            terminal = f.receipts[H(303)]["logs"].pop()
            header = f.blocks[H(102)]; tx = H(999)
            header["transactions"].append(tx)
            receipt = {"transactionHash": tx, "blockHash": H(102), "blockNumber": "0x2",
                "transactionIndex": "0x1", "status": "0x1", "logs": [terminal]}
            terminal.update({key: receipt[key] for key in ("transactionHash", "blockHash", "blockNumber", "transactionIndex")})
            terminal["logIndex"] = "0x0"
            f.receipts[tx] = receipt
            if not duplicate: f.receipts[H(302)]["logs"][0]["logIndex"] = "0x1"
            expected = "cross-stage duplicate block log position" if duplicate else "cross-stage transaction/log order differs"
            with self.subTest(duplicate=duplicate), self.assertRaisesRegex(MuseumError, expected): f.source().snapshot()

    def test_rehashed_seed_policy_index_and_return_abi_reject(self):
        for kind in ("seed", "policy", "abi"):
            f = PublicMintEntropyFixture()
            if kind == "seed":
                f.entropy = (5, H(99)) + f.entropy[2:]; f.update_views()
                f.receipts[H(303)]["logs"][0]["data"] = "0x" + encode(("bytes32", "bytes32"), (H(99), H(700))).hex()
            elif kind == "policy":
                p = f.policies[f.keys[0]]
                f.set(A(20), "requestPolicySnapshot(bytes32)", POLICY, p[:4] + (H(999),) + p[5:], ("bytes32",), (f.keys[0],))
            else: f.calls[(A(20), calldata("tokenEntropy(uint256)", ("uint256",), (71,)))] += bytes(32)
            with self.subTest(kind=kind), self.assertRaises(MuseumError): f.source().snapshot()

    def test_recovery_permission_and_restored_active_attempt_are_not_lifetime_count(self):
        for kind in ("late_permission", "leaf_attempt"):
            f = PublicMintEntropyFixture(recovery=True, late=True)
            if kind == "late_permission": f.recoveries[f.keys[1]] = f.recoveries[f.keys[1]][:-1] + (False,)
            else: f.entropy = f.entropy[:-1] + (2,)
            f.update_views()
            expected = "late-original path" if kind == "late_permission" else "current request tuple"
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError, expected): f.source().snapshot()

    def test_original_coordinator_identity_runtime_and_locked_config_must_match(self):
        for edit in (lambda f: f.core("coordinatorAtMint(uint256)", ("address",), (A(99),)),
            lambda f: f.core("tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"), (True, 9, 2, False)),
            lambda f: f.code.__setitem__(A(20), b"foreign"),
            lambda f: f.set(A(20), "collectionEntropyConfig(uint256)", CONFIG,
                (A(30), True, True, 100, H(501), H(999), H(503)), ("uint256",), (6,))):
            f = PublicMintEntropyFixture(); edit(f)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): f.source().snapshot()

    def test_missing_original_policy_getter_has_no_current_policy_fallback(self):
        f = PublicMintEntropyFixture(); target = calldata("requestPolicySnapshot(bytes32)", ("bytes32",), (f.keys[0],))
        original = f.request
        def missing(method, params):
            if method == "eth_call" and params[0]["to"] == A(20) and params[0]["data"] == target:
                f.requested.append((method, params)); return "0x"
            return original(method, params)
        f.request = missing
        with self.assertRaisesRegex(MuseumError, "ABI"): f.source().snapshot()
        calls = [params[0]["data"] for method, params in f.requested if method == "eth_call"]
        self.assertEqual(calls[-1], target)

    def test_primary_event_bound_rejects_before_unbounded_control_key_scan(self):
        f = PublicMintEntropyFixture(status=3)
        for index in range(65):
            f.log(2, A(20), [REQUESTED, H(900+index), H(71), ZERO], ("address", "uint256"), (A(30), index+1))
        with self.assertRaisesRegex(MuseumError, "request key/event bound"): f.source().snapshot()
        self.assertEqual(len([1 for method, _ in f.requested if method == "eth_getLogs"]), 12)
        self.assertFalse(any(method == "eth_call" for method, _ in f.requested))

    def test_requested_event_cannot_precede_completed_mint_transfer(self):
        f = PublicMintEntropyFixture(status=4)
        f.move_log(2, 1, 0, position=2)
        key = f.keys[0]; f.requests[key] = f.requests[key][:4] + (1,) + f.requests[key][5:]; f.update_views()
        with self.assertRaisesRegex(MuseumError, "before completed mint Transfer"): f.source().snapshot()

    def test_native_reads_recheck_both_source_header_forms_and_exact_replay_ranges(self):
        for method_to_change in ("eth_getBlockByHash", "eth_getBlockByNumber"):
            f = PublicMintEntropyFixture(); original = f.request
            def change(method, params):
                result = original(method, params)
                if method == method_to_change and any(m == "eth_call" for m, _ in f.requested): result["transactions"] = [H(999)]
                return result
            f.request = change
            with self.subTest(method=method_to_change), self.assertRaisesRegex(MuseumError, "repeated RPC result"): f.source().snapshot()
        f = PublicMintEntropyFixture(); source = f.source(); source.snapshot(); packet = loads(source.transcript(), maximum=67108864)
        query = next(row for row in packet["calls"] if row["method"] == "eth_getLogs")
        query["params"][0]["fromBlock"] = "0x1"
        altered = dumps(packet)
        with self.assertRaisesRegex(MuseumError, "order mismatch"):
            PublicMintEntropySource(source.anchor_bytes, PublicReplayTransport(altered, keccak256(altered))).snapshot()

    def test_closed_profile_anchor_and_exact_public_provenance(self):
        f = PublicMintEntropyFixture()
        for edit in (lambda a: a.update(profile=OLD_PROFILE), lambda a: a.update(fromBlock="1"),
            lambda a: a.update(filters=[]), lambda a: a.update(requestKeys=[H(999)])):
            a = dict(f.a); edit(a)
            with self.subTest(edit=edit), self.assertRaisesRegex(MuseumError, "shape/profile"): PublicMintEntropySource(dumps(a), f)
        self.assertEqual(f.requested, [])
        with self.assertRaisesRegex(MuseumError, "provenance"): PublicMintEntropySource(dumps(f.a), f, provenance="trusted_rpc")
        old_wire = dumps({"version": 1, "calls": []})
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicMintEntropySource(dumps(f.a), ReplayTransport(old_wire, keccak256(old_wire)), provenance="trusted_rpc")
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=f.request), patch("socket.socket", side_effect=AssertionError("no network")):
            source = PublicMintEntropySource(dumps(f.a), transport, provenance="trusted_rpc")
            raw = source.snapshot()
        result = loads(raw, maximum=4*1024*1024)
        self.assertEqual(result["mode"], "caller_admitted_public_rpc_history")
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        transcript = source.transcript()
        replay = PublicMintEntropySource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
        self.assertEqual(replay.snapshot(), raw)


if __name__ == "__main__": unittest.main()
