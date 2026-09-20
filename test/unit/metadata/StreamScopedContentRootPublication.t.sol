// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamContentRootPublication
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    RootProviderBoundary,
    RootFinalityBoundary,
    RootCheckpointBoundary,
    RootArtifactsBoundary,
    RootManifestBoundary
} from "./StreamContentRootPublication.t.sol";
import {
    IStreamScopedContentRootPublication as ScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    StreamScopedSnapshotTypes as Snapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    StreamContentRootSchemas
} from "../../../smart-contracts/domains/finality/StreamContentRootSchemas.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";

/// @dev Explicit already-validated scoped-snapshot boundary. The actual snapshot's membership,
/// output/currentness validation has its own suite; it is not fabricated integration here.
contract ScopedRootSnapshotBoundary {
    address public immutable core;
    address public immutable metadataHost;
    address public immutable router;
    mapping(bytes32 => Snapshot.Receipt) private receipts;
    mapping(bytes32 => bytes) private payloads;
    bool public current = true;
    bytes32 public rejectConsumed;

    constructor(address c, address m, address r) {
        core = c;
        metadataHost = m;
        router = r;
    }

    function setCurrent(bool v) external {
        current = v;
    }

    function setLateFailure(bytes32 consent) external {
        rejectConsumed = consent;
    }

    function install(StreamFinalityScope memory scope, bytes32 key) external {
        Snapshot.Source memory source;
        source.scope = scope;
        source.artist.artistId = keccak256("artist");
        source.artist.bindingGeneration = 1;
        source.artist.bindingHash = keccak256("binding");
        source.outputs.contentRoot = keccak256(abi.encode("root", scope));
        source.outputs.tokenCount = 1;
        source.outputs.manifestHash = keccak256(abi.encode("manifest", scope));
        Snapshot.Publication memory p;
        p.scope = scope;
        Snapshot.Receipt memory r;
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        r.revision = 1;
        r.sourceHash = keccak256(abi.encode(source));
        r.publisher = address(this);
        address[11] memory targets;
        bytes32[11] memory pins;
        targets[0] = core;
        targets[1] = metadataHost;
        targets[4] = router;
        pins[0] = core.codehash;
        pins[1] = metadataHost.codehash;
        pins[4] = router.codehash;
        bytes memory raw = abi.encode(
            keccak256("6529STREAM_SCOPED_SNAPSHOT_PAYLOAD_V1"),
            block.chainid,
            address(this),
            targets,
            pins,
            p,
            r,
            source
        );
        r.recordHash = key;
        r.manifestHash = keccak256(raw);
        r.manifestBytes = uint32(raw.length);
        receipts[key] = r;
        payloads[key] = raw;
    }

    function requireCurrent(StreamFinalityScope calldata scope, bytes32 key, uint64 revision)
        external
        view
        returns (Snapshot.Receipt memory r)
    {
        r = receipts[key];
        require(
            current && r.recordHash == key && r.revision == revision
                && r.scopeSubject
                    == StreamMetadataSubjects.scopeSubject(block.chainid, core, scope),
            "current snapshot"
        );
        if (rejectConsumed != 0) {
            require(
                !StreamMetadataRouter(router).consumedArtistContentConsent(rejectConsumed),
                "late snapshot failure"
            );
        }
    }

    function snapshotPayload(bytes32 key) external view returns (bytes memory) {
        return payloads[key];
    }
}

contract ScopedRootProviderBoundary is RootProviderBoundary {
    address public immutable scopedSnapshotHost;
    bytes32 public immutable scopedSnapshotCodeHash;
    uint256 public constant scopedSnapshotValidationGas = 5000000;

    constructor(address m, address s, address l, address snapshots) RootProviderBoundary(m, s, l) {
        scopedSnapshotHost = snapshots;
        scopedSnapshotCodeHash = snapshots.codehash;
    }
}

contract ScopedRootFinalityBoundary is RootFinalityBoundary {
    StreamArtworkFreezeMode public mode;
    constructor(address c, address a, address m, address p, address f)
        RootFinalityBoundary(c, a, m, p, f)
    { }

    function setFreeze(StreamArtworkFreezeMode value) external {
        mode = value;
    }

    function artworkFreezeMode(StreamFinalityScope calldata)
        external
        view
        returns (StreamArtworkFreezeMode)
    {
        return mode;
    }
}

/// @notice Actual Router/STATIC configuration, Metadata grants, schemas, Store and threshold Safe.
/// @dev Core/Artist signatures, finality/provider and validated snapshot are named typed boundaries.
/// No actual Artist op17, complete snapshot producer, current Core or finality ceremony claim.
contract StreamScopedContentRootPublicationTest is StaticMetadataRoutingFixture {
    StaticRouteVm private constant mockVm =
        StaticRouteVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ROOT = keccak256("CONTENT_ROOT");
    ScopedRootSnapshotBoundary private snapshots;
    ScopedRootFinalityBoundary private finality;

    function setUp() public override {
        super.setUp();
        vm.warp(1000);
        _activate();
        _mint();
        snapshots =
            new ScopedRootSnapshotBoundary(address(core), address(metadata), address(router));
        address cp = address(new RootCheckpointBoundary(address(core), address(router)));
        address artifacts = address(new RootArtifactsBoundary(address(schemas)));
        address manifest = address(new RootManifestBoundary(address(core), cp, artifacts));
        address provider = address(
            new ScopedRootProviderBoundary(
                address(metadata), address(schemas), manifest, address(snapshots)
            )
        );
        finality = new ScopedRootFinalityBoundary(
            address(core), address(artist), address(metadata), provider, artifacts
        );
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(finality));
        mockVm.mockCall(
            address(artist),
            abi.encodeWithSignature("finalityRegistry()"),
            abi.encode(address(finality))
        );
        mockVm.mockCall(
            address(artist),
            abi.encodeWithSignature("finalityRegistryCodeHash()"),
            abi.encode(address(finality).codehash)
        );
        mockVm.mockCall(
            address(artist),
            abi.encodeWithSignature("collectionArtistState(uint256)", 1),
            abi.encode(uint8(2), uint64(1), keccak256("artist"), uint8(1), keccak256("binding"))
        );
        _rootGrant(address(this), 1, 7, true);
    }

    function _rootGrant(address actor, uint256 cid, uint8 cls, bool enabled) private {
        bytes32 family = keccak256("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1");
        (bytes32 s, bytes32 o, bytes32 n) =
            metadata.familyWriterTransition(cid, family, cls, actor, enabled);
        executor.execute(
            address(metadata),
            abi.encodeCall(metadata.setFamilyWriter, (cid, family, cls, actor, enabled)),
            s,
            o,
            n
        );
    }

    function _publication(uint8 kind) private returns (ScopedRoot.Publication memory p) {
        p.scope = kind == 1
            ? StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 91, 0)
            : StreamFinalityScope(
                StreamFinalityScopeType(kind), 1, 0, keccak256(abi.encode("scope", kind))
            );
        p.snapshotRecordHash = keccak256(abi.encode("snapshot", kind));
        p.snapshotRevision = 1;
        p.manifestURI = "ipfs://bafkreigh2akiscaildc6p3i3o2uo5ke4nl6dlmrdu5wq5xj2i5skwe2e6i";
        snapshots.install(p.scope, p.snapshotRecordHash);
    }

    function _publish(ScopedRoot.Publication memory p, bytes32 consent)
        private
        returns (bytes32 hash)
    {
        artist.approve(
            1, ROOT, router.previewScopedContentRootPublication(p, address(this)), consent
        );
        return router.publishScopedContentRootPublication(p);
    }

    function _family(bytes32 legacy, ScopedRoot.Aggregate memory aggregate)
        private
        view
        returns (bytes32)
    {
        if (aggregate.revision == 0) return legacy;
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                block.chainid,
                address(router),
                address(core),
                uint256(1),
                legacy,
                aggregate
            )
        );
    }

    function testTwoScopesIndependentHeadsExactAggregateAndOriginalConsentMap() public {
        (bool supported, bytes32 legacy) = router.artistContentFamilyState(1, ROOT);
        require(supported && router.scopedContentRootAggregate(1).revision == 0);
        ScopedRoot.Publication memory first = _publication(1);
        bytes32 consent = keccak256("first");
        bytes32 expected = router.previewScopedContentRootPublication(first, address(this));
        bytes32 hash = _publish(first, consent);
        ScopedRoot.Record memory record = router.scopedContentRootRecord(hash);
        ScopedRoot.Aggregate memory one = router.scopedContentRootAggregate(1);
        bytes32 subject =
            StreamMetadataSubjects.scopeSubject(block.chainid, address(core), first.scope);
        require(
            one.revision == 1
                && one.transitionChain
                    == keccak256(
                        abi.encode(
                            keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                            block.chainid,
                            address(router),
                            address(core),
                            uint256(1),
                            bytes32(0),
                            uint64(1),
                            subject,
                            bytes32(0),
                            record.stateHash
                        )
                    )
        );
        (supported, legacy) = router.artistContentFamilyState(1, ROOT);
        require(supported && legacy == expected && router.consumedArtistContentConsent(consent));
        require(
            record.artistConsent == consent && record.publisher == address(this)
                && record.authorizationClass == 7
        );
        ScopedRoot.Publication memory second = _publication(2);
        _publish(second, keccak256("second"));
        require(
            router.scopedContentRootAggregate(1).revision == 2
                && router.scopedContentRootHead(first.scope) == hash
        );
        require(router.scopedContentRootHead(second.scope) != 0);
        (bytes32 root, uint64 count, bytes32 schema) = router.scopedTokenContentRoot(first.scope);
        require(
            root == record.contentRoot && count == record.leafCount
                && schema == StreamContentRootSchemas.LEAF_SCHEMA
        );
        vm.expectRevert();
        router.publishScopedContentRootPublication(first);
    }

    function testPrescopeConsentCannotAuthorizeAfterAnotherScope() public {
        ScopedRoot.Publication memory first = _publication(1);
        ScopedRoot.Publication memory second = _publication(3);
        bytes32 stale = router.previewScopedContentRootPublication(second, address(this));
        bytes32 consent = keccak256("stale prior aggregate");
        artist.approve(1, ROOT, stale, consent);
        _publish(first, keccak256("earlier actual write"));
        require(router.previewScopedContentRootPublication(second, address(this)) != stale);
        vm.expectRevert();
        router.publishScopedContentRootPublication(second);
        require(
            !router.consumedArtistContentConsent(consent)
                && router.scopedContentRootHead(second.scope) == 0
        );
    }

    function testScriptMediaAndStaticWritesKeepScopedAggregateAndServingCommitment() public {
        _publish(_publication(1), keccak256("scope"));
        ScopedRoot.Aggregate memory aggregate = router.scopedContentRootAggregate(1);
        bytes32 prior = router.artistContentFreezeState(1);
        string memory script = "document.body.textContent = 'second';";
        artist.approve(
            1, keccak256("SCRIPT"), router.previewArtistScriptState(1, script), keccak256("script")
        );
        _admin(abi.encodeCall(router.setCollectionScript, (1, script)));
        require(router.artistContentFreezeState(1) != prior);
        prior = router.artistContentFreezeState(1);
        artist.approve(
            1,
            keccak256("MEDIA_MANIFEST"),
            router.previewArtistMediaState(1, "ipfs://next", ""),
            keccak256("media")
        );
        _admin(
            abi.encodeCall(
                router.setCollectionMetadata, (1, "Static work", "Exact source", "ipfs://next", "")
            )
        );
        require(router.artistContentFreezeState(1) != prior);
        prior = router.artistContentFreezeState(1);
        S.ConfigInput memory config = _input(R.MetadataMode.HYBRID, false);
        _approve(0, config, keccak256("static"));
        router.setCollectionMetadataConfig(1, config);
        require(router.artistContentFreezeState(1) != prior);
        require(
            keccak256(abi.encode(router.scopedContentRootAggregate(1)))
                == keccak256(abi.encode(aggregate))
        );
        bytes32 legacy = keccak256(
            abi.encode(
                keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(router),
                address(core),
                uint256(1)
            )
        );
        (, bytes32 actual) = router.artistContentFamilyState(1, ROOT);
        require(actual == _family(legacy, aggregate));
        _assertServing(aggregate);
    }

    function _assertServing(ScopedRoot.Aggregate memory aggregate) private view {
        S.RawSource memory raw = router.staticRenderSource(1);
        bytes32 context = keccak256(
            abi.encode(
                block.chainid,
                address(core),
                uint256(1),
                address(router),
                address(router).codehash,
                address(StreamMetadataRenderer),
                address(StreamMetadataRenderer).codehash
            )
        );
        bytes32 serving = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_ONCHAIN_CONTENT_V1"),
                context,
                keccak256(bytes(raw.imageURI)),
                keccak256(bytes(raw.animationBaseURI)),
                keccak256(bytes(raw.script))
            )
        );
        serving = keccak256(
            abi.encode(
                keccak256("6529STREAM_ROUTER_CONTENT_WITH_SCOPED_ROOTS_V1"),
                block.chainid,
                address(router),
                address(core),
                uint256(1),
                serving,
                aggregate
            )
        );
        (, bytes32 staticFamily) = router.artistContentFamilyState(1, FAMILY);
        require(
            router.artistContentFreezeState(1)
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_WITH_STATIC_CONFIG_V1"), serving, staticFamily
                    )
                ),
            "all live scoped state retained"
        );
    }

    function testExactInheritedAndCollectionFreezeRefuseWithoutConsuming() public {
        ScopedRoot.Publication memory p = _publication(1);
        bytes32 consent = keccak256("freeze refusal");
        artist.approve(
            1, ROOT, router.previewScopedContentRootPublication(p, address(this)), consent
        );
        finality.setFreeze(StreamArtworkFreezeMode.EXACT);
        vm.expectRevert();
        router.publishScopedContentRootPublication(p);
        finality.setFreeze(StreamArtworkFreezeMode.INHERITED);
        vm.expectRevert();
        router.publishScopedContentRootPublication(p);
        finality.setFreeze(StreamArtworkFreezeMode.NONE);
        core.setFrozen(true);
        vm.expectRevert();
        router.publishScopedContentRootPublication(p);
        require(
            !router.consumedArtistContentConsent(consent)
                && router.scopedContentRootAggregate(1).revision == 0
        );
    }

    function testLateSourceFailureRollsBackExactSafeConsentAndNonce() public {
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0x6530;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 701);
        _rootGrant(address(account), 0, 8, true);
        ScopedRoot.Publication memory p = _publication(1);
        bytes32 consent = keccak256("safe original content consent");
        artist.approve(
            1, ROOT, router.previewScopedContentRootPublication(p, address(account)), consent
        );
        bytes memory input = abi.encodeCall(router.publishScopedContentRootPublication, (p));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(router), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        snapshots.setLateFailure(consent);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(router), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && !router.consumedArtistContentConsent(consent));
        require(
            router.scopedContentRootHead(p.scope) == 0
                && router.scopedContentRootAggregate(1).revision == 0
        );
        snapshots.setLateFailure(0);
        require(
            account.execTransaction(
                address(router), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(account.nonce() == nonce + 1 && router.consumedArtistContentConsent(consent));
        ScopedRoot.Record memory saved =
            router.scopedContentRootRecord(router.scopedContentRootHead(p.scope));
        require(saved.publisher == address(account) && saved.authorizationClass == 8);
    }

    function testCurrentSourceGrantBindingAndViewRefusalsKeepHistoricalRecord() public {
        ScopedRoot.Publication memory p = _publication(1);
        bytes32 hash = _publish(p, keccak256("historical"));
        bytes32 old = keccak256(abi.encode(router.scopedContentRootRecord(hash)));
        p.expectedPredecessor = hash;
        snapshots.setCurrent(false);
        vm.expectRevert();
        router.previewScopedContentRootPublication(p, address(this));
        snapshots.setCurrent(true);
        _rootGrant(address(this), 1, 7, false);
        vm.expectRevert();
        router.previewScopedContentRootPublication(p, address(this));
        _rootGrant(address(this), 1, 7, true);
        mockVm.mockCall(
            address(artist),
            abi.encodeWithSignature("collectionArtistState(uint256)", 1),
            abi.encode(uint8(2), uint64(2), keccak256("artist"), uint8(1), keccak256("new binding"))
        );
        vm.expectRevert();
        router.previewScopedContentRootPublication(p, address(this));
        p.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        vm.expectRevert();
        router.previewScopedContentRootPublication(p, address(this));
        require(keccak256(abi.encode(router.scopedContentRootRecord(hash))) == old);
    }

    function testLegacyCollectionPublicationAfterScopesAuthorizesWrappedFamilyOnly() public {
        _documents();
        IStreamContentRootPublication.Publication memory p =
            IStreamContentRootPublication.Publication(
                1, 0, keccak256("verified"), "ipfs://manifest:one"
            );
        bytes32 unwrapped = router.previewContentRootPublication(p, address(this));
        _publish(_publication(1), keccak256("scope before collection"));
        ScopedRoot.Aggregate memory aggregate = router.scopedContentRootAggregate(1);
        bytes32 expected = router.previewContentRootPublication(p, address(this));
        require(expected == _family(unwrapped, aggregate) && expected != unwrapped);
        bytes32 stale = keccak256("stale collection consent");
        artist.approve(1, ROOT, unwrapped, stale);
        vm.expectRevert();
        router.publishVerifiedTokenContentRoot(p);
        bytes32 consent = keccak256("wrapped collection consent");
        artist.approve(1, ROOT, expected, consent);
        bytes32 hash = router.publishVerifiedTokenContentRoot(p);
        IStreamContentRootPublication.Record memory record = router.contentRootRecord(hash);
        require(
            record.stateHash == unwrapped && record.artistConsent == consent
                && !router.consumedArtistContentConsent(stale)
        );
        (, bytes32 actual) = router.artistContentFamilyState(1, ROOT);
        require(
            actual == expected
                && router.scopedContentRootAggregate(1).transitionChain == aggregate.transitionChain
        );
    }

    function _documents() private {
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
        _document(
            store,
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _document(
            store,
            "STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamContentRootSchemas.document(StreamContentRootSchemas.LEAF_SCHEMA)
        );
        _document(
            store,
            "STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamContentRootSchemas.document(
                keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1")
            )
        );
        _document(
            store,
            "STREAM_TOKEN_CONTENT_ROOT_RECORD_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            StreamContentRootSchemas.document(StreamContentRootSchemas.ROOT_SCHEMA)
        );
        _document(
            store,
            "STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            StreamContentRootSchemas.document(keccak256("STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1"))
        );
    }

    function _document(
        StreamSchemaDocumentStore store,
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) private {
        (bytes32 hash,) = store.publishChunk(raw);
        bytes32[] memory chunks = new bytes32[](1);
        chunks[0] = hash;
        IStreamSchemaRegistry.DocumentSpec memory spec = IStreamSchemaRegistry.DocumentSpec(
            name, kind, hash, schemas.RAW_BYTES(), 0, "", uint32(raw.length)
        );
        (bytes32 s, bytes32 o, bytes32 n) = schemas.registrationTransition(spec, chunks);
        executor.execute(
            address(schemas), abi.encodeCall(schemas.registerDocument, (spec, chunks)), s, o, n
        );
    }
}
