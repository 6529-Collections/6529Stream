// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPreparedNativeContentTypes.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "./IStreamNativeRefundDelegatedClaims.sol";

/// @notice Additive primary-offer admission. Existing content-purchase wire structs stay unchanged.
library StreamPreparedNativeOfferTypes {
    struct Purchase {
        bytes32 saleId;
        uint256 saleNonce;
        bytes32 saleConfigHash;
        bytes32 purchaseId;
        address buyer;
        uint256 purchaseNonce;
        bytes32 authorizationId;
        address authorizer;
        uint8 authorizerKind;
        uint8 primaryPolicyMode;
        bytes32 offerDigest;
    }

    struct GateData {
        bytes32 intentHash;
        bytes32 authorizationId;
        StreamPreparedNativeContentTypes.Selection selection;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerSignature;
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerSignature;
        IStreamNativeRefundDelegatedClaims.DelegationWitness buyerDelegation;
    }
}
