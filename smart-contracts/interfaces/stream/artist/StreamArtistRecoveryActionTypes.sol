// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRotationTypes as Rotation } from "./StreamArtistRotationTypes.sol";

/// @notice Auxiliary preparation facts; these are not permanent recovery semantic records.
library StreamArtistRecoveryActionTypes {
    uint16 internal constant PREPARE_OPERATION = 65534;

    struct Environment {
        address registry;
        address executor;
        bytes32 executorCodeHash;
        address roles;
    }

    struct Witness {
        bytes32 actionId;
        bytes32 callsHash;
        uint256 callIndex;
        bytes32 callDataHash;
        address executor;
        bytes32 executorCodeHash;
        address proposer;
        bytes32 roleMutationHash;
        uint64 roleRevision;
        uint64 notBefore;
        uint64 expiresAfter;
        uint64 minimumDelay;
        bytes32 manifestHash;
    }

    struct Association {
        bytes32 associationHash;
        bytes32 artistId;
        bytes32 requestHash;
        bytes32 acceptanceHash;
        bytes32 contextHash;
        Witness action;
        Rotation.GuardianRecord guardian;
        address preparedBy;
        uint64 preparedAt;
        uint64 ownerRevision;
    }

    struct Veto {
        address vetoer;
        bytes32 reasonHash;
        uint64 vetoedAt;
    }

    error InvalidRecoveryAction(bytes32 actionId);
    error RecoveryActionStillLive(bytes32 actionId);
    error RecoveryActionVetoed(bytes32 actionId);
    error InvalidRecoveryGuardian(address actor);
    error RecoveryActionDependencyChanged(address target);
}
