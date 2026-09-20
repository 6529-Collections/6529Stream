"""Concrete synthetic three-source composition; no deployed runtime or execution acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from . import conservation_provider_binding as binding
from . import public_conservation_provider_capture as capture
from . import public_conservation_provider_source as source
from .canonical import MuseumError, dumps, keccak256, loads
from .test_public_conservation_provider_source import PublicConservationProviderFixture, original_preimage, A, H, K


class ConservationProviderBindingFixture(PublicConservationProviderFixture):
    def __init__(self, *, original_target=None, original_hash=None, **kwargs):
        self.original_target, self.original_hash = original_target, original_hash
        super().__init__(**kwargs)

    def _configure_provider(self):
        super()._configure_provider()
        targets, hashes = list(self.configuration[0]), list(self.configuration[1])
        if self.original_target is not None: targets[self.original_target] = A(20000 + self.original_target)
        if self.original_hash is not None: hashes[self.original_hash] = K("different original dependency hash")
        self.configuration = (tuple(targets), tuple(hashes), *self.configuration[2:])
        self.configuration_hash = keccak256(original_preimage(self.configuration))
        self.set_configuration(self.configuration)
        self.add(self.floor_provider, "metadata()", (), (), ("address",), (targets[1],))
        self.add(self.floor_provider, "metadataCodeHash()", (), (), ("bytes32",), (hashes[1],))

    def provider_capture(self, *, provenance="synthetic_fixture"):
        anchor = dumps(self.a)
        adapter = source.PublicConservationProviderSource(anchor, self)
        adapter.snapshot(); transcript = adapter.transcript()
        if provenance == "trusted_rpc":
            admitted = deepcopy(self.a)
            admitted["runtimeAdmission"]["kind"] = "externally_admitted_runtime"
            anchor = dumps(admitted)
        return capture.replay(anchor, keccak256(anchor), source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance=provenance, disclosure="public")

    def inputs(self): return self.compose(), self.provider_capture()

    def assembled(self):
        old, provider = self.inputs()
        return binding.compose(dict(old.files), old.manifest_hash, dict(provider.files), provider.manifest_hash, disclosure="public")


class ConservationProviderBindingTests(unittest.TestCase):
    @staticmethod
    def join(old, provider):
        return binding.compose(dict(old.files), old.manifest_hash, dict(provider.files), provider.manifest_hash, disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files)
        manifest = loads(files["manifest.json"], maximum=32 * 1024 * 1024)
        manifest["files"] = [binding.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_exact_native_configuration_closes_dependency_identity_only(self):
        fixture = ConservationProviderBindingFixture(raised=True)
        old, provider = fixture.inputs()
        with patch("socket.socket", side_effect=AssertionError("synthetic offline only")):
            result = self.join(old, provider)
            replay = binding.verify(dict(result.files), result.manifest_hash)
        self.assertEqual(replay.files, result.files)
        report = result.report; joined = report["providerBinding"]
        self.assertEqual(joined["status"], "original_provider_configuration_joined")
        self.assertEqual(joined["configurationHash"], fixture.configuration_hash)
        self.assertEqual(joined["firstSaleReceiptHash"], fixture.first[0])
        self.assertEqual(joined["runtimeAdmission"], fixture.a["runtimeAdmission"])
        self.assertEqual([row["rightsAnchorField"] for row in joined["matchedRightsDependencies"]],
            ["core", "host", "schemas", "store", "rightsSelector"])
        self.assertEqual(joined["originalGas"][0]["genesisValue"], "400000")
        self.assertEqual(joined["currentGas"][0]["value"], "800000")
        self.assertEqual(report["historicalRightsStatus"], "original_record_joined")
        self.assertEqual(report["items"][6]["status"], "derived_within_source_profile")
        self.assertEqual(report["items"][12]["status"], "partial")
        self.assertEqual(len(report["items"]), 19)
        self.assertFalse(report["canonicalPacketReady"])
        for claim in ("runtimeArtifactAuthenticityProven", "historicalProviderEligibilityReexecuted",
                "historicalProviderExecutionProven", "personhoodProven", "rightsLegalTruthProven", "allPaidRoutesCovered",
                "sourceConsensusVerified", "actualChainAcceptance", "completeCanonicalPacket"):
            self.assertFalse(report["claims"][claim], claim)

    def test_all_original_inputs_preserved_and_complete_packet_refused(self):
        fixture = ConservationProviderBindingFixture(); old, provider = fixture.inputs()
        result = self.join(old, provider); files = dict(result.files)
        for prefix, original_input in (("rights-assembly/", old), ("provider-capture/", provider)):
            self.assertEqual({path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)},
                dict(original_input.files))
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            binding.complete_packet(files, result.manifest_hash)

    def test_superseded_or_unmatched_original_remains_distinct_from_configuration_binding(self):
        for mode, expected in (("superseded_before_sale", "original_record_joined_but_superseded"),
                ("unmatched", "saved_record_not_in_collection_history"),
                ("post_selection", "selection_not_before_first_sale")):
            with self.subTest(mode=mode):
                result = ConservationProviderBindingFixture(mode=mode).assembled()
                self.assertEqual(result.report["historicalRightsStatus"], expected)
                self.assertEqual(result.report["providerBinding"]["status"], "original_provider_configuration_joined")
                self.assertEqual(result.report["items"][6]["status"], "derived_within_source_profile")
                self.assertEqual(loads(dict(result.files)[result.report["historicalRightsPath"]], maximum=32 * 1024 * 1024)["status"], expected)

    def test_direct_original_family_is_not_converted_to_universal(self):
        result = ConservationProviderBindingFixture(family="direct").assembled()
        self.assertEqual(result.report["floorFamily"], "direct_primary_v1")
        snapshot = loads(dict(result.files)["rights-assembly/captures/floor/source/snapshot.json"], maximum=32 * 1024 * 1024)
        self.assertEqual(len(snapshot["floor"]["directSales"]), 1)
        self.assertNotIn("settlements", snapshot["floor"])

    def test_empty_and_waived_first_sale_have_no_provider_binding_to_invent(self):
        for mode in ("empty", "waived"):
            fixture = ConservationProviderBindingFixture(mode=mode)
            old, provider = fixture.inputs()  # Both original packages individually replay successfully.
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "requires a non-waived first-sale source"):
                self.join(old, provider)

    def test_coherent_original_dependency_mismatches_reject_after_individual_replay(self):
        for variant in ("address", "hash"):
            for index in (1, 2, 3, 4):
                fixture = ConservationProviderBindingFixture(**{"original_target" if variant == "address" else "original_hash": index})
                old, provider = fixture.inputs()
                with self.subTest(variant=variant, index=index), self.assertRaisesRegex(MuseumError,
                        "original Metadata differs|original RIGHTS dependency differs"):
                    self.join(old, provider)

    def test_original_admitted_provider_runtime_or_configuration_mismatch_reject(self):
        for mode in ("runtime", "configuration"):
            fixture = ConservationProviderBindingFixture(); old = fixture.compose()
            if mode == "runtime":
                fixture.codes[fixture.floor_provider] = b"different explicitly admitted source runtime"
                next(pin for pin in fixture.a["codePins"] if pin["address"] == fixture.floor_provider)["runtimeHash"] = \
                    keccak256(fixture.codes[fixture.floor_provider])
            else:
                hashes = list(fixture.configuration[1]); hashes[5] = K("another preserved unused slot")
                config = (fixture.configuration[0], tuple(hashes), *fixture.configuration[2:])
                fixture.set_configuration(config)
                fixture.a["configurationHash"] = keccak256(original_preimage(config))
            provider = fixture.provider_capture()
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "original admitted provider/configuration differs"):
                self.join(old, provider)

    def test_registration_after_admission_rejects_even_with_valid_standalone_captures(self):
        fixture = ConservationProviderBindingFixture()
        early = fixture.receipts[H(400)]["logs"]
        registrations = fixture.registration_events
        for event in registrations: early.remove(event)
        later = fixture.receipts[H(403)]
        for event in registrations:
            event.update({key: later[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")})
            event["logIndex"] = hex(len(later["logs"])); later["logs"].append(event)
        old, provider = fixture.inputs()
        with self.assertRaisesRegex(MuseumError, "original registration/admission/sale order differs"):
            self.join(old, provider)

    def test_same_block_constructor_registration_must_precede_admission_by_log_order(self):
        for before in (True, False):
            fixture = ConservationProviderBindingFixture()
            early = fixture.receipts[H(400)]["logs"]
            target = fixture.receipts[H(402)]
            for event in fixture.registration_events:
                early.remove(event)
                event.update({key: target[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")})
            target["logs"] = (fixture.registration_events + target["logs"] if before else target["logs"] + fixture.registration_events)
            for index, log in enumerate(target["logs"]): log["logIndex"] = hex(index)
            old, provider = fixture.inputs()
            with self.subTest(before=before):
                if before:
                    joined = self.join(old, provider).report["providerBinding"]
                    registered = joined["registrationEvents"][-1]["publication"]
                    admission = joined["originalSourceAdmission"]["admission"]["publication"]
                    self.assertEqual(registered["blockHash"], admission["blockHash"])
                    self.assertEqual(registered["transactionIndex"], admission["transactionIndex"])
                    self.assertEqual(int(registered["logIndex"]) + 1, int(admission["logIndex"]))
                else:
                    with self.assertRaisesRegex(MuseumError, "original registration/admission/sale order differs"):
                        self.join(old, provider)

    def test_independent_source_common_anchor_and_core_runtime_conflicts_reject(self):
        old = ConservationProviderBindingFixture().compose()
        for mode in ("environment", "deployment", "Core"):
            fixture = ConservationProviderBindingFixture()
            if mode == "environment": fixture.a["environment"] = "local_evm_fixture"
            elif mode == "deployment": fixture.a["deploymentEvidenceHash"] = K("other deployment")
            else:
                fixture.codes[fixture.core] = b"coherently independently pinned Core runtime"
                digest = keccak256(fixture.codes[fixture.core])
                next(pin for pin in fixture.a["codePins"] if pin["address"] == fixture.core)["runtimeHash"] = digest
                hashes = list(fixture.configuration[1]); hashes[0] = digest
                config = (fixture.configuration[0], tuple(hashes), *fixture.configuration[2:])
                fixture.set_configuration(config)
                fixture.a["configurationHash"] = keccak256(original_preimage(config))
                fixture.add(fixture.floor_provider, "coreCodeHash()", (), (), ("bytes32",), (digest,))
            provider = fixture.provider_capture()
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "common anchor differs|shared runtime differs"):
                self.join(old, provider)

    def test_complete_shared_receipt_conflict_rejects_unrelated_native_log(self):
        old = ConservationProviderBindingFixture().compose()
        fixture = ConservationProviderBindingFixture()
        fixture.event(0, A(999), [K("unrelated added log")], (), ())
        provider = fixture.provider_capture()
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome differs|repeated receipt differs"):
            self.join(old, provider)

    def test_external_pins_and_rehashed_semantic_tampering_reject(self):
        fixture = ConservationProviderBindingFixture(); old, provider = fixture.inputs()
        for old_hash, provider_hash in ((H(999), provider.manifest_hash), (old.manifest_hash, H(999))):
            with self.assertRaises(MuseumError):
                binding.compose(dict(old.files), old_hash, dict(provider.files), provider_hash, disclosure="public")
        result = self.join(old, provider)
        for mode in ("authority", "historical-status", "extra"):
            files = dict(result.files)
            if mode == "extra": files["provider-binding/caller-complete.json"] = dumps({"complete": True})
            else:
                path = "provider-binding/binding.json" if mode == "authority" else "provider-binding/report.json"
                row = loads(files[path], maximum=32 * 1024 * 1024)
                row["historicalProviderExecutionProven" if mode == "authority" else "historicalRightsStatus"] = \
                    True if mode == "authority" else "original_record_joined_but_superseded"
                files[path] = dumps(row)
            files, digest = self.repin(files)
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                binding.verify(files, digest)

    def test_different_explicit_provenance_is_not_promoted_by_join(self):
        fixture = ConservationProviderBindingFixture(); old = fixture.compose()
        provider = fixture.provider_capture(provenance="trusted_rpc")
        self.assertEqual(provider.report["provenance"], "trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "source provenance differs"): self.join(old, provider)

    def test_public_preflight_before_input_iteration_or_cli_reads(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("input inspected before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            binding.compose(Unreadable(), H(1), Unreadable(), H(2), disclosure="restricted")
        with patch.object(binding, "read_tree", side_effect=AssertionError("input path read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                binding.main(["assemble", "--rights", "unused-rights", "--rights-hash", H(1), "--provider", "unused-provider",
                    "--provider-hash", H(2), "--disclosure", "restricted", "--output", "unused-output"])


if __name__ == "__main__": unittest.main()
