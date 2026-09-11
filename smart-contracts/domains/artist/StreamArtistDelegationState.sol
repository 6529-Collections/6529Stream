// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistHashes.sol";
import "./StreamArtistNonceAvailability.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";

/// @notice Linked implementation operating only on Identity's appended delegation storage.
/// @dev No independent authority or record store. Identity checks Coordinator/snapshot and commits every returned delta.
library StreamArtistDelegationState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    struct State {
        mapping(bytes32 => D.Record) records;
        mapping(bytes32 => bytes32) current;
        mapping(bytes32 => StreamArtistNonceAvailability.Index) availability;
        mapping(bytes32 => uint256) hints;
    }

    function grantDigest(StreamArtistHashes.Environment memory e, D.Grant memory p, uint256 nonce)
        public
        pure
        returns (bytes32)
    {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistDelegation(address core,address delegate,uint256 collectionId,uint32 capabilities,uint64 notBefore,uint64 expiresAt,uint64 maxUses,bytes32 constraintsHash,uint256 nonce)"
                    ),
                    e.core,
                    p.delegate,
                    p.collectionId,
                    p.capabilities,
                    p.notBefore,
                    p.expiresAt,
                    p.maxUses,
                    p.constraintsHash,
                    nonce
                )
            )
        );
    }

    function revokeDigest(
        StreamArtistHashes.Environment memory e,
        D.Revocation memory p,
        uint256 nonce,
        uint64 deadline
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    keccak256(
                        "StreamArtistDelegationRevocation(bytes32 artistId,address delegate,bytes32 delegationRecordHash,bytes32 reasonHash,uint256 nonce,uint64 deadline)"
                    ),
                    p.artistId,
                    p.delegate,
                    p.delegationRecordHash,
                    p.reasonHash,
                    nonce,
                    deadline
                )
            )
        );
    }

    function grant(
        State storage s,
        StreamArtistHashes.Environment memory e,
        D.Grant memory p,
        address grantor,
        uint256 nonce
    ) public returns (bytes32 record, bytes32 delta) {
        if (
            p.artistId == bytes32(0) || p.delegate == address(0) || p.delegate == grantor
                || p.capabilities == 0 || (p.capabilities & ~uint32(36)) != 0
                || p.expiresAt <= p.notBefore || block.timestamp >= p.expiresAt
        ) revert T.UnsupportedProfile();
        bytes32 scope = keccak256(abi.encode(p.artistId, p.delegate));
        bytes32 prior = s.current[scope];
        D.Record storage old = s.records[prior];
        // Future grants reserve the key too. A revoked/expired/exhausted grant can be replaced.
        if (
            old.grantor != address(0) && !old.revoked && block.timestamp < old.grant.expiresAt
                && (old.grant.maxUses == 0 || old.uses < old.grant.maxUses)
        ) revert D.ConflictingDelegation(prior);
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.artistId,
                p.delegate,
                p.collectionId,
                p.capabilities,
                p.notBefore,
                p.expiresAt,
                p.maxUses,
                p.constraintsHash,
                nonce
            )
        );
        if (s.records[record].grantor != address(0)) revert D.InvalidDelegation(record);
        s.records[record] = D.Record(p, grantor, nonce, 0, false, bytes32(0));
        s.current[scope] = record;
        delta = keccak256(abi.encode(scope, prior, record, s.records[record]));
    }

    function revoke(
        State storage s,
        StreamArtistHashes.Environment memory e,
        D.Revocation memory p,
        address signer,
        uint256 nonce,
        uint64 time
    ) public returns (bytes32 record, bytes32 delta) {
        D.Record storage item = s.records[p.delegationRecordHash];
        if (
            item.grantor == address(0) || item.revoked || item.grantor != signer
                || item.grant.artistId != p.artistId || item.grant.delegate != p.delegate
        ) revert D.InvalidDelegation(p.delegationRecordHash);
        record = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DELEGATION_REVOCATION_RECORD_V1"),
                e.chainId,
                e.registry,
                p.artistId,
                p.delegate,
                p.delegationRecordHash,
                signer,
                uint8(1),
                p.reasonHash,
                nonce,
                time
            )
        );
        item.revoked = true;
        item.revocationRecordHash = record;
        delta = keccak256(abi.encode(p.delegationRecordHash, item));
    }

    function lane(bytes32 artistId, address delegate) public pure returns (bytes32) {
        return keccak256(
            abi.encode(keccak256("6529STREAM_ARTIST_DELEGATE_NONCE_LANE_V1"), artistId, delegate)
        );
    }

    function active(D.Record memory item) public view returns (bool) {
        return item.grantor != address(0) && !item.revoked
            && block.timestamp >= item.grant.notBefore && block.timestamp < item.grant.expiresAt
            && (item.grant.maxUses == 0 || item.uses < item.grant.maxUses);
    }

    function consume(
        State storage s,
        bytes32 record,
        bytes32 artistId,
        uint256 collectionId,
        uint32 capability,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        address actor,
        bytes32 digest
    ) public returns (bytes32 replayLane, bytes32 delta) {
        D.Record storage item = s.records[record];
        if (!active(item)) revert D.DelegationUnavailable(record);
        if (
            item.grant.artistId != artistId
                || (item.grant.collectionId != 0 && item.grant.collectionId != collectionId)
        ) revert D.DelegationScope(record);
        if ((item.grant.capabilities & capability) == 0) {
            revert D.DelegationCapability(record, capability);
        }
        if (
            proof.signer != item.grant.delegate || proof.digest != digest
                || (proof.direct && (actor != proof.signer || a.signature.length != 0))
                || (!proof.direct && a.signature.length == 0 && proof.signer.code.length == 0)
        ) revert T.InvalidSignature();
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        replayLane = lane(artistId, proof.signer);
        if (proof.direct && a.nonce != s.hints[replayLane]) revert T.InvalidRecord();
        bytes32 availabilityDelta = s.availability[replayLane].consume(a.nonce);
        if (a.nonce == s.hints[replayLane]) {
            (, s.hints[replayLane]) = s.availability[replayLane].firstUnused();
        }
        ++item.uses;
        delta = keccak256(
            abi.encode(record, item, replayLane, a.nonce, s.hints[replayLane], availabilityDelta)
        );
    }
}
