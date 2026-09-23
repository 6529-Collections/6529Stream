"""Additive supplied-data V9: original scoped factory-policy V2 finality and token proof."""
import argparse
import copy

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import acquisition_packet_v5 as v5
from . import acquisition_scoped_policy_finality_v2 as finality
from . import acquisition_packet_v8 as v8
from tools.museum.canonical import MuseumError, dumps, keccak256, loads, subject_id, uint
from tools.museum.chain_rpc import quantity

v1, v2, v4 = v5.v1, v5.v2, v5.v4
ROOT, ZERO, ZERO_ADDRESS, MAX_BYTES = v5.ROOT, v5.ZERO, v5.ZERO_ADDRESS, v5.MAX_BYTES
PACKET = "STREAM_ACQUISITION_PACKET_V9"
RIGHTS_SNAPSHOT_URI = v5.RIGHTS_SNAPSHOT_URI
QUALIFICATION = ("Prospective unregistered supplied-data acquisition packet V9. All nineteen required groups and "
    "earlier V8 branches remain. The paired scoped factory-policy V2 branch retains complete original membership, "
    "policy/readiness and ordered output hash rows, original snapshot/reference records and STATIC component "
    "preimages. Historical Core/metadata facts and terminal-admission preimages remain hash-only. Current token "
    "burn is separate. Supplied commitment consistency does not establish runtime acceptance, source authenticity, "
    "historical authority or execution, consensus, full source coverage or acquisition acceptance.")
RULES = [
    "Packet version is numeric9; frozen V1 through V8 definitions remain byte-identical and all earlier branches retain their checks.",
    "native_scoped_policy_finality_v2 and native_scoped_policy_token_content_proof_v2 are paired with exact derived proof; ONCHAIN metadata mode and script work class are mandatory.",
    "This branch supports the original factory-policy TOKEN, RELEASE and SEASON codecs only. COLLECTION, VIEW, V1 STATIC and current-authority factory encodings cannot be relabeled into it.",
    "The selected historical root is latest for the exact scope before original finalization; a later root head never replaces it.",
    "The target completed mint precedes original selection checkpoint creation. Burned tokens retain original identity and membership; current lifecycle is separate.",
    "Target original readiness coordinator/status/seed equal the corresponding supplied packet entropy fields; mode/code/policy commitments remain in the exact native fragment.",
    "Original root/snapshot/reference/finality receipts keep distinct authority and cannot be cast into generic records. Original governance inputs reconstruct supported direct Executor metadata only.",
    "All nineteen group relationships remain version-local. Shared Core, Metadata, schema Store/Registry, Artist identity, runtime observations and event coordinates must agree.",
    "Proof of supplied commitment consistency is separate from runtime admission, source replay/authenticity, consensus, historical execution and institution acceptance.",
]


def definitions():
    d = copy.deepcopy(v8.definitions())
    d.update(v5._embed(finality, "scopedPolicyFinality__"))
    d["packet"]["properties"]["schema"] = {"const": PACKET}
    d["packet"]["properties"]["version"] = {"const": 9}
    d["previousFinalityV8"] = d["finality"]
    d["previousProofV8"] = d["proof"]
    d["finality"] = {"oneOf": [v1.ref("previousFinalityV8"), v1.closed({
        "kind": {"const": "native_scoped_policy_finality_v2"}, "fragment": v1.ref("scopedPolicyFinality__fragment")})]}
    d["proof"] = {"oneOf": [v1.ref("previousProofV8"), v1.ref("scopedPolicyFinality__tokenProof")]}
    return d


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "urn:6529stream:schema:" + PACKET, "title": PACKET,
        "description": QUALIFICATION, **v1.ref("packet"), "$defs": definitions(),
        "x-stream-original-packet": {"name": v8.PACKET, "hash": v8.PACKET_SCHEMA_HASH},
        "x-stream-native-finality": {"name": finality.NAME, "hash": finality.SCHEMA_HASH},
        "x-stream-constraints": RULES})


PACKET_SCHEMA_BYTES = schema_document_bytes()
PACKET_SCHEMA_HASH = keccak256(PACKET_SCHEMA_BYTES)


def _native(value):
    return value["finality"].get("kind") in ("native_scoped_policy_finality_v2", "native_policy_collection_finality_v2", "native_scoped_static_finality", "native_collection_finality")


def _finality(value):
    native = value["finality"].get("kind") == "native_scoped_policy_finality_v2"
    proof_native = value["contentRootProof"].get("kind") == "native_scoped_policy_token_content_proof_v2"
    v1.need(native == proof_native, "V9 policy V2 finality/proof branches must be paired")
    if not native:
        v8._finality(value)
        return
    v1.need(value["metadataMode"] == "ONCHAIN" and value["workClass"] == "script",
        "V9 native finality requires ONCHAIN script")
    fragment = finality.validate(dumps(value["finality"]["fragment"]))
    v1.need(value["citation"]["qualifier"] == {"kind": "fin", "hash": fragment["bundle"]["finality"]["record"][2]},
        "V9 native finality requires its original fin citation")
    state, observed = value["sourceState"], fragment["sourceState"]
    v1.need(all(observed[k] == state[k] for k in ("chainId", "core", "collectionId", "tokenId", "blockHash", "blockNumber")),
        "V9 finality source identity differs")
    ctx, p = value["conservation"]["context"], value["attribution"]["personhood"]
    graph = fragment["graph"]
    v1.need(graph["metadata"]["address"] == ctx["metadataHost"]
        and graph["schemas"]["address"] == ctx["schemaRegistry"] and graph["store"]["address"] == ctx["store"]
        and graph["artist"]["address"] == p["sourceBindings"]["currentRegistry"], "V9 shared native graph identities differ")
    content = fragment["bundle"]["content"]
    root = next(row["record"] for row in content["roots"]["history"] if row["recordHash"] == content["roots"]["selectedRootHash"])
    v1.need(value["attribution"]["artistId"] == p["current"]["artistId"] == root[8] != ZERO,
        "V9 shared native Artist identity differs")
    v1.need(observed["timestamp"] == ctx["sourceBlockTimestamp"] == p["sourceState"]["timestamp"]
        and observed["environment"] == p["sourceState"]["environment"]
        and observed["stateRoot"] == p["sourceState"]["stateRoot"]
        and observed["deploymentEvidenceHash"] == p["sourceState"]["deploymentEvidenceHash"]
        and uint(observed["timestamp"], 64) <= uint(state["examinedAt"], 64), "V9 finality source time differs")
    v1.need(value["contentRootProof"] == finality.token_proof(fragment), "V9 native token proof differs")
    identity = fragment["identity"]
    v1.need(identity["collectionSerial"] == state["collectionSerial"] and identity["burned"] == state["burned"]
        and identity["lifecycle"] == ("3" if state["burned"] else "2"), "V9 native finality token lifecycle differs")
    mint = value["ownershipProvenance"]["transfers"][0]
    descriptors = finality.wire.expected_events(fragment["bundle"], observed, graph)
    start = next(row for row in descriptors if row["kind"] == "selection_started")
    checkpoint = next(row["log"] for row in fragment["events"]
        if finality.wire.base.event_matches(start, row["log"]))
    v1.need(tuple(uint(mint[key]) for key in ("blockNumber", "logIndex"))
        < tuple(quantity(checkpoint[key]) for key in ("blockNumber", "logIndex")),
        "V9 target completed mint must precede native checkpoint")
    native_keys = finality.native_record_keys(fragment)
    for record in v1._records_in(value):
        v1.need((record["host"], record["recordHash"]) not in native_keys,
            "V9 native finality/root cannot be relabeled as legacy authority")
    outputs = content["checkpoint"]["outputs"]
    target = next(row for row in outputs if row[0][0] == state["tokenId"])
    readiness, entropy = target[4], value["entropy"]["leaf"]
    v1.need(readiness[0] == entropy["coordinatorAtMint"] and readiness[3] == entropy["status"]
        and readiness[9] == entropy["seed"], "V9 target original readiness differs from packet entropy")
    _joined_observations(value, fragment)


def _joined_observations(value, fragment):
    """Compare already validated fragments without pretending supplied events are a chain proof."""
    state, ctx = value["sourceState"], value["conservation"]["context"]
    obs = v4._Observations(state, fragment["sourceState"]["timestamp"])
    codes = {}
    def runtime(address, digest):
        v1.need(codes.setdefault(address, digest) == digest, "V9 supplied runtime commitments differ")
    runtime(state["core"], ctx["coreRuntimeHash"])
    v4._tier(ctx, state, obs); v4._scopes(ctx, state, obs)
    floor = value["conservation"]["floor"]
    class Joined(v5.direct.Observations):
        def runtime(self, address, digest):
            super().runtime(address, digest); runtime(address, digest)
        def event(self, row, identity, timestamp=None):
            super().event(row, identity, timestamp)
            obs.add(row, None if timestamp is None else str(timestamp), identity)
    joined = Joined(floor["sourceState"])
    v5.direct._catalogue(floor, joined); v5.direct._ledger(floor, joined); v5.direct._first_release(floor, joined)
    for row in floor["floor"]["directSales"]: v5.direct._direct(row, joined)
    joined.finish()
    v5._personhood_observations(value["attribution"]["personhood"], obs, runtime)
    v5._packet_observations(value, state, obs, ctx)
    for row, stamp, identity in finality.event_observations(fragment): obs.add(row, stamp, identity)
    for address, digest in finality.runtime_observations(fragment): runtime(address, digest)
    obs.finish()


def validate(raw):
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(PACKET_SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value); v5._typed(value, v1.ref("packet"), schema["$defs"])
        old_fields = {k: v for k, v in value.items() if k not in ("conservation", "attribution")}
        old_fields["attribution"] = {k: v for k, v in value["attribution"].items() if k != "personhood"}
        if _native(value):
            old_fields.pop("finality"); old_fields.pop("contentRootProof")
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
        _finality(value)
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied acquisition packet V9") from exc


def documents(): return {PACKET: PACKET_SCHEMA_BYTES}
def outputs(): return {"schemas/records/" + name + ".json": raw for name, raw in documents().items()}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv)
    for path, raw in outputs().items():
        destination = ROOT / path
        if args.check: v1.need(destination.is_file() and destination.read_bytes() == raw, "generated V9 bytes differ")
        else: destination.write_bytes(raw)
    print("V9 supplied packet definition matches; complete source coverage is not established.")


# Version-local all-nineteen-group joins are copied from frozen V5 below. Only
# the fin citation hook differs; each native branch is independently validated.
need, _kind, _sorted_unique = v1.need, v1._kind, v1._sorted_unique
_head_key, _record_context, _entropy_hash = v1._head_key, v1._record_context, v1._entropy_hash
_general_head, _personhood, _conservation, _curated = v5._general_head, v5._personhood, v5._conservation, v5._curated
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
        if _native(value):
            need(citation["qualifier"]["hash"] == value["finality"]["fragment"]["bundle"]["finality"]["record"][2 if value["finality"]["kind"] in ("native_scoped_static_finality", "native_scoped_policy_finality_v2") else 1], "native finality citation join")
        else:
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
