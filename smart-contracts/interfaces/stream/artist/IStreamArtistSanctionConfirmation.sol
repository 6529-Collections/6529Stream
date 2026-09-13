// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import {
    StreamArtistSanctionConfirmationTypes as Confirmation
} from "./StreamArtistSanctionConfirmationTypes.sol";

/// @notice Permissionless elevation from accepted attribution using immutable executed collection history.
interface IStreamArtistSanctionConfirmation {
    function confirmSanctionFinalized(uint256 collectionId) external;
}

interface IStreamArtistSanctionConfirmationCoordinator {
    function coordinateConfirmSanctionFinalized(address actor, uint256 collectionId) external;
}

interface IStreamArtistConsentConfirmationOwner {
    function consumeSanctionFinalization(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        Confirmation.Transition calldata transition
    ) external returns (bytes32 replayKey);
}

interface IStreamArtistAttributionConfirmationOwner {
    function confirmSanctionFinalized(
        T.ActionContext calldata context,
        T.Binding calldata binding_,
        Confirmation.Transition calldata transition,
        address savedSigner,
        uint8 savedAuthorityClass
    ) external;
}
