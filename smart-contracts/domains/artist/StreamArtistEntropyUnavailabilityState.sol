// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/entropy/IStreamEntropyArtistUnavailability.sol";
import "./StreamArtistUnavailabilityState.sol";
import "./StreamArtistIdentityState.sol";
import {
    StreamArtistEntropyUnavailabilityTypes as EU
} from "../../interfaces/stream/artist/IStreamArtistEntropyUnavailability.sol";

/// @notice Original operation23 finding records with a separately typed entropy evidence manifest.
/// @dev The fixed Coordinator supplies exact host observations and original Arbiter witness.
/// Ordinary Identity records/latest/activity/replay remain authoritative for both finding profiles.
library StreamArtistEntropyUnavailabilityState {
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
    event ArtistEntropyUnavailabilityContext(
        uint16 schemaVersion,
        uint256 chainId,
        address indexed registry,
        bytes32 indexed findingRecordHash,
        EU.Admission admission
    );

    function recordRead(StreamArtistUnavailabilityState.State storage s, bytes32 hash)
        public
        view
        returns (bytes memory)
    {
        return abi.encode(
            s.records[hash], StreamArtistEntropyUnavailabilityStore.state().admissions[hash]
        );
    }

    function contextEncoded(
        StreamArtistUnavailabilityState.State storage s,
        StreamArtistIdentityState.State storage identities,
        StreamArtistUnavailabilityState.OwnerContext memory o,
        bytes calldata encoded
    ) public view returns (bytes memory) {
        EU.Input memory p = abi.decode(encoded, (EU.Input));
        return abi.encode(context(s, o, identities.identities[p.terms.artistId], p));
    }

    function context(
        StreamArtistUnavailabilityState.State storage s,
        StreamArtistUnavailabilityState.OwnerContext memory o,
        T.Identity memory principal,
        EU.Input memory p
    ) public view returns (U.Context memory x) {
        _binding(o, principal, p);
        (x.noticeSeconds,, x.timingRevision) = StreamArtistUnavailabilityState.timing(s);
        bytes32 head = s.latest[
            StreamArtistUnavailabilityState.associationKey(p.terms.artistId, p.terms.collectionId)
        ];
        if (
            head != 0 && StreamArtistUnavailabilityState.live(s, head, p.binding_)
                && !p.priorRecoveryTerminal
        ) {
            revert U.UnavailabilityFindingActive(head);
        }
        x.scopeHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_UNAVAILABILITY_SCOPE_V1"),
                o.environment.chainId,
                o.environment.registry,
                p.terms.artistId,
                p.terms.collectionId
            )
        );
        x.oldValueHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_ARTIST_ENTROPY_UNAVAILABILITY_OLD_V1"),
                principal,
                p.binding_,
                head,
                s.activityEpoch[p.terms.artistId],
                x.noticeSeconds,
                x.timingRevision,
                p.priorRecoveryTerminal
            )
        );
        x.newValueHash = keccak256(
            abi.encode(
                EU.PROFILE,
                o.environment.chainId,
                o.environment.registry,
                p.terms,
                p.target,
                p.intent,
                p.coordinatorCodeHash,
                x.noticeSeconds,
                x.timingRevision
            )
        );
    }

    function recordEncoded(
        StreamArtistUnavailabilityState.State storage s,
        StreamArtistIdentityState.State storage identities,
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistUnavailabilityState.OwnerContext memory o,
        bytes calldata encoded
    )
        public
        returns (
            StreamArtistUnavailabilityState.Mutation memory m,
            bytes32 artistId,
            uint256 collectionId
        )
    {
        (, EU.Input memory p) = abi.decode(encoded, (T.ActionContext, EU.Input));
        U.Context memory x = context(s, o, identities.identities[p.terms.artistId], p);
        Contest.GovernanceWitness memory g = p.governance;
        if (
            g.actionId == 0 || g.proposer == address(0) || g.actionClass != 2
                || g.roleMutationHash == 0 || g.roleRevision == 0 || g.scopeHash != x.scopeHash
                || g.oldValueHash != x.oldValueHash || g.newValueHash != x.newValueHash
        ) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        uint256 ends = block.timestamp + x.noticeSeconds;
        if (block.timestamp == 0 || ends > type(uint64).max) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        Recovery.FindingRecord memory item;
        item.terms = p.terms;
        item.governanceActionId = g.actionId;
        item.noticeEndsAt = uint64(ends);
        item.recordedAt = uint64(block.timestamp);
        item.noticeSeconds = x.noticeSeconds;
        item.timingRevision = x.timingRevision;
        item.bindingGeneration = p.binding_.generation;
        item.bindingHash = p.binding_.bindingHash;
        item.recordHash = StreamArtistRecoveryHashes.findingRecord(o.environment, item);
        if (s.records[item.recordHash].recordHash != 0) {
            revert Recovery.InvalidUnavailabilityFinding();
        }
        bytes32 actionKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.governance_action_id"),
            keccak256(abi.encode(g.actionId)),
            item.recordHash
        );
        bytes32 findingKey = _consume(
            replay,
            o,
            keccak256("identity_authority.replay.finding_key"),
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_ARTIST_UNAVAILABILITY_FINDING_KEY_V1"),
                    EU.PROFILE,
                    p.terms.artistId,
                    p.binding_.generation,
                    p.binding_.bindingHash,
                    p.target
                )
            ),
            item.recordHash
        );
        EU.Admission memory admission = EU.Admission(
            p.target,
            p.intent,
            p.coordinatorCodeHash,
            s.activityEpoch[p.terms.artistId],
            keccak256(abi.encode(g))
        );
        s.records[item.recordHash] = item;
        StreamArtistEntropyUnavailabilityStore.state().admissions[item.recordHash] = admission;
        s.latest[
            StreamArtistUnavailabilityState.associationKey(p.terms.artistId, p.terms.collectionId)
        ] = item.recordHash;
        s.hasUncancelledFindings[p.terms.artistId] = true;
        m = StreamArtistUnavailabilityState.Mutation(
            item.recordHash,
            keccak256(abi.encode(p)),
            keccak256(abi.encode(EU.PROFILE, item, admission)),
            keccak256(abi.encode(actionKey, findingKey, item.recordHash))
        );
        emit ArtistUnavailabilityFindingRecorded(
            1,
            p.terms.artistId,
            p.terms.collectionId,
            item.noticeEndsAt,
            item.recordedAt,
            p.terms.evidenceHash,
            p.terms.reasonHash,
            item.recordHash,
            g.actionId
        );
        emit ArtistEntropyUnavailabilityContext(
            1, o.environment.chainId, o.environment.registry, item.recordHash, admission
        );
        return (m, p.terms.artistId, p.terms.collectionId);
    }

    function _binding(
        StreamArtistUnavailabilityState.OwnerContext memory o,
        T.Identity memory principal,
        EU.Input memory p
    ) private view {
        IStreamEntropyArtistUnavailability.Intent memory i = p.intent;
        if (
            !p.binding_.accepted || p.binding_.artistId != p.terms.artistId || p.terms.artistId == 0
                || p.binding_.generation == 0 || p.binding_.bindingHash == 0
                || principal.registeredAt == 0 || principal.status == 0 || p.terms.evidenceHash == 0
                || p.terms.reasonHash == 0 || p.target.coordinator == address(0)
                || p.coordinatorCodeHash == 0 || p.target.unavailableEvidenceHash == 0
                || p.target.recovery.oldRequestKey == 0
                || p.target.recovery.providerEvidenceHash == 0
                || bytes(p.target.recovery.reasonURI).length == 0
                || bytes(p.target.recovery.reasonURI).length > 2048
                || i.collectionId != p.terms.collectionId || i.collectionId == 0
                || (i.tokenId == 0) == (i.scopeId == 0)
                || i.oldRequestKey != p.target.recovery.oldRequestKey || i.newRequestKey == 0
                || i.newRequestKey == i.oldRequestKey || i.journalHead == 0
                || i.contentStateHash == 0 || i.currentContentStateHash == 0
                || i.contentStateHash == i.currentContentStateHash || i.requestPolicyHash == 0
                || i.incidentEvidenceHash == 0
                || i.providerEvidenceHash != p.target.recovery.providerEvidenceHash
                || i.reasonHash != keccak256(bytes(p.target.recovery.reasonURI))
                || p.target.intentHash != EU.intentHash(p.target.coordinator, o.environment.core, i)
                || p.terms.evidenceHash
                    != EU.evidenceHash(
                        o.environment.registry,
                        o.environment.core,
                        p.target,
                        i,
                        p.coordinatorCodeHash
                    )
        ) revert Recovery.InvalidUnavailabilityFinding();
    }

    function _consume(
        mapping(bytes32 => T.ReplayCell) storage replay,
        StreamArtistUnavailabilityState.OwnerContext memory o,
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
        StreamArtistAuthorityCheckpoint.noteReplay(key, replay[key]);
    }
}
