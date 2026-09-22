// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPolicyGraphSelectionV2 as Graph
} from "./StreamCurrentAuthorityScopedPolicyGraphSelectionV2.sol";
import {
    StreamFinalityDeferredProfileSourceReadsV2 as Selection
} from "./StreamFinalityDeferredProfileSourceReadsV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyProviderOperationsV2 as Operations
} from "./StreamCurrentAuthorityScopedPolicyProviderOperationsV2.sol";
import {
    StreamFinalityScopedPolicyProviderReadsV2 as Reads
} from "./StreamFinalityScopedPolicyProviderReadsV2.sol";
import {
    StreamFinalityScopedPolicyProviderMetadataV2 as Metadata
} from "./StreamFinalityScopedPolicyProviderMetadataV2.sol";
import {
    StreamFinalityScopedPolicySnapshotReadsV2 as Snapshots
} from "./StreamFinalityScopedPolicySnapshotReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    IStreamFinalitySanctionReview
} from "../../interfaces/stream/finality/IStreamFinalitySanctionReview.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType,
    StreamFinalityComponentExpectation
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamFinalityScopeInputs
} from "../../interfaces/stream/finality/StreamFinalityEvidenceTypes.sol";
import {
    StreamFinalityNativeProviderReads as Native
} from "./StreamFinalityNativeProviderReads.sol";
import {
    StreamCurrentAuthorityPolicyProviderOperationsV2 as PolicyOperations
} from "./StreamCurrentAuthorityPolicyProviderOperationsV2.sol";
import {
    StreamFinalityPolicyProviderComponentsV2 as PolicyComponents
} from "./StreamFinalityPolicyProviderComponentsV2.sol";

/// @notice Fixed storage projections for the deferred provider's existing graph operations.
/// @dev Host dispatch, pin/scope/component checks and original-Registry admission retain their
/// original order. Every graph operation still performs its original current selection.
library StreamCurrentAuthorityDeferredScopedPolicyGraphWorkerV2 {
    function selectedSources(Selection.Context storage selection, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Sources memory)
    {
        return Selection.current(selection, scope);
    }

    function policySnapshot(Native.Config storage policy, uint256 cid)
        public
        view
        returns (bytes32)
    {
        return PolicyComponents.snapshotHash(policy, cid);
    }

    function policyManifest(Native.Config storage policy, StreamFinalityScope memory scope)
        public
        view
        returns (bytes memory)
    {
        return PolicyOperations.manifest(policy, scope);
    }

    function policyInputs(
        Native.Config storage policy,
        StreamFinalityScope memory scope,
        bytes32 hash
    ) public view returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        return PolicyOperations.inputs(policy, scope, hash);
    }

    function policyReview(
        Native.Config storage policy,
        StreamFinalityScope memory scope,
        bytes32 hash
    ) public view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        return PolicyOperations.review(policy, scope, hash);
    }

    function policyPrepared(
        Native.Config storage policy,
        StreamFinalityScope memory scope,
        bytes32 hash,
        StreamFinalityComponentExpectation[] calldata components,
        bool withReview
    )
        public
        view
        returns (
            StreamFinalityScopeInputs memory,
            bytes32,
            bytes32,
            IStreamFinalitySanctionReview.ReviewFacts memory
        )
    {
        return PolicyOperations.prepared(policy, scope, hash, components, withReview);
    }

    function isPolicy(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bool)
    {
        return Graph.isPolicy(graph, scope);
    }

    function isCollectionPolicy(
        Selection.Context storage selection,
        StreamFinalityScope memory scope
    ) public view returns (bool) {
        if (scope.scopeType != StreamFinalityScopeType.COLLECTION) {
            return false;
        }
        Profiles.Sources memory s = Selection.current(selection, scope);
        return s.profile.profileHash == Selection.profileHash(2);
    }

    function sources(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (Profiles.Sources memory)
    {
        return Graph.sources(graph, scope);
    }

    function configuration(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (Reads.Config memory c)
    {
        (c,) = Graph.current(graph, scope);
    }

    function snapshotHost(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (address)
    {
        return configuration(graph, scope).targets[8];
    }

    function snapshotCodeHash(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        return configuration(graph, scope).codeHashes[8];
    }

    function manifest(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bytes memory)
    {
        return Operations.manifest(configuration(graph, scope), scope);
    }

    function inputs(
        Graph.Context storage graph,
        StreamFinalityScope memory scope,
        bytes32 manifestHash
    ) public view returns (StreamFinalityScopeInputs memory, bytes32, bytes32) {
        return Operations.inputs(configuration(graph, scope), scope, manifestHash);
    }

    function review(
        Graph.Context storage graph,
        StreamFinalityScope memory scope,
        bytes32 manifestHash
    ) public view returns (IStreamFinalitySanctionReview.ReviewFacts memory) {
        return Operations.review(configuration(graph, scope), scope, manifestHash);
    }

    function prepared(
        Graph.Context storage graph,
        StreamFinalityScope memory scope,
        bytes32 manifestHash,
        StreamFinalityComponentExpectation[] memory components,
        bool withReview
    )
        public
        view
        returns (
            StreamFinalityScopeInputs memory,
            bytes32,
            bytes32,
            IStreamFinalitySanctionReview.ReviewFacts memory
        )
    {
        return Operations.prepared(
            configuration(graph, scope), scope, manifestHash, components, withReview
        );
    }

    function root(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32, uint64, bytes32)
    {
        return Metadata.root(_metadata(graph, scope), scope);
    }

    function snapshot(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bytes32)
    {
        return Metadata.snapshot(_metadata(graph, scope), scope);
    }

    function scopeManifest(Graph.Context storage graph, StreamFinalityScope memory scope)
        public
        view
        returns (bool, bytes32)
    {
        return Metadata.manifest(_metadata(graph, scope), scope);
    }

    function _metadata(Graph.Context storage graph, StreamFinalityScope memory scope)
        private
        view
        returns (Metadata.Config memory c)
    {
        Reads.Config memory s = configuration(graph, scope);
        c.snapshots = Snapshots.Dependencies(
            s.targets[0],
            s.targets[1],
            s.targets[2],
            s.targets[8],
            s.codeHashes[0],
            s.codeHashes[1],
            s.codeHashes[2],
            s.codeHashes[8],
            s.chainId,
            s.readGas,
            s.componentSourceGas
        );
        c.membership = s.targets[3];
        c.membershipCodeHash = s.codeHashes[3];
    }
}
