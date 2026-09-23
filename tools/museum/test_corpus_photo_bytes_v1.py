"""The photograph supplement has actual retained synthetic pixels and four exports."""

from hashlib import sha256
from pathlib import Path
import struct
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch
import zlib

from lxml import etree

from .canonical import MuseumError, dumps, loads
from .corpus_semantic_v1 import MODEL_ROOT, build, verify
from .corpus_v2 import build as build_corpus
from .iiif_numbers import target_loads
from .lido_model import NS as LIDO_NS
from .package import write_package
from .package_v2 import _assemble, verify_fixture_package
from .premis import NS as PREMIS_NS


class ByteBackedSyntheticPhotograph(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.corpus = cls.root / "corpus"
        cls.corpus_hash = build_corpus(cls.corpus)
        cls.package = build(cls.corpus, cls.corpus_hash, version="5")
        cls.files = dict(cls.package.files)
        cls.output = cls.root / "photo"
        write_package(cls.package, cls.output)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def _four(self, name):
        return self.files["formats/byte-backed/package/" + name]

    def test_received_png_and_four_format_file_identity(self):
        source = loads(self.files["input/corpus/photograph/source/payload.json"])
        joined = loads(self.files["formats/byte-backed/correspondence.json"], maximum=65536)
        report = loads(self.files["formats/byte-backed/report.json"], maximum=65536)
        self.assertTrue(report["claims"]["syntheticGeneratedImageBytesRetained"])
        self.assertFalse(report["claims"]["originalCorpusMediaReceived"])
        image = self.files["media/synthetic-display.png"]
        self.assertEqual(self.files["input/byte-backed-photo.png"], image)
        self.assertEqual(image[:8], b"\x89PNG\r\n\x1a\n")
        length = struct.unpack(">I", image[8:12])[0]
        self.assertEqual(image[12:16], b"IHDR")
        self.assertEqual(struct.unpack(">II", image[16:24]), (1200, 800))
        self.assertEqual(image[24:29], b"\x08\x02\x00\x00\x00")
        self.assertEqual(length, 13)
        self.assertEqual(zlib.crc32(image[12:29]), struct.unpack(">I", image[29:33])[0])
        position, compressed, chunks = 8, bytearray(), []
        while position < len(image):
            size = struct.unpack(">I", image[position:position + 4])[0]
            kind = image[position + 4:position + 8]
            data = image[position + 8:position + 8 + size]
            crc = struct.unpack(">I", image[position + 8 + size:position + 12 + size])[0]
            self.assertEqual(zlib.crc32(kind + data), crc)
            chunks.append(kind)
            if kind == b"IDAT":
                compressed.extend(data)
            position += 12 + size
        self.assertEqual(chunks, [b"IHDR", b"IDAT", b"IEND"])
        self.assertEqual(position, len(image))
        pixels = zlib.decompress(compressed)
        self.assertEqual(len(pixels), (1 + 1200 * 3) * 800)
        self.assertEqual(pixels[:7], b"\x00\x29\x52\x63\x29\x52\x63")
        self.assertEqual(joined["retainedMedia"]["sha256"], "0x" + sha256(image).hexdigest())
        self.assertEqual(joined["retainedMedia"]["bytes"], str(len(image)))
        self.assertEqual(joined["identities"]["work"], source["workId"])
        self.assertEqual(joined["identities"]["visualContent"], source["contentId"])
        self.assertEqual(joined["identities"]["displayFile"], source["resources"][1]["id"])
        self.assertEqual(joined["identities"]["describedOnlyPrints"],
                         [row["id"] for row in source["resources"][2:]])
        mappings = {row["sourcePointer"]: row for row in joined["sourceFieldMappings"]}
        self.assertEqual(set(mappings["/resources/1/id"]["targets"]),
                         {"linked-art", "premis", "iiif", "lido"})
        self.assertEqual(mappings["/resources/1/dimensions/0/value"]["exactHex"],
                         "0x" + dumps("1200").hex())
        self.assertTrue(all(row["presence"] == "described_only" for row in source["resources"]))
        premis = etree.fromstring(self._four("premis/premis.xml"))
        self.assertEqual(premis.xpath(".//p:objectIdentifierValue/text()", namespaces={"p": PREMIS_NS}),
                         [source["resources"][1]["id"]])
        self.assertEqual(premis.xpath(".//p:messageDigest/text()", namespaces={"p": PREMIS_NS}),
                         [sha256(image).hexdigest()])
        self.assertEqual(premis.xpath(".//p:size/text()", namespaces={"p": PREMIS_NS}),
                         [str(len(image))])
        manifest = target_loads(self._four("iiif/manifest.json"))
        body = manifest["items"][0]["items"][0]["items"][0]["body"]
        self.assertEqual(body["id"], joined["retainedMedia"]["canonicalUri"])
        self.assertEqual((body["width"], body["height"], body["format"]),
                         (1200, 800, "image/png"))
        self.assertEqual(body["rights"], joined["retainedMedia"]["bodyRightsDeclaration"])
        self.assertEqual(manifest["rights"], joined["retainedMedia"]["manifestRightsDeclaration"])
        self.assertNotEqual(body["rights"], manifest["rights"])
        lido = etree.fromstring(self._four("lido/lido.xml"))
        self.assertEqual(lido.xpath(".//l:resourceID/text()", namespaces={"l": LIDO_NS}),
                         [source["resources"][1]["id"]])
        self.assertEqual(lido.xpath("l:objectPublishedID/text()", namespaces={"l": LIDO_NS}),
                         [source["workId"]])
        self.assertFalse(any(row["id"].encode() in self._four("premis/premis.xml")
                             for row in source["resources"][2:]))

    def test_detached_replay_and_prior_v4_golden(self):
        self.assertEqual(build(self.corpus, self.corpus_hash, version="4").manifest_hash,
                         "0x3b26e85c2b69531174980f5f7a3a4d3e571f811abdaafb607b2c56571bbfcef3")
        with patch("socket.socket", side_effect=AssertionError("network used")), \
             patch("zlib.compress", side_effect=AssertionError("compressor unavailable")):
            self.assertEqual(verify(self.output, self.package.manifest_hash), self.package)
            inner = self.output / "formats/byte-backed/package"
            self.assertEqual(verify_fixture_package(inner, self._inner_hash()).manifest_hash,
                             self._inner_hash())

    def _inner_hash(self):
        from .canonical import keccak256
        return keccak256(self._four("manifest.json"))

    def test_rehashed_media_join_and_export_tamper_rejected(self):
        from .corpus_photo_bytes_v1 import derive
        altered = self.root / "altered-photo.png"
        original = self.files["input/byte-backed-photo.png"]
        altered.write_bytes(original[:-1] + bytes([original[-1] ^ 1]))
        with self.assertRaisesRegex(MuseumError, "PNG input pin differs"):
            derive(self.corpus, self.corpus_hash, image_path=altered)
        changes = {
            "media/synthetic-display.png": lambda old: old[:-1] + bytes([old[-1] ^ 1]),
            "formats/byte-backed/correspondence.json": lambda old: dumps(
                loads(old) | {"inventedReceipt": True}),
            "formats/byte-backed/package/premis/premis.xml": lambda old: old.replace(
                b"fmt/13", b"fmt/14"),
        }
        for index, (path, edit) in enumerate(changes.items()):
            files = dict(self.files)
            files[path] = edit(files[path])
            self.assertNotEqual(files[path], self.files[path])
            metadata = loads(self.package.manifest, maximum=2 * 1024 * 1024)
            del metadata["files"]
            forged = _assemble(MODEL_ROOT, files, metadata)
            destination = self.root / ("forged-" + str(index))
            write_package(forged, destination)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                verify(destination, forged.manifest_hash)


if __name__ == "__main__":
    unittest.main()
