// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {
    StreamERC20PrimaryOfferTypes as Offer
} from "../../interfaces/stream/mint/StreamERC20PrimaryOfferTypes.sol";

/// @notice Carrier-owned state; payment nonces and mint authorization keys stay in their owners.
library StreamERC20PrimaryOfferState {
    struct State {
        uint256 nextSaleNonce;
        bool paused;
        mapping(bytes32 => Offer.SaleRecord) sales;
        mapping(uint256 => mapping(address => mapping(uint8 => Offer.CollectionSigner))) signers;
        mapping(bytes32 => mapping(address => uint256)) executionNonces;
        mapping(bytes32 => Offer.ExecutionRecord) executions;
        mapping(bytes32 => bool) salePaused;
        mapping(uint256 => bool) collectionStopped;
    }
}
