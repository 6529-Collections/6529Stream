"""Explicit synthetic source examples; no supplied files or chain records implied."""

import argparse
from pathlib import Path

from .canonical import dumps
from .schemas import obj, arr, TEXT, IRI, enum

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/fixtures"


def documents():
    schema = obj({
        "fixtureMode": {"const": "synthetic_fixture"}, "scenario": TEXT,
        "workId": IRI, "title": TEXT, "creatorStatement": TEXT,
        "language": TEXT, "tokenId": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$"},
        "resources": arr(obj({"id": IRI, "kind": enum("digital_object", "physical_object", "information_object"),
                              "role": TEXT, "presence": enum("described_only", "received", "verified_archival"),
                              "filename": {"type": ["string", "null"]}, "dimensions": arr(obj({
                                  "scope": TEXT, "value": TEXT, "unit": TEXT, "precision": TEXT}))})),
        "events": arr(obj({"id": IRI, "kind": TEXT, "status": enum("planned", "completed", "cancelled", "unknown"),
                           "dateExpression": TEXT, "precision": TEXT, "participants": arr(TEXT)})),
        "places": arr(obj({"id": IRI, "statement": TEXT, "role": TEXT,
                           "alignment": {"type": ["string", "null"]}})),
        "statements": arr(obj({"author": TEXT, "subject": IRI, "relation": TEXT, "value": TEXT})),
        "optionalNote": {"type": ["string", "null"]}},
        ["fixtureMode", "scenario", "workId", "title", "creatorStatement", "language", "tokenId",
         "resources", "events", "places", "statements"])
    schema.update({"$schema": "https://json-schema.org/draft/2020-12/schema",
                   "$id": "urn:6529stream:fixture:museum-source-v1",
                   "description": "Synthetic input inventory. Not an allocated CMC family schema."})
    cases = {}
    scenarios = ("photograph", "written_interview", "av_interview", "software_interactive",
                 "disputed_geography", "incomplete_documentation", "independent_accounts", "offline_revision")
    for i, scenario in enumerate(scenarios):
        stem = "urn:uuid:00000000-0000-4000-8000-" + str(i + 1).zfill(12)
        cases[scenario] = {"fixtureMode": "synthetic_fixture", "scenario": scenario, "workId": stem,
                           "title": "Synthetic " + scenario, "creatorStatement": "The contributor's original words.\nNo normalization.",
                           "language": "en", "tokenId": str((1 << 256) - 1),
                           "resources": [], "events": [], "places": [], "statements": []}
    photo = cases["photograph"]
    for i, (kind, role, filename) in enumerate((("digital_object", "master", "master.tiff"),
                       ("digital_object", "display_derivative", "display.jpg"),
                       ("physical_object", "reference_print", None), ("physical_object", "reference_print", None))):
        photo["resources"].append({"id": "urn:example:photo-resource:" + str(i), "kind": kind, "role": role,
                                  "presence": "described_only", "filename": filename,
                                  "dimensions": [{"scope": "pixel_width" if i < 2 else "image_width",
                                      "value": "6000" if i < 2 else "40.00", "unit": "px" if i < 2 else "cm",
                                      "precision": "source lexical"}]})
    for kind, date in (("capture", "2026-05-18"), ("completion", "2026-05-24"), ("printing", "May 2026")):
        photo["events"].append({"id": "urn:example:event:" + kind, "kind": kind, "status": "completed",
                                 "dateExpression": date, "precision": "month" if kind == "printing" else "day",
                                 "participants": ["Synthetic Artist"]})
    for name in ("written_interview", "av_interview"):
        for role in (("instrument", "transcript") if name == "written_interview" else ("instrument", "recording", "transcript", "captions")):
            cases[name]["resources"].append({"id": "urn:example:" + name + ":" + role, "kind": "digital_object",
                                            "role": role, "presence": "described_only", "filename": role + ".example",
                                            "dimensions": []})
        cases[name]["events"].append({"id": "urn:example:" + name + ":event", "kind": "interview", "status": "completed",
                                      "dateExpression": "2 June 2026", "precision": "day", "participants": ["Synthetic Artist", "Synthetic Interviewer"]})
    for role in ("code", "dependency", "environment", "reference_output", "preservation_evidence"):
        cases["software_interactive"]["resources"].append({"id": "urn:example:software:" + role, "kind": "digital_object",
                                     "role": role, "presence": "described_only", "filename": role, "dimensions": []})
    geo = cases["disputed_geography"]
    geo["places"] = [{"id": "urn:example:place:island", "statement": "Milos, Greece", "role": "capture_location", "alignment": None}]
    geo["statements"] = [{"author": "Synthetic Artist", "subject": "urn:example:place:island", "relation": "name", "value": "Milos, Greece"},
                         {"author": "Synthetic Curator", "subject": "urn:example:place:island", "relation": "alternative", "value": "Exact site unknown"}]
    for name in ("incomplete_documentation", "independent_accounts"):
        cases[name]["statements"] = [{"author": author, "subject": "urn:example:print:one", "relation": "custody_location", "value": place}
                                     for author, place in (("Synthetic Artist", "Studio"), ("Synthetic Curator", "Storage"))]
    cases["incomplete_documentation"]["resources"] = [photo["resources"][0]]
    cases["offline_revision"]["optionalNote"] = None
    return {"source.schema.json": schema, **{name + ".json": value for name, value in cases.items()}}


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--check", action="store_true")
    args = p.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, value in documents().items():
        data, target = dumps(value), ROOT / name
        if args.check:
            if not target.exists() or target.read_bytes() != data:
                raise SystemExit("stale fixture " + name)
        else:
            target.write_bytes(data)


if __name__ == "__main__":
    main()
