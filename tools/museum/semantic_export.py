"""Bounded archival manifest over a replayed typed-account authority package.

Generation is permissionless. This module never writes a chain record, infers a
token from a collection, or upgrades the source's account/snapshot authority.
"""
from copy import deepcopy
from pathlib import Path

from .account_profile import JCS_ID
from .authority import need
from .authority_package_v2 import verify_authority_package
from .canonical import MuseumError, dumps, keccak256, loads, schema_id, uint
from .citations import canonical_citation
from .independent_wire import RAW_BYTES
from .package import MAX_BYTES, MAX_FILES, write_package
from .package_recorded import INPUT_FILES
from .package_v2 import _assemble, _read_package
from .recorded_projection import replay_source_bytes
from .review import _selector, _validate
from .schemas import ref
from .typed_authority_profile import NAMES, SCHEMAS, TypedAuthorityProfile

NAME = "STREAM_SEMANTIC_EXPORT_V3"
POLICY_NAME = "STREAM_MUSEUM_ARCHIVAL_EXPORT_PROFILE_V1"
MODE = "recorded_typed_account_semantic_export"
MANIFEST_PATH = "semantic/manifest.json"
MAX_PAYLOAD = 8192
POLICY = {
    "name": POLICY_NAME, "version": "1", "schema": NAME,
    "source": "Exact replay of a public typed-account authority V2 package at one trusted-RPC block; one collection or one token subject only.",
    "selection": "Retain the separate original base and authority policies, their exact source/reviewer selectors, and the base entity plan. Their canonical composite document is the selectionPolicyHash. Do not merge their authority or conflict rules.",
    "identity": "Sort entities by unchanged IRI. One Linked Art resource per local entity, or exact typed extension sidecar entry; external references remain external. Resource names are Keccak256 of the original UTF-8 IRI.",
    "merge": "Preserve original base resources; append only verified authority equivalent values sorted by IRI and canonical bytes. Authority-only entities retain their exact declaration and mapping provenance.",
    "scope": "All retained records share the derived subject. Collection scope has tokenId null and canonicalCitation empty: no work citation is invented. Token scope uses its original CAIP-19 identity and the sole captured lane's chain head. Finality is explicitly unestablished.",
    "hashGraph": "Manifest commits only to children and earlier source records. Package envelope commits to manifest. Export publication is subsequent evidence outside these inputs; no own-record or dossier hash in manifest.",
    "canonicalization": "New JSON uses registered JCS with fixed Keccak256 HashRef. Original files retain exact bytes under RAW_BYTES references. No RDF canonicalization claim.",
    "limits": {"manifestBytes": str(MAX_PAYLOAD), "entities": "512", "resourceBytes": "1048576", "jsonDepth": "64", "packageFiles": str(MAX_FILES), "packageBytes": str(MAX_BYTES)},
    "previousExport": "First-generation exports only; non-null predecessor is rejected until bounded lineage replay is implemented.",
    "claims": {"fullMuseumConformance": False, "linkedArtApi": False, "consensusFinality": False,
        "publisherAuthenticated": False, "humanIdentity": False, "bagIt": False, "onchainPublication": False}}
POLICY_BYTES = dumps(POLICY)
POLICY_HASH = keccak256(POLICY_BYTES)


def export_schema():
    schema = deepcopy(loads(SCHEMAS[NAMES[2]], canonical=True))
    schema.update(title=NAME, **{"$id": "urn:6529stream:schema:" + NAME,
        "x-stream-schema-id": schema_id(NAME),
        "x-stream-profile": {"supersedesSchemaId": schema_id(NAMES[2])}})
    properties = schema["properties"]
    for name in ("sourceAuthoritySet", "reviewerAuthoritySet", "resources"):
        del properties[name]
        schema["required"].remove(name)
    for name in ("authoritySelection", "resourceIndex", "exportPolicy"):
        properties[name] = ref("document")
        schema["required"].append(name)
    schema["x-stream-semantic-checks"] = "Exact source replay, child joins and registered export policy are mandatory; shape alone is not conformance or archival authority."
    return schema


SCHEMA_BYTES = dumps(export_schema())
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def document(path, raw, *, canonical=JCS_ID, media_type="application/json"):
    return {"path": path, "contentHash": {"algorithm": "1", "digest": keccak256(raw),
        "canonicalizationId": canonical}, "byteLength": str(len(raw)), "mediaType": media_type}


def source_scope(source):
    """Establish source/disclosure scope before evaluating the projection outputs."""
    need(type(source.profile) is TypedAuthorityProfile, "typed account source required")
    need(source.state.records and all(r.disclosure == "public" for r in source.state.records), "public source scope required")
    capture = loads(source.capture_bytes, maximum=MAX_BYTES, canonical=True)
    subjects = {tuple(row["subject"]) for row in capture["records"]}
    need(len(subjects) == 1, "mixed export subjects unsupported")
    kind, collection, token, _ = next(iter(subjects))
    need(kind in ("0", "1") and uint(collection) > 0, "collection or token export scope required")
    heads = []
    for lane in capture["lanes"]:
        need(lane["scopeKey"] == collection and uint(lane["count"]) > 0, "empty or foreign export lane")
        rows = [r for r in source.state.records if r.selector.record_type == lane["recordType"]]
        head = max(rows, key=lambda r: uint(r.selector.record_index, 64))
        need(head.selector.record_chain_hash == lane["chainHash"] and uint(head.selector.record_index, 64) + 1 == uint(lane["count"]), "export head mismatch")
        heads.append(_selector(head, ""))
    need(len(heads) == 1, "this export policy requires one exact source lane")
    a = source.anchor
    citation = "" if kind == "0" else canonical_citation(a["chainId"], a["core"], token,
        {"kind": "chain", "hash": heads[0]["recordChainHash"]})
    disclosure = dumps({"classification": "public", "sourceStateHash": source.state.commitment,
        "records": [{"selector": _selector(r, ""), "payloadHash": r.payload_hash, "classification": r.disclosure}
            for r in sorted(source.state.records, key=lambda r: r.selector.record_hash)],
        "scope": "Every retained source, sidecar, snapshot, dependency and report; explicit public classification required. No restricted-family adapter is admitted."})
    return {"chainId": a["chainId"], "core": a["core"], "collectionId": collection,
        "tokenId": None if kind == "0" else token,
        "anchorSubject": {"kind": "collection" if kind == "0" else "token", "subjectId": heads[0]["subjectId"]},
        "canonicalCitation": citation, "blockNumber": a["blockNumber"], "blockHash": a["blockHash"],
        "finalityQualifier": "unfinalized_trusted_rpc_block", "recordHeads": heads,
        "disclosurePolicyHash": keccak256(disclosure)}, disclosure


def _source(directory, files):
    pins = loads(files["source/manifest.json"], maximum=2097152, canonical=True)["pins"]
    return replay_source_bytes(directory / "source/dependencies",
        {name: files["source/inputs/" + name] for name in INPUT_FILES},
        **{key + "_hash": pins[key] for key in ("source", "publication", "interpretation", "profile")})


def identity_evidence(identifier, authority_provenance):
    """Keep compatible continuations from emitted claims, never superseded rows."""
    declarations = {}
    for row in authority_provenance:
        if row["entity"] != identifier: continue
        for origin in row["sources"]:
            declaration = origin["entityDeclaration"]
            evidence = {"declaration": declaration, "lineage": origin.get("declarationLineage", [])}
            declarations[dumps(evidence)] = evidence
    need(declarations, "authority-only resource lacks emitted declaration evidence")
    return {"entity": identifier, "paths": ["/id", "/type", "/_label"],
        "declarations": [declarations[key] for key in sorted(declarations)],
        "rule": POLICY_NAME + ":authority-only-identity",
        "qualification": "The label is the unchanged entity IRI; no authority-publisher label is substituted."}


def build_export(directory, expected_manifest_hash, *, disclosure):
    """Use original authenticated input bytes; accept no caller-authored manifest facts."""
    need(disclosure == "public", "explicit public export classification required")
    directory = Path(directory).resolve()
    _, envelope, originals = _read_package(directory, expected_manifest_hash)
    need(envelope.get("mode") == "recorded_account_authority_package_v2" and envelope.get("disclosure") == "public", "typed authority package required")
    try:
        source = _source(directory, originals)
        scope, disclosure_raw = source_scope(source)
        original = verify_authority_package(directory, expected_manifest_hash)
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("semantic export source input missing") from exc
    need(dict(original.files) == originals, "source changed during export")
    files = {"input/" + name: raw for name, raw in originals.items()}
    files["input/manifest.json"] = original.manifest
    files["definitions/" + NAME + ".json"] = SCHEMA_BYTES
    files["definitions/" + POLICY_NAME + ".json"] = POLICY_BYTES
    files["semantic/disclosure.json"] = disclosure_raw
    base_sidecar = loads(originals["source/linked-art/sidecar.json"], maximum=MAX_BYTES, canonical=True)
    authority_sidecar = loads(originals["authority/sidecar.json"], maximum=MAX_BYTES, canonical=True)
    authority_provenance = loads(originals["authority/provenance.json"], maximum=MAX_BYTES, canonical=True)
    selection = {"basePolicy": loads(originals["source/inputs/selection.json"], maximum=524288, canonical=True),
        "authorityPolicy": loads(originals["inputs/selection.json"], maximum=524288, canonical=True),
        "entityPlan": loads(originals["source/inputs/plan.json"], maximum=524288, canonical=True)}
    selection_raw = dumps(selection)
    files["semantic/authority-selection.json"] = selection_raw
    resources = {row["id"]: loads(originals["source/" + row["path"]], maximum=1048576, canonical=True)
        for row in loads(originals["source/linked-art/entity-index.json"], maximum=2097152)}
    authority_index = loads(originals["authority/index.json"], maximum=2097152)["resources"]
    external = {row["id"]: row for row in base_sidecar["externalEntities"]}
    extensions = {row["id"]: row for row in base_sidecar["extensionEntities"]}
    for row in authority_index:
        value = loads(originals[row["path"]], maximum=1048576, canonical=True)
        need(row["id"] not in external and row["id"] not in extensions, "authority resource changes entity classification")
        if row["id"] in resources:
            base = resources[row["id"]]
            need(base["type"] == value["type"], "authority resource changes entity class")
            values = {dumps(v): v for v in base.get("equivalent", []) + value["equivalent"]}
            base["equivalent"] = sorted(values.values(), key=lambda v: (v["id"], dumps(v)))
        else:
            resources[row["id"]] = value
    need(len(resources) + len(extensions) + len(external) <= 512, "export entity bound")
    index, resource_refs, correspondence, identity_provenance = [], [], [], []
    base_identifiers = set(resources) - {r["id"] for r in authority_index}
    base_identifiers.update(r["id"] for r in loads(originals["source/linked-art/entity-index.json"]))
    authority_identifiers = {r["id"] for r in authority_index}
    for identifier, value in sorted(resources.items()):
        raw = dumps(value); need(len(raw) <= 1048576, "export resource bound")
        expanded = source.profile.linked_art.validate_and_expand(raw).expanded_bytes
        name = keccak256(identifier.encode("utf-8"))[2:]
        path, expanded_path = "semantic/resources/" + name + ".json", "semantic/expanded/" + name + ".json"
        files[path], files[expanded_path] = raw, expanded
        index.append({"id": identifier, "kind": "linked_art", "type": value["type"], "path": path})
        resource_refs.append({"id": identifier, "resource": document(path, raw), "expanded": document(expanded_path, expanded)})
        correspondence.append({"id": identifier, "baseResource": identifier in base_identifiers,
            "authorityResource": identifier in authority_identifiers, "exportPath": path})
        if identifier not in base_identifiers:
            identity_provenance.append(identity_evidence(identifier, authority_provenance))
    assertions = {"base": base_sidecar, "authority": authority_sidecar}
    for i, row in enumerate(base_sidecar["extensionEntities"]):
        index.append({"id": row["id"], "kind": "stream_extension", "type": row["kind"],
            "path": "semantic/assertions.json", "pointer": "/base/extensionEntities/" + str(i)})
    index.extend({"id": row["id"], "kind": "external", "type": row["kind"], "path": None} for row in external.values())
    index.sort(key=lambda r: r["id"])
    dependency_refs = [document("input/" + name, raw, canonical=RAW_BYTES, media_type="application/octet-stream")
        for name, raw in sorted(originals.items()) if name.startswith(("source/definitions/", "source/dependencies/", "definitions/"))]
    dependency_refs.extend(document(path, files[path]) for path in sorted(files) if path.startswith("definitions/"))
    snapshots = {"logicalIndex": loads(originals["inputs/snapshot-index.json"], maximum=524288),
        "admission": loads(originals["authority/snapshot-index.json"], maximum=MAX_BYTES),
        "documents": [document("input/" + name, raw, canonical=RAW_BYTES) for name, raw in sorted(originals.items()) if name.startswith("snapshots/")],
        "pathBase": "input/", "publisherAuthenticated": False}
    components = {
        "entityIndex": index, "assertions": assertions,
        "provenance": {"base": loads(originals["source/linked-art/provenance.json"], maximum=MAX_BYTES),
            "authority": authority_provenance,
            "authorityIdentity": identity_provenance, "compositionRule": POLICY["merge"],
            "identityCorrespondence": correspondence, "originalPathBases": {"base": "input/source/", "authority": "input/"}},
        "authoritySnapshots": snapshots, "dependencyLock": dependency_refs,
        "coverage": {"scope": document("semantic/disclosure.json", disclosure_raw),
            "base": loads(originals["source/linked-art/coverage.json"], maximum=MAX_BYTES),
            "authority": loads(originals["authority/coverage.json"], maximum=MAX_BYTES)},
        "validation": {"sourceStateHash": source.state.commitment, "exportPolicyHash": POLICY_HASH,
            "base": loads(originals["source/linked-art/report.json"], maximum=MAX_BYTES),
            "authority": loads(originals["authority/report.json"], maximum=MAX_BYTES),
            "conformance": {"streamProfile": "not_evaluated", "linkedArtModel": "pass", "linkedArtApi": "not_claimed"},
            "qualification": "Structural export and emitted Linked Art validation only. Full Museum/archival acceptance, finality, publisher identity and human independence remain unestablished."},
        "identityCorrespondence": correspondence}
    refs = {}
    for name, value in components.items():
        path = "semantic/" + name + ".json"
        # The entity index's extension paths refer to this exact sidecar file.
        raw = dumps(value); files[path] = raw; refs[name] = document(path, raw)
    resource_index = dumps(resource_refs); files["semantic/resource-index.json"] = resource_index
    manifest = dumps({"profileSchemaId": schema_id(NAMES[0]), "profileHash": source.profile_hash,
        "sourceState": scope, "selectionPolicyHash": keccak256(selection_raw),
        "authoritySelection": document("semantic/authority-selection.json", selection_raw),
        "exportPolicy": document("definitions/" + POLICY_NAME + ".json", POLICY_BYTES),
        "components": refs, "resourceIndex": document("semantic/resource-index.json", resource_index),
        "completeness": "incomplete", "conformance": components["validation"]["conformance"], "previousExport": None})
    need(len(manifest) <= MAX_PAYLOAD, "semantic manifest exceeds retained record payload bound")
    _validate(SCHEMA_BYTES, manifest)
    files[MANIFEST_PATH] = manifest
    return _assemble(directory, files, {"mode": MODE, "version": "1", "sourceManifestHash": original.manifest_hash,
        "semanticManifestHash": keccak256(manifest), "exportSchemaHash": SCHEMA_HASH,
        "exportPolicyHash": POLICY_HASH, "disclosure": disclosure, "claims": POLICY["claims"]})


def verify_export(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    need(manifest.get("mode") == MODE, "semantic export package mode differs")
    try:
        rebuilt = build_export(directory / "input", manifest["sourceManifestHash"], disclosure=manifest["disclosure"])
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("semantic export reconstruction input missing") from exc
    need(rebuilt.manifest == raw and dict(rebuilt.files) == files, "semantic export reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    definitions = sub.add_parser("definitions"); definitions.add_argument("--check", action="store_true")
    build = sub.add_parser("build"); build.add_argument("source", type=Path); build.add_argument("output", type=Path)
    build.add_argument("--manifest-hash", required=True); build.add_argument("--disclosure", required=True, choices=("public", "restricted"))
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path); verify.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "definitions":
        root = Path(__file__).resolve().parents[2] / "schemas/museum/archival-export"
        for name, raw in ((NAME, SCHEMA_BYTES), (POLICY_NAME, POLICY_BYTES)):
            path = root / (name + ".json")
            if args.check: need(path.read_bytes() == raw, "stale archival export definition")
            else: root.mkdir(parents=True, exist_ok=True); path.write_bytes(raw)
        return
    if args.command == "build":
        result = build_export(args.source, args.manifest_hash, disclosure=args.disclosure); write_package(result, args.output)
    else: result = verify_export(args.directory, args.manifest_hash)
    print(result.manifest_hash)


if __name__ == "__main__": main()
