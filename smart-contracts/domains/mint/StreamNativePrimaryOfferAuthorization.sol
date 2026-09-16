// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleSupport.sol";
import "./StreamMintTicketHash.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";

/// @notice Canonical dual-digest authorization for one native primary offer mint.
/// @dev The guarded host consumes the seller digest before calling this linked proof helper.
/// Manager/Ledger consume the ticket-wrapped offer digest. The host separately validates its
/// immutable terms, current admission, Artist consent, exact content proof and live delegation
/// when the claimed buyer signer differs from the buyer. No replay or authority is stored here.
library StreamNativePrimaryOfferAuthorization {
    struct Context {
        address core;
        address manager;
        uint256 signatureGas;
    }

    struct Terms {
        bytes32 saleId;
        uint256 collectionId;
        bytes32 phaseId;
        address buyer;
        uint256 price;
        uint64 startsAt;
        uint64 deadline;
        bytes32 selectedLeaf;
        bytes32 mintPolicyHash;
        uint8 primaryPolicyMode;
        bytes32 expectedPrimaryPolicyHash;
        address seller;
        uint8 sellerKind;
        bytes32 expectedOfferDigest;
    }

    error InvalidPrimaryOfferTerms();
    error InvalidPrimaryOfferAuthorization();
    error InvalidPrimaryOffer();
    error InvalidPrimaryOfferBatch();
    error PrimaryOfferSignerNotAuthorized(address authorizer, uint8 kind);
    error PrimaryOfferSignatureInvalid(address authorizer);
    error PrimaryOfferLedgerIdMismatch(bytes32 expected, bytes32 actual);

    function validate(
        Context memory context,
        Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamPrivateSaleAdapter.Signature memory sellerProof,
        StreamPrivateSaleTypes.SaleOffer memory offer,
        IStreamPrivateSaleAdapter.Signature memory buyerProof,
        IStreamMintManager.MintBatch memory batch
    ) public view returns (bytes32 sellerDigest, bytes32 offerDigest, bytes32 authorizationId) {
        if (
            context.core == address(0) || context.manager == address(0) || context.signatureGas == 0
                || context.signatureGas > type(uint64).max || terms.saleId == 0
                || terms.collectionId == 0 || terms.phaseId == 0 || terms.buyer == address(0)
                || terms.buyer == address(this) || terms.price == 0
                || terms.deadline <= terms.startsAt || terms.mintPolicyHash == 0
                || terms.primaryPolicyMode != 0 || terms.expectedPrimaryPolicyHash == 0
                || terms.seller == address(0) || (terms.sellerKind != 1 && terms.sellerKind != 2)
                || terms.expectedOfferDigest == 0
        ) revert InvalidPrimaryOfferTerms();
        if (
            block.timestamp < terms.startsAt || block.timestamp > terms.deadline
                || authorization.chainId != block.chainid
                || authorization.saleAdapter != address(this)
                || authorization.mintManager != context.manager
                || authorization.collectionId != terms.collectionId
                || authorization.phaseId != terms.phaseId || authorization.saleId != terms.saleId
                || authorization.saleKind != 6
                || authorization.revenueClass != keccak256("PRIMARY_SALE")
                || authorization.expectedPrimaryPolicyHash != terms.expectedPrimaryPolicyHash
                || authorization.primaryPolicyMode != terms.primaryPolicyMode
                || authorization.payer != terms.buyer || authorization.executor != msg.sender
                || authorization.asset != address(0) || authorization.unitPrice != terms.price
                || authorization.quantity != 1
                || authorization.contentSelectionHash != terms.selectedLeaf
                || authorization.policyHash != terms.mintPolicyHash || authorization.nonce == 0
                || authorization.deadline < block.timestamp
                || authorization.deadline > terms.deadline || authorization.finalizeBy != 0
        ) revert InvalidPrimaryOfferAuthorization();
        if (
            offer.chainId != block.chainid || offer.saleAdapter != address(this)
                || offer.core != context.core || offer.collectionId != terms.collectionId
                || offer.tokenId != 0 || offer.contentSelectionHash != terms.selectedLeaf
                || offer.buyer != terms.buyer || offer.asset != address(0)
                || offer.price != terms.price || offer.nonce == 0
                || offer.deadline < block.timestamp || offer.finalizeBy != 0
        ) revert InvalidPrimaryOffer();
        _requireBatch(terms, authorization, batch, buyerProof.authorizer);
        if (sellerProof.authorizer != terms.seller || sellerProof.kind != terms.sellerKind) {
            revert PrimaryOfferSignerNotAuthorized(sellerProof.authorizer, sellerProof.kind);
        }
        if (buyerProof.authorizer == address(0) || (buyerProof.kind != 1 && buyerProof.kind != 2)) {
            revert PrimaryOfferSignerNotAuthorized(buyerProof.authorizer, buyerProof.kind);
        }
        sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(authorization)
        );
        offerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(offer)
        );
        if (offerDigest != terms.expectedOfferDigest) revert InvalidPrimaryOffer();
        authorizationId = StreamMintTicketHash.authorizationId(offerDigest);
        if (batch.authorizationId != authorizationId) {
            revert PrimaryOfferLedgerIdMismatch(authorizationId, batch.authorizationId);
        }
        if (!StreamPrivateSaleSupport.validSignature(
                sellerProof.authorizer,
                sellerProof.kind,
                sellerDigest,
                sellerProof.signature,
                context.signatureGas
            )) revert PrimaryOfferSignatureInvalid(sellerProof.authorizer);
        if (!StreamPrivateSaleSupport.validSignature(
                buyerProof.authorizer,
                buyerProof.kind,
                offerDigest,
                buyerProof.signature,
                context.signatureGas
            )) revert PrimaryOfferSignatureInvalid(buyerProof.authorizer);
    }

    function _requireBatch(
        Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamMintManager.MintBatch memory batch,
        address offerSigner
    ) private view {
        if (
            batch.collectionId != terms.collectionId || batch.phaseId != terms.phaseId
                || batch.authorizer != offerSigner || batch.payer != terms.buyer
                || batch.expectedPolicyHash != terms.mintPolicyHash || batch.contextHash == 0
                || batch.initialRecipients.length != 1 || batch.beneficiaries.length != 1
                || batch.tokenData.length != 1 || batch.mintCommitments.length != 1
        ) revert InvalidPrimaryOfferBatch();
        if (
            batch.initialRecipients[0] != address(this) || batch.beneficiaries[0] != terms.buyer
                || batch.mintCommitments[0] == 0
                || authorization.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"),
                            batch.initialRecipients
                        )
                    )
                || authorization.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), batch.beneficiaries
                        )
                    )
                || authorization.tokenDataArrayHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), batch.tokenData
                        )
                    )
                || authorization.mintCommitmentsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), batch.mintCommitments
                        )
                    )
        ) revert InvalidPrimaryOfferBatch();
    }
}
