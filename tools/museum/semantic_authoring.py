"""Bounded offline capture and revision of museum semantic drafts.

The module preserves caller supplied text and identifiers.  It does not mint
identifiers, upload attachments, authenticate people, or publish Stream
records.  A later-documentation draft is usable only while its serialized
binding can be re-established from a concrete, externally pinned source.
"""

from copy import deepcopy
from datetime import datetime
import re
from urllib.parse import urlsplit

from jsonschema import FormatChecker

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, uint
from .linked_art import format_checker
from .schemas import HEX32, IRI, TEXT, arr, enum, obj
from .validation import StreamValidator


NAME = "STREAM_MUSEUM_SEMANTIC_AUTHORING_DRAFT_V1"
MODE = "draft_preview"
MAX_DRAFT_BYTES = 524288
ZERO = "0x" + "00" * 32

ENTITY_KINDS = (
    "abstract_work", "visual_content", "information_object", "token",
    "digital_object", "physical_object", "realization", "person", "group",
    "place", "event", "statement", "set",
)
RELATIONSHIPS = (
    "created_by", "carried_out_by", "member_of", "digitally_carries",
    "physically_carries", "digitally_shows", "shows", "derived_from",
    "documents", "has_component", "represented_by", "about",
)
ROLES = (
    "creator", "contributor", "interviewer", "interviewee", "registrar",
    "curator", "conservator", "master", "display_derivative", "print_output",
    "original_capture", "working_project", "transcript", "recording",
    "instrument", "dependency", "environment", "reference_render",
)
DATE_KINDS = (
    "creation", "capture", "completion", "production", "interview",
    "exhibition", "publication", "file_export", "mint", "accession",
)
MEASUREMENT_TYPES = (
    "pixel_width", "pixel_height", "sheet_width", "sheet_height",
    "image_area_width", "image_area_height", "duration", "file_size",
)
ATTACHMENT_ROLES = (
    "master", "display_derivative", "original_capture", "working_project",
    "color_profile", "print_preset", "transcript", "recording", "instrument",
    "care_instruction", "reference_render", "other_documentation",
)


def _nullable(schema):
    return {"oneOf": [schema, {"type": "null"}]}


def schema():
    """Return the complete closed candidate draft schema."""
    language = {"type": "string", "pattern": "^[A-Za-z]{2,8}(?:-[A-Za-z0-9]{1,8})*$", "maxLength": 64}
    instant = {"type": "string", "format": "date-time"}
    name = obj({"value": dict(TEXT, minLength=1), "language": language,
        "kind": enum("preferred", "alternate", "historical", "identifier")})
    actor = obj({"entityId": IRI, "kind": enum("person", "group"), "names": arr(name, 1, 16)})
    confirmation = obj({"confirmedBy": IRI, "confirmedAt": instant,
        "scope": {"const": "exact_source_version_only"},
        "basis": {"const": "platform_draft_confirmation_not_onchain_signature"}})
    source_version = obj({"versionId": IRI, "authorId": IRI,
        "originalText": dict(TEXT, minLength=1), "language": language,
        "status": enum("draft", "confirmed"), "versionHash": _nullable(HEX32),
        "confirmation": _nullable(confirmation)})
    entity = obj({"entityId": IRI, "kind": enum(*ENTITY_KINDS), "names": arr(name, maximum=32)})
    relationship = obj({"relationshipId": IRI, "type": enum(*RELATIONSHIPS),
        "subjectId": IRI, "objectId": IRI, "role": _nullable(enum(*ROLES)),
        "sourceVersionId": IRI, "mappedBy": IRI, "rationale": dict(TEXT, minLength=1)})
    date = obj({"dateId": IRI, "entityId": IRI, "kind": enum(*DATE_KINDS),
        "expression": dict(TEXT, minLength=1), "precision": enum("exact", "range", "approximate", "unknown"),
        "calendar": dict(TEXT, minLength=1), "timezone": _nullable(dict(TEXT, minLength=1)),
        "earliest": _nullable(instant), "latest": _nullable(instant),
        "sourceVersionId": IRI, "mappedBy": IRI})
    exact_value = {"oneOf": [
        obj({"kind": enum("integer"), "lexical": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 78}}),
        obj({"kind": enum("decimal"), "lexical": {"type": "string", "pattern": "^(0|[1-9][0-9]*)\\.[0-9]+$", "maxLength": 256}}),
        obj({"kind": enum("rational"), "numerator": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 78},
            "denominator": {"type": "string", "pattern": "^[1-9][0-9]*$", "maxLength": 78}}),
    ]}
    measurement = obj({"measurementId": IRI, "entityId": IRI,
        "type": enum(*MEASUREMENT_TYPES), "value": exact_value,
        "unit": enum("px", "mm", "cm", "m", "s", "ms", "B"),
        "precision": enum("exact", "source_lexical", "approximate"),
        "sourceVersionId": IRI, "mappedBy": IRI})
    attachment = obj({"attachmentId": IRI, "entityId": IRI,
        "role": enum(*ATTACHMENT_ROLES), "description": dict(TEXT, minLength=1),
        "language": language, "status": {"const": "described_only"},
        "sourceVersionId": IRI})
    no_match = obj({"decisionId": IRI, "entityId": IRI,
        "authority": enum("GETTY_TGN", "GETTY_AAT", "GETTY_ULAN", "VIAF", "WIKIDATA"),
        "status": {"const": "no_match"}, "reason": dict(TEXT, minLength=1),
        "decidedBy": IRI})
    review = obj({"reviewId": IRI, "reviewerId": IRI,
        "targetKind": enum("relationship", "date", "measurement", "authority_decision"),
        "targetId": IRI, "targetSnapshot": {"oneOf": [relationship, date, measurement, no_match]},
        "targetHash": HEX32,
        "status": enum("accepted", "changes_requested"),
        "reviewedAt": instant, "rationale": dict(TEXT, minLength=1)})
    selector = obj({"recordHash": HEX32, "subjectId": HEX32, "schemaId": HEX32,
        "schemaHash": HEX32, "recordType": HEX32,
        "host": {"type": "string", "pattern": "^0x[0-9a-f]{40}$"},
        "recorder": {"type": "string", "pattern": "^0x[0-9a-f]{40}$"},
        "authorizationClass": enum("ARTIST_SIGNER", "OWNER_SIGNER", "CURATOR_SIGNER",
            "INSTITUTION_SIGNER", "INDEPENDENT_ATTESTOR", "PRESERVATION_ADMIN", "METADATA_ADMIN", "GLOBAL_ADMIN"),
        "recordIndex": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 20},
        "recordChainHash": HEX32, "pointer": {"const": ""}})
    recorded_binding = obj({"kind": {"const": "recorded_semantic_source"},
        "sourceStateCommitment": HEX32, "anchorHash": HEX32,
        "sourceCaptureHash": HEX32, "publicationHash": HEX32,
        "interpretationHash": HEX32, "workCitation": IRI, "recordSelector": selector})
    owner_binding = obj({"kind": {"const": "owner_record_source"},
        "sourceSnapshotHash": HEX32, "anchorHash": HEX32, "recordHash": HEX32,
        "subjectId": HEX32, "schemaId": HEX32, "recordType": HEX32,
        "host": {"type": "string", "pattern": "^0x[0-9a-f]{40}$"},
        "owner": {"type": "string", "pattern": "^0x[0-9a-f]{40}$"},
        "recordIndex": {"type": "string", "pattern": "^(0|[1-9][0-9]*)$", "maxLength": 20},
        "recordChainHash": HEX32, "tokenId": {"type": "string", "pattern": "^[1-9][0-9]*$", "maxLength": 78},
        "workCitation": IRI})
    binding = {"oneOf": [recorded_binding, owner_binding]}
    return {"$schema": "https://json-schema.org/draft/2020-12/schema", "title": NAME,
        "description": "Offline draft only; shape validation establishes no authority or publication.",
        **obj({"version": {"const": "1"}, "draftId": IRI,
            "revision": {"type": "string", "pattern": "^[1-9][0-9]*$", "maxLength": 20},
            "previousRevisionHash": _nullable(HEX32),
            "purpose": enum("initial_submission", "later_documentation"), "workId": IRI,
            "recordBinding": _nullable(binding), "sourceAuthor": actor,
            "mappers": arr(actor, 1, 16), "reviewers": arr(actor, maximum=16),
            "sourceVersions": arr(source_version, 1, 32), "activeSourceVersionId": IRI,
            "entities": arr(entity, 1, 256), "relationships": arr(relationship, maximum=512),
            "dates": arr(date, maximum=128), "measurements": arr(measurement, maximum=256),
            "attachments": arr(attachment, maximum=128),
            "authorityDecisions": arr(no_match, maximum=128), "reviews": arr(review, maximum=128),
            "createdAt": instant, "revisedAt": instant})}


DRAFT_SCHEMA = schema()
SCHEMA_BYTES = dumps(DRAFT_SCHEMA)
SCHEMA_HASH = keccak256(SCHEMA_BYTES)


def need(condition, message):
    if not condition:
        raise MuseumError("semantic authoring " + message)


def _iri(value):
    need(format_checker().conforms(value, "uri"), "absolute IRI required")
    parsed = urlsplit(value)
    if parsed.scheme.lower() == "urn" and value.lower().startswith("urn:uuid:"):
        need(bool(re.fullmatch(r"urn:uuid:[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}", value)),
            "UUID IRI must be canonical lowercase RFC 4122")


def source_version_hash(version):
    """Hash the exact source authorship/text/language tuple."""
    body = {key: version[key] for key in ("versionId", "authorId", "originalText", "language")}
    return keccak256(dumps(body))


def _unique(rows, key, label):
    values = [row[key] for row in rows]
    need(len(values) == len(set(values)), "duplicate " + label)
    return set(values)


def _timestamp(value):
    need(isinstance(value, str) and value.endswith("Z"), "UTC timestamp required")
    try:
        return datetime.fromisoformat(value[:-1] + "+00:00")
    except ValueError as exc:
        raise MuseumError("semantic authoring invalid timestamp") from exc


def _check_value(value):
    kind = value["kind"]
    if kind in ("integer", "decimal"):
        lexical = value["lexical"]
        if kind == "integer":
            uint(lexical)
        else:
            whole, fraction = lexical.split(".")
            uint(whole)
            need(len(fraction) <= 128, "decimal fractional bound")
    else:
        uint(value["numerator"])
        need(uint(value["denominator"]) > 0, "rational denominator")


def _semantic(value, *, allow_unbound=False):
    all_iris = []
    _iri(value["draftId"]); all_iris.append(value["draftId"])
    _iri(value["workId"])
    _iri(value["activeSourceVersionId"])
    uint(value["revision"], 64)
    created, revised = _timestamp(value["createdAt"]), _timestamp(value["revisedAt"])
    need(created <= revised, "revision precedes creation")
    if value["revision"] == "1":
        need(value["previousRevisionHash"] is None, "first revision cannot have predecessor")
    else:
        need(value["previousRevisionHash"] not in (None, ZERO), "later revision predecessor missing")

    actors = [value["sourceAuthor"], *value["mappers"], *value["reviewers"]]
    _unique(value["mappers"], "entityId", "mapper identity")
    _unique(value["reviewers"], "entityId", "reviewer identity")
    declarations = {}
    for actor in actors:
        _iri(actor["entityId"])
        exact = dumps(actor)
        need(actor["entityId"] not in declarations or declarations[actor["entityId"]] == exact,
            "conflicting actor declaration across attribution roles")
        declarations[actor["entityId"]] = exact
    actor_ids = set(declarations)
    all_iris.extend(actor_ids)
    author_id = value["sourceAuthor"]["entityId"]
    mapper_ids = {row["entityId"] for row in value["mappers"]}
    reviewer_ids = {row["entityId"] for row in value["reviewers"]}

    versions = value["sourceVersions"]
    version_ids = _unique(versions, "versionId", "source version identity")
    need(value["activeSourceVersionId"] in version_ids, "active source version missing")
    for version in versions:
        _iri(version["versionId"]); all_iris.append(version["versionId"])
        need(version["authorId"] == author_id, "source version author differs")
        expected = source_version_hash(version)
        if version["status"] == "confirmed":
            confirmation = version["confirmation"]
            need(version["versionHash"] == expected and confirmation is not None
                and confirmation["confirmedBy"] == author_id,
                "confirmed source version hash/author differs")
            _timestamp(confirmation["confirmedAt"])
        else:
            need(version["versionHash"] is None and version["confirmation"] is None,
                "unconfirmed source cannot carry confirmation evidence")

    entities = value["entities"]
    entity_ids = _unique(entities, "entityId", "entity identity")
    need(value["workId"] in entity_ids, "work identity is not declared")
    need(not actor_ids & entity_ids, "actor/entity identity collision")
    for entity in entities:
        _iri(entity["entityId"]); all_iris.append(entity["entityId"])
    reference_ids = actor_ids | entity_ids

    typed = (("relationships", "relationshipId"), ("dates", "dateId"),
        ("measurements", "measurementId"), ("attachments", "attachmentId"),
        ("authorityDecisions", "decisionId"), ("reviews", "reviewId"))
    ids = {}
    for collection, key in typed:
        current = _unique(value[collection], key, collection + " identity")
        need(not current & set(ids), "cross-kind identity collision")
        for identifier in current:
            _iri(identifier); all_iris.append(identifier); ids[identifier] = collection
    for row in value["relationships"]:
        need(row["subjectId"] in reference_ids and row["objectId"] in reference_ids,
            "relationship has undeclared endpoint")
        need(row["sourceVersionId"] in version_ids and row["mappedBy"] in mapper_ids,
            "relationship source/mapper differs")
    for row in value["dates"]:
        need(row["entityId"] in entity_ids and row["sourceVersionId"] in version_ids
            and row["mappedBy"] in mapper_ids, "date scope/source/mapper differs")
        early, late = row["earliest"], row["latest"]
        if row["precision"] == "unknown":
            need(early is None and late is None, "unknown date cannot invent bounds")
        else:
            need(early is not None and late is not None and _timestamp(early) <= _timestamp(late),
                "dated statement needs ordered bounds")
            if row["precision"] == "exact":
                need(early == late, "exact date cannot be a range")
    for row in value["measurements"]:
        need(row["entityId"] in entity_ids and row["sourceVersionId"] in version_ids
            and row["mappedBy"] in mapper_ids, "measurement scope/source/mapper differs")
        _check_value(row["value"])
        allowed_units = {
            "pixel_width": {"px"}, "pixel_height": {"px"},
            "sheet_width": {"mm", "cm", "m"}, "sheet_height": {"mm", "cm", "m"},
            "image_area_width": {"mm", "cm", "m"}, "image_area_height": {"mm", "cm", "m"},
            "duration": {"s", "ms"}, "file_size": {"B"},
        }
        need(row["unit"] in allowed_units[row["type"]], "measurement type/unit differs")
    for row in value["attachments"]:
        need(row["entityId"] in entity_ids and row["sourceVersionId"] in version_ids,
            "attachment scope/source differs")
    for row in value["authorityDecisions"]:
        need(row["entityId"] in entity_ids and row["decidedBy"] in mapper_ids | reviewer_ids,
            "authority no-match entity/decider differs")
    for row in value["reviews"]:
        collection = {
            "relationship": "relationships", "date": "dates", "measurement": "measurements",
            "authority_decision": "authorityDecisions"}[row["targetKind"]]
        need(row["reviewerId"] in reviewer_ids and ids.get(row["targetId"]) == collection,
            "review target/reviewer differs")
        key = {"relationships": "relationshipId", "dates": "dateId", "measurements": "measurementId",
            "authorityDecisions": "decisionId"}[collection]
        snapshot = row["targetSnapshot"]
        need(snapshot.get(key) == row["targetId"] and row["targetHash"] == keccak256(dumps(snapshot)),
            "review target snapshot/hash differs")
        _timestamp(row["reviewedAt"])
    need(len(all_iris) == len(set(all_iris)), "IRI reused across typed identities")

    if value["purpose"] == "initial_submission":
        need(value["recordBinding"] is None, "initial draft cannot claim recorded binding")
    else:
        need(value["recordBinding"] is not None or allow_unbound, "later documentation binding missing")
        root = next(entity for entity in entities if entity["entityId"] == value["workId"])
        need(root["kind"] == "token", "later documentation root must be verified token")
        if value["recordBinding"] is not None:
            need(value["workId"] == value["recordBinding"]["workCitation"],
                "later documentation work citation differs")
    return value


def inspect_draft(raw):
    """Validate exact canonical shape and semantics, without authenticating a later binding."""
    need(type(raw) is bytes and len(raw) <= MAX_DRAFT_BYTES, "draft byte bound")
    value = loads(raw, maximum=MAX_DRAFT_BYTES, canonical=True)
    errors = sorted(StreamValidator(DRAFT_SCHEMA, format_checker=FormatChecker()).iter_errors(value),
        key=lambda error: str(error.path))
    need(not errors, "schema validation: " + (errors[0].message if errors else ""))
    return _semantic(value)


def _recorded_binding(source, selector, source_hash):
    from .citations import canonical_citation
    from .canonical import subject_id
    from .chain_rpc import MAX_TRANSCRIPT
    from .recorded_semantic import RecordedSemanticSource
    from .review import _selector
    from .source import BoundSourceState, RetainedSourceRecord
    need(type(source) is RecordedSemanticSource, "concrete RecordedSemanticSource required")
    state = source.state
    need(type(state) is BoundSourceState and state.mode == "recorded_state"
        and state.commitment == source_hash, "recorded source pin differs")
    identity = loads(state.identity, maximum=MAX_TRANSCRIPT, canonical=True)
    need(identity["mode"] == "recorded_state", "recorded source identity mode differs")
    for key, raw in (("sourceCaptureHash", source.capture_bytes),
            ("publicationHash", source.publication_bytes),
            ("interpretationHash", source.interpretation_bytes)):
        need(keccak256(raw) == identity[key], "recorded original evidence bytes differ")
    need(keccak256(dumps(dict(source.anchor))) == identity["anchorHash"], "recorded anchor differs")
    summaries = [{"selector": r.selector.__dict__, "payloadHash": r.payload_hash,
        "authorityEvidenceHash": keccak256(r.authority_evidence), "disclosure": r.disclosure}
        for r in state.records]
    need(summaries == identity["records"] and all(type(r) is RetainedSourceRecord for r in state.records),
        "recorded frozen records differ")
    need(isinstance(selector, dict) and selector.get("pointer") == "", "whole recorded source selector required")
    matches = [r for r in state.records if selector == _selector(r, "")]
    need(len(matches) == 1 and matches[0].disclosure == "public", "recorded selector differs")
    capture = loads(source.capture_bytes, maximum=MAX_TRANSCRIPT, canonical=True)
    originals = [r for r in capture["records"] if r["recordHash"] == matches[0].selector.record_hash]
    documents = {row["documentId"]: hex_bytes(row["payloadHex"]) for row in capture["documents"]}
    need(len(originals) == 1, "recorded original record missing")
    original, record = originals[0], matches[0]
    generic, receipt, subject = original["record"], original["receipt"], original["subject"]
    need(hex_bytes(original["payloadHex"]) == record.payload
        and generic[0] == record.selector.record_type and generic[1] == record.selector.subject_id
        and generic[4] == record.selector.schema_id and generic[2][1] == record.payload_hash
        and documents[generic[4]] == record.schema
        and receipt[1] == record.selector.recorder and receipt[4] == record.selector.record_index
        and receipt[5] == record.selector.record_chain_hash and record.selector.host == source.anchor["host"],
        "recorded original capture differs")
    need(subject[0] == "1" and uint(subject[1]) > 0 and uint(subject[2]) > 0
        and subject[3] == ZERO, "recorded source must have original token subject")
    need(subject_id("token", source.anchor["chainId"], source.anchor["core"], subject[1],
        token_id=subject[2]) == generic[1], "recorded token subject hash differs")
    citation = canonical_citation(source.anchor["chainId"], source.anchor["core"], subject[2])
    return {"kind": "recorded_semantic_source", "sourceStateCommitment": source_hash,
        "anchorHash": identity["anchorHash"], "sourceCaptureHash": identity["sourceCaptureHash"],
        "publicationHash": identity["publicationHash"], "interpretationHash": identity["interpretationHash"],
        "workCitation": citation,
        "recordSelector": deepcopy(selector)}


def _owner_binding(source, record_hash, source_hash):
    from .citations import canonical_citation
    from .canonical import subject_id
    from .chain_rpc import ReplayTransport
    from .owner_record_source import OwnerRecordSource
    need(type(source) is OwnerRecordSource and source.provenance == "trusted_rpc",
        "concrete trusted OwnerRecordSource required")
    source.snapshot()
    transcript = source.reader.transcript()
    frozen = type(source)(source.anchor_bytes, ReplayTransport(transcript, keccak256(transcript)), provenance="trusted_rpc")
    need(keccak256(frozen.snapshot()) == source_hash, "owner source pin differs")
    need(record_hash in frozen.records, "owner source record missing")
    saved = frozen.records[record_hash]
    record, receipt = saved["record"], saved["receipt"]
    need(subject_id("token", frozen.a["chainId"], frozen.a["core"], "0", token_id=receipt[0]) == record[1],
        "owner original token subject hash differs")
    citation = canonical_citation(frozen.a["chainId"], frozen.a["core"], receipt[0])
    return {"kind": "owner_record_source", "sourceSnapshotHash": source_hash,
        "anchorHash": keccak256(frozen.anchor_bytes), "recordHash": record_hash,
        "subjectId": record[1], "schemaId": record[2], "recordType": record[0],
        "host": frozen.a["host"], "owner": receipt[1], "recordIndex": receipt[3],
        "recordChainHash": receipt[4], "tokenId": receipt[0], "workCitation": citation}


def _binding(source, selection, source_hash):
    from .owner_record_source import OwnerRecordSource
    from .recorded_semantic import RecordedSemanticSource
    if type(source) is RecordedSemanticSource:
        return _recorded_binding(source, selection, source_hash)
    if type(source) is OwnerRecordSource:
        need(isinstance(selection, str), "owner record hash required")
        return _owner_binding(source, selection, source_hash)
    raise MuseumError("semantic authoring concrete recorded or owner source required")


def bind_later_documentation(raw, source, selection, *, source_hash):
    """Attach and verify exact existing-work evidence to an unbound later draft."""
    need(type(raw) is bytes and len(raw) <= MAX_DRAFT_BYTES, "draft byte bound")
    value = loads(raw, maximum=MAX_DRAFT_BYTES, canonical=True)
    errors = sorted(StreamValidator(DRAFT_SCHEMA, format_checker=FormatChecker()).iter_errors(value),
        key=lambda error: str(error.path))
    need(not errors, "schema validation: " + (errors[0].message if errors else ""))
    value = _semantic(value, allow_unbound=True)
    need(value["purpose"] == "later_documentation", "binding requires later documentation draft")
    binding = _binding(source, selection, source_hash)
    need(value["workId"] == binding["workCitation"], "later documentation work citation differs")
    if value["recordBinding"] is not None:
        need(value["recordBinding"] == binding, "existing binding differs from pinned evidence")
    value["recordBinding"] = binding
    result = dumps(value)
    validate_draft(result, source=source, source_hash=source_hash)
    return result


def validate_draft(raw, *, source=None, source_hash=None):
    """Fully validate a draft; later documentation always replays concrete evidence."""
    value = inspect_draft(raw)
    if value["purpose"] == "later_documentation":
        need(source is not None and source_hash is not None, "later documentation requires concrete pinned source")
        binding = value["recordBinding"]
        selection = binding["recordSelector"] if binding["kind"] == "recorded_semantic_source" else binding["recordHash"]
        need(binding == _binding(source, selection, source_hash), "serialized binding differs from pinned evidence")
    return value


def revise_draft(previous_raw, revised_raw, *, source=None, source_hash=None):
    """Validate append-only source confirmation and stable identity revision rules."""
    previous = validate_draft(previous_raw, source=source, source_hash=source_hash)
    revised = validate_draft(revised_raw, source=source, source_hash=source_hash)
    need(revised["draftId"] == previous["draftId"] and revised["workId"] == previous["workId"]
        and revised["purpose"] == previous["purpose"], "draft identity/purpose changed")
    need(uint(revised["revision"], 64) == uint(previous["revision"], 64) + 1
        and revised["previousRevisionHash"] == keccak256(previous_raw), "revision lineage differs")
    need(revised["createdAt"] == previous["createdAt"] and revised["sourceAuthor"] == previous["sourceAuthor"],
        "draft creator/source author changed")
    need(_timestamp(revised["revisedAt"]) >= _timestamp(previous["revisedAt"]),
        "revision time moved backward")
    need(revised["recordBinding"] == previous["recordBinding"], "record binding changed")
    for collection in ("mappers", "reviewers"):
        old = {row["entityId"]: row for row in previous[collection]}
        new = {row["entityId"]: row for row in revised[collection]}
        need(set(old) <= set(new), collection + " stable identity removed")
        need(all(old[identifier]["kind"] == new[identifier]["kind"] for identifier in old),
            collection + " actor kind changed")
    before_confirmed = [row for row in previous["sourceVersions"] if row["status"] == "confirmed"]
    after = {row["versionId"]: row for row in revised["sourceVersions"]}
    need(all(after.get(row["versionId"]) == row for row in before_confirmed),
        "confirmed source version changed or disappeared")
    for collection, key, invariant in (
        ("entities", "entityId", ("kind",)),
        ("relationships", "relationshipId", ("type", "subjectId", "objectId")),
        ("dates", "dateId", ("entityId", "kind")),
        ("measurements", "measurementId", ("entityId", "type")),
        ("attachments", "attachmentId", ("entityId", "role")),
        ("authorityDecisions", "decisionId", ("entityId", "authority", "status")),
        ("reviews", "reviewId", ("reviewerId", "targetKind", "targetId", "targetSnapshot", "targetHash", "status", "reviewedAt", "rationale")),
    ):
        old = {row[key]: row for row in previous[collection]}
        new = {row[key]: row for row in revised[collection]}
        need(set(old) <= set(new), collection + " stable identity removed")
        need(all(all(old[i][field] == new[i][field] for field in invariant) for i in old),
            collection + " stable identity retargeted")
    return revised


def preview(raw, *, source=None, source_hash=None):
    """Return an explicit non-publication preview with exact source text retained."""
    value = validate_draft(raw, source=source, source_hash=source_hash)
    item_keys = {"relationship": ("relationships", "relationshipId"),
        "date": ("dates", "dateId"), "measurement": ("measurements", "measurementId"),
        "authority_decision": ("authorityDecisions", "decisionId")}
    reviews = []
    for row in value["reviews"]:
        collection, key = item_keys[row["targetKind"]]
        current = next(item for item in value[collection] if item[key] == row["targetId"])
        reviews.append({"reviewId": row["reviewId"], "targetId": row["targetId"],
            "status": row["status"], "application": "current_target"
                if keccak256(dumps(current)) == row["targetHash"] else "historical_target"})
    return {"mode": MODE, "draftHash": keccak256(raw), "schemaHash": SCHEMA_HASH,
        "draftId": value["draftId"], "revision": value["revision"], "purpose": value["purpose"],
        "recordBinding": deepcopy(value["recordBinding"]),
        "sourceVersions": deepcopy(value["sourceVersions"]),
        "reviewDispositions": reviews,
        "counts": {key: len(value[key]) for key in ("entities", "relationships", "dates",
            "measurements", "attachments", "authorityDecisions", "reviews")},
        "claims": {"recordedStreamDossier": False, "chainBindingInvented": False,
            "signaturePresent": False, "receiptPresent": False, "finalityProven": False,
            "mediaIngested": False, "mediaUploaded": False, "attachmentScanned": False,
            "authorityMatchEstablished": False},
        "qualification": "Offline draft preview only; confirmation covers exact source-version text, not mapped enrichment."}


def preview_bytes(raw, *, source=None, source_hash=None):
    return dumps(preview(raw, source=source, source_hash=source_hash))


def main(argv=None):
    import argparse
    from pathlib import Path
    import sys
    parser = argparse.ArgumentParser(description="Validate or preview an offline museum semantic authoring draft.")
    parser.add_argument("command", choices=("validate", "preview", "schema"))
    parser.add_argument("path", nargs="?", help="canonical JSON draft path")
    args = parser.parse_args(argv)
    if args.command == "schema":
        sys.stdout.buffer.write(SCHEMA_BYTES + b"\n")
        return 0
    need(args.path is not None, "draft path required")
    path = Path(args.path)
    need(path.is_file() and 0 < path.stat().st_size <= MAX_DRAFT_BYTES, "draft file byte bound")
    with path.open("rb") as handle:
        raw = handle.read(MAX_DRAFT_BYTES + 1)
    need(0 < len(raw) <= MAX_DRAFT_BYTES, "draft file changed or exceeds byte bound")
    value = inspect_draft(raw)
    if value["purpose"] == "later_documentation":
        raise MuseumError("semantic authoring CLI cannot authenticate later binding; use validate_draft with a concrete pinned source")
    if args.command == "validate":
        output = dumps({"valid": True, "mode": MODE, "draftHash": keccak256(raw), "schemaHash": SCHEMA_HASH})
    else:
        output = preview_bytes(raw)
    sys.stdout.buffer.write(output + b"\n")
    return 0


if __name__ == "__main__":
    main()
