// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import "../../interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import "../../interfaces/stream/core/IStreamCore.sol";
import "../../interfaces/stream/artist/IStreamArtistAttribution.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublication.sol";
import "../../interfaces/stream/artist/IStreamArtistRecordPublicationHost.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../records/StreamCollectionRecordHashes.sol";
import "../records/StreamRecordFamilies.sol";
import "../records/StreamRecordDocumentReads.sol";
import "./StreamSchemaDocumentStore.sol";
import "./StreamMetadataSubjects.sol";
import "./StreamMetadataRenderer.sol";
import "./StreamMetadataGovernance.sol";

/// @notice Full-byte collection records with direct or detached artist authorization.
/// @dev Catalog and operator grants use exact delayed Executor transitions. Generic records
///      do not claim typed finality readiness or authorize a renderer to consume their values.
contract StreamCollectionMetadataV1 is
    StreamModuleBase,
    StreamGasParameterHost,
    IStreamCollectionMetadataV1,
    IStreamArtistRecordPublicationHost
{
    using StreamRecordFamilies for bytes32;

    struct Configuration {
        address core;
        address executor;
        address schemas;
        address artistRegistry;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
        GasParameterConfig dependencyReadGas;
        GasParameterConfig artistReadGas;
    }

    struct StoredRecord {
        IStreamPreservationRecords.CollectionRecord record;
        RecordReceipt receipt;
    }

    struct Grant {
        bool enabled;
        uint64 revision;
    }

    struct Pointer {
        address pointer;
        bytes32 family;
        bytes32 contentHash;
    }

    struct Subject {
        uint256 collectionId;
        uint256 tokenId;
    }

    address public immutable override core;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    address public immutable artistRegistry;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable chunkStoreCodeHash;
    bytes32 public immutable artistRegistryCodeHash;
    bytes32 public immutable executorCodeHash;
    uint256 public constant MAX_RECORD_PAYLOAD_BYTES = 8192;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant ARTIST_READ_GAS = keccak256("6529STREAM_GGP_METADATA_ARTIST_READ_GAS");
    bytes32 private constant _TYPE = keccak256("COLLECTION_METADATA");

    mapping(bytes32 => RecordPolicy) private _policies;
    bytes32[] private _types;
    mapping(bytes32 => Grant) private _grants;
    mapping(bytes32 => Subject) private _subjects;
    mapping(bytes32 => StoredRecord) private _records;
    mapping(bytes32 => bytes32) private _latest;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(uint256 => Pointer[]) private _pointers;
    mapping(uint256 => mapping(bytes32 => bool)) private _pointerSeen;
    mapping(bytes32 => bool) public consumedArtistAuthorization;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529stream.collection-metadata.full-bytes.v1"),
            address(0),
            c.deploymentManifestHash,
            c.manifestURI,
            c.manifestHash
        )
        StreamGasParameterHost(c.executor)
    {
        if (
            c.executor == address(0) || c.core.code.length == 0 || c.schemas.code.length == 0
                || c.artistRegistry.code.length == 0 || c.deploymentManifestHash == 0
                || c.manifestHash == 0 || !IERC165(c.core).supportsInterface(0x80ac58cd)
                || !IERC165(c.schemas).supportsInterface(type(IStreamSchemaRegistry).interfaceId)
                || IStreamSchemaRegistry(c.schemas).governanceAuthority() != c.executor
                || IStreamArtistAttribution(c.artistRegistry).core() != c.core
        ) revert InvalidMetadataConfiguration();
        if (
            _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
                || _registerGasParameter(c.artistReadGas) != ARTIST_READ_GAS
        ) revert InvalidMetadataConfiguration();
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "moduleManifestURI", c.manifestURI, 2048, false
        );
        core = c.core;
        schemaRegistry = c.schemas;
        chunkStore = IStreamSchemaRegistry(c.schemas).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidMetadataConfiguration();
        artistRegistry = c.artistRegistry;
        coreCodeHash = c.core.codehash;
        schemaRegistryCodeHash = c.schemas.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        artistRegistryCodeHash = c.artistRegistry.codehash;
        executorCodeHash = c.executor.codehash;
    }

    function streamModuleType() public pure override returns (bytes32) {
        return _TYPE;
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.collection-metadata.full-bytes.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamCollectionMetadataV1).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamCollectionMetadataV1).interfaceId
            || id == type(IStreamArtistRecordPublicationHost).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function recordPolicy(bytes32 recordType) external view override returns (RecordPolicy memory) {
        return _policies[recordType];
    }

    function recordTypeCount() external view override returns (uint256) {
        return _types.length;
    }

    function recordTypeAt(uint256 index) external view override returns (bytes32) {
        return _types[index];
    }

    function recordTypeTransition(bytes32 recordType, bytes32 family, uint16 mask)
        public
        view
        override
        returns (bytes32 scope, bytes32 oldHash, bytes32 newHash)
    {
        if (
            recordType == 0 || _policies[recordType].admitted || mask == 0 || family.allowed() == 0
                || (mask & ~family.allowed()) != 0
        ) revert InvalidMetadataRecord();
        // These families have dedicated permanent hosts or typed intersection rules.
        if (
            family == StreamRecordFamilies.SNAPSHOT || family == StreamRecordFamilies.INDEPENDENT
                || family == StreamRecordFamilies.OWNER
        ) revert InvalidMetadataRecord();
        scope = _configurationScope(recordType);
        oldHash = keccak256(abi.encode(false));
        newHash = keccak256(abi.encode(RecordPolicy(family, mask, true)));
    }

    function admitRecordType(bytes32 recordType, bytes32 family, uint16 mask) external override {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            recordTypeTransition(recordType, family, mask);
        bytes32 actionId = _governed(scope, oldHash, newHash);
        _policies[recordType] = RecordPolicy(family, mask, true);
        _types.push(recordType);
        emit MetadataRecordTypeAdmitted(recordType, _policies[recordType], actionId);
    }

    function familyWriter(uint256 collectionId, bytes32 family, uint8 authClass, address account)
        public
        view
        override
        returns (bool, uint64)
    {
        Grant memory g = _grants[_grantKey(collectionId, family, authClass, account)];
        return (g.enabled, g.revision);
    }

    function familyWriterTransition(
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address account,
        bool enabled
    ) public view override returns (bytes32 scope, bytes32 oldHash, bytes32 newHash) {
        if (
            account == address(0) || authClass < 3 || authClass > 8 || authClass == 5
                || (family.allowed() & StreamRecordFamilies.bit(authClass)) == 0
        ) revert MetadataAuthorityRequired();
        if (collectionId != 0) _requireCollection(collectionId);
        bytes32 key = _grantKey(collectionId, family, authClass, account);
        Grant memory g = _grants[key];
        if (g.enabled == enabled || g.revision == type(uint64).max) revert InvalidMetadataRecord();
        scope = _configurationScope(key);
        oldHash = keccak256(abi.encode(g));
        newHash = keccak256(abi.encode(Grant(enabled, g.revision + 1)));
    }

    function setFamilyWriter(
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address account,
        bool enabled
    ) external override {
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = familyWriterTransition(
            collectionId, family, authClass, account, enabled
        );
        bytes32 actionId = _governed(scope, oldHash, newHash);
        Grant storage g = _grants[_grantKey(collectionId, family, authClass, account)];
        g.enabled = enabled;
        ++g.revision;
        emit MetadataFamilyWriterChanged(
            collectionId, family, account, authClass, enabled, g.revision, actionId
        );
    }

    /// @notice Registers a canonical minted/burned token subject without granting record authority.
    function registerTokenSubject(uint256 tokenId) external override returns (bytes32 subjectId) {
        _requireCode(core, coreCodeHash);
        (bool exists, uint256 collectionId,,) = abi.decode(
            _read(
                core,
                abi.encodeCall(IStreamCoreIdentity.tokenCollectionIdentity, (tokenId)),
                128,
                false
            ),
            (bool, uint256, uint256, bool)
        );
        uint8 lifecycle = abi.decode(
            _read(core, abi.encodeCall(IStreamCoreIdentity.tokenLifecycle, (tokenId)), 32, false),
            (uint8)
        );
        if (!exists || (lifecycle != 2 && lifecycle != 3)) revert InvalidMetadataRecord();
        _requireCollection(collectionId);
        subjectId = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            core,
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, collectionId, tokenId, 0)
        );
        _subjects[subjectId] = Subject(collectionId, tokenId);
    }

    function deriveCollectionRecordHashFor(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record
    ) external view override returns (bytes32) {
        if (recorder == address(0)) revert InvalidMetadataRecord();
        return StreamCollectionRecordHashes.recordHash(core, recorder, collectionId, record);
    }

    function recordCollectionRecordWithPayload(
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record,
        bytes calldata payload
    ) external override returns (bytes32) {
        uint8 authClass = _directWriter(collectionId, record);
        return _append(msg.sender, collectionId, record, payload, authClass, 0);
    }

    function recordArtistCollectionRecordWithPayload(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record,
        bytes calldata payload,
        bytes32 authorization
    ) external override returns (bytes32 hash) {
        if (consumedArtistAuthorization[authorization]) {
            revert MetadataAuthorizationConsumed(authorization);
        }
        _requireArtistSelected();
        _zeroSignature(record);
        if (
            record.contentHash.digest.length != 32
                || keccak256(payload) != bytes32(record.contentHash.digest)
        ) revert InvalidMetadataRecord();
        // Publication is permissionless; only _append accepts the pointer into the record index.
        StreamSchemaDocumentStore(chunkStore).publishChunk(payload);
        P.Publication memory p = _publication(recorder, collectionId, record);
        _candidate(p);
        P.Evidence memory evidence = abi.decode(
            _read(
                artistRegistry,
                abi.encodeCall(
                    IStreamArtistRecordPublication.requireRecordPublication, (authorization, p)
                ),
                288,
                true
            ),
            (P.Evidence)
        );
        if (
            authorization == 0 || evidence.attestationRecordHash != authorization
                || evidence.signer != recorder || evidence.artistId == 0
                || evidence.bindingHash == 0 || evidence.bindingGeneration == 0
                || evidence.publicationHash != keccak256(abi.encode(p))
        ) revert MetadataAuthorityRequired();
        consumedArtistAuthorization[authorization] = true;
        hash = _append(recorder, collectionId, record, payload, 1, authorization);
        emit ArtistRecordAuthorizationConsumed(authorization, hash, recorder, msg.sender);
    }

    function requireArtistRecordCandidate(P.Publication calldata publication)
        external
        view
        override
        returns (bytes32 hash, uint8 subjectKind)
    {
        return _candidate(publication);
    }

    function _candidate(P.Publication memory p) private view returns (bytes32 hash, uint8 kind) {
        _requireArtistSelected();
        _requireSubject(p.collectionId, p.subjectId);
        if (
            p.metadataHost != address(this) || p.recorder == address(0) || p.payloadAlgorithm != 1
                || p.effectiveAt == 0 || !_policies[p.recordType].admitted
                || _policies[p.recordType].family != StreamRecordFamilies.ARTIST
        ) revert InvalidMetadataRecord();
        _schema(p.schemaId, p.canonicalizationId);
        bytes memory payload = _chunk(p.payloadHash);
        if (
            payload.length == 0 || payload.length > MAX_RECORD_PAYLOAD_BYTES
                || keccak256(payload) != p.payloadHash
        ) revert InvalidMetadataRecord();
        kind = _artistSubjectKind(p.recordType, p.schemaId);
        hash = StreamCollectionRecordHashes.publicationHash(core, p);
        if (hash != p.candidateRecordHash) revert InvalidMetadataRecord();
    }

    function collectionRecord(bytes32 hash)
        external
        view
        override
        returns (
            IStreamPreservationRecords.CollectionRecord memory record,
            RecordReceipt memory receipt
        )
    {
        StoredRecord storage s = _knownRecord(hash);
        return (s.record, s.receipt);
    }

    function latestCollectionRecordHashFor(
        uint256 collectionId,
        bytes32 recordType,
        bytes32 subjectId,
        address recorder
    ) public view override returns (bytes32) {
        return _latest[keccak256(abi.encode(collectionId, recordType, subjectId, recorder))];
    }

    function collectionRecordPayload(uint256 collectionId, bytes32 recordType, bytes32 subjectId)
        external
        view
        override
        returns (address, bytes memory)
    {
        return recordPayload(
            latestCollectionRecordHashFor(collectionId, recordType, subjectId, msg.sender)
        );
    }

    function recordPayload(bytes32 hash)
        public
        view
        override
        returns (address pointer, bytes memory payload)
    {
        StoredRecord storage s = _knownRecord(hash);
        bytes32 contentHash = bytes32(s.record.contentHash.digest);
        (pointer,) = StreamSchemaDocumentStore(chunkStore).chunk(contentHash);
        payload = _chunk(contentHash);
    }

    function recordChainHash(uint256 collectionId, bytes32 recordType)
        external
        view
        override
        returns (bytes32, uint64)
    {
        return (
            _chains[collectionId][recordType], uint64(_history[collectionId][recordType].length)
        );
    }

    function recordHashAt(uint256 collectionId, bytes32 recordType, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[collectionId][recordType][index];
    }

    function payloadPointerCount(uint256 collectionId) external view override returns (uint256) {
        return _pointers[collectionId].length;
    }

    function payloadPointerAt(uint256 collectionId, uint256 index)
        external
        view
        override
        returns (address, bytes32, bytes32)
    {
        Pointer memory p = _pointers[collectionId][index];
        return (p.pointer, p.family, p.contentHash);
    }

    function _append(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record,
        bytes calldata payload,
        uint8 authClass,
        bytes32 authorization
    ) private returns (bytes32 hash) {
        _requireSubject(collectionId, record.subjectId);
        _zeroSignature(record);
        if (
            record.contentHash.algorithm != 1 || record.contentHash.digest.length != 32
                || payload.length == 0 || payload.length > MAX_RECORD_PAYLOAD_BYTES
                || bytes32(record.contentHash.digest) != keccak256(payload)
                || record.effectiveAt == 0 || block.timestamp > type(uint64).max
        ) revert InvalidMetadataRecord();
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", record.uri, 2048, true);
        RecordReceipt memory receipt;
        (receipt.schemaDefinitionHash, receipt.canonicalizationDefinitionHash) =
            _schema(record.schemaId, record.contentHash.canonicalizationId);
        RecordPolicy memory policy = _policies[record.recordType];
        if (
            !policy.admitted
                || (policy.authorizationMask & StreamRecordFamilies.bit(authClass)) == 0
        ) revert MetadataAuthorityRequired();
        hash = StreamCollectionRecordHashes.recordHash(core, recorder, collectionId, record);
        if (_records[hash].receipt.recorder != address(0)) revert DuplicateMetadataRecord(hash);
        _indexPayload(collectionId, policy.family, payload);
        receipt.collectionId = collectionId;
        receipt.recorder = recorder;
        receipt.authorizationClass = authClass;
        receipt.recordedAt = uint64(block.timestamp);
        receipt.artistAuthorization = authorization;
        _commitRecord(hash, record, receipt);
    }

    function _commitRecord(
        bytes32 hash,
        IStreamPreservationRecords.CollectionRecord calldata record,
        RecordReceipt memory receipt
    ) private {
        uint256 collectionId = receipt.collectionId;
        uint256 count = _history[collectionId][record.recordType].length;
        if (count == type(uint64).max) revert InvalidMetadataRecord();
        receipt.recordIndex = uint64(count);
        receipt.recordChainHash = StreamCollectionRecordHashes.nextChain(
            collectionId,
            record.recordType,
            _chains[collectionId][record.recordType],
            hash,
            uint64(count)
        );
        StoredRecord storage s = _records[hash];
        s.record = record;
        s.receipt = receipt;
        _history[collectionId][record.recordType].push(hash);
        _chains[collectionId][record.recordType] = receipt.recordChainHash;
        _latest[
            keccak256(
                abi.encode(collectionId, record.recordType, record.subjectId, receipt.recorder)
            )
        ] = hash;
        emit CollectionRecordRecorded(
            collectionId,
            record.recordType,
            record.subjectId,
            record,
            hash,
            receipt.recordChainHash,
            receipt.recorder,
            bytes32(uint256(receipt.authorizationClass)),
            1
        );
    }

    function _indexPayload(uint256 collectionId, bytes32 family, bytes calldata payload) private {
        (bytes32 contentHash, address pointer) =
            StreamSchemaDocumentStore(chunkStore).publishChunk(payload);
        bytes32 pointerKey = keccak256(abi.encode(family, contentHash));
        if (!_pointerSeen[collectionId][pointerKey]) {
            _pointerSeen[collectionId][pointerKey] = true;
            _pointers[collectionId].push(Pointer(pointer, family, contentHash));
        }
    }

    function _directWriter(
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record
    ) private view returns (uint8) {
        RecordPolicy memory policy = _policies[record.recordType];
        if (!policy.admitted) revert InvalidMetadataRecord();
        _requireSelected(_TYPE, address(this), address(this).codehash);
        if (policy.family == StreamRecordFamilies.ARTIST) revert MetadataAuthorityRequired();
        for (uint8 c = 3; c <= 8; ++c) {
            if (c == 5 || (policy.authorizationMask & StreamRecordFamilies.bit(c)) == 0) continue;
            if (
                _grants[_grantKey(collectionId, policy.family, c, msg.sender)].enabled
                    || _grants[_grantKey(0, policy.family, c, msg.sender)].enabled
            ) return c;
        }
        revert MetadataAuthorityRequired();
    }

    function _publication(
        address recorder,
        uint256 collectionId,
        IStreamPreservationRecords.CollectionRecord calldata record
    ) private view returns (P.Publication memory p) {
        p.metadataHost = address(this);
        p.recorder = recorder;
        p.collectionId = collectionId;
        p.subjectId = record.subjectId;
        p.recordType = record.recordType;
        p.schemaId = record.schemaId;
        p.canonicalizationId = record.contentHash.canonicalizationId;
        p.payloadAlgorithm = record.contentHash.algorithm;
        p.payloadHash = bytes32(record.contentHash.digest);
        p.uriHash = keccak256(bytes(record.uri));
        p.effectiveAt = record.effectiveAt;
        p.candidateRecordHash =
            StreamCollectionRecordHashes.recordHash(core, recorder, collectionId, record);
    }

    function _artistSubjectKind(bytes32 recordType, bytes32 schemaId) private pure returns (uint8) {
        if (
            (recordType == keccak256("ARTIST_INTENT")
                    && schemaId == keccak256("STREAM_ARTIST_INTENT_V1"))
                || (recordType == keccak256("ARTIST_INTENT_WAIVER")
                    && schemaId == keccak256("STREAM_ARTIST_INTENT_WAIVER_V1"))
        ) return 7;
        if (
            (recordType == keccak256("ARTIST_STATEMENT")
                    && (schemaId == keccak256("STREAM_ARTIST_INTERVIEW_V1")
                        || schemaId == keccak256("STREAM_ARTIST_STATEMENT_V1")))
                || (recordType == keccak256("ARTIST_SEMANTIC_ASSERTION")
                    && schemaId == keccak256("STREAM_SEMANTIC_ASSERTION_V1"))
        ) return 8;
        revert InvalidMetadataRecord();
    }

    function _schema(bytes32 schemaId, bytes32 canonId) private view returns (bytes32, bytes32) {
        _requireCode(schemaRegistry, schemaRegistryCodeHash);
        _requireCode(chunkStore, chunkStoreCodeHash);
        return StreamRecordDocumentReads.activeSchema(
            schemaRegistry, schemaId, canonId, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _chunk(bytes32 hash) private view returns (bytes memory) {
        _requireCode(chunkStore, chunkStoreCodeHash);
        return StreamRecordDocumentReads.chunk(
            chunkStore, hash, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function _requireSubject(uint256 collectionId, bytes32 subjectId) private view {
        _requireCollection(collectionId);
        bytes32 collectionSubject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            core,
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0)
        );
        if (subjectId != collectionSubject && _subjects[subjectId].collectionId != collectionId) {
            revert UnknownMetadataSubject(subjectId);
        }
    }

    function _requireCollection(uint256 collectionId) private view {
        _requireCode(core, coreCodeHash);
        if (
            collectionId == 0
                || !abi.decode(
                    _read(
                        core,
                        abi.encodeCall(IStreamCoreCollectionView.collectionExists, (collectionId)),
                        32,
                        false
                    ),
                    (bool)
                )
        ) revert InvalidMetadataRecord();
    }

    function _requireArtistSelected() private view {
        _requireSelected(_TYPE, address(this), address(this).codehash);
        _requireSelected(keccak256("ARTIST_REGISTRY"), artistRegistry, artistRegistryCodeHash);
    }

    function _requireSelected(bytes32 pointerType, address expected, bytes32 expectedCodeHash)
        private
        view
    {
        _requireCode(core, coreCodeHash);
        _requireCode(expected, expectedCodeHash);
        bytes memory data = _read(
            core, abi.encodeCall(IStreamCorePointers.getSatellitePointer, (pointerType)), 320, false
        );
        (address target, bytes32 hash,,,,,,,,) = abi.decode(
            data,
            (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
        );
        if (target != expected || hash != expectedCodeHash) revert MetadataHostNotSelected();
    }

    function _knownRecord(bytes32 hash) private view returns (StoredRecord storage s) {
        s = _records[hash];
        if (s.receipt.recorder == address(0)) revert UnknownMetadataRecord(hash);
    }

    function _zeroSignature(IStreamPreservationRecords.CollectionRecord calldata r) private pure {
        if (
            r.signatureScheme != 0 || r.signatureHash.algorithm != 0
                || r.signatureHash.digest.length != 0 || r.signatureHash.canonicalizationId != 0
        ) revert InvalidMetadataRecord();
    }

    function _grantKey(uint256 collectionId, bytes32 family, uint8 authClass, address account)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(collectionId, family, authClass, account));
    }

    function _requireCode(address target, bytes32 hash) private view {
        if (target.code.length == 0 || target.codehash != hash) {
            revert MetadataDependencyChanged(target);
        }
    }

    function _governed(bytes32 scope, bytes32 oldHash, bytes32 newHash)
        private
        view
        returns (bytes32)
    {
        return StreamMetadataGovernance.requireTransition(
            governanceAuthority,
            executorCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS),
            scope,
            oldHash,
            newHash
        );
    }

    function _configurationScope(bytes32 key) private view returns (bytes32) {
        return StreamMetadataGovernance.configurationScope(
            governanceAuthority, executorCodeHash, _gasParameterValue(DEPENDENCY_READ_GAS), key
        );
    }

    function _read(address target, bytes memory input, uint256 maximum, bool artist)
        private
        view
        returns (bytes memory data)
    {
        uint256 cap = _gasParameterValue(artist ? ARTIST_READ_GAS : DEPENDENCY_READ_GAS);
        if (gasleft() <= cap + cap / 63 + 10000) revert MetadataReadFailed(target);
        data = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(data, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum || (maximum <= 320 && size != maximum)) {
            revert MetadataReadFailed(target);
        }
        assembly ("memory-safe") { mstore(data, size) }
    }
}
