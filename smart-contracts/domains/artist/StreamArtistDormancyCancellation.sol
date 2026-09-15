// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyState.sol";
import "./StreamArtistDelegationState.sol";

/// @notice Explicit notice cancellation by the current artist, an active delegate or operative designee.
library StreamArtistDormancyCancellation {
    function cancel(
        StreamArtistDormancyState.State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistEstateState.State storage estate,
        StreamArtistDelegationState.State storage delegations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 id,
        bytes32 expected,
        bytes32 grant
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (c.operationId != 42) revert T.InvalidOperation(c.operationId);
        T.Identity storage principal = identity.identities[id];
        Dorm.Notice storage n = s.notices[expected];
        if (
            expected == 0 || s.latestNotice[id] != expected || s.phases[expected] != 1
                || n.terms.artistId != id || n.recordHash != expected
                || principal.authorityClass != 1 || principal.authorityAddress != n.incumbent
                || (principal.status != 2 && principal.status != 4) || c.actor == address(0)
        ) revert Dorm.InvalidDormancy(id);
        uint8 class_;
        bytes32 designation =
            StreamArtistSuccessionState.operativeDesignation(succession, rotations, id);
        if (c.actor == principal.authorityAddress) {
            if (grant != 0) revert D.InvalidDelegation(grant);
            class_ = 1;
        } else if (
            designation != 0 && succession.designations[designation].terms.successor == c.actor
        ) {
            if (grant != 0) revert D.InvalidDelegation(grant);
            class_ = 3;
        } else {
            D.Record memory r = delegations.records[grant];
            if (
                grant == 0 || r.grant.artistId != id || r.grant.delegate != c.actor
                    || estate.grantEpoch[grant] != estate.delegationEpoch[id]
                    || !StreamArtistDelegationState.active(r)
            ) revert D.DelegationUnavailable(grant);
            class_ = 2;
        }
        (bytes32 delta, bytes32 replayDelta) =
            StreamArtistDormancyState.activity(s, identity, replay, o, id, c.actor, class_);
        bytes32 terminal = s.terminalForNotice[expected];
        if (terminal == 0 || s.phases[expected] != 2) revert Dorm.InvalidDormancy(id);
        m = StreamArtistIdentityState.Mutation(
            terminal,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_CANCEL_ARTIST_DORMANCY_V1"),
                    id,
                    expected,
                    c.actor,
                    class_,
                    grant
                )
            ),
            delta,
            replayDelta
        );
    }
}
