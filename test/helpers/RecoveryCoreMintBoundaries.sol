// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamCoreMint } from "../../smart-contracts/interfaces/stream/core/IStreamCoreMint.sol";
import {
    IStreamMintManager
} from "../../smart-contracts/interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamEntropyCoordinator
} from "../../smart-contracts/interfaces/stream/entropy/IStreamEntropyCoordinator.sol";

/// @dev Explicit admission boundary only. Core performs actual allocation/completion/ownership.
contract RecoveryCoreMintBoundary {
    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x01ffc9a7 || id == type(IStreamMintManager).interfaceId;
    }

    function mint(address core, uint256 collectionId, address recipient)
        external
        returns (uint256 id)
    {
        (id,) = IStreamCoreMint(core)
            .mintFromManager(
                collectionId,
                recipient,
                bytes("actual Core token"),
                keccak256("actual Core token"),
                keccak256("explicit mint admission boundary")
            );
    }
}

/// @dev Actual Core callback transport; entropy creation and readiness are outside this fixture.
contract RecoveryCoreEntropyBoundary {
    address public immutable core;
    uint256 public callbacks;

    constructor(address actualCore) {
        core = actualCore;
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
            msg.sender == core && collectionId == 7 && tokenId == callbacks + 1
                && recipient == address(0xBEEF) && commitment != 0,
            "actual Core callback"
        );
        ++callbacks;
    }
}
