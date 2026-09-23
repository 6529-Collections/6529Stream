// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamEntropyCoordinator
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";
import {
    StreamEntropyStatus
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyView.sol";

/// @dev Explicit entropy authority boundary; Core owns the actual callback and token lifecycle.
contract RouterCoreEntropyBoundary {
    address public immutable core;
    uint256 public callbacks;

    constructor(address core_) {
        core = core_;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamEntropyCoordinator).interfaceId;
    }

    function onTokenMinted(
        uint256 collectionId,
        uint256 tokenId,
        address recipient,
        bytes32 commitment
    ) external {
        require(
            msg.sender == core && collectionId == 1 && tokenId == 1 && callbacks == 0
                && recipient == address(0xBEEF) && commitment != 0,
            "actual Core callback"
        );
        callbacks = 1;
    }

    function tokenSeed(uint256 id) external view returns (bytes32, bool) {
        require(id == 1 && callbacks == 1, "actual minted identity");
        return (keccak256("explicit entropy boundary"), true);
    }

    function tokenEntropyStatus(uint256 id) external view returns (StreamEntropyStatus) {
        require(id == 1 && callbacks == 1, "actual minted identity");
        return StreamEntropyStatus.FINALIZED;
    }
}
