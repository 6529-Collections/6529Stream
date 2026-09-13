"""Generate exact public WORK/LIDO examples and prospective profile documents."""

import argparse
import copy
from pathlib import Path

from tools.metadata import work_profile as work
from .canonical import MuseumError, dumps, keccak256
from .lido_model import PinnedLIDO, PROFILE_BYTES as XSD_PROFILE, PROFILE_HASH as XSD_HASH
from .work_lido import project_work_lido_fixture
from .work_lido_context import PROFILE_BYTES, PROFILE_HASH, context_schema
from .work_lido_source import WORK_PROFILE_HASH

ROOT = Path(__file__).resolve().parents[2]
DIRECTORY = "schemas/museum/work-lido"


def fixture_context(value):
    author = "urn:fixture:work-description-author"
    curator = "urn:fixture:cataloguer"
    statements = [
        {"kind": "documentLanguage", "authorId": curator, "value": "und"},
        {"kind": "objectWorkType", "authorId": curator, "value": "artwork", "language": "en"},
        {"kind": "exportPublisher", "authorId": "urn:fixture:publisher-declarant", "id": "urn:fixture:export-publisher",
         "name": "Public fixture export publisher", "language": "en"}]
    if value["form"] == "description_absent":
        statements.append({"kind": "workLabel", "authorId": curator, "target": "work", "value": "Catalogue label for this work", "language": "en"})
    elif value["creator"]["kind"] == "artist":
        statements.append({"kind": "artistName", "authorId": curator, "value": "Declared artist display name", "language": "und",
            "artistId": value["creator"]["artistId"], "association": copy.deepcopy(value["creator"]["association"])})
    return {"mode": "public_fixture_work_lido", "version": "1", "subjectId": value["subjectId"],
        "workPayloadHash": keccak256(dumps(value)), "workId": "urn:fixture:work", "recordId": "urn:fixture:lido-record",
        "sourceDeclaration": {"id": "urn:fixture:work-source", "declaredAuthor": author}, "statements": statements}


def examples():
    simple, absent, complete, catalog = work.examples()
    for value in (simple, absent, complete):
        value["profileHash"] = WORK_PROFILE_HASH
    # A separately authored XML-representable fixture, not a sanitizer for the
    # accepted complete WORK example (which deliberately contains U+0001).
    complete["title"] = 'Quote " <&> literal &amp; backslash \\ CR\rLF\n astral 🎨 é'
    context = fixture_context(absent)
    context["statements"] = []
    return {"simple": (simple, fixture_context(simple), None), "complete": (complete, fixture_context(complete), catalog),
            "absent": (absent, fixture_context(absent), None), "absent-no-xml": (absent, context, None)}


def outputs():
    model = PinnedLIDO(ROOT / "schemas/museum", XSD_PROFILE, profile_hash=XSD_HASH)
    result = {"profile.json": PROFILE_BYTES, "context-schema.json": dumps(context_schema())}
    for name, (value, context, catalog) in examples().items():
        payload, ctx = dumps(value), dumps(context)
        cat = None if catalog is None else dumps(catalog)
        projected = project_work_lido_fixture(payload, ctx, expected_subject_id=value["subjectId"], context_hash=keccak256(ctx),
            profile_bytes=PROFILE_BYTES, profile_hash=PROFILE_HASH, lido_schema=model, catalog_bytes=cat)
        result[name + "/work.json"] = payload
        result[name + "/context.json"] = ctx
        if cat is not None:
            result[name + "/catalog.json"] = cat
        for key in ("xml", "sidecar", "coverage", "provenance", "report"):
            raw = getattr(projected, key)
            if raw is not None:
                result[name + "/" + ("record.xml" if key == "xml" else key + ".json")] = raw
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    result = outputs()
    root = ROOT / DIRECTORY
    if args.check and {p.relative_to(root).as_posix() for p in root.rglob("*") if p.is_file()} != set(result):
        raise MuseumError("WORK LIDO exact output inventory mismatch")
    for name, raw in result.items():
        path = root / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise MuseumError("WORK LIDO generated output differs: " + name)
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(len(result), "exact public WORK/LIDO documents; profile", PROFILE_HASH)


if __name__ == "__main__":
    main()
