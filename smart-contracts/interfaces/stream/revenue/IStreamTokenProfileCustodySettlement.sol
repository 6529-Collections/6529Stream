// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodySettlementTypes.sol";
import "./StreamPrimarySettlementTypes.sol";
import "./StreamTokenProfileCustodyTypes.sol";

interface IStreamTokenProfileCustodySettlement {
    event TokenProfileCustodyRevenueRecorded(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamNativeCustodySettlementTypes.Facts facts,
        StreamTokenProfileCustodyTypes.Activation activation,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );

    function settleTokenProfileCustodyPrimarySale(bytes32 auctionId)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
