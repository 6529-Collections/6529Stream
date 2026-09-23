"""Synthetic original COLLECTION policy V2 wire vectors; no native execution."""
from copy import deepcopy
import unittest

from . import policy_content_types_v2 as t
from . import policy_content_wire_v2 as wire
from . import native_finality_wire as n
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, encode, decode, calldata
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .policy_content_source_reads_v2 import PolicyContentReads


def H(value): return keccak256(str(value).encode())
def A(value): return "0x" + format(value, "040x")


def reseal_roots(content, context, graph, statement, *, selected_index=0):
    previous = ZERO
    for item in content["roots"]["history"]:
        r = list(n.from_json(t.ROOT_RECORD, item["record"])); p = list(r[0]); p[1] = previous; r[0] = tuple(p)
        b = n.from_json(t.ROOT_BINDING, item["binding"])
        if b[0] == ZERO:
            r[11] = n.root_state_hash(int(context["chainId"]), graph["router"]["address"], r)
            digest = n.root_hash(int(context["chainId"]), graph["router"]["address"], r)
        else:
            r[11] = wire.root_state_hash(int(context["chainId"]), graph["router"]["address"], r, b)
            digest = wire.root_hash(int(context["chainId"]), graph["router"]["address"], r, b)
        item.update(recordHash=digest, record=json_values(r)); previous = digest
    content["roots"]["rootHead"] = previous
    selected = content["roots"]["history"][selected_index]["recordHash"]
    content["roots"]["selectedRootHash"] = statement[7][0] = selected


def rebuild(content, context, graph, statement, *, source_facts=True):
    """Rehash a supplied synthetic object before capture, not a source-authentication claim."""
    c = content["checkpoint"]; chain, core = int(context["chainId"]), context["core"]
    rows = n.from_json(Array(t.SELECTION_ROW, 1000), c["selectionRows"])
    outputs = list(n.from_json(Array(t.OUTPUT, 1000), c["outputs"]))
    sp = list(n.from_json(t.SELECTION_PLAN, c["selectionPlan"]))
    sp[3] = sp[4] = len(rows); sp[5] = wire.selection_chain(chain, core, graph["router"]["address"], rows)
    p = list(n.from_json(t.CONTENT_PLAN, c["plan"]))
    p[1] = keccak256(encode((t.SELECTION_PLAN,), (sp,))); p[5] = p[6] = len(outputs)
    for i, (o, row) in enumerate(zip(outputs, rows)):
        o = list(o); o[1] = wire.selection_row_hash(chain, core, graph["router"]["address"], row)
        if source_facts: o[2] = wire.source_facts_hash(graph, p, row, o)
        outputs[i] = tuple(o)
    p[7], p[9] = wire.output_chains(chain, core, outputs)
    p[8] = n.tree_root(chain, core, tuple(o[0] for o in outputs))
    c.update(plan=json_values(p), selectionPlan=json_values(sp), outputs=json_values(outputs))
    c["id"] = wire.checkpoint_hash(chain, graph, p, c["salt"])
    raw = wire.manifest_bytes(chain, graph, c["id"], p, outputs)
    parts = [raw[i:i+8192] for i in range(0, len(raw), 8192)]
    original = content["roots"]["history"][0]["record"]
    artist = original[4]
    artifact = (artist, t.OUTPUT_SCHEMA, t.OUTPUT_CANON, 1, keccak256(raw), len(raw),
        tuple(keccak256(part) for part in parts), tuple(len(part) for part in parts))
    ah = n.artifact_hash(chain, graph["artifacts"]["address"], core, artifact)
    coverage = (H("coverage"), ah, artist, t.OUTPUT_SCHEMA, t.OUTPUT_CANON, keccak256(raw), len(raw), len(parts), H("A"), H("B"), 1, H("archive chain"))
    m = (c["id"], keccak256(encode((t.CONTENT_PLAN,), (p,))), graph["entropySourceSet"]["address"], p[2], p[3],
        ah, coverage[0], artist, p[8], p[9], keccak256(raw), p[4], len(outputs), len(raw))
    ph = wire.manifest_plan_hash(chain, graph, m); mh = wire.manifest_record_hash(ph)
    content["manifest"] = {"recordHash": mh, "planHash": ph, "record": json_values(m), "plan": json_values((m, len(outputs), mh)),
        "artifactHash": ah, "artifact": json_values(artifact), "coverage": json_values(coverage),
        "chunks": [{"pointer": A(1000+i), "codeHash": keccak256(b"\0"+part), "runtime": "0x"+(b"\0"+part).hex()} for i, part in enumerate(parts)]}
    original[0][2] = mh; original[1:4] = [p[8], str(len(outputs)), keccak256(raw)]
    content["roots"]["history"][0]["binding"] = json_values(wire.binding_for(graph, c["id"], p))
    statement[2:5] = [p[8], str(len(outputs)), t.LEAF_SCHEMA]
    reseal_roots(content, context, graph, statement)


def supplied(count=3, *, context=None, graph=None, artist_id=None, root_timestamp=None,
             selection_id=None, selection_plan=None, selection_rows=None):
    graph = deepcopy(graph) if graph is not None else {key: {"address": A(i+1), "runtimeHash": H(key+" code")}
        for i, key in enumerate((*wire.GRAPH_KEYS, "scopeMembership"))}
    context = deepcopy(context) if context is not None else {"chainId": "11155111", "core": graph["core"]["address"],
        "collectionId": "1", "tokenId": "41", "timestamp": "1000"}
    cid, target = int(context["collectionId"]), int(context["tokenId"])
    scope = (0, cid, 0, ZERO)
    rows, outputs = [], []
    if selection_rows is not None: count = len(selection_rows)
    for i in range(count):
        token = target + i
        selected = (A(200), H("registry code"), H("version"), A(201), H("renderer code"),
            schema_id("6529STREAM_RENDERER_V1"), schema_id("6529STREAM_STATIC_RENDERER_V1"), H("context version"), H("renderer profile"), H("selection"), H("rules"))
        row = (token, H("config record"+str(token)), H("config"+str(token)), H("source snapshot"+str(token)), H("raw"+str(token)), selected,
            (context["core"], graph["router"]["address"], graph["metadata"]["address"], A(202), ZERO_ADDRESS, ZERO_ADDRESS),
            (graph["core"]["runtimeHash"], graph["router"]["runtimeHash"], graph["metadata"]["runtimeHash"], H("coordinator code"), ZERO, ZERO))
        if selection_rows is not None: row = n.from_json(t.SELECTION_ROW, selection_rows[i]); token = row[0]
        e = (row[6][3], row[7][3], H("policy"), 5, 2, 1, 0, False, True, H("seed"))
        if i % 3 == 1: e = (row[6][3], row[7][3], H("disabled"), 1, 0, 0, 1, True, False, ZERO)
        if i % 3 == 2: e = (row[6][3], row[7][3], H("not required"), 2, 2, 0, 1, True, False, ZERO)
        html = H("HTML"+str(token)); leaf = (token, H("JSON"+str(token)), ZERO, html, ZERO, H("data"+str(token)))
        outputs.append((leaf, ZERO, ZERO, html, e, H("original terminal evidence"+str(token)) if e[7] else ZERO)); rows.append(row)
    sp = selection_plan or (scope, H("membership"), H("coordinator inventory"), count, count, ZERO)
    sid = selection_id or H("selection id")
    p = (sid, ZERO, H("inventory"), H("policy chain"), scope, count, count, ZERO, ZERO, ZERO)
    r = ((cid, ZERO, ZERO, "ipfs://policy-output"), ZERO, count, ZERO, artist_id or H("artist"), 1, H("binding"), A(300),
        7, 1, wire.route_hash(int(context["chainId"]), graph), ZERO, H("original op17 consent"),
        root_timestamp if root_timestamp is not None else int(context["timestamp"])-1)
    content = {"roots": {"selectedRootHash": ZERO, "rootHead": ZERO, "history": [{"recordHash": ZERO, "record": json_values(r),
        "binding": json_values(tuple(ZERO_ADDRESS if k == "address" else ZERO for k in t.ROOT_BINDING))}]},
        "checkpoint": {"id": ZERO, "salt": H("salt"), "plan": json_values(p), "selectionPlan": json_values(sp),
            "selectionRows": json_values(rows), "outputs": json_values(outputs)}, "manifest": {}}
    entropy = (graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"], schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2"),
        H("inventory plan"), p[2], p[3], 1, H("snapshot profile"), H("reference profile"))
    components = tuple((f, A(400+i), "0x12345678", H("module"+str(i)), H("version"), H("manifest"), H("facts"))
        for i, f in enumerate(n.INDEPENDENT_FAMILIES))
    statement = json_values((scope, H("Core facts"), ZERO, count, t.LEAF_SCHEMA, H("snapshot manifest"), H("reference manifest"),
        (ZERO, *(H("input"+str(i)) for i in range(9))), components, entropy, 1, 1))
    rebuild(content, context, graph, statement)
    return content, context, graph, statement


class ReadHarness(PolicyContentReads):
    """Synthetic canonical ABI maps for the fixed getter adapter only."""
    def __init__(self):
        self.content, self.a, self.graph, self.statement = supplied(30)
        self.responses, self.calls, self.codes, self.parts = {}, [], {}, {}
        def put(role, signature, types, values, inputs=(), arguments=()):
            self.responses[(self.graph[role]["address"], calldata(signature, inputs, arguments))] = encode(types, values)
        self.put = put
        c, m = self.content["checkpoint"], self.content["manifest"]
        put("router", "collectionContentRootHead(uint256)", ("bytes32",), (self.content["roots"]["rootHead"],), ("uint256",), (1,))
        for r in self.content["roots"]["history"]:
            put("router", "contentRootRecord(bytes32)", (t.ROOT_RECORD,), (n.from_json(t.ROOT_RECORD, r["record"]),), ("bytes32",), (r["recordHash"],))
            put("router", "policyContentRootBinding(bytes32)", (t.ROOT_BINDING,), (n.from_json(t.ROOT_BINDING, r["binding"]),), ("bytes32",), (r["recordHash"],))
        for host, sig, kind, result, argument in (
            ("outputManifest", "manifestRecord(bytes32)", t.OUTPUT_MANIFEST, m["record"], m["recordHash"]),
            ("outputManifest", "manifestPlan(bytes32)", t.OUTPUT_PLAN, m["plan"], m["planHash"]),
            ("policyContent", "checkpoint(bytes32)", t.CONTENT_PLAN, c["plan"], c["id"]),
            ("staticSelection", "checkpoint(bytes32)", t.SELECTION_PLAN, c["selectionPlan"], c["plan"][0]),
            ("artifacts", "artifact(bytes32)", t.ARTIFACT, m["artifact"], m["artifactHash"]),
            ("artifacts", "coverage(bytes32)", t.COVERAGE, m["coverage"], m["record"][6])):
            put(host, sig, (kind,), (n.from_json(kind, result),), ("bytes32",), (argument,))
        for i, (o, row) in enumerate(zip(c["outputs"], c["selectionRows"])):
            put("policyContent", "outputAt(bytes32,uint256)", (t.OUTPUT,), (n.from_json(t.OUTPUT, o),), ("bytes32", "uint256"), (c["id"], i))
            put("staticSelection", "selectionAt(bytes32,uint256)", (t.SELECTION_ROW,), (n.from_json(t.SELECTION_ROW, row),),
                ("bytes32", "uint256"), (c["plan"][0], i))
        for i, part in enumerate(m["chunks"]):
            put("artifacts", "artifactChunk(bytes32,uint32)", ("address", "bytes32"), (part["pointer"], part["codeHash"]),
                ("bytes32", "uint32"), (m["artifactHash"], i))
            self.codes[part["pointer"]] = hex_bytes(part["runtime"])
            self.parts[m["artifact"][6][i]] = self.codes[part["pointer"]][1:]
        self.logs = [{"address": e["address"], "topics": list(e["topics"]), "data": e["data"],
            "blockNumber": "0x9", "blockHash": H("block9"), "transactionHash": H("tx9"),
            "transactionIndex": "0x0", "logIndex": hex(i)} for i, e in enumerate(wire.expected_events(self.content, self.a, self.graph, self.statement))]

    def _read(self, target, sig, outputs, inputs=(), values=(), maximum=65536):
        self.calls.append(sig)
        return decode(outputs, self.responses[(target, calldata(sig, inputs, values))], maximum=maximum)

    def _one(self, target, sig, output, inputs=(), values=(), maximum=65536):
        return self._read(target, sig, (output,), inputs, values, maximum)[0]

    def _history(self, address, topics):
        return {"logs": [deepcopy(l) for l in self.logs if l["address"] == address and all(
            l["topics"][i] in want if type(want) is list else l["topics"][i] == want for i, want in enumerate(topics))],
            "blockTimestamps": {"9": "999"}}

    def _carrier(self, pointer, pin, maximum):
        raw = self.codes[pointer]
        self.assert_runtime(raw, pin, maximum)
        return raw[1:]

    @staticmethod
    def assert_runtime(raw, pin, maximum):
        from .independent_wire import require
        require(0 < len(raw) <= maximum+1 and raw[0] == 0 and keccak256(raw) == pin, "synthetic carrier")

    def _chunk(self, digest): return self.parts[digest]


class PolicyContentWireTests(unittest.TestCase):
    def test_complete_odd_tree_and_qualified_hash_only_output(self):
        c, x, g, s = supplied(); result = wire.validate(c, x, g, s)
        self.assertEqual(result["tokenIds"], ["41", "42", "43"])
        proof = result["targetProof"]
        self.assertTrue(n.verify_proof(proof["leafHash"], int(proof["leafIndex"]), int(proof["leafCount"]), proof["proof"], proof["root"]))
        self.assertTrue(result["sourceFactsHashChecked"])
        self.assertFalse(result["outputQualification"]["renderedBytesRetained"])
        self.assertFalse(result["outputQualification"]["terminalAdmissionPreimagesReconstructed"])
        self.assertEqual(len(result["outputManifestBytes"]), 576+640*3)
        self.assertEqual(decode(t.OUTPUT_ENVELOPE, result["outputManifestBytes"])[-1], n.from_json(Array(t.OUTPUT, 818), c["checkpoint"]["outputs"]))

    def test_independent_source_facts_dynamic_bytes_and_checkpoint_preimage(self):
        c, x, g, s = supplied(); cp = c["checkpoint"]; p = n.from_json(t.CONTENT_PLAN, cp["plan"])
        row = n.from_json(t.SELECTION_ROW, cp["selectionRows"][0]); out = n.from_json(t.OUTPUT, cp["outputs"][0])
        kinds = ("bytes32", "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32", "bytes32", "address", "bytes32", "bytes32")
        values = (schema_id("6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2"), row[2], row[4], out[4][0], encode((t.READINESS,), (out[4],)),
            g["entropySourceSet"]["address"], g["entropySourceSet"]["runtimeHash"], p[2], p[3], g["terminalReadiness"]["address"],
            g["terminalReadiness"]["runtimeHash"], out[5])
        self.assertEqual(out[2], keccak256(encode(kinds, values)))
        wrong = (*kinds[:4], t.READINESS, *kinds[5:]); wrong_values = (*values[:4], out[4], *values[5:])
        self.assertNotEqual(out[2], keccak256(encode(wrong, wrong_values)))
        snapshot_changed = list(row); snapshot_changed[3] = H("different frozen snapshot identity")
        self.assertEqual(wire.source_facts_hash(g, p, snapshot_changed, out), out[2])
        raw_changed = list(row); raw_changed[4] = H("different raw source")
        self.assertNotEqual(wire.source_facts_hash(g, p, raw_changed, out), out[2])
        cp["outputs"][0][2] = keccak256(encode(wrong, wrong_values)); rebuild(c, x, g, s, source_facts=False)
        with self.assertRaisesRegex(MuseumError, "source facts"): wire.validate(c, x, g, s)

    def test_coherent_readiness_contradictions(self):
        for index, field, value in ((1, 8, True), (1, 9, H("seed")), (2, 4, "0"), (0, 6, "1")):
            with self.subTest(index=index, field=field):
                c, x, g, s = supplied(); c["checkpoint"]["outputs"][index][4][field] = value; rebuild(c, x, g, s)
                with self.assertRaisesRegex(MuseumError, "readiness"): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); c["checkpoint"]["outputs"][0][4][9] = ZERO; rebuild(c, x, g, s)
        wire.validate(c, x, g, s)  # Native finalized path does not invent a nonzero-seed gate.

    def test_coordinator_and_selection_token_cannot_be_reassigned(self):
        c, x, g, s = supplied(); c["checkpoint"]["outputs"][0][4][0] = A(999); rebuild(c, x, g, s)
        with self.assertRaisesRegex(MuseumError, "coordinator"): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); c["checkpoint"]["outputs"][0][0][0] = "40"; rebuild(c, x, g, s)
        with self.assertRaisesRegex(MuseumError, "output/selection"): wire.validate(c, x, g, s)

    def test_mixed_v1_v2_history_later_supersession_and_unknown_profile(self):
        c, x, g, s = supplied(); first = deepcopy(c["roots"]["history"][0]); first["record"][13] = "998"
        first["binding"] = [ZERO_ADDRESS if k == "address" else ZERO for k in t.ROOT_BINDING]
        later = deepcopy(first); later["record"][13] = "1000"; later["record"][3] = H("later manifest")
        c["roots"]["history"] = [first, c["roots"]["history"][0], later]
        reseal_roots(c, x, g, s, selected_index=1)
        self.assertEqual(wire.validate(c, x, g, s)["selectedRootStatus"], "later_superseded")
        events = wire.expected_events(c, x, g, s)
        self.assertEqual(sum(e["kind"] == "root_published" for e in events), 3)
        self.assertEqual(sum(e["kind"] == "root_binding_published" for e in events), 1)
        c["roots"]["history"][0]["binding"][0] = H("unknown profile")
        with self.assertRaisesRegex(MuseumError, "binding profile"): wire.validate(c, x, g, s)

    def test_root_head_history_and_cross_chain_tamper(self):
        c, x, g, s = supplied(); c["roots"]["rootHead"] = H("missing head")
        with self.assertRaisesRegex(MuseumError, "head/selection"): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); x["chainId"] = "1"
        with self.assertRaisesRegex(MuseumError, "root/state"): wire.validate(c, x, g, s)

    def test_chunks_missing_reordered_runtime_and_alias(self):
        for mode in ("missing", "order", "runtime", "alias", "invalid_pointer"):
            with self.subTest(mode=mode):
                c, x, g, s = supplied(30); chunks = c["manifest"]["chunks"]
                if mode == "missing": chunks.pop()
                if mode == "order": chunks[0], chunks[1] = chunks[1], chunks[0]
                if mode == "runtime": chunks[0]["runtime"] = "0x01"+chunks[0]["runtime"][4:]
                if mode == "alias": chunks[0]["pointer"] = g["core"]["address"]
                if mode == "invalid_pointer": chunks[0]["pointer"] = "not-an-address"
                with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_selected_binding_and_statement_entropy_hashes(self):
        c, x, g, s = supplied(); g["entropySourceSet"]["runtimeHash"] = H("replacement")
        with self.assertRaises(MuseumError): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); s[9][5] = H("other policy chain")
        with self.assertRaisesRegex(MuseumError, "entropy commitments"): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); s[0][0] = "1"
        with self.assertRaisesRegex(MuseumError, "COLLECTION only"): wire.validate(c, x, g, s)

    def test_complete_upper_bound_and_truncated_rows(self):
        c, x, g, s = supplied(818)
        self.assertEqual(len(wire.validate(c, x, g, s)["outputManifestBytes"]), 524096)
        self.assertEqual(len(c["manifest"]["chunks"]), 64)
        c["checkpoint"]["outputs"].append(deepcopy(c["checkpoint"]["outputs"][-1]))
        with self.assertRaises(MuseumError): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); c["checkpoint"]["selectionRows"].pop()
        with self.assertRaisesRegex(MuseumError, "complete checkpoint"): wire.validate(c, x, g, s)

    def test_five_literal_definition_pins_and_no_profile_substitution(self):
        rows = wire.definitions()
        self.assertEqual([len(d["bytes"]) for d in rows], [1567, 1042, 809, 1756, 1130])
        self.assertEqual([d["hash"] for d in rows], [
            "0x17df711d9a71e4b0a336082e315eff287e5521360613ab9a4d0278069702887e",
            "0xe14e8ee36cc4625fec04635cfb427aa8a927336cd9f9b0effee9918d511e8edc",
            "0xcff7b5cda08750a201f1960a45ac0804efbdb0a4a5b899f600ddfe039f6e08d3",
            "0x5697985b546ebc99e50a4387e4fe7b8f1964aefc05c699842bbe678739f93c8e",
            "0x3fb3c96d0c6e5f926b20ee4796df9dc7a7edbe9810077523bfe1f5e035836c88"])
        c, x, g, s = supplied(); b = c["roots"]["history"][0]["binding"]; b[12] = H("same id different bytes")
        reseal_roots(c, x, g, s)
        with self.assertRaisesRegex(MuseumError, "definition hashes"): wire.validate(c, x, g, s)

    def test_event_versions_exact_original_rows(self):
        c, x, g, s = supplied(); events = wire.expected_events(c, x, g, s)
        output_events = [e for e in events if e["kind"] == "content_appended"]
        self.assertEqual(len(output_events), 3)
        for i, event in enumerate(output_events):
            version, row, leaf_hash = decode(("uint16", t.OUTPUT, "bytes32"), hex_bytes(event["data"]))
            self.assertEqual(version, 2); self.assertEqual(json_values(row), c["checkpoint"]["outputs"][i])
            self.assertEqual(leaf_hash, n.leaf_hash(int(x["chainId"]), x["core"], row[0]))
        self.assertFalse(any(e["kind"] == "manifest_advanced" for e in events))

    def test_fixed_reader_roundtrip_no_current_eligibility_calls(self):
        f = ReadHarness()
        self.assertEqual(f._content(f.statement), f.content)
        self.assertFalse(any("requireCurrent" in sig or "tokenHTML" in sig for sig in f.calls))

    def test_reader_root_binding_bijection_and_adjacency(self):
        for mode in ("missing", "duplicate", "moved"):
            f = ReadHarness()
            i = next(i for i, l in enumerate(f.logs) if l["topics"][0] == wire.EVENTS["binding"])
            if mode == "missing": f.logs.pop(i)
            if mode == "duplicate": f.logs.append(deepcopy(f.logs[i]))
            if mode == "moved": f.logs[i]["logIndex"] = "0x99"
            with self.subTest(mode=mode), self.assertRaises(MuseumError): f._content(f.statement)

    def test_reader_original_salt_and_store_part(self):
        f = ReadHarness(); log = next(l for l in f.logs if l["topics"][0] == wire.EVENTS["contentStarted"])
        version, salt, initial = decode(("uint16", "bytes32", t.CONTENT_PLAN), hex_bytes(log["data"]))
        log["data"] = "0x"+encode(("uint16", "bytes32", t.CONTENT_PLAN), (version, H("wrong salt"), initial)).hex()
        with self.assertRaisesRegex(MuseumError, "checkpoint identity"): f._content(f.statement)
        f = ReadHarness(); digest = f.content["manifest"]["artifact"][6][0]; f.parts[digest] = b"wrong"
        with self.assertRaisesRegex(MuseumError, "artifact/Store"): f._content(f.statement)

    def test_reader_getter_event_mismatch_and_hidden_head(self):
        f = ReadHarness(); r = deepcopy(f.content["roots"]["history"][0]); r["record"][13] = "998"
        f.put("router", "contentRootRecord(bytes32)", (t.ROOT_RECORD,), (n.from_json(t.ROOT_RECORD, r["record"]),),
            ("bytes32",), (r["recordHash"],))
        with self.assertRaisesRegex(MuseumError, "root/event/binding"): f._content(f.statement)
        f = ReadHarness(); f.put("router", "collectionContentRootHead(uint256)", ("bytes32",), (H("hidden head"),), ("uint256",), (1,))
        with self.assertRaisesRegex(MuseumError, "head/selection"): f._content(f.statement)


if __name__ == "__main__": unittest.main()
