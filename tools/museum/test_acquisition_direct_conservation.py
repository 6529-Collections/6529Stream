"""Concrete six-source synthetic replays; no live RPC, payment or authority proof."""
from contextlib import redirect_stdout
import io
from pathlib import Path
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

from ..metadata import acquisition_conservation_context_v1 as context
from . import acquisition_direct_conservation as assembly
from . import public_conservation_tier_capture as tier_capture
from . import public_conservation_tier_source as tier_source
from . import public_direct_conservation_source as direct
from . import public_conservation_floor_source as floor
from .bagit import read_tree, write_tree
from .canonical import MuseumError, dumps, keccak256, loads
from .direct_conservation_fixture import DirectConservationFixture
from .independent_wire import ZERO, json_values
from .mint_entropy_source import TRANSFER
from .test_current_rights_source import A, H
from .test_native_conservation_fixture import K


class AcquisitionDirectConservationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = DirectConservationFixture()
        cls.inputs = cls.fixture.packages()
        cls.result = cls.join(*cls.inputs)

    @staticmethod
    def join(*inputs):
        return assembly.compose(*sum(([dict(value.files), value.manifest_hash] for value in inputs), []), disclosure="public")

    @staticmethod
    def repin(files):
        files = dict(files); manifest = loads(files["manifest.json"], maximum=32 * 1024 * 1024)
        manifest["files"] = [assembly.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_actual_six_source_context_and_original_packages_preserved(self):
        files = dict(self.result.files); report = self.result.report
        for prefix, original in zip(("direct-assembly/", "captures/tier/", "captures/selection/"), self.inputs):
            self.assertEqual({path.removeprefix(prefix): raw for path, raw in files.items() if path.startswith(prefix)},
                dict(original.files))
        reconciliation = loads(files["packet/source-reconciliation.json"], maximum=1048576)
        self.assertEqual(set(reconciliation["inputs"]), {"rights", "floor", "provider", "personhood", "tier", "selection"})
        native = context.validate(files["packet/conservation-context.json"])
        self.assertEqual(native["sourceState"], report["fields"]["sourceState"])
        self.assertEqual(native["sourceRefs"], report["nativeContext"]["sourceRefs"])
        self.assertEqual(files["definitions/conservation-context-schema.json"], context.SCHEMA_BYTES)
        for role, original in zip(("tier", "selection"), self.inputs[1:]):
            raw = dict(original.files); refs = native["sourceRefs"][role]
            for key, path in (("manifestHash", "manifest.json"), ("anchorHash", "source/anchor.json"),
                    ("transcriptHash", "source/transcript.json"), ("snapshotHash", "source/snapshot.json")):
                self.assertEqual(refs[key], keccak256(raw[path]))
        direct_value = loads(files["direct-assembly/packet/native-direct-floor.json"], maximum=1048576)
        self.assertEqual(direct_value["floor"]["directSales"][0]["receipt"], json_values(self.fixture.direct_receipt))
        self.assertNotIn("settlements", direct_value["floor"])

    def test_original_default_tier_and_completed_target_identity_join(self):
        report = self.result.report; joined = report["tierJoin"]
        self.assertEqual(joined["status"], "original_tier_and_completed_direct_tokens_joined")
        self.assertEqual(joined["currentTier"]["rawDeclaredTier"], ZERO)
        self.assertEqual(joined["currentTier"]["tierBasis"], "default")
        self.assertEqual(joined["firstSaleTier"], "MUSEUM_GRADE_LITE")
        self.assertEqual(joined["targetTokenId"], "41")
        self.assertEqual(report["fields"]["sourceState"]["collectionSerial"], "3")
        observed = joined["directTokens"][0]
        self.assertEqual(observed["completedMint"]["tokenId"], observed["tokenId"])
        self.assertEqual(observed["tokenIdentity"]["collectionSerial"], "3")
        self.assertLess(assembly.v4._pos(observed["completedMint"]["publication"]),
            assembly.v4._pos(observed["paidPublication"]))
        self.assertFalse(observed["tokenOperationIdentityProven"])

    def test_declared_museum_grade_precedes_mint_and_all_original_floor_receipts(self):
        fixture = DirectConservationFixture(declared_tier=True)
        inputs = fixture.packages(); result = self.join(*inputs)
        joined = result.report["tierJoin"]; tier = joined["currentTier"]
        self.assertEqual(tier["rawDeclaredTier"], floor.FULL)
        self.assertEqual(tier["effectiveTier"], "MUSEUM_GRADE")
        self.assertEqual(joined["firstSaleTier"], "MUSEUM_GRADE")
        declaration_position = assembly.v4._pos(tier["declaration"]["publication"])
        token = joined["directTokens"][0]
        self.assertLess(declaration_position, assembly.v4._pos(token["completedMint"]["publication"]))
        self.assertLess(assembly.v4._pos(token["completedMint"]["publication"]),
            assembly.v4._pos(token["paidPublication"]))
        original = loads(dict(inputs[0].files)["packet/native-direct-floor.json"], maximum=1048576)["floor"]
        for row in (original["firstSale"], *original["releases"], *original["directSales"]):
            self.assertEqual(row["effectiveTier"], "MUSEUM_GRADE")
            self.assertLess(declaration_position, assembly.v4._pos(row["publication"]))
        self.assertEqual(fixture.first[2], floor.FULL)
        self.assertEqual(fixture.release[3], floor.FULL)
        self.assertEqual(fixture.direct_receipt[8], floor.FULL)
        self.assertEqual(result.report["documentary"]["firstSale"]["joins"]["intentRecordHash"]["status"],
            "original_selected_history_joined")

    def test_actual_provider_selector_is_bound_despite_constructor_skip(self):
        matched = self.result.report["providerSelectionBinding"]
        self.assertTrue(matched["constructorSkippedSelectorValidation"])
        self.assertTrue(matched["selectionReadConsumesSavedSelector"])
        self.assertEqual([row["index"] for row in matched["matchedDependencies"]], ["0", "1", "2", "3", "5", "7", "8"])
        selector = next(row for row in matched["matchedDependencies"] if row["index"] == "5")
        self.assertEqual(selector["address"], self.fixture.selection_anchor["conservationSelector"])
        inputs = DirectConservationFixture(provider_selector=A(10005)).packages()
        with self.assertRaisesRegex(MuseumError, "original provider selection dependency differs"):
            self.join(*inputs)

    def test_saved_intent_registration_and_exact_waived_interview_preimage_join(self):
        first = self.result.report["documentary"]["firstSale"]
        self.assertTrue(first["observedSelectedHeadMatchesSavedRecord"])
        self.assertEqual(first["selectionAtFirstSale"]["selectionHash"], self.fixture.saved_selection[12])
        self.assertEqual(first["facts"]["interviewEvidenceHash"], self.fixture.floor_interview_commitment)
        for key in ("identityRecordHash", "intentRecordHash", "interviewEvidenceHash"):
            self.assertEqual(first["joins"][key]["status"], "original_selected_history_joined")
        self.assertEqual(first["joins"]["intentWaiverRecordHash"]["status"], "native_alternative_not_selected")
        self.assertFalse(self.result.report["documentary"]["completeDocumentaryPrerequisites"])

    def test_present_interview_and_native_intent_waiver_keep_distinct_records(self):
        for mode in ("present", "waiver"):
            with self.subTest(mode=mode):
                fixture = DirectConservationFixture(selection_mode=mode); result = self.join(*fixture.packages())
                first = result.report["documentary"]["firstSale"]
                self.assertEqual(first["facts"]["interviewEvidenceHash"], fixture.floor_interview_commitment)
                self.assertEqual(first["joins"]["interviewEvidenceHash"]["status"], "original_selected_history_joined")
                key, alternate = ("intentWaiverRecordHash", "intentRecordHash") if mode == "waiver" else ("intentRecordHash", "intentWaiverRecordHash")
                self.assertEqual(first["joins"][key]["status"], "original_selected_history_joined")
                self.assertEqual(first["facts"][alternate], ZERO)
                self.assertEqual(fixture.saved_selection[3], 0 if mode == "present" else 1)

    def test_pre_sale_and_post_sale_supersession_are_not_the_same_observation(self):
        for mode, expected, latest in (("superseded", "original_selected_history_joined", True),
                ("superseded_before_sale", "original_selected_history_joined_but_superseded", False)):
            with self.subTest(mode=mode):
                result = self.join(*DirectConservationFixture(selection_mode=mode).packages())
                first = result.report["documentary"]["firstSale"]
                self.assertEqual(first["joins"]["intentRecordHash"]["status"], expected)
                self.assertEqual(first["observedSelectedHeadMatchesSavedRecord"], latest)
                if mode == "superseded":
                    self.assertNotEqual(first["selectionAtFirstSale"]["recordHash"], first["currentArtistSelection"]["recordHash"])
                self.assertEqual(result.report["items"][6]["status"], "derived_within_source_profile")

    def test_missing_historical_commitment_retains_paid_facts_without_fallback(self):
        fixture = DirectConservationFixture(saved_intent=K("unobserved historical original"))
        result = self.join(*fixture.packages()); first = result.report["documentary"]["firstSale"]
        self.assertEqual(first["facts"]["intentRecordHash"], fixture.saved_intent)
        self.assertNotEqual(first["joins"]["intentRecordHash"]["status"], "original_selected_history_joined")
        self.assertIsNone(first["observedSelectedHeadMatchesSavedRecord"])
        self.assertFalse(result.report["canonicalPacketReady"])

    def test_source_valid_paid_before_mint_and_late_declaration_is_rejected(self):
        inputs = DirectConservationFixture(late_declaration=True).packages()
        snapshot = loads(dict(inputs[1].files)["source/snapshot.json"], maximum=1048576)
        self.assertEqual(snapshot["tier"]["effectiveTier"], "MUSEUM_GRADE")
        self.assertEqual(snapshot["tier"]["declaration"]["publication"]["blockNumber"], "3")
        self.assertEqual(snapshot["tier"]["firstCompletedMint"]["publication"]["blockNumber"], "4")
        with self.assertRaisesRegex(MuseumError, "paid floor precedes completed token mint"):
            self.join(*inputs)

    def test_independently_valid_wrong_sale_tier_and_unallocated_paid_token_reject(self):
        for options, message in (({"sale_tier": floor.FULL}, "historical sale tier differs"),
                ({"direct_token": 42}, "sale token completed mint missing/ambiguous")):
            with self.subTest(options=options):
                inputs = DirectConservationFixture(**options).packages()
                with self.assertRaisesRegex(MuseumError, message): self.join(*inputs)

    def test_same_timestamp_completed_mint_after_paid_log_is_not_prior_mint(self):
        fixture = DirectConservationFixture(); events = fixture.receipts[H(403)]["logs"]
        transfer = next(event for event in events if event["address"] == fixture.core and event["topics"][0] == TRANSFER)
        events.remove(transfer); events.append(transfer); fixture.reorder_logs(3, events)
        inputs = fixture.packages()  # All exact source observations are otherwise internally consistent.
        with self.assertRaisesRegex(MuseumError, "paid floor precedes completed token mint"):
            self.join(*inputs)

    def test_platform_floor_preserves_unused_saved_selector_without_admitting_it(self):
        result = self.join(*DirectConservationFixture(platform_works=True, provider_selector=A(10005)).packages())
        observed = result.report["providerSelectionBinding"]
        self.assertEqual(observed["status"], "saved_provider_selector_not_required_by_original_platform_floor")
        self.assertFalse(observed["selectionReadConsumesSavedSelector"])
        self.assertEqual(result.report["personhood"]["status"], "not_required_platform_floor")
        self.assertFalse(result.report["claims"]["historicalProviderExecutionProven"])

    def test_erc20_and_auction_original_slices_have_prior_completed_mint(self):
        for product in (direct.ERC20, direct.AUCTION):
            with self.subTest(product=product):
                fixture = DirectConservationFixture(product=product); result = self.join(*fixture.packages())
                token = result.report["tierJoin"]["directTokens"][0]
                self.assertLess(assembly.v4._pos(token["completedMint"]["publication"]), assembly.v4._pos(token["paidPublication"]))
                self.assertEqual(token["completedMint"]["publication"]["blockNumber"], "2" if product == direct.AUCTION else "3")
                if product == direct.AUCTION:
                    self.assertEqual(token["completedMint"]["recipient"], fixture.floor_recorder)
                original = loads(dict(result.files)["direct-assembly/packet/native-direct-floor.json"], maximum=1048576)
                self.assertEqual(original["floor"]["directSales"][0]["receipt"][6][5], product)

    def test_common_anchor_runtime_and_full_shared_receipt_conflicts_reject(self):
        for mode in ("environment", "runtime", "receipt", "header"):
            with self.subTest(mode=mode):
                fixture = DirectConservationFixture(); direct_input = fixture.direct_assembly(); selection = fixture.selection_capture()
                if mode == "environment": fixture.tier_anchor["environment"] = "local_evm_fixture"
                elif mode == "runtime":
                    fixture.codes[fixture.core] = b"independently pinned contradictory Core"
                    fixture.tier_anchor["coreRuntimeHash"] = keccak256(fixture.codes[fixture.core])
                elif mode == "receipt": fixture.event(0, A(999), [K("unrelated original receipt event")], (), ())
                else: fixture.blocks[H(200)]["transactions"].append(K("unqueried transaction"))
                tier = fixture.tier_capture()  # Valid independent source capture; no snapshot mocks.
                with self.assertRaisesRegex(MuseumError, "common anchor/profile differs|tier Core runtime differs|repeated RPC outcome differs|repeated receipt differs|header differs"):
                    self.join(direct_input, tier, selection)

    def test_explicit_trusted_replay_does_not_promote_synthetic_source_provenance(self):
        files = dict(self.inputs[1].files); raw, transcript = files["source/anchor.json"], files["source/transcript.json"]
        admitted = tier_capture.replay(raw, keccak256(raw), tier_source.PROFILE_HASH, transcript, keccak256(transcript),
            provenance="trusted_rpc", disclosure="public")
        self.assertEqual(admitted.report["provenance"], "trusted_rpc")
        with self.assertRaisesRegex(MuseumError, "source provenance differs"):
            self.join(self.inputs[0], admitted, self.inputs[2])

    def test_all_nineteen_items_remain_partial_and_complete_packet_refuses(self):
        report = self.result.report
        self.assertEqual(len(report["items"]), 19)
        for index in (1, 6, 18): self.assertEqual(report["items"][index]["status"], "derived_within_source_profile")
        for index in (5, 12):
            self.assertEqual(report["items"][index]["status"], "partial")
            self.assertFalse(report["items"][index]["canonicalPacketCompatible"])
        for name in ("historicalRouterStateProven", "tokenOperationIdentityProven", "historicalProviderExecutionProven",
                "historicalEligibilityReexecuted", "documentaryTruthProven", "signatureRevalidated", "legalPersonhoodProven",
                "masterArchiveEvidenceComplete", "allPaidRoutesCovered", "universalProjectionSynthesized", "v4PacketCompatible",
                "sourceConsensusVerified", "nativeRuntimeAcceptance", "actualChainAcceptance", "completeCanonicalPacket", "networkFetch"):
            self.assertFalse(report["claims"][name], name)
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            assembly.complete_packet(self.result.files, self.result.manifest_hash)

    def test_external_pins_rehashed_tamper_and_unadmitted_disclosure_fail_closed(self):
        args = sum(([dict(value.files), value.manifest_hash] for value in self.inputs), [])
        for index in (1, 3, 5):
            bad = list(args); bad[index] = K("wrong external pin")
            with self.assertRaises(MuseumError): assembly.compose(*bad, disclosure="public")
        for path, field in (("packet/tier-join.json", "tokenOperationIdentityProven"),
                ("packet/documentary-joins.json", "historicalEligibilityReexecuted"),
                ("packet/conservation-context.json", "qualification")):
            with self.subTest(path=path):
                files = dict(self.result.files); value = loads(files[path], maximum=1048576)
                value[field] = "caller assertion"; files[path] = dumps(value); files, digest = self.repin(files)
                with self.assertRaisesRegex(MuseumError, "reconstruction differs"): assembly.verify(files, digest)
        class Unreadable:
            def __iter__(self): raise AssertionError("read before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            assembly.compose(Unreadable(), K("d"), Unreadable(), K("t"), Unreadable(), K("s"), disclosure="restricted")

    def test_offline_cli_dispatch_preserves_inputs_and_refuses_overwrite(self):
        from .package_v2 import verify_package
        with TemporaryDirectory() as temporary:
            root = Path(temporary); argv = ["assemble"]
            for role, value in zip(("direct", "tier", "selection"), self.inputs):
                directory = root / role; write_tree(dict(value.files), directory)
                argv.extend(("--" + role, str(directory), "--" + role + "-hash", value.manifest_hash))
            output = root / "assembled"; argv.extend(("--disclosure", "public", "--output", str(output)))
            stdout = io.StringIO()
            with patch("socket.socket", side_effect=AssertionError("offline replay only")), redirect_stdout(stdout):
                assembly.main(argv)
                replay = verify_package(output, self.result.manifest_hash)
            self.assertEqual(replay.files, self.result.files)
            self.assertEqual(read_tree(output), dict(self.result.files))
            self.assertEqual(loads(stdout.getvalue().encode())["manifestHash"], self.result.manifest_hash)
            with self.assertRaisesRegex(MuseumError, "new directory"): assembly.main(argv)
            self.assertEqual(read_tree(output), dict(self.result.files))
            with redirect_stdout(io.StringIO()), patch("socket.socket", side_effect=AssertionError("offline replay only")):
                assembly.main(["verify", str(output), "--manifest-hash", self.result.manifest_hash])


if __name__ == "__main__": unittest.main()
