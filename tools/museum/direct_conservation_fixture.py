"""Six coherent synthetic source maps; no native execution or paid-flow acceptance.

The original raw paid construction is DIRECT from the outset. Captured universal
packages are never converted, relabeled, or used as a stand-in for DIRECT data.
"""
from copy import deepcopy

from . import acquisition_direct_personhood as direct_personhood
from . import conservation_provider_binding as provider_binding
from . import conservation_rights as rights_binding
from . import public_conservation_capture as selection_capture
from . import public_conservation_source as selection_source
from . import public_conservation_tier_capture as tier_capture
from . import public_conservation_tier_source as tier_source
from . import public_conservation_floor_source as floor
from . import public_direct_conservation_capture as direct_capture
from . import public_direct_conservation_source as direct
from .canonical import dumps, hex_bytes, keccak256, schema_id
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO, ZERO_ADDRESS
from .test_acquisition_personhood import NativePersonhoodAssemblyFixture
from .test_native_conservation_fixture import _zero, K
from .test_current_rights_source import A, H
from .test_public_conservation_provider_source import original_preimage
from .mint_entropy_source import TRANSFER


class DirectConservationFixture(NativePersonhoodAssemblyFixture):
    """Original DIRECT/personhood, tier, and selection packages from one RPC map."""

    def __init__(self, *, late_declaration=False, declared_tier=False, selection_mode="baseline", personhood_mode="resolved",
            product=direct.NATIVE, platform_works=False, saved_intent=None, provider_selector=None,
            direct_token=41, sale_tier=None):
        if selection_mode not in ("baseline", "present", "waiver", "superseded", "superseded_before_sale"):
            raise ValueError("unsupported synthetic selection mode")
        if product not in (direct.NATIVE, direct.ERC20, direct.AUCTION):
            raise ValueError("unsupported synthetic DIRECT product")
        if late_declaration and declared_tier:
            raise ValueError("early declaration and late-declaration negative are distinct modes")
        self.late_tier = late_declaration
        self.declared_tier = declared_tier
        self.selection_mode, self.product, self.saved_intent = selection_mode, product, saved_intent
        self.provider_selector = provider_selector
        self.direct_token = direct_token
        self.sale_tier = floor.FULL if declared_tier and sale_tier is None else sale_tier
        super().__init__(personhood_mode=personhood_mode, platform_works=platform_works)
        self.floor_anchor["profile"] = direct.PROFILE
        self.floor_anchor["codePins"].append({"address": self.manager, "runtimeHash": self.pins[self.manager]})
        self.personhood_anchor = deepcopy(self.a)
        if declared_tier:
            facade = A(91)
            self.event(2, self.core, [tier_source.CORE_TIER_EVENT, self.topic("uint256", 1),
                floor.FULL, self.topic("address", facade)], ("uint16",), (1,))
            self.event(2, facade, [tier_source.FACADE_TIER_EVENT, self.topic("uint256", 1),
                floor.FULL], ("uint16",), (1,))
        if late_declaration: self._late_declaration()
        else:
            # Native fixed-price mint completes in the paid transaction before
            # the floor records payment. The late-declaration source-only mode
            # deliberately remains contradictory for the new composition guard.
            completion_block = 2 if self.product == direct.AUCTION else 3
            old, paid = self.receipts[H(404)], self.receipts[H(400 + completion_block)]
            transfer = next(log for log in old["logs"] if log["address"] == self.core and log["topics"][0] == TRANSFER)
            old["logs"].remove(transfer)
            transfer.update({key: paid[key] for key in ("blockHash", "blockNumber", "transactionHash", "transactionIndex")})
            if self.product == direct.AUCTION:
                transfer["topics"][2] = self.topic("address", self.floor_recorder)
                paid["logs"].append(transfer)
            else: paid["logs"].insert(0, transfer)
            self.reorder_logs(completion_block, paid["logs"])
            self.reorder_logs(4, old["logs"])
        if selection_mode == "superseded":
            original_anchor = self.a
            self.a = self.selection_anchor
            self.append_intent("collection", block=4)
            self.update_heads()
            self.a = original_anchor

    def _tier_history(self, _declared):
        super()._tier_history(self.late_tier or self.declared_tier)

    def _event(self, signature):
        return next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor and log["topics"][0] == signature)

    def _paid_floor(self, source_head):
        # Called by the ancestor before any snapshot or capture is created.
        previous_selection = self.selections[("collection", 0)][-1]
        if self.selection_mode == "present":
            interview = self.append_interview("collection", block=2)
            self.append_intent("collection", block=2, interview=interview)
        elif self.selection_mode == "waiver":
            self.append_waiver("collection", block=2)
        elif self.selection_mode == "superseded_before_sale":
            self.append_intent("collection", block=2)
        self.update_heads()
        selected = previous_selection if self.selection_mode == "superseded_before_sale" else self.selections[("collection", 0)][-1]
        self.saved_selection = selected
        self.manager = A(98)
        self.codes[self.manager] = b"synthetic DIRECT mint manager"
        self.pins[self.manager] = keccak256(self.codes[self.manager])
        self.add(self.floor, "supportsInterface(bytes4)", ("bytes4",), (direct.DIRECT_FLOOR_INTERFACE,), ("bool",), (True,))
        for interface, value in ((direct.DIRECT_SALE_INTERFACE, True), ("0x01ffc9a7", True), ("0xffffffff", False)):
            self.add(self.floor_recorder, "supportsInterface(bytes4)", ("bytes4",), (interface,), ("bool",), (value,))
        self.bindings = (self.core, self.pins[self.core], self.manager, self.pins[self.manager], 31337, self.product)
        authorization = K("six-source synthetic original DIRECT authorization")
        key = direct.direct_key(self.bindings, self.floor_recorder, authorization)
        stamp = int(self.blocks[H(203)]["timestamp"], 16)
        sale = (K("DIRECT authorization digest"), 1, self.direct_token, K("DIRECT operation root"), K("DIRECT operation id"),
            K("DIRECT bound mint policy"), K("DIRECT primary policy"), K("DIRECT profile"), A(92),
            stamp - 1 if self.product == direct.AUCTION else stamp, False, A(94), 1, A(90),
            A(9090) if self.product == direct.ERC20 else ZERO_ADDRESS, 1003)
        original_hash = direct.original_hash(self.bindings, self.floor_recorder, authorization, sale)
        if self.direct_token != 41:
            self.add(self.core, "tokenCollectionIdentity(uint256)", ("uint256",), (self.direct_token,),
                ("bool", "uint256", "uint256", "bool"), (True, 1, 4, False))
            self.add(self.core, "tokenLifecycle(uint256)", ("uint256",), (self.direct_token,), ("uint8",), (2,))
        interview_domain = "6529STREAM_FINALITY_PRESENT_INTERVIEW_V1" if selected[3] == 0 else "6529STREAM_FINALITY_WAIVED_INTERVIEW_V1"
        self.floor_interview_commitment = keccak256(encode(("bytes32", "uint256", ("address",) * 5,
            ("uint8", "uint256", "uint256", "bytes32"), "bytes32", selection_source.SELECTION, "bytes32", "bytes32"),
            (schema_id(interview_domain), 31337, (self.core, self.a["host"], self.a["schemas"], self.a["store"],
             self.a["conservationSelector"]), (0, 1, 0, ZERO), self.subject("collection"), selected,
             schema_id("STREAM_ARTIST_INTERVIEW_V1"),
             "0x1533a5140b53a7b0bc3f76524cb01d44c62391c8db570cbdff11fbc9dea6e9cf")))
        intent, waiver = (selected[0][0], ZERO) if selected[0][1] == 0 else (ZERO, selected[0][0])
        if self.saved_intent is not None: intent = self.saved_intent
        facts = (self.artist_id, self.identity_hash, intent, waiver, self.floor_interview_commitment,
            K("rights before combined setup"), K("personhood before combined setup"), False)
        self.hash_anchor = {"chainId": "31337", "core": self.core, "conservationFloor": self.floor}
        lite = self.sale_tier or next(value for value, label in floor.TIERS.items() if label == "MUSEUM_GRADE_LITE")
        first = (ZERO, 1, lite, self.floor_recorder, key, stamp, 1, source_head, facts)
        first = (floor.receipt_hash(self.hash_anchor, floor.FIRST_DOMAIN, floor.FIRST, first), *first[1:])
        context = (K("DIRECT scope"), K("DIRECT membership"), K("DIRECT media inventory"), ZERO, K("DIRECT source context"), False)
        release_key = floor.release_key(self.hash_anchor, 1, context)
        release = (ZERO, release_key, 1, lite, self.floor_recorder, key, stamp, 1, source_head,
            context, (context[4], K("DIRECT media evidence"), ZERO))
        release = (floor.receipt_hash(self.hash_anchor, floor.RELEASE_DOMAIN, floor.RELEASE, release), *release[1:])
        paid = (ZERO, self.floor_recorder, self.pins[self.floor_recorder], key, authorization, original_hash,
            self.bindings, sale, lite, first[0], release[0], stamp)
        paid = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, paid), *paid[1:])
        self.first, self.release, self.direct_receipt = first, release, paid
        self._paid_getters()
        self.add(self.floor_recorder, "directPrimaryBindings()", (), (), (direct.BINDINGS,), (self.bindings,))
        self.add(self.floor_recorder, "directPrimarySaleReceipt(bytes32)", ("bytes32",), (authorization,), (direct.SALE,), (sale,))
        self.add(self.floor_recorder, "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), (authorization,), ("bytes32",), (original_hash,))
        self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (key,), (floor.SETTLEMENT,), (_zero(floor.SETTLEMENT),))
        self.add(self.manager, "core()", (), (), ("address",), (self.core,))
        for getter, value in (("isOperationRootUsed", sale[3]), ("isAuthorizationUsed", authorization)):
            self.add(self.manager, getter + "(bytes32)", ("bytes32",), (value,), ("bool",), (True,))
        self.event(3, self.floor, [floor.FIRST_EVENT, self.topic("uint256", 1), first[0]], (floor.FIRST, "uint16"), (first, 1))
        self.event(3, self.floor, [floor.RELEASE_EVENT, release_key, release[0]], (floor.RELEASE, "uint16"), (release, 1))
        self.event(3, self.floor, [direct.DIRECT_EVENT, key, paid[0]], (direct.DIRECT, "uint16"), (paid, 1))
        self.event(3, self.floor_recorder, [direct.ORIGINAL_EVENT, authorization, original_hash, self.topic("uint256", self.direct_token)],
            (direct.SALE, "uint16"), (sale, 1))

    def _paid_getters(self):
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (1,), (floor.FIRST,), (self.first,))
        self.add(self.floor, "releaseFloorReceipt(bytes32)", ("bytes32",), (self.release[1],), (floor.RELEASE,), (self.release,))
        self.add(self.floor, "directPrimarySaleFloorReceipt(bytes32)", ("bytes32",), (self.direct_receipt[3],),
            (direct.DIRECT,), (self.direct_receipt,))

    def _rewrite_floor(self, platform_works):
        # Slot 5 is skipped by provider constructor admission but is used by its
        # actual conservation read. Bind it before hashing the source admission.
        targets, hashes = list(self.configuration[0]), list(self.configuration[1])
        targets[5] = self.provider_selector or self.selection_anchor["conservationSelector"]
        hashes[5] = self.pins.get(targets[5], K("different preserved selector hash"))
        self.configuration = (tuple(targets), tuple(hashes), *self.configuration[2:])
        self.configuration_hash = keccak256(original_preimage(self.configuration))
        self.set_configuration(self.configuration)
        row = decode((floor.SOURCE,), hex_bytes(self.responses[(self.floor, calldata("sourceAt(uint64)", ("uint64",), (1,)))]))[0]
        row = (*row[:3], self.pins[self.floor_provider], self.configuration_hash, *row[5:])
        head = floor.next_head(floor.empty_head(self.hash_anchor), 1, row)
        self.add(self.floor, "sourceAt(uint64)", ("uint64",), (1,), (floor.SOURCE,), (row,))
        self.add(self.floor, "sourceSetHead()", (), (), ("uint64", "bytes32"), (1, head))
        self.add(self.floor, "sourceSetHashAt(uint64)", ("uint64",), (1,), ("bytes32",), (head,))
        self._event(floor.ADDED_EVENT)["data"] = "0x" + encode(("bytes32", floor.SOURCE, "uint16"), (head, row, 1)).hex()
        facts = list(self.first[8])
        if platform_works: facts = [ZERO] * 5 + [self.saved_rights["recordHash"], ZERO, True]
        else:
            facts[5] = self.saved_rights["recordHash"]
            facts[6] = self.native_hash if self.personhood_mode in ("waiver", "imported_waiver") else self.summary_hash
            if facts[6] == ZERO: facts[6] = K("historical unidentified personhood")
        first = (ZERO, *self.first[1:7], head, tuple(facts))
        self.first = (floor.receipt_hash(self.hash_anchor, floor.FIRST_DOMAIN, floor.FIRST, first), *first[1:])
        release = (ZERO, *self.release[1:8], head, *self.release[9:])
        self.release = (floor.receipt_hash(self.hash_anchor, floor.RELEASE_DOMAIN, floor.RELEASE, release), *release[1:])
        paid = (ZERO, *self.direct_receipt[1:9], self.first[0], self.release[0], self.direct_receipt[11])
        self.direct_receipt = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, paid), *paid[1:])
        self._paid_getters()
        for signature, kind, row in ((floor.FIRST_EVENT, floor.FIRST, self.first),
                (floor.RELEASE_EVENT, floor.RELEASE, self.release), (direct.DIRECT_EVENT, direct.DIRECT, self.direct_receipt)):
            event = self._event(signature); event["topics"][2] = row[0]
            event["data"] = "0x" + encode((kind, "uint16"), (row, 1)).hex()

    def floor_source(self):
        return direct.PublicDirectConservationSource(dumps(self.floor_anchor), self)

    @staticmethod
    def _capture(adapter, module, profile_hash):
        adapter.snapshot(); transcript = adapter.transcript()
        return module.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), profile_hash,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")

    def tier_capture(self): return self._capture(self.tier_source(), tier_capture, tier_source.PROFILE_HASH)
    def selection_capture(self): return self._capture(self.selection_source(), selection_capture, selection_source.PROFILE_HASH)
    def direct_floor_capture(self): return self._capture(self.floor_source(), direct_capture, direct.PROFILE_HASH)

    def direct_assembly(self):
        floor_capture, rights = self.direct_floor_capture(), self.rights_capture()
        joined = rights_binding.compose(dict(floor_capture.files), floor_capture.manifest_hash,
            dict(rights.files), rights.manifest_hash, disclosure="public")
        provider = self.provider_capture()
        bound = provider_binding.compose(dict(joined.files), joined.manifest_hash,
            dict(provider.files), provider.manifest_hash, disclosure="public")
        personhood = self.personhood_capture()
        return direct_personhood.compose(dict(bound.files), bound.manifest_hash,
            dict(personhood.files), personhood.manifest_hash, disclosure="public")

    def packages(self):
        return self.direct_assembly(), self.tier_capture(), self.selection_capture()
