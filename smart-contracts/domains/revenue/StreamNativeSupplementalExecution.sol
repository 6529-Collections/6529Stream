// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeSupplementalValidation.sol";
import "./StreamNativeSupplementalRights.sol";
import "./StreamNativeSettlementSupport.sol";
import "./StreamPrimarySettlementEmission.sol";

/// @notice Fixed linked financial funding/result construction; no storage slot or arbitrary callback.
/// @dev Recorder owns all replay/accounting and passes its immutable pins into this delegatecall.
library StreamNativeSupplementalExecution {
    event NativeSupplementalRevenueSettled(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed buyer,
        StreamNativeSupplementalTypes.NativeSupplementalResult result
    );

    struct Context {
        StreamPrimarySettlementRights.Context rights;
        IStreamRevenueEscrow escrow;
        bytes32 escrowHash;
        bytes32 factoryHash;
    }

    function fund(
        Context memory x,
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        bytes32 key,
        uint256 amount
    ) public returns (StreamNativeSupplementalTypes.NativeSupplementalResult memory r) {
        StreamSaleTemplate.Selection memory selected = StreamNativeSupplementalRights.resolve(
            x.rights,
            c.originalFloor.sale.collectionId,
            c.purchase.tokenId,
            c.currentRights,
            c.currentPrimaryPolicyHash
        );
        uint256 original = address(this).balance - msg.value;
        StreamNativeSupplementalRights.materialize(
            x.rights, c.originalFloor.sale.collectionId, c.purchase.tokenId, selected
        );
        bool escrowed = _fund(x, selected, amount);
        if (address(this).balance != original) {
            revert IStreamNativeSupplementalSettlement.InvalidNativeSupplementalSettlement();
        }
        StreamNativeSupplementalRights.requireCurrent(
            x.rights, c.originalFloor.sale.collectionId, c.purchase.tokenId, selected
        );
        r.candidateCommitment = StreamNativeSupplementalHash.candidateCommitment(address(this), c);
        r.settlementKey = key;
        r.purchaseId = c.purchaseId;
        r.originalFloorSettlementKey = c.purchase.floorSettlementKey;
        r.tokenId = c.purchase.tokenId;
        r.profileId = selected.profileId;
        r.wallet = selected.wallet;
        r.amount = amount;
        r.executor = c.executor;
        r.executionId = StreamNativeSupplementalHash.executionId(address(this), c);
        r.escrowed = escrowed;
        r.originalOperationRoot = c.originalFloor.operationIdentityCommitment;
        r.originalOperationId = c.originalFloor.operationId;
        r.originalExpectedPrimaryPolicyHash = c.originalFloor.sale.expectedPrimaryPolicyHash;
        r.currentPrimaryPolicyHash = c.currentPrimaryPolicyHash;
        r.policyDrift = r.originalExpectedPrimaryPolicyHash != r.currentPrimaryPolicyHash;
    }

    function _fund(Context memory x, StreamSaleTemplate.Selection memory selected, uint256 amount)
        private
        returns (bool)
    {
        uint256 cap = StreamNativeSettlementSupport.gasParameter(
            x.rights.factory, x.factoryHash, keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT")
        );
        return
            StreamNativeSettlementSupport.fundNative(x.escrow, x.escrowHash, selected, amount, cap);
    }

    function commonResult(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r
    ) public pure returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory) {
        return StreamPrimarySettlementTypes.PrimarySettlementResult(
            r.candidateCommitment,
            r.settlementKey,
            r.profileId,
            r.wallet,
            address(0),
            r.amount,
            r.executor,
            r.executionId,
            r.escrowed,
            r.originalOperationRoot,
            c.originalFloor.currentPolicyHash,
            c.originalFloor.boundPolicyHash
        );
    }

    function emitResult(
        StreamNativeSupplementalTypes.NativeSupplementalCandidate memory c,
        StreamNativeSupplementalTypes.NativeSupplementalResult memory r,
        StreamPrimarySettlementTypes.PrimarySettlementResult memory common
    ) public {
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory context =
            StreamNativeSettlementHash.accountingContext(c.originalFloor);
        context.sale.policyMode = 1;
        context.sale.tokenId = r.tokenId;
        context.sale.amount = r.amount;
        context.sale.expectedPrimaryPolicyHash = r.currentPrimaryPolicyHash;
        context.rights = c.currentRights;
        context.executor = r.executor;
        context.executionBinding.executionId = r.executionId;
        context.orchestrationOrder = 0; // No new mint order: events reference the original mint identity.
        StreamPrimarySettlementEmission.emitSettlement(
            context, common, address(0), r.originalExpectedPrimaryPolicyHash
        );
        emit NativeSupplementalRevenueSettled(
            1, c.originalFloor.sale.settlementId, c.purchaseId, c.originalFloor.sale.payer, r
        );
    }
}
