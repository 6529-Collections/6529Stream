// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamPrimarySettlementRights.sol";

/// @notice Explicit default PROFILE route; actual resolver precedence and collection consent still apply.
library StreamDefaultPrimaryProfile {
    function resolve(IStreamRevenueResolver resolver, uint256 collection, uint256 token)
        public
        view
        returns (StreamSaleTemplate.Selection memory s)
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            resolver.resolvePrimaryAssignment(collection, token, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.scope != 0 || a.scopeId != 0 || a.assignmentType != 1 || a.profileId == 0
                || a.templateId != 0 || a.assignmentHash == 0 || a.policyHash != 0
        ) revert IStreamPrimarySaleSettlement.PrimarySettlementRightsMismatch();
        IStreamSplitFactory factory = IStreamSplitFactory(resolver.splitFactory());
        s = StreamSaleTemplate.Selection(
            a.profileId,
            factory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            factory.profileEntriesHash(a.profileId)
        );
        StreamPrimarySettlementRights.requireWallet(
            StreamPrimarySettlementRights.Context(
                resolver, factory, factory.splitWalletRuntimeCodeHash()
            ),
            s
        );
    }
}
