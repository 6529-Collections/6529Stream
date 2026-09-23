// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../../interfaces/stream/revenue/StreamCustodyRightsTypes.sol";

library StreamCustodyRightsState {
    struct State {
        mapping(bytes32 => StreamCustodyRightsTypes.Activation) activations;
        mapping(address => mapping(bytes32 => bool)) nonceUsed;
    }
}
