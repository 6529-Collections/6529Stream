// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

library StreamArtistIdentityDismissalTypes {
    struct Request {
        bytes32 artistId;
        bytes32 expectedCauseHash;
        bytes32 expectedResolutionHash;
        bytes32 evidenceHash;
        bytes32 reasonHash;
        bool removePriorStanding;
        bytes32 expectedRetirementHash;
    }

    struct CauseFacts {
        bytes32 artistId;
        uint8 kind; // 1 = operation33 filing; 2 = operation31 veto
        bytes32 referenceHash; // actual33 record or actual vetoed rotation, respectively
        address actor;
        bytes32 reasonHash;
        bytes32 evidenceHash; // actual33 evidence; zero for31, without invented evidence
        uint64 enteredAt;
        address incumbent;
        uint8 authorityClass;
        uint8 priorStatus;
        bytes32 pendingTransitionHash;
        bytes32 executedTransitionHash;
        bytes32 previousCauseHash;
        bytes32 previousResolutionHash;
        bytes32 actorRetirementHash;
    }

    struct Cause {
        bytes32 causeHash;
        CauseFacts facts;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
        bytes32 causeHash;
        bytes32 cohortHash;
        bytes32 revisionContinuationHead;
    }

    struct Record {
        bytes32 recordHash;
        Request terms;
        address executor;
        address proposer;
        uint8 actionClass;
        bytes32 actionId;
        address incumbent;
        uint8 authorityClass;
        uint8 restoredStatus;
        uint64 dismissedAt;
        bytes32 cohortHash;
        bytes32 governanceWitnessHash;
        bytes32 revisionContinuationHead; // separately derived from recordHash, never circular
    }

    struct Closure {
        bytes32 artistId;
        bytes32 transitionRecordHash;
        bytes32 dismissalRecordHash;
        uint64 windowEndsAt;
        uint64 contestedAt;
        bool abandoned;
    }

    struct RevisionContinuation {
        bytes32 continuationHash;
        bytes32 artistId;
        bytes32 dismissalRecordHash;
        bytes32 previousContinuationHash;
        bytes32 stableRevisionRecordHash;
        bytes32 stableDocumentHash;
        bytes32 abandonedRevisionRecordHash;
    }

    // Provided by a snapshotted Identity callback during operation18. Payout
    // independently matches this actual closure to its own exact pending child.
    struct PayoutResolutionFacts {
        bytes32 artistId;
        Closure currentTransitionClosure;
        Closure candidateTransitionClosure;
    }

    struct CohortSnapshot {
        R.TransitionState pendingTransition;
        R.TransitionState executedTransition;
        bytes32 stableRevisionRecord;
        bytes32 pendingRevisionRecord;
        bytes32 operativeRevisionRecord;
        bytes32 operativeDocumentHash;
        bytes32 stableGuardianRecord;
        bytes32 candidateGuardianRecord;
        bytes32 operativeGuardianRecord;
        bytes32 stableDesignationRecord;
        bytes32 candidateDesignationRecord;
        bytes32 operativeDesignationRecord;
        bytes32 stableDirectiveRecord;
        bytes32 candidateDirectiveRecord;
        bytes32 operativeDirectiveRecord;
        bytes32 revisionContinuationHead;
        Closure pendingClosure;
        Closure executedClosure;
    }

    struct StandingJudgment {
        bytes32 retirementHash;
        bytes32 dismissalRecordHash;
    }

    struct ContestResolutionFacts {
        Closure subjectClosure;
        Closure executedClosure;
        bytes32 currentCauseHash;
        bytes32 currentResolutionHash;
    }
    error InvalidDismissal(bytes32 artistId);
    error InvalidContestCause(bytes32 causeHash);
    error InvalidClosure(bytes32 transitionRecordHash);
    error InvalidDismissalGovernance();
}
