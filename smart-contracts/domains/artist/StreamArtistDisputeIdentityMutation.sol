// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeHashes.sol";
import "./StreamArtistDelegatedMutation.sol";

library StreamArtistDisputeIdentityMutation {
    function consume(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        StreamArtistDelegationState.State storage delegations,
        StreamArtistUnavailabilityState.State storage findings,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext calldata c,
        AD.Filing calldata p,
        T.Binding calldata b,
        AD.Standing calldata standing,
        T.Authorization calldata a,
        T.SignerApproval calldata proof
    ) public returns (StreamArtistIdentityState.Mutation memory m, bytes32 record) {
        StreamArtistDisputeHashes.validate(p);
        if (
            c.operationId != (p.disputeAction == 1 ? 44 : 45) || b.generation != p.bindingGeneration
                || b.artistId == 0 || standing.artistId == 0 || block.timestamp > type(uint64).max
                || (!proof.direct && (a.time == 0 || block.timestamp > a.time))
                || (proof.direct && a.time != 0 && block.timestamp > a.time)
        ) revert T.InvalidRecord();
        uint8 class_ =
            standing.delegation == 0 ? identity.identities[standing.artistId].authorityClass : 2;
        record = StreamArtistDisputeHashes.record(
            o.environment, p, proof.signer, class_, a.nonce, uint64(block.timestamp)
        );
        bytes32 digest = StreamArtistDisputeHashes.digest(o.environment, p, a);
        if (standing.delegation == 0) {
            m = StreamArtistIdentityState.authorize(
                identity,
                replay,
                o,
                c,
                standing.artistId,
                a,
                proof,
                digest,
                record,
                identity.identities[standing.artistId].authorityAddress
            );
        } else {
            if (standing.artistId != b.artistId || standing.bindingGeneration != b.generation) {
                revert T.InvalidRecord();
            }
            m = StreamArtistDelegatedMutation.authorize(
                estate,
                succession,
                rotations,
                identity,
                delegations,
                findings,
                dormancy,
                replay,
                o,
                c,
                b,
                p.collectionId,
                16,
                standing.delegation,
                a,
                proof,
                digest,
                record
            );
        }
    }
}
