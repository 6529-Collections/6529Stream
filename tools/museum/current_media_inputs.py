"""Complete public test-image statements; recorded authority comes only from later chain capture.

This module prepares prospective account payloads and exact source selections. It
never constructs or promotes a RecordedSemanticSource, and never retrieves media.
"""
import base64
import hashlib
import struct
import zlib

from .canonical import dumps, keccak256, loads, schema_id
from .independent_wire import require
from .account_profile import account_iri
from .schemas import NAMES
from .premis import FIELDS as PF
from .iiif import FIELDS as IF
from .lido_model import FIELDS as LF
from .recorded_lido import PUBLISHER
from .projection_v2 import CONTENT, CONTENT_KIND

PREFIX = "urn:stream:current-media:"
XSD = "http://www.w3.org/2001/XMLSchema#"
LABEL = "Public current-stack capture test image"
CREDIT = "Public test data, authored for this local capture; no institutional or creator identity claim."


def image_bytes():
    """A deterministic one-pixel RGBA PNG, written locally as public test data."""
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(b"\x00\x65\x29\xff\xff", 9)) + chunk(b"IEND", b""))


def media_description(raw):
    require(type(raw) is bytes and raw == image_bytes(), "only exact public capture image is admitted")
    digest = hashlib.sha256(raw).hexdigest()
    return {"bytes": str(len(raw)), "sha256": digest,
            "uri": "ipfs://b" + base64.b32encode(bytes.fromhex("01551220" + digest)).decode("ascii").lower().rstrip("="),
            "mime": "image/png", "puid": "fmt/13", "width": "1", "height": "1",
            "classification": "public", "purpose": "local protocol fixture; not a real museum accession"}


def payloads(*, chain_id, attestor, subject_id, profile_hash, prior, source_digest, created_at):
    """Emit bounded canonical payloads for an actual Safe to publish subsequently."""
    agent = account_iri(str(chain_id), attestor)
    media = media_description(image_bytes())
    entities = []
    for suffix, kind, name in (("work", "abstract_work", LABEL), ("image", "digital_object", LABEL + " file"),
            ("creator", "person", "Declared test-image creator"), ("publisher", "group", "Declared local test publisher"),
            ("creation", "event", "Local fixture creation")):
        entities.append({"id": PREFIX + suffix, "kind": kind, "declaringAgent": agent,
            "names": [{"value": name, "language": None, "kind": "preferred"}],
            "sourceRecords": [prior], "predecessors": []})
    evidence = [{"source": {"algorithm": "1", "digest": source_digest, "canonicalizationId": schema_id("RAW_BYTES")},
                 "selectorType": "json_pointer", "selector": "/purpose", "basis": "own_signed_statement"}]
    claims = []
    def add(subject, relation, value, datatype="string", unit=None, entity=False):
        obj = {"entity": PREFIX + value} if entity else {"literal": {"lexicalValue": value,
            "datatype": XSD + datatype, "language": None, "unit": unit, "precision": None}}
        claims.append({"id": PREFIX + "assertion:" + str(len(claims)), "subject": PREFIX + subject,
            "relation": relation, "object": obj, "assertingAgent": agent, "createdAt": created_at,
            "evidence": evidence, "origin": "direct_statement", "reviewStatus": "unreviewed",
            "mappingRule": PREFIX + "direct-test-statement", "rationale": CREDIT,
            "reviewEvidence": [], "corrects": [], "disputes": []})
    for field, value in (("category", "file"), ("size", media["bytes"]), ("digest", media["sha256"]), ("puid", media["puid"])):
        add("image", PF[field], value, "nonNegativeInteger" if field == "size" else "string")
    for field, value in (("presentation-type", "Image"), ("mime", media["mime"]), ("content-uri", media["uri"]),
            ("attribution", CREDIT), ("rights", "http://creativecommons.org/publicdomain/zero/1.0/")):
        add("image", IF[field], value, "anyURI" if field in ("content-uri", "rights") else "string")
    add("image", IF["presentation-of"], "work", entity=True)
    for field in ("width", "height"): add("image", IF[field], media[field], "positiveInteger", "px")
    add("work", IF["summary"], "A retained one-pixel image used to exercise recorded multi-format export.")
    add("work", IF["attribution"], CREDIT)
    add("work", IF["manifest-rights"], "http://creativecommons.org/publicdomain/zero/1.0/", "anyURI")
    for field, value in (("work-type", "digital test artwork"), ("medium", "one-pixel RGBA PNG"),
            ("edition", "single public protocol test example"), ("credit-line", CREDIT), ("document-language", "und")):
        add("work", LF[field], value)
    add("work", LF["creation-event"], "creation", entity=True)
    add("creation", LF["event-type"], "creation")
    add("creation", LF["creation-display"], created_at)
    add("creation", LF["creator"], "creator", entity=True)
    add("work", PUBLISHER, "publisher", entity=True)
    template = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": profile_hash,
        "anchorSubject": {"kind": "collection", "subjectId": subject_id}, "entities": [], "assertions": [],
        "sourceRecords": [prior], "authorityAlignments": []}
    result = []
    # Every original semantic record requires at least one assertion.
    for index, item in enumerate(entities):
        result.append(dumps(template | {"entities": [item], "assertions": [claims[index]]}))
    for offset in range(len(entities), len(claims), 4):
        result.append(dumps(template | {"assertions": claims[offset:offset + 4]}))
    require(all(len(raw) <= 8192 for raw in result), "current media payload exceeds host bound")
    from .review import ASSERTION_SCHEMA_BYTES, _validate
    for raw in result: _validate(ASSERTION_SCHEMA_BYTES, raw)
    return tuple(result)


def selected_plans(source, *, omit_publisher=False):
    """Select actual captured records only; omitted publisher is a real selection negative."""
    from .recorded_semantic import RecordedSemanticSource
    from .review import _selector
    from . import recorded_premis as premis, recorded_iiif as iiif, recorded_lido as lido
    require(type(source) is RecordedSemanticSource, "verified captured source required")
    rows, entities, issuers = [], [], set()
    for record in source.state.records:
        if record.selector.schema_id != schema_id(NAMES[1]): continue
        value = source.payload(record)
        for index, item in enumerate(value["entities"]):
            if item["id"].startswith(PREFIX):
                entities.append(_selector(record, "/entities/" + str(index)))
                issuers.add(item["declaringAgent"])
        for index, item in enumerate(value["assertions"]):
            if item["id"].startswith(PREFIX) and not (omit_publisher and item["relation"] == PUBLISHER):
                rows.append(_selector(record, "/assertions/" + str(index)))
                issuers.add(item["assertingAgent"])
    require(rows and len(entities) == 5 and len(issuers) == 1, "complete actual current-media entity/issuer selection required")
    scope = {"version": "1", "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash}
    policy = dumps(scope | {"mode": "recorded_account_selection", "sourceAuthoritySet": rows,
        "reviewerAuthoritySet": [], "singleValuedRelations": sorted(set((*PF.values(), *IF.values(), *LF.values(), PUBLISHER, CONTENT, CONTENT_KIND))),
        "independentReviewRequired": False, "allowAccountSelfReview": False})
    plan = dumps(scope | {"mode": "recorded_account_resource_projection", "version": "account-1",
        "selectionPolicyHash": keccak256(policy), "crosswalkHash": source.profile.crosswalk_hash,
        "entityAuthoritySet": entities, "externalEntities": [{"id": next(iter(issuers)), "kind": "account"}]})
    pp = dumps(scope | {"mode": premis.MODE, "linkedArtPlanHash": keccak256(plan),
        "premisProfileHash": premis.PROFILE_HASH, "objects": [PREFIX + "image"]})
    ip = dumps(scope | {"mode": iiif.MODE, "linkedArtPlanHash": keccak256(plan), "premisPlanHash": keccak256(pp),
        "iiifProfileHash": iiif.PROFILE_HASH, "work": PREFIX + "work", "manifestId": "https://example.org/current-media/manifest",
        "canvases": [{"file": PREFIX + "image", "canvasId": "https://example.org/current-media/canvas",
            "pageId": "https://example.org/current-media/page", "annotationId": "https://example.org/current-media/annotation"}]})
    lp = dumps(scope | {"mode": lido.MODE, "linkedArtPlanHash": keccak256(plan), "premisPlanHash": keccak256(pp),
        "iiifPlanHash": keccak256(ip), "lidoProfileHash": lido.PROFILE_HASH, "recordId": "https://example.org/current-media/lido"})
    return {"selection.json": policy, "plan.json": plan, "premis-plan.json": pp, "iiif-plan.json": ip, "lido-plan.json": lp}
