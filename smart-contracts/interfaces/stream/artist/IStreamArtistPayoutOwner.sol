// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistOwner.sol";
import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";

/// @notice Typed PayoutLifecycle owner boundary for the seven-operation onboarding profile.
/// @dev Mutations require the immutable coordinator and exact pre-operation owner snapshot.
interface IStreamArtistPayoutOwner is IStreamArtistOwner {
    function artistPayoutAccount(bytes32 artistId) external view returns (address, bytes32);

    function designationRecord(bytes32 record) external view returns (T.PayoutDesignation memory);

    function recordDesignation(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt
    ) external returns (bytes32 record);
}
