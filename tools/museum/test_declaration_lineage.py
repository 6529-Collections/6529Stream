"""V3 semantic admission/projection units plus exact retained V1/V2 replay.

The V3 records below deliberately bypass RPC construction to test its downstream
semantic boundary. They are synthetic, not signed publications or proof that V3
documents have been registered. Old capture regressions exercise genuine replay.
"""
import copy
from pathlib import Path
from types import MappingProxyType
import unittest
from unittest.mock import patch

from .account_profile import JCS_ID, account_iri
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .declaration_lineage import declaration_graph
from .declaration_lineage_profile import (DeclarationLineageProfile, NAMES, NAME, SCHEMAS,
    ASSERTION_SCHEMA_BYTES, DEPENDENCIES_NAME)
from .declaration_lineage_projection import project_declaration_lineage
from .projection_v2 import CONTENT, CONTENT_KIND
from .recorded_projection import replay_source_bytes, output_files
from .recorded_selection import project_recorded
from .recorded_semantic import RecordedSemanticSource, CLASS, RECORD_TYPE
from .review import _selector, _validate
from .source import BoundSourceState, RecordSelector, RetainedSourceRecord
from .test_recorded_account import load_source, FIXTURE, PROFILE_HASH
from .typed_authority_profile import TypedAuthorityProfile, NAMES as V2_NAMES, SCHEMAS as V2_SCHEMAS

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
ACCOUNT = "0x" + "12" * 20
OTHER = "0x" + "34" * 20
AGENT = account_iri("31337", ACCOUNT)


class SemanticFixture:
    """Synthetic retained records using the real semantic admission methods."""
    def __init__(self, baseline, profile):
        self.source = object.__new__(RecordedSemanticSource)
        self.source.profile = profile
        self.source.profile_hash = profile.profile_hash
        self.source.anchor = baseline.anchor
        self.source.capture_bytes = dumps({"mode": "synthetic_v3_unit_capture"})
        self.source.publication_bytes = dumps({"mode": "synthetic_v3_unit_publications"})
        self.source.interpretation_bytes = dumps({"mode": "synthetic_v3_unit_interpretation"})
        self.seed = baseline.state.records[0]
        self.records = [self.seed]
        self.canonicalizations = {self.seed.selector.record_hash: baseline.canonicalizations[self.seed.selector.record_hash]}
        self.positions = {self.seed.selector.record_hash: (1, 0, 0)}
        self.publish()

    def publish(self):
        source = self.source
        source.records = MappingProxyType({r.selector.record_hash: r for r in self.records})
        source.canonicalizations = MappingProxyType(dict(self.canonicalizations))
        source.positions = MappingProxyType(dict(self.positions))
        source.accounts = frozenset(account_iri("31337", r.selector.recorder) for r in self.records)
        source._payloads = set()
        source._state = BoundSourceState("recorded_state", dumps({"mode": "synthetic_v3_unit_state",
            "records": [{"record": r.selector.record_hash, "payload": r.payload_hash,
                "authority": keccak256(r.authority_evidence), "position": [str(x) for x in self.positions[r.selector.record_hash]]}
                for r in self.records]}), tuple(self.records))

    def entity(self, identifier, name=None, *, account=ACCOUNT, change=None):
        refs = [] if change is None else [ref["selector"] for ref in change["predecessors"]]
        predecessors = [] if change is None else [self.source.entity(self.source.state, row, self.source.profile_hash)[0]["id"] for row in refs]
        return {"id": identifier, "kind": "physical_object", "names": [{"value": name or identifier,
            "language": None, "kind": "preferred"}], "declaringAgent": account_iri("31337", account),
            "sourceRecords": refs or [_selector(self.seed, "")], "predecessors": predecessors,
            "continuation": None, "lineage": copy.deepcopy(change)}

    def ref(self, row):
        value, _ = self.source.entity(self.source.state, row, self.source.profile_hash)
        return {"selector": copy.deepcopy(row), "declarationHash": keccak256(dumps(value))}

    def change(self, operation, rows, *, successors=()):
        return {"operation": operation, "predecessors": [self.ref(row) for row in rows],
            "successors": list(successors), "rationale": "Exact original declaration evidence retained."}

    def append(self, entities, *, account=ACCOUNT, version=3, payload_change=None):
        source, index = self.source, len(self.records) + 1
        schema = ASSERTION_SCHEMA_BYTES if version == 3 else V2_SCHEMAS[V2_NAMES[1]]
        schema_name = NAMES[1] if version == 3 else V2_NAMES[1]
        rule = source.profile.assertion_rules()[schema_id(schema_name)]
        refs = [_selector(self.seed, "")]
        for entity in entities:
            for row in entity["sourceRecords"]:
                if row not in refs:
                    refs.append(copy.deepcopy(row))
        assertion = {"id": "urn:lineage:assertion:" + str(index), "subject": entities[0]["id"],
            "relation": "urn:lineage:assertion", "object": {"literal": {"lexicalValue": "Original claim stays on this ID.",
                "datatype": "http://www.w3.org/2001/XMLSchema#string", "language": None, "unit": None, "precision": None}},
            "assertingAgent": account_iri("31337", account), "createdAt": "2026-09-22T00:00:00Z",
            "evidence": [{"source": {"algorithm": "1", "digest": self.seed.payload_hash,
                "canonicalizationId": self.canonicalizations[self.seed.selector.record_hash]},
                "selectorType": "whole_document", "selector": "", "basis": "documentary_evidence"}],
            "origin": "direct_statement", "reviewStatus": "unreviewed", "mappingRule": "urn:lineage:rule",
            "rationale": "Synthetic admission unit, no signed-publication claim.", "reviewEvidence": [], "corrects": [], "disputes": []}
        payload = {"profileSchemaId": rule[1], "profileHash": rule[2],
            "anchorSubject": {"kind": "collection", "subjectId": self.seed.selector.subject_id},
            "entities": copy.deepcopy(entities), "assertions": [assertion], "sourceRecords": refs, "authorityAlignments": []}
        if payload_change:
            payload_change(payload)
        raw = dumps(payload)
        selector = RecordSelector(self.seed.selector.host, keccak256(dumps([str(index), keccak256(raw)])),
            self.seed.selector.subject_id, schema_id(schema_name), keccak256(schema), RECORD_TYPE,
            account, CLASS, str(index), keccak256(dumps(["synthetic-chain", str(index)])))
        facts = dumps({"mode": "historical_independent_account", "recorder": account,
            "agentIri": account_iri("31337", account), "recordType": RECORD_TYPE, "authorizationClass": CLASS,
            "publicationPosition": [str(index), "0", "0"], "payloadHash": keccak256(raw), "subjectKind": "collection",
            "humanIdentityEstablished": False, "reviewIndependenceEstablished": False})
        record = RetainedSourceRecord(selector, raw, keccak256(raw), schema, facts, "public")
        self.records.append(record)
        self.canonicalizations[selector.record_hash] = JCS_ID
        self.positions[selector.record_hash] = (index, 0, 0)
        self.publish()
        return [_selector(record, "/entities/" + str(i)) for i in range(len(entities))]

    def admit(self, row):
        return self.source.entity(self.source.state, row, self.source.profile_hash)[0]

    def project(self, rows, claims=(), external=(), entry=project_declaration_lineage):
        source = self.source
        policy = {"mode": "recorded_account_selection", "version": "1", "sourceStateHash": source.state.commitment,
            "profileHash": source.profile_hash, "sourceAuthoritySet": list(claims), "reviewerAuthoritySet": [],
            "singleValuedRelations": [CONTENT_KIND, CONTENT], "independentReviewRequired": False, "allowAccountSelfReview": False}
        raw = dumps(policy)
        plan = {"mode": "recorded_account_resource_projection", "version": "account-3", "sourceStateHash": source.state.commitment,
            "profileHash": source.profile_hash, "selectionPolicyHash": keccak256(raw), "crosswalkHash": source.profile.crosswalk_hash,
            "entityAuthoritySet": list(rows), "externalEntities": [{"id": account, "kind": "account"} for account in sorted(source.accounts)] + list(external)}
        plan_raw = dumps(plan)
        return entry(source, raw, plan_raw, selection_hash=keccak256(raw), plan_hash=keccak256(plan_raw))


class DeclarationLineageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = load_source()
        cls.profile = DeclarationLineageProfile(ROOT)

    def setUp(self):
        self.f = SemanticFixture(self.baseline, self.profile)

    def base(self, identifier="urn:lineage:original", name="Original"):
        row, = self.f.append([self.f.entity(identifier, name)])
        self.f.admit(row)
        return row

    def test_definition_closure_preserves_every_old_byte_rule_and_registration_predecessor(self):
        old = TypedAuthorityProfile(ROOT)
        self.assertEqual(self.baseline.profile_hash, PROFILE_HASH)
        for name, definition in old.documents.items():
            self.assertEqual(self.profile.documents[name], definition, name)
            self.assertEqual(self.profile.document_canonicalizations[name], old.document_canonicalizations[name])
        self.assertEqual({key: self.profile.assertion_rules()[key] for key in old.assertion_rules()}, old.assertion_rules())
        index = loads(self.profile.documents[DEPENDENCIES_NAME][1], maximum=524288, canonical=True)
        self.assertEqual(len(index["documents"]), 19)
        for row in index["interpretationDocuments"]:
            kind, raw = self.profile.documents[row["name"]]
            self.assertEqual((row["kind"], row["byteLength"], row["contentHash"]["digest"]), (str(kind), str(len(raw)), keccak256(raw)))
        self.assertTrue(set(self.profile.document_predecessors.values()) <= {schema_id(name) for name in self.profile.documents})
        for name, (_, raw) in self.profile.documents.items():
            if name not in old.documents:
                self.assertEqual((ROOT / "declaration-lineage-profile" / (name + ".json")).read_bytes(), raw)

    def test_old_schema_rejects_lineage_and_v3_requires_it_without_dual_continuation(self):
        row = self.base()
        body = loads(self.f.source.record(row).payload)
        with self.assertRaises(MuseumError): _validate(V2_SCHEMAS[V2_NAMES[1]], dumps(body))
        for mutation in (lambda b: b["entities"][0].pop("lineage"),
                         lambda b: b["entities"][0].update(continuation={**self.f.ref(row), "rationale": "two paths"})):
            changed = copy.deepcopy(body); mutation(changed)
            with self.assertRaises(MuseumError): _validate(ASSERTION_SCHEMA_BYTES, dumps(changed))

    def test_correction_projects_exact_new_name_retaining_original_and_authority(self):
        old = self.base()
        entity = self.f.entity("urn:lineage:original", "Corrected", change=self.f.change("correction", [old]))
        current, = self.f.append([entity])
        before = self.f.source.record(old).payload
        result = self.f.project([current])
        self.assertEqual(loads(result.resources[0].content)["identified_by"][0]["content"], "Corrected")
        graph, = loads(result.sidecar, maximum=67108864)["declarationLineage"]
        self.assertEqual([node["value"]["names"][0]["value"] for node in graph["nodes"]], ["Corrected", "Original"])
        self.assertEqual(graph["nodes"][1]["source"], old)
        self.assertEqual(graph["nodes"][1]["authority"]["agentIri"], AGENT)
        self.assertEqual(graph["nodes"][1]["authorityEvidenceHash"], keccak256(self.f.source.record(old).authority_evidence))
        self.assertEqual(self.f.source.record(old).payload, before)
        coverage = loads(result.coverage, maximum=67108864)
        ancestor = next(row for row in coverage if row["recordHash"] == old["recordHash"])
        self.assertTrue(ancestor["fields"])
        self.assertTrue(all(row["disposition"] == "retained_stream_only" for row in ancestor["fields"]))
        report = loads(result.report, maximum=67108864)
        self.assertEqual(report["declarationLineageHash"], keccak256(dumps([graph])))
        self.assertEqual(report["sidecarHash"], keccak256(result.sidecar))

    def test_same_iri_or_two_selected_branches_never_silently_overwrite(self):
        old = self.base()
        a, = self.f.append([self.f.entity("urn:lineage:original", "A", change=self.f.change("correction", [old]))])
        b, = self.f.append([self.f.entity("urn:lineage:original", "B", change=self.f.change("correction", [old]))])
        for selected in ([old, a], [a, b]):
            with self.subTest(selected=selected), self.assertRaisesRegex(MuseumError, "ambiguous selected identity"):
                self.f.project(selected)
        self.assertEqual(loads(self.f.project([a]).resources[0].content)["identified_by"][0]["content"], "A")

    def test_merge_projects_three_distinct_identities_and_does_not_redirect_old_claim(self):
        a = self.base("urn:lineage:a", "A"); b = self.base("urn:lineage:b", "B")
        merged, = self.f.append([self.f.entity("urn:lineage:merged", "Merged", change=self.f.change("merge", [a, b]))])
        claim = dict(a, pointer="/assertions/0")
        result = self.f.project([a, b, merged], [claim])
        self.assertEqual({r.identifier for r in result.resources}, {"urn:lineage:a", "urn:lineage:b", "urn:lineage:merged"})
        sidecar = loads(result.sidecar, maximum=67108864)
        self.assertEqual(sidecar["selectedClaims"][0]["assertion"]["subject"], "urn:lineage:a")
        graph = sidecar["declarationLineage"][-1]
        self.assertEqual(len(graph["edges"]), 2)
        self.assertTrue(all(edge["operation"] == "merge" for edge in graph["edges"]))
        self.assertFalse(any("equivalent" in loads(r.content) for r in result.resources))

    def test_selected_or_external_predecessor_cannot_substitute_unrelated_authority_or_kind(self):
        a = self.base("urn:lineage:a"); b = self.base("urn:lineage:b")
        merged, = self.f.append([self.f.entity("urn:lineage:merged", change=self.f.change("merge", [a, b]))])
        foreign, = self.f.append([self.f.entity("urn:lineage:a", account=OTHER)], account=OTHER)
        with self.assertRaisesRegex(MuseumError, "unrelated declaration"):
            self.f.project([foreign, b, merged])
        with self.assertRaisesRegex(MuseumError, "external lineage predecessor kind"):
            self.f.project([b, merged], external=[{"id": "urn:lineage:a", "kind": "person"}])
        result = self.f.project([b, merged], external=[{"id": "urn:lineage:a", "kind": "physical_object"}])
        self.assertEqual(len(result.resources), 2)
        corrected, = self.f.append([self.f.entity("urn:lineage:a", "Corrected A", change=self.f.change("correction", [a]))])
        self.assertEqual(len(self.f.project([corrected, b, merged]).resources), 3)

    def test_existing_public_projection_routes_v3_and_cannot_bypass_lineage(self):
        a = self.base("urn:lineage:a"); b = self.base("urn:lineage:b")
        merged, = self.f.append([self.f.entity("urn:lineage:merged", change=self.f.change("merge", [a, b]))])
        explicit = self.f.project([a, b, merged])
        generic = self.f.project([a, b, merged], entry=project_recorded)
        self.assertEqual(generic, explicit)
        self.assertTrue(loads(generic.sidecar, maximum=67108864)["declarationLineage"])
        foreign, = self.f.append([self.f.entity("urn:lineage:a", account=OTHER)], account=OTHER)
        with self.assertRaisesRegex(MuseumError, "unrelated declaration"):
            self.f.project([foreign, b, merged], entry=project_recorded)

    def test_split_projects_complete_explicit_cohort_and_retains_predecessor(self):
        old = self.base()
        ids = ["urn:lineage:left", "urn:lineage:right"]
        change = self.f.change("split", [old], successors=ids)
        rows = self.f.append([self.f.entity(identifier, change=change) for identifier in ids])
        result = self.f.project([old, *rows])
        self.assertEqual({r.identifier for r in result.resources}, {"urn:lineage:original", *ids})
        graphs = loads(result.sidecar, maximum=67108864)["declarationLineage"]
        self.assertEqual([g["edges"][0]["successorCohort"] for g in graphs[1:]], [ids, ids])

    def test_split_missing_duplicate_or_different_cohort_and_rewritten_rationale_reject(self):
        old = self.base()
        ids = ["urn:lineage:left", "urn:lineage:right"]
        change = self.f.change("split", [old], successors=ids)
        entities = [self.f.entity(identifier, change=change) for identifier in ids]
        variants = [entities[:1], [entities[0], copy.deepcopy(entities[0])]]
        for key, value in (("rationale", "rewritten"), ("successors", [*ids, "urn:lineage:extra"])):
            variant = copy.deepcopy(entities); variant[1]["lineage"][key] = value; variants.append(variant)
        for variant in variants:
            row = self.f.append(variant)[0]
            with self.subTest(variant=variant), self.assertRaises(MuseumError): self.f.admit(row)

    def test_all_three_operations_refuse_foreign_original_account(self):
        own = self.base("urn:lineage:own")
        foreign, = self.f.append([self.f.entity("urn:lineage:foreign", account=OTHER)], account=OTHER)
        for operation, ids, identifier, successors in (
            ("correction", [foreign], "urn:lineage:foreign", []),
            ("merge", [own, foreign], "urn:lineage:merged", []),
            ("split", [foreign], "urn:lineage:left", ["urn:lineage:left", "urn:lineage:right"])):
            change = self.f.change(operation, ids, successors=successors)
            rows = self.f.append([self.f.entity(i, change=change) for i in successors or [identifier]])
            with self.subTest(operation=operation), self.assertRaisesRegex(MuseumError, "authenticated declaring account"):
                self.f.admit(rows[0])

    def test_rehashed_claimed_agent_cannot_replace_actual_attestor(self):
        old = self.base()
        change = self.f.change("correction", [old])
        row, = self.f.append([self.f.entity("urn:lineage:original", change=change)], account=OTHER)
        with self.assertRaisesRegex(MuseumError, "entity declaring account"):
            self.f.admit(row)

    def test_every_original_selector_word_and_declaration_hash_are_bound(self):
        old = self.base()
        for field in old:
            change = self.f.change("correction", [old])
            ref = change["predecessors"][0]["selector"]
            ref[field] = ("/entities/1" if field == "pointer" else str(int(ref[field]) + 1) if field == "recordIndex"
                else "ARTIST_SIGNER" if field == "authorizationClass" else "0x" + "ab" * (20 if field in ("host", "recorder") else 32))
            entity = self.f.entity("urn:lineage:original")
            entity.update(lineage=change, predecessors=["urn:lineage:original"], sourceRecords=[ref])
            row, = self.f.append([entity])
            with self.subTest(field=field), self.assertRaises(MuseumError): self.f.admit(row)
        change = self.f.change("correction", [old]); change["predecessors"][0]["declarationHash"] = "0x" + "ab" * 32
        row, = self.f.append([self.f.entity("urn:lineage:original", change=change)])
        with self.assertRaisesRegex(MuseumError, "predecessor hash"): self.f.admit(row)

    def test_uncited_predecessor_in_entity_or_payload_and_forward_publication_reject(self):
        old = self.base()
        change = self.f.change("correction", [old])
        for mutation in (lambda b: b["entities"][0].update(sourceRecords=[_selector(self.f.seed, "")]),
                         lambda b: b.update(sourceRecords=[_selector(self.f.seed, "")])):
            row, = self.f.append([self.f.entity("urn:lineage:original", change=change)], payload_change=mutation)
            with self.assertRaisesRegex(MuseumError, "must be cited"): self.f.admit(row)
        row, = self.f.append([self.f.entity("urn:lineage:original", change=change)])
        position = self.f.positions[old["recordHash"]]
        self.f.positions[old["recordHash"]] = self.f.positions[row["recordHash"]]
        self.f.publish()
        with self.assertRaisesRegex(MuseumError, "precede"): self.f.admit(row)
        self.f.positions[old["recordHash"]] = position; self.f.publish(); self.f.admit(row)

    def test_kind_id_and_predecessor_order_cannot_be_rewritten(self):
        a = self.base("urn:lineage:a"); b = self.base("urn:lineage:b")
        variants = []
        correction = self.f.entity("urn:lineage:a", change=self.f.change("correction", [a]))
        for field, value in (("id", "urn:lineage:replacement"), ("kind", "person")):
            changed = copy.deepcopy(correction); changed[field] = value; variants.append(changed)
        merged = self.f.entity("urn:lineage:merged", change=self.f.change("merge", [a, b]))
        merged["predecessors"].reverse(); variants.append(merged)
        for entity in variants:
            row, = self.f.append([entity])
            with self.assertRaises(MuseumError): self.f.admit(row)

    def test_merge_arity_duplicate_ref_and_split_recycled_identity_reject(self):
        a = self.base("urn:lineage:a"); b = self.base("urn:lineage:b")
        for rows in ([a], [a, a]):
            entity = self.f.entity("urn:lineage:new", change=self.f.change("merge", rows))
            row, = self.f.append([entity])
            with self.assertRaises(MuseumError): self.f.admit(row)
        merged, = self.f.append([self.f.entity("urn:lineage:merged", change=self.f.change("merge", [a, b]))])
        self.f.admit(merged)
        ids = ["urn:lineage:a", "urn:lineage:new"]
        change = self.f.change("split", [merged], successors=ids)
        rows = self.f.append([self.f.entity(identifier, change=change) for identifier in ids])
        with self.assertRaisesRegex(MuseumError, "ancestor identity"): self.f.admit(rows[0])

    def test_eight_links_allowed_ninth_rejected_cached_and_uncached_with_depth_restored(self):
        row = self.base()
        for number in range(8):
            row, = self.f.append([self.f.entity("urn:lineage:original", "revision " + str(number), change=self.f.change("correction", [row]))])
            self.f.admit(row)
        self.assertEqual(len(declaration_graph(self.f.source, row)["nodes"]), 9)
        bad, = self.f.append([self.f.entity("urn:lineage:original", change=self.f.change("correction", [row]))])
        for cached in (False, True):
            self.f.source._payloads.clear()
            if cached:
                self.f.admit(row)
            with self.subTest(cached=cached), self.assertRaisesRegex(MuseumError, "eight links"):
                self.f.admit(bad)
            self.assertEqual(self.f.source._declaration_admission_depth, 0)
            self.assertNotIn(bad["recordHash"], self.f.source._payloads)
            self.f.admit(row)

    def test_shared_merge_ancestor_cannot_hide_ninth_link_after_shorter_branch(self):
        row = self.base()
        for number in range(6):
            row, = self.f.append([self.f.entity("urn:lineage:original", str(number), change=self.f.change("correction", [row]))])
            self.f.admit(row)
        original = row
        for step in range(2):
            ids = ["urn:lineage:split:" + str(step) + suffix for suffix in (":a", ":b")]
            change = self.f.change("split", [row], successors=ids)
            row = self.f.append([self.f.entity(identifier, change=change) for identifier in ids])[0]
            self.f.admit(row)
        bad, = self.f.append([self.f.entity("urn:lineage:merge", change=self.f.change("merge", [original, row]))])
        self.f.admit(row)  # Original admission cache must not bypass full DAG depth.
        with self.assertRaisesRegex(MuseumError, "eight links"):
            self.f.admit(bad)

    def test_original_subject_and_profile_are_bound_before_lineage(self):
        old = self.base()
        change = self.f.change("correction", [old])
        for mutation in (lambda body: body["anchorSubject"].update(subjectId="0x" + "ab" * 32),
                         lambda body: body.update(profileHash=self.baseline.profile_hash)):
            row, = self.f.append([self.f.entity("urn:lineage:original", change=change)], payload_change=mutation)
            with self.assertRaisesRegex(MuseumError, "profile or subject"):
                self.f.admit(row)

    def test_prior_v2_continuation_remains_exact_under_v3_correction(self):
        original = self.f.entity("urn:lineage:original"); original.pop("lineage")
        old, = self.f.append([original], version=2)
        continued = copy.deepcopy(original)
        continued.update(continuation={**self.f.ref(old), "rationale": "Original V2 continuation."}, sourceRecords=[old])
        v2, = self.f.append([continued], version=2)
        current, = self.f.append([self.f.entity("urn:lineage:original", "V3", change=self.f.change("correction", [v2]))])
        graph = declaration_graph(self.f.source, current)
        self.assertEqual([edge["operation"] for edge in graph["edges"]], ["correction", "continuation"])
        self.assertEqual(graph["nodes"][-1]["declarationHash"], keccak256(dumps(original)))

    def test_unselected_invalid_lineage_does_not_veto_selected_original(self):
        old = self.base()
        change = self.f.change("correction", [old]); change["predecessors"][0]["declarationHash"] = "0x" + "ab" * 32
        bad, = self.f.append([self.f.entity("urn:lineage:original", change=change)])
        result = self.f.project([old])
        sidecar = loads(result.sidecar, maximum=67108864)
        row = next(r for r in sidecar["publicSources"] if r["selector"]["recordHash"] == bad["recordHash"])
        self.assertEqual(row["payloadHex"], "0x" + self.f.source.record(bad).payload.hex())
        self.assertFalse(row["inventoryScope"])

    def test_old_actual_account_projection_remains_byte_exact_and_v3_pin_cannot_promote_it(self):
        selection, plan = (FIXTURE / "selection.json").read_bytes(), (FIXTURE / "plan.json").read_bytes()
        with patch("socket.socket", side_effect=AssertionError("offline replay opened network")):
            result = project_recorded(self.baseline, selection, plan, selection_hash=keccak256(selection), plan_hash=keccak256(plan))
        for name, raw in output_files(result).items():
            self.assertEqual(raw, (FIXTURE / name).read_bytes())
        with self.assertRaisesRegex(MuseumError, "concrete declaration lineage profile"):
            project_declaration_lineage(self.baseline, selection, plan, selection_hash=keccak256(selection), plan_hash=keccak256(plan))
        from .test_recorded_account import SOURCE_HASH, PUBLICATION_HASH, INTERPRETATION_HASH
        inputs = {name: (FIXTURE / name).read_bytes() for name in ("anchor.json", "transcript.json", "publication-hints.json",
            "publication-transcript.json", "interpretation-transcript.json")}
        with self.assertRaises(MuseumError):
            replay_source_bytes(ROOT, inputs, source_hash=SOURCE_HASH, publication_hash=PUBLICATION_HASH,
                interpretation_hash=INTERPRETATION_HASH, profile_hash=self.profile.profile_hash)


if __name__ == "__main__":
    unittest.main()
