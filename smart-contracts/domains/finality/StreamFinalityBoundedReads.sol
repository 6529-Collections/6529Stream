// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Exact-return static reads with a cap and retained caller gas.
/// @dev The configured cap is an upper bound. Allocate before measuring remaining gas.
library StreamFinalityBoundedReads {
    uint256 internal constant PARENT_RESERVE = 100000;
    error FinalityReadFailed(address target);
    error FinalityCapabilityMalformed(address target);

    function tryRead(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bool ok, uint256 actualSize, bytes memory result)
    {
        result = new bytes(size);
        uint256 available = gasleft();
        if (available <= PARENT_RESERVE) return (false, 0, result);
        uint256 forwarded = available - PARENT_RESERVE;
        if (cap < forwarded) forwarded = cap;
        assembly ("memory-safe") {
            ok := staticcall(forwarded, target, add(input, 32), mload(input), add(result, 32), size)
            actualSize := returndatasize()
            if iszero(eq(actualSize, size)) { ok := 0 }
        }
    }

    function read(address target, bytes memory input, uint256 size, uint256 cap)
        internal
        view
        returns (bytes memory result)
    {
        (bool ok,, bytes memory raw) = tryRead(target, input, size, cap);
        if (!ok) revert FinalityReadFailed(target);
        return raw;
    }

    function supportsOptional(address target, bytes4 id, uint256 cap) internal view returns (bool) {
        bytes memory input = abi.encodeCall(IERC165.supportsInterface, (id));
        uint256 budget = cap < 30000 ? cap : 30000;
        if (gasleft() <= budget + budget / 63 + PARENT_RESERVE) revert FinalityReadFailed(target);
        bytes memory result = new bytes(32);
        bool ok;
        uint256 size;
        uint256 supported;
        assembly ("memory-safe") {
            ok := staticcall(budget, target, add(input, 32), mload(input), add(result, 32), 32)
            size := returndatasize()
            supported := mload(add(result, 32))
        }
        // Older pinned implementations can have no capability method. Once advertised,
        // execution failure is terminal and cannot fall back to a different validation path.
        if (!ok || size == 0) return false;
        if (size != 32 || supported > 1) revert FinalityCapabilityMalformed(target);
        return supported == 1;
    }
}
