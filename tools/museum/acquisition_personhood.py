"""Join current native personhood evidence to unchanged conservation assemblies."""
import argparse
from copy import deepcopy
from pathlib import Path

from ..metadata import acquisition_personhood_v1 as personhood_definition
from . import acquisition_conservation as conservation
from . import conservation_capture_join as observations
from . import conservation_provider_binding as provider_binding
from . import object_dossier as base
from . import public_personhood_capture as personhood_capture
from . import public_personhood_source as personhood_source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import ZERO, require

MODE = "acquisition_native_personhood_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_NATIVE_PERSONHOOD_ASSEMBLY_V1"
STATUSES = ("not_required_platform_floor", "current_waiver_matches_saved", "current_resolved_summary_matches_saved",
    "saved_commitment_not_currently_identifiable")
CLAIMS = {"conservationAssemblyReplayed": True, "providerBindingReplayed": True,
    "personhoodCaptureReplayed": True, "originalInputBytesPreserved": True,
    "sharedFloorCaptureExact": True, "sharedSourceObservationsReconciled": True,
    "providerPersonhoodDependenciesJoined": True, "currentNativePersonhoodRetained": True,
    "currentAndOriginalIdentitySeparated": True, "historicalCommitmentCompared": True,
    "nativePersonhoodRepresentationValidated": True, "legacyPacketPersonhoodAdapted": False,
    "historicalSaleTimeCurrentnessProven": False, "historicalProviderExecutionProven": False,
    "runtimeArtifactAuthenticityProven": False, "legalPersonhoodProven": False,
    "institutionalStandingProven": False, "currentSignatureRevalidated": False,
    "completePersonhoodHistoryProven": False, "allPaidRoutesCovered": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "Additive native personhood correspondence over unchanged conservation, provider-binding and personhood "
    "packages. Exact current waiver or resolved-summary hashes are compared with the saved first-sale "
    "commitment. Current operative identity, original personhood-record identity and conservation registration "
    "identity remain separate. A changed current head leaves the historical commitment unidentified rather "
    "than invalid. This does not prove legal personhood, institutional standing, current signature authority, "
    "historical sale-time currentness, provider binary authenticity or execution, consensus, actual-chain "
    "acceptance or complete packet conformance.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "inputs": {"conservation": conservation.PROFILE_HASH, "providerBinding": provider_binding.PROFILE_HASH,
        "personhoodCapture": personhood_capture.PROFILE_HASH, "personhoodSource": personhood_source.PROFILE_HASH},
    "nativePersonhoodSchemaHash": personhood_definition.SCHEMA_HASH,
    "observationSemanticsProfileHash": observations.PROFILE_HASH,
    "statuses": list(STATUSES),
    "identity": "Keep conservation registration identity, original op24 subject identity and source-block operative identity as three explicit fields.",
    "history": "The targeted current getter has no reverse summary-hash index and is not a historical-head denominator. Current mismatch is unresolved historical correspondence, never absence.",
    "packet": "Preserve the V4 conservation fragment byte-for-byte and add a validated standalone native-personhood fragment. The legacy V4 personhood field remains unchanged because its authority and collection shape differs. Items 6 and 13 remain partial pending full-packet integration and attribution dependencies.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "native personhood assembly requires public disclosure before reads")


def _state(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _capture(files, prefix):
    return {path.removeprefix(prefix): body for path, body in files.items() if path.startswith(prefix)}


def _same_floor(conservation_files, binding_files):
    left = _capture(conservation_files, "captures/floor/")
    right = _capture(binding_files, "rights-assembly/captures/floor/")
    require(left and left == right, "native personhood shared floor capture differs")
    return left


def _pins(anchor, pins):
    rows = anchor.get("codePins")
    require(type(rows) is list and 0 < len(rows) <= 256, "native personhood pin inventory")
    for row in rows:
        require(type(row) is dict and set(row) == {"address", "runtimeHash"}, "native personhood pin row")
        address, digest = row["address"], row["runtimeHash"]
        require(address not in pins or pins[address] == digest, "native personhood shared runtime differs")
        pins[address] = digest


def _reconcile(conservation_files, binding_files, personhood_files):
    base_inputs = {role: {kind: conservation_files["captures/" + role + "/source/" + kind + ".json"]
        for kind in ("anchor", "transcript")} for role in ("tier", "selection", "floor")}
    a, calls, hashes, pins, total, count = observations._inputs(base_inputs)
    additions = {
        "rights": (binding_files["rights-assembly/captures/rights/source/anchor.json"],
            binding_files["rights-assembly/captures/rights/source/transcript.json"]),
        "provider": (binding_files["provider-capture/source/anchor.json"],
            binding_files["provider-capture/source/transcript.json"]),
        "personhood": (personhood_files["source/anchor.json"], personhood_files["source/transcript.json"])}
    for role, (raw_anchor, raw_transcript) in additions.items():
        anchor = loads(raw_anchor, maximum=524288, canonical=True)
        require({key: anchor[key] for key in observations.COMMON} == a,
            "native personhood common anchor differs")
        _pins(anchor, pins)
        transcript = loads(raw_transcript, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(type(transcript) is dict and set(transcript) == {"version", "profile", "calls"}
            and transcript["version"] == observations.rpc.VERSION
            and transcript["profile"] == observations.rpc.PROFILE and type(transcript["calls"]) is list,
            "native personhood transcript shape/profile")
        total += len(raw_anchor) + len(raw_transcript); count += len(transcript["calls"])
        require(total <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS,
            "native personhood aggregate evidence bound")
        calls[role] = transcript["calls"]
        hashes[role] = {"anchorHash": keccak256(raw_anchor), "transcriptHash": keccak256(raw_transcript)}
    counts = observations._observations(a, calls, pins)
    return {"sourceState": a, "inputs": hashes,
        "counts": {"inputBytes": str(total), "rowOccurrences": str(count), **counts},
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _join(conservation_files, binding_files, personhood_files):
    conservation_report = _state(conservation_files, "packet/assembly.json")
    documentary_joins = _state(conservation_files, "packet/documentary-joins.json")
    floor = _state(conservation_files, "captures/floor/source/snapshot.json")
    binding = _state(binding_files, "provider-binding/binding.json")
    snapshot = _state(personhood_files, "source/snapshot.json")
    configuration = binding["configuration"]; targets, hashes = configuration[:2]
    source_anchor = snapshot["source"]
    pins = {row["address"]: row["runtimeHash"] for row in source_anchor["codePins"]}
    for index, key in ((0, "core"), (1, "host"), (8, "artistRegistry")):
        require(targets[index] == source_anchor[key] and pins.get(source_anchor[key]) == hashes[index],
            "native personhood provider dependency differs")
    first = floor["floor"]["firstSale"]
    require(first is not None, "native personhood first-sale receipt required")
    saved = documentary_joins["firstSale"]["facts"]
    current, native = snapshot["current"], snapshot["native"]
    tier = first["effectiveTier"]
    require(tier != "CONSERVATION_WAIVED", "native personhood provider binding cannot contain a waived floor")
    if saved["platformWorks"]:
        status = "not_required_platform_floor"
    elif current["artistId"] == saved["artistId"] and current["status"] == "WAIVER" \
            and current["evidenceHash"] == saved["personhoodEvidenceHash"]:
        require(current["evidenceHashDomain"] == "native_op24_record" and native is not None
            and native["recordHash"] == current["evidenceHash"], "native personhood waiver hash domain differs")
        status = "current_waiver_matches_saved"
    elif current["artistId"] == saved["artistId"] and current["status"] == "RESOLVED" \
            and current["evidenceHash"] == saved["personhoodEvidenceHash"]:
        require(current["evidenceHashDomain"] == "personhood_proof_summary" and native is not None
            and native["summaryHash"] == current["evidenceHash"], "native personhood summary hash domain differs")
        status = "current_resolved_summary_matches_saved"
    else:
        status = "saved_commitment_not_currently_identifiable"
    registration = saved["identityRecordHash"]
    historical = documentary_joins["firstSale"]["joins"]["identityRecordHash"]
    original_identity = ZERO if native is None else native["record"][1]
    fragment = {"profile": PROFILE, "version": "1", "status": status,
        "sourceState": conservation_report["fields"]["sourceState"],
        "firstSale": {"receiptHash": first["receiptHash"], "effectiveTier": tier,
            "artistId": saved["artistId"], "registrationIdentityRecordHash": registration,
            "personhoodEvidenceHash": saved["personhoodEvidenceHash"], "platformWorks": saved["platformWorks"]},
        "current": {"artistId": current["artistId"], "status": current["status"],
            "evidenceHash": current["evidenceHash"], "evidenceHashDomain": current["evidenceHashDomain"],
            "registrationIdentityRecordHash": current["registrationIdentityRecordHash"],
            "originalPersonhoodIdentityRecordHash": original_identity,
            "operativeIdentityRecordHash": current["operativeIdentityRecordHash"],
            "identityCurrent": current["identityCurrent"], "notarizationCurrent": current["notarizationCurrent"]},
        "historicalRegistrationIdentityJoin": historical,
        "providerBindingStatus": binding["status"],
        "legalPersonhoodProven": False, "historicalSaleTimeCurrentnessProven": False,
        "canonicalNotarizationFieldReady": False}
    require(status in STATUSES, "native personhood status")
    return fragment


def _native_personhood(personhood_files, personhood_hash):
    raw_snapshot = personhood_files["source/snapshot.json"]
    snapshot = loads(raw_snapshot, maximum=MAX_BYTES, canonical=True)
    source_ref = {"manifestHash": personhood_hash,
        "anchorHash": keccak256(personhood_files["source/anchor.json"]),
        "transcriptHash": keccak256(personhood_files["source/transcript.json"]),
        "snapshotHash": keccak256(raw_snapshot), "sourceProfileHash": personhood_source.PROFILE_HASH,
        "captureProfileHash": personhood_capture.PROFILE_HASH}
    value = personhood_definition.semanticProjection(snapshot, source_ref)
    raw = dumps(value)
    require(personhood_definition.validate(raw) == value,
        "native personhood supplied-data representation differs")
    return value, raw


def compose(conservation_files, conservation_hash, binding_files, binding_hash,
        personhood_files, personhood_hash, *, disclosure):
    _public(disclosure)
    conserved = conservation.verify(conservation_files, conservation_hash)
    bound = provider_binding.verify(binding_files, binding_hash)
    retained = personhood_capture.verify(personhood_files, personhood_hash)
    require(conserved.report["sourceProvenance"] == bound.report["sourceProvenance"] == retained.report["provenance"],
        "native personhood source provenance differs")
    old, binding_files, personhood_files = dict(conserved.files), dict(bound.files), dict(retained.files)
    _same_floor(old, binding_files)
    reconciliation = _reconcile(old, binding_files, personhood_files)
    fragment = _join(old, binding_files, personhood_files)
    native_personhood, native_personhood_raw = _native_personhood(personhood_files, personhood_hash)
    items = deepcopy(conserved.report["items"])
    for item in items: item["evidence"] = ["conservation-assembly/" + path for path in item["evidence"]]
    items[5].update(status="partial", canonicalPacketCompatible=False,
        evidence=["packet/personhood.json", "packet/native-personhood.json", "packet/source-reconciliation.json",
            "personhood-capture/source/snapshot.json"],
        remaining="Current native personhood, the saved floor correspondence and exact General payload are retained when available in the standalone validated fragment. The legacy V4 field remains unchanged; full-packet integration, attribution dependencies, legal personhood, institutional standing and complete historical coverage remain unresolved.")
    items[12]["evidence"] += ["packet/personhood.json", "provider-binding/provider-binding/binding.json"]
    report = {"profile": PROFILE, "version": "1", "sourceState": conserved.report["fields"]["sourceState"],
        "sourceProvenance": conserved.report["sourceProvenance"], "personhood": fragment,
        "nativePersonhood": {"schema": personhood_definition.NAME,
            "schemaHash": personhood_definition.SCHEMA_HASH,
            "status": "native_supplied_data_fragment_validated",
            "path": "packet/native-personhood.json", "sourceRef": native_personhood["sourceRef"],
            "legacyPacketPersonhoodAdapted": False},
        "items": items, "unresolvedItems": [row["item"] for row in items if row["status"] != "derived_within_source_profile"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {"conservation-assembly/" + path: body for path, body in old.items()}
    files.update({"provider-binding/" + path: body for path, body in binding_files.items()})
    files.update({"personhood-capture/" + path: body for path, body in personhood_files.items()})
    files.update({"definitions/personhood-assembly-profile.json": PROFILE_BYTES,
        "definitions/native-personhood-schema.json": personhood_definition.SCHEMA_BYTES,
        "packet/personhood.json": dumps(fragment), "packet/native-personhood.json": native_personhood_raw,
        "packet/source-reconciliation.json": dumps(reconciliation),
        "packet/assembly.json": dumps(report)})
    lines = ["# Native personhood: partial acquisition assembly", "", QUALIFICATION, "",
        "Personhood correspondence status: `" + fragment["status"] + "`.", "",
        "The three input packages remain unchanged in their own directories.", ""]
    files["packet/examination.md"] = "\n".join(lines).encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"conservation": conservation_hash, "providerBinding": binding_hash, "personhood": personhood_hash},
        "sourceProvenance": report["sourceProvenance"],
        "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "native personhood manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "native personhood external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "files", "claims", "qualification"} and manifest["mode"] == MODE
        and manifest["profile"] == PROFILE and manifest["version"] == "1" and manifest["profileHash"] == PROFILE_HASH
        and set(manifest["inputs"]) == {"conservation", "providerBinding", "personhood"}
        and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
        "native personhood closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "native personhood file commitments differ")
    rebuilt = compose(_capture(files, "conservation-assembly/"), manifest["inputs"]["conservation"],
        _capture(files, "provider-binding/"), manifest["inputs"]["providerBinding"],
        _capture(files, "personhood-capture/"), manifest["inputs"]["personhood"], disclosure="public")
    require(dict(rebuilt.files) == files, "native personhood reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("conservation", "provider-binding", "personhood"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "personhoodCaptureProfileHash": personhood_capture.PROFILE_HASH,
            "personhoodSourceProfileHash": personhood_source.PROFILE_HASH}).decode("utf-8")); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.conservation, args.provider_binding, args.personhood]; _destination(args.output, sources)
        result = compose(read_tree(args.conservation), args.conservation_hash,
            read_tree(args.provider_binding), args.provider_binding_hash,
            read_tree(args.personhood), args.personhood_hash, disclosure="public")
        require(verify(dict(result.files), result.manifest_hash).files == result.files,
            "native personhood pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash); return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "personhoodStatus": result.report["personhood"]["status"],
        "sourceProvenance": result.report["sourceProvenance"], "canonicalPacketReady": False}).decode("utf-8"))


if __name__ == "__main__": main()
