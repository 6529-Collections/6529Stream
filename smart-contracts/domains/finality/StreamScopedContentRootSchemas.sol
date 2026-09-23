// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Separate interpretation of original-Router scoped roots and aggregate consent.
/// @dev Never relabel the original COLLECTION root definition or treat individual state as signed family state.
library StreamScopedContentRootSchemas {
    bytes32 internal constant SCHEMA = keccak256("STREAM_SCOPED_CONTENT_ROOT_RECORD_V1");
    bytes32 internal constant CANON = keccak256("STREAM_ABI_SCOPED_CONTENT_ROOT_RECORD_V1");

    function document(bytes32 id) internal pure returns (bytes memory) {
        if (id == SCHEMA) {
            return bytes(
                '{"name":"STREAM_SCOPED_CONTENT_ROOT_RECORD_V1","version":1,"format":"Solidity ABI","tuple":"IStreamScopedContentRootPublication.Record","scope":"Exact TOKEN,RELEASE or SEASON; no COLLECTION or VIEW root substitution","source":"Selected provider-pinned current scoped STATIC snapshot,complete authoritative membership,selection,content and covered output manifest","authority":"Original Router SNAPSHOT class7 exact collection or class8 global grant; exact original Artist operation17 CONTENT_ROOT consent and original ratification/one-use state","lineage":"Expected predecessor equals exact scoped head; append-only collection Aggregate commits each ordered scoped transition","signedState":"Original collection CONTENT_ROOT family after wrapping its legacy family hash with the historical scoped Aggregate; individual Record.stateHash is not signed family state","retention":"Record and schema1 event preserve original fields; event includes original Aggregate; later current aggregate is not a historical substitute"}'
            );
        }
        if (id == CANON) {
            return bytes(
                '{"name":"STREAM_ABI_SCOPED_CONTENT_ROOT_RECORD_V1","version":1,"encoding":"abi.encode(IStreamScopedContentRootPublication.Record)","strings":"Exact validated URI bytes; no normalization","recordHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_CONTENT_ROOT_RECORD_V1),chainId,router,core,record,originalAggregate))","stateHash":"keccak256(abi.encode(keccak256(6529STREAM_SCOPED_CONTENT_ROOT_STATE_V1),chainId,router,core,recordWithStateHashConsentAndPublishedAtZero))","signedFamily":"keccak256(abi.encode(keccak256(6529STREAM_CONTENT_ROOT_FAMILY_WITH_SCOPES_V1),chainId,router,core,collectionId,originalLegacyFamilyHash,originalAggregate))","witnesses":"Historical aggregate and legacy hash are untrusted preimages checked against original record hash and signed consent; never new authority","trailingBytes":"Forbidden","alternateOffsets":"Forbidden"}'
            );
        }
        revert("unknown scoped root document");
    }
}
