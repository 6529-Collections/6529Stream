"""Supplied original policy V2 evidence; all positive sources are synthetic."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import acquisition_scoped_policy_finality_v2 as profile
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.scoped_policy_finality_fixture_v2 import ScopedPolicyFinalityFixtureV2


def supplied(*, count=1, burned=False, scope_type=1):
    fixture = ScopedPolicyFinalityFixtureV2(count=count, burned=burned, scope_type=scope_type)
    snapshot = fixture.policy_result()
    refs = {"sourceProfileHash": snapshot["profileHash"], "anchorHash": snapshot["anchorHash"],
        "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)),
        "provenance": snapshot["provenance"]}
    return fixture, snapshot, refs, profile.semanticProjection(snapshot, refs)


class PolicyCollectionFinalityV2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = supplied()

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught:
            profile.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_original_records_and_hash_rows_retained_offline(self):
        _, snapshot, refs, value = self.baseline
        with patch("socket.socket", side_effect=AssertionError("offline")):
            self.assertEqual(profile.validate(dumps(value)), value)
        self.assertEqual(value["sourceRef"], refs)
        self.assertEqual(value["bundle"], snapshot["bundle"])
        self.assertEqual(len(value["definitions"]), 19)
        self.assertEqual(profile.token_proof(value)["scope"], value["bundle"]["scope"])
        self.assertEqual(value["historicalCoreFacts"]["status"], "hash_only")
        self.assertTrue(all(flag is False for flag in value["claims"].values()))

    def test_projection_requires_exact_profile_and_all_external_pins(self):
        _, snapshot, refs, _ = self.baseline
        for key in profile.SOURCE_REF_FIELDS[:-1]:
            altered = dict(refs); altered[key] = keccak256(("wrong " + key).encode())
            with self.subTest(key=key), self.assertRaises(MuseumError):
                profile.semanticProjection(snapshot, altered)
        altered = deepcopy(snapshot); altered["profile"] = "STREAM_OLD_STATIC_PROFILE"
        with self.assertRaisesRegex(MuseumError, "snapshot profile"):
            profile.semanticProjection(altered, refs)

    def test_current_burn_is_separate_from_retained_original_outputs(self):
        _, _, _, value = supplied(burned=True)
        self.assertTrue(value["identity"]["burned"])
        self.assertEqual(value["identity"]["lifecycle"], "3")
        self.assertEqual(profile.validate(dumps(value)), value)
        value["identity"].update(burned=False, lifecycle="2")
        self.reject(value, "membership identity")

    def test_exact_definitions_closed_fields_and_hash_only_facts(self):
        for edit in (lambda v: v.update(unrecognized=True),
                lambda v: v["definitions"][0].update(payloadHex=v["definitions"][0]["payloadHex"] + "00"),
                lambda v: v["historicalCoreFacts"].update(preimage={}),
                lambda v: v["claims"].update(actualChainAcceptance=True)):
            value = deepcopy(self.baseline[3]); edit(value)
            with self.subTest(edit=edit): self.reject(value)

    def test_output_readiness_and_static_component_originals_are_bound(self):
        for edit in (lambda v: v["bundle"]["content"]["checkpoint"]["outputs"][0][4].__setitem__(9, keccak256(b"wrong seed")),
                lambda v: v["bundle"]["staticComponents"]["originals"][0]["rawSource"].__setitem__(0, keccak256(b"different source")),
                lambda v: v["bundle"]["content"]["roots"]["history"][0]["binding"].__setitem__(0, profile.ZERO)):
            value = deepcopy(self.baseline[3]); edit(value)
            with self.subTest(edit=edit): self.reject(value)

    def test_original_transaction_and_event_observations_are_bound(self):
        value = deepcopy(self.baseline[3]); value["events"][0]["log"]["data"] += "00"
        self.reject(value)
        value = deepcopy(self.baseline[3]); observation = value["transactions"]["schedule"]
        transaction = loads(hex_bytes(observation["transactionBytes"]), maximum=profile.MAX_ORIGINAL_BYTES)
        transaction["chainId"] = hex(int(value["sourceState"]["chainId"]) + 1)
        observation["transactionBytes"] = "0x" + dumps(transaction).hex()
        self.reject(value, "chain")

    def test_original_locks_policy_rows_and_inventory_prefix_are_required(self):
        for edit in (lambda v: v["bundle"]["snapshot"]["lock"].__setitem__(2, profile.ZERO),
                lambda v: v["bundle"]["reference"]["lock"].__setitem__(3, "0"),
                lambda v: v["bundle"]["snapshot"]["source"][9][5].clear(),
                lambda v: v["bundle"]["membership"]["facts"].__setitem__(5, keccak256(b"different membership")),
                lambda v: v["bundle"]["content"]["roots"].update(scopeHead=keccak256(b"unretained head"))):
            value = deepcopy(self.baseline[3]); edit(value)
            with self.subTest(edit=edit): self.reject(value)

    def test_odd_tree_complete_rows_and_reordered_originals(self):
        _, _, _, value = supplied(count=3,scope_type=2)
        self.assertEqual(profile.token_proof(value)["leafCount"], "3")
        for field in ("tokens", "identities"):
            changed = deepcopy(value)
            rows = changed["bundle"]["membership"][field]; rows[0], rows[1] = rows[1], rows[0]
            with self.subTest(field=field): self.reject(changed)
        changed = deepcopy(value); rows = changed["bundle"]["content"]["checkpoint"]["outputs"]
        rows[0], rows[1] = rows[1], rows[0]
        self.reject(changed)

    def test_required_original_events_and_exact_positions(self):
        value = deepcopy(self.baseline[3])
        descriptors = profile.wire.expected_events(value["bundle"], value["sourceState"], value["graph"])
        target = next(row for row in descriptors if row["kind"] == "policy_snapshot_locked")
        index = next(i for i, row in enumerate(value["events"]) if profile.wire.base.event_matches(target, row["log"]))
        del value["events"][index]
        self.reject(value, "missing original event")
        value = deepcopy(self.baseline[3]); value["events"][1]["log"]["logIndex"] = value["events"][0]["log"]["logIndex"]
        self.reject(value)

    def test_original_factory_variant_and_child_denominator(self):
        from tools.museum import scoped_policy_factory_v2 as factory
        for edit in (lambda v:v["bundle"]["factory"].update(profile=factory.CURRENT_AUTHORITY_PROFILE),
                lambda v:v["bundle"]["factory"]["preparationEvents"].pop(),
                lambda v:v["bundle"]["factory"]["graph"][5].reverse()):
            value=deepcopy(self.baseline[3]);edit(value)
            with self.subTest(edit=edit):self.reject(value)

    def test_season_is_native_scope_not_collection_alias(self):
        _,_,_,value=supplied(count=3,scope_type=3)
        self.assertEqual(profile.token_proof(value)["scope"][0],"3")
        value["bundle"]["scope"][0]="0"
        self.reject(value)

    def test_inherited_output_and_membership_carrier_runtime_collisions(self):
        value = deepcopy(self.baseline[3])
        output = value["bundle"]["provider"]["configuration"]["collectionPolicyOutput"]
        output["address"] = value["graph"]["core"]["address"]
        output["runtimeHash"] = keccak256(b"contradictory inherited output code")
        self.reject(value, "supplied runtime contradiction")
        _, _, _, value = supplied(count=3, scope_type=2)
        publication = value["bundle"]["membership"]["publication"]
        self.assertIn((publication[4], publication[5]), list(profile.runtime_observations(value)))
        publication[4] = value["graph"]["core"]["address"]
        self.reject(value, "supplied runtime contradiction")


if __name__ == "__main__": unittest.main()
