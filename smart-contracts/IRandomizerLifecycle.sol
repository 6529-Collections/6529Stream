// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

interface IRandomizerLifecycle {
    function supportsRandomizerLifecycle() external view returns (bool);

    function pendingRandomnessRequests(uint256 collectionId) external view returns (uint256);

    function totalPendingRandomnessRequests() external view returns (uint256);
}
