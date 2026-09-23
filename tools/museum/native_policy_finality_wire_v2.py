"""Original COLLECTION policy V2 evidence, independent of frozen V1 profiles."""
from . import native_finality_wire as base
from . import governance_transaction_wire as governance
from .canonical import hex_bytes, keccak256, schema_id, uint
from .chain_abi import Array, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require

SOURCE_REVISION = "896899f7ca4130f86e066587f780a3b1f755a25d"
MAX_OUTPUTS, MAX_MANIFEST = 818, 8192
SCOPE, COMPONENT, INPUTS = base.SCOPE, base.COMPONENT, base.INPUTS
ENTROPY = ("address", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "uint256", "bytes32", "bytes32")
STATEMENT = (SCOPE, "bytes32", "bytes32", "uint64", "bytes32", "bytes32", "bytes32", INPUTS,
    Array(COMPONENT, 9), ENTROPY, "uint8", "uint8")
INPUT_ENVELOPE = ("bytes32", "bytes32", "uint256", "address", "address", "address", STATEMENT)
INPUT_SCHEMA = schema_id("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_V2")
INPUT_CANON = schema_id("6529STREAM_FINALITY_POLICY_INPUT_MANIFEST_ABI_V2")
LEAF_SCHEMA = schema_id("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2")
ENTROPY_PROFILE = schema_id("6529STREAM_ENTROPY_POLICY_SOURCE_SET_V2")
SNAPSHOT_PROFILE = "0xd8338f881f829b89f9ddebc5b9ca77b263953d6f9479a9c9d40da92a445b8433"
REFERENCE_PROFILE = "0x8ca1d41960302384b3e6c4c9bdce081051e5a2ddc30499fced919075a537865c"
PROVIDER_TARGETS = ("core", "metadata", "router", "scopeMembership", "schemas", "store", "leafManifest",
    "checkpoint", "policySnapshot", "policyReference", "entropyFactory", "artist", "finality", "discovery",
    "coreAdapter", "work", "rights", "conservation", "renderCriticalInventory", "bundleCoverage", "artifacts", "externalCoverage")
GRAPH_KEYS = (*PROVIDER_TARGETS, "provider", "executor", "roles", "tokenInventory", "coordinatorInventory",
    "staticSelection", "policyContent", "outputManifest", "entropySourceSet", "terminalReadiness")
PROVIDER_CONFIG = (("address",) * 22, ("bytes32",) * 22, "uint256", "uint256", "uint256", "uint256", "bytes32")
PROFILE = ("bytes32", "address", "bytes32", "address", "bytes32", "address", "bytes32", "bytes32")
PROFILE_HASHES = ("0x1de4ffe22d9442b4aa3447fef5057f6677f167ce901c76555d17c25aece44755",
    "0xa8863cf6dac274c227895b49ab106c43176ce1f3bc9120e81229d16027352135", SNAPSHOT_PROFILE)
PROFILE_CONTEXT = ("address", "address", "bytes32", "uint256", "uint256", "address", "bytes32", (PROFILE,) * 3)
COMPONENT_INTERFACE = schema_id("finalityState(uint256)")[:10]
DISCOVERY_CONFIG = (*(("address",) * 10), "bytes32", ("address",) * 6, "uint32", "uint32", "uint32")
STATIC_FAMILIES = tuple(schema_id(k) for k in ("METADATA_ROUTER", "RENDERER", "RENDER_CONTEXT", "MEDIA_MANIFEST",
    "SCRIPT_SOURCE", "DEPENDENCY_SOURCE"))
ADAPTER_FAMILIES = (*STATIC_FAMILIES, schema_id("COLLECTION_METADATA"))
INVENTORY_DEPENDENCIES = (("address",)*12, ("bytes32",)*12, ("address",)*5, ("bytes32",)*5,
    "address", "bytes32", "uint256", "uint256", "uint256", "uint256", "uint256", "uint256")
EVENTS = {k: base.EVENTS[k] for k in ("finalized", "manifestPointer", "terminalExecuted", "executionWitness",
    "archiveWitness", "governanceScheduled", "governanceExecuted", "governanceCalldataPublished")}


def _context(context, graph):
    base._closed(graph, GRAPH_KEYS, "COLLECTION policy V2 graph")
    seen = {}
    for row in graph.values():
        base._closed(row, ("address", "runtimeHash"), "policy graph row")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)), "policy empty graph pin")
        require(seen.setdefault(row["address"], row["runtimeHash"]) == row["runtimeHash"], "policy shared runtime differs")
    chain, cid, token = (uint(context[k]) for k in ("chainId", "collectionId", "tokenId"))
    require(chain > 0 and cid > 0 and token > 0 and context["core"] == graph["core"]["address"], "policy source identity")
    return chain, cid, token, uint(context["timestamp"], 64)


def validate_provider(value, context, graph):
    """Saved constructor pins, including the original meanings of roles six/seven."""
    chain, _, _, _ = _context(context, graph)
    base._closed(value, ("originalConfiguration", "scopedConfiguration", "policyConfiguration", "inventoryDependencies",
        "profiles", "configurationHash"), "policy provider evidence")
    original = base._v(PROVIDER_CONFIG, value["originalConfiguration"])
    scoped = base._v(PROVIDER_CONFIG, value["scopedConfiguration"])
    c = base._v(PROVIDER_CONFIG, value["policyConfiguration"])
    require(c[0] == tuple(graph[k]["address"] for k in PROVIDER_TARGETS)
        and c[1] == tuple(graph[k]["runtimeHash"] for k in PROVIDER_TARGETS) and c[2] == chain
        and c[3] >= 50000 and c[3] <= c[5] <= 2**32-1 and c[4] > c[5] + c[5]//63 + 100000
        and c[6] != ZERO, "policy original provider configuration")
    for config, exceptions in ((scoped, (8, 9, 18, 19)), (c, (8, 9, 10, 18, 19))):
        require(config[2:6] == original[2:6] and config[6] != ZERO, "policy inherited provider budgets")
        for i in range(22):
            require(config[0][i] != ZERO_ADDRESS and config[1][i] != ZERO
                and original[0][i] != ZERO_ADDRESS and original[1][i] != ZERO,
                "policy inherited provider empty pin")
            if i not in exceptions:
                require((config[0][i], config[1][i]) == (original[0][i], original[1][i]),
                    "policy inherited source role substitution")
    require(original[6] != ZERO, "policy original inventory dependency missing")
    d = base._v(INVENTORY_DEPENDENCIES, value["inventoryDependencies"])
    indices = (0, 1, 4, 5, 2, 8, 9, 15, 16, 17, 20, 21)
    require(keccak256(encode((INVENTORY_DEPENDENCIES,), (d,))) == c[6] and d[6] == chain
        and d[0] == tuple(c[0][i] for i in indices) and d[1] == tuple(c[1][i] for i in indices)
        and d[2][0] == graph["artist"]["address"] and d[3][0] == graph["artist"]["runtimeHash"],
        "policy complete inventory dependency tuple")
    profiles = base._v((PROFILE,) * 3, value["profiles"])
    for i, config in enumerate((original, scoped, c)):
        require(profiles[i] == (PROFILE_HASHES[i], config[0][9], config[1][9], config[0][8], config[1][8],
            config[0][10], config[1][10], keccak256(encode((PROVIDER_CONFIG,), (config,)))),
            "policy fixed source catalogue entry")
    profile_context = (graph["core"]["address"], graph["router"]["address"], graph["router"]["runtimeHash"], chain, c[3],
        graph["outputManifest"]["address"], graph["outputManifest"]["runtimeHash"], profiles)
    digest = base._hash("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1", ("uint256", "address", PROFILE_CONTEXT),
        (chain, graph["provider"]["address"], profile_context))
    require(value["configurationHash"] == digest, "policy full source catalogue hash")
    return {"configurationHash": digest, "policyConfigurationHash": profiles[2][7], "inventoryDependencyHash": c[6],
        "historicalAdmissionReexecuted": False}


def validate_finality(value, context, graph):
    chain, cid, _, stamp = _context(context, graph)
    base._closed(value, base.FINALITY_KEYS, "policy finality group")
    r = base._v(base.FINALITY_RECORD, value["record"])
    components = base._v(Array(COMPONENT, 32), value["components"])
    manifest = base._v(base.MANIFEST_REF, value["manifestRef"])
    witness = base._v(base.EXECUTION_WITNESS, value["executionWitness"])
    archive = base._v(base.ARCHIVE_WITNESS, value["archiveWitness"])
    raw = base._bytes(value["manifestBytes"], MAX_MANIFEST, "policy input manifest")
    envelope = decode(INPUT_ENVELOPE, raw, maximum=MAX_MANIFEST)
    core, host, metadata = (graph[k]["address"] for k in ("core", "finality", "metadata"))
    require(envelope[:6] == (INPUT_SCHEMA, INPUT_CANON, chain, core, metadata, host), "policy original manifest domain")
    s = envelope[6]; independent, entropy = s[8:10]
    require(s[0] == (0, cid, 0, ZERO) and s[1] != ZERO and s[2] != ZERO
        and 0 < s[3] <= MAX_OUTPUTS and s[4] == LEAF_SCHEMA and s[5] != ZERO and s[6] != ZERO
        and s[10:] == (1, 1), "policy original statement shape")
    require(entropy[0:3] == (graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"], ENTROPY_PROFILE)
        and all(entropy[i] != ZERO for i in (3, 4, 5)) and 0 < entropy[6] <= s[3]
        and entropy[7:] == (SNAPSHOT_PROFILE, REFERENCE_PROFILE), "policy explicit original entropy identities")
    inputs = s[7]
    require(all(inputs[i] != ZERO for i in (0, 1, 2, 5, 6, 7, 8, 9))
        and ((inputs[3] == ZERO) != (inputs[4] == ZERO)), "policy original input commitments")
    require(len(independent) == 9 and tuple(c[0] for c in independent) == base.INDEPENDENT_FAMILIES,
        "policy independent component families")
    require(len(components) == 10 and tuple(c[0] for c in components) == tuple(sorted((*base.INDEPENDENT_FAMILIES, base.SANCTION)))
        and tuple(c for c in components if c[0] != base.SANCTION) == independent, "policy complete original components")
    for c in components:
        require(c[1] != ZERO_ADDRESS and c[2] == COMPONENT_INTERFACE and all(c[i] != ZERO for i in (0, 3, 4, 5, 6)),
            "policy empty component commitment")
    for family, key in (("ARTIST_SANCTION", "artist"), ("ENTROPY_COORDINATOR", "entropySourceSet"), ("REFERENCE_RENDER", "policyReference")):
        c = next(c for c in components if c[0] == schema_id(family))
        require(c[1] == graph[key]["address"] and c[3] == graph[key]["runtimeHash"], "policy component original source differs")
    sanction = next(c for c in components if c[0] == base.SANCTION)
    require(sanction[6] == archive[1][0] and all(v != ZERO for v in archive[1])
        and archive[0] == base.archive_evidence_hash(chain, core, host, graph["artifacts"]["address"], archive[1]),
        "policy original sanction/archive join")
    require(manifest[1] == keccak256(manifest[0].encode("utf-8")) and manifest[2] == keccak256(raw)
        and manifest[3:] == (INPUT_SCHEMA, INPUT_CANON), "policy original manifest reference")
    digest = base.components_hash(components)
    expected = base.finality_hash(chain, core, cid, s[1], digest, manifest)
    require(r == (True, expected, manifest[2], manifest[1], manifest[0], digest, host, r[7]) and 0 < r[7] <= stamp,
        "policy retained COLLECTION finality receipt")
    require(witness[0] != ZERO and witness[1] != ZERO_ADDRESS and witness[2] != ZERO and witness[3] != ZERO and witness[4] > 0,
        "policy original execution witness")
    execution = base.execution_context(chain, host, core, metadata, s, expected, digest, archive[0])
    require(value["inputsHash"] == execution["inputsHash"], "policy original ten-input hash")
    return {"statement": s, "record": r, "components": components, "manifestRef": manifest, "executionWitness": witness,
        "archiveWitness": archive, "executionContext": execution,
        "historicalCoreFacts": {"status": "hash_only", "hash": s[1], "preimage": None}}


def validate_execution(value, context, graph, finality):
    # The original COLLECTION finalize endpoint and execution hashes did not change.
    return base.validate_execution(value, context, graph, finality)


def validate_routes(value, context, graph, finality):
    """Constructor source-family identity joins; no current component call."""
    base._closed(value, ("configuration", "discoveryConfiguration", "discoverySourceConfigurationHash", "adapters", "moduleIdentities"),
        "policy provider/routes")
    configured = validate_provider(value["configuration"], context, graph)
    d = base._v(DISCOVERY_CONFIG, value["discoveryConfiguration"])
    original = base._v(PROVIDER_CONFIG, value["configuration"]["originalConfiguration"])
    require(d[:5] == tuple(graph[k]["address"] for k in ("core", "metadata", "router", "provider", "scopeMembership"))
        and d[5] == original[0][10] and d[7] == original[0][9]
        and d[8:11] == (graph["artist"]["address"], graph["finality"]["address"], graph["finality"]["runtimeHash"])
        and d[12] >= 50000 and d[13] >= d[12] and d[14] >= d[12]
        and value["discoverySourceConfigurationHash"] == configured["configurationHash"], "policy original discovery configuration")
    base._closed(value["moduleIdentities"], ("router", "metadata"), "policy provider saved module identities")
    require(type(value["adapters"]) is list and len(value["adapters"]) == 7, "policy seven original adapters")
    expected = {c[0]: c for c in finality["components"]}
    for i, row in enumerate(value["adapters"]):
        base._closed(row, ("family", "address", "runtimeHash", "core", "coreCodeHash", "host", "hostCodeHash", "evidenceProvider",
            "evidenceProviderCodeHash", "metadataHost", "metadataHostCodeHash"), "policy immutable adapter binding")
        host = "router" if i < 6 else "metadata"
        family = ADAPTER_FAMILIES[i]
        module = base._v(("bytes32", "bytes32"), value["moduleIdentities"][host])
        require(all(v != ZERO for v in module) and row["family"] == family
            and row["address"] == (d[11][i] if i < 6 else d[6]) and any(hex_bytes(row["runtimeHash"], 32)),
            "policy adapter catalogue/order")
        for field, role in (("core", "core"), ("host", host), ("evidenceProvider", "provider"), ("metadataHost", "metadata")):
            require((row[field], row[field+"CodeHash"]) == (graph[role]["address"], graph[role]["runtimeHash"]),
                "policy adapter immutable source pin")
        require(expected[family][1:6] == (row["address"], COMPONENT_INTERFACE, row["runtimeHash"], *module),
            "policy finality family/adapter/module differs")
    return {**configured, "originalComponentSourceIdentitiesJoined": True,
        "collectionMetadataFactsPreimageReconstructed": False}


def validate_governance(bundle, context, graph, transactions, events, finality=None, execution=None):
    finality = finality or validate_finality(bundle["finality"], context, graph)
    execution = execution or validate_execution(bundle["execution"], context, graph, finality)
    def original(name):
        found = [row["log"] for row in events if row["log"]["address"] == graph["executor"]["address"]
            and row["log"]["topics"][0] == EVENTS[name]]
        require(len(found) == 1, "policy exact original governance event")
        return found[0]
    report = governance.verify_action(transactions, chain_id=context["chainId"], executor=graph["executor"]["address"],
        action=bundle["execution"]["action"], expected_action_id=finality["executionWitness"][0],
        scheduled_event=original("governanceScheduled"), executed_event=original("governanceExecuted"),
        call_datas=bundle["execution"]["callDatas"])
    report["finalityCall"] = None
    if report["calls"] is not None:
        i = int(execution["matchedCallIndex"]); call = report["calls"][i]
        require(call["target"] == graph["finality"]["address"] and call["value"] == "0"
            and call["selector"] == bundle["execution"]["callDatas"][i][:10]
            and all(call[k] == finality["executionContext"][k] for k in ("scopeHash", "oldValueHash", "newValueHash")),
            "policy original finality call metadata")
        report["finalityCall"] = {"index": str(i), **call}
    return report


def expected_finality_events(bundle, context, graph):
    f = validate_finality(bundle["finality"], context, graph)
    r, w, a = f["record"], f["executionWitness"], f["archiveWitness"]
    rows = []
    def add(name, topics, kinds, values):
        rows.append({"kind": name, "address": graph["finality"]["address"], "topics": (EVENTS[name], *topics),
            "data": "0x" + encode(kinds, values).hex()})
    add("finalized", (base._topic("uint256", uint(context["collectionId"])), r[1], base._topic("address", graph["executor"]["address"])),
        ("uint16", "bytes32", "bytes32", "string"), (1, r[5], r[2], r[4]))
    add("manifestPointer", (r[1],), ("uint16", "address", "bytes32"), (1, graph["finality"]["address"], r[2]))
    add("terminalExecuted", (keccak256(encode(SCOPE, f["statement"][0])), r[1]),
        ("uint16", "address"), (1, graph["executor"]["address"]))
    add("executionWitness", (r[1], w[0], base._topic("address", w[1])),
        ("uint16", "bytes32", "bytes32", "uint64", "bytes32"), (1, w[2], w[3], w[4], bundle["finality"]["inputsHash"]))
    add("archiveWitness", (r[1], a[0], a[1][0]), ("uint16", "bytes32", "bytes32"), (1, a[1][1], a[1][2]))
    return tuple(rows)


def validate_bundle(bundle, context, graph):
    from . import policy_content_wire_v2 as content_wire
    from . import policy_preservation_wire_v2 as preservation_wire
    from . import policy_static_components_v2 as static_wire
    from . import policy_membership_v2 as membership_wire
    from . import policy_preservation_types_v2 as t
    base._closed(bundle, ("provider", "finality", "content", "snapshot", "reference", "membership", "staticComponents", "execution"),
        "policy COLLECTION bundle")
    f = validate_finality(bundle["finality"], context, graph)
    provider = validate_routes(bundle["provider"], context, graph, f)
    s = f["statement"]
    content = content_wire.validate(bundle["content"], context, graph, s)
    preservation = preservation_wire.validate(bundle, context, graph, s, content)
    snapshot, reference = preservation["snapshot"], preservation["reference"]
    source = base._v(t.SNAPSHOT_SOURCE, snapshot["source"])
    entropy = source[8]
    require(s[9] == (graph["entropySourceSet"]["address"], graph["entropySourceSet"]["runtimeHash"], ENTROPY_PROFILE,
        entropy[0], entropy[1], entropy[2], entropy[3], SNAPSHOT_PROFILE, REFERENCE_PROFILE), "policy original statement/full entropy join")
    for group in (snapshot, reference):
        lock = base._v(t.SNAPSHOT_LOCK, group["lock"])
        require(lock[2] != ZERO and 0 < lock[3] <= f["record"][7], "policy finality requires original class-two locks")
    expected_components = {c[0]: c for c in f["components"]}
    for name, family in (("entropy", "ENTROPY_COORDINATOR"), ("reference", "REFERENCE_RENDER")):
        commitment = preservation["componentCommitments"][name]
        require(expected_components[schema_id(family)][4:7] == tuple(commitment[k] for k in ("moduleVersion", "manifestHash", "dataHash")),
            "policy original retained component commitment")
    membership = membership_wire.validate(bundle["membership"], context, graph, snapshot["membership"], content["tokenIds"])
    value, sc = bundle["staticComponents"], bundle["staticComponents"]["context"]
    require(sc["chainId"] == context["chainId"] and sc["core"] == graph["core"]["address"]
        and sc["metadata"] == graph["metadata"]["address"] and sc["router"] == graph["router"]["address"]
        and sc["routerCodeHash"] == graph["router"]["runtimeHash"] and sc["selection"] == graph["staticSelection"]["address"]
        and sc["selectionCodeHash"] == graph["staticSelection"]["runtimeHash"]
        and (sc["routerModuleVersion"], sc["routerModuleManifestHash"]) == tuple(bundle["provider"]["moduleIdentities"]["router"]),
        "policy STATIC original dependency context")
    require(sc["adapters"] == [{k: row[k] for k in ("family", "address", "runtimeHash")} for row in bundle["provider"]["adapters"][:6]],
        "policy STATIC adapter evidence join")
    authenticated = (source[0], SNAPSHOT_PROFILE, source[4][0], source[3][1], source[3][5], source[3][3], source[2][11])
    require(base._v(static_wire.AUTHENTICATED_SELECTION, value["authenticated"]) == authenticated
        and value["plan"] == content["selectionPlan"] and value["rows"] == content["selectionRows"]
        and value["artistPresentation"] == snapshot["source"][2]
        and base._v(Array(COMPONENT, 9), value["componentExpectations"]) == s[8], "policy STATIC/snapshot/output join")
    static = static_wire.validate(value)
    tokens = membership["tokenIds"]
    for sample in preservation["samples"]:
        # The original reference serial is immutable; a later burn is separate.
        index = int(sample[0]); observation = sample[1]
        require(str(observation[0]) == tokens[index] and str(observation[1]) == bundle["membership"]["identities"][index][2],
            "policy reference original token/serial join")
    execution = validate_execution(bundle["execution"], context, graph, f)
    return {"statement": json_values(s), "executionContext": f["executionContext"], "historicalCoreFacts": f["historicalCoreFacts"],
        "provider": provider, "content": content, "preservation": preservation, "membership": membership, "staticComponents": static,
        "execution": execution, "historicalExecutionReenacted": False, "actualChainAcceptance": False}


def expected_events(bundle, context, graph):
    from . import policy_content_wire_v2 as content
    from . import policy_content_types_v2 as t
    from . import policy_preservation_wire_v2 as preservation
    from . import policy_membership_v2 as membership
    from .scoped_static_snapshot_wire import _descriptor, selection_row_hash
    f = validate_finality(bundle["finality"], context, graph)
    cp = bundle["content"]["checkpoint"]
    plan = base._v(t.SELECTION_PLAN, cp["selectionPlan"])
    key = cp["plan"][0]; host = graph["staticSelection"]["address"]
    rows = list(membership.expected_events(bundle["membership"], context, graph))
    rows.append(_descriptor("selection_started", host, "StaticSelectionStarted", ("uint16", "bytes32", t.SELECTION_PLAN),
        (key,), ("uint16", t.SELECTION_PLAN), (1, (*plan[:4], 0, ZERO))))
    for i, original in enumerate(cp["selectionRows"]):
        row = base._v(t.SELECTION_ROW, original)
        rows.append(_descriptor("selection_appended", host, "StaticSelectionAppended", ("uint16", "bytes32", "uint64", t.SELECTION_ROW, "bytes32"),
            (key, base._topic("uint64", i)), ("uint16", t.SELECTION_ROW, "bytes32"), (1, row, selection_row_hash(row, context, graph))))
    rows.append(_descriptor("selection_completed", host, "StaticSelectionCompleted", ("uint16", "bytes32", "bytes32", "uint64"),
        (key,), ("uint16", "bytes32", "uint64"), (1, plan[5], plan[3])))
    return (*rows, *content.expected_events(bundle["content"], context, graph, f["statement"]),
        *preservation.expected_events(bundle, context, graph, f["statement"]), *expected_finality_events(bundle, context, graph))


def validate_event_join(bundle, context, graph, events):
    """Retained exact event payloads and protocol order; provider completeness is external."""
    from .chain_history import LOG_FIELDS
    from .chain_rpc import quantity
    from . import policy_content_wire_v2 as content
    require(type(events) is list and 0 < len(events) <= 8192, "policy event bound")
    expected = list(expected_events(bundle, context, graph))
    source_number, source_time = uint(context["blockNumber"], 64), uint(context["timestamp"], 64)
    numbers, hashes, times = {source_number: context["blockHash"]}, {context["blockHash"]: source_number}, {source_number: source_time}
    transactions, slots, logs, by_kind, previous = {}, {}, {}, {}, None
    extras = {EVENTS[k]: k for k in ("governanceScheduled", "governanceExecuted", "governanceCalldataPublished")}
    extras[content.EVENTS["manifestAdvanced"]] = "manifest_advanced"
    for row in events:
        base._closed(row, ("log", "timestamp"), "policy event observation")
        log = row["log"]; base._closed(log, LOG_FIELDS, "policy event log")
        for key, size in (("address", 20), ("blockHash", 32), ("transactionHash", 32)):
            require(any(hex_bytes(log[key], size)), "policy event zero identity")
        require(type(log["topics"]) is list and 1 <= len(log["topics"]) <= 4, "policy event topics")
        for topic in log["topics"]: hex_bytes(topic, 32)
        base._bytes(log["data"], 65536, "policy event data")
        n, i, j = (quantity(log[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
        require(n < 2**64 and i < 2**256 and j < 2**256, "policy event position bound")
        position = n, i, j; stamp = uint(row["timestamp"], 64); h, tx = log["blockHash"], log["transactionHash"]
        require(previous is None or previous < position, "policy event order"); previous = position
        require(n <= source_number and stamp <= source_time, "policy event beyond source")
        require(numbers.setdefault(n, h) == h and hashes.setdefault(h, n) == n and times.setdefault(n, stamp) == stamp,
            "policy event block/time mapping")
        require(transactions.setdefault(tx, (h, i)) == (h, i) and slots.setdefault((h, i), tx) == tx, "policy event transaction mapping")
        require((h, j) not in logs, "policy duplicate event position"); logs[h, j] = i
        matches = [i for i, descriptor in enumerate(expected) if base.event_matches(descriptor, log)]
        if matches:
            require(len(matches) == 1, "policy ambiguous event payload"); kind = expected.pop(matches[0])["kind"]
        else:
            kind = extras.get(log["topics"][0])
            require(kind is not None and (kind == "manifest_advanced" or kind not in by_kind), "policy unexpected/duplicate event")
        by_kind.setdefault(kind, []).append(row)
    require(not expected and all(k in by_kind for k in extras.values()), "policy missing original event")
    require([times[n] for n in sorted(times)] == sorted(times.values()), "policy event timestamp regresses")
    for h in hashes:
        require([i for (b,_),i in sorted(logs.items()) if b == h] == sorted(i for (b,_),i in logs.items() if b == h),
            "policy event transaction/log order")
    def one(kind):
        require(len(by_kind[kind]) == 1, "policy event kind cardinality"); return by_kind[kind][0]
    def pos(row): return tuple(quantity(row["log"][k]) for k in ("blockNumber", "transactionIndex", "logIndex"))
    def before(a, b): require(pos(a) < pos(b), "policy original event chronology")
    def same_tx(a, b):
        require(all(a["log"][k] == b["log"][k] for k in ("blockHash", "transactionHash", "transactionIndex")), "policy original event transaction")
    def adjacent(a, b):
        same_tx(a,b); require(quantity(a["log"]["logIndex"]) + 1 == quantity(b["log"]["logIndex"]), "policy event adjacency")
    f = validate_finality(bundle["finality"], context, graph)
    for family in ("selection", "content"):
        start, complete, rows = one(family+"_started"), one(family+"_completed"), by_kind[family+"_appended"]
        require([int.from_bytes(hex_bytes(r["log"]["topics"][2],32), "big") for r in rows] == list(range(f["statement"][3])),
            "policy ordered complete checkpoint event indices")
        before(start, rows[0]); adjacent(rows[-1], complete)
    indexed = by_kind["inventory_indexed"]
    require([str(int.from_bytes(hex_bytes(r["log"]["topics"][2],32),"big")) for r in indexed] == bundle["membership"]["tokens"],
        "policy original inventory event order")
    before(indexed[-1], one("selection_started")); before(one("selection_completed"), one("content_started"))
    artifact, coverage, started, verified = (one(k) for k in ("artifact_recorded", "coverage_completed", "manifest_started", "manifest_verified"))
    before(artifact,coverage); before(coverage,started); before(one("content_completed"),started)
    cursor = 0
    for row in by_kind["manifest_advanced"]:
        version, first, end = decode(("uint16","uint64","uint64"), hex_bytes(row["log"]["data"]), maximum=96)
        require(version == 2 and first == cursor and 0 < end-first <= 16 and end <= f["statement"][3]
            and base.event_matches((graph["outputManifest"]["address"], (content.EVENTS["manifestAdvanced"],
                bundle["content"]["manifest"]["planHash"]), row["log"]["data"]), row["log"]), "policy complete manifest progress")
        before(started,row); before(row,verified); cursor = end
    require(cursor == f["statement"][3], "policy manifest progress denominator"); adjacent(by_kind["manifest_advanced"][-1],verified)
    roots = by_kind["root_published"]
    require([r["log"]["topics"][3] for r in roots] == [r["recordHash"] for r in bundle["content"]["roots"]["history"]],
        "policy all original root history order")
    selected_root = next(r for r in roots if r["log"]["topics"][3] == f["statement"][7][0])
    for event, original in zip(roots,bundle["content"]["roots"]["history"]):
        require(event["timestamp"] == original["record"][13], "policy original root time")
        if original["binding"][0] != ZERO:
            binding = next(r for r in by_kind["root_binding_published"] if r["log"]["topics"][2] == original["recordHash"])
            adjacent(event,binding)
    selected = {}
    for family, input_index in (("snapshot",1),("reference",2)):
        rows, history = by_kind["policy_"+family+"_published"], bundle[family]["history"]
        receipts = [r["receipt"] if family == "snapshot" else r["receipt"][1] for r in history]
        require([r["log"]["topics"][3] for r in rows] == [r[0] for r in receipts], "policy preservation history event order")
        for event, receipt in zip(rows,receipts):
            require(event["timestamp"] == receipt[13 if family == "snapshot" else 15], "policy preservation publication time")
        chosen = next(r for r in rows if r["log"]["topics"][3] == f["statement"][7][input_index]); selected[family] = chosen
        locked = one("policy_"+family+"_locked"); before(chosen,locked)
        require(locked["timestamp"] == bundle[family]["lock"][3], "policy original preservation lock time")
    before(verified,selected_root); before(selected_root,selected["snapshot"]); before(selected["snapshot"],selected["reference"])
    terminal = [one(k) for k in ("finalized","manifestPointer","terminalExecuted","executionWitness","archiveWitness")]
    finalized = terminal[0]
    prior = [r for r in roots if pos(r) < pos(finalized)]
    require(prior and prior[-1] == selected_root, "policy selected root not latest before original finality")
    original_route = content.route_hash(uint(context["chainId"]), graph)
    for event, original in zip(roots,bundle["content"]["roots"]["history"]):
        if original["record"][10] == original_route: before(event,finalized)
    for family in ("snapshot","reference"): before(one("policy_"+family+"_locked"),finalized)
    scheduled, executed, publication = (one(k) for k in ("governanceScheduled","governanceExecuted","governanceCalldataPublished"))
    base.validate_governance_events(bundle,context,graph,scheduled["log"],executed["log"])
    execution = validate_execution(bundle["execution"],context,graph,f)
    version, pointer, publisher = decode(base.GOVERNANCE_CALLDATA_DATA, hex_bytes(publication["log"]["data"]), maximum=96)
    require(version == 1 and pointer == bundle["execution"]["callDataPointer"] and publisher != ZERO_ADDRESS
        and base.event_matches((graph["executor"]["address"], (EVENTS["governanceCalldataPublished"],execution["callDataKey"]),
            publication["log"]["data"]),publication["log"]), "policy original calldata publication")
    before(publication,scheduled); before(scheduled,finalized)
    for i, row in enumerate(terminal):
        require(uint(row["timestamp"],64) == f["record"][7], "policy finality publication time")
        same_tx(finalized,row)
        require(quantity(row["log"]["logIndex"]) == quantity(finalized["log"]["logIndex"])+i, "policy terminal event adjacency")
    same_tx(finalized,executed); before(terminal[-1],executed)
    return {"eventCount": str(len(events)), "originalPublicationChronologyChecked": True, "providerLogCompletenessTrusted": True}


def definitions():
    from .policy_finality_definitions_v2 import DEFINITIONS
    from . import policy_content_wire_v2 as content
    from . import policy_preservation_wire_v2 as preservation
    return (*DEFINITIONS, *content.definitions(), *preservation.definitions())
