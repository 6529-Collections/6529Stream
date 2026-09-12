// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import "../../../smart-contracts/domains/metadata/StreamSchemaRegistry.sol";
import "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadata.sol";
import "../../regression/legacy/helpers/CharacterizationTestBase.sol";
import "../../helpers/OfficialSafeFixture.sol";

/// @dev Explicit current-Core and governance boundaries. Real Core/Executor composition is separate.
contract MetadataCoreBoundary {
    mapping(bytes32 => address) public selected;
    mapping(uint256 => address) public owners;
    mapping(uint256 => uint8) public lifecycles;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd || id == 0x01ffc9a7;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1 || id == 2;
    }

    function setPointer(bytes32 kind, address target) external {
        selected[kind] = target;
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (address, bytes32, bool, bytes32, bytes4, address, uint8, bytes32, bytes32, uint64)
    {
        address target = selected[kind];
        return (
            target,
            target.codehash,
            false,
            kind,
            type(IStreamCollectionMetadataV1).interfaceId,
            address(this),
            1,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1
        );
    }

    function setToken(uint256 id, address owner, uint8 lifecycle) external {
        owners[id] = owner;
        lifecycles[id] = lifecycle;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        return (lifecycles[id] != 0, 1, id, lifecycles[id] == 3);
    }

    function tokenLifecycle(uint256 id) external view returns (uint8) {
        return lifecycles[id];
    }

    function ownerOf(uint256 id) external view returns (address) {
        require(lifecycles[id] == 2, "not live");
        return owners[id];
    }
}

contract MetadataExecutorBoundary {
    bool private active;
    bytes32 private scope;
    bytes32 private oldHash;
    bytes32 private newHash;
    address public root;
    bytes32 private rootCodeHash;
    uint64 private rootRevision = 1;
    address private proposer;
    GovernanceActionStatus private storedStatus = GovernanceActionStatus.EXECUTED;
    string private reasonURI;

    constructor() {
        root = msg.sender;
        rootCodeHash = msg.sender.codehash;
        proposer = msg.sender;
    }

    function setRoot(address account) external {
        root = account;
        rootCodeHash = account.codehash;
        ++rootRevision;
    }

    function setProposer(address account) external {
        proposer = account;
    }

    function setReasonURI(string memory value) external {
        reasonURI = value;
    }

    function setStoredStatus(GovernanceActionStatus value) external {
        storedStatus = value;
    }

    function governanceRootState() external view returns (address, bytes32, uint64) {
        return (root, rootCodeHash, rootRevision);
    }

    function governanceAction(bytes32) external view returns (GovernanceAction memory a) {
        a.status = storedStatus;
        a.actionClass = 1;
        // Deliberately represent another first batch target, not the metadata call.
        a.target = address(0xbeef);
        a.selector = 0x11223344;
        a.proposer = proposer;
        a.reasonURI = reasonURI;
    }

    function isStreamGovernedParameterAuthority() external pure returns (bool) {
        return true;
    }

    function currentAction()
        external
        view
        returns (bool, bytes32, uint8, bytes32, bytes32, bytes32)
    {
        return active
            ? (true, bytes32(uint256(1)), uint8(1), scope, oldHash, newHash)
            : (false, bytes32(0), uint8(0), bytes32(0), bytes32(0), bytes32(0));
    }

    function execute(address target, bytes memory data, bytes32 s, bytes32 o, bytes32 n)
        external
        returns (bytes memory result)
    {
        active = true;
        scope = s;
        oldHash = o;
        newHash = n;
        (bool ok, bytes memory output) = target.call(data);
        if (!ok) assembly { revert(add(output, 32), mload(output)) }
        active = false;
        scope = 0;
        oldHash = 0;
        newHash = 0;
        return output;
    }
}

contract MetadataArtistBoundary {
    address public core;
    address public currentSigner;
    mapping(bytes32 => bytes32) private permits;

    constructor(address c) {
        core = c;
    }

    function setSigner(address account) external {
        currentSigner = account;
    }

    function permit(bytes32 id, P.Publication memory p) external {
        permits[id] = keccak256(abi.encode(p));
    }

    function requireRecordPublication(bytes32 id, P.Publication calldata p)
        external
        view
        returns (P.Evidence memory)
    {
        require(
            p.recorder == currentSigner && permits[id] == keccak256(abi.encode(p)), "current permit"
        );
        (bytes32 hash, uint8 kind) =
            IStreamArtistRecordPublicationHost(p.metadataHost).requireArtistRecordCandidate(p);
        require(hash == p.candidateRecordHash, "actual host candidate");
        return P.Evidence(
            id,
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            1,
            currentSigner,
            1,
            kind == 7 ? 64 : 1,
            uint64(block.timestamp),
            permits[id]
        );
    }
}

contract MetadataModuleRegistryBoundary {
    mapping(address => StreamModuleRecord) private rows;

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamModuleRegistry).interfaceId;
    }

    function register(address target, bytes4 interfaceId) external {
        IStreamModule module = IStreamModule(target);
        (string memory uri, bytes32 hash) = module.streamModuleManifest();
        rows[target] = StreamModuleRecord(
            ModuleRegistryStatus.ACTIVE,
            module.streamModuleType(),
            module.streamModuleVersion(),
            interfaceId,
            100000,
            target.codehash,
            module.streamModuleDeploymentManifestHash(),
            hash,
            uri,
            1,
            1,
            1
        );
    }

    function moduleRecord(address target) external view returns (StreamModuleRecord memory) {
        return rows[target];
    }
}

contract StreamCollectionMetadataV1Test is CharacterizationTestBase, OfficialSafeFixture {
    StreamCollectionMetadataV1 private metadata;
    MetadataCoreBoundary private core;
    MetadataExecutorBoundary private executor;
    MetadataArtistBoundary private artist;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    bytes32 private schemaId;
    bytes32 private subject;
    bytes32 private constant CURATOR = keccak256("CURATOR_TEST_RECORD");
    bytes32 private constant RIGHTS = keccak256("RIGHTS_TEST_RECORD");
    bytes32 private constant ARTIST = keccak256("ARTIST_STATEMENT");
    event CollectionRecordRecorded(
        uint256 indexed collectionId,
        bytes32 indexed recordType,
        bytes32 indexed subjectId,
        IStreamPreservationRecords.CollectionRecord record,
        bytes32 recordHash,
        bytes32 recordChainHash,
        address recorder,
        bytes32 authorizationClass,
        uint16 schemaVersion
    );

    function setUp() public {
        vm.warp(1000);
        core = new MetadataCoreBoundary();
        executor = new MetadataExecutorBoundary();
        artist = new MetadataArtistBoundary(address(core));
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        schemaId = _register(
            "FIXTURE_RECORD_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes("{\"type\":\"object\"}")
        );
        _register(
            "STREAM_ARTIST_INTERVIEW_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes("{\"type\":\"object\"}")
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = bytes32(uint256(1));
        c.manifestHash = bytes32(uint256(2));
        c.manifestURI = "ipfs://metadata-module";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        subject = StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        _admit(CURATOR, StreamRecordFamilies.CURATOR, 8);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(this), true);
        _admit(RIGHTS, StreamRecordFamilies.RIGHTS, 128);
        _admit(ARTIST, StreamRecordFamilies.ARTIST, 2);
    }

    function testDirectBytesExactEventHistoryAndDistinctAuthors() public {
        bytes memory payload = bytes("{\"meaning\":\"original\"}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        bytes32 expected = _oldRecordHash(address(this), r);
        bytes32 chain = keccak256(
            abi.encode(
                bytes32(0x0e7a0feb85d4a4a3e90074703c19de35786e11afaae8f9868aa2a911bcfa1609),
                block.chainid,
                address(metadata),
                uint256(1),
                r.recordType,
                bytes32(0),
                expected,
                uint64(0)
            )
        );
        vm.expectEmit(true, true, true, true);
        emit CollectionRecordRecorded(
            1, r.recordType, r.subjectId, r, expected, chain, address(this), bytes32(uint256(3)), 1
        );
        require(
            metadata.recordCollectionRecordWithPayload(1, r, payload) == expected,
            "old exact record preimage"
        );
        (
            IStreamPreservationRecords.CollectionRecord memory saved,
            IStreamCollectionMetadataV1.RecordReceipt memory receipt
        ) = metadata.collectionRecord(expected);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(r)) && receipt.recordIndex == 0
                && receipt.recordChainHash == chain,
            "complete tuple and receipt"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.DuplicateMetadataRecord.selector, expected
            )
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(0xbeef), true);
        vm.prank(address(0xbeef));
        bytes32 other = metadata.recordCollectionRecordWithPayload(1, r, payload);
        require(
            other != expected
                && metadata.latestCollectionRecordHashFor(1, r.recordType, subject, address(this))
                    == expected,
            "recorder isolation"
        );
        (bytes32 head, uint64 count) = metadata.recordChainHash(1, r.recordType);
        require(
            count == 2 && head != chain && metadata.recordHashAt(1, r.recordType, 1) == other,
            "complete lane history"
        );
        (address pointer, bytes memory body) = metadata.recordPayload(expected);
        require(
            pointer.code.length == payload.length + 1 && keccak256(body) == keccak256(payload),
            "state-only bytes"
        );
        require(metadata.payloadPointerCount(1) == 1, "accepted pointer deduplication");
    }

    function testScopedWriterGrantRevokeAndWrongTransition() public {
        IStreamPreservationRecords.CollectionRecord memory r = _record(RIGHTS, bytes("{}"));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, bytes("{}"));
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, bytes("{}"));
        require(hash != 0, "scoped grant works");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.recordCollectionRecordWithPayload(2, r, bytes("{}"));
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), false);
        r.effectiveAt = 2;
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, bytes("{}"));
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.recordTypeTransition(keccak256("NEW"), StreamRecordFamilies.RIGHTS, 128);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType,
                (keccak256("NEW"), StreamRecordFamilies.RIGHTS, uint16(128))
            ),
            s,
            o,
            bytes32(uint256(n) ^ 1)
        );
        require(metadata.recordTypeCount() == 3, "failed admission rolled back");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        metadata.familyWriterTransition(0, StreamRecordFamilies.ARTIST, 1, address(this), true);
    }

    function testNonRootProposerCannotAdmitOrSelfGrant() public {
        executor.setProposer(address(0xbad));
        bytes32 kind = keccak256("UNAUTHORIZED_TYPE");
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.recordTypeTransition(kind, StreamRecordFamilies.RIGHTS, 128);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType, (kind, StreamRecordFamilies.RIGHTS, uint16(128))
            ),
            s,
            o,
            n
        );
        require(!metadata.recordPolicy(kind).admitted, "no unauthorized type");
        (s, o, n) = metadata.familyWriterTransition(
            1, StreamRecordFamilies.RIGHTS, 7, address(0xbad), true
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (uint256(1), StreamRecordFamilies.RIGHTS, uint8(7), address(0xbad), true)
            ),
            s,
            o,
            n
        );
        (bool enabled, uint64 revision) =
            metadata.familyWriter(1, StreamRecordFamilies.RIGHTS, 7, address(0xbad));
        require(!enabled && revision == 0, "no self grant");
    }

    function testRootAddressABACannotReviveQueuedTypeOrGrant() public {
        bytes32 kind = keccak256("QUEUED_TYPE");
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.recordTypeTransition(kind, StreamRecordFamilies.RIGHTS, 128);
        (bytes32 gs, bytes32 go, bytes32 gn) =
            metadata.familyWriterTransition(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        executor.setRoot(address(0x1234));
        (bytes32 changed,,) = metadata.recordTypeTransition(kind, StreamRecordFamilies.RIGHTS, 128);
        require(changed != s, "root rotation changes admission scope");
        executor.setRoot(address(this));
        (changed,,) = metadata.recordTypeTransition(kind, StreamRecordFamilies.RIGHTS, 128);
        require(changed != s, "returning root has a new revision");
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType, (kind, StreamRecordFamilies.RIGHTS, uint16(128))
            ),
            s,
            o,
            n
        );
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (uint256(1), StreamRecordFamilies.RIGHTS, uint8(7), address(this), true)
            ),
            gs,
            go,
            gn
        );
        _admit(kind, StreamRecordFamilies.RIGHTS, 128);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        require(metadata.recordPolicy(kind).admitted, "fresh root proposal succeeds");
    }

    function testStoredActionMustBeExecutedAndSupportsLongReasonBatchHeader() public {
        bytes32 kind = keccak256("LONG_REASON");
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.recordTypeTransition(kind, StreamRecordFamilies.RIGHTS, 128);
        executor.setStoredStatus(GovernanceActionStatus.SCHEDULED);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.MetadataAuthorityRequired.selector)
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.admitRecordType, (kind, StreamRecordFamilies.RIGHTS, uint16(128))
            ),
            s,
            o,
            n
        );
        executor.setStoredStatus(GovernanceActionStatus.EXECUTED);
        executor.setReasonURI(string(new bytes(1024)));
        _admit(kind, StreamRecordFamilies.RIGHTS, 128);
        require(
            metadata.recordPolicy(kind).admitted,
            "bounded header accepts dynamic reason and another first target"
        );
    }

    function testRealSafeRootCallsExecutorBoundaryForFamilyGrant() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 333;
        keys[1] = 444;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        executor.setRoot(address(account));
        executor.setProposer(address(account));
        (bytes32 s, bytes32 o, bytes32 n) = metadata.familyWriterTransition(
            1, StreamRecordFamilies.RIGHTS, 7, address(account), true
        );
        bytes memory data = abi.encodeCall(
            metadata.setFamilyWriter,
            (uint256(1), StreamRecordFamilies.RIGHTS, uint8(7), address(account), true)
        );
        executeSafe(
            account,
            keys,
            address(executor),
            0,
            abi.encodeCall(executor.execute, (address(metadata), data, s, o, n)),
            0
        );
        (bool enabled, uint64 revision) =
            metadata.familyWriter(1, StreamRecordFamilies.RIGHTS, 7, address(account));
        require(enabled && revision == 1, "real Safe root grant through explicit Executor boundary");
    }

    function testSchemaRetirementStopsNewWritesButPreservesHistoricalBytes() public {
        bytes memory payload = bytes("{}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(RIGHTS, payload);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, address(this), true);
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED)
            ),
            s,
            o,
            n
        );
        r.effectiveAt = 3;
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataSchemaUnavailable.selector, schemaId
            )
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(artist));
        (, bytes memory body) = metadata.recordPayload(hash);
        require(
            keccak256(body) == keccak256(payload),
            "historical read ignores selection and retirement"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(
            receipt.schemaDefinitionHash == schemas.document(schemaId).specification.contentHash,
            "immutable interpretation identity"
        );
    }

    function testDigestSchemaSignatureAndSubjectRejectionsLeaveNoRecords() public {
        bytes memory payload = bytes("{}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, bytes("altered"));
        r.signatureScheme = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        r.signatureScheme = 0;
        r.subjectId = bytes32(uint256(1));
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.UnknownMetadataSubject.selector, r.subjectId
            )
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        r.subjectId = subject;
        r.schemaId = keccak256("unregistered");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataSchemaUnavailable.selector, r.schemaId
            )
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
        require(metadata.payloadPointerCount(1) == 0, "no admitted payload pointers");
        (, uint64 count) = metadata.recordChainHash(1, CURATOR);
        require(count == 0, "no partial history");
    }

    function testTokenSubjectRequiresMintAndRetainsHistoryAfterBurn() public {
        core.setToken(1, address(this), 1);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.registerTokenSubject(1);
        core.setToken(1, address(this), 2);
        bytes32 tokenSubject = metadata.registerTokenSubject(1);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, bytes("{}"));
        r.subjectId = tokenSubject;
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, bytes("{}"));
        core.setToken(1, address(0), 3);
        require(
            metadata.registerTokenSubject(1) == tokenSubject, "burn preserves canonical subject"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(receipt.recorder == address(this), "historical attribution after burn");
    }

    function testDedicatedFamiliesCannotBeAdmittedIntoGenericMetadata() public {
        bytes32[3] memory families = [
            StreamRecordFamilies.OWNER,
            StreamRecordFamilies.INDEPENDENT,
            StreamRecordFamilies.SNAPSHOT
        ];
        uint16[3] memory masks = [uint16(4), uint16(32), uint16(128)];
        for (uint256 i; i < 3; ++i) {
            vm.expectRevert(
                abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
            );
            metadata.recordTypeTransition(keccak256("OTHER"), families[i], masks[i]);
        }
    }

    function testArtistDetachedPermitAndRelayerConsumeOnce() public {
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = bytes("{\"interview\":\"fixture\"}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(ARTIST, payload);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        store.publishChunk(payload);
        P.Publication memory p = _publication(recorder, r);
        (bytes32 candidate, uint8 kind) = metadata.requireArtistRecordCandidate(p);
        require(candidate == _oldRecordHash(recorder, r) && kind == 8, "actual candidate preimage");
        bytes32 permit = keccak256("permit");
        artist.permit(permit, p);
        bytes32 hash =
            metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, permit);
        require(
            hash == candidate && metadata.consumedArtistAuthorization(permit),
            "detached permit consumed"
        );
        (, IStreamCollectionMetadataV1.RecordReceipt memory receipt) =
            metadata.collectionRecord(hash);
        require(
            receipt.recorder == recorder && receipt.authorizationClass == 1
                && receipt.artistAuthorization == permit,
            "author, not relayer"
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.MetadataAuthorizationConsumed.selector, permit
            )
        );
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, permit);
        artist.setSigner(address(0xb0b));
        (, bytes memory body) = metadata.recordPayload(hash);
        require(
            keccak256(body) == keccak256(payload), "published history survives principal change"
        );
    }

    function testArtistBadAppendRollsBackAuthorizationAndNewPointer() public {
        address recorder = address(0xa11ce);
        artist.setSigner(recorder);
        bytes memory payload = bytes("{\"interview\":\"fixture\"}");
        IStreamPreservationRecords.CollectionRecord memory r = _record(ARTIST, payload);
        r.schemaId = keccak256("STREAM_ARTIST_INTERVIEW_V1");
        r.uri = "javascript:bad";
        bytes32 permit = keccak256("bad-uri-permit");
        artist.permit(permit, _publication(recorder, r));
        vm.expectRevert(abi.encodeWithSelector(StreamMetadataRenderer.UnsafeMetadataURI.selector));
        metadata.recordArtistCollectionRecordWithPayload(recorder, 1, r, payload, permit);
        require(
            !metadata.consumedArtistAuthorization(permit) && metadata.payloadPointerCount(1) == 0,
            "authorization and record index rollback"
        );
        (address pointer,) = store.chunk(keccak256(payload));
        require(pointer == address(0), "failed transaction's upload rollback");
    }

    function testPayloadLimitAndRealSafeDirectWritesAndReads() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 111;
        keys[1] = 222;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 1);
        _grant(1, StreamRecordFamilies.CURATOR, 3, address(account), true);
        bytes memory payload = new bytes(8192);
        payload[0] = 0x7b;
        payload[8191] = 0x7d;
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.recordCollectionRecordWithPayload, (uint256(1), r, payload)),
            0
        );
        bytes32 hash = metadata.deriveCollectionRecordHashFor(address(account), 1, r);
        require(
            metadata.latestCollectionRecordHashFor(1, CURATOR, subject, address(account)) == hash,
            "Safe is direct recorder"
        );
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.collectionRecord, (hash)),
            0
        );
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.collectionRecordPayload, (uint256(1), CURATOR, subject)),
            0
        );
        executeSafe(
            account,
            keys,
            address(metadata),
            0,
            abi.encodeCall(metadata.recordChainHash, (uint256(1), CURATOR)),
            0
        );
        payload = new bytes(8193);
        r = _record(CURATOR, payload);
        vm.expectRevert(
            abi.encodeWithSelector(IStreamCollectionMetadataV1.InvalidMetadataRecord.selector)
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
    }

    function testFuzzPayloadExactHashAndReplay(bytes32 value, uint64 effectiveAt) public {
        if (effectiveAt == 0) effectiveAt = 1;
        bytes memory payload = abi.encode(value);
        IStreamPreservationRecords.CollectionRecord memory r = _record(CURATOR, payload);
        r.effectiveAt = effectiveAt;
        bytes32 hash = metadata.recordCollectionRecordWithPayload(1, r, payload);
        require(hash == _oldRecordHash(address(this), r), "independent14-word preimage");
        (, bytes memory body) = metadata.recordPayload(hash);
        require(keccak256(body) == keccak256(payload), "exact payload");
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamCollectionMetadataV1.DuplicateMetadataRecord.selector, hash
            )
        );
        metadata.recordCollectionRecordWithPayload(1, r, payload);
    }

    function testActualCorePointerValidatorRequiresNewCurrentInterface() public {
        bytes32 pointerType = keccak256("COLLECTION_METADATA");
        (bool known, bytes32 moduleType, bytes4 interfaceId) =
            StreamCoreExternalReads.pointerConfiguration(pointerType, address(metadata), address(1));
        require(
            known && moduleType == pointerType
                && interfaceId == type(IStreamCollectionMetadataV1).interfaceId,
            "new canonical primary interface"
        );
        require(
            interfaceId != type(IStreamCollectionMetadata).interfaceId
                && !metadata.supportsInterface(type(IStreamCollectionMetadata).interfaceId),
            "legacy ABI is distinct"
        );
        MetadataModuleRegistryBoundary registry = new MetadataModuleRegistryBoundary();
        registry.register(address(metadata), interfaceId);
        (bool valid, StreamCorePointerState memory registryPointer) = StreamCoreExternalReads.genesisModuleRegistry(
            address(registry), address(registry).codehash, bytes32(uint256(2)), bytes32(uint256(1))
        );
        require(valid, "registry boundary");
        (StreamCoreValidationStatus status, StreamCorePointerState memory candidate) = StreamCoreExternalReads.eligiblePointer(
            registryPointer, address(metadata), moduleType, interfaceId
        );
        require(
            status == StreamCoreValidationStatus.VALID && candidate.target == address(metadata),
            "actual current metadata is eligible"
        );
        registry.register(address(metadata), type(IStreamCollectionMetadata).interfaceId);
        (status,) = StreamCoreExternalReads.eligiblePointer(
            registryPointer, address(metadata), moduleType, interfaceId
        );
        require(status != StreamCoreValidationStatus.VALID, "legacy catalog identity rejected");
        require(!metadata.supportsInterface(0xffffffff), "invalid ERC165 marker rejected");
    }

    function _record(bytes32 kind, bytes memory payload)
        private
        view
        returns (IStreamPreservationRecords.CollectionRecord memory r)
    {
        r.recordType = kind;
        r.subjectId = subject;
        r.schemaId = schemaId;
        r.contentHash = IStreamPreservationRecords.HashRef(
            1, abi.encode(keccak256(payload)), schemas.RAW_BYTES()
        );
        r.uri = "ipfs://record";
        r.effectiveAt = 1;
    }

    function _publication(address recorder, IStreamPreservationRecords.CollectionRecord memory r)
        private
        view
        returns (P.Publication memory p)
    {
        p = P.Publication(
            address(metadata),
            recorder,
            1,
            r.subjectId,
            r.recordType,
            r.schemaId,
            r.contentHash.canonicalizationId,
            1,
            bytes32(r.contentHash.digest),
            keccak256(bytes(r.uri)),
            r.effectiveAt,
            _oldRecordHash(recorder, r)
        );
    }

    function _oldRecordHash(address recorder, IStreamPreservationRecords.CollectionRecord memory r)
        private
        view
        returns (bytes32)
    {
        bytes32[14] memory words;
        words[0] = keccak256("6529stream.preservation-record.v2");
        words[1] = bytes32(block.chainid);
        words[2] = bytes32(uint256(uint160(address(metadata))));
        words[3] = bytes32(uint256(uint160(address(core))));
        words[4] = bytes32(uint256(uint160(recorder)));
        words[5] = bytes32(uint256(1));
        words[6] = r.recordType;
        words[7] = r.subjectId;
        words[8] = keccak256(
            abi.encode(
                r.contentHash.algorithm,
                keccak256(r.contentHash.digest),
                r.contentHash.canonicalizationId
            )
        );
        words[9] = keccak256(bytes(r.uri));
        words[10] = r.schemaId;
        words[11] = r.signatureScheme;
        words[12] = keccak256(
            abi.encode(
                r.signatureHash.algorithm,
                keccak256(r.signatureHash.digest),
                r.signatureHash.canonicalizationId
            )
        );
        words[13] = bytes32(uint256(r.effectiveAt));
        return keccak256(abi.encode(words));
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory payload
    ) private returns (bytes32) {
        (bytes32 hash,) = store.publishChunk(payload);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(payload.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
            ),
            (bytes32)
        );
    }

    function _admit(bytes32 kind, bytes32 family, uint16 mask) private {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.recordTypeTransition(kind, family, mask);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.admitRecordType, (kind, family, mask)),
            s,
            o,
            n
        );
    }

    function _grant(
        uint256 collectionId,
        bytes32 family,
        uint8 authClass,
        address account,
        bool enabled
    ) private {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.familyWriterTransition(
            collectionId, family, authClass, account, enabled
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter, (collectionId, family, authClass, account, enabled)
            ),
            s,
            o,
            n
        );
    }
}
