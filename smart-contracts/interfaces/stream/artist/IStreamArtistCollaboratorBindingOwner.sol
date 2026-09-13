// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Binding-owned immutable collaborator terms and the final collaborator completion transition.
interface IStreamArtistCollaboratorBindingOwner {
    function bindingTerms(uint256 collectionId, uint64 generation)
        external
        view
        returns (C.BindingTerms memory);
    function collaboratorTerm(uint256 collectionId, uint64 generation, uint256 index)
        external
        view
        returns (T.CollaboratorRecord memory);
    function completeCollaboratorBinding(
        T.ActionContext calldata context,
        uint256 collectionId,
        bytes32 bindingHash,
        bytes32 record
    ) external;
}
