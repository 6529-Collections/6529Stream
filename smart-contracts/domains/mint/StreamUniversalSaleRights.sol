// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamSaleTemplate.sol";
import "../../interfaces/stream/revenue/IStreamSplitFactory.sol";
import "../../interfaces/stream/mint/IStreamUniversalFixedPriceSaleAdapter.sol";

/// @notice Exact fixed-PROFILE selection extracted from the universal consumer for code size.
/// @dev No funding, mutation, template admission or new authority is introduced.
library StreamUniversalSaleRights {
    function rights(
        IStreamRevenueResolver resolver,
        IStreamSplitFactory factory,
        uint256 collectionId
    ) public view returns (StreamSaleTemplate.Selection memory selected) {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != collectionId
                || a.templateId != 0 || a.profileId == 0 || a.assignmentHash == 0
                || a.policyHash != 0 || !factory.splitWalletExists(a.profileId)
        ) revert IStreamUniversalFixedPriceSaleAdapter.InvalidUniversalSale();
        return StreamSaleTemplate.Selection(
            a.profileId,
            factory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            factory.profileEntriesHash(a.profileId)
        );
    }
}
