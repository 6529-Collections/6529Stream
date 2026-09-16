// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativePricePrograms.sol";

/// @notice Additive same-leaf pricing for single-token native price programs.
/// @dev Existing sale authorization structs and EIP-712 domains remain unchanged.
interface IStreamNativeAllowlistPricePrograms {
    struct AllowlistPricePolicy {
        bytes32 counterId;
        bool allowFree; // Creation-time declaration for zero-priced fixed/open-edition tiers.
    }

    error InvalidAllowlistPricePolicy();
    error SalePriceOverrideZeroUndeclared(bytes32 saleId);

    event NativeAllowlistPricePolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bool allowFree,
        bytes32 saleConfigHash
    );

    function registerAllowlistPriceProgram(
        IStreamNativePricePrograms.PriceProgramConfig calldata config,
        AllowlistPricePolicy calldata policy
    ) external returns (bytes32 saleId);

    function allowlistPricePolicy(bytes32 saleId)
        external
        view
        returns (AllowlistPricePolicy memory);

    function previewAllowlistPriceProgram(
        IStreamNativePricePrograms.PriceProgramExecution calldata execution,
        bytes calldata resolverData
    ) external view returns (IStreamNativePricePrograms.PriceProgramResult memory);

    function executeAllowlistPriceProgram(
        IStreamNativePricePrograms.PriceProgramExecution calldata execution,
        bytes calldata resolverData
    ) external payable returns (IStreamNativePricePrograms.PriceProgramResult memory);
}
