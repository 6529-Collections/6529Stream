// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Output grammar is distinct from the original retained VIEW payload's input grammar.
library StreamViewRendererFormatV2 {
    bytes32 internal constant ID = keccak256("6529STREAM_ADOPTED_POLICY_VIEW_RENDERER_V2");
    bytes32 internal constant VERSION =
        keccak256("6529STREAM_STATIC_ADOPTED_POLICY_VIEW_RENDERER_V2");
    string internal constant SCHEMA =
        '{"name":"STREAM_ADOPTED_POLICY_VIEW_OUTPUT_V2","encoding":"UTF8 JSON","fields":["name","description","image","animation_url","view_id","view_record","adoption_record","artist_attribution"],"html":"Exact adopted UTF8 script plus STREAM_POLICY_VIEW_CONTEXT_V2 original token identity/serial/seed/tokenData and complete original entropy policy/status and full scope/view/adoption/source commitments","entropy":"Original constructor-indexed Coordinator; explicit full H direct STATIC facts; statuses 1/2 retain seed=0 and finalized=false, ASYNC status5 retains actual seed; legacy status5 branch remains explicitly separate","historical":"Saved adopted payload and renderer; original live Artist attribution remains live"}';

    function schemaHash() internal pure returns (bytes32) {
        return keccak256(bytes(SCHEMA));
    }
}
