// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamFinalityFullPolicyBaseEvidenceProviderV2.sol";
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

import {
    StreamFinalityProviderStoredGuardsV1 as StoredGuards
} from "./StreamFinalityProviderStoredGuardsV1.sol";

/// @notice Fixed read dispatch over the original constructor-owned full-policy contexts.
/// @dev Delegate-host identity, fixed worker links, profile precedence and leaf caps remain unchanged.
library StreamFinalityFullPolicyDispatchV2 {
    function componentFacts(
        GraphSelection.Context storage graph,
        CollectionSelection.Context storage collection,
        bytes32 family,
        StreamFinalityScope calldata scope
    ) public view returns (bool handled, bool frozen, bytes32 dataHash, bool metadata) {
        StreamFinalityHostComponentFacts memory f;

        if (GraphSelection.isPolicy(graph, scope)) {
            ScopedPolicyReads.Config memory configured = _scopedPolicyConfig(graph, scope);
            StoredGuards.pins(graph.original);
            StoredGuards.scope(graph.original, scope);
            if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
                (f.frozen, f.dataHash) = ScopedPolicyFacts.facts(configured, scope);
            } else {
                StoredGuards.componentFamily(family);
                (f.frozen, f.dataHash) = ScopedPolicyStatic.facts(configured, scope, family);
            }
            return (
                true,
                f.frozen,
                f.dataHash,
                family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
            );
        }
        if (!CollectionSelection.isPolicy(collection, scope)) {
            return (false, false, bytes32(0), false);
        }
        StoredGuards.pins(graph.original);
        StoredGuards.scope(graph.original, scope);
        if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
            (f.frozen, f.dataHash) =
                PolicyComponents.facts(_collectionConfig(collection, scope).source, scope, family);
        } else {
            StoredGuards.componentFamily(family);
            (f.frozen, f.dataHash) =
                PolicyComponents.facts(_collectionConfig(collection, scope).source, scope, family);
        }

        return (
            true,
            f.frozen,
            f.dataHash,
            family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
        );
    }

    function latestSnapshot(
        GraphSelection.Context storage graph,
        CollectionSelection.Context storage collection,
        uint256 cid
    ) public view returns (bool handled, bytes32 result) {
        StreamFinalityScope memory scope =
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, cid, 0, 0);
        if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes32(0));
        StoredGuards.pins(graph.original);
        return
            (true, PolicyComponents.snapshotHash(_collectionConfig(collection, scope).source, cid));
    }

    function read(
        GraphSelection.Context storage graph,
        CollectionSelection.Context storage collection,
        Selection.Context storage profiles,
        bytes calldata input
    ) public view returns (bool handled, bytes memory encoded) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == 0x551c5e46) {
            // finalitySourceProfile
            uint8 index = abi.decode(input[4:], (uint8));
            Selection.profileHash(index);
            return (true, abi.encode(profiles.profiles[index]));
        }
        if (selector == 0x99979942) {
            // collectionPolicyPublicationBinding
            return (true, abi.encode(collection.binding));
        }
        if (selector == 0x266d0af8) {
            // scopedPolicyPublicationBinding
            return (true, abi.encode(graph.binding));
        }
        if (selector == 0x4ce4a236) {
            // scopedPolicySnapshotValidationGas
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            if (
                scope.scopeType != StreamFinalityScopeType.TOKEN
                    && scope.scopeType != StreamFinalityScopeType.RELEASE
                    && scope.scopeType != StreamFinalityScopeType.SEASON
            ) revert GraphSelection.ScopedPolicyGraphConfiguration();
            StreamMetadataSubjects.scopeSubject(
                graph.original.chainId, graph.original.targets[0], scope
            );
            return (true, abi.encode(graph.original.componentSourceGas));
        }
        if (selector == 0x5004b8aa) {
            // finalitySourcesForScope
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            Profiles.Sources memory result;
            if (GraphSelection.isPolicy(graph, scope)) {
                result = GraphSelection.sources(graph, scope);
            } else if (CollectionSelection.isPolicy(collection, scope)) {
                result = CollectionSelection.sources(collection, scope);
            } else {
                result = Selection.current(profiles, scope);
            }
            return (true, abi.encode(result));
        }
        if (selector == 0xa9d748fc) {
            // inputManifestBytes
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));

            if (GraphSelection.isPolicy(graph, scope)) {
                bytes memory result =
                    ScopedPolicyOperations.manifest(_scopedPolicyConfig(graph, scope), scope);
                return (true, abi.encode(result));
            }
            if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes(""));
            bytes memory result =
                PolicyOperations.manifest(_collectionConfig(collection, scope), scope);
            return (true, abi.encode(result));
        }
        if (selector == 0x078a7350) {
            // requireFinalityScopeInputs
            (StreamFinalityScope memory scope, bytes32 manifestHash) =
                abi.decode(input[4:], (StreamFinalityScope, bytes32));

            if (GraphSelection.isPolicy(graph, scope)) {
                (StreamFinalityScopeInputs memory result, bytes32 schema, bytes32 canon) = ScopedPolicyOperations.inputs(
                    _scopedPolicyConfig(graph, scope), scope, manifestHash
                );
                return (true, abi.encode(result, schema, canon));
            }
            if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes(""));
            (StreamFinalityScopeInputs memory result, bytes32 schema, bytes32 canon) =
                PolicyOperations.inputs(_collectionConfig(collection, scope), scope, manifestHash);
            return (true, abi.encode(result, schema, canon));
        }
        if (selector == 0x01859042) {
            // requireSanctionReviewFacts
            (StreamFinalityScope memory scope, bytes32 manifestHash) =
                abi.decode(input[4:], (StreamFinalityScope, bytes32));

            if (GraphSelection.isPolicy(graph, scope)) {
                IStreamFinalitySanctionReview.ReviewFacts memory result =
                    ScopedPolicyOperations.review(
                        _scopedPolicyConfig(graph, scope), scope, manifestHash
                    );
                return (true, abi.encode(result));
            }
            if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes(""));
            IStreamFinalitySanctionReview.ReviewFacts memory result =
                PolicyOperations.review(_collectionConfig(collection, scope), scope, manifestHash);
            return (true, abi.encode(result));
        }
        if (selector == 0x343d8ac3) {
            // requirePreparedFinalityScopeInputs
            (
                StreamFinalityScope memory scope,
                bytes32 manifestHash,
                StreamFinalityComponentExpectation[] memory components
            ) = abi.decode(
                input[4:], (StreamFinalityScope, bytes32, StreamFinalityComponentExpectation[])
            );

            if (GraphSelection.isPolicy(graph, scope)) {
                (
                    StreamFinalityScopeInputs memory result,
                    bytes32 schema,
                    bytes32 canon,
                    IStreamFinalitySanctionReview.ReviewFacts memory review
                ) = ScopedPolicyOperations.prepared(
                    _scopedPolicyConfig(graph, scope), scope, manifestHash, components, false
                );
                return (true, abi.encode(result, schema, canon));
            }
            if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes(""));
            (
                StreamFinalityScopeInputs memory result,
                bytes32 schema,
                bytes32 canon,
                IStreamFinalitySanctionReview.ReviewFacts memory review
            ) = PolicyOperations.prepared(
                _collectionConfig(collection, scope), scope, manifestHash, components, false
            );
            return (true, abi.encode(result, schema, canon));
        }
        if (selector == 0x9850674d) {
            // requirePreparedFinalityScopeInputsAndReview
            (
                StreamFinalityScope memory scope,
                bytes32 manifestHash,
                StreamFinalityComponentExpectation[] memory components
            ) = abi.decode(
                input[4:], (StreamFinalityScope, bytes32, StreamFinalityComponentExpectation[])
            );

            if (GraphSelection.isPolicy(graph, scope)) {
                (
                    StreamFinalityScopeInputs memory result,
                    bytes32 schema,
                    bytes32 canon,
                    IStreamFinalitySanctionReview.ReviewFacts memory review
                ) = ScopedPolicyOperations.prepared(
                    _scopedPolicyConfig(graph, scope), scope, manifestHash, components, true
                );
                return (true, abi.encode(result, schema, canon, review));
            }
            if (!CollectionSelection.isPolicy(collection, scope)) return (false, bytes(""));
            (
                StreamFinalityScopeInputs memory result,
                bytes32 schema,
                bytes32 canon,
                IStreamFinalitySanctionReview.ReviewFacts memory review
            ) = PolicyOperations.prepared(
                _collectionConfig(collection, scope), scope, manifestHash, components, true
            );
            return (true, abi.encode(result, schema, canon, review));
        }
        if (selector == 0x875e1785) {
            // scopedContentRoot
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));

            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            (bytes32 result, uint64 revision, bytes32 context) =
                ScopedPolicyMetadata.root(_metadataConfigV2(graph, scope), scope);
            return (true, abi.encode(result, revision, context));
        }
        if (selector == 0x03bbdf0b) {
            // scopedSnapshotHash
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));

            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            bytes32 result = ScopedPolicyMetadata.snapshot(_metadataConfigV2(graph, scope), scope);
            return (true, abi.encode(result));
        }
        if (selector == 0x882621aa) {
            // scopedManifest
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));

            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            (bool exists, bytes32 result) =
                ScopedPolicyMetadata.manifest(_metadataConfigV2(graph, scope), scope);
            return (true, abi.encode(exists, result));
        }
        if (selector == 0x3ee54c6b) {
            // scopedPolicySnapshotHost
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            ScopedPolicyReads.Config memory config = _scopedPolicyConfig(graph, scope);
            return (true, abi.encode(config.targets[8]));
        }
        if (selector == 0xa435ec12) {
            // scopedPolicySnapshotCodeHash
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            ScopedPolicyReads.Config memory config = _scopedPolicyConfig(graph, scope);
            return (true, abi.encode(config.codeHashes[8]));
        }
        revert GraphSelection.ScopedPolicyGraphConfiguration();
    }

    function _scopedPolicyConfig(
        GraphSelection.Context storage graph,
        StreamFinalityScope memory scope
    ) private view returns (ScopedPolicyReads.Config memory c) {
        (c,) = GraphSelection.current(graph, scope);
    }

    function _metadataConfigV2(
        GraphSelection.Context storage graph,
        StreamFinalityScope memory scope
    ) private view returns (ScopedPolicyMetadata.Config memory c) {
        ScopedPolicyReads.Config memory s = _scopedPolicyConfig(graph, scope);
        c.snapshots = ScopedPolicySnapshots.Dependencies(
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

    function _collectionConfig(
        CollectionSelection.Context storage collection,
        StreamFinalityScope memory scope
    ) private view returns (PolicyOperations.Config memory c) {
        CollectionGraph.Graph memory g;
        (c.source, g) = CollectionSelection.current(collection, scope);
        c.outputManifest = g.children[2];
        c.outputManifestCodeHash = g.codeHashes[2];
    }
}
