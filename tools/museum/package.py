"""Offline reconstruction of candidate, wholly public fixture projections.

The external manifest hash is the package integrity anchor. This format is not
an onchain export registration, a complete dossier, BagIt or an OCFL object.
"""

from dataclasses import dataclass
from hashlib import sha256
from pathlib import Path

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .dependencies import OfflineDocuments, safe_path
from .projection import CROSSWALK_BYTES, CROSSWALK_HASH, ProjectionProfile, project_fixture
from .source import FixtureSourceAdapter, RecordSelector, SourceRecord

MAX_FILES = 8192
MAX_BYTES = 96 * 1024 * 1024
MAX_MANIFEST = 2 * 1024 * 1024


def _package_path(root, name):
    if not isinstance(name, str) or len(name) > 4096:
        raise MuseumError("invalid package path")
    reserved = {"CON", "PRN", "AUX", "NUL"} | {prefix + str(n) for prefix in ("COM", "LPT") for n in range(1, 10)}
    if any(len(part) > 255 or part.split(".")[0].upper() in reserved for part in name.split("/")):
        raise MuseumError("nonportable package path")
    return safe_path(root, name)


@dataclass(frozen=True)
class ResourcePackage:
    files: tuple[tuple[str, bytes], ...]
    manifest: bytes

    @property
    def manifest_hash(self):
        return keccak256(self.manifest)


def fixture_state_bytes(state):
    if state.mode != "synthetic_fixture" or any(r.disclosure != "public" for r in state.records):
        raise MuseumError("candidate package requires a wholly public fixture; disclosed-state proofs are not implemented")
    identity = loads(state.identity, maximum=16 * 1024 * 1024, canonical=True)
    return dumps({"mode": "synthetic_fixture", "fixtureName": identity["fixtureName"],
        "identityHex": "0x" + state.identity.hex(), "records": [{"selector": r.selector.__dict__,
        "payloadHex": "0x" + r.payload.hex(), "payloadHash": r.payload_hash, "schemaHex": "0x" + r.schema.hex(),
        "authorityEvidenceHex": "0x" + r.authority_evidence.hex(), "disclosure": r.disclosure} for r in state.records]})


def fixture_state_from_bytes(raw):
    value = loads(raw, maximum=64 * 1024 * 1024, canonical=True)
    if (not isinstance(value, dict) or set(value) != {"mode", "fixtureName", "identityHex", "records"}
            or value["mode"] != "synthetic_fixture" or not isinstance(value["records"], list)
            or len(value["records"]) > 512):
        raise MuseumError("invalid candidate fixture state")
    records = []
    for row in value["records"]:
        if (not isinstance(row, dict) or set(row) != {"selector", "payloadHex", "payloadHash", "schemaHex",
                "authorityEvidenceHex", "disclosure"} or row["disclosure"] != "public"):
            raise MuseumError("invalid or restricted candidate source record")
        try:
            selector = RecordSelector(**row["selector"])
        except (TypeError, KeyError) as exc:
            raise MuseumError("invalid candidate record selector") from exc
        records.append(SourceRecord(selector, hex_bytes(row["payloadHex"]), row["payloadHash"],
                                    hex_bytes(row["schemaHex"]), hex_bytes(row["authorityEvidenceHex"]), "public"))
    state = FixtureSourceAdapter(value["fixtureName"], tuple(records)).snapshot()
    if state.identity != hex_bytes(value["identityHex"]):
        raise MuseumError("candidate source state commitment differs")
    return state


def _dependencies(root, validation_hash, vocabulary_hash):
    """Copy exact checked chunk bytes; never fetch a whole document over RPC."""
    files = {}
    for subroot, index_name, policy_name, expected in (
        (root, "linked-art/validation-index.json", "linked-art/validation-policy.json", validation_hash),
        (root / "standards", "vocabulary-index.json", "vocabulary-policy.json", vocabulary_hash),
    ):
        index_raw = (subroot / index_name).read_bytes()
        index = loads(index_raw, maximum=65536, canonical=True)
        policy_raw = (subroot / policy_name).read_bytes()
        if keccak256(policy_raw) != expected:
            raise MuseumError("package dependency policy differs")
        OfflineDocuments(subroot, index)
        for name, raw in ((index_name, index_raw), (policy_name, policy_raw)):
            relative = (subroot / name).relative_to(root).as_posix()
            files["dependencies/" + relative] = raw
        for row in index["documents"]:
            for chunk in row["chunks"]:
                path = safe_path(subroot, chunk["path"])
                raw = path.read_bytes()
                if len(raw) != uint(chunk["byteLength"], 32) or sha256(raw).digest() != hex_bytes(chunk["sha256"], 32):
                    raise MuseumError("dependency changed during package construction")
                name = "dependencies/" + path.relative_to(root.resolve()).as_posix()
                if name in files and files[name] != raw:
                    raise MuseumError("ambiguous package dependency path")
                files[name] = raw
    for name in ("standards/LICENSE.linked-art.txt", "fixtures/dependencies/LICENSE.linked-art.txt"):
        files["dependencies/" + name] = (root / name).read_bytes()
    return files


def build_fixture_package(state, selection_bytes, plan_bytes, *, root, profile_hash,
                          selection_hash, plan_hash, validation_hash, vocabulary_hash):
    root = Path(root).resolve()
    state_raw = fixture_state_bytes(state)
    # Verify that the serialized input reproduces the very same immutable state.
    if fixture_state_from_bytes(state_raw) != state:
        raise MuseumError("candidate state serialization differs")
    profile = ProjectionProfile(root, CROSSWALK_BYTES, crosswalk_hash=CROSSWALK_HASH,
                                validation_hash=validation_hash, vocabulary_hash=vocabulary_hash)
    projection = project_fixture(state, selection_bytes, plan_bytes, selection_hash=selection_hash,
                                  plan_hash=plan_hash, profile_hash=profile_hash, profile=profile)
    files = _dependencies(root, validation_hash, vocabulary_hash)
    files.update({"inputs/source-state.json": state_raw, "inputs/selection-policy.json": selection_bytes,
                  "inputs/projection-plan.json": plan_bytes, "definitions/crosswalk.json": CROSSWALK_BYTES,
                  "projection/report.json": projection.report, "projection/sidecar.json": projection.sidecar,
                  "projection/coverage.json": projection.coverage, "projection/provenance.json": projection.provenance})
    entity_index = []
    for resource in projection.resources:
        name = "entities/" + keccak256(resource.identifier.encode("utf-8"))[2:] + ".json"
        expansion = "expanded/" + keccak256(resource.identifier.encode("utf-8"))[2:] + ".json"
        if name in files or expansion in files:
            raise MuseumError("entity path collision")
        files[name], files[expansion] = resource.content, resource.expanded
        entity_index.append({"id": resource.identifier, "kind": "linked_art", "path": name, "expandedPath": expansion})
    for extension in loads(projection.sidecar, maximum=64 * 1024 * 1024)["extensionEntities"]:
        entity_index.append({"id": extension["id"], "kind": "stream_extension", "path": "projection/sidecar.json"})
    files["projection/entity-index.json"] = dumps(sorted(entity_index, key=lambda v: v["id"]))
    if len(files) > MAX_FILES or sum(map(len, files.values())) > MAX_BYTES:
        raise MuseumError("candidate package bounds exceeded")
    manifest = dumps({"mode": "synthetic_candidate_resource_package", "version": "1",
        "sourceStateHash": state.commitment, "profileHash": profile_hash, "selectionPolicyHash": selection_hash,
        "projectionPlanHash": plan_hash, "crosswalkHash": CROSSWALK_HASH,
        "validationPolicyHash": validation_hash, "vocabularyPolicyHash": vocabulary_hash,
        "files": [{"path": name, "bytes": str(len(raw)), "sha256": "0x" + sha256(raw).hexdigest(),
                   "keccak256": keccak256(raw)} for name, raw in sorted(files.items())],
        "claims": {"registered": False, "authenticatedChainState": False, "fullMuseumScope": False,
                   "archivedImplementation": False, "bagIt": False, "ocfl": False}})
    if len(manifest) > MAX_MANIFEST:
        raise MuseumError("candidate manifest bound exceeded")
    return ResourcePackage(tuple(sorted(files.items())), manifest)


def write_package(package, directory):
    """Create a new directory; publish the manifest only after all children."""
    directory = Path(directory).resolve()
    directory.mkdir(parents=True, exist_ok=False)
    for name, raw in package.files:
        target = _package_path(directory, name)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(raw)
    (directory / "manifest.json").write_bytes(package.manifest)


def verify_fixture_package(directory, expected_manifest_hash):
    directory = Path(directory).resolve()
    path = _package_path(directory, "manifest.json")
    if path.stat().st_size > MAX_MANIFEST:
        raise MuseumError("candidate manifest bound exceeded")
    raw = path.read_bytes()
    if keccak256(raw) != expected_manifest_hash:
        raise MuseumError("candidate manifest external hash mismatch")
    manifest = loads(raw, maximum=MAX_MANIFEST, canonical=True)
    fields = {"mode", "version", "sourceStateHash", "profileHash", "selectionPolicyHash", "projectionPlanHash",
              "crosswalkHash", "validationPolicyHash", "vocabularyPolicyHash", "files", "claims"}
    if (not isinstance(manifest, dict) or set(manifest) != fields
            or manifest["mode"] != "synthetic_candidate_resource_package" or manifest["version"] != "1"
            or not isinstance(manifest["files"], list) or len(manifest["files"]) > MAX_FILES):
        raise MuseumError("unsupported candidate package manifest")
    files, total, folded = {}, 0, set()
    for row in manifest["files"]:
        if not isinstance(row, dict) or set(row) != {"path", "bytes", "sha256", "keccak256"}:
            raise MuseumError("invalid candidate file row")
        name = row["path"]
        path = _package_path(directory, name)
        if name.casefold() in folded or name.casefold() == "manifest.json":
            raise MuseumError("duplicate or recursive candidate file")
        folded.add(name.casefold())
        size = uint(row["bytes"], 64)
        total += size
        if total > MAX_BYTES or path.stat().st_size != size:
            raise MuseumError("candidate package size mismatch")
        content = path.read_bytes()
        if sha256(content).digest() != hex_bytes(row["sha256"], 32) or keccak256(content) != row["keccak256"]:
            raise MuseumError("candidate child hash mismatch")
        files[name] = content
    actual = {p.relative_to(directory).as_posix() for p in directory.rglob("*") if p.is_file()}
    if actual != set(files) | {"manifest.json"}:
        raise MuseumError("undeclared or missing candidate files")
    try:
        state = fixture_state_from_bytes(files["inputs/source-state.json"])
        rebuilt = build_fixture_package(state, files["inputs/selection-policy.json"], files["inputs/projection-plan.json"],
            root=directory / "dependencies", profile_hash=manifest["profileHash"],
            selection_hash=manifest["selectionPolicyHash"], plan_hash=manifest["projectionPlanHash"],
            validation_hash=manifest["validationPolicyHash"], vocabulary_hash=manifest["vocabularyPolicyHash"])
    except (KeyError, FileNotFoundError) as exc:
        raise MuseumError("candidate reconstruction input missing") from exc
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("candidate semantic reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    verify = sub.add_parser("verify")
    verify.add_argument("directory", type=Path)
    verify.add_argument("--manifest-hash", required=True)
    build = sub.add_parser("build-fixture")
    build.add_argument("state", type=Path)
    build.add_argument("selection", type=Path)
    build.add_argument("plan", type=Path)
    build.add_argument("directory", type=Path)
    build.add_argument("--dependency-root", type=Path, default=Path(__file__).resolve().parents[2] / "schemas/museum")
    for name in ("profile", "selection", "plan", "validation", "vocabulary"):
        build.add_argument("--" + name + "-hash", required=True)
    args = parser.parse_args()
    if args.command == "verify":
        result = verify_fixture_package(args.directory, args.manifest_hash)
    else:
        for path, maximum in ((args.state, 64 * 1024 * 1024), (args.selection, 524288), (args.plan, 524288)):
            if path.stat().st_size > maximum:
                raise MuseumError("candidate CLI input size limit")
        result = build_fixture_package(fixture_state_from_bytes(args.state.read_bytes()), args.selection.read_bytes(),
            args.plan.read_bytes(), root=args.dependency_root, profile_hash=args.profile_hash,
            selection_hash=args.selection_hash, plan_hash=args.plan_hash,
            validation_hash=args.validation_hash, vocabulary_hash=args.vocabulary_hash)
        write_package(result, args.directory)
    print("synthetic_candidate_resource_package", result.manifest_hash, len(result.files))


if __name__ == "__main__":
    main()
