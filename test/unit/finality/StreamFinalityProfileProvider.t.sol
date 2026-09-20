// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../../smart-contracts/interfaces/stream/artist/IStreamArtistMintConsent.sol";
import "../../../smart-contracts/interfaces/stream/finality/IStreamArtworkFinalityComponents.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import "../../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import "../../helpers/PolicySnapshotFixtureV2.sol";
import {
    StreamFinalityPolicyMultiScopeEvidenceProvider as Provider
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyMultiScopeEvidenceProvider.sol";
import {
    StreamFinalityNativeEvidenceProvider as Original
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeEvidenceProvider.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "../../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as ScopedConfig
} from "../../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityProfileSourceReads as Source
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileSourceReads.sol";
import {
    StreamFinalityProfileDiscovery as Discovery
} from "../../../smart-contracts/domains/finality/StreamFinalityProfileDiscovery.sol";
import {
    StreamSnapshotTypes as Legacy
} from "../../../smart-contracts/interfaces/stream/metadata/StreamSnapshotTypes.sol";
import {
    StreamFinalityPolicyStaticSourceV2 as Projection
} from "../../../smart-contracts/domains/finality/StreamFinalityPolicyStaticSourceV2.sol";

/// @notice Actual new/original provider constructors, V2 Snapshot/Metadata/Schema/Store and
/// complete membership. Router profiles, original snapshot, reference/factory/Registry and
/// individual Discovery components are named typed boundaries. No completed Registry ceremony,
/// renderer conformance, or source inventory acceptance is implied by catalogue selection.
contract StreamFinalityProfileProviderTest is PolicySnapshotFixtureV2 {
    Provider private provider;
    Original private original;
    Native.Config private oldConfig;
    Native.Config private policyConfig;
    ScopedConfig.Config private scopedConfig;
    bytes32 private snapshot;
    bytes32 private constant LEGACY = keccak256("literal original snapshot manifest");

    function _ready() private {
        _initializePolicySnapshot();
        snapshot = _publishSnapshot();
        route.set("streamModuleVersion()", abi.encode(bytes32(uint256(23))));
        route.set(
            "streamModuleManifest()", abi.encode("", keccak256("typed Router module manifest"))
        );
        route.set(
            "staticMetadataActivation(uint256)",
            abi.encode(keccak256("typed activation"), uint64(1), bytes32(0))
        );
        Native.Config memory n;
        n.chainId = block.chainid;
        n.readGas = 1000000;
        n.sourceGas = 16000000;
        n.componentSourceGas = 10000000;
        n.inventoryDependencyHash = keccak256("original inventory configuration");
        for (uint256 i; i < 22; ++i) {
            n.targets[i] = address(new PolicySnapshotReadBoundaryV2());
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
        Legacy.Receipt memory legacy;
        legacy.manifestHash = LEGACY;
        PolicySnapshotReadBoundaryV2(n.targets[8])
            .set("currentSnapshot(uint256)", abi.encode(legacy));
        ScopedConfig.Config memory scoped = abi.decode(abi.encode(n), (ScopedConfig.Config));
        uint256[4] memory slots = [uint256(8), 9, 18, 19];
        for (uint256 i; i < slots.length; ++i) {
            uint256 j = slots[i];
            scoped.targets[j] = address(new PolicySnapshotReadBoundaryV2());
            scoped.codeHashes[j] = scoped.targets[j].codehash;
        }
        scoped.inventoryDependencyHash = keccak256("scoped inventory configuration");
        Native.Config memory p = abi.decode(abi.encode(n), (Native.Config));
        uint256[5] memory ps = [uint256(8), 9, 10, 18, 19];
        for (uint256 i; i < ps.length; ++i) {
            uint256 j = ps[i];
            p.targets[j] = address(new PolicySnapshotReadBoundaryV2());
            p.codeHashes[j] = p.targets[j].codehash;
        }
        p.targets[8] = address(host);
        p.codeHashes[8] = address(host).codehash;
        p.inventoryDependencyHash = keccak256("V2 inventory configuration");
        oldConfig = n;
        scopedConfig = scoped;
        policyConfig = p;
        provider = new Provider(n, scoped, p, address(outputs), address(outputs).codehash);
        original = new Original(n);
    }

    function _legacy() private {
        route.set("collectionContentRootHead(uint256)", abi.encode(bytes32(0)));
    }

    function _v2() private {
        _refreshRoot();
    }

    function testActualV2SnapshotAndConstructorCatalogueUseExactProfilesAndManifestMeaning()
        public
    {
        _ready();
        Profiles.Sources memory selected_ = provider.finalitySourcesForScope(publication.scope);
        require(
            selected_.profile.profileHash == host.currentSnapshot(publication.scope).profileHash
        );
        require(
            selected_.profile.snapshots == address(host)
                && selected_.profile.referenceRender == policyConfig.targets[9]
        );
        require(selected_.profile.entropyFactory == policyConfig.targets[10]);
        require(selected_.profile.configurationHash == keccak256(abi.encode(policyConfig)));
        require(
            provider.latestCollectionSnapshotHash(1)
                == host.currentSnapshot(publication.scope).manifestHash
        );
        require(provider.policyOutputManifestV2() == address(outputs));
        require(provider.policySnapshotPublicationV2() == address(host));
        require(provider.policyReferencePublicationV2() == policyConfig.targets[9]);
        require(
            provider.supportsInterface(type(Profiles).interfaceId)
                && !provider.supportsInterface(0xffffffff)
        );
    }

    function testOriginalCollectionBranchKeepsLegacyGetterAndLiteralScriptHash() public {
        _ready();
        _legacy();
        require(
            provider.latestCollectionSnapshotHash(1) == LEGACY
                && original.latestCollectionSnapshotHash(1) == LEGACY
        );
        Profiles.Sources memory chosen = provider.finalitySourcesForScope(publication.scope);
        require(
            chosen.profile.referenceRender == oldConfig.targets[9]
                && chosen.profile.entropyFactory == oldConfig.targets[10]
        );
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        f.scriptBytes = 17;
        f.scriptHash = keccak256("literal script");
        f.scriptLocked = true;
        route.set("collectionServingFacts(uint256)", abi.encode(f));
        StreamFinalityHostComponentFacts memory a = original.finalityComponentFacts(
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE, publication.scope
        );
        StreamFinalityHostComponentFacts memory b = provider.finalityComponentFacts(
            StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE, publication.scope
        );
        require(a.frozen && keccak256(abi.encode(a)) == keccak256(abi.encode(b)));
        require(
            b.dataHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_ROUTER_COMPONENT_EVIDENCE_V1"),
                        block.chainid,
                        address(core),
                        address(route),
                        StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE,
                        publication.scope,
                        keccak256(abi.encode(f.scriptHash, f.scriptBytes))
                    )
                )
        );
    }

    function testSameIdReleaseSeasonAndTokenKeepFullScopeIdentity() public {
        _ready();
        StreamFinalityScope memory release_ =
            StreamFinalityScope(StreamFinalityScopeType.RELEASE, 1, 0, keccak256("id"));
        StreamFinalityScope memory season = StreamFinalityScope(
            StreamFinalityScopeType.SEASON, release_.collectionId, 0, release_.scopeId
        );
        Profiles.Sources memory a = provider.finalitySourcesForScope(release_);
        Profiles.Sources memory b = provider.finalitySourcesForScope(season);
        require(
            a.profile.profileHash == b.profile.profileHash
                && a.profile.snapshots == scopedConfig.targets[8]
        );
        require(keccak256(abi.encode(a)) != keccak256(abi.encode(b)));
        StreamFinalityScope memory token =
            StreamFinalityScope(StreamFinalityScopeType.TOKEN, 1, 1, 0);
        require(
            provider.finalitySourcesForScope(token).profile.profileHash == a.profile.profileHash
        );
        token.scopeId = keccak256("invalid token scope");
        vm.expectRevert();
        provider.finalitySourcesForScope(token);
        token = StreamFinalityScope(StreamFinalityScopeType.VIEW, 1, 0, keccak256("view"));
        vm.expectRevert();
        provider.finalitySourcesForScope(token);
    }

    function testUnknownMixedAndForeignCanonicalPolicyBindingsCannotFallback() public {
        _ready();
        IStreamPolicyContentRootPublicationV2.Binding memory b = rootBinding;
        b.profileId = keccak256("unknown profile");
        route.set("policyContentRootBinding(bytes32)", abi.encode(b));
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        b.profileId = 0;
        route.set("policyContentRootBinding(bytes32)", abi.encode(b));
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        b = rootBinding;
        b.outputManifest = address(content);
        b.outputManifestCodeHash = address(content).codehash;
        route.set("policyContentRootBinding(bytes32)", abi.encode(b));
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        _v2();
        require(
            provider.finalitySourcesForScope(publication.scope).profile.snapshots == address(host)
        );
    }

    function testMalformedCapabilityMissingActivationAndRuntimeDriftRefuseThenRestore() public {
        _ready();
        bytes memory query = abi.encodeWithSignature(
            "supportsInterface(bytes4)", type(IStreamPolicyContentRootPublicationV2).interfaceId
        );
        svm.mockCall(address(route), query, abi.encode(uint256(2)));
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        svm.mockCall(address(route), query, abi.encode(true));
        route.set(
            "staticMetadataActivation(uint256)", abi.encode(bytes32(0), uint64(0), bytes32(0))
        );
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        route.set(
            "staticMetadataActivation(uint256)",
            abi.encode(keccak256("typed activation"), uint64(1), bytes32(0))
        );
        bytes memory code = policyConfig.targets[9].code;
        vm.etch(policyConfig.targets[9], hex"00");
        vm.expectRevert();
        provider.finalitySourcesForScope(publication.scope);
        vm.etch(policyConfig.targets[9], code);
        require(
            provider.finalitySourcesForScope(publication.scope).profile.snapshots == address(host)
        );
    }

    function testActualSnapshotPayloadDriftRefusesWithoutReplacingHistoricalReceipt() public {
        _ready();
        bytes memory originalBytes = host.snapshotPayload(snapshot);
        bytes memory changed = abi.decode(abi.encode(originalBytes), (bytes));
        changed[changed.length - 1] = bytes1(uint8(changed[changed.length - 1]) ^ 1);
        svm.mockCall(
            address(host), abi.encodeCall(host.snapshotPayload, (snapshot)), abi.encode(changed)
        );
        vm.expectRevert();
        provider.latestCollectionSnapshotHash(1);
        svm.mockCall(
            address(host),
            abi.encodeCall(host.snapshotPayload, (snapshot)),
            abi.encode(originalBytes)
        );
        require(
            provider.latestCollectionSnapshotHash(1)
                == host.currentSnapshot(publication.scope).manifestHash
        );
    }

    function testPreparedRegistryGuardPrecedesMalformedCurrentProfile() public {
        _ready();
        route.set("policyContentRootBinding(bytes32)", hex"01");
        StreamFinalityComponentExpectation[] memory rows =
            new StreamFinalityComponentExpectation[](0);
        vm.expectRevert(
            abi.encodeWithSelector(Original.NativeProviderOriginalRegistryOnly.selector)
        );
        provider.requirePreparedFinalityScopeInputs(publication.scope, bytes32(uint256(1)), rows);
        vm.expectRevert(
            abi.encodeWithSelector(Original.NativeProviderOriginalRegistryOnly.selector)
        );
        provider.requirePreparedFinalityScopeInputsAndReview(
            publication.scope, bytes32(uint256(1)), rows
        );
    }

    function testConstructorSharedRoleMismatchAndActualHostDomainAreExplicit() public {
        _ready();
        Native.Config memory altered = policyConfig;
        altered.targets[6] = altered.targets[8];
        altered.codeHashes[6] = altered.codeHashes[8];
        vm.expectRevert(abi.encodeWithSelector(Source.InvalidFinalitySourceProfile.selector));
        new Provider(oldConfig, scopedConfig, altered, address(outputs), address(outputs).codehash);
        Provider other = new Provider(
            oldConfig, scopedConfig, policyConfig, address(outputs), address(outputs).codehash
        );
        require(
            other.finalitySourceConfigurationHash() != provider.finalitySourceConfigurationHash()
        );
        require(
            keccak256(abi.encode(other.finalitySourceProfile(2)))
                == keccak256(abi.encode(provider.finalitySourceProfile(2)))
        );
    }

    function _sourceRows() private {
        for (uint8 i; i < 3; ++i) {
            Profiles.Profile memory p = provider.finalitySourceProfile(i);
            if (p.snapshots != address(host)) {
                PolicySnapshotReadBoundaryV2(p.snapshots).set("core()", abi.encode(address(core)));
                PolicySnapshotReadBoundaryV2(p.snapshots)
                    .set("metadataHost()", abi.encode(address(metadata)));
            }
            PolicySnapshotReadBoundaryV2 ref_ = PolicySnapshotReadBoundaryV2(p.referenceRender);
            ref_.set("core()", abi.encode(address(core)));
            ref_.set("metadataHost()", abi.encode(address(metadata)));
            ref_.set("metadataRouter()", abi.encode(address(route)));
            ref_.set("snapshots()", abi.encode(p.snapshots));
            PolicySnapshotReadBoundaryV2 f = PolicySnapshotReadBoundaryV2(p.entropyFactory);
            f.set("core()", abi.encode(address(core)));
            f.set("metadataHost()", abi.encode(address(metadata)));
            f.set("scopeMembershipHost()", abi.encode(address(membership)));
        }
    }

    function _discoveryConfig()
        private
        returns (StreamFinalityDiscoveryTypes.Configuration memory c)
    {
        _sourceRows();
        c.core = address(core);
        c.metadata = address(metadata);
        c.router = address(route);
        c.provider = address(provider);
        c.membership = address(membership);
        c.entropyFactory = oldConfig.targets[10];
        c.referenceRender = oldConfig.targets[9];
        c.artist = oldConfig.targets[11];
        c.finalityRegistry = oldConfig.targets[12];
        c.finalityRegistryCodeHash = c.finalityRegistry.codehash;
        c.readGas = 1000000;
        c.componentGas = 12000000;
        c.entropyGas = 12000000;
        for (uint256 i; i < 7; ++i) {
            PolicySnapshotReadBoundaryV2 a = new PolicySnapshotReadBoundaryV2();
            a.set("core()", abi.encode(c.core));
            a.set("host()", abi.encode(i == 6 ? c.metadata : c.router));
            a.set("metadataHost()", abi.encode(c.metadata));
            a.set("evidenceProvider()", abi.encode(c.provider));
            a.set("componentType()", abi.encode(_family(i)));
            svm.mockCall(
                address(a), abi.encodeWithSignature("requireCurrentSelection()"), bytes("")
            );
            if (i == 6) c.metadataAdapter = address(a);
            else c.routerAdapters[i] = address(a);
        }
    }

    function _family(uint256 i) private pure returns (bytes32) {
        if (i == 0) return StreamFinalityDomains.COMPONENT_METADATA_ROUTER;
        if (i == 1) return StreamFinalityDomains.COMPONENT_RENDERER;
        if (i == 2) return StreamFinalityDomains.COMPONENT_RENDER_CONTEXT;
        if (i == 3) return StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST;
        if (i == 4) return StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE;
        if (i == 5) return StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE;
        return StreamFinalityDomains.COMPONENT_COLLECTION_METADATA;
    }

    function testDiscoveryPinsCompleteCatalogueAndRejectsWrongConfiguration() public {
        _ready();
        StreamFinalityDiscoveryTypes.Configuration memory c = _discoveryConfig();
        vm.expectRevert(
            abi.encodeWithSelector(Discovery.DiscoveryConfiguration.selector, address(provider))
        );
        new Discovery(c, keccak256("foreign configuration"));
        Discovery discovery = new Discovery(c, provider.finalitySourceConfigurationHash());
        require(discovery.sourceConfigurationHash() == provider.finalitySourceConfigurationHash());
        for (uint8 i; i < 3; ++i) {
            Profiles.Profile memory p = provider.finalitySourceProfile(i);
            require(discovery.dependencyCodeHash(p.referenceRender) == p.referenceRenderCodeHash);
            require(discovery.dependencyCodeHash(p.snapshots) == p.snapshotsCodeHash);
            require(discovery.dependencyCodeHash(p.entropyFactory) == p.entropyFactoryCodeHash);
        }
        require(keccak256(abi.encode(discovery.configuration())) == keccak256(abi.encode(c)));
    }

    function testDiscoveryRejectsForeignFullScopeOrAlteredCatalogueBeforeComponentReads() public {
        _ready();
        StreamFinalityDiscoveryTypes.Configuration memory c = _discoveryConfig();
        Discovery discovery = new Discovery(c, provider.finalitySourceConfigurationHash());
        Profiles.Sources memory selected_ = provider.finalitySourcesForScope(publication.scope);
        bytes memory call_ = abi.encodeCall(provider.finalitySourcesForScope, (publication.scope));
        selected_.scope.collectionId = 2;
        svm.mockCall(address(provider), call_, abi.encode(selected_));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.finalityComponentCount(1);
        selected_.scope = publication.scope;
        selected_.profile.referenceRender = oldConfig.targets[9];
        svm.mockCall(address(provider), call_, abi.encode(selected_));
        vm.expectRevert(abi.encodeWithSelector(Discovery.DiscoveryUnsupportedProfile.selector));
        discovery.finalityComponentCount(1);
    }

    function _activateDiscovery(
        Discovery discovery,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) private {
        PolicySnapshotReadBoundaryV2 registry = PolicySnapshotReadBoundaryV2(c.finalityRegistry);
        registry.set("scopeEvidenceProvider()", abi.encode(c.provider));
        registry.set("finalityDiscovery()", abi.encode(address(discovery)));
        registry.set("coreReads()", abi.encode(c.core));
        registry.set("metadataReads()", abi.encode(c.metadata));
        registry.set("sanctionReads()", abi.encode(c.artist));
        // Explicit typed Registry/candidate boundary only. Catalogue selection and all routes
        // below execute the actual new provider/Discovery bodies; this is not an execution proof.
        svm.mockCall(
            c.provider,
            abi.encodeCall(
                IStreamFinalityRouterEvidenceBinding.requireCurrentRouterCandidate,
                (uint256(1), c.finalityRegistry)
            ),
            bytes("")
        );
        PolicySnapshotReadBoundaryV2 aa = PolicySnapshotReadBoundaryV2(c.artist);
        aa.set("streamModuleType()", abi.encode(keccak256("ARTIST_REGISTRY")));
        aa.set("streamModuleInterfaceId()", abi.encode(type(IStreamArtistMintConsent).interfaceId));
        svm.mockCall(
            c.core,
            abi.encodeWithSignature("getSatellitePointer(bytes32)", keccak256("ARTIST_REGISTRY")),
            abi.encode(
                c.artist,
                c.artist.codehash,
                false,
                keccak256("ARTIST_REGISTRY"),
                type(IStreamArtistMintConsent).interfaceId,
                c.core,
                uint8(1),
                bytes32(uint256(1)),
                bytes32(uint256(2)),
                uint64(1)
            )
        );
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.scriptBytes = 17;
        f.presentationProfile = keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1");
        route.set("collectionServingFacts(uint256)", abi.encode(f));
        for (uint8 i; i < 3; ++i) {
            Profiles.Profile memory profile = provider.finalitySourceProfile(i);
            PolicySnapshotReadBoundaryV2 set = new PolicySnapshotReadBoundaryV2();
            bytes4 id = type(IStreamArtworkFinalityComponent).interfaceId;
            PolicySnapshotReadBoundaryV2(profile.entropyFactory)
                .set(
                    "requireCurrentRoute((uint8,uint256,uint256,bytes32))",
                    abi.encode(
                        StreamFinalityCurrentComponentRoute(
                            StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR,
                            address(set),
                            id,
                            address(set).codehash
                        )
                    )
                );
            _referenceState(profile.referenceRender, true);
        }
    }

    function _referenceState(address target, bool frozen) private {
        StreamFinalityComponentState memory state = StreamFinalityComponentState(
            frozen,
            StreamFinalityDomains.COMPONENT_REFERENCE_RENDER,
            target,
            type(IStreamArtworkFinalityComponent).interfaceId,
            target.codehash,
            keccak256("module"),
            keccak256("manifest"),
            keccak256("typed reference state")
        );
        PolicySnapshotReadBoundaryV2(target).set("finalityState(uint256)", abi.encode(state));
    }

    function testDiscoveryActualProfileSwitchUsesExactReferenceAndFactoryRoutes() public {
        _ready();
        StreamFinalityDiscoveryTypes.Configuration memory c = _discoveryConfig();
        Discovery discovery = new Discovery(c, provider.finalitySourceConfigurationHash());
        _activateDiscovery(discovery, c);
        StreamFinalityCurrentComponentRoute[] memory policyRoutes =
            discovery.requireCurrentRoutes(publication.scope, false);
        require(policyRoutes.length == 9);
        address policyEntropy;
        for (uint256 i; i < 9; ++i) {
            if (policyRoutes[i].componentType == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER) {
                require(policyRoutes[i].component == policyConfig.targets[9]);
            }
            if (
                policyRoutes[i].componentType == StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR
            ) policyEntropy = policyRoutes[i].component;
        }
        require(policyEntropy != address(0));
        _legacy();
        IStreamMetadataServingFacts.ServingFacts memory f;
        f.configured = true;
        f.mode = keccak256("ONCHAIN");
        f.scriptBytes = 17;
        f.presentationProfile = keccak256("6529STREAM_ROUTER_STABLE_PRESENTATION_V1");
        route.set("collectionServingFacts(uint256)", abi.encode(f));
        StreamFinalityCurrentComponentRoute[] memory oldRoutes =
            discovery.requireCurrentRoutes(publication.scope, false);
        for (uint256 i; i < 9; ++i) {
            if (oldRoutes[i].componentType == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER) {
                require(oldRoutes[i].component == oldConfig.targets[9]);
            }
            if (oldRoutes[i].componentType == StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR) {
                require(oldRoutes[i].component != policyEntropy);
            }
        }
    }

    function testDiscoverySelectedIdentityDoesNotBypassOriginalFrozenComponentRead() public {
        _ready();
        StreamFinalityDiscoveryTypes.Configuration memory c = _discoveryConfig();
        Discovery discovery = new Discovery(c, provider.finalitySourceConfigurationHash());
        _activateDiscovery(discovery, c);
        StreamFinalityCurrentComponentRoute[] memory routes =
            discovery.requireCurrentRoutes(publication.scope, false);
        uint256 index = 9;
        for (uint256 i; i < 9; ++i) {
            if (routes[i].componentType == StreamFinalityDomains.COMPONENT_REFERENCE_RENDER) {
                index = i;
            }
        }
        require(index < 9);
        _referenceState(policyConfig.targets[9], false);
        vm.expectRevert(
            abi.encodeWithSelector(
                Discovery.DiscoveryComponent.selector,
                policyConfig.targets[9],
                StreamFinalityDomains.COMPONENT_REFERENCE_RENDER
            )
        );
        discovery.nonSanctionComponentAt(publication.scope, index);
        _referenceState(policyConfig.targets[9], true);
        StreamFinalityComponentExpectation memory accepted =
            discovery.nonSanctionComponentAt(publication.scope, index);
        require(
            accepted.component == policyConfig.targets[9]
                && accepted.dataHash == keccak256("typed reference state")
        );
    }
}
