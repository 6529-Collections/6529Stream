// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamPreservationPolicyOutputSchemasV2 as Output
} from "./StreamPreservationPolicyOutputSchemasV2.sol";

/// @notice Closed two-token-producer family under ADR0054; all V1 document bytes remain unchanged.
library StreamPreservationPolicyContentRootSchemasV2 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_PRESERVATION_POLICY_CONTENT_V2");
    bytes32 internal constant ROOT_SCHEMA =
        keccak256("STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2");
    bytes32 internal constant ROOT_CANON =
        keccak256("STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2");

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == ROOT_SCHEMA) {
            return bytes(
                '{"name":"STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"record":"Original IStreamContentRootPublication.Record tuple plus immutable IStreamPreservationPolicyContentRootPublicationV1.Binding","bindingFields":["bytes32 profileId","address outputManifest","bytes32 outputManifestCodeHash","address checkpoint","bytes32 checkpointCodeHash","bytes32 checkpointHash","bytes32 checkpointStateHash","address entropySourceSet","bytes32 entropySourceSetCodeHash","bytes32 inventoryHash","bytes32 policyChainHash","bytes32 outputRoot","bytes32 outputSchemaHash","bytes32 outputCanonicalizationHash","bytes32 leafSchemaHash","bytes32 rootSchemaHash","bytes32 rootCanonicalizationHash","address metadataRouter","bytes32 preservationOutputProfile"],"profile":"6529STREAM_PRESERVATION_POLICY_CONTENT_V2","scope":"Exact complete COLLECTION; scoped and VIEW records refused","authority":"Original selected Metadata SNAPSHOT class7 collection or class8 global grant; exact original Artist operation17 CONTENT_ROOT approval and original one-use consumption,evolution,freeze rules","lineage":"Original Router collectionContentRootHead and contentRootRecord append-only history; exact predecessor required","schemas":"Exact ACTIVE RAW_BYTES preservation output, canonicalization, leaf and root documents","policy":"DISABLED or ASYNC NOT_REQUIRED are truthful terminal states with no finalized seed; independently admitted terminal STATIC profile required; finalized rows retain original status5 seed","root":"Original ordered six-field content leaf/tree with the distinct preservation leaf interpretation","availability":"Manifest preserves every output hash and source commitment; full artifact bytes and snapshot/reference publication remain independent requirements","checkpointProfile":"6529STREAM_PRESERVATION_POLICY_CONTENT_CHECKPOINT_V2","preservationOutputProfile":"6529STREAM_TOKEN_PRESERVATION_FAMILY_V2","bindingWordCount":19,"source":"Current complete covered preservation output manifest and checkpoint, selected immutable preservation provider binding or publication graph and full original entropy policy inventory","projection":"Canonical public preservation JSON and HTML omit only sanction lookup and its derived displayed state, record hash and authority class. Artwork, executable code, media, token data, citation, C2PA, original entropy and all other Artist facts remain committed. Live presentation and adverse provenance stay separately readable.","producerBinding":"Every output row retains its exact independently admitted producer marker: 6529STREAM_PRESERVATION_RENDER_V1 or 6529STREAM_CURRENT_ARTIST_PRESERVATION_RENDER_V1 only; VIEW and unknown markers are refused. The family marker is not a row producer marker. Each row binds producer, runtime, actual preservation profile, Core, metadataRouter, selected live renderer and runtime, attribution companion and runtime, and seven-word governed admission. Mixed selected renderers are permitted per row; no global producer substitutes for the complete outputRoot.","publicationOrder":"Collection root publication precedes the preservation snapshot that binds that root","legacyCompatibility":"Existing live and locked profiles, schema bytes, signing domains, hashes and consumed-content books keep their original meaning. Original operation17 one-use CONTENT_ROOT authority, evolution and freeze rules apply.","events":"Common original root publication event schemaVersion3 identifies the preservation interpretation; the distinct preservation binding event uses schemaVersion2"}'
            );
        }
        if (id == ROOT_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"encoding":"abi.encode(IStreamContentRootPublication.Record,IStreamPreservationPolicyContentRootPublicationV1.Binding)","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_STATE_V2),chainId,router,recordWithStateHashConsentAndPublishedAtZero,binding))","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_RECORD_V2),chainId,router,completedRecord,binding))","routeHash":"keccak256(abi.encode(keccak256(6529STREAM_PRESERVATION_POLICY_CONTENT_ROOT_ROUTE_V2),chainId,Context(core,artist),orderedTenTargets,orderedTenRuntimeHashes))","targets":"core,artist,router,selectedFinality,selectedCombinedProvider,selectedMetadata,schemaRegistry,outputManifest,checkpoint,artifactCoverage","strings":"Original exact validated UTF-8 URI bytes; no normalization","approval":"Original scoped aggregate wraps the candidate state for original CONTENT_ROOT family consent","history":"Existing profile bytes and domains remain unchanged. Preservation companion bindings and snapshots are never decoded as legacy profile bindings or snapshots; the original canonical Record history getter remains readable across all profiles","canonical":"Solidity ABI only; alternate offsets, trailing bytes and noncanonical words forbidden","bindingWords":19,"preservation":"Binding.metadataRouter is the actual original Router; preservationOutputProfile is the closed 6529STREAM_TOKEN_PRESERVATION_FAMILY_V2 value. Complete per-row producer and admission bindings are committed by outputRoot."}'
            );
        }
        return Output.document(id);
    }

    function definitionHash(bytes32 id) public pure returns (bytes32) {
        return keccak256(document(id));
    }
}
