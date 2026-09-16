// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/preservation/StreamReferenceRenderTypes.sol";
import "./StreamRecordJson.sol";
import "./StreamSnapshotManifestJson.sol";

/// @notice Complete original declared engine/toolchain inventory and native OS requirements.
/// @dev Full package/file correspondence is an attributed curator statement independently checked
///      by the offline package validator; this serializer does not execute ZIP bytes or an engine.
library StreamReferenceEnvironmentJson {
    uint256 private constant MAX = 524288;

    function manifest(StreamReferenceRenderTypes.Environment memory e)
        public
        pure
        returns (bytes memory)
    {
        return manifestWithAuthenticatedFiles(
            e, bytes(files(e.packageFiles, true)), bytes(files(e.platformPrerequisites, false))
        );
    }

    /// @dev The fixed host must obtain both JSON arrays from exact complete ABI-keyed immutable
    ///      preparation. Direct library callers gain no publication authority from this function.
    function manifestWithAuthenticatedFiles(
        StreamReferenceRenderTypes.Environment memory e,
        bytes memory packageJSON,
        bytes memory platformJSON
    ) public pure returns (bytes memory) {
        return manifestWithAuthenticatedFilesInternal(e, packageJSON, platformJSON);
    }

    /// @dev Same complete read-only builder for the fixed preparation library, without
    ///      encoding the full Environment and both retained arrays across another call.
    function manifestWithAuthenticatedFilesInternal(
        StreamReferenceRenderTypes.Environment memory e,
        bytes memory packageJSON,
        bytes memory platformJSON
    ) internal pure returns (bytes memory) {
        if (
            e.objectHash == 0 || e.coverageHash == 0 || e.engineExecutableSha256 == 0
                || e.toolchainSha256 == 0 || e.packageFiles.length == 0
                || e.platformPrerequisites.length == 0 || e.viewportWidth == 0
                || e.viewportWidth > 4096 || e.viewportHeight == 0 || e.viewportHeight > 4096
                || e.devicePixelRatio != 1 || !e.softwareRasterization
                || keccak256(bytes(e.colorSpace)) != keccak256("srgb")
                || keccak256(bytes(e.operatingSystem)) != keccak256("Windows")
                || keccak256(bytes(e.architecture)) != keccak256("AMD64")
                || e.captureProfile != keccak256("STREAM_REFERENCE_CANVAS_STILL_WINDOWS_V1")
        ) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        _member(e.packageFiles, e.engineExecutablePath, e.engineExecutableSha256);
        _member(e.packageFiles, e.toolchainPath, e.toolchainSha256);
        string memory out = string.concat(
            '{"architecture":',
            q(e.architecture, 64),
            ',"captureProfile":',
            h(e.captureProfile),
            ',"colorSpace":',
            q(e.colorSpace, 64),
            ',"devicePixelRatio":',
            u(e.devicePixelRatio),
            ',"engineExecutablePath":',
            q(e.engineExecutablePath, 1024),
            ',"engineExecutableSha256":',
            h(e.engineExecutableSha256)
        );
        out = string.concat(
            out,
            ',"engineName":',
            q(e.engineName, 256),
            ',"engineVersion":',
            q(e.engineVersion, 256),
            ',"licenseBasis":"undetermined","licenseNote":',
            q(e.licenseNote, 16384),
            ',"operatingSystem":',
            q(e.operatingSystem, 64),
            ',"operatingSystemVersion":',
            q(e.operatingSystemVersion, 128),
            ',"packageFiles":',
            string(packageJSON)
        );
        out = string.concat(
            out,
            ',"platformPrerequisites":',
            string(platformJSON),
            ',"runtimeObjectHash":',
            h(e.objectHash),
            ',"softwareRasterization":true,"toolchainName":',
            q(e.toolchainName, 256),
            ',"toolchainPath":',
            q(e.toolchainPath, 1024),
            ',"toolchainSha256":',
            h(e.toolchainSha256)
        );
        out = string.concat(
            out,
            ',"toolchainVersion":',
            q(e.toolchainVersion, 256),
            ',"version":1,"viewportHeight":',
            u(e.viewportHeight),
            ',"viewportWidth":',
            u(e.viewportWidth),
            "}"
        );
        if (bytes(out).length > MAX) revert StreamReferenceRenderTypes.InvalidReferenceRender();
        return bytes(out);
    }

    function files(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        public
        pure
        returns (string memory out)
    {
        bytes[] memory encoded = new bytes[](rows.length);
        uint256 length = 2;
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].sha256Digest == 0
                    || (i != 0 && !_less(bytes(rows[i - 1].path), bytes(rows[i].path)))
            ) revert StreamReferenceRenderTypes.InvalidReferenceRender();
            if (relative) _relative(bytes(rows[i].path));
            encoded[i] = bytes(
                string.concat(
                    '{"byteSize":',
                    u(rows[i].byteSize),
                    ',"path":',
                    relative ? string.concat('"', rows[i].path, '"') : q(rows[i].path, 2048),
                    ',"sha256Digest":',
                    h(rows[i].sha256Digest),
                    "}"
                )
            );
            length += encoded[i].length + (i == 0 ? 0 : 1);
            // Preserve the original prefix bound before appending its final closing bracket.
            if (length - 1 > MAX) revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bytes memory output = new bytes(length);
        output[0] = "[";
        uint256 cursor = 1;
        for (uint256 i; i < encoded.length; ++i) {
            if (i != 0) output[cursor++] = ",";
            _copy(output, cursor, encoded[i]);
            cursor += encoded[i].length;
        }
        output[cursor] = "]";
        return string(output);
    }

    /// @dev Each aligned source word is read once; the final padded word emits only real bytes.
    function _copy(bytes memory output, uint256 cursor, bytes memory row) private pure {
        if (cursor + row.length > output.length) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        assembly ("memory-safe") {
            let source := add(row, 32)
            let target := add(add(output, 32), cursor)
            let length := mload(row)
            let offset := 0
            for { } iszero(gt(add(offset, 32), length)) { offset := add(offset, 32) } {
                mstore(add(target, offset), mload(add(source, offset)))
            }
            if lt(offset, length) {
                let tail := mload(add(source, offset))
                let remaining := sub(length, offset)
                for { let i := 0 } lt(i, remaining) { i := add(i, 1) } {
                    mstore8(add(add(target, offset), i), byte(i, tail))
                }
            }
        }
    }

    function _member(
        StreamReferenceRenderTypes.PackageFile[] memory rows,
        string memory path,
        bytes32 digest
    ) private pure {
        bytes32 name = keccak256(bytes(path));
        bool found;
        for (uint256 i; i < rows.length; ++i) {
            if (keccak256(bytes(rows[i].path)) == name) {
                if (found || rows[i].byteSize == 0 || rows[i].sha256Digest != digest) {
                    revert StreamReferenceRenderTypes.InvalidReferenceRender();
                }
                found = true;
            }
        }
        if (!found) revert StreamReferenceRenderTypes.InvalidReferenceRender();
    }

    function _less(bytes memory a, bytes memory b) private pure returns (bool result) {
        assembly ("memory-safe") {
            let alen := mload(a)
            let blen := mload(b)
            let n := alen
            if lt(blen, n) { n := blen }
            let adata := add(a, 32)
            let bdata := add(b, 32)
            let offset := 0
            let different := 0
            for { } iszero(gt(add(offset, 32), n)) { offset := add(offset, 32) } {
                let av := mload(add(adata, offset))
                let bv := mload(add(bdata, offset))
                if iszero(eq(av, bv)) {
                    result := lt(av, bv)
                    different := 1
                    break
                }
            }
            if iszero(different) {
                if lt(offset, n) {
                    let av := mload(add(adata, offset))
                    let bv := mload(add(bdata, offset))
                    let remaining := sub(n, offset)
                    for { let i := 0 } lt(i, remaining) { i := add(i, 1) } {
                        let ac := byte(i, av)
                        let bc := byte(i, bv)
                        if iszero(eq(ac, bc)) {
                            result := lt(ac, bc)
                            different := 1
                            break
                        }
                    }
                }
                if iszero(different) { result := lt(alen, blen) }
            }
        }
    }

    function _relative(bytes memory path) private pure {
        if (path.length == 0 || path.length > 1024) {
            revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bool valid;
        assembly ("memory-safe") {
            let length := mload(path)
            let data := add(path, 32)
            let start := 0
            valid := 1
            for { let i := 0 } lt(i, length) { i := add(i, 1) } {
                let c := byte(and(i, 31), mload(add(data, and(i, not(31)))))
                if or(lt(c, 0x20), iszero(lt(c, 0x7f))) {
                    valid := 0
                    break
                }
                if or(
                    or(or(eq(c, 0x5c), eq(c, 0x3a)), or(eq(c, 0x3c), eq(c, 0x3e))),
                    or(or(eq(c, 0x22), eq(c, 0x7c)), or(eq(c, 0x3f), eq(c, 0x2a)))
                ) {
                    valid := 0
                    break
                }
                if eq(c, 0x2f) {
                    if eq(i, start) {
                        valid := 0
                        break
                    }
                    let last := byte(and(sub(i, 1), 31), mload(add(data, and(sub(i, 1), not(31)))))
                    if or(eq(last, 0x2e), eq(last, 0x20)) {
                        valid := 0
                        break
                    }
                    start := add(i, 1)
                }
            }
            if valid {
                if eq(start, length) { valid := 0 }
                let last :=
                    byte(and(sub(length, 1), 31), mload(add(data, and(sub(length, 1), not(31)))))
                if or(eq(last, 0x2e), eq(last, 0x20)) { valid := 0 }
            }
        }
        if (!valid) revert StreamReferenceRenderTypes.InvalidReferenceRender();
    }

    function q(string memory s, uint256 bound) private pure returns (string memory) {
        return StreamRecordJson.quote(s, bound, false);
    }

    // Exact fixed-width implementation from the pinned snapshot JSON helper, kept local so
    // each inventory row does not allocate another linked-call argument/return wrapper.
    function h(bytes32 value) private pure returns (string memory result) {
        result = new string(68);
        assembly ("memory-safe") {
            let start := add(result, 32)
            mstore8(start, 0x22)
            mstore8(add(start, 1), 0x30)
            mstore8(add(start, 2), 0x78)
            let alphabet := 0x3031323334353637383961626364656600000000000000000000000000000000
            let cursor := add(start, 3)
            let end := add(cursor, 64)
            for { } lt(cursor, end) { cursor := add(cursor, 1) } {
                mstore8(cursor, byte(shr(252, value), alphabet))
                value := shl(4, value)
            }
            mstore8(end, 0x22)
        }
    }

    // Literal pinned StreamRecordJson.unsigned body; exact decimal strings remain unchanged.
    function u(uint256 value) private pure returns (string memory) {
        uint256 digits = 1;
        for (uint256 remaining = value; remaining >= 10; remaining /= 10) {
            ++digits;
        }
        bytes memory output = new bytes(digits + 2);
        output[0] = '"';
        output[digits + 1] = '"';
        do {
            output[digits--] = bytes1(uint8(48 + value % 10));
            value /= 10;
        } while (value != 0);
        return string(output);
    }
}
