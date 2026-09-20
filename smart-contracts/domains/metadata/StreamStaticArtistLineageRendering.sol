// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamStaticArtistLineageReads as Reads } from "./StreamStaticArtistLineageReads.sol";

/// @notice Fixed STATIC calculation after the actual companion authenticates current authority.
/// @dev This worker is a projection, not an admission/authority capability on caller-supplied data.
library StreamStaticArtistLineageRendering {
    function render(bytes calldata encoded) external view returns (bytes calldata) {
        Reads.Input memory x = abi.decode(encoded, (Reads.Input));
        bytes memory encodedResult = abi.encode(Reads.render(x));
        assembly ("memory-safe") { return(add(encodedResult, 32), mload(encodedResult)) }
    }
}
