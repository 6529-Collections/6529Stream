// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamTokenProfileCustodyTypes.sol";

library StreamTokenProfileCustodyState {
    struct State {
        mapping(bytes32 => StreamTokenProfileCustodyTypes.Activation) activations;
        mapping(address => mapping(bytes32 => bool)) nonceUsed;
    }
}
