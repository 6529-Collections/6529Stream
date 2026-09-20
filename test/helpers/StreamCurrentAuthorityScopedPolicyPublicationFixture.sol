// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentAuthorityScopedRecordsFixture
} from "./StreamCurrentAuthorityScopedRecordsFixture.sol";
import {
    StreamCurrentAuthorityScopedPolicyPublicationFactoryV2 as SPFactory
} from "../../smart-contracts/domains/finality/StreamCurrentAuthorityScopedPolicyPublicationFactoryV2.sol";
import {
    StreamScopedPolicyPublicationGraphTypesV2 as SPGraph
} from "../../smart-contracts/interfaces/stream/finality/StreamScopedPolicyPublicationGraphTypesV2.sol";
import {
    IStreamFinalityEntropySourceFactory as SPSourceFactory
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropySourceFactory.sol";
import {
    IStreamFinalityEntropyPolicySourceSet as SPSourceSet
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityEntropyPolicySourceSet.sol";
import {
    IStreamFinalityCoordinatorInventory as SPCoordinators
} from "../../smart-contracts/interfaces/stream/finality/IStreamFinalityCoordinatorInventory.sol";
import {
    IStreamStaticSelectionCheckpoint as SPSelection
} from "../../smart-contracts/interfaces/stream/finality/IStreamStaticSelectionCheckpoint.sol";
import {
    IStreamScopedPolicyContentCheckpointV2 as SPCheckpoint
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyContentCheckpointV2.sol";
import {
    IStreamScopedPolicyOutputManifestV2 as SPOutputs
} from "../../smart-contracts/interfaces/stream/finality/IStreamScopedPolicyOutputManifestV2.sol";
import {
    IStreamScopedPolicySnapshotPublicationV2 as SPSnapshot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicySnapshotPublicationV2.sol";
import {
    StreamScopedPolicySnapshotTypesV2 as SPSnapshotTypes
} from "../../smart-contracts/interfaces/stream/metadata/StreamScopedPolicySnapshotTypesV2.sol";
import {
    IStreamScopedContentRootPublication as SPRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedContentRootPublication.sol";
import {
    IStreamScopedPolicyContentRootPublicationV2 as SPPolicyRoot
} from "../../smart-contracts/interfaces/stream/metadata/IStreamScopedPolicyContentRootPublicationV2.sol";
import {
    StreamScopedPolicyOutputSchemasV2 as SPOutputDefinitions
} from "../../smart-contracts/domains/finality/StreamScopedPolicyOutputSchemasV2.sol";
import {
    StreamScopedPolicyContentRootSchemasV2 as SPRootDefinitions
} from "../../smart-contracts/domains/finality/StreamScopedPolicyContentRootSchemasV2.sol";
import {
    StreamScopedPolicySnapshotDefinitionsV2 as SPSnapshotDefinitions
} from "../../smart-contracts/domains/records/StreamScopedPolicySnapshotDefinitionsV2.sol";
import {
    StreamFinalityScope as SPScope,
    StreamFinalityScopeType as SPScopeType
} from "../../smart-contracts/interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import {
    StreamScopeMembershipManifest as SPMembershipManifest,
    StreamScopeMembershipFacts as SPMembershipFacts
} from "../../smart-contracts/interfaces/stream/finality/StreamScopeMembershipTypes.sol";
import {
    StreamScopeMembershipEncoding as SPMembershipEncoding
} from "../../smart-contracts/domains/finality/StreamScopeMembershipEncoding.sol";
import {
    StreamMetadataSubjects as SPSubjects
} from "../../smart-contracts/domains/metadata/StreamMetadataSubjects.sol";
import {
    StreamRecordFamilies as SPFamilies
} from "../../smart-contracts/domains/records/StreamRecordFamilies.sol";
import {
    IStreamSchemaRegistry as SPSchemas
} from "../../smart-contracts/interfaces/stream/metadata/IStreamSchemaRegistry.sol";
import {
    IStreamPreservationRecords as SPRecords
} from "../../smart-contracts/interfaces/stream/preservation/IStreamPreservationRecords.sol";
import {
    IStreamCollectionMetadataV1 as SPMetadata
} from "../../smart-contracts/interfaces/stream/metadata/IStreamCollectionMetadataV1.sol";
import {
    StreamArtistOnboardingTypes as SPArtist
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistOnboardingTypes.sol";
import {
    StreamArtistContentTypes as SPContent
} from "../../smart-contracts/interfaces/stream/artist/StreamArtistContentTypes.sol";

/// @notice Genuine complete scoped STATIC publication through the original Router and Artist A.
/// @dev The caller deploys/activates the inherited real graph and performs original Safe recovery
/// before calling this helper. No native checkpoint, mock source, browser capture or finality
/// completion is manufactured. Later references, descriptions and inventory/coverage are separate.
abstract contract StreamCurrentAuthorityScopedPolicyPublicationFixture is
    StreamCurrentAuthorityScopedRecordsFixture
{
    struct AuthorityScopedPublication {
        SPScope scope;
        bytes32 membershipRecord;
        bytes membershipPayload;
        SPMembershipFacts membership;
        SPGraph.Graph graph;
        bytes32 selectionId;
        SPSelection.Plan selection;
        bytes32 checkpointId;
        SPCheckpoint.Plan checkpoint;
        SPCheckpoint.Payload[] payloads;
        bytes[] metadataJSON;
        SPCheckpoint.Output[] outputRows;
        bytes outputPayload;
        bytes32 outputArtifact;
        bytes32 outputCoverage;
        bytes32 outputPlan;
        bytes32 outputRecord;
        SPOutputs.Manifest output;
        SPSnapshotTypes.Publication snapshotPublication;
        SPSnapshotTypes.Receipt snapshot;
        bytes snapshotPayload;
        bytes32 rootHash;
        SPRoot.Record root;
        SPPolicyRoot.Binding binding;
        SPRoot.Aggregate aggregate;
        bytes32 legacyFamily;
        bytes32 signedFamily;
        SPContent.Consent consent;
        bytes32 consentRecord;
        uint256 consentNonce;
        address actor;
        uint64 observedAt;
    }

    bool private spPrepared;
    bytes32 private spLegacyFamily;

    function _authorityPublishScopedPolicy(SPScopeType kind)
        internal
        returns (AuthorityScopedPublication memory p)
    {
        require(
            address(assemblyArtists) == assemblyAuthorityResolver.anchors().targets[3],
            "scoped original Router writes finish in Artist A"
        );
        _spPrepare();
        p.legacyFamily = spLegacyFamily;
        (p.scope, p.membershipRecord, p.membershipPayload) = _spScope(kind);
        p.membership = assemblyMembership.requireScopeMembership(p.scope);
        uint256 count = kind == SPScopeType.TOKEN ? 1 : 2;
        require(p.membership.tokenCount == count && p.membership.membershipHash != 0);
        require(
            p.membership.scopeSubject
                == SPSubjects.scopeSubject(block.chainid, address(assemblyCore), p.scope)
        );
        for (uint256 i; i < count; ++i) {
            require(assemblyMembership.scopeTokenAt(p.scope, i) == i + 1);
        }
        p.graph = _spChildren(p.scope, count);
        _spCheckpoint(p);
        _spOutput(p);
        _spSnapshot(p);
        _spRoot(p);
        require(assemblyRouter.collectionContentRootHead(1) == 0, "native root remains absent");
    }

    /// @dev One actual token/collection inventory and set of locks supports all three scopes.
    function _spPrepare() private {
        if (spPrepared) return;
        require(assemblyRouter.collectionContentRootHead(1) == 0, "STATIC has no native checkpoint");
        require(
            assemblyRouter.scopedContentRootAggregate(1).revision == 0, "start before scoped roots"
        );
        spLegacyFamily = keccak256(
            abi.encode(
                keccak256("6529STREAM_EMPTY_CONTENT_ROOT_STATE_V1"),
                block.chainid,
                address(assemblyRouter),
                address(assemblyCore),
                uint256(1)
            )
        );
        (bool known, bytes32 actualFamily) =
            assemblyRouter.artistContentFamilyState(1, keccak256("CONTENT_ROOT"));
        require(known && actualFamily == spLegacyFamily, "known canonical empty native family");
        _assemblySetupArchiveAdmissions();
        _spDefinitions();
        _spGrant(SPFamilies.SNAPSHOT);
        _spGrant(SPFamilies.IDENTITY);
        uint256[] memory ids = new uint256[](2);
        ids[0] = 1;
        ids[1] = 2;
        assemblyTokens.appendCollectionTokens(1, ids);
        bytes32 collectionPlan =
            assemblyCoordinators.beginInventory(SPScope(SPScopeType.COLLECTION, 1, 0, 0));
        assemblyCoordinators.appendInventory(collectionPlan, 2);
        require(assemblyCoordinators.requireCompleteInventory(collectionPlan).processedTokens == 2);
        assemblyCoordinatorInventoryPlan = collectionPlan;
        _assemblyLockContent();
        spPrepared = true;
    }

    function _spScope(SPScopeType kind)
        private
        returns (SPScope memory scope, bytes32 membershipRecord, bytes memory payload)
    {
        if (kind == SPScopeType.TOKEN) {
            scope = SPScope(kind, 1, 1, 0);
            require(
                assemblyMetadata.registerTokenSubject(1)
                    == SPSubjects.scopeSubject(block.chainid, address(assemblyCore), scope)
            );
            return (scope, bytes32(0), bytes(""));
        }
        require(kind == SPScopeType.RELEASE || kind == SPScopeType.SEASON, "closed scoped profiles");
        _spDefinition(
            "STREAM_SCOPE_MEMBERSHIP_V1",
            SPSchemas.DocumentKind.SCHEMA,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-v1.schema.json"))
        );
        _spDefinition(
            "STREAM_SCOPE_MEMBERSHIP_ABI_V1",
            SPSchemas.DocumentKind.CANONICALIZATION,
            bytes(assemblyVm.readFile("docs/schemas/finality/scope-membership-abi-v1.json"))
        );
        bytes32 recordType = keccak256("SCOPE_MEMBERSHIP");
        SPMetadata.RecordPolicy memory policy = assemblyMetadata.recordPolicy(recordType);
        if (!policy.admitted) {
            (bytes32 actionScope, bytes32 previous, bytes32 next) =
                assemblyMetadata.recordTypeTransition(recordType, SPFamilies.IDENTITY, uint16(384));
            _assemblyGovernanceCall(
                1,
                address(assemblyMetadata),
                abi.encodeCall(
                    assemblyMetadata.admitRecordType, (recordType, SPFamilies.IDENTITY, uint16(384))
                ),
                actionScope,
                previous,
                next
            );
        } else {
            require(policy.family == SPFamilies.IDENTITY && policy.authorizationMask == 384);
        }
        bytes memory tokenBytes = abi.encode(uint256(1), uint256(2));
        (bytes32 chunk, address pointer) = assemblyStore.publishChunk(tokenBytes);
        require(chunk == keccak256(tokenBytes) && pointer.code.length == tokenBytes.length + 1);
        bytes32[] memory parts = new bytes32[](1);
        parts[0] = chunk;
        payload = SPMembershipEncoding.encode(
            SPMembershipManifest(
                1,
                block.chainid,
                address(assemblyCore),
                1,
                uint8(kind),
                2,
                keccak256(tokenBytes),
                parts
            )
        );
        SPRecords.CollectionRecord memory record;
        record.recordType = recordType;
        record.subjectId = SPSubjects.scopeSubject(
            block.chainid, address(assemblyCore), SPScope(SPScopeType.COLLECTION, 1, 0, 0)
        );
        record.schemaId = keccak256("STREAM_SCOPE_MEMBERSHIP_V1");
        record.contentHash = SPRecords.HashRef(
            1, abi.encode(keccak256(payload)), keccak256("STREAM_SCOPE_MEMBERSHIP_ABI_V1")
        );
        record.uri = "https://fixtures.example.invalid/current-authority/static-scope-membership";
        record.effectiveAt = uint64(block.timestamp);
        membershipRecord = assemblyMetadata.recordCollectionRecordWithPayload(1, record, payload);
        scope = assemblyMembership.beginScopeMembership(membershipRecord);
        assemblyMembership.continueScopeMembership(scope, 1);
        SPMembershipFacts memory facts = assemblyMembership.requireScopeMembership(scope);
        require(scope.scopeType == kind && scope.collectionId == 1 && scope.tokenId == 0);
        require(
            scope.scopeId
                == SPMembershipEncoding.scopeId(
                    block.chainid, address(assemblyCore), 1, uint8(kind), membershipRecord
                )
        );
        require(
            facts.sourceRecordHash == membershipRecord
                && facts.scopeManifestHash == keccak256(payload)
        );
        require(facts.tokenCount == 2 && facts.tokenListHash == keccak256(tokenBytes));
        require(
            assemblyMetadata.registerScopeSubject(membershipRecord) == facts.scopeSubject,
            "real Metadata derives subject from the published membership record"
        );
    }

    function _spChildren(SPScope memory scope, uint256 count)
        private
        returns (SPGraph.Graph memory graph)
    {
        bytes32 plan = assemblyCoordinators.beginInventory(scope);
        assemblyCoordinators.appendInventory(plan, count);
        SPCoordinators.Progress memory progress =
            assemblyCoordinators.requireCompleteInventory(plan);
        require(
            progress.complete && progress.processedTokens == count && progress.tokenCount == count
        );
        require(progress.coordinatorCount == 1 && progress.commitment != 0);
        SPCoordinators.Coordinator memory original =
            assemblyCoordinators.requireCoordinator(plan, 0);
        require(
            original.coordinator == address(assemblyEntropy)
                && original.indexedCodeHash == address(assemblyEntropy).codehash
        );
        SPSourceFactory sourceFactory = SPSourceFactory(sourceScopedPolicyEntropyFactory);
        require(sourceFactory.currentInventoryPlan(scope) == plan);
        address sourceSet = sourceFactory.prepareSourceSet(scope);
        (address actual, bytes32 runtime) = sourceFactory.sourceSetForPlan(plan);
        require(actual == sourceSet && runtime == sourceSet.codehash && sourceSet.code.length != 0);
        SPSourceSet(sourceSet).requireCurrentSourceSet();
        require(
            keccak256(abi.encode(SPSourceSet(sourceSet).sourceScope()))
                == keccak256(abi.encode(scope))
        );
        require(
            SPSourceSet(sourceSet).sourceCount() == 1
                && SPSourceSet(sourceSet).sourcePolicyAt(0).frozen
        );
        SPFactory factory = SPFactory(scopedGraphFactory);
        graph = factory.prepareGraph(scope, 7);
        require(graph.preparedChildren == 7 && graph.inventoryPlan == plan);
        require(graph.sourceSet == sourceSet && graph.sourceSetCodeHash == runtime);
        require(
            keccak256(abi.encode(graph))
                == keccak256(abi.encode(factory.requireCurrentGraph(scope)))
        );
        for (uint256 i; i < 7; ++i) {
            require(
                graph.children[i].code.length != 0
                    && graph.children[i].codehash == graph.codeHashes[i]
            );
            for (uint256 j; j < i; ++j) {
                require(graph.children[i] != graph.children[j]);
            }
        }
    }

    function _spCheckpoint(AuthorityScopedPublication memory p) private {
        SPSelection selections = SPSelection(sourceStaticSelection);
        p.selectionId = selections.begin(p.scope);
        selections.append(p.selectionId, p.membership.tokenCount);
        p.selection = selections.requireCurrentCheckpoint(p.selectionId);
        require(p.selection.nextIndex == p.membership.tokenCount && p.selection.selectionRoot != 0);
        SPCheckpoint checkpoint = SPCheckpoint(p.graph.children[1]);
        require(checkpoint.selectionCheckpoint() == sourceStaticSelection);
        p.checkpointId = checkpoint.begin(
            p.selectionId, keccak256(abi.encode("actual original scoped STATIC", p.scope))
        );
        p.payloads = new SPCheckpoint.Payload[](p.membership.tokenCount);
        p.metadataJSON = new bytes[](p.membership.tokenCount);
        for (uint256 i; i < p.payloads.length; ++i) {
            uint256 tokenId = assemblyMembership.scopeTokenAt(p.scope, i);
            // These are genuine current endpoint bytes; the inherited prefix independently
            // checks its citation transformation. This helper adds no renderer conformance claim.
            _assemblyStaticRequireServing(tokenId);
            p.payloads[i] =
                SPCheckpoint.Payload(tokenId, bytes(""), bytes(assemblyRouter.tokenHTML(tokenId)));
            p.metadataJSON[i] = bytes(assemblyRouter.tokenJSON(tokenId));
        }
        checkpoint.append(p.checkpointId, p.payloads);
        p.checkpoint = checkpoint.requireCurrentCheckpoint(p.checkpointId);
        require(
            p.checkpoint.nextIndex == p.membership.tokenCount && p.checkpoint.contentRoot != 0
                && p.checkpoint.outputRoot != 0
        );
        p.outputRows = new SPCheckpoint.Output[](p.membership.tokenCount);
        for (uint256 i; i < p.outputRows.length; ++i) {
            SPCheckpoint.Output memory row = checkpoint.outputAt(p.checkpointId, i);
            require(
                row.leaf.tokenId == p.payloads[i].tokenId
                    && row.leaf.metadataHash == keccak256(p.metadataJSON[i])
            );
            require(
                row.htmlHash == keccak256(p.payloads[i].animation)
                    && row.leaf.animationHash == row.htmlHash
            );
            require(
                row.entropy.coordinator == address(assemblyEntropy) && row.entropy.status == 5
                    && row.entropy.mode == 2
            );
            require(
                row.entropy.finalized && !row.entropy.terminal && row.entropy.seed != 0
                    && row.terminalAdmissionHash == 0
            );
            p.outputRows[i] = row;
        }
    }

    function _spOutput(AuthorityScopedPublication memory p) private {
        SPCheckpoint.Plan memory c = p.checkpoint;
        p.outputPayload = abi.encode(
            SPOutputDefinitions.SCHEMA,
            block.chainid,
            address(assemblyCore),
            p.graph.children[1],
            p.checkpointId,
            keccak256(abi.encode(c)),
            p.graph.sourceSet,
            c.inventoryHash,
            c.policyChainHash,
            c.scope,
            c.contentRoot,
            c.outputRoot,
            c.tokenCount,
            p.outputRows
        );
        require(p.outputPayload.length == 576 + 640 * p.membership.tokenCount);
        (p.outputArtifact, p.outputCoverage) =
            _ocCover(p.outputPayload, SPOutputDefinitions.SCHEMA, SPOutputDefinitions.CANON);
        SPOutputs outputs = SPOutputs(p.graph.children[2]);
        p.outputPlan = outputs.beginManifest(
            p.checkpointId, p.outputArtifact, p.outputCoverage, assemblyArtistId
        );
        p.outputRecord = outputs.verifyNextOutputs(p.outputPlan, p.membership.tokenCount);
        p.output = outputs.requireCurrentManifest(p.outputRecord, assemblyArtistId);
        require(p.outputRecord != 0 && p.output.manifestHash == keccak256(p.outputPayload));
        require(
            p.output.checkpointStateHash == keccak256(abi.encode(c))
                && p.output.tokenCount == c.tokenCount
        );
    }

    function _spSnapshot(AuthorityScopedPublication memory p) private {
        SPSnapshot snapshot = SPSnapshot(p.graph.children[3]);
        require(snapshot.snapshotCount(p.scope) == 0, "new actual scoped snapshot lineage");
        p.snapshotPublication = SPSnapshotTypes.Publication(
            p.scope,
            keccak256(abi.encode("actual original scoped STATIC snapshot", p.scope)),
            bytes32(0),
            0,
            p.outputRecord,
            p.graph.inventoryPlan,
            bytes32(0),
            "https://fixtures.example.invalid/current-authority/scoped-policy-snapshot",
            uint64(block.timestamp),
            keccak256("complete actual original scope, STATIC output and frozen policy")
        );
        (p.snapshotPublication.expectedSourceHash, p.snapshotPayload) =
            snapshot.previewSnapshot(p.snapshotPublication, address(this));
        _assemblyUpload(p.snapshotPayload);
        bytes32 recordHash = snapshot.publishSnapshot(p.snapshotPublication);
        p.snapshot = snapshot.requireCurrent(p.scope, recordHash, 1);
        require(p.snapshot.recordHash == recordHash && p.snapshot.publisher == address(this));
        require(
            p.snapshot.manifestHash == keccak256(p.snapshotPayload)
                && p.snapshot.manifestBytes == p.snapshotPayload.length
        );
        require(keccak256(snapshot.snapshotPayload(recordHash)) == keccak256(p.snapshotPayload));
        require(
            p.snapshot.sourceHash == p.snapshotPublication.expectedSourceHash
                && p.snapshot.scopeSubject == p.membership.scopeSubject
        );
    }

    function _spRoot(AuthorityScopedPublication memory p) private {
        require(assemblyRouter.scopedContentRootHead(p.scope) == 0, "first scoped root");
        SPRoot.Publication memory input = SPRoot.Publication(
            p.scope,
            bytes32(0),
            p.snapshot.recordHash,
            p.snapshot.revision,
            "https://fixtures.example.invalid/current-authority/scoped-policy-root"
        );
        p.actor = address(this);
        p.signedFamily = assemblyRouter.previewScopedPolicyContentRootPublication(input, p.actor);
        p.consent = SPContent.Consent(
            1, address(assemblyRouter), keccak256("CONTENT_ROOT"), p.signedFamily
        );
        SPArtist.Authorization memory authorization = _assemblyAuthorization(false);
        p.consentNonce = authorization.nonce;
        authorization.signature = _assemblyArtistProof(
            assemblyArtists.contentConsentDigest(p.consent, authorization), authorization.nonce
        );
        p.observedAt = uint64(block.timestamp);
        p.consentRecord = assemblyArtists.recordContentConsent(p.consent, authorization);
        _authorityContentConsent(p.consent, p.consentRecord);
        p.rootHash = assemblyRouter.publishScopedPolicyContentRootPublication(input);
        p.root = assemblyRouter.scopedContentRootRecord(p.rootHash);
        p.binding = assemblyRouter.scopedPolicyContentRootBinding(p.rootHash);
        p.aggregate = assemblyRouter.scopedContentRootAggregate(1);
        require(
            p.rootHash != 0 && p.root.artistConsent == p.consentRecord
                && p.root.artistId == assemblyArtistId
        );
        require(
            p.root.publisher == p.actor && p.root.publishedAt == p.observedAt
                && p.root.snapshotHost == p.graph.children[3]
        );
        require(
            p.binding.profileId == SPRootDefinitions.PROFILE
                && p.binding.checkpointHash == p.checkpointId
        );
        require(
            p.binding.outputManifest == p.graph.children[2]
                && p.binding.outputRoot == p.checkpoint.outputRoot
        );
        require(
            assemblyRouter.scopedContentRootHead(p.scope) == p.rootHash
                && assemblyRouter.consumedArtistContentConsent(p.consentRecord)
        );
        require(
            p.signedFamily
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1"),
                        block.chainid,
                        address(assemblyRouter),
                        address(assemblyCore),
                        uint256(1),
                        p.legacyFamily,
                        p.aggregate
                    )
                ),
            "exact original op17 family with per-root resulting aggregate"
        );
        require(
            p.rootHash
                == keccak256(
                    abi.encode(
                        keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"),
                        block.chainid,
                        address(assemblyRouter),
                        address(assemblyCore),
                        p.root,
                        p.binding,
                        p.aggregate
                    )
                ),
            "exact original scoped V2 record"
        );
        (bool known, bytes32 actualFamily) =
            assemblyRouter.artistContentFamilyState(1, keccak256("CONTENT_ROOT"));
        require(known && actualFamily == p.signedFamily, "known exact resulting scoped family");
    }

    function _spGrant(bytes32 family) private {
        (bool enabled, uint64 revision) = assemblyMetadata.familyWriter(1, family, 7, address(this));
        if (!enabled) _assemblyGrantFamily(family, 7, address(this));
        else require(revision != 0);
    }

    function _spDefinitions() private {
        _spDefinition(
            "RAW_BYTES",
            SPSchemas.DocumentKind.CANONICALIZATION,
            bytes(assemblySchemas.RAW_BYTES_DEFINITION())
        );
        string[5] memory names = [
            "STREAM_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_ABI_SCOPED_POLICY_OUTPUT_MANIFEST_V2",
            "STREAM_SCOPED_POLICY_TOKEN_CONTENT_LEAF_V2",
            "STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2",
            "STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2"
        ];
        for (uint256 i; i < names.length; ++i) {
            _spDefinition(
                names[i],
                (i == 1 || i == 4)
                    ? SPSchemas.DocumentKind.CANONICALIZATION
                    : SPSchemas.DocumentKind.SCHEMA,
                SPRootDefinitions.document(keccak256(bytes(names[i])))
            );
        }
        _spDefinition(
            "STREAM_SCOPED_POLICY_SNAPSHOT_ABI_V2",
            SPSchemas.DocumentKind.SCHEMA,
            SPSnapshotDefinitions.document(SPSnapshotDefinitions.SCHEMA_ID)
        );
        _spDefinition(
            "STREAM_SCOPED_POLICY_SNAPSHOT_PROFILE_V2",
            SPSchemas.DocumentKind.CATALOG,
            SPSnapshotDefinitions.document(SPSnapshotDefinitions.PROFILE_ID)
        );
        _spDefinition(
            "STREAM_ABI_SCOPED_POLICY_SNAPSHOT_V2",
            SPSchemas.DocumentKind.CANONICALIZATION,
            SPSnapshotDefinitions.document(SPSnapshotDefinitions.CANON_ID)
        );
    }

    function _spDefinition(string memory name, SPSchemas.DocumentKind kind, bytes memory raw)
        private
    {
        bytes32 id = keccak256(bytes(name));
        SPSchemas.DocumentView memory saved = assemblySchemas.document(id);
        if (!saved.exists) {
            _assemblyRegisterDocument(name, kind, raw, assemblySchemas.RAW_BYTES());
        } else {
            require(
                saved.status == SPSchemas.DocumentStatus.ACTIVE && saved.specification.kind == kind
                    && saved.specification.contentHash == keccak256(raw)
                    && saved.specification.totalBytes == raw.length
                    && saved.specification.canonicalizationId == assemblySchemas.RAW_BYTES(),
                "same active exact definition"
            );
        }
    }
}
