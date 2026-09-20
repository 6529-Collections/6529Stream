// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistRecoveredIdentityHydrationTypes as IH
} from "../../interfaces/stream/artist/StreamArtistRecoveredIdentityHydrationTypes.sol";
import {
    StreamArtistRecoveredHydrationTypes as RH
} from "../../interfaces/stream/artist/StreamArtistRecoveredHydrationTypes.sol";
import {
    StreamArtistDelegationTypes as D
} from "../../interfaces/stream/artist/StreamArtistDelegationTypes.sol";
import { StreamArtistDelegationState as Delegations } from "./StreamArtistDelegationState.sol";
import { StreamArtistHashes as Hashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistRecoveredHydrationChronology as Chronology
} from "./StreamArtistRecoveredHydrationChronology.sol";

/// @notice Original delegation history within the complete recovered Identity inventory.
/// @dev The caller authenticates provenance and reads every body from the pinned source owner.
/// This validates retained history, not present grant liveness or new signature authority.
/// Original27 does not retain its reason, nonce or timestamp in D.Record: its native occurrence,
/// exact one-way replay cell and fixed-source typed body bind that record without invented data.
library StreamArtistRecoveredDelegationHydration {
    bytes32 private constant GRANT = keccak256("identity_authority.replay.delegation_key");
    bytes32 private constant REVOKE =
        keccak256("identity_authority.replay.one_way_delegation_revocation");
    bytes32 private constant NONCE = keccak256("identity_authority.replay.nonce_allocator");
    bytes32 private constant OBSERVED =
        keccak256("identity_authority.replay.authorization_consumed_digest");

    function validate(IH.Bundle memory b, RH.OwnerProvenance memory p) public pure {
        uint256 grants;
        uint256 revocations;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.artistId != b.artistId) continue;
            if (j.receipt.operation == 26) ++grants;
            if (j.receipt.operation == 27) {
                ++revocations;
                uint256 matched;
                for (uint256 k; k < b.delegations.length; ++k) {
                    IH.DelegationRow memory r = b.delegations[k];
                    if (!r.record.revoked || r.record.revocationRecordHash != j.receipt.recordHash)
                    {
                        continue;
                    }
                    if (
                        j.receipt.recordHash == 0 || j.receipt.collectionId != 0
                            || !Chronology.beforeOwner(p, 2, r.position.point, j.position.point)
                    ) revert IH.InvalidRecoveredIdentity(j.receipt.recordHash);
                    _alias(p, j.position.point, REVOKE, r.recordHash, j.receipt.recordHash);
                    ++matched;
                }
                if (matched != 1) revert IH.InvalidRecoveredIdentity(j.receipt.recordHash);
                for (uint256 k; k < i; ++k) {
                    if (
                        p.journal[k].receipt.operation == 27
                            && p.journal[k].receipt.recordHash == j.receipt.recordHash
                    ) revert IH.InvalidRecoveredIdentity(j.receipt.recordHash);
                }
            }
        }
        if (grants != b.delegations.length) revert IH.InvalidRecoveredIdentity(b.artistId);
        uint256 revoked;
        for (uint256 i; i < b.delegations.length; ++i) {
            IH.DelegationRow memory r = b.delegations[i];
            _grant(b.artistId, r, p);
            if (
                r.epoch > b.heads.delegationEpoch
                    || (i != 0
                        && (r.epoch < b.delegations[i - 1].epoch
                            || !Chronology.beforeOwner(
                                p, 2, b.delegations[i - 1].position.point, r.position.point
                            )))
            ) revert IH.InvalidRecoveredIdentity(r.recordHash);
            bytes32 latest = r.recordHash;
            for (uint256 j; j < b.delegations.length; ++j) {
                if (i != j && b.delegations[j].recordHash == r.recordHash) {
                    revert IH.InvalidRecoveredIdentity(r.recordHash);
                }
                if (j > i && b.delegations[j].record.grant.delegate == r.record.grant.delegate) {
                    latest = b.delegations[j].recordHash;
                }
            }
            if (r.current != latest) revert IH.InvalidRecoveredIdentity(r.recordHash);
            if (r.record.revoked) ++revoked;
        }
        if (revoked != revocations) revert IH.InvalidRecoveredIdentity(b.artistId);
        _nonces(b, p);
    }

    function _grant(bytes32 artistId, IH.DelegationRow memory r, RH.OwnerProvenance memory p)
        private
        pure
    {
        D.Record memory item = r.record;
        D.Grant memory g = item.grant;
        if (
            r.recordHash == 0 || g.artistId != artistId || item.grantor == address(0)
                || g.delegate == address(0) || g.delegate == item.grantor || g.capabilities == 0
                || (g.capabilities & ~uint32(1143)) != 0 || g.expiresAt <= g.notBefore
                || (g.maxUses != 0 && item.uses > g.maxUses)
                || item.revoked != (item.revocationRecordHash != 0)
        ) revert IH.InvalidRecoveredIdentity(r.recordHash);
        Chronology.validateOwnerPoint(p, 2, r.position.point);
        uint256 matched;
        for (uint256 i; i < p.journal.length; ++i) {
            RH.JournalEntry memory j = p.journal[i];
            if (j.receipt.operation != 26 || j.receipt.recordHash != r.recordHash) continue;
            if (
                j.receipt.artistId != artistId || j.receipt.collectionId != 0
                    || keccak256(abi.encode(j.position)) != keccak256(abi.encode(r.position))
            ) revert IH.InvalidRecoveredIdentity(r.recordHash);
            ++matched;
        }
        if (matched != 1) revert IH.InvalidRecoveredIdentity(r.recordHash);
        RH.OriginEnvironment memory origin;
        bool found;
        for (uint256 i; i < p.origins.length; ++i) {
            if (RH.originHash(p.origins[i]) != r.position.point.environmentHash) continue;
            if (found) revert IH.InvalidRecoveredIdentity(r.recordHash);
            origin = p.origins[i];
            found = true;
        }
        if (
            !found
                || keccak256(
                        abi.encode(
                            keccak256("6529STREAM_ARTIST_DELEGATION_RECORD_V1"),
                            origin.chainId,
                            origin.registry,
                            g.artistId,
                            g.delegate,
                            g.collectionId,
                            g.capabilities,
                            g.notBefore,
                            g.expiresAt,
                            g.maxUses,
                            g.constraintsHash,
                            item.nonce
                        )
                    ) != r.recordHash
        ) revert IH.InvalidRecoveredIdentity(r.recordHash);
        bytes32 digest = Delegations.grantDigest(
            Hashes.Environment(origin.chainId, origin.registry, origin.core, origin.manager),
            g,
            item.nonce
        );
        _alias(p, r.position.point, GRANT, r.recordHash, r.recordHash);
        _alias(p, r.position.point, NONCE, keccak256(abi.encode(artistId, item.nonce)), digest);
        _alias(p, r.position.point, OBSERVED, keccak256(abi.encode(artistId, digest)), digest);
    }

    function _alias(
        RH.OwnerProvenance memory p,
        RH.Point memory point,
        bytes32 surface,
        bytes32 scope,
        bytes32 commitment
    ) private pure {
        uint256 matched;
        for (uint256 i; i < p.aliases.length; ++i) {
            RH.ReplayAlias memory a = p.aliases[i];
            if (a.originHash != point.environmentHash || a.surface != surface || a.scope != scope) {
                continue;
            }
            if (
                a.ownerIndex != 2 || a.cell.kind != 1 || a.cell.status != 2
                    || a.cell.commitment != commitment
                    || a.cell.touchedRevision != point.ownerRevision
                    || keccak256(abi.encode(a.admittedAt)) != keccak256(abi.encode(point))
            ) revert IH.InvalidRecoveredIdentity(scope);
            ++matched;
        }
        if (matched != 1) revert IH.InvalidRecoveredIdentity(scope);
    }

    function _nonces(IH.Bundle memory b, RH.OwnerProvenance memory p) private pure {
        if (
            p.eras.length == 0
                || b.nonces.length != p.eras[p.eras.length - 1].checkpoint.nonceIndexCount
                || b.nonces.length > RH.MAX_NONCE_INDICES
        ) revert IH.InvalidRecoveredIdentity(b.artistId);
        for (uint256 i; i < b.nonces.length; ++i) {
            IH.NonceLane memory n = b.nonces[i];
            if (
                n.key == 0 || (n.kind != 1 && n.kind != 2 && n.kind != 4 && n.kind != 5)
                    || n.words.length == 0 || n.words.length > RH.MAX_NONCE_PREFIXES
            ) revert IH.InvalidRecoveredIdentity(n.key);
            for (uint256 j; j < i; ++j) {
                if (b.nonces[j].kind == n.kind && b.nonces[j].key == n.key) {
                    revert IH.InvalidRecoveredIdentity(n.key);
                }
            }
            if (n.kind != 2) continue;
            uint256 uses;
            for (uint256 j; j < b.delegations.length; ++j) {
                if (Delegations.lane(b.artistId, b.delegations[j].record.grant.delegate) == n.key) {
                    uses += b.delegations[j].record.uses;
                }
            }
            if (uses == 0 || _consumed(n) != uses) revert IH.InvalidRecoveredIdentity(n.key);
        }
        for (uint256 i; i < b.delegations.length; ++i) {
            if (b.delegations[i].record.uses == 0) continue;
            bytes32 key = Delegations.lane(b.artistId, b.delegations[i].record.grant.delegate);
            bool found;
            for (uint256 j; j < b.nonces.length; ++j) {
                if (b.nonces[j].kind == 2 && b.nonces[j].key == key) found = true;
            }
            if (!found) revert IH.InvalidRecoveredIdentity(key);
        }
    }

    /// @dev Kind2 is populated only by successful delegated consumption. Original54 modifies
    /// the principal kind1 tree (or only digest guards), so it cannot inflate this use count.
    function _consumed(IH.NonceLane memory n) private pure returns (uint256 count) {
        for (uint256 i; i < n.words.length; ++i) {
            if (
                n.words[i].prefix > type(uint248).max || n.words[i].words[0] == 0
                    || n.words[i].exhausted != n.words[0].exhausted
            ) revert IH.InvalidRecoveredIdentity(n.key);
            for (uint256 j; j < i; ++j) {
                if (n.words[j].prefix == n.words[i].prefix) {
                    revert IH.InvalidRecoveredIdentity(n.key);
                }
            }
            uint256 word = n.words[i].words[0];
            while (word != 0) {
                word &= word - 1;
                ++count;
            }
        }
    }
}
