"""Reproducible public institutional derivative of a verified recorded package."""
from pathlib import Path

from .canonical import MuseumError, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .exhibition_package import _check_identity_join
from .institutional import CLAIMS, NAMES, SCHEMAS, PROFILE_BYTES, project_institutional, validator
from .institutional_source import InstitutionalOwnerSource
from .package import _package_path, write_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .package_v2 import _assemble, _read_package
from .recorded_projection import replay_source_bytes

MODE = "recorded_institutional_documentation_package"
INPUTS = ("anchor.json", "transcript.json", "deployment-evidence.json")


def build_institutional_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash, profile_hash,
                                owner_inputs, owner_pins, disclosure, documents=None):
    if disclosure != "public": raise MuseumError("institutional explicit public classification required")
    documents = {} if documents is None else documents
    directory = Path(directory).resolve(); original = verify_recorded_package(directory, expected_manifest_hash)
    original_files = dict(original.files); pins = loads(original.manifest, maximum=2097152)["pins"]
    original_source = replay_source_bytes(directory / "dependencies", {name: original_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    if (not isinstance(owner_inputs, dict) or set(owner_inputs) != set(INPUTS) or not isinstance(owner_pins, dict)
        or set(owner_pins) != {"anchorHash", "transcriptHash", "sourceHash"}
        or any(type(v) is not bytes or len(v) > MAX_TRANSCRIPT for v in owner_inputs.values())):
        raise MuseumError("institutional owner input/pin shape")
    if keccak256(owner_inputs["anchor.json"]) != owner_pins["anchorHash"]: raise MuseumError("institutional anchor pin differs")
    source = InstitutionalOwnerSource(owner_inputs["anchor.json"], ReplayTransport(owner_inputs["transcript.json"], owner_pins["transcriptHash"]), provenance="trusted_rpc")
    if keccak256(owner_inputs["deployment-evidence.json"]) != source.a["deploymentEvidenceHash"]:
        raise MuseumError("institutional deployment evidence differs")
    if any(source.a[k] != original_source.anchor[k] for k in ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")):
        raise MuseumError("institutional sources require same original chain/Core/block/qualification")
    projected = project_institutional(source, plan_bytes, source_hash=owner_pins["sourceHash"], plan_hash=plan_hash,
        profile_hash=profile_hash, model=validator(directory / "dependencies"), documents=documents)
    _check_identity_join({"exhibitions/index.json": projected["institutional/index.json"]}, original_files)
    files = {"source/" + name: raw for name, raw in original.files}; files["source/manifest.json"] = original.manifest
    files.update({"owner-records/" + name: raw for name, raw in owner_inputs.items()})
    files.update({"instruments/" + key[2:] + ".bin": raw for key, raw in documents.items()})
    files["owner-records/source-capture.json"] = source.snapshot(); files["inputs/plan.json"] = plan_bytes
    files["definitions/profile.json"] = PROFILE_BYTES
    files.update({"definitions/" + NAMES[k] + ".json": raw for k, raw in SCHEMAS.items()}); files.update(projected)
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "planHash": plan_hash, "profileHash": profile_hash, "ownerPins": owner_pins, "disclosure": disclosure, "claims": CLAIMS})


def verify_institutional_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve(); raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "planHash", "profileHash", "ownerPins", "disclosure", "claims", "files"}
        or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("institutional package manifest differs")
    documents = {}
    for name, content in files.items():
        if name.startswith("instruments/"):
            key = "0x" + name.removeprefix("instruments/").removesuffix(".bin")
            hex_bytes(key, 32); documents[key] = content
    try:
        rebuilt = build_institutional_package(directory / "source", manifest["sourceManifestHash"], files["inputs/plan.json"],
            plan_hash=manifest["planHash"], profile_hash=manifest["profileHash"], owner_pins=manifest["ownerPins"],
            owner_inputs={name: files["owner-records/" + name] for name in INPUTS}, disclosure=manifest["disclosure"], documents=documents)
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("institutional package input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("institutional semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__); commands = p.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    build = commands.add_parser("build")
    for name in ("source", "plan", "owner_inputs", "owner_pins", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "plan-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    build.add_argument("--documents", type=Path); build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    args = p.parse_args()
    def read(path, maximum):
        if path.stat().st_size > maximum: raise MuseumError("institutional input byte bound")
        return path.read_bytes()
    try:
        if args.command == "verify": result = verify_institutional_package(args.directory, args.manifest_hash)
        else:
            documents = {}
            if args.documents:
                index = loads(read(args.documents, 524288), maximum=524288, canonical=True)
                if not isinstance(index, dict) or len(index) > 128: raise MuseumError("institutional document index bound")
                for key, path in index.items():
                    hex_bytes(key, 32); documents[key] = read(_package_path(args.documents.parent.resolve(), path), 1048576)
            result = build_institutional_package(args.source, args.source_manifest_hash, read(args.plan, 524288),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash,
                owner_inputs={name: read(_package_path(args.owner_inputs.resolve(), name), MAX_TRANSCRIPT) for name in INPUTS},
                owner_pins=loads(read(args.owner_pins, 524288), maximum=524288, canonical=True), disclosure=args.disclosure, documents=documents)
            write_package(result, args.directory)
        print(result.manifest_hash)
    except (MuseumError, OSError) as exc: p.exit(2, str(exc) + "\n")


if __name__ == "__main__": main()
