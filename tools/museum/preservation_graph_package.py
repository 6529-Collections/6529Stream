"""Offline activity-graph derivative; retains the verified preservation package literally."""
from pathlib import Path

from .canonical import MuseumError, loads
from .package import write_package
from .package_v2 import _assemble, _read_package
from .preservation_package import verify_preservation_package
from .preservation_graph import CLAIMS, PROFILE_BYTES, PROFILE_HASH, render, validator

MODE = "recorded_preservation_activity_graph_package"


def build_graph_package(directory, expected_manifest_hash, *, profile_hash, disclosure):
    if disclosure != "public": raise MuseumError("preservation graph requires explicit public classification")
    if profile_hash != PROFILE_HASH: raise MuseumError("preservation graph profile hash mismatch")
    directory = Path(directory).resolve()
    original = verify_preservation_package(directory, expected_manifest_hash)
    source = dict(original.files)
    files = {"source/" + name: raw for name, raw in original.files}
    files["source/manifest.json"] = original.manifest
    files["definitions/activity-graph-profile.json"] = PROFILE_BYTES
    model = validator(directory / "source/dependencies")
    files.update(render(source.get("premis-preservation/premis.xml"), source["premis-preservation/report.json"],
        source["premis-preservation/provenance.json"], model))
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "profileHash": PROFILE_HASH, "disclosure": disclosure, "claims": CLAIMS})


def verify_graph_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "profileHash", "disclosure", "claims", "files"}
            or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("unsupported preservation activity graph manifest")
    try:
        rebuilt = build_graph_package(directory / "source", manifest["sourceManifestHash"],
            profile_hash=manifest["profileHash"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("preservation graph source missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("preservation graph semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    build.add_argument("source", type=Path)
    build.add_argument("directory", type=Path)
    build.add_argument("--source-manifest-hash", required=True)
    build.add_argument("--profile-hash", required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "build":
            result = build_graph_package(args.source, args.source_manifest_hash,
                profile_hash=args.profile_hash, disclosure=args.disclosure)
            write_package(result, args.directory)
        else:
            result = verify_graph_package(args.directory, args.manifest_hash)
        print(result.manifest_hash)
        return 0
    except (MuseumError, OSError) as exc:
        parser.exit(2, str(exc) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
