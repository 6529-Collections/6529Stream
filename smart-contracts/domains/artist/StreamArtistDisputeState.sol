// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeHashes.sol";
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";
import "./StreamArtistPayloadStore.sol";
import "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";

/// @notice Dispute state in the actual Attribution owner; no independent authority or mutable router.
library StreamArtistDisputeState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_ATTRIBUTION_DISPUTES_STORAGE_V1");

    struct Store {
        mapping(bytes32 => AD.Head) heads;
        mapping(bytes32 => AD.Record) records;
        mapping(bytes32 => AD.Resolution) resolutions;
        mapping(bytes32 => bool) evidenceSeen;
    }
    event AttributionDisputeOpened(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed opener,
        uint64 bindingGeneration,
        uint8 openerAuthorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 openedAt,
        bytes32 disputeRecordHash
    );
    event AttributionCounterStatementRecorded(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed disputeRecordHash,
        address indexed signer,
        uint64 bindingGeneration,
        uint8 authorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 recordedAt,
        bytes32 counterStatementRecordHash
    );
    event AttributionDisputeResolved(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed disputeRecordHash,
        uint8 resolution,
        uint8 restoredState,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        bytes32 counterStatementRecordHash,
        bytes32 governanceActionId
    );
    event AttributionDisputeRecordContext(
        uint16 schemaVersion,
        uint256 chainId,
        address registry,
        bytes32 indexed recordHash,
        uint8 disputeAction,
        bytes32 artistId,
        bytes32 bindingHash,
        bytes32 disputeRecordHash,
        bytes32 previousRecordHash,
        bytes32 authorityArtistId,
        bytes32 delegation,
        bytes32 governanceActionId
    );
    event ArtistAttributionStateChanged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        uint8 indexed newState,
        uint64 bindingGeneration,
        uint8 oldState,
        address actor,
        uint8 authorityClass,
        bytes32 recordHash,
        bytes32 reasonHash,
        string reasonURI
    );

    function store() internal pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function key(uint256 id, uint64 generation) internal pure returns (bytes32) {
        return keccak256(abi.encode(id, generation));
    }

    function head(uint256 id, uint64 generation) public view returns (AD.Head memory) {
        return store().heads[key(id, generation)];
    }

    function record(bytes32 hash) public view returns (AD.Record memory) {
        return store().records[hash];
    }

    function resolution(bytes32 action) public view returns (AD.Resolution memory) {
        return store().resolutions[action];
    }

    function readEncoded(bytes calldata data) public view returns (bytes memory) {
        bytes4 sel = bytes4(data[:4]);
        if (sel == IStreamArtistAttributionDisputesOwner.attributionDispute.selector) {
            (uint256 id, uint64 g) = abi.decode(data[4:], (uint256, uint64));
            return abi.encode(head(id, g));
        }
        if (sel == IStreamArtistAttributionDisputesOwner.attributionDisputeRecord.selector) {
            return abi.encode(record(abi.decode(data[4:], (bytes32))));
        }
        if (sel == IStreamArtistAttributionDisputesOwner.attributionDisputeResolution.selector) {
            return abi.encode(resolution(abi.decode(data[4:], (bytes32))));
        }
        revert T.InvalidRecord();
    }

    function applyEncoded(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public returns (AD.Mutation memory m) {
        (
            T.ActionContext memory c,
            AD.Filing memory p,
            AD.Admission memory a,
            uint256 nonce,
            Contest.GovernanceWitness memory g
        ) = abi.decode(
            data[4:], (T.ActionContext, AD.Filing, AD.Admission, uint256, Contest.GovernanceWitness)
        );
        StreamArtistDisputeHashes.validate(p);
        bool opening = p.disputeAction == 1;
        if (
            c.operationId != (opening ? 44 : 45) || a.signer == address(0)
                || a.recordedAt != block.timestamp || a.binding_.generation != p.bindingGeneration
                || a.binding_.artistId == 0 || a.binding_.bindingHash == 0
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        AttrState.Attribution storage current = s.attributions[p.collectionId];
        AD.Head storage h = store().heads[key(p.collectionId, p.bindingGeneration)];
        if (current.generation != p.bindingGeneration) {
            revert AD.InvalidAttributionDispute(p.collectionId);
        }
        uint8 old = current.state;
        bytes32 prior = opening ? h.disputeRecordHash : h.counterStatementRecordHash;
        if (opening) {
            if (
                h.open || (old != 1 && old != 2 && old != 3 && old != 5)
                    || ((old == 1 || old == 5) && g.actionId == 0)
                    || (old == 5 && h.revocationReason != 4)
            ) revert AD.InvalidAttributionDispute(p.collectionId);
            bytes32 evidenceKey =
                keccak256(abi.encode(p.collectionId, p.bindingGeneration, p.evidenceHash));
            if (store().evidenceSeen[evidenceKey]) {
                revert AD.InvalidDisputeEvidence(p.evidenceHash);
            }
            store().evidenceSeen[evidenceKey] = true;
            h.restoreState = old == 5 ? h.restoreState : old;
            h.reopened = old == 5;
            h.open = true;
            h.counterStatementRecordHash = 0;
            current.state = 4;
        } else if (
            old != 4 || !h.open || h.disputeRecordHash == 0 || g.actionId != 0
                || a.standing.artistId != a.binding_.artistId
        ) {
            revert AD.InvalidAttributionDispute(p.collectionId);
        }
        m.record =
            StreamArtistDisputeHashes.record(e, p, a.signer, a.authorityClass, nonce, a.recordedAt);
        if (
            store().records[m.record].recordHash != 0
                || (g.actionId == 0
                        ? a.authorityClass == 0
                        : a.authorityClass != 0 || a.signer != g.proposer || nonce != 0)
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        bytes32 dispute = opening ? m.record : h.disputeRecordHash;
        store().records[m.record] = AD.Record(
            m.record,
            p,
            a.signer,
            a.authorityClass,
            nonce,
            a.recordedAt,
            a.binding_.artistId,
            a.binding_.bindingHash,
            dispute,
            prior,
            a.standing,
            g.actionId
        );
        if (opening) h.disputeRecordHash = m.record;
        else h.counterStatementRecordHash = m.record;
        StreamArtistPayloadStore.preimage(
            m.record,
            StreamArtistDisputeHashes.preimage(
                e, p, a.signer, a.authorityClass, nonce, a.recordedAt
            )
        );
        if (opening) {
            emit AttributionDisputeOpened(
                1,
                p.collectionId,
                a.signer,
                p.bindingGeneration,
                a.authorityClass,
                p.evidenceHash,
                p.reasonHash,
                nonce,
                a.recordedAt,
                m.record
            );
            emit ArtistAttributionStateChanged(
                1,
                p.collectionId,
                4,
                p.bindingGeneration,
                old,
                c.actor,
                a.authorityClass,
                m.record,
                p.reasonHash,
                ""
            );
        } else {
            emit AttributionCounterStatementRecorded(
                1,
                p.collectionId,
                dispute,
                a.signer,
                p.bindingGeneration,
                a.authorityClass,
                p.evidenceHash,
                p.reasonHash,
                nonce,
                a.recordedAt,
                m.record
            );
        }
        emit AttributionDisputeRecordContext(
            1,
            e.chainId,
            e.registry,
            m.record,
            p.disputeAction,
            a.binding_.artistId,
            a.binding_.bindingHash,
            dispute,
            prior,
            a.standing.artistId,
            a.standing.delegation,
            g.actionId
        );
        m.action = keccak256(abi.encode(p, a, nonce, g));
        m.state = keccak256(abi.encode(current, h, store().records[m.record]));
        m.replayScope = keccak256(
            abi.encode(
                p.collectionId,
                p.bindingGeneration,
                opening ? bytes32(0) : dispute,
                a.signer,
                p.evidenceHash,
                p.reasonHash
            )
        );
        m.replayCommitment = m.record;
    }

    function markRepudiated(uint256 id, uint64 generation) public {
        AD.Head storage h = store().heads[key(id, generation)];
        if (h.open) revert AD.InvalidAttributionDispute(id);
        h.revocationReason = 3;
    }

    function resolveEncoded(AttrState.State storage s, bytes calldata data)
        public
        returns (AD.Mutation memory m)
    {
        (
            T.ActionContext memory c,
            AD.ResolutionRequest memory p,
            T.Binding memory b,
            Contest.GovernanceWitness memory g
        ) = abi.decode(
            data[4:], (T.ActionContext, AD.ResolutionRequest, T.Binding, Contest.GovernanceWitness)
        );
        AttrState.Attribution storage current = s.attributions[p.collectionId];
        AD.Head storage h = store().heads[key(p.collectionId, p.bindingGeneration)];
        if (
            block.timestamp > type(uint64).max || c.operationId != 46 || current.state != 4
                || current.generation != p.bindingGeneration || b.generation != p.bindingGeneration
                || b.bindingHash != store().records[h.disputeRecordHash].bindingHash || !h.open
                || p.disputeRecordHash == 0 || p.disputeRecordHash != h.disputeRecordHash
                || p.counterStatementRecordHash != h.counterStatementRecordHash
                || (p.resolution != 1 && p.resolution != 2) || p.evidenceHash == 0
                || p.reasonHash == 0 || g.actionId == 0 || g.proposer == address(0)
                || g.actionClass < (p.resolution == 2 || h.reopened ? 2 : 1) || g.actionClass > 2
                || store().resolutions[g.actionId].actionId != 0
        ) revert AD.InvalidAttributionDispute(p.collectionId);
        uint8 restored = p.resolution == 2 ? 5 : h.restoreState;
        if (restored < 1 || restored > 5 || restored == 4) {
            revert AD.InvalidAttributionDispute(p.collectionId);
        }
        store().resolutions[g.actionId] = AD.Resolution(
            p,
            g.actionId,
            c.actor,
            g.proposer,
            g.actionClass,
            restored,
            uint64(block.timestamp),
            h.resolutionActionId,
            keccak256(abi.encode(g))
        );
        h.resolutionActionId = g.actionId;
        h.open = false;
        h.revocationReason = p.resolution == 2 ? 4 : 0;
        current.state = restored;
        emit AttributionDisputeResolved(
            1,
            p.collectionId,
            p.disputeRecordHash,
            p.resolution,
            restored,
            p.evidenceHash,
            p.reasonHash,
            p.counterStatementRecordHash,
            g.actionId
        );
        emit ArtistAttributionStateChanged(
            1,
            p.collectionId,
            restored,
            p.bindingGeneration,
            4,
            c.actor,
            0,
            p.disputeRecordHash,
            p.reasonHash,
            ""
        );
        m.action = keccak256(abi.encode(p, b, g));
        m.state = keccak256(abi.encode(current, h, store().resolutions[g.actionId]));
        m.replayScope = p.disputeRecordHash;
        m.replayCommitment = g.actionId;
    }
}
