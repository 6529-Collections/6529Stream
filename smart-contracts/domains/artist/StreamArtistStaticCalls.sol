// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Internal bounded STATICCALL only; these helpers are inlined, never linked by DELEGATECALL.
library StreamArtistStaticCalls {
    error StaticArtistReadFailed(address target);

    function bounded(address target, bytes memory data, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory result)
    {
        if (target.code.length == 0 || gasleft() <= 12000) {
            revert StaticArtistReadFailed(target);
        }
        uint256 available = gasleft() - 10000;
        if (cap > available) cap = available;
        result = new bytes(maximum);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(data, 32), mload(data), add(result, 32), maximum)
            size := returndatasize()
        }
        if (!ok || size > maximum) revert StaticArtistReadFailed(target);
        assembly ("memory-safe") { mstore(result, size) }
    }

    function fixedRead(address target, bytes memory data, uint256 expected, uint256 cap)
        internal
        view
        returns (bytes memory result)
    {
        result = bounded(target, data, expected, cap);
        if (result.length != expected) revert StaticArtistReadFailed(target);
    }

    function inner(address target, bytes memory result, uint256 maximum)
        internal
        pure
        returns (bytes memory value)
    {
        value = abi.decode(result, (bytes));
        if (value.length > maximum || keccak256(result) != keccak256(abi.encode(value))) {
            revert StaticArtistReadFailed(target);
        }
    }
}
