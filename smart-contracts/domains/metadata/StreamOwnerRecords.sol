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
import "../records/StreamOwnerNoticeAdmission.sol";
import "../records/StreamOwnerRecoveryNoticeState.sol";
import "../records/StreamOwnerRecordBook.sol";
import "../records/StreamOwnerRecordAuthorizations.sol";

/// @notice Owner-authored permanent dossiers, independent of artwork locks and platform grants.
/// @dev Generic records commit statements. Typed recovery notice/response interpretation is separate.
contract StreamOwnerRecords is
    StreamModuleBase,
    StreamGasParameterHost,
    ReentrancyGuard,
    IStreamOwnerRecords,
    IStreamOwnerStewardRecords,
    IStreamOwnerRecoveryNotices,
    IStreamOwnerPreparedRecoveryNotices,
    IStreamFinalityRecoveryOwnerEvidence,
    IERC5267
{
    // Retain the original public error ABI after immutable payload reads move to Book.
    error SSTORE2InvalidPointer(address pointer);

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
    bytes32 public constant RECOVERY_INTENT_READ_GAS =
        keccak256("6529STREAM_GGP_OWNER_RECOVERY_INTENT_READ_GAS");
    bytes32 public constant STREAM_OWNER_RECORD_TYPEHASH = StreamOwnerRecordHash.RECORD_TYPEHASH;
    bytes32 public constant STREAM_OWNER_RECORD_REVOCATION_TYPEHASH =
        StreamOwnerRecordHash.REVOCATION_TYPEHASH;
    bytes32 private constant TOKEN =
        0x1e576f27850d12bc1ec9255ca277dbecfbc84fb3a9a34c474640dfca89811d7e;

    mapping(address => mapping(uint256 => bool)) private _used;
    mapping(bytes32 => StreamOwnerRecordBook.Stored) private _records;
    mapping(uint256 => mapping(bytes32 => bytes32[])) private _history;
    mapping(uint256 => mapping(bytes32 => bytes32)) private _chains;
    mapping(bytes32 => bytes32) private _latest;
    mapping(bytes32 => bool) private _additionalTypes;
    // Durable per-author designation; historical entries survive transfers and burns.
    mapping(uint256 => mapping(address => bytes32)) private _stewards;
    StreamOwnerRecoveryNoticeState.State private _notices;
    StreamOwnerRecoveryNoticePreparation.State private _preparedNotices;

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
        _registerGasParameter(
            GasParameterConfig(
                "OWNER_RECOVERY_INTENT_READ_GAS",
                8000000,
                8000000,
                FAILURE_CLASS_FAIL_CLOSED_PRECHECK
            )
        );
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
        return id == type(IStreamOwnerRecords).interfaceId
            || id == type(IStreamOwnerStewardRecords).interfaceId
            || id == type(IStreamOwnerRecoveryNotices).interfaceId
            || id == type(IStreamOwnerPreparedRecoveryNotices).interfaceId
            || id == type(IStreamFinalityRecoveryOwnerEvidence).interfaceId
            || id == type(IERC5267).interfaceId || id == type(IStreamGasParameterHost).interfaceId
            || super.supportsInterface(id);
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
        return StreamOwnerRecordBook.isKnownType(_additionalTypes, t);
    }

    function ownerRecordDigest(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline
    ) public view override returns (bytes32) {
        return StreamOwnerRecordAuthorizations.digest(tokenId, r, owner, nonce, deadline);
    }

    function ownerRecordRevocationDigest(address owner, uint256 nonce, uint64 deadline)
        public
        view
        override
        returns (bytes32)
    {
        return StreamOwnerRecordAuthorizations.revocation(owner, nonce, deadline);
    }

    function recordOwnerRecord(uint256 tokenId, OwnerRecord calldata r)
        external
        override
        nonReentrant
    {
        StreamOwnerNoticeAdmission.requireGeneric(r);
        _directAppend(tokenId, r);
    }

    function _directAppend(uint256 tokenId, OwnerRecord calldata r) private returns (bytes32) {
        return StreamOwnerRecordBook.directAppend(
            _records,
            _history,
            _chains,
            _latest,
            _bookConfiguration(),
            StreamOwnerRecordBook.DirectInput(tokenId, r, isOwnerRecordType(r.recordType))
        );
    }

    function recordOwnerRecordFor(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        StreamOwnerNoticeAdmission.requireGeneric(r);
        _signedAppend(tokenId, r, owner, nonce, deadline, signature);
    }

    function _signedAppend(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) private returns (bytes32) {
        StreamOwnerRecordBook.SignedInput memory input;
        input.authorization = StreamOwnerRecordAuthorizations.SignedInput(
            tokenId,
            r,
            owner,
            nonce,
            deadline,
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
        input.knownType = isOwnerRecordType(r.recordType);
        return StreamOwnerRecordBook.signedAppend(
            _used, _records, _history, _chains, _latest, _bookConfiguration(), input
        );
    }

    function recordStewardDesignation(
        uint256 tokenId,
        OwnerRecord calldata r,
        StreamOwnerNoticeTypes.Designation calldata designation
    ) external override nonReentrant {
        _requireSteward(tokenId, msg.sender, r, designation);
        bytes32 hash = _directAppend(tokenId, r);
        _saveSteward(tokenId, msg.sender, hash, designation.predecessor);
    }

    function recordStewardDesignationFor(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature,
        StreamOwnerNoticeTypes.Designation calldata designation
    ) external override nonReentrant {
        _requireSteward(tokenId, owner, r, designation);
        bytes32 hash = _signedAppend(tokenId, r, owner, nonce, deadline, signature);
        _saveSteward(tokenId, owner, hash, designation.predecessor);
    }

    function _requireSteward(
        uint256 tokenId,
        address owner,
        OwnerRecord calldata r,
        StreamOwnerNoticeTypes.Designation calldata designation
    ) private view {
        bytes32 head = _stewards[tokenId][owner];
        if (designation.predecessor != head) {
            revert StewardPredecessorChanged(head, designation.predecessor);
        }
        StreamOwnerNoticeAdmission.requireSteward(
            StreamOwnerNoticeAdmission.Configuration(
                schemaRegistry,
                schemaRegistryCodeHash,
                chunkStore,
                chunkStoreCodeHash,
                _gasParameterValue(DEPENDENCY_READ_GAS)
            ),
            r,
            designation
        );
    }

    function _saveSteward(uint256 tokenId, address owner, bytes32 hash, bytes32 predecessor)
        private
    {
        _stewards[tokenId][owner] = hash;
        emit OwnerStewardDesignated(tokenId, owner, hash, predecessor, 1);
    }

    function stewardDesignationFor(uint256 tokenId, address owner)
        external
        view
        override
        returns (bytes32)
    {
        return _stewards[tokenId][owner];
    }

    function currentStewardDesignation(uint256 tokenId)
        external
        view
        override
        returns (address owner, bytes32 recordHash)
    {
        owner = StreamOwnerRecordReads.owner(
            core, coreCodeHash, tokenId, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
        return (owner, _stewards[tokenId][owner]);
    }

    function _noticeConfiguration()
        private
        view
        returns (StreamOwnerRecoveryNoticeState.Configuration memory)
    {
        return StreamOwnerRecoveryNoticeState.Configuration(
            StreamOwnerRecoveryActionReads.Config(
                core,
                coreCodeHash,
                governanceAuthority,
                executorCodeHash,
                address(this),
                _gasParameterValue(DEPENDENCY_READ_GAS),
                _gasParameterValue(RECOVERY_INTENT_READ_GAS)
            ),
            chunkStore,
            chunkStoreCodeHash
        );
    }

    function openRecoveryNotice(
        bytes32 actionId,
        GovernanceCall[] calldata calls,
        StreamFinalityRecoveryRequest calldata request,
        StreamOwnerNoticeTypes.Designation calldata steward,
        StreamOwnerRecoveryNoticeTypes.Publication calldata publication
    ) external override nonReentrant {
        uint256 tokenId = request.scope.tokenId;
        address owner = StreamOwnerRecordReads.owner(
            core, coreCodeHash, tokenId, _gasParameterValue(DEPENDENCY_READ_GAS)
        );
        bytes32 hash = _stewards[tokenId][owner];
        StreamOwnerRecoveryNoticeState.open(
            _notices,
            _noticeConfiguration(),
            StreamOwnerRecoveryNoticeState.OpeningWitness(
                actionId,
                calls,
                request,
                StreamOwnerRecoveryNoticeState.OriginalOwner(
                    owner,
                    hash,
                    _records[hash].payloadHash,
                    uint64(_history[tokenId][keccak256("RECOVERY_RESPONSE")].length)
                ),
                steward,
                publication
            )
        );
    }

    function _preparationConfiguration()
        private
        view
        returns (StreamOwnerRecoveryNoticePreparation.Configuration memory)
    {
        return StreamOwnerRecoveryNoticePreparation.Configuration(
            core,
            coreCodeHash,
            chunkStore,
            chunkStoreCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function prepareRecoveryNotice(StreamOwnerPreparedNoticeTypes.Input calldata input)
        external
        override
        nonReentrant
        returns (bytes32)
    {
        return StreamOwnerRecoveryNoticePreparation.begin(
            _preparedNotices, _stewards, _records, _preparationConfiguration(), input
        );
    }

    function prepareRecoveryNoticeDelivery(
        bytes32 id,
        StreamOwnerRecoveryNoticeTypes.Delivery calldata delivery
    ) external override nonReentrant {
        StreamOwnerRecoveryNoticePreparation.append(
                _preparedNotices, _preparationConfiguration(), id, delivery
            );
    }

    function openPreparedRecoveryNotice(
        bytes32 id,
        GovernanceCall[] calldata calls,
        StreamFinalityRecoveryRequest calldata request
    ) external override nonReentrant {
        StreamOwnerRecoveryNoticeState.openPrepared(
            _notices,
            _preparedNotices,
            _stewards,
            _noticeConfiguration(),
            StreamOwnerRecoveryNoticeState.PreparedOpeningWitness(
                id,
                calls,
                request,
                uint64(_history[request.scope.tokenId][keccak256("RECOVERY_RESPONSE")].length)
            )
        );
    }

    function recoveryNoticePreparation(bytes32 id)
        external
        view
        override
        returns (StreamOwnerPreparedNoticeTypes.Snapshot memory)
    {
        bytes memory encoded =
            StreamOwnerRecoveryNoticePreparation.encodedSnapshot(_preparedNotices, id);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recoveryNoticePreparedClaim(bytes32 id, uint256 index)
        external
        view
        override
        returns (address pointer, bytes memory originalBytes)
    {
        bytes memory encoded =
            StreamOwnerRecoveryNoticePreparation.encodedClaim(_preparedNotices, id, index);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recoveryNoticePreparationFor(bytes32 actionId)
        external
        view
        override
        returns (bytes32)
    {
        return _preparedNotices.notices[actionId];
    }

    function recordRecoveryResponse(
        uint256 tokenId,
        OwnerRecord calldata r,
        StreamOwnerNoticeTypes.Response calldata response
    ) external override nonReentrant {
        _requireResponse(r, response);
        bytes32 hash = _directAppend(tokenId, r);
        StreamOwnerRecoveryNoticeState.append(_notices, hash, _records[hash].receipt, response);
    }

    function recordRecoveryResponseFor(
        uint256 tokenId,
        OwnerRecord calldata r,
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature,
        StreamOwnerNoticeTypes.Response calldata response
    ) external override nonReentrant {
        _requireResponse(r, response);
        bytes32 hash = _signedAppend(tokenId, r, owner, nonce, deadline, signature);
        StreamOwnerRecoveryNoticeState.append(_notices, hash, _records[hash].receipt, response);
    }

    function _requireResponse(
        OwnerRecord calldata r,
        StreamOwnerNoticeTypes.Response calldata response
    ) private view {
        StreamOwnerNoticeAdmission.requireResponse(
            StreamOwnerNoticeAdmission.Configuration(
                schemaRegistry,
                schemaRegistryCodeHash,
                chunkStore,
                chunkStoreCodeHash,
                _gasParameterValue(DEPENDENCY_READ_GAS)
            ),
            r,
            response
        );
    }

    function processRecoveryResponse(bytes32 actionId)
        external
        override
        nonReentrant
        returns (bool)
    {
        return StreamOwnerRecoveryNoticeState.process(_notices, _noticeConfiguration(), actionId);
    }

    function verifyRecoveryOwnerEvidence(
        StreamFinalityScope calldata scope,
        bytes32 actionId,
        bytes32 manifest
    ) external view override returns (bool, bytes32, uint64, uint64, uint32, uint32) {
        return StreamOwnerRecoveryNoticeState.evidence(
            _notices, _noticeConfiguration(), scope, actionId, manifest
        );
    }

    function recoveryNotice(bytes32 actionId)
        external
        view
        override
        returns (StreamOwnerRecoveryNoticeTypes.Snapshot memory)
    {
        bytes memory encoded = StreamOwnerRecoveryNoticeState.encodedSnapshot(_notices, actionId);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recoveryNoticeClaim(bytes32 actionId, uint256 index)
        external
        view
        override
        returns (address, bytes memory)
    {
        bytes memory encoded = StreamOwnerRecoveryNoticeState.encodedClaim(
            _notices, _preparedNotices, actionId, index
        );
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recoveryResponse(bytes32 hash)
        external
        view
        override
        returns (StreamOwnerRecoveryNoticeTypes.Response memory)
    {
        bytes memory encoded = StreamOwnerRecoveryNoticeState.encodedResponse(_notices, hash);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function recoveryResponseAt(bytes32 actionId, uint256 index)
        external
        view
        override
        returns (bytes32)
    {
        return StreamOwnerRecoveryNoticeState.responseAt(_notices, actionId, index);
    }

    function latestCountedRecoveryResponse(bytes32 actionId, address author)
        external
        view
        override
        returns (bytes32)
    {
        return StreamOwnerRecoveryNoticeState.latest(_notices, actionId, author);
    }

    function _bookConfiguration()
        private
        view
        returns (StreamOwnerRecordBook.Configuration memory)
    {
        return StreamOwnerRecordBook.Configuration(
            core,
            coreCodeHash,
            schemaRegistry,
            schemaRegistryCodeHash,
            chunkStore,
            chunkStoreCodeHash,
            _gasParameterValue(DEPENDENCY_READ_GAS)
        );
    }

    function revokeOwnerRecordNonce(uint256 nonce) external override nonReentrant {
        StreamOwnerRecordAuthorizations.revoke(_used, msg.sender, nonce, false);
    }

    function revokeOwnerRecordNonceFor(
        address owner,
        uint256 nonce,
        uint64 deadline,
        bytes calldata signature
    ) external override nonReentrant {
        StreamOwnerRecordAuthorizations.revokeFor(
            _used,
            owner,
            nonce,
            deadline,
            signature,
            _gasParameterValue(GGP_METADATA_ERC1271_VERIFY_GAS)
        );
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
        bytes memory encoded = StreamOwnerRecordBook.encodedRecord(_records, hash);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
    }

    function ownerRecordSignatureBundle(bytes32 hash)
        external
        view
        override
        returns (address, bytes memory)
    {
        bytes memory encoded = StreamOwnerRecordBook.encodedSignature(_records, hash);
        assembly ("memory-safe") { return(add(encoded, 32), mload(encoded)) }
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
