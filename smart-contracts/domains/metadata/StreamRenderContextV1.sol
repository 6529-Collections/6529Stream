// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { IStreamRenderer as R } from "../../interfaces/stream/metadata/IStreamRenderer.sol";
import { Strings } from "../../vendor/openzeppelin/Strings.sol";

/// @notice Pure STREAM_CONTEXT_V1 serialization; no runtime reads or linked library calls.
/// @dev The calling renderer supplies authenticated source facts. This encoder never confers
/// source authority and never parses Core's opaque token data. Chain ID is a saved source fact.
library StreamRenderContextV1 {
    struct Facts {
        uint256 chainId;
        uint8 entropyStatus;
        address entropyProvider;
        string viewName;
        bytes32 scriptHash;
        bytes32 dependencyHash;
        bytes32 mediaManifestHash;
        bytes tokenData;
        string dependencyScript;
    }
    error InvalidRenderContext();
    bytes16 private constant HEX = "0123456789abcdef";

    function json(R.RenderRequest memory r, Facts memory f, bytes32 rendererId, bytes32 version)
        internal
        pure
        returns (string memory)
    {
        if (
            r.core == address(0) || r.collectionId == 0 || f.chainId == 0 || rendererId == 0
                || version == 0 || bytes(f.viewName).length == 0 || bytes(f.viewName).length > 96
                || (r.viewId == 0
                        ? keccak256(bytes(f.viewName)) != keccak256("MARKETPLACE")
                        : keccak256(bytes(f.viewName)) != r.viewId)
        ) revert InvalidRenderContext();
        bytes memory out = abi.encodePacked(
            '{"schema":"stream-render-context-v1","chainId":"',
            Strings.toString(f.chainId),
            '","contract":"',
            Strings.toHexString(uint256(uint160(r.core)), 20),
            '","tokenId":"',
            Strings.toString(r.tokenId),
            '","collectionId":"',
            Strings.toString(r.collectionId),
            '","collectionSerial":"',
            Strings.toString(r.collectionSerial),
            '","collectionSupplyMode":"',
            supply(r.collectionSupplyMode),
            '","collectionStatus":"',
            status(r.collectionStatus),
            '"'
        );
        if (r.state != R.TokenRenderState.PENDING_RANDOMNESS) {
            out = bytes.concat(
                out,
                abi.encodePacked(
                    ',"hash":"',
                    Strings.toHexString(uint256(r.tokenHash), 32),
                    '","seed":"',
                    Strings.toHexString(uint256(r.tokenHash), 32),
                    '"'
                )
            );
        }
        out = bytes.concat(
            out, abi.encodePacked(',"entropyStatus":"', entropy(f.entropyStatus), '"')
        );
        if (f.entropyProvider != address(0)) {
            out = bytes.concat(
                out,
                abi.encodePacked(
                    ',"entropyProvider":"',
                    Strings.toHexString(uint256(uint160(f.entropyProvider)), 20),
                    '"'
                )
            );
        }
        out = bytes.concat(
            out,
            abi.encodePacked(',"viewId":"', escape(f.viewName), '"'),
            optional("viewManifestHash", r.viewManifestHash),
            optional("metadataSnapshotHash", r.metadataSnapshotHash)
        );
        out = bytes.concat(
            out,
            abi.encodePacked(
                ',"rendererId":"',
                Strings.toHexString(uint256(rendererId), 32),
                '","rendererVersion":"',
                Strings.toHexString(uint256(version), 32),
                '","renderContextVersion":"STREAM_CONTEXT_V1"'
            ),
            optional("scriptHash", f.scriptHash),
            optional("dependencyHash", f.dependencyHash),
            optional("mediaManifestHash", f.mediaManifestHash)
        );
        out = bytes.concat(
            out,
            abi.encodePacked(
                ',"tokenData":"',
                hexBytes(f.tokenData),
                '","dependencyScript":"',
                escape(f.dependencyScript),
                '"}'
            )
        );
        return string(out);
    }

    function html(string memory context, string memory dependency, string memory script)
        internal
        pure
        returns (string memory)
    {
        // escape() renders '<' as a JSON Unicode escape, including inside dependencyScript.
        // Dependency and artist JS are separate executable elements; only end-tag prefixes are
        // escaped there so valid JavaScript bytes retain their meaning inside strings/comments.
        return string(
            abi.encodePacked(
                "<html><head></head><body><script>window.__STREAM_TOKEN__=",
                context,
                ";const stream=window.__STREAM_TOKEN__;const hash=stream.hash;const tokenId=Number(stream.tokenId);const tokenData=stream.tokenData;",
                "</script><script>",
                scriptText(dependency),
                "</script><script>",
                scriptText(script),
                "</script></body></html>"
            )
        );
    }

    function optional(string memory key, bytes32 value) private pure returns (bytes memory) {
        return value == 0
            ? bytes("")
            : abi.encodePacked(',"', key, '":"', Strings.toHexString(uint256(value), 32), '"');
    }

    function supply(uint8 value) internal pure returns (string memory) {
        if (value == 0) return "FIXED";
        if (value == 1) return "CAPPED_OPEN";
        if (value == 2) return "UNCAPPED_OPEN";
        revert InvalidRenderContext();
    }

    function status(uint8 value) internal pure returns (string memory) {
        if (value == 0) return "ACTIVE";
        if (value == 1) return "PAUSED";
        if (value == 2) return "CLOSED";
        revert InvalidRenderContext();
    }

    function entropy(uint8 value) private pure returns (string memory) {
        if (value == 0) return "NONE";
        if (value == 1) return "DISABLED";
        if (value == 2) return "NOT_REQUIRED";
        if (value == 3) return "REGISTERED";
        if (value == 4) return "REQUESTED";
        if (value == 5) return "FINALIZED";
        if (value == 6) return "STALE";
        if (value == 7) return "FAILED";
        revert InvalidRenderContext();
    }

    function hexBytes(bytes memory value) internal pure returns (string memory) {
        bytes memory out = new bytes(2 + value.length * 2);
        out[0] = "0";
        out[1] = "x";
        for (uint256 i; i < value.length; ++i) {
            uint8 b = uint8(value[i]);
            out[2 + i * 2] = HEX[b >> 4];
            out[3 + i * 2] = HEX[b & 15];
        }
        return string(out);
    }

    function escape(string memory value) internal pure returns (string memory) {
        bytes memory raw = bytes(value);
        bytes memory out = new bytes(raw.length * 6);
        uint256 cursor;
        for (uint256 i; i < raw.length; ++i) {
            uint8 b = uint8(raw[i]);
            if (b == 34 || b == 92) {
                out[cursor++] = "\\";
                out[cursor++] = bytes1(b);
            } else if (b < 32 || b == 60) {
                out[cursor++] = "\\";
                out[cursor++] = "u";
                out[cursor++] = "0";
                out[cursor++] = "0";
                out[cursor++] = HEX[b >> 4];
                out[cursor++] = HEX[b & 15];
            } else if (
                b == 0xe2 && i + 2 < raw.length && raw[i + 1] == 0x80
                    && (raw[i + 2] == 0xa8 || raw[i + 2] == 0xa9)
            ) {
                out[cursor++] = "\\";
                out[cursor++] = "u";
                out[cursor++] = "2";
                out[cursor++] = "0";
                out[cursor++] = "2";
                out[cursor++] = raw[i + 2] == 0xa8 ? bytes1("8") : bytes1("9");
                i += 2;
            } else {
                out[cursor++] = raw[i];
            }
        }
        assembly ("memory-safe") { mstore(out, cursor) }
        return string(out);
    }

    function scriptText(string memory value) internal pure returns (string memory) {
        bytes memory raw = bytes(value);
        bytes memory out = new bytes(raw.length + raw.length / 8);
        uint256 cursor;
        for (uint256 i; i < raw.length; ++i) {
            if (
                i + 8 <= raw.length && raw[i] == 0x3c && raw[i + 1] == 0x2f
                    && (uint8(raw[i + 2]) | 32) == 115 && (uint8(raw[i + 3]) | 32) == 99
                    && (uint8(raw[i + 4]) | 32) == 114 && (uint8(raw[i + 5]) | 32) == 105
                    && (uint8(raw[i + 6]) | 32) == 112 && (uint8(raw[i + 7]) | 32) == 116
            ) {
                out[cursor++] = 0x3c;
                out[cursor++] = 0x5c;
                ++i;
            }
            out[cursor++] = raw[i];
        }
        assembly ("memory-safe") { mstore(out, cursor) }
        return string(out);
    }
}
