// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamExternalArtifactCurrentPair
} from "../../../smart-contracts/interfaces/stream/preservation/IStreamExternalArtifactCurrentPair.sol";

contract ScopedPolicyReferenceExternalBoundaryV2 {
    address public immutable core;

    constructor(address value) {
        core = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamExternalArtifactCurrentPair).interfaceId;
    }
}
