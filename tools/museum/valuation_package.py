"""Offline typed valuation derivative of a literally retained verified loan dossier."""
from pathlib import Path
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .loan_package import verify_loan_package
from .owner_record_source import OwnerRecordSource
from .package import _package_path, write_package
from .package_v2 import _assemble, _read_package
from .valuation_history import ValuationHistory
from .valuations import CLAIMS, NAME, PROFILE_BYTES, SCHEMA_BYTES, project_valuations, validator

MODE = "recorded_owner_valuation_package"
INPUTS = ("hints.json", "transcript.json")


def build_valuation_package(directory, expected_manifest_hash, plan_bytes, *, plan_hash, profile_hash,
        history_inputs=None, history_pins=None, disclosure):
    if disclosure != "public": raise MuseumError("valuation explicit public classification required")
    directory = Path(directory).resolve(); original = verify_loan_package(directory, expected_manifest_hash)
    original_files = dict(original.files); original_manifest = loads(original.manifest, maximum=2097152)
    pins = original_manifest["ownerPins"]; source = None
    if pins is not None:
        source = OwnerRecordSource(original_files["owner-records/anchor.json"],
            ReplayTransport(original_files["owner-records/transcript.json"], pins["transcriptHash"]), provenance="trusted_rpc")
        if keccak256(source.snapshot()) != pins["sourceHash"]: raise MuseumError("valuation original source pin differs")
    history = None
    if history_inputs is not None:
        if (source is None or not isinstance(history_inputs, dict) or set(history_inputs) != set(INPUTS)
            or any(type(raw) is not bytes or len(raw) > MAX_TRANSCRIPT for raw in history_inputs.values())
            or not isinstance(history_pins, dict) or set(history_pins) != {"hintsHash", "transcriptHash", "snapshotHash"}):
            raise MuseumError("valuation history inputs/pins shape")
        history = ValuationHistory(source, history_inputs["hints.json"],
            ReplayTransport(history_inputs["transcript.json"], history_pins["transcriptHash"]),
            hints_hash=history_pins["hintsHash"], provenance="trusted_rpc")
        if keccak256(dumps(history.capture())) != history_pins["snapshotHash"]:
            raise MuseumError("valuation history snapshot pin differs")
    elif history_pins is not None: raise MuseumError("valuation history inputs missing")
    projected = project_valuations(source, plan_bytes, plan_hash=plan_hash, profile_hash=profile_hash,
        source_hash=None if pins is None else pins["sourceHash"], model=validator(directory / "source/dependencies"), history=history)
    plan = loads(plan_bytes, maximum=524288, canonical=True)
    old_plan = loads(original_files["inputs/loan-plan.json"], maximum=524288, canonical=True)
    if not set(plan["loans"]) <= set(old_plan["records"]): raise MuseumError("valuation loan selection not retained by original package")
    new_ids = {r["id"] for r in loads(projected["valuations/index.json"], maximum=2097152)["resources"]}
    account_ids = {r["id"] for r in loads(original_files["source/linked-art/entity-index.json"], maximum=2097152)}
    if new_ids & account_ids: raise MuseumError("valuation source identity reuse requires explicit lineage")
    # Shared loan/valuation parties require the entire same explicit declaration,
    # never matching names, wallets or graph labels alone.
    old_ids = {r["id"] for r in loads(original_files["loans/index.json"], maximum=2097152)["resources"]}
    old_parties = {}; new_parties = {}
    for dossier in loads(original_files["loans/dossiers.json"], maximum=MAX_TRANSCRIPT):
        for role in ("lender", "borrower"):
            p = dossier["loan"][role]; old_parties[p["entityId"]] = dumps(p)
    for dossier in loads(projected["valuations/dossiers.json"], maximum=MAX_TRANSCRIPT):
        for role in ("issuer", "appraiser"):
            p = dossier["valuation"][role]
            if p is not None: new_parties[p["entityId"]] = dumps(p)
    if any(i not in old_parties or new_parties.get(i) != old_parties[i] for i in new_ids & old_ids):
        raise MuseumError("valuation conflicting loan entity declaration")
    files = {"source/" + name: raw for name, raw in original.files}; files["source/manifest.json"] = original.manifest
    files.update(projected); files["inputs/valuation-plan.json"] = plan_bytes
    files["definitions/valuation-profile.json"] = PROFILE_BYTES; files["definitions/" + NAME + ".json"] = SCHEMA_BYTES
    if history is not None:
        files.update({"history/" + name: raw for name, raw in history_inputs.items()})
        files["history/source-capture.json"] = dumps(history.capture())
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "planHash": plan_hash, "profileHash": profile_hash, "historyPins": history_pins, "disclosure": disclosure, "claims": CLAIMS})


def verify_valuation_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve(); raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (set(manifest) != {"mode", "version", "sourceManifestHash", "planHash", "profileHash", "historyPins", "disclosure", "claims", "files"}
        or manifest["mode"] != MODE or manifest["version"] != "1" or manifest["claims"] != CLAIMS):
        raise MuseumError("valuation package manifest differs")
    try:
        history = None if manifest["historyPins"] is None else {name: files["history/" + name] for name in INPUTS}
        rebuilt = build_valuation_package(directory / "source", manifest["sourceManifestHash"], files["inputs/valuation-plan.json"],
            plan_hash=manifest["planHash"], profile_hash=manifest["profileHash"], history_inputs=history,
            history_pins=manifest["historyPins"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc: raise MuseumError("valuation original source missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files: raise MuseumError("valuation semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    p = argparse.ArgumentParser(description=__doc__); sub = p.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    build = sub.add_parser("build")
    for name in ("source", "plan", "directory"): build.add_argument(name, type=Path)
    for name in ("source-manifest-hash", "plan-hash", "profile-hash"): build.add_argument("--" + name, required=True)
    build.add_argument("--history-inputs", type=Path); build.add_argument("--history-pins", type=Path)
    build.add_argument("--disclosure", choices=("public", "restricted"), required=True); args = p.parse_args()
    try:
        if args.command == "verify": result = verify_valuation_package(args.directory, args.manifest_hash)
        else:
            if args.plan.stat().st_size > 524288: raise MuseumError("valuation plan bound")
            if (args.history_inputs is None) != (args.history_pins is None): raise MuseumError("valuation both history inputs and pins required")
            inputs, pins = None, None
            if args.history_inputs is not None:
                if args.history_pins.stat().st_size > 524288: raise MuseumError("valuation history pins bound")
                pins = loads(args.history_pins.read_bytes(), maximum=524288, canonical=True); inputs = {}
                for name in INPUTS:
                    path = _package_path(args.history_inputs.resolve(), name)
                    if path.stat().st_size > MAX_TRANSCRIPT: raise MuseumError("valuation history input bound")
                    inputs[name] = path.read_bytes()
            result = build_valuation_package(args.source, args.source_manifest_hash, args.plan.read_bytes(),
                plan_hash=args.plan_hash, profile_hash=args.profile_hash, history_inputs=inputs, history_pins=pins, disclosure=args.disclosure)
            write_package(result, args.directory)
        print(result.manifest_hash); return 0
    except (MuseumError, OSError) as exc: p.exit(2, str(exc) + "\n")


if __name__ == "__main__": raise SystemExit(main())
