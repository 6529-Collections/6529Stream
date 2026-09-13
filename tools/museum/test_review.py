"""Canonical review payload joins using explicit synthetic adapter facts."""

import copy
from dataclasses import replace
from pathlib import Path
import unittest

from .canonical import MuseumError, dumps, keccak256, schema_id
from .review import (ASSERTION_SCHEMA_BYTES, BODY_SCHEMA_BYTES, REVIEW_DATATYPE, REVIEW_MAPPING_RULE, REVIEW_RELATION,
                     resolve_fixture_review, review_literal)
from .schemas import NAMES
from .source import FixtureSourceAdapter, RecordSelector, SourceRecord
from .test_schema_inventory import A, H, assertion_document


def row(record):
    s = record.selector
    return {"recordHash": s.record_hash, "subjectId": s.subject_id, "schemaId": s.schema_id,
            "schemaHash": s.schema_hash, "recordType": s.record_type, "host": s.host, "recorder": s.recorder,
            "authorizationClass": s.authorization_class, "recordIndex": s.record_index,
            "recordChainHash": s.record_chain_hash, "pointer": "/assertions/0"}


def record(document, name, agent, family, position, disclosure="public"):
    raw = dumps(document)
    # Deliberately synthetic identifiers; these are not catalog allocations or
    # a reconstruction of the onchain recordHash preimage.
    kind = schema_id("fixture:family:" + family)
    authority = "ARTIST_SIGNER" if family == "artist" else "CURATOR_SIGNER"
    selector = RecordSelector(A, schema_id("fixture:record:" + name), H, schema_id(NAMES[1]),
                              keccak256(ASSERTION_SCHEMA_BYTES), kind, A, authority, "1",
                              schema_id("fixture:chain:" + name))
    facts = {"mode": "synthetic_fixture", "agentIri": agent, "recorder": A,
             "recordType": kind, "authorizationClass": authority, "publicationPosition": position}
    return SourceRecord(selector, raw, keccak256(raw), ASSERTION_SCHEMA_BYTES, dumps(facts), disclosure)


def case(*, self_review=False, disposition="reviewed", body_change=None, review_change=None):
    original_document = assertion_document()
    original = original_document["assertions"][0]
    original["origin"] = "human_mapping"
    source = record(original_document, "original", original["assertingAgent"], "artist", ["10", "0", "0"])
    selector = row(source)
    revision = keccak256(dumps(original))
    body = {"assertionRecord": copy.deepcopy(selector), "assertionRevisionHash": revision, "profileHash": H,
            "mappingRule": original["mappingRule"], "disposition": disposition}
    if body_change:
        body_change(body)
    review_document = assertion_document()
    review = review_document["assertions"][0]
    review.update(id="urn:fixture:review", subject=original["id"], relation=REVIEW_RELATION,
                  mappingRule=REVIEW_MAPPING_RULE, assertingAgent=original["assertingAgent"] if self_review else "urn:fixture:reviewer",
                  createdAt="2026-09-12T00:01:00Z", object={"literal": review_literal(body)})
    review_document["sourceRecords"] = [selector]
    if review_change:
        review_change(review)
    reviewer = record(review_document, "review", review["assertingAgent"], "curator", ["10", "0", "1"])
    evidence = {"reviewRecord": row(reviewer), "assertionRecord": selector, "assertionRevisionHash": revision,
                "profileHash": H, "mappingRule": original["mappingRule"], "reviewer": review["assertingAgent"],
                "reviewedAt": review["createdAt"], "selfReview": self_review}
    state = FixtureSourceAdapter("canonical-review", (source, reviewer)).snapshot()
    return state, evidence, selector, original["mappingRule"]


def resolve(data):
    state, evidence, selector, rule = data
    return resolve_fixture_review(state, evidence, profile_hash=H, original_selector=selector, mapping_rule=rule)


class CanonicalReview(unittest.TestCase):
    def test_exact_subordinate_schema_and_noncanonical_or_self_committing_body_reject(self):
        path = Path(__file__).resolve().parents[2] / "schemas/museum/review/review-body.schema.json"
        self.assertEqual(path.read_bytes(), BODY_SCHEMA_BYTES)
        with self.assertRaises(MuseumError):
            case(body_change=lambda body: body.update(reviewRecord={}))
        with self.assertRaises(MuseumError):
            case(body_change=lambda body: body.update(selfReview=False))
        with self.assertRaises(MuseumError):
            case(disposition="approved-by-name-only")
        with self.assertRaises(MuseumError):
            resolve(case(review_change=lambda review: review["object"]["literal"].update(
                lexicalValue=review["object"]["literal"]["lexicalValue"] + "\n")))
        self.assertEqual(resolve(case()).disposition, "reviewed")

    def test_review_binds_original_and_resolves_own_selector_externally(self):
        data = case()
        result = resolve(data)
        self.assertEqual(result.mode, "synthetic_fixture")
        self.assertEqual(result.original_selector, dumps(data[2]))
        self.assertEqual(result.review_selector, dumps(data[1]["reviewRecord"]))
        self.assertEqual(result.disposition, "reviewed")
        self.assertFalse(result.self_review)
        self.assertNotIn(data[1]["reviewRecord"]["recordHash"].encode(), result.body)
        self.assertNotIn(b'"reviewRecord"', result.body)
        self.assertNotIn(b'"selfReview"', result.body)
        rejected = resolve(case(disposition="rejected"))
        self.assertEqual(rejected.disposition, "rejected")  # resolver does not turn it into approval

    def test_signed_body_scope_mutations_reject_with_healthy_original_control(self):
        for key, value in (("profileHash", schema_id("other")), ("mappingRule", "urn:fixture:wrong-rule"),
                           ("assertionRevisionHash", schema_id("other"))):
            with self.subTest(key=key), self.assertRaises(MuseumError):
                resolve(case(body_change=lambda body, k=key, v=value: body.update({k: v})))
        with self.assertRaises(MuseumError):
            resolve(case(body_change=lambda body: body["assertionRecord"].update(recordIndex="2")))
        self.assertEqual(resolve(case()).disposition, "reviewed")

    def test_same_assertion_bytes_at_another_record_do_not_reuse_review(self):
        data = case()
        source, review = data[0].records
        later = replace(source, selector=replace(source.selector, record_hash=schema_id("fixture:later"), record_index="2"))
        self.assertEqual(later.payload, source.payload)
        evidence = copy.deepcopy(data[1])
        evidence["assertionRecord"] = row(later)
        state = FixtureSourceAdapter("later-original", (later, review)).snapshot()
        with self.assertRaises(MuseumError):
            resolve((state, evidence, row(later), data[3]))
        self.assertEqual(resolve(data).disposition, "reviewed")

    def test_self_review_is_derived_from_fixture_issuers(self):
        data = case(self_review=True)
        self.assertTrue(resolve(data).self_review)
        forged = copy.deepcopy(data[1])
        forged["selfReview"] = False
        with self.assertRaises(MuseumError):
            resolve((data[0], forged, data[2], data[3]))
        independent = case()
        claimed_self = copy.deepcopy(independent[1])
        claimed_self["selfReview"] = True
        with self.assertRaises(MuseumError):
            resolve((independent[0], claimed_self, independent[2], independent[3]))
        self.assertFalse(resolve(independent).self_review)

    def test_review_identity_datatype_origin_and_withdrawal_controls(self):
        for field, value in (("subject", "urn:fixture:wrong-assertion"), ("relation", "urn:fixture:ordinary-claim"),
                             ("mappingRule", "urn:fixture:wrong-rule"), ("origin", "automated_mapping"),
                             ("reviewStatus", "withdrawn")):
            with self.subTest(field=field), self.assertRaises(MuseumError):
                resolve(case(review_change=lambda review, k=field, v=value: review.update({k: v})))
        for field, value in (("datatype", "urn:fixture:other-datatype"), ("language", "en"),
                             ("unit", "none"), ("precision", "exact")):
            with self.subTest(field=field), self.assertRaises(MuseumError):
                resolve(case(review_change=lambda review, k=field, v=value: review["object"]["literal"].update({k: v})))
        self.assertEqual(resolve(case()).disposition, "reviewed")

    def test_exact_selector_and_issuer_facts_and_publication_order(self):
        data = case()
        for field, value in (("host", "0x" + "33" * 20), ("recordType", schema_id("other")),
                             ("authorizationClass", "INDEPENDENT_ATTESTOR"), ("pointer", "/assertions/00")):
            evidence = copy.deepcopy(data[1])
            evidence["reviewRecord"][field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError):
                resolve((data[0], evidence, data[2], data[3]))
        from .canonical import loads
        source, review = data[0].records
        for field, value in (("agentIri", "urn:fixture:forged"), ("recordType", schema_id("foreign")),
                             ("publicationPosition", ["10", "0", "0"]), ("publicationPosition", ["9", "99", "99"])):
            facts = loads(review.authority_evidence)
            facts[field] = value
            bad = replace(review, authority_evidence=dumps(facts))
            state = FixtureSourceAdapter("bad-review-facts", (source, bad)).snapshot()
            with self.subTest(field=field, value=value), self.assertRaises(MuseumError):
                resolve((state, data[1], data[2], data[3]))
        self.assertEqual(resolve(data).disposition, "reviewed")

    def test_backlink_cannot_supply_reviewer_or_time_and_restricted_reads_reject(self):
        data = case()
        for field, value in (("reviewer", "urn:fixture:forged"), ("reviewedAt", "2026-09-12T00:02:00Z")):
            evidence = copy.deepcopy(data[1])
            evidence[field] = value
            with self.assertRaises(MuseumError):
                resolve((data[0], evidence, data[2], data[3]))
        for index in (0, 1):
            records = list(data[0].records)
            records[index] = replace(records[index], disclosure="restricted")
            state = FixtureSourceAdapter("restricted-review", tuple(records)).snapshot()
            with self.assertRaises(MuseumError):
                resolve((state, data[1], data[2], data[3]))
        with self.assertRaisesRegex(MuseumError, "recorded review adapter not implemented"):
            resolve((replace(data[0], mode="recorded_state"), data[1], data[2], data[3]))


if __name__ == "__main__":
    unittest.main()
