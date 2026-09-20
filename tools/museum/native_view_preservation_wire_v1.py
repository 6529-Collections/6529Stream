"""Joined original VIEW preservation evidence; no complete finality is inferred."""
from .canonical import dumps, hex_bytes, keccak256, uint
from .chain_rpc import quantity
from .independent_wire import require
from .native_finality_wire import event_matches, from_json
from .scoped_static_types import SCOPE

SOURCE_REVISION = "e8a569b36927ed7f711a14a30ce5b09690694dd0"
GRAPH_KEYS = ("core", "router", "authority", "checkpoint", "outputManifest",
    "coverage", "schemas", "store", "artist", "metadata", "finality", "provider", "views",
    "scopeMembership", "sourceFactory", "entropySourceSet", "coordinatorInventory",
    "renderer", "rendererRegistry", "checkpointSourceWorker", "checkpointTokenWorker",
    "manifestReadWorker", "manifestEncodingWorker", "tokenInventory", "attribution",
    "rendererEncoding", "preservationRenderer", "preservationAttribution",
    "preservationWorker", "preservationEncoding", "viewSnapshot")


def scope_value(value):
    scope = from_json(SCOPE, value)
    require(scope[0] == 4 and scope[1] > 0 and scope[2] == 0
        and any(hex_bytes(scope[3], 32)), "VIEW preservation scope differs")
    return scope


def context_graph(context, graph):
    require(uint(context["chainId"]) > 0 and uint(context["collectionId"]) > 0,
        "VIEW preservation source identity")
    uint(context["timestamp"], 64)
    require(type(graph) is dict and set(graph) == set(GRAPH_KEYS), "VIEW preservation exact graph roles")
    pins = {}
    for row in graph.values():
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}
            and any(hex_bytes(row["address"], 20)) and any(hex_bytes(row["runtimeHash"], 32)),
            "VIEW preservation graph identity")
        require(row["address"] not in pins or pins[row["address"]] == row["runtimeHash"],
            "VIEW preservation aliased runtime differs")
        pins[row["address"]] = row["runtimeHash"]
    require(graph["core"]["address"] == context["core"], "VIEW preservation original Core differs")


def validate_bundle(value, context, graph):
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    from . import view_preservation_output_wire_v1 as output
    from . import view_preservation_snapshot_wire_v1 as snapshot
    from . import view_preservation_root_wire_v1 as root
    context_graph(context, graph)
    require(type(value) is dict and set(value) ==
        {"scope", "adoption", "membership", "output", "snapshot", "root"},
        "VIEW preservation closed evidence bundle")
    scope = scope_value(value["scope"])
    require(scope[1] == uint(context["collectionId"]), "VIEW preservation foreign scope")
    adopted = adoption.validate(value["adoption"], context, graph)
    binding = adopted["policyBinding"]
    members = membership.validate(value["membership"], context, graph, binding,
        outputs=value["output"]["checkpoint"]["outputs"])
    require(scope_value(members["scope"]) == scope, "VIEW preservation membership scope differs")
    combined = {**adopted, "tokenIds": members["tokenIds"], "policies": members["policies"]}
    produced = output.validate(value["output"], context, graph, combined)
    retained = snapshot.validate(value["snapshot"], context, graph,
        adoption=adopted, membership=members, output_value=value["output"])
    source = retained["source"]
    require(source[0] == value["scope"] and source[1] == members["facts"]
        and source[3] == value["output"]["checkpoint"]["source"]
        and source[4] == value["output"]["checkpoint"]["plan"]
        and source[5] == value["output"]["manifest"]["plan"]
        and source[6] == members["evidence"], "VIEW preservation original snapshot source differs")
    published = root.validate(value["root"], context, graph,
        snapshot_value=value["snapshot"], output_value=value["output"])
    return {"adoption": adopted, "membership": members, "output": produced,
        "snapshot": retained, "root": published}


def definitions():
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    from . import view_preservation_output_wire_v1 as output
    from . import view_preservation_snapshot_wire_v1 as snapshot
    from . import view_preservation_root_wire_v1 as root
    found = {}
    for row in (*adoption.definitions(), *membership.definitions(), *output.definitions(),
            *snapshot.definitions(), *root.definitions()):
        require(row["id"] not in found or found[row["id"]] == row,
            "VIEW preservation conflicting native definition")
        found[row["id"]] = row
    return tuple(found.values())


def expected_events(bundle, context, graph):
    from . import view_preservation_adoption_wire_v1 as adoption
    from . import view_policy_membership_v2 as membership
    from . import view_preservation_output_wire_v1 as output
    from . import view_preservation_snapshot_wire_v1 as snapshot
    from . import view_preservation_root_wire_v1 as root
    adopted = adoption.validate(bundle["adoption"], context, graph)
    return (*adoption.expected_events(bundle["adoption"], context, graph),
        *membership.expected_events(bundle["membership"], context, graph, adopted["policyBinding"]),
        *output.expected_events(bundle["output"], context, graph),
        *snapshot.expected_events(bundle["snapshot"], context, graph),
        *root.expected_events(bundle["root"], context, graph))


def validate_event_join(bundle, context, graph, events):
    expected = expected_events(bundle, context, graph)
    require(type(events) is list and len(events) == len(expected), "VIEW preservation complete event denominator")
    previous, positions, groups, block_times, transactions = None, set(), {}, {}, {}
    source_number, source_stamp = uint(context["blockNumber"], 64), uint(context["timestamp"], 64)
    source_hash = context["blockHash"]
    require(any(hex_bytes(source_hash, 32)), "VIEW preservation source block hash")
    block_times[source_number] = (source_hash, source_stamp)
    block_numbers, transaction_slots, block_log_indices = {source_hash: source_number}, {}, {}
    unmatched = list(expected)
    for row in events:
        require(type(row) is dict and set(row) == {"log", "timestamp"}, "VIEW preservation event wrapper")
        log = row["log"]
        position = tuple(quantity(log[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
        stamp = uint(row["timestamp"], 64)
        require(position not in positions and (previous is None or previous < position)
            and position[0] <= uint(context["blockNumber"], 64) and stamp <= uint(context["timestamp"], 64),
            "VIEW preservation event order or source block")
        require(log.get("removed") is False, "VIEW preservation removed event")
        for key in ("blockHash", "transactionHash"): require(any(hex_bytes(log[key], 32)), "VIEW preservation event hash")
        header = (log["blockHash"], stamp)
        require(position[0] not in block_times or block_times[position[0]] == header, "VIEW preservation event block conflict")
        block_times[position[0]] = header
        require(log["blockHash"] not in block_numbers or block_numbers[log["blockHash"]] == position[0],
            "VIEW preservation event block number conflict")
        block_numbers[log["blockHash"]] = position[0]
        slot = position[:2]
        require(slot not in transaction_slots or transaction_slots[slot] == log["transactionHash"],
            "VIEW preservation event transaction slot conflict")
        transaction_slots[slot] = log["transactionHash"]
        prior_log = block_log_indices.get(position[0])
        require(prior_log is None or prior_log < position[2], "VIEW preservation block log order")
        block_log_indices[position[0]] = position[2]
        tx = (position[0], position[1], log["blockHash"])
        require(log["transactionHash"] not in transactions or transactions[log["transactionHash"]] == tx,
            "VIEW preservation event transaction conflict")
        transactions[log["transactionHash"]] = tx
        matches = [item for item in unmatched if event_matches(
            (item["address"], item["topics"], item["data"]), log)]
        require(len(matches) == 1, "VIEW preservation event missing, duplicated or unexpected")
        matched = matches[0]
        unmatched.remove(matched)
        groups.setdefault(matched["kind"], []).append(row)
        previous = position
        positions.add(position)
    require(not unmatched, "VIEW preservation original event missing")
    ordered_times = [value[1] for _, value in sorted(block_times.items())]
    require(ordered_times == sorted(ordered_times), "VIEW preservation event time order")
    def pos(row):
        return tuple(quantity(row["log"][key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
    def one(kind):
        rows = groups.get(kind, [])
        require(len(rows) == 1, "VIEW preservation single " + kind)
        return rows[0]
    def before(left, right):
        require(pos(left) < pos(right), "VIEW preservation publication chronology")
    def adjacent(left, right):
        before(left, right)
        require(all(left["log"][key] == right["log"][key]
            for key in ("blockHash", "transactionHash", "transactionIndex"))
            and quantity(left["log"]["logIndex"]) + 1 == quantity(right["log"]["logIndex"]),
            "VIEW preservation completion event adjacency")
    from .chain_abi import decode
    from . import view_preservation_output_types_v1 as output_types
    from . import view_policy_adoption_types_v2 as adoption_types
    started, sealed = one("view_checkpoint_started"), one("view_checkpoint_sealed")
    rows = groups.get("view_checkpoint_appended", [])
    count = uint(bundle["output"]["checkpoint"]["plan"][5], 64)
    require([decode(("uint64", "bytes32"), hex_bytes(row["log"]["data"]))[0] for row in rows]
        == list(range(count)), "VIEW preservation complete ordered append events")
    for row in rows:
        before(started, row)
        before(row, sealed)
    chosen = bundle["output"]["checkpoint"]["plan"][1]
    adopted_events = [row for row in events if row["log"]["address"] == graph["router"]["address"]
        and len(row["log"]["topics"]) == 4 and row["log"]["topics"][3] == chosen]
    require(len(adopted_events) == 1, "VIEW preservation selected adoption event")
    selected_adoption = adopted_events[0]
    before(selected_adoption, started)
    # Every manifest operation revalidates the selected checkpoint. Its adoption
    # must remain selected through the final verification, not merely the seal.
    manifest_verified = one("view_manifest_verified")
    prior = []
    for row in bundle["adoption"]["history"]:
        record = from_json(adoption_types.RECORD, row["record"])
        event = from_json(adoption_types.EVENT, row["event"])
        originals = [item for item in events if item["log"]["address"] == graph["router"]["address"]
            and len(item["log"]["topics"]) == 4 and item["log"]["topics"][3] == record[3]]
        require(len(originals) == 1, "VIEW preservation adoption history event denominator")
        observed = originals[0]
        require((quantity(observed["log"]["blockNumber"]), observed["log"]["blockHash"],
            observed["log"]["transactionHash"], quantity(observed["log"]["transactionIndex"]),
            quantity(observed["log"]["logIndex"]), uint(observed["timestamp"], 64)) == event[6:],
            "VIEW preservation adoption original coordinates differ")
        if record[0][0] == scope_value(bundle["scope"]) and (event[6], event[9], event[10]) < pos(manifest_verified):
            prior.append(record[3])
    require(prior and prior[-1] == chosen, "VIEW preservation adoption changed before manifest verification")
    recorded, admitted, member_sealed = (one(kind) for kind in
        ("membership_recorded", "membership_admitted", "membership_sealed"))
    progress = groups.get("membership_progressed", [])
    require(progress, "VIEW preservation original membership progress missing")
    before(recorded, admitted)
    before(admitted, progress[0])
    adjacent(progress[-1], member_sealed)
    before(member_sealed, one("source_set_prepared"))
    before(one("source_set_prepared"), selected_adoption)
    publication = bundle["membership"]["membership"]["publication"]
    require(recorded["timestamp"] == publication[7][3], "VIEW preservation membership publication time")
    expected_progress = [tuple(uint(value) for value in row)
        for row in bundle["membership"]["membership"]["progressHistory"]]
    require([decode(("uint256", "uint256"), hex_bytes(row["log"]["data"])) for row in progress]
        == expected_progress, "VIEW preservation original membership progress order")
    manifest = bundle["output"]["manifest"]
    started_manifest, verified = one("view_manifest_started"), one("view_manifest_verified")
    before(sealed, started_manifest)
    prepared = {row["log"]["topics"][1]: row for row in groups.get("view_part_prepared", [])}
    advanced = groups.get("view_manifest_advanced", [])
    require([decode(("uint16", "bytes32"), hex_bytes(row["log"]["data"])) for row in advanced]
        == [(index, row["recordHash"]) for index, row in enumerate(manifest["parts"])],
        "VIEW preservation complete ordered manifest progress")
    for index, part in enumerate(manifest["parts"]):
        before(sealed, prepared[part["recordHash"]])
        before(prepared[part["recordHash"]], advanced[index])
        before(started_manifest, advanced[index])
    adjacent(advanced[-1], verified)
    cover_events = {row["log"]["topics"][1]: row for row in groups.get("view_coverage_completed", [])}
    for item in (*manifest["parts"], manifest):
        coverage = from_json(output_types.COVERAGE, item["coverage"])
        observed = cover_events[coverage[0]]
        require(uint(observed["timestamp"], 64) == coverage[10], "VIEW preservation original coverage time")
        before(observed, started_manifest if item is manifest else prepared[item["recordHash"]])
    before(selected_adoption, one("preservation_registered"))
    before(one("preservation_registered"), started)

    def keyed(kind, key):
        rows = [row for row in groups.get(kind, []) if row["log"]["topics"][3] == key]
        require(len(rows) == 1, "VIEW preservation original publication denominator")
        return rows[0]

    def selected_before(scope, boundary, record_hash):
        preceding = []
        for row in bundle["adoption"]["history"]:
            record = from_json(adoption_types.RECORD, row["record"])
            event = from_json(adoption_types.EVENT, row["event"])
            if record[0][0] == scope and (event[6], event[9], event[10]) < pos(boundary):
                preceding.append(record[3])
        require(preceding and preceding[-1] == record_hash,
            "VIEW preservation adoption changed before snapshot/root publication")

    snapshots = bundle["snapshot"]
    prior_snapshot = None
    for row in snapshots["history"]:
        publication, receipt, source = row["publication"], row["receipt"], row["source"]
        observed = keyed("view_snapshot_published", receipt[0])
        require(observed["timestamp"] == receipt[13], "VIEW preservation original snapshot time")
        if prior_snapshot is not None: before(prior_snapshot, observed)
        prior_snapshot = observed
        selected_before(scope_value(publication[0]), observed, source[3][0][3])
        originals = [item["record"] for item in bundle["adoption"]["history"]
            if item["record"][3] == source[3][0][3]]
        require(originals == [source[3][0]], "VIEW preservation snapshot original adoption differs")
        if receipt[0] == snapshots["selectedRecordHash"]: before(verified, observed)
    lock = snapshots["lock"]
    if uint(lock[1], 64):
        locked = one("view_snapshot_locked")
        require(locked["timestamp"] == lock[3], "VIEW preservation original snapshot lock time")
        saved = [row for row in snapshots["history"] if row["receipt"][0] == lock[0]]
        require(len(saved) == 1, "VIEW preservation lock original snapshot")
        before(keyed("view_snapshot_published", lock[0]), locked)
        selected_before(scope_value(saved[0]["publication"][0]), locked, saved[0]["source"][3][0][3])

    prior_root = None
    for row in bundle["root"]["history"]:
        record = row["record"]
        published = keyed("view_root_published", row["recordHash"])
        require(published["timestamp"] == record[17], "VIEW preservation original CONTENT_ROOT time")
        if prior_root is not None: before(prior_root, published)
        prior_root = published
        if row["binding"] is not None:
            bound = keyed("view_root_binding_published", row["recordHash"])
            adjacent(published, bound)
            selected_before(scope_value(record[0][0]), published, row["binding"][2])
        if record[1] == graph["viewSnapshot"]["address"] and record[0][0] == bundle["scope"]:
            before(keyed("view_snapshot_published", record[0][2]), published)
            preceding = [item["receipt"][0] for item in snapshots["history"]
                if pos(keyed("view_snapshot_published", item["receipt"][0])) < pos(published)]
            require(preceding and preceding[-1] == record[0][2],
                "VIEW preservation snapshot changed before CONTENT_ROOT publication")
    return {"eventCount": str(len(events)), "providerLogCompletenessTrusted": True,
        "originalPublicationChronologyChecked": True,
        "historicalAuthorityVerified": False, "viewFinalityEstablished": False}


def target_proof(bundle, context, graph):
    from . import view_preservation_output_wire_v1 as output
    from . import view_preservation_output_types_v1 as kinds
    token = uint(context["tokenId"])
    rows = [from_json(kinds.OUTPUT, row) for row in bundle["output"]["checkpoint"]["outputs"]]
    indices = [index for index, row in enumerate(rows) if row[1] == token]
    require(len(indices) == 1, "VIEW preservation target absent or duplicated")
    index = indices[0]
    checkpoint = bundle["output"]["checkpoint"]
    return {"kind": "view_preservation_full_output_proof_v1", "tokenId": context["tokenId"],
        "scope": bundle["scope"], "checkpointId": checkpoint["id"], "rowIndex": str(index),
        "rowCount": str(len(rows)), "row": checkpoint["outputs"][index],
        "outputRoot": checkpoint["plan"][8], "contentRoot": checkpoint["plan"][9],
        "proof": output.target_proof(bundle["output"], context, index),
        "snapshotRecordHash": bundle["snapshot"]["selectedRecordHash"],
        "contentRootRecordHash": bundle["root"]["selectedRecordHash"],
        "verification": "ordered full-output Merkle tree plus complete checkpoint rows and covered parts",
        "nativeFinality": False, "renderedBytesRecovered": False}
