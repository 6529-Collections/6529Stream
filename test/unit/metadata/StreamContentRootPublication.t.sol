// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCollectionMetadataV1.t.sol";
import "../../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";

contract RootCoreBoundary {
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
        returns (StreamCorePointerState memory p)
    {
        p.target = selected[kind];
        p.codeHash = p.target.codehash;
        p.moduleType = kind;
        p.interfaceId = kind == keccak256("METADATA_ROUTER")
            ? type(IStreamMetadataRouter).interfaceId
            : type(IStreamCollectionMetadataV1).interfaceId;
        p.registry = address(this);
        p.registryStatus = 1;
        p.moduleManifestHash = bytes32(uint256(1));
        p.deploymentManifestHash = bytes32(uint256(2));
        p.revision = 1;
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

    address public entropy;

    function setEntropy(address e) external {
        entropy = e;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256) external pure returns (bytes memory) {
        return hex"00ff";
    }
    uint256 public minted;
    bool public frozen;

    function setMinted(uint256 n) external {
        minted = n;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function collectionFreezeStatus(uint256) external view returns (bool) {
        return frozen;
    }
}

/// @dev Artist signatures/lifecycle are a boundary here; this double checks the entire exact consent tuple.
contract RootArtistBoundary {
    address public immutable core;
    address public finalityRegistry;
    bytes32 public finalityRegistryCodeHash;
    address public router;
    uint64 public generation = 1;
    bytes32 public artistId = keccak256("artist");
    bytes32 public bindingHash = keccak256("binding");
    bytes32 public consentState;
    bytes32 public consentHash;
    bytes32 public ratifiedState;
    bytes32 public ratification;
    bytes32 public freezeState;
    bytes32[] private _locks;

    constructor(address c) {
        core = c;
    }

    function configure(address r, address f) external {
        router = r;
        finalityRegistry = f;
        finalityRegistryCodeHash = f.codehash;
    }

    function changeGeneration() external {
        ++generation;
    }

    function approve(bytes32 state, bytes32 hash) external {
        consentState = state;
        consentHash = hash;
    }

    function ratify(bytes32 state, bytes32 hash) external {
        ratifiedState = state;
        ratification = hash;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == type(IStreamArtistAttribution).interfaceId
            || id == type(IStreamArtistContentRatification).interfaceId
            || id == type(IStreamArtistAttributionState).interfaceId || id == 0x01ffc9a7;
    }

    function collectionArtistState(uint256)
        external
        view
        returns (uint8, uint64, bytes32, uint8, bytes32)
    {
        return (2, generation, artistId, 1, bindingHash);
    }

    function attribution(uint256)
        external
        view
        returns (IStreamCollectionArtistRegistry.Attribution memory a)
    {
        return IStreamCollectionArtistRegistry.Attribution(
            address(0xA11CE),
            address(0xA11CE),
            keccak256("identity"),
            bindingHash,
            keccak256("acceptance"),
            generation,
            0
        );
    }

    function firstReleaseRatification(uint256) external view returns (bool, bytes32, bytes32) {
        return (ratification != 0, ratifiedState, ratification);
    }

    function contentConsentEvidence(uint256 cid, bytes32 family, bytes32 state)
        external
        view
        returns (bytes32)
    {
        require(
            msg.sender == router && cid == 1 && family == keccak256("CONTENT_ROOT")
                && state == consentState && consentHash != 0,
            "exact artist consent"
        );
        return consentHash;
    }

    function setFreeze(bytes32 state, bytes32[] memory locks) external {
        freezeState = state;
        _locks = locks;
    }

    function contentFreezeAuthorization(bytes32 hash)
        external
        view
        returns (C.FreezeRecord memory r)
    {
        r.recordHash = hash;
        r.artistId = artistId;
        r.metadataContract = router;
        r.authorityClass = 1;
        r.lockClasses = _locks;
        r.expectedStateHash = freezeState;
    }

    function isContentFreezeAuthorized(uint256 cid, bytes32) external pure returns (bool, bytes32) {
        return (cid == 1, keccak256("freeze"));
    }
}

contract RootCheckpointBoundary {
    address public immutable core;
    address public immutable metadataRouter;

    constructor(address c, address r) {
        core = c;
        metadataRouter = r;
    }
}

contract RootArtifactsBoundary {
    address public immutable schemaRegistry;

    constructor(address s) {
        schemaRegistry = s;
    }
}

contract RootManifestBoundary {
    address public immutable core;
    address public immutable contentCheckpoint;
    address public immutable artifactCoverage;
    bool public current = true;

    constructor(address c, address p, address a) {
        core = c;
        contentCheckpoint = p;
        artifactCoverage = a;
    }

    function setCurrent(bool value) external {
        current = value;
    }

    function requireCurrentManifest(bytes32 hash, bytes32 artistId)
        external
        view
        returns (IStreamContentLeafManifest.Manifest memory m)
    {
        require(
            current && hash == keccak256("verified") && artistId == keccak256("artist"),
            "current manifest"
        );
        m = IStreamContentLeafManifest.Manifest(
            keccak256("checkpoint"),
            keccak256("artifact"),
            keccak256("coverage"),
            artistId,
            keccak256("root"),
            keccak256("manifest"),
            1,
            1,
            512
        );
    }
}

contract RootProviderBoundary {
    address public immutable metadataHost;
    bytes32 public immutable metadataHostCodeHash;
    address public immutable schemaRegistry;
    bytes32 public immutable schemaRegistryCodeHash;
    address public immutable contentLeafManifest;
    bytes32 public immutable contentLeafManifestCodeHash;

    constructor(address m, address s, address l) {
        metadataHost = m;
        metadataHostCodeHash = m.codehash;
        schemaRegistry = s;
        schemaRegistryCodeHash = s.codehash;
        contentLeafManifest = l;
        contentLeafManifestCodeHash = l.codehash;
    }
}

contract RootFinalityBoundary {
    address public immutable coreReads;
    address public immutable sanctionReads;
    address public immutable metadataReads;
    address public immutable scopeEvidenceProvider;
    bytes32 public immutable scopeEvidenceProviderCodeHash;
    address public immutable artifactCoverage;
    uint256 public readGas = 5_000_000;

    constructor(address c, address a, address m, address p, address f) {
        coreReads = c;
        sanctionReads = a;
        metadataReads = m;
        scopeEvidenceProvider = p;
        scopeEvidenceProviderCodeHash = p.codehash;
        artifactCoverage = f;
    }

    function gasParameter(bytes32) external view returns (uint256) {
        return readGas;
    }

    function core() external view returns (address) {
        return coreReads;
    }

    function setReadGas(uint256 cap) external {
        readGas = cap;
    }
}

/// @notice Actual Router, schema registry/store, governed writer grants and threshold Safe publication.
/// @dev Core, Executor execution, artist, verified-manifest and finality evidence are explicit boundaries.
abstract contract ContentRootPublicationFixture is CharacterizationTestBase, OfficialSafeFixture {
    RootCoreBoundary internal core;
    RootArtistBoundary internal artist;
    MetadataExecutorBoundary internal executor;
    StreamSchemaRegistry internal schemas;
    StreamSchemaDocumentStore internal store;
    StreamCollectionMetadataV1 internal metadata;
    StreamMetadataRouter internal router;
    RootManifestBoundary internal manifest;
    RootFinalityBoundary internal finality;
    address internal provider;
    bytes32 internal constant FAMILY = keccak256("CONTENT_ROOT");
    event TokenContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        IStreamContentRootPublication.Record record
    );

    function setUp() public virtual {
        vm.warp(1000);
        core = new RootCoreBoundary();
        artist = new RootArtistBoundary(address(core));
        executor = new MetadataExecutorBoundary();
        schemas = new StreamSchemaRegistry(address(executor));
        store = StreamSchemaDocumentStore(schemas.chunkStore());
        _register(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION()),
            schemas.RAW_BYTES()
        );
        StreamCollectionMetadataV1.Configuration memory c;
        c.core = address(core);
        c.executor = address(executor);
        c.schemas = address(schemas);
        c.artistRegistry = address(artist);
        c.deploymentManifestHash = keccak256("deployment");
        c.manifestHash = keccak256("manifest");
        c.manifestURI = "ipfs://metadata";
        c.dependencyReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_DEPENDENCY_READ_GAS", 150000, 100000, 2
        );
        c.artistReadGas = IStreamGasParameterHost.GasParameterConfig(
            "METADATA_ARTIST_READ_GAS", 2000000, 1000000, 2
        );
        metadata = new StreamCollectionMetadataV1(c);
        router = new StreamMetadataRouter(
            address(core),
            address(this),
            keccak256("deployment"),
            "ipfs://router",
            keccak256("manifest"),
            IStreamArtistAttribution(address(artist))
        );
        core.setPointer(keccak256("ARTIST_REGISTRY"), address(artist));
        core.setPointer(keccak256("METADATA_ROUTER"), address(router));
        core.setPointer(keccak256("COLLECTION_METADATA"), address(metadata));
        router.setCollectionMetadata(1, "Artwork", "Description", "", "");
        router.setCollectionScript(1, "draw();");
        core.setMinted(1);
        address cp = address(new RootCheckpointBoundary(address(core), address(router)));
        address artifacts = address(new RootArtifactsBoundary(address(schemas)));
        manifest = new RootManifestBoundary(address(core), cp, artifacts);
        provider =
            address(
            new RootProviderBoundary(address(metadata), address(schemas), address(manifest))
        );
        finality = new RootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, artifacts
        );
        artist.configure(address(router), address(finality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        _grant(1, 7, address(this), true);
    }

    function _publication()
        internal
        pure
        returns (IStreamContentRootPublication.Publication memory)
    {
        return IStreamContentRootPublication.Publication(
                1, 0, keccak256("verified"), "ipfs://manifest:one"
            );
    }

    function _approve(
        IStreamContentRootPublication.Publication memory p,
        address publisher,
        bytes32 hash
    ) internal returns (bytes32 state) {
        state = router.previewContentRootPublication(p, publisher);
        artist.approve(state, hash);
    }

    function _documents(bytes32 rootCanon) internal {
        _definition("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1", false, schemas.RAW_BYTES());
        _definition("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1", true, schemas.RAW_BYTES());
        _definition("STREAM_TOKEN_CONTENT_ROOT_RECORD_V1", false, rootCanon);
        _definition("STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1", true, schemas.RAW_BYTES());
    }

    function _definition(string memory name, bool canon, bytes32 registrationCanon) internal {
        _register(
            name,
            canon
                ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                : IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamContentRootSchemas.document(keccak256(bytes(name))),
            registrationCanon
        );
    }

    function _register(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw,
        bytes32 canon
    ) internal returns (bytes32) {
        (bytes32 hash,) = store.publishChunk(raw);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec =
            IStreamSchemaRegistry.DocumentSpec(name, kind, hash, canon, 0, "", uint32(raw.length));
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        return abi.decode(
            executor.execute(
                address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
            ),
            (bytes32)
        );
    }

    function _grant(uint256 cid, uint8 authClass, address account, bool enabled) internal {
        (bytes32 s, bytes32 o, bytes32 n) = metadata.familyWriterTransition(
            cid, StreamRecordFamilies.SNAPSHOT, authClass, account, enabled
        );
        executor.execute(
            address(metadata),
            abi.encodeCall(
                metadata.setFamilyWriter,
                (cid, StreamRecordFamilies.SNAPSHOT, authClass, account, enabled)
            ),
            s,
            o,
            n
        );
    }

    function _subject() internal view returns (bytes32) {
        return StreamMetadataSubjects.scopeSubject(
            block.chainid,
            address(core),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
    }
}

contract StreamContentRootPublicationTest is ContentRootPublicationFixture {
    function testExactPublicationStateHistoryEventsAndNoServingFeedback() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 beforeServing = keccak256(
            abi.encode(router.collectionServingFacts(1), router.collectionServingSource(1))
        );
        bytes32 state = _approve(p, address(this), keccak256("consent"));
        vm.recordLogs();
        bytes32 hash = router.publishVerifiedTokenContentRoot(p);
        IStreamContentRootPublication.Record memory r = router.contentRootRecord(hash);
        require(
            r.stateHash == state && r.publisher == address(this) && r.authorizationClass == 7
                && r.grantRevision == 1,
            "authority"
        );
        require(
            r.publishedAt == 1000 && r.artistConsent == keccak256("consent")
                && r.artistId == keccak256("artist"),
            "record"
        );
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_RECORD_V1"),
                        block.chainid,
                        address(router),
                        r
                    )
                ),
            "record preimage"
        );
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        require(
            state
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_STATE_V1"),
                        block.chainid,
                        address(router),
                        r
                    )
                ),
            "state preimage"
        );
        require(
            router.collectionContentRootHead(1) == hash
                && router.consumedArtistContentConsent(keccak256("consent")),
            "consumed"
        );
        (bytes32 root, uint64 count, bytes32 schema) = router.tokenContentRoot(1, _subject());
        require(
            root == keccak256("root") && count == 1
                && schema == StreamContentRootSchemas.LEAF_SCHEMA,
            "authoritative read"
        );
        (root, count, schema) = router.tokenContentRoot(1, keccak256("other scope"));
        require(root == 0 && count == 0 && schema == 0, "scope isolation");
        require(
            beforeServing
                == keccak256(
                    abi.encode(router.collectionServingFacts(1), router.collectionServingSource(1))
                ),
            "no self-invalidating serving change"
        );
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(
            logs.length == 2 && logs[0].emitter == address(router)
                && logs[1].emitter == address(router),
            "Router events"
        );
        require(
            logs[0].topics[1] == bytes32(uint256(1)) && logs[0].topics[2] == _subject()
                && logs[0].topics[3] == hash,
            "root topics"
        );
        require(
            logs[0].topics[0]
                == keccak256(
                    "TokenContentRootPublished(uint16,uint256,bytes32,bytes32,((uint256,bytes32,bytes32,string),bytes32,uint64,bytes32,bytes32,uint64,bytes32,address,uint8,uint64,bytes32,bytes32,bytes32,uint64))"
                ),
            "root signature"
        );
        require(
            keccak256(logs[0].data)
                == keccak256(abi.encode(uint16(1), router.contentRootRecord(hash))),
            "entire root event data"
        );
        require(
            logs[1].topics[0]
                    == keccak256(
                        "ArtistContentConsentApplied(uint256,bytes32,bytes32,bytes32,uint16)"
                    ) && logs[1].topics[1] == bytes32(uint256(1)) && logs[1].topics[2] == FAMILY
                && logs[1].topics[3] == keccak256("consent"),
            "consent event signature and topics"
        );
        (, bytes32 current) = router.currentArtistContentState(1);
        require(
            keccak256(logs[1].data) == keccak256(abi.encode(current, uint16(1))),
            "consent event data"
        );
    }

    function testExactSchemaBytesRequireRawCanonicalization() public {
        bytes32 other = _register(
            "OTHER_CANON",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes("other"),
            schemas.RAW_BYTES()
        );
        _documents(other);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentRootPublication.InvalidContentRootPublication.selector
            )
        );
        router.previewContentRootPublication(_publication(), address(this));
    }

    function testMissingAndRetiredDefinitionsRejectPublication() public {
        vm.expectRevert();
        router.previewContentRootPublication(_publication(), address(this));
        _documents(schemas.RAW_BYTES());
        bytes32 id = StreamContentRootSchemas.LEAF_SCHEMA;
        (bytes32 s, bytes32 o, bytes32 n) =
            schemas.statusTransition(id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED);
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus, (id, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
        vm.expectRevert();
        router.previewContentRootPublication(_publication(), address(this));
    }

    function testWriterRevocationAndRevisionInvalidateApproval() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 old = _approve(p, address(this), keccak256("consent"));
        _grant(1, 7, address(this), false);
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        _grant(1, 7, address(this), true);
        require(old != router.previewContentRootPublication(p, address(this)), "revision included");
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        require(
            !router.consumedArtistContentConsent(keccak256("consent")), "unused approval retained"
        );
    }

    function testArtistGenerationAndPublisherAreBound() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 old = _approve(p, address(this), keccak256("consent"));
        _grant(1, 7, address(0xB0B), true);
        require(
            old != router.previewContentRootPublication(p, address(0xB0B)), "publisher included"
        );
        vm.prank(address(0xB0B));
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        artist.changeGeneration();
        require(
            old != router.previewContentRootPublication(p, address(this)), "generation included"
        );
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
    }

    function testGlobalSafePublisherAndAllNewCalls() public {
        _documents(schemas.RAW_BYTES());
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0xA11CE;
        keys[1] = 0xB0B;
        OfficialSafe safe =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 9811);
        _grant(0, 8, address(safe), true);
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(safe), keccak256("safe-consent"));
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.previewContentRootPublication, (p, address(safe))),
                0
            ),
            "Safe execution"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.publishVerifiedTokenContentRoot, (p)),
                0
            ),
            "Safe execution"
        );
        bytes32 hash = router.collectionContentRootHead(1);
        IStreamContentRootPublication.Record memory r = router.contentRootRecord(hash);
        require(
            r.publisher == address(safe) && r.authorizationClass == 8, "global Safe publication"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.collectionContentRootHead, (1)),
                0
            ),
            "Safe execution"
        );
        require(
            executeSafe(
                safe, keys, address(router), 0, abi.encodeCall(router.contentRootRecord, (hash)), 0
            ),
            "Safe execution"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.tokenContentRoot, (1, _subject())),
                0
            ),
            "Safe execution"
        );
        require(
            executeSafe(
                safe,
                keys,
                address(router),
                0,
                abi.encodeCall(router.artistContentFamilyState, (1, FAMILY)),
                0
            ),
            "Safe execution"
        );
        require(safe.nonce() == 6, "all new function calls through Safe");
    }

    function testPredecessorReplayAndHistoryAfterEvidenceRetirement() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(this), keccak256("first"));
        bytes32 first = router.publishVerifiedTokenContentRoot(p);
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        p.expectedPredecessor = first;
        p.manifestURI = "ipfs://manifest:two";
        _approve(p, address(this), keccak256("first"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentConsentConsumed.selector, keccak256("first")
            )
        );
        router.publishVerifiedTokenContentRoot(p);
        _approve(p, address(this), keccak256("second"));
        bytes32 second = router.publishVerifiedTokenContentRoot(p);
        require(
            router.contentRootRecord(second).publication.expectedPredecessor == first, "lineage"
        );
        manifest.setCurrent(false);
        require(
            router.contentRootRecord(first).artistConsent == keccak256("first"), "retained history"
        );
        p.expectedPredecessor = second;
        vm.expectRevert();
        router.previewContentRootPublication(p, address(this));
    }

    function testFinalityPointerDriftAndCoreFreezeRejectAtomically() public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(this), keccak256("consent"));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(metadata));
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        core.setFrozen(true);
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        require(
            !router.consumedArtistContentConsent(keccak256("consent"))
                && router.collectionContentRootHead(1) == 0,
            "atomic rollback"
        );
    }

    function testRatificationEvolutionAcrossTwoPublications() public {
        _documents(schemas.RAW_BYTES());
        (, bytes32 beforeState) = router.currentArtistContentState(1);
        artist.ratify(beforeState, keccak256("ratification"));
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(this), keccak256("first"));
        p.expectedPredecessor = router.publishVerifiedTokenContentRoot(p);
        _approve(p, address(this), keccak256("second"));
        router.publishVerifiedTokenContentRoot(p);
        (bytes32 ratification, bytes32 evolved) = router.artistContentEvolution(1);
        (, bytes32 current) = router.currentArtistContentState(1);
        require(
            ratification == keccak256("ratification") && evolved == current
                && current != beforeState,
            "two-step evolution"
        );
        artist.ratify(beforeState, keccak256("changed ratification"));
        p.expectedPredecessor = router.collectionContentRootHead(1);
        _approve(p, address(this), keccak256("third"));
        vm.expectRevert(
            abi.encodeWithSelector(
                StreamMetadataRouter.ArtistContentEvolutionBroken.selector, uint256(1)
            )
        );
        router.publishVerifiedTokenContentRoot(p);
    }

    function testNoMintBootstrapCannotPublishWithoutArtistConsent() public {
        _documents(schemas.RAW_BYTES());
        core.setMinted(0);
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(this), keccak256("consent"));
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        require(router.collectionContentRootHead(1) == 0, "root always needs consent");
    }

    function testRevertAfterConsumptionRollsBackAndSameConsentRetries() public {
        _documents(schemas.RAW_BYTES());
        (, bytes32 beforeState) = router.currentArtistContentState(1);
        artist.ratify(beforeState, keccak256("ratification"));
        IStreamContentRootPublication.Publication memory p = _publication();
        _approve(p, address(this), keccak256("consent"));
        vm.warp(uint256(type(uint64).max) + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamContentRootPublication.InvalidContentRootPublication.selector
            )
        );
        router.publishVerifiedTokenContentRoot(p);
        (bytes32 ratification, bytes32 evolved) = router.artistContentEvolution(1);
        require(
            !router.consumedArtistContentConsent(keccak256("consent"))
                && router.collectionContentRootHead(1) == 0 && ratification == 0 && evolved == 0,
            "post-consumption revert is atomic"
        );
        vm.warp(1001);
        router.publishVerifiedTokenContentRoot(p);
        require(
            router.consumedArtistContentConsent(keccak256("consent")), "identical approval retries"
        );
    }

    function testFreezeLibraryPreservesAuthorizationAndRouterEvent() public {
        bytes32 state = router.artistContentFreezeState(1);
        bytes32[] memory locks = new bytes32[](1);
        locks[0] = keccak256("SCRIPT");
        artist.setFreeze(state, locks);
        vm.recordLogs();
        router.applyArtistContentFreeze(1, keccak256("freeze"));
        (bool supported, bool locked) = router.artistContentLockState(1, locks[0]);
        require(supported && locked, "freeze applied");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        require(logs.length == 1 && logs[0].emitter == address(router), "Router freeze event");
        router.applyArtistContentFreeze(1, keccak256("freeze"));
        vm.expectRevert();
        router.setCollectionScript(1, "changed();");
    }

    function testFuzzManifestUriBindsExactApprovedBytes(uint96 value) public {
        _documents(schemas.RAW_BYTES());
        IStreamContentRootPublication.Publication memory p = _publication();
        bytes32 old = _approve(p, address(this), keccak256("consent"));
        p.manifestURI = string.concat("ipfs://manifest:", Strings.toString(uint256(value)));
        require(old != router.previewContentRootPublication(p, address(this)), "URI exactness");
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
    }
}
