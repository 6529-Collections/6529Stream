// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";

interface IStreamArtistIdentityRecoveryEvents {
    event ArtistIdentityRecovered(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed oldAddress,
        address indexed newAddress,
        uint8 vestedAuthorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 supersededRecordsHash,
        uint64 recoveredAt,
        bytes32 recoveryRecordHash,
        bytes32 governanceActionId,
        bytes32[] supersededRecordHashes
    );
}

/// @notice Operation35 recovery and immutable history; the first admitted profile has no prior transition or guardians.
interface IStreamArtistIdentityRecovery is IStreamArtistIdentityRecoveryEvents {
    function recoverArtistIdentity(
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external returns (bytes32);
    function identityRecoveryContext(
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external view returns (IdentityRecovery.Context memory);
    function identityRecoveryRecord(bytes32 recordHash)
        external
        view
        returns (IdentityRecovery.Record memory);
    function latestIdentityRecovery(bytes32 artistId) external view returns (bytes32);
}

interface IStreamArtistIdentityRecoveryOwner {
    function identityRecoveryContext(
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external view returns (IdentityRecovery.Context memory);
    function identityRecoveryRecord(bytes32 recordHash)
        external
        view
        returns (IdentityRecovery.Record memory);
    function latestIdentityRecovery(bytes32 artistId) external view returns (bytes32);
    function recoverIdentity(
        T.ActionContext calldata context,
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32);
    function identityRecoveryReceipts(bytes32 recordHash)
        external
        view
        returns (bytes32, bytes32, bytes32);
    function recoveryTransitionStanding(bytes32 recordHash)
        external
        view
        returns (address, bytes32, uint64);
}

interface IStreamArtistIdentityRecoveryCoordinator {
    function coordinateRecoverArtistIdentity(
        address actor,
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external returns (bytes32);
}
