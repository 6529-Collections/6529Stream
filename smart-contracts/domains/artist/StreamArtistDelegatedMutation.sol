// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistEconomicsHashes.sol";
import "./StreamArtistEstateState.sol";
import "./StreamArtistUnavailabilityState.sol";

/// @notice Exact delegated mutation composition in the fixed Identity storage context.
library StreamArtistDelegatedMutation {
    function authorize(
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext calldata c,
        T.Binding calldata b,
        uint256 collectionId,
        uint32 capability,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof,
        bytes32 digest,
        bytes32 record
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (estate.grantEpoch[grant] != estate.delegationEpoch[b.artistId]) {
            revert D.DelegationUnavailable(grant);
        }
        StreamArtistSuccessionState.requireAllowed(succession, rotations, b.artistId, capability);
        m = StreamArtistIdentityState.authorizeDelegate(
            identity,
            replay,
            delegations,
            o,
            c,
            b,
            collectionId,
            capability,
            grant,
            a,
            proof,
            digest,
            record
        );
        bytes32 delta = StreamArtistUnavailabilityState.noteActivity(
            findings, b.artistId, proof.signer, 2, c.operationId
        );
        if (delta != 0) m.state = keccak256(abi.encode(m.state, delta));
    }

    function consumeDelegatedRoyaltyFreeze(
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.RoyaltyFreeze calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        record = StreamArtistEconomicsHashes.royaltyFreezeRecordForAuthority(
            o.environment, p, b.artistId, proof.signer, 2, a.nonce, _now()
        );
        m = authorize(
            estate,
            succession,
            rotations,
            identity,
            delegations,
            findings,
            replay,
            o,
            c,
            b,
            p.collectionId,
            D.ROYALTY_FREEZE,
            grant,
            a,
            proof,
            StreamArtistEconomicsHashes.royaltyFreezeDigest(o.environment, p, a.nonce, a.time),
            record
        );
    }

    function consumeDelegatedEconomics(
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.EconomicsConsent calldata p,
        bytes32 designation,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        _deadline(a.time);
        if (designation == bytes32(0)) revert T.InvalidRecord();
        record = StreamArtistEconomicsHashes.economicsRecordForAuthority(
            o.environment, p, designation, b.artistId, proof.signer, 2, a.nonce, _now()
        );
        m = authorize(
            estate,
            succession,
            rotations,
            identity,
            delegations,
            findings,
            replay,
            o,
            c,
            b,
            p.collectionId,
            D.ECONOMICS,
            grant,
            a,
            proof,
            StreamArtistEconomicsHashes.economicsDigest(o.environment, p, a.nonce, a.time),
            record
        );
    }

    function consumeDelegatedAttestation(
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistIdentityState.State storage identity,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext calldata c,
        T.Binding calldata b,
        T.Attestation calldata p,
        bytes32 grant,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        if (a.time == 0 || a.time > block.timestamp || p.subjectKind == 0 || p.subjectKind > 10) {
            revert T.InvalidRecord();
        }
        record = StreamArtistHashes.attestationRecordForAuthority(
            o.environment, p, b.artistId, proof.signer, 2, a.nonce, a.time
        );
        m = authorize(
            estate,
            succession,
            rotations,
            identity,
            delegations,
            findings,
            replay,
            o,
            c,
            b,
            p.collectionId,
            p.subjectKind == 7 ? D.INTENT : D.ATTEST,
            grant,
            a,
            proof,
            StreamArtistHashes.attestationDigest(o.environment, p, a),
            record
        );
    }

    function _deadline(uint64 deadline) private view {
        if (block.timestamp > deadline) revert T.ExpiredAuthorization(deadline);
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }
}
