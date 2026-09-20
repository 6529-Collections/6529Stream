"""Adversarial supplied-data tests for scoped STATIC finality.

All fixtures are synthetic native-wire observations.  They do not establish
chain provenance, historical authority, or execution.
"""
import copy
import unittest
from unittest.mock import patch

from . import acquisition_scoped_static_finality_v1 as profile
from tools.museum import native_scoped_finality_wire as wire
from tools.museum.canonical import MuseumError, dumps, keccak256, loads
from tools.museum.scoped_static_finality_fixture import ScopedStaticFinalityFixture


def supplied(scope_type=1, *, burned=False):
    fixture = ScopedStaticFinalityFixture(scope_type=scope_type, burned=burned)
    snapshot = fixture.scoped_result()
    source_ref = {"sourceProfileHash": snapshot["profileHash"],
        "anchorHash": snapshot["anchorHash"], "transcriptHash": snapshot["transcriptHash"],
        "snapshotHash": keccak256(dumps(snapshot)), "provenance": snapshot["provenance"]}
    return fixture, snapshot, source_ref, profile.semanticProjection(snapshot, source_ref)


class AcquisitionScopedStaticFinalityV1Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.token = supplied(1)

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught:
            profile.validate(dumps(value))
        if message:
            self.assertIn(message, str(caught.exception))

    def test_all_three_scopes_project_exact_originals_offline(self):
        for scope_type in (1, 2, 3):
            with self.subTest(scope_type=scope_type), patch("socket.socket", side_effect=AssertionError("offline")):
                _, snapshot, source_ref, value = supplied(scope_type)
                self.assertEqual(profile.validate(dumps(value)), value)
                self.assertEqual(value["bundle"]["scope"][0], str(scope_type))
                self.assertEqual(value["sourceRef"], source_ref)
                self.assertEqual(value["sourceState"], {key: snapshot["source"][key] for key in profile.COMMON})
                self.assertEqual(profile.token_proof(value)["kind"], "native_scoped_token_content_proof")

    def test_current_burn_is_separate_and_matches_original_membership_identity(self):
        _, _, _, value = supplied(1, burned=True)
        self.assertEqual((value["identity"]["burned"], value["identity"]["lifecycle"]), (True, "3"))
        self.assertEqual(profile.validate(dumps(value)), value)
        for edit in (lambda v: v["identity"].update(collectionSerial="999"),
                lambda v: v["identity"].update(burned=False, lifecycle="2"),
                lambda v: v["bundle"]["membership"]["identities"][0].__setitem__(2, "999")):
            changed = copy.deepcopy(value); edit(changed)
            self.reject(changed, "current/member token identity")

    def test_projection_requires_exact_named_profile_and_snapshot_pins(self):
        _, snapshot, source_ref, value = self.token
        self.assertEqual(profile.semanticProjection(snapshot, source_ref), value)
        for key in profile.SOURCE_REF_FIELDS[:-1]:
            changed = dict(source_ref); changed[key] = keccak256(("different " + key).encode())
            with self.subTest(key=key), self.assertRaises(MuseumError):
                profile.semanticProjection(snapshot, changed)
        changed = copy.deepcopy(snapshot); changed["profile"] = "STREAM_OTHER_PROFILE_V1"
        with self.assertRaisesRegex(MuseumError, "snapshot profile"):
            profile.semanticProjection(changed, source_ref)

    def test_membership_and_output_order_cannot_be_relabelled(self):
        _, _, _, value = supplied(2)
        changed = copy.deepcopy(value)
        changed["bundle"]["membership"]["tokens"][0], changed["bundle"]["membership"]["tokens"][1] = (
            changed["bundle"]["membership"]["tokens"][1], changed["bundle"]["membership"]["tokens"][0])
        self.reject(changed)
        changed = copy.deepcopy(value)
        rows = changed["bundle"]["content"]["checkpoint"]["outputs"]
        rows[0], rows[1] = rows[1], rows[0]
        self.reject(changed)

    def test_original_event_and_transaction_bytes_are_not_replaceable(self):
        value = copy.deepcopy(self.token[3])
        left, right = 0, 1
        value["events"][left]["log"]["topics"], value["events"][right]["log"]["topics"] = (
            value["events"][right]["log"]["topics"], value["events"][left]["log"]["topics"])
        self.reject(value)

        value = copy.deepcopy(self.token[3])
        raw = loads(bytes.fromhex(value["transactions"]["schedule"]["transactionBytes"][2:]), maximum=profile.MAX_ORIGINAL_BYTES)
        raw["input"] += "00"
        value["transactions"]["schedule"]["transactionBytes"] = "0x" + dumps(raw).hex()
        value["transactions"]["schedule"]["normalized"]["input"] = raw["input"]
        self.reject(value)

    def test_historical_hash_only_facts_never_accept_a_preimage(self):
        value = copy.deepcopy(self.token[3]); value["historicalCoreFacts"]["preimage"] = {}
        self.reject(value)
        value = copy.deepcopy(self.token[3]); value["historicalCoreFacts"]["hash"] = keccak256(b"false historical facts")
        self.reject(value, "historical Core hash")

    def test_exact_definitions_and_closed_fragment(self):
        value = copy.deepcopy(self.token[3]); value["definitions"][0]["payloadHex"] += "00"
        self.reject(value, "definition bytes")
        value = copy.deepcopy(self.token[3]); value["unexpected"] = True
        self.reject(value)


if __name__ == "__main__":
    unittest.main()
