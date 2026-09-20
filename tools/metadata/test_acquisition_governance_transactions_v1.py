"""Original supplied RPC bytes and native action preimages; no transaction-signature claim."""
import copy
import unittest
from unittest.mock import patch

from . import acquisition_governance_transactions_v1 as profile
from . import acquisition_native_finality_v1 as native
from .test_acquisition_native_finality_v1 import fragment, original_events
from tools.museum import governance_transaction_wire as wire
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.chain_abi import calldata, encode
from tools.museum.independent_wire import ZERO_ADDRESS, json_values
from tools.museum.test_native_finality_wire import A, H


def blob(value): return "0x" + dumps(value).hex()
def unblob(value): return loads(hex_bytes(value), maximum=profile.MAX_ORIGINAL_BYTES, canonical=True)


def supplied(*, batch=False):
    """Rebuild complete original calls/action/events before observing RPC bytes."""
    original = fragment(); bundle, state, graph = (original[key] for key in ("bundle", "sourceState", "graph"))
    stored = native.wire.from_json(native.wire.GOVERNANCE_ACTION, bundle["execution"]["action"])
    derived = native.wire.validate_bundle(bundle, state, graph)
    data = hex_bytes(bundle["execution"]["callDatas"][0]); transition = derived["executionContext"]
    call = (graph["finality"]["address"], 0, "0x" + data[:4].hex(), keccak256(data),
        *(transition[key] for key in ("scopeHash", "oldValueHash", "newValueHash")))
    if batch:
        marker = hex_bytes(calldata("syntheticMarker(bytes32)", ("bytes32",), (H("marker"),)))
        calls = ((A(33001), 0, "0x" + marker[:4].hex(), keccak256(marker), H("scope"), H("old"), H("new")), call)
        datas = (marker, data)
    else: calls, datas = (call,), (data,)
    digest, transitions = wire.calls_hash(calls), wire.transition_hashes(calls)
    action = (3, stored[1], calls[0][0], 0, calls[0][2], digest, *transitions, *stored[9:])
    identity = (action[1], digest, *transitions, 0, action[9], action[10], action[15], action[17])
    action_id = wire.action_id(state["chainId"], graph["executor"]["address"], identity)
    bundle["execution"]["action"] = json_values(action)
    bundle["execution"]["callDatas"] = ["0x" + raw.hex() for raw in datas]
    bundle["execution"]["runtime"] = "0x" + (b"\0" + encode((wire.Array("bytes", 64),), (datas,))).hex()
    bundle["finality"]["executionWitness"][0] = action_id
    original["events"] = original_events(bundle, state, graph)
    if batch:
        schedule = calldata(wire.SIGNATURES["schedule_batch"], wire.SCHEDULE_BATCH,
            (action[1], calls, *transitions, action[9], action[10], action[15], action[16], action[17]))
        execute = calldata(wire.SIGNATURES["execute_batch"], wire.EXECUTE_BATCH, (action_id, calls, datas))
    else:
        request = (action[1], *call[:3], data, *call[4:], action[9], action[10], action[15], action[16], action[17])
        schedule = calldata(wire.SIGNATURES["schedule_action"], wire.SCHEDULE_ACTION, (request,))
        execute = calldata(wire.SIGNATURES["execute_action"], wire.EXECUTE_ACTION, (action_id, data))
    transactions, headers = {}, {}
    for side, event_name, raw, sender in (("schedule", "governanceScheduled", schedule, action[11]),
            ("execution", "governanceExecuted", execute, action[12])):
        row = next(row for row in original["events"] if row["log"]["topics"][0] == native.wire.EVENTS[event_name])
        log = row["log"]; coords = {key: log[key] for key in ("blockHash", "blockNumber", "transactionIndex")}
        transaction = {**coords, "hash": log["transactionHash"], "from": sender, "to": graph["executor"]["address"],
            "value": "0x0", "input": raw, "chainId": hex(int(state["chainId"])), "nonce": "0x1ff"}
        receipt = {**coords, "transactionHash": transaction["hash"], "from": sender, "to": transaction["to"], "status": "0x1",
            "logs": [{**copy.deepcopy(event["log"]), "removed": False} for event in original["events"]
                if event["log"]["transactionHash"] == transaction["hash"]]}
        normalized = {key: transaction[key] for key in ("to", "from", "input")}; normalized["value"] = "0"
        transactions[side] = {"status": "available", "transactionBytes": blob(transaction), "receiptBytes": blob(receipt), "normalized": normalized}
        slots = [H("unused tx" + log["blockNumber"] + str(i)) for i in range(int(log["transactionIndex"], 16))] + [transaction["hash"]]
        headers[log["blockNumber"]] = {"hash": log["blockHash"], "number": log["blockNumber"], "timestamp": hex(int(row["timestamp"])),
            "parentHash": H("parent" + log["blockNumber"]), "stateRoot": H("state" + log["blockNumber"]), "transactions": slots}
    value = {"schema": profile.NAME, "version": 1, "sourceRef": copy.deepcopy(original["sourceRef"]), "sourceState": copy.deepcopy(state),
        "nativeFinality": original, "headers": [blob(headers[key]) for key in sorted(headers, key=lambda key: int(key, 16))],
        "transactions": transactions, "chainBoundBy": profile.CHAIN_BOUND_BY, "qualification": profile.QUALIFICATION}
    rederive(value)
    return value


def rederive(value):
    original = value["nativeFinality"]
    value["reconstruction"] = wire.verify(original["bundle"], value["sourceState"], original["graph"],
        {key: row["normalized"] for key, row in value["transactions"].items()}, original["events"])


def transaction_edit(value, side, edit, *, actors=False):
    row = value["transactions"][side]; transaction = unblob(row["transactionBytes"])
    edit(transaction); row["transactionBytes"] = blob(transaction)
    row["normalized"] = {key: transaction[key] for key in ("to", "from", "input")}
    row["normalized"]["value"] = str(int(transaction["value"], 16))
    if actors:
        receipt = unblob(row["receiptBytes"])
        receipt.update({key: transaction[key] for key in ("from", "to")}); row["receiptBytes"] = blob(receipt)


class GovernanceTransactionDefinitionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.single, cls.batch = supplied(), supplied(batch=True)
    def fresh(self, *, batch=False): return copy.deepcopy(self.batch if batch else self.single)
    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: profile.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_single_and_ordered_batch_complete_preimages_offline(self):
        for value, count in ((self.single, 1), (self.batch, 2)):
            before = dumps(value["nativeFinality"])
            with patch("socket.socket", side_effect=AssertionError("offline")):
                report = profile.validate(dumps(value))
            self.assertEqual(report["status"], "reconstructed")
            self.assertEqual(len(report["calls"]), count)
            self.assertEqual(report["finalityCall"]["index"], str(count - 1))
            self.assertEqual(keccak256(hex_bytes(report["actionIdPreimage"])), report["actionId"])
            self.assertEqual(report["originalNonce"], "0") # observed tx.nonce is511
            self.assertFalse(report["claims"]["completeAuthority"])
            self.assertFalse(report["claims"]["transactionHashesRecomputed"])
            self.assertEqual(dumps(value["nativeFinality"]), before)
            self.assertFalse(value["nativeFinality"]["claims"]["executionTransactionInputCaptured"])

    def test_missing_inputs_stay_partial_even_when_one_batch_recovers_preimages(self):
        for batch in (False, True):
            for side in ("schedule", "execution"):
                value = self.fresh(batch=batch)
                value["transactions"][side].update(status="not_returned", transactionBytes=None, normalized=None)
                rederive(value); result = profile.validate(dumps(value))
                self.assertEqual(result["status"], "partial")
                self.assertFalse(result["claims"]["bothOriginalTransactionInputsDecoded"])
                self.assertEqual(result["claims"]["fullGovernanceCallMetadataReconstructed"], batch or side == "execution")
        value = self.fresh()
        for row in value["transactions"].values(): row.update(status="not_returned", transactionBytes=None, normalized=None)
        rederive(value); self.assertIsNone(profile.validate(dumps(value))["calls"])

    def test_indirect_unknown_and_noncanonical_input_remain_retained_partial(self):
        for edit in (lambda tx: tx.update(to=A(99991)), lambda tx: tx.update(to=None),
                lambda tx: tx.update(input="0x12345678"), lambda tx: tx.update(input=tx["input"] + "00")):
            value = self.fresh(); transaction_edit(value, "schedule", edit, actors=True); rederive(value)
            raw = value["transactions"]["schedule"]["transactionBytes"]
            self.assertEqual(profile.validate(dumps(value))["status"], "partial")
            self.assertEqual(value["transactions"]["schedule"]["transactionBytes"], raw)

    def test_legacy_missing_chain_id_and_missing_receipt_actors_are_not_fabricated(self):
        value = self.fresh()
        for side in value["transactions"]:
            transaction_edit(value, side, lambda tx: tx.pop("chainId"))
            receipt = unblob(value["transactions"][side]["receiptBytes"])
            receipt.pop("from"); receipt.pop("to"); value["transactions"][side]["receiptBytes"] = blob(receipt)
        self.assertEqual(profile.validate(dumps(value))["status"], "reconstructed")
        self.assertEqual(value["chainBoundBy"], "source_anchor_and_block")
        transaction_edit(value, "schedule", lambda tx: tx.update(chainId="0x1"))
        self.reject(value, "transaction chain")

    def test_raw_transaction_identity_normalization_and_known_actor_conflicts(self):
        for key, bad in (("hash", H("wrong")), ("blockHash", H("wrong block")), ("transactionIndex", "0x1")):
            value = self.fresh(); transaction_edit(value, "schedule", lambda tx: tx.update({key: bad})); self.reject(value, "transaction/receipt")
        value = self.fresh(); value["transactions"]["schedule"]["normalized"]["value"] = "1"; self.reject(value, "normalization")
        value = self.fresh(); transaction_edit(value, "schedule", lambda tx: tx.update({"from": A(99992)})); self.reject(value, "transaction/receipt")

    def test_original_receipt_and_complete_log_correspondence(self):
        for mutation in ("status", "omit", "order", "extra_matching", "coordinates"):
            value = self.fresh(); row = value["transactions"]["execution"]; receipt = unblob(row["receiptBytes"])
            if mutation == "status": receipt["status"] = "0x0"
            if mutation == "omit": receipt["logs"].pop(0)
            if mutation == "order": receipt["logs"].reverse()
            if mutation == "extra_matching":
                log = copy.deepcopy(receipt["logs"][-1]); log["logIndex"] = hex(int(log["logIndex"], 16) + 1); receipt["logs"].append(log)
            if mutation == "coordinates": receipt["logs"][0]["transactionIndex"] = "0x0"
            row["receiptBytes"] = blob(receipt); self.reject(value)

    def test_unrelated_original_receipt_log_is_preserved(self):
        value = self.fresh(); row = value["transactions"]["execution"]; receipt = unblob(row["receiptBytes"])
        log = copy.deepcopy(receipt["logs"][-1]); log.update(address=A(39999), topics=[H("unrelated")], data="0x",
            logIndex=hex(int(log["logIndex"], 16) + 1)); receipt["logs"].append(log)
        row["receiptBytes"] = blob(receipt)
        self.assertEqual(profile.validate(dumps(value))["status"], "reconstructed")

    def test_headers_must_match_original_slot_time_and_number(self):
        for mutation in ("slot", "number", "time", "hash"):
            value = self.fresh(); header = unblob(value["headers"][0])
            if mutation == "slot": header["transactions"][-1] = H("other-tx")
            if mutation == "number": header["number"] = "0x2"
            if mutation == "time": header["timestamp"] = hex(int(header["timestamp"], 16) + 1)
            if mutation == "hash": header["hash"] = H("other-header")
            value["headers"][0] = blob(header); self.reject(value)
        value = self.fresh(); value["headers"][1] = value["headers"][0]; self.reject(value, "duplicate header")
        value = self.fresh(); value["headers"].reverse(); self.reject(value, "header order")

    def test_reconstruction_tamper_and_status_fabrication_are_not_accepted(self):
        value = self.fresh(); value["reconstruction"]["originalNonce"] = "511"; self.reject(value, "derived reconstruction")
        value = self.fresh(); value["reconstruction"]["calls"][0]["oldValueHash"] = H("wrong old"); self.reject(value, "derived reconstruction")
        value = self.fresh(); value["transactions"]["schedule"]["status"] = "not_returned"; self.reject(value, "fabricated input")
        value = self.fresh(); value["reconstruction"]["claims"]["completeAuthority"] = True; self.reject(value)

    def test_supplied_source_refs_are_not_self_authenticating(self):
        value = self.fresh(); value["sourceRef"]["anchorHash"] = H("other supplied pin")
        self.assertEqual(profile.validate(dumps(value))["status"], "reconstructed")
        value["sourceState"]["collectionId"] = "2"; self.reject(value, "source/native finality state")
        value = self.fresh(); value["sourceRef"]["provenance"] = "trusted_rpc"; self.reject(value, "source provenance")

    def test_original_raw_json_is_canonical_and_bounded(self):
        value = self.fresh(); row = value["transactions"]["schedule"]
        row["transactionBytes"] += "0a"; self.reject(value)
        value = self.fresh(); row = value["transactions"]["schedule"]
        row["transactionBytes"] = "0x" + (b" " * (profile.MAX_ORIGINAL_BYTES + 1)).hex(); self.reject(value)

    def test_schema_preserves_frozen_definition_hash_and_no_generated_file_yet(self):
        self.assertEqual(loads(profile.SCHEMA_BYTES, maximum=profile.MAX_BYTES)["x-stream-native-finality"]["hash"], native.SCHEMA_HASH)
        self.assertEqual((native.ROOT / "schemas/records/STREAM_ACQUISITION_NATIVE_FINALITY_V1.json").read_bytes(), native.SCHEMA_BYTES)
        self.assertIn(b'"completeAuthority":{"const":false}', profile.SCHEMA_BYTES)

    def test_projector_binds_exact_snapshot_source_pins_without_mutating_native(self):
        from tools.museum import public_governance_transaction_source as source
        value = self.fresh()
        snapshot = {"profile": source.PROFILE, "profileHash": source.PROFILE_HASH, "version": "1",
            "sourceReviewCommit": profile.SOURCE_REVISION, "anchorHash": H("anchor"), "transcriptHash": H("transcript"),
            "provenance": "synthetic_fixture", "qualification": source.QUALIFICATION}
        for key in ("sourceState", "nativeFinality", "headers", "transactions", "reconstruction"):
            snapshot[key] = copy.deepcopy(value[key])
        refs = {"sourceProfileHash": source.PROFILE_HASH, "anchorHash": snapshot["anchorHash"],
            "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)), "provenance": "synthetic_fixture"}
        result = profile.semanticProjection(snapshot, refs)
        self.assertEqual(dumps(result["nativeFinality"]), dumps(value["nativeFinality"]))
        self.assertEqual(profile.validate(dumps(result)), value["reconstruction"])
        for key in native.SOURCE_REF_FIELDS[:-1]:
            bad = dict(refs); bad[key] = H("other pin")
            with self.assertRaises(MuseumError): profile.semanticProjection(snapshot, bad)
        broken = copy.deepcopy(snapshot); del broken["headers"]
        bad = dict(refs, snapshotHash=keccak256(dumps(broken)))
        with self.assertRaises(MuseumError): profile.semanticProjection(broken, bad)


if __name__ == "__main__": unittest.main()
