// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamDeferredNativeSettlementAdmission.sol";
import "./StreamDeferredNativeSettlementHash.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";

/// @notice Exact deferred-native admission, separate from either immediate funding entry.
library StreamDeferredNativeSettlementValidation {
    struct Bindings {
        address core;
        address registry;
        address resolver;
        address escrow;
    }

    function validate(
        Bindings memory x,
        StreamDeferredNativeSettlementTypes.DeferredNativeCandidate memory d
    ) public view {
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c = d.execution;
        if (
            msg.sender != c.saleAdapter || c.saleAdapter == address(0) || c.executor == address(0)
                || c.sale.settlementId == 0 || c.sale.revenueClass != keccak256("PRIMARY_SALE")
                || c.sale.policyMode != 1 || c.sale.collectionId == 0 || c.sale.tokenId != 0
                || c.sale.saleNonce == 0 || c.sale.payer == address(0)
                || c.sale.payer == address(this) || c.sale.payer == c.saleAdapter
                || c.sale.payer == c.rights.wallet || c.sale.payer == x.escrow
                || c.sale.beneficiary == address(0) || c.sale.amount == 0
                || msg.value != c.sale.amount || c.sale.expectedPrimaryPolicyHash == 0
                || c.orchestrationOrder != 1 || c.executionBinding.authorityMode != 1
                || c.executionBinding.executionNonce == 0
                || c.executionBinding.saleAuthorizationDigest == 0
                || c.operationIdentityCommitment == 0 || c.operationId == 0
                || c.currentPolicyHash == 0 || c.boundPolicyHash == 0
                || c.saleExecutionHash != d.purchaseRecordHash || d.purchaseRecordHash == 0
                || d.purchaseId == 0 || d.originalPrimaryPolicyHash == 0
                || c.executionBinding.executionId
                    != StreamDeferredNativeSettlementHash.executionId(d)
        ) revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        uint256 refund = uint256(d.nominalRefundDeadline) + d.pauseToll;
        uint256 finalDeadline = uint256(d.nominalFinalizeBy) + d.pauseToll;
        if (refund > d.absoluteEscapeDeadline) refund = d.absoluteEscapeDeadline;
        if (finalDeadline > d.absoluteEscapeDeadline) finalDeadline = d.absoluteEscapeDeadline;
        if (
            d.nominalRefundDeadline == 0 || d.nominalFinalizeBy <= d.nominalRefundDeadline
                || d.nominalFinalizeBy > d.maximumNominalFinalizeBy
                || d.nominalFinalizeBy > d.absoluteEscapeDeadline
                || d.effectiveRefundDeadline != refund || d.effectiveFinalizeBy != finalDeadline
                || block.timestamp < refund || block.timestamp > finalDeadline
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
        StreamDeferredNativeSettlementAdmission.requireAdmission(x.registry, c);
        requireBindings(x, c);
        if (
            _word(
                    c.saleAdapter,
                    abi.encodeCall(
                        IStreamDeferredNativeSaleBinding.activeDeferredNativeSettlement,
                        (d.purchaseId)
                    )
                )
                != uint256(StreamDeferredNativeSettlementHash.candidateCommitment(address(this), d))
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    function requireBindings(
        Bindings memory x,
        StreamNativeSettlementTypes.NativeSettlementCandidate memory c
    ) public view {
        if (
            _word(c.saleAdapter, abi.encodeWithSignature("primarySaleSettlement()"))
                    != uint256(uint160(address(this)))
                || _word(c.saleAdapter, abi.encodeWithSignature("core()"))
                    != uint256(uint160(x.core))
                || _word(c.saleAdapter, abi.encodeWithSignature("moduleRegistry()"))
                    != uint256(uint160(x.registry))
                || _word(c.saleAdapter, abi.encodeWithSignature("revenueResolver()"))
                    != uint256(uint160(x.resolver))
                || _word(c.saleAdapter, abi.encodeWithSignature("mintManager()"))
                    != uint256(uint160(c.mintManager))
                || !StreamSettlementAdmission.isContract(c.mintManager)
                || _word(c.mintManager, abi.encodeWithSignature("core()"))
                    != uint256(uint160(x.core))
                || _word(c.mintManager, abi.encodeWithSignature("moduleRegistry()"))
                    != uint256(uint160(x.registry))
        ) {
            revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
        }
    }

    function _word(address target, bytes memory data) private view returns (uint256 value) {
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), target, add(data, 32), mload(data), 0, 32)
            size := returndatasize()
            value := mload(0)
        }
        if (!ok || size != 32) revert IStreamPrimarySaleSettlement.InvalidPrimarySale();
    }
}
