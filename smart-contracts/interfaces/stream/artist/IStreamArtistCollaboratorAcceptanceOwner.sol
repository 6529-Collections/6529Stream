// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Canonical collaborator acceptance records, replay and event ownership.
interface IStreamArtistCollaboratorAcceptanceOwner {
    function recordCollaboratorAcceptance(
        T.ActionContext calldata context,
        C.BindingAcceptance calldata acceptance,
        bytes32 artistId,
        uint256 nonce
    ) external returns (bytes32);
    function collaboratorAcceptanceRecord(
        bytes32 bindingHash,
        address account,
        bytes32 role,
        bytes32 shareLabelId
    ) external view returns (bytes32);
}
