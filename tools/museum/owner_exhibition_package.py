"""Replayable owner-attributed exhibition packages over exact public source bytes."""
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .exhibition_package import _check_identity_join
from .independent_wire import require
from .owner_exhibitions import (CLAIMS as SOURCE_CLAIMS, NAME, PROFILE_BYTES, PROFILE_HASH,
    SCHEMA_BYTES, OwnerExhibitionSource, project_owner_exhibitions)
from .package import MAX_MANIFEST, _package_path, write_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .package_v2 import _assemble, _read_package
from .preservation_graph import validator
from .recorded_projection import replay_source_bytes

MODE = "recorded_owner_exhibition_package"
INPUTS = ("anchor.json", "transcript.json", "deployment-evidence.json")
CLAIMS = dict(SOURCE_CLAIMS, offlineSourceReplay=True, originalBasePackageRetained=True)
MAX_PLAN = 524288


def _pin(value):
    require(any(hex_bytes(value, 32)), "owner exhibition nonzero external pin required")


def _consistent_sources(recorded, original_files, owner, transcript):
    """A common block label cannot reconcile contradictory retained RPC answers."""
    base_pins = {row["address"]: row["runtimeHash"] for row in recorded.anchor["codePins"]}
    require(all(base_pins[address] == owner.pins[address] for address in base_pins.keys() & owner.pins.keys()),
            "owner exhibition shared runtime pins differ")
    transcripts = [original_files["inputs/" + name] for name in
        ("transcript.json", "publication-transcript.json", "interpretation-transcript.json")]
    seen = {}
    for raw in [*transcripts, transcript]:
        for row in loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)["calls"]:
            key, result = dumps([row["method"], row["params"]]), dumps(row["result"])
            require(key not in seen or seen[key] == result, "owner exhibition cross-source RPC result differs")
            seen[key] = result


def build_owner_exhibition_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash,
                                   profile_hash, owner_inputs, owner_pins, disclosure):
    """Build from the original recorded base and separately pinned owner transcript."""
    require(disclosure == "public", "owner exhibition explicit public disclosure required")
    require(profile_hash == PROFILE_HASH, "owner exhibition external profile differs")
    _pin(expected_manifest_hash); _pin(plan_hash)
    require(type(plan_bytes) is bytes and len(plan_bytes) <= MAX_PLAN
            and keccak256(plan_bytes) == plan_hash, "owner exhibition external plan differs")
    plan = loads(plan_bytes, maximum=MAX_PLAN, canonical=True)
    require(type(plan) is dict and set(plan) == {"version", "sourceHash", "records"}
            and plan["version"] == "1" and type(plan["records"]) is list
            and 0 < len(plan["records"]) <= 64, "owner exhibition closed plan/selection bound")
    require(type(owner_inputs) is dict and set(owner_inputs) == set(INPUTS)
            and all(type(raw) is bytes and 0 < len(raw) <= MAX_TRANSCRIPT for raw in owner_inputs.values()),
            "owner exhibition exact owner input set/byte bound")
    require(type(owner_pins) is dict and set(owner_pins) == {"anchorHash", "transcriptHash", "sourceHash"},
            "owner exhibition external owner pin set")
    for value in owner_pins.values(): _pin(value)
    require(keccak256(owner_inputs["anchor.json"]) == owner_pins["anchorHash"]
            and plan["sourceHash"] == owner_pins["sourceHash"], "owner exhibition original owner pin differs")

    directory = Path(directory).resolve()
    original = verify_recorded_package(directory, expected_manifest_hash)
    original_files = dict(original.files)
    pins = loads(original.manifest, maximum=MAX_MANIFEST, canonical=True)["pins"]
    recorded = replay_source_bytes(directory / "dependencies",
        {name: original_files["inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})
    owner = OwnerExhibitionSource(owner_inputs["anchor.json"],
        ReplayTransport(owner_inputs["transcript.json"], owner_pins["transcriptHash"]), provenance="trusted_rpc")
    require(keccak256(owner_inputs["deployment-evidence.json"]) == owner.a["deploymentEvidenceHash"],
            "owner exhibition deployment evidence differs")
    require(all(owner.a[key] == recorded.anchor[key] for key in
        ("chainId", "core", "blockHash", "blockNumber", "timestamp", "stateRoot", "environment")),
        "owner exhibition sources require same original chain/Core/block/qualification")
    _consistent_sources(recorded, original_files, owner, owner_inputs["transcript.json"])
    projected = project_owner_exhibitions(owner, plan["records"], source_hash=owner_pins["sourceHash"],
        profile_hash=profile_hash, model=validator(directory / "dependencies"))
    # Reuse cannot silently overwrite a selected base declaration with an owner
    # assertion. Any future cross-source identity merge needs its own profile.
    _check_identity_join(projected, original_files)
    files = {"source/" + name: raw for name, raw in original.files}
    files["source/manifest.json"] = original.manifest
    files["inputs/owner-exhibition-plan.json"] = plan_bytes
    files["definitions/owner-exhibition-profile.json"] = PROFILE_BYTES
    files["definitions/" + NAME + ".json"] = SCHEMA_BYTES
    files.update({"owner-records/" + name: raw for name, raw in owner_inputs.items()})
    files["owner-records/source-capture.json"] = owner.snapshot()
    files.update(projected)
    return _assemble(directory, files, {"mode": MODE, "version": "1",
        "sourceManifestHash": original.manifest_hash, "planHash": plan_hash,
        "profileHash": profile_hash, "ownerPins": owner_pins, "disclosure": disclosure, "claims": CLAIMS})


def verify_owner_exhibition_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    require(set(manifest) == {"mode", "version", "sourceManifestHash", "planHash", "profileHash",
        "ownerPins", "disclosure", "claims", "files"} and manifest["mode"] == MODE
        and manifest["version"] == "1" and manifest["claims"] == CLAIMS,
        "owner exhibition closed package manifest differs")
    try:
        rebuilt = build_owner_exhibition_package(directory / "source", manifest["sourceManifestHash"],
            files["inputs/owner-exhibition-plan.json"], plan_hash=manifest["planHash"],
            profile_hash=manifest["profileHash"], owner_inputs={name: files["owner-records/" + name] for name in INPUTS},
            owner_pins=manifest["ownerPins"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("owner exhibition original source input missing") from exc
    require(rebuilt.manifest == raw and dict(rebuilt.files) == files,
            "owner exhibition complete semantic reconstruction differs")
    return rebuilt


def _read(path, maximum):
    require(path.stat().st_size <= maximum, "owner exhibition input byte bound")
    raw = path.read_bytes()
    require(len(raw) <= maximum, "owner exhibition input grew beyond byte bound")
    return raw


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    build = commands.add_parser("build")
    for name in ("source", "plan", "owner_inputs", "owner_pins", "directory"):
        build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "plan-hash", "profile-hash"):
        build.add_argument("--" + name, required=True)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    try:
        if args.command == "verify":
            result = verify_owner_exhibition_package(args.directory, args.manifest_hash)
        else:
            # Refuse restricted export before opening any supplied source files.
            require(args.disclosure == "public", "owner exhibition explicit public disclosure required")
            result = build_owner_exhibition_package(args.source, args.source_manifest_hash, _read(args.plan, MAX_PLAN),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash,
                owner_inputs={name: _read(_package_path(args.owner_inputs.resolve(), name), MAX_TRANSCRIPT) for name in INPUTS},
                owner_pins=loads(_read(args.owner_pins, MAX_PLAN), maximum=MAX_PLAN, canonical=True),
                disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash)
    except (MuseumError, OSError, KeyError, TypeError, ValueError) as exc:
        parser.exit(2, str(exc) + "\n")


if __name__ == "__main__":
    main()
