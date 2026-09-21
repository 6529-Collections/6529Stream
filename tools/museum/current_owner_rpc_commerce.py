"""Opt-in original DIRECT registration and WAIVED floor for owner RPC capture.

This changes no ordinary token fixture default and makes no MUSEUM/LITE claim.
"""
from .canonical import hex_bytes, keccak256, schema_id
from .current_museum_capture import h
from .independent_wire import ZERO, ZERO_ADDRESS, require

FLOOR = "StreamConservationFloor"
SALE = "StreamFixedPriceSaleAdapter"
METADATA = "StreamCollectionMetadataV1"
DIRECT_TYPE = schema_id("DIRECT_PRIMARY_SALE_ADAPTER")
DIRECT_VERSION = schema_id("6529STREAM_DIRECT_PRIMARY_SALE_V1")
DIRECT_KIND = schema_id("6529STREAM_DIRECT_NATIVE_FIXED_PRICE_V1")
WAIVED = schema_id("CONSERVATION_WAIVED")
CONSERVATION = schema_id("6529STREAM_RECORD_FAMILY_CONSERVATION_V1")
BINDINGS = ("address", "bytes32", "address", "bytes32", "uint256", "bytes32")
SALE_RECEIPT = ("bytes32", "uint256", "uint256", "bytes32", "bytes32", "bytes32",
    "bytes32", "bytes32", "address", "uint64", "bool", "address", "uint64", "address", "address", "uint256")


def registration_transition(registry, item, chain, count):
    """Original UNKNOWN-to-ACTIVE module-registry state commitments."""
    target, kind, version, interface, gas, runtime, deployment, manifest, uri = item
    record = h(("bytes32", "address", "bytes32", "bytes4", "bytes32", "bytes32", "bytes32", "bytes32"),
        (schema_id("6529STREAM_MODULE_REGISTRATION_RECORD_V1"), target, kind, interface, version, runtime, deployment, manifest))
    next_chain = h(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32", "uint64"),
        (schema_id("6529STREAM_RECORD_CHAIN_V1"), 31337, registry, 0, schema_id("MODULE_REGISTRATION"), chain, record, count))
    fields = ("uint8", "bytes32", "bytes32", "bytes4", "uint32", "bytes32", "bytes32", "bytes32", "bytes32", "uint64")
    empty = h(fields, (0, ZERO, ZERO, "0x00000000", 0, ZERO, ZERO, ZERO, keccak256(b""), 0))
    facts = h(fields, (1, kind, version, interface, gas, runtime, deployment, manifest, keccak256(uri.encode()), 1))
    scope = h(("bytes32", "uint256", "address", "address"),
        (schema_id("6529STREAM_MODULE_REGISTRATION_SCOPE_V1"), 31337, registry, target))
    fields = ("bytes32", "bytes32", "bool", "bytes32", "uint256", "bytes32", "uint64", "address")
    domain = schema_id("6529STREAM_MODULE_REGISTRATION_STATE_V1")
    old = h(fields, (domain, scope, False, empty, count, chain, count, ZERO_ADDRESS))
    new = h(fields, (domain, scope, True, facts, count + 1, next_chain, count + 1, target))
    return (scope, old, new), next_chain


def direct_commitments(adapter, authorization, bindings, receipt):
    leading_types = ("bytes32", "uint256", "address", "address", "bytes32", "bytes32")
    leading_values = (bindings[4], bindings[0], adapter, bindings[5], authorization)
    key = h(leading_types, (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_KEY_V1"), *leading_values))
    digest = h((*leading_types, SALE_RECEIPT),
        (schema_id("6529STREAM_DIRECT_PRIMARY_SALE_RECEIPT_V1"), *leading_values, receipt))
    return key, digest


def evidence_value(value):
    """Lossless JSON evidence: protocol integers are decimal strings, never floats."""
    if type(value) is int:
        return str(value)
    if isinstance(value, (tuple, list)):
        return [evidence_value(item) for item in value]
    if isinstance(value, dict):
        return {key: evidence_value(item) for key, item in value.items()}
    if isinstance(value, bytes):
        return "0x" + value.hex()
    return value


class OwnerCommerceMixin:
    def register_owner_direct_sale(self):
        registry, target = self.addresses["StreamModuleRegistry"], self.addresses[SALE]
        interface = self.token_interface_id("IStreamDirectPrimarySaleReceipt")
        for candidate, expected in ((interface, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            require(self.read(target, "supportsInterface(bytes4)", ("bytes4",), (candidate,), ("bool",)) == (expected,),
                "owner DIRECT interface differs")
        previous, = self.call("StreamModuleRegistry", "moduleRecord", (target,))
        require(previous[0] == 0 and previous[-1] == 0, "owner DIRECT sale already registered")
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [target, "latest"])))
        item = (target, DIRECT_TYPE, DIRECT_VERSION, interface, 500000, runtime, self.deployment,
            schema_id("owner capture actual DIRECT product"), "urn:fixture:owner-capture-direct")
        chain, count = self.call("StreamModuleRegistry", "registrationChainHash")
        transition, next_chain = registration_transition(registry, item, chain, count)
        action = self.govern_configuration("StreamModuleRegistry", "registerModule", (item,), transition)
        row, = self.call("StreamModuleRegistry", "moduleRecord", (target,))
        require(tuple(row[:9]) == (1, *item[1:]) and row[9] == row[10] > 0 and row[-1] == 1
            and self.call("StreamModuleRegistry", "registrationChainHash") == (next_chain, count + 1)
            and self.call("StreamModuleRegistry", "isModuleEligible", (target, DIRECT_TYPE, interface)) == (True,),
            "owner DIRECT registration readback differs")
        return {"action": action, "registration": item, "record": row}

    def prepare_owner_commerce(self):
        require(not hasattr(self, "owner_commerce"), "owner commerce already attempted")
        self.owner_commerce = None
        registration = self.register_owner_direct_sale()
        self.deploy_library_closure((FLOOR,))
        floor = self.deploy(FLOOR, (self.addresses["StreamCore"], self.addresses["StreamGovernanceExecutor"],
            ("CONSERVATION_FLOOR_READ_GAS", 300000, 300000, 2),
            ("CONSERVATION_FLOOR_PRODUCER_GAS", 1000000, 1000000, 2),
            ("CONSERVATION_FLOOR_CALL_GAS", 2000000, 2000000, 2)))
        transition = self.call("StreamCore", "conservationFloorTransition", (floor,))
        binding = self.govern_configuration("StreamCore", "bindConservationFloor", (floor,), transition)
        runtime = keccak256(hex_bytes(self.rpc("eth_getCode", [floor, "latest"])))
        require(self.call("StreamCore", "conservationFloor") == (floor, runtime)
            and self.call("StreamCore", "declaredConservationTier", (1,)) == (ZERO,),
            "owner floor binding differs or tier already declared")
        args = (1, CONSERVATION, 7, self.governor, True)
        transition = self.call(METADATA, "familyWriterTransition", args)
        writer = self.govern_configuration(METADATA, "setFamilyWriter", args, transition)
        require(self.call(METADATA, "familyWriter", args[:-1]) == (True, 1)
            and not self.call(METADATA, "familyWriter", (0, CONSERVATION, 8, self.governor))[0],
            "owner conservation writer grant differs")
        declaration = self.transact(METADATA, "declareConservationTier", (1, WAIVED), safe=self.governor)
        first, = self.call(FLOOR, "firstSale", (1,))
        require(self.call(METADATA, "conservationTier", (1,)) == (WAIVED, WAIVED)
            and self.call("StreamCore", "declaredConservationTier", (1,)) == (WAIVED,)
            and self.call("StreamCore", "collectionMintedEver", (1,)) == (0,) and first[0] == ZERO,
            "owner explicit waiver must precede first mint and sale")
        self.owner_commerce = {"registration": registration, "floor": floor, "floorCodeHash": runtime,
            "bindingAction": binding, "writerAction": writer, "declarationReceipt": declaration,
            "tier": WAIVED, "qualification": "Explicit local WAIVED commerce; no MUSEUM/LITE documentary-floor acceptance."}

    def verify_owner_commerce(self):
        require(self.owner_commerce is not None, "owner commerce setup incomplete")
        evidence, sale = self.token_mint_evidence, self.addresses[SALE]
        authorization = evidence["authorizationId"]
        bindings, = self.call(SALE, "directPrimaryBindings")
        expected = (self.addresses["StreamCore"],
            keccak256(hex_bytes(self.rpc("eth_getCode", [self.addresses["StreamCore"], "latest"]))),
            self.addresses["StreamMintManager"],
            keccak256(hex_bytes(self.rpc("eth_getCode", [self.addresses["StreamMintManager"], "latest"]))),
            31337, DIRECT_KIND)
        require(tuple(bindings) == expected, "owner DIRECT bindings differ")
        receipt, = self.call(SALE, "directPrimarySaleReceipt", (authorization,))
        require(receipt[0] == evidence["saleAuthorizationDigest"] and receipt[1:4] == (1, self.token_id, evidence["operationRoot"])
            and receipt[7:9] == (evidence["profileId"], evidence["wallet"])
            and all(receipt[i] != ZERO for i in (4, 5, 6)) and receipt[9] > 0
            and receipt[11] == self.token_buyer and receipt[12] == 1 and receipt[13] != ZERO_ADDRESS
            and receipt[14:] == (ZERO_ADDRESS, int(evidence["price"])), "owner DIRECT paid receipt differs")
        key, digest = direct_commitments(sale, authorization, bindings, receipt)
        require(self.call(SALE, "directPrimarySaleReceiptHash", (authorization,)) == (digest,),
            "owner original DIRECT receipt hash differs")
        floor, = self.call(FLOOR, "directPrimarySaleFloorReceipt", (key,))
        first, = self.call(FLOOR, "firstSale", (1,))
        require(floor[0] != ZERO and tuple(floor[1:6]) == (sale,
            keccak256(hex_bytes(self.rpc("eth_getCode", [sale, "latest"]))), key, authorization, digest)
            and tuple(floor[6]) == tuple(bindings) and tuple(floor[7]) == tuple(receipt)
            and floor[8] == WAIVED and floor[9] == first[0] != ZERO and floor[10] == ZERO
            and first[1] == 1 and first[2] == WAIVED and first[3] == sale and first[4] == key
            and floor[11] == first[5] > 0,
            "owner DIRECT floor receipt differs")
        # The original receipts hash the complete tuple with its hash slot zero.
        floor_type = ("bytes32", "address", "bytes32", "bytes32", "bytes32", "bytes32",
            BINDINGS, SALE_RECEIPT, "bytes32", "bytes32", "bytes32", "uint64")
        first_type = ("bytes32", "uint256", "bytes32", "address", "bytes32", "uint64",
            "uint64", "bytes32", (*("bytes32",) * 7, "bool"))
        for value, kinds, domain in ((floor, floor_type, "6529STREAM_CONSERVATION_DIRECT_RECEIPT_V1"),
                (first, first_type, "6529STREAM_CONSERVATION_FIRST_SALE_V1")):
            require(value[0] == h(("bytes32", "uint256", "address", "address", kinds),
                (schema_id(domain), 31337, bindings[0], self.addresses[FLOOR], (ZERO, *value[1:]))),
                "owner complete floor receipt hash differs")
        self.owner_commerce = evidence_value(self.owner_commerce | {"directKey": key, "directReceiptHash": digest,
            "directReceipt": receipt, "floorReceipt": floor, "firstSale": first})
