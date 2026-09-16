// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamPrivateSaleSupport } from "./StreamPrivateSaleSupport.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";
import { StreamPrivateSaleTypes } from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";
import {
    StreamERC20PrimaryOfferTypes as Offer
} from "../../interfaces/stream/mint/StreamERC20PrimaryOfferTypes.sol";

/// @notice Revocation against immutable original seller membership and the original Sales domain.
/// @dev The host recomputes the full authorization digest, loads its historical sale configuration,
/// and consumes the digest before this linked call. No live sale, provider or delegation is read.
library StreamERC20PrimaryOfferRevocation {
    error InvalidERC20PrimaryOffer();

    function validate(
        bool exists,
        address manager,
        Offer.Configuration memory c,
        StreamPrivateSaleTypes.SaleAuthorization memory a,
        IStreamPrivateSaleAdapter.Signature memory proof,
        bytes32 digest,
        uint256 signatureGas
    ) public view {
        if (
            !exists || a.chainId != block.chainid || a.saleAdapter != address(this)
                || a.mintManager != manager || a.collectionId != c.collectionId
                || a.phaseId != c.phaseId || a.saleKind != 6
                || a.revenueClass != keccak256("PRIMARY_SALE") || a.payer != c.buyer
                || c.asset == address(0) || a.asset != c.asset || a.unitPrice != c.price
                || a.quantity != 1 || a.primaryPolicyMode != c.primaryPolicyMode
                || a.expectedPrimaryPolicyHash != c.expectedPrimaryPolicyHash
                || a.policyHash != c.mintPolicyHash || a.finalizeBy != 0
                || proof.authorizer != c.signer || proof.kind != c.signerKind
                || c.signer == address(0)
        ) revert InvalidERC20PrimaryOffer();
        StreamPrivateSaleSupport.directOrSignature(
            proof.authorizer,
            proof.kind,
            StreamPrivateSaleHash.digest(
                block.chainid,
                address(this),
                StreamPrivateSaleHash.authorizationRevocationBody(
                    block.chainid, address(this), proof.authorizer, digest
                )
            ),
            proof.signature,
            signatureGas
        );
    }
}
