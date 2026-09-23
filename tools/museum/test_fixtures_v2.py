"""End-to-end synthetic eight-scenario export and offline replay evidence."""

from copy import deepcopy
from pathlib import Path
from shutil import copytree
import tempfile
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .corpus_v2 import build as build_corpus, verify as verify_corpus
from .coverage import inventory
from .fixtures import ROOT as V1_ROOT
from .fixtures_v2 import ROOT, SCENARIOS, documents
from .preview import fixture_package, verify_fixture_package, write_package


class MediaHistoryCorpus(unittest.TestCase):
    def test_builder_rejects_v1_wrong_schema_and_late_bad_row_before_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaisesRegex(MuseumError, "source schema ID differs"):
                build_corpus(root / "v1-output", V1_ROOT)
            self.assertFalse((root / "v1-output").exists())

            wrong_schema = root / "wrong-schema"
            copytree(ROOT, wrong_schema)
            schema_path = wrong_schema / "source.schema.json"
            schema = loads(schema_path.read_bytes())
            schema["$id"] = "urn:6529stream:fixture:other-source-v2"
            schema_path.write_bytes(dumps(schema))
            with self.assertRaisesRegex(MuseumError, "source schema ID differs"):
                build_corpus(root / "wrong-schema-output", wrong_schema)
            self.assertFalse((root / "wrong-schema-output").exists())

            late_bad_row = root / "late-bad-row"
            copytree(ROOT, late_bad_row)
            row_path = late_bad_row / "offline_revision.json"
            row = loads(row_path.read_bytes())
            row["scenario"] = "photograph"
            row_path.write_bytes(dumps(row))
            with self.assertRaisesRegex(MuseumError, "source scenario differs"):
                build_corpus(root / "late-bad-row-output", late_bad_row)
            self.assertFalse((root / "late-bad-row-output").exists())

            row["scenario"] = "offline_revision"
            del row["workId"]
            row_path.write_bytes(dumps(row))
            with self.assertRaisesRegex(MuseumError, "source does not satisfy its schema"):
                build_corpus(root / "invalid-row-output", late_bad_row)
            self.assertFalse((root / "invalid-row-output").exists())

    def test_pinned_corpus_replays_in_a_detached_directory_and_rejects_repinning(self):
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "corpus"
            pin = build_corpus(target)
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")), \
                    patch("tools.museum.fixtures_v2.documents", side_effect=AssertionError("fixture generator read")):
                manifest = verify_corpus(target, pin)
            self.assertEqual([row["scenario"] for row in manifest["cases"]], list(SCENARIOS))
            self.assertEqual(len({row["schemaHash"] for row in manifest["cases"]}), 1)
            self.assertEqual(len({row["sourceHash"] for row in manifest["cases"]}), len(SCENARIOS))
            self.assertFalse(any(manifest["claims"].values()))
            with self.assertRaisesRegex(MuseumError, "external manifest hash mismatch"):
                verify_corpus(target, "0x" + "00" * 32)
            (target / "unexpected.txt").write_text("extra", encoding="utf-8")
            with self.assertRaisesRegex(MuseumError, "file set differs"):
                verify_corpus(target, pin)

    def test_original_version_remains_unchanged_and_new_files_match_generator(self):
        from .fixtures import documents as old_documents
        for name, value in old_documents().items():
            self.assertEqual((V1_ROOT / name).read_bytes(), dumps(value))
        for name, value in documents().items():
            self.assertEqual((ROOT / name).read_bytes(), dumps(value))
        self.assertNotEqual(keccak256((V1_ROOT / "source.schema.json").read_bytes()),
                            keccak256((ROOT / "source.schema.json").read_bytes()))

    def test_eight_original_sources_replay_offline_with_complete_field_coverage(self):
        corpus = documents()
        schema = dumps(corpus["source.schema.json"])
        with tempfile.TemporaryDirectory() as temporary:
            for scenario in SCENARIOS:
                with self.subTest(scenario=scenario):
                    original = dumps(corpus[scenario + ".json"])
                    package = fixture_package(schema, original)
                    target = Path(temporary) / scenario
                    write_package(target, package)
                    manifest_hash = keccak256(package["manifest.json"])
                    with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                            patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")):
                        manifest = verify_fixture_package(target, manifest_hash)
                    self.assertEqual(manifest["scenario"], scenario)
                    self.assertEqual((target / "source/payload.json").read_bytes(), original)
                    self.assertEqual((target / "source/schema.json").read_bytes(), schema)
                    self.assertFalse(manifest["claims"]["recordedState"])
                    self.assertEqual(manifest["claims"]["museumConformance"], "not_evaluated")
                    coverage = loads((target / "reports/coverage.json").read_bytes(), maximum=65536)
                    self.assertEqual({row["pointer"] for row in coverage},
                                     {row.pointer for row in inventory(corpus["source.schema.json"],
                                                                       corpus[scenario + ".json"])})
                    self.assertTrue(all(row["disposition"] == "retained_stream_only" for row in coverage))
                    with self.assertRaisesRegex(MuseumError, "external hash mismatch"):
                        verify_fixture_package(target, "0x" + "00" * 32)

    def test_distinct_media_events_roles_and_attested_absence(self):
        cases = documents()
        photo = cases["photograph.json"]
        self.assertEqual(len({r["id"] for r in photo["resources"]}), 4)
        self.assertEqual([r["kind"] for r in photo["resources"]],
                         ["digital_object", "digital_object", "physical_object", "physical_object"])
        self.assertEqual({r["scope"] for p in photo["resources"][2:] for r in p["dimensions"]},
                         {"image_width", "image_height", "sheet_width", "sheet_height"})
        self.assertEqual({event["kind"] for event in photo["events"]},
                         {"capture", "completion", "printing"})
        self.assertEqual({link["object"] for link in photo["relationships"]
                          if link["relation"] in ("digitally_shows", "physically_shows")},
                         {photo["contentId"]})

        written, av = cases["written_interview.json"], cases["av_interview.json"]
        self.assertEqual({r["role"] for r in written["resources"]}, {"instrument", "transcript"})
        self.assertIsNone(written["duration"])
        self.assertFalse(written["mediaSegments"])
        self.assertNotIn("recording", {r["role"] for r in written["resources"]})
        self.assertEqual({r["role"] for r in av["resources"]},
                         {"instrument", "recording", "transcript", "captions"})
        self.assertEqual(av["duration"], "PT00H02M30S")
        self.assertEqual({r["role"] for r in av["participantRoles"]}, {"interviewee", "interviewer"})
        self.assertEqual(av["mediaSegments"][0]["speaker"], "urn:fixture:artist")
        self.assertNotEqual(av["mediaSegments"][0]["start"], av["mediaSegments"][0]["end"])

        software = cases["software_interactive.json"]
        self.assertEqual({r["role"] for r in software["resources"]},
                         {"code", "dependency", "environment", "reference_output", "preservation_evidence"})
        self.assertEqual(software["events"][0]["kind"], "execution")
        self.assertEqual({r["property"] for r in software["significantProperties"]},
                         {"interaction", "runtime"})
        self.assertTrue(all(r["presence"] == "described_only" for r in software["resources"]))

    def test_historical_alternatives_conflict_and_independent_attribution(self):
        cases = documents()
        geo = cases["disputed_geography.json"]
        self.assertEqual(geo["places"][0]["alignment"], None)
        self.assertEqual([r["status"] for r in geo["authorityHistory"]], ["proposed", "rejected"])
        self.assertTrue(all("synthetic" in r["authority"] for r in geo["authorityHistory"]))
        self.assertEqual(geo["revisions"][1]["prior"], geo["revisions"][0]["id"])
        self.assertEqual(len({r["author"] for r in geo["claims"]}), 2)
        for name in ("incomplete_documentation", "independent_accounts"):
            case = cases[name + ".json"]
            self.assertEqual({r["value"] for r in case["claims"]}, {"Studio", "Storage"})
            self.assertEqual(len({r["author"] for r in case["claims"]}), 2)
            self.assertEqual({r["status"] for r in case["claims"]}, {"asserted", "disputed"})
        self.assertEqual(cases["incomplete_documentation.json"]["resources"][0]["presence"],
                         "described_only")
        for name in SCENARIOS:
            case = cases[name + ".json"]
            known = {case["workId"], case["contentId"],
                     *(row["id"] for row in case["resources"]),
                     *(row["id"] for row in case["places"])}
            for relation in case["relationships"]:
                self.assertIn(relation["subject"], known)
                self.assertIn(relation["object"], known)
            for claim in case["claims"]:
                self.assertIn(claim["subject"], known)

    def test_old_archive_survives_later_schema_revision_without_live_sources(self):
        corpus = documents()
        original_schema = dumps(corpus["source.schema.json"])
        original = dumps(corpus["offline_revision.json"])
        self.assertEqual(corpus["offline_revision.json"]["revisions"][1]["prior"],
                         corpus["offline_revision.json"]["revisions"][0]["id"])
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary) / "archived"
            package = fixture_package(original_schema, original)
            write_package(target, package)
            old_hash = keccak256(package["manifest.json"])
            newer = deepcopy(corpus["source.schema.json"])
            newer["$id"] = "urn:6529stream:fixture:museum-source-v3"
            newer["properties"]["newRequiredField"] = {"type": "string"}
            newer["required"].append("newRequiredField")
            self.assertNotEqual(keccak256(dumps(newer)), keccak256(original_schema))
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("urllib.request.urlopen", side_effect=AssertionError("network forbidden")), \
                    patch("tools.museum.fixtures_v2.documents", side_effect=AssertionError("live fixture read")):
                self.assertEqual(verify_fixture_package(target, old_hash)["scenario"], "offline_revision")
            self.assertEqual((target / "source/schema.json").read_bytes(), original_schema)
            self.assertEqual((target / "source/payload.json").read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
