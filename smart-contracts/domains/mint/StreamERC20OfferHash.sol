// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import {
    StreamERC20OfferMintTypes as Offer
} from "../../interfaces/stream/mint/StreamERC20OfferMintTypes.sol";
import {
    StreamPrivateSaleTypes as Sales
} from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import { StreamMintTicketHash } from "./StreamMintTicketHash.sol";
import {
    StreamPreparedNativeContentHash as ContentHash
} from "./StreamPreparedNativeContentHash.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";

/// @notice Canonical full-payload validation and digests for one direct-to-buyer ERC20 offer mint.
/// @dev Signature authority, delegation, replay consumption and payment effects remain with callers.
library StreamERC20OfferHash {
    error InvalidERC20Offer();

    bytes32 private constant _PRIMARY_SALE = keccak256("PRIMARY_SALE");
    bytes32 private constant _RECIPIENTS = keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1");
    bytes32 private constant _BENEFICIARIES = keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1");
    bytes32 private constant _TOKEN_DATA = keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1");
    bytes32 private constant _COMMITMENTS = keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1");

    /// @notice Validate the complete original seller and buyer presentation and return both
    /// full Sales EIP-712 digests. The buyer digest is the Manager ticket replay authority.
    function validate(
        address manager,
        address house,
        IStreamMintManager.MintBatch calldata batch,
        Offer.GateData memory d
    ) public view returns (bytes32 sellerDigest, bytes32 offerDigest) {
        Sales.SaleAuthorization memory authorization = d.authorization;
        Sales.SaleOffer memory offer = d.offer;
        sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid, house, StreamPrivateSaleHash.authorizationBody(authorization)
        );
        offerDigest = StreamPrivateSaleHash.digest(
            block.chainid, house, StreamPrivateSaleHash.offerBody(offer)
        );
        _requireOriginal(manager, house, d, authorization, offer);
        _requireBatch(house, batch, d, authorization, offer, sellerDigest, offerDigest);
    }

    function _requireOriginal(
        address manager,
        address house,
        Offer.GateData memory d,
        Sales.SaleAuthorization memory authorization,
        Sales.SaleOffer memory offer
    ) private view {
        if (
            manager == address(0) || house == address(0) || d.executor == address(0)
                || offer.buyer == address(0) || offer.buyer == house
                || authorization.chainId != block.chainid || offer.chainId != block.chainid
                || authorization.saleAdapter != house || offer.saleAdapter != house
                || authorization.mintManager != manager
                || offer.core != address(IStreamMintReads(manager).core())
                || authorization.collectionId == 0
                || authorization.collectionId != offer.collectionId || authorization.phaseId == 0
                || authorization.saleId == 0 || authorization.saleKind != 6
                || authorization.revenueClass != _PRIMARY_SALE
                || authorization.expectedPrimaryPolicyHash == 0
                || authorization.primaryPolicyMode != 0 || authorization.payer != offer.buyer
                || authorization.executor != d.executor || authorization.asset == address(0)
                || authorization.asset != offer.asset || authorization.unitPrice == 0
                || authorization.unitPrice != offer.price || authorization.quantity != 1
                || authorization.contentSelectionHash != offer.contentSelectionHash
                || authorization.policyHash == 0 || authorization.nonce == 0
                || authorization.deadline < block.timestamp || authorization.finalizeBy != 0
                || offer.tokenId != 0 || offer.nonce == 0 || offer.deadline < block.timestamp
                || offer.finalizeBy != 0
        ) revert InvalidERC20Offer();
    }

    function _requireBatch(
        address house,
        IStreamMintManager.MintBatch calldata batch,
        Offer.GateData memory d,
        Sales.SaleAuthorization memory authorization,
        Sales.SaleOffer memory offer,
        bytes32 sellerDigest,
        bytes32 offerDigest
    ) private view {
        if (
            batch.collectionId != offer.collectionId
                || batch.collectionId != authorization.collectionId
                || batch.phaseId != authorization.phaseId || batch.payer != offer.buyer
                || batch.authorizer != d.buyerSignature.authorizer
                || d.buyerSignature.authorizer == address(0)
                || (d.buyerSignature.kind != 1 && d.buyerSignature.kind != 2)
                || batch.expectedPolicyHash != authorization.policyHash
                || batch.authorizationId != StreamMintTicketHash.authorizationId(offerDigest)
                || batch.initialRecipients.length != 1 || batch.beneficiaries.length != 1
                || batch.tokenData.length != 1 || batch.mintCommitments.length != 1
                || batch.initialRecipients[0] != offer.buyer
                || batch.beneficiaries[0] != offer.buyer || batch.mintCommitments[0] == 0
                || authorization.initialRecipientsHash
                    != keccak256(abi.encode(_RECIPIENTS, batch.initialRecipients))
                || authorization.beneficiariesHash
                    != keccak256(abi.encode(_BENEFICIARIES, batch.beneficiaries))
                || authorization.tokenDataArrayHash
                    != keccak256(abi.encode(_TOKEN_DATA, batch.tokenData))
                || authorization.mintCommitmentsHash
                    != keccak256(abi.encode(_COMMITMENTS, batch.mintCommitments))
        ) revert InvalidERC20Offer();
        _requireContent(house, batch, d, authorization, sellerDigest);
    }

    function _requireContent(
        address house,
        IStreamMintManager.MintBatch calldata batch,
        Offer.GateData memory d,
        Sales.SaleAuthorization memory authorization,
        bytes32 sellerDigest
    ) private view {
        if (authorization.contentSelectionHash == 0) {
            if (
                d.selection.contentId != 0 || d.selection.tokenDataHash != 0
                    || d.selection.proof.length != 0 || sellerDigest == 0
                    || batch.contextHash != sellerDigest
            ) revert InvalidERC20Offer();
            return;
        }
        if (
            d.selection.tokenDataHash == 0
                || d.selection.tokenDataHash != keccak256(batch.tokenData[0])
                || batch.contextHash
                    != ContentHash.context(
                        block.chainid, house, authorization.saleId, d.selection.contentId
                    )
                || authorization.contentSelectionHash
                    != ContentHash.leaf(
                        block.chainid,
                        house,
                        authorization.saleId,
                        d.selection.contentId,
                        d.selection.tokenDataHash
                    )
        ) revert InvalidERC20Offer();
    }
}
