// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamPreparedNativeMint.sol";
import "./StreamPreparedNativeContentTypes.sol";

/// @notice Distinct entry semantics for the original SSA-CONTENT context and selection leaf.
interface IStreamPreparedNativeContentMint {
    function executePreparedNativeContentMint(
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
    function activePreparedNativeContent()
        external
        view
        returns (StreamPreparedNativeContentTypes.Facts memory);
    function preparedNativeContentAdmission() external view returns (bytes32);
}

interface IStreamPreparedNativeContentSale {
    function activePreparedNativeContentIntent(bytes32 hash)
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Intent memory);
    function onPreparedNativeContentMint(StreamPreparedNativeSettlementTypes.Facts calldata facts)
        external
        returns (bytes4, StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}

interface IStreamPreparedNativeContentSettlement {
    function settlePreparedNativeContentSale(
        StreamPreparedNativeSettlementTypes.Facts calldata facts,
        StreamPreparedNativeSettlementTypes.Intent calldata intent
    ) external payable returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
    function preparedNativeContentHash(bytes32 settlementKey) external view returns (bytes32);
}
