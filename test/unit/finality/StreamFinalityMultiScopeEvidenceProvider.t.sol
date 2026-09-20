// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../helpers/ScopedReferenceSnapshotFixture.sol";
import {
    StreamFinalityMultiScopeEvidenceProvider as Combined
} from "../../../smart-contracts/domains/finality/StreamFinalityMultiScopeEvidenceProvider.sol";
import {
    StreamFinalityNativeEvidenceProvider as Original
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as ScopedReads
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityScopedProviderOperations as Operations
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderOperations.sol";
import {
    IStreamScopedContentRootPublication as Root
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamFinalityScopedMetadataReads as ScopedMetadata
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopedMetadataReads.sol";
import {
    IStreamScopedContentRootEvidenceBinding as Binding
} from "../../../smart-contracts/interfaces/stream/finality/IStreamScopedContentRootEvidenceBinding.sol";
import {
    StreamSnapshotTypes as LegacySnapshot
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalityComponentExpectation
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityDomains
} from "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityHostComponentFacts
} from "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";

/// @notice Actual combined/original provider constructors and actual scoped Snapshot/Metadata/
/// Store/Schema/membership. Root, legacy leaf sources and remaining selected graph are explicit
/// typed boundaries; this is not an Artist op17 or complete Registry finality ceremony.
contract StreamFinalityMultiScopeEvidenceProviderTest is ScopedReferenceSnapshotFixture {
    Combined private combined;
    Original private original;
    Native.Config private nativeConfig;
    ScopedReads.Config private scopedConfig;
    bytes32 private constant LEGACY = keccak256("independent original COLLECTION snapshot bytes");

    function _ready(uint8 kind) private {
        _initialize(kind);
        _publishSnapshot();
        Scoped.Receipt memory saved = host.currentSnapshot(publication.scope);
        Root.Record memory root;
        root.publication.scope = publication.scope;
        root.publication.snapshotRecordHash = saved.recordHash;
        root.publication.snapshotRevision = saved.revision;
        root.snapshotHost = address(host);
        root.snapshotCodeHash = address(host).codehash;
        root.snapshotManifestHash = saved.manifestHash;
        root.snapshotSourceHash = saved.sourceHash;
        root.artistConsent = keccak256("typed original content consent");
        root.stateHash = keccak256("typed signed content family state");
        root.contentRoot = contentPlan.contentRoot;
        root.leafCount = contentPlan.tokenCount;
        route.set(
            "scopedContentRootHead((uint8,uint256,uint256,bytes32))",
            abi.encode(keccak256("typed root"))
        );
        route.set("scopedContentRootRecord(bytes32)", abi.encode(root));
        route.set(
            "scopedTokenContentRoot((uint8,uint256,uint256,bytes32))",
            abi.encode(root.contentRoot, root.leafCount, keccak256("leaf schema"))
        );
        route.set("streamModuleVersion()", abi.encode(bytes32(uint256(23))));
        route.set(
            "streamModuleManifest()", abi.encode("", keccak256("typed Router module manifest"))
        );
        Native.Config memory n;
        n.chainId = block.chainid;
        n.readGas = 600000;
        n.sourceGas = 16000000;
        n.componentSourceGas = 10000000;
        n.inventoryDependencyHash = keccak256("typed original inventory");
        for (uint256 i; i < 22; ++i) {
            n.targets[i] = address(new ScopedReferenceReadBoundary());
        }
        n.targets[0] = address(core);
        n.targets[1] = address(metadata);
        n.targets[2] = address(route);
        n.targets[3] = address(membership);
        n.targets[4] = address(schemas);
        n.targets[5] = address(store);
        for (uint256 i; i < 22; ++i) {
            n.codeHashes[i] = n.targets[i].codehash;
        }
        LegacySnapshot.Receipt memory old;
        old.manifestHash = LEGACY;
        ScopedReferenceReadBoundary(n.targets[8]).set("currentSnapshot(uint256)", abi.encode(old));
        ScopedReads.Config memory s = abi.decode(abi.encode(n), (ScopedReads.Config));
        s.targets[8] = address(host);
        s.codeHashes[8] = address(host).codehash;
        uint256[3] memory replacements = [uint256(9), 18, 19];
        for (uint256 i; i < 3; ++i) {
            uint256 j = replacements[i];
            s.targets[j] = address(new ScopedReferenceReadBoundary());
            s.codeHashes[j] = s.targets[j].codehash;
        }
        s.inventoryDependencyHash = keccak256("typed complete scoped inventory");
        nativeConfig = n;
        scopedConfig = s;
        original = new Original(n);
        combined = new Combined(n, s);
    }

    function testActualTokenMetadataReadsAndImmutableBindings() public {
        _ready(1);
        require(combined.supportsInterface(type(ScopedMetadata).interfaceId));
        require(combined.supportsInterface(type(Binding).interfaceId));
        require(!combined.supportsInterface(0xffffffff));
        require(combined.scopedSnapshotHost() == address(host));
        require(combined.scopedSnapshotCodeHash() == address(host).codehash);
        require(combined.scopedSnapshotValidationGas() == scopedConfig.componentSourceGas);
        require(
            keccak256(abi.encode(combined.scopedConfiguration()))
                == keccak256(abi.encode(scopedConfig))
        );
        require(
            keccak256(abi.encode(combined.nativeConfiguration()))
                == keccak256(abi.encode(nativeConfig))
        );
        require(
            combined.scopedSnapshotHash(publication.scope)
                == host.currentSnapshot(publication.scope).manifestHash
        );
        (bytes32 root, uint64 count, bytes32 schema) = combined.scopedContentRoot(publication.scope);
        require(root == contentPlan.contentRoot && count == 1 && schema == keccak256("leaf schema"));
        (bool exists, bytes32 value) = combined.scopedManifest(publication.scope);
        require(!exists && value == 0);
    }

    function testReleaseAndSameIdSeasonCannotAlias() public {
        _ready(2);
        (bool exists, bytes32 value) = combined.scopedManifest(publication.scope);
        require(
            exists
                && value == membership.requireScopeMembership(publication.scope).scopeManifestHash
        );
        StreamFinalityScope memory different = publication.scope;
        different.scopeType = StreamFinalityScopeType.SEASON;
        vm.expectRevert();
        combined.scopedManifest(different);
        vm.expectRevert();
        combined.scopedSnapshotHash(different);
        vm.expectRevert();
        combined.scopedContentRoot(different);
        require(combined.scopedSnapshotHash(publication.scope) != 0);
    }

    function testOriginalCollectionSnapshotAndScriptBytesStayExact() public {
        _ready(1);
        require(combined.latestCollectionSnapshotHash(1) == LEGACY);
        require(original.latestCollectionSnapshotHash(1) == LEGACY);
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        f.scriptBytes = 17;
        f.scriptHash = keccak256("independent script bytes");
        f.scriptLocked = true;
        route.set("collectionServingFacts(uint256)", abi.encode(f));
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        StreamFinalityHostComponentFacts memory a =
            original.finalityComponentFacts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE, scope);
        StreamFinalityHostComponentFacts memory b =
            combined.finalityComponentFacts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE, scope);
        require(a.frozen && keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
        require(
            a.dataHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1"),
                        block.chainid,
                        address(core),
                        address(route),
                        StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
                        scope,
                        keccak256(abi.encode(f.scriptHash, f.scriptBytes))
                    )
                )
        );
    }

    function testPreparedOriginalAndScopedCallsKeepActualRegistryGuard() public {
        _ready(1);
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        vm.expectRevert(abi.encodeWithSelector(Operations.ScopedProviderRegistryOnly.selector));
        combined.requirePreparedFinalityScopeInputs(publication.scope, bytes32(uint256(1)), rows);
        vm.expectRevert(abi.encodeWithSelector(Operations.ScopedProviderRegistryOnly.selector));
        combined.requirePreparedFinalityScopeInputsAndReview(
            publication.scope, bytes32(uint256(1)), rows
        );
        StreamFinalityScope memory collection =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0);
        vm.expectRevert(
            abi.encodeWithSelector(Original.NativeProviderOriginalRegistryOnly.selector)
        );
        combined.requirePreparedFinalityScopeInputs(collection, bytes32(uint256(1)), rows);
        vm.etch(nativeConfig.targets[12], hex"00");
        vm.prank(nativeConfig.targets[12]);
        vm.expectRevert(abi.encodeWithSelector(Operations.ScopedProviderRegistryOnly.selector));
        combined.requirePreparedFinalityScopeInputs(publication.scope, bytes32(uint256(1)), rows);
    }

    function testConstructorRejectsForeignSharedFactoryCoreAndMissingPins() public {
        _ready(1);
        Native.Config memory n = nativeConfig;
        ScopedReads.Config memory s = scopedConfig;
        s.targets[10] = address(new ScopedReferenceReadBoundary());
        s.codeHashes[10] = s.targets[10].codehash;
        vm.expectRevert();
        new Combined(n, s);
        s = scopedConfig;
        s.codeHashes[0] ^= bytes32(uint256(1));
        vm.expectRevert();
        new Combined(n, s);
        s = scopedConfig;
        s.codeHashes[8] = 0;
        vm.expectRevert();
        new Combined(n, s);
        s = scopedConfig;
        s.componentSourceGas += 1;
        vm.expectRevert();
        new Combined(n, s);
    }

    function testChangedScopedRuntimeDoesNotBecomeLegacySnapshot() public {
        _ready(3);
        Scoped.Receipt memory saved = host.currentSnapshot(publication.scope);
        require(combined.scopedSnapshotHash(publication.scope) == saved.manifestHash);
        bytes memory code = address(host).code;
        vm.etch(address(host), hex"00");
        vm.expectRevert();
        combined.scopedSnapshotHash(publication.scope);
        require(combined.latestCollectionSnapshotHash(1) == LEGACY);
        vm.etch(address(host), code);
        require(combined.scopedSnapshotHash(publication.scope) == saved.manifestHash);
    }

    function testRequiredViewNeverFallsBackToCollectionOrScopedProfile() public {
        _ready(1);
        StreamFinalityScope memory view_ =
            StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, bytes32(uint256(1)));
        vm.expectRevert();
        combined.inputManifestBytes(view_);
        vm.expectRevert();
        combined.scopedManifest(view_);
        vm.expectRevert();
        combined.finalityComponentFacts(StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE, view_);
        require(combined.latestCollectionSnapshotHash(1) == LEGACY);
    }
}
