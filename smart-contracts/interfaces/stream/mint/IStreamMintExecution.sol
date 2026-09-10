// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamMintManager.sol";

/// @notice Atomic immediate and prepared token mint execution through the manager.
/// @dev Caller ABI at the manager address. Use IStreamMintManager for ERC165
///      discovery and canonical nested request types; subset IDs are not advertised.
interface IStreamMintExecution {
    /// @notice Executes the immediate Core manager path atomically.
    /// @dev The caller must be an authorized executor for the phase. Any downstream failure
    ///      reverts all token allocation, ledger consumption, and replay-state changes.
    /// @param batch Canonical manager request; parallel token arrays must have matching lengths.
    /// @param gateData Opaque verification bytes interpreted by the configured phase gate.
    /// @return tokenIds Globally allocated Core token identifiers in request order.
    /// @return operationRoot Commitment binding the complete normalized mint operation.
    /// @return operationIds Ordered per-token operation identities.
    function executeSingleStepMint(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    )
        external
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds);

    /// @notice Executes the prepared Core manager path atomically.
    /// @dev Uses the same phase authorization and atomicity rules as executeSingleStepMint.
    /// @param batch Canonical manager request and expected phase-policy commitment.
    /// @param gateData Opaque verification bytes interpreted by the configured phase gate.
    /// @return tokenIds Globally allocated Core token identifiers in request order.
    /// @return operationRoot Commitment binding the complete normalized mint operation.
    /// @return operationIds Ordered per-token operation identities.
    function executePreparedMint(
        IStreamMintManager.MintBatch calldata batch,
        bytes calldata gateData
    )
        external
        returns (uint256[] memory tokenIds, bytes32 operationRoot, bytes32[] memory operationIds);
}
