"""Pure original scoped STATIC output/root correspondence at the frozen native source.

The complete preserved artifact contains output hashes, not rendered JSON/HTML,
image or tokenData bytes. Historical renderer execution, native publication
authority and per-chunk archive receipt preimages are deliberately not proved.
No network, current-state substitution or runtime source-file loading occurs.
"""
from . import scoped_static_types as t
from . import native_finality_wire as neutral
from .canonical import hex_bytes, keccak256, schema_id, subject_id, uint
from .chain_abi import Array, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = t.SOURCE_REVISION
PROFILE = schema_id("6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1")
LEAF_CHAIN = schema_id("6529STREAM_STATIC_CONTENT_LEAVES_V1")
OUTPUT_CHAIN = schema_id("6529STREAM_STATIC_FULL_OUTPUTS_V1")
OUTPUT_SCHEMA, OUTPUT_CANON = t.OUTPUT_SCHEMA, t.OUTPUT_CANON
ROUTE_KEYS = ("core", "artist", "router", "finality", "provider", "scopedSnapshot")
GRAPH_KEYS = (*ROUTE_KEYS, "metadata", "staticSelection", "staticContent", "outputManifest", "artifacts")

_DEFINITIONS = (
    ("STREAM_STATIC_OUTPUT_MANIFEST_V1", 0, '{"name":"STREAM_STATIC_OUTPUT_MANIFEST_V1","version":1,"profile":"6529STREAM_STATIC_CURRENT_FULL_CONTENT_V1","format":"Solidity ABI","scope":"Exact complete checkpoint scope; current profile excludes VIEW and non-ONCHAIN modes","rows":"Every original IStreamStaticContentCheckpoint.Output in exact checkpoint order","fields":["StreamTokenContentLeaf(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)","bytes32 selectionRowHash","bytes32 sourceFactsHash","bytes32 htmlHash"],"commitments":"Original CMC six-field content tree plus distinct ordered output chain","preservation":"This artifact preserves output hashes and source commitments, not full JSON,HTML,image or tokenData bytes","authority":"Current artifact coverage and checkpoint computation do not establish artist association,publication authority or finality acceptance","history":"Current validation repeats full original outputs and current two-family archival completion; historical records remain readable"}'),
    ("STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1", 1, '{"name":"STREAM_ABI_STATIC_OUTPUT_MANIFEST_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,bytes32 checkpointStateHash,StreamFinalityScope scope,bytes32 contentRoot,bytes32 outputRoot,uint64 tokenCount,IStreamStaticContentCheckpoint.Output[] rows)","schemaId":"keccak256(STREAM_STATIC_OUTPUT_MANIFEST_V1)","checkpointStateHash":"keccak256(abi.encode(complete original checkpoint Plan))","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","headBytes":448,"arrayOffset":448,"headerBytesIncludingArrayCount":480,"rowBytes":288,"length":"480+288*tokenCount","arrayCount":"Exactly positive tokenCount","words":"32-byte big-endian,addresses and narrow unsigned integers zero-extended","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","rowOrder":"Exact checkpoint order","hash":"Keccak-256 of exact complete manifest bytes; not JCS"}'),
)


def definitions():
    """Exact RAW_BYTES schema/canonicalization documents from the original producer."""
    return tuple({"id": schema_id(name), "name": name, "kind": kind,
        "hash": keccak256(text.encode("utf-8")), "bytes": text.encode("utf-8")}
        for name, kind, text in _DEFINITIONS)


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), "scoped STATIC " + label + " fields")


def _v(kind, value):
    result = neutral.from_json(kind, value)
    encode((kind,), (result,))
    return result


def _hash(domain, kinds, values):
    return keccak256(encode(("bytes32", *kinds), (schema_id(domain), *values)))


def valid_scope(value, collection=None):
    scope = _v(t.SCOPE, value)
    require(scope[0] in (1, 2, 3) and scope[1] > 0
        and (collection is None or scope[1] == collection), "scoped STATIC scope/profile")
    require((scope[0] == 1 and scope[2] > 0 and scope[3] == ZERO)
        or (scope[0] in (2, 3) and scope[2] == 0 and scope[3] != ZERO), "scoped STATIC scope shape")
    return scope


def scope_subject(chain, core, scope):
    scope = valid_scope(scope)
    return subject_id("token" if scope[0] == 1 else "scope", str(chain), core, str(scope[1]),
        token_id=str(scope[2]), scope_type=str(scope[0]), scope_id=scope[3])


def route_hash(chain, graph):
    return _hash("6529STREAM_SCOPED_CONTENT_ROOT_ROUTE_V1",
        ("uint256", ("address",) * 6, ("bytes32",) * 6, "address", "bytes32"),
        (chain, tuple(graph[k]["address"] for k in ROUTE_KEYS), tuple(graph[k]["runtimeHash"] for k in ROUTE_KEYS),
         graph["metadata"]["address"], graph["metadata"]["runtimeHash"]))


def root_state_hash(chain, router, core, record):
    value = list(_v(t.ROOT_RECORD, record)); value[15], value[16], value[17] = ZERO, ZERO, 0
    return _hash("6529STREAM_SCOPED_CONTENT_ROOT_STATE_V1", ("uint256", "address", "address", t.ROOT_RECORD),
        (chain, router, core, value))


def next_aggregate(chain, router, core, prior, record):
    prior, r = _v(t.ROOT_AGGREGATE, prior), _v(t.ROOT_RECORD, record)
    require(prior[0] < (1 << 64) - 1, "scoped STATIC aggregate overflow")
    revision = prior[0] + 1
    digest = _hash("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1",
        ("uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32", "bytes32", "bytes32"),
        (chain, router, core, r[0][0][1], prior[1], revision, scope_subject(chain, core, r[0][0]), r[0][1], r[15]))
    return (revision, digest)


def root_hash(chain, router, core, record, aggregate):
    return _hash("6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1",
        ("uint256", "address", "address", t.ROOT_RECORD, t.ROOT_AGGREGATE),
        (chain, router, core, record, aggregate))


def checkpoint_hash(chain, host, selection_host, plan, salt):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", "bytes32"),
        (PROFILE, chain, host, selection_host, plan[0], plan[1], salt)))


def output_chains(chain, core, outputs):
    leaves, output_root = ZERO, ZERO
    for index, row in enumerate(outputs):
        leaves = keccak256(encode(("bytes32", "bytes32", "uint256", "bytes32"),
            (LEAF_CHAIN, leaves, index, neutral.leaf_hash(chain, core, row[0]))))
        output_root = keccak256(encode(("bytes32", "bytes32", "uint256", t.OUTPUT),
            (OUTPUT_CHAIN, output_root, index, row)))
    return leaves, output_root


def manifest_bytes(chain, core, checkpoint, checkpoint_id, plan, outputs):
    return encode(t.OUTPUT_ENVELOPE, (OUTPUT_SCHEMA, chain, core, checkpoint, checkpoint_id,
        keccak256(encode((t.CONTENT_PLAN,), (plan,))), plan[2], plan[6], plan[7], plan[3], outputs))


def manifest_plan_hash(chain, host, core, checkpoint, artifacts, manifest):
    return _hash("6529STREAM_STATIC_OUTPUT_MANIFEST_PLAN_V1",
        ("uint256", "address", "address", "address", "address", t.OUTPUT_MANIFEST),
        (chain, host, core, checkpoint, artifacts, manifest))


def manifest_record_hash(plan_hash):
    return _hash("6529STREAM_STATIC_OUTPUT_MANIFEST_VERIFIED_V1", ("bytes32",), (plan_hash,))


def _context(context, graph):
    chain, cid, token, timestamp = (uint(context[key]) for key in ("chainId", "collectionId", "tokenId", "timestamp"))
    require(chain > 0 and cid > 0 and token > 0 and timestamp > 0, "scoped STATIC context identity")
    runtimes = {}
    for key in GRAPH_KEYS:
        row = graph[key]
        _closed(row, ("address", "runtimeHash"), "graph row")
        address, digest = row["address"], row["runtimeHash"]
        require(any(hex_bytes(address, 20)) and any(hex_bytes(digest, 32)), "scoped STATIC empty graph pin")
        require(address not in runtimes or runtimes[address] == digest, "scoped STATIC conflicting graph runtime")
        runtimes[address] = digest
    require(context["core"] == graph["core"]["address"], "scoped STATIC context Core differs")
    return chain, cid, token, timestamp


def _uri(value):
    raw = value.encode("utf-8")
    accepted = (raw.startswith(b"https://") and len(raw) > 8 and raw[8] not in b"/?#") or (
        raw.startswith(b"ipfs://") and len(raw) > 7) or (raw.startswith(b"ar://") and len(raw) > 5)
    require(0 < len(raw) <= 2048 and accepted and all(byte > 32 and byte != 127 for byte in raw),
        "scoped STATIC root URI")


def _roots(value, chain, cid, timestamp, graph, statement):
    _closed(value, ("selectedRootHash", "scopeHead", "collectionAggregate", "history"), "roots")
    history = value["history"]
    require(type(history) is list and 0 < len(history) <= t.MAX_HISTORY, "scoped STATIC root history bound")
    core, router = graph["core"]["address"], graph["router"]["address"]
    prior, prior_time, heads, records = (0, ZERO), 0, {}, {}
    for row in history:
        _closed(row, ("recordHash", "record", "aggregate"), "root row")
        r, aggregate = _v(t.ROOT_RECORD, row["record"]), _v(t.ROOT_AGGREGATE, row["aggregate"])
        scope = valid_scope(r[0][0], cid); subject = scope_subject(chain, core, scope)
        require(r[0][1] == heads.get(subject, ZERO), "scoped STATIC root predecessor")
        require(r[0][2] != ZERO and r[0][3] > 0 and r[1] != ZERO_ADDRESS and r[11] != ZERO_ADDRESS
            and all(r[index] != ZERO for index in (2, 3, 4, 5, 7, 8, 10, 14, 15, 16))
            and 0 < r[6] <= t.MAX_OUTPUTS and r[9] > 0 and r[12] in (7, 8) and r[13] > 0
            and 0 < r[17] <= timestamp and r[17] >= prior_time, "scoped STATIC original root fields")
        require(scope[0] != 1 or r[6] == 1, "scoped STATIC TOKEN root count")
        _uri(r[0][4])
        require(r[15] == root_state_hash(chain, router, core, r), "scoped STATIC root state hash")
        require(aggregate == next_aggregate(chain, router, core, prior, r), "scoped STATIC collection aggregate")
        digest = root_hash(chain, router, core, r, aggregate)
        require(row["recordHash"] == digest and digest not in records, "scoped STATIC root record hash/duplicate")
        heads[subject] = digest; records[digest] = r; prior, prior_time = aggregate, r[17]
    selected = value["selectedRootHash"]
    require(value["collectionAggregate"] is not None and _v(t.ROOT_AGGREGATE, value["collectionAggregate"]) == prior,
        "scoped STATIC final collection aggregate")
    require(selected == statement[7][0] and selected in records, "scoped STATIC selected original root")
    target_subject = scope_subject(chain, core, statement[0])
    require(value["scopeHead"] == heads.get(target_subject), "scoped STATIC current scope head")
    r = records[selected]
    require(r[0][0] == statement[0] and r[1:3] == (graph["scopedSnapshot"]["address"], graph["scopedSnapshot"]["runtimeHash"])
        and r[14] == route_hash(chain, graph), "scoped STATIC selected root route/scope")
    require(r[0][2] == statement[7][1] and r[3] == statement[5], "scoped STATIC original snapshot commitment")
    return r


def validate(contentgroup, context, graph, statement):
    """Validate exact original commitments and return joins plus the ordered target proof.

    This pure supplied-data check does not authenticate the supplied RPC source,
    prove historical renderer execution, or replace native publication consent.
    """
    _closed(contentgroup, ("roots", "checkpoint", "manifest"), "content group")
    chain, cid, token, timestamp = _context(context, graph)
    core = graph["core"]["address"]
    statement = _v(t.STATEMENT, statement); scope = valid_scope(statement[0], cid)
    require(scope[0] != 1 or scope[2] == token, "scoped STATIC TOKEN target differs")
    selected = _roots(contentgroup["roots"], chain, cid, timestamp, graph, statement)
    checkpoint, manifest = contentgroup["checkpoint"], contentgroup["manifest"]
    _closed(checkpoint, ("id", "salt", "plan", "outputs"), "checkpoint")
    _closed(manifest, ("recordHash", "planHash", "record", "plan", "artifactHash", "artifact", "coverage", "chunks"), "manifest")
    p = _v(t.CONTENT_PLAN, checkpoint["plan"])
    outputs = _v(Array(t.OUTPUT, t.MAX_OUTPUTS), checkpoint["outputs"])
    require(p[2] == scope and p[0] != ZERO and p[1] != ZERO and 0 < p[3] <= t.MAX_OUTPUTS
        and p[4] == p[3] == len(outputs), "scoped STATIC complete checkpoint")
    require(scope[0] != 1 or p[3] == 1, "scoped STATIC TOKEN checkpoint count")
    require(checkpoint["id"] == checkpoint_hash(chain, graph["staticContent"]["address"],
        graph["staticSelection"]["address"], p, checkpoint["salt"]), "scoped STATIC checkpoint identity")
    leaves = tuple(row[0] for row in outputs)
    for row in outputs:
        leaf = row[0]
        require(leaf[1] != ZERO and leaf[3] != ZERO and leaf[4] == ZERO and leaf[5] != ZERO
            and row[1] != ZERO and row[2] != ZERO and row[3] == leaf[3], "scoped STATIC output semantics")
    leaf_chain, output_root = output_chains(chain, core, outputs)
    require(p[5] == leaf_chain and p[6] == neutral.tree_root(chain, core, leaves) and p[7] == output_root,
        "scoped STATIC checkpoint root/output chain")
    m, mp = _v(t.OUTPUT_MANIFEST, manifest["record"]), _v(t.OUTPUT_PLAN, manifest["plan"])
    require(m[0] == checkpoint["id"] and m[1] == keccak256(encode((t.CONTENT_PLAN,), (p,)))
        and m[2] == manifest["artifactHash"] and m[3] != ZERO and m[4] == selected[8]
        and m[5] == p[6] == selected[5] and m[6] == p[7] and m[7] == selected[7]
        and m[8] == scope and m[9] == p[3] == selected[6] and m[10] == 480 + 288 * m[9],
        "scoped STATIC manifest/checkpoint/root fields")
    plan_hash = manifest_plan_hash(chain, graph["outputManifest"]["address"], core,
        graph["staticContent"]["address"], graph["artifacts"]["address"], m)
    require(manifest["planHash"] == plan_hash and manifest["recordHash"] == manifest_record_hash(plan_hash)
        and mp == (m, m[9], manifest["recordHash"]), "scoped STATIC verified manifest plan")
    a, coverage = _v(t.ARTIFACT, manifest["artifact"]), _v(t.COVERAGE, manifest["coverage"])
    require(manifest["artifactHash"] == neutral.artifact_hash(chain, graph["artifacts"]["address"], core, a)
        and a[:6] == (m[4], OUTPUT_SCHEMA, OUTPUT_CANON, 1, m[7], m[10]), "scoped STATIC artifact identity/hash")
    count = (m[10] + t.CHUNK_BYTES - 1) // t.CHUNK_BYTES
    require(len(a[6]) == len(a[7]) == count <= t.MAX_PARTS, "scoped STATIC artifact chunk count")
    require(coverage[:8] == (m[3], manifest["artifactHash"], m[4], OUTPUT_SCHEMA, OUTPUT_CANON, m[7], m[10], count)
        and coverage[8] != ZERO and coverage[9] != ZERO and coverage[8] != coverage[9]
        and coverage[10] > 0 and coverage[11] != ZERO, "scoped STATIC original coverage fields")
    require(type(manifest["chunks"]) is list and len(manifest["chunks"]) == count, "scoped STATIC chunk denominator")
    parts, carriers = [], {row["address"]: row["runtimeHash"] for row in graph.values()}
    for index, chunk in enumerate(manifest["chunks"]):
        _closed(chunk, ("pointer", "codeHash", "runtime"), "chunk")
        raw = hex_bytes(chunk["runtime"]) if type(chunk["runtime"]) is str else chunk["runtime"]
        size = min(t.CHUNK_BYTES, m[10] - index * t.CHUNK_BYTES)
        require(type(raw) is bytes and len(raw) == size + 1 and raw[0] == 0
            and any(hex_bytes(chunk["pointer"], 20)) and keccak256(raw) == chunk["codeHash"]
            and a[7][index] == size and keccak256(raw[1:]) == a[6][index], "scoped STATIC carrier bytes/hash")
        require(chunk["pointer"] not in carriers or carriers[chunk["pointer"]] == chunk["codeHash"],
            "scoped STATIC conflicting shared carrier runtime")
        carriers[chunk["pointer"]] = chunk["codeHash"]; parts.append(raw[1:])
    whole = b"".join(parts)
    require(whole == manifest_bytes(chain, core, graph["staticContent"]["address"], checkpoint["id"], p, outputs)
        and len(whole) == m[10] and keccak256(whole) == m[7], "scoped STATIC complete output manifest bytes")
    require(statement[2:5] == (m[5], m[9], neutral.LEAF_SCHEMA), "scoped STATIC statement root fields")
    indices = [i for i, leaf in enumerate(leaves) if leaf[0] == token]
    require(len(indices) == 1, "scoped STATIC target token absent/duplicate")
    index = indices[0]; leaf = leaves[index]
    return {"selectedRoot": json_values(selected), "checkpointId": checkpoint["id"],
        "selectedRootStatus": "still_current" if contentgroup["roots"]["scopeHead"] == contentgroup["roots"]["selectedRootHash"] else "later_superseded",
        "contentPlan": json_values(p), "outputManifest": json_values(m),
        "manifestRecordHash": manifest["recordHash"], "outputManifestBytes": whole,
        "selectionRowHashes": [row[1] for row in outputs], "tokenIds": [str(row[0][0]) for row in outputs],
        "targetProof": {"leafIndex": str(index), "leafCount": str(len(leaves)), "leaf": json_values(leaf),
            "leafHash": neutral.leaf_hash(chain, core, leaf), "root": m[5],
            "proof": list(neutral.proof_for(chain, core, leaves, index)),
            "rootRecordHash": contentgroup["roots"]["selectedRootHash"], "manifestHash": m[7]},
        "artifactCoverage": {"originalReceiptRetained": True, "coverageHash": m[3],
            "perChunkArchivePreimagesReconstructed": False},
        "outputQualification": {"completeOriginalHashRowsReconstructed": True,
            "renderedBytesRetained": False, "sourceFactsPreimagesReconstructed": False,
            "historicalRendererExecutionReenacted": False, "actualChainAcceptance": False}}


EVENT_SIGNATURES = {
    "root": "ScopedContentRootPublished(uint16,uint256,bytes32,bytes32," + neutral.abi_signature(t.ROOT_RECORD) + "," + neutral.abi_signature(t.ROOT_AGGREGATE) + ")",
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


def expected_events(contentgroup, context, graph, statement):
    """Exact required originals. Advancement batching/coordinates are separate joins.

    The unknown original coverage plan is a nonzero wildcard topic; its receipt
    is exact. No invented advance-event batch partition is returned.
    """
    validate(contentgroup, context, graph, statement)
    chain, cid = uint(context["chainId"]), uint(context["collectionId"])
    core = graph["core"]["address"]; result = []
    def add(host, name, kind, topics, types, values):
        result.append({"kind": kind, "address": graph[host]["address"], "topics": (EVENTS[name], *topics),
            "data": "0x" + encode(types, values).hex()})
    for row in contentgroup["roots"]["history"]:
        r, a = _v(t.ROOT_RECORD, row["record"]), _v(t.ROOT_AGGREGATE, row["aggregate"])
        add("router", "root", "root_published", (neutral._topic("uint256", cid), scope_subject(chain, core, r[0][0]), row["recordHash"]),
            ("uint16", t.ROOT_RECORD, t.ROOT_AGGREGATE), (1, r, a))
    c = contentgroup["checkpoint"]; p = _v(t.CONTENT_PLAN, c["plan"]); key = c["id"]
    initial = (*p[:4], 0, ZERO, ZERO, ZERO)
    add("staticContent", "contentStarted", "content_started", (key,), ("uint16", "bytes32", t.CONTENT_PLAN), (1, c["salt"], initial))
    for index, raw in enumerate(c["outputs"]):
        row = _v(t.OUTPUT, raw)
        add("staticContent", "contentAppended", "content_appended", (key, neutral._topic("uint64", index)),
            ("uint16", t.OUTPUT, "bytes32"), (1, row, neutral.leaf_hash(chain, core, row[0])))
    add("staticContent", "contentCompleted", "content_completed", (key,),
        ("uint16", "bytes32", "bytes32", "uint64"), (1, p[6], p[7], p[3]))
    m = contentgroup["manifest"]; record = _v(t.OUTPUT_MANIFEST, m["record"])
    add("outputManifest", "manifestStarted", "manifest_started", (m["planHash"],), ("uint16", t.OUTPUT_MANIFEST), (1, record))
    add("outputManifest", "manifestVerified", "manifest_verified", (m["recordHash"], m["planHash"]), ("uint16", t.OUTPUT_MANIFEST), (1, record))
    add("artifacts", "artifactRecorded", "artifact_recorded", (m["artifactHash"],), ("uint16", t.ARTIFACT), (1, _v(t.ARTIFACT, m["artifact"])))
    coverage = _v(t.COVERAGE, m["coverage"])
    add("artifacts", "coverageCompleted", "coverage_completed", (coverage[0], None), ("uint16", t.COVERAGE), (1, coverage))
    return tuple(result)
