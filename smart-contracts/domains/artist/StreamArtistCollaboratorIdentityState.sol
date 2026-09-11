// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityState.sol";
import "./StreamArtistCollaboratorHashes.sol";

/// @notice Linked registration mechanics over Identity-owned original state and appended account replay index.
/// @dev Identity retains typed caller/snapshot guards and makes one semantic commit for all mutations.
library StreamArtistCollaboratorIdentityState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    struct State {
        mapping(address => StreamArtistNonceAvailability.Index) available;
    }

    function nonceState(
        State storage accounts,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        address account,
        uint256 nonce
    ) public view returns (bool, uint256) {
        (, uint256 hint) = accounts.available[account].firstUnused();
        return (
            replay[_key(
                        o,
                        keccak256("identity_authority.replay.collaborator_account_nonce"),
                        keccak256(abi.encode(account, nonce))
                    )].status != 0,
            hint
        );
    }

    function register(
        StreamArtistIdentityState.State storage identity,
        State storage accounts,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        C.IdentityProposal memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes memory document,
        string memory displayName
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        bytes32 digest = StreamArtistCollaboratorHashes.identityDigest(
                o.environment, p.account, p.identityRecordHash, a
            );
        if (proof.signer != p.account || proof.digest != digest) revert T.InvalidSignature();
        (bool available, uint256 hint) = accounts.available[p.account].firstUnused();
        if (!available || (proof.direct && a.nonce != hint)) revert T.InvalidRecord();
        bytes32 nonceKey = _key(
            o,
            keccak256("identity_authority.replay.collaborator_account_nonce"),
            keccak256(abi.encode(p.account, a.nonce))
        );
        bytes32 digestKey = _key(
            o,
            keccak256("identity_authority.replay.collaborator_account_digest"),
            keccak256(abi.encode(p.account, digest))
        );
        if (replay[nonceKey].status != 0) revert T.Replay(nonceKey);
        if (replay[digestKey].status != 0) revert T.Replay(digestKey);
        replay[nonceKey] = T.ReplayCell(digest, o.revision + 1, 1, 2);
        replay[digestKey] = T.ReplayCell(digest, o.revision + 1, 1, 2);
        bytes32 accountDelta = accounts.available[p.account].consume(a.nonce);
        StreamArtistIdentityState.Mutation memory registration = StreamArtistIdentityState.register(
            identity,
            replay,
            o,
            p.account,
            p.identityRecordHash,
            p.identityRecordURI,
            document,
            displayName
        );
        bytes32 id = registration.record;
        // A direct registration uses the persistent account hint; this fresh identity
        // still consumes that exact nonce and then derives its own independent hint.
        if (proof.direct) identity.identities[id].nonceHint = hint;
        StreamArtistIdentityState.Mutation memory authorization =
            StreamArtistIdentityState.authorize(
            identity, replay, o, c, id, a, proof, digest, id, p.account
        );
        bytes32 uniqueKey = _key(o, keccak256("identity_authority.replay.identity_uniqueness"), id);
        if (replay[uniqueKey].status != 0) revert T.Replay(uniqueKey);
        replay[uniqueKey] = T.ReplayCell(id, o.revision + 1, 1, 2);
        m = StreamArtistIdentityState.Mutation(
            id,
            keccak256(abi.encode(registration.action, authorization.action, p)),
            keccak256(abi.encode(registration.state, authorization.state, accountDelta)),
            keccak256(
                abi.encode(
                    registration.replay,
                    authorization.replay,
                    nonceKey,
                    digestKey,
                    digest,
                    accountDelta,
                    uniqueKey,
                    id
                )
            )
        );
    }

    function _key(StreamArtistIdentityState.OwnerContext memory o, bytes32 surface, bytes32 scope)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                surface,
                scope
            )
        );
    }
}
