// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamNativeCuratedSaleState } from "./StreamNativeCuratedSaleState.sol";
import {
    StreamPreparedNativeSettlementHash
} from "../revenue/StreamPreparedNativeSettlementHash.sol";
import { IStreamCore } from "../../interfaces/stream/core/IStreamCore.sol";
import {
    IStreamPreparedNativeMint
} from "../../interfaces/stream/mint/IStreamPreparedNativeMint.sol";
import {
    IStreamPreparedNativeContentSale
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentMint.sol";
import {
    IStreamPreparedNativeContentPurchaseMint,
    IStreamPreparedNativeContentPurchaseSale,
    IStreamPreparedNativeContentPurchaseSettlement
} from "../../interfaces/stream/mint/IStreamPreparedNativeContentPurchaseMint.sol";
import {
    StreamNativeCuratedSaleTypes as Curated
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    StreamPreparedNativeSettlementTypes as Prepared
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPrimarySettlementTypes as Primary
} from "../../interfaces/stream/revenue/StreamPrimarySettlementTypes.sol";
import { StreamNativeCuratedSaleRuntime as Runtime } from "./StreamNativeCuratedSaleRuntime.sol";

/// @notice Fixed typed callback, receipt and bounded final delivery worker.
library StreamNativeCuratedSaleSettlement {
    error CuratedSaleUnavailable(bytes32 saleId);
    error CuratedSaleStopped(bytes32 saleId);
    error CuratedPurchaseInvalid();
    error CuratedAccountingMismatch();
    error CuratedCallbackInvalid();
    error CuratedDeliveryFailed(address recipient);

    function callback(
        StreamNativeCuratedSaleState.State storage state,
        Runtime.Context memory x,
        Prepared.Facts calldata facts
    ) public returns (bytes memory) {
        Primary.PrimarySettlementResult memory result;
        if (facts.intentHash == 0 || state.active.intentHash != facts.intentHash) {
            revert CuratedCallbackInvalid();
        }
        StreamNativeCuratedSaleState.Active storage a = state.active;
        Prepared.Intent memory i = a.intent;
        Curated.ExecutionRecord storage e = state.executions[a.purchase.purchaseId];
        if (
            msg.sender != address(x.base.manager) || a.callbackConsumed
                || facts.saleAdapter != address(this)
                || facts.mintManager != address(x.base.manager)
                || facts.recorder != address(x.recorder) || facts.recorderCodeHash != x.recorderHash
                || facts.collectionId != i.collectionId || facts.phaseId != i.phaseId
                || facts.payer != i.payer || facts.initialRecipient != address(this)
                || facts.beneficiary != i.beneficiary || facts.tokenDataHash != e.tokenDataHash
                || facts.mintCommitment != i.mintCommitment
                || facts.boundPolicyHash != i.boundMintPolicyHash || facts.currentPolicyHash == 0
                || facts.operationRoot == 0 || facts.operationId == 0 || facts.tokenId == 0
        ) revert CuratedCallbackInvalid();
        if (
            keccak256(
                    abi.encode(
                        IStreamPreparedNativeMint(address(x.base.manager))
                            .activePreparedNativeMint()
                    )
                ) != keccak256(abi.encode(facts))
        ) revert CuratedCallbackInvalid();
        Runtime.requireSale(state, x, i.saleId);
        a.callbackConsumed = true;
        a.tokenId = facts.tokenId;
        e.operationRoot = facts.operationRoot;
        e.operationId = facts.operationId;
        result = IStreamPreparedNativeContentPurchaseSettlement(address(x.recorder))
        .settlePreparedNativeContentPurchase{ value: i.amount }(
            facts, i
        );
        if (
            result.executionId != StreamPreparedNativeSettlementHash.executionId(facts, i)
                || result.currentPolicyHash != facts.currentPolicyHash
                || result.boundPolicyHash != facts.boundPolicyHash || result.settlementKey == 0
        ) {
            revert CuratedAccountingMismatch();
        }
        e.settlementKey = result.settlementKey;
        return
            abi.encode(
                IStreamPreparedNativeContentSale.onPreparedNativeContentMint.selector, result
            );
    }

    function requireReceipt(
        StreamNativeCuratedSaleState.State storage state,
        Runtime.Context memory x,
        Curated.ExecutionRecord memory e,
        Primary.PrimarySettlementResult memory r
    ) public view {
        StreamNativeCuratedSaleState.Active storage a = state.active;
        Curated.ExecutionRecord storage saved = state.executions[a.purchase.purchaseId];
        if (
            !a.callbackConsumed || !a.received || e.tokenId == 0 || e.tokenId != a.tokenId
                || e.operationRoot != saved.operationRoot || e.operationId != saved.operationId
                || r.settlementKey == 0 || r.candidateCommitment == 0 || r.profileId == 0
                || r.wallet == address(0) || r.asset != address(0) || r.amount != e.price
                || r.executor != a.intent.executor || r.executionId == 0
                || r.settlementKey != saved.settlementKey
                || r.operationIdentityCommitment != e.operationRoot || r.currentPolicyHash == 0
                || r.boundPolicyHash != a.intent.boundMintPolicyHash
                || !x.recorder.settlementConsumed(r.settlementKey)
                || keccak256(abi.encode(x.recorder.settlementResult(r.settlementKey)))
                    != keccak256(abi.encode(r))
                || !IStreamPreparedNativeContentPurchaseSettlement(address(x.recorder))
                    .preparedNativeContentPurchaseConsumed(address(this), a.purchase.purchaseId)
                || IStreamCore(x.base.core).ownerOf(e.tokenId) != address(this)
                || IStreamCore(x.base.core).tokenLifecycle(e.tokenId) != 2
                || IStreamCore(x.base.core).pendingPreparedMintTokenId() != 0
        ) revert CuratedAccountingMismatch();
    }

    function deliver(Runtime.Context memory x, address recipient, uint256 tokenId) public {
        uint256 cap = Runtime.gasParameter(Runtime.DELIVERY_GAS);
        Runtime.admitGas(cap);
        bytes memory data = abi.encodeWithSignature(
            "safeTransferFrom(address,address,uint256)", address(this), recipient, tokenId
        );
        bool ok;
        uint256 size;
        address target = x.base.core;
        assembly ("memory-safe") {
            ok := call(cap, target, 0, add(data, 32), mload(data), 0, 0)
            size := returndatasize()
        }
        if (!ok || size != 0) revert CuratedDeliveryFailed(recipient);
    }
}
