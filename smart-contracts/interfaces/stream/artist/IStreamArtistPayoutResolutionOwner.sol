// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistPayoutTransitionOwner.sol";
import {
    StreamArtistIdentityDismissalTypes as Dismissal
} from "./StreamArtistIdentityDismissalTypes.sol";

/// @notice Typed Identity closure facts are snapshotted by the Coordinator during operation18.
interface IStreamArtistPayoutResolutionOwner {
    function recordDesignationWithResolution(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition,
        Dismissal.PayoutResolutionFacts calldata resolution
    ) external returns (bytes32);
    function payoutAbandonment(bytes32 recordHash)
        external
        view
        returns (bytes32 dismissalRecordHash);
}
