// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./StreamNativeCustodySettlementTypes.sol";
import "./StreamPrimarySettlementTypes.sol";
import "./StreamCustodyRightsTypes.sol";

interface IStreamCustodyRightsSettlement {
    event CustodyRightsRevenueRecorded(
        uint16 schemaVersion,
        bytes32 indexed settlementKey,
        bytes32 indexed saleKey,
        bytes32 indexed factsHash,
        StreamNativeCustodySettlementTypes.Facts facts,
        StreamCustodyRightsTypes.Activation activation,
        bytes32 beneficiaryHash,
        StreamPrimarySettlementTypes.PrimarySettlementResult result
    );

    function settleCustodyRightsPrimarySale(bytes32 auctionId)
        external
        payable
        returns (StreamPrimarySettlementTypes.PrimarySettlementResult memory);
}
