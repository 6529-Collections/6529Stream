"""Synthetic original-native attribution package controls; no chain acceptance."""
import copy
import io
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from . import attribution_dossier as dossier
from .account_profile import AccountProjectionProfile, NAME as OLD_NAME, POLICY_NAME, PROFILE_SCHEMA_BYTES
from .canonical import MuseumError, dumps, keccak256, loads as read_json
from .native_attribution_profile import NativeAttributionProfile, NAME, POLICY, CROSSWALK
from .native_attribution_semantics import NativeAttributionSemanticSource
from .review import _validate
from .test_artist_attestation_source import Fixture, Transport


def loads(raw):
    return read_json(raw, maximum=dossier.MAX_BYTES)


def rehash(files):
    value = loads(files["manifest.json"])
    value["files"] = [{"path": path, "bytes": str(len(raw)), "hash": keccak256(raw)}
        for path, raw in sorted(files.items()) if path != "manifest.json"]
    files["manifest.json"] = dumps(value)
    return keccak256(files["manifest.json"])


class AttributionDossierTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = Fixture(rotated=True, disputed=True, relayed=True)
        cls.artist = cls.fixture.overlay()
        cls.semantic = NativeAttributionSemanticSource(cls.artist, Transport(cls.fixture.responses))
        cls.files = dossier.build_files(cls.artist, semantic=cls.semantic)

    def test_original_bytes_profiles_and_all_field_coverage(self):
        files = self.files
        self.assertEqual(files["artist/snapshot.json"], self.artist.snapshot())
        self.assertEqual(files["artist/transcript.json"], self.artist.transcript())
        self.assertEqual(files["sources/metadata/snapshot.json"], self.artist.metadata_catalog.snapshot())
        value = loads(files["dossier.json"])
        original = value["nativeArtistEvidence"]["attestations"][0]
        index = loads(files["graph/index.json"])["resources"]
        self.assertEqual(len(index), 1)
        resource = loads(files[index[0]["path"]])
        self.assertEqual(resource["type"], "LinguisticObject")
        self.assertEqual(resource["content"].encode(), bytes.fromhex(original["metadataOriginal"]["payloadHex"][2:]))
        coverage = loads(files["graph/source-coverage.json"])
        self.assertEqual({row["sourcePath"]: row["value"] for row in coverage if row["source"] == index[0]["source"]},
            dict(dossier.leaves(original)))
        provenance = loads(files["graph/provenance.json"])
        self.assertEqual({row["path"]: row["value"] for row in provenance if row["entity"] == resource["id"]},
            dict(dossier.leaves(resource)))
        self.assertEqual(value["generalAttestationEvidence"], {"status": "not_captured", "original": None})
        self.assertEqual(index[0]["semanticInterpretation"], "unsupported")

    def test_closed_offline_replay_and_historical_current_separation(self):
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(self.files, keccak256(self.files["manifest.json"]))
        self.assertEqual(report["provenance"], "synthetic_fixture")
        self.assertEqual(report["attestationCount"], "1")
        self.assertFalse(report["claims"]["actualChainAcceptance"])
        self.assertFalse(report["claims"]["independentHumanReviewProven"])
        value = loads(self.files["dossier.json"])
        row = value["nativeArtistEvidence"]["attestations"][0]
        self.assertNotEqual(row["historicalAuthority"]["signer"], row["current"]["identity"][0])
        self.assertEqual(row["current"]["attestationStatus"][0], "3")
        self.assertFalse(value["identityMappings"][0]["personIdentityEstablished"])

    def test_external_inventory_and_component_flags(self):
        with self.assertRaisesRegex(MuseumError, "external manifest"):
            dossier.verify_files(self.files, "0x" + "11" * 32)
        for change in ("unlisted", "missing", "duplicate", "false_general", "false_selection"):
            files = dict(self.files)
            manifest = loads(files["manifest.json"])
            if change == "unlisted": files["extra.json"] = b"{}"
            elif change == "missing": del files["artist/transcript.json"]
            elif change == "duplicate": manifest["files"][1] = manifest["files"][0]
            elif change == "false_general": manifest["components"]["general"] = True
            else: manifest["components"]["selection"] = True
            files["manifest.json"] = dumps(manifest)
            with self.subTest(change=change), self.assertRaises(MuseumError):
                dossier.verify_files(files, keccak256(files["manifest.json"]))

    def test_rehashed_derived_claims_and_profiles_do_not_bypass_rebuild(self):
        paths = ["dossier.json", "report.json", "graph/source-coverage.json", "graph/provenance.json",
            "artist/profile.json", "semantics/documents/" + NAME + ".json",
            next(path for path in self.files if path.startswith("graph/resources/"))]
        for path in paths:
            files = dict(self.files); value = loads(files[path])
            if isinstance(value, list): value = value[1:]
            elif path.startswith("graph/resources/"): value["content"] = "invented named institutional approval"
            elif "claims" in value: value["claims"]["personhoodProven"] = True
            else: value["invented"] = "replacement interpretation"
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "do not reconstruct"):
                dossier.verify_files(files, rehash(files))

    def test_rehashed_original_snapshots_do_not_replace_replay(self):
        for path in ("artist/snapshot.json", "semantics/snapshot.json", "sources/metadata/snapshot.json"):
            files = dict(self.files); value = loads(files[path]); value["invented"] = True
            files[path] = dumps(value)
            with self.subTest(path=path), self.assertRaisesRegex(MuseumError, "replay differs"):
                dossier.verify_files(files, rehash(files))

    def test_binary_original_keeps_every_field_without_fake_text_resource(self):
        value = copy.deepcopy(loads(self.artist.snapshot()))
        original = value["attestations"][0]
        original["metadataOriginal"]["payloadHex"] = "0xff"
        files = dossier.render(value)
        index = loads(files["graph/index.json"])["resources"]
        self.assertEqual(index[0]["status"], "retained_binary_original")
        self.assertIsNone(index[0]["path"])
        coverage = loads(files["graph/source-coverage.json"])
        self.assertEqual({row["sourcePath"]: row["value"] for row in coverage if row["source"] == index[0]["source"]},
            dict(dossier.leaves(original)))

    def test_concrete_source_and_same_artist_instance_required(self):
        with self.assertRaisesRegex(MuseumError, "concrete"):
            dossier.build_files(loads(self.artist.snapshot()))
        other = Fixture().overlay()
        with self.assertRaisesRegex(MuseumError, "exact Artist source"):
            dossier.build_files(other, semantic=self.semantic)
        with self.assertRaisesRegex(MuseumError, "selection needs"):
            dossier.build_files(other, selection_raw=b"{}", selection_hash=keccak256(b"{}"))

    def test_empty_artist_scope_remains_empty_and_replays(self):
        files = dossier.build_files(Fixture(empty=True).overlay())
        report = dossier.verify_files(files, keccak256(files["manifest.json"]))
        self.assertEqual(report["attestationCount"], "0")
        self.assertEqual(loads(files["graph/index.json"])["resources"], [])

    def test_new_profile_reuses_schema_bytes_without_changing_old_policy(self):
        old = AccountProjectionProfile(dossier.DEFAULT_MODEL_ROOT)
        old_bytes = dict(old.documents)
        new = NativeAttributionProfile()
        _validate(PROFILE_SCHEMA_BYTES, new.profile_bytes)
        self.assertNotEqual(new.profile_hash, old.profile_hash)
        self.assertEqual(dict(old.documents), old_bytes)
        self.assertNotIn(OLD_NAME, new.documents)
        self.assertNotIn(POLICY_NAME, new.documents)
        self.assertIn(POLICY, new.documents); self.assertIn(CROSSWALK, new.documents)
        for name in set(old.documents) & set(new.documents):
            self.assertEqual(new.documents[name], old.documents[name])
        with self.assertRaises(TypeError): new.documents[NAME] = (2, b"{}")

    def test_write_and_cli_verify_need_no_network_and_refuse_overwrite(self):
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory) / "attribution"
            result = dossier.write(self.artist, destination, semantic=self.semantic)
            with patch("socket.socket", side_effect=AssertionError("network forbidden")), \
                    patch("sys.argv", ["attribution_dossier", "verify", str(destination), "--manifest-hash", result["manifestHash"]]), \
                    patch("sys.stdout", new_callable=io.StringIO) as output:
                dossier.main()
            self.assertEqual(loads(output.getvalue().encode())["attestationCount"], "1")
            with self.assertRaises((MuseumError, FileExistsError)):
                dossier.write(self.artist, destination)

    def test_general_originals_notarization_and_supported_semantics_join_offline(self):
        from .test_general_attestation_source import Fixture as GeneralFixture
        from .test_native_attribution_source import Fixture as SemanticFixture
        fixture = SemanticFixture(rotated=True, disputed=True)
        general_fixture = GeneralFixture(artist_context=fixture)
        # One synthetic registry answers every component's shared reads identically.
        fixture.responses = general_fixture.responses
        semantic, general = fixture.semantic(), general_fixture.reader()
        files = dossier.build_files(semantic.artist, semantic=semantic, general=general)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(files, keccak256(files["manifest.json"]))
        self.assertEqual(report["generalAttestations"], "captured")
        self.assertEqual(report["generalAttestationCount"], "4")
        self.assertEqual(files["sources/general/snapshot.json"], general.snapshot())
        value = loads(files["dossier.json"])
        self.assertEqual(value["semanticEvidence"]["statements"][0]["status"], "supported")
        original = value["generalAttestationEvidence"]["original"]
        self.assertEqual(len(original["records"]), 4)
        coverage = loads(files["graph/source-coverage.json"])
        for row in original["records"]:
            source = {"host": original["host"], "recordHash": row["recordHash"], "sourceState": original["sourceState"]}
            self.assertEqual({r["sourcePath"]: r["value"] for r in coverage if r["source"] == source},
                dict(dossier.leaves(row)))
        typed = next(row for row in original["records"] if row["notarization"] is not None)
        self.assertTrue(typed["identityEvidence"]["currentDiffersFromHistorical"])
        self.assertFalse(value["claims"]["personhoodProven"])
        operator = next(row for row in original["records"] if row["receipt"][1] == "2")
        self.assertNotEqual(operator["value"][0], operator["receipt"][0])

        for path in ("sources/general/snapshot.json", "sources/general/profile.json"):
            changed = dict(files); content = loads(changed[path]); content["invented"] = True
            changed[path] = dumps(content)
            with self.subTest(path=path), self.assertRaises(MuseumError):
                dossier.verify_files(changed, rehash(changed))

    def test_general_join_rejects_another_state_and_contradictory_shared_read(self):
        from .test_general_attestation_source import Fixture as GeneralFixture
        fixture = Fixture()
        with self.assertRaisesRegex(MuseumError, "identity/state differs"):
            dossier.build_files(fixture.overlay(), general=GeneralFixture().reader())
        general = GeneralFixture(artist_context=fixture)
        general.block["extraHeaderClaim"] = "contradicts the same block read"
        with self.assertRaisesRegex(MuseumError, "cross-source RPC result differs"):
            dossier.build_files(fixture.overlay(), general=general.reader())

    def test_original_v1_general_package_commitment_and_explicit_profile_dispatch(self):
        from .general_attestation_source import GeneralAttestationSource, PROFILE_BYTES
        from .test_general_attestation_source import Fixture as GeneralFixture
        fixture = GeneralFixture(artist_context=Fixture())
        files = dossier.build_files(fixture.artist_overlay(), general=fixture.reader())
        # Captured before adding V2 dispatch: preserves every V1 package byte.
        self.assertEqual(keccak256(files["manifest.json"]),
            "0xe36121d5c5721b9c08c7a247a0ec26ffdfcf8c70ab6fd9bc93ca9a8aa947a2e5")
        self.assertEqual(files["sources/general/profile.json"], PROFILE_BYTES)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            dossier.verify_files(files, keccak256(files["manifest.json"]))
            with tempfile.TemporaryDirectory() as directory:
                plan = {"provenance": "synthetic_fixture"}
                for name in ("anchor", "transcript", "snapshot"):
                    raw = files["sources/general/" + name + ".json"]
                    path = Path(directory) / (name + ".json")
                    path.write_bytes(raw)
                    plan[name + "Path"], plan[name + "Hash"] = str(path), keccak256(raw)
                source = dossier._input_source(plan, dossier._general_source)
                self.assertIs(type(source), GeneralAttestationSource)
                self.assertEqual(source.snapshot(), files["sources/general/snapshot.json"])

        changed = dict(files)
        anchor = loads(changed["sources/general/anchor.json"])
        anchor["profile"] = "STREAM_MUSEUM_GENERAL_ATTESTATION_SOURCE_V99"
        changed["sources/general/anchor.json"] = dumps(anchor)
        with self.assertRaisesRegex(MuseumError, "profile unsupported"):
            dossier.verify_files(changed, rehash(changed))

    def test_v2_maximum_payload_join_retains_all_chunks_and_replays_offline(self):
        from . import general_attestation_source as v1
        from .general_attestation_source_v2 import GeneralAttestationSourceV2, PROFILE_BYTES
        from .test_general_attestation_source_v2 import Fixture as GeneralFixture
        from .test_native_attribution_source import Fixture as SemanticFixture
        fixture = SemanticFixture(rotated=True, disputed=True)
        general_fixture = GeneralFixture(generic_payload_bytes=24576, artist_context=fixture)
        fixture.responses = general_fixture.responses
        semantic, general = fixture.semantic(), general_fixture.reader()
        files = dossier.build_files(semantic.artist, semantic=semantic, general=general)
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            report = dossier.verify_files(files, keccak256(files["manifest.json"]))
            with tempfile.TemporaryDirectory() as directory:
                plan = {"provenance": "synthetic_fixture"}
                for name in ("anchor", "transcript", "snapshot"):
                    raw = files["sources/general/" + name + ".json"]
                    path = Path(directory) / (name + ".json")
                    path.write_bytes(raw)
                    plan[name + "Path"], plan[name + "Hash"] = str(path), keccak256(raw)
                source = dossier._input_source(plan, dossier._general_source)
                self.assertIs(type(source), GeneralAttestationSourceV2)
                self.assertEqual(source.snapshot(), general.snapshot())
        self.assertEqual(report["generalAttestationCount"], "4")
        self.assertEqual(files["sources/general/profile.json"], PROFILE_BYTES)
        original = loads(files["dossier.json"])["generalAttestationEvidence"]["original"]
        row = next(item for item in original["records"] if item["value"][3] == v1.CURATORIAL)
        self.assertEqual(row["payloadInfo"]["byteLength"], "24576")
        self.assertEqual(row["payloadInfo"]["chunkCount"], "3")
        self.assertEqual(row["payloadInfo"]["firstChunkPointer"], row["payloadChunks"][0]["pointer"])
        self.assertNotEqual(row["payloadInfo"]["contentHash"], row["payloadChunks"][0]["chunkHash"])
        resources = loads(files["graph/index.json"])["resources"]
        resource = next(item for item in resources if item["source"].get("recordHash") == row["recordHash"])
        self.assertEqual(loads(files[resource["path"]])["content"].encode(), bytes.fromhex(row["payloadHex"][2:]))
        coverage = loads(files["graph/source-coverage.json"])
        self.assertEqual({item["sourcePath"]: item["value"] for item in coverage
            if item["source"] == resource["source"]}, dict(dossier.leaves(row)))
        self.assertFalse(report["claims"]["actualChainAcceptance"])

        changed = dict(files)
        changed["sources/general/profile.json"] = v1.PROFILE_BYTES
        with self.assertRaisesRegex(MuseumError, "profile bytes differ"):
            dossier.verify_files(changed, rehash(changed))
        changed = dict(files)
        value = loads(changed["sources/general/snapshot.json"])
        record = next(item for item in value["records"] if item["value"][3] == v1.CURATORIAL)
        record["payloadChunks"].reverse()
        changed["sources/general/snapshot.json"] = dumps(value)
        with self.assertRaisesRegex(MuseumError, "general replay differs"):
            dossier.verify_files(changed, rehash(changed))
        changed = dict(files)
        anchor = loads(changed["sources/general/anchor.json"])
        anchor["profile"] = v1.PROFILE
        changed["sources/general/anchor.json"] = dumps(anchor)
        with self.assertRaises(MuseumError):
            dossier.verify_files(changed, rehash(changed))

    def test_v2_worst_case_json_escaping_preserves_complete_original(self):
        from . import general_attestation_source as v1
        from .test_general_attestation_source_v2 import Fixture as GeneralFixture
        fixture = GeneralFixture(generic_payload_bytes=None, artist_context=Fixture())
        original = bytes(24576)
        fixture._replace_payload(2, original)
        fixture.install_v2_state()
        files = dossier.build_files(fixture.artist_overlay(), general=fixture.reader())
        with patch("socket.socket", side_effect=AssertionError("network forbidden")):
            dossier.verify_files(files, keccak256(files["manifest.json"]))
        snapshot = loads(files["sources/general/snapshot.json"])
        row = next(item for item in snapshot["records"] if item["value"][3] == v1.CURATORIAL)
        resource = next(item for item in loads(files["graph/index.json"])["resources"]
            if item["source"].get("recordHash") == row["recordHash"])
        raw = files[resource["path"]]
        self.assertGreater(len(raw), 6 * len(original))
        self.assertLessEqual(len(raw), dossier.MAX_GENERAL_V2_RESOURCE)
        self.assertEqual(loads(raw)["content"].encode(), original)


if __name__ == "__main__":
    unittest.main()
