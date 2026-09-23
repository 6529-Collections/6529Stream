// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCuratedSaleTypes.sol";
import "./StreamPrivateSaleTypes.sol";
import "./IStreamPrivateSaleAdapter.sol";
import "./IStreamNativeRefundDelegatedClaims.sol";

/// @notice Immutable positive native primary offer terms; zero manifest selects the collection path.
library StreamNativePrimaryOfferTypes {
    struct Configuration {
        StreamNativeCuratedSaleTypes.Configuration sale;
        address buyer;
        bytes32 offerDigest;
        bytes32 contentId;
        bytes32 tokenDataHash;
        address signer;
        uint8 signerKind;
        bytes32 signerEvidenceHash;
        uint64 signerRevision;
        address signerAuthority;
    }

    struct Acceptance {
        StreamPrivateSaleTypes.SaleOffer offer;
        IStreamPrivateSaleAdapter.Signature buyerProof;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature sellerProof;
        StreamNativeCuratedSaleTypes.Selection selection;
        IStreamNativeRefundDelegatedClaims.DelegationWitness signerDelegation;
        IStreamNativeRefundDelegatedClaims.DelegationWitness executorDelegation;
    }
}
