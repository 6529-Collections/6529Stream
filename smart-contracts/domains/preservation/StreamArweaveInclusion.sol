// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamArchivalTypes as A
} from "../../interfaces/stream/preservation/StreamArchivalTypes.sol";

/// @notice Native annotated SHA256 paths for a complete non-rebased single-chunk transaction.
/// @dev Reference: ArweaveTeam/arweave 18d402c714132e1de3962b12ff32a420127e0c02,
///      ar_merkle:get_branch_id/get_leaf_id/validate_path and ar_poa:validate_paths.
///      Checkpoint authentication and transaction-ID association are separate oracle obligations.
library StreamArweaveInclusion {
    uint256 internal constant MAX_PAYLOAD_BYTES = 8192;
    uint256 internal constant MAX_TRANSACTION_PATH_BYTES = 64 + 96 * 32;

    function verify(
        A.Checkpoint calldata c,
        bytes calldata transactionPath,
        bytes calldata dataPath,
        bytes calldata payload
    ) internal pure returns (bytes32 digest) {
        if (
            payload.length == 0 || payload.length > MAX_PAYLOAD_BYTES
                || c.dataSize != payload.length || c.transactionStart >= c.transactionEnd
                || c.transactionEnd > c.blockDataSize
                || c.transactionEnd - c.transactionStart != c.dataSize
                || transactionPath.length < 64
                || transactionPath.length > MAX_TRANSACTION_PATH_BYTES
                || (transactionPath.length - 64) % 96 != 0 || dataPath.length != 64
        ) revert A.InvalidNativeInclusion();

        (bytes32 dataRoot, uint256 start, uint256 end) = _transactionLeaf(
            c.transactionRoot, c.transactionStart, c.blockDataSize, transactionPath
        );
        if (dataRoot != c.dataRoot || start != c.transactionStart || end != c.transactionEnd) {
            revert A.InvalidNativeInclusion();
        }
        digest = sha256(payload);
        if (
            _word(dataPath, 0) != digest || uint256(_word(dataPath, 32)) != payload.length
                || _leaf(digest, payload.length) != dataRoot
        ) revert A.InvalidNativeInclusion();
    }

    function _transactionLeaf(bytes32 root, uint256 offset, uint256 right, bytes calldata path)
        private
        pure
        returns (bytes32 data, uint256 left, uint256 end)
    {
        uint256 cursor;
        while (path.length - cursor > 64) {
            bytes32 l = _word(path, cursor);
            bytes32 r = _word(path, cursor + 32);
            uint256 split = uint256(_word(path, cursor + 64));
            // Zero is the native rebase marker; this profile never interprets it as a branch.
            if (l == bytes32(0) || _branch(l, r, split) != root) {
                revert A.InvalidNativeInclusion();
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
        if (data == bytes32(0) || _leaf(data, leafEnd) != root || left >= right) {
            revert A.InvalidNativeInclusion();
        }
        // The supported positive-size canonical leaf must have its actual end within the branch.
        // This excludes the native basic-ruleset's clamped malformed/zero-size leaf shapes.
        if (leafEnd <= left || leafEnd > right) revert A.InvalidNativeInclusion();
        end = leafEnd;
        if (offset < left || offset >= end) revert A.InvalidNativeInclusion();
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
