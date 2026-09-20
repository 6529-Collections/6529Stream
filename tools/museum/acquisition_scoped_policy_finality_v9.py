"""Compose original scoped factory-policy V2 finality into a complete-shape V9 export."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from ..metadata import acquisition_packet_v9 as definition
from ..metadata import acquisition_scoped_policy_finality_v2 as native
from . import acquisition_title_v5 as previous
from . import public_scoped_policy_finality_capture_v2 as finality
from . import conservation_capture_join as observations
from . import scoped_finality_observations
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODE = "acquisition_scoped_policy_finality_v9_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_SCOPED_POLICY_FINALITY_V9_ASSEMBLY_V1"
ORIGINAL_MANIFEST = "inputs/title-v5-manifest.json"
FINALITY_PREFIX = "acquisition-scoped-policy-finality/"
PACKET_PATH = "finality/acquisition-packet-v9.json"
CLAIMS = {"allNineteenGroupsValidated": True, "originalInputBytesPreserved": True,
    "newDerivedPacketExport": True, "twelveSourceObservationsReconciled": True,
    "originalNativeFinalityRetained": True, "nativeTokenProofChecked": True,
    "historicalCoreFactsPreimageRecovered": False, "completeAuthority": False,
    "sourceCoverageComplete": False, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "institutionalAcceptance": False,
    "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = ("New V9 packet with all nineteen groups and paired original scoped factory-policy V2 finality/token-proof branches. "
    "The entire title V5 package and policy V2 capture remain byte-for-byte available. Twelve source captures share "
    "one token/collection state. Exact original policy, snapshot/reference records, complete original sealed scope membership "
    "and selection/output/readiness rows join complete collection scoped-root aggregate history and finalization. Six STATIC component "
    "preimages are reconstructed from immutable configuration/source records. Supported original Executor inputs "
    "reconstruct metadata commitments; availability/unsupported cases remain partial. Historical Core/metadata facts, "
    "terminal-admission preimages, complete renderer execution, signatures, roles and runtime provenance remain "
    "separate. This bounded composition requires shared Metadata, schema Store/Registry and Artist identity. "
    "Provider completeness, source authenticity, consensus, historical execution and acquisition acceptance remain trust boundaries.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "sourceReviewCommit": finality._source().SOURCE_REVISION, "previousAssemblyProfileHash": previous.PROFILE_HASH,
    "finalityCaptureProfileHash": finality.PROFILE_HASH, "nativeFragmentSchemaHash": native.SCHEMA_HASH,
    "packetSchemaHash": definition.PACKET_SCHEMA_HASH,
    "inputs": ["externally pinned title V5 assembly", "externally pinned original scoped factory-policy V2 finality capture"],
    "retention": "All original title package paths/bytes survive; its manifest moves to " + ORIGINAL_MANIFEST
        + ". Entire native capture is under " + FINALITY_PREFIX + ".",
    "export": PACKET_PATH, "changes": ["schema/version", "paired native finality and contentRootProof", "original native fin citation"],
    "sourceJoin": "Replay both packages, reconcile exact twelve anchors, shared runtime pins/RPC outcomes, canonical headers, complete receipts and log query unions.",
    "coverage": "Item3 remains partial: mathematical original sealed scope membership is checked, but historical Core/metadata facts, terminal-admission preimages, authority execution and complete preservation remain unresolved.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure): require(disclosure == "public", "policy finality V9 requires public disclosure before reads")
def _load(files, path): return loads(files[path], maximum=MAX_BYTES, canonical=True)


def _reconcile(originals, capture_files, state):
    inputs = {}
    for path, raw in originals.items():
        if path.endswith("/source/anchor.json") or path.endswith("/sources/owner/anchor.json") or path.endswith("/sources/ownership/anchor.json"):
            prefix = path.removesuffix("anchor.json")
            inputs[prefix] = (raw, originals[prefix + "transcript.json"])
    require(len(inputs) == 11, "policy finality V9 exact eleven previous sources required")
    inputs[FINALITY_PREFIX + "source/"] = (capture_files["source/anchor.json"], capture_files["source/transcript.json"])
    common, pins, calls, hashes, size, count = None, {}, {}, {}, 0, 0
    for role, (anchor_raw, transcript_raw) in sorted(inputs.items()):
        anchor = loads(anchor_raw, maximum=observations.MAX_ANCHOR_BYTES, canonical=True)
        own = {key: state["collectionId"] if key == "collectionId" and role.endswith("/sources/owner/") else anchor[key]
            for key in observations.COMMON}
        require(common is None or own == common, "policy finality V9 common source state differs")
        common = own
        if "tokenId" in anchor: require(anchor["tokenId"] == state["tokenId"], "policy finality V9 source token differs")
        own_pins = ({anchor["core"]: anchor["coreRuntimeHash"]} if "coreRuntimeHash" in anchor else
            {row["address"]: row["runtimeHash"] for row in anchor["codePins"]})
        for address, digest in own_pins.items():
            require(address not in pins or pins[address] == digest, "policy finality V9 cross-source runtime differs")
            pins[address] = digest
        transcript = loads(transcript_raw, maximum=observations.rpc.MAX_TRANSCRIPT, canonical=True)
        from . import public_scoped_finality_rpc as scoped_rpc
        own_rpc = scoped_rpc if role == FINALITY_PREFIX + "source/" else observations.rpc
        require(transcript["profile"] == own_rpc.PROFILE and transcript["version"] == own_rpc.VERSION,
            "policy finality V9 transcript profile differs")
        calls[role] = transcript["calls"]; size += len(anchor_raw) + len(transcript_raw); count += len(calls[role])
        require(size <= observations.MAX_INPUT_BYTES and count <= observations.MAX_ROWS, "policy finality V9 aggregate source bound")
        hashes[role] = {"anchorHash": keccak256(anchor_raw), "transcriptHash": keccak256(transcript_raw)}
    require(all(common[key] == state[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber"))
        and common["timestamp"] == state["examinedAt"], "policy finality V9 observed packet state differs")
    return {"sourceState": common, "inputs": hashes, "counts": scoped_finality_observations.reconcile(common, calls, pins),
        "observationSemanticsProfileHash": observations.PROFILE_HASH, "providerLogCompletenessTrusted": True,
        "sourceConsensusVerified": False, "ownerAnchorCollectionIdSource": "replayed Core token identity in original accession package"}


def compose(packet_files, packet_hash, finality_files, finality_hash, *, disclosure):
    _public(disclosure)
    old = previous.verify(packet_files, packet_hash)
    captured = finality.verify(finality_files, finality_hash)
    originals, captured_files = dict(old.files), dict(captured.files)
    require(old.report["sourceProvenance"] == captured.report["provenance"], "policy finality V9 source provenance differs")
    packet = _load(originals, previous.PACKET_PATH)
    require(packet["metadataMode"] == "ONCHAIN" and packet["workClass"] == "script", "policy finality V9 unsupported supplied mode/work class")
    require(packet["sourceState"] == captured.report["sourceState"], "policy finality V9 captured token observation differs")
    reconciled = _reconcile(originals, captured_files, packet["sourceState"])
    fragment = native.validate(captured_files["scoped-policy-finality/fragment.json"])
    original_packet = deepcopy(packet)
    packet["schema"], packet["version"] = definition.PACKET, 9
    packet["finality"] = {"kind": "native_scoped_policy_finality_v2", "fragment": fragment}
    packet["contentRootProof"] = native.token_proof(fragment)
    digest = fragment["bundle"]["finality"]["record"][2]
    packet["citation"]["qualifier"] = {"kind": "fin", "hash": digest}
    packet["citation"]["qualified"] = packet["citation"]["work"] + "@fin:" + digest
    packet_raw = dumps(packet)
    definition.validate(packet_raw)
    changed = {"schema", "version", "finality", "contentRootProof", "citation"}
    require(all(packet[key] == value for key, value in original_packet.items() if key not in changed), "policy finality V9 unrelated field changed")
    items = deepcopy(old.report["items"])
    require([row["item"] for row in items] == [str(i) for i in range(1, 20)], "policy finality V9 exact nineteen requirements")
    item = items[2]; item["sourceCoverage"] = "partial"
    item["evidence"] += [PACKET_PATH, FINALITY_PREFIX + "scoped-policy-finality/fragment.json", FINALITY_PREFIX + "scoped-policy-finality/token-proof.json"]
    item["remaining"] = "Original scoped factory-policy V2 finality, complete original membership/output/readiness rows and six STATIC component preimages are checked. Original transaction reconstruction retains its availability limits; Core/metadata facts, terminal admission preimages, full renderer execution, roles, signatures and execution remain unresolved."
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "sourceState": packet["sourceState"], "packetSchema": definition.PACKET, "packetPath": PACKET_PATH,
        "packetHash": keccak256(packet_raw), "originalPacketPath": previous.PACKET_PATH,
        "originalPacketHash": old.report["packetHash"], "originalSuppliedPacketValidated": True,
        "derivedPacketValidated": True, "finalityRecordHash": digest, "sourceReconciliation": reconciled, "items": items,
        "unresolvedSourceItems": [row["item"] for row in items if row["sourceCoverage"] != "derived_within_source_profile"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    additions = {ORIGINAL_MANIFEST: originals["manifest.json"], "definitions/scoped-policy-finality-v9-assembly-profile.json": PROFILE_BYTES,
        "definitions/acquisition-packet-v9.json": definition.PACKET_SCHEMA_BYTES, PACKET_PATH: packet_raw,
        "finality/assembly.json": dumps(report), "finality/examination.md": ("# Original native finality export\n\n" + QUALIFICATION + "\n").encode("utf-8")}
    additions.update({FINALITY_PREFIX + path: raw for path, raw in captured_files.items()})
    files = {path: raw for path, raw in originals.items() if path != "manifest.json"}
    require(not set(files).intersection(additions), "policy finality V9 retention path collision")
    files.update(additions); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"packet": packet_hash, "finality": finality_hash}, "sourceProvenance": report["sourceProvenance"],
        "exportedPacket": {"path": PACKET_PATH, "hash": report["packetHash"]},
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "policy finality V9 manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "policy finality V9 external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "exportedPacket", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS and manifest["qualification"] == QUALIFICATION
        and type(manifest["inputs"]) is dict and set(manifest["inputs"]) == {"packet", "finality"}, "policy finality V9 closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "policy finality V9 file commitments differ")
    require(ORIGINAL_MANIFEST in files, "policy finality V9 original manifest missing")
    original_manifest = loads(files[ORIGINAL_MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    try:
        original = {row["path"]: files[row["path"]] for row in original_manifest["files"]}
        original["manifest.json"] = files[ORIGINAL_MANIFEST]
        capture = {path.removeprefix(FINALITY_PREFIX): raw for path, raw in files.items() if path.startswith(FINALITY_PREFIX)}
        result = compose(original, manifest["inputs"]["packet"], capture, manifest["inputs"]["finality"], disclosure="public")
    except (KeyError, TypeError) as exc: raise MuseumError("policy finality V9 original reconstruction failed") from exc
    require(dict(result.files) == files, "policy finality V9 reconstruction differs")
    return result


def export_packet(files, expected_hash): return dict(verify(files, expected_hash).files)[PACKET_PATH]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("packet", "finality"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for name in ("verify", "export-packet", "complete-packet"):
        command = sub.add_parser(name); command.add_argument("directory", type=Path); command.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "previousAssemblyProfileHash": previous.PROFILE_HASH,
            "finalityCaptureProfileHash": finality.PROFILE_HASH, "packetSchemaHash": definition.PACKET_SCHEMA_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.packet, args.finality]; _destination(args.output, sources)
        result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.finality), args.finality_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "policy finality V9 publication replay differs")
        _publish(dict(result.files), args.output, sources)
    elif args.command == "complete-packet": complete_packet(read_tree(args.directory), args.manifest_hash); return
    elif args.command == "export-packet":
        raw = export_packet(read_tree(args.directory), args.manifest_hash)
        binary = getattr(sys.stdout, "buffer", None)
        if binary is not None: binary.write(raw)
        else: sys.stdout.write(raw.decode("utf-8"))
        return
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)), "packetHash": result.report["packetHash"],
        "packetPath": PACKET_PATH, "derivedPacketValidated": True, "sourceCoverageComplete": False,
        "canonicalPacketReady": False}).decode())


if __name__ == "__main__": main()
