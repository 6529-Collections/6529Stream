"""Bounded public geography assertions and qualified Linked Art fragments.

This module is deliberately a pure projector.  It validates canonical source
bytes and retains them verbatim, but it does not authenticate record selectors,
reviewers, authority snapshots, or the historical truth of a statement.  A
recorded-source adapter owns those joins.
"""

from datetime import datetime
import re
from urllib.parse import urlsplit

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .linked_art import format_checker
from .preservation_graph import CONTEXT, VALIDATION_HASH
from .schemas import IRI, TEXT, arr, definitions, enum, obj
from .validation import StreamValidator


NAME = "STREAM_MUSEUM_GEOGRAPHY_V1"
MODE = "draft_preview_public_geography_projection"
RULE = "urn:6529stream:museum:geography:v1:"
MAX_INPUT_BYTES = 524288
MAX_PLACES = 64
MAX_ASSOCIATIONS = 256
ZERO = "0x" + "00" * 32
QUALIFICATION = (
    "Source-attributed public geography statement; historical accuracy, real-world "
    "identity, authority-snapshot authenticity, reviewer identity and exact position "
    "are not independently established by this projection."
)
CLAIMS = {
    "historicalAccuracyProven": False,
    "realWorldIdentityProven": False,
    "authoritySnapshotAuthenticated": False,
    "reviewerIdentityProven": False,
    "exactPositionInferred": False,
    "modernSovereigntyInferred": False,
    "privateMaterialAccepted": False,
    "institutionalConformance": False,
    "linkedArtApiConformance": False,
    "registeredExport": False,
}

PLACE_CLASSES = {
    "continent": "continent",
    "country": "country",
    "administrative_area": "administrative area",
    "region": "region",
    "island": "island",
    "settlement": "settlement",
    "site": "site",
    "building": "building",
    "landform": "landform",
    "water_body": "body of water",
    "fictional_place": "fictional place",
    "unidentified_place": "unidentified place",
}
PLACE_CLASS_PREFIX = "urn:6529stream:museum:place-classification:v1:"

ROLES = (
    "capture_location",
    "creation_location",
    "depicted_place",
    "subject_place",
    "production_location",
    "interview_location",
    "exhibition_location",
    "custody_location",
    "publication_location",
)
EVENT_ROLES = frozenset(ROLES) - {"depicted_place", "subject_place"}
ROLE_TARGET = {role: ("Activity", "took_place_at") for role in EVENT_ROLES} | {
    "creation_location": ("Creation", "took_place_at"),
    "production_location": ("Production", "took_place_at"),
    "depicted_place": ("VisualItem", "represents"),
    "subject_place": ("LinguisticObject", "about"),
}
SUBJECT_TYPES = ("Activity", "Creation", "Production", "VisualItem", "LinguisticObject",
    "DigitalObject", "HumanMadeObject", "Set", "Place", "Person", "Group")
ROLE_TYPES = {role: frozenset({kind}) for role, (kind, _) in ROLE_TARGET.items()}
ROLE_TYPES["creation_location"] = frozenset({"Activity", "Creation"})
ROLE_TYPES["production_location"] = frozenset({"Activity", "Production"})


def nullable(schema):
    return {"oneOf": [schema, {"type": "null"}]}


def documents():
    """Return the closed candidate input schema; this does not register it."""
    defs = definitions()
    source = obj({"record": defs["selector"], "path": {
        "type": "string", "pattern": "^(/([^~]|~[01])*)*$", "maxLength": 2048},
        "assertionId": nullable(IRI)})
    date = defs["date"]
    named = obj({"value": dict(TEXT, minLength=1), "kind": enum("preferred", "alternate", "historical"),
        "language": nullable({"type": "string", "minLength": 1, "maxLength": 128}),
        "applicableDate": nullable(date), "source": source})
    statement = obj({"value": dict(TEXT, minLength=1),
        "language": nullable({"type": "string", "minLength": 1, "maxLength": 128}),
        "applicableDate": nullable(date), "source": source})
    classification = obj({"code": enum(*PLACE_CLASSES), "id": IRI,
        "label": dict(TEXT, minLength=1), "applicableDate": nullable(date), "source": source})
    hierarchy = obj({"kind": enum("spatial_containment", "catalog_hierarchy", "political_affiliation"),
        "parentPlaceId": IRI, "context": dict(TEXT, minLength=1),
        "applicableDate": nullable(date), "source": source})
    geometry = obj({"kind": enum("point", "centroid", "bounding_box", "geometry_reference"),
        "representation": dict(TEXT, minLength=1), "crs": IRI,
        "precision": dict(TEXT, minLength=1), "uncertainty": dict(TEXT, minLength=1),
        "applicableDate": nullable(date), "source": source})
    snapshot_value = obj({"path": {"type": "string", "pattern": "^(/([^~]|~[01])*)*$", "maxLength": 2048},
        "value": TEXT})
    snapshot_hierarchy = obj({"identifier": dict(TEXT, minLength=1),
        "relationship": dict(TEXT, minLength=1), "sourceValue": dict(TEXT, minLength=1),
        "applicableDate": nullable(date)})
    snapshot = obj({"labels": arr(named, 1, 32), "types": arr(snapshot_value, 1, 32),
        "hierarchies": arr(snapshot_hierarchy, maximum=64),
        "otherValues": arr(snapshot_value, maximum=64),
        "sourceAttribution": dict(TEXT, minLength=1), "reuseTerms": dict(TEXT, minLength=1)})
    basis = obj({"rationale": dict(TEXT, minLength=1), "evidenceSelectors": arr(source, 1, 16),
        "author": IRI, "reviewer": nullable(IRI), "status": enum("unreviewed", "reviewed"),
        "origin": enum("human_mapping", "automated_suggestion"),
        "entityTypeChecked": {"type": "boolean"}, "geographicContextChecked": {"type": "boolean"}})
    alignment = obj({"assertionId": IRI, "entityId": IRI, "authority": enum("GETTY_TGN"),
        "identifier": {"type": "string", "pattern": "^[1-9][0-9]*$", "maxLength": 32},
        "canonicalIri": IRI, "focusIri": nullable(IRI),
        "matchKind": enum("equivalent_entity", "close_match", "related_reference"),
        "disposition": enum("active", "superseded", "disputed", "withdrawn"),
        "supersedes": nullable(IRI),
        "snapshotRef": defs["document"], "retrievedAt": {"type": "string", "format": "date-time"},
        "authorityRevision": dict(TEXT, minLength=1), "labelAtReview": named,
        "snapshotValues": snapshot, "basis": basis})
    place = obj({"entityId": IRI, "nature": enum("real", "fictional", "unidentified"),
        "publicPrecision": enum("named_place", "broad_region", "geometry_as_supplied"),
        "source": source,
        "preferredName": named, "alternateNames": arr(named, maximum=32),
        "contexts": arr(statement, 1, 32), "classifications": arr(classification, 1, 16),
        "sourceReferences": arr(defs["document"], 1, 32),
        "hierarchies": arr(hierarchy, maximum=32), "geometry": nullable(geometry),
        "authorityAlignments": arr(alignment, maximum=16)})
    association = obj({"associationId": IRI, "placeId": IRI, "subjectId": IRI,
        "subjectType": enum(*SUBJECT_TYPES),
        "role": enum(*ROLES), "context": dict(TEXT, minLength=1),
        "applicableDate": nullable(date), "source": source})
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "$defs": defs,
        "title": NAME, "description": "Bounded public place statements; selectors are not authenticated by shape validation.",
        **obj({"version": enum("1"), "places": arr(place, 1, MAX_PLACES),
            "associations": arr(association, maximum=MAX_ASSOCIATIONS)})}


SCHEMA_BYTES = dumps(documents())
SCHEMA_HASH = keccak256(SCHEMA_BYTES)
PROFILE_BYTES = dumps({
    "id": "STREAM_MUSEUM_QUALIFIED_GEOGRAPHY_PROFILE_V1",
    "version": "1",
    "status": "prospective_unregistered_export_profile",
    "sourceSchema": NAME,
    "sourceSchemaHash": SCHEMA_HASH,
    "validationPolicyHash": VALIDATION_HASH,
    "context": CONTEXT,
    "bounds": {"inputBytes": str(MAX_INPUT_BYTES), "places": str(MAX_PLACES),
        "associations": str(MAX_ASSOCIATIONS), "alternateNamesPerPlace": "32",
        "contextsPerPlace": "32", "classificationsPerPlace": "16",
        "hierarchiesPerPlace": "32", "alignmentsPerPlace": "16",
        "authoritySnapshotLabels": "32", "authoritySnapshotTypes": "32",
        "authoritySnapshotHierarchies": "64", "authoritySnapshotOtherValues": "64"},
    "roles": list(ROLES),
    "rules": {
        "role": "All nine baseline roles are closed and typed. Creation and production retain Creation/Production or an exact generic Activity; other event roles use Activity and took_place_at; depiction uses VisualItem/represents; LinguisticObject subject matter uses about. Other typed combinations remain Stream-only with an explicit reason.",
        "names": "Preferred, alternate and historical names retain language, applicable date and source. Projection copies exact text only.",
        "hierarchy": "Only asserted spatial containment projects as part_of. Catalog hierarchy and political affiliation remain separately typed Stream assertions.",
        "geometry": "Geometry is public-only and retained exactly with representation, CRS, precision, uncertainty, source and date. No point or centroid is inferred.",
        "authority": "Every caller-supplied GETTY_TGN alignment remains attributed Stream-only. A separate authenticated adapter must validate review eligibility and retain exact snapshot bytes before any Linked Art equivalent can be emitted.",
        "coverage": "Every scalar, null and empty collection in the canonical source receives exactly one mapped or retained_stream_only row.",
        "trust": QUALIFICATION,
    },
    "claims": CLAIMS,
})
PROFILE_HASH = keccak256(PROFILE_BYTES)


def need(condition, message):
    if not condition:
        raise MuseumError("geography " + message)


def _iri(value):
    need(format_checker().conforms(value, "uri"), "invalid absolute IRI")


def _local_place_iri(value):
    _iri(value)
    parsed = urlsplit(value)
    # Local entities and authority concepts/foci/accounts are different things.
    # A direct authority ID would bypass the deliberately withheld alignment.
    host = (parsed.hostname or "").lower()
    need(not value.casefold().startswith(("eip155:", "urn:6529stream:account:", PLACE_CLASS_PREFIX))
        and host not in ("vocab.getty.edu", "www.wikidata.org", "wikidata.org", "viaf.org", "www.viaf.org"),
        "local place cannot use authority/account/classification identity")


def _source(value):
    _iri(value["assertionId"]) if value["assertionId"] is not None else None
    need(value["record"]["recordHash"] != ZERO, "source record hash missing")


def _document(value):
    path = value["path"]
    need(path and not path.startswith(("/", "\\")) and ".." not in path.replace("\\", "/").split("/"),
        "unsafe or empty archived document path")
    need(uint(value["byteLength"]) > 0, "archived document byte length missing")
    ref = value["contentHash"]
    need(uint(ref["algorithm"], 16) != 0 and ref["canonicalizationId"] != ZERO
        and any(hex_bytes(ref["digest"])), "archived document commitment missing")


def _instant(value):
    need(isinstance(value, str) and re.fullmatch(
        r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z", value),
        "invalid Gregorian UTC date")
    try:
        return datetime.strptime(value, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError as exc:
        raise MuseumError("geography invalid Gregorian UTC date") from exc


def _date(value):
    if value is None:
        return
    early, late = value["earliest"], value["latest"]
    if value["precision"] == "unknown":
        need(early is None and late is None, "unknown date cannot contain bounds")
    else:
        need(early is not None and late is not None, "known date requires both bounds")
    if value["precision"] == "exact":
        need(early == late, "exact date cannot be a range")
    if early is not None and value["calendar"] == "gregorian" and value["timezone"] == "UTC":
        need(_instant(early) <= _instant(late), "date bounds reversed")


def fields(value, path=""):
    """Yield all coverage leaves, including nulls and empty containers."""
    if isinstance(value, dict) and value:
        for key, item in value.items():
            yield from fields(item, path + "/" + key.replace("~", "~0").replace("/", "~1"))
    elif isinstance(value, list) and value:
        for index, item in enumerate(value):
            yield from fields(item, path + "/" + str(index))
    else:
        yield path, value


def _all_sources(place):
    sources = [place["source"], place["preferredName"]["source"]]
    sources += [row["source"] for row in place["alternateNames"]]
    sources += [row["source"] for row in place["contexts"]]
    sources += [row["source"] for row in place["classifications"]]
    sources += [row["source"] for row in place["hierarchies"]]
    if place["geometry"] is not None:
        sources.append(place["geometry"]["source"])
    for alignment in place["authorityAlignments"]:
        sources += alignment["basis"]["evidenceSelectors"]
        sources.append(alignment["labelAtReview"]["source"])
        sources += [row["source"] for row in alignment["snapshotValues"]["labels"]]
    return sorted({dumps(row): row for row in sources}.values(), key=dumps)


def admit(value):
    """Validate semantic invariants after exact schema admission."""
    place_ids, association_ids = set(), set()
    for place in value["places"]:
        identifier = place["entityId"]
        _local_place_iri(identifier)
        need(identifier not in place_ids, "duplicate place identity")
        place_ids.add(identifier)
        need(place["preferredName"]["kind"] == "preferred"
            and all(row["kind"] in ("alternate", "historical") for row in place["alternateNames"]),
            "preferred/alternate name role differs")
        for source in _all_sources(place):
            _source(source)
        for row in [place["preferredName"], *place["alternateNames"], *place["contexts"], *place["classifications"]]:
            _date(row["applicableDate"])
        for reference in place["sourceReferences"]:
            _document(reference)
        codes = set()
        for classification in place["classifications"]:
            code = classification["code"]
            need(classification["id"] == PLACE_CLASS_PREFIX + code
                and classification["label"] == PLACE_CLASSES[code], "unsupported place classification")
            need(code not in codes, "duplicate place classification")
            codes.add(code)
        if place["nature"] == "fictional":
            need("fictional_place" in codes, "fictional place classification required")
        elif place["nature"] == "unidentified":
            need("unidentified_place" in codes, "unidentified place classification required")
        else:
            need(not ({"fictional_place", "unidentified_place"} & codes), "real place classification contradiction")
        geometry = place["geometry"]
        need((geometry is not None) == (place["publicPrecision"] == "geometry_as_supplied"),
            "public precision and geometry differ")
        if geometry is not None:
            need(place["nature"] == "real", "fictional or unidentified geometry refused")
            _iri(geometry["crs"]); _date(geometry["applicableDate"]); _source(geometry["source"])
        for hierarchy in place["hierarchies"]:
            _iri(hierarchy["parentPlaceId"]); _date(hierarchy["applicableDate"]); _source(hierarchy["source"])
            need(hierarchy["parentPlaceId"] != identifier, "self hierarchy refused")
        alignment_ids = set()
        for alignment in place["authorityAlignments"]:
            need(place["nature"] == "real", "authority match for fictional or unidentified place refused")
            _iri(alignment["assertionId"])
            need(alignment["assertionId"] not in alignment_ids, "duplicate authority assertion identity")
            alignment_ids.add(alignment["assertionId"])
            if alignment["supersedes"] is not None:
                _iri(alignment["supersedes"])
                need(alignment["supersedes"] != alignment["assertionId"], "authority assertion cannot supersede itself")
            need(alignment["entityId"] == identifier, "authority alignment entity differs")
            expected = "http://vocab.getty.edu/tgn/" + alignment["identifier"]
            need(alignment["canonicalIri"] == expected, "noncanonical Getty TGN entity IRI")
            if alignment["focusIri"] is not None:
                need(alignment["focusIri"] == expected + "-place", "noncanonical Getty TGN focus IRI")
            _document(alignment["snapshotRef"])
            _date(alignment["labelAtReview"]["applicableDate"])
            for label in alignment["snapshotValues"]["labels"]:
                _date(label["applicableDate"])
            reviewed_label = alignment["labelAtReview"]
            need(any((row["value"], row["language"]) == (reviewed_label["value"], reviewed_label["language"])
                for row in alignment["snapshotValues"]["labels"]), "reviewed label absent from authority snapshot")
            for relation in alignment["snapshotValues"]["hierarchies"]:
                _date(relation["applicableDate"])
            basis = alignment["basis"]
            for source in basis["evidenceSelectors"]:
                _source(source)
            if basis["origin"] == "automated_suggestion":
                need(basis["status"] == "unreviewed", "automated suggestion must start unreviewed")
            if basis["status"] == "reviewed":
                need(basis["reviewer"] is not None and basis["entityTypeChecked"]
                    and basis["geographicContextChecked"], "reviewed match lacks reviewer or checks")
    hierarchy_edges = {kind: {} for kind in ("spatial_containment", "catalog_hierarchy", "political_affiliation")}
    for place in value["places"]:
        for hierarchy in place["hierarchies"]:
            need(hierarchy["parentPlaceId"] in place_ids, "hierarchy parent place unavailable")
            edges = hierarchy_edges[hierarchy["kind"]].setdefault(place["entityId"], set())
            need(hierarchy["parentPlaceId"] not in edges, "duplicate hierarchy assertion")
            edges.add(hierarchy["parentPlaceId"])
    for kind, edges in hierarchy_edges.items():
        def visit(node, active, complete):
            need(node not in active, kind + " hierarchy cycle")
            if node in complete:
                return
            active.add(node)
            for parent in edges.get(node, ()):
                visit(parent, active, complete)
            active.remove(node); complete.add(node)
        complete = set()
        for node in edges:
            visit(node, set(), complete)
    kinds = {identifier: "Place" for identifier in place_ids}
    for place in value["places"]:
        for classification in place["classifications"]:
            identifier = classification["id"]
            need(identifier not in kinds or kinds[identifier] == "Type", "classification identity collision")
            kinds[identifier] = "Type"
    for association in value["associations"]:
        _iri(association["associationId"]); _iri(association["subjectId"]); _source(association["source"])
        _date(association["applicableDate"])
        need(association["associationId"] not in association_ids, "duplicate association identity")
        association_ids.add(association["associationId"])
        need(association["placeId"] in place_ids, "association place unavailable")
        identifier, kind = association["subjectId"], association["subjectType"]
        need(identifier not in kinds or kinds[identifier] == kind, "conflicting association subject kind")
        kinds[identifier] = kind
    need(not (association_ids & set(kinds)), "association identity collides with entity")
    return value


def _mapped_path(path, spatial_hierarchies, mapped_associations):
    if path == "/version":
        return True
    association = re.match(r"^/associations/([0-9]+)(?:/|$)", path)
    if association:
        return int(association.group(1)) in mapped_associations
    match = re.match(r"^/places/([0-9]+)/(.*)$", path)
    if not match:
        return False
    place_index, tail = int(match.group(1)), match.group(2)
    if tail == "entityId" or tail == "preferredName/value":
        return True
    if re.fullmatch(r"alternateNames/[0-9]+/value", tail) or re.fullmatch(r"contexts/[0-9]+/value", tail):
        return True
    if re.fullmatch(r"classifications/[0-9]+/(code|id|label)", tail):
        return True
    hierarchy = re.match(r"hierarchies/([0-9]+)/(kind|parentPlaceId)$", tail)
    if hierarchy and (place_index, int(hierarchy.group(1))) in spatial_hierarchies:
        return True
    return False


def render(value, linked_art):
    """Render admitted values with exact sidecar/coverage and validated Places."""
    files, resources, provenance = {}, [], []
    spatial_hierarchies = set()

    def emit(resource, origins, rule):
        raw = dumps(resource)
        expanded = linked_art.validate_and_expand(raw)
        key = keccak256(resource["id"].encode("utf-8"))[2:]
        path = "geography/resources/" + key + ".json"
        need(path not in files or files[path] == raw, "conflicting projected resource identity")
        if path not in files:
            files[path] = raw
            files["geography/expanded/" + key + ".json"] = expanded.expanded_bytes
            resources.append({"id": resource["id"], "type": resource["type"], "path": path})
        for pointer, scalar in fields(resource):
            matches = [(prefix, evidence) for prefix, evidence in origins.items()
                if not prefix or pointer == prefix or pointer.startswith(prefix + "/")]
            prefix, evidence = max(matches, key=lambda row: len(row[0]))
            provenance.append({"entity": resource["id"], "path": pointer, "value": scalar,
                "sourcePaths": evidence[0], "sources": evidence[1], "rule": RULE + evidence[2],
                "qualification": QUALIFICATION})

    used_classes = {}
    for place_index, place in enumerate(value["places"]):
        item = {"@context": CONTEXT, "id": place["entityId"], "type": "Place",
            "_label": place["preferredName"]["value"],
            "identified_by": [{"type": "Name", "content": row["value"]}
                for row in [place["preferredName"], *place["alternateNames"]]],
            "classified_as": [{"id": row["id"], "type": "Type", "_label": row["label"]}
                for row in place["classifications"]],
            "referred_to_by": [{"type": "LinguisticObject", "content": row["value"]}
                for row in place["contexts"]] + [{"type": "LinguisticObject", "content": QUALIFICATION}]}
        origins = {"": ([f"/places/{place_index}/entityId", f"/places/{place_index}/nature",
            f"/places/{place_index}/publicPrecision", f"/places/{place_index}/source"],
            [place["source"]], "place")}
        origins["/_label"] = ([f"/places/{place_index}/preferredName/value"],
            [place["preferredName"]["source"]], "name")
        for name_index, row in enumerate([place["preferredName"], *place["alternateNames"]]):
            source_index = "preferredName" if name_index == 0 else f"alternateNames/{name_index - 1}"
            origins[f"/identified_by/{name_index}"] = ([f"/places/{place_index}/{source_index}"], [row["source"]], "name")
        for context_index, row in enumerate(place["contexts"]):
            origins[f"/referred_to_by/{context_index}"] = ([f"/places/{place_index}/contexts/{context_index}"],
                [row["source"]], "context")
        for class_index, class_row in enumerate(place["classifications"]):
            origins[f"/classified_as/{class_index}"] = ([f"/places/{place_index}/classifications/{class_index}"],
                [class_row["source"]], "classification")
            used_classes.setdefault(class_row["code"], []).append((place_index, class_index, class_row))
        parents = []
        for hierarchy_index, hierarchy in enumerate(place["hierarchies"]):
            if hierarchy["kind"] == "spatial_containment":
                parents.append({"id": hierarchy["parentPlaceId"], "type": "Place"})
                spatial_hierarchies.add((place_index, hierarchy_index))
                origins[f"/part_of/{len(parents) - 1}"] = ([f"/places/{place_index}/hierarchies/{hierarchy_index}"],
                    [hierarchy["source"]], "spatial-containment")
        if parents:
            item["part_of"] = parents
        emit(item, origins, "place")

    for code in sorted(used_classes):
        occurrences = used_classes[code]
        row = occurrences[0][2]
        emit({"@context": CONTEXT, "id": row["id"], "type": "Type", "_label": row["label"]},
            {"": ([f"/places/{place_index}/classifications/{class_index}"
                for place_index, class_index, _ in occurrences],
                sorted({dumps(item[2]["source"]): item[2]["source"] for item in occurrences}.values(), key=dumps),
                "classification")}, "classification")

    relations, unsupported, mapped_associations = [], [], set()
    for association_index, association in enumerate(value["associations"]):
        _, prop = ROLE_TARGET[association["role"]]
        supported = association["subjectType"] in ROLE_TYPES[association["role"]]
        if supported:
            mapped_associations.add(association_index)
        relations.append({"associationId": association["associationId"],
            "subject": {"id": association["subjectId"], "type": association["subjectType"]},
            "property": prop if supported else None,
            "object": {"id": association["placeId"], "type": "Place"},
            "role": association["role"], "context": association["context"],
            "applicableDate": association["applicableDate"], "source": association["source"],
            "disposition": "mapped" if supported else "retained_stream_only",
            "reason": None if supported else "The typed subject/role combination has no faithful property in this pinned baseline.",
            "qualification": QUALIFICATION})
        if not supported:
            unsupported.append({"kind": "place_association", "placeId": association["placeId"],
                "sourcePath": f"/associations/{association_index}", "value": association,
                "disposition": "retained_stream_only",
                "reason": "The typed subject/role combination has no faithful property in this pinned baseline."})
    for place_index, place in enumerate(value["places"]):
        if place["geometry"] is not None:
            unsupported.append({"kind": "geometry", "placeId": place["entityId"],
                "sourcePath": f"/places/{place_index}/geometry", "value": place["geometry"],
                "disposition": "retained_stream_only",
                "reason": "The pinned graph profile has no registered geometry projection; exact public geometry remains typed in the source."})
        for index, hierarchy in enumerate(place["hierarchies"]):
            if hierarchy["kind"] != "spatial_containment":
                unsupported.append({"kind": hierarchy["kind"], "placeId": place["entityId"],
                    "sourcePath": f"/places/{place_index}/hierarchies/{index}", "value": hierarchy,
                    "disposition": "retained_stream_only",
                    "reason": "Catalog and political relationships do not establish physical containment or present sovereignty."})
        for index, alignment in enumerate(place["authorityAlignments"]):
            unsupported.append({"kind": "authority_alignment", "placeId": place["entityId"],
                "sourcePath": f"/places/{place_index}/authorityAlignments/{index}", "value": alignment,
                "disposition": "retained_stream_only",
                "reason": "Pure draft input does not authenticate reviewer eligibility or retain the exact authority snapshot bytes required for a Linked Art identity relationship."})

    coverage = []
    for path, scalar in fields(value):
        mapped = _mapped_path(path, spatial_hierarchies, mapped_associations)
        coverage.append({"sourcePath": path, "value": scalar,
            "disposition": "mapped" if mapped else "retained_stream_only",
            "rule": RULE + ("projection" if mapped else "source-retention"),
            "reason": None if mapped else "Exact source value retained without a faithful pinned graph property."})
    files["geography/source.json"] = dumps(value)
    files["geography/index.json"] = dumps({"resources": sorted(resources, key=lambda row: row["id"])})
    files["geography/relations.json"] = dumps(sorted(relations, key=lambda row: row["associationId"]))
    files["geography/provenance.json"] = dumps(provenance)
    files["geography/coverage.json"] = dumps(coverage)
    files["geography/sidecar.json"] = dumps({"unsupported": unsupported,
        "sourceHash": keccak256(files["geography/source.json"]), "qualification": QUALIFICATION})
    files["geography/report.json"] = dumps({"mode": MODE, "version": "1", "status": "draft_preview",
        "profileHash": PROFILE_HASH, "validationPolicyHash": VALIDATION_HASH,
        "places": str(len(value["places"])), "associations": str(len(relations)),
        "sourceValues": str(len(coverage)), "unsupportedAssertions": str(len(unsupported)),
        "qualification": QUALIFICATION, "claims": CLAIMS})
    return files


def project(source_bytes, linked_art):
    """Validate canonical bounded input and return deterministic projection bytes."""
    need(isinstance(source_bytes, bytes) and 0 < len(source_bytes) <= MAX_INPUT_BYTES, "input byte bound")
    value = loads(source_bytes, maximum=MAX_INPUT_BYTES, canonical=True)
    schema = loads(SCHEMA_BYTES, maximum=MAX_INPUT_BYTES, canonical=True)
    error = next(StreamValidator(schema, format_checker=format_checker()).iter_errors(value), None)
    if error:
        raise MuseumError("geography source schema rejection at " + error.json_path)
    need(dumps(value) == source_bytes, "source must use canonical JSON bytes")
    return render(admit(value), linked_art)


def main():
    import argparse
    from pathlib import Path
    parser = argparse.ArgumentParser(description="Generate/check prospective geography definitions; no registration.")
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2] / "schemas/museum/geography"
    for name, raw in ((NAME + ".json", SCHEMA_BYTES), ("profile.json", PROFILE_BYTES)):
        path = root / name
        if args.check:
            need(path.is_file() and path.read_bytes() == raw, "generated definition differs")
        else:
            root.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
    print(PROFILE_HASH)


if __name__ == "__main__":
    main()
