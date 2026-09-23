// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamFinalityViewPreservationDiscoveryV1 as ViewDiscovery
} from "./StreamFinalityViewPreservationDiscoveryV1.sol";
import {
    StreamArtistCurrentAuthorityTypes as AuthorityTypes
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamFinalityCurrentAuthority
} from "../../interfaces/stream/finality/IStreamFinalityCurrentAuthority.sol";

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

import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as PublicationBinding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamScopedPreservationPolicySnapshotDefinitionsV2 as ScopedPolicyDefinitions
} from "../records/StreamScopedPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1 as PublicationFactoryReads
} from "./StreamCurrentAuthorityScopedPreservationPolicyDiscoveryFactoryReadsV1.sol";

import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1 as CollectionFactoryReads
} from "./StreamCurrentAuthorityPreservationPolicyDiscoveryFactoryReadsV1.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV2 as CollectionPolicyDefinitions
} from "../records/StreamPreservationPolicySnapshotDefinitionsV2.sol";

/// @notice Fixed linked current/profile reads for the current-authority discovery host.
/// @dev Typed storage arguments preserve the existing host layout. Delegate execution keeps
/// the discovery host as address(this) and as the caller of every original dependency read.
/// No entrypoint accepts a worker address, selector, storage cast, or readiness cache.
library StreamCurrentAuthorityFullPreservationPolicyDiscoveryReadsV1 {
    struct Context {
        address core;
        address scopeEvidenceProvider;
        uint256 deploymentChainId;
        bytes32 sourceConfigurationHash;
        Profiles.Profile[2] profiles;
        CollectionBinding.CollectionFactoryBinding collectionBinding;
        address collectionEntropyFactory;
        bytes32 collectionEntropyCodeHash;
        PublicationBinding.FactoryBinding publicationBinding;
        address scopedPolicyEntropyFactory;
        bytes32 scopedPolicyEntropyCodeHash;
    }

    error DiscoveryConfiguration(address target);
    error DiscoveryDependency(address target);
    error DiscoveryUnsupportedProfile();

    function current(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(
            address => bytes32
        ) storage pins,
        Context memory x,
        StreamFinalityScope memory scope,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) public view returns (AuthorityTypes.Route memory authority) {
        if (block.chainid != x.deploymentChainId) {
            revert DiscoveryUnsupportedProfile();
        }
        StreamMetadataSubjects.scopeSubject(x.deploymentChainId, x.core, scope);
        c = scopeConfiguration(storedConfiguration, pins, x, scope);
        _pin(pins, c.core);
        _pin(pins, c.metadata);
        _pin(pins, c.router);
        _pin(pins, c.provider);
        _pin(pins, c.membership);
        _pin(pins, c.entropyFactory);
        _pin(pins, c.metadataAdapter);
        pinReference(storedConfiguration, pins, x, scope, c.referenceRender);
        _pin(pins, c.artist);
        for (uint256 i; i < 6; ++i) {
            _pin(pins, c.routerAdapters[i]);
        }
        if (
            c.finalityRegistry.code.length == 0
                || c.finalityRegistry.codehash != c.finalityRegistryCodeHash
        ) {
            revert DiscoveryDependency(c.finalityRegistry);
        }
        _address(storedConfiguration, c.finalityRegistry, "scopeEvidenceProvider()", c.provider);
        _address(storedConfiguration, c.finalityRegistry, "finalityDiscovery()", address(this));
        _address(storedConfiguration, c.finalityRegistry, "coreReads()", c.core);
        _address(storedConfiguration, c.finalityRegistry, "metadataReads()", c.metadata);
        _address(storedConfiguration, c.finalityRegistry, "sanctionReads()", c.artist);
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
                    != StreamMetadataSubjects.scopeSubject(x.deploymentChainId, x.core, scope)
                || membership.membershipHash == 0 || membership.tokenCount == 0
        ) revert DiscoveryUnsupportedProfile();
        _serving(storedConfiguration, pins, x, scope, c);
        // Keep c.artist as the historical Finality/Router anchor. Current authority is separate.
        authority = _authority(storedConfiguration, pins, scope.collectionId, c);
        StreamMetadataRecoveryRoutes.requireCurrentHost(
            c.core,
            keccak256("ARTIST_REGISTRY"),
            authority.registry,
            keccak256("ARTIST_REGISTRY"),
            type(IStreamArtistMintConsent).interfaceId
        );
    }

    function scopeConfiguration(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(address => bytes32) storage pins,
        Context memory x,
        StreamFinalityScope memory scope
    ) public view returns (StreamFinalityDiscoveryTypes.Configuration memory c) {
        Profiles.Profile memory p = _selectedProfile(storedConfiguration, pins, x, scope);
        c = storedConfiguration;
        c.referenceRender = p.referenceRender;
        c.entropyFactory = p.entropyFactory;
    }

    function pinReference(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(
            address => bytes32
        ) storage pins,
        Context memory x,
        StreamFinalityScope memory scope,
        address target
    ) public view {
        if (scope.scopeType == StreamFinalityScopeType.VIEW) {
            Profiles.Profile memory selected = _selectedProfile(storedConfiguration, pins, x, scope);
            if (target != selected.referenceRender) revert DiscoveryDependency(target);
            _exact(target, selected.referenceRenderCodeHash);
            return;
        }
        if (pins[target] != 0) {
            _pin(pins, target);
            return;
        }
        Profiles.Profile memory p = _selectedProfile(storedConfiguration, pins, x, scope);
        if (
            (p.profileHash != ScopedPolicyDefinitions.PROFILE_HASH
                    && p.profileHash != CollectionPolicyDefinitions.PROFILE_HASH)
                || target != p.referenceRender || p.referenceRenderCodeHash == 0
                || target.code.length == 0 || target.codehash != p.referenceRenderCodeHash
        ) {
            revert DiscoveryDependency(target);
        }
    }

    function _selectedProfile(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(address => bytes32) storage pins,
        Context memory x,
        StreamFinalityScope memory scope
    ) private view returns (Profiles.Profile memory p) {
        StreamMetadataSubjects.scopeSubject(x.deploymentChainId, x.core, scope);
        _pin(pins, x.scopeEvidenceProvider);
        if (
            abi.decode(
                    _read(
                        x.scopeEvidenceProvider,
                        abi.encodeCall(Catalogue.finalitySourceConfigurationHash, ()),
                        32,
                        storedConfiguration.readGas
                    ),
                    (bytes32)
                ) != x.sourceConfigurationHash
        ) revert DiscoveryDependency(x.scopeEvidenceProvider);
        // VIEW authenticates its fixed complete binding directly. The token catalogue path
        // has a larger nested reservation and is not a VIEW discovery dependency.
        if (scope.scopeType == StreamFinalityScopeType.VIEW) {
            return ViewDiscovery.profile(storedConfiguration, scope);
        }
        bytes memory raw = _read(
            x.scopeEvidenceProvider,
            abi.encodeCall(Catalogue.finalitySourcesForScope, (scope)),
            384,
            _sourceSelectionGas(storedConfiguration)
        );
        Profiles.Sources memory selected = abi.decode(raw, (Profiles.Sources));
        if (
            keccak256(raw) != keccak256(abi.encode(selected))
                || keccak256(abi.encode(selected.scope)) != keccak256(abi.encode(scope))
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        if (selected.profile.profileHash == CollectionPolicyDefinitions.PROFILE_HASH) {
            Profiles.Profile memory actual = CollectionFactoryReads.current(
                x.collectionBinding, x.collectionEntropyFactory, x.collectionEntropyCodeHash, scope
            );
            if (keccak256(abi.encode(selected.profile)) != keccak256(abi.encode(actual))) {
                revert DiscoveryUnsupportedProfile();
            }
            _profileBindings(storedConfiguration, actual, true);
            return actual;
        }
        if (selected.profile.profileHash == ScopedPolicyDefinitions.PROFILE_HASH) {
            Profiles.Profile memory actual = PublicationFactoryReads.current(
                x.publicationBinding,
                x.scopedPolicyEntropyFactory,
                x.scopedPolicyEntropyCodeHash,
                scope
            );
            if (keccak256(abi.encode(selected.profile)) != keccak256(abi.encode(actual))) {
                revert DiscoveryUnsupportedProfile();
            }
            _profileBindings(storedConfiguration, actual, false);
            return actual;
        }
        uint8 index = 3;
        for (uint8 i; i < 2; ++i) {
            if (selected.profile.profileHash == x.profiles[i].profileHash) index = i;
        }
        if (
            index == 3
                || keccak256(abi.encode(selected.profile))
                    != keccak256(abi.encode(x.profiles[index]))
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
        _pin(pins, p.referenceRender);
        _pin(pins, p.snapshots);
        _pin(pins, p.entropyFactory);
    }

    function _profileBindings(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        Profiles.Profile memory p,
        bool collection
    ) private view {
        StreamFinalityDiscoveryTypes.Configuration memory c = storedConfiguration;
        _exact(p.referenceRender, p.referenceRenderCodeHash);
        _exact(p.snapshots, p.snapshotsCodeHash);
        _exact(p.entropyFactory, p.entropyFactoryCodeHash);
        _address(storedConfiguration, p.snapshots, "core()", c.core);
        _address(storedConfiguration, p.snapshots, "metadataHost()", c.metadata);
        _address(storedConfiguration, p.referenceRender, "core()", c.core);
        _address(storedConfiguration, p.referenceRender, "metadataHost()", c.metadata);
        _address(storedConfiguration, p.referenceRender, "metadataRouter()", c.router);
        _address(storedConfiguration, p.referenceRender, "snapshots()", p.snapshots);
        _address(storedConfiguration, p.entropyFactory, "core()", c.core);
        _address(storedConfiguration, p.entropyFactory, "metadataHost()", c.metadata);
        _address(storedConfiguration, p.entropyFactory, "scopeMembershipHost()", c.membership);
        _supports(
            storedConfiguration,
            p.entropyFactory,
            type(IStreamFinalityEntropySourceFactory).interfaceId
        );
        _supports(
            storedConfiguration,
            p.entropyFactory,
            type(IStreamFinalityCurrentEntropyRoute).interfaceId
        );
        _supports(
            storedConfiguration,
            p.referenceRender,
            type(IStreamArtworkScopedFinalityComponent).interfaceId
        );
        if (collection) {
            _supports(
                storedConfiguration,
                p.referenceRender,
                type(IStreamArtworkFinalityComponent).interfaceId
            );
        }
    }

    function _exact(address target, bytes32 expected) private view {
        if (expected == 0 || target.code.length == 0 || target.codehash != expected) {
            revert DiscoveryDependency(target);
        }
    }

    function _sourceSelectionGas(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration
    ) private view returns (uint256 cap) {
        // Configured outer budget covers the provider's cold constructor-state projection as
        // well as its nested graph read. A fixed small slack is not an execution-cost bound.
        return storedConfiguration.componentGas;
    }

    function _serving(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(
            address => bytes32
        ) storage pins,
        Context memory x,
        StreamFinalityScope memory scope,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) private view {
        if (scope.scopeType == StreamFinalityScopeType.VIEW) {
            ViewDiscovery.requireServing(c, scope);
            return;
        }
        Profiles.Profile memory p = _selectedProfile(storedConfiguration, pins, x, scope);
        if (p.profileHash == x.profiles[0].profileHash) {
            IStreamMetadataServingFacts.ServingFacts memory original =
                StreamFinalityRouterEvidence.serving(
                    StreamFinalityRouterEvidence.Config(
                        c.core, c.router, x.deploymentChainId, c.readGas, c.componentGas
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

    function _pin(mapping(address => bytes32) storage pins, address target) private view {
        if (target.code.length == 0 || target.codehash != pins[target]) {
            revert DiscoveryDependency(target);
        }
    }

    function _address(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        address target,
        string memory signature,
        address expected
    ) private view {
        if (
            abi.decode(
                    _read(
                        target, abi.encodeWithSignature(signature), 32, storedConfiguration.readGas
                    ),
                    (address)
                ) != expected
        ) {
            revert DiscoveryConfiguration(target);
        }
    }

    function _supports(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        address target,
        bytes4 id
    ) private view {
        if (
            abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            storedConfiguration.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (id)),
                            32,
                            storedConfiguration.readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            storedConfiguration.readGas
                        ),
                        (uint256)
                    ) != 0
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

    function _authority(
        StreamFinalityDiscoveryTypes.Configuration storage storedConfiguration,
        mapping(
            address => bytes32
        ) storage pins,
        uint256 collectionId,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) private view returns (AuthorityTypes.Route memory authority) {
        _supports(
            storedConfiguration,
            c.finalityRegistry,
            type(IStreamFinalityCurrentAuthority).interfaceId
        );
        if (
            abi.decode(
                    _read(
                        c.finalityRegistry,
                        abi.encodeCall(IStreamFinalityCurrentAuthority.currentAuthorityProfile, ()),
                        32,
                        c.readGas
                    ),
                    (bytes32)
                ) != AuthorityTypes.PROFILE
        ) revert DiscoveryConfiguration(c.finalityRegistry);
        bytes memory raw = _read(
            c.finalityRegistry,
            abi.encodeCall(IStreamFinalityCurrentAuthority.currentArtistAuthority, (collectionId)),
            320,
            c.componentGas
        );
        authority = abi.decode(raw, (AuthorityTypes.Route));
        if (
            keccak256(raw) != keccak256(abi.encode(authority))
                || authority.finalityRegistry != c.finalityRegistry
                || authority.finalityCodeHash != c.finalityRegistryCodeHash
                || authority.provider != c.provider
                || authority.providerCodeHash != pins[c.provider] || authority.selectionHash == 0
                || authority.presentationHash == 0
        ) revert DiscoveryConfiguration(c.finalityRegistry);
        _currentPin(authority);
    }

    function _currentPin(AuthorityTypes.Route memory authority) private view {
        if (
            authority.registry.code.length == 0 || authority.registryCodeHash == 0
                || authority.registry.codehash != authority.registryCodeHash
                || authority.coordinator.code.length == 0 || authority.coordinatorCodeHash == 0
                || authority.coordinator.codehash != authority.coordinatorCodeHash
        ) revert DiscoveryDependency(authority.registry);
    }
}
