// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../../interfaces/stream/mint/IStreamNativeImmediateSales.sol";
import "./StreamNativeCuratedClock.sol";

library StreamNativeImmediateSalesState {
    struct Signer {
        IStreamNativeImmediateSales.SignerBinding binding;
        bool enabled;
    }

    struct State {
        uint256 nextSaleNonce;
        mapping(bytes32 => IStreamNativeImmediateSales.Record) sales;
        mapping(uint256 => mapping(address => mapping(uint8 => Signer))) signers;
        mapping(bytes32 => mapping(address => uint256)) executionNonces;
        mapping(bytes32 => IStreamNativeImmediateSales.Receipt) receipts;
        mapping(bytes32 => uint8) executionStatus;
        StreamNativeCuratedClock.History clocks;
        bytes32 activePublicId;
        bytes32 activePublicCommitment;
        mapping(bytes32 => mapping(address => uint256)) refunds;
        mapping(bytes32 => mapping(address => bool)) refundSeen;
        bytes32[] refundSales;
        address[] refundPayers;
        uint256 refundLiability;
    }
}
