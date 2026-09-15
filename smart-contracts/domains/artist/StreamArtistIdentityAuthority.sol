// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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
    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);
    error BoundExceeded(uint256 actual, uint256 maximum);
    error AddressAlreadyRegistered(address authority);
    error InvalidSignature();
    error InvalidIdentity(bytes32 artistId);
    error InvalidTimestamp(uint64 timestamp);
    error InvalidRecord();
    error Replay(bytes32 replayKey);
    error StaleOwnerSnapshot(bytes32 domainId);
    error InvalidOperation(uint16 operationId);
    error ExpiredAuthorization(uint64 deadline);
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;
    address public immutable artistWindowAuthority;
    address public immutable identityWriterExtension;
    address public immutable identityEstateExtension;
    address public immutable identityRecoveryExtension;

    function authorityNonceWordAt(uint8 kind, bytes32 key, uint256 index)
        external
        view
        override
        returns (uint256 prefix, uint256[32] memory words, bool exhausted)
    {
        prefix = StreamArtistAuthorityCheckpoint.noncePrefixAt(kind, key, index);
        if (kind == 1) {
            (words, exhausted) = _identity.nonceAvailability[key].checkpointWords(prefix);
        } else if (kind == 2) {
            (words, exhausted) = _delegations.availability[key].checkpointWords(prefix);
        } else if (kind == 3 && uint256(key) >> 160 == 0) {
            (words, exhausted) = _collaboratorAccounts.available[address(
                    uint160(uint256(key))
                )].checkpointWords(prefix);
        } else if (kind == 4) {
            (words, exhausted) = _rotations.acceptanceNonces[key].checkpointWords(prefix);
        } else if (kind == 5) {
            (words, exhausted) = _estate.nonceAvailability[key].checkpointWords(prefix);
        } else {
            revert StreamArtistAuthorityCheckpoint.InvalidAuthorityCheckpoint();
        }
    }

    function recordPreimageBytes(bytes32 hash) external view returns (bytes memory) {
        return StreamArtistPayloadStore.recordBytes(hash);
    }

    function storedPayloadCount() external view returns (uint256) {
        return StreamArtistPayloadStore.count();
    }

    function storedPayloadAt(uint256 index) external view returns (address, bytes32, bytes32) {
        return StreamArtistPayloadStore.at(index);
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
        returns (Recovery.FindingRecord memory, U.Admission memory)
    {
        _forwardIdentityRead();
    }

    function latestUnavailabilityFinding(bytes32 artistId, uint256 collectionId)
        external
        view
        returns (bytes32)
    {
        return _unavailability.latest[
            StreamArtistUnavailabilityState.associationKey(artistId, collectionId)
        ];
    }

    function unavailabilityFindingContext(U.Input calldata p)
        external
        view
        returns (U.Context memory)
    {
        _forwardIdentityRead();
    }

    function unavailabilityFindingLive(bytes32 hash, T.Binding calldata b)
        external
        view
        returns (bool)
    {
        return StreamArtistUnavailabilityState.live(_unavailability, hash, b);
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
        returns (Estate.RequestFacts memory)
    {
        _forwardIdentityRead();
    }

    function estateExecutionFacts(Estate.Execution calldata p, bytes32 envelopeHash)
        external
        view
        returns (uint32, Estate.AccelerationContext memory)
    {
        _forwardIdentityRead();
    }

    function estateActivationState(bytes32 artistId)
        external
        view
        returns (address, uint64, bytes32)
    {
        bytes32 hash = _estate.pending[artistId];
        Estate.RequestRecord storage item = _estate.requests[hash];
        return (item.terms.successor, item.noticeEndsAt, hash);
    }

    function estateActivationRecord(bytes32 record)
        external
        view
        returns (Estate.RequestRecord memory, uint8, Estate.ExecutionFacts memory)
    {
        _forwardIdentityRead();
    }

    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        returns (uint256)
    {
        return _estate.nonceHints[StreamArtistEstateState.nonceLane(artistId, successor)];
    }

    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (Estate.AuthorityCapabilities memory)
    {
        _forwardIdentityRead();
    }

    function estateActivationDigest(Estate.Request calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistEstateHashes.digest(_environment(), p, a);
    }

    function estateTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64)
    {
        Estate.RequestRecord storage item = _estate.requests[record];
        if (record == bytes32(0) || item.recordHash != record || item.terms.artistId == bytes32(0))
        {
            revert R.InvalidRotation(record);
        }
        return (item.incumbent, item.guardianRecordHash, item.standingTailSeconds);
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
        return StreamArtistSuccessionState.operativeDirective(_succession, _rotations, artistId);
    }

    function successorDesignation(bytes32 artistId)
        external
        view
        returns (address, uint8, uint32, bytes32, bytes32, uint256)
    {
        Succ.DesignationRecord storage r =
            _succession.designations[operativeSuccessorRecord(artistId)];
        return (
            r.terms.successor,
            r.terms.successorKind,
            r.terms.grantedCapabilities,
            r.terms.conditionsHash,
            r.terms.directiveHash,
            r.nonce
        );
    }

    function successorDesignationRecord(bytes32 record)
        external
        view
        returns (Succ.DesignationRecord memory)
    {
        _forwardIdentityRead();
    }

    function estateDirectiveRecord(bytes32 record)
        external
        view
        returns (Succ.DirectiveRecord memory)
    {
        _forwardIdentityRead();
    }

    function estateDirectivePayload(bytes32 record) external view returns (bytes memory) {
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
        returns (GuardianSupersessionTypes.Status memory)
    {
        _forwardIdentityRead();
    }

    function guardianRecoverySelection(bytes32 actionId)
        external
        view
        returns (GuardianSelectionTypes.Result memory, R.GuardianRecord memory)
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
        returns (V.Snapshot memory)
    {
        _forwardIdentityRead();
    }

    function guardianHistoryState(bytes32 artistId, uint64 index, address actor, bytes32 actionId)
        external
        view
        returns (GH.Head memory, GH.Entry memory, GH.Snapshot memory, uint64)
    {
        _forwardIdentityRead();
    }

    function recoveryExecutorBinding() external view returns (address, bytes32) {
        return IStreamArtistRecoveryActionOwner(identityRecoveryExtension).recoveryExecutorBinding();
    }

    function identityRecoveryActionState(bytes32 artistId, bytes32 actionId)
        external
        view
        returns (RecoveryAction.Association memory, RecoveryAction.Veto memory, bytes32, uint64)
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
    ) external view returns (IdentityRecovery.Context memory) {
        _forwardIdentityRead();
    }

    function identityRecoveryRecord(bytes32 record)
        external
        view
        returns (IdentityRecovery.Record memory)
    {
        _forwardIdentityRead();
    }

    function latestIdentityRecovery(bytes32 artistId) external view returns (bytes32) {
        return _identityRecovery.latest[artistId];
    }

    function identityRecoveryReceipts(bytes32 record)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return StreamArtistIdentityRecoveryState.receiptCommitments(_identityRecovery, record);
    }

    function recoveryTransitionStanding(bytes32 record)
        external
        view
        returns (address, bytes32, uint64)
    {
        return
            StreamArtistRecoveryOwnerReads.standing(_identityRecovery, _rotations, _estate, record);
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
        returns (Dismissal.Context memory)
    {
        _forwardIdentityRead();
    }

    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        returns (Dismissal.Cause memory)
    {
        _forwardIdentityRead();
    }

    function identityContestCause(bytes32 hash) external view returns (Dismissal.Cause memory) {
        _forwardIdentityRead();
    }

    function identityContestDismissalRecord(bytes32 hash)
        external
        view
        returns (Dismissal.Record memory)
    {
        _forwardIdentityRead();
    }

    function latestIdentityContestDismissal(bytes32 artistId) external view returns (bytes32) {
        _forwardIdentityRead();
    }

    function identityTransitionClosure(bytes32 artistId, bytes32 transition)
        external
        view
        returns (Dismissal.Closure memory item)
    {
        _forwardIdentityRead();
    }

    function identityRevisionContinuation(bytes32 hash)
        external
        view
        returns (Dismissal.RevisionContinuation memory)
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

    function identityContestRecord(bytes32 record) external view returns (Contest.Record memory) {
        _forwardIdentityRead();
    }

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32) {
        return _identityContests.latest[artistId];
    }

    function identityContestContext(Contest.Request calldata p)
        external
        view
        returns (bytes32, bytes32, bytes32)
    {
        return StreamArtistIdentityCauseState.context(
            _resolutions, _identity, _rotations, _identityContests, _succession, _ownerContext(), p
        );
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

    function operativeIdentityRecord(bytes32 artistId) public view returns (bytes32) {
        return StreamArtistIdentityRevisionState.operative(
            _identityRevisions, _identity, _rotations, artistId
        );
    }

    function identityRecordBytes(bytes32 artistId) external view returns (bytes memory) {
        return _identity.documents[operativeIdentityRecord(artistId)];
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        _forwardIdentityRead();
    }

    function operativeIdentityMetadata(bytes32 artistId)
        external
        view
        returns (bytes32, string memory, string memory)
    {
        _forwardIdentityRead();
    }

    function artistDisplayName(bytes32 artistId)
        external
        view
        returns (string memory name, bytes32 hash)
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
        returns (StreamArtistAuthorizationTypes.State memory)
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
        returns (address[] memory, uint32, uint64, bytes32)
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
        return StreamArtistIdentityDismissalState.standingRevoked(
            _resolutions, _rotations, artistId, account
        );
    }

    function guardianSetRecord(bytes32 record) external view returns (R.GuardianRecord memory) {
        _forwardIdentityRead();
    }

    function rotationRecord(bytes32 record) external view returns (R.RotationRecord memory) {
        _forwardIdentityRead();
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        returns (R.StandingRecord memory)
    {
        _forwardIdentityRead();
    }

    function artistTransitionState(bytes32 record)
        external
        view
        returns (R.TransitionState memory)
    {
        _forwardIdentityRead();
    }

    function lastArtistTransition(bytes32 artistId) external view returns (bytes32) {
        return _rotations.latestTransition[artistId];
    }

    function identityRevisionProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        _forwardIdentityRead();
    }

    function activeAuthorityWindow(bytes32 artistId) external view returns (bytes32, uint64, bool) {
        return StreamArtistRotationState.activeWindowWithResolution(
            _rotations, artistId, _currentIdentityClosure(artistId)
        );
    }

    function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return StreamArtistRotationState.acceptanceNonceState(
            _rotations, _replay, _ownerContext(), artistId, account, nonce
        );
    }

    function provisionalAssociation(bytes32 artistId)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return StreamArtistRotationState.associationWithResolution(
            _rotations, artistId, _currentIdentityClosure(artistId)
        );
    }

    function provisionalRecordEligible(bytes32 artistId, R.ProvisionalAssociation calldata a)
        external
        view
        returns (bool)
    {
        return StreamArtistRotationState.eligible(_rotations, artistId, a);
    }

    function artistWindowInfo(bytes32 parameter) external view returns (uint64, uint64, uint64) {
        return StreamArtistWindowConfiguration.info(
            _rotations, _estate, _unavailability, _dormancy, parameter
        );
    }

    function artistWindowScope(bytes32 parameter) external view returns (bytes32) {
        return StreamArtistWindowConfiguration.scope(
            _rotations, _estate, _unavailability, _dormancy, parameter
        );
    }

    function artistWindowStateHash(bytes32 parameter, uint64 value, uint64 revision)
        external
        view
        returns (bytes32)
    {
        return StreamArtistWindowConfiguration.stateHash(
            _rotations, _estate, _unavailability, _dormancy, parameter, value, revision
        );
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
        return _identity.nextRegistrationNonce;
    }

    function activeIdentity(address account) external view returns (bytes32) {
        return _identity.activeIdentity[account];
    }

    function _ownerContext() private view returns (StreamArtistIdentityState.OwnerContext memory) {
        return StreamArtistIdentityState.OwnerContext(
            _environment(), operationCoordinator, archiveV2, domainId, _revision
        );
    }

    function identity(bytes32 artistId) external view returns (T.Identity memory) {
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
        T.Identity storage item = _identity.identities[artistId];
        return (item.authorityAddress, item.authorityClass, item.status, item.identityRecordHash);
    }

    function identityDocumentBytes(bytes32 documentHash) external view returns (bytes memory) {
        _forwardIdentityRead();
    }

    function signatureBundle(bytes32 recordHash) external view returns (bytes memory) {
        _forwardIdentityRead();
    }

    function nonceUsed(bytes32 artistId, uint256 nonce) public view returns (bool) {
        return _replay[_replayKey(
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(artistId, nonce))
            )].status != 0;
    }

    function delegationRecord(bytes32 grant) external view returns (D.Record memory) {
        _forwardIdentityRead();
    }

    /// @notice Automatic estate revocation is separate from the immutable grant and its explicit revoke record.
    function delegationEpochState(bytes32 grant)
        external
        view
        returns (bool valid, uint64 recorded, uint64 current)
    {
        D.Record storage item = _delegations.records[grant];
        recorded = _estate.grantEpoch[grant];
        current = _estate.delegationEpoch[item.grant.artistId];
        valid = item.grantor != address(0) && recorded == current;
    }

    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return StreamArtistCollaboratorIdentityState.nonceState(
            _collaboratorAccounts, _replay, _ownerContext(), account, nonce
        );
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
        bytes32 lane = StreamArtistDelegationState.lane(artistId, delegate);
        return (
            _replay[_replayKey(
                        keccak256("identity_authority.replay.delegated_nonce"),
                        keccak256(abi.encode(lane, nonce))
                    )].status != 0,
            _delegations.hints[lane]
        );
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
                _ownerContext(),
                msg.data
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
        returns (Dorm.Notice memory, uint8, Dorm.Terminal memory)
    {
        _forwardIdentityRead();
    }

    function dormancyInitiationContext(Dorm.Initiation calldata p)
        external
        view
        returns (Dorm.Context memory)
    {
        _forwardIdentityRead();
    }

    function dormancyCompletionContext(Dorm.Completion calldata p)
        external
        view
        returns (Dorm.Context memory, Dorm.Plan memory)
    {
        _forwardIdentityRead();
    }

    function dormancyCompletionEvidence(Dorm.Completion calldata p)
        external
        view
        returns (bytes memory)
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
        return StreamArtistStewardSanctionState.current(_stewardGrants, _rotations, id);
    }

    function stewardSanctionGrantRecord(bytes32 hash)
        external
        view
        returns (SG.GrantRecord memory)
    {
        _forwardIdentityRead();
    }

    function stewardSanctionGrantSignature(bytes32 hash) external view returns (bytes memory) {
        return _identity.signatures[hash];
    }

    function stewardSanctionGrantDigest(SG.Grant calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistStewardSanctionState.digest(_environment(), p, a);
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
        returns (SC.Context memory)
    {
        _forwardIdentityRead();
    }

    function stewardCapabilityGrantRecord(bytes32 hash) external view returns (SC.Record memory) {
        _forwardIdentityRead();
    }

    function stewardCapabilityGrantState(bytes32 appointment)
        external
        view
        returns (bytes32, uint32)
    {
        return (
            _stewardCapabilityGrants.head[appointment], _stewardCapabilityGrants.added[appointment]
        );
    }

    function artistRecordChainHash(bytes32 id) external view returns (bytes32 tip) {
        (tip,) = StreamArtistHistoryState.lane(1, id);
    }

    function collectionRecordChainHash(uint256 id) external view returns (bytes32 tip) {
        (tip,) = StreamArtistHistoryState.lane(2, bytes32(id));
    }

    function artistHistoryLane(uint8 kind, bytes32 id) external view returns (bytes32, uint64) {
        return StreamArtistHistoryState.lane(kind, id);
    }

    function artistHistoryRecordAt(uint8 kind, bytes32 id, uint64 index)
        external
        view
        returns (bytes32, bytes32)
    {
        return StreamArtistHistoryState.at(
            core, artistRegistry, kind, id, index, StreamArtistHistoryProof.cap(artistRegistry)
        );
    }

    function artistHistoryContinuityCommitment() external view returns (bytes32) {
        return StreamArtistHistoryState.commitment();
    }

    function artistHistorySourceCursor(address source) external view returns (uint256) {
        return StreamArtistHistoryState.cursor(source);
    }

    function importedHistoryBindingCount() external view returns (uint256) {
        return StreamArtistHistoryState.bindingCount();
    }

    function importedHistoryBinding(uint256 index)
        external
        view
        returns (address, uint64, bytes32, bytes32)
    {
        H.Binding memory b = StreamArtistHistoryState.binding(index);
        return (b.predecessorRegistry, b.snapshotBlock, b.importRoot, b.manifestHash);
    }

    function artistHistoryPredecessorBinding(address source)
        external
        view
        returns (bool, bytes32, uint256)
    {
        return StreamArtistHistoryState.predecessorBinding(source);
    }

    function verifyImportedRecord(bytes32 root, H.Leaf calldata p, bytes32[] calldata proof)
        external
        view
        returns (bool)
    {
        return StreamArtistHistoryState.verifyRecord(root, p, proof);
    }

    function importedLaneVerified(uint8 kind, bytes32 id)
        external
        view
        returns (bool, bytes32, uint64)
    {
        return StreamArtistHistoryState.verified(kind, id);
    }

    function artistRegistryCutover() external view returns (bool, address, uint64) {
        return StreamArtistHistoryState.cutover();
    }

    function artistHistoryImportContext(
        address predecessor,
        uint64 snapshot,
        bytes32 root,
        bytes32 manifest
    ) external view returns (H.Context memory) {
        return StreamArtistHistoryState.context(
            artistRegistry, H.Binding(predecessor, snapshot, root, manifest)
        );
    }

    function syncArtistNativeHistory(address source, uint256 first, H.Receipt[] calldata rows)
        external
    {
        if (msg.sender != operationCoordinator) revert T.Unauthorized(msg.sender);
        StreamArtistHistoryState.sync(
            core, artistRegistry, source, first, rows, StreamArtistHistoryProof.cap(artistRegistry)
        );
    }

    function applyArtistHistoryImport(
        T.ActionContext calldata c,
        H.Binding calldata p,
        bytes32 actionId
    ) external {
        _check(c, 55);
        if (c.actor != artistWindowAuthority || actionId == 0) revert T.Unauthorized(c.actor);
        H.Context memory x = StreamArtistHistoryState.context(artistRegistry, p);
        bytes memory raw = StreamArtistHistoryProof.fixedRead(
            artistWindowAuthority,
            abi.encodeWithSignature("currentAction()"),
            192,
            StreamArtistHistoryProof.cap(artistRegistry)
        );
        (bool executing, bytes32 id, uint8 cls, bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            abi.decode(raw, (bool, bytes32, uint8, bytes32, bytes32, bytes32));
        if (
            !executing || id != actionId || cls != 1 || scope != x.scopeHash
                || oldHash != x.oldValueHash || newHash != x.newValueHash
                || keccak256(raw)
                    != keccak256(abi.encode(executing, id, cls, scope, oldHash, newHash))
        ) revert T.InvalidRecord();
        bytes32 a = _consume(
            keccak256("identity_authority.replay.governance_action"),
            keccak256(abi.encode(id, scope, oldHash, newHash)),
            p.importRoot
        );
        bytes32 b = _consume(
            keccak256("identity_authority.replay.import_binding_key"),
            keccak256(abi.encode(p)),
            p.importRoot
        );
        StreamArtistHistoryState.commit(
            core, artistRegistry, p, actionId, StreamArtistHistoryProof.cap(artistRegistry)
        );
        _commit(
            c,
            keccak256(abi.encode(p, id)),
            StreamArtistHistoryState.commitment(),
            keccak256(abi.encode(a, b)),
            bytes32(0)
        );
    }

    function applyArtistHistoryLaneVerification(
        T.ActionContext calldata c,
        uint256 index,
        H.Leaf calldata p,
        bytes32[] calldata proof
    ) external {
        _check(c, 56);
        H.Binding memory b = StreamArtistHistoryState.binding(index);
        bytes32 a = _consume(
            keccak256("identity_authority.replay.verified_lane_key"),
            keccak256(abi.encode(p.laneKind, p.laneKey)),
            p.recordChainHash
        );
        bytes32 bound = _consume(
            keccak256("identity_authority.replay.import_binding"),
            keccak256(abi.encode(index, p.laneKind, p.laneKey)),
            b.importRoot
        );
        StreamArtistHistoryState.verifyTip(
            core, artistRegistry, index, p, proof, StreamArtistHistoryProof.cap(artistRegistry)
        );
        _commit(
            c,
            keccak256(abi.encode(index, p, proof)),
            StreamArtistHistoryState.commitment(),
            keccak256(abi.encode(a, bound)),
            bytes32(0)
        );
    }

    function applyArtistRegistryCutover(T.ActionContext calldata c) external {
        _check(c, 57);
        bytes32 a = _consume(
            keccak256("identity_authority.replay.one_way_cutover_latch"),
            bytes32(0),
            keccak256(abi.encode(block.number))
        );
        StreamArtistHistoryState.observe(
            core, artistRegistry, StreamArtistHistoryProof.cap(artistRegistry)
        );
        _commit(
            c,
            keccak256(abi.encode(c.actor, block.number)),
            StreamArtistHistoryState.commitment(),
            a,
            bytes32(0)
        );
    }
}
