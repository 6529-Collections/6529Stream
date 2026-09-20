"""Adversarial boundaries for synthetic native preservation sources.

These fixtures reproduce native-shaped reads and receipts.  They do not prove
that an EVM executed them or that any chain reached consensus.
"""
from copy import deepcopy
import unittest

from . import acquisition_preservation_v5 as assembly
from . import public_media_master_source as media
from . import public_prospective_reference_source as reference
from .canonical import MuseumError, keccak256, loads, schema_id
from .chain_abi import encode
from .independent_wire import ZERO
from .test_public_media_master_source import PublicMediaMasterFixture
from .test_public_prospective_reference_source import PublicProspectiveReferenceFixture
from .preservation_v5_fixture import PreservationV5Fixture

H = lambda value: keccak256(repr(value).encode("utf-8"))


def publication(block, log=0):
    return {"blockNumber": str(block), "transactionIndex": "0", "logIndex": str(log),
        "blockHash": H(block), "transactionHash": H((block, 0))}


def prospective_release(fixture, snapshot, *, block=3, record=0):
    row = snapshot["records"][record]
    source = row["originalSource"]
    context = source[3]
    receipt = [row["recordHash"], H("release key"), "1", H("tier"), fixture.signer,
        H("settlement"), str(block), "1", source[1], context,
        [context[4], H("media evidence"), row["evidenceHash"]]]
    release = {"receiptHash": H("release receipt"), "releaseKey": H("release key"),
        "collectionId": "1", "sourceId": source[0], "sourceSetHash": source[1],
        "publication": publication(block), "receipt": receipt}
    catalogue = {"sources": [{"sourceId": source[0], "source": source[2],
        "admission": {"publication": publication(1)}}]}
    return release, catalogue


def master_release(snapshot, *, block=3, candidate=0, at=None):
    selected = snapshot["historicalCandidates"][candidate]
    context = [selected["subjectId"], H("membership"), selected["inventoryHash"],
        H("script"), H("source context"), True]
    receipt = [H("release receipt"), H("release key"), "1", H("tier"),
        "0x" + "11" * 20, H("settlement"), str(block), "1", H("source head"),
        context, [context[4], selected["factsHash"], ZERO]]
    return {"receiptHash": receipt[0], "releaseKey": receipt[1], "collectionId": "1",
        "sourceId": "1", "sourceSetHash": receipt[8], "publication": at or publication(block),
        "receipt": receipt}


def immediately_after(row):
    result = deepcopy(row["publication"])
    result["logIndex"] = str(int(result["logIndex"]) + 1)
    return result


class PublicPreservationAdversarialTests(unittest.TestCase):
    def test_concrete_nine_source_assembly_retains_native_evidence_without_chain_claim(self):
        inputs = PreservationV5Fixture().preservation_inputs()
        result = assembly.compose(*sum(([value.files, value.manifest_hash] for value in inputs), []),
            disclosure="public")
        verified = assembly.verify(result.files, result.manifest_hash)
        release = verified.report["nativePreservationJoin"]["releases"][0]
        self.assertEqual(release["masters"]["status"], "original_native_master_evidence_joined")
        self.assertEqual(release["references"]["status"], "original_native_prospective_evidence_joined")
        self.assertFalse(verified.report["claims"]["actualChainAcceptance"])
        self.assertFalse(verified.report["claims"]["sourceConsensusVerified"])
        self.assertFalse(verified.report["nativePreservationJoin"]["historicalExecutionRevalidated"])

    def test_prospective_record_chain_and_floor_evidence_domains_are_independent(self):
        fixture = PublicProspectiveReferenceFixture()
        row = fixture.prospective_rows[0]
        anchor, dep, p, r = fixture.prospective_anchor, row["dependencies"], row["publication"], row["receipt"]
        unsigned = (ZERO, ZERO, *r[2:])
        record = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", reference.PUBLICATION, reference.RECEIPT),
            (schema_id("6529STREAM_PROSPECTIVE_REFERENCE_RECORD_V1"), 31337,
                anchor["host"], anchor["core"], dep[0][1], p, unsigned)))
        self.assertEqual(record, r[0])
        chain = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "uint256", "bytes32", "uint64", "bytes32"),
            (schema_id("6529STREAM_PROSPECTIVE_REFERENCE_CHAIN_V1"), 31337,
                anchor["host"], anchor["core"], 1, ZERO, 1, record)))
        self.assertEqual(chain, r[1])
        evidence = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "uint256", "bytes32", "bytes32", reference.RECEIPT),
            (schema_id("6529STREAM_PROSPECTIVE_COLLECTION_REFERENCE_EVIDENCE_V1"), 31337,
                anchor["host"], anchor["core"], dep[0][1], 1, r[6], r[7], r)))
        self.assertEqual(evidence, row["evidenceHash"])
        self.assertNotEqual(record, evidence)

    def test_prospective_payload_tail_cannot_hide_behind_original_record(self):
        fixture = PublicProspectiveReferenceFixture()
        fixture.prospective_rows[0]["payload"] += b"\x00"
        fixture._prospective_heads()
        with self.assertRaises(MuseumError):
            fixture.source().snapshot()

    def test_prospective_count_cannot_claim_an_unobserved_history_suffix(self):
        fixture = PublicProspectiveReferenceFixture()
        fixture.add(fixture.prospective_host, "prospectiveCount(uint256)", ("uint256",), (1,),
            ("uint256",), (2,))
        with self.assertRaisesRegex(MuseumError, "event/count denominator"):
            fixture.source().snapshot()

    def test_gas_change_between_publication_and_release_rejects_but_later_raise_does_not(self):
        fixture = PublicProspectiveReferenceFixture()
        fixture.raise_prospective_gas(block=2, index=0)
        snapshot = fixture.result()
        release, catalogue = prospective_release(fixture, snapshot, block=3)
        with self.assertRaisesRegex(MuseumError, "gas changed before original release"):
            assembly._reference_join(release, snapshot, catalogue)

        later = PublicProspectiveReferenceFixture(raised=True)
        later_snapshot = later.result()
        release, catalogue = prospective_release(later, later_snapshot, block=3)
        joined = assembly._reference_join(release, later_snapshot, catalogue)
        self.assertEqual(joined["status"], "original_native_prospective_evidence_joined")
        self.assertFalse(joined["historicalSourceExecutionRevalidated"])

    def test_reference_supersession_is_evaluated_at_original_release_position(self):
        fixture = PublicProspectiveReferenceFixture("superseded")
        snapshot = fixture.result()
        early, catalogue = prospective_release(fixture, snapshot, block=3)
        self.assertTrue(assembly._reference_join(early, snapshot, catalogue)["headAtReleaseMatches"])
        late, catalogue = prospective_release(fixture, snapshot, block=5)
        with self.assertRaisesRegex(MuseumError, "reference superseded before"):
            assembly._reference_join(late, snapshot, catalogue)

    def test_media_selection_hash_uses_selector_host_and_complete_row(self):
        fixture = PublicMediaMasterFixture()
        row = fixture.media_selections[1][0]
        anchor = fixture.media_anchor
        expected = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "address", "address", "bytes32", "uint256", media.SELECTION),
            (schema_id("6529STREAM_MEDIA_MASTER_SELECTION_V1"), 31337,
                anchor["mediaMaster"], anchor["core"], anchor["host"], anchor["schemas"],
                anchor["externalCoverage"], media.NATIVE_PROFILE_HASH, 1, (*row[:-1], ZERO))))
        self.assertEqual(expected, row[13])
        wrong_host = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "address", "address", "bytes32", "uint256", media.SELECTION),
            (schema_id("6529STREAM_MEDIA_MASTER_SELECTION_V1"), 31337,
                anchor["host"], anchor["core"], anchor["host"], anchor["schemas"],
                anchor["externalCoverage"], media.NATIVE_PROFILE_HASH, 1, (*row[:-1], ZERO))))
        self.assertNotEqual(expected, wrong_host)

        result = fixture.result()
        candidate = result["historicalCandidates"][0]
        hashes = tuple(candidate["hashes"])
        association = media.native(media.ASSOCIATION, candidate["association"])
        facts = keccak256(encode(
            ("bytes32", "uint256", "address", "address", "address", "address", "uint256",
                "bytes32", "bytes32", "bytes32", ("bytes32",) * 3, media.ASSOCIATION),
            (media.NATIVE_PROFILE_HASH, 31337, anchor["mediaMaster"], anchor["core"],
                anchor["host"], anchor["externalCoverage"], 1, candidate["subjectId"],
                candidate["manifestHash"], candidate["inventoryHash"], hashes, association)))
        facts = keccak256(encode(("bytes32", "uint8", "bytes32", "bytes32"),
            (facts, 1, row[13], candidate["archiveHashes"][0])))
        self.assertEqual(facts, candidate["factsHash"])

    def test_saved_media_coverage_is_retained_without_current_liveness_claim(self):
        result = PublicMediaMasterFixture().result()
        self.assertEqual(result["coverage"][0]["currentLiveness"], "not_checked")
        self.assertFalse(result["claims"]["currentArchiveLivenessChecked"])
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["archiveRetrievalProven"])

    def test_media_head_cannot_omit_a_selected_history_suffix(self):
        fixture = PublicMediaMasterFixture("replaced")
        first = fixture.media_selections[1][0]
        fixture.add(fixture.media_master, "currentMaster(uint256,bytes32,uint8)",
            ("uint256", "bytes32", "uint8"), (1, fixture.media_subject, 1),
            (media.SELECTION,), (first,))
        with self.assertRaisesRegex(MuseumError, "event/history"):
            fixture.source().snapshot()

    def test_manifest_selected_after_release_is_separate_but_before_release_invalidates(self):
        fixture = PublicMediaMasterFixture("manifest_changed")
        snapshot = fixture.result()
        release = master_release(snapshot, block=3)
        self.assertEqual(assembly._master_join(release, snapshot)["status"],
            "original_native_master_evidence_joined")
        release = master_release(snapshot, block=5)
        with self.assertRaisesRegex(MuseumError, "selected manifest changed before"):
            assembly._master_join(release, snapshot)

    def test_router_reselection_a_b_a_uses_the_actual_release_boundary(self):
        fixture = PublicMediaMasterFixture("manifest_changed")
        fixture.media_reselect(fixture.media_manifests[0], block=5)
        snapshot = fixture.result()
        self.assertEqual([row["manifestHash"] for row in snapshot["manifestSelections"]],
            [fixture.media_manifests[0]["hash"], fixture.media_manifests[1]["hash"],
                fixture.media_manifests[0]["hash"]])
        during_b = master_release(snapshot, at=immediately_after(snapshot["manifestSelections"][1]))
        with self.assertRaisesRegex(MuseumError, "selected manifest changed before"):
            assembly._master_join(during_b, snapshot)
        after_a = master_release(snapshot, at=immediately_after(snapshot["manifestSelections"][2]))
        self.assertEqual(assembly._master_join(after_a, snapshot)["status"],
            "original_native_master_evidence_joined")

    def test_same_manifest_and_host_with_wrong_runtime_is_not_a_valid_release_selection(self):
        fixture = PublicMediaMasterFixture()
        anchor = fixture.media_anchor
        manifest = fixture.media_manifests[0]
        fixture.event(4, anchor["router"],
            [media.MANIFEST_SELECTED_EVENT, manifest["event"]["topics"][1],
                manifest["event"]["topics"][2], manifest["hash"]],
            ("uint16", "address", "bytes32"),
            (1, anchor["host"], H("wrong historical Metadata runtime")))
        fixture.media_reselect(manifest, block=5)
        snapshot = fixture.result()
        wrong = snapshot["manifestSelections"][1]
        self.assertEqual((wrong["manifestHash"], wrong["host"]),
            (manifest["hash"], anchor["host"]))
        self.assertFalse(wrong["supportedHost"])
        with self.assertRaisesRegex(MuseumError, "selected manifest changed before"):
            assembly._master_join(master_release(snapshot, at=immediately_after(wrong)), snapshot)

    def test_cleared_manifest_is_a_real_historical_boundary_not_absence(self):
        fixture = PublicMediaMasterFixture()
        fixture.media_clear(block=4)
        fixture.media_reselect(fixture.media_manifests[0], block=5)
        snapshot = fixture.result()
        cleared = snapshot["manifestSelections"][1]
        self.assertEqual((cleared["manifestHash"], cleared["host"], cleared["codeHash"]),
            (ZERO, "0x" + "00" * 20, ZERO))
        release = master_release(snapshot, at=immediately_after(cleared))
        with self.assertRaisesRegex(MuseumError, "selected manifest changed before"):
            assembly._master_join(release, snapshot)
        restored = master_release(snapshot, at=immediately_after(snapshot["manifestSelections"][2]))
        self.assertEqual(assembly._master_join(restored, snapshot)["status"],
            "original_native_master_evidence_joined")

    def test_writer_impossible_stored_manifest_is_retained_but_not_supported(self):
        fixture = PublicMediaMasterFixture()
        anchor = fixture.media_anchor
        manifest = (1, "opaque:synthetic-inline", H("opaque display"), "image/png") \
            + (0, "", ZERO, "") * 2 + ("", ZERO, "", ZERO)
        source_hash = media.h(("string", "string"), (manifest[1], ""))
        digest = media.h(
            ("bytes32", "uint256", "address", "address", "address", "bytes32",
                "uint256", "bytes32", media.MANIFEST),
            (schema_id("6529STREAM_CURRENT_MEDIA_MANIFEST_V1"), 31337,
                anchor["core"], anchor["host"], anchor["router"],
                fixture.pins[anchor["router"]], 1, source_hash, manifest))
        fixture.add(anchor["host"], "recordedMediaManifest(bytes32)",
            ("bytes32",), (digest,), (media.MANIFEST,), (manifest,))
        original = fixture.media_manifests[0]["event"]
        fixture.event(4, anchor["host"],
            [media.MANIFEST_EVENT, original["topics"][1], original["topics"][2], digest],
            ("uint16", "address", "bytes32"), (1, anchor["router"], source_hash))

        snapshot = fixture.result()
        retained, = [row for row in snapshot["manifests"] if row["manifestHash"] == digest]
        self.assertFalse(retained["nativeWriterShape"])
        self.assertFalse(retained["sharedSlotProfile"])
        self.assertEqual(retained["hashes"], [manifest[2], ZERO, ZERO])
        self.assertFalse(any(row["manifestHash"] == digest
            for row in snapshot["historicalCandidates"]))

    def test_empty_denominator_current_candidate_is_not_backdated(self):
        snapshot = PublicMediaMasterFixture("empty").result()
        candidate = snapshot["historicalCandidates"][0]
        self.assertIsNone(candidate["publication"])
        release = master_release(snapshot, block=3)
        result = assembly._master_join(release, snapshot)
        self.assertEqual(result["status"], "historical_empty_inventory_association_unresolved")
        self.assertIsNone(result["candidate"])


if __name__ == "__main__":
    unittest.main()
