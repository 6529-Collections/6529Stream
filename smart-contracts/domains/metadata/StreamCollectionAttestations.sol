// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamCollectionAttestations.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../records/StreamCollectionRecordHashes.sol";
import "./StreamSchemaDocumentStore.sol";
import "./StreamMetadataRenderer.sol";
import "./StreamIndependentReads.sol";
import "./StreamIndependentRecordHash.sol";
import "./StreamIndependentSignatures.sol";

/// @notice Permanent independent preservation evidence, without operator or renderer authority.
/// @dev Schema retirement, Core locks, current pointers and governance liveness are not admission
///      predicates. Media object IDs are attributed references, not registry membership proofs.
contract StreamCollectionAttestations is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamCollectionAttestations,
    IERC5267
{
    struct Configuration {
        address core;
        address schemas;
        address executor;
        bytes32 deploymentManifestHash;
        string manifestURI;
        bytes32 manifestHash;
        GasParameterConfig signatureGas;
        GasParameterConfig dependencyReadGas;
    }

    struct Stored {
        IStreamPreservationRecords.CollectionRecord record;
        Receipt receipt;
        Subject subject;
        address payloadPointer;
        address signaturePointer;
    }

    struct Pointer {
        address pointer;
        bytes32 family;
        bytes32 hash;
    }

    address public immutable override core;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable chunkStoreCodeHash;
    uint256 public constant MAX_RECORD_PAYLOAD_BYTES = 8192;
    uint256 public constant MAX_SIGNATURE_BYTES = 4096;
    uint256 public constant MAX_SIGNATURE_BUNDLE_BYTES = 8192;
    uint256 public constant METADATA_ERC1271_VERIFY_GAS_FLOOR = 90000;
    bytes32 public constant GGP_METADATA_ERC1271_VERIFY_GAS =
        0x3ca324ef8262b1ff4cb8753a082cd8780e50f754c1a323a433e0e7665a5ec9f9;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant STREAM_INDEPENDENT_PRESERVATION_TYPEHASH =
        StreamIndependentRecordHash.RECORD_TYPEHASH;
    bytes32 public constant STREAM_INDEPENDENT_PRESERVATION_REVOCATION_TYPEHASH =
        StreamIndependentRecordHash.REVOCATION_TYPEHASH;
    bytes32 private constant _FAMILY = keccak256("6529STREAM_RECORD_FAMILY_INDEPENDENT_V1");
    bytes32 private constant _BUNDLE_FAMILY = keccak256("STREAM_INDEPENDENT_SIGNATURE_BUNDLE_V1");
    bytes32 private constant _RAW_BYTES = keccak256("RAW_BYTES");

    mapping(address => mapping(uint256 => bool)) private _used;
    mapping(bytes32 => Stored) private _records;
    mapping(bytes32 => bytes32) private _latest;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(uint256 => Pointer[]) private _pointers;
    mapping(uint256 => mapping(bytes32 => bool)) private _pointerSeen;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529stream.collection-attestations.independent.v1"),
            address(0),
            c.deploymentManifestHash,
            c.manifestURI,
            c.manifestHash
        )
        StreamGasParameterHost(c.executor)
    {
        if (
            c.core.code.length == 0 || c.schemas.code.length == 0 || c.deploymentManifestHash == 0
                || c.manifestHash == 0 || !IERC165(c.core).supportsInterface(0x80ac58cd)
                || !IERC165(c.schemas).supportsInterface(type(IStreamSchemaRegistry).interfaceId)
                || (c.executor != address(0)
                    && IStreamSchemaRegistry(c.schemas).governanceAuthority() != c.executor)
                || c.signatureGas.floor != METADATA_ERC1271_VERIFY_GAS_FLOOR
                || c.signatureGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.signatureGas) != GGP_METADATA_ERC1271_VERIFY_GAS
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
        ) revert InvalidAttestationConfiguration();
        core = c.core;
        schemaRegistry = c.schemas;
        chunkStore = IStreamSchemaRegistry(c.schemas).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidAttestationConfiguration();
        coreCodeHash = c.core.codehash;
        schemaRegistryCodeHash = c.schemas.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "moduleManifestURI", c.manifestURI, 2048, false
        );
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("COLLECTION_ATTESTATIONS");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.collection-attestations.independent.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamCollectionAttestations).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamCollectionAttestations).interfaceId
            || id == type(IERC5267).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
    }

    function eip712Domain()
        external
        view
        override
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (
            0x0f,
            "6529StreamCollectionAttestations",
            "1",
            block.chainid,
            address(this),
            0,
            new uint256[](0)
        );
    }

    function isIndependentRecordType(bytes32 t) public pure override returns (bool) {
        return t == keccak256("INDEPENDENT_FIXITY")
            || t == keccak256("INDEPENDENT_PRESERVATION_EVENT")
            || t == keccak256("INDEPENDENT_EXHIBITION") || t == keccak256("INDEPENDENT_CONDITION")
            || t == keccak256("INDEPENDENT_CONSERVATION_TREATMENT")
            || t == keccak256("INDEPENDENT_ENVIRONMENT_MIGRATION")
            || t == keccak256("INDEPENDENT_EXPORT_MIRROR")
            || t == keccak256("INDEPENDENT_SEMANTIC_ASSERTION");
    }

    function deriveSubject(Subject calldata s) external view override returns (bytes32) {
        return StreamIndependentReads.subject(core, s);
    }

    function independentRecordDigest(IndependentRecord calldata r)
        public
        view
        override
        returns (bytes32)
    {
        return StreamIndependentRecordHash.record(r);
    }

    function independentRevocationDigest(address attestor, uint256 nonce, uint64 deadline)
        public
        view
        override
        returns (bytes32)
    {
        return StreamIndependentRecordHash.revocation(attestor, nonce, deadline);
    }

    function recordIndependentPreservation(
        Subject calldata subject,
        IndependentRecord calldata r,
        bytes calldata signature
    ) external override nonReentrant returns (bytes32 hash) {
        _fresh(r.attestor, r.nonce);
        _deadline(r.deadline);
        if (
            !isIndependentRecordType(r.recordType) || r.scopeKey != subject.collectionId
                || r.subjectId != StreamIndependentReads.subject(core, subject) || r.schemaId == 0
                || r.canonicalizationId == 0 || r.algorithmId != 1 || r.digest.length != 32
                || r.payload.length == 0 || r.payload.length > MAX_RECORD_PAYLOAD_BYTES
                || bytes32(r.digest) != keccak256(r.payload) || r.effectiveAt == 0
                || block.timestamp > type(uint64).max
        ) revert InvalidIndependentRecord();
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", r.uri, 2048, true);
        bytes32 digest = independentRecordDigest(r);
        bytes32 scheme = StreamIndependentSignatures.verify(
            r.attestor, digest, signature, _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        StreamIndependentReads.requireSubject(core, coreCodeHash, subject, cap);
        StreamIndependentReads.requireCode(schemaRegistry, schemaRegistryCodeHash);
        Receipt memory receipt;
        receipt.schemaDefinitionHash = StreamIndependentReads.definition(
            schemaRegistry, r.schemaId, IStreamSchemaRegistry.DocumentKind.SCHEMA, cap
        );
        receipt.canonicalizationDefinitionHash = StreamIndependentReads.definition(
            schemaRegistry,
            r.canonicalizationId,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            cap
        );
        // No effects occur until identity, exact signature, current gas and immutable definitions pass.
        _used[r.attestor][r.nonce] = true;
        bytes memory bundle = abi.encode(
            StreamIndependentRecordHash.domain(), StreamIndependentRecordHash.words(r), signature
        );
        if (bundle.length > MAX_SIGNATURE_BUNDLE_BYTES) revert InvalidIndependentRecord();
        IStreamPreservationRecords.CollectionRecord memory record =
            IStreamPreservationRecords.CollectionRecord({
                recordType: r.recordType,
                subjectId: r.subjectId,
                contentHash: IStreamPreservationRecords.HashRef(
                    r.algorithmId, r.digest, r.canonicalizationId
                ),
                uri: r.uri,
                schemaId: r.schemaId,
                signatureScheme: scheme,
                signatureHash: IStreamPreservationRecords.HashRef(
                    1, abi.encode(keccak256(bundle)), _RAW_BYTES
                ),
                effectiveAt: r.effectiveAt
            });
        hash = StreamCollectionRecordHashes.recordHash(core, r.attestor, r.scopeKey, record);
        if (_records[hash].receipt.attestor != address(0)) revert IndependentRecordExists(hash);
        Stored storage stored = _records[hash];
        stored.payloadPointer = _publish(r.scopeKey, _FAMILY, r.payload);
        stored.signaturePointer = _publish(r.scopeKey, _BUNDLE_FAMILY, bundle);
        receipt.scopeKey = r.scopeKey;
        receipt.attestor = r.attestor;
        receipt.authorizationClass = 5;
        receipt.recordedAt = uint64(block.timestamp);
        receipt.authorizationDigest = digest;
        receipt.nonce = r.nonce;
        receipt.deadline = r.deadline;
        _commit(hash, stored, record, subject, receipt);
    }

    function revokeIndependentAttestorNonce(uint256 nonce) external override nonReentrant {
        _revoke(msg.sender, nonce);
    }

    function revokeIndependentAttestorNonceFor(
        address attestor,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        _fresh(attestor, nonce);
        _deadline(deadline);
        StreamIndependentSignatures.verify(
            attestor,
            independentRevocationDigest(attestor, nonce, deadline),
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
        _revoke(attestor, nonce);
    }

    function isIndependentAttestorNonceUsed(address attestor, uint256 nonce)
        external
        view
        override
        returns (bool)
    {
        return _used[attestor][nonce];
    }

    function _fresh(address attestor, uint256 nonce) private view {
        if (attestor == address(0)) revert InvalidIndependentSignature(attestor);
        if (_used[attestor][nonce]) revert IndependentNonceUsed(attestor, nonce);
    }

    function _deadline(uint64 deadline) private view {
        if (deadline < block.timestamp) revert IndependentDeadlineExpired(deadline);
    }

    function _revoke(address attestor, uint256 nonce) private {
        _fresh(attestor, nonce);
        _used[attestor][nonce] = true;
        emit IndependentAttestorNonceRevoked(attestor, nonce, msg.sender, 1);
    }

    function _commit(
        bytes32 hash,
        Stored storage stored,
        IStreamPreservationRecords.CollectionRecord memory record,
        Subject calldata subject,
        Receipt memory receipt
    ) private {
        uint256 count = _history[receipt.scopeKey][record.recordType].length;
        if (count == type(uint64).max) revert InvalidIndependentRecord();
        receipt.recordIndex = uint64(count);
        receipt.recordChainHash = StreamCollectionRecordHashes.nextChain(
            receipt.scopeKey,
            record.recordType,
            _chains[receipt.scopeKey][record.recordType],
            hash,
            uint64(count)
        );
        stored.record = record;
        stored.receipt = receipt;
        stored.subject = subject;
        _history[receipt.scopeKey][record.recordType].push(hash);
        _chains[receipt.scopeKey][record.recordType] = receipt.recordChainHash;
        _latest[
            keccak256(
                abi.encode(receipt.scopeKey, record.recordType, record.subjectId, receipt.attestor)
            )
        ] = hash;
        emit IndependentPreservationRecordRecorded(
            receipt.scopeKey,
            record.recordType,
            record.subjectId,
            record,
            hash,
            receipt.recordChainHash,
            receipt.attestor,
            bytes32(uint256(5)),
            1
        );
    }

    function _publish(uint256 scopeKey, bytes32 family, bytes memory payload)
        private
        returns (address pointer)
    {
        StreamIndependentReads.requireCode(chunkStore, chunkStoreCodeHash);
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(chunkStore).publishChunk(payload);
        if (hash != keccak256(payload) || pointer.code.length != payload.length + 1) {
            revert InvalidIndependentRecord();
        }
        bytes32 key = keccak256(abi.encode(family, hash));
        if (!_pointerSeen[scopeKey][key]) {
            _pointerSeen[scopeKey][key] = true;
            _pointers[scopeKey].push(Pointer(pointer, family, hash));
        }
    }

    function collectionRecord(bytes32 hash)
        external
        view
        override
        returns (IStreamPreservationRecords.CollectionRecord memory, Receipt memory)
    {
        Stored storage s = _known(hash);
        return (s.record, s.receipt);
    }

    function recordSubject(bytes32 hash) external view override returns (Subject memory) {
        return _known(hash).subject;
    }

    function recordPayload(bytes32 hash)
        public
        view
        override
        returns (address pointer, bytes memory payload)
    {
        Stored storage s = _known(hash);
        return (s.payloadPointer, _payload(s.payloadPointer, bytes32(s.record.contentHash.digest)));
    }

    function recordSignatureBundle(bytes32 hash)
        external
        view
        override
        returns (address pointer, bytes memory bundle)
    {
        Stored storage s = _known(hash);
        return (
            s.signaturePointer, _payload(s.signaturePointer, bytes32(s.record.signatureHash.digest))
        );
    }

    function _payload(address pointer, bytes32 hash) private view returns (bytes memory payload) {
        if (pointer.code.length == 0 || pointer.code.length > 8193) {
            revert IndependentDependencyChanged(pointer);
        }
        payload = SSTORE2.read(pointer);
        if (keccak256(payload) != hash) revert IndependentDependencyChanged(pointer);
    }

    function collectionRecordPayload(uint256 scopeKey, bytes32 recordType, bytes32 subjectId)
        external
        view
        override
        returns (address, bytes memory)
    {
        return
            recordPayload(
                latestCollectionRecordHashFor(scopeKey, recordType, subjectId, msg.sender)
            );
    }

    function latestCollectionRecordHashFor(
        uint256 scopeKey,
        bytes32 recordType,
        bytes32 subjectId,
        address recorder
    ) public view override returns (bytes32) {
        return _latest[keccak256(abi.encode(scopeKey, recordType, subjectId, recorder))];
    }

    function recordChainHash(uint256 scopeKey, bytes32 recordType)
        external
        view
        override
        returns (bytes32, uint64)
    {
        return (_chains[scopeKey][recordType], uint64(_history[scopeKey][recordType].length));
    }

    function recordHashAt(uint256 scopeKey, bytes32 recordType, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[scopeKey][recordType][index];
    }

    function payloadPointerCount(uint256 scopeKey) external view override returns (uint256) {
        return _pointers[scopeKey].length;
    }

    function payloadPointerAt(uint256 scopeKey, uint256 index)
        external
        view
        override
        returns (address, bytes32, bytes32)
    {
        Pointer memory p = _pointers[scopeKey][index];
        return (p.pointer, p.family, p.hash);
    }

    function _known(bytes32 hash) private view returns (Stored storage s) {
        s = _records[hash];
        if (s.receipt.attestor == address(0)) revert IndependentRecordUnknown(hash);
    }
}
