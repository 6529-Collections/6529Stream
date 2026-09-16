// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamBurnMintNativeExecutor,
    N,
    S
} from "../../interfaces/stream/mint/IStreamBurnMintNativeSale.sol";
import { IStreamMintManager as M } from "../../interfaces/stream/mint/IStreamMintManager.sol";

/// @notice Linked, one-use native burn callback binding; the adapter retains payment and settlement.
/// @dev Uses only the appended adapter context slot. Mutable direct library CALL is rejected by Solidity.
library StreamNativeBurnCallback {
    struct Context {
        bytes32 commitment;
    }

    struct Binding {
        address core;
        address manager;
        address gate;
        bytes32 saleConfigHash;
        address buyer;
        uint256 suppliedValue;
        bytes32 executionHash;
        bytes32 sourcesHash;
    }

    function purchase(
        Context storage context,
        mapping(bytes32 => N.SaleRecord) storage sales,
        address core,
        M manager,
        bytes calldata input
    ) external returns (S.PrimarySettlementResult memory result, uint256 tokenId) {
        (N.SaleExecutionData memory execution, uint256[] memory sources) =
            abi.decode(input[4:], (N.SaleExecutionData, uint256[]));
        N.SaleRecord storage sale = sales[execution.authorization.saleId];
        M.MintGateConfig memory gateConfig =
            manager.phaseGate(sale.config.collectionId, sale.config.phaseId);
        address gate = gateConfig.gate;
        if (gate.code.length == 0 || gate.codehash != gateConfig.gateCodehash) {
            revert N.InvalidNativeSale();
        }
        context.commitment = _hash(
            Binding(
                core,
                address(manager),
                gate,
                sale.configHash,
                msg.sender,
                msg.value,
                keccak256(abi.encode(execution)),
                keccak256(abi.encode(sources))
            )
        );
        (result, tokenId) = IStreamBurnMintNativeExecutor(gate)
            .executeNativeBurn(execution, msg.sender, msg.value, sources);
        if (context.commitment != keccak256(abi.encode(result, tokenId))) {
            revert N.NativeMintResultInvalid();
        }
        delete context.commitment;
    }

    function consume(
        Context storage context,
        mapping(bytes32 => N.SaleRecord) storage sales,
        address core,
        M manager,
        bytes calldata input
    ) external {
        (
            N.SaleExecutionData memory execution,
            address buyer,
            uint256 suppliedValue,
            uint256[] memory sources
        ) = abi.decode(input[4:], (N.SaleExecutionData, address, uint256, uint256[]));
        N.SaleRecord storage sale = sales[execution.authorization.saleId];
        if (
            context.commitment == 0
                || context.commitment
                    != _hash(
                        Binding(
                            core,
                            address(manager),
                            msg.sender,
                            sale.configHash,
                            buyer,
                            suppliedValue,
                            keccak256(abi.encode(execution)),
                            keccak256(abi.encode(sources))
                        )
                    )
        ) {
            revert N.InvalidNativeSale();
        }
        delete context.commitment;
    }

    function _hash(Binding memory binding) private view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_BURN_CALLBACK_V1"),
                block.chainid,
                address(this),
                binding
            )
        );
    }
}
