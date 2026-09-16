"""Capture a typed AAT mapping and explicit Safe SELF review on the current stack.

The chain workflow is real and isolated. Authority snapshot bytes are caller-
pinned inputs. When none are supplied, the command uses an explicitly synthetic
RDF/JSON fixture and records that boundary; it never calls an authority service.
"""
from datetime import datetime, timezone
import hashlib
from pathlib import Path

from .account_profile import JCS_ID, account_iri
from .authority import GVP, RDF_TYPE, SKOS
from .authority_package_v2 import build_authority_package, verify_authority_package
from .authority_snapshot import DCT_MODIFIED, RAW_BYTES, canonical_authority_iri, parse_snapshot
from .authority_v2 import PROFILE_HASH as RECONCILIATION_PROFILE_HASH, RELATION, RULE, alignment_literal
from .canonical import dumps, keccak256, loads, schema_id
from .current_media_inputs import selected_plans
from .current_museum_capture import ROOT, CurrentMuseumFixture, capture as capture_current, export_media, main as run_main
from .independent_wire import require
from .package import write_package
from .review import REVIEW_MAPPING_RULE, REVIEW_RELATION, review_literal, _validate
from .typed_authority_profile import ASSERTION_SCHEMA_BYTES, NAMES, TypedAuthorityProfile

AAT_IDENTIFIER = "300033618"
AAT_IRI = canonical_authority_iri("GETTY_AAT", AAT_IDENTIFIER)
SNAPSHOT_PATH = "authorities/getty-aat-300033618.rdf.json"
ENTITY_ID = "urn:6529stream:museum:fixture:type:paintings"
DECLARATION_ASSERTION_ID = "urn:6529stream:museum:fixture:assertion:type-label"
ALIGNMENT_ASSERTION_ID = "urn:6529stream:museum:fixture:assertion:aat-alignment"
REVIEW_ASSERTION_ID = "urn:6529stream:museum:fixture:assertion:aat-alignment-review"
LABEL_RELATION = "http://www.w3.org/2000/01/rdf-schema#label"
XSD_STRING = "http://www.w3.org/2001/XMLSchema#string"
PUBLISHER_URI = "https://vocab.getty.edu/aat/300033618.json"
SYNTHETIC_RETRIEVED_AT = "2026-09-16T00:00:00Z"


def _stamp(value):
    return datetime.fromtimestamp(value, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _hash_ref(raw, canonicalization):
    return {"algorithm": "1", "digest": keccak256(raw), "canonicalizationId": canonicalization}


def _fact(row):
    return {"subject": row["subject"], "predicate": row["predicate"],
        "object": row["object"]["value"], "sourcePointer": row["sourcePointer"]}


def synthetic_snapshot():
    """Return a deterministic local RDF/JSON control, never publisher evidence."""
    raw = dumps({AAT_IRI: {
        RDF_TYPE: [{"type": "uri", "value": SKOS + "Concept"},
                   {"type": "uri", "value": GVP + "Concept"}],
        SKOS + "prefLabel": [{"type": "literal", "value": "paintings (visual works)", "lang": "en"}],
        SKOS + "broader": [{"type": "uri", "value": "http://vocab.getty.edu/aat/300191086"}],
        DCT_MODIFIED: [{"type": "literal", "value": "2026-04-09T14:09:50"}],
    }})
    descriptor = dumps({"version": "1", "authority": "GETTY_AAT", "identifier": AAT_IDENTIFIER,
        "canonicalIri": AAT_IRI, "sourceUri": "https://example.org/fixtures/getty-aat-300033618.rdf.json",
        "retrievedAt": SYNTHETIC_RETRIEVED_AT, "contentHash": _hash_ref(raw, RAW_BYTES),
        "byteLength": str(len(raw)), "mediaType": "application/rdf+json",
        "attribution": "Synthetic local test fixture; not bytes served or authenticated by Getty.",
        "reuseTerms": "Test-only fixture data; no authority publisher or licensing claim."})
    return descriptor, raw, keccak256(descriptor), "synthetic_fixture"


def validate_snapshot(descriptor, raw, descriptor_hash):
    parsed = parse_snapshot(descriptor, raw, descriptor_hash=descriptor_hash)
    require(parsed["authority"] == "GETTY_AAT" and parsed["identifier"] == AAT_IDENTIFIER
        and parsed["canonicalIri"] == AAT_IRI and parsed["focusIri"] is None,
        "capture requires the exact configured AAT concept without a focus identity")
    labels = [row for row in parsed["labels"] if row["language"] == "en"]
    require(labels, "capture AAT snapshot requires an English label")
    compatible = [row for row in parsed["typeFacts"] if row["subject"] == AAT_IRI
        and row["predicate"] == RDF_TYPE and row["object"]["value"] in (SKOS + "Concept", GVP + "Concept")]
    require(compatible, "capture AAT snapshot requires an exact supported concept type")
    return parsed, labels[0], compatible[0]


def documentary_bytes(descriptor, raw, descriptor_hash, mode, label):
    return dumps({"purpose": "Exact local source for a typed authority mapping on the current fixture.",
        "localEntityId": ENTITY_ID, "entityKind": "Type", "sourceText": label["value"],
        "sourceLanguage": label["language"], "snapshotPath": SNAPSHOT_PATH,
        "snapshotDescriptorHash": descriptor_hash, "snapshotContentHash": keccak256(raw),
        "snapshotDescriptor": loads(descriptor), "snapshotMode": mode,
        "authorityPublisherAuthenticated": False})


def _assertion(identifier, subject, relation, object_, agent, created_at, evidence, *, origin, rule, rationale):
    return {"id": identifier, "subject": subject, "relation": relation, "object": object_,
        "assertingAgent": agent, "createdAt": created_at, "evidence": [evidence], "origin": origin,
        "reviewStatus": "unreviewed", "mappingRule": rule, "rationale": rationale,
        "reviewEvidence": [], "corrects": [], "disputes": []}


def declaration_payload(profile, agent, subject_id, source_selector, source_raw, created_at, label):
    evidence = {"source": _hash_ref(source_raw, RAW_BYTES), "selectorType": "json_pointer",
        "selector": "/sourceText", "basis": "own_signed_statement"}
    entity = {"id": ENTITY_ID, "kind": "type", "names": [{"value": label["value"],
        "language": label["language"], "kind": "preferred"}], "declaringAgent": agent,
        "sourceRecords": [source_selector], "predecessors": [], "continuation": None}
    assertion = _assertion(DECLARATION_ASSERTION_ID, ENTITY_ID, LABEL_RELATION,
        {"literal": {"lexicalValue": label["value"], "datatype": XSD_STRING,
            "language": label["language"], "unit": None, "precision": None}}, agent, created_at, evidence,
        origin="direct_statement", rule="urn:6529stream:museum:mapping:declared-type-label-v1",
        rationale="The historical Safe account directly declares this local Type label.")
    payload = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": profile.profile_hash,
        "anchorSubject": {"kind": "collection", "subjectId": subject_id}, "entities": [entity],
        "assertions": [assertion], "sourceRecords": [source_selector], "authorityAlignments": []}
    raw = dumps(payload); _validate(ASSERTION_SCHEMA_BYTES, raw)
    return raw, entity


def alignment_payload(profile, agent, subject_id, source_selector, source_raw, declaration_selector,
                      declaration, created_at, parsed, label, type_fact):
    descriptor = parsed["descriptor"]
    alignment = {"entityId": ENTITY_ID, "authority": "GETTY_AAT", "identifier": AAT_IDENTIFIER,
        "canonicalIri": AAT_IRI, "focusIri": None, "matchKind": "equivalent_entity",
        "snapshotRef": {"path": SNAPSHOT_PATH, "contentHash": descriptor["contentHash"],
            "byteLength": descriptor["byteLength"], "mediaType": descriptor["mediaType"]},
        "retrievedAt": descriptor["retrievedAt"],
        "authorityRevision": (parsed["revisions"][0]["object"]["value"] if parsed["revisions"] else "not_supplied"),
        "labelAtReview": {"value": label["value"], "language": label["language"], "kind": "preferred"},
        "basis": "Safe-authored mapping to exact retained snapshot bytes; no publisher or human identity inference.",
        "assertionId": ALIGNMENT_ASSERTION_ID}
    body = {"alignment": alignment, "entityKind": "Type", "typeEvidence": [_fact(type_fact)],
        "contextChecks": [], "change": None, "declaration": {"scope": "prior_record",
            "selector": declaration_selector, "declarationHash": keccak256(dumps(declaration))}}
    evidence = {"source": _hash_ref(source_raw, RAW_BYTES), "selectorType": "json_pointer",
        "selector": "/sourceText", "basis": "documentary_evidence"}
    assertion = _assertion(ALIGNMENT_ASSERTION_ID, ENTITY_ID, RELATION,
        {"literal": alignment_literal(body)}, agent, created_at, evidence, origin="automated_mapping", rule=RULE,
        rationale="A program-generated mapping proposes an exact AAT concept for later explicit Safe review.")
    payload = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": profile.profile_hash,
        "anchorSubject": {"kind": "collection", "subjectId": subject_id}, "entities": [],
        "assertions": [assertion], "sourceRecords": [source_selector, declaration_selector],
        "authorityAlignments": [alignment]}
    raw = dumps(payload); _validate(ASSERTION_SCHEMA_BYTES, raw)
    return raw, assertion


def review_payload(profile, agent, subject_id, original_selector, original_raw, original_assertion, created_at):
    body = {"assertionRecord": original_selector, "assertionRevisionHash": keccak256(dumps(original_assertion)),
        "profileHash": profile.profile_hash, "mappingRule": original_assertion["mappingRule"],
        "disposition": "reviewed"}
    evidence = {"source": _hash_ref(original_raw, JCS_ID), "selectorType": "json_pointer",
        "selector": "/assertions/0", "basis": "own_signed_statement"}
    assertion = _assertion(REVIEW_ASSERTION_ID, original_assertion["id"], REVIEW_RELATION,
        {"literal": review_literal(body)}, agent, created_at, evidence, origin="direct_statement",
        rule=REVIEW_MAPPING_RULE, rationale="The same historical Safe explicitly reviews the exact mapping revision.")
    payload = {"profileSchemaId": schema_id(NAMES[0]), "profileHash": profile.profile_hash,
        "anchorSubject": {"kind": "collection", "subjectId": subject_id}, "entities": [],
        "assertions": [assertion], "sourceRecords": [dict(original_selector, pointer="")],
        "authorityAlignments": []}
    raw = dumps(payload); _validate(ASSERTION_SCHEMA_BYTES, raw)
    return raw


def typed_media_plans(source, *, omit_publisher=False):
    """Retain the V1 media selection under the registered mixed V2 profile."""
    plans = dict(selected_plans(source, omit_publisher=omit_publisher))
    plan = loads(plans["plan.json"], maximum=524288, canonical=True)
    plan["version"] = source.profile.version
    plans["plan.json"] = dumps(plan)
    premis = loads(plans["premis-plan.json"], maximum=524288, canonical=True)
    premis["linkedArtPlanHash"] = keccak256(plans["plan.json"]); plans["premis-plan.json"] = dumps(premis)
    iiif = loads(plans["iiif-plan.json"], maximum=524288, canonical=True)
    iiif.update(linkedArtPlanHash=keccak256(plans["plan.json"]),
        premisPlanHash=keccak256(plans["premis-plan.json"])); plans["iiif-plan.json"] = dumps(iiif)
    lido = loads(plans["lido-plan.json"], maximum=524288, canonical=True)
    lido.update(linkedArtPlanHash=keccak256(plans["plan.json"]),
        premisPlanHash=keccak256(plans["premis-plan.json"]),
        iiifPlanHash=keccak256(plans["iiif-plan.json"])); plans["lido-plan.json"] = dumps(lido)
    return plans


class CurrentAuthorityFixture(CurrentMuseumFixture):
    def profile_for_capture(self):
        return TypedAuthorityProfile(ROOT)

    def configure_authority(self, descriptor, raw, descriptor_hash, mode, publisher_response=None,
                            publisher_metadata=None):
        parsed, label, type_fact = validate_snapshot(descriptor, raw, descriptor_hash)
        self.authority_input = {"descriptor": descriptor, "raw": raw, "descriptorHash": descriptor_hash,
            "mode": mode, "parsed": parsed, "label": label, "typeFact": type_fact}
        self.publisher_response = publisher_response
        self.publisher_metadata = publisher_metadata

    def plans_for_capture(self, source, *, omit_publisher=False):
        return typed_media_plans(source, omit_publisher=omit_publisher)

    def after_media_publications(self):
        if not hasattr(self, "authority_input"):
            self.configure_authority(*synthetic_snapshot())
        item, context = self.authority_input, self.capture_context
        profile = context["profile"]
        require(type(profile) is TypedAuthorityProfile, "typed authority capture profile required")
        agent = account_iri("31337", self.attestor)
        documentary = documentary_bytes(item["descriptor"], item["raw"], item["descriptorHash"],
            item["mode"], item["label"])
        nonce = context["nextNonce"]
        source_selector, sid = self.publish(documentary, context["seedSchema"], RAW_BYTES, nonce)
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        declared_raw, declaration = declaration_payload(profile, agent, sid, source_selector, documentary,
            _stamp(int(block["timestamp"], 16)), item["label"])
        declaration_record, _ = self.publish(declared_raw, schema_id(NAMES[1]), JCS_ID, nonce + 1)
        declaration_selector = dict(declaration_record, pointer="/entities/0")
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        aligned_raw, assertion = alignment_payload(profile, agent, sid, source_selector, documentary,
            declaration_selector, declaration, _stamp(int(block["timestamp"], 16)), item["parsed"],
            item["label"], item["typeFact"])
        alignment_record, _ = self.publish(aligned_raw, schema_id(NAMES[1]), JCS_ID, nonce + 2)
        alignment_selector = dict(alignment_record, pointer="/assertions/0")
        block = self.rpc("eth_getBlockByNumber", ["latest", False])
        reviewed_raw = review_payload(profile, agent, sid, alignment_selector, aligned_raw, assertion,
            _stamp(int(block["timestamp"], 16)))
        review_record, _ = self.publish(reviewed_raw, schema_id(NAMES[1]), JCS_ID, nonce + 3)
        self.authority_records = {"documentary": source_selector, "declaration": declaration_selector,
            "alignment": alignment_selector, "review": dict(review_record, pointer="/assertions/0")}

    def extra_capture_evidence(self):
        item = self.authority_input
        return {"authorityCapture": {"profile": self.capture_context["profile"].name,
            "profileHash": self.capture_context["profile"].profile_hash,
            "reconciliationProfileHash": RECONCILIATION_PROFILE_HASH,
            "snapshotMode": item["mode"], "snapshotDescriptorHash": item["descriptorHash"],
            "snapshotContentHash": keccak256(item["raw"]), "records": self.authority_records,
            "actualCurrentSafeRecords": True, "selfReviewOnly": True,
            "authorityPublisherAuthenticated": False, "namedHumanIdentityEstablished": False,
            "publisherResponse": self.publisher_metadata}}

    def export_capture(self, source, output):
        base_hash = export_media(source, output, plans_function=self.plans_for_capture)
        item = self.authority_input
        request = dumps({"version": "1", "requests": [{"entityId": ENTITY_ID, "entityKind": "Type",
            "authority": "GETTY_AAT", "sourceText": item["label"]["value"]}]})
        selection = dumps({"mode": "recorded_account_selection", "version": "1",
            "sourceStateHash": source.state.commitment, "profileHash": source.profile_hash,
            "sourceAuthoritySet": [self.authority_records["alignment"]],
            "reviewerAuthoritySet": [self.authority_records["review"]],
            "singleValuedRelations": [RELATION], "independentReviewRequired": False,
            "allowAccountSelfReview": True})
        snapshots = {SNAPSHOT_PATH: (item["descriptor"], item["raw"], item["descriptorHash"])}
        result = build_authority_package(output / "package", base_hash, request, selection, snapshots,
            request_hash=keccak256(request), selection_hash=keccak256(selection),
            profile_hash=RECONCILIATION_PROFILE_HASH, disclosure="public")
        destination = output / "authority-package"; write_package(result, destination)
        verify_authority_package(destination, result.manifest_hash)
        output.joinpath("authority-requests.json").write_bytes(request)
        output.joinpath("authority-selection.json").write_bytes(selection)
        output.joinpath("authority-snapshot.descriptor.json").write_bytes(item["descriptor"])
        output.joinpath("authority-snapshot.rdf.json").write_bytes(item["raw"])
        if self.publisher_response is not None:
            output.joinpath("authority-publisher-response.json").write_bytes(self.publisher_response)
            output.joinpath("authority-publisher-response-evidence.json").write_bytes(dumps(self.publisher_metadata))
        report = loads(dict(result.files)["authority/report.json"], maximum=524288, canonical=True)
        output.joinpath("authority-result.json").write_bytes(dumps({
            "mode": "actual_current_safe_typed_authority_reconciliation", "manifestHash": result.manifest_hash,
            "sourceManifestHash": base_hash, "offlinePackageVerified": True,
            "resultStatus": report["results"][0]["status"], "snapshotMode": item["mode"],
            "actualCurrentSafeRecords": True, "selfReviewOnly": True,
            "authorityPublisherAuthenticated": False, "namedHumanIdentityEstablished": False}))
        return result.manifest_hash


def _read(path, maximum):
    require(path.stat().st_size <= maximum, "authority input file bound")
    raw = path.read_bytes(); require(len(raw) <= maximum, "authority input changed beyond bound")
    return raw


def configure_parser(parser):
    parser.add_argument("--authority-descriptor", type=Path)
    parser.add_argument("--authority-raw", type=Path)
    parser.add_argument("--authority-descriptor-hash")
    parser.add_argument("--publisher-response", type=Path)
    parser.add_argument("--publisher-response-sha256")
    parser.add_argument("--publisher-retrieved-at")


def prepare_arguments(args):
    supplied = (args.authority_descriptor, args.authority_raw, args.authority_descriptor_hash)
    require(all(value is None for value in supplied) or all(value is not None for value in supplied),
        "authority descriptor, raw bytes and descriptor hash must be supplied together")
    if all(value is None for value in supplied):
        args.authority_input = synthetic_snapshot()
    else:
        args.authority_input = (_read(args.authority_descriptor, 65536), _read(args.authority_raw, 1048576),
            args.authority_descriptor_hash, "caller_pinned_rdf_json")
        validate_snapshot(*args.authority_input[:3])
    publisher = (args.publisher_response, args.publisher_response_sha256, args.publisher_retrieved_at)
    require(all(value is None for value in publisher) or all(value is not None for value in publisher),
        "publisher response, SHA-256 and retrieval time must be supplied together")
    args.publisher_input = None
    if all(value is not None for value in publisher):
        raw = _read(args.publisher_response, 1048576)
        require(hashlib.sha256(raw).hexdigest() == args.publisher_response_sha256,
            "publisher response SHA-256 mismatch")
        require(args.publisher_retrieved_at.endswith("Z"), "publisher retrieval time must be UTC")
        args.publisher_input = (raw, {"sourceUri": PUBLISHER_URI, "retrievedAt": args.publisher_retrieved_at,
            "mediaType": "application/json", "byteLength": str(len(raw)),
            "sha256": args.publisher_response_sha256,
            "representation": "Getty SPARQL-results JSON retained exactly; not RDF/JSON and not used as the reconciled snapshot.",
            "attribution": "Getty Vocabulary data; J. Paul Getty Trust; contributor/source attribution remains required.",
            "reuseTerms": "Open Data Commons Attribution License (ODC-By) 1.0 per Getty documentation.",
            "authorityPublisherAuthenticated": False})


def configure_fixture(fixture, args):
    response, metadata = (None, None) if args.publisher_input is None else args.publisher_input
    fixture.configure_authority(*args.authority_input, publisher_response=response, publisher_metadata=metadata)


def capture(fixture, output):
    return capture_current(fixture, output)


def main():
    run_main(fixture_type=CurrentAuthorityFixture, capture_function=capture,
        configure_parser=configure_parser, prepare_arguments=prepare_arguments,
        configure_fixture=configure_fixture)


if __name__ == "__main__": main()
