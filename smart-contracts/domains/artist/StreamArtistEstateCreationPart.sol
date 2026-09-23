// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistIdentityEstateExtension } from "./StreamArtistIdentityEstateExtension.sol";
import { StreamArtistCreationParts } from "./StreamArtistCreationParts.sol";

/// @notice Immutable STOP-prefixed fragment of this build's actual linked child initcode.
/// @dev Deploy indices zero and one separately; the Factory authenticates their complete image.
contract StreamArtistEstateCreationPart {
    constructor(uint8 index) {
        bytes memory fragment = StreamArtistCreationParts.part(
            type(StreamArtistIdentityEstateExtension).creationCode, index
        );
        assembly ("memory-safe") { return(add(fragment, 32), mload(fragment)) }
    }
}
