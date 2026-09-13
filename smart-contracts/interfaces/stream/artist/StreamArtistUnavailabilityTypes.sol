// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryTypes as Recovery } from "./StreamArtistRecoveryTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";
import "../finality/StreamArtworkFinalityTypes.sol";

/// @notice Action-bound admission evidence outside the permanent unavailability record hash.
library StreamArtistUnavailabilityTypes {
    struct Target {
        address recoveryRegistry;
        bytes32 recoveryActionId;
        StreamFinalityScope scope;
        bytes32 originalFinalityRecordHash;
        bytes32 recoveryManifestHash;
    }

    struct Admission {
        Target target;
        bytes32 recoveryRegistryCodeHash;
        bytes32 recoveryIntentFactsHash;
        uint256 activityEpoch;
        bytes32 governanceWitnessHash;
    }

    struct Input {
        Recovery.FindingRequest terms;
        Target target;
        T.Binding binding_;
        Contest.GovernanceWitness governance;
        bytes32 recoveryRegistryCodeHash;
        bytes32 recoveryIntentFactsHash;
        uint64 recoveryNotBefore;
        uint64 recoveryExpiresAfter;
        bool priorRecoveryTerminal;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        uint64 noticeSeconds;
        uint64 timingRevision;
    }

    error UnavailabilityNoticeOpen(uint64 noticeEndsAt);
    error UnavailabilityFindingActive(bytes32 recordHash);
    error UnavailabilityTargetMismatch();
}
