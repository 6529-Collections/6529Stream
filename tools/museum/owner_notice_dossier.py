"""Standalone source-preserving owner notice dossier with closed offline replay.

No previous dossier/profile bytes are rewritten. This supplementary component
projects attributed statements, never institutional receipt or recovery authority.
"""
import argparse
import os
from pathlib import Path

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree, write_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport, RpcTransport
from .independent_catalog_source import IndependentCatalogSource
from .independent_wire import require
from .owner_catalog_source import OwnerCatalogSource
from .owner_notice_semantics import (CLAIMS, PROFILE_BYTES, PROFILE_HASH, QUALIFICATION,
    OwnerNoticeSemanticSource, consistent_reads)
from .ownership_source import OwnershipSource
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator

PROFILE = "STREAM_MUSEUM_OWNER_NOTICE_DOSSIER_V1"
RULE = "urn:6529stream:museum:owner-notice:v1:"
DEFAULT_MODEL_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


def leaves(value, path=""):
    if isinstance(value, dict) and value:
        for key, item in value.items():
            yield from leaves(item, path + "/" + key.replace("~", "~0").replace("/", "~1"))
    elif isinstance(value, list) and value:
        for index, item in enumerate(value):
            yield from leaves(item, path + "/" + str(index))
    else:
        yield path, value


def _source_files(source, prefix):
    snapshot = source.snapshot()
    transcript = source.transcript() if hasattr(source, "transcript") else source.reader.transcript()
    return {prefix + "/anchor.json": source.anchor_bytes, prefix + "/snapshot.json": snapshot,
        prefix + "/transcript.json": transcript}


def render(snapshot, *, model_root=DEFAULT_MODEL_ROOT):
    """Render source-checked statements; every original field remains in the sidecar."""
    value = loads(snapshot, maximum=MAX_TRANSCRIPT, canonical=True)
    model = validator(model_root)
    files, resources, provenance, coverage = {}, [], [], []
    for row in (*value["ownerStatements"], *value["independentStatements"]):
        selector = row["source"]
        if row["status"] != "supported":
            continue
        identifier = RULE + selector["chainId"] + ":" + selector["host"] + ":" + selector["recordHash"]
        label = ("Owner-authored " if row["authority"]["carrier"] == "historical_token_owner"
            else "Independent attestor ") + ("steward designation" if "predecessor" in row["value"] else "recovery response")
        resource = {"@context": CONTEXT, "id": identifier, "type": "LinguisticObject", "_label": label,
            "content": hex_bytes(row["payloadHex"]).decode("utf-8"),
            "classified_as": [{"id": RULE + row["family"], "type": "Type", "_label": label}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
        raw = dumps(resource); expanded = model.validate_and_expand(raw)
        key = keccak256(identifier.encode("utf-8"))[2:]
        path = "graph/resources/" + key + ".json"
        require(path not in files, "owner notice duplicate projection identity")
        files[path] = raw; files["graph/expanded/" + key + ".json"] = expanded.expanded_bytes
        resources.append({"id": identifier, "type": "LinguisticObject", "path": path, "source": selector})
        provenance.extend({"entity": identifier, "path": pointer, "value": item, "source": selector,
            "authority": row["authority"], "rule": RULE + "original-statement",
            "sourcePath": "/payload", "qualification": QUALIFICATION}
            for pointer, item in leaves(resource))
        coverage.extend({"source": selector, "sourcePath": pointer, "value": item,
            "disposition": "retained_original_statement"} for pointer, item in leaves(row["value"]))
    files.update({"graph/index.json": dumps({"profile": PROFILE, "validationPolicyHash": VALIDATION_HASH,
            "resources": resources, "claims": CLAIMS}),
        "graph/provenance.json": dumps(provenance), "graph/source-coverage.json": dumps(coverage)})
    return files


def build_files(source, *, notices=None, model_root=DEFAULT_MODEL_ROOT):
    require(type(source) is OwnerNoticeSemanticSource, "concrete owner notice semantic source required")
    snapshot = source.snapshot(); value = loads(snapshot, maximum=MAX_TRANSCRIPT, canonical=True)
    files = _source_files(source.catalogue, "sources/owner")
    files.update({"semantics/snapshot.json": snapshot, "semantics/transcript.json": source.transcript(),
        "semantics/profile.json": PROFILE_BYTES})
    if source.ownership is not None:
        files.update(_source_files(source.ownership, "sources/ownership"))
    for index, independent in enumerate(source.independents):
        files.update(_source_files(independent, "sources/independent-" + str(index)))
    evidence = None
    if notices is not None:
        from .owner_notice_evidence import OwnerNoticeEvidenceSource, PROFILE_BYTES as NOTICE_PROFILE_BYTES
        require(type(notices) is OwnerNoticeEvidenceSource and notices.owner_catalog is source.catalogue,
            "concrete notice evidence must use the same original owner catalogue")
        evidence_raw = notices.snapshot(); evidence = loads(evidence_raw, maximum=MAX_TRANSCRIPT, canonical=True)
        files.update({"notices/snapshot.json": evidence_raw, "notices/transcript.json": notices.transcript(),
            "notices/profile.json": NOTICE_PROFILE_BYTES})
    transcripts = [raw for path, raw in files.items() if path.endswith("/transcript.json")]
    consistent_reads(transcripts)
    files.update(render(snapshot, model_root=model_root))
    statements = [*value["ownerStatements"], *value["independentStatements"]]
    files["dossier.json"] = dumps({"profile": PROFILE, "version": "1", "sourceState": value["sourceState"],
        "semanticProfileHash": PROFILE_HASH, "subjectId": value["subjectId"],
        "ownerStatements": value["ownerStatements"], "independentStatements": value["independentStatements"],
        "designationHeads": value["designationHeads"], "currentDesignation": value["currentDesignation"],
        "noticeActionEvidence": {"status": "captured" if evidence is not None else "not_captured", "original": evidence},
        "dispositions": [{"source": row["source"], "status": row["status"], "reasonCode": row["reasonCode"]}
            for row in statements], "claims": CLAIMS, "qualification": QUALIFICATION})
    files["report.json"] = dumps({"profile": PROFILE, "version": "1", "status": "supplementary_partial_dossier",
        "sourceState": value["sourceState"], "mode": value["mode"],
        "ownerStatementCount": str(len(value["ownerStatements"])),
        "independentStatementCount": str(len(value["independentStatements"])),
        "supportedStatementCount": str(sum(row["status"] == "supported" for row in statements)),
        "unsupportedStatementCount": str(sum(row["status"] != "supported" for row in statements)),
        "noticeActionEvidence": "captured" if evidence is not None else "not_captured",
        "originalOwnerCatalogueHash": value["ownerCatalogueHash"],
        "claims": CLAIMS, "qualification": QUALIFICATION})
    require(len(files) + 1 <= MAX_FILES and sum(map(len, files.values())) <= MAX_BYTES, "owner notice dossier bounds")
    manifest = {"profile": PROFILE, "version": "1", "semanticProfileHash": PROFILE_HASH,
        "validationPolicyHash": VALIDATION_HASH, "provenance": source.provenance,
        "components": {"ownership": source.ownership is not None, "independentCount": str(len(source.independents)),
            "notices": notices is not None},
        "files": [{"path": path, "bytes": str(len(raw)), "hash": keccak256(raw)} for path, raw in sorted(files.items())],
        "claims": CLAIMS}
    raw = dumps(manifest); require(len(raw) <= MAX_MANIFEST, "owner notice manifest bound")
    files["manifest.json"] = raw
    require(sum(map(len, files.values())) <= MAX_BYTES, "owner notice dossier aggregate bound")
    return files


def _replay_source(files, prefix, kind, provenance):
    raw = files[prefix + "/transcript.json"]
    source = kind(files[prefix + "/anchor.json"], ReplayTransport(raw, keccak256(raw)), provenance=provenance)
    require(source.snapshot() == files[prefix + "/snapshot.json"], "owner notice original source replay differs")
    return source


def verify_files(files, manifest_hash, *, model_root=DEFAULT_MODEL_ROOT):
    """Replay original sources and rebuild every derived byte; no socket is needed."""
    require(type(files) is dict and "manifest.json" in files and len(files) <= MAX_FILES
        and all(type(raw) is bytes for raw in files.values()) and sum(map(len, files.values())) <= MAX_BYTES,
        "owner notice dossier input shape/bounds")
    raw = files["manifest.json"]
    require(keccak256(raw) == manifest_hash, "owner notice external manifest commitment differs")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"profile", "version", "semanticProfileHash", "validationPolicyHash", "provenance", "components", "files", "claims"}
        and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["semanticProfileHash"] == PROFILE_HASH and manifest["validationPolicyHash"] == VALIDATION_HASH
        and manifest["provenance"] in ("synthetic_fixture", "trusted_rpc") and manifest["claims"] == CLAIMS,
        "owner notice dossier manifest shape/profile")
    components = manifest["components"]
    require(type(components) is dict and set(components) == {"ownership", "independentCount", "notices"}
        and type(components["ownership"]) is bool and type(components["notices"]) is bool
        and components["independentCount"] in tuple(str(i) for i in range(9)), "owner notice component shape/bound")
    require(type(manifest["files"]) is list and len(manifest["files"]) == len(files) - 1, "owner notice file inventory differs")
    expected = {"manifest.json"}
    for row in manifest["files"]:
        require(type(row) is dict and set(row) == {"path", "bytes", "hash"} and type(row["path"]) is str and row["path"] not in expected
            and row["path"] in files, "owner notice duplicate/missing file")
        expected.add(row["path"]); payload = files[row["path"]]
        require(row["bytes"] == str(len(payload)) and row["hash"] == keccak256(payload), "owner notice packaged bytes differ")
    require(expected == set(files), "owner notice undeclared files")
    prefixes = ["sources/owner"] + (["sources/ownership"] if components["ownership"] else [])
    prefixes += ["sources/independent-" + str(index) for index in range(int(components["independentCount"]))]
    required = {prefix + "/" + name + ".json" for prefix in prefixes for name in ("anchor", "snapshot", "transcript")}
    required |= {"semantics/snapshot.json", "semantics/transcript.json", "semantics/profile.json"}
    if components["notices"]:
        required |= {"notices/snapshot.json", "notices/transcript.json", "notices/profile.json"}
    require(required <= files.keys(), "owner notice component source files missing")
    provenance = manifest["provenance"]
    catalogue = _replay_source(files, "sources/owner", OwnerCatalogSource, provenance)
    ownership = _replay_source(files, "sources/ownership", OwnershipSource, provenance) if components["ownership"] else None
    independents = [_replay_source(files, "sources/independent-" + str(index), IndependentCatalogSource, provenance)
        for index in range(int(components["independentCount"]))]
    transcript = files["semantics/transcript.json"]
    source = OwnerNoticeSemanticSource(catalogue, ReplayTransport(transcript, keccak256(transcript)),
        ownership=ownership, independents=independents)
    require(source.snapshot() == files["semantics/snapshot.json"], "owner notice semantic replay differs")
    notices = None
    if components["notices"]:
        from .owner_notice_evidence import OwnerNoticeEvidenceSource
        transcript = files["notices/transcript.json"]
        notices = OwnerNoticeEvidenceSource(catalogue, ReplayTransport(transcript, keccak256(transcript)),
            provenance=catalogue.provenance)
        require(notices.snapshot() == files["notices/snapshot.json"], "owner notice action replay differs")
    rebuilt = build_files(source, notices=notices, model_root=model_root)
    require(rebuilt == files, "owner notice derived files do not reconstruct exactly")
    return loads(files["report.json"], maximum=MAX_MANIFEST, canonical=True)


def write(source, destination, *, notices=None, model_root=DEFAULT_MODEL_ROOT):
    files = build_files(source, notices=notices, model_root=model_root)
    write_tree(files, destination)
    return {"manifestHash": keccak256(files["manifest.json"]), "files": str(len(files)), "claims": CLAIMS}


def _input_source(row, kind):
    require(type(row) is dict and set(row) == {"anchorPath", "anchorHash", "transcriptPath", "transcriptHash", "snapshotPath", "snapshotHash", "provenance"}
        and row["provenance"] in ("synthetic_fixture", "trusted_rpc"), "owner notice plan source shape")
    files = {}
    for name in ("anchor", "transcript", "snapshot"):
        path = Path(row[name + "Path"])
        require(path.is_absolute(), "owner notice plan input path must be absolute")
        with path.open("rb") as handle:
            raw = handle.read(MAX_TRANSCRIPT + 1)
        require(len(raw) <= MAX_TRANSCRIPT and keccak256(raw) == row[name + "Hash"], "owner notice plan external source pin differs")
        files[name] = raw
    source = kind(files["anchor"], ReplayTransport(files["transcript"], row["transcriptHash"]), provenance=row["provenance"])
    require(source.snapshot() == files["snapshot"], "owner notice plan original source replay differs")
    return source


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    capture = sub.add_parser("capture"); capture.add_argument("--plan", type=Path, required=True)
    capture.add_argument("--plan-hash", required=True); capture.add_argument("--rpc-env", required=True)
    capture.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify":
        print(dumps(verify_files(read_tree(args.directory), args.manifest_hash)).decode())
        return
    with args.plan.open("rb") as handle:
        raw = handle.read(MAX_MANIFEST + 1)
    require(len(raw) <= MAX_MANIFEST and keccak256(raw) == args.plan_hash, "owner notice external plan hash differs")
    plan = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(plan) is dict and set(plan) == {"profile", "owner", "ownership", "independents", "notices"}
        and plan["profile"] == PROFILE and type(plan["notices"]) is bool
        and type(plan["independents"]) is list and len(plan["independents"]) <= 8, "owner notice capture plan shape")
    catalogue = _input_source(plan["owner"], OwnerCatalogSource)
    ownership = _input_source(plan["ownership"], OwnershipSource) if plan["ownership"] is not None else None
    independents = [_input_source(row, IndependentCatalogSource) for row in plan["independents"]]
    endpoint = os.environ.get(args.rpc_env); require(bool(endpoint), "owner notice RPC environment variable missing")
    source = OwnerNoticeSemanticSource(catalogue, RpcTransport(endpoint), ownership=ownership, independents=independents)
    notices = None
    if plan["notices"]:
        from .owner_notice_evidence import OwnerNoticeEvidenceSource
        notices = OwnerNoticeEvidenceSource(catalogue, RpcTransport(endpoint), provenance=catalogue.provenance)
    print(dumps(write(source, args.output, notices=notices)).decode())


if __name__ == "__main__":
    main()
