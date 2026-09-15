// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistPayloadStore } from "./StreamArtistPayloadStore.sol";
import "./StreamArtistEstateState.sol";
import { StreamArtistStewardSanctionState } from "./StreamArtistStewardSanctionState.sol";
import "./StreamArtistIdentityResolutionState.sol";
import {
    StreamArtistDormancyTypes as Dorm
} from "../../interfaces/stream/artist/IStreamArtistDormancy.sol";

/// @notice Canonical dormant-authority lifecycle over appended fixed Identity storage.
/// @dev No caller-selected host, capability mask, witness or prior record can install authority.
library StreamArtistDormancyState {
    struct State {
        mapping(bytes32 => Dorm.Notice) notices;
        mapping(bytes32 => Dorm.Terminal) terminals;
        mapping(bytes32 => uint8) phases; // 1 notice, 2 cancelled, 3 completed
        mapping(bytes32 => bytes32) latestNotice;
        mapping(bytes32 => bytes32) terminalForNotice;
        mapping(bytes32 => bytes32) activation;
        mapping(bytes32 => R.TransitionState) transitions;
        mapping(bytes32 => bytes32) causeNotice;
        mapping(bytes32 => uint256) activity;
        uint64 inactivitySeconds;
        uint64 noticeSeconds;
        uint64 timingRevision;
        mapping(bytes32 => bool) timingActions;
    }
    event ArtistDormancyInitiated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        uint64 noticeEndsAt,
        bytes32 evidenceHash,
        string reasonURI,
        bytes32 actionId
    );
    event ArtistDormancyCancelled(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        address canceller,
        uint8 authorityClass,
        bytes32 cancellationHash
    );
    event ArtistDormancyCompleted(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        bytes32 indexed noticeHash,
        address vestedAuthority,
        uint8 authorityClass,
        uint32 effectiveCapabilities,
        uint64 stewardAppointedAtBlock,
        bytes32 completionHash,
        bytes32 actionId
    );

    /// @dev Called only after the real op33 mutation captured the canonical cause.
    function contest(
        State storage s,
        StreamArtistIdentityResolutionState.State storage resolutions,
        bytes32 id,
        bytes32 executed
    ) public returns (bytes32 delta) {
        bytes32 causeHash = resolutions.currentCause[id];
        Dismissal.Cause storage cause = resolutions.causes[causeHash];
        if (
            cause.causeHash != causeHash || cause.facts.artistId != id
                || cause.facts.enteredAt != block.timestamp
        ) revert Dorm.InvalidDormancy(id);
        if (cause.facts.priorStatus == 2) {
            bytes32 notice = s.latestNotice[id];
            Dorm.Notice storage n = s.notices[notice];
            if (
                cause.facts.authorityClass != 1 || s.phases[notice] != 1 || n.recordHash != notice
                    || n.incumbent != cause.facts.incumbent || s.causeNotice[causeHash] != 0
            ) revert Dorm.InvalidDormancy(id);
            s.causeNotice[causeHash] = notice;
            delta = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DORMANCY_CAUSE_NOTICE_V1"), causeHash, notice
                )
            );
        }
        R.TransitionState storage t = s.transitions[executed];
        if (t.recordHash != 0) {
            if (
                t.recordHash != executed || t.artistId != id
                    || cause.facts.executedTransitionHash != executed
            ) revert Dorm.InvalidDormancy(id);
            if (resolutions.closures[executed].dismissalRecordHash == 0 && t.contestedAt == 0) {
                t.contestedAt = uint64(block.timestamp);
                delta = keccak256(
                    abi.encode(
                        delta,
                        keccak256("6529STREAM_ARTIST_DORMANCY_TRANSITION_CONTEST_V1"),
                        causeHash,
                        t
                    )
                );
            }
        }
    }

    function timing(State storage s, bool inactivity)
        public
        view
        returns (uint64 value, uint64 floor, uint64 revision)
    {
        value = inactivity
            ? (s.inactivitySeconds == 0 ? uint64(730 days) : s.inactivitySeconds)
            : (s.noticeSeconds == 0 ? uint64(365 days) : s.noticeSeconds);
        floor = inactivity ? uint64(365 days) : uint64(180 days);
        revision = s.timingRevision == 0 ? 1 : s.timingRevision;
    }

    function initiationContext(
        State storage s,
        StreamArtistIdentityState.State storage identities,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Initiation memory p
    ) public view returns (Dorm.Context memory x) {
        T.Identity storage i = identities.identities[p.artistId];
        if (
            p.artistId == 0 || i.authorityClass != 1 || i.status != 1
                || i.authorityAddress == address(0)
                || identities.activeIdentity[i.authorityAddress] != p.artistId
                || p.evidenceHash == 0 || bytes(p.reasonURI).length == 0
                || bytes(p.reasonURI).length > 2048 || s.phases[s.latestNotice[p.artistId]] == 1
                || estate.pending[p.artistId] != 0
        ) revert Dorm.InvalidDormancy(p.artistId);
        (bytes32 active, uint64 ends,) = StreamArtistRotationState.activeWindowWithResolution(
            rotations, p.artistId, resolutions.closures[rotations.latestExecution[p.artistId]]
        );
        if (active != 0) revert R.ActiveAuthorityWindow(active, ends);
        (uint64 inactivity,, uint64 revision) = timing(s, true);
        (uint64 notice,,) = timing(s, false);
        if (
            block.timestamp < i.lastAuthorityActionAt
                || block.timestamp - i.lastAuthorityActionAt < inactivity
        ) revert Dorm.DormancyInactivity(i.lastAuthorityActionAt, inactivity);
        x.scopeHash = _scope(e, p.artistId, 41);
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_INITIATION_STATE_V1"),
                x.scopeHash,
                i,
                s.latestNotice[p.artistId],
                s.activity[p.artistId],
                inactivity,
                notice,
                revision,
                rotations.latestExecution[p.artistId],
                resolutions.latestResolution[p.artistId]
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_INITIATION_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                p
            )
        );
    }

    function initiate(
        State storage s,
        StreamArtistIdentityState.State storage identities,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Dorm.Initiation memory p,
        Contest.GovernanceWitness memory g,
        address executor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (c.operationId != 41) revert T.InvalidOperation(c.operationId);
        Dorm.Context memory x =
            initiationContext(s, identities, rotations, estate, resolutions, o.environment, p);
        _governance(c.actor, executor, g, x);
        T.Identity storage i = identities.identities[p.artistId];
        (uint64 inactivity,, uint64 revision) = timing(s, true);
        (uint64 notice,,) = timing(s, false);
        uint64 now_ = _now();
        uint64 end = StreamArtistEstateState.windowEnd(now_, notice);
        bytes32 hash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_NOTICE_V1"),
                o.environment.chainId,
                o.environment.registry,
                address(this),
                p,
                i.authorityAddress,
                now_,
                end,
                inactivity,
                notice,
                revision,
                i.lastAuthorityActionAt,
                s.activity[p.artistId],
                g.actionId,
                keccak256(abi.encode(g))
            )
        );
        if (s.notices[hash].recordHash != 0) revert Dorm.InvalidDormancy(p.artistId);
        bytes32 key = _consume(replay, o, "dormancy_notice", hash, hash);
        bytes32 action =
            _consume(replay, o, "first_governance", keccak256(abi.encode(g.actionId, x)), hash);
        s.notices[hash] = Dorm.Notice(
            hash,
            p,
            i.authorityAddress,
            now_,
            end,
            inactivity,
            notice,
            revision,
            i.lastAuthorityActionAt,
            s.activity[p.artistId],
            g.actionId,
            keccak256(abi.encode(g))
        );
        s.phases[hash] = 1;
        s.latestNotice[p.artistId] = hash;
        i.status = 2;
        m = StreamArtistIdentityState.Mutation(
            hash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_INITIATE_ARTIST_DORMANCY_V1"), p, g
                )
            ),
            keccak256(abi.encode(s.notices[hash], i)),
            keccak256(abi.encode(key, action))
        );
        emit ArtistDormancyInitiated(
            1, p.artistId, hash, end, p.evidenceHash, p.reasonURI, g.actionId
        );
    }

    function plan(
        StreamArtistStewardSanctionState.State storage grants,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistRotationState.State storage rotations,
        bytes32 id,
        address requested
    ) public view returns (Dorm.Plan memory p) {
        p.designation = StreamArtistSuccessionState.operativeDesignation(succession, rotations, id);
        p.directive = StreamArtistSuccessionState.operativeDirective(succession, rotations, id);
        p.guardian = StreamArtistRotationState.operativeGuardian(rotations, id);
        p.postSeconds = StreamArtistRotationState.rotationSeconds(rotations);
        if (rotations.guardians[p.guardian].terms.minContestSeconds > p.postSeconds) {
            p.postSeconds = rotations.guardians[p.guardian].terms.minContestSeconds;
        }
        p.standingTail = StreamArtistRotationState.standingSeconds(rotations);
        if (p.designation != 0) {
            p.authority = succession.designations[p.designation].terms.successor;
            p.authorityClass = 3;
            p.capabilities = StreamArtistEstateState.activationCapabilities(
                succession, p.designation, p.directive
            );
        } else {
            p.authority = requested;
            p.authorityClass = 4;
            // No sanction/economics grant is inferred from the appointing governance action.
            p.capabilities = 369;
            (bool sanctionGranted, bytes32 grant) =
                StreamArtistStewardSanctionState.current(grants, rotations, id);
            p.stewardGrantRecordHash = grant;
            if (sanctionGranted) p.capabilities |= uint32(8);
            if (p.directive != 0) {
                p.capabilities |= succession.directives[p.directive].terms.grantedCapabilities
                & uint32(2048);
                p.capabilities &= ~succession.directives[p.directive].terms.forbiddenCapabilities;
            }
        }
        if (p.authority == address(0) || p.authority != requested) revert Dorm.InvalidDormancy(id);
    }

    function completionContext(
        State storage s,
        StreamArtistStewardSanctionState.State storage grants,
        StreamArtistIdentityState.State storage identities,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        StreamArtistHashes.Environment memory e,
        Dorm.Completion memory p
    ) public view returns (Dorm.Context memory x, Dorm.Plan memory v) {
        Dorm.Notice storage n = s.notices[p.expectedNoticeHash];
        T.Identity storage i = identities.identities[p.artistId];
        if (
            p.expectedNoticeHash == 0 || n.recordHash != p.expectedNoticeHash
                || n.terms.artistId != p.artistId
                || s.latestNotice[p.artistId] != p.expectedNoticeHash
                || s.phases[p.expectedNoticeHash] != 1 || i.status != 2 || i.authorityClass != 1
                || i.authorityAddress != n.incumbent
                || identities.activeIdentity[n.incumbent] != p.artistId
                || i.lastAuthorityActionAt != n.priorLivenessAt
                || s.activity[p.artistId] != n.priorActivity || estate.pending[p.artistId] != 0
                || StreamArtistRotationState.pendingTransition(rotations, p.artistId) != 0
                || p.evidenceHash == 0
        ) revert Dorm.InvalidDormancy(p.artistId);
        if (block.timestamp < n.noticeEndsAt) revert Dorm.DormancyNoticeNotElapsed(n.noticeEndsAt);
        v = plan(grants, succession, rotations, p.artistId, p.vestedAuthority);
        if (identities.activeIdentity[v.authority] != 0 || v.authority == n.incumbent) {
            revert T.AddressAlreadyRegistered(v.authority);
        }
        x.scopeHash = _scope(e, p.artistId, 43);
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_STATE_V1"),
                x.scopeHash,
                n,
                i,
                v,
                s.activity[p.artistId],
                estate.delegationEpoch[p.artistId],
                rotations.latestExecution[p.artistId],
                resolutions.currentCause[p.artistId],
                resolutions.latestResolution[p.artistId]
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_INTENT_V1"),
                x.scopeHash,
                x.oldValueHash,
                p
            )
        );
    }

    function complete(
        State storage s,
        StreamArtistStewardSanctionState.State storage grants,
        StreamArtistIdentityState.State storage identities,
        StreamArtistRotationState.State storage rotations,
        StreamArtistEstateState.State storage estate,
        StreamArtistSuccessionState.State storage succession,
        StreamArtistIdentityResolutionState.State storage resolutions,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Dorm.Completion memory p,
        Contest.GovernanceWitness memory g,
        address executor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (c.operationId != 43) revert T.InvalidOperation(c.operationId);
        (Dorm.Context memory x, Dorm.Plan memory v) = completionContext(
            s, grants, identities, rotations, estate, succession, resolutions, o.environment, p
        );
        _governance(c.actor, executor, g, x);
        Dorm.Notice storage n = s.notices[p.expectedNoticeHash];
        T.Identity storage i = identities.identities[p.artistId];
        uint64 now_ = _now();
        if (block.number > type(uint64).max) revert T.InvalidRecord();
        uint64 appointment = v.authorityClass == 4 ? uint64(block.number) : 0;
        uint64 epoch = ++estate.delegationEpoch[p.artistId];
        Dorm.Terminal memory t = Dorm.Terminal(
            0,
            p.expectedNoticeHash,
            c.actor,
            v.authorityClass,
            now_,
            appointment,
            v,
            p.evidenceHash,
            g.actionId,
            keccak256(abi.encode(g)),
            epoch
        );
        bytes memory preimage = abi.encode(
            keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_V1"),
            o.environment.chainId,
            o.environment.registry,
            address(this),
            t
        );
        t.recordHash = keccak256(preimage);
        StreamArtistPayloadStore.preimage(t.recordHash, preimage);
        bytes32 key = _consume(replay, o, "dormancy_execution", p.expectedNoticeHash, t.recordHash);
        bytes32 action = _consume(
            replay, o, "second_governance", keccak256(abi.encode(g.actionId, x)), t.recordHash
        );
        s.terminals[t.recordHash] = t;
        s.terminalForNotice[p.expectedNoticeHash] = t.recordHash;
        s.phases[p.expectedNoticeHash] = 3;
        s.activation[p.artistId] = t.recordHash;
        s.transitions[t.recordHash] = R.TransitionState(
            p.artistId,
            t.recordHash,
            n.initiatedAt,
            n.noticeEndsAt,
            now_,
            StreamArtistEstateState.windowEnd(now_, v.postSeconds),
            0,
            2
        );
        rotations.latestTransition[p.artistId] = t.recordHash;
        rotations.latestExecution[p.artistId] = t.recordHash;
        rotations.retirement[p.artistId][n.incumbent] = t.recordHash;
        delete identities.activeIdentity[n.incumbent];
        identities.activeIdentity[v.authority] = p.artistId;
        i.authorityAddress = v.authority;
        i.authorityClass = v.authorityClass;
        i.status = 3;
        m = StreamArtistIdentityState.Mutation(
            t.recordHash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_REGISTRY_WRITE_COMPLETE_ARTIST_DORMANCY_V1"), p, g
                )
            ),
            keccak256(abi.encode(t, i, s.transitions[t.recordHash], epoch)),
            keccak256(abi.encode(key, action))
        );
        emit ArtistDormancyCompleted(
            1,
            p.artistId,
            p.expectedNoticeHash,
            v.authority,
            v.authorityClass,
            v.capabilities,
            appointment,
            t.recordHash,
            g.actionId
        );
    }

    /// @dev Called only after an actual owning writer authenticates the named signer.
    /// Delegate activity advances the dormancy clock without pretending to be principal activity.
    function activity(
        State storage s,
        StreamArtistIdentityState.State storage identities,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 id,
        address signer,
        uint8 class_
    ) public returns (bytes32 stateDelta, bytes32 replayDelta) {
        T.Identity storage i = identities.identities[id];
        if (
            i.authorityClass != 1 || signer == address(0)
                || (class_ != 1 && class_ != 2 && class_ != 3)
        ) return (0, 0);
        if (class_ == 1 && signer != i.authorityAddress) return (0, 0);
        bytes32 notice = s.latestNotice[id];
        uint64 observed = _now();
        if (s.phases[notice] != 1) {
            if (i.lastAuthorityActionAt == observed) return (0, 0);
            i.lastAuthorityActionAt = observed;
            return (
                keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ARTIST_DORMANCY_LIVENESS_V1"),
                        id,
                        signer,
                        class_,
                        observed
                    )
                ),
                bytes32(0)
            );
        }
        // A separate counter prevents same-timestamp liveness from being missed by governance.
        uint256 count = ++s.activity[id];
        i.lastAuthorityActionAt = _now();
        if (s.phases[notice] == 1) {
            Dorm.Terminal memory t;
            t.noticeHash = notice;
            t.actor = signer;
            t.authorityClass = class_;
            t.observedAt = _now();
            t.recordHash = keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_DORMANCY_CANCELLATION_V1"),
                    o.environment.chainId,
                    o.environment.registry,
                    address(this),
                    t,
                    count
                )
            );
            replayDelta = _consume(replay, o, "dormancy_cancellation", notice, t.recordHash);
            s.terminals[t.recordHash] = t;
            s.terminalForNotice[notice] = t.recordHash;
            s.phases[notice] = 2;
            if (i.status == 2) i.status = 1; // A genuine compromise remains contested until its own dismissal.
            emit ArtistDormancyCancelled(1, id, notice, signer, class_, t.recordHash);
        }
        stateDelta = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_ACTIVITY_V1"),
                id,
                count,
                notice,
                s.phases[notice],
                s.terminalForNotice[notice],
                i
            )
        );
    }

    /// @dev Canonical completing-action document, including the exact selected pre-grant even when withdrawn.
    function completionEvidence(Dorm.Completion memory p, Dorm.Plan memory v)
        public
        pure
        returns (bytes memory)
    {
        return abi.encode(
            keccak256("6529STREAM_ARTIST_DORMANCY_COMPLETION_EVIDENCE_V1"), uint16(1), p, v
        );
    }

    function _governance(
        address actor,
        address executor,
        Contest.GovernanceWitness memory g,
        Dorm.Context memory x
    ) private pure {
        if (
            actor != executor || executor == address(0) || g.actionClass != 1 || g.actionId == 0
                || g.proposer == address(0) || g.roleRevision == 0 || g.roleMutationHash == 0
                || g.scopeHash != x.scopeHash || g.oldValueHash != x.oldValueHash
                || g.newValueHash != x.newValueHash
        ) revert Dorm.InvalidDormancyGovernance();
    }

    function _scope(StreamArtistHashes.Environment memory e, bytes32 id, uint16 op)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_DORMANCY_SCOPE_V1"),
                e.chainId,
                e.registry,
                address(this),
                id,
                op
            )
        );
    }

    function _now() private view returns (uint64) {
        if (block.timestamp == 0 || block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
    }

    function _surface(string memory purpose) private pure returns (bytes32) {
        bytes32 p = keccak256(bytes(purpose));
        if (p == keccak256("dormancy_notice")) {
            return keccak256("identity_authority.replay.dormancy_notice_key");
        }
        if (p == keccak256("dormancy_cancellation")) {
            return keccak256("identity_authority.replay.dormancy_cancellation_key");
        }
        if (p == keccak256("dormancy_execution")) {
            return keccak256("identity_authority.replay.dormancy_execution_key");
        }
        if (p == keccak256("first_governance")) {
            return keccak256("identity_authority.replay.governance_action");
        }
        if (p == keccak256("second_governance")) {
            return keccak256("identity_authority.replay.second_governance_action");
        }
        revert T.InvalidRecord();
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        string memory purpose,
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
                _surface(purpose),
                scope
            )
        );
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(value, o.revision + 1, 1, 2);
    }
}
