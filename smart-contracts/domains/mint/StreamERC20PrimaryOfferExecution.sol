// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamERC20PrimaryOfferSupport.sol";
import "./StreamERC20PrimaryOfferAuthorization.sol";
import "../../interfaces/stream/mint/IStreamERC20OfferMint.sol";
import "../../interfaces/stream/revenue/IStreamPrimarySaleSettlement.sol";
import "../revenue/StreamPrimarySettlementHash.sol";

/// @notice Fixed typed candidate construction and exact receipt checks; no token pull surface.
library StreamERC20PrimaryOfferExecution {
    error InvalidERC20PrimaryOfferExecution();
    error ERC20PrimaryOfferSettlementFailed();

    function candidate(
        StreamERC20PrimaryOfferState.State storage state,
        StreamERC20PrimaryOfferSupport.Context memory x,
        Offer.Acceptance memory q,
        uint256 signatureGas
    )
        public
        view
        returns (
            StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c,
            IStreamMintManager.MintBatch memory b,
            StreamERC20OfferMintTypes.GateData memory d
        )
    {
        bytes32 id = q.authorization.saleId;
        StreamERC20PrimaryOfferSupport.requireSale(state, x, id);
        Offer.SaleRecord storage s = state.sales[id];
        Offer.Configuration memory terms = s.config;
        if (q.selection.executionNonce != state.executionNonces[id][terms.buyer] + 1) {
            revert InvalidERC20PrimaryOfferExecution();
        }
        (bytes32 leaf, bytes32 context) =
            StreamERC20PrimaryOfferSupport.selection(id, terms, q.selection);
        bytes32 sellerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.authorizationBody(q.authorization)
        );
        bytes32 buyerDigest = StreamPrivateSaleHash.digest(
            block.chainid, address(this), StreamPrivateSaleHash.offerBody(q.offer)
        );
        b.collectionId = terms.collectionId;
        b.phaseId = terms.phaseId;
        b.payer = terms.buyer;
        b.authorizer = q.buyerProof.authorizer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = terms.buyer;
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = terms.buyer;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = q.selection.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = q.selection.mintCommitment;
        b.expectedPolicyHash = terms.mintPolicyHash;
        b.authorizationId = StreamMintTicketHash.authorizationId(buyerDigest);
        b.contextHash = context == 0 ? sellerDigest : context;
        (bytes32 checkedSeller, bytes32 checkedBuyer, bytes32 checkedId) = StreamERC20PrimaryOfferAuthorization.validate(
            StreamERC20PrimaryOfferAuthorization.Context(
                x.core, address(x.manager), signatureGas, q.authorization.executor
            ),
            StreamERC20PrimaryOfferAuthorization.Terms(
                id,
                terms.collectionId,
                terms.phaseId,
                terms.buyer,
                terms.asset,
                terms.price,
                terms.startsAt,
                terms.endsAt,
                leaf,
                terms.mintPolicyHash,
                terms.primaryPolicyMode,
                terms.expectedPrimaryPolicyHash,
                terms.signer,
                terms.signerKind,
                terms.offerDigest
            ),
            q.authorization,
            q.sellerProof,
            q.offer,
            q.buyerProof,
            b
        );
        if (
            checkedSeller != sellerDigest || checkedBuyer != buyerDigest
                || checkedId != b.authorizationId
        ) revert InvalidERC20PrimaryOfferExecution();
        d = StreamERC20OfferMintTypes.GateData(
            q.authorization.executor,
            q.selection.content,
            q.authorization,
            q.sellerProof,
            q.offer,
            q.buyerProof,
            q.signerDelegation,
            q.executorDelegation
        );
        c.saleAdapter = address(this);
        c.executor = q.authorization.executor;
        c.sale = StreamPrimarySettlementTypes.PrimarySale(
            id,
            keccak256("PRIMARY_SALE"),
            terms.primaryPolicyMode,
            terms.collectionId,
            0,
            s.saleNonce,
            terms.buyer,
            terms.poster,
            terms.buyer,
            terms.price,
            terms.expectedPrimaryPolicyHash
        );
        c.lifecycleBinding = s.lifecycle;
        c.executionBinding = StreamPrimarySettlementTypes.SaleExecutionBinding(
            0, q.selection.executionNonce, 1, sellerDigest
        );
        c.asset = terms.asset;
        c.orchestrationOrder = 1;
        c.mintManager = address(x.manager);
        c.currentPolicyHash = x.manager.phasePolicyHash(terms.collectionId, terms.phaseId);
        c.boundPolicyHash = terms.mintPolicyHash;
        c.rights = StreamERC20PrimaryOfferSupport.rights(x, terms);
        c.saleExecutionHash = keccak256(abi.encode(q));
        bytes32[] memory ids;
        (c.operationIdentityCommitment, ids) =
            IStreamERC20OfferMint(address(x.manager)).previewERC20OfferMintOperation(b, d);
        if (c.operationIdentityCommitment == 0 || ids.length != 1 || ids[0] == 0) {
            revert InvalidERC20PrimaryOfferExecution();
        }
        c.operationId = ids[0];
        c.executionBinding.executionId = StreamPrimarySettlementHash.executionId(c);
        StreamSettlementAdmission.requireAdmission(x.registry, terms.paymentAdapter, c);
    }

    function settle(
        address recorder,
        StreamPrimarySettlementTypes.ERC20SettlementCandidate memory c
    ) public returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory result) {
        bytes memory data = abi.encodeCall(
            IStreamPrimarySaleSettlement.settleERC20PrimarySaleFromAdapter,
            (c.lifecycleBinding.paymentAdapter, c)
        );
        bytes memory response = new bytes(384);
        bool ok;
        uint256 size;
        assembly ("memory-safe") {
            ok := call(gas(), recorder, 0, add(data, 32), mload(data), add(response, 32), 384)
            size := returndatasize()
        }
        if (!ok || size != 384) revert ERC20PrimaryOfferSettlementFailed();
        result = abi.decode(response, (StreamPrimarySettlementTypes.PrimarySettlementResult));
        if (
            result.candidateCommitment
                    != StreamPrimarySettlementHash.candidateCommitment(
                        c.lifecycleBinding.paymentAdapter, recorder, c
                    )
                || result.settlementKey
                    != StreamPrimarySettlementHash.settlementKey(
                        recorder, address(this), c.executionBinding.executionId
                    ) || result.profileId != c.rights.profileId || result.wallet != c.rights.wallet
                || result.asset != c.asset || result.amount != c.sale.amount
                || result.executor != c.executor
                || result.executionId != c.executionBinding.executionId
                || result.operationIdentityCommitment != c.operationIdentityCommitment
                || result.currentPolicyHash != c.currentPolicyHash
                || result.boundPolicyHash != c.boundPolicyHash
        ) revert ERC20PrimaryOfferSettlementFailed();
    }
}
