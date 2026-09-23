// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Constructor-created immutable bytes for one authenticated Artist suite catalogue.
/// @dev This data carrier grants no authority. Its source creates and pins the exact typed image.
contract StreamStaticArtistLineageCatalogue {
    constructor(bytes memory payload) {
        bytes memory runtime = bytes.concat(hex"00", payload);
        assembly ("memory-safe") { return(add(runtime, 32), mload(runtime)) }
    }
}
