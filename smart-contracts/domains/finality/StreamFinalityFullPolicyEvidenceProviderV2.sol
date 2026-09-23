// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityFullPolicyBaseEvidenceProviderV2.sol";
import {
    StreamFinalityFullPolicyDispatchV2 as GraphDispatch
} from "./StreamFinalityFullPolicyDispatchV2.sol";
import {
    StreamFinalityPolicyProviderComponentsV2 as PolicyComponents
} from "./StreamFinalityPolicyProviderComponentsV2.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as Selection
} from "./StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamFinalityFactoryPolicyProviderOperationsV2 as PolicyOperations
} from "./StreamFinalityFactoryPolicyProviderOperationsV2.sol";
import {
    IStreamScopedPolicyContentRootEvidenceBindingV2
} from "../../interfaces/stream/finality/IStreamScopedPolicyContentRootEvidenceBindingV2.sol";
import {
    IStreamScopedPolicyPublicationEvidenceBindingV2 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPolicyPublicationEvidenceBindingV2.sol";
import {
    StreamFinalityScopedPolicyGraphSelectionV2 as GraphSelection
} from "./StreamFinalityScopedPolicyGraphSelectionV2.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as ScopedPolicyReads
} from "./StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamFinalityScopedPolicyProviderOperationsV2 as ScopedPolicyOperations
} from "./StreamFinalityScopedPolicyProviderOperationsV2.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as ScopedPolicyMetadata
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicyMetadataFactsV2 as ScopedPolicyFacts
} from "./StreamFinalityScopedPolicyMetadataFactsV2.sol";
import {
    StreamFinalityScopedPolicyStaticComponentsV2 as ScopedPolicyStatic
} from "./StreamFinalityScopedPolicyStaticComponentsV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as ScopedPolicySnapshots
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";

import {
    IStreamFinalityFactoryProfileSourcesV2 as Catalogue
} from "../../interfaces/stream/finality/IStreamFinalityFactoryProfileSourcesV2.sol";
import {
    IStreamPolicyPublicationGraphBindingV2 as CollectionBinding
} from "../../interfaces/stream/finality/IStreamPolicyPublicationGraphBindingV2.sol";
import {
    StreamFinalityPolicyGraphSelectionV2 as CollectionSelection
} from "./StreamFinalityPolicyGraphSelectionV2.sol";
import {
    StreamPolicyPublicationGraphTypesV2 as CollectionGraph
} from "../../interfaces/stream/finality/StreamPolicyPublicationGraphTypesV2.sol";

/// @notice Fixed provider for original two static profiles and genuine per-scope full-policy V2 graphs.
/// @dev Every source catalogue/configuration is constructor-only. Current canonical Router profile
/// chooses the collection branch; no source receipt is cast across profiles. Prior deployment
/// identities and records are not inherited. VIEW retains its separately implemented route.
contract StreamFinalityFullPolicyEvidenceProviderV2 is
    StreamFinalityFullPolicyBaseEvidenceProviderV2,
    Catalogue,
    CollectionBinding,
    IStreamScopedPolicyContentRootEvidenceBindingV2,
    GraphBinding
{
    // Preserve the original surfaced error ABI after fixed-worker extraction.
    error ScopedPolicyGraphConfiguration();

    Selection.Context private _sourceSelection;
    GraphSelection.Context private _graph;
    CollectionSelection.Context private _collectionGraph;
    // Constructor-only storage avoids reciprocal runtime hash cycles.
    bytes32 private _sourceConfigurationHash;

    constructor(
        StreamFinalityNativeProviderReads.Config memory original,
        StreamFinalityScopedProviderReads.Config memory scoped,
        CollectionBinding.CollectionFactoryBinding memory collectionFactory,
        GraphBinding.FactoryBinding memory publicationFactory
    ) StreamFinalityFullPolicyBaseEvidenceProviderV2(original, scoped) {
        Selection.Context memory c;
        c.core = original.targets[0];
        c.router = original.targets[2];
        c.routerCodeHash = original.codeHashes[2];
        c.chainId = original.chainId;
        c.readGas = original.readGas;
        c.profiles[0] = _profile(original, 0, keccak256(abi.encode(original)));
        c.profiles[1] = Profiles.Profile(
            Selection.profileHash(1),
            scoped.targets[9],
            scoped.codeHashes[9],
            scoped.targets[8],
            scoped.codeHashes[8],
            scoped.targets[10],
            scoped.codeHashes[10],
            keccak256(abi.encode(scoped))
        );
        Selection.validate(c);
        _sourceSelection = c;
        _graph = GraphSelection.initialize(original, publicationFactory);
        _collectionGraph = CollectionSelection.initialize(original, collectionFactory);
        _sourceConfigurationHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_FINALITY_FACTORY_SOURCE_CONFIGURATION_V2"),
                block.chainid,
                address(this),
                original,
                scoped,
                _collectionGraph.binding,
                _graph.binding
            )
        );
    }

    function supportsInterface(bytes4 id) public pure virtual override returns (bool) {
        return super.supportsInterface(id) || id == type(Catalogue).interfaceId
            || id == type(CollectionBinding).interfaceId
            || id == type(IStreamScopedPolicyContentRootEvidenceBindingV2).interfaceId
            || id == type(GraphBinding).interfaceId;
    }

    function factorySourceProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_FINALITY_FACTORY_PROFILE_SOURCES_V2");
    }

    function finalitySourceProfile(uint8 index)
        external
        view
        override
        returns (Profiles.Profile calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function finalitySourceConfigurationHash() external view override returns (bytes32) {
        return _sourceConfigurationHash;
    }

    function finalitySourcesForScope(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (Profiles.Sources calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function collectionPolicyPublicationBinding()
        external
        view
        override
        returns (CollectionBinding.CollectionFactoryBinding calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function latestCollectionSnapshotHash(uint256 cid) public view override returns (bytes32) {
        (bool handled, bytes32 result) = GraphDispatch.latestSnapshot(_graph, _collectionGraph, cid);
        if (!handled) return super.latestCollectionSnapshotHash(cid);
        return result;
    }

    function finalityComponentFacts(bytes32 family, StreamFinalityScope calldata scope)
        public
        view
        override
        returns (StreamFinalityHostComponentFacts memory f)
    {
        (bool handled, bool frozen, bytes32 dataHash, bool metadata) =
            GraphDispatch.componentFacts(_graph, _collectionGraph, family, scope);
        if (!handled) return super.finalityComponentFacts(family, scope);
        f.frozen = frozen;
        f.dataHash = dataHash;
        if (metadata) {
            f.moduleVersion = metadataModuleVersion;
            f.manifestHash = metadataModuleManifestHash;
        } else {
            f.moduleVersion = routerModuleVersion;
            f.manifestHash = routerModuleManifestHash;
        }
    }

    function inputManifestBytes(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes memory)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.inputManifestBytes(scope);
    }

    function requireFinalityScopeInputs(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (StreamFinalityScopeInputs memory, bytes32, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.requireFinalityScopeInputs(scope, manifestHash);
    }

    function requireSanctionReviewFacts(StreamFinalityScope calldata scope, bytes32 manifestHash)
        public
        view
        override
        returns (IStreamFinalitySanctionReview.ReviewFacts memory)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.requireSanctionReviewFacts(scope, manifestHash);
    }

    function requirePreparedFinalityScopeInputs(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    ) public view override returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        _originalRegistry();
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.requirePreparedFinalityScopeInputs(scope, manifestHash, components);
    }

    function requirePreparedFinalityScopeInputsAndReview(
        StreamFinalityScope calldata scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] calldata components
    )
        public
        view
        override
        returns (
            StreamFinalityScopeInputs memory,
            bytes32,
            bytes32,
            IStreamFinalitySanctionReview.ReviewFacts memory
        )
    {
        _originalRegistry();
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.requirePreparedFinalityScopeInputsAndReview(scope, manifestHash, components);
    }

    function scopedPolicyPublicationBinding()
        external
        view
        override
        returns (GraphBinding.FactoryBinding calldata)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function scopedPolicySnapshotProfile() external pure override returns (bytes32) {
        return keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2");
    }

    function scopedPolicySnapshotHost(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (address)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function scopedPolicySnapshotCodeHash(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function scopedPolicySnapshotValidationGas(StreamFinalityScope calldata scope)
        external
        view
        override
        returns (uint256)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        revert();
    }

    function scopedContentRoot(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32, uint64, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.scopedContentRoot(scope);
    }

    function scopedSnapshotHash(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.scopedSnapshotHash(scope);
    }

    function scopedManifest(StreamFinalityScope calldata scope)
        public
        view
        override
        returns (bool, bytes32)
    {
        (bool handled, bytes memory encoded) =
            GraphDispatch.read(_graph, _collectionGraph, _sourceSelection, msg.data);
        if (handled) _returnPolicyRead(encoded);
        return super.scopedManifest(scope);
    }

    function _originalRegistry() private view {
        if (
            msg.sender != _collectionGraph.original.targets[12] || msg.sender.code.length == 0
                || msg.sender.codehash != _collectionGraph.original.codeHashes[12]
        ) {
            revert NativeProviderOriginalRegistryOnly();
        }
    }

    function _profile(StreamFinalityNativeProviderReads.Config memory c, uint8 index, bytes32 hash)
        private
        pure
        returns (Profiles.Profile memory)
    {
        return Profiles.Profile(
            Selection.profileHash(index),
            c.targets[9],
            c.codeHashes[9],
            c.targets[8],
            c.codeHashes[8],
            c.targets[10],
            c.codeHashes[10],
            hash
        );
    }

    function _returnPolicyRead(bytes memory result) private pure {
        assembly ("memory-safe") { return(add(result, 32), mload(result)) }
    }
}
