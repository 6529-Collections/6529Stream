// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamRouterLiveFrame {
    function liveAttributionObject(uint256 collectionId, uint256 tokenId)
        external
        view
        returns (bytes memory);
}
