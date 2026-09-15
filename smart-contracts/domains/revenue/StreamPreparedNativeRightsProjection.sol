// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../mint/StreamSaleTemplate.sol";
import "../mint/StreamPlatformSaleTemplate.sol";
import "./StreamDefaultPrimaryProfile.sol";
import "./StreamPlatformPrimaryProfile.sol";
import { StreamDefaultSaleTemplate } from "../mint/StreamDefaultSaleTemplate.sol";
import { StreamDynamicSaleTemplate } from "../mint/StreamDynamicSaleTemplate.sol";
import { StreamConsentedSaleTemplate } from "../mint/StreamConsentedSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPreparedNativeRightsPrimarySettlement.sol";

/// @notice Context-aware collection-template projection for the explicitly new prepared entry.
/// @dev The signed opening policy and actual-token settlement policy are different coordinates.
library StreamPreparedNativeRightsProjection {
    function collectionTemplateForPoster(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint8 mode,
        address poster
    ) public view returns (StreamSaleTemplate.Selection memory s) {
        if (mode == 10 || mode == 11) {
            (s,) = StreamPlatformPrimaryProfile.resolve(resolver, collectionId, 0, mode, poster);
            return s;
        }
        if (mode == 8 || mode == 9) {
            (s,) = StreamPlatformSaleTemplate.resolve(resolver, collectionId, 0, mode, poster);
            return s;
        }
        if (mode >= 5 && mode <= 7) {
            (s,) = StreamDefaultSaleTemplate.resolve(resolver, collectionId, 0, mode, poster);
            return s;
        }
        if (mode != StreamPreparedNativeRightsTypes.DYNAMIC_COLLECTION_TEMPLATE) {
            return collectionTemplateForMode(resolver, collectionId, mode);
        }
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        (s,) = StreamDynamicSaleTemplate.preview(resolver, collectionId, poster, a);
    }

    function preparedTemplateForPoster(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint256 tokenId,
        uint8 mode,
        address poster
    ) public view returns (StreamSaleTemplate.Selection memory s, bytes32 policy, bytes32 witness) {
        if (mode == 10 || mode == 11) {
            if (tokenId == 0) {
                revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
            }
            (s, witness) =
                StreamPlatformPrimaryProfile.resolve(resolver, collectionId, tokenId, mode, poster);
            return (s, policyHash(resolver, collectionId, tokenId, s), witness);
        }
        if (mode == 8 || mode == 9) {
            if (tokenId == 0) {
                revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
            }
            (s, witness) =
                StreamPlatformSaleTemplate.resolve(resolver, collectionId, tokenId, mode, poster);
            return (s, policyHash(resolver, collectionId, tokenId, s), witness);
        }
        if (mode >= 5 && mode <= 7) {
            if (tokenId == 0) {
                revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
            }
            (s, witness) =
                StreamDefaultSaleTemplate.resolve(resolver, collectionId, tokenId, mode, poster);
            return (s, policyHash(resolver, collectionId, tokenId, s), witness);
        }
        if (mode != StreamPreparedNativeRightsTypes.DYNAMIC_COLLECTION_TEMPLATE) {
            (s, policy) = preparedTemplateForMode(resolver, collectionId, tokenId, mode);
            return (s, policy, 0);
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
        (s, witness) = StreamDynamicSaleTemplate.preview(resolver, collectionId, poster, actual);
        policy = policyHash(resolver, collectionId, tokenId, s);
    }

    function collectionTemplateForMode(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint8 mode
    ) public view returns (StreamSaleTemplate.Selection memory) {
        if (mode == 5 || mode == 6) {
            (StreamSaleTemplate.Selection memory selected,) =
                StreamDefaultSaleTemplate.resolve(resolver, collectionId, 0, mode, address(0));
            return selected;
        }
        if (mode == StreamPreparedNativeRightsTypes.DEFAULT_PROFILE) {
            return StreamDefaultPrimaryProfile.resolve(resolver, collectionId, 0);
        }
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
        if (mode == 5 || mode == 6) {
            if (tokenId == 0) {
                revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
            }
            (selected,) = StreamDefaultSaleTemplate.resolve(
                resolver, collectionId, tokenId, mode, address(0)
            );
            return (selected, policyHash(resolver, collectionId, tokenId, selected));
        }
        if (mode == StreamPreparedNativeRightsTypes.DEFAULT_PROFILE) {
            if (tokenId == 0) {
                revert IStreamPreparedNativeRightsPrimarySettlement.InvalidPreparedNativeRights();
            }
            selected = StreamDefaultPrimaryProfile.resolve(resolver, collectionId, tokenId);
            policy = policyHash(resolver, collectionId, tokenId, selected);
            return (selected, policy);
        }
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
