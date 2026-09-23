// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Output grammar is distinct from the original retained VIEW payload's input grammar.
library StreamViewRendererFormat {
    bytes32 internal constant ID = keccak256("6529STREAM_ADOPTED_VIEW_RENDERER_V1");
    bytes32 internal constant VERSION = keccak256("6529STREAM_STATIC_ADOPTED_VIEW_RENDERER_V1");
    string internal constant SCHEMA =
        '{"name":"STREAM_ADOPTED_VIEW_OUTPUT_V1","encoding":"UTF8 JSON","fields":["name","description","image","animation_url","view_id","view_record","adoption_record","artist_attribution"],"html":"Exact adopted UTF8 script plus STREAM_VIEW_CONTEXT_V1 original token identity/serial/seed/tokenData and full scope/view/adoption/source commitments","entropy":"Original Coordinator FINALIZED=5 only; terminal V2 requires a distinct profile","historical":"Saved adopted payload and renderer; original live Artist attribution remains live"}';

    function schemaHash() internal pure returns (bytes32) {
        return keccak256(bytes(SCHEMA));
    }
}
