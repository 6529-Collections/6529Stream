// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";

import "./StreamArtistEconomicsHashes.sol";
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

/// @notice Stateless, constructor-fixed writer bodies for the registry's explicit selectors.
/// @dev Delegated execution preserves the original actor; direct calls cannot reach Coordinator.
contract StreamArtistRegistryWriterExtension {
    error ExtensionWrongHost(address actual);
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
        if (address(this) != _host) revert ExtensionWrongHost(address(this));
        _;
    }

    function recordArtistSanction(Q.Request calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistSanctionCoordinator(operationCoordinator)
            .coordinateRecordArtistSanction(msg.sender, p, a);
    }

    function requestEstateActivation(Estate.Request calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistEstateCoordinator(operationCoordinator)
            .coordinateRequestEstateActivation(msg.sender, p, a);
    }

    function cancelEstateActivation(bytes32 artistId, bytes32 expected) external onlyHost {
        IStreamArtistEstateCoordinator(operationCoordinator)
            .coordinateCancelEstateActivation(msg.sender, artistId, expected);
    }

    function executeEstateActivation(Estate.Execution calldata p) external onlyHost {
        IStreamArtistEstateCoordinator(operationCoordinator)
            .coordinateExecuteEstateActivation(msg.sender, p);
    }

    function recordSaleConsent(Sale.Consent calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistSaleCoordinator(operationCoordinator)
            .coordinateRecordSaleConsent(msg.sender, p, a);
    }

    function dismissArtistIdentityContest(Dismissal.Request calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistIdentityDismissalCoordinator(operationCoordinator)
            .coordinateDismissArtistIdentityContest(msg.sender, p);
    }

    function contestArtistIdentity(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external onlyHost returns (bytes32) {
        return IStreamArtistIdentityContestCoordinator(operationCoordinator)
            .coordinateContestArtistIdentity(
                msg.sender, Contest.Request(artistId, subjectRecordHash, evidenceHash, reasonHash)
            );
    }

    function recordIdentityRevision(
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        return IStreamArtistIdentityRevisionCoordinator(operationCoordinator)
            .coordinateRecordIdentityRevision(msg.sender, p, a, document, displayName);
    }

    function recordSuccessorDesignation(Succ.Designation calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistSuccessionCoordinator(operationCoordinator)
            .coordinateRecordSuccessorDesignation(msg.sender, p, a);
    }

    function recordEstateDirective(
        Succ.Directive calldata p,
        T.Authorization calldata a,
        Succ.PublicDocument calldata document
    ) external onlyHost returns (bytes32) {
        return IStreamArtistSuccessionCoordinator(operationCoordinator)
            .coordinateRecordEstateDirective(msg.sender, p, a, document);
    }

    function setArtistGuardians(R.GuardianSet calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateSetArtistGuardians(msg.sender, p, a);
    }

    function rotateArtistAddress(
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external onlyHost returns (bytes32) {
        return IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateRotateArtistAddress(msg.sender, p, oldAuthorization, newAuthorization);
    }

    function approveArtistRotation(bytes32 artistId, bytes32 expected) external onlyHost {
        IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateApproveArtistRotation(msg.sender, artistId, expected);
    }

    function vetoArtistRotation(bytes32 artistId, bytes32 expected, bytes32 reasonHash)
        external
        onlyHost
    {
        IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateVetoArtistRotation(msg.sender, artistId, expected, reasonHash);
    }

    function executeArtistRotation(bytes32 artistId, bytes32 expected) external onlyHost {
        IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateExecuteArtistRotation(msg.sender, artistId, expected);
    }

    function revokePriorAddressStanding(R.StandingRevocation calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistRotationCoordinator(operationCoordinator)
            .coordinateRevokePriorAddressStanding(msg.sender, p, a);
    }

    function setArtistWindow(bytes32 parameter, uint64 value, uint64 expectedRevision)
        external
        onlyHost
    {
        IStreamArtistWindowCoordinator(operationCoordinator)
            .coordinateSetArtistWindow(msg.sender, parameter, value, expectedRevision);
    }

    function revokeArtistAuthorization(
        StreamArtistAuthorizationTypes.Revocation calldata p,
        T.Authorization calldata a
    ) external onlyHost returns (bytes32) {
        return IStreamArtistAuthorizationCoordinator(operationCoordinator)
            .coordinateRevokeArtistAuthorization(msg.sender, p, a);
    }

    function proposeCollaboratorIdentity(C.IdentityProposal calldata p)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateProposeCollaboratorIdentity(msg.sender, p);
    }

    function acceptCollaboratorIdentity(
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32) {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateAcceptCollaboratorIdentity(
                msg.sender, account, identityRecordHash, a, document, displayName
            );
    }

    function acceptCollaborator(C.BindingAcceptance calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistCollaboratorCoordinator(operationCoordinator)
            .coordinateAcceptCollaborator(msg.sender, p, a);
    }

    function grantArtistDelegation(D.Grant calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateGrantArtistDelegation(msg.sender, p, a);
    }

    function revokeArtistDelegation(D.Revocation calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRevokeArtistDelegation(msg.sender, p, a);
    }

    function recordDelegatedEconomicsConsent(
        T.EconomicsConsent calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external onlyHost returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRecordDelegatedEconomicsConsent(msg.sender, p, grant, a);
    }

    function recordDelegatedProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        bytes32 grant,
        T.Authorization calldata a
    ) external onlyHost returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateRecordDelegatedProspectiveEconomicsConsent(
                msg.sender, p, candidate, grant, a
            );
    }

    function authorizeDelegatedRoyaltyFreeze(
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a
    ) external onlyHost returns (bytes32) {
        return IStreamArtistDelegationCoordinator(operationCoordinator)
            .coordinateAuthorizeDelegatedRoyaltyFreeze(msg.sender, p, grant, a);
    }

    function proposeArtistBinding(
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external onlyHost returns (bytes32, bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateProposeArtistBinding(msg.sender, collectionId, p, document, displayName);
    }

    function acceptArtistBinding(uint256 collectionId, T.Authorization calldata a)
        external
        onlyHost
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
    ) external onlyHost returns (bytes32) {
        return IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateAcceptArtistBindingExpected(
                msg.sender, collectionId, generation, bindingHash, a
            );
    }

    function refuseArtistBinding(L.Termination calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateRefuseArtistBinding(msg.sender, p, a);
    }

    function withdrawArtistBinding(L.Termination calldata p) external onlyHost {
        IStreamArtistBindingLifecycleCoordinator(operationCoordinator)
            .coordinateWithdrawArtistBinding(msg.sender, p);
    }

    function recordPolicyConsent(T.PolicyConsent calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPolicyConsent(msg.sender, p, a);
    }

    function recordEconomicsConsent(T.EconomicsConsent calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordEconomicsConsent(msg.sender, p, a);
    }

    function recordPayoutDesignation(T.PayoutDesignation calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordPayoutDesignation(msg.sender, p, a);
    }

    function recordProspectiveEconomicsConsent(
        T.EconomicsConsent calldata p,
        T.FixedEconomicsCandidate calldata candidate,
        T.Authorization calldata a
    ) external onlyHost returns (bytes32) {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateRecordProspectiveEconomicsConsent(msg.sender, p, candidate, a);
    }

    function authorizeArtistRoyaltyFreeze(T.RoyaltyFreeze calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistEconomicsCoordinator(operationCoordinator)
            .coordinateAuthorizeArtistRoyaltyFreeze(msg.sender, p, a);
    }

    function recordArtistAttestation(
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external onlyHost returns (bytes32) {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordArtistAttestation(msg.sender, p, a, statement);
    }

    function recordContentConsent(Content.Consent calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistContentCoordinator(operationCoordinator)
            .coordinateRecordContentConsent(msg.sender, p, a);
    }

    function authorizeArtistContentFreeze(Content.Freeze calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistContentCoordinator(operationCoordinator)
            .coordinateAuthorizeArtistContentFreeze(msg.sender, p, a);
    }

    function recordContentRatification(T.Ratification calldata p, T.Authorization calldata a)
        external
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistOnboardingCoordinator(operationCoordinator)
            .coordinateRecordContentRatification(msg.sender, p, a);
    }
}
