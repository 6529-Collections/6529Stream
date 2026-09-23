// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArtistCurrentAuthorityTypes as AuthorityTypes
} from "../../interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamFinalityCurrentAuthority
} from "../../interfaces/stream/finality/IStreamFinalityCurrentAuthority.sol";

import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as DeferredBinding
} from "../../interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as Deferred
} from "../../interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
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
    IStreamScopedPolicyPublicationEvidenceBindingV2 as PublicationBinding
} from "../../interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as ScopedPolicyDefinitions
} from "../records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyDiscoveryFactoryReadsV2 as PublicationFactoryReads
} from "./StreamCurrentAuthorityScopedPolicyDiscoveryFactoryReadsV2.sol";

/// @notice Fixed linked profile, serving, authority and component reads for lineage discovery.
/// @dev Constructor-only values are copied by the host; the pin map remains its original storage.
/// DELEGATECALL preserves the discovery address used in reciprocal and receipt commitments.
library StreamFinalityLineageDeferredScopedPolicySelectionV2 {
    struct Context {
        StreamFinalityDiscoveryTypes.Configuration configuration;
        Profiles.Profile[2] profiles;
        Deferred.Capability deferredCapability;
        PublicationBinding.FactoryBinding publicationBinding;
        address scopedPolicyEntropyFactory;
        bytes32 scopedPolicyEntropyCodeHash;
        uint256 deploymentChainId;
        bytes32 sourceConfigurationHash;
    }

    error DiscoveryConfiguration(address target);
    error DiscoveryDependency(address target);
    error DiscoveryUnsupportedProfile();
    error DiscoveryComponent(address target, bytes32 family);

    function selected(
        Context memory x,
        mapping(address => bytes32) storage _codeHashes,
        StreamFinalityScope memory scope
    ) public view returns (Profiles.Profile memory p) {
        address core = x.configuration.core;
        address scopeEvidenceProvider = x.configuration.provider;
        StreamMetadataSubjects.scopeSubject(x.deploymentChainId, core, scope);
        _pin(_codeHashes, scopeEvidenceProvider);
        if (
            abi.decode(
                    _read(
                        scopeEvidenceProvider,
                        abi.encodeCall(Profiles.finalitySourceConfigurationHash, ()),
                        32,
                        x.configuration.readGas
                    ),
                    (bytes32)
                ) != x.sourceConfigurationHash
        ) revert DiscoveryDependency(scopeEvidenceProvider);
        bytes memory raw = _readPendingAware(
            x,
            abi.encodeCall(Profiles.finalitySourcesForScope, (scope)),
            384,
            _sourceSelectionGas(x)
        );
        Profiles.Sources memory selected = abi.decode(raw, (Profiles.Sources));
        if (
            keccak256(raw) != keccak256(abi.encode(selected))
                || keccak256(abi.encode(selected.scope)) != keccak256(abi.encode(scope))
        ) {
            revert DiscoveryUnsupportedProfile();
        }
        if (selected.profile.profileHash == ProfileReads.profileHash(2)) {
            Profiles.Profile memory bound = _boundPolicyProfile(x, _codeHashes, scope);
            if (keccak256(abi.encode(selected.profile)) != keccak256(abi.encode(bound))) {
                revert DiscoveryUnsupportedProfile();
            }
            return bound;
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
        _pin(_codeHashes, p.referenceRender);
        _pin(_codeHashes, p.snapshots);
        _pin(_codeHashes, p.entropyFactory);
    }

    function _boundPolicyProfile(
        Context memory x,
        mapping(address => bytes32) storage _codeHashes,
        StreamFinalityScope memory scope
    ) private view returns (Profiles.Profile memory p) {
        address core = x.configuration.core;
        address metadataHost = x.configuration.metadata;
        address scopeEvidenceProvider = x.configuration.provider;
        if (
            scope.scopeType != StreamFinalityScopeType.COLLECTION || scope.collectionId == 0
                || scope.tokenId != 0 || scope.scopeId != 0
        ) revert DiscoveryUnsupportedProfile();
        bytes memory raw = _read(
            scopeEvidenceProvider,
            abi.encodeCall(DeferredBinding.policyBindingCapability, ()),
            192,
            x.configuration.readGas
        );
        if (keccak256(raw) != keccak256(abi.encode(x.deferredCapability))) {
            revert DiscoveryDependency(scopeEvidenceProvider);
        }
        raw = _readPendingAware(
            x,
            abi.encodeCall(DeferredBinding.requirePolicyBinding, ()),
            2272,
            x.configuration.componentGas
        );
        Deferred.Receipt memory r = abi.decode(raw, (Deferred.Receipt));
        if (
            keccak256(raw) != keccak256(abi.encode(r))
                || r.capabilityHash != x.deferredCapability.capabilityHash || r.bindingHash == 0
                || r.actionId == 0 || r.bindingHash != Deferred.receiptHash(r)
                || r.bindingHash
                    != abi.decode(
                        _read(
                            scopeEvidenceProvider,
                            abi.encodeCall(DeferredBinding.policyBindingHash, ()),
                            32,
                            x.configuration.readGas
                        ),
                        (bytes32)
                    ) || keccak256(abi.encode(r.scope)) != keccak256(abi.encode(scope))
                || r.inventoryPlan == 0 || r.sourceFactoryDependenciesHash == 0
                || r.sourceSetDataHash == 0 || r.policy.chainId != x.deploymentChainId
                || r.policy.inventoryDependencyHash == 0 || r.policy.targets[0] != core
                || r.policy.targets[1] != metadataHost
                || r.policy.targets[2] != x.configuration.router
                || r.policy.targets[3] != x.configuration.membership
                || r.policy.targets[11] != x.configuration.artist
                || r.policy.targets[12] != x.configuration.finalityRegistry
                || r.policy.targets[13] != address(this)
        ) revert DiscoveryConfiguration(scopeEvidenceProvider);
        p = Deferred.boundProfile(
            x.deploymentChainId,
            scopeEvidenceProvider,
            r.capabilityHash,
            r.policy,
            r.output,
            r.outputCodeHash
        );
        if (keccak256(abi.encode(p)) != keccak256(abi.encode(r.profile))) {
            revert DiscoveryConfiguration(scopeEvidenceProvider);
        }
        for (uint256 i; i < 22; ++i) {
            _boundPin(_codeHashes, r.policy.targets[i], r.policy.codeHashes[i]);
        }
        _boundPin(_codeHashes, r.output, r.outputCodeHash);
        _boundPin(_codeHashes, r.sourceSet, r.sourceSetCodeHash);
        _address(x, r.output, "core()", core);
        _address(x, r.sourceSet, "core()", core);
        _address(x, r.sourceSet, "factory()", p.entropyFactory);
        if (
            abi.decode(
                        _read(
                            r.sourceSet,
                            abi.encodeWithSignature("inventoryPlan()"),
                            32,
                            x.configuration.readGas
                        ),
                        (bytes32)
                    ) != r.inventoryPlan
                || abi.decode(
                        _read(
                            r.sourceSet,
                            abi.encodeWithSignature("sourceSetDataHash()"),
                            32,
                            x.configuration.readGas
                        ),
                        (bytes32)
                    ) != r.sourceSetDataHash
                || keccak256(
                        _read(
                            r.sourceSet,
                            abi.encodeWithSignature("sourceScope()"),
                            128,
                            x.configuration.readGas
                        )
                    ) != keccak256(abi.encode(scope))
        ) revert DiscoveryDependency(r.sourceSet);
        address checkpoint = abi.decode(
            _read(
                r.output,
                abi.encodeWithSignature("contentCheckpoint()"),
                32,
                x.configuration.readGas
            ),
            (address)
        );
        if (checkpoint.code.length == 0) revert DiscoveryDependency(checkpoint);
        _address(x, checkpoint, "entropySourceSet()", r.sourceSet);
        _boundProfileBindings(x, _codeHashes, p);
    }

    function _boundProfileBindings(
        Context memory x,
        mapping(address => bytes32) storage _codeHashes,
        Profiles.Profile memory p
    ) private view {
        address core = x.configuration.core;
        address metadataHost = x.configuration.metadata;
        if (p.profileHash != ProfileReads.profileHash(2) || p.configurationHash == 0) {
            revert DiscoveryUnsupportedProfile();
        }
        _boundPin(_codeHashes, p.referenceRender, p.referenceRenderCodeHash);
        _boundPin(_codeHashes, p.snapshots, p.snapshotsCodeHash);
        _boundPin(_codeHashes, p.entropyFactory, p.entropyFactoryCodeHash);
        _address(x, p.snapshots, "core()", core);
        _address(x, p.snapshots, "metadataHost()", metadataHost);
        _address(x, p.referenceRender, "core()", core);
        _address(x, p.referenceRender, "metadataHost()", metadataHost);
        _address(x, p.referenceRender, "metadataRouter()", x.configuration.router);
        _address(x, p.referenceRender, "snapshots()", p.snapshots);
        _address(x, p.entropyFactory, "core()", core);
        _address(x, p.entropyFactory, "metadataHost()", metadataHost);
        _address(x, p.entropyFactory, "scopeMembershipHost()", x.configuration.membership);
        _supports(
            x.configuration.readGas,
            p.entropyFactory,
            type(IStreamFinalityEntropySourceFactory).interfaceId
        );
        _supports(
            x.configuration.readGas,
            p.entropyFactory,
            type(IStreamFinalityCurrentEntropyRoute).interfaceId
        );
        _supports(
            x.configuration.readGas,
            p.referenceRender,
            type(IStreamArtworkScopedFinalityComponent).interfaceId
        );
        _supports(
            x.configuration.readGas,
            p.referenceRender,
            type(IStreamArtworkFinalityComponent).interfaceId
        );
    }

    function _boundPin(
        mapping(address => bytes32) storage _codeHashes,
        address target,
        bytes32 expected
    ) private view {
        if (
            expected == 0 || target.code.length == 0 || target.codehash != expected
                || (_codeHashes[target] != 0 && _codeHashes[target] != expected)
        ) revert DiscoveryDependency(target);
    }

    function _readPendingAware(Context memory x, bytes memory input, uint256 size, uint256 cap)
        private
        view
        returns (bytes memory raw)
    {
        address scopeEvidenceProvider = x.configuration.provider;
        uint256 required = cap + cap / 63 + 100000;
        if (gasleft() <= required) {
            revert StreamFinalityRouterEvidence.RouterEvidenceGas(gasleft(), required);
        }
        raw = new bytes(size);
        address target = scopeEvidenceProvider;
        bool ok;
        uint256 returned;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), add(raw, 32), size)
            returned := returndatasize()
        }
        if (!ok) {
            if (returned == 4 && bytes4(raw) == Deferred.CollectionPolicyPending.selector) {
                revert Deferred.CollectionPolicyPending();
            }
            revert StreamFinalityRouterEvidence.RouterEvidenceRead(target, bytes4(input));
        }
        if (returned != size) {
            revert StreamFinalityRouterEvidence.RouterEvidenceRead(target, bytes4(input));
        }
    }

    function _sourceSelectionGas(Context memory x) private view returns (uint256 cap) {
        // Configured outer budget covers the provider's cold constructor-state projection as
        // well as its nested graph read. A fixed small slack is not an execution-cost bound.
        return x.configuration.componentGas;
    }

    function _supports(uint256 readGas, address target, bytes4 id) private view {
        if (
            abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (type(IERC165).interfaceId)),
                            32,
                            readGas
                        ),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(target, abi.encodeCall(IERC165.supportsInterface, (id)), 32, readGas),
                        (uint256)
                    ) != 1
                || abi.decode(
                        _read(
                            target,
                            abi.encodeCall(IERC165.supportsInterface, (bytes4(0xffffffff))),
                            32,
                            readGas
                        ),
                        (uint256)
                    ) != 0
        ) {
            revert DiscoveryConfiguration(target);
        }
    }

    function _pin(mapping(address => bytes32) storage _codeHashes, address target) private view {
        if (target.code.length == 0 || target.codehash != _codeHashes[target]) {
            revert DiscoveryDependency(target);
        }
    }

    function _address(Context memory x, address target, string memory signature, address expected)
        private
        view
    {
        if (
            abi.decode(
                    _read(target, abi.encodeWithSignature(signature), 32, x.configuration.readGas),
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

    function serving(
        Context memory x,
        mapping(address => bytes32) storage _codeHashes,
        StreamFinalityScope memory scope,
        StreamFinalityDiscoveryTypes.Configuration memory c
    ) public view {
        Profiles.Profile memory p = selected(x, _codeHashes, scope);
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

    function authority(
        StreamFinalityDiscoveryTypes.Configuration memory c,
        mapping(address => bytes32) storage _codeHashes,
        uint256 readGas,
        uint256 collectionId
    ) public view returns (AuthorityTypes.Route memory authority_) {
        _supports(readGas, c.finalityRegistry, type(IStreamFinalityCurrentAuthority).interfaceId);
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
        authority_ = abi.decode(raw, (AuthorityTypes.Route));
        if (
            keccak256(raw) != keccak256(abi.encode(authority_))
                || authority_.finalityRegistry != c.finalityRegistry
                || authority_.finalityCodeHash != c.finalityRegistryCodeHash
                || authority_.provider != c.provider
                || authority_.providerCodeHash != _codeHashes[c.provider]
                || authority_.selectionHash == 0 || authority_.presentationHash == 0
        ) revert DiscoveryConfiguration(c.finalityRegistry);
        _currentPin(authority_);
    }

    function _currentPin(AuthorityTypes.Route memory authority) private view {
        if (
            authority.registry.code.length == 0 || authority.registryCodeHash == 0
                || authority.registry.codehash != authority.registryCodeHash
                || authority.coordinator.code.length == 0 || authority.coordinatorCodeHash == 0
                || authority.coordinator.codehash != authority.coordinatorCodeHash
        ) revert DiscoveryDependency(authority.registry);
    }

    function componentState(
        address target,
        bytes32 family,
        StreamFinalityScope memory scope,
        uint256 readGas,
        uint256 componentGas
    ) public view returns (StreamFinalityComponentExpectation memory e) {
        bytes4 expectedInterface = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? type(IStreamArtworkFinalityComponent).interfaceId
            : type(IStreamArtworkScopedFinalityComponent).interfaceId;
        _supports(readGas, target, expectedInterface);
        bytes memory input = scope.scopeType == StreamFinalityScopeType.COLLECTION
            ? abi.encodeCall(IStreamArtworkFinalityComponent.finalityState, (scope.collectionId))
            : abi.encodeCall(IStreamArtworkScopedFinalityComponent.finalityStateForScope, (scope));
        StreamFinalityComponentState memory s =
            abi.decode(_read(target, input, 256, componentGas), (StreamFinalityComponentState));
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
}
