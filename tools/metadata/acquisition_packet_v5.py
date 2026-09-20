"""Full supplied-data acquisition packet V5 with native personhood and DIRECT context."""
import argparse
import copy

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import acquisition_packet_v4 as v4
from . import acquisition_personhood_v1 as personhood
from . import acquisition_direct_floor_v1 as direct
from . import acquisition_conservation_context_v1 as context
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from tools.museum.chain_abi import encode

v1, v2 = v4.v1, v4.v2
ROOT, ZERO, ZERO_ADDRESS = v4.ROOT, v4.ZERO, v4.ZERO_ADDRESS
MAX_BYTES = 32 * 1024 * 1024
PACKET = "STREAM_ACQUISITION_PACKET_V5"
RIGHTS_SNAPSHOT_URI = "direct-conservation/direct-assembly/provider-binding/rights-assembly/captures/rights/source/snapshot.json"
QUALIFICATION = ("Prospective unregistered full-shaped supplied-data acquisition packet V5. All nineteen field "
    "groups remain required. Native personhood and floor-independent conservation context are retained as whole "
    "standalone fragments alongside original DIRECT floor evidence. Internal hashes, authority domains, source "
    "contexts, supplied heads and chronology are checked. Source references and supplied denominators do not "
    "authenticate themselves. No capture replay, cryptographic authority verification, runtime admission, factual "
    "personhood, complete source coverage or acquisition acceptance is implied. Current observations never "
    "replace historical paid evidence. Frozen packet versions V1–V4 remain unchanged.")
RULES = [
    "Packet version is numeric5. All nineteen original required groups remain; native General authority is never converted to legacy numeric authorityClass.",
    "Personhood is the exact standalone native fragment. Conservation is exactly native_direct_conservation with whole context and floor fragments; universal and mixed target floors are unsupported.",
    "Common source identity, block and time agree. Current Artist identity/generation and eligible conservation associations agree; historical original authorities and paid documentary facts remain distinct.",
    "Selected Metadata originals require matching supplied collection/type heads. Index-zero and consecutive supplied records reconstruct native chain steps; gaps remain explicit unknown predecessors. General permits a foreign collection only for the exact original native notarization host/type/CID, and requires its own supplied head with count at least the retained matching-event count. These are supplied denominator joins, not source completeness proofs.",
    "Legacy aliases of a retained native Metadata original preserve its actual recorder, Metadata authority class, schema/type, subject and publication block; Artist op24 signer authority remains separate. Native General cannot be relabeled as legacy authority.",
    "Observed native publication coordinates, timestamps and current runtime commitments reconcile across fragments and native owner references. Exact repeated events are permitted; contradictory block, transaction and log observations fail.",
    "Original target token identity, serial and burn state match DIRECT observations. The supplied mint transfer precedes paid publication; when it is the first completed mint, its exact identity and coordinates agree with the tier fragment.",
    "Historical FIRST/RELEASE/DIRECT tiers follow declarations preceding each receipt; later current observations do not rewrite historical evidence. All other V4 packet relationships remain version-local checks.",
    "Only rights.selectionEvidence may use the exact retained package snapshot URI; its original HashRef rules and every other original URI rule remain unchanged.",
]


def _embed(module, prefix):
    definitions = copy.deepcopy(module.definitions())
    def rewrite(node):
        if isinstance(node, dict):
            return {key: "#/$defs/" + prefix + child.split("/")[-1] if key == "$ref" else rewrite(child)
                for key, child in node.items()}
        elif isinstance(node, list):
            return [rewrite(child) for child in node]
        return node
    definitions = rewrite(definitions)
    return {prefix + key: value for key, value in definitions.items()}


def definitions():
    d = copy.deepcopy(v4.definitions())
    d.update(_embed(personhood, "personhood__")); d.update(_embed(context, "context__")); d.update(_embed(direct, "direct__"))
    d["packet"]["properties"]["schema"] = {"const": PACKET}
    d["packet"]["properties"]["version"] = {"const": 5}
    d["attribution"]["properties"]["personhood"] = v1.ref("personhood__fragment")
    d["conservation"] = v1.closed({"kind": {"const": "native_direct_conservation"},
        "context": v1.ref("context__context"), "floor": v1.ref("direct__fragment")})
    selected, pending = {}, ["packet"]
    while pending:
        key = pending.pop()
        if key in selected: continue
        selected[key] = d[key]
        pending.extend(row["$ref"].split("/")[-1] for row in v1._walk(d[key]) if "$ref" in row)
    return selected


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + PACKET,
        "title": PACKET, "description": QUALIFICATION, **v1.ref("packet"), "$defs": definitions(),
        "x-stream-native-fragments": {m.NAME: m.SCHEMA_HASH for m in (personhood, context, direct)},
        "x-stream-constraints": RULES})


PACKET_SCHEMA_BYTES = schema_document_bytes()
PACKET_SCHEMA_HASH = keccak256(PACKET_SCHEMA_BYTES)


def _typed(value, schema, definitions):
    if "$ref" in schema: return _typed(value, definitions[schema["$ref"].split("/")[-1]], definitions)
    alternatives = schema.get("oneOf", schema.get("anyOf"))
    if alternatives:
        selected = [s for s in alternatives if Draft202012Validator({"$defs": definitions, **s}).is_valid(value)]
        for branch in selected: _typed(value, branch, definitions)
        return
    if "x-stream-uint-bits" in schema: uint(value, schema["x-stream-uint-bits"])
    if "x-stream-max-utf8-bytes" in schema:
        v1.need(len(value.encode("utf-8")) <= schema["x-stream-max-utf8-bytes"], "UTF-8 byte limit")
    if isinstance(value, dict):
        for key, child in value.items(): _typed(child, schema.get("properties", {}).get(key, {}), definitions)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            shape = schema["prefixItems"][index] if "prefixItems" in schema else schema.get("items", {})
            _typed(child, shape, definitions)


def _general_head(value):
    p = value["attribution"]["personhood"]
    if p["general"] is None: return None
    g = p["general"]
    return ("general", p["original"]["summary"][9][5], g["attestation"][1], g["attestation"][3])


def _personhood(value):
    a, state = value["attribution"], value["sourceState"]
    p = personhood.validate(dumps(a["personhood"])); current = p["current"]
    v1.need(all(p["sourceState"][key] == state[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber")),
        "V5 personhood source differs")
    v1.need((a["artistId"] or ZERO) == current["artistId"] and a["bindingGeneration"] == current["binding"][4],
        "V5 current Artist identity/generation differs")
    if a["state"] in ("artist_accepted", "artist_sanctioned"):
        v1.need(current["binding"][9], "V5 accepted Artist binding inactive")
    key = _general_head(value)
    if key is not None:
        matches = [h for h in value["recordChainHeads"] if v1._head_key(h) == key]
        v1.need(len(matches) == 1, "V5 native General matching head missing")
        receipt = p["general"]["authority"]["receipt"]; index, count = uint(receipt[4]), uint(matches[0]["count"])
        v1.need(index < count and count >= uint(p["general"]["recorderHistory"]["eventCount"])
            and (index + 1 != count or receipt[5] == matches[0]["headHash"]), "V5 native General head/count differs")
        if index == 0:
            v1.need(receipt[5] == v1._chain_step(state, matches[0], ZERO, p["general"]["recordHash"], 0), "V5 native General initial chain differs")
        for legacy in v1._records_in(value):
            v1.need((legacy["host"], legacy["recordHash"]) != (key[1], p["general"]["recordHash"]),
                "V5 native General cannot be relabeled as legacy authority")


def _metadata_chains(records, source):
    lanes = {}
    for row in records:
        original, evidence = row["original"], row["evidence"]
        key = ("metadata", original["host"], source["collectionId"], original["recordType"])
        lanes.setdefault(key, {})[uint(evidence["recordIndex"])] = evidence
    for key, slots in lanes.items():
        head = dict(zip(("lane", "host", "scopeKey", "recordType"), key))
        for index, evidence in sorted(slots.items()):
            if index == 0 or index - 1 in slots:
                previous = ZERO if index == 0 else slots[index - 1]["recordChainHash"]
                v1.need(evidence["recordChainHash"] == v1._chain_step(source, head, previous, evidence["recordHash"], index),
                    "V5 native Metadata supplied chain step differs")


def _metadata_aliases(packet, records, source):
    native = {(row["original"]["host"], row["evidence"]["recordHash"]): row for row in records}
    for alias in v1._records_in(packet):
        key = alias["host"], alias["recordHash"]
        if key not in native: continue
        original, evidence = native[key]["original"], native[key]["evidence"]
        kind = "token" if original["subjectId"] == source["subjectId"] else "collection"
        expected = {"recordHash": evidence["recordHash"], "host": original["host"], "subjectId": original["subjectId"],
            "subjectKind": kind, "recordType": original["recordType"], "schemaId": original["schemaId"],
            "signer": evidence["recorder"], "authorityClass": original["metadataAuthorityClass"],
            "recordedBlock": original["publication"]["blockNumber"]}
        v1.need(alias == expected, "V5 native Metadata legacy alias differs")


def _personhood_observations(p, obs, runtime):
    original, g = p["original"], p["general"]
    if original is None: return
    if original["publication"] is not None:
        obs.add(original["publication"], None, ("op24", p["sourceBindings"]["originalAttribution"], original["recordHash"]))
    stored = original["summaryCarriers"] + ([] if original["statementRetention"] is None else [original["statementRetention"]])
    for row in stored:
        obs.add(row["publication"], None, ("stored", row["owner"], row["pointer"], row["payloadType"], row["payloadHash"], row["index"]))
    for row in original["summaryRetentions"]:
        obs.add(row["publication"], None, ("summary", row["owner"], original["recordHash"], original["summaryHash"]))
    retained = original["statementRetention"]
    if retained: runtime(retained["pointer"], keccak256(b"\0" + hex_bytes(original["statementHex"])))
    if g is None: return
    s = original["summary"]; ref = s[9]
    obs.add(g["publication"], g["authority"]["receipt"][3], ("general", ref[5], g["recordHash"]))
    for address, digest in ((ref[2], s[10]), (ref[5], ref[6]), (s[11], s[12]), (s[13], s[14]), (s[15], s[16]), (s[17], s[18])):
        runtime(address, digest)
    for row in g["carriers"]: runtime(row["address"], row["runtimeHash"])
    native_summary = personhood.native(personhood.proof.SUMMARY, s)
    digest = keccak256(b"\0" + encode(("bytes32", personhood.proof.SUMMARY), (personhood.proof.SUMMARY_TAG, native_summary)))
    for row in original["summaryCarriers"]: runtime(row["pointer"], digest)


def _conservation(c, source, packet):
    ctx = context.validate(dumps(c["context"])); floor = direct.validate(dumps(c["floor"]))
    p = packet["attribution"]["personhood"]
    v1.need(ctx["sourceState"] == source, "V5 conservation context source differs")
    v1.need(all(floor["sourceState"][key] == source[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber"))
        and floor["sourceState"]["timestamp"] == ctx["sourceBlockTimestamp"] == p["sourceState"]["timestamp"]
        and floor["sourceState"]["environment"] == p["sourceState"]["environment"], "V5 native source contexts differ")
    obs = v4._Observations(source, ctx["sourceBlockTimestamp"])
    v4._tier(ctx, source, obs); records = v4._scopes(ctx, source, obs)
    v4._record_lanes(records, source, packet["recordChainHeads"])
    _metadata_chains(records, source)
    _metadata_aliases(packet, records, source)
    codes = {}
    def runtime(address, digest):
        v1.need(codes.setdefault(address, digest) == digest, "V5 supplied runtime commitments differ")
    runtime(source["core"], ctx["coreRuntimeHash"])
    class Joined(direct.Observations):
        def runtime(self, address, digest):
            super().runtime(address, digest); runtime(address, digest)
        def event(self, row, identity, timestamp=None):
            super().event(row, identity, timestamp); obs.add(row, None if timestamp is None else str(timestamp), identity)
    joined = Joined(floor["sourceState"])
    direct._catalogue(floor, joined); direct._ledger(floor, joined); direct._first_release(floor, joined)
    for row in floor["floor"]["directSales"]: direct._direct(row, joined)
    joined.finish()
    _personhood_observations(p, obs, runtime)
    for scope in ctx["scopes"].values():
        for origin in ("artist", "estate"):
            lane = scope[origin]
            if lane["status"] == "selected" and lane["selection"]["currentEligibility"]["eligible"]:
                association = lane["selection"]["association"]; binding = p["current"]["binding"]
                v1.need(association["artistId"] == p["current"]["artistId"] and association["bindingHash"] == binding[3]
                    and association["generation"] == binding[4] and association["identityRecordHash"] == p["current"]["registrationIdentityRecordHash"],
                    "V5 eligible selection/current Artist differs")
    declaration = ctx["tier"]["declaration"]
    rows = ([floor["floor"]["firstSale"]] if floor["floor"]["firstSale"] else []) + floor["floor"]["releases"] + floor["floor"]["directSales"]
    for row in rows:
        expected = declaration["tier"] if declaration and v4._pos(declaration["publication"]) < v4._pos(row["publication"]) else "MUSEUM_GRADE_LITE"
        v1.need(row["effectiveTier"] == expected, "V5 historical DIRECT tier differs")
    targets = [row for row in floor["floor"]["directSales"] if row["tokenId"] == source["tokenId"]]
    v1.need(len(targets) == 1, "V5 target DIRECT paid receipt missing/ambiguous")
    target = targets[0]; identity = target["originalSale"]["tokenIdentity"]
    v1.need(all(identity[key] == source[key] for key in ("collectionId", "collectionSerial", "burned"))
        and identity["lifecycle"] == ("3" if source["burned"] else "2"), "V5 DIRECT target identity differs")
    transfer = packet["ownershipProvenance"]["transfers"][0]
    v1.need(tuple(uint(transfer[k]) for k in ("blockNumber", "logIndex")) < tuple(uint(target["publication"][k]) for k in ("blockNumber", "logIndex")),
        "V5 completed mint must precede DIRECT paid receipt")
    _packet_observations(packet, source, obs, ctx)
    obs.finish()


def _packet_observations(packet, source, obs, ctx):
    owner_keys = set(v2.definitions()["nativeOwnerRecord"]["properties"])
    for record in v1._walk(packet):
        if set(record) != owner_keys: continue
        authority = record["authority"]; state = authority["ownerState"]; transfer = state["transfer"]
        v1.need(state["sourceBlockTimestamp"] == ctx["sourceBlockTimestamp"], "native owner/V5 source timestamp differs")
        obs.add(authority["publication"], authority["receipt"]["recordedAt"], ("owner", record["host"], record["recordHash"]))
        obs.add(transfer, None, ("transfer", transfer["from"], transfer["to"], source["tokenId"]))
    for transfer in packet["ownershipProvenance"]["transfers"]:
        n, tx, index = uint(transfer["blockNumber"]), transfer["transactionHash"], uint(transfer["logIndex"])
        h = obs.numbers.get(n)
        if tx in obs.txs: v1.need(obs.hashes[obs.txs[tx][0]] == n, "native transfer transaction block differs")
        if h is not None and (h, index) in obs.logs:
            v1.need(obs.logs[h, index] == (tx, ("transfer", transfer["from"], transfer["to"], source["tokenId"])), "native transfer occupied event slot differs")
    mint = ctx["tier"]["firstCompletedMint"]
    if mint["tokenId"] == source["tokenId"]:
        transfer = packet["ownershipProvenance"]["transfers"][0]
        v1.need(transfer["from"] == ZERO_ADDRESS and transfer["to"] == mint["recipient"]
            and all(transfer[k] == mint["publication"][k] for k in ("blockNumber", "transactionHash", "logIndex")), "native first mint/ownership history differs")


def _curated(curated, conservation):
    v1.need(v1._kind(curated["attestation"], "INSTITUTIONAL_VERIFICATION", "INDEPENDENT_CONDITION"), "curated attestation type")
    matches = []
    for scope in conservation["context"]["scopes"].values():
        lane = scope["artist"]
        if lane["status"] != "selected": continue
        selected = lane["selection"]; record = selected["record"]
        if record["evidence"]["recordHash"] == curated["artistIntentRecordHash"]:
            v1.need(record["evidence"]["recordKind"] == "0" and selected["currentEligibility"]["eligible"], "curated native intent must be eligible Artist intent")
            matches.append(record)
    v1.need(matches and all(row == matches[0] for row in matches), "curated exact native Artist intent missing/ambiguous")


def validate(raw):
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(PACKET_SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value); _typed(value, v1.ref("packet"), schema["$defs"])
        # Native fragments own their exact reference vocabularies and URI bounds.
        old_fields = {k: v for k, v in value.items() if k not in ("conservation", "attribution")}
        old_fields["attribution"] = {k: v for k, v in value["attribution"].items() if k != "personhood"}
        if value["rights"]["selectionEvidence"]["uri"] == RIGHTS_SNAPSHOT_URI:
            old_fields["rights"] = {k: v for k, v in value["rights"].items() if k != "selectionEvidence"}
            v1._references(value["rights"]["selectionEvidence"]["hash"])
        v1._references(old_fields)
        _packet(value)
        v2._record_context(value, value["sourceState"], value["ownershipProvenance"], value["recordChainHeads"])
        for binding in value["ownershipProvenance"]["titleBindings"]:
            if "authority" in binding["record"]:
                hop = value["ownershipProvenance"]["transfers"][uint(binding["transferIndex"])]
                v1.need(v2._before(hop, binding["record"]["authority"]["publication"]), "native owner title transfer must precede publication")
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied acquisition packet V5") from exc


def documents(): return {PACKET: PACKET_SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: v1.need(destination.is_file() and destination.read_bytes() == raw, "generated V5 bytes differ")
        else: destination.write_bytes(raw)
    print("V5 supplied packet definition matches; complete source coverage is not established.")


# Version-local all-nineteen-group joins; original V4 is unchanged.
need, _kind, _sorted_unique = v1.need, v1._kind, v1._sorted_unique
_head_key, _record_context, _entropy_hash = v1._head_key, v1._record_context, v1._entropy_hash
USES = v1.USES

def _packet(value):
    s = value["sourceState"]
    need(all(uint(s[k]) > 0 for k in ("chainId", "collectionId", "tokenId", "collectionSerial")), "nonzero source identity")
    token = subject_id("token", s["chainId"], s["core"], s["collectionId"], token_id=s["tokenId"])
    collection = subject_id("collection", s["chainId"], s["core"], s["collectionId"])
    need(s["subjectId"] == value["subjectId"] == value["contentRootProof"]["subjectId"] == token, "token subject join")
    need(s["collectionSubjectId"] == collection, "collection subject join")
    need(value["erc721Identity"] == {"core": s["core"], "collectionId": s["collectionId"], "globalTokenId": s["tokenId"],
        "catalogNumber": s["tokenId"], "collectionSerial": s["collectionSerial"]}, "sole ERC721 identity join")
    citation = value["citation"]
    base = f"eip155:{s['chainId']}/erc721:{s['core']}/{s['tokenId']}"
    need(citation["work"] == base and citation["qualified"] == base + "@" + citation["qualifier"]["kind"] + ":" + citation["qualifier"]["hash"], "canonical citation join")
    if citation["qualifier"]["kind"] == "fin":
        need(value["finality"]["status"] == "finalized" and citation["qualifier"]["hash"] == value["finality"]["record"]["recordHash"], "finality citation join")
    snapshot = value["snapshotCommitment"]
    if snapshot is not None:
        need(snapshot["collectionId"] == s["collectionId"] and uint(snapshot["revision"]) > 0
            and uint(snapshot["recordedBlock"]) <= uint(s["blockNumber"])
            and snapshot["manifest"]["hash"]["algorithm"] == 1, "snapshot commitment context")
    if citation["qualifier"]["kind"] == "snap":
        need(snapshot is not None and citation["qualifier"]["hash"] == snapshot["manifest"]["hash"]["digest"], "snapshot citation join")
    heads = value["recordChainHeads"]
    _sorted_unique(heads, _head_key, "record heads")
    for head in heads:
        need((head["count"] == "0") == (head["headHash"] == ZERO), "empty head/count join")
        expected_scopes = (s["tokenId"],) if head["lane"] == "owner" else (
            ("0", s["collectionId"]) if head["lane"] == "independent" else (s["collectionId"],))
        exact_general = _general_head(value)
        need(head["scopeKey"] in expected_scopes or (exact_general is not None and _head_key(head) == exact_general), "native lane scope key")
    if citation["qualifier"]["kind"] == "chain":
        need(citation["qualifier"]["hash"] in {h["headHash"] for h in heads}, "chain citation join")
    _record_context(value, s)
    entropy = value["entropy"]; leaf = entropy["leaf"]
    need(leaf["tokenId"] == s["tokenId"] and entropy["leafHash"] == _entropy_hash(leaf), "pinned entropy leaf preimage")
    _sorted_unique(entropy["events"], lambda e: (uint(e["blockNumber"]), uint(e["logIndex"])), "entropy events")
    for event in entropy["events"]:
        need(event["tokenId"] == s["tokenId"] and event["emitter"] == leaf["coordinatorAtMint"]
            and uint(event["blockNumber"]) <= uint(s["blockNumber"]), "entropy event source join")
    if leaf["status"] == "5":
        events = [e["event"] for e in entropy["events"]]
        need(len(events) >= 2 and events[-1] == "EntropyFinalized"
            and all(event == "EntropyRequested" for event in events[:-1]), "finalized entropy event sequence")
    a = value["attribution"]
    observation = a["attestation"]
    code = int(observation["nativeStatus"])
    need(observation["statusLabel"] == ("NONE", "CURRENT", "STALE", "DISPUTED")[code], "native attestation status label")
    need(observation["collectionId"] == s["collectionId"] and observation["observedBlock"] == s["blockNumber"]
        and observation["observedBlockHash"] == s["blockHash"], "native attestation observation context")
    if code == 0:
        need(observation["attestationRecordHash"] == observation["attestedSubjectStateHash"] == ZERO
            and observation["authorityClass"] == observation["signedAt"] == "0", "native absent attestation tuple")
    else:
        need(observation["attestationRecordHash"] != ZERO, "native attestation original record")
        need((code == 3) == (a["state"] == "disputed"), "native disputed attribution/status join")
        if code == 1:
            need(a["state"] in ("artist_accepted", "artist_sanctioned")
                and (observation["subjectKind"] == "8"
                    or observation["attestedSubjectStateHash"] == observation["currentSubjectStateHash"]),
                "native current attestation state join")
        # STALE under an accepted binding can reflect an older generation;
        # omitted original-generation evidence is not inferred here.
    need((a["artistId"] is None) == (a["state"] == "platform_works"), "artist identity/state join")
    if a["state"] in ("artist_accepted", "artist_sanctioned"):
        need(a["binding"]["status"] == "present" and uint(a["bindingGeneration"]) > 0, "accepted binding evidence")
    if a["state"] == "artist_sanctioned": need(a["sanction"]["status"] == "present", "sanction evidence")
    _personhood(value)
    rights = value["rights"]
    for scope in ("collection", "token"):
        item = rights[scope]
        if item is not None:
            need(item["record"]["subjectKind"] == scope and _kind(item["record"], "RIGHTS_STATEMENT")
                and item["record"]["schemaId"] == keccak256(b"STREAM_RIGHTS_V1"), "rights scope/schema")
    selected = rights["token"] or rights["collection"]
    effective = selected["grants"] if selected is not None else {k: "unspecified" for k in USES}
    count = sum(status != "unspecified" for status in effective.values())
    status = "absent" if selected is None else "specified" if count == len(USES) else "unspecified" if count == 0 else "partially_specified"
    need(rights["effectiveGrants"] == effective and rights["completeness"] == status, "rights precedence/completeness")
    preservation = value["preservation"]; mode = value["metadataMode"]; script = value["workClass"] == "script"
    expected = {"ONCHAIN": ("onchain_bound",), "HYBRID": ("onchain_bound",),
        "OFFCHAIN_HASH_BOUND": ("covered", "uncovered_within_window", "uncovered_overdue"), "SERVICE_BACKED": ("service_backed_mutable",)}[mode]
    need(preservation["coverage"] in expected, "mode-total preservation coverage")
    need(mode not in ("ONCHAIN", "HYBRID") or script, "onchain/hybrid script preservation lane")
    need((preservation["scriptCoverage"]["status"] != "not_applicable") == script, "script coverage applicability")
    if preservation["coverage"] == "covered": need(preservation["fixityCycle"]["status"] == "recorded", "covered requires cycle")
    if preservation["scriptCoverage"]["status"] == "covered":
        need(preservation["scriptCoverage"]["captureSet"] is not None and preservation["scriptCoverage"]["environment"] is not None, "covered script evidence")
    _sorted_unique(preservation["masters"], lambda m: m["mediaClass"], "master slots")
    ownership = value["ownershipProvenance"]
    need(ownership["core"] == s["core"] and ownership["tokenId"] == s["tokenId"], "ownership identity")
    previous = ZERO_ADDRESS; last_order = (-1, -1)
    for i, hop in enumerate(ownership["transfers"]):
        order = (uint(hop["blockNumber"]), uint(hop["logIndex"]))
        need(hop["from"] == previous and (i == 0 or previous != ZERO_ADDRESS)
            and order > last_order and order[0] <= uint(s["blockNumber"]), "mint-to-source transfer continuity")
        need(i != 0 or hop["to"] != ZERO_ADDRESS, "mint initial holder")
        previous = hop["to"]; last_order = order
    need(ownership["currentOwner"] == previous and s["burned"] == (previous == ZERO_ADDRESS), "current owner/burn join")
    for binding in ownership["titleBindings"]:
        index = uint(binding["transferIndex"])
        need(index < len(ownership["transfers"]), "title hop index")
        hop = ownership["transfers"][index]
        need(all(binding[k] == hop[k] for k in ("from", "to", "transactionHash"))
            and _kind(binding["record"], "ACCESSION", "DEACCESSION"), "title transfer join")
    drill = value["scriptDrill"]
    need((drill["status"] != "not_applicable") == script, "script drill applicability")
    if drill["status"] == "recorded":
        need(drill["outcome"] != "TOLERABLE_VARIANCE" or drill["acceptanceMode"] != "BYTE_EXACT", "drill acceptance mode")
        need((drill["curatedEvidence"] is not None) == (drill["acceptanceMode"] == "CURATED_EQUIVALENCE"), "curated evidence applicability")
        if drill["curatedEvidence"] is not None:
            curated = drill["curatedEvidence"]
            _curated(curated, value["conservation"])
    _conservation(value["conservation"], s, value)
    if value["legalInstrument"]["status"] == "recorded": need(_kind(value["legalInstrument"]["accession"], "ACCESSION"), "accession instrument")
    if value["tombstone"]["status"] == "present":
        need(value["tombstone"]["record"]["schemaId"] == keccak256(b"STREAM_WORK_DESCRIPTION_V1"), "tombstone schema")
    if value["c2pa"]["status"] == "present":
        c2pa = value["c2pa"]
        need(_kind(c2pa["record"], "C2PA_REFERENCE"), "C2PA record type")
        if c2pa["assetHash"] != c2pa["committedMediaHash"]:
            need(c2pa["validationStatus"] == keccak256(b"INVALID"), "C2PA mismatched media must be INVALID")
    for lane, expected_type in (("owner", "CONDITION_REPORT"), ("independent", "INDEPENDENT_CONDITION")):
        condition = value["conditionReports"][lane]
        if condition["status"] == "present": need(_kind(condition["record"], expected_type), "condition lane/type")
    if value["recoveryLineage"]["status"] == "present":
        rows = value["recoveryLineage"]["lineage"]
        need(len({r["recoveryId"] for r in rows}) == len(rows), "duplicate recovery")
        for recovery in rows:
            for response in recovery["responses"]:
                need(_kind(response["record"], "RECOVERY_RESPONSE") and response["recoveryId"] == recovery["recoveryId"]
                    and recovery["manifest"]["hash"]["algorithm"] == 1
                    and response["manifestHash"] == recovery["manifest"]["hash"]["digest"], "recovery response join")
    sustain = value["platformSustainability"]
    expected_status = "meets_floor" if uint(sustain["coverageHorizonSeconds"]) >= uint(sustain["viabilityFloorSeconds"]) else "below_floor"
    need(sustain["horizonStatus"] == expected_status, "funding horizon")
    export = sustain["stateExport"]
    need(uint(export["exportedAt"]) <= uint(s["examinedAt"])
        and uint(export["ageSeconds"]) == uint(s["examinedAt"]) - uint(export["exportedAt"]), "state export age")




if __name__ == "__main__": main()
