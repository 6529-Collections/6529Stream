// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorComposition as C
} from "./StreamArtistPrimaryCollaboratorComposition.sol";

/// @notice Complete original eager typed decode and canonical re-encoding at a fixed compiler boundary.
library StreamArtistPrimaryCollaboratorCompositionContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        C.Context memory value = abi.decode(raw, (C.Context));
        return abi.encode(value);
    }
}
