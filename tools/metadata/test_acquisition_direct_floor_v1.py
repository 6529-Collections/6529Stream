"""Synthetic supplied-data DIRECT originals; no network or native execution."""
import copy
import unittest
from unittest.mock import patch

from jsonschema import Draft202012Validator

from . import acquisition_direct_floor_v1 as v1
from . import acquisition_packet_v4 as packet
from tools.museum.canonical import MuseumError, dumps, keccak256, loads, schema_id
from tools.museum.chain_abi import encode
from tools.museum.independent_wire import ZERO, ZERO_ADDRESS, json_values
from tools.museum.test_public_direct_conservation_source import PublicDirectConservationFixture, A, H


def pins(snapshot):
    return {"manifestHash": H("synthetic externally pinned DIRECT capture"), "anchorHash": snapshot["anchorHash"],
        "transcriptHash": snapshot["transcriptHash"], "snapshotHash": keccak256(dumps(snapshot)),
        "sourceProfileHash": v1.source.PROFILE_HASH, "captureProfileHash": v1.capture.PROFILE_HASH}


def project(fixture):
    snapshot = fixture.result()
    return v1.semanticProjection(snapshot, pins(snapshot))


def rehash_sale(value, index=0):
    """Rebuild a supplied DIRECT hash and all copies after changing its native tuple."""
    row = value["floor"]["directSales"][index]; old_hash = row["receiptHash"]
    receipt = v1.native(v1.source.DIRECT, row["receipt"]); b, sale = receipt[6:8]
    updated = list(receipt)
    updated[5] = v1.source.original_hash(b, updated[1], updated[4], sale)
    updated[0] = v1.F.receipt_hash(value["sourceState"], v1.source.DIRECT_DOMAIN, v1.source.DIRECT, tuple(updated))
    row["receipt"] = json_values(tuple(updated)); receipt = tuple(updated)
    for key, val in zip(v1.DIRECT_FIELDS, json_values(receipt[:6])): row[key] = val
    row.update(productKind=b[5], product=v1.source.PRODUCTS[b[5]], collectionId=str(sale[1]), tokenId=str(sale[2]),
        effectiveTier=v1.F.TIERS[receipt[8]], firstSaleReceiptHash=receipt[9], releaseReceiptHash=receipt[10], recordedAt=str(receipt[11]))
    original = row["originalSale"]
    original.update(bindings=json_values(b), receipt=json_values(sale), receiptHash=receipt[5],
        event={"topics": [v1.source.ORIGINAL_EVENT, receipt[4], receipt[5], v1.F._topic("uint256", sale[2])], "data": json_values((sale, 1))})
    for event in value["discovery"]["ledgerReceiptEvents"]:
        if event["kind"] == "direct" and event["receipt"][0] == old_hash: event["receipt"] = copy.deepcopy(row["receipt"])


class AcquisitionDirectFloorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.values = {mode: project(PublicDirectConservationFixture(mode=mode)) for mode in
            ("paid_inline", "empty", "waived", "reused_release", "foreign")}

    def value(self, mode="paid_inline"): return copy.deepcopy(self.values[mode])

    def reject(self, value, message=None):
        with self.assertRaises(MuseumError) as caught: v1.validate(dumps(value))
        if message: self.assertIn(message, str(caught.exception))

    def test_all_products_modes_and_burned_originals_validate_offline(self):
        with patch("socket.socket", side_effect=AssertionError("offline synthetic evidence only")):
            for mode, value in self.values.items():
                with self.subTest(mode=mode): self.assertEqual(v1.validate(dumps(value)), value)
            for product in v1.source.PRODUCTS:
                for burned in (False, True):
                    value = project(PublicDirectConservationFixture(product=product, burned=burned))
                    with self.subTest(product=product, burned=burned):
                        self.assertEqual(value["floor"]["directSales"][0]["productKind"], product)
                        self.assertEqual(value["floor"]["directSales"][0]["originalSale"]["tokenIdentity"]["burned"], burned)

    def test_exact_original_structs_and_source_bytes_are_preserved(self):
        snapshot = PublicDirectConservationFixture().result(); before = copy.deepcopy(snapshot)
        value = v1.semanticProjection(snapshot, pins(snapshot))
        self.assertEqual(snapshot, before)
        for key in ("sourceState", "binding", "catalogue", "floor"): self.assertEqual(value[key], snapshot[key])
        self.assertEqual(value["discovery"]["ledgerReceiptEvents"], snapshot["historyCoverage"]["ledgerReceiptEvents"])
        r = value["floor"]["directSales"][0]["receipt"]
        self.assertEqual((len(r), len(r[6]), len(r[7])), (12, 6, 16))
        self.assertNotIn("settlements", value["floor"])
        self.assertNotIn("authorityClass", value["floor"]["directSales"][0])
        self.assertNotIn("stateRoot", value["sourceState"])

    def test_independent_original_native_hash_preimages(self):
        value = self.value(); state = value["sourceState"]
        row = v1.native(v1.source.DIRECT, value["floor"]["directSales"][0]["receipt"])
        b, sale = row[6:8]
        self.assertEqual(row[3], keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32"),
            (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), 31337, state["core"], row[1], b[5], row[4]))))
        self.assertEqual(row[5], keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", v1.source.SALE),
            (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), 31337, state["core"], row[1], b[5], row[4], sale))))
        self.assertEqual(row[0], keccak256(encode(("bytes32", "uint256", "address", "address", v1.source.DIRECT),
            (schema_id("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"), 31337, state["core"], state["conservationFloor"], (ZERO, *row[1:])))))

    def test_generated_schema_and_frozen_packet_source_profiles(self):
        self.assertGreater(len(v1.SCHEMA_BYTES), 24576)
        Draft202012Validator.check_schema(loads(v1.SCHEMA_BYTES, maximum=v1.MAX_BYTES))
        self.assertEqual(v1.documents(), {v1.NAME: v1.SCHEMA_BYTES})
        self.assertEqual((v1.ROOT / "schemas/records" / (v1.NAME + ".json")).read_bytes(), v1.SCHEMA_BYTES)
        self.assertEqual(v1.SCHEMA_HASH, keccak256(v1.SCHEMA_BYTES))
        self.assertEqual(keccak256(packet.PACKET_SCHEMA_BYTES), "0xbf70e9aa8f0d96855dbb2660a7cf87130d09baa0bb25fb4bb2ffd0f6103a051a")
        self.assertEqual(keccak256(packet.CONSERVATION_SCHEMA_BYTES), "0x35a7c99465ca6997901b8d401d2ae49dce3490b7bf9f6b1debbe0b8960c90f3b")
        self.assertEqual(v1.source.PROFILE_HASH, keccak256(v1.source.PROFILE_BYTES))
        self.assertEqual(v1.capture.PROFILE_HASH, keccak256(v1.capture.PROFILE_BYTES))
        with self.assertRaises(MuseumError): packet.validate(dumps(self.value()))

    def test_source_ref_pins_snapshot_crossjoins_and_closed_fields(self):
        snapshot = PublicDirectConservationFixture().result()
        for key in v1.SOURCE_REF_FIELDS:
            wrong = pins(snapshot); wrong[key] = ZERO
            with self.subTest(key=key), self.assertRaises(MuseumError): v1.semanticProjection(snapshot, wrong)
        for key in ("profile", "profileHash", "sourceReviewCommit", "coreSourceReviewCommit"):
            wrong = copy.deepcopy(snapshot); wrong[key] = "different"
            with self.subTest(key=key), self.assertRaises(MuseumError): v1.semanticProjection(wrong, pins(wrong))
        value = self.value(); value["floor"]["settlements"] = []; self.reject(value)
        value = self.value(); value["sourceState"]["blockHash"] += "\n"; self.reject(value)
        value = self.value(); value["catalogue"]["count"] = "2\n"; self.reject(value)

    def test_foreign_receipts_remain_typed_and_cannot_mask_missing_target(self):
        value = self.value(); events = value["discovery"]["ledgerReceiptEvents"]
        self.assertTrue(any(row["kind"] == "settlement" for row in events))
        self.assertGreater(len(events), int(value["discovery"]["targetReceiptEventCount"]))
        foreign = self.value("foreign")
        self.assertEqual(foreign["floor"]["status"], "none_recorded")
        self.assertGreater(int(foreign["discovery"]["ledgerReceiptEventCount"]), 0)
        target = value["floor"]["directSales"].pop()
        self.reject(value, "target denominator")
        value = self.value(); value["discovery"]["ledgerReceiptEvents"] = [e for e in events if e["receipt"][0] != target["receiptHash"]]
        value["discovery"]["ledgerReceiptEventCount"] = str(len(value["discovery"]["ledgerReceiptEvents"]))
        self.reject(value, "target denominator")
        value = self.value(); event = next(e for e in value["discovery"]["ledgerReceiptEvents"] if e["kind"] == "settlement")
        event["receipt"][7] = value["sourceState"]["collectionId"]
        native = v1.native(v1.F.SETTLEMENT, event["receipt"])
        event["receipt"][0] = v1.F.receipt_hash(value["sourceState"], v1.F.SETTLEMENT_DOMAIN, v1.F.SETTLEMENT, native)
        self.reject(value, "target universal/mixed")

    def test_none_recorded_and_denominator_counts_are_not_claimed_absence(self):
        value = self.value("empty")
        self.assertEqual(value["floor"], {"status": "none_recorded", "firstSale": None, "releases": [], "directSales": []})
        self.assertIn("not proof about free, unpaid, cancelled", value["qualification"])
        value["floor"]["status"] = "present"; self.reject(value, "none-recorded")
        for key in ("ledgerReceiptEventCount", "targetReceiptEventCount"):
            value = self.value(); value["discovery"][key] = "0"; self.reject(value)
        value = self.value(); value["discovery"]["ledgerReceiptEvents"].append(copy.deepcopy(value["discovery"]["ledgerReceiptEvents"][0]))
        value["discovery"]["ledgerReceiptEventCount"] = str(len(value["discovery"]["ledgerReceiptEvents"]))
        self.reject(value, "ledger native hash/key/order")

    def test_source_replacement_preserves_original_first_and_release_epochs(self):
        value = self.value(); self.assertEqual(value["floor"]["firstSale"]["sourceId"], "1")
        self.assertEqual(value["floor"]["releases"][1]["sourceId"], "2")
        for key in ("head", "emptyHead"):
            wrong = self.value(); wrong["catalogue"][key] = H("changed head"); self.reject(wrong, "head")
        wrong = self.value(); wrong["catalogue"]["sources"][1]["source"][5] = "0"; self.reject(wrong, "source member")
        wrong = self.value(); wrong["catalogue"]["sources"].reverse(); self.reject(wrong, "source member")
        wrong = self.value(); release = wrong["floor"]["releases"][0]
        release["receipt"][7:9] = ["2", wrong["catalogue"]["head"]]
        old_hash = release["receiptHash"]
        release["receipt"][0] = v1.F.receipt_hash(wrong["sourceState"], v1.F.RELEASE_DOMAIN, v1.F.RELEASE, v1.native(v1.F.RELEASE, release["receipt"]))
        release.update(receiptHash=release["receipt"][0], sourceId="2", sourceSetHash=wrong["catalogue"]["head"])
        for e in wrong["discovery"]["ledgerReceiptEvents"]:
            if e["receipt"][0] == old_hash: e["receipt"] = copy.deepcopy(release["receipt"])
        self.reject(wrong, "historical source")

    def test_reused_release_is_original_history_not_an_invented_new_receipt(self):
        value = self.value("reused_release")
        self.assertEqual((len(value["floor"]["releases"]), len(value["floor"]["directSales"])), (1, 2))
        self.assertEqual(value["floor"]["directSales"][0]["releaseReceiptHash"], value["floor"]["directSales"][1]["releaseReceiptHash"])
        value["floor"]["directSales"][1]["receipt"][10] = H("unretained release"); rehash_sale(value, 1)
        self.reject(value, "original release missing")

    def test_waiver_platform_collection_and_release_fact_shapes(self):
        value = self.value("waived")
        self.assertEqual(value["floor"]["releases"], [])
        self.assertEqual(value["floor"]["firstSale"]["receipt"][8], [ZERO] * 7 + [False])
        value = self.value(); value["floor"]["firstSale"]["effectiveTier"] = "CONSERVATION_WAIVED"
        self.reject(value, "named native")
        value = self.value(); value["floor"]["releases"][0]["receipt"][10][0] = H("different release payload")
        self.reject(value, "target denominator")

    def test_original_paid_hash_and_named_mirrors_are_not_substitutable(self):
        for mutate in (lambda r: r.update(adapterCodeHash=H("new code")), lambda r: r.update(tokenId="100000"),
                lambda r: r["originalSale"].update(receiptHash=H("new original hash")),
                lambda r: r["originalSale"]["receipt"].__setitem__(15, "0")):
            value = self.value(); mutate(value["floor"]["directSales"][0]); self.reject(value)
        value = self.value(); value["floor"]["directSales"][0]["receipt"][7][15] = "0"; rehash_sale(value)
        self.reject(value, "original paid fields/time")

    def test_fixed_price_and_auction_creation_times_are_distinct(self):
        auction = project(PublicDirectConservationFixture(product=v1.source.AUCTION))
        paid = auction["floor"]["directSales"][0]
        self.assertLess(int(paid["receipt"][7][9]), int(paid["recordedAt"]))
        value = self.value(); value["floor"]["directSales"][0]["receipt"][7][9] = "3003"; rehash_sale(value)
        self.reject(value, "original paid fields/time")
        auction["floor"]["directSales"][0]["receipt"][7][9] = "4000"; rehash_sale(auction)
        self.reject(auction, "original paid fields/time")

    def test_erc20_asset_is_original_address_without_current_code_requirement(self):
        value = project(PublicDirectConservationFixture(product=v1.source.ERC20))
        self.assertNotEqual(value["floor"]["directSales"][0]["receipt"][7][14], ZERO_ADDRESS)
        self.assertNotIn("assetCodeHash", value["floor"]["directSales"][0]["originalSale"])
        value["floor"]["directSales"][0]["receipt"][7][14] = ZERO_ADDRESS; rehash_sale(value)
        self.reject(value, "original paid fields/time")
        value = self.value(); value["floor"]["directSales"][0]["receipt"][7][14] = A(999); rehash_sale(value)
        self.reject(value, "original paid fields/time")

    def test_manager_token_event_and_universal_observations_fail_closed(self):
        edits = [lambda o: o["managerState"].update(authorizationUsed=False), lambda o: o["managerState"].update(core=A(888)),
            lambda o: o["tokenIdentity"].update(burned=True), lambda o: o["tokenIdentity"].update(collectionSerial="0"),
            lambda o: o["tokenIdentity"].update(collectionId="999"), lambda o: o.update(universalGetterEmpty=False),
            lambda o: o["event"]["topics"].__setitem__(3, H("wrong token")), lambda o: o["event"]["data"].__setitem__(1, "2")]
        for index, edit in enumerate(edits):
            value = self.value(); edit(value["floor"]["directSales"][0]["originalSale"])
            with self.subTest(index=index): self.reject(value)
        value = self.value(); value["floor"]["directSales"][1]["originalSale"]["tokenIdentity"]["collectionSerial"] = value["floor"]["directSales"][0]["originalSale"]["tokenIdentity"]["collectionSerial"]
        self.reject(value, "token/serial")

    def test_coherent_runtime_conflicts_are_rejected(self):
        value = self.value(); value["floor"]["directSales"][1]["receipt"][6][1] = H("contradictory Core code")
        rehash_sale(value, 1); self.reject(value, "runtime commitments")

    def test_each_native_receipt_rejects_a_different_domain_after_mirror_updates(self):
        for family, row_key, row_index in (("first_sale", "firstSale", None), ("release", "releases", 0), ("direct", "directSales", 0)):
            value = self.value(); row = value["floor"][row_key] if row_index is None else value["floor"][row_key][row_index]
            kind = v1.SPECS[family][0]; old_hash = row["receiptHash"]
            wrong = v1.F.receipt_hash(value["sourceState"], H("wrong native receipt domain"), kind, v1.native(kind, row["receipt"]))
            row["receiptHash"] = row["receipt"][0] = wrong
            for event in value["discovery"]["ledgerReceiptEvents"]:
                if event["kind"] == family and event["receipt"][0] == old_hash: event["receipt"] = copy.deepcopy(row["receipt"])
            with self.subTest(family=family): self.reject(value, "ledger native hash/key/order")
        value = self.value(); row = value["floor"]["directSales"][0]; old_hash = row["receiptHash"]
        r = list(v1.native(v1.source.DIRECT, row["receipt"])); b = r[6]
        r[5] = keccak256(encode(("bytes32", "uint256", "address", "address", "bytes32", "bytes32", v1.source.SALE),
            (H("wrong original adapter receipt domain"), b[4], b[0], r[1], b[5], r[4], r[7])))
        r[0] = v1.F.receipt_hash(value["sourceState"], v1.source.DIRECT_DOMAIN, v1.source.DIRECT, tuple(r))
        row.update(receipt=json_values(tuple(r)), receiptHash=r[0], originalReceiptHash=r[5])
        row["originalSale"]["receiptHash"] = row["originalSale"]["event"]["topics"][2] = r[5]
        for event in value["discovery"]["ledgerReceiptEvents"]:
            if event["receipt"][0] == old_hash: event["receipt"] = copy.deepcopy(row["receipt"])
        self.reject(value, "original key/hash")

    def test_same_adapter_cannot_claim_different_immutable_product_bindings(self):
        value = self.value(); first, second = value["floor"]["directSales"]
        r = second["receipt"]
        r[1:3] = first["receipt"][1:3]
        r[6][5] = v1.source.ERC20; r[7][14] = A(999)
        r[3] = v1.source.direct_key(v1.native(v1.source.BINDINGS, r[6]), r[1], r[4])
        rehash_sale(value, 1)
        self.reject(value, "immutable adapter bindings")

    def test_self_consistent_subset_cannot_pass_projection_with_original_snapshot_pin(self):
        snapshot = PublicDirectConservationFixture().result(); original_pins = pins(snapshot)
        removed = snapshot["floor"]["directSales"].pop()
        release = snapshot["floor"]["releases"].pop()
        events = snapshot["historyCoverage"]["ledgerReceiptEvents"]
        snapshot["historyCoverage"]["ledgerReceiptEvents"] = [e for e in events if e["receipt"][0] not in (removed["receiptHash"], release["receiptHash"])]
        snapshot["historyCoverage"]["ledgerReceiptEventCount"] = str(len(events) - 2)
        snapshot["historyCoverage"]["targetReceiptEventCount"] = str(int(snapshot["historyCoverage"]["targetReceiptEventCount"]) - 2)
        with self.assertRaisesRegex(MuseumError, "source commitments"):
            v1.semanticProjection(snapshot, original_pins)
        # A newly asserted, internally consistent snapshot is only supplied data. Its new
        # pin is not an authenticated capture and must be replayed by the assembly caller.
        altered = v1.semanticProjection(snapshot, pins(snapshot))
        self.assertEqual(len(altered["floor"]["directSales"]), 1)
        self.assertIn("Source references do not authenticate themselves", altered["qualification"])
        value = self.value(); value["floor"]["directSales"][1]["receipt"][6][3] = H("contradictory manager code")
        rehash_sale(value, 1); self.reject(value, "runtime commitments")

    def test_publication_coordinates_governance_and_timestamp_consistency(self):
        value = self.value(); value["binding"]["governance"]["execution"]["transactionHash"] = H("different transaction")
        self.reject(value, "governance transaction/order")
        value = self.value(); value["catalogue"]["sources"][0]["admission"]["governance"]["action"][10] = "3001"
        self.reject(value, "execution window")
        value = self.value(); value["floor"]["directSales"][0]["originalSale"]["publication"]["logIndex"] = "100"
        self.reject(value, "paid event")
        value = self.value(); value["floor"]["directSales"][0]["originalSale"]["publication"]["blockHash"] = value["sourceState"]["blockHash"]
        self.reject(value)
        value = self.value(); value["sourceState"]["timestamp"] = "3006"
        self.reject(value, "timestamp")
        value = self.value(); first = value["floor"]["firstSale"]["publication"]
        value["binding"]["publication"] = copy.deepcopy(first)
        self.reject(value)


if __name__ == "__main__": unittest.main()
