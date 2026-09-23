// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../metadata/IStreamConservationRecordSelection.sol";
import "./StreamArtworkFinalityTypes.sol";

/// @notice Remaining work, never an assertion that original bytes have archive coverage.
enum StreamConservationArchiveRequirement {
    UNSPECIFIED,
    DUAL_FAMILY_REFERENCES_AND_SIGNATURE_BUNDLES
}

/// @notice Current original artist voice and exact parent-committed interview status.
/// @dev Exactly one intent/waiver reference is nonzero. A WAIVED interview status commitment
/// binds the complete authenticated parent payload; it is not an invented interview record or
/// a separately extracted Reference hash. Neither status proves archival coverage or finality.
struct StreamFinalityConservationEvidence {
    bytes32 scopeSubject;
    bytes32 intentRecordHash;
    bytes32 intentWaiverRecordHash;
    bytes32 interviewEvidenceHash;
    IStreamConservationRecordSelection.Selection selected;
    IStreamConservationRecordSelection.IntentLock intentLock;
    StreamConservationArchiveRequirement archiveRequirement;
}
