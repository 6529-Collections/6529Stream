// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";

/// @notice Typed immutable-facade routes, preserving original caller and exact proposal context.
interface IStreamArtistBindingLifecycleCoordinator {
    function coordinateRefuseArtistBinding(
        address actor,
        L.Termination calldata p,
        T.Authorization calldata a
    ) external returns (bytes32);
    function coordinateWithdrawArtistBinding(address actor, L.Termination calldata p) external;
    function coordinateAcceptArtistBindingExpected(
        address actor,
        uint256 collectionId,
        uint64 expectedGeneration,
        bytes32 expectedBindingHash,
        T.Authorization calldata a
    ) external returns (bytes32);
}
