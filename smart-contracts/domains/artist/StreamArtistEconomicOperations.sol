// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorizationState.sol";
import "./StreamArtistCurrentAuthorityFacts.sol";
import "../../interfaces/stream/artist/IStreamArtistCurrentConsentOwner.sol";
import {
    IStreamArtistEconomicsEvidence
} from "../../interfaces/stream/artist/IStreamArtistEconomicsEvidence.sol";

import "./StreamArtistOnboardingReads.sol";
import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistRegistryValidatorBase.sol";
import "./StreamArtistDelegationState.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistDelegatedConsentOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistArchiveV2.sol";
import "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import "../../interfaces/stream/core/IStreamCoreCollectionView.sol";

/// @notice Linked typed economic/delegation recipes in the Coordinator's guarded execution context.
/// @dev No semantic state. Facade authentication, immutable code checks and the operation lock stay on Coordinator.
library StreamArtistEconomicOperations {
    function grant(
        D.CoordinatorContext memory x,
        address actor,
        D.Grant memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 26);
        (address signer, uint8 class_, uint8 status,) =
            IStreamArtistIdentityOwner(x.suite.owners[2]).authorityState(p.artistId);
        if (class_ != 1 || status != 1) revert T.InvalidIdentity(p.artistId);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistDelegationState.grantDigest(_environment(x), p, a.nonce),
            a.signature
        );
        record = IStreamArtistDelegationOwner(x.suite.owners[2])
            .grantDelegation(T.ActionContext(26, actor, before_[2]), p, a, proof);
        _archive(x, 26, actor, record, before_, abi.encode(p, a, proof));
    }

    function revoke(
        D.CoordinatorContext memory x,
        address actor,
        D.Revocation memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 27);
        D.Record memory prior = IStreamArtistDelegationOwner(x.suite.owners[2])
            .delegationRecord(p.delegationRecordHash);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            prior.grantor,
            StreamArtistDelegationState.revokeDigest(_environment(x), p, a.nonce, a.time),
            a.signature
        );
        record = IStreamArtistDelegationOwner(x.suite.owners[2])
            .revokeDelegation(T.ActionContext(27, actor, before_[2]), p, a, proof);
        _archive(x, 27, actor, record, before_, abi.encode(prior, p, a, proof));
    }

    function economicsCurrent(
        D.CoordinatorContext memory x,
        address actor,
        T.EconomicsConsent memory p,
        bytes32 delegation,
        T.Authorization memory a
    ) public returns (bytes32) {
        T.Snapshot[7] memory before_ = _snapshots(x, 15);
        StreamArtistOnboardingReads reads = StreamArtistOnboardingReads(x.reads);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(x, p.collectionId);
        T.Payout memory payout = _payout(x, b.artistId);
        bytes memory currentEvidence = reads.requireCurrentEconomics(p, payout.account);
        return _economics(x, actor, b, p, payout, delegation, a, before_, currentEvidence);
    }

    function economicsProspective(
        D.CoordinatorContext memory x,
        address actor,
        T.EconomicsConsent memory p,
        T.FixedEconomicsCandidate memory candidate,
        bytes32 delegation,
        T.Authorization memory a
    ) public returns (bytes32) {
        T.Snapshot[7] memory before_ = _snapshots(x, 15);
        StreamArtistOnboardingReads reads = StreamArtistOnboardingReads(x.reads);
        T.Binding memory b = reads.acceptedBinding(p.collectionId);
        _collection(x, p.collectionId);
        T.Payout memory payout = _payout(x, b.artistId);
        (T.AssignmentFact memory actual, bytes32 previousHash) =
            reads.requireProspectiveEconomicsWithEvidence(p, candidate, payout.account);
        return _economics(
            x,
            actor,
            b,
            p,
            payout,
            delegation,
            a,
            before_,
            abi.encode(candidate, actual, previousHash)
        );
    }

    function _economics(
        D.CoordinatorContext memory x,
        address actor,
        T.Binding memory b,
        T.EconomicsConsent memory p,
        T.Payout memory payout,
        bytes32 delegation,
        T.Authorization memory a,
        T.Snapshot[7] memory before_,
        bytes memory candidateEvidence
    ) private returns (bytes32 record) {
        D.Record memory prior;
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, false);
        address signer = authority.authorityAddress;
        if (delegation != bytes32(0)) {
            prior = IStreamArtistDelegationOwner(x.suite.owners[2]).delegationRecord(delegation);
            signer = prior.grant.delegate;
        }
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistEconomicsHashes.economicsDigest(_environment(x), p, a.nonce, a.time),
            a.signature
        );
        bytes32 actual;
        if (delegation == bytes32(0)) {
            record = IStreamArtistIdentityOwner(x.suite.owners[2])
                .consumeEconomics(
                    T.ActionContext(15, actor, before_[2]), b, p, payout.recordHash, a, proof
                );
            actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
                .recordEconomicsWithAuthority(
                    T.ActionContext(15, actor, before_[6]),
                    b,
                    p,
                    payout,
                    proof.signer,
                    a.nonce,
                    authority
                );
        } else {
            record = IStreamArtistDelegationOwner(x.suite.owners[2])
                .consumeDelegatedEconomics(
                    T.ActionContext(15, actor, before_[2]),
                    b,
                    p,
                    payout.recordHash,
                    delegation,
                    a,
                    proof
                );
            actual = IStreamArtistDelegatedConsentOwner(x.suite.owners[6])
                .recordDelegatedEconomics(
                    T.ActionContext(15, actor, before_[6]),
                    b,
                    p,
                    payout,
                    proof.signer,
                    a.nonce,
                    delegation
                );
        }
        if (actual != record) revert T.InvalidRecord();
        IStreamArtistEconomicsEvidence.Association memory association =
            IStreamArtistEconomicsEvidence(x.suite.owners[6]).economicsRecordAssociation(record);
        bytes memory payload = abi.encode(b, p, payout, a, proof, candidateEvidence, association);
        if (delegation != bytes32(0)) payload = abi.encode(payload, delegation, prior);
        _archive(x, 15, actor, record, before_, payload);
    }

    function freeze(
        D.CoordinatorContext memory x,
        address actor,
        T.RoyaltyFreeze memory p,
        bytes32 delegation,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 20);
        StreamArtistOnboardingReads reads = StreamArtistOnboardingReads(x.reads);
        T.Binding memory b = reads.defensiveBinding(p.collectionId);
        _collection(x, p.collectionId);
        reads.requireRoyaltyFreezeProposal(p);
        D.Record memory prior;
        R.AuthorityFact memory authority =
            StreamArtistCurrentAuthorityFacts.read(x.suite.owners[2], b.artistId, true);
        address signer = authority.authorityAddress;
        if (delegation != bytes32(0)) {
            prior = IStreamArtistDelegationOwner(x.suite.owners[2]).delegationRecord(delegation);
            signer = prior.grant.delegate;
        }
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistEconomicsHashes.royaltyFreezeDigest(_environment(x), p, a.nonce, a.time),
            a.signature
        );
        bytes32 actual;
        if (delegation == bytes32(0)) {
            record = IStreamArtistIdentityOwner(x.suite.owners[2])
                .consumeRoyaltyFreeze(T.ActionContext(20, actor, before_[2]), b, p, a, proof);
            actual = IStreamArtistCurrentConsentOwner(x.suite.owners[6])
                .authorizeRoyaltyFreezeWithAuthority(
                    T.ActionContext(20, actor, before_[6]), b, p, proof.signer, a.nonce, authority
                );
        } else {
            record = IStreamArtistDelegationOwner(x.suite.owners[2])
                .consumeDelegatedRoyaltyFreeze(
                    T.ActionContext(20, actor, before_[2]), b, p, delegation, a, proof
                );
            actual = IStreamArtistDelegatedConsentOwner(x.suite.owners[6])
                .authorizeDelegatedRoyaltyFreeze(
                    T.ActionContext(20, actor, before_[6]), b, p, proof.signer, a.nonce, delegation
                );
        }
        if (actual != record) revert T.InvalidRecord();
        bytes memory payload = abi.encode(b, p, a, proof);
        if (delegation != bytes32(0)) payload = abi.encode(payload, delegation, prior);
        _archive(x, 20, actor, record, before_, payload);
    }

    function _payout(D.CoordinatorContext memory x, bytes32 artistId)
        private
        view
        returns (T.Payout memory payout)
    {
        (payout.account, payout.recordHash) =
            StreamArtistOnboardingReads(x.reads).artistPayoutAccount(artistId);
        if (payout.account == address(0) || payout.recordHash == bytes32(0)) {
            revert T.MissingMintPrerequisite(keccak256("payout"));
        }
    }

    function revokeAuthorization(
        D.CoordinatorContext memory x,
        address actor,
        StreamArtistAuthorizationTypes.Revocation memory p,
        T.Authorization memory a
    ) public returns (bytes32 record) {
        T.Snapshot[7] memory before_ = _snapshots(x, 54);
        (address signer,,,) =
            IStreamArtistIdentityOwner(x.suite.owners[2]).authorityState(p.artistId);
        T.SignerApproval memory proof = _verify(
            x,
            actor,
            signer,
            StreamArtistAuthorizationState.digest(_environment(x), p, a),
            a.signature
        );
        record = IStreamArtistAuthorizationOwner(x.suite.owners[2])
            .revokeAuthorization(T.ActionContext(54, actor, before_[2]), p, a, proof);
        _archive(x, 54, actor, record, before_, abi.encode(p, a, proof));
    }

    function _verify(
        D.CoordinatorContext memory x,
        address actor,
        address signer,
        bytes32 digest,
        bytes memory signature
    ) private view returns (T.SignerApproval memory) {
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

    function _snapshots(D.CoordinatorContext memory x, uint16 op)
        private
        view
        returns (T.Snapshot[7] memory result)
    {
        uint256 mask = op == 26 || op == 27 || op == 54 ? 4 : op == 15 ? 0x77 : 0x57;
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
