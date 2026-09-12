"""Original LIDO schema, complete offline import closure and XML boundaries."""

from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, loads
from .lido_model import PinnedLIDO, PROFILE_BYTES, PROFILE_HASH, schema_references, SCHEMA_URI
from .lido_pins import SCHEMA_REFERENCES

ROOT = Path(__file__).resolve().parents[2] / "schemas/museum"
MINIMUM = b'''<lido:lido xmlns:lido="http://www.lido-schema.org"><lido:lidoRecID lido:type="URI">urn:fixture:lido-record</lido:lidoRecID><lido:objectPublishedID lido:type="URI">urn:fixture:work</lido:objectPublishedID><lido:descriptiveMetadata xml:lang="und"><lido:objectClassificationWrap><lido:objectWorkTypeWrap><lido:objectWorkType><lido:term>digital artwork</lido:term></lido:objectWorkType></lido:objectWorkTypeWrap></lido:objectClassificationWrap><lido:objectIdentificationWrap><lido:titleWrap><lido:titleSet><lido:appellationValue>Exact &amp; title&#13;\nnext</lido:appellationValue></lido:titleSet></lido:titleWrap></lido:objectIdentificationWrap></lido:descriptiveMetadata><lido:administrativeMetadata xml:lang="und"><lido:recordWrap><lido:recordID lido:type="URI">urn:fixture:source-record</lido:recordID><lido:recordType><lido:term>item</lido:term></lido:recordType><lido:recordSource><lido:legalBodyID lido:type="URI">urn:fixture:provider</lido:legalBodyID><lido:legalBodyName><lido:appellationValue>Fixture provider</lido:appellationValue></lido:legalBodyName></lido:recordSource></lido:recordWrap></lido:administrativeMetadata></lido:lido>'''


class LIDOOriginalSchema(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.model = PinnedLIDO(ROOT, PROFILE_BYTES, profile_hash=PROFILE_HASH)

    def test_literal_original_schema_minimum_and_empty_language_failure(self):
        with patch("socket.socket", side_effect=AssertionError("offline only")):
            tree = self.model.validate(MINIMUM)
        self.assertEqual(tree.findtext(".//{http://www.lido-schema.org}appellationValue"), "Exact & title\r\nnext")
        self.assertEqual(tree.findtext("{http://www.lido-schema.org}objectPublishedID"), "urn:fixture:work")
        self.assertEqual(len(self.model.schema_warnings), 2)
        self.assertTrue(all("2001/xml.xsd" in text and "2001/03/xml.xsd" in text for text in self.model.schema_warnings))
        with self.assertRaisesRegex(MuseumError, "XSD validation"):
            self.model.validate(MINIMUM.replace(b'xml:lang="und"', b'xml:lang=""'))

    def test_required_record_provider_and_title_are_not_optional(self):
        for first, last in ((b"<lido:recordSource>", b"</lido:recordSource>"),
                            (b"<lido:titleWrap>", b"</lido:titleWrap>")):
            start, end = MINIMUM.index(first), MINIMUM.index(last) + len(last)
            with self.assertRaisesRegex(MuseumError, "XSD validation"):
                self.model.validate(MINIMUM[:start] + MINIMUM[end:])

    def test_untrusted_xml_dtd_entities_comments_namespace_and_byte_bounds(self):
        for raw in (b'<!DOCTYPE x SYSTEM "https://example.org/foreign.dtd">' + MINIMUM,
                    MINIMUM.replace(b"Exact &amp;", b"<!-- hidden -->Exact &amp;"),
                    MINIMUM.replace(b"http://www.lido-schema.org", b"http://example.org/foreign"),
                    b"<?before hidden?>" + MINIMUM, MINIMUM + b" " * (4 * 1024 * 1024)):
            with self.subTest(size=len(raw)), self.assertRaises(MuseumError):
                self.model.validate(raw)

    def test_complete_closure_checks_even_the_schema_skipped_by_namespace_resolution(self):
        index = loads((ROOT / "lido/dependency-index.json").read_bytes(), maximum=524288)
        row = next(v for v in index["documents"] if v["sourceUri"] == "http://www.w3.org/2001/xml.xsd")
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            shutil.copytree(ROOT / "lido", root / "lido")
            path = root / row["chunks"][0]["path"]
            raw = path.read_bytes()
            path.write_bytes(raw[:-1] + bytes([raw[-1] ^ 1]))
            with self.assertRaisesRegex(MuseumError, "chunk hash"):
                PinnedLIDO(root, PROFILE_BYTES, profile_hash=PROFILE_HASH)
        self.assertEqual(len(SCHEMA_REFERENCES), 35)

    def test_reference_order_and_absolute_identity_are_read_from_exact_original(self):
        from lxml import etree
        raw = self.model.documents.load(SCHEMA_URI)
        tree = etree.fromstring(raw)
        self.assertEqual(schema_references(SCHEMA_URI, tree), SCHEMA_REFERENCES[SCHEMA_URI])
        imports = tree.findall("{http://www.w3.org/2001/XMLSchema}import")
        imports[0].set("schemaLocation", "https://example.org/foreign.xsd")
        self.assertNotEqual(schema_references(SCHEMA_URI, tree), SCHEMA_REFERENCES[SCHEMA_URI])
        with self.assertRaisesRegex(MuseumError, "profile mismatch"):
            PinnedLIDO(ROOT, PROFILE_BYTES + b" ", profile_hash=PROFILE_HASH)


if __name__ == "__main__":
    unittest.main()
