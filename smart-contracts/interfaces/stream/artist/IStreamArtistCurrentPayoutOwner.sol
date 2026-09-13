// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamArtistPayoutResolutionOwner.sol";

/// @notice Coordinator-snapshotted current authority and exact transition closure facts for18.
interface IStreamArtistCurrentPayoutOwner {
    function recordDesignationWithAuthority(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition,
        Dismissal.PayoutResolutionFacts calldata resolution,
        R.AuthorityFact calldata authority
    ) external returns (bytes32);
}
