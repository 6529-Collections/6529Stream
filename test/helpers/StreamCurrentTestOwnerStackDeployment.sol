// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCurrentOwnerCaptureFixture,
    StreamCurrentStackFixture
} from "./StreamCurrentOwnerCaptureFixture.sol";

interface IStreamCurrentTestOwnerStackDeployment {
    function deployCurrentStack(address artist_, address platform) external;
}

/// @dev Created by the original Owner host through genuine artifact CREATE, then delegatecalled.
/// Inheritance preserves the original deployment storage prefix and virtual hook resolution.
/// No fixture state is copied; all original product calls and CREATEs run in the host context.
contract StreamCurrentTestOwnerStackDeployment is
    StreamCurrentOwnerCaptureFixture,
    IStreamCurrentTestOwnerStackDeployment
{
    address private immutable _deploymentHost = msg.sender;

    function deployCurrentStack(address artist_, address platform) external override {
        require(address(this) == _deploymentHost, "original Owner host delegatecall required");
        StreamCurrentStackFixture._deployCurrentStack(artist_, platform);
    }
}
