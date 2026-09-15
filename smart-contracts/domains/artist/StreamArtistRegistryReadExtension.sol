// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import "./StreamArtistRepudiationReadEncoding.sol";

import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    StreamArtistAttributionDisputeTypes as AD
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import "./StreamArtistDisputeReadEncoding.sol";

import { StreamArtistRegistryDigestEncoding } from "./StreamArtistRegistryDigestEncoding.sol";
import { StreamArtistRegistryHistoryEncoding } from "./StreamArtistRegistryHistoryEncoding.sol";
import {
    IStreamArtistHistory,
    IStreamArtistHistoryCoordinator,
    StreamArtistHistoryTypes as H
} from "../../interfaces/stream/artist/IStreamArtistHistory.sol";
import "../../interfaces/stream/artist/IStreamArtistReconstruction.sol";
import "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";
import "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";
import {
    IStreamArtistStewardSanctionGrant as SG,
    IStreamArtistStewardSanctionGrantCoordinator
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";
import "./StreamArtistRegistryAuthorityEncoding.sol";
import "./StreamArtistRegistryPresentationEncoding.sol";
import "../../interfaces/stream/artist/IStreamArtistPlatformWorks.sol";
import "../../interfaces/stream/artist/IStreamArtistDisplayFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionClaims.sol";
import "./StreamArtistAttributionPolicy.sol";
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistSanctionReads.sol";
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

/// @notice Fixed stateless read composition for the registry's explicit view selectors.
/// @dev Static calls originate from the bound facade; these selected reads never consume caller authority.
contract StreamArtistRegistryReadExtension {
    error ExtensionWrongHost(address actual);
    error InvalidAttribution(uint256 collectionId);
    address private immutable _host;
    address private immutable operationCoordinator;

    constructor(address host_, address coordinator_) {
        if (
            host_ == address(0) || coordinator_ == address(0) || host_ == coordinator_
                || host_ == address(this)
        ) revert T.InvalidBinding();
        _host = host_;
        operationCoordinator = coordinator_;
    }

    modifier onlyHost() {
        if (msg.sender != _host) revert ExtensionWrongHost(msg.sender);
        _;
    }

    function contentConsentEvidenceForHost(
        uint256 collectionId,
        address contentHost,
        bytes32 familyId,
        bytes32 newStateHash
    ) external view onlyHost returns (bytes32) {
        return StreamArtistContentOperations.consentEvidenceForHost(
            _contentSuite(), collectionId, contentHost, familyId, newStateHash
        );
    }

    function recordPreimageBytes(bytes32 hash) external view onlyHost returns (bytes memory) {
        return IStreamArtistReconstruction(_contentSuite().archive).recordPreimageBytes(hash);
    }

    function storedPayloadCount() external view onlyHost returns (uint256) {
        return IStreamArtistReconstruction(_contentSuite().archive).storedPayloadCount();
    }

    function storedPayloadAt(uint256 index)
        external
        view
        onlyHost
        returns (address, bytes32, bytes32)
    {
        return IStreamArtistReconstruction(_contentSuite().archive).storedPayloadAt(index);
    }

    function requireRecordPublication(bytes32 recordHash, P.Publication calldata publication)
        external
        view
        onlyHost
        returns (P.Evidence memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.requireRecordPublication(
                _host, operationCoordinator, recordHash, publication
            )
        );
    }

    function estateActivationDigest(Estate.Request calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistEstateOwner(_contentSuite().owners[2]).estateActivationDigest(p, a);
    }

    function estateActivationState(bytes32 artistId)
        external
        view
        onlyHost
        returns (address, uint64, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateActivationState(
                _host, operationCoordinator, artistId
            )
        );
    }

    function estateActivationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Estate.RequestRecord memory, uint8, Estate.ExecutionFacts memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateActivationRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function estateActivationNonceHint(bytes32 artistId, address successor)
        external
        view
        onlyHost
        returns (uint256)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateActivationNonceHint(
                _host, operationCoordinator, artistId, successor
            )
        );
    }

    function currentAuthorityCapabilities(bytes32 artistId)
        external
        view
        onlyHost
        returns (Estate.AuthorityCapabilities memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.currentAuthorityCapabilities(
                _host, operationCoordinator, artistId
            )
        );
    }

    function estateAccelerationContext(Estate.Execution calldata p)
        external
        view
        onlyHost
        returns (Estate.AccelerationContext memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateAccelerationContext(
                _host, operationCoordinator, p
            )
        );
    }

    function collectionArtistAuthority(uint256 collectionId)
        external
        view
        onlyHost
        returns (bytes32, uint64, bytes32, address, uint8, uint8, uint32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.collectionArtistAuthority(
                _host, operationCoordinator, collectionId
            )
        );
    }

    function platformWorksState(uint256 id) external view onlyHost returns (PW.State memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksState(
                _host, operationCoordinator, id
            )
        );
    }

    function platformWorksDeclaration(uint256 id)
        external
        view
        onlyHost
        returns (bool, bytes32, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksDeclaration(
                _host, operationCoordinator, id
            )
        );
    }

    function platformWorksContest(uint256 id) external view onlyHost returns (uint8, bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksContest(
                _host, operationCoordinator, id
            )
        );
    }

    function displayBinding(uint256 id) external view onlyHost returns (T.Binding memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.displayBinding(_host, operationCoordinator, id)
        );
    }

    function artistAttestationStatus(uint256 id, uint8 kind, bytes32 subjectId, bytes32 currentHash)
        external
        view
        onlyHost
        returns (uint8, bytes32, bytes32, uint8, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.artistAttestationStatus(
                _host, operationCoordinator, id, kind, subjectId, currentHash
            )
        );
    }

    function displaySanction(StreamFinalityScope calldata scope)
        external
        view
        onlyHost
        returns (S.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.displaySanction(
                _host, operationCoordinator, scope
            )
        );
    }

    function attributionClaims(uint256 id) external view onlyHost returns (uint256, bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.attributionClaims(
                _host, operationCoordinator, id
            )
        );
    }

    function deploymentAttestation(uint256 id)
        external
        view
        onlyHost
        returns (bytes32, uint8, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.deploymentAttestation(
                _host, operationCoordinator, id
            )
        );
    }

    function attestationAuthorityClass(bytes32 record) external view onlyHost returns (uint8) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.attestationAuthorityClass(
                _host, operationCoordinator, record
            )
        );
    }

    function attributionClaimRecord(bytes32 record)
        external
        view
        onlyHost
        returns (StreamArtistAttributionClaimTypes.Claim memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.attributionClaimRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function platformWorksClaims(uint256 id) external view onlyHost returns (uint256, bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksClaims(
                _host, operationCoordinator, id
            )
        );
    }

    function platformWorksCorrection(uint256 id) external view onlyHost returns (uint64, bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksCorrection(
                _host, operationCoordinator, id
            )
        );
    }

    function platformWorksClaimRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (PW.Claim memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksClaimRecord(
                _host, operationCoordinator, hash
            )
        );
    }

    function platformWorksContestRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (PW.Contest memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksContestRecord(
                _host, operationCoordinator, hash
            )
        );
    }

    function platformWorksContext(
        uint256 id,
        uint8 state,
        bytes32 claim_,
        bytes32 evidence,
        bytes32 reason,
        bool correction
    ) external view onlyHost returns (PW.Context memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.platformWorksContext(
                _host, operationCoordinator, id, state, claim_, evidence, reason, correction
            )
        );
    }

    function _platformOwner() private view returns (IStreamArtistPlatformOwner) {
        return IStreamArtistPlatformOwner(_contentSuite().owners[4]);
    }

    function _contentSuite() private view returns (T.SuiteConfiguration memory) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
    }

    function _rotationOwner() private view returns (IStreamArtistRotationOwner) {
        return IStreamArtistRotationOwner(_contentSuite().owners[2]);
    }

    function _successionOwner() private view returns (IStreamArtistSuccessionOwner) {
        return IStreamArtistSuccessionOwner(_contentSuite().owners[2]);
    }

    function successorDesignation(bytes32 artistId)
        external
        view
        onlyHost
        returns (address, uint8, uint32, bytes32, bytes32, uint256)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.successorDesignation(
                _host, operationCoordinator, artistId
            )
        );
    }

    function operativeSuccessorRecord(bytes32 artistId) external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.operativeSuccessorRecord(
                _host, operationCoordinator, artistId
            )
        );
    }

    function operativeEstateDirective(bytes32 artistId) external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.operativeEstateDirective(
                _host, operationCoordinator, artistId
            )
        );
    }

    function successorDesignationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Succ.DesignationRecord memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.successorDesignationRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function estateDirectiveRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Succ.DirectiveRecord memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateDirectiveRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function estateDirectivePayload(bytes32 record) external view onlyHost returns (bytes memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.estateDirectivePayload(
                _host, operationCoordinator, record
            )
        );
    }

    function successorDesignationDigest(Succ.Designation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        T.SuiteConfiguration memory s = _contentSuite();
        return StreamArtistSuccessionHashes.designationDigest(
            StreamArtistHashes.Environment(block.chainid, _host, s.core, s.mintManager), p, a
        );
    }

    function estateDirectiveDigest(Succ.Directive calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        T.SuiteConfiguration memory s = _contentSuite();
        return StreamArtistSuccessionHashes.directiveDigest(
            StreamArtistHashes.Environment(block.chainid, _host, s.core, s.mintManager), p, a
        );
    }

    function previewEstateDirectivePayload(
        uint32 granted,
        uint32 forbidden,
        Succ.PublicDocument calldata document
    ) external view onlyHost returns (bytes memory) {
        return StreamArtistSuccessionHashes.publicPayload(granted, forbidden, document);
    }

    function identityContestDismissalContext(Dismissal.Request calldata p)
        external
        view
        onlyHost
        returns (Dismissal.Context memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityContestDismissalContext(
                _host, operationCoordinator, p
            )
        );
    }

    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        onlyHost
        returns (Dismissal.Cause memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.currentIdentityContestCause(
                _host, operationCoordinator, artistId
            )
        );
    }

    function identityContestCause(bytes32 causeHash)
        external
        view
        onlyHost
        returns (Dismissal.Cause memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityContestCause(
                _host, operationCoordinator, causeHash
            )
        );
    }

    function identityContestDismissalRecord(bytes32 recordHash)
        external
        view
        onlyHost
        returns (Dismissal.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityContestDismissalRecord(
                _host, operationCoordinator, recordHash
            )
        );
    }

    function latestIdentityContestDismissal(bytes32 artistId)
        external
        view
        onlyHost
        returns (bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.latestIdentityContestDismissal(
                _host, operationCoordinator, artistId
            )
        );
    }

    function identityTransitionClosure(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        onlyHost
        returns (Dismissal.Closure memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityTransitionClosure(
                _host, operationCoordinator, artistId, transitionRecordHash
            )
        );
    }

    function identityRevisionContinuation(bytes32 continuationHash)
        external
        view
        onlyHost
        returns (Dismissal.RevisionContinuation memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityRevisionContinuation(
                _host, operationCoordinator, continuationHash
            )
        );
    }

    function identityContestRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Contest.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityContestRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function latestIdentityContest(bytes32 artistId) external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.latestIdentityContest(
                _host, operationCoordinator, artistId
            )
        );
    }

    function identityContestGovernanceContext(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external view onlyHost returns (bytes32, bytes32, bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityContestGovernanceContext(
                    _host,
                    operationCoordinator,
                    artistId,
                    subjectRecordHash,
                    evidenceHash,
                    reasonHash
                )
        );
    }

    function guardianSetRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.GuardianRecord memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.guardianSetRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function rotationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.RotationRecord memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.rotationRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.StandingRecord memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.standingRevocationRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function _identityOwner() private view returns (IStreamArtistIdentityRevisionOwner) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistIdentityRevisionOwner(s.owners[2]);
    }

    function identityRecordBytes(bytes32 artistId) external view onlyHost returns (bytes memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityRecordBytes(
                _host, operationCoordinator, artistId
            )
        );
    }

    function identityDocumentBytes(bytes32 hash) external view onlyHost returns (bytes memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityDocumentBytes(
                _host, operationCoordinator, hash
            )
        );
    }

    function artistDisplayName(bytes32 artistId)
        external
        view
        onlyHost
        returns (string memory, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.artistDisplayName(
                _host, operationCoordinator, artistId
            )
        );
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        onlyHost
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.identityRevisionRecord(
                _host, operationCoordinator, record
            )
        );
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        onlyHost
        returns (StreamArtistAuthorizationTypes.State memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryAuthorityEncoding.artistAuthorizationState(
                _host, operationCoordinator, artistId, digest, nonce
            )
        );
    }

    function collaboratorIdentityProposal(address account, bytes32 identityRecordHash)
        external
        view
        onlyHost
        returns (C.IdentityProposalState memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.collaboratorIdentityProposal(
                _host, operationCoordinator, account, identityRecordHash
            )
        );
    }

    function collaboratorAt(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        onlyHost
        returns (C.Row memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.collaboratorAt(
                _host, operationCoordinator, collectionId, generation, index
            )
        );
    }

    function delegationRecord(bytes32 grant) public view onlyHost returns (D.Record memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.delegationRecord(
                _host, operationCoordinator, grant
            )
        );
    }

    function delegationState(bytes32 grant)
        external
        view
        onlyHost
        returns (bool, address, uint256, uint32, uint64, uint64, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.delegationState(
                _host, operationCoordinator, grant
            )
        );
    }

    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        onlyHost
        returns (L.Terminal memory)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.bindingTermination(
                _host, operationCoordinator, collectionId, generation
            )
        );
    }

    function _reads() private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).reads();
    }

    function firstReleaseRatification(uint256 collectionId)
        external
        view
        onlyHost
        returns (bool, bytes32, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryPresentationEncoding.firstReleaseRatification(
                _host, operationCoordinator, collectionId
            )
        );
    }

    function acceptanceDigest(uint256 collectionId, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRegistryDigestEncoding.digest(_host, operationCoordinator, msg.data, 1);
    }

    function royaltyFreezeDigest(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(), p, a.nonce, a.time);
    }

    function economicsConsentDigest(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistEconomicsHashes.economicsDigest(_environment(), p, a.nonce, a.time);
    }

    function _environment() private view returns (StreamArtistHashes.Environment memory) {
        T.SuiteConfiguration memory s = _contentSuite();
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(operationCoordinator).deploymentChainId(),
            _host,
            s.core,
            s.mintManager
        );
    }

    function guardianSetDigest(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRegistryDigestEncoding.digest(_host, operationCoordinator, msg.data, 2);
    }

    function rotationDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRotationHashes.rotationDigest(_environment(), p, a);
    }

    function rotationAcceptanceDigest(R.Rotation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRotationHashes.acceptanceDigest(_environment(), p, a);
    }

    function standingRevocationDigest(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRotationHashes.standingDigest(_environment(), p, a);
    }

    function identityRevisionDigest(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a
    ) external view onlyHost returns (bytes32) {
        return StreamArtistIdentityRevisionState.digest(_environment(), p, a);
    }

    function authorizationRevocationDigest(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external view onlyHost returns (bytes32) {
        return StreamArtistAuthorizationState.digest(_environment(), p, a);
    }

    function bindingRefusalDigest(L.Termination calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistBindingOperations.refusalDigest(_environment(), p, a);
    }

    function payoutDesignationDigest(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistHashes.payoutDigest(_environment(), p, a);
    }

    function attestationDigest(T.Attestation calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistRegistryDigestEncoding.digest(_host, operationCoordinator, msg.data, 3);
    }

    function contentRatificationDigest(T.Ratification calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return StreamArtistHashes.ratificationDigest(_environment(), p, a);
    }

    function _returnRegistryEncoded(bytes memory encoded) private pure {
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function dormancyState(bytes32 id) external view onlyHost returns (uint8, uint64, uint64) {
        _forwardDormancyRead();
    }

    function dormancyNotice(bytes32 id) external view onlyHost returns (bytes32, uint8, bytes32) {
        _forwardDormancyRead();
    }

    function dormancyRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (Dorm.Notice memory, uint8, Dorm.Terminal memory)
    {
        _forwardDormancyRead();
    }

    function dormancyInitiationContext(Dorm.Initiation calldata p)
        external
        view
        onlyHost
        returns (Dorm.Context memory)
    {
        _forwardDormancyRead();
    }

    function dormancyCompletionContext(Dorm.Completion calldata p)
        external
        view
        onlyHost
        returns (Dorm.Context memory, Dorm.Plan memory)
    {
        _forwardDormancyRead();
    }

    function dormancyCompletionEvidence(Dorm.Completion calldata p)
        external
        view
        onlyHost
        returns (bytes memory)
    {
        _forwardDormancyRead();
    }

    function stewardSanctionGrant(bytes32 id) external view onlyHost returns (bool, bytes32) {
        _forwardDormancyRead();
    }

    function stewardSanctionGrantRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (SG.GrantRecord memory)
    {
        _forwardDormancyRead();
    }

    function stewardSanctionGrantSignature(bytes32 hash)
        external
        view
        onlyHost
        returns (bytes memory)
    {
        _forwardDormancyRead();
    }

    function stewardSanctionGrantDigest(SG.Grant calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        _forwardDormancyRead();
    }

    // Every public selector above is explicit; this private relay always targets the fixed Identity owner.
    function _forwardDormancyRead() private view {
        (bool ok, bytes memory raw) = _contentSuite().owners[2].staticcall(msg.data);
        assembly ("memory-safe") {
            if iszero(ok) { revert(add(raw, 32), mload(raw)) }
            return(add(raw, 32), mload(raw))
        }
    }

    function stewardCapabilityGrantContext(SC.Grant calldata p)
        external
        view
        onlyHost
        returns (SC.Context memory)
    {
        _forwardDormancyRead();
    }

    function stewardCapabilityGrantRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (SC.Record memory)
    {
        _forwardDormancyRead();
    }

    function stewardCapabilityGrantState(bytes32 appointment)
        external
        view
        onlyHost
        returns (bytes32, uint32)
    {
        _forwardDormancyRead();
    }

    function artistRecordChainHash(bytes32 id) external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function collectionRecordChainHash(uint256 id) external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistHistoryLane(uint8 kind, bytes32 id)
        external
        view
        onlyHost
        returns (bytes32, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistHistoryRecordAt(uint8 kind, bytes32 id, uint64 index)
        external
        view
        onlyHost
        returns (bytes32, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistHistoryContinuityCommitment() external view onlyHost returns (bytes32) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function importedHistoryBindingCount() external view onlyHost returns (uint256) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function importedHistoryBinding(uint256 index)
        external
        view
        onlyHost
        returns (address, uint64, bytes32, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistHistoryPredecessorBinding(address source)
        external
        view
        onlyHost
        returns (bool, bytes32, uint256)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function verifyImportedRecord(bytes32 root, H.Leaf calldata p, bytes32[] calldata proof)
        external
        view
        onlyHost
        returns (bool)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function importedLaneVerified(uint8 kind, bytes32 id)
        external
        view
        onlyHost
        returns (bool, bytes32, uint64)
    {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistRegistryCutover() external view onlyHost returns (bool, address, uint64) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function artistHistoryImportContext(
        address predecessor,
        uint64 snapshot,
        bytes32 root,
        bytes32 manifest
    ) external view onlyHost returns (H.Context memory) {
        _returnRegistryEncoded(
            StreamArtistRegistryHistoryEncoding.read(_contentSuite().owners[2], msg.data)
        );
    }

    function attributionDispute(uint256 id, uint64 generation)
        external
        view
        onlyHost
        returns (AD.Head memory)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionDisputeRecord(bytes32 record)
        external
        view
        onlyHost
        returns (AD.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionDisputeResolution(bytes32 action)
        external
        view
        onlyHost
        returns (AD.Resolution memory)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionDisputeDigest(AD.Filing calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionDisputeOpeningContext(AD.Filing calldata p)
        external
        view
        onlyHost
        returns (AD.Context memory)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionDisputeResolutionContext(AD.ResolutionRequest calldata p)
        external
        view
        onlyHost
        returns (AD.Context memory)
    {
        _returnRegistryEncoded(
            StreamArtistDisputeReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function pendingRepudiation(uint256 id)
        external
        view
        onlyHost
        returns (uint64, uint64, bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRepudiationReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionRepudiationRecord(bytes32 hash)
        external
        view
        onlyHost
        returns (RP.Record memory)
    {
        _returnRegistryEncoded(
            StreamArtistRepudiationReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionRepudiationTerminal(bytes32 hash)
        external
        view
        onlyHost
        returns (RP.Terminal memory)
    {
        _returnRegistryEncoded(
            StreamArtistRepudiationReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function activeRepudiationCount(bytes32 artistId) external view onlyHost returns (uint256) {
        _returnRegistryEncoded(
            StreamArtistRepudiationReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }

    function attributionRepudiationDigest(AD.Filing calldata p, T.Authorization calldata a)
        external
        view
        onlyHost
        returns (bytes32)
    {
        _returnRegistryEncoded(
            StreamArtistRepudiationReadEncoding.read(_host, operationCoordinator, msg.data)
        );
    }
}
