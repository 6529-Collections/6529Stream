// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreservationPolicyContentRootV1.t.sol";
import {
    ScopedRootProviderBoundary,
    ScopedRootFinalityBoundary
} from "./StreamScopedContentRootPublication.t.sol";
import {
    ScopedPolicyRootValidatedSnapshotBoundary,
    ScopedPolicyRootProviderBoundary
} from "./StreamScopedPolicyContentRootV2.t.sol";
import {
    IStreamScopedPreservationPolicySnapshotPublicationV1 as PreservationSnap
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPreservationPolicySnapshotPublicationV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1 as ScopedProvider
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    StreamScopedPreservationPolicySnapshotTypesV1 as PreservationSnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamScopedPreservationPolicySnapshotTypesV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV1 as SnapshotDefinitions
} from "../../../smart-contracts/domains/records/StreamScopedPreservationPolicySnapshotDefinitionsV1.sol";
import {
    StreamScopedPreservationPolicyContentRootSchemasV1 as ScopedDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPreservationPolicyContentRootSchemasV1.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as OldScopedRoot
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as OldScopedDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as OldOutputDocuments
} from "../../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as PreservationSnapshotReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";

contract PreservationScopedDependencyBoundary {
    function boundary() external pure returns (bytes32) {
        return keccak256("already validated snapshot dependency");
    }
}

/// @dev An explicitly already-validated preservation snapshot boundary, NOT the snapshot producer.
/// Membership, rendering, policy inventory and factory semantics are covered by the sibling
/// separate actual snapshot suite. Here every retained ABI/hash/payload and live runtime pin is real;
/// currentFault models the validator refusing membership/factory/currentness at its fixed call.
contract PreservationScopedSnapshotBoundary {
    bytes32 private constant PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1");
    address public immutable core;
    address public immutable metadataHost;
    address public immutable router;
    address public immutable factory;
    PreservationSnapshot.Dependencies private deps;
    mapping(bytes32 => PreservationSnapshot.Publication) private publications;
    mapping(bytes32 => PreservationSnapshot.Receipt) private receipts;
    mapping(bytes32 => bytes) private payloads;
    uint8 public currentFault;
    bool public profileValid = true;
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
        return profileValid ? PROFILE : keccak256("wrong snapshot profile");
    }

    function dependencies() external view returns (PreservationSnapshot.Dependencies memory) {
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
        source.outputs.preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
        source.content.preservationProfile = keccak256("6529STREAM_PRESERVATION_RENDER_V1");
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
        r.schemaHash =
            malformed == 12 ? keccak256("old snapshot schema") : SnapshotDefinitions.SCHEMA_HASH;
        r.profileHash = SnapshotDefinitions.PROFILE_HASH;
        r.canonicalizationHash = SnapshotDefinitions.CANON_HASH;
        r.sourceHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_SOURCES_V1"),
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
            keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_PAYLOAD_V1"),
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
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_RECORD_V1"),
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
                keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_CHAIN_V1"),
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

contract PreservationScopedProviderBoundary is ScopedRootProviderBoundary {
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
        return interfaceValid && (id == type(ScopedProvider).interfaceId || id == 0x01ffc9a7);
    }

    function scopedPreservationPolicySnapshotProfile() external view returns (bytes32) {
        return
            profileValid
                ? keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_SNAPSHOT_V1")
                : bytes32(0);
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
        profileValid = value;
    }

    function setInterface(bool value) external {
        interfaceValid = value;
    }
}

/// @notice Actual new scoped worker, original authorization/state/aggregate and real Metadata
/// grants/Schema/Store. Snapshot bytes are constructed at an explicitly already-validated boundary;
/// these tests do not claim actual Artist signatures, rendering, snapshot production or finality.
contract StreamScopedPreservationPolicyContentRootV1Test is PreservationRootWorkerFixture {
    PreservationScopedSnapshotBoundary private snapshots;
    address private scopedProvider;
    ScopedRootFinalityBoundary private scopedFinality;

    function setUp() public override {
        super.setUp();
        snapshots = new PreservationScopedSnapshotBoundary(
            address(core), address(metadata), address(host), address(schemas), address(store)
        );
        scopedProvider = address(
            new PreservationScopedProviderBoundary(
                address(metadata),
                address(schemas),
                address(preservationManifest),
                address(snapshots),
                address(snapshots)
            )
        );
        _selectScoped(scopedProvider);
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
    }

    function testSnapshotBeforeScopedRootFullTupleLiteralHashesAndEvents() public {
        StreamFinalityScope memory scope = _scope(StreamFinalityScopeType.TOKEN);
        Scoped.Publication memory p =
            Scoped.Publication(scope, 0, keccak256("not retained"), 1, "ipfs://root");
        _invalidScoped(p);
        assertEq(host.scopedHead(scope), bytes32(0));
        p.snapshotRecordHash = snapshots.install(scope, 0);
        (
            PreservationSnapshot.Publication memory original,
            PreservationSnapshot.Receipt memory receipt
        ) = snapshots.snapshotRecord(p.snapshotRecordHash);
        bytes memory payload = snapshots.snapshotPayload(p.snapshotRecordHash);
        assertEq(keccak256(payload), receipt.manifestHash);
        assertEq(original.expectedSourceHash, receipt.sourceHash);
        bytes32 consent = keccak256("snapshot then original op17");
        bytes32 expected = _approveScoped(p, consent);
        vm.recordLogs();
        bytes32 key = host.publishScoped(p);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        Scoped.Record memory r = host.scopedRecord(key);
        ScopedPreservation.Binding memory b = host.scopedBinding(key);
        Scoped.Aggregate memory a = host.scopedContentRootAggregate(1);
        assertEq(abi.encode(b).length, 800);
        assertEq(b.metadataRouter, address(host));
        assertEq(b.preservationOutputProfile, keccak256("6529STREAM_PRESERVATION_RENDER_V1"));
        assertEq(abi.encode(r.publication), abi.encode(p));
        assertEq(r.snapshotManifestHash, receipt.manifestHash);
        assertEq(r.snapshotSourceHash, receipt.sourceHash);
        assertEq(b.snapshotSchemaHash, receipt.schemaHash);
        assertEq(b.sourceFactory, snapshots.factory());
        assertEq(
            key,
            keccak256(
                abi.encode(
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1"),
                    block.chainid,
                    address(host),
                    address(core),
                    r,
                    b,
                    a
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
                    keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1"),
                    block.chainid,
                    address(host),
                    address(core),
                    blank,
                    b
                )
            )
        );
        assertEq(a.revision, 1);
        assertEq(a.transitionChain, _append(Scoped.Aggregate(0, 0), p, r.stateHash));
        assertEq(host.family(1), expected);
        assertEq(host.scopedHead(scope), key);
        assertTrue(host.consumedArtistContentConsent(consent));
        assertEq(logs.length, 3);
        assertEq(logs[0].emitter, address(host));
        assertEq(logs[0].data, abi.encode(uint16(3), r, a));
        assertEq(logs[1].data, abi.encode(uint16(1), b));
        snapshots.setCurrentFault(1);
        _invalidScoped(p);
        assertEq(abi.encode(host.scopedRecord(key)), abi.encode(r));
        assertEq(abi.encode(host.scopedBinding(key)), abi.encode(b));
        assertEq(abi.encode(host.scopedContentRootAggregate(1)), abi.encode(a));
    }

    function testScopedCanonicalPayloadRouterProfileFactoryAndArtistJoins() public {
        Scoped.Publication memory p = _scopedPublication(StreamFinalityScopeType.TOKEN, 0);
        host.previewScoped(p, address(this));
        for (uint8 malformed = 1; malformed <= 13; ++malformed) {
            Scoped.Publication memory bad = abi.decode(abi.encode(p), (Scoped.Publication));
            bad.snapshotRecordHash = snapshots.install(p.scope, malformed);
            _invalidScoped(bad);
            host.previewScoped(p, address(this));
        }
        // The scoped current producer is independently caller-sensitive: successful preview above
        // proves the fixed library preserved the host address through every static boundary.
        vm.expectRevert(
            abi.encodeWithSignature("Error(string)", "exact preservation snapshot consumer")
        );
        snapshots.requireCurrent(p.scope, p.snapshotRecordHash, 1);
    }

    function testEveryDependencyAndFactoryRuntimePinRestoresWithoutHistoryMutation() public {
        Scoped.Publication memory p = _scopedPublication(StreamFinalityScopeType.RELEASE, 0);
        PreservationSnapshot.Dependencies memory d = snapshots.dependencies();
        for (uint256 i; i < 11; ++i) {
            snapshots.setDependencyPin(i, keccak256(abi.encode("wrong runtime", i)));
            _invalidScoped(p);
            snapshots.setDependencyPin(i, d.codeHashes[i]);
            host.previewScoped(p, address(this));
        }
        // Retain identical dependencies and original payload pins while changing the actual
        // inert target runtime. These cases reach the live _pin loop independently of the
        // payload/dependency equality check exercised above.
        for (uint256 i = 5; i < 11; ++i) {
            bytes memory originalCode = d.targets[i].code;
            calls.etch(d.targets[i], hex"60006000fd");
            _invalidScoped(p);
            calls.etch(d.targets[i], originalCode);
            host.previewScoped(p, address(this));
        }
        address factory = snapshots.factory();
        bytes memory code = factory.code;
        calls.etch(factory, hex"60006000fd");
        _invalidScoped(p);
        calls.etch(factory, code);
        bytes memory snapshotCode = address(snapshots).code;
        calls.etch(address(snapshots), hex"60006000fd");
        _invalidScoped(p);
        calls.etch(address(snapshots), snapshotCode);
        assertEq(host.scopedContentRootAggregate(1).revision, 0);
        host.previewScoped(p, address(this));
    }

    function testDistinctCapabilitiesProfilesSchemaAndGasNeverFallBack() public {
        Scoped.Publication memory p = _scopedPublication(StreamFinalityScopeType.SEASON, 0);
        PreservationScopedProviderBoundary pp = PreservationScopedProviderBoundary(scopedProvider);
        pp.setProfile(false);
        _invalidScoped(p);
        pp.setProfile(true);
        pp.setInterface(false);
        _invalidScoped(p);
        pp.setInterface(true);
        snapshots.setProfile(false);
        _invalidScoped(p);
        snapshots.setProfile(true);
        snapshots.setInterface(false);
        _invalidScoped(p);
        snapshots.setInterface(true);
        calls.mockCall(
            scopedProvider,
            abi.encodeCall(ScopedProvider.scopedPreservationPolicySnapshotValidationGas, (p.scope)),
            abi.encode(uint256(4999999))
        );
        _invalidScoped(p);
        calls.clearMockedCalls();
        calls.mockCall(
            scopedProvider,
            abi.encodeCall(ScopedProvider.scopedPreservationPolicySnapshotValidationGas, (p.scope)),
            abi.encode(uint256(type(uint32).max) + 1)
        );
        _invalidScoped(p);
        calls.clearMockedCalls();
        scopedFinality.setReadGas(49999);
        _invalidScoped(p);
        scopedFinality.setReadGas(uint256(type(uint32).max) + 1);
        _invalidScoped(p);
        scopedFinality.setReadGas(5000000);
        // Real Schema/Store definitions are required, beyond matching the retained receipt hashes.
        calls.mockCallRevert(
            address(schemas),
            abi.encodeWithSignature("documentFacts(bytes32)", ScopedDocuments.ROOT_SCHEMA),
            abi.encodeWithSignature("Error(string)", "retired root definition")
        );
        _invalidScoped(p);
        calls.clearMockedCalls();
        host.previewScoped(p, address(this));
    }

    function testCurrentReceiptFailureAndLateConsentReprepareAreAtomicWithSameRetry() public {
        Scoped.Publication memory p = _scopedPublication(StreamFinalityScopeType.TOKEN, 0);
        for (uint8 fault = 1; fault <= 4; ++fault) {
            snapshots.setCurrentFault(fault);
            _invalidScoped(p);
            snapshots.setCurrentFault(0);
        }
        bytes32 consent = keccak256("same approval after late refusal");
        _approveScoped(p, consent);
        bytes32 beforeFamily = host.family(1);
        Scoped.Aggregate memory beforeAggregate = host.scopedContentRootAggregate(1);
        snapshots.setLateFailure(consent);
        (bool ok,) = address(host).call(abi.encodeCall(host.publishScoped, (p)));
        assertTrue(!ok);
        assertTrue(!host.consumedArtistContentConsent(consent));
        assertEq(host.scopedHead(p.scope), bytes32(0));
        assertEq(host.family(1), beforeFamily);
        assertEq(abi.encode(host.scopedContentRootAggregate(1)), abi.encode(beforeAggregate));
        snapshots.setLateFailure(0);
        bytes32 key = host.publishScoped(p);
        assertTrue(host.consumedArtistContentConsent(consent));
        p.expectedPredecessor = key;
        artist.approve(host.previewScoped(p, address(this)), consent);
        vm.expectRevert(
            abi.encodeWithSelector(Authorization.ArtistContentConsentConsumed.selector, consent)
        );
        host.publishScoped(p);
        assertEq(host.scopedContentRootAggregate(1).revision, 1);
    }

    function testScopePublisherGrantFreezeAndCurrentIdentityRefusals() public {
        Scoped.Publication memory p = _scopedPublication(StreamFinalityScopeType.TOKEN, 0);
        Scoped.Publication memory bad = abi.decode(abi.encode(p), (Scoped.Publication));
        bad.scope = StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        _invalidScoped(bad);
        bad.scope = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        _invalidScoped(bad);
        bytes32 approved = _approveScoped(p, keccak256("exact original publisher"));
        _grant(1, 7, address(0xA11CE), true);
        assertTrue(host.previewScoped(p, address(0xA11CE)) != approved);
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentAuthorizationRequired.selector, uint256(1)
            )
        );
        vm.prank(address(0xA11CE));
        host.publishScoped(p);
        _grant(1, 7, address(this), false);
        _invalidScoped(p);
        _grant(0, 8, address(this), true);
        assertTrue(host.previewScoped(p, address(this)) != approved);
        core.setFrozen(true);
        _invalidScoped(p);
        core.setFrozen(false);
        scopedFinality.setFreeze(StreamArtworkFreezeMode.EXACT);
        _invalidScoped(p);
        scopedFinality.setFreeze(StreamArtworkFreezeMode.NONE);
        core.setPointer(keccak256("METADATA_ROUTER"), address(metadata));
        _invalidScoped(p);
        core.setPointer(keccak256("METADATA_ROUTER"), address(host));
        artist.changeGeneration();
        _invalidScoped(p);
        calls.mockCall(
            address(artist),
            abi.encodeCall(IStreamArtistAttributionState.collectionArtistState, (uint256(1))),
            abi.encode(uint8(2), uint64(1), keccak256("artist"), uint8(1), keccak256("binding"))
        );
        _approveScoped(p, keccak256("restored current identity"));
        host.publishScoped(p);
        calls.clearMockedCalls();
    }

    function testIndependentScopeHeadsAndCollectionRootShareOriginalAggregateAndConsentBook()
        public
    {
        Scoped.Publication memory token = _scopedPublication(StreamFinalityScopeType.TOKEN, 0);
        Scoped.Publication memory release = _scopedPublication(StreamFinalityScopeType.RELEASE, 0);
        bytes32 tokenKey = _publishScoped(token, keccak256("token consent"));
        Scoped.Record memory tokenRecord = host.scopedRecord(tokenKey);
        Scoped.Aggregate memory prior = host.scopedContentRootAggregate(1);
        bytes32 releaseKey = _publishScoped(release, keccak256("release consent"));
        Scoped.Record memory releaseRecord = host.scopedRecord(releaseKey);
        assertEq(host.scopedHead(token.scope), tokenKey);
        assertEq(host.scopedHead(release.scope), releaseKey);
        assertEq(
            host.scopedContentRootAggregate(1).transitionChain,
            _append(prior, release, releaseRecord.stateHash)
        );
        _selectProvider(provider);
        Root.Publication memory collection = _publication();
        bytes32 nextFamily = _approvePreservation(collection, keccak256("collection after scopes"));
        host.publishCollection(collection);
        assertEq(host.family(1), nextFamily);
        assertEq(host.scopedContentRootAggregate(1).revision, 2);
        assertEq(abi.encode(host.scopedRecord(tokenKey)), abi.encode(tokenRecord));
        _selectScoped(scopedProvider);
        token.expectedPredecessor = tokenKey;
        _approveScoped(token, keccak256("collection after scopes"));
        vm.expectRevert(
            abi.encodeWithSelector(
                Authorization.ArtistContentConsentConsumed.selector,
                keccak256("collection after scopes")
            )
        );
        host.publishScoped(token);
    }

    function testOldScopedV2AndPreservationKeepOneHeadAndRejectForeignProfile() public {
        string[5] memory names = [
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
            "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _register(
                names[i],
                (i == 1 || i == 4)
                    ? IStreamSchemaRegistry.DocumentKind.CANONICALIZATION
                    : IStreamSchemaRegistry.DocumentKind.SCHEMA,
                OldScopedDocuments.document(keccak256(bytes(names[i]))),
                schemas.RAW_BYTES()
            );
        }
        ScopedPolicyRootValidatedSnapshotBoundary old = new ScopedPolicyRootValidatedSnapshotBoundary(
            address(core), address(metadata), address(host), address(schemas), address(store)
        );
        address oldProvider = address(
            new ScopedPolicyRootProviderBoundary(
                address(metadata),
                address(schemas),
                address(preservationManifest),
                address(old),
                address(old)
            )
        );
        Scoped.Publication memory p = Scoped.Publication(
            _scope(StreamFinalityScopeType.TOKEN), 0, 0, 1, "ipfs://original-scoped"
        );
        p.snapshotRecordHash = old.install(p.scope, 0);
        _selectScoped(oldProvider);
        _invalidScoped(p);
        bytes32 first = _publishOldScoped(p, keccak256("old scoped first"));
        Scoped.Record memory saved = host.scopedRecord(first);
        _selectScoped(scopedProvider);
        p.expectedPredecessor = first;
        p.snapshotRecordHash = snapshots.install(p.scope, 0);
        (bool ok,) = address(host)
            .staticcall(
                abi.encodeCall(
                    host.previewOld,
                    (abi.encodeCall(
                            OldScopedRoot.previewScopedPolicyContentRootPublication,
                            (p, address(this))
                        ))
                )
            );
        assertTrue(!ok);
        bytes32 second = _publishScoped(p, keccak256("new scoped middle"));
        assertEq(host.scopedBinding(first).profileId, bytes32(0));
        _selectScoped(oldProvider);
        p.expectedPredecessor = second;
        p.snapshotRecordHash = old.install(p.scope, 0);
        bytes32 third = _publishOldScoped(p, keccak256("old scoped last"));
        assertEq(host.scopedRecord(third).publication.expectedPredecessor, second);
        assertEq(host.scopedRecord(second).publication.expectedPredecessor, first);
        assertEq(abi.encode(host.scopedRecord(first)), abi.encode(saved));
        assertEq(host.scopedContentRootAggregate(1).revision, 3);
    }

    function _selectScoped(address selectedProvider) private {
        scopedFinality = new ScopedRootFinalityBoundary(
            address(core),
            address(artist),
            address(metadata),
            selectedProvider,
            preservationArtifacts
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

    function _scopedPublication(StreamFinalityScopeType kind, uint8 malformed)
        private
        returns (Scoped.Publication memory p)
    {
        p.scope = _scope(kind);
        p.snapshotRecordHash = snapshots.install(p.scope, malformed);
        p.snapshotRevision = 1;
        p.manifestURI = "ipfs://scoped-preservation-root";
    }

    function _approveScoped(Scoped.Publication memory p, bytes32 consent)
        private
        returns (bytes32 expected)
    {
        expected = host.previewScoped(p, address(this));
        artist.approve(expected, consent);
    }

    function _publishScoped(Scoped.Publication memory p, bytes32 consent)
        private
        returns (bytes32 key)
    {
        bytes32 expected = _approveScoped(p, consent);
        key = host.publishScoped(p);
        assertEq(host.family(1), expected);
    }

    function _publishOldScoped(Scoped.Publication memory p, bytes32 consent)
        private
        returns (bytes32)
    {
        artist.approve(
            host.previewOld(
                abi.encodeCall(
                    OldScopedRoot.previewScopedPolicyContentRootPublication, (p, address(this))
                )
            ),
            consent
        );
        return host.publishOld(
            abi.encodeCall(OldScopedRoot.publishScopedPolicyContentRootPublication, (p))
        );
    }

    function _invalidScoped(Scoped.Publication memory p) private {
        (bool ok,) =
            address(host).staticcall(abi.encodeCall(host.previewScoped, (p, address(this))));
        assertTrue(!ok);
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
