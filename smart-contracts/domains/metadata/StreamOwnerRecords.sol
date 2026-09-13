// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/metadata/IStreamOwnerRecords.sol";
import "../../interfaces/standards/IERC5267.sol";
import "../../vendor/openzeppelin/ReentrancyGuard.sol";
import "../modules/StreamModuleBase.sol";
import "../parameters/StreamGasParameterHost.sol";
import "../records/StreamCollectionRecordHashes.sol";
import "./StreamSchemaDocumentStore.sol";
import "./StreamMetadataRenderer.sol";
import "./StreamOwnerRecordHash.sol";
import "./StreamOwnerRecordReads.sol";
import "./StreamOwnerRecordSignatures.sol";

/// @notice Owner-authored permanent dossiers, independent of artwork locks and platform grants.
/// @dev Generic records commit statements. Typed recovery notice/response interpretation is separate.
contract StreamOwnerRecords is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamOwnerRecords,
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
        OwnerRecord record;
        Receipt receipt;
        address payloadPointer;
        address signaturePointer;
        bytes32 payloadHash;
    }

    address public immutable override core;
    address public immutable override schemaRegistry;
    address public immutable override chunkStore;
    bytes32 public immutable coreCodeHash;
    bytes32 public immutable schemaRegistryCodeHash;
    bytes32 public immutable chunkStoreCodeHash;
    bytes32 public immutable executorCodeHash;
    uint256 public constant MAX_RECORD_PAYLOAD_BYTES = 8192;
    uint256 public constant METADATA_ERC1271_VERIFY_GAS_FLOOR = 90000;
    bytes32 public constant GGP_METADATA_ERC1271_VERIFY_GAS =
        0x3ca324ef8262b1ff4cb8753a082cd8780e50f754c1a323a433e0e7665a5ec9f9;
    bytes32 public constant DEPENDENCY_READ_GAS =
        keccak256("6529STREAM_GGP_METADATA_DEPENDENCY_READ_GAS");
    bytes32 public constant STREAM_OWNER_RECORD_TYPEHASH = StreamOwnerRecordHash.RECORD_TYPEHASH;
    bytes32 public constant STREAM_OWNER_RECORD_REVOCATION_TYPEHASH =
        StreamOwnerRecordHash.REVOCATION_TYPEHASH;
    bytes32 private constant TOKEN =
        0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;

    mapping(address => mapping(uint256 => bool)) private _used;
    mapping(bytes32 => Stored) private _records;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(bytes32 => bytes32) private _latest;
    mapping(bytes32 => bool) private _additionalTypes;

    constructor(Configuration memory c)
        StreamModuleBase(
            keccak256("6529stream.owner-records.v1"),
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
                || !IERC165(c.schemas)
                    .supportsInterface(type(IStreamSchemaDocumentFacts).interfaceId)
                || (c.executor != address(0)
                    && IStreamSchemaRegistry(c.schemas).governanceAuthority() != c.executor)
                || c.signatureGas.floor != METADATA_ERC1271_VERIFY_GAS_FLOOR
                || c.signatureGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || c.dependencyReadGas.failureClass != FAILURE_CLASS_FAIL_CLOSED_PRECHECK
                || _registerGasParameter(c.signatureGas) != GGP_METADATA_ERC1271_VERIFY_GAS
                || _registerGasParameter(c.dependencyReadGas) != DEPENDENCY_READ_GAS
        ) revert InvalidOwnerRecordsConfiguration();
        core = c.core;
        schemaRegistry = c.schemas;
        chunkStore = IStreamSchemaRegistry(c.schemas).chunkStore();
        if (chunkStore.code.length == 0) revert InvalidOwnerRecordsConfiguration();
        coreCodeHash = c.core.codehash;
        schemaRegistryCodeHash = c.schemas.codehash;
        chunkStoreCodeHash = chunkStore.codehash;
        executorCodeHash = c.executor.codehash;
        StreamMetadataRenderer.requireValidUtf8ContentUri(
            "moduleManifestURI", c.manifestURI, 2048, false
        );
    }

    function streamModuleType() public pure override returns (bytes32) {
        return keccak256("OWNER_RECORDS");
    }

    function streamModuleVersion() public pure override returns (bytes32) {
        return keccak256("6529stream.owner-records.v1");
    }

    function streamModuleInterfaceId() public pure override returns (bytes4) {
        return type(IStreamOwnerRecords).interfaceId;
    }

    function supportsInterface(bytes4 id)
        public
        view
        override(StreamModuleBase, IERC165)
        returns (bool)
    {
        return id == type(IStreamOwnerRecords).interfaceId || id == type(IERC5267).interfaceId
            || id == type(IStreamGasParameterHost).interfaceId || super.supportsInterface(id);
    }

    function eip712Domain()
        external
        view
        override
        returns (bytes1, string memory, string memory, uint256, address, bytes32, uint256[] memory)
    {
        return
            (0x0f, "6529StreamOwnerRecords", "1", block.chainid, address(this), 0, new uint256[](0));
    }

    function deriveOwnerSubject(uint256 tokenId) public view override returns (bytes32) {
        if (tokenId == 0) revert InvalidOwnerRecord();
        return keccak256(abi.encode(TOKEN, block.chainid, core, tokenId));
    }

    function isOwnerRecordType(bytes32 t) public view override returns (bool) {
        return t == keccak256("ACCESSION") || t == keccak256("CONDITION_REPORT")
            || t == keccak256("EXHIBITION") || t == keccak256("LOAN")
            || t == keccak256("DEACCESSION") || t == keccak256("CITATION")
            || t == keccak256("VALUATION") || t == keccak256("STEWARD_DESIGNATION")
            || t == keccak256("RECOVERY_RESPONSE") || t == keccak256("REDEMPTION_CLAIM")
            || _additionalTypes[t];
    }

    function ownerRecordDigest(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) public view override returns (bytes32) {
        return StreamOwnerRecordHash.record(tokenId, r, owner, nonce, deadline);
    }

    function ownerRecordRevocationDigest(address owner, uint256 nonce, uint64 deadline)
        public
        view
        override
        returns (bytes32)
    {
        return StreamOwnerRecordHash.revocation(owner, nonce, deadline);
    }

    function recordOwnerRecord(uint256 tokenId, OwnerRecord calldata r)
        external
        override
        nonReentrant
    {
        Receipt memory receipt;
        receipt.owner = msg.sender;
        receipt.signatureScheme = keccak256("DIRECT");
        // This original bundle binds even opaque external algorithms to the retained payload bytes.
        bytes memory bundle = abi.encode(receipt.signatureScheme, msg.sender, keccak256(r.payload));
        _append(tokenId, r, receipt, bundle);
    }

    function recordOwnerRecordFor(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        _fresh(owner, nonce);
        _deadline(deadline);
        Receipt memory receipt;
        receipt.owner = owner;
        receipt.relayed = true;
        receipt.nonce = nonce;
        receipt.deadline = deadline;
        receipt.authorizationDigest = ownerRecordDigest(tokenId, r, owner, nonce, deadline);
        receipt.signatureScheme = StreamOwnerRecordSignatures.verify(
            owner,
            receipt.authorizationDigest,
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
        bytes memory bundle = abi.encode(
            StreamOwnerRecordHash.domain(),
            StreamOwnerRecordHash.words(tokenId, r, owner, nonce, deadline),
            signature
        );
        _used[owner][nonce] = true;
        _append(tokenId, r, receipt, bundle);
    }

    function _append(
        uint256 tokenId,
        OwnerRecord calldata r,
        Receipt memory receipt,
        bytes memory bundle
    ) private {
        uint256 cap = _gasParameterValue(DEPENDENCY_READ_GAS);
        if (receipt.owner != StreamOwnerRecordReads.owner(core, coreCodeHash, tokenId, cap)) {
            revert OwnerRecordAuthorityRequired(receipt.owner);
        }
        _validate(tokenId, r);
        StreamOwnerRecordReads.requireCode(schemaRegistry, schemaRegistryCodeHash);
        receipt.schemaDefinitionHash = StreamOwnerRecordReads.definition(
            schemaRegistry, r.schemaId, IStreamSchemaRegistry.DocumentKind.SCHEMA, cap
        );
        receipt.canonicalizationDefinitionHash = StreamOwnerRecordReads.definition(
            schemaRegistry,
            r.contentHash.canonicalizationId,
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            cap
        );
        receipt.tokenId = tokenId;
        receipt.recordedAt = uint64(block.timestamp);
        receipt.signatureBundleHash = keccak256(bundle);
        IStreamPreservationRecords.CollectionRecord memory genericRecord =
            IStreamPreservationRecords.CollectionRecord(
                r.recordType,
                r.subjectId,
                r.contentHash,
                r.uri,
                r.schemaId,
                receipt.signatureScheme,
                IStreamPreservationRecords.HashRef(
                    1, abi.encode(receipt.signatureBundleHash), keccak256("RAW_BYTES")
                ),
                r.effectiveAt
            );
        bytes32 hash =
            StreamCollectionRecordHashes.recordHash(core, receipt.owner, tokenId, genericRecord);
        if (_records[hash].receipt.owner != address(0)) revert OwnerRecordExists(hash);
        uint256 count = _history[tokenId][r.recordType].length;
        if (count == type(uint64).max) revert InvalidOwnerRecord();
        receipt.recordIndex = uint64(count);
        receipt.recordChainHash = StreamCollectionRecordHashes.nextChain(
            tokenId, r.recordType, _chains[tokenId][r.recordType], hash, uint64(count)
        );
        Stored storage stored = _records[hash];
        stored.signaturePointer = _publish(bundle);
        if (r.payload.length != 0) stored.payloadPointer = _publish(r.payload);
        stored.payloadHash = keccak256(r.payload);
        stored.record.recordType = r.recordType;
        stored.record.subjectId = r.subjectId;
        stored.record.schemaId = r.schemaId;
        stored.record.contentHash = r.contentHash;
        stored.record.uri = r.uri;
        stored.record.effectiveAt = r.effectiveAt;
        stored.receipt = receipt;
        _history[tokenId][r.recordType].push(hash);
        _chains[tokenId][r.recordType] = receipt.recordChainHash;
        _latest[keccak256(abi.encode(tokenId, r.recordType, receipt.owner))] = hash;
        emit OwnerRecordRecorded(
            tokenId,
            r.recordType,
            receipt.owner,
            r,
            hash,
            receipt.recordChainHash,
            receipt.relayed,
            1
        );
    }

    function _validate(uint256 tokenId, OwnerRecord calldata r) private view {
        if (
            !isOwnerRecordType(r.recordType) || r.subjectId != deriveOwnerSubject(tokenId)
                || r.schemaId == 0 || r.contentHash.canonicalizationId == 0
                || r.payload.length > MAX_RECORD_PAYLOAD_BYTES || r.effectiveAt == 0
                || block.timestamp > type(uint64).max
        ) revert InvalidOwnerRecord();
        uint16 algorithm = r.contentHash.algorithm;
        uint256 size = r.contentHash.digest.length;
        if (algorithm == 1 || algorithm == 2 || algorithm == 3 || algorithm == 6) {
            if (size != 32) revert InvalidOwnerRecord();
        } else if (algorithm == 4 || algorithm == 5) {
            if (size == 0 || size > 128) revert InvalidOwnerRecord();
        } else {
            revert InvalidOwnerRecord();
        }
        // Algorithms without an onchain implementation remain explicit opaque commitments.
        if (r.payload.length != 0) {
            if (algorithm == 1 && bytes32(r.contentHash.digest) != keccak256(r.payload)) {
                revert InvalidOwnerRecord();
            }
            if (algorithm == 2 && bytes32(r.contentHash.digest) != sha256(r.payload)) {
                revert InvalidOwnerRecord();
            }
        }
        StreamMetadataRenderer.requireValidUtf8ContentUri("recordURI", r.uri, 2048, true);
    }

    function _publish(bytes memory payload) private returns (address pointer) {
        StreamOwnerRecordReads.requireCode(chunkStore, chunkStoreCodeHash);
        bytes32 hash;
        (hash, pointer) = StreamSchemaDocumentStore(chunkStore).publishChunk(payload);
        if (hash != keccak256(payload) || pointer.code.length != payload.length + 1) {
            revert InvalidOwnerRecord();
        }
    }

    function _payload(address pointer, bytes32 hash) private view returns (bytes memory payload) {
        if (pointer == address(0)) {
            if (hash != keccak256(bytes(""))) revert InvalidOwnerRecord();
            return bytes("");
        }
        if (pointer.code.length == 0 || pointer.code.length > 8193) {
            revert OwnerRecordDependencyChanged(pointer);
        }
        payload = SSTORE2.read(pointer);
        if (keccak256(payload) != hash) revert OwnerRecordDependencyChanged(pointer);
    }

    function _fresh(address owner, uint256 nonce) private view {
        if (owner == address(0)) revert InvalidOwnerRecordSignature(owner);
        if (_used[owner][nonce]) revert OwnerRecordNonceUsed(owner, nonce);
    }

    function _deadline(uint64 deadline) private view {
        if (deadline < block.timestamp) revert OwnerRecordDeadlineExpired(deadline);
    }

    function revokeOwnerRecordNonce(uint256 nonce) external override nonReentrant {
        _revoke(msg.sender, nonce, false);
    }

    function revokeOwnerRecordNonceFor(
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        _fresh(owner, nonce);
        _deadline(deadline);
        StreamOwnerRecordSignatures.verify(
            owner,
            ownerRecordRevocationDigest(owner, nonce, deadline),
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
        _revoke(owner, nonce, true);
    }

    function _revoke(address owner, uint256 nonce, bool relayed) private {
        _fresh(owner, nonce);
        _used[owner][nonce] = true;
        emit OwnerRecordNonceRevoked(owner, nonce, relayed, 1);
    }

    function isOwnerRecordNonceUsed(address owner, uint256 nonce)
        external
        view
        override
        returns (bool)
    {
        return _used[owner][nonce];
    }

    function ownerRecord(bytes32 hash)
        external
        view
        override
        returns (OwnerRecord memory record, Receipt memory receipt)
    {
        Stored storage s = _known(hash);
        record = s.record;
        record.payload = _payload(s.payloadPointer, s.payloadHash);
        return (record, s.receipt);
    }

    function ownerRecordSignatureBundle(bytes32 hash)
        external
        view
        override
        returns (address, bytes memory)
    {
        Stored storage s = _known(hash);
        return (s.signaturePointer, _payload(s.signaturePointer, s.receipt.signatureBundleHash));
    }

    function recordHashAt(uint256 tokenId, bytes32 recordType, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return _history[tokenId][recordType][index];
    }

    function recordChainHash(uint256 tokenId, bytes32 recordType)
        external
        view
        override
        returns (bytes32, uint64)
    {
        return (_chains[tokenId][recordType], uint64(_history[tokenId][recordType].length));
    }

    function latestOwnerRecordHashFor(uint256 tokenId, bytes32 recordType, address owner)
        external
        view
        override
        returns (bytes32)
    {
        return _latest[keccak256(abi.encode(tokenId, recordType, owner))];
    }

    function _known(bytes32 hash) private view returns (Stored storage stored) {
        stored = _records[hash];
        if (stored.receipt.owner == address(0)) revert OwnerRecordUnknown(hash);
    }

    function ownerRecordTypeTransition(bytes32 t)
        public
        view
        override
        returns (bytes32, bytes32, bytes32)
    {
        bytes32 domain = keccak256("6529STREAM_OWNER_RECORD_TYPE_V1");
        return (
            keccak256(abi.encode(domain, block.chainid, address(this), t)),
            keccak256(abi.encode(domain, isOwnerRecordType(t))),
            keccak256(abi.encode(domain, true))
        );
    }

    function admitOwnerRecordType(bytes32 t) external override nonReentrant {
        if (t == 0 || isOwnerRecordType(t)) revert InvalidOwnerRecord();
        if (msg.sender != governanceAuthority || msg.sender.codehash != executorCodeHash) {
            revert OwnerRecordGovernanceRequired();
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) = ownerRecordTypeTransition(t);
        (bool active, bytes32 id, uint8 c, bytes32 s, bytes32 o, bytes32 n) =
            IStreamGovernedParameterAuthority(governanceAuthority).currentAction();
        if (!active || id == 0 || c != 1 || s != scope || o != oldHash || n != newHash) {
            revert OwnerRecordGovernanceRequired();
        }
        _additionalTypes[t] = true;
        emit OwnerRecordTypeAdmitted(t, id, 1);
    }
}
