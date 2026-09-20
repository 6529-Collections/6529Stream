"""Joined VIEW regressions using coherent original synthetic source evidence.

These tests verify supplied-data joins. They do not execute native contracts or
authenticate provider observations, historical authority, or rendered bytes.
"""
from copy import deepcopy
import unittest

from . import native_view_policy_output_wire_v2 as wire
from . import view_policy_adoption_wire_v2 as adoption
from . import view_policy_membership_v2 as membership
from . import view_policy_output_wire_v2 as output
from .canonical import MuseumError, schema_id
from .test_view_policy_output_wire_v2 import reseal
from .view_policy_output_fixture_v2 import ViewPolicyOutputFixtureV2


def _position(row):
    return tuple(int(row["log"][key], 16)
        for key in ("blockNumber", "transactionIndex", "logIndex"))


class NativeViewPolicyOutputWireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original = ViewPolicyOutputFixtureV2()
        cls.replaced = ViewPolicyOutputFixtureV2(later_adoption=True)

    def _rehashed_configuration(self, index, value):
        fixture = self.original
        bundle = deepcopy(fixture.bundle)
        adopted = adoption.validate(bundle["adoption"], fixture.context, fixture.graph)
        members = membership.validate(bundle["membership"], fixture.context,
            fixture.graph, adopted["policyBinding"])
        combined = {**adopted, "tokenIds": members["tokenIds"], "policies": members["policies"]}
        bundle["output"]["configuration"]["checkpoint"][index] = value
        reseal(bundle["output"], fixture.context, fixture.graph, combined, coverage_timestamp=105)
        # Every downstream checkpoint/part/index hash is coherent. The joined
        # serving commitment is the only intended rejection point.
        output.validate(bundle["output"], fixture.context, fixture.graph, combined)
        return bundle

    def test_original_complete_rows_and_later_adoption_remain_distinct(self):
        for fixture in (self.original, self.replaced):
            with self.subTest(later=fixture is self.replaced):
                result = wire.validate_bundle(fixture.bundle, fixture.context, fixture.graph)
                events = wire.validate_event_join(fixture.bundle, fixture.context,
                    fixture.graph, fixture.view_events)
                self.assertEqual(result["output"]["tokenIds"], ["41", "42", "43"])
                self.assertTrue(events["originalPublicationChronologyChecked"])
                self.assertFalse(events["historicalAuthorityVerified"])
                self.assertFalse(events["viewFinalityEstablished"])
        selected = self.replaced.bundle["adoption"]["selectedRecordHash"]
        self.assertNotEqual(selected, self.replaced.bundle["adoption"]["head"])
        self.assertEqual(selected, self.replaced.bundle["output"]["checkpoint"]["plan"][1])

    def test_rehashed_serving_configuration_must_match_original_binding(self):
        bundle = self._rehashed_configuration(8, schema_id("different retained serving configuration"))
        with self.assertRaisesRegex(MuseumError, "original serving configuration/budget differs"):
            wire.validate_bundle(bundle, self.original.context, self.original.graph)

    def test_rehashed_serving_gas_requires_strict_native_headroom(self):
        gas = int(self.original.bundle["adoption"]["serving"]["binding"][5])
        threshold = gas + gas // 63 + 50000
        bundle = self._rehashed_configuration(11, str(threshold))
        with self.assertRaisesRegex(MuseumError, "original serving configuration/budget differs"):
            wire.validate_bundle(bundle, self.original.context, self.original.graph)
        accepted = self._rehashed_configuration(11, str(threshold + 1))
        wire.validate_bundle(accepted, self.original.context, self.original.graph)

    def test_replacement_between_checkpoint_seal_and_manifest_verification_rejected(self):
        fixture = self.replaced
        events = deepcopy(fixture.view_events)
        # The later adoption's native record, timestamp and publication remain
        # unchanged at block 6. Only completion of the earlier manifest moves
        # from block 5 to block 7; its original hashes contain no event position.
        moved = []
        for row in events:
            if row["log"]["topics"][0] in (
                    output.EVENTS["manifest_advanced"], output.EVENTS["manifest_verified"]):
                row["log"].update(blockNumber="0x7", blockHash=schema_id("VIEW completion block 7"),
                    transactionHash=schema_id("VIEW completion transaction 7"),
                    transactionIndex="0x0", logIndex=hex(len(moved)))
                row["timestamp"] = "107"
                moved.append(row)
        self.assertEqual(len(moved), 2)
        events.sort(key=_position)
        wire.validate_bundle(fixture.bundle, fixture.context, fixture.graph)
        with self.assertRaisesRegex(MuseumError, "adoption changed before manifest verification"):
            wire.validate_event_join(fixture.bundle, fixture.context, fixture.graph, events)

    def test_events_at_anchor_must_match_anchor_hash_and_timestamp(self):
        fixture = self.original
        last = fixture.view_events[-1]
        context = {**fixture.context, "blockNumber": str(_position(last)[0]),
            "blockHash": last["log"]["blockHash"], "timestamp": last["timestamp"]}
        wire.validate_event_join(fixture.bundle, context, fixture.graph, fixture.view_events)
        for key, value in (("blockHash", schema_id("different anchor header")), ("timestamp", "106")):
            with self.subTest(field=key), self.assertRaisesRegex(MuseumError, "event block conflict"):
                wire.validate_event_join(fixture.bundle, {**context, key: value},
                    fixture.graph, fixture.view_events)

    def test_one_height_cannot_have_two_hashes(self):
        events = deepcopy(self.original.view_events)
        events[-1]["log"]["blockHash"] = schema_id("second hash at same height")
        with self.assertRaisesRegex(MuseumError, "event block conflict"):
            wire.validate_event_join(self.original.bundle, self.original.context,
                self.original.graph, events)

    def test_one_hash_cannot_name_two_heights(self):
        events = deepcopy(self.original.view_events)
        earlier_hash = next(row["log"]["blockHash"] for row in events if _position(row)[0] == 4)
        for row in events:
            if _position(row)[0] == 5:
                row["log"]["blockHash"] = earlier_hash
        with self.assertRaisesRegex(MuseumError, "event block number conflict"):
            wire.validate_event_join(self.original.bundle, self.original.context,
                self.original.graph, events)

    def test_one_transaction_slot_cannot_name_two_transactions(self):
        events = deepcopy(self.original.view_events)
        coverage = next(row for row in events
            if row["log"]["address"] == self.original.graph["coverage"]["address"])
        coverage["log"]["transactionHash"] = schema_id("second transaction in same slot")
        with self.assertRaisesRegex(MuseumError, "event transaction slot conflict"):
            wire.validate_event_join(self.original.bundle, self.original.context,
                self.original.graph, events)

    def test_one_transaction_cannot_move_between_blocks(self):
        events = deepcopy(self.original.view_events)
        earlier_hash = next(row["log"]["transactionHash"] for row in events if _position(row)[0] == 4)
        for row in events:
            if _position(row)[0] == 5:
                row["log"]["transactionHash"] = earlier_hash
        with self.assertRaisesRegex(MuseumError, "event transaction conflict"):
            wire.validate_event_join(self.original.bundle, self.original.context,
                self.original.graph, events)

    def test_global_log_indices_must_increase_across_transaction_slots(self):
        events = deepcopy(self.original.view_events)
        manifest_rows = [row for row in events if _position(row)[0] == 5]
        for row in manifest_rows[1:]:
            row["log"].update(transactionIndex="0x1", transactionHash=schema_id("VIEW second block5 transaction"))
        # Two transactions with distinct ordered global log indices are valid.
        wire.validate_event_join(self.original.bundle, self.original.context, self.original.graph, events)
        for first_index, next_index in ((0, 0), (2, 1)):
            with self.subTest(indices=(first_index, next_index)):
                bad = deepcopy(events)
                rows = [row for row in bad if _position(row)[0] == 5]
                rows[0]["log"]["logIndex"] = hex(first_index)
                rows[1]["log"]["logIndex"] = hex(next_index)
                with self.assertRaisesRegex(MuseumError, "block log order"):
                    wire.validate_event_join(self.original.bundle, self.original.context,
                        self.original.graph, bad)

    def test_observed_header_times_cannot_run_backwards(self):
        events = deepcopy(self.original.view_events)
        for row in events:
            if _position(row)[0] == 4:
                row["timestamp"] = "106"
        with self.assertRaisesRegex(MuseumError, "event time order"):
            wire.validate_event_join(self.original.bundle, self.original.context,
                self.original.graph, events)


if __name__ == "__main__":
    unittest.main()
