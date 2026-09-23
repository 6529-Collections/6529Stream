"""Original artist-bound scoped STATIC finality commitments, separate from frozen V6."""
from . import native_finality_wire as base
from . import governance_transaction_wire as governance
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = "896899f7ca4130f86e066587f780a3b1f755a25d"
MAX_OUTPUTS, MAX_MANIFEST, MAX_CALLDATA = 1818, 8192, 32768
SCOPE, COMPONENT, STATEMENT, INPUT_ENVELOPE = base.SCOPE, base.COMPONENT, base.STATEMENT, base.INPUT_ENVELOPE
MANIFEST_REF, EXECUTION_WITNESS, ARCHIVE_WITNESS = base.MANIFEST_REF, base.EXECUTION_WITNESS, base.ARCHIVE_WITNESS
SCOPED_RECORD = ("bool", SCOPE, "bytes32", "bytes32", "bytes32", "bytes32", "string", "address", "uint64")
INPUT_SCHEMA = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1")
INPUT_CANON = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1")
FINALIZE_TYPES = (SCOPE, Array(COMPONENT, 32), "bytes32", MANIFEST_REF, base.ARCHIVE_PROOF)
FINALIZE_SIGNATURE = "finalizeArtworkScopeWithArchive((uint8,uint256,uint256,bytes32),(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes32,(string,bytes32,bytes32,bytes32,bytes32),(bytes32,bytes32,bytes32))"
GRAPH_REQUIRED = ("core", "artist", "router", "finality", "provider", "metadata", "schemas", "store", "artifacts",
    "scopeMembership", "staticSelection", "staticContent", "outputManifest", "scopedSnapshot",
    "tokenInventory", "coordinatorInventory", "coreAdapter", "executor", "roles")
PROVIDER_TARGETS = ("core", "metadata", "router", "scopeMembership", "schemas", "store", "outputManifest",
    "staticContent", "scopedSnapshot", "scopedReference", "entropyFactory", "artist", "finality", "discovery",
    "coreAdapter", "work", "rights", "conservation", "renderCriticalInventory", "bundleCoverage", "artifacts", "externalCoverage")
GRAPH_KEYS = tuple(dict.fromkeys((*GRAPH_REQUIRED, *PROVIDER_TARGETS)))
PROVIDER_CONFIG = (("address",) * 22, ("bytes32",) * 22, "uint256", "uint256", "uint256", "uint256", "bytes32")
EVENT_SIGNATURES = {**{key: base.EVENT_SIGNATURES[key] for key in ("manifestPointer", "terminalExecuted",
    "executionWitness", "archiveWitness", "governanceScheduled", "governanceExecuted", "governanceCalldataPublished")},
    "scopedFinalized": "ArtworkScopeFinalized(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,string)"}
EVENTS = {key: schema_id(value) for key, value in EVENT_SIGNATURES.items()}


def scope_value(value):
    scope = base._v(SCOPE, value)
    require(scope[1] > 0 and ((scope[0] == 1 and scope[2] > 0 and scope[3] == ZERO)
        or (scope[0] in (2, 3) and scope[2] == 0 and scope[3] != ZERO)), "scoped STATIC scope profile")
    return scope


def scope_key(scope): return keccak256(encode(SCOPE, scope_value(scope)))


def _context(context, graph):
    require(type(graph) is dict and set(GRAPH_REQUIRED).issubset(graph) and len(graph) <= 64, "scoped STATIC graph roles")
    seen = {}
    for row in graph.values():
        base._closed(row, ("address", "runtimeHash"), "scoped graph row")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)), "scoped STATIC graph empty pin")
        require(row["address"] not in seen or seen[row["address"]] == row["runtimeHash"], "scoped STATIC graph conflicting pin")
        seen[row["address"]] = row["runtimeHash"]
    chain, collection, token = (uint(context[key]) for key in ("chainId", "collectionId", "tokenId"))
    require(chain > 0 and collection > 0 and token > 0 and context["core"] == graph["core"]["address"], "scoped STATIC source identity")
    return chain, collection, token, uint(context["timestamp"], 64)


def finality_hash(chain, core, scope, core_hash, component_hash, manifest):
    return base._hash("6529STREAM_SCOPED_FINALITY_V1", ("uint256", "address", *SCOPE,
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
        (chain, core, *scope_value(scope), core_hash, component_hash, manifest[1], manifest[2], manifest[3], manifest[4]))


def validate_finality(value, context, graph, scope):
    chain, collection, token, stamp = _context(context, graph); scope = scope_value(scope)
    require(scope[1] == collection and (scope[0] != 1 or scope[2] == token), "scoped STATIC target/scope differs")
    base._closed(value, base.FINALITY_KEYS, "scoped receipt group")
    record = base._v(SCOPED_RECORD, value["record"])
    components = base._v(Array(COMPONENT, 32), value["components"])
    manifest = base._v(MANIFEST_REF, value["manifestRef"])
    witness = base._v(EXECUTION_WITNESS, value["executionWitness"])
    archive = base._v(ARCHIVE_WITNESS, value["archiveWitness"])
    raw = base._bytes(value["manifestBytes"], MAX_MANIFEST, "scoped input manifest")
    envelope = decode(INPUT_ENVELOPE, raw, maximum=MAX_MANIFEST)
    core, host, metadata = (graph[key]["address"] for key in ("core", "finality", "metadata"))
    require(envelope[:6] == (INPUT_SCHEMA, INPUT_CANON, chain, core, metadata, host), "scoped STATIC original manifest domain")
    statement = envelope[6]; independent = statement[8]
    require(statement[0] == scope and statement[1] != ZERO and statement[2] != ZERO
        and 0 < statement[3] <= MAX_OUTPUTS and (scope[0] != 1 or statement[3] == 1)
        and statement[4] == base.LEAF_SCHEMA and statement[5] != ZERO and statement[6] != ZERO
        and statement[9:] == (1, 1, 1), "scoped STATIC input manifest profile")
    inputs = statement[7]
    require(all(inputs[index] != ZERO for index in (0, 1, 2, 5, 6, 7, 8, 9))
        and ((inputs[3] == ZERO) != (inputs[4] == ZERO)), "scoped STATIC input commitments")
    require(len(independent) == 9 and tuple(row[0] for row in independent) == base.INDEPENDENT_FAMILIES,
        "scoped STATIC independent component families")
    require(len(components) == 10 and tuple(row[0] for row in components) == tuple(sorted((*base.INDEPENDENT_FAMILIES, base.SANCTION)))
        and tuple(row for row in components if row[0] != base.SANCTION) == independent, "scoped STATIC complete artist component set")
    for row in components:
        require(row[1] != ZERO_ADDRESS and row[2] != "0x00000000" and all(row[index] != ZERO for index in (0, 3, 4, 5, 6)),
            "scoped STATIC empty component commitment")
    sanction = next(row for row in components if row[0] == base.SANCTION)
    require(sanction[1] == graph["artist"]["address"] and sanction[3] == graph["artist"]["runtimeHash"]
        and sanction[6] == archive[1][0] and all(item != ZERO for item in archive[1]), "scoped STATIC original sanction/archive join")
    require(archive[0] == base.archive_evidence_hash(chain, core, host, graph["artifacts"]["address"], archive[1]),
        "scoped STATIC archive evidence hash")
    require(manifest[1] == keccak256(manifest[0].encode("utf-8")) and manifest[2] == keccak256(raw)
        and manifest[3:] == (INPUT_SCHEMA, INPUT_CANON), "scoped STATIC manifest reference differs")
    digest = base.components_hash(components)
    expected = finality_hash(chain, core, scope, statement[1], digest, manifest)
    require(record == (True, scope, expected, manifest[2], manifest[1], digest, manifest[0], host, record[8])
        and 0 < record[8] <= stamp, "scoped STATIC stored original receipt differs")
    require(witness[0] != ZERO and witness[1] != ZERO_ADDRESS and witness[2] != ZERO
        and witness[3] != ZERO and witness[4] > 0, "scoped STATIC original execution witness")
    execution = base.execution_context(chain, host, core, metadata, statement, expected, digest, archive[0])
    require(value["inputsHash"] == execution["inputsHash"], "scoped STATIC original scope-input hash")
    return {"statement": statement, "record": record, "components": components, "manifestRef": manifest,
        "executionWitness": witness, "archiveWitness": archive, "executionContext": execution,
        "historicalCoreFacts": {"status": "hash_only", "hash": statement[1], "preimage": None}}


def validate_execution(value, context, graph, finality):
    base._closed(value, base.EXECUTION_KEYS, "scoped execution group")
    action = base._v(base.GOVERNANCE_ACTION, value["action"])
    witness, stamp = finality["executionWitness"], finality["record"][8]
    require(action[0] == 3 and action[1] == 2 and action[2] != ZERO_ADDRESS and action[4] != "0x00000000"
        and all(action[index] != ZERO for index in (5, 6, 7, 8)) and action[9] <= stamp <= action[10]
        and action[11] == witness[1] and action[12] != ZERO_ADDRESS and action[15] == witness[2],
        "scoped STATIC executed action/witness differs")
    require(type(value["callDatas"]) in (tuple, list) and 0 < len(value["callDatas"]) <= 64, "scoped STATIC scheduled call count")
    calls = tuple(base._bytes(row, MAX_CALLDATA, "scoped scheduled call") for row in value["callDatas"])
    expected = hex_bytes(calldata(FINALIZE_SIGNATURE, FINALIZE_TYPES, (finality["statement"][0], finality["components"],
        finality["record"][2], finality["manifestRef"], finality["archiveWitness"][1])))
    require(len(expected) <= MAX_CALLDATA and calls.count(expected) == 1, "scoped STATIC exact finalize bytes missing/duplicate")
    runtime = base._bytes(value["runtime"], 24576, "scoped scheduled carrier")
    require(any(hex_bytes(value["callDataPointer"], 20)) and runtime == b"\0" + encode((Array("bytes", 64),), (calls,)),
        "scoped STATIC original scheduled bytes carrier differs")
    return {"matchedCallIndex": str(calls.index(expected)), "callDataHash": keccak256(expected),
        "callDataKey": keccak256(b"".join(hex_bytes(keccak256(row)) for row in calls)), "carrierCodeHash": keccak256(runtime)}


def expected_finality_events(bundle, context, graph):
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    scope, r, w, a = f["statement"][0], f["record"], f["executionWitness"], f["archiveWitness"]
    rows = []
    def add(name, topics, kinds, values):
        rows.append({"kind": name, "address": graph["finality"]["address"], "topics": (EVENTS[name], *topics),
            "data": "0x" + encode(kinds, values).hex()})
    add("scopedFinalized", (base._topic("uint8", scope[0]), base._topic("uint256", scope[1]), r[2]),
        ("uint16", "uint256", "bytes32", "bytes32", "bytes32", "string"), (1, scope[2], scope[3], r[5], r[3], r[6]))
    add("manifestPointer", (r[2],), ("uint16", "address", "bytes32"), (1, graph["finality"]["address"], r[3]))
    add("terminalExecuted", (scope_key(scope), r[2]), ("uint16", "address"), (1, graph["executor"]["address"]))
    add("executionWitness", (r[2], w[0], base._topic("address", w[1])),
        ("uint16", "bytes32", "bytes32", "uint64", "bytes32"), (1, w[2], w[3], w[4], bundle["finality"]["inputsHash"]))
    add("archiveWitness", (r[2], a[0], a[1][0]), ("uint16", "bytes32", "bytes32"), (1, a[1][1], a[1][2]))
    return tuple(rows)


def validate_governance(bundle, context, graph, transactions, events, finality=None, execution=None):
    finality = finality or validate_finality(bundle["finality"], context, graph, bundle["scope"])
    execution = execution or validate_execution(bundle["execution"], context, graph, finality)
    def original(name):
        matches = [row["log"] for row in events if row["log"]["address"] == graph["executor"]["address"]
            and row["log"]["topics"][0] == EVENTS[name]]
        require(len(matches) == 1, "scoped STATIC exact original governance event")
        return matches[0]
    report = governance.verify_action(transactions, chain_id=context["chainId"], executor=graph["executor"]["address"],
        action=bundle["execution"]["action"], expected_action_id=finality["executionWitness"][0],
        scheduled_event=original("governanceScheduled"), executed_event=original("governanceExecuted"),
        call_datas=bundle["execution"]["callDatas"])
    report["finalityCall"] = None
    if report["calls"] is not None:
        index = int(execution["matchedCallIndex"]); call = report["calls"][index]
        require(call["target"] == graph["finality"]["address"] and call["value"] == "0"
            and call["selector"] == bundle["execution"]["callDatas"][index][:10]
            and all(call[key] == finality["executionContext"][key] for key in ("scopeHash", "oldValueHash", "newValueHash")),
            "scoped STATIC original finality call context differs")
        report["finalityCall"] = {"index": str(index), **call}
    return report


def validate_bundle(bundle, context, graph):
    base._closed(bundle, ("scope", "finality", "content", "snapshot", "selection", "membership", "execution"), "scoped STATIC bundle")
    finality = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    from . import scoped_static_content_wire as content_wire
    from . import scoped_static_snapshot_wire as snapshot_wire
    from . import scoped_static_types as t
    content = content_wire.validate(bundle["content"], context, graph, finality["statement"])
    snapshot = snapshot_wire.validate(bundle, context, graph, finality["statement"], content)
    root = base._v(t.ROOT_RECORD, content["selectedRoot"])
    receipt = snapshot["selectedReceipt"]
    require(root[0][2] == receipt[0] and str(root[0][3]) == receipt[3]
        and root[3] == receipt[5] and root[4] == receipt[7], "scoped STATIC original root/snapshot join")
    artist = snapshot["source"][2]
    require((root[8], str(root[9]), root[10]) == tuple(artist[3:6]),
        "scoped STATIC original root/snapshot Artist binding differs")
    execution = validate_execution(bundle["execution"], context, graph, finality)
    return {"statement": json_values(finality["statement"]), "executionContext": finality["executionContext"],
        "historicalCoreFacts": finality["historicalCoreFacts"], "content": content, "snapshot": snapshot,
        "execution": execution, "historicalExecutionReenacted": False, "actualChainAcceptance": False}


def expected_events(bundle, context, graph):
    from . import scoped_static_content_wire as content
    from . import scoped_static_snapshot_wire as snapshot
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    return (*content.expected_events(bundle["content"], context, graph, f["statement"]),
        *snapshot.expected_events(bundle, context, graph, f["statement"]),
        *expected_finality_events(bundle, context, graph))


def validate_event_join(bundle, context, graph, events):
    """Exact original event subset and chronology; provider completeness stays external."""
    from .chain_history import LOG_FIELDS
    from .chain_rpc import quantity
    from . import scoped_static_content_wire as content
    from . import scoped_static_types as t
    require(type(events) is list and 0 < len(events) <= 8192, "scoped event bound")
    expected = list(expected_events(bundle, context, graph))
    source_number, source_time = uint(context["blockNumber"], 64), uint(context["timestamp"], 64)
    numbers, hashes, times = {source_number: context["blockHash"]}, {context["blockHash"]: source_number}, {source_number: source_time}
    transactions, slots, logs, by_kind, previous = {}, {}, {}, {}, None
    extras = {EVENTS[k]: k for k in ("governanceScheduled", "governanceExecuted", "governanceCalldataPublished")}
    extras[content.EVENTS["manifestAdvanced"]] = "manifest_advanced"
    for row in events:
        base._closed(row, ("log", "timestamp"), "scoped event observation")
        log = row["log"]; base._closed(log, LOG_FIELDS, "scoped event log")
        for key, size in (("address", 20), ("blockHash", 32), ("transactionHash", 32)):
            require(any(hex_bytes(log[key], size)), "scoped event zero identity")
        require(type(log["topics"]) is list and 1 <= len(log["topics"]) <= 4, "scoped event topics")
        for topic in log["topics"]: hex_bytes(topic, 32)
        base._bytes(log["data"], 65536, "scoped event data")
        n, i, j = (quantity(log[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
        require(n < 2**64 and i < 2**256 and j < 2**256, "scoped event position bound")
        position = n, i, j; stamp = uint(row["timestamp"], 64); h, tx = log["blockHash"], log["transactionHash"]
        require(previous is None or previous < position, "scoped event order")
        previous = position
        require(n <= source_number and stamp <= source_time, "scoped event beyond source")
        require(numbers.setdefault(n, h) == h and hashes.setdefault(h, n) == n and times.setdefault(n, stamp) == stamp,
            "scoped event block/time mapping")
        require(transactions.setdefault(tx, (h, i)) == (h, i) and slots.setdefault((h, i), tx) == tx,
            "scoped event transaction mapping")
        require((h, j) not in logs, "scoped duplicate event position"); logs[h, j] = i
        matches = [index for index, descriptor in enumerate(expected) if base.event_matches(descriptor, log)]
        if matches:
            require(len(matches) == 1, "scoped ambiguous event payload")
            kind = expected.pop(matches[0])["kind"]
        else:
            kind = extras.get(log["topics"][0])
            require(kind is not None and (kind == "manifest_advanced" or kind not in by_kind), "scoped unexpected/duplicate event")
        by_kind.setdefault(kind, []).append(row)
    require(not expected and all(k in by_kind for k in extras.values()), "scoped missing original event")
    require([times[n] for n in sorted(times)] == sorted(times.values()), "scoped event timestamp regresses")
    for h in hashes:
        indices = [index for (block, _), index in sorted(logs.items()) if block == h]
        require(indices == sorted(indices), "scoped event transaction/log order")

    def one(kind):
        require(len(by_kind[kind]) == 1, "scoped event kind cardinality")
        return by_kind[kind][0]
    def pos(row): return tuple(quantity(row["log"][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
    def before(a, b): require(pos(a) < pos(b), "scoped original event chronology")
    def same_tx(a, b):
        require(all(a["log"][k] == b["log"][k] for k in ("blockHash", "transactionHash", "transactionIndex")),
            "scoped original event transaction")
    def adjacent(a, b):
        same_tx(a, b)
        require(quantity(a["log"]["logIndex"]) + 1 == quantity(b["log"]["logIndex"]), "scoped event adjacency")
    def rows_between(name, start, end):
        rows = by_kind[name]
        require([int.from_bytes(hex_bytes(r["log"]["topics"][2], 32), "big") for r in rows] == list(range(len(rows))),
            "scoped ordered checkpoint event indices")
        before(start, rows[0]); adjacent(rows[-1], end)

    scheduled, executed, publication = (one(k) for k in ("governanceScheduled", "governanceExecuted", "governanceCalldataPublished"))
    base.validate_governance_events(bundle, context, graph, scheduled["log"], executed["log"])
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    execution = validate_execution(bundle["execution"], context, graph, f)
    version, pointer, publisher = decode(base.GOVERNANCE_CALLDATA_DATA,
        base._bytes(publication["log"]["data"], 96, "scoped calldata publication"), maximum=96)
    require(version == 1 and pointer == bundle["execution"]["callDataPointer"] and publisher != ZERO_ADDRESS
        and base.event_matches((graph["executor"]["address"], (EVENTS["governanceCalldataPublished"], execution["callDataKey"]),
            publication["log"]["data"]), publication["log"]), "scoped calldata publication differs")
    before(publication, scheduled)
    ss, sc, cs, cc = (one(k) for k in ("selection_started", "selection_completed", "content_started", "content_completed"))
    rows_between("selection_appended", ss, sc); rows_between("content_appended", cs, cc); before(sc, cs)
    if f["statement"][0][0] != 1:
        mr, ma, ms = (one(k) for k in ("membership_recorded", "membership_admitted", "membership_sealed"))
        progress = by_kind["membership_progressed"]
        before(mr, ma); before(ma, progress[0]); adjacent(progress[-1], ms); before(ms, ss)
        require([decode(("uint256", "uint256"), hex_bytes(r["log"]["data"])) for r in progress]
            == [base._v(("uint256", "uint256"), r) for r in bundle["membership"]["progressHistory"]], "scoped membership progress order")
        require(uint(mr["timestamp"], 64) == base._v(t.MEMBERSHIP_PUBLICATION, bundle["membership"]["publication"])[7][3],
            "scoped original membership publication time")
    artifact, coverage, start, verified = (one(k) for k in ("artifact_recorded", "coverage_completed", "manifest_started", "manifest_verified"))
    before(artifact, coverage); before(coverage, start); before(cc, start)
    cursor = 0; advances = by_kind["manifest_advanced"]
    for row in advances:
        v, first, end = decode(("uint16", "uint64", "uint64"), hex_bytes(row["log"]["data"]), maximum=96)
        require(v == 1 and first == cursor and 0 < end-first <= 16 and end <= f["statement"][3]
            and base.event_matches((graph["outputManifest"]["address"],
                (content.EVENTS["manifestAdvanced"], bundle["content"]["manifest"]["planHash"]), row["log"]["data"]), row["log"]),
            "scoped output manifest progress")
        before(start, row); before(row, verified); cursor = end
    require(cursor == f["statement"][3], "scoped output manifest progress denominator")
    adjacent(advances[-1], verified)
    snapshots = by_kind["snapshot_published"]
    require([r["log"]["topics"][3] for r in snapshots] == [r["receipt"][0] for r in bundle["snapshot"]["history"]], "scoped snapshot history event order")
    for event, row in zip(snapshots, bundle["snapshot"]["history"]):
        require(event["timestamp"] == row["receipt"][13], "scoped snapshot publication time")
    selected_snapshot = next(r for r in snapshots if r["log"]["topics"][3] == f["statement"][7][1])
    before(verified, selected_snapshot)
    lock = one("snapshot_locked"); before(selected_snapshot, lock)
    require(lock["timestamp"] == bundle["snapshot"]["lock"][3], "scoped snapshot lock time")
    roots = by_kind["root_published"]
    require([r["log"]["topics"][3] for r in roots] == [r["recordHash"] for r in bundle["content"]["roots"]["history"]],
        "scoped all-collection root event order")
    for event, row in zip(roots, bundle["content"]["roots"]["history"]):
        require(event["timestamp"] == row["record"][17], "scoped root publication time")
    terminal = [one(k) for k in ("scopedFinalized", "manifestPointer", "terminalExecuted", "executionWitness", "archiveWitness")]
    finalized = terminal[0]
    prior = [event for event, row in zip(roots, bundle["content"]["roots"]["history"])
        if base._v(t.SCOPE, row["record"][0][0]) == f["statement"][0] and pos(event) < pos(finalized)]
    require(prior and prior[-1]["log"]["topics"][3] == f["statement"][7][0], "scoped selected root not latest before finality")
    original_route = content.route_hash(uint(context["chainId"]), graph)
    for event, row in zip(roots, bundle["content"]["roots"]["history"]):
        if base._v(t.SCOPE, row["record"][0][0]) == f["statement"][0] and row["record"][14] == original_route:
            before(event, finalized)
    before(selected_snapshot, prior[-1]); before(lock, finalized); before(scheduled, finalized)
    for index, row in enumerate(terminal):
        require(uint(row["timestamp"], 64) == f["record"][8], "scoped finality publication time")
        same_tx(finalized, row)
        require(quantity(row["log"]["logIndex"]) == quantity(finalized["log"]["logIndex"]) + index, "scoped terminal event adjacency")
    same_tx(finalized, executed); before(terminal[-1], executed)
    return {"requiredEvents": str(len(events)), "originalChronologyChecked": True,
        "latestScopeRootAtFinalizationChecked": True, "sourceAuthenticated": False}


_INPUT_DEFINITIONS = ('{"name":"6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1","version":1,"format":"Solidity ABI","profile":"native STATIC ONCHAIN artist-bound TOKEN/RELEASE/SEASON","statement":"StreamScopedFinalityInputManifestTypes.Statement","fields":["StreamFinalityScope scope","bytes32 coreFactsHash","bytes32 contentRoot","uint64 leafCount","bytes32 contentRootSchemaId","bytes32 snapshotManifestHash","bytes32 referenceRenderManifestHash","StreamFinalityScopeInputs inputs","StreamFinalityComponentExpectation[] nonSanctionComponents","uint8 entropyPolicy","uint8 postFreezePolicy","uint8 sanctionPolicy"],"inputOrder":["rootRecordHash","snapshotRecordHash","referenceRenderRecordHash","intentRecordHash","intentWaiverRecordHash","interviewEvidenceHash","rightsStatementRecordHash","workDescriptionRecordHash","renderCriticalEvidenceHash","bundleCoverageHash"],"components":"Exactly the nine required independent families in ascending family order; all seven original expectation fields retained","policies":{"entropyPolicy":1,"postFreezePolicy":1,"sanctionPolicy":1},"policyMeaning":"All members have terminal entropy; no artwork-byte mutation exceptions; actual artist sanction and its archival proof are separate execution requirements","originalEvidence":"Distinct scoped Router root, scoped snapshot and scoped reference records resolve complete source/membership/selection/output commitments; samples never substitute for membership; original renderer/context/native policies/runtime environment and archive receipt identities retained","excluded":"Own content hash, finality record, sanction record and signature; no mutable fixity head is substituted into original evidence","authority":"Only the fixed provider rederives and validates current facts; encoding or byte publication grants no authority or readiness"}', '{"name":"6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,bytes32 canonicalizationId,uint256 chainId,address core,address metadataHost,address finalityRegistry,StreamScopedFinalityInputManifestTypes.Statement statement)","schemaId":"keccak256(6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1)","canonicalizationId":"keccak256(6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1)","scope":"TOKEN=1: nonzero collectionId/tokenId and zero scopeId; RELEASE=2 or SEASON=3: nonzero collectionId/scopeId and zero tokenId; no COLLECTION or VIEW","scopeTuple":["uint8 scopeType","uint256 collectionId","uint256 tokenId","bytes32 scopeId"],"inputTuple":["bytes32 rootRecordHash","bytes32 snapshotRecordHash","bytes32 referenceRenderRecordHash","bytes32 intentRecordHash","bytes32 intentWaiverRecordHash","bytes32 interviewEvidenceHash","bytes32 rightsStatementRecordHash","bytes32 workDescriptionRecordHash","bytes32 renderCriticalEvidenceHash","bytes32 bundleCoverageHash"],"componentTuple":["bytes32 componentType","address component","bytes4 interfaceId","bytes32 codeHash","bytes32 moduleVersion","bytes32 manifestHash","bytes32 dataHash"],"expandedEnvelope":"(bytes32,bytes32,uint256,address,address,address,((uint8,uint256,uint256,bytes32),bytes32,bytes32,uint64,bytes32,bytes32,bytes32,(bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32,bytes32),(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],uint8,uint8,uint8))","componentCount":9,"componentWords":7,"words":"Solidity 0.8.19 canonical ABI; uint64/uint8 and addresses zero extended, bytes4 right padded","arrays":"Exact fixed family order, no duplicate or omitted family","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","maximumBytes":8192,"hash":"Keccak-256 of all exact bytes","scopeInputCommitment":"Existing 6529STREAM_FINALITY_SCOPE_INPUTS_V1 domain with chainId, actual Core, actual generic metadataHost, scope and ten inputs; never provider address","retention":"The actual schema Store and original Registry staging must both retain identical complete bytes under this content hash"}')

def definitions():
    from . import scoped_static_content_wire as content
    from . import scoped_static_snapshot_wire as snapshot
    own = tuple({"name": name, "id": schema_id(name), "kind": index, "hash": keccak256(raw.encode("utf-8")), "bytes": raw.encode("utf-8")}
        for index, (name, raw) in enumerate(zip(("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1", "6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1"), _INPUT_DEFINITIONS)))
    return own + content.definitions() + snapshot.definitions()
