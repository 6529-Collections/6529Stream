// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @dev Existing immutable Manager getters, used only to authenticate exact continuity pairs.
interface IStreamMintArtistManagerBinding {
    function core() external view returns (address);
    function mintLedger() external view returns (address);
}
