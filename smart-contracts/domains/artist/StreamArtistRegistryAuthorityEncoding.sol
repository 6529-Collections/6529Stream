// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
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

/// @notice Fixed typed read encoding; suite and host originate from the immutable reader.
library StreamArtistRegistryAuthorityEncoding {
    struct Context {
        address host;
        address coordinator;
    }

    function estateActivationState(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        (address v0, uint64 v1, bytes32 v2) =
            _original_estateActivationState(Context(host, coordinator), artistId);
        return abi.encode(v0, v1, v2);
    }

    function _original_estateActivationState(Context memory x, bytes32 artistId)
        private
        view
        returns (address, uint64, bytes32)
    {
        return IStreamArtistEstateOwner(_contentSuite(x).owners[2]).estateActivationState(artistId);
    }

    function estateActivationRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        (Estate.RequestRecord memory v0, uint8 v1, Estate.ExecutionFacts memory v2) =
            _original_estateActivationRecord(Context(host, coordinator), record);
        return abi.encode(v0, v1, v2);
    }

    function _original_estateActivationRecord(Context memory x, bytes32 record)
        private
        view
        returns (Estate.RequestRecord memory, uint8, Estate.ExecutionFacts memory)
    {
        return IStreamArtistEstateOwner(_contentSuite(x).owners[2]).estateActivationRecord(record);
    }

    function estateActivationNonceHint(
        address host,
        address coordinator,
        bytes32 artistId,
        address successor
    ) public view returns (bytes memory) {
        uint256 v0 = _original_estateActivationNonceHint(
            Context(host, coordinator), artistId, successor
        );
        return abi.encode(v0);
    }

    function _original_estateActivationNonceHint(
        Context memory x,
        bytes32 artistId,
        address successor
    ) private view returns (uint256) {
        return IStreamArtistEstateOwner(_contentSuite(x).owners[2])
            .estateActivationNonceHint(artistId, successor);
    }

    function currentAuthorityCapabilities(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        Estate.AuthorityCapabilities memory v0 =
            _original_currentAuthorityCapabilities(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_currentAuthorityCapabilities(Context memory x, bytes32 artistId)
        private
        view
        returns (Estate.AuthorityCapabilities memory)
    {
        return IStreamArtistEstateOwner(_contentSuite(x).owners[2])
            .currentAuthorityCapabilities(artistId);
    }

    function estateAccelerationContext(
        address host,
        address coordinator,
        Estate.Execution calldata p
    ) public view returns (bytes memory) {
        Estate.AccelerationContext memory v0 =
            _original_estateAccelerationContext(Context(host, coordinator), p);
        return abi.encode(v0);
    }

    function _original_estateAccelerationContext(Context memory x, Estate.Execution calldata p)
        private
        view
        returns (Estate.AccelerationContext memory)
    {
        return StreamArtistEstateOperations.acceleration(
            D.CoordinatorContext(_contentSuite(x), address(0), bytes32(0)), p
        );
    }

    function collectionArtistAuthority(address host, address coordinator, uint256 collectionId)
        public
        view
        returns (bytes memory)
    {
        (bytes32 v0, uint64 v1, bytes32 v2, address v3, uint8 v4, uint8 v5, uint32 v6) =
            _original_collectionArtistAuthority(Context(host, coordinator), collectionId);
        return abi.encode(v0, v1, v2, v3, v4, v5, v6);
    }

    function _original_collectionArtistAuthority(Context memory x, uint256 collectionId)
        private
        view
        returns (bytes32, uint64, bytes32, address, uint8, uint8, uint32)
    {
        T.SuiteConfiguration memory s = _contentSuite(x);
        (uint8 state, uint64 generation, bytes32 artistId,, bytes32 hash) =
            StreamArtistSaleOperations.attributionState(s, collectionId);
        T.Binding memory b = IStreamArtistBindingOwner(s.owners[0]).binding(collectionId);
        if (
            !StreamArtistAttributionPolicy.acceptedOrSanctioned(state) || !b.accepted
                || artistId == bytes32(0) || hash == bytes32(0) || generation != b.generation
                || hash != b.bindingHash || artistId != b.artistId
        ) revert T.InvalidAttribution(collectionId);
        Estate.AuthorityCapabilities memory f =
            IStreamArtistEstateOwner(s.owners[2]).currentAuthorityCapabilities(artistId);
        return (
            artistId,
            generation,
            hash,
            f.authorityAddress,
            f.authorityClass,
            f.status,
            f.effectiveCapabilities
        );
    }

    function successorDesignation(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        (address v0, uint8 v1, uint32 v2, bytes32 v3, bytes32 v4, uint256 v5) =
            _original_successorDesignation(Context(host, coordinator), artistId);
        return abi.encode(v0, v1, v2, v3, v4, v5);
    }

    function _original_successorDesignation(Context memory x, bytes32 artistId)
        private
        view
        returns (address, uint8, uint32, bytes32, bytes32, uint256)
    {
        return _successionOwner(x).successorDesignation(artistId);
    }

    function operativeSuccessorRecord(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes32 v0 = _original_operativeSuccessorRecord(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_operativeSuccessorRecord(Context memory x, bytes32 artistId)
        private
        view
        returns (bytes32)
    {
        return _successionOwner(x).operativeSuccessorRecord(artistId);
    }

    function operativeEstateDirective(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes32 v0 = _original_operativeEstateDirective(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_operativeEstateDirective(Context memory x, bytes32 artistId)
        private
        view
        returns (bytes32)
    {
        return _successionOwner(x).operativeEstateDirective(artistId);
    }

    function successorDesignationRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        Succ.DesignationRecord memory v0 =
            _original_successorDesignationRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_successorDesignationRecord(Context memory x, bytes32 record)
        private
        view
        returns (Succ.DesignationRecord memory)
    {
        return _successionOwner(x).successorDesignationRecord(record);
    }

    function estateDirectiveRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        Succ.DirectiveRecord memory v0 =
            _original_estateDirectiveRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_estateDirectiveRecord(Context memory x, bytes32 record)
        private
        view
        returns (Succ.DirectiveRecord memory)
    {
        return _successionOwner(x).estateDirectiveRecord(record);
    }

    function estateDirectivePayload(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        bytes memory v0 = _original_estateDirectivePayload(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_estateDirectivePayload(Context memory x, bytes32 record)
        private
        view
        returns (bytes memory)
    {
        return _successionOwner(x).estateDirectivePayload(record);
    }

    function identityContestDismissalContext(
        address host,
        address coordinator,
        Dismissal.Request calldata p
    ) public view returns (bytes memory) {
        Dismissal.Context memory v0 = _original_identityContestDismissalContext(
            Context(host, coordinator), p
        );
        return abi.encode(v0);
    }

    function _original_identityContestDismissalContext(
        Context memory x,
        Dismissal.Request calldata p
    ) private view returns (Dismissal.Context memory) {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .identityContestDismissalContext(p);
    }

    function currentIdentityContestCause(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        Dismissal.Cause memory v0 =
            _original_currentIdentityContestCause(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_currentIdentityContestCause(Context memory x, bytes32 artistId)
        private
        view
        returns (Dismissal.Cause memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .currentIdentityContestCause(artistId);
    }

    function identityContestCause(address host, address coordinator, bytes32 causeHash)
        public
        view
        returns (bytes memory)
    {
        Dismissal.Cause memory v0 =
            _original_identityContestCause(Context(host, coordinator), causeHash);
        return abi.encode(v0);
    }

    function _original_identityContestCause(Context memory x, bytes32 causeHash)
        private
        view
        returns (Dismissal.Cause memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .identityContestCause(causeHash);
    }

    function identityContestDismissalRecord(address host, address coordinator, bytes32 recordHash)
        public
        view
        returns (bytes memory)
    {
        Dismissal.Record memory v0 =
            _original_identityContestDismissalRecord(Context(host, coordinator), recordHash);
        return abi.encode(v0);
    }

    function _original_identityContestDismissalRecord(Context memory x, bytes32 recordHash)
        private
        view
        returns (Dismissal.Record memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .identityContestDismissalRecord(recordHash);
    }

    function latestIdentityContestDismissal(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes32 v0 = _original_latestIdentityContestDismissal(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_latestIdentityContestDismissal(Context memory x, bytes32 artistId)
        private
        view
        returns (bytes32)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .latestIdentityContestDismissal(artistId);
    }

    function identityTransitionClosure(
        address host,
        address coordinator,
        bytes32 artistId,
        bytes32 transitionRecordHash
    ) public view returns (bytes memory) {
        Dismissal.Closure memory v0 = _original_identityTransitionClosure(
            Context(host, coordinator), artistId, transitionRecordHash
        );
        return abi.encode(v0);
    }

    function _original_identityTransitionClosure(
        Context memory x,
        bytes32 artistId,
        bytes32 transitionRecordHash
    ) private view returns (Dismissal.Closure memory) {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .identityTransitionClosure(artistId, transitionRecordHash);
    }

    function identityRevisionContinuation(
        address host,
        address coordinator,
        bytes32 continuationHash
    ) public view returns (bytes memory) {
        Dismissal.RevisionContinuation memory v0 =
            _original_identityRevisionContinuation(Context(host, coordinator), continuationHash);
        return abi.encode(v0);
    }

    function _original_identityRevisionContinuation(Context memory x, bytes32 continuationHash)
        private
        view
        returns (Dismissal.RevisionContinuation memory)
    {
        return IStreamArtistIdentityDismissalOwner(_contentSuite(x).owners[2])
            .identityRevisionContinuation(continuationHash);
    }

    function identityContestRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        Contest.Record memory v0 =
            _original_identityContestRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_identityContestRecord(Context memory x, bytes32 record)
        private
        view
        returns (Contest.Record memory)
    {
        return IStreamArtistIdentityContestOwner(_contentSuite(x).owners[2])
            .identityContestRecord(record);
    }

    function latestIdentityContest(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes32 v0 = _original_latestIdentityContest(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_latestIdentityContest(Context memory x, bytes32 artistId)
        private
        view
        returns (bytes32)
    {
        return IStreamArtistIdentityContestOwner(_contentSuite(x).owners[2])
            .latestIdentityContest(artistId);
    }

    function identityContestGovernanceContext(
        address host,
        address coordinator,
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) public view returns (bytes memory) {
        (bytes32 v0, bytes32 v1, bytes32 v2) = _original_identityContestGovernanceContext(
            Context(host, coordinator), artistId, subjectRecordHash, evidenceHash, reasonHash
        );
        return abi.encode(v0, v1, v2);
    }

    function _original_identityContestGovernanceContext(
        Context memory x,
        bytes32 artistId,
        bytes32 subjectRecordHash,
        bytes32 evidenceHash,
        bytes32 reasonHash
    ) private view returns (bytes32, bytes32, bytes32) {
        return IStreamArtistIdentityContestOwner(_contentSuite(x).owners[2])
            .identityContestContext(
                Contest.Request(artistId, subjectRecordHash, evidenceHash, reasonHash)
            );
    }

    function guardianSetRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        R.GuardianRecord memory v0 = _original_guardianSetRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_guardianSetRecord(Context memory x, bytes32 record)
        private
        view
        returns (R.GuardianRecord memory)
    {
        return _rotationOwner(x).guardianSetRecord(record);
    }

    function rotationRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        R.RotationRecord memory v0 = _original_rotationRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_rotationRecord(Context memory x, bytes32 record)
        private
        view
        returns (R.RotationRecord memory)
    {
        return _rotationOwner(x).rotationRecord(record);
    }

    function standingRevocationRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        R.StandingRecord memory v0 =
            _original_standingRevocationRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_standingRevocationRecord(Context memory x, bytes32 record)
        private
        view
        returns (R.StandingRecord memory)
    {
        return _rotationOwner(x).standingRevocationRecord(record);
    }

    function identityRecordBytes(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        bytes memory v0 = _original_identityRecordBytes(Context(host, coordinator), artistId);
        return abi.encode(v0);
    }

    function _original_identityRecordBytes(Context memory x, bytes32 artistId)
        private
        view
        returns (bytes memory)
    {
        return _identityOwner(x).identityRecordBytes(artistId);
    }

    function identityDocumentBytes(address host, address coordinator, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        bytes memory v0 = _original_identityDocumentBytes(Context(host, coordinator), hash);
        return abi.encode(v0);
    }

    function _original_identityDocumentBytes(Context memory x, bytes32 hash)
        private
        view
        returns (bytes memory)
    {
        return _identityOwner(x).identityDocumentBytes(hash);
    }

    function artistDisplayName(address host, address coordinator, bytes32 artistId)
        public
        view
        returns (bytes memory)
    {
        (string memory v0, bytes32 v1) =
            _original_artistDisplayName(Context(host, coordinator), artistId);
        return abi.encode(v0, v1);
    }

    function _original_artistDisplayName(Context memory x, bytes32 artistId)
        private
        view
        returns (string memory, bytes32)
    {
        return _identityOwner(x).artistDisplayName(artistId);
    }

    function identityRevisionRecord(address host, address coordinator, bytes32 record)
        public
        view
        returns (bytes memory)
    {
        StreamArtistIdentityRevisionTypes.Record memory v0 =
            _original_identityRevisionRecord(Context(host, coordinator), record);
        return abi.encode(v0);
    }

    function _original_identityRevisionRecord(Context memory x, bytes32 record)
        private
        view
        returns (StreamArtistIdentityRevisionTypes.Record memory)
    {
        return _identityOwner(x).identityRevisionRecord(record);
    }

    function artistAuthorizationState(
        address host,
        address coordinator,
        bytes32 artistId,
        bytes32 digest,
        uint256 nonce
    ) public view returns (bytes memory) {
        StreamArtistAuthorizationTypes.State memory v0 =
            _original_artistAuthorizationState(Context(host, coordinator), artistId, digest, nonce);
        return abi.encode(v0);
    }

    function _original_artistAuthorizationState(
        Context memory x,
        bytes32 artistId,
        bytes32 digest,
        uint256 nonce
    ) private view returns (StreamArtistAuthorizationTypes.State memory) {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        return IStreamArtistAuthorizationOwner(s.owners[2])
            .artistAuthorizationState(artistId, digest, nonce);
    }

    function _contentSuite(Context memory x) private view returns (T.SuiteConfiguration memory) {
        return StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
    }

    function _platformOwner(Context memory x) private view returns (IStreamArtistPlatformOwner) {
        return IStreamArtistPlatformOwner(_contentSuite(x).owners[4]);
    }

    function _rotationOwner(Context memory x) private view returns (IStreamArtistRotationOwner) {
        return IStreamArtistRotationOwner(_contentSuite(x).owners[2]);
    }

    function _successionOwner(Context memory x)
        private
        view
        returns (IStreamArtistSuccessionOwner)
    {
        return IStreamArtistSuccessionOwner(_contentSuite(x).owners[2]);
    }

    function _identityOwner(Context memory x)
        private
        view
        returns (IStreamArtistIdentityRevisionOwner)
    {
        T.SuiteConfiguration memory s =
            StreamArtistOnboardingCoordinator(x.coordinator).suiteConfiguration();
        return IStreamArtistIdentityRevisionOwner(s.owners[2]);
    }

    function _reads(Context memory x) private view returns (StreamArtistOnboardingReads) {
        return StreamArtistOnboardingCoordinator(x.coordinator).reads();
    }

    function _environment(Context memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        T.SuiteConfiguration memory s = _contentSuite(x);
        return StreamArtistHashes.Environment(
            StreamArtistOnboardingCoordinator(x.coordinator).deploymentChainId(),
            x.host,
            s.core,
            s.mintManager
        );
    }
}
