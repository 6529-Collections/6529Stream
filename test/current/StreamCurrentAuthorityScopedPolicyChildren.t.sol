// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
} from "../helpers/StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationFactoryV2 as Factory
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as G
} from "../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationTypesV2 as Domains
} from "../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityScopedPolicyPublicationTypesV2.sol";
import {
    StreamScopedPolicyPublicationRecipeV2 as Recipe
} from "../../smart-contracts/domains/finality/StreamScopedPolicyPublicationRecipeV2.sol";
import {
    IStreamFinalityEntropySourceFactory as EntropyFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as EntropySet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityCoordinatorInventory as Coordinators
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as Snapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    IStreamScopedPolicyReferencePublicationV2 as Reference
} from "../../smart-contracts/interfaces/stream/preservation/IStreamScopedPolicyReferencePublicationV2.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as Checkpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as Outputs
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2 as Inventory
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedPolicyRenderCriticalInventoryV2.sol";
import {
    StreamCurrentAuthorityScopedBundleArchiveCoverage as Bundle
} from "../../smart-contracts/domains/preservation/StreamCurrentAuthorityScopedBundleArchiveCoverage.sol";
import {
    StreamArtistArchiveOriginTypes as O
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as D
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamArtistCurrentAuthorityTypes as Authority
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistCurrentAuthorityTypes.sol";
import {
    IStreamCurrentAuthorityDeferredPolicyBindingV2 as Deferred
} from "../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityDeferredPolicyBindingV2.sol";
import {
    StreamCurrentAuthorityDeferredPolicyBindingTypesV2 as DeferredTypes
} from "../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityDeferredPolicyBindingTypesV2.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipManifest,
    StreamScopeMembershipFacts
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamScopeMembershipEncoding as MembershipEncoding
} from "../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";
import {
    StreamMetadataSubjects as Subjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamRecordFamilies as Families
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamSchemaRegistry as Schemas
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamPreservationRecords as Records
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";

/// @notice Genuine TOKEN/RELEASE/SEASON child construction with collection-policy binding pending.
/// @dev Uses real Core, Safe/Artist recovery, Metadata governance/publication, scope membership,
/// complete original Coordinator inventory/source sets and all seven factory CREATE workers.
/// Native execution, gas/size qualification and the integrated original-authority ratification
/// codec remain validation prerequisites. No STATIC snapshot/reference/root or Finality ceremony
/// is claimed by construction of these empty publication children.
contract StreamCurrentAuthorityScopedPolicyChildrenTest is
    StreamCurrentAuthorityDeferredScopedPolicyAssemblyFixture
{
    function testActualTokenChildrenWhileCollectionPolicyRemainsPending() public {
        _prepare(StreamFinalityScopeType.TOKEN);
    }

    function testActualReleaseChildrenWhileCollectionPolicyRemainsPending() public {
        _prepare(StreamFinalityScopeType.RELEASE);
    }

    function testActualSeasonChildrenWhileCollectionPolicyRemainsPending() public {
        _prepare(StreamFinalityScopeType.SEASON);
    }

    function _prepare(StreamFinalityScopeType kind) private {
        _deployAssemblyGraph();
        _activateAssemblyArtwork();
        _authorityRecoverOriginal();
        // This publishes the actual original native root and completes the collection token/
        // Coordinator inventories. Metadata record publication remains unlocked.
        _assemblyPublishOriginalRoot();
        bytes32 originalPresentation = keccak256(abi.encode(assemblyRouter.artistPresentation(1)));
        bytes32 originalAnchors = keccak256(abi.encode(assemblyAuthorityResolver.anchors()));
        bytes32 originalRoot = assemblyRouter.collectionContentRootHead(1);
        require(originalRoot != 0 && originalRoot == assemblyOriginalContentRoot);
        _pending();
        StreamFinalityScope memory scope = _scope(kind);
        uint256 count = kind == StreamFinalityScopeType.TOKEN ? 1 : 2;
        StreamScopeMembershipFacts memory membership =
            assemblyMembership.requireScopeMembership(scope);
        require(membership.tokenCount == count && membership.membershipHash != 0);
        require(
            membership.scopeSubject
                == Subjects.scopeSubject(block.chainid, address(assemblyCore), scope)
        );
        require(assemblyMembership.scopeTokenAt(scope, 0) == 1);
        if (count == 2) require(assemblyMembership.scopeTokenAt(scope, 1) == 2);

        bytes32 plan = assemblyCoordinators.beginInventory(scope);
        assemblyCoordinators.appendInventory(plan, count);
        Coordinators.Progress memory progress = assemblyCoordinators.requireCompleteInventory(plan);
        require(
            progress.complete && progress.processedTokens == count && progress.tokenCount == count
        );
        require(progress.coordinatorCount == 1 && progress.commitment != 0);
        Coordinators.Coordinator memory original = assemblyCoordinators.requireCoordinator(plan, 0);
        require(
            original.coordinator == address(assemblyEntropy)
                && original.indexedCodeHash == address(assemblyEntropy).codehash
        );
        EntropyFactory sourceFactory = EntropyFactory(sourceScopedPolicyEntropyFactory);
        require(sourceFactory.currentInventoryPlan(scope) == plan);
        address set = sourceFactory.prepareSourceSet(scope);
        (address actual, bytes32 runtime) = sourceFactory.sourceSetForPlan(plan);
        require(actual == set && runtime == set.codehash && set.code.length != 0);
        EntropySet(set).requireCurrentSourceSet();
        require(
            keccak256(abi.encode(EntropySet(set).sourceScope())) == keccak256(abi.encode(scope))
        );
        require(EntropySet(set).sourceCount() == 1 && EntropySet(set).sourcePolicyAt(0).frozen);

        Factory factory = Factory(scopedGraphFactory);
        G.Graph memory graph = factory.prepareGraph(scope, 2);
        require(graph.preparedChildren == 2 && graph.inventoryPlan == plan);
        graph = factory.prepareGraph(scope, 2);
        require(graph.preparedChildren == 4);
        graph = factory.prepareGraph(scope, 3);
        require(graph.preparedChildren == 7);
        require(
            keccak256(abi.encode(graph))
                == keccak256(abi.encode(factory.requireCurrentGraph(scope)))
        );
        require(
            keccak256(abi.encode(graph)) == keccak256(abi.encode(factory.prepareGraph(scope, 7))),
            "complete graph is idempotent"
        );
        _children(factory, graph, set, plan);
        _pending();
        require(keccak256(abi.encode(assemblyRouter.artistPresentation(1))) == originalPresentation);
        require(keccak256(abi.encode(assemblyAuthorityResolver.anchors())) == originalAnchors);
        require(assemblyRouter.collectionContentRootHead(1) == originalRoot);
        require(address(assemblyFinality.sanctionReads()) == assemblySuite.registry);
        require(assemblyMetadata.artistRegistry() == assemblySuite.registry);
        require(assemblyFinality.scopeEvidenceProvider() == address(assemblyProvider));
        require(assemblyArtifact.finalityRegistry() == address(assemblyFinality));
    }

    function _scope(StreamFinalityScopeType kind)
        private
        returns (StreamFinalityScope memory scope)
    {
        if (kind == StreamFinalityScopeType.TOKEN) {
            return StreamFinalityScope(kind, 1, 1, 0);
        }
        require(kind == StreamFinalityScopeType.RELEASE || kind == StreamFinalityScopeType.SEASON);
        _assemblyRegisterDocument(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            Schemas.DocumentKind.SCHEMA,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-v1.schema.json")),
            assemblySchemas.RAW_BYTES()
        );
        _assemblyRegisterDocument(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            Schemas.DocumentKind.CANONICALIZATION,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-abi-v1.json")),
            assemblySchemas.RAW_BYTES()
        );
        bytes32 recordType = keccak256("SCOPE_MEMBERSHIP");
        (bytes32 actionScope, bytes32 oldHash, bytes32 newHash) =
            assemblyMetadata.recordTypeTransition(recordType, Families.IDENTITY, uint16(384));
        _assemblyGovernanceCall(
            1,
            address(assemblyMetadata),
            abi.encodeCall(
                assemblyMetadata.admitRecordType, (recordType, Families.IDENTITY, uint16(384))
            ),
            actionScope,
            oldHash,
            newHash
        );
        _assemblyGrantFamily(Families.IDENTITY, 7, address(this));
        bytes memory tokenBytes = abi.encode(uint256(1), uint256(2));
        (bytes32 chunk, address pointer) = assemblyStore.publishChunk(tokenBytes);
        require(chunk == keccak256(tokenBytes) && pointer.code.length == tokenBytes.length + 1);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = chunk;
        StreamScopeMembershipManifest memory manifest = StreamScopeMembershipManifest(
            1, block.chainid, address(assemblyCore), 1, uint8(kind), 2, keccak256(tokenBytes), parts
        );
        bytes memory payload = MembershipEncoding.encode(manifest);
        Records.CollectionRecord memory record;
        record.recordType = recordType;
        record.subjectId = Subjects.scopeSubject(
            block.chainid,
            address(assemblyCore),
            StreamFinalityScope(StreamFinalityScopeType.COLLECTION, 1, 0, 0)
        );
        record.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        record.contentHash = Records.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        record.uri = "https://fixtures.example.invalid/current-authority/scoped-policy-membership";
        record.effectiveAt = uint64(block.timestamp);
        bytes32 saved = assemblyMetadata.recordCollectionRecordWithPayload(1, record, payload);
        scope = assemblyMembership.beginScopeMembership(saved);
        assemblyMembership.continueScopeMembership(scope, 1);
        StreamScopeMembershipFacts memory facts = assemblyMembership.requireScopeMembership(scope);
        require(scope.scopeType == kind && scope.collectionId == 1 && scope.tokenId == 0);
        require(
            scope.scopeId
                == MembershipEncoding.scopeId(
                    block.chainid, address(assemblyCore), 1, uint8(kind), saved
                )
        );
        require(facts.sourceRecordHash == saved && facts.scopeManifestHash == keccak256(payload));
        require(facts.tokenCount == 2 && facts.tokenListHash == keccak256(tokenBytes));
    }

    function _children(Factory factory, G.Graph memory graph, address set, bytes32 plan)
        private
        view
    {
        G.Recipe memory recipe = factory.recipe();
        O.Dependencies memory origin = factory.originDependencies();
        D.Dependencies memory authority = factory.authorityDependencies();
        require(factory.scopedPolicyPublicationFactoryProfile() == Domains.FACTORY_PROFILE);
        require(
            factory.recipeHash() == Domains.recipeHash(block.chainid, recipe, origin, authority)
        );
        require(
            keccak256(abi.encode(origin)) == keccak256(abi.encode(_assemblyOriginDependencies()))
        );
        require(
            keccak256(abi.encode(authority))
                == keccak256(abi.encode(_assemblyAuthorityDependencies()))
        );
        require(
            graph.sourceSet == set && graph.sourceSetCodeHash == set.codehash
                && graph.inventoryPlan == plan
        );
        require(
            graph.graphId
                == keccak256(
                    abi.encode(
                        Domains.GRAPH_DOMAIN,
                        block.chainid,
                        address(factory),
                        factory.recipeHash(),
                        factory.sourceFactoryDependenciesHash(),
                        graph.scope,
                        plan,
                        set,
                        set.codehash
                    )
                )
        );
        for (uint256 i; i < 7; ++i) {
            require(
                graph.children[i].code.length != 0
                    && graph.children[i].codehash == graph.codeHashes[i]
            );
            for (uint256 j; j < i; ++j) {
                require(graph.children[i] != graph.children[j], "seven distinct genuine children");
            }
        }
        require(
            Checkpoint(graph.children[1]).scopedPolicyProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        require(
            Outputs(graph.children[2]).scopedOutputProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_CURRENT_FULL_CONTENT_V2")
        );
        require(
            Snapshot(graph.children[3]).scopedPolicySnapshotProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_SNAPSHOT_V2")
        );
        require(
            Reference(graph.children[4]).scopedPolicyReferenceProfile()
                == keccak256("6529STREAM_SCOPED_POLICY_REFERENCE_V2")
        );
        require(
            keccak256(abi.encode(Snapshot(graph.children[3]).dependencies()))
                == keccak256(abi.encode(Recipe.snapshot(recipe, graph)))
        );
        require(
            keccak256(abi.encode(Reference(graph.children[4]).dependencies()))
                == keccak256(abi.encode(Recipe.referenceDependencies(recipe, graph)))
        );
        Inventory inventory = Inventory(graph.children[5]);
        Bundle bundle = Bundle(graph.children[6]);
        require(inventory.scopedPolicyInventoryProfile() == D.SCOPED_POLICY_INVENTORY_PROFILE);
        require(inventory.originProfile() == D.SCOPED_POLICY_INVENTORY_PROFILE);
        require(
            keccak256(abi.encode(inventory.originalAnchor()))
                == keccak256(abi.encode(Recipe.inventory(recipe, graph)))
        );
        require(inventory.originalAnchor().artistTargets[0] == assemblySuite.registry);
        require(inventory.originalAnchor().artistTargets[4] == assemblySuite.archive);
        require(
            inventory.dependencyHash()
                == D.dependencyHash(
                    D.SCOPED_POLICY_INVENTORY_PROFILE,
                    Recipe.inventory(recipe, graph),
                    origin,
                    authority
                )
        );
        require(
            keccak256(abi.encode(inventory.originDependencies(), inventory.authorityDependencies()))
                == keccak256(abi.encode(origin, authority))
        );
        require(bundle.INVENTORY_PROFILE() == D.SCOPED_POLICY_INVENTORY_PROFILE);
        require(
            keccak256(abi.encode(bundle.dependencies()))
                == keccak256(abi.encode(Recipe.bundle(recipe, graph)))
        );
        require(
            keccak256(abi.encode(bundle.originDependencies(), bundle.authorityDependencies()))
                == keccak256(abi.encode(origin, authority))
        );
        require(
            bundle.dependencyHash()
                == keccak256(
                    abi.encode(
                        bundle.PROFILE(),
                        D.SCOPED_POLICY_INVENTORY_PROFILE,
                        Recipe.bundle(recipe, graph),
                        origin,
                        authority
                    )
                )
        );
        Authority.Anchors memory anchors = assemblyAuthorityResolver.anchors();
        require(
            anchors.targets[3] == assemblySuite.registry
                && anchors.targets[4] == address(assemblyProvider)
        );
        require(anchors.finalityRegistry == address(assemblyFinality));
        require(Snapshot(graph.children[3]).snapshotCount(graph.scope) == 0);
        require(Reference(graph.children[4]).referenceCount(graph.scope) == 0);
    }

    function _pending() private view {
        Deferred provider = Deferred(address(assemblyProvider));
        require(
            provider.deferredPolicyBindingProfile() == DeferredTypes.PROFILE
                && provider.policyBindingHash() == 0
        );
        (bool ok, bytes memory error_) =
            address(provider).staticcall(abi.encodeCall(provider.requirePolicyBinding, ()));
        require(
            !ok
                && keccak256(error_)
                    == keccak256(
                        abi.encodeWithSelector(DeferredTypes.CollectionPolicyPending.selector)
                    )
        );
    }
}
