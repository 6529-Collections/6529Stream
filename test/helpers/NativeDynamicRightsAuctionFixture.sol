// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeConsentedRightsAuctionFixture.sol";
import {
    StreamArtistCollaboratorTypes as C
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCollaboratorTypes.sol";
import {
    IStreamDynamicPrimaryTemplates as D
} from "../../smart-contracts/interfaces/stream/revenue/IStreamDynamicPrimaryTemplates.sol";
import {
    IStreamArtistDynamicPrimaryTemplateFacts as F
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistDynamicPrimaryTemplateFacts.sol";

/// @dev Typed Artist boundary. Original accepted identities and exact assignment approvals are explicit.
contract NativeDynamicRightsArtist is NativeConsentedRightsArtist {
    C.Row[] private rows;
    mapping(bytes32 => address) private payouts;
    address public collaboratorFundingTrigger;
    address public collaboratorAfterFunding;
    bytes32 public changedIdentity;
    constructor(address c, address m) NativeConsentedRightsArtist(c, m) { }

    function setRows(C.Row[] calldata value) external {
        delete rows;
        for (uint256 i; i < value.length; ++i) {
            rows.push(value[i]);
        }
    }

    function setCollaboratorPayout(bytes32 id, address account) external {
        payouts[id] = account;
    }

    function changeCollaboratorAfterFunding(address trigger, bytes32 id, address account) external {
        collaboratorFundingTrigger = trigger;
        changedIdentity = id;
        collaboratorAfterFunding = account;
    }

    function collaboratorCount(uint256 collection, uint64 generation)
        external
        view
        returns (uint256)
    {
        require(collection == 1 && generation == 1, "typed current binding");
        return rows.length;
    }

    function collaboratorAt(uint256 collection, uint64 generation, uint256 index)
        external
        view
        returns (C.Row memory)
    {
        require(collection == 1 && generation == 1, "typed current row");
        return rows[index];
    }

    function collaboratorPayoutAccount(bytes32 id, address account)
        external
        view
        returns (address, bytes32)
    {
        bool linked;
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].accepted && rows[i].collaboratorArtistId == id && rows[i].account == account
            ) linked = true;
        }
        if (!linked) return (address(0), bytes32(0));
        address payout_ = collaboratorFundingTrigger != address(0)
            && collaboratorFundingTrigger.balance != 0 && changedIdentity == id
            ? collaboratorAfterFunding
            : payouts[id];
        return (
            payout_,
            payout_ == address(0)
                ? bytes32(0)
                : keccak256(abi.encode("collaborator designation", id, payout_))
        );
    }
}

abstract contract NativeDynamicRightsAuctionFixture is NativeRightsAuctionFixture {
    NativeDynamicRightsArtist internal dynamicArtist;
    bytes32 internal constant COLLAB_ONE = keccak256("actual typed collaborator one");
    bytes32 internal constant COLLAB_TWO = keccak256("actual typed collaborator two");

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        dynamicArtist = new NativeDynamicRightsArtist(address(core), address(manager));
        rightsArtist = dynamicArtist;
        return dynamicArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        dynamicArtist.setRows(_rows());
        dynamicArtist.setCollaboratorPayout(COLLAB_ONE, address(0xA77157));
        dynamicArtist.setCollaboratorPayout(COLLAB_TWO, address(0xC0B2));
        dynamicArtist.approve(
            address(resolver), resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash, true
        );
        dynamicArtist.enforceExactConsent();
        template = resolver.createDynamicPrimaryTemplate(
            _entries(), keccak256("symbolic dynamic terms"), _references()
        );
        bytes32 assignment =
            resolver.previewArtistDynamicPrimaryTemplateAssignment(1, template, 0, false)
        .assignmentHash;
        dynamicArtist.approve(address(resolver), assignment, true);
        require(
            resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, template, 0) == assignment,
            "actual bound dynamic setter"
        );
    }

    function _rows() internal pure returns (C.Row[] memory rows) {
        rows = new C.Row[](2);
        // Zero is a valid opaque role; each original account/role remains distinct.
        rows[0] = C.Row(
            address(0xC011), 0, keccak256("artist"), COLLAB_ONE, keccak256("accepted one"), true
        );
        rows[1] = C.Row(
            address(0xC012),
            keccak256("composer"),
            keccak256("composer-share"),
            COLLAB_TWO,
            keccak256("accepted two"),
            true
        );
    }

    function _references() internal pure returns (D.CollaboratorReference[] memory refs) {
        C.Row[] memory rows = _rows();
        refs = new D.CollaboratorReference[](2);
        for (uint256 i; i < 2; ++i) {
            refs[i] = D.CollaboratorReference(rows[i].account, rows[i].role, rows[i].shareLabelId);
        }
    }

    function _source(D.CollaboratorReference memory ref) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_COLLABORATOR_SOURCE_V1"),
                ref.account,
                ref.role,
                ref.shareLabelId
            )
        );
    }

    function _entries()
        internal
        pure
        returns (IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries)
    {
        D.CollaboratorReference[] memory refs = _references();
        entries = new IStreamRevenueResolver.PrimaryTemplateEntry[](5);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), 100000, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), _source(refs[0]), 200000, refs[0].shareLabelId
        );
        entries[2] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), _source(refs[1]), 300000, refs[1].shareLabelId
        );
        entries[3] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("SALE_POSTER"), 300000, keccak256("poster")
        );
        entries[4] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 100000, keccak256("protocol")
        );
    }

    function _selected() internal view override returns (StreamSaleTemplate.Selection memory) {
        return StreamPreparedNativeRightsProjection.collectionTemplateForPoster(
            resolver, 1, 3, address(this)
        );
    }

    function _original()
        internal
        view
        override
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        StreamSaleTemplate.Selection memory s = _selected();
        return StreamPreparedNativeRightsTypes.OriginalPolicy(3, s.assignmentHash, s.templateId);
    }
}
