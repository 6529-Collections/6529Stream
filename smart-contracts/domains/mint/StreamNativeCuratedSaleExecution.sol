// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import { StreamNativeCuratedSaleSupport } from "./StreamNativeCuratedSaleSupport.sol";
import { StreamNativeCuratedSaleHash } from "./StreamNativeCuratedSaleHash.sol";
import { StreamPreparedNativeContentHash } from "./StreamPreparedNativeContentHash.sol";
import { StreamMintTicketHash } from "./StreamMintTicketHash.sol";
import { StreamImmediateSaleReveal } from "./StreamImmediateSaleReveal.sol";
import { IStreamMintManager } from "../../interfaces/stream/mint/IStreamMintManager.sol";
import {
    IStreamPreparedNativeContentPurchaseMint,
    IStreamPreparedNativeContentPurchaseSale,
    IStreamPreparedNativeContentPurchaseSettlement
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import {
    StreamPreparedNativeContentPurchaseTypes as PurchaseTypes
} from "../../interfaces/stream/mint/StreamPreparedNativeContentPurchaseTypes.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    IStreamImmediateSaleReveal
} from "../../interfaces/stream/mint/IStreamImmediateSaleReveal.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes as Primary
} from "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import { StreamNativeCuratedSaleRuntime as Runtime } from "./StreamNativeCuratedSaleRuntime.sol";
import {
    StreamNativeCuratedSaleSettlement as Settlement
} from "./StreamNativeCuratedSaleSettlement.sol";

interface ICuratedLiabilities {
    function totalBuyerLiabilities() external view returns (uint256);
}

/// @notice Fixed linked purchase orchestration; host guard and original caller survive delegatecall.
library StreamNativeCuratedSaleExecution {
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedSaleStopped(bytes32 saleId);
    error CuratedPurchaseInvalid();
    error CuratedAccountingMismatch();
    error CuratedCallbackInvalid();
    error CuratedDeliveryFailed(address recipient);
    event CuratedPurchaseSettled(
        bytes32 indexed saleId,
        bytes32 indexed purchaseId,
        address indexed buyer,
        Curated.ExecutionRecord execution,
        uint256 revealFee,
        uint256 feeCredit
    );
    event CuratedCreditAdded(bytes32 indexed saleId, address indexed buyer, uint256 amount);

    function execute(
        StreamNativeCuratedSaleState.State storage state,
        Runtime.Context memory x,
        StreamNativeCuratedSaleState.Request memory r
    ) public returns (Curated.ExecutionRecord memory e) {
        Runtime.requireSale(state, x, r.saleId);
        Curated.SaleRecord storage s = state.sales[r.saleId];
        bytes32 purchaseId =
            StreamNativeCuratedSaleHash.purchaseId(r.saleId, r.buyer, r.selection.purchaseNonce);
        if (
            state.active.intentHash != 0 || state.executions[purchaseId].saleId != 0
                || r.selection.purchaseNonce == 0
                || r.selection.purchaseNonce > state.purchaseNonces[r.saleId][r.buyer]
                || (r.authorityMode != 1 && r.authorityMode != 2)
        ) revert CuratedPurchaseInvalid();
        (bytes32 leaf,) = StreamNativeCuratedSaleSupport.selection(r.saleId, s, r.selection);
        IStreamImmediateSaleReveal.RevealQuote memory quote =
            StreamImmediateSaleReveal.quote(x.base.core, s.config.collectionId);
        uint256 priceDue = r.priceEscrowed ? 0 : s.config.price;
        if (msg.value < priceDue) revert CuratedAccountingMismatch();
        uint256 excess = StreamImmediateSaleReveal.preflight(
            quote, msg.value - priceDue, Runtime.gasParameter(Runtime.REVEAL_GAS)
        );
        Runtime.admitGas(Runtime.gasParameter(Runtime.DELIVERY_GAS));
        Prepared.Intent memory intent = _intent(r, s, purchaseId, leaf);
        bytes32 hash = StreamPreparedNativeContentHash.intentHash(
            address(this), address(x.recorder), intent
        );
        bytes32 authorizationId = r.authorityMode == 1
            ? StreamMintTicketHash.authorizationId(r.authorizationDigest)
            : hash;
        PurchaseTypes.Purchase memory p = PurchaseTypes.Purchase(
            r.saleId,
            s.saleNonce,
            s.configHash,
            purchaseId,
            r.buyer,
            r.selection.purchaseNonce,
            authorizationId,
            r.signature.authorizer,
            r.signature.kind,
            s.config.primaryPolicyMode
        );
        IStreamMintManager.MintBatch memory b =
            batch(state, r.saleId, r.buyer, r.selection, authorizationId, p.authorizer);
        state.active.intentHash = hash;
        state.active.intent = intent;
        state.active.purchase = p;
        e = Curated.ExecutionRecord(
            r.saleId,
            r.buyer,
            r.selection.recipient,
            r.selection.purchaseNonce,
            authorizationId,
            intent.saleAuthorizationDigest,
            leaf,
            r.selection.content.tokenDataHash,
            r.selection.mintCommitment,
            s.config.price,
            0,
            0,
            0,
            0
        );
        state.executions[purchaseId] = e;
        uint256 beforeBalance = address(this).balance;
        Primary.PrimarySettlementResult memory receipt;
        (e.tokenId, e.operationRoot, e.operationId, receipt) =
            IStreamPreparedNativeContentPurchaseMint(address(x.base.manager))
                .executePreparedNativeContentPurchaseMint(
                    b,
                    abi.encode(
                        PurchaseTypes.GateData(
                            hash, authorizationId, r.selection.content, r.authorization, r.signature
                        )
                    ),
                    hash
                );
        Settlement.requireReceipt(state, x, e, receipt);
        Runtime.requireSale(state, x, r.saleId);
        StreamImmediateSaleReveal.fundAndAttempt(
            x.base.core,
            s.config.collectionId,
            e.tokenId,
            quote,
            Runtime.gasParameter(Runtime.REVEAL_GAS)
        );
        if (
            address(this).balance
                != beforeBalance - s.config.price - quote.policy.revealFeePerTokenWei
        ) revert CuratedAccountingMismatch();
        e.settlementKey = receipt.settlementKey;
        state.executions[purchaseId] = e;
        credit(state, r.saleId, r.buyer, excess);
        Settlement.deliver(x, e.recipient, e.tokenId);
        Runtime.requireSale(state, x, r.saleId);
        if (address(this).balance < ICuratedLiabilities(address(this)).totalBuyerLiabilities()) {
            revert CuratedAccountingMismatch();
        }
        delete state.active;
        emit CuratedPurchaseSettled(
            r.saleId, purchaseId, r.buyer, e, quote.policy.revealFeePerTokenWei, excess
        );
    }

    function batch(
        StreamNativeCuratedSaleState.State storage state,
        bytes32 id,
        address buyer,
        Curated.Selection memory chosen,
        bytes32 authorizationId,
        address authorizer
    ) public view returns (IStreamMintManager.MintBatch memory b) {
        Curated.SaleRecord storage s = state.sales[id];
        (, bytes32 contextHash) = StreamNativeCuratedSaleSupport.selection(id, s, chosen);
        b.collectionId = s.config.collectionId;
        b.phaseId = s.config.phaseId;
        b.payer = buyer;
        b.authorizer = authorizer;
        b.initialRecipients = new address[](1);
        b.initialRecipients[0] = address(this);
        b.beneficiaries = new address[](1);
        b.beneficiaries[0] = chosen.recipient;
        b.tokenData = new bytes[](1);
        b.tokenData[0] = chosen.tokenData;
        b.mintCommitments = new bytes32[](1);
        b.mintCommitments[0] = chosen.mintCommitment;
        b.expectedPolicyHash = s.config.mintPolicyHash;
        b.authorizationId = authorizationId;
        b.contextHash = contextHash;
    }

    function _intent(
        StreamNativeCuratedSaleState.Request memory r,
        Curated.SaleRecord storage s,
        bytes32 purchaseId,
        bytes32 leaf
    ) private view returns (Prepared.Intent memory i) {
        i.collectionId = s.config.collectionId;
        i.phaseId = s.config.phaseId;
        i.saleId = r.saleId;
        i.saleNonce = s.saleNonce;
        i.executor = msg.sender;
        i.payer = r.buyer;
        i.poster = s.config.poster;
        i.beneficiary = r.selection.recipient;
        i.amount = s.config.price;
        i.primaryPolicyMode = s.config.primaryPolicyMode;
        i.originalPrimaryPolicyHash = s.config.expectedPrimaryPolicyHash;
        i.executionNonce = r.selection.purchaseNonce;
        i.authorityMode = r.authorityMode;
        i.saleExecutionHash = keccak256(
            abi.encode(
                keccak256("6529STREAM_NATIVE_CURATED_EXECUTION_V1"),
                block.chainid,
                address(this),
                s.configHash,
                purchaseId,
                r
            )
        );
        i.saleAuthorizationDigest = r.authorityMode == 1
            ? r.authorizationDigest
            : keccak256(
                abi.encode(
                    keccak256("6529STREAM_NATIVE_CURATED_PUBLIC_PURCHASE_V1"),
                    block.chainid,
                    address(this),
                    purchaseId,
                    s.configHash,
                    leaf,
                    msg.sender,
                    i.saleExecutionHash
                )
            );
        i.contentSelectionHash = leaf;
        i.mintCommitment = r.selection.mintCommitment;
        i.boundMintPolicyHash = s.config.mintPolicyHash;
    }

    function credit(
        StreamNativeCuratedSaleState.State storage state,
        bytes32 id,
        address buyer,
        uint256 amount
    ) public {
        if (amount == 0) return;
        state.credits[id][buyer] += amount;
        state.refundLiability += amount;
        emit CuratedCreditAdded(id, buyer, amount);
    }
}
