// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamProspectiveReferenceTypes as P
} from "../../interfaces/stream/preservation/StreamProspectiveReferenceTypes.sol";
import { StreamRenderContextV1 as Text } from "../metadata/StreamRenderContextV1.sol";
import { StreamStaticText } from "../metadata/StreamStaticText.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Fixed named simulation input convention, separate from every actual-token renderer.
/// @dev No tokenId, serial, finalization or original Coordinator is invented by this encoder.
library StreamProspectiveReferenceEncoding {
    bytes32 public constant PROFILE = keccak256("6529STREAM_PROSPECTIVE_NAMED_SIMULATION_V1");

    function vectorHash(P.Vector memory v) public pure returns (bytes32) {
        bytes memory n = bytes(v.name);
        if (n.length == 0 || n.length > 64 || v.input.length > 4096) {
            revert P.InvalidProspectiveReference();
        }
        for (uint256 i; i < n.length; ++i) {
            uint8 c = uint8(n[i]);
            if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 45
                        || c == 95)) revert P.InvalidProspectiveReference();
        }
        return keccak256(abi.encode(PROFILE, v));
    }

    function html(
        uint256 chain,
        address core,
        uint256 cid,
        bytes32 sourceHash,
        P.Vector memory v,
        bytes memory script
    ) public pure returns (bytes memory out) {
        bytes32 vector = vectorHash(v);
        if (
            chain == 0 || core == address(0) || cid == 0 || sourceHash == 0 || script.length == 0
                || script.length > 24576 || !StreamStaticText.isValidUtf8(string(script))
        ) revert P.InvalidProspectiveReference();
        out = abi.encodePacked(
            '<!doctype html><html data-stream-render-state="prospective"><head><meta charset="utf-8">',
            '<meta name="viewport" content="width=device-width,initial-scale=1"></head><body><script>',
            'const STREAM_PROSPECTIVE={profile:"',
            Strings.toHexString(uint256(PROFILE), 32),
            '",chainId:"',
            Strings.toString(chain),
            '",core:"',
            Strings.toHexString(uint256(uint160(core)), 20),
            '",collectionId:"',
            Strings.toString(cid),
            '",sourceHash:"',
            Strings.toHexString(uint256(sourceHash), 32),
            '",vectorHash:"',
            Strings.toHexString(uint256(vector), 32),
            '",name:"',
            v.name,
            '",seed:"',
            Strings.toHexString(uint256(v.seed), 32),
            '",inputBase64:"',
            Base64.encode(v.input),
            '"};Object.freeze(STREAM_PROSPECTIVE);</script><script>',
            Text.scriptText(string(script)),
            "</script></body></html>"
        );
        if (out.length > 40960) revert P.InvalidProspectiveReference();
    }
}
