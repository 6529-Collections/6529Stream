"""Synthetic original-source controls; no on-chain publication or signature execution."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import decode, encode
from .chain_rpc import MAX_TRANSCRIPT
from .general_publication_v1 import EVENT_DATA, GRANT_DATA
from .general_review_fixture import GeneralReviewFixture
from .general_review_selection import build, replay, select
from .general_review_profile_v1 import GeneralSemanticReviewProfileV1, ASSERTION_NAME
from .test_general_attestation_source import a, h


def receipt(f, tx):
    return f.general_fixture.responses[dumps(["eth_getTransactionReceipt", [tx]])]


def read(f):
    return loads(f.source().snapshot(), maximum=MAX_TRANSCRIPT, canonical=True)


class GeneralSemanticReviewTests(unittest.TestCase):
    def selection(self, f, **kwargs):
        source = f.source(); raw, digest = f.policy(source, **kwargs)
        return select(source, raw, digest)

    def test_curator_original_operator_grant_and_all_native_rows(self):
        f = GeneralReviewFixture(); snapshot = read(f)
        self.assertEqual(len(snapshot["statements"]), 4)
        self.assertEqual(len(snapshot["reviews"]), 1)
        review = snapshot["reviews"][0]
        self.assertTrue(review["reviewer"].endswith(a(10)))
        row = next(r for r in snapshot["statements"] if r["source"]["recordHash"] == f.review_source["recordHash"])
        self.assertEqual(row["authority"]["assertedAttester"], a(9))
        self.assertEqual(row["grantEvidence"]["operator"], a(10))
        self.assertEqual(row["grantEvidence"]["revision"], "2")
        self.assertTrue(snapshot["interpretationDocumentsChecked"])
        chosen = self.selection(f)
        self.assertEqual(len(chosen["selected"]), 1)
        self.assertEqual(chosen["selected"][0]["reviewQualification"], "explicitly_admitted_distinct_accounts")
        self.assertFalse(chosen["claims"]["independentHumanReviewProven"])

    def test_signed_estate_uses_historical_recorder(self):
        f = GeneralReviewFixture(reviewer="estate"); snapshot = read(f)
        self.assertTrue(snapshot["reviews"][0]["reviewer"].endswith(a(15)))
        self.assertEqual(len(self.selection(f)["selected"]), 1)

    def test_author_confirmation_requires_explicit_policy(self):
        f = GeneralReviewFixture(reviewer="self")
        self.assertEqual(len(self.selection(f)["selected"]), 0)
        result = self.selection(f, allow_self=True)
        self.assertEqual(result["selected"][0]["reviewQualification"], "author_confirmed_self_review")
        self.assertTrue(result["selected"][0]["qualifyingReviews"][0]["selfReview"])

    def test_same_timestamp_uses_actual_transaction_order(self):
        f = GeneralReviewFixture(same_block=True); result = self.selection(f)
        row = result["selected"][0]
        self.assertEqual(row["publication"]["publicationPosition"], ["6", "0", "0"])
        self.assertEqual(row["qualifyingReviews"][0]["publication"]["publicationPosition"], ["6", "1", "1"])

    def test_reversed_same_block_order_refuses(self):
        f = GeneralReviewFixture(same_block=True); first, second = h("General-tx-1"), h("General-tx-2")
        for tx, index in ((first, 1), (second, 0)):
            r = receipt(f, tx); r["transactionIndex"] = hex(index)
            r["logs"][0]["transactionIndex"] = hex(index); r["logs"][0]["logIndex"] = hex(index)
        block = f.general_fixture.responses[dumps(["eth_getBlockByHash", [h("publication-block-6"), False]])]
        block["transactions"] = [second, first]
        self.assertTrue(any("precede" in r["reason"] or "follow" in r["reason"] for r in read(f)["ineligibleAssertions"]))
        with self.assertRaisesRegex(MuseumError, "ineligible"): self.selection(f)

    def test_same_transaction_order_is_exact_log_position(self):
        f = GeneralReviewFixture(same_block=True); target_tx, review_tx = h("General-tx-1"), h("General-tx-2")
        first, second = receipt(f, target_tx), receipt(f, review_tx)
        log = deepcopy(second["logs"][0]); log.update(transactionHash=target_tx, transactionIndex="0x0")
        first["logs"].append(log)
        header = f.general_fixture.responses[dumps(["eth_getBlockByHash", [h("publication-block-6"), False]])]
        header["transactions"] = [target_tx]
        hints = loads(f.hints); hints["records"][2]["transactionHash"] = target_tx; f.hints = dumps(hints)
        result = self.selection(f)
        self.assertEqual(result["selected"][0]["qualifyingReviews"][0]["publication"]["publicationPosition"], ["6", "0", "1"])

    def test_grant_in_same_transaction_must_precede_general_event(self):
        f = GeneralReviewFixture(); tx = h("General-tx-2"); r = receipt(f, tx)
        log = deepcopy(receipt(f, h("original-curator-grant"))["logs"][0])
        for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex"): log[key] = r[key]
        r["logs"][0]["logIndex"] = "0x1"; r["logs"].insert(0, log)
        hints = loads(f.hints); hints["curatorGrants"][0]["transactionHash"] = tx; f.hints = dumps(hints)
        self.assertEqual(len(self.selection(f)["selected"]), 1)
        r["logs"] = [r["logs"][1], r["logs"][0]]
        r["logs"][0]["logIndex"] = "0x0"; r["logs"][1]["logIndex"] = "0x1"
        with self.assertRaisesRegex(MuseumError, "grant must precede"): read(f)

    def test_review_exact_revision_profile_mapping_scope_and_principal(self):
        mutations = [lambda b: b.update(assertionRevisionHash=h("other-revision")),
            lambda b: b.update(profileHash=h("other-profile")), lambda b: b.update(mappingRule="urn:other:mapping"),
            lambda b: b["targetAuthority"].update(principal="urn:other:account"),
            lambda b: b["targetAuthority"].update(collectionId="8"),
            lambda b: b["targetAuthority"].update(grantRevision="9"),
            lambda b: b["assertionRecord"].update(recordChainHash=h("other-chain"))]
        for mutate in mutations:
            with self.subTest(mutate=mutate):
                f = GeneralReviewFixture(mutate_body=mutate)
                self.assertEqual(len(read(f)["ineligibleAssertions"]), 1)
                with self.assertRaisesRegex(MuseumError, "ineligible"): self.selection(f)

    def test_unsigned_curator_label_cannot_impersonate_reviewer(self):
        def mutate(value): value["assertions"][0]["assertingAgent"] = "urn:6529stream:account:eip155:31337:" + a(9)
        f = GeneralReviewFixture(mutate_review=mutate)
        self.assertTrue(any("impersonation" in r["reason"] for r in read(f)["ineligibleAssertions"]))
        with self.assertRaisesRegex(MuseumError, "ineligible"): self.selection(f)

    def test_assertion_name_is_not_historical_principal(self):
        def mutate(value): value["assertions"][0]["assertingAgent"] = "urn:example:institution"
        f = GeneralReviewFixture(mutate_target=mutate)
        self.assertTrue(any("impersonation" in r["reason"] for r in read(f)["ineligibleAssertions"]))
        with self.assertRaisesRegex(MuseumError, "ineligible"): self.selection(f)

    def test_withdrawn_or_disputed_review_cannot_admit_mapping(self):
        for status in ("withdrawn", "disputed"):
            with self.subTest(status=status):
                result = self.selection(GeneralReviewFixture(review_status=status))
                self.assertEqual(len(result["selected"]), 0)

    def test_withdrawn_or_disputed_target_remains_withheld(self):
        for status in ("withdrawn", "disputed"):
            with self.subTest(status=status):
                result = self.selection(GeneralReviewFixture(target_status=status))
                self.assertIn("original_disputed_or_withdrawn", result["withheld"][0]["reasons"])

    def test_rejection_has_no_recency_winner(self):
        result = self.selection(GeneralReviewFixture(disposition="rejected"))
        self.assertEqual(len(result["selected"]), 0)
        self.assertIn("selected_review_rejects_exact_revision", result["withheld"][0]["reasons"])

    def test_unselected_review_has_no_veto_and_reviewed_label_is_not_authority(self):
        result = self.selection(GeneralReviewFixture(origin="direct_statement", disposition="rejected"), include_review=False)
        self.assertEqual(len(result["selected"]), 1)
        result = self.selection(GeneralReviewFixture(target_status="reviewed"), include_review=False)
        self.assertEqual(len(result["selected"]), 0)

    def test_curator_grant_event_requires_original_class_enabled_revision_and_action(self):
        for index, value in ((0, 4), (1, False), (2, 3), (3, "0x" + "00" * 32)):
            f = GeneralReviewFixture(); log = receipt(f, h("original-curator-grant"))["logs"][0]
            parts = list(decode(GRANT_DATA, hex_bytes(log["data"]))); parts[index] = value
            log["data"] = "0x" + encode(GRANT_DATA, tuple(parts)).hex()
            with self.subTest(index=index), self.assertRaises(MuseumError): read(f)

    def test_curator_grant_exact_host_collection_family_account(self):
        for field in ("host", "collection", "family", "account", "padding"):
            f = GeneralReviewFixture(); log = receipt(f, h("original-curator-grant"))["logs"][0]
            if field == "host": log["address"] = a(99)
            elif field == "collection": log["topics"][1] = "0x" + (8).to_bytes(32, "big").hex()
            elif field == "family": log["topics"][2] = h("other-family")
            elif field == "account": log["topics"][3] = "0x" + bytes(12).hex() + a(9)[2:]
            else: log["topics"][3] = "0x01" + log["topics"][3][4:]
            with self.subTest(field=field), self.assertRaises(MuseumError): read(f)

    def test_grant_must_precede_publication(self):
        f = GeneralReviewFixture(); tx = h("original-curator-grant"); r = receipt(f, tx)
        anchor = f.general_fixture.responses[dumps(["eth_getBlockByHash", [f.general_fixture.anchor["blockHash"], False]])]
        anchor["transactions"] = [tx]
        r.update(blockHash=anchor["hash"], blockNumber="0x9")
        r["logs"][0].update(blockHash=anchor["hash"], blockNumber="0x9")
        with self.assertRaisesRegex(MuseumError, "grant must precede"): read(f)

    def test_later_revocation_does_not_rewrite_historical_grant(self):
        f = GeneralReviewFixture(); grant = deepcopy(receipt(f, h("original-curator-grant"))["logs"][0])
        r = receipt(f, h("General-tx-2")); after = deepcopy(r["logs"][0])
        after.update(address=grant["address"], topics=grant["topics"], logIndex="0x1",
            data="0x" + encode(GRANT_DATA, (3, False, 3, h("revocation"))).hex())
        r["logs"].append(after)
        self.assertEqual(len(self.selection(f)["selected"]), 1)

    def test_exact_general_event_full_tuple(self):
        for index, value in ((0, h("foreign")), (1, a(90)), (2, 1), (3, 1), (4, h("supersedes")), (5, h("chain")), (6, 2)):
            f = GeneralReviewFixture(); log = receipt(f, h("General-tx-2"))["logs"][0]
            parts = list(decode(EVENT_DATA, hex_bytes(log["data"]))); parts[index] = value
            log["data"] = "0x" + encode(EVENT_DATA, tuple(parts)).hex()
            with self.subTest(index=index), self.assertRaises(MuseumError): read(f)

    def test_receipt_event_and_transaction_authentication(self):
        for field in ("removed", "status", "host", "transaction", "index", "duplicate"):
            f = GeneralReviewFixture(); r = receipt(f, h("General-tx-1")); log = r["logs"][0]
            if field == "removed": log["removed"] = True
            elif field == "status": r["status"] = "0x0"
            elif field == "host": log["address"] = a(99)
            elif field == "transaction": log["transactionHash"] = h("other-tx")
            elif field == "index": r["transactionIndex"] = log["transactionIndex"] = "0x1"
            else: r["logs"].append(deepcopy(log))
            with self.subTest(field=field), self.assertRaises(MuseumError): read(f)

    def test_header_ancestry_and_timestamp_not_assumed(self):
        for field, value in (("number", "0x10"), ("timestamp", "0x80"), ("parentHash", h("foreign-parent"))):
            f = GeneralReviewFixture(); key = dumps(["eth_getBlockByHash", [h("publication-block-7"), False]])
            f.general_fixture.responses[key][field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError): read(f)

    def test_complete_hints_and_source_family_cannot_be_sliced(self):
        f = GeneralReviewFixture(); value = loads(f.hints); value["records"].pop(); f.hints = dumps(value)
        with self.assertRaisesRegex(MuseumError, "completeness"): read(f)
        f = GeneralReviewFixture(); value = loads(f.hints); value["curatorGrants"] = []; f.hints = dumps(value)
        with self.assertRaisesRegex(MuseumError, "completeness"): read(f)

    def test_interpretation_document_must_equal_registered_bytes(self):
        f = GeneralReviewFixture(); f._install_document(ASSERTION_NAME, 0, b'{"different":true}')
        with self.assertRaises(MuseumError): read(f)

    def test_documentary_pointer_and_hash_are_exact(self):
        def bad_pointer(value): value["sourceRecords"][0]["pointer"] = "/missing"
        def bad_hash(value): value["assertions"][0]["evidence"][0]["source"]["digest"] = h("other")
        for mutate in (bad_pointer, bad_hash):
            with self.subTest(mutate=mutate):
                f = GeneralReviewFixture(mutate_target=mutate)
                self.assertTrue(read(f)["ineligibleAssertions"])
                with self.assertRaisesRegex(MuseumError, "ineligible"): self.selection(f)

    def test_metadata_shaped_review_target_is_not_coerced(self):
        def mutate(body):
            body["assertionRecord"].pop("verificationClass")
            body["assertionRecord"]["authorizationClass"] = "INSTITUTION_SIGNER"
        with self.assertRaises(MuseumError): GeneralReviewFixture(mutate_body=mutate)

    def test_manifest_admissions_bind_historical_family_scope_principal(self):
        f = GeneralReviewFixture(); s = f.source(); raw, _ = f.policy(s)
        for name, field, value in (("sourceAuthoritySet", "principal", "urn:forged:principal"),
            ("reviewerAuthoritySet", "grantRevision", "3"), ("reviewerAuthoritySet", "collectionId", "8")):
            p = loads(raw); p[name][0]["authority"][field] = value; changed = dumps(p)
            with self.subTest(field=field), self.assertRaises(MuseumError): select(s, changed, keccak256(changed))
        with self.assertRaises(MuseumError): select(s, raw, h("wrong-external-pin"))

    def test_competing_selected_direct_claims_are_withheld(self):
        def mutate(value):
            other = deepcopy(value["assertions"][0]); other["id"] = "urn:synthetic:other"
            other["object"] = {"entity": "urn:synthetic:place:B"}; value["assertions"].append(other)
        f = GeneralReviewFixture(origin="direct_statement", mutate_target=mutate); s = f.source(); raw, _ = f.policy(s)
        p = loads(raw); second = deepcopy(p["sourceAuthoritySet"][0]); second["source"]["pointer"] = "/assertions/1"
        p["sourceAuthoritySet"].append(second); p["singleValuedRelations"] = ["urn:synthetic:place"]
        raw = dumps(p); result = select(s, raw, keccak256(raw))
        self.assertEqual(len(result["selected"]), 0); self.assertEqual(len(result["withheld"]), 2)
        self.assertTrue(all("conflicting_selected_source_values" in r["reasons"] for r in result["withheld"]))

    def test_unselected_invalid_review_or_backlink_cannot_veto_valid_export(self):
        for kind in ("revision", "target", "backlink"):
            f = GeneralReviewFixture(); payload = deepcopy(f.review)
            payload["assertions"][0]["id"] = "urn:synthetic:malformed-extra"
            claim = payload["assertions"][0]
            body = loads(claim["object"]["literal"]["lexicalValue"].encode())
            if kind == "backlink":
                claim["relation"] = "urn:synthetic:later-disposition"
                claim["mappingRule"] = "urn:synthetic:disposition-rule"
                claim["object"] = {"entity": "urn:synthetic:disposition"}
                claim["reviewEvidence"] = [{"reviewRecord": f.review_source, **{k: body[k] for k in
                    ("assertionRecord", "assertionRevisionHash", "profileHash", "mappingRule", "targetAuthority")},
                    "reviewer": "urn:forged:reviewer", "reviewedAt": f.review["assertions"][0]["createdAt"], "selfReview": False}]
            else:
                if kind == "revision": body["assertionRevisionHash"] = h("forged-revision")
                else: body["assertionRecord"]["recordHash"] = h("foreign-target")
                claim["object"]["literal"]["lexicalValue"] = dumps(body).decode()
            extra = f.append_statement(payload); source = f.source(); policy, digest = f.policy(source)
            files = build(source, policy, digest, disclosure="public")
            snapshot = loads(files["semantic-source.json"], maximum=MAX_TRANSCRIPT)
            self.assertEqual(snapshot["ineligibleAssertions"][0]["source"], extra)
            self.assertEqual(len(loads(files["graph.json"])), 1)
            selected = loads(policy)
            from .general_semantic_source_v2 import admission
            row = next(r for r in snapshot["statements"] if r["source"]["recordHash"] == extra["recordHash"])
            item = {"source": extra, "authority": admission(row, source.a)}
            for key in ("sourceAuthoritySet", "reviewerAuthoritySet"):
                modified = deepcopy(selected); modified[key].append(item); raw = dumps(modified)
                with self.subTest(kind=kind, set=key), self.assertRaisesRegex(MuseumError, "ineligible"):
                    select(source, raw, keccak256(raw))

    def test_unselected_malformed_semantic_envelope_and_backlink_shape_have_no_veto(self):
        for kind in ("json", "envelope", "assertingAgent", "entity", "profileSchema", "backlinkShape", "backlinkSelector"):
            f = GeneralReviewFixture(); payload = deepcopy(f.review); claim = payload["assertions"][0]
            claim["id"] = "urn:synthetic:malformed-semantic"
            if kind == "json": payload = b'{"profileHash":'
            elif kind == "envelope": payload["entities"] = "not an array"
            elif kind == "assertingAgent": claim["assertingAgent"] = "urn:forged:operator"
            elif kind == "entity":
                payload["entities"] = [{"id": "urn:synthetic:declaration", "kind": "person", "names": [],
                    "declaringAgent": "urn:forged:operator", "sourceRecords": payload["sourceRecords"], "predecessors": []}]
            elif kind == "profileSchema": payload["profileSchemaId"] = h("foreign-profile-schema")
            else:
                body = loads(claim["object"]["literal"]["lexicalValue"].encode())
                backlink = {"reviewRecord": f.review_source, **{k: body[k] for k in
                    ("assertionRecord", "assertionRevisionHash", "profileHash", "mappingRule", "targetAuthority")},
                    "reviewer": f.review["assertions"][0]["assertingAgent"], "reviewedAt": claim["createdAt"], "selfReview": False}
                if kind == "backlinkShape": backlink.pop("targetAuthority")
                else: backlink["reviewRecord"] = {"recordHash": f.review_source["recordHash"]}
                claim["reviewEvidence"] = [backlink]
            extra = f.append_statement(payload); source = f.source(); raw, digest = f.policy(source)
            result = select(source, raw, digest)
            snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
            self.assertEqual(len(result["selected"]), 1)
            self.assertTrue(any(r["source"]["recordHash"] == extra["recordHash"] for r in snapshot["ineligibleAssertions"]))
            from .general_semantic_source_v2 import admission
            row = next(r for r in snapshot["statements"] if r["source"]["recordHash"] == extra["recordHash"])
            p = loads(raw); p["sourceAuthoritySet"].append({"source": extra, "authority": admission(row, source.a)})
            changed = dumps(p)
            with self.subTest(kind=kind), self.assertRaisesRegex(MuseumError, "ineligible"):
                select(source, changed, keccak256(changed))

    def test_malformed_assertion_does_not_veto_valid_sibling_assertion(self):
        f = GeneralReviewFixture(); payload = deepcopy(f.review); good = payload["assertions"][0]
        good.update(id="urn:synthetic:valid-sibling", relation="urn:synthetic:observation",
            mappingRule="urn:synthetic:observation-rule", object={"entity": "urn:synthetic:observation"})
        bad = deepcopy(good); bad.update(id="urn:synthetic:bad-sibling", reviewEvidence=[{"reviewRecord": f.review_source}])
        payload["assertions"].append(bad)
        extra = f.append_statement(payload); source = f.source(); raw, _ = f.policy(source)
        snapshot = loads(source.snapshot(), maximum=MAX_TRANSCRIPT)
        self.assertEqual([r["source"]["pointer"] for r in snapshot["ineligibleAssertions"]], ["/assertions/1"])
        from .general_semantic_source_v2 import admission
        row = next(r for r in snapshot["statements"] if r["source"]["recordHash"] == extra["recordHash"])
        p = loads(raw); p["sourceAuthoritySet"].append({"source": extra, "authority": admission(row, source.a)})
        changed = dumps(p); self.assertEqual(len(select(source, changed, keccak256(changed))["selected"]), 2)
        p["sourceAuthoritySet"][-1]["source"]["pointer"] = "/assertions/1"; changed = dumps(p)
        with self.assertRaisesRegex(MuseumError, "ineligible"): select(source, changed, keccak256(changed))

    def test_review_own_authenticated_token_scope_cannot_approve_collection(self):
        from .canonical import subject_id
        from .independent_wire import ZERO
        f = GeneralReviewFixture(); payload = deepcopy(f.review)
        token_subject = subject_id("token", "31337", f.general_fixture.core, "7", token_id="42")
        payload["anchorSubject"] = {"kind": "token", "subjectId": token_subject}
        payload["assertions"][0]["id"] = "urn:synthetic:wrong-scope-review"
        extra = f.append_statement(payload, scope=((1, 7, 42, ZERO), token_subject))
        snapshot = read(f)
        self.assertEqual(snapshot["ineligibleAssertions"][0]["source"], extra)
        self.assertIn("own native subject scope", snapshot["ineligibleAssertions"][0]["reason"])
        self.assertEqual(len(self.selection(f)["selected"]), 1)

    def test_valid_later_backlink_preserves_exact_prior_review(self):
        f = GeneralReviewFixture(); payload = deepcopy(f.review); claim = payload["assertions"][0]
        body = loads(claim["object"]["literal"]["lexicalValue"].encode())
        claim.update(id="urn:synthetic:later-backlink", relation="urn:synthetic:later-disposition",
            mappingRule="urn:synthetic:disposition", object={"entity": "urn:synthetic:retained"})
        claim["reviewEvidence"] = [{"reviewRecord": f.review_source, **{k: body[k] for k in
            ("assertionRecord", "assertionRevisionHash", "profileHash", "mappingRule", "targetAuthority")},
            "reviewer": f.review["assertions"][0]["assertingAgent"], "reviewedAt": f.review["assertions"][0]["createdAt"], "selfReview": False}]
        f.append_statement(payload)
        self.assertEqual(read(f)["ineligibleAssertions"], [])
        self.assertEqual(len(self.selection(f)["selected"]), 1)

    def test_synthetic_transport_cannot_be_labelled_trusted(self):
        with self.assertRaises(MuseumError): GeneralReviewFixture().source(provenance="trusted_rpc")

    def test_exact_graph_provenance_and_offline_replay(self):
        f = GeneralReviewFixture(); s = f.source(); raw, digest = f.policy(s)
        with patch("socket.socket", side_effect=AssertionError("unexpected network")):
            files = build(s, raw, digest, disclosure="public")
            self.assertEqual(replay(files, digest, provenance="synthetic_fixture", disclosure="public"), files)
        graph = loads(files["graph.json"]); provenance = loads(files["provenance.json"], maximum=MAX_TRANSCRIPT)
        self.assertEqual(len(graph), 1)
        self.assertEqual(loads(graph[0]["resource"]["content"].encode()), f.target["assertions"][0])
        self.assertTrue(all(p["source"] == f.target_source and p["reviews"] for p in provenance))
        altered = dict(files); altered["graph.json"] = dumps([])
        with self.assertRaisesRegex(MuseumError, "bundle differs"):
            replay(altered, digest, provenance="synthetic_fixture", disclosure="public")

    def test_public_disclosure_precedes_capture(self):
        f = GeneralReviewFixture()
        from .test_general_attestation_source import Transport
        with patch.object(Transport, "request", side_effect=AssertionError("reads before public disclosure")):
            s = f.source()
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                build(s, b"", h("any"), disclosure="private")
        self.assertFalse(s._started)
        self.assertFalse(s.publications._started)

    def test_failed_capture_cannot_resume(self):
        f = GeneralReviewFixture(); receipt(f, h("General-tx-1"))["status"] = "0x0"; s = f.source()
        with self.assertRaises(MuseumError): s.snapshot()
        receipt(f, h("General-tx-1"))["status"] = "0x1"
        with self.assertRaisesRegex(MuseumError, "cannot resume"): s.snapshot()
        self.assertTrue(read(f)["interpretationDocumentsChecked"])


if __name__ == "__main__": unittest.main()
