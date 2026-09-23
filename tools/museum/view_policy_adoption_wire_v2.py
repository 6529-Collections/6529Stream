"""Exact retained Router VIEW adoption history at native source e0b4d17b.

The collection aggregate is shared by original V1 and policy V2 records. A
checkpoint chooses one historical V2 record; it need not be today's scope
head. This validates original bytes and hashes, without running a renderer or
asserting current eligibility or VIEW finality.
"""
from . import native_finality_wire as base
from . import view_policy_adoption_types_v2 as t
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, generic_hash, json_values, require

SOURCE_REVISION = t.SOURCE_REVISION
RAW_BYTES = schema_id("RAW_BYTES")
DISPLAY_VIEW_MANIFEST = schema_id("DISPLAY_VIEW_MANIFEST")
RECORD_DOMAIN_V1 = schema_id("6529STREAM_VIEW_ADOPTION_RECORD_V1")
SOURCE_DOMAIN_V1 = schema_id("6529STREAM_VIEW_ADOPTION_SOURCE_V1")
PREPARED_DOMAIN_V1 = schema_id("6529STREAM_VIEW_PREPARED_STATE_V1")
AGGREGATE_DOMAIN_V1 = schema_id("6529STREAM_VIEW_AGGREGATE_V1")
RECORD_DOMAIN_V2 = schema_id("6529STREAM_POLICY_VIEW_ADOPTION_RECORD_V2")
SOURCE_DOMAIN_V2 = schema_id("6529STREAM_POLICY_VIEW_ADOPTION_SOURCE_V2")
PREPARED_DOMAIN_V2 = schema_id("6529STREAM_POLICY_VIEW_PREPARED_STATE_V2")
AGGREGATE_DOMAIN_V2 = schema_id("6529STREAM_POLICY_VIEW_AGGREGATE_V2")
VERSION_DOMAIN = schema_id("6529STREAM_RENDERER_VERSION_V1")
SERVING_DOMAIN = schema_id("6529STREAM_VIEW_CHECKPOINT_SERVING_V2")
SERVING_BINDING = ("address", "bytes32", "address", "bytes32", "uint256", "uint32")
RECORD_EVENT_ABI = ("((uint8,uint256,uint256,bytes32),bytes32,bytes32,bytes32,address,bytes32,bytes32),"
    "((address,bytes32,address,bytes32,address,bytes32,address,bytes32,address,bytes32,address,bytes32,"
    "address,bytes32,address,bytes32,(address,bytes32,address,bytes32,uint32,uint32)),"
    "(bytes32,bytes32,bytes32,uint256,bytes32,bytes32,uint256,bytes32),"
    "(address,bytes32,bytes32,address,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),"
    "bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,uint32,address[5],bytes32[5]),"
    "bytes32,bytes32,uint64,address,uint8,uint256,uint64,bytes32,uint64,(uint64,bytes32))")

V1_PAYLOAD_SCHEMA_BYTES = b'{"name":"STREAM_STATIC_VIEW_PAYLOAD_V1","encoding":"Solidity abi.encode","canonicalization":"RAW_BYTES","type":"(bytes32,string,string,string,bytes)","fields":["contextVersion","name","description","imageURI","script"],"contextVersion":"keccak256(STREAM_ADOPTED_VIEW_CONTEXT_V1)","limits":{"payloadBytes":40960,"nameBytes":128,"descriptionBytes":8192,"imageURIBytes":2048,"scriptBytes":24576},"source":"Complete UTF8 script; no external animation URI or library; safe optional image URI","authority":"Document publication is not Artist adoption; original Router op17 and admitted view renderer required"}'
V2_PAYLOAD_SCHEMA_BYTES = b'{"name":"STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2","encoding":"Solidity abi.encode","canonicalization":"RAW_BYTES","type":"(bytes32,string,string,string,bytes)","fields":["contextVersion","name","description","imageURI","script"],"contextVersion":"keccak256(STREAM_ADOPTED_POLICY_VIEW_CONTEXT_V2)","limits":{"payloadBytes":40960,"nameBytes":128,"descriptionBytes":8192,"imageURIBytes":2048,"scriptBytes":24576},"source":"Complete UTF8 script with explicit full-policy/terminal/finalized context; no invented finalized seed; no external animation URI or library; safe optional image URI","authority":"Document publication is not Artist adoption; original Router op17 and admitted view renderer required"}'
MANIFEST_SCHEMA_BYTES = b'{"name":"STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1","encoding":"Solidity abi.encode","canonicalization":"RAW_BYTES","types":["uint256","uint64","bytes32","(bytes32,bytes32,string,bytes32,string,bool)"],"fields":["collectionId","revision","previousRecordHash","manifest"],"manifestFields":["viewId","schemaId","uri","contentHash","mimeType","defaultForView"],"contentHash":"keccak256 over exact retained referenced-view bytes","authority":"DISPLAY class 7 or 8; no Artist consent or renderer adoption"}'
RAW_DEFINITION_BYTES = b'{"name":"RAW_BYTES","rule":"Do not transform the supplied bytes.","version":1}'
V1_OUTPUT_SCHEMA_BYTES = b'{"name":"STREAM_ADOPTED_VIEW_OUTPUT_V1","encoding":"UTF8 JSON","fields":["name","description","image","animation_url","view_id","view_record","adoption_record","artist_attribution"],"html":"Exact adopted UTF8 script plus STREAM_VIEW_CONTEXT_V1 original token identity/serial/seed/tokenData and full scope/view/adoption/source commitments","entropy":"Original Coordinator FINALIZED=5 only; terminal V2 requires a distinct profile","historical":"Saved adopted payload and renderer; original live Artist attribution remains live"}'
V2_OUTPUT_SCHEMA_BYTES = b'{"name":"STREAM_ADOPTED_POLICY_VIEW_OUTPUT_V2","encoding":"UTF8 JSON","fields":["name","description","image","animation_url","view_id","view_record","adoption_record","artist_attribution"],"html":"Exact adopted UTF8 script plus STREAM_POLICY_VIEW_CONTEXT_V2 original token identity/serial/seed/tokenData and complete original entropy policy/status and full scope/view/adoption/source commitments","entropy":"Original constructor-indexed Coordinator; explicit full H direct STATIC facts; statuses 1/2 retain seed=0 and finalized=false, ASYNC status5 retains actual seed; legacy status5 branch remains explicitly separate","historical":"Saved adopted payload and renderer; original live Artist attribution remains live"}'

_DEFINITIONS = (("STREAM_STATIC_VIEW_PAYLOAD_V1", 0, V1_PAYLOAD_SCHEMA_BYTES),
    ("STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2", 0, V2_PAYLOAD_SCHEMA_BYTES),
    ("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1", 0, MANIFEST_SCHEMA_BYTES),
    ("RAW_BYTES", 1, RAW_DEFINITION_BYTES),
    ("STREAM_ADOPTED_VIEW_OUTPUT_V1", 0, V1_OUTPUT_SCHEMA_BYTES),
    ("STREAM_ADOPTED_POLICY_VIEW_OUTPUT_V2", 0, V2_OUTPUT_SCHEMA_BYTES))


def definitions():
    return tuple({"name": n, "id": schema_id(n), "kind": k,
        "hash": keccak256(raw), "bytes": raw} for n, k, raw in _DEFINITIONS)


def _v(kind, value): return base.from_json(kind, value)
def _u(value): return value if type(value) is int and value >= 0 else uint(value)


def _scope(value):
    value = _v(t.SCOPE, value)
    require(value[0] == 4 and value[1] > 0 and value[2] == 0 and value[3] != ZERO,
        "VIEW adoption scope")
    return value


def scope_subject(chain_id, core, scope):
    s = _scope(scope)
    return keccak256(encode(("bytes32", "uint256", "address", "uint256", "uint8", "bytes32"),
        (schema_id("6529STREAM_SUBJECT_SCOPE_V1"), _u(chain_id), core, s[1], s[0], s[3])))


def source_hash(profile, chain_id, router, record, policy_binding=None):
    r = _v(t.RECORD, record); p, source = r[0], r[1]
    if profile == ZERO:
        require(policy_binding is None, "V1 VIEW record has policy binding")
        return keccak256(encode(("bytes32", "uint256", "address", t.SCOPE, "bytes32",
            "bytes32", t.SOURCE), (SOURCE_DOMAIN_V1, _u(chain_id), router, p[0], p[1], p[2], source)))
    require(profile == t.V2_PROFILE and policy_binding is not None, "VIEW adoption profile")
    binding = _v(t.POLICY_BINDING, policy_binding)
    return keccak256(encode(("bytes32", "bytes32", "uint256", "address", t.SCOPE,
        "bytes32", "bytes32", t.SOURCE, t.POLICY_BINDING),
        (SOURCE_DOMAIN_V2, t.V2_PROFILE, _u(chain_id), router, p[0], p[1], p[2], source, binding)))


def prepared_hash(profile, record):
    r = _v(t.RECORD, record); values = (r[0], r[2], r[5], r[6], r[7], r[8])
    if profile == ZERO:
        return keccak256(encode(("bytes32", t.INPUT, "bytes32", "address", "uint8", "uint256", "uint64"),
            (PREPARED_DOMAIN_V1, *values)))
    require(profile == t.V2_PROFILE, "VIEW adoption profile")
    return keccak256(encode(("bytes32", "bytes32", t.INPUT, "bytes32", "address", "uint8", "uint256", "uint64"),
        (PREPARED_DOMAIN_V2, t.V2_PROFILE, *values)))


def next_aggregate(profile, chain_id, router, core, collection_id, previous, revision,
                   subject, old, prepared):
    if profile == ZERO:
        kinds = ("bytes32", "uint256", "address", "address", "uint256", "bytes32",
            "uint64", "bytes32", "bytes32", "bytes32")
        values = (AGGREGATE_DOMAIN_V1, _u(chain_id), router, core, collection_id, previous,
            revision, subject, old, prepared)
    else:
        require(profile == t.V2_PROFILE, "VIEW adoption profile")
        kinds = ("bytes32", "bytes32", "uint256", "address", "address", "uint256",
            "bytes32", "uint64", "bytes32", "bytes32", "bytes32")
        values = (AGGREGATE_DOMAIN_V2, t.V2_PROFILE, _u(chain_id), router, core, collection_id,
            previous, revision, subject, old, prepared)
    return keccak256(encode(kinds, values))


def record_hash(profile, chain_id, router, core, record):
    r = list(_v(t.RECORD, record)); r[3] = ZERO; r = tuple(r)
    if profile == ZERO:
        return keccak256(encode(("bytes32", "uint256", "address", "address", t.RECORD),
            (RECORD_DOMAIN_V1, _u(chain_id), router, core, r)))
    require(profile == t.V2_PROFILE, "VIEW adoption profile")
    return keccak256(encode(("bytes32", "bytes32", "uint256", "address", "address", t.RECORD),
        (RECORD_DOMAIN_V2, t.V2_PROFILE, _u(chain_id), router, core, r)))


def serving_configuration_hash(chain_id, serving, binding, worker, worker_hash):
    return keccak256(encode(("bytes32", "uint256", "address", SERVING_BINDING, "address", "bytes32"),
        (SERVING_DOMAIN, _u(chain_id), serving, _v(SERVING_BINDING, binding), worker, worker_hash)))


def _safe_uri(value, maximum, empty=True):
    require(type(value) is str, "VIEW URI type")
    raw = value.encode("utf-8")
    if not raw:
        require(empty, "VIEW URI empty"); return
    valid = ((raw.startswith(b"https://") and len(raw) > 8 and raw[8] not in b"/?#")
        or (raw.startswith(b"ipfs://") and len(raw) > 7)
        or (raw.startswith(b"ar://") and len(raw) > 5))
    require(len(raw) <= maximum and valid and all(b > 32 and b != 127 for b in raw), "VIEW URI")


def _payload(raw, profile):
    require(0 < len(raw) <= t.MAX_PAYLOAD, "VIEW payload byte bound")
    p, = decode((t.PAYLOAD,), raw, maximum=t.MAX_PAYLOAD)
    require(p[0] == (t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT)
        and 0 < len(p[1].encode("utf-8")) <= 128 and len(p[2].encode("utf-8")) <= 8192
        and len(p[3].encode("utf-8")) <= 2048 and 0 < len(p[4]) <= 24576,
        "VIEW payload shape")
    try: p[4].decode("utf-8")
    except UnicodeError as exc: raise MuseumError("VIEW payload UTF-8") from exc
    _safe_uri(p[3], 2048, True)


def _carrier(row, expected, label):
    base._closed(row, ("pointer", "codeHash", "runtime"), "VIEW " + label)
    runtime = hex_bytes(row["runtime"])
    require(row["pointer"] != ZERO_ADDRESS and runtime == b"\0" + expected
        and row["codeHash"] == keccak256(runtime), "VIEW " + label + " differs")
    return row["pointer"]


def _renderer(row, profile, source, policy):
    base._closed(row, ("sourceTargets", "sourcePins", "encoding", "encodingRuntimeHash", "manifest"),
        "VIEW renderer observations")
    targets = _v(("address",) * 4, row["sourceTargets"])
    pins = _v(("bytes32",) * 4, row["sourcePins"])
    manifest = _v(t.RENDERER_MANIFEST, row["manifest"]); route, selected = source[0], source[2]
    rid = schema_id("6529STREAM_ADOPTED_VIEW_RENDERER_V1") if profile == ZERO else schema_id("6529STREAM_ADOPTED_POLICY_VIEW_RENDERER_V2")
    version = schema_id("6529STREAM_STATIC_ADOPTED_VIEW_RENDERER_V1") if profile == ZERO else schema_id("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_RENDERER_V2")
    output_hash = keccak256(V1_OUTPUT_SCHEMA_BYTES if profile == ZERO else V2_OUTPUT_SCHEMA_BYTES)
    require(targets[0:2] == (route[0], route[2]) and pins[0:2] == (route[1], route[3])
        and all(v != ZERO_ADDRESS for v in targets) and all(v != ZERO for v in pins),
        "VIEW renderer source bindings")
    if profile == t.V2_PROFILE:
        require(targets[2] == policy[4] and pins[2] == policy[5]
            and row["encoding"] != ZERO_ADDRESS and row["encodingRuntimeHash"] != ZERO,
            "VIEW policy renderer bindings")
    else:
        require(row["encoding"] is None and row["encodingRuntimeHash"] is None,
            "V1 VIEW has no encoding binding")
    require(manifest[0:5] == (rid, version,
        t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT, schema_id("STATIC"), output_hash)
        and manifest[7] != ZERO and manifest[8:10] == (262144, 262144) and not manifest[10],
        "VIEW renderer manifest")
    require(selected[0] != ZERO_ADDRESS and selected[1] != ZERO and selected[3] != ZERO_ADDRESS
        and selected[4] != ZERO
        and selected[5:9] == (manifest[0], manifest[1], manifest[2], manifest[4])
        and selected[2] == keccak256(encode(("bytes32", "bytes32", "bytes32"),
            (VERSION_DOMAIN, manifest[0], manifest[1]))) and selected[9] != ZERO and selected[10] != ZERO,
        "VIEW renderer selection")
    return {"sourceTargets": json_values(targets), "sourcePins": json_values(pins),
        "encoding": row["encoding"], "encodingRuntimeHash": row["encodingRuntimeHash"],
        "manifest": json_values(manifest)}


def _declaration(row, profile, chain_id, record, policy):
    base._closed(row, ("manifest", "receipt", "record", "manifestPayload", "manifestCarrier",
        "viewPayload", "payloadChunks", "renderer"), "VIEW declaration")
    adoption = _v(t.RECORD, record); p, source = adoption[0], adoption[1]; route = source[0]
    manifest = _v(t.VIEW_MANIFEST, row["manifest"]); receipt = _v(t.VIEW_RECEIPT, row["receipt"])
    original = _v(t.COLLECTION_RECORD, row["record"])
    manifest_raw, payload_raw = hex_bytes(row["manifestPayload"]), hex_bytes(row["viewPayload"])
    expected_schema = schema_id("STREAM_STATIC_VIEW_PAYLOAD_V1") if profile == ZERO else schema_id("STREAM_STATIC_POLICY_VIEW_PAYLOAD_V2")
    expected_schema_hash = keccak256(V1_PAYLOAD_SCHEMA_BYTES if profile == ZERO else V2_PAYLOAD_SCHEMA_BYTES)
    require(receipt[0] == p[0][1] and receipt[1] == p[1] == manifest[0] and receipt[2] > 0
        and receipt[4] != ZERO_ADDRESS and receipt[5] in (7, 8) and receipt[6] in (0, p[0][1])
        and receipt[7] > 0 and 0 < receipt[8] <= adoption[10] and manifest[1] == expected_schema
        and manifest[3] == keccak256(payload_raw) and manifest[4] == "application/octet-stream",
        "VIEW declaration manifest/receipt")
    _safe_uri(manifest[2], 2048, True); _payload(payload_raw, profile)
    require(source[3:6] == (expected_schema_hash, keccak256(MANIFEST_SCHEMA_BYTES),
        keccak256(RAW_DEFINITION_BYTES)) and receipt[11:14] == source[3:6],
        "VIEW declaration definitions")
    expected_manifest = encode(("uint256", "uint64", "bytes32", t.VIEW_MANIFEST),
        (receipt[0], receipt[2], receipt[3], manifest))
    require(manifest_raw == expected_manifest and source[6] == keccak256(manifest_raw)
        and source[7] == keccak256(encode((t.VIEW_RECEIPT,), (receipt,))), "VIEW declaration bytes")
    require(original[0] == DISPLAY_VIEW_MANIFEST and original[1] == scope_subject(chain_id, route[0], p[0])
        and original[2] == (1, hex_bytes(source[6]), RAW_BYTES) and original[3] == manifest[2]
        and original[4] == schema_id("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1")
        and original[5] == ZERO and original[6] == (0, b"", ZERO) and original[7] == 0
        and generic_hash(chain_id, route[16][0], route[0], receipt[0], receipt[4], original) == p[2],
        "VIEW declaration generic record")
    _carrier(row["manifestCarrier"], manifest_raw, "manifest carrier")
    chunks = row["payloadChunks"]
    require(type(chunks) is list and len(chunks) == (len(payload_raw) + 8191) // 8192,
        "VIEW payload chunk count")
    parts = []
    for index, chunk in enumerate(chunks):
        part = payload_raw[index * 8192:(index + 1) * 8192]
        pointer = _carrier(chunk, part, "payload chunk")
        require(pointer == source[10][index] and source[11][index] == keccak256(part),
            "VIEW payload chunk commitment")
        parts.append(part)
    require(b"".join(parts) == payload_raw and source[8] == keccak256(payload_raw)
        and source[9] == len(payload_raw) and all(source[10][i] == ZERO_ADDRESS and source[11][i] == ZERO
            for i in range(len(chunks), t.MAX_CHUNKS)), "VIEW payload carrier")
    renderer = _renderer(row["renderer"], profile, source, policy)
    return {"manifest": json_values(manifest), "receipt": json_values(receipt),
        "record": json_values(original), "manifestPayload": row["manifestPayload"],
        "manifestCarrier": dict(row["manifestCarrier"]), "viewPayload": row["viewPayload"],
        "payloadChunks": [dict(v) for v in chunks], "renderer": renderer}


def _source(record, profile, chain_id, router, policy_binding):
    r = _v(t.RECORD, record); p, source = r[0], r[1]; route, membership, renderer = source[0:3]
    require(route[0] != ZERO_ADDRESS and route[1] != ZERO and route[2] == router and route[3] != ZERO
        and all(route[i] != ZERO_ADDRESS and route[i + 1] != ZERO for i in range(4, 16, 2)),
        "VIEW saved route")
    rb = route[16]
    require(rb[0] != ZERO_ADDRESS and rb[1] != ZERO and rb[2] != ZERO_ADDRESS and rb[3] != ZERO
        and rb[4] >= 50000 and rb[5] >= rb[4], "VIEW source binding")
    subject = scope_subject(chain_id, route[0], p[0])
    require(membership[0] == subject and all(membership[i] != ZERO for i in (1, 2, 4, 5))
        and membership[3] > 0 and membership[6] == 0 and membership[7] == ZERO,
        "VIEW membership facts")
    require(renderer[7] == (t.V1_CONTEXT if profile == ZERO else t.V2_CONTEXT),
        "VIEW renderer context")
    policy = None
    if profile == t.V2_PROFILE:
        policy = _v(t.POLICY_BINDING, policy_binding)
        require(policy[0:2] == route[0:2] and policy[2] != ZERO_ADDRESS and policy[3] != ZERO
            and policy[4] != ZERO_ADDRESS and policy[5] != ZERO and policy[6] == _u(chain_id)
            and policy[7] == p[0] and policy[8] == membership and all(policy[i] != ZERO for i in (9, 10, 11))
            and 0 < policy[12] <= membership[3], "VIEW policy binding")
    else: require(policy_binding is None, "V1 VIEW record has policy binding")
    actual = source_hash(profile, chain_id, router, r, policy)
    require(actual == r[2] and p[6] == actual, "VIEW adoption source hash")
    return route, subject, policy


def _graph_join(record, policy, declaration, context, graph):
    from .native_view_policy_output_wire_v2 import context_graph
    context_graph(context, graph)
    r = _v(t.RECORD, record); route, selection = r[1][0], r[1][2]
    pair = lambda key: (graph[key]["address"], graph[key]["runtimeHash"])
    require(route[0:16] == (*pair("core"), *pair("router"), *pair("artist"), *pair("finality"),
        *pair("provider"), *pair("metadata"), *pair("schemas"), *pair("store"))
        and route[16][0:4] == (*pair("views"), *pair("scopeMembership")),
        "selected VIEW route graph differs")
    require(selection[0:2] == pair("rendererRegistry") and selection[3:5] == pair("renderer"),
        "selected VIEW renderer graph differs")
    observed = declaration["renderer"]
    require(observed["sourceTargets"][0:4] == [graph[k]["address"] for k in
        ("core", "router", "entropySourceSet", "attribution")]
        and observed["sourcePins"][0:4] == [graph[k]["runtimeHash"] for k in
        ("core", "router", "entropySourceSet", "attribution")]
        and observed["encoding"] == graph["rendererEncoding"]["address"]
        and observed["encodingRuntimeHash"] == graph["rendererEncoding"]["runtimeHash"],
        "selected VIEW renderer observations differ")
    require(policy[2:6] == (*pair("sourceFactory"), *pair("entropySourceSet")),
        "selected VIEW policy graph differs")
    require(uint(context["chainId"]) == policy[6] and uint(context["collectionId"]) == r[0][0][1]
        and context["core"] == route[0], "VIEW source context differs")


def validate(value, context, graph):
    try: return _validate(value, context, graph)
    except MuseumError: raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied VIEW adoption evidence") from exc


def _validate(value, context, graph):
    base._closed(value, ("version", "chainId", "router", "routerRuntimeHash", "scope",
        "selectedRecordHash", "head", "aggregate", "history", "serving"), "VIEW adoption evidence")
    require(value["version"] == "1", "VIEW adoption evidence version")
    chain, router = uint(value["chainId"]), value["router"]
    require(chain > 0 and any(hex_bytes(router, 20)) and any(hex_bytes(value["routerRuntimeHash"], 32)),
        "VIEW adoption domain")
    require(chain == uint(context["chainId"])
        and router == graph["router"]["address"]
        and value["routerRuntimeHash"] == graph["router"]["runtimeHash"],
        "VIEW adoption chain/router graph differs")
    scope = _scope(value["scope"]); selected_hash = value["selectedRecordHash"]
    hex_bytes(selected_hash, 32); hex_bytes(value["head"], 32)
    aggregate = _v(t.AGGREGATE, value["aggregate"]); rows = value["history"]
    serving = value["serving"]
    base._closed(serving, ("binding", "worker", "workerRuntimeHash", "configurationHash"),
        "VIEW serving evidence")
    serving_binding = _v(SERVING_BINDING, serving["binding"])
    require(serving_binding[:4] == (graph["core"]["address"], graph["core"]["runtimeHash"],
        graph["router"]["address"], graph["router"]["runtimeHash"])
        and serving_binding[4] == chain and 50000 <= serving_binding[5] <= 14000000
        and serving["worker"] == graph["servingWorker"]["address"]
        and serving["workerRuntimeHash"] == graph["servingWorker"]["runtimeHash"]
        and serving["configurationHash"] == serving_configuration_hash(chain,
            graph["serving"]["address"], serving_binding, serving["worker"], serving["workerRuntimeHash"]),
        "VIEW serving binding/configuration differs")
    require(type(rows) is list and 0 < len(rows) <= t.MAX_HISTORY, "VIEW adoption history bound")
    heads, revisions = {}, {}; previous_aggregate = ZERO; selected = None; normalized = []
    previous_position = None
    for row in rows:
        base._closed(row, ("profile", "record", "encoded", "carrier", "event", "declaration",
            "policyBinding"), "VIEW adoption history row")
        profile = row["profile"]
        require(profile in (ZERO, t.V2_PROFILE), "VIEW adoption history profile")
        record = _v(t.RECORD, row["record"]); p = record[0]; row_scope = _scope(p[0])
        require(row_scope[1] == scope[1], "VIEW collection history scope")
        route, subject, policy = _source(record, profile, chain, router, row["policyBinding"])
        require(route[0:4] == (graph["core"]["address"], graph["core"]["runtimeHash"],
            graph["router"]["address"], graph["router"]["runtimeHash"]),
            "VIEW adoption history graph differs")
        key = tuple(row_scope); require(p[3] == heads.get(key, ZERO), "VIEW adoption predecessor")
        revision = revisions.get(key, 0) + 1
        require(record[4] == revision and record[5] != ZERO_ADDRESS and record[6] in (7, 8)
            and record[7] in (0, row_scope[1]) and record[8] > 0 and record[9] != ZERO
            and record[10] > 0, "VIEW adoption record facts")
        aggregate_revision = len(normalized) + 1
        require(record[11][0] == aggregate_revision, "VIEW collection aggregate revision")
        expected_chain = next_aggregate(profile, chain, router, route[0], row_scope[1],
            previous_aggregate, aggregate_revision, subject, p[3], prepared_hash(profile, record))
        require(record[11][1] == expected_chain, "VIEW collection aggregate chain")
        require(record[3] == record_hash(profile, chain, router, route[0], record),
            "VIEW adoption record hash")
        encoded = hex_bytes(row["encoded"])
        require(encoded == encode((t.RECORD,), (record,)) and 0 < len(encoded) <= 8192,
            "VIEW adoption canonical record bytes")
        carrier = row["carrier"]; _carrier(carrier, encoded, "adoption record carrier")
        event = _v(t.EVENT, row["event"])
        require(event[0] == (1 if profile == ZERO else 2) and event[1] == profile
            and event[2] == row_scope[1] and event[3] == subject and event[4] == record[3]
            and event[5] == record and event[6] > 0 and event[7] != ZERO and event[8] != ZERO
            and event[11] == record[10], "VIEW adoption event differs")
        position = (event[6], event[9], event[10])
        require(previous_position is None or position > previous_position, "VIEW adoption event order")
        previous_position = position
        declaration = _declaration(row["declaration"], profile, chain, record, policy)
        heads[key], revisions[key], previous_aggregate = record[3], revision, expected_chain
        item = {"profile": profile, "record": json_values(record), "encoded": row["encoded"],
            "carrier": dict(carrier), "event": json_values(event), "declaration": declaration,
            "policyBinding": None if policy is None else json_values(policy)}
        normalized.append(item)
        if record[3] == selected_hash:
            require(selected is None, "duplicate selected VIEW adoption"); selected = item
    require(aggregate == (len(rows), previous_aggregate), "VIEW adoption aggregate differs")
    require(value["head"] == heads.get(tuple(scope), ZERO), "VIEW adoption head differs")
    require(selected is not None and selected["profile"] == t.V2_PROFILE
        and tuple(_v(t.RECORD, selected["record"])[0][0]) == tuple(scope),
        "selected policy VIEW adoption missing")
    selected_record = _v(t.RECORD, selected["record"])
    selected_binding = _v(t.POLICY_BINDING, selected["policyBinding"])
    _graph_join(selected_record, selected_binding, selected["declaration"], context, graph)
    return {"profile": t.V2_PROFILE, "scope": json_values(scope), "record": selected["record"],
        "policyBinding": json_values(selected_binding), "selectedRecordHash": selected_hash,
        "head": value["head"], "selectedIsCurrentHead": selected_hash == value["head"],
        "aggregate": json_values(aggregate), "history": normalized,
        "servingBinding": json_values(serving_binding),
        "servingConfigurationHash": serving["configurationHash"],
        "historicalCarrierVerified": True, "currentEligibilityChecked": False,
        "rendererExecuted": False, "viewFinalityAdmitted": False}


def expected_events(value, context, graph):
    validate(value, context, graph)
    rows = []
    for item in value["history"]:
        event = _v(t.EVENT, item["event"])
        if item["profile"] == ZERO:
            signature = "ViewAdopted(uint16,uint256,bytes32,bytes32," + RECORD_EVENT_ABI + ")"
            kinds, values = ("uint16", t.RECORD), (event[0], event[5])
        else:
            signature = "ViewAdopted(uint16,bytes32,uint256,bytes32,bytes32," + RECORD_EVENT_ABI + ")"
            kinds, values = ("uint16", "bytes32", t.RECORD), (event[0], event[1], event[5])
        rows.append({"kind": "view_adopted", "address": value["router"],
            "topics": (schema_id(signature), base._topic("uint256", event[2]), event[3], event[4]),
            "data": "0x" + encode(kinds, values).hex()})
    return tuple(rows)


def _abi(kind):
    if isinstance(kind, tuple):
        return "(" + ",".join(_abi(item) for item in kind) + ")"
    return kind
