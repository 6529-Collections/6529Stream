"""Native finality supplied-data controls; synthetic originals are not RPC proof."""
import copy
import unittest
from unittest.mock import patch

from . import acquisition_native_finality_v1 as profile
from tools.museum import native_finality_wire as wire
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.chain_abi import encode
from tools.museum.independent_wire import ZERO
from tools.museum.test_native_finality_wire import supplied, H, A


def original_events(bundle, context, graph, *, headers=None):
    """Exact event preimages placed in a synthetic chronology, not a source capture."""
    expected = list(wire.expected_events(bundle, context, graph))
    rows = []
    for descriptor in expected:
        descriptor = copy.deepcopy(descriptor)
        descriptor["topics"] = [H("coverage-plan") if topic is None else topic for topic in descriptor["topics"]]
        rows.append(descriptor)
    action = wire.from_json(wire.GOVERNANCE_ACTION, bundle["execution"]["action"])
    witness = wire.from_json(wire.EXECUTION_WITNESS, bundle["finality"]["executionWitness"])
    topic = lambda kind, value: "0x" + encode((kind,), (value,)).hex()
    action_topics = [witness[0], topic("uint8", action[1]), topic("address", action[2])]
    def add(kind, topics, types, values):
        rows.append({"kind": kind, "address": graph["executor"]["address"],
            "topics": [wire.EVENTS[kind], *topics], "data": "0x" + encode(types, values).hex()})
    add("governanceScheduled", action_topics, wire.GOVERNANCE_SCHEDULED_DATA,
        (1, *action[3:11], 0, action[11], action[15], action[16], action[17]))
    add("governanceExecuted", action_topics, wire.GOVERNANCE_EXECUTED_DATA,
        (1, *action[3:9], action[12], action[17]))
    call_key = keccak256(b"".join(hex_bytes(keccak256(hex_bytes(raw))) for raw in bundle["execution"]["callDatas"]))
    add("governanceCalldataPublished", [call_key], wire.GOVERNANCE_CALLDATA_DATA,
        (1, bundle["execution"]["callDataPointer"], A(29001)))
    order = ("governanceCalldataPublished", "governanceScheduled", "checkpoint_started", "leaf_verified",
        "checkpoint_completed", "artifact_recorded", "coverage_completed", "manifest_started", "manifest_verified",
        "root_published", "finality_finalized", "pointer_recorded", "freeze_executed", "execution_witness",
        "archive_witness", "governanceExecuted")
    rows.sort(key=lambda row: order.index(row["kind"]))
    source_time = int(context["timestamp"])
    result = []; indices = {}
    for row in rows:
        kind = row.pop("kind")
        n = 3 if kind == "root_published" else 4 if order.index(kind) >= 10 else 1
        stamp = source_time - (2 if n == 3 else 1 if n == 4 else 4)
        h = headers[n]["hash"] if headers else H("event-block-" + str(n))
        if headers: stamp = int(headers[n]["timestamp"], 16)
        j = indices.setdefault(n, 1000); indices[n] += 1
        log = {**row, "blockHash": h, "blockNumber": hex(n), "transactionHash": H("event-transaction-" + str(n)),
            "transactionIndex": "0x64", "logIndex": hex(j)}
        result.append({"log": log, "timestamp": str(stamp)})
    return result


def fragment(context=None, graph=None, **kwargs):
    if context is None:
        context = supplied()[1]; context["environment"] = "local_evm_fixture"
    bundle, state, graph = supplied(context, graph, **kwargs)
    return {"schema": profile.NAME, "version": 1,
        "sourceRef": {**{key: H(key) for key in profile.SOURCE_REF_FIELDS[:-1]}, "provenance": "synthetic_fixture"},
        "sourceState": state, "graph": graph,
        "identity": {"tokenId": state["tokenId"], "collectionId": state["collectionId"], "collectionSerial": "3", "lifecycle": "2", "burned": False},
        "bundle": bundle, "events": original_events(bundle, state, graph),
        "definitions": [{"documentId": row["id"], "payloadHex": "0x" + row["bytes"].hex()} for row in wire.definitions()],
        "historicalCoreFacts": wire.validate_bundle(bundle, state, graph)["historicalCoreFacts"],
        "claims": dict(profile.CLAIMS), "qualification": profile.QUALIFICATION}


class AcquisitionNativeFinalityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.value = fragment()
    def fresh(self): return copy.deepcopy(self.value)
    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: profile.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_original_native_fragment_and_odd_leaf_proof_offline(self):
        with patch("socket.socket", side_effect=AssertionError("offline")):
            value = profile.validate(dumps(self.value))
        proof = profile.token_proof(value)
        self.assertEqual((proof["leafIndex"], proof["leafCount"], len(proof["proof"])), ("2", "3", 1))
        self.assertEqual(value["historicalCoreFacts"]["status"], "hash_only")
        self.assertIsNone(value["historicalCoreFacts"]["preimage"])
        self.assertFalse(any(value["claims"].values()))
        self.assertNotIn("authorityClass", value["bundle"]["finality"])

    def test_event_bytes_missing_duplicate_and_unsupplied_extras(self):
        value = self.fresh(); value["events"].pop(0); self.reject(value, "missing governance")
        value = self.fresh(); value["events"].insert(1, copy.deepcopy(value["events"][0])); self.reject(value, "event order")
        value = self.fresh(); value["events"][0]["log"]["data"] += "00"; self.reject(value)
        value = self.fresh(); value["events"][0]["log"]["topics"][0] = H("unknown-event"); self.reject(value, "unexpected")

    def test_semantic_event_order_cannot_be_reassigned_to_valid_coordinates(self):
        value = self.fresh()
        def index(kind): return next(i for i, row in enumerate(value["events"]) if row["log"]["topics"][0] == wire.EVENTS[kind])
        left, right = index("manifestStarted"), index("manifestVerified")
        for key in ("address", "topics", "data"):
            value["events"][left]["log"][key], value["events"][right]["log"][key] = value["events"][right]["log"][key], value["events"][left]["log"][key]
        self.reject(value, "chronology")

    def test_root_and_finality_receipt_timestamps_are_original(self):
        for topic, message in (("root", "root publication timestamp"), ("finalized", "finalized publication timestamp")):
            value = self.fresh()
            block = next(row["log"]["blockNumber"] for row in value["events"] if row["log"]["topics"][0] == wire.EVENTS[topic])
            for row in value["events"]:
                if row["log"]["blockNumber"] == block: row["timestamp"] = str(int(row["timestamp"]) - 1)
            self.reject(value, message)

    def test_source_header_transaction_and_log_contradictions(self):
        value = self.fresh(); value["events"][1]["log"]["blockHash"] = H("other-block"); self.reject(value, "block mapping")
        value = self.fresh(); value["events"][1]["log"]["transactionHash"] = H("other-tx"); self.reject(value, "transaction mapping")
        value = self.fresh(); value["sourceState"]["timestamp"] = "1"; self.reject(value)
        value = self.fresh(); value["events"][1]["log"]["logIndex"] = value["events"][0]["log"]["logIndex"]; self.reject(value)

    def test_carriers_definitions_and_original_commitment_mutations(self):
        value = self.fresh(); value["definitions"][0]["payloadHex"] += "00"; self.reject(value, "definition bytes")
        value = self.fresh(); value["bundle"]["content"]["artifact"]["chunks"][0]["runtime"] += "00"; self.reject(value, "chunk bytes")
        value = self.fresh(); value["bundle"]["finality"]["manifestBytes"] += "00"; self.reject(value)
        value = self.fresh(); value["bundle"]["execution"]["callDatas"][0] += "00"; self.reject(value, "scheduled finalize")
        value = self.fresh(); value["historicalCoreFacts"]["preimage"] = {}; self.reject(value)

    def test_closed_reference_shape_and_no_self_authentication(self):
        value = self.fresh(); value["sourceRef"]["anchorHash"] = H("different supplied pin")
        self.assertEqual(profile.validate(dumps(value)), value)
        value["sourceRef"]["captureManifestHash"] = H("extra"); self.reject(value)
        value = self.fresh(); value["sourceRef"]["anchorHash"] = ZERO; self.reject(value)
        value = self.fresh(); value["graph"]["core"]["address"] += "\n"; self.reject(value)

    def test_self_schema_larger_than_default_json_bound_is_explicitly_supported(self):
        self.assertGreater(len(profile.SCHEMA_BYTES), 24576)
        self.assertEqual(loads(profile.SCHEMA_BYTES, maximum=profile.MAX_BYTES)["title"], profile.NAME)
        self.assertEqual(profile.validate(dumps(self.value)), self.value)

    def test_later_coherent_root_cannot_be_ignored_at_finalization(self):
        value = self.fresh(); content = value["bundle"]["content"]
        old = content["rootHistory"][0]
        record = list(wire.from_json(wire.ROOT_RECORD, old["record"]))
        record[0] = (record[0][0], old["recordHash"], record[0][2], "ipfs://later-root")
        record[11] = wire.root_state_hash(int(value["sourceState"]["chainId"]), value["graph"]["router"]["address"], record)
        record[12] = H("later-root-consent")
        digest = wire.root_hash(int(value["sourceState"]["chainId"]), value["graph"]["router"]["address"], record)
        from tools.museum.independent_wire import json_values
        content["rootHistory"].append({"recordHash": digest, "record": json_values(record)})
        content["rootHead"] = digest
        wire.validate_bundle(value["bundle"], value["sourceState"], value["graph"])
        value["events"] = original_events(value["bundle"], value["sourceState"], value["graph"])
        self.reject(value, "selected root is not the final root head")

    def test_projection_checks_named_source_and_exact_snapshot_pins(self):
        from tools.museum import public_finality_source as source
        value = self.fresh()
        snapshot = {"profile": profile.SOURCE_PROFILE, "profileHash": source.PROFILE_HASH, "version": "1",
            "sourceReviewCommit": profile.SOURCE_REVISION, "anchorHash": H("source-anchor"),
            "transcriptHash": H("source-transcript"), "provenance": "synthetic_fixture", "source": value["sourceState"]}
        for key in ("graph", "identity", "bundle", "events", "definitions", "historicalCoreFacts"):
            snapshot[key] = copy.deepcopy(value[key])
        refs = {"sourceProfileHash": source.PROFILE_HASH, "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)), "provenance": "synthetic_fixture"}
        projected = profile.semanticProjection(snapshot, refs)
        self.assertEqual(projected["bundle"], value["bundle"])
        for key in profile.SOURCE_REF_FIELDS[:-1]:
            bad = dict(refs); bad[key] = H("mismatched-reference")
            with self.assertRaises(MuseumError): profile.semanticProjection(snapshot, bad)
        bad = dict(refs); bad["provenance"] = "trusted_rpc"
        with self.assertRaises(MuseumError): profile.semanticProjection(snapshot, bad)

    def test_terminal_and_scheduled_publication_order_are_exact(self):
        value = self.fresh()
        selected = [row for row in value["events"] if row["log"]["topics"][0] in
            (wire.EVENTS["terminalExecuted"], wire.EVENTS["executionWitness"], wire.EVENTS["archiveWitness"], wire.EVENTS["governanceExecuted"])]
        for row in selected: row["log"]["logIndex"] = hex(int(row["log"]["logIndex"], 16) + 1)
        self.reject(value, "terminal event adjacency")
        value = self.fresh()
        for key in ("address", "topics", "data"):
            value["events"][0]["log"][key], value["events"][1]["log"][key] = value["events"][1]["log"][key], value["events"][0]["log"][key]
        self.reject(value, "chronology")


if __name__ == "__main__": unittest.main()
