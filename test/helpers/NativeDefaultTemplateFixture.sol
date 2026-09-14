// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./NativeCustodyRightsBatchFixture.sol";
import {
    StreamDefaultSaleTemplate
} from "../../smart-contracts/domains/mint/StreamDefaultSaleTemplate.sol";

/// @dev Shared test construction only. Actual Resolver/Factory calls retain the fixture owner.
library NativeDefaultTemplateBuilder {
    function select(StreamRevenueResolver resolver, CustodyRightsBatchArtist artist, uint8 mode)
        internal
        returns (bytes32 id, bytes32 hash)
    {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory e;
        if (mode == 7) {
            BC.Row[] memory rows = new BC.Row[](1);
            rows[0] = BC.Row(
                address(0xC011),
                0,
                keccak256("default composer"),
                keccak256("default collaborator"),
                keccak256("accepted default row"),
                true
            );
            artist.setRows(rows);
            artist.setCollaboratorPayout(rows[0].collaboratorArtistId, address(0xC0B));
            BD.CollaboratorReference[] memory refs = new BD.CollaboratorReference[](1);
            refs[0] = BD.CollaboratorReference(rows[0].account, rows[0].role, rows[0].shareLabelId);
            bytes32 source = keccak256(
                abi.encode(
                    keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                    rows[0].account,
                    rows[0].role,
                    rows[0].shareLabelId
                )
            );
            e = new IStreamRevenueResolver.PrimaryTemplateEntry[](3);
            e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("COLLECTION_ARTIST"), 100000, keccak256("artist")
            );
            e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), source, 800000, rows[0].shareLabelId
            );
            e[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("SALE_POSTER"), 100000, keccak256("poster")
            );
            id = resolver.createDynamicPrimaryTemplate(e, keccak256("default dynamic terms"), refs);
        } else {
            require(mode == 5 || mode == 6, "explicit default template family");
            e = new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
            uint32 share = mode == 5 ? 900000 : 1;
            e[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
            );
            // Low-take remainder is a co-signed community grant, not a >10% genesis protocol fee.
            e[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
                address(0xFEE),
                0,
                1000000 - share,
                mode == 5 ? keccak256("protocol") : keccak256("community")
            );
            id = resolver.createPrimaryTemplate(e, keccak256(abi.encode("default template", mode)));
        }
        hash = resolver.setPrimaryTemplateAssignment(keccak256("PRIMARY_SALE"), 0, 0, id, 0);
        artist.approveScope(address(resolver), 1, 0, 0, hash, true);
    }
}

abstract contract NativeDefaultTemplateAuctionFixture is NativeRightsAuctionFixture {
    CustodyRightsBatchArtist internal defaultArtist;
    uint8 internal defaultMode;
    bytes32 internal selectedDefault;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        defaultArtist = new CustodyRightsBatchArtist(address(core), address(manager));
        rightsArtist = defaultArtist;
        return defaultArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        _setDefault(5);
    }

    function _setDefault(uint8 mode) internal {
        defaultMode = mode;
        (, selectedDefault) = NativeDefaultTemplateBuilder.select(resolver, defaultArtist, mode);
        resolver.setPrimaryProfileAssignment(CLASS, 1, 1, profile, 0);
        resolver.clearPrimaryAssignment(CLASS, 1, 1);
    }

    function _selected() internal view override returns (StreamSaleTemplate.Selection memory s) {
        (s,) = StreamDefaultSaleTemplate.resolve(resolver, 1, 0, defaultMode, address(this));
    }

    function _original()
        internal
        view
        override
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        StreamSaleTemplate.Selection memory s = _selected();
        return
            StreamPreparedNativeRightsTypes.OriginalPolicy(
                defaultMode, s.assignmentHash, s.templateId
            );
    }
}
