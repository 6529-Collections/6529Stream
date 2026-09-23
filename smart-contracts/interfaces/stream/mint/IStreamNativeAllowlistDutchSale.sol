// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeDutchSale.sol";

/// @notice Additive same-leaf price ceilings for single-token native Dutch sales.
/// @dev Existing Dutch configuration tuples and authorization domains remain unchanged.
interface IStreamNativeAllowlistDutchSale {
    error InvalidAllowlistDutchPolicy();
    error SalePriceOverrideZeroUndeclared(bytes32 saleId);

    event DutchAllowlistPricePolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bool declaredFree,
        bytes32 saleConfigHash
    );

    function registerAllowlistDutchSale(
        IStreamNativeDutchSale.DutchSaleConfig calldata config,
        bytes32 counterId
    ) external returns (bytes32 saleId);

    function allowlistPriceCounter(bytes32 saleId) external view returns (bytes32);

    function purchaseWithAllowlist(
        IStreamNativeDutchSale.DutchPurchaseData calldata purchaseData,
        bytes calldata resolverData
    ) external payable returns (IStreamNativeDutchSale.DutchPurchaseResult memory);
}
