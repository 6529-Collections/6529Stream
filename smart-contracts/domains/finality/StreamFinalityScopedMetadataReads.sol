// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamFinalityScopedMetadataReads as I
} from "../../interfaces/stream/finality/IStreamFinalityScopedMetadataReads.sol";
import {
    StreamFinalityScope,
    StreamFinalityScopeType
} from "../../interfaces/stream/finality/StreamArtworkFinalityTypes.sol";
import { StreamFinalityBoundedReads as Reads } from "./StreamFinalityBoundedReads.sol";

/// @notice Required full-scope reads from the pinned selected provider, with no legacy fallback.
library StreamFinalityScopedMetadataReads {
    error InvalidScopedMetadataSource(address target);
    error InvalidScopedMetadataScope();

    function contentRoot(
        address target,
        bytes32 runtime,
        StreamFinalityScope memory scope,
        uint256 cap
    ) public view returns (bytes32 root, uint64 count, bytes32 schema) {
        _require(target, runtime, scope, cap);
        bytes memory raw = Reads.read(target, abi.encodeCall(I.scopedContentRoot, (scope)), 96, cap);
        (root, count, schema) = abi.decode(raw, (bytes32, uint64, bytes32));
        if (keccak256(raw) != keccak256(abi.encode(root, count, schema))) {
            revert InvalidScopedMetadataSource(target);
        }
    }

    function snapshot(
        address target,
        bytes32 runtime,
        StreamFinalityScope memory scope,
        uint256 cap
    ) public view returns (bytes32) {
        _require(target, runtime, scope, cap);
        return abi.decode(
            Reads.read(target, abi.encodeCall(I.scopedSnapshotHash, (scope)), 32, cap), (bytes32)
        );
    }

    function manifest(
        address target,
        bytes32 runtime,
        StreamFinalityScope memory scope,
        uint256 cap
    ) public view returns (bool published, bytes32 hash) {
        _require(target, runtime, scope, cap);
        bytes memory raw = Reads.read(target, abi.encodeCall(I.scopedManifest, (scope)), 64, cap);
        (published, hash) = abi.decode(raw, (bool, bytes32));
        if (keccak256(raw) != keccak256(abi.encode(published, hash))) {
            revert InvalidScopedMetadataSource(target);
        }
    }

    function _require(
        address target,
        bytes32 runtime,
        StreamFinalityScope memory scope,
        uint256 cap
    ) private view {
        if (
            scope.collectionId == 0
                || (scope.scopeType == StreamFinalityScopeType.TOKEN
                        ? scope.tokenId == 0 || scope.scopeId != 0
                        : (scope.scopeType != StreamFinalityScopeType.RELEASE
                            && scope.scopeType != StreamFinalityScopeType.SEASON
                            && scope.scopeType != StreamFinalityScopeType.VIEW)
                        || scope.tokenId != 0 || scope.scopeId == 0)
        ) revert InvalidScopedMetadataScope();
        if (
            target.code.length == 0 || runtime == 0 || target.codehash != runtime
                || !Reads.supportsOptional(target, type(I).interfaceId, cap)
        ) revert InvalidScopedMetadataSource(target);
    }
}
