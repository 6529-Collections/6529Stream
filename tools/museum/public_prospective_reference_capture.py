"""Read-only original prospective simulations with exact offline replay."""
import argparse
import os
from pathlib import Path
import re
import stat

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import (PublicRpcTransport, PublicReplayTransport, MAX_TRANSCRIPT,
    PROFILE as RPC_PROFILE, VERSION as RPC_VERSION)

MODE = "public_prospective_reference_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_PROSPECTIVE_REFERENCE_CAPTURE_V1"
CLAIMS = {"readOnlyRpc":True,"consumerFixedReads":True,"offlineReplayChecked":True,
    "originalSourceBytesRetained":True,"originalProspectivePayloadsRetained":True,"originalAndCurrentSourcesSeparated":True,
    "providerLogCompletenessTrusted":True,"canonicalMappingTrusted":True,"historicalCurrentPairReplayed":False,
    "browserExecutionProven":False,"zipMembershipVerified":False,"postMintReferenceProven":False,
    "institutionalAcceptance":False,"runtimeArtifactAuthenticated":False,"nativeRuntimeAcceptance":False,
    "sourceConsensusVerified":False,"actualChainAcceptance":False,"completeCanonicalPacket":False,"endpointRetained":False}
QUALIFICATION = ("Exact original prospective simulation source/Publication/Receipt/environment/execution bytes and "
    "native count/head history are retained with separate current source observations. Original archive facts do not "
    "reproduce the historical currentReceiptPair gates, browser execution, ZIP membership, post-mint references, "
    "finality, institutional acceptance, runtime authenticity or consensus. No complete canonical packet is established.")
PROFILE_BYTES = dumps({"name":PROFILE,"version":"1","status":"prospective_unregistered_capture_profile",
    "source":"STREAM_MUSEUM_PUBLIC_PROSPECTIVE_REFERENCE_SOURCE_V1","inputPins":["anchorHash","sourceProfileHash"],
    "output":"Exact source triplet, source/history/RPC/capture profiles, source and gas observations, native definitions and every original canonical payload/publication/environment/script/HTML/execution byte sequence.",
    "endpoint":"Explicit named process environment variable; endpoint and remote errors are not retained.",
    "claims":CLAIMS,"qualification":QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _source():
    from . import public_prospective_reference_source as source
    return source


def _public(disclosure):
    require(disclosure == "public", "public prospective reference requires public disclosure before reads")


def _anchor(raw, expected_hash, expected_profile):
    module = _source()
    require(type(raw) is bytes and 0 < len(raw) <= module.MAX_ANCHOR
        and any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "public prospective reference external anchor pin/bound differs")
    require(expected_profile == module.PROFILE_HASH, "public prospective reference external source profile differs")
    return module.PublicProspectiveReferenceSource


def _derive(snapshot):
    files={"prospective/"+key+".json":dumps(snapshot[key]) for key in
        ("dependencies","gasHistory","currentSource","history","records")}
    files["prospective/evidence.json"]=dumps({key:snapshot[key] for key in
        ("source","sourceReviewCommit","sourceState","historyCoverage","claims","qualification")})
    for row in snapshot["definitions"]:
        files["definitions/native/"+row["documentId"][2:]+".json"]=hex_bytes(row["payloadHex"])
    for row in snapshot["records"]:
        prefix="prospective/records/"+row["index"].zfill(3)+"/"
        for name,key in (("payload.abi","payloadHex"),("publication.abi","publicationAbiHex"),("environment.json","environmentHex")):
            files[prefix+name]=hex_bytes(row[key])
        files[prefix+"script.js"]=hex_bytes(row["originalSource"][15])
        for i,capture in enumerate(row["captures"]):
            files[prefix+"captures/"+str(i)+".html"]=hex_bytes(capture["animationHTMLHex"])
            files[prefix+"captures/"+str(i)+".abi"]=hex_bytes(capture["executionHex"])
    return files


def _assemble(source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    module = _source()
    require(source_profile_hash == module.PROFILE_HASH and keccak256(source.anchor_bytes) == anchor_hash,
        "public prospective reference original capture pins differ")
    snapshot_bytes = source.snapshot(); transcript = source.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    files = {"source/anchor.json": source.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": module.PROFILE_BYTES,
        "definitions/history-profile.json": history.PROFILE_BYTES, "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES, **_derive(snapshot)}
    report = {"profile": PROFILE, "provenance": source.provenance, "sourceProfileHash": source_profile_hash,
        **{key: snapshot[key] for key in ("sourceState", "sourceReviewCommit", "dependencies", "gasHistory", "currentSource", "history", "records", "historyCoverage")},
        "canonicalPacketCompatible": False, "completeCanonicalPacket": False,
        "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash, "provenance": source.provenance,
        "files": [base._ref(path, body) for path, body in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public prospective reference manifest bound")
    files["manifest.json"] = raw; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    _public(disclosure); constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public prospective reference capture requires explicit read-only transport")
    result = _assemble(constructor(anchor_bytes, transport, provenance="trusted_rpc"), anchor_hash, source_profile_hash)
    require(verify(dict(result.files), result.manifest_hash).files == result.files, "public prospective reference post-capture replay differs")
    return result


def replay(anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    _public(disclosure); constructor = _anchor(anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public prospective reference explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash,
        "public prospective reference external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "anchorHash",
        "sourceProfileHash", "provenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public prospective reference closed manifest differs")
    require(value["files"] == [base._ref(path, body) for path, body in sorted(files.items()) if path != "manifest.json"],
        "public prospective reference file commitments differ")
    require(all(path in files for path in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public prospective reference original capture missing")
    rebuilt = replay(files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]), provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public prospective reference reconstruction differs")
    return rebuilt


def _read_input(path, limit):
    state = path.lstat()
    require(stat.S_ISREG(state.st_mode) and not path.is_symlink()
        and not (getattr(state, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0)),
        "public prospective reference input must be a regular file")
    require(0 < state.st_size <= limit, "public prospective reference input byte bound")
    with path.open("rb") as stream: raw = stream.read(limit + 1)
    require(0 < len(raw) <= limit, "public prospective reference input byte bound")
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
                "public prospective reference RPC environment variable name")
            endpoint = os.environ.get(args.rpc_env)
            require(type(endpoint) is str and endpoint.startswith(("http://", "https://")), "public prospective reference RPC endpoint missing")
            result = capture(raw, args.anchor_hash, args.source_profile_hash, PublicRpcTransport(endpoint), disclosure="public")
        else:
            transcript = _read_input(args.transcript, MAX_TRANSCRIPT)
            require(keccak256(transcript) == args.transcript_hash, "public prospective reference transcript pin differs")
            result = replay(raw, args.anchor_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure="public")
        require(verify(dict(result.files), result.manifest_hash).files == result.files,
            "public prospective reference pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "sourceProvenance": result.report["provenance"], "canonicalPacketCompatible": False}).decode("utf-8"))


if __name__ == "__main__": main()
