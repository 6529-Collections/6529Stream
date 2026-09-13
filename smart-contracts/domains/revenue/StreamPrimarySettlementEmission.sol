// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";

/// @notice Canonical official settlement events emitted in the recorder's linked call context.
/// @dev Immediate calls supply equal expected/current hashes; deferred calls retain the purchase hash.
library StreamPrimarySettlementEmission {
    bytes32 private constant _CLASS = keccak256("PRIMARY_SALE");
    event PrimaryRevenueSettled(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        address wallet,
        address asset,
        address payer,
        uint256 amount,
        bytes32 saleContextHash,
        bool policyDrift,
        uint8 assignmentType
    );
    event PrimaryRevenueSettlementContext(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        address settlementCaller,
        bytes32 settlementId,
        uint8 policyMode,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 operationRoot,
        bytes32 operationId,
        uint256 saleNonce,
        address poster,
        address beneficiary,
        bytes32 templateId
    );
    event PrimaryRevenueSettlementPolicy(
        bytes32 indexed settlementKey,
        bytes32 indexed revenueClass,
        bytes32 indexed profileId,
        uint16 schemaVersion,
        bytes32 expectedPrimaryPolicyHash,
        bytes32 resolvedPrimaryPolicyHash,
        bytes32 resolvedAssignmentHash,
        bytes32 templateId
    );
    event PrimaryRevenueExecutionBound(
        bytes32 indexed settlementKey,
        address indexed saleAdapter,
        bytes32 indexed executionId,
        uint16 schemaVersion,
        address executor,
        address paymentAdapter,
        bytes32 candidateCommitment,
        bytes32 currentPolicyHash,
        bytes32 boundPolicyHash
    );

    struct ContextEventData {
        uint16 schemaVersion;
        address settlementCaller;
        bytes32 settlementId;
        uint8 policyMode;
        uint256 collectionId;
        uint256 tokenId;
        bytes32 operationRoot;
        bytes32 operationId;
        uint256 saleNonce;
        address poster;
        address beneficiary;
        bytes32 templateId;
    }
    bytes32 private constant _CONTEXT_EVENT = keccak256(
        "PrimaryRevenueSettlementContext(bytes32,bytes32,bytes32,uint16,address,bytes32,uint8,uint256,uint256,bytes32,bytes32,uint256,address,address,bytes32)"
    );

    function emitSettlement(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r,
        address paymentAdapter,
        bytes32 expectedPolicyHash
    ) public {
        emit PrimaryRevenueSettled(
            r.settlementKey,
            _CLASS,
            r.profileId,
            1,
            r.wallet,
            r.asset,
            c.sale.payer,
            r.amount,
            keccak256(abi.encode(c.sale)),
            expectedPolicyHash != c.sale.expectedPrimaryPolicyHash,
            c.rights.templateId == 0 ? 1 : 2
        );
        _emitContext(c, r);
        emit PrimaryRevenueSettlementPolicy(
            r.settlementKey,
            _CLASS,
            r.profileId,
            1,
            expectedPolicyHash,
            c.sale.expectedPrimaryPolicyHash,
            c.rights.assignmentHash,
            c.rights.templateId
        );
        emit PrimaryRevenueExecutionBound(
            r.settlementKey,
            c.saleAdapter,
            r.executionId,
            1,
            c.executor,
            paymentAdapter,
            r.candidateCommitment,
            c.currentPolicyHash,
            c.boundPolicyHash
        );
    }

    function _emitContext(
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory r
    ) private {
        ContextEventData memory context;
        context.schemaVersion = 1;
        context.settlementCaller = c.saleAdapter;
        context.settlementId = c.sale.settlementId;
        context.policyMode = c.sale.policyMode;
        context.collectionId = c.sale.collectionId;
        context.tokenId = c.sale.tokenId;
        context.operationRoot = c.operationIdentityCommitment;
        context.operationId = c.operationId;
        context.saleNonce = c.sale.saleNonce;
        context.poster = c.sale.poster;
        context.beneficiary = c.sale.beneficiary;
        context.templateId = c.rights.templateId;
        // A static tuple is the exact twelve nonindexed ABI words. Explicit LOG4 avoids
        // the legacy compiler's stack limit without changing the normative event layout.
        bytes memory data = abi.encode(context);
        bytes32 topic = _CONTEXT_EVENT;
        bytes32 key = r.settlementKey;
        bytes32 profile = r.profileId;
        bytes32 revenueClass = _CLASS;
        assembly ("memory-safe") {
            log4(add(data, 32), mload(data), topic, key, revenueClass, profile)
        }
    }
}
