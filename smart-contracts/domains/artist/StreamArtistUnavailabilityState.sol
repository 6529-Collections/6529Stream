// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtistRecoveryHashes.sol";
import {
    StreamArtistOnboardingTypes as T
} from "../../interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamArtistUnavailabilityTypes as U
} from "../../interfaces/stream/artist/StreamArtistUnavailabilityTypes.sol";
import {
    StreamArtistIdentityContestTypes as Contest
} from "../../interfaces/stream/artist/StreamArtistIdentityContestTypes.sol";

/// @notice Finding records and activity cancellation in the Identity owner's appended storage.
/// @dev The locked Coordinator must validate actual governance, binding and recovery-intent reads;
///      this library only consumes those typed observations and the owner's actual Identity state.
library StreamArtistUnavailabilityState {
    struct OwnerContext {
        StreamArtistHashes.Environment environment;
        address coordinator;
        address archive;
        bytes32 domain;
        uint64 revision;
    }

    struct Mutation {
        bytes32 record;
        bytes32 action;
        bytes32 state;
        bytes32 replay;
    }

    struct State {
        mapping(bytes32 => Recovery.FindingRecord) records;
        mapping(bytes32 => U.Admission) admissions;
        mapping(bytes32 => bytes32) latest;
        mapping(bytes32 => uint256) activityEpoch;
        mapping(bytes32 => bool) hasUncancelledFindings;
        uint64 noticeSeconds;
        uint64 timingRevision;
        mapping(bytes32 => bool) timingActions;
    }

    event ArtistUnavailabilityFindingRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        uint256 indexed collectionId,
        uint64 noticeEndsAt,
        uint64 recordedAt,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 findingRecordHash,
        bytes32 governanceActionId
    );
    event ArtistUnavailabilityActivityRecorded(
        uint16 schemaVersion,
        bytes32 indexed artistId,
        address indexed signer,
        uint8 authorityClass,
        uint16 operationId,
        uint256 previousEpoch,
        uint256 nextEpoch
    );

    function timing(State storage s) public view returns (uint64, uint64, uint64) {
        return (
            s.noticeSeconds == 0 ? uint64(90 days) : s.noticeSeconds,
            30 days,
            s.timingRevision == 0 ? uint64(1) : s.timingRevision
        );
    }

    function associationKey(bytes32 artistId, uint256 collectionId) public pure returns (bytes32) {
        return keccak256(abi.encode(artistId, collectionId));
    }

    function recordEncodedRead(State storage s, bytes32 hash) public view returns (bytes memory) {
        return abi.encode(s.records[hash], s.admissions[hash]);
    }

    function contextEncodedRead(
        State storage s,
        OwnerContext memory o,
        T.Identity memory principal,
        U.Input memory p
    ) public view returns (bytes memory) {
        return abi.encode(context(s, o, principal, p));
    }

    function context(
        State storage s,
        OwnerContext memory o,
        T.Identity memory principal,
        U.Input memory p
    ) public view returns (U.Context memory result) {
        _binding(principal, p);
        (result.noticeSeconds,, result.timingRevision) = timing(s);
        bytes32 head = s.latest[associationKey(p.terms.artistId, p.terms.collectionId)];
        if (head != bytes32(0) && live(s, head, p.binding_) && !p.priorRecoveryTerminal) {
            revert U.UnavailabilityFindingActive(head);
        }
        result.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_SCOPE_V1"),
                o.environment.chainId,
                o.environment.registry,
                p.terms.artistId,
                p.terms.collectionId
            )
        );
        result.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_OLD_STATE_V1"),
                principal,
                p.binding_,
                head,
                s.activityEpoch[p.terms.artistId],
                result.noticeSeconds,
                result.timingRevision,
                p.priorRecoveryTerminal
            )
        );
        result.newValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_INTENT_V1"),
                o.environment.chainId,
                o.environment.registry,
                p.terms,
                p.target,
                p.recoveryRegistryCodeHash,
                p.recoveryIntentFactsHash,
                result.noticeSeconds,
                result.timingRevision
            )
        );
    }

    function record(
        State storage s,
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        T.Identity memory principal,
        U.Input memory p
    ) public returns (Mutation memory m) {
        U.Context memory expected = context(s, o, principal, p);
        Contest.GovernanceWitness memory g = p.governance;
        if (
            g.actionId == bytes32(0) || g.actionId == p.target.recoveryActionId
                || g.proposer == address(0) || g.actionClass != 2
                || g.roleMutationHash == bytes32(0) || g.roleRevision == 0
                || g.scopeHash != expected.scopeHash || g.oldValueHash != expected.oldValueHash
                || g.newValueHash != expected.newValueHash
        ) revert Recovery.InvalidUnavailabilityFinding();
        uint256 endsAt = block.timestamp + expected.noticeSeconds;
        if (
            block.timestamp > type(uint64).max || endsAt > type(uint64).max
                || p.recoveryNotBefore < endsAt || p.recoveryExpiresAfter <= p.recoveryNotBefore
        ) revert Recovery.InvalidUnavailabilityFinding();

        Recovery.FindingRecord memory r;
        r.terms = p.terms;
        r.governanceActionId = g.actionId;
        r.noticeEndsAt = uint64(endsAt);
        r.recordedAt = uint64(block.timestamp);
        r.noticeSeconds = expected.noticeSeconds;
        r.timingRevision = expected.timingRevision;
        r.bindingGeneration = p.binding_.generation;
        r.bindingHash = p.binding_.bindingHash;
        r.recordHash = StreamArtistRecoveryHashes.findingRecord(o.environment, r);
        bytes32 actionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.governance_action_id"),
            keccak256(abi.encode(g.actionId)),
            r.recordHash
        );
        bytes32 findingKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.finding_key"),
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                    p.terms.artistId,
                    p.binding_.generation,
                    p.binding_.bindingHash,
                    p.target
                )
            ),
            r.recordHash
        );
        if (s.records[r.recordHash].recordHash != bytes32(0)) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        U.Admission memory admission = U.Admission(
            p.target,
            p.recoveryRegistryCodeHash,
            p.recoveryIntentFactsHash,
            s.activityEpoch[p.terms.artistId],
            keccak256(abi.encode(g))
        );
        s.records[r.recordHash] = r;
        s.admissions[r.recordHash] = admission;
        s.latest[associationKey(p.terms.artistId, p.terms.collectionId)] = r.recordHash;
        s.hasUncancelledFindings[p.terms.artistId] = true;
        m = Mutation(
            r.recordHash,
            keccak256(abi.encode(p)),
            keccak256(abi.encode(r, admission)),
            keccak256(abi.encode(actionKey, findingKey, r.recordHash))
        );
        emit ArtistUnavailabilityFindingRecorded(
            1,
            p.terms.artistId,
            p.terms.collectionId,
            r.noticeEndsAt,
            r.recordedAt,
            p.terms.evidenceHash,
            p.terms.reasonHash,
            r.recordHash,
            g.actionId
        );
    }

    /// @notice Association/activity eligibility only; this does not prove a live recovery action.
    function live(State storage s, bytes32 hash, T.Binding memory b) public view returns (bool) {
        Recovery.FindingRecord storage r = s.records[hash];
        return r.recordHash != bytes32(0) && b.accepted && b.artistId == r.terms.artistId
            && b.generation == r.bindingGeneration && b.bindingHash == r.bindingHash
            && s.admissions[hash].activityEpoch == s.activityEpoch[b.artistId];
    }

    /// @notice Called only after a successfully authenticated CURRENT artist-authority action.
    /// @dev Its delta must be included in that action's single owner commit. Reverts roll it back.
    ///      This invalidates unexecuted use; immutable executed recovery history does not read it.
    function noteActivity(
        State storage s,
        bytes32 artistId,
        address signer,
        uint8 authorityClass,
        uint16 operation
    ) public returns (bytes32 delta) {
        if (!s.hasUncancelledFindings[artistId]) return bytes32(0);
        if (signer == address(0) || authorityClass == 0) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        uint256 previous = s.activityEpoch[artistId];
        uint256 next = previous + 1;
        s.activityEpoch[artistId] = next;
        s.hasUncancelledFindings[artistId] = false;
        delta = keccak256(abi.encode(artistId, signer, authorityClass, operation, previous, next));
        emit ArtistUnavailabilityActivityRecorded(
            1, artistId, signer, authorityClass, operation, previous, next
        );
    }

    /// @dev Only the fixed owner supplies this storage reference, after authenticating the action.
    function notePrincipalActivity(
        State storage s,
        T.Identity storage principal,
        bytes32 artistId,
        address signer,
        uint16 operation
    ) public returns (bytes32) {
        if (!s.hasUncancelledFindings[artistId]) return bytes32(0);
        if (
            signer == address(0) || signer != principal.authorityAddress
                || (principal.authorityClass != 1 && principal.authorityClass != 3)
        ) return bytes32(0);
        return noteActivity(s, artistId, signer, principal.authorityClass, operation);
    }

    function _binding(T.Identity memory principal, U.Input memory p) private pure {
        StreamFinalityScope memory scope = p.target.scope;
        bool shape = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? scope.tokenId == 0 && scope.scopeId == bytes32(0)
            : scope.scopeType == StreamFinalityScopeType.TOKEN
                ? scope.tokenId != 0 && scope.scopeId == bytes32(0)
                : scope.tokenId == 0 && scope.scopeId != bytes32(0);
        if (
            !p.binding_.accepted || p.binding_.artistId != p.terms.artistId
                || p.terms.artistId == bytes32(0) || p.binding_.generation == 0
                || p.binding_.bindingHash == bytes32(0) || principal.registeredAt == 0
                || principal.status == 0 || p.terms.evidenceHash == bytes32(0)
                || p.terms.reasonHash == bytes32(0) || p.target.recoveryRegistry == address(0)
                || p.target.recoveryActionId == bytes32(0)
                || p.recoveryRegistryCodeHash == bytes32(0)
                || p.recoveryIntentFactsHash == bytes32(0)
                || p.target.originalFinalityRecordHash == bytes32(0)
                || p.target.recoveryManifestHash == bytes32(0)
                || scope.collectionId != p.terms.collectionId || !shape
        ) revert Recovery.InvalidUnavailabilityFinding();
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        OwnerContext memory o,
        bytes32 surface,
        bytes32 scope,
        bytes32 recordHash
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
        replay[key] = T.ReplayCell(recordHash, o.revision + 1, 1, 2);
    }
}
