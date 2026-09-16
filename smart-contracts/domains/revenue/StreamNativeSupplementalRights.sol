// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrimarySettlementRights.sol";
import "../../interfaces/stream/revenue/IStreamNativeSupplementalSettlement.sol";

/// @notice Post-mint resolution uses the actual token, preserving resolver precedence and consent.
/// @dev Current provider restrictions for nominated token/default scopes are propagated, never bypassed.
library StreamNativeSupplementalRights {
    function resolve(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        StreamPrimarySettlementTypes.PrimaryRights memory claimed,
        bytes32 expected
    ) public view returns (StreamSaleTemplate.Selection memory r) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            _assignment(x.resolver, collectionId, tokenId);
        if (a.assignmentType == 1) {
            if (a.profileId == 0 || a.templateId != 0) {
                revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
            }
            r = StreamSaleTemplate.Selection(
                a.profileId,
                x.factory.walletFor(a.profileId),
                0,
                a.assignmentHash,
                x.factory.profileEntriesHash(a.profileId)
            );
        } else if (a.assignmentType == 2) {
            if (a.profileId != 0 || a.templateId == 0) {
                revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
            }
            IStreamArtistPrimaryTemplateFacts(address(x.resolver))
                .primaryTemplateEconomicsFacts(a.templateId);
            (r.profileId, r.wallet, r.entriesHash) =
                x.resolver.previewCollectionPrimaryProfile(a.templateId, collectionId, address(0));
            r.templateId = a.templateId;
            r.assignmentHash = a.assignmentHash;
        } else {
            revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        }
        if (
            r.profileId == 0 || r.wallet == address(0) || r.entriesHash == 0
                || keccak256(abi.encode(r)) != keccak256(abi.encode(claimed))
        ) {
            revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        }
        if (policyHash(x.resolver, collectionId, tokenId, r) != expected) {
            revert IStreamNativeSupplementalSettlement.SupplementalPolicyMismatch();
        }
        if (r.templateId == 0) StreamPrimarySettlementRights.requireWallet(x, r);
    }

    function policyHash(
        IStreamRevenueResolver resolver,
        uint256 collectionId,
        uint256 tokenId,
        StreamSaleTemplate.Selection memory r
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PRIMARY_POLICY_V1"),
                block.chainid,
                address(resolver),
                keccak256("PRIMARY_SALE"),
                collectionId,
                tokenId,
                r.templateId,
                r.profileId,
                r.wallet,
                r.assignmentHash
            )
        );
    }

    function materialize(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        StreamSaleTemplate.Selection memory r
    ) public {
        _requireAssignment(x, collectionId, tokenId, r);
        if (r.templateId == 0) {
            StreamPrimarySettlementRights.requireWallet(x, r);
            return;
        }
        (bytes32 profile, address wallet, bytes32 entries) = x.resolver
            .materializeCollectionPrimaryProfile(r.templateId, collectionId, address(0), false);
        if (profile != r.profileId || wallet != r.wallet || entries != r.entriesHash) {
            revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        }
        requireCurrent(x, collectionId, tokenId, r);
    }

    /// @dev Recheck assignment and immutable concrete rights without re-observing a dynamic payout.
    function requireCurrent(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        StreamSaleTemplate.Selection memory r
    ) public view {
        _requireAssignment(x, collectionId, tokenId, r);
        StreamPrimarySettlementRights.requireWallet(x, r);
    }

    function _requireAssignment(
        StreamPrimarySettlementRights.Context memory x,
        uint256 collectionId,
        uint256 tokenId,
        StreamSaleTemplate.Selection memory r
    ) private view {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            _assignment(x.resolver, collectionId, tokenId);
        if (
            a.assignmentHash != r.assignmentHash || a.templateId != r.templateId
                || (r.templateId == 0 && (a.assignmentType != 1 || a.profileId != r.profileId))
                || (r.templateId != 0 && (a.assignmentType != 2 || a.profileId != 0))
        ) {
            revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        }
    }

    function _assignment(IStreamRevenueResolver resolver, uint256 collectionId, uint256 tokenId)
        private
        view
        returns (IStreamRevenueResolver.ResolvedPrimaryAssignment memory a)
    {
        if (tokenId == 0) revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        a = resolver.resolvePrimaryAssignment(collectionId, tokenId, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.assignmentHash == 0 || a.policyHash != 0
                || !((a.scope == 0 && a.scopeId == 0)
                    || (a.scope == 1 && a.scopeId == collectionId)
                    || (a.scope == 2 && a.scopeId == tokenId))
        ) {
            revert IStreamNativeSupplementalSettlement.SupplementalRightsMismatch();
        }
    }
}
