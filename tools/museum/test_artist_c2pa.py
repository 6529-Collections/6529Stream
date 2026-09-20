"""Synthetic wire tests for the bounded ART38 native C2PA consumer.

These fixtures exercise exact ABI and hash correspondence.  They are not
recorded-chain evidence, C2PA validation, trust-anchor review, or freeze proof.
"""

import copy
import unittest
from unittest.mock import patch

from . import artist_c2pa as c
from .artist_attestation_source import ATTESTATION_RECORD
from .canonical import MuseumError, dumps, hex_bytes, keccak256, schema_id
from .chain_abi import encode
from .independent_wire import RAW_BYTES, RAW_DEFINITION, RECORD, ZERO, ZERO_ADDRESS
from .metadata_catalog_source import RECEIPT, generic_hash


def A(number):
    return "0x" + format(number, "040x")


def H(label):
    return schema_id("synthetic ART38 test " + label)


class Fixture:
    """Independently construct the producer's exact native tuples."""

    def __init__(self):
        self.artist = H("artist")
        self.binding = H("binding")
        self.subject = H("subject")
        self.key = H("key")
        self.spki = H("spki")
        self.observation = b"synthetic retained verifier observation"
        self.anchors = b"synthetic retained trust anchors"
        self.identity = {
            "schema": "6529STREAM_ARTIST_IDENTITY_V1",
            "displayName": "Synthetic Artist",
            "biographicalRefs": [],
            "publicKeyHistory": [{"keyId": self.key, "spkiSha256": self.spki,
                "validFrom": "10", "validUntil": "0"}],
            "c2paCredentials": [{"kind": "1", "fingerprint": self.spki,
                "keyId": self.key, "validFrom": "10", "validUntil": "0"}],
            "payoutAccounts": [A(90)],
        }
        self.identity_raw = dumps(self.identity)
        self.identity_hash = keccak256(self.identity_raw)
        self.context = c.Context(31337, A(1), A(2), A(3), A(4), A(5), A(6), 7,
                                 self.subject, 100, H("block"))
        self.definition = c.report_schema_definition()

    def credential(self, *, kind=1, fingerprint=None, key=None, start=10, end=0):
        return (kind, fingerprint or self.spki, key or self.key, start, end)

    def credential_evidence(self, revision, previous, credentials, *, collection=None,
                            registry=None, record_hash=None, identity_hash=None):
        identity_hash = identity_hash or self.identity_hash
        record_hash = record_hash or H("credential record " + str(revision))
        statement = encode((c.PAYLOAD,), ((1, self.artist, identity_hash, previous,
                                           tuple(credentials)),))
        attestation = (record_hash, identity_hash, c.CREDENTIAL_SCHEMA, keccak256(statement),
                       revision, 20 + revision, A(40 + revision))
        head = (revision, record_hash, previous, self.artist,
                collection if collection is not None else self.context.collection_id,
                self.binding, revision, identity_hash, keccak256(statement), registry or A(50 + revision))
        return c.CredentialEvidence(encode((c.HEAD,), (head,)),
                                    encode((ATTESTATION_RECORD,), (attestation,)), statement)

    def personhood(self, *, schema=None, record_hash=None):
        value = (record_hash or H("personhood"), self.identity_hash,
                 schema or c.PERSONHOOD_SCHEMAS[0], H("personhood statement"), 1, 19, A(70))
        return encode((ATTESTATION_RECORD,), (value,))

    def empty_personhood(self):
        return encode((ATTESTATION_RECORD,), ((ZERO, ZERO, ZERO, ZERO, 0, 0, ZERO_ADDRESS),))

    def report(self, credential_record, enumeration_hash, **changes):
        values = {
            "version": 1, "profile": c.PROFILE, "collectionId": self.context.collection_id,
            "subjectId": self.subject, "artistId": self.artist, "bindingHash": self.binding,
            "generation": 1, "identityRecordHash": self.identity_hash,
            "credentialRecordHash": credential_record, "identityDocumentHash": self.identity_hash,
            "publicKeyHistoryHash": keccak256(dumps(self.identity["publicKeyHistory"])),
            "credentialEnumerationHash": enumeration_hash,
            "selectedMediaManifestHash": H("media manifest"), "mediaSlot": 1,
            "mediaHash": H("media"), "claimAssetHash": H("media"),
            "manifestHash": H("manifest"), "claimHash": H("claim"),
            "claimSignatureHash": H("claim signature"), "signerKind": 1,
            "signerFingerprint": self.spki, "signerKeyFingerprint": self.spki,
            "keyId": self.key, "signedAt": 15, "validation": 1, "authorship": 1,
            "assertsAuthorship": True, "validatorIdentityHash": H("validator identity"),
            "softwareVersionHash": H("software"),
            "validationReportHash": keccak256(self.observation),
            "trustAnchorsHash": keccak256(self.anchors), "reportURI": "ipfs://synthetic-report",
        }
        values.update(changes)
        return tuple(values[name] for name in c.REPORT_FIELDS)

    def original(self, report, *, index=5, authorization=4, record_changes=None,
                 receipt_changes=None, observation=None, anchors=None):
        payload = encode((c.REPORT,), (report,))
        record = (schema_id("C2PA_VALIDATION"), self.subject,
                  (1, hex_bytes(keccak256(payload)), RAW_BYTES), "", c.REPORT_SCHEMA,
                  ZERO, (0, b"", ZERO), 10)
        if record_changes:
            record = tuple(record_changes.get(i, value) for i, value in enumerate(record))
        record_hash = generic_hash(self.context.chain_id, self.context.metadata, self.context.core,
                                   self.context.collection_id, self.context.verifier, record)
        receipt = (self.context.collection_id, self.context.verifier, authorization, 20, index,
                   H("record chain " + str(index)), c.REPORT_SCHEMA_HASH,
                   keccak256(RAW_DEFINITION), ZERO)
        if receipt_changes:
            receipt = tuple(receipt_changes.get(i, value) for i, value in enumerate(receipt))
        evidence = c.ReportEvidence(encode((RECORD, RECEIPT), (record, receipt)), payload,
                                    self.observation if observation is None else observation,
                                    self.anchors if anchors is None else anchors)
        return record_hash, evidence

    def selection(self, report, *, previous=ZERO, revision=1, index=5,
                  authorization=4, evidence_changes=None):
        record_hash, evidence = self.original(report, index=index, authorization=authorization,
                                              **(evidence_changes or {}))
        blank = (record_hash, previous, ZERO, revision, index, authorization, report)
        digest = c.selection_hash(self.context, blank)
        selected = (record_hash, previous, digest, revision, index, authorization, report)
        return encode((c.SELECTION,), (selected,)), evidence, selected

    def display(self, selected, *, current=True, validation=None, authorship=None,
                asserts=None):
        value = (selected[0], selected[2], selected[6][24] if validation is None else validation,
                 selected[6][25] if authorship is None else authorship, current,
                 selected[6][26] if asserts is None else asserts)
        return encode((c.DISPLAY,), (value,))


class ArtistC2PATest(unittest.TestCase):
    def setUp(self):
        self.f = Fixture()

    def assert_rejects(self, function, *args, **kwargs):
        with self.assertRaises(MuseumError):
            function(*args, **kwargs)

    def one_credential(self):
        item = self.f.credential_evidence(1, ZERO, (self.f.credential(),))
        head = item.head
        return item, head

    def reconciliation(self, *, current_display=True, report_changes=None):
        item, _ = self.one_credential()
        report = self.f.report(H("credential record 1"), keccak256(item.statement),
                               **(report_changes or {}))
        raw, evidence, selected = self.f.selection(report)
        display = self.f.display(selected, current=current_display,
            validation=None if current_display else 0, authorship=None if current_display else 0)
        return item, report, raw, evidence, selected, display

    def test_pinned_schema_exact_abi_and_decimal_output(self):
        self.assertEqual(keccak256(self.f.definition), c.REPORT_SCHEMA_HASH)
        self.assertEqual(c.REPORT_SCHEMA_HASH,
            "0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb")
        item, report, raw, evidence, selected, display = self.reconciliation()
        decoded = c.decode_report(evidence.payload, self.f.definition)
        self.assertEqual((decoded["validationLabel"], decoded["authorshipLabel"]),
                         ("valid", "consistent"))
        result = c.consume_reconciliation(self.f.context, self.f.definition, raw, (raw,),
                                          display, (evidence,))
        self.assertEqual(result["context"]["chain_id"], "31337")
        self.assertEqual(result["context"]["collection_id"], "7")
        self.assertFalse(result["claims"]["frozenOutputConformance"])
        self.assertEqual(result["selectionHistory"][0]["selectionHash"], selected[2])

    def test_credentials_unknown_kind_withdrawal_and_global_history(self):
        first = self.f.credential_evidence(1, ZERO, (self.f.credential(kind=9),),
                                           collection=1, registry=A(51))
        second = self.f.credential_evidence(2, H("credential record 1"), (),
                                            collection=999, registry=A(52))
        decoded = c.decode_credentials(c.CREDENTIAL_SCHEMA, first.statement)
        self.assertEqual(decoded["credentials"][0]["interpretation"], "opaque_unsupported")
        result = c.consume_credentials(self.f.artist, 7, second.head, (first, second),
                                       self.f.personhood())
        self.assertTrue(result["credentialHistory"][-1]["statement"]["enumerationWithdrawn"])
        self.assertEqual(result["credentialHistory"][0]["head"]["collectionId"], "1")
        self.assertEqual(result["credentialHistory"][1]["head"]["collectionId"], "999")
        self.assertEqual(result["personhood"]["status"], "supplied_separate_native_record")

    def test_credential_malformed_schema_order_validity_and_tail_reject(self):
        rows = (self.f.credential(), self.f.credential(kind=2, fingerprint=H("cert")))
        rows = tuple(reversed(sorted(rows, key=lambda row: keccak256(encode(c.CREDENTIAL, row)))))
        malformed = encode((c.PAYLOAD,), ((1, self.f.artist, self.f.identity_hash, ZERO, rows),))
        self.assert_rejects(c.decode_credentials, c.CREDENTIAL_SCHEMA, malformed)
        for row in ((0, self.f.spki, self.f.key, 10, 0),
                    (1, self.f.spki, self.f.key, 10, 10)):
            raw = encode((c.PAYLOAD,), ((1, self.f.artist, self.f.identity_hash, ZERO, (row,)),))
            self.assert_rejects(c.decode_credentials, c.CREDENTIAL_SCHEMA, raw)
        valid = self.f.credential_evidence(1, ZERO, (self.f.credential(),)).statement
        self.assert_rejects(c.decode_credentials, H("foreign schema"), valid)
        self.assert_rejects(c.decode_credentials, c.CREDENTIAL_SCHEMA, valid + bytes(32))

    def test_head_history_and_personhood_cross_joins_reject(self):
        first, _ = self.one_credential()
        for current, history, personhood in (
                (first.head, (), self.f.empty_personhood()),
                (first.head, (c.CredentialEvidence(first.head, first.attestation,
                    self.f.credential_evidence(1, ZERO, (self.f.credential(),),
                                               identity_hash=H("other identity")).statement),),
                    self.f.empty_personhood()),
                (first.head, (first,), encode((ATTESTATION_RECORD,),
                    ((H("credential record 1"), self.f.identity_hash, c.PERSONHOOD_SCHEMAS[0],
                      H("person"), 1, 1, A(9)),)))):
            self.assert_rejects(c.consume_credentials, self.f.artist, 7, current, history, personhood)
        partial = encode((c.HEAD,), ((0, H("partial"), ZERO, ZERO, 0, ZERO, 0,
                                     ZERO, ZERO, ZERO_ADDRESS),))
        self.assert_rejects(c.decode_head, partial)
        nonzero_record_zero_collection = list(c.decode((c.HEAD,), first.head)[0])
        nonzero_record_zero_collection[4] = 0
        self.assert_rejects(c.decode_head,
            encode((c.HEAD,), (tuple(nonzero_record_zero_collection),)))
        zero_identity_personhood = encode((ATTESTATION_RECORD,),
            ((H("personhood other"), ZERO, c.PERSONHOOD_SCHEMAS[0],
              H("personhood statement other"), 1, 19, A(70)),))
        self.assert_rejects(c.consume_credentials, self.f.artist, 7, first.head,
                            (first,), zero_identity_personhood)
        historical_identity_personhood = encode((ATTESTATION_RECORD,),
            ((H("personhood historical"), H("historical identity"), c.PERSONHOOD_SCHEMAS[1],
              H("personhood statement historical"), 1, 19, A(70)),))
        retained = c.consume_credentials(self.f.artist, 7, first.head, (first,),
                                         historical_identity_personhood)
        self.assertEqual(retained["personhood"]["status"], "supplied_separate_native_record")

    def test_selection_hash_uses_zero_field_and_supersession_ordinals(self):
        item, _ = self.one_credential()
        first_report = self.f.report(H("credential record 1"), keccak256(item.statement))
        first_raw, first_evidence, first = self.f.selection(first_report, index=5)
        second_report = self.f.report(H("credential record 1"), keccak256(item.statement),
                                      validation=2, authorship=0, assertsAuthorship=False,
                                      claimAssetHash=H("different asset"))
        second_raw, second_evidence, second = self.f.selection(second_report,
            previous=first[2], revision=2, index=9, authorization=6)
        independent = keccak256(encode(("bytes32", "uint256", *("address",) * 6, c.SELECTION),
            (c.PROFILE, self.f.context.chain_id, self.f.context.companion, self.f.context.core,
             self.f.context.metadata, self.f.context.artist, self.f.context.router,
             self.f.context.verifier, (*second[:2], ZERO, *second[3:]))))
        self.assertEqual(second[2], independent)
        result = c.consume_reconciliation(self.f.context, self.f.definition, second_raw,
            (first_raw, second_raw), self.f.display(second), (first_evidence, second_evidence))
        self.assertEqual([row["revision"] for row in result["selectionHistory"]], ["1", "2"])
        self.assertEqual([row["recordIndex"] for row in result["selectionHistory"]], ["5", "9"])
        bad = list(second); bad[3] = 1
        self.assert_rejects(c.consume_reconciliation, self.f.context, self.f.definition,
            encode((c.SELECTION,), (tuple(bad),)), (first_raw, encode((c.SELECTION,), (tuple(bad),))),
            self.f.display(tuple(bad)), (first_evidence, second_evidence))

    def test_stale_display_preserves_selected_claim_without_current_promotion(self):
        _, _, raw, evidence, selected, display = self.reconciliation(current_display=False)
        result = c.consume_reconciliation(self.f.context, self.f.definition, raw, (raw,), display,
                                          (evidence,))
        self.assertFalse(result["displayObservation"]["current"])
        self.assertEqual(result["displayObservation"]["validationLabel"], "unevaluated")
        self.assertEqual(result["selectionHistory"][0]["report"]["authorshipLabel"], "consistent")
        contradictory = self.f.display(selected, current=False, validation=1, authorship=1)
        self.assert_rejects(c.consume_reconciliation, self.f.context, self.f.definition, raw,
                            (raw,), contradictory, (evidence,))

    def test_report_enums_tail_and_native_contradictions_reject(self):
        item, _, raw, evidence, selected, display = self.reconciliation()
        for changes in ({"validation": 3}, {"authorship": 3},
                        {"mediaHash": H("other")},
                        {"signerFingerprint": H("other spki")},
                        {"validation": 0, "authorship": 1}):
            report = self.f.report(H("credential record 1"), keccak256(item.statement), **changes)
            self.assert_rejects(c.decode_report, encode((c.REPORT,), (report,)), self.f.definition)
        self.assert_rejects(c.decode_report, evidence.payload + bytes(32), self.f.definition)
        self.assert_rejects(c.decode_report, evidence.payload, self.f.definition + b" ")

    def test_original_record_receipt_artifacts_and_context_are_exact(self):
        item, report, raw, evidence, selected, display = self.reconciliation()
        cases = (
            self.f.selection(report, evidence_changes={"record_changes": {1: H("foreign subject")}}),
            self.f.selection(report, evidence_changes={"receipt_changes": {0: 8}}),
            self.f.selection(report, evidence_changes={"receipt_changes": {1: A(99)}}),
            self.f.selection(report, evidence_changes={"receipt_changes": {6: H("foreign definition")}}),
            self.f.selection(report, evidence_changes={"observation": b"changed observation"}),
        )
        for changed_raw, changed_evidence, changed_selected in cases:
            with self.subTest(record=changed_selected[0]):
                self.assert_rejects(c.consume_reconciliation, self.f.context, self.f.definition,
                    changed_raw, (changed_raw,), self.f.display(changed_selected), (changed_evidence,))
        wrong_context = c.Context(31337, A(1), A(2), A(3), A(4), A(5), A(6), 8,
                                  self.f.subject, 100, H("block"))
        self.assert_rejects(c.consume_reconciliation, wrong_context, self.f.definition, raw,
                            (raw,), display, (evidence,))
        class_eight_raw, class_eight_evidence, class_eight = self.f.selection(report,
            authorization=8)
        self.assert_rejects(c.consume_reconciliation, self.f.context, self.f.definition,
            class_eight_raw, (class_eight_raw,), self.f.display(class_eight),
            (class_eight_evidence,))

    def test_joined_current_identity_and_native_credentials(self):
        item, _, raw, evidence, selected, display = self.reconciliation()
        artist = c.ArtistEvidence(self.f.artist, item.head, (item,), self.f.personhood())
        result = c.consume(self.f.context, self.f.definition, raw, (raw,), display, (evidence,),
                           (artist,), {self.f.identity_hash: self.f.identity_raw})
        self.assertEqual(result["historicalJoins"][0]["basis"],
                         "historical_native_credential_record")
        self.assertFalse(result["historicalJoins"][0]["c2paCryptographyVerified"])
        self.assertEqual(result["artists"][0]["personhood"]["status"],
                         "supplied_separate_native_record")
        self.assert_rejects(c.consume, self.f.context, self.f.definition, raw, (raw,), display,
                            (evidence,), (artist,), {H("wrong key"): self.f.identity_raw})
        occurrence_total = sum(map(len, (self.f.definition, raw, display, raw,
            self.f.identity_raw, evidence.record, evidence.payload, evidence.observation,
            evidence.trust_anchors, artist.current_head, artist.personhood, item.head,
            item.attestation, item.statement)))
        with patch.object(c, "MAX_INPUT_BYTES", occurrence_total - 1):
            self.assert_rejects(c.consume, self.f.context, self.f.definition, raw, (raw,),
                display, (evidence,), (artist,), {self.f.identity_hash: self.f.identity_raw})

    def test_joined_stale_report_survives_later_withdrawal_only_as_history(self):
        first = self.f.credential_evidence(1, ZERO, (self.f.credential(),))
        second = self.f.credential_evidence(2, H("credential record 1"), ())
        report = self.f.report(H("credential record 1"), keccak256(first.statement))
        raw, evidence, selected = self.f.selection(report)
        stale = self.f.display(selected, current=False, validation=0, authorship=0)
        artist = c.ArtistEvidence(self.f.artist, second.head, (first, second), self.f.personhood())
        result = c.consume(self.f.context, self.f.definition, raw, (raw,), stale, (evidence,),
                           (artist,), {self.f.identity_hash: self.f.identity_raw})
        self.assertEqual(result["historicalJoins"][0]["credentialRecordHash"],
                         H("credential record 1"))
        current = self.f.display(selected, current=True)
        self.assert_rejects(c.consume, self.f.context, self.f.definition, raw, (raw,), current,
                            (evidence,), (artist,), {self.f.identity_hash: self.f.identity_raw})

    def test_joined_selected_withdrawal_never_falls_back_to_identity_credentials(self):
        first = self.f.credential_evidence(1, ZERO, (self.f.credential(),))
        second = self.f.credential_evidence(2, H("credential record 1"), ())
        artist = c.ArtistEvidence(self.f.artist, second.head, (first, second), self.f.personhood())
        consistent = self.f.report(H("credential record 2"), keccak256(second.statement))
        raw, evidence, selected = self.f.selection(consistent)
        self.assert_rejects(c.consume, self.f.context, self.f.definition, raw, (raw,),
            self.f.display(selected), (evidence,), (artist,),
            {self.f.identity_hash: self.f.identity_raw})
        unevaluated = self.f.report(H("credential record 2"), keccak256(second.statement),
                                    authorship=0)
        raw, evidence, selected = self.f.selection(unevaluated)
        result = c.consume(self.f.context, self.f.definition, raw, (raw,),
            self.f.display(selected), (evidence,), (artist,),
            {self.f.identity_hash: self.f.identity_raw})
        self.assertEqual(result["reconciliation"]["selectionHistory"][0]["report"]["authorshipLabel"],
                         "unevaluated")

    def test_all_zero_native_getters_are_valid_empty_state(self):
        empty_report = tuple(False if kind == "bool" else "" if kind == "string" else
            ZERO if kind == "bytes32" else 0 for kind in c.REPORT)
        selection = (ZERO, ZERO, ZERO, 0, 0, 0, empty_report)
        current = encode((c.SELECTION,), (selection,))
        display = encode((c.DISPLAY,), ((ZERO, ZERO, 0, 0, False, False),))
        head = encode((c.HEAD,), ((0, ZERO, ZERO, ZERO, 0, ZERO, 0, ZERO, ZERO,
                                  ZERO_ADDRESS),))
        artist = c.ArtistEvidence(self.f.artist, head, (), self.f.empty_personhood())
        result = c.consume(self.f.context, self.f.definition, current, (), display, (),
                           (artist,), {})
        self.assertEqual(result["reconciliation"]["selectionHistory"], [])
        self.assertEqual(result["artists"][0]["credentialHistory"], [])
        self.assertEqual(result["artists"][0]["personhood"]["status"], "absent")

    def test_identity_only_enumeration_is_exact_and_no_personhood_upgrade(self):
        enumeration = keccak256(dumps(self.f.identity["c2paCredentials"]))
        report = self.f.report(ZERO, enumeration)
        raw, evidence, selected = self.f.selection(report)
        artist = c.ArtistEvidence(self.f.artist,
            encode((c.HEAD,), ((0, ZERO, ZERO, ZERO, 0, ZERO, 0, ZERO, ZERO, ZERO_ADDRESS),)),
            (), self.f.personhood())
        result = c.consume(self.f.context, self.f.definition, raw, (raw,), self.f.display(selected),
            (evidence,), (artist,), {self.f.identity_hash: self.f.identity_raw})
        self.assertEqual(result["historicalJoins"][0]["basis"],
                         "historical_identity_document_enumeration")
        self.assertFalse(result["claims"]["personhoodProven"])
        changed = copy.deepcopy(self.f.identity); changed["c2paCredentials"] = []
        changed_raw = dumps(changed)
        self.assert_rejects(c.consume, self.f.context, self.f.definition, raw, (raw,),
            self.f.display(selected), (evidence,), (artist,), {keccak256(changed_raw): changed_raw})


if __name__ == "__main__":
    unittest.main()
