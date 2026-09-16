// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact current descriptive records and their independently retained selection receipts.
/// @dev These two inputs do not establish scope membership, other finality inputs or legal rights.
struct StreamFinalityDescriptionEvidence {
    bytes32 scopeSubject;
    bytes32 workDescriptionRecordHash;
    bytes32 rightsStatementRecordHash;
    bytes32 workPayloadHash;
    bytes32 rightsPayloadHash;
    bytes32 workSelectionHash;
    bytes32 rightsSelectionHash;
    uint64 workRevision;
    uint64 rightsRevision;
}
