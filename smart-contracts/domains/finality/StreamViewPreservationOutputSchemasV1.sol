// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library StreamViewPreservationOutputSchemasV1 {
    bytes32 internal constant PART = keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1");
    bytes32 internal constant PART_CANON = keccak256("STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1");
    bytes32 internal constant INDEX = keccak256("STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1");
    bytes32 internal constant INDEX_CANON =
        keccak256("STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1");

    bytes32 internal constant LEAF = keccak256("STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1");

    function document(bytes32 id) internal pure returns (bytes memory) {
        if (id == PART) {
            return bytes(
                '{"name":"STREAM_VIEW_PRESERVATION_OUTPUT_PART_V1","version":1,"profile":"6529STREAM_ADOPTED_VIEW_PRESERVATION_MANIFEST_V1","rows":"Every complete 31-word StreamViewPreservationCheckpointTypesV1.Output in exact original order; 64 rows except the exact final remainder","scope":"Complete canonical VIEW scope, membership identity and original Router adoption record","entropy":"Full original policy and actual status/seed; terminal is not finalized","servingKind":"1 current completed live token; 2 retained historical burned token under the still-current adoption; never current burned output","preservation":"Explicit non-sanction preservation JSON/HTML row commitments only; complete byte artifacts and browser execution remain separate. All original artwork and non-sanction Artist facts remain; this is not live tokenURI output","authority":"Permissionless byte verification grants no Artist, publication or finality authority"}'
            );
        }
        if (id == PART_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1","version":1,"encoding":"abi.encode(schemaId,chainId,core,checkpoint,checkpointConfigurationHash,Header,uint64 first,Output[] rows)","Header":"bytes32 checkpointId,bytes32 checkpointStateHash,StreamFinalityScope scope,bytes32 adoptionRecord,bytes32 sourceContextHash,bytes32 membershipHash,bytes32 policyChainHash,uint64 tokenCount,bytes32 outputRoot,bytes32 contentRoot","scope":"uint8 scopeType,uint256 collectionId,uint256 tokenId,bytes32 scopeId","arrayOffset":640,"headerBytesIncludingCount":672,"rowBytes":992,"length":"672+992*rows.length","first":"multiple of64 less than tokenCount","count":"min(64,tokenCount-first)","maximumTokenCount":16384,"words":"Canonical Solidity ABI including narrow widths and booleans; no alternate offset or trailing bytes","hash":"Keccak256 of complete bytes"}'
            );
        }
        if (id == INDEX) {
            return bytes(
                '{"name":"STREAM_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1","version":1,"profile":"6529STREAM_ADOPTED_VIEW_PRESERVATION_MANIFEST_V1","parts":"Complete ordered 64-row parts, maximum256; no omission, duplicate, overlap, truncation or sampling","identity":"Every part binds the same full Header and archive artist label; its record is derived by this actual host from verified bytes","current":"Full original checkpoint is independently current; all exact canonical part and index bytes retain current original ArtifactCoverage. Historical records remain readable after drift","capacity":"Bounded carriers do not prove the full checkpoint currentness call fits a transaction; no partial verification is current evidence","authority":"Archive artist identity is a byte-coverage label that downstream authority must join; it is not independent Artist consent"}'
            );
        }
        if (id == INDEX_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_VIEW_PRESERVATION_OUTPUT_MANIFEST_V1","version":1,"encoding":"abi.encode(schemaId,chainId,core,checkpoint,checkpointConfigurationHash,Header,bytes32 artistId,Descriptor[] parts)","Header":"Exact thirteen-word Header from STREAM_ABI_VIEW_PRESERVATION_OUTPUT_PART_V1","Descriptor":"bytes32 recordHash,bytes32 artifactHash,bytes32 coverageHash,bytes32 contentHash,uint64 byteLength,uint64 first,uint16 count,uint256 firstToken,uint256 lastToken","arrayOffset":640,"headerBytesIncludingCount":672,"descriptorBytes":288,"length":"672+288*ceil(tokenCount/64)","order":"Exact consecutive parts, strictly increasing actual token identities across boundaries","maximumCarrierBytes":524288,"words":"Canonical Solidity ABI; no alternate offsets or trailing bytes","hash":"Keccak256 of complete bytes"}'
            );
        }
        if (id == LEAF) {
            return bytes(
                '{"name":"STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1","version":1,"encoding":"abi.encode(keccak256(6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1),keccak256(6529STREAM_ADOPTED_POLICY_VIEW_PRESERVATION_V1),chainId,core,fullScope,adoptionRecord,complete31WordOutput)","node":"keccak256(abi.encode(keccak256(6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1),left,right))","order":"Complete strictly ascending token identities; zero-based row index; pair adjacent left/right without sorting and promote odd node unchanged","scope":"VIEW membership scopeId differs from viewId; full original adopted record binds actual view identity","meaning":"Separately named preservation JSON/HTML with only sanction projection; not original CMC six-field leaf or live outputRoot"}'
            );
        }
        revert("unknown view preservation document");
    }
}
