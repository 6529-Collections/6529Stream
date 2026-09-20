"""Independent original V1/V2 VIEW adoption vectors for the e0b4 reader."""
from copy import deepcopy
import unittest

from . import view_policy_adoption_wire_v2 as w
from . import view_policy_adoption_types_v2 as t
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values
from .native_view_policy_output_wire_v2 import GRAPH_KEYS
from .test_view_policy_membership_v2 import supplied as membership_supplied
from .view_policy_adoption_source_reads_v2 import ViewPolicyAdoptionReads

LEGACY_RENDERER_RUNTIME = b"synthetic legacy VIEW renderer"

def A(n): return "0x" + format(n, "040x")
def H(value): return schema_id("VIEW adoption test " + str(value))


def _graph(context):
    graph = {name: {"address": A(1000 + index),
        "runtimeHash": keccak256(("synthetic VIEW " + name).encode())}
        for index, name in enumerate(GRAPH_KEYS)}
    graph["core"]["address"] = context["core"]
    return graph


def _manifest(profile, cid, view_id, revision, previous, payload):
    schema = schema_id("STREAM_STATIC_VIEW_PAYLOAD_V1") if profile == ZERO else schema_id("STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2")
    manifest = (view_id, schema, "ipfs://view-payload", keccak256(payload),
        "application/octet-stream", False)
    raw = encode(("uint256", "uint64", "bytes32", t.VIEW_MANIFEST), (cid, revision, previous, manifest))
    return manifest, raw


def _renderer(profile, graph, binding):
    rid = schema_id("6529STREAM_ADOPTED_VIEW_RENDERER_V1") if profile == ZERO else schema_id("6529STREAM_ADOPTED_POLICY_VIEW_RENDERER_V2")
    version = schema_id("6529STREAM_STATIC_ADOPTED_VIEW_RENDERER_V1") if profile == ZERO else schema_id("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_RENDERER_V2")
    context = t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT
    output = keccak256(w.V1_OUTPUT_SCHEMA_BYTES if profile == ZERO else w.V2_OUTPUT_SCHEMA_BYTES)
    manifest = (rid, version, context, schema_id("STATIC"), output, "", "", H("renderer manifest"),
        262144, 262144, False)
    if profile == ZERO:
        targets = (graph["core"]["address"], graph["router"]["address"], A(7000), graph["attribution"]["address"])
        pins = (graph["core"]["runtimeHash"], graph["router"]["runtimeHash"], H("legacy entropy"),
            graph["attribution"]["runtimeHash"])
        encoding = encoding_hash = None
    else:
        targets = (graph["core"]["address"], graph["router"]["address"], binding[4], graph["attribution"]["address"])
        pins = (graph["core"]["runtimeHash"], graph["router"]["runtimeHash"], binding[5],
            graph["attribution"]["runtimeHash"])
        encoding, encoding_hash = graph["rendererEncoding"]["address"], graph["rendererEncoding"]["runtimeHash"]
    return {"sourceTargets": json_values(targets), "sourcePins": json_values(pins),
        "encoding": encoding, "encodingRuntimeHash": encoding_hash, "manifest": json_values(manifest)}


def supplied(*, context=None, graph=None, policy_binding=None, later_head=True,
             include_v1=True, adopted_at=103, foreign_v1_core=False):
    external_binding = policy_binding is not None
    context = deepcopy(context) if context is not None else {"chainId": "31337", "core": A(1),
        "collectionId": "7", "tokenId": "41", "timestamp": "120", "blockNumber": "20",
        "blockHash": H("source block"), "stateRoot": H("state"),
        "environment": "local_evm_fixture", "deploymentEvidenceHash": H("deployment")}
    graph = deepcopy(graph) if graph is not None else _graph(context)
    if policy_binding is None:
        _, _, _, binding_json = membership_supplied(3, context=context, graph=graph, recorded_at=101)
    else:
        binding_json = deepcopy(policy_binding)
    binding = w._v(t.POLICY_BINDING, binding_json)
    chain, cid, router, core = int(context["chainId"]), int(context["collectionId"]), graph["router"]["address"], graph["core"]["address"]
    route = (*((graph[k]["address"], graph[k]["runtimeHash"]) for k in
        ("core", "router", "artist", "finality", "provider", "metadata", "schemas", "store")),)
    route = tuple(v for pair in route for v in pair) + ((graph["views"]["address"],
        graph["views"]["runtimeHash"], graph["scopeMembership"]["address"],
        graph["scopeMembership"]["runtimeHash"], 100000, 1000000),)
    rows = []
    aggregate_chain = ZERO; heads = {}; revisions = {}; declaration_heads = {}; declaration_revisions = {}

    def add(profile, scope_id, view_id, timestamp, block, tx, log):
        nonlocal aggregate_chain
        scope = (4, cid, 0, scope_id); key = tuple(scope); previous = heads.get(key, ZERO)
        policy = binding if profile == t.V2_PROFILE else None
        row_route = route
        if profile == ZERO and foreign_v1_core:
            row_route = (A(7998), H("foreign historical core"), *route[2:])
        row_core = row_route[0]
        payload = encode((t.PAYLOAD,), ((t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT,
            "Example view", "Synthetic retained bytes", "ipfs://image", b"window.example=true;"),))
        declaration_previous = declaration_heads.get(view_id, ZERO)
        declaration_revision = declaration_revisions.get(view_id, 0) + 1
        manifest, manifest_raw = _manifest(profile, cid, view_id, declaration_revision, declaration_previous, payload)
        receipt = (cid, view_id, declaration_revision, declaration_previous, A(8000), 7, cid, 1,
            timestamp - 1, len(rows), H("declaration chain " + str(len(rows))),
            keccak256(w.V1_PAYLOAD_SCHEMA_BYTES if profile == ZERO else w.V2_PAYLOAD_SCHEMA_BYTES),
            keccak256(w.MANIFEST_SCHEMA_BYTES), keccak256(w.RAW_DEFINITION_BYTES))
        original = (w.DISPLAY_VIEW_MANIFEST, w.scope_subject(chain, row_core, scope),
            (1, hex_bytes(keccak256(manifest_raw)), w.RAW_BYTES), manifest[2],
            schema_id("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"), ZERO, (0, b"", ZERO), 0)
        declaration_hash = generic_hash(chain, graph["views"]["address"], row_core, cid, receipt[4], original)
        registry = (A(7301), H("legacy registry")) if profile == ZERO else (
            graph["rendererRegistry"]["address"], graph["rendererRegistry"]["runtimeHash"])
        renderer = (A(7300), keccak256(LEGACY_RENDERER_RUNTIME)) if profile == ZERO else (
            graph["renderer"]["address"], graph["renderer"]["runtimeHash"])
        selected_manifest = (registry[0], registry[1], ZERO,
            renderer[0], renderer[1], ZERO, ZERO,
            t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT, ZERO, H("read set"), H("registration"))
        renderer_info = _renderer(profile, graph, binding)
        if profile == ZERO and foreign_v1_core:
            renderer_info["sourceTargets"][0] = row_core
            renderer_info["sourcePins"][0] = row_route[1]
        rm = w._v(t.RENDERER_MANIFEST, renderer_info["manifest"])
        version_key = keccak256(encode(("bytes32", "bytes32", "bytes32"), (w.VERSION_DOMAIN, rm[0], rm[1])))
        selected_manifest = (*selected_manifest[:2], version_key, *selected_manifest[3:5], rm[0], rm[1], rm[2], rm[4],
            selected_manifest[9], selected_manifest[10])
        chunks = [payload[i:i + 8192] for i in range(0, len(payload), 8192)]
        pointers = tuple(A(9000 + len(rows) * 10 + i) for i in range(len(chunks)))
        padded_pointers = pointers + (ZERO_ADDRESS,) * (t.MAX_CHUNKS - len(chunks))
        padded_hashes = tuple(keccak256(part) for part in chunks) + (ZERO,) * (t.MAX_CHUNKS - len(chunks))
        membership = list(binding[8]); membership[0] = w.scope_subject(chain, row_core, scope)
        source = (row_route, tuple(membership), selected_manifest,
            receipt[11], receipt[12], receipt[13], keccak256(manifest_raw),
            keccak256(encode((t.VIEW_RECEIPT,), (receipt,))), keccak256(payload), len(payload),
            padded_pointers, padded_hashes)
        input_ = [scope, view_id, declaration_hash, previous, registry[0], version_key, ZERO]
        record = [tuple(input_), source, ZERO, ZERO, 0, A(8100), 7, cid, 1,
            H("artist consent " + str(len(rows))), timestamp, (0, ZERO)]
        source_value = w.source_hash(profile, chain, router, tuple(record), policy)
        input_[6] = source_value; record[0] = tuple(input_); record[2] = source_value
        revision = revisions.get(key, 0) + 1; record[4] = revision
        aggregate_revision = len(rows) + 1
        aggregate_chain = w.next_aggregate(profile, chain, router, row_core, cid, aggregate_chain,
            aggregate_revision, w.scope_subject(chain, core, scope), previous,
            w.prepared_hash(profile, tuple(record)))
        record[11] = (aggregate_revision, aggregate_chain)
        record[3] = w.record_hash(profile, chain, router, row_core, tuple(record)); record = tuple(record)
        encoded = encode((t.RECORD,), (record,))
        declaration = {"manifest": json_values(manifest), "receipt": json_values(receipt),
            "record": json_values(original), "manifestPayload": "0x" + manifest_raw.hex(),
            "manifestCarrier": {"pointer": A(9500 + len(rows)),
                "codeHash": keccak256(b"\0" + manifest_raw), "runtime": "0x" + (b"\0" + manifest_raw).hex()},
            "viewPayload": "0x" + payload.hex(),
            "payloadChunks": [{"pointer": pointers[i], "codeHash": keccak256(b"\0" + part),
                "runtime": "0x" + (b"\0" + part).hex()} for i, part in enumerate(chunks)],
            "renderer": renderer_info}
        event = (1 if profile == ZERO else 2, profile, cid, w.scope_subject(chain, row_core, scope), record[3],
            record, block, H("block " + str(block)), H("tx " + str(block) + ":" + str(tx)), tx, log, timestamp)
        rows.append({"profile": profile, "record": json_values(record), "encoded": "0x" + encoded.hex(),
            "carrier": {"pointer": A(9800 + len(rows)), "codeHash": keccak256(b"\0" + encoded),
                "runtime": "0x" + (b"\0" + encoded).hex()}, "event": json_values(event),
            "declaration": declaration, "policyBinding": None if policy is None else json_values(policy)})
        heads[key], revisions[key] = record[3], revision
        declaration_heads[view_id], declaration_revisions[view_id] = declaration_hash, declaration_revision
        return record[3]

    target_scope_id = binding[7][3]
    if include_v1: add(ZERO, H("other scope"), H("legacy view"), 102, 2, 0, 0)
    selected = add(t.V2_PROFILE, target_scope_id, H("target view"), adopted_at, 3, 0, 0)
    if later_head: add(t.V2_PROFILE, target_scope_id, H("target view"), 106, 6, 0, 0)
    serving_binding = (core, graph["core"]["runtimeHash"], router, graph["router"]["runtimeHash"],
        chain, 100000)
    serving_hash = w.serving_configuration_hash(chain, graph["serving"]["address"],
        serving_binding, graph["servingWorker"]["address"], graph["servingWorker"]["runtimeHash"])
    value = {"version": "1", "chainId": str(chain), "router": router,
        "routerRuntimeHash": graph["router"]["runtimeHash"], "scope": json_values(binding[7]),
        "selectedRecordHash": selected, "head": heads[tuple(binding[7])],
        "aggregate": json_values((len(rows), aggregate_chain)), "history": rows,
        "serving": {"binding": json_values(serving_binding),
            "worker": graph["servingWorker"]["address"],
            "workerRuntimeHash": graph["servingWorker"]["runtimeHash"],
            "configurationHash": serving_hash}}
    return value if external_binding else (value, context, graph)


def install_adoption_reads(fixture, value, context, graph):
    """Install exact historical getters/carriers; events remain parent-owned."""
    scope = w._v(t.SCOPE, value["scope"]); router = graph["router"]["address"]
    fixture.add(router, "viewAdoptionHead((uint8,uint256,uint256,bytes32))", (t.SCOPE,),
        (scope,), ("bytes32",), (value["head"],))
    fixture.add(router, "viewAdoptionAggregate(uint256)", ("uint256",), (scope[1],),
        (t.AGGREGATE,), (w._v(t.AGGREGATE, value["aggregate"]),))
    for item in value["history"]:
        record = w._v(t.RECORD, item["record"]); key = record[3]
        host = record[1][0][16][0]
        if host not in fixture.codes:
            for role, observed in graph.items():
                if observed["address"] == host:
                    _install_runtime(fixture, host, ("synthetic VIEW " + role).encode(), observed["runtimeHash"])
                    break
        renderer_address, renderer_hash = record[1][2][3:5]
        if renderer_address not in fixture.codes:
            if renderer_address == A(7300):
                _install_runtime(fixture, renderer_address, LEGACY_RENDERER_RUNTIME, renderer_hash)
            else:
                for role, observed in graph.items():
                    if observed["address"] == renderer_address:
                        _install_runtime(fixture, renderer_address,
                            ("synthetic VIEW " + role).encode(), observed["runtimeHash"])
                        break
        encoded = hex_bytes(item["encoded"]); carrier = item["carrier"]
        fixture.add(router, "viewAdoptionProfile(bytes32)", ("bytes32",), (key,),
            ("bytes32",), (item["profile"],))
        fixture.add(router, "viewAdoptionEncoded(bytes32)", ("bytes32",), (key,),
            ("bytes",), (encoded,))
        fixture.add(router, "viewAdoptionCarrier(bytes32)", ("bytes32",), (key,),
            ("address", "bytes32", "uint32"),
            (carrier["pointer"], keccak256(encoded), len(encoded)))
        _install_code(fixture, carrier)
        declaration = item["declaration"]
        fixture.add(host, "viewRecord(bytes32)", ("bytes32",), (record[0][2],),
            (t.VIEW_MANIFEST, t.VIEW_RECEIPT, t.COLLECTION_RECORD),
            (w._v(t.VIEW_MANIFEST, declaration["manifest"]),
             w._v(t.VIEW_RECEIPT, declaration["receipt"]),
             w._v(t.COLLECTION_RECORD, declaration["record"])))
        manifest_raw = hex_bytes(declaration["manifestPayload"])
        fixture.add(host, "manifestPayload(bytes32)", ("bytes32",), (record[0][2],),
            ("address", "bytes"), (declaration["manifestCarrier"]["pointer"], manifest_raw))
        _install_code(fixture, declaration["manifestCarrier"])
        payload = hex_bytes(declaration["viewPayload"]); chunks = declaration["payloadChunks"]
        fixture.add(host, "viewPayload(bytes32)", ("bytes32",), (record[0][2],),
            ("address", "bytes"), (chunks[0]["pointer"], payload))
        fixture.add(host, "viewChunkCount(bytes32)", ("bytes32",), (record[0][2],),
            ("uint256",), (len(chunks),))
        for index, chunk in enumerate(chunks):
            body = hex_bytes(chunk["runtime"])[1:]
            fixture.add(host, "viewChunk(bytes32,uint256)", ("bytes32", "uint256"),
                (record[0][2], index), ("bytes32", "bytes"), (keccak256(body), body))
            _install_code(fixture, chunk)
        observed = declaration["renderer"]; renderer = record[1][2][3]
        fixture.add(renderer, "sourceBindings()", (), (), (("address",) * 4, ("bytes32",) * 4),
            (w._v(("address",) * 4, observed["sourceTargets"]),
             w._v(("bytes32",) * 4, observed["sourcePins"])))
        fixture.add(renderer, "rendererManifest()", (), (), (t.RENDERER_MANIFEST,),
            (w._v(t.RENDERER_MANIFEST, observed["manifest"]),))
        if item["profile"] == t.V2_PROFILE:
            fixture.add(renderer, "encodingBinding()", (), (), ("address", "bytes32"),
                (observed["encoding"], observed["encodingRuntimeHash"]))
            fixture.add(renderer, "policyViewBinding()", (), (), (t.POLICY_BINDING,),
                (w._v(t.POLICY_BINDING, item["policyBinding"]),))
    serving = value["serving"]; host = graph["serving"]["address"]
    fixture.add(host, "binding()", (), (), (w.SERVING_BINDING,),
        (w._v(w.SERVING_BINDING, serving["binding"]),))
    fixture.add(host, "workerBinding()", (), (), ("address", "bytes32"),
        (serving["worker"], serving["workerRuntimeHash"]))
    fixture.add(host, "configurationHash()", (), (), ("bytes32",),
        (serving["configurationHash"],))


def _install_code(fixture, row):
    raw = hex_bytes(row["runtime"])
    if row["pointer"] in fixture.codes:
        if fixture.codes[row["pointer"]] != raw: raise MuseumError("VIEW fixture carrier collision")
    fixture.codes[row["pointer"]] = raw
    fixture.pins[row["pointer"]] = keccak256(raw)


def _install_runtime(fixture, address, raw, expected):
    if address in fixture.codes and fixture.codes[address] != raw:
        raise MuseumError("VIEW fixture runtime collision")
    if keccak256(raw) != expected:
        raise MuseumError("VIEW fixture runtime hash differs")
    fixture.codes[address] = raw
    fixture.pins[address] = expected


class ReadHarness(ViewPolicyAdoptionReads):
    def __init__(self, args):
        from .chain_abi import calldata, decode
        self.value, self.a, self.graph = deepcopy(args)
        self.reader = self; self.responses = {}; self.codes = {}; self.pins = {}; self.requested = []
        self._calldata, self._decode = calldata, decode
        install_adoption_reads(self, self.value, self.a, self.graph)
        expected = w.expected_events(self.value, self.a, self.graph)
        self.logs = []; self.block_times = {}
        for item, descriptor in zip(self.value["history"], expected):
            event = w._v(t.EVENT, item["event"]); number, txi, logi = event[6], event[9], event[10]
            self.logs.append({"address": descriptor["address"], "topics": list(descriptor["topics"]),
                "data": descriptor["data"], "blockNumber": hex(number), "blockHash": event[7],
                "transactionHash": event[8], "transactionIndex": hex(txi), "logIndex": hex(logi),
                "removed": False})
            self.block_times[str(number)] = str(event[11])

    def add(self, target, sig, inputs, values, outputs, result):
        self.responses[(target, self._calldata(sig, inputs, values))] = encode(outputs, result)

    def code(self, address): return "0x" + self.codes[address].hex()
    def _read(self, target, sig, outputs, inputs=(), values=(), maximum=65536):
        self.requested.append(sig)
        return self._decode(outputs, self.responses[(target, self._calldata(sig, inputs, values))], maximum=maximum)
    def _one(self, target, sig, output, inputs=(), values=(), **kwargs):
        return self._read(target, sig, (output,), inputs, values, **kwargs)[0]
    def _history(self, address, topics):
        return {"logs": list(self.logs), "blockTimestamps": dict(self.block_times)}


class ViewPolicyAdoptionWireTests(unittest.TestCase):
    def test_mixed_v1_v2_history_and_historical_selected_record(self):
        value, context, graph = supplied()
        result = w.validate(value, context, graph)
        self.assertEqual(result["profile"], t.V2_PROFILE)
        self.assertFalse(result["selectedIsCurrentHead"])
        self.assertEqual(len(result["history"]), 3)
        self.assertEqual(len(w.expected_events(value, context, graph)), 3)

    def test_selected_can_be_current_without_changing_record_semantics(self):
        value, context, graph = supplied(later_head=False)
        self.assertTrue(w.validate(value, context, graph)["selectedIsCurrentHead"])

    def test_external_collection_context_is_used_in_every_native_domain(self):
        context = {"chainId": "31337", "core": A(1), "collectionId": "1",
            "tokenId": "41", "timestamp": "120", "blockNumber": "20",
            "blockHash": H("external source block"), "stateRoot": H("external state"),
            "environment": "local_evm_fixture", "deploymentEvidenceHash": H("external deployment")}
        graph = _graph(context)
        value, _, _, binding = membership_supplied(3, context=context, graph=graph, recorded_at=101)
        adopted = supplied(context=context, graph=graph, policy_binding=binding, later_head=False)
        result = w.validate(adopted, context, graph)
        record = w._v(t.RECORD, result["record"])
        event = w._v(t.EVENT, result["history"][-1]["event"])
        self.assertEqual((record[0][0][1], record[7], event[2]), (1, 1, 1))

    def test_complete_collection_aggregate_and_event_order(self):
        value, context, graph = supplied(); value["history"].pop(0)
        with self.assertRaisesRegex(MuseumError, "aggregate revision|aggregate chain"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["history"][2]["event"][6] = "2"
        with self.assertRaisesRegex(MuseumError, "event order"):
            w.validate(value, context, graph)

    def test_every_history_row_uses_the_fixed_core_router_domain(self):
        value, context, graph = supplied(foreign_v1_core=True)
        with self.assertRaisesRegex(MuseumError, "history graph differs"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["routerRuntimeHash"] = H("foreign router runtime")
        with self.assertRaisesRegex(MuseumError, "chain/router graph differs"):
            w.validate(value, context, graph)

    def test_scope_predecessor_and_selected_checkpoint_are_independent_of_head(self):
        value, context, graph = supplied(); value["history"][2]["record"][0][3] = ZERO
        with self.assertRaisesRegex(MuseumError, "predecessor"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["selectedRecordHash"] = H("not retained")
        with self.assertRaisesRegex(MuseumError, "selected policy"):
            w.validate(value, context, graph)

    def test_profile_domain_and_canonical_record_bytes(self):
        value, context, graph = supplied(); value["history"][1]["profile"] = ZERO
        with self.assertRaises(MuseumError): w.validate(value, context, graph)
        value, context, graph = supplied(); value["history"][1]["encoded"] += "00"
        with self.assertRaisesRegex(MuseumError, "canonical record bytes"):
            w.validate(value, context, graph)

    def test_declaration_scope_view_and_original_record_hash(self):
        value, context, graph = supplied(); value["history"][1]["declaration"]["receipt"][1] = H("wrong view")
        with self.assertRaisesRegex(MuseumError, "manifest/receipt"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["history"][1]["declaration"]["record"][1] = H("foreign subject")
        with self.assertRaisesRegex(MuseumError, "generic record"):
            w.validate(value, context, graph)

    def test_all_original_carrier_runtime_bytes_are_checked(self):
        for location in ("carrier", "manifest", "payload"):
            value, context, graph = supplied()
            if location == "carrier": row = value["history"][1]["carrier"]
            elif location == "manifest": row = value["history"][1]["declaration"]["manifestCarrier"]
            else: row = value["history"][1]["declaration"]["payloadChunks"][0]
            row["runtime"] += "00"
            with self.assertRaisesRegex(MuseumError, "carrier|chunk"):
                w.validate(value, context, graph)

    def test_policy_binding_and_selected_graph_are_exact(self):
        value, context, graph = supplied(); value["history"][1]["policyBinding"][4] = A(9999)
        with self.assertRaisesRegex(MuseumError, "policy binding|source hash"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); graph["rendererEncoding"]["runtimeHash"] = H("changed")
        with self.assertRaisesRegex(MuseumError, "renderer observations"):
            w.validate(value, context, graph)

    def test_later_history_does_not_relabel_selected_original(self):
        value, context, graph = supplied()
        result = w.validate(value, context, graph)
        self.assertNotEqual(result["selectedRecordHash"], result["head"])
        self.assertEqual(result["record"][3], result["selectedRecordHash"])
        self.assertEqual(result["history"][-1]["record"][3], result["head"])

    def test_actual_read_mixin_replays_selected_history_offline(self):
        args = supplied()
        harness = ReadHarness(args)
        value = harness._adoption(args[0]["selectedRecordHash"], args[0]["scope"])
        self.assertEqual(value, args[0])
        self.assertFalse(any("requireCurrent" in name or "selectedViewRecord" in name
            or "renderPolicyView" in name or "renderView" in name
            or "currentOutput" in name for name in harness.requested))

    def test_historical_renderer_runtime_must_match_saved_record(self):
        args = supplied(); harness = ReadHarness(args)
        renderer = w._v(t.RECORD, args[0]["history"][0]["record"])[1][2][3]
        harness.codes[renderer] = b"changed historical renderer"
        with self.assertRaisesRegex(MuseumError, "historical renderer runtime differs"):
            harness._adoption(args[0]["selectedRecordHash"], args[0]["scope"])


if __name__ == "__main__": unittest.main()
