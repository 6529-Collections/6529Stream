// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import "./StreamPrivateSaleHash.sol";
import "./StreamMintTicketHash.sol";

/// @notice The original purchase and signed authorization domains, with a separate admission profile.
library StreamPreparedNativeContentPurchaseHash {
    error InvalidPreparedNativeContentPurchase();

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

    function admissionHash(
        address house,
        bytes32 intentHash,
        StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
        StreamPreparedNativeContentTypes.Facts memory c
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("6529STREAM_PREPARED_NATIVE_CONTENT_PURCHASE_ADMISSION_V1"),
                block.chainid,
                house,
                intentHash,
                p,
                c
            )
        );
    }

    function readPurchase(
        address house,
        bytes32 intentHash,
        StreamPreparedNativeSettlementTypes.Intent memory i
    ) public view returns (StreamPreparedNativeContentPurchaseTypes.Purchase memory p) {
        bytes memory input = abi.encodeCall(
            IStreamPreparedNativeContentPurchaseSale.activePreparedNativeContentPurchase,
            (intentHash)
        );
        bytes memory raw = new bytes(320);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := staticcall(gas(), house, add(input, 32), mload(input), add(raw, 32), 320)
            size := returndatasize()
        }
        if (!ok || size != 320) revert InvalidPreparedNativeContentPurchase();
        p = abi.decode(raw, (StreamPreparedNativeContentPurchaseTypes.Purchase));
        if (
            keccak256(raw) != keccak256(abi.encode(p)) || intentHash == 0 || p.saleId == 0
                || p.saleId != i.saleId || p.saleNonce == 0 || p.saleNonce != i.saleNonce
                || p.saleConfigHash == 0 || p.buyer == address(0) || p.buyer != i.payer
                || p.purchaseNonce == 0 || p.purchaseNonce != i.executionNonce
                || p.purchaseId != purchaseId(house, p.saleId, p.buyer, p.purchaseNonce)
                || p.authorizationId == 0 || p.primaryPolicyMode > 1
                || p.primaryPolicyMode != i.primaryPolicyMode
        ) revert InvalidPreparedNativeContentPurchase();
        if (i.authorityMode == 2) {
            if (
                p.authorizationId != intentHash || p.authorizer != address(0)
                    || p.authorizerKind != 0
            ) {
                revert InvalidPreparedNativeContentPurchase();
            }
        } else if (i.authorityMode == 1) {
            if (
                p.authorizationId != StreamMintTicketHash.authorizationId(i.saleAuthorizationDigest)
                    || p.authorizer == address(0)
                    || (p.authorizerKind != 1 && p.authorizerKind != 2)
            ) {
                revert InvalidPreparedNativeContentPurchase();
            }
        } else {
            revert InvalidPreparedNativeContentPurchase();
        }
    }

    /// @dev Signature/membership verification belongs to the independently admitted gate.
    /// These checks bind its signed presentation to the complete actual Manager batch.
    function requireAuthorization(
        IStreamMintManager.MintBatch calldata b,
        StreamPreparedNativeContentPurchaseTypes.GateData memory d,
        StreamPreparedNativeContentPurchaseTypes.Purchase memory p,
        StreamPreparedNativeSettlementTypes.Intent memory i
    ) public view {
        if (
            b.initialRecipients.length != 1 || b.beneficiaries.length != 1
                || b.tokenData.length != 1 || b.mintCommitments.length != 1
                || b.initialRecipients[0] != msg.sender || b.beneficiaries[0] != i.beneficiary
                || b.payer != p.buyer || b.authorizer != p.authorizer
                || b.authorizationId != p.authorizationId || d.authorizationId != p.authorizationId
                || b.collectionId != i.collectionId || b.phaseId != i.phaseId
                || b.expectedPolicyHash != i.boundMintPolicyHash
                || b.mintCommitments[0] != i.mintCommitment
        ) revert InvalidPreparedNativeContentPurchase();
        StreamPrivateSaleTypes.SaleAuthorization memory a = d.authorization;
        if (i.authorityMode == 2) {
            StreamPrivateSaleTypes.SaleAuthorization memory empty;
            if (
                keccak256(abi.encode(a)) != keccak256(abi.encode(empty))
                    || d.signature.authorizer != address(0) || d.signature.kind != 0
                    || d.signature.signature.length != 0
            ) revert InvalidPreparedNativeContentPurchase();
            return;
        }
        bytes32 digest = StreamPrivateSaleHash.digest(
            block.chainid, msg.sender, StreamPrivateSaleHash.authorizationBody(a)
        );
        if (
            a.chainId != block.chainid || a.saleAdapter != msg.sender
                || a.mintManager != address(this) || a.collectionId != b.collectionId
                || a.phaseId != b.phaseId || a.saleId != p.saleId || a.saleKind != 5
                || a.revenueClass != keccak256("PRIMARY_SALE") || a.primaryPolicyMode != 0
                || a.expectedPrimaryPolicyHash != i.originalPrimaryPolicyHash
                || a.primaryPolicyMode != i.primaryPolicyMode || a.payer != b.payer
                || a.executor != i.executor || a.asset != address(0) || a.unitPrice != i.amount
                || a.quantity != 1 || a.contentSelectionHash != i.contentSelectionHash
                || a.policyHash != b.expectedPolicyHash || a.nonce == 0
                || a.deadline < block.timestamp || a.finalizeBy != 0
                || digest != i.saleAuthorizationDigest || d.signature.authorizer != p.authorizer
                || d.signature.kind != p.authorizerKind
                || a.initialRecipientsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_RECIPIENTS_V1"), b.initialRecipients
                        )
                    )
                || a.beneficiariesHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_BENEFICIARIES_V1"), b.beneficiaries
                        )
                    )
                || a.tokenDataArrayHash
                    != keccak256(
                        abi.encode(keccak256("6529STREAM_MINT_BATCH_TOKEN_DATA_V1"), b.tokenData)
                    )
                || a.mintCommitmentsHash
                    != keccak256(
                        abi.encode(
                            keccak256("6529STREAM_MINT_BATCH_COMMITMENTS_V1"), b.mintCommitments
                        )
                    )
        ) revert InvalidPreparedNativeContentPurchase();
    }
}
