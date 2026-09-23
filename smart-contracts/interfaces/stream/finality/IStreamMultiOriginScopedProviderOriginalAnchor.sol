// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IStreamMultiOriginScopedProviderOriginalAnchor {
    function requireCurrentRouterCandidate(uint256 collectionId, address registry) external view;
}
