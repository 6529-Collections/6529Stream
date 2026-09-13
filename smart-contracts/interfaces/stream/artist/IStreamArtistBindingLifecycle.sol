// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";

/// @notice Artist refusal and proposer withdrawal of never-accepted proposals, with exact queued-call binding.
interface IStreamArtistBindingLifecycle {
    function refuseArtistBinding(L.Termination calldata p, T.Authorization calldata a)
        external
        returns (bytes32);
    /// @notice Only the stored proposer may withdraw; its later role membership does not transfer this right.
    function withdrawArtistBinding(L.Termination calldata p) external;
    function bindingRefusalDigest(L.Termination calldata p, T.Authorization calldata a)
        external
        view
        returns (bytes32);
    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        returns (L.Terminal memory);
    /// @notice Pins the exact proposal before direct or relayed acceptance; required for direct generations after1.
    function acceptArtistBindingExpected(
        uint256 collectionId,
        uint64 expectedGeneration,
        bytes32 expectedBindingHash,
        T.Authorization calldata a
    ) external returns (bytes32);
}
