// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamRightsRecordSelection.sol";
import "../../interfaces/stream/metadata/IStreamRightsRecordWitnessSelection.sol";
import "../records/StreamRightsRecordReads.sol";
import "../records/StreamRecordArtistIdentityReads.sol";

/// @notice Explicit current rights statements selected by the existing RIGHTS authority.
/// @dev Fixed auxiliary for the typed provider; no new Core role, grant store or mutable binder.
contract StreamRightsRecordSelection is
    IStreamRightsRecordSelection,
    IStreamRightsRecordWitnessSelection
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
        StreamRightsRecordReads.Dependencies memory d = _baseContext();
        _artistPins =
            StreamRecordArtistIdentityReads.resolve(metadata, core, deploymentChainId, d.readGas);
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IStreamRightsRecordSelection).interfaceId
            || id == type(IStreamRightsRecordWitnessSelection).interfaceId || id == 0x01ffc9a7;
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
        Selection memory previous = currentRights(request.collectionId, request.subjectId);
        if (
            previous.recordHash != request.expectedHead
                || previous.revision != request.expectedRevision
                || witness.predecessor != request.expectedHead
                || request.expectedRevision == type(uint64).max
                || block.timestamp > type(uint64).max
        ) revert RightsSelectionConflict();
        StreamRightsRecordReads.Dependencies memory d = _context();
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
            selected.artistIdentityRecordHash = StreamRecordArtistIdentityReads.knownIdentity(
                metadata, core, deploymentChainId, _artistPins, witness.licensor.artistId, d.readGas
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
        StreamRightsRecordReads.definitions(_context());
    }

    function _context() private view returns (StreamRightsRecordReads.Dependencies memory d) {
        d = _baseContext();
        for (uint256 i; i < 3; ++i) {
            if (
                _artistPins.targets[i].code.length == 0
                    || _artistPins.targets[i].codehash != _artistPins.codeHashes[i]
            ) {
                revert RightsDependencyChanged(_artistPins.targets[i]);
            }
        }
        StreamRecordArtistIdentityReads.Pins memory current =
            StreamRecordArtistIdentityReads.resolve(metadata, core, deploymentChainId, d.readGas);
        for (uint256 i; i < 3; ++i) {
            if (
                current.targets[i] != _artistPins.targets[i]
                    || current.codeHashes[i] != _artistPins.codeHashes[i]
            ) {
                revert RightsDependencyChanged(current.targets[i]);
            }
        }
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
