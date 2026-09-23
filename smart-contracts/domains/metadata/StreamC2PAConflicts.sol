// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamC2PAConflicts as C
} from "../../interfaces/stream/metadata/IStreamC2PAConflicts.sol";
import {
    IStreamC2PAReconciliation as R
} from "../../interfaces/stream/metadata/IStreamC2PAReconciliation.sol";
import {
    StreamArtistAttributionDisputeTypes as AD,
    IStreamArtistAttributionDisputesOwner as A
} from "../../interfaces/stream/artist/IStreamArtistAttributionDisputes.sol";
import {
    IStreamArtistEstateBinding
} from "../../interfaces/stream/artist/IStreamArtistEstateOwner.sol";
import {
    IStreamCollectionArchivalCoverage as Archive
} from "../../interfaces/stream/preservation/IStreamCollectionArchivalCoverage.sol";
import {
    StreamArchivalTypes as Archival
} from "../../interfaces/stream/preservation/StreamArchivalTypes.sol";
import { StreamSchemaDocumentStore } from "./StreamSchemaDocumentStore.sol";

/// @notice Fixed conflict producer/disposition verifier. Original Artist writes and domains are untouched.
library StreamC2PAConflicts {
    bytes32 internal constant DOMAIN = keccak256("6529STREAM_C2PA_STANDING_CONFLICT_V1");
    bytes32 internal constant CHAIN = keccak256("6529STREAM_C2PA_CONFLICT_CHAIN_V1");
    bytes32 internal constant DISPOSITION = keccak256("6529STREAM_C2PA_DISPUTE_DISPOSITION_V1");

    struct Head {
        bytes32 latest;
        bytes32 chain;
        bytes32 tail;
        uint64 revision;
        uint64 openCount;
    }

    struct Links {
        bytes32 previous;
        bytes32 next;
    }

    struct Store {
        mapping(bytes32 => Head) heads;
        mapping(bytes32 => C.Conflict) records;
        mapping(bytes32 => C.Resolution) resolutions;
        mapping(bytes32 => Links) links;
        mapping(bytes32 => mapping(uint64 => bytes32)) history;
    }

    struct Environment {
        uint256 chainId;
        address core;
        address artist;
        address attribution;
        address chunks;
        uint256 readGas;
    }
    event C2PAConflictRecorded(
        bytes32 indexed conflictId,
        uint256 indexed collectionId,
        bytes32 indexed subjectId,
        C.Conflict conflict
    );
    event C2PAConflictCleared(
        bytes32 indexed conflictId, bytes32 indexed actionId, C.Resolution resolution
    );

    function note(Store storage s, address core, address artist, R.Selection memory selected)
        public
    {
        if (
            !selected.report.assertsAuthorship
                || selected.report.authorship != R.AuthorshipStatus.DIVERGENT
        ) return;
        if (block.timestamp > type(uint64).max) revert C.InvalidC2PAConflict();
        bytes32 key = keccak256(abi.encode(selected.report.collectionId, selected.report.subjectId));
        Head storage h = s.heads[key];
        C.Conflict memory c = C.Conflict(
            0,
            selected.report.collectionId,
            selected.report.subjectId,
            selected.report.artistId,
            selected.report.bindingHash,
            selected.report.generation,
            selected.recordHash,
            selected.selectionHash,
            h.latest,
            0,
            h.revision + 1,
            uint64(block.timestamp)
        );
        c.conflictId = keccak256(abi.encode(DOMAIN, block.chainid, address(this), core, artist, c));
        c.chainHash = keccak256(abi.encode(CHAIN, h.chain, c.conflictId, c.revision));
        if (s.records[c.conflictId].conflictId != 0) revert C.InvalidC2PAConflict();
        s.records[c.conflictId] = c;
        s.history[key][c.revision] = c.conflictId;
        s.links[c.conflictId].previous = h.tail;
        if (h.tail != 0) s.links[h.tail].next = c.conflictId;
        h.latest = c.conflictId;
        h.chain = c.chainHash;
        h.tail = c.conflictId;
        h.revision = c.revision;
        ++h.openCount;
        emit C2PAConflictRecorded(c.conflictId, c.collectionId, c.subjectId, c);
    }

    function narrative(Environment memory e, C.Conflict memory c)
        public
        view
        returns (bytes memory)
    {
        if (c.conflictId == 0) revert C.InvalidC2PAConflict();
        // Disposition 1 expressly resolves THIS adverse record, not a generic attribution ruling.
        return abi.encode(
            DISPOSITION,
            e.chainId,
            address(this),
            e.core,
            e.artist,
            c.collectionId,
            c.subjectId,
            c.artistId,
            c.bindingHash,
            c.generation,
            c.conflictId,
            c.chainHash,
            c.recordHash,
            c.selectionHash,
            uint8(1)
        );
    }

    function clear(Store storage s, Environment memory e, bytes32 id, bytes32 action) public {
        C.Conflict memory c = s.records[id];
        if (
            c.conflictId == 0 || action == 0 || s.resolutions[id].actionId != 0
                || e.chainId != block.chainid || block.timestamp > type(uint64).max
        ) revert C.InvalidC2PAConflict();
        AD.Resolution memory r = abi.decode(
            _read(e, e.attribution, abi.encodeCall(A.attributionDisputeResolution, (action)), 480),
            (AD.Resolution)
        );
        AD.Head memory h = abi.decode(
            _read(
                e,
                e.attribution,
                abi.encodeCall(A.attributionDispute, (c.collectionId, c.generation)),
                224
            ),
            (AD.Head)
        );
        AD.Record memory opening = abi.decode(
            _read(
                e,
                e.attribution,
                abi.encodeCall(A.attributionDisputeRecord, (r.terms.disputeRecordHash)),
                608
            ),
            (AD.Record)
        );
        if (
            r.actionId != action || r.terms.collectionId != c.collectionId
                || r.terms.bindingGeneration != c.generation || r.terms.disputeRecordHash == 0
                || (r.terms.resolution != 1 && r.terms.resolution != 2)
                || r.actionClass < (r.terms.resolution == 2 ? 2 : 1) || r.actionClass > 2
                || r.actor == address(0) || r.proposer == address(0) || r.witnessHash == 0
                || r.resolvedAt < c.recordedAt || r.resolvedAt == 0 || h.open
                || h.disputeRecordHash != r.terms.disputeRecordHash
                || h.resolutionActionId != action || opening.recordHash != r.terms.disputeRecordHash
                || opening.terms.disputeAction != 1 || opening.terms.collectionId != c.collectionId
                || opening.terms.bindingGeneration != c.generation
                || opening.bindingHash != c.bindingHash || opening.artistId != c.artistId
        ) revert C.InvalidC2PAConflict();
        bytes memory raw = _chunk(e, r.terms.evidenceHash);
        if (raw.length != 192) revert C.InvalidC2PAConflict();
        AD.Evidence memory evidence = abi.decode(raw, (AD.Evidence));
        if (
            evidence.schemaVersion != 1 || evidence.collectionId != c.collectionId
                || evidence.bindingGeneration != c.generation
                || evidence.bindingHash != c.bindingHash
                || evidence.disputeRecordHash != r.terms.disputeRecordHash
                || keccak256(raw) != keccak256(abi.encode(evidence))
        ) revert C.InvalidC2PAConflict();
        bytes memory intended = narrative(e, c);
        if (
            evidence.narrativeHash != keccak256(intended)
                || keccak256(_chunk(e, evidence.narrativeHash)) != keccak256(intended)
        ) revert C.InvalidC2PAConflict();
        address coverage = abi.decode(
            _read(e, e.artist, abi.encodeCall(IStreamArtistEstateBinding.archivalCoverage, ()), 32),
            (address)
        );
        bytes32 pin = abi.decode(
            _read(
                e,
                e.artist,
                abi.encodeCall(IStreamArtistEstateBinding.archivalCoverageCodeHash, ()),
                32
            ),
            (bytes32)
        );
        if (coverage.code.length == 0 || coverage.codehash != pin) revert C.InvalidC2PAConflict();
        Archival.CoverageFacts memory f = abi.decode(
            _read(
                e,
                coverage,
                abi.encodeCall(
                    Archive.requireCollectionEvidence, (c.collectionId, r.terms.evidenceHash)
                ),
                384
            ),
            (Archival.CoverageFacts)
        );
        if (
            f.artistId != 0 || f.evidenceHash != r.terms.evidenceHash || f.coverageRecordHash == 0
                || f.envelopeHash == 0
        ) revert C.InvalidC2PAConflict();
        C.Resolution memory resolution = C.Resolution(
            action,
            r.terms.disputeRecordHash,
            r.terms.evidenceHash,
            evidence.narrativeHash,
            uint64(block.timestamp)
        );
        s.resolutions[id] = resolution;
        Head storage head = s.heads[keccak256(abi.encode(c.collectionId, c.subjectId))];
        Links memory links = s.links[id];
        if (links.previous != 0) s.links[links.previous].next = links.next;
        if (links.next != 0) s.links[links.next].previous = links.previous;
        if (head.tail == id) head.tail = links.previous;
        --head.openCount;
        emit C2PAConflictCleared(id, action, resolution);
    }

    function _chunk(Environment memory e, bytes32 hash) private view returns (bytes memory value) {
        bytes memory raw =
            _read(e, e.chunks, abi.encodeCall(StreamSchemaDocumentStore.readChunk, (hash)), 0);
        value = abi.decode(raw, (bytes));
        if (
            hash == 0 || value.length == 0 || value.length > 8192 || keccak256(value) != hash
                || keccak256(raw) != keccak256(abi.encode(value))
        ) revert C.InvalidC2PAConflict();
    }

    function _read(Environment memory e, address target, bytes memory input, uint256 exact)
        private
        view
        returns (bytes memory out)
    {
        uint256 maximum = exact == 0 ? 8256 : exact;
        uint256 cap = e.readGas;
        if (cap == 0 || cap > type(uint256).max / 64 || gasleft() <= cap + cap / 63 + 10000) {
            revert C.C2PAConflictRead(target);
        }
        out = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(out, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > maximum || (exact != 0 && size != exact)) {
            revert C.C2PAConflictRead(target);
        }
        assembly ("memory-safe") { mstore(out, size) }
    }
}
