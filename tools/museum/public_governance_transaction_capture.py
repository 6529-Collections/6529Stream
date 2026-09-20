"""Read-only original governance transaction capture with complete offline replay."""
import argparse
import os
from pathlib import Path
import re

from . import object_dossier as base
from . import public_governance_transaction_rpc as rpc
from . import public_governance_transaction_source as source
from .bagit import MAX_BYTES, MAX_MANIFEST, read_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .independent_wire import require

MODE = "public_governance_transaction_capture"
PROFILE = "STREAM_MUSEUM_PUBLIC_GOVERNANCE_TRANSACTION_CAPTURE_V1"
NATIVE_PREFIX = "inputs/native-finality/"
FRAGMENT_PATH = "governance/transactions.json"
CLAIMS = {"readOnlyRpc": True, "offlineReplayChecked": True, "originalNativeCapturePreserved": True,
    "originalTransactionObservationsRetained": True, "originalReceiptAndHeaderJoinChecked": True,
    "missingInputsRemainPartial": True, "completeAuthority": False, "signedTransactionHashVerified": False,
    "historicalCoreFactsPreimageRecovered": False, "historicalExecutionReenacted": False,
    "sourceConsensusVerified": False, "actualChainAcceptance": False, "endpointRetained": False}
QUALIFICATION = ("Additive original governance transaction evidence. All original native capture bytes remain available; "
    "decoded call/action-ID preimages are a separate report and do not rewrite published native/V6 authority claims. "
    "Missing or unsupported transaction observations stay partial. Historical authority, policy, EVM execution, "
    "Core-facts preimage and consensus remain unresolved.")
PROFILE_BYTES = dumps({"name": PROFILE, "version": "1", "status": "prospective_unregistered_capture_profile",
    "sourceProfileHash": source.PROFILE_HASH, "rpcProfileHash": rpc.PROFILE_HASH,
    "input": "Externally pinned verified original native finality capture; original source derives every transaction lookup target.",
    "retention": "Entire original native capture under " + NATIVE_PREFIX + "; new source triplet, original transaction/receipt/header bytes, supplied fragment and separate reconstruction report.",
    "endpoint": "Explicit process environment variable; endpoint and remote error details never enter evidence.",
    "claims": CLAIMS, "qualification": QUALIFICATION})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def _public(disclosure): require(disclosure == "public", "governance capture requires public disclosure before reads")


def _profile(expected): require(expected == source.PROFILE_HASH, "governance external source profile differs")


def _assemble(observed, source_profile_hash):
    _profile(source_profile_hash)
    from ..metadata import acquisition_governance_transactions_v1 as definition
    snapshot_bytes = observed.snapshot(); transcript = observed.transcript()
    snapshot = loads(snapshot_bytes, maximum=MAX_BYTES, canonical=True)
    refs = {"sourceProfileHash": source.PROFILE_HASH, "anchorHash": snapshot["anchorHash"],
        "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(snapshot_bytes), "provenance": observed.provenance}
    fragment = definition.semanticProjection(snapshot, refs)
    files = {NATIVE_PREFIX + path: raw for path, raw in observed.captured.files}
    files.update({"source/anchor.json": observed.anchor_bytes, "source/transcript.json": transcript,
        "source/snapshot.json": snapshot_bytes, "definitions/source-profile.json": source.PROFILE_BYTES,
        "definitions/rpc-profile.json": rpc.PROFILE_BYTES, "definitions/capture-profile.json": PROFILE_BYTES,
        "definitions/governance-transactions.json": definition.SCHEMA_BYTES, FRAGMENT_PATH: dumps(fragment)})
    report = {"profile": PROFILE, "version": "1", "provenance": observed.provenance,
        "sourceState": snapshot["sourceState"], "sourceReviewCommit": source.SOURCE_REVISION,
        "nativeManifestHash": observed.captured.manifest_hash, "sourceProfileHash": source.PROFILE_HASH,
        "fragmentPath": FRAGMENT_PATH, "fragmentHash": keccak256(files[FRAGMENT_PATH]),
        "reconstruction": fragment["reconstruction"], "claims": CLAIMS, "qualification": QUALIFICATION}
    files["capture/report.json"] = dumps(report); base._bounded(files)
    manifest = dumps({"mode": MODE, "profile": PROFILE, "version": "1", "profileHash": PROFILE_HASH,
        "nativeManifestHash": observed.captured.manifest_hash, "sourceProfileHash": source.PROFILE_HASH,
        "provenance": observed.provenance, "files": [base._ref(path, raw) for path, raw in sorted(files.items())],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(manifest) <= MAX_MANIFEST, "governance capture manifest bound")
    files["manifest.json"] = manifest; base._bounded(files)
    return base.Assembly(tuple(sorted(files.items())), manifest, report)


def capture(native_files, native_manifest_hash, source_profile_hash, transport, *, disclosure):
    _public(disclosure); _profile(source_profile_hash)
    require(type(transport) is rpc.PublicGovernanceRpcTransport, "governance capture requires explicit read-only transport")
    result = _assemble(source.PublicGovernanceTransactionSource(native_files, native_manifest_hash, transport,
        provenance="trusted_rpc"), source_profile_hash)
    require(verify(result.files, result.manifest_hash).files == result.files, "governance post-capture replay differs")
    return result


def replay(native_files, native_manifest_hash, source_profile_hash, transcript, transcript_hash, *, provenance, disclosure):
    _public(disclosure); _profile(source_profile_hash)
    observed = source.PublicGovernanceTransactionSource(native_files, native_manifest_hash,
        rpc.PublicGovernanceReplayTransport(transcript, transcript_hash), provenance=provenance)
    return _assemble(observed, source_profile_hash)


def verify(files, expected_hash):
    files = dict(files); base._bounded(files); raw = files.get("manifest.json", b"")
    require(any(hex_bytes(expected_hash, 32)) and keccak256(raw) == expected_hash, "governance capture external manifest pin differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"mode", "profile", "version", "profileHash",
        "nativeManifestHash", "sourceProfileHash", "provenance", "files", "claims", "qualification"}
        and manifest["mode"] == MODE and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["profileHash"] == PROFILE_HASH and manifest["claims"] == CLAIMS
        and manifest["qualification"] == QUALIFICATION, "governance capture closed manifest differs")
    require(manifest["files"] == [base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"],
        "governance capture file commitments differ")
    require("source/transcript.json" in files, "governance original transcript missing")
    native = {path.removeprefix(NATIVE_PREFIX): raw for path, raw in files.items() if path.startswith(NATIVE_PREFIX)}
    transcript = files["source/transcript.json"]
    rebuilt = replay(native, manifest["nativeManifestHash"], manifest["sourceProfileHash"], transcript,
        keccak256(transcript), provenance=manifest["provenance"], disclosure="public")
    require(dict(rebuilt.files) == files, "governance capture reconstruction differs")
    return rebuilt


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    for command in ("capture", "replay"):
        child = sub.add_parser(command)
        child.add_argument("--native", type=Path, required=True); child.add_argument("--native-hash", required=True)
        child.add_argument("--source-profile-hash", required=True); child.add_argument("--disclosure", required=True)
        child.add_argument("--output", type=Path, required=True)
        if command == "capture": child.add_argument("--rpc-env", required=True)
        else:
            child.add_argument("--transcript", type=Path, required=True); child.add_argument("--transcript-hash", required=True)
            child.add_argument("--provenance", choices=("trusted_rpc", "synthetic_fixture"), required=True)
    check = sub.add_parser("verify"); check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    sub.add_parser("profiles"); args = parser.parse_args(argv)
    if args.command == "profiles":
        print(dumps({"captureProfileHash": PROFILE_HASH, "sourceProfileHash": source.PROFILE_HASH,
            "rpcProfileHash": rpc.PROFILE_HASH}).decode()); return
    if args.command in ("capture", "replay"):
        _public(args.disclosure); _profile(args.source_profile_hash)
        from .repository_exchange import _destination, _publish
        sources = [args.native] + ([args.transcript] if args.command == "replay" else [])
        _destination(args.output, sources)
        native = read_tree(args.native)
        # Verify original source before loading endpoint credentials or making any read.
        source.original_observations(native, args.native_hash)
        if args.command == "capture":
            require(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", args.rpc_env) is not None,
                "governance RPC environment variable name")
            endpoint = os.environ.get(args.rpc_env)
            require(type(endpoint) is str and endpoint.startswith(("http://", "https://")), "governance RPC endpoint missing")
            result = capture(native, args.native_hash, args.source_profile_hash, rpc.PublicGovernanceRpcTransport(endpoint), disclosure="public")
        else:
            from .public_finality_capture import _read_input
            transcript = _read_input(args.transcript, rpc.MAX_TRANSCRIPT)
            result = replay(native, args.native_hash, args.source_profile_hash, transcript, args.transcript_hash,
                provenance=args.provenance, disclosure="public")
        require(verify(result.files, result.manifest_hash).files == result.files, "governance capture pre-publication replay differs")
        _publish(dict(result.files), args.output, sources)
    else: result = verify(read_tree(args.directory), args.manifest_hash)
    print(dumps({"manifestHash": result.manifest_hash, "files": str(len(result.files)),
        "provenance": result.report["provenance"], "reconstruction": result.report["reconstruction"],
        "completeAuthority": False}).decode())


if __name__ == "__main__": main()
