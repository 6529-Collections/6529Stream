"""Native document planning only; no onchain registration execution claim."""

from dataclasses import FrozenInstanceError
from hashlib import sha256
from pathlib import Path
import unittest

from Crypto.Hash import keccak

from .canonical import MuseumError, loads, schema_id
from .dependencies import OfflineDocuments
from .publication import MAX_CHUNKS, MAX_DOCUMENT_BYTES, PublicationPlan, ZERO


def plan(content, **changes):
    args = dict(name="EXACT_BYTES_V1", kind="DEPENDENCY", canonicalization_id=schema_id("RAW_BYTES"),
                supersedes_id=ZERO, uri="urn:fixture:document", content=content)
    return PublicationPlan(**(args | changes))


class Publication(unittest.TestCase):
    def test_exact64_limit_and_canonical54_chunk_shape(self):
        self.assertEqual((MAX_CHUNKS, MAX_DOCUMENT_BYTES), (64, 524288))
        maximum = plan(bytes(range(256)) * 2048)
        self.assertEqual(len(maximum.chunks), 64)
        self.assertEqual(set(map(len, maximum.chunks)), {8192})
        self.assertEqual(b"".join(maximum.chunks), maximum.content)
        # Shape oracle only; the separately captured official CRM bytes retain their own hash proof.
        shape = plan(b"x" * 434213)
        self.assertEqual(len(shape.chunks), 54)
        self.assertEqual(tuple(map(len, shape.chunks)), (8192,) * 53 + (37,))
        for bad in (b"", bytes(524289), bytearray(b"mutable")):
            with self.assertRaises(MuseumError):
                plan(bad)
        with self.assertRaises(FrozenInstanceError):
            maximum.content = b"other"

    def test_exact_context10_whole_and_ordered_keccak_prospective_metadata(self):
        root = Path(__file__).resolve().parents[2] / "schemas/museum/fixtures/dependencies"
        raw = OfflineDocuments(root, loads((root / "index.json").read_bytes())).load(
            "https://linked.art/ns/v1/linked-art.json")
        document = plan(raw, name="LINKED_ART_CONTEXT_a3b57fae_V1")
        metadata = document.metadata()
        self.assertEqual(sha256(raw).hexdigest(), "3017421203aba8ea73f159aced1285e35b37cee49b5648cf19b01f237025f165")
        self.assertEqual(metadata["specification"], {
            "name": "LINKED_ART_CONTEXT_a3b57fae_V1", "kind": "3",
            "contentHash": "0x" + keccak.new(digest_bits=256, data=raw).hexdigest(),
            "canonicalizationId": schema_id("RAW_BYTES"), "supersedesId": ZERO,
            "uri": "urn:fixture:document", "totalBytes": "79235"})
        self.assertEqual(metadata["chunkByteLengths"], ["8192"] * 9 + ["5507"])
        self.assertEqual(metadata["chunkHashes"], ["0x" + keccak.new(digest_bits=256,
            data=raw[i:i + 8192]).hexdigest() for i in range(0, len(raw), 8192)])
        self.assertEqual(metadata["mode"], "prospective_unregistered")
        self.assertFalse(any(metadata["claims"].values()))
        self.assertNotEqual(plan(raw[::-1]).metadata()["chunkHashes"], metadata["chunkHashes"])

    def test_exact_name_kind_uri_bytes_and_definition_pins(self):
        self.assertEqual(plan(b"x", name="A" * 128, uri="\u00e9" * 1024).metadata()["specification"]["totalBytes"], "1")
        for changes in ({"name": "a b"}, {"name": "A" * 129}, {"kind": "UNKNOWN"},
                        {"uri": "\u00e9" * 1025}, {"uri": "\ud800"},
                        {"canonicalization_id": ZERO}, {"supersedes_id": "0x1"}):
            with self.subTest(changes=repr(changes)), self.assertRaises(MuseumError):
                plan(b"x", **changes)
        original = plan(b"exact")
        newer = plan(b"exact", name="EXACT_BYTES_V2", supersedes_id=original.metadata()["documentId"])
        self.assertNotEqual(original.metadata()["documentId"], newer.metadata()["documentId"])
        self.assertEqual(original.metadata()["specification"]["contentHash"], newer.metadata()["specification"]["contentHash"])
        self.assertEqual(newer.metadata()["specification"]["supersedesId"], original.metadata()["documentId"])


if __name__ == "__main__":
    unittest.main()
