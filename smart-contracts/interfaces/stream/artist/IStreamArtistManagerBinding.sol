// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamArtistManagerBinding {
    function core() external view returns (address);
    function moduleRegistry() external view returns (address);
    function governanceAuthority() external view returns (address);
}
