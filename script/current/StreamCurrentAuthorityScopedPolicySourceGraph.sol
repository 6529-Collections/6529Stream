// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamCurrentAuthorityFinalityGraph } from "./StreamCurrentAuthorityFinalityGraph.sol";
import {
    StreamScopedSnapshotTypes as ScopedSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedSnapshotTypes.sol";
import {
    StreamScopedReferenceTypes as ScopedReference
} from "../../smart-contracts/interfaces/stream/preservation/StreamScopedReferenceTypes.sol";
import {
    StreamFinalityCoordinatorPolicyReadsV2 as PolicySources
} from "../../smart-contracts/domains/finality/StreamFinalityCoordinatorPolicyReadsV2.sol";
import {
    IStreamFinalityEntropySourceFactory as PolicyFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as PolicySet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    IStreamGasParameterHost
} from "../../smart-contracts/interfaces/stream/parameters/IStreamGasParameterHost.sol";

/// @notice Actual source construction before and after the original Artist graph can mint.
/// @dev The scoped V1 prefix and the two policy factories need no fabricated inventory. The
/// collection-policy publications are built only after their real factory creates a complete,
/// frozen source set. No pointer, code, source receipt or publication is substituted here.
abstract contract StreamCurrentAuthorityScopedPolicySourceGraph is
    StreamCurrentAuthorityFinalityGraph
{
    struct SourceGas {
        uint32 readGas;
        uint32 selectionGas;
        uint32 renderGas;
        uint32 sourceGas;
        uint32 inventoryGas;
        uint32 snapshotGas;
        uint32 archiveGas;
    }

    address internal sourceStaticSelection;
    address internal sourceStaticCheckpoint;
    address internal sourceStaticOutput;
    address internal sourceScopedSnapshots;
    address internal sourceScopedReference;
    address internal sourcePolicyEntropyFactory;
    address internal sourceScopedPolicyEntropyFactory;
    address internal sourcePolicySet;
    address internal sourcePolicyReadiness;
    address internal sourcePolicyCheckpoint;
    address internal sourcePolicyOutput;
    address internal sourcePolicySnapshots;
    address internal sourcePolicyReference;

    /// @dev Implementations return the literal linked creation template, checked against its
    /// compiler artifact before CREATE. These simulation helpers are never broadcast products.
    function _scopedPolicyCreation(string memory name) internal view virtual returns (bytes memory);

    function _scopedPolicySourceGas() internal view virtual returns (SourceGas memory);

    function _deployCurrentAuthorityScopedSourcePrefix() internal {
        require(sourceStaticSelection == address(0), "fresh scoped source prefix");
        SourceGas memory g = _scopedPolicySourceGas();
        _requireSourceGas(g);
        sourceStaticSelection = _scopedPolicyCreate(
            "StreamStaticSelectionCheckpoint",
            abi.encode(
                address(assemblyCore),
                address(assemblyRouter),
                address(assemblyMembership),
                address(assemblyExecutor),
                _gas("STATIC_CHECKPOINT_READ_GAS", g.selectionGas, 50000, 1)
            )
        );
        sourceStaticCheckpoint = _scopedPolicyCreate(
            "StreamStaticContentCheckpoint",
            abi.encode(
                sourceStaticSelection,
                address(assemblyExecutor),
                _gas("STATIC_CONTENT_READ_GAS", g.readGas, 50000, 2),
                _gas("STATIC_CONTENT_RENDER_GAS", g.renderGas, 50000, 2)
            )
        );
        sourceStaticOutput = _scopedPolicyCreate(
            "StreamStaticOutputManifest",
            abi.encode(
                address(assemblyCore),
                sourceStaticCheckpoint,
                address(assemblyArtifact),
                address(assemblyExecutor),
                _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", g.sourceGas, 50000, 2)
            )
        );
        sourceScopedSnapshots = _scopedPolicyCreate(
            "StreamScopedSnapshotPublication",
            abi.encode(
                _sourceSnapshotDependencies(
                    sourceStaticCheckpoint, sourceStaticOutput, address(assemblyCoordinators), g
                ),
                address(assemblyExecutor),
                _sourceSnapshotGas("SCOPED", g)
            )
        );
        sourceScopedReference = _scopedPolicyCreate(
            "StreamScopedReferencePublication",
            abi.encode(
                _sourceReferenceDependencies(sourceScopedSnapshots, g),
                address(assemblyExecutor),
                _sourceReferenceGas("SCOPED", g)
            )
        );
        PolicySources.Dependencies memory d = _sourcePolicyDependencies(g);
        sourcePolicyEntropyFactory =
            _scopedPolicyCreate("StreamFinalityEntropyPolicySourceFactoryV2", abi.encode(d));
        sourceScopedPolicyEntropyFactory =
            _scopedPolicyCreate("StreamFinalityScopedEntropyPolicySourceFactoryV2", abi.encode(d));
    }

    /// @dev Factory preparation itself proves the complete real collection inventory and its
    /// frozen native policies. Every subsequent constructor retains its ordinary strict joins.
    function _deployCurrentAuthorityCollectionPolicySources(uint256 collectionId) internal {
        require(
            sourceStaticSelection.code.length != 0 && sourcePolicySnapshots == address(0),
            "original collection source phase"
        );
        SourceGas memory g = _scopedPolicySourceGas();
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, collectionId, 0, 0);
        PolicyFactory factory = PolicyFactory(sourcePolicyEntropyFactory);
        bytes32 plan = factory.currentInventoryPlan(scope);
        sourcePolicySet = factory.prepareSourceSet(scope);
        (address actual, bytes32 hash) = factory.sourceSetForPlan(plan);
        require(
            actual == sourcePolicySet && hash != 0 && sourcePolicySet.codehash == hash,
            "actual collection factory receipt"
        );
        require(
            keccak256(abi.encode(PolicySet(sourcePolicySet).sourceScope()))
                == keccak256(abi.encode(scope)),
            "exact collection source scope"
        );
        PolicySet(sourcePolicySet).requireCurrentSourceSet();
        sourcePolicyReadiness = _scopedPolicyCreate(
            "StreamTerminalEntropyReadiness",
            abi.encode(
                address(assemblyCore),
                address(assemblyRouter),
                sourcePolicySet,
                g.readGas,
                g.sourceGas
            )
        );
        sourcePolicyCheckpoint = _scopedPolicyCreate(
            "StreamPolicyContentCheckpointV2",
            abi.encode(
                sourceStaticSelection,
                sourcePolicySet,
                sourcePolicyReadiness,
                address(assemblyExecutor),
                _gas("STATIC_CONTENT_READ_GAS", g.readGas, 50000, 2),
                _gas("STATIC_CONTENT_RENDER_GAS", g.renderGas, 50000, 2)
            )
        );
        sourcePolicyOutput = _scopedPolicyCreate(
            "StreamPolicyOutputManifestV2",
            abi.encode(
                address(assemblyCore),
                sourcePolicyCheckpoint,
                address(assemblyArtifact),
                address(assemblyExecutor),
                _gas("STATIC_OUTPUT_MANIFEST_READ_GAS", g.sourceGas, 50000, 2)
            )
        );
        // The scoped and collection dependency tuples have identical field types, but the
        // actual product is the distinct collection implementation and retains its own checks.
        sourcePolicySnapshots = _scopedPolicyCreate(
            "StreamPolicySnapshotPublicationV2",
            abi.encode(
                _sourceSnapshotDependencies(
                    sourcePolicyCheckpoint, sourcePolicyOutput, sourcePolicySet, g
                ),
                address(assemblyExecutor),
                _sourceSnapshotGas("POLICY", g)
            )
        );
        sourcePolicyReference = _scopedPolicyCreate(
            "StreamPolicyReferencePublicationV2",
            abi.encode(
                _sourceReferenceDependencies(sourcePolicySnapshots, g),
                address(assemblyExecutor),
                _sourceReferenceGas("POLICY", g)
            )
        );
    }

    function _sourcePolicyDependencies(SourceGas memory g)
        internal
        view
        returns (PolicySources.Dependencies memory d)
    {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblyMembership),
            address(assemblyCoordinators)
        ];
        for (uint256 i; i < 4; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = g.readGas;
        d.inventoryGas = g.inventoryGas;
    }

    function _sourceSnapshotDependencies(
        address checkpoint,
        address output,
        address entropy,
        SourceGas memory g
    ) private view returns (ScopedSnapshot.Dependencies memory d) {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            address(assemblyMembership),
            sourceStaticSelection,
            checkpoint,
            output,
            address(assemblyArtifact),
            entropy
        ];
        for (uint256 i; i < 11; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = g.readGas;
        d.sourceGas = g.sourceGas;
        d.inventoryGas = g.inventoryGas;
    }

    function _sourceReferenceDependencies(address snapshot, SourceGas memory g)
        private
        view
        returns (ScopedReference.Dependencies memory d)
    {
        d.targets = [
            address(assemblyCore),
            address(assemblyMetadata),
            address(assemblySchemas),
            address(assemblyStore),
            address(assemblyRouter),
            snapshot,
            address(assemblyExternal)
        ];
        for (uint256 i; i < 7; ++i) {
            d.codeHashes[i] = d.targets[i].codehash;
        }
        d.chainId = block.chainid;
        d.readGas = g.readGas;
        d.sourceGas = g.sourceGas;
        d.snapshotGas = g.snapshotGas;
        d.archiveGas = g.archiveGas;
    }

    function _sourceSnapshotGas(string memory prefix, SourceGas memory g)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[3] memory configs)
    {
        configs[0] = _gas(string.concat(prefix, "_SNAPSHOT_READ_GAS"), g.readGas, 50000, 2);
        configs[1] = _gas(string.concat(prefix, "_SNAPSHOT_SOURCE_GAS"), g.sourceGas, 50000, 2);
        configs[2] =
            _gas(string.concat(prefix, "_SNAPSHOT_INVENTORY_GAS"), g.inventoryGas, 50000, 2);
    }

    function _sourceReferenceGas(string memory prefix, SourceGas memory g)
        internal
        pure
        returns (IStreamGasParameterHost.GasParameterConfig[4] memory configs)
    {
        configs[0] = _gas(string.concat(prefix, "_REFERENCE_READ_GAS"), g.readGas, 50000, 1);
        configs[1] = _gas(string.concat(prefix, "_REFERENCE_SOURCE_GAS"), g.sourceGas, 50000, 1);
        configs[2] = _gas(string.concat(prefix, "_REFERENCE_SNAPSHOT_GAS"), g.snapshotGas, 50000, 1);
        configs[3] = _gas(string.concat(prefix, "_REFERENCE_ARCHIVE_GAS"), g.archiveGas, 50000, 1);
    }

    function _requireSourceGas(SourceGas memory g) private pure {
        require(
            g.readGas >= 50000 && g.selectionGas >= g.readGas && g.renderGas >= g.readGas
                && g.sourceGas >= g.readGas && g.inventoryGas >= g.readGas
                && g.snapshotGas >= g.sourceGas && g.archiveGas >= g.readGas,
            "explicit source gas envelope"
        );
    }

    mapping(bytes32 => bool) private _scopedPolicyTemplates;

    function _scopedPolicyCreate(string memory name, bytes memory args)
        internal
        returns (address product)
    {
        bytes memory creation = _scopedPolicyCreation(name);
        bytes32 key = keccak256(bytes(name));
        if (!_scopedPolicyTemplates[key]) {
            _linkRuntime(graphVm.readFile(_artifact(name)), creation);
            _scopedPolicyTemplates[key] = true;
        }
        bytes memory initcode = bytes.concat(creation, args);
        require(initcode.length <= 49152, "actual scoped product initcode fits");
        assembly ("memory-safe") {
            product := create(0, add(initcode, 32), mload(initcode))
            if iszero(product) {
                let errorData := mload(0x40)
                returndatacopy(errorData, 0, returndatasize())
                revert(errorData, returndatasize())
            }
        }
        require(
            product.code.length != 0 && product.code.length <= 24576,
            "actual scoped product runtime fits"
        );
    }
}
