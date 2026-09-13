// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRotationState.sol";
import "./StreamArtistIdentityState.sol";
import "./StreamArtistAuthorityPolicy.sol";
import "./StreamArtistRotationHashes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistEstateTypes as Estate
} from "../../interfaces/stream/artist/StreamArtistEstateTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

/// @notice Linked guardian mechanics over the sole Identity-owned rotation storage.
library StreamArtistGuardianState {
    event ArtistGuardianSetUpdated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address[] guardians,
        uint32 approvalThreshold,
        uint64 minContestSeconds,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 guardianSetRecordHash
    );

    function setGuardians(
        StreamArtistRotationState.State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.GuardianSet memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Dismissal.Closure memory closure
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (
            p.guardians.length > 8 || p.minContestSeconds > 30 days
                || (p.guardians.length == 0
                        ? p.approvalThreshold != 0
                        : p.approvalThreshold == 0 || p.approvalThreshold > p.guardians.length)
        ) {
            revert R.InvalidGuardianSet();
        }
        address previous;
        for (uint256 i; i < p.guardians.length; ++i) {
            if (p.guardians[i] <= previous) revert R.InvalidGuardianSet();
            previous = p.guardians[i];
        }
        if (a.time == 0 || a.time > block.timestamp || (proof.direct && a.time != block.timestamp))
        {
            revert T.InvalidRecord();
        }
        bytes32 prior = StreamArtistRotationState.operativeGuardian(s, p.artistId);
        uint8 authorityClass = identity.identities[p.artistId].authorityClass;
        if (authorityClass == 3) {
            Estate.AuthorityCapabilities memory rights =
                StreamArtistAuthorityPolicy.capabilities(p.artistId);
            if ((rights.effectiveCapabilities & 2048) == 0) {
                (, bytes32 artistGuardians,) =
                    StreamArtistRotationState.transitionStanding(s, rights.activationRecordHash);
                R.GuardianRecord storage lifetime = s.guardians[artistGuardians];
                if (artistGuardians != bytes32(0) && lifetime.authorityClass != 1) {
                    revert R.InvalidGuardianSet();
                }
                for (uint256 i; i < lifetime.terms.guardians.length; ++i) {
                    bool found;
                    for (uint256 j; j < p.guardians.length; ++j) {
                        if (p.guardians[j] == lifetime.terms.guardians[i]) found = true;
                    }
                    if (!found) revert Estate.EstateCapabilityUnavailable(p.artistId, 2048);
                }
            }
        }
        bytes32 record = StreamArtistRotationHashes.guardianRecord(o.environment, p, a);
        if (s.guardians[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            StreamArtistRotationHashes.guardianDigest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        R.ProvisionalAssociation memory pending_ =
            StreamArtistRotationState.associationWithResolution(s, p.artistId, closure);
        R.GuardianRecord memory item = R.GuardianRecord(
            record, p, proof.signer, authorityClass, a.nonce, a.time, prior, pending_
        );
        s.guardians[record] = item;
        // Checkpoint only an actually eligible head; time-only reads also select it before this write.
        s.stableGuardian[p.artistId] = prior;
        bytes32 candidate = s.provisionalGuardian[p.artistId];
        if (pending_.transitionRecordHash == bytes32(0)) {
            if (prior == bytes32(0) || a.nonce > s.guardians[prior].nonce) {
                s.stableGuardian[p.artistId] = record;
            }
            s.provisionalGuardian[p.artistId] = bytes32(0);
        } else if (
            (prior == bytes32(0) || a.nonce > s.guardians[prior].nonce)
                && (candidate == bytes32(0)
                    || s.guardians[candidate].provisional.transitionRecordHash
                        != pending_.transitionRecordHash
                    || a.nonce > s.guardians[candidate].nonce)
        ) {
            s.provisionalGuardian[p.artistId] = record;
        }
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.guardian_set_chain"),
            keccak256(abi.encode(p.artistId, a.nonce)),
            record
        );
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof));
        m.state = keccak256(
            abi.encode(
                m.state, item, s.stableGuardian[p.artistId], s.provisionalGuardian[p.artistId]
            )
        );
        m.replay = keccak256(abi.encode(m.replay, key, record));
        emit ArtistGuardianSetUpdated(
            1,
            p.artistId,
            p.guardians,
            p.approvalThreshold,
            p.minContestSeconds,
            authorityClass,
            a.nonce,
            a.time,
            record
        );

        if (closure.dismissalRecordHash != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, closure));
        }
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
    }
}
