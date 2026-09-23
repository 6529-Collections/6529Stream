// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/preservation/StreamReferenceModeTypes.sol";

/// @notice Full configured-budget, bounded-return transport for the new evidence profile.
library StreamReferenceModeReads {
    function read(address target, bytes memory input, uint256 maximum, uint256 cap)
        internal
        view
        returns (bytes memory raw)
    {
        // Warm target and finish input construction before the admission check.
        if (target.code.length == 0 || cap == 0 || cap > type(uint256).max / 2) {
            revert StreamReferenceModeTypes.ModeRead(target);
        }
        uint256 required = cap + cap / 63 + 100000;
        uint256 available = gasleft();
        if (available < required) {
            revert StreamReferenceModeTypes.ModeParentGas(available, required);
        }
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(cap, target, add(input, 32), mload(input), 0, 0)
            size := returndatasize()
        }
        if (!ok || size == 0 || size > maximum) revert StreamReferenceModeTypes.ModeRead(target);
        raw = new bytes(size);
        assembly ("memory-safe") { returndatacopy(add(raw, 32), 0, size) }
    }

    function exact(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory raw)
    {
        raw = read(target, input, size, cap);
        if (raw.length != size) revert StreamReferenceModeTypes.ModeRead(target);
    }

    function canonical(address target, bytes memory raw, bytes memory encoded) internal pure {
        if (keccak256(raw) != keccak256(encoded)) revert StreamReferenceModeTypes.ModeRead(target);
    }

    function pin(address target, bytes32 hash) internal view {
        if (hash == 0 || target.code.length == 0 || target.codehash != hash) {
            revert StreamReferenceModeTypes.ModeRead(target);
        }
    }
}
