// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamFinalityRouterEvidence.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityProfileSourceReads as ProfileReads
} from "./StreamFinalityProfileSourceReads.sol";
import {
    IStreamStaticMetadataRouter as StaticRouter
} from "../../interfaces/stream/metadata/IStreamStaticMetadataRouter.sol";
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingEvidenceProvider.sol";
import "../../interfaces/stream/finality/IStreamFinalityDiscoverySources.sol";
import "../metadata/StreamMetadataRecoveryRoutes.sol";
import "../metadata/StreamMetadataSubjects.sol";
import "../../interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import "../../interfaces/stream/finality/IStreamFinalityEvidenceDiscoveryBinding.sol";
import "../../interfaces/stream/finality/IStreamNonSanctionFinalityDiscovery.sol";
import "../../interfaces/stream/finality/IStreamFinalityServingHostAdapter.sol";
import "../../interfaces/stream/finality/IStreamFinalityRouterEvidenceBinding.sol";
import "../../interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import "../../interfaces/stream/finality/IStreamFinalityScopeMembership.sol";
import "../../interfaces/stream/finality/IStreamFinalitySanctionReads.sol";
import "../../interfaces/stream/artist/IStreamArtistMintConsent.sol";

/// @notice Fixed full-scope discovery for constructor-pinned original, scoped STATIC and policy V2 sources.
/// @dev This sibling preserves original discovery/component ABI. The original implementation is
/// untouched. Source selection is acyclic and distinct from independent component validation.
/// @dev Derives nine independent non-sanction components and one original artist component.
/// No caller component list is accepted. This layer does not implement missing evidence producers
/// or widen their scope support. Historical finalized routes belong to the original Registry.
contract StreamFinalityProfileDiscovery is
    IERC165,
    IStreamArtworkFinalityDiscovery,
    IStreamArtworkScopedFinalityDiscovery,
    IStreamNonSanctionFinalityDiscovery,
    IStreamFinalityCurrentComponentRoutes,
    IStreamFinalityEvidenceDiscoveryBinding
{
    address public immutable core;
    address public immutable metadataHost;
    address public immutable override scopeEvidenceProvider;
    uint256 public immutable deploymentChainId;
    // All other configuration, including reciprocal late-runtime pins, is constructor-only
    // storage. No method mutates it and no configuration hash is embedded into runtime code.
    StreamFinalityDiscoveryTypes.Configuration private _configuration;
    mapping(address => bytes32) private _codeHashes;
    Profiles.Profile[3] private _profiles;
    // Storage prevents a reciprocal runtime-hash cycle. Constructor-only; no setter exists.
    bytes32 public sourceConfigurationHash;
    error DiscoveryConfiguration(address target);
    error DiscoveryDependency(address target);
    error DiscoveryUnsupportedProfile();
    error DiscoveryComponent(address target, bytes32 family);
    error DiscoveryIndex(uint256 index);

    constructor(
        StreamFinalityDiscoveryTypes.Configuration memory c,
        bytes32 expectedSourceConfigurationHash
    ) {
        if (
            c.readGas < 50000 || c.componentGas < c.readGas || c.entropyGas < c.readGas
                || c.finalityRegistry == address(0) || c.finalityRegistryCodeHash == 0
        ) {
            revert DiscoveryConfiguration(c.finalityRegistry);
        }
        core = c.core;
        metadataHost = c.metadata;
        scopeEvidenceProvider = c.provider;
        deploymentChainId = block.chainid;
        _configuration = c;
        _admit(c.core);
        _admit(c.metadata);
        _admit(c.router);
        _admit(c.provider);
        _admit(c.membership);
        _admit(c.entropyFactory);
        _admit(c.metadataAdapter);
        _admit(c.referenceRender);
        _admit(c.artist);
        for (uint256 i; i < 6; ++i) {
            _admit(c.routerAdapters[i]);
        }
        _address(c.provider, "core()", c.core);
        _address(c.provider, "metadataHost()", c.metadata);
        _address(c.provider, "metadataRouter()", c.router);
        _address(c.provider, "scopeMembershipHost()", c.membership);
        _address(c.membership, "core()", c.core);
        _address(c.membership, "metadataHost()", c.metadata);
        _address(c.entropyFactory, "core()", c.core);
        _address(c.entropyFactory, "metadataHost()", c.metadata);
        _address(c.entropyFactory, "scopeMembershipHost()", c.membership);
        _address(c.referenceRender, "core()", c.core);
        _address(c.referenceRender, "metadataHost()", c.metadata);
        _address(c.referenceRender, "metadataRouter()", c.router);
        _address(c.provider, "referenceRenderHost()", c.referenceRender);
        _address(c.provider, "entropySourceFactory()", c.entropyFactory);
        address snapshots = abi.decode(
            _read(
                c.provider,
                abi.encodeCall(IStreamFinalityDiscoverySources.snapshotHost, ()),
                32,
                c.readGas
            ),
            (address)
        );
        if (snapshots.code.length == 0) revert DiscoveryConfiguration(snapshots);
        _address(c.referenceRender, "snapshots()", snapshots);
        _supports(c.provider, type(IStreamFinalityServingEvidenceProvider).interfaceId);
        _supports(c.provider, type(IStreamFinalityRouterEvidenceBinding).interfaceId);
        _supports(c.provider, type(IStreamFinalityDiscoverySources).interfaceId);
        _supports(c.entropyFactory, type(IStreamFinalityEntropySourceFactory).interfaceId);
        _supports(c.entropyFactory, type(IStreamFinalityCurrentEntropyRoute).interfaceId);
        _supports(c.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
        _supports(c.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _supports(c.artist, type(IStreamArtworkFinalityComponent).interfaceId);
        _supports(c.artist, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        for (uint256 i; i < 6; ++i) {
            _adapter(c.routerAdapters[i], c.router, _routerFamily(i));
        }
        _adapter(c.metadataAdapter, c.metadata, StreamFinalityDomains.COMPONENT_COLLECTION_METADATA);
        _initializeProfiles(expectedSourceConfigurationHash);
        // No original Registry or Coordinator call: both may be constructed later.
    }

    function supportsInterface(bytes4 id) external pure override returns (bool) {
        return id == type(IERC165).interfaceId
            || id == type(IStreamArtworkFinalityDiscovery).interfaceId
            || id == type(IStreamArtworkScopedFinalityDiscovery).interfaceId
            || id == type(IStreamNonSanctionFinalityDiscovery).interfaceId
            || id == type(IStreamFinalityCurrentComponentRoutes).interfaceId
            || id == type(IStreamFinalityEvidenceDiscoveryBinding).interfaceId;
    }

    function configuration()
        external
        view
        returns (StreamFinalityDiscoveryTypes.Configuration memory)
    {
        return _configuration;
    }

    function dependencyCodeHash(address target) external view returns (bytes32) {
        return _codeHashes[target];
    }

    function finalityComponentCount(uint256 cid) external view override returns (uint256) {
        _current(_collection(cid), _configuration);
        return 10;
    }

    function finalityComponentAt(uint256 cid, uint256 index)
        external
        view
        override
        returns (StreamFinalityComponentExpectation memory)
    {
        return _at(_collection(cid), index, true);
    }

    function finalityDiscoveryHash(uint256 cid) external view override returns (bytes32) {
        return _hash(_components(_collection(cid), true));
    }

    function finalityComponentCountForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        _current(scope, _configuration);
        return 10;
    }

    function finalityComponentAtForScope(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (StreamFinalityComponentExpectation memory)
    {
        return _at(scope, index, true);
    }

    function finalityDiscoveryHashForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        return _hash(_components(scope, true));
    }

    function nonSanctionDiscoveryFacts(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256 count, bytes32 hash)
    {
        StreamFinalityComponentExpectation[] memory entries = _components(scope, false);
        return (entries.length, _hash(entries));
    }

    function nonSanctionComponentAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        override
        returns (StreamFinalityComponentExpectation memory)
    {
        return _at(scope, index, false);
    }

    /// @inheritdoc IStreamFinalityCurrentComponentRoutes
    function requireCurrentRoutes(StreamFinalityScope calldata scope, bool includeSanction)
        external
        view
        override
        returns (StreamFinalityCurrentComponentRoute[] memory routes)
    {
        _current(scope, _configuration);
        uint8[] memory order = _order(includeSanction);
        routes = new StreamFinalityCurrentComponentRoute[](order.length);
        for (uint256 i; i < order.length; ++i) {
            routes[i] = _identity(scope, order[i]);
        }
    }

    function _identity(StreamFinalityScope memory scope, uint8 index)
        private
        view
        returns (StreamFinalityCurrentComponentRoute memory route)
    {
        StreamFinalityDiscoveryTypes.Configuration memory c = _scopeConfiguration(scope);
        bytes32 family = _family(index);
        bytes4 expected = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        address target;
        if (index < 7) {
            target = index < 6 ? c.routerAdapters[index] : c.metadataAdapter;
            _selection(target);
        } else if (index == 7) {
            route = abi.decode(
                _read(
                    c.entropyFactory,
                    abi.encodeCall(IStreamFinalityCurrentEntropyRoute.requireCurrentRoute, (scope)),
                    128,
                    c.entropyGas
                ),
                (StreamFinalityCurrentComponentRoute)
            );
            if (
                route.componentType != family || route.interfaceId != expected
                    || route.component.code.length == 0
                    || route.codeHash != route.component.codehash
            ) {
                revert DiscoveryComponent(route.component, family);
            }
            _supports(route.component, expected);
            return route;
        } else {
            target = index == 8 ? c.referenceRender : c.artist;
            if (
                index == 9
                    && abi.decode(
                            _read(
                                c.artist,
                                abi.encodeCall(
                                    IStreamFinalitySanctionReads.collectionSanctionComponentType,
                                    (scope.collectionId)
                                ),
                                32,
                                c.componentGas
                            ),
                            (bytes32)
                        ) != family
            ) revert DiscoveryUnsupportedProfile();
        }
        _pin(target);
        _supports(target, expected);
        return StreamFinalityCurrentComponentRoute(family, target, expected, target.codehash);
    }

    function _components(StreamFinalityScope memory scope, bool full)
        private
        view
        returns (StreamFinalityComponentExpectation[] memory entries)
    {
        _current(scope, _configuration);
        uint8[] memory order = _order(full);
        entries = new StreamFinalityComponentExpectation[](order.length);
        for (uint256 i; i < order.length; ++i) {
            entries[i] = _route(scope, order[i]);
        }
    }

    function _route(StreamFinalityScope memory scope, uint8 index)
        private
        view
        returns (StreamFinalityComponentExpectation memory entry)
    {
        StreamFinalityDiscoveryTypes.Configuration memory c = _scopeConfiguration(scope);
        bytes32 family = _family(index);
        if (index < 7) {
            address adapter = index < 6 ? c.routerAdapters[index] : c.metadataAdapter;
            _selection(adapter);
            return _component(adapter, family, scope);
        }
        if (index == 7) {
            entry = abi.decode(
                _read(
                    c.entropyFactory,
                    abi.encodeCall(
                        IStreamFinalityEntropySourceFactory.requireCurrentComponent, (scope)
                    ),
                    224,
                    c.entropyGas
                ),
                (StreamFinalityComponentExpectation)
            );
            _expectation(entry, family, entry.component);
            bytes4 expected = scope.scopeType == StreamFinalityScopeType.COLLECTION
                ? type(IStreamArtworkFinalityComponent).interfaceId
                : type(IStreamArtworkScopedFinalityComponent).interfaceId;
            if (entry.interfaceId != expected) revert DiscoveryComponent(entry.component, family);
            _supports(entry.component, expected);
            return entry;
        }
        if (index == 8) return _component(c.referenceRender, family, scope);
        // Only the full projection asks for the artist's signed record.
        bytes32 actual = abi.decode(
            _read(
                c.artist,
                abi.encodeCall(
                    IStreamFinalitySanctionReads.collectionSanctionComponentType,
                    (scope.collectionId)
                ),
                32,
                c.componentGas
            ),
            (bytes32)
        );
        if (actual != family) revert DiscoveryUnsupportedProfile();
        return _component(c.artist, family, scope);
    }

    function _order(bool full) private pure returns (uint8[] memory order) {
        order = new uint8[](full ? 10 : 9);
        for (uint8 i; i < order.length; ++i) {
            order[i] = i;
        }
        for (uint256 i = 1; i < order.length; ++i) {
            for (uint256 j = i; j > 0 && _family(order[j]) < _family(order[j - 1]); --j) {
                (order[j], order[j - 1]) = (order[j - 1], order[j]);
            }
        }
    }

    function _family(uint8 index) private pure returns (bytes32) {
        if (index < 6) return _routerFamily(index);
        if (index == 6) return StreamFinalityDomains.COMPONENT_COLLECTION_METADATA;
        if (index == 7) return StreamFinalityDomains.COMPONENT_ENTROPY_COORDINATOR;
        if (index == 8) return StreamFinalityDomains.COMPONENT_REFERENCE_RENDER;
        return StreamFinalityDomains.COMPONENT_ARTIST_SANCTION;
    }

    function _current(
        StreamFinalityScope memory scope,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) private view {
        if (block.chainid != deploymentChainId) {
            revert DiscoveryUnsupportedProfile();
        }
        StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        c = _scopeConfiguration(scope);
        _pin(c.core);
        _pin(c.metadata);
        _pin(c.router);
        _pin(c.provider);
        _pin(c.membership);
        _pin(c.entropyFactory);
        _pin(c.metadataAdapter);
        _pin(c.referenceRender);
        _pin(c.artist);
        for (uint256 i; i < 6; ++i) {
            _pin(c.routerAdapters[i]);
        }
        if (
            c.finalityRegistry.code.length == 0
                || c.finalityRegistry.codehash != c.finalityRegistryCodeHash
        ) {
            revert DiscoveryDependency(c.finalityRegistry);
        }
        _address(c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _address(c.finalityRegistry, "finalityDiscovery()", address(this));
        _address(c.finalityRegistry, "coreReads()", c.core);
        _address(c.finalityRegistry, "metadataReads()", c.metadata);
        _address(c.finalityRegistry, "sanctionReads()", c.artist);
        _read(
            c.provider,
            abi.encodeCall(
                IStreamFinalityRouterEvidenceBinding.requireCurrentRouterCandidate,
                (scope.collectionId, c.finalityRegistry)
            ),
            0,
            c.componentGas
        );
        StreamScopeMembershipFacts memory membership = abi.decode(
            _read(
                c.membership,
                abi.encodeCall(IStreamFinalityScopeMembership.requireScopeMembership, (scope)),
                256,
                c.componentGas
            ),
            (StreamScopeMembershipFacts)
        );
        if (
            membership.scopeSubject
                    != StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope)
                || membership.membershipHash == 0 || membership.tokenCount == 0
        ) revert DiscoveryUnsupportedProfile();
        _serving(scope, c);
        // This confirms the selected artist module without asking for its unsigned sanction.
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            c.core,
            keccak256("ARTIST_REGISTRY"),
            c.artist,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
    }

    function _initializeProfiles(bytes32 expected) private {
        StreamFinalityDiscoveryTypes.Configuration memory c = _configuration;
        _supports(c.provider, type(Profiles).interfaceId);
        sourceConfigurationHash = abi.decode(
            _read(
                c.provider,
                abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
                32,
                c.readGas
            ),
            (bytes32)
        );
        if (expected == 0 || sourceConfigurationHash != expected) {
            revert DiscoveryConfiguration(c.provider);
        }
        for (uint8 i; i < 3; ++i) {
            bytes memory raw = _read(
                c.provider, abi.encodeCall(Profiles.finalitySourceProfile, (i)), 256, c.readGas
            );
            Profiles.Profile memory p = abi.decode(raw, (Profiles.Profile));
            if (
                keccak256(raw) != keccak256(abi.encode(p))
                    || p.profileHash != ProfileReads.profileHash(i) || p.configurationHash == 0
            ) revert DiscoveryConfiguration(c.provider);
            _admitExact(p.referenceRender, p.referenceRenderCodeHash);
            _admitExact(p.snapshots, p.snapshotsCodeHash);
            _admitExact(p.entropyFactory, p.entropyFactoryCodeHash);
            _address(p.snapshots, "core()", c.core);
            _address(p.snapshots, "metadataHost()", c.metadata);
            _address(p.referenceRender, "core()", c.core);
            _address(p.referenceRender, "metadataHost()", c.metadata);
            _address(p.referenceRender, "metadataRouter()", c.router);
            _address(p.referenceRender, "snapshots()", p.snapshots);
            _address(p.entropyFactory, "core()", c.core);
            _address(p.entropyFactory, "metadataHost()", c.metadata);
            _address(p.entropyFactory, "scopeMembershipHost()", c.membership);
            _supports(p.entropyFactory, type(IStreamFinalityEntropySourceFactory).interfaceId);
            _supports(p.entropyFactory, type(IStreamFinalityCurrentEntropyRoute).interfaceId);
            _supports(p.referenceRender, type(IStreamArtworkScopedFinalityComponent).interfaceId);
            if (i != 1) {
                _supports(p.referenceRender, type(IStreamArtworkFinalityComponent).interfaceId);
            }
            if (
                i == 0
                    && (p.referenceRender != c.referenceRender
                        || p.entropyFactory != c.entropyFactory)
            ) {
                revert DiscoveryConfiguration(c.provider);
            }
            _profiles[i] = p;
        }
    }

    function _admitExact(address target, bytes32 expected) private {
        if (
            expected == 0 || target.code.length == 0 || target.codehash != expected
                || (_codeHashes[target] != 0 && _codeHashes[target] != expected)
        ) revert DiscoveryConfiguration(target);
        _codeHashes[target] = expected;
    }

    function _selectedProfile(StreamFinalityScope memory scope)
        private
        view
        returns (Profiles.Profile memory p)
    {
        StreamMetadataSubjects.scopeSubject(deploymentChainId, core, scope);
        _pin(scopeEvidenceProvider);
        if (
            abi.decode(
                    _read(
                        scopeEvidenceProvider,
                        abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
                        32,
                        _configuration.readGas
                    ),
                    (bytes32)
                ) != sourceConfigurationHash
        ) revert DiscoveryDependency(scopeEvidenceProvider);
        bytes memory raw = _read(
            scopeEvidenceProvider,
            abi.encodeCall(Profiles.finalitySourcesForScope, (scope)),
            384,
            _configuration.readGas
        );
        Profiles.Sources memory selected = abi.decode(raw, (Profiles.Sources));
        if (
            keccak256(raw) != keccak256(abi.encode(selected))
                || keccak256(abi.encode(selected.scope)) != keccak256(abi.encode(scope))
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        uint8 index = 3;
        for (uint8 i; i < 3; ++i) {
            if (selected.profile.profileHash == _profiles[i].profileHash) index = i;
        }
        if (
            index == 3
                || keccak256(abi.encode(selected.profile))
                    != keccak256(abi.encode(_profiles[index]))
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        if (scope.scopeType == StreamFinalityScopeType.COLLECTION) {
            if (index == 1) revert DiscoveryUnsupportedProfile();
        } else if (
            scope.scopeType == StreamFinalityScopeType.TOKEN
                || scope.scopeType == StreamFinalityScopeType.RELEASE
                || scope.scopeType == StreamFinalityScopeType.SEASON
        ) {
            if (index != 1) revert DiscoveryUnsupportedProfile();
        } else {
            revert DiscoveryUnsupportedProfile();
        }
        p = selected.profile;
        _pin(p.referenceRender);
        _pin(p.snapshots);
        _pin(p.entropyFactory);
    }

    function _scopeConfiguration(StreamFinalityScope memory scope)
        private
        view
        returns (StreamFinalityDiscoveryTypes.Configuration memory c)
    {
        Profiles.Profile memory p = _selectedProfile(scope);
        c = _configuration;
        c.referenceRender = p.referenceRender;
        c.entropyFactory = p.entropyFactory;
    }

    function _serving(
        StreamFinalityScope memory scope,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) private view {
        Profiles.Profile memory p = _selectedProfile(scope);
        if (p.profileHash == _profiles[0].profileHash) {
            IStreamMetadataServingFacts.ServingFacts memory original =
                StreamFinalityRouterEvidence.serving(
                    StreamFinalityRouterEvidence.Config(
                        c.core, c.router, deploymentChainId, c.readGas, c.componentGas
                    ),
                    scope.collectionId
                );
            if (original.mode != keccak256("ONCHAIN")) revert DiscoveryUnsupportedProfile();
            return;
        }
        bytes memory raw = _read(
            c.router,
            abi.encodeCall(
                IStreamMetadataServingFacts.collectionServingFacts, (scope.collectionId)
            ),
            512,
            c.componentGas
        );
        IStreamMetadataServingFacts.ServingFacts memory f =
            abi.decode(raw, (IStreamMetadataServingFacts.ServingFacts));
        if (
            keccak256(raw) != keccak256(abi.encode(f)) || !f.configured
                || f.mode != keccak256("ONCHAIN")
                || f.presentationProfile != keccak256("6529STREAM_STATIC_METADATA_SELECTION_V1")
        ) revert DiscoveryUnsupportedProfile();
        raw = _read(
            c.router,
            abi.encodeCall(StaticRouter.staticMetadataActivation, (scope.collectionId)),
            96,
            c.readGas
        );
        (bytes32 record, uint64 revision, bytes32 head) =
            abi.decode(raw, (bytes32, uint64, bytes32));
        if (
            keccak256(raw) != keccak256(abi.encode(record, revision, head)) || record == 0
                || revision == 0
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        // No frozen=true shortcut: the selected metadata and all six STATIC adapters still
        // prove their own exact current/locked scope facts, and Registry rechecks each result.
    }

    function _adapter(address target, address host, bytes32 family) private view {
        _supports(target, type(IStreamFinalityServingHostAdapter).interfaceId);
        _supports(target, type(IStreamArtworkFinalityComponent).interfaceId);
        _supports(target, type(IStreamArtworkScopedFinalityComponent).interfaceId);
        _address(target, "core()", core);
        _address(target, "host()", host);
        _address(target, "metadataHost()", metadataHost);
        _address(target, "evidenceProvider()", scopeEvidenceProvider);
        if (
            abi.decode(
                    _read(
                        target,
                        abi.encodeCall(IStreamFinalityHostAdapter.componentType, ()),
                        32,
                        _configuration.readGas
                    ),
                    (bytes32)
                ) != family
        ) revert DiscoveryConfiguration(target);
    }

    function _selection(address target) private view {
        _pin(target);
        _read(
            target,
            abi.encodeCall(IStreamFinalityHostAdapter.requireCurrentSelection, ()),
            0,
            _configuration.componentGas
        );
    }

    function _component(address target, bytes32 family, StreamFinalityScope memory scope)
        private
        view
        returns (StreamFinalityComponentExpectation memory e)
    {
        _pin(target);
        bytes4 expectedInterface = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        _supports(target, expectedInterface);
        bytes memory input = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (scope.collectionId))
            : abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope));
        StreamFinalityComponentState memory s = abi.decode(
            _read(target, input, 256, _configuration.componentGas), (StreamFinalityComponentState)
        );
        if (!s.frozen || s.interfaceId != expectedInterface) {
            revert DiscoveryComponent(target, family);
        }
        e = StreamFinalityComponentExpectation(
            s.componentType,
            s.component,
            s.interfaceId,
            s.codeHash,
            s.moduleVersion,
            s.manifestHash,
            s.dataHash
        );
        _expectation(e, family, target);
    }

    function _expectation(
        StreamFinalityComponentExpectation memory e,
        bytes32 family,
        address target
    ) private view {
        if (
            target.code.length == 0 || e.component != target || e.codeHash != target.codehash
                || e.componentType != family || e.interfaceId == 0 || e.moduleVersion == 0
                || e.manifestHash == 0 || e.dataHash == 0
        ) revert DiscoveryComponent(target, family);
    }

    function _at(StreamFinalityScope memory scope, uint256 index, bool full)
        private
        view
        returns (StreamFinalityComponentExpectation memory)
    {
        _current(scope, _configuration);
        uint8[] memory order = _order(full);
        if (index >= order.length) revert DiscoveryIndex(index);
        // One slot only. Full hash/facts plus Registry live checks prove complete readiness.
        return _route(scope, order[index]);
    }

    function _hash(StreamFinalityComponentExpectation[] memory entries)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(StreamFinalityDomains.STREAM_FINALITY_COMPONENTS_V1, entries));
    }

    function _collection(uint256 cid) private pure returns (StreamFinalityScope memory) {
        return StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
    }

    function _routerFamily(uint256 i) private pure returns (bytes32) {
        if (i == 0) return StreamFinalityDomains.COMPONENT_METADATA_ROUTER;
        if (i == 1) return StreamFinalityDomains.COMPONENT_RENDERER;
        if (i == 2) return StreamFinalityDomains.COMPONENT_RENDER_CONTEXT;
        if (i == 3) return StreamFinalityDomains.COMPONENT_MEDIA_MANIFEST;
        if (i == 4) return StreamFinalityDomains.COMPONENT_SCRIPT_SOURCE;
        return StreamFinalityDomains.COMPONENT_DEPENDENCY_SOURCE;
    }

    function _supports(address target, bytes4 id) private view {
        if (
            abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            _configuration.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (id)),
                            32,
                            _configuration.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            _configuration.readGas
                        ),
                        (uint256)
                    ) != 0
        ) {
            revert DiscoveryConfiguration(target);
        }
    }

    function _admit(address target) private {
        if (target.code.length == 0) revert DiscoveryConfiguration(target);
        _codeHashes[target] = target.codehash;
    }

    function _pin(address target) private view {
        if (target.code.length == 0 || target.codehash != _codeHashes[target]) {
            revert DiscoveryDependency(target);
        }
    }

    function _address(address target, string memory signature, address expected) private view {
        if (
            abi.decode(
                    _read(target, abi.encodeWithSignature(signature), 32, _configuration.readGas),
                    (address)
                ) != expected
        ) {
            revert DiscoveryConfiguration(target);
        }
    }

    function _read(address target, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory)
    {
        return StreamFinalityRouterEvidence.read(target, input, size, cap);
    }
}
