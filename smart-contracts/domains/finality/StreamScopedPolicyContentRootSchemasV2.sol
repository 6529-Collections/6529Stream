// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamScopedPolicyOutputSchemasV2 as Output
} from "./StreamScopedPolicyOutputSchemasV2.sol";

/// @notice Scoped full-policy interpretation; original COLLECTION and scoped V1 bytes remain exact.
library StreamScopedPolicyContentRootSchemasV2 {
    bytes32 internal constant PROFILE = keccak256("6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2");
    bytes32 internal constant ROOT_SCHEMA =
        keccak256("STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2");
    bytes32 internal constant ROOT_CANON =
        keccak256("STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2");

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == ROOT_SCHEMA) {
            return bytes(
                '{"name":"STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"profile":"6529STREAM_SCOPED_POLICY_CONTENT_ROOT_V2","record":"IStreamScopedContentRootPublication.Record plus IStreamScopedPolicyContentRootPublicationV2.Binding and historical Aggregate","scope":"Exact TOKEN,RELEASE or SEASON; COLLECTION and VIEW refused","source":"Current root-free scoped-policy V2 snapshot,complete authoritative membership,actual source factory and plan,runtime-pinned full original frozen policies,selection,checkpoint and covered output manifest","bindingFields":["bytes32 profileId","address outputManifest","bytes32 outputManifestCodeHash","address checkpoint","bytes32 checkpointCodeHash","bytes32 checkpointHash","bytes32 checkpointStateHash","address entropySourceSet","bytes32 entropySourceSetCodeHash","bytes32 inventoryHash","bytes32 policyChainHash","bytes32 outputRoot","bytes32 outputSchemaHash","bytes32 outputCanonicalizationHash","bytes32 leafSchemaHash","bytes32 rootSchemaHash","bytes32 rootCanonicalizationHash","address sourceFactory","bytes32 sourceFactoryCodeHash","bytes32 factoryDependenciesHash","bytes32 snapshotSchemaHash","bytes32 snapshotProfileHash","bytes32 snapshotCanonicalizationHash"],"authority":"Original Metadata SNAPSHOT class7 collection or class8 global grant,exact Artist operation17 CONTENT_ROOT consent and original replay/evolution state","lineage":"One original scoped head and collection aggregate across V1 and V2; exact predecessor required","entropy":"Terminal DISABLED or ASYNC NOT_REQUIRED remains zero seed and finalized=false; finalized rows retain actual original status5 and seed","schemas":"Exact ACTIVE RAW_BYTES output,leaf,root and snapshot definitions","retention":"Schema2 root event retains historical aggregate; companion event retains binding; current aggregate cannot authenticate historical consent"}'
            );
        }
        if (id == ROOT_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2","version":2,"encoding":"abi.encode(IStreamScopedContentRootPublication.Record,IStreamScopedPolicyContentRootPublicationV2.Binding,IStreamScopedContentRootPublication.Aggregate)","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_STATE_V2),chainId,router,core,recordWithStateHashConsentAndPublishedAtZero,binding))","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_RECORD_V2),chainId,router,core,completedRecord,binding,historicalAggregate))","signedFamily":"Original 6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1 wraps original legacy family with historical aggregate; individual stateHash is not signed family","aggregate":"Original 6529STREAM_SCOPED_CONTENT_ROOT_APPEND_V1 transition preimage unchanged","routeHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_POLICY_CONTENT_ROOT_ROUTE_V2),chainId,orderedSixTargets,orderedSixRuntimeHashes,metadata,metadataRuntimeHash,scope))","targets":"core,artist,router,selectedFinality,selectedProvider,scopeSelectedSnapshot","strings":"Exact validated UTF-8 URI bytes; no normalization","canonical":"Solidity ABI only; alternate offsets,trailing bytes and noncanonical words forbidden","history":"V1 record and snapshot bytes retain their original interpretation; V2 never enters V1 snapshot decoders"}'
            );
        }
        return Output.document(id);
    }

    function definitionHash(bytes32 id) public pure returns (bytes32) {
        return keccak256(document(id));
    }
}
