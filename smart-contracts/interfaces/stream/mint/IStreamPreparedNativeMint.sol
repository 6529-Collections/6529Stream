// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";
import "../revenue/StreamPrimarySettlementTypes.sol";
import "../revenue/StreamPreparedNativeSettlementTypes.sol";

/// @notice Additive same-transaction paid prepared execution; existing Manager interfaces are intact.
interface IStreamPreparedNativeMint {
    error InvalidPreparedNativeMint();
    error PreparedNativeCallFailed(address target, bytes4 selector);
    error PreparedNativeResultMismatch();
    error InsufficientPreparedNativeGas(uint256 available, uint256 required);
    error PreparedNativeRecorderAlreadyBound();
    event PreparedNativeRecorderBound(
        address indexed recorder, bytes32 runtimeCodeHash, uint64 boundAt, uint64 moduleRevision
    );

    /// @notice Owner selects the official recorder once, after the dependency graph is deployed.
    /// @dev Stored pins avoid a constructor/runtime cycle. No sale may nominate an alternate 9.
    function bindPreparedNativeRecorder(address recorder) external;
    function preparedNativeRecorder()
        external
        view
        returns (address recorder, bytes32 runtimeCodeHash, uint64 boundAt, uint64 moduleRevision);

    function previewPreparedNativeMintOperation(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    ) external view returns (bytes32 operationRoot, bytes32[] memory operationIds);

    function executePreparedNativeMint(
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

    /// @notice Zero outside the one Manager-owned operation; never a persisted preparation ticket.
    function activePreparedNativeMint()
        external
        view
        returns (StreamPreparedNativeSettlementTypes.Facts memory);
}
