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
        bytes[7] memory pieces;
        pieces[0] = bytes(
            string.concat(
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
            )
        );
        pieces[1] = bytes(
            string.concat(
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
                ',"packageFiles":'
            )
        );
        pieces[2] = packageJSON;
        pieces[3] = bytes(',"platformPrerequisites":');
        pieces[4] = platformJSON;
        pieces[5] = bytes(
            string.concat(
                ',"runtimeObjectHash":',
                h(e.objectHash),
                ',"softwareRasterization":true,"toolchainName":',
                q(e.toolchainName, 256),
                ',"toolchainPath":',
                q(e.toolchainPath, 1024),
                ',"toolchainSha256":',
                h(e.toolchainSha256)
            )
        );
        pieces[6] = bytes(
            string.concat(
                ',"toolchainVersion":',
                q(e.toolchainVersion, 256),
                ',"version":1,"viewportHeight":',
                u(e.viewportHeight),
                ',"viewportWidth":',
                u(e.viewportWidth),
                "}"
            )
        );
        uint256 length;
        for (uint256 i; i < pieces.length; ++i) {
            length += pieces[i].length;
        }
        if (length > MAX) revert StreamReferenceRenderTypes.InvalidReferenceRender();
        bytes memory out = new bytes(length);
        uint256 cursor;
        for (uint256 i; i < pieces.length; ++i) {
            _copy(out, cursor, pieces[i]);
            cursor += pieces[i].length;
        }
        return out;
    }

    function files(StreamReferenceRenderTypes.PackageFile[] memory rows, bool relative)
        public
        pure
        returns (string memory out)
    {
        // Absolute paths retain the original UTF-8/JSON quoting routine and its errors.
        // Relative paths are already restricted to a literal JSON-safe ASCII alphabet.
        bytes[] memory quoted = new bytes[](relative ? 0 : rows.length);
        uint256 length = 2;
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].sha256Digest == 0
                    || (i != 0 && !_less(bytes(rows[i - 1].path), bytes(rows[i].path)))
            ) revert StreamReferenceRenderTypes.InvalidReferenceRender();
            uint256 pathLength;
            if (relative) {
                _relative(bytes(rows[i].path));
                pathLength = bytes(rows[i].path).length + 2;
            } else {
                quoted[i] = bytes(q(rows[i].path, 2048));
                pathLength = quoted[i].length;
            }
            length += 107 + _digits(rows[i].byteSize) + pathLength + (i == 0 ? 0 : 1);
            // Preserve the original prefix bound, including its final-bracket convention.
            if (length - 1 > MAX) revert StreamReferenceRenderTypes.InvalidReferenceRender();
        }
        bytes memory output = new bytes(length);
        output[0] = "[";
        uint256 cursor = 1;
        for (uint256 i; i < rows.length; ++i) {
            if (i != 0) output[cursor++] = ",";
            cursor = _rowPrefix(output, cursor, rows[i].byteSize);
            if (relative) {
                output[cursor++] = '"';
                _copy(output, cursor, bytes(rows[i].path));
                cursor += bytes(rows[i].path).length;
                output[cursor++] = '"';
            } else {
                _copy(output, cursor, quoted[i]);
                cursor += quoted[i].length;
            }
            cursor = _rowDigest(output, cursor, rows[i].sha256Digest);
        }
        output[cursor] = "]";
        return string(output);
    }

    function _digits(uint256 value) private pure returns (uint256 digits) {
        assembly ("memory-safe") {
            digits := 1
            for { } iszero(lt(value, 10)) { } {
                value := div(value, 10)
                digits := add(digits, 1)
            }
        }
    }

    /// @dev Writes into the one exact-size output; every row has a further 87-byte suffix.
    function _rowPrefix(bytes memory output, uint256 cursor, uint256 value)
        private
        pure
        returns (uint256 next)
    {
        uint256 digits = _digits(value);
        assembly ("memory-safe") {
            let target := add(add(output, 32), cursor)
            mstore(target, '{"byteSize":"')
            target := add(target, 13)
            let end := add(target, digits)
            for { let at := end } gt(at, target) { } {
                at := sub(at, 1)
                mstore8(at, add(48, mod(value, 10)))
                value := div(value, 10)
            }
            mstore(end, "\",\"path\":")
            next := add(cursor, add(22, digits))
        }
    }

    function _rowDigest(bytes memory output, uint256 cursor, bytes32 value)
        private
        pure
        returns (uint256 next)
    {
        assembly ("memory-safe") {
            let target := add(add(output, 32), cursor)
            mstore(target, ',"sha256Digest":"0x')
            target := add(target, 19)
            // Spread sixteen bytes into pairs, then translate their nibbles in parallel.
            function hexWord(v) -> encoded {
                v := and(
                    or(v, shl(64, v)),
                    0x0000000000000000ffffffffffffffff0000000000000000ffffffffffffffff
                )
                v := and(
                    or(v, shl(32, v)),
                    0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff
                )
                v := and(
                    or(v, shl(16, v)),
                    0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff
                )
                v := and(
                    or(v, shl(8, v)),
                    0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff
                )
                let nibble := 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f
                v := and(or(v, shl(4, v)), nibble)
                let letters :=
                    shr(
                        4,
                        and(
                            add(
                                v,
                                0x0606060606060606060606060606060606060606060606060606060606060606
                            ),
                            0x1010101010101010101010101010101010101010101010101010101010101010
                        )
                    )
                encoded := add(
                    add(v, 0x3030303030303030303030303030303030303030303030303030303030303030),
                    mul(letters, 39)
                )
            }
            mstore(target, hexWord(shr(128, value)))
            mstore(add(target, 32), hexWord(and(value, 0xffffffffffffffffffffffffffffffff)))
            let end := add(target, 64)
            mstore8(end, 0x22)
            mstore8(add(end, 1), 0x7d)
            next := add(cursor, 85)
        }
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
                // Same printable ASCII interval and exact forbidden characters as the
                // original eight equality checks: backslash, colon, <, >, quote, |, ?, *.
                if or(gt(sub(c, 0x20), 0x5e), and(shr(c, 0x1000000010000000d400040400000000), 1)) {
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
