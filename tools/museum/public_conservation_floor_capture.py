"""Read-only original conservation sale-floor evidence; item13 remains partial."""
import argparse
import os
from pathlib import Path
import re
import stat

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .dossier_gather import ITEMS
from .independent_wire import require
from .public_history_rpc import (PublicRpcTransport, PublicReplayTransport, MAX_TRANSCRIPT,
    PROFILE as RPC_PROFILE, VERSION as RPC_VERSION)

MODE = "public_conservation_floor_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_CAPTURE_V1"
MISSING_JOINS = {
    "durableTierSource": "The separate durable tier/default source has not been joined to this capture.",
    "selectedArtistIntent": "The original selected Artist intent or its explicit waiver has not been joined to this capture.",
    "selectedInterview": "The original selected interview or its explicit waiver has not been joined to this capture.",
    "canonicalPacketContext": "The remaining original conservation prerequisites and canonical packet context are not assembled.",
}
CLAIMS = {"readOnlyRpc": True, "consumerFixedFilters": True, "offlineReplayChecked": True,
    "originalSourceBytesRetained": True, "nativeFloorHistoryRetained": True,
    "optionalPreparationDistinctFromPayment": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "genesisWalk": False, "allBlockReceipts": False, "ancestryProof": False,
    "sourceConsensusVerified": False, "sourceProvenanceSelfAuthenticated": False,
    "durableTierSourceJoined": False, "selectedArtistIntentJoined": False, "selectedInterviewJoined": False,
    "candidatePreimageRecovered": False, "preparationRequiredForPayment": False,
    "allPaidRoutesCovered": False, "historicalExecutionReproved": False, "personhoodProven": False,
    "nativeRuntimeAcceptance": False, "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
    "actualChainAcceptance": False, "endpointRetained": False}
QUALIFICATION = (
    "Original native conservation floor receipt history for one collection at an externally pinned block. "
    "Paid inline persistence and optional prior preparation retain the same original native receipt; "
    "preparation is never payment proof and is not required for a purchase. Candidate commitments do not "
    "recover their unavailable preimages. Provider log completeness and canonical mapping remain trusted. "
    "Replay does not authenticate provenance or consensus, reexecute historical payments, establish "
    "personhood, validate native runtime acceptance or cover every paid route. Item13 remains partial "
    "until durable tier/default, selected intent/interview and remaining packet evidence are joined. "
    "No canonical packet compatibility or complete acquisition packet is claimed.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "source": "STREAM_MUSEUM_PUBLIC_CONSERVATION_FLOOR_SOURCE_V1", "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit named process environment variable; never in retained evidence or remote error details.",
    "output": "Exact collection source triplet, frozen definitions, binding and catalogue, original first-sale/release/settlement receipt rows; complete offline reconstruction required.",
    "coverage": "All19 acquisition requirements remain visible; item13 partial, all others unresolved. This capture is not a packet assembly.",
    "missingJoins": MISSING_JOINS, "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_conservation_floor_source as source
    return source


def _public(disclosure):
    require(disclosure == "public", "public conservation floor requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    source = _source()
    require(type(raw) is bytes and 0 < len(raw) <= 65536 and any(hex_bytes(expected_hash, 32))
        and keccak256(raw) == expected_hash, "public conservation floor external anchor pin/bound differs")
    require(expected_profile == source.PROFILE_HASH, "public conservation floor external source profile differs")
    return source.PublicConservationFloorSource


def _derive(snapshot):
    evidence = {key: snapshot[key] for key in ("sourceState", "sourceReviewCommit", "coreSourceReviewCommit",
        "historyCoverage", "claims", "qualification")}
    return {"conservation-floor/evidence.json": dumps(evidence),
        "conservation-floor/binding.json": dumps(snapshot["binding"]),
        "conservation-floor/catalogue.json": dumps(snapshot["catalogue"]),
        "conservation-floor/floor.json": dumps(snapshot["floor"])}


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "public conservation floor original capture pins differ")
    snapshot_bytes = source.snapshot(); transcript = source.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    derived = _derive(snapshot)
    files = {"source/anchor.json": source.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": module.PROFILE_BYTES,
        "definitions/history-profile.json": history.PROFILE_BYTES, "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES, **derived}
    items = [{"item": str(i), "name": title, "status": "partial" if i == 13 else "unresolved",
        "canonicalPacketCompatible": False, "evidence": sorted(derived) if i == 13 else [],
        "remaining": " ".join(MISSING_JOINS.values()) if i == 13 else "Required evidence is not assembled by this capture."}
        for i, (title, _) in enumerate(ITEMS, 1)]
    report = {"profile": PROFILE, "provenance": source.provenance, "sourceProfileHash": source_profile_hash,
        "historyCoverage": snapshot["historyCoverage"], "sourceState": snapshot["sourceState"],
        "floor": snapshot["floor"],
        "item13": {"status": "partial", "canonicalPacketCompatible": False, "missingJoins": MISSING_JOINS},
        "items": items, "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
        "remaining": list(MISSING_JOINS.values()), "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash, "provenance": source.provenance,
        "files": [base._ref(p, b) for p, b in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public conservation floor capture manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    """Read-only RPC entry point; exact offline reconstruction precedes return."""
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public conservation floor capture requires explicit read-only transport")
    source = constructor(anchor_bytes, transport, provenance="trusted_rpc")
    result = _assemble(source, anchor_hash, source_profile_hash)
    require(verify(dict(result.files), result.manifest_hash).files == result.files,
        "public conservation floor post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    """Reconstruct retained bytes under their explicitly supplied provenance."""
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public conservation floor explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "public conservation floor external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"} and value["mode"] == MODE
        and value["profile"] == PROFILE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
        and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public conservation floor closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "public conservation floor file commitments differ")
    require(all(p in files for p in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public conservation floor original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]),
        provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public conservation floor reconstruction differs")
    return rebuilt


def _read_input(path, limit):
    state = path.lstat()
    require(stat.S_ISREG(state.st_mode) and not path.is_symlink()
        and not (getattr(state, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)),
        "public conservation floor input must be a regular file")
    require(0 < state.st_size <= limit, "public conservation floor input byte bound")
    with path.open("rb") as stream: raw = stream.read(limit + 1)
    require(0 < len(raw) <= limit, "public conservation floor input byte bound")
    return raw


def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    for command in ("capture", "replay"):
        child = sub.add_parser(command)
        child.add_argument("--anchor", type=Path, required=True); child.add_argument("--anchor-hash", required=True)
        child.add_argument("--source-profile-hash", required=True); child.add_argument("--disclosure", required=True)
        child.add_argument("--output", type=Path, required=True)
        if command == "capture": child.add_argument("--rpc-env", required=True)
        else:
            child.add_argument("--transcript", type=Path, required=True); child.add_argument("--transcript-hash", required=True)
            child.add_argument("--provenance", choices=("trusted_rpc", "synthetic_fixture"), required=True)
    check = sub.add_parser("verify"); check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args()
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH, "sourceProfileHash": _source().PROFILE_HASH}).decode("utf-8")); return
    if args.command in ("capture", "replay"):
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.anchor] + ([args.transcript] if args.command == "replay" else [])
        _destination(args.output, sources)
        if args.command == "capture":
            require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", args.rpc_env) is not None,
                "public conservation floor RPC variable name invalid")
        raw = _read_input(args.anchor, 65536)
        constructor = _anchor(raw, args.anchor_hash, args.source_profile_hash)
        empty = dumps({"version": RPC_VERSION, "profile": RPC_PROFILE, "calls": []})
        constructor(raw, PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        if args.command == "capture":
            endpoint = os.environ.get(args.rpc_env)
            require(endpoint is not None and endpoint != "", "public conservation floor RPC variable unavailable")
            result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure=args.disclosure)
        else:
            transcript = _read_input(args.transcript, MAX_TRANSCRIPT)
            result = replay(raw, args.anchor_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure=args.disclosure)
            require(verify(dict(result.files), result.manifest_hash).files == result.files,
                "public conservation floor post-replay reconstruction differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)), "provenance": result.report["provenance"],
        "item13Status": result.report["item13"]["status"], "canonicalPacketCompatible": False,
        "floorStatus": result.report["floor"]["status"],
        "releaseCount": str(len(result.report["floor"]["releases"])),
        "settlementCount": str(len(result.report["floor"]["settlements"])),
        "completeCanonicalPacket": False, "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}).decode("utf-8"))


if __name__ == "__main__": main()
