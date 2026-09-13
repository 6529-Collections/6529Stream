// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "./StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as IdentityRecovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { GovernanceCall } from "../governance/StreamGovernanceTypes.sol";

interface IStreamArtistRecoveryActionEvents {
    event ArtistIdentityRecoveryPrepared(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed governanceActionId,
        bytes32 associationHash,
        bytes32 guardianRecordHash,
        address preparedBy,
        uint64 preparedAt
    );
    event ArtistIdentityRecoveryVetoed(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed vetoer,
        bytes32 reasonHash,
        bytes32 governanceActionId
    );
}

/// @notice Auxiliary action preparation and the canonical operation34 guardian veto.
interface IStreamArtistRecoveryAction is IStreamArtistRecoveryActionEvents {
    function registerIdentityRecoveryAction(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external returns (bytes32);
    function vetoIdentityRecovery(bytes32 artistId, bytes32 reasonHash) external;
    function identityRecoveryActionState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RecoveryAction.Association memory, RecoveryAction.Veto memory, bytes32, uint64);
}

interface IStreamArtistRecoveryActionOwner {
    function recoveryExecutorBinding() external view returns (address, bytes32);
    function identityRecoveryActionState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RecoveryAction.Association memory, RecoveryAction.Veto memory, bytes32, uint64);
    function prepareIdentityRecoveryAction(
        T.ActionContext calldata context,
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance,
        RecoveryAction.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal
    ) external returns (bytes32);
    function vetoPreparedIdentityRecovery(
        T.ActionContext calldata context,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 reasonHash,
        bool scheduled
    ) external;
}

interface IStreamArtistRecoveryActionCoordinator {
    function coordinateRegisterIdentityRecoveryAction(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        IdentityRecovery.Request calldata request,
        T.Authorization calldata acceptance
    ) external returns (bytes32);
    function coordinateVetoIdentityRecovery(address actor, bytes32 artistId, bytes32 reasonHash)
        external;
}
