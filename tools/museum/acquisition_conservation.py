"""Offline native conservation composition from three unchanged source captures."""
import argparse
from pathlib import Path

from ..metadata import acquisition_packet_v4 as packet
from . import object_dossier as base
from . import public_conservation_capture as selection_capture
from . import public_conservation_tier_capture as tier_capture
from . import public_conservation_floor_capture as floor_capture
from . import conservation_capture_join as joined
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id, subject_id, uint
from .chain_abi import decode, encode
from .dossier_gather import ITEMS
from .independent_wire import ZERO, require
from .owner_catalog_source import _position
from .public_conservation_source import SELECTION

MODE = "acquisition_native_conservation_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_NATIVE_CONSERVATION_ASSEMBLY_V1"
CAPTURES = {"tier": tier_capture, "selection": selection_capture, "floor": floor_capture}
# Stable additive event shape at 37d5b443. Recognition only; no DIRECT admission.
DIRECT_EVENT = schema_id("ConservationDirectPrimarySaleRecorded(bytes32,bytes32,(bytes32,address,bytes32,bytes32,bytes32,bytes32,"
    "(address,bytes32,address,bytes32,uint256,bytes32),"
    "(bytes32,uint256,uint256,bytes32,bytes32,bytes32,bytes32,bytes32,address,uint64,bool,address,uint64,address,address,uint256),"
    "bytes32,bytes32,bytes32,uint64),uint16)")
DIRECT_BINDINGS = ("address", "bytes32", "address", "bytes32", "uint256", "bytes32")
DIRECT_SALE = ("bytes32", "uint256", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
    "address", "uint64", "bool", "address", "uint64", "address", "address", "uint256")
DIRECT_RECEIPT = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", DIRECT_BINDINGS,
    DIRECT_SALE, "bytes32", "bytes32", "bytes32", "uint64")
QUALIFICATION = ("Partial acquisition assembly under the explicit V4 native conservation representation. "
    "The unchanged tier, selected intent/interview and universal floor captures are replayed separately, then "
    "their shared source state, RPC observations, headers, receipts and original evidence are reconciled. "
    "Current four-lane selection and historical accepted floor facts remain distinct. Supplied-data schema "
    "compatibility and source replay do not independently prove documentary truth, personhood, archive delivery, "
    "all paid routes or complete CMC prerequisites. Observed target-collection DIRECT floor records cause rejection; "
    "exactly decoded foreign-collection DIRECT observations remain retained originals without admission, and malformed known "
    "DIRECT events fail closed. "
    "Unobserved target DIRECT absence is not proved by the frozen universal filters. DIRECT and unsupported mixed receipt "
    "families are not admitted by this profile. All 19 requirements stay explicit; complete packet export remains unavailable. "
    "Provider completeness and canonical mappings remain trusted; provenance is externally admitted.")
CLAIMS = {"threeOriginalCapturesReplayed": True, "sharedSourceObservationsReconciled": True,
    "nativeConservationFragmentCompatible": True, "fourSelectionLanesRetained": True,
    "historicalFloorDistinctFromCurrentSelection": True, "frozenInputBytesPreserved": True,
    "unknownConvertedToAbsence": False, "directReceiptFamilySupported": False,
    "allPaidRoutesCovered": False, "candidatePreimagesRecovered": False,
    "documentaryFactsIndependentlyVerified": False, "personhoodProven": False,
    "archiveDeliveryProven": False, "completeCmcPrerequisites": False,
    "sourceProvenanceSelfAuthenticated": False, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "completeCanonicalPacket": False, "networkFetch": False}
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "packetSchema": packet.PACKET, "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
    "conservationSchema": packet.CONSERVATION, "conservationSchemaHash": packet.CONSERVATION_SCHEMA_HASH,
    "captureProfiles": {role: module.PROFILE_HASH for role, module in CAPTURES.items()},
    "reconciliationProfileHash": joined.PROFILE_HASH,
    "unsupportedObservedFloorEvents": [DIRECT_EVENT],
    "directEventPolicy": "Decode the exact version-one event shape. Reject target-collection DIRECT records and malformed known events; retain typed foreign-collection observations without admitting their receipt semantics.",
    "inputs": "Exactly tier, selection and floor capture packages with external manifest pins and equal provenance. Each frozen capture is fully replayed before cross-source reconciliation.",
    "scope": "Native V4 item13 evidence composition and source token identity; complete acquisition export is unavailable.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "native conservation composition requires public disclosure before reads")


def _pins(packet_schema_hash, conservation_schema_hash):
    require(packet_schema_hash == packet.PACKET_SCHEMA_HASH and conservation_schema_hash == packet.CONSERVATION_SCHEMA_HASH,
        "native conservation explicit schema pins differ")


def _state(selection, tier):
    anchor, identity = selection["source"], selection["identity"]
    allocated = [r for r in tier["allocations"] if r["tokenId"] == identity["tokenId"]]
    require(len(allocated) == 1 and allocated[0]["collectionSerial"] == identity["collectionSerial"]
        and allocated[0]["lifecycle"] == identity["lifecycle"] and allocated[0]["status"] == ("burned" if identity["burned"] else "minted"),
        "native conservation token identity/completed mint join differs")
    require(any(row["tokenId"] == identity["tokenId"] and row["collectionSerial"] == identity["collectionSerial"]
        for row in tier["completedMints"]), "native conservation original completed token mint missing")
    return {key: anchor[key] for key in ("chainId", "core", "collectionId", "tokenId", "blockNumber", "blockHash")} | {
        "collectionSerial": identity["collectionSerial"], "burned": identity["burned"], "examinedAt": anchor["timestamp"],
        "subjectId": subject_id("token", anchor["chainId"], anchor["core"], anchor["collectionId"], token_id=anchor["tokenId"]),
        "collectionSubjectId": subject_id("collection", anchor["chainId"], anchor["core"], anchor["collectionId"])}


def _items():
    rows = [{"item": str(index), "name": title, "status": "unresolved", "canonicalPacketCompatible": False,
        "evidence": [], "remaining": "Complete evidence for this requirement is not supplied to this assembly."}
        for index, (title, _) in enumerate(ITEMS, 1)]
    for number, field in ((2, "subjectId"), (19, "erc721Identity")):
        rows[number - 1].update(status="derived_within_source_profile", canonicalPacketCompatible=True,
            evidence=["packet/assembly.json#/fields/" + field, "captures/tier/source/snapshot.json",
                "captures/selection/source/snapshot.json"], remaining="")
    rows[12].update(status="partial", canonicalPacketCompatible=True,
        evidence=["packet/conservation.json", "packet/source-reconciliation.json", "packet/documentary-joins.json",
            *["captures/" + role + "/manifest.json" for role in CAPTURES]],
        remaining="Native tier, four selected lineages and universal floor evidence are composed. Original documentary prerequisites, personhood, archive delivery, DIRECT and other paid routes, and the remaining acquisition evidence are not established.")
    return rows


def _supported_history(join_inputs, ledger, collection_id):
    for value in join_inputs.values():
        transcript = loads(value["transcript"], maximum=MAX_BYTES, canonical=True)
        for row in transcript["calls"]:
            if "result" not in row: continue
            if row["method"] == "eth_getTransactionReceipt": logs = row["result"]["logs"]
            elif row["method"] == "eth_getLogs": logs = row["result"]
            else: continue
            for log in logs:
                if log["address"] != ledger or not log["topics"] or log["topics"][0] != DIRECT_EVENT: continue
                require(len(log["topics"]) == 3, "native conservation malformed observed DIRECT floor history")
                try:
                    receipt, version = decode((DIRECT_RECEIPT, "uint16"), hex_bytes(log["data"]), maximum=32768)
                except MuseumError as exc:
                    raise MuseumError("native conservation malformed observed DIRECT floor history") from exc
                require(version == 1 and receipt[0] == log["topics"][2] and receipt[3] == log["topics"][1]
                    and receipt[0] != ZERO and receipt[3] != ZERO and receipt[7][1] > 0,
                    "native conservation malformed observed DIRECT floor history")
                require(receipt[7][1] != collection_id,
                    "native conservation unsupported observed target DIRECT/mixed floor history")


def _wire(kind, value):
    if isinstance(kind, tuple): return tuple(_wire(k, v) for k, v in zip(kind, value, strict=True))
    return uint(value, int(kind[4:])) if kind.startswith("uint") else value


def _documentary_joins(selection, floor):
    """Resolve only original facts whose exact producer preimages are retained."""
    first = floor["floor"]["firstSale"]
    report = {"firstSale": None, "releases": [], "completeDocumentaryPrerequisites": False,
        "qualification": "Matches bind captured original commitments, not documentary truth or archive delivery. Missing original producer evidence stays unresolved; current provider diagnostics never replace historical facts."}
    if first is None:
        report["firstSale"] = {"status": "no_native_receipt", "joins": {}}
        return report
    row = first["receipt"]; facts = row[8]
    names = ("artistId", "identityRecordHash", "intentRecordHash", "intentWaiverRecordHash", "interviewEvidenceHash",
        "rightsRecordHash", "personhoodEvidenceHash", "platformWorks")
    saved = dict(zip(names, facts, strict=True))
    joins = {name: {"status": "original_producer_not_supplied", "commitment": saved[name]}
        for name in ("identityRecordHash", "intentRecordHash", "intentWaiverRecordHash", "interviewEvidenceHash", "rightsRecordHash", "personhoodEvidenceHash")}
    report["firstSale"] = {"status": "native_facts_retained", "receiptHash": first["receiptHash"], "facts": saved, "joins": joins}
    if first["effectiveTier"] == "CONSERVATION_WAIVED":
        for value in joins.values(): value["status"] = "not_required_by_native_waived_floor"
    elif facts[7]:
        for name, value in joins.items():
            if name != "rightsRecordHash": value["status"] = "not_required_by_native_platform_floor"
    else:
        a = selection["source"]
        source = floor["catalogue"]["sources"][uint(first["sourceId"]) - 1]
        lane = selection["scopes"]["collection"]["origins"]["artist"]
        expected_record = facts[2] if facts[2] != ZERO else facts[3]
        expected_kind = 0 if facts[2] != ZERO else 1
        positions = tuple(uint(first["publication"][key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
        candidates = [(selected, event) for selected, event in zip(lane["history"], lane["events"], strict=True)
            if selected[0][0] == expected_record and uint(selected[0][1], 8) == expected_kind
            and selected[1][0] == facts[0] and selected[1][3] == facts[1]
            and _position(event) < positions]
        metadata_pin = next(pin["runtimeHash"] for pin in a["codePins"] if pin["address"] == a["host"])
        if source["metadata"] == a["host"] and source["metadataCodeHash"] == metadata_pin and len(candidates) == 1:
            selected, event = candidates[0]
            selected_at = {key: str(int(event[key], 16)) if key in ("blockNumber", "transactionIndex", "logIndex") else event[key]
                for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex", "logIndex")}
            common = {"status": "original_selected_history_joined", "recordHash": expected_record,
                "selectionHash": selected[12], "revision": selected[9], "publication": selected_at}
            key = "intentRecordHash" if facts[2] != ZERO else "intentWaiverRecordHash"
            joins[key].update(common)
            joins["intentWaiverRecordHash" if facts[2] != ZERO else "intentRecordHash"]["status"] = "native_alternative_not_selected"
            joins["identityRecordHash"].update(common, meaning="original_registration_identity_commitment")
            subject = selection["scopes"]["collection"]["subjectId"]
            domain = schema_id("6529STREAM_FINALITY_" + ("PRESENT" if selected[3] == "0" else "WAIVED") + "_INTERVIEW_V1")
            digest = keccak256(encode(("bytes32", "uint256", ("address",) * 5,
                ("uint8", "uint256", "uint256", "bytes32"), "bytes32", SELECTION, "bytes32", "bytes32"),
                (domain, uint(a["chainId"]), tuple(a[k] for k in ("core", "host", "schemas", "store", "conservationSelector")),
                    (0, uint(a["collectionId"]), 0, ZERO), subject, _wire(SELECTION, selected),
                    schema_id("STREAM_ARTIST_INTERVIEW_V1"), "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf")))
            if digest == facts[4]:
                joins["interviewEvidenceHash"].update(common, interviewStatus="present" if selected[3] == "0" else "waived",
                    interviewRecordHash=selected[4][0], meaning="full_original_selection_and_dependency_commitment")
            else:
                joins["interviewEvidenceHash"].update(status="captured_selection_preimage_differs", computedCommitment=digest)
    for release in floor["floor"]["releases"]:
        context, evidence = release["receipt"][9:11]
        report["releases"].append({"receiptHash": release["receiptHash"], "releaseKey": release["releaseKey"],
            "sourceId": release["sourceId"], "sourceContextHash": context[4],
            "sourceContext": {"status": "original_constructor_serving_and_manifest_facts_not_supplied"},
            "mediaEvidence": {"status": "original_master_and_archive_facts_not_supplied", "commitment": evidence[1]},
            "referenceEvidence": {"status": "not_required_by_native_floor" if evidence[2] == ZERO else "original_prospective_reference_not_supplied",
                "commitment": evidence[2]}})
    return report


def compose(tier_files, tier_hash, selection_files, selection_hash, floor_files, floor_hash, *,
        disclosure, packet_schema_hash, conservation_schema_hash):
    """Replay all originals, reconcile their observations, then project supplied V4 fields."""
    _public(disclosure); _pins(packet_schema_hash, conservation_schema_hash)
    inputs = {"tier": (tier_files, tier_hash), "selection": (selection_files, selection_hash), "floor": (floor_files, floor_hash)}
    for _, expected in inputs.values():
        require(any(hex_bytes(expected, 32)), "native conservation empty input manifest pin")
    verified, snapshots, source_refs, join_inputs = {}, {}, {}, {}
    provenances = set()
    for role, module in CAPTURES.items():
        files, expected = inputs[role]
        require(any(hex_bytes(expected, 32)), "native conservation empty input manifest pin")
        checked = module.verify(files, expected)
        retained = dict(checked.files); verified[role] = retained
        manifest = loads(checked.manifest, maximum=MAX_MANIFEST, canonical=True)
        provenances.add(manifest["provenance"])
        snapshots[role] = loads(retained["source/snapshot.json"], maximum=MAX_BYTES, canonical=True)
        source_refs[role] = {"captureProfileHash": manifest["profileHash"], "sourceProfileHash": manifest["sourceProfileHash"],
            "manifestHash": expected, "anchorHash": keccak256(retained["source/anchor.json"]),
            "transcriptHash": keccak256(retained["source/transcript.json"]), "snapshotHash": keccak256(retained["source/snapshot.json"])}
        join_inputs[role] = {"anchor": retained["source/anchor.json"], "transcript": retained["source/transcript.json"]}
    require(len(provenances) == 1, "native conservation mixed source provenance")
    reconciliation = joined.reconcile(join_inputs)
    _supported_history(join_inputs, snapshots["floor"]["sourceState"]["conservationFloor"], uint(snapshots["floor"]["sourceState"]["collectionId"]))
    state = _state(snapshots["selection"], snapshots["tier"])
    fragment = packet.project(snapshots["tier"], snapshots["selection"], snapshots["floor"], source_refs, state)
    packet.validate_conservation(dumps(fragment), state)
    documentary = _documentary_joins(snapshots["selection"], snapshots["floor"])
    fields = {"sourceState": state, "subjectId": state["subjectId"], "conservation": fragment,
        "erc721Identity": {"core": state["core"], "collectionId": state["collectionId"], "globalTokenId": state["tokenId"],
            "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}}
    items = _items()
    report = {"profile": PROFILE, "version": "1", "packetSchema": packet.PACKET, "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
        "conservationSchemaHash": packet.CONSERVATION_SCHEMA_HASH, "sourceProvenance": next(iter(provenances)),
        "fields": fields, "items": items, "unresolvedItems": [r["item"] for r in items if r["status"] != "derived_within_source_profile"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    require(len(dumps(report)) <= packet.MAX_BYTES, "native conservation partial report byte bound")
    files = {"captures/" + role + "/" + path: raw for role, retained in verified.items() for path, raw in retained.items()}
    files.update({"definitions/assembly-profile.json": PROFILE_BYTES, "definitions/reconciliation-profile.json": joined.PROFILE_BYTES,
        "definitions/packet-schema.json": packet.PACKET_SCHEMA_BYTES, "definitions/conservation-schema.json": packet.CONSERVATION_SCHEMA_BYTES,
        "packet/assembly.json": dumps(report), "packet/conservation.json": dumps(fragment),
        "packet/documentary-joins.json": dumps(documentary),
        "packet/source-reconciliation.json": dumps(reconciliation)})
    lines = ["# Native conservation: partial acquisition assembly", "", QUALIFICATION, "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((r["item"], r["name"], r["status"], r["remaining"])) + " |" for r in items]
    files["packet/examination.md"] = ("\n".join(lines) + "\n").encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {role: expected for role, (_, expected) in inputs.items()}, "packetSchemaHash": packet.PACKET_SCHEMA_HASH,
        "conservationSchemaHash": packet.CONSERVATION_SCHEMA_HASH, "sourceProvenance": report["sourceProvenance"],
        "files": [base._ref(p, b) for p, b in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "native conservation assembly manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "native conservation external assembly manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "inputs", "packetSchemaHash",
        "conservationSchemaHash", "sourceProvenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
        and type(value["inputs"]) is dict and set(value["inputs"]) == set(CAPTURES)
        and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION, "native conservation closed assembly manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "native conservation assembly file commitments differ")
    args = []
    for role in CAPTURES:
        prefix = "captures/" + role + "/"
        args.extend(({p[len(prefix):]: raw for p, raw in files.items() if p.startswith(prefix)}, value["inputs"][role]))
    rebuilt = compose(*args, disclosure="public", packet_schema_hash=value["packetSchemaHash"],
        conservation_schema_hash=value["conservationSchemaHash"])
    require(dict(rebuilt.files) == files, "native conservation assembly reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in CAPTURES:
        build.add_argument("--" + role, type=Path, required=True)
        build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--packet-schema-hash", required=True); build.add_argument("--conservation-schema-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for command in ("verify", "complete-packet"):
        child = sub.add_parser(command); child.add_argument("directory", type=Path)
        child.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "packetSchema": packet.PACKET,
            "packetSchemaHash": packet.PACKET_SCHEMA_HASH, "conservationSchemaHash": packet.CONSERVATION_SCHEMA_HASH,
            "reconciliationProfileHash": joined.PROFILE_HASH}).decode("utf-8")); return
    if args.command == "assemble":
        _public(args.disclosure); _pins(args.packet_schema_hash, args.conservation_schema_hash)
        for role in CAPTURES:
            require(any(hex_bytes(getattr(args, role + "_hash"), 32)), "native conservation empty input manifest pin")
        from .repository_exchange import _destination, _publish
        sources = [getattr(args, role) for role in CAPTURES]; _destination(args.output, sources)
        inputs = []
        for role in CAPTURES: inputs.extend((read_tree(getattr(args, role)), getattr(args, role + "_hash")))
        result = compose(*inputs, disclosure=args.disclosure, packet_schema_hash=args.packet_schema_hash,
            conservation_schema_hash=args.conservation_schema_hash)
        require(verify(result.files, result.manifest_hash).files == result.files, "native conservation pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash); return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)), "packetSchema": packet.PACKET,
        "item13CanonicalPacketCompatible": True, "canonicalPacketReady": False,
        "sourceProvenance": result.report["sourceProvenance"], "unresolvedItems": result.report["unresolvedItems"]}).decode("utf-8"))


if __name__ == "__main__": main()
