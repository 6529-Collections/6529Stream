// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamScopedPreservationPolicyContentRootV1.t.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as FamilySnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV2 as FamilyRootDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicyOutputSchemasV2 as FamilyOutputDocuments
} from "../../../smart-contracts/domains/finality/StreamPreservationPolicyOutputSchemasV2.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as ProducerFamily
} from "../../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";

/// @dev Explicit already-validated V2 snapshot boundary with actually retained canonical payloads.
/// Its membership, output and factory facts are synthetic boundary facts; this is not a renderer,
/// actual snapshot writer/factory, Artist signature ceremony, or full Finality integration test.
contract FamilyScopedSnapshotBoundary {
    bytes32 private constant PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2");
    address public immutable core;
    address public immutable metadataHost;
    address public immutable router;
    address public immutable factory;
    PreservationSnapshot.Dependencies private deps;
    mapping(bytes32 => PreservationSnapshot.Publication) private publications;
    mapping(bytes32 => PreservationSnapshot.Receipt) private receipts;
    mapping(bytes32 => bytes) private payloads;
    uint8 public currentFault;
    bytes32 public profileMarker = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2");
    bool public interfaceValid = true;
    bytes32 public rejectConsumed;

    constructor(address c, address m, address r, address schemas, address store) {
        core = c;
        metadataHost = m;
        router = r;
        factory = address(new PreservationScopedDependencyBoundary());
        deps.targets[0] = c;
        deps.targets[1] = m;
        deps.targets[2] = schemas;
        deps.targets[3] = store;
        deps.targets[4] = r;
        for (uint256 i = 5; i < 11; ++i) {
            deps.targets[i] = address(new PreservationScopedDependencyBoundary());
        }
        for (uint256 i; i < 11; ++i) {
            deps.codeHashes[i] = deps.targets[i].codehash;
        }
        deps.chainId = block.chainid;
        deps.readGas = 5000000;
        deps.sourceGas = 5000000;
        deps.inventoryGas = 5000000;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return interfaceValid && (id == type(PreservationSnap).interfaceId || id == 0x01ffc9a7);
    }

    function scopedPreservationPolicySnapshotProfile() external view returns (bytes32) {
        return profileMarker;
    }

    function dependencies() external view returns (PreservationSnapshot.Dependencies memory) {
        return deps;
    }

    function setDependencyPin(uint256 index, bytes32 value) external {
        deps.codeHashes[index] = value;
    }

    function setProfile(bool value) external {
        profileMarker =
            value ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2") : bytes32(0);
    }

    function setProfileMarker(bytes32 value) external {
        profileMarker = value;
    }

    function setInterface(bool value) external {
        interfaceValid = value;
    }

    function setCurrentFault(uint8 value) external {
        currentFault = value;
    }

    function setLateFailure(bytes32 consent) external {
        rejectConsumed = consent;
    }

    function install(StreamFinalityScope memory scope, uint8 malformed)
        external
        returns (bytes32 key)
    {
        PreservationSnapshot.Source memory source;
        source.scope = abi.decode(abi.encode(scope), (StreamFinalityScope));
        source.membership.scopeSubject =
            StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        source.membership.tokenCount = 1;
        source.membership.membershipHash = keccak256(abi.encode("validated membership", scope));
        source.artist.artistId = keccak256("artist");
        source.artist.bindingGeneration = 1;
        source.artist.bindingHash = keccak256("binding");
        source.outputs.contentRoot = keccak256(abi.encode("root V2", scope));
        source.outputs.tokenCount = 1;
        source.outputs.manifestHash = keccak256(abi.encode("output manifest V2", scope));
        source.outputs.outputRoot = keccak256("output root");
        source.outputs.checkpointHash = keccak256("checkpoint");
        source.outputs.checkpointStateHash = keccak256("checkpoint state");
        source.outputs.entropySourceSet = deps.targets[10];
        source.outputs.inventoryHash = keccak256("complete inventory");
        source.outputs.policyChainHash = keccak256("complete policy chain");
        source.outputs.scope = scope;
        source.outputs.metadataRouter = router;
        source.outputs.preservationProfile = ProducerFamily.FAMILY_PROFILE;
        source.content.preservationProfile = ProducerFamily.FAMILY_PROFILE;
        source.sourceFactory = factory;
        source.sourceFactoryCodeHash = factory.codehash;
        source.factoryDependenciesHash = keccak256("factory dependencies");
        if (malformed == 1) source.sourceFactoryCodeHash = keccak256("wrong factory runtime");
        if (malformed == 4) source.scope.tokenId = 92;
        if (malformed == 5) source.artist.bindingHash = keccak256("different accepted binding");
        if (malformed == 6) source.outputs.policyChainHash = 0;
        if (malformed == 7) source.outputs.metadataRouter = address(0xBAD);
        if (malformed == 8) source.outputs.preservationProfile = keccak256("live profile");
        if (malformed == 9) source.content.preservationProfile = keccak256("live profile");
        if (malformed == 10) source.outputs.entropySourceSet = address(0xBAD);
        if (malformed == 11) ++source.artist.bindingGeneration;
        if (malformed == 17) {
            source.outputs.preservationProfile = ProducerFamily.ORIGINAL_PROFILE;
            source.content.preservationProfile = ProducerFamily.ORIGINAL_PROFILE;
        }
        if (malformed == 18) {
            source.outputs.preservationProfile = ProducerFamily.CURRENT_ARTIST_PROFILE;
        }
        if (malformed == 19) source.content.preservationProfile = ProducerFamily.ORIGINAL_PROFILE;
        return _retain(scope, source, malformed);
    }

    function _retain(
        StreamFinalityScope memory scope,
        PreservationSnapshot.Source memory source,
        uint8 malformed
    ) private returns (bytes32 key) {
        PreservationSnapshot.Publication memory p;
        p.scope = scope;
        p.snapshotId = keccak256(abi.encode("snapshot V2", scope, malformed));
        p.outputManifestRecord = source.outputs.manifestHash;
        p.coordinatorInventoryPlan = source.outputs.inventoryHash;
        p.manifestURI = "ipfs://preservation-snapshot";
        p.effectiveAt = uint64(block.timestamp);
        p.reasonHash = keccak256("snapshot publication reason");
        PreservationSnapshot.Receipt memory r;
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        r.revision = 1;
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        r.displayAuthorizationClass = 7;
        r.displayGrantRevision = 1;
        r.schemaHash = malformed == 12
            ? SnapshotDefinitions.SCHEMA_HASH
            : FamilySnapshotDefinitions.SCHEMA_HASH;
        r.profileHash = FamilySnapshotDefinitions.PROFILE_HASH;
        r.canonicalizationHash = FamilySnapshotDefinitions.CANON_HASH;
        r.sourceHash = keccak256(
            abi.encode(
                (malformed == 15
                        ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1")
                        : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V2")),
                block.chainid,
                address(this),
                deps.targets,
                deps.codeHashes,
                source
            )
        );
        if (malformed == 3) r.sourceHash = keccak256("wrong source hash");
        // Only expectedSourceHash plus the five documented circular receipt fields are erased.
        // Fault 2 deliberately violates that normalization while retaining canonical outer ABI.
        if (malformed == 2) p.expectedSourceHash = r.sourceHash;
        bytes memory raw = abi.encode(
            (malformed == 14
                    ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1")
                    : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V2")),
            block.chainid,
            address(this),
            deps.targets,
            deps.codeHashes,
            p,
            r,
            source
        );
        if (malformed == 13) raw = bytes.concat(raw, bytes32(uint256(1)));
        p.expectedSourceHash = r.sourceHash;
        r.manifestHash = keccak256(raw);
        r.manifestBytes = uint32(raw.length);
        r.recordedAt = uint64(block.timestamp);
        key = keccak256(
            abi.encode(
                (malformed == 16
                        ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1")
                        : keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V2")),
                block.chainid,
                address(this),
                core,
                metadataHost,
                p,
                r
            )
        );
        r.recordHash = key;
        r.chainHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V2"),
                block.chainid,
                address(this),
                core,
                scope,
                bytes32(0),
                uint64(1),
                key
            )
        );
        publications[key] = p;
        receipts[key] = r;
        payloads[key] = raw;
    }

    function snapshotRecord(bytes32 key)
        external
        view
        returns (PreservationSnapshot.Publication memory, PreservationSnapshot.Receipt memory)
    {
        return (publications[key], receipts[key]);
    }

    function snapshotPayload(bytes32 key) external view returns (bytes memory) {
        return payloads[key];
    }

    function setPayload(bytes32 key, bytes calldata raw) external {
        payloads[key] = raw;
    }

    function requireCurrent(StreamFinalityScope calldata scope, bytes32 key, uint64 revision)
        external
        view
        returns (PreservationSnapshot.Receipt memory r)
    {
        require(msg.sender == router, "exact preservation snapshot consumer");
        require(
            currentFault != 1 && currentFault != 2 && currentFault != 4,
            "validated snapshot unavailable"
        );
        r = receipts[key];
        require(
            r.recordHash == key && r.revision == revision
                && r.scopeSubject
                    == StreamMetadataSubjects.scopeSubject(block.chainid, core, scope),
            "snapshot identity"
        );
        if (rejectConsumed != 0) {
            require(
                !PreservationRootWorkerHost(router).consumedArtistContentConsent(rejectConsumed),
                "late snapshot failure"
            );
        }
        if (currentFault == 3) ++r.grantRevision;
    }
}

contract FamilyScopedProviderBoundary is ScopedRootProviderBoundary {
    address private immutable policySnapshots;
    bytes32 private immutable policySnapshotHash;
    bytes32 public profileMarker = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2");
    bool public interfaceValid = true;

    constructor(address m, address s, address l, address oldSnapshots, address snapshots)
        ScopedRootProviderBoundary(m, s, l, oldSnapshots)
    {
        policySnapshots = snapshots;
        policySnapshotHash = snapshots.codehash;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return interfaceValid && (id == type(ScopedProvider).interfaceId || id == 0x01ffc9a7);
    }

    function scopedPreservationPolicySnapshotProfile() external view returns (bytes32) {
        return profileMarker;
    }

    function scopedPreservationPolicySnapshotHost(StreamFinalityScope calldata)
        external
        view
        returns (address)
    {
        return policySnapshots;
    }

    function scopedPreservationPolicySnapshotCodeHash(StreamFinalityScope calldata)
        external
        view
        returns (bytes32)
    {
        return policySnapshotHash;
    }

    function scopedPreservationPolicySnapshotValidationGas(StreamFinalityScope calldata)
        external
        pure
        returns (uint256)
    {
        return 5000000;
    }

    function setProfile(bool value) external {
        profileMarker =
            value ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2") : bytes32(0);
    }

    function setProfileMarker(bytes32 value) external {
        profileMarker = value;
    }

    function setInterface(bool value) external {
        interfaceValid = value;
    }
}

/// @notice Executes actual shared scoped root preparation, publication, authorization, original
/// scoped state/aggregate and stored-binding codec with genuine Metadata grants/Schema/Store.
/// @dev Snapshot/currentness, Core, Artist consent and Finality/provider are labelled boundaries.
/// No native execution, gas/capacity, real producer admission or complete ceremony is claimed.
contract StreamScopedPreservationPolicyContentRootV2Test is PreservationRootWorkerFixture {
    FamilyScopedSnapshotBoundary private snapshots;
    FamilyScopedProviderBoundary private familyProvider;
    ScopedRootFinalityBoundary private scopedFinality;

    function setUp() public override {
        super.setUp();
        snapshots = new FamilyScopedSnapshotBoundary(
            address(core), address(metadata), address(host), address(schemas), address(store)
        );
        familyProvider = new FamilyScopedProviderBoundary(
            address(metadata),
            address(schemas),
            address(preservationManifest),
            address(snapshots),
            address(snapshots)
        );
        _selectScoped(address(familyProvider));
        string[4] memory names = [
            "STREAM_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_PRESERVATION_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                i % 2 == 0
                    ? IStreamSchemaRegistry.DocumentKind.SCHEMA
                    : IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
                FamilyRootDocuments.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
        // The exact V1 token-leaf document is already genuinely registered by the parent fixture.
    }

    function testV2PublicationUsesExactFullBindingDomainsConsentAndAggregate() public {
        Scoped.Publication memory p = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        (, PreservationSnapshot.Receipt memory snapshot) =
            snapshots.snapshotRecord(p.snapshotRecordHash);
        assertEq(keccak256(snapshots.snapshotPayload(p.snapshotRecordHash)), snapshot.manifestHash);
        bytes32 consent = keccak256("V2 exact original consent");
        bytes32 originalLegacy = host.family(1);
        bytes32 expectedFamily = _approve(p, consent);
        vm.recordLogs();
        bytes32 key = host.publishScoped(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Scoped.Record memory r = host.scopedRecord(key);
        ScopedPreservation.Binding memory b = host.scopedBinding(key);
        Scoped.Aggregate memory aggregate = host.scopedContentRootAggregate(1);
        assertEq(abi.encode(b).length, 800);
        assertEq(b.profileId, FamilyRootDocuments.PROFILE);
        assertEq(b.preservationOutputProfile, ProducerFamily.FAMILY_PROFILE);
        assertEq(b.metadataRouter, address(host));
        assertEq(b.sourceFactory, snapshots.factory());
        assertEq(b.snapshotSchemaHash, FamilySnapshotDefinitions.SCHEMA_HASH);
        assertEq(b.snapshotProfileHash, FamilySnapshotDefinitions.PROFILE_HASH);
        assertEq(b.snapshotCanonicalizationHash, FamilySnapshotDefinitions.CANON_HASH);
        assertEq(
            b.outputSchemaHash,
            keccak256(FamilyOutputDocuments.document(FamilyOutputDocuments.SCHEMA))
        );
        assertEq(
            b.outputCanonicalizationHash,
            keccak256(FamilyOutputDocuments.document(FamilyOutputDocuments.CANON))
        );
        assertEq(b.leafSchemaHash, keccak256(OutputDocuments.document(OutputDocuments.LEAF_SCHEMA)));
        assertEq(
            b.rootSchemaHash,
            keccak256(FamilyRootDocuments.document(FamilyRootDocuments.ROOT_SCHEMA))
        );
        assertEq(
            b.rootCanonicalizationHash,
            keccak256(FamilyRootDocuments.document(FamilyRootDocuments.ROOT_CANON))
        );
        assertEq(abi.encode(r.publication), abi.encode(p));
        assertEq(r.snapshotManifestHash, snapshot.manifestHash);
        assertEq(r.snapshotSourceHash, snapshot.sourceHash);
        assertEq(r.artistConsent, consent);
        assertEq(r.routeHash, _route(p.scope));
        assertEq(
            key,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2"),
                    block.chainid,
                    address(host),
                    address(core),
                    r,
                    b,
                    aggregate
                )
            )
        );
        Scoped.Record memory blank = abi.decode(abi.encode(r), (Scoped.Record));
        blank.stateHash = 0;
        blank.artistConsent = 0;
        blank.publishedAt = 0;
        assertEq(
            r.stateHash,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2"),
                    block.chainid,
                    address(host),
                    address(core),
                    blank,
                    b
                )
            )
        );
        assertEq(aggregate.revision, 1);
        assertEq(aggregate.transitionChain, _append(Scoped.Aggregate(0, 0), p, r.stateHash));
        assertEq(host.scopedHead(p.scope), key);
        assertEq(host.family(1), expectedFamily);
        assertEq(
            expectedFamily,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                    block.chainid,
                    address(host),
                    address(core),
                    uint256(1),
                    originalLegacy,
                    aggregate
                )
            )
        );
        assertTrue(host.consumedArtistContentConsent(consent));
        assertEq(logs.length, 3);
        assertEq(logs[0].emitter, address(host));
        assertEq(logs[0].data, abi.encode(uint16(3), r, aggregate));
        assertEq(logs[1].emitter, address(host));
        assertEq(logs[1].data, abi.encode(uint16(2), b));
    }

    function testV2RejectsCrossedOriginalHeadersDefinitionsAndEverySourceJoin() public {
        Scoped.Publication memory good = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        bytes32 baseline = host.previewScoped(good, address(this));
        for (uint8 fault = 1; fault <= 19; ++fault) {
            Scoped.Publication memory bad = _publicationV2(StreamFinalityScopeType.TOKEN, fault);
            _invalid(bad);
            assertEq(host.previewScoped(good, address(this)), baseline);
            assertEq(host.scopedContentRootAggregate(1).revision, 0);
        }
    }

    function testV2ProviderAndSnapshotProfilesNeverFallBackOrAutodetect() public {
        Scoped.Publication memory p = _publicationV2(StreamFinalityScopeType.SEASON, 0);
        bytes32 good = keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V2");
        bytes32[3] memory refused = [
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1"),
            keccak256("unknown family"),
            keccak256("6529STREAM_VIEW_PRESERVATION_RENDER_V1")
        ];
        for (uint256 i; i < refused.length; ++i) {
            familyProvider.setProfileMarker(refused[i]);
            _invalid(p);
            familyProvider.setProfileMarker(good);
            snapshots.setProfileMarker(refused[i]);
            _invalid(p);
            snapshots.setProfileMarker(good);
            host.previewScoped(p, address(this));
        }
        familyProvider.setInterface(false);
        _invalid(p);
        familyProvider.setInterface(true);
        snapshots.setInterface(false);
        _invalid(p);
        snapshots.setInterface(true);
        host.previewScoped(p, address(this));
    }

    function testV2AcceptsThreeCanonicalScopesAndRejectsViewAndCollection() public {
        StreamFinalityScopeType[3] memory kinds = [
            StreamFinalityScopeType.TOKEN,
            StreamFinalityScopeType.RELEASE,
            StreamFinalityScopeType.SEASON
        ];
        for (uint256 i; i < kinds.length; ++i) {
            Scoped.Publication memory p = _publicationV2(kinds[i], 0);
            _approve(p, keccak256(abi.encode("separate original consent", i)));
            bytes32 key = host.publishScoped(p);
            assertEq(host.scopedHead(p.scope), key);
            assertEq(host.scopedContentRootAggregate(1).revision, i + 1);
        }
        Scoped.Publication memory bad = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        bad.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidScopedContentRoot.selector));
        host.previewScoped(bad, address(this));
        bad.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(Scoped.InvalidScopedContentRoot.selector));
        host.previewScoped(bad, address(this));
        assertEq(host.scopedContentRootAggregate(1).revision, 3);
    }

    function testV2LateReprepareFailureRollsBackConsentHeadAndAggregateThenIdenticalRetry() public {
        Scoped.Publication memory p = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        bytes32 consent = keccak256("same exact retry approval");
        bytes32 expected = _approve(p, consent);
        bytes32 beforeFamily = host.family(1);
        bytes memory input = abi.encodeCall(host.publishScoped, (p));
        snapshots.setLateFailure(consent);
        (bool ok,) = address(host).call(input);
        assertTrue(!ok);
        assertTrue(!host.consumedArtistContentConsent(consent));
        assertEq(host.scopedHead(p.scope), bytes32(0));
        assertEq(host.scopedContentRootAggregate(1).revision, 0);
        assertEq(host.family(1), beforeFamily);
        snapshots.setLateFailure(0);
        bytes memory result;
        (ok, result) = address(host).call(input);
        assertTrue(ok);
        bytes32 key = abi.decode(result, (bytes32));
        assertEq(host.scopedHead(p.scope), key);
        assertEq(host.family(1), expected);
        assertTrue(host.consumedArtistContentConsent(consent));
        p.expectedPredecessor = key;
        _approve(p, consent);
        vm.expectRevert(
            abi.encodeWithSelector(Authorization.ArtistContentConsentConsumed.selector, consent)
        );
        host.publishScoped(p);
        assertEq(host.scopedContentRootAggregate(1).revision, 1);
    }

    function testV2CurrentFailureCannotRewriteRetainedOriginalBindingOrReceipt() public {
        Scoped.Publication memory p = _publicationV2(StreamFinalityScopeType.RELEASE, 0);
        _approve(p, keccak256("retained before drift"));
        bytes32 key = host.publishScoped(p);
        bytes32 saved = keccak256(
            abi.encode(
                host.scopedRecord(key), host.scopedBinding(key), host.scopedContentRootAggregate(1)
            )
        );
        p.expectedPredecessor = key;
        for (uint8 fault = 1; fault <= 4; ++fault) {
            snapshots.setCurrentFault(fault);
            _invalid(p);
            assertEq(
                keccak256(
                    abi.encode(
                        host.scopedRecord(key),
                        host.scopedBinding(key),
                        host.scopedContentRootAggregate(1)
                    )
                ),
                saved
            );
            snapshots.setCurrentFault(0);
        }
        host.previewScoped(p, address(this));
    }

    function testV2RequiresAllFiveActualActiveDefinitionsAndExactRuntimePins() public {
        Scoped.Publication memory p = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        bytes32[5] memory ids = [
            FamilyOutputDocuments.SCHEMA,
            FamilyOutputDocuments.CANON,
            FamilyOutputDocuments.LEAF_SCHEMA,
            FamilyRootDocuments.ROOT_SCHEMA,
            FamilyRootDocuments.ROOT_CANON
        ];
        for (uint256 i; i < ids.length; ++i) {
            calls.mockCallRevert(
                address(schemas),
                abi.encodeWithSignature("documentFacts(bytes32)", ids[i]),
                abi.encodeWithSignature("Error(string)", "unavailable exact definition")
            );
            _invalid(p);
            calls.clearMockedCalls();
        }
        PreservationSnapshot.Dependencies memory d = snapshots.dependencies();
        for (uint256 i; i < d.targets.length; ++i) {
            snapshots.setDependencyPin(i, keccak256(abi.encode("incorrect original pin", i)));
            _invalid(p);
            snapshots.setDependencyPin(i, d.codeHashes[i]);
        }
        host.previewScoped(p, address(this));
        assertEq(host.scopedContentRootAggregate(1).revision, 0);
    }

    function testV1AndV2ShareOriginalScopeHeadWithoutRelabelingRetainedHistory() public {
        PreservationScopedSnapshotBoundary oldSnapshots = new PreservationScopedSnapshotBoundary(
            address(core), address(metadata), address(host), address(schemas), address(store)
        );
        PreservationScopedProviderBoundary oldProvider = new PreservationScopedProviderBoundary(
            address(metadata),
            address(schemas),
            address(preservationManifest),
            address(oldSnapshots),
            address(oldSnapshots)
        );
        _register(
            "STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            ScopedDocuments.document(ScopedDocuments.ROOT_SCHEMA),
            schemas.RAW_BYTES()
        );
        _register(
            "STREAM_ABI_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            ScopedDocuments.document(ScopedDocuments.ROOT_CANON),
            schemas.RAW_BYTES()
        );
        _selectScoped(address(oldProvider));
        Scoped.Publication memory p;
        p.scope = _scope(StreamFinalityScopeType.TOKEN);
        p.snapshotRecordHash = oldSnapshots.install(p.scope, 0);
        p.snapshotRevision = 1;
        p.manifestURI = "ipfs://old-original";
        _approve(p, keccak256("V1 original consent"));
        bytes32 first = host.publishScoped(p);
        bytes32 retained =
            keccak256(abi.encode(host.scopedRecord(first), host.scopedBinding(first)));
        assertEq(
            host.scopedBinding(first).preservationOutputProfile, ProducerFamily.ORIGINAL_PROFILE
        );
        _selectScoped(address(familyProvider));
        Scoped.Publication memory second = _publicationV2(StreamFinalityScopeType.TOKEN, 0);
        _invalid(second); // The V2 family does not reset the original head.
        second.expectedPredecessor = first;
        _approve(second, keccak256("V2 successor consent"));
        bytes32 key = host.publishScoped(second);
        assertEq(host.scopedHead(second.scope), key);
        assertEq(host.scopedContentRootAggregate(1).revision, 2);
        assertEq(host.scopedBinding(key).preservationOutputProfile, ProducerFamily.FAMILY_PROFILE);
        assertEq(
            keccak256(abi.encode(host.scopedRecord(first), host.scopedBinding(first))), retained
        );
    }

    function _selectScoped(address provider_) private {
        scopedFinality = new ScopedRootFinalityBoundary(
            address(core), address(artist), address(metadata), provider_, preservationArtifacts
        );
        artist.configure(address(host), address(scopedFinality));
        core.setPointer(keccak256("ARTWORK_FINALITY_REGISTRY"), address(scopedFinality));
    }

    function _scope(StreamFinalityScopeType kind)
        private
        pure
        returns (StreamFinalityScope memory)
    {
        return kind == StreamFinalityScopeType.TOKEN
            ? StreamFinalityScope(kind, 1, 91, 0)
            : StreamFinalityScope(kind, 1, 0, keccak256(abi.encode("scope", kind)));
    }

    function _publicationV2(StreamFinalityScopeType kind, uint8 malformed)
        private
        returns (Scoped.Publication memory p)
    {
        p.scope = _scope(kind);
        p.snapshotRecordHash = snapshots.install(p.scope, malformed);
        p.snapshotRevision = 1;
        p.manifestURI = "ipfs://scoped-family-root";
    }

    function _approve(Scoped.Publication memory p, bytes32 consent)
        private
        returns (bytes32 expected)
    {
        expected = host.previewScoped(p, address(this));
        artist.approve(expected, consent);
    }

    function _invalid(Scoped.Publication memory p) private {
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.previewScoped, (p, address(this))));
        assertTrue(!ok);
    }

    function _route(StreamFinalityScope memory scope) private view returns (bytes32) {
        address[6] memory targets = [
            address(core),
            address(artist),
            address(host),
            address(scopedFinality),
            address(familyProvider),
            address(snapshots)
        ];
        bytes32[6] memory hashes;
        for (uint256 i; i < targets.length; ++i) {
            hashes[i] = targets[i].codehash;
        }
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V2"),
                block.chainid,
                targets,
                hashes,
                address(metadata),
                address(metadata).codehash,
                scope
            )
        );
    }

    function _append(Scoped.Aggregate memory prior, Scoped.Publication memory p, bytes32 stateHash)
        private
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                block.chainid,
                address(host),
                address(core),
                uint256(1),
                prior.transitionChain,
                prior.revision + 1,
                StreamMetadataSubjects.scopeSubject(block.chainid, address(core), p.scope),
                p.expectedPredecessor,
                stateHash
            )
        );
    }
}
