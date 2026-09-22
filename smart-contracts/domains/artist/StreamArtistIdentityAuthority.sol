// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRecoveredHydrationState as StaticHydrationState } from "./StreamArtistRecoveredHydrationState.sol";
import { IStreamStaticArtistLineageFacts as StaticLineage } from "../../interfaces/stream/artist/IStreamStaticArtistLineageFacts.sol";
import { StreamArtistRecoveredTimingInventory } from "./StreamArtistRecoveredTimingInventory.sol";
import {
    StreamArtistRecoveredIdentityTransport
} from "./StreamArtistRecoveredIdentityTransport.sol";
import { StreamArtistRecoveredHydrationCodec } from "./StreamArtistRecoveredHydrationCodec.sol";
import {
    StreamArtistRecoveredIdentityHydrationTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredTimingTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveredTimingTypes.sol";
import {
    StreamArtistRecoveryRewindTypes as RewindTypes
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";
import { StreamArtistRecoveryRewindReads } from "./StreamArtistRecoveryRewindReads.sol";
import { StreamArtistRecoveryRewindInventory } from "./StreamArtistRecoveryRewindInventory.sol";
import {
    StreamArtistRecoveryRewindCapabilityReads
} from "./StreamArtistRecoveryRewindCapabilityReads.sol";
import { StreamArtistIdentityRewindExtension } from "./StreamArtistIdentityRewindExtension.sol";
import { StreamArtistRewindExtensionDeployment } from "./StreamArtistRewindExtensionDeployment.sol";

import "./StreamArtistAdditiveIdentityHydration.sol";
import {
    StreamArtistStaticIdentityProjection as StaticIdentity
} from "./StreamArtistStaticIdentityProjection.sol";
import {
    IStreamArtistStaticIdentityProjection as StaticProjection
} from "../../interfaces/stream/artist/IStreamArtistStaticIdentityProjection.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailability,
    IStreamArtistEntropyUnavailabilityOwner,
    IStreamArtistEntropyUnavailabilityCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

import "./StreamArtistIdentitySupplementalReads.sol";
import "./StreamArtistIdentityHistoryMutation.sol";
import "./StreamArtistIdentityHydration.sol";
import "./StreamArtistHistoryState.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { StreamArtistIdentityReadDispatch } from "./StreamArtistIdentityReadDispatch.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import { StreamArtistIdentityPayloadReads } from "./StreamArtistIdentityPayloadReads.sol";
import { StreamArtistDormancyRecovery } from "./StreamArtistDormancyRecovery.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";

import "./StreamArtistDormancyReadEncoding.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import { StreamArtistExtensionAdmission } from "./StreamArtistExtensionAdmission.sol";
import {
    StreamArtistGuardianSelectionTypes as GuardianSelectionTypes
} from "../../interfaces/stream/artist/StreamArtistGuardianSelectionTypes.sol";
import {
    StreamArtistGuardianSupersessionTypes as GuardianSupersessionTypes
} from "../../interfaces/stream/artist/StreamArtistGuardianSupersessionTypes.sol";
import { StreamArtistGuardianVestingHistory } from "./StreamArtistGuardianVestingHistory.sol";
import {
    StreamArtistGuardianHistoryTypes as GH
} from "../../interfaces/stream/artist/StreamArtistGuardianHistoryTypes.sol";
import {
    IStreamArtistRecoveryActionOwner
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { StreamArtistRecoveryOwnerReads } from "./StreamArtistRecoveryOwnerReads.sol";

import "./StreamArtistContentHashes.sol";

import "./StreamArtistEconomicsHashes.sol";

import "./StreamArtistOwner.sol";
import "./StreamArtistIdentityData.sol";
import "../../interfaces/stream/artist/IStreamArtistUnavailability.sol";
import "./StreamArtistIdentityWriterExtension.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityRecovery.sol";
import "./StreamArtistIdentityExtensionDeployment.sol";
import "./StreamArtistEstateExtensionDeployment.sol";
import "./StreamArtistRecoveryExtensionDeployment.sol";
import {
    StreamArtistAdjudicationExtensionDeployment
} from "./StreamArtistAdjudicationExtensionDeployment.sol";
import {
    StreamArtistIdentityAdjudicationExtension
} from "./StreamArtistIdentityAdjudicationExtension.sol";
import { StreamArtistRecoveryAdjudicationReads } from "./StreamArtistRecoveryAdjudicationReads.sol";
import {
    StreamArtistRecoveryEvidenceTypes as RecoveryEvidence
} from "../../interfaces/stream/artist/StreamArtistRecoveryEvidenceTypes.sol";
import {
    StreamArtistRecoverySelectionTypesV2 as RecoverySelectionV2
} from "../../interfaces/stream/artist/StreamArtistRecoverySelectionTypesV2.sol";
import "./StreamArtistIdentityDismissalState.sol";
import "./StreamArtistIdentityCauseState.sol";
import "./StreamArtistIdentityResolutionReads.sol";
import "./StreamArtistNonceAvailability.sol";
import "./StreamArtistDelegationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorIdentityState.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistIdentityRevisionState.sol";
import "./StreamArtistIdentityConsentState.sol";
import "./StreamArtistRotationState.sol";
import "./StreamArtistTimingState.sol";
import "./StreamArtistEstateReads.sol";
import "./StreamArtistEstateReadEncoding.sol";
import "./StreamArtistEstateTiming.sol";
import "./StreamArtistWindowConfiguration.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Sole owner of artist identities, authorization replay, liveness and signature bytes.
/// @dev Fixed children apply typed mutations; recovery admits the initial living-authority profile.
contract StreamArtistIdentityAuthority is
    StreamArtistOwner,
    StreamArtistIdentityData,
    IStreamArtistIdentityDismissalEvents,
    IStreamArtistEstateEvents,
    IStreamArtistUnavailabilityEvents,
    IStreamArtistIdentityRecoveryEvents
{
    // Retain the owner ABI for errors propagated by the linked mechanics.
    error InvalidPriorStanding(address priorAddress);
    error InvalidAuthorityCheckpoint();
    error InvalidRotation(bytes32 rotationRecordHash);
    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);
    error BoundExceeded(uint256 actual, uint256 maximum);
    error AddressAlreadyRegistered(address authority);
    error InvalidSignature();
    error InvalidIdentity(bytes32 artistId);
    error InvalidTimestamp(uint64 timestamp);
    error InvalidRecord();
    error Replay(bytes32 replayKey);
    error ExpiredAuthorization(uint64 deadline);
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;
    address public immutable artistWindowAuthority;
    address public immutable identityWriterExtension;
    address public immutable identityEstateExtension;
    address public immutable identityRecoveryExtension;
    address public immutable identityAdjudicationExtension;
    address public immutable identityRewindExtension;

    function authorityNonceWordAt(uint8 kind, bytes32 key, uint256 index)
        external
        view
        override
        returns (uint256 prefix, uint256[32] calldata words, bool exhausted)
    {
        _forwardSupplementalRead();
    }

    function recordPreimageBytes(bytes32 hash) external view returns (bytes calldata) {
        _forwardSupplementalRead();
    }

    function storedPayloadCount() external view returns (uint256) {
        _forwardSupplementalRead();
    }

    function storedPayloadAt(uint256 index) external view returns (address, bytes32, bytes32) {
        _forwardSupplementalRead();
    }

    function recordEntropyUnavailability(T.ActionContext calldata c, EU.Input calldata input)
        external
        returns (bytes32)
    {
        _forwardEstateWriter();
    }

    function entropyUnavailabilityFindingContext(EU.Input calldata input)
        external
        view
        returns (U.Context calldata)
    {
        _forwardIdentityRead();
    }

    function entropyUnavailabilityFindingRecord(bytes32 hash)
        external
        view
        returns (Recovery.FindingRecord calldata, EU.Admission calldata)
    {
        _forwardIdentityRead();
    }

    function recordUnavailability(T.ActionContext calldata c, U.Input calldata p)
        external
        returns (bytes32)
    {
        _forwardEstateWriter();
    }

    function unavailabilityFindingRecord(bytes32 hash)
        external
        view
        returns (Recovery.FindingRecord calldata, U.Admission calldata)
    {
        _forwardIdentityRead();
    }

    function latestUnavailabilityFinding(bytes32 artistId, uint256 collectionId)
        external
        view
        returns (bytes32)
    {
        _forwardSupplementalRead();
    }

    function unavailabilityFindingContext(U.Input calldata p)
        external
        view
        returns (U.Context calldata)
    {
        _forwardIdentityRead();
    }

    function unavailabilityFindingLive(bytes32 hash, T.Binding calldata b)
        external
        view
        returns (bool)
    {
        _forwardSupplementalRead();
    }

    function _unavailabilityContext()
        private
        view
        returns (StreamArtistUnavailabilityState.OwnerContext memory)
    {
        return StreamArtistUnavailabilityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function consumeSanction(
        T.ActionContext calldata c,
        T.Binding calldata b,
        S.Terms calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function consumeRecoveryApproval(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Recovery.ApprovalTerms calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function requestEstate(
        T.ActionContext calldata c,
        Estate.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        StreamArchivalTypes.CoverageFacts calldata coverage
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function cancelEstate(T.ActionContext calldata c, bytes32 artistId, bytes32 expected) external {
        _forwardEstateWriter();
    }

    function executeEstate(
        T.ActionContext calldata c,
        Estate.Execution calldata p,
        StreamArchivalTypes.CoverageFacts calldata coverage,
        Contest.GovernanceWitness calldata governance
    ) external {
        _forwardEstateWriter();
    }

    function estateRequestFacts(Estate.Request calldata p, bytes32 envelopeHash)
        external
        view
        returns (Estate.RequestFacts calldata)
    {
        _forwardIdentityRead();
    }

    function estateExecutionFacts(Estate.Execution calldata p, bytes32 envelopeHash)
        external
        view
        returns (uint32, Estate.AccelerationContext calldata)
    {
        _forwardIdentityRead();
    }

    function estateActivationState(bytes32 artistId)
        external
        view
        returns (address, uint64, bytes32)
    {
        _forwardSupplementalRead();
    }

    function estateActivationRecord(bytes32 record)
        external
        view
        returns (Estate.RequestRecord calldata, uint8, Estate.ExecutionFacts calldata)
    {
        _forwardIdentityRead();
    }

    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        returns (uint256)
    {
        _forwardSupplementalRead();
    }

    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (Estate.AuthorityCapabilities calldata)
    {
        _forwardIdentityRead();
    }

    function estateActivationDigest(Estate.Request calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardSupplementalRead();
    }

    function estateTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64)
    {
        _forwardSupplementalRead();
    }

    event ArtistSuccessorDesignated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint8 successorKind,
        uint32 grantedCapabilities,
        bytes32 conditionsHash,
        bytes32 directiveHash,
        uint256 nonce,
        uint64 signedAt,
        bytes32 designationRecordHash
    );
    event ArtistEstateDirectiveRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint32 grantedCapabilities,
        uint32 forbiddenCapabilities,
        bytes32 directivePayloadHash,
        uint256 nonce,
        uint64 signedAt,
        bytes32 directiveRecordHash
    );

    function recordSuccessorDesignation(
        T.ActionContext calldata c,
        Succ.Designation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function recordEstateDirective(
        T.ActionContext calldata c,
        Succ.Directive calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Succ.PublicDocument calldata document
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function operativeSuccessorRecord(bytes32 artistId) public view returns (bytes32) {
        return StreamArtistSuccessionState.operativeDesignation(_succession, _rotations, artistId);
    }

    function operativeEstateDirective(bytes32 artistId) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function successorDesignation(bytes32 artistId)
        external
        view
        returns (address, uint8, uint32, bytes32, bytes32, uint256)
    {
        _forwardSupplementalRead();
    }

    function successorDesignationRecord(bytes32 record)
        external
        view
        returns (Succ.DesignationRecord calldata)
    {
        _forwardIdentityRead();
    }

    function estateDirectiveRecord(bytes32 record)
        external
        view
        returns (Succ.DirectiveRecord calldata)
    {
        _forwardIdentityRead();
    }

    function estateDirectivePayload(bytes32 record) external view returns (bytes calldata) {
        _forwardIdentityRead();
    }

    event ArtistIdentityContested(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed contester,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint64 contestedAt,
        bytes32 contestRecordHash
    );

    function guardianRecordSupersession(bytes32 recordHash)
        external
        view
        returns (GuardianSupersessionTypes.Status calldata)
    {
        _forwardIdentityRead();
    }

    function guardianRecoverySelection(bytes32 actionId)
        external
        view
        returns (GuardianSelectionTypes.Result calldata, R.GuardianRecord calldata)
    {
        _forwardIdentityRead();
    }

    function guardianRecoveryAuthorityRole(bytes32 artistId, bytes32[] calldata records)
        external
        view
        returns (bytes32)
    {
        _forwardIdentityRead();
    }

    function guardianVestingSnapshot(bytes32 artistId, bytes32 recordHash)
        external
        view
        returns (V.Snapshot calldata)
    {
        _forwardIdentityRead();
    }

    function guardianHistoryState(bytes32 artistId, uint64 index, address actor, bytes32 actionId)
        external
        view
        returns (GH.Head calldata, GH.Entry calldata, GH.Snapshot calldata, uint64)
    {
        _forwardIdentityRead();
    }

    function recoveryExecutorBinding() external view returns (address, bytes32) {
        return IStreamArtistRecoveryActionOwner(identityRecoveryExtension).recoveryExecutorBinding();
    }

    function identityRecoveryActionState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RecoveryAction.Association calldata, RecoveryAction.Veto calldata, bytes32, uint64)
    {
        _forwardIdentityRead();
    }

    function prepareIdentityRecoveryAction(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        RecoveryAction.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal
    ) external returns (bytes32) {
        _forwardRecoveryWriter();
    }

    function vetoPreparedIdentityRecovery(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 actionId,
        bytes32 reasonHash,
        bool scheduled
    ) external {
        if (_recoveryRewinds.actions[actionId].manifestHash != 0) {
            _forwardRewindWriter();
        }
        if (_recoveryAdjudication.actions[actionId].manifestHash != 0) {
            _forwardAdjudicationWriter();
        }
        _forwardRecoveryWriter();
    }

    function recoverIdentity(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32) {
        _forwardRecoveryWriter();
    }

    function identityRecoveryContext(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a
    ) external view returns (IdentityRecovery.Context calldata) {
        _forwardIdentityRead();
    }

    function recoveryRewindEvidenceBinding() external view returns (address, bytes32) {
        return StreamArtistIdentityRewindExtension(identityRewindExtension)
            .recoveryRewindEvidenceBinding();
    }

    function recoveryRewindSelectionBinding() external view returns (address, bytes32) {
        return StreamArtistIdentityRewindExtension(identityRewindExtension)
            .recoveryRewindSelectionBinding();
    }

    // These terminal-forwarded reads return worker bytes, never an implicit Solidity object.
    function recoveryRewindInventoryV3(bytes32 artistId)
        external
        view
        returns (RewindTypes.IdentityInventoryV3 calldata)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryRecordStatusV3(RewindTypes.RecordKind kind, bytes32 recordHash)
        external
        view
        returns (RewindTypes.StatusV3 calldata)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryStandingScopeV3(bytes32 artistId, address priorAddress)
        external
        view
        returns (bytes32, bytes32, bytes32, bytes32)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryRewindBasisV3(bytes32 manifestHash)
        external
        view
        returns (RewindTypes.IdentityBasisV3 calldata)
    {
        _forwardRewindRead();
    }

    function identityRecoveryEvidenceStateV3(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RewindTypes.EvidenceStateV3 calldata)
    {
        _forwardRewindRead();
    }

    function identityRecoveryContextV3(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external view returns (IdentityRecovery.Context calldata) {
        _forwardRewindRead();
    }

    function guardianRecoveryAuthorityRoleV3(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external view returns (bytes32) {
        _forwardRewindRead();
    }

    function prepareIdentityRecoveryActionV3(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        RecoveryAction.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external returns (bytes32) {
        _forwardRewindWriter();
    }

    function recoverIdentityV3(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance,
        bytes32 manifestHash,
        RewindTypes.CrossOwnerFactsV3 calldata facts
    ) external returns (bytes32) {
        _forwardRewindWriter();
    }

    function latestRecoveryCapabilityContinuationV3(bytes32 artistId)
        external
        view
        returns (bytes32)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryCapabilityContinuationV3(bytes32 record)
        external
        view
        returns (RewindTypes.CapabilityContinuationV3 calldata)
    {
        _forwardRewindInventoryRead();
    }

    function identityRevisionRecoveryContinuationV3(bytes32 record)
        external
        view
        returns (bytes32)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryRevisionContinuationV3(bytes32 hash)
        external
        view
        returns (RewindTypes.RevisionContinuationV3 calldata)
    {
        _forwardRewindInventoryRead();
    }

    function standingRevocationRecoveryContinuationV3(bytes32 record)
        external
        view
        returns (bytes32)
    {
        _forwardRewindInventoryRead();
    }

    function recoveryStandingContinuationV3(bytes32 hash)
        external
        view
        returns (RewindTypes.StandingContinuationV3 calldata)
    {
        _forwardRewindInventoryRead();
    }

    function _forwardRewindInventoryRead() private view {
        _forwardIdentityRead();
    }

    function _forwardRewindRead() private view {
        _forwardIdentityRead();
    }

    function _forwardRewindWriter() private {
        address target = identityRewindExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function recoveryEvidenceBinding() external view returns (address, bytes32) {
        return StreamArtistIdentityAdjudicationExtension(identityAdjudicationExtension)
            .recoveryEvidenceBinding();
    }

    function recoverySelectionPreparationBinding() external view returns (address, bytes32) {
        return StreamArtistIdentityAdjudicationExtension(identityAdjudicationExtension)
            .recoverySelectionPreparationBinding();
    }

    function identityRecoveryContextV2(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external view returns (IdentityRecovery.Context calldata) {
        _forwardAdjudicationRead();
    }

    function guardianRecoveryAuthorityRoleV2(
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external view returns (bytes32) {
        _forwardAdjudicationRead();
    }

    function identityRecoveryEvidenceState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RecoveryEvidence.EvidenceStateV2 calldata)
    {
        _forwardAdjudicationRead();
    }

    function recoverySelectionBasisV2(bytes32 manifestHash)
        external
        view
        returns (RecoverySelectionV2.Basis calldata)
    {
        _forwardAdjudicationRead();
    }

    function prepareIdentityRecoveryActionV2(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        RecoveryAction.Witness calldata witness,
        bytes32 previousAssociation,
        bool previousTerminal,
        bytes32 manifestHash
    ) external returns (bytes32) {
        _forwardAdjudicationWriter();
    }

    function recoverIdentityV2(
        T.ActionContext calldata c,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        Contest.GovernanceWitness calldata governance,
        bytes32 manifestHash
    ) external returns (bytes32) {
        _forwardAdjudicationWriter();
    }

    function _forwardAdjudicationRead() private view {
        _forwardIdentityRead();
    }

    function _forwardAdjudicationWriter() private {
        address target = identityAdjudicationExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function identityRecoveryRecord(bytes32 record)
        external
        view
        returns (IdentityRecovery.Record calldata)
    {
        _forwardIdentityRead();
    }

    function latestIdentityRecovery(bytes32 artistId) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function identityRecoveryReceipts(bytes32 record)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        _forwardSupplementalRead();
    }

    function recoveryTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64)
    {
        _forwardSupplementalRead();
    }

    function dismissIdentityContest(
        T.ActionContext calldata c,
        Dismissal.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function identityContestDismissalContext(Dismissal.Request calldata p)
        external
        view
        returns (Dismissal.Context calldata)
    {
        _forwardIdentityRead();
    }

    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        returns (Dismissal.Cause calldata)
    {
        _forwardIdentityRead();
    }

    function identityContestCause(bytes32 hash) external view returns (Dismissal.Cause calldata) {
        _forwardIdentityRead();
    }

    function identityContestDismissalRecord(bytes32 hash)
        external
        view
        returns (Dismissal.Record calldata)
    {
        _forwardIdentityRead();
    }

    function latestIdentityContestDismissal(bytes32 artistId) external view returns (bytes32) {
        _forwardIdentityRead();
    }

    function identityTransitionClosure(bytes32 artistId, bytes32 transition)
        external
        view
        returns (Dismissal.Closure calldata item)
    {
        _forwardIdentityRead();
    }

    function identityRevisionContinuation(bytes32 hash)
        external
        view
        returns (Dismissal.RevisionContinuation calldata)
    {
        _forwardIdentityRead();
    }

    function contestIdentity(
        T.ActionContext calldata c,
        Contest.Request calldata p,
        Contest.GovernanceWitness calldata governance
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function identityContestRecord(bytes32 record) external view returns (Contest.Record calldata) {
        _forwardIdentityRead();
    }

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function identityContestContext(Contest.Request calldata p)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        _forwardSupplementalRead();
    }

    event ArtistIdentityRevisionRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bytes32 previousRecordHash,
        bytes32 revisedRecordHash,
        string identityRecordURI,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 revisionRecordHash
    );

    function recordIdentityRevision(
        T.ActionContext calldata c,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function staticAuthorityState(bytes32 artistId)
        external
        view
        returns (address, uint8, uint8, bytes32)
    {
        T.Identity storage r = _identity.identities[artistId];
        return (r.authorityAddress, r.authorityClass, r.status, r.identityRecordHash);
    }

    /// @notice Direct original history and optional imported-only origin facts.
    function staticArtistLineage(bytes32 hash) external view returns (StaticLineage.Lineage calldata) {
        StreamArtistHistoryState.State storage s = StreamArtistHistoryState.state();
        // The public result is the same fifteen-word Lineage tuple. Every narrow source
        // is explicitly widened before this flat memory frame is returned.
        bytes32[15] memory words;
        words[0] = bytes32(uint256(s.cutover ? 1 : 0));
        words[1] = bytes32(uint256(uint160(s.successor)));
        words[2] = bytes32(uint256(s.cutoverBlock));
        words[3] = bytes32(s.bindings.length);
        if (s.bindings.length == 1) {
            address predecessor = s.bindings[0].predecessorRegistry;
            words[4] = bytes32(uint256(uint160(predecessor)));
            words[5] = bytes32(uint256(s.bindings[0].snapshotBlock));
            words[6] = s.bindings[0].importRoot;
            words[7] = s.bindings[0].manifestHash;
            words[8] = s.predecessorCode[predecessor];
            words[9] = bytes32(s.predecessorCount[predecessor]);
        }
        if (hash != 0) {
            (bytes32 stored, bytes32 commitment_, uint64 revision, uint8 index, bytes32 profile) =
                StaticHydrationState.originFactsInline(hash, artistRegistry);
            words[10] = stored;
            words[11] = commitment_;
            words[12] = bytes32(uint256(revision));
            words[13] = bytes32(uint256(index));
            words[14] = profile;
        }
        assembly ("memory-safe") { return(words, 480) }
    }

    /// @dev Exact original operative document selection, with direct reads throughout.
    function staticIdentityMetadata(bytes32 artistId)
        external
        view
        returns (string memory, bytes32)
    {
        T.Identity storage original = _identity.identities[artistId];
        if (original.identityRecordHash == 0) revert T.InvalidIdentity(artistId);
        bytes32 candidate = _identityRevisions.pendingRecord[artistId];
        bytes32 selected = _identityRevisions.latestRecord[artistId];
        if (candidate != 0) {
            StaticIdentity.Context memory context = _staticIdentityContext(artistId, candidate);
            if (!StaticIdentity.recorded(StaticIdentity.key(artistRegistry, context))) {
                revert StaticProjection.StaticIdentityMaturityUnavailable(artistId, candidate);
            }
            selected = candidate;
        }
        if (selected == 0) return (original.displayName, original.identityRecordHash);
        StreamArtistIdentityRevisionTypes.Record storage r = _identityRevisions.records[selected];
        return (r.displayName, r.revisedRecordHash);
    }

    function checkpointStaticIdentityMaturity(bytes32 artistId) external returns (bytes32) {
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        bytes32 candidate = _identityRevisions.pendingRecord[artistId];
        if (candidate == 0 || _identity.identities[artistId].identityRecordHash == 0) {
            revert StaticProjection.StaticIdentityMaturityUnavailable(artistId, candidate);
        }
        StaticIdentity.Context memory context = _staticIdentityContext(artistId, candidate);
        if (block.timestamp < context.association.windowEndsAt) {
            revert StaticProjection.StaticIdentityMaturityUnavailable(artistId, candidate);
        }
        return StaticIdentity.record(artistRegistry, context);
    }

    function _staticIdentityContext(bytes32 artistId, bytes32 candidate)
        private
        view
        returns (StaticIdentity.Context memory c)
    {
        T.Identity storage original = _identity.identities[artistId];
        c.artistId = artistId;
        c.candidate = candidate;
        c.documentHash = _identityRevisions.records[candidate].revisedRecordHash;
        c.latestExecution = _rotations.latestExecution[artistId];
        c.authority = original.authorityAddress;
        c.authorityClass = original.authorityClass;
        c.status = original.status;
        c.association = _identityRevisions.associations[candidate];
        R.ProvisionalAssociation memory a = c.association;
        if (a.transitionRecordHash == 0) {
            if (a.windowEndsAt != 0) {
                revert StaticProjection.StaticIdentityMaturityUnavailable(artistId, candidate);
            }
            return c;
        }
        bytes32 record = a.transitionRecordHash;
        R.TransitionState memory t;
        // Original Rotation-first selection and original same-owner fallback order.
        if (_rotations.rotations[record].recordHash != 0) {
            t = _rotations.rotations[record].transition;
        } else if (_dormancy.transitions[record].recordHash != 0) {
            t = _dormancy.transitions[record];
        } else {
            bool rotation = _rotations.rotations[record].recordHash == record;
            bool estate = _estate.requests[record].recordHash == record;
            bool recovered = _identityRecovery.records[record].recordHash == record;
            if ((rotation ? 1 : 0) + (estate ? 1 : 0) + (recovered ? 1 : 0) != 1) {
                revert R.InvalidRotation(record);
            }
            t = rotation
                ? _rotations.rotations[record].transition
                : estate ? _estate.transitions[record] : _identityRecovery.transitions[record];
            if (recovered && t.artistId != _identityRecovery.records[record].fields.artistId) {
                revert R.InvalidRotation(record);
            }
        }
        if (t.recordHash != record || t.artistId == 0 || t.phase == 0) {
            revert R.InvalidRotation(record);
        }
        if (
            t.artistId != artistId || t.phase != 2 || t.executedAt == 0
                || t.postWindowEndsAt != a.windowEndsAt
                || (t.contestedAt != 0 && t.contestedAt < a.windowEndsAt)
        ) {
            revert StaticProjection.StaticIdentityMaturityUnavailable(artistId, candidate);
        }
        c.transition = t;
    }

    function operativeIdentityRecord(bytes32 artistId) public view returns (bytes32) {
        _forwardIdentityRead();
    }

    function identityRecordBytes(bytes32 artistId) external view returns (bytes calldata) {
        _forwardSupplementalRead();
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record calldata)
    {
        _forwardIdentityRead();
    }

    function operativeIdentityMetadata(bytes32 artistId)
        external
        view
        returns (bytes32, string calldata, string calldata)
    {
        _forwardIdentityRead();
    }

    function artistDisplayName(bytes32 artistId)
        external
        view
        returns (string calldata name, bytes32 hash)
    {
        _forwardIdentityRead();
    }

    event ArtistAuthorizationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 revokedDigest,
        uint256 revokedNonce,
        uint256 nonce,
        uint64 revokedAt,
        bytes32 revocationRecordHash
    );

    function revokeAuthorization(
        T.ActionContext calldata c,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State calldata)
    {
        _forwardIdentityRead();
    }

    event ArtistDelegationGranted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        uint256 indexed collectionId,
        uint32 capabilities,
        uint64 notBefore,
        uint64 expiresAt,
        uint64 maxUses,
        bytes32 constraintsHash,
        uint256 nonce,
        bytes32 delegationRecordHash
    );
    event ArtistDelegationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed delegate,
        bytes32 indexed delegationRecordHash,
        bytes32 reasonHash,
        address signer,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt
    );

    event ArtistIdentityRegistered(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed authorityAddress,
        bytes32 identityRecordHash,
        string identityRecordURI,
        uint256 registrationNonce
    );
    /// @notice Supplementary mirror evidence; the canonical identity document remains authoritative.
    event ArtistIdentityDisplayNameStored(
        bytes32 indexed artistId, bytes32 indexed identityRecordHash, string displayName
    );

    constructor(
        address registry_,
        address coordinator_,
        address archive_,
        address core_,
        address manager_,
        address extensionFactory_,
        address[3] memory extensions_
    )
        StreamArtistOwner(
            registry_,
            coordinator_,
            archive_,
            keccak256("domain:identity_authority"),
            core_,
            manager_
        )
    {
        artistWindowAuthority = StreamArtistTimingState.canonicalAuthority(core_, manager_);
        StreamArtistRecoveredTimingInventory.initialize();
        StreamArtistExtensionAdmission.identity(
            extensionFactory_,
            extensions_,
            [address(this), registry_, coordinator_, archive_, core_, manager_]
        );
        (address recoveryAuthority, bytes32 recoveryAuthorityHash) =
            StreamArtistIdentityRecoveryExtension(extensions_[2]).recoveryExecutorBinding();
        if (
            recoveryAuthority != artistWindowAuthority
                || recoveryAuthorityHash != artistWindowAuthority.codehash
        ) revert T.InvalidBinding();
        identityWriterExtension = extensions_[0];
        identityEstateExtension = extensions_[1];
        identityRecoveryExtension = extensions_[2];
        identityAdjudicationExtension = StreamArtistAdjudicationExtensionDeployment.deploy(
            address(this), registry_, coordinator_, archive_, core_, manager_
        );
        identityRewindExtension = StreamArtistRewindExtensionDeployment.deploy(
            address(this), registry_, coordinator_, archive_, core_, manager_
        );
    }

    function setGuardians(
        T.ActionContext calldata c,
        R.GuardianSet calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function stageRotation(
        T.ActionContext calldata c,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization,
        T.SignerApproval calldata oldProof,
        T.SignerApproval calldata newProof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function approveRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
    {
        _forwardEstateWriter();
    }

    function vetoRotation(
        T.ActionContext calldata c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) external {
        _forwardEstateWriter();
    }

    function executeRotation(T.ActionContext calldata c, bytes32 artistId, bytes32 expected)
        external
    {
        _forwardEstateWriter();
    }

    function revokeStanding(
        T.ActionContext calldata c,
        R.StandingRevocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function guardianSet(bytes32 artistId)
        external
        view
        returns (address[] calldata, uint32, uint64, bytes32)
    {
        _forwardIdentityRead();
    }

    function pendingRotation(bytes32 artistId)
        external
        view
        returns (address, address, uint64, uint32, bytes32)
    {
        _forwardIdentityRead();
    }

    function priorAddressStandingRevoked(bytes32 artistId, address account)
        external
        view
        returns (bool, bytes32)
    {
        _forwardSupplementalRead();
    }

    function guardianSetRecord(bytes32 record) external view returns (R.GuardianRecord calldata) {
        _forwardIdentityRead();
    }

    function rotationRecord(bytes32 record) external view returns (R.RotationRecord calldata) {
        _forwardIdentityRead();
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        returns (R.StandingRecord calldata)
    {
        _forwardIdentityRead();
    }

    function artistTransitionState(bytes32 record)
        external
        view
        returns (R.TransitionState calldata)
    {
        _forwardIdentityRead();
    }

    function lastArtistTransition(bytes32 artistId) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function identityRevisionProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation calldata)
    {
        _forwardIdentityRead();
    }

    function activeAuthorityWindow(bytes32 artistId) external view returns (bytes32, uint64, bool) {
        _forwardSupplementalRead();
    }

    function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        _forwardSupplementalRead();
    }

    function provisionalAssociation(bytes32 artistId)
        external
        view
        returns (R.ProvisionalAssociation calldata)
    {
        _forwardSupplementalRead();
    }

    function provisionalRecordEligible(bytes32 artistId, R.ProvisionalAssociation calldata a)
        external
        view
        returns (bool)
    {
        _forwardSupplementalRead();
    }

    function artistWindowInfo(bytes32 parameter) external view returns (uint64, uint64, uint64) {
        _forwardSupplementalRead();
    }

    function artistWindowScope(bytes32 parameter) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function artistWindowStateHash(bytes32 parameter, uint64 value, uint64 revision)
        external
        view
        returns (bytes32)
    {
        _forwardSupplementalRead();
    }

    function configureArtistWindow(
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) external {
        if (msg.sender != operationCoordinator) revert T.Unauthorized(msg.sender);
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        StreamArtistWindowConfiguration.configure(
            _rotations,
            _estate,
            _unavailability,
            _dormancy,
            artistWindowAuthority,
            actor,
            parameter,
            newValue,
            expectedRevision
        );
    }

    function nextRegistrationNonce() external view returns (uint256) {
        _forwardSupplementalRead();
    }

    function activeIdentity(address account) external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function identity(bytes32 artistId) external view returns (T.Identity calldata) {
        _forwardIdentityRead();
    }

    /// @notice Fixed-size authority facts with the immutable registration hash, not the operative document.
    function authorityState(bytes32 artistId)
        external
        view
        returns (
            address authorityAddress,
            uint8 authorityClass,
            uint8 status,
            bytes32 identityRecordHash
        )
    {
        _forwardSupplementalRead();
    }

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes calldata) {
        _forwardIdentityRead();
    }

    function signatureBundle(bytes32 recordHash) external view returns (bytes calldata) {
        _forwardIdentityRead();
    }

    function nonceUsed(bytes32 artistId, uint256 nonce) public view returns (bool) {
        _forwardIdentityRead();
    }

    function delegationRecord(bytes32 grant) external view returns (D.Record calldata) {
        _forwardIdentityRead();
    }

    /// @notice Automatic estate revocation is separate from the immutable grant and its explicit revoke record.
    function delegationEpochState(bytes32 grant)
        external
        view
        returns (bool valid, uint64 recorded, uint64 current)
    {
        _forwardSupplementalRead();
    }

    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        _forwardSupplementalRead();
    }

    function registerCollaboratorIdentity(
        T.ActionContext calldata c,
        C.IdentityProposal calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function consumeCollaboratorAcceptance(
        T.ActionContext calldata c,
        C.BindingAcceptance calldata p,
        bytes32 artistId,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function delegatedNonceState(bytes32 artistId, address delegate, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        _forwardSupplementalRead();
    }

    function grantDelegation(
        T.ActionContext calldata c,
        D.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function revokeDelegation(
        T.ActionContext calldata c,
        D.Revocation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeDelegatedPolicyConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function consumeDelegatedSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function consumeDelegatedEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardEstateWriter();
    }

    function consumeDelegatedRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardEstateWriter();
    }

    function registerIdentity(
        T.ActionContext calldata c,
        address artist,
        bytes32 documentHash,
        string calldata uri,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function consumeAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeSaleConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Sale.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumePolicy(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.PolicyConsent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeEconomics(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumePayout(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeDelegatedAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeAttestation(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRatification(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Ratification calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeRoyaltyFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeContentConsent(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Consent calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function consumeContentFreeze(
        T.ActionContext calldata c,
        T.Binding calldata b,
        Content.Freeze calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32 record) {
        _forwardIdentityWriter();
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _forwardIdentityRead() private view {
        _returnResolution(
            StreamArtistIdentityReadDispatch.read(
                _identity,
                _delegations,
                _identityRevisions,
                _rotations,
                _identityContests,
                _succession,
                _resolutions,
                _estate,
                _unavailability,
                _identityRecovery,
                _dormancy,
                _stewardGrants,
                _stewardCapabilityGrants,
                _replay,
                _recoveryAdjudication,
                _recoveryRewinds,
                StreamArtistIdentityReadDispatch.Input(_ownerContext(), msg.data)
            )
        );
    }

    function _returnResolution(bytes memory encoded) private pure {
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function _forwardIdentityWriter() private {
        address target = identityWriterExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function _forwardEstateWriter() private {
        address target = identityEstateExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function _forwardRecoveryWriter() private {
        address target = identityRecoveryExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function initiateDormancy(
        T.ActionContext calldata c,
        Dorm.Initiation calldata p,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function cancelDormancy(T.ActionContext calldata c, bytes32 id, bytes32 expected, bytes32 grant)
        external
    {
        _forwardEstateWriter();
    }

    function completeDormancy(
        T.ActionContext calldata c,
        Dorm.Completion calldata p,
        Contest.GovernanceWitness calldata g
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function recordStewardSanctionGrant(
        T.ActionContext calldata c,
        SG.Grant calldata p,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function dormancyState(bytes32 id) external view returns (uint8, uint64, uint64) {
        _forwardIdentityRead();
    }

    function dormancyNotice(bytes32 id) external view returns (bytes32, uint8, bytes32) {
        _forwardIdentityRead();
    }

    function dormancyRecord(bytes32 n)
        external
        view
        returns (Dorm.Notice calldata, uint8, Dorm.Terminal calldata)
    {
        _forwardIdentityRead();
    }

    function dormancyInitiationContext(Dorm.Initiation calldata p)
        external
        view
        returns (Dorm.Context calldata)
    {
        _forwardIdentityRead();
    }

    function dormancyCompletionContext(Dorm.Completion calldata p)
        external
        view
        returns (Dorm.Context calldata, Dorm.Plan calldata)
    {
        _forwardIdentityRead();
    }

    function dormancyCompletionEvidence(Dorm.Completion calldata p)
        external
        view
        returns (bytes calldata)
    {
        _forwardIdentityRead();
    }

    function dormancyTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64)
    {
        _forwardIdentityRead();
    }

    function dormancyResolutionState(bytes32 id, bytes32 cause)
        external
        view
        returns (bytes32, uint8, bytes32)
    {
        _forwardIdentityRead();
    }

    function stewardSanctionGrant(bytes32 id) external view returns (bool, bytes32) {
        _forwardSupplementalRead();
    }

    function stewardSanctionGrantRecord(bytes32 hash)
        external
        view
        returns (SG.GrantRecord calldata)
    {
        _forwardIdentityRead();
    }

    function stewardSanctionGrantSignature(bytes32 hash) external view returns (bytes calldata) {
        _forwardSupplementalRead();
    }

    function stewardSanctionGrantDigest(SG.Grant calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardSupplementalRead();
    }

    function grantStewardCapabilities(
        T.ActionContext calldata c,
        SC.Grant calldata p,
        SC.Witness calldata w
    ) external returns (bytes32) {
        _forwardEstateWriter();
    }

    function stewardCapabilityGrantContext(SC.Grant calldata p)
        external
        view
        returns (SC.Context calldata)
    {
        _forwardIdentityRead();
    }

    function stewardCapabilityGrantRecord(bytes32 hash) external view returns (SC.Record calldata) {
        _forwardIdentityRead();
    }

    function stewardCapabilityGrantState(bytes32 appointment)
        external
        view
        returns (bytes32, uint32)
    {
        _forwardSupplementalRead();
    }

    function artistRecordChainHash(bytes32 id) external view returns (bytes32 tip) {
        _forwardSupplementalRead();
    }

    function collectionRecordChainHash(uint256 id) external view returns (bytes32 tip) {
        _forwardSupplementalRead();
    }

    function artistHistoryLane(uint8 kind, bytes32 id) external view returns (bytes32, uint64) {
        _forwardSupplementalRead();
    }

    function artistHistoryRecordAt(uint8 kind, bytes32 id, uint64 index)
        external
        view
        returns (bytes32, bytes32)
    {
        _forwardSupplementalRead();
    }

    function artistHistoryContinuityCommitment() external view returns (bytes32) {
        _forwardSupplementalRead();
    }

    function artistHistorySourceCursor(address source) external view returns (uint256) {
        _forwardSupplementalRead();
    }

    function importedHistoryBindingCount() external view returns (uint256) {
        _forwardSupplementalRead();
    }

    function importedHistoryBinding(uint256 index)
        external
        view
        returns (address, uint64, bytes32, bytes32)
    {
        _forwardSupplementalRead();
    }

    function artistHistoryPredecessorBinding(address source)
        external
        view
        returns (bool, bytes32, uint256)
    {
        _forwardSupplementalRead();
    }

    function verifyImportedRecord(bytes32 root, H.Leaf calldata p, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        _forwardSupplementalRead();
    }

    function importedLaneVerified(uint8 kind, bytes32 id)
        external
        view
        returns (bool, bytes32, uint64)
    {
        _forwardSupplementalRead();
    }

    function artistRegistryCutover() external view returns (bool, address, uint64) {
        _forwardSupplementalRead();
    }

    function artistHistoryImportContext(
        address predecessor,
        uint64 snapshot,
        bytes32 root,
        bytes32 manifest
    ) external view returns (H.Context calldata) {
        _forwardSupplementalRead();
    }

    function syncArtistNativeHistory(address source, uint256 first, H.Receipt[] calldata rows)
        external
    {
        if (msg.sender != operationCoordinator) revert T.Unauthorized(msg.sender);
        StreamArtistIdentityHistoryMutation.syncEncoded(core, artistRegistry, msg.data);
    }

    function applyArtistHistoryImport(
        T.ActionContext calldata c,
        H.Binding calldata p,
        bytes32 actionId
    ) external {
        _check(c, 55);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityHistoryMutation.importEncoded(
                _replay, _ownerContext(), artistWindowAuthority, msg.data
            );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function applyArtistHistoryLaneVerification(
        T.ActionContext calldata c,
        uint256 index,
        H.Leaf calldata p,
        bytes32[] calldata proof
    ) external {
        _check(c, 56);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityHistoryMutation.verifyEncoded(
                _replay, _ownerContext(), artistWindowAuthority, msg.data
            );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function applyArtistRegistryCutover(T.ActionContext calldata c) external {
        _check(c, 57);
        StreamArtistIdentityState.Mutation memory m =
            StreamArtistIdentityHistoryMutation.cutoverEncoded(
                _replay, _ownerContext(), artistWindowAuthority, msg.data
            );
        _commit(c, m.action, m.state, m.replay, m.record);
    }

    function _baselineTiming() private view {
        (,, uint64 repudiationRevision) = StreamArtistRepudiationTiming.info();
        if (repudiationRevision != 1) revert T.UnsupportedProfile();
        if (
            _rotations.timingRevision != 0 || _estate.noticeRevision != 0
                || _dormancy.timingRevision != 0 || _unavailability.timingRevision != 0
        ) revert T.UnsupportedProfile();
    }

    function authorityHydrationState(AH.Query calldata q)
        external
        view
        override
        returns (bytes memory)
    {
        return _additiveHydrationState();
    }

    function authorityDelegationHydrationState(AH.Query calldata q)
        external
        view
        returns (bytes memory)
    {
        return _additiveHydrationState();
    }

    function authorityLivingIdentityHydrationState(AH.Query calldata q)
        external
        view
        returns (bytes memory)
    {
        return _additiveHydrationState();
    }

    function _additiveHydrationState() private view returns (bytes memory) {
        _baselineTiming();
        return StreamArtistAdditiveIdentityHydration.exportEncoded(
            _identity,
            _delegations,
            _identityRevisions,
            _estate,
            _dormancy,
            _unavailability,
            msg.data
        );
    }

    function authorityEntropyFindingHydrationState(AH.Query calldata q)
        external
        view
        returns (bytes memory)
    {
        return _additiveHydrationState();
    }

    function entropyUnavailabilityFindingOrigin(bytes32 hash) external view returns (address) {
        _forwardIdentityRead();
    }

    function _hydrateAuthority(AH.Query calldata q, AH.OwnerData calldata p) internal override {
        if (StreamArtistRecoveredHydrationCodec.isState(p.typedState, 2)) {
            StreamArtistRecoveredIdentityTransport.importEncoded(
                _recoveredHydrationRoots(), msg.data[4:]
            );
            return;
        }
        _baselineTiming();
        StreamArtistAdditiveIdentityHydration.importEncoded(
            _identity,
            _delegations,
            _identityRevisions,
            _estate,
            _dormancy,
            _unavailability,
            msg.data[4:]
        );
    }

    function recoveredIdentityHydrationRaw(
        AH.Query calldata,
        StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata
    ) external view returns (StreamArtistRecoveredIdentityHydrationTypes.Bundle calldata) {
        _forwardRecoveredIdentityRead();
    }

    function _recoveredHydrationFeatures() internal pure override returns (uint256) {
        return StreamArtistRecoveredHydrationTypes.MULTIPLE_ATTESTATIONS_GRAPH_FEATURES;
    }

    function recoveredAuthorityHydrationState(
        AH.Query calldata,
        StreamArtistRecoveredHydrationTypes.OwnerProvenance calldata
    ) external view override returns (bytes calldata) {
        _forwardRecoveredIdentityRead();
    }

    function recoveredIdentityHydrationActionArtist(bytes32) external view returns (bytes32) {
        _forwardRecoveredIdentityRead();
    }

    function recoveredHydrationAuxiliaryPoint(bytes32, bytes32)
        external
        view
        override
        returns (StreamArtistRecoveredHydrationTypes.Point calldata)
    {
        _forwardRecoveredIdentityRead();
    }

    function recoveredTimingCheckpoint()
        external
        view
        returns (StreamArtistRecoveredTimingTypes.Checkpoint calldata)
    {
        _forwardRecoveredIdentityRead();
    }

    function recoveredTimingEntryAt(uint256)
        external
        view
        returns (StreamArtistRecoveredTimingTypes.Entry calldata)
    {
        _forwardRecoveredIdentityRead();
    }

    function _forwardRecoveredIdentityRead() private view {
        _returnResolution(
            StreamArtistRecoveredIdentityTransport.read(
                _recoveredHydrationRoots(), _ownerContext(), msg.data
            )
        );
    }

    function _recoveredHydrationRoots() private pure returns (uint256[17] memory roots) {
        assembly ("memory-safe") {
            mstore(roots, _identity.slot)
            mstore(add(roots, 32), _delegations.slot)
            mstore(add(roots, 64), _collaboratorAccounts.slot)
            mstore(add(roots, 96), _identityRevisions.slot)
            mstore(add(roots, 128), _rotations.slot)
            mstore(add(roots, 160), _identityContests.slot)
            mstore(add(roots, 192), _succession.slot)
            mstore(add(roots, 224), _resolutions.slot)
            mstore(add(roots, 256), _estate.slot)
            mstore(add(roots, 288), _unavailability.slot)
            mstore(add(roots, 320), _identityRecovery.slot)
            mstore(add(roots, 352), _dormancy.slot)
            mstore(add(roots, 384), _stewardGrants.slot)
            mstore(add(roots, 416), _stewardCapabilityGrants.slot)
            mstore(add(roots, 448), _recoveryAdjudication.slot)
            mstore(add(roots, 480), _recoveryRewinds.slot)
            mstore(add(roots, 512), _replay.slot)
        }
    }

    function _forwardSupplementalRead() private view {
        // Exact declared roots, not offsets inferred from another contract's layout.
        uint256[15] memory roots;
        assembly ("memory-safe") {
            mstore(roots, _identity.slot)
            mstore(add(roots, 32), _collaboratorAccounts.slot)
            mstore(add(roots, 64), _delegations.slot)
            mstore(add(roots, 96), _identityRevisions.slot)
            mstore(add(roots, 128), _rotations.slot)
            mstore(add(roots, 160), _identityContests.slot)
            mstore(add(roots, 192), _succession.slot)
            mstore(add(roots, 224), _resolutions.slot)
            mstore(add(roots, 256), _estate.slot)
            mstore(add(roots, 288), _unavailability.slot)
            mstore(add(roots, 320), _identityRecovery.slot)
            mstore(add(roots, 352), _dormancy.slot)
            mstore(add(roots, 384), _stewardGrants.slot)
            mstore(add(roots, 416), _stewardCapabilityGrants.slot)
            mstore(add(roots, 448), _replay.slot)
        }
        _returnResolution(
            StreamArtistIdentitySupplementalReads.read(roots, _ownerContext(), msg.data)
        );
    }

    function consumeAttributionDispute(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        T.Binding calldata b,
        AD.Standing calldata standing,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function consumeRepudiation(
        T.ActionContext calldata c,
        AD.Filing calldata p,
        RP.Admission calldata admission,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) external returns (bytes32) {
        _forwardIdentityWriter();
    }

    function contestRepudiation(T.ActionContext calldata c, RP.GuardianProof calldata proof)
        external
        returns (bytes32)
    {
        _forwardIdentityWriter();
    }

    function noteRepudiationCancellation(T.ActionContext calldata c, RP.Record calldata record)
        external
    {
        _forwardIdentityWriter();
    }
}
