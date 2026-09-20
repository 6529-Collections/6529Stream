"""Offline proof of an original adopted VIEW and its preservation admission.

This profile retains immutable Router and Registry evidence.  It never calls
current VIEW selection, preservation admission, renderer output, reference, or
finality gates.
"""
from . import native_finality_wire as base
from . import view_policy_adoption_types_v2 as adoption_types
from . import view_policy_adoption_wire_v2 as adoption
from . import view_preservation_adoption_types_v1 as t
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = t.SOURCE_REVISION
PROFILE = t.PROFILE
REGISTRATION_DOMAIN = schema_id("6529STREAM_PRESERVATION_REGISTRATION_V1")
READ_SET_DOMAIN = schema_id("6529STREAM_RENDERER_READ_SET_V1")
KEY_DOMAIN = schema_id("6529STREAM_PRESERVATION_KEY_V1")

PROFILE_BYTES = (b'{"name":"STREAM_VIEW_PRESERVATION_ADOPTION_EVIDENCE_V1","version":1,'
    b'"source":"e8a569b36927ed7f711a14a30ce5b09690694dd0","scope":"VIEW only",'
    b'"evidence":"Complete tagged Router adoption history plus immutable preservation producer '
    b'configuration, binding, Registry registration and declared reads",'
    b'"limits":"Reader bounds: 256 adoption rows,128 Registry reads,64 referenced targets",'
    b'"authority":"Stored admission is reconstructed; current eligibility, rendering, reference, '
    b'finality, governance execution and consensus are not claimed"}')
PROFILE_HASH = keccak256(PROFILE_BYTES)


def definitions():
    # These are the exact documents retained by the native adoption contracts.
    # PROFILE_BYTES describes this consumer and is packaged separately by the
    # source/capture layers; it was never registered as a native document.
    return adoption.definitions()


def _v(kind, value): return base.from_json(kind, value)


def _closed(value, keys, label):
    require(type(value) is dict and set(value) == set(keys), "VIEW preservation " + label + " fields")
    return value


def _graph(context, graph):
    require(type(graph) is dict and set(graph) == set(t.GRAPH_KEYS),
        "VIEW preservation exact graph roles")
    pins = {}
    for row in graph.values():
        _closed(row, ("address", "runtimeHash"), "graph row")
        require(row["address"] != ZERO_ADDRESS and row["runtimeHash"] != ZERO,
            "VIEW preservation graph identity")
        require(row["address"] not in pins or pins[row["address"]] == row["runtimeHash"],
            "VIEW preservation aliased runtime differs")
        pins[row["address"]] = row["runtimeHash"]
    require(graph["core"]["address"] == context["core"], "VIEW preservation Core differs")


def preservation_key(version_key, producer):
    return keccak256(encode(("bytes32", "bytes32", "address", "bytes32"),
        (KEY_DOMAIN, version_key, producer, t.OUTPUT_PROFILE)))


def configuration_hash(chain, producer, configuration, worker, worker_hash, encoding, encoding_hash):
    return keccak256(encode(("bytes32", "uint256", "address", t.CONFIGURATION,
        "address", "bytes32", "address", "bytes32"),
        (t.OUTPUT_PROFILE, chain, producer, configuration, worker, worker_hash,
            encoding, encoding_hash)))


def read_set_hash(target_set_hash, reads):
    return keccak256(encode(("bytes32", "bytes32", t.READS),
        (READ_SET_DOMAIN, target_set_hash, reads)))


def registration_hash(chain, registry, schemas, schemas_hash, target_set_hash,
                      original_registration_hash, registration, reads):
    return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32",
        "bytes32", "bytes32", t.PRESERVATION_REGISTRATION, t.READS),
        (REGISTRATION_DOMAIN, chain, registry, schemas, schemas_hash, target_set_hash,
            original_registration_hash, registration, reads)))


def _history(value, context, graph):
    chain, router = uint(value["chainId"]), value["router"]
    require(chain == uint(context["chainId"]) and router == graph["router"]["address"]
        and value["routerRuntimeHash"] == graph["router"]["runtimeHash"],
        "VIEW preservation chain/router differs")
    scope = adoption._scope(value["scope"]); aggregate = adoption._v(adoption_types.AGGREGATE,
        value["aggregate"]); rows = value["history"]
    require(type(rows) is list and 0 < len(rows) <= adoption_types.MAX_HISTORY,
        "VIEW preservation adoption history bound")
    heads, revisions, previous_aggregate, normalized = {}, {}, ZERO, []
    selected = None; previous_position = None
    for row in rows:
        base._closed(row, ("profile", "record", "encoded", "carrier", "event", "declaration",
            "policyBinding"), "VIEW preservation adoption row")
        profile = row["profile"]
        require(profile in (ZERO, adoption_types.V2_PROFILE), "VIEW preservation adoption profile")
        record = adoption._v(adoption_types.RECORD, row["record"]); p = record[0]
        row_scope = adoption._scope(p[0])
        require(row_scope[1] == scope[1], "VIEW preservation collection history scope")
        route, subject, policy = adoption._source(record, profile, chain, router,
            row["policyBinding"])
        require(route[0:4] == (graph["core"]["address"], graph["core"]["runtimeHash"],
            graph["router"]["address"], graph["router"]["runtimeHash"]),
            "VIEW preservation adoption history graph differs")
        key = tuple(row_scope); revision = revisions.get(key, 0) + 1
        require(p[3] == heads.get(key, ZERO) and record[4] == revision
            and record[5] != ZERO_ADDRESS and record[6] in (7, 8)
            and record[7] in (0, row_scope[1]) and record[8] > 0
            and record[9] != ZERO and record[10] > 0, "VIEW preservation adoption record facts")
        aggregate_revision = len(normalized) + 1
        expected_chain = adoption.next_aggregate(profile, chain, router, route[0], row_scope[1],
            previous_aggregate, aggregate_revision, subject, p[3], adoption.prepared_hash(profile, record))
        require(record[11] == (aggregate_revision, expected_chain)
            and record[3] == adoption.record_hash(profile, chain, router, route[0], record),
            "VIEW preservation adoption record/aggregate")
        encoded = hex_bytes(row["encoded"])
        require(encoded == encode((adoption_types.RECORD,), (record,)) and 0 < len(encoded) <= 8192,
            "VIEW preservation canonical adoption bytes")
        adoption._carrier(row["carrier"], encoded, "adoption record carrier")
        event = adoption._v(adoption_types.EVENT, row["event"])
        require(event[0] == (1 if profile == ZERO else 2) and event[1] == profile
            and event[2] == row_scope[1] and event[3] == subject and event[4] == record[3]
            and event[5] == record and event[6] > 0 and event[7] != ZERO and event[8] != ZERO
            and event[11] == record[10], "VIEW preservation adoption event differs")
        position = (event[6], event[9], event[10])
        require(previous_position is None or position > previous_position,
            "VIEW preservation adoption event order")
        previous_position = position
        declaration = adoption._declaration(row["declaration"], profile, chain, record, policy)
        heads[key], revisions[key], previous_aggregate = record[3], revision, expected_chain
        item = {"profile": profile, "record": json_values(record), "encoded": row["encoded"],
            "carrier": dict(row["carrier"]), "event": json_values(event),
            "declaration": declaration,
            "policyBinding": None if policy is None else json_values(policy)}
        normalized.append(item)
        if record[3] == value["selectedRecordHash"]:
            require(selected is None, "duplicate selected VIEW preservation adoption")
            selected = item
    require(aggregate == (len(rows), previous_aggregate), "VIEW preservation aggregate differs")
    require(value["head"] == heads.get(tuple(scope), ZERO), "VIEW preservation head differs")
    require(selected is not None and selected["profile"] == adoption_types.V2_PROFILE
        and tuple(adoption._v(adoption_types.RECORD, selected["record"])[0][0]) == tuple(scope),
        "selected preservation VIEW adoption missing")
    record = adoption._v(adoption_types.RECORD, selected["record"])
    policy = adoption._v(adoption_types.POLICY_BINDING, selected["policyBinding"])
    # Selected original graph joins, without the old VIEW checkpoint Serving dependency.
    route, renderer = record[1][0], record[1][2]
    pair = lambda key: (graph[key]["address"], graph[key]["runtimeHash"])
    require(route[0:16] == (*pair("core"), *pair("router"), *pair("artist"), *pair("finality"),
        *pair("provider"), *pair("metadata"), *pair("schemas"), *pair("store"))
        and route[16][0:4] == (*pair("views"), *pair("scopeMembership")),
        "selected preservation VIEW route differs")
    require(renderer[0:2] == pair("rendererRegistry") and renderer[3:5] == pair("renderer")
        and policy[2:6] == (*pair("sourceFactory"), *pair("entropySourceSet")),
        "selected preservation VIEW renderer/policy differs")
    return {"scope": json_values(scope), "record": selected["record"],
        "policyBinding": json_values(policy), "selectedRecordHash": value["selectedRecordHash"],
        "head": value["head"], "selectedIsCurrentHead": value["selectedRecordHash"] == value["head"],
        "aggregate": json_values(aggregate), "history": normalized}


def _reads(reads, targets, producer, attribution):
    require(type(reads) is list and 0 < len(reads) <= t.MAX_READS,
        "VIEW preservation Registry read bound")
    decoded = tuple(_v(t.READ, row) for row in reads)
    target_rows = tuple(_v(t.TARGET, row) for row in targets)
    require(0 < len(target_rows) <= t.MAX_TARGETS, "VIEW preservation target bound")
    require(all(row[0] != ZERO_ADDRESS and row[1] != ZERO and row[2] != ZERO
        and (index == 0 or int(target_rows[index - 1][0], 16) < int(row[0], 16))
        for index, row in enumerate(target_rows)),
        "VIEW preservation Registry target shape/order")
    previous = -1; required = 0
    # Derive selectors from the canonical Solidity signatures, not hard-coded interface IDs.
    selector = lambda signature: "0x" + hex_bytes(keccak256(signature.encode()), 32)[:4].hex()
    required_producer = {
        selector("preservationProfile()"): (32, True, 1),
        selector("configuration()"): (288, True, 2),
        selector("preservationViewJSON((uint8,uint256,uint256,bytes32),uint256)"): (96, False, 4),
        selector("preservationViewHTML((uint8,uint256,uint256,bytes32),uint256)"): (96, False, 8),
        selector("historicalPreservationViewJSON(bytes32,uint256)"): (192, False, 32),
        selector("historicalPreservationViewHTML(bytes32,uint256)"): (192, False, 64),
        selector("preservationViewBinding(bytes32)"): (192, True, 128),
    }
    attribution_selector = selector("preservationAttribution(uint256,uint256)")
    for row in decoded:
        order = (row[0] << 32) | int.from_bytes(hex_bytes(row[1], 4), "big")
        require(row[0] < len(target_rows) and order > previous and 0 < row[2] <= 16777216
            and (not row[3] or row[2] % 32 == 0), "VIEW preservation Registry read shape/order")
        previous = order; target = target_rows[row[0]]
        if target[0] == producer and row[1] in required_producer:
            minimum, exact, bit = required_producer[row[1]]
            require(row[3] == exact and (row[2] == minimum if exact else row[2] >= minimum),
                "VIEW preservation producer read differs")
            required |= bit
        if target[0] == attribution and row[1] == attribution_selector:
            require(not row[3] and row[2] == 32832,
                "VIEW preservation attribution read differs")
            required |= 16
    require(required == 255, "VIEW preservation required read set incomplete")
    return decoded, target_rows


def _ordered_reads(value, label):
    rows = tuple(_v(t.READ, row) for row in value)
    require(len(rows) <= t.MAX_READS, "VIEW preservation " + label + " bound")
    previous = -1
    for row in rows:
        order = (row[0] << 32) | int.from_bytes(hex_bytes(row[1], 4), "big")
        require(order > previous and row[1] != "0x00000000" and 0 < row[2] <= 16777216
            and (not row[3] or row[2] % 32 == 0),
            "VIEW preservation " + label + " shape/order")
        previous = order
    return rows


def _preservation(value, selected, context, graph):
    p = _closed(value, ("configuration", "configurationHash", "worker", "workerRuntimeHash",
        "encoding", "encodingRuntimeHash", "binding", "producerBinding", "admission",
        "attribution", "registry"), "producer evidence")
    chain = uint(context["chainId"]); config = _v(t.CONFIGURATION, p["configuration"])
    binding = _v(t.BINDING, p["binding"]); producer_binding = _v(t.PRODUCER_BINDING,
        p["producerBinding"]); admission = _v(t.ADMISSION, p["admission"])
    producer = graph["preservationRenderer"]["address"]
    pair = lambda key: (graph[key]["address"], graph[key]["runtimeHash"])
    require(config[:6] == (*pair("core"), *pair("router"), *pair("preservationAttribution"))
        and config[6] == chain and 50000 <= config[7] <= 14000000
        and 50000 <= config[8] <= 14000000, "VIEW preservation producer configuration")
    require((p["worker"], p["workerRuntimeHash"]) == pair("preservationWorker")
        and (p["encoding"], p["encodingRuntimeHash"]) == pair("preservationEncoding")
        and p["configurationHash"] == configuration_hash(chain, producer, config,
            p["worker"], p["workerRuntimeHash"], p["encoding"], p["encodingRuntimeHash"]),
        "VIEW preservation producer configuration hash")
    attribution = _closed(p["attribution"], ("core", "router", "profile",
        "liveAttribution", "liveAttributionRuntimeHash"),
        "attribution binding")
    require(attribution == {"core": config[0], "router": config[2],
        "profile": t.ATTRIBUTION_PROFILE,
        "liveAttribution": graph["attribution"]["address"],
        "liveAttributionRuntimeHash": graph["attribution"]["runtimeHash"]},
        "VIEW preservation attribution binding differs")
    selected_record = adoption._v(adoption_types.RECORD, selected["record"])
    live_renderer = selected_record[1][2]
    require(binding == (config[0], config[2], live_renderer[3], live_renderer[4], config[4], config[5]),
        "VIEW preservation retained binding differs")
    require(producer_binding == (producer, graph["preservationRenderer"]["runtimeHash"],
        t.OUTPUT_PROFILE, config[0], config[2], live_renderer[3], live_renderer[4], config[4], config[5]),
        "VIEW preservation producer binding differs")
    registry = _closed(p["registry"], ("deploymentChainId", "schemaRegistry",
        "schemaRegistryCodeHash", "targetSetHash", "version", "originalReads", "record",
        "reads", "targets"),
        "Registry evidence")
    require(uint(registry["deploymentChainId"]) == chain
        and (registry["schemaRegistry"], registry["schemaRegistryCodeHash"]) == pair("schemas"),
        "VIEW preservation Registry domain")
    version = _v(t.VERSION, registry["version"]); record = _v(t.PRESERVATION_RECORD,
        registry["record"]); registration = record[0]
    require(version[0] and version[2:4] == live_renderer[3:5]
        and version[4] == live_renderer[10] and version[5] == live_renderer[9]
        and all(version[i] != ZERO for i in range(4, 9)),
        "VIEW preservation original renderer version")
    require(registration[0] == live_renderer[2] and registration[1] == producer_binding
        and all(registration[i] != ZERO for i in range(2, 5)),
        "VIEW preservation stored registration")
    reads, targets = _reads(registry["reads"], registry["targets"], producer, config[4])
    original_reads = _ordered_reads(registry["originalReads"], "original read set")
    target_hash = keccak256(encode((t.TARGETS,), (targets,)))
    require(version[5] == read_set_hash(target_hash, original_reads),
        "VIEW preservation original renderer read hash")
    old = 0
    for item in reads:
        if old < len(original_reads) and item[:2] == original_reads[old][:2]:
            require(item == original_reads[old], "VIEW preservation changed original read")
            old += 1
    require(old == len(original_reads), "VIEW preservation original read omitted")
    producer_target = [row for row in targets if row[0] == producer]
    attribution_target = [row for row in targets if row[0] == config[4]]
    require(producer_target == [(producer, graph["preservationRenderer"]["runtimeHash"],
        schema_id("PRESERVATION_RENDERER"))]
        and attribution_target == [(config[4], graph["preservationAttribution"]["runtimeHash"],
            schema_id("PRESERVATION_ATTRIBUTION"))],
        "VIEW preservation Registry target binding differs")
    require(registry["targetSetHash"] == target_hash
        and record[2] == read_set_hash(registry["targetSetHash"], reads)
        and record[1] == registration_hash(chain, admission[0], registry["schemaRegistry"],
            registry["schemaRegistryCodeHash"], registry["targetSetHash"], version[4],
            registration, reads) and all(record[i] != ZERO for i in range(1, 6)),
        "VIEW preservation stored Registry hashes")
    require(admission == (graph["rendererRegistry"]["address"],
        graph["rendererRegistry"]["runtimeHash"], live_renderer[2], *record[1:5]),
        "VIEW preservation admission differs")
    return {"configuration": json_values(config), "configurationHash": p["configurationHash"],
        "worker": p["worker"], "workerRuntimeHash": p["workerRuntimeHash"],
        "encoding": p["encoding"], "encodingRuntimeHash": p["encodingRuntimeHash"],
        "binding": json_values(binding), "producerBinding": json_values(producer_binding),
        "admission": json_values(admission), "registry": {**registry,
            "version": json_values(version), "record": json_values(record),
            "originalReads": json_values(original_reads), "reads": json_values(reads),
            "targets": json_values(targets)}}


def validate(value, context, graph):
    try:
        _graph(context, graph)
        _closed(value, ("version", "chainId", "router", "routerRuntimeHash", "scope",
            "selectedRecordHash", "head", "aggregate", "history", "preservation"), "evidence")
        require(value["version"] == "1", "VIEW preservation evidence version")
        selected = _history(value, context, graph)
        preservation = _preservation(value["preservation"], selected, context, graph)
        return {"profile": PROFILE, "adoptionProfile": adoption_types.V2_PROFILE,
            **selected, "preservation": preservation,
            "preservationBinding": preservation["binding"], "admission": preservation["admission"],
            "currentEligibilityChecked": False, "rendererExecuted": False,
            "referenceEvidencePresent": False, "viewFinalityAdmitted": False,
            "governanceExecutionVerified": False}
    except MuseumError:
        raise
    except (ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied VIEW preservation adoption evidence") from exc


def expected_events(value, context, graph):
    result = validate(value, context, graph)
    rows = []
    for item in value["history"]:
        event = adoption._v(adoption_types.EVENT, item["event"])
        if item["profile"] == ZERO:
            signature = "ViewAdopted(uint16,uint256,bytes32,bytes32," + adoption.RECORD_EVENT_ABI + ")"
            kinds, values = ("uint16", adoption_types.RECORD), (event[0], event[5])
        else:
            signature = "ViewAdopted(uint16,bytes32,uint256,bytes32,bytes32," + adoption.RECORD_EVENT_ABI + ")"
            kinds, values = ("uint16", "bytes32", adoption_types.RECORD), (event[0], event[1], event[5])
        rows.append({"kind": "view_adopted", "address": value["router"],
            "topics": (schema_id(signature), base._topic("uint256", event[2]), event[3], event[4]),
            "data": "0x" + encode(kinds, values).hex()})
    p = result["preservation"]; record = _v(t.PRESERVATION_RECORD, p["registry"]["record"])
    registration, reads = record[0], _v(t.READS, p["registry"]["reads"])
    signature = ("PreservationRegistered(uint16,bytes32,address,bytes32,bytes32,"
        + _abi(t.PRESERVATION_REGISTRATION) + "," + _abi(t.READ) + "[])")
    rows.append({"kind": "preservation_registered", "address": p["admission"][0],
        "topics": (schema_id(signature), preservation_key(registration[0], registration[1][0]),
            base._topic("address", registration[1][0]), record[5]),
        "data": "0x" + encode(("uint16", "bytes32", t.PRESERVATION_REGISTRATION, t.READS),
            (1, record[1], registration, reads)).hex()})
    return tuple(rows)


def _abi(kind):
    if isinstance(kind, tuple): return "(" + ",".join(_abi(v) for v in kind) + ")"
    return kind
