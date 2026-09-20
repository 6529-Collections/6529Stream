"""Read-only adopted VIEW output capture with exact offline reconstruction."""
import argparse
import os
from pathlib import Path
import re

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import (PublicRpcTransport, PublicReplayTransport,
    MAX_TRANSCRIPT, PROFILE as RPC_PROFILE, VERSION as RPC_VERSION)
from .public_scoped_policy_finality_capture_v2 import _read_input

MODE = "public_view_policy_output_capture_v2"
PROFILE = "STREAM_MUSEUM_PUBLIC_VIEW_POLICY_OUTPUT_CAPTURE_V2"
CLAIMS = {"readOnlyRpc": True, "offlineReplayChecked": True,
    "originalSourceBytesRetained": True, "completeCheckpointRowsChecked": True,
    "coveredOutputPartBytesChecked": True, "providerLogCompletenessTrusted": True,
    "originalRenderedBytesRecovered": False, "rendererReexecuted": False,
    "historicalAuthorityVerified": False, "currentEligibilityVerified": False,
    "currentArchiveLivenessVerified": False, "viewFinalityEstablished": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "completeAcquisitionPacket": False, "endpointRetained": False}
QUALIFICATION = (
    "Historical adopted VIEW V2 output evidence under an externally pinned native revision. "
    "Complete original declaration and tagged adoption history, sealed membership, source-set policies, "
    "checkpoint rows and covered parts/index are retained and joined. The output root commits an ordered "
    "row chain; it is not a token Merkle proof or a finality receipt. Output hashes and lengths do not "
    "recover complete rendered JSON/HTML, media or browser execution. Later adoption heads and token "
    "burns remain separate observations. Current eligibility, archive liveness, historical authority, "
    "signatures, runtime provenance, consensus and acquisition acceptance remain separate obligations. "
    "The pinned native revision does not admit VIEW snapshot/reference/provider finality.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "2",
    "status": "prospective_unregistered_capture_profile",
    "source": "STREAM_MUSEUM_PUBLIC_VIEW_POLICY_OUTPUT_SOURCE_V2",
    "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit process environment variable; no endpoint or raw remote error retention.",
    "output": "Exact source anchor/transcript/snapshot, native definitions and complete adopted VIEW output evidence.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_view_policy_output_source_v2 as source
    return source


def _public(disclosure):
    require(disclosure == "public", "VIEW output capture requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    module = _source()
    require(type(raw) is bytes and 0 < len(raw) <= module.MAX_ANCHOR
        and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "VIEW output external anchor pin/bound differs")
    require(expected_profile == module.PROFILE_HASH, "VIEW output external source profile differs")
    return module.PublicViewPolicyOutputSource


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "VIEW output original capture pins differ")
    snapshot_bytes = source.snapshot()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    files = {"source/anchor.json": source.anchor_bytes,
        "source/transcript.json": source.transcript(), "source/snapshot.json": snapshot_bytes,
        "definitions/source-profile.json": module.PROFILE_BYTES,
        "definitions/history-profile.json": history.PROFILE_BYTES,
        "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES,
        "view-output/evidence.json": dumps(snapshot["bundle"]),
        "view-output/target-row.json": dumps(snapshot["targetOutput"])}
    files.update({"definitions/native/" + row["name"] + ".json": row["bytes"]
        for row in module.wire.definitions()})
    report = {"profile": PROFILE, "provenance": source.provenance,
        "sourceProfileHash": source_profile_hash,
        **{key: snapshot[key] for key in ("sourceState", "sourceReviewCommit", "identity", "historyCoverage")},
        "checkpointId": snapshot["bundle"]["output"]["checkpoint"]["id"],
        "manifestRecordHash": snapshot["bundle"]["output"]["manifest"]["recordHash"],
        "evidencePath": "view-output/evidence.json", "targetRowPath": "view-output/target-row.json",
        "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
        "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report)
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "2", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash,
        "provenance": source.provenance,
        "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "VIEW output manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "VIEW output requires explicit read-only transport")
    result = _assemble(constructor(anchor_bytes, transport, provenance="trusted_rpc"), anchor_hash, source_profile_hash)
    require(verify(result.files, result.manifest_hash).files == result.files, "VIEW output post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    _public(disclosure)
    constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "VIEW output explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files)
    base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "VIEW output external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "2"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS
        and value["qualification"] == QUALIFICATION, "VIEW output closed manifest differs")
    require(value["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "VIEW output file commitments differ")
    require(all(path in files for path in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "VIEW output original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]),
        provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "VIEW output reconstruction differs")
    return rebuilt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    for command in ("capture", "replay"):
        child = sub.add_parser(command)
        child.add_argument("--anchor", type=Path, required=True)
        child.add_argument("--anchor-hash", required=True)
        child.add_argument("--source-profile-hash", required=True)
        child.add_argument("--disclosure", required=True)
        child.add_argument("--output", type=Path, required=True)
        if command == "capture": child.add_argument("--rpc-env", required=True)
        else:
            child.add_argument("--transcript", type=Path, required=True)
            child.add_argument("--transcript-hash", required=True)
            child.add_argument("--provenance", choices=("trusted_rpc", "synthetic_fixture"), required=True)
    check = sub.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles")
    args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH, "sourceProfileHash": _source().PROFILE_HASH}).decode())
        return
    if args.command in ("capture", "replay"):
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        sources = [args.anchor] + ([args.transcript] if args.command == "replay" else [])
        _destination(args.output, sources)
        raw = _read_input(args.anchor, _source().MAX_ANCHOR)
        constructor = _anchor(raw, args.anchor_hash, args.source_profile_hash)
        empty = dumps({"version": RPC_VERSION, "profile": RPC_PROFILE, "calls": []})
        constructor(raw, PublicReplayTransport(empty, keccak256(empty)),
            provenance="trusted_rpc" if args.command == "capture" else args.provenance)
        if args.command == "capture":
            require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", args.rpc_env) is not None,
                "VIEW output RPC environment variable name")
            endpoint = os.environ.get(args.rpc_env)
            require(type(endpoint) is str and endpoint.startswith(("http://", "https://")), "VIEW output RPC endpoint missing")
            result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure="public")
        else:
            transcript = _read_input(args.transcript, MAX_TRANSCRIPT)
            require(keccak256(transcript) == args.transcript_hash, "VIEW output transcript pin differs")
            result = replay(raw, args.anchor_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "VIEW output publication replay differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "sourceProvenance": result.report["provenance"], "canonicalPacketCompatible": False}).decode())


if __name__ == "__main__": main()
