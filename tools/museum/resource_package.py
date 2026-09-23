"""Offline resource derivative preserving both original independent and Metadata source evidence."""
from pathlib import Path

from .canonical import MuseumError, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .metadata_rights_source import MetadataRightsSource, SCHEMA_BYTES as RIGHTS_SCHEMA, PROFILE_BYTES as RIGHTS_PROFILE
from .package import _package_path, write_package
from .package_v2 import _assemble, _read_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .premis import PinnedPremis, PROFILE_BYTES as XSD_BYTES, PROFILE_HASH as XSD_HASH
from .preservation_resources import PROFILE_BYTES, SCHEMAS, project_resources
from .recorded_projection import replay_source_bytes

MODE = "recorded_preservation_resources_package"
CLAIMS = {"networkFetch": False, "institutionalConformance": False, "registeredExport": False,
    "legalOwnershipProven": False, "currentRightsSelection": False, "independentQuotesAreRightsGrants": False}


def build_resource_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash, profile_hash,
                           rights_inputs=None, rights_pins=None, disclosure):
    if disclosure != "public": raise MuseumError("resource export requires explicit public source classification")
    directory = Path(directory).resolve()
    original = verify_recorded_package(directory, expected_manifest_hash)
    source_files = dict(original.files); pins = loads(original.manifest, maximum=2097152)["pins"]
    source = replay_source_bytes(directory / "dependencies", {name: source_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    if "premis_profile" not in pins:
        raise MuseumError("resource package requires the original pinned PREMIS dependency closure")
    rights_source = None
    if rights_inputs is not None:
        if (not isinstance(rights_inputs, dict) or set(rights_inputs) != {"anchor.json", "transcript.json", "deployment-evidence.json"}
            or not isinstance(rights_pins, dict) or set(rights_pins) != {"anchorHash", "transcriptHash", "sourceHash"}
            or any(type(v) is not bytes or len(v) > MAX_TRANSCRIPT for v in rights_inputs.values())):
            raise MuseumError("resource Metadata rights inputs/pins differ")
        if keccak256(rights_inputs["anchor.json"]) != rights_pins["anchorHash"]:
            raise MuseumError("resource external Metadata anchor mismatch")
        rights_source = MetadataRightsSource(rights_inputs["anchor.json"],
            ReplayTransport(rights_inputs["transcript.json"], rights_pins["transcriptHash"]), provenance="trusted_rpc")
        if keccak256(rights_inputs["deployment-evidence.json"]) != rights_source.a["deploymentEvidenceHash"]:
            raise MuseumError("resource Metadata deployment evidence mismatch")
    elif rights_pins is not None: raise MuseumError("resource missing Metadata rights inputs")
    result = project_resources(source, plan_bytes, plan_hash=plan_hash, profile_hash=profile_hash,
        rights_source=rights_source, rights_source_hash=None if rights_pins is None else rights_pins["sourceHash"],
        premis_schema=PinnedPremis(directory / "dependencies", XSD_BYTES, profile_hash=XSD_HASH))
    files = {"source/" + name: raw for name, raw in original.files}; files["source/manifest.json"] = original.manifest
    files["inputs/resource-plan.json"] = plan_bytes
    files["definitions/resource-profile.json"] = PROFILE_BYTES
    files.update({"definitions/" + name + ".json": raw for name, raw in SCHEMAS.items()})
    files["definitions/STREAM_RIGHTS_V1.json"] = RIGHTS_SCHEMA
    files["definitions/STREAM_RIGHTS_JSON_PROFILE_V1.json"] = RIGHTS_PROFILE
    if rights_inputs is not None:
        files.update({"metadata-rights/" + name: raw for name, raw in rights_inputs.items()})
        files["metadata-rights/source-capture.json"] = rights_source.snapshot()
    files.update({"premis-resources/" + name + ".json": getattr(result, name) for name in ("report", "correspondence", "provenance")})
    if result.xml is not None: files["premis-resources/premis.xml"] = result.xml
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "resourcePlanHash": plan_hash, "resourceProfileHash": profile_hash, "rightsPins": rights_pins,
        "disclosure": "public", "claims": CLAIMS})


def verify_resource_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "resourcePlanHash", "resourceProfileHash", "rightsPins", "disclosure", "claims", "files"}
        or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("resource package manifest differs")
    try:
        rights_inputs = None if manifest["rightsPins"] is None else {name: files["metadata-rights/" + name]
            for name in ("anchor.json", "transcript.json", "deployment-evidence.json")}
        rebuilt = build_resource_package(directory / "source", manifest["sourceManifestHash"], files["inputs/resource-plan.json"],
            plan_hash=manifest["resourcePlanHash"], profile_hash=manifest["resourceProfileHash"], rights_inputs=rights_inputs,
            rights_pins=manifest["rightsPins"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("resource package reconstruction input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("resource package reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    check = commands.add_parser("verify"); check.add_argument("directory", type=Path); check.add_argument("--manifest-hash", required=True)
    build = commands.add_parser("build")
    for name in ("source", "plan", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "plan-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    build.add_argument("--rights-inputs", type=Path); build.add_argument("--rights-pins", type=Path)
    args = parser.parse_args()
    try:
        if args.command == "verify": result = verify_resource_package(args.directory, args.manifest_hash)
        else:
            if args.disclosure != "public": raise MuseumError("restricted resource export unsupported")
            if args.plan.stat().st_size > 524288: raise MuseumError("resource plan bound")
            if (args.rights_inputs is None) != (args.rights_pins is None): raise MuseumError("both Metadata rights inputs and pins required")
            inputs, pins = None, None
            if args.rights_inputs is not None:
                if args.rights_pins.stat().st_size > 524288: raise MuseumError("resource rights pins bound")
                pins = loads(args.rights_pins.read_bytes(), maximum=524288, canonical=True); inputs = {}
                for name in ("anchor.json", "transcript.json", "deployment-evidence.json"):
                    path = _package_path(args.rights_inputs.resolve(), name)
                    if path.stat().st_size > MAX_TRANSCRIPT: raise MuseumError("resource rights input bound")
                    inputs[name] = path.read_bytes()
            result = build_resource_package(args.source, args.source_manifest_hash, args.plan.read_bytes(), plan_hash=args.plan_hash,
                profile_hash=args.profile_hash, rights_inputs=inputs, rights_pins=pins, disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash); return 0
    except (MuseumError, OSError) as exc: parser.exit(2, str(exc) + "\n")


if __name__ == "__main__": raise SystemExit(main())