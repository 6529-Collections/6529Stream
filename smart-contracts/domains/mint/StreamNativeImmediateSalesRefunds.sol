// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeImmediateSalesState.sol";

/// @notice Payer-owned reveal credits in the guarded immediate adapter's storage context.
/// @dev Fixed compiler link preserves caller, balance, events and atomic refund effects.
library StreamNativeImmediateSalesRefunds {
    event SalePaymentExcessCredited(
        uint16 schemaVersion, bytes32 indexed saleId, address indexed payer, uint256 amount
    );
    event SaleRefundClaimed(
        uint16 schemaVersion,
        bytes32 indexed saleId,
        address indexed payer,
        address indexed recipient,
        uint256 amount
    );

    function claim(
        StreamNativeImmediateSalesState.State storage state,
        bytes32 id,
        address recipient
    ) public {
        uint256 amount = state.refunds[id][msg.sender];
        if (amount == 0) revert IStreamImmediateSaleReveal.SaleRefundEmpty(id, msg.sender);
        if (recipient == address(0) || recipient == address(this)) {
            revert IStreamImmediateSaleReveal.SaleRefundTransferFailed(recipient);
        }
        uint256 before_ = address(this).balance;
        if (before_ < state.refundLiability) {
            revert IStreamImmediateSaleReveal.SaleRevealAccountingMismatch();
        }
        delete state.refunds[id][msg.sender];
        state.refundLiability -= amount;
        bool ok;
        assembly ("memory-safe") { ok := call(gas(), recipient, amount, 0, 0, 0, 0) }
        if (!ok) revert IStreamImmediateSaleReveal.SaleRefundTransferFailed(recipient);
        if (address(this).balance != before_ - amount) {
            revert IStreamImmediateSaleReveal.SaleRevealAccountingMismatch();
        }
        emit SaleRefundClaimed(1, id, msg.sender, recipient, amount);
    }

    function credit(
        StreamNativeImmediateSalesState.State storage state,
        bytes32 id,
        address payer,
        uint256 amount
    ) public {
        if (amount == 0) return;
        if (!state.refundSeen[id][payer]) {
            state.refundSeen[id][payer] = true;
            state.refundSales.push(id);
            state.refundPayers.push(payer);
        }
        state.refunds[id][payer] += amount;
        state.refundLiability += amount;
        emit SalePaymentExcessCredited(1, id, payer, amount);
    }
}
