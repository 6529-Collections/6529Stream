// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamNativeRefundWindowSale.sol";

/// @notice Captured same-leaf prices for deferred native refund-window purchases.
/// @dev The original authorization remains unchanged; price and proof facts are additive.
interface IStreamNativeAllowlistRefundWindowSale {
    struct AllowlistPricePolicy {
        bytes32 counterId;
        bool allowFree;
    }

    error InvalidAllowlistRefundPolicy();
    error RefundPriceOverrideZeroUndeclared(bytes32 saleId);

    event NativeRefundAllowlistPricePolicy(
        bytes32 indexed saleId,
        bytes32 indexed counterId,
        uint16 schemaVersion,
        bool allowFree,
        bytes32 saleConfigHash
    );
    event RefundPurchasePriceBound(
        bytes32 indexed purchaseId,
        uint256 chargedPrice,
        bytes32 resolverDataHash,
        bytes32 purchaseRecordHash
    );

    function registerAllowlistRefundSale(
        IStreamNativeRefundWindowSale.RefundSaleConfig calldata config,
        AllowlistPricePolicy calldata policy
    ) external returns (bytes32 saleId);

    function purchaseAllowlistRefundWindow(
        IStreamNativeRefundWindowSale.RefundPurchaseData calldata data,
        bytes calldata resolverData
    ) external payable returns (bytes32 purchaseId);

    function allowlistRefundSalePolicy(bytes32 saleId)
        external
        view
        returns (AllowlistPricePolicy memory);

    function refundPurchasePriceFacts(bytes32 purchaseId)
        external
        view
        returns (bool captured, uint256 chargedPrice, bytes32 resolverDataHash);

    function refundPurchaseResolverData(bytes32 purchaseId) external view returns (bytes memory);
}
