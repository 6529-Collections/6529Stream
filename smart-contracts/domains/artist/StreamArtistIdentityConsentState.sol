// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "./StreamArtistContentHashes.sol";
import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistSaleHashes.sol";
import "./StreamArtistBindingOperations.sol";
import "./StreamArtistSanctionHashes.sol";

/// @notice Typed authorization mechanics; Identity keeps every operation guard and semantic commit.
library StreamArtistIdentityConsentState {
    function sanction(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        S.Terms memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        if (proof.direct || a.signature.length == 0) revert S.SanctionSignatureRequired();
        S.Record memory r;
        r.artistId = b.artistId;
        r.signer = proof.signer;
        r.authorityClass = identity.identities[b.artistId].authorityClass;
        r.terms = p;
        r.nonce = a.nonce;
        r.signedAt = _now();
        record = StreamArtistSanctionHashes.record(o.environment, r);
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistSanctionHashes.digest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function refusal(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        L.Termination memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        if (
            b.accepted || b.generation != p.generation || b.bindingHash != p.bindingHash
                || proof.signer != identity.identities[b.artistId].authorityAddress
        ) revert T.InvalidRecord();
        record = StreamArtistBindingOperations.refusalRecordForAuthority(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistBindingOperations.refusalDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function saleConsent(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        Sale.Consent memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        if (
            p.collectionId == 0 || p.saleAdapter == address(0) || p.saleId == bytes32(0)
                || p.saleConfigHash == bytes32(0)
        ) revert T.InvalidRecord();
        record = StreamArtistSaleHashes.record(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistSaleHashes.digest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function acceptance(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        uint256 collectionId,
        T.Binding memory b,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        record = StreamArtistHashes.acceptanceRecordForAuthority(
            o.environment,
            collectionId,
            b,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.acceptanceDigest(o.environment, collectionId, b, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function policy(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        T.PolicyConsent memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        record = StreamArtistHashes.policyRecordForAuthority(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.policyDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function contentConsent(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        Content.Consent memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        StreamArtistContentHashes.validateConsent(p);
        record = StreamArtistContentHashes.consentRecord(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistContentHashes.consentDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function economics(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        T.EconomicsConsent memory p,
        bytes32 designation,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        if (designation == bytes32(0)) revert T.InvalidRecord();
        record = StreamArtistEconomicsHashes.economicsRecordForAuthority(
            o.environment,
            p,
            designation,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistEconomicsHashes.economicsDigest(o.environment, p, a.nonce, a.time),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function royaltyFreeze(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        T.RoyaltyFreeze memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        record = StreamArtistEconomicsHashes.royaltyFreezeRecordForAuthority(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistEconomicsHashes.royaltyFreezeDigest(o.environment, p, a.nonce, a.time),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function contentFreeze(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        Content.Freeze memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        StreamArtistContentHashes.validateFreeze(p);
        record = StreamArtistContentHashes.freezeRecord(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistContentHashes.freezeDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function payout(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.PayoutDesignation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        if (a.time == 0 || a.time > block.timestamp) revert T.InvalidTimestamp(a.time);
        record = StreamArtistHashes.payoutRecordForAuthority(
            o.environment,
            p,
            proof.signer,
            identity.identities[p.artistId].authorityClass,
            a.nonce,
            a.time
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            StreamArtistHashes.payoutDigest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
    }

    function attestation(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        T.Attestation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        if (a.time == 0 || a.time > block.timestamp) revert T.InvalidTimestamp(a.time);
        record = StreamArtistHashes.attestationRecordForAuthority(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            a.time
        );
        if (p.subjectKind == 7) {
            m = StreamArtistIdentityState.authorizeIntentAttestation(
                identity,
                replay,
                o,
                c,
                b.artistId,
                a,
                proof,
                StreamArtistHashes.attestationDigest(o.environment, p, a),
                record,
                identity.identities[b.artistId].authorityAddress
            );
            return (m, record);
        }
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.attestationDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function ratification(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        T.Ratification memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        record = StreamArtistHashes.ratificationRecordForAuthority(
            o.environment,
            p,
            b.artistId,
            proof.signer,
            identity.identities[b.artistId].authorityClass,
            a.nonce,
            _now()
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistHashes.ratificationDigest(o.environment, p, a),
            record,
            identity.identities[b.artistId].authorityAddress
        );
    }

    function _deadline(uint64 time) private view {
        if (block.timestamp > time) revert T.ExpiredAuthorization(time);
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
