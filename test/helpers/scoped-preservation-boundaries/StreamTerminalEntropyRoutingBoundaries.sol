// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StaticRouteVersions } from "../StaticMetadataRoutingFixture.sol";
import {
    IStreamTerminalEntropyRenderer as Terminal
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamTerminalEntropyRenderer.sol";

/// @dev Explicit admitted-profile boundary for actual routing, not a substitute for the separate
/// real Registry/Schema/governed-evidence/Safe suite or real program analysis.
contract TerminalRouteVersions is StaticRouteVersions {
    address private immutable renderer;
    bool public admitted;
    bytes32 public profile = keccak256("6529STREAM_TERMINAL_ENTROPY_RENDER_V1");

    constructor(address executor, address schemas, address target)
        StaticRouteVersions(executor, schemas, target)
    {
        renderer = target;
    }

    function setAdmitted(bool value) external {
        admitted = value;
    }

    function setProfile(bytes32 value) external {
        profile = value;
    }

    function requireTerminalEntropy(bytes32 k)
        external
        view
        returns (address, bytes32, bytes32, bytes4)
    {
        require(admitted && k == key, "separate terminal admission required");
        return (renderer, renderer.codehash, profile, Terminal.renderTerminal.selector);
    }
}
