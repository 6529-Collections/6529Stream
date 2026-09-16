"""Actual local ARCHIVE evidence; no network or publisher/human promotion."""
from copy import deepcopy
from pathlib import Path
import unittest
from unittest.mock import patch

from .archive_evidence import verify_evidence
from .archive_fixture import read, rebuild
from .canonical import MuseumError, dumps, keccak256, loads
from .semantic_export import MANIFEST_PATH

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum/archival-export/local-fixture"
MANIFEST_HASH = "0x92d26a64ba30e5b5827a323668e29a2f76264b286b8068615334b48781c2e518"


class ActualArchiveCapture(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.inputs, cls.retained = read(ROOT, MANIFEST_HASH)
        with patch("socket.socket", side_effect=AssertionError("archive replay used network")):
            cls.package, cls.report = rebuild(cls.inputs)
        cls.manifest_bytes = dict(cls.package.files)[MANIFEST_PATH]
        cls.original = loads(cls.inputs["archive-publication.json"], maximum=8388608, canonical=True)

    def verify_altered(self, value, pattern):
        raw = dumps(value)
        with self.assertRaisesRegex(MuseumError, pattern):
            verify_evidence(raw, keccak256(raw), self.manifest_bytes,
                source_anchor_bytes=self.inputs["anchor.json"])

    def test_actual_archive_record_rebuilds_without_becoming_a_source(self):
        self.assertEqual(self.package.manifest_hash, self.retained["exportManifestHash"])
        self.assertEqual(self.report["recordHash"], self.retained["archiveRecordHash"])
        self.assertEqual(self.report["historicalAuthorizationClass"], "PRESERVATION_ADMIN")
        capture = loads(self.inputs["source-capture.json"], maximum=67108864)
        self.assertEqual(len(capture["records"]), 15)
        self.assertNotIn(self.report["recordHash"], {r["recordHash"] for r in capture["records"]})
        self.assertEqual(self.original["payloadByteLength"], str(len(self.manifest_bytes)))
        self.assertLessEqual(len(self.manifest_bytes), 8192)
        self.assertFalse(self.report["consensusProof"])
        self.assertEqual(self.retained["snapshotMode"], "synthetic_fixture")
        self.assertFalse(self.retained["authorityPublisherAuthenticated"])

    def test_external_fixture_and_evidence_pins_are_required(self):
        with self.assertRaisesRegex(MuseumError, "external pin differs"):
            read(ROOT, "0x" + "ff" * 32)
        with self.assertRaisesRegex(MuseumError, "external pin differs"):
            verify_evidence(self.inputs["archive-publication.json"], "0x" + "ff" * 32,
                self.manifest_bytes, source_anchor_bytes=self.inputs["anchor.json"])

    def test_rehashed_receipt_event_cannot_move_to_another_transaction(self):
        value = deepcopy(self.original); old = value["publicationReceipt"]["transactionHash"]
        new = "0x" + "aa" * 32
        value["publicationReceipt"]["transactionHash"] = new
        value["publicationEvent"]["transactionHash"] = new
        for event in value["publicationReceipt"]["logs"]: event["transactionHash"] = new
        for row in value["publicationTransactions"]:
            if row["transactionHash"] == old:
                row["transactionHash"] = new; row["receipt"] = deepcopy(value["publicationReceipt"])
        self.verify_altered(value, "block transaction differs")

    def test_disconnected_parent_trail_cannot_bind_the_source(self):
        value = deepcopy(self.original)
        value["publicationBlock"]["parentHash"] = "0x" + "bb" * 32
        value["publicationAncestry"][0]["parentHash"] = "0x" + "bb" * 32
        self.verify_altered(value, "ancestry differs")

    def test_archive_runtime_and_original_authority_are_exact(self):
        value = deepcopy(self.original); value["metadataRuntimeHash"] = "0x" + "cc" * 32
        self.verify_altered(value, "runtime pins")
        value = deepcopy(self.original); value["recordReceipt"][2] = "8"
        self.verify_altered(value, "historical receipt differs")
        value = deepcopy(self.original); value["recordChainHash"] = "0x" + "dd" * 32
        self.verify_altered(value, "chain preimage differs")

    def test_schema_policy_and_payload_cannot_be_replaced_after_rehash(self):
        value = deepcopy(self.original); value["registeredDocuments"]["policy"]["bytesHex"] = "0x7b7d"
        self.verify_altered(value, "registered input differs")
        value = deepcopy(self.original); value["payloadBytesHex"] = "0x7b7d"
        self.verify_altered(value, "retained payload differs")


if __name__ == "__main__": unittest.main()
