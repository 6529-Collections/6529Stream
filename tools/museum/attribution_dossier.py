"""Source-preserving Artist attribution dossier with closed offline reconstruction."""
import argparse
import os
from pathlib import Path

from .bagit import MAX_BYTES, MAX_FILES, MAX_MANIFEST, read_tree, write_tree
from .canonical import dumps, hex_bytes, keccak256, loads
from .chain_rpc import MAX_TRANSCRIPT, ReplayTransport, RpcTransport
from .independent_wire import require
from .metadata_catalog_source import MetadataCatalogSource
from .native_attribution_profile import CLAIMS, QUALIFICATION, NativeAttributionProfile
from .native_attribution_semantics import NativeAttributionSemanticSource, select
from .owner_notice_dossier import DEFAULT_MODEL_ROOT, _input_source, _source_files, leaves
from .owner_notice_semantics import consistent_reads
from .preservation_graph import CONTEXT, VALIDATION_HASH, validator

PROFILE = "STREAM_MUSEUM_NATIVE_ATTRIBUTION_DOSSIER_V1"
RULE = "urn:6529stream:museum:native-attribution:v1:"
# A V2 payload may expand sixfold when control bytes become JSON escape sequences.
MAX_GENERAL_V2_RESOURCE = 6 * 24576 + 8192


def _general_profiles():
    from .general_attestation_source import GeneralAttestationSource, PROFILE as V1, PROFILE_BYTES as V1_BYTES
    from .general_attestation_source_v2 import GeneralAttestationSourceV2, PROFILE as V2, PROFILE_BYTES as V2_BYTES
    return ((V1, GeneralAttestationSource, V1_BYTES), (V2, GeneralAttestationSourceV2, V2_BYTES))


def _general_source(anchor_raw, transport, *, provenance):
    """Choose an explicit retained profile before any producer reads; never fall back."""
    anchor = loads(anchor_raw, maximum=524288, canonical=True)
    require(type(anchor) is dict, "general attribution anchor profile missing")
    for name, kind, _ in _general_profiles():
        if anchor.get("profile") == name:
            return kind(anchor_raw, transport, provenance=provenance)
    require(False, "general attribution anchor profile unsupported")


def _general_profile_bytes(source):
    for _, kind, raw in _general_profiles():
        if type(source) is kind:
            return raw
    require(False, "concrete general attribution source required")


def render(artist, semantic=None, selection=None, *, general=None, model_root=DEFAULT_MODEL_ROOT):
    """Only original textual statements become resources; identities remain evidence."""
    model = validator(model_root)
    files, index, provenance, coverage = {}, [], [], []
    semantic_rows = {} if semantic is None else {r["source"]["recordHash"]: r for r in semantic["statements"]}
    for row in artist["attestations"]:
        original = row["metadataOriginal"]
        raw = hex_bytes(original["payloadHex"])
        source = {"metadataHost": artist["host"], "metadataRecordHash": row["metadataRecordHash"],
            "artistRegistry": artist["artistRegistry"], "attestationRecordHash": row["attestationRecordHash"],
            "sourceState": artist["sourceState"]}
        # Binary and unsupported originals have the same complete field coverage.
        coverage.extend({"source": source, "sourcePath": pointer, "value": value,
            "disposition": "retained_original_native_evidence"} for pointer, value in leaves(row))
        try: content = raw.decode("utf-8")
        except UnicodeDecodeError:
            index.append({"source": source, "status": "retained_binary_original", "path": None})
            continue
        identifier = RULE + row["metadataRecordHash"]
        resource = {"@context": CONTEXT, "id": identifier, "type": "LinguisticObject",
            "_label": "Historically authorized Artist metadata statement", "content": content,
            "classified_as": [{"type": "Type", "id": RULE + "historical-statement",
                "_label": "Native historical attribution"}],
            "referred_to_by": [{"type": "LinguisticObject", "content": QUALIFICATION}]}
        payload = dumps(resource)
        expanded = model.validate_and_expand(payload).expanded_bytes
        stem = row["metadataRecordHash"][2:]
        path = "graph/resources/" + stem + ".json"
        require(path not in files, "native attribution duplicate graph identity")
        files[path], files["graph/expanded/" + stem + ".json"] = payload, expanded
        semantic_row = semantic_rows.get(row["metadataRecordHash"])
        index.append({"source": source, "id": identifier, "path": path, "status": "original_statement",
            "historicalAuthority": row["historicalAuthority"], "currentQualification": row["current"],
            "semanticInterpretation": "not_captured" if semantic_row is None else semantic_row["status"]})
        provenance.extend({"entity": identifier, "path": pointer, "value": value, "source": source,
            "historicalAuthority": row["historicalAuthority"], "currentQualification": row["current"],
            "rule": RULE + "original-statement", "qualification": QUALIFICATION}
            for pointer, value in leaves(resource))
    for identity in artist["identities"]:
        coverage.extend({"source": {"artistRegistry": artist["artistRegistry"], "artistId": identity["artistId"]},
            "sourcePath": pointer, "value": value, "disposition": "retained_identity_evidence_no_person_inference"}
            for pointer, value in leaves(identity))
    for row in (() if general is None else general["records"]):
        source = {"host": general["host"], "recordHash": row["recordHash"], "sourceState": general["sourceState"]}
        coverage.extend({"source": source, "sourcePath": pointer, "value": value,
            "disposition": "retained_original_general_attestation"} for pointer, value in leaves(row))
        authority = {"assertedAttester": row["value"][0], "authenticatedRecorder": row["receipt"][0],
            "verificationClass": row["receipt"][1], "authorityQualification": row["receipt"][2]}
        try: content = hex_bytes(row["payloadHex"]).decode("utf-8")
        except UnicodeDecodeError:
            index.append({"source": source, "status": "retained_binary_original", "path": None, "authority": authority})
            continue
        identifier = RULE + "general:" + general["host"] + ":" + row["recordHash"]
        resource = {"@context": CONTEXT, "id": identifier, "type": "LinguisticObject",
            "_label": "General attestation statement", "content": content,
            "classified_as": [{"type": "Type", "id": RULE + "general-statement", "_label": "Attributed statement"}],
            "referred_to_by": [{"type": "LinguisticObject", "content": general["qualification"]}]}
        raw = dumps(resource); stem = "general-" + row["recordHash"][2:]
        path = "graph/resources/" + stem + ".json"
        require(path not in files, "general attribution duplicate graph identity")
        from .general_attestation_source_v2 import PROFILE as GENERAL_V2
        maximum = MAX_GENERAL_V2_RESOURCE if general["profile"] == GENERAL_V2 else 24576
        files[path], files["graph/expanded/" + stem + ".json"] = raw, model.validate_and_expand(raw, maximum=maximum).expanded_bytes
        index.append({"source": source, "id": identifier, "path": path, "status": "original_statement",
            "authority": authority, "interpretation": row["interpretation"]})
        provenance.extend({"entity": identifier, "path": pointer, "value": value, "source": source,
            "authority": authority, "rule": RULE + "original-general-statement", "qualification": general["qualification"]}
            for pointer, value in leaves(resource))
    files.update({"graph/index.json": dumps({"profile": PROFILE, "validationPolicyHash": VALIDATION_HASH,
            "resources": index, "claims": CLAIMS}), "graph/provenance.json": dumps(provenance),
        "graph/source-coverage.json": dumps(coverage),
        "dossier.json": dumps({"profile": PROFILE, "version": "1", "sourceState": artist["sourceState"],
            "nativeArtistEvidence": artist, "semanticEvidence": semantic, "selection": selection,
            "generalAttestationEvidence": {"status": "not_captured" if general is None else "captured", "original": general},
            "identityMappings": [{"artistId": row["artistId"], "kind": "native_protocol_identity",
                "original": row, "personIdentityEstablished": False} for row in artist["identities"]],
            "claims": CLAIMS, "qualification": QUALIFICATION})})
    return files


def build_files(artist_source, *, semantic=None, general=None, selection_raw=None, selection_hash=None, model_root=DEFAULT_MODEL_ROOT):
    from .artist_attestation_source import ArtistAttestationSource, PROFILE_BYTES as ARTIST_PROFILE_BYTES
    require(type(artist_source) is ArtistAttestationSource, "concrete Artist source required for dossier")
    raw_artist = artist_source.snapshot()
    artist = loads(raw_artist, maximum=MAX_TRANSCRIPT, canonical=True)
    files = _source_files(artist_source.metadata_catalog, "sources/metadata")
    files.update({"artist/snapshot.json": raw_artist, "artist/transcript.json": artist_source.transcript(),
        "artist/profile.json": ARTIST_PROFILE_BYTES})
    general_value = None
    if general is not None:
        general_profile = _general_profile_bytes(general)
        require(general.provenance == artist_source.provenance,
            "concrete general attribution source with matching provenance required")
        general_value = loads(general.snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)
        require(general_value["sourceState"] == artist["sourceState"]
            and all(general.a[name] == artist_source.metadata_catalog.a[other] for name, other in
                (("metadata", "host"), ("artistRegistry", "artistRegistry"), ("schemas", "schemas"), ("store", "store")))
            and general.a["stateRoot"] == artist_source.metadata_catalog.a["stateRoot"],
            "general attribution joined source identity/state differs")
        files.update(_source_files(general, "sources/general"))
        files["sources/general/profile.json"] = general_profile
    semantic_value = selected = None
    require((selection_raw is None) == (selection_hash is None), "native attribution selection external pin required")
    if semantic is not None:
        require(type(semantic) is NativeAttributionSemanticSource and semantic.artist is artist_source,
            "semantic evidence must use exact Artist source")
        raw = semantic.snapshot(); semantic_value = loads(raw, maximum=MAX_TRANSCRIPT, canonical=True)
        files.update({"semantics/snapshot.json": raw, "semantics/transcript.json": semantic.transcript()})
        for name, (_, raw) in semantic.profile.documents.items():
            files["semantics/documents/" + name + ".json"] = raw
        if selection_raw is not None:
            selected = select(semantic_value, selection_raw, selection_hash)
            files["semantics/selection.json"] = selection_raw
    else:
        require(selection_raw is None, "native attribution selection needs semantic source")
    consistent_reads([raw for path, raw in files.items() if path.endswith("/transcript.json")])
    files.update(render(artist, semantic_value, selected, general=general_value, model_root=model_root))
    report = {"profile": PROFILE, "version": "1", "status": "supplementary_partial_dossier",
        "provenance": artist_source.provenance, "sourceState": artist["sourceState"],
        "originalArtistSourceHash": keccak256(raw_artist), "attestationCount": str(len(artist["attestations"])),
        "identityCount": str(len(artist["identities"])), "semanticInterpretation": "captured" if semantic else "not_captured",
        "generalAttestations": "not_captured" if general is None else "captured",
        "generalAttestationCount": None if general_value is None else str(len(general_value["records"])),
        "reviewSelection": "captured" if selected is not None else "not_captured",
        "claims": CLAIMS, "qualification": QUALIFICATION}
    files["report.json"] = dumps(report)
    manifest = {"profile": PROFILE, "version": "1", "provenance": artist_source.provenance,
        "validationPolicyHash": VALIDATION_HASH, "components": {"semantics": semantic is not None,
            "selection": selection_raw is not None, "general": general is not None}, "selectionHash": selection_hash,
        "files": [{"path": path, "bytes": str(len(raw)), "hash": keccak256(raw)} for path, raw in sorted(files.items())],
        "claims": CLAIMS}
    files["manifest.json"] = dumps(manifest)
    require(len(files) <= MAX_FILES and sum(map(len, files.values())) <= MAX_BYTES
        and len(files["manifest.json"]) <= MAX_MANIFEST, "native attribution package bounds")
    return files


def verify_files(files, manifest_hash, *, model_root=DEFAULT_MODEL_ROOT):
    from .artist_attestation_source import ArtistAttestationSource
    require(type(files) is dict and "manifest.json" in files and len(files) <= MAX_FILES
        and all(type(raw) is bytes for raw in files.values()) and sum(map(len, files.values())) <= MAX_BYTES,
        "native attribution package shape/bound")
    require(keccak256(files["manifest.json"]) == manifest_hash, "native attribution external manifest pin differs")
    manifest = loads(files["manifest.json"], maximum=MAX_MANIFEST, canonical=True)
    require(type(manifest) is dict and set(manifest) == {"profile", "version", "provenance", "validationPolicyHash",
        "components", "selectionHash", "files", "claims"} and manifest["profile"] == PROFILE and manifest["version"] == "1"
        and manifest["provenance"] in ("synthetic_fixture", "trusted_rpc")
        and manifest["validationPolicyHash"] == VALIDATION_HASH and manifest["claims"] == CLAIMS,
        "native attribution manifest shape/profile")
    flags = manifest["components"]
    require(type(flags) is dict and set(flags) == {"semantics", "selection", "general"}
        and all(type(value) is bool for value in flags.values()) and (not flags["selection"] or flags["semantics"])
        and flags["selection"] == (manifest["selectionHash"] is not None), "native attribution component flags")
    require(type(manifest["files"]) is list and len(manifest["files"]) == len(files) - 1, "native attribution file count")
    seen = {"manifest.json"}
    for row in manifest["files"]:
        require(type(row) is dict and set(row) == {"path", "bytes", "hash"} and type(row["path"]) is str
            and row["path"] not in seen and row["path"] in files, "native attribution file inventory")
        raw = files[row["path"]]; seen.add(row["path"])
        require(row["bytes"] == str(len(raw)) and row["hash"] == keccak256(raw), "native attribution file bytes differ")
    require(seen == set(files), "native attribution unlisted files")
    required = {"sources/metadata/" + name + ".json" for name in ("anchor", "snapshot", "transcript")}
    required |= {"artist/snapshot.json", "artist/transcript.json", "artist/profile.json"}
    if flags["semantics"]: required |= {"semantics/snapshot.json", "semantics/transcript.json"}
    if flags["general"]: required |= {"sources/general/" + name + ".json" for name in ("anchor", "snapshot", "transcript", "profile")}
    if flags["selection"]: required.add("semantics/selection.json")
    require(required <= files.keys(), "native attribution required component missing")
    raw = files["sources/metadata/transcript.json"]
    catalogue = MetadataCatalogSource(files["sources/metadata/anchor.json"], ReplayTransport(raw, keccak256(raw)),
        provenance=manifest["provenance"])
    require(catalogue.snapshot() == files["sources/metadata/snapshot.json"], "native attribution metadata replay differs")
    raw = files["artist/transcript.json"]
    artist = ArtistAttestationSource(catalogue, ReplayTransport(raw, keccak256(raw)))
    require(artist.snapshot() == files["artist/snapshot.json"], "native attribution Artist replay differs")
    semantic = None
    if flags["semantics"]:
        raw = files["semantics/transcript.json"]
        semantic = NativeAttributionSemanticSource(artist, ReplayTransport(raw, keccak256(raw)),
            profile=NativeAttributionProfile(model_root))
        require(semantic.snapshot() == files["semantics/snapshot.json"], "native attribution semantic replay differs")
    general = None
    if flags["general"]:
        raw = files["sources/general/transcript.json"]
        general = _general_source(files["sources/general/anchor.json"], ReplayTransport(raw, keccak256(raw)),
            provenance=manifest["provenance"])
        require(files["sources/general/profile.json"] == _general_profile_bytes(general),
            "native attribution general profile bytes differ")
        require(general.snapshot() == files["sources/general/snapshot.json"], "native attribution general replay differs")
    rebuilt = build_files(artist, semantic=semantic, general=general,
        selection_raw=files["semantics/selection.json"] if flags["selection"] else None,
        selection_hash=manifest["selectionHash"], model_root=model_root)
    require(rebuilt == files, "native attribution derived bytes do not reconstruct")
    return loads(files["report.json"], maximum=MAX_MANIFEST, canonical=True)


def write(artist, destination, **kwargs):
    files = build_files(artist, **kwargs)
    write_tree(files, destination)
    return {"manifestHash": keccak256(files["manifest.json"]), "files": str(len(files)), "claims": CLAIMS}


def main():
    from .artist_attestation_source import ArtistAttestationSource
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify"); verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    capture = sub.add_parser("capture"); capture.add_argument("--plan", type=Path, required=True)
    capture.add_argument("--plan-hash", required=True); capture.add_argument("--rpc-env", required=True)
    capture.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "verify":
        print(dumps(verify_files(read_tree(args.directory), args.manifest_hash)).decode()); return
    with args.plan.open("rb") as handle: raw = handle.read(MAX_MANIFEST + 1)
    require(len(raw) <= MAX_MANIFEST and keccak256(raw) == args.plan_hash, "native attribution external plan pin differs")
    plan = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    require(type(plan) is dict and set(plan) == {"profile", "metadata", "semantics", "general"}
        and plan["profile"] == PROFILE and type(plan["semantics"]) is bool, "native attribution capture plan shape")
    catalogue = _input_source(plan["metadata"], MetadataCatalogSource)
    general = None
    if plan["general"] is not None:
        general = _input_source(plan["general"], _general_source)
    endpoint = os.environ.get(args.rpc_env); require(bool(endpoint), "native attribution RPC environment missing")
    artist = ArtistAttestationSource(catalogue, RpcTransport(endpoint))
    semantic = NativeAttributionSemanticSource(artist, RpcTransport(endpoint)) if plan["semantics"] else None
    print(dumps(write(artist, args.output, semantic=semantic, general=general)).decode())


if __name__ == "__main__":
    main()
