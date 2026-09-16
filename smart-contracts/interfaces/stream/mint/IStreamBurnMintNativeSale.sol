// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamNativeFixedPriceSaleAdapter as N } from "./IStreamNativeFixedPriceSaleAdapter.sol";
import { StreamPrimarySettlementTypes as S } from "../revenue/StreamPrimarySettlementTypes.sol";

/// @notice Additive native purchase entry; the original payer, executor and refund owner are unchanged.
interface IStreamBurnMintNativeSale {
    function purchaseWithBurn(
        N.SaleExecutionData calldata execution,
        uint256[] calldata sourceTokenIds
    ) external payable returns (S.PrimarySettlementResult memory result, uint256 tokenId);

    /// @notice One exact callback admitted only inside this adapter's purchaseWithBurn context.
    function executeBurnPurchase(
        N.SaleExecutionData calldata execution,
        address buyer,
        uint256 suppliedValue,
        uint256[] calldata sourceTokenIds
    ) external returns (S.PrimarySettlementResult memory result, uint256 tokenId);
}

/// @notice Gate owns the guarded burn -> typed sale callback -> consumed-proof lifetime.
interface IStreamBurnMintNativeExecutor {
    function executeNativeBurn(
        N.SaleExecutionData calldata execution,
        address buyer,
        uint256 suppliedValue,
        uint256[] calldata sourceTokenIds
    ) external returns (S.PrimarySettlementResult memory result, uint256 tokenId);
}
