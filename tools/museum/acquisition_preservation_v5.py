"""Historical native masters and prospective references over an unchanged full V5 packet."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from . import acquisition_attribution_v5 as previous
from . import conservation_capture_join as observations
from . import object_dossier as base
from . import public_media_master_capture as masters
from . import public_prospective_reference_capture as references
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import ZERO, require
from .owner_catalog_source import _location

MODE = "acquisition_preservation_v5_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_PRESERVATION_V5_ASSEMBLY_V1"
ORIGINAL_MANIFEST = "inputs/attribution-v5-manifest.json"
PREFIXES = {"masters": "captures/media-masters/", "references": "captures/prospective-reference/"}
PROVIDER_BINDING = "direct-conservation/direct-assembly/provider-binding/provider-binding/binding.json"
CLAIMS = {"allNineteenSuppliedGroupsValidated": True, "originalPacketBytesPreserved": True,
    "nineSourceObservationsReconciled": True, "originalReleasePublicationUsed": True,
    "historicalEvidenceSeparatedFromCurrentState": True, "nativeAndGenericPreservationFieldsSeparated": True,
    "genericMediaClassAuthenticated": False, "genericReferenceSchemaAuthenticated": False,
    "historicalEligibilityReexecuted": False, "archiveDeliveryVerified": False, "browserExecutionVerified": False,
    "postMintReferenceAuthenticated": False, "finalityAuthenticated": False, "sourceCoverageComplete": False,
    "institutionalAcceptance": False, "actualChainAcceptance": False, "sourceConsensusVerified": False,
    "completeCanonicalPacket": False}
QUALIFICATION = (
    "An unchanged attribution-enriched full supplied packet V5 with native media-master and prospective "
    "reference captures. All nineteen requirements and earlier qualifications remain visible. Saved release "
    "hashes are compared with original native preimages and publication chronology. Current selections, "
    "current source and archive liveness remain separate observations. Missing historical inputs remain "
    "unresolved; current values never replace them. Generic V5 media classes and reference-record labels "
    "are supplied statements, not mappings authenticated by these native producers. Prospective named "
    "simulations are not post-mint token renders or finality evidence. Retained archive identities and "
    "coverage do not prove delivery, ZIP contents or browser execution. Historical runtime, authority and "
    "liveness execution, consensus, complete source coverage and institutional acceptance remain unproved.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "previousAssemblyProfileHash": previous.PROFILE_HASH, "masterCaptureProfileHash": masters.PROFILE_HASH,
    "referenceCaptureProfileHash": references.PROFILE_HASH,
    "inputs": ["externally pinned attribution-enriched V5", "externally pinned native master capture",
        "externally pinned native prospective-reference capture"],
    "retention": "Original files retain their paths and bytes; original manifest is retained at " + ORIGINAL_MANIFEST + ".",
    "dependencies": "Original provider targets6 and9 and supported immutable dependencies must match the two added captures.",
    "chronology": "Use the original release receipt, never a later sale that reused it. Matching evidence must precede that release and cannot have been superseded before it. Later replacements remain separate.",
    "coverage": "All nineteen supplied groups remain validated; native sidecars do not invent mediaClass or generic schema mappings.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "preservation V5 requires public disclosure before reads")


def _load(files, path): return loads(files[path], maximum=MAX_BYTES, canonical=True)
def _pos(publication): return tuple(uint(publication[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))


def _reconcile(originals, additional):
    inputs = {path.removesuffix("source/anchor.json"): (raw, originals[path.removesuffix("anchor.json") + "transcript.json"])
        for path, raw in originals.items() if path.endswith("/source/anchor.json")}
    require(len(inputs) == 7, "preservation V5 requires exact seven original capture sources")
    for role, files in additional.items():
        inputs[role] = (files["source/anchor.json"], files["source/transcript.json"])
    common, pins, calls, hashes, size, count = None, {}, {}, {}, 0, 0
    for role, (anchor_raw, transcript_raw) in sorted(inputs.items()):
        anchor = loads(anchor_raw, maximum=observations.MAX_ANCHOR_BYTES, canonical=True)
        state = {key: anchor[key] for key in observations.COMMON}
        require(common is None or state == common, "preservation V5 common source state differs")
        common = state
        own_pins = ({anchor["core"]: anchor["coreRuntimeHash"]} if "coreRuntimeHash" in anchor else
            {row["address"]: row["runtimeHash"] for row in anchor["codePins"]})
        for address, digest in own_pins.items():
            require(address not in pins or pins[address] == digest, "preservation V5 cross-source runtime differs")
            pins[address] = digest
        transcript = loads(transcript_raw, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(transcript["profile"] == observations.rpc.PROFILE and transcript["version"] == observations.rpc.VERSION,
            "preservation V5 transcript profile differs")
        calls[role] = transcript["calls"]; size += len(anchor_raw) + len(transcript_raw); count += len(calls[role])
        require(size <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS, "preservation V5 aggregate source bound")
        hashes[role] = {"anchorHash": keccak256(anchor_raw), "transcriptHash": keccak256(transcript_raw)}
    return {"sourceState": common, "inputs": hashes, "counts": observations._observations(common, calls, pins),
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _provider(originals, additional, snapshots):
    binding = _load(originals, PROVIDER_BINDING)
    targets, hashes = binding["configuration"][:2]
    matched = []
    for role, index, field in (("masters", 6, "mediaMaster"), ("references", 9, "host")):
        anchor = _load(additional[role], "source/anchor.json")
        pins = {row["address"]: row["runtimeHash"] for row in anchor["codePins"]}
        require(anchor[field] == targets[index] and pins[anchor[field]] == hashes[index],
            "preservation V5 original provider producer differs")
        matched.append({"role": role, "index": str(index), "address": targets[index], "runtimeHash": hashes[index]})
        expected = {0: anchor["core"]}
        if role == "masters":
            expected.update({1: anchor["host"], 2: anchor["schemas"], 3: anchor["store"],
                7: anchor["router"], 8: anchor["artistRegistry"]})
        else:
            dependencies = snapshots[role]["dependencies"]
            expected.update({2: dependencies[0][2], 3: dependencies[0][3]})
            floor = _load(originals, "packet/acquisition-packet.json")["conservation"]["floor"]
            require(dependencies[0][1] == floor["sourceState"]["conservationFloor"],
                "preservation V5 prospective permanent floor differs")
        for key, address in expected.items():
            require(targets[key] == address and hashes[key] == pins[address],
                "preservation V5 original provider dependency differs")
            matched.append({"role": role, "index": str(key), "address": address, "runtimeHash": pins[address]})
    return {"sourceId": binding["sourceId"], "configurationHash": binding["configurationHash"],
        "matchedDependencies": matched, "historicalRuntimeExecutionProven": False}


def _master_join(release, snapshot):
    context, facts = release["receipt"][9:]
    result = {"savedEvidenceHash": facts[1], "status": "historical_inputs_not_observed",
        "candidate": None, "selectedHeadAtReleaseMatches": None, "historicalEligibilityReexecuted": False,
        "currentArchiveLivenessRequired": False}
    matches = [row for row in snapshot["historicalCandidates"] if row["factsHash"] == facts[1]]
    if not matches: return result
    if not any(row["publication"] is not None for row in matches):
        result["status"] = "historical_empty_inventory_association_unresolved"
        return result
    # Repeated candidate observations may have the same hash. The original earliest
    # preimage boundary, not a later observation, owns the chronological comparison.
    eligible = [row for row in matches if row["publication"] is not None
        and _pos(row["publication"]) < _pos(release["publication"])]
    require(eligible, "preservation V5 matching master evidence does not precede original release")
    chosen = min(eligible, key=lambda row: _pos(row["publication"]))
    require(chosen["subjectId"] == context[0] and chosen["inventoryHash"] == context[2],
        "preservation V5 master release scope/inventory differs")
    manifests = [row for row in snapshot["manifestSelections"]
        if _pos(row["publication"]) < _pos(release["publication"])]
    require(manifests, "preservation V5 original selected manifest history unavailable")
    selected_manifest = max(manifests, key=lambda row: _pos(row["publication"]))
    pins = {row["address"]: row["runtimeHash"] for row in snapshot["source"]["codePins"]}
    require(selected_manifest["supportedHost"] is True and selected_manifest["manifestHash"] == chosen["manifestHash"]
        and selected_manifest["host"] == snapshot["source"]["host"]
        and selected_manifest["codeHash"] == pins[snapshot["source"]["host"]],
        "preservation V5 selected manifest changed before original release")
    for slot, selected in enumerate(chosen["slotSelections"], 1):
        if chosen["hashes"][slot - 1] == ZERO: continue
        scope = snapshot["slots"][str(slot)]
        rows = [{"selection": selection, "publication": _location(event)}
            for selection, event in zip(scope["history"], scope["events"], strict=True)]
        prior = [row for row in rows if _pos(row["publication"]) < _pos(release["publication"])]
        require(prior, "preservation V5 selected master has no prior selection")
        latest = max(prior, key=lambda row: _pos(row["publication"]))
        require(latest["selection"] == selected, "preservation V5 master superseded before original release")
    result.update(status="original_native_master_evidence_joined", candidate=deepcopy(chosen),
        selectedHeadAtReleaseMatches=True, manifestSelectionAtRelease=deepcopy(selected_manifest))
    return result


def _reference_join(release, snapshot, catalogue):
    context, facts = release["receipt"][9:]
    result = {"savedEvidenceHash": facts[2], "status": "native_reference_not_required",
        "record": None, "headAtReleaseMatches": None, "historicalSourceExecutionRevalidated": False,
        "postMintReferenceAuthenticated": False, "finalityAuthenticated": False}
    if facts[2] == ZERO: return result
    result["status"] = "historical_inputs_not_observed"
    rows = [row for row in snapshot["records"] if row["evidenceHash"] == facts[2]]
    if not rows: return result
    require(len(rows) == 1, "preservation V5 ambiguous prospective evidence hash")
    selected = rows[0]; receipt, original = selected["receipt"], selected["originalSource"]
    require(_pos(selected["publication"]) < _pos(release["publication"]),
        "preservation V5 prospective publication does not precede original release")
    require(receipt[2] == release["collectionId"] and receipt[6:8] == context[:2],
        "preservation V5 prospective collection/scope/membership differs")
    prior = [row for row in snapshot["records"] if _pos(row["publication"]) < _pos(release["publication"])]
    head = max(prior, key=lambda row: _pos(row["publication"]))
    require(head["recordHash"] == selected["recordHash"], "preservation V5 prospective reference superseded before original release")
    admitted = [row for row in catalogue["sources"] if row["sourceId"] == release["sourceId"]]
    require(len(admitted) == 1 and original[:2] == [release["sourceId"], release["sourceSetHash"]]
        and original[2] == admitted[0]["source"] and original[3] == context,
        "preservation V5 prospective original floor source/context differs")
    require(_pos(admitted[0]["admission"]["publication"]) < _pos(selected["publication"]),
        "preservation V5 prospective source admission does not precede publication")
    gas = snapshot["gasHistory"]
    require(all(_pos(row["publication"]) < _pos(release["publication"]) for row in gas["registrations"]),
        "preservation V5 prospective gas registration does not precede release")
    values = {row["parameterId"]: row["genesisValue"] for row in gas["registrations"]}
    for row in gas["updates"]:
        if _pos(row["publication"]) < _pos(release["publication"]): values[row["parameterId"]] = row["newValue"]
    at_release = [values[row["parameterId"]] for row in gas["registrations"]]
    require(selected["originalDependencies"][6:] == at_release,
        "preservation V5 prospective committed gas changed before original release")
    result.update(status="original_native_prospective_evidence_joined", record=deepcopy(selected), headAtReleaseMatches=True)
    return result


def _join(packet, snapshots, provider):
    floor = packet["conservation"]["floor"]
    current = snapshots["references"]["currentSource"]
    if current["status"] == "observed":
        source, media_context = current["source"], snapshots["masters"]["mediaContext"]
        require(source[13] == media_context["manifestHash"] and source[14] == media_context["manifest"]
            and source[9] == media_context["routerServingSource"] and source[3][2] == media_context["inventoryHash"],
            "preservation V5 current source media observations differ")
        current_artist = snapshots["masters"]["currentAssociation"]
        binding = current_artist["binding"]
        require(source[6] == binding[0] and source[7][:4] == [snapshots["masters"]["source"]["artistRegistry"],
            binding[0], binding[4], binding[3]] and source[7][4] == current_artist["attribution"][0],
            "preservation V5 current source Artist observations differ")
    rows = []
    for release in floor["floor"]["releases"]:
        row = {"releaseReceiptHash": release["receiptHash"], "releaseKey": release["releaseKey"],
            "originalPublication": deepcopy(release["publication"]), "sourceId": release["sourceId"],
            "context": deepcopy(release["receipt"][9]), "facts": deepcopy(release["receipt"][10])}
        if release["sourceId"] != provider["sourceId"]:
            row.update(masters={"status": "original_provider_configuration_not_captured"},
                references={"status": "original_provider_configuration_not_captured"})
        else:
            row["masters"] = _master_join(release, snapshots["masters"])
            row["references"] = _reference_join(release, snapshots["references"], floor["catalogue"])
        rows.append(row)
    return {"status": "native_historical_preservation_examined", "releases": rows,
        "currentMediaContext": deepcopy(snapshots["masters"]["mediaContext"]),
        "currentProspectiveSource": deepcopy(snapshots["references"]["currentSource"]),
        "genericPreservation": {"status": "supplied_fields_retained_without_native_mapping",
            "mediaClassInferred": False, "genericSchemaAuthenticated": False,
            "coverageAndFixityAuthenticated": False, "postMintCapturesAuthenticated": False},
        "sourceCoverageComplete": False, "historicalExecutionRevalidated": False}


def compose(packet_files, packet_hash, master_files, master_hash, reference_files, reference_hash, *, disclosure):
    _public(disclosure)
    old = previous.verify(packet_files, packet_hash)
    retained = {"masters": masters.verify(master_files, master_hash), "references": references.verify(reference_files, reference_hash)}
    originals = dict(old.files); additional = {role: dict(value.files) for role, value in retained.items()}
    for value in retained.values():
        require(value.report["provenance"] == old.report["sourceProvenance"], "preservation V5 source provenance differs")
    reconciled = _reconcile(originals, additional)
    snapshots = {role: _load(files, "source/snapshot.json") for role, files in additional.items()}
    provider = _provider(originals, additional, snapshots)
    packet = _load(originals, "packet/acquisition-packet.json")
    join = _join(packet, snapshots, provider)
    items = deepcopy(old.report["items"])
    for item in items:
        if item["item"] == "8":
            item["sourceCoverage"] = "partial"
            item["evidence"] += ["preservation/native-join.json", *[prefix + "source/snapshot.json" for prefix in PREFIXES.values()]]
            item["remaining"] = "Native historical master and prospective-reference facts are retained. Generic media classes, preservation coverage/fixity, post-mint captures and environment labels remain supplied; archive delivery and execution are unproved."
        elif item["item"] == "13":
            item["evidence"].append("preservation/native-join.json")
            item["remaining"] = "Saved release master/reference commitments are examined against original native inputs and chronology. Unresolved historical inputs, original eligibility execution and full documentary prerequisites remain qualified."
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "sourceState": packet["sourceState"], "packetHash": old.report["packetHash"], "packetSchema": old.report["packetSchema"],
        "suppliedPacketValidated": True, "nativePreservationJoin": join, "providerBinding": provider,
        "sourceReconciliation": reconciled, "items": items, "unresolvedSourceItems": old.report["unresolvedSourceItems"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    additions = {ORIGINAL_MANIFEST: originals["manifest.json"], "definitions/preservation-v5-assembly-profile.json": PROFILE_BYTES,
        "preservation/native-join.json": dumps(join), "preservation/assembly.json": dumps(report),
        "preservation/examination.md": ("# Historical masters and prospective references\n\n" + QUALIFICATION + "\n").encode("utf-8")}
    for role, files in additional.items(): additions.update({PREFIXES[role] + path: raw for path, raw in files.items()})
    files = {path: raw for path, raw in originals.items() if path != "manifest.json"}
    require(not set(files).intersection(additions), "preservation V5 retention path collision")
    files.update(additions); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"packet": packet_hash, "masters": master_hash, "references": reference_hash},
        "sourceProvenance": report["sourceProvenance"], "files": [base._ref(path, raw) for path, raw in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "preservation V5 manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "preservation V5 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs", "sourceProvenance", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"packet", "masters", "references"},
        "preservation V5 closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "preservation V5 file commitments differ")
    require(ORIGINAL_MANIFEST in files, "preservation V5 original manifest missing")
    original_manifest = loads(files[ORIGINAL_MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    require(type(original_manifest) is dict and type(original_manifest.get("files")) is list, "preservation V5 original inventory missing")
    try:
        original = {row["path"]: files[row["path"]] for row in original_manifest["files"]}
        original["manifest.json"] = files[ORIGINAL_MANIFEST]
        additional = {role: {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}
            for role, prefix in PREFIXES.items()}
        result = compose(original, manifest["inputs"]["packet"], additional["masters"], manifest["inputs"]["masters"],
            additional["references"], manifest["inputs"]["references"], disclosure="public")
    except (KeyError, TypeError) as exc: raise MuseumError("preservation V5 original input reconstruction failed") from exc
    require(dict(result.files) == files, "preservation V5 reconstruction differs")
    return result


def export_supplied_packet(files, expected_hash):
    return dict(verify(files, expected_hash).files)["packet/acquisition-packet.json"]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("packet", "masters", "references"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "export-supplied-packet", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "previousAssemblyProfileHash": previous.PROFILE_HASH,
            "masterCaptureProfileHash": masters.PROFILE_HASH, "referenceCaptureProfileHash": references.PROFILE_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.packet, args.masters, args.references]; _destination(args.output, sources)
        result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.masters), args.masters_hash,
            read_tree(args.references), args.references_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "preservation V5 publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet": complete_packet(read_tree(args.directory), args.manifest_hash); return
    elif args.command == "export-supplied-packet":
        raw = export_supplied_packet(read_tree(args.directory), args.manifest_hash)
        binary = getattr(sys.stdout, "buffer", None)
        if binary is not None: binary.write(raw)
        else: sys.stdout.write(raw.decode("utf-8"))
        return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "suppliedPacketValidated": True, "sourceCoverageComplete": False, "canonicalPacketReady": False}).decode())


if __name__ == "__main__": main()
