// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeRightsValidation.sol";
import "./StreamPreparedNativeRightsProjection.sol";
import "./StreamPrimarySettlementRights.sol";

/// @notice Current collection TEMPLATE accounting with the actual prepared token policy coordinate.
library StreamPreparedNativeRightsAccounting {
    function derive(
        StreamPrimarySettlementRights.Context memory x,
        StreamPreparedNativeRightsTypes.Facts memory rights,
        StreamPreparedNativeRightsTypes.Intent memory original,
        StreamNativeSettlementTypes.SaleLifecycleBinding memory lifecycle
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            StreamSaleTemplate.Selection memory selected,
            bytes32 beneficiaryHash
        )
    {
        StreamPreparedNativeSettlementTypes.Facts memory facts = rights.mint;
        StreamPreparedNativeSettlementTypes.Intent memory intent = original.sale;
        bytes32 policy;
        (selected, policy, beneficiaryHash) =
            StreamPreparedNativeRightsProjection.preparedTemplateForPoster(
                x.resolver, facts.collectionId, facts.tokenId, original.original.mode, intent.poster
            );
        // A template preview can name a profile not yet materialized. The fixed funding
        // worker verifies Factory registration and wallet identity after actual materialization.
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
            policy
        );
        c.lifecycleBinding.saleCreatedAt = lifecycle.saleCreatedAt;
        c.lifecycleBinding.saleAdapterRegistryRevision = lifecycle.saleAdapterRegistryRevision;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            StreamPreparedNativeRightsHash.executionId(rights, original),
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
