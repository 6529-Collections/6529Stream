"""Four-format field evidence stays attached to exact synthetic originals."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .corpus_semantic_v1 import MODEL_ROOT, build, verify
from .corpus_v2 import build as build_corpus
from .fixtures_v2 import SCENARIOS
from .lido_model import PinnedLIDO, PROFILE_BYTES, PROFILE_HASH
from .package import write_package
from .package_v2 import _assemble


class CorpusFourFormatCorrespondence(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.corpus = cls.root / "corpus"
        cls.corpus_hash = build_corpus(cls.corpus)
        cls.package = build(cls.corpus, cls.corpus_hash, version="4")
        cls.files = dict(cls.package.files)
        cls.output = cls.root / "output"
        write_package(cls.package, cls.output)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_all_eight_denominators_and_honest_support(self):
        ledger = loads(self.files["formats/field-correspondence.json"], maximum=2 * 1024 * 1024, canonical=True)
        self.assertEqual([row["scenario"] for row in ledger["scenarios"]], list(SCENARIOS))
        self.assertFalse(ledger["claims"]["fullFourFormatParity"])
        model = PinnedLIDO(MODEL_ROOT, PROFILE_BYTES, profile_hash=PROFILE_HASH)
        for row in ledger["scenarios"]:
            name = row["scenario"]
            coverage = loads(self.files["semantic/" + name + "/coverage.json"],
                             maximum=65536, canonical=True)
            source = loads(self.files[row["sourcePath"]], canonical=True)
            self.assertEqual([(field["sourcePointer"], field["exactHex"]) for field in row["fields"]],
                             [(field["pointer"], field["exactHex"]) for field in coverage])
            self.assertEqual(row["sourceHash"], keccak256(dumps(source)))
            self.assertEqual(row["identities"]["work"], source["workId"])
            self.assertTrue(all(field["formats"]["premis"]["disposition"] == "retained_stream_only"
                                and field["formats"]["iiif"]["disposition"] == "retained_stream_only"
                                for field in row["fields"]))
            self.assertNotIn("formats/" + name + "/premis.xml", self.files)
            self.assertNotIn("formats/" + name + "/manifest.json", self.files)
            if name in ("photograph", "software_interactive"):
                raw = self.files["formats/" + name + "/lido.xml"]
                model.validate(raw)
                self.assertEqual(row["support"]["lido"], "projected")
                self.assertEqual(row["identities"]["lido"]["workId"], source["workId"])
                by_pointer = {field["sourcePointer"]: field for field in row["fields"]}
                for pointer in ("/workId", "/title", "/creatorStatement", "/language", "/scenario"):
                    self.assertEqual(by_pointer[pointer]["formats"]["lido"]["disposition"], "mapped")
                self.assertEqual(by_pointer["/resources/0/presence"]["formats"]["lido"]["disposition"],
                                 "retained_stream_only")
            else:
                self.assertIsNone(row["identities"]["lido"])

    def test_photograph_and_interactive_identities_stay_distinct(self):
        ledger = loads(self.files["formats/field-correspondence.json"], maximum=2 * 1024 * 1024, canonical=True)
        cases = {row["scenario"]: row for row in ledger["scenarios"]}
        photo = loads(self.files[cases["photograph"]["sourcePath"]])
        software = loads(self.files[cases["software_interactive"]["sourcePath"]])
        self.assertEqual(set(cases["photograph"]["identities"]["linkedArtEntities"]),
                         {photo["contentId"]} | {row["id"] for row in photo["resources"]})
        self.assertEqual(set(cases["software_interactive"]["identities"]["linkedArtEntities"]),
                         {row["id"] for row in software["resources"]} |
                         {software["events"][0]["id"], "urn:fixture:artist"})
        for name in ("photograph", "software_interactive"):
            identity = cases[name]["identities"]
            self.assertNotIn(identity["lido"]["recordId"], identity["linkedArtEntities"])
            self.assertNotIn(identity["work"], identity["linkedArtEntities"])
        photo_comparisons = {row["sourcePointer"]: row for row in cases["photograph"]["comparisons"]}
        self.assertEqual(photo_comparisons["/title"]["status"], "exact_lexical")
        self.assertEqual(photo_comparisons["/title"]["formats"], ["lido", "linked-art"])
        self.assertEqual(photo_comparisons["/scenario"]["status"],
                         "different_target_representations")

    def test_offline_round_trip_and_rehashed_target_or_ledger_tamper(self):
        self.assertEqual(build(self.corpus, self.corpus_hash, version="3").manifest_hash,
                         "0xb79a27fe4c2d70bd8b7016a22e531295974cb4e3a8b0b23316ed6d49918ec28b")
        with patch("socket.socket", side_effect=AssertionError("network used")):
            self.assertEqual(verify(self.output, self.package.manifest_hash), self.package)
        for path in ("formats/photograph/lido.xml", "formats/field-correspondence.json"):
            files = dict(self.files)
            if path.endswith(".xml"):
                files[path] = files[path].replace(b"Synthetic photograph", b"Forged photograph")
            else:
                value = loads(files[path], maximum=2 * 1024 * 1024)
                value["scenarios"][0]["identities"]["work"] = "urn:fixture:wrong-work"
                files[path] = dumps(value)
            metadata = loads(self.package.manifest, maximum=2 * 1024 * 1024)
            del metadata["files"]
            forged = _assemble(MODEL_ROOT, files, metadata)
            destination = self.root / ("forged-xml" if path.endswith(".xml") else "forged-ledger")
            write_package(forged, destination)
            with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                verify(destination, forged.manifest_hash)


if __name__ == "__main__":
    unittest.main()
