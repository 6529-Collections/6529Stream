// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamViewPreservationCheckpointTypesV1 as T
} from "../../interfaces/stream/finality/StreamViewPreservationCheckpointTypesV1.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";

/// @notice Ordered full-row VIEW preservation tree, with explicit distinct leaf and node domains.
/// @dev No sorting or odd-node duplication. Caller must authenticate complete membership/output.
library StreamViewPreservationContentTreeV1 {
    bytes32 internal constant LEAF = keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_LEAF_V1");
    bytes32 internal constant NODE = keccak256("6529STREAM_VIEW_PRESERVATION_CONTENT_NODE_V1");

    function leafHash(
        uint256 chainId,
        address core,
        StreamFinalityScope memory scope,
        bytes32 adoption,
        T.Output memory output
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(LEAF, T.OUTPUT_PROFILE, chainId, core, scope, adoption, output));
    }

    function nodeHash(bytes32 left, bytes32 right) internal pure returns (bytes32) {
        return keccak256(abi.encode(NODE, left, right));
    }

    function root(
        uint256 chainId,
        address core,
        StreamFinalityScope memory scope,
        bytes32 adoption,
        T.Output[] memory rows
    ) internal pure returns (bytes32) {
        if (
            core == address(0) || adoption == 0 || scope.scopeType != StreamFinalityScopeType.VIEW
                || scope.collectionId == 0 || scope.tokenId != 0 || scope.scopeId == 0
                || rows.length == 0 || rows.length > T.MAX_ROWS
        ) revert T.InvalidViewCheckpoint();
        bytes32[] memory level = new bytes32[](rows.length);
        uint256 previous;
        for (uint256 i; i < rows.length; ++i) {
            if (
                rows[i].index != i || rows[i].tokenId <= previous || rows[i].jsonHash == 0
                    || rows[i].htmlHash == 0
            ) revert T.ViewCheckpointIndex(uint64(i));
            previous = rows[i].tokenId;
            level[i] = leafHash(chainId, core, scope, adoption, rows[i]);
        }
        uint256 count = rows.length;
        while (count > 1) {
            uint256 next;
            for (uint256 i; i < count; i += 2) {
                level[next++] = i + 1 < count ? nodeHash(level[i], level[i + 1]) : level[i];
            }
            count = next;
        }
        return level[0];
    }
}
