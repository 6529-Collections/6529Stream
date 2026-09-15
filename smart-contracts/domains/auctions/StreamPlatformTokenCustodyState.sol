// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/revenue/StreamPlatformTokenCustodyTypes.sol";

library StreamPlatformTokenCustodyState {
    struct State {
        mapping(bytes32 => StreamPlatformTokenCustodyTypes.Activation) activations;
        mapping(bytes32 => bool) nonceUsed;
    }
}
