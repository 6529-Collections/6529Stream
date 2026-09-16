// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistDisputeState.sol";
import "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";
import {
    StreamArtistDisputeWithdrawalTypes as W
} from "../../interfaces/stream/artist/IStreamArtistDisputeWithdrawal.sol";

/// @notice Append-only outcomes alongside the unchanged original dispute store and Head ABI.
library StreamArtistDisputeWithdrawalState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_DISPUTE_WITHDRAWALS_STORAGE_V1");

    struct Store {
        mapping(bytes32 => W.Outcome) outcomes;
    }
    event AttributionDisputeWithdrawn(
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
        bytes32 withdrawalRecordHash,
        bytes32 counterStatementRecordHash,
        uint8 restoredState
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

    function store() private pure returns (Store storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function outcome(bytes32 opening) public view returns (W.Outcome memory) {
        return store().outcomes[opening];
    }

    function applyEncoded(
        AttrState.State storage s,
        StreamArtistHashes.Environment memory e,
        bytes calldata data
    ) public returns (AD.Mutation memory m) {
        (T.ActionContext memory c, AD.Filing memory p, AD.Admission memory a, uint256 nonce) =
            abi.decode(data[4:], (T.ActionContext, AD.Filing, AD.Admission, uint256));
        StreamArtistDisputeHashes.validateWithdrawal(p);
        AttrState.Attribution storage current = s.attributions[p.collectionId];
        StreamArtistDisputeState.Store storage ds = StreamArtistDisputeState.store();
        AD.Head storage h =
            ds.heads[StreamArtistDisputeState.key(p.collectionId, p.bindingGeneration)];
        AD.Record storage opening = ds.records[h.disputeRecordHash];
        if (
            c.operationId != 61 || current.state != 4 || current.generation != p.bindingGeneration
                || !h.open || h.reopened || h.restoreState < 2 || h.restoreState > 3
                || opening.recordHash == 0 || opening.recordHash != h.disputeRecordHash
                || opening.terms.disputeAction != 1 || opening.governanceActionId != 0
                || a.authorityClass == 0 || a.authorityClass != opening.authorityClass
                || a.signer != opening.signer || a.recordedAt != block.timestamp
                || a.binding_.generation != p.bindingGeneration
                || a.binding_.bindingHash != opening.bindingHash
                || a.binding_.artistId != opening.artistId
                || keccak256(abi.encode(a.standing)) != keccak256(abi.encode(opening.standing))
                || store().outcomes[h.disputeRecordHash].recordHash != 0
        ) {
            revert AD.InvalidAttributionDispute(p.collectionId);
        }
        m.record =
            StreamArtistDisputeHashes.record(e, p, a.signer, a.authorityClass, nonce, a.recordedAt);
        if (ds.records[m.record].recordHash != 0) {
            revert AD.InvalidAttributionDispute(p.collectionId);
        }
        bytes32 prior =
            h.counterStatementRecordHash == 0 ? h.disputeRecordHash : h.counterStatementRecordHash;
        ds.records[m.record] = AD.Record(
            m.record,
            p,
            a.signer,
            a.authorityClass,
            nonce,
            a.recordedAt,
            a.binding_.artistId,
            a.binding_.bindingHash,
            h.disputeRecordHash,
            prior,
            a.standing,
            0
        );
        W.Outcome memory result = W.Outcome(m.record, h.counterStatementRecordHash, h.restoreState);
        store().outcomes[h.disputeRecordHash] = result;
        current.state = h.restoreState;
        h.open = false;
        h.revocationReason = 0;
        StreamArtistPayloadStore.preimage(
            m.record,
            StreamArtistDisputeHashes.preimage(
                e, p, a.signer, a.authorityClass, nonce, a.recordedAt
            )
        );
        emit AttributionDisputeWithdrawn(
            1,
            p.collectionId,
            h.disputeRecordHash,
            a.signer,
            p.bindingGeneration,
            a.authorityClass,
            p.evidenceHash,
            p.reasonHash,
            nonce,
            a.recordedAt,
            m.record,
            result.counterStatementRecordHash,
            result.restoredState
        );
        emit ArtistAttributionStateChanged(
            1,
            p.collectionId,
            current.state,
            p.bindingGeneration,
            4,
            c.actor,
            a.authorityClass,
            m.record,
            p.reasonHash,
            ""
        );
        emit AttributionDisputeRecordContext(
            1,
            e.chainId,
            e.registry,
            m.record,
            2,
            a.binding_.artistId,
            a.binding_.bindingHash,
            h.disputeRecordHash,
            prior,
            a.standing.artistId,
            a.standing.delegation,
            0
        );
        m.action = keccak256(abi.encode(p, a, nonce, result));
        m.state = keccak256(abi.encode(current, h, ds.records[m.record], result));
        m.replayScope = h.disputeRecordHash;
        m.replayCommitment = m.record;
    }
}
