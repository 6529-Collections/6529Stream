"""Sparse public-chain ownership vectors, explicitly synthetic RPC responses."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import calldata, encode
from .independent_wire import ZERO_ADDRESS
from .public_history_rpc import PublicReplayTransport
from .public_ownership_source import PublicOwnershipSource, PROFILE, PROFILE_HASH
from .test_ownership_source import OwnershipFixture, A, H


class PublicOwnershipFixture(OwnershipFixture):
    def __init__(self, *, burned=False, height=9000003):
        super().__init__(burned=burned)
        self.a.update(profile=PROFILE, blockNumber=str(height), environment="public_chain")
        offset = height - 3
        for block in self.blocks.values():
            block["number"] = hex(int(block["number"], 16) + offset)
            if block["parentHash"] == H(0) and int(block["number"], 16): block["parentHash"] = H(99)
        for receipt in self.receipts.values():
            receipt["blockNumber"] = hex(int(receipt["blockNumber"], 16) + offset)
            for log in receipt["logs"]: log["blockNumber"] = receipt["blockNumber"]
        self.omit = set()

    def request(self, method, params):
        if method == "eth_getBlockByNumber":
            self.requested.append((method, deepcopy(params)))
            return deepcopy(next(b for b in self.blocks.values() if b["number"] == params[0]))
        if method == "eth_getLogs":
            self.requested.append((method, deepcopy(params)))
            query = params[0]
            lower, upper = int(query["fromBlock"], 16), int(query["toBlock"], 16)
            result = []
            for transaction, receipt in self.receipts.items():
                if transaction in self.omit: continue
                for row in receipt["logs"]:
                    if row["address"] != query["address"] or not lower <= int(row["blockNumber"], 16) <= upper: continue
                    if len(row["topics"]) < len(query["topics"]): continue
                    if all(value is None or (row["topics"][index] in value if isinstance(value, list)
                        else row["topics"][index] == value) for index, value in enumerate(query["topics"])):
                        result.append(deepcopy(row))
            return result
        return super().request(method, params)

    def source(self): return PublicOwnershipSource(dumps(self.a), self)


class PublicOwnershipTests(unittest.TestCase):
    def test_high_public_height_uses_sparse_headers_and_replays_exactly(self):
        f = PublicOwnershipFixture(); source = f.source(); raw = source.snapshot()
        result = loads(raw, maximum=8 * 1024 * 1024)
        self.assertEqual(result["profileHash"], PROFILE_HASH)
        self.assertEqual(len(result["transitions"]), 3)
        self.assertEqual(result["identity"]["owner"], A(2))
        self.assertEqual(result["historyCoverage"]["endBlock"], "9000003")
        self.assertEqual(result["historyCoverage"]["queries"], "181")
        heights = {p[0] for m, p in f.requested if m == "eth_getBlockByNumber"}
        self.assertEqual(heights, {hex(9000001), hex(9000002), hex(9000003)})
        self.assertTrue(result["claims"]["providerLogCompletenessTrusted"])
        self.assertFalse(result["claims"]["genesisWalk"])
        self.assertFalse(result["claims"]["fullAcquisitionItem10"])
        transcript = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline")):
            replay = PublicOwnershipSource(source.anchor_bytes, PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)

    def test_burned_token_does_not_query_reverting_owner_and_keeps_history(self):
        f = PublicOwnershipFixture(burned=True)
        del f.calls[calldata("ownerOf(uint256)", ("uint256",), (71,))]
        result = loads(f.source().snapshot(), maximum=8 * 1024 * 1024)
        self.assertEqual(result["transitions"][-1]["kind"], "burn")
        self.assertEqual(result["identity"]["owner"], ZERO_ADDRESS)

    def test_missing_mint_disconnected_transfer_and_final_owner_conflicts_fail(self):
        for edit in (lambda f: f.omit.add(H(301)), lambda f: f.omit.add(H(302)),
            lambda f: f.calls.__setitem__(calldata("ownerOf(uint256)", ("uint256",), (71,)), encode(("address",), (A(99),)))):
            f = PublicOwnershipFixture(); edit(f)
            with self.subTest(edit=edit), self.assertRaises(MuseumError): f.source().snapshot()

    def test_silent_self_transfer_omission_remains_explicit_provider_trust(self):
        f = PublicOwnershipFixture(); f.omit.add(H(303))
        result = loads(f.source().snapshot(), maximum=8 * 1024 * 1024)
        self.assertEqual(len(result["transitions"]), 2)
        self.assertTrue(result["claims"]["providerLogCompletenessTrusted"])
        self.assertFalse(result["claims"]["consensusVerified"])
        self.assertIn("omitted transfer cycles", result["qualification"])

    def test_original_profile_lower_bound_and_wrong_transport_provenance_refused(self):
        from .ownership_source import PROFILE as OLD_PROFILE
        from .chain_rpc import ReplayTransport
        f = PublicOwnershipFixture()
        for a in (f.a | {"profile": OLD_PROFILE}, f.a | {"fromBlock": "9000000"}):
            with self.subTest(a=a), self.assertRaises(MuseumError): PublicOwnershipSource(dumps(a), f)
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicOwnershipSource(dumps(f.a), f, provenance="trusted_rpc")
        empty = dumps({"version": 1, "calls": []})
        with self.assertRaisesRegex(MuseumError, "provenance"):
            PublicOwnershipSource(dumps(f.a), ReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")

    def test_original_strict_reader_still_refuses_high_block(self):
        from .ownership_source import OwnershipSource, PROFILE as OLD_PROFILE
        f = PublicOwnershipFixture()
        with self.assertRaisesRegex(MuseumError, "history block bound"):
            OwnershipSource(dumps(f.a | {"profile": OLD_PROFILE}), f).snapshot()


if __name__ == "__main__":
    unittest.main()
