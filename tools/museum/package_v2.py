"""Offline v2 packages with explicit fixture or recorded-account source admission.

Fixture packages compose all four existing formats. Recorded-account packages
replay captured evidence and report unsupported formats explicitly. Neither
mode retrieves media or claims BagIt/OCFL or institutional conformance.
"""
from hashlib import sha256
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .dependencies import OfflineDocuments, safe_path
from .package import (MAX_BYTES, MAX_FILES, MAX_MANIFEST, ResourcePackage, _package_path,
                      fixture_state_bytes, fixture_state_from_bytes, write_package)
from .projection_v2 import CROSSWALK_V2_BYTES, CROSSWALK_V2_HASH, ProjectionProfileV2
from .premis import PinnedPremis, PROFILE_BYTES as PREMIS_BYTES, PROFILE_HASH as PREMIS_HASH
from .iiif_model import PinnedIIIF, PROFILE_BYTES as IIIF_BYTES, PROFILE_HASH as IIIF_HASH
from .lido_model import PinnedLIDO, PROFILE_BYTES as LIDO_BYTES, PROFILE_HASH as LIDO_HASH
from .lido import project_lido_fixture

FORMATS = ["linked_art_v2", "premis_file_v1", "iiif_presentation_v1", "lido_work_v1"]
INPUTS = ("selection", "plan", "premis_plan", "iiif_plan", "lido_plan")
CLAIMS = {name: False for name in ("registered", "authenticatedChainState", "fullMuseumScope",
    "institutionalIngest", "mediaRetrieved", "fixityVerified", "archivedImplementation", "bagIt", "ocfl")}
DEFINITIONS = {"crosswalk-v2.json": CROSSWALK_V2_BYTES, "premis-profile.json": PREMIS_BYTES,
               "iiif-profile.json": IIIF_BYTES, "lido-profile.json": LIDO_BYTES}


def _dependencies(root, *, recorded=False, premis=False, iiif=False, lido=False):
    """Archive only the required exact interpretation closures; no tree copy or fetch."""
    files = {}

    def retain(path):
        relative = path.relative_to(root).as_posix()
        target = "dependencies/" + relative
        raw = path.read_bytes()
        if target in files and files[target] != raw:
            raise MuseumError("ambiguous multiformat dependency")
        files[target] = raw
        return raw

    indices = (
        (root, "linked-art-v2/validation-index.json"),
        (root / "standards", "vocabulary-index.json"),
        (root, "premis/dependency-index.json"),
        (root, "iiif/dependency-index.json"),
        (root, "lido/dependency-index.json"),
    )
    for subroot, name in (indices[:5 if lido else 4 if iiif else 3 if premis else 2] if recorded else indices):
        index_path = safe_path(subroot, name)
        if index_path.stat().st_size > 524288:
            raise MuseumError("multiformat dependency index bound")
        index = loads(retain(index_path), maximum=524288, canonical=True)
        OfflineDocuments(subroot, index)
        for document in index["documents"]:
            for chunk in document["chunks"]:
                path = safe_path(subroot, chunk["path"])
                raw = retain(path)
                if len(raw) != uint(chunk["byteLength"], 32) or sha256(raw).digest() != hex_bytes(chunk["sha256"], 32):
                    raise MuseumError("multiformat dependency changed during construction")
    names = ["linked-art-v2/validation-policy.json", "standards/vocabulary-policy.json",
             "linked-art-v2/LICENSE.linked-art.txt", "standards/LICENSE.linked-art.txt",
             "fixtures/dependencies/LICENSE.linked-art.txt"]
    if not recorded or iiif:
        names += ["iiif/sound-context.json", "iiif/target.schema.json",
                  "iiif/licenses/cid-LICENSE", "iiif/licenses/arweave-LICENSE.md", "iiif/licenses/multicodec-LICENSE"]
    for name in names:
        retain(safe_path(root, name))
    return files


def build_fixture_package(state, selection_bytes, plan_bytes, premis_plan_bytes,
                          iiif_plan_bytes, lido_plan_bytes, *, root, profile_hash,
                          selection_hash, plan_hash, premis_plan_hash, iiif_plan_hash,
                          lido_plan_hash, validation_hash, vocabulary_hash):
    """Build all formats from one source/selection and explicitly bound corresponding plans."""
    root = Path(root).resolve()
    state_raw = fixture_state_bytes(state)
    if fixture_state_from_bytes(state_raw) != state:
        raise MuseumError("multiformat source serialization differs")
    linked = ProjectionProfileV2(root, CROSSWALK_V2_BYTES, crosswalk_hash=CROSSWALK_V2_HASH,
        validation_hash=validation_hash, vocabulary_hash=vocabulary_hash)
    result = project_lido_fixture(state, selection_bytes, plan_bytes, premis_plan_bytes,
        iiif_plan_bytes, lido_plan_bytes, profile_hash=profile_hash,
        selection_hash=selection_hash, plan_hash=plan_hash, premis_plan_hash=premis_plan_hash,
        iiif_plan_hash=iiif_plan_hash, lido_plan_hash=lido_plan_hash, linked_art_profile=linked,
        premis_profile=PinnedPremis(root, PREMIS_BYTES, profile_hash=PREMIS_HASH),
        iiif_profile=PinnedIIIF(root, IIIF_BYTES, profile_hash=IIIF_HASH),
        lido_profile=PinnedLIDO(root, LIDO_BYTES, profile_hash=LIDO_HASH))
    iiif, premis, linked = result.iiif, result.iiif.premis, result.iiif.premis.linked_art
    files = _dependencies(root)
    files["inputs/source-state.json"] = state_raw
    raw_inputs = (selection_bytes, plan_bytes, premis_plan_bytes, iiif_plan_bytes, lido_plan_bytes)
    for name, raw in zip(INPUTS, raw_inputs):
        files["inputs/" + name.replace("_", "-") + ".json"] = raw
    for name, raw in DEFINITIONS.items():
        files["definitions/" + name] = raw
    for format_name, projected in (("linked-art", linked), ("premis", premis), ("iiif", iiif), ("lido", result)):
        for report in ("report", "coverage", "provenance"):
            files[format_name + "/" + report + ".json"] = getattr(projected, report)
        if format_name != "linked-art":
            files[format_name + "/correspondence.json"] = projected.correspondence
    files.update({"linked-art/sidecar.json": linked.sidecar, "premis/premis.xml": premis.xml,
                  "iiif/manifest.json": iiif.manifest, "lido/lido.xml": result.xml})
    entities = []
    for resource in linked.resources:
        ident = keccak256(resource.identifier.encode("utf-8"))[2:]
        path, expanded = "linked-art/entities/" + ident + ".json", "linked-art/expanded/" + ident + ".json"
        if path in files or expanded in files:
            raise MuseumError("multiformat entity path collision")
        files[path], files[expanded] = resource.content, resource.expanded
        entities.append({"id": resource.identifier, "kind": "linked_art", "path": path, "expandedPath": expanded})
    sidecar = loads(linked.sidecar, maximum=64 * 1024 * 1024)
    for entity in sidecar["extensionEntities"]:
        entities.append({"id": entity["id"], "kind": "stream_extension", "path": "linked-art/sidecar.json"})
    files["linked-art/entity-index.json"] = dumps(sorted(entities, key=lambda row: row["id"]))
    # Preserve each correspondence's entity roles; do not collapse work, token, file,
    # display Canvas, source issuer and creator into a misleading shared identifier.
    files["reports/shared-identity.json"] = dumps({
        "sourceStateHash": state.commitment, "linkedArtEntityIndex": "linked-art/entity-index.json",
        "premis": loads(premis.correspondence, maximum=64 * 1024 * 1024),
        "iiif": loads(iiif.correspondence, maximum=64 * 1024 * 1024),
        "lido": loads(result.correspondence, maximum=64 * 1024 * 1024)})
    pins = {"profile": profile_hash, "selection": selection_hash, "plan": plan_hash,
        "premis_plan": premis_plan_hash, "iiif_plan": iiif_plan_hash, "lido_plan": lido_plan_hash,
        "validation": validation_hash, "vocabulary": vocabulary_hash,
        "crosswalk": CROSSWALK_V2_HASH, "premis_profile": PREMIS_HASH,
        "iiif_profile": IIIF_HASH, "lido_profile": LIDO_HASH}
    return _assemble(root, files, {"mode": "synthetic_candidate_resource_package", "version": "2",
        "formats": FORMATS, "sourceStateHash": state.commitment, "pins": pins, "claims": CLAIMS})


def _assemble(root, files, metadata):
    """Shared bounded file envelope; source-specific builders own their evidence and claims."""
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("multiformat package bounds exceeded")
    # Validate portability before writing, including cross-platform case collisions.
    folded = set()
    for name in files:
        _package_path(root, name)
        if name.casefold() in folded:
            raise MuseumError("multiformat package path collision")
        folded.add(name.casefold())
    manifest = dumps({**metadata, "files": [{"path": name, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
                   "keccak256": keccak256(raw)} for name, raw in sorted(files.items())]})
    if len(manifest) > MAX_MANIFEST:
        raise MuseumError("multiformat manifest bound exceeded")
    return ResourcePackage(tuple(sorted(files.items())), manifest)


def _read_package(directory, expected_manifest_hash):
    """Authenticate the bounded exact file inventory before source-specific replay."""
    directory = Path(directory).resolve()
    manifest_path = _package_path(directory, "manifest.json")
    if manifest_path.stat().st_size > MAX_MANIFEST:
        raise MuseumError("multiformat manifest bound exceeded")
    raw = manifest_path.read_bytes()
    if keccak256(raw) != expected_manifest_hash:
        raise MuseumError("multiformat manifest external hash mismatch")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    if (not isinstance(manifest, dict) or not isinstance(manifest.get("files"), list)
            or len(manifest["files"]) > MAX_FILES):
        raise MuseumError("unsupported multiformat package manifest")
    files, folded, total = {}, set(), 0
    for row in manifest["files"]:
        if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256", "keccak256"}:
            raise MuseumError("invalid multiformat file row")
        name = row["path"]
        path = _package_path(directory, name)
        if name.casefold() in folded or name.casefold() == "manifest.json":
            raise MuseumError("duplicate or recursive multiformat file")
        folded.add(name.casefold())
        size = uint(row["bytes"], 64)
        total += size
        if total > MAX_BYTES or path.stat().st_size != size:
            raise MuseumError("multiformat package size mismatch")
        content = path.read_bytes()
        if sha256(content).digest() != hex_bytes(row["sha256"], 32) or keccak256(content) != row["keccak256"]:
            raise MuseumError("multiformat child hash mismatch")
        files[name] = content
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    if actual != set(files) | {"manifest.json"}:
        raise MuseumError("undeclared or missing multiformat files")
    return raw, manifest, files


def verify_fixture_package(directory, expected_manifest_hash):
    """Check external fixity, then regenerate from only the archived inputs/dependencies."""
    directory = Path(directory).resolve()
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    pin_names = {"profile", "selection", "plan", "premis_plan", "iiif_plan", "lido_plan",
                 "validation", "vocabulary", "crosswalk", "premis_profile", "iiif_profile", "lido_profile"}
    if (not isinstance(manifest, dict)
            or set(manifest) != {"mode", "version", "formats", "sourceStateHash", "pins", "files", "claims"}
            or manifest["mode"] != "synthetic_candidate_resource_package" or manifest["version"] != "2"
            or manifest["formats"] != FORMATS or manifest["claims"] != CLAIMS
            or not isinstance(manifest["pins"], dict) or set(manifest["pins"]) != pin_names
            or not isinstance(manifest["files"], list) or len(manifest["files"]) > MAX_FILES):
        raise MuseumError("unsupported multiformat package manifest")
    for value in manifest["pins"].values():
        hex_bytes(value, 32)
    try:
        pins = manifest["pins"]
        rebuilt = build_fixture_package(fixture_state_from_bytes(files["inputs/source-state.json"]),
            *(files["inputs/" + name.replace("_", "-") + ".json"] for name in INPUTS),
            root=directory / "dependencies",
            **{name + "_hash": pins[name] for name in pin_names - {
                "crosswalk", "premis_profile", "iiif_profile", "lido_profile"}})
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("multiformat reconstruction input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("multiformat semantic reconstruction differs")
    return rebuilt


def verify_package(directory, expected_manifest_hash):
    """Dispatch only distinct v2 source modes; each verifier authenticates the full manifest."""
    path = _package_path(Path(directory).resolve(), "manifest.json")
    if path.stat().st_size > MAX_MANIFEST:
        raise MuseumError("multiformat manifest bound exceeded")
    value = loads(path.read_bytes(), maximum=MAX_MANIFEST, canonical=True)
    if isinstance(value, dict) and value.get("mode") == "public_conservation_capture":
        from .public_conservation_capture import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "acquisition_packet_assembly_v2":
        from .acquisition_packet_v2 import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "acquisition_accession_history":
        from .acquisition_accession import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "public_mint_entropy_capture":
        from .public_mint_entropy_capture import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "public_native_history_capture":
        from .public_history_capture import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "token_current_rights_examination":
        from .dossier_rights import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "token_mint_entropy_examination":
        from .dossier_mint_entropy import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "source_gathered_token_examination":
        from .dossier_gather import verify
        from .bagit import read_tree
        return verify(read_tree(directory), expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") in ("recorded_account_resource_package", "recorded_account_premis_resource_package", "recorded_account_iiif_resource_package", "recorded_account_lido_resource_package"):
        from .package_recorded import verify_recorded_package
        return verify_recorded_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_account_fixity_resource_package":
        from .fixity_package import verify_fixity_package
        return verify_fixity_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_owner_valuation_package":
        from .valuation_package import verify_valuation_package
        return verify_valuation_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_owner_loan_dossier_package":
        from .loan_package import verify_loan_package
        return verify_loan_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_institutional_documentation_package":
        from .institutional_package import verify_institutional_package
        return verify_institutional_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_institutional_transfer_package":
        from .institutional_transfer_package import verify_transfer_package
        return verify_transfer_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_condition_conservation_package":
        from .condition_package import verify_condition_package
        return verify_condition_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_account_authority_package":
        from .authority_package import verify_authority_package
        return verify_authority_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_account_authority_package_v2":
        from .authority_package_v2 import verify_authority_package
        return verify_authority_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_typed_account_semantic_export":
        from .semantic_export import verify_export
        return verify_export(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_independent_exhibition_package":
        from .exhibition_package import verify_exhibition_package
        return verify_exhibition_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_owner_exhibition_package":
        from .owner_exhibition_package import verify_owner_exhibition_package
        return verify_owner_exhibition_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_preservation_activity_graph_package":
        from .preservation_graph_package import verify_graph_package
        return verify_graph_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_preservation_resources_package":
        from .resource_package import verify_resource_package
        return verify_resource_package(directory, expected_manifest_hash)
    if isinstance(value, dict) and value.get("mode") == "recorded_account_preservation_resource_package":
        from .preservation_package import verify_preservation_package
        return verify_preservation_package(directory, expected_manifest_hash)
    return verify_fixture_package(directory, expected_manifest_hash)


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    verify = commands.add_parser("verify")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    build = commands.add_parser("build-fixture")
    build.add_argument("state", type=Path)
    for name in INPUTS:
        build.add_argument(name, type=Path)
    build.add_argument("directory", type=Path)
    build.add_argument("--dependency-root", type=Path, default=Path(__file__).resolve().parents[2] / "schemas/museum")
    for name in ("profile", *INPUTS, "validation", "vocabulary"):
        build.add_argument("--" + name.replace("_", "-") + "-hash", required=True)
    recorded = commands.add_parser("build-recorded", help="package an admitted public recorded-account capture")
    recorded.add_argument("input", type=Path)
    recorded.add_argument("directory", type=Path)
    recorded.add_argument("--disclosure", choices=("public", "restricted"), required=True)
    recorded.add_argument("--dependency-root", type=Path, default=Path(__file__).resolve().parents[2] / "schemas/museum")
    for name in ("source", "publication", "interpretation", "profile", "selection", "plan"):
        recorded.add_argument("--" + name + "-hash", required=True)
    recorded.add_argument("--premis-plan", type=Path)
    recorded.add_argument("--premis-plan-hash")
    recorded.add_argument("--premis-profile-hash")
    recorded.add_argument("--iiif-plan", type=Path)
    recorded.add_argument("--iiif-plan-hash")
    recorded.add_argument("--iiif-profile-hash")
    recorded.add_argument("--lido-plan", type=Path)
    recorded.add_argument("--lido-plan-hash")
    recorded.add_argument("--lido-profile-hash")
    args = parser.parse_args()
    try:
        if args.command == "verify":
            result = verify_package(args.directory, args.manifest_hash)
        elif args.command == "build-recorded":
            from .package_recorded import build_recorded_directory
            requested = (args.premis_plan, args.premis_plan_hash, args.premis_profile_hash)
            if any(v is not None for v in requested) and not all(v is not None for v in requested):
                raise MuseumError("recorded PREMIS requires plan, plan hash and profile hash together")
            extra = {}
            if args.premis_plan is not None:
                if args.disclosure != "public":
                    raise MuseumError("restricted export is unsupported")
                if args.premis_plan.stat().st_size > 524288:
                    raise MuseumError("recorded PREMIS plan byte bound")
                extra = dict(premis_plan_bytes=args.premis_plan.read_bytes(), premis_plan_hash=args.premis_plan_hash,
                             premis_profile_hash=args.premis_profile_hash)
            iiif_requested = (args.iiif_plan, args.iiif_plan_hash, args.iiif_profile_hash)
            if any(v is not None for v in iiif_requested):
                if not all(v is not None for v in iiif_requested) or args.premis_plan is None:
                    raise MuseumError("recorded IIIF requires PREMIS and IIIF plan with both pins")
                if args.disclosure != "public":
                    raise MuseumError("restricted export is unsupported")
                if args.iiif_plan.stat().st_size > 524288:
                    raise MuseumError("recorded IIIF plan byte bound")
                extra.update(iiif_plan_bytes=args.iiif_plan.read_bytes(), iiif_plan_hash=args.iiif_plan_hash,
                             iiif_profile_hash=args.iiif_profile_hash)
            lido_requested = (args.lido_plan, args.lido_plan_hash, args.lido_profile_hash)
            if any(v is not None for v in lido_requested):
                if not all(v is not None for v in lido_requested) or args.iiif_plan is None:
                    raise MuseumError("recorded LIDO requires IIIF and LIDO plan with both pins")
                if args.disclosure != "public":
                    raise MuseumError("restricted export is unsupported")
                if args.lido_plan.stat().st_size > 524288:
                    raise MuseumError("recorded LIDO plan byte bound")
                extra.update(lido_plan_bytes=args.lido_plan.read_bytes(), lido_plan_hash=args.lido_plan_hash,
                             lido_profile_hash=args.lido_profile_hash)
            result = build_recorded_directory(args.input, root=args.dependency_root, disclosure=args.disclosure, **extra,
                **{name + "_hash": getattr(args, name + "_hash")
                   for name in ("source", "publication", "interpretation", "profile", "selection", "plan")})
            write_package(result, args.directory)
        else:
            if args.state.stat().st_size > 64 * 1024 * 1024 or any(
                    getattr(args, name).stat().st_size > 524288 for name in INPUTS):
                raise MuseumError("multiformat CLI input bound")
            result = build_fixture_package(fixture_state_from_bytes(args.state.read_bytes()),
                *(getattr(args, name).read_bytes() for name in INPUTS), root=args.dependency_root,
                **{name + "_hash": getattr(args, name + "_hash")
                   for name in ("profile", *INPUTS, "validation", "vocabulary")})
            write_package(result, args.directory)
    except (MuseumError, OSError, KeyError, TypeError) as exc:
        parser.exit(1, str(exc) + "\n")
    print(loads(result.manifest, maximum=MAX_MANIFEST)["mode"], "v2", result.manifest_hash, len(result.files))


if __name__ == "__main__":
    main()
