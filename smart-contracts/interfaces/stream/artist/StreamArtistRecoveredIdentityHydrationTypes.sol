// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredTimingTypes as TM } from "./StreamArtistRecoveredTimingTypes.sol";

import {
    StreamArtistRecoveredHydrationTypes as RH
} from "./StreamArtistRecoveredHydrationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistAuthorityHydrationTypes as AH } from "./IStreamArtistAuthorityHydration.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";
import { StreamArtistGuardianHistoryTypes as GH } from "./StreamArtistGuardianHistoryTypes.sol";
import { StreamArtistGuardianVestingTypes as V } from "./StreamArtistGuardianVestingTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as GS
} from "./StreamArtistGuardianSupersessionTypes.sol";
import {
    StreamArtistGuardianSelectionTypes as Selection
} from "./StreamArtistGuardianSelectionTypes.sol";
import { StreamArtistIdentityContestTypes as C } from "./StreamArtistIdentityContestTypes.sol";
import { StreamArtistIdentityDismissalTypes as D } from "./StreamArtistIdentityDismissalTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistRecoveryActionTypes as A } from "./StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRecoveryEvidenceTypes as E } from "./StreamArtistRecoveryEvidenceTypes.sol";
import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";
import { StreamArtistSuccessionTypes as Succ } from "./StreamArtistSuccessionTypes.sol";
import { StreamArtistEstateTypes as Estate } from "./StreamArtistEstateTypes.sol";
import { StreamArtistDormancyTypes as Dorm } from "./IStreamArtistDormancy.sol";
import { StreamArtistIdentityRevisionTypes as Doc } from "./IStreamArtistIdentityRevision.sol";
import { StreamArtistDelegationTypes as Delegate } from "./StreamArtistDelegationTypes.sol";
import { StreamArtistRecoveryTypes as Finding } from "./StreamArtistRecoveryTypes.sol";
import { StreamArtistUnavailabilityTypes as U } from "./StreamArtistUnavailabilityTypes.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "./IStreamArtistEntropyUnavailability.sol";
import {
    IStreamArtistStewardSanctionGrant as Grant
} from "./IStreamArtistStewardSanctionGrant.sol";

/// @notice Exact Identity-owned state for the additive recovered-authority profile.
/// @dev No row is an instruction to a writer. Source positions and original record tuples survive unchanged.
library StreamArtistRecoveredIdentityHydrationTypes {
    bytes32 internal constant SCHEMA =
        keccak256("6529STREAM_ARTIST_RECOVERED_IDENTITY_HYDRATION_V1");

    struct Heads {
        bytes32 latestTransition;
        bytes32 latestExecution;
        bytes32 pendingRotation;
        bytes32 latestContest;
        bytes32 currentCause;
        bytes32 latestDismissal;
        bytes32 originalRevisionContinuation;
        bytes32 latestRecovery;
        bytes32 pendingRecoveryAction;
        bytes32 latestVesting;
        bytes32 pendingEstate;
        bytes32 estateActivation;
        bytes32 dormancyActivation;
        bytes32 latestNotice;
        uint256 livingActivity;
        uint256 dormancyActivity;
        uint256 findingActivity;
        bool hasUncancelledFindings;
        uint64 delegationEpoch;
        uint64 guardianRecordsSeen;
        GH.Head guardianHistory;
        GS.IndexHead guardianIndex;
        W.IdentityInventoryV3 inventory;
        bytes32 capabilityContinuation;
    }

    struct DocumentRow {
        bytes32 documentHash;
        bytes document;
    }

    struct FindingRow {
        RH.Position position;
        Finding.FindingRecord record;
        U.Admission admission;
        EU.Admission entropyAdmission;
        address entropyOrigin;
        bytes32 latestForCollection;
    }

    struct SignatureRow {
        bytes32 recordHash;
        bytes signature;
    }

    struct NonceLane {
        uint8 kind;
        bytes32 key;
        uint256 hint;
        AH.NonceWord[] words;
    }

    struct RevisionRow {
        RH.Position position;
        Doc.Record record;
        bytes document;
        R.ProvisionalAssociation association;
        W.StatusV3 status;
        bytes32 rewindContinuation;
    }

    struct DelegationRow {
        RH.Position position;
        bytes32 recordHash;
        Delegate.Record record;
        bytes32 current;
        uint64 epoch;
    }

    struct GuardianRow {
        RH.Position position;
        R.GuardianRecord record;
        GH.Entry entry;
        GS.Status status;
    }

    struct MembershipRow {
        address actor;
        uint64 first;
        uint64[] indices;
    }

    struct RotationRow {
        RH.Position position;
        R.RotationRecord record;
        // Exact bits in the captured guardian record's original member order.
        bool[] approvals;
    }

    struct ContestRow {
        RH.Position position;
        C.Record record;
    }

    struct CauseRow {
        RH.Point point;
        D.Cause cause;
        bytes32 notice;
    }

    struct DismissalRow {
        RH.Position position;
        D.Record record;
    }

    struct ClosureRow {
        bytes32 transition;
        D.Closure closure;
    }

    struct StandingRow {
        address account;
        bytes32 retirement;
        bytes32 revocation;
        D.StandingJudgment judgment;
    }

    struct StandingRecordRow {
        RH.Position position;
        R.StandingRecord record;
        W.StatusV3 status;
        bytes32 rewindContinuation;
    }

    struct RecoveryRow {
        RH.Position position;
        Recovery.Record record;
        R.TransitionState transition;
        bytes32 guardian;
        bytes32 primaryReceipt;
        bytes32 secondaryOccurrence;
        bytes32 secondaryReceipt;
    }

    struct VestingRow {
        RH.Point point;
        V.Snapshot snapshot;
    }

    struct ActionRow {
        RH.Point point;
        A.Association association;
        A.Veto veto;
        bytes32 execution;
        GH.Snapshot guardianSnapshot;
        GS.Plan plan;
        Selection.Result election;
        R.GuardianRecord restoredGuardian;
        // Aligned with Bundle.memberships; retain zero counts explicitly.
        uint64[] excludedMemberships;
        E.EvidenceStateV2 evidenceV2;
        W.EvidenceStateV3 evidenceV3;
        bytes32 manifestActionV2;
        bytes32 manifestActionV3;
    }

    struct DesignationRow {
        RH.Position position;
        Succ.DesignationRecord record;
        W.StatusV3 status;
    }

    struct DirectiveRow {
        RH.Position position;
        Succ.DirectiveRecord record;
        bytes payload;
        W.StatusV3 status;
    }

    struct GrantRow {
        RH.Position position;
        Grant.GrantRecord record;
        W.StatusV3 status;
    }

    struct EstateRow {
        RH.Position position;
        Estate.RequestRecord request;
        uint8 phase;
        Estate.ExecutionFacts execution;
        R.TransitionState transition;
    }

    struct NoticeRow {
        RH.Position position;
        Dorm.Notice notice;
        uint8 phase;
        Dorm.Terminal terminal;
        R.TransitionState transition;
    }

    struct OriginalContinuationRow {
        RH.Point point;
        D.RevisionContinuation continuation;
    }

    struct RevisionContinuationRow {
        RH.Point point;
        W.RevisionContinuationV3 continuation;
    }

    struct StandingContinuationRow {
        RH.Point point;
        W.StandingContinuationV3 continuation;
        // Exact current head of this historical (artist, address, retirement) scope.
        bytes32 scopeHead;
    }

    struct CapabilityContinuationRow {
        RH.Point point;
        W.CapabilityContinuationV3 continuation;
    }

    struct Bundle {
        bytes32 artistId;
        T.Snapshot sourceSnapshot;
        uint256 nextRegistrationNonce;
        T.Identity identity;
        bytes identityDocument;
        DocumentRow[] documents;
        Heads heads;
        TM.Bundle timing;
        SignatureRow[] signatures;
        NonceLane[] nonces;
        RevisionRow[] revisions;
        DelegationRow[] delegations;
        GuardianRow[] guardians;
        MembershipRow[] memberships;
        RotationRow[] rotations;
        ContestRow[] contests;
        CauseRow[] causes;
        DismissalRow[] dismissals;
        ClosureRow[] closures;
        StandingRow[] standing;
        StandingRecordRow[] standingRecords;
        RecoveryRow[] recoveries;
        VestingRow[] vestings;
        ActionRow[] actions;
        DesignationRow[] designations;
        DirectiveRow[] directives;
        GrantRow[] sanctionGrants;
        EstateRow[] estates;
        NoticeRow[] notices;
        FindingRow[] findings;
        OriginalContinuationRow[] originalContinuations;
        RevisionContinuationRow[] revisionContinuations;
        StandingContinuationRow[] standingContinuations;
        CapabilityContinuationRow[] capabilityContinuations;
    }

    error InvalidRecoveredIdentity(bytes32 key);
}
