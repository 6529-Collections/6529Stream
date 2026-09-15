// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistAuthorityCheckpoint.sol";

import { StreamArtistIdentityState } from "./StreamArtistIdentityState.sol";
import { StreamArtistRotationState } from "./StreamArtistRotationState.sol";
import { StreamArtistHashes } from "./StreamArtistHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistRotationTypes as R
} from "../../interfaces/stream/artist/StreamArtistRotationTypes.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";
import {
    IStreamArtistStewardSanctionGrant as SG
} from "../../interfaces/stream/artist/IStreamArtistStewardSanctionGrant.sol";

/// @notice Appended Identity-owned op19 records; the linked worker has no independent authority.
/// @dev Signature bytes use Identity's existing immutable record-keyed storage. The returned grant
///      never overrides directives and does not confer any successor, delegate or steward power itself.
library StreamArtistStewardSanctionState {
    struct State {
        mapping(bytes32 => SG.GrantRecord) records;
        mapping(bytes32 => bytes32) stable;
        mapping(bytes32 => bytes32) candidate;
    }
    event StewardSanctionGrantRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        bool granted,
        bytes32 statementHash,
        uint8 authorityClass,
        uint256 nonce,
        uint64 signedAt,
        bytes32 grantRecordHash
    );

    function digest(
        StreamArtistHashes.Environment memory e,
        SG.Grant memory p,
        T.Authorization memory a
    ) public pure returns (bytes32) {
        return StreamArtistHashes.typed(
            e,
            keccak256(
                abi.encode(
                    bytes32(0xb48c9f264543966930485ab31e707d91b18c4f9e8644f8dd4a8cbb38c2aea9f2),
                    p.artistId,
                    p.granted,
                    p.statementHash,
                    a.nonce,
                    a.time
                )
            )
        );
    }

    function recordHash(
        StreamArtistHashes.Environment memory e,
        SG.Grant memory p,
        T.Authorization memory a,
        address signer
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                bytes32(0x8e938520f64582e71a67db13c1e692945f6168798f060033fffca4ad733798b4),
                e.chainId,
                e.registry,
                p.artistId,
                p.granted,
                p.statementHash,
                signer,
                uint8(1),
                a.nonce,
                a.time
            )
        );
    }

    function operative(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bytes32) {
        bytes32 base = s.stable[artistId];
        bytes32 candidate = s.candidate[artistId];
        if (
            candidate != bytes32(0)
                && StreamArtistRotationState.eligible(
                    rotations, artistId, s.records[candidate].provisional
                ) && (base == bytes32(0) || s.records[candidate].nonce > s.records[base].nonce)
        ) {
            return candidate;
        }
        return base;
    }

    function current(
        State storage s,
        StreamArtistRotationState.State storage rotations,
        bytes32 artistId
    ) public view returns (bool granted, bytes32 grantRecordHash) {
        grantRecordHash = operative(s, rotations, artistId);
        granted = s.records[grantRecordHash].terms.granted;
    }

    function record(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        SG.Grant memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.Closure memory empty;
        return _record(s, identity, rotations, replay, o, c, p, a, proof, empty);
    }

    function recordWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        SG.Grant memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Dismissal.Closure memory closure
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _record(s, identity, rotations, replay, o, c, p, a, proof, closure);
    }

    function _record(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        SG.Grant memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Dismissal.Closure memory closure
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            p.artistId == bytes32(0) || p.statementHash == bytes32(0) || c.operationId != 19
                || principal.authorityClass != 1 || (principal.status != 1 && principal.status != 2)
        ) {
            revert SG.InvalidStewardSanctionGrant(p.artistId);
        }
        if (a.time == 0 || a.time > block.timestamp || (proof.direct && a.time != block.timestamp))
        {
            revert T.InvalidTimestamp(a.time);
        }
        bytes32 hash = recordHash(o.environment, p, a, proof.signer);
        if (s.records[hash].recordHash != bytes32(0)) revert T.InvalidRecord();
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            digest(o.environment, p, a),
            hash,
            principal.authorityAddress
        );
        bytes32 base = operative(s, rotations, p.artistId);
        R.ProvisionalAssociation memory association_ =
            StreamArtistRotationState.associationWithResolution(rotations, p.artistId, closure);
        SG.GrantRecord memory item =
            SG.GrantRecord(hash, p, proof.signer, 1, a.nonce, a.time, association_);
        s.records[hash] = item;
        if (association_.transitionRecordHash == bytes32(0)) {
            s.stable[p.artistId] =
                base == bytes32(0) || a.nonce > s.records[base].nonce ? hash : base;
            delete s.candidate[p.artistId];
        } else {
            s.stable[p.artistId] = base;
            bytes32 candidate = s.candidate[p.artistId];
            if (
                candidate == bytes32(0)
                    || s.records[candidate].provisional.transitionRecordHash
                        != association_.transitionRecordHash || a.nonce > s.records[candidate].nonce
            ) s.candidate[p.artistId] = hash;
        }
        bytes32 key = _consume(replay, o, hash);
        m.record = hash;
        m.action = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_RECORD_STEWARD_SANCTION_GRANT_V1"),
                p,
                a,
                proof
            )
        );
        m.state = keccak256(
            abi.encode(m.state, base, item, s.stable[p.artistId], s.candidate[p.artistId])
        );
        m.replay = keccak256(abi.encode(m.replay, key, hash));
        emit StewardSanctionGrantRecorded(
            1, p.artistId, proof.signer, p.granted, p.statementHash, 1, a.nonce, a.time, hash
        );
        if (closure.dismissalRecordHash != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, closure));
        }
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 record_
    ) private returns (bytes32 key) {
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_OWNER_REPLAY_KEY_V2"),
                o.environment.chainId,
                o.environment.registry,
                o.coordinator,
                o.archive,
                address(this),
                o.domain,
                keccak256("identity_authority.replay.grant_chain"),
                keccak256(abi.encode(record_))
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(record_, o.revision + 1, 1, 2);
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
