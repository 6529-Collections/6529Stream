// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../records/StreamWorkRecordReads.sol";

/// @notice Fixed authoritative WORK head with separate artist-record adoption and curator grants.
/// @dev Only static dependency calls precede the one append. No publisher grants, nonces or
///      deadlines are modified; raw selected history is independent of later provider health.
contract StreamWorkRecordSelection is IStreamWorkRecordSelection {
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
    mapping(bytes32 => Selection[]) private _history;

    constructor(address core_, address metadata_, address schemas_) {
        if (core_.code.length == 0 || metadata_.code.length == 0 || schemas_.code.length == 0) {
            revert InvalidWorkConfiguration();
        }
        core = core_;
        metadata = metadata_;
        schemaRegistry = schemas_;
        chunkStore = IStreamSchemaRegistry(schemas_).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidWorkConfiguration();
        deploymentChainId = block.chainid;
        coreCodeHash = core_.codehash;
        metadataCodeHash = metadata_.codehash;
        schemaRegistryCodeHash = schemas_.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        // Registration can follow deployment. Graph identities are fixed immediately.
        StreamWorkRecordContext.Dependencies memory d =
            StreamWorkRecordContext.pinArtists(_context());
        _artists = d.artists;
        _artistCodeHashes = d.artistCodeHashes;
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamWorkRecordSelection).interfaceId || id == 0x01ffc9a7;
    }

    function selectCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external override returns (Selection memory) {
        return _select(
            collectionId,
            subjectId,
            recordHash,
            expectedHead,
            expectedRevision,
            witness,
            AdoptionMode.CURATOR_GRANT
        );
    }

    function adoptArtistRecord(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external override returns (Selection memory) {
        return _select(
            collectionId,
            subjectId,
            recordHash,
            expectedHead,
            expectedRevision,
            witness,
            AdoptionMode.ARTIST_RECORD_ADOPTION
        );
    }

    function _select(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness,
        AdoptionMode mode
    ) private returns (Selection memory selected) {
        Selection memory previous = currentWork(collectionId, subjectId);
        if (
            previous.recordHash != expectedHead || previous.revision != expectedRevision
                || witness.description.predecessor != expectedHead
                || expectedRevision == type(uint64).max || block.timestamp > type(uint64).max
        ) revert WorkSelectionConflict();
        StreamWorkRecordContext.Dependencies memory d = _context();
        Selection memory authority;
        if (mode == AdoptionMode.CURATOR_GRANT) {
            (authority.selectorAuthorizationClass, authority.grantScope, authority.grantRevision) =
                StreamWorkRecordReads.curatorAuthority(d, collectionId, msg.sender);
        }
        StreamWorkRecordContext.definitions(d);
        selected = StreamWorkRecordReads.recorded(d, collectionId, subjectId, recordHash, witness);
        if (mode == AdoptionMode.ARTIST_RECORD_ADOPTION && selected.recorderAuthorizationClass != 1)
        revert WorkSelectionAuthorityRequired();
        if (expectedHead != 0 && selected.recordIndex <= previous.recordIndex) {
            revert WorkSelectionConflict();
        }
        selected.submitter = msg.sender;
        selected.mode = mode;
        selected.selectorAuthorizationClass = authority.selectorAuthorizationClass;
        selected.grantScope = authority.grantScope;
        selected.grantRevision = authority.grantRevision;
        selected.revision = expectedRevision + 1;
        selected.selectedAt = uint64(block.timestamp);
        selected.selectionHash = _selectionHash(collectionId, subjectId, selected);
        _history[_key(collectionId, subjectId)].push(selected);
        emit WorkRecordSelected(collectionId, subjectId, recordHash, selected);
    }

    function _selectionHash(uint256 collectionId, bytes32 subjectId, Selection memory selected)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_WORK_SELECTION_V1"),
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
    }

    function currentWork(uint256 collectionId, bytes32 subjectId)
        public
        view
        override
        returns (Selection memory)
    {
        Selection[] storage rows = _history[_key(collectionId, subjectId)];
        if (rows.length == 0) {
            Selection memory empty;
            return empty;
        }
        return rows[rows.length - 1];
    }

    function workSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        override
        returns (Selection memory)
    {
        Selection[] storage rows = _history[_key(collectionId, subjectId)];
        if (revision == 0 || revision > rows.length) revert WorkSelectionConflict();
        return rows[revision - 1];
    }

    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external view override returns (Selection memory selected) {
        selected = currentWork(collectionId, subjectId);
        if (
            selected.recordHash == 0 || selected.recordHash != expectedRecord
                || selected.revision != expectedRevision
        ) revert WorkSelectionConflict();
        StreamWorkRecordContext.Dependencies memory d = _context();
        StreamWorkRecordContext.definitions(d);
        StreamWorkRecordReads.requireSelectedAssociation(d, collectionId, selected);
    }

    function _context() private view returns (StreamWorkRecordContext.Dependencies memory d) {
        d.targets = [core, metadata, schemaRegistry, chunkStore];
        d.codeHashes = [coreCodeHash, metadataCodeHash, schemaRegistryCodeHash, chunkStoreCodeHash];
        d.artists = _artists;
        d.artistCodeHashes = _artistCodeHashes;
        d.chainId = deploymentChainId;
        return StreamWorkRecordContext.currentContext(d);
    }

    function _key(uint256 collectionId, bytes32 subjectId) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, subjectId));
    }
}
