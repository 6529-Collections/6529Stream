"""Bind an original provider configuration to an unchanged historical RIGHTS assembly."""
import argparse
from copy import deepcopy
from pathlib import Path

from . import conservation_capture_join as observations
from . import conservation_rights as original
from . import conservation_rights_join as rights_join
from . import object_dossier as base
from . import public_conservation_provider_capture as capture
from . import public_conservation_provider_source as source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import require

MODE = "conservation_original_provider_binding"
PROFILE = "STREAM_MUSEUM_CONSERVATION_ORIGINAL_PROVIDER_BINDING_V1"
CLAIMS = {"originalRightsAssemblyReplayed": True, "originalProviderCaptureReplayed": True,
    "originalInputBytesPreserved": True, "sharedSourceObservationsReconciled": True,
    "originalProviderConfigurationJoined": True, "originalRightsSelectorPinsJoined": True,
    "originalAndCurrentGasSeparated": True, "runtimeIdentityAdmissionRequired": True,
    "runtimeArtifactAuthenticityProven": False, "historicalProviderEligibilityReexecuted": False,
    "historicalProviderExecutionProven": False, "personhoodProven": False,
    "rightsLegalTruthProven": False, "allPaidRoutesCovered": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "Original provider configuration bound to the non-waived first-sale source admission and the "
    "separately captured RIGHTS selector, Core, Metadata, schema and Store runtime pins. Both prior "
    "packages remain unchanged. This closes configuration identity correspondence within explicit "
    "runtime/provenance admission; a source commit or artifact hash alone is not binary authenticity "
    "proof. Pre-sale selected-record correspondence retains its earlier status, including superseded "
    "or missing records. Immutable binding does not prove historical requireCurrent execution, "
    "personhood, paid Artist acceptance, legal truth or complete packet readiness.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "sourceReviewCommit": source.SOURCE_REVISION,
    "originalAssemblyProfileHash": original.PROFILE_HASH, "providerCaptureProfileHash": capture.PROFILE_HASH,
    "providerSourceProfileHash": source.PROFILE_HASH, "observationSemanticsProfileHash": observations.PROFILE_HASH,
    "inputs": "Exactly one unchanged original RIGHTS assembly and one new provider capture, each externally pinned and fully replayed before binding. Equal provenance and exact common anchor are required.",
    "binding": "FirstSale sourceId names the original admission. Provider address/runtime/configurationHash, Metadata address/runtime, original gas registration chronology, and configuration targets0..4 match exact captured RIGHTS dependencies. All other constructor fields remain retained without unsupported currentness claims.",
    "observations": "The real floor, RIGHTS and provider source triplets are reconciled together without anchor projection, including shared runtime pins, exact RPC outcomes, reciprocal headers, complete receipts and matching log pages.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "provider binding requires public disclosure before reads")


def _state(files, path):
    return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _reconcile(old_files, provider_files):
    inputs = {role: {kind: old_files["captures/" + role + "/source/" + kind + ".json"]
        for kind in ("anchor", "transcript")} for role in ("rights", "floor")}
    a, family, calls, hashes, pins, total, count = rights_join._inputs(inputs)
    raw_anchor = provider_files["source/anchor.json"]
    raw_transcript = provider_files["source/transcript.json"]
    provider = loads(raw_anchor, maximum=source.MAX_ANCHOR, canonical=True)
    require(provider["profile"] == source.PROFILE and {key: provider[key] for key in source.COMMON} == a,
        "provider binding common anchor differs")
    total += len(raw_anchor) + len(raw_transcript)
    require(total <= observations.MAX_INPUT_BYTES, "provider binding aggregate input byte bound")
    transcript = loads(raw_transcript, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
    count += len(transcript["calls"])
    require(count <= observations.MAX_ROWS, "provider binding aggregate row bound")
    for row in provider["codePins"]:
        address, digest = row["address"], row["runtimeHash"]
        require(address not in pins or pins[address] == digest, "provider binding shared runtime differs")
        pins[address] = digest
    calls["provider"] = transcript["calls"]
    hashes["provider"] = {"anchorHash": keccak256(raw_anchor), "transcriptHash": keccak256(raw_transcript)}
    counts = observations._observations(a, calls, pins)
    return {"sourceState": a, "floorFamily": family, "inputs": hashes,
        "counts": {"inputBytes": str(total), "rowOccurrences": str(count), **counts},
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _binding(old_files, provider_files):
    floor = _state(old_files, "captures/floor/source/snapshot.json")
    rights = _state(old_files, "captures/rights/source/snapshot.json")
    provider = _state(provider_files, "source/snapshot.json")
    first = floor["floor"]["firstSale"]
    require(first is not None and first["effectiveTier"] != "CONSERVATION_WAIVED",
        "provider binding requires a non-waived first-sale source")
    source_id = uint(first["sourceId"])
    rows = floor["catalogue"]["sources"]
    require(0 < source_id <= len(rows), "provider binding source ID differs")
    admitted = rows[source_id - 1]
    a, configuration = provider["source"], provider["configuration"]
    pins = {row["address"]: row["runtimeHash"] for row in a["codePins"]}
    require(admitted["provider"] == a["provider"] and admitted["providerCodeHash"] == pins[a["provider"]]
        and admitted["configurationHash"] == provider["configurationHash"] == a["configurationHash"],
        "provider binding original admitted provider/configuration differs")
    targets, hashes = configuration[:2]
    require(admitted["metadata"] == targets[1] and admitted["metadataCodeHash"] == hashes[1],
        "provider binding original Metadata differs")
    rights_anchor = rights["source"]
    rights_pins = {row["address"]: row["runtimeHash"] for row in rights_anchor["codePins"]}
    matched = []
    for index, key in enumerate(("core", "host", "schemas", "store", "rightsSelector")):
        require(targets[index] == rights_anchor[key] and hashes[index] == rights_pins[rights_anchor[key]],
            "provider binding original RIGHTS dependency differs")
        matched.append({"index": str(index), "address": targets[index], "runtimeHash": hashes[index], "rightsAnchorField": key})
    position = lambda row: tuple(uint(row[key]) for key in ("blockNumber", "transactionIndex", "logIndex"))
    admission_at = admitted["admission"]["publication"]
    registered_at = provider["registrationEvents"][-1]["publication"]
    require(position(registered_at) < position(admission_at) < position(first["publication"]),
        "provider binding original registration/admission/sale order differs")
    return {"status": "original_provider_configuration_joined", "sourceId": first["sourceId"],
        "firstSaleReceiptHash": first["receiptHash"], "originalSourceAdmission": admitted,
        "provider": a["provider"], "providerRuntimeHash": pins[a["provider"]],
        "runtimeAdmission": a["runtimeAdmission"], "configurationHash": provider["configurationHash"],
        "configuration": configuration, "configurationRawHex": provider["configurationRawHex"],
        "matchedRightsDependencies": matched, "originalGas": provider["originalGas"], "currentGas": provider["currentGas"],
        "registrationEvents": provider["registrationEvents"],
        "historicalProviderExecutionProven": False, "historicalProviderEligibilityReexecuted": False}


def compose(rights_files, rights_hash, provider_files, provider_hash, *, disclosure):
    _public(disclosure)
    previous = original.verify(rights_files, rights_hash)
    retained = capture.verify(provider_files, provider_hash)
    require(previous.report["sourceProvenance"] == retained.report["provenance"], "provider binding source provenance differs")
    old_files, new_files = dict(previous.files), dict(retained.files)
    reconciliation = _reconcile(old_files, new_files)
    binding = _binding(old_files, new_files)
    items = deepcopy(previous.report["items"])
    for item in items:
        item["evidence"] = ["rights-assembly/" + path for path in item["evidence"]]
    items[12]["evidence"] += ["provider-binding/binding.json", "provider-binding/reconciliation.json"]
    items[12]["remaining"] = ("Provider configuration identity and RIGHTS dependencies are joined. Original pre-sale record correspondence retains its reported status; historical execution, other conservation prerequisites, personhood, archive delivery and complete packet evidence remain unresolved.")
    report = {"profile": PROFILE, "sourceState": previous.report["sourceState"],
        "sourceProvenance": previous.report["sourceProvenance"], "floorFamily": previous.report["floorFamily"],
        "providerBinding": binding, "historicalRightsStatus": previous.report["historicalRights"]["status"],
        "historicalRightsPath": "rights-assembly/documentary/historical-rights.json",
        "items": items, "unresolvedItems": previous.report["unresolvedItems"],
        "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {"rights-assembly/" + path: raw for path, raw in old_files.items()}
    files.update({"provider-capture/" + path: raw for path, raw in new_files.items()})
    files.update({"definitions/provider-binding-profile.json": PROFILE_BYTES,
        "provider-binding/binding.json": dumps(binding), "provider-binding/reconciliation.json": dumps(reconciliation),
        "provider-binding/report.json": dumps(report)})
    lines = ["# Original conservation provider binding", "", QUALIFICATION, "",
        "Historical RIGHTS status: `" + report["historicalRightsStatus"] + "`.", "",
        "Provider configuration status: `" + binding["status"] + "`.", "",
        "The earlier RIGHTS assembly and provider capture remain unchanged in their own directories.", ""]
    files["provider-binding/examination.md"] = "\n".join(lines).encode("utf-8")
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "rightsAssemblyManifestHash": rights_hash, "providerCaptureManifestHash": provider_hash,
        "sourceProvenance": report["sourceProvenance"], "files": [base._ref(path, raw) for path, raw in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "provider binding manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def verify(files, expected_hash):
    files = dict(files)
    base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "provider binding external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash",
        "rightsAssemblyManifestHash", "providerCaptureManifestHash", "sourceProvenance", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION,
        "provider binding closed manifest differs")
    require(manifest["files"] == [base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"],
        "provider binding file commitments differ")
    rebuilt = compose({path.removeprefix("rights-assembly/"): raw for path, raw in files.items() if path.startswith("rights-assembly/")},
        manifest["rightsAssemblyManifestHash"],
        {path.removeprefix("provider-capture/"): raw for path, raw in files.items() if path.startswith("provider-capture/")},
        manifest["providerCaptureManifestHash"], disclosure="public")
    require(dict(rebuilt.files) == files, "provider binding reconstruction differs")
    return rebuilt


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("rights", "provider"):
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
        print(dumps({"bindingProfileHash": PROFILE_HASH, "providerCaptureProfileHash": capture.PROFILE_HASH,
            "providerSourceProfileHash": source.PROFILE_HASH}).decode("utf-8"))
        return
    if args.command == "assemble":
        _public(args.disclosure)
        for digest in (args.rights_hash, args.provider_hash):
            require(any(hex_bytes(digest, 32)), "provider binding empty input manifest pin")
        from .repository_exchange import _destination, _publish
        sources = [args.rights, args.provider]
        _destination(args.output, sources)
        result = compose(read_tree(args.rights), args.rights_hash, read_tree(args.provider), args.provider_hash, disclosure=args.disclosure)
        require(verify(result.files, result.manifest_hash).files == result.files, "provider binding pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash)
        return
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "providerBinding": result.report["providerBinding"]["status"], "historicalRights": result.report["historicalRightsStatus"],
        "sourceProvenance": result.report["sourceProvenance"], "canonicalPacketReady": False}).decode("utf-8"))


if __name__ == "__main__":
    main()
