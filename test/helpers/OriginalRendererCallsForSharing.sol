// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Original read body frozen from joined source 9b016f1a. This oracle covers
/// transport results and refusals, not exact gas costs or complete renderer behavior.
library OriginalRendererCallsForSharing {
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
}
