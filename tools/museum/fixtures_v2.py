"""Versioned, synthetic media/history corpus for offline source retention.

The v1 fixture documents remain immutable. These are illustrative statements,
not authenticated records, received files, or an institutional interpretation.
"""

import argparse
from copy import deepcopy
from pathlib import Path

from .canonical import dumps
from .fixtures import documents as v1_documents
from .schemas import IRI, TEXT, arr, enum, obj


ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/fixtures-v2"
SCENARIOS = ("photograph", "written_interview", "av_interview", "software_interactive",
             "disputed_geography", "incomplete_documentation", "independent_accounts", "offline_revision")
ARTIST = "urn:fixture:artist"
CURATOR = "urn:fixture:curator"
INTERVIEWER = "urn:fixture:interviewer"


def _schema():
    schema = deepcopy(v1_documents()["source.schema.json"])
    schema["$id"] = "urn:6529stream:fixture:museum-source-v2"
    schema["description"] = "Synthetic eight-scenario source corpus V2; not a registered CMC family or validated target projection."
    fields = schema["properties"]
    original_fields = set(fields)
    fields.update({
        "contentId": IRI,
        "relationships": arr(obj({"subject": IRI, "relation": TEXT, "object": IRI},
                                 ["subject", "relation", "object"])),
        "participantRoles": arr(obj({"event": IRI, "participant": IRI, "role": TEXT},
                                  ["event", "participant", "role"])),
        "mediaSegments": arr(obj({"resource": IRI, "start": TEXT, "end": TEXT,
                                  "speaker": IRI, "caption": TEXT},
                                  ["resource", "start", "end", "speaker", "caption"])),
        "duration": {"type": ["string", "null"]},
        "significantProperties": arr(obj({"subject": IRI, "property": TEXT, "value": TEXT},
                                         ["subject", "property", "value"])),
        "claims": arr(obj({"id": IRI, "author": IRI, "subject": IRI, "relation": TEXT,
                           "value": TEXT, "status": enum("asserted", "disputed", "withdrawn"),
                           "source": TEXT},
                          ["id", "author", "subject", "relation", "value", "status", "source"])),
        "authorityHistory": arr(obj({"id": IRI, "place": IRI, "authority": TEXT,
                                    "snapshot": TEXT, "match": TEXT,
                                    "status": enum("proposed", "rejected", "unreviewed"),
                                    "author": IRI},
                                    ["id", "place", "authority", "snapshot", "match", "status", "author"])),
        "revisions": arr(obj({"id": IRI, "prior": {"type": ["string", "null"]},
                              "author": IRI, "statement": TEXT},
                              ["id", "prior", "author", "statement"])),
    })
    schema["required"].extend(fields.keys() - original_fields)
    schema["required"].sort()
    return schema


def _claim(name, author, subject, relation, value, status="asserted"):
    return {"id": "urn:fixture:claim:" + name, "author": author, "subject": subject,
            "relation": relation, "value": value, "status": status,
            "source": "synthetic authored example; identity not authenticated"}


def _link(subject, relation, target):
    return {"subject": subject, "relation": relation, "object": target}


def _dimension(scope, value, unit):
    return {"scope": scope, "value": value, "unit": unit, "precision": "source lexical"}


def documents():
    old = v1_documents()
    schema = _schema()
    cases = {name: deepcopy(old[name + ".json"]) for name in SCENARIOS}
    for case in cases.values():
        case.update(contentId=case["workId"] + ":content", relationships=[],
                    participantRoles=[], mediaSegments=[], duration=None,
                    significantProperties=[], claims=[], authorityHistory=[], revisions=[])

    photo = cases["photograph"]
    content = photo["contentId"]
    master, display, first, second = photo["resources"]
    master["dimensions"] = [_dimension("pixel_width", "6000", "px"), _dimension("pixel_height", "4000", "px")]
    display["dimensions"] = [_dimension("pixel_width", "1200", "px"), _dimension("pixel_height", "800", "px")]
    first["dimensions"] = [_dimension("image_width", "40.00", "cm"), _dimension("image_height", "26.67", "cm"),
                           _dimension("sheet_width", "50.00", "cm"), _dimension("sheet_height", "36.67", "cm")]
    second["dimensions"] = [_dimension("image_width", "30.00", "cm"), _dimension("image_height", "20.00", "cm"),
                            _dimension("sheet_width", "42.00", "cm"), _dimension("sheet_height", "32.00", "cm")]
    photo["relationships"] = [_link(photo["workId"], "has_visual_content", content),
        _link(master["id"], "digitally_shows", content), _link(display["id"], "derivative_of", master["id"]),
        _link(display["id"], "digitally_shows", content),
        *[_link(p["id"], "physically_shows", content) for p in (first, second)]]
    photo["participantRoles"] = [{"event": row["id"], "participant": ARTIST, "role": "maker"}
                                 for row in photo["events"]]

    for name in ("written_interview", "av_interview"):
        case = cases[name]
        event = case["events"][0]["id"]
        case["participantRoles"] = [{"event": event, "participant": ARTIST, "role": "interviewee"},
                                    {"event": event, "participant": INTERVIEWER, "role": "interviewer"}]
        case["relationships"] = [_link(case["workId"], "documented_by", row["id"])
                                 for row in case["resources"]]
        case["claims"] = [_claim(name + ":language", ARTIST, case["workId"], "interview_language", "en")]
    av = cases["av_interview"]
    av["duration"] = "PT00H02M30S"
    recording = next(row["id"] for row in av["resources"] if row["role"] == "recording")
    captions = next(row["id"] for row in av["resources"] if row["role"] == "captions")
    av["relationships"].append(_link(captions, "time_aligned_to", recording))
    av["mediaSegments"] = [{"resource": recording, "start": "PT00H00M10S", "end": "PT00H00M20S",
                            "speaker": ARTIST, "caption": "Synthetic artist response."}]

    software = cases["software_interactive"]
    software["events"] = [{"id": "urn:fixture:software:execution", "kind": "execution",
                           "status": "completed", "dateExpression": "2026-06-03", "precision": "day",
                           "participants": ["Synthetic Artist"]}]
    software["participantRoles"] = [{"event": software["events"][0]["id"],
                                     "participant": ARTIST, "role": "operator"}]
    code, dependency, environment, output, preservation = software["resources"]
    software["relationships"] = [_link(code["id"], "requires_dependency", dependency["id"]),
        _link(code["id"], "requires_environment", environment["id"]),
        _link(output["id"], "reference_output_of", code["id"]),
        _link(preservation["id"], "documents_preservation_of", code["id"])]
    software["significantProperties"] = [{"subject": software["workId"],
        "property": "interaction", "value": "viewer input changes the rendered state"},
        {"subject": environment["id"], "property": "runtime", "value": "synthetic pinned runtime example"}]

    geo = cases["disputed_geography"]
    place = geo["places"][0]["id"]
    geo["places"][0]["statement"] = "Milos (historical name supplied by artist); exact site unknown"
    geo["claims"] = [_claim("geo:artist", ARTIST, place, "capture_location", "Milos, Greece"),
                     _claim("geo:curator", CURATOR, place, "capture_location", "Exact site unknown", "disputed")]
    geo["authorityHistory"] = [{"id": "urn:fixture:alignment:proposed", "place": place,
        "authority": "synthetic TGN-style snapshot; not Getty data", "snapshot": "fixture snapshot A",
        "match": "Milos", "status": "proposed", "author": CURATOR},
        {"id": "urn:fixture:alignment:reconsidered", "place": place,
         "authority": "synthetic TGN-style snapshot; not Getty data", "snapshot": "fixture snapshot B",
         "match": "unresolved", "status": "rejected", "author": CURATOR}]
    geo["revisions"] = [{"id": "urn:fixture:geo:revision:1", "prior": None,
                         "author": ARTIST, "statement": "Milos, Greece"},
                        {"id": "urn:fixture:geo:revision:2", "prior": "urn:fixture:geo:revision:1",
                         "author": CURATOR, "statement": "Exact capture site remains unverified"}]

    incomplete = cases["incomplete_documentation"]
    incomplete["resources"][0]["id"] = "urn:example:incomplete:master"
    incomplete["resources"][0]["presence"] = "described_only"
    print_object = {"id": "urn:example:print:one", "kind": "physical_object",
                    "role": "reference_print", "presence": "described_only",
                    "filename": None, "dimensions": []}
    incomplete["resources"].append(deepcopy(print_object))
    incomplete["claims"] = [_claim("custody:artist", ARTIST, "urn:example:print:one", "custody_location", "Studio"),
                            _claim("custody:curator", CURATOR, "urn:example:print:one", "custody_location", "Storage", "disputed")]
    independent = cases["independent_accounts"]
    independent["resources"] = [deepcopy(print_object)]
    independent["claims"] = [_claim("independent:artist", ARTIST, "urn:example:print:one", "custody_location", "Studio"),
                             _claim("independent:curator", CURATOR, "urn:example:print:one", "custody_location", "Storage", "disputed")]
    independent["optionalNote"] = "Neither synthetic account authenticates or overrides the other."

    revision = cases["offline_revision"]
    revision["revisions"] = [{"id": "urn:fixture:revision:1", "prior": None,
                              "author": ARTIST, "statement": "Original wording."},
                             {"id": "urn:fixture:revision:2", "prior": "urn:fixture:revision:1",
                              "author": ARTIST, "statement": "Later wording; original remains retained."}]
    return {"source.schema.json": schema, **{name + ".json": cases[name] for name in SCENARIOS}}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    ROOT.mkdir(parents=True, exist_ok=True)
    for name, value in documents().items():
        raw, path = dumps(value), ROOT / name
        if args.check:
            if not path.exists() or path.read_bytes() != raw:
                raise SystemExit("stale fixture " + name)
        else:
            path.write_bytes(raw)


if __name__ == "__main__":
    main()
