"""Pinned offline archive of the eight synthetic media/history source fixtures."""

import argparse
from pathlib import Path

from .canonical import MuseumError, dumps, keccak256, loads
from .fixtures_v2 import ROOT, SCENARIOS
from .preview import fixture_package, verify_fixture_package, write_package


MANIFEST = "corpus-manifest.json"


def build(destination: Path, source: Path = ROOT) -> str:
    destination, source = Path(destination), Path(source)
    if destination.exists():
        raise MuseumError("corpus output already exists")
    schema = (source / "source.schema.json").read_bytes()
    destination.mkdir(parents=True)
    rows = []
    for scenario in SCENARIOS:
        original = (source / (scenario + ".json")).read_bytes()
        package = fixture_package(schema, original)
        write_package(destination / scenario, package)
        rows.append({"scenario": scenario, "schemaHash": keccak256(schema),
                     "sourceHash": keccak256(original),
                     "packageHash": keccak256(package["manifest.json"])})
    raw = dumps({"mode": "synthetic_media_history_corpus", "version": "2",
                 "sourceSchemaId": "urn:6529stream:fixture:museum-source-v2",
                 "cases": rows, "claims": {"recordedState": False,
                                         "targetProjection": False,
                                         "institutionalAcceptance": False}})
    (destination / MANIFEST).write_bytes(raw)
    return keccak256(raw)


def verify(directory: Path, expected_hash: str) -> dict:
    directory = Path(directory)
    manifest_path = directory / MANIFEST
    if manifest_path.stat().st_size > 8192:
        raise MuseumError("corpus manifest limit")
    raw = manifest_path.read_bytes()
    if keccak256(raw) != expected_hash:
        raise MuseumError("corpus external manifest hash mismatch")
    manifest = loads(raw, maximum=8192, canonical=True)
    if (not isinstance(manifest, dict)
            or set(manifest) != {"mode", "version", "sourceSchemaId", "cases", "claims"}
            or manifest["mode"] != "synthetic_media_history_corpus" or manifest["version"] != "2"
            or manifest["sourceSchemaId"] != "urn:6529stream:fixture:museum-source-v2"
            or manifest["claims"] != {"recordedState": False, "targetProjection": False,
                                       "institutionalAcceptance": False}
            or not isinstance(manifest["cases"], list)
            or not all(isinstance(row, dict) for row in manifest["cases"])
            or [row.get("scenario") for row in manifest["cases"]] != list(SCENARIOS)):
        raise MuseumError("invalid corpus manifest")
    if {path.name for path in directory.iterdir()} != set(SCENARIOS) | {MANIFEST}:
        raise MuseumError("corpus file set differs")
    schema_hash = None
    for row in manifest["cases"]:
        if set(row) != {"scenario", "schemaHash", "sourceHash", "packageHash"}:
            raise MuseumError("invalid corpus case row")
        name = row["scenario"]
        folder = directory / name
        verified = verify_fixture_package(folder, row["packageHash"])
        if verified["scenario"] != name:
            raise MuseumError("corpus scenario mismatch")
        schema = (folder / "source/schema.json").read_bytes()
        source = (folder / "source/payload.json").read_bytes()
        if (keccak256(schema) != row["schemaHash"] or keccak256(source) != row["sourceHash"]
                or loads(schema, canonical=True).get("$id") != manifest["sourceSchemaId"]):
            raise MuseumError("corpus source or schema pin differs")
        if schema_hash is None:
            schema_hash = row["schemaHash"]
        elif schema_hash != row["schemaHash"]:
            raise MuseumError("corpus cases use different schema bytes")
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    make = sub.add_parser("build")
    make.add_argument("destination", type=Path)
    make.add_argument("--source", type=Path, default=ROOT)
    check = sub.add_parser("verify")
    check.add_argument("directory", type=Path)
    check.add_argument("--manifest-hash", required=True)
    args = parser.parse_args()
    if args.command == "build":
        print(build(args.destination, args.source))
    else:
        verify(args.directory, args.manifest_hash)
        print(args.manifest_hash)


if __name__ == "__main__":
    main()
