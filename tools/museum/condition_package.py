"""Offline condition derivative retaining the complete original source evidence."""
from pathlib import Path

from .canonical import MuseumError, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .condition import (CLAIMS as BASE_CLAIMS, PROFILE_BYTES, PROFILE_HASH, SCHEMAS,
    project_independent_conditions, project_owner_conditions)
from .exhibition_package import _check_identity_join
from .owner_record_source import OwnerRecordSource
from .package import _package_path, write_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .package_v2 import _assemble, _read_package
from .preservation_graph import validator
from .recorded_projection import replay_source_bytes

MODE = "recorded_condition_conservation_package"
INPUTS = ("anchor.json", "transcript.json", "deployment-evidence.json")
CLAIMS = dict(BASE_CLAIMS, actualSourceAuthenticated=True)


def build_condition_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash,
                            profile_hash, disclosure, owner_inputs=None, owner_pins=None):
    if disclosure != "public": raise MuseumError("condition explicit public classification required")
    if profile_hash != PROFILE_HASH: raise MuseumError("condition external profile differs")
    if keccak256(plan_bytes) != plan_hash: raise MuseumError("condition external plan differs")
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    if (not isinstance(plan, dict) or set(plan) != {"version", "sourceKind", "sourceHash", "records"}
        or plan["version"] != "1" or plan["sourceKind"] not in ("owner_records", "independent_records")
        or not isinstance(plan["records"], list) or not 0 < len(plan["records"]) <= 64):
        raise MuseumError("condition plan shape/selection bound")
    directory = Path(directory).resolve()
    original = verify_recorded_package(directory, expected_manifest_hash)
    original_files = dict(original.files); pins = loads(original.manifest, maximum=2097152)["pins"]
    recorded = replay_source_bytes(directory / "dependencies",
        {name: original_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    model = validator(directory / "dependencies")
    owner = None
    if plan["sourceKind"] == "owner_records":
        if (not isinstance(owner_inputs, dict) or set(owner_inputs) != set(INPUTS)
            or not isinstance(owner_pins, dict) or set(owner_pins) != {"anchorHash", "transcriptHash", "sourceHash"}
            or any(type(raw) is not bytes or len(raw) > MAX_TRANSCRIPT for raw in owner_inputs.values())):
            raise MuseumError("condition owner input/pin shape")
        if keccak256(owner_inputs["anchor.json"]) != owner_pins["anchorHash"] or plan["sourceHash"] != owner_pins["sourceHash"]:
            raise MuseumError("condition original owner pin differs")
        owner = OwnerRecordSource(owner_inputs["anchor.json"],
            ReplayTransport(owner_inputs["transcript.json"], owner_pins["transcriptHash"]), provenance="trusted_rpc")
        if keccak256(owner_inputs["deployment-evidence.json"]) != owner.a["deploymentEvidenceHash"]:
            raise MuseumError("condition owner deployment evidence differs")
        if any(owner.a[k] != recorded.anchor[k] for k in ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")):
            raise MuseumError("condition sources require same original chain/Core/block/qualification")
        projected = project_owner_conditions(owner, plan["records"], source_hash=plan["sourceHash"], profile_hash=profile_hash, model=model)
    else:
        if owner_inputs is not None or owner_pins is not None: raise MuseumError("condition independent plan cannot retain owner inputs")
        projected = project_independent_conditions(recorded, plan["records"], source_hash=plan["sourceHash"], profile_hash=profile_hash, model=model)
    _check_identity_join({"exhibitions/index.json": projected["condition/index.json"]}, original_files)
    files = {"source/" + name: raw for name, raw in original.files}
    files["source/manifest.json"] = original.manifest
    files["inputs/condition-plan.json"] = plan_bytes
    files["definitions/condition-profile.json"] = PROFILE_BYTES
    files.update({"definitions/" + name + ".json": raw for name, raw in SCHEMAS.items()})
    if owner is not None:
        files.update({"owner-records/" + name: raw for name, raw in owner_inputs.items()})
        files["owner-records/source-capture.json"] = owner.snapshot()
    files.update(projected)
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "planHash": plan_hash, "profileHash": profile_hash, "ownerPins": owner_pins, "disclosure": disclosure, "claims": CLAIMS})


def verify_condition_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve(); raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "planHash", "profileHash", "ownerPins", "disclosure", "claims", "files"}
        or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("condition package manifest differs")
    try:
        owner_inputs = None if manifest["ownerPins"] is None else {name: files["owner-records/" + name] for name in INPUTS}
        rebuilt = build_condition_package(directory / "source", manifest["sourceManifestHash"], files["inputs/condition-plan.json"],
            plan_hash=manifest["planHash"], profile_hash=manifest["profileHash"], disclosure=manifest["disclosure"],
            owner_inputs=owner_inputs, owner_pins=manifest["ownerPins"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("condition package input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("condition package semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__); sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    build = sub.add_parser("build")
    for name in ("source", "plan", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "plan-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    build.add_argument("--owner-inputs", type=Path); build.add_argument("--owner-pins", type=Path)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    args = parser.parse_args()
    def read(path, limit):
        if path.stat().st_size > limit: raise MuseumError("condition input byte bound")
        return path.read_bytes()
    try:
        if args.command == "verify": result = verify_condition_package(args.directory, args.manifest_hash)
        else:
            if (args.owner_inputs is None) != (args.owner_pins is None): raise MuseumError("condition both owner inputs and pins required")
            owner_inputs = None if args.owner_inputs is None else {name: read(_package_path(args.owner_inputs.resolve(), name), MAX_TRANSCRIPT) for name in INPUTS}
            owner_pins = None if args.owner_pins is None else loads(read(args.owner_pins, 524288), maximum=524288, canonical=True)
            result = build_condition_package(args.source, args.source_manifest_hash, read(args.plan, 524288),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash, disclosure=args.disclosure,
                owner_inputs=owner_inputs, owner_pins=owner_pins)
            write_package(result, args.directory)
        print(result.manifest_hash)
    except (MuseumError, OSError) as exc: parser.exit(2, str(exc) + "\n")


if __name__ == "__main__": main()
