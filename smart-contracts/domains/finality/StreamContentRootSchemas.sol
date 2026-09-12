// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Exact interpretation documents that must be registered before root publication.
/// @dev Bytes use RAW_BYTES registration; the declared canonicalizations describe artwork payloads.
library StreamContentRootSchemas {
    bytes32 internal constant LEAF_SCHEMA = keccak256("STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1");
    bytes32 internal constant LEAF_CANON = keccak256("STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1");
    bytes32 internal constant ROOT_SCHEMA = keccak256("STREAM_TOKEN_CONTENT_ROOT_RECORD_V1");
    bytes32 internal constant ROOT_CANON = keccak256("STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1");

    function document(bytes32 id) public pure returns (bytes memory) {
        if (id == LEAF_SCHEMA) {
            return bytes(
                '{"name":"STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1","version":1,"format":"Solidity ABI","profile":"6529STREAM_CONTENT_INLINE_ONCHAIN_V1","leaves":"Every completed Core token, including burns, in checkpoint order; original entropy finalized","fields":["uint256 tokenId","bytes32 metadataHash","bytes32 imageHash","bytes32 animationHash","bytes32 contentHash","bytes32 tokenDataHash"],"hash":"Keccak-256 of exact complete bytes","metadata":"Complete deterministic Stream JSON with exact field order and integer precision; not JCS","image":"Decoded canonical inline image bytes; zero only if absent","animation":"Complete served HTML; required and nonzero","content":"No separate content asset in this profile; zero","tokenData":"Exact Core bytes, including empty bytes; hash is never an absence marker","root":"CMC-CONTENT-ROOT ordered domain-separated tree; odd node promoted without sorting or duplication"}'
            );
        }
        if (id == LEAF_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_TOKEN_CONTENT_LEAF_MANIFEST_V1","version":1,"encoding":"abi.encode(bytes32 schemaId,uint256 chainId,address core,address checkpoint,bytes32 checkpointHash,uint256 collectionId,bytes32 contentRoot,uint64 tokenCount,StreamTokenContentLeaf[] leaves)","schemaId":"keccak256(STREAM_TOKEN_CONTENT_LEAF_MANIFEST_V1)","headBytes":288,"arrayOffset":288,"headerBytesIncludingArrayCount":320,"leafBytes":192,"length":"320+192*tokenCount","arrayCount":"Exactly tokenCount; positive","words":"32-byte big-endian unsigned integers; addresses and uint64 values zero-extended","trailingBytes":"Forbidden","alternateOffsets":"Forbidden","leafOrder":"Exact checkpoint order"}'
            );
        }
        if (id == ROOT_SCHEMA) {
            return bytes(
                '{"name":"STREAM_TOKEN_CONTENT_ROOT_RECORD_V1","version":1,"format":"Solidity ABI","publication":"Artist-approved collection root backed by complete current inline-ONCHAIN checkpoint and preserved leaf manifest","tuple":"IStreamContentRootPublication.Record","fields":["Publication(uint256 collectionId,bytes32 expectedPredecessor,bytes32 verifiedManifestRecordHash,string manifestURI)","bytes32 contentRoot","uint64 leafCount","bytes32 manifestHash","bytes32 artistId","uint64 bindingGeneration","bytes32 bindingHash","address publisher","uint8 authorizationClass","uint64 grantRevision","bytes32 routeHash","bytes32 stateHash","bytes32 artistConsent","uint64 publishedAt"],"authority":"SNAPSHOT family class7 at collection or class8 at global0; nonzero governed grant revision","artist":"Exact current accepted association and operation17 CONTENT_ROOT consent","lineage":"Expected predecessor equals previous authoritative record; append-only history","scope":"Collection; other profiles and scopes are separate"}'
            );
        }
        if (id == ROOT_CANON) {
            return bytes(
                '{"name":"STREAM_ABI_TOKEN_CONTENT_ROOT_RECORD_V1","version":1,"encoding":"abi.encode(IStreamContentRootPublication.Record)","strings":"Exact validated UTF-8 URI bytes; no normalization","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_CONTENT_ROOT_RECORD_V1),chainId,router,record))","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_CONTENT_ROOT_STATE_V1),chainId,router,recordWithStateHashConsentAndPublishedAtZero))","history":"Record includes the actual consent and publication timestamp; neither alters approved content state","trailingBytes":"Forbidden","alternateOffsets":"Forbidden"}'
            );
        }
        revert("unknown content root document");
    }

    function definitionHash(bytes32 id) public pure returns (bytes32) {
        return keccak256(document(id));
    }
}
