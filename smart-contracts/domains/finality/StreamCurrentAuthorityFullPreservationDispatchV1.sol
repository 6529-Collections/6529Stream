// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./StreamCurrentAuthorityScopedPolicyBaseEvidenceProviderV2.sol";
import {
    StreamFinalityPreservationPolicyProviderComponentsV1 as PolicyComponents
} from "./StreamFinalityPreservationPolicyProviderComponentsV1.sol";
import {
    StreamFinalityFactoryProfileSourceReadsV2 as ProfileSelection
} from "./StreamFinalityFactoryProfileSourceReadsV2.sol";
import {
    IStreamFinalityProfileSources as Profiles
} from "../../interfaces/stream/finality/IStreamFinalityProfileSources.sol";
import {
    StreamCurrentAuthorityPreservationPolicyProviderOperationsV1 as PolicyOperations
} from "./StreamCurrentAuthorityPreservationPolicyProviderOperationsV1.sol";
import {
    IStreamScopedPreservationPolicyContentRootEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyContentRootEvidenceBindingV1.sol";
import {
    IStreamScopedPreservationPolicyPublicationEvidenceBindingV1 as GraphBinding
} from "../../interfaces/stream/finality/IStreamScopedPreservationPolicyPublicationEvidenceBindingV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1 as GraphSelection
} from "./StreamCurrentAuthorityScopedPreservationPolicyGraphSelectionV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderReadsV1 as ScopedPolicyReads
} from "./StreamFinalityScopedPreservationPolicyProviderReadsV1.sol";
import {
    StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1 as ScopedPolicyOperations
} from "./StreamCurrentAuthorityScopedPreservationPolicyProviderOperationsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyProviderMetadataV1 as ScopedPolicyMetadata
} from "./StreamFinalityScopedPreservationPolicyProviderMetadataV1.sol";
import {
    StreamFinalityScopedPreservationPolicyMetadataFactsV1 as ScopedPolicyFacts
} from "./StreamFinalityScopedPreservationPolicyMetadataFactsV1.sol";
import {
    StreamFinalityScopedPreservationPolicyStaticComponentsV1 as ScopedPolicyStatic
} from "./StreamFinalityScopedPreservationPolicyStaticComponentsV1.sol";
import {
    StreamFinalityScopedPreservationPolicySnapshotReadsV1 as ScopedPolicySnapshots
} from "./StreamFinalityScopedPreservationPolicySnapshotReadsV1.sol";

import {
    IStreamFinalityPreservationFactoryProfileSourcesV1 as Catalogue
} from "../../interfaces/stream/finality/IStreamFinalityPreservationFactoryProfileSourcesV1.sol";
import {
    IStreamPreservationPolicyPublicationGraphBindingV1 as CollectionBinding
} from "../../interfaces/stream/finality/IStreamPreservationPolicyPublicationGraphBindingV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyGraphSelectionV1 as CollectionSelection
} from "./StreamCurrentAuthorityPreservationPolicyGraphSelectionV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CollectionGraph
} from "../../interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";

import {
    IStreamViewPreservationEvidenceBindingV1
} from "../../interfaces/stream/finality/IStreamViewPreservationEvidenceBindingV1.sol";
import {
    IStreamFinalityViewPreservationBindingV1
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationBindingV1.sol";
import {
    StreamFinalityViewPreservationBindingTypesV1 as ViewBindingTypes
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationBindingV1 as ViewBinding
} from "./StreamFinalityViewPreservationBindingV1.sol";

import {
    IStreamViewSourceBinding
} from "../../interfaces/stream/finality/IStreamViewSourceBinding.sol";
import {
    StreamViewAdoptionTypes as ViewDeclarationTypes
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";

import {
    IStreamViewPolicySourceBindingV2
} from "../../interfaces/stream/finality/IStreamViewPolicySourceBindingV2.sol";
import {
    StreamFinalityViewPolicyFactoryBindingV1 as ViewPolicyFactory
} from "./StreamFinalityViewPolicyFactoryBindingV1.sol";

import {
    IStreamViewRouteReadBudgetV1
} from "../../interfaces/stream/finality/IStreamViewRouteReadBudgetV1.sol";
import {
    IStreamFinalityViewPreservationCompleteBindingV1
} from "../../interfaces/stream/finality/IStreamFinalityViewPreservationCompleteBindingV1.sol";
import {
    IStreamViewPreservationFinalitySourcesV1
} from "../../interfaces/stream/finality/IStreamViewPreservationFinalitySourcesV1.sol";
import {
    StreamFinalityViewPreservationCompleteBindingTypesV1 as CompleteViewBinding
} from "../../interfaces/stream/finality/StreamFinalityViewPreservationCompleteBindingTypesV1.sol";
import {
    StreamFinalityViewPreservationConfigurationV1 as ViewConfiguration
} from "./StreamFinalityViewPreservationConfigurationV1.sol";
import {
    StreamFinalityViewPreservationComponentsV1 as ViewComponents
} from "./StreamFinalityViewPreservationComponentsV1.sol";
import {
    StreamFinalityViewPreservationMetadataV1 as ViewMetadata
} from "./StreamFinalityViewPreservationMetadataV1.sol";
import {
    StreamFinalityViewPreservationOperationsV1 as ViewOperations
} from "./StreamFinalityViewPreservationOperationsV1.sol";

import {
    StreamFinalityProviderStoredGuardsV1 as StoredGuards
} from "./StreamFinalityProviderStoredGuardsV1.sol";

/// @notice Fixed nominal graph read dispatch; original profile branches and delegate domain retained.
library StreamCurrentAuthorityFullPreservationDispatchV1 {
    error UnsupportedPreservationSelector();

    function componentFacts(
        GraphSelection.Context storage graph,
        CollectionSelection.Context storage collection,
        bytes32 family,
        StreamFinalityScope calldata scope
    ) public view returns (bool handled, bool frozen, bytes32 dataHash, bool metadata) {
        StreamFinalityHostComponentFacts memory f;
        if (scope.scopeType == StreamFinalityScopeType.VIEW) {
            (f.frozen, f.dataHash) = ViewComponents.facts(graph.original, scope, family);
            if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) { } else {
                StoredGuards.componentFamily(family);
            }
            return (
                true,
                f.frozen,
                f.dataHash,
                family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA
            );
        }
        if (GraphSelection.isPolicy(graph, scope)) {
            ScopedPolicyReads.Config memory configured = _scopedPolicyConfig(graph, scope);
            StoredGuards.pins(graph.original);
            StoredGuards.scope(graph.original, scope);
            if (family == StreamFinalityDomains.COMPONENT_COLLECTION_METADATA) {
                (f.frozen, f.dataHash) = ScopedPolicyFacts.facts(
                    configured, scope, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                );
            } else {
                StoredGuards.componentFamily(family);
                (f.frozen, f.dataHash) = ScopedPolicyStatic.facts(
                    configured, scope, family, keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
                );
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
            (f.frozen, f.dataHash) = PolicyComponents.facts(
                _collectionConfig(collection, scope).source,
                scope,
                family,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
        } else {
            StoredGuards.componentFamily(family);
            (f.frozen, f.dataHash) = PolicyComponents.facts(
                _collectionConfig(collection, scope).source,
                scope,
                family,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
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
        return (
            true,
            PolicyComponents.snapshotHash(
                _collectionConfig(collection, scope).source,
                cid,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            )
        );
    }

    function read(
        GraphSelection.Context storage graph,
        CollectionSelection.Context storage collection,
        ProfileSelection.Context storage profiles,
        bytes calldata input
    ) public view returns (bool handled, bytes memory encoded) {
        bytes4 selector = bytes4(input[:4]);
        if (selector == 0x551c5e46) {
            // finalitySourceProfile
            uint8 index = abi.decode(input[4:], (uint8));
            ProfileSelection.profileHash(index);
            return (true, abi.encode(profiles.profiles[index]));
        }
        if (selector == 0xddfaf08f) {
            // collectionPreservationPolicyPublicationBinding
            return (true, abi.encode(collection.binding));
        }
        if (selector == 0x3517ed94) {
            // scopedPreservationPolicyPublicationBinding
            return (true, abi.encode(graph.binding));
        }
        if (selector == 0x553ea121) {
            // scopedPreservationPolicySnapshotValidationGas
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                result = ViewConfiguration.catalogue(graph.original, scope);
            } else if (GraphSelection.isPolicy(graph, scope)) {
                result = GraphSelection.sources(graph, scope);
            } else if (CollectionSelection.isPolicy(collection, scope)) {
                result = CollectionSelection.sources(collection, scope);
            } else {
                result = ProfileSelection.current(profiles, scope);
            }
            return (true, abi.encode(result));
        }
        if (selector == 0xa9d748fc) {
            // inputManifestBytes
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                bytes memory result = ViewOperations.manifest(graph.original, scope);
                return (true, abi.encode(result));
            }
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                (StreamFinalityScopeInputs memory result, bytes32 schema, bytes32 canon) =
                    ViewOperations.inputs(graph.original, scope, manifestHash);
                return (true, abi.encode(result, schema, canon));
            }
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                IStreamFinalitySanctionReview.ReviewFacts memory result =
                    ViewOperations.review(graph.original, scope, manifestHash);
                return (true, abi.encode(result));
            }
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                (
                    StreamFinalityScopeInputs memory result,
                    bytes32 schema,
                    bytes32 canon,
                    IStreamFinalitySanctionReview.ReviewFacts memory review
                ) = ViewOperations.prepared(graph.original, scope, manifestHash, components, false);
                return (true, abi.encode(result, schema, canon));
            }
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                (
                    StreamFinalityScopeInputs memory result,
                    bytes32 schema,
                    bytes32 canon,
                    IStreamFinalitySanctionReview.ReviewFacts memory review
                ) = ViewOperations.prepared(graph.original, scope, manifestHash, components, true);
                return (true, abi.encode(result, schema, canon, review));
            }
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
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                (bytes32 result, uint64 revision, bytes32 context) =
                    ViewMetadata.root(graph.original, scope);
                return (true, abi.encode(result, revision, context));
            }
            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            (bytes32 result, uint64 revision, bytes32 context) = ScopedPolicyMetadata.root(
                _metadataConfigV2(graph, scope),
                scope,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
            return (true, abi.encode(result, revision, context));
        }
        if (selector == 0x03bbdf0b) {
            // scopedSnapshotHash
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                bytes32 result = ViewMetadata.snapshot(graph.original, scope);
                return (true, abi.encode(result));
            }
            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            bytes32 result = ScopedPolicyMetadata.snapshot(
                _metadataConfigV2(graph, scope),
                scope,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
            return (true, abi.encode(result));
        }
        if (selector == 0x882621aa) {
            // scopedManifest
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            if (scope.scopeType == StreamFinalityScopeType.VIEW) {
                (bool exists, bytes32 result) = ViewMetadata.manifest(graph.original, scope);
                return (true, abi.encode(exists, result));
            }
            if (!GraphSelection.isPolicy(graph, scope)) return (false, bytes(""));
            (bool exists, bytes32 result) = ScopedPolicyMetadata.manifest(
                _metadataConfigV2(graph, scope),
                scope,
                keccak256("6529STREAM_TOKEN_PRESERVATION_FAMILY_V2")
            );
            return (true, abi.encode(exists, result));
        }
        if (selector == 0x15439b03) {
            // scopedPreservationPolicySnapshotHost
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            ScopedPolicyReads.Config memory config = _scopedPolicyConfig(graph, scope);
            return (true, abi.encode(config.targets[8]));
        }
        if (selector == 0x65a6c10a) {
            // scopedPreservationPolicySnapshotCodeHash
            StreamFinalityScope memory scope = abi.decode(input[4:], (StreamFinalityScope));
            ScopedPolicyReads.Config memory config = _scopedPolicyConfig(graph, scope);
            return (true, abi.encode(config.codeHashes[8]));
        }
        revert UnsupportedPreservationSelector();
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
