// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamCorePointerState
} from "../../../smart-contracts/core/StreamCoreExternalReads.sol";
import {
    IStreamMetadataRouter
} from "../../../smart-contracts/interfaces/stream/metadata/IStreamMetadataRouter.sol";

/// @dev Explicit read boundaries. Actual Core membership is independently exercised in inventory14.
contract CheckpointCoreBoundary {
    address public selected;
    address public entropy;
    uint256 public minted = 1;
    uint256 public dataLength = 32;
    bool public burned;
    bool public frozen;

    function configure(address router, address e) external {
        selected = router;
        entropy = e;
    }

    function setCount(uint256 count) external {
        minted = count;
    }

    function setBurned(bool value) external {
        burned = value;
    }

    function setFrozen(bool value) external {
        frozen = value;
    }

    function setDataLength(uint256 value) external {
        dataLength = value;
    }

    function supportsInterface(bytes4 id) external pure returns (bool) {
        return id == 0x80ac58cd;
    }

    function collectionExists(uint256 id) external pure returns (bool) {
        return id == 1;
    }

    function collectionMintedEver(uint256) external view returns (uint256) {
        return minted;
    }

    function tokenCollectionIdentity(uint256 id)
        external
        view
        returns (bool, uint256, uint256, bool)
    {
        bool exists = id > 0 && id <= minted * 2 && id % 2 == 0;
        return (exists, exists ? 1 : 0, exists ? id / 2 : 0, burned);
    }

    function tokenLifecycle(uint256) external view returns (uint8) {
        return burned ? 3 : 2;
    }

    function coordinatorAtMint(uint256) external view returns (address) {
        return entropy;
    }

    function tokenData(uint256 id) external view returns (bytes memory) {
        if (dataLength == 32) return abi.encode(id);
        return new bytes(dataLength);
    }

    function getSatellitePointer(bytes32 kind)
        external
        view
        returns (StreamCorePointerState memory p)
    {
        p = StreamCorePointerState(
            selected,
            selected.codehash,
            false,
            kind,
            type(IStreamMetadataRouter).interfaceId,
            address(this),
            1,
            keccak256("module"),
            keccak256("deployment"),
            1
        );
    }
}
