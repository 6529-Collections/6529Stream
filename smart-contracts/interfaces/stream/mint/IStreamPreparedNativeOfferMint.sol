// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamPreparedNativeContentMint.sol";
import "./StreamPreparedNativeOfferTypes.sol";

/// @notice Atomic positive native primary offers with optional original selected-content proof.
interface IStreamPreparedNativeOfferMint {
    function executePreparedNativeOfferMint(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata offerGateData,
        bytes32 intentHash
    )
        external
        returns (
            uint256 tokenId,
            bytes32 operationRoot,
            bytes32 operationId,
            StreamPrimarySettlementTypes.PrimarySettlementResult memory result
        );

    function preparedNativeOfferAdmission() external view returns (bytes32);
    function activePreparedNativeOfferContent()
        external
        view
        returns (StreamPreparedNativeContentTypes.Facts memory);
}

interface IStreamPreparedNativeOfferSale {
    function activePreparedNativeOfferIntent(bytes32 intentHash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory);
    function activePreparedNativeOfferPurchase(bytes32 intentHash)
        external
        view
        returns (StreamPreparedNativeOfferTypes.Purchase memory);
    function onPreparedNativeOfferMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external
        returns (bytes4 magic, StreamPrimarySettlementTypes.PrimarySettlementResult memory result);

    /// @notice Immutable historical seller membership, unaffected by live providers or sale status.
    function primaryOfferAuthorizationBinding(bytes32 saleId)
        external
        view
        returns (
            uint256 collectionId,
            bytes32 phaseId,
            address signer,
            uint8 signerKind,
            bytes32 saleConfigHash
        );
}

interface IStreamPreparedNativeOfferSettlement {
    error PreparedNativeOfferAlreadySettled(address adapter, bytes32 purchaseId);
    event PreparedNativeOfferRecorded(
        uint16 schemaVersion,
        address indexed adapter,
        bytes32 indexed purchaseId,
        bytes32 indexed settlementKey,
        bytes32 saleId,
        uint256 saleNonce,
        bytes32 offerDigest,
        bytes32 authorizationDigest
    );

    function settlePreparedNativeOffer(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);

    function preparedNativeOfferConsumed(address adapter, bytes32 purchaseId)
        external
        view
        returns (bool);
}
