// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../helpers/StaticMetadataRoutingFixture.sol";
import {
    ScopedRootSnapshotBoundary,
    ScopedRootProviderBoundary,
    ScopedRootFinalityBoundary
} from "./StreamScopedContentRootPublication.t.sol";
import {
    RootCheckpointBoundary,
    RootArtifactsBoundary,
    RootManifestBoundary
} from "./StreamContentRootPublication.t.sol";
import {
    IStreamScopedContentRootPublication as RootPublication
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as PolicyRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2 as Provider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as PolicySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as Definitions
} from "../../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as Schemas
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as Outputs
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamContentRootSchemas as OriginalSchemas
} from "../../../smart-contracts/domains/finality/StreamContentRootSchemas.sol";
import {
    StreamMetadataSubjects
} from "../../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as SnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    StreamFinalityRouterEvidence as Evidence
} from "../../../smart-contracts/domains/finality/StreamFinalityRouterEvidence.sol";
import {
    StreamMetadataContentAuthorization as Authorization
} from "../../../smart-contracts/domains/metadata/StreamMetadataContentAuthorization.sol";
import {
    IStreamWorkRecordSelection
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamWorkRecordSelection.sol";

contract ScopedPolicyRootDependencyBoundary {
    function boundary() external pure returns (bytes32) {
        return keccak256("already validated snapshot dependency");
    }
}

/// @dev An explicitly already-validated snapshot boundary, NOT the snapshot producer.
/// Membership, rendering, policy inventory and factory semantics are covered by the sibling
/// actual V2 snapshot suite. Here every retained ABI/hash/payload and live runtime pin is real;
/// currentFault models the validator refusing membership/factory/currentness at its fixed call.
contract ScopedPolicyRootValidatedSnapshotBoundary {
    bytes32 private constant PROFILE = keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");
    address public immutable core;
    address public immutable metadataHost;
    address public immutable router;
    address public immutable factory;
    PolicySnapshot.Dependencies private deps;
    mapping(bytes32 => PolicySnapshot.Publication) private publications;
    mapping(bytes32 => PolicySnapshot.Receipt) private receipts;
    mapping(bytes32 => bytes) private payloads;
    uint8 public currentFault;
    bool public profileValid = true;
    bool public interfaceValid = true;
    bytes32 public rejectConsumed;

    constructor(address c, address m, address r, address schemas, address store) {
        core = c;
        metadataHost = m;
        router = r;
        factory = address(new ScopedPolicyRootDependencyBoundary());
        deps.targets[0] = c;
        deps.targets[1] = m;
        deps.targets[2] = schemas;
        deps.targets[3] = store;
        deps.targets[4] = r;
        for (uint256 i = 5; i < 11; ++i) {
            deps.targets[i] = address(new ScopedPolicyRootDependencyBoundary());
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
        return interfaceValid && (id == type(Snap).interfaceId || id == 0x01ffc9a7);
    }

    function scopedPolicySnapshotProfile() external view returns (bytes32) {
        return profileValid ? PROFILE : keccak256("wrong snapshot profile");
    }

    function dependencies() external view returns (PolicySnapshot.Dependencies memory) {
        return deps;
    }

    function setDependencyPin(uint256 index, bytes32 value) external {
        deps.codeHashes[index] = value;
    }

    function setProfile(bool value) external {
        profileValid = value;
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
        PolicySnapshot.Source memory source;
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
        source.sourceFactory = factory;
        source.sourceFactoryCodeHash = factory.codehash;
        source.factoryDependenciesHash = keccak256("factory dependencies");
        if (malformed == 1) source.sourceFactoryCodeHash = keccak256("wrong factory runtime");
        if (malformed == 4) source.scope.tokenId = 92;
        if (malformed == 5) source.artist.bindingHash = keccak256("different accepted binding");
        if (malformed == 6) source.outputs.policyChainHash = 0;
        return _retain(scope, source, malformed);
    }

    function _retain(
        StreamFinalityScope memory scope,
        PolicySnapshot.Source memory source,
        uint8 malformed
    ) private returns (bytes32 key) {
        PolicySnapshot.Publication memory p;
        p.scope = scope;
        p.snapshotId = keccak256(abi.encode("snapshot V2", scope, malformed));
        p.outputManifestRecord = source.outputs.manifestHash;
        p.coordinatorInventoryPlan = source.outputs.inventoryHash;
        p.manifestURI = "ipfs://snapshot-v2";
        p.effectiveAt = uint64(block.timestamp);
        p.reasonHash = keccak256("snapshot publication reason");
        PolicySnapshot.Receipt memory r;
        r.scopeSubject = StreamMetadataSubjects.scopeSubject(block.chainid, core, scope);
        r.revision = 1;
        r.publisher = address(this);
        r.authorizationClass = 7;
        r.grantRevision = 1;
        r.displayAuthorizationClass = 7;
        r.displayGrantRevision = 1;
        r.schemaHash = Definitions.SCHEMA_HASH;
        r.profileHash = Definitions.PROFILE_HASH;
        r.canonicalizationHash = Definitions.CANON_HASH;
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_SOURCES_V2"),
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
            keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_PAYLOAD_V2"),
            block.chainid,
            address(this),
            deps.targets,
            deps.codeHashes,
            p,
            r,
            source
        );
        p.expectedSourceHash = r.sourceHash;
        r.manifestHash = keccak256(raw);
        r.manifestBytes = uint32(raw.length);
        r.recordedAt = uint64(block.timestamp);
        key = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
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
                keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_CHAIN_V2"),
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
        returns (PolicySnapshot.Publication memory, PolicySnapshot.Receipt memory)
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
        returns (PolicySnapshot.Receipt memory r)
    {
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
                !StreamMetadataRouter(router).consumedArtistContentConsent(rejectConsumed),
                "late snapshot failure"
            );
        }
        if (currentFault == 3) ++r.grantRevision;
    }
}

contract ScopedPolicyRootProviderBoundary is ScopedRootProviderBoundary {
    address private immutable policySnapshots;
    bytes32 private immutable policySnapshotHash;
    bool public profileValid = true;
    bool public interfaceValid = true;

    constructor(address m, address s, address l, address oldSnapshots, address snapshots)
        ScopedRootProviderBoundary(m, s, l, oldSnapshots)
    {
        policySnapshots = snapshots;
        policySnapshotHash = snapshots.codehash;
    }

    function supportsInterface(bytes4 id) external view returns (bool) {
        return interfaceValid && (id == type(Provider).interfaceId || id == 0x01ffc9a7);
    }

    function scopedPolicySnapshotProfile() external view returns (bytes32) {
        return profileValid ? keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2") : bytes32(0);
    }

    function scopedPolicySnapshotHost(StreamFinalityScope calldata)
        external
        view
        returns (address)
    {
        return policySnapshots;
    }

    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata)
        external
        view
        returns (bytes32)
    {
        return policySnapshotHash;
    }

    function scopedPolicySnapshotValidationGas(StreamFinalityScope calldata)
        external
        pure
        returns (uint256)
    {
        return 5000000;
    }

    function setProfile(bool value) external {
        profileValid = value;
    }

    function setInterface(bool value) external {
        interfaceValid = value;
    }
}

/// @notice Real Router, Metadata grants, schema documents, Store and 2-of-2 upstream Safe.
/// @dev Core/Artist approval, finality route and already-validated snapshots are named boundaries.
/// This host tests root adoption, not real Artist op17 or a complete finality/snapshot ceremony.
contract StreamScopedPolicyContentRootV2Test is StaticMetadataRoutingFixture {
    // Typed declarations let the compiler produce the canonical struct event signatures.
    event ScopedContentRootPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        RootPublication.Record record,
        RootPublication.Aggregate collectionAggregate
    );
    event ScopedPolicyContentRootBindingPublished(
        uint16 schemaVersion,
        uint256 indexed collectionId,
        bytes32 indexed scopeSubject,
        bytes32 indexed recordHash,
        PolicyRoot.Binding binding
    );
    StaticRouteVm private constant mockVm =
        StaticRouteVm(address(uint160(uint256(keccak256("hevm cheat code")))));
    bytes32 private constant ROOT = keccak256("CONTENT_ROOT");
    ScopedRootSnapshotBoundary private oldSnapshots;
    ScopedPolicyRootValidatedSnapshotBoundary private snapshots;
    ScopedPolicyRootProviderBoundary private provider;
    ScopedRootFinalityBoundary private finality;

    function setUp() public override {
        super.setUp();
        vm.warp(1000);
        _activate();
        _mint();
        oldSnapshots =
            new ScopedRootSnapshotBoundary(address(core), address(metadata), address(router));
        snapshots = new ScopedPolicyRootValidatedSnapshotBoundary(
            address(core),
            address(metadata),
            address(router),
            address(schemas),
            schemas.chunkStore()
        );
        address cp = address(new RootCheckpointBoundary(address(core), address(router)));
        address artifacts = address(new RootArtifactsBoundary(address(schemas)));
        address manifest = address(new RootManifestBoundary(address(core), cp, artifacts));
        provider = new ScopedPolicyRootProviderBoundary(
            address(metadata), address(schemas), manifest, address(oldSnapshots), address(snapshots)
        );
        finality = new ScopedRootFinalityBoundary(
            address(core), address(artist), address(metadata), address(provider), artifacts
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
        _documents();
    }

    function testV1V2V1KeepsOneScopeLineageAggregateAndOriginalConsentEvolution() public {
        _ratifyCurrent();
        (, bytes32 legacy) = router.artistContentFamilyState(1, ROOT);
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        RootPublication.Publication memory old =
            abi.decode(abi.encode(p), (RootPublication.Publication));
        old.snapshotRecordHash = keccak256("original snapshot");
        oldSnapshots.install(old.scope, old.snapshotRecordHash);
        bytes32 firstConsent = keccak256("V1 first");
        bytes32 first = _publishOld(old, firstConsent);
        RootPublication.Record memory firstRecord = router.scopedContentRootRecord(first);
        RootPublication.Aggregate memory one = router.scopedContentRootAggregate(1);
        _assertAggregate(one, RootPublication.Aggregate(0, 0), firstRecord, legacy);
        _assertLeaf(old.scope, OriginalSchemas.LEAF_SCHEMA);
        p.expectedPredecessor = first;
        bytes32 secondConsent = keccak256("V2 second");
        bytes32 second = _publish(p, secondConsent);
        RootPublication.Record memory secondRecord = router.scopedContentRootRecord(second);
        RootPublication.Aggregate memory two = router.scopedContentRootAggregate(1);
        _assertAggregate(two, one, secondRecord, legacy);
        _assertLeaf(p.scope, Outputs.LEAF_SCHEMA);
        old.expectedPredecessor = second;
        bytes32 thirdConsent = keccak256("V1 third");
        bytes32 third = _publishOld(old, thirdConsent);
        _assertAggregate(
            router.scopedContentRootAggregate(1), two, router.scopedContentRootRecord(third), legacy
        );
        _assertLeaf(old.scope, OriginalSchemas.LEAF_SCHEMA);
        require(router.scopedContentRootHead(p.scope) == third);
        require(router.scopedContentRootAggregate(1).revision == 3);
        require(
            router.consumedArtistContentConsent(firstConsent)
                && router.consumedArtistContentConsent(secondConsent)
                && router.consumedArtistContentConsent(thirdConsent)
        );
        require(
            keccak256(abi.encode(router.scopedContentRootRecord(first)))
                == keccak256(abi.encode(firstRecord))
        );
        require(
            keccak256(abi.encode(router.scopedContentRootRecord(second)))
                == keccak256(abi.encode(secondRecord))
        );
        require(
            router.scopedPolicyContentRootBinding(first).profileId == 0
                && router.scopedPolicyContentRootBinding(third).profileId == 0
        );
        require(router.scopedPolicyContentRootBinding(second).profileId == Schemas.PROFILE);
        vm.expectRevert(
            abi.encodeWithSelector(RootPublication.ScopedContentRootLineage.selector, first, third)
        );
        router.previewScopedPolicyContentRootPublication(p, address(this));
    }

    function testSchema2BindingEventsAndLiteralRootHashPreimages() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        _assertSnapshot(p);
        bytes32 consent = keccak256("literal root");
        vm.recordLogs();
        bytes32 hash = _publish(p, consent);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        RootPublication.Record memory r = router.scopedContentRootRecord(hash);
        PolicyRoot.Binding memory b = router.scopedPolicyContentRootBinding(hash);
        RootPublication.Aggregate memory a = router.scopedContentRootAggregate(1);
        require(
            hash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(router),
                        address(core),
                        r,
                        b,
                        a
                    )
                )
        );
        _assertEvents(logs, hash, r, b, a);
        _assertBinding(b, p);
        bytes32 stateHash = r.stateHash;
        r.stateHash = 0;
        r.artistConsent = 0;
        r.publishedAt = 0;
        require(
            stateHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2"),
                        block.chainid,
                        address(router),
                        address(core),
                        r,
                        b
                    )
                )
        );
        address[6] memory targets = [
            address(core),
            address(artist),
            address(router),
            address(finality),
            address(provider),
            address(snapshots)
        ];
        bytes32[6] memory pins;
        for (uint256 i; i < targets.length; ++i) {
            pins[i] = targets[i].codehash;
        }
        require(
            r.routeHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2"),
                        block.chainid,
                        targets,
                        pins,
                        address(metadata),
                        address(metadata).codehash,
                        p.scope
                    )
                )
        );
        require(
            router.supportsInterface(type(RootPublication).interfaceId)
                && router.supportsInterface(type(PolicyRoot).interfaceId)
        );
    }

    function testReleaseSeasonIndependentHeadsStillConsumeOneCollectionFamily() public {
        RootPublication.Publication memory release =
            _publication(StreamFinalityScopeType.RELEASE, 0);
        RootPublication.Publication memory season = _publication(StreamFinalityScopeType.SEASON, 0);
        bytes32 stale = keccak256("season before release");
        bytes32 oldPreview = router.previewScopedPolicyContentRootPublication(season, address(this));
        bytes32 releaseHash = _publish(release, keccak256("release"));
        require(
            router.previewScopedPolicyContentRootPublication(season, address(this)) != oldPreview
        );
        artist.approve(1, ROOT, oldPreview, stale);
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        router.publishScopedPolicyContentRootPublication(season);
        require(
            !router.consumedArtistContentConsent(stale)
                && router.scopedContentRootHead(season.scope) == 0
        );
        bytes32 seasonHash = _publish(season, keccak256("season after release"));
        require(
            router.scopedContentRootHead(release.scope) == releaseHash
                && router.scopedContentRootHead(season.scope) == seasonHash
        );
        require(router.scopedContentRootAggregate(1).revision == 2);
    }

    function testUnknownStoredProfileFailsClosedWithoutChangingHistoricalBytes() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 hash = _publish(p, keccak256("profile corruption control"));
        bytes32 beforeRecord = keccak256(abi.encode(router.scopedContentRootRecord(hash)));
        bytes32 slot = keccak256(
            abi.encode(hash, keccak256("6529STREAM_STORAGE_SCOPED_POLICY_CONTENT_ROOT_V2"))
        );
        bytes32 saved = vm.load(address(router), slot);
        require(saved == Schemas.PROFILE, "exact companion profile slot");
        vm.store(address(router), slot, keccak256("unknown future profile"));
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.scopedContentRootHead(p.scope);
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.scopedTokenContentRoot(p.scope);
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.scopedPolicyContentRootBinding(hash);
        require(keccak256(abi.encode(router.scopedContentRootRecord(hash))) == beforeRecord);
        vm.store(address(router), slot, saved);
        _assertLeaf(p.scope, Outputs.LEAF_SCHEMA);
        require(router.scopedPolicyContentRootBinding(hash).profileId == saved);
        // TOKEN subject identity omits collectionId; V2 interpretation must still check
        // the full retained scope and refuse an alias through another collection.
        StreamFinalityScope memory wrongCollection =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 2, 91, 0);
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.scopedContentRootHead(wrongCollection);
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.scopedTokenContentRoot(wrongCollection);
        require(keccak256(abi.encode(router.scopedContentRootRecord(hash))) == beforeRecord);
    }

    function testEveryLiveDependencyPinAndFactoryPinIsRequired() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 valid = router.previewScopedPolicyContentRootPublication(p, address(this));
        PolicySnapshot.Dependencies memory d = snapshots.dependencies();
        for (uint256 i; i < 11; ++i) {
            require(d.targets[i].code.length != 0 && d.codeHashes[i] == d.targets[i].codehash);
            snapshots.setDependencyPin(i, keccak256("wrong runtime"));
            if (i == 0 || i == 1 || i == 4) {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        SnapshotReads.InvalidScopedPolicySnapshotEvidence.selector
                    )
                );
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        RootPublication.ScopedContentRootDependency.selector, d.targets[i]
                    )
                );
            }
            router.previewScopedPolicyContentRootPublication(p, address(this));
            snapshots.setDependencyPin(i, d.codeHashes[i]);
            require(router.previewScopedPolicyContentRootPublication(p, address(this)) == valid);
        }
        RootPublication.Publication memory bad = _publication(StreamFinalityScopeType.TOKEN, 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                RootPublication.ScopedContentRootDependency.selector, snapshots.factory()
            )
        );
        router.previewScopedPolicyContentRootPublication(bad, address(this));
        require(router.scopedContentRootAggregate(1).revision == 0);
    }

    function testProviderAndSnapshotProfilesAndInterfacesCannotDowngrade() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 expected = router.previewScopedPolicyContentRootPublication(p, address(this));
        provider.setProfile(false);
        _invalidPreview(p);
        provider.setProfile(true);
        provider.setInterface(false);
        _invalidPreview(p);
        provider.setInterface(true);
        snapshots.setProfile(false);
        _invalidPreview(p);
        snapshots.setProfile(true);
        snapshots.setInterface(false);
        _invalidPreview(p);
        snapshots.setInterface(true);
        require(router.previewScopedPolicyContentRootPublication(p, address(this)) == expected);
    }

    function testWrongScopeAndCanonicalPayloadJoinsAreRejectedAfterValidBaseline() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 expected = router.previewScopedPolicyContentRootPublication(p, address(this));
        p.scope.tokenId = 92;
        vm.expectRevert(
            abi.encodeWithSelector(SnapshotReads.InvalidScopedPolicySnapshotEvidence.selector)
        );
        router.previewScopedPolicyContentRootPublication(p, address(this));
        p.scope.tokenId = 91;
        bytes memory saved = snapshots.snapshotPayload(p.snapshotRecordHash);
        bytes memory changed = abi.encodePacked(saved);
        changed[changed.length - 1] ^= bytes1(uint8(1));
        snapshots.setPayload(p.snapshotRecordHash, changed);
        _invalidPreview(p);
        snapshots.setPayload(p.snapshotRecordHash, bytes.concat(saved, hex"00"));
        _invalidPreview(p);
        snapshots.setPayload(p.snapshotRecordHash, saved);
        for (uint8 fault = 2; fault <= 6; ++fault) {
            _invalidPreview(_publication(StreamFinalityScopeType.TOKEN, fault));
        }
        require(router.previewScopedPolicyContentRootPublication(p, address(this)) == expected);
        p.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        _invalidPreview(p);
        p.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        _invalidPreview(p);
        require(router.scopedContentRootAggregate(1).revision == 0);
    }

    function testValidatedMembershipFactoryAndExactCurrentReceiptAreRequired() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 valid = router.previewScopedPolicyContentRootPublication(p, address(this));
        for (uint8 fault = 1; fault <= 4; ++fault) {
            snapshots.setCurrentFault(fault);
            if (fault == 3) {
                vm.expectRevert(
                    abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector)
                );
            } else {
                vm.expectRevert(
                    abi.encodeWithSelector(
                        Evidence.RouterEvidenceRead.selector,
                        address(snapshots),
                        Snap.requireCurrent.selector
                    )
                );
            }
            router.previewScopedPolicyContentRootPublication(p, address(this));
            snapshots.setCurrentFault(0);
            require(router.previewScopedPolicyContentRootPublication(p, address(this)) == valid);
        }
    }

    function testSafePreAndPostConsentFailureRollBackAndIdenticalTransactionRetries() public {
        _ratifyCurrent();
        uint256[] memory keys = new uint256[](2);
        keys[0] = 0x6529;
        keys[1] = 0x6530;
        OfficialSafe account =
            createOfficialSafe(deploySafeComponents("1.4.1"), safeOwnerAddresses(keys), 2, 702);
        _rootGrant(address(account), 0, 8, true);
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 consent = keccak256("V2 safe consent");
        artist.approve(
            1, ROOT, router.previewScopedPolicyContentRootPublication(p, address(account)), consent
        );
        bytes memory input = abi.encodeCall(router.publishScopedPolicyContentRootPublication, (p));
        uint256 nonce = account.nonce();
        bytes memory signatures = safeThresholdSignature(
            keys,
            account.getTransactionHash(
                address(router), 0, input, 0, 0, 0, 0, address(0), address(0), nonce
            )
        );
        snapshots.setCurrentFault(1);
        _safeFailure(account, input, signatures, nonce, p, consent);
        snapshots.setCurrentFault(0);
        snapshots.setLateFailure(consent);
        _safeFailure(account, input, signatures, nonce, p, consent);
        snapshots.setLateFailure(0);
        require(
            account.execTransaction(
                address(router), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
            )
        );
        require(account.nonce() == nonce + 1 && router.consumedArtistContentConsent(consent));
        bytes32 hash = router.scopedContentRootHead(p.scope);
        RootPublication.Record memory r = router.scopedContentRootRecord(hash);
        require(
            r.publisher == address(account) && r.authorizationClass == 8
                && r.artistConsent == consent
        );
        require(
            router.scopedContentRootAggregate(1).revision == 1
                && router.scopedPolicyContentRootBinding(hash).profileId == Schemas.PROFILE
        );
    }

    function testCurrentFailureFreezeAndGrantChangesPreserveImmutableHistory() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        bytes32 hash = _publish(p, keccak256("historical V2"));
        bytes32 history = keccak256(
            abi.encode(
                router.scopedContentRootRecord(hash), router.scopedPolicyContentRootBinding(hash)
            )
        );
        p.expectedPredecessor = hash;
        bytes32 consent = keccak256("new root frozen");
        artist.approve(
            1, ROOT, router.previewScopedPolicyContentRootPublication(p, address(this)), consent
        );
        bytes32 subject = StreamMetadataSubjects.scopeSubject(block.chainid, address(core), p.scope);
        finality.setFreeze(StreamArtworkFreezeMode.INHERITED);
        vm.expectRevert(
            abi.encodeWithSelector(RootPublication.ScopedContentRootFrozen.selector, subject)
        );
        router.publishScopedPolicyContentRootPublication(p);
        finality.setFreeze(StreamArtworkFreezeMode.NONE);
        core.setFrozen(true);
        vm.expectRevert(
            abi.encodeWithSelector(RootPublication.ScopedContentRootFrozen.selector, subject)
        );
        router.publishScopedPolicyContentRootPublication(p);
        core.setFrozen(false);
        snapshots.setCurrentFault(4);
        vm.expectRevert(
            abi.encodeWithSelector(
                Evidence.RouterEvidenceRead.selector,
                address(snapshots),
                Snap.requireCurrent.selector
            )
        );
        router.publishScopedPolicyContentRootPublication(p);
        snapshots.setCurrentFault(0);
        _rootGrant(address(this), 1, 7, false);
        vm.expectRevert(
            abi.encodeWithSelector(
                RootPublication.ScopedContentRootAuthority.selector, address(this)
            )
        );
        router.publishScopedPolicyContentRootPublication(p);
        require(!router.consumedArtistContentConsent(consent));
        _rootGrant(address(this), 1, 7, true);
        // Real Registry retirement is another current-only failure; no document mock.
        require(router.previewScopedPolicyContentRootPublication(p, address(this)) != 0);
        (bytes32 s, bytes32 o, bytes32 n) = schemas.statusTransition(
            Schemas.ROOT_SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED
        );
        executor.execute(
            address(schemas),
            abi.encodeCall(
                schemas.setDocumentStatus,
                (Schemas.ROOT_SCHEMA, IStreamSchemaRegistry.DocumentStatus.DEPRECATED)
            ),
            s,
            o,
            n
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                IStreamWorkRecordSelection.WorkDefinitionUnavailable.selector, Schemas.ROOT_SCHEMA
            )
        );
        router.previewScopedPolicyContentRootPublication(p, address(this));
        require(
            keccak256(
                abi.encode(
                    router.scopedContentRootRecord(hash),
                    router.scopedPolicyContentRootBinding(hash)
                )
            ) == history
        );
        _assertLeaf(p.scope, Outputs.LEAF_SCHEMA);
        require(
            router.scopedContentRootHead(p.scope) == hash
                && router.scopedContentRootAggregate(1).revision == 1
        );
    }

    function testGrantPrecedenceAndRevisionArePartOfExactArtistApproval() public {
        RootPublication.Publication memory p = _publication(StreamFinalityScopeType.TOKEN, 0);
        _rootGrant(address(this), 0, 8, true);
        bytes32 class7 = router.previewScopedPolicyContentRootPublication(p, address(this));
        bytes32 stale = keccak256("old class7 grant");
        artist.approve(1, ROOT, class7, stale);
        _rootGrant(address(this), 1, 7, false);
        require(router.previewScopedPolicyContentRootPublication(p, address(this)) != class7);
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        router.publishScopedPolicyContentRootPublication(p);
        require(!router.consumedArtistContentConsent(stale));
        _rootGrant(address(this), 1, 7, true);
        require(router.previewScopedPolicyContentRootPublication(p, address(this)) != class7);
        bytes32 first = _publish(p, keccak256("new class7 grant"));
        RootPublication.Record memory r = router.scopedContentRootRecord(first);
        (bool enabled, uint64 revision) = metadata.familyWriter(
            1, keccak256("6529STREAM_RECORD_FAMILY_SNAPSHOT_V1"), 7, address(this)
        );
        require(enabled && r.authorizationClass == 7 && r.grantRevision == revision);
        _rootGrant(address(this), 1, 7, false);
        p.expectedPredecessor = first;
        bytes32 second = _publish(p, keccak256("global fallback"));
        require(router.scopedContentRootRecord(second).authorizationClass == 8);
    }

    function _assertEvents(
        Vm.Log[] memory actual,
        bytes32 hash,
        RootPublication.Record memory r,
        PolicyRoot.Binding memory b,
        RootPublication.Aggregate memory a
    ) private {
        bytes32 subject = StreamMetadataSubjects.scopeSubject(
            block.chainid, address(core), r.publication.scope
        );
        vm.recordLogs();
        emit ScopedContentRootPublished(2, 1, subject, hash, r, a);
        emit ScopedPolicyContentRootBindingPublished(2, 1, subject, hash, b);
        Vm.Log[] memory expected = vm.getRecordedLogs();
        require(expected.length == 2);
        for (uint256 j; j < expected.length; ++j) {
            uint256 found;
            for (uint256 i; i < actual.length; ++i) {
                if (
                    actual[i].emitter == address(router)
                        && keccak256(abi.encode(actual[i].topics))
                            == keccak256(abi.encode(expected[j].topics))
                        && keccak256(actual[i].data) == keccak256(expected[j].data)
                ) ++found;
            }
            require(found == 1, "exact schema2 topic0/indexed/data bytes");
        }
    }

    function _ratifyCurrent() private {
        mockVm.mockCall(
            address(artist),
            abi.encodeWithSignature("firstReleaseRatification(uint256)", 1),
            abi.encode(true, router.artistContentFreezeState(1), keccak256("original ratification"))
        );
    }

    function _safeFailure(
        OfficialSafe account,
        bytes memory input,
        bytes memory signatures,
        uint256 nonce,
        RootPublication.Publication memory p,
        bytes32 consent
    ) private {
        (, bytes32 beforeFamily) = router.artistContentFamilyState(1, ROOT);
        vm.expectRevert(abi.encodeWithSignature("Error(string)", "GS013"));
        account.execTransaction(
            address(router), 0, input, 0, 0, 0, 0, address(0), payable(address(0)), signatures
        );
        require(account.nonce() == nonce && !router.consumedArtistContentConsent(consent));
        require(
            router.scopedContentRootHead(p.scope) == 0
                && router.scopedContentRootAggregate(1).revision == 0
        );
        (, bytes32 afterFamily) = router.artistContentFamilyState(1, ROOT);
        require(beforeFamily == afterFamily);
    }

    function _assertSnapshot(RootPublication.Publication memory p) private view {
        PolicySnapshot.Dependencies memory d = snapshots.dependencies();
        require(abi.encode(d).length == 832);
        (PolicySnapshot.Publication memory original, PolicySnapshot.Receipt memory receipt) =
            snapshots.snapshotRecord(p.snapshotRecordHash);
        require(abi.encode(receipt).length == 544);
        require(
            keccak256(abi.encode(receipt))
                == keccak256(
                    abi.encode(
                        snapshots.requireCurrent(p.scope, p.snapshotRecordHash, p.snapshotRevision)
                    )
                )
        );
        bytes32 key = receipt.recordHash;
        receipt.recordHash = 0;
        receipt.chainHash = 0;
        require(
            key
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_RECORD_V2"),
                        block.chainid,
                        address(snapshots),
                        address(core),
                        address(metadata),
                        original,
                        receipt
                    )
                )
        );
        require(receipt.manifestHash == keccak256(snapshots.snapshotPayload(key)));
    }

    function _assertBinding(PolicyRoot.Binding memory b, RootPublication.Publication memory p)
        private
        view
    {
        PolicySnapshot.Dependencies memory d = snapshots.dependencies();
        (, PolicySnapshot.Receipt memory r) = snapshots.snapshotRecord(p.snapshotRecordHash);
        require(
            b.profileId == Schemas.PROFILE && b.sourceFactory == snapshots.factory()
                && b.sourceFactoryCodeHash == snapshots.factory().codehash
        );
        require(b.outputManifest == d.targets[8] && b.outputManifestCodeHash == d.codeHashes[8]);
        require(b.checkpoint == d.targets[7] && b.checkpointCodeHash == d.codeHashes[7]);
        require(
            b.entropySourceSet == d.targets[10] && b.entropySourceSetCodeHash == d.codeHashes[10]
        );
        require(
            b.checkpointHash == keccak256("checkpoint")
                && b.checkpointStateHash == keccak256("checkpoint state")
        );
        require(
            b.inventoryHash == keccak256("complete inventory")
                && b.policyChainHash == keccak256("complete policy chain")
                && b.outputRoot == keccak256("output root")
        );
        require(b.factoryDependenciesHash == keccak256("factory dependencies"));
        require(
            b.outputSchemaHash == keccak256(Schemas.document(Outputs.SCHEMA))
                && b.outputCanonicalizationHash == keccak256(Schemas.document(Outputs.CANON))
        );
        require(
            b.leafSchemaHash == keccak256(Schemas.document(Outputs.LEAF_SCHEMA))
                && b.rootSchemaHash == keccak256(Schemas.document(Schemas.ROOT_SCHEMA))
                && b.rootCanonicalizationHash == keccak256(Schemas.document(Schemas.ROOT_CANON))
        );
        require(
            b.snapshotSchemaHash == r.schemaHash && b.snapshotProfileHash == r.profileHash
                && b.snapshotCanonicalizationHash == r.canonicalizationHash
        );
    }

    function _assertAggregate(
        RootPublication.Aggregate memory actual,
        RootPublication.Aggregate memory prior,
        RootPublication.Record memory r,
        bytes32 legacy
    ) private view {
        require(actual.revision == prior.revision + 1);
        require(
            actual.transitionChain
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1"),
                        block.chainid,
                        address(router),
                        address(core),
                        uint256(1),
                        prior.transitionChain,
                        actual.revision,
                        StreamMetadataSubjects.scopeSubject(
                            block.chainid, address(core), r.publication.scope
                        ),
                        r.publication.expectedPredecessor,
                        r.stateHash
                    )
                )
        );
        (, bytes32 family) = router.artistContentFamilyState(1, ROOT);
        require(
            family
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                        block.chainid,
                        address(router),
                        address(core),
                        uint256(1),
                        legacy,
                        actual
                    )
                )
        );
    }

    function _assertLeaf(StreamFinalityScope memory scope, bytes32 schema) private view {
        (bytes32 root, uint64 count, bytes32 actual) = router.scopedTokenContentRoot(scope);
        RootPublication.Record memory r =
            router.scopedContentRootRecord(router.scopedContentRootHead(scope));
        require(root == r.contentRoot && count == 1 && actual == schema);
    }

    function _invalidPreview(RootPublication.Publication memory p) private {
        vm.expectRevert(abi.encodeWithSelector(RootPublication.InvalidScopedContentRoot.selector));
        router.previewScopedPolicyContentRootPublication(p, address(this));
    }

    function _publication(StreamFinalityScopeType kind, uint8 malformed)
        private
        returns (RootPublication.Publication memory p)
    {
        p.scope = kind == StreamFinalityScopeType.TOKEN
            ? StreamFinalityScope(kind, 1, 91, 0)
            : StreamFinalityScope(kind, 1, 0, keccak256(abi.encode("scope", kind)));
        p.snapshotRecordHash = snapshots.install(p.scope, malformed);
        p.snapshotRevision = 1;
        p.manifestURI = "ipfs://scoped-root-v2";
    }

    function _publish(RootPublication.Publication memory p, bytes32 consent)
        private
        returns (bytes32)
    {
        bytes32 expected = router.previewScopedPolicyContentRootPublication(p, address(this));
        artist.approve(1, ROOT, expected, consent);
        bytes32 hash = router.publishScopedPolicyContentRootPublication(p);
        (, bytes32 actual) = router.artistContentFamilyState(1, ROOT);
        require(actual == expected && router.consumedArtistContentConsent(consent));
        return hash;
    }

    function _publishOld(RootPublication.Publication memory p, bytes32 consent)
        private
        returns (bytes32)
    {
        bytes32 expected = router.previewScopedContentRootPublication(p, address(this));
        artist.approve(1, ROOT, expected, consent);
        bytes32 hash = router.publishScopedContentRootPublication(p);
        (, bytes32 actual) = router.artistContentFamilyState(1, ROOT);
        require(actual == expected && router.consumedArtistContentConsent(consent));
        return hash;
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

    function _documents() private {
        _document(
            "RAW_BYTES",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            bytes(schemas.RAW_BYTES_DEFINITION())
        );
        _document(
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Schemas.document(Outputs.SCHEMA)
        );
        _document(
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Schemas.document(Outputs.CANON)
        );
        _document(
            "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Schemas.document(Outputs.LEAF_SCHEMA)
        );
        _document(
            "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            IStreamSchemaRegistry.DocumentKind.SCHEMA,
            Schemas.document(Schemas.ROOT_SCHEMA)
        );
        _document(
            "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            IStreamSchemaRegistry.DocumentKind.CANONICALIZATION,
            Schemas.document(Schemas.ROOT_CANON)
        );
    }

    function _document(
        string memory name,
        IStreamSchemaRegistry.DocumentKind kind,
        bytes memory raw
    ) private {
        StreamSchemaDocumentStore store = StreamSchemaDocumentStore(schemas.chunkStore());
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
