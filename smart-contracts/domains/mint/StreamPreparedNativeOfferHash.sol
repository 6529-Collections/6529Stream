// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    IStreamPreparedNativeOfferSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeOfferMint.sol";
import {
    StreamPreparedNativeOfferTypes as Offer
} from "../../interfaces/stream/mint/StreamPreparedNativeOfferTypes.sol";
import {
    StreamPreparedNativeContentTypes as Content
} from "../../interfaces/stream/mint/StreamPreparedNativeContentTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import { IStreamMintReads } from "../../interfaces/stream/mint/IStreamMintReads.sol";
import { StreamPrivateSaleTypes } from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import { StreamPrivateSaleHash } from "./StreamPrivateSaleHash.sol";
import { StreamMintTicketHash } from "./StreamMintTicketHash.sol";

/// @notice Original buyer offer replay key and seller authorization under a distinct offer admission.
library StreamPreparedNativeOfferHash {
    error InvalidPreparedNativeOffer();

    function purchaseId(address house, bytes32 saleId, address buyer, uint256 nonce)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_SALE_PURCHASE_V1"), block.chainid, house, saleId, buyer, nonce
            )
        );
    }

    function intentHash(address house, address recorder, Prepared.Intent memory intent)
        internal
        view
        returns (bytes32)
    {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_OFFER_INTENT_V1"),
                block.chainid,
                house,
                recorder,
                intent
            )
        );
    }

    function admissionHash(
        address house,
        bytes32 hash,
        Offer.Purchase memory purchase,
        Content.Facts memory content
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_OFFER_ADMISSION_V1"),
                block.chainid,
                house,
                hash,
                purchase,
                content
            )
        );
    }

    function readPurchase(address house, bytes32 hash, Prepared.Intent memory i)
        public
        view
        returns (Offer.Purchase memory p)
    {
        bytes memory input = abi.encodeCall(
            IStreamPreparedNativeOfferSale.activePreparedNativeOfferPurchase, (hash)
        );
        bytes memory raw = new bytes(352);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), house, add(input, 32), mload(input), add(raw, 32), 352)
            size := returndatasize()
        }
        if (!ok || size != 352) revert InvalidPreparedNativeOffer();
        p = abi.decode(raw, (Offer.Purchase));
        if (
            keccak256(raw) != keccak256(abi.encode(p)) || hash == 0 || house == address(0)
                || p.saleId == 0 || p.saleId != i.saleId || p.saleNonce == 0
                || p.saleNonce != i.saleNonce || p.saleConfigHash == 0 || p.buyer == address(0)
                || p.buyer != i.payer || p.buyer != i.beneficiary || p.purchaseNonce == 0
                || p.purchaseNonce != i.executionNonce
                || p.purchaseId != purchaseId(house, p.saleId, p.buyer, p.purchaseNonce)
                || p.primaryPolicyMode != 0 || i.primaryPolicyMode != 0 || i.authorityMode != 1
                || i.amount == 0 || i.saleAuthorizationDigest == 0 || p.offerDigest == 0
                || p.authorizationId != StreamMintTicketHash.authorizationId(p.offerDigest)
                || p.authorizer == address(0) || (p.authorizerKind != 1 && p.authorizerKind != 2)
        ) revert InvalidPreparedNativeOffer();
    }

    /// @dev Also used by the selected gate, which independently authenticates both full digests.
    function requirePresentation(
        address manager,
        address house,
        Offer.GateData memory d,
        Offer.Purchase memory p,
        Prepared.Intent memory i
    ) public view {
        StreamPrivateSaleTypes.SaleAuthorization memory a = d.authorization;
        StreamPrivateSaleTypes.SaleOffer memory o = d.offer;
        bytes32 sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid, house, StreamPrivateSaleHash.authorizationBody(a)
        );
        bytes32 buyerDigest =
            StreamPrivateSaleHash.digest(block.chainid, house, StreamPrivateSaleHash.offerBody(o));
        if (
            i.authorityMode != 1 || i.primaryPolicyMode != 0 || i.amount == 0 || i.payer != p.buyer
                || i.beneficiary != p.buyer || d.authorizationId != p.authorizationId
                || p.primaryPolicyMode != 0 || p.offerDigest != buyerDigest
                || p.authorizationId != StreamMintTicketHash.authorizationId(buyerDigest)
                || sellerDigest != i.saleAuthorizationDigest
                || d.buyerSignature.authorizer != p.authorizer
                || d.buyerSignature.kind != p.authorizerKind || a.chainId != block.chainid
                || a.saleAdapter != house || a.mintManager != manager
                || a.collectionId != i.collectionId || a.phaseId != i.phaseId
                || a.saleId != p.saleId || a.saleKind != 6
                || a.revenueClass != keccak256("PRIMARY_SALE")
                || a.expectedPrimaryPolicyHash != i.originalPrimaryPolicyHash
                || a.primaryPolicyMode != 0 || a.payer != p.buyer || a.executor != i.executor
                || a.asset != address(0) || a.unitPrice != i.amount || a.quantity != 1
                || a.contentSelectionHash != i.contentSelectionHash
                || a.policyHash != i.boundMintPolicyHash || a.nonce == 0
                || a.deadline < block.timestamp || a.finalizeBy != 0 || o.chainId != block.chainid
                || o.saleAdapter != house || o.core != address(IStreamMintReads(manager).core())
                || o.collectionId != i.collectionId || o.tokenId != 0 || o.buyer != p.buyer
                || o.contentSelectionHash != i.contentSelectionHash || o.asset != address(0)
                || o.price != i.amount || o.nonce == 0 || o.deadline < block.timestamp
                || o.finalizeBy != 0
        ) revert InvalidPreparedNativeOffer();
    }

    function requireAuthorization(
        IStreamMintManager.MintBatch calldata b,
        Offer.GateData memory d,
        Offer.Purchase memory p,
        Prepared.Intent memory i
    ) public view {
        requirePresentation(address(this), msg.sender, d, p, i);
        if (
            b.initialRecipients.length != 1 || b.beneficiaries.length != 1
                || b.tokenData.length != 1 || b.mintCommitments.length != 1
                || b.initialRecipients[0] != msg.sender || b.beneficiaries[0] != p.buyer
                || b.payer != p.buyer || b.authorizer != p.authorizer
                || b.authorizationId != p.authorizationId || b.collectionId != i.collectionId
                || b.phaseId != i.phaseId || b.expectedPolicyHash != i.boundMintPolicyHash
                || b.mintCommitments[0] != i.mintCommitment
                || d.authorization.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients
                        )
                    )
                || d.authorization.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries
                        )
                    )
                || d.authorization.tokenDataArrayHash
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData)
                    )
                || d.authorization.mintCommitmentsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments
                        )
                    )
        ) revert InvalidPreparedNativeOffer();
    }
}
