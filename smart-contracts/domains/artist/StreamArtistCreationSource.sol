// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    IStreamArtistCreationSource
} from "../../interfaces/stream/artist/IStreamArtistCreationSource.sol";

/// @dev CREATE remains in the linked wrapper's original delegate-host context.
library StreamArtistCreationSource {
    function deploy(uint8 kind, bytes memory arguments) internal returns (address child) {
        bytes memory initcode = bytes.concat(
            IStreamArtistCreationSource(address(this)).extensionCreationCode(kind), arguments
        );
        assembly ("memory-safe") {
            child := create(0, add(initcode, 32), mload(initcode))
            if iszero(child) {
                let reason := mload(64)
                returndatacopy(reason, 0, returndatasize())
                revert(reason, returndatasize())
            }
        }
    }
}
