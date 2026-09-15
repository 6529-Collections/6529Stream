// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import {
    StreamCollectionViews
} from "../../../smart-contracts/domains/metadata/StreamCollectionViews.sol";
import {
    IStreamCollectionViews as V
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamCollectionViews.sol";

interface ViewFailureVm {
    function mockCallRevert(address target, bytes calldata input, bytes calldata reason) external;
    function clearMockedCalls() external;
}

contract ViewsCoreBoundary is MetadataCoreBoundary {
    mapping(uint256 => bool) private frozen;

    function freeze(uint256 id) external {
        frozen[id] = true;
    }

    function collectionFreezeStatus(uint256 id) external view returns (bool) {
        return frozen[id];
    }
}

contract ViewsRegistryBoundary {
    address public admitted;
    address public metadata;
    bool public metadataEnabled = true;

    function bindMetadata(address target, bool enabled_) external {
        metadata = target;
        metadataEnabled = enabled_;
    }
    bool public enabled = true;

    function set(address target, bool value) external {
        admitted = target;
        enabled = value;
    }

    function isModuleEligible(address target, bytes32 kind, bytes4 interfaceId)
        external
        view
        returns (bool)
    {
        if (target == metadata) {
            return metadataEnabled && kind == keccak256("COLLECTION_METADATA")
                && interfaceId == type(IStreamCollectionMetadataV1).interfaceId;
        }
        return enabled && target == admitted && kind == keccak256("COLLECTION_VIEWS")
            && interfaceId == type(V).interfaceId;
    }
}

/// @notice Actual MetadataV1/Schema/store/Safe; Core/Executor/module selection are explicit typed boundaries.
/// @dev No renderer or Artist content-adoption permission is supplied by this fixture.
contract StreamCollectionViewsTest is CharacterizationTestBase, OfficialSafeFixture {
    ViewsCoreBoundary private core;
    MetadataExecutorBoundary private executor;
    MetadataArtistBoundary private artist;
    StreamSchemaRegistry private schemas;
    StreamSchemaDocumentStore private store;
    StreamCollectionMetadataV1 private metadata;
    ViewsRegistryBoundary private registry;
    StreamCollectionViews private views;
    bytes32 private schemaId;
    bytes32 private constant GALLERY = keccak256("GALLERY");
    bytes32 private constant ARCHIVE = keccak256("ARCHIVE");
    bytes32 private constant DISPLAY = keccak256("6529STREAM_RECORD_FAMILY_IDENTITY_DISPLAY_V1");

    function setUp() public {
        vm.warp(1000);
        core = new ViewsCoreBoundary();
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
            "VIEW_DOCUMENT_FIXTURE_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            bytes("{\"type\":\"object\"}")
        );
        StreamCollectionMetadataV1.Configuration memory m;
        m.core = address(core);
        m.executor = address(executor);
        m.schemas = address(schemas);
        m.artistRegistry = address(artist);
        m.deploymentManifestHash = keccak256("fixture deployment");
        m.manifestHash = keccak256("metadata manifest");
        m.manifestURI = "ipfs://metadata";
        m.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        m.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(m);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        StreamCollectionViews.Configuration memory c;
        c.core = address(core);
        c.metadata = address(metadata);
        c.executor = address(executor);
        c.deploymentManifestHash = m.deploymentManifestHash;
        c.manifestHash = keccak256("views manifest");
        c.manifestURI = "ipfs://views";
        c.dependencyReadGas = m.dependencyReadGas;
        views = new StreamCollectionViews(c);
        registry = new ViewsRegistryBoundary();
        registry.set(address(views), true);
        registry.bindMetadata(address(metadata), true);
        core.setPointer(keccak256("MODULE_REGISTRY"), address(registry));
        (, bytes32 hash, bytes memory definition) = views.viewSchema();
        require(hash == keccak256(definition), "exact advertised ABI schema bytes");
        _register(
            "STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            definition
        );
        _grant(1, DISPLAY, 7, address(this), true);
    }

    function testOriginalRecordHashFullEventAndByteCarriers() public {
        bytes memory payload = bytes("{\"label\":\"gallery fixture\"}");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        vm.recordLogs();
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        (
            V.CollectionViewManifest memory saved,
            V.ViewReceipt memory receipt,
            IStreamPreservationRecords.CollectionRecord memory record
        ) = views.viewRecord(hash);
        require(
            keccak256(abi.encode(saved)) == keccak256(abi.encode(m)), "complete original six fields"
        );
        bytes memory carrier = abi.encode(uint256(1), uint64(1), bytes32(0), m);
        bytes32 subject = keccak256(
            abi.encode(
                keccak256("6529STREAM_SUBJECT_SCOPE_V1"),
                block.chainid,
                address(core),
                uint256(1),
                uint8(4),
                GALLERY
            )
        );
        bytes32 expected = keccak256(
            abi.encode(
                keccak256("6529stream.preservation-record.v2"),
                block.chainid,
                address(views),
                address(core),
                address(this),
                uint256(1),
                keccak256("DISPLAY_VIEW_MANIFEST"),
                subject,
                keccak256(
                    abi.encode(
                        uint16(1), keccak256(abi.encode(keccak256(carrier))), keccak256("RAW_BYTES")
                    )
                ),
                keccak256(bytes(m.uri)),
                keccak256("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"),
                bytes32(0),
                keccak256(abi.encode(uint16(0), keccak256(bytes("")), bytes32(0))),
                uint64(0)
            )
        );
        require(hash == expected, "independent original fourteen-word preimage");
        bytes32 chain = keccak256(
            abi.encode(
                keccak256("6529STREAM_RECORD_CHAIN_V1"),
                block.chainid,
                address(views),
                uint256(1),
                keccak256("DISPLAY_VIEW_MANIFEST"),
                bytes32(0),
                hash,
                uint64(0)
            )
        );
        require(
            receipt.recordChainHash == chain && receipt.recordIndex == 0,
            "original record-chain recipe"
        );
        require(
            receipt.authorizationClass == 7 && receipt.recorder == address(this)
                && receipt.grantCollectionId == 1 && receipt.grantRevision == 1,
            "original actual DISPLAY grant provenance"
        );
        (, bytes memory got) = views.viewPayload(hash);
        require(keccak256(got) == keccak256(payload), "exact reference bytes");
        (, got) = views.manifestPayload(hash);
        require(keccak256(got) == keccak256(carrier), "exact canonical ABI carrier");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 found;
        bytes32 topic = keccak256(
            "CollectionRecordRecorded(uint256,bytes32,bytes32,(bytes32,bytes32,(uint16,bytes,bytes32),string,bytes32,bytes32,(uint16,bytes,bytes32),uint64),bytes32,bytes32,address,bytes32,uint16)"
        );
        for (uint256 i; i < logs.length; ++i) {
            if (logs[i].emitter == address(views) && logs[i].topics[0] == topic) {
                require(
                    logs[i].topics.length == 4 && logs[i].topics[1] == bytes32(uint256(1))
                        && logs[i].topics[2] == record.recordType && logs[i].topics[3] == subject,
                    "original event indices"
                );
                require(
                    keccak256(logs[i].data)
                        == keccak256(
                            abi.encode(
                                record, hash, chain, address(this), bytes32(uint256(7)), uint16(1)
                            )
                        ),
                    "full original event body"
                );
                ++found;
            }
        }
        require(
            found == 1 && views.payloadPointerCount(1) == 2,
            "one authoritative record and both carriers"
        );
        (bytes32 metadataChain, uint64 count) =
            metadata.recordChainHash(1, keccak256("DISPLAY_VIEW_MANIFEST"));
        require(metadataChain == 0 && count == 0, "no mutation of Metadata/renderer truth");
    }

    function testRevisionCASHistoryAndSameBlockReturnToOriginalContent() public {
        bytes memory a = bytes("a");
        bytes memory b = bytes("b");
        V.CollectionViewManifest memory m = _manifest(GALLERY, a);
        bytes32 first = views.setCollectionViewManifestWithPayload(1, GALLERY, m, a, 0);
        m.contentHash = keccak256(b);
        m.defaultForView = false;
        bytes32 second = views.setCollectionViewManifestWithPayload(1, GALLERY, m, b, first);
        vm.expectRevert(abi.encodeWithSelector(V.ViewRevisionMismatch.selector, first, second));
        views.setCollectionViewManifestWithPayload(1, GALLERY, _manifest(GALLERY, a), a, first);
        bytes32 third = views.setCollectionViewManifestWithPayload(
            1, GALLERY, _manifest(GALLERY, a), a, second
        );
        (, V.ViewReceipt memory receipt,) = views.viewRecord(third);
        require(
            third != first && receipt.revision == 3 && receipt.previousRecordHash == second,
            "A-B-A never aliases old receipt"
        );
        require(
            views.viewIdCount(1) == 1 && views.viewIdAt(1, 0) == GALLERY
                && views.recordHashAt(1, 0) == first && views.recordHashAt(1, 2) == third,
            "full immutable selection history"
        );
        (, bytes memory original) = views.viewPayload(first);
        require(keccak256(original) == keccak256(a), "history retained");
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewManifest.selector));
        views.setCollectionViewManifestWithPayload(1, GALLERY, _manifest(GALLERY, a), a, third);
    }

    function testOriginalScopedAndGlobalGrantsDoNotImpersonateArtistOrOtherFamilies() public {
        bytes memory payload = bytes("{}");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        address outsider = vm.addr(117);
        _grant(1, StreamRecordFamilies.RIGHTS, 7, outsider, true);
        vm.expectRevert(abi.encodeWithSelector(V.ViewAuthorityRequired.selector));
        vm.prank(outsider);
        views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        _grant(2, DISPLAY, 7, outsider, true);
        vm.expectRevert(abi.encodeWithSelector(V.ViewAuthorityRequired.selector));
        vm.prank(outsider);
        views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        _grant(0, DISPLAY, 8, outsider, true);
        vm.prank(outsider);
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        (, V.ViewReceipt memory receipt,) = views.viewRecord(hash);
        require(
            receipt.authorizationClass == 8 && receipt.grantCollectionId == 0,
            "global authority retained as global"
        );
        _grant(0, DISPLAY, 8, outsider, false);
        m.viewId = ARCHIVE;
        vm.expectRevert(abi.encodeWithSelector(V.ViewAuthorityRequired.selector));
        vm.prank(outsider);
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        (, receipt,) = views.viewRecord(hash);
        require(
            receipt.recorder == outsider && receipt.authorizationClass == 8,
            "revocation never rewrites original authority"
        );
    }

    function testHostRetirementAndMetadataPointerDriftStopOnlyNewWrites() public {
        bytes memory payload = bytes("{}");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        m.viewId = ARCHIVE;
        registry.set(address(views), false);
        vm.expectRevert(abi.encodeWithSelector(V.ViewHostNotSelected.selector));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        (, bytes memory old) = views.viewPayload(hash);
        require(keccak256(old) == keccak256(payload), "retired host retains bytes");
        registry.set(address(views), true);
        registry.bindMetadata(address(metadata), false);
        vm.expectRevert(abi.encodeWithSelector(V.ViewHostNotSelected.selector));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        registry.bindMetadata(address(metadata), true);
        core.setPointer(keccak256("COLLECTION_METADATA"), address(artist));
        vm.expectRevert(abi.encodeWithSelector(V.ViewHostNotSelected.selector));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        require(
            views.collectionViewManifest(1, GALLERY).contentHash == keccak256(payload),
            "historical read is never relabeled current renderer selection"
        );
    }

    function testSchemaRetirementMissingSchemaAndExactCarrierDefinition() public {
        bytes memory payload = bytes("{}");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        _status(schemaId, IStreamSchemaRegistry.DocumentStatus.ARCHIVED);
        m.viewId = ARCHIVE;
        vm.expectRevert(abi.encodeWithSelector(V.ViewSchemaUnavailable.selector, schemaId));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        (,, IStreamPreservationRecords.CollectionRecord memory record) = views.viewRecord(hash);
        require(
            record.schemaId == keccak256("STREAM_COLLECTION_VIEW_MANIFEST_ABI_V1"),
            "carrier schema distinct from referenced document schema"
        );
        (, bytes memory original) = views.manifestPayload(hash);
        require(original.length > 0, "retirement retains interpretation and carrier history");
        m.schemaId = keccak256("missing");
        vm.expectRevert(abi.encodeWithSelector(V.ViewSchemaUnavailable.selector, m.schemaId));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
    }

    function testAll65536ArchiveBytesPagedReadsAndPointerDeduplication() public {
        bytes memory payload = new bytes(65536);
        for (uint256 i; i < payload.length; ++i) {
            payload[i] = bytes1(uint8(i));
        }
        V.CollectionViewManifest memory m = _manifest(ARCHIVE, payload);
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        (, bytes memory got) = views.viewPayload(hash);
        require(
            got.length == 65536 && keccak256(got) == keccak256(payload), "full archive-view maximum"
        );
        require(
            views.viewChunkCount(hash) == 8 && views.payloadPointerCount(1) == 2,
            "logical repetition retained, physical document chunk deduplicated plus manifest"
        );
        for (uint256 i; i < 8; ++i) {
            (bytes32 part, bytes memory raw) = views.viewChunk(hash, i);
            require(raw.length == 8192 && part == keccak256(raw), "exact page hash and length");
        }
        vm.expectRevert(abi.encodeWithSelector(V.ViewIndexOutOfBounds.selector));
        views.viewChunk(hash, 8);
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewManifest.selector));
        views.setCollectionViewManifestWithPayload(
            1, GALLERY, _manifest(GALLERY, new bytes(65537)), new bytes(65537), 0
        );
    }

    function testUploadsAreNotAuthorityAndThreeArgumentSetterUsesRealSavedBytes() public {
        bytes memory payload = bytes("published before admission");
        (, address pointer) = store.publishChunk(payload);
        require(
            pointer != address(0) && views.viewIdCount(1) == 0 && views.payloadPointerCount(1) == 0,
            "upload alone adds no view"
        );
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        bytes32 hash = views.setCollectionViewManifest(1, GALLERY, m);
        (, bytes memory got) = views.viewPayload(hash);
        require(keccak256(got) == m.contentHash, "selected exact existing bytes");
        m = _manifest(ARCHIVE, bytes("not uploaded"));
        vm.expectRevert();
        views.setCollectionViewManifest(1, ARCHIVE, m);
        require(views.viewIdCount(1) == 1, "missing payload never creates hash-only manifest");
    }

    function testSafeLateCarrierFailureRollsBackAllRowsAndIdenticalTransactionRetries() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 111;
        keys[1] = 222;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 91);
        _grant(1, DISPLAY, 7, address(account), true);
        bytes memory payload = bytes("new Safe view bytes");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        bytes memory data = abi.encodeCall(
            views.setCollectionViewManifestWithPayload,
            (uint256(1), GALLERY, m, payload, bytes32(0))
        );
        bytes memory carrier = abi.encode(uint256(1), uint64(1), bytes32(0), m);
        bytes32 txHash = account.getTransactionHash(
            address(views), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
        );
        ViewFailureVm(address(vm))
            .mockCallRevert(
                address(store),
                abi.encodeCall(store.publishChunk, (carrier)),
                abi.encodeWithSignature("Error(string)", "late carrier")
            );
        uint256 nonce = account.nonce();
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        this.safeWrite(account, keys, data);
        require(
            account.nonce() == nonce && views.viewIdCount(1) == 0
                && views.payloadPointerCount(1) == 0,
            "Safe and full host state rolled back"
        );
        (address created,) = store.chunk(keccak256(payload));
        require(
            created == address(0),
            "first actual SSTORE2 publication rolled back after late second failure"
        );
        ViewFailureVm(address(vm)).clearMockedCalls();
        require(
            txHash
                == account.getTransactionHash(
                    address(views), 0, data, 0, 0, 0, 0, address(0), address(0), account.nonce()
                ),
            "byte-identical Safe authorization"
        );
        this.safeWrite(account, keys, data);
        (bytes32 hash,) = views.selectedViewRecord(1, GALLERY);
        (, V.ViewReceipt memory receipt,) = views.viewRecord(hash);
        require(
            receipt.recorder == address(account) && account.nonce() == nonce + 1,
            "actual threshold Safe is original recorder"
        );
    }

    function testLocksCoreFreezeAndInvalidManifestNeverChangeSelectedView() public {
        bytes memory payload = bytes("{}");
        V.CollectionViewManifest memory m = _manifest(GALLERY, payload);
        bytes32 hash = views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, 0);
        vm.expectRevert(abi.encodeWithSelector(V.ViewAuthorityRequired.selector));
        views.lockCollectionView(1, GALLERY);
        _grant(1, DISPLAY, 8, address(this), true);
        views.lockCollectionView(1, GALLERY);
        m.defaultForView = false;
        vm.expectRevert(abi.encodeWithSelector(V.ViewLocked.selector, uint256(1), GALLERY));
        views.setCollectionViewManifestWithPayload(1, GALLERY, m, payload, hash);
        m.viewId = ARCHIVE;
        core.freeze(1);
        vm.expectRevert(abi.encodeWithSelector(V.ViewLocked.selector, uint256(1), bytes32(0)));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        (bytes32 saved, bool locked) = views.selectedViewRecord(1, GALLERY);
        require(saved == hash && locked, "permanent selected record and lock");
        m = _manifest(ARCHIVE, payload);
        m.viewId = GALLERY;
        vm.expectRevert(abi.encodeWithSelector(V.InvalidViewManifest.selector));
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
        m = _manifest(ARCHIVE, payload);
        m.uri = "javascript:alert(1)";
        vm.expectRevert();
        views.setCollectionViewManifestWithPayload(1, ARCHIVE, m, payload, 0);
    }

    function safeWrite(OfficialSafe account, uint256[] memory keys, bytes memory data) external {
        require(executeSafe(account, keys, address(views), 0, data, 0), "Safe CALL succeeded");
    }

    function _manifest(bytes32 id, bytes memory payload)
        private
        view
        returns (V.CollectionViewManifest memory)
    {
        return V.CollectionViewManifest(
            id, schemaId, "ipfs://view-document", keccak256(payload), "application/json", true
        );
    }

    function _grant(uint256 collection, bytes32 family, uint8 kind, address account, bool enabled)
        private
    {
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(collection, family, kind, account, enabled);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.setFamilyWriter, (collection, family, kind, account, enabled)),
            s,
            o,
            n
        );
    }

    function _status(bytes32 id, IStreamSchemaRegistry.DocumentStatus next) private {
        (bytes32 s, bytes32 o, bytes32 n) = schemas.statusTransition(id, next);
        executor.execute(
            address(schemas), abi.encodeCall(schemas.setDocumentStatus, (id, next)), s, o, n
        );
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
}
