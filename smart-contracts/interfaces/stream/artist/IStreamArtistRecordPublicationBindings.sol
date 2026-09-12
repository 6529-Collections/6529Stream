// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Actual canonical metadata host's reciprocal Core binding.
interface IStreamArtistRecordPublicationBindings {
    function core() external view returns (address);
}
