// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "./IStreamPrivateSaleAdapter.sol";
import "./IStreamPrivateSaleDelegatedClaims.sol";
import "./StreamPrivateSaleTypes.sol";

/// @notice A live delegate may sign the original buyer's offer, without payment or custody authority.
interface IStreamPrivateSaleDelegatedOffers {
    function acceptDelegatedOffer(
        StreamPrivateSaleTypes.SaleAuthorization calldata authorization,
        IStreamPrivateSaleAdapter.Signature calldata sellerProof,
        StreamPrivateSaleTypes.SaleOffer calldata offer,
        IStreamPrivateSaleAdapter.Signature calldata delegateProof,
        StreamPrivateSaleTypes.SaleCustodyGrant calldata ownerGrant,
        uint8 ownerKind,
        bytes calldata ownerSignature,
        IStreamPrivateSaleDelegatedClaims.DelegationWitness calldata witness
    ) external payable;
}
