// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @notice Original RSR frozen-economic continuity surface; no pointer mutation authority.
interface IStreamRevenueResolverContinuity {
    function frozenEconomicStateHash(address core) external view returns (bytes32);
    function economicRouteHash(address core, bytes32 revenueClass, uint8 scope, uint256 scopeId)
        external
        view
        returns (bytes32);
    function supportsEconomicContinuity(
        address oldResolver,
        bytes32 oldFrozenEconomicStateHash,
        bytes32 continuityManifestHash
    ) external view returns (bool);
}
