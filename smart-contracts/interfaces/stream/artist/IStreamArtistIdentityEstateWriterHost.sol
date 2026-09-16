// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice The Identity owner's constructor-fixed second writer, used by retained child1 callbacks.
interface IStreamArtistIdentityEstateWriterHost {
    function identityEstateExtension() external view returns (address);
}
