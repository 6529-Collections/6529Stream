// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable public program and in-progress token candidate evidence read by the recorder.
interface IStreamERC20PublicSaleBinding {
    /// @dev Original StreamPrimarySettlementHash candidate commitment includes payment adapter and recorder.
    function activePublicERC20Candidate(bytes32 executionId)
        external
        view
        returns (bytes32 candidateCommitment);

    function publicERC20SaleBinding(bytes32 saleId)
        external
        view
        returns (uint256 collectionId, bytes32 phaseId, bytes32 configHash, uint8 authorityMode);
}
