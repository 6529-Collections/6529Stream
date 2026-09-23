"""Standalone current conservation tier and four native selection lanes, without a floor."""
import argparse
import copy

from jsonschema import Draft202012Validator
from jsonschema.exceptions import ValidationError

from . import acquisition_packet_v4 as v4
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from tools.museum.independent_wire import require

ROOT, MAX_BYTES, ZERO = v4.ROOT, v4.MAX_BYTES, v4.ZERO
NAME = "STREAM_ACQUISITION_CONSERVATION_CONTEXT_V1"
SOURCE_REF_FIELDS = v4.SOURCE_REF_FIELDS
SOURCE_PROFILES = {key: v4.SOURCE_PROFILES[key] for key in ("tier", "selection")}
QUALIFICATION = ("Prospective unregistered supplied-data conservation context. Native current tier and four "
    "collection/token Artist/estate selector lanes are represented independently of any sale-floor family. "
    "Original Metadata receipt authority and Artist op24 authority remain separate. Exact supplied source "
    "pins, native selection/catalog hashes, shared record indices, tier/default and observation joins are "
    "checked; source references do not authenticate themselves. Validation performs no capture replay, "
    "signature or runtime admission, personhood, institutional or documentary-fact proof. Selector-scoped "
    "absence is not universal record absence. Current eligibility and selected records never replace "
    "historical sale evidence. No floor, full acquisition packet or complete item13 is synthesized. Frozen "
    "packet versions V1–V4 and their universal-only floor boundary remain unchanged.")
RULES = [
    "Numeric version1 identifies this floor-independent standalone context; sourceRefs has exactly tier and selection with six exact capture/source commitments each.",
    "Reachable native tier/scope definitions and their validation semantics are reused unchanged from frozen V4. Neither the V4 complete-packet projector nor any fabricated floor is used.",
    "Packet sourceState distinguishes examination time from the captured block timestamp. The original target must be completed or burned, with matching Core token/collection/serial/lifecycle observations in both source snapshots.",
    "Native collection/token subjects and Artist/estate origins are separate lanes without inferred precedence. Metadata authority class1 is distinct from Artist signer class1/3.",
    "Exact ordered catalogue occurrences and selection hashes are reconstructed. Shared Metadata collection/type record indices preserve original records and publication order; this fragment carries no full lane head denominator.",
    "Source pins and supplied history observations are internal joins only. Historical originals, source headers, receipts and transcript replay remain the capture assembler's responsibility.",
]


def definitions():
    original = v4.definitions(); r, c = v4.v1.ref, v4.v1.closed
    inherited = original["nativeConservation"]["properties"]
    properties = {key: copy.deepcopy(inherited[key]) for key in ("sourceBlockTimestamp", "coreRuntimeHash", "metadataHost",
        "conservationSelector", "schemaRegistry", "store", "tier", "scopes")}
    original["context"] = c({"schema": {"const": NAME}, "version": {"const": 1}, "sourceState": r("sourceState"),
        "sourceRefs": c({key: copy.deepcopy(inherited["sourceRefs"]["properties"][key]) for key in SOURCE_PROFILES}),
        **properties, "qualification": {"const": QUALIFICATION}})
    selected, pending = {}, ["context"]
    while pending:
        key = pending.pop()
        if key in selected: continue
        selected[key] = original[key]
        pending.extend(row["$ref"].split("/")[-1] for row in v4.v1._walk(original[key]) if "$ref" in row)
    return selected


def schema_document_bytes():
    return dumps({"$schema": "https://json-schema.org/draft/2020-12/schema", "$id": "urn:6529stream:schema:" + NAME,
        "title": NAME, "description": QUALIFICATION, **v4.v1.ref("context"), "$defs": definitions(),
        "x-stream-frozen-native-semantics": {"name": v4.CONSERVATION, "hash": v4.CONSERVATION_SCHEMA_HASH},
        "x-stream-source-profile-pins": {k: list(v) for k, v in SOURCE_PROFILES.items()}, "x-stream-constraints": RULES})


SCHEMA_BYTES = schema_document_bytes()
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def validate(raw):
    """Check supplied tier/selection consistency; source authentication is explicitly external."""
    try:
        value = loads(raw, maximum=MAX_BYTES, canonical=True)
        schema = loads(SCHEMA_BYTES, maximum=MAX_BYTES)
        Draft202012Validator(schema).validate(value)
        v4.v1._typed(value, v4.v1.ref("context"), schema["$defs"])
        state = value["sourceState"]; v4.v2._source_context(state)
        require(uint(value["sourceBlockTimestamp"], 64) <= uint(state["examinedAt"], 64), "conservation context timestamp after examination")
        for role, expected in SOURCE_PROFILES.items():
            pins = value["sourceRefs"][role]
            require(tuple(pins[key] for key in SOURCE_REF_FIELDS[:2]) == expected and all(any(hex_bytes(pins[key], 32)) for key in SOURCE_REF_FIELDS),
                "conservation context source reference differs")
        observations = v4._Observations(state, value["sourceBlockTimestamp"])
        v4._tier(value, state, observations)
        records = v4._scopes(value, state, observations)
        v4._record_lanes(records, state)
        observations.finish()
        return value
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid supplied conservation context") from exc


def semanticProjection(tier_snapshot, selection_snapshot, source_refs, source_state):
    """Project two real caller-verified snapshots directly; no floor parameter exists."""
    try:
        v4.v2._source_context(source_state)
        require(type(source_refs) is dict and set(source_refs) == set(SOURCE_PROFILES), "conservation context exact source pair required")
        snapshots = {"tier": tier_snapshot, "selection": selection_snapshot}
        modules = {"tier": v4.tier_source, "selection": v4.selection}
        ss = selection_snapshot["source"]; stamp = ss["timestamp"]
        for role, snapshot in snapshots.items():
            module, refs = modules[role], source_refs[role]
            require(type(refs) is dict and set(refs) == set(SOURCE_REF_FIELDS) and type(snapshot) is dict
                and snapshot.get("profile") == module.PROFILE and snapshot.get("profileHash") == module.PROFILE_HASH
                and snapshot.get("version") == "1" and snapshot.get("sourceReviewCommit") == module.SOURCE_REVISION,
                "conservation context snapshot profile differs")
            state = snapshot["source"] if role == "selection" else snapshot["sourceState"]
            require(all(state[k] == source_state[k] for k in ("chainId", "core", "collectionId", "blockHash", "blockNumber"))
                and state["timestamp"] == stamp and state["environment"] == ss["environment"], "conservation context snapshot source differs")
            require(tuple(refs[k] for k in SOURCE_REF_FIELDS[:2]) == SOURCE_PROFILES[role]
                and snapshot["anchorHash"] == refs["anchorHash"] and snapshot["transcriptHash"] == refs["transcriptHash"]
                and keccak256(dumps(snapshot)) == refs["snapshotHash"], "conservation context snapshot pin differs")
        require(tier_snapshot["coreSourceReviewCommit"] == v4.tier_source.CORE_REVISION
            and selection_snapshot["anchorHash"] == keccak256(dumps(ss))
            and ss["profile"] == v4.selection.PROFILE and ss["tokenId"] == source_state["tokenId"],
            "conservation context retained anchor differs")
        identity = selection_snapshot["identity"]
        require(all(identity[k] == source_state[k] for k in ("tokenId", "collectionId", "collectionSerial", "burned"))
            and identity["lifecycle"] == ("3" if identity["burned"] else "2"), "conservation context completed token identity differs")
        allocations = [row for row in tier_snapshot["allocations"] if row["tokenId"] == identity["tokenId"]]
        completed = [row for row in tier_snapshot["completedMints"] if row["tokenId"] == identity["tokenId"]]
        require(len(allocations) == len(completed) == 1, "conservation context target completion missing/duplicate")
        allocation = allocations[0]
        require(all(row["collectionSerial"] == identity["collectionSerial"] for row in (allocation, completed[0]))
            and allocation["identity"] == [True, identity["collectionId"], identity["collectionSerial"], identity["burned"]]
            and allocation["lifecycle"] == identity["lifecycle"] and allocation["status"] == ("burned" if identity["burned"] else "minted"),
            "conservation context tier/selection target identity differs")
        value = {"schema": NAME, "version": 1, "sourceState": copy.deepcopy(source_state), "sourceRefs": copy.deepcopy(source_refs),
            "sourceBlockTimestamp": stamp, "coreRuntimeHash": tier_snapshot["sourceState"]["coreRuntimeHash"],
            "metadataHost": ss["host"], "conservationSelector": ss["conservationSelector"], "schemaRegistry": ss["schemas"], "store": ss["store"],
            "qualification": QUALIFICATION}
        core_pins = [pin["runtimeHash"] for pin in ss["codePins"] if pin["address"] == ss["core"]]
        require(core_pins == [value["coreRuntimeHash"]], "conservation context shared Core runtime differs")
        value["tier"] = {key: copy.deepcopy(tier_snapshot["tier"][key]) for key in definitions()["nativeTier"]["properties"]}
        declaration = value["tier"]["declaration"]
        if declaration:
            value["tier"]["declaration"] = {key: declaration[key] for key in ("tier", "tierHash", "metadataHost", "blockTimestamp", "publication")}
            value["tier"]["declaration"]["facadePublication"] = v4._pub(declaration["facadeEvent"])
        mint = value["tier"]["firstCompletedMint"]
        if mint: value["tier"]["firstCompletedMint"] = {key: mint[key] for key in definitions()["nativeFirstMint"]["properties"]}
        originals = {row["recordHash"]: row for row in selection_snapshot["records"]}
        require(len(originals) == len(selection_snapshot["records"]), "conservation context duplicate original records")
        def record(evidence):
            original = originals[evidence[0]]; wire = original["record"]
            return {"evidence": v4._named(evidence, v4.EVIDENCE_FIELDS, v4.selection.RECORD_EVIDENCE,
                {"artist": (v4.ARTIST_FIELDS, v4.selection.EVIDENCE)}), "original": {
                    "host": ss["host"], "subjectId": wire[1], "recordType": wire[0], "schemaId": wire[4],
                    "metadataAuthorityClass": original["receipt"][2], "originalRecordBytesHash": keccak256(dumps(wire)),
                    "payloadBytesHash": keccak256(hex_bytes(original["payloadHex"])), "statementBytesHash": keccak256(hex_bytes(original["statementHex"])),
                    "signatureBundleHash": keccak256(hex_bytes(original["signatureHex"])), "publication": v4._pub(original["publication"])}}
        require(set(selection_snapshot["scopes"]) == {"collection", "token"}, "conservation context exact two scopes required")
        value["scopes"] = {}
        for scope_name, original in selection_snapshot["scopes"].items():
            require(set(original["origins"]) == {"artist", "estate"}, "conservation context exact two origins required")
            scope = {"subjectId": original["subjectId"]}
            for origin, lane in original["origins"].items():
                require(lane["status"] in ("absent_on_bound_selector", "selected"), "conservation context unknown selector status")
                if lane["status"] == "absent_on_bound_selector":
                    require(lane["current"] == v4.selection.json_values(v4.selection.EMPTY_SELECTION), "conservation context absent head differs")
                    scope[origin] = {"status": lane["status"], "currentEligibility": copy.deepcopy(lane["currentEligibility"])}; continue
                head = lane["current"]
                require(head[2] == ("0" if origin == "artist" else "1") and head[3] in ("0", "1"), "conservation context native origin/interview differs")
                if head[4][0] == ZERO:
                    require(head[4] == v4.selection.json_values(v4.selection.EMPTY_RECORD), "conservation context partial empty interview")
                selected = {"record": record(head[0]), "association": v4._named(head[1], v4.ASSOCIATION_FIELDS, v4.selection.ASSOCIATION),
                    "statementOrigin": origin, "interviewStatus": "present" if head[3] == "0" else "waived", "interview": record(head[4]) if head[4][0] != ZERO else None,
                    "interviewReferenceHash": head[5], "interviewPayloadCorrespondence": head[6], "predecessorRecordHash": head[7],
                    "selector": head[8], "revision": head[9], "selectedAt": head[10], "catalogHash": head[11], "selectionHash": head[12],
                    "catalogs": [v4._named(pin, v4.CATALOG_FIELDS, v4.selection.CATALOG_PIN) for pin in lane["catalogs"][-1]],
                    "publication": v4._pub(lane["events"][-1]), "currentEligibility": copy.deepcopy(lane["currentEligibility"])}
                scope[origin] = {"status": "selected", "selection": selected}
            lock = original["lock"]
            require(type(lock[0]) is bool, "conservation context lock flag differs")
            if not lock[0]:
                require(lock == v4.selection.json_values(v4.selection.EMPTY_LOCK) and original["lockEvent"] is None,
                    "conservation context partial empty lock")
            scope["lock"] = {"status": "unlocked"} if not lock[0] else {"status": "locked",
                **v4._named(lock[1:], v4.LOCK_FIELDS, v4.selection.LOCK[1:]), "publication": v4._pub(original["lockEvent"])}
            value["scopes"][scope_name] = scope
        return validate(dumps(value))
    except MuseumError: raise
    except (ValidationError, ValueError, TypeError, KeyError, IndexError, OverflowError, RecursionError) as exc:
        raise MuseumError("invalid conservation context snapshot projection") from exc


def documents(): return {NAME: SCHEMA_BYTES}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument("--check", action="store_true")
    args = parser.parse_args(argv); path = ROOT / "schemas/records" / (NAME + ".json")
    if args.check: require(path.is_file() and path.read_bytes() == SCHEMA_BYTES, "conservation context generated definition differs")
    else: path.write_bytes(SCHEMA_BYTES)
    print("Standalone tier/selection context matches; no floor or full-packet proof.")


if __name__ == "__main__": main()
