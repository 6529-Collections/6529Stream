"""Synthetic numeric-range and receipt-correspondence controls; no chain capture."""
import copy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from . import public_chain_history as history
from .public_history_rpc import PublicLimitError, PublicRecordingReader, PublicReplayTransport
from .test_public_history_rpc import A, H


class PublicHistoryFixture:
    def __init__(self, end=9000000):
        self.anchor = {"chainId": "11155111", "blockNumber": str(end), "blockHash": H(100000000+end),
            "stateRoot": H(200000000+end), "timestamp": str(1700000000+end)}
        self.filters = [{"address": A(1), "topics": [H(11)]}]
        self.blocks, self.receipts, self.logs, self.calls = {}, {}, [], []
        self.header(end)

    def header(self, number):
        digest = H(100000000+number)
        if digest not in self.blocks:
            self.blocks[digest] = {"hash": digest, "number": hex(number), "stateRoot": H(200000000+number),
                "timestamp": hex(1700000000+number), "parentHash": H(99999999+number) if number else H(0), "transactions": []}
        return self.blocks[digest]

    def add(self, block=20, *, address=A(1), topics=None, same_transaction=False):
        header = self.header(block)
        if same_transaction:
            tx = header["transactions"][-1]; receipt = self.receipts[tx]
        else:
            tx = H(300000000+len(self.receipts))
            receipt = {"transactionHash": tx, "blockHash": header["hash"], "blockNumber": hex(block),
                "transactionIndex": hex(len(header["transactions"])), "status": "0x1", "logs": []}
            header["transactions"].append(tx); self.receipts[tx] = receipt
        index = sum(len(r["logs"]) for r in self.receipts.values() if r["blockHash"] == header["hash"])
        log = {key: receipt[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")}
        log.update(address=address, topics=topics or [H(11)], data="0x", logIndex=hex(index), removed=False)
        receipt["logs"].append(log); self.logs.append(log)
        return log

    def request(self, method, params):
        self.calls.append((method, copy.deepcopy(params)))
        if method == "eth_chainId": return hex(int(self.anchor["chainId"]))
        if method == "eth_getBlockByHash": return copy.deepcopy(self.blocks[params[0]])
        if method == "eth_getBlockByNumber": return copy.deepcopy(self.header(int(params[0], 16)))
        if method == "eth_getTransactionReceipt": return copy.deepcopy(self.receipts[params[0]])
        if method == "eth_getLogs":
            f = params[0]; lower, upper = int(f["fromBlock"], 16), int(f["toBlock"], 16)
            return copy.deepcopy([row for row in self.logs if lower <= int(row["blockNumber"], 16) <= upper
                and history._matches(row, f)])
        raise AssertionError(method)

    def scan(self):
        self.reader = PublicRecordingReader(self, self.anchor["blockHash"])
        return history.scan_public_history(self.reader, self.anchor, filters=self.filters)


class PublicChainHistoryTests(unittest.TestCase):
    def test_large_empty_range_uses_few_queries_and_explicit_trust(self):
        f = PublicHistoryFixture(); result = f.scan(); coverage = result["coverage"]
        self.assertEqual(coverage["startBlock"], "0")
        self.assertEqual(coverage["endBlock"], "9000000")
        self.assertEqual(coverage["queries"], "181")
        self.assertEqual(coverage["touchedBlocks"], "1")
        self.assertEqual(coverage["receipts"], "0")
        self.assertTrue(coverage["providerLogCompletenessTrusted"])
        self.assertTrue(coverage["canonicalMappingTrusted"])
        self.assertFalse(coverage["genesisWalk"])
        self.assertFalse(coverage["allBlockReceipts"])
        self.assertFalse(coverage["ancestryProven"])
        self.assertEqual(result["logs"], [])
        self.assertEqual([p[0] for m, p in f.calls if m == "eth_getBlockByNumber"], [hex(9000000)] * 2)

    def test_receipt_join_overlap_dedup_sort_and_exact_offline_replay(self):
        f = PublicHistoryFixture(end=100)
        later = f.add(80); earlier = f.add(20)
        f.filters.append({"address": A(1), "topics": [[H(11), H(12)]]})
        result = f.scan()
        self.assertEqual([row["blockNumber"] for row in result["logs"]], ["0x14", "0x50"])
        self.assertEqual(result["coverage"]["receipts"], "2")
        self.assertEqual(result["coverage"]["logs"], "2")
        raw = f.reader.transcript(); replay = PublicReplayTransport(raw, keccak256(raw))
        reader = PublicRecordingReader(replay, f.anchor["blockHash"])
        with patch("socket.socket", side_effect=AssertionError("no network")):
            again = history.scan_public_history(reader, f.anchor, filters=f.filters); replay.finish()
        self.assertEqual(again, result); self.assertEqual(reader.transcript(), raw)

    def test_limit_splits_are_exact_ascending_partition_and_replay(self):
        f = PublicHistoryFixture(end=49999); f.add(100); original = f.request
        def limited(method, params):
            if method == "eth_getLogs" and int(params[0]["toBlock"], 16) - int(params[0]["fromBlock"], 16) + 1 > 25000:
                f.calls.append((method, copy.deepcopy(params))); raise PublicLimitError("range_limit")
            return original(method, params)
        f.request = limited; result = f.scan()
        self.assertEqual([(r["fromBlock"], r["toBlock"]) for r in result["coverage"]["queryRanges"]],
            [("0", "49999"), ("0", "24999"), ("25000", "49999")])
        self.assertEqual(result["coverage"]["pages"], "2")
        raw = f.reader.transcript(); replay = PublicReplayTransport(raw, keccak256(raw))
        again = history.scan_public_history(PublicRecordingReader(replay, f.anchor["blockHash"]), f.anchor, filters=f.filters)
        replay.finish(); self.assertEqual(again, result)
        for delta in (-1, 1):
            packet = loads(raw); query = next(row for row in packet["calls"] if row["method"] == "eth_getLogs" and "result" in row)
            query["params"][0]["toBlock"] = hex(24999 + delta)
            mutated = dumps(packet); replay = PublicReplayTransport(mutated, keccak256(mutated))
            with self.subTest(gap_or_overlap=delta), self.assertRaisesRegex(MuseumError, "order mismatch"):
                history.scan_public_history(PublicRecordingReader(replay, f.anchor["blockHash"]), f.anchor, filters=f.filters)

    def test_saturation_splits_and_parent_disclosed_hits_cannot_disappear(self):
        f = PublicHistoryFixture(end=29); f.add(10); f.add(20)
        with patch.object(history, "SATURATION_LOGS", 2): result = f.scan()
        self.assertEqual(result["coverage"]["splits"], "1")
        f = PublicHistoryFixture(end=29); f.add(10); f.add(20); original = f.request
        def omitted(method, params):
            rows = original(method, params)
            if method == "eth_getLogs" and params[0]["fromBlock"] == "0xf": return []
            return rows
        f.request = omitted
        with patch.object(history, "SATURATION_LOGS", 2), self.assertRaisesRegex(MuseumError, "omitted disclosed hit"): f.scan()

    def test_overlapping_filter_cannot_rescue_omission_from_split_children(self):
        for reverse in (False, True):
            f = PublicHistoryFixture(end=29); f.add(10); f.add(20)
            f.filters.append({"address": A(1), "topics": [[H(11), H(12)]]})
            if reverse: f.filters.reverse()
            original = f.request
            def omitted(method, params):
                rows = original(method, params)
                if method == "eth_getLogs" and params[0]["topics"] == [H(11)] and params[0]["fromBlock"] == "0xf": return []
                return rows
            f.request = omitted
            with self.subTest(overlap_first=reverse), patch.object(history, "SATURATION_LOGS", 2), self.assertRaisesRegex(MuseumError, "filter split response omitted disclosed hit"):
                f.scan()

    def test_single_block_limit_saturation_and_initial_query_bound(self):
        f = PublicHistoryFixture(end=0)
        original = f.request
        f.request = lambda m, p: (_ for _ in ()).throw(PublicLimitError("response_size")) if m == "eth_getLogs" else original(m, p)
        with self.assertRaisesRegex(MuseumError, "single block"): f.scan()
        f = PublicHistoryFixture(end=0); f.add(0)
        with patch.object(history, "SATURATION_LOGS", 1), self.assertRaisesRegex(MuseumError, "single block"): f.scan()
        f = PublicHistoryFixture(end=history.MAX_QUERIES * history.WINDOW_BLOCKS)
        with self.assertRaisesRegex(MuseumError, "initial query bound"): f.scan()
        self.assertEqual(f.calls, [])

    def test_returned_logs_must_match_every_filter_range_and_wire_field(self):
        for field, value in (("address", A(2)), ("topics", [H(99)]), ("blockNumber", "0x100"),
            ("removed", True), ("logIndex", "0x00")):
            f = PublicHistoryFixture(end=100); f.add(20); original = f.request
            def changed(method, params):
                result = original(method, params)
                if method == "eth_getLogs": result[0][field] = value
                return result
            f.request = changed
            with self.subTest(field=field), self.assertRaises(MuseumError): f.scan()

    def test_full_retained_receipt_detects_omitted_matching_sibling(self):
        f = PublicHistoryFixture(end=100); f.add(20); f.add(20, same_transaction=True); original = f.request
        f.request = lambda m, p: original(m, p)[:1] if m == "eth_getLogs" else original(m, p)
        with self.assertRaisesRegex(MuseumError, "matching logs differ"): f.scan()

    def test_every_receipt_log_checked_including_unmatched_logs(self):
        for field, value in (("removed", True), ("transactionIndex", "0x1"), ("logIndex", "0x4")):
            f = PublicHistoryFixture(end=100); f.add(20); extra = f.add(20, address=A(2), same_transaction=True)
            extra[field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError): f.scan()

    def test_receipt_status_coordinates_and_header_transaction_slot(self):
        for kind in ("reverted", "coordinates", "slot"):
            f = PublicHistoryFixture(end=100); row = f.add(20); receipt = f.receipts[row["transactionHash"]]
            if kind == "reverted": receipt["status"] = "0x0"
            elif kind == "coordinates": receipt["transactionIndex"] = "0x1"
            else: f.header(20)["transactions"][0] = H(999)
            with self.subTest(kind=kind), self.assertRaises(MuseumError): f.scan()

    def test_sparse_receipts_allow_prior_log_offset_but_not_overlapping_positions(self):
        f = PublicHistoryFixture(end=100); unrelated = f.add(20, address=A(2)); selected = f.add(20)
        self.assertEqual(selected["logIndex"], "0x1")
        self.assertEqual(f.scan()["coverage"]["receipts"], "1")
        f = PublicHistoryFixture(end=100); f.add(20); second = f.add(20); second["logIndex"] = "0x0"
        with self.assertRaisesRegex(MuseumError, "duplicate block log position"): f.scan()

    def test_header_mapping_reorg_and_repeated_query_conflicts(self):
        f = PublicHistoryFixture(end=100); f.add(20); original = f.request
        def fork(method, params):
            result = original(method, params)
            if method == "eth_getBlockByNumber" and params[0] == "0x14": result["parentHash"] = H(999)
            return result
        f.request = fork
        with self.assertRaisesRegex(MuseumError, "canonical header differs"): f.scan()
        f = PublicHistoryFixture(end=100); original = f.request; count = 0
        def final_changed(method, params):
            nonlocal count
            result = original(method, params)
            if method == "eth_getBlockByHash":
                count += 1
                if count == 2: result["transactions"] = [H(999)]
            return result
        f.request = final_changed
        with self.assertRaisesRegex(MuseumError, "repeated RPC result differs"): f.scan()

    def test_adjacent_touched_headers_must_link_and_times_cannot_regress(self):
        for kind in ("parent", "adjacent_time", "sparse_time"):
            f = PublicHistoryFixture(end=100)
            f.add(20); later = 40 if kind == "sparse_time" else 21; f.add(later)
            # Shared header mutation affects both by-hash and by-number answers.
            if kind == "parent": f.header(later)["parentHash"] = H(999)
            else: f.header(later)["timestamp"] = hex(1700000019)
            expected = "adjacent header parent" if kind == "parent" else "touched header time regresses"
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError, expected): f.scan()

    def test_valid_sparse_headers_do_not_infer_missing_ancestry(self):
        f = PublicHistoryFixture(end=100); f.add(20); f.add(40)
        f.header(40)["parentHash"] = H(999)
        result = f.scan()
        self.assertEqual(result["coverage"]["touchedBlocks"], "3")
        self.assertFalse(result["coverage"]["ancestryProven"])
        self.assertEqual(len([1 for m, _ in f.calls if m == "eth_getBlockByHash"]), 4)

    def test_bound_failures_never_return_partial_history(self):
        for bound, maximum, expected in (("MAX_LOGS", 1, "disclosed log bound"),
            ("MAX_RECEIPTS", 1, "receipt bound"), ("MAX_TOUCHED_BLOCKS", 1, "touched block bound")):
            f = PublicHistoryFixture(end=100); f.add(20); f.add(30)
            with self.subTest(bound=bound), patch.object(history, bound, maximum), self.assertRaisesRegex(MuseumError, expected): f.scan()
        f = PublicHistoryFixture(end=100); original = f.request
        f.request = lambda m, p: (_ for _ in ()).throw(PublicLimitError("range_limit")) if m == "eth_getLogs" else original(m, p)
        with patch.object(history, "MAX_QUERIES", 2), self.assertRaisesRegex(MuseumError, "query bound"): f.scan()

    def test_positional_or_null_filters_and_duplicate_disclosure_consistency(self):
        f = PublicHistoryFixture(end=100); f.add(20, topics=[H(11), H(4), H(5)])
        f.filters = [{"address": A(1), "topics": [[H(11), H(12)], None, H(5)]}]
        self.assertEqual(len(f.scan()["logs"]), 1)
        f.filters.append({"address": A(1), "topics": [H(11)]}); original = f.request
        def conflict(method, params):
            result = original(method, params)
            if method == "eth_getLogs" and params[0]["topics"] == [H(11)]: result[0]["data"] = "0x01"
            return result
        f.request = conflict
        with self.assertRaisesRegex(MuseumError, "conflicting disclosed hit"): f.scan()


if __name__ == "__main__": unittest.main()
