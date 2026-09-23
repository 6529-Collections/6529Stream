// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamNativeCuratedSaleTypes
} from "../../interfaces/stream/mint/StreamNativeCuratedSaleTypes.sol";
import {
    StreamPreparedNativeSettlementTypes
} from "../../interfaces/stream/revenue/StreamPreparedNativeSettlementTypes.sol";
import {
    StreamPreparedNativeContentPurchaseTypes
} from "../../interfaces/stream/mint/StreamPreparedNativeContentPurchaseTypes.sol";
import { StreamNativeCuratedClock } from "./StreamNativeCuratedClock.sol";
import { StreamPrivateSaleTypes } from "../../interfaces/stream/mint/StreamPrivateSaleTypes.sol";
import {
    IStreamPrivateSaleAdapter
} from "../../interfaces/stream/mint/IStreamPrivateSaleAdapter.sol";

/// @notice One shared guard protects this satellite's sale records, active mint and native credits.
library StreamNativeCuratedSaleState {
    struct Request {
        bytes32 saleId;
        address buyer;
        StreamNativeCuratedSaleTypes.Selection selection;
        uint8 authorityMode;
        bytes32 authorizationDigest;
        StreamPrivateSaleTypes.SaleAuthorization authorization;
        IStreamPrivateSaleAdapter.Signature signature;
        bool priceEscrowed;
    }

    struct Active {
        bytes32 intentHash;
        StreamPreparedNativeSettlementTypes.Intent intent;
        StreamPreparedNativeContentPurchaseTypes.Purchase purchase;
        uint256 tokenId;
        bool callbackConsumed;
        bool received;
    }

    struct State {
        uint256 nextSaleNonce;
        mapping(bytes32 => StreamNativeCuratedSaleTypes.SaleRecord) sales;
        mapping(bytes32 => mapping(address => uint256)) purchaseNonces;
        mapping(bytes32 => StreamNativeCuratedSaleTypes.ExecutionRecord) executions;
        mapping(bytes32 => mapping(address => uint256)) credits;
        uint256 refundLiability;
        StreamNativeCuratedClock.History clocks;
        Active active;
    }
}
