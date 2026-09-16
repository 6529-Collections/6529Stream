// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IStreamArtistRotation.sol";

/// @notice Payout record facts for composition with Identity's actual transition state.
interface IStreamArtistPayoutTransitionOwner {
    function payoutDesignationProvisionalAssociation(bytes32 recordHash)
        external
        view
        returns (R.ProvisionalAssociation memory);
    function payoutCandidates(bytes32 artistId)
        external
        view
        returns (
            T.Payout memory stable,
            T.Payout memory candidate,
            R.ProvisionalAssociation memory association
        );
    function recordDesignationWithTransition(
        T.ActionContext calldata c,
        T.PayoutDesignation calldata p,
        address signer,
        uint256 nonce,
        uint64 signedAt,
        R.TransitionState calldata currentTransition,
        R.TransitionState calldata candidateTransition
    ) external returns (bytes32);
}
