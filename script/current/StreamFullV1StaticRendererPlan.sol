// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamCurrentStackPlan.sol";
import {
    StreamEntropyCoordinator
} from "../../smart-contracts/domains/entropy/StreamEntropyCoordinator.sol";
import {
    IStreamFinalityScopeEvidence
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityScopeEvidence.sol";
import {
    IStreamArtistAttribution
} from "../../smart-contracts/interfaces/stream/artist/IStreamArtistAttribution.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";
import { StreamRendererV1 } from "../../smart-contracts/domains/metadata/StreamRendererV1.sol";
import {
    StreamStaticAttributionCompanion
} from "../../smart-contracts/domains/metadata/StreamStaticAttributionCompanion.sol";
import {
    StreamRendererRegistryModule
} from "../../smart-contracts/domains/metadata/StreamRendererRegistryModule.sol";
import {
    StreamCollectionMetadataV1
} from "../../smart-contracts/domains/metadata/StreamCollectionMetadataV1.sol";
import {
    StreamMetadataRouter
} from "../../smart-contracts/domains/metadata/StreamMetadataRouter.sol";
import {
    IStreamRenderer as R
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRenderer.sol";
import {
    IStreamRendererRegistry as V
} from "../../smart-contracts/interfaces/stream/metadata/IStreamRendererRegistry.sol";
import {
    IStreamSchemaRegistry as S
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";

/// @notice Original role23 renderer and its named attribution/registry support products.
/// @dev No analysis report, read inventory, schema, or golden is manufactured here. Supply
/// exact reviewed target/read inventories and retained documents for release admission.
/// Required direct targets are checked below; this does not prove a transitive read closure,
/// opcode conformance, complete golden inventory, or independent compiler authentication.
library StreamFullV1StaticRendererPlan {
    error InvalidStaticComposition();
    error MissingStaticReadTarget(address target);

    struct Configuration {
        address core;
        address executor;
        address router;
        address metadata;
        address schemas;
        address entropy;
        address dependencyRegistry;
        address artist;
        address finality;
        bytes32 deploymentHash;
        string registryManifestURI;
        bytes32 registryManifestHash;
        R.RendererManifest rendererManifest;
        IStreamGasParameterHost.GasParameterConfig readGas;
        IStreamGasParameterHost.GasParameterConfig attributionGas;
        IStreamGasParameterHost.GasParameterConfig goldenGas;
    }

    struct Products {
        StreamStaticAttributionCompanion attribution;
        StreamRendererV1 renderer;
        StreamRendererRegistryModule versions;
        bytes32 configurationHash;
        bytes32 attributionCodeHash;
        bytes32 rendererCodeHash;
        bytes32 registryCodeHash;
    }

    /// @notice First construct the immutable original renderer and original AA companion.
    function deployRenderer(Configuration memory c) internal returns (Products memory p) {
        _dependencies(c);
        p.configurationHash = keccak256(abi.encode(c));
        p.attribution = new StreamStaticAttributionCompanion(
            c.core, c.router, c.artist, c.finality, c.executor
        );
        p.renderer = new StreamRendererV1(
            StreamRendererV1.Deployment(
                StreamRendererV1.Sources(
                    c.core,
                    c.router,
                    c.metadata,
                    c.entropy,
                    c.dependencyRegistry,
                    address(p.attribution)
                ),
                c.executor,
                c.readGas,
                c.attributionGas,
                c.rendererManifest
            )
        );
        p.attributionCodeHash = address(p.attribution).codehash;
        p.rendererCodeHash = address(p.renderer).codehash;
    }

    /// @notice Freeze the explicit named target inventory after every target exists.
    /// @dev Additional targets/roles require the registering version's actual review. Never
    /// label an unrelated host METADATA_COMPANION to evade the MARKETPLACE read firewall.
    function deployRegistry(Configuration memory c, Products memory p, V.Target[] memory targets)
        internal
        returns (Products memory)
    {
        _renderer(c, p);
        if (address(p.versions) != address(0)) revert InvalidStaticComposition();
        _requiredTargets(c, p, targets);
        p.versions = new StreamRendererRegistryModule(
            StreamRendererRegistryModule.Deployment(
                c.executor,
                c.schemas,
                targets,
                c.readGas,
                c.goldenGas,
                c.deploymentHash,
                c.registryManifestURI,
                c.registryManifestHash
            )
        );
        p.registryCodeHash = address(p.versions).codehash;
        return p;
    }

    function registrations(Configuration memory c, Products memory p, uint32 readGas)
        internal
        view
        returns (StreamModuleRegistration[] memory rows)
    {
        validate(c, p);
        if (readGas == 0) revert InvalidStaticComposition();
        rows = new StreamModuleRegistration[](2);
        rows[0] = StreamModuleRegistration(
            address(p.renderer),
            keccak256("RENDERER"),
            p.renderer.rendererVersion(),
            type(R).interfaceId,
            readGas,
            p.rendererCodeHash,
            c.deploymentHash,
            c.rendererManifest.manifestHash,
            c.rendererManifest.manifestURI
        );
        rows[1] = StreamModuleRegistration(
            address(p.versions),
            p.versions.streamModuleType(),
            p.versions.streamModuleVersion(),
            type(V).interfaceId,
            readGas,
            p.registryCodeHash,
            c.deploymentHash,
            c.registryManifestHash,
            c.registryManifestURI
        );
    }

    /// @notice Plan actual retained-document admission, including registry target-side goldens.
    function admission(
        Configuration memory c,
        Products memory p,
        V.Registration memory registration,
        V.Read[] memory reads
    ) internal view returns (GovernanceCall memory operation, bytes memory data) {
        validate(c, p);
        if (
            registration.renderer != address(p.renderer)
                || keccak256(abi.encode(registration.manifest))
                    != keccak256(abi.encode(c.rendererManifest))
        ) {
            revert InvalidStaticComposition();
        }
        (bytes32 scope, bytes32 oldHash, bytes32 newHash) =
            p.versions.registrationTransition(registration, reads);
        data = abi.encodeCall(p.versions.registerRenderer, (registration, reads));
        operation = StreamCurrentStackPlan.call(address(p.versions), data, scope, oldHash, newHash);
    }

    /// @notice Admissions and GGP raises required by this construction slice.
    /// @dev Add the separately classified deprecation policy when preparing retirement.
    function operatingPolicies(Configuration memory c, Products memory p)
        internal
        view
        returns (GovernanceActionPolicyEntry[] memory rows)
    {
        validate(c, p);
        rows = new GovernanceActionPolicyEntry[](3);
        rows[0] =
            _policy(address(p.versions), p.versions.registerRenderer.selector, c.deploymentHash);
        rows[1] =
            _policy(address(p.versions), p.versions.raiseGasParameter.selector, c.deploymentHash);
        rows[2] =
            _policy(address(p.renderer), p.renderer.raiseGasParameter.selector, c.deploymentHash);
    }

    function validate(Configuration memory c, Products memory p) internal view {
        _renderer(c, p);
        if (
            address(p.versions).code.length == 0
                || address(p.versions).codehash != p.registryCodeHash
                || p.versions.schemaRegistry() != c.schemas
                || p.versions.governanceAuthority() != c.executor
        ) {
            revert InvalidStaticComposition();
        }
    }

    function _renderer(Configuration memory c, Products memory p) private view {
        _dependencies(c);
        if (
            p.configurationHash != keccak256(abi.encode(c))
                || address(p.attribution).code.length == 0
                || address(p.attribution).codehash != p.attributionCodeHash
                || address(p.renderer).code.length == 0
                || address(p.renderer).codehash != p.rendererCodeHash
                || p.attribution.core() != c.core || p.attribution.router() != c.router
                || p.attribution.artist() != c.artist
                || p.attribution.originalFinality() != c.finality
                || p.attribution.artistCodeHash() != c.artist.codehash
                || p.attribution.originalFinalityCodeHash() != c.finality.codehash
                || p.renderer.governanceAuthority() != c.executor
        ) {
            revert InvalidStaticComposition();
        }
        (StreamRendererV1.Sources memory actual, bytes32[6] memory hashes) =
            p.renderer.sourceBindings();
        if (
            actual.core != c.core || actual.router != c.router || actual.metadata != c.metadata
                || actual.entropy != c.entropy || actual.dependencyRegistry != c.dependencyRegistry
                || actual.attribution != address(p.attribution)
        ) revert InvalidStaticComposition();
        address[6] memory sources = [
            actual.core,
            actual.router,
            actual.metadata,
            actual.entropy,
            actual.dependencyRegistry,
            actual.attribution
        ];
        for (uint256 i; i < sources.length; ++i) {
            if (sources[i].codehash != hashes[i]) revert InvalidStaticComposition();
        }
    }

    function _dependencies(Configuration memory c) private view {
        if (
            c.core.code.length == 0 || c.executor.code.length == 0 || c.router.code.length == 0
                || c.metadata.code.length == 0 || c.schemas.code.length == 0
                || c.entropy.code.length == 0 || c.artist.code.length == 0
                || c.finality.code.length == 0 || c.deploymentHash == 0
                || c.registryManifestHash == 0 || bytes(c.registryManifestURI).length == 0
                || (c.dependencyRegistry != address(0) && c.dependencyRegistry.code.length == 0)
        ) {
            revert InvalidStaticComposition();
        }
        StreamCollectionMetadataV1 metadata = StreamCollectionMetadataV1(c.metadata);
        StreamMetadataRouter router = StreamMetadataRouter(c.router);
        if (
            metadata.core() != c.core || metadata.schemaRegistry() != c.schemas
                || metadata.artistRegistry() != c.artist
                || metadata.governanceAuthority() != c.executor || address(router.core()) != c.core
                || router.governanceAuthority() != c.executor
                || S(c.schemas).governanceAuthority() != c.executor
                || IStreamArtistAttribution(c.artist).core() != c.core
                || IStreamFinalityScopeEvidence(c.finality).core() != c.core
                || IStreamGasParameterHost(c.finality).governanceAuthority() != c.executor
                || address(StreamEntropyCoordinator(payable(c.entropy)).core()) != c.core
                || StreamEntropyCoordinator(payable(c.entropy)).authority() != c.executor
        ) {
            revert InvalidStaticComposition();
        }
    }

    function _requiredTargets(Configuration memory c, Products memory p, V.Target[] memory targets)
        private
        view
    {
        _target(targets, c.core, keccak256("CORE"));
        _target(targets, c.metadata, keccak256("COLLECTION_METADATA"));
        _target(targets, c.router, keccak256("METADATA_COMPANION"));
        _target(targets, c.entropy, keccak256("ENTROPY_COORDINATOR"));
        _target(targets, address(p.attribution), keccak256("METADATA_COMPANION"));
        (address encoding, bytes32 codeHash) = p.renderer.encodingBinding();
        if (encoding.codehash != codeHash) revert InvalidStaticComposition();
        _target(targets, encoding, keccak256("METADATA_COMPANION"));
        if (c.dependencyRegistry != address(0)) {
            _target(targets, c.dependencyRegistry, keccak256("DEPENDENCY_REGISTRY"));
        }
    }

    function _target(V.Target[] memory targets, address target, bytes32 role) private view {
        for (uint256 i; i < targets.length; ++i) {
            if (
                targets[i].target == target && targets[i].codeHash == target.codehash
                    && targets[i].role == role
            ) return;
        }
        revert MissingStaticReadTarget(target);
    }

    function _policy(address target, bytes4 selector, bytes32 profile)
        private
        view
        returns (GovernanceActionPolicyEntry memory)
    {
        return GovernanceActionPolicyEntry(
            1, target, selector, target.codehash, profile, 1, 0, 0, bytes32(0)
        );
    }
}
