// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArchivalTypes as A
} from "../../interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Native non-rebased tx/data-root inclusion for a complete externally retained object.
/// @dev This verifies the included native root, size and first/last native leaf paths. It does
///      NOT recompute the external object's flat SHA256/Keccak or establish network consensus.
///      A separately named checkpoint quorum anchors tx-ID/root association; independent full
///      retrieval fixity must attest the correspondence of native and flat object commitments.
library StreamArweaveObjectInclusion {
    error InvalidExternalObjectInclusion();

    uint256 private constant _MAX_PATH = 64 + 96 * 64;

    function verify(
        A.Checkpoint calldata c,
        bytes calldata transactionPath,
        bytes calldata firstDataPath,
        bytes calldata lastDataPath
    ) public pure returns (bytes32 firstChunkDigest, bytes32 lastChunkDigest) {
        if (
            c.dataSize == 0 || c.dataRoot == 0 || c.transactionRoot == 0
                || c.transactionStart >= c.transactionEnd || c.transactionEnd > c.blockDataSize
                || c.transactionEnd - c.transactionStart != c.dataSize
        ) {
            revert InvalidExternalObjectInclusion();
        }
        _transaction(c, transactionPath);
        firstChunkDigest = _endpoint(c.dataRoot, c.dataSize, firstDataPath, true);
        lastChunkDigest = _endpoint(c.dataRoot, c.dataSize, lastDataPath, false);
        // The path root commits every intermediate leaf. First/last paths do not
        // purport to sample-check or hash the omitted bytes; fixity retrieves all.
    }

    function _transaction(A.Checkpoint calldata c, bytes calldata path) private pure {
        (bytes32 root, uint256 start, uint256 end) =
            _path(c.transactionRoot, c.transactionStart, c.blockDataSize, path);
        if (root != c.dataRoot || start != c.transactionStart || end != c.transactionEnd) {
            revert InvalidExternalObjectInclusion();
        }
    }

    function _endpoint(bytes32 root, uint64 size, bytes calldata path, bool first)
        private
        pure
        returns (bytes32 digest)
    {
        uint256 start;
        uint256 end;
        (digest, start, end) = _path(root, first ? 0 : size - 1, size, path);
        if ((first ? start != 0 : end != size) || end - start > 262144 || digest == 0) {
            revert InvalidExternalObjectInclusion();
        }
    }

    function _path(bytes32 root, uint256 offset, uint256 right, bytes calldata path)
        private
        pure
        returns (bytes32 data, uint256 left, uint256 end)
    {
        if (
            path.length < 64 || path.length > _MAX_PATH || (path.length - 64) % 96 != 0
                || offset >= right
        ) revert InvalidExternalObjectInclusion();
        uint256 cursor;
        while (path.length - cursor > 64) {
            bytes32 l = _word(path, cursor);
            bytes32 r = _word(path, cursor + 32);
            uint256 split = uint256(_word(path, cursor + 64));
            // The native rebase-marker form is explicitly outside this profile.
            if (l == 0 || r == 0 || _branch(l, r, split) != root) {
                revert InvalidExternalObjectInclusion();
            }
            if (offset < split) {
                root = l;
                if (split < right) right = split;
            } else {
                root = r;
                if (split > left) left = split;
            }
            cursor += 96;
        }
        data = _word(path, cursor);
        uint256 leafEnd = uint256(_word(path, cursor + 32));
        if (
            data == 0 || _leaf(data, leafEnd) != root || left >= right || leafEnd <= left
                || leafEnd > right || offset < left || offset >= leafEnd
        ) {
            revert InvalidExternalObjectInclusion();
        }
        end = leafEnd;
    }

    function _branch(bytes32 left, bytes32 right, uint256 split) private pure returns (bytes32) {
        return sha256(
            abi.encodePacked(
                sha256(abi.encodePacked(left)),
                sha256(abi.encodePacked(right)),
                sha256(abi.encodePacked(split))
            )
        );
    }

    function _leaf(bytes32 data, uint256 end) private pure returns (bytes32) {
        return
            sha256(abi.encodePacked(sha256(abi.encodePacked(data)), sha256(abi.encodePacked(end))));
    }

    function _word(bytes calldata data, uint256 offset) private pure returns (bytes32 value) {
        assembly ("memory-safe") { value := calldataload(add(data.offset, offset)) }
    }
}
