"""Closed public-fixture supplement for typed WORK to LIDO; no authority promotion."""

import jsonschema

from tools.metadata import work_profile as work
from .canonical import MuseumError, dumps, keccak256, loads
from .linked_art import format_checker
from .lido_pins import DOCUMENT_SHA256, INDEX_SHA256
from .lido_model import SCHEMA_URI
from .work_lido_source import WORK_SCHEMA_HASH, WORK_PROFILE_HASH, _inventory

MAX_CONTEXT_BYTES = 32768


def context_schema():
    uri = {**work.text(2048), "format": "uri"}
    language = {**work.text(16), "pattern": "^" + work.LANG + "$"}
    base = {"authorId": uri}
    def statement(kind, fields):
        return work.closed({**base, "kind": {"const": kind}, **fields})
    text = {"value": work.text(1024), "language": language}
    return {"$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "STREAM_WORK_LIDO_FIXTURE_CONTEXT_V1", **work.closed({
            "mode": {"const": "public_fixture_work_lido"}, "version": {"const": "1"},
            "subjectId": work.NH, "workPayloadHash": work.NH, "workId": uri, "recordId": uri,
            "sourceDeclaration": work.closed({"id": uri, "declaredAuthor": uri}),
            "statements": work.array({"oneOf": [
                statement("documentLanguage", {"value": language}),
                statement("objectWorkType", text),
                statement("workLabel", {**text, "target": {"const": "work"}}),
                statement("artistName", {**text, "artistId": work.NH,
                    "association": work.closed({"bindingGeneration": {**work.UINT, "x-stream-maximum": str((1 << 64) - 1)}, "bindingHash": work.NH})}),
                statement("exportPublisher", {"id": uri, "name": work.text(1024), "language": language})]}, 5)})}


def profile_document():
    return {"name": "STREAM_LIDO_PROFILE_V1", "version": "1", "status": "prospective_unregistered",
        "sourceSchemaHash": WORK_SCHEMA_HASH, "sourceProfileHash": WORK_PROFILE_HASH,
        "contextSchemaHash": keccak256(dumps(context_schema())),
        "source": "Complete canonical WORK payload and complete catalog witness; same subject and exact WORK interpretation hash. Public fixture source declaration is not an authenticated record selector.",
        "schema": {"uri": SCHEMA_URI, "sha256": DOCUMENT_SHA256[SCHEMA_URI], "dependencyIndexSha256": INDEX_SHA256,
            "validation": "Original offline LIDO1.1 XSD closure, unchanged. Existing synthetic-assertion profile is reused only to instantiate its pinned XSD validator; it does not define this mapping."},
        "context": "Entire canonical context is retained and externally hash-pinned. Each statement declares its author. One statement per kind; duplicates, inactive fields and unused work labels/artist names reject. No signature, account identity, truth or current selection inferred.",
        "language": "Explicit documentLanguage covers original WORK primary text without its own tag; supplied context texts and every WORK language variant retain their own exact tag. No inferred work/creator language, no normalization. Generated controlled labels use en.",
        "absence": "description_absent remains absence. Without independently declared work label (target work), object type, document language and export publisher: accounted no-XML. With all four: catalogue-work-label plus absence reason/date, no invented creator, creation, medium, edition or credit.",
        "creator": "Named uses original name. Artist requires independently declared name bound to exact artistId/generation/bindingHash. IDs and authority references remain claims, not proof of current signer, creator truth or authority match.",
        "fields": "All titles/ordered alternate titles/variants, creator, exact dates, medium/authority roles, digital format, dimensions and unreduced rationals, edition, credit and inscription description are mapped. Every actual source node and applicable absent optional has a disposition and exact canonical bytes. Unselected catalog entries and control/association metadata remain sidecars.",
        "format": "PRONOM scheme and exact PUID or catalog-selected full-spec URI/hash are descriptive technical statements only. No resource, MIME, format detection, fetched bytes or preservation fixity event inferred.",
        "datesQuantities": "Gregorian exact date or inclusive range; indexed dates preserve original lexical dates. Pixel integers are decimal strings; ratios and duration use exact numerator/denominator display without float conversion/reduction. Serial edition preserves exact number and total.",
        "xml": "UTF8 XML1.0; illegal characters reject, no strip/replacement. All provenance paths resolve after complete siblings and reparse. 4MiB/depth64/elements32768 original validator bounds.",
        "limits": {"workBytes": "8192", "catalogBytes": "8192", "contextBytes": str(MAX_CONTEXT_BYTES), "outputBytesEach": "4194304"},
        "remaining": ["authenticated WORK selection/source adapter and creator/association authority", "registered LIDO interpretation", "media/resources and cross-format record joins", "institutional ingest", "full Museum scope"]}


PROFILE_BYTES = dumps(profile_document())
PROFILE_HASH = keccak256(PROFILE_BYTES)


def load_context(raw, *, expected_hash, source):
    if keccak256(raw) != expected_hash:
        raise MuseumError("WORK LIDO context hash mismatch")
    value = loads(raw, maximum=MAX_CONTEXT_BYTES, canonical=True)
    try:
        jsonschema.Draft202012Validator(context_schema(), format_checker=format_checker()).validate(value)
        work._pattern_checks(value, context_schema())
    except (jsonschema.ValidationError, work.WorkError) as exc:
        raise MuseumError("WORK LIDO context schema rejected") from exc
    if value["subjectId"] != source.subject_id or value["workPayloadHash"] != source.payload_hash:
        raise MuseumError("WORK LIDO context source binding")
    ids = [value["workId"], value["recordId"], value["sourceDeclaration"]["id"]]
    if len(set(ids)) != len(ids):
        raise MuseumError("WORK LIDO work/record/source identity collision")
    statements = {}
    for i, statement in enumerate(value["statements"]):
        kind = statement["kind"]
        if kind in statements:
            raise MuseumError("WORK LIDO duplicate/conflicting context statement")
        # Uri validity does not establish an entity class or actual authorship.
        if statement["authorId"] in ids or kind == "exportPublisher" and statement["id"] in ids:
            raise MuseumError("WORK LIDO author/publisher identity collision")
        statements[kind] = (statement, "/statements/" + str(i))
    if value["sourceDeclaration"]["declaredAuthor"] in ids:
        raise MuseumError("WORK LIDO source author identity collision")
    v = loads(source.payload, maximum=8192)
    if source.form == "full":
        if "workLabel" in statements:
            raise MuseumError("WORK LIDO unused work label")
        creator = v["creator"]
        if creator["kind"] == "named" and "artistName" in statements:
            raise MuseumError("WORK LIDO unused artist name")
        if creator["kind"] == "artist" and "artistName" in statements:
            name = statements["artistName"][0]
            if name["artistId"] != creator["artistId"] or name["association"] != creator["association"]:
                raise MuseumError("WORK LIDO artist association mismatch")
    elif "artistName" in statements:
        raise MuseumError("WORK LIDO absent description cannot acquire artist")
    fields, branches = _inventory(value, context_schema(), "context", keccak256(dumps(context_schema())))
    return value, statements, fields, branches
