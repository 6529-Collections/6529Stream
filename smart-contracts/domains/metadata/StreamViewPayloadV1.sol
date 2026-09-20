// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamStaticText as Text } from "./StreamStaticText.sol";
import { StreamMetadataRenderer as URI } from "./StreamMetadataRenderer.sol";

/// @notice Closed executable document grammar, independent of Artist or renderer authority.
library StreamViewPayloadV1 {
    bytes32 internal constant SCHEMA_ID = keccak256("STREAM_STATIC_VIEW_PAYLOAD_V1");
    string internal constant DEFINITION =
        '{"name":"STREAM_STATIC_VIEW_PAYLOAD_V1","encoding":"Solidity abi.encode","canonicalization":"RAW_BYTES","type":"(bytes32,string,string,string,bytes)","fields":["contextVersion","name","description","imageURI","script"],"contextVersion":"keccak256(STREAM_ADOPTED_VIEW_CONTEXT_V1)","limits":{"payloadBytes":40960,"nameBytes":128,"descriptionBytes":8192,"imageURIBytes":2048,"scriptBytes":24576},"source":"Complete UTF8 script; no external animation URI or library; safe optional image URI","authority":"Document publication is not Artist adoption; original Router op17 and admitted view renderer required"}';

    function schemaHash() internal pure returns (bytes32) {
        return keccak256(bytes(DEFINITION));
    }

    function decode(bytes memory raw) internal pure returns (V.Payload memory p) {
        if (raw.length == 0 || raw.length > V.MAX_PAYLOAD) revert V.InvalidViewAdoption();
        p = abi.decode(raw, (V.Payload));
        if (
            keccak256(raw) != keccak256(abi.encode(p)) || p.contextVersion != V.CONTEXT
                || bytes(p.name).length == 0 || bytes(p.name).length > 128
                || bytes(p.description).length > 8192 || bytes(p.imageURI).length > 2048
                || p.script.length == 0 || p.script.length > 24576 || !Text.isValidUtf8(p.name)
                || !Text.isValidUtf8(p.description) || !Text.isValidUtf8(p.imageURI)
                || !Text.isValidUtf8(string(p.script))
        ) revert V.InvalidViewAdoption();
    }

    /// @dev Publication-only URI predicate; serving decodes the exact already-admitted bytes
    /// internally and never delegates to this public metadata helper from the STATIC renderer.
    function requireAdmissible(bytes memory raw) public pure returns (V.Payload memory p) {
        p = decode(raw);
        URI.requireValidUtf8ContentUri("viewImageURI", p.imageURI, 2048, true);
    }
}
