// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamPreservationRecordsV1 as P
} from "../../interfaces/stream/preservation/IStreamPreservationRecordsV1.sol";
import {
    IStreamPreservationRecords as Original
} from "../../interfaces/stream/preservation/IStreamPreservationRecords.sol";
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
    IStreamGasParameterHost
} from "../../interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { IERC165 } from "../../vendor/openzeppelin/IERC165.sol";
import { ReentrancyGuard } from "../../vendor/openzeppelin/ReentrancyGuard.sol";
import { StreamModuleBase } from "../modules/StreamModuleBase.sol";
import { StreamGasParameterHost } from "../parameters/StreamGasParameterHost.sol";
import {
    StreamCollectionRecordHashes as Hashes
} from "../records/StreamCollectionRecordHashes.sol";
import { StreamSnapshotManifestBytes as Bytes } from "../records/StreamSnapshotManifestBytes.sol";
import { StreamSchemaDocumentStore as Store } from "../metadata/StreamSchemaDocumentStore.sol";
import { StreamMetadataRenderer } from "../metadata/StreamMetadataRenderer.sol";
import { StreamMetadataSubjects } from "../metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamPreservationRecordReads as Reads } from "./StreamPreservationRecordReads.sol";

/// @notice Role27 full-byte operator-asserted preservation records under selected Metadata family grants.
/// @dev Immutable historical bytes are independent of live selection. Publication is not archival coverage,
///      proof of performed fixity, ownership, Artist consent, renderer adoption or artwork finality.
contract StreamPreservationRecordsV1 is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    P
{
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
        Original.CollectionRecord record;
        Receipt receipt;
    }

    struct Subject {
        uint256 collectionId;
        uint8 kind;
        uint256 tokenId;
        bytes32 objectId;
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
    uint256 public constant MAX_RECORD_PAYLOAD_BYTES = 24576;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    mapping(bytes32 => Stored) private _records;
    mapping(bytes32 => Bytes.Manifest) private _payloads;
    mapping(bytes32 => Subject) private _subjects;
    mapping(bytes32 => bytes32) private _latest;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(uint256 => Pointer[]) private _pointers;
    mapping(uint256 => mapping(bytes32 => bool)) private _pointerSeen;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529stream.preservation-records.full-bytes.v1"),
            address(0),
            c.deploymentManifestHash,
            c.manifestURI,
            c.manifestHash
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
        ) revert InvalidPreservationConfiguration();
        address schemas = M(c.metadata).schemaRegistry();
        if (
            schemas.code.length == 0 || !S(schemas).supportsInterface(type(S).interfaceId)
                || !S(schemas).supportsInterface(type(IStreamSchemaDocumentFacts).interfaceId)
                || S(schemas).governanceAuthority() != c.executor
        ) revert InvalidPreservationConfiguration();
        address store = S(schemas).chunkStore();
        if (store.code.length == 0 || M(c.metadata).chunkStore() != store) {
            revert InvalidPreservationConfiguration();
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
        return keccak256("PRESERVATION_RECORDS");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.preservation-records.full-bytes.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(P).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(P).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
    }

    function registerTokenSubject(uint256 id) external override returns (bytes32 subject) {
        uint256 cid = Reads.token(_context(), id);
        subject = StreamMetadataSubjects.scopeSubject(
            block.chainid, core, StreamFinalityScope(StreamFinalityScopeType.TOKEN, cid, id, 0)
        );
        _register(subject, Subject(cid, 1, id, 0));
    }

    function registerMediaSubject(uint256 cid, bytes32 objectId)
        external
        override
        returns (bytes32 subject)
    {
        Reads.collection(_context(), cid);
        subject = StreamMetadataSubjects.mediaSubject(block.chainid, core, cid, objectId);
        _register(subject, Subject(cid, 2, 0, objectId));
    }

    function _register(bytes32 key, Subject memory s) private {
        if (_subjects[key].collectionId != 0) return;
        _subjects[key] = s;
        emit PreservationSubjectRegistered(1, key, s.collectionId, s.kind, s.tokenId, s.objectId);
    }

    function subjectIdentity(bytes32 subject)
        external
        view
        override
        returns (uint256, uint8, uint256, bytes32)
    {
        Subject memory s = _subjects[subject];
        return (s.collectionId, s.kind, s.tokenId, s.objectId);
    }

    function recordCollectionRecordWithPayload(
        uint256 cid,
        Original.CollectionRecord calldata record,
        bytes calldata payload
    ) external override nonReentrant returns (bytes32 hash) {
        if (
            record.recordType == 0 || record.schemaId == 0
                || record.contentHash.canonicalizationId == 0 || record.contentHash.algorithm != 1
                || record.contentHash.digest.length != 32 || payload.length == 0
                || payload.length > MAX_RECORD_PAYLOAD_BYTES
                || bytes32(record.contentHash.digest) != keccak256(payload)
                || record.effectiveAt == 0 || block.timestamp > type(uint64).max
                || record.signatureScheme != 0 || record.signatureHash.algorithm != 0
                || record.signatureHash.digest.length != 0
                || record.signatureHash.canonicalizationId != 0
        ) revert InvalidPreservationRecord();
        _subject(cid, record.subjectId);
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", record.uri, 2048, true);
        Reads.Context memory c = _context();
        Receipt memory receipt = Reads.admit(
            c,
            cid,
            record.recordType,
            msg.sender,
            record.schemaId,
            record.contentHash.canonicalizationId
        );
        bytes32 authority = keccak256(abi.encode(receipt));
        hash = Hashes.recordHash(core, msg.sender, cid, record);
        if (_records[hash].receipt.recorder != address(0)) {
            revert DuplicatePreservationRecord(hash);
        }
        uint256 index = _history[cid][record.recordType].length;
        if (index >= type(uint64).max) revert InvalidPreservationRecord();
        Reads.code(chunkStore, _storeHash);
        for (uint256 offset; offset < payload.length; offset += 8192) {
            uint256 end = offset + 8192;
            if (end > payload.length) end = payload.length;
            (bytes32 chunkHash, address pointer) =
                Store(chunkStore).publishChunk(payload[offset:end]);
            bytes32 key = keccak256(abi.encode(receipt.family, chunkHash));
            if (!_pointerSeen[cid][key]) {
                _pointerSeen[cid][key] = true;
                _pointers[cid].push(Pointer(pointer, receipt.family, chunkHash));
            }
        }
        Bytes.retainBounded(_payloads[hash], chunkStore, payload, MAX_RECORD_PAYLOAD_BYTES);
        // Late dependency/authority failure rolls back chunk creation, pointer rows and the record.
        Reads.code(chunkStore, _storeHash);
        if (
            authority
                != keccak256(
                    abi.encode(
                        Reads.admit(
                            c,
                            cid,
                            record.recordType,
                            msg.sender,
                            record.schemaId,
                            record.contentHash.canonicalizationId
                        )
                    )
                )
        ) revert PreservationAuthorityRequired();
        receipt.recordedAt = uint64(block.timestamp);
        receipt.recordIndex = uint64(index);
        receipt.recordChainHash = Hashes.nextChain(
            cid, record.recordType, _chains[cid][record.recordType], hash, uint64(index)
        );
        _records[hash] = Stored(record, receipt);
        _history[cid][record.recordType].push(hash);
        _chains[cid][record.recordType] = receipt.recordChainHash;
        _latest[keccak256(abi.encode(cid, record.recordType, record.subjectId, msg.sender))] = hash;
        emit CollectionRecordRecorded(
            cid,
            record.recordType,
            record.subjectId,
            record,
            hash,
            receipt.recordChainHash,
            msg.sender,
            bytes32(uint256(receipt.authorizationClass)),
            1
        );
    }

    function deriveCollectionRecordHashFor(
        address recorder,
        uint256 cid,
        Original.CollectionRecord calldata record
    ) external view override returns (bytes32) {
        if (recorder == address(0)) {
            revert InvalidPreservationRecord();
        }
        return Hashes.recordHash(core, recorder, cid, record);
    }

    function collectionRecord(bytes32 hash)
        external
        view
        override
        returns (Original.CollectionRecord memory, Receipt memory)
    {
        Stored storage s = _known(hash);
        return (s.record, s.receipt);
    }

    function latestCollectionRecordHashFor(
        uint256 cid,
        bytes32 kind,
        bytes32 subject,
        address recorder
    ) public view override returns (bytes32) {
        return _latest[keccak256(abi.encode(cid, kind, subject, recorder))];
    }

    function collectionRecordPayload(uint256 cid, bytes32 kind, bytes32 subject)
        external
        view
        override
        returns (address, bytes memory)
    {
        return recordPayload(latestCollectionRecordHashFor(cid, kind, subject, msg.sender));
    }

    function recordPayload(bytes32 hash) public view override returns (address, bytes memory) {
        _known(hash);
        return
            (
                _payloads[hash].pointers[0],
                Bytes.readBounded(_payloads[hash], MAX_RECORD_PAYLOAD_BYTES)
            );
    }

    function recordPayloadChunkCount(bytes32 hash) external view override returns (uint256) {
        _known(hash);
        return _payloads[hash].pointers.length;
    }

    function recordPayloadChunkAt(bytes32 hash, uint256 index)
        external
        view
        override
        returns (address, bytes32)
    {
        _known(hash);
        if (index >= _payloads[hash].pointers.length) revert PreservationIndexOutOfBounds();
        return (_payloads[hash].pointers[index], _payloads[hash].chunkHashes[index]);
    }

    function recordChainHash(uint256 cid, bytes32 kind)
        external
        view
        override
        returns (bytes32, uint64)
    {
        return (_chains[cid][kind], uint64(_history[cid][kind].length));
    }

    function recordHashAt(uint256 cid, bytes32 kind, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[cid][kind][index];
    }

    function payloadPointerCount(uint256 cid) external view override returns (uint256) {
        return _pointers[cid].length;
    }

    function payloadPointerAt(uint256 cid, uint256 index)
        external
        view
        override
        returns (address, bytes32, bytes32)
    {
        Pointer memory p = _pointers[cid][index];
        return (p.pointer, p.family, p.hash);
    }

    function _subject(uint256 cid, bytes32 subject) private view {
        bytes32 collection = StreamMetadataSubjects.scopeSubject(
            block.chainid, core, StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0)
        );
        if (subject != collection && _subjects[subject].collectionId != cid) {
            revert UnknownPreservationSubject(subject);
        }
    }

    function _known(bytes32 hash) private view returns (Stored storage s) {
        s = _records[hash];
        if (s.receipt.recorder == address(0)) revert UnknownPreservationRecord(hash);
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
}
