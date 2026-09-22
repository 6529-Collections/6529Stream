// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture
} from "./StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture.sol";
import { OfficialSafe } from "./OfficialSafeFixture.sol";
import { IERC165 as CPIERC165 } from "../../smart-contracts/vendor/openzeppelin/IERC165.sol";
import {
    IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1 as CPFactoryInterface
} from "../../smart-contracts/interfaces/stream/finality/IStreamCurrentAuthorityPreservationPolicyPublicationFactoryV1.sol";
import {
    StreamPreservationPolicyPublicationGraphTypesV1 as CPGraph
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationPolicyPublicationGraphTypesV1.sol";
import {
    StreamCurrentAuthorityPreservationPolicyPublicationTypesV1 as CPDomains
} from "../../smart-contracts/interfaces/stream/finality/StreamCurrentAuthorityPreservationPolicyPublicationTypesV1.sol";
import {
    StreamPreservationPolicyPublicationRecipeV1 as CPRecipe
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyPublicationRecipeV1.sol";
import {
    IStreamFinalityEntropySourceFactory as CPSourceFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as CPSourceSet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityCoordinatorInventory as CPCoordinators
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import {
    IStreamStaticSelectionCheckpoint as CPSelection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    StreamTerminalEntropyReadiness as CPReadiness
} from "../../smart-contracts/domains/finality/StreamTerminalEntropyReadiness.sol";
import {
    IStreamPreservationPolicyContentCheckpointV1 as CPCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyContentCheckpointV1.sol";
import {
    IStreamPreservationPolicyOutputManifestV1 as CPOutput
} from "../../smart-contracts/interfaces/stream/finality/IStreamPreservationPolicyOutputManifestV1.sol";
import {
    StreamPreservationTokenProducerProfilesV1 as CPFamily
} from "../../smart-contracts/interfaces/stream/finality/StreamPreservationTokenProducerProfilesV1.sol";
import {
    IStreamPreservationPolicySnapshotPublicationV1 as CPSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicySnapshotPublicationV1.sol";
import {
    StreamPreservationPolicySnapshotTypesV1 as CPSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamPreservationPolicySnapshotTypesV1.sol";
import {
    IStreamPreservationPolicyReferencePublicationV1 as CPReference
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationPolicyReferencePublicationV1.sol";
import {
    IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1 as CPInventory
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityPreservationPolicyRenderCriticalInventoryV1.sol";
import {
    IStreamCurrentAuthorityBundleArchiveCoverage as CPBundle
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityBundleArchiveCoverage.sol";
import {
    IStreamBundleArchiveCoverage as CPBaseBundle
} from "../../smart-contracts/interfaces/stream/preservation/IStreamBundleArchiveCoverage.sol";
import {
    IStreamArtistArchiveOriginInventory as CPOrigins
} from "../../smart-contracts/interfaces/stream/preservation/IStreamArtistArchiveOriginInventory.sol";
import {
    IStreamCurrentAuthorityInventory as CPAuthority
} from "../../smart-contracts/interfaces/stream/preservation/IStreamCurrentAuthorityInventory.sol";
import {
    StreamArtistArchiveOriginTypes as CPOriginTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamArtistArchiveOriginTypes.sol";
import {
    StreamCurrentAuthorityInventoryTypes as CPAuthorityTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamCurrentAuthorityInventoryTypes.sol";
import {
    StreamRenderCriticalSourceTypes as CPInventoryTypes
} from "../../smart-contracts/interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamPreservationPolicyContentRootSchemasV2 as CPRootDefinitions
} from "../../smart-contracts/domains/finality/StreamPreservationPolicyContentRootSchemasV2.sol";
import {
    StreamPreservationPolicySnapshotDefinitionsV2 as CPSnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamPreservationPolicySnapshotDefinitionsV2.sol";
import {
    StreamPreservationPolicyReferenceDefinitionsV2 as CPReferenceDefinitions
} from "../../smart-contracts/domains/records/StreamPreservationPolicyReferenceDefinitionsV2.sol";
import {
    StreamReferenceRenderDefinitions as CPReferenceCommon
} from "../../smart-contracts/domains/records/StreamReferenceRenderDefinitions.sol";
import {
    IStreamSchemaRegistry as CPSchemas
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    StreamRecordFamilies as CPFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    StreamFinalityScope as CPScope,
    StreamFinalityScopeType as CPScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipFacts as CPMembershipFacts
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    IStreamContentRootPublication as CPRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamContentRootPublication.sol";
import {
    IStreamPreservationPolicyContentRootPublicationV1 as CPPreservationRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamPreservationPolicyContentRootPublicationV1.sol";
import {
    IStreamMetadataServingFacts as CPServing
} from "../../smart-contracts/interfaces/stream/metadata/IStreamMetadataServingFacts.sol";
import {
    StreamPreservationPolicySnapshotRootReadsV1 as CPRootReads
} from "../../smart-contracts/domains/records/StreamPreservationPolicySnapshotRootReadsV1.sol";

/// @notice Genuine collection V2 prerequisites for separately submitted Client/Safe calls.
/// @dev Call deploy/activate/recover on the inherited actual graph first. This helper registers
/// exact definitions and grants, locks the original sources, and creates seven factory children.
/// It never invokes the Client checkpoint/output/snapshot/reference/inventory/bundle writers.
/// Synthetic STATIC assessment evidence remains the inherited fixture boundary; no browser,
/// caller-receipt, native-capacity, or executed protocol acceptance is established by source.
abstract contract StreamCurrentAuthorityCollectionPreservationCallerFixture is
    StreamCurrentAuthorityScopedPreservationPolicyPublicationFixture
{
    struct CollectionPreservationCallerPreparation {
        CPScope scope;
        address writer;
        uint256 writerNonceAfterSetup;
        bytes32 legacyContentFamily;
        CPMembershipFacts membership;
        CPCoordinators.Progress coordinatorInventory;
        CPGraph.Graph graph;
        bytes32 selectionId;
        CPSelection.Plan selection;
        bytes32 factoryRecipeHash;
        bytes32 sourceFactoryDependenciesHash;
        CPOriginTypes.Dependencies origin;
        CPAuthorityTypes.Dependencies authority;
    }

    /// @dev The original official root Safe is the default caller for this new fixture only.
    /// A composed caller harness can override the shared hook, but must select an actual fixture Safe.
    function _authorityScopedPublicationWriter() internal view virtual override returns (address) {
        return address(assemblyRoot);
    }

    function _authorityPrepareCollectionPreservationCaller()
        internal
        returns (CollectionPreservationCallerPreparation memory p)
    {
        p.writer = _authorityScopedPublicationWriter();
        require(
            (p.writer == address(assemblyRoot) || p.writer == address(assemblyArtist))
                && p.writer.code.length != 0 && OfficialSafe(p.writer).getThreshold() == 2,
            "actual threshold Safe caller, no fixture impersonation"
        );
        require(
            address(assemblyArtists) == assemblyAuthorityResolver.anchors().targets[3],
            "collection original Router preparation in Artist A"
        );
        p.legacyContentFamily = _authorityPreparePreservationPolicySourcePrefix();
        _cpDefinitions();
        (bool curator, uint64 curatorRevision) =
            assemblyMetadata.familyWriter(1, CPFamilies.CURATOR, 3, p.writer);
        if (!curator) _assemblyGrantFamily(CPFamilies.CURATOR, 3, p.writer);
        else require(curatorRevision != 0, "retained curator grant");
        _cpWriter(p.writer, CPFamilies.SNAPSHOT, 7);
        _cpWriter(p.writer, CPFamilies.IDENTITY, 7);
        _cpWriter(p.writer, CPFamilies.CURATOR, 3);
        p.scope = CPScope(CPScopeType.COLLECTION, 1, 0, 0);
        uint256 count = _assemblyArtworkTokenCount();
        require(count == 2 || count == 4, "explicit original or caller four-row recipe");
        p.membership = assemblyMembership.requireScopeMembership(p.scope);
        require(p.membership.tokenCount == count && p.membership.membershipHash != 0);
        for (uint256 i; i < count; ++i) {
            require(assemblyMembership.scopeTokenAt(p.scope, i) == i + 1);
        }
        p.coordinatorInventory =
            assemblyCoordinators.requireCompleteInventory(assemblyCoordinatorInventoryPlan);
        require(
            p.coordinatorInventory.complete && p.coordinatorInventory.tokenCount == count
                && p.coordinatorInventory.processedTokens == count
                && p.coordinatorInventory.coordinatorCount == 1
                && p.coordinatorInventory.commitment != 0,
            "actual complete collection token inventory"
        );
        CPCoordinators.Coordinator memory original =
            assemblyCoordinators.requireCoordinator(assemblyCoordinatorInventoryPlan, 0);
        require(
            original.coordinator == address(assemblyEntropy)
                && original.indexedCodeHash == address(assemblyEntropy).codehash
        );
        CPSourceFactory sources = CPSourceFactory(sourcePolicyEntropyFactory);
        require(sources.currentInventoryPlan(p.scope) == assemblyCoordinatorInventoryPlan);
        address sourceSet = sources.prepareSourceSet(p.scope);
        (address retainedSet, bytes32 retainedHash) =
            sources.sourceSetForPlan(assemblyCoordinatorInventoryPlan);
        require(
            sourceSet == retainedSet && sourceSet.code.length != 0
                && sourceSet.codehash == retainedHash
        );
        CPSourceSet(sourceSet).requireCurrentSourceSet();
        require(
            CPSourceSet(sourceSet).factory() == sourcePolicyEntropyFactory
                && CPSourceSet(sourceSet).inventoryPlan() == assemblyCoordinatorInventoryPlan
                && CPSourceSet(sourceSet).sourceCount() == 1
                && CPSourceSet(sourceSet).sourcePolicyAt(0).frozen
                && keccak256(abi.encode(CPSourceSet(sourceSet).sourceScope()))
                    == keccak256(abi.encode(p.scope))
                && keccak256(abi.encode(CPSourceSet(sourceSet).scopeMembershipFacts()))
                    == keccak256(abi.encode(p.membership)),
            "current collection source set, exact scope and membership"
        );
        CPFactoryInterface factory = CPFactoryInterface(collectionGraphFactory);
        _cpInterface(collectionGraphFactory, type(CPFactoryInterface).interfaceId);
        require(
            collectionGraphFactory == collectionGraphBinding.factory
                && collectionGraphFactory.codehash == collectionGraphBinding.factoryCodeHash
                && factory.preservationPolicyPublicationFactoryProfile()
                    == CPDomains.FACTORY_PROFILE,
            "constructor-fixed current-authority collection factory"
        );
        p.origin = factory.originDependencies();
        p.authority = factory.authorityDependencies();
        p.factoryRecipeHash = factory.recipeHash();
        p.sourceFactoryDependenciesHash = factory.sourceFactoryDependenciesHash();
        require(
            p.factoryRecipeHash == collectionGraphBinding.recipeHash
                && p.sourceFactoryDependenciesHash
                    == collectionGraphBinding.sourceFactoryDependenciesHash
                && keccak256(abi.encode(p.origin))
                    == keccak256(abi.encode(assemblyInventory.originDependencies()))
                && keccak256(abi.encode(p.authority))
                    == keccak256(abi.encode(assemblyInventory.authorityDependencies())),
            "original graph origin and current-authority pins"
        );
        CPGraph.Recipe memory recipe = factory.recipe();
        require(
            CPDomains.recipeHash(block.chainid, recipe, p.origin, p.authority)
                == p.factoryRecipeHash
        );
        CPInventoryTypes.Dependencies memory originalAnchor = assemblyInventory.originalAnchor();
        for (uint256 i; i < 12; ++i) {
            if (i == 5 || i == 6) {
                require(
                    recipe.inventory.targets[i] == address(0) && recipe.inventory.codeHashes[i] == 0
                );
            } else {
                require(
                    recipe.inventory.targets[i] == originalAnchor.targets[i]
                        && recipe.inventory.codeHashes[i] == originalAnchor.codeHashes[i]
                );
            }
        }
        require(
            keccak256(
                abi.encode(
                    recipe.inventory.artistTargets,
                    recipe.inventory.artistCodeHashes,
                    recipe.inventory.artistContentOwner,
                    recipe.inventory.artistContentOwnerCodeHash
                )
            )
            == keccak256(
                abi.encode(
                    originalAnchor.artistTargets,
                    originalAnchor.artistCodeHashes,
                    originalAnchor.artistContentOwner,
                    originalAnchor.artistContentOwnerCodeHash
                )
            ),
            "fixed original Artist suite retained in the collection recipe"
        );
        p.graph = factory.prepareGraph(p.scope, 7);
        require(
            p.graph.preparedChildren == 7
                && p.graph.inventoryPlan == assemblyCoordinatorInventoryPlan
                && p.graph.sourceSet == sourceSet && p.graph.sourceSetCodeHash == retainedHash
                && keccak256(abi.encode(p.graph))
                    == keccak256(abi.encode(factory.requireCurrentGraph(p.scope))),
            "seven real current collection children"
        );
        require(
            p.graph.graphId
                == keccak256(
                    abi.encode(
                        CPDomains.GRAPH_DOMAIN,
                        block.chainid,
                        collectionGraphFactory,
                        p.factoryRecipeHash,
                        p.sourceFactoryDependenciesHash,
                        p.scope,
                        p.graph.inventoryPlan,
                        p.graph.sourceSet,
                        p.graph.sourceSetCodeHash
                    )
                ),
            "exact collection graph identity"
        );
        _cpChildren(p, recipe);
        // STATIC selection is a separate real setup source, outside the Client's eleven hosts.
        // No content-checkpoint begin/append call is made here.
        CPSelection selections = CPSelection(sourceStaticSelection);
        p.selectionId = selections.begin(p.scope);
        selections.append(p.selectionId, count);
        p.selection = selections.requireCurrentCheckpoint(p.selectionId);
        require(
            p.selection.tokenCount == count && p.selection.nextIndex == count
                && p.selection.selectionRoot != 0,
            "complete actual collection STATIC selection"
        );
        require(
            assemblyRouter.collectionContentRootHead(1) == 0
                && CPSnapshot(p.graph.children[3]).snapshotCount(p.scope) == 0
                && CPReference(p.graph.children[4]).referenceCount(p.scope) == 0,
            "prepared children do not manufacture a V2 root or publication"
        );
        p.writerNonceAfterSetup = OfficialSafe(p.writer).nonce();
    }

    function _cpChildren(
        CollectionPreservationCallerPreparation memory p,
        CPGraph.Recipe memory recipe
    ) private view {
        for (uint256 i; i < 7; ++i) {
            address child = p.graph.children[i];
            require(
                child.code.length != 0 && child.code.length <= 24576
                    && child.codehash == p.graph.codeHashes[i]
            );
            for (uint256 j; j < i; ++j) {
                require(child != p.graph.children[j]);
            }
        }
        CPReadiness readiness = CPReadiness(p.graph.children[0]);
        require(
            readiness.core() == address(assemblyCore)
                && readiness.metadataRouter() == address(assemblyRouter)
                && readiness.entropySourceSet() == p.graph.sourceSet
                && readiness.entropySourceSetCodeHash() == p.graph.sourceSetCodeHash
        );
        _cpInterface(p.graph.children[1], type(CPCheckpoint).interfaceId);
        CPCheckpoint checkpoint = CPCheckpoint(p.graph.children[1]);
        require(
            checkpoint.selectionCheckpoint() == sourceStaticSelection
                && checkpoint.preservationPolicyProfile() == CPFamily.COLLECTION_CHECKPOINT_PROFILE
                && checkpoint.preservationOutputProfile() == CPFamily.FAMILY_PROFILE
        );
        _cpInterface(p.graph.children[2], type(CPOutput).interfaceId);
        CPOutput output = CPOutput(p.graph.children[2]);
        require(
            output.core() == address(assemblyCore)
                && output.contentCheckpoint() == p.graph.children[1]
                && output.artifactCoverage() == recipe.inventory.targets[10]
                && output.outputProfile() == CPFamily.OUTPUT_MANIFEST_PROFILE
        );
        _cpInterface(p.graph.children[3], type(CPSnapshot).interfaceId);
        _cpInterface(p.graph.children[4], type(CPReference).interfaceId);
        require(
            CPSnapshot(p.graph.children[3]).preservationPolicySnapshotProfile()
                    == keccak256("6529STREAM_PRESERVATION_POLICY_SNAPSHOT_V2")
                && CPReference(p.graph.children[4]).preservationPolicyReferenceProfile()
                    == keccak256("6529STREAM_PRESERVATION_POLICY_REFERENCE_V2")
                && keccak256(abi.encode(CPSnapshot(p.graph.children[3]).dependencies()))
                    == keccak256(abi.encode(CPRecipe.snapshot(recipe, p.graph)))
                && keccak256(abi.encode(CPReference(p.graph.children[4]).dependencies()))
                    == keccak256(abi.encode(CPRecipe.referenceDependencies(recipe, p.graph)))
        );
        _cpInterface(p.graph.children[5], type(CPInventory).interfaceId);
        _cpInterface(p.graph.children[5], type(CPOrigins).interfaceId);
        _cpInterface(p.graph.children[5], type(CPAuthority).interfaceId);
        CPInventory inventory = CPInventory(p.graph.children[5]);
        CPInventoryTypes.Dependencies memory expected = CPRecipe.inventory(recipe, p.graph);
        require(
            inventory.originProfile() == CPAuthorityTypes.PRESERVATION_POLICY_INVENTORY_PROFILE
                && inventory.preservationPolicyInventoryProfile()
                    == CPAuthorityTypes.PRESERVATION_POLICY_INVENTORY_PROFILE
                && keccak256(abi.encode(inventory.dependencies()))
                    == keccak256(abi.encode(expected))
                && keccak256(abi.encode(inventory.originalAnchor()))
                    == keccak256(abi.encode(expected))
                && keccak256(abi.encode(inventory.originDependencies()))
                    == keccak256(abi.encode(p.origin))
                && keccak256(abi.encode(inventory.authorityDependencies()))
                    == keccak256(abi.encode(p.authority))
                && inventory.dependencyHash()
                    == CPAuthorityTypes.dependencyHash(
                        CPAuthorityTypes.PRESERVATION_POLICY_INVENTORY_PROFILE,
                        expected,
                        p.origin,
                        p.authority
                    )
        );
        _cpInterface(p.graph.children[6], type(CPBundle).interfaceId);
        _cpInterface(p.graph.children[6], type(CPBaseBundle).interfaceId);
        CPBundle bundle = CPBundle(p.graph.children[6]);
        require(
            bundle.originProfile()
                    == keccak256(
                        "6529STREAM_CURRENT_AUTHORITY_PRESERVATION_POLICY_BUNDLE_IMMUTABLE_STOP_AGGREGATE_V1"
                    )
                && keccak256(abi.encode(bundle.dependencies()))
                    == keccak256(abi.encode(CPRecipe.bundle(recipe, p.graph)))
                && keccak256(abi.encode(bundle.originDependencies()))
                    == keccak256(abi.encode(p.origin))
                && keccak256(abi.encode(bundle.authorityDependencies()))
                    == keccak256(abi.encode(p.authority))
        );
    }

    /// @dev Read-only bridge after separately executed checkpoint/output and actual op17/root
    /// publication. A zero root cannot qualify collection snapshot preparation. This function
    /// never submits or signs that missing transaction and never substitutes a scoped root.
    function _authorityRequireCollectionPreservationCallerRoot(
        CollectionPreservationCallerPreparation memory p,
        bytes32 outputRecord,
        bytes32 rootRecord
    ) internal view returns (CPRoot.Record memory root) {
        require(rootRecord != 0 && outputRecord != 0, "genuine V2 collection root still required");
        require(
            keccak256(
                abi.encode(CPFactoryInterface(collectionGraphFactory).requireCurrentGraph(p.scope))
            ) == keccak256(abi.encode(p.graph))
        );
        CPSourceSet sources = CPSourceSet(p.graph.sourceSet);
        sources.requireCurrentSourceSet();
        CPOutput.Manifest memory output =
            CPOutput(p.graph.children[2]).requireCurrentManifest(outputRecord, assemblyArtistId);
        CPSnapshotTypes.Publication memory publication;
        publication.scope = p.scope;
        publication.outputManifestRecord = outputRecord;
        publication.contentRootRecord = rootRecord;
        CPPreservationRoot.Binding memory binding;
        (root, binding) = CPRootReads.current(
            CPSnapshot(p.graph.children[3]).dependencies(),
            publication,
            CPServing(address(assemblyRouter)).artistPresentation(1),
            output,
            sources.originalInventoryHash(),
            sources.originalPolicyChainHash(),
            CPFamily.FAMILY_PROFILE
        );
        require(
            root.publisher == p.writer && binding.profileId == CPRootDefinitions.PROFILE
                && binding.preservationOutputProfile == CPFamily.FAMILY_PROFILE,
            "same actual Safe's admitted collection V2 root"
        );
    }

    function _cpInterface(address target, bytes4 capability) private view {
        require(
            CPIERC165(target).supportsInterface(0x01ffc9a7)
                && !CPIERC165(target).supportsInterface(0xffffffff)
                && CPIERC165(target).supportsInterface(capability),
            "exact advertised child capability"
        );
    }

    function _cpWriter(address writer, bytes32 family, uint8 authorizationClass) private view {
        (bool enabled, uint64 revision) =
            assemblyMetadata.familyWriter(1, family, authorizationClass, writer);
        require(enabled && revision != 0, "actual Safe family grant");
    }

    function _cpDefinitions() private {
        _cpDefinition(
            "STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2",
            CPSchemas.DocumentKind.SCHEMA,
            CPRootDefinitions.document(CPRootDefinitions.ROOT_SCHEMA)
        );
        _cpDefinition(
            "STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2",
            CPSchemas.DocumentKind.CANONICALIZATION,
            CPRootDefinitions.document(CPRootDefinitions.ROOT_CANON)
        );
        string[10] memory names = [
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_ABI_V2",
            "STREAM_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_PROFILE_V2",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_SNAPSHOT_V2",
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_ABI_V2",
            "STREAM_PRESERVATION_POLICY_COLLECTION_REFERENCE_PROFILE_V2",
            "STREAM_ABI_PRESERVATION_POLICY_COLLECTION_REFERENCE_V2",
            "STREAM_REFERENCE_NATIVE_ENVIRONMENT_V1",
            "STREAM_REFERENCE_PNG_OBJECT_V1",
            "STREAM_REFERENCE_RUNTIME_ZIP_OBJECT_V1",
            "STREAM_REFERENCE_NATIVE_FORMATS_V1"
        ];
        bytes32[10] memory hashes = [
            CPSnapshotDefinitions.SCHEMA_HASH,
            CPSnapshotDefinitions.PROFILE_HASH,
            CPSnapshotDefinitions.CANON_HASH,
            CPReferenceDefinitions.SCHEMA_HASH,
            CPReferenceDefinitions.PROFILE_HASH,
            CPReferenceDefinitions.CANON_HASH,
            CPReferenceCommon.ENVIRONMENT_SCHEMA_HASH,
            CPReferenceCommon.PNG_SCHEMA_HASH,
            CPReferenceCommon.ZIP_SCHEMA_HASH,
            CPReferenceCommon.FORMAT_CATALOG_HASH
        ];
        uint256[10] memory lengths = [
            CPSnapshotDefinitions.SCHEMA_BYTES,
            CPSnapshotDefinitions.PROFILE_BYTES,
            CPSnapshotDefinitions.CANON_BYTES,
            uint256(CPReferenceDefinitions.SCHEMA_BYTES),
            CPReferenceDefinitions.PROFILE_BYTES,
            CPReferenceDefinitions.CANON_BYTES,
            CPReferenceCommon.ENVIRONMENT_SCHEMA_BYTES,
            CPReferenceCommon.PNG_SCHEMA_BYTES,
            CPReferenceCommon.ZIP_SCHEMA_BYTES,
            CPReferenceCommon.FORMAT_CATALOG_BYTES
        ];
        for (uint256 i; i < names.length; ++i) {
            string memory path = i < 6
                ? string.concat(
                    "docs/schemas/preservation/preservation-policy-collection-",
                    i < 3 ? "snapshot-v2." : "reference-v2.",
                    i % 3 == 0 ? "schema" : i % 3 == 1 ? "profile" : "abi",
                    ".json"
                )
                : string.concat("schemas/records/", names[i], ".json");
            bytes memory raw = bytes(assemblyVm.readFile(path));
            require(
                raw.length == lengths[i] && keccak256(raw) == hashes[i],
                "exact collection V2/common schema bytes"
            );
            CPSchemas.DocumentKind kind = (i == 2 || i == 5)
                ? CPSchemas.DocumentKind.CANONICALIZATION
                : (i == 1 || i == 4 || i == 9)
                    ? CPSchemas.DocumentKind.CATALOG
                    : CPSchemas.DocumentKind.SCHEMA;
            _cpDefinition(names[i], kind, raw);
        }
    }

    function _cpDefinition(string memory name, CPSchemas.DocumentKind kind, bytes memory raw)
        private
    {
        bytes32 id = keccak256(bytes(name));
        CPSchemas.DocumentView memory saved = assemblySchemas.document(id);
        if (!saved.exists) {
            require(_assemblyRegisterDocument(name, kind, raw, assemblySchemas.RAW_BYTES()) == id);
            saved = assemblySchemas.document(id);
        }
        require(
            saved.status == CPSchemas.DocumentStatus.ACTIVE && saved.specification.kind == kind
                && saved.specification.contentHash == keccak256(raw)
                && saved.specification.totalBytes == raw.length
                && saved.specification.canonicalizationId == assemblySchemas.RAW_BYTES()
                && keccak256(assemblySchemas.documentBytes(id)) == keccak256(raw),
            "retained exact active definition"
        );
    }
}
