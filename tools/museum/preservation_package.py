"""Offline derivative retaining an exact recorded package plus typed preservation evidence."""
from pathlib import Path

from .canonical import MuseumError, hex_bytes, loads
from .package import _package_path, write_package
from .package_v2 import _assemble, _read_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .premis import PinnedPremis, PROFILE_BYTES as XSD_BYTES, PROFILE_HASH as XSD_HASH
from .preservation_events import (MAX_EVENTS, MAX_OBSERVATION_BYTES, PROFILE_BYTES,
    SCHEMAS, project_recorded_preservation)
from .recorded_projection import replay_source_bytes

MODE = "recorded_account_preservation_resource_package"
CLAIMS = {"networkFetch": False, "historicalPerformanceProven": False, "namedAgentIdentityProven": False,
    "institutionalConformance": False, "registeredExport": False}


def build_preservation_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash, profile_hash,
                         observations, disclosure):
    if disclosure != "public":
        raise MuseumError("preservation package requires explicit public classification of source and observations")
    # This verifier rejects synthetic and derivative source packages. It also
    # authenticates every retained input, dependency, projection and claim.
    directory = Path(directory).resolve()
    original = verify_recorded_package(directory, expected_manifest_hash)
    manifest = loads(original.manifest, maximum=2097152)
    if "premis_plan" not in manifest["pins"]:
        raise MuseumError("preservation package requires an explicit recorded file-only PREMIS plan")
    source_files = dict(original.files)
    pins = manifest["pins"]
    source = replay_source_bytes(directory / "dependencies", {
        name: source_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    result = project_recorded_preservation(source, source_files["inputs/selection.json"], source_files["inputs/plan.json"],
        source_files["inputs/premis-plan.json"], plan_bytes,
        **{key + "_hash": pins[key] for key in ("selection", "plan", "premis_plan", "premis_profile")},
        preservation_plan_hash=plan_hash, preservation_profile_hash=profile_hash,
        premis_schema=PinnedPremis(directory / "dependencies", XSD_BYTES, profile_hash=XSD_HASH), observations=observations)
    files = {"source/" + name: raw for name, raw in original.files}
    files["source/manifest.json"] = original.manifest
    files["inputs/preservation-plan.json"] = plan_bytes
    files["definitions/preservation-profile.json"] = PROFILE_BYTES
    files.update({"definitions/" + name + ".json": raw for name, raw in SCHEMAS.items()})
    for event_id, raw in observations.items():
        hex_bytes(event_id, 32)
        files["observations/" + event_id[2:] + ".bin"] = raw
    files["premis-preservation/report.json"] = result.report
    files["premis-preservation/correspondence.json"] = result.correspondence
    files["premis-preservation/provenance.json"] = result.provenance
    if result.xml is not None: files["premis-preservation/premis.xml"] = result.xml
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "preservationPlanHash": plan_hash, "preservationProfileHash": profile_hash, "disclosure": "public",
        "observationEvents": sorted(observations), "claims": CLAIMS})


def verify_preservation_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "preservationPlanHash", "preservationProfileHash",
            "disclosure", "observationEvents", "claims", "files"}
            or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS
            or not isinstance(manifest["observationEvents"], list) or len(manifest["observationEvents"]) > MAX_EVENTS):
        raise MuseumError("unsupported preservation package manifest")
    ids = manifest["observationEvents"]
    for event_id in ids: hex_bytes(event_id, 32)
    if ids != sorted(set(ids)): raise MuseumError("preservation observation identifiers must be unique and ordered")
    try:
        observations = {event_id: files["observations/" + event_id[2:] + ".bin"] for event_id in ids}
        rebuilt = build_preservation_package(directory / "source", manifest["sourceManifestHash"], files["inputs/preservation-plan.json"],
            plan_hash=manifest["preservationPlanHash"], profile_hash=manifest["preservationProfileHash"],
            observations=observations, disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("preservation package reconstruction input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("preservation package semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    build = commands.add_parser("build")
    build.add_argument("source", type=Path)
    build.add_argument("plan", type=Path)
    build.add_argument("directory", type=Path)
    build.add_argument("--source-manifest-hash", required=True)
    build.add_argument("--plan-hash", required=True)
    build.add_argument("--profile-hash", required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    build.add_argument("--observations", type=Path,
        help="Optional directory containing only EVENT_ID_WITHOUT_0x.bin files; bytes are local public observations.")
    args = parser.parse_args()
    try:
        if args.command == "verify":
            result = verify_preservation_package(args.directory, args.manifest_hash)
        else:
            if args.disclosure != "public": raise MuseumError("restricted preservation export unsupported")
            if args.plan.stat().st_size > 524288: raise MuseumError("preservation plan byte bound")
            observations, total = {}, 0
            if args.observations is not None:
                for path in args.observations.iterdir():
                    event_id = "0x" + path.stem
                    hex_bytes(event_id, 32)
                    if path.suffix != ".bin" or not path.is_file(): raise MuseumError("unknown observation input")
                    checked = _package_path(args.observations.resolve(), path.name)
                    total += checked.stat().st_size
                    if len(observations) >= MAX_EVENTS or total > MAX_OBSERVATION_BYTES:
                        raise MuseumError("observation byte/count bound")
                    observations[event_id] = checked.read_bytes()
            result = build_preservation_package(args.source, args.source_manifest_hash, args.plan.read_bytes(),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash, observations=observations,
                disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash)
        return 0
    except (MuseumError, OSError) as exc:
        parser.exit(2, str(exc) + "\n")


if __name__ == "__main__":
    raise SystemExit(main())
