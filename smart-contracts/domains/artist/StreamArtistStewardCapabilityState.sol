// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDormancyState.sol";
import {
    StreamArtistStewardCapabilityTypes as SC
} from "../../interfaces/stream/artist/IStreamArtistStewardCapabilities.sol";

/// @notice Additive op59 history. The original op43 appointment/plan is never rewritten.
library StreamArtistStewardCapabilityState {
    struct State {
        mapping(bytes32 => SC.Record) records;
        mapping(bytes32 => bytes32) head;
        mapping(bytes32 => uint32) added;
    }
    event StewardCapabilitiesGranted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed appointmentHash,
        bytes32 indexed recordHash,
        address steward,
        uint32 addedCapabilities,
        uint32 effectiveCapabilities,
        bytes32 actionId,
        bytes32 previousGrantHash
    );

    function effective(State storage s, bytes32 appointment, uint32 original)
        internal
        view
        returns (uint32)
    {
        uint32 added = s.added[appointment];
        if (added & ~uint32(12) != 0 || original & uint32(2) != 0) {
            revert SC.InvalidStewardCapabilityGrant(appointment);
        }
        return original | added;
    }

    function context(
        State storage s,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistHashes.Environment memory e,
        SC.Grant memory p
    ) public view returns (SC.Context memory x) {
        T.Identity storage principal = identity.identities[p.artistId];
        bytes32 appointment = dormancy.activation[p.artistId];
        Dorm.Terminal storage t = dormancy.terminals[appointment];
        bytes32 directive =
            StreamArtistSuccessionState.operativeDirective(succession, rotations, p.artistId);
        uint32 forbidden = succession.directives[directive].terms.forbiddenCapabilities;
        uint32 current = effective(s, appointment, t.plan.capabilities);
        if (
            p.artistId == 0 || appointment == 0 || p.expectedAppointmentHash != appointment
                || t.recordHash != appointment || t.appointmentBlock == 0
                || t.plan.authorityClass != 4 || dormancy.phases[t.noticeHash] != 3
                || dormancy.terminalForNotice[t.noticeHash] != appointment
                || dormancy.notices[t.noticeHash].terms.artistId != p.artistId
                || principal.authorityClass != 4 || principal.status != 3
                || principal.authorityAddress == address(0)
                || principal.authorityAddress != p.expectedSteward
                || identity.activeIdentity[p.expectedSteward] != p.artistId
                || directive != t.plan.directive || p.expectedDirectiveHash != directive
                || p.expectedGrantHead != s.head[appointment] || current != p.expectedCapabilities
                || current & forbidden != 0 || p.addedCapabilities == 0
                || p.addedCapabilities & ~uint32(12) != 0 || p.addedCapabilities & current != 0
                || p.addedCapabilities & forbidden != 0 || p.reasonHash == 0
                || bytes(p.reasonURI).length == 0 || bytes(p.reasonURI).length > 2048
        ) revert SC.InvalidStewardCapabilityGrant(p.artistId);
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_SCOPE_V1"),
                e.chainId,
                e.registry,
                address(this),
                p.artistId,
                uint16(59)
            )
        );
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_STATE_V1"),
                x.scopeHash,
                principal,
                t,
                directive,
                succession.directives[directive],
                s.head[appointment],
                current,
                rotations.latestExecution[p.artistId]
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                p
            )
        );
    }

    function grant(
        State storage s,
        StreamArtistDormancyState.State storage dormancy,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        StreamArtistSuccessionState.State storage succession,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        SC.Grant memory p,
        SC.Witness memory w,
        address executor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (c.operationId != 59) revert T.InvalidOperation(c.operationId);
        SC.Context memory x =
            context(s, dormancy, identity, rotations, succession, o.environment, p);
        if (
            c.actor != executor || executor == address(0) || w.actionId == 0
                || w.proposer == address(0) || w.executionCaller == address(0)
                || w.guardianCommitment == 0 || w.selectorConfigHash == 0 || w.selectorRevision == 0
                || keccak256(abi.encode(x)) != keccak256(abi.encode(w.context))
                || block.timestamp < w.notBefore || block.timestamp > w.expiresAfter
                || block.timestamp > type(uint64).max
        ) revert SC.InvalidStewardGrantGovernance();
        SC.Record memory saved = SC.Record(
            0, p, w, executor, p.expectedCapabilities | p.addedCapabilities, uint64(block.timestamp)
        );
        saved.recordHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_STEWARD_CAPABILITY_GRANT_V1"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                saved
            )
        );
        if (s.records[saved.recordHash].recordHash != 0) {
            revert SC.InvalidStewardCapabilityGrant(p.artistId);
        }
        bytes32 recordKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.steward_capability_grant"),
            saved.recordHash,
            saved.recordHash
        );
        bytes32 actionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.steward_capability_grant_action"),
            keccak256(abi.encode(w.actionId, x)),
            saved.recordHash
        );
        s.records[saved.recordHash] = saved;
        s.head[p.expectedAppointmentHash] = saved.recordHash;
        s.added[p.expectedAppointmentHash] |= p.addedCapabilities;
        m = StreamArtistIdentityState.Mutation(
            saved.recordHash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_GRANT_STEWARD_CAPABILITIES_V1"),
                    p,
                    w
                )
            ),
            keccak256(abi.encode(saved, s.added[p.expectedAppointmentHash])),
            keccak256(abi.encode(recordKey, actionKey))
        );
        emit StewardCapabilitiesGranted(
            1,
            p.artistId,
            p.expectedAppointmentHash,
            saved.recordHash,
            p.expectedSteward,
            p.addedCapabilities,
            saved.effectiveCapabilities,
            w.actionId,
            p.expectedGrantHead
        );
        StreamArtistDormancyRecordEvents.grant(o.environment, saved);
    }

    function contextEncoded(
        State storage s,
        StreamArtistDormancyState.State storage d,
        StreamArtistIdentityState.State storage i,
        StreamArtistRotationState.State storage r,
        StreamArtistSuccessionState.State storage su,
        StreamArtistHashes.Environment memory e,
        SC.Grant memory p
    ) public view returns (bytes memory) {
        return abi.encode(context(s, d, i, r, su, e, p));
    }

    function recordEncoded(State storage s, bytes32 hash) public view returns (bytes memory) {
        return abi.encode(s.records[hash]);
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 value
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
                surface,
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(value, o.revision + 1, 1, 2);
    }
}
