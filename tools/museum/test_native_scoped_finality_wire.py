"""Original scoped commitments and chronology; no native execution claim."""
from copy import deepcopy
import unittest

from . import native_scoped_finality_wire as wire
from . import scoped_static_content_wire as content
from .canonical import MuseumError, hex_bytes
from .chain_abi import decode, encode
from .scoped_static_finality_fixture import ScopedStaticFinalityFixture
from .test_scoped_static_content_wire import seal_roots


class ScopedWireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixtures = {scope: ScopedStaticFinalityFixture(scope_type=scope) for scope in (1, 2, 3)}

    def test_all_original_scopes(self):
        for scope, fixture in self.fixtures.items():
            with self.subTest(scope=scope):
                result = wire.validate_bundle(fixture.scoped_bundle, fixture.scoped_context, fixture.scoped_graph)
                self.assertEqual(result["historicalCoreFacts"]["status"], "hash_only")
                self.assertIsNone(result["historicalCoreFacts"]["preimage"])
                self.assertFalse(result["historicalExecutionReenacted"])
                wire.validate_event_join(fixture.scoped_bundle, fixture.scoped_context, fixture.scoped_graph, fixture.scoped_events)
                report = wire.validate_governance(fixture.scoped_bundle, fixture.scoped_context, fixture.scoped_graph,
                    fixture.scoped_normalized_transactions, fixture.scoped_events)
                self.assertEqual(report["status"], "reconstructed")
                self.assertFalse(report["claims"]["completeAuthority"])

    def test_later_burn_preserves_originals(self):
        fresh, burned = self.fixtures[1], ScopedStaticFinalityFixture(scope_type=1, burned=True)
        self.assertEqual(fresh.scoped_bundle["finality"], burned.scoped_bundle["finality"])
        self.assertEqual(fresh.scoped_bundle["content"], burned.scoped_bundle["content"])
        self.assertEqual(fresh.scoped_bundle["membership"]["facts"], burned.scoped_bundle["membership"]["facts"])
        wire.validate_bundle(burned.scoped_bundle, burned.scoped_context, burned.scoped_graph)

    def test_wrong_scope_and_collection_are_not_cast(self):
        f = self.fixtures[2]
        for kind in ("0", "1", "3", "4"):
            b = deepcopy(f.scoped_bundle); b["scope"][0] = kind
            with self.subTest(kind=kind), self.assertRaises(MuseumError):
                wire.validate_bundle(b, f.scoped_context, f.scoped_graph)

    def test_required_original_event_missing(self):
        f = self.fixtures[1]
        for index in (0, len(f.scoped_events)//2, len(f.scoped_events)-1):
            rows = deepcopy(f.scoped_events); rows.pop(index)
            with self.subTest(index=index), self.assertRaises(MuseumError):
                wire.validate_event_join(f.scoped_bundle, f.scoped_context, f.scoped_graph, rows)

    def test_incomplete_or_oversized_output_progress(self):
        f = self.fixtures[3]
        for start, end in ((0, 30), (1, 16), (0, 15)):
            rows = deepcopy(f.scoped_events)
            event = next(r["log"] for r in rows if r["log"]["topics"][0] == content.EVENTS["manifestAdvanced"])
            event["data"] = "0x" + encode(("uint16", "uint64", "uint64"), (1, start, end)).hex()
            with self.subTest(start=start,end=end), self.assertRaises(MuseumError):
                wire.validate_event_join(f.scoped_bundle, f.scoped_context, f.scoped_graph, rows)

    def _later_root(self, *, before_finality):
        f = ScopedStaticFinalityFixture(scope_type=2)
        b, x, g = f.scoped_bundle, f.scoped_context, f.scoped_graph
        old = b["content"]["roots"]["selectedRootHash"]
        row = deepcopy(b["content"]["roots"]["history"][-1])
        block = 3 if before_finality else 5
        from .test_current_rights_source import H
        row["record"][17] = str(int(f.blocks[H(200+block)]["timestamp"], 16))
        b["content"]["roots"]["history"].append(row)
        statement = deepcopy(f.scoped_statement)
        seal_roots(b["content"], x, g, statement)
        b["content"]["roots"]["selectedRootHash"] = old
        descriptor = [r for r in wire.expected_events(b, x, g) if r["kind"] == "root_published"][-1]
        log = f._raw_event(block, descriptor, f.blocks[H(200+block)]["transactions"][-1])
        log = {k:v for k,v in log.items() if k != "removed"}
        rows = deepcopy(f.scoped_events) + [{"log": log, "timestamp": row["record"][17]}]
        from .chain_rpc import quantity
        rows.sort(key=lambda r: tuple(quantity(r["log"][k]) for k in ("blockNumber", "transactionIndex", "logIndex")))
        return f, rows

    def test_original_frozen_route_cannot_publish_later_same_scope_root(self):
        f, rows = self._later_root(before_finality=False)
        result = wire.validate_bundle(f.scoped_bundle, f.scoped_context, f.scoped_graph)
        self.assertEqual(result["content"]["selectedRootStatus"], "later_superseded")
        # Pure retained commitments are consistent, but the original Registry's
        # one-way scoped freeze makes publication on that same route impossible.
        with self.assertRaisesRegex(MuseumError, "chronology"):
            wire.validate_event_join(f.scoped_bundle, f.scoped_context, f.scoped_graph, rows)

    def test_intervening_root_before_finality_rejects(self):
        f, rows = self._later_root(before_finality=True)
        with self.assertRaisesRegex(MuseumError, "latest before finality"):
            wire.validate_event_join(f.scoped_bundle, f.scoped_context, f.scoped_graph, rows)

    def test_governance_wrong_actual_call_transition(self):
        f = self.fixtures[1]
        transactions = deepcopy(f.scoped_normalized_transactions)
        raw = hex_bytes(transactions["execution"]["input"])
        action, calls, datas = decode(wire.governance.EXECUTE_BATCH, raw[4:])
        changed = list(calls[0]); changed[4] = "0x" + "34"*32
        transactions["execution"]["input"] = "0x" + (raw[:4] + encode(wire.governance.EXECUTE_BATCH,
            (action, (tuple(changed), *calls[1:]), datas))).hex()
        with self.assertRaises(MuseumError):
            wire.validate_governance(f.scoped_bundle, f.scoped_context, f.scoped_graph, transactions, f.scoped_events)

    def test_rehashed_root_cannot_replace_snapshot_artist_binding(self):
        for index, replacement in ((9, "2"), (10, "0x" + "56"*32)):
            f = ScopedStaticFinalityFixture(scope_type=2)
            f.scoped_bundle["content"]["roots"]["history"][-1]["record"][index] = replacement
            seal_roots(f.scoped_bundle["content"], f.scoped_context, f.scoped_graph, f.scoped_statement)
            with self.subTest(index=index), self.assertRaisesRegex(MuseumError, "Artist binding"):
                # Rebuild original manifest/finality/action commitments around the changed root.
                f._finality_execution()


if __name__ == "__main__": unittest.main()
