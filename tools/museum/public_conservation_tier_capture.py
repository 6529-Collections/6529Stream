"""Read-only durable conservation tier/default evidence; item13 remains partial."""
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

MODE = "public_conservation_tier_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_CONSERVATION_TIER_CAPTURE_V1"
MISSING_JOINS = {
    "selectedArtistIntent": "The original selected Artist intent or its explicit waiver has not been joined to this capture.",
    "selectedInterview": "The original selected interview or its explicit waiver has not been joined to this capture.",
    "actualSaleFloorReceipt": "A genuine native sale-floor receipt and its full prerequisite evidence have not been joined.",
}
CLAIMS = {"readOnlyRpc": True, "consumerFixedFilters": True, "offlineReplayChecked": True,
    "originalSourceBytesRetained": True, "durableTierEvidenceRetained": True,
    "completedMintDefaultDistinguished": True, "prospectiveSaleTierDistinct": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "genesisWalk": False, "allBlockReceipts": False, "ancestryProof": False,
    "sourceConsensusVerified": False, "sourceProvenanceSelfAuthenticated": False,
    "selectedArtistIntentJoined": False, "selectedInterviewJoined": False, "saleFloorEnforced": False,
    "genericTierRecordInvented": False,
    "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
    "actualChainAcceptance": False, "endpointRetained": False}
QUALIFICATION = (
    "Durable Core conservation tier and collection mint-completion evidence at an externally pinned block. "
    "An undeclared collection has no effective tier until its first completed mint; the prospective "
    "undeclared LITE sale-floor rule is retained separately and does not prove that a floor was enforced. "
    "Allocation, preparation, reversion and burns do not substitute for first completed minting. "
    "Provider log completeness and canonical mapping remain trusted. Replay does not authenticate "
    "provenance or consensus. Item13 remains partial until selected intent/interview and actual native "
    "floor-receipt evidence are joined. No generic tier record, canonical packet compatibility or "
    "complete acquisition packet is invented.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "source": "STREAM_MUSEUM_PUBLIC_CONSERVATION_TIER_SOURCE_V1", "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit named process environment variable; never in retained evidence or remote error details.",
    "output": "Exact collection source triplet, frozen definitions, durable declaration/default facts, original allocations and completed mints; complete offline reconstruction required.",
    "coverage": "All19 acquisition requirements remain visible; item13 partial, all others unresolved. This capture is not a packet assembly.",
    "missingJoins": MISSING_JOINS, "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_conservation_tier_source as source
    return source


def _public(disclosure):
    require(disclosure == "public", "public conservation tier requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    source = _source()
    require(type(raw) is bytes and 0 < len(raw) <= 65536 and any(hex_bytes(expected_hash, 32))
        and keccak256(raw) == expected_hash, "public conservation tier external anchor pin/bound differs")
    require(expected_profile == source.PROFILE_HASH, "public conservation tier external source profile differs")
    return source.PublicConservationTierSource


def _derive(snapshot):
    evidence = {key: snapshot[key] for key in ("sourceState", "sourceReviewCommit", "coreSourceReviewCommit",
        "historyCoverage", "claims", "qualification")}
    return {"conservation-tier/evidence.json": dumps(evidence),
        "conservation-tier/tier.json": dumps(snapshot["tier"]),
        "conservation-tier/allocations.json": dumps(snapshot["allocations"]),
        "conservation-tier/completed-mints.json": dumps(snapshot["completedMints"])}


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "public conservation tier original capture pins differ")
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
        "tier": snapshot["tier"],
        "item13": {"status": "partial", "canonicalPacketCompatible": False, "missingJoins": MISSING_JOINS},
        "items": items, "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
        "remaining": list(MISSING_JOINS.values()), "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash, "provenance": source.provenance,
        "files": [base._ref(p, b) for p, b in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public conservation tier capture manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    """Read-only RPC entry point; exact offline reconstruction precedes return."""
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public conservation tier capture requires explicit read-only transport")
    source = constructor(anchor_bytes, transport, provenance="trusted_rpc")
    result = _assemble(source, anchor_hash, source_profile_hash)
    require(verify(dict(result.files), result.manifest_hash).files == result.files,
        "public conservation tier post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    """Reconstruct retained bytes under their explicitly supplied provenance."""
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public conservation tier explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "public conservation tier external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"} and value["mode"] == MODE
        and value["profile"] == PROFILE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
        and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public conservation tier closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "public conservation tier file commitments differ")
    require(all(p in files for p in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public conservation tier original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]),
        provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public conservation tier reconstruction differs")
    return rebuilt


def _read_input(path, limit):
    state = path.lstat()
    require(stat.S_ISREG(state.st_mode) and not path.is_symlink()
        and not (getattr(state, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)),
        "public conservation tier input must be a regular file")
    require(0 < state.st_size <= limit, "public conservation tier input byte bound")
    with path.open("rb") as stream: raw = stream.read(limit + 1)
    require(0 < len(raw) <= limit, "public conservation tier input byte bound")
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
                "public conservation tier RPC variable name invalid")
        raw = _read_input(args.anchor, 65536)
        constructor = _anchor(raw, args.anchor_hash, args.source_profile_hash)
        empty = dumps({"version": RPC_VERSION, "profile": RPC_PROFILE, "calls": []})
        constructor(raw, PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        if args.command == "capture":
            endpoint = os.environ.get(args.rpc_env)
            require(endpoint is not None and endpoint != "", "public conservation tier RPC variable unavailable")
            result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure=args.disclosure)
        else:
            transcript = _read_input(args.transcript, MAX_TRANSCRIPT)
            result = replay(raw, args.anchor_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure=args.disclosure)
            require(verify(dict(result.files), result.manifest_hash).files == result.files,
                "public conservation tier post-replay reconstruction differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)), "provenance": result.report["provenance"],
        "item13Status": result.report["item13"]["status"], "canonicalPacketCompatible": False,
        "tierBasis": result.report["tier"]["tierBasis"], "effectiveTier": result.report["tier"]["effectiveTier"],
        "prospectiveSaleTier": result.report["tier"]["prospectiveSaleTier"],
        "completeCanonicalPacket": False, "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}).decode("utf-8"))


if __name__ == "__main__": main()
