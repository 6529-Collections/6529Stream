"""Offline Transfer-evidence derivative retaining the complete institutional package."""
from pathlib import Path

from .canonical import MuseumError, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .institutional_package import verify_institutional_package
from .institutional_source import InstitutionalOwnerSource
from .institutional_transfers import CLAIMS, PROFILE_BYTES, PROFILE_HASH, TitleTransferCapture
from .package import write_package
from .package_v2 import _assemble, _read_package

MODE = "recorded_institutional_transfer_package"


def build_transfer_package(directory, source_manifest_hash, hints_bytes, transcript_bytes, *, hints_hash, transcript_hash, profile_hash):
    if profile_hash != PROFILE_HASH: raise MuseumError("institutional transfer profile differs")
    directory = Path(directory).resolve(); original = verify_institutional_package(directory, source_manifest_hash)
    retained = dict(original.files); manifest = loads(original.manifest, maximum=2097152)
    pins = manifest["ownerPins"]
    source = InstitutionalOwnerSource(retained["owner-records/anchor.json"],
        ReplayTransport(retained["owner-records/transcript.json"], pins["transcriptHash"]), provenance="trusted_rpc")
    capture = TitleTransferCapture(source, hints_bytes, ReplayTransport(transcript_bytes, transcript_hash),
        hints_hash=hints_hash, source_hash=pins["sourceHash"], provenance="trusted_rpc")
    report = capture.capture()
    files = {"source/" + name: raw for name, raw in original.files}
    files.update({"source/manifest.json": original.manifest, "inputs/hints.json": hints_bytes,
        "inputs/transcript.json": transcript_bytes, "definitions/profile.json": PROFILE_BYTES, "transfers/report.json": report})
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": source_manifest_hash,
        "hintsHash": hints_hash, "transcriptHash": transcript_hash, "profileHash": profile_hash, "claims": CLAIMS})


def verify_transfer_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve(); raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "hintsHash", "transcriptHash", "profileHash", "claims", "files"}
        or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("institutional transfer manifest differs")
    try:
        rebuilt = build_transfer_package(directory / "source", manifest["sourceManifestHash"], files["inputs/hints.json"], files["inputs/transcript.json"],
            hints_hash=manifest["hintsHash"], transcript_hash=manifest["transcriptHash"], profile_hash=manifest["profileHash"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("institutional transfer package input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("institutional transfer semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    build = sub.add_parser("build")
    for name in ("source", "hints", "transcript", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "hints-hash", "transcript-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify": result = verify_transfer_package(args.directory, args.manifest_hash)
        else:
            if args.hints.stat().st_size > 524288 or args.transcript.stat().st_size > MAX_TRANSCRIPT:
                raise MuseumError("institutional transfer input bound")
            result = build_transfer_package(args.source, args.source_manifest_hash, args.hints.read_bytes(), args.transcript.read_bytes(),
                hints_hash=args.hints_hash, transcript_hash=args.transcript_hash, profile_hash=args.profile_hash)
            write_package(result, args.directory)
        print(result.manifest_hash)
    except (MuseumError, OSError) as exc: parser.exit(2, str(exc) + "\n")


if __name__ == "__main__": main()
