// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeSettlementValidation.sol";
import "./StreamPrimarySettlementRights.sol";

/// @notice Concrete collection PROFILE projection for the first paid prepared-native increment.
/// @dev Actual token identity is supplied to the resolver; token/default/template branches reject.
library StreamPreparedNativeSettlementAccounting {
    function derive(
        StreamPrimarySettlementRights.Context memory x,
        StreamPreparedNativeSettlementTypes.Facts memory facts,
        StreamPreparedNativeSettlementTypes.Intent memory intent,
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected
        )
    {
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory a =
            x.resolver
                .resolvePrimaryAssignment(
                    facts.collectionId, facts.tokenId, keccak256("PRIMARY_SALE")
                );
        IStreamRevenueResolver.ResolvedPrimaryAssignment memory collection =
            x.resolver.resolvePrimaryAssignment(facts.collectionId, 0, keccak256("PRIMARY_SALE"));
        if (
            !a.exists || a.assignmentType != 1 || a.scope != 1 || a.scopeId != facts.collectionId
                || a.profileId == 0 || a.templateId != 0 || a.assignmentHash == 0
                || a.policyHash != 0
                || keccak256(abi.encode(a)) != keccak256(abi.encode(collection))
        ) {
            revert IStreamPreparedNativePrimarySaleSettlement.UnsupportedPreparedNativeRights();
        }
        selected = StreamSaleTemplate.Selection(
            a.profileId,
            x.factory.walletFor(a.profileId),
            0,
            a.assignmentHash,
            x.factory.profileEntriesHash(a.profileId)
        );
        StreamPrimarySettlementRights.requireWallet(x, selected);
        c.saleAdapter = facts.saleAdapter;
        c.executor = intent.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            intent.saleId,
            keccak256("PRIMARY_SALE"),
            intent.primaryPolicyMode,
            facts.collectionId,
            facts.tokenId,
            intent.saleNonce,
            intent.payer,
            intent.poster,
            intent.beneficiary,
            intent.amount,
            StreamSaleTemplate.policyHash(x.resolver, facts.collectionId, selected)
        );
        c.lifecycleBinding.saleCreatedAt = lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamPreparedNativeSettlementHash.executionId(facts, intent),
            intent.executionNonce,
            intent.authorityMode,
            intent.saleAuthorizationDigest
        );
        c.orchestrationOrder = 2;
        c.mintManager = facts.mintManager;
        c.operationIdentityCommitment = facts.operationRoot;
        c.operationId = facts.operationId;
        c.currentPolicyHash = facts.currentPolicyHash;
        c.boundPolicyHash = facts.boundPolicyHash;
        c.rights = StreamPrimarySettlementTypes.PrimaryRights(
            selected.profileId,
            selected.wallet,
            selected.templateId,
            selected.assignmentHash,
            selected.entriesHash
        );
        c.saleExecutionHash = intent.saleExecutionHash;
    }
}
