// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import {
    StreamEntropyPolicyConsumerTypes as P
} from "../../interfaces/stream/entropy/StreamEntropyPolicyConsumerTypes.sol";
import { StreamStaticRenderEncoding as Encoding } from "./StreamStaticRenderEncoding.sol";
import { StreamRenderContextV1 as Context } from "./StreamRenderContextV1.sol";
import { StreamTerminalEntropyJSON as TerminalJSON } from "./StreamTerminalEntropyJSON.sol";
import { StreamMetadataCitation as Citation } from "./StreamMetadataCitation.sol";
import { StreamStaticC2PAJSON } from "./StreamStaticC2PAJSON.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";
import { Base64 } from "../../vendor/openzeppelin/Base64.sol";

/// @notice Pure, separately admitted terminal context. There is no hash/seed or ambient random source.
library StreamTerminalEntropyEncoding {
    using Strings for uint256;
    error InvalidTerminalRender();

    function render(
        R.RenderRequest memory r,
        Encoding.Prepared memory p,
        P.Terminal memory policy,
        string memory script,
        address router,
        uint8 mode
    ) public pure returns (string memory) {
        if (
            mode > 3 || r.tokenId == 0 || r.tokenHash != 0
                || r.state == R.TokenRenderState.PENDING_RANDOMNESS
                || p.config.mode != R.MetadataMode.ONCHAIN || policy.status < 1 || policy.status > 2
                || policy.policy.renderRequirement != 1 || !policy.policy.explicitPolicy
                || !policy.policy.frozen
        ) revert InvalidTerminalRender();
        string memory context = _context(r, p, policy);
        string memory html;
        if (mode >= 2 || p.bundle == 0) {
            html = string(
                abi.encodePacked(
                    "<html><head></head><body><script>window.__STREAM_TOKEN__=",
                    context,
                    ";const stream=window.__STREAM_TOKEN__;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;",
                    "</script><script>",
                    Context.scriptText(p.facts.dependencyScript),
                    "</script><script>",
                    Context.scriptText(script),
                    "</script></body></html>"
                )
            );
            if (bytes(html).length > 16777216) revert InvalidTerminalRender();
        }
        if (mode == 3) return html;
        string memory root = string.concat(
            "web3://", uint256(uint160(router)).toHexString(20), ":", p.source.chainId.toString()
        );
        bytes memory c2pa = p.c2paConflictsEnabled
            ? StreamStaticC2PAJSON.withConflicts(
                p.c2pa,
                p.c2paSubject,
                p.c2paUnavailable,
                p.c2paTokenConflict,
                p.c2paCollectionConflict,
                p.c2paConflictsUnavailable
            )
            : StreamStaticC2PAJSON.fields(p.c2pa, p.c2paSubject, p.c2paUnavailable);
        bytes memory json = abi.encodePacked(
            '{"name":"',
            Context.escape(p.source.name),
            " #",
            r.collectionSerial.toString(),
            '","description":"',
            Context.escape(p.source.description),
            '","image":"',
            Context.escape(p.source.imageURI),
            '","metadata_schema_version":"6529stream-static-terminal-entropy-v1","metadata_state":"',
            _state(r, policy),
            '","token_data_base64":"',
            Base64.encode(p.facts.tokenData),
            '","properties":{"stream":',
            context,
            ',"provenance":{"attribution":',
            p.artist,
            c2pa,
            '},"config_record_hash":"',
            uint256(r.metadataSnapshotHash).toHexString(32),
            '","views":{"tokenJSON":"',
            root,
            "/tokenJSON/",
            r.tokenId.toString(),
            '","tokenHTML":"',
            root,
            "/tokenHTML/",
            r.tokenId.toString(),
            '"}}',
            bytes(html).length == 0
                ? bytes("")
                : abi.encodePacked(
                    ',"animation_url":"data:text/html;base64,', Base64.encode(bytes(html)), '"'
                ),
            "}"
        );
        if (mode < 2 && json.length > 18000) {
            json = abi.encodePacked(
                '{"name":"',
                Context.escape(p.source.name),
                " #",
                r.collectionSerial.toString(),
                '","image":"',
                Context.escape(p.source.imageURI),
                '","metadata_schema_version":"6529stream-static-terminal-entropy-v1","metadata_state":"',
                _state(r, policy),
                '","token_data_location":"tokenJSON:token_data_base64","properties":{"stream":{"citation":"',
                Citation.work(p.source.chainId, r.core, r.tokenId),
                '",',
                TerminalJSON.fields(policy),
                ',"render_profile":"6529STREAM_TERMINAL_ENTROPY_RENDER_V1"},"config_record_hash":"',
                uint256(r.metadataSnapshotHash).toHexString(32),
                '","views":{"tokenJSON":"',
                root,
                "/tokenJSON/",
                r.tokenId.toString(),
                '","tokenHTML":"',
                root,
                "/tokenHTML/",
                r.tokenId.toString(),
                '"}}}'
            );
        }
        if (json.length > (mode >= 2 ? 16777216 : 18000)) revert InvalidTerminalRender();
        if (mode != 1) return string(json);
        string memory uri = string.concat("data:application/json;base64,", Base64.encode(json));
        if (bytes(uri).length > 24576) revert InvalidTerminalRender();
        return uri;
    }

    function _state(R.RenderRequest memory r, P.Terminal memory p)
        private
        pure
        returns (string memory)
    {
        return r.state == R.TokenRenderState.BURNED
            ? "burned"
            : p.status == 1 ? "disabled" : "not_required";
    }

    function _context(
        R.RenderRequest memory r,
        Encoding.Prepared memory p,
        P.Terminal memory policy
    ) private pure returns (string memory) {
        return string(
            abi.encodePacked(
                '{"schema":"stream-render-context-terminal-v1","chainId":"',
                p.source.chainId.toString(),
                '","contract":"',
                uint256(uint160(r.core)).toHexString(20),
                '","tokenId":"',
                r.tokenId.toString(),
                '","collectionId":"',
                r.collectionId.toString(),
                '","collectionSerial":"',
                r.collectionSerial.toString(),
                '","collectionSupplyMode":"',
                Context.supply(r.collectionSupplyMode),
                '","collectionStatus":"',
                Context.status(r.collectionStatus),
                '","citation":"',
                Citation.work(p.source.chainId, r.core, r.tokenId),
                '",',
                TerminalJSON.fields(policy),
                ',"render_profile":"6529STREAM_TERMINAL_ENTROPY_RENDER_V1","tokenData":"',
                Context.hexBytes(p.facts.tokenData),
                '","scriptHash":"',
                uint256(p.facts.scriptHash).toHexString(32),
                '","dependencyHash":"',
                uint256(p.facts.dependencyHash).toHexString(32),
                '","dependencyScript":"',
                Context.escape(p.facts.dependencyScript),
                '"}'
            )
        );
    }
}
