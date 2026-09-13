// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryTypes as RecoveryRecord
} from "./StreamArtistIdentityRecoveryTypes.sol";
import { StreamArtistRotationTypes as Rotation } from "./StreamArtistRotationTypes.sol";

/// @notice Typed operation35 admission and history, separate from its permanent semantic hash.
library StreamArtistIdentityRecoveryOperationTypes {
    struct Request {
        bytes32 artistId;
        address newAddress;
        uint8 vestedAuthorityClass;
        bytes32 expectedCauseHash;
        bytes32 expectedResolutionHash;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bytes32[] supersededRecordHashes;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        bytes32 causeHash;
        address incumbent;
        uint64 postContestSeconds;
        uint64 standingTailSeconds;
        uint64 timingRevision;
        uint64 delegationEpoch;
        Rotation.TransitionState abandonedTransition;
    }

    struct Record {
        bytes32 recordHash;
        RecoveryRecord.RecordFields fields;
        Request terms;
        address executor;
        address proposer;
        bytes32 governanceWitnessHash;
        bytes32 contextHash;
        bytes32 acceptanceDigest;
        uint256 acceptanceNonce;
        uint64 acceptanceDeadline;
        uint64 postContestSeconds;
        uint64 standingTailSeconds;
        uint64 timingRevision;
        uint64 delegationEpoch;
        Rotation.TransitionState abandonedTransition;
    }

    error InvalidIdentityRecovery(bytes32 artistId);
    error UnsupportedIdentityRecoveryProfile(bytes32 artistId);
    error InvalidIdentityRecoveryGovernance();
}
