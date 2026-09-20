"""Synthetic shared DIRECT/RIGHTS/provider/personhood response map for offline tests.

No bytes from an already captured package are edited.  Native-looking receipts
are independently assembled before all four concrete readers observe this map;
they are not actual-chain, payment, signature or personhood acceptance evidence.
"""
from copy import deepcopy

from . import conservation_provider_binding as binding
from . import public_conservation_floor_source as floor
from . import public_conservation_provider_capture as provider_capture
from . import public_conservation_provider_source as provider_source
from . import public_direct_conservation_source as direct
from . import public_personhood_capture as personhood_capture
from . import public_personhood_source as personhood_source
from .canonical import dumps, hex_bytes, keccak256
from .chain_abi import calldata, decode, encode
from .independent_wire import ZERO
from .test_conservation_provider_binding import ConservationProviderBindingFixture
from .test_public_personhood_source import PublicPersonhoodMixin, K
from .test_current_rights_source import A


class DirectPersonhoodFixture(PublicPersonhoodMixin, ConservationProviderBindingFixture):
    """Four independently replayable sources at one synthetic collection/block."""

    def __init__(self, *, personhood_mode="resolved", platform_works=False, family="direct",
            mode="joined", saved_artist=None, saved_personhood=None, product=direct.NATIVE, **kwargs):
        if product not in (direct.NATIVE, direct.ERC20, direct.AUCTION):
            raise ValueError("unknown synthetic DIRECT product")
        self.direct_product = product
        ConservationProviderBindingFixture.__init__(self, family=family, mode=mode, **kwargs)
        # The mixin's public source anchor replaces self.a; retain all original
        # exact closed anchor kinds before adding the new source observations.
        self.rights_anchor = deepcopy(self.rights_anchor)
        self.floor_anchor = deepcopy(self.floor_anchor)
        self.provider_anchor = deepcopy(self.a)
        self.setup_personhood(mode=personhood_mode)
        self.personhood_anchor = deepcopy(self.a)
        if self.first is not None and mode != "waived":
            self._bind_personhood(platform_works, saved_artist, saved_personhood)

    def _read(self, host, signature, inputs, args, outputs):
        return decode(outputs, hex_bytes(self.responses[(host, calldata(signature, inputs, args))]))

    def _event(self, signature):
        return next(event for receipt in self.receipts.values() for event in receipt["logs"]
            if event["address"] == self.floor and event["topics"][0] == signature)

    def _direct_bindings(self):
        return (*super()._direct_bindings()[:5], self.direct_product)

    def _direct_paid(self, key, stamp, tier, first_hash, release_hash):
        super()._direct_paid(key, stamp, tier, first_hash, release_hash)
        if self.direct_product == direct.NATIVE: return
        event = self._event(direct.DIRECT_EVENT)
        original = decode((direct.DIRECT, "uint16"), hex_bytes(event["data"]))[0]
        sale = list(original[7])
        # Auction creation is an earlier original fact, while fixed-price sale
        # creation occurs at payment. ERC20 retains an asset address only.
        if self.direct_product == direct.AUCTION: sale[9] -= 1
        else: sale[14] = A(9090)
        sale = tuple(sale)
        digest = direct.original_hash(original[6], self.floor_recorder, original[4], sale)
        row = (ZERO, *original[1:5], digest, original[6], sale, *original[8:])
        row = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, row), *row[1:])
        self.add(self.floor, "directPrimarySaleFloorReceipt(bytes32)", ("bytes32",), (key,), (direct.DIRECT,), (row,))
        self.add(self.floor_recorder, "directPrimarySaleReceipt(bytes32)", ("bytes32",), (row[4],), (direct.SALE,), (sale,))
        self.add(self.floor_recorder, "directPrimarySaleReceiptHash(bytes32)", ("bytes32",), (row[4],), ("bytes32",), (digest,))
        event["topics"][2] = row[0]
        event["data"] = "0x" + encode((direct.DIRECT, "uint16"), (row, 1)).hex()
        original_event = next(log for receipt in self.receipts.values() for log in receipt["logs"]
            if log["address"] == self.floor_recorder and log["topics"][0] == direct.ORIGINAL_EVENT)
        original_event["topics"][2] = digest
        original_event["data"] = "0x" + encode((direct.SALE, "uint16"), (sale, 1)).hex()

    def _bind_personhood(self, platform, saved_artist, saved_personhood):
        first = self.first
        if platform:
            facts = (ZERO, ZERO, ZERO, ZERO, ZERO, self.saved["recordHash"], ZERO, True)
        else:
            evidence = self.native_record[0] if self.personhood_mode in ("waiver", "imported_waiver") else self.summary_hash
            if evidence == ZERO: evidence = K("original historical personhood commitment not currently identifiable")
            facts = (self.artist_id if saved_artist is None else saved_artist, self.registration_hash,
                K("original documentary intent not captured by this bridge"), ZERO,
                K("original documentary interview not captured by this bridge"), self.saved["recordHash"],
                evidence if saved_personhood is None else saved_personhood, False)
        self.saved_first_facts = facts
        first = (ZERO, *first[1:8], facts)
        first = (floor.receipt_hash(self.hash_anchor, floor.FIRST_DOMAIN, floor.FIRST, first), *first[1:])
        self.first = first
        self.add(self.floor, "firstSale(uint256)", ("uint256",), (1,), (floor.FIRST,), (first,))
        event = self._event(floor.FIRST_EVENT)
        event["topics"][2] = first[0]
        event["data"] = "0x" + encode((floor.FIRST, "uint16"), (first, 1)).hex()

        # The release has its own context and immutable hash; personhood belongs
        # to FirstSale, so keep the actual independent release facts unchanged.
        release_event = self._event(floor.RELEASE_EVENT)
        release = decode((floor.RELEASE, "uint16"), hex_bytes(release_event["data"]))[0]
        self.release = release
        if self.family == "direct":
            event = self._event(direct.DIRECT_EVENT)
            original = decode((direct.DIRECT, "uint16"), hex_bytes(event["data"]))[0]
            row = (ZERO, *original[1:9], first[0], release[0], original[11])
            row = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, row), *row[1:])
            self.direct_receipt = row
            self.add(self.floor, "directPrimarySaleFloorReceipt(bytes32)", ("bytes32",), (row[3],), (direct.DIRECT,), (row,))
            event["topics"][2] = row[0]
            event["data"] = "0x" + encode((direct.DIRECT, "uint16"), (row, 1)).hex()
            # The original adapter's 16-field sale and original receipt hash are
            # still exact DIRECT facts, with no universal candidate projection.
        else:
            event = self._event(floor.SETTLEMENT_EVENT)
            original = decode((floor.SETTLEMENT, "uint16"), hex_bytes(event["data"]))[0]
            row = (ZERO, *original[1:10], first[0], release[0], original[12])
            row = (floor.receipt_hash(self.hash_anchor, floor.SETTLEMENT_DOMAIN, floor.SETTLEMENT, row), *row[1:])
            self.add(self.floor, "settlementReceipt(bytes32)", ("bytes32",), (row[3],), (floor.SETTLEMENT,), (row,))
            event["topics"][2] = row[0]
            event["data"] = "0x" + encode((floor.SETTLEMENT, "uint16"), (row, 1)).hex()

    def provider_capture(self):
        raw = dumps(self.provider_anchor)
        adapter = provider_source.PublicConservationProviderSource(raw, self)
        adapter.snapshot(); transcript = adapter.transcript()
        return provider_capture.replay(raw, keccak256(raw), provider_source.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")

    def personhood_capture(self):
        raw = dumps(self.personhood_anchor)
        adapter = personhood_source.PublicPersonhoodSource(raw, self)
        adapter.snapshot(); transcript = adapter.transcript()
        return personhood_capture.replay(raw, keccak256(raw), personhood_source.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")

    def binding_capture(self):
        original, provider = self.compose(), self.provider_capture()
        return binding.compose(dict(original.files), original.manifest_hash,
            dict(provider.files), provider.manifest_hash, disclosure="public")

    def packages(self):
        return self.binding_capture(), self.personhood_capture()
