// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";
import {
    StreamArtistRepudiationTypes as RP
} from "../../interfaces/stream/artist/IStreamArtistAttributionRepudiation.sol";

import "./StreamArtistAuthorityCheckpoint.sol";
import { StreamArtistRotationAcceptance } from "./StreamArtistRotationAcceptance.sol";
import { StreamArtistAuthorityRecordEvents } from "./StreamArtistAuthorityRecordEvents.sol";
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import {
    StreamArtistRecoveredAuthorityPreimages
} from "./StreamArtistRecoveredAuthorityPreimages.sol";
import "./StreamArtistTransitionReads.sol";
import "./StreamArtistGuardianState.sol";

import "./StreamArtistIdentityState.sol";
import "./StreamArtistRotationHashes.sol";
import "../../interfaces/stream/artist/IStreamArtistRotationOwner.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "../../interfaces/stream/artist/StreamArtistIdentityDismissalTypes.sol";

import { StreamArtistRotationState as Original } from "./StreamArtistRotationState.sol";

/// @notice Fixed typed worker preserving the original validation and caller context.
library StreamArtistRotationExecution {
    event ArtistAddressRotated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed oldAddress,
        address indexed newAddress,
        uint8 authorityClass,
        bytes32 reasonHash,
        bytes32 rotationRecordHash
    );

    function execute(
        Original.State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        R.RotationRecord storage r = _pending(s, artistId, expected);
        T.Identity storage principal = identity.identities[artistId];
        if (
            !StreamArtistAuthorityPolicy.ordinary(principal.authorityClass, principal.status, false)
                || principal.authorityAddress != r.terms.oldAddress
                || identity.activeIdentity[r.terms.oldAddress] != artistId
        ) revert T.InvalidIdentity(artistId);
        if (
            block.timestamp < r.transition.contestEndsAt
                && (r.approvalThreshold == 0 || r.guardianApprovals < r.approvalThreshold)
        ) {
            revert R.RotationNotExecutable(expected);
        }
        if (identity.activeIdentity[r.terms.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(r.terms.newAddress);
        }
        bytes32 executionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.rotation_execution_key"),
            expected,
            expected
        );
        bytes32 retirementKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.standing_retirement"),
            keccak256(abi.encode(artistId, r.terms.oldAddress, expected)),
            expected
        );
        uint64 observed = _now();
        r.transition.executedAt = observed;
        r.transition.postWindowEndsAt = _windowEnd(observed, r.effectiveWindow);
        r.transition.phase = 2;
        s.latestExecution[artistId] = expected;
        StreamArtistRecoveredAuthorityPreimages.rotation(o.environment, r);
        s.retirement[artistId][r.terms.oldAddress] = expected;
        delete s.pending[artistId];
        delete identity.activeIdentity[r.terms.oldAddress];
        identity.activeIdentity[r.terms.newAddress] = artistId;
        principal.authorityAddress = r.terms.newAddress;
        // Permissionless execution and guardian approvals do not establish artist activity.
        // The owner separately records finding-only activity for an authenticated current-principal
        // veto; neither veto branch is a living-principal estate cancellation.
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, expected, c.actor)),
            keccak256(abi.encode(r.transition, principal, r.terms.oldAddress, r.terms.newAddress)),
            keccak256(abi.encode(executionKey, retirementKey, expected))
        );
        emit ArtistAddressRotated(
            1,
            artistId,
            r.terms.oldAddress,
            r.terms.newAddress,
            principal.authorityClass,
            r.terms.reasonHash,
            expected
        );
        StreamArtistAuthorityRecordEvents.rotation(
            o.environment, c.actor, r.transition, principal.authorityClass
        );
    }

    function _pending(Original.State storage s, bytes32 artistId, bytes32 expected)
        private
        view
        returns (R.RotationRecord storage r)
    {
        if (expected == bytes32(0) || s.pending[artistId] != expected) {
            revert R.InvalidRotation(expected);
        }
        r = s.rotations[expected];
        if (
            r.terms.artistId != artistId || r.transition.phase != 1 || r.transition.contestedAt != 0
        ) {
            revert R.InvalidRotation(expected);
        }
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }

    function _windowEnd(uint64 observed, uint64 duration) private pure returns (uint64) {
        if (uint256(observed) + duration > type(uint64).max) {
            revert R.InvalidArtistWindow(keccak256("ARTIST_ROTATION_CONTEST_SECONDS"));
        }
        return observed + duration;
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
