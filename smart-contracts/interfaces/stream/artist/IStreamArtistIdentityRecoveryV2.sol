// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";
import { StreamArtistRecoveryActionTypes as A } from "./StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRecoveryEvidenceTypes as E } from "./StreamArtistRecoveryEvidenceTypes.sol";
import { GovernanceCall } from "../governance/StreamGovernanceTypes.sol";

/// @notice Explicit evidence-selected operation35 entry points; all original selectors remain separate.
interface IStreamArtistIdentityRecoveryV2 {
    function identityRecoveryContextV2(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external view returns (Recovery.Context memory);
    function registerIdentityRecoveryActionV2(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function recoverArtistIdentityV2(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function identityRecoveryEvidenceState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (E.EvidenceStateV2 memory);
}

interface IStreamArtistIdentityRecoveryOwnerV2 {
    function guardianRecoveryAuthorityRoleV2(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external view returns (bytes32);
    function identityRecoveryContextV2(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external view returns (Recovery.Context memory);
    function identityRecoveryEvidenceState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (E.EvidenceStateV2 memory);
    function prepareIdentityRecoveryActionV2(
        T.ActionContext calldata context,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        A.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal,
        bytes32 manifestHash
    ) external returns (bytes32);
    function recoverIdentityV2(
        T.ActionContext calldata context,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance,
        bytes32 manifestHash
    ) external returns (bytes32);
}

interface IStreamArtistIdentityRecoveryCoordinatorV2 {
    function coordinateRegisterIdentityRecoveryActionV2(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function coordinateRecoverArtistIdentityV2(
        address actor,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
}
