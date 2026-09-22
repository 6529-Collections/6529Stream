// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamArtistPrimaryCollaboratorSourceProof as C
} from "./StreamArtistPrimaryCollaboratorSourceProof.sol";

/// @notice Complete original eager typed decode and canonical re-encoding at a fixed compiler boundary.
library StreamArtistPrimaryCollaboratorSourceContext {
    function canonical(bytes calldata raw) public pure returns (bytes memory) {
        C.Result memory value = abi.decode(raw, (C.Result));
        return abi.encode(value);
    }
}
