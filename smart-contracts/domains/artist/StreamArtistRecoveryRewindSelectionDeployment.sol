// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistRecoveryRewindSelection } from "./StreamArtistRecoveryRewindSelection.sol";
import {
    StreamArtistRecoveryRewindTypes as W
} from "../../interfaces/stream/artist/StreamArtistRecoveryRewindTypes.sol";

library StreamArtistRecoveryRewindSelectionDeployment {
    function deploy(
        address host,
        address registry,
        address coordinator,
        address archive,
        address core,
        address manager
    ) public returns (address) {
        if (archive == address(0) || core == address(0) || manager == address(0)) {
            revert W.InvalidRecoveryRewindSelection(bytes32(0));
        }
        return address(new StreamArtistRecoveryRewindSelection(host, registry, coordinator));
    }
}
