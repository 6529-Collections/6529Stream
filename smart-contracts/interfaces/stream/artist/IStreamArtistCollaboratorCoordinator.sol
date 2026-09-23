// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import { StreamArtistCollaboratorTypes as C } from "./StreamArtistCollaboratorTypes.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Fixed ingress routes preserving the original actor and owner snapshot/commit boundaries.
interface IStreamArtistCollaboratorCoordinator {
    function coordinateProposeCollaboratorIdentity(
        address actor,
        C.IdentityProposal calldata proposal
    ) external returns (bytes32);
    function coordinateAcceptCollaboratorIdentity(
        address actor,
        address account,
        bytes32 identityRecordHash,
        T.Authorization calldata authorization,
        bytes calldata document,
        string calldata displayName
    ) external returns (bytes32);
    function coordinateAcceptCollaborator(
        address actor,
        C.BindingAcceptance calldata acceptance,
        T.Authorization calldata authorization
    ) external returns (bytes32);
}
