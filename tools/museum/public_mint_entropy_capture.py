"""Read-only public mint/entropy capture under a distinct replay profile."""
import argparse
import os
from pathlib import Path
import re

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import PublicRpcTransport, PublicReplayTransport, PROFILE as RPC_PROFILE, VERSION as RPC_VERSION

MODE = "public_mint_entropy_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_MINT_ENTROPY_CAPTURE_V1"
CLAIMS = {"readOnlyRpc": True, "consumerDerivedFilters": True, "offlineReplayChecked": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "lifetimeAttemptHighWaterProven": False, "genesisWalk": False, "allBlockReceipts": False,
    "sourceConsensusVerified": False, "sourceProvenanceSelfAuthenticated": False,
    "originalPaidSaleEvidenceComplete": False, "fullAcquisitionPacket": False,
    "actualChainAcceptance": False, "endpointRetained": False}
QUALIFICATION = ("Concrete public-history mint and original-coordinator entropy evidence at an externally pinned block. "
    "Native request policies, recovery decisions, event chronology and current views reconcile; provider log "
    "completeness and canonical mapping remain trusted. Observed request count and maximum attempt do not prove "
    "a lifetime highwater; late original fulfillment may restore an earlier active request. Replay does not "
    "authenticate provenance, consensus, oracle quality, original paid-sale authorization or a full acquisition packet.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "source": "STREAM_MUSEUM_PUBLIC_MINT_ENTROPY_SOURCE_V1",
    "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit named process environment variable; never in retained evidence or remote error details.",
    "output": "Exact original source triplet, frozen definitions, original mint events, entropy packet fragment and ABI leaf preimage; complete offline reconstruction required.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_mint_entropy_source as source
    return source


def _public(disclosure):
    require(disclosure == "public", "public mint entropy requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    source = _source()
    require(type(raw) is bytes and 0 < len(raw) <= 65536 and any(hex_bytes(expected_hash, 32))
        and keccak256(raw) == expected_hash, "public mint entropy external anchor pin/bound differs")
    require(expected_profile == source.PROFILE_HASH, "public mint entropy external source profile differs")
    return source.PublicMintEntropySource


def _derive(snapshot):
    raw = hex_bytes(snapshot["entropyLeafBytes"])
    require(keccak256(raw) == snapshot["entropy"]["leafHash"], "public mint entropy leaf preimage differs")
    from tools.metadata.genesis_dossier_profile import _entropy_hash
    require(_entropy_hash(snapshot["entropy"]["leaf"]) == snapshot["entropy"]["leafHash"],
        "public mint entropy original packet leaf differs")
    return {"mint/evidence.json": dumps(snapshot["mint"]),
        "mint/transfers.jsonl": b"".join(dumps(log) + b"\n" for log in snapshot["mint"]["tokenTransfers"]),
        "entropy/packet-fragment.json": dumps(snapshot["entropy"]),
        "entropy/leaf-preimage.bin": raw,
        "entropy/request-history-observation.json": dumps(snapshot["requestHistoryObservation"])}


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "public mint entropy original capture pins differ")
    snapshot_bytes = source.snapshot(); transcript = source.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    files = {"source/anchor.json": source.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": module.PROFILE_BYTES,
        "definitions/history-profile.json": history.PROFILE_BYTES, "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES, **_derive(snapshot)}
    report = {"profile": PROFILE, "provenance": source.provenance, "sourceProfileHash": source_profile_hash,
        "historyCoverage": snapshot["historyCoverage"], "identity": snapshot["identity"],
        "observedStatus": snapshot["observedStatus"], "observedStatusLabel": snapshot["observedStatusLabel"],
        "terminalEligible": snapshot["terminalEligible"], "requestHistoryObservation": snapshot["requestHistoryObservation"],
        "remaining": snapshot["remaining"], "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash, "provenance": source.provenance,
        "files": [base._ref(p, b) for p, b in sorted(files.items())], "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public mint entropy capture manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public mint entropy capture requires explicit read-only transport")
    source = constructor(anchor_bytes, transport, provenance="trusted_rpc")
    result = _assemble(source, anchor_hash, source_profile_hash)
    require(verify(dict(result.files), result.manifest_hash).files == result.files,
        "public mint entropy post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public mint entropy explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "public mint entropy external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"} and value["mode"] == MODE
        and value["profile"] == PROFILE and value["version"] == "1" and value["profileHash"] == PROFILE_HASH
        and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public mint entropy closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "public mint entropy file commitments differ")
    require(all(p in files for p in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public mint entropy original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]), provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public mint entropy reconstruction differs")
    return rebuilt


def main():
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    live = sub.add_parser("capture")
    live.add_argument("--anchor", type=Path, required=True); live.add_argument("--anchor-hash", required=True)
    live.add_argument("--source-profile-hash", required=True); live.add_argument("--rpc-env", required=True)
    live.add_argument("--disclosure", required=True); live.add_argument("--output", type=Path, required=True)
    check = sub.add_parser("verify"); check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args()
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH, "sourceProfileHash": _source().PROFILE_HASH}).decode("utf-8")); return
    if args.command == "capture":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        _destination(args.output, [args.anchor])
        require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", args.rpc_env) is not None, "public mint entropy RPC variable name invalid")
        with args.anchor.open("rb") as stream: raw = stream.read(65537)
        constructor = _anchor(raw, args.anchor_hash, args.source_profile_hash)
        empty = dumps({"version": RPC_VERSION, "profile": RPC_PROFILE, "calls": []})
        constructor(raw, PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        endpoint = os.environ.get(args.rpc_env)
        require(endpoint is not None and endpoint != "", "public mint entropy RPC variable unavailable")
        result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure=args.disclosure)
        _publish(dict(result.files), args.output, [args.anchor])
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)), "provenance": result.report["provenance"],
        "observedStatus": result.report["observedStatusLabel"], "terminalEligible": result.report["terminalEligible"],
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}).decode("utf-8"))


if __name__ == "__main__": main()
