"""Versioned profile and synthetic declaration controls, separate from chain evidence."""
from copy import deepcopy
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from . import authority, authority_v2
from .account_profile import AccountProjectionProfile, NAME as OLD_NAME
from .authority_admission_v2 import bind_declarations, candidates
from .canonical import MuseumError, dumps, keccak256, loads, schema_id
from .identity import EntityDeclaration, entity_index
from .independent_wire import RAW_BYTES
from .recorded_selection import select_recorded
from .review import _validate
from .schemas import NAMES as OLD_NAMES
from .test_authority import fixture
from .test_schema_inventory import assertion_document, selector
from .typed_authority_profile import TypedAuthorityProfile, ASSERTION_SCHEMA_BYTES, NAMES, SCHEMAS
from .typed_declarations import declaration_evidence, lineage, resolve_declaration, validate_continuations

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"


class DeclarationDouble:
    """Synthetic resolver only. It has no registered capture or chain authority."""
    def __init__(self):
        self.state = object(); self.profile_hash = "synthetic"; self.rows = {}

    def add(self, number, *, previous=None):
        pick = selector(); pick.update(recordHash="0x" + format(number, "064x"), pointer="/entities/0")
        entity = {"id": "urn:test:stable-type", "kind": "type", "declaringAgent": "urn:test:account",
            "names": [], "sourceRecords": [], "predecessors": [], "continuation": None}
        if previous:
            entity["sourceRecords"] = [previous["source"]]
            entity["continuation"] = {"selector": previous["source"], "declarationHash": previous["declarationHash"], "rationale": "Same account continuation"}
        record = SimpleNamespace(position=number)
        self.rows[pick["recordHash"]] = (entity, record)
        return declaration_evidence(entity, pick)

    def entity(self, state, pick, profile_hash):
        assert state is self.state and profile_hash == self.profile_hash
        return self.rows[pick["recordHash"]]

    def _prior(self, current, pick):
        previous = self.rows[pick["recordHash"]][1]
        authority.need(previous.position < current.position, "semantic evidence must precede this publication")
        return previous


class TypedAuthorityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.old = AccountProjectionProfile(ROOT); cls.profile = TypedAuthorityProfile(ROOT)

    def test_v1_documents_and_profile_hash_are_unchanged(self):
        self.assertEqual(self.old.profile_hash, "0xa7c728732beeb6fa94be1e870cd54dc470a6050986e084393e7308a1b542075f")
        for name, document in self.old.documents.items():
            self.assertEqual(self.profile.documents[name], document)
            self.assertEqual(document[1], (ROOT / "account-profile" / (name + ".json")).read_bytes())
        self.assertEqual(loads(self.profile.profile_bytes)["supersedesSchemaId"], schema_id(OLD_NAME))
        self.assertNotEqual(self.profile.profile_hash, self.old.profile_hash)
        with self.assertRaisesRegex(MuseumError, "pin mismatch"): TypedAuthorityProfile(ROOT, expected_hash=self.old.profile_hash)

    def test_old_schema_rejects_type_while_new_schema_requires_explicit_continuation(self):
        from .review import ASSERTION_SCHEMA_BYTES as old_schema
        payload = assertion_document()
        payload["entities"] = [{"id": "urn:test:type", "kind": "type", "names": [],
            "declaringAgent": "urn:test:account", "sourceRecords": [selector()], "predecessors": []}]
        with self.assertRaises(MuseumError): _validate(old_schema, dumps(payload))
        payload["profileSchemaId"] = schema_id(NAMES[0]); payload["profileHash"] = self.profile.profile_hash
        with self.assertRaises(MuseumError): _validate(ASSERTION_SCHEMA_BYTES, dumps(payload))
        payload["entities"][0]["continuation"] = None
        self.assertEqual(_validate(ASSERTION_SCHEMA_BYTES, dumps(payload)), payload)
        self.assertEqual(loads(SCHEMAS[NAMES[1]])["x-stream-profile"]["supersedesSchemaId"], schema_id(OLD_NAMES[1]))

    def test_typed_profile_projects_declared_type_under_separate_kind_policy(self):
        declaration = EntityDeclaration("urn:test:type", "type", "hash", "/entities/0", "urn:test:account")
        with self.assertRaisesRegex(MuseumError, "unsupported selected entity kind"):
            entity_index((declaration,), {("hash", "/entities/0"): "urn:test:account"}, ())
        selected, _ = entity_index((declaration,), {("hash", "/entities/0"): "urn:test:account"}, (), allowed_kinds=self.profile.entity_kinds)
        self.assertEqual(selected, (declaration,))
        result = self.profile.linked_art.validate_and_expand(dumps({"@context": authority.CONTEXT, "id": declaration.identifier,
            "type": "Type", "_label": "Declared category"}))
        self.assertIn(b"E55_Type", result.expanded_bytes)

    def test_registered_closure_contains_exact_raw_model_and_vocabulary_bytes(self):
        index = loads(self.profile.documents["STREAM_ACCOUNT_DEPENDENCIES_V2"][1], maximum=524288)
        self.assertEqual(len(index["documents"]), 19)
        self.assertIn("https://linked.art/ns/v1/linked-art.json", {row["sourceUri"] for row in index["documents"]})
        for row in index["documents"]:
            kind, raw = self.profile.documents[row["documentName"]]
            self.assertEqual(kind, 3)
            self.assertEqual(keccak256(raw), row["contentHash"]["digest"])
            self.assertEqual(schema_id(row["documentName"]), row["documentId"])
            self.assertEqual(self.profile.document_canonicalizations[row["documentName"]], RAW_BYTES)
            self.assertEqual(len(raw), int(row["byteLength"]))
        self.assertIn(authority_v2.NAME, self.profile.documents)
        self.assertIn(authority_v2.PROFILE, self.profile.documents)
        for row in index["interpretationDocuments"]:
            self.assertEqual(keccak256(self.profile.documents[row["name"]][1]), row["contentHash"]["digest"])
        self.assertTrue(set(self.profile.document_predecessors.values()) <= {schema_id(name) for name in self.profile.documents})
        self.assertEqual(self.profile.documents[OLD_NAMES[2]][1], (ROOT / (OLD_NAMES[2] + ".json")).read_bytes())

    def test_v2_literal_and_engine_admit_type_without_upgrading_v1(self):
        row, body, request, snapshots = fixture(authority="GETTY_AAT", kind="Type")
        body["declaration"] = {"scope": "same_record", "pointer": "/entities/0"}
        row["assertion"].update(relation=authority_v2.RELATION, mappingRule=authority_v2.RULE,
            object={"literal": authority_v2.alignment_literal(body)})
        raw = dumps({"version": "1", "requests": [request]})
        with patch("socket.socket", side_effect=AssertionError("offline")):
            files = authority._reconcile(raw, [row], snapshots, request_hash=keccak256(raw), profile_hash=authority_v2.PROFILE_HASH,
                mode="synthetic_fixture_authority_reconciliation", model=self.profile.linked_art)
        self.assertEqual(loads(files["authority/report.json"])["results"][0]["status"], "resolved")
        self.assertEqual(loads(files["authority/report.json"])["sourceAuthentication"], "not_established")
        with self.assertRaises(MuseumError): authority._body(row["assertion"])
        draft = authority.reconcile_draft(raw, dumps([row["assertion"]]), snapshots, request_hash=keccak256(raw),
            assertions_hash=keccak256(dumps([row["assertion"]])), profile_hash=authority_v2.PROFILE_HASH)
        self.assertEqual(loads(draft["authority/index.json"])["resources"], [])

    def test_original_v1_self_review_keeps_its_own_profile_in_mixed_source_unit_control(self):
        # This is an internal mixed-version selection control, not a new registered capture.
        from .test_recorded_account import load_source, FIXTURE
        source = load_source(); source.profile = self.profile; source.profile_hash = self.profile.profile_hash
        policy = loads((FIXTURE / "selection.json").read_bytes()); policy["profileHash"] = source.profile_hash
        selected = select_recorded(source, dumps(policy), policy_hash=keccak256(dumps(policy)))
        reviews = [loads(e) for row in selected.selected for e in row.review_evidence]
        self.assertTrue(reviews)
        self.assertEqual({r["profileHash"] for r in reviews}, {self.old.profile_hash})

    def test_new_authority_original_cannot_acquire_v2_meaning_from_old_schema(self):
        from .test_authority_admission import admitted_fixture
        source, policy, _, _, selection = admitted_fixture(authority="GETTY_AAT", kind="Type")
        source.profile = self.profile; source.profile_hash = self.profile.profile_hash
        body = authority._body(source._assertion); body["declaration"] = {"scope": "same_record", "pointer": "/entities/0"}
        source._assertion.update(relation=authority_v2.RELATION, mappingRule=authority_v2.RULE,
            object={"literal": authority_v2.alignment_literal(body)})
        source._payload["profileHash"] = source.profile_hash
        for name, raw, pin in ((OLD_NAMES[1], self.old.assertion_schema_bytes, self.old.profile_hash),
                               (NAMES[1], ASSERTION_SCHEMA_BYTES, self.old.profile_hash)):
            source.record = lambda _, name=name, raw=raw: SimpleNamespace(selector=SimpleNamespace(schema_id=schema_id(name)), schema=raw)
            source._payload["profileHash"] = pin
            with self.subTest(name=name), patch("tools.museum.authority_admission_v2.select_recorded", return_value=selection):
                with self.assertRaisesRegex(MuseumError, "original must bind"):
                    candidates(source, policy, "synthetic")

    def test_explicit_continuation_preserves_exact_predecessor(self):
        source = DeclarationDouble(); first = source.add(1); second = source.add(2, previous=first)
        record = source.rows[second["source"]["recordHash"]][1]
        self.assertEqual(lineage(source, record, second["value"]), [first])
        validate_continuations(source, record, {"entities": [second["value"]]})

    def test_later_mapping_resolves_exact_cited_declaration_without_redeclaring(self):
        source = DeclarationDouble(); first = source.add(1)
        current = SimpleNamespace(position=2)
        source.record = lambda _: current
        payload = {"sourceRecords": [first["source"]]}
        source.payload = lambda _: payload
        assertion = {"subject": first["value"]["id"], "assertingAgent": first["value"]["declaringAgent"]}
        body = {"entityKind": "Type", "declaration": {"scope": "prior_record", "selector": first["source"],
            "declarationHash": first["declarationHash"]}}
        self.assertEqual(resolve_declaration(source, {}, assertion, body), (first, []))
        for change in ("source", "hash", "issuer", "future"):
            candidate = deepcopy(body); who = deepcopy(assertion); payload["sourceRecords"] = [first["source"]]; current.position = 2
            if change == "source": payload["sourceRecords"] = []
            elif change == "hash": candidate["declaration"]["declarationHash"] = "0x" + "88" * 32
            elif change == "issuer": who["assertingAgent"] = "urn:test:other"
            else: current.position = 1
            with self.subTest(change=change), self.assertRaises(MuseumError): resolve_declaration(source, {}, who, candidate)

    def test_v2_package_cannot_promote_the_original_v1_capture_to_typed_registration(self):
        import tempfile
        from .authority_package_v2 import build_authority_package
        from .package import write_package
        from .package_recorded import build_recorded_package
        from .test_package_recorded import inputs, pins
        original_inputs = inputs()
        original = build_recorded_package(original_inputs, root=ROOT, disclosure="public", **pins())
        request = dumps({"version": "1", "requests": [{"entityId": "urn:test:type", "entityKind": "Type", "authority": "GETTY_AAT", "sourceText": "Unit control"}]})
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "source"; write_package(original, path)
            with self.assertRaisesRegex(MuseumError, "requires registered typed profile"):
                build_authority_package(path, original.manifest_hash, request, original_inputs["selection.json"], {},
                    request_hash=keccak256(request), selection_hash=keccak256(original_inputs["selection.json"]),
                    profile_hash=authority_v2.PROFILE_HASH, disclosure="public")

    def test_continuation_rejects_changed_account_kind_identity_hash_or_publication_order(self):
        for field, value in (("declaringAgent", "urn:test:other"), ("kind", "place"), ("id", "urn:test:new"),
                             ("declarationHash", "0x" + "99" * 32), ("position", 1)):
            source = DeclarationDouble(); first = source.add(1); second = source.add(2, previous=first)
            entity, record = source.rows[second["source"]["recordHash"]]
            if field == "declarationHash": entity["continuation"][field] = value
            elif field == "position": record.position = value
            else: entity[field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError): lineage(source, record, entity)

    def test_continuation_requires_source_citation_and_bounds_eight_links(self):
        source = DeclarationDouble(); previous = source.add(1)
        for number in range(2, 10): previous = source.add(number, previous=previous)
        record = source.rows[previous["source"]["recordHash"]][1]
        self.assertEqual(len(lineage(source, record, previous["value"])), 8)
        ninth = source.add(10, previous=previous)
        with self.assertRaisesRegex(MuseumError, "eight"):
            lineage(source, source.rows[ninth["source"]["recordHash"]][1], ninth["value"])
        previous["value"]["sourceRecords"] = []
        with self.assertRaisesRegex(MuseumError, "source reference"): lineage(source, record, previous["value"])

    def test_selected_continuation_reuses_dossier_and_sibling_branches_withhold(self):
        source = DeclarationDouble(); first = source.add(1); second = source.add(2, previous=first); sibling = source.add(3, previous=first)
        def candidate(declaration):
            return {"assertion": {"subject": declaration["value"]["id"]}, "eligible": True,
                "entityDeclaration": declaration, "declarationLineage": [first]}
        plan = dumps({"entityAuthoritySet": [first["source"]], "externalEntities": []})
        rows = [candidate(second)]; bind_declarations(source, plan, rows); self.assertTrue(rows[0]["eligible"])
        rows = [candidate(second), candidate(sibling)]; bind_declarations(source, plan, rows)
        self.assertTrue(all(not row["eligible"] for row in rows))
        self.assertEqual(rows[0]["eligibilityReason"], "ambiguous_selected_declaration_branches")
        rows = [candidate(second), candidate(sibling)]; rows[1]["eligible"] = False
        bind_declarations(source, plan, rows); self.assertTrue(rows[0]["eligible"])


if __name__ == "__main__": unittest.main()
