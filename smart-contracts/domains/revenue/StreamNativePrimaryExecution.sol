// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativeSettlementSupport.sol";
import "./StreamPrimarySettlementRights.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";

/// @notice Fixed native funding body shared by the existing immediate and deferred recorder paths.
/// @dev Recorder retains validation, replay, post-callback admission, result and accounting order.
library StreamNativePrimaryExecution {
    error SettlementAmountMismatch(address asset);

    struct Context {
        StreamPrimarySettlementRights.Context rights;
        IStreamRevenueEscrow escrow;
        bytes32 escrowHash;
        bytes32 factoryHash;
    }

    function fund(
        Context memory x,
        uint256 collectionId,
        uint256 amount,
        StreamSaleTemplate.Selection memory selected
    ) public returns (bool escrowed) {
        uint256 original =
            address(this).balance - msg.value;
        StreamSaleTemplate.materialize(x.rights.resolver, collectionId, selected);
        StreamPrimarySettlementRights.requireWallet(x.rights, selected);
        uint256 cap = StreamNativeSettlementSupport.gasParameter(
            x.rights.factory, x.factoryHash, keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT")
        );
        escrowed =
            StreamNativeSettlementSupport.fundNative(x.escrow, x.escrowHash, selected, amount, cap);
        if (address(this).balance != original) revert SettlementAmountMismatch(address(0));
    }
}
