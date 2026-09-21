// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistRotationExecution as Worker } from "./StreamArtistRotationExecution.sol";
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

/// @notice Linked state mechanics for Identity's guardian and rotation domain.
/// @dev Identity retains typed caller/snapshot guards and the single semantic commit.
library StreamArtistRotationState {
    // Retain the original error ABI entry now raised by the fixed worker.
    error RotationNotExecutable(bytes32 rotationRecordHash);
    error InvalidGuardianSet();
    error EstateCapabilityUnavailable(bytes32 artistId, uint32 requiredCapabilities);
    // Retain original error ABI entries now raised by the fixed acceptance worker.
    error BoundExceeded(uint256 actual, uint256 maximum);
    error InvalidSignature();
    error NonceAvailabilityAlreadyUsed(uint256 nonce);
    error NonceAvailabilityInconsistent(uint8 level, uint256 prefix);

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

    function _validClosure(State storage s, bytes32 artistId, Dismissal.Closure memory closure)
        private
        view
    {
        R.TransitionState memory t = transitionState(s, s.latestExecution[artistId]);
        bool abandoned = t.phase == 3
            || (t.phase == 2 && t.contestedAt != 0 && t.contestedAt < t.postWindowEndsAt);
        if (
            closure.artistId != artistId || t.artistId != artistId
                || closure.transitionRecordHash != s.latestExecution[artistId]
                || closure.transitionRecordHash == bytes32(0) || t.phase != 2 || t.executedAt == 0
                || closure.windowEndsAt != t.postWindowEndsAt
                || closure.contestedAt != t.contestedAt || closure.abandoned != abandoned
        ) revert Dismissal.InvalidClosure(closure.transitionRecordHash);
    }

    function associationWithResolution(
        State storage s,
        bytes32 artistId,
        Dismissal.Closure memory closure
    ) public view returns (R.ProvisionalAssociation memory empty) {
        if (closure.dismissalRecordHash == bytes32(0)) return association(s, artistId);
        _validClosure(s, artistId, closure);
    }

    function activeWindowWithResolution(
        State storage s,
        bytes32 artistId,
        Dismissal.Closure memory closure
    ) public view returns (bytes32, uint64, bool) {
        if (closure.dismissalRecordHash == bytes32(0)) {
            return activeWindow(s, artistId);
        }
        _validClosure(s, artistId, closure);
        if (pendingTransition(s, artistId) != bytes32(0)) return activeWindow(s, artistId);
        return (bytes32(0), 0, false);
    }

    function association(State storage s, bytes32 artistId)
        public
        view
        returns (R.ProvisionalAssociation memory result)
    {
        bytes32 record = s.latestExecution[artistId];
        R.TransitionState memory transition = transitionState(s, record);
        if (record != bytes32(0) && transition.artistId != artistId) {
            revert T.InvalidIdentity(artistId);
        }
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
        R.TransitionState memory t = transitionState(s, a.transitionRecordHash);
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
        return StreamArtistTransitionReads.activeWindow(s, artistId);
    }

    /// @notice Resolve the actual pending rotation or estate from Identity-owned references.
    function pendingTransition(State storage s, bytes32 artistId)
        public
        view
        returns (bytes32 record)
    {
        return StreamArtistTransitionReads.pendingTransition(s, artistId);
    }

    /// @dev Rotation data stays local; the fixed estate getter reads only actual local estate maps.
    function transitionStanding(State storage s, bytes32 record)
        public
        view
        returns (address priorAddress, bytes32 guardianRecord, uint64 standingTail)
    {
        return StreamArtistTransitionReads.transitionStanding(s, record);
    }

    /// @dev Existing rotation facts stay local. Other actual transition kinds resolve by a
    /// fixed same-Identity static read; the owner getter never calls this selection helper.
    function transitionState(State storage s, bytes32 record)
        public
        view
        returns (R.TransitionState memory t)
    {
        return StreamArtistTransitionReads.transitionState(s, record);
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
        Dismissal.Closure memory empty;
        return _setGuardians(s, identity, replay, o, c, p, a, proof, empty);
    }

    function setGuardiansWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.GuardianSet memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Dismissal.Closure memory closure
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _setGuardians(s, identity, replay, o, c, p, a, proof, closure);
    }

    function _setGuardians(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.GuardianSet memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        Dismissal.Closure memory closure
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        return
            StreamArtistGuardianState.setGuardians(s, identity, replay, o, c, p, a, proof, closure);
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
        Dismissal.Closure memory empty;
        return _stage(
            s,
            identity,
            replay,
            o,
            c,
            p,
            oldAuthorization,
            newAuthorization,
            oldProof,
            newProof,
            empty
        );
    }

    function stageWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory oldAuthorization,
        T.Authorization memory newAuthorization,
        T.SignerApproval memory oldProof,
        T.SignerApproval memory newProof,
        Dismissal.Closure memory closure
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _stage(
            s,
            identity,
            replay,
            o,
            c,
            p,
            oldAuthorization,
            newAuthorization,
            oldProof,
            newProof,
            closure
        );
    }

    function _stage(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory oldAuthorization,
        T.Authorization memory newAuthorization,
        T.SignerApproval memory oldProof,
        T.SignerApproval memory newProof,
        Dismissal.Closure memory closure
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
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
        (bytes32 active, uint64 endsAt,) = activeWindowWithResolution(s, p.artistId, closure);
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
        StreamArtistPayloadStore.store(
            keccak256("ARTIST_SIGNATURE_BUNDLE"), identity.signatures[record]
        );
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

        if (closure.dismissalRecordHash != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, closure));
        }
    }

    function acceptanceNonceState(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        bytes32 artistId,
        address newAddress,
        uint256 nonce
    ) public view returns (bool used, uint256 nextNonce) {
        return StreamArtistRotationAcceptance.nonceState(
                s.acceptanceHint, replay, o, artistId, newAddress, nonce
            );
    }

    /// @dev Operation35 shares the original acceptance digest, replay key and nonce index.
    ///      The concrete Identity owner authenticates recovery authority and typed facts first.
    function acceptIdentityRecovery(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.Rotation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 record
    ) public returns (bytes32) {
        if (c.operationId != 35) revert T.InvalidOperation(c.operationId);
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        return _newSide(s, replay, o, c, p, a, proof, record);
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
        return StreamArtistRotationAcceptance.accept(
            s.acceptanceNonces, s.acceptanceHint, replay, o, c, p, a, proof, record
        );
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
            !StreamArtistAuthorityPolicy.ordinary(
                    identity.identities[artistId].authorityClass,
                    identity.identities[artistId].status,
                    false
                ) || !_member(s, r.guardianSetRecordHash, c.actor)
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
        return vetoWithSuccessor(
            s, identity, replay, o, c, artistId, expected, reasonHash, address(0)
        );
    }

    function vetoWithSuccessor(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash,
        address successor
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        Dismissal.StandingJudgment memory none;
        return _veto(s, identity, replay, o, c, artistId, expected, reasonHash, successor, none);
    }

    function vetoWithResolution(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash,
        address successor,
        Dismissal.StandingJudgment memory judgment
    ) public returns (StreamArtistIdentityState.Mutation memory m) {
        return _veto(s, identity, replay, o, c, artistId, expected, reasonHash, successor, judgment);
    }

    function _veto(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        bytes32 artistId,
        bytes32 expected,
        bytes32 reasonHash,
        address successor,
        Dismissal.StandingJudgment memory judgment
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        R.RotationRecord storage r = _pending(s, artistId, expected);
        (bool revoked,) = standingRevoked(s, artistId, c.actor);
        if (
            judgment.dismissalRecordHash != bytes32(0)
                && judgment.retirementHash == s.retirement[artistId][c.actor]
        ) revoked = true;
        if (
            c.actor != identity.identities[artistId].authorityAddress && c.actor != successor
                && !_member(s, operativeGuardian(s, artistId), c.actor)
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
        if (judgment.dismissalRecordHash != bytes32(0)) {
            m.state = keccak256(abi.encode(m.state, judgment));
        }
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
        return Worker.execute(s, identity, replay, o, c, artistId, expected);
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
        return _revokeStanding(s, identity, replay, o, c, p, a, proof, bytes32(0));
    }

    /// @dev The owner authenticates the exact stored recovery continuation for this retirement.
    function revokeStandingWithRecovery(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.StandingRevocation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 recoveryContinuation
    ) public returns (StreamArtistIdentityState.Mutation memory) {
        if (recoveryContinuation == 0) revert T.InvalidRecord();
        return _revokeStanding(s, identity, replay, o, c, p, a, proof, recoveryContinuation);
    }

    function _revokeStanding(
        State storage s,
        StreamArtistIdentityState.State storage identity,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistIdentityState.OwnerContext memory o,
        T.ActionContext memory c,
        R.StandingRevocation memory p,
        T.Authorization memory a,
        T.SignerApproval memory proof,
        bytes32 recoveryContinuation
    ) private returns (StreamArtistIdentityState.Mutation memory m) {
        if (block.timestamp > a.time) revert T.ExpiredAuthorization(a.time);
        bytes32 retirement = s.retirement[p.artistId][p.revokedAddress];
        R.TransitionState memory transition = transitionState(s, retirement);
        (address priorAddress,, uint64 tail) = transitionStanding(s, retirement);
        (bool revoked,) = standingRevoked(s, p.artistId, p.revokedAddress);
        if (
            retirement == bytes32(0) || retirement != p.retiredTransitionRecordHash || revoked
                || p.revokedAddress == identity.identities[p.artistId].authorityAddress
                || transition.artistId != p.artistId || priorAddress != p.revokedAddress
                || transition.phase != 2 || transition.contestedAt != 0
                || pendingTransition(s, p.artistId) != bytes32(0)
                || IStreamArtistAttributionRepudiation(o.environment.registry)
                        .activeRepudiationCount(p.artistId) != 0
                || block.timestamp < uint256(transition.postWindowEndsAt) + tail
        ) {
            revert R.InvalidPriorStanding(p.revokedAddress);
        }
        uint64 observed = _now();
        uint8 authorityClass = identity.identities[p.artistId].authorityClass;
        bytes32 record = StreamArtistRotationHashes.standingRecordForAuthority(
            o.environment, p, proof.signer, authorityClass, a.nonce, observed
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
            recoveryContinuation == 0
                ? keccak256("identity_authority.replay.standing_revocation_key")
                : keccak256("identity_authority.replay.standing_revocation_recovery_continuation"),
            recoveryContinuation == 0
                ? keccak256(abi.encode(p.artistId, p.revokedAddress, retirement))
                : keccak256(
                    abi.encode(p.artistId, p.revokedAddress, retirement, recoveryContinuation)
                ),
            record
        );
        R.StandingRecord memory item =
            R.StandingRecord(record, p, proof.signer, authorityClass, a.nonce, observed);
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
            authorityClass,
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
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
