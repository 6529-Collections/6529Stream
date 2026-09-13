// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { RecoveryCoreMintBoundary } from "./RecoveryCoreMintBoundaries.sol";
import { IStreamCoreMint } from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";

/// @dev Explicit mint admission boundary; all bytes are stored by the actual Core mint path.
contract RouterCoreMintBoundary is RecoveryCoreMintBoundary {
    function mintMaximum(address core, bytes calldata data) external returns (uint256 id) {
        require(data.length == 16384, "maximum supported token bytes");
        (id,) = IStreamCoreMint(core)
            .mintFromManager(
                1,
                address(0xBEEF),
                data,
                keccak256(data),
                keccak256("explicit mint admission boundary")
            );
    }
}
