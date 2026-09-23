// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../records/StreamMediaMasterReads.sol";
import "../records/StreamMasterWaiverJson.sol";
import "../parameters/StreamGasParameterHost.sol";
import "./StreamMetadataSubjects.sol";
import "../../interfaces/stream/metadata/IStreamMediaMasterSelection.sol";

/// @notice Authenticated media master or original artist waiver, over explicit shared media slots.
/// @dev Retains originals and lineage. This producer cannot prove opaque/token-specific media closure
/// or platform archives; it fails closed for these profiles. No archive is inferred from a URI.
contract StreamMediaMasterSelection is StreamGasParameterHost, IStreamMediaMasterSelection {
    address public immutable override core;
    address public immutable override metadata;
    address public immutable override schemaRegistry;
    address public immutable override externalCoverage;
    address public immutable chunkStore;
    uint256 public immutable deploymentChainId;
    bytes32 public constant override profileHash = StreamMediaMasterDefinitions.PROFILE_HASH;
    bytes32[4] private _codeHashes;
    address[5] private _artists;
    bytes32[5] private _artistCodeHashes;
    bytes32 private immutable _coverageCodeHash;
    bytes32 private constant _MANIFEST_GAS = keccak256("6529STREAM_GGP_MEDIA_MASTER_MANIFEST_READ_GAS");
    bytes32 private constant _COVERAGE_GAS = keccak256("6529STREAM_GGP_MEDIA_MASTER_COVERAGE_READ_GAS");
    mapping(bytes32 => StreamMediaMasterTypes.Selection[]) private _history;

    constructor(address core_, address metadata_, address schemas_, address coverage_,
        address executor, GasParameterConfig memory manifestRead, GasParameterConfig memory coverageRead)
        StreamGasParameterHost(executor)
    {
        if (core_.code.length == 0 || metadata_.code.length == 0 || schemas_.code.length == 0
            || coverage_.code.length == 0
            || keccak256(bytes(manifestRead.name)) != keccak256("MEDIA_MASTER_MANIFEST_READ_GAS")
            || manifestRead.floor < 500000 || manifestRead.failureClass != 2
            || keccak256(bytes(coverageRead.name)) != keccak256("MEDIA_MASTER_COVERAGE_READ_GAS")
            || coverageRead.floor < 500000 || coverageRead.failureClass != 2) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
        core = core_;
        metadata = metadata_;
        schemaRegistry = schemas_;
        externalCoverage = coverage_;
        chunkStore = IStreamSchemaRegistry(schemas_).chunkStore();
        deploymentChainId = block.chainid;
        _codeHashes = [core_.codehash, metadata_.codehash, schemas_.codehash, chunkStore.codehash];
        _coverageCodeHash = coverage_.codehash;
        _registerGasParameter(manifestRead);
        _registerGasParameter(coverageRead);
        StreamConservationRecordContext.Dependencies memory d =
            StreamConservationRecordContext.pinArtists(_context());
        _artists = d.artists;
        _artistCodeHashes = d.artistCodeHashes;
        bytes memory raw = StreamMediaMasterReads.read(coverage_,
            abi.encodeCall(IStreamGasParameterHost.governanceAuthority, ()), 32, d.readGas);
        if (raw.length != 32 || abi.decode(raw, (address)) != executor
            || IStreamExternalArtifactCoverage(coverage_).core() != core_
            || !IStreamExternalArtifactCoverage(coverage_).supportsInterface(type(IStreamExternalArtifactCoverage).interfaceId)) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamMediaMasterSelection).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId;
    }

    function mediaObjectId(uint256 collectionId, bytes32 subjectId, bytes32 manifestHash,
        uint8 slot, bytes32 displayHash) public view override returns (bytes32)
    {
        if (collectionId == 0 || subjectId == 0 || manifestHash == 0 || slot == 0 || slot > 3
            || displayHash == 0) revert StreamMediaMasterTypes.InvalidMasterWitness();
        return keccak256(abi.encode(keccak256("6529STREAM_MEDIA_MASTER_SLOT_V1"),
            deploymentChainId, core, metadata, collectionId, subjectId, manifestHash, slot, displayHash));
    }

    function collectionMediaContext(uint256 collectionId) external view override returns (
        bytes32 subjectId, bytes32 manifestHash, bytes32 inventoryHash, uint8 occupiedMask)
    {
        subjectId = StreamMetadataSubjects.scopeSubject(deploymentChainId, core,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0));
        _subject(collectionId, subjectId);
        bytes32[3] memory hashes;
        (manifestHash, hashes, inventoryHash) = StreamMediaMasterReads.media(_context(), collectionId,
            _gasParameterValue(_MANIFEST_GAS));
        for (uint8 i; i < 3; ++i) { if (hashes[i] != 0) occupiedMask |= uint8(1 << i); }
    }

    function adoptMaster(uint256 collectionId, bytes32 recordHash, uint64 expectedRevision,
        IStreamPreservationRecords.CollectionRecord calldata original,
        StreamMediaMasterTypes.Master calldata witness)
        external override returns (StreamMediaMasterTypes.Selection memory s)
    {
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamMediaMasterReads.definitions(d, false);
        s = _selection(d, collectionId, witness.subjectId, witness.selectedMediaManifestHash,
            witness.mediaSlot);
        if (s.displayHash != witness.displayHash) revert StreamMediaMasterTypes.InvalidMasterWitness();
        s.original = StreamMediaMasterPublicationReads.recorded(d, collectionId, witness.subjectId,
            recordHash, original, false);
        StreamRecordJson.requirePayload(StreamMasterWaiverJson.master(witness),
            StreamMediaMasterPublicationReads.payload(d, recordHash, s.original.payloadHash));
        s.status = StreamMediaMasterTypes.Status.PRESENT;
        s.masterRole = witness.masterRole;
        s.masterObjectHash = witness.masterObjectHash;
        s.coverageHash = witness.coverageHash;
        s.predecessor = witness.predecessor;
        StreamMediaMasterReads.coverage(externalCoverage, _coverageCodeHash, d, s,
            _gasParameterValue(_COVERAGE_GAS));
        return _adopt(collectionId, expectedRevision, s);
    }

    function adoptWaiver(uint256 collectionId, uint8 slot, bytes32 manifestHash,
        bytes32 recordHash, uint64 expectedRevision,
        IStreamPreservationRecords.CollectionRecord calldata original,
        StreamMediaMasterTypes.Waiver calldata witness)
        external override returns (StreamMediaMasterTypes.Selection memory s)
    {
        StreamConservationRecordContext.Dependencies memory d = _context();
        StreamMediaMasterReads.definitions(d, true);
        s = _selection(d, collectionId, witness.subjectId, manifestHash, slot);
        if (s.association.artistId == 0) revert StreamMediaMasterTypes.PlatformMasterUnavailable();
        s.original = StreamMediaMasterPublicationReads.recorded(d, collectionId, witness.subjectId,
            recordHash, original, true);
        StreamRecordJson.requirePayload(StreamMasterWaiverJson.waiver(witness),
            StreamMediaMasterPublicationReads.payload(d, recordHash, s.original.payloadHash));
        if (s.original.publication.artistId != s.association.artistId
            || s.original.publication.bindingHash != s.association.bindingHash
            || s.original.publication.bindingGeneration != s.association.generation
            || witness.artist.artistId != s.association.artistId
            || witness.artist.bindingHash != s.association.bindingHash
            || witness.artist.bindingGeneration != s.association.generation) {
            revert StreamMediaMasterTypes.MasterSelectionConflict();
        }
        bool matched;
        for (uint256 i; i < witness.mediaObjects.length; ++i) {
            if (witness.mediaObjects[i].objectId == s.objectId) {
                matched = true;
                s.masterRole = witness.mediaObjects[i].masterRoles[0];
            }
        }
        if (!matched) revert StreamMediaMasterTypes.InvalidMasterWitness();
        s.status = StreamMediaMasterTypes.Status.WAIVED;
        s.predecessor = witness.predecessor;
        return _adopt(collectionId, expectedRevision, s);
    }

    function _selection(StreamConservationRecordContext.Dependencies memory d,
        uint256 collectionId, bytes32 subjectId, bytes32 manifestHash, uint8 slot)
        private view returns (StreamMediaMasterTypes.Selection memory s)
    {
        _subject(collectionId, subjectId);
        if (slot == 0 || slot > 3) revert StreamMediaMasterTypes.InvalidMasterWitness();
        (bytes32 selected, bytes32[3] memory hashes,) = StreamMediaMasterReads.media(d, collectionId,
            _gasParameterValue(_MANIFEST_GAS));
        if (selected != manifestHash || hashes[slot - 1] == 0) {
            revert StreamMediaMasterTypes.MasterSelectionConflict();
        }
        s.subjectId = subjectId;
        s.manifestHash = manifestHash;
        s.mediaSlot = slot;
        s.displayHash = hashes[slot - 1];
        s.objectId = mediaObjectId(collectionId, subjectId, manifestHash, slot, s.displayHash);
        s.association = StreamConservationRecordContext.association(d, collectionId);
    }

    function _adopt(uint256 collectionId, uint64 expectedRevision, StreamMediaMasterTypes.Selection memory s)
        private returns (StreamMediaMasterTypes.Selection memory)
    {
        StreamMediaMasterTypes.Selection[] storage history = _history[_key(collectionId, s.subjectId, s.mediaSlot)];
        bytes32 previous;
        if (history.length != 0) {
            StreamMediaMasterTypes.Selection storage prior = history[history.length - 1];
            previous = prior.original.recordHash;
            if (s.original.recordedAt < prior.original.recordedAt
                || (s.status == prior.status && s.original.recordIndex <= prior.original.recordIndex)) {
                revert StreamMediaMasterTypes.MasterSelectionConflict();
            }
        }
        if (history.length != expectedRevision || expectedRevision == type(uint64).max
            || s.predecessor != previous || s.original.recordHash == previous) {
            revert StreamMediaMasterTypes.MasterSelectionConflict();
        }
        s.revision = expectedRevision + 1;
        s.selectionHash = keccak256(abi.encode(keccak256("6529STREAM_MEDIA_MASTER_SELECTION_V1"),
            deploymentChainId, address(this), core, metadata, schemaRegistry, externalCoverage,
            profileHash, collectionId, s));
        history.push(s);
        emit MediaMasterSelected(collectionId, s.subjectId, s.mediaSlot, s);
        return s;
    }

    function currentMaster(uint256 collectionId, bytes32 subjectId, uint8 slot)
        public view override returns (StreamMediaMasterTypes.Selection memory s)
    {
        StreamMediaMasterTypes.Selection[] storage history = _history[_key(collectionId, subjectId, slot)];
        if (history.length != 0) s = history[history.length - 1];
    }

    function masterSelectionAt(uint256 collectionId, bytes32 subjectId, uint8 slot, uint64 revision)
        external view override returns (StreamMediaMasterTypes.Selection memory)
    {
        StreamMediaMasterTypes.Selection[] storage history = _history[_key(collectionId, subjectId, slot)];
        if (revision == 0 || revision > history.length) revert StreamMediaMasterTypes.MasterSelectionConflict();
        return history[revision - 1];
    }

    function requireCollectionMasters(uint256 collectionId, bytes32 subjectId)
        external view override returns (bytes32 factsHash)
    {
        _subject(collectionId, subjectId);
        StreamConservationRecordContext.Dependencies memory d = _context();
        (bytes32 manifestHash, bytes32[3] memory hashes, bytes32 inventoryHash) = StreamMediaMasterReads.media(d, collectionId,
            _gasParameterValue(_MANIFEST_GAS));
        IStreamConservationRecordSelection.Association memory a =
            StreamConservationRecordContext.association(d, collectionId);
        factsHash = keccak256(abi.encode(profileHash, deploymentChainId, address(this), core,
            metadata, externalCoverage, collectionId, subjectId, manifestHash, inventoryHash, hashes, a));
        bool[2] memory validated;
        for (uint8 i; i < 3; ++i) {
            if (hashes[i] == 0) continue;
            StreamMediaMasterTypes.Selection memory s = currentMaster(collectionId, subjectId, i + 1);
            if (s.status == StreamMediaMasterTypes.Status.ABSENT || s.manifestHash != manifestHash
                || s.displayHash != hashes[i] || keccak256(abi.encode(s.association)) != keccak256(abi.encode(a))) {
                revert StreamMediaMasterTypes.MasterSelectionConflict();
            }
            bool waived = s.status == StreamMediaMasterTypes.Status.WAIVED;
            uint256 kind = waived ? 1 : 0;
            if (!validated[kind]) {
                StreamMediaMasterReads.definitions(d, waived);
                validated[kind] = true;
            }
            bytes32 archiveHash;
            if (waived) {
                if (a.artistId == 0) revert StreamMediaMasterTypes.PlatformMasterUnavailable();
            } else {
                archiveHash = StreamMediaMasterReads.coverage(externalCoverage, _coverageCodeHash, d,
                    s, _gasParameterValue(_COVERAGE_GAS));
            }
            factsHash = keccak256(abi.encode(factsHash, i + 1, s.selectionHash, archiveHash));
        }
    }

    function _context() private view returns (StreamConservationRecordContext.Dependencies memory d) {
        d.targets = [core, metadata, schemaRegistry, chunkStore];
        d.codeHashes = _codeHashes;
        d.artists = _artists;
        d.artistCodeHashes = _artistCodeHashes;
        d.chainId = deploymentChainId;
        return StreamConservationRecordContext.currentContext(d);
    }

    function _subject(uint256 collectionId, bytes32 subjectId) private view {
        if (collectionId == 0 || subjectId != StreamMetadataSubjects.scopeSubject(deploymentChainId,
            core, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0))) {
            revert StreamMediaMasterTypes.InvalidMasterWitness();
        }
    }

    function _key(uint256 collectionId, bytes32 subjectId, uint8 slot) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, subjectId, slot));
    }
}
