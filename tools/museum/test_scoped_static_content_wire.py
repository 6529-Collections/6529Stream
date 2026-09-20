"""Synthetic original scoped STATIC ABI fixtures; no EVM/source acceptance claim."""
from copy import deepcopy
import unittest

from . import scoped_static_content_wire as wire
from . import scoped_static_types as t
from . import native_finality_wire as neutral
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import encode, decode, calldata
from .independent_wire import ZERO, json_values, require
from .scoped_static_content_source_reads import ContentReadsMixin


def H(value):
    return keccak256(str(value).encode("utf-8"))


def A(value):
    return "0x" + format(value, "040x")


ALL_GRAPH_KEYS = ("core", "artist", "router", "finality", "provider", "metadata", "schemas", "store",
    "artifacts", "scopeMembership", "staticSelection", "staticContent", "outputManifest", "scopedSnapshot",
    "coreAdapter", "executor", "roles", "tokenInventory", "coordinatorInventory")


def seal_roots(content, context, graph, statement):
    """Rebuild synthetic native root state/aggregate hashes, before any source capture."""
    chain, core, router = int(context["chainId"]), context["core"], graph["router"]["address"]
    previous, heads = (0, ZERO), {}
    for row in content["roots"]["history"]:
        r = list(neutral.from_json(t.ROOT_RECORD, row["record"]))
        pub = list(r[0]); subject = wire.scope_subject(chain, core, pub[0])
        pub[1] = heads.get(subject, ZERO); r[0] = tuple(pub)
        r[15] = wire.root_state_hash(chain, router, core, r)
        aggregate = wire.next_aggregate(chain, router, core, previous, r)
        digest = wire.root_hash(chain, router, core, r, aggregate)
        row.update(recordHash=digest, record=json_values(r), aggregate=json_values(aggregate))
        heads[subject] = digest; previous = aggregate
    scope = neutral.from_json(t.SCOPE, statement[0])
    selected = heads[wire.scope_subject(chain, core, scope)]
    content["roots"].update(selectedRootHash=selected, scopeHead=selected, collectionAggregate=json_values(previous))
    statement[7][0] = selected


def rebuild_outputs(content, context, graph, statement):
    """Coherently rebuild all synthetic output/artifact/manifest/root links."""
    c, m = content["checkpoint"], content["manifest"]
    chain, core = int(context["chainId"]), context["core"]
    outputs = neutral.from_json(t.Array(t.OUTPUT, t.MAX_OUTPUTS), c["outputs"])
    p = list(neutral.from_json(t.CONTENT_PLAN, c["plan"]))
    p[3] = p[4] = len(outputs)
    p[5], p[7] = wire.output_chains(chain, core, outputs)
    p[6] = neutral.tree_root(chain, core, tuple(row[0] for row in outputs))
    c["plan"] = json_values(p)
    c["id"] = wire.checkpoint_hash(chain, graph["staticContent"]["address"], graph["staticSelection"]["address"], p, c["salt"])
    raw = wire.manifest_bytes(chain, core, graph["staticContent"]["address"], c["id"], p, outputs)
    parts = [raw[i:i+t.CHUNK_BYTES] for i in range(0, len(raw), t.CHUNK_BYTES)]
    artist = m["record"][4]
    artifact = (artist, t.OUTPUT_SCHEMA, t.OUTPUT_CANON, 1, keccak256(raw), len(raw),
        tuple(keccak256(part) for part in parts), tuple(len(part) for part in parts))
    artifact_hash = neutral.artifact_hash(chain, graph["artifacts"]["address"], core, artifact)
    coverage_hash = H("synthetic preserved coverage")
    record = (c["id"], keccak256(encode((t.CONTENT_PLAN,), (p,))), artifact_hash, coverage_hash, artist,
        p[6], p[7], keccak256(raw), p[2], p[3], len(raw))
    plan_hash = wire.manifest_plan_hash(chain, graph["outputManifest"]["address"], core,
        graph["staticContent"]["address"], graph["artifacts"]["address"], record)
    record_hash = wire.manifest_record_hash(plan_hash)
    coverage = (coverage_hash, artifact_hash, artist, t.OUTPUT_SCHEMA, t.OUTPUT_CANON, keccak256(raw),
        len(raw), len(parts), H("archive family A"), H("archive family B"), 1, H("archive evidence chain"))
    m.update(recordHash=record_hash, planHash=plan_hash, record=json_values(record),
        plan=json_values((record, p[3], record_hash)), artifactHash=artifact_hash,
        artifact=json_values(artifact), coverage=json_values(coverage),
        chunks=[{"pointer": A(1000+i), "codeHash": keccak256(b"\0"+part),
            "runtime": "0x"+(b"\0"+part).hex()} for i, part in enumerate(parts)])
    for row in content["roots"]["history"]:
        if row["record"][0][0] == json_values(p[2]):
            row["record"][5], row["record"][6], row["record"][7] = p[6], str(p[3]), keccak256(raw)
    statement[2:5] = [p[6], str(p[3]), neutral.LEAF_SCHEMA]
    seal_roots(content, context, graph, statement)


def supplied(*, scope_type=2, count=3, token_index=None, scope=None, context=None, graph=None,
             artist_id=None, selection_id=None, selection_hash=None, selection_row_hashes=None,
             snapshot_record_hash=None, snapshot_manifest_hash=None, snapshot_source_hash=None,
             binding_generation=1, binding_hash=None, root_timestamp=None, off_target=False):
    """Return (content,context,graph,statement), explicitly synthetic supplied bytes.

    Overrides let the shared fixture align already constructed selection and
    snapshot originals without mutating a captured transcript or package.
    """
    graph = deepcopy(graph) if graph is not None else {key: {"address": A(i+1), "runtimeHash": H(key+" code")}
        for i, key in enumerate(ALL_GRAPH_KEYS)}
    if token_index is None: token_index = count - 1
    context = deepcopy(context) if context is not None else {"chainId": "11155111", "core": graph["core"]["address"],
        "collectionId": "1", "tokenId": str(41+token_index), "blockNumber": "10", "blockHash": H("block"),
        "timestamp": "1000", "stateRoot": H("state"), "environment": "synthetic_fixture", "deploymentEvidenceHash": H("deployment")}
    chain, cid, target = int(context["chainId"]), int(context["collectionId"]), int(context["tokenId"])
    scope = tuple(scope) if scope is not None else (scope_type, cid, target if scope_type == 1 else 0,
        ZERO if scope_type == 1 else H("scope"+str(scope_type)))
    artist_id = artist_id or H("Artist")
    root_timestamp = root_timestamp if root_timestamp is not None else int(context["timestamp"])-1
    tokens = [target-token_index+i for i in range(count)]
    outputs = []
    for i, token in enumerate(tokens):
        html = H("html"+str(token))
        outputs.append(((token, H("json"+str(token)), ZERO, html, ZERO, H("tokenData"+str(token))),
            selection_row_hashes[i] if selection_row_hashes else H("selection row"+str(token)), H("source facts"+str(token)), html))
    snap = snapshot_record_hash or H("snapshot record")
    snap_manifest = snapshot_manifest_hash or H("snapshot manifest")
    pub = (scope, ZERO, snap, 1, "ipfs://original-scoped-output")
    record = (pub, graph["scopedSnapshot"]["address"], graph["scopedSnapshot"]["runtimeHash"], snap_manifest,
        snapshot_source_hash or H("snapshot source"), H("root placeholder"), count, H("manifest placeholder"), artist_id,
        binding_generation, binding_hash or H("binding"), A(100), 7, 1, wire.route_hash(chain, graph), ZERO, H("consent"), root_timestamp)
    history = []
    if off_target:
        other = list(record); other_scope = (1, cid, tokens[0]+count+999, ZERO)
        other[0] = (other_scope, ZERO, H("other snapshot"), 1, "ar://other")
        other[6] = 1
        history.append({"recordHash": ZERO, "record": json_values(other), "aggregate": ["0", ZERO]})
    history.append({"recordHash": ZERO, "record": json_values(record), "aggregate": ["0", ZERO]})
    checkpoint = {"id": ZERO, "salt": H("salt"), "plan": json_values((selection_id or H("selection id"),
        selection_hash or H("selection hash"), scope, count, count, ZERO, ZERO, ZERO)), "outputs": json_values(outputs)}
    content = {"roots": {"selectedRootHash": ZERO, "scopeHead": ZERO, "collectionAggregate": ["0", ZERO], "history": history},
        "checkpoint": checkpoint, "manifest": {"record": [ZERO, ZERO, ZERO, ZERO, artist_id]}}
    inputs = (ZERO, snap, H("reference"), H("intent"), ZERO, H("interview"), H("rights"), H("description"), H("render"), H("bundle"))
    components = tuple((family, A(200+i), "0x12345678", H("module"+str(i)), H("version"), H("manifest"), H("facts"))
        for i, family in enumerate(neutral.INDEPENDENT_FAMILIES))
    statement = json_values((scope, H("original Core facts"), ZERO, count, neutral.LEAF_SCHEMA, snap_manifest,
        H("reference manifest"), inputs, components, 1, 1, 1))
    rebuild_outputs(content, context, graph, statement)
    return content, context, graph, statement


def joined_supplied(scope_type=2, count=3, *, snapshot_inputs=None, root_timestamp=None):
    """Bottom-up coherent pure snapshot/content fixture, before finality/capture.

    snapshot_inputs may supply (bundle,context,graph,statement) already aligned
    to a shared source. No original captured bytes are modified by this helper.
    """
    from . import scoped_static_snapshot_wire as snapshot_wire
    from .test_scoped_static_snapshot_wire import supplied as snapshot_supplied, resnapshot
    b, x, g, _ = deepcopy(snapshot_inputs) if snapshot_inputs is not None else snapshot_supplied(scope_type, count)
    for i, key in enumerate(ALL_GRAPH_KEYS):
        if key not in g: g[key] = {"address": A(500+i), "runtimeHash": H(key+" extra synthetic code")}
    x.setdefault("stateRoot", H("state")); x.setdefault("environment", "local_evm_fixture")
    x.setdefault("deploymentEvidenceHash", H("deployment"))
    src = list(decode(t.SNAPSHOT_ENVELOPE, hex_bytes(b["snapshot"]["history"][-1]["payload"]), maximum=524288)[-1])
    tokens = [int(value) for value in b["membership"]["tokens"]]
    p = neutral.from_json(t.SELECTION_PLAN, b["selection"]["plan"])
    c, x, g, s = supplied(count=len(tokens), scope=p[0], context=x, graph=g, artist_id=src[2][3],
        token_index=tokens.index(int(x["tokenId"])), selection_id=b["selection"]["id"], root_timestamp=root_timestamp,
        selection_hash=keccak256(encode((t.SELECTION_PLAN,), (p,))),
        selection_row_hashes=[snapshot_wire.selection_row_hash(neutral.from_json(t.SELECTION_ROW, row), x, g)
            for row in b["selection"]["rows"]], binding_generation=src[2][4], binding_hash=src[2][5])
    for token, row in zip(tokens, c["checkpoint"]["outputs"]): row[0][0] = str(token)
    rebuild_outputs(c, x, g, s)
    src[4], src[5] = neutral.from_json(t.CONTENT_PLAN, c["checkpoint"]["plan"]), neutral.from_json(t.OUTPUT_MANIFEST, c["manifest"]["record"])
    b["snapshot"]["history"][-1]["publication"][4] = c["manifest"]["recordHash"]
    resnapshot(b, x, g, s, source=tuple(src))
    r = b["snapshot"]["history"][-1]["receipt"]
    root = c["roots"]["history"][-1]["record"]
    root[0][2], root[0][3], root[3], root[4] = r[0], r[3], r[5], r[7]
    seal_roots(c, x, g, s)
    b["content"] = c
    return b, x, g, s


class ReadHarness(ContentReadsMixin):
    """Fixed original read orchestration only; no receipt/provider authentication."""
    def __init__(self):
        self.bundle, self.a, self.graph, self.statement = joined_supplied()
        self.scope = neutral.from_json(t.SCOPE, self.statement[0])
        self.responses, self.calls, self.codes, self.parts = {}, [], {}, {}
        c = self.bundle["content"]; m = c["manifest"]; checkpoint = c["checkpoint"]
        def put(host, signature, types, values, inputs=(), arguments=()):
            self.responses[(self.graph[host]["address"], calldata(signature, inputs, arguments))] = encode(types, values)
        self.put = put
        put("router", "scopedContentRootAggregate(uint256)", (t.ROOT_AGGREGATE,),
            (neutral.from_json(t.ROOT_AGGREGATE, c["roots"]["collectionAggregate"]),), ("uint256",), (int(self.a["collectionId"]),))
        put("router", "scopedContentRootHead((uint8,uint256,uint256,bytes32))", ("bytes32",),
            (c["roots"]["scopeHead"],), (t.SCOPE,), (self.scope,))
        for row in c["roots"]["history"]:
            put("router", "scopedContentRootRecord(bytes32)", (t.ROOT_RECORD,),
                (neutral.from_json(t.ROOT_RECORD, row["record"]),), ("bytes32",), (row["recordHash"],))
        snap = self.bundle["snapshot"]["history"][0]
        put("scopedSnapshot", "snapshotRecord(bytes32)", (t.SNAPSHOT_PUBLICATION, t.SNAPSHOT_RECEIPT),
            (neutral.from_json(t.SNAPSHOT_PUBLICATION, snap["publication"]), neutral.from_json(t.SNAPSHOT_RECEIPT, snap["receipt"])),
            ("bytes32",), (snap["receipt"][0],))
        put("scopedSnapshot", "snapshotPayload(bytes32)", ("bytes",), (hex_bytes(snap["payload"]),), ("bytes32",), (snap["receipt"][0],))
        for host, signature, kind, result, argument in (
                ("outputManifest", "manifestRecord(bytes32)", t.OUTPUT_MANIFEST, m["record"], m["recordHash"]),
                ("outputManifest", "manifestPlan(bytes32)", t.OUTPUT_PLAN, m["plan"], m["planHash"]),
                ("staticContent", "checkpoint(bytes32)", t.CONTENT_PLAN, checkpoint["plan"], checkpoint["id"]),
                ("artifacts", "artifact(bytes32)", t.ARTIFACT, m["artifact"], m["artifactHash"]),
                ("artifacts", "coverage(bytes32)", t.COVERAGE, m["coverage"], m["record"][3])):
            put(host, signature, (kind,), (neutral.from_json(kind, result),), ("bytes32",), (argument,))
        for i, row in enumerate(checkpoint["outputs"]):
            put("staticContent", "outputAt(bytes32,uint256)", (t.OUTPUT,), (neutral.from_json(t.OUTPUT, row),),
                ("bytes32", "uint256"), (checkpoint["id"], i))
        for i, chunk in enumerate(m["chunks"]):
            put("artifacts", "artifactChunk(bytes32,uint32)", ("address", "bytes32"),
                (chunk["pointer"], chunk["codeHash"]), ("bytes32", "uint32"), (m["artifactHash"], i))
            self.codes[chunk["pointer"]] = hex_bytes(chunk["runtime"])
            self.parts[m["artifact"][6][i]] = hex_bytes(chunk["runtime"])[1:]
        self.logs = []
        for i, event in enumerate(wire.expected_events(c, self.a, self.graph, self.statement)):
            if event["kind"] not in ("root_published", "content_started"): continue
            log = {key: event[key] for key in ("address", "topics", "data")}
            log["topics"] = list(log["topics"])
            log.update(blockHash=H("block9"), blockNumber="0x9", transactionHash=H("transaction"), transactionIndex="0x0", logIndex=hex(i))
            self.logs.append(log)

    def _read(self, target, signature, outputs, inputs=(), values=(), *, maximum=65536):
        key = (target, calldata(signature, inputs, values)); self.calls.append(signature)
        require(key in self.responses, "synthetic missing exact original getter")
        return decode(outputs, self.responses[key], maximum=maximum)

    def _one(self, target, signature, output, inputs=(), values=(), *, maximum=65536):
        return self._read(target, signature, (output,), inputs, values, maximum=maximum)[0]

    def _history(self, address, topics):
        logs = [row for row in self.logs if row["address"] == address and row["topics"][:len(topics)] == topics]
        return {"logs": logs, "blockTimestamps": {"9": "999"}}

    def _carrier(self, pointer, digest, maximum):
        raw = self.codes[pointer]
        require(raw[0] == 0 and len(raw) <= maximum+1 and keccak256(raw) == digest, "synthetic carrier mismatch")
        return raw[1:]

    def _chunk(self, digest):
        return self.parts[digest]


class ScopedStaticContentTests(unittest.TestCase):
    def test_original_source_read_orchestration(self):
        fixture = ReadHarness()
        self.assertEqual(fixture._content(fixture.statement), fixture.bundle["content"])
        self.assertFalse(any("requireCurrent" in call for call in fixture.calls))

    def test_source_omitted_root_and_duplicate_start_fail(self):
        fixture = ReadHarness(); fixture.logs.pop(0)
        with self.assertRaisesRegex(MuseumError, "event/aggregate denominator"): fixture._content(fixture.statement)
        fixture = ReadHarness(); fixture.logs.append(deepcopy(fixture.logs[-1]))
        with self.assertRaisesRegex(MuseumError, "start denominator"): fixture._content(fixture.statement)

    def test_source_original_getter_and_carrier_contradictions_fail(self):
        fixture = ReadHarness(); row = fixture.bundle["content"]["roots"]["history"][0]
        mutated = list(neutral.from_json(t.ROOT_RECORD, row["record"])); mutated[13] += 1
        fixture.put("router", "scopedContentRootRecord(bytes32)", (t.ROOT_RECORD,), (tuple(mutated),), ("bytes32",), (row["recordHash"],))
        with self.assertRaisesRegex(MuseumError, "getter/event differs"): fixture._content(fixture.statement)
        fixture = ReadHarness(); key = next(iter(fixture.parts)); fixture.parts[key] += b"x"
        with self.assertRaisesRegex(MuseumError, "artifact/Store"): fixture._content(fixture.statement)

    def test_full_snapshot_membership_selection_output_join(self):
        from . import scoped_static_snapshot_wire as snapshot_wire
        for kind, count in ((1, 1), (2, 3), (3, 4)):
            b, x, g, s = joined_supplied(kind, count)
            result = wire.validate(b["content"], x, g, s)
            snapshot_wire.validate(b, x, g, s, result)
            # Rehashed output for another token keeps the same row commitment,
            # but cannot stand for the selected membership token.
            if kind != 1:
                result["tokenIds"][-1] = "999"
                with self.assertRaisesRegex(MuseumError, "verified output"):
                    snapshot_wire.validate(b, x, g, s, result)

    def test_three_scopes_and_odd_promoted_target_proof(self):
        for kind, count in ((1, 1), (2, 3), (3, 4)):
            with self.subTest(kind=kind):
                c, x, g, s = supplied(scope_type=kind, count=count)
                result = wire.validate(c, x, g, s); proof = result["targetProof"]
                self.assertTrue(neutral.verify_proof(proof["leafHash"], int(proof["leafIndex"]), count, proof["proof"], proof["root"]))
                self.assertEqual(len(result["outputManifestBytes"]), 480+288*count)
                self.assertFalse(result["outputQualification"]["renderedBytesRetained"])
                self.assertFalse(result["artifactCoverage"]["perChunkArchivePreimagesReconstructed"])
        c, x, g, s = supplied(count=3)
        proof = wire.validate(c, x, g, s)["targetProof"]
        self.assertEqual(len(proof["proof"]), 1)  # Odd third leaf is promoted, never duplicated.

    def test_independent_abi_preimages(self):
        c, x, g, s = supplied(); chain = int(x["chainId"]); core = x["core"]
        p = neutral.from_json(t.CONTENT_PLAN, c["checkpoint"]["plan"])
        expected_id = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", "bytes32"),
            (schema_id("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1"), chain, g["staticContent"]["address"],
             g["staticSelection"]["address"], p[0], p[1], c["checkpoint"]["salt"])))
        self.assertEqual(c["checkpoint"]["id"], expected_id)
        leaves = [neutral.from_json(t.OUTPUT, row)[0] for row in c["checkpoint"]["outputs"]]
        digest = neutral.node_hash(neutral.node_hash(neutral.leaf_hash(chain, core, leaves[0]),
            neutral.leaf_hash(chain, core, leaves[1])), neutral.leaf_hash(chain, core, leaves[2]))
        self.assertEqual(p[6], digest)
        r = neutral.from_json(t.ROOT_RECORD, c["roots"]["history"][0]["record"])
        a = neutral.from_json(t.ROOT_AGGREGATE, c["roots"]["history"][0]["aggregate"])
        expected = keccak256(encode(("bytes32", "uint256", "address", "address", t.ROOT_RECORD, t.ROOT_AGGREGATE),
            (schema_id("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1"), chain, g["router"]["address"], core, r, a)))
        self.assertEqual(c["roots"]["scopeHead"], expected)
        result = wire.validate(c, x, g, s)
        raw = result["outputManifestBytes"]
        self.assertEqual(int.from_bytes(raw[416:448], "big"), 448)
        self.assertEqual(int.from_bytes(raw[448:480], "big"), 3)
        self.assertEqual(decode(t.OUTPUT_ENVELOPE, raw, maximum=524288)[-1],
            neutral.from_json(t.Array(t.OUTPUT, t.MAX_OUTPUTS), c["checkpoint"]["outputs"]))

    def test_maximum_manifest_and_original_chunks(self):
        c, x, g, s = supplied(count=1818)
        result = wire.validate(c, x, g, s)
        self.assertEqual(len(c["manifest"]["chunks"]), 64)
        self.assertEqual(len(result["outputManifestBytes"]), 524064)
        c["checkpoint"]["outputs"].append(deepcopy(c["checkpoint"]["outputs"][-1]))
        with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_collection_aggregate_includes_off_target_scope(self):
        c, x, g, s = supplied(off_target=True)
        self.assertEqual(c["roots"]["collectionAggregate"][0], "2")
        wire.validate(c, x, g, s)
        c["roots"]["history"].pop(0)
        with self.assertRaisesRegex(MuseumError, "collection aggregate"): wire.validate(c, x, g, s)

    def test_scope_predecessor_and_target_head(self):
        c, x, g, s = supplied()
        old = deepcopy(c["roots"]["history"][0]); c["roots"]["history"].append(old)
        c["roots"]["history"][-1]["record"][16] = H("new consent")
        seal_roots(c, x, g, s); wire.validate(c, x, g, s)
        c["roots"]["history"][-1]["record"][0][1] = ZERO
        with self.assertRaisesRegex(MuseumError, "predecessor"): wire.validate(c, x, g, s)

    def test_selected_original_can_differ_from_source_block_head(self):
        c, x, g, s = supplied()
        original = c["roots"]["selectedRootHash"]
        c["roots"]["history"].append(deepcopy(c["roots"]["history"][0]))
        c["roots"]["history"][-1]["record"][16] = H("later consent")
        c["roots"]["history"][-1]["record"][17] = "1000"
        seal_roots(c, x, g, s)
        c["roots"]["selectedRootHash"] = s[7][0] = original
        result = wire.validate(c, x, g, s)
        self.assertEqual(result["selectedRootStatus"], "later_superseded")
        self.assertEqual(result["tokenIds"], ["41", "42", "43"])
        # Finalization-relative latest-root chronology belongs to the event join.

    def test_reordered_outputs_cannot_reuse_root_or_manifest(self):
        for mutate in (lambda c: c["checkpoint"]["outputs"].reverse(),
                       lambda c: c["checkpoint"]["outputs"].pop(),
                       lambda c: c["checkpoint"]["outputs"].__setitem__(1, deepcopy(c["checkpoint"]["outputs"][0]))):
            c, x, g, s = supplied(); mutate(c)
            with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_html_content_and_source_commitment_semantics(self):
        for field, value in (("html", H("different")), ("content", H("separate")), ("source", ZERO), ("data", ZERO)):
            c, x, g, s = supplied()
            row = c["checkpoint"]["outputs"][0]
            if field == "html": row[3] = value
            elif field == "source": row[2] = value
            elif field == "data": row[0][5] = value
            else: row[0][4] = value
            rebuild_outputs(c, x, g, s)
            with self.assertRaisesRegex(MuseumError, "output semantics"): wire.validate(c, x, g, s)

    def test_target_token_and_unsupported_scope(self):
        for mutate in (lambda x, s: x.update(tokenId="9999"), lambda x, s: s[0].__setitem__(0, "4"),
                       lambda x, s: s[0].__setitem__(1, "99")):
            c, x, g, s = supplied(); mutate(x, s)
            with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_output_schema_and_coverage_not_collection_leaf_alias(self):
        for key, index, value in (("artifact", 1, neutral.LEAF_SCHEMA), ("artifact", 3, "2"),
                                  ("coverage", 8, ZERO), ("coverage", 9, H("archive family A"))):
            c, x, g, s = supplied(); c["manifest"][key][index] = value
            with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_carrier_hash_size_stop_and_shared_address_conflicts(self):
        for mutation in ("STOP", "tail", "hash", "graph"):
            c, x, g, s = supplied(); part = c["manifest"]["chunks"][0]
            if mutation == "STOP": part["runtime"] = "0x01" + part["runtime"][4:]
            elif mutation == "tail": part["runtime"] += "00"
            elif mutation == "hash": part["codeHash"] = H("wrong")
            else: part["pointer"] = g["core"]["address"]
            with self.assertRaises(MuseumError): wire.validate(c, x, g, s)

    def test_original_route_authority_timestamp_and_uri(self):
        for index, value in ((12, "3"), (13, "0"), (14, H("wrong route")), (17, "1001")):
            c, x, g, s = supplied(); c["roots"]["history"][0]["record"][index] = value
            seal_roots(c, x, g, s)
            with self.assertRaises(MuseumError): wire.validate(c, x, g, s)
        for uri in ("", "http://example.org", "https://", "ipfs://bad uri", "ar://x\n"):
            c, x, g, s = supplied(); c["roots"]["history"][0]["record"][0][4] = uri
            seal_roots(c, x, g, s)
            with self.assertRaisesRegex(MuseumError, "root URI"): wire.validate(c, x, g, s)

    def test_exact_original_events_and_definitions(self):
        c, x, g, s = supplied(); events = wire.expected_events(c, x, g, s)
        self.assertEqual([row["kind"] for row in events].count("content_appended"), 3)
        started = next(row for row in events if row["kind"] == "content_started")
        version, salt, initial = decode(("uint16", "bytes32", t.CONTENT_PLAN), hex_bytes(started["data"]))
        self.assertEqual((version, salt, initial[4:]), (1, c["checkpoint"]["salt"], (0, ZERO, ZERO, ZERO)))
        root = events[0]
        self.assertEqual(root["topics"][2], wire.scope_subject(int(x["chainId"]), x["core"], s[0]))
        self.assertTrue(all(row["hash"] == keccak256(row["bytes"]) for row in wire.definitions()))
        self.assertEqual([row["kind"] for row in wire.definitions()], [0, 1])

    def test_closed_shapes_and_ambiguous_numeric_fields(self):
        c, x, g, s = supplied(); c["checkpoint"]["complete"] = True
        with self.assertRaises(MuseumError): wire.validate(c, x, g, s)
        c, x, g, s = supplied(); c["checkpoint"]["plan"][3] = True
        with self.assertRaises(MuseumError): wire.validate(c, x, g, s)


if __name__ == "__main__":
    unittest.main()
