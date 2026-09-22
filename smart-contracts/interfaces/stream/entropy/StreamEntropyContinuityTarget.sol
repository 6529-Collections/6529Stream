// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamCore
} from "../core/IStreamCore.sol";

interface StreamEntropyContinuityTarget {
    function core() external view returns (IStreamCore);
    function authority() external view returns (address);
}
