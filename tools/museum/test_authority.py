"""Synthetic reconciliation controls; these assertions are not actual chain records."""
import copy
import unittest
from unittest.mock import patch

from .authority import (BODY_SCHEMA_BYTES, DATATYPE, GVP, P31, PROFILE_HASH, RELATION, RDF_TYPE, RULE, SKOS,
    _reconcile, alignment_literal, reconcile_draft)
from .authority_snapshot import FOAF_FOCUS, canonical_authority_iri, parse_snapshot
from .canonical import MuseumError, dumps, keccak256, loads
from .exhibitions import fields
from .preservation_graph import validator
from .test_authority_snapshot import descriptor


def fixture(n=1, *, authority="GETTY_TGN", kind="Place", local="urn:test:local-place", label="Milos", identity=None):
    identifier = identity or ("Q" + str(n) if authority == "WIKIDATA" else str(n))
    iri = canonical_authority_iri(authority, identifier)
    typ = {("GETTY_TGN", "Place"): GVP + "PhysPlaceConcept", ("GETTY_AAT", "Type"): SKOS + "Concept",
        ("GETTY_ULAN", "Person"): GVP + "PersonConcept", ("GETTY_ULAN", "Group"): GVP + "GroupConcept",
        ("VIAF", "Person"): "http://xmlns.com/foaf/0.1/Person", ("WIKIDATA", "Person"): "http://www.wikidata.org/entity/Q5"}[(authority, kind)]
    predicate = P31 if authority == "WIKIDATA" else RDF_TYPE
    graph = {iri: {predicate: [{"type": "uri", "value": typ}], SKOS + "prefLabel": [{"type": "literal", "value": label, "lang": "en"}]}}
    if kind == "Place":
        graph[iri][FOAF_FOCUS] = [{"type": "uri", "value": iri + "-place"}]
        graph[iri][SKOS + "broader"] = [{"type": "uri", "value": "http://vocab.getty.edu/tgn/1000001"}]
    raw = dumps(graph); desc, pin = descriptor(raw, authority=authority, identifier=identifier)
    parsed = parse_snapshot(desc, raw, descriptor_hash=pin); metadata = loads(desc)
    path = "authorities/" + str(n) + ".rdf.json"
    def fact(row):
        return {"subject": row["subject"], "predicate": row["predicate"], "object": row["object"]["value"], "sourcePointer": row["sourcePointer"]}
    alignment = {"entityId": local, "authority": authority, "identifier": identifier, "canonicalIri": iri,
        "focusIri": parsed["focusIri"], "matchKind": "equivalent_entity",
        "snapshotRef": {"path": path, **{key: metadata[key] for key in ("contentHash", "byteLength", "mediaType")}},
        "retrievedAt": metadata["retrievedAt"], "authorityRevision": "not_supplied",
        "labelAtReview": {"value": label, "language": "en", "kind": "preferred"},
        "basis": "Synthetic author supplied type and catalog context, never a deployed assertion.", "assertionId": "urn:test:alignment:" + str(n)}
    body = {"alignment": alignment, "entityKind": kind, "typeEvidence": [fact(parsed["typeFacts"][0])],
        "contextChecks": [] if kind != "Place" else [{"scope": "authority_catalog_hierarchy", "fact": fact(parsed["hierarchyFacts"][0]),
            "localStatement": "Artist's exact island context e\u0301.", "conclusion": "consistent", "rationale": "Synthetic reviewed catalog association."}], "change": None}
    assertion = {"id": alignment["assertionId"], "subject": local, "relation": RELATION,
        "object": {"literal": alignment_literal(body)}, "assertingAgent": "urn:test:mapper", "createdAt": "2026-09-16T12:34:57Z",
        "evidence": [{"source": metadata["contentHash"], "selectorType": "whole_document", "selector": "", "basis": "documentary_evidence"}],
        "origin": "human_mapping", "reviewStatus": "unreviewed", "mappingRule": RULE, "rationale": "Synthetic identity mapping rationale.",
        "reviewEvidence": [], "corrects": [], "disputes": []}
    candidate = {"assertion": assertion, "eligible": True, "eligibilityReason": "fixture_not_eligible", "source": {"synthetic": True},
        "reviews": [{"synthetic": True}], "basis": "synthetic_review_control", "position": ["1", "0", str(n)]}
    request = {"entityId": local, "entityKind": kind, "authority": authority, "sourceText": "Exact e\u0301 local wording\r\nkept."}
    return candidate, body, request, {path: (desc, raw, pin)}


def update(candidate, body):
    candidate["assertion"]["object"]["literal"] = alignment_literal(body)


class AuthorityReconciliation(unittest.TestCase):
    @classmethod
    def setUpClass(cls): cls.model = validator("schemas/museum")

    def run_fixture(self, rows, requests, snapshots):
        raw = dumps({"version": "1", "requests": requests})
        return _reconcile(raw, rows, snapshots, request_hash=keccak256(raw), profile_hash=PROFILE_HASH,
            mode="synthetic_fixture_authority_reconciliation", model=self.model)

    def test_five_authority_codes_and_qualified_equivalence(self):
        for authority, kind in (("GETTY_TGN", "Place"), ("GETTY_ULAN", "Person"), ("GETTY_AAT", "Type"), ("VIAF", "Person"), ("WIKIDATA", "Person")):
            row, body, request, snapshots = fixture(authority=authority, kind=kind)
            with self.subTest(authority=authority), patch("socket.socket", side_effect=AssertionError("offline")):
                files = self.run_fixture([row], [request], snapshots)
            report = loads(files["authority/report.json"])
            self.assertEqual(report["results"][0]["status"], "resolved")
            self.assertEqual(report["sourceAuthentication"], "not_established")
            self.assertFalse(any(report["claims"].values()))
            resource = loads(files[loads(files["authority/index.json"])["resources"][0]["path"]])
            self.assertEqual(resource["equivalent"][0]["id"], body["alignment"]["canonicalIri"])
            self.assertNotIn("sameAs", dumps(resource).decode())
            self.assertEqual(loads(files["authority/sidecar.json"])[0]["assertion"], row["assertion"])
            self.assertEqual([(v["sourcePath"], v["value"]) for v in loads(files["authority/coverage.json"], maximum=524288)], list(fields(row["assertion"])))

    def test_draft_claimed_review_never_emits_equivalence(self):
        row, body, request, snapshots = fixture(); row["assertion"]["reviewStatus"] = "reviewed"
        raw = dumps({"version": "1", "requests": [request]}); claims = dumps([row["assertion"]])
        files = reconcile_draft(raw, claims, snapshots, request_hash=keccak256(raw), assertions_hash=keccak256(claims), profile_hash=PROFILE_HASH)
        self.assertEqual(loads(files["authority/index.json"])["resources"], [])
        self.assertEqual(loads(files["authority/report.json"])["mode"], "draft_preview")

    def test_ambiguous_matches_have_no_order_name_or_recency_winner(self):
        first, _, request, one = fixture(1); second, _, _, two = fixture(2)
        left = self.run_fixture([first, second], [request], one | two)
        right = self.run_fixture([second, first], [request], two | one)
        self.assertEqual(left, right)
        report = loads(left["authority/report.json"])
        self.assertEqual(report["results"][0]["status"], "ambiguous")
        self.assertEqual(loads(left["authority/index.json"])["resources"], [])

    def test_weaker_and_no_match_preserve_local_source_without_identity(self):
        row, body, request, snapshots = fixture()
        for kind in ("close_match", "related_reference"):
            body["alignment"]["matchKind"] = kind; update(row, body)
            result = self.run_fixture([row], [request], snapshots)
            self.assertEqual(loads(result["authority/index.json"])["resources"], [])
        empty = self.run_fixture([], [request], {})
        report = loads(empty["authority/report.json"])
        self.assertEqual(report["results"][0]["status"], "unresolved")
        self.assertEqual(report["results"][0]["sourceText"], request["sourceText"])

    def test_type_context_and_focus_fail_closed(self):
        row, body, request, snapshots = fixture()
        no_type = copy.deepcopy(body); no_type["entityKind"] = "Person"; request_person = dict(request, entityKind="Person")
        update(row, no_type); files = self.run_fixture([row], [request_person], snapshots)
        self.assertIn("unsupported_or_mismatched_entity_type", loads(files["authority/sidecar.json"])[0]["reasons"])
        for checks in ([], [dict(body["contextChecks"][0], conclusion="conflicting")]):
            bad = dict(body, contextChecks=checks); update(row, bad)
            self.assertEqual(loads(self.run_fixture([row], [request], snapshots)["authority/index.json"])["resources"], [])
        body["alignment"]["focusIri"] = body["alignment"]["canonicalIri"]; update(row, body)
        with self.assertRaisesRegex(MuseumError, "focus"): self.run_fixture([row], [request], snapshots)

    def test_canonical_identity_reviewed_label_and_exact_pointer_are_checked(self):
        for mutate in (
            lambda b: b["alignment"].update(canonicalIri=b["alignment"]["canonicalIri"].replace("http:", "https:")),
            lambda b: b["alignment"]["labelAtReview"].update(value="Same name from another version"),
            lambda b: b["typeEvidence"][0].update(sourcePointer="/invented"),
            lambda b: b["alignment"].update(authorityRevision="invented"),
        ):
            row, body, request, snapshots = fixture(); mutate(body); update(row, body)
            with self.assertRaises(MuseumError): self.run_fixture([row], [request], snapshots)

    def test_changed_snapshot_never_rewrites_history(self):
        old, old_body, request, old_snap = fixture(9)
        new, body, _, new_snap = fixture(10, identity="9", label="New official label")
        body["change"] = {"previousAssertionId": old["assertion"]["id"], "previousAssertionHash": keccak256(dumps(old["assertion"])),
            "previousSnapshotRef": old_body["alignment"]["snapshotRef"], "disposition": "rename", "rationale": "New source revision; old label retained."}
        new["assertion"]["corrects"] = [old["assertion"]["id"]]; update(new, body)
        files = self.run_fixture([new, old], [request], new_snap | old_snap)
        sidecar = loads(files["authority/sidecar.json"], maximum=524288)
        retained = next(row for row in sidecar if row["assertion"]["id"] == old["assertion"]["id"])
        self.assertEqual(retained["assertion"], old["assertion"])
        self.assertEqual(retained["supersededBy"], [new["assertion"]["id"]])
        self.assertEqual(len(loads(files["authority/snapshot-index.json"], maximum=524288)), 2)
        new["assertion"]["assertingAgent"] = "urn:test:other-author"
        files = self.run_fixture([old, new], [request], old_snap | new_snap)
        self.assertIn("unresolved_predecessor_or_disposition", next(r for r in loads(files["authority/sidecar.json"], maximum=524288) if r["assertion"]["id"] == new["assertion"]["id"])["reasons"])

    def test_missing_snapshot_and_unreviewed_alternative_cannot_suppress_eligible(self):
        first, _, request, one = fixture(1); second, _, _, _ = fixture(2)
        second.update(eligible=False, eligibilityReason="not_selected_review")
        files = self.run_fixture([first, second], [request], one)
        self.assertEqual(loads(files["authority/report.json"])["results"][0]["status"], "resolved")
        self.assertIn("snapshot_not_supplied", loads(files["authority/sidecar.json"])[1]["reasons"])

    def test_automated_suggestions_start_unreviewed_and_original_body_is_closed(self):
        row, body, request, snapshots = fixture(); row["assertion"].update(origin="automated_mapping", reviewStatus="reviewed")
        with self.assertRaisesRegex(MuseumError, "automated suggestion"): self.run_fixture([row], [request], snapshots)
        body["claimedVerified"] = True
        with self.assertRaises(MuseumError): alignment_literal(body)

    def test_snapshot_path_scope_duplicates_and_external_pins_reject(self):
        row, _, request, snapshots = fixture()
        with self.assertRaises(MuseumError): self.run_fixture([row, row], [request], snapshots)
        with self.assertRaises(MuseumError): self.run_fixture([row], [request, request], snapshots)
        with self.assertRaises(MuseumError): self.run_fixture([row], [request], {"../bad": next(iter(snapshots.values()))})
        raw = dumps({"version": "1", "requests": [request]})
        with self.assertRaises(MuseumError): _reconcile(raw, [], {}, request_hash="0x" + "01" * 32,
            profile_hash=PROFILE_HASH, mode="synthetic_fixture_authority_reconciliation")

    def test_alternate_authority_hosts_and_account_namespaces_are_not_local_entities(self):
        _, _, request, _ = fixture()
        for identifier in ("http://www.viaf.org/viaf/24604287", "https://wikidata.org/entity/Q42",
            "https://VOCAB.GETTY.EDU:443/tgn/1", "http://vocab.getty.edu./tgn/1", "eip155:1:0x123",
            "urn:6529stream:account:1:0x123"):
            with self.subTest(identifier=identifier), self.assertRaisesRegex(MuseumError, "cannot be a local entity"):
                self.run_fixture([], [dict(request, entityId=identifier)], {})

    def test_recorded_type_path_is_explicitly_unsupported(self):
        row, _, request, snapshots = fixture(authority="GETTY_AAT", kind="Type")
        raw = dumps({"version": "1", "requests": [request]})
        files = _reconcile(raw, [row], snapshots, request_hash=keccak256(raw), profile_hash=PROFILE_HASH,
            mode="recorded_account_authority_reconciliation")
        self.assertEqual(loads(files["authority/report.json"])["results"][0]["reasonCode"], "recorded_type_declaration_unsupported")
        self.assertEqual(loads(files["authority/index.json"])["resources"], [])

    def test_deprecation_and_contradictory_focus_do_not_silently_resolve(self):
        for change in ("obsolete", "replacement", "person_focus"):
            row, body, request, snapshots = fixture(); path, (desc, raw, _) = next(iter(snapshots.items()))
            graph = loads(raw); root = body["alignment"]["canonicalIri"]
            if change == "obsolete": graph[root][RDF_TYPE].append({"type": "uri", "value": GVP + "ObsoleteSubject"})
            elif change == "replacement": graph[root]["http://purl.org/dc/terms/isReplacedBy"] = [{"type": "uri", "value": "http://vocab.getty.edu/tgn/2"}]
            else: graph[root + "-place"] = {RDF_TYPE: [{"type": "uri", "value": "http://schema.org/Person"}]}
            raw = dumps(graph); desc, pin = descriptor(raw, identifier="1"); metadata = loads(desc)
            body["alignment"]["snapshotRef"].update({key: metadata[key] for key in ("contentHash", "byteLength")}); update(row, body)
            files = self.run_fixture([row], [request], {path: (desc, raw, pin)})
            self.assertEqual(loads(files["authority/index.json"])["resources"], [])
            self.assertEqual(loads(files["authority/report.json"])["results"][0]["status"], "unresolved")


if __name__ == "__main__": unittest.main()
