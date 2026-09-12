// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamArtworkFinalityTypes.sol";

/// @notice The actual discovery host's ordered non-sanction projection, available before signing.
/// @dev Derives the set from authoritative scope/route inventory. It does not accept a caller's
///      list, count or readiness assertion. Each member retains the full seven-word expectation.
///      Historical recorded finality reads are independent of this current candidate projection.
interface IStreamNonSanctionFinalityDiscovery {
    /// @notice Exact current count and STREAM_FINALITY_COMPONENTS_V1 hash of the ordered set.
    /// @dev Uses the permanent component-array hash domain and ordering with ARTIST_SANCTION
    ///      entries excluded. PLATFORM_WORKS_DECLARATION remains in its ordinary projection;
    ///      prepareSanction separately rejects platform collections and declaration entries.
    ///      Unknown scopes, missing required sources and incomplete inventory revert.
    function nonSanctionDiscoveryFacts(StreamFinalityScope calldata scope)
        external
        view
        returns (uint256 componentCount, bytes32 componentsHash);

    /// @notice Exact member at an index of the same current authoritative ordered projection.
    /// @dev Reverts for an unknown scope or out-of-range index, never supplies a zero placeholder.
    function nonSanctionComponentAt(StreamFinalityScope calldata scope, uint256 index)
        external
        view
        returns (StreamFinalityComponentExpectation memory);
}
