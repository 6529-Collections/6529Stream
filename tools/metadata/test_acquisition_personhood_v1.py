"""Offline supplied native personhood joins; fixtures are explicitly synthetic."""
import copy
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

from . import acquisition_personhood_v1 as v1
from . import acquisition_packet_v4 as packet
from tools.museum import artist_attestation_source as artist
from tools.museum import personhood_documentary as proof
from tools.museum.canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from tools.museum.chain_abi import decode, encode
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, json_values
from tools.museum.test_public_personhood_source import PublicPersonhoodFixture, A, H, K


def source_ref(snapshot):
    return {"manifestHash": K("synthetic externally pinned capture manifest"),
        "anchorHash": snapshot["anchorHash"], "transcriptHash": snapshot["transcriptHash"],
        "snapshotHash": keccak256(dumps(snapshot)), "sourceProfileHash": v1.source.PROFILE_HASH,
        "captureProfileHash": v1.capture.PROFILE_HASH}


def project(fixture):
    snapshot = fixture.result()
    return v1.semanticProjection(snapshot, source_ref(snapshot))


class AcquisitionPersonhoodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.values = {mode: project(PublicPersonhoodFixture(mode=mode)) for mode in
            ("none", "waiver", "resolved", "legacy", "stale_head", "other_recorder", "imported", "imported_waiver")}

    def value(self, mode="resolved"):
        return copy.deepcopy(self.values[mode])

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: v1.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_all_native_statuses_and_imported_waiver_remain_distinct(self):
        expected = {"none": "NONE", "waiver": "WAIVER", "resolved": "RESOLVED", "legacy": "UNRESOLVED",
            "stale_head": "STALE", "other_recorder": "RESOLVED", "imported": "RESOLVED", "imported_waiver": "WAIVER"}
        with patch("socket.socket", side_effect=AssertionError("offline supplied-data validation")):
            for mode, status in expected.items():
                value = self.value(mode)
                with self.subTest(mode=mode):
                    self.assertEqual(v1.validate(dumps(value)), value)
                    self.assertEqual(value["current"]["status"], status)
        self.assertIsNone(self.value("none")["original"])
        imported = self.value("imported_waiver")
        self.assertNotEqual(imported["sourceBindings"]["originalRegistry"], imported["sourceBindings"]["currentRegistry"])
        self.assertIsNone(imported["general"])
        self.assertEqual(imported["current"]["evidenceHash"], imported["original"]["recordHash"])

    def test_projection_preserves_exact_originals_and_independent_notary_scope(self):
        fixture = PublicPersonhoodFixture(); snapshot = fixture.result(); original = copy.deepcopy(snapshot)
        value = v1.semanticProjection(snapshot, source_ref(snapshot))
        self.assertEqual(snapshot, original)
        self.assertEqual(value["sourceState"]["collectionId"], "1")
        self.assertEqual(value["general"]["attestation"][1], "7")
        for key in ("record", "recordPreimageHex", "statementHex", "signatureHex", "summary", "summaryHash"):
            self.assertEqual(value["original"][key], snapshot["native"][key])
        authority = value["general"]["authority"]
        self.assertEqual((authority["kind"], authority["version"]), ("native_general_receipt", "1"))
        self.assertEqual(authority["receipt"], snapshot["documentary"]["receipt"])
        self.assertEqual(len(authority["receipt"]), 24)
        self.assertNotIn("authorityClass", authority)
        self.assertEqual(value["general"]["payloadValue"]["legalPersonRef"], snapshot["documentary"]["payloadValue"]["legalPersonRef"])
        value["general"]["authority"]["authorityClass"] = 1
        self.reject(value)

    def test_schema_exceeds_old_json_limit_and_generated_bytes_match(self):
        self.assertGreater(len(v1.SCHEMA_BYTES), 24576)
        schema = loads(v1.SCHEMA_BYTES, maximum=v1.MAX_BYTES)
        Draft202012Validator.check_schema(schema)
        self.assertEqual(v1.documents(), {v1.NAME: v1.SCHEMA_BYTES})
        self.assertEqual(v1.SCHEMA_HASH, keccak256(v1.SCHEMA_BYTES))
        self.assertEqual((v1.ROOT / "schemas/records" / (v1.NAME + ".json")).read_bytes(), v1.SCHEMA_BYTES)
        self.assertEqual(v1.validate(dumps(self.value())), self.value())

    def test_old_packet_and_native_definition_bytes_stay_frozen(self):
        old = {
            "STREAM_ACQUISITION_PACKET_V1": "0x88d89a5ee0a1b15bc4c4b38e73c57f6c120bf198e03a82f7f8ad61d0f9923357",
            "STREAM_ACQUISITION_PACKET_V2": "0xfda1ee532ac701b3030a79f7a3c628a26bb9d2243459d03b850d245ab8c2bd89",
            "STREAM_ACQUISITION_PACKET_V3": "0xd140ae87e0b02561293b804bea90e5602a0cecfde05d7708ae6211d8d8d0e0b6",
            "STREAM_ACQUISITION_PACKET_V4": "0xbf70e9aa8f0d96855dbb2660a7cf87130d09baa0bb25fb4bb2ffd0f6103a051a"}
        for name, digest in old.items():
            self.assertEqual(keccak256((v1.ROOT / "schemas/records" / (name + ".json")).read_bytes()), digest)
        self.assertEqual(keccak256(packet.PACKET_SCHEMA_BYTES), old[packet.PACKET])
        self.assertEqual(keccak256(proof.PROFILE_BYTES), "0x06eaf449a0abe6a4305706d589bc597f14f7d23f62acc661b4b1fff128b921c3")
        with self.assertRaises(MuseumError): packet.validate(dumps(self.value()))
        self.assertIn("does not change or complete acquisition packets V1–V4", v1.QUALIFICATION)

    def test_source_commitments_and_closed_identity_pins(self):
        snapshot = PublicPersonhoodFixture().result()
        for key in v1.SOURCE_REF_FIELDS:
            wrong = source_ref(snapshot); wrong[key] = ZERO
            with self.subTest(key=key), self.assertRaises(MuseumError): v1.semanticProjection(snapshot, wrong)
        for key in ("chainId", "collectionId", "core", "blockHash"):
            wrong = copy.deepcopy(snapshot); wrong["sourceState"][key] = "2" if key in ("chainId", "collectionId") else ZERO
            with self.subTest(key=key), self.assertRaises(MuseumError): v1.semanticProjection(wrong, source_ref(wrong))
        wrong = self.value(); wrong["sourceRef"]["sourceProfileHash"] = K("foreign source profile"); self.reject(wrong)
        wrong = self.value(); wrong["sourceRef"]["snapshotHash"] = ZERO; self.reject(wrong, "empty source reference")

    def test_three_identities_survive_current_rotation(self):
        f = PublicPersonhoodFixture(); changed = (*f.current_binding[:4], 2, *f.current_binding[5:])
        f.add(f.owners[0], "binding(uint256)", ("uint256",), (1,), (artist.BINDING,), (changed,))
        f.add(f.owners[2], "operativeIdentityRecord(bytes32)", ("bytes32",), (f.artist_id,), ("bytes32",), (K("later identity"),))
        f.set_selected((*f.selected[:6], False, True, 3))
        value = project(f)
        self.assertEqual(value["current"]["status"], "STALE")
        self.assertEqual(value["identities"]["originalAttested"], f.operative)
        self.assertNotEqual(value["identities"]["currentRegistration"], value["identities"]["currentOperative"])
        self.assertNotEqual(value["identities"]["currentOperative"], value["identities"]["originalAttested"])
        value["identities"]["originalAttested"] = value["identities"]["currentOperative"]
        self.reject(value, "identity projection")

    def test_unknown_origin_and_native_unresolved_do_not_invent_proof(self):
        f = PublicPersonhoodFixture(mode="legacy")
        f.reorder_logs(2, [event for event in f.receipts[H(402)]["logs"] if event is not f.native_event])
        f.set_selected((f.selected[0], ZERO_ADDRESS, *f.selected[2:]))
        value = project(f)
        self.assertTrue(value["current"]["identityCurrent"])
        self.assertIsNone(value["original"]["recordPreimageHex"])
        self.assertIsNone(value["sourceBindings"]["originalRegistry"])
        value["original"]["authorization"] = self.value()["original"]["authorization"]
        self.reject(value, "unavailable origin")
        f = PublicPersonhoodFixture(); f.set_selected((*f.selected[:3], ZERO, ZERO_ADDRESS, ZERO, False, False, 4))
        value = project(f)
        self.assertIsNotNone(value["general"])
        self.assertEqual(value["current"]["status"], "UNRESOLVED")
        self.assertEqual(value["current"]["evidenceHash"], ZERO)

    def test_same_recorder_supersession_never_replaces_selected_original(self):
        stale, other = self.value("stale_head"), self.value("other_recorder")
        self.assertFalse(stale["general"]["facts"][3]); self.assertTrue(other["general"]["facts"][3])
        self.assertEqual(stale["general"]["recordHash"], stale["original"]["summary"][9][7])
        self.assertNotEqual(stale["general"]["recordHash"], stale["general"]["facts"][2])
        stale["general"]["facts"][2] = stale["general"]["recordHash"]
        self.reject(stale, "General currentness")
        other["general"]["recorderHistory"]["eventCount"] = "1"
        self.reject(other, "recorder heads")

    def test_definition_lifecycle_and_module_currentness_are_separate(self):
        value = self.value()
        for definition in value["general"]["definitions"]: definition["facts"][2] = "2"
        value["general"]["module"][0] = "2"
        self.assertEqual(v1.validate(dumps(value)), value)
        for status in ("0", "3"):
            wrong = copy.deepcopy(value); wrong["general"]["module"][0] = status
            self.reject(wrong, "General currentness")
            wrong["general"]["facts"][2:] = [ZERO, False]
            wrong["current"]["selection"][5:] = [ZERO, True, False, "3"]
            wrong["current"].update(status="STALE", evidenceHash=ZERO, evidenceHashDomain="none", notarizationCurrent=False)
            self.assertEqual(v1.validate(dumps(wrong)), wrong)

    def test_summary_and_original_preimage_domain_tampering_fails(self):
        for index in (2, 3, 4, 7, 20, 24, 25):
            value = self.value(); value["original"]["summary"][index] = "9" if index in (7, 20) else K("changed Summary field")
            with self.subTest(index=index): self.reject(value, "Summary differs")
        value = self.value("imported")
        domain = decode(("bytes32", "bytes32", "bytes32", "uint256", "address"), hex_bytes(value["original"]["authorization"]["domainHex"]))
        self.assertEqual(domain[-1], value["sourceBindings"]["originalRegistry"])
        value["original"]["authorization"]["domainHex"] = "0x" + encode(("bytes32", "bytes32", "bytes32", "uint256", "address"),
            (*domain[:-1], value["sourceBindings"]["currentRegistry"])).hex()
        self.reject(value, "original authorization")
        value = self.value(); raw = hex_bytes(value["original"]["recordPreimageHex"])
        value["original"]["recordPreimageHex"] = "0x" + (raw[:-1] + bytes([raw[-1] ^ 1])).hex()
        self.reject(value, "op24 preimage")

    def test_original_native_authority_class_four_and_empty_direct_signature_preserved(self):
        class SuccessorFixture(PublicPersonhoodFixture):
            native_authority_class = 4
        value = project(SuccessorFixture())
        self.assertEqual(value["original"]["authorization"]["authorityClass"], "4")
        self.assertFalse(value["original"]["authorization"]["signatureCryptographyRevalidated"])
        value["original"]["signatureHex"] = "0x"
        self.assertEqual(v1.validate(dumps(value)), value)
        self.assertNotEqual(value["general"]["authority"]["signatureHex"], "0x")

    def test_general_payload_signature_receipt_and_documentary_hashes_recomputed(self):
        edits = [lambda v: v["general"].update(payloadHex="0x00"),
            lambda v: v["general"]["payloadValue"]["legalPersonRef"].update(uri="ipfs://changed-person"),
            lambda v: v["general"]["authority"].update(signatureHex="0x"),
            lambda v: v["general"]["authority"]["words"].__setitem__(4, v1.general.ESTATE),
            lambda v: v["general"]["authority"]["receipt"].__setitem__(5, K("changed chain position")),
            lambda v: v["general"].update(documentaryHash=K("changed documentary")),
            lambda v: v["general"]["subject"].__setitem__(1, "1")]
        for index, edit in enumerate(edits):
            value = self.value(); edit(value)
            with self.subTest(index=index): self.reject(value)
        value = self.value(); before = v1.general.native_record_hash(31337, value["original"]["summary"][9][5],
            v1.native(v1.general.ATTESTATION, value["general"]["attestation"]),
            v1.native(v1.general.RECEIPT, value["general"]["authority"]["receipt"]))
        value["general"]["authority"]["receipt"][5] = K("new chain")
        after = v1.general.native_record_hash(31337, value["original"]["summary"][9][5],
            v1.native(v1.general.ATTESTATION, value["general"]["attestation"]),
            v1.native(v1.general.RECEIPT, value["general"]["authority"]["receipt"]))
        self.assertEqual(before, after)
        self.reject(value, "documentary hash")

    def test_definition_and_carrier_substitution_fails(self):
        edits = [lambda d: d.update(payloadHex="0x00"), lambda d: d["facts"].__setitem__(8, K("different declaration")),
            lambda d: d.update(pointer=A(9876)), lambda d: d.update(carrierCodeHash=K("new runtime"))]
        for edit in edits:
            value = self.value(); edit(value["general"]["definitions"][0]); self.reject(value)
        value = self.value(); value["general"]["carriers"].reverse(); self.reject(value, "carriers/definitions")

    def test_retention_chronology_and_shared_source_bindings_fail_closed(self):
        value = self.value(); value["original"]["summaryCarriers"][0]["index"] = str(1 << 256)
        self.reject(value)
        value = self.value(); value["original"]["statementRetention"]["publication"] = copy.deepcopy(value["original"]["publication"])
        value["original"]["statementRetention"]["publication"]["logIndex"] = "99"
        self.reject(value, "statement retention")
        value = self.value(); value["sourceBindings"]["originalAttribution"] = A(8765)
        self.reject(value, "same Registry")
        value = self.value(); value["sourceBindings"]["currentArchive"] = value["sourceBindings"]["currentRegistry"]
        self.reject(value, "identities collide")
        value = self.value("none"); value["sourceBindings"].update({k: self.value()["sourceBindings"][k]
            for k in ("originalRegistry", "originalAttribution", "originalArchive")})
        self.reject(value, "empty head original bindings")
        value = self.value(); value["general"]["publication"]["blockHash"] = value["sourceState"]["blockHash"]
        self.reject(value, "block mapping")

    def test_native_abi_byte_limits_and_strict_scalar_endings(self):
        value = self.value(); value["general"]["module"][8] = "\U0001f600" * 2048
        self.reject(value, "module ABI byte limit")
        value = self.value(); value["general"]["attestation"][4] = value["general"]["attestation"][7] = "\U0001f600" * 2048
        self.reject(value, "General ABI byte limit")
        edits = [lambda v: v["sourceBindings"].update(currentArchive=v["sourceBindings"]["currentArchive"] + "\n"),
            lambda v: v["original"]["publication"].update(transactionHash=v["original"]["publication"]["transactionHash"] + "\n"),
            lambda v: v["original"]["statementRetention"].update(index="0\n")]
        for edit in edits:
            value = self.value(); edit(value); self.reject(value)

    def test_global_distinct_event_log_slot_and_transaction_order(self):
        value = self.value()
        value["original"]["statementRetention"]["publication"] = copy.deepcopy(value["general"]["publication"])
        self.reject(value, "distinct events share a block log position")
        value = self.value()
        original = value["original"]["publication"]
        value["general"]["publication"].update(blockNumber=original["blockNumber"], blockHash=original["blockHash"],
            transactionIndex="0", transactionHash=K("earlier transaction"), logIndex="100")
        for row in [value["original"]["publication"], value["original"]["statementRetention"]["publication"],
                *[r["publication"] for r in value["original"]["summaryRetentions"]],
                *[r["publication"] for r in value["original"]["summaryCarriers"]]]:
            row["transactionIndex"] = "1"
        self.reject(value, "block log/transaction order")

    def test_distinct_registry_domains_cannot_share_immutable_owners(self):
        value = self.value("imported"); bindings = value["sourceBindings"]
        self.assertNotEqual(bindings["currentRegistry"], bindings["originalRegistry"])
        bindings["currentAttribution"], bindings["currentArchive"] = bindings["originalAttribution"], bindings["originalArchive"]
        value["original"]["summaryRetentions"] = [r for r in value["original"]["summaryRetentions"] if r["owner"] == bindings["originalAttribution"]]
        value["original"]["summaryCarriers"] = [r for r in value["original"]["summaryCarriers"]
            if r["owner"] in (bindings["originalAttribution"], bindings["originalArchive"])]
        self.reject(value, "conflicting Registries")

    def test_rehashed_same_address_different_runtime_is_impossible(self):
        value = self.value(); row, original = value["general"], value["original"]
        self.assertNotEqual(row["carriers"][0]["runtimeHash"], row["carriers"][1]["runtimeHash"])
        row["carriers"][1]["address"] = row["carriers"][0]["address"]
        original["summary"][26][1] = original["summary"][26][0]
        digest = proof.summary_hash(v1.native(proof.SUMMARY, original["summary"]))
        original["summaryHash"] = value["current"]["evidenceHash"] = digest
        for carrier in original["summaryCarriers"]: carrier["payloadHash"] = digest
        self.reject(value, "runtime commitments conflict")
        value = self.value(); value["original"]["statementRetention"]["pointer"] = value["original"]["summaryCarriers"][0]["pointer"]
        self.reject(value, "runtime commitments conflict")
        # Original owner and archive intentionally retain the same immutable Summary carrier.
        original = self.value()["original"]
        self.assertEqual(original["summaryCarriers"][0]["pointer"], original["summaryCarriers"][1]["pointer"])
        self.assertEqual(v1.validate(dumps(self.value())), self.value())


if __name__ == "__main__": unittest.main()
