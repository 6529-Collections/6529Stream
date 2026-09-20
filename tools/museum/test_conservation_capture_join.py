"""Independent small supplied-observation controls; no native-source proof."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import conservation_capture_join as join
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from . import public_history_rpc as rpc


def H(label): return schema_id(str(label))
def A(number): return "0x" + number.to_bytes(20, "big").hex()


class JoinFixture:
    def __init__(self, *, same_block=False):
        self.code = b"synthetic-core-runtime"
        self.common = {"chainId": "11155111", "core": A(1), "collectionId": "7",
            "blockHash": H("block100"), "blockNumber": "100", "timestamp": "1100",
            "stateRoot": H("root100"), "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment")}
        self.blocks, self.receipts, self.queries = {}, {}, {}
        self.header(100)
        self.anchors = {}
        for index, (name, number) in enumerate(zip(join.NAMES, (20, 20 if same_block else 21, 60))):
            header = self.header(number); tx = H("tx-" + name)
            tx_index = len(header["transactions"]); header["transactions"].append(tx)
            log_index = sum(len(r["logs"]) for r in self.receipts.values() if r["blockHash"] == header["hash"])
            coordinates = {"transactionHash": tx, "blockHash": header["hash"],
                "blockNumber": hex(number), "transactionIndex": hex(tx_index)}
            log = {**coordinates, "address": A(10 + index), "topics": [H("topic-" + name)],
                "data": "0x", "removed": False, "logIndex": hex(log_index)}
            self.receipts[name] = {**coordinates, "status": "0x1", "logs": [log]}
            self.queries[name] = {"method": "eth_getLogs", "params": [{"address": log["address"],
                "topics": list(log["topics"]), "fromBlock": "0x0", "toBlock": "0x64"}], "result": [deepcopy(log)]}
            self.anchors[name] = {**self.common, "profile": join.SOURCE_PROFILES[name]}
            if name == "tier": self.anchors[name]["coreRuntimeHash"] = keccak256(self.code)
            else:
                self.anchors[name]["codePins"] = [{"address": A(1), "runtimeHash": keccak256(self.code)}]
                if name == "selection": self.anchors[name]["tokenId"] = "41"
        self.extra = {name: [] for name in join.NAMES}

    def header(self, number):
        if number not in self.blocks:
            self.blocks[number] = {"hash": H("block" + str(number)), "number": hex(number),
                "parentHash": H("block" + str(number - 1)) if number else "0x" + "00" * 32,
                "stateRoot": H("root" + str(number)), "timestamp": hex(1000 + number), "transactions": []}
        return self.blocks[number]

    def inputs(self):
        inputs = {}
        for name in join.NAMES:
            receipt = self.receipts[name]
            calls = [{"method": "eth_chainId", "params": [], "result": hex(int(self.common["chainId"]))},
                {"method": "eth_getCode", "params": [A(1), {"blockHash": self.common["blockHash"], "requireCanonical": True}],
                    "result": "0x" + self.code.hex()}]
            for number in sorted({100, int(receipt["blockNumber"], 16)}):
                header = self.blocks[number]
                calls.extend([{"method": "eth_getBlockByHash", "params": [header["hash"], False], "result": header},
                    {"method": "eth_getBlockByNumber", "params": [hex(number), False], "result": header}])
            calls.extend([{"method": "eth_getTransactionReceipt", "params": [receipt["transactionHash"]], "result": receipt},
                self.queries[name], *self.extra[name]])
            inputs[name] = {"anchor": dumps(self.anchors[name]), "transcript": dumps({"version": rpc.VERSION,
                "profile": rpc.PROFILE, "calls": calls})}
        return inputs

    def cross_log(self):
        log = deepcopy(self.receipts["tier"]["logs"][0])
        log.update(address=self.queries["selection"]["params"][0]["address"],
            topics=self.queries["selection"]["params"][0]["topics"], logIndex="0x1")
        self.receipts["tier"]["logs"].append(log)
        return log


def edit_rows(inputs, name, callback):
    packet = loads(inputs[name]["transcript"], maximum=rpc.MAX_TRANSCRIPT)
    callback(packet["calls"])
    inputs[name]["transcript"] = dumps(packet)


class ConservationCaptureJoinTests(unittest.TestCase):
    def test_valid_three_capture_union_is_offline_deterministic_and_qualified(self):
        fixture = JoinFixture(); inputs = fixture.inputs()
        with patch("socket.socket", side_effect=AssertionError("offline only")), \
                patch("urllib.request.build_opener", side_effect=AssertionError("offline only")):
            result = join.reconcile(inputs)
            self.assertEqual(join.reconcile(dict(reversed(list(inputs.items())))), result)
        self.assertEqual(result["sourceState"], fixture.common)
        self.assertEqual(result["coreRuntimeHash"], keccak256(fixture.code))
        self.assertEqual(result["counts"]["headers"], "4")
        self.assertEqual(result["counts"]["receipts"], "3")
        self.assertEqual(result["counts"]["receiptLogs"], "3")
        self.assertTrue(result["claims"]["capturesAlreadyVerifiedRequired"])
        for key in ("sourceProvenanceAuthenticated", "unobservedLogCompletenessProven", "ancestryProven",
                "receiptTrieProven", "consensusVerified", "actualChainAcceptance", "nativeSemanticsReverified"):
            self.assertFalse(result["claims"][key])
        self.assertLess(len(dumps(result)), 8192)

    def test_closed_inputs_canonical_bytes_and_common_anchor_identity(self):
        for change in (lambda v: v.pop("floor"), lambda v: v.update(extra=v["tier"]),
                lambda v: v["tier"].update(extra=b"{}"), lambda v: v["tier"].update(anchor="not bytes"),
                lambda v: v["tier"].update(anchor=v["tier"]["anchor"] + b"\n")):
            inputs = JoinFixture().inputs(); change(inputs)
            with self.assertRaises(MuseumError): join.reconcile(inputs)
        for key in join.COMMON:
            fixture = JoinFixture(); fixture.anchors["selection"][key] = "different"
            with self.subTest(key=key), self.assertRaisesRegex(MuseumError, "common anchor"):
                join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.anchors["floor"]["profile"] = join.SOURCE_PROFILES["tier"]
        with self.assertRaisesRegex(MuseumError, "shape/profile"): join.reconcile(fixture.inputs())

    def test_core_and_overlapping_dependency_runtime_pins_must_agree(self):
        fixture = JoinFixture(); fixture.anchors["floor"]["codePins"][0]["runtimeHash"] = H("wrong")
        with self.assertRaisesRegex(MuseumError, "runtime pin differs"): join.reconcile(fixture.inputs())
        fixture = JoinFixture()
        for name in ("selection", "floor"):
            fixture.anchors[name]["codePins"].append({"address": A(2), "runtimeHash": H(name)})
        with self.assertRaisesRegex(MuseumError, "runtime pin differs"): join.reconcile(fixture.inputs())
        inputs = JoinFixture().inputs()
        for name in join.NAMES:
            edit_rows(inputs, name, lambda rows: rows[1].update(result="0x01"))
        with self.assertRaisesRegex(MuseumError, "observed runtime"): join.reconcile(inputs)

    def test_repeated_rpc_results_and_sanitized_limit_outcomes_are_exact(self):
        fixture = JoinFixture()
        call = {"method": "eth_call", "params": [{"to": A(8), "data": "0x1234", "gas": "0x1"},
            {"blockHash": fixture.common["blockHash"], "requireCanonical": True}], "result": "0x01"}
        fixture.extra["tier"].append(call); fixture.extra["floor"].append(deepcopy(call))
        join.reconcile(fixture.inputs())
        fixture.extra["floor"][0]["result"] = "0x02"
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())
        for outcome in ({"limit": "response_size"}, {"result": []}):
            fixture = JoinFixture()
            params = [{"address": A(99), "topics": [], "fromBlock": "0x0", "toBlock": "0x64"}]
            fixture.extra["tier"].append({"method": "eth_getLogs", "params": params, "limit": "range_limit"})
            fixture.extra["floor"].append({"method": "eth_getLogs", "params": params, **outcome})
            with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())

    def test_header_hash_height_request_and_source_observations_cannot_conflict(self):
        inputs = JoinFixture().inputs()
        def changed(rows):
            for row in rows:
                if row["method"] == "eth_getBlockByNumber" and row["params"][0] == "0x64":
                    row["result"]["transactions"] = [H("invented")]
        edit_rows(inputs, "floor", changed)
        with self.assertRaises(MuseumError): join.reconcile(inputs)
        fixture = JoinFixture(); fixture.blocks[21]["number"] = "0x14"
        with self.assertRaisesRegex(MuseumError, "height|request"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.blocks[100]["stateRoot"] = H("wrong")
        with self.assertRaisesRegex(MuseumError, "source header differs"): join.reconcile(fixture.inputs())
        inputs = JoinFixture().inputs()
        edit_rows(inputs, "selection", lambda rows: rows.__setitem__(slice(None),
            [r for r in rows if r["method"] != "eth_getBlockByNumber" or r["params"][0] != "0x15"]))
        with self.assertRaisesRegex(MuseumError, "reciprocal header"): join.reconcile(inputs)
        inputs = JoinFixture().inputs()
        def typed_difference(rows):
            for row in rows:
                if row["method"] in ("eth_getBlockByHash", "eth_getBlockByNumber") and row["result"]["number"] == "0x14":
                    row["result"]["extra"] = True if row["method"] == "eth_getBlockByHash" else 1
        edit_rows(inputs, "tier", typed_difference)
        with self.assertRaisesRegex(MuseumError, "header hash observation"): join.reconcile(inputs)

    def test_header_times_adjacent_parents_and_sparse_gap_rules(self):
        fixture = JoinFixture(); fixture.blocks[21]["timestamp"] = hex(1019)
        with self.assertRaisesRegex(MuseumError, "time regresses"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.blocks[21]["parentHash"] = H("wrong-parent")
        with self.assertRaisesRegex(MuseumError, "adjacent parent"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.blocks[60]["parentHash"] = H("unobserved-parent")
        self.assertFalse(join.reconcile(fixture.inputs())["claims"]["ancestryProven"])

    def test_transaction_placement_and_full_repeated_receipts_are_exact(self):
        fixture = JoinFixture(); fixture.blocks[60]["transactions"].append(fixture.blocks[20]["transactions"][0])
        with self.assertRaisesRegex(MuseumError, "multiple blocks"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.receipts["floor"]["transactionIndex"] = "0x1"
        with self.assertRaisesRegex(MuseumError, "transaction slot"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); repeated = deepcopy(fixture.receipts["tier"]); repeated["extra"] = "contradiction"
        fixture.extra["floor"].append({"method": "eth_getTransactionReceipt",
            "params": [repeated["transactionHash"]], "result": repeated})
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.receipts["tier"]["status"] = "0x0"
        with self.assertRaisesRegex(MuseumError, "successful original receipt"): join.reconcile(fixture.inputs())

    def test_full_receipt_log_coordinates_order_collision_and_adjacency(self):
        fixture = JoinFixture(same_block=True); join.reconcile(fixture.inputs())
        for index, message in (("0x0", "duplicate block log"), ("0x2", "adjacent receipt log gap")):
            fixture = JoinFixture(same_block=True)
            fixture.receipts["selection"]["logs"][0]["logIndex"] = index
            fixture.queries["selection"]["result"][0]["logIndex"] = index
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError, message): join.reconcile(fixture.inputs())
        fixture = JoinFixture(same_block=True)
        for name, index in (("tier", "0x1"), ("selection", "0x0")):
            fixture.receipts[name]["logs"][0]["logIndex"] = index
            fixture.queries[name]["result"][0]["logIndex"] = index
        with self.assertRaisesRegex(MuseumError, "transaction/log order"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.receipts["tier"]["logs"][0]["transactionHash"] = H("wrong")
        with self.assertRaisesRegex(MuseumError, "log coordinates"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); extra = fixture.cross_log(); extra["logIndex"] = "0x2"
        with self.assertRaisesRegex(MuseumError, "log order/gap"): join.reconcile(fixture.inputs())

    def test_cross_capture_matching_log_omission_and_exact_positive_union(self):
        fixture = JoinFixture(); extra = fixture.cross_log()
        with self.assertRaisesRegex(MuseumError, "omitted matching retained receipt log"): join.reconcile(fixture.inputs())
        fixture.queries["selection"]["result"].append(deepcopy(extra))
        self.assertEqual(join.reconcile(fixture.inputs())["counts"]["receiptLogs"], "4")

    def test_query_range_and_positional_filter_boundaries_do_not_invent_hits(self):
        fixture = JoinFixture(); fixture.cross_log()
        fixture.queries["selection"]["params"][0]["fromBlock"] = "0x15"
        join.reconcile(fixture.inputs())  # The other retained log is at height20, outside this page.
        fixture.queries["selection"]["params"][0]["fromBlock"] = "0x16"
        with self.assertRaisesRegex(MuseumError, "outside range/filter"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.queries["floor"]["params"][0]["toBlock"] = "0x65"
        with self.assertRaisesRegex(MuseumError, "outside source range"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.cross_log()["topics"] = [H("different-topic")]
        join.reconcile(fixture.inputs())
        fixture.queries["selection"]["params"][0]["topics"] = [None]
        with self.assertRaisesRegex(MuseumError, "omitted matching"): join.reconcile(fixture.inputs())

    def test_query_hit_without_exact_retained_receipt_fails(self):
        fixture = JoinFixture(); fixture.queries["floor"]["result"][0]["data"] = "0x01"
        with self.assertRaisesRegex(MuseumError, "differs from retained receipt"): join.reconcile(fixture.inputs())
        fixture = JoinFixture(); fixture.queries["floor"]["result"][0]["removed"] = True
        with self.assertRaisesRegex(MuseumError, "removed/malformed log"): join.reconcile(fixture.inputs())

    def test_split_limits_saturation_children_and_cross_input_rescue(self):
        for limited in (False, True):
            fixture = JoinFixture()
            second = fixture.receipts["floor"]["logs"][0]
            second["address"] = fixture.queries["tier"]["params"][0]["address"]
            fixture.queries["floor"]["params"][0]["address"] = second["address"]
            fixture.queries["floor"]["result"] = [deepcopy(second)]
            fixture.queries["tier"]["params"][0]["topics"] = [[
                fixture.receipts["tier"]["logs"][0]["topics"][0], second["topics"][0]]]
            fixture.queries["tier"]["result"].append(deepcopy(second))
            original = deepcopy(fixture.queries["tier"])
            child1 = deepcopy(original); child1["params"][0]["toBlock"] = "0x32"; child1["result"] = original["result"][:1]
            child2 = deepcopy(original); child2["params"][0]["fromBlock"] = "0x33"; child2["result"] = original["result"][1:]
            if limited:
                fixture.queries["tier"].pop("result"); fixture.queries["tier"]["limit"] = "range_limit"
            fixture.extra["tier"].extend([child1, child2])
            with patch.object(join.history, "SATURATION_LOGS", 2): result = join.reconcile(fixture.inputs())
            self.assertEqual(result["counts"]["limitedQueries" if limited else "saturatedQueries"], "1")
            fixture.extra["tier"].remove(child2); fixture.extra["floor"].append(child2)
            with patch.object(join.history, "SATURATION_LOGS", 2), self.assertRaisesRegex(MuseumError, "missing exact split child"):
                join.reconcile(fixture.inputs())
            fixture.extra["floor"].remove(child2); fixture.extra["tier"].append(child2)
            child1["params"][0]["toBlock"] = "0x31"
            with patch.object(join.history, "SATURATION_LOGS", 2), self.assertRaisesRegex(MuseumError, "missing exact split child"):
                join.reconcile(fixture.inputs())

    def test_repeated_occurrence_in_one_query_cannot_manufacture_saturation(self):
        for count in (2, 1000):
            fixture = JoinFixture(); fixture.queries["tier"]["result"] *= count
            with self.subTest(count=count), self.assertRaisesRegex(MuseumError, "duplicate query hit"):
                join.reconcile(fixture.inputs())

    def test_aggregate_bounds_fail_closed_without_truncation(self):
        inputs = JoinFixture().inputs()
        for key, value, message in (("MAX_INPUT_BYTES", 1, "input byte bound"), ("MAX_ROWS", 1, "row bound"),
                ("MAX_HEADERS", 1, "header bound"), ("MAX_RECEIPTS", 1, "receipt bound"),
                ("MAX_TRANSACTIONS", 1, "transaction placement bound"), ("MAX_LOGS", 1, "log union bound"),
                ("MAX_QUERIES", 1, "query bound"), ("MAX_MATCH_CHECKS", 1, "comparison bound")):
            with self.subTest(bound=key), patch.object(join, key, value), self.assertRaisesRegex(MuseumError, message):
                join.reconcile(inputs)


if __name__ == "__main__": unittest.main()
