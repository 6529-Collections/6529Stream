// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamArtistRepudiationHashes.sol";
import {
    StreamArtistAttributionStateTypes as AttrState
} from "./StreamArtistAttributionStateTypes.sol";
import "./StreamArtistPayloadStore.sol";

/// @notice Immutable staged exits and explicit terminal state in the sole Attribution owner.
library StreamArtistRepudiationState {
    bytes32 private constant SLOT = keccak256("6529STREAM_ARTIST_ATTRIBUTION_REPUDIATIONS_V1");

    struct State {
        mapping(bytes32 => RP.Record) records;
        mapping(bytes32 => RP.Terminal) terminal;
        mapping(uint256 => bytes32) pending;
        mapping(bytes32 => mapping(bytes32 => uint256)) counts;
    }
    event AttributionRepudiationStaged(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed artistId,
        address indexed signer,
        uint64 bindingGeneration,
        uint8 authorityClass,
        bytes32 evidenceHash,
        bytes32 reasonHash,
        uint256 nonce,
        uint64 stagedAt,
        uint64 executableAt,
        bytes32 repudiationRecordHash
    );
    event AttributionRepudiationVetoed(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed vetoer,
        bytes32 indexed repudiationRecordHash,
        bytes32 reasonHash
    );
    event AttributionRepudiationCancelled(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        address indexed canceller,
        bytes32 indexed repudiationRecordHash,
        uint8 authorityClass
    );
    event AttributionRepudiationContext(
        uint16 schemaVersion,
        uint256 chainId,
        address registry,
        bytes32 indexed repudiationRecordHash,
        bytes32 bindingHash,
        RP.AuthorityHead authorityHead,
        bytes32 capturedGuardianSet,
        uint64 windowRevision
    );
    event AttributionRepudiationInvalidated(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed repudiationRecordHash,
        bytes32 identityHeadHash,
        bytes32 disputeRecordHash
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

    function state() internal pure returns (State storage s) {
        bytes32 slot = SLOT;
        assembly ("memory-safe") { s.slot := slot }
    }

    function record(bytes32 hash) public view returns (RP.Record memory) {
        return state().records[hash];
    }

    function terminal(bytes32 hash) public view returns (RP.Terminal memory) {
        return state().terminal[hash];
    }

    function pending(uint256 id) public view returns (bytes32) {
        return state().pending[id];
    }

    function count(bytes32 id, bytes32 cohort) public view returns (uint256) {
        return state().counts[id][cohort];
    }

    function readEncoded(bytes calldata data) public view returns (bytes memory) {
        bytes4 sel = bytes4(data[:4]);
        if (sel == IStreamArtistRepudiationOwner.rawPendingRepudiation.selector) {
            return abi.encode(pending(abi.decode(data[4:], (uint256))));
        }
        if (sel == IStreamArtistRepudiationOwner.attributionRepudiationRecord.selector) {
            return abi.encode(record(abi.decode(data[4:], (bytes32))));
        }
        if (sel == IStreamArtistRepudiationOwner.attributionRepudiationTerminal.selector) {
            return abi.encode(terminal(abi.decode(data[4:], (bytes32))));
        }
        if (sel == IStreamArtistRepudiationOwner.repudiationCount.selector) {
            (bytes32 id, bytes32 cohort) = abi.decode(data[4:], (bytes32, bytes32));
            return abi.encode(count(id, cohort));
        }
        revert T.InvalidRecord();
    }

    function stage(
        AttrState.State storage attribution,
        StreamArtistHashes.Environment memory e,
        T.ActionContext memory c,
        AD.Filing memory p,
        RP.Admission memory a,
        uint256 nonce
    ) public returns (RP.Mutation memory m) {
        StreamArtistRepudiationHashes.validate(p);
        AttrState.Attribution storage current = attribution.attributions[p.collectionId];
        if (
            c.operationId != 47 || current.generation != p.bindingGeneration
                || (current.state != 2 && current.state != 3)
                || a.binding_.generation != p.bindingGeneration || a.binding_.artistId == 0
                || !a.binding_.accepted || a.binding_.bindingHash == 0
                || a.authorityHead.principal == address(0)
                || (a.authorityHead.authorityClass != 1
                    && a.authorityHead.authorityClass != 3
                    && a.authorityHead.authorityClass != 4) || a.stagedAt != block.timestamp
                || a.executableAt <= a.stagedAt || a.windowRevision == 0
        ) revert RP.InvalidRepudiation(0);
        State storage s = state();
        bytes32 cohort = StreamArtistRepudiationHashes.headHash(a.authorityHead);
        bytes32 prior = s.pending[p.collectionId];
        if (prior != 0 && s.terminal[prior].phase == 1) {
            RP.Record storage old = s.records[prior];
            if (
                old.artistId == a.binding_.artistId
                    && old.terms.bindingGeneration == p.bindingGeneration
                    && old.bindingHash == a.binding_.bindingHash
                    && StreamArtistRepudiationHashes.headHash(old.authorityHead) == cohort
            ) revert RP.ActiveRepudiation(a.binding_.artistId);
            _invalidate(old, cohort, 0);
        }
        RP.Record memory next = RP.Record(
            0,
            p,
            a.binding_.artistId,
            a.authorityHead.principal,
            a.authorityHead.authorityClass,
            nonce,
            a.stagedAt,
            a.executableAt,
            a.binding_.bindingHash,
            a.authorityHead,
            a.guardianSet,
            a.windowRevision
        );
        next.recordHash = StreamArtistRepudiationHashes.recordHash(e, next);
        if (s.records[next.recordHash].recordHash != 0) {
            revert RP.InvalidRepudiation(next.recordHash);
        }
        s.records[next.recordHash] = next;
        s.terminal[next.recordHash] = RP.Terminal(1, address(0), 0, 0);
        s.pending[p.collectionId] = next.recordHash;
        ++s.counts[next.artistId][cohort];
        StreamArtistPayloadStore.preimage(
            next.recordHash, StreamArtistRepudiationHashes.preimage(e, next)
        );
        emit AttributionRepudiationStaged(
            1,
            p.collectionId,
            next.artistId,
            next.signer,
            p.bindingGeneration,
            next.authorityClass,
            p.evidenceHash,
            p.reasonHash,
            nonce,
            next.stagedAt,
            next.executableAt,
            next.recordHash
        );
        emit AttributionRepudiationContext(
            1,
            e.chainId,
            e.registry,
            next.recordHash,
            next.bindingHash,
            next.authorityHead,
            next.capturedGuardianSet,
            next.windowRevision
        );
        m.record = next.recordHash;
        m.action = keccak256(abi.encode(p, a, nonce));
        m.state = keccak256(
            abi.encode(
                prior, next, s.terminal[next.recordHash], cohort, s.counts[next.artistId][cohort]
            )
        );
        m.replayScope = next.recordHash;
        m.replayCommitment = next.recordHash;
    }

    function veto(T.ActionContext memory c, RP.Record memory r, RP.GuardianProof memory proof)
        public
        returns (RP.Mutation memory m)
    {
        _requirePending(r);
        if (
            c.operationId != 48 || proof.collectionId != r.terms.collectionId
                || proof.repudiationRecordHash != r.recordHash || proof.vetoer != c.actor
                || proof.reasonHash == 0 || proof.vetoedAt != block.timestamp
                || proof.capturedGuardianSet != r.capturedGuardianSet
        ) revert RP.InvalidRepudiation(r.recordHash);
        _end(r, 2, c.actor, proof.reasonHash);
        emit AttributionRepudiationVetoed(
            1, r.terms.collectionId, c.actor, r.recordHash, proof.reasonHash
        );
        return _mutation(r, keccak256(abi.encode(c.actor, proof)), 2, proof.reasonHash);
    }

    function cancel(T.ActionContext memory c, RP.Record memory r)
        public
        returns (RP.Mutation memory m)
    {
        _requirePending(r);
        if (c.operationId != 49 || c.actor != r.signer) revert T.Unauthorized(c.actor);
        _end(r, 3, c.actor, 0);
        emit AttributionRepudiationCancelled(
            1, r.terms.collectionId, c.actor, r.recordHash, r.authorityClass
        );
        return _mutation(r, keccak256(abi.encode(c.actor, r.recordHash)), 3, 0);
    }

    function execute(
        AttrState.State storage attribution,
        T.ActionContext memory c,
        RP.Record memory r
    ) public returns (RP.Mutation memory m) {
        _requirePending(r);
        AttrState.Attribution storage current = attribution.attributions[r.terms.collectionId];
        if (
            c.operationId != 50 || block.timestamp < r.executableAt
                || current.generation != r.terms.bindingGeneration
                || (current.state != 2 && current.state != 3)
        ) revert RP.RepudiationNotExecutable(r.recordHash);
        uint8 old = current.state;
        _end(r, 4, c.actor, r.terms.reasonHash);
        current.state = 5;
        emit ArtistAttributionStateChanged(
            1,
            r.terms.collectionId,
            5,
            r.terms.bindingGeneration,
            old,
            c.actor,
            r.authorityClass,
            r.recordHash,
            r.terms.reasonHash,
            ""
        );
        m = _mutation(r, keccak256(abi.encode(c.actor, r.recordHash)), 4, r.terms.reasonHash);
        m.state = keccak256(abi.encode(m.state, current, uint8(3)));
    }

    function invalidateByDispute(uint256 id, bytes32 dispute) public returns (bytes32 delta) {
        State storage s = state();
        bytes32 hash = s.pending[id];
        if (hash == 0 || s.terminal[hash].phase != 1) return 0;
        RP.Record memory r = s.records[hash];
        _invalidate(r, 0, dispute);
        return keccak256(abi.encode(hash, dispute, s.terminal[hash]));
    }

    function _invalidate(RP.Record memory r, bytes32 currentHead, bytes32 dispute) private {
        _end(r, 5, address(0), dispute);
        emit AttributionRepudiationInvalidated(
            1, r.terms.collectionId, r.recordHash, currentHead, dispute
        );
    }

    function _requirePending(RP.Record memory r) private view {
        State storage s = state();
        if (
            r.recordHash == 0 || s.pending[r.terms.collectionId] != r.recordHash
                || s.terminal[r.recordHash].phase != 1
                || keccak256(abi.encode(s.records[r.recordHash])) != keccak256(abi.encode(r))
        ) revert RP.InvalidRepudiation(r.recordHash);
    }

    function _end(RP.Record memory r, uint8 phase, address actor, bytes32 reason) private {
        if (block.timestamp > type(uint64).max) revert T.InvalidRecord();
        State storage s = state();
        bytes32 cohort = StreamArtistRepudiationHashes.headHash(r.authorityHead);
        if (s.counts[r.artistId][cohort] == 0) revert RP.InvalidRepudiation(r.recordHash);
        --s.counts[r.artistId][cohort];
        delete s.pending[r.terms.collectionId];
        s.terminal[r.recordHash] = RP.Terminal(phase, actor, reason, uint64(block.timestamp));
    }

    function _mutation(RP.Record memory r, bytes32 action, uint8 phase, bytes32 reason)
        private
        view
        returns (RP.Mutation memory m)
    {
        State storage s = state();
        bytes32 cohort = StreamArtistRepudiationHashes.headHash(r.authorityHead);
        m.action = action;
        m.state =
            keccak256(abi.encode(r, s.terminal[r.recordHash], cohort, s.counts[r.artistId][cohort]));
        m.replayScope = r.recordHash;
        m.replayCommitment = keccak256(abi.encode(r.recordHash, phase, reason));
    }
}
