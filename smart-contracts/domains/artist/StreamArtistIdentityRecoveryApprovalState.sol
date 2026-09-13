// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "./StreamArtistRecoveryHashes.sol";

/// @notice Recovery approval uses Identity's current-principal proof and permanent shared nonce lane.
library StreamArtistIdentityRecoveryApprovalState {
    function consume(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        T.Binding memory b,
        Recovery.ApprovalTerms memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 recordHash) {
        if (block.timestamp > type(uint64).max) revert T.InvalidTimestamp(type(uint64).max);
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        if (
            c.operationId != 22 || !b.accepted || b.consentMode != 1 || b.artistId == 0
                || b.generation == 0 || b.bindingHash == 0 || p.finalityRegistry == address(0)
                || p.collectionId == 0 || p.finalityRecordHash == 0 || p.recoveryManifestHash == 0
        ) revert Recovery.InvalidRecoveryApproval();
        Recovery.ApprovalRecord memory r;
        r.terms = p;
        r.artistId = b.artistId;
        r.signer = proof.signer;
        r.authorityClass = identity.identities[b.artistId].authorityClass;
        r.nonce = a.nonce;
        r.signedAt = uint64(block.timestamp);
        recordHash = StreamArtistRecoveryHashes.approvalRecord(o.environment, r);
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            b.artistId,
            a,
            proof,
            StreamArtistRecoveryHashes.approvalDigest(o.environment, p, a.nonce, a.time),
            recordHash,
            identity.identities[b.artistId].authorityAddress
        );
    }
}
