// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Internal bounded STATICCALL. Never copies unbounded failed or oversized returndata.
library StreamRendererCalls {
    error RendererReadFailed(address target, bytes4 selector);
    uint256 internal constant RESERVE = 12000;

    function read(address target, bytes memory input, uint256 maximum, bool exact, uint256 cap)
        internal
        view
        returns (bytes memory result)
    {
        uint256 left = gasleft();
        if (target.code.length == 0 || left <= RESERVE || cap == 0) {
            revert RendererReadFailed(target, bytes4(input));
        }
        uint256 available = (left - RESERVE) * 63 / 64;
        if (cap > available) cap = available;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size > maximum || (exact && size != maximum)) {
            revert RendererReadFailed(target, bytes4(input));
        }
        result = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(result, 32), 0, size) }
    }

    function stringResult(bytes memory result, uint256 maximum)
        internal
        pure
        returns (string memory value)
    {
        value = abi.decode(result, (string));
        if (bytes(value).length > maximum || keccak256(result) != keccak256(abi.encode(value))) {
            revert RendererReadFailed(address(0), 0);
        }
    }
}
