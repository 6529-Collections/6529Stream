// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../mint/StreamSaleTemplate.sol";
import { StreamConsentedSaleTemplate } from "../mint/StreamConsentedSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativeRightsPrimarySettlement.sol";

/// @notice Context-aware collection-template projection for the explicitly new prepared entry.
/// @dev The signed opening policy and actual-token settlement policy are different coordinates.
library StreamPreparedNativeRightsProjection {
    function collectionTemplateForMode(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint8 mode
    ) public view returns (StreamSaleTemplate.Selection memory) {
        if (mode == StreamPreparedNativeRightsTypes.COLLECTION_TEMPLATE) {
            return collectionTemplate(resolver, collectionId);
        }
        if (mode != StreamPreparedNativeRightsTypes.CONSENTED_COLLECTION_TEMPLATE) {
            revert IStreamPreparedNativeRightsPrimarySettlement.UnsupportedPreparedNativeRightsMode();
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        return StreamConsentedSaleTemplate.preview(resolver, collectionId, a);
    }

    function preparedTemplateForMode(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint256 tokenId,
        uint8 mode
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 policy) {
        if (mode == StreamPreparedNativeRightsTypes.COLLECTION_TEMPLATE) {
            return preparedTemplate(resolver, collectionId, tokenId);
        }
        if (mode != StreamPreparedNativeRightsTypes.CONSENTED_COLLECTION_TEMPLATE) {
            revert IStreamPreparedNativeRightsPrimarySettlement.UnsupportedPreparedNativeRightsMode();
        }
        if (tokenId == 0) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            resolver.resolvePrimaryAssignment(collectionId, tokenId, keccak256("PRIMARY_SALE"));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(collection))) {
            revert IStreamPreparedNativeRightsPrimarySettlement.UnsupportedPreparedNativeRightsMode();
        }
        selected = StreamConsentedSaleTemplate.preview(resolver, collectionId, actual);
        policy = policyHash(resolver, collectionId, tokenId, selected);
    }

    function collectionTemplate(IStreamRevenueResolver resolver, uint256 collectionId)
        public
        view
        returns (StreamSaleTemplate.Selection memory)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        return StreamSaleTemplate.preview(resolver, collectionId, a);
    }

    function preparedTemplate(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint256 tokenId
    ) public view returns (StreamSaleTemplate.Selection memory selected, bytes32 policy) {
        if (tokenId == 0) {
            revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory actual =
            resolver.resolvePrimaryAssignment(collectionId, tokenId, keccak256("PRIMARY_SALE"));
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        if (keccak256(abi.encode(actual)) != keccak256(abi.encode(collection))) {
            revert IStreamPreparedNativeRightsPrimarySettlement.UnsupportedPreparedNativeRightsMode();
        }
        selected = StreamSaleTemplate.preview(resolver, collectionId, actual);
        policy = policyHash(resolver, collectionId, tokenId, selected);
    }

    /// @dev Exact original RSR PRIMARY_POLICY_V1 preimage with its actual resolution context.
    /// tokenId zero is used only by opening authorization; preparedTemplate rejects zero.
    function policyHash(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint256 tokenId,
        StreamSaleTemplate.Selection memory selected
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                keccak256("PRIMARY_SALE"),
                collectionId,
                tokenId,
                selected.templateId,
                selected.profileId,
                selected.wallet,
                selected.assignmentHash
            )
        );
    }
}
