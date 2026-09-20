// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicySourceGraph
} from "./StreamCurrentAuthorityScopedPolicySourceGraph.sol";
import {
    StreamFinalityNativeProviderReads as NativeConfig
} from "../../smart-contracts/domains/finality/StreamFinalityNativeProviderReads.sol";
import {
    StreamFinalityScopedProviderReads as ScopedConfig
} from "../../smart-contracts/domains/finality/StreamFinalityScopedProviderReads.sol";
import {
    StreamFinalityDiscoveryTypes as DiscoveryTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamFinalityDiscoveryTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as AuthorityInventory
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as InventoryTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamBundleArchiveTypes as BundleTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamBundleArchiveTypes.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as PublicationTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    IStreamScopedPolicyPublicationFactoryV2 as PublicationFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationFactoryV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as PublicationBinding
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    IStreamFinalityProfileSources as ProfileSources
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import { StreamDeploymentSlot } from "./StreamDeploymentSlot.sol";
import {
    IStreamCurrentAuthorityInventory
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";

/// @notice Original deferred scoped-policy provider/Discovery before Finality and Artist lock.
/// @dev Original/native graph defaults remain separate. All added products use genuine linked
/// creation templates and actual constructor checks. Explicit simulation gas budgets are inputs,
/// not claimed measured production caps. No policy source is bound until a governed action runs.
abstract contract StreamCurrentAuthorityDeferredScopedPolicyGraph is
    StreamCurrentAuthorityScopedPolicySourceGraph
{
    struct GraphGas {
        uint32 graphGas;
        uint32 componentSourceGas;
        uint32 providerSourceGas;
        uint32 discoveryComponentGas;
        uint32 finalityComponentGas;
    }
    function _scopedPolicyGraphGas() internal view virtual returns (GraphGas memory);

    StreamDeploymentSlot[2] internal scopedSourceSlots;
    address[2] internal scopedSourceLate;
    bytes[2] internal scopedSourceRuntimes;
    NativeConfig.Config internal scopedGraphOriginal;
    ScopedConfig.Config internal scopedGraphV1;
    PublicationBinding.FactoryBinding internal scopedGraphBinding;
    address internal scopedGraphFactory;
    address internal collectionPolicyInventory;
    address internal collectionPolicyBundle;

    function _assemblyProviderTemplate()
        internal
        view
        virtual
        override
        returns (string memory name, string[] memory parents, bytes memory creation)
    {
        name = "StreamCurrentAuthorityDeferredScopedPolicyEvidenceProviderV2";
        parents = new string[](2);
        parents[0] = "StreamCurrentAuthorityNativeEvidenceProvider";
        parents[1] = "StreamFinalityRouterEvidenceProvider";
        creation = _scopedPolicyCreation(name);
    }

    function _assemblyDiscoveryTemplate()
        internal
        view
        virtual
        override
        returns (string memory name, string[] memory parents, bytes memory creation)
    {
        name = "StreamFinalityLineageDeferredScopedPolicyDiscoveryV2";
        parents = new string[](0);
        creation = _scopedPolicyCreation(name);
    }

    function _assemblyProviderSourceGas() internal view virtual override returns (uint256) {
        return _scopedPolicyGraphGas().providerSourceGas;
    }

    function _assemblyComponentSourceGas() internal view virtual override returns (uint256) {
        return _scopedPolicyGraphGas().componentSourceGas;
    }

    function _assemblyDiscoveryComponentGas() internal view virtual override returns (uint32) {
        return _scopedPolicyGraphGas().discoveryComponentGas;
    }

    function _assemblyFinalityComponentGas() internal view virtual override returns (uint256) {
        return _scopedPolicyGraphGas().finalityComponentGas;
    }

    function _assemblyProviderArguments(NativeConfig.Config memory original)
        internal
        virtual
        override
        returns (bytes memory)
    {
        require(scopedGraphFactory == address(0), "fresh deferred original graph");
        _deployCurrentAuthorityScopedSourcePrefix();
        scopedGraphOriginal = original;
        string[2] memory names = [
            "StreamCurrentAuthorityScopedRenderCriticalInventory",
            "StreamCurrentAuthorityScopedBundleArchiveCoverage"
        ];
        for (uint256 i; i < 2; ++i) {
            (scopedSourceSlots[i], scopedSourceLate[i]) = _slot();
            scopedSourceRuntimes[i] = _productRuntime(
                names[i], new string[](0), _scopedPolicyCreation(names[i]), new RuntimeValue[](0)
            );
        }
        ScopedConfig.Config memory scoped;
        scoped.targets = original.targets;
        scoped.codeHashes = original.codeHashes;
        scoped.targets[8] = sourceScopedSnapshots;
        scoped.targets[9] = sourceScopedReference;
        scoped.targets[18] = scopedSourceLate[0];
        scoped.targets[19] = scopedSourceLate[1];
        scoped.codeHashes[8] = sourceScopedSnapshots.codehash;
        scoped.codeHashes[9] = sourceScopedReference.codehash;
        scoped.codeHashes[18] = keccak256(scopedSourceRuntimes[0]);
        scoped.codeHashes[19] = keccak256(scopedSourceRuntimes[1]);
        scoped.chainId = original.chainId;
        scoped.readGas = original.readGas;
        scoped.sourceGas = original.sourceGas;
        scoped.componentSourceGas = original.componentSourceGas;
        scoped.inventoryDependencyHash = AuthorityInventory.dependencyHash(
            AuthorityInventory.SCOPED_INVENTORY_PROFILE,
            _profileInventory(sourceScopedSnapshots, sourceScopedReference),
            _assemblyOriginDependencies(),
            _assemblyAuthorityDependencies()
        );
        scopedGraphV1 = scoped;

        PublicationTypes.Recipe memory recipe = _scopedPublicationRecipe();
        scopedGraphFactory = _scopedPolicyCreate(
            "StreamCurrentAuthorityScopedPolicyPublicationFactoryV2",
            abi.encode(recipe, _assemblyOriginDependencies(), _assemblyAuthorityDependencies())
        );
        PublicationFactory factory = PublicationFactory(scopedGraphFactory);
        scopedGraphBinding = PublicationBinding.FactoryBinding({
            factory: scopedGraphFactory,
            factoryCodeHash: scopedGraphFactory.codehash,
            recipeHash: factory.recipeHash(),
            sourceFactoryDependenciesHash: factory.sourceFactoryDependenciesHash(),
            graphGas: _scopedPolicyGraphGas().graphGas,
            configurationHash: bytes32(0)
        });
        return abi.encode(original, scoped, scopedGraphBinding);
    }

    function _assemblyDiscoveryArguments(DiscoveryTypes.Configuration memory c)
        internal
        virtual
        override
        returns (bytes memory)
    {
        bytes32 sourceHash = ProfileSources(c.provider).finalitySourceConfigurationHash();
        require(sourceHash != 0, "actual deferred source capability configuration");
        scopedGraphBinding = PublicationBinding(c.provider).scopedPolicyPublicationBinding();
        require(
            scopedGraphBinding.configurationHash != 0, "actual initialized provider factory binding"
        );
        return abi.encode(c, sourceHash, scopedGraphBinding);
    }

    function _afterCurrentAuthoritySelectorsDeployment(NativeConfig.Config memory original)
        internal
        virtual
        override
    {
        require(
            keccak256(abi.encode(original)) == keccak256(abi.encode(scopedGraphOriginal)),
            "fixed original provider profile"
        );
        _deploySlot(
            scopedSourceSlots[0],
            scopedSourceLate[0],
            _scopedPolicyCreation("StreamCurrentAuthorityScopedRenderCriticalInventory"),
            abi.encode(
                _profileInventory(sourceScopedSnapshots, sourceScopedReference),
                _assemblyOriginDependencies(),
                _assemblyAuthorityDependencies()
            ),
            scopedSourceRuntimes[0]
        );
        _deploySlot(
            scopedSourceSlots[1],
            scopedSourceLate[1],
            _scopedPolicyCreation("StreamCurrentAuthorityScopedBundleArchiveCoverage"),
            abi.encode(
                _profileBundle(scopedSourceLate[0]),
                _assemblyOriginDependencies(),
                _assemblyAuthorityDependencies(),
                AuthorityInventory.SCOPED_INVENTORY_PROFILE
            ),
            scopedSourceRuntimes[1]
        );
        require(
            _sourceWord(scopedSourceLate[0], "dependencyHash()")
                == scopedGraphV1.inventoryDependencyHash,
            "exact original scoped inventory configuration"
        );
        for (uint256 i; i < 22; ++i) {
            require(
                scopedGraphV1.targets[i].code.length != 0
                    && scopedGraphV1.targets[i].codehash == scopedGraphV1.codeHashes[i],
                "actual original scoped dependencies"
            );
        }
    }

    /// @dev Returns the concrete proposal for the provider's existing governed transition.
    /// The caller must schedule/register/execute the actual terminal action; this method grants
    /// no authority and does not fabricate an in-flight Governance context.
    function _prepareOriginalCollectionPolicyBinding(uint256 collectionId)
        internal
        returns (NativeConfig.Config memory policy, address output, bytes32 outputHash)
    {
        require(
            address(assemblyCoordinator).code.length != 0
                && collectionPolicyInventory == address(0),
            "collection phase after original Coordinator"
        );
        _deployCurrentAuthorityCollectionPolicySources(collectionId);
        InventoryTypes.Dependencies memory d =
            _profileInventory(sourcePolicySnapshots, sourcePolicyReference);
        collectionPolicyInventory = _scopedPolicyCreate(
            "StreamCurrentAuthorityPolicyRenderCriticalInventoryV2",
            abi.encode(d, _assemblyOriginDependencies(), _assemblyAuthorityDependencies())
        );
        collectionPolicyBundle = _scopedPolicyCreate(
            "StreamCurrentAuthorityBundleArchiveCoverage",
            abi.encode(
                _profileBundle(collectionPolicyInventory),
                _assemblyOriginDependencies(),
                _assemblyAuthorityDependencies(),
                AuthorityInventory.POLICY_INVENTORY_PROFILE
            )
        );
        policy = scopedGraphOriginal;
        policy.targets[8] = sourcePolicySnapshots;
        policy.targets[9] = sourcePolicyReference;
        policy.targets[10] = sourcePolicyEntropyFactory;
        policy.targets[18] = collectionPolicyInventory;
        policy.targets[19] = collectionPolicyBundle;
        uint256[5] memory indexes = [uint256(8), 9, 10, 18, 19];
        for (uint256 i; i < 5; ++i) {
            policy.codeHashes[indexes[i]] = policy.targets[indexes[i]].codehash;
        }
        policy.inventoryDependencyHash = AuthorityInventory.dependencyHash(
            AuthorityInventory.POLICY_INVENTORY_PROFILE,
            d,
            _assemblyOriginDependencies(),
            _assemblyAuthorityDependencies()
        );
        require(
            _sourceWord(collectionPolicyInventory, "dependencyHash()")
                == policy.inventoryDependencyHash,
            "actual policy inventory tuple"
        );
        output = sourcePolicyOutput;
        outputHash = output.codehash;
    }

    function _profileInventory(address snapshots, address referenceHost)
        private
        view
        returns (InventoryTypes.Dependencies memory d)
    {
        // After succession the scenario's current Artist variables name B/C. New original
        // policy sources must retain the already installed A anchor, not those current owners.
        d = address(assemblyInventory).code.length == 0
            ? _assemblyInventoryDependencies()
            : IStreamCurrentAuthorityInventory(address(assemblyInventory)).originalAnchor();
        d.targets[5] = snapshots;
        d.targets[6] = referenceHost;
        d.codeHashes[5] = snapshots.codehash;
        d.codeHashes[6] = referenceHost.codehash;
        SourceGas memory g = _scopedPolicySourceGas();
        d.readGas = g.readGas;
        d.sourceGas = g.sourceGas;
        d.selectionGas = g.selectionGas;
        d.snapshotGas = g.snapshotGas;
        d.referenceGas = g.snapshotGas;
    }

    function _profileBundle(address inventory)
        private
        view
        returns (BundleTypes.Dependencies memory b)
    {
        address originalArchive = address(assemblyInventory).code.length == 0
            ? assemblySuite.archive
            : IStreamCurrentAuthorityInventory(address(assemblyInventory))
            .originalAnchor()
            .artistTargets[4];
        b.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            inventory,
            address(assemblyArtifact),
            address(assemblyExternal),
            originalArchive
        ];
        for (uint256 i; i < 6; ++i) {
            b.codeHashes[i] = b.targets[i].codehash;
        }
        b.chainId = block.chainid;
        b.readGas = _scopedPolicySourceGas().readGas;
        b.archiveGas = _scopedPolicySourceGas().archiveGas;
    }

    function _scopedPublicationRecipe() private view returns (PublicationTypes.Recipe memory r) {
        SourceGas memory g = _scopedPolicySourceGas();
        r.inventory = _assemblyInventoryDependencies();
        r.inventory.targets[5] = address(0);
        r.inventory.targets[6] = address(0);
        r.inventory.codeHashes[5] = 0;
        r.inventory.codeHashes[6] = 0;
        r.inventory.readGas = g.readGas;
        r.inventory.sourceGas = g.sourceGas;
        r.inventory.selectionGas = g.selectionGas;
        r.inventory.snapshotGas = g.snapshotGas;
        r.inventory.referenceGas = g.snapshotGas;
        r.targets = [
            address(assemblyMembership),
            sourceStaticSelection,
            sourceScopedPolicyEntropyFactory,
            address(assemblyExecutor)
        ];
        for (uint256 i; i < 4; ++i) {
            r.codeHashes[i] = r.targets[i].codehash;
        }
        r.readinessReadGas = g.readGas;
        r.readinessSourceGas = g.sourceGas;
        r.factorySourceGas = g.inventoryGas;
        r.bundleReadGas = g.readGas;
        r.bundleArchiveGas = g.archiveGas;
        r.checkpointGas[0] = _gas("STATIC_CONTENT_READ_GAS", g.readGas, 50000, 2);
        r.checkpointGas[1] = _gas("STATIC_CONTENT_RENDER_GAS", g.renderGas, 50000, 2);
        r.outputGas = _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", g.sourceGas, 50000, 2);
        r.snapshotGas = _sourceSnapshotGas("SCOPED_POLICY", g);
        r.referenceGas = _sourceReferenceGas("SCOPED_POLICY", g);
    }

    function _sourceWord(address target, string memory selector)
        private
        view
        returns (bytes32 value)
    {
        (bool ok, bytes memory raw) = target.staticcall(abi.encodeWithSignature(selector));
        require(ok && raw.length == 32, "exact source recipe read");
        return abi.decode(raw, (bytes32));
    }
}
