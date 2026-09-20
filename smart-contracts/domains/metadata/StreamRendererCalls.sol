// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Internal bounded STATICCALL. Never copies unbounded failed or oversized returndata.
library StreamRendererCalls {
    error RendererReadFailed(address target, bytes4 selector);
    uint256 internal constant RESERVE = 12000;

    // Keep literal return bounds from producing a separate read body at each call site.
    struct ReadOptions {
        uint256 maximum;
        bool exact;
    }

    function read(address target, bytes memory input, ReadOptions memory options, uint256 cap)
        internal
        view
        returns (bytes memory result)
    {
        uint256 maximum = options.maximum;
        bool exact = options.exact;
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

    /// @dev Fixed linked-code extraction, not a selectable source. The caller supplies a
    /// bound derived from its unchanged per-source/render budgets. Failed code keeps its
    /// original small custom error; neither success nor failure copies unbounded data.
    function fixedCode(address target, bytes memory input, uint256 maximum, uint256 cap)
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
        if (size > (ok ? maximum : 4096) || (!ok && size == 0)) {
            revert RendererReadFailed(target, bytes4(input));
        }
        result = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(result, 32), 0, size) }
        if (!ok) assembly ("memory-safe") { revert(add(result, 32), mload(result)) }
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
