// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistRotation.sol";

interface IStreamArtistRotationOwner is IStreamArtistRotationReads {
    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function stageRotation(
        T.ActionContext calldata c,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization,
        T.SignerApproval calldata oldProof,
        T.SignerApproval calldata newProof
    ) external returns (bytes32);
    function approveRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external;
    function vetoRotation(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) external;
    function executeRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external;
    function revokeStanding(
        T.ActionContext calldata c,
        R.StandingRevocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
    function provisionalAssociation(bytes32 artistId)
        external
        view
        returns (R.ProvisionalAssociation memory);
    function provisionalRecordEligible(bytes32 artistId, R.ProvisionalAssociation calldata a)
        external
        view
        returns (bool);
}

/// @notice AA-owned seconds configuration; neither GGP nor GTP.
interface IStreamArtistWindows {
    function artistWindowInfo(bytes32 parameter)
        external
        view
        returns (uint64 value, uint64 floor, uint64 revision);
    function artistWindowScope(bytes32 parameter) external view returns (bytes32);
    function artistWindowStateHash(bytes32 parameter, uint64 value, uint64 revision)
        external
        view
        returns (bytes32);
    function setArtistWindow(bytes32 parameter, uint64 newValue, uint64 expectedRevision) external;
}

interface IStreamArtistWindowOwner {
    function configureArtistWindow(
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) external;
}

interface IStreamArtistWindowCoordinator {
    function coordinateSetArtistWindow(
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) external;
}
