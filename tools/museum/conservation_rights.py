"""Join saved first-sale RIGHTS commitments to unchanged original public captures."""
import argparse
from pathlib import Path

from . import conservation_rights_join as joined
from . import object_dossier as base
from . import public_conservation_floor_capture as universal
from . import public_direct_conservation_capture as direct
from . import public_history_capture as rights_capture
from . import public_rights_source as rights_source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, subject_id, uint
from .dossier_gather import ITEMS
from .independent_wire import require
from .owner_catalog_source import _location, _position

MODE = "conservation_original_rights_assembly"
PROFILE = "STREAM_MUSEUM_CONSERVATION_ORIGINAL_RIGHTS_ASSEMBLY_V1"
FLOORS = {universal.MODE: universal, direct.MODE: direct}
CLAIMS = {"twoOriginalCapturesReplayed": True, "originalInputBytesPreserved": True,
    "sharedSourceObservationsReconciled": True, "currentAndHistoricalRightsSeparated": True,
    "originalPublisherAndSelectorAuthorityRetained": True,
    "historicalConservationProviderSelectorBindingProven": False,
    "historicalProviderEligibilityReexecuted": False, "unknownConvertedToAbsence": False,
    "rightsLegalTruthProven": False, "effectiveDateApplicabilityAssessed": False,
    "personhoodProven": False, "archiveDeliveryProven": False,
    "allPaidRoutesCovered": False, "sourceProvenanceSelfAuthenticated": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "Original documentary correspondence between one frozen universal or DIRECT floor capture and one "
    "frozen public RIGHTS capture. The saved first-sale collection RIGHTS hash is compared with original "
    "Metadata, runtime, record, receipt, payload and pre-sale selected history. Current collection and token "
    "selections remain separate. The RIGHTS selector is bound by its original finality source profile; its "
    "binding to the historical conservation provider is not established without that provider's original "
    "configuration. A matching record does not prove legal rights, date applicability or historical provider "
    "execution. Existing RIGHTS capture requires current eligibility and cannot capture every retired graph. "
    "Provider completeness and canonical mappings remain trusted. Complete packet export is unavailable.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "sourceReviewCommit": "8bb6dfe2957542f641b0d558e1cfd48e1b39ae98",
    "inputs": {"floor": {mode: module.PROFILE_HASH for mode, module in FLOORS.items()},
        "rights": {"captureProfileHash": rights_capture.PROFILE_HASH, "sourceProfileHash": rights_source.PROFILE_HASH}},
    "reconciliationProfileHash": joined.PROFILE_HASH,
    "originals": "Exactly two independently replayed captures with external manifest pins and equal provenance. Preserve every input byte and reconcile shared observations before documentary matching.",
    "join": "Exact saved original Metadata address/runtime, collection subject and RIGHTS record hash, original publication and selected revision strictly before first-sale event. Full originals remain in their capture; never substitute source-time current selection.",
    "selection": "Retain all matching pre-sale selections and the latest observed collection selection before first sale. A superseded original is explicitly flagged; original_record_joined requires that latest row to match the saved hash. Neither status establishes historical provider selector binding or consumption.",
    "waiver": "Native zero RIGHTS on a waived first-sale floor is not required by that floor; current RIGHTS evidence is still retained. No first-sale receipt means no historical join, not RIGHTS absence.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "original RIGHTS composition requires public disclosure before reads")


def _manifest(files, expected_hash):
    base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "original RIGHTS external input manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict, "original RIGHTS input manifest shape")
    return value


def _originals(floor_files, floor_hash, rights_files, rights_hash):
    floor_files, rights_files = dict(floor_files), dict(rights_files)
    floor_manifest = _manifest(floor_files, floor_hash)
    rights_manifest = _manifest(rights_files, rights_hash)
    require(floor_manifest.get("mode") in FLOORS, "original RIGHTS floor capture family unsupported")
    require(rights_manifest.get("mode") == rights_capture.MODE and rights_manifest.get("kind") == "rights",
        "original RIGHTS requires the original public RIGHTS capture")
    # Authenticate each retained package under its own closed profile first.
    floor = FLOORS[floor_manifest["mode"]].verify(floor_files, floor_hash)
    rights = rights_capture.verify(rights_files, rights_hash)
    require(floor.report["provenance"] == rights.report["provenance"], "original RIGHTS source provenance differs")
    captures = {"floor": dict(floor.files), "rights": dict(rights.files)}
    inputs = {role: {name: files["source/" + name + ".json"] for name in ("anchor", "transcript")}
        for role, files in captures.items()}
    reconciliation = joined.reconcile(inputs)
    snapshots = {role: loads(files["source/snapshot.json"], maximum=MAX_BYTES, canonical=True)
        for role, files in captures.items()}
    return captures, snapshots, reconciliation, floor.report["provenance"]


def _historical(floor, rights):
    a = rights["source"]
    collection = rights["scopes"]["collection"]
    expected_subject = subject_id("collection", a["chainId"], a["core"], a["collectionId"])
    require(collection["subjectId"] == expected_subject, "original RIGHTS collection subject differs")
    first = floor["floor"]["firstSale"]
    report = {"status": "no_native_receipt", "firstSale": first,
        "collectionSubjectId": expected_subject,
        "currentAtAnchor": {"collection": collection["current"], "token": rights["scopes"]["token"]["current"],
            "effectiveGrants": rights["effectiveGrants"], "completeness": rights["completeness"]},
        "savedRecordHash": None, "originalRecord": None, "matchingSelections": [], "selectionAtFirstSale": None,
        "observedSelectedHeadMatchesSavedRecord": None,
        "providerBinding": {"status": "original_conservation_provider_configuration_not_supplied",
            "rightsSelector": a["rightsSelector"], "finalityProvider": a["provider"],
            "qualification": "Original finality binding does not establish the historical conservation provider's selector."}}
    if first is None:
        return report
    saved = first["receipt"][8][5]
    report["savedRecordHash"] = saved
    if first["effectiveTier"] == "CONSERVATION_WAIVED":
        report["status"] = "not_required_by_native_waived_floor"
        report["providerBinding"]["status"] = "not_required_by_native_waived_floor"
        return report
    source_id = uint(first["sourceId"])
    sources = floor["catalogue"]["sources"]
    require(0 < source_id <= len(sources), "original RIGHTS first-sale source ID differs")
    original_source = sources[source_id - 1]
    report["originalConservationSource"] = original_source
    pins = {row["address"]: row["runtimeHash"] for row in a["codePins"]}
    if original_source["metadata"] != a["host"] or original_source["metadataCodeHash"] != pins[a["host"]]:
        report["status"] = "original_metadata_differs"
        return report
    rows = {row["recordHash"]: row for row in rights["records"]}
    require(len(rows) == len(rights["records"]), "original RIGHTS duplicate original record")
    original = rows.get(saved)
    if original is None or original["record"][1] != expected_subject:
        report["status"] = "saved_record_not_in_collection_history"
        return report
    report["originalRecord"] = original
    position = tuple(uint(first["publication"][key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
    publication = original["publication"]["log"]
    if _position(publication) >= position:
        report["status"] = "original_publication_not_before_first_sale"
        return report
    before = [(row, event) for row, event in zip(collection["history"], collection["events"], strict=True)
        if _position(event) < position]
    if before:
        row, event = before[-1]
        report["selectionAtFirstSale"] = {"selection": row, "publication": _location(event)}
        report["observedSelectedHeadMatchesSavedRecord"] = row[0] == saved
    report["matchingSelections"] = [{"selection": row, "publication": _location(event)}
        for row, event in before if row[0] == saved]
    if not report["matchingSelections"]:
        report["status"] = "selection_not_before_first_sale"
        return report
    report["status"] = ("original_record_joined" if report["observedSelectedHeadMatchesSavedRecord"]
        else "original_record_joined_but_superseded")
    report["originalRecordPath"] = "captures/rights/rights/records/" + saved[2:] + "/original.json"
    report["originalPayloadPath"] = "captures/rights/rights/records/" + saved[2:] + "/payload.json"
    return report


def _items():
    items = [{"item": str(i), "name": title, "status": "unresolved", "canonicalPacketCompatible": False,
        "evidence": [], "remaining": "Required evidence is not assembled by this documentary join."}
        for i, (title, _) in enumerate(ITEMS, 1)]
    items[6].update(status="derived_within_source_profile", canonicalPacketCompatible=True,
        evidence=["captures/rights/rights/packet-fragment.json", "captures/rights/source/snapshot.json"],
        remaining="Source provenance remains externally admitted; legal truth and date applicability are not established.")
    items[12].update(status="partial", evidence=["documentary/historical-rights.json", "documentary/reconciliation.json",
        "captures/floor/manifest.json", "captures/rights/manifest.json"],
        remaining="Original RIGHTS correspondence is reported where supplied. Historical provider configuration, other documentary prerequisites, personhood, archive delivery and a complete conservation representation remain unresolved.")
    return items


def compose(floor_files, floor_hash, rights_files, rights_hash, *, disclosure):
    _public(disclosure)
    captures, snapshots, reconciliation, provenance = _originals(floor_files, floor_hash, rights_files, rights_hash)
    historical = _historical(snapshots["floor"], snapshots["rights"])
    items = _items()
    report = {"profile": PROFILE, "sourceState": reconciliation["sourceState"], "sourceProvenance": provenance,
        "floorFamily": reconciliation["floorFamily"], "historicalRights": historical,
        "items": items, "unresolvedItems": [row["item"] for row in items if row["status"] in ("unresolved", "partial")],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {"captures/" + role + "/" + path: raw for role, capture in captures.items() for path, raw in capture.items()}
    files.update({"definitions/assembly-profile.json": PROFILE_BYTES, "definitions/reconciliation-profile.json": joined.PROFILE_BYTES,
        "documentary/historical-rights.json": dumps(historical), "documentary/reconciliation.json": dumps(reconciliation),
        "documentary/report.json": dumps(report)})
    lines = ["# Original conservation RIGHTS correspondence", "", QUALIFICATION, "",
        "Historical RIGHTS status: `" + historical["status"] + "`.", "",
        "| Item | Requirement | Status | Remaining evidence |", "| --- | --- | --- | --- |"]
    lines += ["| " + " | ".join((row["item"], row["name"], row["status"], row["remaining"])) + " |" for row in items]
    files["documentary/examination.md"] = ("\n".join(lines) + "\n").encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"floor": floor_hash, "rights": rights_hash}, "sourceProvenance": provenance,
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "original RIGHTS assembly manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files)
    value = _manifest(files, expected_hash)
    require(set(value) == {"mode", "profile", "version", "profileHash", "inputs", "sourceProvenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION
        and type(value["inputs"]) is dict and set(value["inputs"]) == {"floor", "rights"},
        "original RIGHTS closed assembly manifest differs")
    require(value["files"] == [base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"],
        "original RIGHTS assembly file commitments differ")
    args = []
    for role in ("floor", "rights"):
        prefix = "captures/" + role + "/"
        args.extend(({path[len(prefix):]: raw for path, raw in files.items() if path.startswith(prefix)}, value["inputs"][role]))
    rebuilt = compose(*args, disclosure="public")
    require(dict(rebuilt.files) == files, "original RIGHTS assembly reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("floor", "rights"):
        build.add_argument("--" + role, type=Path, required=True)
        build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True)
    build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name)
        command.add_argument("directory", type=Path)
        command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles")
    args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "reconciliationProfileHash": joined.PROFILE_HASH,
            "rightsSourceProfileHash": rights_source.PROFILE_HASH}).decode("utf-8"))
        return
    if args.command == "assemble":
        _public(args.disclosure)
        for digest in (args.floor_hash, args.rights_hash):
            require(any(hex_bytes(digest, 32)), "original RIGHTS empty input manifest pin")
        from .repository_exchange import _destination, _publish
        sources = [args.floor, args.rights]
        _destination(args.output, sources)
        result = compose(read_tree(args.floor), args.floor_hash, read_tree(args.rights), args.rights_hash,
            disclosure=args.disclosure)
        require(verify(result.files, result.manifest_hash).files == result.files, "original RIGHTS pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "historicalRights": result.report["historicalRights"]["status"], "floorFamily": result.report["floorFamily"],
        "sourceProvenance": result.report["sourceProvenance"], "canonicalPacketReady": False}).decode("utf-8"))


if __name__ == "__main__":
    main()
