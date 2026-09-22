"""Actual raw-reader replays of synthetic originals; no native execution claim."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import artist_attestation_source as artist
from . import metadata_catalog_source as metadata
from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import decode, encode
from .chain_rpc import ReplayTransport
from .native_artist_review_test_fixture import NativeArtistReviewFixture, A, H
from .native_artist_review_profile import NativeArtistReviewProfile
from .native_attribution_profile import NativeAttributionProfile
from .native_attribution_semantics import NativeAttributionSemanticSource, selector
from .test_metadata_catalog_source import Transport


def ordered(snapshot):
    """Derive chronology from the admitted original publication coordinates."""
    return sorted(snapshot["attestations"], key=lambda r: tuple(int(r["metadataPublicationPosition"][key])
        for key in ("blockNumber", "transactionIndex", "logIndex")))


class NativeArtistReviewPublicationTests(unittest.TestCase):
    def test_two_original_semantic_publications_have_complete_backlinks(self):
        f = NativeArtistReviewFixture(profile=NativeAttributionProfile())
        source, snapshot = f.capture()
        rows = ordered(snapshot)
        self.assertEqual(snapshot["mode"], "synthetic_fixture")
        self.assertEqual(len(rows), 2)
        self.assertEqual(len(snapshot["identities"]), 2)
        self.assertFalse(snapshot["claims"]["actualChainAcceptance"])
        self.assertFalse(snapshot["claims"]["reviewerIndependenceProven"])
        catalogue = loads(source.metadata_catalog.snapshot(), maximum=artist.MAX_SNAPSHOT)
        self.assertEqual(len(catalogue["records"]), 3)  # original documentary row and both publications
        self.assertEqual([r["metadataPublicationPosition"]["blockNumber"] for r in rows], ["4", "6"])
        for index, native in enumerate(rows):
            expected = f.publications[index]
            self.assertEqual(native["metadataOriginal"], expected["original"])
            self.assertEqual(selector(native["metadataOriginal"], A(1)), expected["selector"])
            self.assertEqual(native["archive"]["bytesHex"], "0x" + expected["archiveRaw"].hex())
            self.assertEqual(native["historicalBindingWire"], list(map(lambda x: str(x) if type(x) is int else x, expected["binding"])))
            self.assertEqual(native["associationWire"][0], native["historicalAuthority"]["artistId"])
            self.assertNotEqual(native["historicalAuthority"]["artistId"], artist.ZERO)
        self.assertFalse(rows[0]["current"]["statusAppliesToOriginalRecord"])
        self.assertTrue(rows[1]["current"]["statusAppliesToOriginalRecord"])
        semantic = NativeAttributionSemanticSource(source, Transport(f.responses), profile=f.semantic_profile)
        meanings = loads(semantic.snapshot(), maximum=artist.MAX_SNAPSHOT)
        self.assertEqual([r["status"] for r in meanings["statements"]], ["supported", "supported"])

    def test_default_profile_and_semantic_adapter_agree(self):
        f = NativeArtistReviewFixture()
        self.assertIs(type(f.semantic_profile), NativeArtistReviewProfile)
        semantic = f.semantic()
        snapshot = loads(semantic.snapshot(), maximum=artist.MAX_SNAPSHOT)
        self.assertEqual(snapshot["interpretationProfileHash"], f.semantic_profile.profile_hash)
        self.assertEqual(len(snapshot["statements"]), 2)
        self.assertTrue(snapshot["documents"])
        for row in snapshot["statements"]:
            self.assertEqual(row["status"], "supported")
            self.assertEqual(row["value"]["profileHash"], f.semantic_profile.profile_hash)
        self.assertFalse(snapshot["claims"]["actualChainAcceptance"])

    def test_callback_uses_sealed_first_original_and_three_complete_records(self):
        seen = []
        def callback(context):
            seen.append(deepcopy(context))
            first = context["previous"][0]
            raw = hex_bytes(first["original"]["payloadHex"])
            value = loads(raw)
            value["assertions"][0]["id"] = "urn:fixture:third-original"
            value["assertions"][0]["assertingAgent"] = "eip155:31337:" + context["signer"]
            return dumps(value)
        f = NativeArtistReviewFixture([{}, {}, {"payload": callback}])
        _, snapshot = f.capture()
        rows = ordered(snapshot)
        self.assertEqual(len(rows), 3)
        self.assertEqual([r["metadataOriginal"]["receipt"][4] for r in rows], ["0", "1", "2"])
        self.assertEqual([r["metadataPublicationPosition"]["blockNumber"] for r in rows], ["4", "6", "8"])
        first = seen[0]["previous"][0]
        self.assertEqual(first["original"], rows[0]["metadataOriginal"])
        self.assertEqual(first["nativeAuthority"]["operationEvidenceHash"], keccak256(hex_bytes(rows[0]["archive"]["bytesHex"])))
        self.assertEqual(first["nativeAuthority"]["attestationRecordHash"], rows[0]["attestationRecordHash"])
        self.assertEqual(first["nativeAuthority"]["operationEvidenceId"], rows[0]["archive"]["evidenceId"])

    def test_same_artist_rotated_signer_preserves_original_identity_and_accounts(self):
        f = NativeArtistReviewFixture(mode="same_artist")
        _, snapshot = f.capture()
        first, second = ordered(snapshot)
        self.assertEqual(len(snapshot["identities"]), 1)
        self.assertEqual(first["historicalAuthority"]["artistId"], second["historicalAuthority"]["artistId"])
        self.assertEqual([r["historicalAuthority"]["signer"] for r in (first, second)], [A(8), A(14)])
        self.assertEqual(first["current"]["identity"][0], A(14))
        self.assertEqual(first["historicalAuthority"]["bindingGeneration"], "1")
        self.assertEqual(second["historicalAuthority"]["bindingGeneration"], "2")

    def test_distinct_artist_same_signer_is_not_human_independence(self):
        _, snapshot = NativeArtistReviewFixture(mode="same_signer").capture()
        first, second = ordered(snapshot)
        self.assertNotEqual(first["historicalAuthority"]["artistId"], second["historicalAuthority"]["artistId"])
        self.assertEqual(first["historicalAuthority"]["signer"], second["historicalAuthority"]["signer"])
        self.assertFalse(snapshot["claims"]["reviewerIndependenceProven"])

    def test_original_relay_actor_signature_and_delegated_grant_remain_distinct(self):
        f = NativeArtistReviewFixture(relayed=True, delegated=True)
        _, snapshot = f.capture()
        for index, row in enumerate(ordered(snapshot)):
            outer = decode(artist.ARCHIVE, hex_bytes(row["archive"]["bytesHex"]))
            self.assertEqual(outer[3], A(70 + index))
            self.assertNotEqual(outer[3], row["historicalAuthority"]["signer"])
            self.assertFalse(row["signatureEvidence"]["currentSignatureRevalidated"])
            self.assertEqual(row["signatureHex"], "0x" + f.publications[index]["signature"].hex())
        second = ordered(snapshot)[1]
        self.assertEqual(second["historicalAuthority"]["authorityClass"], "2")
        delegation = second["signatureEvidence"]["delegation"]
        self.assertFalse(delegation["originalWire"][4])
        self.assertTrue(delegation["currentWire"][4])
        self.assertEqual(delegation["recordHash"], second["associationWire"][3])
        self.assertEqual(len(delegation["originalEvents"]), 2)

    def test_second_original_binding_getter_cannot_be_replaced_by_current_binding(self):
        f = NativeArtistReviewFixture()
        bad = list(f.publications[1]["binding"]); bad[3] = H("wrong original binding")
        f.call("bindingAt(uint256,uint64)", (artist.BINDING,), (tuple(bad),), ("uint256", "uint64"), (7, 2), target=A(40))
        with self.assertRaisesRegex(MuseumError, "original binding archive"):
            f.capture()

    def test_coherently_rehashed_second_archive_cannot_change_direct_actor(self):
        f = NativeArtistReviewFixture()
        entry = f.publications[1]
        outer = list(decode(artist.ARCHIVE, entry["archiveRaw"])); outer[3] = A(79)
        new_key = artist._hash(("bytes32", "uint256", "address", "address", "uint16", "address", "bytes32"),
            (schema_id("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"), 31337, A(5), f.coordinator, 24, outer[3], outer[4]))
        entry["archiveId"] = new_key; entry["archiveEvent"]["topics"][1] = new_key
        f.reseal_archive(1, encode(artist.ARCHIVE, tuple(outer)))
        with self.assertRaisesRegex(MuseumError, "original direct authority"):
            f.capture()

    def test_missing_second_archive_is_not_an_uninterpreted_or_empty_record(self):
        f = NativeArtistReviewFixture()
        entry = f.publications[1]
        receipt = f.receipts[entry["archiveEvent"]["transactionHash"]]
        receipt["logs"].remove(entry["archiveEvent"])
        for index, log in enumerate(receipt["logs"]): log["logIndex"] = hex(index)
        with self.assertRaisesRegex(MuseumError, "original op24 archive missing"):
            f.capture()

    def test_second_nonce_and_payload_bytes_are_required_originals(self):
        f = NativeArtistReviewFixture()
        row = f.publications[1]
        f.call("nonceUsed(bytes32,uint256)", ("bool",), (False,), ("bytes32", "uint256"),
               (row["binding"][0], 18), target=A(42))
        with self.assertRaisesRegex(MuseumError, "original nonce"):
            f.capture()
        f = NativeArtistReviewFixture()
        row = f.publications[1]
        f.put("eth_getCode", [row["original"]["payloadPointer"], f.block_ref], "0x00" + b"changed original".hex())
        with self.assertRaises(MuseumError): f.capture()

    def test_new_schema_name_is_not_smuggled_through_frozen_artist_gate(self):
        f = NativeArtistReviewFixture([{}, {"schemaId": schema_id("UNADMITTED_NEW_ARTIST_REVIEW_SCHEMA")}])
        with self.assertRaisesRegex(MuseumError, "historical artist receipt"):
            f.capture()

    def test_complete_metadata_and_artist_transcripts_replay_without_network(self):
        f = NativeArtistReviewFixture([{}, {}, {}], mode="same_artist")
        source, _ = f.capture()
        raw_metadata = source.metadata_catalog.transcript()
        raw_artist = source.transcript()
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            catalogue = metadata.MetadataCatalogSource(dumps(f.anchor), ReplayTransport(raw_metadata, keccak256(raw_metadata)))
            replay = artist.ArtistAttestationSource(catalogue, ReplayTransport(raw_artist, keccak256(raw_artist)))
            self.assertEqual(replay.snapshot(), source.snapshot())
            self.assertEqual(catalogue.snapshot(), source.metadata_catalog.snapshot())
        value = loads(raw_artist, maximum=artist.MAX_TRANSCRIPT)
        value["calls"].append(deepcopy(value["calls"][-1]))
        extra = dumps(value)
        catalogue = metadata.MetadataCatalogSource(dumps(f.anchor), ReplayTransport(raw_metadata, keccak256(raw_metadata)))
        with self.assertRaises(MuseumError):
            artist.ArtistAttestationSource(catalogue, ReplayTransport(extra, keccak256(extra))).snapshot()


if __name__ == "__main__":
    unittest.main()
