// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryTypes as Recovery } from "./StreamArtistRecoveryTypes.sol";
import { StreamArtistUnavailabilityTypes as U } from "./StreamArtistUnavailabilityTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Action-bound unavailability findings and their separate immutable admission evidence.
interface IStreamArtistUnavailabilityEvents {
    event ArtistUnavailabilityFindingRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint256 indexed collectionId,
        uint64 noticeEndsAt,
        uint64 recordedAt,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 findingRecordHash,
        bytes32 governanceActionId
    );
    event ArtistUnavailabilityActivityRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        uint8 authorityClass,
        uint16 operationId,
        uint256 previousEpoch,
        uint256 nextEpoch
    );
}

interface IStreamArtistUnavailability is IStreamArtistUnavailabilityEvents {
    function recordUnavailabilityFinding(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external returns (bytes32 findingRecordHash);

    function unavailabilityFindingRecord(bytes32 recordHash)
        external
        view
        returns (Recovery.FindingRecord memory, U.Admission memory);

    function unavailabilityFindingContext(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external view returns (U.Context memory);

    /// @notice Current association/activity eligibility for the exact target, with its notice end.
    /// @dev A validating read is not consumption. The companion independently admits the actual
    ///      executing canonical action, exact intent, current pins and elapsed notice, and consumes
    ///      its action once. Executed recovery history never calls this current-use read again.
    function verifyRecoveryUnavailability(U.Target calldata target)
        external
        view
        returns (bool valid, bytes32 findingRecordHash, bytes32 artistId, uint64 noticeEndsAt);
}

interface IStreamArtistUnavailabilityOwner {
    function recordUnavailability(T.ActionContext calldata c, U.Input calldata p)
        external
        returns (bytes32);

    function unavailabilityFindingRecord(bytes32 recordHash)
        external
        view
        returns (Recovery.FindingRecord memory, U.Admission memory);

    function latestUnavailabilityFinding(bytes32 artistId, uint256 collectionId)
        external
        view
        returns (bytes32);

    function unavailabilityFindingContext(U.Input calldata p)
        external
        view
        returns (U.Context memory);

    function unavailabilityFindingLive(bytes32 recordHash, T.Binding calldata b)
        external
        view
        returns (bool);
}

interface IStreamArtistUnavailabilityCoordinator {
    function coordinateRecordUnavailabilityFinding(
        address actor,
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external returns (bytes32);

    function prepareUnavailabilityFinding(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external view returns (U.Context memory);
}
