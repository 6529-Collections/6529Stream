// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";

/// @notice Current-principal compromise filing; successor, dismissal and recovery are separate capabilities.
interface IStreamArtistIdentityContest {
    function contestArtistIdentity(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external returns (bytes32);

    function identityContestRecord(bytes32 recordHash) external view returns (Contest.Record memory);

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32);

    function identityContestGovernanceContext(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external view returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);
}

interface IStreamArtistIdentityContestOwner {
    function contestIdentity(
        T.ActionContext calldata c,
        Contest.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32);

    function identityContestRecord(bytes32 recordHash) external view returns (Contest.Record memory);

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32);

    function identityContestContext(Contest.Request calldata p)
        external
        view
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash);

    function artistWindowAuthority() external view returns (address);
}

interface IStreamArtistIdentityContestCoordinator {
    function coordinateContestArtistIdentity(address actor, Contest.Request calldata p)
        external
        returns (bytes32);
}
