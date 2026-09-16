// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

library StreamArtistDormancyTypes {
    struct Initiation {
        bytes32 artistId;
        bytes32 evidenceHash;
        string reasonURI;
    }

    struct Completion {
        bytes32 artistId;
        bytes32 expectedNoticeHash;
        address vestedAuthority;
        bytes32 evidenceHash;
    }

    struct Context {
        bytes32 scopeHash;
        bytes32 oldValueHash;
        bytes32 newValueHash;
    }

    struct Plan {
        address authority;
        uint8 authorityClass;
        uint32 capabilities;
        bytes32 designation;
        bytes32 directive;
        bytes32 guardian;
        bytes32 stewardGrantRecordHash;
        uint64 postSeconds;
        uint64 standingTail;
    }

    struct Notice {
        bytes32 recordHash;
        Initiation terms;
        address incumbent;
        uint64 initiatedAt;
        uint64 noticeEndsAt;
        uint64 inactivitySeconds;
        uint64 noticeSeconds;
        uint64 timingRevision;
        uint64 priorLivenessAt;
        uint256 priorActivity;
        bytes32 actionId;
        bytes32 witnessHash;
    }

    struct Terminal {
        bytes32 recordHash;
        bytes32 noticeHash;
        address actor;
        uint8 authorityClass;
        uint64 observedAt;
        uint64 appointmentBlock;
        Plan plan;
        bytes32 evidenceHash;
        bytes32 actionId;
        bytes32 witnessHash;
        uint64 delegationEpoch;
    }
    error InvalidDormancy(bytes32 artistId);
    error DormancyInactivity(uint64 lastActivity, uint64 requiredSeconds);
    error DormancyNoticeNotElapsed(uint64 noticeEndsAt);
    error InvalidDormancyGovernance();
}

interface IStreamArtistDormancyEvents {
    event ArtistDormancyInitiated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        uint64 noticeEndsAt,
        bytes32 evidenceHash,
        string reasonURI,
        bytes32 actionId
    );
    event ArtistDormancyCancelled(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        address canceller,
        uint8 authorityClass,
        bytes32 cancellationHash
    );
    event ArtistDormancyCompleted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        address vestedAuthority,
        uint8 authorityClass,
        uint32 effectiveCapabilities,
        uint64 stewardAppointedAtBlock,
        bytes32 completionHash,
        bytes32 actionId
    );
}

interface IStreamArtistDormancy is IStreamArtistDormancyEvents {
    function initiateArtistDormancy(StreamArtistDormancyTypes.Initiation calldata terms)
        external
        returns (bytes32);
    function cancelArtistDormancy(bytes32 artistId, bytes32 expectedNoticeHash, bytes32 grantHint)
        external;
    function completeArtistDormancy(StreamArtistDormancyTypes.Completion calldata terms)
        external
        returns (bytes32);
    function dormancyState(bytes32 artistId)
        external
        view
        returns (uint8 identityStatus, uint64 noticeEndsAt, uint64 stewardAppointedAtBlock);
    function dormancyNotice(bytes32 artistId)
        external
        view
        returns (bytes32 noticeHash, uint8 phase, bytes32 terminalHash);
    function dormancyRecord(bytes32 noticeHash)
        external
        view
        returns (
            StreamArtistDormancyTypes.Notice memory,
            uint8 phase,
            StreamArtistDormancyTypes.Terminal memory
        );
    function dormancyInitiationContext(StreamArtistDormancyTypes.Initiation calldata terms)
        external
        view
        returns (StreamArtistDormancyTypes.Context memory);
    function dormancyCompletionContext(StreamArtistDormancyTypes.Completion calldata terms)
        external
        view
        returns (StreamArtistDormancyTypes.Context memory, StreamArtistDormancyTypes.Plan memory);
}

interface IStreamArtistDormancyEvidence {
    function dormancyCompletionEvidence(StreamArtistDormancyTypes.Completion calldata terms)
        external
        view
        returns (bytes memory);
}

interface IStreamArtistDormancyCoordinator {
    function coordinateInitiateArtistDormancy(
        address actor,
        StreamArtistDormancyTypes.Initiation calldata terms
    ) external returns (bytes32);
    function coordinateCancelArtistDormancy(
        address actor,
        bytes32 artistId,
        bytes32 expectedNoticeHash,
        bytes32 grantHint
    ) external;
    function coordinateCompleteArtistDormancy(
        address actor,
        StreamArtistDormancyTypes.Completion calldata terms
    ) external returns (bytes32);
}

interface IStreamArtistDormancyOwner {
    function initiateDormancy(
        T.ActionContext calldata context,
        StreamArtistDormancyTypes.Initiation calldata terms,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32);
    function cancelDormancy(
        T.ActionContext calldata context,
        bytes32 artistId,
        bytes32 expectedNoticeHash,
        bytes32 grantHint
    ) external;
    function completeDormancy(
        T.ActionContext calldata context,
        StreamArtistDormancyTypes.Completion calldata terms,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32);
    function dormancyState(bytes32 artistId) external view returns (uint8, uint64, uint64);
    function dormancyNotice(bytes32 artistId) external view returns (bytes32, uint8, bytes32);
    function dormancyRecord(bytes32 hash)
        external
        view
        returns (
            StreamArtistDormancyTypes.Notice memory,
            uint8,
            StreamArtistDormancyTypes.Terminal memory
        );
    function dormancyInitiationContext(StreamArtistDormancyTypes.Initiation calldata terms)
        external
        view
        returns (StreamArtistDormancyTypes.Context memory);
    function dormancyCompletionContext(StreamArtistDormancyTypes.Completion calldata terms)
        external
        view
        returns (StreamArtistDormancyTypes.Context memory, StreamArtistDormancyTypes.Plan memory);
    function dormancyCompletionEvidence(StreamArtistDormancyTypes.Completion calldata terms)
        external
        view
        returns (bytes memory);
    function dormancyTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64);
    function dormancyResolutionState(bytes32 artistId, bytes32 causeHash)
        external
        view
        returns (bytes32 noticeHash, uint8 phase, bytes32 terminalHash);
}
