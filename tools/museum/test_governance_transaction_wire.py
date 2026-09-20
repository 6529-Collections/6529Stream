"""Synthetic ABI transaction vectors; no chain, EVM, signatures or RPC proof."""
import copy
import unittest

from . import governance_transaction_wire as w
from . import native_finality_wire as f
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, decode, encode
from .independent_wire import ZERO_ADDRESS, json_values
from .test_native_finality_wire import A, H, event_rows, supplied as finality_supplied


def _json(value):
    if type(value) is dict: return {key: _json(item) for key, item in value.items()}
    if type(value) in (tuple, list): return [_json(item) for item in value]
    return json_values(value)


def _hashes(calls, chain, executor, action, nonce):
    """Independent literal native ABI recipe, not calls through wire hash helpers."""
    digest = keccak256(encode(("bytes32", Array(w.CALL)), (
        "0x10f09566fb70f7947b61639c2a53b3aec872069a8b46edd08ba14eb2b5942b70", calls)))
    folds = tuple(keccak256(encode(("bytes32", "bytes32", Array("bytes32")), (domain, digest,
        tuple(row[index] for row in calls)))) for domain, index in zip((
        "0x6cfd5dfd67f064adac45602c05057edddda810734779c0ebe11b447e6985e31c",
        "0xc5029f937b44065c2ad92d9253e07f06117567480206189fcc1409d5509222b7",
        "0xce958009248d20d9574439fa374bc00c142940af2b496896b5bdbc00b882e98b"), (4, 5, 6)))
    identity = (action[1], digest, *folds, nonce, action[9], action[10], action[15], action[17])
    preimage = encode(("bytes32", "uint256", "address", *w.IDENTITY), (
        "0x214cd728538bb3775a7106caff5c761bace11866a984d4a4d97a98f51971ac4b", chain, executor, *identity))
    return digest, folds, keccak256(preimage)


def _inputs(calls, data, action, action_id, executor, schedule_kind, execution_kind):
    if schedule_kind == "schedule_batch":
        schedule_args = (action[1], calls, *action[6:11], *action[15:])
    else:
        assert len(calls) == 1
        row = calls[0]
        schedule_args = ((action[1], row[0], row[1], row[2], data[0], *row[4:], *action[9:11], *action[15:]),)
    execution_args = (action_id, calls, data) if execution_kind == "execute_batch" else (action_id, data[0])
    return {
        "schedule": {"to": executor, "from": action[11], "value": "0",
            "input": w.SELECTORS[schedule_kind] + encode(w.TYPES[schedule_kind], schedule_args).hex()},
        "execution": {"to": executor, "from": action[12], "value": str(action[3]),
            "input": w.SELECTORS[execution_kind] + encode(w.TYPES[execution_kind], execution_args).hex()}}


def _events(action, action_id, executor, nonce):
    topics = [action_id, "0x" + encode(("uint8",), (action[1],)).hex(), "0x" + encode(("address",), (action[2],)).hex()]
    return ({"address": executor, "topics": [f.EVENTS["governanceScheduled"], *topics],
        "data": "0x" + encode(f.GOVERNANCE_SCHEDULED_DATA, (1, *action[3:11], nonce, action[11], *action[15:])).hex()},
        {"address": executor, "topics": [f.EVENTS["governanceExecuted"], *topics],
        "data": "0x" + encode(f.GOVERNANCE_EXECUTED_DATA, (1, *action[3:9], action[12], action[17])).hex()})


def action_vector(*, count=2, calls=None, data=None, schedule_kind="schedule_batch", execution_kind="execute_batch", action_class=2):
    """Return exact verify_action kwargs for synthetic native source ABI bytes."""
    chain, executor, nonce = 31337, A(27001), 17
    if data is None: data = tuple(hex_bytes("0x12345678") + encode(("uint256",), (i + 1,)) for i in range(count))
    if calls is None: calls = tuple((A(28000 + i), 0, "0x12345678", keccak256(raw), H((i, "scope")), H((i, "old")), H((i, "new")))
                                    for i, raw in enumerate(data))
    action = [3, action_class, calls[0][0], sum(row[1] for row in calls), calls[0][2], H("opaque"),
        H("aggregate-scope"), H("aggregate-old"), H("aggregate-new"), 1780000000, 1790000000,
        A(27002), A(27003), ZERO_ADDRESS, ZERO_ADDRESS, H("reason"), "arbitrary original reason", H("manifest")]
    digest, folds, action_id = _hashes(calls, chain, executor, action, nonce)
    action[5:9] = [digest, *folds]
    scheduled, executed = _events(action, action_id, executor, nonce)
    return {"transactions": _inputs(calls, data, action, action_id, executor, schedule_kind, execution_kind),
        "chain_id": str(chain), "executor": executor, "action": _json(action), "expected_action_id": action_id,
        "scheduled_event": scheduled, "executed_event": executed, "call_datas": _json(data)}


def bind_transactions(bundle, context, graph, *, calls=None, schedule_kind="schedule_batch", execution_kind="execute_batch"):
    """Build original raw synthetic governance facts before any source capture.

    Mutates only the caller's new synthetic bundle; never changes a retained
    package. Returns (normalized transactions, coherent original event rows).
    Explicit calls correspond exactly to bundle.execution.callDatas.
    """
    old = f.validate_bundle(bundle, context, graph)
    data = tuple(hex_bytes(value) for value in bundle["execution"]["callDatas"])
    index = int(old["execution"]["matchedCallIndex"])
    if calls is None:
        calls = tuple((graph["finality"]["address"] if i == index else A(28000 + i), 0,
            "0x" + raw[:4].hex(), keccak256(raw),
            *(old["executionContext"][key] if i == index else H((i, key))
                for key in ("scopeHash", "oldValueHash", "newValueHash"))) for i, raw in enumerate(data))
    action = list(f.from_json(f.GOVERNANCE_ACTION, bundle["execution"]["action"]))
    action[2:5] = [calls[0][0], sum(row[1] for row in calls), calls[0][2]]
    digest, folds, action_id = _hashes(calls, int(context["chainId"]), graph["executor"]["address"], action, 17)
    action[5:9] = [digest, *folds]
    bundle["execution"]["action"] = _json(action)
    bundle["finality"]["executionWitness"][0] = action_id
    bundle["execution"]["runtime"] = "0x" + (b"\0" + encode((Array("bytes"),), (data,))).hex()
    transactions = _inputs(calls, data, action, action_id, graph["executor"]["address"], schedule_kind, execution_kind)
    return transactions, event_rows(bundle, context, graph)


def supplied(context=None, graph=None, *, extra_call=True, schedule_kind="schedule_batch", execution_kind="execute_batch", **kwargs):
    """Return (bundle, context, graph, transactions, events), explicitly synthetic.

    kwargs pass through to the frozen pure finality fixture. By default finality
    is the second call, making its index different from the stored first target.
    """
    bundle, context, graph = finality_supplied(context, graph, **kwargs)
    if extra_call:
        bundle["execution"]["callDatas"].insert(0, "0x12345678" + encode(("uint256",), (77,)).hex())
        raw = tuple(hex_bytes(value) for value in bundle["execution"]["callDatas"])
        bundle["execution"]["runtime"] = "0x" + (b"\0" + encode((Array("bytes"),), (raw,))).hex()
    transactions, events = bind_transactions(bundle, context, graph, schedule_kind=schedule_kind, execution_kind=execution_kind)
    return bundle, context, graph, transactions, events


class GovernanceTransactionWireTests(unittest.TestCase):
    def test_literal_selectors_and_independent_action_preimage(self):
        for name, signature in w.SIGNATURES.items(): self.assertEqual(w.SELECTORS[name], schema_id(signature)[:10])
        vector = action_vector(); result = w.verify_action(**vector)
        self.assertEqual(result["status"], "reconstructed")
        self.assertEqual(keccak256(hex_bytes(result["actionIdPreimage"])), vector["expected_action_id"])
        self.assertEqual(len(hex_bytes(result["actionIdPreimage"])), 13 * 32)
        self.assertEqual(result["callsHash"], "0x614955512d05d1e6bc4431050330734ac3c5419fce30ea0693d169d8b7188c88")
        self.assertEqual(result["actionId"], "0x7107f50708ff0ef179b7905e06508873fc293a7d15aa4c2d5e87c94e9b846def")
        calls = w.decode_schedule(vector["transactions"]["schedule"]["input"])["calls"]
        self.assertEqual(w.calls_hash(calls), vector["action"][5])
        self.assertNotEqual(calls[0][4], vector["action"][6])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["historicalRoleAuthorizationReexecuted"])

    def test_all_single_wrapper_and_batch_combinations_same_action_id(self):
        ids = set()
        for schedule in ("schedule_action", "schedule_batch"):
            for execution in ("execute_action", "execute_batch"):
                with self.subTest(schedule=schedule, execution=execution):
                    vector = action_vector(count=1, schedule_kind=schedule, execution_kind=execution)
                    result = w.verify_action(**vector); ids.add(result["actionId"])
                    self.assertEqual(result["status"], "reconstructed")
                    self.assertTrue(result["claims"]["bothOriginalTransactionInputsDecoded"])
        self.assertEqual(len(ids), 1)

    def test_partial_input_matrix_never_infers_private_single_transitions(self):
        for schedule, execution, metadata in ((None, None, False), (None, "execute_action", False),
                (None, "execute_batch", True), ("schedule_action", None, True), ("schedule_batch", None, True)):
            with self.subTest(schedule=schedule, execution=execution):
                vector = action_vector(count=1, schedule_kind=schedule or "schedule_batch", execution_kind=execution or "execute_batch")
                if schedule is None: vector["transactions"]["schedule"] = None
                if execution is None: vector["transactions"]["execution"] = None
                result = w.verify_action(**vector)
                self.assertEqual(result["status"], "partial")
                self.assertEqual(result["claims"]["fullGovernanceCallMetadataReconstructed"], metadata)
                self.assertEqual(result["claims"]["actionIdPreimageReconstructed"], metadata)
                self.assertEqual(result["calls"] is not None, metadata)
                if execution == "execute_action":
                    self.assertIn("single_execution_first_call_transitions_unavailable", result["reasons"])

    def test_missing_schedule_does_not_hide_single_execution_data_contradiction(self):
        vector = action_vector(count=1, execution_kind="execute_action")
        vector["transactions"]["schedule"] = None
        vector["call_datas"][0] = vector["call_datas"][0][:-2] + "02"
        with self.assertRaisesRegex(MuseumError, "transaction/saved calldata"):
            w.verify_action(**vector)

    def test_unknown_outer_recipient_and_selector_are_partial(self):
        for field, value, reason in (("to", A(9), "outer_recipient_not_executor"), ("to", None, "outer_recipient_not_executor"),
                ("input", "0x01020304", "outer_selector_unsupported")):
            vector = action_vector(); vector["transactions"]["schedule"][field] = value
            result = w.verify_action(**vector)
            self.assertEqual(result["status"], "partial")
            self.assertIn("schedule_" + reason, result["reasons"])
            self.assertTrue(result["claims"]["actionIdPreimageReconstructed"])

    def test_noncanonical_input_is_retained_as_partial_not_native_rejection(self):
        for side in ("schedule", "execution"):
            for mutation in ("tail", "truncated", "uint_padding", "offset"):
                vector = action_vector(); raw = bytearray(hex_bytes(vector["transactions"][side]["input"]))
                if mutation == "tail": raw.extend(b"\0" * 32)
                if mutation == "truncated": del raw[-1]
                if mutation == "uint_padding":
                    # Narrow actionClass for schedule; address high padding in execution CALLS.
                    raw[4 if side == "schedule" else 4 + 128] = 1
                if mutation == "offset": raw[4 + (32 if side == "schedule" else 32):4 + 64] = (4096).to_bytes(32, "big")
                vector["transactions"][side]["input"] = "0x" + raw.hex()
                with self.subTest(side=side, mutation=mutation):
                    result = w.verify_action(**vector)
                    self.assertEqual(result["status"], "partial")
                    self.assertIn(side + "_unsupported_noncanonical_input", result["reasons"])

    def test_postdecode_context_hash_and_order_contradictions_fail(self):
        for mutation in ("scope", "order", "data", "data_count", "calls_hash"):
            vector = action_vector()
            side = "schedule" if mutation == "scope" else "execution"
            kind = "schedule_batch" if side == "schedule" else "execute_batch"
            values = list(decode(w.TYPES[kind], hex_bytes(vector["transactions"][side]["input"])[4:]))
            if mutation == "scope": values[2] = H("different-aggregate")
            if mutation == "order": values[1] = tuple(reversed(values[1]))
            if mutation == "data": values[2] = (values[2][0], values[2][0])
            if mutation == "data_count": values[2] = values[2][:-1]
            if mutation == "calls_hash":
                changed = list(values[1][0]); changed[3] = H("different-data"); values[1] = (tuple(changed), *values[1][1:])
            vector["transactions"][side]["input"] = w.SELECTORS[kind] + encode(w.TYPES[kind], values).hex()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.verify_action(**vector)

    def test_direct_callers_values_reason_uri_and_nonce_are_original_facts(self):
        for mutation in ("proposer", "executor", "schedule_value", "execution_value", "uri", "nonce"):
            vector = action_vector()
            if mutation == "proposer": vector["transactions"]["schedule"]["from"] = A(999)
            if mutation == "executor": vector["transactions"]["execution"]["from"] = A(999)
            if mutation == "schedule_value": vector["transactions"]["schedule"]["value"] = "1"
            if mutation == "execution_value": vector["transactions"]["execution"]["value"] = "1"
            if mutation == "uri":
                values = list(decode(w.SCHEDULE_BATCH, hex_bytes(vector["transactions"]["schedule"]["input"])[4:]))
                values[8] = "different URI outside action ID"
                vector["transactions"]["schedule"]["input"] = w.SELECTORS["schedule_batch"] + encode(w.SCHEDULE_BATCH, values).hex()
            if mutation == "nonce":
                values = list(decode(f.GOVERNANCE_SCHEDULED_DATA, hex_bytes(vector["scheduled_event"]["data"])))
                values[9] += 1; vector["scheduled_event"]["data"] = "0x" + encode(f.GOVERNANCE_SCHEDULED_DATA, values).hex()
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.verify_action(**vector)

    def test_cross_chain_and_executor_preimages_cannot_be_reused(self):
        vector = action_vector(); vector["chain_id"] = "1"
        with self.assertRaisesRegex(MuseumError, "action ID preimage"): w.verify_action(**vector)
        vector = action_vector(); vector["executor"] = A(999)
        for row in vector["transactions"].values(): row["to"] = vector["executor"]
        vector["scheduled_event"]["address"] = vector["executed_event"]["address"] = vector["executor"]
        with self.assertRaisesRegex(MuseumError, "action ID preimage"): w.verify_action(**vector)

    def test_single_execution_cannot_claim_a_multi_call_schedule(self):
        vector = action_vector(execution_kind="execute_action")
        with self.assertRaises(MuseumError): w.verify_action(**vector)

    def test_native_value_empty_calldata_and_selector_semantics(self):
        calls = ((A(88), 7, "0x00000000", keccak256(b""), H("scope"), H("old"), H("new")),)
        vector = action_vector(calls=calls, data=(b"",), action_class=1)
        self.assertEqual(w.verify_action(**vector)["calls"][0]["value"], "7")
        for changed in ((A(88), 0, *calls[0][2:]), (A(88), 7, "0x12345678", *calls[0][3:])):
            with self.assertRaises(MuseumError): w.verify_action(**action_vector(calls=(changed,), data=(b"",), action_class=1))
        with self.assertRaises(MuseumError): w.verify_action(**action_vector(calls=calls, data=(b"",), action_class=0))

    def test_consumer_limits_and_closed_observations(self):
        vector = action_vector(count=64); self.assertEqual(len(w.verify_action(**vector)["calls"]), 64)
        for mutation in ("extra", "boolean_value", "nonhex_input", "zero_chain", "huge_input", "carrier"):
            vector = action_vector()
            if mutation == "extra": vector["transactions"]["schedule"]["accepted"] = True
            if mutation == "boolean_value": vector["transactions"]["schedule"]["value"] = True
            if mutation == "nonhex_input": vector["transactions"]["schedule"]["input"] = b"\x12\x34\x56\x78"
            if mutation == "zero_chain": vector["chain_id"] = "0"
            if mutation == "huge_input": vector["transactions"]["schedule"]["input"] = "0x" + "00" * (w.MAX_TRANSACTION_BYTES + 1)
            if mutation == "carrier": vector["call_datas"] = ["0x" + "00" * w.MAX_CARRIER_BYTES]
            with self.subTest(mutation=mutation), self.assertRaises(MuseumError): w.verify_action(**vector)
        with self.assertRaises(MuseumError): w.calls_hash([*w.decode_schedule(action_vector()["transactions"]["schedule"]["input"])["calls"]] * 33)
        huge = (A(88), (1 << 256) - 1, "0x12345678", H("data"), H("s"), H("o"), H("n"))
        with self.assertRaisesRegex(MuseumError, "overflow"): w.calls_hash((huge, huge))

    def test_complete_finality_call_is_matched_at_actual_index(self):
        bundle, context, graph, transactions, events = supplied()
        result = w.verify(bundle, context, graph, transactions, events)
        self.assertEqual(result["finalityCall"]["index"], "1")
        self.assertNotEqual(result["calls"][0]["target"], graph["finality"]["address"])
        self.assertEqual(result["finalityCall"]["target"], graph["finality"]["address"])
        self.assertTrue(result["claims"]["actionIdPreimageReconstructed"])
        transactions["schedule"] = None
        self.assertEqual(w.verify(bundle, context, graph, transactions, events)["status"], "partial")

    def test_coherently_rehashed_wrong_finality_call_metadata_rejects(self):
        for mutation in ("target", "value", "scope", "old", "new"):
            bundle, context, graph, transactions, events = supplied()
            calls = list(w.decode_schedule(transactions["schedule"]["input"])["calls"])
            final_call = list(calls[1])
            index = {"target": 0, "value": 1, "scope": 4, "old": 5, "new": 6}[mutation]
            final_call[index] = A(999) if mutation == "target" else 1 if mutation == "value" else H("different")
            calls[1] = tuple(final_call)
            transactions, events = bind_transactions(bundle, context, graph, calls=tuple(calls))
            # All native action hashes, original calldata, event bytes and IDs
            # agree; only the finality execution-context correspondence fails.
            with self.subTest(mutation=mutation), self.assertRaisesRegex(MuseumError, "original finality call"):
                w.verify(bundle, context, graph, transactions, events)


if __name__ == "__main__": unittest.main()
