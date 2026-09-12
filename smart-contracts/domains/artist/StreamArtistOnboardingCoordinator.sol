// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityOperations.sol";
import "./StreamArtistOnboardingOperations.sol";
import "./StreamArtistRotationOperations.sol";
import "./StreamArtistSaleOperations.sol";
import "./StreamArtistIdentityContestOperations.sol";
import "./StreamArtistSuccessionOperations.sol";
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
    IStreamArtistDelegationCoordinator,
    IStreamArtistBindingLifecycleCoordinator,
    IStreamArtistCollaboratorCoordinator,
    IStreamArtistSaleCoordinator
{
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

    constructor(T.SuiteConfiguration memory suite) {
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
        configurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_CONFIGURATION_V1"),
                block.chainid,
                address(this),
                suite,
                _runtimeHashes,
                uint16(1),
                uint16(2),
                uint16(3),
                uint16(4),
                uint16(5),
                uint16(6),
                uint16(7),
                uint16(14),
                uint16(15),
                uint16(16),
                uint16(17),
                uint16(18),
                uint16(20),
                uint16(21),
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
                uint16(36),
                uint16(37),
                uint16(51),
                uint16(52),
                uint16(54)
            )
        );
        reads = new StreamArtistOnboardingReads(suite);
    }

    modifier operation() {
        if (msg.sender != _suite.registry) revert T.Unauthorized(msg.sender);
        if (_entered != 0) revert T.ReentrantOperation();
        if (block.chainid != deploymentChainId) revert T.InvalidBinding();
        for (uint256 i; i < 16; ++i) {
            if (_targets[i].codehash != _runtimeHashes[i]) revert T.ComponentChanged(_targets[i]);
        }
        _entered = 1;
        _;
        _entered = 0;
    }

    function suiteConfiguration() external view returns (T.SuiteConfiguration memory) {
        return _suite;
    }

    function coordinateRecordSaleConsent(
        address actor,
        Sale.Consent calldata p,
        T.Authorization calldata a
    ) external operation returns (bytes32) {
        return StreamArtistSaleOperations.record(_economicContext(), actor, p, a);
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
        return StreamArtistRotationOperations.guardians(_economicContext(), actor, p, a);
    }

    function coordinateRotateArtistAddress(
        address actor,
        R.Rotation calldata p,
        T.Authorization calldata oldAuthorization,
        T.Authorization calldata newAuthorization
    ) external operation returns (bytes32) {
        return StreamArtistRotationOperations.stage(
            _economicContext(), actor, p, oldAuthorization, newAuthorization
        );
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

    function coordinateProposeArtistBinding(
        address actor,
        uint256 collectionId,
        T.BindingProposal calldata p,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32 artistId, bytes32 bindingHash) {
        return StreamArtistOnboardingOperations.propose(
            _economicContext(), actor, collectionId, p, document, displayName
        );
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
        return StreamArtistCollaboratorOperations.acceptIdentity(
            _economicContext(), actor, account, identityRecordHash, a, document, displayName
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

    function coordinateRecordArtistAttestation(
        address actor,
        T.Attestation calldata p,
        T.Authorization calldata a,
        bytes calldata statement
    ) external operation returns (bytes32 record) {
        return StreamArtistIdentityOperations.attest(_economicContext(), actor, p, a, statement);
    }

    function coordinateRecordIdentityRevision(
        address actor,
        StreamArtistIdentityRevisionTypes.Revision calldata p,
        T.Authorization calldata a,
        bytes calldata document,
        string calldata displayName
    ) external operation returns (bytes32) {
        return StreamArtistIdentityOperations.revise(
            _economicContext(), actor, p, a, document, displayName
        );
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
        return StreamArtistSuccessionOperations.directive(_economicContext(), actor, p, a, document);
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
}
