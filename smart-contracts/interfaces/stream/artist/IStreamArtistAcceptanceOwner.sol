// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed AcceptanceLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistAcceptanceOwner is IStreamArtistOwner {
    function acceptanceRecord(bytes32 bindingHash) external view returns (bytes32);

    function acceptedAt(bytes32 bindingHash) external view returns (uint64);

    function recordAcceptance(
        T.ActionContext calldata c,
        uint256 collectionId,
        T.Binding calldata b,
        address signer,
        uint256 nonce
    ) external returns (bytes32 record);
}
