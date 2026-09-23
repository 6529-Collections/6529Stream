"""Public-chain read-only source capture and exact offline verification.

Endpoints come only from an explicitly named environment variable. They are
never retained in captures. Original strict profiles use their existing tools.
"""
import argparse
import os
from pathlib import Path
import re

from . import object_dossier as base
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require
from .public_history_rpc import PublicRpcTransport, PublicReplayTransport

MODE = "public_native_history_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_HISTORY_CAPTURE_V1"
CLAIMS = {"readOnlyRpc": True, "consumerFixedFilters": True, "offlineReplayChecked": True,
    "providerLogCompletenessTrusted": True, "providerCanonicalMappingTrusted": True,
    "genesisWalk": False, "allBlockReceipts": False, "ancestryProof": False,
    "sourceConsensusVerified": False, "sourceProvenanceSelfAuthenticated": False,
    "fullAcquisitionPacket": False, "actualChainAcceptance": False, "endpointRetained": False}
QUALIFICATION = ("Capture of a concrete public-history source at an externally pinned block and runtime. "
    "Inclusive fixed-filter pages, returned logs/receipts/headers and native state joins are checked; "
    "provider log completeness and canonical block mapping remain trusted. A successful RPC response "
    "alone does not establish source completeness. Neither replay nor a local manifest authenticates "
    "source provenance, consensus, ancestry, a full acquisition packet or actual chain acceptance.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "sources": ["rights", "ownership"], "inputPins": ["anchorHash", "sourceProfileHash"],
    "endpoint": "Explicit named process environment variable; never in manifest/transcript/error detail.",
    "output": "Exact source triplet, frozen profile definitions, source-derived output and closed manifest; offline reconstruction required.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure):
    require(disclosure == "public", "public history requires explicit public disclosure before reads")


def _sources():
    from . import public_rights_source as rights
    from . import public_ownership_source as ownership
    return {"rights": (rights.PublicRightsSource, rights.PROFILE_BYTES, rights.PROFILE_HASH),
        "ownership": (ownership.PublicOwnershipSource, ownership.PROFILE_BYTES, ownership.PROFILE_HASH)}


def _anchor(kind, raw, expected_hash, expected_profile):
    sources = _sources()
    require(kind in sources, "public history source kind unsupported")
    require(type(raw) is bytes and 0 < len(raw) <= 65536 and any(hex_bytes(expected_hash, 32))
        and keccak256(raw) == expected_hash, "public history external anchor pin/bound differs")
    require(expected_profile == sources[kind][2], "public history external source profile differs")
    return sources[kind]


def _derive(kind, snapshot, anchor, snapshot_bytes):
    if kind == "ownership":
        raw = snapshot["tokenTransferJsonl"].encode("utf-8")
        require(keccak256(raw) == snapshot["tokenTransferJsonlHash"], "public ownership exact JSONL differs")
        return {"ownership/transfers.jsonl": raw}
    from .dossier_rights import _fragment, _extract
    # These pure adapters preserve the original canonical RIGHTS schema. They
    # confer no source admission; the concrete public reader has already run.
    fragment = _fragment(snapshot, anchor, snapshot_bytes)
    fragment["selectionEvidence"]["uri"] = "source/snapshot.json"
    return _extract(snapshot) | {"rights/packet-fragment.json": dumps(fragment)}


def _assemble(kind, source, anchor_hash, source_profile_hash):
    from . import public_chain_history as history
    from . import public_history_rpc as rpc
    _, source_profile, actual_profile = _sources()[kind]
    require(source_profile_hash == actual_profile and keccak256(source.anchor_bytes) == anchor_hash,
        "public history original capture pins differ")
    snapshot_bytes = source.snapshot()
    transcript = source.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    files = {"source/anchor.json": source.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": source_profile,
        "definitions/history-profile.json": history.PROFILE_BYTES,
        "definitions/rpc-profile.json": rpc.PROFILE_BYTES,
        "definitions/capture-profile.json": PROFILE_BYTES}
    files.update(_derive(kind, snapshot, source.a, snapshot_bytes))
    report = {"profile": PROFILE, "kind": kind, "provenance": source.provenance,
        "sourceProfileHash": source_profile_hash, "historyCoverage": snapshot["historyCoverage"],
        "identity": snapshot["identity"], "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report)
    base._bounded(files)
    raw = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "kind": kind, "anchorHash": anchor_hash, "sourceProfileHash": source_profile_hash,
        "provenance": source.provenance, "files": [base._ref(p, b) for p, b in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(raw) <= MAX_MANIFEST, "public history capture manifest bound")
    files["manifest.json"] = raw
    base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), raw, report)


def capture(kind, anchor_bytes, anchor_hash, source_profile_hash, transport, *, disclosure):
    """Actual RPC entry point; full offline readback must pass before returning."""
    _public(disclosure)
    constructor, _, _ = _anchor(kind, anchor_bytes, anchor_hash, source_profile_hash)
    require(type(transport) is PublicRpcTransport, "public history capture requires explicit read-only transport")
    source = constructor(anchor_bytes, transport, provenance="trusted_rpc")
    result = _assemble(kind, source, anchor_hash, source_profile_hash)
    rebuilt = verify(dict(result.files), result.manifest_hash)
    require(rebuilt.files == result.files, "public history post-capture replay differs")
    return result


def replay(kind, anchor_bytes, anchor_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    """Retained-byte entry point, also useful for explicitly synthetic vectors."""
    _public(disclosure)
    constructor, _, _ = _anchor(kind, anchor_bytes, anchor_hash, source_profile_hash)
    require(provenance in ("trusted_rpc", "synthetic_fixture"), "public history explicit provenance required")
    source = constructor(anchor_bytes, PublicReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(kind, source, anchor_hash, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files)
    raw = files.get("manifest.json", b"")
    require(keccak256(raw) == expected_hash, "public history external manifest pin differs")
    value = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(value) is dict and set(value) == {"mode", "profile", "version", "profileHash", "kind",
        "anchorHash", "sourceProfileHash", "provenance", "files", "claims", "qualification"}
        and value["mode"] == MODE and value["profile"] == PROFILE and value["version"] == "1"
        and value["profileHash"] == PROFILE_HASH and value["claims"] == CLAIMS and value["qualification"] == QUALIFICATION,
        "public history closed manifest differs")
    require(value["files"] == [base._ref(p, b) for p, b in sorted(files.items()) if p != "manifest.json"],
        "public history original file commitments differ")
    require(all(p in files for p in ("source/anchor.json", "source/transcript.json", "source/snapshot.json")),
        "public history required original capture missing")
    rebuilt = replay(value["kind"], files["source/anchor.json"], value["anchorHash"], value["sourceProfileHash"],
        files["source/transcript.json"], keccak256(files["source/transcript.json"]),
        provenance=value["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "public history source reconstruction differs")
    return rebuilt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    live = sub.add_parser("capture")
    live.add_argument("--kind", choices=("rights", "ownership"), required=True)
    live.add_argument("--anchor", type=Path, required=True)
    live.add_argument("--anchor-hash", required=True)
    live.add_argument("--source-profile-hash", required=True)
    live.add_argument("--rpc-env", required=True)
    live.add_argument("--disclosure", required=True)
    live.add_argument("--output", type=Path, required=True)
    check = sub.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles")
    args = parser.parse_args()
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH,
            "sources": {kind: row[2] for kind, row in _sources().items()}}).decode("utf-8"))
        return
    if args.command == "capture":
        _public(args.disclosure)
        from .repository_exchange import _destination, _publish
        _destination(args.output, [args.anchor])
        require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", args.rpc_env) is not None,
            "public history RPC environment variable name invalid")
        with args.anchor.open("rb") as stream:
            raw = stream.read(65537)
        constructor, _, _ = _anchor(args.kind, raw, args.anchor_hash, args.source_profile_hash)
        # Anchor schema validation also precedes opening the endpoint.
        empty = dumps({"version": 2, "profile": "STREAM_MUSEUM_PUBLIC_HISTORY_RPC_V1", "calls": []})
        constructor(raw, PublicReplayTransport(empty, keccak256(empty)), provenance="trusted_rpc")
        endpoint = os.environ.get(args.rpc_env)
        require(endpoint is not None and endpoint != "", "public history RPC environment variable unavailable")
        result = capture(args.kind, raw, args.anchor_hash, args.source_profile_hash,
            PublicRpcTransport(endpoint), disclosure=args.disclosure)
        _publish(dict(result.files), args.output, [args.anchor])
    else:
        result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "kind": result.report["kind"], "provenance": result.report["provenance"],
        "providerLogCompletenessTrusted": True, "sourceConsensusVerified": False}).decode("utf-8"))


if __name__ == "__main__":
    main()
