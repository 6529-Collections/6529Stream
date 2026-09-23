"""Synthetic original DIRECT receipts and public replay; no actual-chain acceptance."""
from copy import deepcopy
import unittest
from unittest.mock import patch

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS, json_values
from .public_history_rpc import PublicReplayTransport, PublicRpcTransport
from . import public_conservation_floor_source as f
from . import public_direct_conservation_source as source
from .test_public_conservation_floor_source import PublicConservationFloorFixture, CHAIN, COLLECTION, FOREIGN, LITE, _zero
from .test_owner_catalog_source import A, H


class PublicDirectConservationFixture(PublicConservationFloorFixture):
    """Exact original receipt/getter/event mechanics on one synthetic history."""

    def __init__(self, *, mode="paid_inline", product=None, burned=False):
        if mode not in ("paid_inline", "empty", "waived", "reused_release", "foreign", "target_universal", "mixed"):
            raise ValueError("unsupported synthetic DIRECT mode")
        super().__init__(mode="empty")
        self.mode, self.product, self.burned = mode, product or source.NATIVE, burned
        self.adapter1, self.adapter2, self.manager, self.asset = A(70), A(71), A(75), A(76)
        self.direct_rows, self.original_rows = [], []
        for address in (self.adapter1, self.adapter2, self.manager, self.asset):
            self.codes[address] = b"\x60" + hex_bytes(address, 20)[-1:] + b"\x00"
        self._call(self.floor, "supportsInterface(bytes4)", ("bool",), (True,), ("bytes4",), (source.DIRECT_FLOOR_INTERFACE,))
        self._call(self.manager, "core()", ("address",), (self.core,))
        if mode not in ("empty", "foreign", "target_universal"):
            self.append_direct("first", block=4, source_id=0 if mode == "waived" else 1,
                tier=f.WAIVED if mode == "waived" else LITE, release_number=None if mode == "waived" else 1)
            if mode != "waived":
                self.append_direct("second", block=7, source_id=2, adapter=self.adapter2, include_first=False,
                    release_number=None if mode == "reused_release" else 2,
                    reused_release=self.release_rows[0] if mode == "reused_release" else None)
        if mode not in ("empty", "waived", "target_universal", "mixed"):
            self._paid("foreign-universal", FOREIGN, 8, self.foreign_recorder, self.foreign_sale,
                self.foreign_payment, source_id=0, tier=f.WAIVED, release_number=None)
            self.append_direct("foreign-direct", cid=FOREIGN + 1, block=9, source_id=0,
                tier=f.WAIVED, release_number=None, adapter=A(72))
        if mode in ("target_universal", "mixed"):
            self._paid("target-universal", COLLECTION, 8, self.recorder1, self.sale1,
                self.payment1, source_id=1, release_number=None,
                include_first=mode == "target_universal", reused_release=self.release_rows[0] if self.release_rows else None)
        self.a["profile"] = source.PROFILE
        self.a["codePins"] = [{"address": address, "runtimeHash": keccak256(code)}
            for address, code in sorted(self.codes.items())]

    def original_hash(self, bindings, adapter, authorization_id, sale):
        return keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", source.SALE),
            (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), bindings[4], bindings[0], adapter,
             bindings[5], authorization_id, sale)))

    def direct_hash(self, row):
        return keccak256(encode(("bytes32", "uint256", "address", "address", source.DIRECT),
            (schema_id("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"), CHAIN, self.core, self.floor,
             (ZERO, *row[1:]))))

    def append_direct(self, label, *, block, source_id, cid=COLLECTION, tier=LITE,
            release_number=1, include_first=True, reused_release=None, adapter=None, created_at=None):
        adapter = adapter or self.adapter1
        self.codes.setdefault(adapter, b"\x60" + hex_bytes(adapter, 20)[-1:] + b"\x00")
        authorization_id = H("direct-authorization-" + label)
        bindings = (self.core, keccak256(self.codes[self.core]), self.manager,
            keccak256(self.codes[self.manager]), CHAIN, self.product)
        key = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32"),
            (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), CHAIN, self.core, adapter, self.product, authorization_id)))
        stamp = 3000 + block
        if created_at is None: created_at = stamp - 2 if self.product == source.AUCTION else stamp
        token = 100 + block
        sale = (H(label + "-authorization-digest"), cid, token, H(label + "-operation-root"),
            H(label + "-operation-id"), H(label + "-bound-mint-policy"), H(label + "-primary-policy"),
            H(label + "-profile"), A(60), created_at, False, A(62), 1, A(64),
            self.asset if self.product == source.ERC20 else ZERO_ADDRESS, 1000 + block)
        original_hash = self.original_hash(bindings, adapter, authorization_id, sale)
        first = self._first_row(cid, adapter, key, block, source_id, tier) if include_first else None
        if first: self.first_rows.append(first)
        release = self._release_row(cid, adapter, key, block, source_id, release_number) if release_number is not None else None
        if release: self.release_rows.append(release)
        first_hash = first[0] if first else next(row[0] for row in self.first_rows if row[1] == cid)
        release_hash = release[0] if release else reused_release[0] if reused_release else ZERO
        row = (ZERO, adapter, keccak256(self.codes[adapter]), key, authorization_id, original_hash,
            bindings, sale, tier, first_hash, release_hash, stamp)
        row = (self.direct_hash(row), *row[1:])
        self.direct_rows.append(row)
        logs = []
        if first:
            logs.append((self.floor, [f.FIRST_EVENT, self.topic("uint256", cid), first[0]],
                encode((f.FIRST, "uint16"), (first, 1))))
        if release:
            logs.append((self.floor, [f.RELEASE_EVENT, release[1], release[0]],
                encode((f.RELEASE, "uint16"), (release, 1))))
        logs.extend([(self.floor, [source.DIRECT_EVENT, key, row[0]], encode((source.DIRECT, "uint16"), (row, 1))),
            (adapter, [source.ORIGINAL_EVENT, authorization_id, original_hash, self.topic("uint256", token)],
                encode((source.SALE, "uint16"), (sale, 1)))])
        receipt = self._transaction(block, "direct-" + label, logs)
        context = {"row": row, "bindings": bindings, "sale": sale, "adapter": adapter,
            "authorizationId": authorization_id, "key": key, "receipt": receipt, "first": first, "release": release}
        self.original_rows.append(context)
        self._original_calls(context)
        if first:
            self._call(self.floor, "firstSale(uint256)", (f.FIRST,), (first,), ("uint256",), (cid,))
        if release:
            self._call(self.floor, "releaseFloorReceipt(bytes32)", (f.RELEASE,), (release,), ("bytes32",), (release[1],))
        return context

    def _original_calls(self, context):
        row, sale, bindings, adapter = (context[k] for k in ("row", "sale", "bindings", "adapter"))
        authorization_id, key = context["authorizationId"], context["key"]
        for interface, value in ((source.DIRECT_SALE_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self._call(adapter, "supportsInterface(bytes4)", ("bool",), (value,), ("bytes4",), (interface,))
        self._call(adapter, "directPrimaryBindings()", (source.BINDINGS,), (bindings,))
        self._call(adapter, "directPrimarySaleReceipt(bytes32)", (source.SALE,), (sale,), ("bytes32",), (authorization_id,))
        self._call(adapter, "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), (row[5],), ("bytes32",), (authorization_id,))
        self._call(self.floor, "directPrimarySaleFloorReceipt(bytes32)", (source.DIRECT,), (row,), ("bytes32",), (key,))
        self._call(self.floor, "settlementReceipt(bytes32)", (f.SETTLEMENT,), (_zero(f.SETTLEMENT),), ("bytes32",), (key,))
        for signature, argument in (("isOperationRootUsed(bytes32)", sale[3]), ("isAuthorizationUsed(bytes32)", authorization_id)):
            self._call(self.manager, signature, ("bool",), (True,), ("bytes32",), (argument,))
        self._call(self.core, "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
            (True, sale[1], sale[2], self.burned), ("uint256",), (sale[2],))
        self._call(self.core, "tokenLifecycle(uint256)", ("uint8",), (3 if self.burned else 2,), ("uint256",), (sale[2],))

    def replace_sale(self, index, field, value):
        """Coherently rehash both retained receipts and their original events."""
        context = self.original_rows[index]; sale = list(context["sale"]); sale[field] = value
        sale = tuple(sale); old = context["row"]
        original_hash = self.original_hash(context["bindings"], context["adapter"], context["authorizationId"], sale)
        row = (*old[:5], original_hash, old[6], sale, *old[8:])
        row = (self.direct_hash(row), *row[1:])
        context.update(row=row, sale=sale); self.direct_rows[index] = row
        for log in context["receipt"]["logs"]:
            if log["topics"][0] == source.DIRECT_EVENT:
                log["topics"][2] = row[0]; log["data"] = "0x" + encode((source.DIRECT, "uint16"), (row, 1)).hex()
            elif log["topics"][0] == source.ORIGINAL_EVENT:
                log["topics"][2] = original_hash; log["topics"][3] = self.topic("uint256", sale[2])
                log["data"] = "0x" + encode((source.SALE, "uint16"), (sale, 1)).hex()
        self._original_calls(context)

    def source(self, **kwargs):
        return source.PublicDirectConservationSource(dumps(self.a), self, **kwargs)

    def result(self):
        return loads(self.source().snapshot(), maximum=source.MAX_OUTPUT)


class PublicDirectConservationSourceTests(unittest.TestCase):
    def test_original_interface_tuple_and_event_constants_match_frozen_native_preimages(self):
        bindings = ("address", "bytes32", "address", "bytes32", "uint256", "bytes32")
        sale = ("bytes32", "uint256", "uint256", "bytes32", "bytes32", "bytes32", "bytes32", "bytes32",
            "address", "uint64", "bool", "address", "uint64", "address", "address", "uint256")
        direct = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", bindings, sale,
            "bytes32", "bytes32", "bytes32", "uint64")
        self.assertEqual(source.BINDINGS, bindings); self.assertEqual(source.SALE, sale); self.assertEqual(source.DIRECT, direct)
        interface = 0
        for signature in ("directPrimaryBindings()", "directPrimarySaleReceipt(bytes32)", "directPrimarySaleReceiptHash(bytes32)"):
            interface ^= int(keccak256(signature.encode())[2:10], 16)
        self.assertEqual(source.DIRECT_SALE_INTERFACE, f"0x{interface:08x}")
        self.assertEqual(source.DIRECT_SALE_INTERFACE, "0xf9f99b4b")
        self.assertEqual(source.ORIGINAL_EVENT, "0x9c7bcb925439c167a29c00d9c54e1d8539a47186017d6d98f0927615b0f82493")
        self.assertEqual(source.DIRECT_EVENT, "0x4e702e93215586c9ac01e0be1f25c29f03f7af11d593a09f13a3e50ae209937f")
        self.assertEqual(len(encode((source.SALE,), (_zero(source.SALE),))), 512)
        self.assertEqual(len(encode((source.BINDINGS,), (_zero(source.BINDINGS),))), 192)

    def test_native_erc20_auction_exact_original_receipts_and_replacement_sources(self):
        for product in (source.NATIVE, source.ERC20, source.AUCTION):
            fixture = PublicDirectConservationFixture(product=product)
            result = fixture.result()
            self.assertEqual(result["floor"]["status"], "present")
            self.assertEqual(len(result["floor"]["directSales"]), 2)
            self.assertEqual(len(result["floor"]["releases"]), 2)
            self.assertEqual(result["catalogue"]["count"], "2")
            self.assertNotIn("settlements", result["floor"])
            for observed, original in zip(result["floor"]["directSales"], fixture.direct_rows):
                self.assertEqual(observed["receipt"], json_values(original))
                self.assertEqual(original[6][5], product)
            if product == source.AUCTION:
                self.assertLess(fixture.direct_rows[0][7][9], fixture.direct_rows[0][11])

    def test_empty_waived_and_reused_release_have_exact_scoped_meanings(self):
        self.assertEqual(PublicDirectConservationFixture(mode="empty").result()["floor"],
            {"status": "none_recorded", "firstSale": None, "releases": [], "directSales": []})
        waived = PublicDirectConservationFixture(mode="waived").result()["floor"]
        self.assertEqual(waived["firstSale"]["effectiveTier"], "CONSERVATION_WAIVED")
        self.assertEqual(waived["releases"], [])
        reused = PublicDirectConservationFixture(mode="reused_release").result()["floor"]
        self.assertEqual(len(reused["directSales"]), 2); self.assertEqual(len(reused["releases"]), 1)
        self.assertEqual({row["receipt"][10] for row in reused["directSales"]}, {reused["releases"][0]["receiptHash"]})

    def test_foreign_both_family_denominator_is_retained_but_target_universal_fails(self):
        fixture = PublicDirectConservationFixture(mode="foreign")
        observed = fixture.result()
        self.assertEqual(observed["floor"]["status"], "none_recorded")
        self.assertTrue(any(row["topics"][0] == f.SETTLEMENT_EVENT for receipt in fixture.receipts.values() for row in receipt["logs"]))
        self.assertTrue(any(row["topics"][0] == source.DIRECT_EVENT for receipt in fixture.receipts.values() for row in receipt["logs"]))
        coverage = observed["historyCoverage"]
        self.assertEqual(coverage["targetReceiptEventCount"], "0")
        self.assertEqual(coverage["ledgerReceiptEventCount"], "4")
        self.assertEqual({row["kind"] for row in coverage["ledgerReceiptEvents"]}, {"first_sale", "settlement", "direct"})
        universal = next(row["receipt"] for row in coverage["ledgerReceiptEvents"] if row["kind"] == "settlement")
        direct = next(row["receipt"] for row in coverage["ledgerReceiptEvents"] if row["kind"] == "direct")
        self.assertEqual(universal[7], str(FOREIGN)); self.assertEqual(direct[7][1], str(FOREIGN + 1))
        for mode in ("target_universal", "mixed"):
            with self.subTest(mode=mode), self.assertRaises(MuseumError):
                PublicDirectConservationFixture(mode=mode).source().snapshot()

    def test_getters_pins_original_identity_and_used_flags_fail_closed(self):
        for mode in ("local-sale", "local-hash", "local-bindings", "floor-getter", "universal-alias", "manager-core",
                "used-root", "used-authorization", "interface", "runtime", "missing-manager-pin"):
            fixture = PublicDirectConservationFixture(product=source.ERC20)
            original = fixture.original_rows[0]; row, sale = original["row"], original["sale"]
            if mode == "local-sale":
                fixture._call(row[1], "directPrimarySaleReceipt(bytes32)", (source.SALE,), (_zero(source.SALE),), ("bytes32",), (row[4],))
            elif mode == "local-hash":
                fixture._call(row[1], "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), (H("incorrect-original"),), ("bytes32",), (row[4],))
            elif mode == "local-bindings":
                binding = list(row[6]); binding[0] = A(999)
                fixture._call(row[1], "directPrimaryBindings()", (source.BINDINGS,), (tuple(binding),))
            elif mode == "floor-getter":
                fixture._call(fixture.floor, "directPrimarySaleFloorReceipt(bytes32)", (source.DIRECT,), (_zero(source.DIRECT),), ("bytes32",), (row[3],))
            elif mode == "universal-alias":
                alias = (H("universal-alias"), *_zero(f.SETTLEMENT)[1:])
                fixture._call(fixture.floor, "settlementReceipt(bytes32)", (f.SETTLEMENT,), (alias,), ("bytes32",), (row[3],))
            elif mode == "manager-core": fixture._call(fixture.manager, "core()", ("address",), (A(999),))
            elif mode == "used-root":
                fixture._call(fixture.manager, "isOperationRootUsed(bytes32)", ("bool",), (False,), ("bytes32",), (sale[3],))
            elif mode == "used-authorization":
                fixture._call(fixture.manager, "isAuthorizationUsed(bytes32)", ("bool",), (False,), ("bytes32",), (row[4],))
            elif mode == "interface":
                fixture._call(row[1], "supportsInterface(bytes4)", ("bool",), (False,), ("bytes4",), (source.DIRECT_SALE_INTERFACE,))
            elif mode == "runtime": fixture.codes[row[1]] = b"different actual runtime"
            else:
                fixture.a["codePins"] = [pin for pin in fixture.a["codePins"] if pin["address"] != fixture.manager]
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_coherently_rehashed_invalid_original_paid_fields_and_creation_times_reject(self):
        for field, value in ((0, ZERO), (2, 0), (3, ZERO), (4, ZERO), (9, 0), (9, 4000), (11, ZERO_ADDRESS),
                (9, 3002), (12, 0), (13, ZERO_ADDRESS), (14, A(76)), (15, 0)):
            fixture = PublicDirectConservationFixture()
            fixture.replace_sale(0, field, value)
            with self.subTest(field=field, value=value), self.assertRaises(MuseumError): fixture.source().snapshot()
        fixture = PublicDirectConservationFixture(product=source.ERC20)
        fixture.replace_sale(0, 14, ZERO_ADDRESS)
        with self.assertRaisesRegex(MuseumError, "original paid fields differ"): fixture.source().snapshot()

    def test_historical_erc20_asset_has_no_current_code_admission_requirement(self):
        for code in (b"", b"different current token runtime"):
            fixture = PublicDirectConservationFixture(product=source.ERC20)
            fixture.a["codePins"] = [pin for pin in fixture.a["codePins"] if pin["address"] != fixture.asset]
            fixture.codes[fixture.asset] = code
            result = fixture.result()
            self.assertTrue(all(row["originalSale"]["receipt"][14] == fixture.asset for row in result["floor"]["directSales"]))
            self.assertFalse(any(method == "eth_getCode" and params[0] == fixture.asset for method, params in fixture.requested))
            self.assertTrue(result["claims"]["historicalAssetContractAdmissionTrusted"])
            self.assertFalse(result["claims"]["currentAssetCodeRequired"])

    def test_completed_or_burned_core_identity_remains_distinct_from_current_owner(self):
        for burned in (False, True):
            result = PublicDirectConservationFixture(burned=burned).result()
            self.assertEqual(result["floor"]["status"], "present")
            self.assertTrue(all(row["originalSale"]["tokenIdentity"]["burned"] == burned
                and row["originalSale"]["tokenIdentity"]["lifecycle"] == ("3" if burned else "2")
                for row in result["floor"]["directSales"]))
        for mode in ("wrong-collection", "not-minted", "prepared"):
            fixture = PublicDirectConservationFixture(); token = fixture.direct_rows[0][7][2]
            if mode == "prepared": fixture._call(fixture.core, "tokenLifecycle(uint256)", ("uint8",), (1,), ("uint256",), (token,))
            else:
                identity = (mode != "not-minted", COLLECTION + 1 if mode == "wrong-collection" else COLLECTION, token, False)
                fixture._call(fixture.core, "tokenCollectionIdentity(uint256)", ("bool", "uint256", "uint256", "bool"),
                    identity, ("uint256",), (token,))
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_original_event_must_be_unique_exact_and_immediately_after_floor(self):
        for mode in ("missing", "duplicate", "gap", "altered-sale", "failed"):
            fixture = PublicDirectConservationFixture(); receipt = fixture.original_rows[0]["receipt"]
            original = next(log for log in receipt["logs"] if log["topics"][0] == source.ORIGINAL_EVENT)
            if mode == "missing": receipt["logs"].remove(original)
            elif mode == "duplicate": receipt["logs"].append(deepcopy(original))
            elif mode == "gap":
                gap = deepcopy(original); gap.update(address=fixture.core, topics=[H("unrelated actual event")], data="0x")
                receipt["logs"].insert(receipt["logs"].index(original), gap)
            elif mode == "altered-sale":
                sale, version = decode((source.SALE, "uint16"), hex_bytes(original["data"]))
                original["data"] = "0x" + encode((source.SALE, "uint16"), ((*sale[:-1], sale[-1] + 1), version)).hex()
            else: receipt["status"] = "0x0"
            for index, log in enumerate(receipt["logs"]): log["logIndex"] = hex(index)
            with self.subTest(mode=mode), self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_foreign_hash_tamper_and_target_omission_are_not_ignored(self):
        fixture = PublicDirectConservationFixture(mode="foreign")
        original = fixture.original_rows[-1]
        log = next(log for log in original["receipt"]["logs"] if log["topics"][0] == source.DIRECT_EVENT)
        row = original["row"]; changed = (*row[:5], H("wrong-foreign-original"), *row[6:])
        log["data"] = "0x" + encode((source.DIRECT, "uint16"), (changed, 1)).hex()
        with self.assertRaises(MuseumError): fixture.source().snapshot()
        fixture = PublicDirectConservationFixture()
        row = fixture.original_rows[0]
        log = next(log for log in row["receipt"]["logs"] if log["topics"][0] == source.DIRECT_EVENT)
        log["topics"][0] = H("hidden direct event")
        with self.assertRaises(MuseumError): fixture.source().snapshot()

    def test_no_current_provider_registry_or_owner_reauthorization_calls(self):
        fixture = PublicDirectConservationFixture(); result = fixture.result()
        forbidden = {fixture.metadata1, fixture.provider1, fixture.metadata2, fixture.provider2}
        self.assertFalse(any(method == "eth_call" and params[0]["to"] in forbidden for method, params in fixture.requested))
        owner_selector = calldata("ownerOf(uint256)", ("uint256",), (fixture.direct_rows[0][7][2],))
        self.assertFalse(any(method == "eth_call" and params[0]["data"] == owner_selector for method, params in fixture.requested))
        self.assertFalse(result["claims"]["actualChainAcceptance"])
        self.assertFalse(result["claims"]["completeAcquisitionPacket"])

    def test_new_release_uses_original_admission_position_and_reuse_has_no_new_event(self):
        fixture = PublicDirectConservationFixture()
        context = fixture.original_rows[1]
        release = list(context["release"])
        # Keep source1/head1 coherent, but it is no longer the newest admission at block7.
        release[7:9] = [1, fixture.sources[0][2]]
        release[0] = f.receipt_hash(fixture._hash_anchor(), f.RELEASE_DOMAIN, f.RELEASE, tuple(release))
        release = tuple(release)
        direct = list(context["row"]); direct[10] = release[0]; direct[0] = fixture.direct_hash(tuple(direct))
        direct = tuple(direct); context.update(row=direct, release=release)
        fixture._original_calls(context)
        fixture._call(fixture.floor, "releaseFloorReceipt(bytes32)", (f.RELEASE,), (release,), ("bytes32",), (release[1],))
        for log in context["receipt"]["logs"]:
            if log["topics"][0] == f.RELEASE_EVENT:
                log["topics"][2] = release[0]; log["data"] = "0x" + encode((f.RELEASE, "uint16"), (release, 1)).hex()
            elif log["topics"][0] == source.DIRECT_EVENT:
                log["topics"][2] = direct[0]; log["data"] = "0x" + encode((source.DIRECT, "uint16"), (direct, 1)).hex()
        with self.assertRaisesRegex(MuseumError, "source.*admission|source.*head"):
            fixture.source().snapshot()
        fixture = PublicDirectConservationFixture(mode="reused_release")
        old = next(log for log in fixture.original_rows[0]["receipt"]["logs"] if log["topics"][0] == f.RELEASE_EVENT)
        fixture._transaction(9, "duplicate-release", [(old["address"], old["topics"], hex_bytes(old["data"]))])
        with self.assertRaisesRegex(MuseumError, "duplicate"): fixture.source().snapshot()

    def test_explicit_bounds_and_foreign_dependency_pins_do_not_create_authority(self):
        fixture = PublicDirectConservationFixture()
        required = {fixture.core, fixture.floor, fixture.executor, fixture.adapter1, fixture.adapter2, fixture.manager}
        fixture.a["codePins"] = [pin for pin in fixture.a["codePins"] if pin["address"] in required]
        result = fixture.result()
        self.assertEqual(result["historyCoverage"]["ledgerReceiptEventCount"], "9")
        self.assertFalse(any(method in ("eth_getCode", "eth_call") and
            (params[0] if method == "eth_getCode" else params[0]["to"]) not in required
            for method, params in fixture.requested))
        fixture = PublicDirectConservationFixture()
        with patch.object(source, "MAX_RECEIPTS", 8), self.assertRaisesRegex(MuseumError, "ledger event bound"):
            fixture.source().snapshot()
        fixture = PublicDirectConservationFixture()
        fixture.a["codePins"] = [{"address": A(index + 10000), "runtimeHash": H("pin-" + str(index))}
            for index in range(source.MAX_PINS + 1)]
        with self.assertRaisesRegex(MuseumError, "pin bound"): fixture.source()
        self.assertEqual(fixture.requested, [])

    def test_closed_anchor_old_profile_and_failed_capture_are_not_reused(self):
        for field, value in (("profile", f.PROFILE), ("tokenId", "1"), ("rpcUrl", "https://example.invalid")):
            fixture = PublicDirectConservationFixture(); fixture.a[field] = value
            with self.subTest(field=field), self.assertRaises(MuseumError): fixture.source()
            self.assertEqual(fixture.requested, [])
        fixture = PublicDirectConservationFixture(); adapter = fixture.source()
        fixture.codes[fixture.floor] = b"wrong runtime"
        with self.assertRaises(MuseumError): adapter.snapshot()
        with self.assertRaisesRegex(MuseumError, "cannot resume"): adapter.snapshot()

    def test_exact_socket_denied_replay_and_explicit_synthetic_provenance(self):
        fixture = PublicDirectConservationFixture(); adapter = fixture.source()
        raw, transcript = adapter.snapshot(), adapter.transcript()
        with patch("socket.socket", side_effect=AssertionError("offline replay only")):
            replay = source.PublicDirectConservationSource(adapter.anchor_bytes,
                PublicReplayTransport(transcript, keccak256(transcript)))
            self.assertEqual(replay.snapshot(), raw)
        with self.assertRaises(MuseumError): fixture.source(provenance="trusted_rpc")
        # Exercise exact PublicRpcTransport admission with synthetic responses only.
        transport = PublicRpcTransport("https://example.invalid")
        with patch.object(PublicRpcTransport, "request", side_effect=fixture.request), \
                patch("socket.socket", side_effect=AssertionError("synthetic mechanics only")):
            trusted = source.PublicDirectConservationSource(dumps(fixture.a), transport, provenance="trusted_rpc")
            result = loads(trusted.snapshot(), maximum=source.MAX_OUTPUT)
            self.assertFalse(result["claims"]["actualChainAcceptance"])

    def test_rehashed_replay_cannot_replace_original_adapter_receipt(self):
        fixture = PublicDirectConservationFixture(); adapter = fixture.source(); adapter.snapshot()
        value = loads(adapter.transcript(), maximum=source.MAX_OUTPUT)
        original = fixture.original_rows[0]
        query = calldata("directPrimarySaleReceipt(bytes32)", ("bytes32",), (original["authorizationId"],))
        changed = False
        for row in value["calls"]:
            if row["method"] == "eth_call" and row["params"][0]["data"] == query:
                row["result"] = "0x" + encode((source.SALE,), (_zero(source.SALE),)).hex(); changed = True
        self.assertTrue(changed)
        raw = dumps(value)
        with patch("socket.socket", side_effect=AssertionError("offline replay only")):
            replay = source.PublicDirectConservationSource(adapter.anchor_bytes, PublicReplayTransport(raw, keccak256(raw)))
            with self.assertRaisesRegex(MuseumError, "original adapter getter differs"): replay.snapshot()


if __name__ == "__main__": unittest.main()
