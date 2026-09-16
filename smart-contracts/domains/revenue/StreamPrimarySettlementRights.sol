// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../mint/StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";

/// @notice Linked exact rights reads for the official recorder; supplied context is its immutable context.
library StreamPrimarySettlementRights {
    struct Context {
        IStreamRevenueResolver resolver;
        IStreamSplitFactory factory;
        bytes32 walletHash;
    }
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");

    function resolve(
        Context memory x,
        uint256 collectionId,
        StreamPrimarySettlementTypes.PrimaryRights memory claimed,
        bytes32 policyHash
    ) public view returns (StreamSaleTemplate.Selection memory rights) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            x.resolver.resolvePrimaryAssignment(collectionId, 0, _CLASS);
        if (a.assignmentType == 2) {
            rights = StreamSaleTemplate.preview(x.resolver, collectionId, a);
        } else {
            if (
                !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                    || a.profileId == 0 || a.templateId != 0 || a.assignmentHash == 0
                    || a.policyHash != 0
            ) revert IStreamPrimarySaleSettlement.PrimarySettlementRightsMismatch();
            rights = StreamSaleTemplate.Selection(
                a.profileId,
                x.factory.walletFor(a.profileId),
                0,
                a.assignmentHash,
                x.factory.profileEntriesHash(a.profileId)
            );
        }
        if (keccak256(abi.encode(rights)) != keccak256(abi.encode(claimed))) {
            revert IStreamPrimarySaleSettlement.PrimarySettlementRightsMismatch();
        }
        if (StreamSaleTemplate.policyHash(x.resolver, collectionId, rights) != policyHash) {
            revert IStreamPrimarySaleSettlement.PrimarySettlementPolicyMismatch();
        }
    }

    function requireCurrent(
        Context memory x,
        uint256 collectionId,
        StreamPrimarySettlementTypes.PrimaryRights memory claimed,
        bytes32 policyHash,
        StreamSaleTemplate.Selection memory rights
    ) public view {
        if (rights.templateId != 0) {
            StreamSaleTemplate.requireCurrent(x.resolver, collectionId, rights);
        } else {
            resolve(x, collectionId, claimed, policyHash);
        }
        requireWallet(x, rights);
    }

    function requireWallet(Context memory x, StreamSaleTemplate.Selection memory rights)
        public
        view
    {
        if (
            x.factory.walletFor(rights.profileId) != rights.wallet
                || !x.factory.profileExists(rights.profileId)
                || (rights.wallet.code.length == 0 && rights.templateId == 0)
                || (rights.wallet.code.length != 0
                    && (rights.wallet.codehash != x.walletHash
                        || !x.factory.splitWalletExists(rights.profileId)))
        ) {
            revert IStreamPrimarySaleSettlement.PrimarySettlementRightsMismatch();
        }
    }
}
