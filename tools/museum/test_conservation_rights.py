"""Coherent synthetic RIGHTS and floor captures; no legal or actual-chain acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads
from .chain_abi import encode
from .independent_wire import ZERO, ZERO_ADDRESS
from . import public_conservation_floor_source as floor
from . import public_conservation_floor_capture as floor_capture
from . import public_direct_conservation_source as direct
from . import public_direct_conservation_capture as direct_capture
from . import public_rights_source as rights
from . import public_history_capture as rights_capture
from . import conservation_rights as composer
from .current_rights_source import SELECTION, EMPTY_SELECTION, SELECTED_EVENT, selection_hash
from .test_public_rights_source import PublicRightsFixture
from .test_native_conservation_fixture import NativeConservationFixture, K, _zero
from .test_current_rights_source import A, H


class ConservationRightsFixture(PublicRightsFixture):
    """Both frozen readers query one response map and the same complete receipts."""
    topic = staticmethod(NativeConservationFixture.topic)
    _action = NativeConservationFixture._action

    def __init__(self, *, mode="joined", family="universal", burned=False):
        if mode not in ("joined", "empty", "waived", "unmatched", "post_publication", "post_selection",
                "wrong_metadata_code", "superseded_before_sale", "same_block_before", "same_block_after") or family not in ("universal", "direct"):
            raise ValueError("unsupported synthetic historical RIGHTS mode")
        super().__init__(source_block=5, collection=False, token=False, burned=burned)
        self.mode, self.family = mode, family
        self.core, self.floor, self.floor_executor = A(2), A(80), A(81)
        self.floor_provider, self.floor_recorder = A(86), A(87)
        self.sale_adapter, self.payment_adapter, self.manager = A(88), A(89), A(98)
        for address in (self.floor, self.floor_executor, self.floor_provider, self.floor_recorder,
                self.sale_adapter, self.payment_adapter, self.manager):
            self.codes[address] = b"\x60" + hex_bytes(address, 20)[-1:] + b"\x00"
            self.pins[address] = keccak256(self.codes[address])
        if mode in ("post_selection", "same_block_before", "same_block_after"):
            self.saved = self.append("collection", "granted", block=1, select=False)
            if mode != "same_block_after":
                self._select_original(self.saved, "collection", block=3 if mode == "same_block_before" else 4)
        else:
            self.saved = self.append("collection", "granted", block=4 if mode == "post_publication" else 1)
        if mode == "superseded_before_sale": self.append("collection", "denied", block=2)
        self._floor_history()
        if mode == "same_block_after": self._select_original(self.saved, "collection", block=3)
        self.current_collection = self.append("collection", "denied", block=4)
        self.current_token = self.append("token", "unspecified", block=4)
        self.rights_anchor = deepcopy(self.a)
        common = {key: self.a[key] for key in ("chainId", "core", "collectionId", "blockHash", "blockNumber",
            "timestamp", "stateRoot", "environment", "deploymentEvidenceHash")}
        module = floor if family == "universal" else direct
        self.floor_anchor = {"profile": module.PROFILE, **common, "conservationFloor": self.floor,
            "executor": self.floor_executor, "codePins": [{"address": address, "runtimeHash": self.pins[address]}
                for address in (self.core, self.floor, self.floor_executor, self.floor_recorder)
                + ((self.manager,) if family == "direct" else ())]}

    def _select_original(self, original, kind, *, block):
        subject = self.subject(kind)
        prior = self.selections[kind][-1] if self.selections[kind] else EMPTY_SELECTION
        stamp = int(self.blocks[H(200 + block)]["timestamp"], 16)
        row = (original["recordHash"], prior[0], keccak256(original["payload"]), A(10), 1, 3,
            len(self.selections[kind]) + 1, original["receipt"][4], stamp, 8, A(9), 7, ZERO, ZERO)
        row = (*row[:-1], selection_hash(self.a, subject, row))
        self.selections[kind].append(row)
        original["selectionEvent"] = self.event(block, A(8), [SELECTED_EVENT, H(1), subject, original["recordHash"]],
            (SELECTION,), (row,))
        self.update_heads()

    def _floor_history(self):
        self.add(self.core, "collectionExists(uint256)", ("uint256",), (1,), ("bool",), (True,))
        for host, interface in ((self.core, floor.CORE_INTERFACE), (self.floor, floor.FLOOR_INTERFACE)):
            for value, accepted in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
                self.add(host, "supportsInterface(bytes4)", ("bytes4",), (value,), ("bool",), (accepted,))
        if self.family == "direct":
            self.add(self.floor, "supportsInterface(bytes4)", ("bytes4",), (direct.DIRECT_FLOOR_INTERFACE,), ("bool",), (True,))
        self.add(self.core, "conservationFloor()", (), (), ("address", "bytes32"), (self.floor, self.pins[self.floor]))
        for getter, kind, value in (("core", "address", self.core), ("coreCodeHash", "bytes32", self.pins[self.core]),
                ("governanceAuthority", "address", self.floor_executor), ("executorCodeHash", "bytes32", self.pins[self.floor_executor]),
                ("deploymentChainId", "uint256", 31337)):
            self.add(self.floor, getter + "()", (), (), (kind,), (value,))
        self.hash_anchor = {"chainId": "31337", "core": self.core, "conservationFloor": self.floor}
        empty = floor.empty_head(self.hash_anchor); head = empty
        self._action("floor-binding", 0, self.core,
            lambda action: [floor.BOUND_EVENT, self.topic("address", self.floor), action],
            ("uint16", "bytes32"), lambda _action: (1, self.pins[self.floor]))
        count = 0 if self.mode == "empty" else 1
        if count:
            stamp = int(self.blocks[H(202)]["timestamp"], 16)
            row = (self.a["host"], K("different saved Metadata runtime") if self.mode == "wrong_metadata_code" else self.pins[self.a["host"]],
                self.floor_provider, self.pins[self.floor_provider], K("synthetic floor source configuration"), 0, stamp,
                K("native-conservation-floor-source-action"))
            head = floor.next_head(empty, 1, row)
            self._action("floor-source", 2, self.floor,
                lambda _action: [floor.ADDED_EVENT, self.topic("uint64", 1), self.topic("address", row[0]), self.topic("address", row[2])],
                ("bytes32", floor.SOURCE, "uint16"), lambda _action: (head, row, 1))
            self.add(self.floor, "sourceAt(uint64)", ("uint64",), (1,), (floor.SOURCE,), (row,))
            self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (1,), ("bytes32",), (head,))
        self.add(self.floor, "sourceSetHead()", (), (), ("uint64", "bytes32"), (count, head))
        self.add(self.floor, "sourceCount()", (), (), ("uint64",), (count,))
        self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (0,), ("bytes32",), (empty,))
        if not count:
            self.add(self.floor, "firstSale(uint256)", ("uint256",), (1,), (floor.FIRST,), (_zero(floor.FIRST),))
            self.first = None
            return
        self._paid(head)

    def _paid(self, source_head):
        stamp = int(self.blocks[H(203)]["timestamp"], 16)
        key = direct.direct_key(self._direct_bindings(), self.floor_recorder, K("direct authorization")) if self.family == "direct" else \
            keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32"),
                (floor.KEY_DOMAIN, 31337, self.floor_recorder, self.sale_adapter, K("floor execution"))))
        tier = floor.WAIVED if self.mode == "waived" else next(k for k, label in floor.TIERS.items() if label == "MUSEUM_GRADE_LITE")
        saved_hash = K("not in retained RIGHTS history") if self.mode == "unmatched" else self.saved["recordHash"]
        facts = (ZERO,) * 7 + (False,) if self.mode == "waived" else (ZERO,) * 5 + (saved_hash, ZERO, True)
        first = (ZERO, 1, tier, self.floor_recorder, key, stamp, 0 if self.mode == "waived" else 1, source_head, facts)
        self.first = first = (floor.receipt_hash(self.hash_anchor, floor.FIRST_DOMAIN, floor.FIRST, first), *first[1:])
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (1,), (floor.FIRST,), (first,))
        self.event(3, self.floor, [floor.FIRST_EVENT, self.topic("uint256", 1), first[0]], (floor.FIRST, "uint16"), (first, 1))
        release_hash = ZERO
        if self.mode != "waived":
            context = (K("scope"), K("membership"), K("media inventory"), ZERO, K("source context"), False)
            release_key = floor.release_key(self.hash_anchor, 1, context)
            release = (ZERO, release_key, 1, tier, self.floor_recorder, key, stamp, 1, source_head,
                context, (context[4], K("media evidence"), ZERO))
            release = (floor.receipt_hash(self.hash_anchor, floor.RELEASE_DOMAIN, floor.RELEASE, release), *release[1:])
            release_hash = release[0]
            self.add(self.floor, "releaseFloorReceipt(bytes32)", ("bytes32",), (release_key,), (floor.RELEASE,), (release,))
            self.event(3, self.floor, [floor.RELEASE_EVENT, release_key, release_hash], (floor.RELEASE, "uint16"), (release, 1))
        if self.family == "direct": self._direct_paid(key, stamp, tier, first[0], release_hash)
        else: self._universal_paid(key, stamp, tier, first[0], release_hash)

    def _universal_paid(self, key, stamp, tier, first_hash, release_hash):
        profile, wallet, asset, payer = K("profile"), A(92), A(93), A(94)
        operation_root, operation_id = K("operation root"), K("operation id")
        expected, current, bound = K("expected policy"), K("current policy"), K("bound policy")
        assignment, template, settlement_id = K("assignment"), K("template"), K("settlement id")
        sale = (settlement_id, floor.PRIMARY, 1, 1, 0, 1, payer, A(95), A(96), 1003, expected)
        result = (K("candidate commitment"), key, profile, wallet, asset, 1003, self.floor_executor,
            K("floor execution"), False, operation_root, current, bound)
        row = (ZERO, self.floor_recorder, self.pins[self.floor_recorder], key, K("candidate payload"), result[0],
            keccak256(encode((floor.RESULT,), (result,))), 1, 0, tier, first_hash, release_hash, stamp)
        row = (floor.receipt_hash(self.hash_anchor, floor.SETTLEMENT_DOMAIN, floor.SETTLEMENT, row), *row[1:])
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (key,), (floor.SETTLEMENT,), (row,))
        self.add(self.floor_recorder, "settlementConsumed(bytes32)", ("bytes32",), (key,), ("bool",), (True,))
        self.add(self.floor_recorder, "settlementResult(bytes32)", ("bytes32",), (key,), (floor.RESULT,), (result,))
        self.event(3, self.floor, [floor.SETTLEMENT_EVENT, key, row[0]], (floor.SETTLEMENT, "uint16"), (row, 1))
        self.event(3, self.floor_recorder, [floor.SETTLED_EVENT, key, floor.PRIMARY, profile], floor.SETTLED_DATA,
            (1, wallet, asset, payer, 1003, keccak256(encode((floor.SALE,), (sale,))), False, 2))
        self.event(3, self.floor_recorder, [floor.CONTEXT_EVENT, key, floor.PRIMARY, profile], floor.CONTEXT_DATA,
            (1, self.sale_adapter, settlement_id, 1, 1, 0, operation_root, operation_id, 1, sale[7], sale[8], template))
        self.event(3, self.floor_recorder, [floor.POLICY_EVENT, key, floor.PRIMARY, profile], floor.POLICY_DATA,
            (1, expected, sale[10], assignment, template))
        self.event(3, self.floor_recorder, [floor.EXECUTION_EVENT, key, self.topic("address", self.sale_adapter), result[7]],
            floor.EXECUTION_DATA, (1, self.floor_executor, self.payment_adapter, result[0], current, bound))

    def _direct_bindings(self):
        return (self.core, self.pins[self.core], self.manager, self.pins[self.manager], 31337, direct.NATIVE)

    def _direct_paid(self, key, stamp, tier, first_hash, release_hash):
        bindings = self._direct_bindings(); authorization = K("direct authorization")
        sale = (K("original authorization digest"), 1, 41, K("operation root"), K("operation id"),
            K("bound mint policy"), K("primary policy"), K("profile"), A(92), stamp, False, A(94), 1, A(96), ZERO_ADDRESS, 1003)
        original_hash = direct.original_hash(bindings, self.floor_recorder, authorization, sale)
        row = (ZERO, self.floor_recorder, self.pins[self.floor_recorder], key, authorization, original_hash,
            bindings, sale, tier, first_hash, release_hash, stamp)
        row = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, row), *row[1:])
        self.add(self.floor, "directPrimarySaleFloorReceipt(bytes32)", ("bytes32",), (key,), (direct.DIRECT,), (row,))
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (key,), (floor.SETTLEMENT,), (_zero(floor.SETTLEMENT),))
        for interface, accepted in ((direct.DIRECT_SALE_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self.add(self.floor_recorder, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (accepted,))
        self.add(self.floor_recorder, "directPrimaryBindings()", (), (), (direct.BINDINGS,), (bindings,))
        self.add(self.floor_recorder, "directPrimarySaleReceipt(bytes32)", ("bytes32",), (authorization,), (direct.SALE,), (sale,))
        self.add(self.floor_recorder, "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), (authorization,), ("bytes32",), (original_hash,))
        self.add(self.manager, "core()", (), (), ("address",), (self.core,))
        for getter, value in (("isOperationRootUsed", sale[3]), ("isAuthorizationUsed", authorization)):
            self.add(self.manager, getter + "(bytes32)", ("bytes32",), (value,), ("bool",), (True,))
        self.event(3, self.floor, [direct.DIRECT_EVENT, key, row[0]], (direct.DIRECT, "uint16"), (row, 1))
        self.event(3, self.floor_recorder, [direct.ORIGINAL_EVENT, authorization, original_hash, self.topic("uint256", 41)],
            (direct.SALE, "uint16"), (sale, 1))

    def sources(self):
        constructor = floor.PublicConservationFloorSource if self.family == "universal" else direct.PublicDirectConservationSource
        return {"rights": rights.PublicRightsSource(dumps(self.rights_anchor), self),
            "floor": constructor(dumps(self.floor_anchor), self)}

    def captures(self):
        return {name: self.capture(name) for name in ("rights", "floor")}

    def capture(self, name):
        adapter = self.sources()[name]
        adapter.snapshot(); transcript = adapter.transcript()
        args = (adapter.anchor_bytes, keccak256(adapter.anchor_bytes),
            rights.PROFILE_HASH if name == "rights" else floor.PROFILE_HASH if self.family == "universal" else direct.PROFILE_HASH,
            transcript, keccak256(transcript))
        kwargs = {"provenance": "synthetic_fixture", "disclosure": "public"}
        return rights_capture.replay("rights", *args, **kwargs) if name == "rights" else \
            (floor_capture if self.family == "universal" else direct_capture).replay(*args, **kwargs)

    def compose(self):
        captures = self.captures()
        return composer.compose(dict(captures["floor"].files), captures["floor"].manifest_hash,
            dict(captures["rights"].files), captures["rights"].manifest_hash, disclosure="public")


class ConservationRightsTests(unittest.TestCase):
    @staticmethod
    def join(floor_capture, rights_capture, **kwargs):
        return composer.compose(dict(floor_capture.files), floor_capture.manifest_hash,
            dict(rights_capture.files), rights_capture.manifest_hash, disclosure=kwargs.get("disclosure", "public"))

    @staticmethod
    def repin(files):
        files = dict(files)
        manifest = loads(files["manifest.json"], maximum=32 * 1024 * 1024)
        manifest["files"] = [composer.base._ref(path, raw) for path, raw in sorted(files.items()) if path != "manifest.json"]
        files["manifest.json"] = dumps(manifest)
        return files, keccak256(files["manifest.json"])

    def test_concrete_sources_share_headers_receipts_core_and_closed_replay(self):
        fixture = ConservationRightsFixture()
        sources = fixture.sources()
        snapshots = {name: loads(adapter.snapshot(), maximum=32 * 1024 * 1024) for name, adapter in sources.items()}
        self.assertEqual(snapshots["floor"]["floor"]["firstSale"]["receipt"][8][5], fixture.saved["recordHash"])
        self.assertNotEqual(snapshots["rights"]["scopes"]["collection"]["current"][0], fixture.saved["recordHash"])
        self.assertEqual(len(snapshots["rights"]["scopes"]["collection"]["history"]), 2)
        with patch("socket.socket", side_effect=AssertionError("synthetic offline replay only")):
            result = fixture.compose()
            replay = composer.verify(dict(result.files), result.manifest_hash)
        self.assertEqual(replay.files, result.files)
        self.assertEqual(result.report["historicalRights"]["status"], "original_record_joined")
        historical = result.report["historicalRights"]
        self.assertEqual(historical["savedRecordHash"], fixture.saved["recordHash"])
        self.assertEqual(historical["selectionAtFirstSale"]["selection"][0], fixture.saved["recordHash"])
        self.assertTrue(historical["observedSelectedHeadMatchesSavedRecord"])
        self.assertEqual(historical["currentAtAnchor"]["collection"][0], fixture.current_collection["recordHash"])
        self.assertEqual(historical["currentAtAnchor"]["token"][0], fixture.current_token["recordHash"])
        self.assertEqual(dict(result.files)[historical["originalPayloadPath"]], fixture.saved["payload"])
        self.assertIn(historical["originalRecordPath"], dict(result.files))
        self.assertEqual(historical["providerBinding"]["status"], "original_conservation_provider_configuration_not_supplied")

    def test_native_direct_receipts_join_without_universal_aliases(self):
        fixture = ConservationRightsFixture(family="direct", burned=True)
        result = fixture.compose()
        self.assertEqual(result.report["historicalRights"]["status"], "original_record_joined")
        retained = dict(result.files)
        snapshot = loads(retained["captures/floor/source/snapshot.json"], maximum=32 * 1024 * 1024)
        self.assertEqual(len(snapshot["floor"]["directSales"]), 1)
        self.assertNotIn("settlements", snapshot["floor"])

    def test_explicit_partial_and_not_required_statuses(self):
        expected = {"empty": "no_native_receipt", "waived": "not_required_by_native_waived_floor",
            "unmatched": "saved_record_not_in_collection_history", "post_publication": "original_publication_not_before_first_sale",
            "post_selection": "selection_not_before_first_sale", "wrong_metadata_code": "original_metadata_differs"}
        for mode, status in expected.items():
            with self.subTest(mode=mode):
                self.assertEqual(ConservationRightsFixture(mode=mode).compose().report["historicalRights"]["status"], status)

    def test_superseded_before_sale_retains_original_without_currentness_promotion(self):
        fixture = ConservationRightsFixture(mode="superseded_before_sale")
        result = fixture.compose(); historical = result.report["historicalRights"]
        self.assertEqual(historical["status"], "original_record_joined_but_superseded")
        self.assertFalse(historical["observedSelectedHeadMatchesSavedRecord"])
        self.assertEqual(historical["originalRecord"]["recordHash"], fixture.saved["recordHash"])
        self.assertEqual(len(historical["matchingSelections"]), 1)
        self.assertEqual(historical["selectionAtFirstSale"]["selection"][0], fixture.rows[1]["recordHash"])
        self.assertEqual(dict(result.files)[historical["originalPayloadPath"]], fixture.saved["payload"])
        self.assertEqual(result.report["items"][6]["status"], "derived_within_source_profile")

    def test_same_block_selection_boundary_uses_transaction_and_log_order(self):
        for mode in ("same_block_before", "same_block_after"):
            for separate_transactions in (False, True):
                with self.subTest(mode=mode, separate_transactions=separate_transactions):
                    fixture = ConservationRightsFixture(mode=mode)
                    selection = fixture.saved["selectionEvent"]
                    receipt = fixture.receipts[H(403)]
                    first_event = next(log for log in receipt["logs"] if log["topics"][0] == floor.FIRST_EVENT)
                    if separate_transactions:
                        # Keep the block-wide log order; separate the selection and complete paid flow
                        # into two successful native receipts, without editing any signed/hash fields.
                        cut = 1 if mode == "same_block_before" else len(receipt["logs"]) - 1
                        second = {**receipt, "transactionHash": H(603), "transactionIndex": "0x1",
                            "logs": receipt["logs"][cut:]}
                        receipt["logs"] = receipt["logs"][:cut]
                        for log in second["logs"]:
                            log.update(transactionHash=H(603), transactionIndex="0x1")
                        fixture.receipts[H(603)] = second
                        fixture.blocks[H(203)]["transactions"] = [H(403), H(603)]
                    self.assertEqual(selection["blockHash"], first_event["blockHash"])
                    self.assertEqual(fixture.selections["collection"][0][8], fixture.first[5])
                    if mode == "same_block_before":
                        self.assertEqual(int(selection["logIndex"], 16) + 1, int(first_event["logIndex"], 16))
                    else:
                        self.assertGreater(int(selection["logIndex"], 16), int(first_event["logIndex"], 16))
                    if separate_transactions:
                        self.assertNotEqual(selection["transactionIndex"], first_event["transactionIndex"])
                    else:
                        self.assertEqual(selection["transactionHash"], first_event["transactionHash"])
                    # Both original capture wrappers replay concrete readers before the composer joins.
                    result = fixture.compose(); historical = result.report["historicalRights"]
                    expected = "original_record_joined" if mode == "same_block_before" else "selection_not_before_first_sale"
                    self.assertEqual(historical["status"], expected)
                    self.assertEqual(len(historical["matchingSelections"]), 1 if mode == "same_block_before" else 0)
                    self.assertEqual(result.report["items"][6]["status"], "derived_within_source_profile")

    def test_all_original_capture_bytes_retained_and_all19_requirements_stay_visible(self):
        fixture = ConservationRightsFixture(); captures = fixture.captures()
        result = self.join(captures["floor"], captures["rights"]); files = dict(result.files)
        for role, capture in captures.items():
            self.assertEqual({path.removeprefix("captures/" + role + "/"): raw for path, raw in files.items()
                if path.startswith("captures/" + role + "/")}, dict(capture.files))
        report = result.report
        self.assertEqual(len(report["items"]), 19)
        self.assertEqual(report["items"][6]["status"], "derived_within_source_profile")
        self.assertEqual(report["items"][12]["status"], "partial")
        self.assertFalse(report["canonicalPacketReady"])
        for claim in ("actualChainAcceptance", "rightsLegalTruthProven", "personhoodProven", "archiveDeliveryProven",
                "historicalConservationProviderSelectorBindingProven", "completeCanonicalPacket"):
            self.assertFalse(report["claims"][claim], claim)
        with self.assertRaisesRegex(MuseumError, "complete canonical packet unavailable"):
            composer.complete_packet(files, result.manifest_hash)

    def test_external_input_pins_and_rehashed_fabricated_snapshot_reject(self):
        captures = ConservationRightsFixture().captures()
        ff, rf = dict(captures["floor"].files), dict(captures["rights"].files)
        with self.assertRaisesRegex(MuseumError, "external input manifest pin"):
            composer.compose(ff, H(999), rf, captures["rights"].manifest_hash, disclosure="public")
        snapshot = loads(rf["source/snapshot.json"], maximum=32 * 1024 * 1024)
        snapshot["effectiveGrants"][next(iter(snapshot["effectiveGrants"]))] = "granted"
        rf["source/snapshot.json"] = dumps(snapshot)
        rf, digest = self.repin(rf)
        with self.assertRaises(MuseumError):
            composer.compose(ff, captures["floor"].manifest_hash, rf, digest, disclosure="public")

    def test_rehashed_assembly_semantic_tamper_and_extra_file_reject(self):
        result = ConservationRightsFixture().compose()
        for mode in ("status", "provider-authority", "extra"):
            files = dict(result.files)
            if mode == "extra": files["documentary/caller-complete.json"] = dumps({"complete": True})
            else:
                historical = loads(files["documentary/historical-rights.json"], maximum=32 * 1024 * 1024)
                if mode == "status": historical["status"] = "original_record_joined_but_superseded"
                else: historical["providerBinding"]["status"] = "verified"
                files["documentary/historical-rights.json"] = dumps(historical)
            files, digest = self.repin(files)
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "reconstruction differs"):
                composer.verify(files, digest)

    def test_independently_replayed_common_anchor_and_runtime_conflicts_reject(self):
        right = ConservationRightsFixture().capture("rights")
        for mode in ("environment", "deployment", "core-runtime"):
            fixture = ConservationRightsFixture()
            if mode == "environment": fixture.floor_anchor["environment"] = "local_evm_fixture"
            elif mode == "deployment": fixture.floor_anchor["deploymentEvidenceHash"] = K("different deployment")
            else:
                fixture.codes[fixture.core] = b"independently admitted different Core runtime"
                changed = keccak256(fixture.codes[fixture.core])
                next(pin for pin in fixture.floor_anchor["codePins"] if pin["address"] == fixture.core)["runtimeHash"] = changed
                fixture.add(fixture.floor, "coreCodeHash()", (), (), ("bytes32",), (changed,))
            left = fixture.capture("floor")  # Concrete source replay succeeds first.
            with self.subTest(mode=mode), self.assertRaisesRegex(MuseumError, "common anchor differs|runtime pin differs"):
                self.join(left, right)

    def test_complete_shared_receipt_conflict_rejects_even_for_unrelated_added_log(self):
        right_fixture = ConservationRightsFixture(mode="superseded_before_sale")
        right = right_fixture.capture("rights")
        left_fixture = ConservationRightsFixture(mode="superseded_before_sale")
        left_fixture.event(2, A(99), [K("unrelated additional native event")], (), ())
        left = left_fixture.capture("floor")
        with self.assertRaisesRegex(MuseumError, "repeated RPC outcome differs|repeated receipt differs"):
            self.join(left, right)

    def test_public_disclosure_precedes_input_and_cli_reads(self):
        class Unreadable:
            def __iter__(self): raise AssertionError("input was inspected before disclosure")
        with self.assertRaisesRegex(MuseumError, "public disclosure"):
            composer.compose(Unreadable(), H(1), Unreadable(), H(2), disclosure="restricted")
        with patch.object(composer, "read_tree", side_effect=AssertionError("filesystem read before disclosure")):
            with self.assertRaisesRegex(MuseumError, "public disclosure"):
                composer.main(["assemble", "--floor", "unused-floor", "--floor-hash", H(1),
                    "--rights", "unused-rights", "--rights-hash", H(2), "--disclosure", "restricted", "--output", "unused-output"])


if __name__ == "__main__": unittest.main()
