// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";

/// @notice Sole Binding owner terminal state and refusal records; only its immutable Coordinator may mutate.
interface IStreamArtistBindingTerminationOwner {
    function bindingTermination(uint256 collectionId, uint64 generation)
        external
        view
        returns (L.Terminal memory);
    function refuse(
        T.ActionContext calldata c,
        L.Termination calldata p,
        address signer,
        uint256 nonce
    ) external returns (bytes32);
    function withdraw(T.ActionContext calldata c, L.Termination calldata p) external;
}
