// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original public program and in-progress execution evidence read by the native recorder.
interface IStreamNativePublicSaleBinding {
    function activePublicNativeCandidate(bytes32 executionId)
        external
        view
        returns (bytes32 candidateCommitment);

    function publicNativeSaleBinding(bytes32 saleId)
        external
        view
        returns (uint256 collectionId, bytes32 phaseId, bytes32 configHash, uint8 authorityMode);
}
