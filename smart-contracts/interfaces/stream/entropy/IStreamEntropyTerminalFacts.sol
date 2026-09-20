// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../../vendor/openzeppelin/IERC165.sol";
import "./IStreamEntropyCollectionPolicy.sol";

/// @notice Direct-storage facts for transitive STATIC consumers; no linked or external reads.
/// @dev Consumers verify collection/coordinator identity against original Core and admit status.
interface IStreamEntropyTerminalFacts is IERC165 {
    function staticTerminalEntropyFacts(uint256 tokenId)
        external
        view
        returns (
            uint256 collectionId,
            IStreamEntropyCollectionPolicy.PolicyRecord memory policy,
            uint8 status,
            bytes32 seed,
            bytes32 requestKey
        );
}
