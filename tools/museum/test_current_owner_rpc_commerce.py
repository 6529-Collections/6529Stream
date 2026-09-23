"""Pure commerce orchestration/refusal tests; no chain execution is asserted."""
import unittest
from unittest.mock import Mock

from .canonical import MuseumError, dumps, hex_bytes, keccak256, loads, schema_id
from .current_museum_capture import h
from .current_owner_rpc_commerce import (OwnerCommerceMixin, BINDINGS, SALE_RECEIPT,
    CONSERVATION, DIRECT_KIND, DIRECT_TYPE, DIRECT_VERSION, FLOOR, METADATA, SALE,
    WAIVED, direct_commitments, evidence_value, registration_transition)
from .independent_wire import ZERO, ZERO_ADDRESS


def address(n):
    return "0x" + n.to_bytes(20, "big").hex()


class RegistrationDouble(OwnerCommerceMixin):
    def __init__(self):
        self.addresses = {"StreamModuleRegistry": address(1), SALE: address(2)}
        self.deployment = schema_id("deployment")
        self.item = None
        self.chain, self.count = schema_id("chain"), 7
        self.actions = []
        self.token_interface_id = Mock(return_value="0x12345678")
        self.read = Mock(side_effect=lambda target, sig, kinds, args, out: (args[0] != "0xffffffff",))
        self.rpc = Mock(return_value="0x6000")
        self.tamper = False

    def call(self, name, method, values=()):
        assert name == "StreamModuleRegistry"
        if method == "moduleRecord":
            if self.item is None:
                return ((0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, "", 0, 0, 0),)
            row = [1, *self.item[1:], 100, 100, 1]
            if self.tamper: row[2] = schema_id("local token graph module v1")
            return (tuple(row),)
        if method == "registrationChainHash": return (self.chain, self.count)
        if method == "isModuleEligible": return (True,)
        raise AssertionError(method)

    def govern_configuration(self, name, method, values, transition):
        assert (name, method) == ("StreamModuleRegistry", "registerModule")
        item, = values
        expected, chain = registration_transition(address(1), item, self.chain, self.count)
        assert transition == expected
        self.actions.append((name, method, values, transition))
        self.item, self.chain, self.count = item, chain, self.count + 1
        return schema_id("actual delayed action double")


class CommerceTests(unittest.TestCase):
    def test_direct_registration_uses_original_identity_and_actual_governance(self):
        f = RegistrationDouble()
        evidence = f.register_owner_direct_sale()
        self.assertEqual(evidence["registration"][1:5], (DIRECT_TYPE, DIRECT_VERSION, "0x12345678", 500000))
        self.assertNotEqual(DIRECT_VERSION, schema_id("local token graph module v1"))
        self.assertEqual(len(f.actions), 1)
        self.assertEqual(evidence["record"][9:], (100, 100, 1))
        with self.assertRaisesRegex(MuseumError, "already registered"):
            f.register_owner_direct_sale()
        self.assertEqual(len(f.actions), 1)

    def test_direct_registration_rejects_foreign_readback_and_invalid_erc165(self):
        f = RegistrationDouble(); f.tamper = True
        with self.assertRaisesRegex(MuseumError, "readback differs"):
            f.register_owner_direct_sale()
        f = RegistrationDouble(); f.read = Mock(return_value=(True,))
        with self.assertRaisesRegex(MuseumError, "interface differs"):
            f.register_owner_direct_sale()
        self.assertEqual(f.actions, [])

    def setup_fixture(self, *, already_minted=False, global_grant=False):
        f = OwnerCommerceMixin(); steps = []
        f.addresses = {"StreamCore": address(1), "StreamGovernanceExecutor": address(2), FLOOR: address(3)}
        f.governor = address(4)
        f.register_owner_direct_sale = Mock(side_effect=lambda: steps.append("admit-DIRECT") or {"action": ZERO})
        f.deploy_library_closure = Mock()
        f.deploy = Mock(side_effect=lambda *args: steps.append("deploy-floor") or address(3))
        f.rpc = Mock(return_value="0x6000")
        tier = [ZERO]
        def call(name, method, values=()):
            if method in ("conservationFloorTransition", "familyWriterTransition"):
                return (schema_id(method), ZERO, schema_id("new"))
            if method == "conservationFloor": return (address(3), keccak256(b"\x60\x00"))
            if method == "declaredConservationTier": return (tier[0],)
            if method == "familyWriter": return (global_grant, 1) if values[0] == 0 else (True, 1)
            if method == "conservationTier": return (tier[0], tier[0])
            if method == "collectionMintedEver": return (int(already_minted),)
            if method == "firstSale": return ((ZERO,),)
            raise AssertionError((name, method, values))
        f.call = call
        f.govern_configuration = Mock(side_effect=lambda name, method, args, transition:
            steps.append(method) or schema_id(method))
        def transact(name, method, args, *, safe):
            self.assertEqual((name, method, args, safe), (METADATA, "declareConservationTier", (1, WAIVED), f.governor))
            tier[0] = WAIVED; steps.append("Safe-waiver")
            return {"status": "0x1"}
        f.transact = transact
        return f, steps

    def test_real_floor_configuration_and_narrow_safe_declaration_precede_mint(self):
        f, steps = self.setup_fixture(); f.prepare_owner_commerce()
        self.assertEqual(steps, ["admit-DIRECT", "deploy-floor", "bindConservationFloor", "setFamilyWriter", "Safe-waiver"])
        self.assertEqual(f.deploy.call_args.args, (FLOOR, (address(1), address(2),
            ("CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2),
            ("CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2),
            ("CONSERVATION_FLOOR_CALL_GAS", 2000000, 2000000, 2))))
        self.assertEqual(f.govern_configuration.call_args_list[1].args[2], (1, CONSERVATION, 7, address(4), True))
        self.assertEqual(f.owner_commerce["tier"], WAIVED)
        with self.assertRaisesRegex(MuseumError, "already attempted"):
            f.prepare_owner_commerce()

    def test_prior_mint_or_global_writer_grant_is_not_accepted_as_waived_setup(self):
        for options, message in (({"already_minted": True}, "precede first mint"),
                ({"global_grant": True}, "writer grant differs")):
            f, _ = self.setup_fixture(**options)
            with self.assertRaisesRegex(MuseumError, message): f.prepare_owner_commerce()
            self.assertIsNone(f.owner_commerce)

    def receipt_fixture(self):
        f = OwnerCommerceMixin()
        f.addresses = {"StreamCore": address(1), "StreamMintManager": address(2), SALE: address(3), FLOOR: address(4)}
        f.owner_commerce, f.token_id, f.token_buyer = {}, 1, address(5)
        f.rpc = Mock(return_value="0x6000")
        runtime = keccak256(b"\x60\x00")
        bindings = (address(1), runtime, address(2), runtime, 31337, DIRECT_KIND)
        sale = (schema_id("auth-digest"), 1, 1, schema_id("operation-root"), schema_id("operation-id"),
            schema_id("bound-policy"), schema_id("primary-policy"), schema_id("profile"), address(5),
            100, False, address(5), 1, address(6), ZERO_ADDRESS, 10**16)
        authorization = schema_id("authorization")
        key, digest = direct_commitments(address(3), authorization, bindings, sale)
        first_type = ("bytes32", "uint256", "bytes32", "address", "bytes32", "uint64", "uint64", "bytes32", (*("bytes32",) * 7, "bool"))
        first = (ZERO, 1, WAIVED, address(3), key, 100, 0, schema_id("source-head"), (*[ZERO] * 7, False))
        first_hash = h(("bytes32", "uint256", "address", "address", first_type),
            (schema_id("6529STREAM_CONSERVATION_FIRST_SALE_V1"), 31337, address(1), address(4), first))
        first = (first_hash, *first[1:])
        floor_type = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32", BINDINGS, SALE_RECEIPT, "bytes32", "bytes32", "bytes32", "uint64")
        floor = (ZERO, address(3), runtime, key, authorization, digest, bindings, sale, WAIVED, first_hash, ZERO, 100)
        floor_hash = h(("bytes32", "uint256", "address", "address", floor_type),
            (schema_id("6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"), 31337, address(1), address(4), floor))
        floor = (floor_hash, *floor[1:])
        f.token_mint_evidence = {"authorizationId": authorization, "saleAuthorizationDigest": sale[0],
            "operationRoot": sale[3], "profileId": sale[7], "wallet": sale[8], "price": str(sale[-1])}
        rows = {"directPrimaryBindings": (bindings,), "directPrimarySaleReceipt": (sale,),
            "directPrimarySaleReceiptHash": (digest,), "directPrimarySaleFloorReceipt": (floor,), "firstSale": (first,)}
        f.call = lambda name, method, values=(): rows[method]
        return f, rows

    def test_original_direct_domain_and_sixteen_word_receipt_are_preserved(self):
        f, rows = self.receipt_fixture()
        bindings, = rows["directPrimaryBindings"]; receipt, = rows["directPrimarySaleReceipt"]
        authorization = f.token_mint_evidence["authorizationId"]
        key, digest = direct_commitments(address(3), authorization, bindings, receipt)
        # Hand-written fixed-width ABI oracle; operationId is bytes32, not an integer.
        words = [hex_bytes(schema_id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1")),
            (31337).to_bytes(32, "big"), hex_bytes(address(1)).rjust(32, b"\0"),
            hex_bytes(address(3)).rjust(32, b"\0"), hex_bytes(DIRECT_KIND), hex_bytes(authorization)]
        for value in receipt:
            words.append(int(value).to_bytes(32, "big") if type(value) in (int, bool) else hex_bytes(value).rjust(32, b"\0"))
        self.assertEqual(digest, keccak256(b"".join(words)))
        self.assertNotEqual(key, digest)
        f.verify_owner_commerce()
        encoded = dumps(f.owner_commerce)
        self.assertEqual(loads(encoded)["directReceipt"][-1], "10000000000000000")
        self.assertIs(loads(encoded)["directReceipt"][10], False)

    def test_foreign_direct_and_floor_receipts_are_refused(self):
        cases = (("directPrimaryBindings", 4, 1), ("directPrimarySaleReceipt", 11, address(99)),
            ("directPrimarySaleFloorReceipt", 4, ZERO), ("directPrimarySaleFloorReceipt", 8, schema_id("MUSEUM_GRADE")),
            ("directPrimarySaleFloorReceipt", 9, ZERO), ("directPrimarySaleFloorReceipt", 0, schema_id("foreign")),
            ("firstSale", 0, schema_id("foreign")))
        for method, index, value in cases:
            f, rows = self.receipt_fixture()
            changed = list(rows[method][0]); changed[index] = value; rows[method] = (tuple(changed),)
            with self.subTest(method=method, index=index), self.assertRaises(MuseumError):
                f.verify_owner_commerce()
            self.assertEqual(f.owner_commerce, {})

    def test_integer_serialization_is_exact_at_uint256_boundary(self):
        value = {"uint": 2**256 - 1, "nested": (True, False, b"\x01", 1)}
        self.assertEqual(loads(dumps(evidence_value(value))),
            {"uint": str(2**256 - 1), "nested": [True, False, "0x01", "1"]})


if __name__ == "__main__":
    unittest.main()
