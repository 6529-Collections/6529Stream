// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamRightsRecordWitnessSelection.sol";
import "../../interfaces/stream/metadata/IStreamRightsRecordCurrentAuthority.sol";
import "../records/StreamRightsRecordReads.sol";
import "../records/StreamRecordArtistIdentityReads.sol";
import {
    IStreamRecordSelectionLock
} from "../../interfaces/stream/metadata/IStreamRecordSelectionLock.sol";
import { StreamRecordSelectionLocks as SelectionLocks } from "./StreamRecordSelectionLocks.sol";

/// @notice Current RIGHTS selection through Metadata's authenticated current Artist lineage.
/// @dev Deploy this explicit profile before its first selection or lock. Original RIGHTS grants,
/// records, selection domains and permanent seals are unchanged. This is not a storage importer
/// or replacement-address adapter for an already deployed legacy selector. No new Core role,
/// grant registry or mutable Artist binder is introduced.
contract StreamCurrentAuthorityRightsRecordSelection is
    IStreamRightsRecordCurrentAuthority,
    IStreamRightsRecordSelection,
    IStreamRightsRecordWitnessSelection,
    IStreamRecordSelectionLock
{
    address public immutable override core;
    address public immutable override metadata;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    uint256 public immutable override deploymentChainId;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable metadataCodeHash;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable chunkStoreCodeHash;
    StreamRecordArtistIdentityReads.Pins private _artistPins;
    mapping(bytes32 => Selection[]) private _history;
    mapping(bytes32 => SelectionLock) private _selectionLocks;

    struct SelectionRequest {
        uint256 collectionId;
        bytes32 subjectId;
        bytes32 recordHash;
        bytes32 expectedHead;
        uint64 expectedRevision;
    }

    constructor(address core_, address metadata_, address schemas_) {
        if (
            core_.code.length == 0 || metadata_.code.length == 0 || schemas_.code.length == 0
                || !IERC165(metadata_)
                    .supportsInterface(type(IStreamCollectionRecordReceipts).interfaceId)
                || !IERC165(schemas_)
                    .supportsInterface(type(IStreamSchemaDocumentFacts).interfaceId)
        ) {
            revert InvalidRightsConfiguration();
        }
        core = core_;
        metadata = metadata_;
        schemaRegistry = schemas_;
        chunkStore = IStreamSchemaRegistry(schemas_).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidRightsConfiguration();
        deploymentChainId = block.chainid;
        coreCodeHash = core_.codehash;
        metadataCodeHash = metadata_.codehash;
        schemaRegistryCodeHash = schemas_.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        // Complete definitions may be registered later by normal governance.
        // Retain the original deployment's three runtime pins. A successor may become the
        // authenticated current graph without replacing these original source identities.
        StreamRightsRecordReads.Dependencies memory d = _baseContext();
        _artistPins = StreamRecordArtistIdentityReads.resolveCurrent(
            metadata, core, deploymentChainId, d.readGas
        );
    }

    function currentAuthorityProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_CURRENT_AUTHORITY_RIGHTS_SELECTION_V1");
    }

    function currentArtistIdentityContext()
        external
        view
        override
        returns (address[3] memory targets, bytes32[3] memory codeHashes)
    {
        (, StreamRecordArtistIdentityReads.Pins memory current) = _context();
        return (current.targets, current.codeHashes);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamRightsRecordCurrentAuthority).interfaceId
            || id == type(IStreamRightsRecordSelection).interfaceId
            || id == type(IStreamRightsRecordWitnessSelection).interfaceId
            || id == type(IStreamRecordSelectionLock).interfaceId || id == 0x01ffc9a7;
    }

    function selectCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        StreamRightsRecordTypes.Statement calldata witness
    ) external override returns (Selection memory selected) {
        IStreamPreservationRecords.CollectionRecord memory unused;
        return _select(
            SelectionRequest(collectionId, subjectId, recordHash, expectedHead, expectedRevision),
            witness,
            unused,
            false
        );
    }

    function selectCurrentWithRecord(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 recordHash,
        bytes32 expectedHead,
        uint64 expectedRevision,
        Witness calldata witness
    ) external override returns (Selection memory) {
        return _select(
            SelectionRequest(collectionId, subjectId, recordHash, expectedHead, expectedRevision),
            witness.statement,
            witness.original,
            true
        );
    }

    function _select(
        SelectionRequest memory request,
        StreamRightsRecordTypes.Statement calldata witness,
        IStreamPreservationRecords.CollectionRecord memory original,
        bool supplied
    ) private returns (Selection memory selected) {
        if (_selectionLocks[_key(request.collectionId, request.subjectId)].locked) {
            revert RecordSelectionLocked(request.collectionId, request.subjectId);
        }
        Selection memory previous = currentRights(request.collectionId, request.subjectId);
        if (
            previous.recordHash != request.expectedHead
                || previous.revision != request.expectedRevision
                || witness.predecessor != request.expectedHead
                || request.expectedRevision == type(uint64).max
                || block.timestamp > type(uint64).max
        ) revert RightsSelectionConflict();
        (
            StreamRightsRecordReads.Dependencies memory d,
            StreamRecordArtistIdentityReads.Pins memory current
        ) = _context();
        (selected.authorizationClass, selected.grantScope, selected.grantRevision) =
            StreamRightsRecordReads.authority(d, request.collectionId, msg.sender);
        StreamRightsRecordReads.definitions(d);
        IStreamCollectionMetadataV1.RecordReceipt memory receipt;
        if (supplied) {
            (selected.payloadHash, receipt) = StreamRightsRecordReads.recordedWithWitness(
                d, request.collectionId, request.subjectId, request.recordHash, witness, original
            );
        } else {
            (selected.payloadHash, receipt) = StreamRightsRecordReads.recorded(
                d, request.collectionId, request.subjectId, request.recordHash, witness
            );
        }
        selected.recordIndex = receipt.recordIndex;
        selected.recorder = receipt.recorder;
        selected.recorderAuthorizationClass = receipt.authorizationClass;
        if (witness.licensor.kind == StreamRightsRecordTypes.LicensorKind.ARTIST) {
            selected.artistIdentityRecordHash = StreamRecordArtistIdentityReads.knownCurrentIdentity(
                metadata, core, deploymentChainId, current, witness.licensor.artistId, d.readGas
            );
        }
        if (request.expectedHead != 0 && selected.recordIndex <= previous.recordIndex) {
            revert RightsSelectionConflict();
        }
        selected.recordHash = request.recordHash;
        selected.predecessor = request.expectedHead;
        selected.selector = msg.sender;
        selected.revision = request.expectedRevision + 1;
        selected.selectedAt = uint64(block.timestamp);
        selected.selectionHash = _selectionHash(request.collectionId, request.subjectId, selected);
        _history[_key(request.collectionId, request.subjectId)].push(selected);
        emit RightsRecordSelected(
            request.collectionId, request.subjectId, request.recordHash, selected
        );
    }

    function _selectionHash(uint256 collectionId, bytes32 subjectId, Selection memory selected)
        private
        view
        returns (bytes32)
    {
        // The selectionHash field is zero while computing this explicit preimage.
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_RIGHTS_SELECTION_V1"),
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

    function currentRights(uint256 collectionId, bytes32 subjectId)
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

    function rightsSelectionAt(uint256 collectionId, bytes32 subjectId, uint64 revision)
        external
        view
        override
        returns (Selection memory)
    {
        if (revision == 0) revert RightsSelectionConflict();
        return _history[_key(collectionId, subjectId)][revision - 1];
    }

    function requireCurrent(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external view override returns (Selection memory selected) {
        selected = currentRights(collectionId, subjectId);
        if (
            selected.recordHash == 0 || selected.recordHash != expectedRecord
                || selected.revision != expectedRevision
        ) revert RightsSelectionConflict();
        (StreamRightsRecordReads.Dependencies memory d,) = _context();
        StreamRightsRecordReads.definitions(d);
    }

    function selectionLockTransition(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    )
        external
        view
        override
        returns (bytes32 scopeHash, bytes32 oldValueHash, bytes32 newValueHash)
    {
        (SelectionLocks.Environment memory e, SelectionLocks.Head memory h) =
            _lockData(collectionId, subjectId, expectedRecord, expectedRevision);
        SelectionLock memory item = SelectionLocks.context(e, h);
        return (item.scopeHash, item.oldValueHash, item.newValueHash);
    }

    function lockSelection(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) external override {
        (SelectionLocks.Environment memory e, SelectionLocks.Head memory h) =
            _lockData(collectionId, subjectId, expectedRecord, expectedRevision);
        SelectionLocks.lock(_selectionLocks, e, h);
    }

    function selectionLock(uint256 collectionId, bytes32 subjectId)
        external
        view
        override
        returns (SelectionLock memory)
    {
        return _selectionLocks[_key(collectionId, subjectId)];
    }

    function _lockData(
        uint256 collectionId,
        bytes32 subjectId,
        bytes32 expectedRecord,
        uint64 expectedRevision
    ) private view returns (SelectionLocks.Environment memory e, SelectionLocks.Head memory h) {
        if (_selectionLocks[_key(collectionId, subjectId)].locked) {
            revert RecordSelectionLocked(collectionId, subjectId);
        }
        Selection memory selected = currentRights(collectionId, subjectId);
        if (
            selected.recordHash == 0 || selected.recordHash != expectedRecord
                || selected.revision != expectedRevision
        ) {
            revert RecordSelectionLockConflict(collectionId, subjectId);
        }
        (StreamRightsRecordReads.Dependencies memory d,) = _context();
        StreamRightsRecordReads.definitions(d);
        e = SelectionLocks.Environment(
            core,
            metadata,
            coreCodeHash,
            metadataCodeHash,
            deploymentChainId,
            d.readGas,
            keccak256("RIGHTS_STATEMENT")
        );
        h = SelectionLocks.Head(
            collectionId, subjectId, selected.recordHash, selected.revision, selected.selectionHash
        );
    }

    function _context()
        private
        view
        returns (
            StreamRightsRecordReads.Dependencies memory d,
            StreamRecordArtistIdentityReads.Pins memory current
        )
    {
        d = _baseContext();
        // Preserve the original deployment's runtime guards even when the original facade
        // is still selected, where the common ancestry proof needs no import completion.
        for (uint256 i; i < 3; ++i) {
            if (
                _artistPins.targets[i].code.length == 0
                    || _artistPins.targets[i].codehash != _artistPins.codeHashes[i]
            ) {
                revert RightsDependencyChanged(_artistPins.targets[i]);
            }
        }
        // Includes ACCOUNT licensors, retained current selections and new seals: each use
        // proves the selected Artist from Metadata's original facade/runtime, including
        // complete imported authority and repeated ancestry where applicable. Nothing here
        // updates the immutable non-Artist graph or rewrites any retained selection.
        current = StreamRecordArtistIdentityReads.resolveCurrent(
            metadata, core, deploymentChainId, d.readGas
        );
    }

    function _baseContext() private view returns (StreamRightsRecordReads.Dependencies memory d) {
        d.targets = [core, metadata, schemaRegistry, chunkStore];
        d.codeHashes = [coreCodeHash, metadataCodeHash, schemaRegistryCodeHash, chunkStoreCodeHash];
        d.chainId = deploymentChainId;
        return StreamRightsRecordReads.currentContext(d);
    }

    function _key(uint256 collectionId, bytes32 subjectId) private pure returns (bytes32) {
        return keccak256(abi.encode(collectionId, subjectId));
    }
}
