"""Adversarial synthetic checks for the public attribution reader.

These fixtures reconstruct native-shaped RPC answers.  They are not actual-chain
or institutional evidence.
"""
import unittest
from unittest.mock import patch

from . import artist_attestation_source as artist
from . import public_attribution_source as source
from .canonical import MuseumError, keccak256, loads
from .independent_wire import ZERO
from .public_history_rpc import PublicReplayTransport
from .test_current_rights_source import A
from .test_public_personhood_source import K
from .test_public_attribution_source import PublicAttributionFixture


class PublicAttributionAdversarialTests(unittest.TestCase):
    def snapshot(self, fixture):
        return loads(fixture.source().snapshot(), maximum=source.MAX_OUTPUT)

    def rebind_after_confirmed_generation(self):
        fixture = PublicAttributionFixture(mode="sanctioned")
        old = fixture.current_binding
        fixture.transition(3, 5, block=4, generation=1, record=K("generation one revocation"))
        current = (old[0], old[1], old[2], K("generation two binding"), 2,
            old[5], old[6], old[7], A(190), True)
        fixture.current_binding = current
        fixture.add(fixture.owners[0], "bindingAt(uint256,uint64)", ("uint256", "uint64"),
            (1, 2), (artist.BINDING,), (current,))
        fixture.add(fixture.owners[0], "binding(uint256)", ("uint256",),
            (1,), (artist.BINDING,), (current,))
        fixture.transition(5, 1, block=5, generation=2, authority=0, record=current[3])
        fixture.transition(1, 2, block=5, generation=2, authority=1,
            record=K("generation two acceptance"))
        fixture.set_attribution(2, 2)
        fixture.latest(ZERO, binding=current)
        return fixture

    def test_confirmation_latest_and_dispute_restoration_stay_distinct(self):
        later = self.snapshot(PublicAttributionFixture(mode="later_sanction"))
        confirmed = later["history"]["originalConfirmation"]["recordHash"]
        latest = later["sanctions"]["latestAssociationHash"]
        self.assertNotEqual(confirmed, latest)
        self.assertEqual(later["sanctions"]["originalConfirmedHash"], confirmed)
        self.assertEqual(later["history"]["confirmationArchive"]["sanctionRecordHash"], confirmed)
        self.assertEqual({row["recordHash"] for row in later["sanctions"]["records"]}, {confirmed, latest})

        restored = self.snapshot(PublicAttributionFixture(mode="restored"))
        restoration = restored["history"]["restorations"][-1]
        self.assertEqual((restoration["oldState"], restoration["newState"]), ("4", "3"))
        self.assertNotEqual(restoration["recordHash"], restored["sanctions"]["originalConfirmedHash"])
        self.assertEqual(restored["history"]["originalConfirmation"]["recordHash"],
            restored["sanctions"]["originalConfirmedHash"])

    def test_prior_generation_confirmation_is_fully_checked_after_rebinding(self):
        fixture = self.rebind_after_confirmed_generation()
        result = self.snapshot(fixture)
        self.assertEqual(result["current"]["attribution"], ["2", "2"])
        self.assertIsNone(result["history"]["originalConfirmation"])
        self.assertIsNone(result["history"]["confirmationArchive"])
        self.assertEqual(len(result["history"]["confirmations"]), 1)
        old = result["history"]["confirmations"][0]
        self.assertEqual(old["transition"]["generation"], "1")
        self.assertEqual(old["archive"]["sanctionRecordHash"], old["transition"]["recordHash"])

        operation = next(row for row in fixture.archive_rows if row["operation"] == 13)
        changed = operation["raw"][:-1] + bytes([operation["raw"][-1] ^ 1])
        fixture.add(fixture.archive, "artistEvidenceBytesV2(bytes32,uint64)",
            ("bytes32", "uint64"), (operation["key"], 1), ("bytes",), (changed,))
        with self.assertRaisesRegex(MuseumError, "archive receipt/carrier"):
            fixture.result()

    def test_confirmation_must_use_latest_association_sanction_at_transition(self):
        fixture = PublicAttributionFixture(mode="accepted")
        first = fixture.append_sanction(block=1)
        fixture.append_sanction(block=2)
        fixture.confirm(first, block=3)
        fixture.set_attribution(3, 1)
        with self.assertRaisesRegex(MuseumError, "not latest sanction at transition"):
            fixture.result()

    def test_current_authority_rotation_does_not_rewrite_historical_signer(self):
        fixture = PublicAttributionFixture(mode="sanctioned")
        historical = fixture.sanction_rows[0]["record"]
        current_authority = A(777)
        fixture.add(fixture.owners[2], "authorityState(bytes32)", ("bytes32",),
            (fixture.current_binding[0],), (source.AUTHORITY,),
            ((current_authority, 3, 3, fixture.current_binding[2]),))
        fixture.add(fixture.registry, "collectionArtistState(uint256)", ("uint256",),
            (1,), source.COMPOSITE, (3, 1, fixture.current_binding[0], 3, fixture.current_binding[3]))
        result = self.snapshot(fixture)
        self.assertEqual(result["current"]["authority"][0], current_authority)
        self.assertEqual(result["current"]["authority"][1:3], ["3", "3"])
        self.assertEqual(result["sanctions"]["records"][0]["record"][2], historical[2])
        self.assertNotEqual(current_authority, historical[2])

    def test_latest_class_four_sanction_does_not_imply_confirmation(self):
        fixture = PublicAttributionFixture(mode="accepted")
        latest = fixture.append_sanction(block=4, authority_class=4)
        result = self.snapshot(fixture)
        self.assertEqual(result["current"]["attribution"], ["2", "1"])
        self.assertEqual(result["sanctions"]["latestAssociationHash"], latest["record"][0])
        self.assertEqual(result["sanctions"]["records"][0]["record"][3], "4")
        self.assertIsNone(result["history"]["originalConfirmation"])
        self.assertEqual(result["sanctions"]["originalConfirmedHash"], ZERO)

    def test_native_none_and_platform_declaration_are_separate(self):
        none = self.snapshot(PublicAttributionFixture(mode="none"))
        platform = self.snapshot(PublicAttributionFixture(mode="platform"))
        self.assertEqual(none["current"]["attribution"], ["0", "0"])
        self.assertEqual(platform["current"]["attribution"], ["0", "0"])
        self.assertFalse(none["current"]["platformDeclaration"][0])
        self.assertTrue(platform["current"]["platformDeclaration"][0])
        self.assertEqual(none["current"]["stateLabel"], "NONE")
        self.assertEqual(platform["current"]["stateLabel"], "NONE")

    def test_saved_platform_declaration_requires_its_original_event(self):
        fixture = PublicAttributionFixture(mode="platform")
        for receipt in fixture.receipts.values():
            receipt["logs"] = [log for log in receipt["logs"] if log["topics"][0] != source.PLATFORM_EVENT]
        with self.assertRaisesRegex(MuseumError, "platform original declaration missing"):
            fixture.result()

    def test_binding_state_and_current_authority_contradictions_reject(self):
        fixture = PublicAttributionFixture(mode="none")
        fixture.set_attribution(1, 1)
        with self.assertRaisesRegex(MuseumError, "empty binding/state"):
            fixture.result()

        fixture = PublicAttributionFixture(mode="imported")
        fixture.set_attribution(1, 1)
        with self.assertRaisesRegex(MuseumError, "current generation/registration"):
            fixture.result()

        fixture = PublicAttributionFixture(mode="accepted")
        fixture.add(fixture.owners[2], "authorityState(bytes32)", ("bytes32",),
            (fixture.current_binding[0],), (source.AUTHORITY,),
            ((A(778), 2, 1, fixture.current_binding[2]),))
        with self.assertRaisesRegex(MuseumError, "current generation/registration"):
            fixture.result()

    def test_latest_getter_cannot_replace_last_original_publication(self):
        fixture = PublicAttributionFixture(mode="later_sanction")
        first, second = fixture.sanction_rows
        self.assertNotEqual(first["record"][0], second["record"][0])
        fixture.latest(first["record"][0])
        with self.assertRaisesRegex(MuseumError, "latest association differs"):
            fixture.result()

    def test_offline_replay_preserves_all_occurrences(self):
        fixture = PublicAttributionFixture(mode="restored")
        adapter = fixture.source(); expected = adapter.snapshot(); transcript = adapter.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            replay = source.PublicAttributionSource(adapter.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), expected)


if __name__ == "__main__": unittest.main()
