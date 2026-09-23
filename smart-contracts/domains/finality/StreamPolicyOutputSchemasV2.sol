// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Separate interpretation of full current outputs with complete frozen entropy policy.
/// Original finalized-only V1 schema bytes and IDs remain authoritative for their original profile.
library StreamPolicyOutputSchemasV2 {
    bytes32 internal constant SCHEMA = keccak256("STREAM_POLICY_OUTPUT_MANIFEST_V2");
    bytes32 internal constant CANON = keccak256("STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2");
    bytes32 internal constant LEAF_SCHEMA = keccak256("STREAM_POLICY_TOKEN_CONTENT_LEAF_V2");

    function document(bytes32 id) internal pure returns (bytes memory) {
        if (id == SCHEMA) {
            return bytes(
                '{"name":"STREAM_POLICY_OUTPUT_MANIFEST_V2","version":2,"profile":"6529STREAM_POLICY_CURRENT_FULL_CONTENT_V2","format":"Solidity ABI","scope":"Exact complete COLLECTION checkpoint; VIEW and non-ONCHAIN modes refused","rows":"Every IStreamPolicyContentCheckpointV2.Output in exact authoritative checkpoint order","fields":["StreamTokenContentLeaf(uint256 tokenId,bytes32 metadataHash,bytes32 imageHash,bytes32 animationHash,bytes32 contentHash,bytes32 tokenDataHash)","bytes32 selectionRowHash","bytes32 sourceFactsHash","bytes32 htmlHash","TokenReadiness(address coordinator,bytes32 coordinatorCodeHash,bytes32 policyHash,uint8 status,uint8 mode,uint8 securityClass,uint8 renderRequirement,bool terminal,bool finalized,bytes32 seed)","bytes32 terminalAdmissionHash"],"entropy":"Original coordinatorAtMint and complete frozen policy-set hash; terminal DISABLED and ASYNC NOT_REQUIRED require independently admitted terminal STATIC profile with zero seed and finalized=false; finalized rows require actual status5 and exact original seed","commitments":"Original CMC six-field content tree plus distinct V2 ordered output chain and full policy/inventory commitments","preservation":"Output hashes and source commitments only; complete JSON,HTML,image and tokenData bytes require separate preserved artifacts","authority":"Current archive coverage and checkpoint computation are evidence only; no Artist,publication or finality authority","current":"Every read revalidates complete source policy set and renders all prior output rows; immutable history remains readable"}'
            );
        }
        if (id == CANON) {
            return bytes(
                '{"name":"STREAM_ABI_POLICY_OUTPUT_MANIFEST_V2","version":2,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,bytes32 checkpointStateHash,address entropySourceSet,bytes32 inventoryHash,bytes32 policyChainHash,StreamFinalityScope scope,bytes32 contentRoot,bytes32 outputRoot,uint64 tokenCount,IStreamPolicyContentCheckpointV2.Output[] rows)","schemaId":"keccak256(STREAM_POLICY_OUTPUT_MANIFEST_V2)","checkpointStateHash":"keccak256(abi.encode(complete V2 checkpoint Plan))","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","headBytes":544,"arrayOffset":544,"headerBytesIncludingArrayCount":576,"rowBytes":640,"length":"576+640*tokenCount","arrayCount":"Exactly positive tokenCount","words":"32-byte big-endian; addresses and narrow unsigned integers zero-extended; booleans exactly0or1","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","rowOrder":"Exact original checkpoint order","hash":"Keccak-256 of complete exact manifest bytes; not JCS"}'
            );
        }
        if (id == LEAF_SCHEMA) {
            return bytes(
                '{"name":"STREAM_POLICY_TOKEN_CONTENT_LEAF_V2","version":2,"fields":["uint256 tokenId","bytes32 metadataHash","bytes32 imageHash","bytes32 animationHash","bytes32 contentHash","bytes32 tokenDataHash"],"encoding":"Original CMC ordered six-field content leaf/tree; no preimage change","metadata":"Exact current full Router tokenJSON bytes, not historical compact JSON","animation":"Exact current tokenHTML bytes; nonempty","image":"Exact decoded admitted inline bytes; zero only if absent","content":"No separate content asset in this finite profile; zero","entropy":"Truthful terminal or finalized original-source state authenticated by distinct V2 output manifest; terminal is never a fabricated finalized seed","authority":"Leaf hash alone is not root adoption,Artist consent,snapshot or finality acceptance"}'
            );
        }
        revert("unknown policy output document");
    }
}
