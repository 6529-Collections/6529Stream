// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Operative first-release ratification read; not authority to mutate content.
interface IStreamArtistContentRatification {
    function firstReleaseRatification(uint256 collectionId)
        external
        view
        returns (bool ratified, bytes32 contentStateHash, bytes32 ratificationRecordHash);
}
