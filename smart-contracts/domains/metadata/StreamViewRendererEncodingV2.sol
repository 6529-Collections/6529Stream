// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamViewAdoptionTypes as V
} from "../../interfaces/stream/metadata/StreamViewAdoptionTypes.sol";
import { StreamViewPolicyTypesV2 as T } from "./StreamViewPolicyTypesV2.sol";
import { StreamViewPolicyContextV2 as PolicyContext } from "./StreamViewPolicyContextV2.sol";
import { StreamRenderContextV1 as Text } from "./StreamRenderContextV1.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Fixed pure formatter. Renderer authenticates inputs; this helper grants no authority.
/// @dev Called only through STATICCALL by the admitted renderer, with an immutable runtime pin.
library StreamViewRendererEncodingV2 {
    uint32 private constant MAX_BYTES = 262144;

    function html(
        R.RenderRequest memory r,
        bytes32 scopeId,
        bytes32 sourceHash,
        uint256 chainId,
        bytes memory tokenData,
        T.Entropy memory entropy,
        bytes memory script
    ) public pure returns (string memory) {
        string memory context = _context(r, scopeId, sourceHash, chainId, tokenData, entropy);
        string memory html = string.concat(
            "<html><head></head><body><script>window.STREAM_VIEW=",
            context,
            ";const stream=window.STREAM_VIEW;const hash=stream.seed;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;</script><script>",
            Text.scriptText(string(script)),
            "</script></body></html>"
        );
        if (bytes(html).length > MAX_BYTES) revert V.InvalidViewAdoption();
        return html;
    }

    function output(
        R.RenderRequest memory r,
        string memory name,
        string memory description,
        string memory imageURI,
        string memory html,
        bytes memory artist,
        uint8 mode
    ) public pure returns (string memory) {
        string memory json = string(
            abi.encodePacked(
                '{"name":"',
                Text.escape(name),
                '","description":"',
                Text.escape(description),
                '","image":"',
                Text.escape(imageURI),
                '","animation_url":"data:text/html;base64,',
                Base64.encode(bytes(html)),
                '","view_id":"',
                Strings.toHexString(uint256(r.viewId), 32),
                '","view_record":"',
                Strings.toHexString(uint256(r.viewManifestHash), 32),
                '","adoption_record":"',
                Strings.toHexString(uint256(r.metadataSnapshotHash), 32),
                '","artist_attribution":',
                artist,
                "}"
            )
        );
        if (bytes(json).length > MAX_BYTES) revert V.InvalidViewAdoption();
        if (mode == 1) {
            string memory uri =
                string.concat("data:application/json;base64,", Base64.encode(bytes(json)));
            if (bytes(uri).length > MAX_BYTES) revert V.InvalidViewAdoption();
            return uri;
        }
        return json;
    }

    function _context(
        R.RenderRequest memory r,
        bytes32 scopeId,
        bytes32 sourceHash,
        uint256 chainId,
        bytes memory tokenData,
        T.Entropy memory entropy
    ) private pure returns (string memory) {
        bytes memory first = abi.encodePacked(
            '{"schema":"STREAM_POLICY_VIEW_CONTEXT_V2","chainId":"',
            Strings.toString(chainId),
            '","contract":"',
            Strings.toHexString(uint256(uint160(r.core)), 20),
            '","collectionId":"',
            Strings.toString(r.collectionId),
            '","tokenId":"',
            Strings.toString(r.tokenId),
            '","collectionSerial":"',
            Strings.toString(r.collectionSerial),
            '","seed":"',
            Strings.toHexString(uint256(r.tokenHash), 32),
            '","entropy":',
            PolicyContext.encode(entropy),
            ',"scopeId":"',
            Strings.toHexString(uint256(scopeId), 32)
        );
        return string(
            abi.encodePacked(
                first,
                '","viewId":"',
                Strings.toHexString(uint256(r.viewId), 32),
                '","viewRecord":"',
                Strings.toHexString(uint256(r.viewManifestHash), 32),
                '","adoptionRecord":"',
                Strings.toHexString(uint256(r.metadataSnapshotHash), 32),
                '","sourceHash":"',
                Strings.toHexString(uint256(sourceHash), 32),
                '","tokenData":"',
                Text.hexBytes(tokenData),
                '"}'
            )
        );
    }
}
