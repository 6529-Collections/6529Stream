// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Local supplied-file wire primitives, never protocol authority or readiness.
library StreamViewCeremonyInputEncoding {
    error InvalidMemberIndex();
    error InvalidDigest();
    error InvalidByteSize();

    function memberIndex(uint256 index) internal pure returns (string memory) {
        if (index > type(uint64).max) revert InvalidMemberIndex();
        bytes memory out = new bytes(20);
        for (uint256 i; i < 20; ++i) {
            out[19 - i] = bytes1(uint8(48 + index % 10));
            index /= 10;
        }
        return string(out);
    }

    function memberName(uint256 index) internal pure returns (string memory) {
        return string.concat("member-", memberIndex(index), ".json");
    }

    function digest(bytes memory raw) internal pure returns (bytes32 value) {
        if (raw.length != 32) revert InvalidDigest();
        assembly ("memory-safe") { value := mload(add(raw, 32)) }
        if (value == 0) revert InvalidDigest();
    }

    function byteSize(uint256 value) internal pure returns (uint64) {
        if (value == 0 || value > type(uint64).max) revert InvalidByteSize();
        return uint64(value);
    }
}
