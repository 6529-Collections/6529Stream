import copy
import unittest
from pathlib import Path
from .c2pa_reconciliation import *


class ReconciliationTest(unittest.TestCase):
    def setUp(self):
        self.key, self.fingerprint = schema_id("key"), schema_id("SPKI")
        self.credential = {"kind": "1", "fingerprint": self.fingerprint, "keyId": self.key, "validFrom": "10", "validUntil": "20"}
        self.identity = {"schema": "6529STREAM_ARTIST_IDENTITY_V1", "displayName": "Artist", "biographicalRefs": [],
            "publicKeyHistory": [{"keyId": self.key, "spkiSha256": self.fingerprint, "validFrom": "10", "validUntil": "20"}],
            "c2paCredentials": [self.credential], "payoutAccounts": ["0x" + "11" * 20],
            "extensions": {"c2paReconciliationProfile": IDENTITY_PROFILE}}
        self.media, self.anchors = b"actual local media bytes", b"explicit retained trust anchors"
        self.context = {"collectionId": "1", "subjectId": schema_id("subject"), "artistId": schema_id("artist"),
            "bindingHash": schema_id("binding"), "generation": "1", "identityRecordHash": keccak256(dumps(self.identity)),
            "credentialRecordHash": ZERO, "selectedMediaManifestHash": schema_id("media manifest"),
            "mediaSlot": "1", "mediaHash": keccak256(self.media), "reportURI": "ipfs://report"}
        self.observation = {"profile": OBSERVATION_PROFILE, "manifestHash": schema_id("manifest"),
            "claimHash": schema_id("claim"), "claimSignatureHash": schema_id("signature"), "assetHash": keccak256(self.media),
            "signerKind": "1", "signerFingerprint": self.fingerprint, "signerKeyFingerprint": self.fingerprint,
            "keyId": self.key, "signedAt": "10", "validationStatus": "valid", "assertsAuthorship": True,
            "validatorIdentityHash": schema_id("verifier"), "softwareVersionHash": schema_id("software"),
            "trustAnchorsHash": keccak256(self.anchors), "cryptoTrustProfile": "SELECTED_VERIFIER_ARCHIVED_TRUST_V1"}

    def build(self, statement=None):
        self.context["identityRecordHash"] = keccak256(dumps(self.identity))
        return build_report(self.context, dumps(self.identity), statement, dumps(self.observation), self.anchors, self.media)

    def test_exact_identity_enumeration_and_report_abi(self):
        report, raw = self.build()
        self.assertEqual((report["validation"], report["authorship"]), (1, 1))
        values, = decode((REPORT,), raw)
        self.assertEqual(dict(zip(REPORT_FIELDS, values)), report)
        self.assertEqual(report["publicKeyHistoryHash"], keccak256(dumps(self.identity["publicKeyHistory"])))

    def test_registered_schema_definition_is_exact_typed_report(self):
        raw = (Path(__file__).resolve().parents[2] / "schemas/records/6529STREAM_C2PA_RECONCILIATION_REPORT_V1.json").read_bytes()
        self.assertEqual(raw, report_schema_definition())
        self.assertEqual(keccak256(raw), "0x9c896dc177954cc145f240cbcd4097a3b953b0121360c7f2acef053bc17e68cb")

    def test_validity_start_inclusive_end_exclusive(self):
        for at, expected in (("9", 2), ("10", 1), ("19", 1), ("20", 2)):
            self.observation["signedAt"] = at
            self.assertEqual(self.build()[0]["authorship"], expected)

    def test_key_history_window_is_independent(self):
        self.identity["publicKeyHistory"][0]["validFrom"] = "11"
        self.assertEqual(self.build()[0]["authorship"], 2)

    def test_certificate_requires_same_spki_key_history(self):
        cert = schema_id("certificate DER")
        self.credential.update(kind="2", fingerprint=cert)
        self.observation.update(signerKind="2", signerFingerprint=cert)
        self.assertEqual(self.build()[0]["authorship"], 1)
        self.observation["signerKeyFingerprint"] = schema_id("foreign SPKI")
        self.assertEqual(self.build()[0]["authorship"], 2)

    def test_latest_abi_enumeration_replaces_identity(self):
        self.context["credentialRecordHash"] = schema_id("record")
        statement = credential_statement(self.context["artistId"], self.context["identityRecordHash"], ZERO, [])
        report, _ = self.build(statement)
        self.assertEqual(report["authorship"], 0)
        self.assertEqual(report["credentialEnumerationHash"], keccak256(statement))

    def test_stale_statement_identity_rejected(self):
        self.context["credentialRecordHash"] = schema_id("record")
        statement = credential_statement(self.context["artistId"], schema_id("old document"), ZERO, [self.credential])
        with self.assertRaisesRegex(MuseumError, "credential identity"):
            self.build(statement)

    def test_noncanonical_statement_and_omitted_head_rejected(self):
        statement = credential_statement(self.context["artistId"], self.context["identityRecordHash"], ZERO, [self.credential])
        with self.assertRaisesRegex(MuseumError, "unexpected credential"):
            self.build(statement)
        self.context["credentialRecordHash"] = schema_id("record")
        with self.assertRaises(MuseumError):
            self.build(statement + bytes(32))
        with self.assertRaisesRegex(MuseumError, "statement required"):
            self.build()

    def test_unknown_identity_profile_is_unevaluated(self):
        self.identity["extensions"]["c2paReconciliationProfile"] = "future"
        self.assertEqual(self.build()[0]["authorship"], 0)

    def test_unknown_crypto_trust_is_unevaluated(self):
        self.observation["cryptoTrustProfile"] = "self-reported"
        report, _ = self.build()
        self.assertEqual((report["validation"], report["authorship"]), (0, 0))

    def test_opaque_credential_does_not_imply_divergence(self):
        self.credential["kind"] = "3"
        self.assertEqual(self.build()[0]["authorship"], 0)

    def test_missing_credentials_and_no_authorship_unevaluated(self):
        self.identity["c2paCredentials"] = []
        self.assertEqual(self.build()[0]["authorship"], 0)
        self.identity["c2paCredentials"] = [self.credential]
        self.observation["assertsAuthorship"] = False
        self.assertEqual(self.build()[0]["authorship"], 0)

    def test_hard_binding_mismatch_is_invalid(self):
        self.observation["assetHash"] = schema_id("different asset")
        report, _ = self.build()
        self.assertEqual((report["validation"], report["authorship"]), (2, 0))

    def test_actual_media_bytes_must_match_committed_hash(self):
        self.media += b"corruption"
        with self.assertRaisesRegex(MuseumError, "committed media"):
            self.build()

    def test_retained_anchor_bytes_must_match_report(self):
        self.anchors += b"corruption"
        with self.assertRaisesRegex(MuseumError, "trust-anchor"):
            self.build()

    def test_duplicate_history_key_refuses_ambiguity(self):
        self.identity["publicKeyHistory"].append(copy.deepcopy(self.identity["publicKeyHistory"][0]))
        with self.assertRaisesRegex(MuseumError, "duplicate key-history"):
            self.build()

    def test_duplicate_credential_refuses_ambiguity(self):
        with self.assertRaisesRegex(MuseumError, "duplicate credential"):
            credential_statement(self.context["artistId"], self.context["identityRecordHash"], ZERO, [self.credential, self.credential])

    def test_closed_observation_and_context(self):
        self.observation["trusted"] = True
        with self.assertRaisesRegex(MuseumError, "observation keys"):
            self.build()
        del self.observation["trusted"]
        self.context["authority"] = True
        with self.assertRaisesRegex(MuseumError, "context keys"):
            self.build()

    def test_exact_identity_bytes_cannot_be_replaced_by_valid_shape(self):
        raw = dumps(self.identity)
        self.identity["displayName"] = "Changed"
        with self.assertRaisesRegex(MuseumError, "identity byte hash"):
            build_report(self.context, dumps(self.identity), None, dumps(self.observation), self.anchors, self.media)
        with self.assertRaises(MuseumError):
            build_report(self.context, b" " + raw, None, dumps(self.observation), self.anchors, self.media)


if __name__ == "__main__":
    unittest.main()
