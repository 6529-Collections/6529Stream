// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed BindingLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistBindingOwner is IStreamArtistOwner {
    function binding(uint256 collectionId) external view returns (T.Binding memory);

    function bindingAt(uint256 collectionId, uint64 generation)
        external
        view
        returns (T.Binding memory);

    function propose(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 artistId,
        T.BindingProposal calldata p
    ) external returns (T.Binding memory item);

    function accept(
        T.ActionContext calldata c,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes32 acceptanceRecord
    ) external;
}
