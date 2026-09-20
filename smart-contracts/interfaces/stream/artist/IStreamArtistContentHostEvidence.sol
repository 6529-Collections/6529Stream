// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Explicit host-bound evidence for original op17 content consent.
/// @dev Original metadata-only reads and op21 freeze admission are unchanged.
interface IStreamArtistContentHostEvidence {
    /// @notice Returns the original consent record after current binding and host-pin validation.
    /// @dev Entropy admission is restricted to keccak256("6529STREAM_ENTROPY_RECOVERY_V1")
    /// and keccak256("6529STREAM_ENTROPY_CONFIGURATION_V1") on the selected coordinator.
    /// The host independently binds the exact subject and resulting state, and consumes the
    /// returned record once. This read does not authorize another host or perform a mutation.
    function contentConsentEvidenceForHost(
        uint256 collectionId,
        address contentHost,
        bytes32 familyId,
        bytes32 newStateHash
    ) external view returns (bytes32 recordHash);
}
