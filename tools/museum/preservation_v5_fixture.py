"""One synthetic response map for nine original captures; no native execution claim."""
from . import acquisition_attribution_v5 as attribution
from . import acquisition_direct_conservation as direct_assembly
from . import acquisition_packet_v5 as packet_v5
from . import public_attribution_capture as attribution_capture
from . import public_conservation_floor_source as floor
from . import public_conservation_tier_source as tier
from . import public_direct_conservation_source as direct
from . import public_media_master_source as media
from . import public_prospective_reference_source as prospective
from . import public_prospective_reference_capture as prospective_capture
from .canonical import MuseumError, dumps, keccak256, loads
from .chain_abi import encode
from .independent_wire import ZERO
from .test_current_rights_source import A, H
from .test_public_attribution_source import PublicAttributionFixture
from .test_public_media_master_source import MediaMasterMixin
from .test_public_prospective_reference_source import ProspectiveReferenceMixin
from ..metadata.test_acquisition_packet_v5 import supplied


class PreservationV5Fixture(MediaMasterMixin, ProspectiveReferenceMixin, PublicAttributionFixture):
    def __init__(self, *, master_mode="present", reference_mode="baseline", raised=False, full=True):
        super().__init__()
        self.setup_media(master_mode)
        reference_host = A(26000)
        # The prospective fixture installs these exact synthetic bytes below.
        self.codes[reference_host] = b"synthetic905 prospective publication"
        self.pins[reference_host] = keccak256(self.codes[reference_host])
        targets, hashes = list(self.configuration[0]), list(self.configuration[1])
        targets[6], hashes[6] = self.media_master, self.pins[self.media_master]
        targets[9], hashes[9] = reference_host, self.pins[reference_host]
        self.configuration = (tuple(targets), tuple(hashes), *self.configuration[2:])
        self._rewrite_floor(False)
        self.provider_anchor["configurationHash"] = self.configuration_hash
        self.provider_anchor["codePins"] += [{"address": reference_host, "runtimeHash": hashes[9]}]
        self.reference_media_choice = self.media_manifests[0]
        self.setup_prospective_reference(reference_mode, host=reference_host, raised=raised)
        saved_context = self.prospective_release_context
        first_media = self.media_manifests[0]
        selections = [rows[0] if rows else media.EMPTY_SELECTION for rows in self.media_selections.values()]
        archives = [ZERO if row[0] != 1 else next(item["archiveHash"] for item in self.media_coverages
            if item["coverage"][0] == row[9]) for row in selections]
        try:
            saved_media = media.evidence_hash(self.media_anchor, first_media["hash"], first_media["inventoryHash"],
                first_media["hashes"], self.media_association, selections, archives)
        except MuseumError:
            if master_mode != "absent": raise
            saved_media = keccak256(b"synthetic unobserved original master evidence")
        saved_reference = self.prospective_rows[0]["evidenceHash"] if self.prospective_rows else keccak256(b"synthetic missing original reference")
        if full:
            self.add(self.core, "declaredConservationTier(uint256)", ("uint256",), (1,), ("bytes32",), (floor.FULL,))
            self.event(2, self.core, [tier.CORE_TIER_EVENT, H(1), floor.FULL, self.topic("address", A(91))], ("uint16",), (1,))
            self.event(2, A(91), [tier.FACADE_TIER_EVENT, H(1), floor.FULL], ("uint16",), (1,))
        effective_tier = floor.FULL if full else self.first[2]
        first = (ZERO, self.first[1], effective_tier, *self.first[3:])
        self.first = (floor.receipt_hash(self.hash_anchor, floor.FIRST_DOMAIN, floor.FIRST, first), *first[1:])
        release = (ZERO, floor.release_key(self.hash_anchor, 1, saved_context), 1, effective_tier,
            *self.release[4:9], saved_context, (saved_context[4], saved_media, saved_reference))
        self.release = (floor.receipt_hash(self.hash_anchor, floor.RELEASE_DOMAIN, floor.RELEASE, release), *release[1:])
        paid = (ZERO, *self.direct_receipt[1:8], effective_tier, self.first[0], self.release[0], self.direct_receipt[11])
        self.direct_receipt = (floor.receipt_hash(self.hash_anchor, direct.DIRECT_DOMAIN, direct.DIRECT, paid), *paid[1:])
        self._paid_getters()
        for signature, kind, row in ((floor.FIRST_EVENT, floor.FIRST, self.first),
                (floor.RELEASE_EVENT, floor.RELEASE, self.release), (direct.DIRECT_EVENT, direct.DIRECT, self.direct_receipt)):
            event = self._event(signature); event["topics"][2] = row[0]
            if signature == floor.RELEASE_EVENT: event["topics"][1] = row[1]
            event["data"] = "0x" + encode((kind, "uint16"), (row, 1)).hex()
        if master_mode in ("replaced", "manifest_changed"):
            self.reference_media_choice = self.media_manifests[-1]
            self.prospective_source = self._prospective_source_capsule()
            self._prospective_heads()
        self.add(self.media_anchor["router"], "collectionServingSource(uint256)", ("uint256",), (1,),
            (media.SERVING,), (self.prospective_source[9],))

    def _prospective_source_capsule(self):
        original = list(super()._prospective_source_capsule())
        selected = self.reference_media_choice; manifest = selected["manifest"]
        original[13], original[14] = selected["hash"], manifest
        original[9] = (*original[9][:2], manifest[1], *original[9][3:])
        original[8] = (*original[8][:7], keccak256(manifest[1].encode()), *original[8][8:])
        context = list(original[3]); context[2] = selected["inventoryHash"]
        context[1] = prospective.hash_abi(("bytes32", "uint256", "address", "uint256", "bytes32", "bytes32", "bytes32"),
            (prospective.schema_id("6529STREAM_CONSERVATION_COLLECTION_RELEASE_V1"), 31337, self.core, 1,
                context[0], context[2], context[3]))
        mask = sum(1 << index for index, value in enumerate(selected["hashes"]) if value != ZERO)
        context[4] = prospective.hash_abi(("bytes32", "bytes32", "bytes32", "uint8", prospective.SOURCE[8], "bytes32"),
            (original[2][4], original[13], original[11], mask, original[8], context[1]))
        original[3] = tuple(context)
        return tuple(original)

    def preservation_inputs(self):
        components = self.packages()
        direct_packet = direct_assembly.compose(*sum(([value.files, value.manifest_hash] for value in components), []), disclosure="public")
        packet = supplied(direct_packet)
        snapshot = loads(self.source().snapshot(), maximum=32 * 1024 * 1024)
        packet["attribution"]["binding"]["record"]["recordHash"] = snapshot["current"]["binding"][3]
        raw = dumps(packet)
        packet_assembly = packet_v5.compose(direct_packet.files, direct_packet.manifest_hash, raw, keccak256(raw), disclosure="public")
        adapter = self.source(); adapter.snapshot(); transcript = adapter.transcript()
        attr = attribution_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), attribution_capture._source().PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        old = attribution.compose(packet_assembly.files, packet_assembly.manifest_hash, attr.files, attr.manifest_hash, disclosure="public")
        adapter = self.prospective_source_adapter(); adapter.snapshot(); transcript = adapter.transcript()
        reference = prospective_capture.replay(adapter.anchor_bytes, keccak256(adapter.anchor_bytes), prospective.PROFILE_HASH,
            transcript, keccak256(transcript), provenance="synthetic_fixture", disclosure="public")
        return old, self.media_capture(), reference
