"""Exact source mapping and detached replay of the first corpus semantic slice."""

import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, keccak256, loads
from .corpus_semantic_v1 import CASES, LEGACY_CASES, V2_CASES, MODEL_ROOT, _extension, _project, build, verify
from .corpus_v2 import build as build_corpus
from .package import write_package
from .package_v2 import _assemble
from .projection import CRM, DIG, LA


class SyntheticCorpusSemanticProjection(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.corpus = cls.root / "corpus"
        cls.corpus_hash = build_corpus(cls.corpus)
        cls.result = build(cls.corpus, cls.corpus_hash, version="3")
        cls.files = dict(cls.result.files)
        cls.export = cls.root / "semantic"
        write_package(cls.result, cls.export)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def _resources(self, scenario):
        index = loads(self.files["semantic/entity-index.json"], maximum=65536)
        return {row["id"]: loads(self.files[row["path"]]) for row in index
                if row["scenario"] == scenario}

    def _expanded(self, scenario):
        index = loads(self.files["semantic/entity-index.json"], maximum=65536)
        return {row["id"]: loads(self.files[row["expandedPath"]])[0] for row in index
                if row["scenario"] == scenario}

    def test_photo_has_one_visual_content_and_four_distinct_carriers(self):
        photo = loads(self.files["input/corpus/photograph/source/payload.json"])
        resources = self._resources("photograph")
        expanded = self._expanded("photograph")
        self.assertEqual(len(resources), 5)
        self.assertEqual(resources[photo["contentId"]]["type"], "VisualItem")
        for row in photo["resources"]:
            self.assertIn(row["id"], resources)
            predicate = LA + "digitally_shows" if row["kind"] == "digital_object" else CRM + "P65_shows_visual_item"
            self.assertEqual(expanded[row["id"]][predicate][0]["@id"], photo["contentId"])
            self.assertEqual(expanded[row["id"]]["@type"],
                             [DIG + "D1_Digital_Object"] if row["kind"] == "digital_object"
                             else [CRM + "E22_Human-Made_Object"])
        self.assertNotIn(photo["workId"], resources)
        self.assertNotIn(b"produced_by", b"".join(raw for path, raw in self.files.items()
                                                 if path.startswith("semantic/photograph/resources/")))
        coverage = {row["pointer"]: row for row in loads(self.files["semantic/photograph/coverage.json"], maximum=65536)}
        self.assertEqual(coverage["/relationships/1/object"]["disposition"], "mapped")
        self.assertEqual(coverage["/relationships/2/relation"]["disposition"], "retained_stream_only")
        self.assertEqual(coverage["/resources/2/dimensions/2/value"]["disposition"], "retained_stream_only")
        self.assertEqual(coverage["/resources/2/dimensions/2/value"]["exactHex"], "0x" + dumps("50.00").hex())
        self.assertEqual(coverage["/events/2/precision"]["disposition"], "retained_stream_only")
        provenance = loads(self.files["semantic/photograph/provenance.json"], maximum=65536)
        self.assertTrue(any(row["sourcePointer"] == "/relationships/1/object"
                            and row["targetPointer"] == "/digitally_shows/0/id"
                            and row["sourceHash"] == keccak256(dumps(photo)) for row in provenance))

    def test_interviews_map_distinct_carriers_and_activity_without_invented_content(self):
        for name in ("written_interview", "av_interview"):
            with self.subTest(name=name):
                source = loads(self.files["input/corpus/" + name + "/source/payload.json"])
                resources = self._resources(name)
                expanded = self._expanded(name)
                self.assertEqual({row["id"] for row in source["resources"]},
                                 {identifier for identifier, value in resources.items()
                                  if value["type"] == "DigitalObject"})
                event = source["events"][0]
                self.assertEqual(resources[event["id"]]["type"], "Activity")
                self.assertEqual({row["@id"] for row in expanded[event["id"]][CRM + "P14_carried_out_by"]},
                                 {row["participant"] for row in source["participantRoles"]})
                self.assertNotIn(source["contentId"], resources)
                self.assertNotIn(source["workId"], resources)
                self.assertFalse(any(value["type"] in ("LinguisticObject", "VisualItem")
                                     for value in resources.values()))
                coverage = {row["pointer"]: row for row in loads(
                    self.files["semantic/" + name + "/coverage.json"], maximum=65536)}
                self.assertEqual(coverage["/participantRoles/0/participant"]["disposition"], "mapped")
                self.assertEqual(coverage["/participantRoles/0/role"]["disposition"], "retained_stream_only")
                self.assertEqual(coverage["/events/0/dateExpression"]["disposition"], "retained_stream_only")
                self.assertEqual(coverage["/duration"]["disposition"], "retained_stream_only")
                self.assertEqual(coverage["/duration"]["exactHex"], "0x" + dumps(source["duration"]).hex())
        written = loads(self.files["input/corpus/written_interview/source/payload.json"])
        self.assertNotIn("recording", {row["role"] for row in written["resources"]})
        changed = loads(self.files["input/corpus/written_interview/source/payload.json"])
        changed["participantRoles"][0]["participant"] = "urn:fixture:unclassified-party"
        schema = loads(self.files["input/corpus/written_interview/source/schema.json"])
        with self.assertRaisesRegex(MuseumError, "participant kinds unestablished"):
            _project("written_interview", changed, schema, object())

    def test_interactive_work_maps_carriers_and_execution_without_inventing_software_content(self):
        source = loads(self.files["input/corpus/software_interactive/source/payload.json"])
        resources = self._resources("software_interactive")
        expanded = self._expanded("software_interactive")
        self.assertEqual({row["id"] for row in source["resources"]},
                         {identifier for identifier, value in resources.items()
                          if value["type"] == "DigitalObject"})
        self.assertEqual(resources[source["events"][0]["id"]]["type"], "Activity")
        self.assertEqual(expanded[source["events"][0]["id"]][CRM + "P14_carried_out_by"][0]["@id"],
                         "urn:fixture:artist")
        self.assertNotIn(source["contentId"], resources)
        self.assertFalse(any(value["type"] == "LinguisticObject" for value in resources.values()))
        coverage = {row["pointer"]: row for row in loads(
            self.files["semantic/software_interactive/coverage.json"], maximum=65536)}
        self.assertEqual(coverage["/relationships/0/relation"]["disposition"], "retained_stream_only")
        self.assertEqual(coverage["/significantProperties/0/value"]["disposition"], "retained_stream_only")
        self.assertEqual(coverage["/resources/0/presence"]["exactHex"],
                         "0x" + dumps("described_only").hex())
        provenance = loads(self.files["semantic/software_interactive/provenance.json"], maximum=65536)
        self.assertTrue(any(row["entity"] == source["events"][0]["id"]
                            and row["sourcePointer"] == "/events/0/kind"
                            and row["rule"] == "fixture-v2:completed-execution" for row in provenance))

    def test_historical_place_maps_only_local_identity_and_keeps_competing_claims(self):
        source = loads(self.files["input/corpus/disputed_geography/source/payload.json"])
        resources = self._resources("disputed_geography")
        place = source["places"][0]
        self.assertEqual(set(resources), {place["id"]})
        self.assertEqual(resources[place["id"]]["type"], "Place")
        self.assertEqual(resources[place["id"]]["_label"], place["statement"])
        self.assertNotIn("equivalent", resources[place["id"]])
        self.assertNotIn("took_place_at", resources[place["id"]])
        self.assertEqual(self._expanded("disputed_geography")[place["id"]]["@type"],
                         [CRM + "E53_Place"])
        coverage = {row["pointer"]: row for row in loads(
            self.files["semantic/disputed_geography/coverage.json"], maximum=65536)}
        self.assertEqual(coverage["/places/0/statement"]["disposition"], "mapped")
        self.assertEqual(coverage["/places/0/alignment"]["exactHex"], "0x" + b"null".hex())
        self.assertEqual(coverage["/authorityHistory/0/match"]["disposition"], "retained_stream_only")
        self.assertEqual(coverage["/claims/1/value"]["disposition"], "retained_stream_only")
        self.assertEqual(len({row["author"] for row in source["claims"]}), 2)

    def test_conflict_ledgers_keep_both_authors_without_custody_selection(self):
        for name, expected_resources in (("incomplete_documentation", 2), ("independent_accounts", 1)):
            with self.subTest(name=name):
                source = loads(self.files["input/corpus/" + name + "/source/payload.json"])
                resources = self._resources(name)
                self.assertEqual(len(resources), expected_resources)
                self.assertEqual({row["id"] for row in source["resources"]}, set(resources))
                self.assertTrue(all("current_location" not in value and "member_of" not in value
                                    for value in resources.values()))
                path = "semantic/" + name + "/conflict-ledger.json"
                ledger = loads(self.files[path])
                self.assertEqual(ledger["mode"], "synthetic_unresolved_claims")
                self.assertEqual(ledger["resolution"], "unresolved")
                self.assertIsNone(ledger["selectedClaim"])
                self.assertEqual([row["claim"] for row in ledger["claims"]], source["claims"])
                self.assertEqual(len({row["claim"]["author"] for row in ledger["claims"]}), 2)
                coverage = {row["pointer"]: row for row in loads(
                    self.files["semantic/" + name + "/coverage.json"], maximum=65536)}
                self.assertEqual(coverage["/claims/0/value"]["disposition"], "mapped")
                self.assertEqual(coverage["/claims/1/author"]["disposition"], "mapped")
                if name == "incomplete_documentation":
                    self.assertEqual(source["resources"][0]["presence"], "described_only")
                    self.assertEqual(coverage["/resources/0/presence"]["disposition"], "retained_stream_only")

    def test_offline_revision_extension_cites_prior_without_replacing_original(self):
        source = loads(self.files["input/corpus/offline_revision/source/payload.json"])
        self.assertFalse(self._resources("offline_revision"))
        path = "semantic/offline_revision/revision-lineage.json"
        lineage = loads(self.files[path])
        self.assertEqual(lineage["mode"], "synthetic_revision_lineage")
        self.assertEqual([row["revision"] for row in lineage["revisions"]], source["revisions"])
        self.assertEqual(lineage["revisions"][1]["revision"]["prior"],
                         lineage["revisions"][0]["revision"]["id"])
        coverage = {row["pointer"]: row for row in loads(
            self.files["semantic/offline_revision/coverage.json"], maximum=65536)}
        self.assertEqual(coverage["/revisions/0/statement"]["disposition"], "mapped")
        self.assertEqual(coverage["/revisions/1/prior"]["disposition"], "mapped")
        self.assertEqual(coverage["/optionalNote"]["exactHex"], "0x" + b"null".hex())

        def at(value, pointer):
            for part in pointer.lstrip("/").split("/"):
                value = value[int(part)] if isinstance(value, list) else value[part]
            return value

        for name in ("incomplete_documentation", "independent_accounts", "offline_revision"):
            source = loads(self.files["input/corpus/" + name + "/source/payload.json"])
            provenance = loads(self.files["semantic/" + name + "/provenance.json"], maximum=65536)
            extension_rows = [row for row in provenance if "targetPath" in row]
            self.assertTrue(extension_rows)
            for row in extension_rows:
                self.assertEqual(row["sourceHash"], keccak256(dumps(source)))
                self.assertEqual(at(source, row["sourcePointer"]),
                                 at(loads(self.files[row["targetPath"]]), row["targetPointer"]))

        altered = loads(self.files["input/corpus/offline_revision/source/payload.json"])
        altered["revisions"][1]["prior"] = "urn:fixture:unrelated-revision"
        with self.assertRaisesRegex(MuseumError, "revision lineage differs"):
            _extension("offline_revision", altered, {}, b"", b"")
        altered = loads(self.files["input/corpus/independent_accounts/source/payload.json"])
        altered["claims"][1]["author"] = altered["claims"][0]["author"]
        with self.assertRaisesRegex(MuseumError, "conflict attribution differs"):
            _extension("independent_accounts", altered, {}, b"", b"")

    def test_profile_source_pins_and_all_eight_original_packages_survive(self):
        report = loads(self.files["semantic/report.json"])
        self.assertEqual(report["corpusManifestHash"], self.corpus_hash)
        self.assertEqual(report["sourceSchemaId"], "urn:6529stream:fixture:museum-source-v2")
        self.assertEqual(report["crosswalkVersion"], "2")
        self.assertEqual(report["scenarios"], list(CASES))
        self.assertEqual(report["completeness"], "incomplete")
        self.assertFalse(any(report["claims"].values()))
        self.assertFalse(any(loads(self.result.manifest, maximum=2 * 1024 * 1024)["claims"].values()))
        self.assertEqual(loads(self.result.manifest, maximum=2 * 1024 * 1024)["version"], "3")
        self.assertEqual(self.files["definitions/crosswalk-v2.json"],
                         (MODEL_ROOT / "projection/crosswalk-v2.json").read_bytes())
        for path in self.corpus.rglob("*"):
            if path.is_file():
                relative = path.relative_to(self.corpus).as_posix()
                self.assertEqual(self.files["input/corpus/" + relative], path.read_bytes())

    def test_v1_three_case_archive_still_rebuilds_after_v2_expansion(self):
        legacy = build(self.corpus, self.corpus_hash)
        self.assertEqual(legacy.manifest_hash,
                         "0x621677b8f979b55f425909e32bb12c78ba7e791667c4ede9caa3430a0f95a291")
        files = dict(legacy.files)
        report = loads(files["semantic/report.json"])
        self.assertEqual(report["scenarios"], list(LEGACY_CASES))
        self.assertEqual(loads(legacy.manifest, maximum=2 * 1024 * 1024)["version"], "1")
        self.assertNotIn("semantic/software_interactive/coverage.json", files)
        self.assertNotIn("semantic/disputed_geography/coverage.json", files)
        target = self.root / "legacy"
        write_package(legacy, target)
        with patch("socket.socket", side_effect=AssertionError("network used")):
            self.assertEqual(verify(target, legacy.manifest_hash), legacy)

    def test_v2_five_case_archive_still_rebuilds_after_v3_expansion(self):
        prior = build(self.corpus, self.corpus_hash, version="2")
        self.assertEqual(prior.manifest_hash,
                         "0x63b7b1384aef4cf2aa7f4e8899bbc1a09aed0ae989b37e507163a132e27ceb87")
        files = dict(prior.files)
        self.assertEqual(loads(files["semantic/report.json"])["scenarios"], list(V2_CASES))
        self.assertNotIn("semantic/offline_revision/revision-lineage.json", files)
        target = self.root / "prior-v2"
        write_package(prior, target)
        with patch("socket.socket", side_effect=AssertionError("network used")):
            self.assertEqual(verify(target, prior.manifest_hash), prior)

    def test_mislabeled_draft_v2_rejected_even_with_rehashed_manifest(self):
        corrected = build(self.corpus, self.corpus_hash, version="2")
        files = dict(corrected.files)
        path = "semantic/software_interactive/provenance.json"
        provenance = loads(files[path], maximum=65536)
        changed = 0
        for row in provenance:
            if row["rule"] == "fixture-v2:completed-execution":
                row["rule"] = "fixture-v2:completed-interview"
                changed += 1
        self.assertEqual(changed, 3)
        files[path] = dumps(sorted(provenance, key=dumps))
        metadata = loads(corrected.manifest, maximum=2 * 1024 * 1024)
        del metadata["files"]
        mislabeled = _assemble(MODEL_ROOT, files, metadata)
        target = self.root / "mislabeled-draft-v2"
        write_package(mislabeled, target)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify(target, mislabeled.manifest_hash)

    def test_detached_replay_uses_retained_dependencies_and_catches_rehashed_forgery(self):
        real_open = io.open
        forbidden = (MODEL_ROOT.resolve(),)

        def guarded(file, *args, **kwargs):
            if isinstance(file, (str, bytes, Path)):
                path = Path(file).resolve()
                if any(path.is_relative_to(root) for root in forbidden):
                    raise AssertionError("repository model fallback")
            return real_open(file, *args, **kwargs)

        with patch("socket.socket", side_effect=AssertionError("network used")), patch("io.open", guarded):
            self.assertEqual(verify(self.export, self.result.manifest_hash), self.result)

        files = dict(self.files)
        path = next(name for name in files if name.startswith("semantic/photograph/resources/"))
        changed = loads(files[path]); changed["_label"] = "forged label"
        files[path] = dumps(changed)
        metadata = loads(self.result.manifest, maximum=2 * 1024 * 1024)
        del metadata["files"]
        forged = _assemble(MODEL_ROOT, files, metadata)
        target = self.root / "forged"
        write_package(forged, target)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify(target, forged.manifest_hash)

        files = dict(self.files)
        policy_path = "dependencies/linked-art-v2/validation-policy.json"
        policy = loads(files[policy_path]); policy["unreviewedChange"] = True
        files[policy_path] = dumps(policy)
        altered = _assemble(MODEL_ROOT, files, metadata)
        target = self.root / "changed-policy"
        write_package(altered, target)
        with self.assertRaisesRegex(MuseumError, "model policy hash differs"):
            verify(target, altered.manifest_hash)

        files = dict(self.files)
        crosswalk_path = "definitions/crosswalk-v2.json"
        crosswalk = loads(files[crosswalk_path]); crosswalk["unreviewedChange"] = True
        files[crosswalk_path] = dumps(crosswalk)
        altered = _assemble(MODEL_ROOT, files, metadata)
        target = self.root / "changed-crosswalk"
        write_package(altered, target)
        with self.assertRaisesRegex(MuseumError, "crosswalk hash differs"):
            verify(target, altered.manifest_hash)

        files = dict(self.files)
        conflict_path = "semantic/independent_accounts/conflict-ledger.json"
        conflict = loads(files[conflict_path]); conflict["selectedClaim"] = conflict["claims"][0]["claim"]["id"]
        files[conflict_path] = dumps(conflict)
        altered = _assemble(MODEL_ROOT, files, metadata)
        target = self.root / "forged-conflict-selection"
        write_package(altered, target)
        with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
            verify(target, altered.manifest_hash)


if __name__ == "__main__":
    unittest.main()
