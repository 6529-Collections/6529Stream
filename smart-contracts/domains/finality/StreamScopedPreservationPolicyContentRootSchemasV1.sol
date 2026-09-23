// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputSchemasV1 as Output
} from "./StreamPreservationPolicyOutputSchemasV1.sol";

/// @notice Closed ADR0054 preservation interpretation; every legacy schema document remains unchanged.
library StreamScopedPreservationPolicyContentRootSchemasV1 {
    bytes32 internal constant PROFILE =
        keccak256("6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1");
    bytes32 internal constant ROOT_SCHEMA =
        keccak256("STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1");
    bytes32 internal constant ROOT_CANON =
        keccak256("STREAM_ABI_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1");

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == ROOT_SCHEMA) {
            return bytes(
                '{"name":"STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1","version":1,"profile":"6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_V1","record":"Original IStreamScopedContentRootPublication.Record tuple plus immutable IStreamScopedPreservationPolicyContentRootPublicationV1.Binding and historical Aggregate","scope":"Exact TOKEN, RELEASE or SEASON; COLLECTION and VIEW refused","source":"Current authenticated preservation snapshot and complete membership, original entropy policy inventory, selected actual source factory, current checkpoint and covered preservation output manifest","bindingFields":["bytes32 profileId","address outputManifest","bytes32 outputManifestCodeHash","address checkpoint","bytes32 checkpointCodeHash","bytes32 checkpointHash","bytes32 checkpointStateHash","address entropySourceSet","bytes32 entropySourceSetCodeHash","bytes32 inventoryHash","bytes32 policyChainHash","bytes32 outputRoot","bytes32 outputSchemaHash","bytes32 outputCanonicalizationHash","bytes32 leafSchemaHash","bytes32 rootSchemaHash","bytes32 rootCanonicalizationHash","address sourceFactory","bytes32 sourceFactoryCodeHash","bytes32 factoryDependenciesHash","bytes32 snapshotSchemaHash","bytes32 snapshotProfileHash","bytes32 snapshotCanonicalizationHash","address metadataRouter","bytes32 preservationOutputProfile"],"authority":"Original Metadata SNAPSHOT class7 collection or class8 global grant,exact Artist operation17 CONTENT_ROOT consent and original replay/evolution state","lineage":"One original scoped head and collection aggregate across all profiles; exact predecessor required","entropy":"Terminal DISABLED or ASYNC NOT_REQUIRED remains zero seed and finalized=false; finalized rows retain actual original status5 and seed","schemas":"Exact ACTIVE RAW_BYTES preservation output, canonicalization, leaf and root documents; scoped snapshot definitions independently authenticated","retention":"Common schemaVersion3 root event retains the historical aggregate; the preservation binding event retains the exact new binding. A current aggregate cannot authenticate historical consent.","checkpointProfile":"6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_V1","preservationOutputProfile":"6529STREAM_PRESERVATION_RENDER_V1","bindingWordCount":25,"projection":"Canonical public preservation JSON and HTML omit only sanction lookup and its derived displayed state, record hash and authority class. Artwork, executable code, media, token data, citation, C2PA, original entropy and all other Artist facts remain committed. Live presentation and adverse provenance stay separately readable.","producerBinding":"Every output row binds its exact admitted producer, runtime, fixed preservation profile, Core, metadataRouter, selected live renderer and runtime, attribution companion and runtime, and seven-word governed admission. Mixed selected renderers are permitted per row; no global producer substitutes for the complete outputRoot.","publicationOrder":"Current root-free preservation snapshot precedes root publication","legacyCompatibility":"Existing live and locked profiles, schema bytes, signing domains, hashes and consumed-content books keep their original meaning. Original operation17 one-use CONTENT_ROOT authority, evolution and freeze rules apply.","events":"Common original root publication event schemaVersion3 identifies the preservation interpretation; the distinct preservation binding event uses schemaVersion1"}'
            );
        }
        if (id == ROOT_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1","version":1,"encoding":"abi.encode(IStreamScopedContentRootPublication.Record,IStreamScopedPreservationPolicyContentRootPublicationV1.Binding,IStreamScopedContentRootPublication.Aggregate)","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V1),chainId,router,core,recordWithStateHashConsentAndPublishedAtZero,binding))","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V1),chainId,router,core,completedRecord,binding,historicalAggregate))","signedFamily":"Original 6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1 wraps original legacy family with historical aggregate; individual stateHash is not signed family","aggregate":"Original 6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1 transition preimage unchanged","routeHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V1),chainId,orderedSixTargets,orderedSixRuntimeHashes,metadata,metadataRuntimeHash,scope))","targets":"core,artist,router,selectedFinality,selectedProvider,scopeSelectedSnapshot","strings":"Exact validated UTF-8 URI bytes; no normalization","canonical":"Solidity ABI only; alternate offsets, trailing bytes and noncanonical words forbidden","history":"Existing profile bytes and domains remain unchanged. Preservation companion bindings and snapshots are never decoded as legacy profile bindings or snapshots; the original canonical Record history getter remains readable across all profiles","bindingWords":25,"preservation":"Binding.metadataRouter is the actual original Router; preservationOutputProfile is the closed 6529STREAM_PRESERVATION_RENDER_V1 value. Complete per-row producer and admission bindings are committed by outputRoot."}'
            );
        }
        return Output.document(id);
    }

    function definitionHash(bytes32 id) public pure returns (bytes32) {
        return keccak256(document(id));
    }
}
