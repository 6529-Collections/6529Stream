// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Canonical names derived from this Metadata host's authenticated scope publications.
/// @dev Registration grants no writing authority, token membership, sanction or finality readiness.
/// Existing Metadata V1 selectors and interface identifier remain unchanged.
interface IStreamMetadataPublishedScopeSubject {
    event MetadataScopeSubjectRegistered(
        bytes32 indexed subjectId,
        uint256 indexed collectionId,
        bytes32 indexed membershipRecordHash,
        uint8 scopeType,
        bytes32 scopeId
    );

    /// @notice Authenticate the original scope record and register its RELEASE, SEASON or VIEW name.
    /// @dev The only input is a record on this host. The full scope is derived, never caller asserted.
    /// Idempotent; consuming contracts must still require complete authenticated membership.
    function registerScopeSubject(bytes32 membershipRecordHash) external returns (bytes32 subjectId);
}
