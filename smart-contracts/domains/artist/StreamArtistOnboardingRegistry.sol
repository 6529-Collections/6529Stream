// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistEconomicsHashes.sol";
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
    StreamModuleBase,
    StreamGasParameterHost
{
    address public immutable override(IStreamArtistMintConsent, IStreamArtistAttribution) core;
    address public immutable override mintManager;
    address public immutable operationCoordinator;

    constructor(
        address core_,
        address manager_,
        address coordinator_,
        address governance_,
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
        _registerGasParameter(GasParameterConfig("ARTIST_ERC1271_VERIFY_GAS", 150_000, 90_000, 2));
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
        return id == type(IStreamArtistMintConsent).interfaceId
            || id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistOnboarding).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistEconomicsAuthority).interfaceId
            || id == type(IStreamArtistDelegation).interfaceId
            || id == type(IStreamArtistBindingLifecycle).interfaceId
            || id == type(IStreamArtistBeneficiaryFacts).interfaceId
            || id == type(IStreamArtistCollaboratorLifecycle).interfaceId
            || id == type(IStreamArtistAuthorizationRevocation).interfaceId
            || super.supportsInterface(id);
    }

    function revokeArtistAuthorization(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistAuthorizationCoordinator(operationCoordinator)
            .coordinateRevokeArtistAuthorization(msg.sender, p, a);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistAuthorizationOwner(s.owners[2])
            .artistAuthorizationState(artistId, digest, nonce);
    }

    function proposeCollaboratorIdentity(C.IdentityProposal calldata p) external returns (bytes32) {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateProposeCollaboratorIdentity(msg.sender, p);
    }

    function acceptCollaboratorIdentity(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32) {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateAcceptCollaboratorIdentity(
                msg.sender, account, identityRecordHash, a, document, displayName
            );
    }

    function acceptCollaborator(C.BindingAcceptance calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateAcceptCollaborator(msg.sender, p, a);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistCollaboratorRecordsOwner(s.owners[1])
            .identityProposal(account, identityRecordHash);
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
        return _reads().collaboratorAt(collectionId, generation, index);
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
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateGrantArtistDelegation(msg.sender, p, a);
    }

    function revokeArtistDelegation(D.Revocation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRevokeArtistDelegation(msg.sender, p, a);
    }

    function recordDelegatedEconomicsConsent(
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRecordDelegatedEconomicsConsent(msg.sender, p, grant, a);
    }

    function recordDelegatedProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRecordDelegatedProspectiveEconomicsConsent(
                msg.sender, p, candidate, grant, a
            );
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateAuthorizeDelegatedRoyaltyFreeze(msg.sender, p, grant, a);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistDelegationOwner(s.owners[2]).delegationRecord(grant);
    }

    function delegationState(bytes32 grant)
        external
        view
        returns (bool, address, uint256, uint32, uint64, uint64, uint64)
    {
        D.Record memory item = delegationRecord(grant);
        uint64 remaining = item.grantor == address(0)
            ? 0
            : item.grant.maxUses == 0
                ? type(uint64).max
                : uint64(uint256(item.grant.maxUses) - item.uses);
        return (
            StreamArtistDelegationState.active(item),
            item.grant.delegate,
            item.grant.collectionId,
            item.grant.capabilities,
            item.grant.notBefore,
            item.grant.expiresAt,
            remaining
        );
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
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateProposeArtistBinding(msg.sender, collectionId, p, document, displayName);
    }

    function acceptArtistBinding(uint256 collectionId, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateAcceptArtistBinding(msg.sender, collectionId, a);
    }

    function acceptArtistBindingExpected(
        uint256 collectionId,
        uint64 generation,
        bytes32 bindingHash,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateAcceptArtistBindingExpected(
                msg.sender, collectionId, generation, bindingHash, a
            );
    }

    function refuseArtistBinding(L.Termination calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateRefuseArtistBinding(msg.sender, p, a);
    }

    function withdrawArtistBinding(L.Termination calldata p) external {
        IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateWithdrawArtistBinding(msg.sender, p);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistBindingTerminationOwner(s.owners[0])
            .bindingTermination(collectionId, generation);
    }

    function recordPolicyConsent(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPolicyConsent(msg.sender, p, a);
    }

    function recordEconomicsConsent(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordEconomicsConsent(msg.sender, p, a);
    }

    function recordPayoutDesignation(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPayoutDesignation(msg.sender, p, a);
    }

    function recordProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external returns (bytes32) {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateRecordProspectiveEconomicsConsent(msg.sender, p, candidate, a);
    }

    function authorizeArtistRoyaltyFreeze(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateAuthorizeArtistRoyaltyFreeze(msg.sender, p, a);
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
        return StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(), p, a.nonce, a.time);
    }

    function recordArtistAttestation(
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external returns (bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordArtistAttestation(msg.sender, p, a, statement);
    }

    function recordContentRatification(T.Ratification calldata p, T.Authorization calldata a)
        external
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordContentRatification(msg.sender, p, a);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        T.RatificationRecord memory r =
            IStreamArtistConsentOwner(s.owners[6]).firstReleaseRatification(collectionId);
        return (r.recordHash != bytes32(0), r.contentStateHash, r.recordHash);
    }

    function collectionArtistBeneficiary(uint256 collectionId)
        external
        view
        returns (bytes32, address, bytes32)
    {
        return _reads().collectionArtistBeneficiary(collectionId);
    }

    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistPayoutOwner(s.owners[5]).artistPayoutAccount(artistId);
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
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return StreamArtistHashes.acceptanceDigest(
            _environment(),
            collectionId,
            IStreamArtistBindingOwner(s.owners[0]).binding(collectionId),
            a
        );
    }

    function policyConsentDigest(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistHashes.policyDigest(_environment(), p, a);
    }

    function economicsConsentDigest(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32)
    {
        return StreamArtistEconomicsHashes.economicsDigest(_environment(), p, a.nonce, a.time);
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
}
