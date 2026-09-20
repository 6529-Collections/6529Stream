"""Native attribution and sanction evidence joined to an unchanged full supplied V5 packet."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from . import acquisition_packet_v5 as packet_v5
from . import conservation_capture_join as observations
from . import object_dossier as base
from . import public_attribution_capture as capture
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import ZERO, require

MODE = "acquisition_attribution_v5_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_ATTRIBUTION_V5_ASSEMBLY_V1"
ORIGINAL_MANIFEST = "inputs/packet-v5-manifest.json"
CAPTURE_PREFIX = "captures/attribution/"
STATES = {"1": "claimed", "2": "artist_accepted", "3": "artist_sanctioned", "4": "disputed", "5": "revoked"}
CLAIMS = {"allNineteenSuppliedGroupsValidated": True, "originalPacketBytesPreserved": True,
    "sevenSourceObservationsReconciled": True, "currentAttributionFieldsJoined": True,
    "nativeAuthorityStatusSeparated": True, "originalConfirmationSeparatedFromLatestSanction": True,
    "genericSanctionSchemaAndSubjectAuthenticated": False, "completeBindingAuthorityAuthenticated": False,
    "completeAttestationAuthorityAuthenticated": False, "sourceCoverageComplete": False,
    "currentSignatureRevalidated": False, "institutionalAcceptance": False,
    "actualChainAcceptance": False, "sourceConsensusVerified": False, "completeCanonicalPacket": False}
QUALIFICATION = (
    "An unchanged full supplied packet V5 with an additional native attribution/sanction capture. "
    "All nineteen requirements remain visible. Current attribution, identity authority, original "
    "generation-specific confirmation, latest association sanction and later dispute restoration are "
    "separate facts. Native original record bytes and archives do not authenticate V5's generic "
    "record type, schema or subject labels. No absent transition is inferred from a missing historical "
    "baseline, and native NONE does not imply platform works. Complete binding and attestation "
    "authority, historical finality execution, signatures, documentary truth, runtime admission, "
    "consensus and institutional acceptance remain outside this assembly. Source coverage remains "
    "incomplete; all earlier source and historical qualifications are retained.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "packetAssemblyProfileHash": packet_v5.PROFILE_HASH, "attributionCaptureProfileHash": capture.PROFILE_HASH,
    "inputs": ["externally pinned packet V5 assembly", "externally pinned native attribution capture"],
    "retention": "Original V5 payloads retain their paths and bytes; its manifest is retained at " + ORIGINAL_MANIFEST
        + ". The additional capture retains its complete original tree under " + CAPTURE_PREFIX + ".",
    "sanction": "A retained original confirmation selects its original sanction. Latest association sanction and later restoration remain distinct. Without a retained confirmation, an exact latest sanction can be joined only as unconfirmed.",
    "genericFields": "Only actual native identities and supported fields are matched; generic record type/schema/subject and absent-evidence references are not authenticated.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "attribution V5 requires public disclosure before reads")


def _load(files, path): return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _reconcile(packet_files, capture_files):
    inputs = {path.removesuffix("source/anchor.json"): (raw, packet_files[path.removesuffix("anchor.json") + "transcript.json"])
        for path, raw in packet_files.items() if path.endswith("/source/anchor.json")}
    require(len(inputs) == 6, "attribution V5 requires exact six original capture sources")
    inputs["attribution"] = (capture_files["source/anchor.json"], capture_files["source/transcript.json"])
    common, pins, calls, hashes, size, count = None, {}, {}, {}, 0, 0
    for role, (anchor_raw, transcript_raw) in sorted(inputs.items()):
        anchor = loads(anchor_raw, maximum=observations.MAX_ANCHOR_BYTES, canonical=True)
        state = {key: anchor[key] for key in observations.COMMON}
        require(common is None or state == common, "attribution V5 common source state differs")
        common = state
        own_pins = ({anchor["core"]: anchor["coreRuntimeHash"]} if "coreRuntimeHash" in anchor else
            {row["address"]: row["runtimeHash"] for row in anchor["codePins"]})
        for address, digest in own_pins.items():
            require(address not in pins or pins[address] == digest, "attribution V5 cross-source runtime differs")
            pins[address] = digest
        transcript = loads(transcript_raw, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(transcript["profile"] == observations.rpc.PROFILE and transcript["version"] == observations.rpc.VERSION,
            "attribution V5 source transcript profile differs")
        calls[role] = transcript["calls"]; size += len(anchor_raw) + len(transcript_raw); count += len(calls[role])
        require(size <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS, "attribution V5 aggregate source bound")
        hashes[role] = {"anchorHash": keccak256(anchor_raw), "transcriptHash": keccak256(transcript_raw)}
    return {"sourceState": common, "inputs": hashes, "counts": observations._observations(common, calls, pins),
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _bind(packet, previous, snapshot):
    state, current = snapshot["sourceState"], snapshot["current"]
    attribution = packet["attribution"]; personhood = attribution["personhood"]
    require(state == personhood["sourceState"], "attribution V5 personhood source state differs")
    binding = current["binding"]; code, generation = current["attribution"]
    require(binding == personhood["current"]["binding"], "attribution V5 personhood binding differs")
    for key in ("registrationIdentityRecordHash", "operativeIdentityRecordHash"):
        require(current[key] == personhood["current"][key], "attribution V5 current identity differs")
    graph = snapshot["graph"]["current"]
    for native, original in (("registry", "currentRegistry"), ("attribution", "currentAttribution"), ("archive", "currentArchive")):
        require(graph[native] == personhood["sourceBindings"][original], "attribution V5 current source graph differs")
    old = previous["currentAttributionJoin"]
    require(code == old["nativeState"] and generation == old["nativeGeneration"] and binding == old["currentBinding"],
        "attribution V5 conservation current attribution differs")
    require(generation == attribution["bindingGeneration"] and (attribution["artistId"] or ZERO) == binding[0],
        "attribution V5 packet Artist/generation differs")
    matched = ["artistId", "bindingGeneration"]
    if code in STATES:
        require(attribution["state"] == STATES[code], "attribution V5 packet current state differs")
        matched.append("state")
    else:
        require(code == "0", "attribution V5 unsupported native state")
        # V5 has no NONE branch. A claimed platform branch needs a separate positive declaration.
        require(attribution["state"] == "platform_works" and current["platformDeclaration"][0] is True,
            "attribution V5 native NONE requires a separately retained platform declaration; other representation unavailable")
        matched.append("state_from_separate_platform_declaration")
    binding_join = {"matchedFields": [], "completeAuthorityAuthenticated": False}
    if attribution["binding"]["status"] == "present":
        record = attribution["binding"]["record"]
        require(binding[3] != ZERO and record["recordHash"] == binding[3],
            "attribution V5 binding native identity differs")
        binding_join["matchedFields"] = ["recordHash"]
    else:
        require(binding[3] == ZERO, "attribution V5 supplied binding absence contradicts current binding")
    confirmation = snapshot["history"]["originalConfirmation"]
    confirmed_hash = None if confirmation is None else confirmation["recordHash"]
    latest = snapshot["sanctions"]["latestAssociationHash"]
    selected = confirmed_hash or (latest if latest != ZERO else None)
    sanction_join = {"originalConfirmationRecordHash": confirmed_hash, "latestAssociationHash": latest,
        "selection": "original_confirmation" if confirmed_hash else "latest_unconfirmed" if selected else "none_retained",
        "selectedRecordHash": selected, "matchedFields": [], "genericTypeSchemaAndSubjectAuthenticated": False,
        "finalityExecutionRevalidated": False, "absenceReferenceAuthenticated": False}
    if attribution["sanction"]["status"] == "present":
        record = attribution["sanction"]["record"]
        rows = [row for row in snapshot["sanctions"]["records"] if row["recordHash"] == selected]
        require(selected is not None and len(rows) == 1, "attribution V5 supplied sanction has no exact retained selection")
        row = rows[0]; native = row["record"]
        require(row["publication"] is not None, "attribution V5 original sanction publication unavailable")
        expected = {"recordHash": selected, "host": row["owner"], "signer": native[2],
            "authorityClass": native[3], "recordedBlock": row["publication"]["blockNumber"]}
        require(all(record[key] == value for key, value in expected.items()), "attribution V5 original sanction fields differ")
        sanction_join["matchedFields"] = list(expected)
    else:
        require(selected is None, "attribution V5 supplied sanction absence contradicts retained sanction")
    return {"status": "native_attribution_and_sanction_fields_joined", "matchedPacketFields": matched,
        "nativeAttribution": deepcopy(current["attribution"]), "collectionArtistState": deepcopy(current["collectionArtistState"]),
        "identityAuthority": deepcopy(current["authority"]), "binding": binding_join, "sanction": sanction_join,
        "platformWorksInferred": False, "completeAttestationAuthorityAuthenticated": False,
        "sourceCoverageComplete": False}


def compose(packet_files, packet_hash, attribution_files, attribution_hash, *, disclosure):
    _public(disclosure)
    old = packet_v5.verify(packet_files, packet_hash); native = capture.verify(attribution_files, attribution_hash)
    originals, source_files = dict(old.files), dict(native.files)
    require(old.report["sourceProvenance"] == native.report["provenance"], "attribution V5 source provenance differs")
    reconciled = _reconcile(originals, source_files)
    packet = _load(originals, "packet/acquisition-packet.json"); snapshot = _load(source_files, "source/snapshot.json")
    join = _bind(packet, old.report, snapshot)
    items = deepcopy(old.report["items"])
    item = next(row for row in items if row["item"] == "6")
    item["evidence"] += ["attribution/native-join.json", CAPTURE_PREFIX + "source/snapshot.json"]
    item["remaining"] = "Native current attribution, identity authority and exact retained sanction evidence are joined. Generic binding/sanction labels, full binding and attestation authority, historical baseline/finality execution and documentary truth remain qualified."
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "sourceState": packet["sourceState"], "packetHash": old.report["packetHash"], "packetSchema": old.report["packetSchema"],
        "suppliedPacketValidated": True, "nativeAttributionJoin": join, "sourceReconciliation": reconciled,
        "items": items, "unresolvedSourceItems": old.report["unresolvedSourceItems"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    additions = {ORIGINAL_MANIFEST: originals["manifest.json"], "definitions/attribution-v5-assembly-profile.json": PROFILE_BYTES,
        "attribution/native-join.json": dumps(join), "attribution/assembly.json": dumps(report),
        "attribution/examination.md": ("# Native attribution and sanction evidence\n\n" + QUALIFICATION + "\n").encode("utf-8")}
    additions.update({CAPTURE_PREFIX + path: raw for path, raw in source_files.items()})
    files = {path: raw for path, raw in originals.items() if path != "manifest.json"}
    require(not set(files).intersection(additions), "attribution V5 retention path collision")
    files.update(additions); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"packet": packet_hash, "attribution": attribution_hash}, "sourceProvenance": report["sourceProvenance"],
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "attribution V5 manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "attribution V5 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs", "sourceProvenance", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"packet", "attribution"}, "attribution V5 closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "attribution V5 file commitments differ")
    require(ORIGINAL_MANIFEST in files, "attribution V5 original manifest missing")
    original_manifest = loads(files[ORIGINAL_MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    require(type(original_manifest) is dict and type(original_manifest.get("files")) is list, "attribution V5 original inventory missing")
    try:
        original = {row["path"]: files[row["path"]] for row in original_manifest["files"]}
        original["manifest.json"] = files[ORIGINAL_MANIFEST]
        native = {path.removeprefix(CAPTURE_PREFIX): body for path, body in files.items() if path.startswith(CAPTURE_PREFIX)}
        result = compose(original, manifest["inputs"]["packet"], native, manifest["inputs"]["attribution"], disclosure="public")
    except (KeyError, TypeError) as exc: raise MuseumError("attribution V5 original input reconstruction failed") from exc
    require(dict(result.files) == files, "attribution V5 reconstruction differs")
    return result


def export_supplied_packet(files, expected_hash):
    return dict(verify(files, expected_hash).files)["packet/acquisition-packet.json"]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("packet", "attribution"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "export-supplied-packet", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "packetAssemblyProfileHash": packet_v5.PROFILE_HASH,
            "attributionCaptureProfileHash": capture.PROFILE_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.packet, args.attribution]; _destination(args.output, sources)
        result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.attribution), args.attribution_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "attribution V5 publication replay differs")
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
