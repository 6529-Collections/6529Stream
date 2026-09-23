"""Read-only original native finality capture and complete offline reconstruction."""
import argparse
import os
from pathlib import Path
import re
import stat

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_scoped_finality_rpc import (PublicScopedRpcTransport as PublicRpcTransport, PublicScopedReplayTransport as PublicReplayTransport, MAX_TRANSCRIPT,
    PROFILE as RPC_PROFILE, VERSION as RPC_VERSION)

MODE = "public_scoped_finality_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_SCOPED_STATIC_FINALITY_CAPTURE_V1"
CLAIMS = {"readOnlyRpc": True, "offlineReplayChecked": True, "originalSourceBytesRetained": True,
    "providerLogCompletenessTrusted": True, "canonicalMappingTrusted": True, "nativeTokenProofChecked": True,
    "currentArchiveLivenessChecked": False, "completeAuthority": False,
    "historicalCoreFactsPreimageRecovered": False, "sourceProvenanceSelfAuthenticated": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False,
    "canonicalPacketCompatible": False, "completeCanonicalPacket": False, "endpointRetained": False}
QUALIFICATION = ("Original TOKEN/RELEASE/SEASON STATIC finality, complete membership, selection and output-hash rows, "
    "original scoped snapshots and root lineage. Original Executor transaction observations strengthen supported "
    "direct-call reconstruction while missing/unsupported inputs remain partial. Historical Core facts, rendered "
    "bytes, authority execution, signatures and consensus remain unresolved. The capture is not a complete packet.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "source": "STREAM_MUSEUM_PUBLIC_SCOPED_STATIC_FINALITY_SOURCE_V1",
    "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit process environment variable; endpoint and remote errors never retained.",
    "output": "Original source triplet, nine exact native definition documents, complete captured scoped evidence, transaction observations and supplied fragment/token proof.",
    "coverage": "Original scoped STATIC native finality and token membership; complete historical authority, renderer source preimages and Core facts remain partial.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_scoped_finality_source as source
    return source


def _public(disclosure):
    require(disclosure == "public", "public scoped finality requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    module = _source()
    require(type(raw) is bytes and 0 < len(raw) <= module.MAX_ANCHOR
        and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "public scoped finality external anchor pin/bound differs")
    require(expected_profile == module.PROFILE_HASH, "public scoped finality external source profile differs")
    return module.PublicScopedFinalitySource


def _derive(snapshot, snapshot_bytes):
    from ..metadata import acquisition_scoped_static_finality_v1 as definition
    refs = {"sourceProfileHash": snapshot["profileHash"], "anchorHash": snapshot["anchorHash"],
        "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(snapshot_bytes), "provenance": snapshot["provenance"]}
    fragment = definition.semanticProjection(snapshot, refs)
    return {"scoped-finality/fragment.json": dumps(fragment),
        "scoped-finality/token-proof.json": dumps(definition.token_proof(fragment)),
        "definitions/scoped-finality-fragment.json": definition.SCHEMA_BYTES}


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_scoped_finality_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "public scoped finality original capture pins differ")
    snapshot_bytes = source.snapshot(); transcript = source.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    files = {"source/anchor.json": source.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": module.PROFILE_BYTES,
        "definitions/history-profile.json": history.PROFILE_BYTES, "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES, **_derive(snapshot, snapshot_bytes)}
    files.update({"definitions/native/"+row["name"]+".json":row["bytes"] for row in module.wire.definitions()})
    report = {"profile": PROFILE, "provenance": source.provenance, "sourceProfileHash": source_profile_hash,
        **{key: snapshot[key] for key in ("sourceState", "sourceReviewCommit", "identity", "historicalCoreFacts", "historyCoverage")},
        "finalityRecordHash": snapshot["bundle"]["finality"]["record"][2],
        "fragmentPath": "scoped-finality/fragment.json", "tokenProofPath": "scoped-finality/token-proof.json",
        "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
        "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash, "provenance": source.provenance,
        "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public scoped finality manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    _public(disclosure); constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public scoped finality capture requires explicit read-only transport")
    result = _assemble(constructor(anchor_bytes, transport, provenance="trusted_rpc"), anchor_hash, source_profile_hash)
    require(verify(dict(result.files), result.manifest_hash).files == result.files, "public scoped finality post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    _public(disclosure); constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public scoped finality explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "public scoped finality external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public scoped finality closed manifest differs")
    require(value["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "public scoped finality file commitments differ")
    require(all(path in files for path in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public scoped finality original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]), provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public scoped finality reconstruction differs")
    return rebuilt


def _read_input(path, limit):
    state = path.lstat()
    require(stat.S_ISREG(state.st_mode) and not path.is_symlink()
        and not (getattr(state, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)),
        "public scoped finality input must be a regular file")
    require(0 < state.st_size <= limit, "public scoped finality input byte bound")
    with path.open("rb") as stream: raw = stream.read(limit + 1)
    require(0 < len(raw) <= limit, "public scoped finality input byte bound")
    return raw


def main(argv=None):
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
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH, "sourceProfileHash": _source().PROFILE_HASH}).decode("utf-8")); return
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
                "public scoped finality RPC environment variable name")
            endpoint = os.environ.get(args.rpc_env)
            require(type(endpoint) is str and endpoint.startswith(("http://", "https://")), "public scoped finality RPC endpoint missing")
            result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure="public")
        else:
            transcript = _read_input(args.transcript, MAX_TRANSCRIPT)
            require(keccak256(transcript) == args.transcript_hash, "public scoped finality transcript pin differs")
            result = replay(raw, args.anchor_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure="public")
        require(verify(dict(result.files), result.manifest_hash).files == result.files,
            "public scoped finality pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "sourceProvenance": result.report["provenance"], "canonicalPacketCompatible": False}).decode("utf-8"))


if __name__ == "__main__": main()
