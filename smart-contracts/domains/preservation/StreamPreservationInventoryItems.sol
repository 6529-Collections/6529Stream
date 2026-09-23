// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamPreservationInventoryTypes as T
} from "../../interfaces/stream/preservation/StreamPreservationInventoryTypes.sol";

/// @notice Canonical item constructors used only after the producer authenticates source bytes.
library StreamPreservationInventoryItems {
    function bytesItem(
        T.Kind kind,
        bytes32 role,
        address source,
        bytes32 record,
        uint256 index,
        bytes memory value
    ) internal pure returns (T.Item memory item) {
        if (value.length > type(uint64).max) revert T.InvalidInventoryItem();
        item.kind = value.length == 0 && kind == T.Kind.NATIVE_BYTES ? T.Kind.EMPTY_BYTES : kind;
        item.role = role;
        item.source = source;
        item.sourceRecord = record;
        item.sourceIndex = index;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(keccak256(value));
        item.byteSize = uint64(value.length);
    }

    function runtime(bytes32 role, address target, bytes32 record, uint256 index)
        internal
        view
        returns (T.Item memory item)
    {
        if (target.code.length == 0 || target.code.length > type(uint64).max) {
            revert T.InvalidInventoryItem();
        }
        item.kind = T.Kind.CONTRACT_RUNTIME;
        item.role = role;
        item.source = target;
        item.sourceRecord = record;
        item.sourceIndex = index;
        item.algorithm = 1;
        item.canonicalizationId = keccak256("RAW_BYTES");
        item.digest = abi.encodePacked(target.codehash);
        item.byteSize = uint64(target.code.length);
    }

    function absent(bytes32 role, address source, bytes32 record, uint256 index)
        internal
        pure
        returns (T.Item memory item)
    {
        item.kind = T.Kind.ABSENT;
        item.role = role;
        item.source = source;
        item.sourceRecord = record;
        item.sourceIndex = index;
    }
}
