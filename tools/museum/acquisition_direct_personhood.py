"""Join native DIRECT floor and personhood fragments over original public captures."""
import argparse
from copy import deepcopy
from pathlib import Path

from ..metadata import acquisition_direct_floor_v1 as direct_definition
from ..metadata import acquisition_personhood_v1 as personhood_definition
from . import acquisition_personhood as native
from . import conservation_capture_join as observations
from . import conservation_provider_binding as provider_binding
from . import conservation_rights_join as rights_join
from . import object_dossier as base
from . import public_conservation_provider_source as provider_source
from . import public_direct_conservation_capture as direct_capture
from . import public_direct_conservation_source as direct_source
from . import public_personhood_capture as personhood_capture
from . import public_personhood_source as personhood_source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import ZERO, require

MODE = "acquisition_direct_personhood_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_DIRECT_PERSONHOOD_ASSEMBLY_V1"
STATUSES = native.STATUSES
CLAIMS = {"providerBindingReplayed": True, "personhoodCaptureReplayed": True,
    "originalInputBytesPreserved": True, "fourSourceObservationsReconciled": True,
    "nativeDirectFloorRepresentationValidated": True, "nativePersonhoodRepresentationValidated": True,
    "providerPersonhoodDependenciesJoined": True, "historicalCommitmentCompared": True,
    "currentAndOriginalIdentitySeparated": True, "universalProjectionSynthesized": False,
    "legacyPacketPersonhoodAdapted": False, "tierAndSelectionSourcesJoined": False,
    "historicalSaleTimeCurrentnessProven": False, "historicalProviderExecutionProven": False,
    "runtimeArtifactAuthenticityProven": False, "legalPersonhoodProven": False,
    "institutionalStandingProven": False, "currentSignatureRevalidated": False,
    "completePersonhoodHistoryProven": False, "allPaidRoutesCovered": False,
    "paymentExecutionReproved": False, "sourceConsensusVerified": False,
    "nativeRuntimeAcceptance": False, "actualChainAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "Additive native DIRECT floor and personhood fragments over two unchanged input packages. "
    "The original DIRECT floor, RIGHTS, provider configuration and personhood transcripts are replayed "
    "and reconciled together. Original adapter bindings, paid receipts and native authority remain typed "
    "DIRECT evidence. Current waiver or resolved-summary hashes and artist identity are compared with "
    "the saved first-sale commitment; a changed current head leaves historical correspondence unresolved. "
    "Current registration, original attested operative identity, current operative identity and saved "
    "conservation registration remain distinct. V4 has neither this DIRECT floor representation nor the "
    "native General authority and independent notarization scope. Tier, attribution selection and other "
    "packet prerequisites remain unresolved. No payment or signature reexecution, legal truth, historical "
    "currentness, native runtime, actual-chain acceptance or full packet conformance is established.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "inputs": {"providerBinding": provider_binding.PROFILE_HASH,
        "directFloorCapture": direct_capture.PROFILE_HASH, "directFloorSource": direct_source.PROFILE_HASH,
        "personhoodCapture": personhood_capture.PROFILE_HASH, "personhoodSource": personhood_source.PROFILE_HASH},
    "nativeDirectFloorSchemaHash": direct_definition.SCHEMA_HASH,
    "nativePersonhoodSchemaHash": personhood_definition.SCHEMA_HASH,
    "observationSemanticsProfileHash": observations.PROFILE_HASH,
    "statuses": list(STATUSES),
    "binding": "Require DIRECT-only provider binding and equal source provenance. Reconcile the four actual source triplets, retaining all original profiles. Original configuration targets 0/1/8 must match personhood Core/Metadata/Artist facade and runtime pins.",
    "personhood": "Compare saved first-sale artist ID and evidence hash against current native WAIVER record or RESOLVED Summary domains. Platform floors report not required. Current mismatch is unresolved correspondence, never historical invalidity or absence.",
    "identity": "Saved conservation registration is retained as a commitment. No historical registration record is joined without its selection capture. Do not substitute current registration or operative identity.",
    "packet": "Two standalone supplied-data fragments, not a new packet version. V1-V4 and original captures remain unchanged. All 19 requirement statuses remain visible; items 6 and 13 are partial and complete-packet verifies then refuses.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "DIRECT personhood assembly requires public disclosure before reads")


def _state(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _capture(files, prefix):
    return {path.removeprefix(prefix): body for path, body in files.items() if path.startswith(prefix)}


def _reconcile(binding_files, personhood_files):
    inputs = {role: {kind: binding_files["rights-assembly/captures/" + role + "/source/" + kind + ".json"]
        for kind in ("anchor", "transcript")} for role in ("rights", "floor")}
    a, family, calls, hashes, pins, total, count = rights_join._inputs(inputs)
    require(family == "direct_primary_v1", "DIRECT personhood requires DIRECT floor family")
    additions = {
        "provider": (binding_files["provider-capture/source/anchor.json"],
            binding_files["provider-capture/source/transcript.json"], provider_source.PROFILE),
        "personhood": (personhood_files["source/anchor.json"], personhood_files["source/transcript.json"],
            personhood_source.PROFILE)}
    for role, (raw_anchor, raw_transcript, profile) in additions.items():
        anchor = loads(raw_anchor, maximum=524288, canonical=True)
        require(anchor["profile"] == profile and {key: anchor[key] for key in observations.COMMON} == a,
            "DIRECT personhood common anchor/profile differs")
        native._pins(anchor, pins)
        transcript = loads(raw_transcript, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(type(transcript) is dict and set(transcript) == {"version", "profile", "calls"}
            and type(transcript["version"]) is int and transcript["version"] == observations.rpc.VERSION
            and transcript["profile"] == observations.rpc.PROFILE and type(transcript["calls"]) is list,
            "DIRECT personhood transcript shape/profile")
        total += len(raw_anchor) + len(raw_transcript); count += len(transcript["calls"])
        require(total <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS,
            "DIRECT personhood aggregate evidence bound")
        calls[role] = transcript["calls"]
        hashes[role] = {"anchorHash": keccak256(raw_anchor), "transcriptHash": keccak256(raw_transcript)}
    counts = observations._observations(a, calls, pins)
    return {"sourceState": a, "floorFamily": family, "inputs": hashes,
        "counts": {"inputBytes": str(total), "rowOccurrences": str(count), **counts},
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _join(binding_files, personhood_files, source_state):
    floor = _state(binding_files, "rights-assembly/captures/floor/source/snapshot.json")
    binding = _state(binding_files, "provider-binding/binding.json")
    snapshot = _state(personhood_files, "source/snapshot.json")
    targets, hashes = binding["configuration"][:2]
    source_anchor = snapshot["source"]
    pins = {row["address"]: row["runtimeHash"] for row in source_anchor["codePins"]}
    matched = []
    for index, key in ((0, "core"), (1, "host"), (8, "artistRegistry")):
        require(targets[index] == source_anchor[key] and pins.get(source_anchor[key]) == hashes[index],
            "DIRECT personhood provider dependency differs")
        matched.append({"index": str(index), "address": targets[index], "runtimeHash": hashes[index],
            "personhoodAnchorField": key})
    first = floor["floor"]["firstSale"]
    require(first is not None and first["effectiveTier"] != "CONSERVATION_WAIVED",
        "DIRECT personhood requires a non-waived first sale")
    facts = first["receipt"][8]
    saved = dict(zip(("artistId", "identityRecordHash", "intentRecordHash", "intentWaiverRecordHash",
        "interviewEvidenceHash", "rightsRecordHash", "personhoodEvidenceHash", "platformWorks"), facts))
    current, original = snapshot["current"], snapshot["native"]
    if saved["platformWorks"]:
        status = "not_required_platform_floor"
    elif current["artistId"] == saved["artistId"] and current["status"] == "WAIVER" \
            and current["evidenceHash"] == saved["personhoodEvidenceHash"]:
        require(current["evidenceHashDomain"] == "native_op24_record" and original is not None
            and original["recordHash"] == current["evidenceHash"], "DIRECT personhood waiver hash domain differs")
        status = "current_waiver_matches_saved"
    elif current["artistId"] == saved["artistId"] and current["status"] == "RESOLVED" \
            and current["evidenceHash"] == saved["personhoodEvidenceHash"]:
        require(current["evidenceHashDomain"] == "personhood_proof_summary" and original is not None
            and original["summaryHash"] == current["evidenceHash"], "DIRECT personhood summary hash domain differs")
        status = "current_resolved_summary_matches_saved"
    else:
        status = "saved_commitment_not_currently_identifiable"
    return {"profile": PROFILE, "version": "1", "status": status, "sourceState": source_state,
        "firstSale": {"receiptHash": first["receiptHash"], "effectiveTier": first["effectiveTier"],
            "artistId": saved["artistId"], "registrationIdentityRecordHash": saved["identityRecordHash"],
            "personhoodEvidenceHash": saved["personhoodEvidenceHash"], "platformWorks": saved["platformWorks"]},
        "current": {"artistId": current["artistId"], "status": current["status"],
            "evidenceHash": current["evidenceHash"], "evidenceHashDomain": current["evidenceHashDomain"],
            "registrationIdentityRecordHash": current["registrationIdentityRecordHash"],
            "originalPersonhoodIdentityRecordHash": ZERO if original is None else original["record"][1],
            "operativeIdentityRecordHash": current["operativeIdentityRecordHash"],
            "identityCurrent": current["identityCurrent"], "notarizationCurrent": current["notarizationCurrent"]},
        "historicalRegistrationIdentityJoin": {"status": "selection_source_not_supplied",
            "savedRecordHash": saved["identityRecordHash"], "historicalRecordJoined": False},
        "providerBindingStatus": binding["status"], "matchedPersonhoodDependencies": matched,
        "legalPersonhoodProven": False, "historicalSaleTimeCurrentnessProven": False,
        "canonicalNotarizationFieldReady": False}


def _native_direct(binding_files):
    files = _capture(binding_files, "rights-assembly/captures/floor/")
    raw_snapshot = files["source/snapshot.json"]
    snapshot = loads(raw_snapshot, maximum=MAX_BYTES, canonical=True)
    source_ref = {"manifestHash": keccak256(files["manifest.json"]),
        "anchorHash": keccak256(files["source/anchor.json"]),
        "transcriptHash": keccak256(files["source/transcript.json"]),
        "snapshotHash": keccak256(raw_snapshot), "sourceProfileHash": direct_source.PROFILE_HASH,
        "captureProfileHash": direct_capture.PROFILE_HASH}
    value = direct_definition.semanticProjection(snapshot, source_ref)
    raw = dumps(value)
    require(direct_definition.validate(raw) == value, "native DIRECT supplied-data representation differs")
    return value, raw


def compose(binding_files, binding_hash, personhood_files, personhood_hash, *, disclosure):
    _public(disclosure)
    bound = provider_binding.verify(binding_files, binding_hash)
    retained = personhood_capture.verify(personhood_files, personhood_hash)
    require(bound.report["floorFamily"] == "direct_primary_v1", "DIRECT personhood requires DIRECT floor family")
    require(bound.report["sourceProvenance"] == retained.report["provenance"],
        "DIRECT personhood source provenance differs")
    binding_files, personhood_files = dict(bound.files), dict(retained.files)
    reconciliation = _reconcile(binding_files, personhood_files)
    fragment = _join(binding_files, personhood_files, reconciliation["sourceState"])
    direct, direct_raw = _native_direct(binding_files)
    personhood, personhood_raw = native._native_personhood(personhood_files, personhood_hash)
    items = deepcopy(bound.report["items"])
    for item in items:
        item["evidence"] = ["provider-binding/" + path for path in item["evidence"]]
    items[5].update(status="partial", canonicalPacketCompatible=False,
        evidence=["documentary/personhood.json", "packet/native-personhood.json", "packet/source-reconciliation.json",
            "personhood-capture/source/snapshot.json"],
        remaining="Native personhood and the saved DIRECT floor correspondence are retained. V4 cannot represent native General authority and independent notarization scope. Full-packet integration, attribution dependencies, legal truth and complete historical coverage remain unresolved.")
    items[12].update(status="partial", canonicalPacketCompatible=False,
        evidence=items[12]["evidence"] + ["packet/native-direct-floor.json", "documentary/personhood.json", "packet/source-reconciliation.json"],
        remaining="Native DIRECT receipts, original provider configuration, historical RIGHTS status and personhood correspondence are retained. V4 has no DIRECT floor branch. Tier/default, attribution selection, intent/interview, master/archive and full packet integration remain unresolved.")
    report = {"profile": PROFILE, "version": "1", "sourceState": reconciliation["sourceState"],
        "sourceProvenance": bound.report["sourceProvenance"], "floorFamily": bound.report["floorFamily"],
        "personhood": fragment, "historicalRightsStatus": bound.report["historicalRightsStatus"],
        "nativeDirectFloor": {"schema": direct_definition.NAME, "schemaHash": direct_definition.SCHEMA_HASH,
            "status": "native_supplied_data_fragment_validated", "path": "packet/native-direct-floor.json",
            "sourceRef": direct["sourceRef"], "universalProjectionSynthesized": False},
        "nativePersonhood": {"schema": personhood_definition.NAME, "schemaHash": personhood_definition.SCHEMA_HASH,
            "status": "native_supplied_data_fragment_validated", "path": "packet/native-personhood.json",
            "sourceRef": personhood["sourceRef"], "legacyPacketPersonhoodAdapted": False},
        "items": items, "unresolvedItems": [row["item"] for row in items if row["status"] != "derived_within_source_profile"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {"provider-binding/" + path: body for path, body in binding_files.items()}
    files.update({"personhood-capture/" + path: body for path, body in personhood_files.items()})
    files.update({"definitions/direct-personhood-assembly-profile.json": PROFILE_BYTES,
        "definitions/native-direct-floor-schema.json": direct_definition.SCHEMA_BYTES,
        "definitions/native-personhood-schema.json": personhood_definition.SCHEMA_BYTES,
        "documentary/personhood.json": dumps(fragment), "packet/native-direct-floor.json": direct_raw,
        "packet/native-personhood.json": personhood_raw, "packet/source-reconciliation.json": dumps(reconciliation),
        "packet/assembly.json": dumps(report)})
    files["packet/examination.md"] = ("# DIRECT floor and native personhood: partial acquisition assembly\n\n" +
        QUALIFICATION + "\n\nPersonhood correspondence: `" + fragment["status"] + "`.\n\n" +
        "The provider-binding and personhood input packages remain unchanged in their own directories.\n").encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"providerBinding": binding_hash, "personhood": personhood_hash},
        "sourceProvenance": report["sourceProvenance"],
        "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "DIRECT personhood manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "DIRECT personhood external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "files", "claims", "qualification"} and manifest["mode"] == MODE
        and manifest["profile"] == PROFILE and manifest["version"] == "1" and manifest["profileHash"] == PROFILE_HASH
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"providerBinding", "personhood"}
        and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
        "DIRECT personhood closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "DIRECT personhood file commitments differ")
    rebuilt = compose(_capture(files, "provider-binding/"), manifest["inputs"]["providerBinding"],
        _capture(files, "personhood-capture/"), manifest["inputs"]["personhood"], disclosure="public")
    require(dict(rebuilt.files) == files, "DIRECT personhood reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("provider-binding", "personhood"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "nativeDirectFloorSchemaHash": direct_definition.SCHEMA_HASH,
            "nativePersonhoodSchemaHash": personhood_definition.SCHEMA_HASH}).decode("utf-8")); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.provider_binding, args.personhood]; _destination(args.output, sources)
        result = compose(read_tree(args.provider_binding), args.provider_binding_hash,
            read_tree(args.personhood), args.personhood_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files,
            "DIRECT personhood pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash); return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "personhoodStatus": result.report["personhood"]["status"],
        "sourceProvenance": result.report["sourceProvenance"], "canonicalPacketReady": False}).decode("utf-8"))


if __name__ == "__main__": main()
