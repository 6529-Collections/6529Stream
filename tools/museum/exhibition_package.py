"""Offline derivative preserving a verified recorded package and selected exhibition records."""
from pathlib import Path

from .canonical import MuseumError, loads
from .exhibitions import CLAIMS, NAME, PROFILE_BYTES, PROFILE_HASH, SCHEMA_BYTES, project_recorded_exhibitions, validator
from .package import write_package
from .package_v2 import _assemble, _read_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .recorded_projection import replay_source_bytes

MODE = "recorded_independent_exhibition_package"


def build_exhibition_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash, profile_hash, disclosure):
    if disclosure != "public": raise MuseumError("exhibition requires explicit public classification")
    if profile_hash != PROFILE_HASH: raise MuseumError("exhibition profile hash mismatch")
    directory = Path(directory).resolve()
    original = verify_recorded_package(directory, expected_manifest_hash)
    original_files = dict(original.files)
    pins = loads(original.manifest, maximum=2097152)["pins"]
    source = replay_source_bytes(directory / "dependencies", {key: original_files["inputs/" + key] for key in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    files = {"source/" + name: raw for name, raw in original.files}
    files["source/manifest.json"] = original.manifest
    files["inputs/exhibition-plan.json"] = plan_bytes
    files["definitions/exhibition-profile.json"] = PROFILE_BYTES
    files["definitions/" + NAME + ".json"] = SCHEMA_BYTES
    projected = project_recorded_exhibitions(source, plan_bytes, plan_hash=plan_hash, profile_hash=profile_hash,
        linked_art=validator(directory / "dependencies"))
    _check_identity_join(projected, original_files)
    files.update(projected)
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "planHash": plan_hash, "profileHash": profile_hash, "disclosure": disclosure, "claims": CLAIMS})


def _check_identity_join(projected, original_files):
    # The already verified selected source index is authoritative for this
    # package view. Unselected hostile declarations are not consulted.
    original_ids = {r["id"] for r in loads(original_files["linked-art/entity-index.json"], maximum=2097152)}
    next_ids = {r["id"] for r in loads(projected["exhibitions/index.json"], maximum=2097152)["resources"]}
    if original_ids & next_ids: raise MuseumError("exhibition selected source identity reuse requires an explicit lineage profile")


def verify_exhibition_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "planHash", "profileHash", "disclosure", "claims", "files"}
            or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("unsupported exhibition package manifest")
    try:
        rebuilt = build_exhibition_package(directory / "source", manifest["sourceManifestHash"], files["inputs/exhibition-plan.json"],
            plan_hash=manifest["planHash"], profile_hash=manifest["profileHash"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("exhibition package source missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("exhibition semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    build.add_argument("source", type=Path); build.add_argument("plan", type=Path); build.add_argument("directory", type=Path)
    build.add_argument("--source-manifest-hash", required=True); build.add_argument("--plan-hash", required=True)
    build.add_argument("--profile-hash", required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    verify = commands.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify": result = verify_exhibition_package(args.directory, args.manifest_hash)
        else:
            if args.plan.stat().st_size > 524288: raise MuseumError("exhibition plan byte bound")
            result = build_exhibition_package(args.source, args.source_manifest_hash, args.plan.read_bytes(),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash, disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash)
        return 0
    except (MuseumError, OSError) as exc: parser.exit(2, str(exc) + "\n")


if __name__ == "__main__": raise SystemExit(main())
