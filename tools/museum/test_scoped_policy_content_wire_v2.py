"""Synthetic original scoped policy V2 wire vectors; no native execution."""
from copy import deepcopy
import unittest

from . import scoped_policy_content_types_v2 as t
from . import scoped_policy_content_wire_v2 as wire
from . import native_finality_wire as n
from .canonical import MuseumError, hex_bytes, keccak256, schema_id
from .chain_abi import Array, encode, decode, calldata
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .scoped_policy_content_source_reads_v2 import ScopedPolicyContentReads


def H(value): return keccak256(str(value).encode())
def A(value): return "0x" + format(value, "040x")


def reseal_roots(content, context, graph, statement, *, selected_index=0):
    chain, core, router = int(context["chainId"]), context["core"], graph["router"]["address"]
    prior, heads = (0,ZERO), {}
    for item in content["roots"]["history"]:
        r = list(n.from_json(t.ROOT_RECORD,item["record"])); p = list(r[0])
        subject = wire.scope_subject(chain,core,p[0]); p[1] = heads.get(subject,ZERO); r[0] = tuple(p)
        b = n.from_json(t.ROOT_BINDING,item["binding"])
        r[15] = (wire.original.root_state_hash(chain,router,core,r) if b[0] == ZERO
            else wire.root_state_hash(chain,router,core,r,b))
        aggregate = wire.next_aggregate(chain,router,core,prior,r)
        digest = (wire.original.root_hash(chain,router,core,r,aggregate) if b[0] == ZERO
            else wire.root_hash(chain,router,core,r,b,aggregate))
        item.update(recordHash=digest,record=json_values(r),aggregate=json_values(aggregate))
        heads[subject],prior = digest,aggregate
    content["roots"]["collectionAggregate"] = json_values(prior)
    content["roots"]["scopeHead"] = heads[wire.scope_subject(chain,core,n.from_json(t.SCOPE,statement[0]))]
    content["roots"]["selectedRootHash"] = statement[7][0] = content["roots"]["history"][selected_index]["recordHash"]


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
    artist = original[8]
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
    original[5:8] = [p[8], str(len(outputs)), keccak256(raw)]
    content["roots"]["history"][0]["binding"] = json_values(wire.binding_for(graph, c["id"], p, n.from_json(t.FACTORY_DEPENDENCIES,c["factoryDependencies"])))
    statement[2:5] = [p[8], str(len(outputs)), t.LEAF_SCHEMA]
    reseal_roots(content, context, graph, statement)


def supplied(count=None, *, scope_type=2, scope_id=None, context=None, graph=None, artist_id=None, root_timestamp=None,
             selection_id=None, selection_plan=None, selection_rows=None):
    graph = deepcopy(graph) if graph is not None else {key: {"address": A(i+1), "runtimeHash": H(key+" code")}
        for i, key in enumerate(wire.GRAPH_KEYS)}
    context = deepcopy(context) if context is not None else {"chainId": "11155111", "core": graph["core"]["address"],
        "collectionId": "1", "tokenId": "41", "timestamp": "1000"}
    cid, target = int(context["collectionId"]), int(context["tokenId"])
    count = (1 if scope_type == 1 else 3) if count is None else count
    scope = (scope_type,cid,target if scope_type == 1 else 0,ZERO if scope_type == 1 else (scope_id or H("scope")))
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
    r = ((scope,ZERO,H("snapshot record"),1,"ipfs://scoped-policy-output"),graph["policySnapshot"]["address"],
        graph["policySnapshot"]["runtimeHash"],H("snapshot manifest"),H("snapshot source"),ZERO,count,ZERO,
        artist_id or H("artist"),1,H("binding"),A(300),7,1,wire.route_hash(int(context["chainId"]),graph,scope),
        ZERO,H("original op17 consent"),root_timestamp if root_timestamp is not None else int(context["timestamp"])-1)
    dependencies = (tuple(graph[k]["address"] for k in ("core","metadata","scopeMembership","coordinatorInventory")),
        tuple(graph[k]["runtimeHash"] for k in ("core","metadata","scopeMembership","coordinatorInventory")),int(context["chainId"]),500000,500000)
    content = {"roots":{"selectedRootHash":ZERO,"scopeHead":ZERO,"collectionAggregate":["0",ZERO],
        "history":[{"recordHash":ZERO,"record":json_values(r),"aggregate":["0",ZERO],
            "binding":json_values(tuple(ZERO_ADDRESS if k == "address" else ZERO for k in t.ROOT_BINDING))}]},
        "checkpoint":{"id":ZERO,"salt":H("salt"),"plan":json_values(p),"selectionPlan":json_values(sp),
            "selectionRows":json_values(rows),"outputs":json_values(outputs),"factoryDependencies":json_values(dependencies)},"manifest":{}}
    components = tuple((f, A(400+i), "0x12345678", H("module"+str(i)), H("version"), H("manifest"), H("facts"))
        for i, f in enumerate(n.INDEPENDENT_FAMILIES))
    statement = json_values((scope, H("Core facts"), ZERO, count, t.LEAF_SCHEMA, H("snapshot manifest"), H("reference manifest"),
        (ZERO,H("snapshot record"), *(H("input"+str(i)) for i in range(8))), components, 1, 1, 1))
    rebuild(content, context, graph, statement)
    return content, context, graph, statement


class ReadHarness(ScopedPolicyContentReads):
    """Synthetic canonical ABI maps for the fixed getter adapter only."""
    def __init__(self, scope_type=2):
        self.content, self.a, self.graph, self.statement = supplied(1 if scope_type==1 else 30,scope_type=scope_type)
        self.responses, self.calls, self.codes, self.parts = {}, [], {}, {}
        def put(role, signature, types, values, inputs=(), arguments=()):
            self.responses[(self.graph[role]["address"], calldata(signature, inputs, arguments))] = encode(types, values)
        self.put = put
        c, m = self.content["checkpoint"], self.content["manifest"]
        put("router","scopedContentRootHead((uint8,uint256,uint256,bytes32))",("bytes32",),(self.content["roots"]["scopeHead"],),
            (t.SCOPE,),(n.from_json(t.SCOPE,self.statement[0]),))
        put("router","scopedContentRootAggregate(uint256)",(t.ROOT_AGGREGATE,),
            (n.from_json(t.ROOT_AGGREGATE,self.content["roots"]["collectionAggregate"]),),("uint256",),(1,))
        from . import scoped_policy_preservation_types_v2 as preservation
        root=self.content["roots"]["history"][0]["record"]
        publication=(n.from_json(t.SCOPE,self.statement[0]),H("snapshotId"),ZERO,0,m["recordHash"],H("inventoryPlan"),root[4],"ipfs://snapshot",900,H("reason"))
        receipt=(root[0][2],wire.scope_subject(11155111,self.a["core"],publication[0]),ZERO,int(root[0][3]),H("chain"),root[3],100,root[4],A(300),7,1,7,1,900,*t.SNAPSHOT_DEFINITION_HASHES)
        put("policySnapshot","snapshotRecord(bytes32)",(preservation.SNAPSHOT_PUBLICATION,preservation.SNAPSHOT_RECEIPT),
            (publication,receipt),("bytes32",),(root[0][2],))
        put("sourceFactory","dependencies()",(t.FACTORY_DEPENDENCIES,),
            (n.from_json(t.FACTORY_DEPENDENCIES,c["factoryDependencies"]),))
        for r in self.content["roots"]["history"]:
            put("router", "scopedContentRootRecord(bytes32)", (t.ROOT_RECORD,), (n.from_json(t.ROOT_RECORD, r["record"]),), ("bytes32",), (r["recordHash"],))
            put("router", "scopedPolicyContentRootBinding(bytes32)", (t.ROOT_BINDING,), (n.from_json(t.ROOT_BINDING, r["binding"]),), ("bytes32",), (r["recordHash"],))
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


class ScopedPolicyContentTests(unittest.TestCase):
    def test_three_native_scopes_and_odd_proof(self):
        for kind in (1,2,3):
            c,x,g,s = supplied(scope_type=kind); r=wire.validate(c,x,g,s)
            self.assertEqual(r["selectedRootStatus"],"still_current")
            p=r["targetProof"]
            self.assertTrue(n.verify_proof(p["leafHash"],int(p["leafIndex"]),int(p["leafCount"]),p["proof"],p["root"]))
            self.assertEqual(len(r["outputManifestBytes"]),576+640*len(r["tokenIds"]))
            self.assertFalse(r["outputQualification"]["renderedBytesRetained"])
            self.assertFalse(r["outputQualification"]["terminalAdmissionPreimagesReconstructed"])
            self.assertEqual(len(wire.expected_events(c,x,g,s)),len(c["checkpoint"]["outputs"])+8)

    def test_complete_chunk_capacity(self):
        c,x,g,s=supplied(818);r=wire.validate(c,x,g,s)
        self.assertEqual(len(c["manifest"]["chunks"]),64)
        self.assertEqual(len(r["outputManifestBytes"]),524096)
        with self.assertRaisesRegex(MuseumError,"array bound"):supplied(819)

    def test_profile_scope_and_token_count_do_not_alias(self):
        for kind,count in ((0,3),(4,3),(1,2)):
            with self.subTest(kind=kind):
                with self.assertRaises(MuseumError):
                    c,x,g,s=supplied(count,scope_type=kind);wire.validate(c,x,g,s)
        c,x,g,s=supplied();c["roots"]["history"][0]["binding"][0]=t.PROFILE
        reseal_roots(c,x,g,s)
        with self.assertRaisesRegex(MuseumError,"binding profile"):wire.validate(c,x,g,s)

    def test_later_root_does_not_replace_original(self):
        c,x,g,s=supplied();row=deepcopy(c["roots"]["history"][0]);row["record"][0][2]=H("later snapshot")
        row["record"][17]=x["timestamp"];c["roots"]["history"].append(row);reseal_roots(c,x,g,s)
        result=wire.validate(c,x,g,s)
        self.assertEqual(result["selectedRootStatus"],"later_superseded")
        c["roots"]["scopeHead"]=c["roots"]["selectedRootHash"]
        with self.assertRaisesRegex(MuseumError,"current scope head"):wire.validate(c,x,g,s)

    def test_mixed_v1_and_off_scope_aggregate_is_complete(self):
        c,x,g,s=supplied();row=deepcopy(c["roots"]["history"][0]);row["record"][0][0][0]="3"
        row["binding"]=[ZERO_ADDRESS if k=="address" else ZERO for k in t.ROOT_BINDING]
        c["roots"]["history"].insert(0,row);reseal_roots(c,x,g,s,selected_index=1)
        self.assertEqual(wire.validate(c,x,g,s)["selectedRootStatus"],"still_current")
        self.assertEqual(c["roots"]["collectionAggregate"][0],"2")
        del c["roots"]["history"][0]
        with self.assertRaisesRegex(MuseumError,"aggregate"):wire.validate(c,x,g,s)

    def test_source_facts_uses_dynamic_bytes_and_raw_source(self):
        c,x,g,s=supplied();p=n.from_json(t.CONTENT_PLAN,c["checkpoint"]["plan"])
        row=n.from_json(t.SELECTION_ROW,c["checkpoint"]["selectionRows"][0]);o=n.from_json(t.OUTPUT,c["checkpoint"]["outputs"][0])
        kinds=("bytes32","bytes32","bytes32","address","bytes","address","bytes32","bytes32","bytes32","address","bytes32","bytes32")
        values=(schema_id("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2"),row[2],row[4],o[4][0],encode((t.READINESS,),(o[4],)),
            g["entropySourceSet"]["address"],g["entropySourceSet"]["runtimeHash"],p[2],p[3],g["terminalReadiness"]["address"],g["terminalReadiness"]["runtimeHash"],o[5])
        self.assertEqual(o[2],keccak256(encode(kinds,values)))
        self.assertNotEqual(o[2],keccak256(encode((*kinds[:4],t.READINESS,*kinds[5:]),(*values[:4],o[4],*values[5:]))))
        changed=list(row);changed[3]=H("different source snapshot")
        self.assertEqual(wire.source_facts_hash(g,p,changed,o),o[2])
        changed[4]=H("different raw");self.assertNotEqual(wire.source_facts_hash(g,p,changed,o),o[2])

    def test_factory_dependencies_binding_and_distinct_root_profile(self):
        c,x,g,s=supplied();r=wire.validate(c,x,g,s)
        b=r["selectedBinding"]
        self.assertEqual(b[0],schema_id("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2"))
        self.assertNotEqual(b[0],t.PROFILE)
        self.assertEqual(tuple(b[20:]),t.SNAPSHOT_DEFINITION_HASHES)
        c["checkpoint"]["factoryDependencies"][3]="500001"
        with self.assertRaisesRegex(MuseumError,"binding"):wire.validate(c,x,g,s)

    def test_tampered_or_reordered_parts_and_incomplete_output(self):
        for mode in ("part","order","output","runtime"):
            with self.subTest(mode=mode):
                c,x,g,s=supplied(30)
                if mode=="part": c["manifest"]["chunks"][0]["runtime"] += "00"
                if mode=="order": c["manifest"]["chunks"][0],c["manifest"]["chunks"][1]=c["manifest"]["chunks"][1],c["manifest"]["chunks"][0]
                if mode=="output":c["checkpoint"]["outputs"].pop()
                if mode=="runtime":c["manifest"]["chunks"][0]["pointer"]=g["core"]["address"]
                with self.assertRaises(MuseumError):wire.validate(c,x,g,s)

    def test_output_token_mismatch_rehash_still_rejects(self):
        c,x,g,s=supplied();c["checkpoint"]["outputs"][0][0][0]="40";rebuild(c,x,g,s)
        with self.assertRaisesRegex(MuseumError,"output/selection"):wire.validate(c,x,g,s)

    def test_immutable_definition_pins_and_no_collection_alias(self):
        from . import policy_content_wire_v2 as collection
        rows=wire.definitions();self.assertEqual(len(rows),5)
        self.assertEqual([d["kind"] for d in rows],[0,1,0,0,1])
        self.assertTrue(all(a["hash"]!=b["hash"] for a,b in zip(rows,collection.definitions())))
        from .scoped_policy_preservation_wire_v2 import SNAPSHOT_HASHES
        self.assertEqual(t.SNAPSHOT_DEFINITION_HASHES,SNAPSHOT_HASHES)

    def test_exact_interface_selectors_and_token_context(self):
        for expected,signatures in ((t.CONTENT_INTERFACE,t.CONTENT_SIGNATURES),(t.OUTPUT_INTERFACE,t.OUTPUT_SIGNATURES),(t.ROOT_INTERFACE,t.ROOT_SIGNATURES)):
            result=0
            for signature in signatures:result ^= int(schema_id(signature)[2:10],16)
            self.assertEqual(expected,"0x"+format(result,"08x"))
        c,x,g,s=supplied(scope_type=1);x["tokenId"]="42"
        with self.assertRaisesRegex(MuseumError,"TOKEN target differs"):wire.validate(c,x,g,s)


class ScopedPolicyContentReadsTests(unittest.TestCase):
    def test_exact_three_scopes_historical_reads(self):
        for scope in (1,2,3):
            h=ReadHarness(scope); self.assertEqual(h._content(h.statement),h.content)
            self.assertFalse(any("requireCurrent" in call for call in h.calls))
            self.assertIn("snapshotRecord(bytes32)",h.calls)
            self.assertIn("dependencies()",h.calls)

    def test_original_root_event_bijection_and_companion_order(self):
        for mode in ("missing","adjacency","duplicate","foreign_subject"):
            h=ReadHarness();row=next(l for l in h.logs if l["topics"][0]==wire.EVENTS["binding"])
            if mode=="missing":h.logs.remove(row)
            if mode=="adjacency":row["logIndex"]="0xff"
            if mode=="duplicate":h.logs.append(deepcopy(row))
            if mode=="foreign_subject":row["topics"][2]=H("wrong scope")
            with self.subTest(mode=mode),self.assertRaises(MuseumError):h._content(h.statement)

    def test_aggregate_truncation_and_original_getter_conflict(self):
        for mode in ("aggregate","record","snapshot"):
            h=ReadHarness();r=h.content["roots"]["history"][0]
            if mode=="aggregate":h.put("router","scopedContentRootAggregate(uint256)",(t.ROOT_AGGREGATE,),((2,H("hidden prefix")),),("uint256",),(1,))
            if mode=="record":
                value=list(n.from_json(t.ROOT_RECORD,r["record"]));value[13]+=1
                h.put("router","scopedContentRootRecord(bytes32)",(t.ROOT_RECORD,),(value,),("bytes32",),(r["recordHash"],))
            if mode=="snapshot":
                from . import scoped_policy_preservation_types_v2 as preservation
                key=(h.graph["policySnapshot"]["address"],calldata("snapshotRecord(bytes32)",("bytes32",),(r["record"][0][2],)))
                publication,receipt=decode((preservation.SNAPSHOT_PUBLICATION,preservation.SNAPSHOT_RECEIPT),h.responses[key]);receipt=list(receipt);receipt[3]+=1
                h.responses[key]=encode((preservation.SNAPSHOT_PUBLICATION,preservation.SNAPSHOT_RECEIPT),(publication,receipt))
            with self.subTest(mode=mode),self.assertRaises(MuseumError):h._content(h.statement)

    def test_store_and_original_artifact_pointer_must_agree(self):
        h=ReadHarness();digest=h.content["manifest"]["artifact"][6][0];h.parts[digest]=b"other retained bytes"
        with self.assertRaisesRegex(MuseumError,"artifact/Store"):h._content(h.statement)

    def test_checkpoint_start_is_original_not_caller_supplied_salt(self):
        h=ReadHarness();row=next(l for l in h.logs if l["topics"][0]==wire.EVENTS["contentStarted"])
        version,salt,plan=decode(("uint16","bytes32",t.CONTENT_PLAN),hex_bytes(row["data"]))
        row["data"]="0x"+encode(("uint16","bytes32",t.CONTENT_PLAN),(version,H("wrong salt"),plan)).hex()
        with self.assertRaisesRegex(MuseumError,"checkpoint identity"):h._content(h.statement)


if __name__ == "__main__":unittest.main()
