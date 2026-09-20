"""Add actual tier and selection captures to an unchanged native DIRECT assembly."""
import argparse
from copy import deepcopy
from pathlib import Path

from ..metadata import acquisition_conservation_context_v1 as context_definition
from ..metadata import acquisition_packet_v4 as v4
from . import acquisition_conservation as shared
from . import acquisition_direct_personhood as direct
from . import acquisition_personhood as native
from . import conservation_capture_join as observations
from . import conservation_rights_join as rights_join
from . import object_dossier as base
from . import public_conservation_capture as selection_capture
from . import public_conservation_source as selection_source
from . import public_conservation_tier_capture as tier_capture
from . import public_conservation_tier_source as tier_source
from . import public_conservation_provider_source as provider_source
from . import public_personhood_source as personhood_source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import ZERO, require

MODE = "acquisition_direct_conservation_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_DIRECT_CONSERVATION_ASSEMBLY_V1"
CLAIMS = {"threeOriginalPackagesReplayed": True, "sixSourceObservationsReconciled": True,
    "originalInputBytesPreserved": True, "nativeContextRepresentationValidated": True,
    "originalProviderSelectionDependenciesCompared": True, "fourSelectionLanesRetained": True,
    "directTokenCompletedMintChronologyJoined": True, "saleTimeTierCompared": True,
    "currentAndHistoricalSelectionsSeparated": True, "savedDocumentaryCommitmentsCompared": True,
    "historicalRouterStateProven": False, "tokenOperationIdentityProven": False,
    "historicalProviderExecutionProven": False, "historicalEligibilityReexecuted": False,
    "documentaryTruthProven": False, "signatureRevalidated": False, "legalPersonhoodProven": False,
    "masterArchiveEvidenceComplete": False, "allPaidRoutesCovered": False,
    "universalProjectionSynthesized": False, "v4PacketCompatible": False,
    "sourceConsensusVerified": False, "nativeRuntimeAcceptance": False,
    "actualChainAcceptance": False, "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "Additive tier, selection and documentary correspondence over an unchanged DIRECT-personhood assembly. "
    "Six actual original source transcripts are replayed and reconciled at one block. The provider's saved "
    "selector is matched for artist-bound floors even though constructor validation skipped that target; "
    "runtime selection reads consume it. Platform floors skip that read and retain the saved selector "
    "without a historical-use claim. Each recorded DIRECT token's completed mint must precede its paid floor receipt, with the "
    "same Core collection identity at the source. Original declaration positions determine sale-time tier; "
    "current tier and all four current selection lanes remain distinct. Saved intent/waiver, registration "
    "and interview commitments are compared with the collection Artist history strictly before first sale, "
    "including a superseded matching record. This does not reexecute historical authority, prove token-to-"
    "operation correspondence, documentary truth, native runtime or actual-chain acceptance. Earlier RIGHTS "
    "and personhood correspondence keeps its original qualifications. The standalone "
    "context, DIRECT and personhood fragments do not change V4 or form a complete acquisition packet.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "inputs": {"directAssembly": direct.PROFILE_HASH, "tierCapture": tier_capture.PROFILE_HASH,
        "selectionCapture": selection_capture.PROFILE_HASH}, "contextSchemaHash": context_definition.SCHEMA_HASH,
    "observationSemanticsProfileHash": observations.PROFILE_HASH,
    "nativeProducerReviews": {"provider": provider_source.SOURCE_REVISION,
        "direct": direct.direct_source.SOURCE_REVISION},
    "sources": "DIRECT floor, RIGHTS, provider, personhood, tier and selection original triplets. No anchor projection, source substitution or synthetic universal receipt.",
    "binding": "Original provider targets 0/1/2/3/7/8 and saved code hashes match captured Core/Metadata/schema/Store/router/Artist. Artist-bound floors additionally match target5 selector/hash, consumed by currentCollectionRecords even though skipped at construction. Platform floors do not require that skipped selector read. Router/finality source binding is checked at the source block, not rederived historically.",
    "tier": "Each DIRECT token joins an actual completed mint before its paid floor event and the same retained allocation/lifecycle identity. First-sale, release and DIRECT tiers agree with the declaration preceding their original position, or prospective undeclared LITE. Allocation alone is insufficient.",
    "documentary": "Exact original Metadata and native Artist collection selection before first sale; intent and waiver are distinct native kinds. The latest prior selection is reported separately from matching saved history and the current head. Interview digest retains the complete original selection and exact dependency preimage.",
    "packet": "Standalone context plus unchanged native DIRECT/personhood fragments. Items 2/19 derive token identity; items 6/13 remain partial with all 19 visible. Complete-packet verifies then refuses.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "DIRECT conservation requires public disclosure before reads")


def _state(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _capture(files, prefix):
    return {path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)}


def _reconcile(direct_files, tier_files, selection_files):
    binding = _capture(direct_files, "provider-binding/")
    inputs = {role: {kind: binding["rights-assembly/captures/" + role + "/source/" + kind + ".json"]
        for kind in ("anchor", "transcript")} for role in ("rights", "floor")}
    a, family, calls, hashes, pins, total, count = rights_join._inputs(inputs)
    require(family == "direct_primary_v1", "DIRECT conservation floor family differs")
    additions = {
        "provider": (_capture(binding, "provider-capture/"), provider_source.PROFILE),
        "personhood": (_capture(direct_files, "personhood-capture/"), personhood_source.PROFILE),
        "tier": (tier_files, tier_source.PROFILE), "selection": (selection_files, selection_source.PROFILE)}
    for role, (files, profile) in additions.items():
        raw_anchor, raw_transcript = (files["source/" + key + ".json"] for key in ("anchor", "transcript"))
        anchor = loads(raw_anchor, maximum=524288, canonical=True)
        require(anchor["profile"] == profile and {key: anchor[key] for key in observations.COMMON} == a,
            "DIRECT conservation common anchor/profile differs")
        if role == "tier":
            require(pins.get(anchor["core"]) == anchor["coreRuntimeHash"], "DIRECT conservation tier Core runtime differs")
        else: native._pins(anchor, pins)
        transcript = loads(raw_transcript, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(type(transcript) is dict and set(transcript) == {"version", "profile", "calls"}
            and type(transcript["version"]) is int and transcript["version"] == observations.rpc.VERSION
            and transcript["profile"] == observations.rpc.PROFILE and type(transcript["calls"]) is list,
            "DIRECT conservation transcript shape/profile")
        total += len(raw_anchor) + len(raw_transcript); count += len(transcript["calls"])
        require(total <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS,
            "DIRECT conservation aggregate evidence bound")
        calls[role] = transcript["calls"]
        hashes[role] = {"anchorHash": keccak256(raw_anchor), "transcriptHash": keccak256(raw_transcript)}
    counts = observations._observations(a, calls, pins)
    return {"sourceState": a, "floorFamily": family, "inputs": hashes,
        "counts": {"inputBytes": str(total), "rowOccurrences": str(count), **counts},
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _provider_binding(direct_files, selection, floor):
    binding = _state(direct_files, "provider-binding/provider-binding/binding.json")
    targets, hashes = binding["configuration"][:2]
    anchor = selection["source"]; pins = {p["address"]: p["runtimeHash"] for p in anchor["codePins"]}
    platform = floor["floor"]["firstSale"]["receipt"][8][7]
    matches = []
    for index, key in ((0, "core"), (1, "host"), (2, "schemas"), (3, "store"),
            (5, "conservationSelector"), (7, "router"), (8, "artistRegistry")):
        if index == 5 and platform: continue
        require(targets[index] == anchor[key] and hashes[index] == pins[anchor[key]],
            "DIRECT conservation original provider selection dependency differs")
        matches.append({"index": str(index), "address": targets[index], "runtimeHash": hashes[index],
            "selectionAnchorField": key})
    rights_anchor = _state(direct_files, "provider-binding/rights-assembly/captures/rights/source/anchor.json")
    require(rights_anchor["tokenId"] == anchor["tokenId"], "DIRECT conservation RIGHTS/selection target token differs")
    return {"status": "saved_provider_selector_not_required_by_original_platform_floor" if platform else "original_provider_selection_dependencies_joined", "matchedDependencies": matches,
        "configurationHash": binding["configurationHash"], "sourceId": binding["sourceId"],
        "savedSelector": {"address": targets[5], "runtimeHash": hashes[5]},
        "sourceBlockSelector": {"address": anchor["conservationSelector"], "runtimeHash": pins[anchor["conservationSelector"]]},
        "constructorSkippedSelectorValidation": True, "selectionReadConsumesSavedSelector": not platform,
        "historicalRouterStateProven": False, "historicalProviderExecutionProven": False}


def _tier_join(tier, selection, floor):
    state = shared._state(selection, tier)
    declaration = tier["tier"]["declaration"]
    tier_rows = [floor["floor"]["firstSale"], *floor["floor"]["releases"], *floor["floor"]["directSales"]]
    require(tier_rows[0] is not None, "DIRECT conservation first sale required")
    for row in tier_rows:
        expected = declaration["tier"] if declaration and v4._pos(declaration["publication"]) < v4._pos(row["publication"]) else "MUSEUM_GRADE_LITE"
        require(row["effectiveTier"] == expected, "DIRECT conservation historical sale tier differs")
    joined = []
    for sale in floor["floor"]["directSales"]:
        original = sale["originalSale"]["tokenIdentity"]
        allocations = [row for row in tier["allocations"] if row["tokenId"] == sale["tokenId"]]
        mints = [row for row in tier["completedMints"] if row["tokenId"] == sale["tokenId"]]
        require(len(allocations) == len(mints) == 1, "DIRECT conservation sale token completed mint missing/ambiguous")
        allocation, mint = allocations[0], mints[0]
        require(all(original[key] == allocation[key] for key in ("collectionSerial", "lifecycle"))
            and original["collectionId"] == sale["collectionId"] == state["collectionId"]
            and allocation["status"] == ("burned" if original["burned"] else "minted")
            and mint["collectionSerial"] == original["collectionSerial"], "DIRECT conservation sale token identity differs")
        require(v4._pos(mint["publication"]) < v4._pos(sale["publication"]),
            "DIRECT conservation paid floor precedes completed token mint")
        joined.append({"tokenId": sale["tokenId"], "receiptHash": sale["receiptHash"],
            "tokenIdentity": deepcopy(original), "completedMint": deepcopy(mint),
            "paidPublication": deepcopy(sale["publication"]), "tokenOperationIdentityProven": False})
    selected = [row for row in joined if row["tokenId"] == state["tokenId"]]
    require(len(selected) == 1 and all(selected[0]["tokenIdentity"][key] == selection["identity"][key]
        for key in ("collectionId", "collectionSerial", "burned", "lifecycle")),
        "DIRECT conservation selected token paid receipt missing/ambiguous")
    return state, {"status": "original_tier_and_completed_direct_tokens_joined",
        "firstSaleTier": tier_rows[0]["effectiveTier"], "currentTier": deepcopy(tier["tier"]),
        "targetTokenId": state["tokenId"], "directTokens": joined,
        "historicalDeclarationPositionsChecked": True, "tokenOperationIdentityProven": False}


def _documentary(selection, floor):
    report = shared._documentary_joins(selection, floor)
    first = report["firstSale"]; receipt = floor["floor"]["firstSale"]
    lane = selection["scopes"]["collection"]["origins"]["artist"]
    def describe(selected, event):
        return {"recordHash": selected[0][0], "recordKind": selected[0][1],
            "artistId": selected[1][0], "registrationIdentityRecordHash": selected[1][3],
            "revision": selected[9], "selectionHash": selected[12], "publication": v4._pub(event)}
    prior = [(selected, event) for selected, event in zip(lane["history"], lane["events"], strict=True)
        if v4._pos(v4._pub(event)) < v4._pos(receipt["publication"])]
    latest = describe(*prior[-1]) if prior else None
    first["selectionAtFirstSale"] = latest
    first["currentArtistSelection"] = None if lane["status"] == "absent_on_bound_selector" else describe(lane["current"], lane["events"][-1])
    first["observedSelectedHeadMatchesSavedRecord"] = None
    facts, joins = first["facts"], first["joins"]
    matching = [value for value in joins.values() if value["status"] == "original_selected_history_joined"]
    if matching:
        match = matching[0]
        is_latest = latest is not None and latest["selectionHash"] == match["selectionHash"]
        first["observedSelectedHeadMatchesSavedRecord"] = is_latest
        if not is_latest:
            for value in matching: value["status"] = "original_selected_history_joined_but_superseded"
    first["savedArtistId"] = facts["artistId"]
    report["historicalEligibilityReexecuted"] = False
    report["historicalRouterStateProven"] = False
    report["qualification"] = ("Exact saved collection Artist history and interview dependency commitments are compared. "
        "Latest pre-sale selection and the current head remain separate. A superseded or missing match does not "
        "invalidate an immutable sale. No legal truth, historical provider execution or complete documentary prerequisites are proved.")
    return report


def _source_ref(files, digest, capture, source):
    return {"manifestHash": digest, "anchorHash": keccak256(files["source/anchor.json"]),
        "transcriptHash": keccak256(files["source/transcript.json"]),
        "snapshotHash": keccak256(files["source/snapshot.json"]),
        "captureProfileHash": capture.PROFILE_HASH, "sourceProfileHash": source.PROFILE_HASH}


def compose(direct_files, direct_hash, tier_files, tier_hash, selection_files, selection_hash, *, disclosure):
    _public(disclosure)
    old = direct.verify(direct_files, direct_hash)
    tier_package = tier_capture.verify(tier_files, tier_hash)
    selection_package = selection_capture.verify(selection_files, selection_hash)
    require(old.report["sourceProvenance"] == tier_package.report["provenance"] == selection_package.report["provenance"],
        "DIRECT conservation source provenance differs")
    direct_files, tier_files, selection_files = dict(old.files), dict(tier_package.files), dict(selection_package.files)
    reconciliation = _reconcile(direct_files, tier_files, selection_files)
    tier, selection = _state(tier_files, "source/snapshot.json"), _state(selection_files, "source/snapshot.json")
    floor = _state(direct_files, "provider-binding/rights-assembly/captures/floor/source/snapshot.json")
    binding = _provider_binding(direct_files, selection, floor)
    state, tier_join = _tier_join(tier, selection, floor)
    refs = {"tier": _source_ref(tier_files, tier_hash, tier_capture, tier_source),
        "selection": _source_ref(selection_files, selection_hash, selection_capture, selection_source)}
    context = context_definition.semanticProjection(tier, selection, refs, state)
    context_raw = dumps(context)
    require(context_definition.validate(context_raw) == context, "DIRECT conservation context representation differs")
    documentary = _documentary(selection, floor)
    prior_rights = _state(direct_files, "provider-binding/rights-assembly/documentary/historical-rights.json")
    documentary["firstSale"]["joins"]["rightsRecordHash"].update(status=prior_rights["status"],
        evidencePath="direct-assembly/provider-binding/rights-assembly/documentary/historical-rights.json",
        observedSelectedHeadMatchesSavedRecord=prior_rights["observedSelectedHeadMatchesSavedRecord"])
    documentary["firstSale"]["joins"]["personhoodEvidenceHash"].update(status=old.report["personhood"]["status"],
        evidencePath="direct-assembly/documentary/personhood.json", historicalSaleTimeCurrentnessProven=False)
    personhood = deepcopy(old.report["personhood"])
    personhood["historicalRegistrationIdentityJoin"] = deepcopy(documentary["firstSale"]["joins"]["identityRecordHash"])
    items = deepcopy(old.report["items"])
    for item in items: item["evidence"] = ["direct-assembly/" + path for path in item["evidence"]]
    for index in (1, 18):
        items[index].update(status="derived_within_source_profile", canonicalPacketCompatible=True,
            evidence=["packet/assembly.json#/fields/sourceState", "packet/tier-join.json"], remaining="")
    items[5]["evidence"] += ["packet/documentary-joins.json", "captures/selection/source/snapshot.json"]
    items[5]["remaining"] = "Native personhood and saved registration correspondence are retained alongside current binding/attribution observations. Complete attribution/sanction evidence, legal personhood and full-packet native authority/scope representation remain unresolved."
    items[12].update(status="partial", canonicalPacketCompatible=False,
        evidence=items[12]["evidence"] + ["packet/conservation-context.json", "packet/tier-join.json",
            "packet/documentary-joins.json", "packet/provider-selection-binding.json", "packet/source-reconciliation.json"],
        remaining="Native current tier and four selection lanes, original DIRECT mint/tier chronology and saved documentary correspondence are retained. Reported unmatched/superseded originals, master/archive/reference and remaining packet requirements still need evidence; V4 remains unchanged.")
    fields = {"sourceState": state, "subjectId": state["subjectId"],
        "erc721Identity": {"core": state["core"], "collectionId": state["collectionId"],
            "globalTokenId": state["tokenId"], "catalogNumber": state["tokenId"], "collectionSerial": state["collectionSerial"]}}
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "fields": fields, "tierJoin": tier_join, "documentary": documentary, "providerSelectionBinding": binding,
        "personhood": personhood, "currentAttributionObservations": deepcopy(selection["currentAssociation"]),
        "nativeContext": {"schema": context_definition.NAME, "schemaHash": context_definition.SCHEMA_HASH,
            "path": "packet/conservation-context.json", "sourceRefs": refs},
        "items": items, "unresolvedItems": [row["item"] for row in items if row["status"] != "derived_within_source_profile"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {"direct-assembly/" + path: raw for path, raw in direct_files.items()}
    files.update({"captures/" + role + "/" + path: raw for role, captured in (("tier", tier_files), ("selection", selection_files))
        for path, raw in captured.items()})
    files.update({"definitions/direct-conservation-profile.json": PROFILE_BYTES,
        "definitions/conservation-context-schema.json": context_definition.SCHEMA_BYTES,
        "packet/conservation-context.json": context_raw, "packet/tier-join.json": dumps(tier_join),
        "packet/provider-selection-binding.json": dumps(binding), "packet/documentary-joins.json": dumps(documentary),
        "packet/source-reconciliation.json": dumps(reconciliation), "packet/assembly.json": dumps(report),
        "packet/examination.md": ("# Native DIRECT conservation: partial acquisition assembly\n\n" + QUALIFICATION +
            "\n\nThe DIRECT assembly, tier capture and selection capture remain unchanged in their own directories.\n").encode("utf-8")})
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"direct": direct_hash, "tier": tier_hash, "selection": selection_hash},
        "sourceProvenance": report["sourceProvenance"], "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "DIRECT conservation manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "DIRECT conservation external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "files", "claims", "qualification"} and manifest["mode"] == MODE
        and manifest["profile"] == PROFILE and manifest["version"] == "1" and manifest["profileHash"] == PROFILE_HASH
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"direct", "tier", "selection"}
        and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
        "DIRECT conservation closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "DIRECT conservation file commitments differ")
    rebuilt = compose(_capture(files, "direct-assembly/"), manifest["inputs"]["direct"],
        _capture(files, "captures/tier/"), manifest["inputs"]["tier"],
        _capture(files, "captures/selection/"), manifest["inputs"]["selection"], disclosure="public")
    require(dict(rebuilt.files) == files, "DIRECT conservation reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("direct", "tier", "selection"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "contextSchemaHash": context_definition.SCHEMA_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.direct, args.tier, args.selection]; _destination(args.output, sources)
        result = compose(read_tree(args.direct), args.direct_hash, read_tree(args.tier), args.tier_hash,
            read_tree(args.selection), args.selection_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "DIRECT conservation publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash); return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "sourceProvenance": result.report["sourceProvenance"], "canonicalPacketReady": False}).decode())


if __name__ == "__main__": main()
