// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamPreparedNativeContentMint.sol";
import "./StreamPreparedNativeContentPurchaseTypes.sol";

/// @notice Repeatable positive-price content purchases; the auction entry remains separate.
interface IStreamPreparedNativeContentPurchaseMint {
    function executePreparedNativeContentPurchaseMint(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData,
        bytes32 intentHash
    )
        external
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        );
}

interface IStreamPreparedNativeContentPurchaseSale {
    /// @notice Exact active immutable sale and purchase bindings, only while the intent executes.
    function activePreparedNativeContentPurchase(bytes32 intentHash)
        external
        view
        returns (StreamPreparedNativeContentPurchaseTypes.Purchase memory);
}

interface IStreamPreparedNativeContentPurchaseSettlement {
    error PreparedNativeContentPurchaseAlreadySettled(address adapter, bytes32 purchaseId);
    event PreparedNativeContentPurchaseRecorded(
        uint16 schemaVersion,
        address indexed adapter,
        bytes32 indexed purchaseId,
        bytes32 indexed settlementKey,
        bytes32 saleId,
        uint256 saleNonce
    );

    function settlePreparedNativeContentPurchase(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function preparedNativeContentPurchaseConsumed(address adapter, bytes32 purchaseId)
        external
        view
        returns (bool);
}
