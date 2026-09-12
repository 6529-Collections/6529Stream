// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistIdentityState.sol";
import "./StreamArtistRotationHashes.sol";

/// @notice Linked state mechanics for Identity's guardian and rotation domain.
/// @dev Identity retains typed caller/snapshot guards and the single semantic commit.
library StreamArtistRotationState {
    using StreamArtistNonceAvailability for StreamArtistNonceAvailability.Index;

    struct State {
        mapping(bytes32 => bytes32) latestTransition;
        mapping(bytes32 => bytes32) latestExecution;
        mapping(bytes32 => bytes32) pending;
        mapping(bytes32 => R.RotationRecord) rotations;
        mapping(bytes32 => R.GuardianRecord) guardians;
        mapping(bytes32 => bytes32) stableGuardian;
        mapping(bytes32 => bytes32) provisionalGuardian;
        mapping(bytes32 => mapping(address => bool)) approvals;
        mapping(bytes32 => mapping(address => bytes32)) retirement;
        mapping(bytes32 => mapping(address => bytes32)) standingRevocation;
        mapping(bytes32 => R.StandingRecord) standingRecords;
        mapping(bytes32 => StreamArtistNonceAvailability.Index) acceptanceNonces;
        mapping(bytes32 => uint256) acceptanceHint;
        uint64 rotationContestSeconds;
        uint64 priorStandingTailSeconds;
        uint64 timingRevision;
        mapping(bytes32 => bool) timingActions;
    }

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
    event ArtistRotationStaged(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed oldAddress,
        address indexed newAddress,
        uint64 stagedAt,
        uint64 contestEndsAt,
        uint256 nonce,
        bytes32 reasonHash,
        bytes32 rotationRecordHash
    );
    event ArtistRotationGuardianApproved(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed guardian,
        bytes32 indexed rotationRecordHash,
        uint32 approvals
    );
    event ArtistRotationVetoed(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed vetoer,
        bytes32 indexed rotationRecordHash,
        bytes32 reasonHash
    );
    event ArtistAddressRotated(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed oldAddress,
        address indexed newAddress,
        uint8 authorityClass,
        bytes32 reasonHash,
        bytes32 rotationRecordHash
    );
    event PriorAddressStandingRevoked(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed revokedAddress,
        address indexed signer,
        bytes32 retiredTransitionRecordHash,
        uint8 authorityClass,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 signedAt,
        bytes32 revocationRecordHash
    );

    function rotationSeconds(State storage s) internal view returns (uint64) {
        return s.rotationContestSeconds == 0 ? 7 days : s.rotationContestSeconds;
    }

    function standingSeconds(State storage s) internal view returns (uint64) {
        return s.priorStandingTailSeconds == 0 ? 90 days : s.priorStandingTailSeconds;
    }

    function association(State storage s, bytes32 artistId)
        public
        view
        returns (R.ProvisionalAssociation memory result)
    {
        bytes32 record = s.latestExecution[artistId];
        R.TransitionState storage transition = s.rotations[record].transition;
        if (record != bytes32(0) && block.timestamp < transition.postWindowEndsAt) {
            result = R.ProvisionalAssociation(record, transition.postWindowEndsAt);
        }
    }

    function eligible(State storage s, bytes32 artistId, R.ProvisionalAssociation memory a)
        public
        view
        returns (bool)
    {
        if (a.transitionRecordHash == bytes32(0)) return a.windowEndsAt == 0;
        R.TransitionState storage t = s.rotations[a.transitionRecordHash].transition;
        return t.artistId == artistId && t.phase == 2 && t.executedAt != 0
            && t.postWindowEndsAt == a.windowEndsAt
            && (t.contestedAt == 0 || t.contestedAt >= a.windowEndsAt)
            && block.timestamp >= a.windowEndsAt;
    }

    function operativeGuardian(State storage s, bytes32 artistId) public view returns (bytes32) {
        bytes32 base = s.stableGuardian[artistId];
        bytes32 candidate = s.provisionalGuardian[artistId];
        if (
            candidate != bytes32(0) && eligible(s, artistId, s.guardians[candidate].provisional)
                && (base == bytes32(0) || s.guardians[candidate].nonce > s.guardians[base].nonce)
        ) {
            return candidate;
        }
        return base;
    }

    function activeWindow(State storage s, bytes32 artistId)
        public
        view
        returns (bytes32 record, uint64 endsAt, bool contested)
    {
        record = s.pending[artistId];
        if (record != bytes32(0)) {
            R.TransitionState storage pending_ = s.rotations[record].transition;
            return (record, pending_.contestEndsAt, pending_.contestedAt != 0);
        }
        record = s.latestExecution[artistId];
        if (record == bytes32(0)) return (bytes32(0), 0, false);
        R.TransitionState storage executed = s.rotations[record].transition;
        if (
            (executed.contestedAt != 0 && executed.contestedAt < executed.postWindowEndsAt)
                || block.timestamp < executed.postWindowEndsAt
        ) {
            return (record, executed.postWindowEndsAt, executed.contestedAt != 0);
        }
        return (bytes32(0), 0, false);
    }

    function standingRevoked(State storage s, bytes32 artistId, address priorAddress)
        public
        view
        returns (bool revoked, bytes32 record)
    {
        record = s.standingRevocation[artistId][priorAddress];
        revoked = record != bytes32(0)
            && s.standingRecords[record].terms.retiredTransitionRecordHash
                == s.retirement[artistId][priorAddress];
        if (!revoked) record = bytes32(0);
    }

    function setGuardians(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.GuardianSet memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
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
        bytes32 prior = operativeGuardian(s, p.artistId);
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
        R.ProvisionalAssociation memory pending_ = association(s, p.artistId);
        R.GuardianRecord memory item =
            R.GuardianRecord(record, p, proof.signer, 1, a.nonce, a.time, prior, pending_);
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
            1,
            a.nonce,
            a.time,
            record
        );
    }

    function stage(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory oldAuthorization,
        T.Authorization memory newAuthorization,
        T.SignerApproval memory oldProof,
        T.SignerApproval memory newProof
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (block.timestamp > oldAuthorization.time) {
            revert T.ExpiredAuthorization(oldAuthorization.time);
        }
        if (block.timestamp > newAuthorization.time) {
            revert T.ExpiredAuthorization(newAuthorization.time);
        }
        if (
            p.oldAddress == address(0) || p.newAddress == address(0) || p.oldAddress == p.newAddress
                || p.oldAddress != identity.identities[p.artistId].authorityAddress
                || p.expectedPreviousTransitionRecordHash != s.latestTransition[p.artistId]
        ) {
            revert R.InvalidRotation(p.expectedPreviousTransitionRecordHash);
        }
        if (identity.activeIdentity[p.newAddress] != bytes32(0)) {
            revert T.AddressAlreadyRegistered(p.newAddress);
        }
        (bytes32 active, uint64 endsAt,) = activeWindow(s, p.artistId);
        if (active != bytes32(0)) revert R.ActiveAuthorityWindow(active, endsAt);
        bytes32 guardians_ = operativeGuardian(s, p.artistId);
        R.GuardianRecord storage guardian = s.guardians[guardians_];
        uint64 window = rotationSeconds(s);
        if (guardian.terms.minContestSeconds > window) window = guardian.terms.minContestSeconds;
        uint64 observed = _now();
        uint64 contestEndsAt = _windowEnd(observed, window);
        bytes32 record = StreamArtistRotationHashes.rotationRecord(
            o.environment, p, oldAuthorization.nonce, observed, contestEndsAt
        );
        if (s.rotations[record].recordHash != bytes32(0)) revert R.InvalidRotation(record);
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            oldAuthorization,
            oldProof,
            StreamArtistRotationHashes.rotationDigest(o.environment, p, oldAuthorization),
            record,
            p.oldAddress
        );
        bytes32 newReplay = _newSide(s, replay, o, c, p, newAuthorization, newProof, record);
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.rotation_key"),
            keccak256(abi.encode(p.artistId, record)),
            record
        );
        R.RotationRecord memory item = R.RotationRecord(
            record,
            p,
            guardians_,
            guardian.terms.approvalThreshold,
            0,
            oldAuthorization.nonce,
            newAuthorization.nonce,
            window,
            standingSeconds(s),
            s.timingRevision == 0 ? 1 : s.timingRevision,
            R.TransitionState(p.artistId, record, observed, contestEndsAt, 0, 0, 0, 1)
        );
        s.rotations[record] = item;
        s.pending[p.artistId] = record;
        s.latestTransition[p.artistId] = record;
        identity.signatures[record] =
            abi.encode(oldAuthorization.signature, newAuthorization.signature);
        m.record = record;
        m.action = keccak256(abi.encode(p, oldAuthorization, newAuthorization, oldProof, newProof));
        m.state = keccak256(abi.encode(m.state, item, newReplay));
        m.replay = keccak256(abi.encode(m.replay, newReplay, key, record));
        emit ArtistRotationStaged(
            1,
            p.artistId,
            p.oldAddress,
            p.newAddress,
            observed,
            contestEndsAt,
            oldAuthorization.nonce,
            p.reasonHash,
            record
        );
    }

    function acceptanceNonceState(
        State storage s,
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
        nextNonce = s.acceptanceHint[lane];
    }

    function _newSide(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 record
    ) private returns (bytes32) {
        bytes32 digest = StreamArtistRotationHashes.acceptanceDigest(o.environment, p, a);
        bytes32 lane = _acceptanceLane(p.artistId, p.newAddress);
        if (
            proof.signer != p.newAddress || proof.digest != digest
                || (proof.direct && (c.actor != proof.signer || a.signature.length != 0))
                || (!proof.direct && a.signature.length == 0 && proof.signer.code.length == 0)
        ) {
            revert T.InvalidSignature();
        }
        if (proof.direct && a.nonce != s.acceptanceHint[lane]) revert T.InvalidRecord();
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
        }
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.nonce_allocator"),
            _acceptanceScope(p.artistId, p.newAddress, a.nonce),
            digest
        );
        bytes32 delta = s.acceptanceNonces[lane].consume(a.nonce);
        if (a.nonce == s.acceptanceHint[lane]) {
            (, s.acceptanceHint[lane]) = s.acceptanceNonces[lane].firstUnused();
        }
        return keccak256(
            abi.encode(
                key, digest, delta, observation, replay[observation], s.acceptanceHint[lane], record
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

    function approve(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        R.RotationRecord storage r = _pending(s, artistId, expected);
        if (
            identity.identities[artistId].status != 1
                || !_member(s, r.guardianSetRecordHash, c.actor)
        ) {
            revert T.Unauthorized(c.actor);
        }
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.guardian_approval_key"),
            keccak256(abi.encode(expected, c.actor)),
            expected
        );
        if (s.approvals[expected][c.actor]) revert T.Replay(key);
        s.approvals[expected][c.actor] = true;
        ++r.guardianApprovals;
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, expected, c.actor)),
            keccak256(abi.encode(expected, c.actor, r.guardianApprovals)),
            keccak256(abi.encode(key, expected))
        );
        emit ArtistRotationGuardianApproved(1, artistId, c.actor, expected, r.guardianApprovals);
    }

    function veto(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        R.RotationRecord storage r = _pending(s, artistId, expected);
        (bool revoked,) = standingRevoked(s, artistId, c.actor);
        if (
            c.actor != identity.identities[artistId].authorityAddress
                && !_member(s, r.guardianSetRecordHash, c.actor)
                && (s.retirement[artistId][c.actor] == bytes32(0) || revoked)
        ) revert T.Unauthorized(c.actor);
        bytes32 key = _consume(
            replay, o, keccak256("identity_authority.replay.rotation_veto_key"), expected, expected
        );
        r.transition.phase = 3;
        r.transition.contestedAt = _now();
        delete s.pending[artistId];
        identity.identities[artistId].status = 4;
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, expected, reasonHash, c.actor)),
            keccak256(abi.encode(r.transition, identity.identities[artistId])),
            keccak256(abi.encode(key, expected))
        );
        emit ArtistRotationVetoed(1, artistId, c.actor, expected, reasonHash);
    }

    function execute(
        State storage s,
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
            principal.status != 1 || principal.authorityClass != 1
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
        s.retirement[artistId][r.terms.oldAddress] = expected;
        delete s.pending[artistId];
        delete identity.activeIdentity[r.terms.oldAddress];
        identity.activeIdentity[r.terms.newAddress] = artistId;
        principal.authorityAddress = r.terms.newAddress;
        // Permissionless execution, approvals and vetoes never count as artist activity.
        m = StreamArtistIdentityState.Mutation(
            bytes32(0),
            keccak256(abi.encode(artistId, expected, c.actor)),
            keccak256(abi.encode(r.transition, principal, r.terms.oldAddress, r.terms.newAddress)),
            keccak256(abi.encode(executionKey, retirementKey, expected))
        );
        emit ArtistAddressRotated(
            1, artistId, r.terms.oldAddress, r.terms.newAddress, 1, r.terms.reasonHash, expected
        );
    }

    function revokeStanding(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.StandingRevocation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        bytes32 retirement = s.retirement[p.artistId][p.revokedAddress];
        R.RotationRecord storage transition = s.rotations[retirement];
        (bool revoked,) = standingRevoked(s, p.artistId, p.revokedAddress);
        if (
            retirement == bytes32(0) || retirement != p.retiredTransitionRecordHash || revoked
                || p.revokedAddress == identity.identities[p.artistId].authorityAddress
                || transition.transition.phase != 2 || transition.transition.contestedAt != 0
                || s.pending[p.artistId] != bytes32(0)
                || block.timestamp
                    < uint256(transition.transition.postWindowEndsAt) + transition.standingTail
        ) {
            revert R.InvalidPriorStanding(p.revokedAddress);
        }
        uint64 observed = _now();
        bytes32 record = StreamArtistRotationHashes.standingRecord(
            o.environment, p, proof.signer, a.nonce, observed
        );
        m = StreamArtistIdentityState.authorize(
            identity,
            replay,
            o,
            c,
            p.artistId,
            a,
            proof,
            StreamArtistRotationHashes.standingDigest(o.environment, p, a),
            record,
            identity.identities[p.artistId].authorityAddress
        );
        bytes32 key = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.standing_revocation_key"),
            keccak256(abi.encode(p.artistId, p.revokedAddress, retirement)),
            record
        );
        R.StandingRecord memory item =
            R.StandingRecord(record, p, proof.signer, 1, a.nonce, observed);
        s.standingRecords[record] = item;
        s.standingRevocation[p.artistId][p.revokedAddress] = record;
        m.record = record;
        m.action = keccak256(abi.encode(p, a, proof));
        m.state = keccak256(abi.encode(m.state, item));
        m.replay = keccak256(abi.encode(m.replay, key, record));
        emit PriorAddressStandingRevoked(
            1,
            p.artistId,
            p.revokedAddress,
            proof.signer,
            retirement,
            1,
            p.reasonHash,
            a.nonce,
            observed,
            record
        );
    }

    function _pending(State storage s, bytes32 artistId, bytes32 expected)
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

    function _member(State storage s, bytes32 guardianRecord_, address account)
        private
        view
        returns (bool)
    {
        address[] storage guardians_ = s.guardians[guardianRecord_].terms.guardians;
        for (uint256 i; i < guardians_.length; ++i) {
            if (guardians_[i] == account) return true;
        }
        return false;
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
    }
}
