"""Pure original scoped factory-policy V2 content correspondence.

Complete output hash rows and source-facts preimages are reconstructed. The
artifact does not retain rendered JSON/HTML/image/tokenData or original terminal
admission preimages. This module performs no RPC, rendering or authority replay.
"""
from . import scoped_policy_content_types_v2 as t
from . import native_finality_wire as neutral
from . import scoped_static_content_wire as original
from .canonical import hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = t.SOURCE_REVISION
PROFILE, OUTPUT_SCHEMA, OUTPUT_CANON = t.PROFILE, t.OUTPUT_SCHEMA, t.OUTPUT_CANON
LEAF_CHAIN = schema_id("6529STREAM_SCOPED_POLICY_CONTENT_LEAVES_V2")
OUTPUT_CHAIN = schema_id("6529STREAM_SCOPED_POLICY_FULL_OUTPUTS_V2")
ROUTE_KEYS = ("core", "artist", "router", "finality", "provider", "policySnapshot")
GRAPH_KEYS = (*ROUTE_KEYS, "metadata", "schemas", "outputManifest", "policyContent", "artifacts", "staticSelection", "entropySourceSet", "terminalReadiness", "sourceFactory", "scopeMembership", "coordinatorInventory")
ROOT_PROFILE = t.ROOT_PROFILE
valid_scope, scope_subject, next_aggregate = original.valid_scope, original.scope_subject, original.next_aggregate


def definitions():
    """Literal original RAW_BYTES definitions, independent of current registration."""
    return tuple({"id": schema_id(name), "name": name, "kind": kind,
        "hash": keccak256(text.encode("utf-8")), "bytes": text.encode("utf-8")}
        for name, kind, text in _DEFINITIONS)


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), "policy V2 " + label + " fields")


def _v(kind, value):
    result = neutral.from_json(kind, value)
    encode((kind,), (result,))
    return result


def _hash(domain, kinds, values):
    return keccak256(encode(("bytes32", *kinds), (schema_id(domain), *values)))


def route_hash(chain, graph, scope):
    return _hash("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2",
        ("uint256", ("address",)*6, ("bytes32",)*6, "address", "bytes32", t.SCOPE),
        (chain, tuple(graph[k]["address"] for k in ROUTE_KEYS), tuple(graph[k]["runtimeHash"] for k in ROUTE_KEYS),
         graph["metadata"]["address"], graph["metadata"]["runtimeHash"], scope))


def root_state_hash(chain, router, core, record, binding):
    r = list(_v(t.ROOT_RECORD, record)); r[15], r[16], r[17] = ZERO, ZERO, 0
    return _hash("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2",
        ("uint256", "address", "address", t.ROOT_RECORD, t.ROOT_BINDING), (chain, router, core, r, binding))


def root_hash(chain, router, core, record, binding, aggregate):
    return _hash("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
        ("uint256", "address", "address", t.ROOT_RECORD, t.ROOT_BINDING, t.ROOT_AGGREGATE),
        (chain, router, core, record, binding, aggregate))


def checkpoint_hash(chain, graph, plan, salt):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", "address", "bytes32",
        "address", "bytes32", "bytes32", "bytes32", "bytes32"), (PROFILE, chain,
        graph["policyContent"]["address"], graph["staticSelection"]["address"], plan[0], plan[1],
        graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"],
        graph["terminalReadiness"]["address"], graph["terminalReadiness"]["runtimeHash"], plan[2], plan[3], salt)))


def selection_row_hash(chain, core, router, row):
    return _hash("6529STREAM_STATIC_SELECTION_ROW_V1", ("uint256", "address", "address", t.SELECTION_ROW),
        (chain, core, router, row))


def selection_chain(chain, core, router, rows):
    folded = ZERO
    for index, row in enumerate(rows):
        folded = _hash("6529STREAM_STATIC_SELECTION_CHAIN_V1", ("bytes32", "uint256", "bytes32"),
            (folded, index, selection_row_hash(chain, core, router, row)))
    return folded


def source_facts_hash(graph, plan, selection_row, output):
    # Native `facts` is a dynamic bytes value, not an inlined READINESS tuple.
    return keccak256(encode(("bytes32", "bytes32", "bytes32", "address", "bytes", "address", "bytes32", "bytes32",
        "bytes32", "address", "bytes32", "bytes32"), (PROFILE, selection_row[2], selection_row[4], output[4][0],
        encode((t.READINESS,), (output[4],)), graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"],
        plan[2], plan[3], graph["terminalReadiness"]["address"], graph["terminalReadiness"]["runtimeHash"], output[5])))


def output_chains(chain, core, outputs):
    leaves, output_root = ZERO, ZERO
    for index, row in enumerate(outputs):
        leaves = keccak256(encode(("bytes32", "bytes32", "uint256", "bytes32"),
            (LEAF_CHAIN, leaves, index, neutral.leaf_hash(chain, core, row[0]))))
        output_root = keccak256(encode(("bytes32", "bytes32", "uint256", t.OUTPUT),
            (OUTPUT_CHAIN, output_root, index, row)))
    return leaves, output_root


def manifest_bytes(chain, graph, checkpoint_id, plan, outputs):
    return encode(t.OUTPUT_ENVELOPE, (OUTPUT_SCHEMA, chain, graph["core"]["address"], graph["policyContent"]["address"],
        checkpoint_id, keccak256(encode((t.CONTENT_PLAN,), (plan,))), graph["entropySourceSet"]["address"],
        plan[2], plan[3], plan[4], plan[8], plan[9], plan[5], outputs))


def manifest_plan_hash(chain, graph, manifest):
    return _hash("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_PLAN_V2",
        ("uint256", "address", "address", "address", "address", t.OUTPUT_MANIFEST),
        (chain, graph["outputManifest"]["address"], graph["core"]["address"], graph["policyContent"]["address"],
         graph["artifacts"]["address"], manifest))


def manifest_record_hash(plan_hash):
    return _hash("6529STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_VERIFIED_V2", ("bytes32",), (plan_hash,))


def binding_for(graph, checkpoint_id, plan, factory_dependencies):
    return (ROOT_PROFILE, graph["outputManifest"]["address"], graph["outputManifest"]["runtimeHash"],
        graph["policyContent"]["address"], graph["policyContent"]["runtimeHash"], checkpoint_id,
        keccak256(encode((t.CONTENT_PLAN,), (plan,))), graph["entropySourceSet"]["address"],
        graph["entropySourceSet"]["runtimeHash"], plan[2], plan[3], plan[9], *(d["hash"] for d in definitions()), graph["sourceFactory"]["address"],
        graph["sourceFactory"]["runtimeHash"], keccak256(encode((t.FACTORY_DEPENDENCIES,), (factory_dependencies,))), *t.SNAPSHOT_DEFINITION_HASHES)


def _context(context, graph):
    chain, cid, token, stamp = (uint(context[k]) for k in ("chainId", "collectionId", "tokenId", "timestamp"))
    require(chain > 0 and cid > 0 and token > 0 and stamp > 0, "policy V2 context")
    require(type(graph) is dict and set(GRAPH_KEYS) <= set(graph), "policy V2 graph roles")
    runtimes = {}
    for row in graph.values():
        _closed(row, ("address", "runtimeHash"), "graph row")
        a, h = row["address"], row["runtimeHash"]
        require(any(hex_bytes(a, 20)) and any(hex_bytes(h, 32)), "policy V2 empty graph pin")
        require(a not in runtimes or runtimes[a] == h, "policy V2 graph runtime contradiction")
        runtimes[a] = h
    require(context["core"] == graph["core"]["address"], "policy V2 Core differs")
    return chain, cid, token, stamp, runtimes


def _uri(value):
    raw = value.encode("utf-8")
    allowed = (raw.startswith(b"https://") and len(raw) > 8 and raw[8] not in b"/?#") or (
        raw.startswith(b"ipfs://") and len(raw) > 7) or (raw.startswith(b"ar://") and len(raw) > 5)
    require(0 < len(raw) <= 2048 and allowed and all(b > 32 and b != 127 for b in raw), "policy V2 root URI")


def _roots(value, chain, cid, stamp, graph, statement):
    _closed(value, ("selectedRootHash", "scopeHead", "collectionAggregate", "history"), "roots")
    history = value["history"]
    require(type(history) is list and 0 < len(history) <= t.MAX_HISTORY, "scoped policy root history bound")
    core, router = graph["core"]["address"], graph["router"]["address"]
    prior, prior_time, heads, records = (0, ZERO), 0, {}, {}
    for row in history:
        _closed(row, ("recordHash", "record", "aggregate", "binding"), "root row")
        r, b, aggregate = _v(t.ROOT_RECORD,row["record"]), _v(t.ROOT_BINDING,row["binding"]), _v(t.ROOT_AGGREGATE,row["aggregate"])
        scope = valid_scope(r[0][0], cid); subject = scope_subject(chain,core,scope)
        require(r[0][1] == heads.get(subject,ZERO), "scoped policy root predecessor")
        empty = b == tuple(ZERO_ADDRESS if kind == "address" else ZERO for kind in t.ROOT_BINDING)
        require(r[0][2] != ZERO and r[0][3] > 0 and r[1] != ZERO_ADDRESS and r[11] != ZERO_ADDRESS
            and all(r[i] != ZERO for i in (2,3,4,5,7,8,10,14,15,16)) and r[9] > 0 and r[12] in (7,8) and r[13] > 0
            and 0 < r[6] <= (1818 if empty else t.MAX_OUTPUTS) and prior_time <= r[17] <= stamp and r[17] > 0,
            "scoped policy original root fields")
        require(scope[0] != 1 or r[6] == 1, "scoped policy TOKEN root count")
        _uri(r[0][4])
        if empty:
            require(r[15] == original.root_state_hash(chain,router,core,r), "scoped policy V1 root state")
        else:
            require(b[0] == ROOT_PROFILE and all(v != (ZERO_ADDRESS if kind == "address" else ZERO)
                for kind,v in zip(t.ROOT_BINDING,b)), "scoped policy root binding profile/fields")
            require(b[12:17] == tuple(d["hash"] for d in definitions()) and b[20:] == t.SNAPSHOT_DEFINITION_HASHES,
                "scoped policy root definition hashes")
            require(r[15] == root_state_hash(chain,router,core,r,b), "scoped policy V2 root state")
        require(aggregate == next_aggregate(chain,router,core,prior,r), "scoped policy complete collection aggregate")
        digest = original.root_hash(chain,router,core,r,aggregate) if empty else root_hash(chain,router,core,r,b,aggregate)
        require(row["recordHash"] == digest and digest not in records, "scoped policy root record hash/duplicate")
        records[digest] = (r,b); heads[subject] = digest; prior,prior_time = aggregate,r[17]
    require(_v(t.ROOT_AGGREGATE,value["collectionAggregate"]) == prior, "scoped policy current collection aggregate")
    selected = value["selectedRootHash"]
    require(selected == statement[7][0] and selected in records, "scoped policy selected original root")
    require(value["scopeHead"] == heads.get(scope_subject(chain,core,statement[0])), "scoped policy current scope head")
    r,b = records[selected]
    require(b[0] == ROOT_PROFILE and r[0][0] == statement[0]
        and r[0][2] == statement[7][1] and r[1:3] == (graph["policySnapshot"]["address"],graph["policySnapshot"]["runtimeHash"])
        and r[3] == statement[5] and r[14] == route_hash(chain,graph,statement[0]), "scoped policy selected route/snapshot")
    return r,b


def validate(content, context, graph, statement):
    """Validate supplied original bytes/commitments; source authentication is external."""
    _closed(content, ("roots", "checkpoint", "manifest"), "content")
    chain, cid, token, stamp, runtimes = _context(context, graph)
    core, router = graph["core"]["address"], graph["router"]["address"]
    s = _v(t.STATEMENT, statement); scope = valid_scope(s[0], cid)
    require(scope[0] != 1 or scope[2] == token, "scoped policy TOKEN target differs")
    root, binding = _roots(content["roots"], chain, cid, stamp, graph, s)
    c, mrow = content["checkpoint"], content["manifest"]
    _closed(c, ("id", "salt", "plan", "outputs", "selectionPlan", "selectionRows", "factoryDependencies"), "checkpoint")
    _closed(mrow, ("recordHash", "planHash", "record", "plan", "artifactHash", "artifact", "coverage", "chunks"), "manifest")
    p, sp = _v(t.CONTENT_PLAN, c["plan"]), _v(t.SELECTION_PLAN, c["selectionPlan"])
    outputs, selections = _v(Array(t.OUTPUT, t.MAX_OUTPUTS), c["outputs"]), _v(Array(t.SELECTION_ROW, t.MAX_OUTPUTS), c["selectionRows"])
    require(p[4] == sp[0] == scope and 0 < p[5] <= t.MAX_OUTPUTS and p[5] == p[6] == sp[3] == sp[4] == len(outputs) == len(selections)
        and all(v != ZERO for v in p[:4]) and sp[1] != ZERO and sp[2] != ZERO, "policy V2 complete checkpoint/selection")
    require(p[1] == keccak256(encode((t.SELECTION_PLAN,), (sp,))) and sp[5] == selection_chain(chain, core, router, selections),
        "policy V2 original selection hash/chain")
    require(c["id"] == checkpoint_hash(chain, graph, p, c["salt"]), "policy V2 checkpoint identity")
    def pin(a, h, optional=False):
        hex_bytes(a, 20); hex_bytes(h, 32)
        require((optional and a == ZERO_ADDRESS and h == ZERO) or (a != ZERO_ADDRESS and h != ZERO), "policy V2 selection dependency")
        if a == ZERO_ADDRESS: return
        require(a not in runtimes or runtimes[a] == h, "policy V2 shared runtime contradiction")
        runtimes[a] = h
    previous = 0
    for row, original in zip(outputs, selections):
        leaf, e = row[0], row[4]
        require(leaf[0] == original[0] > previous and leaf[1] != ZERO and leaf[3] == row[3] != ZERO
            and leaf[4] == ZERO and leaf[5] != ZERO and all(v != ZERO for v in original[1:5]), "policy V2 output/selection row")
        previous = leaf[0]
        selected = original[5]
        pin(selected[0], selected[1]); pin(selected[3], selected[4])
        require(all(selected[i] != ZERO for i in (2, 5, 6, 7, 8, 9, 10)), "policy V2 immutable renderer selection")
        require(selected[5:7] == (schema_id("6529STREAM_RENDERER_V1"), schema_id("6529STREAM_STATIC_RENDERER_V1")),
            "policy V2 original STATIC renderer")
        require(original[6][:3] == (core, router, graph["metadata"]["address"]), "policy V2 renderer source graph")
        for j, (a, h) in enumerate(zip(original[6], original[7])): pin(a, h, j >= 4)
        require(e[0] == original[6][3] and e[1] == original[7][3] and e[2] != ZERO, "policy V2 entropy coordinator/policy")
        if e[7]:
            require(not e[8] and e[9] == ZERO and e[6] == 1 and ((e[3] == 1 and e[4] == 0) or (e[3] == 2 and e[4] == 2))
                and row[5] != ZERO, "policy V2 terminal readiness")
        else:
            require(e[8] and e[3] == 5 and e[4] == 2 and e[6] == 0 and row[5] == ZERO, "policy V2 finalized readiness")
        require(row[1] == selection_row_hash(chain, core, router, original)
            and row[2] == source_facts_hash(graph, p, original, row), "policy V2 output source facts")
    leaves = tuple(row[0] for row in outputs)
    lc, oc = output_chains(chain, core, outputs)
    require(p[7] == lc and p[8] == neutral.tree_root(chain, core, leaves) and p[9] == oc, "policy V2 output tree/chains")
    dependencies = _v(t.FACTORY_DEPENDENCIES,c["factoryDependencies"])
    require(dependencies[0] == tuple(graph[k]["address"] for k in ("core","metadata","scopeMembership","coordinatorInventory"))
        and dependencies[1] == tuple(graph[k]["runtimeHash"] for k in ("core","metadata","scopeMembership","coordinatorInventory"))
        and dependencies[2] == chain and dependencies[3] > 0 and dependencies[4] > 0, "scoped policy factory dependencies")
    require(binding == binding_for(graph, c["id"], p, dependencies), "policy V2 exact original binding")
    m, mp = _v(t.OUTPUT_MANIFEST, mrow["record"]), _v(t.OUTPUT_PLAN, mrow["plan"])
    require(m[:5] == (c["id"], binding[6], graph["entropySourceSet"]["address"], p[2], p[3])
        and m[5] == mrow["artifactHash"] and m[6] != ZERO and m[7] == root[8]
        and m[8] == p[8] == root[5] and m[9] == p[9] and m[10] == root[7] and m[11] == scope
        and m[12] == p[5] == root[6] and m[13] == 576 + 640 * m[12], "policy V2 manifest/checkpoint/root")
    ph = manifest_plan_hash(chain, graph, m)
    require(mrow["planHash"] == ph and mrow["recordHash"] == manifest_record_hash(ph)
        and mp == (m, m[12], mrow["recordHash"]), "policy V2 verified manifest")
    a, coverage = _v(t.ARTIFACT, mrow["artifact"]), _v(t.COVERAGE, mrow["coverage"])
    require(mrow["artifactHash"] == neutral.artifact_hash(chain, graph["artifacts"]["address"], core, a)
        and a[:6] == (m[7], OUTPUT_SCHEMA, OUTPUT_CANON, 1, m[10], m[13]), "policy V2 artifact")
    count = (m[13] + t.CHUNK_BYTES - 1) // t.CHUNK_BYTES
    require(len(a[6]) == len(a[7]) == count <= t.MAX_PARTS and type(mrow["chunks"]) is list and len(mrow["chunks"]) == count,
        "policy V2 complete chunks")
    require(coverage[:8] == (m[6], mrow["artifactHash"], m[7], OUTPUT_SCHEMA, OUTPUT_CANON, m[10], m[13], count)
        and coverage[8] != ZERO and coverage[9] != ZERO and coverage[8] != coverage[9]
        and coverage[10] > 0 and coverage[11] != ZERO, "policy V2 coverage receipt")
    parts = []
    for index, chunk in enumerate(mrow["chunks"]):
        _closed(chunk, ("pointer", "codeHash", "runtime"), "chunk")
        raw = hex_bytes(chunk["runtime"]); size = min(t.CHUNK_BYTES, m[13] - index * t.CHUNK_BYTES)
        require(len(raw) == size + 1 and raw[0] == 0 and keccak256(raw) == chunk["codeHash"]
            and a[7][index] == size and keccak256(raw[1:]) == a[6][index], "policy V2 chunk bytes/hash")
        pin(chunk["pointer"], chunk["codeHash"]); parts.append(raw[1:])
    whole = b"".join(parts)
    require(whole == manifest_bytes(chain, graph, c["id"], p, outputs) and len(whole) == m[13] and keccak256(whole) == m[10],
        "policy V2 complete canonical manifest bytes")
    require(s[2:5] == (m[8], m[12], t.LEAF_SCHEMA), "policy V2 statement content")
    indices = [i for i, leaf in enumerate(leaves) if leaf[0] == token]
    require(len(indices) == 1, "policy V2 target token absent/duplicate")
    index = indices[0]; leaf = leaves[index]
    return {"selectedRootHash": content["roots"]["selectedRootHash"], "selectedRoot": json_values(root), "selectedBinding": json_values(binding),
        "selectedRootStatus": "still_current" if content["roots"]["selectedRootHash"] == content["roots"]["scopeHead"] else "later_superseded",
        "contentPlan": json_values(p), "outputManifest": json_values(m), "manifestRecordHash": mrow["recordHash"],
        "checkpointId": c["id"], "selectionId": p[0], "selectionPlan": json_values(sp),
        "selectionRows": json_values(selections), "outputs": json_values(outputs),
        "selectionRowHashes": [row[1] for row in outputs], "tokenIds": [str(row[0][0]) for row in outputs],
        "readiness": json_values(tuple(row[4] for row in outputs)), "sourceFactsHashChecked": True,
        "outputManifestBytes": whole, "targetProof": {"leafIndex": str(index), "leafCount": str(len(leaves)),
            "leaf": json_values(leaf), "leafHash": neutral.leaf_hash(chain, core, leaf), "root": m[8],
            "proof": list(neutral.proof_for(chain, core, leaves, index)), "rootRecordHash": content["roots"]["selectedRootHash"], "manifestHash": m[10]},
        "artifactCoverage": {"originalReceiptRetained": True, "coverageHash": m[6], "perChunkArchivePreimagesReconstructed": False},
        "outputQualification": {"completeOriginalHashRowsReconstructed": True, "renderedBytesRetained": False,
            "sourceFactsPreimagesReconstructed": True, "terminalAdmissionPreimagesReconstructed": False,
            "historicalRendererExecutionReenacted": False, "historicalAuthorityRevalidated": False, "actualChainAcceptance": False}}


EVENT_SIGNATURES = {
    "root": "ScopedContentRootPublished(uint16,uint256,bytes32,bytes32," + neutral.abi_signature(t.ROOT_RECORD) + "," + neutral.abi_signature(t.ROOT_AGGREGATE) + ")",
    "binding": "ScopedPolicyContentRootBindingPublished(uint16,uint256,bytes32,bytes32," + neutral.abi_signature(t.ROOT_BINDING) + ")",
    "contentStarted": "StaticContentStarted(uint16,bytes32,bytes32," + neutral.abi_signature(t.CONTENT_PLAN) + ")",
    "contentAppended": "StaticContentAppended(uint16,bytes32,uint64," + neutral.abi_signature(t.OUTPUT) + ",bytes32)",
    "contentCompleted": "StaticContentCompleted(uint16,bytes32,bytes32,bytes32,uint64)",
    "manifestStarted": "OutputManifestStarted(uint16,bytes32," + neutral.abi_signature(t.OUTPUT_MANIFEST) + ")",
    "manifestAdvanced": "OutputManifestAdvanced(uint16,bytes32,uint64,uint64)",
    "manifestVerified": "OutputManifestVerified(uint16,bytes32,bytes32," + neutral.abi_signature(t.OUTPUT_MANIFEST) + ")",
    "artifactRecorded": neutral.EVENT_SIGNATURES["artifactRecorded"],
    "coverageCompleted": neutral.EVENT_SIGNATURES["coverageCompleted"],
}
EVENTS = {key: schema_id(value) for key, value in EVENT_SIGNATURES.items()}


def expected_events(content, context, graph, statement):
    """Exact descriptors. Manifest advance partition and event coordinates are external.

    Coverage plan is the one nonzero wildcard topic because it is not retained
    inside its receipt. V1 roots deliberately use their original schema version.
    """
    validate(content, context, graph, statement)
    chain, cid = uint(context["chainId"]), uint(context["collectionId"])
    result = []
    def add(host, key, kind, topics, kinds, values):
        result.append({"kind": kind, "address": graph[host]["address"], "topics": (EVENTS[key], *topics),
            "data": "0x" + encode(kinds, values).hex()})
    for row in content["roots"]["history"]:
        r,b,aggregate = _v(t.ROOT_RECORD,row["record"]),_v(t.ROOT_BINDING,row["binding"]),_v(t.ROOT_AGGREGATE,row["aggregate"])
        version = 2 if b[0] == ROOT_PROFILE else 1
        topics = (neutral._topic("uint256",cid),scope_subject(chain,graph["core"]["address"],r[0][0]),row["recordHash"])
        add("router","root","root_published",topics,("uint16",t.ROOT_RECORD,t.ROOT_AGGREGATE),(version,r,aggregate))
        if version == 2: add("router","binding","root_binding_published",topics,("uint16",t.ROOT_BINDING),(2,b))
    c = content["checkpoint"]; p = _v(t.CONTENT_PLAN, c["plan"]); key = c["id"]
    initial = (*p[:6], 0, ZERO, ZERO, ZERO)
    add("policyContent", "contentStarted", "content_started", (key,), ("uint16", "bytes32", t.CONTENT_PLAN), (2, c["salt"], initial))
    for index, raw in enumerate(c["outputs"]):
        row = _v(t.OUTPUT, raw)
        add("policyContent", "contentAppended", "content_appended", (key, neutral._topic("uint64", index)),
            ("uint16", t.OUTPUT, "bytes32"), (2, row, neutral.leaf_hash(chain, graph["core"]["address"], row[0])))
    add("policyContent", "contentCompleted", "content_completed", (key,),
        ("uint16", "bytes32", "bytes32", "uint64"), (2, p[8], p[9], p[5]))
    m = content["manifest"]; r = _v(t.OUTPUT_MANIFEST, m["record"])
    add("outputManifest", "manifestStarted", "manifest_started", (m["planHash"],), ("uint16", t.OUTPUT_MANIFEST), (2, r))
    add("outputManifest", "manifestVerified", "manifest_verified", (m["recordHash"], m["planHash"]), ("uint16", t.OUTPUT_MANIFEST), (2, r))
    add("artifacts", "artifactRecorded", "artifact_recorded", (m["artifactHash"],), ("uint16", t.ARTIFACT), (1, _v(t.ARTIFACT, m["artifact"])))
    cover = _v(t.COVERAGE, m["coverage"])
    add("artifacts", "coverageCompleted", "coverage_completed", (cover[0], None), ("uint16", t.COVERAGE), (1, cover))
    return tuple(result)


_DEFINITIONS = (('STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2', 0, '{"name":"STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2","version":2,"profile":"6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2","format":"Solidity ABI","scope":"Exact complete TOKEN/RELEASE/SEASON checkpoint; COLLECTION,VIEW and non-ONCHAIN modes refused","rows":"Every IStreamScopedPolicyContentCheckpointV2.Output in exact authoritative checkpoint order","fields":["StreamTokenContentLeaf(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)","bytes32 selectionRowHash","bytes32 sourceFactsHash","bytes32 htmlHash","TokenReadiness(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,uint8 status,uint8 mode,uint8 securityClass,uint8 renderRequirement,bool terminal,bool finalized,bytes32 seed)","bytes32 terminalAdmissionHash"],"entropy":"Original coordinatorAtMint and complete frozen policy-set hash; terminal DISABLED and ASYNC NOT_REQUIRED require independently admitted terminal STATIC profile with zero seed and finalized=false; finalized rows require actual status5 and exact original seed","commitments":"Original CMC six-field content tree plus distinct V2 ordered output chain and full policy/inventory commitments","preservation":"Output hashes and source commitments only; complete JSON,HTML,image and tokenData bytes require separate preserved artifacts","authority":"Current archive coverage and checkpoint computation are evidence only; no Artist,publication or finality authority","current":"Every read revalidates complete source policy set and renders all prior output rows; immutable history remains readable"}'), ('STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2', 1, '{"name":"STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2","version":2,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,StreamFinalityScope scope,bytes32 contentRoot,bytes32 outputRoot,uint64 tokenCount,IStreamScopedPolicyContentCheckpointV2.Output[] rows)","schemaId":"keccak256(STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2)","checkpointStateHash":"keccak256(abi.encode(complete V2 checkpoint Plan))","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","headBytes":544,"arrayOffset":544,"headerBytesIncludingArrayCount":576,"rowBytes":640,"length":"576+640*tokenCount","arrayCount":"Exactly positive tokenCount","words":"32-byte big-endian; addresses and narrow unsigned integers zero-extended; booleans exactly0or1","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","rowOrder":"Exact original checkpoint order","hash":"Keccak-256 of complete exact manifest bytes; not JCS"}'), ('STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2', 0, '{"name":"STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2","version":2,"fields":["uint256 tokenId","bytes32 metadataHash","bytes32 imageHash","bytes32 animationHash","bytes32 contentHash","bytes32 tokenDataHash"],"encoding":"Original CMC ordered six-field content leaf/tree; no preimage change","metadata":"Exact current full Router tokenJSON bytes, not historical compact JSON","animation":"Exact current tokenHTML bytes; nonempty","image":"Exact decoded admitted inline bytes; zero only if absent","content":"No separate content asset in this finite profile; zero","entropy":"Truthful terminal or finalized original-source state authenticated by distinct V2 output manifest; terminal is never a fabricated finalized seed","authority":"Leaf hash alone is not root adoption,Artist consent,snapshot or finality acceptance"}'), ('STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2', 0, '{"name":"STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"profile":"6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2","record":"IStreamScopedContentRootPublication.Record plus IStreamScopedPolicyContentRootPublicationV2.Binding and historical Aggregate","scope":"Exact TOKEN,RELEASE or SEASON; COLLECTION and VIEW refused","source":"Current root-free scoped-policy V2 snapshot,complete authoritative membership,actual source factory and plan,runtime-pinned full original frozen policies,selection,checkpoint and covered output manifest","bindingFields":["bytes32 profileId","address outputManifest","bytes32 outputManifestCodeHash","address checkpoint","bytes32 checkpointCodeHash","bytes32 checkpointHash","bytes32 checkpointStateHash","address entropySourceSet","bytes32 entropySourceSetCodeHash","bytes32 inventoryHash","bytes32 policyChainHash","bytes32 outputRoot","bytes32 outputSchemaHash","bytes32 outputCanonicalizationHash","bytes32 leafSchemaHash","bytes32 rootSchemaHash","bytes32 rootCanonicalizationHash","address sourceFactory","bytes32 sourceFactoryCodeHash","bytes32 factoryDependenciesHash","bytes32 snapshotSchemaHash","bytes32 snapshotProfileHash","bytes32 snapshotCanonicalizationHash"],"authority":"Original Metadata SNAPSHOT class7 collection or class8 global grant,exact Artist operation17 CONTENT_ROOT consent and original replay/evolution state","lineage":"One original scoped head and collection aggregate across V1 and V2; exact predecessor required","entropy":"Terminal DISABLED or ASYNC NOT_REQUIRED remains zero seed and finalized=false; finalized rows retain actual original status5 and seed","schemas":"Exact ACTIVE RAW_BYTES output,leaf,root and snapshot definitions","retention":"Schema2 root event retains historical aggregate; companion event retains binding; current aggregate cannot authenticate historical consent"}'), ('STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2', 1, '{"name":"STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"encoding":"abi.encode(IStreamScopedContentRootPublication.Record,IStreamScopedPolicyContentRootPublicationV2.Binding,IStreamScopedContentRootPublication.Aggregate)","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2),chainId,router,core,recordWithStateHashConsentAndPublishedAtZero,binding))","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2),chainId,router,core,completedRecord,binding,historicalAggregate))","signedFamily":"Original 6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1 wraps original legacy family with historical aggregate; individual stateHash is not signed family","aggregate":"Original 6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1 transition preimage unchanged","routeHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2),chainId,orderedSixTargets,orderedSixRuntimeHashes,metadata,metadataRuntimeHash,scope))","targets":"core,artist,router,selectedFinality,selectedProvider,scopeSelectedSnapshot","strings":"Exact validated UTF-8 URI bytes; no normalization","canonical":"Solidity ABI only; alternate offsets,trailing bytes and noncanonical words forbidden","history":"V1 record and snapshot bytes retain their original interpretation; V2 never enters V1 snapshot decoders"}'))
