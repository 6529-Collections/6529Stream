// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed CollaboratorLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistCollaboratorOwner is IStreamArtistOwner {
    function collaboratorSetHash() external pure returns (bytes32);

    function collaboratorCount() external pure returns (uint256);
}
