// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Supplemental estate lifecycle facts; the permanent activation digest/record is unchanged.
library StreamArtistEstateTypes {
    struct Request {
        bytes32 artistId;
        address successor;
        bytes32 evidenceHash;
        bytes32 expectedDesignationRecordHash;
        bytes32 selectedCoverageHash;
    }

    struct Execution {
        bytes32 artistId;
        bytes32 expectedActivationRecordHash;
        bytes32 currentCoverageHash;
    }

    struct RequestRecord {
        bytes32 recordHash;
        Request terms;
        T.Authorization authorization;
        address incumbent;
        bytes32 designationRecordHash;
        bytes32 pairedDirectiveRecordHash;
        bytes32 forbiddenDirectiveRecordHash;
        bytes32 guardianRecordHash;
        bytes32 envelopeHash;
        uint64 requestedAt;
        uint64 noticeEndsAt;
        uint64 noticeSeconds;
        uint64 noticeRevision;
        uint64 postContestSeconds;
        uint64 standingTailSeconds;
        uint64 rotationTimingRevision;
        uint256 livingActivity;
    }

    /// @dev Operation40 has no new normative primary record. This is evidence keyed by its request.
    struct ExecutionFacts {
        bytes32 activationRecordHash;
        bytes32 coverageRecordHash;
        uint32 effectiveCapabilities;
        uint64 executedAt;
        bytes32 governanceActionId;
        bytes32 governanceWitnessHash;
        uint64 delegationEpoch;
    }

    struct AuthorityCapabilities {
        address authorityAddress;
        uint8 authorityClass;
        uint8 status;
        uint32 effectiveCapabilities;
        bytes32 activationRecordHash;
    }

    struct TransitionHead {
        uint8 kind; // 0 none, 1 actual rotation, 2 actual estate activation
        bytes32 recordHash;
    }

    struct RequestFacts {
        bytes32 designationRecordHash;
        bytes32 pairedDirectiveRecordHash;
        bytes32 forbiddenDirectiveRecordHash;
        bytes32 guardianRecordHash;
        bytes32 envelopeHash;
        uint64 noticeSeconds;
        uint64 noticeRevision;
        uint64 postContestSeconds;
        uint64 standingTailSeconds;
        uint64 rotationTimingRevision;
    }

    struct AccelerationContext {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        bytes32 evidenceHash;
        uint32 effectiveCapabilities;
    }

    error InvalidEstateActivation(bytes32 activationRecordHash);
    error EstateActivationPending(bytes32 activationRecordHash);
    error EstateNoticeNotElapsed(uint64 noticeEndsAt);
    error InvalidEstateCoverage(bytes32 coverageRecordHash);
    error InvalidEstateAcceleration();
    error EstateCapabilityUnavailable(bytes32 artistId, uint32 requiredCapabilities);
}
