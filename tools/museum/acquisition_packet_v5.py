"""Source-preserving full-shaped packet V5 with explicit supplied-only requirements."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from ..metadata import acquisition_packet_v5 as definition
from ..metadata import genesis_dossier_profile as v1
from . import acquisition_direct_conservation as direct
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .independent_wire import ZERO, ZERO_ADDRESS, require

MODE = "acquisition_packet_v5_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_PACKET_V5_ASSEMBLY_V1"
DIRECT_PREFIX = "direct-conservation/"
RIGHTS_ROOT = "direct-assembly/provider-binding/rights-assembly/captures/rights/"
RIGHTS_FRAGMENT = RIGHTS_ROOT + "rights/packet-fragment.json"
CLAIMS = {"completeSuppliedPacketShape": True, "packetSchemaValidated": True,
    "sixSourceAssemblyReplayed": True, "originalInputBytesPreserved": True,
    "threeNativeFragmentsBound": True, "currentRightsBound": True,
    "currentAttributionTupleCompared": True, "allNineteenRequirementsVisible": True,
    "fullAttributionAuthoritiesVerified": False, "fullPacketSourceCoverage": False,
    "historicalEligibilityReexecuted": False, "historicalProviderExecutionProven": False,
    "documentaryTruthProven": False, "legalPersonhoodProven": False,
    "sourceConsensusVerified": False, "nativeRuntimeAcceptance": False,
    "actualChainAcceptance": False, "institutionalConformance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "A complete supplied-data packet V5 is retained and validated across all nineteen field groups. "
    "Its native DIRECT, personhood and conservation context fragments bind byte for byte to the "
    "replayed six-source DIRECT assembly. Current RIGHTS and supported current attribution fields "
    "are compared with their actual captured producer observations. Other packet fields remain "
    "supplied statements: shape and internal consistency do not establish source provenance, "
    "authenticated absence, complete history, documentary truth, legal identity or institutional "
    "acceptance. Historical source qualifications remain unchanged. V1–V4 and original source "
    "profiles retain their original bytes and meanings. Supplied-packet export is available; "
    "complete source-covered canonical packet export remains unavailable.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "packetSchemaHash": definition.PACKET_SCHEMA_HASH, "directAssemblyProfileHash": direct.PROFILE_HASH,
    "inputs": ["externally pinned DIRECT conservation assembly", "externally pinned canonical full packet V5 bytes"],
    "nativeFragments": "Exact unchanged standalone DIRECT, native personhood and conservation context embedded in V5; no fabricated legacy conversion.",
    "rights": "Exact current RIGHTS packet fragment, with only its snapshot URI relocated to the retained original capture path. Hash, native authority and grants remain unchanged.",
    "attribution": "Compare current captured native attribution state, generation and binding Artist ID; original binding, sanction and independent attestation authority remain outside this partial join.",
    "coverage": "All nineteen supplied field groups are required. Source coverage is separately derived, partial or supplied_only; no caller assertion upgrades it.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "packet V5 requires public disclosure before reads")


def _load(files, path): return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _current_attribution(packet, captured):
    observed = captured.report["currentAttributionObservations"]
    attribution = packet["attribution"]
    code, generation = observed["attribution"]
    binding = observed["binding"]
    states = {"1": "claimed", "2": "artist_accepted", "3": "artist_sanctioned", "4": "disputed", "5": "revoked"}
    require(code in ("0", *states), "packet V5 native attribution state unsupported")
    matched = []
    if code in states:
        require(binding[0] != ZERO and binding[3] != ZERO and uint(generation) > 0
            and binding[4] == generation, "packet V5 current binding/attribution generation differs")
        require(attribution["state"] == states[code], "packet V5 current attribution state differs")
        matched.append("state")
    require(attribution["bindingGeneration"] == generation, "packet V5 current attribution generation differs")
    matched.append("bindingGeneration")
    if binding[0] != ZERO:
        require(attribution["artistId"] == binding[0], "packet V5 current attribution Artist differs")
        matched.append("artistId")
    return {"status": "captured_current_attribution_fields_joined",
        "sourceState": deepcopy(captured.report["fields"]["sourceState"]),
        "nativeState": code, "nativeGeneration": generation, "currentBinding": deepcopy(binding),
        "currentAssociation": deepcopy(observed["association"]), "matchedPacketFields": matched,
        "unmappedNativeState": code == "0", "platformWorksInferred": False,
        "bindingAuthorityVerified": False, "sanctionRecordVerified": False,
        "attestationStatusAndAuthorityVerified": False, "historicalAttributionReexecuted": False}


def _bind(packet, captured, files):
    require(packet["sourceState"] == captured.report["fields"]["sourceState"], "packet V5 captured sourceState differs")
    for value, path in ((packet["conservation"]["context"], "packet/conservation-context.json"),
            (packet["conservation"]["floor"], "direct-assembly/packet/native-direct-floor.json"),
            (packet["attribution"]["personhood"], "direct-assembly/packet/native-personhood.json")):
        require(dumps(value) == files[path], "packet V5 captured native fragment differs")
    rights = _load(files, RIGHTS_FRAGMENT)
    original_uri = rights["selectionEvidence"]["uri"]
    require(original_uri == "source/snapshot.json", "packet V5 RIGHTS source URI differs")
    rights["selectionEvidence"]["uri"] = DIRECT_PREFIX + RIGHTS_ROOT + original_uri
    require(packet["rights"] == rights, "packet V5 captured RIGHTS fragment differs")
    require(rights["selectionEvidence"]["hash"]["digest"] == keccak256(files[RIGHTS_ROOT + original_uri]),
        "packet V5 RIGHTS snapshot commitment differs")
    tokens = [row for row in captured.report["tierJoin"]["directTokens"]
        if row["tokenId"] == packet["sourceState"]["tokenId"]]
    require(len(tokens) == 1, "packet V5 captured completed target mint missing/ambiguous")
    mint, transfer = tokens[0]["completedMint"], packet["ownershipProvenance"]["transfers"][0]
    require(transfer["from"] == ZERO_ADDRESS and transfer["to"] == mint["recipient"]
        and all(transfer[key] == mint["publication"][key] for key in ("blockNumber", "transactionHash", "logIndex")),
        "packet V5 captured target mint/ownership transfer differs")
    attribution = _current_attribution(packet, captured)
    return attribution, {"status": "current_rights_fragment_joined", "fragmentPath": DIRECT_PREFIX + RIGHTS_FRAGMENT,
        "snapshotPath": rights["selectionEvidence"]["uri"], "snapshotHash": rights["selectionEvidence"]["hash"]["digest"],
        "originalFragmentBytesPreserved": True, "onlySnapshotUriRelocated": True, "legalRightsTruthProven": False}


def _items(captured):
    items = []
    for original in captured.report["items"]:
        number = original["item"]
        coverage = "derived_within_source_profile" if number in ("2", "7", "19") else (
            "partial" if number in ("5", "6", "10", "13") else "supplied_only")
        remaining = "" if coverage == "derived_within_source_profile" else (
            "Field values pass supplied-data validation; complete corresponding source evidence has not been joined.")
        if number == "5": remaining = "Supplied heads join retained native records, but complete lane inventories and current head capture are not established."
        if number == "6": remaining = "Current native personhood, binding Artist ID/generation and supported attribution state are joined. Full original binding, attestation and sanction authority capture remains required."
        if number == "10": remaining = "The supplied first transfer joins the completed DIRECT mint. Complete ownership transfer history and title instruments remain unverified by this assembly."
        if number == "13": remaining = "Native tier, selection and DIRECT fragments are represented and replayed. Saved historical documentary and execution qualifications remain; master/archive/reference prerequisites require their own source joins."
        evidence = [DIRECT_PREFIX + path for path in original["evidence"]]
        evidence += ["packet/acquisition-packet.json#/" + field for field in v1.PACKET_REQUIREMENTS[number]]
        if number == "6": evidence.append("packet/current-attribution-join.json")
        if number == "7": evidence.append("packet/rights-join.json")
        items.append({"item": number, "name": original["name"], "fields": v1.PACKET_REQUIREMENTS[number],
            "suppliedFieldsValidated": True, "schemaCompatible": True, "sourceCoverage": coverage,
            "evidence": evidence, "remaining": remaining})
    require([item["item"] for item in items] == [str(index) for index in range(1, 20)], "packet V5 exact nineteen requirements")
    return items


def compose(direct_files, direct_hash, packet_raw, packet_hash, *, disclosure):
    _public(disclosure)
    require(type(packet_raw) is bytes and 0 < len(packet_raw) <= definition.MAX_BYTES
        and any(hex_bytes(packet_hash, 32)) and keccak256(packet_raw) == packet_hash,
        "packet V5 external supplied packet pin/bound differs")
    packet = definition.validate(packet_raw)
    captured = direct.verify(direct_files, direct_hash)
    original = dict(captured.files)
    attribution, rights = _bind(packet, captured, original)
    items = _items(captured)
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": captured.report["sourceProvenance"],
        "packetSchema": {"name": definition.PACKET, "hash": definition.PACKET_SCHEMA_HASH}, "packetHash": packet_hash,
        "sourceState": packet["sourceState"], "suppliedPacketValidated": True,
        "currentAttributionJoin": attribution, "rightsJoin": rights, "items": items,
        "unresolvedSourceItems": [item["item"] for item in items if item["sourceCoverage"] != "derived_within_source_profile"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {DIRECT_PREFIX + path: raw for path, raw in original.items()}
    files.update({"definitions/packet-v5-schema.json": definition.PACKET_SCHEMA_BYTES,
        "definitions/packet-v5-assembly-profile.json": PROFILE_BYTES, "inputs/supplied-packet.json": packet_raw,
        "packet/acquisition-packet.json": packet_raw, "packet/current-attribution-join.json": dumps(attribution),
        "packet/rights-join.json": dumps(rights), "packet/assembly.json": dumps(report),
        "packet/examination.md": ("# Packet V5: supplied data and source coverage\n\n" + QUALIFICATION + "\n").encode("utf-8")})
    base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"direct": direct_hash, "packet": packet_hash}, "sourceProvenance": report["sourceProvenance"],
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "packet V5 manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "packet V5 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "files", "claims", "qualification"} and manifest["mode"] == MODE
        and manifest["profile"] == PROFILE and manifest["version"] == "1" and manifest["profileHash"] == PROFILE_HASH
        and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"direct", "packet"}, "packet V5 closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "packet V5 file commitments differ")
    original = {path.removeprefix(DIRECT_PREFIX): body for path, body in files.items() if path.startswith(DIRECT_PREFIX)}
    require("inputs/supplied-packet.json" in files, "packet V5 original supplied packet missing")
    rebuilt = compose(original, manifest["inputs"]["direct"], files["inputs/supplied-packet.json"],
        manifest["inputs"]["packet"], disclosure="public")
    require(dict(rebuilt.files) == files, "packet V5 reconstruction differs")
    return rebuilt


def export_supplied_packet(files, expected_hash):
    result = verify(files, expected_hash)
    return dict(result.files)["packet/acquisition-packet.json"]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("direct", "packet"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "export-supplied-packet", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "packetSchemaHash": definition.PACKET_SCHEMA_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.direct, args.packet]; _destination(args.output, sources)
        require(args.packet.is_file() and not args.packet.is_symlink() and args.packet.stat().st_size <= definition.MAX_BYTES,
            "packet V5 supplied packet must be a bounded ordinary file")
        result = compose(read_tree(args.direct), args.direct_hash, args.packet.read_bytes(), args.packet_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "packet V5 publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet":
        complete_packet(read_tree(args.directory), args.manifest_hash); return
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
