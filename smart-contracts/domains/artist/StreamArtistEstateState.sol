// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "./StreamArtistEstateHashes.sol";
import "./StreamArtistSuccessionState.sol";
import "../../interfaces/stream/artist/IStreamArtistEstateActivation.sol";

/// @notice Linked estate mechanics over appended Identity storage only.
/// @dev The typed owner retains authentication, actual coverage admission and one semantic commit.
library StreamArtistEstateState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    struct State {
        mapping(bytes32 => Estate.RequestRecord) requests;
        mapping(bytes32 => uint8) phases; // 1 pending, 2 executed, 3 permanently cancelled
        mapping(bytes32 => Estate.ExecutionFacts) executions;
        mapping(bytes32 => R.TransitionState) transitions;
        mapping(bytes32 => bytes32) pending;
        mapping(bytes32 => bytes32) authorityActivation;
        mapping(bytes32 => uint256) livingActivity;
        mapping(bytes32 => StreamArtistNonceAvailability.Index) nonceAvailability;
        mapping(bytes32 => uint256) nonceHints;
        mapping(bytes32 => uint64) delegationEpoch;
        mapping(bytes32 => uint64) grantEpoch;
        uint64 noticeSeconds;
        uint64 noticeRevision;
        mapping(bytes32 => bool) timingActions;
    }

    event ArtistEstateActivationRequested(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint64 requestedAt,
        uint64 noticeEndsAt,
        uint256 nonce,
        bytes32 evidenceHash,
        bytes32 activationRecordHash
    );
    event ArtistEstateActivationCancelled(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed canceller,
        uint8 authorityClass,
        bytes32 activationRecordHash
    );
    event ArtistSuccessionActivated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed successor,
        uint8 authorityClass,
        uint32 effectiveCapabilities,
        bytes32 activationEvidenceHash,
        bytes32 governanceActionId
    );

    function timing(State storage s) public view returns (uint64, uint64, uint64) {
        return (
            s.noticeSeconds == 0 ? uint64(180 days) : s.noticeSeconds,
            90 days,
            s.noticeRevision == 0 ? uint64(1) : s.noticeRevision
        );
    }

    function nonceLane(bytes32 artistId, address successor) public pure returns (bytes32) {
        return keccak256(abi.encode("estate_activation", artistId, successor));
    }

    function request(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Estate.Request memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Estate.RequestFacts memory facts
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            principal.status != 1 || principal.authorityClass != 1
                || principal.authorityAddress == address(0)
                || identity.activeIdentity[principal.authorityAddress] != p.artistId
        ) {
            revert T.InvalidIdentity(p.artistId);
        }
        if (s.pending[p.artistId] != bytes32(0)) {
            revert Estate.EstateActivationPending(s.pending[p.artistId]);
        }
        if (
            p.successor == address(0) || p.successor == principal.authorityAddress
                || p.evidenceHash == bytes32(0) || p.selectedCoverageHash == bytes32(0)
                || facts.envelopeHash == bytes32(0) || p.expectedDesignationRecordHash == bytes32(0)
                || p.expectedDesignationRecordHash != facts.designationRecordHash
        ) {
            revert Estate.InvalidEstateActivation(bytes32(0));
        }
        if (identity.activeIdentity[p.successor] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.successor);
        }
        (uint64 duration,, uint64 revision) = timing(s);
        if (
            facts.noticeSeconds != duration || facts.noticeRevision != revision
                || facts.postContestSeconds < 72 hours || facts.standingTailSeconds < 30 days
                || facts.rotationTimingRevision == 0
        ) revert T.InvalidRecord();
        uint64 now_ = _now();
        uint64 endsAt = windowEnd(now_, duration);
        bytes32 record = StreamArtistEstateHashes.record(o.environment, p, a.nonce, now_, endsAt);
        if (s.requests[record].recordHash != bytes32(0)) revert T.InvalidRecord();
        bytes32 replayDelta = _authorize(s, replay, o, c, p, a, proof, record);
        Estate.RequestRecord storage item = s.requests[record];
        item.recordHash = record;
        item.terms = p;
        item.authorization = a;
        item.incumbent = principal.authorityAddress;
        item.designationRecordHash = facts.designationRecordHash;
        item.pairedDirectiveRecordHash = facts.pairedDirectiveRecordHash;
        item.forbiddenDirectiveRecordHash = facts.forbiddenDirectiveRecordHash;
        item.guardianRecordHash = facts.guardianRecordHash;
        item.envelopeHash = facts.envelopeHash;
        item.requestedAt = now_;
        item.noticeEndsAt = endsAt;
        item.noticeSeconds = duration;
        item.noticeRevision = revision;
        item.postContestSeconds = facts.postContestSeconds;
        item.standingTailSeconds = facts.standingTailSeconds;
        item.rotationTimingRevision = facts.rotationTimingRevision;
        item.livingActivity = s.livingActivity[p.artistId];
        s.phases[record] = 1;
        s.pending[p.artistId] = record;
        s.transitions[record] = R.TransitionState(p.artistId, record, now_, endsAt, 0, 0, 0, 1);
        rotations.latestTransition[p.artistId] = record;
        m = StreamArtistIdentityState.Mutation(
            record,
            keccak256(abi.encode(p, a, proof, facts)),
            keccak256(
                abi.encode(item, s.transitions[record], rotations.latestTransition[p.artistId])
            ),
            replayDelta
        );
        emit ArtistEstateActivationRequested(
            1, p.artistId, p.successor, now_, endsAt, a.nonce, p.evidenceHash, record
        );
    }

    function _authorize(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Estate.Request memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 record
    ) private returns (bytes32) {
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        bytes32 digest = StreamArtistEstateHashes.digest(o.environment, p, a);
        bytes32 lane = nonceLane(p.artistId, p.successor);
        if (
            proof.signer != p.successor || proof.digest != digest
                || (proof.direct
                    && (c.actor != p.successor
                        || a.signature.length != 0
                        || a.nonce != s.nonceHints[lane]))
                || (!proof.direct && a.signature.length == 0 && p.successor.code.length == 0)
        ) {
            revert T.InvalidSignature();
        }
        if (a.signature.length > 4096) revert T.BoundExceeded(a.signature.length, 4096);
        bytes32 deny = _key(
            o,
            keccak256("identity_authority.replay.digest_revocation"),
            keccak256(abi.encode(p.artistId, digest))
        );
        if (replay[deny].status != 0) revert T.Replay(deny);
        bytes32 nonceKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.nonce_allocator"),
            keccak256(abi.encode("estate_activation", p.artistId, p.successor, a.nonce)),
            digest
        );
        bytes32 observed = _key(
            o,
            keccak256("identity_authority.replay.authorization_consumed_digest"),
            keccak256(abi.encode(p.artistId, digest))
        );
        if (replay[observed].status == 0) {
            replay[observed] = T.ReplayCell(digest, o.revision + 1, 1, 2);
        }
        bytes32 indexDelta = s.nonceAvailability[lane].consume(a.nonce);
        if (a.nonce == s.nonceHints[lane]) {
            (, s.nonceHints[lane]) = s.nonceAvailability[lane].firstUnused();
        }
        bytes32 requestKey = _consume(
            replay, o, keccak256("identity_authority.replay.activation_request_key"), record, record
        );
        return keccak256(
            abi.encode(nonceKey, digest, observed, replay[observed], indexDelta, requestKey, record)
        );
    }

    /// @notice Called once by the owner after a successful current living-principal action.
    /// @dev Failed actions roll this back with the owner's commit/archive transaction.
    function livingAction(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address verifiedSigner
    ) public returns (bytes32 stateDelta, bytes32 replayDelta) {
        T.Identity storage principal = identity.identities[artistId];
        if (
            principal.authorityClass != 1 || principal.authorityAddress != verifiedSigner
                || verifiedSigner == address(0)
        ) return (bytes32(0), bytes32(0));
        bytes32 pending = s.pending[artistId];
        // Only a pending request needs a separate same-block marker. Ordinary historical
        // liveness remains Identity.lastAuthorityActionAt and no unrelated state is rewritten.
        if (pending == bytes32(0)) return (bytes32(0), bytes32(0));
        uint256 activity = ++s.livingActivity[artistId];
        replayDelta = _cancel(s, replay, o, artistId, pending, verifiedSigner, 1);
        stateDelta = keccak256(abi.encode(artistId, activity, pending));
    }

    function cancel(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        T.Identity storage principal = identity.identities[artistId];
        if (
            principal.authorityClass != 1 || principal.authorityAddress != c.actor
                || (principal.status != 1 && principal.status != 4)
        ) revert T.Unauthorized(c.actor);
        bytes32 delta = _cancel(s, replay, o, artistId, expected, c.actor, 1);
        principal.lastAuthorityActionAt = _now();
        uint256 activity = ++s.livingActivity[artistId];
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, expected, c.actor)),
            keccak256(abi.encode(artistId, expected, s.phases[expected], activity, principal)),
            delta
        );
    }

    /// @dev Contest cancellation has no living-activity effect and cannot be undone by dismissal.
    function contest(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        bytes32 subject,
        bytes32 executed,
        bool subjectClosed,
        bool executedClosed
    ) public returns (bytes32 stateDelta, bytes32 replayDelta) {
        bytes32 pending = s.pending[artistId];
        // Pending cancellation validates its uncontested head before setting contestedAt.
        // A named pending subject must not pre-mark the very record _pending validates.
        bool changed = subject != pending && _markContest(s, artistId, subject, subjectClosed);
        changed =
            (executed != pending && _markContest(s, artistId, executed, executedClosed)) || changed;
        if (pending != bytes32(0)) {
            _pending(s, artistId, pending);
            bytes32 key = _consume(
                replay,
                o,
                keccak256("identity_authority.replay.activation_cancellation_key"),
                pending,
                pending
            );
            s.phases[pending] = 3;
            s.transitions[pending].phase = 3;
            s.transitions[pending].contestedAt = _now();
            delete s.pending[artistId];
            replayDelta = keccak256(abi.encode(key, pending));
            changed = true;
        }
        // Operation33 and its captured cause describe this defensive cancellation. No
        // artist-side operation39 or artist-authority class is fabricated for its filer.
        if (changed) {
            stateDelta = keccak256(
                abi.encode(
                    artistId,
                    s.transitions[subject],
                    s.transitions[executed],
                    s.transitions[pending],
                    pending
                )
            );
        }
    }

    function _markContest(State storage s, bytes32 artistId, bytes32 record, bool closed)
        private
        returns (bool)
    {
        if (record == bytes32(0) || s.requests[record].recordHash == bytes32(0) || closed) {
            return false;
        }
        R.TransitionState storage t = s.transitions[record];
        if (t.artistId != artistId || t.recordHash != record || (t.phase != 1 && t.phase != 2)) {
            revert Estate.InvalidEstateActivation(record);
        }
        if (t.contestedAt != 0) return false;
        t.contestedAt = _now();
        return true;
    }

    function _cancel(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        bytes32 expected,
        address actor,
        uint8 authorityClass
    ) private returns (bytes32) {
        _pending(s, artistId, expected);
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.activation_cancellation_key"),
            expected,
            expected
        );
        s.phases[expected] = 3;
        s.transitions[expected].phase = 3;
        delete s.pending[artistId];
        emit ArtistEstateActivationCancelled(1, artistId, actor, authorityClass, expected);
        return keccak256(abi.encode(key, expected));
    }

    function activationCapabilities(
        StreamArtistSuccessionState.State storage succession,
        bytes32 designation,
        bytes32 forbiddenDirective
    ) public view returns (uint32 caps) {
        Succ.DesignationRecord storage d = succession.designations[designation];
        if (d.recordHash == bytes32(0)) revert Succ.InvalidSuccessor();
        caps = d.terms.grantedCapabilities;
        if (d.terms.directiveHash != bytes32(0)) {
            Succ.DirectiveRecord storage paired = succession.directives[d.terms.directiveHash];
            if (paired.recordHash == bytes32(0) || paired.terms.artistId != d.terms.artistId) {
                revert Succ.InvalidDirective();
            }
            caps &= paired.terms.grantedCapabilities;
        }
        if (forbiddenDirective != bytes32(0)) {
            Succ.DirectiveRecord storage latest = succession.directives[forbiddenDirective];
            if (latest.recordHash == bytes32(0) || latest.terms.artistId != d.terms.artistId) {
                revert Succ.InvalidDirective();
            }
            caps &= ~latest.terms.forbiddenCapabilities;
        }
    }

    function execute(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        StreamArtistRotationState.State storage rotations,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        Estate.Execution memory p,
        uint32 capabilities,
        Estate.AccelerationContext memory context,
        bytes32 governanceActionId,
        bytes32 governanceWitnessHash
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Estate.RequestRecord storage item = _pending(s, p.artistId, p.expectedActivationRecordHash);
        T.Identity storage principal = identity.identities[p.artistId];
        if (
            principal.status != 1 || principal.authorityClass != 1
                || principal.authorityAddress != item.incumbent
                || identity.activeIdentity[item.incumbent] != p.artistId
                || s.livingActivity[p.artistId] != item.livingActivity
        ) revert T.InvalidIdentity(p.artistId);
        if (identity.activeIdentity[item.terms.successor] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(item.terms.successor);
        }
        if (p.currentCoverageHash == bytes32(0) || capabilities & ~uint32(4095) != 0) {
            revert Estate.InvalidEstateActivation(p.expectedActivationRecordHash);
        }
        bytes32 governanceKey;
        if (block.timestamp < item.noticeEndsAt) {
            if (
                governanceActionId == bytes32(0) || governanceWitnessHash == bytes32(0)
                    || context.evidenceHash != item.terms.evidenceHash
                    || context.effectiveCapabilities != capabilities
            ) {
                revert Estate.EstateNoticeNotElapsed(item.noticeEndsAt);
            }
            governanceKey = _consume(
                replay,
                o,
                keccak256("identity_authority.replay.governance_action_when_accelerated"),
                keccak256(
                    abi.encode(
                        governanceActionId,
                        context.scopeHash,
                        context.oldValueHash,
                        context.newValueHash
                    )
                ),
                governanceWitnessHash
            );
        } else if (governanceActionId != bytes32(0) || governanceWitnessHash != bytes32(0)) {
            revert Estate.InvalidEstateAcceleration();
        }
        bytes32 record = p.expectedActivationRecordHash;
        bytes32 executionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.activation_execution_key"),
            record,
            record
        );
        bytes32 retirementKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.standing_retirement"),
            keccak256(abi.encode(p.artistId, item.incumbent, record)),
            record
        );
        uint64 now_ = _now();
        R.TransitionState storage t = s.transitions[record];
        t.phase = 2;
        t.executedAt = now_;
        t.postWindowEndsAt = windowEnd(now_, item.postContestSeconds);
        s.phases[record] = 2;
        delete s.pending[p.artistId];
        s.authorityActivation[p.artistId] = record;
        rotations.latestExecution[p.artistId] = record;
        uint64 epoch = ++s.delegationEpoch[p.artistId];
        s.executions[record] = Estate.ExecutionFacts(
            record,
            p.currentCoverageHash,
            capabilities,
            now_,
            governanceActionId,
            governanceWitnessHash,
            epoch
        );
        rotations.retirement[p.artistId][item.incumbent] = record;
        delete identity.activeIdentity[item.incumbent];
        identity.activeIdentity[item.terms.successor] = p.artistId;
        principal.authorityAddress = item.terms.successor;
        principal.authorityClass = 3;
        principal.status = 3;
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(p, c.actor, context, governanceActionId, governanceWitnessHash)),
            keccak256(
                abi.encode(
                    t,
                    s.executions[record],
                    principal,
                    item.incumbent,
                    rotations.latestExecution[p.artistId]
                )
            ),
            keccak256(abi.encode(executionKey, retirementKey, record, governanceKey))
        );
        emit ArtistSuccessionActivated(
            1,
            p.artistId,
            item.terms.successor,
            3,
            capabilities,
            item.terms.evidenceHash,
            governanceActionId
        );
    }

    function _pending(State storage s, bytes32 artistId, bytes32 expected)
        private
        view
        returns (Estate.RequestRecord storage item)
    {
        item = s.requests[expected];
        if (
            expected == bytes32(0) || s.pending[artistId] != expected || s.phases[expected] != 1
                || item.terms.artistId != artistId || s.transitions[expected].contestedAt != 0
        ) {
            revert Estate.InvalidEstateActivation(expected);
        }
    }

    function windowEnd(uint64 start, uint64 duration) internal pure returns (uint64) {
        if (uint256(start) + duration > type(uint64).max) revert T.InvalidRecord();
        return start + duration;
    }

    function _now() private view returns (uint64) {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        return uint64(block.timestamp);
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
        bytes32 commitment
    ) private returns (bytes32 key) {
        key = _key(o, surface, scope);
        if (replay[key].status != 0) revert T.Replay(key);
        replay[key] = T.ReplayCell(commitment, o.revision + 1, 1, 2);
    }
}
