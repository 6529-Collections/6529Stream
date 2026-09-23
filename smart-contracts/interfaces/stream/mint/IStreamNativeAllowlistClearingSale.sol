// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamNativeClearingSale.sol";

/// @notice Same-leaf proof ingress for the existing signed native clearing ceiling.
interface IStreamNativeAllowlistClearingSale {
    error InvalidClearingAllowlistPolicy();
    error ClearingAllowlistPriceMismatch(
        bool provenFlag, uint256 provenPrice, bool signedFlag, uint256 signedPrice
    );
    event NativeClearingAllowlistPolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bytes32 saleConfigHash
    );
    function registerAllowlistClearingSale(
        IStreamNativeClearingSale.ClearingSaleConfig calldata config,
        bytes32 counterId
    ) external returns (bytes32);
    function allowlistPriceCounter(bytes32 saleId) external view returns (bytes32);
    function purchaseWithAllowlist(
        IStreamNativeClearingSale.ClearingPurchaseData calldata data,
        bytes calldata resolverData
    ) external payable returns (IStreamNativeClearingSale.ClearingPurchaseResult memory);
}
