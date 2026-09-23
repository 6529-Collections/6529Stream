// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistArchiveOriginTypes as O } from "./StreamArtistArchiveOriginTypes.sol";

/// @notice Facts admitted by the fixed typed inventory, never caller-enrolled Archive targets.
interface IStreamArtistArchiveOriginInventory {
    function originDependencies() external view returns (O.Dependencies memory);
    function originProfile() external view returns (bytes32);
    function artistArchiveOrigin(bytes32 planId, bytes32 itemHash)
        external
        view
        returns (O.RecordOrigin memory);
    function originCount(bytes32 planId) external view returns (uint256);
    function originAt(bytes32 planId, uint256 index) external view returns (O.Origin memory);
    /// @notice Nonzero only for a sealed complete inventory, committing exact count and order.
    function originSetHash(bytes32 planId) external view returns (bytes32);
}
