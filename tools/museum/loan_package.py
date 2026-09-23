"""Offline loan dossier derivative retaining original account and owner-record evidence."""
from pathlib import Path
from .canonical import MuseumError, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport
from .exhibition_package import _check_identity_join
from .loans import CLAIMS, NAME, PROFILE_BYTES, SCHEMA_BYTES, project_loans, validator
from .owner_record_source import OwnerRecordSource
from .package import _package_path, write_package
from .package_recorded import INPUT_FILES, verify_recorded_package
from .package_v2 import _assemble, _read_package
from .recorded_projection import replay_source_bytes

MODE="recorded_owner_loan_dossier_package"
INPUTS=("anchor.json","transcript.json","deployment-evidence.json")


def build_loan_package(directory,expected_manifest_hash,plan_bytes,*,plan_hash,profile_hash,owner_inputs=None,owner_pins=None,disclosure):
    if disclosure!="public":raise MuseumError("loan explicit public classification required")
    directory=Path(directory).resolve();original=verify_recorded_package(directory,expected_manifest_hash)
    original_files=dict(original.files);pins=loads(original.manifest,maximum=2097152)["pins"]
    original_source=replay_source_bytes(directory/"dependencies",{name:original_files["inputs/"+name] for name in INPUT_FILES},
        **{key+"_hash":pins[key] for key in ("source","publication","interpretation","profile")})
    source=None
    if owner_inputs is not None:
        if (not isinstance(owner_inputs,dict) or set(owner_inputs)!=set(INPUTS) or not isinstance(owner_pins,dict)
            or set(owner_pins)!={"anchorHash","transcriptHash","sourceHash"}
            or any(type(v) is not bytes or len(v)>MAX_TRANSCRIPT for v in owner_inputs.values())):
            raise MuseumError("loan owner input/pin shape")
        if keccak256(owner_inputs["anchor.json"])!=owner_pins["anchorHash"]:raise MuseumError("loan external owner anchor differs")
        source=OwnerRecordSource(owner_inputs["anchor.json"],ReplayTransport(owner_inputs["transcript.json"],owner_pins["transcriptHash"]),provenance="trusted_rpc")
        if keccak256(owner_inputs["deployment-evidence.json"])!=source.a["deploymentEvidenceHash"]:raise MuseumError("loan owner deployment evidence differs")
        if any(source.a[k]!=original_source.anchor[k] for k in ("chainId","core","blockHash","blockNumber","timestamp","stateRoot","environment")):
            raise MuseumError("loan original sources require same chain/Core/block/qualification")
    elif owner_pins is not None:raise MuseumError("loan owner inputs missing")
    projected=project_loans(source,plan_bytes,plan_hash=plan_hash,profile_hash=profile_hash,
        source_hash=None if owner_pins is None else owner_pins["sourceHash"],model=validator(directory/"dependencies"))
    # Reuse the already verified selected original index; no matching-by-name.
    _check_identity_join({"exhibitions/index.json":projected["loans/index.json"]},original_files)
    files={"source/"+name:raw for name,raw in original.files};files["source/manifest.json"]=original.manifest
    files["inputs/loan-plan.json"]=plan_bytes;files["definitions/loan-profile.json"]=PROFILE_BYTES
    files["definitions/"+NAME+".json"]=SCHEMA_BYTES
    if source is not None:
        files.update({"owner-records/"+name:raw for name,raw in owner_inputs.items()})
        files["owner-records/source-capture.json"]=source.snapshot()
    files.update(projected)
    return _assemble(directory,files,{"mode":MODE,"version":"1","sourceManifestHash":original.manifest_hash,
        "planHash":plan_hash,"profileHash":profile_hash,"ownerPins":owner_pins,"disclosure":disclosure,"claims":CLAIMS})


def verify_loan_package(directory,expected_manifest_hash):
    directory=Path(directory).resolve();raw,manifest,files=_read_package(directory,expected_manifest_hash)
    if (set(manifest)!={"mode","version","sourceManifestHash","planHash","profileHash","ownerPins","disclosure","claims","files"}
        or manifest["mode"]!=MODE or manifest["version"]!="1" or manifest["claims"]!=CLAIMS):raise MuseumError("loan package manifest differs")
    try:
        owner_inputs=None if manifest["ownerPins"] is None else {name:files["owner-records/"+name] for name in INPUTS}
        rebuilt=build_loan_package(directory/"source",manifest["sourceManifestHash"],files["inputs/loan-plan.json"],
            plan_hash=manifest["planHash"],profile_hash=manifest["profileHash"],owner_inputs=owner_inputs,owner_pins=manifest["ownerPins"],disclosure=manifest["disclosure"])
    except (KeyError,FileNotFoundError) as exc:raise MuseumError("loan package source missing") from exc
    if rebuilt.manifest!=raw or dict(rebuilt.files)!=files:raise MuseumError("loan package semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    p=argparse.ArgumentParser(description=__doc__);commands=p.add_subparsers(dest="command",required=True)
    verify=commands.add_parser("verify");verify.add_argument("directory",type=Path);verify.add_argument("--manifest-hash",required=True)
    build=commands.add_parser("build")
    for name in ("source","plan","directory"):build.add_argument(name,type=Path)
    for name in ("source-manifest-hash","plan-hash","profile-hash"):build.add_argument("--"+name,required=True)
    build.add_argument("--owner-inputs",type=Path);build.add_argument("--owner-pins",type=Path)
    build.add_argument("--disclosure",choices=("public","restricted"),required=True);args=p.parse_args()
    try:
        if args.command=="verify":result=verify_loan_package(args.directory,args.manifest_hash)
        else:
            if args.plan.stat().st_size>524288:raise MuseumError("loan plan byte bound")
            if (args.owner_inputs is None)!=(args.owner_pins is None):raise MuseumError("loan both owner inputs and pins required")
            inputs,pins=None,None
            if args.owner_inputs is not None:
                if args.owner_pins.stat().st_size>524288:raise MuseumError("loan owner pins bound")
                pins=loads(args.owner_pins.read_bytes(),maximum=524288,canonical=True);inputs={}
                for name in INPUTS:
                    path=_package_path(args.owner_inputs.resolve(),name)
                    if path.stat().st_size>MAX_TRANSCRIPT:raise MuseumError("loan owner input bound")
                    inputs[name]=path.read_bytes()
            result=build_loan_package(args.source,args.source_manifest_hash,args.plan.read_bytes(),plan_hash=args.plan_hash,
                profile_hash=args.profile_hash,owner_inputs=inputs,owner_pins=pins,disclosure=args.disclosure)
            write_package(result,args.directory)
        print(result.manifest_hash);return 0
    except (MuseumError,OSError) as exc:p.exit(2,str(exc)+"\n")


if __name__=="__main__":raise SystemExit(main())
