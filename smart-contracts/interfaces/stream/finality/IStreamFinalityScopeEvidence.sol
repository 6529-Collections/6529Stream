// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";
import "./StreamFinalityEvidenceTypes.sol";

/// @notice Additional validating metadata reads; the original five metadata reads remain intact.
interface IStreamFinalityScopeEvidence {
    /// @notice Actual ERC-721 Core whose scope and retained token membership this host validates.
    function core() external view returns (address);

    /// @notice Validates the exact scope inputs and independent manifest against stored evidence.
    /// @dev Reverts for an unknown scope, incomplete applicable evidence, wrong authority/schema,
    ///      stale selected references or insufficient actual payload coverage. The render-critical
    ///      set and its coverage are derived from host inventory, never a caller-supplied list.
    ///      The finality manifest may commit the resulting inputs, but its content hash is excluded
    ///      from the independent inputs commitment. Its returned schema/canonicalization facts
    ///      belong to the actual validated manifest, preventing a caller from relabeling its bytes.
    function requireFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestContentHash
    )
        external
        view
        returns (
            StreamFinalityScopeInputs memory inputs,
            bytes32 manifestSchemaId,
            bytes32 manifestCanonicalizationHash
        );
}
