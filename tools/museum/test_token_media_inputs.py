"""Pure token-media preparation controls; no compiler, RPC, or native process."""
from copy import deepcopy
import unittest

from .account_profile import account_iri
from .authority_v2 import _body
from .canonical import MuseumError, dumps, keccak256, loads, schema_id, subject_id
from .current_authority_capture import (alignment_payload as collection_alignment_payload,
    declaration_payload as collection_declaration_payload, review_payload as collection_review_payload,
    synthetic_snapshot, validate_snapshot)
from .current_media_inputs import PREFIX, payloads as collection_payloads
from .independent_wire import ZERO
from .token_media_inputs import (token_alignment_payload, token_declaration_payload, token_payloads,
    token_review_payload, token_scope)
from .typed_authority_profile import TypedAuthorityProfile


CORE = "0x" + "11" * 20
ATTESTOR = "0x" + "22" * 20
PROFILE = "0x" + "33" * 32
DIGEST = "0x" + "44" * 32
STAMP = "2026-09-16T00:00:00Z"


def selector(subject):
    return {"host": ATTESTOR, "recordHash": "0x" + "55" * 32, "subjectId": subject,
        "schemaId": "0x" + "66" * 32, "schemaHash": "0x" + "77" * 32,
        "recordType": schema_id("INDEPENDENT_SEMANTIC_ASSERTION"), "recorder": ATTESTOR,
        "authorizationClass": "INDEPENDENT_ATTESTOR", "pointer": "", "recordIndex": "0",
        "recordChainHash": "0x" + "88" * 32}


def prepared(token="71", prior=None):
    scope = token_scope("31337", CORE, "1", token)
    prior = selector(scope.subject_id) if prior is None else prior
    return scope, token_payloads(chain_id="31337", core=CORE, collection_id="1", token_id=token,
        attestor=ATTESTOR, profile_hash=PROFILE, prior=prior, source_digest=DIGEST,
        created_at=STAMP)


class TokenMediaInputs(unittest.TestCase):
    def test_scope_is_exact_native_token_subject(self):
        scope = token_scope("31337", CORE, "1", "71")
        self.assertEqual(scope.subject_id,
            subject_id("token", "31337", CORE, "1", token_id="71"))
        self.assertEqual(scope.wire_subject, (1, 1, 71, ZERO))
        self.assertEqual(scope.anchor_subject, {"kind": "token", "subjectId": scope.subject_id})

    def test_all_media_rows_use_token_anchor_and_seed_selector(self):
        scope, rows = prepared()
        values = [loads(raw, maximum=8192, canonical=True) for raw in rows]
        self.assertTrue(all(value["anchorSubject"] == scope.anchor_subject for value in values))
        self.assertTrue(all(selector_["subjectId"] == scope.subject_id for value in values
            for selector_ in value["sourceRecords"]))
        self.assertEqual(sum(len(value["entities"]) for value in values), 5)
        self.assertEqual(sum(len(value["assertions"]) for value in values), 25)
        self.assertEqual({entity["id"] for value in values for entity in value["entities"]},
            {PREFIX + suffix for suffix in ("work", "image", "creator", "publisher", "creation")})

    def test_only_anchor_changes_from_existing_v1_media_statements(self):
        scope, rows = prepared()
        prior = selector(scope.subject_id)
        originals = collection_payloads(chain_id=31337, attestor=ATTESTOR, subject_id=scope.subject_id,
            profile_hash=PROFILE, prior=prior, source_digest=DIGEST, created_at=STAMP)
        self.assertEqual(len(rows), len(originals))
        for original, token in zip(originals, rows):
            expected = loads(original, maximum=8192, canonical=True)
            expected["anchorSubject"] = scope.anchor_subject
            self.assertEqual(loads(token, maximum=8192, canonical=True), expected)
            self.assertEqual(token, dumps(expected))

    def test_collection_or_other_token_seed_selector_is_rejected(self):
        wanted = token_scope("31337", CORE, "1", "71")
        for foreign in (subject_id("collection", "31337", CORE, "1"),
                        token_scope("31337", CORE, "1", "72").subject_id):
            with self.subTest(foreign=foreign), self.assertRaisesRegex(MuseumError, "different subject"):
                prepared(prior=selector(foreign))
        self.assertNotEqual(wanted.subject_id, foreign)

    def test_nested_foreign_selector_is_rejected_before_return(self):
        scope = token_scope("31337", CORE, "1", "71")
        prior = selector(scope.subject_id)
        altered = deepcopy(prior); altered["subjectId"] = token_scope("31337", CORE, "1", "72").subject_id
        with self.assertRaisesRegex(MuseumError, "different subject"):
            prepared(prior=altered)

    def test_noncanonical_or_zero_token_identity_is_rejected(self):
        bad = (("031337", CORE, "1", "71"), ("31337", CORE.upper(), "1", "71"),
               ("31337", "0x" + "00" * 20, "1", "71"), ("31337", CORE, "0", "71"),
               ("31337", CORE, "1", "0"))
        for args in bad:
            with self.subTest(args=args), self.assertRaises(MuseumError): token_scope(*args)

    def test_exact_token_id_changes_subject_and_payload_bytes(self):
        first_scope, first = prepared("71")
        second_scope, second = prepared("72")
        self.assertNotEqual(first_scope.subject_id, second_scope.subject_id)
        self.assertNotEqual(first, second)

    def test_typed_authority_wrappers_change_only_anchor_and_keep_exact_lineage(self):
        from .current_museum_capture import ROOT
        profile = TypedAuthorityProfile(ROOT)
        descriptor, snapshot, pin, _ = synthetic_snapshot()
        parsed, label, type_fact = validate_snapshot(descriptor, snapshot, pin)
        scope = token_scope("31337", CORE, "1", "71")
        documentary = dumps({"sourceText": label["value"]})
        source = selector(scope.subject_id)
        agent = account_iri("31337", ATTESTOR)
        args = (profile, agent, scope.subject_id, source, documentary, STAMP, label)
        token_raw, entity = token_declaration_payload(*args)
        collection_raw, expected_entity = collection_declaration_payload(*args)
        self.assertEqual(entity, expected_entity)
        self._only_anchor_diff(collection_raw, token_raw, scope.subject_id)

        declaration_selector = selector(scope.subject_id) | {"pointer": "/entities/0",
            "recordHash": "0x" + "91" * 32, "recordIndex": "1"}
        alignment_args = (profile, agent, scope.subject_id, source, documentary,
            declaration_selector, entity, STAMP, parsed, label, type_fact)
        aligned_raw, assertion = token_alignment_payload(*alignment_args)
        collection_aligned, expected_assertion = collection_alignment_payload(*alignment_args)
        self.assertEqual(assertion, expected_assertion)
        self.assertEqual(_body(assertion)["declaration"]["selector"], declaration_selector)
        self._only_anchor_diff(collection_aligned, aligned_raw, scope.subject_id)

        original_selector = selector(scope.subject_id) | {"pointer": "/assertions/0",
            "recordHash": "0x" + "92" * 32, "recordIndex": "2"}
        review_args = (profile, agent, scope.subject_id, original_selector, aligned_raw, assertion, STAMP)
        reviewed_raw = token_review_payload(*review_args)
        collection_reviewed = collection_review_payload(*review_args)
        self._only_anchor_diff(collection_reviewed, reviewed_raw, scope.subject_id)
        review = loads(reviewed_raw, maximum=8192, canonical=True)
        body = loads(review["assertions"][0]["object"]["literal"]["lexicalValue"].encode(), canonical=True)
        self.assertEqual(body["assertionRecord"], original_selector)
        self.assertEqual(body["assertionRevisionHash"], keccak256(dumps(assertion)))

    def test_typed_authority_wrappers_reject_foreign_actual_selectors(self):
        from .current_museum_capture import ROOT
        profile = TypedAuthorityProfile(ROOT)
        descriptor, snapshot, pin, _ = synthetic_snapshot()
        _, label, _ = validate_snapshot(descriptor, snapshot, pin)
        scope = token_scope("31337", CORE, "1", "71")
        foreign = selector(token_scope("31337", CORE, "1", "72").subject_id)
        with self.assertRaisesRegex(MuseumError, "foreign selector"):
            token_declaration_payload(profile, account_iri("31337", ATTESTOR), scope.subject_id,
                foreign, dumps({"sourceText": label["value"]}), STAMP, label)

    def _only_anchor_diff(self, collection_raw, token_raw, subject):
        expected = loads(collection_raw, maximum=8192, canonical=True)
        self.assertEqual(expected["anchorSubject"], {"kind": "collection", "subjectId": subject})
        expected["anchorSubject"] = {"kind": "token", "subjectId": subject}
        self.assertEqual(loads(token_raw, maximum=8192, canonical=True), expected)


if __name__ == "__main__": unittest.main()
