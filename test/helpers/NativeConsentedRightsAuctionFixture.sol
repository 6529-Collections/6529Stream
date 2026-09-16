// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./NativeRightsAuctionFixture.sol";
import {
    IStreamArtistTemplateEconomicsAuthority
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistTemplateEconomicsAuthority.sol";

/// @dev Explicit typed consent boundary, not the Artist operation-15 implementation. Keys bind
/// the actual caller Resolver, current binding generation and complete original assignment key.
contract NativeConsentedRightsArtist is NativeRightsAuctionArtist {
    bool public exactConsent;
    uint64 public bindingGeneration = 1;
    address public consentFundingTrigger;
    mapping(bytes32 => bool) private approvals;

    constructor(address c, address m) NativeRightsAuctionArtist(c, m) { }

    function supportsInterface(bytes4 id) public pure override returns (bool) {
        return id == type(IStreamArtistTemplateEconomicsAuthority).interfaceId
            || super.supportsInterface(id);
    }

    function enforceExactConsent() external {
        exactConsent = true;
    }

    function nextBinding() external {
        ++bindingGeneration;
    }

    function failConsentAfterFunding(address trigger) external {
        consentFundingTrigger = trigger;
    }

    function approve(address resolver, bytes32 assignmentHash, bool value) external {
        approvals[_key(resolver, 1, keccak256("PRIMARY_SALE"), 1, 1, assignmentHash)] = value;
    }

    function requireEconomicsConsent(
        uint256 collection,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) external view override {
        require(consent, "artist economics");
        if (exactConsent) {
            require(
                approvals[_key(
                        msg.sender, collection, revenueClass, scope, scopeId, assignmentHash
                    )],
                "current exact typed consent"
            );
            require(
                consentFundingTrigger == address(0) || consentFundingTrigger.balance == 0,
                "consent changed during funding"
            );
        }
    }

    function _key(
        address resolver,
        uint256 collection,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                resolver,
                collection,
                bindingGeneration,
                revenueClass,
                scope,
                scopeId,
                assignmentHash
            )
        );
    }
}

abstract contract NativeConsentedRightsAuctionFixture is NativeRightsAuctionFixture {
    NativeConsentedRightsArtist internal consentArtist;

    function _deployAuctionArtist() internal override returns (NativeAuctionArtist) {
        consentArtist = new NativeConsentedRightsArtist(address(core), address(manager));
        rightsArtist = consentArtist;
        return consentArtist;
    }

    function setUp() public virtual override {
        super.setUp();
        bytes32 initial = resolver.resolvePrimaryAssignment(1, 0, CLASS).assignmentHash;
        consentArtist.approve(address(resolver), initial, true);
        consentArtist.enforceExactConsent();
        template = _approveTemplate(1, keccak256("consented one ppm"));
    }

    /// @dev The real Resolver's bound setter consumes the exact typed current consent;
    /// unlike the initial fixture setup, no Artist unbind is used for this transition.
    function _approveTemplate(uint32 share, bytes32 terms) internal returns (bytes32 id) {
        IStreamRevenueResolver.PrimaryTemplateEntry[] memory entries =
            new IStreamRevenueResolver.PrimaryTemplateEntry[](2);
        entries[0] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0), keccak256("COLLECTION_ARTIST"), share, keccak256("artist")
        );
        entries[1] = IStreamRevenueResolver.PrimaryTemplateEntry(
            address(0xFEE), 0, 1000000 - share, keccak256("protocol")
        );
        id = resolver.createPrimaryTemplate(entries, terms);
        bytes32 original =
            resolver.previewArtistPrimaryTemplateConsentAssignment(1, id, 0, false).assignmentHash;
        require(artists.artist() == vm.addr(SIGNER_KEY), "original Artist remains bound");
        consentArtist.approve(address(resolver), original, true);
        require(
            resolver.setPrimaryTemplateAssignment(CLASS, 1, 1, id, 0) == original,
            "actual bound setter matches approved original key"
        );
    }

    function _selected() internal view override returns (StreamSaleTemplate.Selection memory) {
        return StreamPreparedNativeRightsProjection.collectionTemplateForMode(resolver, 1, 2);
    }

    function _original()
        internal
        view
        override
        returns (StreamPreparedNativeRightsTypes.OriginalPolicy memory)
    {
        StreamSaleTemplate.Selection memory selected = _selected();
        return StreamPreparedNativeRightsTypes.OriginalPolicy(
            2, selected.assignmentHash, selected.templateId
        );
    }
}
