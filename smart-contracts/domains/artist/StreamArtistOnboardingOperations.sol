// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistIdentityDismissal.sol";
import "../../interfaces/stream/artist/IStreamArtistPayoutResolutionOwner.sol";
import "./StreamArtistIdentityOperations.sol";
import "./StreamArtistRotationOperations.sol";

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

/// @notice Linked onboarding recipes in the authenticated, locked Coordinator context.
/// @dev No independent state or public dispatcher; every public entry has a typed fixed recipe.
library StreamArtistOnboardingOperations {
    function propose(
        D.CoordinatorContext memory x,
        address actor,
        uint256 collectionId,
        T.BindingProposal memory p,
        bytes memory document,
        string memory displayName
    ) public returns (bytes32 artistId, bytes32 bindingHash) {
        bytes32 role = keccak256("ROLE_ARTIST_REGISTRY_ADMIN");
        if (!IStreamRoleRegistry(x.suite.roleRegistry).hasRole(role, actor)) {
            revert T.Unauthorized(actor);
        }
        (bytes32 roleHash, uint64 roleRevision) =
            IStreamRoleRegistry(x.suite.roleRegistry).roleMutationState(role);
        T.Snapshot[7] memory before_ = _snapshots(x, 1);
        _collection(x, collectionId);
        IStreamArtistIdentityOwner identity = IStreamArtistIdentityOwner(x.suite.owners[2]);
        artistId = p.artistId;
        bool reused = artistId != bytes32(0);
        if (reused) {
            StreamArtistIdentityOperations.validateProposalIdentity(
                x.suite.owners[2], p, document, displayName
            );
        } else {
            artistId = identity.registerIdentity(
                _context(1, actor, before_[2]),
                p.artistAddress,
                p.identityRecordHash,
                p.identityRecordURI,
                document,
                displayName
            );
        }
        T.Binding memory b = IStreamArtistBindingOwner(x.suite.owners[0])
            .propose(_context(1, actor, before_[0]), collectionId, artistId, p);
        bindingHash = b.bindingHash;
        IStreamArtistAttributionOwner(x.suite.owners[4])
            .claim(_context(1, actor, before_[4]), collectionId, b, p.reasonHash, p.reasonURI);
        _archive(
            x,
            1,
            actor,
            bindingHash,
            before_,
            abi.encode(collectionId, p, document, displayName, reused, roleHash, roleRevision)
        );
    }

    function policy(
        D.CoordinatorContext memory x,
        address actor,
        T.PolicyConsent memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 14);
        T.Binding memory b = StreamArtistOnboardingReads(x.reads).acceptedBinding(p.collectionId);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        _collection(x, p.collectionId);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            authority.authorityAddress,
            StreamArtistHashes.policyDigest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(x.suite.owners[2])
            .consumePolicy(_context(14, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
            .recordPolicyWithAuthority(
                _context(14, actor, before_[6]), b, p, proof.signer, a.nonce, authority
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 14, actor, record, before_, abi.encode(b, p, a, proof));
    }

    function payout(
        D.CoordinatorContext memory x,
        address actor,
        T.PayoutDesignation memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 18);
        T.Identity memory artist =
            IStreamArtistIdentityOwner(x.suite.owners[2]).identity(p.artistId);
        T.Authorization memory effective = _directObservedTime(actor, artist.authorityAddress, a);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            artist.authorityAddress,
            StreamArtistHashes.payoutDigest(_environment(x), p, effective),
            effective.signature
        );
        IStreamArtistRotationOwner transitionOwner = IStreamArtistRotationOwner(x.suite.owners[2]);
        R.ProvisionalAssociation memory currentAssociation =
            transitionOwner.provisionalAssociation(p.artistId);
        (,, R.ProvisionalAssociation memory candidateAssociation) =
            IStreamArtistPayoutTransitionOwner(x.suite.owners[5]).payoutCandidates(p.artistId);
        R.TransitionState memory currentTransition =
            transitionOwner.artistTransitionState(currentAssociation.transitionRecordHash);
        R.TransitionState memory candidateTransition =
            transitionOwner.artistTransitionState(candidateAssociation.transitionRecordHash);
        Dismissal.PayoutResolutionFacts memory resolution;
        resolution.artistId = p.artistId;
        IStreamArtistIdentityDismissalOwner resolver =
            IStreamArtistIdentityDismissalOwner(x.suite.owners[2]);
        resolution.currentTransitionClosure =
            resolver.identityTransitionClosure(p.artistId, currentTransition.recordHash);
        resolution.candidateTransitionClosure =
            resolver.identityTransitionClosure(p.artistId, candidateTransition.recordHash);
        record = IStreamArtistIdentityOwner(x.suite.owners[2])
            .consumePayout(_context(18, actor, before_[2]), p, effective, proof);
        bytes32 actual = IStreamArtistPayoutResolutionOwner(x.suite.owners[5])
            .recordDesignationWithResolution(
                _context(18, actor, before_[5]),
                p,
                proof.signer,
                effective.nonce,
                effective.time,
                currentTransition,
                candidateTransition,
                resolution
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(
            x,
            18,
            actor,
            record,
            before_,
            abi.encode(p, a, proof, effective, currentTransition, candidateTransition, resolution)
        );
    }

    function ratify(
        D.CoordinatorContext memory x,
        address actor,
        T.Ratification memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 52);
        T.Binding memory b = StreamArtistOnboardingReads(x.reads).acceptedBinding(p.collectionId);
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        _collection(x, p.collectionId);
        (address metadata, bytes32 state) =
            StreamArtistOnboardingReads(x.reads).currentContent(p.collectionId);
        if (p.metadataContract != metadata || p.contentStateHash != state) {
            revert T.InvalidRecord();
        }
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            authority.authorityAddress,
            StreamArtistHashes.ratificationDigest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistIdentityOwner(x.suite.owners[2])
            .consumeRatification(_context(52, actor, before_[2]), b, p, a, proof);
        bytes32 actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
            .recordRatificationWithAuthority(
                _context(52, actor, before_[6]), b, p, proof.signer, a.nonce, authority
            );
        if (actual != record) revert T.InvalidRecord();
        _archive(x, 52, actor, record, before_, abi.encode(b, p, a, proof));
    }

    function _directObservedTime(address actor, address signer, T.Authorization memory submitted)
        private
        view
        returns (T.Authorization memory effective)
    {
        effective = T.Authorization(submitted.nonce, submitted.time, submitted.signature);
        if (
            actor == signer && actor != address(0) && submitted.signature.length == 0
                && submitted.time == 0
        ) {
            if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
            effective.time = uint64(block.timestamp);
        }
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory proof) {
        if (actor == address(0) || signer == address(0)) {
            revert T.InvalidSignature();
        }
        bool direct = actor == signer && signature.length == 0;
        if (!direct) {
            (uint256 cap,, uint8 failureClass, uint64 revision) = IStreamGasParameterHost(
                    x.suite.registry
                ).gasParameterInfo(keccak256("6529STREAM_GGP_ARTIST_ERC1271_VERIFY_GAS"));
            if (
                revision == 0 || failureClass != 2
                    || !StreamArtistRegistryValidatorBase(x.suite.validator)
                        .validateSignerProof(signer, digest, signature, cap)
            ) revert T.InvalidSignature();
        }
        return T.SignerApproval(signer, digest, direct);
    }

    function _collection(D.CoordinatorContext memory x, uint256 collectionId) private view {
        if (!IStreamCoreCollectionView(x.suite.core).collectionExists(collectionId)) {
            revert T.InvalidAttribution(collectionId);
        }
    }

    function _environment(D.CoordinatorContext memory x)
        private
        view
        returns (StreamArtistHashes.Environment memory)
    {
        return StreamArtistHashes.Environment(
            block.chainid, x.suite.registry, x.suite.core, x.suite.mintManager
        );
    }

    function _context(uint16 operationId, address actor, T.Snapshot memory prior)
        private
        pure
        returns (T.ActionContext memory)
    {
        return T.ActionContext(operationId, actor, prior);
    }

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        // acceptedBinding also consumes Attribution's state/generation. Commit
        // that read for every recipe using it, without adding an owner mutation.
        uint256 mask = op == 1
            ? 0x15
            : op == 2 ? 0x1f : op == 15 ? 0x77 : op == 18 ? 0x24 : op == 24 ? 0x17 : 0x57;
        for (uint256 i; i < 7; ++i) {
            if ((mask & (1 << i)) != 0) {
                result[i] = IStreamArtistOwner(x.suite.owners[i]).ownerStateSnapshotV2();
            }
        }
    }

    function _archive(
        D.CoordinatorContext memory x,
        uint16 op,
        address actor,
        bytes32 record,
        T.Snapshot[7] memory prior,
        bytes memory payload
    ) private {
        T.Snapshot[7] memory after_ = _snapshots(x, op);
        bytes32 id = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ONBOARDING_OPERATION_EVIDENCE_V1"),
                block.chainid,
                x.suite.registry,
                address(this),
                op,
                actor,
                record
            )
        );
        bytes memory evidence =
            abi.encode(uint16(1), x.configurationHash, op, actor, record, prior, after_, payload);
        (bytes32 hash,, bool appended) =
            IStreamArtistArchiveV2(x.suite.archive).appendArtistEvidenceV2(id, 1, evidence);
        if (!appended || hash != keccak256(evidence)) revert T.InvalidRecord();
    }
}
