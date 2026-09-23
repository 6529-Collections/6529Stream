// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {
    StreamRenderCriticalSourceTypes as S
} from "../../interfaces/stream/preservation/StreamRenderCriticalSourceTypes.sol";
import {
    StreamScopedPolicyRenderCriticalInventoryV2 as Child
} from "../preservation/StreamScopedPolicyRenderCriticalInventoryV2.sol";

/// @notice Fixed delegate-host CREATE from the original typed constructor arguments.
library StreamScopedPolicyPublicationInventoryConstructorV2 {
    function deploy(S.Dependencies memory d) public returns (address) {
        return address(new Child(d));
    }
}
