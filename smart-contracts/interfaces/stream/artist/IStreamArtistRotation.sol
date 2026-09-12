// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistRotationTypes as R } from "./StreamArtistRotationTypes.sol";

/// @notice Scoped current-principal guardian and two-sided rotation reads.
/// @dev Successor, estate, dormancy, compromise filing and recovery are separate capabilities.
interface IStreamArtistRotationReads {
    function guardianSet(bytes32 artistId)
        external
        view
        returns (address[] memory, uint32, uint64, bytes32);
    function pendingRotation(bytes32 artistId)
        external
        view
        returns (address, address, uint64, uint32, bytes32);
    function priorAddressStandingRevoked(bytes32 artistId, address priorAddress)
        external
        view
        returns (bool, bytes32);
    function guardianSetRecord(bytes32 recordHash) external view returns (R.GuardianRecord memory);
    function rotationRecord(bytes32 recordHash) external view returns (R.RotationRecord memory);
    function standingRevocationRecord(bytes32 recordHash)
        external
        view
        returns (R.StandingRecord memory);
    function artistTransitionState(bytes32 recordHash)
        external
        view
        returns (R.TransitionState memory);
    function lastArtistTransition(bytes32 artistId) external view returns (bytes32);
    function identityRevisionProvisionalAssociation(bytes32 recordHash)
        external
        view
        returns (R.ProvisionalAssociation memory);
    function activeAuthorityWindow(bytes32 artistId)
        external
        view
        returns (bytes32 transitionRecordHash, uint64 windowEndsAt, bool contested);
    function rotationAcceptanceNonceState(bytes32 artistId, address newAddress, uint256 nonce)
        external
        view
        returns (bool used, uint256 nextNonce);
}

interface IStreamArtistRotation is IStreamArtistRotationReads {
    function payoutDesignationProvisionalAssociation(bytes32 recordHash)
        external
        view
        returns (R.ProvisionalAssociation memory);
    function setArtistGuardians(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    function rotateArtistAddress(
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external returns (bytes32);
    function approveArtistRotation(bytes32 artistId, bytes32 expectedRotationRecordHash) external;
    function vetoArtistRotation(
        bytes32 artistId,
        bytes32 expectedRotationRecordHash,
        bytes32 reasonHash
    ) external;
    function executeArtistRotation(bytes32 artistId, bytes32 expectedRotationRecordHash) external;
    function revokePriorAddressStanding(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    function guardianSetDigest(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function rotationDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function rotationAcceptanceDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function standingRevocationDigest(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
}

interface IStreamArtistRotationCoordinator {
    function coordinateSetArtistGuardians(
        address actor,
        R.GuardianSet calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateRotateArtistAddress(
        address actor,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external returns (bytes32);
    function coordinateApproveArtistRotation(
        address actor,
        bytes32 artistId,
        bytes32 expectedRotationRecordHash
    ) external;
    function coordinateVetoArtistRotation(
        address actor,
        bytes32 artistId,
        bytes32 expectedRotationRecordHash,
        bytes32 reasonHash
    ) external;
    function coordinateExecuteArtistRotation(
        address actor,
        bytes32 artistId,
        bytes32 expectedRotationRecordHash
    ) external;
    function coordinateRevokePriorAddressStanding(
        address actor,
        R.StandingRevocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
}
