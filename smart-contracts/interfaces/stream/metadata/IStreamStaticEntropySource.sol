// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Direct original token entropy fields for the transitive STATIC renderer read set.
/// @dev status and seed are the original TOKEN subject fields. Provider comes from the saved
/// request policy when requestKey != 0, otherwise collectionEntropyConfig[collectionId].provider.
/// There is no current-provider substitution. FINALIZED is original status code 5. Unknown tokens
/// retain the original zero subject behavior. Implement internally, without a delegatecall codec.
interface IStreamStaticEntropySource {
    function staticTokenRenderFacts(uint256 tokenId)
        external
        view
        returns (uint8 status, bytes32 seed, address provider);
}
