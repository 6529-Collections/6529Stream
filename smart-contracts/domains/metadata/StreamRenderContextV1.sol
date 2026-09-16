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
            Strings.toString(r.collectionSerial)
        );
        out = bytes.concat(
            out,
            abi.encodePacked(
                '","collectionSupplyMode":"',
                supply(r.collectionSupplyMode),
                '","collectionStatus":"',
                status(r.collectionStatus),
                '"'
            )
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

    /// @dev Count exact expansion first; ordinary spans are copied in words. The old encoder's
    /// byte rules deliberately preserve arbitrary non-special bytes, including malformed UTF-8.
    function escape(string memory value) internal pure returns (string memory) {
        bytes memory raw = bytes(value);
        uint256 extra;
        assembly ("memory-safe") {
            function at(p) -> b { b := byte(and(p, 31), mload(and(p, not(31)))) }
            let end := add(add(raw, 32), mload(raw))
            for { let p := add(raw, 32) } lt(p, end) { p := add(p, 1) } {
                let b := at(p)
                switch or(eq(b, 34), eq(b, 92))
                case 1 { extra := add(extra, 1) }
                default {
                    switch or(lt(b, 32), eq(b, 60))
                    case 1 { extra := add(extra, 5) }
                    default {
                        if and(eq(b, 0xe2), lt(add(p, 2), end)) {
                            if and(
                                eq(at(add(p, 1)), 0x80),
                                or(eq(at(add(p, 2)), 0xa8), eq(at(add(p, 2)), 0xa9))
                            ) {
                                extra := add(extra, 3)
                                p := add(p, 2)
                            }
                        }
                    }
                }
            }
        }
        if (extra == 0) return value;
        bytes memory out = new bytes(raw.length + extra);
        assembly ("memory-safe") {
            function at(p) -> b { b := byte(and(p, 31), mload(and(p, not(31)))) }
            function copy(dst, src, size) {
                for { } iszero(lt(size, 32)) { size := sub(size, 32) } {
                    mstore(dst, mload(src))
                    dst := add(dst, 32)
                    src := add(src, 32)
                }
                for { } gt(size, 0) { size := sub(size, 1) } {
                    mstore8(dst, at(src))
                    dst := add(dst, 1)
                    src := add(src, 1)
                }
            }
            let end := add(add(raw, 32), mload(raw))
            let run := add(raw, 32)
            let dst := add(out, 32)
            let hexDigits := 0x3031323334353637383961626364656600000000000000000000000000000000
            for { let p := run } lt(p, end) { p := add(p, 1) } {
                let b := at(p)
                let kind := 0
                if or(eq(b, 34), eq(b, 92)) { kind := 1 }
                if or(lt(b, 32), eq(b, 60)) { kind := 2 }
                if and(eq(b, 0xe2), lt(add(p, 2), end)) {
                    if and(
                        eq(at(add(p, 1)), 0x80),
                        or(eq(at(add(p, 2)), 0xa8), eq(at(add(p, 2)), 0xa9))
                    ) { kind := 3 }
                }
                if kind {
                    let size := sub(p, run)
                    copy(dst, run, size)
                    dst := add(dst, size)
                    mstore8(dst, 92)
                    switch kind
                    case 1 {
                        mstore8(add(dst, 1), b)
                        dst := add(dst, 2)
                    }
                    default {
                        mstore8(add(dst, 1), 117)
                        switch kind
                        case 2 {
                            mstore8(add(dst, 2), 48)
                            mstore8(add(dst, 3), 48)
                            mstore8(add(dst, 4), byte(shr(4, b), hexDigits))
                            mstore8(add(dst, 5), byte(and(b, 15), hexDigits))
                        }
                        case 3 {
                            mstore8(add(dst, 2), 50)
                            mstore8(add(dst, 3), 48)
                            mstore8(add(dst, 4), 50)
                            mstore8(add(dst, 5), add(56, eq(at(add(p, 2)), 0xa9)))
                            p := add(p, 2)
                        }
                        dst := add(dst, 6)
                    }
                    run := add(p, 1)
                }
            }
            copy(dst, run, sub(end, run))
        }
        return string(out);
    }

    /// @dev The historical rule escapes every case-insensitive eight-byte "</script" prefix,
    /// including prefixes without a trailing '>'. No-match scripts retain their original bytes.
    function scriptText(string memory value) internal pure returns (string memory) {
        bytes memory raw = bytes(value);
        uint256 matches;
        assembly ("memory-safe") {
            function at(p) -> b { b := byte(and(p, 31), mload(and(p, not(31)))) }
            function isEndTag(p, end) -> yes {
                if iszero(lt(sub(end, p), 8)) {
                    if eq(at(p), 60) {
                        yes := and(
                            eq(at(add(p, 1)), 47),
                            and(
                                eq(or(at(add(p, 2)), 32), 115),
                                and(
                                    eq(or(at(add(p, 3)), 32), 99),
                                    and(
                                        eq(or(at(add(p, 4)), 32), 114),
                                        and(
                                            eq(or(at(add(p, 5)), 32), 105),
                                            and(
                                                eq(or(at(add(p, 6)), 32), 112),
                                                eq(or(at(add(p, 7)), 32), 116)
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    }
                }
            }
            let end := add(add(raw, 32), mload(raw))
            for { let p := add(raw, 32) } lt(p, end) { p := add(p, 1) } {
                if isEndTag(p, end) {
                    matches := add(matches, 1)
                    p := add(p, 7)
                }
            }
        }
        if (matches == 0) return value;
        bytes memory out = new bytes(raw.length + matches);
        assembly ("memory-safe") {
            function at(p) -> b { b := byte(and(p, 31), mload(and(p, not(31)))) }
            function copy(dst, src, size) {
                for { } iszero(lt(size, 32)) { size := sub(size, 32) } {
                    mstore(dst, mload(src))
                    dst := add(dst, 32)
                    src := add(src, 32)
                }
                for { } gt(size, 0) { size := sub(size, 1) } {
                    mstore8(dst, at(src))
                    dst := add(dst, 1)
                    src := add(src, 1)
                }
            }
            function isEndTag(p, end) -> yes {
                if iszero(lt(sub(end, p), 8)) {
                    if eq(at(p), 60) {
                        yes := and(
                            eq(at(add(p, 1)), 47),
                            and(
                                eq(or(at(add(p, 2)), 32), 115),
                                and(
                                    eq(or(at(add(p, 3)), 32), 99),
                                    and(
                                        eq(or(at(add(p, 4)), 32), 114),
                                        and(
                                            eq(or(at(add(p, 5)), 32), 105),
                                            and(
                                                eq(or(at(add(p, 6)), 32), 112),
                                                eq(or(at(add(p, 7)), 32), 116)
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    }
                }
            }
            let end := add(add(raw, 32), mload(raw))
            let run := add(raw, 32)
            let dst := add(out, 32)
            for { let p := run } lt(p, end) { p := add(p, 1) } {
                if isEndTag(p, end) {
                    let size := add(sub(p, run), 1)
                    copy(dst, run, size)
                    dst := add(dst, size)
                    mstore8(dst, 92)
                    dst := add(dst, 1)
                    run := add(p, 1)
                    p := add(p, 7)
                }
            }
            copy(dst, run, sub(end, run))
        }
        return string(out);
    }
}
