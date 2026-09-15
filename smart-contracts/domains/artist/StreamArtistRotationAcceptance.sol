// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistIdentityState.sol";
import "./StreamArtistRotationHashes.sol";
import { StreamArtistAuthorityCheckpoint } from "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";

/// @notice Fixed new-side acceptance mechanics over the original Identity-owned storage.
/// @dev Rotation/recovery callers retain their authorization, expiry and semantic commit order.
library StreamArtistRotationAcceptance {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    function nonceState(
        mapping(bytes32 => uint256) storage acceptanceHint,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address newAddress,
        uint256 nonce
    ) public view returns (bool used, uint256 nextNonce) {
        bytes32 lane = _acceptanceLane(artistId, newAddress);
        used = replay[_key(
                    o,
                    keccak256("identity_authority.replay.nonce_allocator"),
                    _acceptanceScope(artistId, newAddress, nonce)
                )].status != 0;
        nextNonce = acceptanceHint[lane];
    }

    function accept(
        mapping(bytes32 => StreamArtistNonceAvailability.Index) storage acceptanceNonces,
        mapping(bytes32 => uint256) storage acceptanceHint,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 record
    ) public returns (bytes32) {
        bytes32 digest = StreamArtistRotationHashes.acceptanceDigest(o.environment, p, a);
        bytes32 lane = _acceptanceLane(p.artistId, p.newAddress);
        if (
            proof.signer != p.newAddress || proof.digest != digest
                || (proof.direct && (c.actor != proof.signer || a.signature.length != 0))
                || (!proof.direct && a.signature.length == 0 && proof.signer.code.length == 0)
        ) {
            revert T.InvalidSignature();
        }
        if (proof.direct && a.nonce != acceptanceHint[lane]) revert T.InvalidRecord();
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        bytes32 deny = _key(
            o,
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(p.artistId, digest))
        );
        if (replay[deny].status != 0) revert T.Replay(deny);
        bytes32 observation = _key(
            o,
            keccak256("identity_authority.replay.authorization_consumed_digest"),
            keccak256(abi.encode(p.artistId, digest))
        );
        if (replay[observation].status == 0) {
            replay[observation] = T.ReplayCell(digest, o.revision + 1, 1, 2);
            StreamArtistAuthorityCheckpoint.noteReplay(observation, replay[observation]);
        }
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.nonce_allocator"),
            _acceptanceScope(p.artistId, p.newAddress, a.nonce),
            digest
        );
        bytes32 delta = acceptanceNonces[lane].consumeTagged(a.nonce, 4, lane);
        StreamArtistPayloadStore.store(keccak256("ARTIST_SIGNATURE_BUNDLE"), a.signature);
        if (a.nonce == acceptanceHint[lane]) {
            (, acceptanceHint[lane]) = acceptanceNonces[lane].firstUnused();
        }
        return keccak256(
            abi.encode(
                key, digest, delta, observation, replay[observation], acceptanceHint[lane], record
            )
        );
    }

    function _acceptanceLane(bytes32 artistId, address account) private pure returns (bytes32) {
        return keccak256(abi.encode(keccak256("rotation_acceptance"), artistId, account));
    }

    function _acceptanceScope(bytes32 artistId, address account, uint256 nonce)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(keccak256("rotation_acceptance"), artistId, account, nonce));
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

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 record
    ) private returns (bytes32 key) {
        key = _key(o, surface, scope);
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
