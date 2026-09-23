// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeContentTypes.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "./IStreamNativeRefundDelegatedClaims.sol";

/// @notice Full original offer authorities for the atomic, direct-to-buyer ERC20 mint profile.
library StreamERC20OfferMintTypes {
    struct GateData {
        address executor;
        StreamPreparedNativeContentTypes.Selection selection;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerSignature;
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerSignature;
        IStreamNativeRefundDelegatedClaims.DelegationWitness buyerDelegation;
        IStreamNativeRefundDelegatedClaims.DelegationWitness executorDelegation;
    }
}
