// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/finality/IStreamFinalityCurrentComponentRoutes.sol";
import "../../vendor/openzeppelin/IERC165.sol";

/// @notice Checks the optional fixed current route projection after independent live-state checks.
/// @dev This is not a readiness check on its own. Legacy discovery retains its full existing path.
library StreamFinalityRouteReads {
    error FinalityRoutesUnreadable();
    error FinalityRoutesMismatch(uint256 index);

    function verifyIfSupported(
        address discovery,
        StreamFinalityScope memory scope,
        StreamFinalityComponentExpectation[] calldata components,
        bool includeSanction,
        uint256 cap
    ) public view returns (bool) {
        if (!_supportsRoutes(discovery, cap)) return false;
        uint256 count = includeSanction ? 10 : 9;
        if (components.length != count) revert FinalityRoutesMismatch(count);
        bytes memory result = _readRoutes(discovery, scope, includeSanction, cap, count);
        StreamFinalityCurrentComponentRoute[] memory routes =
            abi.decode(result, (StreamFinalityCurrentComponentRoute[]));
        if (routes.length != count || keccak256(result) != keccak256(abi.encode(routes))) {
            revert FinalityRoutesUnreadable();
        }
        for (uint256 i; i < count; ++i) {
            StreamFinalityCurrentComponentRoute memory route = routes[i];
            StreamFinalityComponentExpectation calldata entry = components[i];
            if (
                (i != 0 && routes[i - 1].componentType >= route.componentType)
                    || route.componentType != entry.componentType
                    || route.component != entry.component || route.interfaceId != entry.interfaceId
                    || route.codeHash != entry.codeHash
            ) {
                revert FinalityRoutesMismatch(i);
            }
        }
        // Permanent hashes still use every submitted field; strict component checks establish
        // frozen/moduleVersion/manifestHash/dataHash directly, exactly once, in Preparation.
        return true;
    }

    function _readRoutes(
        address discovery,
        StreamFinalityScope memory scope,
        bool full,
        uint256 cap,
        uint256 count
    ) private view returns (bytes memory result) {
        bytes memory input = abi.encodeCall(
            IStreamFinalityCurrentComponentRoutes.requireCurrentRoutes, (scope, full)
        );
        uint256 expectedSize = 64 + 128 * count;
        result = new bytes(expectedSize);
        uint256 available = gasleft();
        if (available <= 100000) revert FinalityRoutesUnreadable();
        // A governed read cap is an upper bound, not a requirement to reserve the entire
        // configured component budget for this cheaper identity projection.
        uint256 forwarded = available - 100000;
        if (cap < forwarded) forwarded = cap;
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(
                forwarded,
                discovery,
                add(input, 32),
                mload(input),
                add(result, 32),
                expectedSize
            )
            size := returndatasize()
        }
        if (!ok || size != expectedSize) revert FinalityRoutesUnreadable();
    }

    function _supportsRoutes(address discovery, uint256 cap) private view returns (bool) {
        bytes memory probe = abi.encodeCall(
            IERC165.supportsInterface, (type(IStreamFinalityCurrentComponentRoutes).interfaceId)
        );
        uint256 probeCap = cap < 30000 ? cap : 30000;
        if (gasleft() <= probeCap + probeCap / 63 + 100000) revert FinalityRoutesUnreadable();
        bool ok;
        uint256 size;
        uint256 supported;
        assembly ("memory-safe") {
            let out := mload(0x40)
            ok := staticcall(probeCap, discovery, add(probe, 32), mload(probe), out, 32)
            size := returndatasize()
            supported := mload(out)
        }
        // Pre-capability pinned discovery may have no ERC-165 method. A successful malformed
        // answer is never authority to choose a different validation path.
        if (!ok || size == 0) return false;
        if (size != 32 || supported > 1) revert FinalityRoutesUnreadable();
        return supported == 1;
    }
}
