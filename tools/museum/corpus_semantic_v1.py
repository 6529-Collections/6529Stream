"""Conservative Linked Art V2 projection of three synthetic corpus scenarios.

This is a fixture adapter. Its source/sidecar provenance is not a signed
STREAM_SEMANTIC_ASSERTION record or a completed museum dossier.
"""

from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads
from .corpus_v2 import verify as verify_corpus
from .coverage import inventory, verify_coverage
from .fixtures_v2 import ARTIST, INTERVIEWER
from .package import ResourcePackage, write_package
from .package_v2 import _assemble, _dependencies, _read_package
from .projection import CONTEXT
from .projection_v2 import CROSSWALK_V2_HASH, ProjectionProfileV2


MODEL_ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
CASES = ("photograph", "written_interview", "av_interview")
MODE = "synthetic_media_history_semantic_projection_v1"
SOURCE_SCHEMA_HASH = "0x052724ed357f286d28d15113a37d2d8f007487205b2f815817f7ef1d11ae35fe"
VALIDATION_HASH = "0xc5dfe8227e65a2012b707b3d669ec9c4712e1a4e8b3441556b9f8c67da38e19d"
VOCABULARY_HASH = "0xd56f4d9fdb72ea1eddcb6542c2fe0a52761d6837914f11b3bf0876ec2bd64faf"
CROSSWALK_PATH = "definitions/crosswalk-v2.json"


def _profile(root, crosswalk_bytes):
    if type(crosswalk_bytes) is not bytes or keccak256(crosswalk_bytes) != CROSSWALK_V2_HASH:
        raise MuseumError("semantic corpus crosswalk hash differs")
    validation = (root / "linked-art-v2/validation-policy.json").read_bytes()
    vocabulary = (root / "standards/vocabulary-policy.json").read_bytes()
    if keccak256(validation) != VALIDATION_HASH or keccak256(vocabulary) != VOCABULARY_HASH:
        raise MuseumError("semantic corpus model policy hash differs")
    return ProjectionProfileV2(root, crosswalk_bytes, crosswalk_hash=CROSSWALK_V2_HASH,
        validation_hash=VALIDATION_HASH, vocabulary_hash=VOCABULARY_HASH)


def _project(name, source, schema, profile):
    """Map only exact source identities and supported relations, retaining all else."""
    if name not in CASES or source.get("scenario") != name:
        raise MuseumError("semantic corpus scenario differs")
    fields = inventory(schema, source)
    source_hash = keccak256(dumps(source))
    resources, provenance, mapped = {}, [], set()

    def evidence(identifier, target, pointer, rule):
        provenance.append({"entity": identifier, "targetPointer": target,
                           "sourcePointer": pointer, "sourceHash": source_hash,
                           "rule": rule, "authority": "synthetic fixture; unauthenticated"})
        mapped.add(pointer)

    def add(identifier, kind, label, id_pointer, kind_pointer, label_pointer, rule):
        if identifier in resources:
            raise MuseumError("duplicate semantic corpus entity")
        resources[identifier] = {"@context": CONTEXT, "id": identifier, "type": kind, "_label": label}
        for target, pointer in (("/id", id_pointer), ("/type", kind_pointer), ("/_label", label_pointer)):
            evidence(identifier, target, pointer, rule)

    if name == "photograph":
        content = source["contentId"]
        add(content, "VisualItem", source["title"], "/contentId", "/scenario", "/title",
            "fixture-v2:photograph-visual-content")

    for i, row in enumerate(source["resources"]):
        kind = {"digital_object": "DigitalObject", "physical_object": "HumanMadeObject"}.get(row["kind"])
        if kind is None:
            continue
        pointer = "/resources/" + str(i)
        add(row["id"], kind, row["role"], pointer + "/id", pointer + "/kind",
            pointer + "/role", "fixture-v2:carrier-kind")

    if name == "photograph":
        content = source["contentId"]
        for i, row in enumerate(source["relationships"]):
            field = {"digitally_shows": "digitally_shows", "physically_shows": "shows"}.get(row["relation"])
            carrier = resources.get(row["subject"])
            if field is None or carrier is None:
                continue
            expected = "DigitalObject" if field == "digitally_shows" else "HumanMadeObject"
            if carrier["type"] != expected or row["object"] != content:
                raise MuseumError("visual carrier relationship kind differs")
            carrier[field] = [{"id": content, "type": "VisualItem"}]
            pointer = "/relationships/" + str(i)
            evidence(row["subject"], "/" + field + "/0", pointer + "/subject",
                     "fixture-v2:visual-carrier-relation")
            evidence(row["subject"], "/" + field + "/0/id", pointer + "/object",
                     "fixture-v2:visual-carrier-relation")
            evidence(row["subject"], "/" + field + "/0/type", pointer + "/relation",
                     "fixture-v2:visual-carrier-relation")

    else:
        people = sorted({row["participant"] for row in source["participantRoles"]})
        if set(people) != {ARTIST, INTERVIEWER}:
            raise MuseumError("fixture interview participant kinds unestablished")
        for person in people:
            pointer = next("/participantRoles/" + str(i) + "/participant"
                           for i, row in enumerate(source["participantRoles"])
                           if row["participant"] == person)
            add(person, "Person", person, pointer, pointer, pointer,
                "fixture-v2:participant-identity-only")
        for i, event in enumerate(source["events"]):
            if event["kind"] != "interview" or event["status"] != "completed":
                continue
            pointer = "/events/" + str(i)
            add(event["id"], "Activity", event["kind"], pointer + "/id",
                pointer + "/kind", pointer + "/kind", "fixture-v2:completed-interview")
            participants = sorted({row["participant"] for row in source["participantRoles"]
                                   if row["event"] == event["id"]})
            resources[event["id"]]["carried_out_by"] = [
                {"id": person, "type": "Person"} for person in participants]
            for j, person in enumerate(participants):
                original = next(k for k, row in enumerate(source["participantRoles"])
                                if row["event"] == event["id"] and row["participant"] == person)
                evidence(event["id"], "/carried_out_by/" + str(j) + "/id",
                         "/participantRoles/" + str(original) + "/participant",
                         "fixture-v2:activity-participant-identity")
                evidence(event["id"], "/carried_out_by/" + str(j),
                         "/participantRoles/" + str(original) + "/event",
                         "fixture-v2:activity-participant-event")

    encoded = {}
    for identifier, resource in sorted(resources.items()):
        raw = dumps(resource)
        checked = profile.linked_art.validate_and_expand(raw)
        encoded[identifier] = (raw, checked.expanded_bytes)
    coverage = [{"pointer": field.pointer, "presence": field.presence,
                 "exactHex": "0x" + field.exact.hex(),
                 "disposition": "mapped" if field.pointer in mapped else "retained_stream_only",
                 "rule": "fixture-v2:linked-art-v2" if field.pointer in mapped else "fixture-v2:source-retention",
                 "reason": "exact source pointer has a supported target" if field.pointer in mapped
                           else "original source retained; no stronger target claim"} for field in fields]
    verify_coverage(fields, coverage)
    if {row["sourcePointer"] for row in provenance} != mapped:
        raise MuseumError("semantic corpus provenance and coverage differ")
    return encoded, dumps(coverage), dumps(sorted(provenance, key=dumps))


def build(corpus_directory: Path, corpus_hash: str, model_root: Path = MODEL_ROOT,
          *, crosswalk_bytes: bytes | None = None) -> ResourcePackage:
    corpus_directory, model_root = Path(corpus_directory).resolve(), Path(model_root).resolve()
    verify_corpus(corpus_directory, corpus_hash)
    if crosswalk_bytes is None:
        crosswalk_bytes = (model_root / "projection/crosswalk-v2.json").read_bytes()
    profile = _profile(model_root, crosswalk_bytes)
    files = _dependencies(model_root, recorded=True)
    files[CROSSWALK_PATH] = crosswalk_bytes
    for path in sorted(corpus_directory.rglob("*")):
        if path.is_file():
            files["input/corpus/" + path.relative_to(corpus_directory).as_posix()] = path.read_bytes()
    schema = loads(files["input/corpus/photograph/source/schema.json"], canonical=True)
    if keccak256(dumps(schema)) != SOURCE_SCHEMA_HASH:
        raise MuseumError("semantic corpus source schema hash differs")
    index = []
    for name in CASES:
        source = loads(files["input/corpus/" + name + "/source/payload.json"], canonical=True)
        encoded, coverage, provenance = _project(name, source, schema, profile)
        files["semantic/" + name + "/coverage.json"] = coverage
        files["semantic/" + name + "/provenance.json"] = provenance
        files["semantic/" + name + "/sidecar.json"] = dumps({
            "sourceHash": keccak256(dumps(source)), "sourcePath": "input/corpus/" + name + "/source/payload.json",
            "qualification": "Synthetic source; no signer, receipt, received media or institutional review."})
        for identifier, (raw, expanded) in sorted(encoded.items()):
            stem = keccak256(identifier.encode("utf-8"))[2:]
            path = "semantic/" + name + "/resources/" + stem + ".json"
            expanded_path = "semantic/" + name + "/expanded/" + stem + ".json"
            files[path], files[expanded_path] = raw, expanded
            index.append({"scenario": name, "id": identifier, "path": path,
                          "expandedPath": expanded_path})
    files["semantic/entity-index.json"] = dumps(sorted(index, key=lambda row: (row["scenario"], row["id"])))
    files["semantic/report.json"] = dumps({"corpusManifestHash": corpus_hash,
        "sourceSchemaId": schema["$id"], "sourceSchemaHash": keccak256(dumps(schema)),
        "projectionProfile": loads(profile.identity), "crosswalkVersion": "2",
        "crosswalkHash": CROSSWALK_V2_HASH, "scenarios": list(CASES),
        "completeness": "incomplete", "claims": {"recordedState": False,
            "receivedMedia": False, "fullMuseumConformance": False,
            "institutionalAcceptance": False}})
    return _assemble(model_root, files, {"mode": MODE, "version": "1",
        "corpusManifestHash": corpus_hash, "crosswalkHash": CROSSWALK_V2_HASH,
        "claims": {"authenticatedChainState": False, "fullMuseumScope": False,
                   "institutionalAcceptance": False}})


def verify(directory: Path, expected_manifest_hash: str) -> ResourcePackage:
    directory = Path(directory)
    raw, manifest, files = _read_package(directory, expected_manifest_hash)
    if (manifest.get("mode") != MODE or manifest.get("version") != "1"
            or manifest.get("crosswalkHash") != CROSSWALK_V2_HASH):
        raise MuseumError("semantic corpus package profile differs")
    try:
        crosswalk_bytes = files[CROSSWALK_PATH]
    except KeyError as exc:
        raise MuseumError("semantic corpus retained crosswalk missing") from exc
    rebuilt = build(directory / "input/corpus", manifest["corpusManifestHash"],
                    directory / "dependencies", crosswalk_bytes=crosswalk_bytes)
    if rebuilt.manifest != raw or dict(rebuilt.files) != files:
        raise MuseumError("semantic corpus reconstruction differs")
    return rebuilt


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    make = sub.add_parser("build"); make.add_argument("corpus", type=Path)
    make.add_argument("output", type=Path); make.add_argument("--corpus-hash", required=True)
    check = sub.add_parser("verify"); check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "build":
        package = build(args.corpus, args.corpus_hash)
        write_package(package, args.output)
        print(package.manifest_hash)
    else:
        print(verify(args.directory, args.manifest_hash).manifest_hash)


if __name__ == "__main__":
    main()
