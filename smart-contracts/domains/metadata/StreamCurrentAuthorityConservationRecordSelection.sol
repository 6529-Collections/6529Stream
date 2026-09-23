// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../records/StreamConservationRecordReads.sol";

import {
    StreamCurrentAuthorityConservationRecordContext
} from "../records/StreamCurrentAuthorityConservationRecordContext.sol";
import {
    IStreamRecordCurrentAuthority
} from "../../interfaces/stream/metadata/IStreamRecordCurrentAuthority.sol";

/// @notice Successor-aware original conservation selector preserving original-voice and estate histories.
/// @dev Deploy this profile as the original selector before history/locks. This is not an
/// importer or replacement-address adapter for an already deployed legacy selector.
contract StreamCurrentAuthorityConservationRecordSelection is
    IStreamRecordCurrentAuthority,
    IStreamConservationRecordSelection
{
    address public immutable override core;
    address public immutable override metadata;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    uint256 public immutable override deploymentChainId;
    bytes32 public immutable override coreCodeHash;
    bytes32 public immutable override metadataCodeHash;
    bytes32 public immutable override schemaRegistryCodeHash;
    bytes32 public immutable override chunkStoreCodeHash;
    address[5] private _artists;
    bytes32[5] private _artistCodeHashes;

    struct Stored {
        Selection selected;
        CatalogPin[] catalogs;
    }

    struct LaneProgress {
        uint64[2] indices;
        bool[2] seen;
    }
    mapping(bytes32 => Stored[]) private _history;
    mapping(bytes32 => LaneProgress) private _progress;
    mapping(bytes32 => IntentLock) private _locks;
    mapping(bytes32 => PreparedInterview) private _interviews;

    constructor(address core_, address metadata_, address schemas_) {
        if (core_.code.length == 0 || metadata_.code.length == 0 || schemas_.code.length == 0) {
            revert InvalidConservationConfiguration();
        }
        core = core_;
        metadata = metadata_;
        schemaRegistry = schemas_;
        chunkStore = IStreamSchemaRegistry(schemas_).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidConservationConfiguration();
        deploymentChainId = block.chainid;
        coreCodeHash = core_.codehash;
        metadataCodeHash = metadata_.codehash;
        schemaRegistryCodeHash = schemas_.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        StreamConservationRecordContext.Dependencies memory d =
            StreamConservationRecordContext.pinArtists(_context());
        _artists = d.artists;
        _artistCodeHashes = d.artistCodeHashes;
    }

    function currentAuthorityProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_AUTHORITY_CONSERVATION_SELECTION_V1");
    }

    function currentArtistContext()
        external
        view
        override
        returns (address[5] memory targets, bytes32[5] memory codeHashes)
    {
        StreamConservationRecordContext.Dependencies memory d = _context();
        return (d.artists, d.artistCodeHashes);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamRecordCurrentAuthority).interfaceId
            || id == type(IStreamConservationRecordSelection).interfaceId || id == 0x01ffc9a7;
    }

    function adoptIntent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        IntentWitness calldata witness
    ) external override returns (Selection memory) {
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamConservationRecordContext.definitions(d);
        PreparedInterview memory empty;
        StreamConservationRecordReads.Prepared memory p = StreamConservationRecordReads.intent(
            d, collectionId, subjectId, recordHash, witness, empty
        );
        return _adopt(collectionId, subjectId, expectedHead, expectedRevision, p);
    }

    function adoptWaiver(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        WaiverWitness calldata witness
    ) external override returns (Selection memory) {
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamConservationRecordContext.definitions(d);
        PreparedInterview memory empty;
        StreamConservationRecordReads.Prepared memory p = StreamConservationRecordReads.waiver(
            d, collectionId, subjectId, recordHash, witness, empty
        );
        return _adopt(collectionId, subjectId, expectedHead, expectedRevision, p);
    }

    function prepareInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        InterviewWitness calldata witness
    ) external override returns (PreparedInterview memory p) {
        if (_interviews[recordHash].preparationHash != 0) {
            revert ConservationSelectionConflict();
        }
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamConservationRecordContext.interviewDefinitions(d);
        p = StreamConservationRecordReads.prepareInterview(
            d, collectionId, subjectId, recordHash, witness
        );
        p.preparationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_INTERVIEW_PREPARATION_V1"),
                deploymentChainId,
                address(this),
                core,
                metadata,
                schemaRegistry,
                chunkStore,
                p
            )
        );
        PreparedInterview storage saved = _interviews[recordHash];
        saved.collectionId = p.collectionId;
        saved.subjectId = p.subjectId;
        saved.association = p.association;
        saved.record = p.record;
        saved.preparationHash = p.preparationHash;
        for (uint256 i; i < p.catalogs.length; ++i) {
            saved.catalogs.push(p.catalogs[i]);
        }
        emit ConservationInterviewPrepared(recordHash, msg.sender, p.preparationHash);
    }

    function preparedInterview(bytes32 recordHash)
        external
        view
        override
        returns (PreparedInterview memory)
    {
        return _interviews[recordHash];
    }

    function adoptIntentWithPreparedInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        IntentWitness calldata witness
    ) external override returns (Selection memory) {
        PreparedInterview memory prepared = _prepared(witness.intent.interview.record.recordHash);
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamConservationRecordContext.definitions(d);
        StreamConservationRecordReads.Prepared memory p = StreamConservationRecordReads.intent(
            d, collectionId, subjectId, recordHash, witness, prepared
        );
        return _adopt(collectionId, subjectId, expectedHead, expectedRevision, p);
    }

    function adoptWaiverWithPreparedInterview(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        WaiverWitness calldata witness
    ) external override returns (Selection memory) {
        PreparedInterview memory prepared = _prepared(witness.waiver.interview.record.recordHash);
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamConservationRecordContext.definitions(d);
        StreamConservationRecordReads.Prepared memory p = StreamConservationRecordReads.waiver(
            d, collectionId, subjectId, recordHash, witness, prepared
        );
        return _adopt(collectionId, subjectId, expectedHead, expectedRevision, p);
    }

    function _prepared(bytes32 recordHash) private view returns (PreparedInterview memory p) {
        p = _interviews[recordHash];
        if (p.preparationHash == 0) revert InvalidConservationRecord(recordHash);
    }

    function _adopt(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedHead,
        uint64 expectedRevision,
        StreamConservationRecordReads.Prepared memory p
    ) private returns (Selection memory selected) {
        selected = p.selection;
        bytes32 key = _key(collectionId, subjectId, selected.origin);
        Selection memory previous = currentConservation(collectionId, subjectId, selected.origin);
        if (
            previous.record.recordHash != expectedHead || previous.revision != expectedRevision
                || selected.predecessor != expectedHead || expectedRevision == type(uint64).max
                || block.timestamp > type(uint64).max
        ) revert ConservationSelectionConflict();
        if (
            selected.origin == StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
                && _locks[_scope(collectionId, subjectId)].locked
        ) revert ConservationHeadLocked();
        uint256 lane = uint8(selected.record.kind);
        if (
            lane > 1
                || (_progress[key].seen[lane]
                    && selected.record.recordIndex <= _progress[key].indices[lane])
                || (expectedHead != 0 && selected.record.recordedAt < previous.record.recordedAt)
        ) {
            revert ConservationSelectionConflict();
        }
        selected.submitter = msg.sender;
        selected.revision = expectedRevision + 1;
        selected.selectedAt = uint64(block.timestamp);
        selected.selectionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_CONSERVATION_SELECTION_V1"),
                deploymentChainId,
                address(this),
                core,
                metadata,
                schemaRegistry,
                chunkStore,
                collectionId,
                subjectId,
                selected
            )
        );
        Stored storage next = _history[key].push();
        next.selected = selected;
        for (uint256 i; i < p.catalogs.length; ++i) {
            next.catalogs.push(p.catalogs[i]);
        }
        _progress[key].seen[lane] = true;
        _progress[key].indices[lane] = selected.record.recordIndex;
        emit ConservationRecordSelected(
            collectionId, subjectId, selected.record.recordHash, selected
        );
    }

    function lockArtistIntent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedHead,
        uint64 expectedRevision
    ) external override {
        bytes32 scope = _scope(collectionId, subjectId);
        if (_locks[scope].locked) revert ConservationHeadLocked();
        Selection memory selected = currentConservation(
            collectionId, subjectId, StreamConservationRecordTypes.StatementOrigin.ARTIST_INTENT
        );
        if (
            selected.record.recordHash == 0 || selected.record.recordHash != expectedHead
                || selected.revision != expectedRevision || block.timestamp > type(uint64).max
        ) {
            revert ConservationSelectionConflict();
        }
        StreamConservationRecordContext.Dependencies memory d = _context();
        _requireCurrent(d, collectionId, subjectId, selected);
        StreamConservationRecordContext.requireLocker(
            d, selected.association.artistId, selected.association.identityRecordHash, msg.sender
        );
        IntentLock memory locked = IntentLock(
            true,
            msg.sender,
            selected.association.artistId,
            selected.association.identityRecordHash,
            selected.association.bindingHash,
            selected.association.generation,
            expectedHead,
            expectedRevision,
            uint64(block.timestamp)
        );
        _locks[scope] = locked;
        emit ConservationIntentLocked(collectionId, subjectId, locked);
    }

    function intentLock(uint256 collectionId, bytes32 subjectId)
        external
        view
        override
        returns (IntentLock memory)
    {
        return _locks[_scope(collectionId, subjectId)];
    }

    function currentConservation(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin
    ) public view override returns (Selection memory) {
        Stored[] storage rows = _history[_key(collectionId, subjectId, origin)];
        if (rows.length == 0) {
            Selection memory empty;
            return empty;
        }
        return rows[rows.length - 1].selected;
    }

    function conservationSelectionAt(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision
    ) external view override returns (Selection memory) {
        return _at(collectionId, subjectId, origin, revision).selected;
    }

    function selectionCatalogAt(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision,
        uint256 index
    ) external view override returns (CatalogPin memory) {
        return _at(collectionId, subjectId, origin, revision).catalogs[index];
    }

    function selectionCatalogCount(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision
    ) external view override returns (uint256) {
        return _at(collectionId, subjectId, origin, revision).catalogs.length;
    }

    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        bytes32 expectedHead,
        uint64 expectedRevision
    ) external view override returns (Selection memory selected) {
        selected = currentConservation(collectionId, subjectId, origin);
        if (
            selected.record.recordHash == 0 || selected.record.recordHash != expectedHead
                || selected.revision != expectedRevision
        ) revert ConservationSelectionConflict();
        _requireCurrent(_context(), collectionId, subjectId, selected);
    }

    function _requireCurrent(
        StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId,
        bytes32 subjectId,
        Selection memory selected
    ) private view {
        StreamConservationRecordContext.definitions(d);
        StreamConservationRecordReads.requireSelected(
            d,
            collectionId,
            selected,
            _at(collectionId, subjectId, selected.origin, selected.revision).catalogs
        );
    }

    function _at(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin,
        uint64 revision
    ) private view returns (Stored storage row) {
        Stored[] storage rows = _history[_key(collectionId, subjectId, origin)];
        if (revision == 0 || revision > rows.length) revert ConservationSelectionConflict();
        return rows[revision - 1];
    }

    function _context()
        private
        view
        returns (StreamConservationRecordContext.Dependencies memory d)
    {
        return StreamCurrentAuthorityConservationRecordContext.currentContext(
                [core, metadata, schemaRegistry, chunkStore],
                [coreCodeHash, metadataCodeHash, schemaRegistryCodeHash, chunkStoreCodeHash],
                deploymentChainId
            );
    }

    function _key(
        uint256 collectionId,
        bytes32 subjectId,
        StreamConservationRecordTypes.StatementOrigin origin
    ) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, subjectId, origin));
    }

    function _scope(uint256 collectionId, bytes32 subjectId) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, subjectId));
    }
}
