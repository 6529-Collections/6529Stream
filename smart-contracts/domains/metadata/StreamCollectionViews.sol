// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCollectionViews as V
} from "../../interfaces/stream/metadata/IStreamCollectionViews.sol";
import {
    IStreamCollectionMetadataV1 as M
} from "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    IStreamSchemaRegistry as S
} from "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamSchemaDocumentFacts
} from "../../interfaces/stream/metadata/IStreamSchemaDocumentFacts.sol";
import {
    IStreamPreservationRecords as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamModuleBase } from "../modules/StreamModuleBase.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    StreamCollectionRecordHashes as Hashes
} from "../records/StreamCollectionRecordHashes.sol";
import { StreamRecordDocumentReads } from "../records/StreamRecordDocumentReads.sol";
import { StreamSchemaDocumentStore } from "./StreamSchemaDocumentStore.sol";
import { StreamMetadataRenderer } from "./StreamMetadataRenderer.sol";
import { StreamCollectionViewFormat as Format } from "./StreamCollectionViewFormat.sol";
import { StreamCollectionViewReads as Reads } from "./StreamCollectionViewReads.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { ReentrancyGuard } from "../../vendor/openzeppelin/ReentrancyGuard.sol";

/// @notice Full-byte, revisioned alternate-view declarations under actual Metadata DISPLAY grants.
/// @dev This host does not adopt renderer inputs or confer Artist approval. A rendering consumer
///      must separately enforce the original content-consent, freeze and finality requirements.
contract StreamCollectionViews is StreamModuleBase, StreamGasParameterHost, ReentrancyGuard, V {
    struct Configuration {
        address core;
        address metadata;
        address executor;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
        GasParameterConfig dependencyReadGas;
    }

    struct Stored {
        CollectionViewManifest manifest;
        ViewReceipt receipt;
        P.CollectionRecord record;
        address manifestPointer;
        address viewPointer;
        bytes32[] viewChunks;
    }

    struct Pointer {
        address pointer;
        bytes32 family;
        bytes32 hash;
    }
    address public immutable override core;
    address public immutable override metadataHost;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    bytes32 private immutable _coreHash;
    bytes32 private immutable _metadataHash;
    bytes32 private immutable _schemasHash;
    bytes32 private immutable _storeHash;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    uint256 public constant MAX_VIEW_PAYLOAD_BYTES = 65536;
    uint256 private constant _CHUNK_BYTES = 8192;
    uint256 public constant MAX_VIEWS = 128;
    bytes32 private constant _RECORD_TYPE = keccak256("DISPLAY_VIEW_MANIFEST");
    bytes32 private constant _POINTER_MANIFEST = keccak256("6529STREAM_VIEW_MANIFEST_BYTES_V1");
    bytes32 private constant _POINTER_DOCUMENT = keccak256("6529STREAM_VIEW_DOCUMENT_BYTES_V1");
    mapping(bytes32 => Stored) private _records;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _selected;
    mapping(uint256 => mapping(bytes32 => bool)) private _locked;
    mapping(uint256 => bytes32[]) private _viewIds;
    mapping(uint256 => bytes32[]) private _history;
    mapping(uint256 => bytes32) private _chains;
    mapping(uint256 => Pointer[]) private _pointers;
    mapping(uint256 => mapping(bytes32 => bool)) private _pointerSeen;

    constructor(Configuration memory c)
        StreamModuleBase(
            Format.hash(), address(0), c.deploymentManifestHash, c.manifestURI, c.manifestHash
        )
        StreamGasParameterHost(c.executor)
    {
        if (
            c.core.code.length == 0 || c.metadata.code.length == 0 || c.executor == address(0)
                || c.deploymentManifestHash == 0 || c.manifestHash == 0
                || !M(c.metadata).supportsInterface(type(M).interfaceId)
                || M(c.metadata).core() != c.core
                || IStreamGasParameterHost(c.metadata).governanceAuthority() != c.executor
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
        ) revert InvalidViewConfiguration();
        address schemas = M(c.metadata).schemaRegistry();
        if (
            schemas.code.length == 0 || !S(schemas).supportsInterface(type(S).interfaceId)
                || !S(schemas).supportsInterface(type(IStreamSchemaDocumentFacts).interfaceId)
                || S(schemas).governanceAuthority() != c.executor
        ) revert InvalidViewConfiguration();
        address store = S(schemas).chunkStore();
        if (store.code.length == 0 || M(c.metadata).chunkStore() != store) {
            revert InvalidViewConfiguration();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "moduleManifestURI", c.manifestURI, 2048, false
        );
        core = c.core;
        metadataHost = c.metadata;
        schemaRegistry = schemas;
        chunkStore = store;
        _coreHash = c.core.codehash;
        _metadataHash = c.metadata.codehash;
        _schemasHash = schemas.codehash;
        _storeHash = store.codehash;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("COLLECTION_VIEWS");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.collection-views.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(V).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(V).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
    }

    function viewSchema() external pure override returns (bytes32, bytes32, bytes memory) {
        return (Format.SCHEMA_ID, Format.hash(), Format.definition());
    }

    function setCollectionViewManifest(
        uint256 id,
        bytes32 viewId,
        CollectionViewManifest calldata m
    ) external override nonReentrant returns (bytes32) {
        _validate(viewId, m);
        Reads.code(chunkStore, _storeHash);
        bytes memory payload = StreamRecordDocumentReads.chunk(
            chunkStore, m.contentHash, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
        return _set(id, viewId, m, payload, _selected[id][viewId]);
    }

    function setCollectionViewManifestWithPayload(
        uint256 id,
        bytes32 viewId,
        CollectionViewManifest calldata m,
        bytes calldata payload,
        bytes32 expectedPrevious
    ) external override nonReentrant returns (bytes32) {
        return _set(id, viewId, m, payload, expectedPrevious);
    }

    function _set(
        uint256 id,
        bytes32 viewId,
        CollectionViewManifest calldata m,
        bytes memory payload,
        bytes32 expected
    ) private returns (bytes32 hash) {
        _validate(viewId, m);
        if (
            payload.length == 0 || payload.length > MAX_VIEW_PAYLOAD_BYTES
                || keccak256(payload) != m.contentHash
        ) revert InvalidViewManifest();
        Reads.Context memory c = _context();
        Reads.live(c, id);
        Reads.code(chunkStore, _storeHash);
        if (_locked[id][viewId]) revert ViewLocked(id, viewId);
        bytes32 previous = _selected[id][viewId];
        if (expected != previous) revert ViewRevisionMismatch(expected, previous);
        if (
            previous != 0
                && keccak256(abi.encode(_records[previous].manifest)) == keccak256(abi.encode(m))
        ) revert InvalidViewManifest();
        uint64 revision = previous == 0 ? 1 : _records[previous].receipt.revision + 1;
        if (previous == 0 && _viewIds[id].length >= MAX_VIEWS) revert InvalidViewManifest();
        ViewReceipt memory receipt;
        receipt.collectionId = id;
        receipt.viewId = viewId;
        receipt.revision = revision;
        receipt.previousRecordHash = previous;
        receipt.recorder = msg.sender;
        (receipt.authorizationClass, receipt.grantCollectionId, receipt.grantRevision) =
            Reads.authority(c, id, msg.sender, false);
        (
            receipt.viewSchemaDefinitionHash,
            receipt.manifestSchemaDefinitionHash,
            receipt.canonicalizationDefinitionHash
        ) = Reads.schemas(c, m.schemaId);
        bytes memory carrier = abi.encode(id, revision, previous, m);
        if (
            carrier.length > _CHUNK_BYTES || _history[id].length >= type(uint64).max
                || block.timestamp > type(uint64).max
        ) revert InvalidViewManifest();
        P.CollectionRecord memory record;
        record.recordType = _RECORD_TYPE;
        // Original CMC VIEW subject preimage, distinct from collection or token subjects.
        record.subjectId = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"), block.chainid, core, id, uint8(4), viewId
            )
        );
        record.contentHash = P.HashRef(1, abi.encode(keccak256(carrier)), keccak256("RAW_BYTES"));
        record.uri = m.uri;
        record.schemaId = Format.SCHEMA_ID;
        record.signatureHash = P.HashRef(0, bytes(""), 0);
        hash = Hashes.recordHash(core, msg.sender, id, record);
        if (_records[hash].receipt.recorder != address(0)) revert InvalidViewManifest();
        receipt.recordedAt = uint64(block.timestamp);
        receipt.recordIndex = uint64(_history[id].length);
        receipt.recordChainHash =
            Hashes.nextChain(id, _RECORD_TYPE, _chains[id], hash, receipt.recordIndex);
        (address viewPointer, bytes32[] memory viewChunks) = _storeDocument(id, payload);
        (, address manifestPointer) = StreamSchemaDocumentStore(chunkStore).publishChunk(carrier);
        _records[hash] = Stored(m, receipt, record, manifestPointer, viewPointer, viewChunks);
        if (previous == 0) _viewIds[id].push(viewId);
        _selected[id][viewId] = hash;
        _history[id].push(hash);
        _chains[id] = receipt.recordChainHash;
        _index(id, manifestPointer, _POINTER_MANIFEST, keccak256(carrier));
        emit CollectionRecordRecorded(
            id,
            _RECORD_TYPE,
            record.subjectId,
            record,
            hash,
            receipt.recordChainHash,
            msg.sender,
            bytes32(uint256(receipt.authorizationClass)),
            1
        );
        emit CollectionViewManifestSet(1, id, viewId, m.schemaId, m.contentHash, hash, m, receipt);
    }

    function lockCollectionView(uint256 id, bytes32 viewId) external override nonReentrant {
        Reads.Context memory c = _context();
        Reads.live(c, id);
        bytes32 hash = _selected[id][viewId];
        if (hash == 0 || _locked[id][viewId]) revert ViewLocked(id, viewId);
        (uint8 kind, uint256 scope, uint64 revision) = Reads.authority(c, id, msg.sender, true);
        _locked[id][viewId] = true;
        emit CollectionViewLocked(1, id, viewId, hash, msg.sender, kind, scope, revision);
    }

    function collectionViewManifest(uint256 id, bytes32 viewId)
        external
        view
        override
        returns (CollectionViewManifest memory)
    {
        return _records[_selected[id][viewId]].manifest;
    }

    function selectedViewRecord(uint256 id, bytes32 viewId)
        external
        view
        override
        returns (bytes32, bool)
    {
        return (_selected[id][viewId], _locked[id][viewId]);
    }

    function viewIdCount(uint256 id) external view override returns (uint256) {
        return _viewIds[id].length;
    }

    function viewIdAt(uint256 id, uint256 index) external view override returns (bytes32) {
        if (index >= _viewIds[id].length) revert ViewIndexOutOfBounds();
        return _viewIds[id][index];
    }

    function viewRecord(bytes32 hash)
        external
        view
        override
        returns (CollectionViewManifest memory, ViewReceipt memory, P.CollectionRecord memory)
    {
        Stored storage s = _known(hash);
        return (s.manifest, s.receipt, s.record);
    }

    function viewPayload(bytes32 hash) external view override returns (address, bytes memory) {
        Stored storage s = _known(hash);
        bytes memory result = new bytes(MAX_VIEW_PAYLOAD_BYTES);
        uint256 length;
        for (uint256 i; i < s.viewChunks.length; ++i) {
            bytes memory part = _payload(s.viewChunks[i]);
            if (
                part.length == 0 || part.length > _CHUNK_BYTES
                    || (i + 1 < s.viewChunks.length && part.length != _CHUNK_BYTES)
                    || length + part.length > MAX_VIEW_PAYLOAD_BYTES
            ) revert InvalidViewManifest();
            _copy(part, 0, result, length, part.length);
            length += part.length;
        }
        assembly ("memory-safe") { mstore(result, length) }
        if (keccak256(result) != s.manifest.contentHash) revert InvalidViewManifest();
        return (s.viewPointer, result);
    }

    function viewChunkCount(bytes32 hash) external view override returns (uint256) {
        return _known(hash).viewChunks.length;
    }

    function viewChunk(bytes32 hash, uint256 index)
        external
        view
        override
        returns (bytes32, bytes memory)
    {
        Stored storage s = _known(hash);
        if (index >= s.viewChunks.length) revert ViewIndexOutOfBounds();
        bytes32 chunk = s.viewChunks[index];
        return (chunk, _payload(chunk));
    }

    function manifestPayload(bytes32 hash) external view override returns (address, bytes memory) {
        Stored storage s = _known(hash);
        return (s.manifestPointer, _payload(bytes32(s.record.contentHash.digest)));
    }

    function recordChainHash(uint256 id) external view override returns (bytes32, uint64) {
        return (_chains[id], uint64(_history[id].length));
    }

    function recordHashAt(uint256 id, uint256 index) external view override returns (bytes32) {
        if (index >= _history[id].length) revert ViewIndexOutOfBounds();
        return _history[id][index];
    }

    function payloadPointerCount(uint256 id) external view override returns (uint256) {
        return _pointers[id].length;
    }

    function payloadPointerAt(uint256 id, uint256 index)
        external
        view
        override
        returns (address, bytes32, bytes32)
    {
        if (index >= _pointers[id].length) revert ViewIndexOutOfBounds();
        Pointer storage p = _pointers[id][index];
        return (p.pointer, p.family, p.hash);
    }

    function _storeDocument(uint256 id, bytes memory payload)
        private
        returns (address first, bytes32[] memory hashes)
    {
        uint256 count = (payload.length + _CHUNK_BYTES - 1) / _CHUNK_BYTES;
        hashes = new bytes32[](count);
        for (uint256 i; i < count; ++i) {
            uint256 offset = i * _CHUNK_BYTES;
            uint256 length = payload.length - offset;
            if (length > _CHUNK_BYTES) length = _CHUNK_BYTES;
            bytes memory part = new bytes(length);
            _copy(payload, offset, part, 0, length);
            (bytes32 hash, address pointer) =
                StreamSchemaDocumentStore(chunkStore).publishChunk(part);
            hashes[i] = hash;
            if (i == 0) first = pointer;
            _index(id, pointer, _POINTER_DOCUMENT, hash);
        }
    }

    function _copy(
        bytes memory source,
        uint256 from,
        bytes memory target,
        uint256 to,
        uint256 length
    ) private pure {
        // Both offsets are chunk-aligned; the final allocation includes its complete padded word.
        for (uint256 i; i < length; i += 32) {
            assembly ("memory-safe") {
                mstore(add(add(target, 32), add(to, i)), mload(add(add(source, 32), add(from, i))))
            }
        }
    }

    function _context() private view returns (Reads.Context memory) {
        return Reads.Context(
            core,
            _coreHash,
            metadataHost,
            _metadataHash,
            schemaRegistry,
            _schemasHash,
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _known(bytes32 hash) private view returns (Stored storage s) {
        s = _records[hash];
        if (s.receipt.recorder == address(0)) revert UnknownViewRecord(hash);
    }

    function _payload(bytes32 hash) private view returns (bytes memory) {
        Reads.code(chunkStore, _storeHash);
        return StreamRecordDocumentReads.chunk(
            chunkStore, hash, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _index(uint256 id, address pointer, bytes32 family, bytes32 hash) private {
        bytes32 key = keccak256(abi.encode(family, hash));
        if (_pointerSeen[id][key]) return;
        _pointerSeen[id][key] = true;
        _pointers[id].push(Pointer(pointer, family, hash));
    }

    function _validate(bytes32 viewId, CollectionViewManifest calldata m) private pure {
        if (viewId == 0 || m.viewId != viewId || m.schemaId == 0 || m.contentHash == 0) {
            revert InvalidViewManifest();
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri("viewURI", m.uri, 2048, true);
        bytes memory mime = bytes(m.mimeType);
        if (mime.length == 0 || mime.length > 96) revert InvalidViewManifest();
        uint256 slash;
        for (uint256 i; i < mime.length; ++i) {
            uint8 b = uint8(mime[i]);
            if (b == 47) {
                if (i == 0 || i + 1 == mime.length || slash != 0) revert InvalidViewManifest();
                slash = i;
            } else if (!((b >= 48 && b <= 57) || (b >= 65 && b <= 90) || (b >= 97 && b <= 122)
                        || b == 33 || b == 35 || b == 36 || b == 38 || b == 94 || b == 95 || b == 46
                        || b == 43 || b == 45)) {
                revert InvalidViewManifest();
            }
        }
        if (slash == 0) revert InvalidViewManifest();
    }
}
