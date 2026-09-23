"""Focused supplied-evidence controls for the attributed VIEW retrieval wire."""

from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, hex_bytes, keccak256, schema_id as H
from .chain_abi import decode, encode
from .independent_wire import ZERO, json_values
from .native_finality_wire import from_json
from . import view_preservation_output_types_v1 as output_types
from . import view_policy_adoption_types_v2 as adoption_types
from . import view_preservation_bundle_wire_v1 as archive
from . import view_preservation_retrieval_types_v1 as t
from . import view_preservation_retrieval_wire_v1 as wire
from .view_preservation_retrieval_fixture_v1 import supplied


class ViewPreservationRetrievalWireTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = supplied()

    def setUp(self):
        self.value = deepcopy(self.base["retrieval"])
        self.context = deepcopy(self.base["context"])
        self.graph = deepcopy(self.base["graph"])
        self.inventory = deepcopy(self.base["inventory"])
        self.source_proof = deepcopy(self.base["sourceProof"])

    def validate(self):
        return wire.validate(
            self.value, self.context, self.graph, self.inventory, self.source_proof)

    def reject(self):
        with self.assertRaises(MuseumError):
            self.validate()

    def append_retained_history(self):
        original = self.value["records"][0]
        observation, signature = decode(
            (t.OBSERVATION, "bytes"), hex_bytes(original["payloadHex"]), maximum=t.MAX_BYTES)
        changed = list(observation); changed[7] = 18; observation = tuple(changed)
        raw = encode((t.OBSERVATION, "bytes"), (observation, signature))
        receipt = list(from_json(t.RECEIPT, original["receipt"]))
        receipt[0] = ZERO
        receipt[2] = wire.observation_hash(self.value["configuration"],
            self.value["witness"]["address"], observation)
        receipt[6], receipt[7], receipt[8] = 137, keccak256(raw), len(raw)
        receipt[0] = wire.record_hash(
            self.value["configuration"], self.value["witness"]["address"], tuple(receipt))
        log = {"address": self.value["witness"]["address"],
            "topics": [t.RECORDED_TOPIC, receipt[0], receipt[1],
                "0x" + encode(("address",), (receipt[5],)).hex()],
            "data": "0x" + encode((t.RECEIPT,), (tuple(receipt),)).hex(),
            "blockNumber": "0x25", "blockHash": H("retained retrieval block37"),
            "transactionHash": H("retained retrieval transaction37"),
            "transactionIndex": "0x0", "logIndex": "0x0", "removed": False}
        self.value["records"].append({"recordHash": receipt[0],
            "receipt": json_values(tuple(receipt)), "payloadHex": "0x" + raw.hex(),
            "publication": {"log": log, "timestamp": "137"}, "revocation": None,
            "current": None, "status": "retained_history",
            "nativeState": {"revoked": False, "nonceUsed": True}})
        self.value["historyCoverage"]["retainedRecordCount"] = 2
        calls = self.value["sourceBindings"]["calls"]
        epoch_call = wire._call(self.value["witness"]["address"],
            "revocationEpoch((uint8,uint256,uint256,bytes32))", (t.SCOPE,),
            (observation[0][0],), ("uint64",), (0,))
        insertion = calls.index(epoch_call)
        additions = [
            wire._call(self.value["witness"]["address"], "record(bytes32)",
                ("bytes32",), (receipt[0],), (t.RECEIPT,), (tuple(receipt),)),
            wire._call(self.value["witness"]["address"], "encoded(bytes32)",
                ("bytes32",), (receipt[0],), ("bytes",), (raw,)),
            wire._call(self.value["witness"]["address"], "revoked(bytes32)",
                ("bytes32",), (receipt[0],), ("bool",), (False,)),
            wire._call(self.value["witness"]["address"], "nonceUsed(bytes32)",
                ("bytes32",), (wire.nonce_key(receipt[5], observation[7]),),
                ("bool",), (True,)),
        ]
        calls[insertion:insertion] = additions
        return self.value["records"][-1], observation, tuple(receipt)

    def retime_operative_observation(self, observed_at):
        row = self.value["records"][0]
        observation, signature = decode(
            (t.OBSERVATION, "bytes"), hex_bytes(row["payloadHex"]), maximum=t.MAX_BYTES)
        changed = list(observation); changed[6] = observed_at; observation = tuple(changed)
        raw = encode((t.OBSERVATION, "bytes"), (observation, signature))
        receipt = list(from_json(t.RECEIPT, row["receipt"])); receipt[0] = ZERO
        receipt[2] = wire.observation_hash(
            self.value["configuration"], self.value["witness"]["address"], observation)
        receipt[6], receipt[7], receipt[8] = observed_at, keccak256(raw), len(raw)
        receipt[0] = wire.record_hash(
            self.value["configuration"], self.value["witness"]["address"], tuple(receipt))
        row.update(recordHash=receipt[0], receipt=json_values(tuple(receipt)),
            payloadHex="0x" + raw.hex())
        row["publication"]["timestamp"] = str(observed_at)
        row["publication"]["log"]["topics"] = [t.RECORDED_TOPIC, receipt[0], receipt[1],
            "0x" + encode(("address",), (receipt[5],)).hex()]
        row["publication"]["log"]["data"] = "0x" + encode(
            (t.RECEIPT,), (tuple(receipt),)).hex()

    def test_complete_direct_https_correspondence_is_offline_and_deterministic(self):
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            first = self.validate()
            second = self.validate()
        self.assertEqual(first, second)
        self.assertEqual(first["recordCount"], 1)
        self.assertEqual(first["operativeRecordCount"], 1)
        self.assertEqual(first["inventorySummary"]["itemCount"], 151)
        self.assertEqual(first["inventorySummary"]["provenance"], "synthetic_fixture")
        self.assertEqual(len(first["resolvedAdmissions"]), 1)
        self.assertGreater(len(first["expectedCalls"]), 100)

    def test_checkpoint_context_is_omitted_from_key_but_required_by_current_source(self):
        observation_source = list(from_json(t.SOURCE, self.base["_observation"][0]))
        before = wire.source_key(tuple(observation_source))
        observation_source[8] = H("different current checkpoint context")
        self.assertEqual(before, wire.source_key(tuple(observation_source)))
        checkpoint = self.value["records"][0]["current"]["checkpointSource"]
        checkpoint[4] = observation_source[8]
        self.reject()

    def test_observation_before_native_adoption_time_is_rejected(self):
        checked = wire.preservation.validate_bundle(
            self.source_proof["bundle"], self.context,
            {key: self.graph[key] for key in wire.preservation.GRAPH_KEYS})
        record = from_json(adoption_types.RECORD, checked["adoption"]["record"])
        _, _, adopted_at, _ = wire._expected_source(
            self.source_proof["bundle"], checked,
            self.value["records"][0]["current"])
        self.assertEqual(adopted_at, record[10])
        self.assertNotEqual(adopted_at, record[4])
        self.retime_operative_observation(adopted_at - 1)
        with self.assertRaisesRegex(MuseumError, "current source projection"):
            self.validate()

    def test_same_block_publication_must_follow_selected_adoption_log(self):
        selected = self.source_proof["bundle"]["adoption"]["selectedRecordHash"]
        adoption = next(row for row in self.source_proof["events"]
            if row["timestamp"] == "103"
            and (selected in row["log"]["topics"] or selected[2:] in row["log"]["data"][2:]))
        self.retime_operative_observation(103)
        publication = self.value["records"][0]["publication"]
        for key in ("blockNumber", "blockHash", "transactionHash",
                    "transactionIndex", "logIndex"):
            publication["log"][key] = adoption["log"][key]
        with self.assertRaisesRegex(MuseumError, "current source projection"):
            self.validate()

    def test_signed_archive_object_cannot_be_substituted_by_current_archive(self):
        self.value["records"][0]["current"]["sourceEvidence"]["object"][3] = H(
            "different current Archive content")
        self.reject()

    def test_locked_artist_presentation_is_mandatory(self):
        artist = self.value["records"][0]["current"]["artistPresentation"]
        artist[0] = False
        self.reject()

    def test_original_environment_preimage_is_not_a_free_hash(self):
        binding = self.value["itemBindings"][0]
        binding["environment"]["artifact"][0] = H("different artifact environment")
        self.reject()

    def test_inventory_and_retrieval_provenance_must_be_identical(self):
        self.value["sourceBindings"]["provenance"] = "externally_admitted_rpc"
        self.reject()

    def test_duplicate_inventory_coordinate_is_rejected_even_for_same_record(self):
        self.value["itemBindings"].append(deepcopy(self.value["itemBindings"][0]))
        self.reject()

    def test_every_operative_record_requires_an_item_binding(self):
        self.value["itemBindings"] = []
        self.reject()

    def test_payload_must_be_exact_canonical_observation_envelope(self):
        self.value["records"][0]["payloadHex"] += "00"
        self.reject()

    def test_publication_removed_flag_is_not_accepted(self):
        self.value["records"][0]["publication"]["log"]["removed"] = True
        self.reject()

    def test_retrieval_event_cannot_reuse_inventory_event_coordinate(self):
        occupied = self.inventory["value"]["events"][0]
        self.retime_operative_observation(int(occupied["timestamp"]))
        publication = self.value["records"][0]["publication"]
        for key in ("blockNumber", "blockHash", "transactionHash",
                    "transactionIndex", "logIndex"):
            publication["log"][key] = occupied["log"][key]
        publication["timestamp"] = occupied["timestamp"]
        with self.assertRaisesRegex(
                MuseumError, "global source/publication block or transaction conflict"):
            self.validate()

    def test_source_carriers_share_one_runtime_map_with_archive(self):
        originals = archive._Originals(self.context, self.graph)
        address = self.graph["externalCoverage"]["address"]
        checked = {"membership": {"policies": []},
            "adoption": {"preservation": {"registry": {"targets": []}}}}
        with self.assertRaises(MuseumError):
            wire._source_pins({"pointer": address, "runtime": "0x00"}, checked, originals)
        fresh = archive._Originals(self.context, self.graph)
        other = "0x0000000000000000000000000000000000099999"
        wire._source_pins({"pointer": other, "runtime": "0x00"}, checked, fresh)
        wire._source_pins({"pointer": other, "runtime": "0x00"}, checked, fresh)

    def test_non_evaluated_history_uses_explicit_retained_status(self):
        self.value["records"][0]["status"] = "historical_noncurrent"
        self.reject()

    def test_unrevoked_record_may_be_retained_without_currentness_claim(self):
        self.append_retained_history()
        result = self.validate()
        self.assertEqual(result["recordCount"], 2)
        self.assertEqual(result["operativeRecordCount"], 1)
        self.assertFalse(result["claims"]["retainedHistoryCurrentnessEvaluated"])

    def test_revoked_retained_record_joins_event_epoch_and_native_getter(self):
        row, observation, receipt = self.append_retained_history()
        reason = H("retained retrieval revocation reason")
        row["status"] = "revoked"; row["nativeState"]["revoked"] = True
        row["revocation"] = {"reasonHash": reason, "event": {"timestamp": "138", "log": {
            "address": self.value["witness"]["address"],
            "topics": [t.REVOKED_TOPIC, receipt[0],
                "0x" + encode(("address",), (receipt[5],)).hex()],
            "data": "0x" + encode(("bytes32",), (reason,)).hex(),
            "blockNumber": "0x26", "blockHash": H("retained retrieval block38"),
            "transactionHash": H("retained retrieval transaction38"),
            "transactionIndex": "0x0", "logIndex": "0x0", "removed": False}}}
        self.value["historyCoverage"]["retainedRevocationCount"] = 1
        self.value["scopeEpochs"][0]["epoch"] = "1"
        binding = self.value["itemBindings"][0]
        binding["environmentHash"] = wire.environment_hash(
            binding["originalEnvironment"], self.value["witness"]["address"],
            self.value["witness"]["runtimeHash"], observation[0][0], 1)
        revoked_call = wire._call(self.value["witness"]["address"], "revoked(bytes32)",
            ("bytes32",), (receipt[0],), ("bool",), (False,))
        epoch_calldata = wire._call(self.value["witness"]["address"],
            "revocationEpoch((uint8,uint256,uint256,bytes32))", (t.SCOPE,),
            (observation[0][0],), ("uint64",), (0,))["calldata"]
        for calls in (self.value["sourceBindings"]["calls"],
                      binding["sourceBindings"]["calls"]):
            for call in calls:
                if call == revoked_call:
                    call["result"] = "0x" + encode(("bool",), (True,)).hex()
                if (call["target"] == self.value["witness"]["address"]
                        and call["calldata"] == epoch_calldata):
                    call["result"] = "0x" + encode(("uint64",), (1,)).hex()
        result = self.validate()
        self.assertEqual(result["recordCount"], 2)
        self.assertEqual(result["operativeRecordCount"], 1)
        self.assertEqual(result["revocationCount"], 1)

    def test_frozen_profile_and_witness_interface_are_closed(self):
        changed = deepcopy(self.value)
        changed["profile"] = H("different retrieval profile")
        with self.assertRaises(MuseumError):
            wire.validate(changed, self.context, self.graph, self.inventory, self.source_proof)
        self.value["witness"]["interfaceId"] = "0x00000000"
        self.reject()

    def test_full_wire_redirect_mirror_and_manifest_callback_paths(self):
        for route, steps, manifests in (("redirect", 1, 0), ("mirror", 1, 0),
                                        ("manifest", 1, 1)):
            case = supplied(route=route)
            with self.subTest(route=route), patch(
                    "socket.socket", side_effect=AssertionError("offline only")):
                result = wire.validate(case["retrieval"], case["context"], case["graph"],
                    case["inventory"], case["sourceProof"])
            report = result["resolvedAdmissions"][0]["route"]
            self.assertEqual(report["steps"], steps)
            self.assertEqual(len(report["manifestOccurrences"]), manifests)
        case = supplied(route="manifest")
        case["retrieval"]["records"][0]["current"]["manifestEvidence"] = []
        with self.assertRaises(MuseumError):
            wire.validate(case["retrieval"], case["context"], case["graph"],
                case["inventory"], case["sourceProof"])

    def test_current_checkpoint_source_has_exact_native_shape(self):
        checkpoint = from_json(
            output_types.SOURCE,
            self.value["records"][0]["current"]["checkpointSource"],
        )
        self.assertEqual(checkpoint[4], self.base["_observation"][0][8])


if __name__ == "__main__":
    unittest.main()
