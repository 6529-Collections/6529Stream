// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Identity registration and replay owned by Identity, including the persistent pre-registration account lane.
interface IStreamArtistCollaboratorIdentityOwner {
    function collaboratorRegistrationNonceState(address account, uint256 nonce)
        external
        view
        returns (bool, uint256);
    function registerCollaboratorIdentity(
        T.ActionContext calldata context,
        C.IdentityProposal calldata proposal,
        T.Authorization calldata authorization,
        T.SignerApproval calldata proof,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
    function consumeCollaboratorAcceptance(
        T.ActionContext calldata context,
        C.BindingAcceptance calldata acceptance,
        bytes32 artistId,
        T.Authorization calldata authorization,
        T.SignerApproval calldata proof
    ) external returns (bytes32);
}
