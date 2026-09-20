"""Attach original governance preimage evidence to a byte-identical V6 package."""
import argparse
from copy import deepcopy
from pathlib import Path
import sys

from . import acquisition_finality_v6 as previous
from . import public_governance_transaction_capture as capture
from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODE = "acquisition_governance_transactions_v1_assembly"
PROFILE = "STREAM_MUSEUM_ACQUISITION_GOVERNANCE_TRANSACTIONS_V1_ASSEMBLY_V1"
ORIGINAL_MANIFEST = "inputs/finality-v6-manifest.json"
CAPTURE_PREFIX = "acquisition-governance/"
PACKET_PATH = previous.PACKET_PATH
REPORT_PATH = "governance/assembly.json"
CLAIMS = {"allNineteenGroupsValidated": True, "originalV6PackagePreserved": True,
    "originalV6PacketBytesUnchanged": True, "originalNativeCaptureExactMatch": True,
    "additiveOriginalTransactionEvidence": True, "missingInputsRemainPartial": True,
    "completeAuthority": False, "historicalCoreFactsPreimageRecovered": False,
    "sourceCoverageComplete": False, "sourceConsensusVerified": False,
    "actualChainAcceptance": False, "completeCanonicalPacket": False, "networkFetch": False}
QUALIFICATION = ("The complete original V6 package is retained byte-for-byte, with its original packet and published claims "
    "unchanged. A separate source-bound report reconstructs original governance call/action-ID preimages when available. "
    "Original schedule and execution inputs, receipts, events and Executor/source anchors are joined; unsupported or absent "
    "inputs remain partial. Historical authority, policy, Core-facts preimage, EVM execution and consensus remain unresolved. "
    "Item 3 and complete source-covered acquisition readiness remain partial.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_assembly_profile",
    "previousAssemblyProfileHash": previous.PROFILE_HASH, "captureProfileHash": capture.PROFILE_HASH,
    "inputs": ["externally pinned unchanged V6 assembly", "externally pinned original governance transaction capture"],
    "join": "Verify both complete packages offline; require byte equality of the whole native capture embedded in each input, including original source pins, receipts, headers, events and runtime admission. Require identical provenance.",
    "retention": "Every V6 path remains unchanged except its manifest moves to " + ORIGINAL_MANIFEST
        + ". Complete new capture under " + CAPTURE_PREFIX + "; unchanged V6 export remains " + PACKET_PATH + ".",
    "coverage": "Additive report only; no V7, no published schema/source rewrite, no completeAuthority upgrade. Required scoped/STATIC/policyV2/VIEW native finality profiles remain follow-up work.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure): require(disclosure == "public", "governance assembly requires public disclosure before reads")


def compose(packet_files, packet_hash, transaction_files, transaction_hash, *, disclosure):
    _public(disclosure)
    old = previous.verify(packet_files, packet_hash)
    new = capture.verify(transaction_files, transaction_hash)
    originals, captured = dict(old.files), dict(new.files)
    require(old.report["sourceProvenance"] == new.report["provenance"], "governance assembly source provenance differs")
    prior_native = {path.removeprefix(previous.FINALITY_PREFIX): raw for path, raw in originals.items()
        if path.startswith(previous.FINALITY_PREFIX)}
    new_native = {path.removeprefix(capture.NATIVE_PREFIX): raw for path, raw in captured.items()
        if path.startswith(capture.NATIVE_PREFIX)}
    require(prior_native == new_native, "governance assembly original native capture differs")
    packet_raw = originals[PACKET_PATH]
    reconstruction = new.report["reconstruction"]
    items = deepcopy(old.report["items"])
    require([row["item"] for row in items] == [str(i) for i in range(1, 20)], "governance assembly exact nineteen requirements")
    items[2]["sourceCoverage"] = "partial"
    items[2]["evidence"] += [CAPTURE_PREFIX + capture.FRAGMENT_PATH, REPORT_PATH]
    items[2]["remaining"] = ("Original governance transaction reconstruction is reported separately. Missing/unsupported original inputs remain partial; "
        "historical authority, policy, execution and Core-facts preimage remain unresolved even when all call/action preimages are reconstructed.")
    report = {"profile": PROFILE, "version": "1", "sourceProvenance": old.report["sourceProvenance"],
        "sourceState": old.report["sourceState"], "packetSchema": old.report["packetSchema"],
        "packetPath": PACKET_PATH, "packetHash": keccak256(packet_raw), "packetBytesUnchanged": True,
        "originalNativeManifestHash": new.report["nativeManifestHash"], "reconstruction": reconstruction,
        "items": items, "unresolvedSourceItems": [row["item"] for row in items if row["sourceCoverage"] != "derived_within_source_profile"],
        "sourceCoverageComplete": False, "canonicalPacketReady": False, "claims": CLAIMS, "qualification": QUALIFICATION}
    files = {path: raw for path, raw in originals.items() if path != "manifest.json"}
    additions = {ORIGINAL_MANIFEST: originals["manifest.json"],
        "definitions/governance-transactions-assembly-profile.json": PROFILE_BYTES, REPORT_PATH: dumps(report),
        "governance/examination.md": ("# Original governance transaction evidence\n\n" + QUALIFICATION + "\n").encode("utf-8")}
    additions.update({CAPTURE_PREFIX + path: raw for path, raw in captured.items()})
    require(not set(files).intersection(additions), "governance assembly retention path collision")
    files.update(additions); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "inputs": {"packet": packet_hash, "transactions": transaction_hash}, "sourceProvenance": report["sourceProvenance"],
        "exportedPacket": {"path": PACKET_PATH, "hash": report["packetHash"]},
        "files": [base._ref(path, raw) for path, raw in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "governance assembly manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "governance assembly external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash", "inputs",
        "sourceProvenance", "exportedPacket", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS
        and manifest["qualification"] == QUALIFICATION and type(manifest["inputs"]) is dict
        and set(manifest["inputs"]) == {"packet", "transactions"}, "governance assembly closed manifest differs")
    require(manifest["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "governance assembly file commitments differ")
    require(ORIGINAL_MANIFEST in files, "governance assembly original V6 manifest missing")
    original_manifest = loads(files[ORIGINAL_MANIFEST], maximum=MAX_MANIFEST, canonical=True)
    try:
        original = {row["path"]: files[row["path"]] for row in original_manifest["files"]}
        original["manifest.json"] = files[ORIGINAL_MANIFEST]
        transactions = {path.removeprefix(CAPTURE_PREFIX): raw for path, raw in files.items() if path.startswith(CAPTURE_PREFIX)}
        result = compose(original, manifest["inputs"]["packet"], transactions, manifest["inputs"]["transactions"], disclosure="public")
    except (KeyError, TypeError) as exc: raise MuseumError("governance assembly original reconstruction failed") from exc
    require(dict(result.files) == files, "governance assembly reconstruction differs")
    return result


def export_packet(files, expected_hash): return dict(verify(files, expected_hash).files)[PACKET_PATH]


def complete_packet(files, expected_hash):
    result = verify(files, expected_hash)
    raise MuseumError("complete source-covered canonical packet unavailable; unresolved items: " + ", ".join(result.report["unresolvedSourceItems"]))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    build = sub.add_parser("assemble")
    for role in ("packet", "transactions"):
        build.add_argument("--" + role, type=Path, required=True); build.add_argument("--" + role + "-hash", required=True)
    build.add_argument("--disclosure", required=True); build.add_argument("--output", type=Path, required=True)
    for command in ("verify", "export-packet", "complete-packet"):
        child = sub.add_parser(command); child.add_argument("directory", type=Path); child.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"assemblyProfileHash": PROFILE_HASH, "previousAssemblyProfileHash": previous.PROFILE_HASH,
            "captureProfileHash": capture.PROFILE_HASH}).decode()); return
    if args.command == "assemble":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.packet, args.transactions]; _destination(args.output, sources)
        result = compose(read_tree(args.packet), args.packet_hash, read_tree(args.transactions), args.transactions_hash, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "governance assembly publication replay differs")
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
        "packetBytesUnchanged": True, "sourceCoverageComplete": False, "completeAuthority": False}).decode())


if __name__ == "__main__": main()
