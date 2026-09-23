"""Derive native accession/title fields in a new V5 export, retaining original inputs."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from ..metadata import acquisition_packet_v5 as definition
from . import acquisition_accession as accession
from . import acquisition_preservation_v5 as previous
from . import conservation_capture_join as observations
from . import native_title_v5 as native
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODE = "acquisition_title_v5_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_TITLE_V5_ASSEMBLY_V1"
ORIGINAL_MANIFEST = "inputs/preservation-v5-manifest.json"
ACCESSION_PREFIX = "acquisition-title/"
PACKET_PATH = "title/acquisition-packet.json"
CLAIMS = {"allNineteenGroupsValidated": True, "originalInputBytesPreserved": True,
    "newDerivedPacketExport": True, "elevenSourceObservationsReconciled": True,
    "explicitOriginalAccessionRetained": True, "originalOwnerAuthorityRetained": True,
    "fullCapturedCoreTransfersDerived": True, "canonicalLatestAccessionInferred": False,
    "allOwnerHostsEnumerated": False, "completeProtocolEventArchive": False,
    "legalTitleProven": False, "institutionIdentityProven": False, "custodyTransferred": False,
    "sourceCoverageComplete": False, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "institutionalAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = (
    "A new validated V5 packet derives legalInstrument, Core transfers/currentOwner, supported "
    "titleBindings and captured OwnerRecords heads from an externally pinned accession history. "
    "Both original packages and all nineteen packet groups remain available. Eleven source "
    "transcripts are reconciled at one source state. The explicitly selected original ACCESSION "
    "is an acquisition choice, not a canonical latest selection. Original native owner receipts "
    "retain their publication authority without a fabricated numeric class. Instrument byte "
    "availability, legal title, institutional identity and custody are separate observations. "
    "Uncaptured owner hosts, unsupported historical statements and the supplied protocol event "
    "archive remain qualified. Provider completeness, canonical mapping and provenance require "
    "external trust; consumer replay does not prove consensus, native execution or institutional acceptance.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "reviewedSourceCommit": "6fb3291e0991f556ef642e206c7732d8882a336f",
    "previousAssemblyProfileHash": previous.PROFILE_HASH, "accessionProfileHash": accession.PROFILE_HASH,
    "nativeDerivationProfileHash": native.PROFILE_HASH, "packetSchemaHash": definition.PACKET_SCHEMA_HASH,
    "inputs": ["externally pinned preservation V5 assembly", "externally pinned accession history"],
    "retention": "Original preservation payload paths and bytes remain unchanged; its manifest is retained at "
        + ORIGINAL_MANIFEST + ". The entire accession package is retained under " + ACCESSION_PREFIX + ".",
    "export": "The newly derived packet is " + PACKET_PATH + "; original packet/acquisition-packet.json remains unchanged.",
    "sourceJoin": "Replay both packages, match exact token/collection source identity and provenance, then reconcile all eleven common anchors, runtime pins, RPC outcomes, headers, complete receipts and log-query unions. The owner anchor collection is derived only from replayed Core identity.",
    "coverage": "Item9 is derived within the admitted owner source profile. Items5 and10 remain partial; all other earlier qualifications remain.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "title V5 requires public disclosure before reads")


def _load(files, path): return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _reconcile(originals, acquisition_files, acquisition_state):
    """Inputs have already been replayed. Never alter their original anchors."""
    inputs = {path.removesuffix("source/anchor.json"):
        (raw, originals[path.removesuffix("anchor.json") + "transcript.json"])
        for path, raw in originals.items() if path.endswith("/source/anchor.json")}
    require(len(inputs) == 9, "title V5 requires exact nine original capture sources")
    for role in ("owner", "ownership"):
        prefix = "sources/" + role + "/"
        inputs[ACCESSION_PREFIX + prefix] = (acquisition_files[prefix + "anchor.json"],
            acquisition_files[prefix + "transcript.json"])
    common, pins, calls, hashes, size, count = None, {}, {}, {}, 0, 0
    for role, (anchor_raw, transcript_raw) in sorted(inputs.items()):
        anchor = loads(anchor_raw, maximum=observations.MAX_ANCHOR_BYTES, canonical=True)
        if role == ACCESSION_PREFIX + "sources/owner/":
            # This frozen source anchor has no collectionId. The verified accession
            # package derives it from the paired ownership source's Core identity.
            state = {key: acquisition_state["collectionId"] if key == "collectionId" else anchor[key]
                for key in observations.COMMON}
        else:
            state = {key: anchor[key] for key in observations.COMMON}
        require(common is None or state == common, "title V5 common source state differs")
        common = state
        if "tokenId" in anchor:
            require(anchor["tokenId"] == acquisition_state["tokenId"], "title V5 source token differs")
        own_pins = ({anchor["core"]: anchor["coreRuntimeHash"]} if "coreRuntimeHash" in anchor else
            {row["address"]: row["runtimeHash"] for row in anchor["codePins"]})
        for address, digest in own_pins.items():
            require(address not in pins or pins[address] == digest, "title V5 cross-source runtime differs")
            pins[address] = digest
        transcript = loads(transcript_raw, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        require(transcript["profile"] == observations.rpc.PROFILE and transcript["version"] == observations.rpc.VERSION,
            "title V5 transcript profile differs")
        calls[role] = transcript["calls"]; size += len(anchor_raw) + len(transcript_raw); count += len(calls[role])
        require(size <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS, "title V5 aggregate source bound")
        hashes[role] = {"anchorHash": keccak256(anchor_raw), "transcriptHash": keccak256(transcript_raw)}
    require(all(common[key] == acquisition_state[key] for key in
        ("chainId", "core", "collectionId", "blockHash", "blockNumber", "timestamp")),
        "title V5 acquisition source state differs")
    return {"sourceState": common, "inputs": hashes, "counts": observations._observations(common, calls, pins),
        "observationSemanticsProfileHash": observations.PROFILE_HASH,
        "ownerAnchorCollectionIdSource": "replayed Core token identity in accession ownership snapshot",
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}


def _items(old):
    items = deepcopy(old)
    for item in items:
        number = item["item"]
        if number not in ("5", "9", "10"): continue
        item["sourceCoverage"] = "derived_within_source_profile" if number == "9" else "partial"
        item["evidence"] += ["title/native-derivation.json", PACKET_PATH]
        if number == "5":
            item["remaining"] = "Captured OwnerRecords heads derive from exact per-type histories; unrelated supplied lanes and uncaptured hosts remain qualified."
        elif number == "9":
            item["remaining"] = "The explicitly selected original ACCESSION and instrument commitment derive from native owner evidence. Referenced byte availability, legal validity, institutional identity and custody remain separate."
        else:
            item["remaining"] = "Full captured Core transfers/currentOwner and supported title bindings are derived. Complete protocol event archival evidence, other owner hosts and unresolved historical statements remain required."
    require([row["item"] for row in items] == [str(i) for i in range(1, 20)], "title V5 exact nineteen requirements")
    return items


def compose(packet_files, packet_hash, accession_files, accession_hash, *, disclosure):
    _public(disclosure)
    old = previous.verify(packet_files, packet_hash)
    acquired = accession.verify(accession_files, accession_hash)
    originals, acquisition_files = dict(old.files), dict(acquired.files)
    require(old.report["sourceProvenance"] == acquired.report["provenance"], "title V5 source provenance differs")
    reconciled = _reconcile(originals, acquisition_files, acquired.report["sourceState"])
    supplied = _load(originals, "packet/acquisition-packet.json")
    derived = native.derive(acquired, acquisition_files, accession_hash, supplied)
    packet_raw = dumps(derived["packet"])
    packet = definition.validate(packet_raw)
    require(packet["sourceState"] == supplied["sourceState"], "title V5 original packet source state differs")
    join = {key: value for key, value in derived.items() if key != "packet"}
    items = _items(old.report["items"])
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "sourceState": packet["sourceState"], "packetSchema": old.report["packetSchema"],
        "packetPath": PACKET_PATH, "packetHash": keccak256(packet_raw),
        "originalPacketPath": "packet/acquisition-packet.json", "originalPacketHash": old.report["packetHash"],
        "originalSuppliedPacketValidated": True, "derivedPacketValidated": True,
        "nativeTitleDerivation": join, "sourceReconciliation": reconciled, "items": items,
        "unresolvedSourceItems": [row["item"] for row in items if row["sourceCoverage"] != "derived_within_source_profile"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    additions = {ORIGINAL_MANIFEST: originals["manifest.json"],
        "definitions/title-v5-assembly-profile.json": PROFILE_BYTES,
        "definitions/native-title-v5-profile.json": native.PROFILE_BYTES,
        "definitions/title-native-owner-authority-profile.json": native.owner_authority.PROFILE_BYTES,
        PACKET_PATH: packet_raw, "title/native-derivation.json": dumps(join), "title/assembly.json": dumps(report),
        "title/examination.md": ("# Native accession and title export\n\n" + QUALIFICATION
            + "\n\nDerived packet: `" + PACKET_PATH + "`. Original packet: `packet/acquisition-packet.json`.\n").encode("utf-8")}
    additions.update({ACCESSION_PREFIX + path: raw for path, raw in acquisition_files.items()})
    files = {path: raw for path, raw in originals.items() if path != "manifest.json"}
    require(not set(files).intersection(additions), "title V5 retention path collision")
    files.update(additions); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"packet": packet_hash, "accession": accession_hash}, "sourceProvenance": report["sourceProvenance"],
        "exportedPacket": {"path": PACKET_PATH, "hash": report["packetHash"]},
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "title V5 manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "title V5 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "exportedPacket", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"packet", "accession"},
        "title V5 closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "title V5 file commitments differ")
    require(ORIGINAL_MANIFEST in files, "title V5 original manifest missing")
    original_manifest = loads(files[ORIGINAL_MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    require(type(original_manifest) is dict and type(original_manifest.get("files")) is list,
        "title V5 original inventory missing")
    try:
        original = {row["path"]: files[row["path"]] for row in original_manifest["files"]}
        original["manifest.json"] = files[ORIGINAL_MANIFEST]
        acquired = {path.removeprefix(ACCESSION_PREFIX): raw for path, raw in files.items() if path.startswith(ACCESSION_PREFIX)}
        result = compose(original, manifest["inputs"]["packet"], acquired, manifest["inputs"]["accession"], disclosure="public")
    except (KeyError, TypeError) as exc: raise MuseumError("title V5 original input reconstruction failed") from exc
    require(dict(result.files) == files, "title V5 reconstruction differs")
    return result


def export_packet(files, expected_hash):
    return dict(verify(files, expected_hash).files)[PACKET_PATH]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("packet", "accession"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "export-packet", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "previousAssemblyProfileHash": previous.PROFILE_HASH,
            "accessionProfileHash": accession.PROFILE_HASH, "nativeDerivationProfileHash": native.PROFILE_HASH,
            "packetSchemaHash": definition.PACKET_SCHEMA_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.packet, args.accession]; _destination(args.output, sources)
        result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.accession), args.accession_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "title V5 publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet": complete_packet(read_tree(args.directory), args.manifest_hash); return
    elif args.command == "export-packet":
        raw = export_packet(read_tree(args.directory), args.manifest_hash)
        binary = getattr(sys.stdout, "buffer", None)
        if binary is not None: binary.write(raw)
        else: sys.stdout.write(raw.decode("utf-8"))
        return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "packetHash": result.report["packetHash"], "packetPath": PACKET_PATH, "derivedPacketValidated": True,
        "sourceCoverageComplete": False, "canonicalPacketReady": False}).decode())


if __name__ == "__main__": main()
