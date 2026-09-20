"""Four concrete synthetic source replays; no native payment/personhood acceptance."""
from contextlib import redirect_stdout
from copy import deepcopy
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_direct_floor_v1 as direct_definition
from ..metadata import acquisition_personhood_v1 as personhood_definition
from . import acquisition_direct_personhood as assembly
from . import public_direct_conservation_source as direct
from . import public_personhood_capture as personhood_capture
from . import public_personhood_source as personhood_source
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .direct_personhood_fixture import DirectPersonhoodFixture
from .independent_wire import ZERO, json_values
from .test_current_rights_source import A, H
from .test_public_personhood_source import K


class AcquisitionDirectPersonhoodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = DirectPersonhoodFixture()
        cls.binding, cls.personhood = cls.fixture.packages()
        cls.result = cls.join(cls.binding, cls.personhood)

    @staticmethod
    def join(binding, personhood):
        return assembly.compose(dict(binding.files), binding.manifest_hash,
            dict(personhood.files), personhood.manifest_hash, disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files); manifest = loads(files["manifest.json"], maximum=32 * 1024 * 1024)
        manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_exact_originals_and_two_typed_fragments_preserve_authority_domains(self):
        files, report = dict(self.result.files), self.result.report
        for prefix, original in (("provider-binding/", self.binding), ("personhood-capture/", self.personhood)):
            self.assertEqual({path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)},
                dict(original.files))
        native = direct_definition.validate(files["packet/native-direct-floor.json"])
        person = personhood_definition.validate(files["packet/native-personhood.json"])
        self.assertEqual(native["floor"]["directSales"][0]["receipt"], json_values(self.fixture.direct_receipt))
        self.assertEqual(native["floor"]["directSales"][0]["originalSale"]["receipt"],
            json_values(self.fixture.direct_receipt[7]))
        self.assertNotIn("settlements", native["floor"])
        self.assertEqual(person["general"]["authority"]["kind"], "native_general_receipt")
        self.assertEqual(person["general"]["attestation"][1], "7")
        self.assertEqual(person["sourceState"]["collectionId"], "1")
        self.assertEqual(report["personhood"]["status"], "current_resolved_summary_matches_saved")
        self.assertEqual(report["personhood"]["current"]["evidenceHashDomain"], "personhood_proof_summary")
        self.assertNotEqual(report["personhood"]["current"]["registrationIdentityRecordHash"],
            report["personhood"]["current"]["operativeIdentityRecordHash"])
        self.assertEqual(report["personhood"]["historicalRegistrationIdentityJoin"], {
            "status": "selection_source_not_supplied", "savedRecordHash": self.fixture.registration_hash,
            "historicalRecordJoined": False})
        for report_key, prefix in (("nativeDirectFloor", "provider-binding/rights-assembly/captures/floor/"),
                ("nativePersonhood", "personhood-capture/")):
            ref = report[report_key]["sourceRef"]
            for key, path in (("manifestHash", "manifest.json"), ("anchorHash", "source/anchor.json"),
                    ("transcriptHash", "source/transcript.json"), ("snapshotHash", "source/snapshot.json")):
                self.assertEqual(ref[key], keccak256(files[prefix + path]))
        self.assertEqual(files["definitions/native-direct-floor-schema.json"], direct_definition.SCHEMA_BYTES)
        self.assertEqual(files["definitions/native-personhood-schema.json"], personhood_definition.SCHEMA_BYTES)

    def test_four_observation_sources_and_all_nineteen_items_remain_qualified(self):
        report = self.result.report
        observation = loads(dict(self.result.files)["packet/source-reconciliation.json"], maximum=1048576)
        self.assertEqual(set(observation["inputs"]), {"rights", "floor", "provider", "personhood"})
        self.assertEqual(report["sourceProvenance"], "synthetic_fixture")
        self.assertEqual(len(report["items"]), 19)
        self.assertEqual(report["items"][6]["status"], "derived_within_source_profile")
        for index in (5, 12):
            self.assertEqual(report["items"][index]["status"], "partial")
            self.assertFalse(report["items"][index]["canonicalPacketCompatible"])
        self.assertFalse(report["canonicalPacketReady"])
        for name in ("universalProjectionSynthesized", "legacyPacketPersonhoodAdapted", "tierAndSelectionSourcesJoined",
                "historicalSaleTimeCurrentnessProven", "historicalProviderExecutionProven", "runtimeArtifactAuthenticityProven",
                "legalPersonhoodProven", "institutionalStandingProven", "currentSignatureRevalidated",
                "completePersonhoodHistoryProven", "allPaidRoutesCovered", "paymentExecutionReproved",
                "sourceConsensusVerified", "nativeRuntimeAcceptance", "actualChainAcceptance", "completeCanonicalPacket", "networkFetch"):
            self.assertFalse(report["claims"][name], name)

    def test_native_erc20_and_auction_original_paid_receipts_are_not_universal(self):
        for product in (direct.ERC20, direct.AUCTION):
            with self.subTest(product=product):
                fixture = DirectPersonhoodFixture(product=product); result = self.join(*fixture.packages())
                value = direct_definition.validate(dict(result.files)["packet/native-direct-floor.json"])
                row = value["floor"]["directSales"][0]
                self.assertEqual(row["receipt"][6][5], product)
                self.assertEqual(row["originalSale"]["receipt"], json_values(fixture.direct_receipt[7]))
                self.assertNotIn("settlements", value["floor"])
                self.assertEqual(result.report["personhood"]["status"], "current_resolved_summary_matches_saved")
                if product == direct.AUCTION:
                    self.assertLess(int(row["receipt"][7][9]), int(row["recordedAt"]))
                else:
                    self.assertEqual(row["receipt"][7][14], A(9090))
                    self.assertNotIn(A(9090), fixture.codes)  # No invented current asset-code admission.

    def test_waiver_and_imported_originals_keep_native_hash_domains(self):
        for mode, status, domain in (("waiver", "current_waiver_matches_saved", "native_op24_record"),
                ("imported_waiver", "current_waiver_matches_saved", "native_op24_record"),
                ("imported", "current_resolved_summary_matches_saved", "personhood_proof_summary")):
            with self.subTest(mode=mode):
                fixture = DirectPersonhoodFixture(personhood_mode=mode); result = self.join(*fixture.packages())
                fragment = result.report["personhood"]
                self.assertEqual(fragment["status"], status)
                self.assertEqual(fragment["current"]["evidenceHashDomain"], domain)
                self.assertEqual(fragment["firstSale"]["personhoodEvidenceHash"], fragment["current"]["evidenceHash"])
                self.assertFalse(fragment["legalPersonhoodProven"])
                native = personhood_definition.validate(dict(result.files)["packet/native-personhood.json"])
                if mode.startswith("imported"):
                    self.assertNotEqual(fixture.origin_registry, fixture.registry)
                    self.assertIn(fixture.origin_registry, dumps(native).decode())

    def test_stale_none_and_unresolved_do_not_reclassify_historical_sale(self):
        for mode, observed in (("stale_head", "STALE"), ("none", "NONE"), ("legacy", "UNRESOLVED")):
            with self.subTest(mode=mode):
                result = self.join(*DirectPersonhoodFixture(personhood_mode=mode).packages())
                fragment = result.report["personhood"]
                self.assertEqual(fragment["status"], "saved_commitment_not_currently_identifiable")
                self.assertEqual(fragment["current"]["status"], observed)
                self.assertNotEqual(fragment["firstSale"]["personhoodEvidenceHash"], ZERO)
                self.assertEqual(result.report["historicalRightsStatus"], "original_record_joined")

    def test_other_recorder_and_superseded_rights_keep_separate_current_observations(self):
        result = self.join(*DirectPersonhoodFixture(personhood_mode="other_recorder", mode="superseded_before_sale").packages())
        self.assertEqual(result.report["personhood"]["status"], "current_resolved_summary_matches_saved")
        self.assertEqual(result.report["historicalRightsStatus"], "original_record_joined_but_superseded")
        self.assertEqual(result.report["items"][6]["status"], "derived_within_source_profile")

    def test_platform_floor_does_not_infer_personhood_requirement(self):
        result = self.join(*DirectPersonhoodFixture(platform_works=True).packages())
        self.assertEqual(result.report["personhood"]["status"], "not_required_platform_floor")
        self.assertEqual(result.report["personhood"]["firstSale"]["personhoodEvidenceHash"], ZERO)
        self.assertEqual(result.report["personhood"]["current"]["status"], "RESOLVED")
        self.assertFalse(result.report["personhood"]["legalPersonhoodProven"])

    def test_rehashed_native_saved_artist_or_evidence_mismatch_stays_unidentified(self):
        for key in ("saved_artist", "saved_personhood"):
            with self.subTest(key=key):
                result = self.join(*DirectPersonhoodFixture(**{key: K("different original commitment")}).packages())
                self.assertEqual(result.report["personhood"]["status"], "saved_commitment_not_currently_identifiable")
                self.assertEqual(result.report["personhood"]["current"]["status"], "RESOLVED")

    def test_universal_binding_is_not_projected_into_direct(self):
        binding, personhood = DirectPersonhoodFixture(family="universal").packages()
        self.assertEqual(binding.report["floorFamily"], "universal_primary_v1")
        with self.assertRaisesRegex(MuseumError, "requires DIRECT floor family"):
            self.join(binding, personhood)

    def test_original_provider_artist_target_must_match_personhood_facade(self):
        fixture = DirectPersonhoodFixture(original_target=8)
        binding, personhood = fixture.packages()
        self.assertNotEqual(binding.report["providerBinding"]["configuration"][0][8], fixture.registry)
        # Both original packages replay independently, and their shared reads
        # agree. The provider's different Artist target still forbids this join.
        with self.assertRaisesRegex(MuseumError, "provider dependency differs"):
            self.join(binding, personhood)

    def test_independently_valid_common_state_and_runtime_conflicts_reject(self):
        for mode in ("deployment", "environment", "runtime"):
            with self.subTest(mode=mode):
                fixture = DirectPersonhoodFixture(); binding = fixture.binding_capture()
                if mode == "deployment": fixture.personhood_anchor["deploymentEvidenceHash"] = K("other deployment")
                elif mode == "environment": fixture.personhood_anchor["environment"] = "local_evm_fixture"
                else:
                    address = fixture.floor_recorder
                    fixture.codes[address] = b"independently admitted conflicting adapter runtime"
                    next(pin for pin in fixture.personhood_anchor["codePins"] if pin["address"] == address)["runtimeHash"] = \
                        keccak256(fixture.codes[address])
                personhood = fixture.personhood_capture()  # A complete independently replayed capture, not a stub.
                with self.assertRaisesRegex(MuseumError, "common anchor/profile differs|shared runtime differs"):
                    self.join(binding, personhood)

    def test_independently_valid_full_receipt_and_header_conflicts_reject(self):
        for mode in ("receipt", "header"):
            with self.subTest(mode=mode):
                fixture = DirectPersonhoodFixture(); binding = fixture.binding_capture()
                if mode == "receipt":
                    fixture.event(2, A(999), [K("unrelated full receipt event")], (), ())
                else:
                    fixture.blocks[H(202)]["transactions"].append(K("unqueried transaction in shared header"))
                personhood = fixture.personhood_capture()
                with self.assertRaisesRegex(MuseumError, "repeated RPC outcome differs|repeated receipt differs|header differs"):
                    self.join(binding, personhood)

    def test_provenance_admission_does_not_promote_synthetic_inputs(self):
        files = dict(self.personhood.files)
        anchor = loads(files["source/anchor.json"], maximum=1048576)
        anchor["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
        raw, transcript = dumps(anchor), files["source/transcript.json"]
        personhood = personhood_capture.replay(raw, keccak256(raw), personhood_source.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="trusted_rpc", disclosure="public")
        self.assertEqual(personhood.report["provenance"], "trusted_rpc")
        # This tests caller-admitted replay mechanics, never actual public-chain evidence.
        with self.assertRaisesRegex(MuseumError, "source provenance differs"):
            self.join(self.binding, personhood)

    def test_external_pins_and_rehashed_projection_or_extra_file_tamper_reject(self):
        for binding_hash, personhood_hash in ((K("wrong"), self.personhood.manifest_hash),
                (self.binding.manifest_hash, K("wrong"))):
            with self.assertRaises(MuseumError):
                assembly.compose(dict(self.binding.files), binding_hash, dict(self.personhood.files), personhood_hash,
                    disclosure="public")
        with self.assertRaisesRegex(MuseumError, "external manifest pin"):
            assembly.verify(self.result.files, K("wrong"))
        for path, key in (("documentary/personhood.json", "legalPersonhoodProven"),
                ("packet/native-direct-floor.json", "qualification"),
                ("packet/native-personhood.json", "qualification"), ("extra.json", None)):
            with self.subTest(path=path):
                files = dict(self.result.files)
                value = {} if key is None else loads(files[path], maximum=1048576)
                value["complete" if key is None else key] = "caller supplied claim"
                files[path] = dumps(value); files, digest = self.repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                    assembly.verify(files, digest)

    def test_complete_packet_and_public_preflight_fail_before_unadmitted_reads(self):
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), K("one"), Unreadable(), K("two"), disclosure="restricted")
        with patch.object(assembly, "read_tree", side_effect=AssertionError("path read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                assembly.main(["assemble", "--provider-binding", "unread-binding", "--provider-binding-hash", K("one"),
                    "--personhood", "unread-personhood", "--personhood-hash", K("two"),
                    "--disclosure", "restricted", "--output", "unread-output"])

    def test_offline_cli_and_common_dispatch_reconstruct_and_refuse_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temp:
            root = Path(temp); binding = root / "binding"; personhood = root / "personhood"; output = root / "output"
            write_tree(dict(self.binding.files), binding); write_tree(dict(self.personhood.files), personhood)
            argv = ["assemble", "--provider-binding", str(binding), "--provider-binding-hash", self.binding.manifest_hash,
                "--personhood", str(personhood), "--personhood-hash", self.personhood.manifest_hash,
                "--disclosure", "public", "--output", str(output)]
            stdout = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline replay only")), redirect_stdout(stdout):
                assembly.main(argv)
                replay = verify_package(output, self.result.manifest_hash)
            self.assertEqual(replay.files, self.result.files)
            self.assertEqual(read_tree(output), dict(self.result.files))
            self.assertEqual(loads(stdout.getvalue().encode())["manifestHash"], self.result.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "new directory"):
                assembly.main(argv)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline replay only")):
                assembly.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])


if __name__ == "__main__": unittest.main()
