// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original observed-reference evidence and separate current local lock status.
/// @dev Exact full original payload/coverage validation belongs to the pinned publication host.
///      A passing read does not prove arbitrary JavaScript classification or archive cadence.
struct StreamFinalityReferenceEvidence {
    bytes32 inputHash;
    bytes32 recordHash;
    bytes32 payloadHash;
    bytes32 sourcesHash;
    bytes32 snapshotRecordHash;
    uint64 snapshotRevision;
    uint64 revision;
    uint32 payloadBytes;
    address recorder;
    uint8 authorizationClass;
    uint64 grantRevision;
    uint64 recordedAt;
    bytes32 schemaHash;
    bytes32 profileHash;
    bytes32 canonicalizationHash;
    bool locked;
    bytes32 lockHash;
    bytes32 componentDataHash;
}
