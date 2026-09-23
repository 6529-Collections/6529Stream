// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistCoordinatorFinalityReads as FinalityReads
} from "./StreamArtistCoordinatorFinalityReads.sol";
import {
    StreamArtistCoordinatorSanctionConfirmation as SanctionConfirmation
} from "./StreamArtistCoordinatorSanctionConfirmation.sol";
import { StreamArtistCoordinatorSanctionRecord } from "./StreamArtistCoordinatorSanctionRecord.sol";
import { StreamArtistCurrentFinalityRoute } from "./StreamArtistCurrentFinalityRoute.sol";
import {
    IStreamArtistCurrentFinality
} from "../../interfaces/stream/artist/IStreamArtistCurrentFinality.sol";
import {
    StreamArtistCurrentAuthorityTypes as CurrentAuthority
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import "./StreamArtistBindingCorrectionOperations.sol";
import {
    StreamArtistRecoveredHydrationTypes as Recovered
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import "../../interfaces/stream/artist/IStreamArtistMultipleRecordsHydration.sol";

import { StreamArtistRecoveryRewindTransport } from "./StreamArtistRecoveryRewindTransport.sol";
import "../../interfaces/stream/artist/IStreamArtistMultipleAuthorityHydration.sol";
import "./StreamArtistDelegatedConsentOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsent.sol";
import "./StreamArtistDisputeWithdrawalOperations.sol";
import "./StreamArtistCoordinatorDisputeTransport.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import "./StreamArtistRepudiationOperations.sol";

import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "./StreamArtistDisputeOperations.sol";

import "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU,
    IStreamArtistEntropyUnavailability,
    IStreamArtistEntropyUnavailabilityOwner,
    IStreamArtistEntropyUnavailabilityCoordinator
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

import { StreamArtistCoordinatorRecoveryRead } from "./StreamArtistCoordinatorRecoveryRead.sol";
import {
    StreamArtistCoordinatorRecordTransport
} from "./StreamArtistCoordinatorRecordTransport.sol";
import { StreamArtistCoordinatorSanctionRead } from "./StreamArtistCoordinatorSanctionRead.sol";
import { StreamArtistCoordinatorHydration } from "./StreamArtistCoordinatorHydration.sol";
import "./StreamArtistAuthorityHydrationOperations.sol";
import "./StreamArtistHistoryOperations.sol";
import {
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import { StreamArtistPayloadSync } from "./StreamArtistPayloadSync.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import "./StreamArtistStewardCapabilityOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG,
    IStreamArtistStewardSanctionGrantCoordinator
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import "./StreamArtistDormancyOperations.sol";
import "./StreamArtistStewardSanctionOperations.sol";
import "./StreamArtistAttributionClaimOperations.sol";
import "./StreamArtistPlatformOperations.sol";
import {
    IStreamArtistRecoveryActionOwner,
    IStreamArtistRecoveryActionCoordinator
} from "../../interfaces/stream/artist/IStreamArtistRecoveryAction.sol";
import {
    StreamArtistRecoveryActionTypes as RecoveryAction
} from "../../interfaces/stream/artist/StreamArtistRecoveryActionTypes.sol";
import { GovernanceCall } from "../../interfaces/stream/governance/StreamGovernanceTypes.sol";
import "./StreamArtistIdentityDismissalOperations.sol";
import "./StreamArtistIdentityRecoveryOperations.sol";
import { StreamArtistRecoveryActionOperations } from "./StreamArtistRecoveryActionOperations.sol";
import {
    StreamArtistRecoveryAdjudicationOperations
} from "./StreamArtistRecoveryAdjudicationOperations.sol";
import "./StreamArtistUnavailabilityOperations.sol";
import "./StreamArtistEntropyUnavailabilityOperations.sol";
import "./StreamArtistRecoveryApprovalOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistRecoveryApproval.sol";
import "./StreamArtistOnboardingReadDeployment.sol";
import "./StreamArtistFinalityAdmission.sol";
import "./StreamArtistSanctionOperations.sol";
import "./StreamArtistSanctionConfirmationOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";
import "./StreamArtistIdentityOperations.sol";
import "./StreamArtistOnboardingOperations.sol";
import "./StreamArtistRotationOperations.sol";
import "./StreamArtistSaleOperations.sol";
import "./StreamArtistIdentityContestOperations.sol";
import "./StreamArtistSuccessionOperations.sol";
import "./StreamArtistEstateOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistSaleAuthority.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistEconomicOperations.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistCollaboratorOperations.sol";
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistContentOperations.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycleCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationCoordinator.sol";

import "./StreamArtistOnboardingReads.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorOwner.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistTemplateEconomicsCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistTemplateMutationCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../interfaces/stream/artist/IStreamArtistIngressBinding.sol";
import "../../interfaces/stream/governance/IStreamRoleRegistry.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Immutable typed orchestration of the supported artist-authority recipes.
/// @dev No generic route, semantic record or nonce lives here. Only the operation lock mutates.
contract StreamArtistOnboardingCoordinator is
    IStreamArtistOnboardingCoordinator,
    IStreamArtistEconomicsCoordinator,
    IStreamArtistTemplateEconomicsCoordinator,
    IStreamArtistTemplateMutationCoordinator,
    IStreamArtistDelegationCoordinator,
    IStreamArtistBindingLifecycleCoordinator,
    IStreamArtistCollaboratorCoordinator,
    IStreamArtistSaleCoordinator
{
    // Retained for the unchanged error bubbled by the fixed finality reader.
    error InvalidCurrentAuthority();
    /// @notice A required artist fact is absent; retained for errors propagated by linked recipes.
    error MissingMintPrerequisite(bytes32 prerequisite);
    /// @notice Retained for errors propagated by the linked identity recipes.
    error InvalidIdentity(bytes32 artistId);
    // Preserve the public ABI of errors now propagated by extracted typed recipes.
    error InvalidRecord();
    error InvalidSignature();
    error InvalidAttribution(uint256 collectionId);
    T.SuiteConfiguration private _suite;
    address[16] private _targets;
    bytes32[16] private _runtimeHashes;
    uint256 private _entered;
    uint256 public immutable deploymentChainId;
    bytes32 public immutable configurationHash;
    StreamArtistOnboardingReads public immutable reads;
    address public immutable finalityRegistry;
    bytes32 public immutable finalityRegistryCodeHash;
    address public immutable finalityEvidenceProvider;
    bytes32 public immutable finalityEvidenceProviderCodeHash;

    constructor(T.SuiteConfiguration memory suite, address finalityRegistry_) {
        deploymentChainId = block.chainid;
        if (suite.registry == address(0) || suite.primaryRevenueClass == bytes32(0)) {
            revert T.InvalidBinding();
        }
        _suite = suite;
        for (uint256 i; i < 7; ++i) {
            _targets[i] = suite.owners[i];
        }
        _targets[7] = suite.registry;
        _targets[8] = suite.archive;
        _targets[9] = suite.core;
        _targets[10] = suite.mintManager;
        _targets[11] = suite.roleRegistry;
        _targets[12] = suite.metadata;
        _targets[13] = suite.primaryResolver;
        _targets[14] = suite.royaltyResolver;
        _targets[15] = suite.validator;
        for (uint256 i; i < 16; ++i) {
            address target = _targets[i];
            if (target.code.length == 0 || target == address(this)) revert T.InvalidBinding();
            for (uint256 j; j < i; ++j) {
                if (_targets[j] == target) revert T.InvalidBinding();
            }
            _runtimeHashes[i] = target.codehash;
        }
        if (
            IStreamArtistMintConsent(suite.registry).core() != suite.core
                || IStreamArtistMintConsent(suite.registry).mintManager() != suite.mintManager
                || IStreamArtistIngressBinding(suite.registry).operationCoordinator()
                    != address(this)
                || IStreamArtistArchiveV2(suite.archive).artistRegistry() != suite.registry
                || IStreamArtistArchiveV2(suite.archive).operationCoordinator() != address(this)
        ) revert T.InvalidBinding();
        bytes32[7] memory domains = [
            keccak256("domain:binding_lifecycle"),
            keccak256("domain:collaborator_lifecycle"),
            keccak256("domain:identity_authority"),
            keccak256("domain:acceptance_lifecycle"),
            keccak256("domain:attribution_lifecycle"),
            keccak256("domain:payout_lifecycle"),
            keccak256("domain:consent_finality")
        ];
        for (uint256 i; i < 7; ++i) {
            IStreamArtistOwner owner = IStreamArtistOwner(suite.owners[i]);
            if (
                owner.artistRegistry() != suite.registry
                    || owner.operationCoordinator() != address(this)
                    || owner.archiveV2() != suite.archive || owner.core() != suite.core
                    || owner.mintManager() != suite.mintManager
                    || owner.deploymentChainId() != block.chainid || owner.domainId() != domains[i]
            ) revert T.InvalidBinding();
        }
        if (
            IStreamArtistCollaboratorOwner(suite.owners[1]).collaboratorSetHash()
                != StreamArtistHashes.emptyCollaborators()
        ) revert T.InvalidBinding();
        (address provider, bytes32 providerCodeHash) =
            StreamArtistFinalityAdmission.admit(suite, finalityRegistry_);
        finalityEvidenceProvider = provider;
        finalityEvidenceProviderCodeHash = providerCodeHash;
        finalityRegistry = finalityRegistry_;
        finalityRegistryCodeHash = finalityRegistry_.codehash;
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                suite,
                _runtimeHashes,
                finalityRegistry_,
                finalityRegistry_.codehash,
                provider,
                providerCodeHash,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(12),
                uint16(13),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
                uint16(22),
                uint16(23),
                uint16(24),
                uint16(25),
                uint16(26),
                uint16(27),
                uint16(28),
                uint16(29),
                uint16(30),
                uint16(31),
                uint16(32),
                uint16(33),
                uint16(34),
                uint16(35),
                uint16(36),
                uint16(37),
                uint16(38),
                uint16(39),
                uint16(40),
                uint16(51),
                uint16(52),
                uint16(54),
                uint16(58),
                uint16(65534),
                keccak256("6529STREAM_ARTIST_RECOVERY_PREPARATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_GUARDIAN_HISTORY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_FIRST_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_RECOVERY_HISTORICAL_ROTATION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_VESTING_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_SUPERSESSION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_HEAD_SELECTION_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_GUARDIAN_ROOT_APPEAL_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_FIRST_ESTATE_RECOVERY_PROFILE_V1"),
                keccak256("6529STREAM_ARTIST_ESTATE_SUCCESSOR_GUARDIAN_RECOVERY_PROFILE_V1")
            )
        );
        reads = StreamArtistOnboardingReadDeployment.deployReader(suite);
    }

    modifier operation() {
        _beginOperation();
        _;
        _endOperation();
    }

    function _endOperation() private {
        if (_entered != 1) revert T.InvalidRecord();
        StreamArtistHistoryOperations.sync(_suite);
        StreamArtistPayloadSync.sync(_suite);
        _entered = 0;
    }

    function _beginOperation() private {
        if (msg.sender != _suite.registry) revert T.Unauthorized(msg.sender);
        if (_entered != 0) revert T.ReentrantOperation();
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        for (uint256 i; i < 16;) {
            if (_targets[i].codehash != _runtimeHashes[i]) revert T.ComponentChanged(_targets[i]);
            // The constructor-fixed sixteen pins bound this loop.
            unchecked {
                ++i;
            }
        }
        if (
            msg.sig != this.coordinateCommitArtistHistoryImportRoot.selector
                && msg.sig != this.coordinateVerifyImportedLaneTip.selector
                && msg.sig != this.coordinateObserveRegistryCutover.selector
        ) StreamArtistHistoryOperations.requireCurrent(_suite);
        _entered = 1;
    }

    function coordinateDeclarePlatformWorks(address actor, uint256 id, bytes32 statement)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistPlatformOperations.declare(_economicContext(), actor, id, statement);
    }

    function coordinateFileAttributionClaim(
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string calldata uri
    ) external operation returns (bytes32) {
        return StreamArtistAttributionClaimOperations.file(
            _economicContext(), actor, id, evidence, reason, uri
        );
    }

    function coordinateFilePlatformWorksClaim(
        address actor,
        uint256 id,
        bytes32 evidence,
        bytes32 reason,
        string calldata uri
    ) external operation returns (bytes32) {
        return StreamArtistPlatformOperations.claim(
            _economicContext(), actor, id, evidence, reason, uri
        );
    }

    function coordinateSetPlatformWorksContest(
        address actor,
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason
    ) external operation returns (bytes32) {
        return StreamArtistPlatformOperations.resolve(
            _economicContext(), actor, id, state, claim_, evidence, reason, false
        );
    }

    function coordinateApprovePlatformWorksCorrection(
        address actor,
        uint256 id,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason
    ) external operation returns (bytes32) {
        return StreamArtistPlatformOperations.resolve(
            _economicContext(), actor, id, 3, claim_, evidence, reason, true
        );
    }

    function platformWorksContext(
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) external view returns (PW.Context calldata) {
        bytes memory encoded = StreamArtistPlatformOperations.contextEncoded(
            _economicContext(), msg.data[4:]
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration calldata) {
        bytes memory encoded = StreamArtistCoordinatorRecoveryRead.suiteEncoded(_suite);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function coordinateRecordArtistSanction(
        address actor,
        Q.Request calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorSanctionRecord.record(
            _suite,
            address(reads),
            configurationHash,
            _sanctionPins(p.terms.collectionId),
            actor,
            p,
            a
        );
    }

    function coordinateRecordRecoveryApproval(
        address actor,
        Approval.Request calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        _unavailabilityPins();
        return StreamArtistRecoveryApprovalOperations.record(
            _economicContext(), _recoveryApprovalPins(), actor, p, a
        );
    }

    function verifyRecoveryApproval(
        uint256 collectionId,
        bytes32 originalHash,
        bytes32 manifestHash
    ) external view returns (bool, bytes32, address, uint8) {
        _unavailabilityPins();
        return StreamArtistRecoveryApprovalReads.verify(
            _suite, _recoveryApprovalPins(), collectionId, originalHash, manifestHash
        );
    }

    function _finalityReadGas() private view returns (uint256 cap) {
        return FinalityReads.finalityReadGas(_suite);
    }

    function _recoveryApprovalPins()
        private
        view
        returns (StreamArtistRecoveryOriginalReads.Pins memory)
    {
        uint256 cap = _finalityReadGas();
        return StreamArtistRecoveryOriginalReads.Pins(
            finalityRegistry, finalityRegistryCodeHash, _runtimeHashes[9], _runtimeHashes[7], cap
        );
    }

    function coordinateRecordEntropyUnavailabilityFinding(
        address actor,
        Recovery.FindingRequest calldata request,
        EU.Target calldata target
    ) external operation returns (bytes32) {
        _unavailabilityPins();
        return
            StreamArtistEntropyUnavailabilityOperations.recordEncoded(_economicContext(), msg.data);
    }

    function prepareEntropyUnavailabilityFinding(
        Recovery.FindingRequest calldata request,
        EU.Target calldata target
    ) external view returns (U.Context calldata) {
        _unavailabilityPins();
        bytes memory encoded =
            StreamArtistEntropyUnavailabilityOperations.prepareEncoded(_suite, msg.data);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function verifyEntropyRecoveryUnavailability(
        address coordinator,
        IStreamEntropyFreshRecovery.RecoveryInput calldata input,
        bytes32 intentHash,
        bytes32 expectedFinding
    ) external view returns (bool, bytes32, bytes32, uint64) {
        _unavailabilityPins();
        bytes memory encoded =
            StreamArtistEntropyUnavailabilityOperations.verifyEncoded(_suite, msg.data);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function coordinateRecordUnavailabilityFinding(
        address actor,
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external operation returns (bytes32) {
        _unavailabilityPins();
        return StreamArtistCoordinatorRecordTransport.unavailability(
            _economicContext(), finalityRegistry, msg.data
        );
    }

    function prepareUnavailabilityFinding(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external view returns (U.Context calldata) {
        _unavailabilityPins();
        bytes memory encoded =
            StreamArtistCoordinatorRecoveryRead.prepareEncoded(_suite, finalityRegistry, msg.data);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function verifyRecoveryUnavailability(U.Target calldata target)
        external
        view
        returns (bool, bytes32, bytes32, uint64)
    {
        _unavailabilityPins();
        return StreamArtistRecoveryAdmission.verify(_suite, finalityRegistry, target);
    }

    function _unavailabilityPins() private view {
        for (uint256 i; i < 16;) {
            if (_targets[i].codehash != _runtimeHashes[i]) revert T.ComponentChanged(_targets[i]);
            // The constructor-fixed sixteen pins bound this loop.
            unchecked {
                ++i;
            }
        }
        if (
            _suite.core.codehash != _runtimeHashes[9]
                || _suite.registry.codehash != _runtimeHashes[7]
                || finalityRegistry.code.length == 0
                || finalityRegistry.codehash != finalityRegistryCodeHash
                || block.chainid != deploymentChainId
        ) revert T.InvalidBinding();
    }

    function coordinateConfirmSanctionFinalized(address actor, uint256 collectionId)
        external
        operation
    {
        SanctionConfirmation.confirm(
            _suite,
            _runtimeHashes,
            address(reads),
            configurationHash,
            deploymentChainId,
            finalityRegistry,
            finalityRegistryCodeHash,
            actor,
            collectionId
        );
    }

    function prepareArtistSanction(Q.Request calldata p)
        external
        view
        returns (Q.Prepared calldata)
    {
        if (
            _suite.core.codehash != _runtimeHashes[9]
                || _suite.registry.codehash != _runtimeHashes[7]
                || block.chainid != deploymentChainId
        ) revert T.InvalidBinding();
        bytes memory encoded = StreamArtistCoordinatorSanctionRead.prepareEncoded(
            StreamArtistHashes.Environment(
                block.chainid, _suite.registry, _suite.core, _suite.mintManager
            ),
            _sanctionPins(p.terms.collectionId),
            msg.data
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamArtistCurrentFinality).interfaceId;
    }

    function currentFinalityRoute(uint256 collectionId)
        external
        view
        returns (CurrentAuthority.Route calldata route)
    {
        bytes memory encoded =
            FinalityReads.currentFinalityRouteEncoded(_suite, deploymentChainId, collectionId);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function _sanctionPins(uint256 collectionId)
        private
        view
        returns (StreamArtistSanctionCandidate.Pins memory)
    {
        return FinalityReads.sanctionPins(
            _suite,
            deploymentChainId,
            collectionId,
            finalityRegistry,
            finalityRegistryCodeHash,
            finalityEvidenceProvider,
            finalityEvidenceProviderCodeHash
        );
    }

    function coordinateRecordSaleConsent(
        address actor,
        Sale.Consent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistSaleOperations.record(_economicContext(), actor, p, a);
    }

    function coordinateRegisterIdentityRecoveryActionV3(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external operation returns (bytes32) {
        return StreamArtistRecoveryRewindTransport.execute(_economicContext(), msg.data);
    }

    function coordinateRecoverArtistIdentityV3(
        address actor,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external operation returns (bytes32) {
        return StreamArtistRecoveryRewindTransport.execute(_economicContext(), msg.data);
    }

    function coordinateRegisterIdentityRecoveryActionV2(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external operation returns (bytes32) {
        return StreamArtistRecoveryAdjudicationOperations.prepare(_economicContext(), msg.data);
    }

    function coordinateRecoverArtistIdentityV2(
        address actor,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a,
        bytes32 manifestHash
    ) external operation returns (bytes32) {
        return StreamArtistRecoveryAdjudicationOperations.recoverEncoded(
            _economicContext(), msg.data
        );
    }

    function coordinateRegisterIdentityRecoveryAction(
        address actor,
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.prepareRecovery(_economicContext(), msg.data);
    }

    function coordinateVetoIdentityRecovery(address actor, bytes32 artistId, bytes32 reasonHash)
        external
        operation
    {
        StreamArtistRecoveryActionOperations.veto(_economicContext(), actor, artistId, reasonHash);
    }

    function coordinateRecoverArtistIdentity(
        address actor,
        IdentityRecovery.Request calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistIdentityRecoveryOperations.recover(_economicContext(), actor, p, a);
    }

    function coordinateDismissArtistIdentityContest(address actor, Dismissal.Request calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistIdentityDismissalOperations.dismiss(_economicContext(), actor, p);
    }

    function coordinateRequestEstateActivation(
        address actor,
        Estate.Request calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEstateOperations.request(_economicContext(), actor, p, a);
    }

    function coordinateCancelEstateActivation(address actor, bytes32 artistId, bytes32 expected)
        external
        operation
    {
        StreamArtistEstateOperations.cancel(_economicContext(), actor, artistId, expected);
    }

    function coordinateExecuteEstateActivation(address actor, Estate.Execution calldata p)
        external
        operation
    {
        StreamArtistEstateOperations.execute(_economicContext(), actor, p);
    }

    function coordinateContestArtistIdentity(address actor, Contest.Request calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistIdentityContestOperations.file(_economicContext(), actor, p);
    }

    function coordinateSetArtistGuardians(
        address actor,
        R.GuardianSet calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.guardians(_economicContext(), msg.data);
    }

    function coordinateRotateArtistAddress(
        address actor,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.stageRotation(_economicContext(), msg.data);
    }

    function coordinateApproveArtistRotation(address actor, bytes32 artistId, bytes32 expected)
        external
        operation
    {
        StreamArtistRotationOperations.approve(_economicContext(), actor, artistId, expected);
    }

    function coordinateVetoArtistRotation(
        address actor,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) external operation {
        StreamArtistRotationOperations.veto(
            _economicContext(), actor, artistId, expected, reasonHash
        );
    }

    function coordinateExecuteArtistRotation(address actor, bytes32 artistId, bytes32 expected)
        external
        operation
    {
        StreamArtistRotationOperations.execute(_economicContext(), actor, artistId, expected);
    }

    function coordinateRevokePriorAddressStanding(
        address actor,
        R.StandingRevocation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistRotationOperations.revokeStanding(_economicContext(), actor, p, a);
    }

    function coordinateSetArtistWindow(
        address actor,
        bytes32 parameter,
        uint64 newValue,
        uint64 expectedRevision
    ) external operation {
        IStreamArtistWindowOwner(_suite.owners[2])
            .configureArtistWindow(actor, parameter, newValue, expectedRevision);
    }

    function coordinateProposeArtistBindingAfterRevocation(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName,
        bytes32 repudiationRecord
    ) external operation returns (bytes32, bytes32) {
        return StreamArtistBindingCorrectionOperations.proposeStored(
            _suite, address(reads), configurationHash, msg.data
        );
    }

    function coordinateProposeArtistBinding(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32 artistId, bytes32 bindingHash) {
        return StreamArtistCoordinatorRecordTransport.propose(_economicContext(), msg.data);
    }

    function coordinateAcceptArtistBinding(
        address actor,
        uint256 collectionId,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistBindingOperations.accept(
            _economicContext(), actor, collectionId, a, 0, bytes32(0), false
        );
    }

    function coordinateAcceptArtistBindingExpected(
        address actor,
        uint256 collectionId,
        uint64 generation,
        bytes32 bindingHash,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistBindingOperations.accept(
            _economicContext(), actor, collectionId, a, generation, bindingHash, true
        );
    }

    function coordinateRefuseArtistBinding(
        address actor,
        L.Termination calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistBindingOperations.refuse(_economicContext(), actor, p, a);
    }

    function coordinateWithdrawArtistBinding(address actor, L.Termination calldata p)
        external
        operation
    {
        StreamArtistBindingOperations.withdraw(_economicContext(), actor, p);
    }

    function coordinateProposeCollaboratorIdentity(address actor, C.IdentityProposal calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistCollaboratorOperations.proposeIdentity(_economicContext(), actor, p);
    }

    function coordinateAcceptCollaboratorIdentity(
        address actor,
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.acceptCollaboratorIdentity(
                _economicContext(), msg.data
            );
    }

    function coordinateAcceptCollaborator(
        address actor,
        C.BindingAcceptance calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCollaboratorOperations.acceptRow(_economicContext(), actor, p, a);
    }

    function coordinateRevokeArtistAuthorization(
        address actor,
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistEconomicOperations.revokeAuthorization(_economicContext(), actor, p, a);
    }

    function coordinateRecordPolicyConsent(
        address actor,
        T.PolicyConsent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistOnboardingOperations.policy(_economicContext(), actor, p, a);
    }

    function coordinateRecordEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsCurrent(
            _economicContext(), actor, p, bytes32(0), a
        );
    }

    function coordinateRecordProspectiveTemplateFreezeConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsProspectiveTemplateFreeze(
                _economicContext(), actor, p, a
            );
    }

    function coordinateRecordProspectiveTemplateEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        bytes32 templateId,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsProspectiveTemplate(
            _economicContext(), actor, p, templateId, a
        );
    }

    function coordinateRecordProspectiveEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.economicsProspective(
            _economicContext(), actor, p, candidate, bytes32(0), a
        );
    }

    function coordinateAuthorizeArtistRoyaltyFreeze(
        address actor,
        T.RoyaltyFreeze calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.freeze(_economicContext(), actor, p, bytes32(0), a);
    }

    function coordinateGrantArtistDelegation(
        address actor,
        D.Grant calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.grant(_economicContext(), actor, p, a);
    }

    function coordinateRevokeArtistDelegation(
        address actor,
        D.Revocation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistEconomicOperations.revoke(_economicContext(), actor, p, a);
    }

    function coordinateRecordDelegatedPolicyConsent(
        address actor,
        T.PolicyConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistDelegatedConsentOperations.policy(_economicContext(), actor, p, grant, a);
    }

    function coordinateRecordDelegatedSaleConsent(
        address actor,
        Sale.Consent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistDelegatedConsentOperations.sale(_economicContext(), actor, p, grant, a);
    }

    function coordinateRecordDelegatedEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return
            StreamArtistEconomicOperations.economicsCurrent(_economicContext(), actor, p, grant, a);
    }

    function coordinateRecordDelegatedProspectiveEconomicsConsent(
        address actor,
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return StreamArtistEconomicOperations.economicsProspective(
            _economicContext(), actor, p, candidate, grant, a
        );
    }

    function coordinateAuthorizeDelegatedRoyaltyFreeze(
        address actor,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        if (grant == bytes32(0)) revert D.InvalidDelegation(grant);
        return StreamArtistEconomicOperations.freeze(_economicContext(), actor, p, grant, a);
    }

    function _economicContext() private view returns (D.CoordinatorContext memory) {
        return D.CoordinatorContext(_suite, address(reads), configurationHash);
    }

    function coordinateRecordPayoutDesignation(
        address actor,
        T.PayoutDesignation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistOnboardingOperations.payout(_economicContext(), actor, p, a);
    }

    function coordinateSubjectAttestation(
        address actor,
        T.Attestation calldata p,
        Attest.Subject calldata subject,
        bool scoped,
        bytes32 grant,
        T.Authorization calldata a,
        bytes calldata statement
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.attest(_economicContext(), msg.data);
    }

    function coordinateRecordArtistAttestation(
        address actor,
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external operation returns (bytes32 record) {
        return StreamArtistCoordinatorRecordTransport.attestArtist(_economicContext(), msg.data);
    }

    function coordinateRecordIdentityRevision(
        address actor,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.revise(_economicContext(), msg.data);
    }

    function coordinateRecordSuccessorDesignation(
        address actor,
        Succ.Designation calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistSuccessionOperations.designate(_economicContext(), actor, p, a);
    }

    function coordinateRecordEstateDirective(
        address actor,
        Succ.Directive calldata p,
        T.Authorization calldata a,
        Succ.PublicDocument calldata document
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorRecordTransport.directive(_economicContext(), msg.data);
    }

    function coordinateRecordContentConsent(
        address actor,
        Content.Consent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistContentOperations.consent(_economicContext(), actor, p, a);
    }

    function coordinateAuthorizeArtistContentFreeze(
        address actor,
        Content.Freeze calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistContentOperations.freeze(_economicContext(), actor, p, a);
    }

    function coordinateRecordContentRatification(
        address actor,
        T.Ratification calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32 record) {
        return StreamArtistOnboardingOperations.ratify(_economicContext(), actor, p, a);
    }

    function coordinateInitiateArtistDormancy(address actor, Dorm.Initiation calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistDormancyOperations.initiate(_economicContext(), actor, p);
    }

    function coordinateCancelArtistDormancy(
        address actor,
        bytes32 id,
        bytes32 expected,
        bytes32 grant
    ) external operation {
        StreamArtistDormancyOperations.cancel(_economicContext(), actor, id, expected, grant);
    }

    function coordinateCompleteArtistDormancy(address actor, Dorm.Completion calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistDormancyOperations.complete(_economicContext(), actor, p);
    }

    function coordinateRecordStewardSanctionGrant(
        address actor,
        SG.Grant calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistStewardSanctionOperations.record(_economicContext(), actor, p, a);
    }

    function coordinateGrantStewardCapabilities(address actor, SC.Grant calldata p)
        external
        operation
        returns (bytes32)
    {
        return StreamArtistStewardCapabilityOperations.grant(_economicContext(), actor, p);
    }

    function coordinateCommitArtistHistoryImportRoot(address actor, H.Binding calldata p)
        external
        operation
    {
        StreamArtistHistoryOperations.commit(_economicContext(), actor, p);
    }

    function coordinateVerifyImportedLaneTip(
        address actor,
        uint256 index,
        H.Leaf calldata p,
        bytes32[] calldata proof
    ) external operation {
        StreamArtistHistoryOperations.verify(_economicContext(), actor, index, p, proof);
    }

    function coordinateObserveRegistryCutover(address actor) external operation {
        StreamArtistHistoryOperations.observe(_economicContext(), actor);
    }

    function coordinateHydrateRecoveredArtistAuthority(address actor, Recovered.Request calldata p)
        external
        returns (bytes32)
    {
        return _coordinateHydration();
    }

    function coordinateHydrateRecoveredArtistAuthorityWithConsents(
        address actor,
        Recovered.Request calldata p,
        T.RoyaltyFreeze[] calldata royaltyFreezes
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateMultipleArtistAuthorityWithRecords(
        address actor,
        StreamArtistMultipleRecordsTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateMultipleArtistAuthority(
        address actor,
        StreamArtistMultipleHydrationTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateArtistAuthorityWithDelegations(address actor, AH.Request calldata p)
        external
        returns (bytes32)
    {
        return _coordinateHydration();
    }

    function _coordinateHydration() private operation returns (bytes32) {
        return StreamArtistCoordinatorHydration.executeSelected(_economicContext(), msg.data);
    }

    function coordinateHydrateArtistAuthority(address actor, AH.Request calldata p)
        external
        returns (bytes32)
    {
        return _coordinateHydration();
    }

    function authorityHydrationSuite() external view returns (T.SuiteConfiguration calldata) {
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        for (uint256 j; j < 16;) {
            if (_targets[j].codehash != _runtimeHashes[j]) revert T.ComponentChanged(_targets[j]);
            // The constructor-fixed sixteen pins bound this read-only loop.
            unchecked {
                ++j;
            }
        }
        bytes memory encoded = StreamArtistCoordinatorRecoveryRead.suiteEncoded(_suite);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function coordinateHydrateArtistAuthorityWithPayout(address actor, AH.Request calldata p)
        external
        returns (bytes32)
    {
        return _coordinateHydration();
    }

    function coordinateHydrateArtistAuthorityWithEconomics(
        address actor,
        StreamArtistEconomicsHydrationTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateArtistAuthorityWithReadiness(
        address actor,
        StreamArtistReadinessHydrationTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateArtistAuthorityWithPublications(
        address actor,
        StreamArtistReadinessHydrationTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateHydrateArtistAuthorityWithEntropyFindings(
        address actor,
        StreamArtistEntropyFindingHydrationTypes.Request calldata p
    ) external returns (bytes32) {
        return _coordinateHydration();
    }

    function coordinateWithdrawAttributionDispute(
        address actor,
        AD.Filing calldata p,
        AD.Standing calldata standing,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistDisputeWithdrawalOperations.applyEncoded(_economicContext(), msg.data);
    }

    function coordinateOpenAttributionDispute(
        address actor,
        AD.Filing calldata p,
        AD.Standing calldata standing,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorDisputeTransport.applyEncoded(
            _economicContext(), msg.data, 44
        );
    }

    function coordinateRecordCounterStatement(
        address actor,
        AD.Filing calldata p,
        AD.Standing calldata standing,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorDisputeTransport.applyEncoded(
            _economicContext(), msg.data, 45
        );
    }

    function coordinateResolveAttributionDispute(address actor, AD.ResolutionRequest calldata p)
        external
        operation
        returns (bytes32)
    {
        return
            StreamArtistCoordinatorDisputeTransport.applyEncoded(_economicContext(), msg.data, 46);
    }

    function coordinateRevokeAttribution(
        address actor,
        AD.Filing calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistCoordinatorDisputeTransport.applyEncoded(
            _economicContext(), msg.data, 47
        );
    }

    function coordinateVetoAttributionRepudiation(
        address actor,
        uint256 id,
        bytes32 expected,
        bytes32 reason
    ) external operation {
        StreamArtistCoordinatorDisputeTransport.applyEncoded(_economicContext(), msg.data, 48);
    }

    function coordinateCancelAttributionRepudiation(address actor, uint256 id, bytes32 expected)
        external
        operation
    {
        StreamArtistCoordinatorDisputeTransport.applyEncoded(_economicContext(), msg.data, 49);
    }

    function coordinateExecuteAttributionRepudiation(address actor, uint256 id, bytes32 expected)
        external
        operation
    {
        StreamArtistCoordinatorDisputeTransport.applyEncoded(_economicContext(), msg.data, 50);
    }
}
