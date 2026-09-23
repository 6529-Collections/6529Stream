// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamPolicyOutputSchemasV2 as Output } from "./StreamPolicyOutputSchemasV2.sol";

/// @notice Exact independent V2 interpretation; original V1 schema documents are unchanged.
library StreamPolicyContentRootSchemasV2 {
    bytes32 internal constant ROOT_SCHEMA = keccak256("STREAM_POLICY_CONTENT_ROOT_RECORD_V2");
    bytes32 internal constant ROOT_CANON = keccak256("STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2");

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == ROOT_SCHEMA) {
            return bytes(
                '{"name":"STREAM_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"record":"Original IStreamContentRootPublication.Record tuple plus immutable IStreamPolicyContentRootPublicationV2.Binding","bindingFields":["bytes32 profileId","address outputManifest","bytes32 outputManifestCodeHash","address checkpoint","bytes32 checkpointCodeHash","bytes32 checkpointHash","bytes32 checkpointStateHash","address entropySourceSet","bytes32 entropySourceSetCodeHash","bytes32 inventoryHash","bytes32 policyChainHash","bytes32 outputRoot","bytes32 outputSchemaHash","bytes32 outputCanonicalizationHash","bytes32 leafSchemaHash","bytes32 rootSchemaHash","bytes32 rootCanonicalizationHash"],"profile":"6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2","scope":"COLLECTION only; complete current frozen ONCHAIN output and original-source entropy policy inventory","authority":"Original selected Metadata SNAPSHOT class7 collection or class8 global grant; exact original Artist operation17 CONTENT_ROOT approval and original one-use consumption,evolution,freeze rules","lineage":"Original Router collectionContentRootHead and contentRootRecord append-only history; expected predecessor must equal actual head","schemas":"Output manifest,output canonicalization,leaf,root and root canonicalization definitions must be exact ACTIVE RAW_BYTES documents","policy":"DISABLED or ASYNC NOT_REQUIRED are truthful terminal states with no finalized seed; independently admitted terminal STATIC profile required; finalized rows retain original status5 seed","root":"Original six-field content leaf/tree; distinct V2 leaf interpretation","availability":"Manifest preserves every output hash and source commitment; full artifact bytes and snapshot/reference publication remain independent requirements"}'
            );
        }
        if (id == ROOT_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"encoding":"abi.encode(IStreamContentRootPublication.Record,IStreamPolicyContentRootPublicationV2.Binding)","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_POLICY_CONTENT_ROOT_STATE_V2),chainId,router,recordWithStateHashConsentAndPublishedAtZero,binding))","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_POLICY_CONTENT_ROOT_RECORD_V2),chainId,router,completedRecord,binding))","routeHash":"keccak256(abi.encode(keccak256(6529STREAM_POLICY_CONTENT_ROOT_ROUTE_V2),chainId,Context(core,artist),orderedTenTargets,orderedTenRuntimeHashes))","targets":"core,artist,router,selectedFinality,selectedCombinedProvider,selectedMetadata,schemaRegistry,outputManifest,checkpoint,artifactCoverage","strings":"Original exact validated UTF-8 URI bytes; no normalization","approval":"Original scoped aggregate wraps the candidate state for original CONTENT_ROOT family consent","history":"Recorded consent and timestamp do not change the approved state; no reinterpretation of V1 hashes","canonical":"Compiler ABI only; alternate offsets and trailing bytes forbidden"}'
            );
        }
        return Output.document(id);
    }

    function definitionHash(bytes32 id) public pure returns (bytes32) {
        return keccak256(document(id));
    }
}
