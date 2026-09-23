// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Immutable evidence references validated for one actual finality scope.
/// @dev The metadata host derives these references from its authoritative scope inventory.
///      Explicit waiver or non-applicability records are references, not implicit zero readiness.
///      The render and coverage commitments exclude the final sanction record/signature and the
///      finality manifest itself. Those objects are validated separately to avoid circular hashes.
struct StreamFinalityScopeInputs {
    bytes32 rootRecordHash;
    bytes32 snapshotRecordHash;
    bytes32 referenceRenderRecordHash;
    bytes32 intentRecordHash;
    bytes32 intentWaiverRecordHash;
    bytes32 interviewEvidenceHash;
    bytes32 rightsStatementRecordHash;
    bytes32 workDescriptionRecordHash;
    bytes32 renderCriticalEvidenceHash;
    bytes32 bundleCoverageHash;
}

/// @notice Actual host facts for one fixed finality component family and scope.
/// @dev A constructor-bound adapter supplies its own component/type/interface/code identity.
///      These four facts come from the authoritative host's validated local state.
struct StreamFinalityHostComponentFacts {
    bool frozen;
    bytes32 moduleVersion;
    bytes32 manifestHash;
    bytes32 dataHash;
}
