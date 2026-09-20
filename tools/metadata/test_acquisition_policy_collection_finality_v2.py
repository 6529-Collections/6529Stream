"""Supplied original policy V2 evidence; all positive sources are synthetic."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import acquisition_policy_collection_finality_v2 as profile
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.policy_finality_fixture_v2 import PolicyFinalityFixtureV2


def supplied(*, count=1, burned=False):
    fixture = PolicyFinalityFixtureV2(count=count, burned=burned)
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
        self.assertEqual(len(value["definitions"]), 17)
        self.assertEqual(profile.token_proof(value)["scope"], ["0", value["sourceState"]["collectionId"], "0", profile.ZERO])
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
                lambda v: v["bundle"]["snapshot"]["source"][8][5].clear(),
                lambda v: v["bundle"]["membership"]["inventoryState"].__setitem__(1, keccak256(b"different prefix")),
                lambda v: v["bundle"]["content"]["roots"].update(rootHead=keccak256(b"unretained head"))):
            value = deepcopy(self.baseline[3]); edit(value)
            with self.subTest(edit=edit): self.reject(value)

    def test_odd_tree_complete_rows_and_reordered_originals(self):
        _, _, _, value = supplied(count=3)
        self.assertEqual(profile.token_proof(value)["leafCount"], "3")
        for field in ("tokens", "serialTokens"):
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

    def test_inherited_provider_runtime_aliases_are_checked(self):
        # Rebuild every provider configuration commitment after assigning an
        # inherited-only role to an existing address with another runtime.
        # The current V2 graph remains intact; the cross-source pin map is the
        # independent rejection, not a stale configuration hash.
        value = deepcopy(self.baseline[3]); provider = value["bundle"]["provider"]
        c = provider["configuration"]; graph = value["graph"]
        c["originalConfiguration"][0][8] = graph["roles"]["address"]
        c["originalConfiguration"][1][8] = keccak256(b"different inherited runtime")
        from tools.museum.chain_abi import encode
        from tools.museum import native_policy_finality_wire_v2 as wire
        configurations = [wire.base._v(wire.PROVIDER_CONFIG, c[key]) for key in
            ("originalConfiguration", "scopedConfiguration", "policyConfiguration")]
        profiles = [(wire.PROFILE_HASHES[i], cfg[0][9], cfg[1][9], cfg[0][8], cfg[1][8], cfg[0][10], cfg[1][10],
            keccak256(encode((wire.PROVIDER_CONFIG,), (cfg,)))) for i, cfg in enumerate(configurations)]
        c["profiles"] = wire.base.json_values(tuple(profiles))
        cfg = configurations[-1]
        pc = (graph["core"]["address"], graph["router"]["address"], graph["router"]["runtimeHash"], cfg[2], cfg[3],
            graph["outputManifest"]["address"], graph["outputManifest"]["runtimeHash"], tuple(profiles))
        c["configurationHash"] = wire.base._hash("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1",
            ("uint256", "address", wire.PROFILE_CONTEXT), (cfg[2], graph["provider"]["address"], pc))
        provider["discoverySourceConfigurationHash"] = c["configurationHash"]
        wire.validate_provider(c, value["sourceState"], graph)
        self.reject(value, "runtime contradiction")


if __name__ == "__main__": unittest.main()
