// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";

/// @notice Preparation read implemented by the actual selected recovery companion.
/// @dev This is a caller subset, not a replacement for the companion's primary module interface.
interface IStreamArtistRecoveryIntent {
    struct Facts {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        bytes32 requestHash;
    }

    function core() external view returns (address);
    function originalFinalityRegistry() external view returns (address);

    /// @notice Validate actual staged canonical intent, original finality and current route lineage.
    /// @dev All four results are derived from that exact stored request, never caller assertions.
    ///      The returned request commitment excludes artist/owner evidence heads, avoiding a cycle
    ///      with approval or finding records subsequently created for this exact recovery action.
    ///      Reverts for missing bytes, malformed/unsupported scope, drift or any mismatched hash.
    function requireArtistRecoveryIntent(
        StreamFinalityScope calldata scope,
        bytes32 originalFinalityRecordHash,
        bytes32 recoveryManifestHash
    ) external view returns (Facts memory);
}
