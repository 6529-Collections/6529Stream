"""Independent bounded two-input observations; no native evidence authentication."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import conservation_capture_join as shared
from . import conservation_rights_join as join
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .test_conservation_capture_join import JoinFixture


def H(label): return schema_id(str(label))
def A(number): return "0x" + number.to_bytes(20, "big").hex()


class RightsJoinFixture:
    """Synthetic original anchor shapes; does not stand in for capture verification."""
    def __init__(self, *, direct=False, same_block=False, adjacent=False):
        self.common = {"chainId": "11155111", "core": A(1), "collectionId": "7",
            "blockHash": H("block100"), "blockNumber": "100", "timestamp": "1100",
            "stateRoot": H("root100"), "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment")}
        self.code = b"synthetic-core-code"; self.blocks = {}; self.header(100)
        self.anchors, self.receipts, self.queries, self.extra = {}, {}, {}, {name: [] for name in join.NAMES}
        for name, number in zip(join.NAMES, (20, 20 if same_block else 21 if adjacent else 60)):
            hosts = {key: A(1 if key == "core" else 2 + index if name == "rights" else 20 + index)
                for index, key in enumerate(join.HOSTS[name])}
            pins = [{"address": address, "runtimeHash": keccak256(self.code) if address == A(1) else H(address)}
                for address in hosts.values()]
            profile = join.RIGHTS_PROFILE if name == "rights" else next(p for p, family in join.FLOOR_FAMILIES.items()
                if family == ("direct_primary_v1" if direct else "universal_primary_v1"))
            self.anchors[name] = {**self.common, **hosts, "profile": profile, "codePins": pins}
            if name == "rights": self.anchors[name]["tokenId"] = "41"
            b = self.header(number); tx = H("transaction-" + name); index = len(b["transactions"])
            b["transactions"].append(tx)
            log_index = sum(len(r["logs"]) for r in self.receipts.values() if r["blockHash"] == b["hash"])
            coordinates = {"blockHash": b["hash"], "blockNumber": hex(number),
                "transactionHash": tx, "transactionIndex": hex(index)}
            log = {**coordinates, "address": hosts["host" if name == "rights" else "conservationFloor"],
                "topics": [H("event-" + name)], "data": "0x", "removed": False, "logIndex": hex(log_index)}
            self.receipts[name] = {**coordinates, "status": "0x1", "logs": [log]}
            self.queries[name] = {"method": "eth_getLogs", "params": [{"address": log["address"],
                "topics": deepcopy(log["topics"]), "fromBlock": "0x0", "toBlock": "0x64"}], "result": [deepcopy(log)]}

    def header(self, number):
        if number not in self.blocks:
            self.blocks[number] = {"hash": H("block" + str(number)), "number": hex(number),
                "parentHash": H("block" + str(number - 1)), "timestamp": hex(1000 + number),
                "stateRoot": H("root" + str(number)), "transactions": []}
        return self.blocks[number]

    def inputs(self):
        result = {}
        for name in join.NAMES:
            r = self.receipts[name]
            calls = [{"method": "eth_chainId", "params": [], "result": hex(int(self.common["chainId"]))},
                {"method": "eth_getCode", "params": [A(1), {"blockHash": self.common["blockHash"], "requireCanonical": True}],
                    "result": "0x" + self.code.hex()}]
            for number in sorted({100, int(r["blockNumber"], 16)}):
                b = self.blocks[number]
                calls.extend([{"method": "eth_getBlockByHash", "params": [b["hash"], False], "result": b},
                    {"method": "eth_getBlockByNumber", "params": [hex(number), False], "result": b}])
            calls.extend([{"method": "eth_getTransactionReceipt", "params": [r["transactionHash"]], "result": r},
                self.queries[name], *self.extra[name]])
            result[name] = {"anchor": dumps(self.anchors[name]), "transcript": dumps({"version": shared.rpc.VERSION,
                "profile": shared.rpc.PROFILE, "calls": calls})}
        return result

    def cross_log(self):
        log = deepcopy(self.receipts["rights"]["logs"][0]); f = self.queries["floor"]["params"][0]
        log.update(address=f["address"], topics=deepcopy(f["topics"]), logIndex="0x1")
        self.receipts["rights"]["logs"].append(log)
        return log


def edit_calls(inputs, name, edit):
    packet = loads(inputs[name]["transcript"], maximum=shared.rpc.MAX_TRANSCRIPT)
    edit(packet["calls"]); inputs[name]["transcript"] = dumps(packet)


class ConservationRightsJoinTests(unittest.TestCase):
    def test_original_three_input_profile_and_output_bytes_are_unchanged(self):
        self.assertEqual(shared.PROFILE_HASH, "0x3afec2a64be199c9f5edbfb556176b84d9e6c82abc45e3a4eb39353bb503981c")
        self.assertEqual(len(shared.PROFILE_BYTES), 2558)
        for same, digest in ((False, "0x43cf876754956356de2ab1a098801e7ecbe2b4a29a6e65a4923d4299006cd603"),
                (True, "0xc0587ba796588b035182d3bb120c2cfe179dbaf2c78d8c349d3a39cc1acd51de")):
            self.assertEqual(keccak256(dumps(shared.reconcile(JoinFixture(same_block=same).inputs()))), digest)

    def test_both_original_floor_families_preserved_offline_without_native_claim(self):
        for direct in (False, True):
            fixture = RightsJoinFixture(direct=direct); inputs = fixture.inputs(); before = deepcopy(inputs)
            with self.subTest(direct=direct), patch("socket.socket", side_effect=AssertionError("offline only")), \
                    patch("urllib.request.build_opener", side_effect=AssertionError("offline only")):
                result = join.reconcile(inputs)
                self.assertEqual(join.reconcile(dict(reversed(list(inputs.items())))), result)
            self.assertEqual(inputs, before)
            self.assertEqual(result["floorFamily"], "direct_primary_v1" if direct else "universal_primary_v1")
            self.assertEqual(result["sourceState"], fixture.common)
            self.assertEqual(result["coreRuntimeHash"], keccak256(fixture.code))
            self.assertEqual(result["counts"]["receipts"], "2")
            self.assertEqual(result["counts"]["receiptLogs"], "2")
            for name in join.NAMES:
                self.assertEqual(result["inputs"][name], {"anchorHash": keccak256(inputs[name]["anchor"]),
                    "transcriptHash": keccak256(inputs[name]["transcript"])})
            self.assertTrue(result["claims"]["capturesAlreadyVerifiedRequired"])
            for key in ("nativeSemanticsReverified", "sourceProvenanceAuthenticated", "unobservedLogCompletenessProven",
                    "ancestryProven", "actualChainAcceptance", "consensusVerified"):
                self.assertFalse(result["claims"][key])

    def test_closed_pair_original_anchor_profiles_and_canonical_bytes(self):
        for change in (lambda v: v.pop("rights"), lambda v: v.update(tier=v["floor"]),
                lambda v: v["rights"].update(extra=b"{}"), lambda v: v["floor"].update(anchor="text"),
                lambda v: v["rights"].update(anchor=v["rights"]["anchor"] + b"\n")):
            inputs = RightsJoinFixture().inputs(); change(inputs)
            with self.assertRaises(MuseumError): join.reconcile(inputs)
        for key, value in (("profile", "STREAM_MUSEUM_CURRENT_RIGHTS_SOURCE_V1"), ("tokenId", "0"), ("extra", "x")):
            fixture = RightsJoinFixture(); fixture.anchors["rights"][key] = value
            with self.subTest(key=key), self.assertRaises(MuseumError): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.anchors["floor"]["tokenId"] = "41"
        with self.assertRaisesRegex(MuseumError, "shape/profile"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.anchors["floor"]["profile"] = join.RIGHTS_PROFILE
        with self.assertRaisesRegex(MuseumError, "shape/profile"): join.reconcile(fixture.inputs())
        inputs = RightsJoinFixture().inputs()
        packet = loads(inputs["rights"]["transcript"], maximum=shared.rpc.MAX_TRANSCRIPT)
        packet["version"] = 1; inputs["rights"]["transcript"] = dumps(packet)
        with self.assertRaisesRegex(MuseumError, "transcript profile"): join.reconcile(inputs)

    def test_common_anchor_runtime_pin_and_repeated_state_outcomes(self):
        for key in join.COMMON:
            fixture = RightsJoinFixture(); fixture.anchors["floor"][key] = "different"
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "common anchor"):
                join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.anchors["floor"]["codePins"][0]["runtimeHash"] = H("other")
        with self.assertRaisesRegex(MuseumError, "runtime pin"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture()
        for name in join.NAMES:
            fixture.anchors[name]["codePins"].append({"address": A(90), "runtimeHash": H(name)})
        with self.assertRaisesRegex(MuseumError, "runtime pin"): join.reconcile(fixture.inputs())
        inputs = RightsJoinFixture().inputs()
        edit_calls(inputs, "floor", lambda rows: rows[1].update(result="0x01"))
        with self.assertRaisesRegex(MuseumError, "RPC outcome|runtime"): join.reconcile(inputs)
        fixture = RightsJoinFixture(); state = {"method": "eth_call", "params": [{"to": A(90), "data": "0x1234", "gas": "0x1"},
            {"blockHash": fixture.common["blockHash"], "requireCanonical": True}], "result": "0x01"}
        fixture.extra["rights"].append(state); fixture.extra["floor"].append({**state, "result": "0x02"})
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())

    def test_same_query_limit_outcomes_are_not_empty_success_or_interchangeable(self):
        for outcome in ({"limit": "response_size"}, {"result": []}):
            fixture = RightsJoinFixture()
            params = [{"address": A(90), "topics": [], "fromBlock": "0x0", "toBlock": "0x64"}]
            fixture.extra["rights"].append({"method": "eth_getLogs", "params": params, "limit": "range_limit"})
            fixture.extra["floor"].append({"method": "eth_getLogs", "params": params, **outcome})
            with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())

    def test_header_union_reciprocal_mapping_timestamps_and_adjacent_parent(self):
        fixture = RightsJoinFixture(adjacent=True); fixture.blocks[21]["timestamp"] = hex(1019)
        with self.assertRaisesRegex(MuseumError, "time regresses"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(adjacent=True); fixture.blocks[21]["parentHash"] = H("other")
        with self.assertRaisesRegex(MuseumError, "adjacent parent"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.blocks[60]["parentHash"] = H("unobserved")
        self.assertFalse(join.reconcile(fixture.inputs())["claims"]["ancestryProven"])
        inputs = RightsJoinFixture().inputs()
        def change(rows):
            for row in rows:
                if row["method"] == "eth_getBlockByNumber" and row["params"][0] == "0x64":
                    row["result"]["transactions"] = [H("invented")]
        edit_calls(inputs, "floor", change)
        with self.assertRaises(MuseumError): join.reconcile(inputs)
        inputs = RightsJoinFixture().inputs()
        edit_calls(inputs, "floor", lambda rows: rows.__setitem__(slice(None), [r for r in rows
            if r["method"] != "eth_getBlockByNumber" or r["params"][0] != "0x3c"]))
        with self.assertRaisesRegex(MuseumError, "reciprocal header"): join.reconcile(inputs)

    def test_full_receipt_transaction_and_global_log_union(self):
        fixture = RightsJoinFixture(); fixture.blocks[60]["transactions"].append(fixture.receipts["rights"]["transactionHash"])
        with self.assertRaisesRegex(MuseumError, "multiple blocks"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); receipt = deepcopy(fixture.receipts["rights"]); receipt["extra"] = "conflict"
        fixture.extra["floor"].append({"method": "eth_getTransactionReceipt", "params": [receipt["transactionHash"]], "result": receipt})
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.receipts["floor"]["transactionIndex"] = "0x1"
        with self.assertRaisesRegex(MuseumError, "transaction slot"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(same_block=True); join.reconcile(fixture.inputs())
        for index, message in (("0x0", "duplicate block log"), ("0x2", "adjacent receipt log gap")):
            fixture = RightsJoinFixture(same_block=True)
            fixture.receipts["floor"]["logs"][0]["logIndex"] = index; fixture.queries["floor"]["result"][0]["logIndex"] = index
            with self.assertRaisesRegex(MuseumError, message): join.reconcile(fixture.inputs())

    def test_cross_capture_matching_log_omission_cannot_survive_rehash(self):
        fixture = RightsJoinFixture(); extra = fixture.cross_log()
        with self.assertRaisesRegex(MuseumError, "omitted matching retained receipt log"): join.reconcile(fixture.inputs())
        fixture.queries["floor"]["result"].append(deepcopy(extra))
        self.assertEqual(join.reconcile(fixture.inputs())["counts"]["receiptLogs"], "3")
        fixture.queries["floor"]["result"][0]["data"] = "0x01"
        with self.assertRaisesRegex(MuseumError, "differs from retained receipt"): join.reconcile(fixture.inputs())

    def test_range_and_positional_filter_nonoverlap_preserves_qualified_scope(self):
        fixture = RightsJoinFixture(); fixture.cross_log(); fixture.queries["floor"]["params"][0]["fromBlock"] = "0x15"
        join.reconcile(fixture.inputs())
        fixture.queries["floor"]["params"][0]["fromBlock"] = "0x3d"
        with self.assertRaisesRegex(MuseumError, "outside range/filter"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.cross_log()["topics"] = [H("different")]
        join.reconcile(fixture.inputs())
        fixture.queries["floor"]["params"][0]["topics"] = [None]
        with self.assertRaisesRegex(MuseumError, "omitted matching"): join.reconcile(fixture.inputs())
        fixture = RightsJoinFixture(); fixture.queries["floor"]["params"][0]["toBlock"] = "0x65"
        with self.assertRaisesRegex(MuseumError, "outside source range"): join.reconcile(fixture.inputs())

    def test_limited_page_children_must_close_in_the_same_original_capture(self):
        fixture = RightsJoinFixture(); parent = deepcopy(fixture.queries["rights"])
        left, right = deepcopy(parent), deepcopy(parent)
        left["params"][0]["toBlock"] = "0x32"
        right["params"][0]["fromBlock"] = "0x33"; right["result"] = []
        parent.pop("result"); parent["limit"] = "range_limit"
        fixture.queries["rights"] = parent; fixture.extra["rights"].extend((left, right))
        self.assertEqual(join.reconcile(fixture.inputs())["counts"]["limitedQueries"], "1")
        fixture.extra["rights"].remove(right); fixture.extra["floor"].append(right)
        with self.assertRaisesRegex(MuseumError, "missing exact split child"): join.reconcile(fixture.inputs())
        fixture.extra["floor"].clear(); fixture.extra["rights"].append(right)
        right["params"][0]["fromBlock"] = "0x32"
        with self.assertRaisesRegex(MuseumError, "missing exact split child"): join.reconcile(fixture.inputs())

    def test_duplicate_query_occurrences_and_combined_bounds_fail_closed(self):
        fixture = RightsJoinFixture(); fixture.queries["floor"]["result"] *= 1000
        with self.assertRaisesRegex(MuseumError, "duplicate query hit"): join.reconcile(fixture.inputs())
        inputs = RightsJoinFixture().inputs()
        for key in ("MAX_INPUT_BYTES", "MAX_ROWS"):
            with patch.object(join, key, 1), self.assertRaises(MuseumError): join.reconcile(inputs)
        for key in ("MAX_HEADERS", "MAX_RECEIPTS", "MAX_LOGS", "MAX_TRANSACTIONS", "MAX_QUERIES", "MAX_MATCH_CHECKS"):
            with patch.object(shared, key, 1), self.assertRaises(MuseumError): join.reconcile(inputs)


if __name__ == "__main__": unittest.main()
