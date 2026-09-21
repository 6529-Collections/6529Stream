"""Offline supplied-evidence validator for attributed VIEW retrieval records.

This module checks the frozen native hash/ABI domains and joins an operative
record to a complete preservation proof, immutable inventory companion, and
the original Archive pair at one captured source block.  It does not perform a
network retrieval, replay Safe authority, or infer execution from supplied
bytes.
"""

from . import native_view_preservation_wire_v1 as preservation
from . import view_policy_adoption_types_v2 as adoption_types
from . import view_preservation_bundle_wire_v1 as bundle_wire
from . import view_preservation_inventory_items_v1 as items
from . import view_preservation_inventory_types_v1 as inventory_types
from . import view_preservation_inventory_wire_v1 as inventory_wire
from . import view_preservation_locator_wire_v1 as locator_wire
from . import view_preservation_output_types_v1 as output_types
from . import view_preservation_reference_wire_v1 as reference_wire
from . import view_preservation_retrieval_types_v1 as t
from . import view_preservation_retrieval_routes_v1 as routes
from .canonical import MuseumError, hex_bytes, keccak256, schema_id, uint
from .chain_history import LOG_FIELDS
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values, require
from .native_finality_wire import from_json, event_matches


CLAIMS = {
    "nativeHashDomainsChecked": True,
    "completePreservationProofRequired": True,
    "immutableCompanionRuntimeBound": True,
    "currentCheckpointSourceJoined": True,
    "lockedArtistPresentationJoined": True,
    "currentArchivePairJoined": True,
    "scopeRevocationEpochJoined": True,
    "retainedHistoryCurrentnessEvaluated": False,
    "networkRetrievalPerformed": False,
    "historicalSignatureReauthorized": False,
    "currentSafeAuthorityChecked": False,
    "evmExecutionProven": False,
    "consensusProven": False,
}

QUALIFICATION = (
    "The report checks supplied canonical native preimages, complete preservation evidence, "
    "the immutable retrieval companion, scope revocation history, and original/current Archive "
    "pair observations at the captured block. It does not fetch any URI, replay historical "
    "signature authority, prove EVM execution, or extend currentness beyond that block."
)


def _hash(kinds, values):
    return keccak256(encode(kinds, values))


def _raw(value, maximum, label):
    raw = hex_bytes(value)
    require(0 < len(raw) <= maximum, label)
    return raw


def configuration_hash(configuration):
    c = from_json(t.CONFIGURATION, configuration)
    return _hash(("bytes32", t.CONFIGURATION), (t.PROFILE, c))


def source_key(source):
    s = from_json(t.SOURCE, source)
    return _hash(
        ("bytes32", t.SCOPE, "address", "address", *("bytes32",) * 2,
         "address", *("bytes32",) * 2, "string", *("bytes32",) * 2),
        (t.SOURCE_DOMAIN, s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7],
         s[9], s[10], s[11]),
    )


def observation_hash(configuration, witness, observation):
    c = from_json(t.CONFIGURATION, configuration)
    o = from_json(t.OBSERVATION, observation)
    return _hash(
        ("bytes32", "uint256", "address", "bytes32", t.OBSERVATION),
        (t.OBSERVATION_DOMAIN, c[8], witness, configuration_hash(c), o),
    )


def record_hash(configuration, witness, receipt):
    c = from_json(t.CONFIGURATION, configuration)
    r = list(from_json(t.RECEIPT, receipt))
    r[0] = ZERO
    return _hash(
        ("bytes32", "uint256", "address", "bytes32", t.RECEIPT),
        (t.RECORD_DOMAIN, c[8], witness, configuration_hash(c), tuple(r)),
    )


def scope_key(scope):
    return _hash(("bytes32", t.SCOPE), (t.REVOCATION_SCOPE_DOMAIN, from_json(t.SCOPE, scope)))


def environment_hash(original, witness, runtime_hash, scope, epoch):
    return _hash(
        ("bytes32", "bytes32", "address", "bytes32", t.SCOPE, "uint64"),
        (t.ARCHIVE_ENVIRONMENT_DOMAIN, original, witness, runtime_hash,
         from_json(t.SCOPE, scope), from_json("uint64", epoch)),
    )


def nonce_key(writer, nonce):
    return _hash(("bytes32", "address", "uint256"),
                 (t.NONCE_DOMAIN, writer, uint(str(nonce))))


def _safe_uri(value):
    return routes.uri(value)


def _shape(observation):
    o = from_json(t.OBSERVATION, observation)
    s, obj, coverage, steps = o[:4]
    require(s[0][0] == 4 and s[0][1] > 0 and s[0][2] == 0 and s[0][3] != ZERO,
            "VIEW retrieval scope")
    require(s[1] != ZERO_ADDRESS and s[2] != ZERO_ADDRESS and all(s[i] != ZERO for i in (3, 4, 6, 7, 8, 10, 11)),
            "VIEW retrieval source identity")
    require(s[5] != ZERO_ADDRESS and obj[0] == s[10] and o[5] != ZERO_ADDRESS
            and o[6] > 0 and o[8] >= o[6] and coverage[0] != ZERO
            and coverage[1] != ZERO and obj[3] != ZERO and obj[4] != ZERO and obj[6] > 0,
            "VIEW retrieval observation shape")
    routes.shape(json_values(o))
    return o


def _institutional(uri):
    try:
        return locator_wire.locator(uri)[0] == 1
    except MuseumError:
        return False


def obligation_item(source):
    s = from_json(t.SOURCE, source); uri = s[9]
    if not uri or uri.startswith("ipfs://"):
        return items.media(s[5], s[6], uri)
    kind, _ = _safe_uri(uri)
    if kind == 2 or (kind == 1 and _institutional(uri)):
        return locator_wire.media(s[5], s[6], uri)
    row = list(items.empty(4, t.ROLE, s[2], s[3], 0))
    row[6] = locator_wire.RAW; row[8] = uri; row[16] = source_key(s)
    return tuple(row)


def _expected_source(bundle, result, current):
    require(result["adoption"]["selectedIsCurrentHead"] is True,
            "VIEW retrieval selected adoption is not current head")
    record = from_json(adoption_types.RECORD, result["adoption"]["record"])
    selected = next(row for row in bundle["adoption"]["history"]
                    if row["record"][3] == bundle["adoption"]["selectedRecordHash"])
    raw_payload = _raw(selected["declaration"]["viewPayload"], adoption_types.MAX_PAYLOAD,
                       "VIEW retrieval adopted payload byte bound")
    payload = decode((adoption_types.PAYLOAD,), raw_payload, maximum=adoption_types.MAX_PAYLOAD)[0]
    require(encode((adoption_types.PAYLOAD,), (payload,)) == raw_payload
            and keccak256(raw_payload) == record[1][8] and len(raw_payload) == record[1][9],
            "VIEW retrieval adopted payload")
    checkpoint = from_json(output_types.SOURCE, current["checkpointSource"])
    require(current["checkpointSource"] == bundle["output"]["checkpoint"]["source"],
            "VIEW retrieval current checkpoint source differs")
    artist = from_json(t.ARTIST_PRESENTATION, current["artistPresentation"])
    require(artist[0] and artist[1] != ZERO_ADDRESS
            and all(artist[i] != ZERO for i in (2, 3, 5, 7, 8, 11))
            and artist[4] > 0 and artist[6] != ZERO_ADDRESS and 0 < artist[9] <= artist[10],
            "VIEW retrieval locked Artist presentation")
    route = record[1][0]
    require(artist[1:3] == route[4:6] and checkpoint[0] == record,
            "VIEW retrieval current source/adoption differs")
    source = (
        record[0][0], route[0], route[2], record[3], record[2], route[16][0],
        record[0][2], record[1][8], checkpoint[4], payload[3], artist[3],
        _hash((t.ARTIST_PRESENTATION,), (artist,)),
    )
    return source, artist, record[10], checkpoint


def _source_pins(bundle, checked, originals):
    """Reconcile every validated source carrier, policy and Registry runtime."""
    pending = [bundle]
    while pending:
        value = pending.pop()
        if type(value) is dict:
            if "pointer" in value and "runtime" in value:
                digest = keccak256(hex_bytes(value["runtime"]))
                require("codeHash" not in value or value["codeHash"] == digest,
                        "VIEW retrieval source carrier runtime differs")
                originals.pin(value["pointer"], digest)
            pending.extend(value.values())
        elif type(value) is list:
            pending.extend(value)
    for policy in checked["membership"]["policies"]:
        originals.pin(policy[0], policy[1])
    for target in checked["adoption"]["preservation"]["registry"]["targets"]:
        originals.pin(target[0], target[1])


def _reference_source_pins(reference, context, graph, originals):
    """Seed all independently validated reference source groups into one map."""
    for row in reference["history"]:
        proof = row["sourceProof"]
        checked = preservation.validate_bundle(proof["bundle"], context, graph)
        _source_pins(proof["bundle"], checked, originals)


def _inventory_events(inventory):
    """Return every already-validated inventory/reference/source event observation."""
    value = inventory["value"]; reference = value["reference"]
    events = [*value["events"], *reference["events"]]
    for row in reference["history"]:
        events.extend(row["sourceProof"]["events"])
    return events


def _selected_adoption_position(bundle, events, context, graph, adopted_at):
    """Locate the exact validated selected-adoption publication coordinate."""
    from . import view_preservation_adoption_wire_v1 as preservation_adoption
    selected = bundle["adoption"]["selectedRecordHash"]
    descriptors = preservation_adoption.expected_events(bundle["adoption"], context, graph)
    index = next(index for index, row in enumerate(bundle["adoption"]["history"])
        if row["record"][3] == selected)
    descriptor = descriptors[index]
    matches = [row for row in events
        if uint(row["timestamp"], 64) == adopted_at
        and event_matches((descriptor["address"], descriptor["topics"], descriptor["data"]), row["log"])]
    require(len(matches) == 1, "VIEW retrieval selected adoption event identity")
    return reference_wire._position(matches[0])


def _event(row, expected, label):
    require(type(row) is dict and set(row) == {"log", "timestamp"}, label + " wrapper")
    require(type(row["log"]) is dict and set(row["log"]) == set(LOG_FIELDS) | {"removed"}
            and row["log"]["removed"] is False and event_matches(expected, row["log"])
            and uint(row["timestamp"], 64) > 0,
            label + " event")


def _publication(witness, receipt):
    return (witness, (t.RECORDED_TOPIC, receipt[0], receipt[1],
            "0x" + encode(("address",), (receipt[5],)).hex()),
            "0x" + encode((t.RECEIPT,), (receipt,)).hex())


def _revocation(witness, receipt, reason):
    return (witness, (t.REVOKED_TOPIC, receipt[0],
            "0x" + encode(("address",), (receipt[5],)).hex()),
            "0x" + encode(("bytes32",), (reason,)).hex())


def _call(target, signature, inputs=(), values=(), outputs=(), result=()):
    return {"target": target, "calldata": calldata(signature, inputs, values),
            "result": "0x" + encode(outputs, result).hex()}


def _record_call(originals, target, signature, inputs=(), values=(), outputs=(), result=()):
    row = _call(target, signature, inputs, values, outputs, result)
    key = (target, row["calldata"])
    require(originals.answers.setdefault(key, row["result"]) == row["result"],
            "VIEW retrieval conflicting retained getter")
    originals.calls.append(row)


def _bundle_dependencies(value, context, graph):
    d = from_json(t.BUNDLE_DEPENDENCIES, value)
    require(d[0] == tuple(graph[key]["address"] for key in bundle_wire.DEPENDENCY_ROLES)
            and d[1] == tuple(graph[key]["runtimeHash"] for key in bundle_wire.DEPENDENCY_ROLES)
            and d[2] == uint(context["chainId"]) and d[3] >= 50000
            and d[3] <= d[4] <= bundle_wire.MAX_GAS,
            "VIEW retrieval exact bundle dependencies")
    return d


def _admit_current(evidence, source, expected_object, expected_coverage, expected_writer,
                   context, graph, dependencies, originals):
    require(type(evidence) is dict and set(evidence) == {"admission", "sourceEvidence",
            "currentPair", "secondFamily"}, "VIEW retrieval Archive current evidence shape")
    admission = from_json(t.ADMISSION, evidence["admission"])
    pair = from_json(t.CURRENT_PAIR, evidence["currentPair"])
    coverage = admission[3]
    require(pair[:10] == coverage[1:11] and pair[10] != ZERO and pair[11] != ZERO
            and pair[12:] == coverage[13:15], "VIEW retrieval current Archive pair")
    item = list(obligation_item(source)); obj = from_json(t.OBJECT, evidence["sourceEvidence"]["object"])
    require((expected_object is None or obj == expected_object)
            and (expected_coverage is None or coverage == expected_coverage)
            and admission[0] == (1, coverage[0], coverage[1]),
            "VIEW retrieval signed/current Archive object differs")
    item[5] = 1; item[7] = hex_bytes(obj[3], 32); item[9] = obj[6]
    d = from_json(t.BUNDLE_DEPENDENCIES, dependencies)
    bundle_wire._admission(tuple(item), admission, evidence["sourceEvidence"], d, source[10], originals)
    raw_second = _raw(evidence["sourceEvidence"]["receipts"][1], 65536,
                      "VIEW retrieval second receipt byte bound")
    second_receipt, second_identifier, second_signature = decode(
        (bundle_wire.RECEIPT, "bytes", "bytes"), raw_second, maximum=65536)
    family = evidence["secondFamily"]
    require(type(family) is dict and set(family) == {"family", "status", "revision"},
            "VIEW retrieval second family shape")
    family_row = from_json(t.ARCHIVE_FAMILY, family["family"])
    status, revision = uint(family["status"], 8), uint(family["revision"], 64)
    require(status == 1 and revision > 0 and family_row[8] == 2
            and all(family_row[index] != ZERO for index in range(8))
            and family_row[9] == second_receipt[6]
            and family_row[10] == schema_id("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1")
            and coverage[8] == bundle_wire._domain("6529STREAM_EXTERNAL_ARCHIVE_FAMILY_V1",
                ("uint256", "address", t.ARCHIVE_FAMILY), (d[2], d[0][4], family_row))
            and (expected_writer is None or second_receipt[6] == expected_writer)
            and second_receipt[0] == coverage[1]
            and second_receipt[1] == coverage[8]
            and second_receipt[3] == schema_id("ATTESTED_POSSESSION")
            and second_receipt[4] == schema_id("STREAM_INSTITUTIONAL_EXTERNAL_OBJECT_POSSESSION_V1")
            and second_receipt[7] > 0
            and keccak256(second_identifier) == second_receipt[2],
            "VIEW retrieval current institutional Archive writer")
    archive = graph["externalCoverage"]["address"]
    _record_call(originals, archive, "coverage(bytes32)", ("bytes32",), (coverage[0],),
                 (t.ADMISSION[3],), (coverage,))
    _record_call(originals, archive, "objectIdentity(bytes32)", ("bytes32",), (coverage[1],),
                 (t.OBJECT,), (obj,))
    _record_call(originals, archive, "receipt(bytes32)", ("bytes32",), (coverage[10],),
                 (bundle_wire.RECEIPT, "bytes", "bytes"),
                 (second_receipt, second_identifier, second_signature))
    _record_call(originals, archive, "family(bytes32)", ("bytes32",), (coverage[8],),
                 (t.ARCHIVE_FAMILY, "uint8", "uint64"), (family_row, status, revision))
    _record_call(originals, archive,
                 "currentReceiptPair(bytes32,bytes32,bytes32,bytes32)",
                 ("bytes32",) * 4, (coverage[9], coverage[10], source[10], coverage[1]),
                 (t.CURRENT_PAIR,), (pair,))
    return obj, admission, second_receipt[7]


def _archive_current(current, observation, context, graph, dependencies, receipt,
                     witness, configuration, configuration_hash_, originals):
    require(type(current) is dict and set(current) == {"checkpointSource", "artistPresentation",
            "admission", "sourceEvidence", "currentPair", "secondFamily", "manifestEvidence"},
            "VIEW retrieval operative evidence shape")
    source, observed_object, observed_coverage = observation[:3]
    primary = {key: current[key] for key in
        ("admission", "sourceEvidence", "currentPair", "secondFamily")}
    obj, admission, archive_observed_at = _admit_current(
        primary, source, observed_object, observed_coverage, observation[5], context, graph,
        dependencies, originals)
    require(observation[6] >= archive_observed_at,
            "VIEW retrieval observation predates Archive receipt")
    manifests = current["manifestEvidence"]
    require(type(manifests) is list, "VIEW retrieval manifest evidence denominator")

    def admit_manifest(evidence, manifest_source):
        object_row, saved, _ = _admit_current(
            evidence, manifest_source, None, None, None, context, graph, dependencies, originals)
        return object_row, saved

    route_report = routes.validate(observation, configuration, admission,
        current["sourceEvidence"], manifests, originals, admit_manifest=admit_manifest)
    pair = from_json(t.CURRENT_PAIR, current["currentPair"])
    original = admission[1]
    transformed = _hash(("bytes32", "bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32"),
        (t.ADMITTED_BUNDLE_DOMAIN, original, witness["address"], witness["runtimeHash"],
         configuration_hash_, receipt[0], receipt[7]))
    pair_observation = _hash((t.CURRENT_PAIR,), (pair,))
    observation = _hash(("bytes32", t.SOURCE, t.RECEIPT, "bytes32"),
        (t.CURRENT_OBSERVATION_DOMAIN, source, receipt, pair_observation))
    return admission, transformed, observation, route_report


def validate(value, context, graph, inventory, source_proof):
    """Validate one closed retrieval history against existing raw preservation evidence."""
    try:
        return _validate(value, context, graph, inventory, source_proof)
    except MuseumError:
        raise
    except (KeyError, IndexError, TypeError, ValueError, OverflowError, UnicodeError) as exc:
        raise MuseumError("invalid VIEW attributed retrieval evidence") from exc


def _validate(value, context, graph, inventory, source_proof):
    require(type(value) is dict and set(value) == {"sourceRevision", "profile", "witness",
            "configuration", "configurationHash", "bundleDependencies", "records", "scopeEpochs",
            "itemBindings", "historyCoverage", "sourceBindings"},
            "VIEW retrieval closed evidence")
    require(value["sourceRevision"] == t.SOURCE_REVISION and value["profile"] == t.PROFILE,
            "VIEW retrieval frozen profile")
    require(type(source_proof) is dict and set(source_proof) == {"bundle", "events"},
            "VIEW retrieval preservation proof shape")
    native_graph = {key: graph[key] for key in preservation.GRAPH_KEYS}
    preserved = preservation.validate_bundle(source_proof["bundle"], context, native_graph)
    preservation.validate_event_join(source_proof["bundle"], context, native_graph, source_proof["events"])
    witness = value["witness"]
    require(type(witness) is dict and set(witness) == {"address", "runtimeHash", "interfaceId"}
            and witness["address"] != ZERO_ADDRESS and witness["runtimeHash"] != ZERO
            and witness["interfaceId"] == t.WITNESS_INTERFACE_ID,
            "VIEW retrieval witness identity")
    c = from_json(t.CONFIGURATION, value["configuration"])
    require(value["configurationHash"] == configuration_hash(c)
            and c[0] == context["core"] and c[1] == graph["core"]["runtimeHash"]
            and c[2] == graph["router"]["address"] and c[3] == graph["router"]["runtimeHash"]
            and c[4] == graph["checkpoint"]["address"] and c[5] == graph["checkpoint"]["runtimeHash"]
            and c[6] == graph["externalCoverage"]["address"] and c[7] == graph["externalCoverage"]["runtimeHash"]
            and c[8] == uint(context["chainId"]) and c[9] >= 50000 and c[10] >= c[9]
            and c[11] >= c[9] and c[12] >= 90000 and max(c[10:]) <= 16777216,
            "VIEW retrieval configuration")
    originals = bundle_wire._Originals(context, graph)
    originals.pin(witness["address"], witness["runtimeHash"])
    _source_pins(source_proof["bundle"], preserved, originals)
    from . import view_preservation_retrieval_inventory_v1 as retrieval_inventory
    _, inventory_result = retrieval_inventory.validate(
        inventory, context, graph, witness, c, originals=originals)
    _reference_source_pins(inventory["value"]["reference"], context, native_graph, originals)
    from . import view_preservation_inventory_sources_v1 as inventory_sources
    selected_reference = inventory_sources.selected(inventory["value"]["reference"])[0]
    selected_reference_result = preservation.validate_bundle(
        selected_reference["sourceProof"]["bundle"], context, native_graph)
    dependencies = _bundle_dependencies(value["bundleDependencies"], context, graph)
    selected_adoption_position = _selected_adoption_position(
        source_proof["bundle"], source_proof["events"], context, native_graph,
        from_json(adoption_types.RECORD, preserved["adoption"]["record"])[10])
    history = value["historyCoverage"]
    require(type(history) is dict and set(history) == {"retainedRecordCount",
            "retainedRevocationCount", "eventHistoryCompleteness"}
            and history["eventHistoryCompleteness"] == "bounded_retained_rows",
            "VIEW retrieval bounded history description")
    require(type(value["records"]) is list and 0 < len(value["records"]) <= 4096,
            "VIEW retrieval record bound")
    records, revoked_counts, operative, nonce_keys, retrieval_events = {}, {}, {}, set(), []
    for row in value["records"]:
        require(type(row) is dict and set(row) == {"recordHash", "receipt", "payloadHex",
                "publication", "revocation", "current", "status", "nativeState"},
                "VIEW retrieval record shape")
        raw = _raw(row["payloadHex"], t.MAX_BYTES, "VIEW retrieval payload byte bound")
        observation, signature = decode((t.OBSERVATION, "bytes"), raw, maximum=t.MAX_BYTES)
        require(len(signature) <= t.MAX_SIGNATURE and encode((t.OBSERVATION, "bytes"),
                (observation, signature)) == raw, "VIEW retrieval canonical payload")
        observation = _shape(observation); receipt = from_json(t.RECEIPT, row["receipt"])
        require(row["recordHash"] not in records and receipt[0] == row["recordHash"]
                and receipt[0] == record_hash(c, witness["address"], receipt)
                and receipt[1] == source_key(observation[0])
                and receipt[2] == observation_hash(c, witness["address"], observation)
                and receipt[3:5] == (observation[2][1], observation[2][0])
                and receipt[5] == observation[5] and receipt[7] == keccak256(raw)
                and receipt[8] == len(raw) and observation[6] <= receipt[6] <= observation[8],
                "VIEW retrieval receipt preimage")
        _event(row["publication"], _publication(witness["address"], receipt), "VIEW retrieval publication")
        require(uint(row["publication"]["timestamp"], 64) == receipt[6]
                and receipt[6] <= uint(context["timestamp"], 64)
                and reference_wire._position(row["publication"])[0] <= uint(context["blockNumber"], 64),
                "VIEW retrieval publication time")
        state = row["nativeState"]
        require(type(state) is dict and set(state) == {"revoked", "nonceUsed"}
                and state["nonceUsed"] is True, "VIEW retrieval native record state")
        nkey = nonce_key(observation[5], observation[7])
        require(nkey not in nonce_keys, "VIEW retrieval duplicate writer nonce")
        nonce_keys.add(nkey)
        _record_call(originals, witness["address"], "record(bytes32)", ("bytes32",),
                     (receipt[0],), (t.RECEIPT,), (receipt,))
        _record_call(originals, witness["address"], "encoded(bytes32)", ("bytes32",),
                     (receipt[0],), ("bytes",), (raw,))
        _record_call(originals, witness["address"], "revoked(bytes32)", ("bytes32",),
                     (receipt[0],), ("bool",), (state["revoked"],))
        _record_call(originals, witness["address"], "nonceUsed(bytes32)", ("bytes32",),
                     (nkey,), ("bool",), (True,))
        key = scope_key(observation[0][0]); records[receipt[0]] = (observation, receipt)
        retrieval_events.append(row["publication"])
        if row["revocation"] is not None:
            rev = row["revocation"]
            require(type(rev) is dict and set(rev) == {"reasonHash", "event"}
                    and rev["reasonHash"] != ZERO, "VIEW retrieval revocation shape")
            _event(rev["event"], _revocation(witness["address"], receipt, rev["reasonHash"]),
                   "VIEW retrieval revocation")
            require(row["status"] == "revoked" and state["revoked"] is True
                    and row["current"] is None
                    and reference_wire._position(row["publication"]) < reference_wire._position(rev["event"])
                    and uint(rev["event"]["timestamp"], 64) <= uint(context["timestamp"], 64)
                    and reference_wire._position(rev["event"])[0] <= uint(context["blockNumber"], 64),
                    "VIEW retrieval revoked operative record")
            revoked_counts[key] = revoked_counts.get(key, 0) + 1
            retrieval_events.append(rev["event"])
        elif row["status"] == "retained_history":
            require(state["revoked"] is False and row["current"] is None,
                    "VIEW retrieval retained history record")
        else:
            require(row["status"] == "operative" and state["revoked"] is False
                    and row["current"] is not None
                    and selected_reference_result["adoption"]["selectedIsCurrentHead"] is True,
                    "VIEW retrieval current evidence missing")
            expected_source, artist, adopted_at, checkpoint = _expected_source(
                source_proof["bundle"], preserved, row["current"])
            require(observation[0] == expected_source and observation[6] >= adopted_at
                    and selected_adoption_position < reference_wire._position(row["publication"]),
                    "VIEW retrieval current source projection")
            _record_call(originals, c[4], "currentSource((uint8,uint256,uint256,bytes32))",
                         (t.SCOPE,), (observation[0][0],), (output_types.SOURCE,), (checkpoint,))
            _record_call(originals, c[2], "artistPresentation(uint256)", ("uint256",),
                         (observation[0][0][1],), (t.ARTIST_PRESENTATION,), (artist,))
            admission, transformed, current_observation, route_report = _archive_current(
                row["current"], observation, context, graph, dependencies, receipt, witness, c,
                value["configurationHash"], originals)
            _record_call(originals, witness["address"], "requireCorrespondence(bytes32)",
                         ("bytes32",), (receipt[0],), (t.SOURCE, t.RECEIPT, t.ADMISSION),
                         (observation[0], receipt, admission))
            operative[receipt[0]] = {"source": observation[0], "receipt": receipt,
                "admission": admission, "transformed": transformed,
                "currentObservation": current_observation, "route": route_report}
    require(history["retainedRecordCount"] == len(records)
            and history["retainedRevocationCount"] == sum(revoked_counts.values()),
            "VIEW retrieval retained event denominator")
    reference_wire._event_coherence(
        [*source_proof["events"], *_inventory_events(inventory), *retrieval_events], context)
    supplied_epochs = {}
    for row in value["scopeEpochs"]:
        require(type(row) is dict and set(row) == {"scope", "epoch"}, "VIEW retrieval epoch shape")
        key = scope_key(row["scope"]); require(key not in supplied_epochs, "VIEW retrieval duplicate epoch")
        supplied_epochs[key] = uint(row["epoch"], 64)
        _record_call(originals, witness["address"],
            "revocationEpoch((uint8,uint256,uint256,bytes32))", (t.SCOPE,),
            (from_json(t.SCOPE, row["scope"]),), ("uint64",), (supplied_epochs[key],))
    record_scopes = {scope_key(observation[0][0]) for observation, _ in records.values()}
    require(set(supplied_epochs) == record_scopes
            and all(supplied_epochs[key] >= revoked_counts.get(key, 0) for key in record_scopes),
            "VIEW retrieval admitted scope epochs")
    require(type(value["itemBindings"]) is list and value["itemBindings"],
            "VIEW retrieval item binding denominator")
    bindings, binding_coordinates, bound_records = [], set(), set()
    for row in value["itemBindings"]:
        require(row["witnessRecordHash"] in operative, "VIEW retrieval item witness current")
        current = operative[row["witnessRecordHash"]]
        epoch = supplied_epochs[scope_key(current["source"][0])]
        binding = retrieval_inventory.validate_item_binding(
            row, inventory_result, context, graph, witness, c, current, epoch, originals=originals)
        coordinate = (binding["planId"], binding["index"])
        require(coordinate not in binding_coordinates, "VIEW retrieval duplicate item coordinate")
        binding_coordinates.add(coordinate); bound_records.add(row["witnessRecordHash"])
        bindings.append(binding)
    require(bound_records == set(operative), "VIEW retrieval operative record binding denominator")
    source_bindings = value["sourceBindings"]
    require(type(source_bindings) is dict and set(source_bindings) == {"blockHash", "provenance", "calls"}
            and source_bindings["blockHash"] == context["blockHash"]
            and source_bindings["provenance"] == inventory_result["provenance"]
            and source_bindings["calls"] == originals.calls,
            "VIEW retrieval exact shared source read map")
    return json_values({"sourceRevision": t.SOURCE_REVISION, "profile": t.PROFILE,
        "configurationHash": value["configurationHash"], "recordCount": len(records),
        "operativeRecordCount": len(operative), "revocationCount": sum(revoked_counts.values()),
        "inventorySummary": {"scope": inventory_result["scope"],
            "planId": inventory_result["planId"],
            "dependencyHash": inventory_result["dependencyHash"],
            "itemCount": len(inventory_result["items"]),
            "segmentCount": len(inventory_result["segments"]),
            "provenance": inventory_result["provenance"]},
        "bindings": bindings,
        "resolvedAdmissions": [{"recordHash": key, "admission": row["admission"],
            "currentObservation": row["currentObservation"], "route": row["route"]}
            for key, row in operative.items()],
        "expectedCalls": originals.calls, "claims": CLAIMS, "qualification": QUALIFICATION})
