// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamArtistCreationSource {
    function extensionCreationCode(uint8 kind) external view returns (bytes memory);
}
