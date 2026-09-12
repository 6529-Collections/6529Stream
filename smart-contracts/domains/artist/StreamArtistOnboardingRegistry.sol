// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistFinalityBinding.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistRegistryWriterExtension.sol";
import "./StreamArtistRegistryReadExtension.sol";
import "./StreamArtistRegistryFinalityReadExtension.sol";
import "./StreamArtistRegistryExtensionDeployment.sol";
import "./StreamArtistFinalityReadDeployment.sol";
import "./StreamArtistEstateCoverage.sol";
import "../../interfaces/stream/artist/IStreamArtistCommercialAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublication.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionState.sol";
import {
    IStreamArtistContentAuthority
} from "../../interfaces/stream/artist/IStreamArtistContentAuthority.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegation.sol";
import "../../interfaces/stream/artist/IStreamArtistBindingLifecycle.sol";
import "../../interfaces/stream/artist/IStreamArtistBeneficiaryFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCollaboratorLifecycle.sol";

import "./StreamArtistOnboardingCoordinator.sol";
import "../../interfaces/stream/artist/IStreamArtistOnboarding.sol";
import "../../interfaces/stream/artist/IStreamArtistContentRatification.sol";
import "../../interfaces/stream/artist/IStreamArtistEconomicsAuthority.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";

/// @notice Immutable artist ingress and composed reads for the supported first-sale profile.
/// @dev The facade is the EIP712 registry identity. Semantic state stays in its separate owners.
///      This subset does not advertise the full artist lifecycle or legacy nomination API.
contract StreamArtistOnboardingRegistry is
    IStreamArtistOnboarding,
    IStreamArtistMintConsent,
    IStreamArtistAttribution,
    IStreamArtistContentRatification,
    IStreamArtistEconomicsAuthority,
    IStreamArtistDelegation,
    IStreamArtistBindingLifecycle,
    IStreamArtistBeneficiaryFacts,
    IStreamArtistCollaboratorLifecycle,
    IStreamArtistAuthorizationRevocation,
    IStreamArtistContentAuthority,
    IStreamArtistIdentityRevision,
    IStreamArtistRotation,
    IStreamArtistWindows,
    IStreamArtistSaleAuthority,
    IStreamArtistAttributionState,
    IStreamArtistIdentityContest,
    IStreamArtistSuccessionRecords,
    IStreamArtistIdentityDismissal,
    IStreamArtistEstateActivation,
    IStreamArtistEstateBinding,
    IStreamArtistCommercialAuthority,
    IStreamArtistRecordPublication,
    IStreamArtistFinalityBinding,
    IStreamArtistSanction,
    IStreamArtistSanctionConfirmation,
    IStreamArtistUnavailability,
    IStreamArtworkFinalityComponent,
    IStreamArtworkScopedFinalityComponent,
    StreamModuleBase,
    StreamGasParameterHost
{
    address public immutable override(IStreamArtistMintConsent, IStreamArtistAttribution) core;
    address public immutable override mintManager;
    address public immutable operationCoordinator;
    address public immutable registryWriterExtension;
    address public immutable registryReadExtension;
    address public immutable registryFinalityReadExtension;
    address public immutable override archivalCoverage;
    bytes32 public immutable override archivalCoverageCodeHash;
    bytes32 public immutable override archivalCoverageConfigurationHash;

    function recordUnavailabilityFinding(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function unavailabilityFindingRecord(bytes32 hash)
        external
        view
        returns (Recovery.FindingRecord memory, U.Admission memory)
    {
        _forwardFinalityRead();
    }

    function unavailabilityFindingContext(
        Recovery.FindingRequest calldata p,
        U.Target calldata target
    ) external view returns (U.Context memory) {
        _forwardFinalityRead();
    }

    function verifyRecoveryUnavailability(U.Target calldata target)
        external
        view
        returns (bool, bytes32, bytes32, uint64)
    {
        _forwardFinalityRead();
    }

    function recordArtistSanction(Q.Request calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function confirmSanctionFinalized(uint256 collectionId) external {
        _forwardRegistryWriter();
    }

    function prepareArtistSanction(Q.Request calldata p) external view returns (Q.Prepared memory) {
        _forwardFinalityRead();
    }

    function sanctionDigest(S.Terms calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardFinalityRead();
    }

    function sanctionRecord(bytes32 recordHash) external view returns (S.Record memory) {
        _forwardFinalityRead();
    }

    function sanctionArchiveBytes(bytes32 recordHash) external view returns (bytes memory) {
        _forwardFinalityRead();
    }

    function sanctionArchiveFacts(bytes32 recordHash)
        external
        view
        returns (IStreamArtistSanctionArchiveFacts.Facts memory)
    {
        _forwardFinalityRead();
    }

    function collectionSanctionComponentType(uint256 collectionId) external view returns (bytes32) {
        _forwardFinalityRead();
    }

    function verifySanctionForSubject(
        uint8 scopeType,
        uint256 collectionId,
        uint256 tokenId,
        bytes32 scopeId,
        bytes32 subject
    ) external view returns (bool, bytes32, address, uint8) {
        _forwardFinalityRead();
    }

    function finalityState(uint256 collectionId)
        external
        view
        returns (StreamFinalityComponentState memory)
    {
        _forwardFinalityRead();
    }

    function finalityStateForScope(StreamFinalityScope calldata scope)
        external
        view
        returns (StreamFinalityComponentState memory)
    {
        _forwardFinalityRead();
    }

    function finalityRegistry() external view returns (address) {
        _forwardFinalityRead();
    }

    function finalityRegistryCodeHash() external view returns (bytes32) {
        _forwardFinalityRead();
    }

    constructor(
        address core_,
        address manager_,
        address coordinator_,
        address governance_,
        address archivalCoverage_,
        bytes32 deploymentHash,
        string memory manifestURI,
        bytes32 manifestHash
    )
        StreamModuleBase(
            keccak256("6529stream.artist-onboarding.v1"),
            address(0),
            deploymentHash,
            manifestURI,
            manifestHash
        )
        StreamGasParameterHost(governance_)
    {
        if (
            core_.code.length == 0 || manager_.code.length == 0 || coordinator_ == address(0)
                || coordinator_ == address(this) || core_ == manager_
        ) revert T.InvalidBinding();
        core = core_;
        mintManager = manager_;
        operationCoordinator = coordinator_;
        archivalCoverageConfigurationHash =
            StreamArtistEstateCoverage.admit(core_, manager_, governance_, archivalCoverage_);
        archivalCoverage = archivalCoverage_;
        archivalCoverageCodeHash = archivalCoverage_.codehash;
        registryWriterExtension =
            address(new StreamArtistRegistryWriterExtension(address(this), coordinator_));
        registryReadExtension = StreamArtistRegistryExtensionDeployment.deployReader(coordinator_);
        registryFinalityReadExtension =
            StreamArtistFinalityReadDeployment.deployReader(coordinator_);
        _registerGasParameter(GasParameterConfig("ARTIST_ERC1271_VERIFY_GAS", 150_000, 90_000, 2));
        _registerGasParameter(GasParameterConfig("ARTIST_SALE_FACTS_READ_GAS", 150_000, 50_000, 2));
        _registerGasParameter(
            GasParameterConfig("ARTIST_RECORD_PUBLICATION_READ_GAS", 400_000, 150_000, 2)
        );
        _registerGasParameter(
            GasParameterConfig("ARTIST_ARCHIVAL_COVERAGE_READ_GAS", 400_000, 250_000, 2)
        );
        _registerGasParameter(GasParameterConfig("ARTIST_FINALITY_READ_GAS", 2_000_000, 500_000, 2));
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("ARTIST_REGISTRY");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.artist-onboarding.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamArtistMintConsent).interfaceId;
    }

    function supportsInterface(bytes4 id) public view override returns (bool) {
        return id == type(IStreamArtistUnavailability).interfaceId
            || id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistOnboarding).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || id == type(IStreamArtistDelegation).interfaceId
            || id == type(IStreamArtistBindingLifecycle).interfaceId
            || id == type(IStreamArtistBeneficiaryFacts).interfaceId
            || id == type(IStreamArtistCollaboratorLifecycle).interfaceId
            || id == type(IStreamArtistAuthorizationRevocation).interfaceId
            || id == type(IStreamArtistContentAuthority).interfaceId
            || id == type(IStreamArtistIdentityRevision).interfaceId
            || id == type(IStreamArtistIdentityRevisionReads).interfaceId
            || id == type(IStreamArtistRotation).interfaceId
            || id == type(IStreamArtistRotationReads).interfaceId
            || id == type(IStreamArtistSaleAuthority).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId
            || id == type(IStreamArtistIdentityContest).interfaceId
            || id == type(IStreamArtistIdentityDismissal).interfaceId
            || id == type(IStreamArtistEstateActivation).interfaceId
            || id == type(IStreamArtistEstateBinding).interfaceId
            || id == type(IStreamArtistCommercialAuthority).interfaceId
            || id == type(IStreamArtistRecordPublication).interfaceId
            || id == type(IStreamArtistFinalityBinding).interfaceId
            || id == type(IStreamArtistSanction).interfaceId
            || id == type(IStreamArtistSanctionConfirmation).interfaceId
            || id == type(IStreamFinalitySanctionReads).interfaceId
            || id == type(IStreamArtistSanctionArchiveFacts).interfaceId
            || id == type(IStreamArtworkFinalityComponent).interfaceId
            || id == type(IStreamArtworkScopedFinalityComponent).interfaceId
            || id == type(IStreamArtistSuccessionRecords).interfaceId
            || id == type(IStreamArtistSuccessionReads).interfaceId
            || id == type(IStreamArtistWindows).interfaceId || super.supportsInterface(id);
    }

    function recordSaleConsent(Sale.Consent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function requestEstateActivation(Estate.Request calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function cancelEstateActivation(bytes32 artistId, bytes32 expected) external {
        _forwardRegistryWriter();
    }

    function executeEstateActivation(Estate.Execution calldata p) external {
        _forwardRegistryWriter();
    }

    function estateActivationDigest(Estate.Request calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function estateActivationState(bytes32 artistId)
        external
        view
        returns (address, uint64, bytes32)
    {
        _forwardRegistryRead();
    }

    function estateActivationRecord(bytes32 record)
        external
        view
        returns (Estate.RequestRecord memory, uint8, Estate.ExecutionFacts memory)
    {
        _forwardRegistryRead();
    }

    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        returns (uint256)
    {
        _forwardRegistryRead();
    }

    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        returns (Estate.AuthorityCapabilities memory)
    {
        _forwardRegistryRead();
    }

    function estateAccelerationContext(Estate.Execution calldata p)
        external
        view
        returns (Estate.AccelerationContext memory)
    {
        _forwardRegistryRead();
    }

    function collectionArtistAuthority(uint256 collectionId)
        external
        view
        returns (bytes32, uint64, bytes32, address, uint8, uint8, uint32)
    {
        _forwardRegistryRead();
    }

    function recordSuccessorDesignation(Succ.Designation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function recordEstateDirective(
        Succ.Directive calldata p,
        T.Authorization calldata a,
        Succ.PublicDocument calldata document
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function successorDesignation(bytes32 artistId)
        external
        view
        returns (address, uint8, uint32, bytes32, bytes32, uint256)
    {
        _forwardRegistryRead();
    }

    function operativeSuccessorRecord(bytes32 artistId) external view returns (bytes32) {
        _forwardRegistryRead();
    }

    function operativeEstateDirective(bytes32 artistId) external view returns (bytes32) {
        _forwardRegistryRead();
    }

    function successorDesignationRecord(bytes32 record)
        external
        view
        returns (Succ.DesignationRecord memory)
    {
        _forwardRegistryRead();
    }

    function estateDirectiveRecord(bytes32 record)
        external
        view
        returns (Succ.DirectiveRecord memory)
    {
        _forwardRegistryRead();
    }

    function estateDirectivePayload(bytes32 record) external view returns (bytes memory) {
        _forwardRegistryRead();
    }

    function successorDesignationDigest(Succ.Designation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function estateDirectiveDigest(Succ.Directive calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function previewEstateDirectivePayload(
        uint32 granted,
        uint32 forbidden,
        Succ.PublicDocument calldata document
    ) external view returns (bytes memory) {
        _forwardRegistryRead();
    }

    function dismissArtistIdentityContest(Dismissal.Request calldata p) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function identityContestDismissalContext(Dismissal.Request calldata p)
        external
        view
        returns (Dismissal.Context memory)
    {
        _forwardRegistryRead();
    }

    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        returns (Dismissal.Cause memory)
    {
        _forwardRegistryRead();
    }

    function identityContestCause(bytes32 causeHash)
        external
        view
        returns (Dismissal.Cause memory)
    {
        _forwardRegistryRead();
    }

    function identityContestDismissalRecord(bytes32 recordHash)
        external
        view
        returns (Dismissal.Record memory)
    {
        _forwardRegistryRead();
    }

    function latestIdentityContestDismissal(bytes32 artistId) external view returns (bytes32) {
        _forwardRegistryRead();
    }

    function identityTransitionClosure(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        returns (Dismissal.Closure memory)
    {
        _forwardRegistryRead();
    }

    function identityRevisionContinuation(bytes32 continuationHash)
        external
        view
        returns (Dismissal.RevisionContinuation memory)
    {
        _forwardRegistryRead();
    }

    function contestArtistIdentity(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function identityContestRecord(bytes32 record) external view returns (Contest.Record memory) {
        _forwardRegistryRead();
    }

    function latestIdentityContest(bytes32 artistId) external view returns (bytes32) {
        _forwardRegistryRead();
    }

    function identityContestGovernanceContext(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external view returns (bytes32, bytes32, bytes32) {
        _forwardRegistryRead();
    }

    function saleConsentDigest(Sale.Consent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardFinalityRead();
    }

    function saleConsentScope(uint256 collectionId) external view returns (uint8) {
        return StreamArtistSaleOperations.scope(_contentSuite(), collectionId);
    }

    /// @notice Stored evidence only, independent of its current applicability.
    function isSaleConsented(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view
        returns (bool, bytes32)
    {
        return StreamArtistSaleOperations.isConsented(
            _contentSuite(), collectionId, saleId, saleConfigHash
        );
    }

    function requireSaleConsent(uint256 collectionId, bytes32 saleId, bytes32 saleConfigHash)
        external
        view
    {
        StreamArtistSaleOperations.requireConsent(
            _contentSuite(), msg.sender, collectionId, saleId, saleConfigHash
        );
    }

    function saleConsentRecord(bytes32 recordHash) external view returns (Sale.Record memory) {
        return
            IStreamArtistSaleConsentOwner(_contentSuite().owners[6]).saleConsentRecord(recordHash);
    }

    function requireRecordPublication(bytes32 recordHash, P.Publication calldata publication)
        external
        view
        returns (P.Evidence memory)
    {
        _forwardRegistryRead();
    }

    function collectionArtistState(uint256 collectionId)
        external
        view
        returns (
            uint8 attributionState,
            uint64 bindingGeneration,
            bytes32 artistId,
            uint8 authorityStatus,
            bytes32 bindingHash
        )
    {
        return StreamArtistSaleOperations.attributionState(_contentSuite(), collectionId);
    }

    function recordIdentityRevision(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function setArtistGuardians(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function rotateArtistAddress(
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function approveArtistRotation(bytes32 artistId, bytes32 expected) external {
        _forwardRegistryWriter();
    }

    function vetoArtistRotation(bytes32 artistId, bytes32 expected, bytes32 reasonHash) external {
        _forwardRegistryWriter();
    }

    function executeArtistRotation(bytes32 artistId, bytes32 expected) external {
        _forwardRegistryWriter();
    }

    function revokePriorAddressStanding(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function guardianSetDigest(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRotationHashes.guardianDigest(_environment(), p, a);
    }

    function rotationDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRotationHashes.rotationDigest(_environment(), p, a);
    }

    function rotationAcceptanceDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRotationHashes.acceptanceDigest(_environment(), p, a);
    }

    function standingRevocationDigest(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistRotationHashes.standingDigest(_environment(), p, a);
    }

    function _rotationOwner() private view returns (IStreamArtistRotationOwner) {
        return IStreamArtistRotationOwner(_contentSuite().owners[2]);
    }

    function guardianSet(bytes32 artistId)
        external
        view
        returns (address[] memory, uint32, uint64, bytes32)
    {
        return _rotationOwner().guardianSet(artistId);
    }

    function pendingRotation(bytes32 artistId)
        external
        view
        returns (address, address, uint64, uint32, bytes32)
    {
        return _rotationOwner().pendingRotation(artistId);
    }

    function priorAddressStandingRevoked(bytes32 artistId, address account)
        external
        view
        returns (bool, bytes32)
    {
        return _rotationOwner().priorAddressStandingRevoked(artistId, account);
    }

    function guardianSetRecord(bytes32 record) external view returns (R.GuardianRecord memory) {
        _forwardRegistryRead();
    }

    function rotationRecord(bytes32 record) external view returns (R.RotationRecord memory) {
        _forwardRegistryRead();
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        returns (R.StandingRecord memory)
    {
        _forwardRegistryRead();
    }

    function artistTransitionState(bytes32 record)
        external
        view
        returns (R.TransitionState memory)
    {
        return _rotationOwner().artistTransitionState(record);
    }

    function lastArtistTransition(bytes32 artistId) external view returns (bytes32) {
        return _rotationOwner().lastArtistTransition(artistId);
    }

    function identityRevisionProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        return _rotationOwner().identityRevisionProvisionalAssociation(record);
    }

    function payoutDesignationProvisionalAssociation(bytes32 record)
        external
        view
        returns (R.ProvisionalAssociation memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistPayoutTransitionOwner(s.owners[5])
            .payoutDesignationProvisionalAssociation(record);
    }

    function activeAuthorityWindow(bytes32 artistId) external view returns (bytes32, uint64, bool) {
        return _rotationOwner().activeAuthorityWindow(artistId);
    }

    function rotationAcceptanceNonceState(bytes32 artistId, address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        return _rotationOwner().rotationAcceptanceNonceState(artistId, account, nonce);
    }

    function artistWindowInfo(bytes32 parameter) external view returns (uint64, uint64, uint64) {
        return IStreamArtistWindows(address(_rotationOwner())).artistWindowInfo(parameter);
    }

    function artistWindowScope(bytes32 parameter) external view returns (bytes32) {
        return IStreamArtistWindows(address(_rotationOwner())).artistWindowScope(parameter);
    }

    function artistWindowStateHash(bytes32 parameter, uint64 value, uint64 revision)
        external
        view
        returns (bytes32)
    {
        return IStreamArtistWindows(address(_rotationOwner()))
            .artistWindowStateHash(parameter, value, revision);
    }

    function setArtistWindow(bytes32 parameter, uint64 value, uint64 expectedRevision) external {
        _forwardRegistryWriter();
    }

    function identityRevisionDigest(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32) {
        return StreamArtistIdentityRevisionState.digest(_environment(), p, a);
    }

    function _identityOwner() private view returns (IStreamArtistIdentityRevisionOwner) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistIdentityRevisionOwner(s.owners[2]);
    }

    function operativeIdentityRecord(bytes32 artistId) external view returns (bytes32) {
        return _identityOwner().operativeIdentityRecord(artistId);
    }

    function identityRecordBytes(bytes32 artistId) external view returns (bytes memory) {
        _forwardRegistryRead();
    }

    function identityDocumentBytes(bytes32 hash) external view returns (bytes memory) {
        _forwardRegistryRead();
    }

    function artistDisplayName(bytes32 artistId) external view returns (string memory, bytes32) {
        _forwardRegistryRead();
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        _forwardRegistryRead();
    }

    function revokeArtistAuthorization(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function authorizationRevocationDigest(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32) {
        return StreamArtistAuthorizationState.digest(_environment(), p, a);
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        returns (StreamArtistAuthorizationTypes.State memory)
    {
        _forwardRegistryRead();
    }

    function proposeCollaboratorIdentity(C.IdentityProposal calldata p) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function acceptCollaboratorIdentity(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function acceptCollaborator(C.BindingAcceptance calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function collaboratorIdentityDigest(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a
    ) external view returns (bytes32) {
        return StreamArtistCollaboratorHashes.identityDigest(
            _environment(), account, identityRecordHash, a
        );
    }

    function collaboratorAcceptanceDigest(
        C.BindingAcceptance calldata p,
        T.Authorization calldata a
    ) external view returns (bytes32) {
        return StreamArtistCollaboratorHashes.acceptanceDigest(_environment(), p, a);
    }

    function collaboratorIdentityProposal(address account, bytes32 identityRecordHash)
        external
        view
        returns (C.IdentityProposalState memory)
    {
        _forwardRegistryRead();
    }

    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistCollaboratorIdentityOwner(s.owners[2])
            .collaboratorRegistrationNonceState(account, nonce);
    }

    function collaboratorCount(uint256 collectionId, uint64 generation)
        external
        view
        returns (uint256)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistCollaboratorBindingOwner(s.owners[0])
        .bindingTerms(collectionId, generation)
        .count;
    }

    function collaboratorAt(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        returns (C.Row memory)
    {
        _forwardRegistryRead();
    }

    function collaboratorPayoutAccount(bytes32 artistId, address account)
        external
        view
        returns (address, bytes32)
    {
        return _reads().collaboratorPayoutAccount(artistId, account);
    }

    function grantArtistDelegation(D.Grant calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function revokeArtistDelegation(D.Revocation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function recordDelegatedEconomicsConsent(
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function recordDelegatedProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function delegationGrantDigest(D.Grant calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistDelegationState.grantDigest(_environment(), p, a.nonce);
    }

    function delegationRevocationDigest(D.Revocation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistDelegationState.revokeDigest(_environment(), p, a.nonce, a.time);
    }

    function delegationRecord(bytes32 grant) public view returns (D.Record memory) {
        _forwardRegistryRead();
    }

    function delegationState(bytes32 grant)
        external
        view
        returns (bool, address, uint256, uint32, uint64, uint64, uint64)
    {
        _forwardRegistryRead();
    }

    function delegatedNonceState(bytes32 artistId, address delegate, uint256 nonce)
        external
        view
        returns (bool, uint256)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return
            IStreamArtistDelegationOwner(s.owners[2]).delegatedNonceState(artistId, delegate, nonce);
    }

    function recordDelegation(bytes32 record) external view returns (bytes32) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistDelegatedConsentOwner(s.owners[6]).recordDelegation(record);
    }

    function proposeArtistBinding(
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32, bytes32) {
        _forwardRegistryWriter();
    }

    function acceptArtistBinding(uint256 collectionId, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function acceptArtistBindingExpected(
        uint256 collectionId,
        uint64 generation,
        bytes32 bindingHash,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function refuseArtistBinding(L.Termination calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function withdrawArtistBinding(L.Termination calldata p) external {
        _forwardRegistryWriter();
    }

    function bindingRefusalDigest(L.Termination calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistBindingOperations.refusalDigest(_environment(), p, a);
    }

    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        returns (L.Terminal memory)
    {
        _forwardRegistryRead();
    }

    function recordPolicyConsent(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function recordEconomicsConsent(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function recordPayoutDesignation(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function recordProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function authorizeArtistRoyaltyFreeze(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function isRoyaltyFreezeAuthorized(uint256 collectionId, bytes32 expectedAssignmentHash)
        external
        view
        returns (bool)
    {
        return _reads().isRoyaltyFreezeAuthorized(collectionId, expectedAssignmentHash);
    }

    function royaltyFreezeDigest(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function recordArtistAttestation(
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32) {
        _forwardRegistryWriter();
    }

    function recordContentConsent(Content.Consent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function authorizeArtistContentFreeze(Content.Freeze calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function contentConsentDigest(Content.Consent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardFinalityRead();
    }

    function contentFreezeDigest(Content.Freeze calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardFinalityRead();
    }

    function requireContentConsent(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        external
        view
    {
        StreamArtistContentOperations.consentEvidence(
            _contentSuite(), collectionId, familyId, newStateHash
        );
    }

    function contentConsentEvidence(uint256 collectionId, bytes32 familyId, bytes32 newStateHash)
        external
        view
        returns (bytes32)
    {
        return StreamArtistContentOperations.consentEvidence(
            _contentSuite(), collectionId, familyId, newStateHash
        );
    }

    function isContentFreezeAuthorized(uint256 collectionId, bytes32 lockClass)
        external
        view
        returns (bool, bytes32)
    {
        return StreamArtistContentOperations.freezeAuthorized(
            _contentSuite(), collectionId, lockClass
        );
    }

    function contentFreezeAuthorization(bytes32 recordHash)
        external
        view
        returns (Content.FreezeRecord memory)
    {
        return IStreamArtistContentRecordsOwner(_contentSuite().owners[6])
            .contentFreezeRecord(recordHash);
    }

    function _contentSuite() private view returns (T.SuiteConfiguration memory) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
    }

    function recordContentRatification(T.Ratification calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        _forwardRegistryWriter();
    }

    function consentMode(uint256 collectionId) external view returns (uint8) {
        return _reads().consentMode(collectionId);
    }

    function acceptedArtist(uint256 collectionId) external view returns (address) {
        return _reads().acceptedArtist(collectionId);
    }

    /// @notice Primary acceptance hash/time are historical evidence; artist is zero until whole-set acceptance.
    function attribution(uint256 collectionId)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory)
    {
        return _reads().attribution(collectionId);
    }

    function isPolicyConsented(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
        returns (bool, bytes32)
    {
        return _reads().isPolicyConsented(collectionId, phaseId, policyHash);
    }

    function requireMintConsent(uint256 collectionId, bytes32 phaseId, bytes32 policyHash)
        external
        view
    {
        _reads().requireMintConsent(collectionId, phaseId, policyHash);
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (bool, bytes32, bytes32)
    {
        _forwardRegistryRead();
    }

    function collectionArtistBeneficiary(uint256 collectionId)
        external
        view
        returns (bytes32, address, bytes32)
    {
        return _reads().collectionArtistBeneficiary(collectionId);
    }

    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32) {
        return _reads().artistPayoutAccount(artistId);
    }

    function requireEconomicsConsent(
        uint256 collectionId,
        bytes32 revenueClass,
        uint8 scope,
        uint256 scopeId,
        bytes32 assignmentHash
    ) external view {
        _reads()
            .requireEconomicsConsent(
                T.EconomicsConsent(
                    collectionId, msg.sender, revenueClass, scope, scopeId, assignmentHash
                )
            );
    }

    function acceptanceDigest(uint256 collectionId, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function policyConsentDigest(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardFinalityRead();
    }

    function economicsConsentDigest(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        _forwardRegistryRead();
    }

    function payoutDesignationDigest(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.payoutDigest(_environment(), p, a);
    }

    function attestationDigest(T.Attestation calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.attestationDigest(_environment(), p, a);
    }

    function contentRatificationDigest(T.Ratification calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.ratificationDigest(_environment(), p, a);
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(operationCoordinator).deploymentChainId(),
            address(this),
            core,
            mintManager
        );
    }

    function _reads() private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).reads();
    }

    function _forwardRegistryWriter() private {
        address target = registryWriterExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := delegatecall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function _forwardRegistryRead() private view {
        address target = registryReadExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := staticcall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }

    function _forwardFinalityRead() private view {
        address target = registryFinalityReadExtension;
        assembly ("memory-safe") {
            let pointer := mload(0x40)
            calldatacopy(pointer, 0, calldatasize())
            let success := staticcall(gas(), target, pointer, calldatasize(), 0, 0)
            returndatacopy(pointer, 0, returndatasize())
            if iszero(success) { revert(pointer, returndatasize()) }
            return(pointer, returndatasize())
        }
    }
}
