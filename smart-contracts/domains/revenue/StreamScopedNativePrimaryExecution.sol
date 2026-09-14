// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamNativePrimaryExecution.sol";
import { StreamScopedSaleTemplate } from "../mint/StreamScopedSaleTemplate.sol";
import { StreamDefaultSaleTemplate } from "../mint/StreamDefaultSaleTemplate.sol";

library StreamScopedNativePrimaryExecution {
    function fund(
        StreamNativePrimaryExecution.Context memory x,
        uint256 collection,
        uint256 token,
        uint8 mode,
        address poster,
        uint256 amount,
        StreamSaleTemplate.Selection memory selected,
        bytes32 witness
    ) public returns (bool escrowed) {
        uint256 original = address(this).balance - msg.value;
        if (selected.templateId != 0) {
            if (mode >= 5 && mode <= 7) {
                StreamDefaultSaleTemplate.materialize(
                    x.rights.resolver, collection, token, mode, poster, selected, witness
                );
            } else {
                StreamScopedSaleTemplate.materialize(
                    x.rights.resolver, collection, token, mode, poster, selected, witness
                );
            }
        }
        StreamPrimarySettlementRights.requireWallet(x.rights, selected);
        uint256 cap = StreamNativeSettlementSupport.gasParameter(
            x.rights.factory, x.factoryHash, keccak256("6529STREAM_GGP_WALLET_DEPOSIT_GAS_LIMIT")
        );
        escrowed =
            StreamNativeSettlementSupport.fundNative(x.escrow, x.escrowHash, selected, amount, cap);
        if (address(this).balance != original) {
            revert StreamNativePrimaryExecution.SettlementAmountMismatch(address(0));
        }
    }
}
