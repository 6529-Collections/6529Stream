// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamPrivateSaleSupport.sol";
import "./StreamMintTicketHash.sol";
import "../../interfaces/stream/mint/IStreamMintManager.sol";
import "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";

/// @notice Canonical SSA authorization and batch binding for one native private primary mint.
/// @dev Linked calls preserve the host verifier and original executor. The host must admit its
/// immutable terms, validate the selected leaf/bytes/proof and content context, and enforce live
/// sale, Artist, module and delegate authority. Manager/Ledger own durable authorization replay.
/// The batch authorizer is the admitted seller; the prepared intent hash remains a separate ID.
library StreamNativeCuratedPrivateAuthorization {
    struct Context {
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
    }

    error InvalidCuratedPrivateTerms();
    error InvalidCuratedPrivateAuthorization();
    error InvalidCuratedPrivateBatch();
    error CuratedPrivateSignerNotAuthorized(address authorizer, uint8 kind);
    error CuratedPrivateSignatureInvalid(address authorizer);
    error CuratedPrivateLedgerIdMismatch(bytes32 expected, bytes32 actual);

    function validate(
        Context memory context,
        Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamPrivateSaleAdapter.Signature memory proof,
        IStreamMintManager.MintBatch memory batch
    ) public view returns (bytes32 digest, bytes32 authorizationId) {
        if (
            context.manager == address(0) || context.signatureGas == 0
                || context.signatureGas > type(uint64).max || terms.saleId == 0
                || terms.collectionId == 0 || terms.phaseId == 0 || terms.buyer == address(0)
                || terms.buyer == address(this) || terms.price == 0
                || terms.deadline <= terms.startsAt || terms.selectedLeaf == 0
                || terms.mintPolicyHash == 0 || terms.primaryPolicyMode > 1
                || terms.expectedPrimaryPolicyHash == 0 || terms.seller == address(0)
                || (terms.sellerKind != 1 && terms.sellerKind != 2)
        ) revert InvalidCuratedPrivateTerms();
        if (
            block.timestamp < terms.startsAt || block.timestamp > terms.deadline
                || authorization.chainId != block.chainid
                || authorization.saleAdapter != address(this)
                || authorization.mintManager != context.manager
                || authorization.collectionId != terms.collectionId
                || authorization.phaseId != terms.phaseId || authorization.saleId != terms.saleId
                || authorization.saleKind != 5
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
        ) revert InvalidCuratedPrivateAuthorization();
        _requireBatch(terms, authorization, batch);
        if (proof.authorizer != terms.seller || proof.kind != terms.sellerKind) {
            revert CuratedPrivateSignerNotAuthorized(proof.authorizer, proof.kind);
        }
        digest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(authorization)
        );
        authorizationId = StreamMintTicketHash.authorizationId(digest);
        if (batch.authorizationId != authorizationId) {
            revert CuratedPrivateLedgerIdMismatch(authorizationId, batch.authorizationId);
        }
        if (!StreamPrivateSaleSupport.validSignature(
                proof.authorizer, proof.kind, digest, proof.signature, context.signatureGas
            )) revert CuratedPrivateSignatureInvalid(proof.authorizer);
    }

    function _requireBatch(
        Terms memory terms,
        StreamPrivateSaleTypes.SaleAuthorization memory authorization,
        IStreamMintManager.MintBatch memory batch
    ) private view {
        if (
            batch.collectionId != terms.collectionId || batch.phaseId != terms.phaseId
                || batch.authorizer != terms.seller || batch.payer != terms.buyer
                || batch.expectedPolicyHash != terms.mintPolicyHash || batch.contextHash == 0
                || batch.initialRecipients.length != 1 || batch.beneficiaries.length != 1
                || batch.tokenData.length != 1 || batch.mintCommitments.length != 1
        ) revert InvalidCuratedPrivateBatch();
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
        ) revert InvalidCuratedPrivateBatch();
    }
}
