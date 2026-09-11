// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Exactly one authoritative attribution transition when the final required collaborator accepts.
interface IStreamArtistCollaboratorAttributionOwner {
    function completeCollaboratorBinding(
        T.ActionContext calldata context,
        uint256 collectionId,
        T.Binding calldata binding,
        bytes32 record,
        address signer
    ) external;
}
