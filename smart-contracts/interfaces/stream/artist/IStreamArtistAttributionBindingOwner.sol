// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamArtistOnboardingTypes as T } from "./StreamArtistOnboardingTypes.sol";
import { StreamArtistBindingLifecycleTypes as L } from "./StreamArtistBindingLifecycleTypes.sol";

/// @notice Attribution's typed CLAIMED→REVOKED transitions; actual records/replay stay with their owning domains.
interface IStreamArtistAttributionBindingOwner {
    function recordRefusal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p,
        address signer,
        uint256 nonce,
        bytes32 record
    ) external;
    function recordWithdrawal(
        T.ActionContext calldata c,
        T.Binding calldata b,
        L.Termination calldata p
    ) external;
}
