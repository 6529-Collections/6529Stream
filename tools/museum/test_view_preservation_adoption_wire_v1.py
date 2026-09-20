"""Independent original VIEW preservation admission vectors and replay reads."""
from copy import deepcopy
import unittest

from . import view_policy_adoption_types_v2 as a_types
from . import view_preservation_adoption_types_v1 as t
from . import view_preservation_adoption_wire_v1 as w
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, json_values
from .test_view_policy_adoption_wire_v2 import supplied as adoption_supplied
from .test_view_policy_adoption_wire_v2 import install_adoption_reads
from .view_preservation_adoption_source_reads_v1 import ViewPreservationAdoptionReads


def A(n): return "0x" + format(n, "040x")
def H(value): return schema_id("VIEW preservation adoption test " + str(value))
def OLD_H(value): return schema_id("VIEW adoption test " + str(value))


def _selector(signature): return "0x" + hex_bytes(keccak256(signature.encode()), 32)[:4].hex()


def _bind_original_registry(value, context, graph, registration_hash, read_hash):
    chain, router, cid = int(context["chainId"]), graph["router"]["address"], int(context["collectionId"])
    heads, revisions, aggregate = {}, {}, ZERO
    for aggregate_revision, item in enumerate(value["history"], 1):
        record = list(w.adoption._v(a_types.RECORD, item["record"])); scope = tuple(record[0][0])
        input_ = list(record[0]); input_[3] = heads.get(scope, ZERO)
        if item["profile"] == a_types.V2_PROFILE:
            source = list(record[1]); renderer = list(source[2])
            renderer[9], renderer[10] = read_hash, registration_hash
            source[2] = tuple(renderer); record[1] = tuple(source); record[0] = tuple(input_)
            policy = w.adoption._v(a_types.POLICY_BINDING, item["policyBinding"])
            source_hash = w.adoption.source_hash(item["profile"], chain, router, tuple(record), policy)
            input_[6] = source_hash
            record[0], record[2] = tuple(input_), source_hash
        else:
            record[0] = tuple(input_)
        revision = revisions.get(scope, 0) + 1; record[4] = revision
        prepared = w.adoption.prepared_hash(item["profile"], tuple(record))
        aggregate = w.adoption.next_aggregate(item["profile"], chain, router, record[1][0][0], cid,
            aggregate, aggregate_revision, item["event"][3], input_[3], prepared)
        record[11] = (aggregate_revision, aggregate)
        record[3] = w.adoption.record_hash(item["profile"], chain, router, record[1][0][0], tuple(record))
        record = tuple(record); encoded = encode((a_types.RECORD,), (record,))
        event = list(w.adoption._v(a_types.EVENT, item["event"])); event[4], event[5] = record[3], record
        item["record"], item["encoded"], item["event"] = (
            json_values(record), "0x" + encoded.hex(), json_values(tuple(event)))
        item["carrier"]["runtime"] = "0x" + (b"\0" + encoded).hex()
        item["carrier"]["codeHash"] = keccak256(b"\0" + encoded)
        heads[scope], revisions[scope] = record[3], revision
    # Resolve selection by stable history position: it is the first retained V2 row for the target scope.
    target_scope = tuple(w.adoption._scope(value["scope"]))
    candidates = [row for row in value["history"] if row["profile"] == a_types.V2_PROFILE
        and tuple(w.adoption._scope(row["record"][0][0])) == target_scope]
    require_selected = candidates[0]["record"][3]
    value["selectedRecordHash"] = require_selected
    value["head"] = heads[target_scope]
    value["aggregate"] = json_values((len(value["history"]), aggregate))


def supplied(*, later_head=True, context=None, graph=None, policy_binding=None,
             adopted_at=103, later_adopted_at=106):
    # The frozen e0b4 helper supplies the byte-identical Router rows.  Its old
    # Serving roles are fixture construction inputs only and are not validated
    # or returned by this distinct preservation profile.
    supplied_context = deepcopy(context)
    supplied_graph = deepcopy(graph)
    if supplied_graph is not None:
        supplied_graph["serving"] = deepcopy(supplied_graph["preservationRenderer"])
        supplied_graph["servingWorker"] = deepcopy(supplied_graph["preservationWorker"])
    created = adoption_supplied(context=supplied_context, graph=supplied_graph,
        policy_binding=policy_binding, later_head=later_head, adopted_at=adopted_at)
    if policy_binding is None:
        old_value, context, old_graph = created
    else:
        old_value = created
        context = supplied_context
        old_graph = supplied_graph
    graph = deepcopy(graph) if graph is not None else {
        key: deepcopy(old_graph[key]) for key in t.GRAPH_KEYS if key in old_graph}
    next_address = 7600
    for key in t.GRAPH_KEYS:
        if key not in graph:
            raw = ("synthetic VIEW preservation " + key).encode()
            graph[key] = {"address": A(next_address), "runtimeHash": keccak256(raw)}
            next_address += 1
    value = {key: deepcopy(old_value[key]) for key in old_value if key != "serving"}
    if later_head and later_adopted_at != 106:
        item = value["history"][-1]
        record = list(w.adoption._v(a_types.RECORD, item["record"]))
        record[10] = later_adopted_at
        record[3] = w.adoption.record_hash(item["profile"], int(context["chainId"]),
            graph["router"]["address"], record[1][0][0], tuple(record))
        record = tuple(record); encoded = encode((a_types.RECORD,), (record,))
        event = list(w.adoption._v(a_types.EVENT, item["event"])); block = later_adopted_at - 100
        event[4], event[5], event[6], event[7], event[8], event[11] = (
            record[3], record, block, OLD_H("block " + str(block)),
            OLD_H("tx " + str(block) + ":0"), later_adopted_at)
        item["record"], item["encoded"], item["event"] = (
            json_values(record), "0x" + encoded.hex(), json_values(tuple(event)))
        item["carrier"]["runtime"] = "0x" + (b"\0" + encoded).hex()
        item["carrier"]["codeHash"] = keccak256(b"\0" + encoded)
        value["head"] = record[3]
    selected = next(row for row in value["history"] if row["record"][3] == value["selectedRecordHash"])
    record = w.adoption._v(a_types.RECORD, selected["record"])
    version_key = record[1][2][2]
    producer = graph["preservationRenderer"]["address"]
    attribution = graph["preservationAttribution"]["address"]
    config = (graph["core"]["address"], graph["core"]["runtimeHash"],
        graph["router"]["address"], graph["router"]["runtimeHash"], attribution,
        graph["preservationAttribution"]["runtimeHash"], int(context["chainId"]), 100000, 100000)
    worker, worker_hash = graph["preservationWorker"].values()
    encoding, encoding_hash = graph["preservationEncoding"].values()
    binding = (config[0], config[2], record[1][2][3], record[1][2][4], config[4], config[5])
    producer_binding = (producer, graph["preservationRenderer"]["runtimeHash"], t.OUTPUT_PROFILE,
        config[0], config[2], record[1][2][3], record[1][2][4], config[4], config[5])
    targets = [(graph["core"]["address"], graph["core"]["runtimeHash"], schema_id("CORE")),
        (producer, graph["preservationRenderer"]["runtimeHash"], schema_id("PRESERVATION_RENDERER")),
        (attribution, graph["preservationAttribution"]["runtimeHash"],
            schema_id("PRESERVATION_ATTRIBUTION"))]
    targets.sort(key=lambda row: int(row[0], 16))
    index = {row[0]: position for position, row in enumerate(targets)}
    original_reads = ((index[graph["core"]["address"]], _selector("collectionExists(uint256)"),
        32, True),)
    reads = [*original_reads,
        (index[producer], _selector("preservationProfile()"), 32, True),
        (index[producer], _selector("configuration()"), 288, True),
        (index[producer], _selector("preservationViewJSON((uint8,uint256,uint256,bytes32),uint256)"), 96, False),
        (index[producer], _selector("preservationViewHTML((uint8,uint256,uint256,bytes32),uint256)"), 96, False),
        (index[producer], _selector("historicalPreservationViewJSON(bytes32,uint256)"), 192, False),
        (index[producer], _selector("historicalPreservationViewHTML(bytes32,uint256)"), 192, False),
        (index[producer], _selector("preservationViewBinding(bytes32)"), 192, True),
        (index[attribution], _selector("preservationAttribution(uint256,uint256)"), 32832, False)]
    reads.sort(key=lambda row: (row[0], int(row[1], 16)))
    targets, reads = tuple(targets), tuple(reads)
    target_set_hash = keccak256(encode((t.TARGETS,), (targets,)))
    original_registration_hash = H("original renderer registration")
    original_read_hash = w.read_set_hash(target_set_hash, original_reads)
    _bind_original_registry(value, context, graph, original_registration_hash, original_read_hash)
    selected = next(row for row in value["history"] if row["record"][3] == value["selectedRecordHash"])
    record = w.adoption._v(a_types.RECORD, selected["record"])
    version_key = record[1][2][2]
    version = (True, True, record[1][2][3], record[1][2][4], original_registration_hash,
        original_read_hash, H("original analysis"), H("original golden"), H("original action"))
    registration = (version_key, producer_binding, H("preservation schema"),
        H("preservation analysis document"), H("preservation golden document"))
    registry = graph["rendererRegistry"]["address"]
    read_hash = w.read_set_hash(target_set_hash, reads)
    registration_hash = w.registration_hash(int(context["chainId"]), registry,
        graph["schemas"]["address"], graph["schemas"]["runtimeHash"], target_set_hash,
        original_registration_hash, registration, reads)
    preservation_record = (registration, registration_hash, read_hash,
        H("analysis bytes"), H("golden bytes"), H("preservation action"))
    admission = (registry, graph["rendererRegistry"]["runtimeHash"], version_key,
        *preservation_record[1:5])
    value["preservation"] = {"configuration": json_values(config),
        "configurationHash": w.configuration_hash(int(context["chainId"]), producer,
            config, worker, worker_hash, encoding, encoding_hash),
        "worker": worker, "workerRuntimeHash": worker_hash,
        "encoding": encoding, "encodingRuntimeHash": encoding_hash,
        "binding": json_values(binding), "producerBinding": json_values(producer_binding),
        "admission": json_values(admission), "attribution": {"core": config[0],
            "router": config[2], "profile": t.ATTRIBUTION_PROFILE,
            "liveAttribution": graph["attribution"]["address"],
            "liveAttributionRuntimeHash": graph["attribution"]["runtimeHash"]},
        "registry": {"deploymentChainId": context["chainId"],
            "schemaRegistry": graph["schemas"]["address"],
            "schemaRegistryCodeHash": graph["schemas"]["runtimeHash"],
            "targetSetHash": target_set_hash, "version": json_values(version),
            "originalReads": json_values(original_reads), "record": json_values(preservation_record),
            "reads": json_values(reads), "targets": json_values(targets)}}
    return value, context, graph


class _FilteredInstaller:
    def __init__(self, target, host): self.target, self.host = target, host
    def __getattr__(self, name): return getattr(self.target, name)
    def add(self, target, signature, *args, **kwargs):
        if target == self.host and signature in ("binding()", "workerBinding()", "configurationHash()"):
            return
        return self.target.add(target, signature, *args, **kwargs)


def install_preservation_adoption_reads(fixture, value, context, graph):
    compat_graph = deepcopy(graph)
    compat_graph["serving"] = deepcopy(graph["preservationRenderer"])
    compat_graph["servingWorker"] = deepcopy(graph["preservationWorker"])
    old = {key: deepcopy(value[key]) for key in value if key != "preservation"}
    old["serving"] = {"binding": json_values((graph["core"]["address"],
        graph["core"]["runtimeHash"], graph["router"]["address"],
        graph["router"]["runtimeHash"], int(context["chainId"]), 100000)),
        "worker": graph["preservationWorker"]["address"],
        "workerRuntimeHash": graph["preservationWorker"]["runtimeHash"],
        "configurationHash": H("discarded old serving configuration")}
    install_adoption_reads(_FilteredInstaller(fixture, graph["preservationRenderer"]["address"]),
        old, context, compat_graph)
    p = value["preservation"]; producer = graph["preservationRenderer"]["address"]
    fixture.add(producer, "preservationProfile()", (), (), ("bytes32",), (t.OUTPUT_PROFILE,))
    fixture.add(producer, "configuration()", (), (), (t.CONFIGURATION,),
        (w._v(t.CONFIGURATION, p["configuration"]),))
    fixture.add(producer, "configurationHash()", (), (), ("bytes32",), (p["configurationHash"],))
    fixture.add(producer, "workerBinding()", (), (), ("address", "bytes32"),
        (p["worker"], p["workerRuntimeHash"]))
    fixture.add(producer, "encodingBinding()", (), (), ("address", "bytes32"),
        (p["encoding"], p["encodingRuntimeHash"]))
    fixture.add(producer, "preservationViewBinding(bytes32)", ("bytes32",),
        (value["selectedRecordHash"],), (t.BINDING,), (w._v(t.BINDING, p["binding"]),))
    attr = p["attribution"]; host = graph["preservationAttribution"]["address"]
    for signature, output, key in (("core()", "address", "core"), ("router()", "address", "router"),
            ("preservationAttributionProfile()", "bytes32", "profile"),
            ("liveAttribution()", "address", "liveAttribution"),
            ("liveAttributionCodeHash()", "bytes32", "liveAttributionRuntimeHash")):
        fixture.add(host, signature, (), (), (output,), (attr[key],))
    registry = p["registry"]; host = p["admission"][0]
    version_key = p["admission"][2]; key = w.preservation_key(version_key, producer)
    for signature, output, result in (("deploymentChainId()", "uint256", int(registry["deploymentChainId"])),
            ("schemaRegistry()", "address", registry["schemaRegistry"]),
            ("schemaRegistryCodeHash()", "bytes32", registry["schemaRegistryCodeHash"]),
            ("targetSetHash()", "bytes32", registry["targetSetHash"]),
            ("targetCount()", "uint256", len(registry["targets"]))):
        fixture.add(host, signature, (), (), (output,), (result,))
    fixture.add(host, "version(bytes32)", ("bytes32",), (version_key,), (t.VERSION,),
        (w._v(t.VERSION, registry["version"]),))
    fixture.add(host, "reads(bytes32)", ("bytes32",), (version_key,), (t.READS,),
        (w._v(t.READS, registry["originalReads"]),))
    fixture.add(host, "preservationRecord(bytes32)", ("bytes32",), (key,),
        (t.PRESERVATION_RECORD,), (w._v(t.PRESERVATION_RECORD, registry["record"]),))
    fixture.add(host, "preservationReads(bytes32)", ("bytes32",), (key,), (t.READS,),
        (w._v(t.READS, registry["reads"]),))
    for index, row in enumerate(registry["targets"]):
        fixture.add(host, "targetAt(uint256)", ("uint256",), (index,), (t.TARGET,),
            (w._v(t.TARGET, row),))


class ReadHarness(ViewPreservationAdoptionReads):
    def __init__(self, args):
        self.value, self.a, self.graph = deepcopy(args)
        self.reader = self; self.responses = {}; self.codes = {}; self.pins = {}; self.requested = []
        self.signatures = []
        for name, row in self.graph.items():
            raw = ("synthetic VIEW " + name).encode()
            if keccak256(raw) != row["runtimeHash"]:
                raw = ("synthetic VIEW preservation " + name).encode()
            self.codes[row["address"]] = raw; self.pins[row["address"]] = row["runtimeHash"]
        install_preservation_adoption_reads(self, self.value, self.a, self.graph)
        expected = w.expected_events(self.value, self.a, self.graph)[:len(self.value["history"])]
        self.logs, self.block_times = [], {}
        for item, descriptor in zip(self.value["history"], expected):
            event = w.adoption._v(a_types.EVENT, item["event"])
            self.logs.append({"address": descriptor["address"], "topics": list(descriptor["topics"]),
                "data": descriptor["data"], "blockNumber": hex(event[6]), "blockHash": event[7],
                "transactionHash": event[8], "transactionIndex": hex(event[9]),
                "logIndex": hex(event[10]), "removed": False})
            self.block_times[str(event[6])] = str(event[11])

    def add(self, target, signature, inputs, values, outputs, result):
        self.responses[(target, calldata(signature, inputs, values))] = "0x" + encode(outputs, result).hex()
    def call(self, target, data):
        self.requested.append((target, data))
        if (target, data) not in self.responses: raise MuseumError("unexpected VIEW preservation read")
        return self.responses[(target, data)]
    def code(self, address):
        self.requested.append(("code", address))
        if address not in self.codes: raise MuseumError("unexpected VIEW preservation code")
        return "0x" + self.codes[address].hex()
    def _read(self, target, signature, outputs, inputs=(), values=(), *, maximum=65536):
        self.signatures.append(signature)
        return decode(outputs, hex_bytes(self.call(target, calldata(signature, inputs, values))), maximum=maximum)
    def _one(self, target, signature, output, inputs=(), values=(), *, maximum=65536):
        return self._read(target, signature, (output,), inputs, values, maximum=maximum)[0]
    def _history(self, address, topics):
        def match(log):
            return log["address"] == address and all(item is None or
                (isinstance(item, list) and log["topics"][index] in item) or log["topics"][index] == item
                for index, item in enumerate(topics))
        return {"logs": [row for row in self.logs if match(row)],
            "blockTimestamps": dict(self.block_times), "coverage": {}}


class ViewPreservationAdoptionWireTests(unittest.TestCase):
    def test_definitions_are_exact_native_adoption_documents(self):
        self.assertEqual(w.definitions(), w.adoption.definitions())
        self.assertEqual(len(w.definitions()), 6)
        self.assertNotIn(w.PROFILE, {row["id"] for row in w.definitions()})
        self.assertEqual(w.PROFILE_HASH, keccak256(w.PROFILE_BYTES))

    def test_complete_original_admission_and_distinct_profiles(self):
        value, context, graph = supplied()
        result = w.validate(value, context, graph)
        self.assertEqual(result["profile"], t.PROFILE)
        self.assertEqual(result["adoptionProfile"], a_types.V2_PROFILE)
        self.assertFalse(result["selectedIsCurrentHead"])
        self.assertEqual(result["preservationBinding"], value["preservation"]["binding"])
        self.assertEqual(result["admission"], value["preservation"]["admission"])

    def test_later_original_adoption_coordinate_can_follow_new_checkpoint_timeline(self):
        value, context, graph = supplied(later_adopted_at=110)
        result = w.validate(value, context, graph)
        self.assertEqual(result["history"][-1]["event"][11], "110")
        self.assertEqual(result["head"], result["history"][-1]["record"][3])

    def test_configuration_binding_and_live_attribution_are_exact(self):
        for mutate, message in (
            (lambda v, g: v["preservation"]["configuration"].__setitem__(7, "49999"), "configuration"),
            (lambda v, g: v["preservation"]["binding"].__setitem__(2, A(99)), "binding"),
            (lambda v, g: v["preservation"]["attribution"].__setitem__("liveAttribution", A(98)), "attribution")):
            value, context, graph = supplied(); mutate(value, graph)
            with self.subTest(message=message), self.assertRaisesRegex(MuseumError, message):
                w.validate(value, context, graph)

    def test_registry_target_set_roles_and_original_read_subset(self):
        value, context, graph = supplied()
        targets = value["preservation"]["registry"]["targets"]
        index = next(i for i, row in enumerate(targets)
            if row[0] == graph["preservationRenderer"]["address"])
        targets[index][2] = H("wrong role")
        with self.assertRaisesRegex(MuseumError, "read hash|target binding"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["preservation"]["registry"]["originalReads"][0][2] = "64"
        with self.assertRaisesRegex(MuseumError, "original renderer read hash|changed original read|omitted"):
            w.validate(value, context, graph)

    def test_required_read_shapes_and_selector_domain(self):
        value, context, graph = supplied(); value["preservation"]["registry"]["reads"].pop()
        with self.assertRaisesRegex(MuseumError, "required read set"):
            w.validate(value, context, graph)
        value, context, graph = supplied(); value["preservation"]["registry"]["reads"][1][1] = "0x00000000"
        with self.assertRaises(MuseumError): w.validate(value, context, graph)

    def test_fully_rehashed_zero_selector_registry_read_is_rejected(self):
        value, context, graph = supplied()
        p = value["preservation"]; registry = p["registry"]
        reads = registry["reads"]
        reads.append(["0", "0x00000000", "32", True])
        reads.sort(key=lambda row: (int(row[0]), int(row[1], 16)))
        decoded = w._v(t.READS, reads)
        record = registry["record"]
        record[2] = w.read_set_hash(registry["targetSetHash"], decoded)
        record[1] = w.registration_hash(int(context["chainId"]), p["admission"][0],
            registry["schemaRegistry"], registry["schemaRegistryCodeHash"],
            registry["targetSetHash"], registry["version"][4],
            w._v(t.PRESERVATION_REGISTRATION, record[0]), decoded)
        p["admission"] = [graph["rendererRegistry"]["address"],
            graph["rendererRegistry"]["runtimeHash"], record[0][0], *record[1:5]]
        with self.assertRaisesRegex(MuseumError, "Registry read shape/order"):
            w.validate(value, context, graph)

    def test_registration_readset_and_admission_hashes(self):
        for field in ("targetSetHash",):
            value, context, graph = supplied(); value["preservation"]["registry"][field] = H("changed")
            with self.assertRaisesRegex(MuseumError, "Registry hashes"):
                w.validate(value, context, graph)
        value, context, graph = supplied(); value["preservation"]["registry"]["record"][1] = H("changed")
        with self.assertRaisesRegex(MuseumError, "Registry hashes"):
            w.validate(value, context, graph)

    def test_deprecated_original_version_remains_historical_evidence(self):
        value, context, graph = supplied(); self.assertTrue(value["preservation"]["registry"]["version"][1])
        self.assertEqual(w.validate(value, context, graph)["admission"],
            value["preservation"]["admission"])

    def test_registration_event_has_schema_version_and_padded_address_topic(self):
        value, context, graph = supplied()
        event = w.expected_events(value, context, graph)[-1]
        self.assertEqual(event["topics"][2], w.base._topic("address",
            graph["preservationRenderer"]["address"]))
        version, registration_hash, _, _ = decode(("uint16", "bytes32",
            t.PRESERVATION_REGISTRATION, t.READS), hex_bytes(event["data"]))
        self.assertEqual(version, 1)
        self.assertEqual(registration_hash, value["preservation"]["registry"]["record"][1])

    def test_actual_source_reader_roundtrip_uses_no_current_or_render_calls(self):
        args = supplied(); harness = ReadHarness(args)
        result = harness._preservation_adoption(args[0]["selectedRecordHash"], args[0]["scope"])
        self.assertEqual(result, args[0])
        forbidden = ("requirePreservation", "preservationViewJSON", "preservationViewHTML",
            "historicalPreservationViewJSON", "historicalPreservationViewHTML", "requireCurrent")
        self.assertFalse(any(any(term in signature for term in forbidden)
            for signature in harness.signatures))

    def test_source_reader_rejects_current_runtime_drift(self):
        args = supplied(); harness = ReadHarness(args)
        host = args[2]["preservationAttribution"]["address"]
        harness.codes[host] = b"changed"
        with self.assertRaisesRegex(MuseumError, "preservation attribution runtime differs"):
            harness._preservation_adoption(args[0]["selectedRecordHash"], args[0]["scope"])


if __name__ == "__main__": unittest.main()
