// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindTypes as W } from "./StreamArtistRecoveryRewindTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistIdentityRecoveryOperationTypes as Recovery
} from "./StreamArtistIdentityRecoveryOperationTypes.sol";
import { StreamArtistRecoveryActionTypes as A } from "./StreamArtistRecoveryActionTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "./StreamArtistIdentityContestTypes.sol";
import { GovernanceCall } from "../governance/StreamGovernanceTypes.sol";

interface IStreamArtistIdentityRecoveryV3 {
    function identityRecoveryContextV3(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external view returns (Recovery.Context memory);
    function registerIdentityRecoveryActionV3(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function recoverArtistIdentityV3(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function identityRecoveryEvidenceStateV3(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (W.EvidenceStateV3 memory);
}

interface IStreamArtistIdentityRecoveryOwnerV3 {
    function recoveryRewindEvidenceBinding() external view returns (address, bytes32);
    function recoveryRewindSelectionBinding() external view returns (address, bytes32);
    function recoveryRewindInventoryV3(bytes32 artistId)
        external
        view
        returns (W.IdentityInventoryV3 memory);
    function recoveryRecordStatusV3(W.RecordKind kind, bytes32 recordHash)
        external
        view
        returns (W.StatusV3 memory);
    function recoveryStandingScopeV3(bytes32 artistId, address priorAddress)
        external
        view
        returns (
            bytes32 retirementHash,
            bytes32 revocationRecordHash,
            bytes32 independentJudgmentHash,
            bytes32 continuationHash
        );
    function recoveryRewindBasisV3(bytes32 manifestHash)
        external
        view
        returns (W.IdentityBasisV3 memory);
    function identityRecoveryEvidenceStateV3(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (W.EvidenceStateV3 memory);
    function guardianRecoveryAuthorityRoleV3(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash,
        W.CrossOwnerFactsV3 calldata facts
    ) external view returns (bytes32);
    function identityRecoveryContextV3(
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash,
        W.CrossOwnerFactsV3 calldata facts
    ) external view returns (Recovery.Context memory);
    function prepareIdentityRecoveryActionV3(
        T.ActionContext calldata context,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        A.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal,
        bytes32 manifestHash,
        W.CrossOwnerFactsV3 calldata facts
    ) external returns (bytes32);
    function recoverIdentityV3(
        T.ActionContext calldata context,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance,
        bytes32 manifestHash,
        W.CrossOwnerFactsV3 calldata facts
    ) external returns (bytes32);
    function latestRecoveryCapabilityContinuationV3(bytes32 artistId)
        external
        view
        returns (bytes32 recoveryRecordHash);
    function recoveryCapabilityContinuationV3(bytes32 recoveryRecordHash)
        external
        view
        returns (W.CapabilityContinuationV3 memory);
    function identityRevisionRecoveryContinuationV3(bytes32 recordHash)
        external
        view
        returns (bytes32 continuationHash);
    function recoveryRevisionContinuationV3(bytes32 continuationHash)
        external
        view
        returns (W.RevisionContinuationV3 memory);
    function standingRevocationRecoveryContinuationV3(bytes32 recordHash)
        external
        view
        returns (bytes32 continuationHash);
    function recoveryStandingContinuationV3(bytes32 continuationHash)
        external
        view
        returns (W.StandingContinuationV3 memory);
}

interface IStreamArtistIdentityRecoveryCoordinatorV3 {
    function coordinateRegisterIdentityRecoveryActionV3(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
    function coordinateRecoverArtistIdentityV3(
        address actor,
        Recovery.Request calldata request,
        T.Authorization calldata acceptance,
        bytes32 manifestHash
    ) external returns (bytes32);
}
