"""Original scoped factory policy V2 finality; native scoped V1 manifest layout retained."""
from . import native_finality_wire as base
from . import governance_transaction_wire as governance
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_abi import Array, calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from . import native_policy_finality_wire_v2 as collection

SOURCE_REVISION = "e0b4d17bc548f778a379773234caee545658bcdc"
MAX_OUTPUTS, MAX_MANIFEST, MAX_CALLDATA = 818, 8192, 32768
SCOPE, COMPONENT, STATEMENT, INPUT_ENVELOPE = base.SCOPE, base.COMPONENT, base.STATEMENT, base.INPUT_ENVELOPE
MANIFEST_REF, EXECUTION_WITNESS, ARCHIVE_WITNESS = base.MANIFEST_REF, base.EXECUTION_WITNESS, base.ARCHIVE_WITNESS
SCOPED_RECORD = ("bool", SCOPE, "bytes32", "bytes32", "bytes32", "bytes32", "string", "address", "uint64")
INPUT_SCHEMA = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_V1")
INPUT_CANON = schema_id("6529STREAM_SCOPED_FINALITY_INPUT_MANIFEST_ABI_V1")
FINALIZE_TYPES = (SCOPE, Array(COMPONENT, 32), "bytes32", MANIFEST_REF, base.ARCHIVE_PROOF)
FINALIZE_SIGNATURE = "finalizeArtworkScopeWithArchive((uint8,uint256,uint256,bytes32),(bytes32,address,bytes4,bytes32,bytes32,bytes32,bytes32)[],bytes32,(string,bytes32,bytes32,bytes32,bytes32),(bytes32,bytes32,bytes32))"
PROVIDER_TARGETS = ("core", "metadata", "router", "scopeMembership", "schemas", "store", "outputManifest",
    "policyContent", "policySnapshot", "policyReference", "sourceFactory", "artist", "finality", "discovery",
    "coreAdapter", "work", "rights", "conservation", "renderCriticalInventory", "bundleCoverage", "artifacts", "externalCoverage")
GRAPH_KEYS = (*PROVIDER_TARGETS, "staticSelection", "tokenInventory", "coordinatorInventory", "provider", "executor",
    "roles", "entropySourceSet", "terminalReadiness", "publicationFactory")
GRAPH_REQUIRED = GRAPH_KEYS
LEAF_SCHEMA = schema_id("STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2")
COMPONENT_INTERFACE = "0x" + hex_bytes(schema_id("finalityStateForScope((uint8,uint256,uint256,bytes32))"))[:4].hex()
PROVIDER_CONFIG = (("address",) * 22, ("bytes32",) * 22, "uint256", "uint256", "uint256", "uint256", "bytes32")
FACTORY_BINDING = ("address", "bytes32", "bytes32", "bytes32", "uint256", "bytes32")
PROFILE, PROFILE_CONTEXT, PROFILE_HASHES = collection.PROFILE, collection.PROFILE_CONTEXT, collection.PROFILE_HASHES
DISCOVERY_CONFIG, ADAPTER_FAMILIES = collection.DISCOVERY_CONFIG, collection.ADAPTER_FAMILIES
INVENTORY_DEPENDENCIES = collection.INVENTORY_DEPENDENCIES
EVENT_SIGNATURES = {**{key: base.EVENT_SIGNATURES[key] for key in ("manifestPointer", "terminalExecuted",
    "executionWitness", "archiveWitness", "governanceScheduled", "governanceExecuted", "governanceCalldataPublished")},
    "scopedFinalized": "ArtworkScopeFinalized(uint16,uint8,uint256,bytes32,uint256,bytes32,bytes32,bytes32,string)"}
EVENTS = {key: schema_id(value) for key, value in EVENT_SIGNATURES.items()}


def scope_value(value):
    scope = base._v(SCOPE, value)
    require(scope[1] > 0 and ((scope[0] == 1 and scope[2] > 0 and scope[3] == ZERO)
        or (scope[0] in (2, 3) and scope[2] == 0 and scope[3] != ZERO)), "scoped policy V2 scope profile")
    return scope


def scope_key(scope): return keccak256(encode(SCOPE, scope_value(scope)))


def _context(context, graph):
    require(type(graph) is dict and set(graph) == set(GRAPH_KEYS), "scoped policy V2 graph roles")
    seen = {}
    for row in graph.values():
        base._closed(row, ("address", "runtimeHash"), "scoped graph row")
        require(any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)), "scoped policy V2 graph empty pin")
        require(row["address"] not in seen or seen[row["address"]] == row["runtimeHash"], "scoped policy V2 graph conflicting pin")
        seen[row["address"]] = row["runtimeHash"]
    chain, collection, token = (uint(context[key]) for key in ("chainId", "collectionId", "tokenId"))
    require(chain > 0 and collection > 0 and token > 0 and context["core"] == graph["core"]["address"], "scoped policy V2 source identity")
    return chain, collection, token, uint(context["timestamp"], 64)


def finality_hash(chain, core, scope, core_hash, component_hash, manifest):
    return base._hash("6529STREAM_SCOPED_FINALITY_V1", ("uint256", "address", *SCOPE,
        "bytes32", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32"),
        (chain, core, *scope_value(scope), core_hash, component_hash, manifest[1], manifest[2], manifest[3], manifest[4]))


def selected_configuration(original, recipe, factory_graph):
    """Reconstruct the immutable graph splice, without a current-eligibility read."""
    from . import scoped_policy_factory_v2 as factory
    original = base._v(PROVIDER_CONFIG, original)
    recipe, g = base._v(factory.RECIPE, recipe), base._v(factory.GRAPH, factory_graph)
    targets, pins = list(original[0]), list(original[1])
    for role, child in ((6, 2), (7, 1), (8, 3), (9, 4), (18, 5), (19, 6)):
        targets[role], pins[role] = g[5][child], g[6][child]
    targets[10], pins[10] = recipe[1][2], recipe[2][2]
    dependency_hash = keccak256(encode((INVENTORY_DEPENDENCIES,), (factory.inventory_dependencies(recipe, g),)))
    return (tuple(targets), tuple(pins), *original[2:6], dependency_hash)


def provider_hashes(original, scoped, policy, output, binding, chain, provider):
    """Constructor hashes; the legacy catalogue and scoped factory keep distinct domains."""
    configs = tuple(base._v(PROVIDER_CONFIG, v) for v in (original, scoped, policy))
    profiles = tuple((PROFILE_HASHES[i], c[0][9], c[1][9], c[0][8], c[1][8], c[0][10], c[1][10],
        keccak256(encode((PROVIDER_CONFIG,), (c,)))) for i, c in enumerate(configs))
    c = configs[0]; binding = base._v(FACTORY_BINDING, binding)
    context = (c[0][0], c[0][2], c[1][2], chain, c[3], output["address"], output["runtimeHash"], profiles)
    legacy = base._hash("6529STREAM_FINALITY_SOURCE_CONFIGURATION_V1", ("uint256", "address", PROFILE_CONTEXT),
        (chain, provider, context))
    configuration = base._hash("6529STREAM_SCOPED_POLICY_PROVIDER_CONFIGURATION_V2",
        ("uint256", "address", PROVIDER_CONFIG, *FACTORY_BINDING[:5]), (chain, provider, c, *binding[:5]))
    binding = (*binding[:5], configuration)
    source = base._hash("6529STREAM_FINALITY_SOURCE_CONFIGURATION_SCOPED_POLICY_V2",
        ("bytes32", FACTORY_BINDING), (legacy, binding))
    return profiles, binding, source


def validate_provider(value, context, graph, factory_value):
    from . import scoped_policy_factory_v2 as factory
    chain, _, _, _ = _context(context, graph)
    base._closed(value, ("originalConfiguration", "scopedConfiguration", "policyConfiguration", "collectionPolicyOutput",
        "profiles", "factoryBinding", "selectedConfiguration", "sourceConfigurationHash", "inventoryDependencies"),
        "scoped policy V2 provider configuration")
    original, scoped, policy = (base._v(PROVIDER_CONFIG, value[k]) for k in
        ("originalConfiguration", "scopedConfiguration", "policyConfiguration"))
    require(original[2] == chain and original[3] >= 50000 and original[3] <= original[5] <= 2**32-1
        and original[4] > original[5] + original[5]//63 + 100000 and original[6] != ZERO,
        "scoped policy V2 original budgets")
    for c, exceptions in ((original, ()), (scoped, (8, 9, 18, 19)), (policy, (8, 9, 10, 18, 19))):
        require(c[2:6] == original[2:6] and c[6] != ZERO, "scoped policy V2 inherited budgets")
        for i in range(22):
            require(c[0][i] != ZERO_ADDRESS and c[1][i] != ZERO, "scoped policy V2 inherited empty pin")
            if i not in exceptions:
                require((c[0][i], c[1][i]) == (original[0][i], original[1][i]),
                    "scoped policy V2 inherited source substitution")
    output = value["collectionPolicyOutput"]
    base._closed(output, ("address", "runtimeHash"), "COLLECTION V2 separate output binding")
    require(any(hex_bytes(output["address"], 20)) and any(hex_bytes(output["runtimeHash"], 32)),
        "scoped policy V2 missing inherited output binding")
    binding = base._v(FACTORY_BINDING, value["factoryBinding"])
    require(binding[:4] == (graph["publicationFactory"]["address"], graph["publicationFactory"]["runtimeHash"],
        factory_value["recipeHash"], factory_value["sourceFactoryDependenciesHash"])
        and original[3] <= binding[4] <= 2**32-1
        and original[5] > binding[4] + binding[4]//63 + original[3] + 200000,
        "scoped policy V2 factory binding/budget")
    configured = factory.validate(factory_value, context, graph, original_configuration=original)
    recipe = base._v(factory.RECIPE, configured["recipe"])
    require(recipe[1] == tuple(graph[k]["address"] for k in ("scopeMembership", "staticSelection", "sourceFactory", "executor"))
        and recipe[2] == tuple(graph[k]["runtimeHash"] for k in ("scopeMembership", "staticSelection", "sourceFactory", "executor")),
        "scoped policy V2 recipe fixed source roles")
    require((recipe[1][0], recipe[2][0]) == (original[0][3], original[1][3])
        and (recipe[0][2][0], recipe[0][3][0]) == (original[0][11], original[1][11]),
        "scoped policy V2 recipe membership/Artist pins")
    selected = selected_configuration(original, recipe, configured["graph"])
    require(base._v(PROVIDER_CONFIG, value["selectedConfiguration"]) == selected
        and selected[0] == tuple(graph[k]["address"] for k in PROVIDER_TARGETS)
        and selected[1] == tuple(graph[k]["runtimeHash"] for k in PROVIDER_TARGETS)
        and base._v(INVENTORY_DEPENDENCIES, value["inventoryDependencies"])
            == base._v(INVENTORY_DEPENDENCIES, configured["inventoryDependencies"]),
        "scoped policy V2 factory-derived selected configuration")
    profiles, expected_binding, digest = provider_hashes(original, scoped, policy, output, binding, chain, graph["provider"]["address"])
    require(base._v((PROFILE,)*3, value["profiles"]) == profiles and binding == expected_binding
        and value["sourceConfigurationHash"] == digest, "scoped policy V2 complete constructor catalogue hash")
    return {"configurationHash": digest, "factoryConfigurationHash": binding[5], "inventoryDependencyHash": selected[6],
        "selectedConfigurationHash": keccak256(encode((PROVIDER_CONFIG,), (selected,))),
        "historicalAdmissionReexecuted": False, "factory": configured}


def validate_routes(value, context, graph, finality, factory_value):
    base._closed(value, ("configuration", "discoveryConfiguration", "discoverySourceConfigurationHash", "adapters", "moduleIdentities"),
        "scoped policy V2 routes")
    configured = validate_provider(value["configuration"], context, graph, factory_value)
    d = base._v(DISCOVERY_CONFIG, value["discoveryConfiguration"])
    original = base._v(PROVIDER_CONFIG, value["configuration"]["originalConfiguration"])
    binding = base._v(FACTORY_BINDING, value["configuration"]["factoryBinding"])
    require(d[:5] == tuple(graph[k]["address"] for k in ("core", "metadata", "router", "provider", "scopeMembership"))
        and d[5] == original[0][10] and d[7] == original[0][9]
        and d[8:11] == (graph["artist"]["address"], graph["finality"]["address"], graph["finality"]["runtimeHash"])
        and d[12] >= 50000 and d[13] >= d[12] and d[14] >= d[12]
        and d[13] > binding[4] + binding[4]//63 + 100000
        and value["discoverySourceConfigurationHash"] == configured["configurationHash"],
        "scoped policy V2 discovery constructor binding")
    base._closed(value["moduleIdentities"], ("router", "metadata"), "scoped policy V2 module identities")
    require(type(value["adapters"]) is list and len(value["adapters"]) == 7, "scoped policy V2 seven adapters")
    expected = {c[0]: c for c in finality["components"]}
    for i, row in enumerate(value["adapters"]):
        base._closed(row, ("family", "address", "runtimeHash", "core", "coreCodeHash", "host", "hostCodeHash", "evidenceProvider",
            "evidenceProviderCodeHash", "metadataHost", "metadataHostCodeHash"), "scoped policy V2 adapter")
        host, family = ("router" if i < 6 else "metadata"), ADAPTER_FAMILIES[i]
        module = base._v(("bytes32", "bytes32"), value["moduleIdentities"][host])
        require(all(v != ZERO for v in module) and row["family"] == family
            and row["address"] == (d[11][i] if i < 6 else d[6]) and any(hex_bytes(row["runtimeHash"], 32)),
            "scoped policy V2 adapter family/catalogue")
        for field, role in (("core", "core"), ("host", host), ("evidenceProvider", "provider"), ("metadataHost", "metadata")):
            require((row[field], row[field+"CodeHash"]) == (graph[role]["address"], graph[role]["runtimeHash"]),
                "scoped policy V2 immutable adapter pin")
        require(expected[family][1:6] == (row["address"], COMPONENT_INTERFACE, row["runtimeHash"], *module),
            "scoped policy V2 finality family/adapter/module")
    return {**configured, "originalComponentSourceIdentitiesJoined": True, "collectionMetadataFactsPreimageReconstructed": False}


def validate_finality(value, context, graph, scope):
    chain, collection, token, stamp = _context(context, graph); scope = scope_value(scope)
    require(scope[1] == collection and (scope[0] != 1 or scope[2] == token), "scoped policy V2 target/scope differs")
    base._closed(value, base.FINALITY_KEYS, "scoped receipt group")
    record = base._v(SCOPED_RECORD, value["record"])
    components = base._v(Array(COMPONENT, 32), value["components"])
    manifest = base._v(MANIFEST_REF, value["manifestRef"])
    witness = base._v(EXECUTION_WITNESS, value["executionWitness"])
    archive = base._v(ARCHIVE_WITNESS, value["archiveWitness"])
    raw = base._bytes(value["manifestBytes"], MAX_MANIFEST, "scoped input manifest")
    envelope = decode(INPUT_ENVELOPE, raw, maximum=MAX_MANIFEST)
    core, host, metadata = (graph[key]["address"] for key in ("core", "finality", "metadata"))
    require(envelope[:6] == (INPUT_SCHEMA, INPUT_CANON, chain, core, metadata, host), "scoped policy V2 original manifest domain")
    statement = envelope[6]; independent = statement[8]
    require(statement[0] == scope and statement[1] != ZERO and statement[2] != ZERO
        and 0 < statement[3] <= MAX_OUTPUTS and (scope[0] != 1 or statement[3] == 1)
        and statement[4] == LEAF_SCHEMA and statement[5] != ZERO and statement[6] != ZERO
        and statement[9:] == (1, 1, 1), "scoped policy V2 input manifest profile")
    inputs = statement[7]
    require(all(inputs[index] != ZERO for index in (0, 1, 2, 5, 6, 7, 8, 9))
        and ((inputs[3] == ZERO) != (inputs[4] == ZERO)), "scoped policy V2 input commitments")
    require(len(independent) == 9 and tuple(row[0] for row in independent) == base.INDEPENDENT_FAMILIES,
        "scoped policy V2 independent component families")
    require(len(components) == 10 and tuple(row[0] for row in components) == tuple(sorted((*base.INDEPENDENT_FAMILIES, base.SANCTION)))
        and tuple(row for row in components if row[0] != base.SANCTION) == independent, "scoped policy V2 complete artist component set")
    for row in components:
        require(row[1] != ZERO_ADDRESS and row[2] == COMPONENT_INTERFACE and all(row[index] != ZERO for index in (0, 3, 4, 5, 6)),
            "scoped policy V2 empty component commitment")
    for family, key in (("ENTROPY_COORDINATOR", "entropySourceSet"), ("REFERENCE_RENDER", "policyReference")):
        row = next(row for row in components if row[0] == schema_id(family))
        require(row[1] == graph[key]["address"] and row[3] == graph[key]["runtimeHash"],
            "scoped policy V2 original component source identity")
    sanction = next(row for row in components if row[0] == base.SANCTION)
    require(sanction[1] == graph["artist"]["address"] and sanction[3] == graph["artist"]["runtimeHash"]
        and sanction[6] == archive[1][0] and all(item != ZERO for item in archive[1]), "scoped policy V2 original sanction/archive join")
    require(archive[0] == base.archive_evidence_hash(chain, core, host, graph["artifacts"]["address"], archive[1]),
        "scoped policy V2 archive evidence hash")
    require(manifest[1] == keccak256(manifest[0].encode("utf-8")) and manifest[2] == keccak256(raw)
        and manifest[3:] == (INPUT_SCHEMA, INPUT_CANON), "scoped policy V2 manifest reference differs")
    digest = base.components_hash(components)
    expected = finality_hash(chain, core, scope, statement[1], digest, manifest)
    require(record == (True, scope, expected, manifest[2], manifest[1], digest, manifest[0], host, record[8])
        and 0 < record[8] <= stamp, "scoped policy V2 stored original receipt differs")
    require(witness[0] != ZERO and witness[1] != ZERO_ADDRESS and witness[2] != ZERO
        and witness[3] != ZERO and witness[4] > 0, "scoped policy V2 original execution witness")
    execution = base.execution_context(chain, host, core, metadata, statement, expected, digest, archive[0])
    require(value["inputsHash"] == execution["inputsHash"], "scoped policy V2 original scope-input hash")
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
        "scoped policy V2 executed action/witness differs")
    require(type(value["callDatas"]) in (tuple, list) and 0 < len(value["callDatas"]) <= 64, "scoped policy V2 scheduled call count")
    calls = tuple(base._bytes(row, MAX_CALLDATA, "scoped scheduled call") for row in value["callDatas"])
    expected = hex_bytes(calldata(FINALIZE_SIGNATURE, FINALIZE_TYPES, (finality["statement"][0], finality["components"],
        finality["record"][2], finality["manifestRef"], finality["archiveWitness"][1])))
    require(len(expected) <= MAX_CALLDATA and calls.count(expected) == 1, "scoped policy V2 exact finalize bytes missing/duplicate")
    runtime = base._bytes(value["runtime"], 24576, "scoped scheduled carrier")
    require(any(hex_bytes(value["callDataPointer"], 20)) and runtime == b"\0" + encode((Array("bytes", 64),), (calls,)),
        "scoped policy V2 original scheduled bytes carrier differs")
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
        require(len(matches) == 1, "scoped policy V2 exact original governance event")
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
            "scoped policy V2 original finality call context differs")
        report["finalityCall"] = {"index": str(index), **call}
    return report


def validate_bundle(bundle, context, graph):
    from . import scoped_policy_content_wire_v2 as content_wire
    from . import scoped_policy_preservation_wire_v2 as preservation_wire
    from . import scoped_policy_static_components_v2 as static_wire
    from . import scoped_policy_membership_v2 as membership_wire
    from . import scoped_policy_preservation_types_v2 as t
    base._closed(bundle, ("scope", "factory", "provider", "finality", "content", "snapshot", "reference", "membership", "staticComponents", "execution"),
        "scoped policy V2 bundle")
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    provider = validate_routes(bundle["provider"], context, graph, f, bundle["factory"])
    s = f["statement"]
    content = content_wire.validate(bundle["content"], context, graph, s)
    preservation = preservation_wire.validate(bundle, context, graph, s, content)
    snapshot, reference = preservation["snapshot"], preservation["reference"]
    source = base._v(t.SNAPSHOT_SOURCE, snapshot["source"])
    from . import scoped_policy_factory_v2 as factory_wire
    factory_graph = base._v(factory_wire.GRAPH, bundle["factory"]["graph"])
    require(factory_graph[0] == s[0] and factory_graph[1] == source[9][0], "scoped policy V2 original factory plan/scope")
    require(bundle["factory"]["sourceFactoryDependencies"] == bundle["snapshot"]["entropyDependencies"]
        == bundle["content"]["checkpoint"]["factoryDependencies"], "scoped policy V2 shared source factory dependency tuple")
    # Publication gas parameters can be raised after construction. Their current
    # observed budgets do not alter the preserved targets, pins or payload hash.
    for family, child, kind in (("snapshot", "policySnapshot", t.SNAPSHOT_DEPS),
            ("reference", "policyReference", t.REFERENCE_DEPS)):
        observed = base._v(kind, bundle[family]["dependencies"])
        minimum = base._v(kind, bundle["factory"]["childDependencies"][child])
        require(observed[:3] == minimum[:3] and all(a >= b for a, b in zip(observed[3:], minimum[3:])),
            "scoped policy V2 factory child immutable pins/minimum budgets")
    for group in (snapshot, reference):
        lock = base._v(t.SNAPSHOT_LOCK, group["lock"])
        require(lock[2] != ZERO and 0 < lock[3] <= f["record"][8], "policy finality requires original class-two locks")
    expected_components = {c[0]: c for c in f["components"]}
    for name, family in (("entropy", "ENTROPY_COORDINATOR"), ("reference", "REFERENCE_RENDER")):
        commitment = preservation["componentCommitments"][name]
        require(expected_components[schema_id(family)][4:7] == tuple(commitment[k] for k in ("moduleVersion", "manifestHash", "dataHash")),
            "policy original retained component commitment")
    membership = membership_wire.validate(bundle["membership"], context, graph, s[0], snapshot["membership"], content["tokenIds"])
    value, sc = bundle["staticComponents"], bundle["staticComponents"]["context"]
    require(sc["chainId"] == context["chainId"] and sc["core"] == graph["core"]["address"]
        and sc["metadata"] == graph["metadata"]["address"] and sc["router"] == graph["router"]["address"]
        and sc["routerCodeHash"] == graph["router"]["runtimeHash"] and sc["selection"] == graph["staticSelection"]["address"]
        and sc["selectionCodeHash"] == graph["staticSelection"]["runtimeHash"]
        and (sc["routerModuleVersion"], sc["routerModuleManifestHash"]) == tuple(bundle["provider"]["moduleIdentities"]["router"]),
        "policy STATIC original dependency context")
    require(sc["adapters"] == [{k: row[k] for k in ("family", "address", "runtimeHash")} for row in bundle["provider"]["adapters"][:6]],
        "policy STATIC adapter evidence join")
    authenticated = (source[0], preservation["snapshotProfileHash"], source[4][0], source[3][1], source[3][5], source[3][3], source[2][11])
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
    from . import scoped_policy_content_wire_v2 as content
    from . import scoped_policy_content_types_v2 as t
    from . import scoped_policy_preservation_wire_v2 as preservation
    from . import scoped_policy_membership_v2 as membership
    from .scoped_static_snapshot_wire import _descriptor, selection_row_hash
    from . import scoped_policy_factory_v2 as factory
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    cp = bundle["content"]["checkpoint"]
    plan = base._v(t.SELECTION_PLAN, cp["selectionPlan"])
    key = cp["plan"][0]; host = graph["staticSelection"]["address"]
    rows = list(membership.expected_events(bundle["membership"], context, graph, f["statement"][0]))
    for child in bundle["factory"]["preparationEvents"]:
        rows.append({"kind": "factory_child_prepared", "address": graph["publicationFactory"]["address"],
            "topics": (factory.CHILD_EVENT, child["graphId"], child["inventoryPlan"], base._topic("uint8", uint(child["childIndex"], 8))),
            "data": "0x"+encode(("uint16", "address", "bytes32"), (2, child["child"], child["codeHash"])).hex()})
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
    from . import scoped_policy_content_wire_v2 as content
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
    f = validate_finality(bundle["finality"], context, graph, bundle["scope"])
    prepared = by_kind["factory_child_prepared"]
    require([int.from_bytes(hex_bytes(row["log"]["topics"][3], 32), "big") for row in prepared] == list(range(7)),
        "scoped policy factory complete ordered child preparation")
    # Factory children may be prepared in separate transactions. The checkpoint
    # can start after child1 exists, before inventory/bundle children5/6 exist.
    before(prepared[1], one("content_started"))
    for family in ("selection", "content"):
        start, complete, rows = one(family+"_started"), one(family+"_completed"), by_kind[family+"_appended"]
        require([int.from_bytes(hex_bytes(r["log"]["topics"][2],32), "big") for r in rows] == list(range(f["statement"][3])),
            "policy ordered complete checkpoint event indices")
        before(start, rows[0]); adjacent(rows[-1], complete)
    before(one("selection_completed"), one("content_started"))
    if f["statement"][0][0] != 1:
        from .scoped_static_types import MEMBERSHIP_PUBLICATION
        mr, ma, ms = (one(k) for k in ("membership_recorded", "membership_admitted", "membership_sealed"))
        progress = by_kind["membership_progressed"]
        before(mr, ma); before(ma, progress[0]); adjacent(progress[-1], ms); before(ms, one("selection_started"))
        require([decode(("uint256", "uint256"), hex_bytes(r["log"]["data"])) for r in progress]
            == [base._v(("uint256", "uint256"), r) for r in bundle["membership"]["progressHistory"]], "scoped policy membership progress order")
        require(uint(mr["timestamp"], 64) == base._v(MEMBERSHIP_PUBLICATION, bundle["membership"]["publication"])[7][3],
            "scoped policy membership original time")
    artifact, coverage, started, verified = (one(k) for k in ("artifact_recorded", "coverage_completed", "manifest_started", "manifest_verified"))
    before(prepared[2], started)
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
    # Native root publication resolves scopedPolicySnapshotHost via the provider,
    # whose graph selection requires the complete seven-child factory graph.
    before(prepared[-1], selected_root)
    for event, original in zip(roots,bundle["content"]["roots"]["history"]):
        require(event["timestamp"] == original["record"][17], "policy original root time")
        if original["binding"][0] != ZERO:
            binding = next(r for r in by_kind["root_binding_published"] if r["log"]["topics"][3] == original["recordHash"])
            adjacent(event,binding)
    selected = {}
    for family, input_index in (("snapshot",1),("reference",2)):
        rows, history = by_kind["policy_"+family+"_published"], bundle[family]["history"]
        receipts = [r["receipt"] if family == "snapshot" else r["receipt"][1] for r in history]
        require([r["log"]["topics"][3] for r in rows] == [r[0] for r in receipts], "policy preservation history event order")
        for event, receipt in zip(rows,receipts):
            require(event["timestamp"] == receipt[13 if family == "snapshot" else 15], "policy preservation publication time")
        chosen = next(r for r in rows if r["log"]["topics"][3] == f["statement"][7][input_index]); selected[family] = chosen
        before(prepared[3 if family == "snapshot" else 4], rows[0])
        locked = one("policy_"+family+"_locked"); before(chosen,locked)
        require(locked["timestamp"] == bundle[family]["lock"][3], "policy original preservation lock time")
    before(verified,selected["snapshot"]); before(selected["snapshot"],selected_root); before(selected_root,selected["reference"])
    terminal = [one(k) for k in ("scopedFinalized","manifestPointer","terminalExecuted","executionWitness","archiveWitness")]
    finalized = terminal[0]
    before(prepared[-1], finalized)
    prior = [r for r, original in zip(roots, bundle["content"]["roots"]["history"])
        if base._v(SCOPE, original["record"][0][0]) == f["statement"][0] and pos(r) < pos(finalized)]
    require(prior and prior[-1] == selected_root, "policy selected root not latest before original finality")
    original_route = content.route_hash(uint(context["chainId"]), graph, f["statement"][0])
    for event, original in zip(roots,bundle["content"]["roots"]["history"]):
        if base._v(SCOPE, original["record"][0][0]) == f["statement"][0] and original["record"][14] == original_route: before(event,finalized)
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
        require(uint(row["timestamp"],64) == f["record"][8], "policy finality publication time")
        same_tx(finalized,row)
        require(quantity(row["log"]["logIndex"]) == quantity(finalized["log"]["logIndex"])+i, "policy terminal event adjacency")
    same_tx(finalized,executed); before(terminal[-1],executed)
    return {"eventCount": str(len(events)), "originalPublicationChronologyChecked": True, "providerLogCompletenessTrusted": True}




def definitions():
    from . import native_scoped_finality_wire as original
    from . import scoped_policy_content_wire_v2 as content
    from . import scoped_policy_preservation_wire_v2 as preservation
    from . import scoped_static_snapshot_wire as membership
    rows = (*original.definitions()[:2], *content.definitions(), *preservation.definitions(), *membership.definitions()[3:])
    unique = {}
    for row in rows:
        require(row["id"] not in unique or unique[row["id"]] == row, "scoped policy conflicting definition")
        unique[row["id"]] = row
    return tuple(unique.values())
