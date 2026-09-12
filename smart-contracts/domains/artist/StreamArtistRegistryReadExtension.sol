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

/// @notice Fixed stateless read composition for the registry's explicit view selectors.
/// @dev Static calls originate from the bound facade; these selected reads never consume caller authority.
contract StreamArtistRegistryReadExtension {
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
        if (msg.sender != _host) revert ExtensionWrongHost(msg.sender);
        _;
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
        return _successionOwner().successorDesignation(artistId);
    }

    function operativeSuccessorRecord(bytes32 artistId) external view onlyHost returns (bytes32) {
        return _successionOwner().operativeSuccessorRecord(artistId);
    }

    function operativeEstateDirective(bytes32 artistId) external view onlyHost returns (bytes32) {
        return _successionOwner().operativeEstateDirective(artistId);
    }

    function successorDesignationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Succ.DesignationRecord memory)
    {
        return _successionOwner().successorDesignationRecord(record);
    }

    function estateDirectiveRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Succ.DirectiveRecord memory)
    {
        return _successionOwner().estateDirectiveRecord(record);
    }

    function estateDirectivePayload(bytes32 record) external view onlyHost returns (bytes memory) {
        return _successionOwner().estateDirectivePayload(record);
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
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .identityContestDismissalContext(p);
    }

    function currentIdentityContestCause(bytes32 artistId)
        external
        view
        onlyHost
        returns (Dismissal.Cause memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .currentIdentityContestCause(artistId);
    }

    function identityContestCause(bytes32 causeHash)
        external
        view
        onlyHost
        returns (Dismissal.Cause memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .identityContestCause(causeHash);
    }

    function identityContestDismissalRecord(bytes32 recordHash)
        external
        view
        onlyHost
        returns (Dismissal.Record memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .identityContestDismissalRecord(recordHash);
    }

    function latestIdentityContestDismissal(bytes32 artistId)
        external
        view
        onlyHost
        returns (bytes32)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .latestIdentityContestDismissal(artistId);
    }

    function identityTransitionClosure(bytes32 artistId, bytes32 transitionRecordHash)
        external
        view
        onlyHost
        returns (Dismissal.Closure memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .identityTransitionClosure(artistId, transitionRecordHash);
    }

    function identityRevisionContinuation(bytes32 continuationHash)
        external
        view
        onlyHost
        returns (Dismissal.RevisionContinuation memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite().owners[2])
            .identityRevisionContinuation(continuationHash);
    }

    function identityContestRecord(bytes32 record)
        external
        view
        onlyHost
        returns (Contest.Record memory)
    {
        return IStreamArtistIdentityContestOwner(_contentSuite().owners[2])
            .identityContestRecord(record);
    }

    function latestIdentityContest(bytes32 artistId) external view onlyHost returns (bytes32) {
        return IStreamArtistIdentityContestOwner(_contentSuite().owners[2])
            .latestIdentityContest(artistId);
    }

    function identityContestGovernanceContext(
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) external view onlyHost returns (bytes32, bytes32, bytes32) {
        return IStreamArtistIdentityContestOwner(_contentSuite().owners[2])
            .identityContestContext(
                Contest.Request(artistId, subjectRecordHash, evidenceHash, reasonHash)
            );
    }

    function guardianSetRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.GuardianRecord memory)
    {
        return _rotationOwner().guardianSetRecord(record);
    }

    function rotationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.RotationRecord memory)
    {
        return _rotationOwner().rotationRecord(record);
    }

    function standingRevocationRecord(bytes32 record)
        external
        view
        onlyHost
        returns (R.StandingRecord memory)
    {
        return _rotationOwner().standingRevocationRecord(record);
    }

    function _identityOwner() private view returns (IStreamArtistIdentityRevisionOwner) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistIdentityRevisionOwner(s.owners[2]);
    }

    function identityRecordBytes(bytes32 artistId) external view onlyHost returns (bytes memory) {
        return _identityOwner().identityRecordBytes(artistId);
    }

    function identityDocumentBytes(bytes32 hash) external view onlyHost returns (bytes memory) {
        return _identityOwner().identityDocumentBytes(hash);
    }

    function artistDisplayName(bytes32 artistId)
        external
        view
        onlyHost
        returns (string memory, bytes32)
    {
        return _identityOwner().artistDisplayName(artistId);
    }

    function identityRevisionRecord(bytes32 record)
        external
        view
        onlyHost
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        return _identityOwner().identityRevisionRecord(record);
    }

    function artistAuthorizationState(bytes32 artistId, bytes32 digest, uint256 nonce)
        external
        view
        onlyHost
        returns (StreamArtistAuthorizationTypes.State memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistAuthorizationOwner(s.owners[2])
            .artistAuthorizationState(artistId, digest, nonce);
    }

    function collaboratorIdentityProposal(address account, bytes32 identityRecordHash)
        external
        view
        onlyHost
        returns (C.IdentityProposalState memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistCollaboratorRecordsOwner(s.owners[1])
            .identityProposal(account, identityRecordHash);
    }

    function collaboratorAt(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        onlyHost
        returns (C.Row memory)
    {
        return _reads().collaboratorAt(collectionId, generation, index);
    }

    function delegationRecord(bytes32 grant) public view onlyHost returns (D.Record memory) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistDelegationOwner(s.owners[2]).delegationRecord(grant);
    }

    function delegationState(bytes32 grant)
        external
        view
        onlyHost
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

    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        onlyHost
        returns (L.Terminal memory)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(operationCoordinator).suiteConfiguration();
        return IStreamArtistBindingTerminationOwner(s.owners[0])
            .bindingTermination(collectionId, generation);
    }

    function _reads() private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(operationCoordinator).reads();
    }
}
