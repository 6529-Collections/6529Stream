// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "../../interfaces/stream/artist/IStreamArtistAuthorizationRevocation.sol";

/// @notice Linked operation-54 mechanics; Identity retains the typed guard and single semantic commit.
library StreamArtistAuthorizationState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    event ArtistAuthorizationRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 revokedDigest,
        uint256 revokedNonce,
        uint256 nonce,
        uint64 revokedAt,
        bytes32 revocationRecordHash
    );

    function digest(
        StreamArtistHashes.Environment memory e,
        StreamArtistAuthorizationTypes.Revocation memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistAuthorizationRevocation(bytes32 artistId,bytes32 revokedDigest,uint256 revokedNonce,uint256 nonce,uint64 deadline)"
                    ),
                    p.artistId,
                    p.revokedDigest,
                    p.revokedNonce,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function authorizationState(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        bytes32 actionDigest,
        uint256 nonce
    ) public view returns (StreamArtistAuthorizationTypes.State memory result) {
        result.digestObserved = replay[_key(
                    o,
                    keccak256("identity_authority.replay.authorization_consumed_digest"),
                    keccak256(abi.encode(artistId, actionDigest))
                )].status != 0;
        result.digestRevoked = replay[_key(
                    o,
                    keccak256("identity_authority.replay.digest_revocation"),
                    keccak256(abi.encode(artistId, actionDigest))
                )].status != 0;
        result.nonceConsumed = replay[_key(
                    o,
                    keccak256("identity_authority.replay.nonce_allocator"),
                    keccak256(abi.encode(artistId, nonce))
                )].status != 0;
        result.nonceRevoked = replay[_targetKey(o, artistId, bytes32(0), nonce)].status != 0;
        result.nextUnusedNonce = identity.identities[artistId].nonceHint;
    }

    function revoke(
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        StreamArtistAuthorizationTypes.Revocation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (p.artistId == bytes32(0) || (p.revokedDigest == bytes32(0)) == (p.revokedNonce == 0)) {
            revert T.InvalidRecord();
        }
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        bytes32 actionDigest = digest(o.environment, p, a);
        if (
            p.revokedDigest == actionDigest
                || (p.revokedDigest == bytes32(0) && p.revokedNonce == a.nonce)
        ) revert T.InvalidRecord();
        bytes32 target = _targetKey(o, p.artistId, p.revokedDigest, p.revokedNonce);
        if (replay[target].status != 0) revert T.Replay(target);
        bytes32 denyKey;
        if (p.revokedDigest != bytes32(0)) {
            bytes32 used = _key(
                o,
                keccak256("identity_authority.replay.authorization_consumed_digest"),
                keccak256(abi.encode(p.artistId, p.revokedDigest))
            );
            if (replay[used].status != 0) revert T.Replay(used);
            denyKey = _key(
                o,
                keccak256("identity_authority.replay.digest_revocation"),
                keccak256(abi.encode(p.artistId, p.revokedDigest))
            );
        } else {
            denyKey = _key(
                o,
                keccak256("identity_authority.replay.nonce_allocator"),
                keccak256(abi.encode(p.artistId, p.revokedNonce))
            );
        }
        if (replay[denyKey].status != 0) revert T.Replay(denyKey);
        uint64 observed = uint64(block.timestamp);
        bytes32 record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_AUTH_REVOCATION_RECORD_V1"),
                o.environment.chainId,
                o.environment.registry,
                p.artistId,
                p.revokedDigest,
                p.revokedNonce,
                a.nonce,
                observed
            )
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            actionDigest,
            record,
            identity.identities[p.artistId].authorityAddress
        );
        replay[denyKey] = T.ReplayCell(record, o.revision + 1, 1, 2);
        replay[target] = T.ReplayCell(record, o.revision + 1, 1, 2);
        bytes32 availability;
        if (p.revokedDigest == bytes32(0)) {
            availability = identity.nonceAvailability[p.artistId].consume(p.revokedNonce);
            if (identity.identities[p.artistId].nonceHint == p.revokedNonce) {
                (, identity.identities[p.artistId].nonceHint) =
                    identity.nonceAvailability[p.artistId].firstUnused();
            }
        }
        m.action = keccak256(abi.encode(m.action, p, record));
        m.state = keccak256(
            abi.encode(
                m.state, p.artistId, identity.identities[p.artistId].nonceHint, target, record
            )
        );
        m.replay = keccak256(abi.encode(m.replay, denyKey, target, record, availability));
        m.record = record;
        emit ArtistAuthorizationRevoked(
            1, p.artistId, p.revokedDigest, p.revokedNonce, a.nonce, observed, record
        );
    }

    function _targetKey(
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        bytes32 targetDigest,
        uint256 nonce
    ) private view returns (bytes32) {
        return _key(
            o,
            keccak256("identity_authority.replay.target_authorization_revocation"),
            keccak256(abi.encode(artistId, targetDigest, nonce))
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
